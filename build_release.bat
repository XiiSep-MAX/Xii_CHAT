@echo off
setlocal enableextensions enabledelayedexpansion

cd /d "%~dp0"

set "POWERSHELL_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "OUTPUT_ROOT=release\READY_TO_SEND\Portable_ZIP"
set "APP_VERSION=1.2.16"
set "PACKAGE_PREFIX=Xii_Raw_Graph_Trial"
set "DOWNLOADS_DIR=downloads"
set "HASH_OUTPUT=release\READY_TO_SEND\package_sha256.txt"

for /f "tokens=2 delims=:, " %%i in ('findstr /i "\"version\"" version.json') do (
  set "APP_VERSION=%%~i"
)

set "ZIP_OUTPUT=release\READY_TO_SEND\%PACKAGE_PREFIX%_v%APP_VERSION%.zip"
set "HASH_PUBLIC_FILE=%DOWNLOADS_DIR%\%PACKAGE_PREFIX%_v%APP_VERSION%.sha256.txt"

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
if exist "build\windows\x64\runner\Release\*.msix" (
  echo [INFO] Removing stale .msix from build output...
  del /f /q "build\windows\x64\runner\Release\*.msix"
)

if exist "%OUTPUT_ROOT%" rmdir /s /q "%OUTPUT_ROOT%"
mkdir "%OUTPUT_ROOT%"

echo 3. Copying portable runtime files...
robocopy "build\windows\x64\runner\Release" "%OUTPUT_ROOT%" /E /NFL /NDL /NJH /NJS /NC /NS /XF *.msix >nul
if errorlevel 8 (
  echo [ERROR] Failed to copy the Windows release files.
  exit /b 1
)

copy /y "USER_SETUP_GUIDE.md" "%OUTPUT_ROOT%\" >nul
copy /y "PORTABLE_PACKAGE_README.md" "%OUTPUT_ROOT%\" >nul
copy /y "CONTACT_AUTHOR_WX.txt" "%OUTPUT_ROOT%\" >nul
copy /y "RELEASE_PACKAGE_README.txt" "%OUTPUT_ROOT%\" >nul

if exist "%OUTPUT_ROOT%\USER_SETUP_GUIDE.md" del /f /q "%OUTPUT_ROOT%\USER_SETUP_GUIDE.md"
if exist "%OUTPUT_ROOT%\PORTABLE_PACKAGE_README.md" del /f /q "%OUTPUT_ROOT%\PORTABLE_PACKAGE_README.md"

if exist "%OUTPUT_ROOT%\.env" del /f /q "%OUTPUT_ROOT%\.env"
if exist ".env.example" (
  copy /y ".env.example" "%OUTPUT_ROOT%\.env" >nul
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

echo 5. Calculating SHA-256...
call dart run tool\prepare_version_metadata.dart version.json "%DOWNLOADS_DIR%\%PACKAGE_PREFIX%_v%APP_VERSION%.zip" "%HASH_OUTPUT%" "%HASH_PUBLIC_FILE%"
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
echo   SHA256: %HASH_OUTPUT%
echo   Public: %HASH_PUBLIC_FILE%
echo.
echo Recommended next step:
echo   Commit and push the updated ZIP, SHA256 file, index.html, and version.json to GitHub.

endlocal
