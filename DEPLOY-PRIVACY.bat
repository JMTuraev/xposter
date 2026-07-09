@echo off
setlocal
cd /d "%~dp0"
set "LOG=D:\poster\_privacy_deploy_log.txt"
echo ==== XPOSTER PRIVACY HOSTING DEPLOY %DATE% %TIME% ==== > "%LOG%"
call firebase deploy --only hosting --project poster-ae945 --non-interactive >> "%LOG%" 2>&1
echo ---DEPLOY-EXIT=%ERRORLEVEL%--- >> "%LOG%"
echo ---DONE--- >> "%LOG%"
endlocal
