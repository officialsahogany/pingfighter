"""
Core Constants - Phase 101
핵심 게임 상수 통합
"""

import pygame

# ============= 화면 설정 =============
SCREEN_WIDTH = 600
SCREEN_HEIGHT = 750
FPS = 60
MILLISECONDS_PER_SECOND = 1000

# ============= 색상 정의 =============
class Colors:
    # 기본 색상
    WHITE = (255, 255, 255)
    BLACK = (0, 0, 0)
    RED = (255, 0, 0)
    GREEN = (0, 255, 0)
    BLUE = (0, 0, 255)
    YELLOW = (255, 255, 0)
    ORANGE = (255, 165, 0)
    PURPLE = (128, 0, 128)
    CYAN = (0, 255, 255)
    MAGENTA = (255, 0, 255)
    
    # 게임 특화 색상
    PLAYER_BLUE = (100, 150, 255)
    BOSS_RED = (255, 100, 100)
    ITEM_GOLD = (255, 215, 0)
    ENERGY_CYAN = (100, 255, 255)
    DARK_PURPLE = (50, 0, 50)
    GHOST_PURPLE = (150, 100, 200)
    QUANTUM_BLUE = (100, 200, 255)
    
    # UI 색상
    UI_BACKGROUND = (30, 30, 40)
    UI_BORDER = (100, 100, 120)
    UI_TEXT = (200, 200, 220)
    UI_HIGHLIGHT = (255, 215, 0)

# ============= 게임 객체 크기 =============
class Sizes:
    # 공
    BALL_RADIUS = 10
    BALL_DIAMETER = 20
    
    # 패들
    PLAYER_WIDTH = 80
    PLAYER_HEIGHT = 15
    BOSS_WIDTH = 80
    BOSS_HEIGHT = 15

# ============= 속도 설정 =============
class Speeds:
    # 공 속도
    BALL_BASE_SPEED = 10.0
    BALL_MAX_SPEED = 25.0
    BALL_MIN_SPEED = 5.0
    
# ============= 타이밍 설정 =============
class Timings:
    # 프레임
    HALF_SECOND_FRAMES = 30
    ONE_SECOND_FRAMES = 60
    TWO_SECONDS_FRAMES = 120
    
# ============= 게임 밸런스 =============
class Balance:
    # 점수
    SCORE_HIT = 10
    SCORE_COMBO = 50
    
# ============= 물리 설정 =============
class Physics:
    # 중력
    GRAVITY = 0.5
    MOON_GRAVITY = 0.1
