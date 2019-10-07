@echo off

start cmd /K "perl watch.pl %MONGODB_CONNECT% 300"

echo "updating bibs..."
perl sync.pl -bM %MONGODB_CONNECT%

echo "updating auths..."
perl sync.pl -aM %MONGODB_CONNECT%

cmd /K
