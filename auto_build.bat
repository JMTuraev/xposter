@echo off
setlocal
cd /d "%~dp0"
del build_status.txt 2>nul
del build_log.txt 2>nul
echo BUILDING> build_status.txt
call flutter pub get > build_log.txt 2>&1
call flutter build apk --debug >> build_log.txt 2>&1
if errorlevel 1 (
  echo FAILED>> build_status.txt
  exit
)
set "ADB=C:\Users\user\AppData\Local\Android\sdk\platform-tools\adb.exe"
if not exist "%ADB%" set "ADB=adb"
"%ADB%" install -r "build\app\outputs\flutter-apk\app-debug.apk" >> build_log.txt 2>&1
"%ADB%" shell am start -n com.buxoropos.buxoro_pos/com.buxoropos.buxoro_pos.MainActivity >> build_log.txt 2>&1
"%ADB%" shell wm size >> build_log.txt 2>&1
echo DONE>> build_status.txt
exit
