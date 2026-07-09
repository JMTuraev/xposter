@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"
echo ============================================
echo   Buxoro POS - Flutter setup va ishga tushirish
echo ============================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo [XATO] Flutter topilmadi.
  echo Iltimos Flutter SDK o'rnating: https://docs.flutter.dev/get-started/install/windows
  echo Keyin ushbu faylni qayta ishga tushiring.
  pause
  exit /b 1
)

if not exist "android" (
  echo Platforma fayllari yaratilmoqda ^(android^)...
  if exist "pubspec.yaml" ren "pubspec.yaml" "pubspec.keep.yaml"
  if exist "lib" ren "lib" "lib_keep"
  call flutter create --project-name buxoro_pos --org com.buxoropos --platforms=android .
  if exist "pubspec.yaml" del /q "pubspec.yaml"
  if exist "pubspec.keep.yaml" ren "pubspec.keep.yaml" "pubspec.yaml"
  if exist "lib" rmdir /s /q "lib"
  if exist "lib_keep" ren "lib_keep" "lib"
  if exist "test" rmdir /s /q "test"
  echo Platforma fayllari tayyor.
  echo.
)

echo Paketlar yuklanmoqda ^(flutter pub get^)...
call flutter pub get
echo.

echo Ulangan qurilmalar:
call flutter devices
echo.

echo Ishga tushirilmoqda. Android qurilmangiz USB orqali ulangan va
echo "USB debugging" yoqilgan bo'lishi kerak.
echo.
call flutter run
pause
