@echo off
setlocal
cd /d "%~dp0"
set "LOG=D:\poster\_play_build_log3.txt"
echo ==== XPOSTER ARM64 BUILD %DATE% %TIME% ==== > "%LOG%"
echo [1/2] flutter build appbundle --release --target-platform android-arm64 ... >> "%LOG%"
call flutter build appbundle --release --target-platform android-arm64 >> "%LOG%" 2>&1
echo ---BUILD-EXIT=%ERRORLEVEL%--- >> "%LOG%"
if exist "build\app\outputs\bundle\release\app-release.aab" (
  echo ---AAB-OK--- >> "%LOG%"
  for %%A in ("build\app\outputs\bundle\release\app-release.aab") do echo AAB-SIZE=%%~zA >> "%LOG%"
) else (
  echo ---AAB-MISSING--- >> "%LOG%"
)
echo ---DONE--- >> "%LOG%"
endlocal
