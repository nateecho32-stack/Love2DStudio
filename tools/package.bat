@echo off
rem Packages the studio (or a game embedding it) into a .love file via an
rem explicit ALLOWLIST — dev-only folders are excluded by construction, so a
rem shipped build cannot contain tests or tooling (2d Trippy Hell model).
rem Usage: package.bat [out.love] [rootDir]
setlocal enabledelayedexpansion
set "ROOT=%~dp0.."
if not "%~2"=="" set "ROOT=%~2"
set "OUT=%~1"
if "%OUT%"=="" set "OUT=%ROOT%\love2d-studio.love"

rem Staging allowlist: folders + root files that ship
set "STAGE=%TEMP%\studio_stage_%RANDOM%"
mkdir "%STAGE%" 2>nul
for %%D in (core render save audio ui editor content sample tools template) do (
  if exist "%ROOT%\%%D" xcopy /e /i /q "%ROOT%\%%D" "%STAGE%\%%D" >nul
)
for %%F in (init.lua main.lua conf.lua demo.lua play.lua archetypes.lua version.lua) do (
  if exist "%ROOT%\%%F" copy /y /q "%ROOT%\%%F" "%STAGE%" >nul
)
if exist "%ROOT%\sample" (
  copy /y /q "%ROOT%\sample\*.lua" "%STAGE%\sample" >nul 2>nul
)

rem .love is a zip — entries MUST use forward slashes at the zip root
rem (Compress-Archive writes backslashes, which LÖVE cannot read)
powershell -NoProfile -Command ^
  "Add-Type -AssemblyName System.IO.Compression.FileSystem;" ^
  "$zip = [System.IO.Compression.ZipFile]::Open('%OUT%', 'Create');" ^
  "Get-ChildItem -Recurse '%STAGE%' -File | ForEach-Object {" ^
  "  $rel = $_.FullName.Substring((Resolve-Path '%STAGE%').Path.Length + 1).Replace('\','/');" ^
  "  [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel)" ^
  "};" ^
  "$zip.Dispose()"
rmdir /s /q "%STAGE%"
echo packaged: %OUT%
endlocal
