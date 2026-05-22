@echo off
setlocal enabledelayedexpansion

echo ============================================
echo   NSSM - Run All Tests
echo ============================================
echo.

REM -----------------------------------------------------------------------
REM Find and load MSVC environment (cl.exe, link.exe)
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
echo [INFO] Loading MSVC environment...
call "!VCVARS!" x64 >nul 2>&1

set ERRORS=0

echo.
echo [1/3] Building unit tests...
pushd tests
call build_test.bat
if errorlevel 1 (
    echo [FAILED] Unit test build
    set /a ERRORS+=1
    popd
    goto :inttest
)
popd

echo.
echo [2/3] Running unit tests...
tests\test_nssm.exe --reporter compact
if errorlevel 1 (
    echo [FAILED] Unit tests
    set /a ERRORS+=1
) else (
    echo       OK
)

:inttest
echo.
echo [3/3] Running integration tests...
powershell -ExecutionPolicy Bypass -Command "& '.\tests\integration\run_tests.ps1'"
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
