@echo off
setlocal
set "PATH=C:\flutter\bin;%PATH%"
set "LOG=D:\poster\_log.txt"
cd /d D:\poster\buxoro_pos

echo ==== ENV CHECK ==== > "%LOG%"
where flutter >> "%LOG%" 2>&1
echo. >> "%LOG%"
echo ==== FLUTTER PUB GET ==== >> "%LOG%"
call flutter pub get >> "%LOG%" 2>&1
echo ---PUBGET-EXIT=%ERRORLEVEL%--- >> "%LOG%"
echo. >> "%LOG%"
echo ==== FLUTTER ANALYZE ==== >> "%LOG%"
call flutter analyze >> "%LOG%" 2>&1
echo ---ANALYZE-EXIT=%ERRORLEVEL%--- >> "%LOG%"
echo ---DONE--- >> "%LOG%"
endlocal
