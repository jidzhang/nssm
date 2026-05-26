@echo off
setlocal

cd /d "%~dp0"

rem Initialize VS2008 x86 build environment
if not defined VS90COMNTOOLS (
    echo [ERROR] VS90COMNTOOLS not set. Is VS2008 installed?
    exit /b 1
)
set "VCVARS=%VS90COMNTOOLS%\..\..\VC\bin\vcvars32.bat"
if not exist "%VCVARS%" echo [ERROR] vcvars32.bat not found & exit /b 1
call "%VCVARS%" >nul 2>&1

echo Compiling demo_svc.cpp ...
cl -nologo -c -O2 -MT -W3 -D_CRT_SECURE_NO_WARNINGS -DUNICODE -D_UNICODE demo_svc.cpp
if errorlevel 1 (
    echo [FAILED] Compile
    exit /b 1
)

echo Linking demo_svc.exe ...
link -nologo -OUT:demo_svc.exe -SUBSYSTEM:CONSOLE demo_svc.obj ws2_32.lib
if errorlevel 1 (
    echo [FAILED] Link
    exit /b 1
)

echo [OK] demo_svc.exe built successfully
echo.
echo Usage:
echo   nssm install demo_svc "%cd%\demo_svc.exe" 18080
echo   nssm start demo_svc
echo   http://localhost:18080/
echo   nssm stop demo_svc
echo   nssm remove demo_svc confirm

exit /b 0
