@echo off
setlocal
cd /d "%~dp0"
echo ==============================================
echo           eShokFix Mobile - APK DEBUG
echo ==============================================
echo.
where flutter >nul 2>nul
if errorlevel 1 (
  echo No encuentro Flutter en PATH.
  echo Abre este proyecto desde Android Studio con el plugin Flutter.
  echo O configura Flutter SDK en Android Studio y vuelve a intentarlo.
  pause
  exit /b 1
)
flutter pub get
if errorlevel 1 goto error
flutter analyze
if errorlevel 1 goto error
flutter test
if errorlevel 1 goto error
flutter build apk --debug
if errorlevel 1 goto error
echo.
echo APK creada en:
echo %CD%\build\app\outputs\flutter-apk\app-debug.apk
explorer "%CD%\build\app\outputs\flutter-apk"
pause
exit /b 0
:error
echo.
echo Hubo un error. Revisa el mensaje anterior.
pause
exit /b 1
