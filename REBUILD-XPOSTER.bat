@echo off
setlocal
cd /d "%~dp0"
set "LOG=D:\poster\_play_build_log2.txt"
echo ==== XPOSTER REBUILD %DATE% %TIME% ==== > "%LOG%"

echo [1/4] Stopping stuck Gradle daemons... >> "%LOG%"
cd android
call gradlew.bat --stop >> "%LOG%" 2>&1
cd ..
echo ---GRADLE-STOP-EXIT=%ERRORLEVEL%--- >> "%LOG%"

echo [2/4] Killing stale java/dart build processes... >> "%LOG%"
taskkill /F /IM java.exe /T >> "%LOG%" 2>&1
taskkill /F /IM dart.exe /T >> "%LOG%" 2>&1
echo ---KILL-DONE--- >> "%LOG%"

echo [3/4] flutter build appbundle --release -v ... >> "%LOG%"
call flutter build appbundle --release -v >> "%LOG%" 2>&1
echo ---BUILD-EXIT=%ERRORLEVEL%--- >> "%LOG%"

echo [4/4] Checking output... >> "%LOG%"
if exist "build\app\outputs\bundle\release\app-release.aab" (
  echo ---AAB-OK--- >> "%LOG%"
  for %%A in ("build\app\outputs\bundle\release\app-release.aab") do echo AAB-SIZE=%%~zA >> "%LOG%"
) else (
  echo ---AAB-MISSING--- >> "%LOG%"
)
echo ---DONE--- >> "%LOG%"
endlocal
