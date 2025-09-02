"""
게임 상수 정의
색상, 크기, 기본값 등 변경되지 않는 상수들
"""

# ============= 색상 상수 =============
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
YELLOW = (255, 255, 0)
CYAN = (0, 255, 255)
MAGENTA = (255, 0, 255)
GRAY = (128, 128, 128)

# 추가 색상
DARK_GRAY = (64, 64, 64)
LIGHT_GRAY = (192, 192, 192)
ORANGE = (255, 165, 0)
PURPLE = (128, 0, 128)
PINK = (255, 192, 203)

# ============= 화면 설정 =============
SCREEN_WIDTH = 600
SCREEN_HEIGHT = 750
WIDTH = SCREEN_WIDTH  # 호환성 유지
HEIGHT = SCREEN_HEIGHT  # 호환성 유지

GAME_WIDTH = 600
GAME_HEIGHT = 750
GAME_OFFSET_X = 0
GAME_OFFSET_Y = 0

# FPS 설정
TARGET_FPS = 60
MIN_FPS = 30
MAX_FPS = 120

# ============= 게임 객체 크기 =============
# 패들
PADDLE_WIDTH = 100
PADDLE_HEIGHT = 10
PADDLE_SPEED = 8

# 보스 패들
BOSS_PADDLE_WIDTH = 100
BOSS_PADDLE_HEIGHT = 10

# 공
BALL_SIZE = 10
BALL_RADIUS = BALL_SIZE // 2
INITIAL_BALL_SPEED = 6

# 보스 이미지 크기
BOSS_IMG_WIDTH = 80
BOSS_IMG_HEIGHT = 80
BOSS_IMG_STAGE4_WIDTH = 150
BOSS_IMG_STAGE4_HEIGHT = 70
BOSS_IMG_STAGE5_WIDTH = 100
BOSS_IMG_STAGE5_HEIGHT = 100

# ============= 게임 규칙 =============
# 점수 시스템
POINTS_TO_WIN = 3
MAX_ROUNDS = 5
DEUCE_THRESHOLD = 2

# 듀스 시스템
DEUCE_MODE_ENABLED = True
DEUCE_WIN_DIFFERENCE = 2

# ============= 물리 상수 =============
GRAVITY = 0.5
FRICTION = 0.98
BOUNCE_DAMPING = 0.9
MAX_BALL_SPEED = 25
MIN_BALL_SPEED = 3

# ============= 타이밍 상수 =============
SERVE_DELAY = 1000  # 밀리초
ROUND_START_DELAY = 2000
GAME_OVER_DELAY = 3000
EFFECT_DURATION = 60  # 프레임

# ============= 난이도 상수 =============
DIFFICULTY_LEVELS = {
    "EASY": 0.8,
    "NORMAL": 1.0,
    "HARD": 1.3,
    "EXTREME": 1.5
}

# ============= 리그 모드 =============
LEAGUE_MODES = ["junior", "senior", "master", "legend"]
LEAGUE_MULTIPLIERS = {
    "junior": 1.0,
    "senior": 1.5,
    "master": 2.0,
    "legend": 3.0
}