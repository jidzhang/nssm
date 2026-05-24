/*
  demo_svc.cpp - Minimal HTTP service for verifying NSSM functionality.

  Usage:  demo_svc.exe [port] [logfile]
  Default: port 18080, logfile demo_svc.log (in current directory)

  Access http://localhost:port/ to verify the service is alive.
  The page shows PID, uptime, and request count.
  /health returns a plain "OK" for scripted checks.

  Build (VS Developer Command Prompt):
    cl /nologo /O2 /DUNICODE /D_UNICODE demo_svc.cpp ws2_32.lib /Fe:demo_svc.exe

  Compatible with Windows XP+ (Winsock2, no Vista+ APIs).
*/

#include <winsock2.h>
#include <ws2tcpip.h>
#include <stdio.h>
#include <time.h>

#pragma comment(lib, "ws2_32.lib")

static const char* HTML_FMT =
    "HTTP/1.0 200 OK\r\n"
    "Content-Type: text/html; charset=utf-8\r\n"
    "Connection: close\r\n"
    "\r\n"
    "<html><head><title>NSSM Demo Service</title></head>"
    "<body style='font-family:monospace;background:#1a1a2e;color:#eee;padding:40px'>"
    "<h1 style='color:#0f0'>NSSM Demo Service - RUNNING</h1>"
    "<table style='font-size:18px'>"
    "<tr><td>PID</td><td>%u</td></tr>"
    "<tr><td>Uptime</td><td>%lus</td></tr>"
    "<tr><td>Requests</td><td>%lu</td></tr>"
    "<tr><td>Port</td><td>%d</td></tr>"
    "<tr><td>Time</td><td>%s</td></tr>"
    "</table>"
    "<p style='margin-top:30px;color:#888'>If you see this page, "
    "NSSM has successfully started and is managing this service.</p>"
    "</body></html>";

static const char* HEALTH_RESP =
    "HTTP/1.0 200 OK\r\n"
    "Content-Type: text/plain\r\n"
    "Connection: close\r\n"
    "\r\n"
    "OK";

static const char* FAVICON_RESP =
    "HTTP/1.0 204 No Content\r\n"
    "Connection: close\r\n\r\n";

static volatile long g_requests = 0;
static volatile int g_running = 1;
static time_t g_start_time = 0;
static int g_port = 18080;
static const char* g_logfile = "demo_svc.log";
static FILE* g_logfp = NULL;

static void log_msg(const char* fmt, ...) {
    if (!g_logfp) return;
    va_list ap;
    va_start(ap, fmt);
    time_t now = time(NULL);
    struct tm* t = localtime(&now);
    fprintf(g_logfp, "[%04d-%02d-%02d %02d:%02d:%02d] ",
            t->tm_year + 1900, t->tm_mon + 1, t->tm_mday,
            t->tm_hour, t->tm_min, t->tm_sec);
    vfprintf(g_logfp, fmt, ap);
    fprintf(g_logfp, "\n");
    fflush(g_logfp);
    va_end(ap);
}

static void send_response(SOCKET client, const char* data, int len) {
    int sent = 0;
    while (sent < len) {
        int n = send(client, data + sent, len - sent, 0);
        if (n <= 0) break;
        sent += n;
    }
}

static DWORD WINAPI client_thread(LPVOID param) {
    SOCKET client = (SOCKET)(ULONG_PTR)param;
    char buf[1024] = {0};
    recv(client, buf, sizeof(buf) - 1, 0);

    long req = InterlockedIncrement(&g_requests);
    time_t elapsed = (time(NULL) - g_start_time);

    if (strstr(buf, "GET /health") || strstr(buf, "GET /health ")) {
        log_msg("GET /health (req #%ld)", req);
        send_response(client, HEALTH_RESP, (int)strlen(HEALTH_RESP));
    } else if (strstr(buf, "GET /favicon")) {
        send_response(client, FAVICON_RESP, (int)strlen(FAVICON_RESP));
    } else {
        log_msg("GET / (req #%ld)", req);
        time_t now = time(NULL);
        char timebuf[64];
        struct tm* t = localtime(&now);
        sprintf(timebuf, "%04d-%02d-%02d %02d:%02d:%02d",
                t->tm_year + 1900, t->tm_mon + 1, t->tm_mday,
                t->tm_hour, t->tm_min, t->tm_sec);

        char resp[2048];
        int len = sprintf(resp, HTML_FMT,
                          GetCurrentProcessId(),
                          (unsigned long)elapsed,
                          (unsigned long)req,
                          g_port, timebuf);
        send_response(client, resp, len);
    }

    closesocket(client);
    return 0;
}

static BOOL WINAPI console_handler(DWORD type) {
    if (type == CTRL_C_EVENT || type == CTRL_BREAK_EVENT || type == CTRL_CLOSE_EVENT) {
        g_running = 0;
        return TRUE;
    }
    return FALSE;
}

int main(int argc, char* argv[]) {
    if (argc >= 2) g_port = atoi(argv[1]);
    if (argc >= 3) g_logfile = argv[2];

    g_start_time = time(NULL);
    g_logfp = fopen(g_logfile, "a");

    log_msg("=== demo_svc starting (pid=%u, port=%d) ===", GetCurrentProcessId(), g_port);
    SetConsoleCtrlHandler(console_handler, TRUE);

    WSADATA wsa;
    if (WSAStartup(MAKEWORD(2, 2), &wsa) != 0) {
        log_msg("WSAStartup failed: %d", WSAGetLastError());
        return 1;
    }

    SOCKET listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
    if (listener == INVALID_SOCKET) {
        log_msg("socket() failed: %d", WSAGetLastError());
        return 1;
    }

    /* Allow port reuse so restart doesn't fail with "address in use". */
    int reuse = 1;
    setsockopt(listener, SOL_SOCKET, SO_REUSEADDR, (const char*)&reuse, sizeof(reuse));

    struct sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port = htons((u_short)g_port);

    if (bind(listener, (struct sockaddr*)&addr, sizeof(addr)) == SOCKET_ERROR) {
        log_msg("bind(port=%d) failed: %d", g_port, WSAGetLastError());
        return 1;
    }

    if (listen(listener, 10) == SOCKET_ERROR) {
        log_msg("listen() failed: %d", WSAGetLastError());
        return 1;
    }

    log_msg("Listening on http://localhost:%d/", g_port);
    printf("demo_svc: listening on http://localhost:%d/\n", g_port);

    while (g_running) {
        fd_set readfds;
        struct timeval tv;
        tv.tv_sec = 1;
        tv.tv_usec = 0;
        FD_ZERO(&readfds);
        FD_SET(listener, &readfds);

        int sel = select(0, &readfds, NULL, NULL, &tv);
        if (sel > 0 && FD_ISSET(listener, &readfds)) {
            struct sockaddr_in client_addr;
            int client_len = sizeof(client_addr);
            SOCKET client = accept(listener, (struct sockaddr*)&client_addr, &client_len);
            if (client != INVALID_SOCKET) {
                CreateThread(NULL, 0, client_thread, (LPVOID)(ULONG_PTR)client, 0, NULL);
            }
        }
    }

    log_msg("=== demo_svc stopping ===");
    closesocket(listener);
    WSACleanup();
    if (g_logfp) fclose(g_logfp);
    return 0;
}
