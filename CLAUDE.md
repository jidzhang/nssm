# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

NSSM (Non-Sucking Service Manager) is a single-executable Windows NT service wrapper written in Win32 native C++. It starts any application as a Windows service, monitors it, and restarts it on failure. Supports GUI and CLI for install/remove/edit/control. Public Domain.

## Build

**VS2019 (v142) + Windows 10 SDK.** No standalone build scripts — use MSBuild or Visual Studio.

```bash
# Build Release x64 (via .bat wrapper, not direct cl.exe)
# In a VS Developer Command Prompt:
msbuild nssm.vcxproj /p:Configuration=Release /p:Platform=x64

# Or open nssm.sln / nssm140.sln in Visual Studio
```

Four configurations: `Debug|Win32`, `Debug|x64`, `Release|Win32`, `Release|x64`. Output goes to `out/<Config>/win32|win64/`. Intermediate files in `tmp/`.

**Pre-build step:** `version.cmd` runs `git describe --tags --long` and generates `version.h`. If not on a tagged commit, the version shows as prerelease.

**Message compiler:** `messages.mc` is compiled by `mc -u -U` into `messages.h`, `messages.rc`, and `MSG*.bin` files. Three languages: English, French, Italian.

**Linked libraries:** `psapi.lib`, `shlwapi.lib`. Unicode character set.

## C++ Standard

**C++03** — must remain compatible with older MSVC versions. No C++11/14/17 features. Target `_WIN32_WINNT 0x0500` (Windows 2000+).

## Architecture

Single entry point `_tmain()` in `nssm.cpp` dispatches to two modes:

### CLI mode (`nssm install|remove|edit|start|stop|restart|status|...`)
- Commands dispatched via string comparison in `_tmain()`
- Service operations delegate to `service.cpp` functions
- Settings get/set/dump handled by `settings.cpp` abstraction layer
- GUI launched via `nssm_gui()` in `gui.cpp`

### Service mode (SCM calls `service_main()`)
- `service.cpp` owns `nssm_service_t` struct (~123 fields) — all runtime state
- Config persisted in registry: `HKLM\SYSTEM\CurrentControlSet\Services\<name>\Parameters\`
- `registry.cpp` handles all registry I/O
- `io.cpp` creates background threads for stdout/stderr pipe → file with rotation
- `process.cpp` implements graceful shutdown: Ctrl-C → WM_CLOSE → WM_QUIT → TerminateProcess
- `hook.cpp` runs user-configured commands on lifecycle events (start/stop/exit/rotate/power)
- `monitor_service()` loop: start → wait → on exit decide action (restart/exit/suicide) → throttle if too fast

### Module responsibilities

| Module | Role |
|--------|------|
| `nssm.cpp/h` | Entry point, CLI dispatch, utility functions |
| `service.cpp/h` | Service lifecycle, install/remove/edit, monitoring, throttling |
| `gui.cpp/h` | Win32 tabbed property sheet (12 tabs) for service config |
| `process.cpp/h` | Process tree walking, graceful shutdown methods |
| `registry.cpp/h` | Registry persistence, parameter read/write |
| `settings.cpp/h` | Parameter name → get/set/dump function mapping |
| `io.cpp/h` | Pipe-based I/O redirection, log rotation thread |
| `hook.cpp/h` | Lifecycle event hooks with timeout enforcement |
| `account.cpp/h` | LSA policy, SID lookup, logon-as-service right |
| `event.cpp/h` | Event logging, error string formatting |
| `env.cpp/h` | Windows environment block manipulation |
| `console.cpp/h` | Console detection and allocation |
| `imports.cpp/h` | Dynamic API imports for backward compatibility |
| `utf8.cpp/h` | UTF-8/UTF-16 conversion, console codepage setup |

`nssm.h` is the master header that includes all others and defines shared constants (path lengths, throttle timers, stop methods, exit actions, priority classes).
