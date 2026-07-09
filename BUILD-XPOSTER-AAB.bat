@echo off
setlocal
cd /d "%~dp0"
set "LOG=D:\poster\_play_build_log.txt"
echo ==== XPOSTER AAB BUILD %DATE% %TIME% ==== > "%LOG%"

echo [1/3] Keystore tayyorlanmoqda... >> "%LOG%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0android_keystore.ps1"
echo ---KEYSTORE-EXIT=%ERRORLEVEL%--- >> "%LOG%"

echo [2/3] flutter pub get... >> "%LOG%"
call flutter pub get >> "%LOG%" 2>&1
echo ---PUBGET-EXIT=%ERRORLEVEL%--- >> "%LOG%"

echo [3/3] flutter build appbundle --release... >> "%LOG%"
call flutter build appbundle --release >> "%LOG%" 2>&1
echo ---BUILD-EXIT=%ERRORLEVEL%--- >> "%LOG%"

if exist "build\app\outputs\bundle\release\app-release.aab" (
  echo ---AAB-OK--- >> "%LOG%"
  for %%A in ("build\app\outputs\bundle\release\app-release.aab") do echo AAB-SIZE=%%~zA >> "%LOG%"
) else (
  echo ---AAB-MISSING--- >> "%LOG%"
)
echo ---DONE--- >> "%LOG%"
endlocal
