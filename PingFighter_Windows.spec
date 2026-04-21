# -*- mode: python ; coding: utf-8 -*-
# PingFighter Windows 실행 파일 빌드 설정 (2026-02-17 업데이트)
# console=False → 로그 창 없이 실행

import glob
import os

try:
    import imageio_ffmpeg
    ffmpeg_exe = imageio_ffmpeg.get_ffmpeg_exe()
except ImportError:
    imageio_ffmpeg = None
    ffmpeg_exe = None

try:
    import imageio
except ImportError:
    imageio = None

try:
    import moviepy
except ImportError:
    moviepy = None

try:
    from PyInstaller.utils.hooks import collect_submodules, copy_metadata
except ImportError:
    collect_submodules = lambda x: []
    copy_metadata = lambda x: []

# --- BGM 파일 수집 ---
bgm_files = []
for _pattern in ("bgm/*.ogg", "bgm/*.mp3", "bgm/*.wav"):
    for _path in glob.glob(_pattern):
        bgm_files.append((_path, 'bgm'))
# bgm/intro/ 서브디렉토리 (인트로 컷씬 BGM)
for _pattern in ("bgm/intro/*.ogg", "bgm/intro/*.mp3", "bgm/intro/*.wav"):
    for _path in glob.glob(_pattern):
        bgm_files.append((_path, 'bgm/intro'))

# --- 스테이지 비디오 수집 ---
stage_videos = []
for _pattern in ("stagevideo/*.mov", "stagevideo/*.mp4", "stagevideo/*.avi"):
    for _path in glob.glob(_pattern):
        stage_videos.append((_path, 'stagevideo'))

# --- 패키지 메타데이터 (.dist-info) 수집 ---
dist_info_datas = []
for _pkg_name in ['imageio', 'imageio-ffmpeg', 'moviepy', 'tqdm', 'proglog']:
    try:
        dist_info_datas += copy_metadata(_pkg_name)
    except Exception:
        pass

# --- ffmpeg 바이너리 ---
ffmpeg_binaries = []
if ffmpeg_exe and os.path.isfile(ffmpeg_exe):
    ffmpeg_binaries.append((ffmpeg_exe, 'ffmpeg.exe'))

# --- moviepy 하위 모듈 ---
moviepy_hiddenimports = []
try:
    moviepy_hiddenimports = ["moviepy.editor"] + collect_submodules("moviepy")
except Exception:
    moviepy_hiddenimports = [
        "moviepy",
        "moviepy.editor",
        "moviepy.audio.io.readers",
        "moviepy.audio.io.ffmpeg_audiowriter",
        "moviepy.video.io.ffmpeg_reader",
        "moviepy.video.io.ffmpeg_writer",
        "moviepy.video.io.VideoFileClip",
        "moviepy.audio.io.AudioFileClip",
    ]

# --- managers/sounds 수집 ---
manager_sounds = []
for _pattern in ("managers/sounds/*.wav", "managers/sounds/*.mp3"):
    for _path in glob.glob(_pattern):
        manager_sounds.append((_path, 'managers/sounds'))

