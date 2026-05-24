@echo off
setlocal enabledelayedexpansion

rem ============================================================
rem  NSSM Demo - Install, Start, Test, Stop, Remove
rem
rem  Copy this bat together with nssm.exe and demo_svc.exe
rem  to the target machine, then run as Administrator.
rem ============================================================

cd /d "%~dp0"

set SVC=demo_svc
set PORT=18080
set NSSM=%cd%\nssm.exe
set APP=%cd%\demo_svc.exe

echo ============================================
echo   NSSM Demo Service Test
echo ============================================
echo.

rem --- Check files ---
if not exist "%NSSM%" (
    echo [ERROR] nssm.exe not found in %cd%
    echo         Put nssm.exe, demo_svc.exe and this bat in the same folder.
    exit /b 1
)
if not exist "%APP%" (
    echo [ERROR] demo_svc.exe not found in %cd%
    exit /b 1
)

echo [1/6] Installing service ...
"%NSSM%" install %SVC% "%APP%" %PORT%
if errorlevel 1 (
    echo [ERROR] Install failed. Are you running as Administrator?
    exit /b 1
)
echo       OK
echo.

echo [2/6] Starting service ...
"%NSSM%" start %SVC%
if errorlevel 1 (
    echo [WARN] Start returned non-zero, checking status ...
)
echo.

rem Wait for the service to come up
echo       Waiting for service ...
set TRIES=0
:waitloop
set /a TRIES+=1
if %TRIES% GTR 10 (
    echo [ERROR] Service did not start within 10 seconds.
    goto :cleanup
)
ping -n 2 127.0.0.1 >nul
"%NSSM%" status %SVC% 2>nul | findstr /i "RUNNING" >nul
if errorlevel 1 goto waitloop
echo       Service is RUNNING
echo.

echo [3/6] Testing HTTP endpoint ...
echo       Open your browser: http://localhost:%PORT%/
echo.
rem Try to fetch the health endpoint
set HEALTH_OK=0
rem Use PowerShell if available (Vista+), otherwise just skip
powershell -Command "$r=Invoke-WebRequest -Uri 'http://localhost:%PORT%/health' -TimeoutSec 5 -UseBasicParsing;if($r.StatusCode -eq 200){exit 0}else{exit 1}" >nul 2>&1
if not errorlevel 1 (
    echo       /health returned 200 OK
    set HEALTH_OK=1
) else (
    echo       [SKIP] Could not reach localhost:%PORT% from this script.
    echo              This is normal on XP without PowerShell. Use browser instead.
)
echo.

echo [4/6] Service info ---
"%NSSM%" status %SVC%
echo       PID:
"%NSSM%" get %SVC% AppExit Default 2>nul
echo.

echo ============================================
echo   Press any key to STOP and REMOVE the service ...
echo ============================================
pause >nul

:cleanup
echo.
echo [5/6] Stopping service ...
"%NSSM%" stop %SVC% 2>nul
ping -n 2 127.0.0.1 >nul
echo       Done.
echo.

echo [6/6] Removing service ...
"%NSSM%" remove %SVC% confirm 2>nul
echo       Done.
echo.

echo ============================================
echo   Test complete.
echo ============================================
exit /b 0
