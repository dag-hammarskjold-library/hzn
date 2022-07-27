@echo off

perl watch_kill.pl %MONGODB_CONNECT% y
if %errorlevel% neq 0 exit /b %errorlevel%

:start
perl watch.pl -sM %MONGODB_CONNECT% -i 300
timeout /t 300
goto start

cmd /k
