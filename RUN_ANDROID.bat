@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: Flutter no esta en PATH.
  pause
  exit /b 1
)
if not exist "android" flutter create --platforms android .
if errorlevel 1 goto :fail
flutter pub get
if errorlevel 1 goto :fail
flutter devices
 echo.
echo Selecciona tu Android conectado en la lista anterior.
flutter run
if errorlevel 1 goto :fail
exit /b 0
:fail
echo No se pudo iniciar la aplicacion. Revisa Flutter, Android SDK y la autorizacion USB.
pause
exit /b 1
