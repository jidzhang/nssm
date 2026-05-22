@echo off
setlocal

echo Cleaning build artifacts...

REM Build output
if exist out  rmdir /s /q out

REM Intermediate files
if exist tmp  rmdir /s /q tmp

REM VS cache
if exist .vs  rmdir /s /q .vs

REM Generated files from mc.exe
del /q MSG*.bin    2>nul
del /q messages.h  2>nul
del /q messages.rc 2>nul

REM Generated version header
del /q version.h   2>nul

REM Unit test binary and object files
if exist tests\test_nssm.exe  del /q tests\test_nssm.exe
if exist tests\*.obj          del /q tests\*.obj

REM Integration test results
if exist tests\integration\TestResults.xml  del /q tests\integration\TestResults.xml

REM Upgrade log
del /q UpgradeLog.htm 2>nul

echo Done.
exit /b 0
