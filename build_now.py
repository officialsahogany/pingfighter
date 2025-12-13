import subprocess
import sys
import os

os.chdir(r"d:\백업\1129\윈도우용최신\game\bosspong")

cmd = [
    sys.executable, "-m", "PyInstaller",
    "--noconfirm", "--onefile", "--windowed",
    "--name", "PingFighter",
    "--icon", "ball.ico",
    "--add-data", "items;items",
    "--add-data", "sounds;sounds",
    "--add-data", "backgrounds;backgrounds",
    "--add-data", "fonts;fonts",
    "--add-data", "bgm;bgm",
    "--add-data", "assets;assets",
    "--add-data", "NanumSquareEB.ttf;.",
    "--add-data", "NanumSquareB.ttf;.",
    "--add-data", "NanumSquareR.ttf;.",
    "--add-data", "NanumSquareL.ttf;.",
    "--add-data", "NeoDGM.ttf;.",
    "--add-data", "PFStardust.ttf;.",
    "--add-data", "*.png;.",
    "--add-data", "*.json;.",
    "--add-data", "core;core",
    "--add-data", "events;events",
    "--add-data", "game_logic;game_logic",
    "--add-data", "game_mechanics;game_mechanics",
    "--add-data", "item_effects;item_effects",
    "--add-data", "managers;managers",
    "--add-data", "rendering;rendering",
    "--add-data", "ui;ui",
    "--add-data", "utils;utils",
    "--add-data", "scenes;scenes",
    "--add-data", "config;config",
    "--add-data", "localization;localization",
    "--hidden-import", "pygame",
    "--hidden-import", "pygame.font",
    "--hidden-import", "pygame.mixer",
    "--hidden-import", "items",
    "--hidden-import", "academy",
    "--hidden-import", "gacha",
    "--hidden-import", "opening",
    "--hidden-import", "skill",
    "--hidden-import", "option",
    "--hidden-import", "legendary_items",
    "--hidden-import", "pixel_font_manager",
    "--exclude-module", "tensorflow",
    "--exclude-module", "tkinter",
    "--exclude-module", "matplotlib",
    "pingfighter.py"
]

print("Building PingFighter.exe...")
print("This may take several minutes...")
result = subprocess.run(cmd)
print(f"\nBuild finished with exit code: {result.returncode}")
if result.returncode == 0:
    print("SUCCESS! EXE file: dist\\PingFighter.exe")
