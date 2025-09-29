# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

a = Analysis(
    ['pingfighter.py'],
    pathex=['/Users/pika/Desktop/game/bosspong'],
    binaries=[],
    datas=[
        ('*.png', '.'),
        ('*.ttf', '.'),
        ('*.txt', '.'),
        ('*.json', '.'),
        ('*.jpeg', '.'),
        ('items', 'items'),
        ('sounds', 'sounds'),
        ('fonts/pixel', 'fonts/pixel'),
        ('localization', 'localization'),
    ],
    hiddenimports=[
        'pygame',
        'items',
        'gacha',
        'academy',
        'opening',
        'skill',
        'trade_point_system',
        'pixel_font_manager',
        'effects_manager',
        'legendary_items',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tkinter', 'matplotlib', 'numpy', 'pandas', 'scipy', 'tensorflow'],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='PingFighter',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    onefile=True,  # 단일 파일로 생성
    icon=None,
)