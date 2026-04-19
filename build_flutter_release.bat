@echo off
setlocal

set "ROOT_DIR=%~dp0"
set "APP_DIR=%ROOT_DIR%mobile_app"

set "TURN_URLS=turn:83.217.201.40:3478"
set "TURN_USERNAME=MessangerCHTPCHAT"
set "TURN_CREDENTIAL=VhQS0RR6dKli7fMVe-Y6hg5m5N6C7N"

if not exist "%APP_DIR%\pubspec.yaml" (
    echo [ERROR] Flutter project not found: "%APP_DIR%"
    exit /b 1
)

pushd "%APP_DIR%" || exit /b 1

echo.
echo === Flutter clean ===
call flutter clean
if errorlevel 1 goto :fail

echo.
echo === Flutter pub get ===
call flutter pub get
if errorlevel 1 goto :fail

echo.
echo === Build Android APK (release) ===
call flutter build apk --release ^
  --dart-define=WEBRTC_TURN_URLS=%TURN_URLS% ^
  --dart-define=WEBRTC_TURN_USERNAME=%TURN_USERNAME% ^
  --dart-define=WEBRTC_TURN_CREDENTIAL=%TURN_CREDENTIAL%
if errorlevel 1 goto :fail

echo.
echo === Build Windows (release) ===
call flutter build windows --release ^
  --dart-define=WEBRTC_TURN_URLS=%TURN_URLS% ^
  --dart-define=WEBRTC_TURN_USERNAME=%TURN_USERNAME% ^
  --dart-define=WEBRTC_TURN_CREDENTIAL=%TURN_CREDENTIAL%
if errorlevel 1 goto :fail

echo.
echo === Done ===
echo APK: %APP_DIR%\build\app\outputs\flutter-apk\app-release.apk
echo Windows: %APP_DIR%\build\windows\x64\runner\Release
popd
exit /b 0

:fail
set "EXIT_CODE=%ERRORLEVEL%"
echo.
echo [ERROR] Build failed with code %EXIT_CODE%.
popd
exit /b %EXIT_CODE%
