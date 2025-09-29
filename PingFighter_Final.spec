# -*- mode: python ; coding: utf-8 -*-
import os
import sys
from pathlib import Path

# 프로젝트 경로 설정
BASE_DIR = Path(SPECPATH)

# 분석 설정
a = Analysis(
    ['pingfighter.py'],
    pathex=[str(BASE_DIR)],
    binaries=[],
    datas=[
        # 폰트 파일
        ('*.ttf', '.'),
        ('fonts/pixel/*.ttf', 'fonts/pixel'),
        ('fonts/프리텐다드/public/static/alternative/*.ttf', 'fonts/프리텐다드/public/static/alternative'),
        
        # 이미지 파일
        ('*.png', '.'),
        ('*.ico', '.'),
        ('items/*.png', 'items'),
        ('items/legendary/*.png', 'items/legendary'),
        ('backgrounds/*.png', 'backgrounds'),
        
        # 사운드 파일
        ('sounds/*.wav', 'sounds'),
        
        # 설정 파일
        ('*.json', '.'),
        
        # Python 모듈들
        ('academy.py', '.'),
        ('items.py', '.'),
        ('gacha.py', '.'),
        ('skill.py', '.'),
        ('opening.py', '.'),
        ('effects_manager.py', '.'),
        ('physics_manager.py', '.'),
        ('ui_manager.py', '.'),
        ('sound_manager.py', '.'),
        ('dash_manager.py', '.'),
        ('feedback_system.py', '.'),
        ('trade_point_system.py', '.'),
        ('legendary_items.py', '.'),
        ('pixel_font_manager.py', '.'),
        ('font_config.py', '.'),
        ('cinematic.py', '.'),
        
        # 디렉토리 모듈들
        ('ui/*.py', 'ui'),
        ('item_effects/*.py', 'item_effects'),
        ('events/*.py', 'events'),
        ('backgrounds/*.py', 'backgrounds'),
        ('config/*.py', 'config'),
        ('game_logic/*.py', 'game_logic'),
        ('game_mechanics/*.py', 'game_mechanics'),
        ('managers/*.py', 'managers'),
        ('utils/*.py', 'utils'),
        ('rendering/*.py', 'rendering'),
        ('core/*.py', 'core'),
        ('localization', 'localization'),
    ],
    hiddenimports=[
        'pygame',
        'numpy',
        'random',
        'math',
        'json',
        'os',
        'sys',
        'time',
        'copy',
        'traceback',
        'pathlib',
        'typing',
        'enum',
        'dataclasses',
        'colorsys',
        're',
        # 게임 모듈들
        'academy',
        'items',
        'gacha',
        'skill',
        'opening',
        'effects_manager',
        'physics_manager',
        'ui_manager',
        'sound_manager',
        'dash_manager',
        'feedback_system',
        'trade_point_system',
        'legendary_items',
        'pixel_font_manager',
        'font_config',
        'cinematic',
        # UI 모듈
        'ui.stage3_menhera_world',
        'ui.stage4_shaolin_temple',
        'ui.stage5_chinese_market',
        'ui.hud_display',
        'ui.improved_main_menu',
        'ui.font_manager',
        # 이벤트 모듈
        'events.balloon_machine_event',
        'events.stage1_event_integration',
        'events.stage5_fire_machine_event',
        'events.stage5_event_integration',
        # 아이템 효과 모듈
        'item_effects.devil_dice',
        'item_effects.technical_vest',
        'item_effects.bluetooth_ring',
        'item_effects.fuel_pouch',
        'item_effects.dowsing_pendulum',
        # 배경 모듈
        'backgrounds.animated_background_stage2',
        'backgrounds.animated_background_stage3',
        'backgrounds.animated_background_stage4',
        'backgrounds.animated_background_stage5',
        'backgrounds.animated_background_stage6',
        # 게임 로직 모듈
        'game_logic.boss_movement_integration',
        'game_logic.checkmate_system',
        'game_logic.smooth_boss_movement',
        'game_logic.show_character_selection_module',
        'game_logic.physics_engine',
        # 게임 메카닉스 모듈
        'game_mechanics.half_dash_system',
        'game_mechanics.half_dash_integration',
        # 설정 모듈
        'config.constants',
        'config.game_settings',
        'config.stage_configs',
        # 코어 모듈
        'core.game_state',
        'core.game_variables',
        # 렌더링 모듈
        'rendering.unified_renderer',
        # 유틸 모듈
        'utils.safe_loader',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        # 테스트 파일들 제외
        'test_*',
        'fix_*',
        'create_*',
        'add_*',
        'remove_*',
        'apply_*',
        'download_*',
        'generate_*',
        'analyze_*',
        'optimize_*',
        'integrate_*',
        'verify_*',
        # 백업 파일들 제외
        '*_backup*',
        'bosspong_*',
        # 불필요한 모듈들
        'matplotlib',
        'PIL',
        'tkinter',
        'tensorflow',
        'torch',
        'sklearn',
        'pandas',
        'scipy',
        'notebook',
        'jupyter',
        'IPython',
    ],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=None,
    noarchive=False,
)

# 바이너리 생성
pyz = PYZ(a.pure, a.zipped_data, cipher=None)

# 실행 파일 생성
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
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,  # 콘솔 창 숨기기
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='ball.ico',  # 아이콘 파일
    version_file=None,
    uac_admin=False,
    uac_uiaccess=False,
)