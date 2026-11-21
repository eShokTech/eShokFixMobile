@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo ERROR: Flutter no esta en PATH. Instala Flutter SDK y abre una terminal nueva.
  pause
  exit /b 1
)
if not exist "android" (
  echo Generando archivos de plataforma Android...
  flutter create --platforms android .
  if errorlevel 1 goto :fail
)
echo Resolviendo dependencias...
flutter pub get
if errorlevel 1 goto :fail
echo Analizando codigo...
flutter analyze --no-pub
if errorlevel 1 goto :fail
echo Ejecutando pruebas...
flutter test --no-pub
if errorlevel 1 goto :fail
echo Compilando APK de depuracion...
flutter build apk --debug --no-pub
if errorlevel 1 goto :fail
if not exist "dist" mkdir "dist"
copy /Y "build\app\outputs\flutter-apk\app-debug.apk" "dist\eShokFix-Mobile-debug.apk" >nul
 echo.
echo APK lista: %~dp0dist\eShokFix-Mobile-debug.apk
pause
exit /b 0
:fail
echo.
echo La preparacion fallo. Revisa el primer error mostrado arriba.
pause
exit /b 1
