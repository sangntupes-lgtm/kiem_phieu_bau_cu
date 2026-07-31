@echo off
cd /d %~dp0
where node >nul 2>nul || (echo Chua cai Node.js 20 & pause & exit /b 1)
if not exist node_modules call npm install
call npm start
pause
