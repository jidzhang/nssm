@echo off
rem run_tests.bat - Batch wrapper for running NSSM integration tests.
rem Must be run as Administrator from a VS Developer Command Prompt.
rem
rem Usage:
rem   run_tests.bat                   -- Build and run all tests
rem   run_tests.bat -SkipBuild        -- Run tests without building
rem   run_tests.bat -Tests Lifecycle  -- Run only Lifecycle tests

powershell -ExecutionPolicy Bypass -File "%~dp0run_tests.ps1" %*
exit /b %errorlevel%
