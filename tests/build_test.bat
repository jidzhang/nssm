@echo off
setlocal

cd /d "%~dp0"

set ARCH=%~1
if "%ARCH%"=="" set ARCH=x86
if /i not "%ARCH%"=="x86" if /i not "%ARCH%"=="x64" (
    echo [ERROR] Unknown arch: %ARCH%. Use x86 or x64.
    exit /b 1
)
set EXE=test_nssm_%ARCH%.exe

echo Compiling %EXE% (%ARCH%) ...
cl -nologo -utf-8 -EHsc -W3 -DUNICODE -D_UNICODE -D_CRT_SECURE_NO_WARNINGS -I.. test_main.cpp test_basic.cpp test_str.cpp test_quote.cpp test_path.cpp test_priority.cpp test_affinity.cpp nssm_testable.cpp /Fe:%EXE%
if errorlevel 1 (
    echo [FAILED] Compilation
    exit /b 1
)

echo [OK] Build succeeded: %EXE%
exit /b 0
