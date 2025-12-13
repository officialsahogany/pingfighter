@echo off
cd /d "d:\백업\1129\윈도우용최신\game\bosspong"
echo Building PingFighter.exe...
python build_now.py
echo.
echo Done! Check dist folder for PingFighter.exe
explorer dist
pause
