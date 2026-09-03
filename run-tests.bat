@echo off
setlocal
set "LOVE=C:\Program Files\LOVE\lovec.exe"
if not exist "%LOVE%" for /f "delims=" %%i in ('where lovec 2^>nul') do set "LOVE=%%i"
if not exist "%LOVE%" for /f "delims=" %%i in ('where love 2^>nul') do set "LOVE=%%i"
if not exist "%LOVE%" (
  echo LOVE not found. Install from https://love2d.org or add lovec to PATH.
  exit /b 1
)
rem FRAMEWORK_CHECK=<module> must run the single check WITHOUT --test:
rem the --test flag outranks the check runner inside main.lua
if defined FRAMEWORK_CHECK goto check
"%LOVE%" "%~dp0." --test
exit /b %ERRORLEVEL%
:check
"%LOVE%" "%~dp0."
exit /b %ERRORLEVEL%
