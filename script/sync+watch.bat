
set connect="mongodb://undlFilesAdmin:password@18.235.152.183:8080/?authSource=undlFiles" 

start cmd /K perl script\watch.pl %connect% 300

perl script\sync.pl -bM %connect%
perl script\sync.pl -aM %connect%
