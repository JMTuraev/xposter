@echo off
setlocal
cd /d "%~dp0"
echo ============================================
echo   Buxoro POS - qayta yig'ish va o'rnatish
echo ============================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo [XATO] Flutter topilmadi. SDK o'rnatilganini tekshiring.
  pause
  exit /b 1
)

if not exist "android" (
  echo [XATO] android/ papkasi yo'q. Avval setup_and_run.bat ni ishga tushiring.
  pause
  exit /b 1
)

echo Paketlar yuklanmoqda (flutter pub get)...
call flutter pub get
echo.

echo APK qayta yig'ilmoqda (flutter build apk --debug)...
echo Bu 1-5 daqiqa olishi mumkin, kuting...
call flutter build apk --debug
if errorlevel 1 (
  echo [XATO] Build muvaffaqiyatsiz tugadi. Yuqoridagi xatoni ko'ring.
  pause
  exit /b 1
)
echo APK tayyor.
echo.

set "ADB=C:\Users\user\AppData\Local\Android\sdk\platform-tools\adb.exe"
if not exist "%ADB%" set "ADB=adb"
set "APK=build\app\outputs\flutter-apk\app-debug.apk"

echo Ulangan qurilmalar:
"%ADB%" devices
echo.

echo APK telefonga o'rnatilmoqda (-r bilan, ustiga yozadi)...
"%ADB%" install -r "%APK%"
echo.

echo Ilova ishga tushirilmoqda...
"%ADB%" shell am start -n com.buxoropos.buxoro_pos/com.buxoropos.buxoro_pos.MainActivity
echo.
echo ============================================
echo   Tayyor! Telefonda "buxoro_pos" ochilishi kerak.
echo ============================================
pause
