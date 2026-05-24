@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

echo ============================================
echo   NSSM - Run All Tests (x86 + x64)
echo ============================================
echo.

REM -----------------------------------------------------------------------
REM Find vcvarsall.bat
REM -----------------------------------------------------------------------
set VCVARS=
for %%E in (Enterprise Professional Community) do (
    for %%Y in (2019 2022) do (
        set "CHECK=%ProgramFiles(x86)%\Microsoft Visual Studio\%%Y\%%E\VC\Auxiliary\Build\vcvarsall.bat"
        if exist "!CHECK!" set "VCVARS=!CHECK!"
    )
)
if not defined VCVARS (
    echo [ERROR] vcvarsall.bat not found. Run from VS Developer Command Prompt.
    exit /b 1
)
echo [INFO] vcvarsall.bat: !VCVARS!

set ERRORS=0

REM -----------------------------------------------------------------------
REM x64 unit tests
REM -----------------------------------------------------------------------
echo.
echo [1/5] Loading x64 MSVC environment...
call "!VCVARS!" x64 >nul 2>&1

echo [2/5] Building x64 unit tests...
call tests\build_test.bat x64
cd /d "%~dp0"
if errorlevel 1 (
    echo [FAILED] x64 unit test build
    set /a ERRORS+=1
    goto :x86_unit
)

echo       Running x64 unit tests...
tests\test_nssm_x64.exe --reporter compact
if errorlevel 1 (
    echo [FAILED] x64 unit tests
    set /a ERRORS+=1
) else (
    echo       OK
)

REM -----------------------------------------------------------------------
REM x86 unit tests
REM -----------------------------------------------------------------------
:x86_unit
echo.
echo       Cleaning intermediate files...
del /q tests\*.obj 2>nul

echo [3/5] Loading x86 MSVC environment and building x86 unit tests...
call "!VCVARS!" x86 >nul 2>&1

call tests\build_test.bat x86
cd /d "%~dp0"
if errorlevel 1 (
    echo [FAILED] x86 unit test build
    set /a ERRORS+=1
    goto :inttest
)

echo [4/5] Running x86 unit tests...
tests\test_nssm_x86.exe --reporter compact
if errorlevel 1 (
    echo [FAILED] x86 unit tests
    set /a ERRORS+=1
) else (
    echo       OK
)

REM -----------------------------------------------------------------------
REM Integration tests (PowerShell finds MSBuild independently)
REM -----------------------------------------------------------------------
:inttest
echo.
echo [5/5] Running integration tests...
powershell -ExecutionPolicy Bypass -File "%~dp0tests\integration\run_tests.ps1"
if errorlevel 1 (
    set /a ERRORS+=1
)

echo.
echo ============================================
if !ERRORS! equ 0 (
    echo ALL TESTS PASSED
) else (
    echo !ERRORS! test suite(s) FAILED
)
echo ============================================
exit /b !ERRORS!
