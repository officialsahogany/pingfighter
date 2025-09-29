# -*- mode: python ; coding: utf-8 -*-
# PingFighter Windows 실행 파일 빌드 설정

a = Analysis(
    ['pingfighter.py'],
    pathex=[],
    binaries=[],
    datas=[
        # 폰트 파일 - 개별 파일 명시적 포함
        ('NanumSquareEB.ttf', '.'),
        ('NanumSquareB.ttf', '.'),
        ('NanumSquareR.ttf', '.'),
        ('NanumSquareL.ttf', '.'),
        ('NanumSquare_acEB.ttf', '.'),
        ('NanumSquare_acB.ttf', '.'),
        ('NanumSquare_acR.ttf', '.'),
        ('NanumSquare_acL.ttf', '.'),
        ('PFStardust.ttf', '.'),
        ('PFSartdust.ttf', '.'),
        ('PF스타더스트 3.0.ttf', '.'),
        ('Pretendard-Bold.ttf', '.'),
        ('Pretendard-Medium.ttf', '.'),
        ('Pretendard-Regular.ttf', '.'),
        ('NeoDGM.ttf', '.'),
        ('NeoDunggeunmoPro.ttf', '.'),
        ('네오둥근모.ttf', '.'),
        # 폰트 서브디렉토리
        ('fonts/pixel/*.ttf', 'fonts/pixel'),
        ('fonts/프리텐다드/public/static/alternative/*.ttf', 'fonts/프리텐다드/public/static/alternative'),
        ('fonts/프리텐다드/public/variable/*.ttf', 'fonts/프리텐다드/public/variable'),
        
        # 이미지 파일
        ('*.png', '.'),
        ('다운로드.jpeg', '.'),
        ('items/*.png', 'items'),
        ('items/legendary/*.png', 'items/legendary'),
        ('backgrounds/*.png', 'backgrounds'),
        # 스테이지 배경 이미지
        ('stage*.png', '.'),
        ('boss_stage*.png', '.'),
        
        # 사운드 파일
        ('sounds/*.wav', 'sounds'),
        
        # 설정 파일
        ('*.json', '.'),
        ('*.txt', '.'),
        
        # Python 모듈 디렉토리
        ('scenes', 'scenes'),
        ('ui', 'ui'),
        ('backgrounds', 'backgrounds'),
        ('config', 'config'),
        ('localization', 'localization'),
        ('core', 'core'),
        ('events', 'events'),
        ('game_logic', 'game_logic'),
        ('game_mechanics', 'game_mechanics'),
        ('item_effects', 'item_effects'),
        ('managers', 'managers'),
        ('rendering', 'rendering'),
        ('utils', 'utils'),
    ],
    hiddenimports=[
        # 기본 모듈
        'pygame',
        'pygame.font',
        'pygame.mixer',
        'pygame.image',
        'random',
        'math',
        'json',
        'sys',
        'os',
        'copy',
        'time',
        'traceback',
        'datetime',
        'importlib',
        'pathlib',
        # 게임 모듈
        'items',
        'option',
        'gacha',
        'opening',
        'skill',
        'academy',
        'cinematic',
        'ui_manager',
        'effects_manager',
        'physics_manager',
        'dash_manager',
        'trade_point_system',
        'legendary_items',
        'pixel_font_manager',
        # 배경 모듈
        'backgrounds.animated_background',
        'backgrounds.animated_background_stage2',
        'backgrounds.animated_background_stage6',
        # UI 모듈
        'ui.hud_display',
        'ui.menu_system',
        'ui.dialog_system',
        'ui.simple_menu_background',
        'ui.stage3_menhera_world',
        'ui.stage4_shaolin_temple',
        'ui.stage5_chinese_market',
        # 이벤트 모듈
        'events.stage1_event_integration',
        'events.stage5_event_integration',
        # 게임 로직 모듈
        'game_logic.checkmate_system',
        'game_logic.smooth_boss_movement',
        'game_logic.boss_movement_integration',
        'game_logic.advanced_boss_physics',
        # 아이템 효과 모듈
        'item_effects.dowsing_pendulum',
        'item_effects.devil_dice',
        'item_effects.technical_vest',
        'item_effects.fuel_pouch',
        'item_effects.bluetooth_ring',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'tensorflow',  # TensorFlow는 옵션이므로 제외
        'tkinter',     # GUI 라이브러리 제외
        'matplotlib',  # 플로팅 라이브러리 제외
        'numpy',       # 필요없으면 제외
        'pandas',      # 필요없으면 제외
    ],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='PingFighter',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,  # Windows에서 콘솔 창 숨기기
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='ball.ico',  # Windows는 .ico 파일 사용
    version_file=None,
    uac_admin=False,  # 관리자 권한 불필요
    uac_uiaccess=False,
)