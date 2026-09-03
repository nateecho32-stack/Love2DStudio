@echo off
setlocal
set "LOVE=C:\Program Files\LOVE\lovec.exe"
if not exist "%LOVE%" for /f "delims=" %%i in ('where lovec 2^>nul') do set "LOVE=%%i"
if not exist "%LOVE%" for /f "delims=" %%i in ('where love 2^>nul') do set "LOVE=%%i"
if not exist "%LOVE%" (
  echo LOVE not found. Install from https://love2d.org or add lovec to PATH.
  exit /b 1
)
"%LOVE%" "%~dp0."