a = Analysis(
    ['pingfighter.py'],
    pathex=[],
    binaries=ffmpeg_binaries,
    datas=[
        # ===== 폰트 파일 =====
        # 루트 TTF
        ('*.ttf', '.'),
        # font/ 디렉토리 (HCRBatang 등 인트로용 폰트)
        ('font/*.ttf', 'font'),
        # fonts/ 서브디렉토리
        ('fonts/pixel/*.ttf', 'fonts/pixel'),
        ('fonts/\ud504\ub9ac\ud150\ub2e4\ub4dc/public/static/alternative/*.ttf',
         'fonts/\ud504\ub9ac\ud150\ub2e4\ub4dc/public/static/alternative'),
        ('fonts/\ud504\ub9ac\ud150\ub2e4\ub4dc/public/variable/*.ttf',
         'fonts/\ud504\ub9ac\ud150\ub2e4\ub4dc/public/variable'),

        # ===== 이미지 파일 =====
        ('*.png', '.'),
        ('*.jpg', '.'),
        ('*.jpeg', '.'),
        ('intro/*.png', 'intro'),
        ('intro/*.jpg', 'intro'),
        ('items/*.png', 'items'),
        ('items/legendary/*.png', 'items/legendary'),
        ('backgrounds/*.png', 'backgrounds'),
        ('chat/*.png', 'chat'),
        ('introstory/*.png', 'introstory'),
        ('facecard/*.png', 'facecard'),
        ('assets/*.png', 'assets'),
        ('stage*.png', '.'),
        ('boss_stage*.png', '.'),
        # UI 이미지
        ('ui/*.jpg', 'ui'),
        ('ui/*.png', 'ui'),
        ('ui/*.PNG', 'ui'),

        # ===== 사운드 파일 =====
        ('sounds/*.wav', 'sounds'),
        ('sounds/poker/*.wav', 'sounds/poker'),
        ('sounds/poker/*.mp3', 'sounds/poker'),

        # ===== 설정 파일 =====
        ('*.json', '.'),
        ('*.txt', '.'),

        # ===== 로컬라이제이션 =====
        ('localization/*.json', 'localization'),

        # ===== Python 모듈 디렉토리 (데이터로도 포함) =====
        ('ui', 'ui'),
        ('backgrounds', 'backgrounds'),
        ('config', 'config'),
        ('localization', 'localization'),
        ('core', 'core'),
        ('events', 'events'),
        ('game_logic', 'game_logic'),
        ('game_mechanics', 'game_mechanics'),
        ('game_state', 'game_state'),
        ('item_effects', 'item_effects'),
        ('managers', 'managers'),
        ('rendering', 'rendering'),
        ('utils', 'utils'),
        ('downtown', 'downtown'),
        ('tutorial', 'tutorial'),
        ('soldier', 'soldier'),
        ('stages', 'stages'),
        ('new_features', 'new_features'),
    ] + bgm_files + stage_videos + dist_info_datas + manager_sounds,
    hiddenimports=[
        # --- 표준 라이브러리 ---
        'pygame', 'pygame.font', 'pygame.mixer', 'pygame.image', 'pygame.freetype',
        'random', 'math', 'json', 'sys', 'os', 'copy', 'time',
        'traceback', 'datetime', 'importlib', 'pathlib',
        'numpy', 'numpy.core', 'numpy.core._multiarray_umath',

        # --- 루트 게임 모듈 ---
        'splash_screen', 'logo_intro', 'items', 'option', 'gacha', 'opening', 'skill',
        'academy', 'cinematic', 'ui_manager', 'effects_manager',
        'physics_manager', 'dash_manager', 'trade_point_system',
        'legendary_items', 'pixel_font_manager', 'start_menu',
        'font_config', 'resource_path', 'sound_manager', 'bgm_manager',
        'background_manager', 'display_manager', 'item_state_manager',
        'sound_effects', 'supply_drop', 'tutorial_integration',
        'multiplayer_mode', 'game', 'main',

        # --- 필러 모듈 ---
        'pillar_background', 'pillar_stadium', 'pillar_jungle',
        'pillar_menhera', 'pillar_temple', 'pillar_nemesis_ocean',
        'pillar_hongryeon', 'pillar_ninja', 'pillar_colosseum',
        'pillar_blazing_sun', 'pillar_baroque', 'pillar_tetriser',

        # --- 배경 모듈 ---
        'backgrounds.animated_background',
        'backgrounds.animated_background_stage2',
        'backgrounds.animated_background_stage3',
        'backgrounds.animated_background_stage4',
        'backgrounds.animated_background_stage5',
        'backgrounds.animated_background_stage6',
        'backgrounds.animated_background_stage7',
        'backgrounds.animated_background_stage8',
        'backgrounds.animated_background_stage30',

        # --- UI 모듈 ---
        'ui.hud_display', 'ui.hud_display_wrapper', 'ui.menu_system',
        'ui.dialog_system', 'ui.simple_menu_background',
        'ui.stage3_menhera_world', 'ui.stage4_shaolin_temple',
        'ui.stage5_chinese_market', 'ui.pause_menu',
        'ui.retro_game_over', 'ui.settings_ui', 'ui.settings_system',
        'ui.theme_manager', 'ui.font_manager', 'ui.ui_manager',
        'ui.ui_system', 'ui.opening_system', 'ui.menus',
        'ui.components', 'ui.dialogs', 'ui.animation_manager',
        'ui.animation_system', 'ui.network_ui',
        'ui.ice_crystal_scoreboard', 'ui.inferno_scoreboard',
        'ui.throw_angle_display', 'ui.fixed_radar_chart',
        'ui.character_silhouette', 'ui.academy_ui', 'ui.achievement_ui',
        'ui.cyberpunk_menu_background', 'ui.cyberpunk_theme_background',
        'ui.enhanced_menu_background', 'ui.menu_background',
        'ui.improved_main_menu',

        # --- 이벤트 모듈 ---
        'events.stage1_event_integration',
        'events.stage5_event_integration',
        'events.stage5_fire_machine_event',
        'events.balloon_machine_event',
        'events.weather_event',

        # --- 게임 로직 모듈 ---
        'game_logic.checkmate_system', 'game_logic.smooth_boss_movement',
        'game_logic.boss_movement_integration', 'game_logic.advanced_boss_physics',
        'game_logic.boss_ai', 'game_logic.collision', 'game_logic.collision_manager',
        'game_logic.collision_system', 'game_logic.physics', 'game_logic.physics_engine',
        'game_logic.physics_manager', 'game_logic.scoring', 'game_logic.score_manager',
        'game_logic.round_manager', 'game_logic.skill_manager', 'game_logic.skill_system',
        'game_logic.item_manager', 'game_logic.item_system', 'game_logic.special_items',
        'game_logic.special_abilities', 'game_logic.stage_features',
        'game_logic.stage2_effects', 'game_logic.stage7_tetriser',
        'game_logic.perfect_timing', 'game_logic.power_smashing',
        'game_logic.balance_manager', 'game_logic.game_config',
        'game_logic.game_events', 'game_logic.game_loop',
        'game_logic.legacy_state_bridge', 'game_logic.main_loop_module',
        'game_logic.draw_objects_module', 'game_logic.draw_player_gauge_module',
        'game_logic.draw_aircraft_carrier_boss_module',
        'game_logic.get_final_boss_config_module',
        'game_logic.handle_ball_module', 'game_logic.handle_player_module',
        'game_logic.show_character_selection_module',
        'game_logic.show_difficulty_selection_module',
        'game_logic.show_start_screen_module',

        # --- 게임 메카닉 모듈 ---
        'game_mechanics.half_dash_system', 'game_mechanics.half_dash_integration',
        'game_mechanics.ingame_bodyguard', 'game_mechanics.item_system',
        'game_mechanics.skill_system',

        # --- 아이템 효과 모듈 ---
        'item_effects.dowsing_pendulum', 'item_effects.devil_dice',
        'item_effects.technical_vest', 'item_effects.fuel_pouch',
        'item_effects.bluetooth_ring', 'item_effects.ak47',
        'item_effects.ammo_box', 'item_effects.banana',
        'item_effects.bazooka', 'item_effects.bowling_trap',
        'item_effects.cleanse_skill', 'item_effects.dash_boost',
        'item_effects.dynamite', 'item_effects.fire_support',
        'item_effects.foul_whistle', 'item_effects.gold_bar',
        'item_effects.gold_digger', 'item_effects.holy_barrier',
        'item_effects.knee_pads', 'item_effects.laser_scope',
        'item_effects.net_gun', 'item_effects.smartphone',
        'item_effects.star_detector', 'item_effects.weather_capsule',

        # --- config 모듈 ---
        'config.constants', 'config.balance_config', 'config.game_settings',
        'config.language_options', 'config.settings_system', 'config.stage_configs',

        # --- core 모듈 ---
        'core.bridge', 'core.config', 'core.constants',
        'core.dependency_injection', 'core.error_boundary', 'core.error_handler',
        'core.event_bus', 'core.event_handlers', 'core.events',
        'core.game_constants', 'core.game_core', 'core.game_engine',
        'core.game_state', 'core.game_variables', 'core.global_manager',
        'core.imports', 'core.input_keys', 'core.legacy_bridge',
        'core.legacy_state_accessor', 'core.performance_optimizer',
        'core.player_state', 'core.plugin_system', 'core.profiler',

        # --- downtown 모듈 ---
        'downtown', 'downtown.manager', 'downtown.renderer',
        'downtown.player', 'downtown.buildings', 'downtown.building_interior',
        'downtown.building_designs', 'downtown.character_sprites',
        'downtown.constants', 'downtown.map_generator', 'downtown.npc',
        'downtown.shop', 'downtown.action_points',
        'downtown.academy_designs', 'downtown.bank_designs',
        'downtown.gacha_designs', 'downtown.mystery_designs',
        'downtown.poker_game', 'downtown.pachinko_game',
        'downtown.performance_stage', 'downtown.boss_dialogues',
        'downtown.hero_dialogues', 'downtown.hero_paddles',
        'downtown.hero_portraits', 'downtown.hero_skill_icons',
        'downtown.hero_skills', 'downtown.colosseum_arena',
        'downtown.colosseum_dojo', 'downtown.apply_new_designs',

        # --- rendering 모듈 ---
        'rendering.ball_renderer', 'rendering.draw_helper',
        'rendering.effect_renderer', 'rendering.game_renderer',
        'rendering.objects_module', 'rendering.paddle_renderer',
        'rendering.render_manager', 'rendering.render_system',
        'rendering.renderer', 'rendering.stage_renderer',
        'rendering.ui_renderer', 'rendering.unified_renderer',

        # --- managers 모듈 ---
        'managers.dash_manager', 'managers.effects_manager',
        'managers.resource_manager', 'managers.sound_manager',
        'managers.unified_effects', 'managers.unified_sound',

        # --- utils 모듈 ---
        'utils.color_utils', 'utils.draw_utils', 'utils.effect_renderer',
        'utils.game_constants', 'utils.game_helpers', 'utils.game_utils',
        'utils.math_utils', 'utils.particle_utils', 'utils.render_utils',
        'utils.safe_loader',

        # --- tutorial 모듈 ---
        'tutorial', 'tutorial.dialogue', 'tutorial.game_interface',
        'tutorial.manager', 'tutorial.state', 'tutorial.ui',

        # --- soldier 모듈 ---
        'soldier', 'soldier.controller',

        # --- stages 모듈 ---
        'stages', 'stages.stage_loader', 'stages.stage7_boss',

        # --- game_state 모듈 ---
        'game_state', 'game_state.audio', 'game_state.items',

        # --- 외부 라이브러리 ---
        'cv2',
        'moviepy', 'moviepy.editor',
        'moviepy.audio.io.ffmpeg_audioreader',
        'moviepy.audio.io.ffmpeg_audiowriter',
        'moviepy.video.io.ffmpeg_reader',
        'moviepy.video.io.ffmpeg_writer',
        'imageio', 'imageio_ffmpeg',
    ] + moviepy_hiddenimports,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=['hooks/rth_imageio_nometa.py'],
    excludes=[
        'tensorflow',
        'tkinter',
        'matplotlib',
        'pandas',
        'scipy',
        'IPython',
        'jupyter',
        'notebook',
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
    console=False,  # 콘솔 창 비활성화 (로그 없음)
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='ball.ico',
    version_file=None,
    uac_admin=False,
    uac_uiaccess=False,
)
