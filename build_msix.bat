@echo off
setlocal enableextensions enabledelayedexpansion

cd /d "%~dp0"

echo ================================
echo Building Xii_Raw Graph MSIX package
echo ================================

echo 1. Building Windows release...
flutter build windows --release
if errorlevel 1 (
  echo [ERROR] Windows release build failed.
  exit /b 1
)

echo 2. Creating MSIX package...
dart run msix:create --certificate-path cert.pfx --certificate-password 1234
if errorlevel 1 (
  echo [ERROR] MSIX package creation failed.
  exit /b 1
)

echo ================================
echo MSIX package created successfully.
echo Please check the output directory for the generated .msix file.
echo ================================

endlocal
