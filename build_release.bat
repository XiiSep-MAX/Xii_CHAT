@echo off
setlocal enableextensions enabledelayedexpansion

cd /d "%~dp0"

set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "OUTPUT_ROOT=release\READY_TO_SEND\Portable_ZIP"
set "APP_VERSION=1.2.5"
set "PACKAGE_PREFIX=Xii_Raw_Graph_Trial"
set "DOWNLOADS_DIR=downloads"
set "HASH_OUTPUT=release\READY_TO_SEND\package_sha256.txt"
set "HASH_PUBLIC_FILE=%DOWNLOADS_DIR%\%PACKAGE_PREFIX%_v%APP_VERSION%.sha256.txt"
set "LATEST_ASSET_NAME=%PACKAGE_PREFIX%_latest.zip"
set "LATEST_HASH_PUBLIC_FILE=%DOWNLOADS_DIR%\%PACKAGE_PREFIX%_latest.sha256.txt"
set "RELEASE_DOWNLOAD_URL=https://github.com/XiiSep-MAX/Xii_CHAT/releases/latest/download/%LATEST_ASSET_NAME%"

for /f "tokens=2 delims=:, " %%i in ('findstr /i "\"version\"" version.json') do (
  set "APP_VERSION=%%~i"
)

set "ZIP_OUTPUT=release\READY_TO_SEND\%PACKAGE_PREFIX%_v%APP_VERSION%.zip"
set "LATEST_ZIP_OUTPUT=release\READY_TO_SEND\%LATEST_ASSET_NAME%"

echo ==========================================
echo Building portable ZIP package
echo ==========================================

echo 1. Building Windows release...
call flutter build windows --release
if errorlevel 1 (
  echo [ERROR] Windows release build failed.
  exit /b 1
)

echo 2. Building updater helper...
if not exist "build\portable_updater" mkdir "build\portable_updater"
call dart compile exe tool\portable_updater.dart -o build\portable_updater\xii_updater.exe
if errorlevel 1 (
  echo [ERROR] Updater helper build failed.
  exit /b 1
)

copy /y "build\portable_updater\xii_updater.exe" "build\windows\x64\runner\Release\xii_updater.exe" >nul
if errorlevel 1 (
  echo [ERROR] Failed to copy updater helper into release output.
  exit /b 1
)

if exist "build\windows\x64\runner\Release\.env" (
  echo [INFO] Removing stale .env from build output...
  del /f /q "build\windows\x64\runner\Release\.env"
)

if exist "%OUTPUT_ROOT%" rmdir /s /q "%OUTPUT_ROOT%"
mkdir "%OUTPUT_ROOT%"

echo 3. Copying portable runtime files...
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

echo 4. Creating ZIP archive...
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

copy /y "%ZIP_OUTPUT%" "%DOWNLOADS_DIR%\%LATEST_ASSET_NAME%" >nul
if errorlevel 1 (
  echo [ERROR] Failed to sync latest ZIP into repository downloads directory.
  exit /b 1
)

copy /y "%ZIP_OUTPUT%" "%LATEST_ZIP_OUTPUT%" >nul
if errorlevel 1 (
  echo [ERROR] Failed to create local latest ZIP copy.
  exit /b 1
)

echo 5. Calculating SHA-256...
call dart run tool\prepare_version_metadata.dart version.json "%DOWNLOADS_DIR%\%LATEST_ASSET_NAME%" "%HASH_OUTPUT%" "%HASH_PUBLIC_FILE%" "%LATEST_HASH_PUBLIC_FILE%" "%RELEASE_DOWNLOAD_URL%"
if errorlevel 1 (
  echo [ERROR] Failed to calculate SHA-256 or update version.json.
  exit /b 1
)

echo 6. Signing version metadata...
call dart run tool\sign_version_metadata.dart version.json
if errorlevel 1 (
  echo [ERROR] Failed to sign version.json.
  exit /b 1
)

echo.
echo Portable ZIP package created successfully:
echo   Staging: %OUTPUT_ROOT%
echo   Zip:    %ZIP_OUTPUT%
echo   Repo:   %DOWNLOADS_DIR%\%PACKAGE_PREFIX%_v%APP_VERSION%.zip
echo   Latest: %DOWNLOADS_DIR%\%LATEST_ASSET_NAME%
echo   SHA256: %HASH_OUTPUT%
echo   Public: %HASH_PUBLIC_FILE%
echo   Latest SHA256: %LATEST_HASH_PUBLIC_FILE%
echo   Release URL: %RELEASE_DOWNLOAD_URL%
echo.
echo Recommended next step:
echo   Upload %LATEST_ASSET_NAME% to the latest GitHub Release, then commit and push the updated page and version metadata.

endlocal
