SETLOCAL ENABLEDELAYEDEXPANSION
@echo on
set n=C:\Users\%username%\AppData\LocalLow\Sun\Java\Deployment\security\

if not exist %n% (
	cd C:\Users\%username%\AppData\LocalLow\
	mkdir Sun\Java\Deployment\security\
)

cd %n%
ipconfig | findstr "Default Gateway" | Findstr 192.168 > localips.txt
set /p k=<localips.txt
DEL localips.txt

FOR /F "tokens=*" %%i in ('echo %k%') DO SET r=%%i
SET r=%r:~44,2%

IF EXIST exception.sites (
	set /p f=<exception.sites

) ELSE (
	FOR /L %%G IN (1,1,140) DO echo http://10.%r%.16.%%G/ >> exception.sites
)

IF NOT %f%==http://10.%r%.16.1/ (
	DEL exception.sites
	FOR /L %%G IN (1,1,140) DO echo http://10.%r%.16.%%G/ >> exception.sites
)