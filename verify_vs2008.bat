@echo off
setlocal enabledelayedexpansion

rem ============================================================
rem  VS2008 32-bit Full Verification
rem
rem  1. Build NSSM Release Win32  (devenv.com)
rem  2. Build demo_svc.exe        (cl.exe via vcvars)
rem  3. Copy both to demo\ directory
rem  4. Install -> Start -> Test HTTP -> Stop -> Remove
rem  5. Verify service fully removed
rem
rem  Must run as Administrator.
rem ============================================================

cd /d "%~dp0"

if not defined VS90COMNTOOLS (
    echo [ERROR] VS90COMNTOOLS not set. Is VS2008 installed?
    exit /b 1
)
set "DEVENV=%VS90COMNTOOLS%\..\IDE\devenv.com"
if not exist "%DEVENV%" echo [ERROR] devenv.com not found: "%DEVENV%" & exit /b 1

set "VCVARS=%VS90COMNTOOLS%\..\..\VC\bin\vcvars32.bat"
if not exist "%VCVARS%" echo [ERROR] vcvars32.bat not found: "%VCVARS%" & exit /b 1

echo ============================================
echo   VS2008 32-bit Full Verification
echo ============================================
echo.

rem ---- 1. Build NSSM Release Win32 ----
echo [1/6] Building NSSM Release Win32 (devenv.com) ...
"%DEVENV%" nssm90.sln /Build "Release|Win32"
if errorlevel 1 echo [FAILED] NSSM build & exit /b 1
echo       OK
echo.

rem ---- 2. Build demo_svc (needs cl.exe from vcvars) ----
echo [2/6] Building demo_svc.exe ...
call "%VCVARS%" >nul 2>&1
pushd demo
cl -nologo -c -O2 -MT -W3 -D_CRT_SECURE_NO_WARNINGS -DUNICODE -D_UNICODE demo_svc.cpp
if errorlevel 1 echo [FAILED] demo_svc compile & popd & exit /b 1
link.exe -nologo -OUT:demo_svc.exe -SUBSYSTEM:CONSOLE demo_svc.obj ws2_32.lib
if errorlevel 1 echo [FAILED] demo_svc link & popd & exit /b 1
popd
echo       OK
echo.

rem ---- 3. Copy to demo directory ----
echo [3/6] Copying nssm.exe to demo\ ...
copy /Y out\Release\win32\nssm.exe demo\nssm.exe >nul
if errorlevel 1 echo [FAILED] Copy nssm.exe & exit /b 1
echo       demo\nssm.exe      - copied
echo       demo\demo_svc.exe  - built
echo.

set NSSM=%cd%\demo\nssm.exe
set APP=%cd%\demo\demo_svc.exe
set SVC=demo_vs2008
set PORT=18081

rem ---- 4. Install + Start + Test ----
echo [4/6] Installing service '%SVC%' ...
"%NSSM%" install %SVC% "%APP%" %PORT%
if errorlevel 1 goto cleanup
echo       OK
echo.

echo [5/6] Starting service ...
"%NSSM%" start %SVC%
if errorlevel 1 echo [WARN] Start returned non-zero, checking status ...

set TRIES=0
:waitloop
set /a TRIES+=1
if !TRIES! GTR 15 goto cleanup
ping -n 2 127.0.0.1 >nul
"%NSSM%" status %SVC% 2>nul | findstr /i "RUNNING" >nul
if errorlevel 1 goto waitloop
echo       Service is RUNNING
echo.

echo       Testing HTTP (http://localhost:%PORT%/health) ...
powershell -Command "$r=Invoke-WebRequest -Uri 'http://localhost:%PORT%/health' -TimeoutSec 5 -UseBasicParsing;if($r.StatusCode -eq 200){exit 0}else{exit 1}" >nul 2>&1
if not errorlevel 1 echo       /health returned 200 OK
if errorlevel 1 echo       [WARN] Could not reach endpoint.
echo.
echo       Service is running. Waiting 15 seconds for manual verification ...
echo       Open http://localhost:%PORT%/health in a browser to check.
ping -n 16 127.0.0.1 >nul
echo.

echo       Status:
"%NSSM%" status %SVC%
echo       AppExit default:
"%NSSM%" get %SVC% AppExit Default 2>nul
echo.

rem ---- 6. Stop + Remove + Verify ----
:cleanup
echo [6/6] Stopping service ...
"%NSSM%" stop %SVC% 2>nul
ping -n 3 127.0.0.1 >nul

echo       Removing service ...
"%NSSM%" remove %SVC% confirm 2>nul

ping -n 2 127.0.0.1 >nul

echo       Verifying removal ...
"%NSSM%" status %SVC% 2>nul
if not errorlevel 1 echo [WARN] Service still exists!
if errorlevel 1 echo       Service confirmed removed.
echo.

echo ============================================
echo   VS2008 32-bit Verification Complete.
echo ============================================
endlocal
exit /b 0
