@echo off
setlocal enableextensions enabledelayedexpansion

cd /d "%~dp0"

set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "OUTPUT_ROOT=release\READY_TO_SEND\Portable_ZIP"
set "APP_VERSION=1.2.0"
set "PACKAGE_PREFIX=Xii_Raw_Graph_Trial"
set "DOWNLOADS_DIR=downloads"

for /f "tokens=2 delims=:, " %%i in ('findstr /i "\"version\"" version.json') do (
  set "APP_VERSION=%%~i"
)

set "ZIP_OUTPUT=release\READY_TO_SEND\%PACKAGE_PREFIX%_v%APP_VERSION%.zip"

echo ==========================================
echo Building portable ZIP package
echo ==========================================

echo 1. Building Windows release...
call flutter build windows --release
if errorlevel 1 (
  echo [ERROR] Windows release build failed.
  exit /b 1
)

if exist "build\windows\x64\runner\Release\.env" (
  echo [INFO] Removing stale .env from build output...
  del /f /q "build\windows\x64\runner\Release\.env"
)

if exist "%OUTPUT_ROOT%" rmdir /s /q "%OUTPUT_ROOT%"
mkdir "%OUTPUT_ROOT%"

echo 2. Copying portable runtime files...
xcopy /e /i /y "build\windows\x64\runner\Release\*" "%OUTPUT_ROOT%\" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy the Windows release files.
  exit /b 1
)

copy /y "USER_SETUP_GUIDE.md" "%OUTPUT_ROOT%\" >nul
copy /y "PORTABLE_PACKAGE_README.md" "%OUTPUT_ROOT%\" >nul
copy /y "CONTACT_AUTHOR_WX.txt" "%OUTPUT_ROOT%\" >nul

if exist "%OUTPUT_ROOT%\.env" del /f /q "%OUTPUT_ROOT%\.env"
if exist ".env.example" (
  copy /y ".env.example" "%OUTPUT_ROOT%\.env.example" >nul
)

echo 3. Creating ZIP archive...
"%POWERSHELL_EXE%" -NoProfile -ExecutionPolicy Bypass -Command "if (Test-Path '%~dp0%ZIP_OUTPUT%') { Remove-Item '%~dp0%ZIP_OUTPUT%' -Force }; Compress-Archive -Path '%~dp0%OUTPUT_ROOT%\*' -DestinationPath '%~dp0%ZIP_OUTPUT%'"
if errorlevel 1 (
  echo [ERROR] Failed to create the ZIP archive.
  exit /b 1
)

if not exist "%DOWNLOADS_DIR%" mkdir "%DOWNLOADS_DIR%"
copy /y "%ZIP_OUTPUT%" "%DOWNLOADS_DIR%\%PACKAGE_PREFIX%_v%APP_VERSION%.zip" >nul
if errorlevel 1 (
  echo [ERROR] Failed to sync ZIP into repository downloads directory.
  exit /b 1
)

echo.
echo Portable ZIP package created successfully:
echo   Staging: %OUTPUT_ROOT%
echo   Zip:    %ZIP_OUTPUT%
echo   Repo:   %DOWNLOADS_DIR%\%PACKAGE_PREFIX%_v%APP_VERSION%.zip
echo.
echo Recommended next step:
echo   Commit and push the updated ZIP, index.html, and version.json to GitHub.

endlocal
