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
        ('items/*.png', 'items'),
        ('items/legendary/*.png', 'items/legendary'),
        ('sounds/*.wav', 'sounds'),
        ('fonts/pixel/*.ttf', 'fonts/pixel'),
        ('*.py', '.'),
        ('ui/*.py', 'ui'),
        ('item_effects/*.py', 'item_effects'),
        ('events/*.py', 'events'),
        ('backgrounds/*.py', 'backgrounds'),
        ('game_logic/*.py', 'game_logic'),
        ('managers/*.py', 'managers'),
        ('config/*.py', 'config'),
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
    debug=True,  # 디버그 모드 활성화
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,  # 압축 비활성화
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,  # 콘솔 창 표시
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

app = BUNDLE(
    exe,
    name='PingFighter.app',
    icon=None,
    bundle_identifier='com.pika.pingfighter',
    info_plist={
        'NSHighResolutionCapable': 'True',
        'LSMinimumSystemVersion': '10.13.0',
    },
)