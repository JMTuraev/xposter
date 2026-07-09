@echo off
setlocal
cd /d "%~dp0"
set "LOG=D:\poster\_play_build_log4.txt"
echo ==== XPOSTER ARM64 REBUILD %DATE% %TIME% ==== > "%LOG%"

echo [1/3] Stopping stuck Gradle daemons and processes... >> "%LOG%"
cd android
call gradlew.bat --stop >> "%LOG%" 2>&1
cd ..
taskkill /F /IM java.exe /T >> "%LOG%" 2>&1
taskkill /F /IM dart.exe /T >> "%LOG%" 2>&1
taskkill /F /IM gen_snapshot.exe /T >> "%LOG%" 2>&1
taskkill /F /IM gen_snapshot_arm64.exe /T >> "%LOG%" 2>&1
taskkill /F /IM flutter_tester.exe /T >> "%LOG%" 2>&1
echo ---CLEANUP-DONE--- >> "%LOG%"

echo [2/3] Deleting old AAB and building fresh... >> "%LOG%"
del /q "build\app\outputs\bundle\release\app-release.aab" 2>nul
call flutter build appbundle --release --target-platform android-arm64 >> "%LOG%" 2>&1
echo ---BUILD-EXIT=%ERRORLEVEL%--- >> "%LOG%"

echo [3/3] Checking output... >> "%LOG%"
if exist "build\app\outputs\bundle\release\app-release.aab" (
  echo ---AAB-OK--- >> "%LOG%"
  for %%A in ("build\app\outputs\bundle\release\app-release.aab") do echo AAB-SIZE=%%~zA >> "%LOG%"
) else (
  echo ---AAB-MISSING--- >> "%LOG%"
)
echo ---DONE--- >> "%LOG%"
echo.
echo Tayyor. Oynani yopishingiz mumkin.
pause
