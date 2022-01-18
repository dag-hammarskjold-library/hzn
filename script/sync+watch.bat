@echo off

perl watch_kill.pl %MONGODB_CONNECT% y && perl watch.pl -sM %MONGODB_CONNECT% -i 300

cmd /k
