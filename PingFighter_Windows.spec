# -*- mode: python ; coding: utf-8 -*-
# PingFighter Windows 실행 파일 빌드 설정

import glob
import os
import imageio_ffmpeg
import imageio
import moviepy
from PyInstaller.utils.hooks import collect_submodules

bgm_files = []
for _pattern in ("bgm/*.ogg", "bgm/*.mp3", "bgm/*.wav"):
    for _path in glob.glob(_pattern):
        bgm_files.append((_path, 'bgm'))

stage_videos = []
for _pattern in ("stagevideo/*.mov", "stagevideo/*.mp4", "stagevideo/*.avi"):
    for _path in glob.glob(_pattern):
        stage_videos.append((_path, 'stagevideo'))

# package metadata (.dist-info) 포함 - importlib.metadata 사용 에러 방지
dist_info_datas = []
for _mod, _pattern in (
    (imageio, "imageio*.dist-info"),
    (imageio_ffmpeg, "imageio_ffmpeg*.dist-info"),
    (moviepy, "moviepy*.dist-info"),
):
    try:
        _pkg_dir = os.path.dirname(os.path.abspath(_mod.__file__))
        _site_dir = os.path.dirname(_pkg_dir)  # dist-info는 패키지와 같은 상위 경로에 위치
        for _dist in glob.glob(os.path.join(_site_dir, _pattern)):
            dist_info_datas.append((_dist, os.path.basename(_dist)))
    except Exception:
        pass

ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
ffmpeg_binaries = []
if ffmpeg_exe and os.path.isfile(ffmpeg_exe):
    ffmpeg_binaries.append((ffmpeg_exe, 'ffmpeg.exe'))
    # 번들 시 이름을 ffmpeg.exe로 고정해 런타임 경로를 단순화
    ffmpeg_binaries.append((ffmpeg_exe, 'ffmpeg.exe'))

# Stage intro 오디오 추출에 필요한 moviepy 하위 모듈을 통째로 포함
try:
    # collect_submodules가 editor.py를 누락하므로 수동으로 추가한다.
    moviepy_hiddenimports = ["moviepy.editor"] + collect_submodules("moviepy")
except Exception:
    moviepy_hiddenimports = [
        "moviepy",
        "moviepy.editor",
        "moviepy.audio.io.readers",
        "moviepy.audio.io.ffmpeg_audiowriter",
        "moviepy.video.io.ffmpeg_reader",
        "moviepy.video.io.ffmpeg_writer",
    ]

a = Analysis(
    ['pingfighter.py'],
    pathex=[],
    binaries=ffmpeg_binaries,
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
        ('PF\uC2A4\uD0C0\uB354\uC2A4\uD2B8 3.0.ttf', '.'),
        ('Pretendard-Bold.ttf', '.'),
        ('Pretendard-Medium.ttf', '.'),
        ('Pretendard-Regular.ttf', '.'),
        ('NeoDGM.ttf', '.'),
        ('NeoDunggeunmoPro.ttf', '.'),
        ('\uB124\uC624\uB465\uADFC\uBAA8.ttf', '.'),
        # 폰트 서브디렉토리
        ('fonts/pixel/*.ttf', 'fonts/pixel'),
        ('fonts/\uD504\uB9AC\uD150\uB2E4\uB4DC/public/static/alternative/*.ttf', 'fonts/\uD504\uB9AC\uD150\uB2E4\uB4DC/public/static/alternative'),
        ('fonts/\uD504\uB9AC\uD150\uB2E4\uB4DC/public/variable/*.ttf', 'fonts/\uD504\uB9AC\uD150\uB2E4\uB4DC/public/variable'),
        
        # 이미지 파일
        ('*.png', '.'),
        ('\uB2E4\uC6B4\uB85C\uB4DC.jpeg', '.'),
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
    ] + bgm_files + stage_videos + dist_info_datas,
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
        'cv2',
        'moviepy',
        'moviepy.editor',
        'moviepy.audio.io.ffmpeg_audioreader',
        'moviepy.audio.io.ffmpeg_audiowriter',
        'moviepy.video.io.ffmpeg_reader',
        'moviepy.video.io.ffmpeg_writer',
        'imageio_ffmpeg',
    ] + moviepy_hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=['hooks/rth_imageio_nometa.py'],
    excludes=[
        'tensorflow',  # TensorFlow는 옵션이므로 제외
        'tkinter',     # GUI 라이브러리 제외
        'matplotlib',  # 플로팅 라이브러리 제외
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
    console=True,  # 디버그용 콘솔 창 표시
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
