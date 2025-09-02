"""
게임 설정 및 변경 가능한 파라미터
런타임에 조정 가능한 설정값들
"""

import pygame
from .constants import *

# ============= 게임 초기 설정 =============
FULLSCREEN_MODE = False
SOUND_ENABLED = True
MUSIC_VOLUME = 0.7
SFX_VOLUME = 0.8

# ============= 게임플레이 설정 =============
# 기본 게임 속도
GAME_SPEED = 1.0
BALL_SPEED_MULTIPLIER = 1.0
PADDLE_SPEED_MULTIPLIER = 1.0

# AI 난이도
AI_DIFFICULTY = "NORMAL"
AI_REACTION_TIME = 5  # 프레임
AI_ERROR_RATE = 0.1  # 10% 실수율

# ============= 보스 설정 =============
# 보스 기본 능력치
BOSS_BASE_SPEED = 5
BOSS_BASE_ACCELERATION = 1.5
BOSS_SKILL_COOLDOWN = 300  # 프레임

# 스테이지별 보스 설정은 stage_configs.py로 이동

# ============= 아이템 시스템 =============
ITEM_SPAWN_CHANCE = 0.02  # 2% 확률
ITEM_DURATION = 300  # 5초
MAX_ITEMS_ON_SCREEN = 3
ITEM_FALL_SPEED = 2

# ============= 스킬 시스템 =============
# 대쉬
DASH_SPEED = 20
DASH_COOLDOWN = 180  # 3초
DASH_DURATION = 10  # 프레임

# 특수 스킬
SPECIAL_GAUGE_MAX = 100
SPECIAL_GAUGE_GAIN = 5
SPECIAL_SKILL_COST = 50

# ============= 이펙트 설정 =============
PARTICLE_ENABLED = True
SCREEN_SHAKE_ENABLED = True
MOTION_BLUR_ENABLED = False
BLOOM_EFFECT_ENABLED = False

# ============= 저장 설정 =============
SAVE_FILE_PATH = "save_data.json"
AUTO_SAVE_ENABLED = True
AUTO_SAVE_INTERVAL = 60000  # 1분

# ============= 디버그 설정 =============
DEBUG_MODE = False
SHOW_FPS = False
SHOW_HITBOXES = False
INVINCIBLE_MODE = False

# ============= 컨트롤 설정 =============
KEYBOARD_CONTROLS = {
    "LEFT": pygame.K_LEFT,
    "RIGHT": pygame.K_RIGHT,
    "DASH": pygame.K_SPACE,
    "SKILL": pygame.K_z,
    "PAUSE": pygame.K_ESCAPE
}

GAMEPAD_CONTROLS = {
    "AXIS_X": 0,
    "BUTTON_DASH": 0,
    "BUTTON_SKILL": 1,
    "BUTTON_PAUSE": 7
}

# ============= 네트워크 설정 (멀티플레이어용) =============
NETWORK_ENABLED = False
SERVER_IP = "localhost"
SERVER_PORT = 5555
PING_THRESHOLD = 100  # ms

# ============= 그래픽 품질 설정 =============
GRAPHICS_QUALITY = "HIGH"  # LOW, MEDIUM, HIGH, ULTRA
RESOLUTION_SCALE = 1.0
ANTI_ALIASING = True
VSYNC_ENABLED = True

# 품질별 설정
QUALITY_PRESETS = {
    "LOW": {
        "PARTICLE_ENABLED": False,
        "SCREEN_SHAKE_ENABLED": False,
        "MOTION_BLUR_ENABLED": False,
        "BLOOM_EFFECT_ENABLED": False,
        "ANTI_ALIASING": False
    },
    "MEDIUM": {
        "PARTICLE_ENABLED": True,
        "SCREEN_SHAKE_ENABLED": True,
        "MOTION_BLUR_ENABLED": False,
        "BLOOM_EFFECT_ENABLED": False,
        "ANTI_ALIASING": False
    },
    "HIGH": {
        "PARTICLE_ENABLED": True,
        "SCREEN_SHAKE_ENABLED": True,
        "MOTION_BLUR_ENABLED": True,
        "BLOOM_EFFECT_ENABLED": False,
        "ANTI_ALIASING": True
    },
    "ULTRA": {
        "PARTICLE_ENABLED": True,
        "SCREEN_SHAKE_ENABLED": True,
        "MOTION_BLUR_ENABLED": True,
        "BLOOM_EFFECT_ENABLED": True,
        "ANTI_ALIASING": True
    }
}

# ============= 언어 설정 =============
LANGUAGE = "ko"  # ko, en, ja, zh
FONT_SIZE_MULTIPLIER = 1.0

# ============= 접근성 설정 =============
COLOR_BLIND_MODE = False
SCREEN_READER_ENABLED = False
SUBTITLE_ENABLED = True
BUTTON_HINTS_ENABLED = True