@echo off
chcp 65001 >nul
cd /d "d:\백업\1129\윈도우용최신\game\bosspong"

echo === Installing PyInstaller ===
python -m pip install pyinstaller --quiet

echo === Building EXE ===
python -m PyInstaller --noconfirm --onefile --windowed ^
    --name "PingFighter" ^
    --icon "ball.ico" ^
    --add-data "NanumSquareEB.ttf;." ^
    --add-data "NanumSquareB.ttf;." ^
    --add-data "NanumSquareR.ttf;." ^
    --add-data "NanumSquareL.ttf;." ^
    --add-data "PFStardust.ttf;." ^
    --add-data "NeoDGM.ttf;." ^
    --add-data "items;items" ^
    --add-data "sounds;sounds" ^
    --add-data "backgrounds;backgrounds" ^
    --add-data "fonts;fonts" ^
    --add-data "bgm;bgm" ^
    --add-data "assets;assets" ^
    --add-data "config;config" ^
    --add-data "localization;localization" ^
    --add-data "core;core" ^
    --add-data "events;events" ^
    --add-data "game_logic;game_logic" ^
    --add-data "game_mechanics;game_mechanics" ^
    --add-data "item_effects;item_effects" ^
    --add-data "managers;managers" ^
    --add-data "rendering;rendering" ^
    --add-data "ui;ui" ^
    --add-data "utils;utils" ^
    --add-data "scenes;scenes" ^
    --add-data "*.png;." ^
    --add-data "*.json;." ^
    --hidden-import pygame ^
    --hidden-import pygame.font ^
    --hidden-import pygame.mixer ^
    --hidden-import items ^
    --hidden-import option ^
    --hidden-import gacha ^
    --hidden-import opening ^
    --hidden-import skill ^
    --hidden-import academy ^
    --hidden-import legendary_items ^
    --hidden-import pixel_font_manager ^
    --exclude-module tensorflow ^
    --exclude-module tkinter ^
    --exclude-module matplotlib ^
    pingfighter.py

echo === Build Complete ===
echo EXE file is in: dist\PingFighter.exe
pause
