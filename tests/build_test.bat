@echo off
setlocal

cd /d "%~dp0"

echo Compiling test_nssm.exe ...
cl -nologo -utf-8 -EHsc -W3 -DUNICODE -D_UNICODE -D_CRT_SECURE_NO_WARNINGS -I.. test_main.cpp test_basic.cpp test_str.cpp test_quote.cpp test_path.cpp test_priority.cpp test_affinity.cpp nssm_testable.cpp /Fe:test_nssm.exe
if errorlevel 1 (
    echo [FAILED] Compilation
    exit /b 1
)

echo [OK] Build succeeded
exit /b 0
