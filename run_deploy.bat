@echo off
setlocal
set "LOG=D:\poster\_deploy2.txt"
cd /d D:\poster\buxoro_pos

echo ==== TOOL CHECK ==== > "%LOG%"
where node >> "%LOG%" 2>&1
where npm >> "%LOG%" 2>&1
where firebase >> "%LOG%" 2>&1
call firebase --version >> "%LOG%" 2>&1
echo. >> "%LOG%"

echo ==== NPM INSTALL (functions) ==== >> "%LOG%"
cd functions
call npm install >> "%LOG%" 2>&1
echo ---NPMINSTALL-EXIT=%ERRORLEVEL%--- >> "%LOG%"
cd ..
echo. >> "%LOG%"

echo ==== FIREBASE DEPLOY ==== >> "%LOG%"
rem Storage rules allaqachon konsolda faol; storage'ni chiqarib tashladik
rem (cross-service IAM interaktiv promptidan qochish uchun).
call firebase deploy --only functions,firestore:indexes,firestore:rules --project poster-ae945 --non-interactive >> "%LOG%" 2>&1
echo ---DEPLOY-EXIT=%ERRORLEVEL%--- >> "%LOG%"
echo ---DONE--- >> "%LOG%"
endlocal
