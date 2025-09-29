# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['pingfighter.py'],
    pathex=[],
    binaries=[],
    datas=[('*.png', '.'), ('*.ttf', '.'), ('*.txt', '.'), ('*.json', '.'), ('*.jpeg', '.'), ('items', 'items'), ('sounds', 'sounds'), ('scenes', 'scenes'), ('ui', 'ui'), ('localization', 'localization')],
    hiddenimports=[],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=['tensorflow', 'matplotlib', 'scipy', 'sklearn'],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='PingFighter_Fixed',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='PingFighter_Fixed',
)
app = BUNDLE(
    coll,
    name='PingFighter_Fixed.app',
    icon=None,
    bundle_identifier=None,
)
