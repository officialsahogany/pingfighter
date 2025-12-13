@echo off
chcp 65001 >nul
cd /d "d:\백업\1129\윈도우용최신\game\bosspong"
echo Building PingFighter...
python -m PyInstaller PingFighter_Windows.spec --noconfirm
echo Build completed!
pause
