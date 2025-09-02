import pygame
import random
import sys
import math 
import importlib
import items
import option as option_module
import gacha
import opening
import skill
import academy
import cinematic
import ui_manager
import effects_manager
import physics_manager
import dash_manager
from ui.hud_display import show_score, draw_dash_spirit_lasers
from ui.menu_system import MenuSystem
from ui.dialog_system import DialogSystem
from core.profiler import init_profiler
# 🏗️ 새로운 아키텍처 시스템
from core.game_state import GameState
from core.events import EventManager, EventType, emit_event
from core.bridge import get_bridge, handle_item_collection
from backgrounds.animated_background import AnimatedBackground
from backgrounds.animated_background_stage2 import AnimatedBackgroundStage2
from backgrounds.animated_background_stage3 import AnimatedBackgroundStage3
from backgrounds.animated_background_stage4 import AnimatedBackgroundStage4
from backgrounds.animated_background_stage5 import AnimatedBackgroundStage5
importlib.reload(items)
# 설정 파일 임포트
from config.constants import *
from config.game_settings import *
from config.stage_configs import *
from utils import safe_loader
from utils.effect_renderer import EffectRenderer

effect_renderer = EffectRenderer()
# 🧠 딥러닝 AI 모듈 임포트 (선택적)
try:
    from boss_ai_integration import EnhancedBossAI
    AI_AVAILABLE = True
    print("🧠 딥러닝 AI 모듈이 로드되었습니다!")
except ImportError as e:
    AI_AVAILABLE = False
    print(f"⚠️ 딥러닝 AI 모듈을 사용할 수 없습니다: {e}")
    print("   기본 AI로 실행됩니다. TensorFlow 설치: pip install tensorflow")
# 🏆 플레이어 실력 분석 시스템 임포트
try:
    from player_skill_analyzer import get_player_analyzer
    SKILL_ANALYZER_AVAILABLE = True
    print("🏆 플레이어 실력 분석 시스템이 로드되었습니다!")
except ImportError as e:
    SKILL_ANALYZER_AVAILABLE = False
    print(f"⚠️ 플레이어 분석 시스템 로드 실패: {e}")

# pygame 초기화 (항상 실행)
pygame.init()
# 🏗️ 새 아키텍처 시스템 초기화
game_state = GameState.get_instance()
# 📦 점진적 리팩토링: 게임 변수 관리
from core.game_variables import get_game_vars
game_vars = get_game_vars()
# 📦 점진적 리팩토링: 유틸리티 함수
from utils.game_utils import clamp, lerp, distance, normalize_vector
from utils.render_utils import (create_cyberpunk_background, create_fire_background,
                                create_ice_background, create_electric_background,
                                create_shadow_background, draw_glow_effect)
# 화면 생성 (통합)
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("PINGFIGHTER")

# DrawHelper 인스턴스는 클래스 정의 후 초기화됨
# draw = DrawHelper(SCREEN)  # 나중에 초기화

# 🎮 UI 시스템 초기화
dialog_system = DialogSystem(SCREEN, WIDTH, HEIGHT)
menu_system = MenuSystem(SCREEN, WIDTH, HEIGHT)
# 🎯 이벤트 핸들러 초기화
from core.event_handlers import init_event_handlers
event_handlers = init_event_handlers()
# 📊 프로파일러 초기화
profiler = init_profiler(SCREEN, enabled=True)
profiler.visible = False  # 7번키로 토글
# 입력 관련 변수들은 input_manager에서 관리
# 입력 관련 함수들은 input_manager로 이동됨
STAGE1_BG = safe_loader.safe_load_image("stage1_field.png", (WIDTH, HEIGHT))
STAGE1_BG = safe_loader.safe_scale_image(STAGE1_BG, (WIDTH, HEIGHT))
animated_bg = AnimatedBackground("stage1_field.png") if STAGE1_BG else None
STAGE2_BG = safe_loader.safe_load_image("stage2_field.png", (WIDTH, HEIGHT))
STAGE2_BG = safe_loader.safe_scale_image(STAGE2_BG, (WIDTH, HEIGHT))
animated_bg_stage2 = AnimatedBackgroundStage2("stage2_field.png") if STAGE2_BG else None
STAGE3_BG = safe_loader.safe_load_image("stage3_field.png", (WIDTH, HEIGHT))
STAGE3_BG = safe_loader.safe_scale_image(STAGE3_BG, (WIDTH, HEIGHT))
animated_bg_stage3 = AnimatedBackgroundStage3("stage3_field.png") if STAGE3_BG else None
STAGE4_BG = safe_loader.safe_load_image("stage4_field.png", (WIDTH, HEIGHT))
STAGE4_BG = safe_loader.safe_scale_image(STAGE4_BG, (WIDTH, HEIGHT))
animated_bg_stage4 = AnimatedBackgroundStage4("stage4_field.png") if STAGE4_BG else None
STAGE5_BG = safe_loader.safe_load_image("stage5_field.png", (WIDTH, HEIGHT))
STAGE5_BG = safe_loader.safe_scale_image(STAGE5_BG, (WIDTH, HEIGHT))
animated_bg_stage5 = AnimatedBackgroundStage5("stage5_field.png") if STAGE5_BG else None
# Stage 6 배경 로드 (항공모함 스테이지)
STAGE6_BG = safe_loader.safe_load_image("stage6_field.png", (WIDTH, HEIGHT))
STAGE6_BG = safe_loader.safe_scale_image(STAGE6_BG, (WIDTH, HEIGHT))
# 빠칭코 기계 이미지 로드
pachinko_machine_img = safe_loader.safe_load_image("itemmachine.png", (400, 500))
pachinko_machine_img = safe_loader.safe_scale_image(pachinko_machine_img, (400, 500))
slot_add_icon = safe_loader.safe_load_image("items/slot_add_icon.png", (20, 20))
slot_add_icon = safe_loader.safe_scale_image(slot_add_icon, (20, 20))
for item in items.ITEM_TYPES:
    if item["name"] == "slot_add":
        item["icon"] = slot_add_icon
long_boost_icon = safe_loader.safe_load_image("items/long_boost_icon.png", (28, 28))
long_boost_icon = safe_loader.safe_scale_image(long_boost_icon, (28, 28))
for item in items.ITEM_TYPES:
    if item["name"] == "long_boost":
        item["icon"] = long_boost_icon
battery_icon = safe_loader.safe_load_image("items/battery.png", (28, 28))
battery_icon = safe_loader.safe_scale_image(battery_icon, (28, 28))
for item in items.ITEM_TYPES:
    if item["name"] == "battery":
        item["icon"] = battery_icon
wall_icon = safe_loader.safe_load_image("items/wall.png", (28, 28))
wall_icon = safe_loader.safe_scale_image(wall_icon, (28, 28))
for item in items.ITEM_TYPES:
    if item["name"] == "wall":
        item["icon"] = wall_icon
FIREBALL_IMG = safe_loader.safe_load_image("items/fireball.png", (48, 48))
FIREBALL_IMG = safe_loader.safe_scale_image(FIREBALL_IMG, (48, 48))
# ===============================
# 게이지 시스템 (GameState와 동기화)
# === DrawHelper 클래스 ===
class DrawHelper:
    """pygame.draw 호출을 간소화하는 헬퍼 클래스"""
    def __init__(self, surface):
        self.surface = surface
    
    def circle(self, color, pos, radius, width=0):
        """원 그리기 간소화"""
        pygame.draw.circle(self.surface, color, pos, radius, width)
    
    def rect(self, color, rect, width=0, border_radius=0):
        """사각형 그리기 간소화"""
        if border_radius > 0:
            pygame.draw.rect(self.surface, color, rect, width, border_radius=border_radius)
        else:
            pygame.draw.rect(self.surface, color, rect, width)
    
    def line(self, color, start, end, width=1):
        """선 그리기 간소화"""
        pygame.draw.line(self.surface, color, start, end, width)
    
    def polygon(self, color, points, width=0):
        """다각형 그리기 간소화"""
        pygame.draw.polygon(self.surface, color, points, width)
    
    def lines(self, color, closed, points, width=1):
        """여러 선 그리기 간소화"""
        pygame.draw.lines(self.surface, color, closed, points, width)

# DrawHelper 인스턴스 생성
draw = DrawHelper(SCREEN)

# ===============================
# 🔧 동적 최대 게이지 계산 함수
def get_max_gauge():
    base_max = 500
    try:
        import academy
        paddle_max_bonus = academy.get_skill_bonus("paddle_max_gauge")
        return base_max + paddle_max_bonus
    except:
        return base_max
# GameState와 동기화되는 변수들 (점진적 마이그레이션)
special_gauge = game_state.special_gauge
special_ready = game_state.special_ready
special_gauge_max = get_max_gauge()
displayed_gauge = game_state.displayed_gauge
gauge_animation_speed = game_state.gauge_animation_speed
displayed_boss_gauge = game_state.displayed_boss_gauge
boss_gauge_animation_speed = game_state.boss_gauge_animation_speed
# 홍련폭염 시스템
hongryun_hit_count = game_state.hongryun_hit_count
hongryun_ready = game_state.hongryun_ready
HONGRYUN_MAX_HITS = game_state.HONGRYUN_MAX_HITS
# 🎮 게임 기본 설정
CURRENT_BG = STAGE1_BG  # 현재 배경 기본값은 Stage 1
boss_names = {
    1: "풍악보이",
    2: "악어장군", 
    3: "멘헤라걸",
    4: "퐁크",
    5: "홍련",
}
# 색상 정의
# 게임 기본 설정
FONT = pygame.font.Font("NanumSquareR.ttf", 40)
FPS = TARGET_FPS  # from constants.py
# UI 매니저 초기화
ui_manager.init_ui_manager(SCREEN, FONT, WIDTH, HEIGHT)
# 이펙트 매니저 초기화
effects_manager.init_effects_manager(SCREEN, WIDTH, HEIGHT)
# 입력 매니저 초기화 (비활성화됨)
# input_manager.init_input_manager(SCREEN, WIDTH, HEIGHT)
# 물리 매니저 초기화 (BALL, PLAYER, BOSS 객체 생성 후에 호출해야 함)
# 패들 설정
PADDLE_WIDTH, PADDLE_HEIGHT = 155, 50
# 📦 점진적 리팩토링: 전역 변수를 game_vars로 대체
# 기존 코드와의 호환성을 위해 참조만 유지
PLAYER = game_vars.player.rect
BOSS_Y = game_vars.boss.y_position
BOSS = game_vars.boss.rect
# 공 설정 - game_vars로 관리하되 호환성 유지
BALL_RADIUS = game_vars.ball.radius
BALL = game_vars.ball.rect
BALL_SPEED_Y = game_vars.ball.speed_y
BALL_SPEED_X = game_vars.ball.speed_x
BALL_BASE_SPEED = game_vars.ball.base_speed
ball_vel = game_vars.ball.vel
last_hit_by = game_vars.ball.last_hit_by
# 물리 매니저 초기화 (BALL, PLAYER, BOSS 객체 생성 후)
physics_manager.init_physics_manager(SCREEN, BALL, PLAYER, BOSS, WIDTH, HEIGHT)
# 대쉬 매니저 초기화
# get_special_gauge와 consume_special_gauge는 인라인화됨
# 직접 special_gauge 변수 사용
def play_dash_sound():
    SOUND_DASH.play()
# dash_manager를 위한 헬퍼 함수
def get_gauge():
    return special_gauge
def use_gauge(amount):
    global special_gauge
    special_gauge = max(0, special_gauge - amount)

dash = dash_manager.init_dash_manager(
    academy.get_skill_bonus,
    get_gauge,
    use_gauge,
    play_dash_sound
)
# 🏓 공 물리 시스템
ball_impact_boost = 1.0        # 충돌 시 순간 부스트 (배율)
# 🏓 동적 감속 시스템 (속도에 따라 변화)
ball_boost_decay_rate = 0.975  # 기본 부스트 감소율 (동적으로 조정됨)
ball_min_boost = 0.7          # 기본 최소 부스트 (동적으로 조정됨)
ball_angle = 0                # 공이 굴러가는 느낌
slow_ball_timer = 0           # 느린 상태 유지 시간 (프레임 단위)
vertical_bounce_count = 0     # 수직 바운스 카운트
# 🎯 퍼펙트 타이밍 & 드라이브 시스템
# 퍼펙트 타이밍 감지 (GameState와 동기화)
perfect_timing_window = game_state.perfect_timing_window
perfect_timing_active = game_state.perfect_timing_active
perfect_timing_frame_count = game_state.perfect_timing_frame_count
perfect_direction = game_state.perfect_direction
# 키 입력 감지 (GameState와 동기화)
space_just_pressed = game_state.space_just_pressed
last_space_state = game_state.last_space_state
left_just_pressed = game_state.left_just_pressed
last_left_state = game_state.last_left_state
right_just_pressed = game_state.right_just_pressed
last_right_state = game_state.last_right_state
# 동시 입력 감지 (프레임 기반)
left_press_frame = -1                # 왼쪽 방향키 눌린 프레임
right_press_frame = -1               # 오른쪽 방향키 눌린 프레임
space_press_frame = -1               # 스페이스키 눌린 프레임
frame_counter = 0                    # 프레임 카운터
# 쿨다운 시스템
perfect_timing_cooldown = 0          # 퍼펙트 타이밍 쿨다운 (연타 방지용)
perfect_timing_cooldown_frames = 30  # 쿨다운 시간 (0.5초)
perfect_timing_input_used = False    # 현재 윈도우에서 이미 입력 사용됨 플래그
drive_global_cooldown = 0            # 드라이브 전역 쿨다운 (더 강력한 연타 방지)
drive_global_cooldown_frames = 120   # 드라이브 전역 쿨다운 시간 (2초) - 선입력 방지 강화 (90 → 120)
last_space_press_time = 0            # 마지막 스페이스바 입력 시간 (연타 감지용)
# 🏆 플레이어 분석 관련
recent_dash_time = 0             # 최근 대쉬 시간 (성공 판정용)
recent_dash_success_window = 120  # 대쉬 후 성공 판정 윈도우 (2초)
# 🌪️ 스핀 & 드라이브 시스템
# 스핀 시스템
ball_spin_strength = 0.0             # 현재 스핀 강도
ball_spin_direction = 0              # 스핀 방향 (-1: 왼쪽, 1: 오른쪽)
ball_spin_decay = 0.98               # 스핀 감소율
# 드라이브 상태
drive_ball_active = False            # 드라이브 공 상태 (연두색 표시용)
drive_hit_boss = False               # 드라이브 공이 보스 패들에 맞았는지 추적
drive_just_activated = False         # 드라이브 방금 발동됨 플래그 (게이지 충전 차단용)
drive_speed_increase = 0.0           # 드라이브로 증가한 공속량 추적 (보스 충돌 시 90% 감소용)
drive_text_timer = 0                 # DRIVE! 텍스트 표시 타이머
# 🚀 파워스매싱 시스템
# 파워스매싱 기본
power_smashing_direction = None      # 파워스매싱 방향 (-1: 왼쪽, 1: 오른쪽, None: 미설정)
power_smashing_original_speed = 0.0  # 파워스매싱 발동 전 원래 공 속도 (보스 반격 시 감속용)
# 파워스매싱 포물선 궤적
power_smashing_parabola_active = False  # 포물선 궤적 활성화 상태
power_smashing_start_time = 0           # 파워스매싱 시작 시간
power_smashing_arc_strength = 0.0       # 포물선 강도 (방향에 따라 ± 값)
power_smashing_gravity_effect = 0.06    # 중력 효과 강도 (뚜렷한 곡선으로 조정)
# 파워스매싱 정지 시간 관리
power_smashing_freeze_start_time = 0    # 파워스매싱 정지 시작 시간
power_smashing_freeze_duration = 1000   # 정지 시간 (밀리초, 1초)
power_smashing_freeze_active = False    # 정지 상태 활성화 여부
# 파워스매싱 이펙트
power_smashing_trails = []  # 파워스매싱 잔상 [(x, y, alpha, size)]
power_smashing_particles = []  # 파워스매싱 파티클 효과
# 고스트샷 관련 변수
mega_smashing_active = False  # 고스트샷 활성화 여부
mega_smashing_bonus_applied = False  # 고스트샷 보너스 적용 여부
mega_smashing_meteor_trail = []  # 고스트샷 유성 궤적 효과 [(x, y, vx, vy, life, size)]
mega_smashing_start_time = 0  # 고스트샷 시작 시간
mega_smashing_particles = []  # 고스트샷 전용 파티클 효과
# 👻 고스트샷 귀신 이펙트
mega_smashing_ghosts = []  # 귀신들 리스트 [{x, y, angle, radius, speed, alpha, wobble}]
mega_smashing_ghost_scatter = False  # 귀신 흩어짐 상태
mega_smashing_ghost_scatter_time = 0  # 흩어짐 시작 시간
# ⚛️ 양자역학 효과 변수
quantum_balls = []  # 양자 상태 공들 [{x, y, vx, vy, alpha, phase, probability, collapsed}]
quantum_explosion_active = False  # 양자 폭발 활성화 여부
quantum_superposition_count = 5  # 중첩 상태 개수
quantum_collapse_timer = 0  # 양자 붕괴 타이머
quantum_measurement_made = False  # 관측 여부
# 충돌 쿨다운 (중복 충돌 방지)
player_collision_cooldown = 0  # 플레이어 패들 충돌 쿨다운
boss_collision_cooldown = 0    # 보스 패들 충돌 쿨다운
player_collision_handled = False  # 플레이어 충돌이 이미 처리되었는지 플래그
player_sound_cooldown = 0  # 플레이어 패들 사운드 재생 쿨다운
# 🛡️ 무한 수평 왕복 방지 시스템 변수들
horizontal_movement_timer = 0   # 수평 움직임 지속 시간 카운터
horizontal_threshold = 0.3      # 수평 판정 임계값 (Y속도가 이 값보다 작으면 수평으로 판정)
max_horizontal_time = 180       # 최대 수평 움직임 허용 시간 (3초)
angle_correction_strength = 0.02 # 각도 보정 강도 (점진적으로 적용)
clock = pygame.time.Clock()
speech_timer = 0
speech_text = ""
tear_particles = []  # 눈물 파티클 리스트
# 사운드 초기화
pygame.mixer.init()
# 사운드 파일 로드
SOUND_SERVE = pygame.mixer.Sound("sounds/serve.wav")
SOUND_WALL = pygame.mixer.Sound("sounds/wall_hit.wav")
SOUND_PADDLE = pygame.mixer.Sound("sounds/paddle_hit.wav")
# 정글지진 효과음 로드
SOUND_QUAKE = pygame.mixer.Sound("sounds/quake_sound.wav")  # 퀘이크 효과음 파일 로드 (이 경로는 실제 파일에 맞게 수정 필요)
whip_sound = pygame.mixer.Sound("sounds/whip_effect.wav")
SOUND_DEFENSE_HIT = pygame.mixer.Sound("sounds/defense_hit.wav")  # ← 파일명에 맞게 수정
SOUND_DEFENSE_START = pygame.mixer.Sound("sounds/speed_defense_start.wav")  # 파일명에 맞게 수정
SOUND_FIREBALL = pygame.mixer.Sound("sounds/fireball.wav")  # 🆕 화염탄 발사 효과음
SOUND_DASH = pygame.mixer.Sound("sounds/dash.wav")  # 🆕 대쉬 효과음
SOUND_ACTIVE_ITEM = pygame.mixer.Sound("sounds/activeitem.wav")  # 🆕 엑티브 아이템 사용 효과음
SOUND_BALLOON_BOOM = pygame.mixer.Sound("sounds/balloonboom.wav")
SOUND_POWER_SMASH = pygame.mixer.Sound("sounds/power_smash.wav")  # 🆕 파워스매싱 발동 효과음
SOUND_POWER_SMASH_LAUNCH = pygame.mixer.Sound("sounds/power_smash_launch.wav")  # 🆕 파워스매싱 공 발사 효과음  # 🎈 풍선 터지는 효과음
SOUND_MISSILE = pygame.mixer.Sound("sounds/missle.wav")  # 🚀 미사일 충돌 효과음
SOUND_STAGE6_BOSS_HIT = pygame.mixer.Sound("sounds/stage6bosshit.wav")  # 🎯 스테이지 6 보스 피격 효과음
SOUND_STAGE6_BEAM = pygame.mixer.Sound("sounds/stage6beam.wav")  # ⚡ 스테이지 6 보스 레이저 빔 효과음
SOUND_STAGE6_BEAM_CHARGE = pygame.mixer.Sound("sounds/stage6beamcharge.wav")  # 🔋 스테이지 6 보스 레이저 충전 효과음
SOUND_STAGE6_INTERCEPTOR_HIT = pygame.mixer.Sound("sounds/stage6carrior.wav")  # 🚀 스테이지 6 인터셉터 충돌 효과음
# 메뉴 사운드 (자동 생성된 파일들)
try:
    SOUND_BUTTON_CLICK = pygame.mixer.Sound("sounds/button_click.wav")  # 🎵 버튼 클릭 사운드
    SOUND_BUTTON_HOVER = pygame.mixer.Sound("sounds/button_hover.wav")  # 🎵 버튼 호버 사운드
except:
    # 사운드 파일이 없으면 기본 사운드 사용
    SOUND_BUTTON_CLICK = SOUND_ACTIVE_ITEM
    SOUND_BUTTON_HOVER = SOUND_ACTIVE_ITEM
# === 추가된 필살기 관련 전역 변수 ===
special_ready = False
special_active = False
special_gauge = 0
rainbow_colors = [(255,0,0), (255,165,0), (255,255,0), (0,255,0), (0,127,255), (0,0,255), (139,0,255)]
rainbow_index = 0
ball_trail = []
# 🤖 보스 AI & 움직임 시스템
# 보스 기본 설정
BOSS_SPEED = 1                       # 기본 보스 속도
BOSS_COLOR = WHITE                   # 기본값: Stage 1 보스는 흰색
boss_speed_boost_timer = 0           # 타이머 (프레임 단위)
boss_prev_x = 0                      # 보스 이전 위치 (속도 계산용)
boss_current_speed = 0               # 현재 AI 보스 속도
# 보스 AI 움직임 파라미터
BOSS_ACCELERATION = 0.798            # 가속도 (35% 감소: 1.2 → 0.798)
BOSS_DECELERATION = 0.798            # 감속도 (35% 감소: 1.2 → 0.798)
BOSS_MAX_SPEED = 6.3175              # 최대 속도 (35% 감소: 9.5 → 6.3175)
BOSS_INSTANT_STOP_DECELERATION = 0.665 # 즉시 정지시킬 때 더 빠른 감속 (35% 감소: 1 → 0.665)
# 보스 시각 효과
boss_trail = []                      # (x, y, alpha) 저장
red_intensity = 0                    # 0~255 사이, 붉은 정도
# 🧠 딥러닝 AI 시스템
# AI 모드 및 인스턴스
enhanced_ai = None                   # 딥러닝 AI 인스턴스
ai_mode = "pro"                     # "junior", "pro", "champion", "mythic"
ai_enabled = False                   # AI 시스템 활성화 여부
ai_decisions_history = []            # AI 결정 기록 (시각화용)
# 🏆 리그별 보스 능력치 보정
def get_league_boss_multiplier(league_mode):
    """리그별 보스 능력치 배수 반환 (개선된 배율)"""
    league_multipliers = {
        "junior": 0.85,    # 🌱 주니어리그: -15% (85%) - 초보자 친화적
        "pro": 1.00,       # ⚡ 프로리그: 기본 (100%) - 표준 난이도
        "champion": 1.25,  # 💎 챔피언리그: +25% (125%) - 도전적
        "mythic": 1.50     # 👑 신화리그: +50% (150%) - 극한 난이도
    }
    return league_multipliers.get(league_mode, 1.00)
def apply_league_boss_config(base_config, league_mode):
    """리그별 보스 설정에 능력치 보정 적용"""
    multiplier = get_league_boss_multiplier(league_mode)
    if multiplier == 1.00:
        return base_config  # 주니어리그는 기본값 그대로
    # 능력치 보정 적용
    modified_config = base_config.copy()
    # 보스 이동 능력치 보정
    modified_config["accel"] = base_config["accel"] * multiplier
    modified_config["decel"] = base_config["decel"] * multiplier  
    modified_config["max_speed"] = base_config["max_speed"] * multiplier
    modified_config["instant_stop"] = base_config["instant_stop"] * multiplier
    # AI 능력치는 실수율로 조정되므로 여기서는 건드리지 않음
    # (predict_chance, predict_error, fail_chance는 유지)
    return modified_config
def get_final_boss_config(stage, league_mode):
    """🏆 통합 보스 설정: 스테이지별 + 리그별 완전 연계"""
    # 1️⃣ 스테이지별 기본 설정 가져오기
    base_config = boss_speed_config.get(stage, boss_speed_config[1])
    # 2️⃣ 리그별 보정 적용
    final_config = apply_league_boss_config(base_config, league_mode)
    # 3️⃣ 디버깅 정보 (가끔씩만)
    if stage == 1 and league_mode != "junior":  # Stage 1에서만 로그
        multiplier = get_league_boss_multiplier(league_mode)
        # print(f"🏆 보스 설정 통합: Stage {stage} + {league_mode} ({multiplier:.0%}) → 최대속도 {final_config['max_speed']:.2f}")
    return final_config
# AI 성능 추적
ai_performance_stats = {
    "total_decisions": 0,
    "successful_hits": 0,
    "missed_balls": 0,
    "confidence_history": [],
    "learning_progress": 0.0
}
# AI 프레임 카운터 (Neural/Hybrid 모드용)
ai_frame_counter = 0
# 🏆 플레이어 실력 분석 시스템
# 플레이어 분석기 인스턴스
player_analyzer = None
skill_display_enabled = True
last_skill_update_time = 0
# 🎮 플레이어 설정
PLAYER_SPEED = 1                     # 플레이어 기본 이동 속도
# 🌊 기타 게임 효과
original_ball_speed_quake = [0, 0]   # 정글지진용 공 속도 백업
# 터렛 시스템 변수
turret_angles = {}  # 각 터렛의 현재 각도
turret_missiles = []  # 발사된 미사일 리스트
last_missile_time = 0  # 마지막 미사일 발사 시간
# 레이저 캐논 시스템 변수
laser_cannon_active = False  # 레이저 발사 중인지
last_laser_time = 0  # 마지막 레이저 발사 시간
laser_charging = False  # 레이저 충전 중인지
laser_charge_start = 0  # 충전 시작 시간
laser_beam_duration = 1500  # 레이저 지속 시간 (1.5초)
player_stunned = False  # 플레이어 감전 상태
player_stun_end_time = 0  # 감전 종료 시간
laser_cannon_angle = 90  # 레이저 캐논 현재 각도 (기본 6시 방향)
laser_rotating_mode = False  # 레이저 회전 모드 (등대 모드)
laser_rotation_direction = 1  # 레이저 회전 방향 (1: 시계방향, -1: 반시계방향)
laser_cooldown = 5000  # 레이저 쿨타임 (5~9초 랜덤)
laser_rotation_range = 60  # 레이저 회전 범위 (랜덤으로 설정됨)
laser_rotation_speed = 1.0  # 레이저 회전 속도 배율 (랜덤으로 설정됨)
# 쉴드 안테나 시스템 변수
shield_antenna_active = False  # 쉴드 활성화 여부
shield_antenna_timer = 0  # 쉴드 타이머
shield_antenna_cooldown = random.randint(10000, 15000)  # 10~15초 쿨다운
last_shield_time = 0  # 마지막 쉴드 생성 시간
shield_duration = 3000  # 쉴드 지속 시간 (3초)
shield_fade_alpha = 255  # 쉴드 페이드 알파값
shield_position = 'center'  # 쉴드 위치 ('left', 'center', 'right')
# 인터셉터 시스템 변수 (스타크래프트 캐리어 스타일)
interceptors = []  # 활성화된 인터셉터 리스트
interceptor_launch_time = 0  # 마지막 인터셉터 출격 시간
interceptor_cooldown = random.randint(10000, 12000)  # 10~12초 쿨다운
interceptor_launching = False  # 인터셉터 출격 중인지
interceptor_launch_queue = []  # 출격 대기 중인 인터셉터
hangar_door_open = False  # 격납고 문 열림 상태
hangar_door_timer = 0  # 격납고 문 애니메이션 타이머
# 미사일 무적 시간
player_missile_invulnerable_time = 0  # 미사일 무적 종료 시간
# 미사일 넉백 시스템 (스테이지 5 화염탄과 동일)
player_missile_knockback_vel = 0  # 미사일 넉백 속도
player_missile_stunned_timer = 0  # 미사일 스턴 타이머
# 스테이지 6 보스 피격 효과 (소닉 스타일)
stage6_boss_hit_timer = 0  # 보스 피격 타이머 (깜빡임 지속 시간)
stage6_boss_hit_flash = False  # 보스 피격 깜빡임 상태
# 📦 아이템 시스템
# 액티브 아이템
active_item_slot = []                # 리스트로 바꿔서 최대 3개 보관
selected_item_index = 0              # 현재 선택 중인 아이템 인덱스
MAX_ITEM_SLOTS = 2                   # 최대 아이템 슬롯 수
last_item_use_time = 0               # 마지막 아이템 사용 시간 (전역 쿨타임용)
# 패시브 아이템
selected_passive_item = -1           # 패시브 아이템 선택 인덱스
# 전역변수
speech_text = ""
speech_timer = 0  # 말풍선 표시 시간 (타이머)
# === Stage 5 화염탄 전역 변수 ===
fireballs = []  # [(pos, vel), ...] 여러 발의 화염탄을 관리
fireball_cooldown = 5000      # ms 단위 쿨타임
fireball_last_cast = 0        # 마지막 발사 시각
fireball_speed = 15           # 화염탄 발사 속도
round_start_time = 0          # 라운드 시작 시간 (화염탄 2.5초 지연용)
boss_throwing = False         # 보스 던지는 모션 여부
boss_throw_timer = 0          # 보스 던지는 모션 지속 시간 (프레임 단위)
# === Stage 4 자기장 관련 ===
magnet_curve_angle = 0
# === Stage 5 홍련 전용 게이지 ===
# === Stage 3 눈물샤워 관련 ===
tear_particles = []  # 💧 파티클 리스트
fireball_img = pygame.Surface((40, 40), pygame.SRCALPHA)
pygame.draw.circle(fireball_img, (255, 80, 0), (20, 20), 20)  # 화염탄 예비 이미지
# 아이템 아이콘 로드
gauge_200_icon = pygame.image.load("items/gauge_200.png").convert_alpha()
gauge_200_icon = pygame.transform.scale(gauge_200_icon, (32, 32))
# 게이지 충전 아이콘 로드
gauge_charge_icon = safe_loader.safe_load_image("items/gauge_200.png", (32, 32))
gauge_charge_icon = safe_loader.safe_scale_image(gauge_charge_icon, (32, 32))
# 스피드부츠 아이콘 로드
speedboots_icon = safe_loader.safe_load_image("items/speedboots.png", (32, 32))
speedboots_icon = safe_loader.safe_scale_image(speedboots_icon, (32, 32))
# 무중력벨트 아이콘 로드
gravitybelt_icon = safe_loader.safe_load_image("gravitybelt.png", (32, 32))
gravitybelt_icon = safe_loader.safe_scale_image(gravitybelt_icon, (32, 32))
# 스피드기어 아이콘 로드
speedgear_icon = safe_loader.safe_load_image("items/speedgear.png", (32, 32))
speedgear_icon = safe_loader.safe_scale_image(speedgear_icon, (32, 32))
# AI 필 아이콘 로드
aipill_icon = safe_loader.safe_load_image("items/aipill.png", (32, 32))
aipill_icon = safe_loader.safe_scale_image(aipill_icon, (32, 32))
# 부활 아이콘 로드
revival_icon = safe_loader.safe_load_image("items/revival.png", (32, 32))
revival_icon = safe_loader.safe_scale_image(revival_icon, (32, 32))
# 장인 아이콘 로드
master_icon = safe_loader.safe_load_image("items/master.png", (32, 32))
master_icon = safe_loader.safe_scale_image(master_icon, (32, 32))
# 쿨타임 아이콘 로드
cooltime_icon = safe_loader.safe_load_image("items/coolingball.png", (32, 32))
cooltime_icon = safe_loader.safe_scale_image(cooltime_icon, (32, 32))
# 🌈 생명수 아이콘 생성 (무지개빛 포션)
try:
    life_elixir_icon = pygame.image.load("items/life_elixir.png").convert_alpha()
    life_elixir_icon = pygame.transform.scale(life_elixir_icon, (32, 32))
except:
    # 무지개빛 포션 아이콘 생성
    life_elixir_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    # 포션 병 모양 (둥근 바닥)
    # 병 몸통
    pygame.draw.ellipse(life_elixir_icon, (60, 60, 80, 200), (8, 12, 16, 18))
    pygame.draw.ellipse(life_elixir_icon, (80, 80, 100, 180), (9, 13, 14, 16))
    # 병 목
    pygame.draw.rect(life_elixir_icon, (60, 60, 80, 200), (13, 8, 6, 6))
    pygame.draw.rect(life_elixir_icon, (80, 80, 100, 180), (14, 9, 4, 5))
    # 코르크 마개
    pygame.draw.rect(life_elixir_icon, (139, 69, 19, 255), (12, 6, 8, 4))
    pygame.draw.rect(life_elixir_icon, (160, 82, 45, 255), (13, 7, 6, 2))
    # 무지개빛 액체 (그라데이션 효과)
    rainbow_colors = [
        (255, 0, 0),      # 빨강
        (255, 127, 0),    # 주황
        (255, 255, 0),    # 노랑
        (0, 255, 0),      # 초록
        (0, 127, 255),    # 하늘
        (0, 0, 255),      # 파랑
        (127, 0, 255),    # 보라
    ]
    # 액체 층별로 그리기
    for i, color in enumerate(rainbow_colors):
        y_pos = 15 + i * 2
        if y_pos < 28:  # 병 안에만 그리기
            # 반투명 무지개 액체
            liquid_color = (*color, 150)
            pygame.draw.ellipse(life_elixir_icon, liquid_color, 
                              (10, y_pos, 12, 3))
    # 반짝임 효과
    pygame.draw.circle(life_elixir_icon, (255, 255, 255, 200), (12, 16), 2)
    pygame.draw.circle(life_elixir_icon, (255, 255, 255, 150), (19, 20), 1)
    # 병 하이라이트
    pygame.draw.arc(life_elixir_icon, (255, 255, 255, 100), 
                    (8, 12, 16, 18), math.radians(200), math.radians(250), 2)
# 충전가방 아이콘 로드
try:
    chargebag_icon = pygame.image.load("items/chargebag.png").convert_alpha()
    chargebag_icon = pygame.transform.scale(chargebag_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    chargebag_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    pygame.draw.circle(chargebag_icon, (100, 255, 100), (16, 16), 12)  # 초록색 외곽
    pygame.draw.circle(chargebag_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(chargebag_icon, (100, 255, 100), (16, 16), 4)   # 초록색 중심
# 스파이크부츠 아이콘 로드
try:
    spikeboots_icon = pygame.image.load("items/spikeboots.png").convert_alpha()
    spikeboots_icon = pygame.transform.scale(spikeboots_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    spikeboots_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    pygame.draw.circle(spikeboots_icon, (255, 100, 255), (16, 16), 12)  # 마젠타색 외곽
    pygame.draw.circle(spikeboots_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(spikeboots_icon, (255, 100, 255), (16, 16), 4)   # 마젠타색 중심
# 대쉬기어 아이콘 로드
try:
    dashgear_icon = pygame.image.load("items/dashgear.png").convert_alpha()
    dashgear_icon = pygame.transform.scale(dashgear_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    dashgear_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    pygame.draw.circle(dashgear_icon, (100, 100, 255), (16, 16), 12)  # 파란색 외곽
    pygame.draw.circle(dashgear_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(dashgear_icon, (100, 100, 255), (16, 16), 4)   # 파란색 중심
# 벌크업 아이콘 로드
try:
    bulkup_icon = pygame.image.load("items/bulkup.png").convert_alpha()
    bulkup_icon = pygame.transform.scale(bulkup_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    bulkup_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    pygame.draw.circle(bulkup_icon, (255, 100, 100), (16, 16), 12)  # 빨간색 외곽
    pygame.draw.circle(bulkup_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(bulkup_icon, (255, 100, 100), (16, 16), 4)   # 빨간색 중심
# 감지센서 아이콘 로드
try:
    sensor_icon = pygame.image.load("items/sensor.png").convert_alpha()
    sensor_icon = pygame.transform.scale(sensor_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    sensor_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    pygame.draw.circle(sensor_icon, (150, 150, 255), (16, 16), 12)  # 연파란색 외곽
    pygame.draw.circle(sensor_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(sensor_icon, (150, 150, 255), (16, 16), 4)   # 연파란색 중심
# 대쉬홀더 아이콘 로드
try:
    dashholder_icon = pygame.image.load("items/dashholder.png").convert_alpha()
    dashholder_icon = pygame.transform.scale(dashholder_icon, (32, 32))
except:
    # 파일이 없으면 기본 아이콘 생성
    dashholder_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    pygame.draw.circle(dashholder_icon, (255, 150, 100), (16, 16), 12)  # 주황색 외곽
    pygame.draw.circle(dashholder_icon, (255, 255, 255), (16, 16), 8)  # 흰색 내부
    pygame.draw.circle(dashholder_icon, (255, 150, 100), (16, 16), 4)   # 주황색 중심
# ITEM_TYPES에 아이콘 할당
for item in items.ITEM_TYPES:
    # 아이템 아이콘 매핑 (딕셔너리로 최적화)
    icon_map = {
        "gauge_200": gauge_200_icon,
        "gauge_charge": gauge_charge_icon,
        "speedboots": speedboots_icon,
        "gravitybelt": gravitybelt_icon,
        "speedgear": speedgear_icon,
        "aipill": aipill_icon,
        "revival": revival_icon,
        "master": master_icon,
        "cooltime": cooltime_icon,
        "chargebag": chargebag_icon,
        "spikeboots": spikeboots_icon,
        "dashgear": dashgear_icon,
        "bulkup": bulkup_icon,
        "sensor": sensor_icon,
        "dashholder": dashholder_icon
    }
    if item["name"] in icon_map:
        item["icon"] = icon_map[item["name"]]
    elif item["name"] == "molotov":
        try:
            item["icon"] = pygame.image.load("items/molotov.png").convert_alpha()
            item["icon"] = pygame.transform.scale(item["icon"], (32, 32))
        except:
            # 화염병 기본 아이콘
            item["icon"] = pygame.Surface((32, 32), pygame.SRCALPHA)
            pygame.draw.circle(item["icon"], (255, 100, 0), (16, 16), 12)
    elif item["name"] == "grenade":
        try:
            item["icon"] = pygame.image.load("items/grenade.png").convert_alpha()
            item["icon"] = pygame.transform.scale(item["icon"], (32, 32))
        except:
            # 수류탄 기본 아이콘
            item["icon"] = pygame.Surface((32, 32), pygame.SRCALPHA)
            pygame.draw.circle(item["icon"], (80, 100, 80), (16, 16), 12)
            pygame.draw.rect(item["icon"], (60, 60, 60), (14, 8, 4, 6))
    elif item["name"] == "predictor":
        try:
            item["icon"] = pygame.image.load("items/predictor.png").convert_alpha()
            item["icon"] = pygame.transform.scale(item["icon"], (32, 32))
        except:
            # 레이저스코프 기본 아이콘
            item["icon"] = pygame.Surface((32, 32), pygame.SRCALPHA)
            pygame.draw.circle(item["icon"], (100, 200, 255), (16, 16), 12, 2)
            pygame.draw.line(item["icon"], (255, 0, 0), (16, 4), (16, 28), 1)
            pygame.draw.line(item["icon"], (255, 0, 0), (4, 16), (28, 16), 1)
# === 롱부스트 관련 ===
long_boost_active = False
long_boost_timer = 0
long_boost_scale = 1.0  # 현재 패들 크기 배율
long_boost_target_scale = 1.0  # 목표 패들 크기 배율
LONG_BOOST_DURATION = 360  # 6초 (60fps * 6)
LONG_BOOST_TRANSITION_TIME = 60  # 1초 동안 크기 변화
# === 배터리 관련 ===
battery_obtained = False  # 배터리 획득 여부
# === 부활 관련 ===
revival_obtained = False  # 부활 아이템 획득 여부
revival_used = False  # 부활 아이템 사용 여부
# === 장인 관련 ===
master_obtained = False  # 장인 아이템 획득 여부
# === 레이저스코프 관련 ===
predictor_active = False  # 레이저스코프 활성화 여부
predictor_timer = 0  # 레이저스코프 남은 시간
predicted_trajectory = []  # 예측된 궤적 저장
last_prediction_ball_y = 0  # 마지막 예측 시 공의 Y 위치
# === 쿨타임 관련 ===
cooltime_obtained = False  # 쿨타임 아이템 획득 여부
# === 충전가방 관련 ===
chargebag_obtained = False  # 충전가방 아이템 획득 여부
# === 스파이크부츠 관련 ===
spikeboots_obtained = False  # 스파이크부츠 아이템 획득 여부
# === 대쉬기어 관련 ===
dashgear_obtained = False  # 대쉬기어 아이템 획득 여부
# === 벌크업 관련 ===
bulkup_obtained = False  # 벌크업 아이템 획득 여부
# === 대쉬홀더 관련 ===
dashholder_obtained = False  # 대쉬홀더 아이템 획득 여부
# 위험감지센서 관련 변수 (독립적 관리)
danger_sensor_obtained = False  # 위험감지센서 아이템 획득 여부
danger_sensor_enabled = True  # 위험감지센서 활성화 상태 (ON/OFF)
sensor_obtained = False  # 센서 아이템 획득 여부 (호환성)
sensor_enabled = True  # 센서 활성화 상태 (호환성)
is_danger_sensor_dash = False  # 위험감지센서로 발동된 대쉬인지 구분 플래그
# === 감지센서 관련 ===
boss_hit_timer = 0  # 보스가 공을 때린 후 경과 시간
# === 벽돌 관련 ===
walls = []  # 벽돌 리스트 [{"rect": pygame.Rect, "hit_count": int, "crack_level": int}]
wall_installing = False  # 벽돌 설치 중
wall_install_timer = 0  # 설치 타이머 (0.5초 = 30프레임)
# === 화염병 관련 ===
molotovs = []  # 던져진 화염병 리스트
fire_zones = []  # 화염 지대 리스트
wall_install_gauge_visible = False  # 설치 게이지 표시 여부
molotov_throwing = False  # 화염병 투척 모션 중
molotov_throw_timer = 0  # 투척 모션 타이머
molotov_target_x = 0  # 화염병 목표 X 좌표
molotov_target_y = 0  # 화염병 목표 Y 좌표
# === 수류탄 관련 ===
grenades = []  # 던져진 수류탄 리스트
explosion_zones = []  # 폭발 지역 리스트
grenade_throwing = False  # 수류탄 투척 모션 중
grenade_throw_timer = 0  # 투척 모션 타이머
grenade_target_x = 0  # 수류탄 목표 X 좌표
grenade_target_y = 0  # 수류탄 목표 Y 좌표
# === 조명탄 관련 ===
flares = []  # 던져진 조명탄 리스트
flare_zones = []  # 조명 지역 리스트
flare_throwing = False  # 조명탄 투척 모션 중
flare_throw_timer = 0  # 투척 모션 타이머
flare_target_x = 0  # 조명탄 목표 X 좌표
flare_target_y = 0  # 조명탄 목표 Y 좌표
boss_confused_timer = 0  # 보스 혼란 타이머 (조명탄 효과)
# === 연막탄 관련 ===
smoke_grenades = []  # 던져진 연막탄 리스트
smoke_zones = []  # 연막 지역 리스트
smoke_grenade_target_x = 0  # 연막탄 목표 X 좌표
smoke_grenade_target_y = 0  # 연막탄 목표 Y 좌표
# 보스별 스피드 및 예측 설정 - config에서 가져온 값에 추가 설정
# BOSS_CONFIGS에서 기본값을 가져오고 추가 속성만 정의
boss_speed_config = {}
for stage_num in range(1, 6):
    if stage_num in BOSS_CONFIGS:
        boss_speed_config[stage_num] = {
            "accel": BOSS_CONFIGS[stage_num]["accel"],
            "decel": BOSS_CONFIGS[stage_num]["decel"],
            "max_speed": BOSS_CONFIGS[stage_num]["max_speed"],
            "instant_stop": BOSS_CONFIGS[stage_num]["instant_stop"],
            # AI 추가 설정
            "predict_chance": 0.45 + (stage_num - 1) * 0.05,  # 스테이지별 증가
            "predict_error": 95 - (stage_num - 1) * 5,        # 스테이지별 감소
            "fail_chance": 0.010 - (stage_num - 1) * 0.001,   # 스테이지별 감소
            "fail_error": BOSS_CONFIGS[stage_num]["fail_error"],
        }
# 보스 기본 속도 설정값 (초기값 저장용)
# 보스 물리 상수 (35% 감소 적용)
BOSS_ACCELERATION = 0.798       # 1.2 → 0.798
BOSS_DECELERATION = 0.798       # 1.2 → 0.798
BOSS_MAX_SPEED = 6.3175         # 9.5 → 6.3175
BOSS_INSTANT_STOP_DECELERATION = 0.665  # 1 → 0.665
CURRENT_BG = STAGE1_BG  # 기본값
quake_last_used_time = -9999  # 마지막 정글지진 발동 시간
QUAKE_COOLDOWN = 4000         # 쿨타임: 7000ms (7초 예시)
horizontal_bounce_count = 0
boss_trail = []  # [(x, y, alpha)] 형식의 튜플 리스트
long_boost_growing = False
long_boost_shrinking = False
player_last_shot_speed = BALL_BASE_SPEED  # 기본 속도로 초기화
round_wins = 0
round_losses = 0
win_goal = 3  # 기본 승리 목표점수
# 핑파이터 스타일 듀스 시스템
deuce_mode = False  # 듀스 모드 상태
deuce_goal = 4  # 듀스에서의 승리 목표점수 (4점)
deuce_wins = 0  # 듀스에서의 플레이어 점수
deuce_losses = 0  # 듀스에서의 보스 점수
is_player_serve = True
is_waiting_for_serve = True
waiting_start_time = 0
wait_delay = 0
# === 일시정지 시스템 ===
game_paused = False  # 게임 일시정지 상태
boss_fake_move = False
boss_fake_start_time = 0
boss_fake_during_player_serve = False
speed_defense_active = False
speed_defense_cooldown = 100  # 약 3초 쿨타임
speed_defense_timer = 0
speed_defense_checked = False
original_speed = [0, 0]  # 암행트위스트 발동 전 속도 백업용
final_wave_direction = [0, 0]  # 공의 마지막 이동 방향 (X, Y)
PLAYER_IMG = pygame.image.load("ufo_player.png").convert_alpha()
PLAYER_IMG = pygame.transform.scale(PLAYER_IMG, (250, 100))  # 세로 늘리기
boss_special_waiting = False
# UFO 확장 애니메이션 관련
long_boost_animating = False
long_boost_animation_step = 0
# 보스 이미지 크기 - config 오버라이드
BOSS_IMG_WIDTH = 160  # 기본값 오버라이드
BOSS_IMG_HEIGHT = 80
# 스테이지 4, 5 전용 사이즈
BOSS_IMG_STAGE4_WIDTH = 130
BOSS_IMG_STAGE4_HEIGHT = 70
BOSS_IMG_STAGE5_WIDTH = 130
BOSS_IMG_STAGE5_HEIGHT = 70
# 전역 변수 추가 (파일 위쪽에 위치)
whip_wave_phase = 0
# 🚀 가속화 스킬 관련 변수
acceleration_active = False  # 가속화 효과 활성 여부
acceleration_original_speed = [0, 0]  # 가속화 적용 전 원래 공속도
# 📍 타격 이펙트 관련 변수
impact_particles = []  # 타격 파티클 리스트 [x, y, vx, vy, size, alpha, color, life]
last_impact_strength = 0  # 마지막 타격 강도
# === 멘헤라걸 전용 붉어짐 효과 관련 전역 변수 ===
boss_red_intensity = 0  # 붉은 정도 (0 ~ 255)
boss_special_gauge = 0  # 보스 필살기 게이지
boss_special_ready = False
# 사이코볼
emotional_overdrive_active = False
emotional_overdrive_timer = 0
# === 대쉬 스피릿 레이저 시스템 ===
dash_spirit_lasers = []  # [(start_x, start_y, end_x, end_y, remaining_time, direction, electric_offset), ...]
DASH_SPIRIT_LASER_DURATION = 360  # 6초 (60fps 기준)
DASH_SPIRIT_LASER_WIDTH = 8  # 레이저 두께
DASH_SPIRIT_LASER_COLOR = (135, 206, 235)  # 하늘색 (SkyBlue)
DASH_SPIRIT_ELECTRIC_COLOR = (255, 255, 255)  # 전기 효과 (흰색)
# === Stage 5 화염 궤적 스킬 관련 전역 ===
flame_trail_active = False
flame_trail_timer = 0

# === 보스 히트 애니메이션 관련 전역 변수 ===
boss_hit_animation_active = False
boss_hit_animation_timer = 0
BOSS_HIT_ANIMATION_DURATION = 10  # 애니메이션 지속 시간

# === 파티클 관련 전역 변수 ===
balloon_particles = []
water_particles = []
flame_trail_phase = 0
flame_trail_positions = []  # [(x, y)] 궤적 저장
# 패들 반짝임
overdrive_flash_timer = 0
# 잔상 저장
overdrive_trails = []
# 대쉬 잔상 효과
dash_afterimages = []  # [(x, y, alpha, image)]
psycho_bg_timer = 0
# === 멘헤라걸 스킬: 눈물의 비 관련 전역 변수 ===
tears_active = False
tears_timer = 0
falling_tears = []  # [(x, y, speed)] 리스트
last_tears_cast_time = -9999  # 마지막 눈물샤워 발동 시간
TEARS_COOLDOWN = 7000        # 쿨타임 (밀리초 단위 = 5초)
passive_item_list = []
try:
    BOSS_IMG_STAGE1 = pygame.image.load("boss_stage1.png").convert_alpha()
    BOSS_IMG_STAGE1 = pygame.transform.scale(BOSS_IMG_STAGE1, (BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT))
except:
    BOSS_IMG_STAGE1 = pygame.Surface((BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT), pygame.SRCALPHA)
    BOSS_IMG_STAGE1.fill((255, 255, 255))
try:
    BOSS_IMG_STAGE2 = pygame.image.load("boss_stage2.png").convert_alpha()
    BOSS_IMG_STAGE2 = pygame.transform.scale(BOSS_IMG_STAGE2, (BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT))
except:
    BOSS_IMG_STAGE2 = pygame.Surface((BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT), pygame.SRCALPHA)
    BOSS_IMG_STAGE2.fill((0, 255, 0))
try:
    BOSS_IMG_STAGE3 = pygame.image.load("boss_stage3.png").convert_alpha()
    BOSS_IMG_STAGE3 = pygame.transform.scale(BOSS_IMG_STAGE3, (BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT))
except:
    BOSS_IMG_STAGE3 = pygame.Surface((BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT), pygame.SRCALPHA)
    BOSS_IMG_STAGE3.fill((255, 0, 255))  # 보스 3의 기본 색상 (보라색 예시)
try:
    BOSS_IMG_STAGE4 = pygame.image.load("boss_stage4.png").convert_alpha()
    BOSS_IMG_STAGE4 = pygame.transform.scale(BOSS_IMG_STAGE4, (BOSS_IMG_STAGE4_WIDTH, BOSS_IMG_STAGE4_HEIGHT))
except:
    BOSS_IMG_STAGE4 = pygame.Surface((BOSS_IMG_STAGE4_WIDTH, BOSS_IMG_STAGE4_HEIGHT), pygame.SRCALPHA)
    BOSS_IMG_STAGE4.fill((200, 200, 150))
try:
    BOSS_IMG_STAGE5 = pygame.image.load("boss_stage5.png").convert_alpha()
    BOSS_IMG_STAGE5 = pygame.transform.scale(BOSS_IMG_STAGE5, (BOSS_IMG_STAGE5_WIDTH, BOSS_IMG_STAGE5_HEIGHT))
except:
    BOSS_IMG_STAGE5 = pygame.Surface((BOSS_IMG_STAGE5_WIDTH, BOSS_IMG_STAGE5_HEIGHT), pygame.SRCALPHA)
    BOSS_IMG_STAGE5.fill((255, 80, 0))
try:
    SPEED_DEFENSE_IMG = pygame.image.load("boss_stage2_speed.png").convert_alpha()
    SPEED_DEFENSE_IMG = pygame.transform.scale(SPEED_DEFENSE_IMG, (BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT))
except:
    SPEED_DEFENSE_IMG = pygame.Surface((BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT), pygame.SRCALPHA)
    SPEED_DEFENSE_IMG.fill((255, 0, 0))  # 디버깅용 붉은 사각형
try:
    TEAR_IMG = pygame.image.load("tear_drop.png").convert_alpha()
    TEAR_IMG = pygame.transform.scale(TEAR_IMG, (36, 36))  # 원하는 크기로 조정
except:
    TEAR_IMG = pygame.Surface((24, 24), pygame.SRCALPHA)
    pygame.draw.circle(TEAR_IMG, (0, 200, 255), (12, 12), 12)  # 예비용 원형 눈물
BOSS_IMG = BOSS_IMG_STAGE1  # 기본값: Stage 1 보스 이미지
BALL_IMG = pygame.image.load("ball.png").convert_alpha()
BALL_IMG = pygame.transform.smoothscale(BALL_IMG, (36, 36))
hit_animation_active = False
hit_animation_timer = 0
HIT_ANIMATION_DURATION = 6  # 프레임 수
player_slow_timer = 0  # 눈물 디버프 지속 시간 (프레임 단위)
quake_offset_y = 0  # ← 전역 초기화 (draw_objects에서 사용)
# 화면 흔들림 오프셋 변수들
screen_shake_offset_x = 0
screen_shake_offset_y = 0
grenade_shake_timer = 0  # 수류탄 폭발 화면 흔들림 타이머
# Stage 2 특수 기술: 정글지진
quake_active = False
quake_duration = 80
quake_timer = 0
# 전역
flame_particles = []
# 별가루 파티클 시스템 (무중력벨트 + 스피드기어 시너지)
# 목성 띠 애니메이션 (무중력벨트 + 스피드기어 시너지)
jupiter_ring_angle = 0  # 회전 각도
jupiter_ring_speed = 3  # 회전 속도
jupiter_ring_segments = 12  # 띠 세그먼트 개수
# 무중력벨트 + 스피드기어 시너지 효과
gravity_speed_synergy = False  # 시너지 활성화 여부
synergy_paddle_width_boost = 1.6  # 패들 가로길이 60% 증가
def draw_jupiter_ring(surface, paddle_rect):
    """목성 띠 애니메이션 그리기 (무중력벨트 + 스피드기어 시너지)"""
    global jupiter_ring_angle
    # 패들 중심점
    center_x = paddle_rect.centerx
    center_y = paddle_rect.centery
    # 띠 크기 (패들보다 약간 크게)
    ring_width = paddle_rect.width + 20
    ring_height = paddle_rect.height + 10
    # 회전 각도 업데이트
    jupiter_ring_angle += jupiter_ring_speed
    if jupiter_ring_angle >= 360:
        jupiter_ring_angle = 0
    # 각 세그먼트 그리기
    for i in range(jupiter_ring_segments):
        segment_angle = jupiter_ring_angle + (i * 360 / jupiter_ring_segments)
        rad = math.radians(segment_angle)
        # 타원형 궤도상의 위치 계산
        x = center_x + math.cos(rad) * (ring_width / 2)
        y = center_y + math.sin(rad) * (ring_height / 2)
        # 세그먼트 크기 (각도에 따라 크기 변화)
        segment_size = 3 + math.sin(math.radians(segment_angle * 2)) * 2
        # 파란색 계열 색상 (목성 띠 느낌)
        blue_intensity = 150 + int(math.sin(math.radians(segment_angle * 3)) * 50)
        color = (50, 100, blue_intensity)
        # 세그먼트 그리기
        pygame.draw.circle(surface, color, (int(x), int(y)), int(segment_size))
        # 글로우 효과 (더 밝은 중심)
        glow_color = (100, 150, 255)
        pygame.draw.circle(surface, glow_color, (int(x), int(y)), int(segment_size // 2))
def show_hongryun_explosion():
    """Stage 5 홍련폭염 발동 시 화면 연출"""
    overlay = pygame.Surface((WIDTH, HEIGHT))
    overlay.fill((255, 60, 30))  # 붉은빛
    for alpha in range(0, 200, 20):  # 페이드 인
        overlay.set_alpha(alpha)
        SCREEN.blit(overlay, (0, 0))
        pygame.display.flip()
        pygame.time.delay(30)
    # 🔹 show_fade_text 호출 수정
    show_fade_text("홍련폭염!!")  # duration 제거
    for alpha in range(200, 0, -20):  # 페이드 아웃
        overlay.set_alpha(alpha)
        SCREEN.blit(overlay, (0, 0))
        pygame.display.flip()
        pygame.time.delay(30)
def show_winner_text(winner_name):
    """승리 텍스트 표시 - DialogSystem 사용"""
    global speech_text, speech_timer, rolling_active, rolling_timer, rolling_direction, rolling_stun_timer
    global rolling_dash_available_timer
    # 말풍선 제거
    speech_text = ""
    speech_timer = 0
    # 키 이벤트 큐 비우기 - 대쉬 버그 방지
    pygame.event.clear()
    pygame.event.pump()
    # 🔧 대쉬 상태 초기화 - 다음 라운드 버그 방지
    # 레거시 대쉬 변수 초기화
    rolling_active = False
    rolling_timer = 0
    rolling_direction = 0
    rolling_stun_timer = 0
    rolling_dash_available_timer = 0  # 추가 초기화
    # 플레이어 속도 초기화 - 다음 라운드에서 자동 이동 방지
    global current_speed
    current_speed = 0
    # 대쉬 매니저 초기화
    if 'dash' in globals() and dash is not None:
        dash.is_active = False
        dash.direction = 0
        dash.timer = 0
        dash.stun_timer = 0
    # 🎮 새로운 DialogSystem 사용 (옵션)
    # dialog_system이 초기화되어 있으면 사용
    if 'dialog_system' in globals() and dialog_system is not None:
        dialog_system.show_winner_text(winner_name)
        return
    # 🎯 깔끔한 승리 스타일
    if "Player" in winner_name or "플레이어" in winner_name:
        main_color = (255, 255, 255)
        accent_color = (0, 200, 100)
        result_text = "VICTORY"
        show_winner_name = False  # 승리 시에도 플레이어 이름 표시 안함 (UI 통일감)
    else:
        main_color = (255, 255, 255)
        accent_color = (200, 80, 80)
        result_text = "DEFEAT"
        show_winner_name = False  # 패배 시에는 보스 이름 표시하지 않음
    # 폰트 생성
    font_large = pygame.font.Font("NanumSquareB.ttf", 64)
    font_small = pygame.font.Font("NanumSquareR.ttf", 24)
    result_surface = font_large.render(result_text, True, main_color)
    winner_surface = font_small.render(winner_name if show_winner_name else "", True, accent_color)
    # 🌟 빠른 페이드인 (0.4초)
    for alpha in range(0, 256, 25):
        draw_field()
        draw_objects()
        # 반투명 오버레이
        overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, min(150, alpha)))
        SCREEN.blit(overlay, (0, 0))
        # 메인 텍스트 위치 (패배 시에는 중앙에만 표시)
        if show_winner_name:
            result_rect = result_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2 - 20))
            winner_rect = winner_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2 + 40))
        else:
            result_rect = result_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2))
            winner_rect = winner_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2 + 40))
        # 액센트 라인 (위쪽)
        top_line_width = result_rect.width + 40
        top_line_y = result_rect.top - 15
        top_line_surface = pygame.Surface((top_line_width, 3), pygame.SRCALPHA)
        top_line_surface.fill((*accent_color, min(255, alpha + 50)))
        SCREEN.blit(top_line_surface, ((WIDTH - top_line_width) // 2, top_line_y))
        # 액센트 라인 (아래쪽) - 승리 시에만 표시
        if show_winner_name:
            bottom_line_width = winner_rect.width + 20
            bottom_line_y = winner_rect.bottom + 10
            bottom_line_surface = pygame.Surface((bottom_line_width, 2), pygame.SRCALPHA)
            bottom_line_surface.fill((*accent_color, min(255, alpha + 50)))
            SCREEN.blit(bottom_line_surface, ((WIDTH - bottom_line_width) // 2, bottom_line_y))
        # 텍스트
        result_surface.set_alpha(alpha)
        SCREEN.blit(result_surface, result_rect)
        # 승리 시에만 승자 이름 표시
        if show_winner_name:
            winner_surface.set_alpha(alpha)
            SCREEN.blit(winner_surface, winner_rect)
        pygame.display.flip()
        pygame.time.delay(16)
    # 💫 유지 (1초)
    hold_start = pygame.time.get_ticks()
    hold_duration = 1000
    while pygame.time.get_ticks() - hold_start < hold_duration:
        draw_field()
        draw_objects()
        # 반투명 오버레이
        overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 150))
        SCREEN.blit(overlay, (0, 0))
        # 텍스트 위치
        if show_winner_name:
            result_rect = result_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2 - 20))
            winner_rect = winner_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2 + 40))
        else:
            result_rect = result_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2))
            winner_rect = winner_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2 + 40))
        # 액센트 라인 (미세한 펄스)
        time_elapsed = pygame.time.get_ticks() - hold_start
        pulse = int(3 * math.sin(time_elapsed * 0.008))
        # 위쪽 라인
        top_line_width = result_rect.width + 40 + pulse
        top_line_y = result_rect.top - 15
        top_line_surface = pygame.Surface((top_line_width, 3), pygame.SRCALPHA)
        top_line_surface.fill(accent_color)
        SCREEN.blit(top_line_surface, ((WIDTH - top_line_width) // 2, top_line_y))
        # 아래쪽 라인 - 승리 시에만 표시
        if show_winner_name:
            bottom_line_width = winner_rect.width + 20 + pulse
            bottom_line_y = winner_rect.bottom + 10
            bottom_line_surface = pygame.Surface((bottom_line_width, 2), pygame.SRCALPHA)
            bottom_line_surface.fill(accent_color)
            SCREEN.blit(bottom_line_surface, ((WIDTH - bottom_line_width) // 2, bottom_line_y))
        # 텍스트
        SCREEN.blit(result_surface, result_rect)
        # 승리 시에만 승자 이름 표시
        if show_winner_name:
            SCREEN.blit(winner_surface, winner_rect)
        pygame.display.flip()
        pygame.time.delay(16)
    # 🌅 빠른 페이드아웃 (0.3초)
    for alpha in range(255, -1, -35):
        draw_field()
        draw_objects()
        # 반투명 오버레이
        overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, max(0, alpha // 2)))
        SCREEN.blit(overlay, (0, 0))
        # 텍스트 위치
        if show_winner_name:
            result_rect = result_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2 - 20))
            winner_rect = winner_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2 + 40))
        else:
            result_rect = result_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2))
            winner_rect = winner_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2 + 40))
        # 액센트 라인
        top_line_width = result_rect.width + 40
        top_line_y = result_rect.top - 15
        top_line_surface = pygame.Surface((top_line_width, 3), pygame.SRCALPHA)
        top_line_surface.fill((*accent_color, max(0, alpha)))
        SCREEN.blit(top_line_surface, ((WIDTH - top_line_width) // 2, top_line_y))
        # 아래쪽 라인 - 승리 시에만 표시
        if show_winner_name:
            bottom_line_width = winner_rect.width + 20
            bottom_line_y = winner_rect.bottom + 10
            bottom_line_surface = pygame.Surface((bottom_line_width, 2), pygame.SRCALPHA)
            bottom_line_surface.fill((*accent_color, max(0, alpha)))
            SCREEN.blit(bottom_line_surface, ((WIDTH - bottom_line_width) // 2, bottom_line_y))
        # 텍스트
        result_surface.set_alpha(max(0, alpha))
        SCREEN.blit(result_surface, result_rect)
        # 승리 시에만 승자 이름 표시
        if show_winner_name:
            winner_surface.set_alpha(max(0, alpha))
            SCREEN.blit(winner_surface, winner_rect)
        pygame.display.flip()
        pygame.time.delay(12)
def go_to_next_round():
    global special_active, special_ready, special_gauge, whip_active, whip_timer, quake_active, quake_timer, whip_hit_by_player, whip_original_ball_speed
    global rolling_consecutive_count  # 🆕 연속 대쉬 카운터 추가
    global ball_trail, ball_vel, ball_angle, PLAYER_SPEED
    global stage4_magnetic_active, stage4_magnetic_timer, boss_special_ready_stage4, boss_special_gauge_stage4, flame_trail_active, flame_trail_positions, flame_trail_timer, flame_trail_phase
    global fireballs, boss_throwing, boss_throw_timer  # 🆕 홍련탄 관련 변수 추가
    global speedboots_obtained, speedgear_obtained  # 🆕 스피드 아이템 효과 초기화
    global water_trail_positions, water_trail_timer  # 🆕 물자국 초기화
    global aipill_active  # 🆕 AI 필 변수 추가
    global rolling_active, rolling_timer, rolling_direction, rolling_speed  # 🆕 대시 관련 변수 추가
    global balloon_active, balloon_timer, balloons, balloon_used_this_round  # 🆕 풍선 스킬 변수 추가
    global boss_hit_animation_active, boss_hit_animation_timer  # 🆕 보스 충돌 애니메이션 변수 추가
    global drive_ball_active, drive_hit_boss, drive_speed_increase  # 🆕 드라이브 관련 변수 추가
    global power_smashing_direction, power_smashing_original_speed  # 🚀 파워스매싱 관련 변수 추가
    global lightning_master_speed, ice_queen_speed, fire_knight_speed, wind_spirit_speed  # 🆕 새로운 보스들 속도 초기화
    global fire_zones, molotovs  # 🔥 화염병 관련 변수 추가
    # 공 정지
    ball_vel = [0, 0]
    physics_manager.reset_ball(is_player_serve)
    # 🔥 화염병 관련 초기화 (라운드 전환 시 화염 지대 제거)
    fire_zones.clear()  # 모든 화염 지대 제거
    molotovs.clear()    # 날아가는 화염병도 제거
    # 💣 수류탄 관련 초기화
    grenades.clear()  # 날아가는 수류탄 제거
    explosion_zones.clear()  # 폭발 지역 제거
    # 필살기 상태 리셋 (게이지는 유지)
    special_active = False
    # ✅ 게이지가 400 기준이면 준비 상태로, 아니면 False
    special_ready = (special_gauge >= 350)  # 파워스매시 비용 조정: 400 → 350
    # 보스 스킬 상태 초기화
    whip_active = False
    whip_timer = 0
    whip_hit_by_player = False  # 🌟 상모돌리기 플레이어 충돌 상태 초기화
    whip_original_ball_speed = [0, 0]  # 🌟 상모돌리기 이전 속도 초기화
    whip_sound.stop()  # 🆕 상모돌리기 사운드 중지
    if BOSS and hasattr(BOSS, 'whip_sound') and BOSS.whip_sound:
        BOSS.whip_sound.stop()  # 🆕 보스 상모돌리기 사운드 중지
    quake_active = False
    quake_timer = 0
    PLAYER_SPEED = 1
    ball_angle = 0
    ball_trail.clear()
    # ✅ 홍련폭염 상태 초기화
    flame_trail_active = False
    flame_trail_positions.clear()
    flame_trail_timer = 0
    flame_trail_phase = 0
    # 🆕 홍련탄 초기화
    fireballs.clear()
    boss_throwing = False
    boss_throw_timer = 0
    # 🆕 AI 알약 상태 초기화
    aipill_active = False
    # 🆕 대시 상태 초기화
    rolling_active = False
    rolling_timer = 0
    rolling_direction = 0
    rolling_speed = 0
    # 플레이어 속도 초기화
    current_speed = 0
    rolling_stun_timer = 0  # 통제불능 시간 초기화
    rolling_dash_available_timer = 0  # 대쉬 가능 타이머 초기화
    # 🔧 토큰 시스템 초기화 (라운드 시작 시 패시브 아이템 효과 적용)
    global rolling_charges, rolling_charge_timer, rolling_consecutive_count, rolling_cooldown
    base_charges = 1  # 기본 1개
    holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
    amplification_bonus = academy.get_skill_bonus("dash_amplification")
    rolling_charges = int(base_charges + holder_bonus + amplification_bonus)
    rolling_charge_timer = 0  # 충전 타이머 초기화
    rolling_consecutive_count = 0  # 연속 대쉬 카운터 초기화
    rolling_cooldown = 0  # 쿨다운 초기화
    # 대쉬 매니저와 동기화
    if dash is not None:
        dash.update_bonuses(dashholder_obtained, dashgear_obtained, spikeboots_obtained)
        dash.reset_to_max()  # 최대 토큰으로 초기화
    # 🆕 풍선 스킬 상태 초기화
    balloon_active = False
    balloon_timer = 0
    balloons.clear()
    balloon_used_this_round = False  # 다음 라운드에서 다시 사용 가능하도록 리셋
    # 🆕 보스 충돌 애니메이션 초기화
    boss_hit_animation_active = False
    boss_hit_animation_timer = 0
    # 🎯 멘헤라걸 필살기 상태
    global emotional_overdrive_active, emotional_overdrive_timer, overdrive_flash_timer, overdrive_trails
    global boss_special_gauge, boss_special_ready, boss_special_waiting, boss_red_intensity
    emotional_overdrive_active = False
    emotional_overdrive_timer = 0
    overdrive_flash_timer = 0
    overdrive_trails.clear()
    if current_stage == 3:
        # 게이지 100 감소, 최소 0 제한
        boss_special_gauge = max(0, boss_special_gauge - 100)
        # 게이지가 500 미만이면 준비 상태 해제
        if boss_special_gauge < 500:
            boss_special_ready = False
            boss_special_waiting = False
        # 붉은 정도를 게이지에 비례하여 다시 계산
        boss_red_intensity = (boss_special_gauge / 500) * 220
    else:
        boss_special_gauge = 0
        boss_special_ready = False
        boss_special_waiting = False
        boss_red_intensity = 0
    # 🎯 멘헤라걸 눈물샤워 초기화
    global tears_active, tears_timer, falling_tears, last_tears_cast_time, player_slow_timer  # ← 디버프 초기화용
    tears_active = False
    tears_timer = 0
    falling_tears.clear()
    last_tears_cast_time = -9999
    player_slow_timer = 0  # ← 다음 라운드로 넘어가면 느려짐 해제
    # ✅ Stage 4 자기장 강제 종료
    stage4_magnetic_active = False
    stage4_magnetic_timer = 0
    boss_special_ready_stage4 = False
    boss_special_gauge_stage4 = 0
    # ✅ Stage 2 스킬: 스피드디펜스 상태 초기화
    global speed_defense_active, speed_defense_timer, boss_trail  # 🆕 보스 꼬리 효과 변수 추가
    global BOSS_ACCELERATION, BOSS_DECELERATION, BOSS_MAX_SPEED, BOSS_INSTANT_STOP_DECELERATION, BOSS_ACCELERATION_DEFAULT, BOSS_DECELERATION_DEFAULT, BOSS_MAX_SPEED_DEFAULT, BOSS_INSTANT_STOP_DECELERATION_DEFAULT
    speed_defense_active = False
    speed_defense_timer = 0
    boss_trail.clear()  # 🆕 스피드 디펜스 꼬리 효과 정리
    BOSS_ACCELERATION = BOSS_ACCELERATION_DEFAULT
    BOSS_DECELERATION = BOSS_DECELERATION_DEFAULT
    BOSS_MAX_SPEED = BOSS_MAX_SPEED_DEFAULT
    BOSS_INSTANT_STOP_DECELERATION = BOSS_INSTANT_STOP_DECELERATION_DEFAULT
    # 🆕 스피드 아이템 효과는 유지 (라운드가 바뀌어도 효과 지속)
    # speedboots_obtained = False  # 제거 - 패시브 아이템은 라운드가 바뀌어도 유지
    # 🆕 Aipill 초기화 (라운드가 바뀌면 Aipill 효과 종료)
    if aipill_active:
        print("라운드 변경으로 인해 Aipill 효과가 종료됩니다.")
        aipill_active = False
    # speedgear_obtained = False   # 제거 - 패시브 아이템은 라운드가 바뀌어도 유지
    # items.speedboots_obtained = False  # 제거
    # items.speedgear_obtained = False   # 제거
    # 🆕 물자국 초기화
    water_trail_positions.clear()
    water_trail_timer = 0
    # 🆕 드라이브 관련 상태 초기화
    drive_ball_active = False
    drive_hit_boss = False
    drive_speed_increase = 0.0
    # 🌪️ 스핀 상태 완전히 초기화 (스테이지 전환 시 드라이브 효과 제거)
    global ball_spin_strength, ball_spin_direction
    ball_spin_strength = 0.0
    ball_spin_direction = 0
    # 🚀 파워스매싱 관련 상태 초기화
    power_smashing_direction = None
    power_smashing_original_speed = 0.0
    power_smashing_parabola_active = False
    power_smashing_start_time = 0
    power_smashing_arc_strength = 0.0
    # 🆕 새로운 보스들 속도 초기화
    lightning_master_speed = 0.0
    ice_queen_speed = 0.0
    fire_knight_speed = 0.0
    wind_spirit_speed = 0.0
    # 🌟 대쉬 스피릿 레이저 초기화
    global dash_spirit_lasers
    dash_spirit_lasers.clear()
    # 🧠 AI 메모리 정리 (라운드 간 성능 최적화)
    optimize_ai_memory_for_round()
    reset_round()
    whip_sound.stop()
# === Stage 4 보스 필살기 관련 전역 변수 ===
boss_special_gauge_stage4 = 0
boss_special_ready_stage4 = False
stage4_magnetic_active = False
stage4_magnetic_timer = 0
stage4_magnetic_radius = 130
# 🗑️ get_reddish_ball_image 함수 제거됨 - 예전 파워스매싱 시스템 제거
def activate_fireball():
    global fireball_active, fireball_pos, fireball_vel, fireball_timer, fireball_direction, fireball_cooldown_timer
    fireball_active = True
    fireball_pos = [BOSS.centerx, BOSS.bottom]  # 보스 패들 아래에서 시작
    fireball_direction = random.choice([-1, 1])  # 왼/오 무작위
    fireball_vel = [fireball_speed * fireball_direction, fireball_speed]
    fireball_timer = 600  # 10초 정도 존재 가능
    fireball_cooldown_timer = random.randint(5000, 15000)  # 5~15초 뒤 재발동
    # 🔹 보스 던지는 모션 잠깐 멈춤
    pygame.time.set_timer(pygame.USEREVENT + 1, 300)  # 0.3초 모션
    show_speech("화염탄!", duration=30)
# === 눈물의 비 발동 함수 ===
def activate_tears_of_pain():
    global tears_active, tears_timer, falling_tears
    tears_active = True
    tears_timer = 400  # 5초 지속 (60fps 기준)
    falling_tears = []
    for _ in range(10):  # 눈물 개수
        x = random.randint(0, WIDTH - 20)
        y = random.randint(-200, -20)
        speed = random.uniform(2, 5)
        falling_tears.append([x, y, speed, y])  # ← 이전 y값도 저장
# === 눈물의 비 상태 처리 함수 ===
def handle_tears():
    global tears_active, tears_timer, falling_tears
    if not tears_active:
        return
    tears_timer -= 1
    if tears_timer <= 0:
        tears_active = False
        falling_tears = []
        return
    for tear in falling_tears:
        tear[3] = tear[1]  # 이전 y 저장
        tear[1] += tear[2]
# === 눈물의 비 그리기 함수 ===
def draw_tears():
    """눈물 이펙트 그리기 - EffectRenderer 사용"""
    # 실제 눈물 이미지 그리기
    if tears_active and falling_tears:
        for tear in falling_tears:
            x, y = int(tear[0]), int(tear[1])
            # TEAR_IMG 그리기
            if TEAR_IMG:
                SCREEN.blit(TEAR_IMG, (x - 18, y - 18))  # 36x36 이미지 중앙 정렬
            else:
                # 대체 렌더링 (이미지가 없을 경우)
                draw.circle((0, 150, 255), (x, y), 12)
                draw.circle((100, 200, 255), (x - 3, y - 3), 5)
    
    # 눈물 파티클 효과 그리기
    if tear_particles:
        effect_renderer.draw_particles(SCREEN, tear_particles, (0, 100, 255))
def check_tear_collisions():
    global falling_tears, player_slow_timer
    new_tears = []
    for tear in falling_tears:
        x, y, speed, prev_y = tear
        tear_rect = pygame.Rect(x, y, 10, 10)
        if (
            tear_rect.colliderect(PLAYER) and
            prev_y <= PLAYER.top and y >= PLAYER.top
        ):
            player_slow_timer = 130  # 2초간 느려짐 (60fps 기준)
            # 🚀 성능 최적화: 파티클 개수를 절반으로 줄임 (12 → 6)
            for _ in range(6):
                angle = random.uniform(200, 340)
                speed = random.uniform(1.0, 3.0)
                vx = math.cos(math.radians(angle)) * speed
                vy = math.sin(math.radians(angle)) * speed
                tear_particles.append([
                    PLAYER.centerx, PLAYER.top,
                    vx, vy,
                    255,
                    random.randint(2, 4)
                ])
            continue  # 충돌한 눈물 제거
        else:
            new_tears.append(tear)
    falling_tears = new_tears
def apply_effect(effect_name):
    global PADDLE_WIDTH, PLAYER_SPEED, special_gauge, special_gauge_max, special_ready, aipill_active  # 🆕 AI 필 변수 추가
    # 🏆 아이템 사용 기록 (효과적인 사용인지 간단히 판단)
    was_effective = True  # 대부분의 아이템은 효과적으로 간주
    if effect_name == "gauge_boost" and special_gauge >= 70:
        was_effective = False  # 게이지가 이미 충분할 때는 비효과적
    elif effect_name == "gauge_charge" and special_gauge >= (special_gauge_max - 50):
        was_effective = False  # 게이지가 거의 풀일 때는 비효과적
    record_item_usage(effect_name, was_effective=was_effective)
    # 🆕 엑티브 아이템 사용 효과음 재생 (패시브 아이템 제외)
    if effect_name not in ["battery", "chargebag", "spikeboots", "dashgear"]:
        SOUND_ACTIVE_ITEM.play()
    if effect_name == "long_paddle":
        PADDLE_WIDTH = int(PADDLE_WIDTH * 1.5)
        print("롱 패들 활성화! 패들 크기가 1.5배 증가!")
    elif effect_name == "speed_up":
        PLAYER_SPEED *= 1.3
        print("스피드 업! 이동 속도가 30% 증가!")
    elif effect_name == "gauge_boost":
        special_gauge = min(100, special_gauge + 30)
        print("게이지 부스트! 특수 게이지가 30 증가!")
    elif effect_name == "long_boost":
        activate_long_boost()
        print("롱 부스트 활성화! 5초간 패들 크기 1.5배!")
    elif effect_name == "gauge_charge":  # 🆕 게이지 충전 아이템
        # 🔧 동적 최대치 계산 적용
        current_max = get_max_gauge()
        special_gauge = min(current_max, special_gauge + 220)
        # 🔹 게이지가 400 이상이면 special_ready 활성화
        if special_gauge >= 350:  # 파워스매시 발동 조건
            special_ready = True
        print("게이지 충전! 특수 게이지가 220 증가!")
    elif effect_name == "aipill":  # 🆕 AI 필 아이템 활성화
        aipill_active = True
        print("Aipill 활성화 - 현재 게이지:", special_gauge)
        print("Aipill 활성화 완료!")
    elif effect_name == "battery":  # 🆕 배터리 아이템 (패시브 아이템이므로 apply_effect에서 처리하지 않음)
        # 배터리는 store_passive_item에서 처리됨
        pass
    elif effect_name == "wall":  # 🆕 벽돌 설치 아이템 활성화
        activate_wall()
    elif effect_name == "molotov":  # 🔥 화염병 아이템 활성화
        activate_molotov()
        print("화염병 투척! 상대 패들 뒤쪽으로 날아갑니다!")
    elif effect_name == "grenade":  # 💣 수류탄 아이템 활성화
        activate_grenade()
        print("수류탄 투척! 보스를 밀어내고 공속을 증가시킵니다!")
    elif effect_name == "flare":  # 💡 조명탄 아이템 활성화
        activate_flare()
        print("조명탄 투척! 상대 진영에 도착 후 1.5초 뒤 폭발!")
    elif effect_name == "smoke_grenade":  # 💨 연막탄 아이템 활성화
        activate_smoke_grenade()
        print("연막탄 투척! 플레이어 진영에 연막 생성!")
    elif effect_name == "predictor":  # 🎯 레이저스코프 아이템 활성화
        activate_predictor()
        print("레이저스코프 활성화! 10초간 공의 궤적을 예측합니다!")
    elif effect_name == "life_elixir":  # 🌈 생명수 아이템 활성화
        # 게이지를 500 충전
        current_max = get_max_gauge()
        special_gauge = min(current_max, special_gauge + 500)
        # 게이지가 400 이상이면 special_ready 활성화
        if special_gauge >= 350:  # 파워스매시 발동 조건
            special_ready = True
        print("🌈 생명수 사용! 특수 게이지가 500 충전되었습니다!")
        # 무지개 이펙트 (선택사항)
        for _ in range(20):
            particle_x = PLAYER.centerx + random.randint(-30, 30)
            particle_y = PLAYER.centery + random.randint(-30, 30)
            rainbow_color = random.choice([
                (255, 0, 0), (255, 127, 0), (255, 255, 0),
                (0, 255, 0), (0, 127, 255), (0, 0, 255), (127, 0, 255)
            ])
            # 파티클 효과는 나중에 추가 가능
    elif effect_name == "chargebag":  # 🆕 충전가방 아이템 (패시브 아이템이므로 apply_effect에서 처리하지 않음)
        # 충전가방은 store_passive_item에서 처리됨
        pass
    elif effect_name == "spikeboots":  # 🆕 스파이크부츠 아이템 (패시브 아이템이므로 apply_effect에서 처리하지 않음)
        # 스파이크부츠는 store_passive_item에서 처리됨
        pass
    elif effect_name == "dashgear":  # 🆕 대쉬기어 아이템 (패시브 아이템이므로 apply_effect에서 처리하지 않음)
        # 대쉬기어는 store_passive_item에서 처리됨
        pass
# === 벌크업 발동 함수 ===
def activate_long_boost():
    global long_boost_active, long_boost_timer, long_boost_target_scale, LONG_BOOST_DURATION
    if not long_boost_active:
        long_boost_active = True
        long_boost_timer = LONG_BOOST_DURATION  # 6초 지속
        long_boost_target_scale = 1.5  # 목표 크기: 1.5배
        # 🆕 엑티브 아이템 사용 효과음 재생
        SOUND_ACTIVE_ITEM.play()
        print("🍄 거대화포션 발동! 6초간 패들 크기 1.5배 증가")
def activate_flare():
    """조명탄 투척 함수 - 0.5초 투척 모션 후 발사"""
    global flare_throwing, flare_throw_timer, flare_target_x, flare_target_y
    # 투척 모션 시작
    flare_throwing = True
    flare_throw_timer = 30  # 0.5초 (60fps * 0.5)
    # 목표 지점 미리 계산 (투척 모션 중에 사용)
    flare_target_x = BOSS.centerx + random.uniform(-50, 50)  # 보스 중심 근처 랜덤
    flare_target_y = BOSS.bottom + 40  # 보스 패들 아래쪽에서 40픽셀 떨어진 곳 (조금 더 멀리)
def activate_smoke_grenade():
    """연막탄 투척 함수 - 즉시 발동"""
    global smoke_grenade_target_x, smoke_grenade_target_y
    # 목표 지점 계산 (플레이어 데드라인 바로 위)
    smoke_grenade_target_x = PLAYER.centerx + random.uniform(-80, 80)  # 플레이어 중심 근처  
    smoke_grenade_target_y = PLAYER.top - 50  # 플레이어 패들 위 50픽셀
    # 즉시 투척
    throw_smoke_grenade()
    # 효과음 재생
    SOUND_ACTIVE_ITEM.play()
    print(f"💨 연막탄 즉시 발사!")
def activate_grenade():
    """수류탄 투척 함수 - 0.5초 투척 모션 후 발사"""
    global grenade_throwing, grenade_throw_timer, grenade_target_x, grenade_target_y, grenade_shake_timer
    # 화면 흔들림 타이머 초기화
    grenade_shake_timer = 0
    # 투척 모션 시작
    grenade_throwing = True
    grenade_throw_timer = 30  # 0.5초 (60fps * 0.5)
    # 목표 지점 미리 계산 (투척 모션 중에 사용)
    grenade_target_x = BOSS.centerx + random.uniform(-30, 30)  # 보스 중심 근처 랜덤
    grenade_target_y = BOSS.centery  # 보스 패들 중앙
    # 효과음 재생 (투척 시작)
    SOUND_ACTIVE_ITEM.play()
    print(f"💣 수류탄 투척 준비! 0.5초 후 발사됩니다.")
def throw_grenade():
    """실제 수류탄 투척 (모션 후 실행)"""
    global grenades, PLAYER, grenade_target_x, grenade_target_y
    # 투척 방향 계산
    dx = grenade_target_x - PLAYER.centerx
    dy = grenade_target_y - PLAYER.centery
    distance = math.sqrt(dx**2 + dy**2)
    # 속도 정규화 (일정한 속도로 날아가도록)
    speed = 12  # 수류탄 속도 (10 → 12, 20% 상향)
    vel_x = (dx / distance) * speed if distance > 0 else 0
    vel_y = (dy / distance) * speed if distance > 0 else -speed
    grenade = {
        "x": PLAYER.centerx,
        "y": PLAYER.centery,
        "vel_x": vel_x,
        "vel_y": vel_y,
        "target_x": grenade_target_x,
        "target_y": grenade_target_y,
        "gravity": 0,  # 중력 제거 - 직선으로 날아감
        "rotation": 0  # 회전 각도
    }
    grenades.append(grenade)
    print(f"💣 수류탄 발사! 목표 지점: X={grenade_target_x:.1f}, Y={grenade_target_y:.1f}")
def throw_smoke_grenade():
    """실제 연막탄 투척 (모션 후 실행) - 포물선 궤적"""
    global smoke_grenades, PLAYER, smoke_grenade_target_x, smoke_grenade_target_y
    # 포물선 궤적을 위한 초기 속도 계산
    dx = smoke_grenade_target_x - PLAYER.centerx
    dy = smoke_grenade_target_y - PLAYER.centery
    # 수평 속도 (목표까지 일정 시간 내에 도달)
    flight_time = 42  # 약 0.7초 비행시간 (50 → 42, 20% 빠르게) 
    vel_x = dx / flight_time
    # 수직 속도 (높이 올라갔다가 떨어지는 포물선)
    # 더 높이 올라가도록 초기 수직 속도 증가
    gravity = 0.8  # 중력 증가
    vel_y = -18  # 위로 강하게 던지기 (음수가 위쪽) (-15 → -18, 20% 상향)
    smoke_grenade = {
        "x": PLAYER.centerx,
        "y": PLAYER.centery,
        "vel_x": vel_x,
        "vel_y": vel_y,
        "gravity": gravity,
        "target_x": smoke_grenade_target_x,
        "target_y": smoke_grenade_target_y,
        "timer": 0,  # 도착 후 타이머
        "arrived": False,
        "rotation": 0,
        "trail": []  # 궤적 표시용
    }
    smoke_grenades.append(smoke_grenade)
    print(f"💨 연막탄 발사! 목표: X={smoke_grenade_target_x:.0f}, Y={smoke_grenade_target_y:.0f}")
def throw_flare():
    """실제 조명탄 투척 (모션 후 실행)"""
    global flares, PLAYER, flare_target_x, flare_target_y
    # 투척 방향 계산
    dx = flare_target_x - PLAYER.centerx
    dy = flare_target_y - PLAYER.centery
    distance = math.sqrt(dx**2 + dy**2)
    # 속도 정규화 (일정한 속도로 날아가도록)
    speed = 9.6  # 조명탄 속도 (8 → 9.6, 20% 상향)
    vel_x = (dx / distance) * speed if distance > 0 else 0
    vel_y = (dy / distance) * speed if distance > 0 else -speed
    flare = {
        "x": PLAYER.centerx,
        "y": PLAYER.centery,
        "vel_x": vel_x,
        "vel_y": vel_y,
        "target_x": flare_target_x,
        "target_y": flare_target_y,
        "gravity": 0,  # 중력 제거 - 직선으로 날아감
        "rotation": 0,  # 회전 각도
        "timer": 0,  # 도착 후 타이머
        "exploded": False,
        "arrived": False  # 도착 여부 플래그 추가
    }
    flares.append(flare)
    print(f"💡 조명탄 발사! 목표 지점: X={flare_target_x:.1f}, Y={flare_target_y:.1f}")
def activate_predictor():
    """레이저스코프 활성화 함수 - 10초간 공의 궤적 예측"""
    global predictor_active, predictor_timer
    predictor_active = True
    predictor_timer = 600  # 10초 지속 (60fps * 10초 = 600)
    # 효과음 재생
    try:
        SOUND_ACTIVE_ITEM.play()
    except:
        pass
    print("🎯 레이저스코프 활성화! 공의 궤적이 표시됩니다!")
def calculate_trajectory():
    """공이 보스 패들에서 출발할 때 한 번만 궤적을 계산하는 함수"""
    global ball_vel, BALL, WIDTH, HEIGHT, predicted_trajectory, last_prediction_ball_y
    # 공이 보스 패들 근처에서 아래로 향하기 시작할 때만 계산
    if BALL.centery < 100 and ball_vel[1] > 0 and BALL.centery != last_prediction_ball_y:
        last_prediction_ball_y = BALL.centery
        # 시뮬레이션용 변수
        sim_x = BALL.centerx
        sim_y = BALL.centery
        sim_vel_x = ball_vel[0]
        sim_vel_y = ball_vel[1]
        # 새로운 궤적 계산
        predicted_trajectory = []
        # 최대 500프레임 예측 (충분한 시간)
        max_steps = 500
        for step in range(max_steps):
            # 현재 위치 저장 (매 3프레임마다 더 세밀하게)
            if step % 3 == 0:
                predicted_trajectory.append((int(sim_x), int(sim_y)))
            # 다음 위치 계산
            sim_x += sim_vel_x
            sim_y += sim_vel_y
            # 벽 충돌 체크
            if sim_x <= BALL.width // 2 or sim_x >= WIDTH - BALL.width // 2:
                sim_vel_x = -sim_vel_x
                sim_x = max(BALL.width // 2, min(WIDTH - BALL.width // 2, sim_x))
            # 플레이어 패들 높이에 도달하면 중단
            if sim_y >= HEIGHT - 40:
                predicted_trajectory.append((int(sim_x), int(sim_y)))  # 최종 위치 추가
                break
            # 화면 밖으로 나가면 중단
            if sim_y > HEIGHT + 50:
                break
def draw_predicted_trajectory():
    """레이저스코프 활성화 시 저장된 궤적을 그리는 함수"""
    global predicted_trajectory, predictor_active, ball_vel
    if not predictor_active:
        return
    # 공이 위로 향하고 있으면 궤적 지우기 (플레이어가 친 경우)
    if ball_vel[1] <= 0:
        predicted_trajectory = []
        return
    # 궤적 계산 (보스가 방금 친 경우)
    calculate_trajectory()
    # 저장된 궤적 그리기
    if len(predicted_trajectory) > 1:
        # 전체 궤적을 하나의 Surface에 그리기
        trajectory_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        # 애니메이션을 위한 오프셋 (천천히 움직이는 효과)
        time_offset = pygame.time.get_ticks() * 0.001  # 천천히 움직이도록
        for i in range(len(predicted_trajectory) - 1):
            start_pos = predicted_trajectory[i]
            end_pos = predicted_trajectory[i + 1]
            # 선분 길이 계산
            segment_length = ((end_pos[0] - start_pos[0])**2 + (end_pos[1] - start_pos[1])**2)**0.5
            # 점선 그리기 (움직이는 효과)
            dash_length = 15  # 각 대시 길이
            gap_length = 10   # 간격 길이
            total_pattern = dash_length + gap_length
            # 선분을 따라 점선 그리기
            if segment_length > 0:
                num_dashes = int(segment_length / total_pattern) + 2
                for dash in range(num_dashes):
                    # 애니메이션 오프셋 적용
                    dash_start = (dash * total_pattern + time_offset * 30) % segment_length
                    dash_end = min(dash_start + dash_length, segment_length)
                    if dash_start < segment_length:
                        # 대시의 시작과 끝 위치 계산
                        t_start = dash_start / segment_length
                        t_end = dash_end / segment_length
                        dash_start_x = start_pos[0] + (end_pos[0] - start_pos[0]) * t_start
                        dash_start_y = start_pos[1] + (end_pos[1] - start_pos[1]) * t_start
                        dash_end_x = start_pos[0] + (end_pos[0] - start_pos[0]) * t_end
                        dash_end_y = start_pos[1] + (end_pos[1] - start_pos[1]) * t_end
                        # 빨간색 점선
                        pygame.draw.line(trajectory_surface, (255, 0, 0, 200), 
                                       (dash_start_x, dash_start_y), 
                                       (dash_end_x, dash_end_y), 5)
                        # 밝은 중심선 효과
                        pygame.draw.line(trajectory_surface, (255, 100, 100, 150), 
                                       (dash_start_x, dash_start_y), 
                                       (dash_end_x, dash_end_y), 3)
            # 궤적 포인트 표시 (일정 간격으로)
            if i % 4 == 0:
                # 빨간색 발광 효과
                pygame.draw.circle(trajectory_surface, (255, 150, 150, 100), start_pos, 6)
                pygame.draw.circle(trajectory_surface, (255, 50, 50, 200), start_pos, 4)
        # 궤적 Surface를 화면에 블릿
        SCREEN.blit(trajectory_surface, (0, 0))
    # 최종 도착 예상 지점에 타겟 마커 그리기
    if predicted_trajectory:
        final_point = predicted_trajectory[-1]
        # 타겟 십자선 그리기 - 크고 명확하게
        marker_surface = pygame.Surface((80, 80), pygame.SRCALPHA)
        # 외부 원
        pygame.draw.circle(marker_surface, (255, 0, 0, 200), (40, 40), 30, 3)
        # 십자선
        pygame.draw.line(marker_surface, (255, 0, 0, 255), (40, 10), (40, 70), 3)
        pygame.draw.line(marker_surface, (255, 0, 0, 255), (10, 40), (70, 40), 3)
        # 내부 점
        pygame.draw.circle(marker_surface, (255, 50, 50, 255), (40, 40), 5)
        # 빛나는 효과
        for radius in range(10, 35, 5):
            alpha = 50 - radius
            pygame.draw.circle(marker_surface, (255, 100, 100, alpha), (40, 40), radius, 1)
        SCREEN.blit(marker_surface, (final_point[0] - 40, final_point[1] - 40))
def activate_molotov():
    """화염병 투척 함수 - 0.5초 투척 모션 후 발사"""
    global molotov_throwing, molotov_throw_timer, molotov_target_x, molotov_target_y
    # 투척 모션 시작
    molotov_throwing = True
    molotov_throw_timer = 30  # 0.5초 (60fps * 0.5)
    # 목표 지점 미리 계산 (투척 모션 중에 사용)
    molotov_target_x = BOSS.centerx + random.uniform(-50, 50)  # 보스 중심 근처 랜덤
    molotov_target_y = BOSS.bottom - 50  # 보스 패들 뒤쪽
    # 효과음 재생 (투척 시작)
    SOUND_ACTIVE_ITEM.play()
    print(f"화염병 투척 준비! 0.5초 후 발사됩니다.")
def throw_molotov():
    """실제 화염병 투척 (모션 후 실행)"""
    global molotovs, PLAYER, molotov_target_x, molotov_target_y
    # 방향 벡터 계산
    dx = molotov_target_x - PLAYER.centerx
    dy = molotov_target_y - PLAYER.centery
    distance = math.sqrt(dx**2 + dy**2)
    # 속도 정규화 (일정한 속도로 날아가도록)
    speed = 14.4  # 화염병 속도 (12 → 14.4, 20% 상향)
    vel_x = (dx / distance) * speed if distance > 0 else 0
    vel_y = (dy / distance) * speed if distance > 0 else -speed
    molotov = {
        "x": PLAYER.centerx,
        "y": PLAYER.centery,
        "vel_x": vel_x,  # 목표를 향한 X 속도
        "vel_y": vel_y,  # 목표를 향한 Y 속도
        "gravity": 0,  # 중력 제거
        "target_y": molotov_target_y,  # 보스 패들 뒤쪽 목표 지점
        "exploded": False,
        "rotation": 0  # 회전 각도 추가
    }
    molotovs.append(molotov)
    print(f"화염병 발사! 목표 지점: X={molotov_target_x:.1f}, Y={molotov_target_y:.1f}")
def activate_wall():
    """벽돌 설치 함수"""
    global walls, wall_installing, wall_install_timer, wall_install_gauge_visible, master_obtained
    if not wall_installing:
        wall_installing = True
        # 🆕 엑티브 아이템 사용 효과음 재생
        SOUND_ACTIVE_ITEM.play()
        # 장인 아이템이 있으면 쿨타임과 벽돌 크기 조정
        if master_obtained:
            wall_install_timer = 48  # 0.8초 (48프레임)
            wall_width = int(80 * 1.3)  # 1.3배 길이 (30% 증가)
            print(f"장인 아이템 효과! 벽돌 길이 1.3배, 쿨타임 0.8초 (총 {len(walls)}개)")
        else:
            wall_install_timer = 30  # 0.5초 (30프레임)
            wall_width = 80  # 기본 길이
            print(f"벽돌 설치 시작! 0.5초 동안 움직일 수 없습니다. (총 {len(walls)}개)")
        wall_install_gauge_visible = True  # 설치 게이지 표시 시작
        # 벽돌 위치 설정 (플레이어 패들 하단, 가로 2cm 정도)
        wall_height = 20  # 높이를 20픽셀로 복원
        wall_x = PLAYER.centerx - wall_width // 2
        wall_y = PLAYER.bottom + 10  # 패들 아래 10픽셀로 복원
        wall_rect = pygame.Rect(wall_x, wall_y, wall_width, wall_height)
        # 새로운 벽돌 추가
        new_wall = {
            "rect": wall_rect,
            "hit_count": 0,
            "crack_level": 0
        }
        walls.append(new_wall)
# === Stage 4 명상타임 관련 전역 변수 ===
meditation_active = False
meditation_timer = 0
meditation_angle = 0
meditation_orbit_radius = 80  # 공이 보스 주변을 도는 반경
meditation_duration = 140     # 3초 (60fps 기준)
# 🔹 추가: 명상타임 공 잔상
meditation_trails = []  # [(x, y, alpha)]
def activate_meditation():
    global meditation_active, meditation_timer, meditation_angle, ball_vel
    meditation_active = True
    meditation_timer = meditation_duration
    meditation_angle = 0
    ball_vel = [0, 0]  # 공 멈춤
    show_speech("위빠사나명상...", duration=90)
    # 🔊 명상 사운드
    try:
        meditation_sound = pygame.mixer.Sound("sounds/meditation.wav")
        meditation_sound.play()
    except:
        pass
def handle_meditation():
    global meditation_active, meditation_timer, meditation_angle, BALL, ball_vel
    if not meditation_active:
        return
    meditation_timer -= 1
    meditation_angle += 3  # 공전 속도
    # 공이 보스 주변을 공전
    BALL.centerx = int(BOSS.centerx + math.cos(math.radians(meditation_angle)) * meditation_orbit_radius)
    BALL.centery = int(BOSS.centery + math.sin(math.radians(meditation_angle)) * meditation_orbit_radius)
    # 종료 처리
    if meditation_timer <= 0:
        meditation_active = False
        # 랜덤 각도로 공 발사
        angle_deg = random.randint(-60, 60)
        speed = BALL_BASE_SPEED
        rad = math.radians(angle_deg)
        ball_vel = [speed * math.sin(rad), speed * math.cos(rad)]
def activate_quake():
    global quake_active, quake_timer, PLAYER_SPEED, original_ball_speed_quake
    quake_active = True
    quake_timer = quake_duration
    PLAYER_SPEED = 1
    # 💾 현재 공 속도 백업
    original_ball_speed_quake = ball_vel.copy()
    # 정글지진 효과음 재생
    try:
        SOUND_QUAKE.play(loops=-1)  # 무한루프로 재생
    except:
        pass  # 사운드 오류 발생 시 무시하고 계속 진행
    show_speech("정글지진!", duration=90)
# stop_quake_sound 함수는 인라인화됨 - 직접 SOUND_QUAKE.stop() 호출
def handle_quake():
    global quake_active, quake_timer, PLAYER_SPEED, ball_vel
    if quake_active:
        if quake_timer > 0:
            quake_timer -= 1
            # 원래 흔들림 효과 (매 프레임 적용)
            shake_x = random.uniform(-3, 3)
            shake_y = random.uniform(-2, 2)
            ball_vel[0] += shake_x
            ball_vel[1] += shake_y
            # 원래 플레이어 영향 계산
            dx = PLAYER.centerx - BALL.centerx
            dy = PLAYER.centery - BALL.centery
            distance = math.sqrt(dx*dx + dy*dy)
            if distance > 10:
                influence = 0.15 / distance
                ball_vel[0] += dx * influence * 0.01
                ball_vel[1] += dy * influence * 0.01
            # 속도 제한
            max_speed = 8
            ball_vel[0] = max(-max_speed, min(max_speed, ball_vel[0]))
            ball_vel[1] = max(-max_speed, min(max_speed, ball_vel[1]))
        else:
            # ✅ 효과 종료 시 상태 복원
            quake_active = False
            PLAYER_SPEED = 1
            # 💫 원래 속도로 복원
            ball_vel[0] = original_ball_speed_quake[0]
            ball_vel[1] = original_ball_speed_quake[1]
            # 💥 추가: 만약 복원한 속도가 너무 느리면 기본 속도로 보정
            speed = math.hypot(ball_vel[0], ball_vel[1])
            if speed < BALL_BASE_SPEED * 0.85:
                direction = pygame.math.Vector2(ball_vel).normalize()
                ball_vel[0] = direction.x * BALL_BASE_SPEED
                ball_vel[1] = direction.y * BALL_BASE_SPEED
            # 퀘이크 효과음 종료
            SOUND_QUAKE.stop()  # 직접 호출로 인라인화
def draw_shaking_screen():
    """정글지진 시 화면 흔들림 효과 (더 효율적인 방식)"""
    global screen_shake_offset_x, screen_shake_offset_y, grenade_shake_timer
    if quake_active:
        # 화면 흔들림 오프셋 계산
        screen_shake_offset_x = random.randint(-3, 3)
        screen_shake_offset_y = random.randint(-2, 2)
    elif grenade_shake_timer > 0:
        # 💣 수류탄 폭발 화면 흔들림
        intensity = grenade_shake_timer / 40.0  # 40으로 나누어 강도 계산
        screen_shake_offset_x = random.randint(-int(12 * intensity), int(12 * intensity))
        screen_shake_offset_y = random.randint(-int(10 * intensity), int(10 * intensity))
        grenade_shake_timer -= 1
        print(f"🔨 화면 흔들림: timer={grenade_shake_timer}, offset=({screen_shake_offset_x}, {screen_shake_offset_y})")
    else:
        screen_shake_offset_x = 0
        screen_shake_offset_y = 0
def show_speech(text, duration=60):
    global speech_timer, speech_text
    speech_timer = duration
    speech_text = text
def draw_speech():
    global speech_timer, speech_text
    if speech_timer > 0:
        # 만화 스타일 말풍선 그리기
        font = pygame.font.Font("NanumSquareR.ttf", 26)
        text_surface = font.render(speech_text, True, BLACK)
        # 말풍선 크기 계산 (패딩 포함)
        padding = 20
        bubble_width = text_surface.get_width() + padding * 2
        bubble_height = text_surface.get_height() + padding * 1.5
        # 말풍선 위치 (보스 아래쪽에 - 화면 안에 보이도록)
        bubble_x = BOSS.centerx - bubble_width // 2
        bubble_y = BOSS.bottom + 20  # 보스 아래에 위치
        # 말풍선 표면 생성 (투명도 지원)
        bubble_surface = pygame.Surface((bubble_width + 10, bubble_height + 20), pygame.SRCALPHA)
        # 1. 그림자 효과
        shadow_offset = 4
        shadow_rect = pygame.Rect(shadow_offset, shadow_offset, bubble_width, bubble_height)
        pygame.draw.rect(bubble_surface, (0, 0, 0, 80), shadow_rect, border_radius=15)
        # 2. 메인 말풍선 (둥근 모서리)
        main_rect = pygame.Rect(0, 0, bubble_width, bubble_height)
        pygame.draw.rect(bubble_surface, WHITE, main_rect, border_radius=15)
        # 3. 만화 스타일 테두리 (두껍고 검은색)
        border_width = 3
        pygame.draw.rect(bubble_surface, BLACK, main_rect, border_width, border_radius=15)
        # 4. 말풍선 꼬리 (위쪽 보스를 향해)
        tail_points = [
            (bubble_width // 2 - 20, 2),              # 왼쪽 점
            (bubble_width // 2, 2),                    # 중간 점  
            (bubble_width // 2 - 30, -15)             # 위 대각선 끝점 (보스 방향)
        ]
        # 꼬리 그림자
        shadow_tail = [(p[0] + shadow_offset, p[1] + shadow_offset) for p in tail_points]
        pygame.draw.polygon(bubble_surface, (0, 0, 0, 80), shadow_tail)
        # 꼬리 메인
        pygame.draw.polygon(bubble_surface, WHITE, tail_points)
        # 꼬리 테두리
        pygame.draw.polygon(bubble_surface, BLACK, tail_points, border_width)
        # 5. 내부 하이라이트 효과 (만화 느낌)
        highlight_rect = pygame.Rect(10, 5, bubble_width - 20, 8)
        highlight_surface = pygame.Surface((highlight_rect.width, highlight_rect.height), pygame.SRCALPHA)
        pygame.draw.rect(highlight_surface, (255, 255, 255, 100), highlight_surface.get_rect(), border_radius=4)
        bubble_surface.blit(highlight_surface, highlight_rect)
        # 6. 작은 반짝임 효과 (만화 스타일)
        if speech_timer % 30 < 15:  # 깜빡임 효과
            sparkle_size = 8
            sparkle_x = bubble_width - 25
            sparkle_y = 10
            # 십자 반짝임
            pygame.draw.line(bubble_surface, (255, 255, 200), 
                           (sparkle_x - sparkle_size, sparkle_y), 
                           (sparkle_x + sparkle_size, sparkle_y), 2)
            pygame.draw.line(bubble_surface, (255, 255, 200), 
                           (sparkle_x, sparkle_y - sparkle_size), 
                           (sparkle_x, sparkle_y + sparkle_size), 2)
            # 대각선 반짝임
            pygame.draw.line(bubble_surface, (255, 255, 150), 
                           (sparkle_x - sparkle_size//2, sparkle_y - sparkle_size//2), 
                           (sparkle_x + sparkle_size//2, sparkle_y + sparkle_size//2), 1)
            pygame.draw.line(bubble_surface, (255, 255, 150), 
                           (sparkle_x - sparkle_size//2, sparkle_y + sparkle_size//2), 
                           (sparkle_x + sparkle_size//2, sparkle_y - sparkle_size//2), 1)
        # 7. 텍스트 그리기 (약간의 그림자 효과)
        # 텍스트 그림자
        text_shadow = font.render(speech_text, True, (50, 50, 50))
        bubble_surface.blit(text_shadow, (padding + 1, padding - 2))
        # 메인 텍스트
        bubble_surface.blit(text_surface, (padding, padding - 3))
        # 8. 애니메이션 효과 (살짝 위아래로 움직임)
        float_offset = math.sin(speech_timer * 0.1) * 2
        # 화면에 최종 그리기
        SCREEN.blit(bubble_surface, (bubble_x - 5, bubble_y + float_offset))
        # ✅ 타이머 감소
        speech_timer -= 1
    else:
        # ✅ 시간이 끝나면 말풍선 제거
        speech_text = ""
# === 대쉬 스피릿 레이저 시스템 함수들 ===
def create_dash_spirit_laser(player_x, player_y, direction, dash_distance):
    """대쉬 스피릿 레이저 생성 - 플레이어 패들 뒷부분에서 시작"""
    global dash_spirit_lasers
    # 🎯 플레이어 패들의 뒷부분에서 시작점 계산
    paddle_half_width = PADDLE_WIDTH // 2
    if direction == -1:  # 왼쪽 대쉬
        # 패들의 오른쪽 끝에서 시작해서 왼쪽으로 레이저 생성
        start_x = player_x + paddle_half_width
        end_x = start_x - dash_distance
    else:  # 오른쪽 대쉬  
        # 패들의 왼쪽 끝에서 시작해서 오른쪽으로 레이저 생성
        start_x = player_x - paddle_half_width
        end_x = start_x + dash_distance
    start_y = player_y
    end_y = player_y
    # 🎯 화면 경계 제한 제거 - 실제 50% 거리 유지
    # end_x = max(0, min(WIDTH, end_x))  # 이 제한이 레이저를 짧게 만듦
    # 레이저 추가 (전기 효과 추가)
    laser = {
        'start_x': start_x,
        'start_y': start_y,
        'end_x': end_x,
        'end_y': end_y,
        'remaining_time': DASH_SPIRIT_LASER_DURATION,
        'direction': direction,
        'alpha': 255,
        'electric_timer': 0,  # 전기 효과 타이머
        'electric_segments': [],  # 전기 효과 세그먼트들
        'invincible_time': 10  # 🛡️ 생성 후 10프레임(약 0.17초) 동안 충돌 무시
    }
    # 전기 효과 세그먼트 생성 (레이저 길이를 10개 구간으로 나누기)
    num_segments = 10
    for i in range(num_segments + 1):
        t = i / num_segments
        seg_x = start_x + t * (end_x - start_x)
        seg_y = start_y + t * (end_y - start_y)
        laser['electric_segments'].append([seg_x, seg_y, random.uniform(-3, 3), random.uniform(-3, 3)])
    dash_spirit_lasers.append(laser)
    print(f"🌟 대쉬 스피릿 레이저 생성! 위치: ({start_x}, {start_y}) → ({end_x}, {end_y})")
def update_dash_spirit_lasers():
    """대쉬 스피릿 레이저 업데이트"""
    global dash_spirit_lasers
    # 시간 감소 및 페이드 아웃 효과
    for laser in dash_spirit_lasers[:]:
        laser['remaining_time'] -= 1
        laser['electric_timer'] += 1
        # 🛡️ 무적 시간 감소
        if 'invincible_time' in laser and laser['invincible_time'] > 0:
            laser['invincible_time'] -= 1
        # 알파값 계산 (페이드 아웃)
        laser['alpha'] = int(255 * (laser['remaining_time'] / DASH_SPIRIT_LASER_DURATION))
        # 🌩️ 전기 효과 업데이트 (매 3프레임마다 변화)
        if laser['electric_timer'] % 3 == 0:
            for segment in laser['electric_segments']:
                # 원래 위치에서 작은 범위 내에서 흔들림
                original_x = segment[0]
                original_y = segment[1]
                # 새로운 무작위 오프셋 생성 (더 강한 전기 효과)
                segment[2] = random.uniform(-4, 4)  # X 오프셋
                segment[3] = random.uniform(-4, 4)  # Y 오프셋
        if laser['remaining_time'] <= 0:
            dash_spirit_lasers.remove(laser)
def check_laser_ball_collision():
    """레이저와 공의 충돌 검사"""
    global ball_vel, dash_spirit_lasers
    for laser in dash_spirit_lasers[:]:
        # 🛡️ 무적 시간 중에는 충돌 검사 생략
        if 'invincible_time' in laser and laser['invincible_time'] > 0:
            continue
        # 공과 레이저 선분의 거리 계산
        ball_x, ball_y = BALL.centerx, BALL.centery
        # 선분과 점의 최단거리 계산
        laser_start = (laser['start_x'], laser['start_y'])
        laser_end = (laser['end_x'], laser['end_y'])
        # 벡터 계산
        dx = laser_end[0] - laser_start[0]
        dy = laser_end[1] - laser_start[1]
        if dx == 0 and dy == 0:  # 점 레이저인 경우
            distance = ((ball_x - laser_start[0])**2 + (ball_y - laser_start[1])**2)**0.5
        else:
            # 선분 길이의 제곱
            length_sq = dx*dx + dy*dy
            # 공에서 선분의 시작점으로의 벡터
            px = ball_x - laser_start[0]
            py = ball_y - laser_start[1]
            # 투영 비율 계산
            t = max(0, min(1, (px*dx + py*dy) / length_sq))
            # 가장 가까운 점
            closest_x = laser_start[0] + t * dx
            closest_y = laser_start[1] + t * dy
            # 거리 계산
            distance = ((ball_x - closest_x)**2 + (ball_y - closest_y)**2)**0.5
        # 충돌 판정 (공 반지름 + 레이저 두께 고려)
        collision_threshold = BALL_RADIUS + DASH_SPIRIT_LASER_WIDTH // 2
        if distance <= collision_threshold:
            # 🛡️ 플레이어 방어용 레이저 반사 - 항상 위쪽(보스 방향)으로 반사
            print(f"🌟 레이저 충돌! 공 반사")
            # 🎯 방어 효과: 공을 항상 보스(위쪽) 방향으로 반사
            current_speed = (ball_vel[0]**2 + ball_vel[1]**2)**0.5
            # Y방향을 항상 위쪽으로 (음수)
            if ball_vel[1] > 0:  # 아래로 향하고 있다면
                ball_vel[1] = -abs(ball_vel[1])  # 위쪽으로 반사
            else:  # 이미 위로 향하고 있다면
                ball_vel[1] = ball_vel[1] * 1.2  # 더 빠르게 위로
            # X방향은 레이저 방향의 반대로 (플레이어 중앙 쪽으로)
            player_center_x = PLAYER.centerx
            if ball_x < player_center_x:  # 공이 플레이어 왼쪽에 있으면
                ball_vel[0] = abs(ball_vel[0]) * 0.8  # 오른쪽으로 (중앙 쪽)
            else:  # 공이 플레이어 오른쪽에 있으면
                ball_vel[0] = -abs(ball_vel[0]) * 0.8  # 왼쪽으로 (중앙 쪽)
            # 🔥 반사 후 속도 증가 (반격 효과)
            speed_boost = 1.3
            ball_vel[0] *= speed_boost
            ball_vel[1] *= speed_boost
            # 레이저 제거 (한 번만 반사)
            dash_spirit_lasers.remove(laser)
            break
# ball_angle을 전역 변수로 선언하고 초기값을 설정
ball_angle = 0  # 초기 각도
# 기본 이동 속도
PLAYER_BASE_SPEED = 2
MAX_SPEED = 7  # 최대 속도
ACCELERATION = 0.3  # 가속도
DECELERATION = 0.3  # 감속도
# 현재 이동 속도
current_speed = 0
# 기본 이동 속도
PLAYER_BASE_SPEED = 2
MAX_SPEED = 7  # 최대 속도
ACCELERATION = 0.4  # 가속도 (빠르게 반응하도록 값을 증가)
DECELERERATION = 0.2  # 감속도 (빠르게 반응하도록 값을 증가)
# 현재 이동 속도
current_speed = 0
# 기본 이동 속도
PLAYER_BASE_SPEED = 2
MAX_SPEED = 5  # 최대 속도 (기본 속도 추가 감소)
ACCELERATION = 0.4  # 가속도 (빠르게 반응하도록 값을 증가)
DECELERATION = 0.4  # 감속도 (빠르게 반응하도록 값을 증가)
INSTANT_STOP_DECELERATION = 1.0  # 즉시 정지시킬 때 더 빠른 감속
# 스피드부츠 관련 변수
speedboots_obtained = False  # 스피드부츠 획득 여부
PERMANENT_SPEED_BOOST = 0.15  # 영구 속도 증가량 (15% 증가)
# 🌊 관성 보존 시스템 변수
last_wall_collision_time = 0  # 마지막 벽 충돌 시간
# 스피드기어 관련 변수
speedgear_obtained = False  # 스피드기어 획득 여부
# 무중력벨트 관련 변수
gravitybelt_obtained = False  # 무중력벨트 획득 여부
DIRECTION_CHANGE_BOOST = 2.5  # 방향 전환 속도 증가량 (150% 더 빠름)
# 🆕 새로운 보스 배틀 모드 관련 변수
new_boss_mode_active = False  # 새로운 보스들만의 대결 모드
selected_top_boss = 1  # 상단 보스 선택 (1: 라이트닝 마스터, 2: 아이스 퀸)
selected_bottom_boss = 1  # 하단 보스 선택 (1: 파이어 나이트, 2: 윈드 스피릿)
# ⚡ 새로운 보스들 능력치
# 라이트닝 마스터 (Lightning Master) - 전기 속성
lightning_master_speed = 0.0
lightning_master_acceleration = 0.975  # 매우 빠른 가속 (35% 감소: 1.5 → 0.975)
lightning_master_max_speed = 11.7  # 최고 속도 (35% 감소: 18.0 → 11.7)
# 🧊 아이스 퀸 (Ice Queen) - 얼음 속성  
ice_queen_speed = 0.0
ice_queen_acceleration = 0.39  # 느린 가속 (35% 감소: 0.6 → 0.39)
ice_queen_max_speed = 5.2  # 느린 속도, 하지만 특수 능력 보유 (35% 감소: 8.0 → 5.2)
# 🔥 파이어 나이트 (Fire Knight) - 화염 속성
fire_knight_speed = 0.0
fire_knight_acceleration = 0.78  # 균형잡힌 가속 (35% 감소: 1.2 → 0.78)
fire_knight_max_speed = 9.75  # 균형잡힌 속도 (35% 감소: 15.0 → 9.75)
# 💨 윈드 스피릿 (Wind Spirit) - 바람 속성
wind_spirit_speed = 0.0
wind_spirit_acceleration = 1.3  # 매우 빠른 가속 (35% 감소: 2.0 → 1.3)
wind_spirit_max_speed = 13.0  # 최고 속도, 하지만 체력 약함 (35% 감소: 20.0 → 13.0)
# 🆕 새로운 보스 스킬들 관련 변수
# ⚡ 라이트닝 마스터 스킬: 전기 충격 (Lightning Strike)
lightning_strike_active = False
lightning_strike_timer = 0
lightning_strike_duration = 90  # 1.5초
lightning_strike_cooldown = 180  # 3초
lightning_strike_last_used = 0
# 🧊 아이스 퀸 스킬: 얼음 방벽 (Ice Barrier)  
ice_barrier_active = False
ice_barrier_timer = 0
ice_barrier_duration = 180  # 3초
ice_barrier_cooldown = 300  # 5초
ice_barrier_last_used = 0
# 🔥 파이어 나이트 스킬: 화염 돌진 (Fire Charge)
fire_charge_active = False
fire_charge_timer = 0
fire_charge_duration = 60  # 1초
fire_charge_cooldown = 240  # 4초
fire_charge_last_used = 0
# 💨 윈드 스피릿 스킬: 바람 폭발 (Wind Burst)
wind_burst_active = False
wind_burst_timer = 0
wind_burst_duration = 30  # 0.5초
wind_burst_cooldown = 150  # 2.5초
wind_burst_last_used = 0
# 물자국 관련 변수
water_trail_positions = []  # 물자국 위치 리스트
water_trail_timer = 0  # 물자국 생성 타이머
# AI 필 관련 변수
aipill_active = False  # AI 필 활성화 상태
aipill_speed_boost = 4.0  # AI 필 시 스피드 증가 배율
# 대쉬 관리자 초기화 (기존 변수들은 호환성을 위해 유지)
dash = None  # 대쉬 매니저 인스턴스 (나중에 초기화됨)
# 대쉬 관련 변수 (더블대쉬 제거 후 단순화) - 호환성을 위해 유지
rolling_active = False
rolling_timer = 0
rolling_direction = 0  # -1: 왼쪽, 1: 오른쪽
rolling_speed = 30
rolling_stun_timer = 0  # 구르기 후 통제 불가능 시간
rolling_dash_available_timer = 0  # 구르기 대쉬 가능 타이머
rolling_cooldown = 0  # 구르기 쿨타임
rolling_charges = 1  # 구르기 사용 가능 횟수 (기본값 1개)
token_states = [True]  # 각 토큰의 상태 (True=사용가능, False=소진) - 왼쪽부터 소진/충전
rolling_charge_timer = 0  # 구르기 충전 타이머
rolling_consecutive_count = 0  # 🆕 연속 대쉬 사용 횟수 (할인 계산용)
rolling_consecutive_timer = 0  # 🆕 연속 대쉬 타이머 (일정 시간 내에 사용해야 할인)
# 빠칭코 관련 변수
pachinko_active = False  # 빠칭코 활성화 상태
pachinko_phase = 0  # 0: 대기, 1: 슬롯 돌아감, 2: 슬로우다운, 3: 완료
pachinko_slot_positions = []  # 슬롯 위치들 (세로 스크롤용)
pachinko_scroll_speed = 8  # 슬롯 스크롤 속도 (세로)
pachinko_slowdown_timer = 0  # 슬로우다운 타이머
pachinko_final_item = None  # 최종 선택된 아이템
slot_final_result = None  # 슬롯 최종 결과
slot_slowdown_mode = False  # 슬롯 슬로우다운 모드
slot_stop_order = 0  # 슬롯 정지 순서
pachinko_machine_img = None  # 빠칭코 기계 이미지
# 아이템 획득 효과 변수들
item_obtained_effect = None  # {"icon": icon, "name": name, "timer": timer, "alpha": alpha, "type": type, "x": x, "y": y, "target_x": target_x, "target_y": target_y}
item_effect_duration = 120  # 2초 (60fps * 2)
# 풍선 터지는 효과 파티클
balloon_pop_particles = []
# 슬롯머신 변수들
slot_reels = [[], [], []]  # 3개의 릴
slot_positions = [0, 0, 0]  # 각 릴의 위치
slot_spinning = True  # 슬롯이 돌아가는지 여부
slot_stop_timer = 0  # 멈춤 타이머
slot_spin_speed = 15  # 슬롯 회전 속도
# 현재 이동 속도
current_speed = 0
# 🆕 새로운 보스들의 AI 함수들
def handle_lightning_master_as_top():
    """새로운 보스 모드에서 라이트닝 마스터(상단)의 AI 처리"""
    global lightning_master_speed, BOSS, is_player_serve, is_waiting_for_serve
    global boss_fake_move, boss_fake_start_time, boss_fake_during_player_serve
    global waiting_start_time, wait_delay, ball_vel
    if not new_boss_mode_active or selected_top_boss != 1:
        return
    # --- 서브 대기 상태 처리 ---
    if is_waiting_for_serve:
        time_now = pygame.time.get_ticks()
        # 보스 패들 간보기 움직임
        def fake_motion():
            style = random.randint(1, 4)
            if style == 1:
                return math.sin(time_now / 100) * 2.5
            elif style == 2 and random.random() < 0.02:
                return random.choice([-1, 1]) * random.randint(20, 30)
            elif style == 3:
                return math.sin(time_now / 300) * 4
            elif style == 4 and random.random() < 0.015:
                return random.choice([-1, 1]) * 10
            return 0
        # --- 보스 서브 차례 ---
        if not is_player_serve:
            if boss_fake_move and time_now - boss_fake_start_time < wait_delay:
                BOSS.centerx += fake_motion()
            if wait_delay > 0 and time_now - waiting_start_time >= wait_delay:
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                calculate_bounce(BOSS)
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
            if wait_delay == 0:
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                calculate_bounce(BOSS)
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
        # --- 플레이어 서브 차례 ---
        elif boss_fake_during_player_serve:
            BOSS.centerx += fake_motion()
        return  # 서브 중에는 아래 일반 이동 로직 실행 안 함
    # 공의 위치 예측
    predict_frame = 18  # 빠른 반응
    future_x = BALL.centerx + ball_vel[0] * predict_frame
    # 예측 오차 추가 (매우 정확)
    if random.random() < 0.05:  # 5% 확률로 실수
        future_x += random.randint(-20, 20)
    # 목표 위치 계산
    target_x = future_x - PADDLE_WIDTH // 2
    target_x = max(0, min(WIDTH - PADDLE_WIDTH, target_x))
    # 이동 로직
    distance = target_x - BOSS.x
    # 전기 충격 활성화 시 속도 증가
    current_acceleration = lightning_master_acceleration
    current_max_speed = lightning_master_max_speed
    if lightning_strike_active:
        current_acceleration *= 2.0  # 전기 충격 시 가속도 2배
        current_max_speed *= 1.5  # 최대 속도 1.5배
    if abs(distance) > 1:
        if distance > 0:
            lightning_master_speed = min(current_max_speed, lightning_master_speed + current_acceleration)
        else:
            lightning_master_speed = max(-current_max_speed, lightning_master_speed - current_acceleration)
    else:
        # 빠른 감속
        if lightning_master_speed > 0:
            lightning_master_speed = max(0, lightning_master_speed - current_acceleration * 1.5)
        else:
            lightning_master_speed = min(0, lightning_master_speed + current_acceleration * 1.5)
    # 위치 업데이트
    new_x = BOSS.x + lightning_master_speed
    new_x = max(0, min(WIDTH - PADDLE_WIDTH, new_x))
    BOSS.x = new_x
def handle_ice_queen_as_top():
    """새로운 보스 모드에서 아이스 퀸(상단)의 AI 처리"""
    global ice_queen_speed, BOSS, is_player_serve, is_waiting_for_serve
    global boss_fake_move, boss_fake_start_time, boss_fake_during_player_serve
    global waiting_start_time, wait_delay, ball_vel
    if not new_boss_mode_active or selected_top_boss != 2:
        return
    # --- 서브 대기 상태 처리 ---
    if is_waiting_for_serve:
        time_now = pygame.time.get_ticks()
        # 보스 패들 간보기 움직임
        def fake_motion():
            style = random.randint(1, 4)
            if style == 1:
                return math.sin(time_now / 100) * 2.5
            elif style == 2 and random.random() < 0.02:
                return random.choice([-1, 1]) * random.randint(20, 30)
            elif style == 3:
                return math.sin(time_now / 300) * 4
            elif style == 4 and random.random() < 0.015:
                return random.choice([-1, 1]) * 10
            return 0
        # --- 보스 서브 차례 ---
        if not is_player_serve:
            if boss_fake_move and time_now - boss_fake_start_time < wait_delay:
                BOSS.centerx += fake_motion()
            if wait_delay > 0 and time_now - waiting_start_time >= wait_delay:
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                calculate_bounce(BOSS)
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
            if wait_delay == 0:
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                calculate_bounce(BOSS)
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
        # --- 플레이어 서브 차례 ---
        elif boss_fake_during_player_serve:
            BOSS.centerx += fake_motion()
        return  # 서브 중에는 아래 일반 이동 로직 실행 안 함
    # 공의 위치 예측 (방어적)
    predict_frame = 30  # 느린 반응
    future_x = BALL.centerx + ball_vel[0] * predict_frame
    # 예측 오차 추가 (보통)
    if random.random() < 0.12:  # 12% 확률로 실수
        future_x += random.randint(-35, 35)
    # 목표 위치 계산
    target_x = future_x - PADDLE_WIDTH // 2
    target_x = max(0, min(WIDTH - PADDLE_WIDTH, target_x))
    # 이동 로직 (느리지만 안정적)
    distance = target_x - BOSS.x
    if abs(distance) > 2:
        if distance > 0:
            ice_queen_speed = min(ice_queen_max_speed, ice_queen_speed + ice_queen_acceleration)
        else:
            ice_queen_speed = max(-ice_queen_max_speed, ice_queen_speed - ice_queen_acceleration)
    else:
        # 안정적인 감속
        if ice_queen_speed > 0:
            ice_queen_speed = max(0, ice_queen_speed - ice_queen_acceleration * 0.8)
        else:
            ice_queen_speed = min(0, ice_queen_speed + ice_queen_acceleration * 0.8)
    # 위치 업데이트
    new_x = BOSS.x + ice_queen_speed
    new_x = max(0, min(WIDTH - PADDLE_WIDTH, new_x))
    BOSS.x = new_x
def handle_fire_knight_as_bottom():
    """새로운 보스 모드에서 파이어 나이트(하단)의 AI 처리"""
    global fire_knight_speed, PLAYER, ball_vel
    if not new_boss_mode_active or selected_bottom_boss != 1:
        return
    # 공의 위치 예측 (균형잡힌)
    predict_frame = 22  # 보통 반응
    future_x = BALL.centerx + ball_vel[0] * predict_frame
    # 예측 오차 추가
    if random.random() < 0.08:  # 8% 확률로 실수
        future_x += random.randint(-25, 25)
    # 목표 위치 계산
    target_x = future_x - PADDLE_WIDTH // 2
    target_x = max(0, min(WIDTH - PADDLE_WIDTH, target_x))
    # 이동 로직
    distance = target_x - PLAYER.x
    # 화염 돌진 활성화 시 속도 대폭 증가
    current_acceleration = fire_knight_acceleration
    current_max_speed = fire_knight_max_speed
    if fire_charge_active:
        current_acceleration *= 3.0  # 화염 돌진 시 가속도 3배
        current_max_speed *= 2.0  # 최대 속도 2배
    if abs(distance) > 1.5:
        if distance > 0:
            fire_knight_speed = min(current_max_speed, fire_knight_speed + current_acceleration)
        else:
            fire_knight_speed = max(-current_max_speed, fire_knight_speed - current_acceleration)
    else:
        # 감속
        decel_multiplier = 10.0 if fire_charge_active else 1.2  # 화염 돌진 시 급정지
        if fire_knight_speed > 0:
            fire_knight_speed = max(0, fire_knight_speed - current_acceleration * decel_multiplier)
        else:
            fire_knight_speed = min(0, fire_knight_speed + current_acceleration * decel_multiplier)
    # 위치 업데이트
    new_x = PLAYER.x + fire_knight_speed
    new_x = max(0, min(WIDTH - PADDLE_WIDTH, new_x))
    PLAYER.x = new_x
def handle_wind_spirit_as_bottom():
    """새로운 보스 모드에서 윈드 스피릿(하단)의 AI 처리"""
    global wind_spirit_speed, PLAYER, ball_vel
    if not new_boss_mode_active or selected_bottom_boss != 2:
        return
    # 공의 위치 예측 (매우 빠른 반응)
    predict_frame = 15  # 가장 빠른 반응
    future_x = BALL.centerx + ball_vel[0] * predict_frame
    # 예측 오차 추가 (매우 정확)
    if random.random() < 0.03:  # 3% 확률로 실수
        future_x += random.randint(-15, 15)
    # 목표 위치 계산
    target_x = future_x - PADDLE_WIDTH // 2
    target_x = max(0, min(WIDTH - PADDLE_WIDTH, target_x))
    # 이동 로직 (매우 빠름)
    distance = target_x - PLAYER.x
    if abs(distance) > 0.5:  # 매우 민감한 반응
        if distance > 0:
            wind_spirit_speed = min(wind_spirit_max_speed, wind_spirit_speed + wind_spirit_acceleration)
        else:
            wind_spirit_speed = max(-wind_spirit_max_speed, wind_spirit_speed - wind_spirit_acceleration)
    else:
        # 매우 빠른 감속
        if wind_spirit_speed > 0:
            wind_spirit_speed = max(0, wind_spirit_speed - wind_spirit_acceleration * 2.0)
        else:
            wind_spirit_speed = min(0, wind_spirit_speed + wind_spirit_acceleration * 2.0)
    # 위치 업데이트
    new_x = PLAYER.x + wind_spirit_speed
    new_x = max(0, min(WIDTH - PADDLE_WIDTH, new_x))
    PLAYER.x = new_x
# 🆕 새로운 보스들의 스킬 함수들
def handle_lightning_master_skills():
    """라이트닝 마스터의 스킬 처리"""
    global lightning_strike_active, lightning_strike_timer, lightning_strike_last_used
    print(f"🔍 라이트닝 마스터 스킬 함수 호출됨! new_boss_mode_active={new_boss_mode_active}, selected_top_boss={selected_top_boss}")
    if not new_boss_mode_active or selected_top_boss != 1:
        print(f"🔍 라이트닝 마스터 조건 불만족으로 리턴")
        return
    time_now = pygame.time.get_ticks()
    # 전기 충격 스킬 (50% 확률) - 테스트용으로 높임
    if not lightning_strike_active and (time_now - lightning_strike_last_used >= lightning_strike_cooldown * 16.67):  # 프레임을 ms로 변환
        if random.random() <= 0.50:
            lightning_strike_active = True
            lightning_strike_timer = lightning_strike_duration
            lightning_strike_last_used = time_now
            show_speech("번개 충격!", duration=lightning_strike_duration)
            print("⚡ 라이트닝 마스터가 전기 충격 사용!")
def handle_ice_queen_skills():
    """아이스 퀸의 스킬 처리"""
    global ice_barrier_active, ice_barrier_timer, ice_barrier_last_used
    if not new_boss_mode_active or selected_top_boss != 2:
        return
    time_now = pygame.time.get_ticks()
    # 얼음 방벽 스킬 (40% 확률) - 테스트용으로 높임
    if not ice_barrier_active and (time_now - ice_barrier_last_used >= ice_barrier_cooldown * 16.67):
        if random.random() <= 0.40:
            ice_barrier_active = True
            ice_barrier_timer = ice_barrier_duration
            ice_barrier_last_used = time_now
            show_speech("얼음 방벽!", duration=ice_barrier_duration)
            print("🧊 아이스 퀸이 얼음 방벽 사용!")
def handle_fire_knight_skills():
    """파이어 나이트의 스킬 처리"""
    global fire_charge_active, fire_charge_timer, fire_charge_last_used
    if not new_boss_mode_active or selected_bottom_boss != 1:
        return
    time_now = pygame.time.get_ticks()
    # 화염 돌진 스킬 (50% 확률) - 테스트용으로 높임
    if not fire_charge_active and (time_now - fire_charge_last_used >= fire_charge_cooldown * 16.67):
        if random.random() <= 0.50:
            fire_charge_active = True
            fire_charge_timer = fire_charge_duration
            fire_charge_last_used = time_now
            show_speech("화염 돌진!", duration=fire_charge_duration)
            print("🔥 파이어 나이트가 화염 돌진 사용!")
def handle_wind_spirit_skills():
    """윈드 스피릿의 스킬 처리"""
    global wind_burst_active, wind_burst_timer, wind_burst_last_used
    if not new_boss_mode_active or selected_bottom_boss != 2:
        return
    time_now = pygame.time.get_ticks()
    # 바람 폭발 스킬 (60% 확률) - 테스트용으로 높임
    if not wind_burst_active and (time_now - wind_burst_last_used >= wind_burst_cooldown * 16.67):
        if random.random() <= 0.60:
            wind_burst_active = True
            wind_burst_timer = wind_burst_duration
            wind_burst_last_used = time_now
            show_speech("바람 폭발!", duration=wind_burst_duration)
            print("💨 윈드 스피릿이 바람 폭발 사용!")
def handle_new_boss_skills_timer():
    """새로운 보스들의 스킬 타이머 처리"""
    global lightning_strike_active, lightning_strike_timer, ice_barrier_active, ice_barrier_timer
    global fire_charge_active, fire_charge_timer, wind_burst_active, wind_burst_timer
    global ball_vel
    if not new_boss_mode_active:
        return
    # 라이트닝 마스터 스킬 타이머 - 번개 충격 활성화 시 공 속도 증가
    if lightning_strike_active and lightning_strike_timer > 0:
        lightning_strike_timer -= 1
        # 번개 충격 효과: 공 속도 증가
        if ball_vel[1] < 0:  # 공이 위로 향할 때만 (하단에서 상단으로)
            ball_vel[0] *= 1.02  # X축 속도 증가
            ball_vel[1] *= 1.02  # Y축 속도 증가
            # 번개 효과로 공에 약간의 랜덤성 추가
            if lightning_strike_timer % 15 == 0:  # 15프레임마다
                thunder_force_x = random.uniform(-0.5, 0.5)
                thunder_force_y = random.uniform(-0.3, 0.3)
                ball_vel[0] += thunder_force_x
                ball_vel[1] += thunder_force_y
        if lightning_strike_timer <= 0:
            lightning_strike_active = False
            print("⚡ 라이트닝 마스터 전기 충격 효과 종료!")
    # 아이스 퀸 스킬 타이머 - 얼음 방벽 활성화 시 공 속도 50% 감소
    if ice_barrier_active and ice_barrier_timer > 0:
        ice_barrier_timer -= 1
        # 얼음 방벽 효과: 공 속도 감소
        if ball_vel[1] < 0:  # 공이 위로 향할 때만 (상단 보스에게 향할 때)
            ball_vel[0] *= 0.98  # X축 속도 감소
            ball_vel[1] *= 0.98  # Y축 속도 감소
        if ice_barrier_timer <= 0:
            ice_barrier_active = False
            print("🧊 아이스 퀸 얼음 방벽 효과 종료!")
    # 파이어 나이트 스킬 타이머
    if fire_charge_active and fire_charge_timer > 0:
        fire_charge_timer -= 1
        if fire_charge_timer <= 0:
            fire_charge_active = False
            print("🔥 파이어 나이트 화염 돌진 효과 종료!")
    # 윈드 스피릿 스킬 타이머 - 바람 폭발 시 공을 랜덤하게 튕겨냄
    if wind_burst_active and wind_burst_timer > 0:
        wind_burst_timer -= 1
        # 바람 폭발 효과: 공에 랜덤한 힘 적용
        if wind_burst_timer == wind_burst_duration - 1:  # 스킬 발동 직후 한 번만
            wind_force_x = random.uniform(-3, 3)
            wind_force_y = random.uniform(-2, 2)
            ball_vel[0] += wind_force_x
            ball_vel[1] += wind_force_y
            print(f"💨 바람 폭발! 공에 바람 힘 적용: ({wind_force_x:.1f}, {wind_force_y:.1f})")
        if wind_burst_timer <= 0:
            wind_burst_active = False
            print("💨 윈드 스피릿 바람 폭발 효과 종료!")
def handle_player(keys):
    special_gauge, special_ready, special_active, recent_dash_time, recent_dash_success_window, mega_smashing_bonus_applied
    global current_speed, player_slow_timer, rolling_consecutive_count, rolling_consecutive_timer  # 🎯 연속 대쉬 카운터 및 타이머
    global long_boost_active, long_boost_timer, PADDLE_WIDTH, long_boost_shrinking, long_boost_growing
    global player_stunned_timer, player_knockback_vel  # 🔹 스턴 전역
    global long_boost_scale, long_boost_target_scale, LONG_BOOST_TRANSITION_TIME, LONG_BOOST_DURATION, PLAYER, speedboots_obtained, speedgear_obtained
    global aipill_active  # 🆕 AI 필 변수 추가
    global wall_installing  # 🆕 벽돌 설치 변수 추가
    global is_waiting_for_serve  # 🆕 서브 대기 상태 변수 추가
    global is_player_serve  # 🆕 플레이어 서브 상태 변수 추가
    global gravitybelt_obtained  # 🆕 무중력벨트 변수 추가
    global rolling_active, rolling_timer, rolling_direction, rolling_speed, rolling_stun_timer, rolling_dash_available_timer, rolling_cooldown, rolling_charges, rolling_charge_timer
    global player_missile_stunned_timer, player_missile_knockback_vel, current_stage  # 스테이지 6 미사일 넉백
    global is_danger_sensor_dash  # 위험감지센서 대쉬 플래그
    global token_states  # 🆕 토큰 상태 리스트
    global molotov_throwing, molotov_throw_timer  # 화염병 투척 모션
    global grenade_throwing, grenade_throw_timer  # 수류탄 투척 모션
    global flare_throwing, flare_throw_timer  # 조명탄 투척 모션
    # 🆕 새로운 보스 모드에서는 하단 보스가 플레이어 역할
    if new_boss_mode_active:
        if selected_bottom_boss == 1:
            handle_fire_knight_as_bottom()  # 파이어 나이트
        elif selected_bottom_boss == 2:
            handle_wind_spirit_as_bottom()  # 윈드 스피릿
        return
    # 마우스 조작 처리 (비활성화됨)
    mouse_controls = {}
    # if input_manager.get_control_mode() == "마우스":
    #     mouse_controls = input_manager.handle_mouse_controls(selected_item_index, active_item_slot)
    # 키 입력 변수 초기화
    down_pressed = keys[pygame.K_DOWN]
    # 마우스 조작 (비활성화됨)
    # if input_manager.get_control_mode() == "마우스":
    #     if mouse_controls.get("space", False):
    #         space_pressed = True
    #     if mouse_controls.get("down", False):
    #         down_pressed = True
    special_gauge_max = get_max_gauge()  # 🔧 아카데미 스킬 적용된 최대치
    # ✅ 스턴 상태 처리
    if player_stunned_timer > 0:
        player_stunned_timer -= 1
        # 넉백 적용
        PLAYER.x += player_knockback_vel
        PLAYER.x = max(0, min(WIDTH - PADDLE_WIDTH, PLAYER.x))
        # 감속
        player_knockback_vel *= 0.85
        PLAYER.width = int(PADDLE_WIDTH * long_boost_scale)  # 스턴 중에도 거대화포션 효과 적용
        return  # 🔹 스턴 중에는 조작 불가
    # 스테이지 6 미사일 넉백 처리
    if current_stage == 6 and player_missile_stunned_timer > 0:
        player_missile_stunned_timer -= 1
        # 넉백 적용
        PLAYER.x += player_missile_knockback_vel
        PLAYER.x = max(0, min(WIDTH - PADDLE_WIDTH, PLAYER.x))
        # 감속 (화염탄과 동일한 0.85)
        player_missile_knockback_vel *= 0.85
        PLAYER.width = int(PADDLE_WIDTH * long_boost_scale)  # 스턴 중에도 거대화포션 효과 적용
        return  # 미사일 넉백 중에는 조작 불가
    # 🆕 벽돌 설치 중에는 움직이지 못함
    if wall_installing:
        return
    # 🔥 화염병 투척 모션 중 처리
    if molotov_throwing:
        molotov_throw_timer -= 1
        if molotov_throw_timer <= 0:
            molotov_throwing = False
            throw_molotov()  # 실제 투척
        return  # 투척 모션 중에는 조작 불가
    # 💣 수류탄 투척 모션 중 처리
    if grenade_throwing:
        grenade_throw_timer -= 1
        if grenade_throw_timer <= 0:
            grenade_throwing = False
            throw_grenade()  # 실제 투척
        return  # 투척 모션 중에는 조작 불가
    # 💡 조명탄 투척 모션 중 처리
    if flare_throwing:
        flare_throw_timer -= 1
        if flare_throw_timer <= 0:
            flare_throwing = False
            throw_flare()  # 실제 투척
        return  # 투척 모션 중에는 조작 불가
    # 연막탄 투척 모션 제거 (즉시 발동으로 변경됨)
    # ✅ 디버프 적용: 느려지는 효과
    if player_slow_timer > 0:
        speed_factor = 0.3
        player_slow_timer -= 1
    else:
        speed_factor = 1.0
    # === 롱부스트 타이머 체크 및 점진적 크기 변화 ===
    if long_boost_active:
        if long_boost_timer > 0:
            long_boost_timer -= 1
            # 시작 단계 (1초간 점진적 확대)
            if long_boost_timer > LONG_BOOST_DURATION - LONG_BOOST_TRANSITION_TIME:
                progress = (LONG_BOOST_DURATION - long_boost_timer) / LONG_BOOST_TRANSITION_TIME
                long_boost_scale = 1.0 + (1.5 - 1.0) * progress
            # 유지 단계
            elif long_boost_timer > LONG_BOOST_TRANSITION_TIME:
                long_boost_scale = 1.5
            # 종료 단계 (1초간 점진적 축소)
            else:
                progress = long_boost_timer / LONG_BOOST_TRANSITION_TIME
                long_boost_scale = 1.0 + (1.5 - 1.0) * progress
            # 타이머 종료 시
            if long_boost_timer == 0:
                long_boost_active = False
                long_boost_scale = 1.0
                long_boost_target_scale = 1.0
                print("🍄 거대화포션 효과 종료")
    # === 레이저스코프 타이머 체크 ===
    global predictor_active, predictor_timer
    if predictor_active and predictor_timer > 0:
        predictor_timer -= 1
        if predictor_timer == 0:
            predictor_active = False
            print("🎯 레이저스코프 효과 종료!")
    # 🆕 AI 필 효과 적용
    if aipill_active:
        # AI 필 활성화 시 필살기/아이템 사용 불가 (게이지는 유지하되 획득 불가)
        special_ready = False
        special_active = False
        # AI 필 활성화 시 공을 99% 확률로 막아내는 완벽한 추적
        # 공의 중심을 패들의 중심으로 맞추기
        target_x = BALL.centerx - PADDLE_WIDTH // 2
        # 경계 처리 - 패들이 화면 밖으로 나가지 않도록
        if target_x < 0:
            target_x = 0
        elif target_x > WIDTH - PADDLE_WIDTH:
            target_x = WIDTH - PADDLE_WIDTH
        # 즉시 목표 위치로 이동 (지연 없음)
        if abs(PLAYER.x - target_x) > 0.5:  # 0.5픽셀 이상 차이나면 움직임
            if PLAYER.x < target_x:
                # 오른쪽으로 이동
                current_speed = MAX_SPEED * aipill_speed_boost
            elif PLAYER.x > target_x:
                # 왼쪽으로 이동
                current_speed = -MAX_SPEED * aipill_speed_boost
        else:
            # 목표 위치에 도달하면 즉시 정지
            current_speed = 0
    else:
        # 🆕 구르기 상태 처리
        if rolling_active:
            # 구르기 중일 때
            rolling_timer -= 1
            if rolling_timer <= 0:
                # 구르기 종료, 통제 불가능 상태 시작
                rolling_active = False
                # 🤖 위험감지센서 자동 대쉬는 통제불능시간 없음
                if is_danger_sensor_dash:
                    rolling_stun_timer = 0
                    rolling_dash_available_timer = 0
                    is_danger_sensor_dash = False  # 플래그 리셋
                else:
                    # 일반 대쉬의 경우 기존 로직 적용
                    # 아카데미 스킬 효과: 통제불능 시간 감소 (모듈제어)
                    module_control_bonus = academy.get_skill_bonus("dash_module_control")
                    stun_reduction = int(module_control_bonus * 30)  # 기본 30프레임에서 10%씩 감소
                    # 스파이크부츠 효과: 제어불능 시간 15% 감소
                    base_stun_time = 30  # 0.5초 (60fps * 0.5)
                    if spikeboots_obtained:
                        base_stun_time = int(base_stun_time * 0.85)  # 15% 감소 (85%로 단축)
                    final_stun_time = max(1, base_stun_time - stun_reduction)  # 최소 1프레임
                    rolling_stun_timer = final_stun_time
                    rolling_dash_available_timer = final_stun_time
                current_speed = 0
            else:
                # 구르기 중에는 순간적으로 매우 빠르게 이동 후 빠르게 감속
                if rolling_timer > 20:  # 처음 10프레임은 매우 빠르게
                    current_speed = rolling_direction * 40  # 매우 빠른 속도 (50에서 40으로 20% 감소)
                else:  # 나머지는 빠르게 감속
                    decel_factor = rolling_timer / 20.0
                    current_speed = rolling_direction * 40 * decel_factor
        elif rolling_stun_timer > 0:
            # 구르기 후 통제 불가능 상태
            rolling_stun_timer -= 1
            if rolling_dash_available_timer > 0:
                rolling_dash_available_timer -= 1
            # 통제 불가능 중에는 조작 불가
            if not gravitybelt_obtained:
                # 무중력벨트가 없을 때만 감속 적용
                if current_speed > 0:
                    current_speed -= DECELERATION * 2  # 빠른 감속
                elif current_speed < 0:
                    current_speed += DECELERATION * 2
            # 🎯 토큰이 2개 이상 있을 때 통제불능 상태에서도 추가 대쉬 가능 (대쉬홀더 또는 증폭 스킬)
            base_charges = 1  # 기본 1개
            holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
            amplification_bonus = academy.get_skill_bonus("dash_amplification")
            max_charges = int(base_charges + holder_bonus + amplification_bonus)
            if max_charges > 1 and rolling_charges > 0:
                # 🎯 연속 대쉬 할인을 고려한 실제 게이지 요구량 계산
                base_gauge_cost = 140  # 대시 기본 비용: 160 → 140
                # 대시 실행 시 rolling_consecutive_count가 1 증가하므로 미리 계산
                next_consecutive_count = rolling_consecutive_count + 1
                consecutive_discount = 0.5 ** (next_consecutive_count - 1)  # 실제 대시에서 사용할 할인율
                discounted_cost = int(base_gauge_cost * consecutive_discount)
                if dashgear_obtained:
                    discounted_cost = int(discounted_cost * 0.8)  # 대쉬기어 20% 할인
                battery_bonus = academy.get_skill_bonus("dash_battery_pack")
                required_gauge = max(10, int(discounted_cost * (1 - battery_bonus)))  # 실제 필요 게이지
                if keys[pygame.K_LEFT] and down_pressed and special_gauge >= required_gauge and rolling_charges > 0:
                    # 통제불능 상태에서 왼쪽 대쉬 실행 (아래키 + 왼쪽키 필요)
                    rolling_active = True
                    # 🆕 대쉬 효과음 재생
                    SOUND_DASH.play()
                    # 대쉬기어 효과: 대쉬 거리 10% 증가
                    base_rolling_timer = 15  # 기본 대쉬 시간
                    if dashgear_obtained:
                        base_rolling_timer = 16  # 0.267초 대쉬 (15 * 1.1)
                    # 🚀 아카데미 스킬 효과 적용: 대쉬 거리 증가 (도약)
                    jump_bonus = academy.get_skill_bonus("dash_jump")  # 도약: 대쉬거리 증가
                    total_distance_bonus = jump_bonus
                    base_rolling_timer = int(base_rolling_timer * (1 + total_distance_bonus))
                    # 스킬 효과 적용: 대쉬 거리 증가
                    skill_distance_boost = skill.apply_dash_distance_boost(base_rolling_timer)
                    rolling_timer = int(skill_distance_boost)
                    rolling_direction = -1
                    # 🌟 대쉬 스피릿 스킬: 확률적 레이저 생성
                    dash_spirit_level = academy.get_skill_bonus("dash_spirit")
                    if dash_spirit_level > 0:
                        # 확률 계산: 레벨1=15%, 레벨2=30%
                        dash_spirit_chance = dash_spirit_level
                        if random.random() < dash_spirit_chance:
                            # 🎯 플레이어를 따라오다가 대쉬 거리의 50% 지점에서 스피릿 생성 종료
                            # 대쉬 중 속도는 40, 첫 20프레임은 최대 속도, 이후 감속
                            # 평균적으로 rolling_timer의 약 70% 정도가 효과적인 이동 시간
                            actual_dash_distance = int(rolling_timer * 40 * 0.7)  # 실제 대쉬 거리
                            dash_distance = int(actual_dash_distance * 0.5)  # 대쉬 거리의 50% 지점에서 종료
                            create_dash_spirit_laser(PLAYER.centerx, PLAYER.centery, -1, dash_distance)
                    # 🔧 토큰 사용 - 대쉬 매니저와 동기화
                    rolling_charges = max(0, rolling_charges - 1)
                    # 최대 토큰 수 계산 (먼저 계산해야 함)
                    base_charges = 1  # 기본 1개
                    holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
                    amplification_bonus = academy.get_skill_bonus("dash_amplification")
                    max_charges = int(base_charges + holder_bonus + amplification_bonus)
                    # 오른쪽부터 토큰 소진 (token_states가 있을 때만)
                    if 'token_states' in globals() and len(token_states) > 0:
                        # 오른쪽부터 검색하여 소진
                        for idx in range(min(len(token_states), max_charges) - 1, -1, -1):
                            if idx < len(token_states) and token_states[idx]:
                                token_states[idx] = False
                                break
                    else:
                        # token_states가 없으면 초기화
                        token_states = [True] * rolling_charges + [False] * (max_charges - rolling_charges)
                    # 아카데미 스킬 효과: 쿨타임 감소
                    dash_cooldown_bonus = academy.get_skill_bonus("dash_cooldown")
                    cooldown_reduction = int(dash_cooldown_bonus * 60)  # 초 단위를 프레임으로 변환
                    # 다중 토큰 시스템 로직 (대쉬홀더 또는 증폭 스킬)
                    if max_charges > 1:
                        if rolling_charges >= 1:  # 아직 1개 이상 남아있으면 (2개에서 1개 사용)
                            rolling_cooldown = max(6, 60 - cooldown_reduction)   # 1초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 60 - cooldown_reduction)  # 1초 후 풀 충전 (2개로)
                        else:  # 마지막 대쉬 사용 (1개에서 0개)
                            rolling_cooldown = max(6, 90 - cooldown_reduction)   # 1.5초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 90 - cooldown_reduction)  # 1.5초 후 1개 충전
                    else:
                        # 기본 대쉬 후 1.5초
                        base_cooldown = 90  # 1.5초 (90프레임)
                        # 스파이크부츠 효과: 쿨타임 20% 감소
                        if spikeboots_obtained:
                            base_cooldown = int(base_cooldown * 0.8)  # 20% 감소 (80%로 단축)
                        rolling_cooldown = max(6, base_cooldown - cooldown_reduction)  # 최소 0.1초
                        rolling_charge_timer = max(6, base_cooldown - cooldown_reduction)  # 쿨타임과 동일
                        print(f"[DEBUG] 대쉬 사용 후 충전 타이머 설정: {rolling_charge_timer} (토큰: {rolling_charges})")
                    # 🎯 연속 대쉬 할인 시스템: 연속 사용 시 50%씩 할인
                    rolling_consecutive_count += 1
                    rolling_consecutive_timer = 60  # 1초간 연속 대쉬 유지
                    # 🔧 대쉬 매니저와 동기화 - 토큰 소모 및 충전 타이머 설정
                    if dash is not None:
                        dash.sync_with_legacy_system(rolling_charges, rolling_charge_timer, rolling_consecutive_count)
                    # 기본 게이지 소모량
                    base_gauge_cost = 140  # 대시 기본 비용: 160 → 140
                    # 연속 대쉬 할인 계산 (첫 번째: 160, 두 번째: 80, 세 번째: 40...)
                    consecutive_discount = 0.5 ** (rolling_consecutive_count - 1)  # 0.5^0=1, 0.5^1=0.5, 0.5^2=0.25...
                    discounted_cost = int(base_gauge_cost * consecutive_discount)
                    # 대쉬기어 효과: 게이지 소모 20% 감소
                    if dashgear_obtained:
                        discounted_cost = int(discounted_cost * 0.8)  # 20% 추가 할인
                    # 아카데미 스킬 효과 적용: 게이지 소모 감소 (배터리팩)
                    battery_bonus = academy.get_skill_bonus("dash_battery_pack")
                    final_gauge_cost = max(10, int(discounted_cost * (1 - battery_bonus)))  # 최소 10은 소모
                    special_gauge = max(0, special_gauge - final_gauge_cost)  # 게이지가 음수가 되지 않도록 보정
                    # 🔹 게이지 감소 시 special_ready 상태 업데이트
                    if special_gauge < special_gauge_max:
                        special_ready = False
                    print(f"통제불능 상태에서 왼쪽 대쉬 실행! (연속 {rolling_consecutive_count}회, 할인된 소모: {final_gauge_cost}, 남은 횟수: {rolling_charges}, 게이지: {special_gauge})")
                elif keys[pygame.K_RIGHT] and down_pressed and special_gauge >= required_gauge and rolling_charges > 0:
                    # 통제불능 상태에서 오른쪽 대쉬 실행 (아래키 + 오른쪽키 필요)
                    rolling_active = True
                    # 🆕 대쉬 효과음 재생
                    SOUND_DASH.play()
                    # 대쉬기어 효과: 대쉬 거리 10% 증가
                    base_rolling_timer = 15  # 기본 대쉬 시간
                    if dashgear_obtained:
                        base_rolling_timer = 16  # 0.267초 대쉬 (15 * 1.1)
                    # 🚀 아카데미 스킬 효과 적용: 대쉬 거리 증가 (도약)
                    jump_bonus = academy.get_skill_bonus("dash_jump")  # 도약: 대쉬거리 증가
                    total_distance_bonus = jump_bonus
                    base_rolling_timer = int(base_rolling_timer * (1 + total_distance_bonus))
                    # 스킬 효과 적용: 대쉬 거리 증가
                    skill_distance_boost = skill.apply_dash_distance_boost(base_rolling_timer)
                    rolling_timer = int(skill_distance_boost)
                    rolling_direction = 1
                    # 🌟 대쉬 스피릿 스킬: 확률적 레이저 생성
                    dash_spirit_level = academy.get_skill_bonus("dash_spirit")
                    if dash_spirit_level > 0:
                        # 확률 계산: 레벨1=15%, 레벨2=30%
                        dash_spirit_chance = dash_spirit_level
                        if random.random() < dash_spirit_chance:
                            # 🎯 플레이어를 따라오다가 대쉬 거리의 50% 지점에서 스피릿 생성 종료
                            # 대쉬 중 속도는 40, 첫 20프레임은 최대 속도, 이후 감속
                            # 평균적으로 rolling_timer의 약 70% 정도가 효과적인 이동 시간
                            actual_dash_distance = int(rolling_timer * 40 * 0.7)  # 실제 대쉬 거리
                            dash_distance = int(actual_dash_distance * 0.5)  # 대쉬 거리의 50% 지점에서 종료
                            create_dash_spirit_laser(PLAYER.centerx, PLAYER.centery, 1, dash_distance)
                    # 🔧 토큰 사용 - 대쉬 매니저와 동기화
                    rolling_charges = max(0, rolling_charges - 1)
                    # 최대 토큰 수 계산 (먼저 계산해야 함)
                    base_charges = 1  # 기본 1개
                    holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
                    amplification_bonus = academy.get_skill_bonus("dash_amplification")
                    max_charges = int(base_charges + holder_bonus + amplification_bonus)
                    # 오른쪽부터 토큰 소진 (token_states가 있을 때만)
                    if 'token_states' in globals() and len(token_states) > 0:
                        # 오른쪽부터 검색하여 소진
                        for idx in range(min(len(token_states), max_charges) - 1, -1, -1):
                            if idx < len(token_states) and token_states[idx]:
                                token_states[idx] = False
                                break
                    else:
                        # token_states가 없으면 초기화
                        token_states = [True] * rolling_charges + [False] * (max_charges - rolling_charges)
                    # 아카데미 스킬 효과: 쿨타임 감소
                    dash_cooldown_bonus = academy.get_skill_bonus("dash_cooldown")
                    cooldown_reduction = int(dash_cooldown_bonus * 60)  # 초 단위를 프레임으로 변환
                    # 다중 토큰 시스템 로직 (대쉬홀더 또는 증폭 스킬)
                    if max_charges > 1:
                        if rolling_charges >= 1:  # 아직 1개 이상 남아있으면 (2개에서 1개 사용)
                            rolling_cooldown = max(6, 60 - cooldown_reduction)   # 1초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 60 - cooldown_reduction)  # 1초 후 풀 충전 (2개로)
                        else:  # 마지막 대쉬 사용 (1개에서 0개)
                            rolling_cooldown = max(6, 90 - cooldown_reduction)   # 1.5초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 90 - cooldown_reduction)  # 1.5초 후 1개 충전
                    else:
                        # 기본 대쉬 후 1.5초
                        base_cooldown = 90  # 1.5초 (90프레임)
                        # 스파이크부츠 효과: 쿨타임 20% 감소
                        if spikeboots_obtained:
                            base_cooldown = int(base_cooldown * 0.8)  # 20% 감소 (80%로 단축)
                        rolling_cooldown = max(6, base_cooldown - cooldown_reduction)  # 최소 0.1초
                        rolling_charge_timer = max(6, base_cooldown - cooldown_reduction)  # 쿨타임과 동일
                        print(f"[DEBUG] 대쉬 사용 후 충전 타이머 설정: {rolling_charge_timer} (토큰: {rolling_charges})")
                    # 기본 게이지 소모량
                    base_gauge_cost = 140  # 대시 기본 비용: 160 → 140
                    discounted_cost = base_gauge_cost
                    # 대쉬기어 효과: 게이지 소모 20% 감소
                    if dashgear_obtained:
                        discounted_cost = int(discounted_cost * 0.8)  # 20% 할인
                    # 아카데미 스킬 효과 적용: 게이지 소모 감소 (배터리팩)
                    battery_bonus = academy.get_skill_bonus("dash_battery_pack")
                    final_gauge_cost = max(10, int(discounted_cost * (1 - battery_bonus)))  # 최소 10은 소모
                    special_gauge = max(0, special_gauge - final_gauge_cost)  # 게이지가 음수가 되지 않도록 보정
                    # 🔹 게이지 감소 시 special_ready 상태 업데이트
                    if special_gauge < special_gauge_max:
                        special_ready = False
                    print(f"통제불능 상태에서 오른쪽 대쉬 실행! (남은 횟수: {rolling_charges}, 게이지: {special_gauge})")
        else:
            # 🆕 구르기 쿨타임 감소
            if rolling_cooldown > 0:
                rolling_cooldown -= 1
            # 🆕 연속 대쉬 타이머 감소 (1초 후 연속 대쉬 카운터 리셋)
            if rolling_consecutive_timer > 0:
                rolling_consecutive_timer -= 1
                if rolling_consecutive_timer <= 0:
                    rolling_consecutive_count = 0  # 연속 대쉬 카운터 리셋
                    print("연속 대쉬 시간 만료 - 할인 리셋")
            # 🆕 구르기 충전 타이머 감소
            if rolling_charge_timer > 0:
                old_timer = rolling_charge_timer
                rolling_charge_timer -= 1
                if rolling_charge_timer % 30 == 0 or rolling_charge_timer <= 5:
                    print(f"[DEBUG] 충전 타이머 감소: {old_timer} → {rolling_charge_timer}")
                if rolling_charge_timer <= 0:
                    # 토큰 충전
                    base_charges = 1
                    holder_bonus = 1 if dashholder_obtained else 0
                    amplification_bonus = academy.get_skill_bonus("dash_amplification")
                    max_charges = int(base_charges + holder_bonus + amplification_bonus)
                    rolling_charges = min(rolling_charges + 1, max_charges)
                    # 왼쪽부터 토큰 충전 (token_states가 있을 때만)
                    if 'token_states' in globals() and len(token_states) > 0:
                        # 첫 번째 비어있는 토큰을 찾아서 충전
                        for idx in range(min(len(token_states), max_charges)):
                            if idx < len(token_states) and not token_states[idx]:
                                token_states[idx] = True
                                break
                    else:
                        # token_states가 없으면 초기화
                        token_states = [True] * rolling_charges + [False] * (max_charges - rolling_charges)
                    # 아직 최대 토큰이 아니면 다음 충전 타이머 설정
                    if rolling_charges < max_charges:
                        # 경량화 스킬 효과 적용
                        lightweight_bonus = academy.get_skill_bonus("dash_lightweight")
                        charge_time_reduction = lightweight_bonus
                        base_charge_time = 90  # 1.5초
                        rolling_charge_timer = int(base_charge_time * (1 - charge_time_reduction))
                        print(f"[DEBUG] 다음 토큰 충전 타이머 설정: {rolling_charge_timer}프레임")
                    else:
                        rolling_consecutive_count = 0  # 모든 토큰 충전 시 연속 카운터 리셋
                    print(f"✅ 토큰 충전 완료! 현재: {rolling_charges}/{max_charges}")
                    print(f"[DEBUG] 충전 후 타이머: {rolling_charge_timer}")
            # 🆕 구르기 충전 - 대쉬 매니저에게 위임 (비활성화 - 고스트샷 버그 때문에)
            # 대쉬 매니저와의 동기화를 일시적으로 비활성화
            # TODO: 대쉬 매니저와 고스트샷 시스템 통합 필요
            if False and dash is not None:
                # 대쉬 매니저의 상태를 가져와서 레거시 시스템과 동기화
                dash_tokens, dash_timer, dash_consecutive, dash_max = dash.get_legacy_sync_data()
                if rolling_charges != dash_tokens or rolling_charge_timer != dash_timer:
                    rolling_charges = dash_tokens
                    rolling_charge_timer = dash_timer
                    rolling_consecutive_count = dash_consecutive
            # 🆕 구르기 더블탭 감지
            current_time = pygame.time.get_ticks()
            # 아래키 + 방향키로 대쉬 발동 (무릎보호대 효과 적용)
            # 플레이어 서브 상태일 때 처음 6초 동안은 대쉬 발동 불가
            can_use_rolling = False
            # 기본 대쉬 조건 (일반 상태에서만)
            if rolling_charges > 0 and not is_waiting_for_serve and rolling_stun_timer <= 0:
                can_use_rolling = True
            # 플레이어 서브 상태에서는 6초 후에만 대쉬 가능
            elif is_player_serve and is_waiting_for_serve and rolling_charges > 0:
                serve_wait_time = pygame.time.get_ticks() - waiting_start_time
                if serve_wait_time >= 6000:  # 6초 이상 대기했을 때만
                    can_use_rolling = True
            # 디버깅: 대쉬 조건 확인
            if keys[pygame.K_DOWN]:
                print(f"아래키 눌림 - 대쉬 조건: charges={rolling_charges}, stun_timer={rolling_stun_timer}, waiting_serve={is_waiting_for_serve}, player_serve={is_player_serve}, can_use={can_use_rolling}")
                if is_player_serve and is_waiting_for_serve:
                    serve_wait_time = pygame.time.get_ticks() - waiting_start_time
                    print(f"서브 대기 시간: {serve_wait_time}ms")
            if down_pressed and can_use_rolling and rolling_charges > 0 and not rolling_active:
                # 🎯 연속 대쉬 할인을 고려한 실제 게이지 요구량 계산  
                base_gauge_cost = 140  # 대시 기본 비용: 160 → 140
                # 대시 실행 시 rolling_consecutive_count가 1 증가하므로 미리 계산
                next_consecutive_count = rolling_consecutive_count + 1
                consecutive_discount = 0.5 ** (next_consecutive_count - 1)  # 실제 대시에서 사용할 할인율
                discounted_cost = int(base_gauge_cost * consecutive_discount)
                if dashgear_obtained:
                    discounted_cost = int(discounted_cost * 0.8)  # 대쉬기어 20% 할인
                battery_bonus = academy.get_skill_bonus("dash_battery_pack")
                required_gauge = max(10, int(discounted_cost * (1 - battery_bonus)))  # 실제 필요 게이지
                if keys[pygame.K_LEFT] and keys[pygame.K_DOWN] and special_gauge >= required_gauge:
                    # 아래키 + 왼쪽 - 대쉬 실행
                    rolling_active = True
                    # 🆕 대쉬 효과음 재생
                    SOUND_DASH.play()
                    # 대쉬기어 효과: 대쉬 거리 10% 증가
                    base_rolling_timer = 15  # 기본 대쉬 시간
                    if dashgear_obtained:
                        base_rolling_timer = 16  # 0.267초 대쉬 (15 * 1.1)
                    # 아카데미 스킬 효과 적용: 대쉬 거리 증가 (도약)
                    jump_bonus = academy.get_skill_bonus("dash_jump")  # 도약: 대쉬거리 증가
                    total_distance_bonus = jump_bonus
                    base_rolling_timer = int(base_rolling_timer * (1 + total_distance_bonus))
                    # 스킬 효과 적용: 대쉬 거리 증가 (기존 시스템 유지)
                    skill_distance_boost = skill.apply_dash_distance_boost(base_rolling_timer)
                    rolling_timer = int(skill_distance_boost)
                    rolling_direction = -1
                    # 🌟 대쉬 스피릿 스킬: 확률적 레이저 생성
                    dash_spirit_level = academy.get_skill_bonus("dash_spirit")
                    if dash_spirit_level > 0:
                        # 확률 계산: 레벨1=15%, 레벨2=30%
                        dash_spirit_chance = dash_spirit_level
                        if random.random() < dash_spirit_chance:
                            # 🎯 플레이어를 따라오다가 대쉬 거리의 50% 지점에서 스피릿 생성 종료
                            # 대쉬 중 속도는 40, 첫 20프레임은 최대 속도, 이후 감속
                            # 평균적으로 rolling_timer의 약 70% 정도가 효과적인 이동 시간
                            actual_dash_distance = int(rolling_timer * 40 * 0.7)  # 실제 대쉬 거리
                            dash_distance = int(actual_dash_distance * 0.5)  # 대쉬 거리의 50% 지점에서 종료
                            create_dash_spirit_laser(PLAYER.centerx, PLAYER.centery, -1, dash_distance)
                    # 🔧 토큰 사용 - 대쉬 매니저와 동기화
                    rolling_charges = max(0, rolling_charges - 1)
                    # 최대 토큰 수 계산 (먼저 계산해야 함)
                    base_charges = 1  # 기본 1개
                    holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
                    amplification_bonus = academy.get_skill_bonus("dash_amplification")
                    max_charges = int(base_charges + holder_bonus + amplification_bonus)
                    # 오른쪽부터 토큰 소진 (token_states가 있을 때만)
                    if 'token_states' in globals() and len(token_states) > 0:
                        # 오른쪽부터 검색하여 소진
                        for idx in range(min(len(token_states), max_charges) - 1, -1, -1):
                            if idx < len(token_states) and token_states[idx]:
                                token_states[idx] = False
                                break
                    else:
                        # token_states가 없으면 초기화
                        token_states = [True] * rolling_charges + [False] * (max_charges - rolling_charges)
                    # 아카데미 스킬 효과: 쿨타임 감소
                    dash_cooldown_bonus = academy.get_skill_bonus("dash_cooldown")
                    cooldown_reduction = int(dash_cooldown_bonus * 60)  # 초 단위를 프레임으로 변환
                    # 다중 토큰 시스템 로직 (대쉬홀더 또는 증폭 스킬)
                    if max_charges > 1:
                        if rolling_charges >= 1:  # 아직 1개 이상 남아있으면 (2개에서 1개 사용)
                            rolling_cooldown = max(6, 60 - cooldown_reduction)   # 1초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 60 - cooldown_reduction)  # 1초 후 풀 충전 (2개로)
                        else:  # 마지막 대쉬 사용 (1개에서 0개)
                            rolling_cooldown = max(6, 90 - cooldown_reduction)   # 1.5초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 90 - cooldown_reduction)  # 1.5초 후 1개 충전
                    else:
                        # 기본 대쉬 후 1.5초
                        base_cooldown = 90  # 1.5초 (90프레임)
                        # 스파이크부츠 효과: 쿨타임 20% 감소
                        if spikeboots_obtained:
                            base_cooldown = int(base_cooldown * 0.8)  # 20% 감소 (80%로 단축)
                        rolling_cooldown = max(6, base_cooldown - cooldown_reduction)  # 최소 0.1초
                        rolling_charge_timer = max(6, base_cooldown - cooldown_reduction)  # 쿨타임과 동일
                        print(f"[DEBUG] 대쉬 사용 후 충전 타이머 설정: {rolling_charge_timer} (토큰: {rolling_charges})")
                    # 🎯 연속 대쉬 할인 시스템: 연속 사용 시 50%씩 할인
                    rolling_consecutive_count += 1
                    rolling_consecutive_timer = 60  # 1초간 연속 대쉬 유지
                    # 🔧 대쉬 매니저와 동기화 - 토큰 소모 및 충전 타이머 설정
                    if dash is not None:
                        dash.sync_with_legacy_system(rolling_charges, rolling_charge_timer, rolling_consecutive_count)
                    # 기본 게이지 소모량
                    base_gauge_cost = 140  # 대시 기본 비용: 160 → 140
                    # 연속 대쉬 할인 계산 (첫 번째: 160, 두 번째: 80, 세 번째: 40...)
                    consecutive_discount = 0.5 ** (rolling_consecutive_count - 1)  # 0.5^0=1, 0.5^1=0.5, 0.5^2=0.25...
                    discounted_cost = int(base_gauge_cost * consecutive_discount)
                    # 대쉬기어 효과: 게이지 소모 20% 감소
                    if dashgear_obtained:
                        discounted_cost = int(discounted_cost * 0.8)  # 20% 추가 할인
                    # 아카데미 스킬 효과 적용: 게이지 소모 감소 (배터리팩)
                    battery_bonus = academy.get_skill_bonus("dash_battery_pack")
                    final_gauge_cost = max(10, int(discounted_cost * (1 - battery_bonus)))  # 최소 10은 소모
                    special_gauge = max(0, special_gauge - final_gauge_cost)  # 게이지가 음수가 되지 않도록 보정
                    # 🔹 게이지 감소 시 special_ready 상태 업데이트
                    if special_gauge < special_gauge_max:
                        special_ready = False
                    print(f"왼쪽 대쉬 실행! (연속 {rolling_consecutive_count}회, 할인된 소모: {final_gauge_cost}, 남은 횟수: {rolling_charges}, 게이지: {special_gauge})")
                    # 🏆 대쉬 사용 기록
                    recent_dash_time = pygame.time.get_ticks()
                    mega_smashing_bonus_applied = False  # 고스트샷 보너스 리셋 (새로운 콤보 가능)
                    record_dash_usage(success=False)  # 일단 사용만 기록, 성공은 공 충돌 시 체크
                # 🔧 대쉬 매니저와 4번째 대쉬 위치 동기화
                if dash is not None and rolling_charge_timer > 0:
                    dash.sync_with_legacy_system(rolling_charges, rolling_charge_timer, rolling_consecutive_count)
                elif keys[pygame.K_RIGHT] and keys[pygame.K_DOWN] and special_gauge >= required_gauge:
                    # 아래키 + 오른쪽 - 대쉬 실행
                    rolling_active = True
                    # 🆕 대쉬 효과음 재생
                    SOUND_DASH.play()
                    # 대쉬기어 효과: 대쉬 거리 10% 증가
                    base_rolling_timer = 15  # 기본 대쉬 시간
                    if dashgear_obtained:
                        base_rolling_timer = 16  # 0.267초 대쉬 (15 * 1.1)
                    # 아카데미 스킬 효과 적용: 대쉬 거리 증가 (도약)
                    jump_bonus = academy.get_skill_bonus("dash_jump")  # 도약: 대쉬거리 증가
                    total_distance_bonus = jump_bonus
                    base_rolling_timer = int(base_rolling_timer * (1 + total_distance_bonus))
                    # 스킬 효과 적용: 대쉬 거리 증가 (기존 시스템 유지)
                    skill_distance_boost = skill.apply_dash_distance_boost(base_rolling_timer)
                    rolling_timer = int(skill_distance_boost)
                    rolling_direction = 1
                    # 🌟 대쉬 스피릿 스킬: 확률적 레이저 생성
                    dash_spirit_level = academy.get_skill_bonus("dash_spirit")
                    if dash_spirit_level > 0:
                        # 확률 계산: 레벨1=15%, 레벨2=30%
                        dash_spirit_chance = dash_spirit_level
                        if random.random() < dash_spirit_chance:
                            # 🎯 플레이어를 따라오다가 대쉬 거리의 50% 지점에서 스피릿 생성 종료
                            # 대쉬 중 속도는 40, 첫 20프레임은 최대 속도, 이후 감속
                            # 평균적으로 rolling_timer의 약 70% 정도가 효과적인 이동 시간
                            actual_dash_distance = int(rolling_timer * 40 * 0.7)  # 실제 대쉬 거리
                            dash_distance = int(actual_dash_distance * 0.5)  # 대쉬 거리의 50% 지점에서 종료
                            create_dash_spirit_laser(PLAYER.centerx, PLAYER.centery, 1, dash_distance)
                    # 🔧 토큰 사용 - 대쉬 매니저와 동기화
                    rolling_charges = max(0, rolling_charges - 1)
                    # 최대 토큰 수 계산 (먼저 계산해야 함)
                    base_charges = 1  # 기본 1개
                    holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
                    amplification_bonus = academy.get_skill_bonus("dash_amplification")
                    max_charges = int(base_charges + holder_bonus + amplification_bonus)
                    # 오른쪽부터 토큰 소진 (token_states가 있을 때만)
                    if 'token_states' in globals() and len(token_states) > 0:
                        # 오른쪽부터 검색하여 소진
                        for idx in range(min(len(token_states), max_charges) - 1, -1, -1):
                            if idx < len(token_states) and token_states[idx]:
                                token_states[idx] = False
                                break
                    else:
                        # token_states가 없으면 초기화
                        token_states = [True] * rolling_charges + [False] * (max_charges - rolling_charges)
                    # 아카데미 스킬 효과: 쿨타임 감소
                    dash_cooldown_bonus = academy.get_skill_bonus("dash_cooldown")
                    cooldown_reduction = int(dash_cooldown_bonus * 60)  # 초 단위를 프레임으로 변환
                    # 다중 토큰 시스템 로직 (대쉬홀더 또는 증폭 스킬)
                    if max_charges > 1:
                        if rolling_charges >= 1:  # 아직 1개 이상 남아있으면 (2개에서 1개 사용)
                            rolling_cooldown = max(6, 60 - cooldown_reduction)   # 1초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 60 - cooldown_reduction)  # 1초 후 풀 충전 (2개로)
                        else:  # 마지막 대쉬 사용 (1개에서 0개)
                            rolling_cooldown = max(6, 90 - cooldown_reduction)   # 1.5초 쿨타임 (최소 0.1초)
                            rolling_charge_timer = max(6, 90 - cooldown_reduction)  # 1.5초 후 1개 충전
                    else:
                        # 기본 대쉬 후 1.5초
                        base_cooldown = 90  # 1.5초 (90프레임)
                        # 스파이크부츠 효과: 쿨타임 20% 감소
                        if spikeboots_obtained:
                            base_cooldown = int(base_cooldown * 0.8)  # 20% 감소 (80%로 단축)
                        rolling_cooldown = max(6, base_cooldown - cooldown_reduction)  # 최소 0.1초
                        rolling_charge_timer = max(6, base_cooldown - cooldown_reduction)  # 쿨타임과 동일
                        print(f"[DEBUG] 대쉬 사용 후 충전 타이머 설정: {rolling_charge_timer} (토큰: {rolling_charges})")
                    # 🎯 연속 대쉬 할인 시스템: 연속 사용 시 50%씩 할인
                    rolling_consecutive_count += 1
                    rolling_consecutive_timer = 60  # 1초간 연속 대쉬 유지
                    # 🔧 대쉬 매니저와 동기화 - 토큰 소모 및 충전 타이머 설정
                    if dash is not None:
                        dash.sync_with_legacy_system(rolling_charges, rolling_charge_timer, rolling_consecutive_count)
                    # 기본 게이지 소모량
                    base_gauge_cost = 140  # 대시 기본 비용: 160 → 140
                    # 연속 대쉬 할인 계산 (첫 번째: 160, 두 번째: 80, 세 번째: 40...)
                    consecutive_discount = 0.5 ** (rolling_consecutive_count - 1)  # 0.5^0=1, 0.5^1=0.5, 0.5^2=0.25...
                    discounted_cost = int(base_gauge_cost * consecutive_discount)
                    # 대쉬기어 효과: 게이지 소모 20% 감소
                    if dashgear_obtained:
                        discounted_cost = int(discounted_cost * 0.8)  # 20% 추가 할인
                    # 아카데미 스킬 효과 적용: 게이지 소모 감소 (배터리팩)
                    battery_bonus = academy.get_skill_bonus("dash_battery_pack")
                    final_gauge_cost = max(10, int(discounted_cost * (1 - battery_bonus)))  # 최소 10은 소모
                    special_gauge = max(0, special_gauge - final_gauge_cost)  # 게이지가 음수가 되지 않도록 보정
                    # 🔹 게이지 감소 시 special_ready 상태 업데이트
                    if special_gauge < special_gauge_max:
                        special_ready = False
                    print(f"오른쪽 대쉬 실행! (연속 {rolling_consecutive_count}회, 할인된 소모: {final_gauge_cost}, 남은 횟수: {rolling_charges}, 게이지: {special_gauge})")
                    # 🏆 대쉬 사용 기록
                    recent_dash_time = pygame.time.get_ticks()
                    mega_smashing_bonus_applied = False  # 고스트샷 보너스 리셋 (새로운 콤보 가능)
                    record_dash_usage(success=False)  # 일단 사용만 기록, 성공은 공 충돌 시 체크
            # 🆕 스피드부츠 효과 적용 (15% 증가)
            speed_multiplier = (1.0 + PERMANENT_SPEED_BOOST) if speedboots_obtained else 1.0
            # 스킬 효과 적용: 패들 속도 증가
            skill_speed_boost = skill.apply_paddle_speed_boost(0)
            effective_max_speed = (MAX_SPEED + skill_speed_boost) * speed_multiplier
            # 일반 이동 키 처리 (키보드 + 마우스 조작 통합)
            # 통제불능 상태에서는 일반 이동 불가 (더블대쉬 아이템 소지 시에도)
            if rolling_stun_timer <= 0:
                # 키보드 조작
                left_pressed = keys[pygame.K_LEFT]
                right_pressed = keys[pygame.K_RIGHT]
                # 마우스 조작 (비활성화됨)
                if False:  # input_manager.get_control_mode() == "마우스":
                    # 마우스 위치로 직접 패들 이동
                    mouse_x, mouse_y = pygame.mouse.get_pos()
                    target_x = mouse_x - PADDLE_WIDTH // 2
                    # 경계 처리
                    target_x = max(0, min(WIDTH - PADDLE_WIDTH, target_x))
                    # 즉시 이동
                    PLAYER.x = target_x
                    current_speed = 0
                    # 마우스 클릭 처리 (이미 이벤트 루프에서 처리됨)
                    mouse_state = input_manager.get_mouse_state()
                    if mouse_state['left_pressed']:
                        left_pressed = True
                    if mouse_state['right_pressed']:
                        right_pressed = True
                else:
                    # 키보드 조작 (감전 상태가 아닐 때만)
                    if not player_stunned:
                        if gravitybelt_obtained:
                            # 무중력벨트: 완전히 기계적인 즉각 이동 (키 누르는 동안만)
                            # 시너지 효과일 때는 추가 속도 +3
                            speed_bonus = 3 if gravity_speed_synergy else 0
                            if left_pressed:
                                current_speed = -(effective_max_speed + speed_bonus) * speed_factor
                            elif right_pressed:
                                current_speed = (effective_max_speed + speed_bonus) * speed_factor
                            else:
                                # 키를 떼면 즉시 정지
                                current_speed = 0
                        else:
                            # 일반 이동: 가속도와 감속도 적용
                            if left_pressed:
                                if current_speed > -effective_max_speed * speed_factor:
                                    current_speed -= ACCELERATION
                            elif right_pressed:
                                if current_speed < effective_max_speed * speed_factor:
                                    current_speed += ACCELERATION
                            else:
                                # 키를 떼었을 때 감속 적용 (무중력벨트가 없을 때만)
                                if not gravitybelt_obtained:
                                    if current_speed > 0:
                                        current_speed -= DECELERATION
                                    elif current_speed < 0:
                                        current_speed += DECELERATION
                                # 무중력벨트가 있으면 감속 로직 완전 무시 (속도 유지)
                    else:
                        # 감전 상태일 때는 즉시 정지
                        current_speed = 0
    # 🆕 스피드기어 효과: 빠른 방향 전환 감속 (무중력벨트 없을 때만, 감전 상태가 아닐 때만)
    if not gravitybelt_obtained and not player_stunned:
        direction_change_boost = DIRECTION_CHANGE_BOOST if speedgear_obtained else 1.0  # 150% 더 빠른 방향 전환
        # 빠른 방향 전환 감속
        if keys[pygame.K_LEFT] and current_speed > 0:
            current_speed -= INSTANT_STOP_DECELERATION * direction_change_boost
        elif keys[pygame.K_RIGHT] and current_speed < 0:
            current_speed += INSTANT_STOP_DECELERATION * direction_change_boost
    # 무중력벨트가 있으면 모든 감속 로직 완전 무시 (속도 유지)
    # 감전 상태일 때도 모든 감속 로직 무시
    # 위치 적용 (감전 상태가 아닐 때만)
    if not player_stunned:
        PLAYER.x += current_speed
        # 패들 크기 변화를 고려한 X 좌표 제한
        actual_paddle_width = int(PADDLE_WIDTH * long_boost_scale * (synergy_paddle_width_boost if gravity_speed_synergy else 1.0))
        PLAYER.x = max(0, min(WIDTH - actual_paddle_width, PLAYER.x))
    # 무중력벨트 + 스피드기어 시너지 효과 적용
    if gravity_speed_synergy:
        PLAYER.width = int(PADDLE_WIDTH * synergy_paddle_width_boost * long_boost_scale)  # 시너지 + 거대화포션
    else:
        PLAYER.width = int(PADDLE_WIDTH * long_boost_scale)  # 거대화포션 효과 적용
    # (퍼펙트 타이밍 윈도우 감지 로직은 메인 루프로 이동)
    # 공 충돌 처리 - Aipill 활성화 시에는 모든 방향에서 감지, 비활성화 시에는 측면 충돌도 감지
    # 패들 끝부분 충돌을 위해 Y속도 조건 완화 - 공이 매우 빠르게 위로 가지 않는 한 모두 감지
    # 서브 대기 중에는 충돌 체크하지 않음
    global player_collision_handled, player_collision_cooldown, player_sound_cooldown, last_hit_by, mega_smashing_active, mega_smashing_meteor_trail, mega_smashing_ghosts, mega_smashing_ghost_scatter
    # Y속도와 관계없이 충돌 감지 (고스트샷 등 특수 상황 대응)
    if BALL.colliderect(PLAYER) and not is_waiting_for_serve:
        # 디버그: 충돌 위치 정보
        collision_x = BALL.centerx - PLAYER.centerx
        collision_side = "LEFT" if collision_x < 0 else "RIGHT"
        edge_distance = abs(collision_x) - (PADDLE_WIDTH / 2)
        print(f"🎯 handle_player 충돌! 위치: {collision_side}, 중심거리: {collision_x:.1f}, 가장자리거리: {edge_distance:.1f}, Y속도: {ball_vel[1]:.1f}")
        # 💥 고스트샷 종료 (플레이어 패들에 돌아왔을 때)
        # 고스트샷 첫 2초 동안은 패들 충돌을 무시하고 계속 진행
        if mega_smashing_active:
            elapsed_time = (pygame.time.get_ticks() - mega_smashing_start_time) / 1000
            if elapsed_time > 2.0:  # 2초 이후에만 고스트샷 종료
                mega_smashing_active = False
                mega_smashing_bonus_applied = False
                mega_smashing_meteor_trail.clear()
                mega_smashing_ghosts.clear()  # 귀신들 제거
                mega_smashing_ghost_scatter = False  # 흩어짐 상태 리셋
                # 🔧 고스트샷 종료 시 토큰 충전 타이머 초기화
                base_charges = 1
                holder_bonus = 1 if dashholder_obtained else 0
                amplification_bonus = academy.get_skill_bonus("dash_amplification")
                max_charges = int(base_charges + holder_bonus + amplification_bonus)
                print(f"[DEBUG] 고스트샷 종료 - 현재 토큰: {rolling_charges}/{max_charges}, 타이머: {rolling_charge_timer}")
                # 토큰이 부족한 경우 무조건 충전 타이머 설정
                if rolling_charges < max_charges:
                    # 경량화 스킬 효과 적용
                    lightweight_bonus = academy.get_skill_bonus("dash_lightweight")
                    charge_time_reduction = lightweight_bonus  # 5% per level
                    base_charge_time = 90  # 1.5초
                    rolling_charge_timer = int(base_charge_time * (1 - charge_time_reduction))
                    print(f"💥 고스트샷 종료! 토큰 충전 시작 (타이머: {rolling_charge_timer}프레임 = {rolling_charge_timer/60:.1f}초)")
                    print(f"[DEBUG] 충전 타이머 강제 설정 완료: {rolling_charge_timer}")
                else:
                    print(f"💥 고스트샷 종료! (토큰 이미 최대: {rolling_charges}/{max_charges})")
            else:
                print(f"🌟 고스트샷 궤적 진행 중 ({elapsed_time:.1f}/2.0초) - 패들 충돌 무시")
        # 충돌 처리 플래그 설정
        player_collision_handled = True
        last_hit_by = "player"  # 플레이어가 공을 쳤음을 기록
        # 🚀 가속화 스킬: 대쉬 상태에서 공과 충돌 시 순간 공속도 증가
        if rolling_active:
            acceleration_bonus = academy.get_skill_bonus("dash_acceleration")
            if acceleration_bonus > 0:
                # 🎯 현재 공속도 저장 (원래 속도 기록)
                original_ball_speed = [ball_vel[0], ball_vel[1]]
                global acceleration_original_speed, acceleration_active
                acceleration_original_speed = original_ball_speed[:]
                acceleration_active = True
                # 🚀 10% × 레벨만큼 순간 속도 증가
                speed_multiplier = 1 + acceleration_bonus  # acceleration_bonus가 이미 0.1 × level
                ball_vel[0] *= speed_multiplier
                ball_vel[1] *= speed_multiplier
                print(f"🔄 원래 속도 저장: {acceleration_original_speed}")
        drive_activated = calculate_bounce(PLAYER)
        print(f"🔍 DEBUG: calculate_bounce 반환값 - drive_activated: {drive_activated}")  # 🔍 디버그
        # 드라이브 발동 시 게이지 충전 차단 플래그 설정
        global drive_just_activated
        if drive_activated:
            drive_just_activated = True
            print("🎯 드라이브 발동! 게이지 충전 차단 플래그 설정")
        # 사운드 쿨다운이 없을 때만 사운드 재생
        if player_sound_cooldown <= 0:
            SOUND_PADDLE.play()
            player_sound_cooldown = 20  # 약 0.33초 쿨다운
            print(f"🔊 handle_player에서 사운드 재생 (쿨다운 설정: 20)")
        else:
            print(f"🔇 사운드 쿨다운 중 (남은 쿨다운: {player_sound_cooldown})")
        # 🏆 플레이어 히트 기록
        is_perfect = perfect_timing_active and perfect_direction is not None
        record_player_hit(is_perfect_timing=is_perfect, is_power_smash=drive_activated)
        # 🏆 대쉬 성공 체크 (최근 2초 내에 대쉬했다면 성공으로 기록)
        current_time = pygame.time.get_ticks()
        if recent_dash_time > 0 and (current_time - recent_dash_time) <= recent_dash_success_window:
            # 대쉬 후 성공적으로 공을 쳤으므로 성공으로 업데이트
            record_dash_usage(success=True)
            # 🏆 대쉬 활용 능력 상세 분석
            ball_distance = abs(BALL.centery - PLAYER.centery)
            ball_speed = math.hypot(ball_vel[0], ball_vel[1])
            # 생명 구조 상황 판정 (위험한 상황에서 대쉬로 공을 맞춘 경우)
            if ball_distance > 100 or ball_speed > 10:  # 멀거나 빠른 공
                record_dash_life_save()
                print("🏆 대쉬로 생명 구조!")
            # 대쉬 방어 구조 판정 (불가능한 영역에서 가드) - 신규
            paddle_width = PLAYER.width
            ball_x_distance = abs(BALL.centerx - PLAYER.centerx)
            if ball_x_distance > paddle_width * 1.5:  # 패들 범위 밖에서 가드
                record_dash_defensive_save()
                print("🏆 대쉬로 불가능한 영역 가드!")
            # 공격적 대쉬 성공 (승리 기여) 판정
            if ball_speed > 12:  # 강력한 반격
                record_dash_victory()
                print("🏆 대쉬로 강력한 반격!")
            # 대쉬 클러치 승리 판정 (상대가 못막고 바로 승리) - 신규  
            if ball_speed > 15 and ball_vel[1] < 0:  # 매우 빠른 공을 위로 반격
                record_dash_clutch_victory()
                print("🏆 대쉬 클러치 승리!")
            # 공속도 적응 점수 기록 - 신규
            record_speed_adaptation(ball_speed)
            recent_dash_time = 0  # 성공 기록 후 초기화
        # 🏆 가드 능력 기록 (공과의 거리, 공 속도)
        ball_distance = abs(BALL.centery - PLAYER.centery)
        ball_speed = math.hypot(ball_vel[0], ball_vel[1])
        is_close_call = ball_distance < 20  # 매우 가까운 거리
        record_guard_action(ball_distance, ball_speed, is_close_call)
        # 🏆 공속도 적응 점수 기록 (일반 가드에서도)
        record_speed_adaptation(ball_speed)
        # 🎯 타격 이펙트 생성 (공 속도에 따라 강도 조절)
        create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=True)
        global hit_animation_active, hit_animation_timer
        hit_animation_active = True
        hit_animation_timer = HIT_ANIMATION_DURATION
        # 무중력벨트 + 스피드기어 시너지 시 별가루 파티클 생성
        if gravity_speed_synergy:
            print(f"별가루 파티클 생성! 시너지 상태: {gravity_speed_synergy}")
            effects_manager.spawn_star_particles(PLAYER.centerx, PLAYER.centery, count=3)
        else:
            print(f"별가루 파티클 생성 안됨! 시너지 상태: {gravity_speed_synergy}")
        # 🔹 게이지 처리 - Aipill 활성화 시에는 게이지 감소만, 비활성화 시에는 게이지 증가
        print(f"공 충돌 시 aipill_active: {aipill_active}")  # 디버깅용
        # Aipill 활성화 시 게이지 감소만
        if aipill_active:
            print(f"Aipill 활성화 상태 - 공 충돌 감지! 현재 게이지: {special_gauge}")  # 디버깅용
            # Aipill 활성화 시 공이 맞을 때마다 게이지 90 감소만
            old_gauge = special_gauge
            special_gauge = max(0, special_gauge - 90)
            print(f"Aipill 활성화 중 - 게이지 감소: {old_gauge} → {special_gauge}")  # 디버깅용
            # 🔹 게이지 감소 시 special_ready 상태 업데이트
            if special_gauge < 350:  # 파워스매시 발동 조건
                special_ready = False
            # 게이지가 0이 되면 aipill 효과 종료
            if special_gauge <= 0:
                aipill_active = False
                special_gauge = 0
                print("Aipill 효과 종료")  # 디버깅용
            # Aipill 활성화 시에는 절대 게이지 증가 금지
            print("Aipill 활성화로 인한 게이지 감소 완료")  # 디버깅용
            return
        # 🎯 게이지 충전을 handle_player에서만 처리 (handle_ball 충돌 시에는 충전하지 않음)
        # 대쉬 중이거나 대쉬 직후, 드라이브 발동 시에는 게이지 충전 차단
        if not aipill_active and not special_active and not rolling_active and player_collision_cooldown <= 0 and not drive_activated:
            # 스킬 효과 적용: 게이지 충전 증가
            base_gauge_gain = 80  # 사용자 요청에 따라 80으로 설정
            skill_gauge_boost = skill.apply_gauge_boost(0)
            total_gauge_gain = base_gauge_gain + skill_gauge_boost
            print(f"🔍 DEBUG: ✅ handle_player에서 게이지 충전 ({total_gauge_gain})")
            special_gauge += total_gauge_gain
            # 🔧 동적 최대치 제한 적용
            current_max = get_max_gauge()
            if special_gauge > current_max:
                special_gauge = current_max
            # 🔧 필살기 준비 상태 업데이트 (400 이상일 때)
            if special_gauge >= 350:  # 파워스매시 발동 조건
                special_ready = True
            # 충돌 쿨다운 설정하여 중복 충전 방지
            player_collision_cooldown = 15
        elif rolling_active:
            print(f"🔍 DEBUG: ❌ 대쉬 중이므로 handle_player 게이지 충전 차단됨!")
        elif player_collision_cooldown > 0:
            print(f"🔍 DEBUG: ❌ 충돌 쿨다운 중이므로 게이지 충전 차단됨! (남은 쿨다운: {player_collision_cooldown})")
        elif drive_activated:
            print(f"🔍 DEBUG: ❌ 드라이브 발동으로 게이지 충전 차단됨!")
        else:
            print(f"🔍 DEBUG: ❌ handle_player에서 게이지 충전 차단됨")
        # 🔹 파워스매싱은 이제 퍼펙트 타이밍 윈도우에서 처리됨 (드라이브와 동일한 타이밍)
        # handle_player에서는 제거하고 메인 루프의 퍼펙트 타이밍 윈도우에서 처리
# 채찍질 특수기술 관련 변수
whip_active = False
whip_duration = 260  # 260프레임 (약 4.3초)으로 증가
whip_timer = 0
whip_hit_by_player = False  # 플레이어가 공 맞췄는지 추적
whip_original_ball_speed = [0, 0]  # 상모돌리기 발동 전 공 속도 저장
# 풍선 스킬 관련 변수
balloon_active = False
balloon_timer = 0
balloon_duration = 120  # 2초
balloons = []  # 풍선 리스트 [{"x": int, "y": int, "radius": int, "color": tuple}]
balloon_used_this_round = False  # 이번 라운드에 풍선 스킬 사용 여부
medal_score = 0
current_stage = 1
# 🏗️ 전역 변수를 GameState와 동기화
game_state.player_score = 0
game_state.ai_score = 0
game_state.round_wins = round_wins
game_state.round_losses = round_losses
game_state.current_stage = current_stage
game_state.medal_score = medal_score
game_state.special_gauge = special_gauge
game_state.special_ready = special_ready
game_state.deuce_mode = deuce_mode
game_state.deuce_wins = deuce_wins
game_state.deuce_losses = deuce_losses
# 스테이지 1 벽 충돌 테두리 깜빡임 효과
border_flash_active = False  # 테두리 깜빡임 활성화 상태
border_flash_timer = 0  # 깜빡임 타이머
border_flash_duration = 20  # 깜빡임 지속 시간 (프레임) - 증가
border_flash_color = (255, 255, 0)  # 깜빡임 색상 (노란색) - 더 눈에 띄게
border_flash_thickness = 10  # 테두리 두께 - 증가
# 스테이지 2 정글 테두리 효과
stage2_border_active = False  # 스테이지 2 테두리 활성화 상태
stage2_border_timer = 0  # 테두리 애니메이션 타이머
stage2_border_flash_timer = 0  # 벽 충돌 시 깜빡임 타이머
stage2_border_flash_duration = 25  # 깜빡임 지속 시간
stage2_vines = []  # 덩굴 위치 리스트
stage2_leaves = []  # 나뭇잎 위치 리스트
# 체력형 보스 시스템 (스테이지 6, 11, 16, 21)
boss_health_stages = [6, 11, 16, 21]  # 체력형 보스가 등장하는 스테이지
boss_max_health = 15  # 보스 최대 체력
boss_current_health = 15  # 보스 현재 체력
boss_health_bar_width = 200  # 체력바 너비
boss_health_bar_height = 8  # 체력바 높이 (더 얇게)
boss_displayed_health = 15  # 스무스하게 표시되는 체력 (감소 애니메이션용)
boss_damage_preview_health = 15  # 데미지 프리뷰용 체력
boss_damage_values = {
    "basic": 1,     # 기본 공격 데미지
    "drive": 2,     # 드라이브 데미지
    "power": 3      # 파워 스매싱 데미지
}
boss_fire_hit_count = 0  # 화염탄 맞은 횟수 (3회마다 체력 1 감소)
boss_fire_hit_timer = 0  # 화염 타격 쿨다운 타이머 (중복 방지)
stage_medal_rewards = {
    1: 10,
    2: 20,
    3: 40,
    4: 80,
    5: 100,
    6: 130,
    7: 180,
    8: 200,
    9: 250,
    10: 300,
    11: 350
}
session_medal_earned = 0  # main 함수 외부에 선언
final_wave_direction = [0, 0]  # 공의 마지막 이동 방향 (X, Y)
def store_active_item(item_data):
    global active_item_slot, selected_item_index, aipill_active, last_item_use_time, long_boost_active
    if active_item_slot is None:
        active_item_slot = []  # 혹시 None이면 초기화
    # Aipill 활성화 시에는 아이템 획득 불가
    if aipill_active:
        return
    # long_boost가 이미 활성화되어 있으면 long_boost 아이템 획득 불가
    if item_data["name"] == "long_boost" and long_boost_active:
        print("롱 부스트가 이미 활성화되어 있어 아이템을 획득할 수 없습니다!")
        return
    # 패시브 아이템들은 엑티브 슬롯에 추가하지 않음
    if item_data["name"] in ["speedboots", "speedgear", "battery", "slot_add", "revival", "master", "cooltime", "chargebag", "spikeboots", "dashgear", "bulkup", "sensor", "dashholder", "gravitybelt"]:
        return
    if len(active_item_slot) < MAX_ITEM_SLOTS:
        # 아이콘이 없으면 get_item_icon 함수로 동적 생성
        if item_data.get("icon") is None:
            item_data["icon"] = get_item_icon(item_data["name"])
        # 아이템에 last_use 필드 추가 (전역 쿨타임 적용)
        current_time = pygame.time.get_ticks()
        item_data["last_use"] = last_item_use_time  # 전역 쿨타임 적용
        active_item_slot.append(item_data)
        selected_item_index = len(active_item_slot) - 1  # 자동 선택
        # 아이템 획득 효과 표시 (아이템 위치에서)
        show_item_obtained_effect(item_data, item_data.get("x"), item_data.get("y"))
# bosspong.py
def store_passive_item(item_data):
    global MAX_ITEM_SLOTS, passive_item_list, speedboots_obtained, speedgear_obtained, items, aipill_active, battery_obtained, revival_obtained, master_obtained, cooltime_obtained, chargebag_obtained, spikeboots_obtained, dashgear_obtained, bulkup_obtained
    global danger_sensor_obtained, sensor_obtained, danger_sensor_enabled, sensor_enabled  # 센서 관련 변수들
    global dashholder_obtained  # 대쉬홀더 관련 변수
    global gravitybelt_obtained, gravity_speed_synergy  # 무중력벨트 관련 변수들
    print(f"store_passive_item 호출됨: {item_data['name']}")
    # Aipill 활성화 시에는 아이템 획득 불가
    if aipill_active:
        print("Aipill 활성화로 인해 아이템 획득이 차단되었습니다.")
        return
    if passive_item_list is None:
        passive_item_list = []
    if item_data["name"] == "slot_add":
        # 최대 슬롯 4개 제한
        MAX_ITEM_SLOTS = min(4, MAX_ITEM_SLOTS + 1)
        print("슬롯 +1 증가!")
        # 획득 개수 카운트 증가
        items.slot_add_obtained += 1
    elif item_data["name"] == "speedboots":
        # 스피드부츠 영구 효과 적용
        if not speedboots_obtained:
            speedboots_obtained = True
            items.speedboots_obtained = True  # items.py의 변수도 업데이트
            # 🏗️ 새 시스템으로도 업데이트
            handle_item_collection("speedboots")
            print("스피드부츠 획득! 영구적으로 이동속도 15% 증가!")
    elif item_data["name"] == "speedgear":
        # 스피드기어 영구 효과 적용
        if not speedgear_obtained:
            speedgear_obtained = True
            items.speedgear_obtained = True  # items.py의 변수도 업데이트
            # 🏗️ 새 시스템으로도 업데이트
            handle_item_collection("speedgear")
            print("스피드기어 획득! 영구적으로 방향 전환 속도 150% 증가!")
    elif item_data["name"] == "battery":
        # 배터리 영구 효과 적용
        print(f"배터리 아이템 처리 중... 현재 battery_obtained: {battery_obtained}")
        if not battery_obtained:
            battery_obtained = True
            items.battery_obtained = True  # items.py의 변수도 업데이트
            print("배터리 획득! 다음 스테이지로 넘어가도 게이지가 유지됩니다!")
        else:
            print("이미 배터리를 획득했으므로 효과가 적용되지 않습니다.")
    elif item_data["name"] == "revival":
        # 부활 아이템 획득
        if not revival_obtained:
            revival_obtained = True
            items.revival_obtained = True  # items.py의 변수도 업데이트
            print("부활 아이템 획득! 패배 시 한 번 기회를 드립니다!")
        else:
            print("이미 부활 아이템을 획득했으므로 효과가 적용되지 않습니다.")
    elif item_data["name"] == "master":
        # 장인 아이템 획득
        if not master_obtained:
            master_obtained = True
            items.master_obtained = True  # items.py의 변수도 업데이트
            print("장인의 망치 아이템 획득! 벽돌의 길이가 30% 늘어나고 제작 쿨타임이 0.8초로 늘어나며, 아이템 쿨타임이 10% 감소합니다!")
        else:
            print("이미 장인의 망치 아이템을 획득했으므로 효과가 적용되지 않습니다.")
    elif item_data["name"] == "cooltime":
        # 쿨타임 아이템 획득
        if not cooltime_obtained:
            cooltime_obtained = True
            items.cooltime_obtained = True  # items.py의 변수도 업데이트
            print("쿨링볼 아이템 획득! 아이템 재사용 쿨타임이 30% 감소합니다!")
        else:
            print("이미 쿨링볼 아이템을 획득했으므로 효과가 적용되지 않습니다.")
    elif item_data["name"] == "chargebag":
        # 충전가방 아이템 획득
        if not chargebag_obtained:
            chargebag_obtained = True
            items.chargebag_obtained = True  # items.py의 변수도 업데이트
            print("충전가방 획득! 공이 벽에 닿을 때마다 플레이어 패들 충전량의 20%가 충전됩니다!")
        else:
            print("이미 충전가방을 획득했으므로 효과가 적용되지 않습니다.")
    elif item_data["name"] == "spikeboots":
        # 스파이크부츠 아이템 획득
        if not spikeboots_obtained:
            spikeboots_obtained = True
            items.spikeboots_obtained = True  # items.py의 변수도 업데이트
            # 대쉬 매니저에 보너스 업데이트
            if dash is not None:
                dash.update_bonuses(dashholder_obtained, dashgear_obtained, True)
            print("스파이크부츠 획득! 대쉬 후 제어불능 시간이 15% 감소하고 쿨타임이 20% 감소합니다!")
        else:
            print("이미 스파이크부츠를 획득했으므로 효과가 적용되지 않습니다.")
    elif item_data["name"] == "dashgear":
        # 대쉬기어 아이템 획득
        if not dashgear_obtained:
            dashgear_obtained = True
            items.dashgear_obtained = True  # items.py의 변수도 업데이트
            # 대쉬 매니저에 보너스 업데이트
            if dash is not None:
                dash.update_bonuses(dashholder_obtained, True, spikeboots_obtained)
            print("대쉬기어 획득! 대쉬 거리가 10% 증가하고 게이지 소모가 20% 감소합니다!")
        else:
            print("이미 대쉬기어를 획득했으므로 효과가 적용되지 않습니다.")
    elif item_data["name"] == "bulkup":
        # 벌크업 아이템 획득
        if not bulkup_obtained:
            bulkup_obtained = True
            items.bulkup_obtained = True  # items.py의 변수도 업데이트
            # 패들 크기를 영구적으로 10% 증가
            global PADDLE_WIDTH, PADDLE_HEIGHT
            PADDLE_WIDTH = int(PADDLE_WIDTH * 1.10)
            PADDLE_HEIGHT = int(PADDLE_HEIGHT * 1.10)
            print(f"벌크업 획득! 패들 크기가 영구적으로 10% 증가! (현재 크기: {PADDLE_WIDTH}x{PADDLE_HEIGHT})")
        else:
            print("이미 벌크업을 획득했으므로 효과가 적용되지 않습니다.")
    elif item_data["name"] == "sensor":
        # 위험감지센서 아이템 획득
        if not danger_sensor_obtained:
            danger_sensor_obtained = True
            sensor_obtained = True  # 호환성을 위해 두 변수 모두 설정
            danger_sensor_enabled = True  # 기본적으로 활성화 상태로 설정
            sensor_enabled = True  # 호환성을 위해 두 변수 모두 설정
            items.sensor_obtained = True  # items.py의 변수도 업데이트
            print("위험감지센서 획득! 때때로 위험한 상황에 직면하면 자동으로 대쉬를 시전합니다!")
        else:
            print("이미 위험감지센서를 획득했으므로 효과가 적용되지 않습니다.")
    elif item_data["name"] == "dashholder":
        # 대쉬홀더 아이템 획득
        if not dashholder_obtained:
            global rolling_charges
            dashholder_obtained = True
            items.dashholder_obtained = True  # items.py의 변수도 업데이트
            # 🔧 안전한 토큰 추가 (최대치 계산 후 적용)
            base_charges = 1  # 기본 1개
            holder_bonus = 1  # 대쉬홀더 +1개 (방금 획득)
            amplification_bonus = academy.get_skill_bonus("dash_amplification")
            max_charges = int(base_charges + holder_bonus + amplification_bonus)
            rolling_charges = min(rolling_charges + 1, max_charges)
            # 대쉬 매니저에 보너스 업데이트
            if dash is not None:
                dash.update_bonuses(True, dashgear_obtained, spikeboots_obtained)
            print(f"대쉬홀더 획득! 대쉬 토큰이 증가하여 연속 대쉬가 가능합니다! (현재: {rolling_charges}/{max_charges})")
        else:
            print("이미 대쉬홀더를 획득했으므로 효과가 적용되지 않습니다.")
    elif item_data["name"] == "gravitybelt":
        # 무중력벨트 아이템 획득
        if not gravitybelt_obtained:
            gravitybelt_obtained = True
            items.gravitybelt_obtained = True  # items.py의 변수도 업데이트
            print("무중력벨트 획득! 이동 시 감속이 없고 즉각적인 방향 전환이 가능합니다!")
            # 무중력벨트 + 스피드기어 시너지 효과 확인
            if speedgear_obtained:
                gravity_speed_synergy = True
                print("무중력벨트 + 스피드기어 시너지 활성화! 패들 크기가 60% 증가합니다!")
        else:
            print("이미 무중력벨트를 획득했으므로 효과가 적용되지 않습니다.")
    passive_item_list.append(item_data)
    # 아이템 획득 효과 표시 (아이템 위치에서)
    show_item_obtained_effect(item_data, item_data.get("x"), item_data.get("y"))
def activate_emotional_overdrive():
    global emotional_overdrive_active, emotional_overdrive_timer, overdrive_flash_timer, overdrive_trails
    emotional_overdrive_active = True
    emotional_overdrive_timer = 300  # 약 5초간 지속 (60fps 기준)
    overdrive_flash_timer = 30  # 0.5초마다 반짝임
    overdrive_trails.clear()
def handle_emotional_overdrive():
    global emotional_overdrive_active, emotional_overdrive_timer, overdrive_flash_timer, overdrive_trails, ball_vel
    global psycho_bg_timer  # 💡 배경 깜빡임 타이머
    if not emotional_overdrive_active:
        return
    emotional_overdrive_timer -= 1
    if emotional_overdrive_timer <= 0:
        emotional_overdrive_active = False
        overdrive_trails.clear()
        psycho_bg_timer = 0  # 🔥 배경 깜빡임 타이머 초기화
        return
    # 1. 공 곡선 이동
    time_now = pygame.time.get_ticks()
    curve = math.sin(time_now / 80) * 3
    ball_vel[0] += curve * random.uniform(0.5, 1.2)
    # 2. 공 순간이동 (랜덤 확률)
    if random.random() < 0.01:
        BALL.centerx = random.randint(50, WIDTH - 50)
        BALL.centery = random.randint(150, HEIGHT - 150)
    # 3. 보스 잔상 추가
    overdrive_trails.append((BOSS.centerx, BOSS.centery, 200))
    overdrive_trails = [(x, y, a - 10) for x, y, a in overdrive_trails if a > 10][:15]
    # 4. 보스 반짝임 타이머
    overdrive_flash_timer -= 1
    if overdrive_flash_timer <= 0:
        overdrive_flash_timer = 30
    # 5. 배경 깜빡임 타이머 증가 (draw_field에서 사용됨)
    psycho_bg_timer += 1
def handle_aipill():
    """AI 필 효과 처리 함수 - 게이지 기반 지속시간"""
    global aipill_active
    # 게이지 기반으로 처리되므로 타이머는 사용하지 않음
    # 공 충돌 시 게이지 감소 및 종료 처리는 handle_player에서 처리됨
    pass
def is_player_in_smoke():
    """플레이어가 연막 안에 있는지 확인하는 함수"""
    global smoke_zones, PLAYER
    for smoke_zone in smoke_zones:
        if smoke_zone["opacity"] > 50:  # 연막이 충분히 진할 때만
            # 플레이어와 연막 중심 사이의 거리 계산
            player_distance = math.sqrt((PLAYER.centerx - smoke_zone["x"])**2 + 
                                      (PLAYER.centery - smoke_zone["y"])**2)
            if player_distance <= smoke_zone["radius"]:
                return True
    return False
def handle_wall():
    """벽돌 설치 및 관리 함수"""
    global walls, wall_installing, wall_install_timer, wall_install_gauge_visible, boss_stunned_timer, boss_knockback_vel, explosion_zones, grenades
    global boss_confused_timer, flares, flare_zones, last_hit_by, boss_current_health, boss_max_health  # 💪 체력형 보스 체력 변수
    global boss_fire_hit_count, boss_fire_hit_timer  # 💪 보스 화염 타격 카운터
    # 설치 중인 경우
    if wall_installing:
        wall_install_timer -= 1
        if wall_install_timer <= 0:
            wall_installing = False
            wall_install_gauge_visible = False  # 설치 게이지 숨기기
            print("벽돌 설치 완료! 이제 움직일 수 있습니다.")
    # 파괴된 벽돌들 제거
    walls = [wall for wall in walls if wall["hit_count"] < 2]
    # 수류탄 업데이트
    global grenade_shake_timer, boss_stunned_timer, boss_knockback_vel, explosion_zones
    for grenade in grenades[:]:
        # 중력 적용
        if grenade["gravity"] > 0:
            grenade["vel_y"] += grenade["gravity"]
        grenade["x"] += grenade["vel_x"]
        grenade["y"] += grenade["vel_y"]
        grenade["rotation"] += 15  # 회전 (화염병보다 빠름)
        # 목표 지점에 도달했는지 체크
        if abs(grenade["x"] - grenade["target_x"]) < 30 and abs(grenade["y"] - grenade["target_y"]) < 30:
            # 폭발 효과 - 화염병보다 넓은 범위
            explosion_zone = {
                "x": grenade["x"],
                "y": grenade["y"],
                "radius": 120,  # 폭발 반경 (화염병 150x60보다 넓은 원형)
                "duration": 15,  # 폭발 효과 지속 시간 (짧음)
                "active": True
            }
            # 화면 흔들림 효과 시작 (폭발하면 무조건 흔들림)
            grenade_shake_timer = 40  # 40프레임 동안 흔들림 (2배로 증가)
            print(f"💥 수류탄 폭발! 화면 흔들림 시작: {grenade_shake_timer}")
            # 보스가 폭발 범위 내에 있는지 체크
            boss_center_x = BOSS.centerx
            boss_center_y = BOSS.centery
            distance = math.sqrt((boss_center_x - grenade["x"])**2 + (boss_center_y - grenade["y"])**2)
            if distance < explosion_zone["radius"]:
                # 보스 스턴 및 넉백 효과
                boss_stunned_timer = 84  # 1.4초 스턴
                # 화염병처럼 넉백 효과 (튕겨나가는 느낌)
                knockback_power = 40  # 넉백 강도 조정
                if grenade["x"] < WIDTH / 2:
                    # 수류탄이 왼쪽에서 터지면 보스를 오른쪽으로 넉백
                    boss_knockback_vel = knockback_power
                else:
                    # 수류탄이 오른쪽에서 터지면 보스를 왼쪽으로 넉백
                    boss_knockback_vel = -knockback_power
                # 💪 체력형 보스 수류탄 데미지 적용
                if current_stage in boss_health_stages:
                    boss_current_health = max(0, boss_current_health - 3)  # 수류탄 데미지 3
                    print(f"💥 수류탄 폭발! 보스 체력 -{3} (현재: {boss_current_health}/{boss_max_health})")
                else:
                    print(f"💥 수류탄 폭발! 보스 스턴 및 넉백")
            # 현실감 있는 수류탄 폭발 효과
            # 1. 폭발 파편 효과 (다양한 크기와 속도)
            for _ in range(50):  # 파편 수 증가
                angle = random.uniform(0, 360)
                speed = random.uniform(5.0, 15.0)  # 더 빠른 파편
                vx = math.cos(math.radians(angle)) * speed
                vy = math.sin(math.radians(angle)) * speed
                tear_particles.append([
                    grenade["x"] + random.uniform(-10, 10),
                    grenade["y"] + random.uniform(-10, 10),
                    vx, vy,
                    255,  # alpha
                    random.randint(3, 8)  # 다양한 크기의 파편
                ])
            # 2. 연기 효과 (회색 파티클)
            for _ in range(40):
                angle = random.uniform(0, 360)
                speed = random.uniform(1.0, 4.0)  # 느린 연기
                vx = math.cos(math.radians(angle)) * speed
                vy = math.sin(math.radians(angle)) * speed - 0.5  # 위로 올라가는 연기
                tear_particles.append([
                    grenade["x"] + random.uniform(-30, 30),
                    grenade["y"] + random.uniform(-30, 30),
                    vx, vy,
                    180,  # alpha
                    random.randint(15, 25)  # 큰 연기 입자
                ])
            # 3. 폭발 섬광 효과 (노란색/주황색 불꽃)
            for _ in range(20):
                angle = random.uniform(0, 360)
                speed = random.uniform(8.0, 12.0)
                vx = math.cos(math.radians(angle)) * speed
                vy = math.sin(math.radians(angle)) * speed
                tear_particles.append([
                    grenade["x"],
                    grenade["y"],
                    vx, vy,
                    255,  # alpha
                    random.randint(10, 15)  # 섬광 크기
                ])
            explosion_zones.append(explosion_zone)
            grenades.remove(grenade)
            # 폭발 효과음
            try:
                SOUND_WALL.play()
            except:
                pass
            print(f"💣 수류탄 폭발! 위치: X={explosion_zone['x']:.1f}, Y={explosion_zone['y']:.1f}, 반경: {explosion_zone['radius']}")
    # 폭발 지역 업데이트 (지속시간 감소)
    explosion_zones = [zone for zone in explosion_zones if zone["duration"] > 0]
    for zone in explosion_zones:
        zone["duration"] -= 1
    # 연막탄 업데이트
    for smoke_grenade in smoke_grenades[:]:
        if not smoke_grenade["arrived"]:
            # 포물선 궤적으로 비행
            smoke_grenade["vel_y"] += smoke_grenade["gravity"]  # 중력 적용
            smoke_grenade["x"] += smoke_grenade["vel_x"]
            smoke_grenade["y"] += smoke_grenade["vel_y"]
            smoke_grenade["rotation"] += 15  # 더 빠른 회전
            # 궤적 추가 (흔적 효과)
            if len(smoke_grenade["trail"]) > 10:
                smoke_grenade["trail"].pop(0)
            smoke_grenade["trail"].append((smoke_grenade["x"], smoke_grenade["y"]))
            # 목표 지점 도달 체크 (바닥에 닿으면)
            if smoke_grenade["y"] >= smoke_grenade["target_y"]:
                smoke_grenade["arrived"] = True
                smoke_grenade["y"] = smoke_grenade["target_y"]
                print(f"💨 연막탄 도착! 1초 후 연막 분출")
                # 착지 효과음
                try:
                    SOUND_PADDLE.play()
                except:
                    pass
        elif smoke_grenade["timer"] < 60:  # 1초 대기
            smoke_grenade["timer"] += 1
            # 1초 후 연막 생성
            if smoke_grenade["timer"] >= 60:
                # 연막 지역 생성
                smoke_zone = {
                    "x": smoke_grenade["x"],
                    "y": smoke_grenade["target_y"],
                    "radius": 0,  # 초기 반경 0에서 시작
                    "max_radius": 180,  # 최대 반경 (가로로 120% 확대)
                    "duration": 420,  # 7초 지속 (6초 + 1초 페이드아웃)
                    "particles": [],  # 연막 파티클들
                    "opacity": 0,  # 초기 투명도
                    "expansion_rate": 5  # 확장 속도
                }
                # 초기 연막 파티클 생성 (중앙에서 시작)
                for i in range(30):
                    angle = random.uniform(0, 2 * math.pi)
                    dist = random.uniform(0, 10)
                    particle = {
                        "x": smoke_zone["x"] + math.cos(angle) * dist,
                        "y": smoke_zone["y"] + math.sin(angle) * dist,
                        "size": random.uniform(15, 30),
                        "vel_x": math.cos(angle) * random.uniform(0.5, 1.5),  # 바깥쪽으로 퍼짐
                        "vel_y": random.uniform(-0.5, -0.2),
                        "lifetime": random.uniform(80, 150)
                    }
                    smoke_zone["particles"].append(particle)
                smoke_zones.append(smoke_zone)
                smoke_grenades.remove(smoke_grenade)
                # 연막 분출 효과음
                try:
                    SOUND_WALL.play()
                except:
                    pass
                print(f"💨 연막 생성! 6초간 지속됩니다.")
    # 연막 지역 업데이트
    for smoke_zone in smoke_zones[:]:
        smoke_zone["duration"] -= 1
        # 연막 반경 점진적 확대
        if smoke_zone["radius"] < smoke_zone["max_radius"]:
            smoke_zone["radius"] = min(smoke_zone["max_radius"], 
                                      smoke_zone["radius"] + smoke_zone["expansion_rate"])
        # 투명도 조절 (서서히 나타났다가 사라짐)
        if smoke_zone["duration"] > 360:  # 처음 1초: 페이드인
            smoke_zone["opacity"] = min(150, smoke_zone["opacity"] + 5)
        elif smoke_zone["duration"] > 60:  # 중간 5초: 유지
            smoke_zone["opacity"] = 150
        else:  # 마지막 1초: 페이드아웃
            smoke_zone["opacity"] = max(0, smoke_zone["opacity"] - 3)
        # 파티클 추가 생성 (지속적인 연기 효과)
        if smoke_zone["duration"] > 60 and len(smoke_zone["particles"]) < 40:
            if random.random() < 0.4:  # 40% 확률로 새 파티클
                angle = random.uniform(0, 2 * math.pi)
                dist = random.uniform(0, smoke_zone["radius"] * 0.7)
                particle = {
                    "x": smoke_zone["x"] + math.cos(angle) * dist,
                    "y": smoke_zone["y"] + math.sin(angle) * dist,
                    "size": random.uniform(25, 45),
                    "vel_x": math.cos(angle) * random.uniform(0.2, 0.8),  # 바깥쪽으로
                    "vel_y": random.uniform(-0.2, -0.05),
                    "lifetime": random.uniform(40, 80)
                }
                smoke_zone["particles"].append(particle)
        # 파티클 업데이트
        for particle in smoke_zone["particles"][:]:
            particle["x"] += particle["vel_x"]
            particle["y"] += particle["vel_y"]
            particle["lifetime"] -= 1
            particle["size"] *= 0.99  # 서서히 작아짐
            if particle["lifetime"] <= 0 or particle["size"] < 5:
                smoke_zone["particles"].remove(particle)
        # 공이 연막 안에 있는지 체크
        ball_distance = math.sqrt((BALL.centerx - smoke_zone["x"])**2 + 
                                 (BALL.centery - smoke_zone["y"])**2)
        if ball_distance <= smoke_zone["radius"] and smoke_zone["opacity"] > 50:
            # 보스가 친 공만 연막 효과 적용 (플레이어가 친 공은 무시)
            if last_hit_by == "boss":
                # 연막 안에서는 공 속도가 점진적으로 감소 (매 프레임마다 적용)
                # 현재 속도를 약간씩 감소시킴 (원래 방향은 유지)
                speed_reduction = 0.97  # 매 프레임마다 3% 감속
                ball_vel[0] *= speed_reduction
                ball_vel[1] *= speed_reduction
                # 최소 속도 보장 (완전히 멈추지 않도록)
                min_speed = 2.0
                current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
                if current_speed < min_speed and current_speed > 0:
                    # 속도가 너무 느려지면 최소 속도로 유지
                    speed_factor = min_speed / current_speed
                    ball_vel[0] *= speed_factor
                    ball_vel[1] *= speed_factor
                # 처음 진입 시에만 메시지 출력
                if not hasattr(smoke_zone, "affecting_ball"):
                    smoke_zone["affecting_ball"] = True
                    print(f"💨 보스가 친 공이 연막에 진입! 속도 감소 중...")
            else:
                # 플레이어가 친 공은 연막 효과 무시
                if not hasattr(smoke_zone, "player_ball_ignored"):
                    smoke_zone["player_ball_ignored"] = True
                    print(f"💨 플레이어가 친 공은 연막 효과 무시!")
        else:
            # 연막을 벗어나면 플래그 제거
            if hasattr(smoke_zone, "affecting_ball"):
                del smoke_zone["affecting_ball"]
                print(f"💨 공이 연막을 벗어남")
            if hasattr(smoke_zone, "player_ball_ignored"):
                del smoke_zone["player_ball_ignored"]
        # 지속시간 종료 체크
        if smoke_zone["duration"] <= 0:
            smoke_zones.remove(smoke_zone)
    # 조명탄 업데이트
    for flare in flares[:]:
        if not flare["arrived"]:
            # 아직 날아가는 중이면 이동
            flare["x"] += flare["vel_x"]
            flare["y"] += flare["vel_y"]
            flare["rotation"] += 12  # 회전
            # 목표 지점에 도달했는지 체크 (거리 기반으로 체크)
            dist_to_target = math.sqrt((flare["x"] - flare["target_x"])**2 + 
                                      (flare["y"] - flare["target_y"])**2)
            if dist_to_target < 10:  # 목표 지점에 충분히 가까워졌을 때
                flare["arrived"] = True
                flare["x"] = flare["target_x"]  # 정확한 위치에 고정
                flare["y"] = flare["target_y"]
                print(f"💡 조명탄 도착! 1.5초 후 폭발합니다.")
        elif not flare["exploded"]:
            # 도착 후 타이머 증가
            flare["timer"] += 1
            # 1.5초(90프레임) 후 폭발
            if flare["timer"] >= 90:
                flare["exploded"] = True
                # 섬광 효과 생성 (0.15초 = 9프레임)
                flare_zone = {
                    "x": flare["x"],
                    "y": flare["y"],
                    "radius": 180,  # 조명 반경
                    "duration": 9,  # 0.15초 섬광 (60fps * 0.15)
                    "intensity": 1.0,
                    "flash": True  # 섬광 효과 플래그
                }
                flare_zones.append(flare_zone)
                # 보스가 폭발 범위 내에 있는지 체크
                boss_distance = math.sqrt((BOSS.centerx - flare["x"])**2 + (BOSS.centery - flare["y"])**2)
                if boss_distance <= 180:  # 폭발 반경 내에 있으면
                    boss_confused_timer = 180  # 3초간 보스 혼란
                    print(f"💡 섬광탄 명중! 보스가 3초간 혼란 상태!")
                else:
                    print(f"💡 섬광탄 빗나감! 거리: {boss_distance:.0f}")
                flares.remove(flare)
                # 효과음
                try:
                    SOUND_WALL.play()
                except:
                    pass
                print(f"💡 조명탄 폭발! 보스가 5초간 혼란 상태!")
    # 조명 지대 업데이트 (섬광 효과)
    for zone in flare_zones[:]:
        zone["duration"] -= 1
        if zone.get("flash", False):
            # 섬광 효과: 빠르게 깜빡임 (0.15초 = 9프레임)
            if zone["duration"] > 6:  # 처음 0.05초는 최대 밝기
                zone["intensity"] = 1.0
            elif zone["duration"] > 3:  # 다음 0.05초는 어두워짐
                zone["intensity"] = 0.3
            else:  # 마지막 0.05초는 다시 밝아짐
                zone["intensity"] = 0.8
        else:
            zone["intensity"] = zone["duration"] / 9.0  # 일반 페이드 아웃
        if zone["duration"] <= 0:
            flare_zones.remove(zone)
    # 보스 혼란 타이머 감소
    if boss_confused_timer > 0:
        boss_confused_timer -= 1
    # 화염병 업데이트
    for molotov in molotovs[:]:
        # 중력 적용 (gravity가 0이면 적용 안함)
        if molotov["gravity"] > 0:
            molotov["vel_y"] += molotov["gravity"]
        molotov["x"] += molotov["vel_x"]
        molotov["y"] += molotov["vel_y"]
        molotov["rotation"] += 10  # 회전
        # 목표 지점에 도달했는지 체크 (화염병이 목표 Y좌표에 도달하면 폭발)
        if molotov["y"] <= molotov["target_y"]:
            # 폭발 효과 - 불길이 번지는 효과
            fire_zone = {
                "x": molotov["x"],
                "y": molotov["target_y"],  # 목표 지점에 생성
                "width": 150,  # 화염 지대 너비
                "height": 60,  # 화염 지대 높이
                "duration": 150,  # 2.5초로 단축 (60fps * 2.5)
                "flames": [],  # 개별 불꽃 파티클들
                "spread_timer": 0  # 불길 번짐 타이머
            }
            # 초기 불꽃 파티클 생성 (불길이 번지는 효과)
            for i in range(15):
                flame = {
                    "x": molotov["x"] + random.uniform(-30, 30),
                    "y": molotov["target_y"] + random.uniform(-10, 10),
                    "size": random.uniform(8, 20),
                    "lifetime": random.uniform(20, 40),
                    "color_phase": random.uniform(0, 1)
                }
                fire_zone["flames"].append(flame)
            fire_zones.append(fire_zone)
            molotovs.remove(molotov)
            # 폭발 효과음
            try:
                SOUND_WALL.play()
            except:
                pass
            print(f"🔥 화염병 폭발! 화염 지대 생성 위치: X={fire_zone['x']:.1f}, Y={fire_zone['y']:.1f}")
    # 화염 지대 업데이트
    for fire_zone in fire_zones[:]:
        fire_zone["duration"] -= 1
        fire_zone["spread_timer"] += 1
        # push_timer가 없으면 초기화
        if "push_timer" not in fire_zone:
            fire_zone["push_timer"] = 0
        fire_zone["push_timer"] += 1
        # 불길 번짐 효과 - 지속적으로 새 불꽃 추가
        if fire_zone["spread_timer"] % 5 == 0 and len(fire_zone["flames"]) < 30:
            for i in range(3):
                flame = {
                    "x": fire_zone["x"] + random.uniform(-fire_zone["width"]/2, fire_zone["width"]/2),
                    "y": fire_zone["y"] + random.uniform(-fire_zone["height"]/2, fire_zone["height"]/2),
                    "size": random.uniform(10, 25),
                    "lifetime": random.uniform(15, 30),
                    "color_phase": random.uniform(0, 1)
                }
                fire_zone["flames"].append(flame)
        # 불꽃 파티클 업데이트
        for flame in fire_zone["flames"][:]:
            flame["lifetime"] -= 1
            flame["size"] *= 0.97  # 서서히 작아짐
            flame["y"] -= random.uniform(0.1, 0.5)  # 위로 살짝 올라감
            flame["x"] += random.uniform(-0.5, 0.5)  # 좌우로 흔들림
            if flame["lifetime"] <= 0 or flame["size"] < 2:
                fire_zone["flames"].remove(flame)
        # 보스가 화염 지대 안에 있는지 체크 (이동속도 감소용)
        boss_center_x = BOSS.centerx
        boss_center_y = BOSS.centery
        # 사각형 영역 체크 (불길이 번진 영역 + 패들 크기 고려) - 범위 50% 축소
        # X축 거리 체크 - 보스가 화염 지대 폭 안에 있는지
        x_in_range = abs(boss_center_x - fire_zone["x"]) < (fire_zone["width"]/4 + PADDLE_WIDTH/2)  # width/2 → width/4로 축소
        # Y축 거리 체크 - 보스와 화염 지대 사이 거리
        y_distance = abs(boss_center_y - fire_zone["y"])
        # 보스가 화염 지대 근처에 있으면 (Y축으로 60픽셀 이내)  # 120 → 60으로 축소
        y_in_range = y_distance < 60
        in_fire_zone = x_in_range and y_in_range
        # 🔥 화염 지대 내 보스 이동속도 50% 감소 효과 설정
        if in_fire_zone:
            # 전역 변수로 보스 속도 감소 플래그 설정 (handle_boss에서 참조)
            fire_zone["boss_in_fire"] = True
            global boss_speed_reduction_active, boss_speed_reduction_factor
            boss_speed_reduction_active = True
            boss_speed_reduction_factor = 0.5  # 50% 감소 = 50%만 유지
        else:
            # 보스가 화염 지대를 벗어났을 때
            fire_zone["boss_in_fire"] = False
        # 0.5초마다 보스를 화염 지대 밖으로 밀어내기 (스턴 없이 튕김)
        if fire_zone["push_timer"] >= 30:  # 30프레임 = 0.5초 (9프레임에서 변경)
            fire_zone["push_timer"] = 0
            if in_fire_zone:
                # 스턴 없이 즉시 밀어내기 - 화염 지대 중심으로부터 반대 방향으로
                push_force = 60  # 매우 강한 밀어내기 힘 (35에서 60으로 대폭 증가)
                # 화염 지대 중심으로부터의 방향에 따라 밀어내기
                if boss_center_x < fire_zone["x"]:
                    # 보스가 화염 지대 왼쪽에 있으면 왼쪽으로 밀기
                    BOSS.x -= push_force
                else:
                    # 보스가 화염 지대 오른쪽에 있으면 오른쪽으로 밀기
                    BOSS.x += push_force
                # 화면 경계 체크
                BOSS.x = max(0, min(WIDTH - PADDLE_WIDTH, BOSS.x))
                # 💪 체력형 보스 화염 데미지 적용 (1초마다 1회씩만 카운트, 3회마다 체력 감소)
                if current_stage in boss_health_stages and boss_fire_hit_timer <= 0:
                    boss_fire_hit_count += 1
                    boss_fire_hit_timer = 60  # 1초 쿨다운 (60프레임)
                    if boss_fire_hit_count >= 3:
                        boss_current_health = max(0, boss_current_health - 1)  # 3회마다 체력 1 감소
                        boss_fire_hit_count = 0  # 카운터 리셋
                        print(f"🔥 화염 데미지! 보스 체력 -1 (현재: {boss_current_health}/{boss_max_health})")
                    else:
                        print(f"🔥 화염 타격 {boss_fire_hit_count}/3")
                # 시각적 피드백용 작은 흔들림 효과
                if random.random() < 0.3:  # 30% 확률로 작은 흔들림
                    BOSS.x += random.randint(-3, 3)
                    BOSS.x = max(0, min(WIDTH - PADDLE_WIDTH, BOSS.x))
        # 지속시간 종료 체크
        if fire_zone["duration"] <= 0:
            fire_zones.remove(fire_zone)
    # 🔥 모든 화염 지대를 체크한 후, 보스가 어떤 화염 지대에도 없으면 속도 감소 효과 리셋
    if len(fire_zones) == 0 or not any(zone.get("boss_in_fire", False) for zone in fire_zones):
        boss_speed_reduction_active = False
        boss_speed_reduction_factor = 1.0  # 정상 속도로 복구
def activate_whip():
    global whip_active, whip_timer, whip_wave_phase, whip_original_ball_speed
    whip_active = True
    whip_timer = whip_duration
    whip_wave_phase = 0  # 사인 파형 초기화
    # 🌟 상모돌리기 발동 전 공 속도 저장
    whip_original_ball_speed = [ball_vel[0], ball_vel[1]]
    print(f"🌟 상모돌리기 발동! 이전 속도 저장: {whip_original_ball_speed}")
    # 효과음이 처음 발동될 때만 플레이
    whip_sound.play(loops=-1, maxtime=whip_duration * 1000)  # 효과음이 지속되는 시간 설정
    # 속도 일시적으로 줄이기 (25% 감소 = 75% 유지)
    ball_vel[0] *= 0.75
    ball_vel[1] *= 0.75
def handle_whip():
    global whip_active, whip_timer, whip_wave_phase
    if whip_active:
        if whip_timer > 0:
            whip_timer -= 1  # 타이머 감소 (효과음의 지속시간)
            whip_wave_phase += 0.3  # 사인 함수로 진폭 파형 진행
            # 진폭 계산 (사인 함수에 의해 -1에서 1 사이의 값을 가짐)
            wave = math.sin(whip_wave_phase) * 35  # 진폭 25 정도
            # 볼륨 조정: -1에서 1 사이의 값을 0.0에서 1.0으로 변환
            volume = (math.sin(whip_wave_phase) + 1) / 2  # 0.0 ~ 1.0 범위로 변환
            whip_sound.set_volume(volume)  # 효과음 볼륨 설정
            # 공의 속도에 진폭 적용
            ball_vel[0] = original_speed[0] + wave  # 공의 속도에 진폭 효과 반영
        else:
            # 효과음 정지
            whip_active = False  # 효과음 종료
            whip_sound.stop()  # 타이머가 0이 되면 효과음 정지
def activate_balloon():
    """풍선 스킬 활성화"""
    global balloon_active, balloon_timer, balloons, balloon_used_this_round
    balloon_active = True
    balloon_timer = -1  # -1은 라운드 끝까지 지속
    balloons = []  # 풍선 리스트 초기화
    balloon_used_this_round = True  # 이번 라운드에 사용됨 표시
    # 화면에 3-5개의 풍선 생성
    balloon_colors = [
        (255, 100, 100),  # 빨간색
        (100, 255, 100),  # 초록색
        (100, 100, 255),  # 파란색
        (255, 255, 100),  # 노란색
        (255, 100, 255),  # 마젠타
        (100, 255, 255),  # 시안
    ]
    for i in range(random.randint(3, 5)):
        x = random.randint(100, WIDTH-100)
        y = random.randint(100, HEIGHT-100)
        radius = random.randint(25, 35)
        color = random.choice(balloon_colors)
        # 랜덤한 방향과 속도 설정
        speed = random.uniform(1.5, 3.0)
        angle = random.uniform(0, 2 * math.pi)
        vx = math.cos(angle) * speed
        vy = math.sin(angle) * speed
        balloons.append({
            "x": x, 
            "y": y, 
            "radius": radius, 
            "color": color,
            "vx": vx,
            "vy": vy,
            "bounce": 0  # 튀는 애니메이션용
        })
    show_speech("풍선 놀이!", duration=60)
def handle_balloon():
    """풍선 스킬 처리"""
    global balloon_active, balloon_timer, balloons
    if balloon_active:
        # 타이머가 -1이면 라운드 끝까지 지속
        if balloon_timer > 0:
            balloon_timer -= 1
        elif balloon_timer == 0:
            # 풍선 스킬 종료
            balloon_active = False
            balloons.clear()
            return
        # 풍선 움직임과 벽 충돌 처리
        for balloon in balloons:
            # 풍선 위치 업데이트
            balloon["x"] += balloon["vx"]
            balloon["y"] += balloon["vy"]
            # 튀는 애니메이션
            balloon["bounce"] += 0.2
            balloon["y"] += int(math.sin(balloon["bounce"]) * 1)
            # 벽 충돌 감지 및 튕김 처리
            if balloon["x"] - balloon["radius"] <= 0:  # 왼쪽 벽
                balloon["x"] = balloon["radius"]
                balloon["vx"] = abs(balloon["vx"])  # 오른쪽으로 튕김
            elif balloon["x"] + balloon["radius"] >= WIDTH:  # 오른쪽 벽
                balloon["x"] = WIDTH - balloon["radius"]
                balloon["vx"] = -abs(balloon["vx"])  # 왼쪽으로 튕김
            if balloon["y"] - balloon["radius"] <= 0:  # 위쪽 벽
                balloon["y"] = balloon["radius"]
                balloon["vy"] = abs(balloon["vy"])  # 아래쪽으로 튕김
            elif balloon["y"] + balloon["radius"] >= HEIGHT:  # 아래쪽 벽
                balloon["y"] = HEIGHT - balloon["radius"]
                balloon["vy"] = -abs(balloon["vy"])  # 위쪽으로 튕김
def draw_balloons():
    """풍선 이펙트 그리기 - EffectRenderer 사용"""
    # 실제 풍선 그리기
    if balloon_active and balloons:
        for balloon in balloons:
            # 풍선 본체 그리기
            draw.circle(balloon["color"], 
                             (int(balloon["x"]), int(balloon["y"])), 
                             balloon["radius"])
            # 풍선 하이라이트 효과
            highlight_x = int(balloon["x"] - balloon["radius"] * 0.3)
            highlight_y = int(balloon["y"] - balloon["radius"] * 0.3)
            highlight_radius = int(balloon["radius"] * 0.3)
            draw.circle((255, 255, 255, 128), 
                             (highlight_x, highlight_y), 
                             highlight_radius)
    
    # 풍선 파티클 효과 (터진 풍선)
    if balloon_particles:
        effect_renderer.draw_particles(SCREEN, balloon_particles, (255, 200, 100))
def check_balloon_collisions():
    """풍선과 공의 충돌 감지"""
    if not balloon_active or not balloons:
        return
    for balloon in balloons[:]:  # 복사본으로 순회
        # 풍선의 중심점과 공의 중심점 사이의 거리 계산
        dx = BALL.centerx - balloon["x"]
        dy = BALL.centery - balloon["y"]
        distance = math.sqrt(dx*dx + dy*dy)
        # 충돌 감지 (공 반지름 + 풍선 반지름)
        collision_distance = BALL_RADIUS + balloon["radius"]
        if distance <= collision_distance:
            print(f"🎈 풍선 충돌! 각도 변화: 30도")
            # 🎈 풍선 터지는 효과음 재생
            SOUND_BALLOON_BOOM.play()
            # 풍선 터뜨리기 효과
            effects_manager.create_balloon_pop_effect(balloon["x"], balloon["y"], balloon["color"])
            # 풍선 제거
            balloons.remove(balloon)
            # 현재 공의 각도 계산
            current_angle = math.atan2(ball_vel[1], ball_vel[0])
            # 30도(약 0.524 라디안) 랜덤하게 휘어지기
            angle_change = random.uniform(-0.524, 0.524)  # -30도 ~ +30도
            new_angle = current_angle + angle_change
            # 새로운 속도 계산 (현재 속도 유지)
            speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
            ball_vel[0] = math.cos(new_angle) * speed
            ball_vel[1] = math.sin(new_angle) * speed
            # 속도 정규화 제거 - 현재 속도 그대로 유지
            # 충돌 후 즉시 반환 (한 번에 하나의 풍선만 처리)
            return
def apply_red_overlay(surface, intensity):
    """
    투명하지 않은 픽셀에만 붉은 효과를 적용하는 함수 (최적화 버전)
    :param surface: pygame.Surface (RGBA)
    :param intensity: 0~255 사이의 붉은 정도
    """
    # 🚀 성능 최적화: 매우 큰 표면에서는 효과 비활성화
    if surface.get_width() > 300 or surface.get_height() > 300:
        return
    # 🚀 성능 최적화: 블렌딩 모드를 사용한 효율적인 색상 적용
    # 임시 표면을 생성하고 블렌딩 모드 사용
    overlay = pygame.Surface(surface.get_size(), pygame.SRCALPHA)
    # 빨간색 오버레이 색상 계산
    red_factor = min(255, 255 + int(intensity * 0.8))
    green_factor = max(0, 255 - int(intensity * 0.2))
    blue_factor = max(0, 255 - int(intensity * 0.2))
    overlay.fill((red_factor, green_factor, blue_factor, 90))  # 투명도 90
    # 🚀 블렌드 모드를 사용하여 효율적으로 색상 적용
    surface.blit(overlay, (0, 0), special_flags=pygame.BLEND_MULT)
def apply_blue_overlay(surface, intensity):
    """
    투명하지 않은 픽셀에만 파란색 효과를 적용하는 함수 (최적화 버전)
    :param surface: pygame.Surface (RGBA)
    :param intensity: 0~255 사이의 파란색 정도
    """
    # 🚀 성능 최적화: 매우 큰 표면에서는 효과 비활성화
    if surface.get_width() > 300 or surface.get_height() > 300:
        return
    # 🚀 성능 최적화: 블렌딩 모드를 사용한 효율적인 색상 적용
    # 임시 표면을 생성하고 블렌딩 모드 사용
    overlay = pygame.Surface(surface.get_size(), pygame.SRCALPHA)
    # 파란색 오버레이 색상 계산
    blue_factor = min(255, int(intensity * 0.5))
    red_factor = max(0, 255 - int(intensity * 0.3))
    green_factor = max(0, 255 - int(intensity * 0.1))
    overlay.fill((red_factor, green_factor, blue_factor, 80))  # 투명도 80
    # 🚀 블렌드 모드를 사용하여 효율적으로 색상 적용
    surface.blit(overlay, (0, 0), special_flags=pygame.BLEND_MULT)
def update_water_trail():
    """물자국 업데이트 함수"""
    global water_trail_positions, water_trail_timer
    # 디버프가 활성화되어 있을 때만 물자국 생성
    if player_slow_timer > 0:
        water_trail_timer += 1
        # 일정 간격으로 물자국 생성 (패들 바닥 중앙)
        if water_trail_timer >= 10:  # 10프레임마다 생성
            water_trail_positions.append((PLAYER.centerx, PLAYER.bottom + 5, 100))  # 초기 투명도 100
            water_trail_timer = 0
    # 물자국 점점 사라지게 하기 (시간이 지나면 투명도 감소)
    water_trail_positions = [(x, y, alpha - 3) for x, y, alpha in water_trail_positions if alpha > 0]
def draw_water_trail():
    """물 트레일 이펙트 - EffectRenderer 사용"""
    if water_particles:
        effect_renderer.draw_particles(SCREEN, water_particles, (100, 150, 255))
def draw_pachinko():
    """라스베가스 스타일 슬롯머신 그리기 함수"""
    if not pachinko_active:
        return
    # 라스베가스 스타일 배경 (화려한 그라데이션)
    for y in range(HEIGHT):
        ratio = y / HEIGHT
        r = int(20 + ratio * 30)
        g = int(10 + ratio * 20)
        b = int(40 + ratio * 50)
        draw.line((r, g, b), (0, y), (WIDTH, y))
    # 메인 컨테이너 (라스베가스 카지노 스타일)
    container_width = 500
    container_height = 600
    container_x = (WIDTH - container_width) // 2
    container_y = (HEIGHT - container_height) // 2 - 20
    # 컨테이너 글로우 효과 (골드)
    for i in range(10):
        glow_alpha = 60 - i * 6
        glow_surface = pygame.Surface((container_width + i*6, container_height + i*6), pygame.SRCALPHA)
        glow_surface.fill((255, 215, 0, glow_alpha))
        SCREEN.blit(glow_surface, (container_x - i*3, container_y - i*3))
    # 메인 컨테이너
    main_container = pygame.Rect(container_x, container_y, container_width, container_height)
    draw.rect((25, 15, 5), main_container)
    draw.rect((255, 215, 0), main_container, 4)
    # 내부 컨테이너
    inner_container = pygame.Rect(container_x + 20, container_y + 20, container_width - 40, container_height - 40)
    draw.rect((15, 10, 5), inner_container)
    draw.rect((255, 200, 0), inner_container, 3)
    # 제목 영역
    title_area = pygame.Rect(container_x + 30, container_y + 30, container_width - 60, 80)
    draw.rect((30, 20, 10), title_area)
    draw.rect((255, 215, 0), title_area, 3)
    # 제목 텍스트
    title_font = pygame.font.Font("NanumSquareB.ttf", 40)
    title_text = title_font.render("🎰 슬롯머신", True, (255, 215, 0))
    title_rect = title_text.get_rect(center=(container_x + container_width // 2, container_y + 70))
    SCREEN.blit(title_text, title_rect)
    # 슬롯 영역
    slot_area_x = container_x + 50
    slot_area_y = container_y + 150
    slot_area_width = container_width - 100
    slot_area_height = 300
    # 슬롯 배경
    slot_bg_rect = pygame.Rect(slot_area_x - 10, slot_area_y - 10, slot_area_width + 20, slot_area_height + 20)
    draw.rect((20, 15, 10), slot_bg_rect)
    draw.rect((255, 215, 0), slot_bg_rect, 3)
    # 3개 슬롯 그리기
    slot_width = (slot_area_width - 40) // 3
    slot_height = slot_area_height
    for reel_idx in range(3):
        reel_x = slot_area_x + reel_idx * (slot_width + 20)
        reel_y = slot_area_y
        # 릴 배경
        reel_rect = pygame.Rect(reel_x, reel_y, slot_width, slot_height)
        draw.rect((10, 8, 5), reel_rect)
        draw.rect((255, 200, 0), reel_rect, 2)
        # 릴 내부 아이템들 그리기 (세로 스크롤)
        item_size = 60
        visible_items = 5  # 한 번에 보이는 아이템 개수
        for i in range(visible_items):
            item_y = reel_y + i * (slot_height // visible_items) + 10
            item_y -= slot_positions[reel_idx]  # 스크롤 적용
            # 화면 안에 있는 아이템만 그리기
            if item_y + item_size > reel_y and item_y < reel_y + slot_height:
                # 아이템 인덱스 계산
                item_idx = (int(slot_positions[reel_idx] // 8) + i) % 30
                if item_idx < len(slot_reels[reel_idx]):
                    item = slot_reels[reel_idx][item_idx]
                    # 아이템 배경
                    item_rect = pygame.Rect(reel_x + 5, item_y, item_size, item_size)
                    draw.rect((25, 20, 15), item_rect)
                    draw.rect((255, 180, 0), item_rect, 2)
                    # 아이템 아이콘
                    if "icon" in item and item["icon"]:
                        icon = pygame.transform.scale(item["icon"], (50, 50))
                        icon_x = reel_x + 8
                        icon_y = item_y + 5
                        SCREEN.blit(icon, (icon_x, icon_y))
                    else:
                        # 아이콘이 없으면 원으로 그리기
                        center_x = reel_x + slot_width // 2
                        center_y = item_y + item_size // 2
                        draw.circle(item["color"], (center_x, center_y), 20)
        # 중앙 선택 표시 (골드 글로우)
        center_y = reel_y + slot_height // 2
        center_rect = pygame.Rect(reel_x - 5, center_y - 35, slot_width + 10, 70)
        # 글로우 효과
        for i in range(3):
            glow_alpha = 100 - i * 30
            glow_surface = pygame.Surface((slot_width + 10 + i*4, 70 + i*4), pygame.SRCALPHA)
            glow_surface.fill((255, 215, 0, glow_alpha))
            glow_x = reel_x - 5 - i*2
            glow_y = center_y - 35 - i*2
            SCREEN.blit(glow_surface, (glow_x, glow_y))
        draw.rect((255, 215, 0), center_rect, 4)
    # 결과 표시
    if pachinko_phase == 3 and slot_final_result:
        # 당첨 애니메이션
        global slot_win_animation
        slot_win_animation += 1
        # 결과 영역
        result_width = 400
        result_height = 120
        result_x = (WIDTH - result_width) // 2
        result_y = container_y + container_height + 20
        # 화려한 배경
        for i in range(result_height):
            ratio = i / result_height
            r = int(50 + ratio * 100)
            g = int(30 + ratio * 80)
            b = int(10 + ratio * 40)
            draw.line((r, g, b), (result_x, result_y + i), (result_x + result_width, result_y + i))
        draw.rect((255, 215, 0), (result_x, result_y, result_width, result_height), 4)
        # 당첨 아이템 표시
        if "icon" in slot_final_result and slot_final_result["icon"]:
            icon = pygame.transform.scale(slot_final_result["icon"], (80, 80))
            icon_x = result_x + 30
            icon_y = result_y + 20
            SCREEN.blit(icon, (icon_x, icon_y))
        # 당첨 메시지
        item_name = get_item_name_korean(slot_final_result['name'])
        result_font = pygame.font.Font("NanumSquareB.ttf", 28)
        result_text = f"🎉 JACKPOT! {item_name} 🎉"
        text = result_font.render(result_text, True, (255, 255, 255))
        text_rect = text.get_rect(center=(result_x + result_width // 2, result_y + 60))
        SCREEN.blit(text, text_rect)
        # 계속하기 안내
        continue_font = pygame.font.Font("NanumSquareR.ttf", 20)
        continue_text = "✨ SPACE를 눌러 계속... ✨"
        text_small = continue_font.render(continue_text, True, (255, 255, 255))
        text_small_rect = text_small.get_rect(center=(result_x + result_width // 2, result_y + 100))
        SCREEN.blit(text_small, text_small_rect)
    elif pachinko_phase == 3 and not slot_final_result:
        # 꽝 결과
        result_width = 400
        result_height = 120
        result_x = (WIDTH - result_width) // 2
        result_y = container_y + container_height + 20
        # 어두운 배경
        draw.rect((30, 20, 10), (result_x, result_y, result_width, result_height))
        draw.rect((100, 100, 100), (result_x, result_y, result_width, result_height), 3)
        # 꽝 메시지
        result_font = pygame.font.Font("NanumSquareB.ttf", 32)
        result_text = "💔 아쉽게도 꽝입니다... 💔"
        text = result_font.render(result_text, True, (200, 200, 200))
        text_rect = text.get_rect(center=(result_x + result_width // 2, result_y + 60))
        SCREEN.blit(text, text_rect)
        # 계속하기 안내
        continue_font = pygame.font.Font("NanumSquareR.ttf", 20)
        continue_text = "✨ SPACE를 눌러 계속... ✨"
        text_small = continue_font.render(continue_text, True, (200, 200, 200))
        text_small_rect = text_small.get_rect(center=(result_x + result_width // 2, result_y + 100))
        SCREEN.blit(text_small, text_small_rect)
    # 안내 텍스트
    if pachinko_phase == 0:
        guide_font = pygame.font.Font("NanumSquareR.ttf", 24)
        guide_text = "🎯 SPACE를 눌러 슬롯머신 시작! 🎯"
        text = guide_font.render(guide_text, True, (255, 215, 0))
        text_rect = text.get_rect(center=(WIDTH // 2, container_y + container_height + 80))
        SCREEN.blit(text, text_rect)
    elif slot_spinning and not slot_slowdown_mode:
        guide_font = pygame.font.Font("NanumSquareR.ttf", 24)
        guide_text = "🎯 SPACE를 눌러 첫 번째 릴 멈추기! 🎯"
        text = guide_font.render(guide_text, True, (255, 215, 0))
        text_rect = text.get_rect(center=(WIDTH // 2, container_y + container_height + 80))
        SCREEN.blit(text, text_rect)
    elif slot_slowdown_mode:
        if slot_stop_order == 0:
            guide_font = pygame.font.Font("NanumSquareR.ttf", 24)
            guide_text = "🎯 SPACE를 눌러 두 번째 릴 멈추기! 🎯"
            text = guide_font.render(guide_text, True, (255, 215, 0))
            text_rect = text.get_rect(center=(WIDTH // 2, container_y + container_height + 80))
            SCREEN.blit(text, text_rect)
        elif slot_stop_order == 1:
            guide_font = pygame.font.Font("NanumSquareR.ttf", 24)
            guide_text = "🎯 SPACE를 눌러 세 번째 릴 멈추기! 🎯"
            text = guide_font.render(guide_text, True, (255, 215, 0))
            text_rect = text.get_rect(center=(WIDTH // 2, container_y + container_height + 80))
            SCREEN.blit(text, text_rect)
        else:
            guide_font = pygame.font.Font("NanumSquareR.ttf", 24)
            guide_text = "🎯 슬롯이 멈춥니다... 🎯"
            text = guide_font.render(guide_text, True, (255, 215, 0))
            text_rect = text.get_rect(center=(WIDTH // 2, container_y + container_height + 80))
            SCREEN.blit(text, text_rect)
def update_red_intensity():
    global red_intensity
    if special_active:
        red_intensity = 0
        return
    # 게이지 비율 기반(0.0~1.0)
    ratio = special_gauge / special_gauge_max  # ✅ 수정
    target = ratio * 180  # 최대값 180
    # 서서히 변화
    if red_intensity < target:
        red_intensity += (target - red_intensity) * 0.1
    else:
        red_intensity -= (red_intensity - target) * 0.1
    red_intensity = min(180, max(0, red_intensity))
def update_gauge_animation():
    """게이지 부드러운 애니메이션 업데이트"""
    global displayed_gauge, gauge_animation_speed, displayed_boss_gauge, boss_gauge_animation_speed
    # 플레이어 게이지 애니메이션
    # 목표 게이지까지 부드럽게 이동
    if displayed_gauge < special_gauge:
        displayed_gauge += (special_gauge - displayed_gauge) * gauge_animation_speed
        # 정확히 목표값에 도달하도록 보정
        if displayed_gauge > special_gauge - 1:
            displayed_gauge = special_gauge
    elif displayed_gauge > special_gauge:
        displayed_gauge -= (displayed_gauge - special_gauge) * gauge_animation_speed
        # 정확히 목표값에 도달하도록 보정
        if displayed_gauge < special_gauge + 1:
            displayed_gauge = special_gauge
    # 멘헤라걸(스테이지 3) 게이지 애니메이션
    if current_stage == 3:
        if displayed_boss_gauge < boss_special_gauge:
            displayed_boss_gauge += (boss_special_gauge - displayed_boss_gauge) * boss_gauge_animation_speed
            # 정확히 목표값에 도달하도록 보정
            if displayed_boss_gauge > boss_special_gauge - 1:
                displayed_boss_gauge = boss_special_gauge
        elif displayed_boss_gauge > boss_special_gauge:
            displayed_boss_gauge -= (displayed_boss_gauge - boss_special_gauge) * boss_gauge_animation_speed
            # 정확히 목표값에 도달하도록 보정
            if displayed_boss_gauge < boss_special_gauge + 1:
                displayed_boss_gauge = boss_special_gauge
def show_item_obtained_effect(item_data, item_x=None, item_y=None):
    """아이템 획득 효과 표시"""
    global item_obtained_effect
    # 아이템 타입 확인
    item_name = item_data.get("name", "")
    is_passive = item_name in ["speedboots", "speedgear", "battery", "slot_add", "revival", "master", "cooltime", "chargebag", "spikeboots", "dashgear", "bulkup", "sensor", "dashholder"]
    # 시작 위치 (아이템이 있던 위치 또는 화면 중앙)
    if item_x is not None and item_y is not None:
        start_x = item_x
        start_y = item_y
    else:
        start_x = WIDTH // 2
        start_y = HEIGHT // 2 - 50
    # 목표 위치 (모든 아이템이 플레이어 쪽으로 이동)
    target_x = 100  # 플레이어 쪽
    target_y = HEIGHT // 2
    # 풍선 터지는 효과 생성 (아이템 색상으로) - 모든 아이템에 적용
    item_color = item_data.get("color", (255, 255, 255))
    effects_manager.create_balloon_pop_effect(start_x, start_y, item_color)
    item_obtained_effect = {
        "icon": item_data.get("icon"),
        "name": item_data.get("name"),
        "timer": item_effect_duration,
        "alpha": 180,  # 더 투명하게 (255 -> 180)
        "type": "passive" if is_passive else "active",
        "x": start_x,
        "y": start_y,
        "target_x": target_x,
        "target_y": target_y,
        "start_x": start_x,
        "start_y": start_y
    }
def update_item_obtained_effect():
    """아이템 획득 효과 업데이트"""
    global item_obtained_effect
    if item_obtained_effect:
        item_obtained_effect["timer"] -= 1
        # 위치 업데이트 (모든 아이템이 플레이어 쪽으로 이동)
        progress = 1 - (item_obtained_effect["timer"] / item_effect_duration)
        # 부드러운 이동 (easing)
        ease_progress = 1 - (1 - progress) ** 2
        item_obtained_effect["x"] = item_obtained_effect["start_x"] + (item_obtained_effect["target_x"] - item_obtained_effect["start_x"]) * ease_progress
        item_obtained_effect["y"] = item_obtained_effect["start_y"] + (item_obtained_effect["target_y"] - item_obtained_effect["start_y"]) * ease_progress
        # 페이드 아웃 효과
        if item_obtained_effect["timer"] < 60:  # 마지막 1초
            fade_ratio = item_obtained_effect["timer"] / 60
            item_obtained_effect["alpha"] = int(255 * fade_ratio)
        if item_obtained_effect["timer"] <= 0:
            item_obtained_effect = None
def draw_item_obtained_effect():
    """아이템 획득 효과 그리기"""
    if not item_obtained_effect:
        return
    effect_x = int(item_obtained_effect["x"])
    effect_y = int(item_obtained_effect["y"])
    # 배경 원 (글로우 효과) - 크기 50% 감소
    glow_radius = 40  # 80 -> 40
    glow_surface = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
    for i in range(glow_radius):
        alpha = int(30 * (1 - i / glow_radius) * (item_obtained_effect["alpha"] / 255))  # 더 투명하게
        pygame.draw.circle(glow_surface, (255, 255, 255, alpha), (glow_radius, glow_radius), glow_radius - i)
    SCREEN.blit(glow_surface, (effect_x - glow_radius, effect_y - glow_radius))
    # 메인 원형 배경 - 크기 50% 감소
    draw.circle((30, 40, 60, 150), (effect_x, effect_y), 30)  # 더 투명하게
    draw.circle((100, 150, 255, 150), (effect_x, effect_y), 30, 2)  # 더 투명하게
    # 아이템 아이콘 - 크기 50% 감소
    if item_obtained_effect["icon"]:
        icon = pygame.transform.scale(item_obtained_effect["icon"], (40, 40))  # 80 -> 40
        icon.set_alpha(item_obtained_effect["alpha"])
        icon_rect = icon.get_rect(center=(effect_x, effect_y))
        SCREEN.blit(icon, icon_rect.topleft)
    # 아이템 이름 (한글) - 크기 50% 감소
    item_name = get_item_name_korean(item_obtained_effect["name"])
    name_font = pygame.font.Font("NanumSquareB.ttf", 12)  # 24 -> 12
    # 시너지 효과일 때 보라색으로 표시
    if item_obtained_effect["name"] == "gravitybelt" and gravity_speed_synergy:
        name_color = (128, 0, 128)  # 보라색
    else:
        name_color = (255, 255, 255)  # 흰색
    name_text = name_font.render(item_name, True, name_color)
    name_text.set_alpha(item_obtained_effect["alpha"])
    name_rect = name_text.get_rect(center=(effect_x, effect_y + 50))  # 100 -> 50
    SCREEN.blit(name_text, name_rect)
    # 획득 메시지 - 크기 50% 감소
    obtain_font = pygame.font.Font("NanumSquareR.ttf", 9)  # 18 -> 9
    obtain_text = obtain_font.render("획득!", True, (255, 215, 0))
    obtain_text.set_alpha(item_obtained_effect["alpha"])
    obtain_rect = obtain_text.get_rect(center=(effect_x, effect_y + 65))  # 130 -> 65
    SCREEN.blit(obtain_text, obtain_rect)
def apply_white_glow(surface, intensity=60):
    """
    픽셀 단위로 반짝임 효과를 입히는 함수 (최적화 버전)
    :param surface: pygame.Surface (RGBA)
    :param intensity: 반짝임 밝기 (기본 60)
    """
    # 성능 최적화: 너무 큰 표면에서는 효과 비활성화 (크기 제한을 늘림)
    if surface.get_width() > 400 or surface.get_height() > 400:
        return  # 매우 큰 표면에서만 효과 비활성화
    # 성능 최적화: 픽셀 단위 대신 간격을 두고 처리
    step = 2  # 2픽셀마다 처리
    for x in range(0, surface.get_width(), step):
        for y in range(0, surface.get_height(), step):
            pixel = surface.get_at((x, y))
            if pixel.a != 0:  # 기체 부분에만 적용
                glow_r = min(255, max(0, pixel.r + intensity))
                glow_g = min(255, max(0, pixel.g + intensity))
                glow_b = min(255, max(0, pixel.b + intensity))
                try:
                    surface.set_at((x, y), pygame.Color(glow_r, glow_g, glow_b, pixel.a))
                except ValueError:
                    # 색상 값이 잘못된 경우 기본값 사용
                    surface.set_at((x, y), pygame.Color(255, 255, 255, pixel.a))
def draw_player_gauge():
    """플레이어 게이지바를 오른쪽 하단에 세로로 표시 - 고급스러운 버전"""
    global special_gauge, special_gauge_max, special_ready, aipill_active, long_boost_active, long_boost_timer
    global wall_installing, wall_install_timer, wall_install_gauge_visible, rolling_charges, rolling_cooldown  # 🔴 대쉬 토큰 표시용
    # 필살기 게이지바 위치와 크기 - 엣지있는 주인공 스타일
    gauge_x = WIDTH - 40  # 오른쪽에서 40px
    gauge_y = HEIGHT - 180  # 하단에서 180px 위
    gauge_width = 14  # 더 얇게
    gauge_height = 100  # 높이
    time_now = pygame.time.get_ticks()
    # ⚡ 전기 효과 강도 (게이지가 높을수록 강해짐)
    # 🔷 육각형 프레임 상단
    hex_top = [
        (gauge_x + gauge_width // 2, gauge_y - 10),
        (gauge_x - 3, gauge_y),
        (gauge_x - 3, gauge_y + 8),
        (gauge_x + gauge_width + 3, gauge_y + 8),
        (gauge_x + gauge_width + 3, gauge_y),
    ]
    draw.polygon((80, 90, 100), hex_top)
    draw.polygon((180, 190, 200), hex_top, 2)
    # 🔷 육각형 프레임 하단
    hex_bottom = [
        (gauge_x - 3, gauge_y + gauge_height - 8),
        (gauge_x - 3, gauge_y + gauge_height),
        (gauge_x + gauge_width // 2, gauge_y + gauge_height + 10),
        (gauge_x + gauge_width + 3, gauge_y + gauge_height),
        (gauge_x + gauge_width + 3, gauge_y + gauge_height - 8),
    ]
    draw.polygon((80, 90, 100), hex_bottom)
    draw.polygon((180, 190, 200), hex_bottom, 2)
    # 🎯 메인 프레임 배경
    # 어두운 메탈릭 배경
    main_rect = pygame.Rect(gauge_x - 2, gauge_y, gauge_width + 4, gauge_height)
    draw.rect((25, 28, 35), main_rect)
    # 내부 홈 (음각 효과)
    inner_rect = pygame.Rect(gauge_x, gauge_y + 2, gauge_width, gauge_height - 4)
    draw.rect((15, 18, 25), inner_rect)
    # 사이드 라인 디테일 (테크니컬한 느낌)
    for i in range(3):
        line_y = gauge_y + 20 + i * 30
        # 왼쪽 라인
        draw.line((100, 110, 120), 
                        (gauge_x - 5, line_y), (gauge_x - 2, line_y), 1)
        # 오른쪽 라인
        draw.line((100, 110, 120), 
                        (gauge_x + gauge_width + 2, line_y), (gauge_x + gauge_width + 5, line_y), 1)
    # 센터 라인 (세로 중앙선)
    center_x = gauge_x + gauge_width // 2
    draw.line((60, 65, 75), 
                    (center_x, gauge_y + 5), (center_x, gauge_y + gauge_height - 5), 1)
    # ⚡ 게이지 채우기 - 전기/플라즈마 스타일
    if displayed_gauge > 0:
        fill_ratio = displayed_gauge / special_gauge_max
        fill_height = int((gauge_height - 4) * fill_ratio)
        # 게이지 레벨별 색상 (차갑고 날카로운 색상)
        if displayed_gauge < 150:
            # 레벨 1: 차가운 청백색
            base_color = (180, 200, 220)
            energy_color = (200, 220, 240)
        elif displayed_gauge < 250:
            # 레벨 2: 전기 청색
            base_color = (100, 180, 255)
            energy_color = (150, 200, 255)
        elif displayed_gauge < 350:
            # 레벨 3: 강렬한 시안
            base_color = (0, 220, 255)
            energy_color = (100, 240, 255)
        else:
            # 레벨 4: 플라즈마 (청백색 + 보라)
            pulse = abs(math.sin(time_now * 0.005))
            base_color = (
                int(100 + pulse * 100),
                int(150 + pulse * 50),
                255
            )
            energy_color = (200, 200, 255)
        # 메인 에너지 채우기
        fill_y = gauge_y + gauge_height - fill_height - 2
        # 3층 레이어 구조
        for layer in range(3):
            layer_alpha = 255 - layer * 50
            layer_width = gauge_width - 4 - layer * 2
            if layer_width > 0:
                for i in range(fill_height):
                    # 펄스 효과
                    pulse_offset = abs(math.sin((time_now * 0.003) + (i * 0.1)))
                    if layer == 0:  # 코어 레이어
                        color = energy_color
                    elif layer == 1:  # 미들 레이어
                        color = base_color
                    else:  # 외곽 레이어
                        color = tuple(int(c * 0.7) for c in base_color)
                    # 색상에 펄스 적용
                    final_color = tuple(min(255, int(c + pulse_offset * 20)) for c in color)
                    draw.line(final_color,
                                   (gauge_x + 2 + layer, fill_y + i),
                                   (gauge_x + 2 + layer_width, fill_y + i))
        # ⚡ 전기 스파크 효과 (350 이상일 때)
        if displayed_gauge >= 350:
            spark_count = 2 if displayed_gauge < special_gauge_max else 4
            for _ in range(spark_count):
                spark_y = fill_y + random.randint(0, fill_height - 1)
                spark_x = gauge_x + random.randint(2, gauge_width - 2)
                spark_length = random.randint(3, 7)
                # 번개 모양
                points = []
                current_x = spark_x
                current_y = spark_y
                for i in range(3):
                    next_x = current_x + random.randint(-3, 3)
                    next_y = current_y + spark_length // 3
                    points.append((current_x, current_y))
                    points.append((next_x, next_y))
                    current_x = next_x
                    current_y = next_y
                if len(points) > 1:
                    pygame.draw.lines(SCREEN, (255, 255, 255), False, points, 1)
        # 상단 에너지 글로우
        if fill_ratio > 0.5:
            glow_height = 5
            for i in range(glow_height):
                alpha = 100 - i * 20
                glow_color = tuple(min(255, c + 50) for c in energy_color)
                draw.line(glow_color,
                               (gauge_x + 2, fill_y - i),
                               (gauge_x + gauge_width - 2, fill_y - i))
    # ⚡ 파워 준비 상태 표시 (전기 효과)
    if displayed_gauge >= 350:
        # 외곽 전기 아크
        if (time_now // 100) % 3 == 0:  # 간헐적으로
            # 상단 아크
            arc_start = (gauge_x - 5, gauge_y - 5)
            arc_end = (gauge_x + gauge_width + 5, gauge_y - 5)
            arc_mid = (gauge_x + gauge_width // 2, gauge_y - 8)
            pygame.draw.lines(SCREEN, (150, 200, 255), False, 
                            [arc_start, arc_mid, arc_end], 1)
            # 하단 아크
            arc_start = (gauge_x - 5, gauge_y + gauge_height + 5)
            arc_end = (gauge_x + gauge_width + 5, gauge_y + gauge_height + 5)
            arc_mid = (gauge_x + gauge_width // 2, gauge_y + gauge_height + 8)
            pygame.draw.lines(SCREEN, (150, 200, 255), False, 
                            [arc_start, arc_mid, arc_end], 1)
        # 코너 발광
        corner_glow = int(abs(math.sin(time_now * 0.004)) * 100 + 155)
        corner_color = (corner_glow, corner_glow, 255)
        # 상단 코너
        draw.circle(corner_color, (gauge_x, gauge_y), 3)
        draw.circle(corner_color, (gauge_x + gauge_width, gauge_y), 3)
        # 하단 코너
        draw.circle(corner_color, (gauge_x, gauge_y + gauge_height), 3)
        draw.circle(corner_color, (gauge_x + gauge_width, gauge_y + gauge_height), 3)
    # 🔢 게이지바 위에 숫자 표시 (현재/최대)
    gauge_text = f"{int(displayed_gauge)}/{special_gauge_max}"
    text_color = (255, 255, 255) if displayed_gauge < special_gauge_max else (255, 255, 100)  # 만렙일 때는 노란색
    # 폰트 로드 (작은 크기)
    try:
        gauge_font = pygame.font.Font("NanumSquareB.ttf", 14)
    except:
        gauge_font = pygame.font.Font(None, 14)
    gauge_text_surface = gauge_font.render(gauge_text, True, text_color)
    text_rect = gauge_text_surface.get_rect()
    # 게이지바 위쪽에 중앙 정렬
    text_x = gauge_x + gauge_width // 2 - text_rect.width // 2
    text_y = gauge_y - 20  # 게이지바 위 20픽셀
    # 텍스트 배경 (반투명 검은 배경으로 가독성 향상)
    text_bg_rect = pygame.Rect(text_x - 2, text_y - 1, text_rect.width + 4, text_rect.height + 2)
    draw.rect((0, 0, 0, 180), text_bg_rect, border_radius=3)
    draw.rect((100, 100, 100), text_bg_rect, 1, border_radius=3)
    # 텍스트 렌더링
    SCREEN.blit(gauge_text_surface, (text_x, text_y))
    # 🎯 통합 아이템 지속시간 게이지바 (거대화포션 & 레이저스코프)
    item_gauge_active = (long_boost_active and long_boost_timer > 0) or (predictor_active and predictor_timer > 0)
    if item_gauge_active:
        gauge_x = WIDTH - 75  # 필살기 게이지 왼쪽에 배치
        gauge_y = HEIGHT - 180  # 필살기 게이지와 같은 높이
        gauge_width = 14  # 플레이어 게이지와 동일한 폭
        gauge_height = 100
        # 🔷 육각형 프레임 상단 (플레이어 게이지와 동일)
        hex_top = [
            (gauge_x + gauge_width // 2, gauge_y - 10),
            (gauge_x - 3, gauge_y),
            (gauge_x - 3, gauge_y + 8),
            (gauge_x + gauge_width + 3, gauge_y + 8),
            (gauge_x + gauge_width + 3, gauge_y),
        ]
        draw.polygon((80, 90, 100), hex_top)
        draw.polygon((180, 190, 200), hex_top, 2)
        # 🔷 육각형 프레임 하단
        hex_bottom = [
            (gauge_x - 3, gauge_y + gauge_height - 8),
            (gauge_x - 3, gauge_y + gauge_height),
            (gauge_x + gauge_width // 2, gauge_y + gauge_height + 10),
            (gauge_x + gauge_width + 3, gauge_y + gauge_height),
            (gauge_x + gauge_width + 3, gauge_y + gauge_height - 8),
        ]
        draw.polygon((80, 90, 100), hex_bottom)
        draw.polygon((180, 190, 200), hex_bottom, 2)
        # 🎯 메인 프레임 배경
        main_rect = pygame.Rect(gauge_x - 2, gauge_y, gauge_width + 4, gauge_height)
        draw.rect((25, 28, 35), main_rect)
        # 내부 홈 (음각 효과) - 게이지 채우기 전에만 그리기
        inner_rect = pygame.Rect(gauge_x, gauge_y + 2, gauge_width, gauge_height - 4)
        draw.rect((15, 18, 25), inner_rect)
        # 사이드 라인 디테일
        for i in range(3):
            line_y = gauge_y + 20 + i * 30
            draw.line((100, 110, 120), 
                            (gauge_x - 5, line_y), (gauge_x - 2, line_y), 1)
            draw.line((100, 110, 120), 
                            (gauge_x + gauge_width + 2, line_y), (gauge_x + gauge_width + 5, line_y), 1)
        # ⚡ 게이지 채우기 - 활성 아이템에 따라 색상 결정
        if long_boost_active and long_boost_timer > 0:
            # 거대화포션 활성화 시
            remaining_ratio = long_boost_timer / LONG_BOOST_DURATION
            fill_height = int((gauge_height - 4) * remaining_ratio)
            # 거대화포션 색상 (황금빛 -> 주황색)
            if remaining_ratio > 0.6:
                base_color = (255, 215, 0)  # 골드
                energy_color = (255, 235, 100)
            elif remaining_ratio > 0.3:
                base_color = (255, 165, 0)  # 주황색
                energy_color = (255, 195, 50)
            else:
                # 끝날 때 깜빡임 효과
                pulse = abs(math.sin(time_now * 0.01))
                base_color = (255, int(100 + pulse * 65), 0)
                energy_color = (255, int(150 + pulse * 50), 50)
        elif predictor_active and predictor_timer > 0:
            # 레이저스코프 활성화 시
            remaining_ratio = predictor_timer / 600  # 10초 기준 (60fps * 10초 = 600)
            fill_height = int((gauge_height - 4) * remaining_ratio)
            # 레이저스코프 색상 (빨간색 레이저)
            if remaining_ratio > 0.6:
                base_color = (255, 100, 100)  # 밝은 빨강
                energy_color = (255, 150, 150)
            elif remaining_ratio > 0.3:
                base_color = (255, 50, 50)  # 진한 빨강
                energy_color = (255, 100, 100)
            else:
                # 끝날 때 깜빡임
                pulse = abs(math.sin(time_now * 0.01))
                base_color = (255, int(50 * pulse), int(50 * pulse))
                energy_color = (255, int(100 * pulse), int(100 * pulse))
        else:
            fill_height = 0
        # 게이지 그리기 (fill_height가 0보다 클 때만)
        if fill_height > 0:
            fill_y = gauge_y + gauge_height - fill_height - 2
            # 3층 레이어 구조 (플레이어 게이지와 동일)
            for layer in range(3):
                layer_alpha = 255 - layer * 50
                layer_width = gauge_width - 4 - layer * 2
                if layer_width > 0:
                    layer_rect = pygame.Rect(gauge_x + 2 + layer, fill_y, layer_width, fill_height)
                    # 레이어별 색상 조정
                    layer_color = (
                        min(255, base_color[0] + layer * 20),
                        min(255, base_color[1] + layer * 20),
                        min(255, base_color[2] + layer * 20)
                    )
                    draw.rect(layer_color, layer_rect)
            # ✨ 특수 효과
            if long_boost_active and remaining_ratio > 0.1:
                # 거대화포션: 반짝임 효과
                if random.random() < 0.3:  # 30% 확률로 반짝임
                    sparkle_y = fill_y + random.randint(0, max(1, fill_height - 1))
                    sparkle_color = (255, 255, 200, 150)
                    draw.line(sparkle_color,
                                   (gauge_x + 2, sparkle_y),
                                   (gauge_x + gauge_width - 2, sparkle_y), 1)
            elif predictor_active and remaining_ratio > 0.1:
                # 레이저스코프: 스캔 효과 (정확한 범위 제한)
                if fill_height > 6:  # 최소 높이 확인 (여유 있게)
                    # 실제 채우기 영역 계산 (내부 홈 영역)
                    actual_fill_top = max(gauge_y + 2, fill_y)
                    actual_fill_bottom = min(gauge_y + gauge_height - 2, fill_y + fill_height)
                    actual_fill_height = actual_fill_bottom - actual_fill_top
                    if actual_fill_height > 0:
                        # 스캔 위치 계산 (실제 채우기 영역 내에서만 순환)
                        scan_offset = (time_now // 10) % actual_fill_height
                        scan_y = actual_fill_top + scan_offset
                        # 스캔 라인 그리기 (정확한 경계 체크)
                        if actual_fill_top <= scan_y < actual_fill_bottom:
                            scan_color = (255, 200, 200, 180)
                            draw.line(scan_color,
                                           (gauge_x + 2, scan_y),
                                           (gauge_x + gauge_width - 2, scan_y), 2)
    # 🆕 벽돌 설치 게이지 (플레이어 패들 바로 위)
    if wall_install_gauge_visible and wall_installing:
        # 설치 게이지 위치 (플레이어 패들 바로 위)
        install_gauge_x = PLAYER.centerx - 40  # 패들 중앙 기준 좌우 40픽셀
        install_gauge_y = PLAYER.top - 30  # 패들 위 30픽셀
        install_gauge_width = 80  # 패들 너비와 동일
        install_gauge_height = 8  # 얇은 게이지
        # 설치 게이지 배경 (회색)
        draw.rect((80, 80, 80), 
                         (install_gauge_x, install_gauge_y, install_gauge_width, install_gauge_height))
        # 설치 게이지 테두리 (갈색)
        draw.rect((139, 69, 19), 
                         (install_gauge_x, install_gauge_y, install_gauge_width, install_gauge_height), 2)
        # 설치 게이지 채우기 (남은 시간에 따라 증가)
        install_max_timer = 30  # 0.5초 (30프레임)
        progress_ratio = (install_max_timer - wall_install_timer) / install_max_timer
        fill_width = int(install_gauge_width * progress_ratio)
        # 갈색에서 노란색으로 그라데이션
        if progress_ratio < 0.5:
            gauge_color = (139, 69, 19)  # 갈색
        elif progress_ratio < 0.8:
            gauge_color = (160, 82, 45)  # 밝은 갈색
        else:
            gauge_color = (255, 255, 0)  # 노란색
        # 채워진 부분 그리기 (왼쪽에서부터)
        draw.rect(gauge_color, 
                         (install_gauge_x + 2, install_gauge_y + 2, fill_width - 4, install_gauge_height - 4))
    # 대쉬 전용 게이지바 제거 - 토큰볼을 게이지로 활용
    # 🔴 대쉬 토큰 표시 (플레이어 게이지바 하단에 고정)
    token_radius = 6  # 토큰 크기
    token_spacing = 16  # 토큰 간격
    # 🔧 정확한 최대 토큰 수 계산 (대쉬홀더 + 증폭 스킬)
    base_charges = 1  # 기본 1개
    holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
    amplification_bonus = academy.get_skill_bonus("dash_amplification")
    max_tokens = int(base_charges + holder_bonus + amplification_bonus)
    # 토큰 표시 시작 위치 (플레이어 게이지바 중앙 하단에 항상 고정)
    player_gauge_x = WIDTH - 40  # 플레이어 게이지바 X 위치
    player_gauge_width = 14  # 플레이어 게이지바 폭
    token_start_x = player_gauge_x + player_gauge_width // 2 - (max_tokens * token_spacing) // 2 + token_spacing // 2
    token_y = gauge_y + gauge_height + 15  # 게이지바 아래 15픽셀
    # 🔧 대쉬 토큰 표시 - 오른쪽부터 소진 / 왼쪽부터 충전
    # 최종 해결: token_states 리스트로 각 토큰 개별 추적
    global token_states
    if 'token_states' not in globals():
        token_states = [True] * rolling_charges + [False] * (max_tokens - rolling_charges)
    # 토큰 상태 배열 크기 조정
    if len(token_states) != max_tokens:
        # 현재 충전된 토큰 수 계산
        current_charged = sum(1 for state in token_states if state)
        # 새로운 토큰 상태 배열 생성
        if rolling_charges > 0:
            # 실제 충전된 토큰 수에 맞춰 재구성
            token_states = [True] * min(rolling_charges, max_tokens) + [False] * max(0, max_tokens - rolling_charges)
        else:
            # 토큰이 없으면 모두 비어있음
            token_states = [False] * max_tokens
    for i in range(max_tokens):
        token_x = token_start_x + i * token_spacing
        # 토큰 상태에 따른 표시
        if i < len(token_states) and token_states[i]:
            # 사용 가능한 토큰 - 밝은 빨간색
            token_color = (255, 80, 80)
            glow_color = (255, 150, 150)
            is_available = True
        else:
            # 사용된 토큰 - 충전 중
            # 충전 진행률 계산
            if rolling_charge_timer > 0:
                # 최대 충전 시간 계산
                dash_cooldown_bonus = academy.get_skill_bonus("dash_cooldown")
                cooldown_reduction = int(dash_cooldown_bonus * 60)
                if dashholder_obtained and rolling_charges >= 1:
                    max_charge_time = max(6, 60 - cooldown_reduction)  # 1초
                else:
                    max_charge_time = max(6, 90 - cooldown_reduction)  # 1.5초
                # 충전 진행률 (0.0 ~ 1.0)
                charge_progress = 1.0 - (rolling_charge_timer / max_charge_time)
                charge_progress = max(0, min(1, charge_progress))
                # 충전 중인 토큰 확인 (왼쪽부터 충전)
                # 왼쪽부터 첫 번째 비어있는 토큰만 충전
                is_charging = False
                for j in range(len(token_states)):
                    if not token_states[j]:  # 비어있는 토큰 발견
                        if j == i:  # 현재 토큰이 첫 번째 비어있는 토큰인 경우
                            is_charging = True
                        break  # 첫 번째 비어있는 토큰만 찾으면 종료
                if is_charging:
                    # 충전 중 - 빨간색이 차오르는 효과
                    base_empty_color = (60, 30, 30)  # 비어있는 상태
                    base_full_color = (255, 80, 80)  # 가득 찬 상태
                    # 충전 진행률에 따른 색상 보간
                    token_color = (
                        int(base_empty_color[0] + (base_full_color[0] - base_empty_color[0]) * charge_progress),
                        int(base_empty_color[1] + (base_full_color[1] - base_empty_color[1]) * charge_progress),
                        int(base_empty_color[2] + (base_full_color[2] - base_empty_color[2]) * charge_progress)
                    )
                    glow_color = (
                        int(100 + 155 * charge_progress),
                        int(50 + 100 * charge_progress),
                        int(50 + 100 * charge_progress)
                    )
                    is_available = False
                else:
                    # 아직 충전 차례가 아님 - 완전히 비어있는 상태 (어두운 회색)
                    token_color = (40, 20, 20)  # 더 어두운 색
                    glow_color = (50, 25, 25)  # 글로우도 최소화
                    is_available = False
                    charge_progress = 0  # 충전 진행률 0으로 설정
            else:
                # 충전 타이머 없음 - 완전히 비어있는 상태
                token_color = (60, 30, 30)
                glow_color = (80, 40, 40)
                is_available = False
        # 글로우 효과 (토큰이 사용 가능할 때만)
        if is_available:
            # 글로우 효과를 위한 반투명 원
            glow_surface = pygame.Surface((token_radius * 4, token_radius * 4), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, (*glow_color, 60), 
                             (token_radius * 2, token_radius * 2), token_radius * 2)
            SCREEN.blit(glow_surface, (token_x - token_radius * 2, token_y - token_radius * 2))
        # 충전 중인 토큰의 물 차오르는 효과
        if not is_available and 'charge_progress' in locals() and 'is_charging' in locals() and is_charging and charge_progress > 0:
            # 배경 원 (비어있는 상태)
            draw.circle((40, 20, 20), (int(token_x), int(token_y)), token_radius)
            # 아래에서 위로 차오르는 물 효과
            if charge_progress > 0:
                # 충전 높이 계산 (아래에서 위로)
                fill_height = int(token_radius * 2 * charge_progress)
                # 원형 내부에 차오르는 사각형 영역 클리핑
                # 원의 하단부터 시작
                fill_y_start = token_y + token_radius - fill_height
                # 물결 효과를 위한 sin 파동
                wave_offset = math.sin(pygame.time.get_ticks() * 0.005) * 1
                # 채워진 부분 그리기 (원 안에서만)
                for y in range(int(fill_y_start), int(token_y + token_radius)):
                    # 현재 y 위치에서 원의 너비 계산
                    dy = abs(y - token_y)
                    if dy <= token_radius:
                        # 원의 방정식: x² + y² = r²
                        dx = math.sqrt(token_radius * token_radius - dy * dy)
                        # 물결 효과 추가
                        wave = wave_offset * (1 - (y - fill_y_start) / fill_height) if fill_height > 0 else 0
                        # 그라데이션 색상 (아래가 더 진함)
                        gradient_ratio = (y - fill_y_start) / fill_height if fill_height > 0 else 0
                        color_r = int(token_color[0] * (0.7 + 0.3 * gradient_ratio))
                        color_g = int(token_color[1] * (0.7 + 0.3 * gradient_ratio))
                        color_b = int(token_color[2] * (0.7 + 0.3 * gradient_ratio))
                        # 수평선 그리기
                        draw.line((color_r, color_g, color_b),
                                       (token_x - dx + wave, y),
                                       (token_x + dx + wave, y))
            # 테두리
            draw.circle((100, 50, 50), (int(token_x), int(token_y)), token_radius, 1)
            # 충전 펄스 효과 (반짝임)
            if charge_progress > 0.5:
                pulse_alpha = int(50 + 50 * math.sin(pygame.time.get_ticks() * 0.01))
                pulse_surface = pygame.Surface((token_radius * 2 + 4, token_radius * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(pulse_surface, (255, 100, 100, pulse_alpha),
                                 (token_radius + 2, token_radius + 2), token_radius + 1)
                SCREEN.blit(pulse_surface, (token_x - token_radius - 2, token_y - token_radius - 2))
        else:
            # 메인 토큰 원 (기본 상태)
            draw.circle(token_color, (int(token_x), int(token_y)), token_radius)
            # 토큰 테두리 (입체감)
            border_color = (200, 200, 200) if is_available else (80, 80, 80)
            draw.circle(border_color, (int(token_x), int(token_y)), token_radius, 1)
            # 하이라이트 효과 (작은 흰색 점)
            if is_available:
                highlight_x = token_x - token_radius // 3
                highlight_y = token_y - token_radius // 3
                draw.circle((255, 255, 255), 
                                 (int(highlight_x), int(highlight_y)), token_radius // 4)
def draw_crocodile_boss(boss_x=0, boss_y=0, ball_x=0, ball_y=0):
    """🐊 스테이지 2 악어장군 - 공을 추적하는 눈동자"""
    # 기본 악어 이미지 생성
    crocodile_surface = pygame.Surface((BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT), pygame.SRCALPHA)
    # 기존 이미지가 있으면 사용, 없으면 기본 그래픽 생성
    try:
        crocodile_surface.blit(BOSS_IMG_STAGE2, (0, 0))
    except:
        # 기본 악어 몸체 (녹색)
        pygame.draw.rect(crocodile_surface, (34, 139, 34), (10, 20, BOSS_IMG_WIDTH-20, BOSS_IMG_HEIGHT-40), border_radius=15)
        pygame.draw.rect(crocodile_surface, (0, 100, 0), (10, 20, BOSS_IMG_WIDTH-20, BOSS_IMG_HEIGHT-40), 3, border_radius=15)
    # 눈 위치 설정 (악어 이미지의 대략적인 눈 위치)
    left_eye_x = BOSS_IMG_WIDTH // 2 - 30
    right_eye_x = BOSS_IMG_WIDTH // 2 + 30
    eye_y = BOSS_IMG_HEIGHT // 2 - 5
    # 눈 크기 (더 크게 조정)
    eye_radius = 18
    pupil_radius = 8
    # 공과 눈의 각도 계산
    def calculate_pupil_position(eye_x, eye_y):
        # 보스 패들의 실제 화면상 위치 계산
        actual_eye_x = boss_x + eye_x - BOSS_IMG_WIDTH // 2
        actual_eye_y = boss_y + eye_y - BOSS_IMG_HEIGHT // 2
        # 공과의 각도 계산
        dx = ball_x - actual_eye_x
        dy = ball_y - actual_eye_y
        distance = math.sqrt(dx**2 + dy**2)
        if distance > 0:
            # 눈동자가 움직일 수 있는 최대 거리
            max_distance = eye_radius - pupil_radius - 2
            # 방향 벡터 정규화
            dx_norm = dx / distance
            dy_norm = dy / distance
            # 눈동자 위치 계산 (눈 안에서만 움직이도록 제한)
            pupil_offset_x = dx_norm * min(max_distance, distance * 0.1)
            pupil_offset_y = dy_norm * min(max_distance, distance * 0.1)
            return pupil_offset_x, pupil_offset_y
        return 0, 0
    # 왼쪽 눈 그리기
    pygame.draw.circle(crocodile_surface, (255, 255, 255), (left_eye_x, eye_y), eye_radius)
    pygame.draw.circle(crocodile_surface, (50, 50, 50), (left_eye_x, eye_y), eye_radius, 2)
    # 왼쪽 눈동자
    left_pupil_offset_x, left_pupil_offset_y = calculate_pupil_position(left_eye_x, eye_y)
    pygame.draw.circle(crocodile_surface, (0, 0, 0), 
                      (int(left_eye_x + left_pupil_offset_x), 
                       int(eye_y + left_pupil_offset_y)), pupil_radius)
    # 눈동자 하이라이트
    pygame.draw.circle(crocodile_surface, (255, 255, 255), 
                      (int(left_eye_x + left_pupil_offset_x - 2), 
                       int(eye_y + left_pupil_offset_y - 2)), 2)
    # 오른쪽 눈 그리기
    pygame.draw.circle(crocodile_surface, (255, 255, 255), (right_eye_x, eye_y), eye_radius)
    pygame.draw.circle(crocodile_surface, (50, 50, 50), (right_eye_x, eye_y), eye_radius, 2)
    # 오른쪽 눈동자
    right_pupil_offset_x, right_pupil_offset_y = calculate_pupil_position(right_eye_x, eye_y)
    pygame.draw.circle(crocodile_surface, (0, 0, 0), 
                      (int(right_eye_x + right_pupil_offset_x), 
                       int(eye_y + right_pupil_offset_y)), pupil_radius)
    # 눈동자 하이라이트
    pygame.draw.circle(crocodile_surface, (255, 255, 255), 
                      (int(right_eye_x + right_pupil_offset_x - 2), 
                       int(eye_y + right_pupil_offset_y - 2)), 2)
    # 악어 특유의 세로 동공 효과 추가
    for eye_x, pupil_x, pupil_y in [(left_eye_x, left_pupil_offset_x, left_pupil_offset_y), 
                                      (right_eye_x, right_pupil_offset_x, right_pupil_offset_y)]:
        pygame.draw.ellipse(crocodile_surface, (0, 0, 0),
                           (int(eye_x + pupil_x - 2), 
                            int(eye_y + pupil_y - pupil_radius),
                            4, pupil_radius * 2))
    return crocodile_surface
def draw_aircraft_carrier_boss(boss_speed=0, boss_x=0):
    """⚔️ 스테이지 6 울트라 배틀크루저 - 최강의 전함 보스 패들"""
    import random
    global laser_cannon_angle, laser_charging, laser_cannon_active, laser_charge_start, shield_antenna_active, stage6_boss_hit_timer, stage6_boss_hit_flash
    # 🎯 소닉 스타일 피격 효과 타이머 업데이트
    if stage6_boss_hit_timer > 0:
        stage6_boss_hit_timer -= 1
        # 깜빡임 효과 (매 4프레임마다 on/off)
        stage6_boss_hit_flash = (stage6_boss_hit_timer // 4) % 2 == 0
        if stage6_boss_hit_timer <= 0:
            stage6_boss_hit_flash = False
    carrier_width = 220
    carrier_height = 85
    # 배틀크루저 표면 생성
    carrier_surface = pygame.Surface((carrier_width, carrier_height), pygame.SRCALPHA)
    # 체력에 따른 손상 정도 계산
    damage_ratio = 1.0 - (boss_current_health / boss_max_health)
    time_now = pygame.time.get_ticks()
    # 🌟 체력 기반 에너지 쉴드 효과 (제거)
    # 파란색 테두리가 나타나지 않도록 주석 처리
    # if boss_current_health > 10:
    #     # 외곽 에너지 쉴드 (체력이 높을수록 강함)
    #     shield_alpha = int(20 + (boss_current_health / boss_max_health) * 30)
    #     shield_color = (100, 150, 255, shield_alpha)
    #     for i in range(3):
    #         pygame.draw.rect(carrier_surface, shield_color, 
    #                        (3-i, 3-i, carrier_width-6+i*2, carrier_height-6+i*2), 1)
    # === 메인 선체 (5단계 레이어드 구조로 입체감 강화) ===
    # 🎯 소닉 스타일 피격 효과 적용 (붉은색 오버레이)
    def apply_hit_effect(color):
        if stage6_boss_hit_flash:
            # 붉은색으로 강하게 변환 (소닉 스타일)
            r, g, b = color
            return (min(255, r + 120), max(0, g - 30), max(0, b - 30))
        return color
    # 최하부 그림자 레이어
    shadow_color = apply_hit_effect((35, 40, 45))
    pygame.draw.rect(carrier_surface, shadow_color, (6, 48, carrier_width-12, 34))
    # 하부 선체 (진한 금속색 + 그라데이션 효과)
    hull_base_color = apply_hit_effect((65, 75, 85) if damage_ratio < 0.7 else (55, 60, 70))
    pygame.draw.rect(carrier_surface, hull_base_color, (8, 45, carrier_width-16, 32))
    # 하부 하이라이트
    pygame.draw.line(carrier_surface, apply_hit_effect((75, 85, 95)), (8, 46), (carrier_width-8, 46), 1)
    # 중하부 전환 레이어
    trans_color = apply_hit_effect((72, 82, 95) if damage_ratio < 0.6 else (62, 70, 78))
    pygame.draw.rect(carrier_surface, trans_color, (10, 40, carrier_width-20, 28))
    # 중부 선체 (조금 밝은 색)
    hull_mid_color = apply_hit_effect((80, 90, 105) if damage_ratio < 0.5 else (70, 75, 85))
    pygame.draw.rect(carrier_surface, hull_mid_color, (12, 35, carrier_width-24, 25))
    # 중부 하이라이트
    pygame.draw.line(carrier_surface, apply_hit_effect((90, 100, 115)), (12, 36), (carrier_width-12, 36), 1)
    # 상부 선체 (가장 밝은 색 + 메탈릭 효과)
    hull_top_color = apply_hit_effect((95, 110, 125) if damage_ratio < 0.3 else (85, 95, 110))
    pygame.draw.rect(carrier_surface, hull_top_color, (16, 25, carrier_width-32, 20))
    # 상부 메탈릭 하이라이트
    pygame.draw.line(carrier_surface, (115, 130, 145), (16, 26), (carrier_width-16, 26), 1)
    pygame.draw.line(carrier_surface, (105, 120, 135), (16, 28), (carrier_width-16, 28), 1)
    # === 배틀크루저 특유의 고급 장갑판 시스템 ===
    # 반응형 장갑판 패널들 (체력에 따라 색상 변화)
    panel_base = (110, 125, 140) if boss_current_health > 10 else (90, 100, 115)
    panel_glow = (130, 160, 200) if boss_current_health > 12 else (110, 135, 160)
    for i in range(8):  # 더 많은 패널
        panel_x = 15 + i * 25
        if panel_x < carrier_width - 35:
            # 패널 외곽 (3D 효과)
            pygame.draw.rect(carrier_surface, (70, 80, 90), (panel_x-1, 27, 23, 17))
            pygame.draw.rect(carrier_surface, panel_base, (panel_x, 28, 21, 15))
            pygame.draw.rect(carrier_surface, panel_glow, (panel_x, 28, 21, 15), 1)
            # 패널 내부 고급 디테일
            # 에너지 라인 (펄스 효과)
            pulse = abs(math.sin(time_now * 0.003 + i * 0.5))
            line_color = (int(120 + pulse * 30), int(130 + pulse * 40), int(145 + pulse * 50))
            pygame.draw.line(carrier_surface, line_color, 
                           (panel_x + 2, 30), (panel_x + 19, 30), 1)
            pygame.draw.line(carrier_surface, line_color, 
                           (panel_x + 2, 35), (panel_x + 19, 35), 1)
            pygame.draw.line(carrier_surface, line_color, 
                           (panel_x + 2, 40), (panel_x + 19, 40), 1)
            # 중앙 에너지 코어
            core_x = panel_x + 10
            core_y = 35
            pygame.draw.circle(carrier_surface, panel_glow, (core_x, core_y), 2)
            if boss_current_health > 8:
                pygame.draw.circle(carrier_surface, (180, 210, 255), (core_x, core_y), 1)
    # === 추가 몸통 디테일 ===
    # 구조적 리벳 라인들
    rivet_color = (130, 140, 155)
    # 수평 구조 라인들
    for y_pos in [30, 40, 50, 60]:
        pygame.draw.line(carrier_surface, rivet_color, 
                        (15, y_pos), (carrier_width - 15, y_pos), 1)
        # 리벳 포인트들
        for x_pos in range(25, carrier_width - 20, 20):
            pygame.draw.circle(carrier_surface, rivet_color, (x_pos, y_pos), 1)
    # 수직 구조 라인들
    for x_pos in range(30, carrier_width - 30, 35):
        pygame.draw.line(carrier_surface, rivet_color, 
                        (x_pos, 28), (x_pos, 65), 1)
    # 장갑판 섹션 구분선
    section_color = (100, 115, 130)
    section_positions = [50, 90, 130, 170]
    for sect_x in section_positions:
        if sect_x < carrier_width - 20:
            pygame.draw.line(carrier_surface, section_color, 
                           (sect_x, 25), (sect_x, 70), 2)
            # 섹션 하이라이트
            pygame.draw.line(carrier_surface, (140, 150, 165), 
                           (sect_x + 1, 25), (sect_x + 1, 70), 1)
    # 웨폰 하드포인트 마운트
    hardpoint_positions = [(40, 45), (80, 45), (120, 45), (160, 45)]
    for hx, hy in hardpoint_positions:
        if hx < carrier_width - 25:
            # 하드포인트 베이스
            pygame.draw.rect(carrier_surface, (75, 85, 100), (hx-3, hy-3, 6, 6))
            pygame.draw.rect(carrier_surface, (95, 105, 120), (hx-2, hy-2, 4, 4))
            # 마운트 포인트
            pygame.draw.circle(carrier_surface, (115, 125, 140), (hx, hy), 2)
            pygame.draw.circle(carrier_surface, (135, 145, 160), (hx, hy), 1)
    # 배기구/벤트 시스템
    vent_positions = [(35, 55), (65, 55), (95, 55), (125, 55), (155, 55)]
    for vx, vy in vent_positions:
        if vx < carrier_width - 20:
            # 벤트 그릴
            for i in range(3):
                pygame.draw.line(carrier_surface, (60, 70, 85), 
                               (vx + i*2, vy), (vx + i*2, vy + 8), 1)
            # 벤트 프레임
            pygame.draw.rect(carrier_surface, (80, 90, 105), (vx-1, vy-1, 7, 10), 1)
    # 센서 어레이 시스템
    sensor_positions = [(45, 20), (75, 20), (105, 20), (135, 20)]
    for sx, sy in sensor_positions:
        if sx < carrier_width - 15:
            # 센서 돔
            pygame.draw.circle(carrier_surface, (90, 110, 130), (sx, sy), 3)
            pygame.draw.circle(carrier_surface, (110, 130, 150), (sx, sy), 2)
            # 센서 렌즈
            pygame.draw.circle(carrier_surface, (150, 170, 190), (sx-1, sy-1), 1)
    # === 야마토 캐논급 주포 터렛 시스템 ===
    # 듀얼 배럴 주포 터렛 (더 강력한 느낌)
    turret_positions = [(30, 38), (65, 36), (100, 36), (135, 38), (170, 38)]
    for idx, (tx, ty) in enumerate(turret_positions):
        if tx < carrier_width - 25:
            # 터렛 베이스 (다층 구조)
            pygame.draw.circle(carrier_surface, (50, 60, 70), (tx, ty), 10)
            pygame.draw.circle(carrier_surface, (70, 80, 90), (tx, ty), 8)
            pygame.draw.circle(carrier_surface, (90, 100, 110), (tx, ty), 6)
            # 듀얼 포신 (쌍발)
            gun_angle = math.sin(time_now * 0.00001 + tx * 0.01) * 2  # 극도로 느린 움직임 (100배 느리게, 각도도 작게)
            for barrel_offset in [-2, 2]:  # 두 개의 포신
                barrel_x = tx + barrel_offset
                gun_end_x = barrel_x + 15 * math.cos(math.radians(gun_angle))
                gun_end_y = ty + 15 * math.sin(math.radians(gun_angle)) + barrel_offset
                # 포신 그라데이션 (굵기 변화)
                pygame.draw.line(carrier_surface, (40, 50, 60), 
                               (barrel_x, ty), (gun_end_x, gun_end_y), 4)
                pygame.draw.line(carrier_surface, (60, 70, 80), 
                               (barrel_x, ty), (gun_end_x-2, gun_end_y), 3)
                pygame.draw.line(carrier_surface, (80, 90, 100), 
                               (barrel_x, ty), (gun_end_x-4, gun_end_y), 2)
                # 포구 플래시 제거 (사용자 요청 - 주황색 빛 제거)
                # if boss_current_health > 8 and random.random() < 0.1:
                #     flash_color = (255, 200, 100)
                #     pygame.draw.circle(carrier_surface, flash_color, 
                #                      (int(gun_end_x), int(gun_end_y)), 3)
            # 터렛 중앙 에너지 코어
            pygame.draw.circle(carrier_surface, (150, 180, 210), (tx, ty), 3)
            pygame.draw.circle(carrier_surface, (180, 210, 240), (tx-1, ty-1), 1)
    # === 사령부 브릿지 (미래형 다층 구조) ===
    bridge_x = carrier_width - 75
    # 브릿지 기초 플랫폼
    pygame.draw.rect(carrier_surface, (55, 65, 75), (bridge_x-2, 18, 54, 32))
    pygame.draw.rect(carrier_surface, (75, 85, 100), (bridge_x, 15, 50, 30))
    # 중간층 (지휘소)
    bridge_mid = (95, 105, 120) if boss_current_health > 5 else (75, 85, 95)
    pygame.draw.rect(carrier_surface, bridge_mid, (bridge_x + 5, 12, 40, 22))
    # 중간층 디테일
    for i in range(3):
        pygame.draw.line(carrier_surface, (115, 125, 140), 
                        (bridge_x + 8 + i*12, 14), (bridge_x + 8 + i*12, 30), 1)
    # 최상층 (전망대)
    bridge_top = (105, 115, 130) if boss_current_health > 3 else (85, 95, 105)
    pygame.draw.rect(carrier_surface, bridge_top, (bridge_x + 10, 8, 30, 15))
    # 지휘탑 안테나 타워
    pygame.draw.rect(carrier_surface, (115, 125, 140), (bridge_x + 23, 3, 4, 8))
    pygame.draw.line(carrier_surface, (135, 145, 160), (bridge_x + 25, 3), (bridge_x + 25, 0), 2)
    # 파노라마 브릿지 창문 시스템
    for i in range(5):
        window_x = bridge_x + 10 + i * 6
        # 창문 프레임
        pygame.draw.rect(carrier_surface, (100, 110, 120), (window_x-1, 9, 6, 10), 1)
        # 내부 블루 글로우 (커맨드 센터 느낌)
        glow_intensity = int(150 + 50 * abs(math.sin(time_now * 0.002 + i * 0.3)))
        pygame.draw.rect(carrier_surface, (glow_intensity, glow_intensity + 30, 200), 
                        (window_x, 10, 4, 8))
        # 창문 반사 및 디테일
        pygame.draw.line(carrier_surface, (200, 220, 255), 
                        (window_x, 10), (window_x + 2, 10), 1)
        # 내부 활동 표시 제거 (사용자 요청 - 주황색 깜빡임 제거)
        # if random.random() < 0.05:
        #     pygame.draw.circle(carrier_surface, (255, 200, 100), (window_x + 2, 14), 1)
    # === 폐이저 어레이 레이더 시스템 ===
    # 주 레이더 돔 (입체적 구조)
    radar_x = bridge_x + 25
    # 레이더 베이스
    pygame.draw.circle(carrier_surface, (80, 90, 100), (radar_x, 8), 7)
    pygame.draw.circle(carrier_surface, (120, 140, 160), (radar_x, 8), 5)
    pygame.draw.circle(carrier_surface, (140, 160, 180), (radar_x, 8), 3)
    # 멀티 레이어 레이더 스캔 효과 (극도로 천천히 회전)
    radar_angle = time_now * 0.00005  # 0.0003 → 0.00005 (60배 더 느리게)
    for r in range(1, 4):  # 여러 개의 스캔 라인
        angle_offset = radar_angle + r * 0.2  # 0.5 → 0.2 (라인 간격도 좁게)
        scan_range = 6 + r * 2
        antenna_end_x = radar_x + scan_range * math.cos(angle_offset)
        antenna_end_y = 8 + scan_range * math.sin(angle_offset)
        # 색상도 더 어둡게 조정하여 덜 눈에 띄게
        scan_color = (min(255, 80 + r*15), min(255, 100 + r*15), min(255, 120 + r*15))
        pygame.draw.line(carrier_surface, scan_color, 
                        (radar_x, 8), (antenna_end_x, antenna_end_y), 2)  # 두께도 줄임
    # 중앙 레이더 코어 (펄스 빛)
    pulse = abs(math.sin(time_now * 0.005))
    core_color = (int(180 + pulse * 75), int(200 + pulse * 55), 255)
    pygame.draw.circle(carrier_surface, core_color, (radar_x, 8), 2)
    # 보조 통신 안테나들
    for i, ant_x in enumerate([bridge_x + 10, bridge_x + 40]):
        ant_height = 5 - i
        pygame.draw.line(carrier_surface, (160, 170, 180), 
                        (ant_x, 15), (ant_x, ant_height), 2)
        # 안테나 팁
        pygame.draw.circle(carrier_surface, (200, 210, 220), (ant_x, ant_height), 1)
    # === 쉴드 안테나 시스템 (사용자가 그린 디자인 참고) ===
    # 안테나 위치 (함선 앞쪽 중앙)
    shield_antenna_x = carrier_width // 2
    shield_antenna_y = 75  # 함선 앞쪽
    # 안테나 베이스 (둥근 돔)
    pygame.draw.circle(carrier_surface, (100, 110, 120), (shield_antenna_x, shield_antenna_y), 5)
    pygame.draw.circle(carrier_surface, (140, 150, 160), (shield_antenna_x, shield_antenna_y), 3)
    # 안테나 기둥
    pygame.draw.line(carrier_surface, (180, 190, 200), 
                    (shield_antenna_x, shield_antenna_y), 
                    (shield_antenna_x, shield_antenna_y - 8), 2)
    # 안테나 팁 (쉴드 생성기)
    tip_glow = abs(math.sin(time_now * 0.003)) * 100
    if shield_antenna_active:
        # 쉴드 활성화 시 밝게 빛남
        pygame.draw.circle(carrier_surface, (200, 220, 255), 
                          (shield_antenna_x, shield_antenna_y - 8), 4)
        pygame.draw.circle(carrier_surface, (255, 255, 255), 
                          (shield_antenna_x, shield_antenna_y - 8), 2)
    else:
        # 비활성화 시 약하게 빛남
        glow_value = min(255, int(150 + tip_glow))
        glow_color = (glow_value, min(255, int(170 + tip_glow)), min(255, int(200 + tip_glow)))
        pygame.draw.circle(carrier_surface, glow_color, 
                          (shield_antenna_x, shield_antenna_y - 8), 3)
        pygame.draw.circle(carrier_surface, (180, 200, 220), 
                          (shield_antenna_x, shield_antenna_y - 8), 1)
    # === 플라즈마 레이저 캐논 ===
    # 레이저 캐논 위치 (함선 아래쪽 중앙)
    laser_cannon_x = carrier_width // 2
    laser_cannon_y = 85  # 함선 아래쪽
    # 캐논 베이스 (회전 가능)
    pygame.draw.circle(carrier_surface, (70, 80, 90), (laser_cannon_x, laser_cannon_y), 8)
    pygame.draw.circle(carrier_surface, (90, 100, 110), (laser_cannon_x, laser_cannon_y), 6)
    # 캐논 포신 (각도에 따라 회전)
    if laser_charging or laser_cannon_active:
        # 충전 중이거나 발사 중일 때
        cannon_angle_rad = math.radians(laser_cannon_angle)
        barrel_end_x = laser_cannon_x + int(math.cos(cannon_angle_rad) * 12)
        barrel_end_y = laser_cannon_y + int(math.sin(cannon_angle_rad) * 12)
        # 포신 그리기
        pygame.draw.line(carrier_surface, (50, 60, 70), 
                        (laser_cannon_x, laser_cannon_y), 
                        (barrel_end_x, barrel_end_y), 5)
        pygame.draw.line(carrier_surface, (70, 80, 90), 
                        (laser_cannon_x, laser_cannon_y), 
                        (barrel_end_x, barrel_end_y), 3)
        # 충전 중 효과
        if laser_charging:
            charge_progress = (time_now - laser_charge_start) / 1500.0  # 0 ~ 1
            charge_glow = int(255 * charge_progress)
            # 포구에 충전 빛
            pygame.draw.circle(carrier_surface, 
                             (min(255, charge_glow), min(255, charge_glow + 50), 255), 
                             (barrel_end_x, barrel_end_y), int(3 + charge_progress * 3))
            # 파란색 전기 스파크
            for _ in range(int(5 * charge_progress)):
                spark_angle = random.uniform(0, math.pi * 2)
                spark_dist = random.uniform(5, 15)
                spark_x = barrel_end_x + int(math.cos(spark_angle) * spark_dist)
                spark_y = barrel_end_y + int(math.sin(spark_angle) * spark_dist)
                pygame.draw.circle(carrier_surface, (150, 200, 255), (spark_x, spark_y), 1)
    else:
        # 기본 상태 (아래 방향)
        pygame.draw.line(carrier_surface, (50, 60, 70), 
                        (laser_cannon_x, laser_cannon_y), 
                        (laser_cannon_x, laser_cannon_y + 12), 5)
        pygame.draw.line(carrier_surface, (70, 80, 90), 
                        (laser_cannon_x, laser_cannon_y), 
                        (laser_cannon_x, laser_cannon_y + 12), 3)
    # 캐논 중심 코어
    pygame.draw.circle(carrier_surface, (110, 120, 130), (laser_cannon_x, laser_cannon_y), 3)
    if laser_charging or laser_cannon_active:
        # 충전/발사 중 밝게
        pygame.draw.circle(carrier_surface, (150, 200, 255), (laser_cannon_x, laser_cannon_y), 2)
    # === 비행대대 편대 시스템 (체력 기반 전투기 배치) ===
    max_fighters = 12  # 더 많은 전투기
    current_fighters = int(max_fighters * (boss_current_health / boss_max_health))
    # V자 포메이션 전투기 배열
    fighter_positions = [
        # 전방 편대
        (20, 32), (35, 30), (50, 28), (65, 28), (80, 30), (95, 32),
        # 후방 편대
        (25, 35), (40, 33), (55, 31), (70, 31), (85, 33), (100, 35)
    ]
    for i in range(current_fighters):
        if i < len(fighter_positions):
            fx, fy = fighter_positions[i]
            if fx < carrier_width - 15:
                # 하이테크 인터셉터 스타일
                # 동체 (더 날렵한 형태)
                fighter_body = (80, 95, 110) if i < 6 else (70, 85, 100)  # 전방편대가 더 밝음
                pygame.draw.polygon(carrier_surface, fighter_body, 
                                   [(fx, fy), (fx+12, fy+1), (fx+10, fy+3), (fx+2, fy+3)])
                # 날개 (격납고 형태)
                wing_color = (65, 80, 95)
                # 왼쪽 날개
                pygame.draw.polygon(carrier_surface, wing_color,
                                   [(fx+3, fy+1), (fx, fy-2), (fx+1, fy+1)])
                # 오른쪽 날개
                pygame.draw.polygon(carrier_surface, wing_color,
                                   [(fx+9, fy+1), (fx+12, fy-2), (fx+11, fy+1)])
                # 콕핏 하이라이트
                pygame.draw.circle(carrier_surface, (120, 140, 160), (fx+6, fy+1), 1)
                # 미사일 마운트 제거 (사용자 요청 - 주황색 선 제거)
                # if boss_current_health > 10:
                #     pygame.draw.line(carrier_surface, (200, 100, 50), 
                #                    (fx+2, fy+3), (fx+2, fy+4), 1)
                #     pygame.draw.line(carrier_surface, (200, 100, 50), 
                #                    (fx+10, fy+3), (fx+10, fy+4), 1)
    # === 플라즈마 부스트 엔진 시스템 ===
    # 대형 슬링스트림 엔진 4기
    engine_positions = [(3, 48), (3, 56), (3, 64), (3, 72)]
    for idx, (ex, ey) in enumerate(engine_positions):
        # 엔진 노즐 하우징 (입체적)
        pygame.draw.rect(carrier_surface, (40, 50, 60), (ex, ey-1, 18, 10))
        pygame.draw.rect(carrier_surface, (60, 70, 80), (ex, ey, 16, 8))
        pygame.draw.rect(carrier_surface, (80, 90, 100), (ex+2, ey+1, 12, 6))
        # 플라즈마 제트 효과 (보스 움직임에 따라 동적으로)
        boss_velocity = abs(boss_speed)
        # 보스가 움직일 때만 제트 효과 표시
        if boss_velocity > 0.3:  # 더 민감하게 반응
            # 움직임 속도에 비례한 제트 길이 (더 길게)
            jet_length = int(15 + boss_velocity * 8)  # 더 긴 화염
            jet_intensity = min(255, int(180 + boss_velocity * 30))  # 더 밝게
            # 애니메이션 효과를 위한 오프셋
            flame_offset = (pygame.time.get_ticks() // 50) % 3
            # 외곽 글로우 효과 (더 크게)
            glow_color = (255, 100, 50, 30)  # 주황색 글로우
            for g in range(3):
                pygame.draw.line(carrier_surface, (255, 80 - g*20, 30), 
                                (ex, ey + 4), (ex - jet_length - g*2, ey + 4), 5 - g)
            # 메인 화염 (더 화려하게)
            # 외곽 화염 (빨간색-주황색)
            for i in range(3):
                offset_y = flame_offset - 1 + i
                flame_alpha = 200 - i * 50
                flame_red = min(255, jet_intensity + i * 10)
                flame_color = (flame_red, max(50, jet_intensity - 100 - i*30), 20)
                pygame.draw.line(carrier_surface, flame_color, 
                                (ex-1, ey + 3 + offset_y), 
                                (ex - jet_length - i*2, ey + 3 + offset_y), 4 - i)
            # 중간층 (주황색-노란색)
            mid_color = (255, min(255, jet_intensity + 30), 80)
            pygame.draw.line(carrier_surface, mid_color, 
                            (ex, ey + 4), (ex - jet_length*2//3, ey + 4), 3)
            # 코어 (밝은 노란색-흰색)
            core_color = (255, 255, min(255, 180 + boss_velocity * 20))
            pygame.draw.line(carrier_surface, core_color, 
                            (ex+1, ey + 4), (ex - jet_length//2, ey + 4), 2)
            # 플라즈마 번개 효과 (가끔씩)
            if random.random() < 0.3:
                bolt_x = ex - random.randint(5, jet_length)
                bolt_y = ey + 4 + random.randint(-2, 2)
                pygame.draw.line(carrier_surface, (200, 200, 255),
                                (ex, ey + 4), (bolt_x, bolt_y), 1)
            # 불꽃 파티클 효과 (더 많이)
            particle_count = int(3 + boss_velocity * 2)
            for _ in range(particle_count):
                spark_x = ex - random.randint(0, jet_length + 10)
                spark_y = ey + 4 + random.randint(-3, 3)
                spark_size = random.choice([1, 1, 2])
                spark_color = random.choice([
                    (255, random.randint(180, 255), random.randint(0, 100)),
                    (255, random.randint(150, 200), 50),
                    (255, 255, random.randint(150, 255))
                ])
                pygame.draw.circle(carrier_surface, spark_color, (spark_x, spark_y), spark_size)
    # === 포인트 디펜스 미사일 시스템 ===
    # 자동 방어 미사일 터렛
    defense_positions = [(25, 22), (45, 20), (65, 22), (85, 20), 
                        (105, 22), (125, 20), (145, 22), (165, 20)]
    global turret_angles, turret_missiles, last_missile_time
    current_time = pygame.time.get_ticks()
    for idx, (dx, dy) in enumerate(defense_positions):
        if dx < carrier_width - 15:
            # 터렛 ID 생성
            turret_id = f"turret_{idx}_{dx}_{dy}"
            # 터렛 각도 초기화 및 업데이트
            if turret_id not in turret_angles:
                turret_angles[turret_id] = random.randint(0, 360)
            # 천천히 좌우로 움직이는 포신 (아래를 향하되 각도가 변함)
            turret_angles[turret_id] = (turret_angles[turret_id] + 1) % 120  # 0~120도 범위
            barrel_angle = 60 + turret_angles[turret_id]  # 60~180도 (대략 아래 방향)
            angle_rad = math.radians(barrel_angle)
            # 터렛 베이스
            pygame.draw.circle(carrier_surface, (65, 75, 85), (dx, dy), 4)
            pygame.draw.circle(carrier_surface, (85, 95, 105), (dx, dy), 3)
            # 아래를 향하는 포신 그리기
            barrel_length = 10
            barrel_end_x = dx + int(math.cos(angle_rad) * barrel_length)
            barrel_end_y = dy + int(math.sin(angle_rad) * barrel_length)
            pygame.draw.line(carrier_surface, (90, 100, 110), (dx, dy), (barrel_end_x, barrel_end_y), 3)
            # 포구 끝부분 (더 크게)
            pygame.draw.circle(carrier_surface, (120, 130, 140), (barrel_end_x, barrel_end_y), 3)
            pygame.draw.circle(carrier_surface, (100, 110, 120), (barrel_end_x, barrel_end_y), 2)
            # 미사일 발사 (터렛별로 다른 타이밍)
            if boss_current_health > 0 and random.random() < 0.0015 and boss_confused_timer == 0:  # 0.15% 확률로 매 프레임 발사 (발사 빈도 더 줄임, 혼란 상태가 아닐 때만)
                # 미사일 발사 위치 (보스 패들 절대 좌표로 변환)
                missile_x = boss_x + dx
                missile_y = BOSS_Y + dy + 10  # 포신 끝에서 발사
                # 아래 방향으로 랜덤한 각도로 발사 (수직에서 ±30도 범위)
                base_angle = 90  # 아래 방향 (90도)
                spread_angle = random.randint(-30, 30)  # ±30도 랜덤 스프레드
                final_angle = base_angle + spread_angle
                angle_for_missile = math.radians(final_angle)
                # 미사일 속도 설정 (랜덤 속도)
                missile_speed = random.uniform(2, 4)  # 2~4 사이 랜덤 속도
                missile_vx = math.cos(angle_for_missile) * missile_speed
                missile_vy = math.sin(angle_for_missile) * missile_speed
                # 미사일 추가
                new_missile = {
                    'x': missile_x,
                    'y': missile_y,
                    'vx': missile_vx,
                    'vy': missile_vy,
                    'age': 0,
                    'turret_id': turret_id
                }
                turret_missiles.append(new_missile)
            # 터렛 중앙 렌즈
            lens_color = (100, 100, 100)  # 회색
            pygame.draw.circle(carrier_surface, lens_color, (dx, dy), 1)
            pygame.draw.circle(carrier_surface, (100, 110, 120), (dx, dy), 2)
    # === 울트라 배틀크루저 전투 손상 시스템 ===
    if damage_ratio > 0.2:
        # 시스템 오작동 스파크 (안정적인 효과)
        for _ in range(int(damage_ratio * 8)):
            spark_x = random.randint(10, carrier_width - 10)
            spark_y = random.randint(25, 75)
            # 전기 스파크 색상 변화
            spark_type = random.choice(['electric', 'plasma', 'fire'])
            if spark_type == 'electric':
                spark_color = (150, 200, 255)  # 전기 파란색
            elif spark_type == 'plasma':
                spark_color = (255, 150, 255)  # 플라즈마 보라색
            else:
                spark_color = (255, 200, 100)  # 화염 노란색
            pygame.draw.circle(carrier_surface, spark_color, (spark_x, spark_y), 1)
    if damage_ratio > 0.4:
        # 장갑판 균열 및 손상
        for _ in range(int(damage_ratio * 5)):
            crack_x = random.randint(20, carrier_width - 20)
            crack_y = random.randint(30, 65)
            crack_length = random.randint(5, 15)
            crack_end_x = crack_x + random.randint(-crack_length, crack_length)
            crack_end_y = crack_y + random.randint(-5, 5)
            pygame.draw.line(carrier_surface, (40, 45, 50), 
                           (crack_x, crack_y), (crack_end_x, crack_end_y), 1)
    if damage_ratio > 0.5:
        # 화재 및 플라즈마 누출
        for _ in range(int(damage_ratio * 7)):
            leak_x = random.randint(15, carrier_width - 15)
            leak_y = random.randint(30, 70)
            if random.random() < 0.6:
                # 화재 효과 (계층적 화염)
                pygame.draw.circle(carrier_surface, (255, 100, 0), (leak_x, leak_y), 3)
                pygame.draw.circle(carrier_surface, (255, 150, 0), (leak_x, leak_y), 2)
                pygame.draw.circle(carrier_surface, (255, 200, 50), (leak_x, leak_y), 1)
            else:
                # 플라즈마 누출 (파란색 에너지)
                pygame.draw.circle(carrier_surface, (100, 150, 255), (leak_x, leak_y), 2)
                pygame.draw.circle(carrier_surface, (150, 200, 255), (leak_x, leak_y), 1)
            # 연기 효과
            if random.random() < 0.5:
                smoke_x = leak_x + random.randint(-5, 5)
                smoke_y = leak_y - random.randint(3, 10)
                pygame.draw.circle(carrier_surface, (50, 50, 50), (smoke_x, smoke_y), 2)
    # === 에너지 쉴드 효과 (제거) ===
    # 파란색 테두리가 나타나지 않도록 주석 처리
    # if damage_ratio < 0.3:  # 체력이 70% 이상일 때
    #     shield_alpha = int(30 + 20 * abs(math.sin(time_now * 0.005)))
    #     shield_color = (100, 150, 255, shield_alpha)
    #     # 쉴드 윤곽선
    #     pygame.draw.rect(carrier_surface, shield_color[:3], 
    #                     (3, 20, carrier_width - 6, carrier_height - 25), 2)
    #     # 쉴드 헥사곤 패턴
    #     for i in range(0, carrier_width - 10, 20):
    #         for j in range(0, carrier_height - 20, 15):
    #             if random.random() < 0.3:
    #                 hex_x, hex_y = 8 + i, 25 + j
    #                 pygame.draw.circle(carrier_surface, shield_color[:3], (hex_x, hex_y), 3, 1)
    # 🔥 체력에 따른 손상 효과 (연기, 화염)
    health_percent = (boss_current_health / boss_max_health) * 100
    # 체력 50% 이하: 연기 효과
    if health_percent <= 50:
        # 연기 파티클 생성
        smoke_points = []
        if health_percent <= 10:
            smoke_count = 12  # 체력 10% 이하: 매우 많은 연기
        elif health_percent <= 20:
            smoke_count = 8   # 체력 20% 이하: 많은 연기
        elif health_percent <= 30:
            smoke_count = 5   # 체력 30% 이하: 중간 연기
        else:
            smoke_count = 3   # 체력 50% 이하: 약간의 연기
        # 랜덤 위치에서 연기 생성
        for _ in range(smoke_count):
            smoke_x = random.randint(20, carrier_width - 20)
            smoke_y = random.randint(30, 60)
            smoke_points.append((smoke_x, smoke_y))
        # 연기 그리기
        for smoke_x, smoke_y in smoke_points:
            # 여러 크기의 연기 구름
            for i in range(3):
                smoke_size = random.randint(8, 15) + i * 3
                smoke_alpha = random.randint(20, 60) - i * 10
                smoke_color = (60 + i * 20, 60 + i * 20, 60 + i * 20, smoke_alpha)
                # 연기 원 그리기
                smoke_circle = pygame.Surface((smoke_size * 2, smoke_size * 2), pygame.SRCALPHA)
                pygame.draw.circle(smoke_circle, smoke_color, (smoke_size, smoke_size), smoke_size)
                # 연기 위치 약간 흔들기
                offset_x = random.randint(-2, 2)
                offset_y = random.randint(-5, -1) - i * 2
                carrier_surface.blit(smoke_circle, (smoke_x - smoke_size + offset_x, smoke_y - smoke_size + offset_y))
    # 체력 30% 이하: 화염 효과 시작
    if health_percent <= 30:
        fire_intensity = 1.0
        if health_percent <= 10:
            fire_intensity = 3.0  # 체력 10% 이하: 대형 화염
            fire_count = 8
        elif health_percent <= 20:
            fire_intensity = 2.0  # 체력 20% 이하: 강한 화염
            fire_count = 5
        else:
            fire_intensity = 1.0  # 체력 30% 이하: 약한 화염
            fire_count = 3
        # 화염 위치 생성
        fire_points = []
        for _ in range(fire_count):
            fire_x = random.randint(25, carrier_width - 25)
            fire_y = random.randint(35, 65)
            fire_points.append((fire_x, fire_y))
        # 화염 그리기
        for fire_x, fire_y in fire_points:
            # 화염 애니메이션 (시간에 따라 변화)
            flame_wave = abs(math.sin(time_now * 0.01 + fire_x))
            # 화염 코어 (흰색-노란색)
            core_size = int(4 * fire_intensity * (0.8 + flame_wave * 0.2))
            pygame.draw.circle(carrier_surface, (255, 255, 200), (fire_x, fire_y), core_size)
            # 중간 화염 (주황색)
            mid_size = int(7 * fire_intensity * (0.9 + flame_wave * 0.1))
            mid_color = (255, 150, 50, 180)
            flame_mid = pygame.Surface((mid_size * 2, mid_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(flame_mid, mid_color, (mid_size, mid_size), mid_size)
            carrier_surface.blit(flame_mid, (fire_x - mid_size, fire_y - mid_size))
            # 외부 화염 (빨간색)
            outer_size = int(10 * fire_intensity * (1.0 + flame_wave * 0.2))
            outer_color = (255, 50, 30, 120)
            flame_outer = pygame.Surface((outer_size * 2, outer_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(flame_outer, outer_color, (outer_size, outer_size), outer_size)
            carrier_surface.blit(flame_outer, (fire_x - outer_size, fire_y - outer_size - int(flame_wave * 3)))
            # 불꽃 파티클 효과
            if random.random() < 0.3 * fire_intensity:
                for _ in range(int(2 * fire_intensity)):
                    spark_x = fire_x + random.randint(-15, 15)
                    spark_y = fire_y + random.randint(-10, -2)
                    spark_color = (255, random.randint(100, 200), 0)
                    pygame.draw.circle(carrier_surface, spark_color, (spark_x, spark_y), random.randint(1, 2))
    # 체력 10% 이하: 폭발 효과 추가
    if health_percent <= 10:
        # 랜덤 폭발 효과
        if random.random() < 0.2:  # 20% 확률로 폭발
            explosion_x = random.randint(30, carrier_width - 30)
            explosion_y = random.randint(30, 60)
            # 폭발 플래시
            flash_size = random.randint(15, 25)
            pygame.draw.circle(carrier_surface, (255, 255, 255), (explosion_x, explosion_y), flash_size)
            pygame.draw.circle(carrier_surface, (255, 200, 100), (explosion_x, explosion_y), flash_size - 3)
            pygame.draw.circle(carrier_surface, (255, 100, 0), (explosion_x, explosion_y), flash_size - 6)
            # 파편 효과
            for _ in range(8):
                debris_x = explosion_x + random.randint(-20, 20)
                debris_y = explosion_y + random.randint(-20, 20)
                debris_color = (random.randint(150, 255), random.randint(50, 150), 0)
                pygame.draw.circle(carrier_surface, debris_color, (debris_x, debris_y), random.randint(1, 3))
    # === 플라즈마 레이저 캐논 ===
    # 글로벌 변수는 이미 draw_objects에서 선언됨
    current_time = pygame.time.get_ticks()
    # 캐논 위치 (함선 전면 중앙)
    cannon_x = carrier_width // 2
    cannon_y = 15
    # 캐논 각도는 충전 시작할 때 이미 설정됨
    # laser_cannon_angle은 draw_objects에서 충전 시 설정
    # 캐논 베이스 그리기
    pygame.draw.circle(carrier_surface, (80, 90, 100), (cannon_x, cannon_y), 12)
    pygame.draw.circle(carrier_surface, (100, 110, 120), (cannon_x, cannon_y), 10)
    # 회전하는 캐논 포신
    cannon_barrel_length = 20
    angle_rad = math.radians(laser_cannon_angle)
    cannon_barrel_end_x = cannon_x + int(math.cos(angle_rad) * cannon_barrel_length)
    cannon_barrel_end_y = cannon_y + int(math.sin(angle_rad) * cannon_barrel_length)
    # 포신 그리기 (두께 좋 표현)
    pygame.draw.line(carrier_surface, (90, 100, 110), 
                     (cannon_x, cannon_y), (cannon_barrel_end_x, cannon_barrel_end_y), 8)
    pygame.draw.line(carrier_surface, (110, 120, 130), 
                     (cannon_x, cannon_y), (cannon_barrel_end_x, cannon_barrel_end_y), 6)
    # 캐논 끝부분 (발사구)
    pygame.draw.circle(carrier_surface, (120, 130, 140), 
                      (cannon_barrel_end_x, cannon_barrel_end_y), 6)
    pygame.draw.circle(carrier_surface, (140, 150, 160), 
                      (cannon_barrel_end_x, cannon_barrel_end_y), 4)
    # 충전 효과
    if laser_charging:
        charge_time = current_time - laser_charge_start
        charge_ratio = min(1.0, charge_time / 1000)  # 1초 충전
        # 충전 파티클 효과
        for _ in range(int(10 * charge_ratio)):
            particle_angle = random.uniform(0, math.pi * 2)
            particle_dist = random.uniform(10, 30 * (1 - charge_ratio))
            particle_x = cannon_barrel_end_x + int(math.cos(particle_angle) * particle_dist)
            particle_y = cannon_barrel_end_y + int(math.sin(particle_angle) * particle_dist)
            # 파란색 에너지 파티클
            particle_color = (100, 150 + int(100 * charge_ratio), 255)
            pygame.draw.circle(carrier_surface, particle_color, 
                             (particle_x, particle_y), random.randint(1, 3))
        # 충전 코어
        core_size = int(4 + 6 * charge_ratio)
        core_color = (150, 200, 255)
        pygame.draw.circle(carrier_surface, core_color, 
                         (cannon_barrel_end_x, cannon_barrel_end_y), core_size)
        pygame.draw.circle(carrier_surface, (255, 255, 255), 
                         (cannon_barrel_end_x, cannon_barrel_end_y), core_size - 2)
    # === 쉴드 안테나 시스템 ===
    # 안테나 위치 (함선 전면 좌우)
    antenna_left_x = 30
    antenna_right_x = carrier_width - 30
    antenna_y = 25
    # 왼쪽 안테나
    pygame.draw.rect(carrier_surface, (110, 120, 130), 
                     (antenna_left_x - 2, antenna_y, 4, 15))
    pygame.draw.circle(carrier_surface, (140, 150, 160), 
                      (antenna_left_x, antenna_y), 4)
    # 안테나 끝 발광체
    pygame.draw.circle(carrier_surface, (200, 210, 220), 
                      (antenna_left_x, antenna_y - 5), 3)
    if shield_antenna_active:
        # 활성화시 빛나는 효과
        pygame.draw.circle(carrier_surface, (255, 255, 255), 
                          (antenna_left_x, antenna_y - 5), 2)
    # 오른쪽 안테나
    pygame.draw.rect(carrier_surface, (110, 120, 130), 
                     (antenna_right_x - 2, antenna_y, 4, 15))
    pygame.draw.circle(carrier_surface, (140, 150, 160), 
                      (antenna_right_x, antenna_y), 4)
    # 안테나 끝 발광체
    pygame.draw.circle(carrier_surface, (200, 210, 220), 
                      (antenna_right_x, antenna_y - 5), 3)
    if shield_antenna_active:
        # 활성화시 빛나는 효과
        pygame.draw.circle(carrier_surface, (255, 255, 255), 
                          (antenna_right_x, antenna_y - 5), 2)
    return carrier_surface
def draw_with_shake(surface, pos):
    """화면 흔들림 효과와 함께 그리기"""
    shake_x = random.randint(-2, 2) if boss_hit_animation_active else 0
    shake_y = random.randint(-2, 2) if boss_hit_animation_active else 0
    SCREEN.blit(surface, (pos[0] + shake_x, pos[1] + shake_y))

def draw_objects():
    global quake_offset_y, rainbow_index, ball_trail, ball_angle, hit_animation_active, hit_animation_timer
    global boss_trail, long_boost_animating, long_boost_animation_step, long_boost_growing, long_boost_shrinking, long_boost_active
    global PADDLE_WIDTH, stage4_magnetic_active, boss_throwing, boss_throw_timer
    global tear_particles, hongryun_hit_count, HONGRYUN_MAX_HITS
    global walls  # 🆕 벽돌 변수 추가
    global boss_hit_animation_active, boss_hit_animation_timer  # 🆕 보스 충돌 애니메이션 변수 추가
    global power_smashing_trails, power_smashing_particles, mega_smashing_meteor_trail  # 🔥 파워스매싱 이펙트 변수 추가
    global perfect_timing_active, perfect_timing_frame_count, perfect_timing_window  # 🎯 퍼펙트 타이밍 변수 추가
    global special_gauge  # 🆕 드라이브 게이지 확인용
    global grenade_shake_timer  # 💣 수류탄 화면 흔들림
    global shield_antenna_active, shield_antenna_timer, shield_antenna_cooldown, last_shield_time, shield_duration, shield_fade_alpha, shield_position
    global laser_cannon_angle, laser_charging, laser_cannon_active, laser_charge_start, player_stunned, player_stun_end_time, laser_beam_duration
    global last_laser_time, laser_rotating_mode, turret_angles, turret_missiles, last_missile_time
    global interceptors, interceptor_launch_time, interceptor_cooldown, interceptor_launching, interceptor_launch_queue, hangar_door_open, hangar_door_timer
    global player_missile_invulnerable_time  # 미사일 무적 시간
    new_tear_particles = []  # ✅ 함수 시작 시 초기화
    # 🎾 서브 대기 상태 UI (미니멀 디자인)
    if is_waiting_for_serve:
        # 시간 계산
        current_time = pygame.time.get_ticks()
        wait_time = current_time - waiting_start_time
        if is_player_serve:
            # 🟢 플레이어 서브 - 하단 미니멀 UI
            serve_font = pygame.font.Font("NanumSquareB.ttf", 24)
            info_font = pygame.font.Font("NanumSquareR.ttf", 16)
            # 간단한 텍스트만 표시
            serve_text = serve_font.render("Player Serve", True, (255, 255, 255))
            serve_rect = serve_text.get_rect(center=(WIDTH // 2, HEIGHT - 100))
            SCREEN.blit(serve_text, serve_rect)
            # 액센트 라인
            line_width = serve_rect.width + 20
            line_y = serve_rect.bottom + 5
            line_surface = pygame.Surface((line_width, 2), pygame.SRCALPHA)
            line_surface.fill((0, 200, 100))
            SCREEN.blit(line_surface, ((WIDTH - line_width) // 2, line_y))
            # 3초 후 자동 서브 카운트다운
            if wait_time >= 1000:
                remaining = max(0, 3000 - wait_time) // 1000
                if remaining > 0:
                    countdown_text = info_font.render(f"SPACE ({remaining}s)", True, (200, 200, 200))
                else:
                    countdown_text = info_font.render("Auto serve", True, (255, 255, 100))
            else:
                countdown_text = info_font.render("Press SPACE", True, (200, 200, 200))
            countdown_rect = countdown_text.get_rect(center=(WIDTH // 2, serve_rect.bottom + 20))
            SCREEN.blit(countdown_text, countdown_rect)
        else:
            # 🔴 보스 서브 - 상단 미니멀 UI
            serve_font = pygame.font.Font("NanumSquareB.ttf", 24)
            info_font = pygame.font.Font("NanumSquareR.ttf", 16)
            # 간단한 텍스트만 표시
            boss_name = boss_names.get(current_stage, "Boss")
            serve_text = serve_font.render(f"{boss_name} Serve", True, (255, 255, 255))
            serve_rect = serve_text.get_rect(center=(WIDTH // 2, 80))
            SCREEN.blit(serve_text, serve_rect)
            # 액센트 라인
            line_width = serve_rect.width + 20
            line_y = serve_rect.bottom + 5
            line_surface = pygame.Surface((line_width, 2), pygame.SRCALPHA)
            line_surface.fill((200, 80, 80))
            SCREEN.blit(line_surface, ((WIDTH - line_width) // 2, line_y))
            # 상태 텍스트
            if boss_fake_move and wait_delay > 0:
                remaining = max(0, wait_delay - wait_time) // 100
                if remaining > 0:
                    status_text = info_font.render("Preparing...", True, (200, 200, 200))
                else:
                    status_text = info_font.render("Ready", True, (255, 255, 100))
            else:
                status_text = info_font.render("Waiting...", True, (200, 200, 200))
            status_rect = status_text.get_rect(center=(WIDTH // 2, serve_rect.bottom + 20))
            SCREEN.blit(status_text, status_rect)
    # 🎯 퍼펙트 타이밍 윈도우 시각적 표시 (게이지 200 이상일 때만)
    elif perfect_timing_active and special_gauge >= 200:
        # 공 주변에 퍼펙트 타이밍 인디케이터 그리기
        timing_alpha = int(255 * (1.0 - perfect_timing_frame_count / perfect_timing_window))
        timing_radius = 30 + int(5 * math.sin(pygame.time.get_ticks() * 0.2))
        # 반투명 원 그리기 - 파워스매싱 준비 상태에 따라 색상 변경
        timing_surface = pygame.Surface((timing_radius*2, timing_radius*2), pygame.SRCALPHA)
        if special_ready:
            # 파워스매싱 준비 상태일 때 - 빨간색 원
            pygame.draw.circle(timing_surface, (255, 80, 80, timing_alpha), (timing_radius, timing_radius), timing_radius, 3)
        else:
            # 일반 드라이브 상태일 때 - 노란색 원
            pygame.draw.circle(timing_surface, (255, 255, 0, timing_alpha), (timing_radius, timing_radius), timing_radius, 3)
        SCREEN.blit(timing_surface, (BALL.centerx - timing_radius, BALL.centery - timing_radius))
        # 텍스트 표시 - 파워스매싱 준비 상태에 따라 다르게 표시
        timing_font = pygame.font.Font("NanumSquareR.ttf", 24)
        if special_ready:
            # 파워스매싱 준비 상태일 때 - 빨간색 SMASHING
            timing_text = timing_font.render("SMASHING", True, (255, 80, 80))
        else:
            # 일반 드라이브 상태일 때 - 노란색 Drive!
            timing_text = timing_font.render("Drive!", True, (255, 255, 0))
        text_rect = timing_text.get_rect(center=(BALL.centerx, BALL.centery - 50))
        SCREEN.blit(timing_text, text_rect)
    # 화면 흔들림 효과 계산
    quake_offset_y = random.randint(-5, 5) if quake_active else 0
    # 💣 수류탄 폭발 화면 흔들림
    grenade_offset_x = 0
    grenade_offset_y = 0
    if grenade_shake_timer > 0:
        # 흔들림 강도 계산 (시간이 지날수록 약해짐)
        intensity = grenade_shake_timer / 15.0
        grenade_offset_x = random.randint(-int(8 * intensity), int(8 * intensity))
        grenade_offset_y = random.randint(-int(6 * intensity), int(6 * intensity))
        grenade_shake_timer -= 1
    # 최종 화면 흔들림 오프셋
    total_offset_x = grenade_offset_x
    total_offset_y = quake_offset_y + grenade_offset_y
    # 화면 흔들림을 적용하여 오브젝트 그리기
    
    def draw_rect_with_shake(color, rect, width=0):
        """ 화면 흔들림을 적용하여 사각형 그리기"""
        shaken_rect = pygame.Rect(rect.x + total_offset_x, rect.y + total_offset_y, rect.width, rect.height)
        draw.rect(color, shaken_rect, width)
    def draw_circle_with_shake(color, pos, radius, width=0):
        """  화면 흔들림을 적용하여 원 그리기"""
        draw.circle(color, (int(pos[0] + total_offset_x), int(pos[1] + total_offset_y)), radius, width)
    # === 보스 이미지 선택 + 스테이지별 전용 사이즈 적용 ===
    if new_boss_mode_active:
        # 🆕 새로운 보스 모드에서는 상단 보스 선택
        if selected_top_boss == 1:
            # 라이트닝 마스터 (임시로 stage3 이미지 사용 - 전기 속성)
            boss_img = BOSS_IMG_STAGE3
            boss_w, boss_h = BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT
        elif selected_top_boss == 2:
            # 아이스 퀸 (임시로 stage4 이미지 사용 - 얼음 속성)
            boss_img = BOSS_IMG_STAGE4
            boss_w, boss_h = BOSS_IMG_STAGE4_WIDTH, BOSS_IMG_STAGE4_HEIGHT
        else:
            boss_img = BOSS_IMG_STAGE1
            boss_w, boss_h = BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT
    # 스테이지별 보스 이미지 매핑
    stage_boss_config = {
        1: (BOSS_IMG_STAGE1, BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT),
        2: (SPEED_DEFENSE_IMG if speed_defense_active else BOSS_IMG_STAGE2, BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT),
        3: (BOSS_IMG_STAGE3, BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT),
        4: (BOSS_IMG_STAGE4, BOSS_IMG_STAGE4_WIDTH, BOSS_IMG_STAGE4_HEIGHT),
        5: (BOSS_IMG_STAGE5, BOSS_IMG_STAGE5_WIDTH, BOSS_IMG_STAGE5_HEIGHT)
    }
    
    if current_stage in stage_boss_config:
        boss_img, boss_w, boss_h = stage_boss_config[current_stage]
    elif current_stage == 6:
        # 🚢 스테이지 6: 항공모함 스타일 보스 (체력형)
        # 보스 속도 계산 (이전 위치와 현재 위치 차이)
        global boss_prev_x
        boss_current_speed = abs(BOSS.x - boss_prev_x) if boss_prev_x else 0
        boss_prev_x = BOSS.x
        boss_img = draw_aircraft_carrier_boss(boss_current_speed, BOSS.x)
        boss_w, boss_h = 220, 85  # 배틀크루저는 더 크고 위용있게
    else:
        boss_img = pygame.Surface((BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT), pygame.SRCALPHA)
        boss_img.fill((255, 255, 255))
        boss_w, boss_h = BOSS_IMG_WIDTH, BOSS_IMG_HEIGHT
    boss_img = pygame.transform.scale(boss_img, (boss_w, boss_h))
    # 🎭 풍악보이 상모돌리기 회전 효과
    whip_rotation_angle = 0
    if current_stage == 1 and whip_active:
        # 빠른 속도로 회전 (팽이처럼)
        rotation_speed = 15  # 회전 속도 (도/프레임)
        current_time = pygame.time.get_ticks()
        whip_rotation_angle = (current_time * rotation_speed / 16.67) % 360  # 60fps 기준
        boss_img = pygame.transform.rotate(boss_img, whip_rotation_angle)
    # === 보스 던지는 모션 ===
    boss_offset_y = 0
    tilt_angle_boss = 0
    if current_stage == 5 and boss_throwing:
        boss_offset_y = -10  # 살짝 위로 올림
        tilt_angle_boss = -15 if (pygame.time.get_ticks() // 100) % 2 == 0 else 15
    # 좌우 기울기 효과 제거 (사용자 요청)
    # elif not is_waiting_for_serve and not (current_stage == 2 and speed_defense_active):
    #     # 평상시 좌우 기울기
    #     if BOSS.x > WIDTH // 2:
    #         tilt_angle_boss = -10
    #     elif BOSS.x < WIDTH // 2:
    #         tilt_angle_boss = 10
    # === 보스 회전 처리 ===
    # 보스 패들 충돌 애니메이션 처리
    if boss_hit_animation_active:
        # 스테이지별 기본 지속시간 매핑
        stage_durations = {1: 5, 2: 7, 3: 8, 4: 6, 5: 9}
        base_duration = stage_durations.get(current_stage, BOSS_HIT_ANIMATION_DURATION)
        progress = base_duration - boss_hit_animation_timer
        # 스테이지별 충돌 애니메이션 매핑
        # (각도, 감소율) 튜플로 저장
        stage_animations = {
            1: (15, 3),  # 부드러운 회전
            2: (25, 4),  # 빠른 회전
            3: (30, 4),  # 강한 회전
            4: (20, 3),  # 중간 회전
            5: (35, 4)   # 최강 회전
        }
        angle, rate = stage_animations.get(current_stage, (20, 3))
        hit_tilt_angle = angle - (progress * rate)
        boss_hit_animation_timer -= 1
        if boss_hit_animation_timer <= 0:
            boss_hit_animation_active = False
        tilt_angle_boss = hit_tilt_angle  # 충돌 애니메이션 우선 적용
    # 상모돌리기 중이거나 스피드디펜스 중일 때는 기울기 효과 제거
    if (current_stage == 1 and whip_active) or (current_stage == 2 and speed_defense_active):
        rotated_boss = boss_img.copy()
        boss_rect = rotated_boss.get_rect(center=(BOSS.centerx + screen_shake_offset_x, BOSS.centery + boss_offset_y + screen_shake_offset_y))
    else:
        # 원래 보스 회전 로직 (화면 흔들림 오프셋 적용)
        rotated_boss = pygame.Surface((boss_w, boss_h), pygame.SRCALPHA)
        rotated_boss.blit(boss_img, (0, 0))
        rotated_boss = pygame.transform.rotate(rotated_boss, tilt_angle_boss)
        boss_rect = rotated_boss.get_rect(center=(BOSS.centerx + screen_shake_offset_x, BOSS.centery + boss_offset_y + screen_shake_offset_y))
    # === Stage 2 스피드 디펜스 꼬리효과 ===
    if current_stage == 2 and speed_defense_active:
        # 원래 꼬리 효과 (매 프레임 추가) - 더 많은 잔상 추가
        boss_trail.append((BOSS.centerx, BOSS.centery, 255))
    # 꼬리 효과 알파값 감소 및 정리 (스피드 디펜스 활성화 여부와 관계없이 실행)
    boss_trail[:] = [(x, y, a-8) for x, y, a in boss_trail if a > 8]  # 더 천천히 사라지도록
    # 원래 꼬리 효과 렌더링 - 길게 늘어진 잔상 효과
    if boss_trail:
        for i, (x, y, alpha) in enumerate(boss_trail):
            # 잔상 크기를 점진적으로 줄이기
            scale_factor = 1.0 - (i * 0.02)  # 뒤로 갈수록 작아짐
            trail_width = int(BOSS_IMG_WIDTH * scale_factor)
            trail_height = int(BOSS_IMG_HEIGHT * scale_factor)
            if trail_width > 10 and trail_height > 10:  # 너무 작아지면 그리지 않음
                trail_img = pygame.transform.scale(SPEED_DEFENSE_IMG, (trail_width, trail_height))
                trail_img.set_alpha(alpha)
                trail_rect = trail_img.get_rect(center=(x, y))
                SCREEN.blit(trail_img, trail_rect.topleft)
    # === Stage 3 오버드라이브 꼬리 ===
    if current_stage == 3 and emotional_overdrive_active:
        for x, y, alpha in overdrive_trails:
            trail = pygame.transform.scale(BOSS_IMG_STAGE3, (boss_w, boss_h))
            trail.set_alpha(alpha)
            trail_rect = trail.get_rect(center=(x, y))
            SCREEN.blit(trail, trail_rect.topleft)
        if overdrive_flash_timer < 15:
            apply_white_glow(rotated_boss, intensity=80)
    if current_stage == 3 and boss_special_ready and not emotional_overdrive_active:
        time_now = pygame.time.get_ticks()
        if (time_now // 250) % 2 == 0:
            apply_white_glow(rotated_boss, intensity=60)
    # === Stage 3 빨간 오버레이 ===
    if current_stage == 3 and boss_red_intensity > 0:
        rotated_boss_copy = rotated_boss.copy()
        apply_red_overlay(rotated_boss_copy, boss_red_intensity)
        SCREEN.blit(rotated_boss_copy, boss_rect.topleft)
    else:
        # 보스 충돌 시 빛나는 효과 추가 (파워스매싱 상태일 때만)
        if boss_hit_animation_active and boss_hit_animation_timer > BOSS_HIT_ANIMATION_DURATION - 3 and special_active:
            # 파워스매싱 충돌 직후 3프레임 동안 빛나는 효과
            glow_intensity = (BOSS_HIT_ANIMATION_DURATION - boss_hit_animation_timer) * 20
            apply_white_glow(rotated_boss, intensity=glow_intensity)
        draw_with_shake(rotated_boss, boss_rect.topleft)
    # === Stage 6 쉴드 안테나 그리기 (패들 위에 직접) ===
    if current_stage == 6:
        # 왼쪽 안테나 (패들 왼쪽)
        antenna_left_x = BOSS.left + 20
        antenna_left_y = BOSS.centery
        # 안테나 기둥
        draw.rect((110, 120, 130), 
                        (antenna_left_x - 2, antenna_left_y - 10, 4, 20))
        # 안테나 베이스
        draw.circle((140, 150, 160), 
                          (antenna_left_x, antenna_left_y), 5)
        # 안테나 끝 발광체
        antenna_tip_y = antenna_left_y - 15
        draw.circle((200, 210, 220), 
                          (antenna_left_x, antenna_tip_y), 4)
        if shield_antenna_active:
            # 활성화시 빛나는 효과
            draw.circle((255, 255, 255), 
                              (antenna_left_x, antenna_tip_y), 3)
            # 빛나는 파티클
            for _ in range(2):
                spark_offset = random.randint(-5, 5)
                draw.circle((200, 220, 255), 
                                  (antenna_left_x + spark_offset, antenna_tip_y + random.randint(-3, 3)), 1)
        # 오른쪽 안테나 (패들 오른쪽)
        antenna_right_x = BOSS.right - 20
        antenna_right_y = BOSS.centery
        # 안테나 기둥
        draw.rect((110, 120, 130), 
                        (antenna_right_x - 2, antenna_right_y - 10, 4, 20))
        # 안테나 베이스
        draw.circle((140, 150, 160), 
                          (antenna_right_x, antenna_right_y), 5)
        # 안테나 끝 발광체
        antenna_tip_y = antenna_right_y - 15
        draw.circle((200, 210, 220), 
                          (antenna_right_x, antenna_tip_y), 4)
        if shield_antenna_active:
            # 활성화시 빛나는 효과
            draw.circle((255, 255, 255), 
                              (antenna_right_x, antenna_tip_y), 3)
            # 빛나는 파티클
            for _ in range(2):
                spark_offset = random.randint(-5, 5)
                draw.circle((200, 220, 255), 
                                  (antenna_right_x + spark_offset, antenna_tip_y + random.randint(-3, 3)), 1)
    # 🎯 보스 확장 히트박스 디버그 표시 (개발용)
    DEBUG_SHOW_HITBOX = False  # True로 변경하면 히트박스가 보임
    if DEBUG_SHOW_HITBOX:
        # 스테이지 6에서만 확장된 히트박스 표시
        if current_stage == 6:
            # 확장된 히트박스 그리기 (반투명 빨간색)
            boss_hitbox_expanded = pygame.Rect(
                BOSS.x - BOSS.width // 2,  # 왼쪽으로 절반 폭만큼 확장
                BOSS.y,  # y 위치는 그대로
                BOSS.width * 2,  # 너비를 2배로
                BOSS.height  # 높이는 그대로
            )
            hitbox_surface = pygame.Surface((boss_hitbox_expanded.width, boss_hitbox_expanded.height), pygame.SRCALPHA)
            hitbox_surface.fill((255, 0, 0, 50))  # 반투명 빨간색
            SCREEN.blit(hitbox_surface, boss_hitbox_expanded.topleft)
            # 히트박스 테두리 (실선)
            draw.rect((255, 0, 0), boss_hitbox_expanded, 2)
        # 원본 보스 패들 크기 표시 (파란색) - 모든 스테이지
        draw.rect((0, 0, 255), BOSS, 2)
    # 🌀 스턴 시 머리 위 빙글빙글 도는 별 효과 (작게, 머리 위로)
    if boss_stunned_timer > 0:
        # 별 3개가 머리 위에서 회전
        # 프레임 기반 회전 (스턴 타이머를 이용)
        rotation_angle = (60 - boss_stunned_timer) * 6  # 스턴 타이머를 이용한 회전 (6도씩)
        num_stars = 3
        radius = 20  # 회전 반경 (25 → 20)
        for i in range(num_stars):
            # 각 별의 회전 각도
            angle = (rotation_angle + i * (360 / num_stars)) % 360
            angle_rad = math.radians(angle)
            # 별 위치 (보스 머리 위 - 더 아래로)
            star_x = BOSS.centerx + radius * math.cos(angle_rad)
            star_y = BOSS.top - 15 + radius * math.sin(angle_rad) * 0.5  # 더 아래로 조정 (25 → 15)
            # 별 그리기 (더 작게)
            star_size = 8  # 12 → 8로 축소
            star_points = []
            for j in range(10):
                angle_star = j * 36 - 90
                angle_star_rad = math.radians(angle_star)
                if j % 2 == 0:
                    # 바깥쪽 점
                    px = star_x + star_size * math.cos(angle_star_rad)
                    py = star_y + star_size * math.sin(angle_star_rad)
                else:
                    # 안쪽 점
                    px = star_x + (star_size * 0.4) * math.cos(angle_star_rad)
                    py = star_y + (star_size * 0.4) * math.sin(angle_star_rad)
                star_points.append((px, py))
            # 별 색상 (노란색 계열)
            star_color = (255, 255, 100)
            draw.polygon(star_color, star_points)
            draw.polygon((255, 200, 0), star_points, 1)  # 얇은 테두리
            # 별 글로우 효과
            glow_surface = pygame.Surface((star_size * 3, star_size * 3), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, (255, 255, 100, 60), 
                             (star_size * 1.5, star_size * 1.5), star_size)
            SCREEN.blit(glow_surface, (star_x - star_size * 1.5, star_y - star_size * 1.5))
    # === Stage 4 자기장 이펙트 ===
    if current_stage == 4 and stage4_magnetic_active:
        magnetic_surface = pygame.Surface((260, 260), pygame.SRCALPHA)
        # 기본 자기장 원
        pygame.draw.circle(magnetic_surface, (100, 200, 255, 80), (130, 130), 130, width=6)
        pygame.draw.circle(magnetic_surface, (180, 220, 255, 50), (130, 130), 80, width=0)
        # 전기 이펙트 - 번개 모양의 선들
        electric_time = pygame.time.get_ticks()
        num_bolts = 8  # 전기 번개 개수
        for i in range(num_bolts):
            # 각 번개의 시작과 끝 각도
            start_angle = (electric_time * 0.002 + i * (360 / num_bolts)) % 360
            end_angle = start_angle + random.randint(30, 90)
            # 내부와 외부 반경 사이를 오가는 번개
            inner_radius = 60 + random.randint(-10, 10)
            outer_radius = 120 + random.randint(-10, 10)
            # 시작점과 끝점 계산
            start_x = 130 + inner_radius * math.cos(math.radians(start_angle))
            start_y = 130 + inner_radius * math.sin(math.radians(start_angle))
            end_x = 130 + outer_radius * math.cos(math.radians(end_angle))
            end_y = 130 + outer_radius * math.sin(math.radians(end_angle))
            # 중간 지점들 (지그재그 효과)
            mid_points = []
            num_segments = 3
            for j in range(1, num_segments):
                t = j / num_segments
                mid_x = start_x + (end_x - start_x) * t + random.randint(-15, 15)
                mid_y = start_y + (end_y - start_y) * t + random.randint(-15, 15)
                mid_points.append((mid_x, mid_y))
            # 전기 색상 (밝은 청백색)
            electric_alpha = 180 + random.randint(-30, 30)
            electric_color = (150 + random.randint(0, 105), 200 + random.randint(0, 55), 255, electric_alpha)
            # 번개 그리기 (메인 라인)
            points = [(start_x, start_y)] + mid_points + [(end_x, end_y)]
            for k in range(len(points) - 1):
                pygame.draw.line(magnetic_surface, electric_color, points[k], points[k+1], 2)
            # 글로우 효과 (더 굵고 투명한 선)
            glow_color = (100, 150, 255, electric_alpha // 3)
            for k in range(len(points) - 1):
                pygame.draw.line(magnetic_surface, glow_color, points[k], points[k+1], 4)
        # 펄스 효과 (주기적으로 밝아짐)
        pulse = abs(math.sin(electric_time * 0.005)) * 0.5 + 0.5
        if pulse > 0.8:  # 주기적으로 강한 번쩍임
            flash_surface = pygame.Surface((260, 260), pygame.SRCALPHA)
            pygame.draw.circle(flash_surface, (200, 230, 255, int(40 * pulse)), (130, 130), 130, width=0)
            magnetic_surface.blit(flash_surface, (0, 0))
        SCREEN.blit(magnetic_surface, (BOSS.centerx - 130, BOSS.centery - 130))
    # === 롱부스트 애니메이션 처리 (레거시 코드 - 새로운 점진적 크기 변화로 대체됨) ===
    # === 플레이어 이미지 (새로운 보스 모드 고려) ===
    if new_boss_mode_active:
        # 🆕 새로운 보스 모드에서는 하단 보스 이미지 사용
        try:
            if selected_bottom_boss == 1:
                # 파이어 나이트 이미지 (임시로 stage1 이미지 사용, 나중에 별도 이미지 추가 가능)
                boss_img = pygame.image.load("boss_stage1.png").convert_alpha()
                # 화염 속성 느낌으로 빨간색 틴트 적용
                base_ufo_img = pygame.transform.scale(boss_img, (250, 100))
            elif selected_bottom_boss == 2:
                # 윈드 스피릿 이미지 (임시로 stage2 이미지 사용, 나중에 별도 이미지 추가 가능)
                boss_img = pygame.image.load("boss_stage2.png").convert_alpha()
                # 바람 속성 느낌으로 사용
                base_ufo_img = pygame.transform.scale(boss_img, (250, 100))
            else:
                base_ufo_img = PLAYER_IMG
        except:
            # 이미지 로드 실패 시 기본 플레이어 이미지 사용
            base_ufo_img = PLAYER_IMG
    else:
        # 일반 모드에서는 UFO 플레이어 이미지 사용
        base_ufo_img = PLAYER_IMG
    # 스킬 효과 적용: 패들 크기 증가
    skill_boosted_width = skill.apply_paddle_size_boost(PADDLE_WIDTH)
    scale_ratio = skill_boosted_width / 155
    # 🍄 거대화포션 효과 적용 (점진적 크기 변화)
    scale_ratio *= long_boost_scale
    if scale_ratio != 1.0:
        new_width = int(base_ufo_img.get_width() * scale_ratio)
        new_height = int(base_ufo_img.get_height() * scale_ratio)
        base_ufo_img = pygame.transform.scale(base_ufo_img, (new_width, new_height))
    keys = pygame.key.get_pressed()
    tilt_angle = 0
    if hit_animation_active:
        progress = HIT_ANIMATION_DURATION - hit_animation_timer
        tilt_angle = -20 + (progress * 7)
        hit_animation_timer -= 1
        if hit_animation_timer <= 0:
            hit_animation_active = False
    else:
        if keys[pygame.K_LEFT] or keys[pygame.K_a]:
            tilt_angle = 10
        elif keys[pygame.K_RIGHT] or keys[pygame.K_d]:
            tilt_angle = -10
    # 🔥💣💡 투척 모션 중일 때 특별한 회전 각도 적용
    if molotov_throwing or grenade_throwing or flare_throwing:
        throw_progress = 0
        if molotov_throwing:
            throw_progress = 1.0 - (molotov_throw_timer / 30.0)  # 0에서 1로 진행
        elif grenade_throwing:
            throw_progress = 1.0 - (grenade_throw_timer / 30.0)  # 0에서 1로 진행
        elif flare_throwing:
            throw_progress = 1.0 - (flare_throw_timer / 30.0)  # 0에서 1로 진행
        # 투척 모션: UFO가 뒤로 젖혔다가 앞으로 던지는 동작
        if throw_progress < 0.3:
            # 준비 단계: 뒤로 젖히기
            tilt_angle = 30 * (throw_progress / 0.3)
        elif throw_progress < 0.7:
            # 유지 단계
            tilt_angle = 30
        else:
            # 투척 단계: 앞으로 던지기
            tilt_angle = 30 - 50 * ((throw_progress - 0.7) / 0.3)
    rotated_player = pygame.transform.rotate(base_ufo_img, tilt_angle).copy()
    # 🎭 보스 vs 보스전과 🆕 새로운 보스전에서는 빨간 효과 제거 (게이지를 사용하지 않음)
    if not new_boss_mode_active:
        if not special_active and red_intensity > 0:
            apply_red_overlay(rotated_player, red_intensity)
        # 🆕 눈물샤워 디버프 시 파란색 변색 효과
        if player_slow_timer > 0:
            apply_blue_overlay(rotated_player, intensity=120)
    # 🏃 대쉬 잔상 효과 그리기
    global dash_afterimages, rolling_active, rolling_timer, rolling_direction
    # 대쉬 중일 때 잔상 추가
    if rolling_active and rolling_timer > 0:
        # 대쉬 방향에 따른 잔상 생성 위치
        afterimage_x = PLAYER.centerx
        afterimage_y = PLAYER.centery
        # 잔상 이미지 생성 (현재 회전된 이미지 복사)
        afterimage = rotated_player.copy()
        # 잔상 투명도 설정 (대쉬 진행도에 따라 조절)
        alpha = min(180, int(180 * (rolling_timer / 15)))  # 최대 180 투명도
        # 잔상 리스트에 추가 (최대 5개 유지)
        dash_afterimages.append({
            'x': afterimage_x,
            'y': afterimage_y, 
            'alpha': alpha,
            'image': afterimage,
            'life': 10  # 잔상 지속 시간
        })
        # 잔상 개수 제한
        if len(dash_afterimages) > 5:
            dash_afterimages.pop(0)
    # 잔상 그리기 및 업데이트
    new_afterimages = []
    for afterimage in dash_afterimages:
        # 잔상 투명도 적용
        afterimage_surf = afterimage['image'].copy()
        afterimage_surf.set_alpha(afterimage['alpha'])
        # 잔상 위치 계산 (점점 뒤로 밀림)
        afterimage_rect = afterimage_surf.get_rect(center=(afterimage['x'], afterimage['y']))
        # 잔상 그리기
        SCREEN.blit(afterimage_surf, afterimage_rect.topleft)
        # 잔상 업데이트
        afterimage['alpha'] -= 25  # 투명도 감소
        afterimage['life'] -= 1
        # 아직 살아있는 잔상만 유지
        if afterimage['alpha'] > 0 and afterimage['life'] > 0:
            new_afterimages.append(afterimage)
    dash_afterimages = new_afterimages
    # UFO 이미지 그리기 (화면 흔들림 오프셋 적용)
    player_rect = rotated_player.get_rect(center=(PLAYER.centerx + screen_shake_offset_x, PLAYER.centery + screen_shake_offset_y))
    # 🎯 스킬 인디케이터 UI 그리기 (패들 아래)
    if not new_boss_mode_active:  # 일반 모드에서만 표시
        # 스킬 게이지 계산
        skill_gauge_ratio = min(1.0, special_gauge / special_gauge_max)
        # 스킬 인디케이터는 표시하지 않음 (UI 정리)
    # 미사일 무적 시간 체크
    time_now = pygame.time.get_ticks()
    is_missile_invulnerable = time_now < player_missile_invulnerable_time
    # UFO 이미지 그리기 (깜빡임 효과 적용 - 최적화 버전)
    if special_ready:
        if (time_now // 250) % 2 == 0:
            # 🚀 성능 최적화: 블렌딩 모드를 사용한 깜빡임 효과
            bright_ufo = rotated_player.copy()
            # 밝기 오버레이 생성
            bright_overlay = pygame.Surface(bright_ufo.get_size(), pygame.SRCALPHA)
            bright_overlay.fill((100, 100, 100, 128))  # 밝기 오버레이
            # 블렌딩 모드로 효율적으로 밝기 적용
            bright_ufo.blit(bright_overlay, (0, 0), special_flags=pygame.BLEND_ADD)
            # 미사일 무적 시간이면 반투명 처리
            if is_missile_invulnerable and (time_now // 100) % 2 == 0:
                bright_ufo.set_alpha(100)
            draw_with_shake(bright_ufo, player_rect.topleft)
        else:
            player_to_draw = rotated_player.copy()
            # 미사일 무적 시간이면 반투명 처리
            if is_missile_invulnerable and (time_now // 100) % 2 == 0:
                player_to_draw.set_alpha(100)
            draw_with_shake(player_to_draw, player_rect.topleft)
    else:
        player_to_draw = rotated_player.copy()
        # 미사일 무적 시간이면 반투명 처리
        if is_missile_invulnerable and (time_now // 100) % 2 == 0:
            player_to_draw.set_alpha(100)
        draw_with_shake(player_to_draw, player_rect.topleft)
    # 🔥💣💡 투척 모션 중 아이템 표시
    if molotov_throwing or grenade_throwing or flare_throwing:
        throw_progress = 0
        item_icon = None
        if molotov_throwing:
            throw_progress = 1.0 - (molotov_throw_timer / 30.0)
            try:
                item_icon = pygame.image.load("items/molotov.png").convert_alpha()
                item_icon = pygame.transform.scale(item_icon, (40, 40))
            except:
                # 화염병 기본 아이콘
                item_icon = pygame.Surface((40, 40), pygame.SRCALPHA)
                pygame.draw.circle(item_icon, (255, 100, 0), (20, 20), 15)
        elif grenade_throwing:
            throw_progress = 1.0 - (grenade_throw_timer / 30.0)
            try:
                item_icon = pygame.image.load("items/grenade.png").convert_alpha()
                item_icon = pygame.transform.scale(item_icon, (40, 40))
            except:
                # 수류탄 기본 아이콘
                item_icon = pygame.Surface((40, 40), pygame.SRCALPHA)
                pygame.draw.circle(item_icon, (100, 150, 100), (20, 20), 15)
        elif flare_throwing:
            throw_progress = 1.0 - (flare_throw_timer / 30.0)
            try:
                item_icon = pygame.image.load("items/flare.png").convert_alpha()
                item_icon = pygame.transform.scale(item_icon, (40, 40))
            except:
                # 조명탄 기본 아이콘
                item_icon = pygame.Surface((40, 40), pygame.SRCALPHA)
                pygame.draw.circle(item_icon, (255, 255, 200), (20, 20), 15)
        # 연막탄은 즉시 발동으로 변경되어 투척 모션 제거됨
        if item_icon:
            # 투척 모션에 따른 아이템 위치 계산
            if throw_progress < 0.7:
                # 준비 및 유지 단계: UFO 위에 아이템 표시
                item_x = PLAYER.centerx + screen_shake_offset_x
                item_y = PLAYER.centery - 30 + screen_shake_offset_y
                # 아이템도 같이 회전
                item_angle = tilt_angle
            else:
                # 투척 단계: 아이템이 앞으로 날아가는 효과
                throw_distance = ((throw_progress - 0.7) / 0.3) * 50
                item_x = PLAYER.centerx + screen_shake_offset_x
                item_y = PLAYER.centery - 30 - throw_distance + screen_shake_offset_y
                item_angle = -30
            # 아이템 회전 및 그리기
            rotated_item = pygame.transform.rotate(item_icon, item_angle)
            item_rect = rotated_item.get_rect(center=(item_x, item_y))
            SCREEN.blit(rotated_item, item_rect.topleft)
    # 수류탄 그리기
    for grenade in grenades:
        # 회전된 수류탄 아이콘 그리기
        try:
            icon = pygame.image.load("items/grenade.png").convert_alpha()
            icon = pygame.transform.scale(icon, (36, 36))  # 화염병보다 약간 크게
            rotated_icon = pygame.transform.rotate(icon, grenade["rotation"])
            icon_rect = rotated_icon.get_rect(center=(grenade["x"], grenade["y"]))
            SCREEN.blit(rotated_icon, icon_rect)
        except:
            # 기본 원형 그리기
            draw.circle((80, 100, 80), (int(grenade["x"]), int(grenade["y"])), 12)
    # 현실감 있는 수류탄 폭발 효과 그리기
    for zone in explosion_zones:
        if zone["active"]:
            # 폭발 사이즈 계산 (시간에 따라 포다짐)
            explosion_surface = pygame.Surface((zone["radius"]*3, zone["radius"]*3), pygame.SRCALPHA)
            center = zone["radius"] * 1.5
            # 1. 충격파 효과 (가장 바깥쪽)
            shockwave_radius = zone["radius"] + (15 - zone["duration"]) * 8
            if shockwave_radius < zone["radius"] * 2.5:
                pygame.draw.circle(explosion_surface, (255, 255, 255, 30), 
                                 (int(center), int(center)), int(shockwave_radius), 4)
            # 2. 폭발 화염 구체 (주황색-빨간색 그라데이션)
            for i in range(zone["radius"], 0, -3):
                progress = (15 - zone["duration"]) / 15.0
                # 시간에 따라 색상 변화
                ratio = i / max(zone["radius"], 1)
                if zone["duration"] > 10:  # 초기: 흰색-노란색
                    r = 255
                    g = int(255 - (1 - ratio) * 100)
                    b = int(200 - (1 - ratio) * 150)
                elif zone["duration"] > 5:  # 중반: 주황색-빨간색
                    r = 255
                    g = int(150 - (1 - ratio) * 100)
                    b = int(50 - (1 - ratio) * 40)
                else:  # 후반: 빨간색-검은색
                    r = int(200 - (1 - ratio) * 100)
                    g = int(50 - (1 - ratio) * 40)
                    b = 30
                # 색상 값이 유효한 범위에 있도록 보장
                r = max(0, min(255, r))
                g = max(0, min(255, g))
                b = max(0, min(255, b))
                alpha = max(0, min(255, int((200 * zone["duration"] / 15) * ratio)))
                color = (r, g, b, alpha)
                pygame.draw.circle(explosion_surface, color, (int(center), int(center)), i)
            # 3. 연기 효과 (회색 구름)
            smoke_radius = zone["radius"] * 0.8 + (15 - zone["duration"]) * 4
            smoke_alpha = max(0, 100 - (15 - zone["duration"]) * 6)
            for j in range(3):  # 여러 개의 연기 구름
                offset_x = random.randint(-20, 20)
                offset_y = random.randint(-20, 20)
                pygame.draw.circle(explosion_surface, (80, 80, 80, smoke_alpha), 
                                 (int(center + offset_x), int(center + offset_y - (15 - zone["duration"]) * 2)), 
                                 int(smoke_radius + random.randint(-10, 10)), 0)
            # 4. 섬광 효과 (랜덤 방향으로 퍼지는 빛)
            if zone["duration"] > 10:
                num_sparks = 8
                for k in range(num_sparks):
                    angle = (k * 360 / num_sparks) + random.randint(-20, 20)
                    spark_length = zone["radius"] * 0.7 + random.randint(-10, 10)
                    spark_end_x = center + spark_length * math.cos(math.radians(angle))
                    spark_end_y = center + spark_length * math.sin(math.radians(angle))
                    pygame.draw.line(explosion_surface, (255, 255, 200, 150), 
                                   (int(center), int(center)), 
                                   (int(spark_end_x), int(spark_end_y)), 2)
            SCREEN.blit(explosion_surface, (zone["x"] - center, zone["y"] - center))
    # 연막탄 그리기
    for smoke_grenade in smoke_grenades:
        if smoke_grenade["arrived"]:
            # 도착 후 대기 중인 연막탄 (바닥에 있음)
            if smoke_grenade["timer"] < 60:
                # 땅에 떨어진 연막탄 그림자
                shadow_rect = pygame.Rect(smoke_grenade["x"] - 15, smoke_grenade["y"] - 3, 30, 6)
                pygame.draw.ellipse(SCREEN, (0, 0, 0, 100), shadow_rect)
                # 깜빡이는 효과 (빨간 LED)
                if smoke_grenade["timer"] % 15 < 8:
                    draw.circle((255, 0, 0), 
                                     (int(smoke_grenade["x"]), int(smoke_grenade["y"] - 5)), 3)
                # 연막탄 본체
                try:
                    icon = pygame.image.load("items/smoke_grenade.png").convert_alpha()
                    icon = pygame.transform.scale(icon, (28, 28))
                    icon_rect = icon.get_rect(center=(smoke_grenade["x"], smoke_grenade["y"] - 5))
                    SCREEN.blit(icon, icon_rect)
                except:
                    draw.circle((100, 100, 100), 
                                     (int(smoke_grenade["x"]), int(smoke_grenade["y"] - 5)), 10)
        else:
            # 날아가는 중인 연막탄
            # 궤적 그리기
            if "trail" in smoke_grenade:
                for i, pos in enumerate(smoke_grenade["trail"]):
                    alpha = int(255 * (i / len(smoke_grenade["trail"])) * 0.3)
                    draw.circle((150, 150, 150, alpha), 
                                     (int(pos[0]), int(pos[1])), 2)
            # 연막탄 본체
            try:
                icon = pygame.image.load("items/smoke_grenade.png").convert_alpha()
                icon = pygame.transform.scale(icon, (32, 32))
                rotated_icon = pygame.transform.rotate(icon, smoke_grenade["rotation"])
                icon_rect = rotated_icon.get_rect(center=(smoke_grenade["x"], smoke_grenade["y"]))
                SCREEN.blit(rotated_icon, icon_rect)
            except:
                # 기본 원형 그리기
                draw.circle((150, 150, 150), 
                                 (int(smoke_grenade["x"]), int(smoke_grenade["y"])), 10)
    # 연막 지역 그리기
    for smoke_zone in smoke_zones:
        if smoke_zone["opacity"] > 0:
            # 연막 파티클 그리기
            for particle in smoke_zone["particles"]:
                # 파티클 투명도 계산
                particle_alpha = min(smoke_zone["opacity"], 
                                   int(smoke_zone["opacity"] * (particle["lifetime"] / 80)))
                # 연막 파티클 그리기 (회색 연기)
                smoke_surface = pygame.Surface((int(particle["size"] * 2), int(particle["size"] * 2)), 
                                              pygame.SRCALPHA)
                # 그라데이션 효과를 위한 여러 레이어
                for i in range(3):
                    layer_size = particle["size"] - i * (particle["size"] / 4)
                    if layer_size > 0:
                        layer_alpha = particle_alpha // (i + 1)
                        color = (120 + i * 20, 120 + i * 20, 120 + i * 20, layer_alpha)
                        pygame.draw.circle(smoke_surface, color,
                                         (int(particle["size"]), int(particle["size"])),
                                         int(layer_size))
                SCREEN.blit(smoke_surface, 
                           (particle["x"] - particle["size"], particle["y"] - particle["size"]))
            # 연막 영역 표시 제거 (원형 경계선 삭제)
    # 조명탄 그리기
    for flare in flares:
        # 도착 후 대기 중인 조명탄 표시
        if flare.get("arrived", False) and not flare["exploded"]:
            # 깜빡이는 효과만 표시 (카운트다운 없음)
            if flare["timer"] % 10 < 5:
                draw.circle((255, 255, 100), 
                                 (int(flare["x"]), int(flare["y"])), 12)
            draw.circle((255, 200, 0), 
                             (int(flare["x"]), int(flare["y"])), 8, 2)
        else:
            # 날아가는 중인 조명탄
            try:
                icon = pygame.image.load("items/flare.png").convert_alpha()
                icon = pygame.transform.scale(icon, (32, 32))
                rotated_icon = pygame.transform.rotate(icon, flare["rotation"])
                icon_rect = rotated_icon.get_rect(center=(flare["x"], flare["y"]))
                SCREEN.blit(rotated_icon, icon_rect)
            except:
                # 기본 원형 그리기
                draw.circle((255, 255, 200), (int(flare["x"]), int(flare["y"])), 10)
    # 조명 지대 그리기 (섬광 효과)
    for zone in flare_zones:
        if zone.get("flash", False):
            # 섬광 효과: 매우 밝고 강렬한 빛
            if zone["duration"] > 0:
                # 화면 전체를 밝게 만드는 효과
                flash_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
                flash_alpha = int(180 * zone["intensity"])  # 더 강한 섬광
                flash_surface.fill((255, 255, 230, flash_alpha))
                SCREEN.blit(flash_surface, (0, 0))
                # 폭발 중심부 강렬한 빛
                for i in range(5):  # 더 많은 레이어로 강렬함 표현
                    radius = zone["radius"] * (1 - i * 0.15)
                    alpha = int(255 * zone["intensity"] * (1 - i * 0.2))
                    if alpha > 0:
                        light_surface = pygame.Surface((int(radius * 2), int(radius * 2)), pygame.SRCALPHA)
                        # 흰색에 가까운 밝은 빛
                        color = (255, 255, 240, min(255, alpha))
                        pygame.draw.circle(light_surface, color, 
                                         (int(radius), int(radius)), int(radius))
                        SCREEN.blit(light_surface, (zone["x"] - radius, zone["y"] - radius))
                # 번쩍이는 십자 섬광
                if zone["intensity"] > 0.7:
                    cross_length = zone["radius"] * 2
                    cross_width = 5
                    draw.line((255, 255, 255), 
                                   (zone["x"] - cross_length, zone["y"]), 
                                   (zone["x"] + cross_length, zone["y"]), cross_width)
                    draw.line((255, 255, 255), 
                                   (zone["x"], zone["y"] - cross_length), 
                                   (zone["x"], zone["y"] + cross_length), cross_width)
        else:
            # 일반 조명 효과 (기존 코드)
            for i in range(3):
                radius = zone["radius"] * (1 - i * 0.2)
                alpha = int(100 * zone["intensity"] * (1 - i * 0.3))
                if alpha > 0:
                    light_surface = pygame.Surface((int(radius * 2), int(radius * 2)), pygame.SRCALPHA)
                    color = (255, 255, 200, alpha)
                    pygame.draw.circle(light_surface, color, 
                                     (int(radius), int(radius)), int(radius))
                    SCREEN.blit(light_surface, (zone["x"] - radius, zone["y"] - radius))
    # 보스 혼란 상태 표시 (물음표가 빙글빙글)
    if boss_confused_timer > 0:
        # 회전 각도 계산 (시간에 따라 빙글빙글)
        rotation_speed = 0.005  # 회전 속도
        current_time = pygame.time.get_ticks()
        # 물음표 폰트 설정
        try:
            question_font = pygame.font.Font("NanumSquareB.ttf", 28)
        except:
            question_font = pygame.font.Font(None, 28)
        # 3개의 물음표가 보스 주위를 빙글빙글 돌기
        num_questions = 3
        orbit_radius = 40  # 회전 반경
        for i in range(num_questions):
            # 각 물음표의 각도 계산 (균등하게 배치)
            angle = current_time * rotation_speed + (i * 2 * math.pi / num_questions)
            # 물음표 위치 계산 (원형 궤도)
            x = BOSS.centerx + orbit_radius * math.cos(angle)
            y = BOSS.centery - 25 + orbit_radius * math.sin(angle) * 0.5  # Y축은 타원형으로
            # 물음표 크기 변화 (앞뒤 구분)
            size_factor = 0.8 + 0.2 * math.sin(angle)  # 0.8 ~ 1.0 사이 변화
            # 물음표 색상 (깜빡이는 효과)
            if math.sin(current_time * 0.01 + i) > 0:
                color = (255, 255, 100)  # 밝은 노란색
            else:
                color = (255, 200, 50)   # 어두운 노란색
            # 물음표 그리기
            question_text = question_font.render("?", True, color)
            # 크기 조절
            scaled_width = int(question_text.get_width() * size_factor)
            scaled_height = int(question_text.get_height() * size_factor)
            if scaled_width > 0 and scaled_height > 0:
                scaled_question = pygame.transform.scale(question_text, (scaled_width, scaled_height))
                question_rect = scaled_question.get_rect(center=(int(x), int(y)))
                # 그림자 효과
                shadow_color = (50, 50, 0)
                shadow_text = question_font.render("?", True, shadow_color)
                scaled_shadow = pygame.transform.scale(shadow_text, (scaled_width, scaled_height))
                shadow_rect = scaled_shadow.get_rect(center=(int(x + 2), int(y + 2)))
                SCREEN.blit(scaled_shadow, shadow_rect)
                # 물음표 본체
                SCREEN.blit(scaled_question, question_rect)
        # 중앙에 큰 물음표 효과 추가 (추가 시각 효과)
        center_angle = current_time * rotation_speed * 2  # 더 빠르게 회전
        # 중앙 물음표 폰트 (더 크게)
        try:
            center_question_font = pygame.font.Font("NanumSquareB.ttf", 45)
        except:
            center_question_font = pygame.font.Font(None, 45)
        # 물음표 색상 (깜빡이는 효과)
        if math.sin(current_time * 0.015) > 0:
            center_color = (255, 255, 150)  # 밝은 노란색
        else:
            center_color = (255, 220, 100)   # 약간 어두운 노란색
        # 중앙 물음표 그리기 (회전 효과)
        center_question_text = center_question_font.render("?", True, center_color)
        # 회전 적용
        rotation_angle = math.degrees(center_angle)
        rotated_question = pygame.transform.rotate(center_question_text, rotation_angle)
        # 중앙에 위치
        question_rect = rotated_question.get_rect(center=(BOSS.centerx, BOSS.centery - 25))
        # 그림자 효과
        shadow_color = (100, 100, 50)
        shadow_text = center_question_font.render("?", True, shadow_color)
        rotated_shadow = pygame.transform.rotate(shadow_text, rotation_angle)
        shadow_rect = rotated_shadow.get_rect(center=(BOSS.centerx + 3, BOSS.centery - 22))
        SCREEN.blit(rotated_shadow, shadow_rect)
        # 물음표 본체
        SCREEN.blit(rotated_question, question_rect)
    # 화염병 그리기
    for molotov in molotovs:
        # 회전된 화염병 아이콘 그리기
        try:
            icon = pygame.image.load("items/molotov.png").convert_alpha()
            icon = pygame.transform.scale(icon, (32, 32))
            rotated_icon = pygame.transform.rotate(icon, molotov["rotation"])
            icon_rect = rotated_icon.get_rect(center=(molotov["x"], molotov["y"]))
            SCREEN.blit(rotated_icon, icon_rect)
        except:
            # 기본 원형 그리기
            draw.circle((255, 100, 0), (int(molotov["x"]), int(molotov["y"])), 10)
    # 화염 지대 그리기 - 불길이 번지는 효과
    for fire_zone in fire_zones:
        # 바닥에 기름이 번진 효과 (반투명 검은색 타원)
        oil_surface = pygame.Surface((fire_zone["width"], fire_zone["height"]), pygame.SRCALPHA)
        pygame.draw.ellipse(oil_surface, (30, 20, 10, 50), 
                          (0, 0, fire_zone["width"], fire_zone["height"]))
        SCREEN.blit(oil_surface, (fire_zone["x"] - fire_zone["width"]/2, 
                                 fire_zone["y"] - fire_zone["height"]/2))
        # 개별 불꽃 파티클 그리기
        for flame in fire_zone["flames"]:
            # 불꽃 색상 (노란색 → 주황색 → 빨간색)
            color_phase = flame["color_phase"]
            if color_phase < 0.3:
                # 밝은 노란색 중심부
                r, g, b = 255, 255, 100
            elif color_phase < 0.7:
                # 주황색
                r, g, b = 255, 150, 0
            else:
                # 빨간색 외곽
                r, g, b = 200, 50, 0
            # 투명도는 lifetime에 따라
            alpha = min(180, int(150 * (flame["lifetime"] / 30)))
            # 불꽃 그리기 (여러 겹으로)
            for layer in range(2):
                layer_size = flame["size"] * (1 - layer * 0.4)
                layer_alpha = alpha * (1 - layer * 0.5)
                if layer_alpha > 0 and layer_size > 0:
                    flame_surface = pygame.Surface((int(layer_size * 2), int(layer_size * 2)), pygame.SRCALPHA)
                    color_with_alpha = (r, g, b, int(layer_alpha))
                    pygame.draw.circle(flame_surface, color_with_alpha, 
                                     (int(layer_size), int(layer_size)), int(layer_size))
                    # 불꽃에 흔들림 효과 추가
                    wobble_x = random.uniform(-2, 2)
                    wobble_y = random.uniform(-1, 1)
                    SCREEN.blit(flame_surface, (int(flame["x"] - layer_size + wobble_x), 
                                               int(flame["y"] - layer_size + wobble_y)))
    # 🆕 벽돌 그리기
    for wall in walls:
        wall_rect = wall["rect"]
        wall_crack_level = wall["crack_level"]
        # 벽돌 기본 색상 (갈색)
        wall_color = (139, 69, 19)
        # 균열에 따른 색상 변화
        if wall_crack_level == 1:
            wall_color = (160, 82, 45)  # 살짝 밝은 갈색
        elif wall_crack_level == 2:
            wall_color = (184, 134, 11)  # 더 밝은 갈색
        elif wall_crack_level == 3:
            wall_color = (218, 165, 32)  # 금색
        # 벽돌 그리기
        draw.rect(wall_color, wall_rect)
        draw.rect((255, 255, 255), wall_rect, 2)  # 흰색 테두리
        # 균열 그리기
        if wall_crack_level > 0:
            crack_color = (255, 0, 0) if wall_crack_level >= 3 else (255, 255, 0)
            # 충돌횟수에 비례해서 균열 개수 증가
            crack_count = wall_crack_level * 3  # 1회 충돌당 3개, 2회 충돌당 6개, 3회 충돌당 9개 균열
            # 균열 선 그리기
            for i in range(crack_count):
                # 균열의 시작점 (벽돌 내부에서 랜덤)
                start_x = wall_rect.x + random.randint(5, wall_rect.width - 5)
                start_y = wall_rect.y + random.randint(5, wall_rect.height - 5)
                # 균열의 방향과 길이 (충돌횟수가 많을수록 더 긴 균열)
                crack_length = random.randint(8, 15 + wall_crack_level * 3)  # 충돌횟수에 따라 길이 증가
                angle = random.uniform(0, 2 * math.pi)  # 랜덤 각도
                # 균열의 끝점 계산
                end_x = start_x + int(math.cos(angle) * crack_length)
                end_y = start_y + int(math.sin(angle) * crack_length)
                # 균열 두께 (충돌횟수가 많을수록 두꺼워짐)
                crack_thickness = min(4, 1 + wall_crack_level)
                draw.line(crack_color, (start_x, start_y), (end_x, end_y), crack_thickness)
    # === Stage 4 명상타임 공 잔상 ===
    if current_stage == 4 and meditation_active:
        for x, y, alpha in meditation_trails:
            rotated_trail = pygame.transform.rotate(BALL_IMG, ball_angle)
            rotated_trail.set_alpha(alpha)
            SCREEN.blit(rotated_trail, (x - BALL.width // 2, y - BALL.height // 2))
    # === 공 (화면 흔들림 오프셋 적용) ===
    ball_rect = BALL.copy()
    ball_rect.x += screen_shake_offset_x
    ball_rect.y += quake_offset_y + screen_shake_offset_y
    # 💫 파워스매싱 잔상 효과 그리기 (세련된 버전) - 고스트샷일 때는 제외
    if (power_smashing_parabola_active or power_smashing_freeze_active) and not mega_smashing_active:
        # 잔상 업데이트 (현재 공 위치 추가)
        if len(power_smashing_trails) == 0 or \
           (len(power_smashing_trails) > 0 and 
            math.hypot(BALL.centerx - power_smashing_trails[-1][0], 
                      BALL.centery - power_smashing_trails[-1][1]) > 8):
            power_smashing_trails.append((BALL.centerx, BALL.centery, 255, BALL.width))
        # 오래된 잔상 제거 및 알파값 감소
        new_trails = []
        for trail in power_smashing_trails:
            x, y, alpha, size = trail
            alpha -= 20  # 더 빠른 페이드
            if alpha > 0:
                new_trails.append((x, y, alpha, size))
        power_smashing_trails = new_trails
        # 잔상 그리기 (전기 효과)
        for i, trail in enumerate(power_smashing_trails):
            x, y, alpha, size = trail
            color_intensity = alpha / 255.0
            # 전기 효과를 위한 서페이스
            trail_surface = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
            center = size * 1.5
            # 전기 번개 효과 (얇은 선들)
            if i < len(power_smashing_trails) - 1:
                next_trail = power_smashing_trails[i + 1]
                next_x, next_y = next_trail[0], next_trail[1]
                # 메인 번개
                lightning_color = (150, 200, 255, int(alpha * 0.8))
                draw.line(lightning_color[:3], (x, y), (next_x, next_y), max(1, int(3 * color_intensity)))
                # 주변 전기 스파크
                for _ in range(2):
                    spark_offset_x = random.randint(-10, 10)
                    spark_offset_y = random.randint(-10, 10)
                    spark_color = (200, 220, 255, int(alpha * 0.4))
                    draw.line(spark_color[:3], (x, y), 
                                   (x + spark_offset_x, y + spark_offset_y), 1)
            # 중심 에너지 코어 (파란색-흰색 그라데이션)
            core_size = int(size * 0.6 * color_intensity)
            if core_size > 0:
                # 외부 글로우 (파란색)
                glow_color = (100, 150, 255)
                pygame.draw.circle(trail_surface, (*glow_color, int(alpha * 0.2)), 
                                 (int(center), int(center)), int(size * 0.9))
                # 중간 레이어 (밝은 파란색)
                mid_color = (150, 200, 255)
                pygame.draw.circle(trail_surface, (*mid_color, int(alpha * 0.4)), 
                                 (int(center), int(center)), int(size * 0.6))
                # 내부 코어 (거의 흰색)
                core_color = (220, 240, 255)
                pygame.draw.circle(trail_surface, (*core_color, int(alpha * 0.6)), 
                                 (int(center), int(center)), core_size)
                SCREEN.blit(trail_surface, (x - center, y - center))
    # ✨ 파워스매싱 파티클 효과 업데이트 및 그리기 (세련된 버전) - 고스트샷일 때는 제외
    if len(power_smashing_particles) > 0 and not mega_smashing_active:
        new_particles = []
        for particle in power_smashing_particles:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['vx'] *= 0.92  # 속도 감소
            particle['vy'] *= 0.92
            particle['vy'] += 0.1  # 약간의 중력 효과
            particle['life'] -= 1
            if particle['life'] > 0:
                new_particles.append(particle)
                # 에너지 파티클 그리기
                alpha = int(255 * (particle['life'] / 60))
                size = int(2 + (particle['life'] / 60) * 2)
                # 파티클 타입에 따른 렌더링
                if particle.get('type') == 'spark':
                    # 전기 스파크 타입
                    spark_length = int(5 + (particle['life'] / 60) * 5)
                    end_x = particle['x'] + particle['vx'] * 2
                    end_y = particle['y'] + particle['vy'] * 2
                    draw.line((*particle['color'], alpha), 
                                   (particle['x'], particle['y']), (end_x, end_y), 1)
                else:
                    # 에너지 구체 타입
                    particle_surface = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
                    center = size * 2
                    # 외부 글로우
                    glow_alpha = int(alpha * 0.3)
                    pygame.draw.circle(particle_surface, (*particle['color'], glow_alpha), 
                                     (center, center), size * 2)
                    # 내부 코어
                    core_alpha = int(alpha * 0.8)
                    pygame.draw.circle(particle_surface, (255, 255, 255, core_alpha), 
                                     (center, center), size)
                    SCREEN.blit(particle_surface, (particle['x'] - center, particle['y'] - center))
        power_smashing_particles = new_particles
        # 고스트샷 이펙트는 별도 함수에서 처리
        if False:  # 고스트샷 이펙트 제거 (render_mega_smashing_effects에서 처리)
            new_meteor_trail = []
            current_time = pygame.time.get_ticks() / 1000.0  # 초 단위 시간
            for meteor in mega_smashing_meteor_trail:
                # 회전 각도 업데이트 (불규칙한 속도 변화)
                speed_variation = math.sin(current_time * meteor.get('orbit_frequency', 3)) * 0.05
                meteor['angle'] += meteor['angular_speed'] * (1 + speed_variation)
                # 복잡한 나선형 움직임을 위한 반경 변화
                wobble1 = math.sin(current_time * meteor.get('orbit_frequency', 3) + meteor['offset_phase']) * meteor.get('wobble_amplitude', 5)
                wobble2 = math.cos(current_time * 2.1 + meteor['offset_phase'] * 0.7) * 3
                current_radius = meteor['radius'] + wobble1 + wobble2
                # 공 중심을 기준으로 복잡한 궤도를 그리는 위치 계산
                # 리사주 곡선 효과 추가
                x = BALL.centerx + math.cos(meteor['angle']) * current_radius + math.sin(meteor['angle'] * 2) * 10
                y = BALL.centery + math.sin(meteor['angle']) * current_radius + math.cos(meteor['angle'] * 3) * 8
                # 궤적에 현재 위치 추가
                meteor['trail'].append((x, y, meteor['life']))
                # 궤적 길이 제한
                if len(meteor['trail']) > 15:
                    meteor['trail'].pop(0)
                meteor['life'] -= 0.5  # 천천히 사라지게
                if meteor['life'] > 0:
                    new_meteor_trail.append(meteor)
                    # 유성 궤적 그리기 (무지개빛 효과)
                    if len(meteor['trail']) > 1:
                        for i in range(len(meteor['trail']) - 1):
                            x1, y1, life1 = meteor['trail'][i]
                            x2, y2, life2 = meteor['trail'][i + 1]
                            # 고스트샷 특수 색상 효과
                            trail_alpha = int((life2 / 120) * 255)
                            trail_width = int(meteor['size'] * (life2 / 120) * 0.7)
                            if trail_width > 0 and trail_alpha > 10:
                                # 무지개빛 색상 변화 (시간에 따라)
                                color_shift = meteor.get('color_shift', 0)
                                hue = (current_time * 100 + i * 10 + color_shift * 360) % 360
                                # HSV to RGB 변환 (무지개 효과)
                                c = 1.0
                                h = hue / 60.0
                                x_val = c * (1 - abs((h % 2) - 1))
                                if h < 1:
                                    r, g, b = c, x_val, 0
                                elif h < 2:
                                    r, g, b = x_val, c, 0
                                elif h < 3:
                                    r, g, b = 0, c, x_val
                                elif h < 4:
                                    r, g, b = 0, x_val, c
                                elif h < 5:
                                    r, g, b = x_val, 0, c
                                else:
                                    r, g, b = c, 0, x_val
                                # 네온 효과를 위한 밝기 증가
                                r = min(255, int(r * 255 * 1.5))
                                g = min(255, int(g * 255 * 1.5))
                                b = min(255, int(b * 255 * 1.5))
                                # 외곽 글로우 (더 밝은 색)
                                draw.line((r, g, b, min(255, trail_alpha // 2)), 
                                               (x1, y1), (x2, y2), max(1, trail_width + 2))
                                # 코어 (황금색 + 무지개)
                                core_r = min(255, (255 + r) // 2)
                                core_g = min(255, (215 + g) // 2)
                                core_b = min(255, b)
                                draw.line((core_r, core_g, core_b, min(255, trail_alpha)), 
                                               (x1, y1), (x2, y2), max(1, trail_width))
                    # 유성 헤드 그리기
                    head_size = int(meteor['size'] * (meteor['life'] / 90))
                    if head_size > 0:
                        # 홀로그램 글로우
                        glow_surface = pygame.Surface((head_size * 4, head_size * 4), pygame.SRCALPHA)
                        glow_alpha = int((meteor['life'] / 90) * 150)
                        # 외부 글로우 (청록색)
                        pygame.draw.circle(glow_surface, (0, 255, 255, min(255, glow_alpha // 2)),
                                         (head_size * 2, head_size * 2), head_size * 2)
                        # 내부 코어 (황금색)
                        pygame.draw.circle(glow_surface, (255, 215, 0, min(255, glow_alpha)),
                                         (head_size * 2, head_size * 2), head_size)
                        SCREEN.blit(glow_surface, (x - head_size * 2, y - head_size * 2))
            mega_smashing_meteor_trail = new_meteor_trail
        # 움직이는 동안 계속 파티클 생성 (더 세련된 효과) - 고스트샷일 때는 제외
        if power_smashing_parabola_active and not mega_smashing_active and random.random() < 0.7:
            # 에너지 파티클
            for _ in range(1):
                angle = random.uniform(0, 2 * math.pi)
                speed = random.uniform(0.5, 2)
                power_smashing_particles.append({
                    'x': BALL.centerx + random.randint(-5, 5),
                    'y': BALL.centery + random.randint(-5, 5),
                    'vx': math.cos(angle) * speed,
                    'vy': math.sin(angle) * speed,
                    'life': 25,
                    'color': random.choice([(100, 150, 255), (150, 200, 255), (200, 220, 255)]),
                    'type': 'energy'
                })
            # 전기 스파크
            if random.random() < 0.3:
                angle = random.uniform(0, 2 * math.pi)
                speed = random.uniform(2, 4)
                power_smashing_particles.append({
                    'x': BALL.centerx,
                    'y': BALL.centery,
                    'vx': math.cos(angle) * speed,
                    'vy': math.sin(angle) * speed,
                    'life': 15,
                    'color': (200, 230, 255),
                    'type': 'spark'
                })
    # 🎯 레이저스코프 궤적 그리기 (공 그리기 전에)
    draw_predicted_trajectory()
    # 👻 고스트샷 귀신 이펙트 렌더링
    render_mega_smashing_effects()
    # 공 이미지 결정
    ball_img_to_draw = BALL_IMG  # 🔧 예전 파워스매싱(공이 붉게 되는 것) 제거
    # 💎 고스트샷 발동 시 보라색-검은색 그라데이션 광물질 효과
    if mega_smashing_active:
        # 시간 기반 애니메이션
        ghost_time = pygame.time.get_ticks() * 0.002
        # 기본 공 이미지를 복사
        ghost_ball = ball_img_to_draw.copy()
        # 보라색 오버레이 표면 생성
        overlay = pygame.Surface((BALL.width, BALL.height), pygame.SRCALPHA)
        # 중심에서 외곽으로 그라데이션
        center_x = BALL.width // 2
        center_y = BALL.height // 2
        max_radius = BALL.width // 2
        # 어두운 보라색 틴트 효과
        tint_surface = pygame.Surface((BALL.width, BALL.height), pygame.SRCALPHA)
        # 시간에 따른 색상 변화 (맥동 효과)
        pulse = (math.sin(ghost_time * 2) + 1) * 0.5
        # 보라색-검은색 그라데이션을 위한 색상 설정
        base_purple = (60 + int(pulse * 40), 0, 80 + int(pulse * 50))  # 어두운 보라색
        # 전체적으로 어두운 보라색 틴트 적용
        pygame.draw.circle(tint_surface, (*base_purple, 180),
                         (center_x, center_y), max_radius)
        # 원본 이미지에 틴트 적용
        ghost_ball.blit(tint_surface, (0, 0), special_flags=pygame.BLEND_MULT)
        # 보라색 그라데이션 효과 추가
        for i in range(3):
            radius = max_radius - i * (max_radius // 4)
            alpha = 80 - i * 20
            color = (
                120 + int(pulse * 60) - i * 20,
                20 + int(pulse * 20) - i * 10,
                180 + int(pulse * 40) - i * 30
            )
            pygame.draw.circle(overlay, (*color, alpha),
                             (center_x, center_y), radius)
        # 오버레이를 공에 적용
        ghost_ball.blit(overlay, (0, 0), special_flags=pygame.BLEND_ADD)
        # 광물질 반짝임 효과
        sparkle_surface = pygame.Surface((BALL.width, BALL.height), pygame.SRCALPHA)
        for _ in range(5):
            sparkle_x = random.randint(5, BALL.width - 5)
            sparkle_y = random.randint(5, BALL.height - 5)
            sparkle_size = random.randint(1, 2)
            # 반짝이는 점 (밝은 보라빛)
            pygame.draw.circle(sparkle_surface, (200, 150, 255, 200),
                             (sparkle_x, sparkle_y), sparkle_size)
        ghost_ball.blit(sparkle_surface, (0, 0))
        # 크리스탈 하이라이트 효과
        highlight_offset = int(math.sin(ghost_time * 3) * 2)
        pygame.draw.circle(ghost_ball, (220, 180, 255, 200),
                         (center_x - 5 + highlight_offset, center_y - 5), 3)
        # 검은 테두리 효과
        pygame.draw.circle(overlay, (20, 0, 40, 150),
                         (center_x, center_y), max_radius, 2)
        ghost_ball.blit(overlay, (0, 0))
        # 최종 이미지로 설정
        ball_img_to_draw = ghost_ball
    # 🆕 새로운 보스전에서는 드라이브 모니터(연두색 공) 제거
    elif not new_boss_mode_active and drive_ball_active:
        # 프리즘 구체 효과를 위한 시간 기반 변화
        prism_time = pygame.time.get_ticks() * 0.003
        # 기본 공 이미지 복사
        base_ball = ball_img_to_draw.copy()
        # 선명한 무지개 색상 스펙트럼
        rainbow_colors = [
            (255, 0, 0),      # 강한 빨강
            (255, 127, 0),    # 강한 주황
            (255, 255, 0),    # 강한 노랑
            (0, 255, 0),      # 강한 초록
            (0, 127, 255),    # 강한 하늘색
            (0, 0, 255),      # 강한 파랑
            (127, 0, 255),    # 강한 보라
        ]
        # 각도에 따른 프리즘 효과
        angle_offset = prism_time % 360
        # 무지개 그라데이션 오버레이
        overlay = pygame.Surface((BALL.width, BALL.height), pygame.SRCALPHA)
        # 무지개 스트라이프 효과
        for i, color in enumerate(rainbow_colors):
            # 각 색상의 각도 계산
            stripe_angle = (angle_offset + i * 51) % 360
            # 색상 강도를 시간에 따라 변화
            pulse = (math.sin(math.radians(stripe_angle * 2)) + 1) * 0.5
            intensity = 0.4 + pulse * 0.4
            # 무지개 띠 그리기
            stripe_pos = i * 5 - 10 + int(math.sin(math.radians(stripe_angle)) * 3)
            # 각 색상 띠를 대각선으로 그리기
            for j in range(BALL.height):
                x = stripe_pos + j // 2
                if 0 <= x < BALL.width:
                    color_with_alpha = (*color, int(intensity * 150))
                    pygame.draw.line(overlay, color_with_alpha, 
                                   (x, j), (x + 2, j), 2)
        # 오버레이를 공에 블렌드
        base_ball.blit(overlay, (0, 0), special_flags=pygame.BLEND_ADD)
        # 프리즘 굴절 효과 (색상 시프트)
        shift_surface = pygame.Surface((BALL.width, BALL.height), pygame.SRCALPHA)
        color_idx = int((prism_time / 10) % len(rainbow_colors))
        prism_color = rainbow_colors[color_idx]
        shift_surface.fill((*prism_color, 40))
        base_ball.blit(shift_surface, (0, 0), special_flags=pygame.BLEND_ADD)
        # 중앙에 밝은 하이라이트 추가 (크리스탈 느낌)
        highlight = pygame.Surface((BALL.width, BALL.height), pygame.SRCALPHA)
        pygame.draw.circle(highlight, (255, 255, 255, 100),
                         (BALL.width//2 - 3, BALL.height//2 - 3), 6)
        pygame.draw.circle(highlight, (255, 255, 255, 50),
                         (BALL.width//2, BALL.height//2), 10)
        base_ball.blit(highlight, (0, 0), special_flags=pygame.BLEND_ADD)
        # 회전 적용
        rotated_ball = pygame.transform.rotate(base_ball, ball_angle)
        ball_img_rect = rotated_ball.get_rect(center=ball_rect.center)
        draw_with_shake(rotated_ball, ball_img_rect.topleft)
    else:
        # 기본 공 그리기
        rotated_ball = pygame.transform.rotate(ball_img_to_draw, ball_angle)
        ball_img_rect = rotated_ball.get_rect(center=ball_rect.center)
        draw_with_shake(rotated_ball, ball_img_rect.topleft)
    # ⚡ 라이트닝 마스터 번개 충격 효과 - 공 주위에 번개 고리
    if new_boss_mode_active and lightning_strike_active:
        # 번개 고리 그리기
        thunder_time = pygame.time.get_ticks() * 0.01
        for i in range(8):  # 8개의 번개 볼트
            angle = (i * 45 + thunder_time * 50) % 360  # 회전하는 번개
            rad = math.radians(angle)
            # 번개 볼트 위치 계산
            radius = BALL.width // 2 + 15 + math.sin(thunder_time + i) * 5
            bolt_x = ball_rect.centerx + math.cos(rad) * radius
            bolt_y = ball_rect.centery + math.sin(rad) * radius
            # 번개 색상 (번쩍거리는 효과)
            flash_intensity = int(200 + 55 * math.sin(thunder_time * 3 + i))
            lightning_color = (flash_intensity, flash_intensity, 100)
            # 번개 볼트 그리기 (중심에서 외곽으로)
            draw.line(lightning_color, ball_rect.center, (int(bolt_x), int(bolt_y)), 3)
            # 번개 끝에 작은 원 효과
            draw.circle(lightning_color, (int(bolt_x), int(bolt_y)), 4)
        # 공 중심에 전기 글로우 효과
        glow_alpha = int(100 + 50 * math.sin(thunder_time * 5))
        glow_surface = pygame.Surface((BALL.width + 30, BALL.height + 30), pygame.SRCALPHA)
        pygame.draw.circle(glow_surface, (255, 255, 150, glow_alpha), 
                         ((BALL.width + 30) // 2, (BALL.height + 30) // 2), BALL.width // 2 + 10)
        SCREEN.blit(glow_surface, (ball_rect.centerx - (BALL.width + 30) // 2, 
                                 ball_rect.centery - (BALL.height + 30) // 2))
    # 🔥 파이어 나이트 화염 돌진 효과 - 하단 패들 주위에 화염 효과
    if new_boss_mode_active and fire_charge_active:
        # 화염 효과 시간
        flame_time = pygame.time.get_ticks() * 0.015
        # 하단 패들 (파이어 나이트) 주위에 화염 고리
        for i in range(12):  # 12개의 화염 파티클
            angle = (i * 30 + flame_time * 100) % 360  # 빠르게 회전하는 화염
            rad = math.radians(angle)
            # 화염 파티클 위치 계산 (패들 주위)
            radius = PADDLE_WIDTH // 2 + 20 + math.sin(flame_time + i * 0.5) * 8
            flame_x = PLAYER.centerx + math.cos(rad) * radius
            flame_y = PLAYER.centery + math.sin(rad) * radius
            # 화염 색상 (오렌지에서 빨강으로 번갈아가며)
            flame_intensity = int(150 + 105 * math.sin(flame_time * 4 + i))
            if i % 2 == 0:
                flame_color = (255, flame_intensity, 0)  # 오렌지
            else:
                flame_color = (255, flame_intensity // 2, 0)  # 빨강
            # 화염 파티클 그리기
            flame_size = int(6 + 3 * math.sin(flame_time * 2 + i))
            draw.circle(flame_color, (int(flame_x), int(flame_y)), flame_size)
            # 내부에 밝은 중심 추가
            inner_size = max(2, flame_size - 2)
            draw.circle((255, 255, 200), (int(flame_x), int(flame_y)), inner_size)
        # 패들 중심에 화염 글로우 효과
        glow_alpha = int(80 + 40 * math.sin(flame_time * 6))
        glow_surface = pygame.Surface((PADDLE_WIDTH + 40, PADDLE_HEIGHT + 40), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_surface, (255, 100, 0, glow_alpha), 
                           (0, 0, PADDLE_WIDTH + 40, PADDLE_HEIGHT + 40))
        SCREEN.blit(glow_surface, (PLAYER.centerx - (PADDLE_WIDTH + 40) // 2, 
                                 PLAYER.centery - (PADDLE_HEIGHT + 40) // 2))
        # 화염 꼬리 효과 (패들 뒤쪽)
        for i in range(5):
            tail_x = PLAYER.centerx - i * 15  # 패들 뒤로 이어지는 꼬리
            tail_y = PLAYER.centery + random.randint(-5, 5)
            tail_alpha = int(100 - i * 15)
            if tail_alpha > 0:
                tail_surface = pygame.Surface((20, 20), pygame.SRCALPHA)
                pygame.draw.circle(tail_surface, (255, 150, 0, tail_alpha), (10, 10), 10 - i)
                SCREEN.blit(tail_surface, (tail_x - 10, tail_y - 10))
    # 🔹 공 꼬리
    if special_active:
        ball_trail.append((BALL.centerx, BALL.centery, 200))
    ball_trail = [(x, y, a - 10) for x, y, a in ball_trail if a > 10][:10]
    for x, y, alpha in ball_trail:
        trail = pygame.transform.scale(ball_img_to_draw, (BALL.width, BALL.height))
        trail.set_alpha(alpha)
        SCREEN.blit(trail, (x - BALL.width // 2, y - BALL.height // 2))
    # === Stage 5 화염탄 ===
    if current_stage == 5:
        for fireball in fireballs:
            pos = fireball[0]
            SCREEN.blit(FIREBALL_IMG, (pos[0] - 16, pos[1] - 16))
    # 🔥 화염탄 폭발 이펙트 그리기
    draw_fireball_explosion_particles()
    # === Stage 5 화염 용이 소용돌이치며 공을 따라오는 이펙트 ===
    if flame_trail_active:
        # 용의 몸체를 그리기 위한 시간 기반 애니메이션
        time_now = pygame.time.get_ticks()
        if len(flame_trail_positions) > 2:
            # 🐉 화염 용 몸체 그리기
            for i in range(len(flame_trail_positions) - 1):
                if i < len(flame_trail_positions) - 1:
                    x1, y1 = flame_trail_positions[i]
                    x2, y2 = flame_trail_positions[i + 1]
                    # 위치 비율 계산 (꼬리에서 머리로)
                    progress = i / max(1, len(flame_trail_positions) - 1)
                    # 소용돌이 효과를 위한 사인파 적용
                    wave_offset = math.sin(time_now * 0.01 + i * 0.5) * 10
                    spiral_offset = math.cos(time_now * 0.008 + i * 0.3) * 8
                    # 용의 몸체 두께 (머리로 갈수록 굵어짐)
                    thickness = int(3 + progress * 12)
                    # 색상 그라데이션 (꼬리: 어두운 붉은색 → 머리: 밝은 주황색)
                    r = int(150 + progress * 105)
                    g = int(20 + progress * 100)
                    b = int(10 + progress * 20)
                    body_color = (min(255, r), min(255, g), min(255, b))
                    # 용의 몸체 중심선
                    center_x = x1 + wave_offset
                    center_y = y1 + spiral_offset
                    # 몸체 메인 부분
                    draw.circle(body_color, 
                                     (int(center_x), int(center_y)), thickness)
                    # 용의 비늘 효과 (일정 간격마다)
                    if i % 3 == 0:
                        scale_color = (min(255, r + 50), min(255, g + 30), b)
                        draw.circle(scale_color,
                                         (int(center_x + thickness/2), int(center_y)), 
                                         max(2, thickness//3))
                    # 화염 효과 (외곽 불꽃)
                    if progress > 0.3:  # 몸체 중간부터 화염 시작
                        flame_alpha = int(100 + progress * 155)
                        for angle in range(0, 360, 60):  # 6방향 불꽃
                            flame_x = center_x + math.cos(math.radians(angle + time_now * 0.5)) * (thickness + 4)
                            flame_y = center_y + math.sin(math.radians(angle + time_now * 0.5)) * (thickness + 4)
                            flame_size = max(1, int(2 + progress * 3))
                            # 불꽃 그라데이션
                            draw.circle((255, 200, 100),
                                             (int(flame_x), int(flame_y)), flame_size)
                            if flame_size > 2:
                                draw.circle((255, 255, 200),
                                                 (int(flame_x), int(flame_y)), flame_size - 1)
            # 🐉 용의 머리 (공 위치)
            if flame_trail_positions:
                head_x, head_y = flame_trail_positions[-1]
                # 머리 본체
                draw.circle((255, 150, 50), 
                                 (int(head_x), int(head_y)), 15)
                draw.circle((255, 200, 100),
                                 (int(head_x), int(head_y)), 10)
                # 용의 눈 (빛나는 효과)
                eye_glow = int(abs(math.sin(time_now * 0.01)) * 100 + 155)
                draw.circle((eye_glow, eye_glow, 0),
                                 (int(head_x - 5), int(head_y - 3)), 3)
                draw.circle((eye_glow, eye_glow, 0),
                                 (int(head_x + 5), int(head_y - 3)), 3)
                # 용의 뿔
                horn_color = (200, 50, 50)
                draw.line(horn_color,
                               (int(head_x - 8), int(head_y - 10)),
                               (int(head_x - 12), int(head_y - 18)), 3)
                draw.line(horn_color,
                               (int(head_x + 8), int(head_y - 10)),
                               (int(head_x + 12), int(head_y - 18)), 3)
                # 화염 숨결 효과
                if random.random() < 0.6:  # 60% 확률로 화염 분출
                    for _ in range(5):
                        breath_angle = math.radians(random.randint(160, 200))  # 아래쪽 방향
                        breath_dist = random.randint(10, 25)
                        breath_x = head_x + math.cos(breath_angle) * breath_dist
                        breath_y = head_y + math.sin(breath_angle) * breath_dist
                        breath_size = random.randint(2, 4)
                        draw.circle((255, random.randint(100, 200), 0),
                                         (int(breath_x), int(breath_y)), breath_size)
    # 🚀 성능 최적화: 눈물 파티클 렌더링 최적화
    new_tear_particles = []
    # 파티클 개수 제한으로 성능 향상
    max_particles = 20  # 최대 20개 파티클만 유지
    active_particles = 0
    for p in tear_particles:
        if active_particles >= max_particles:
            break  # 최대 개수 제한
        x, y, vx, vy, alpha, size = p
        x += vx
        y += vy
        alpha -= 8  # 더 빨리 사라지게 해서 성능 향상 (5 → 8)
        if alpha > 0:
            # 🚀 성능 최적화: 간단한 원형으로 그리기 (Surface 생성 생략)
            color = (100, 150, min(255, alpha))  # 푸른 물빛
            draw.circle(color, (int(x + size//2), int(y + size//2)), size//2)
            new_tear_particles.append([x, y, vx, vy, alpha, size])
            active_particles += 1
    tear_particles[:] = new_tear_particles
    # 🎯 타격 이펙트 파티클 그리기
    draw_impact_particles()
    # 모든 이펙트 업데이트 및 그리기
    effects_manager.update_all_effects()
    effects_manager.draw_all_effects(SCREEN)
    # 터렛 미사일 업데이트 및 그리기 (스테이지 6에서만)
    if current_stage == 6:
        global player_missile_stunned_timer, player_missile_knockback_vel
        current_time = pygame.time.get_ticks()
        # 미사일 업데이트
        new_missiles = []
        missile_hit_this_frame = False  # 이번 프레임에 미사일 충돌 여부
        for missile in turret_missiles:
            # 미사일 이동
            missile['x'] += missile['vx']
            missile['y'] += missile['vy']
            missile['age'] += 1
            # 화면 밖으로 나가거나 너무 오래된 미사일 제거
            if (0 <= missile['x'] <= WIDTH and 0 <= missile['y'] <= HEIGHT and 
                missile['age'] < 300):  # 5초 후 제거
                new_missiles.append(missile)
                # 플레이어와 충돌 체크 (무적 시간이 아니고 연막 안에 있지 않을 때만)
                missile_rect = pygame.Rect(missile['x'] - 3, missile['y'] - 3, 6, 6)
                if missile_rect.colliderect(PLAYER) and current_time > player_missile_invulnerable_time and not is_player_in_smoke():
                    # 스테이지 5 화염탄과 동일한 넉백 시스템 적용
                    # 미사일 방향에 따른 넉백 속도 설정
                    missile_speed = math.sqrt(missile['vx']**2 + missile['vy']**2)
                    if missile_speed > 0:
                        # 미사일 진행 방향으로 넉백 (화염탄의 25% 강도)
                        knockback_direction = missile['vx'] / abs(missile['vx']) if missile['vx'] != 0 else random.choice([-1, 1])
                        player_missile_knockback_vel = knockback_direction * 9  # 화염탄의 25% 강도 (36 -> 18 -> 9)
                        player_missile_stunned_timer = int(0.3 * FPS)  # 화염탄과 동일한 스턴 시간 (0.3초)
                    # 충돌 효과 표시
                    effects_manager.create_impact_effect(missile['x'], missile['y'], 10, is_player=False)
                    # 화면 흔들림 효과 추가
                    for _ in range(10):
                        spark_x = PLAYER.x + random.randint(0, PLAYER.width)
                        spark_y = PLAYER.y + random.randint(0, PLAYER.height)
                        effects_manager.spawn_star_particles(spark_x, spark_y, count=3)
                    # 한 프레임에 한 번만 사운드 재생
                    if not missile_hit_this_frame:
                        SOUND_MISSILE.play()  # 미사일 충돌 사운드 재생
                        missile_hit_this_frame = True
                        # 무적 시간 설정 (0.5초로 감소)
                        player_missile_invulnerable_time = current_time + 500
                    continue  # 충돌한 미사일은 제거
        turret_missiles = new_missiles
        # 미사일 그리기 (탄도미사일 스타일)
        for missile in turret_missiles:
            mx, my = int(missile['x']), int(missile['y'])
            # 미사일 각도 계산 (진행 방향)
            angle = math.atan2(missile['vy'], missile['vx'])
            # 미사일 길이와 두께
            missile_length = 12
            missile_width = 3
            # 미사일 탄두 (앞부분 - 원뿔형)
            tip_x = mx + math.cos(angle) * missile_length // 2
            tip_y = my + math.sin(angle) * missile_length // 2
            # 미사일 후미
            tail_x = mx - math.cos(angle) * missile_length // 2
            tail_y = my - math.sin(angle) * missile_length // 2
            # 미사일 몸체 (짙은 회색 원통형)
            draw.line((80, 80, 80), 
                           (tail_x, tail_y), (tip_x, tip_y), missile_width + 2)
            draw.line((120, 120, 120), 
                           (tail_x, tail_y), (tip_x, tip_y), missile_width)
            # 탄두 (빨간색 팁)
            warhead_x = mx + math.cos(angle) * (missile_length // 2 - 2)
            warhead_y = my + math.sin(angle) * (missile_length // 2 - 2)
            draw.circle((200, 50, 50), (int(warhead_x), int(warhead_y)), 2)
            draw.circle((255, 100, 100), (int(warhead_x), int(warhead_y)), 1)
            # 날개/핀 (미사일 안정 날개)
            fin_offset = missile_length // 3
            fin_x = mx - math.cos(angle) * fin_offset
            fin_y = my - math.sin(angle) * fin_offset
            # 좌우 날개
            perp_angle = angle + math.pi / 2
            fin_size = 3
            # 왼쪽 날개
            left_fin_x = fin_x + math.cos(perp_angle) * fin_size
            left_fin_y = fin_y + math.sin(perp_angle) * fin_size
            draw.line((100, 100, 100), 
                           (int(fin_x), int(fin_y)), 
                           (int(left_fin_x), int(left_fin_y)), 2)
            # 오른쪽 날개
            right_fin_x = fin_x - math.cos(perp_angle) * fin_size
            right_fin_y = fin_y - math.sin(perp_angle) * fin_size
            draw.line((100, 100, 100), 
                           (int(fin_x), int(fin_y)), 
                           (int(right_fin_x), int(right_fin_y)), 2)
            # 추진 화염 효과
            for i in range(4):
                flame_dist = (i + 1) * 3
                flame_x = tail_x - math.cos(angle) * flame_dist
                flame_y = tail_y - math.sin(angle) * flame_dist
                flame_size = 4 - i
                if i < 2:
                    # 밝은 화염 (노란색-주황색)
                    flame_color = (255, 200 - i*50, 100 - i*30)
                else:
                    # 연기 (회색)
                    flame_color = (150 - i*20, 150 - i*20, 150 - i*20)
                draw.circle(flame_color, 
                                 (int(flame_x), int(flame_y)), flame_size)
        # 마지막 발사 시간 업데이트
        if len(turret_missiles) > 0:
            last_missile_time = pygame.time.get_ticks()
    # === 플라즈마 레이저 캐논 시스템 (스테이지 6) ===
    if current_stage == 6:
        global laser_cannon_active, last_laser_time, laser_charging, laser_charge_start, player_stunned, player_stun_end_time, laser_beam_duration, laser_rotating_mode, laser_rotation_direction, laser_cooldown
        global laser_rotation_range, laser_rotation_speed
        current_time = pygame.time.get_ticks()
        # 체력이 60% 이하일 때만 레이저 작동
        health_percent = (boss_current_health / boss_max_health) * 100
        # 5~9초마다 레이저 충전 시작 (체력 60% 이하일 때만, 혼란 상태가 아닐 때만)
        if health_percent <= 60 and not laser_charging and not laser_cannon_active and current_time - last_laser_time > laser_cooldown and boss_confused_timer == 0:
            laser_charging = True
            laser_charge_start = current_time
            # 레이저 충전 사운드 재생
            SOUND_STAGE6_BEAM_CHARGE.play()
            # 체력에 따른 레이저 패턴 결정
            if health_percent <= 40:
                # 40% 이하: 등대처럼 회전하는 레이저 (모든 요소 랜덤)
                laser_cannon_angle = random.choice([120, 90, 60])  # 시작 방향
                laser_rotating_mode = True  # 회전 모드 활성화
                laser_rotation_direction = random.choice([1, -1])  # 50% 확률로 시계방향/반시계방향
                laser_rotation_range = random.randint(40, 90)  # 회전 범위 40~90도 랜덤
                laser_rotation_speed = random.uniform(0.7, 1.5)  # 회전 속도 0.7~1.5배 랜덤
            else:
                # 60% ~ 41%: 기존 고정 방향 레이저
                laser_cannon_angle = random.choice([120, 90, 60])  # 4시(120도), 6시(90도), 8시(60도) 방향
                laser_rotating_mode = False  # 고정 모드
        # 충전 완료 후 발사
        if laser_charging and current_time - laser_charge_start > 1500:  # 1.5초 충전
            laser_charging = False
            laser_cannon_active = True
            last_laser_time = current_time
            # 체력에 따른 레이저 지속시간 설정
            if health_percent <= 40:
                laser_beam_duration = 2500  # 40% 이하: 2.5초
            else:
                laser_beam_duration = 1500  # 기본: 1.5초
            # 레이저 빔 사운드 재생
            SOUND_STAGE6_BEAM.play()
        # 레이저 빔 그리기 및 충돌 체크
        if laser_cannon_active:
            beam_time = current_time - last_laser_time
            if beam_time < laser_beam_duration:
                # 레이저 빔 위치 및 방향 계산
                # 회전 모드인 경우 등대처럼 천천히 회전
                if laser_rotating_mode:
                    # 진정한 등대 효과: 사인파를 이용한 왕복 운동
                    # 주기적으로 왕복하는 속도 (laser_rotation_speed로 조절)
                    oscillation_period = 2000 / laser_rotation_speed  # 기본 2초 주기, 속도 배율 적용
                    # 시간에 따른 진동 위치 (-1 ~ 1)
                    oscillation_factor = math.sin((beam_time / oscillation_period) * 2 * math.pi)
                    # 회전 범위의 절반만큼 좌우로 움직임
                    rotation_offset = (laser_rotation_range / 2) * oscillation_factor * laser_rotation_direction
                    # 최종 각도 계산
                    current_angle = laser_cannon_angle + rotation_offset
                    angle_rad = math.radians(current_angle)
                else:
                    # 고정 모드
                    angle_rad = math.radians(laser_cannon_angle)
                beam_start_x = BOSS.centerx
                beam_start_y = BOSS.bottom + 35  # 캐논 끝에서 시작
                # 빔 끝점 계산 (각도에 따라)
                beam_length = HEIGHT
                beam_end_x = beam_start_x + int(math.cos(angle_rad) * beam_length)
                beam_end_y = beam_start_y + int(math.sin(angle_rad) * beam_length)
                # 레이저 빔 그리기 (파란색 플라즈마)
                # 빔이 끝날 때 점점 얇아지는 효과 (마지막 0.5초 동안)
                fade_start_time = laser_beam_duration - 500  # 마지막 0.5초
                if beam_time > fade_start_time:
                    fade_progress = (beam_time - fade_start_time) / 500  # 0~1
                    beam_width = int(20 * (1 - fade_progress))  # 20에서 0으로 감소
                    beam_width = max(1, beam_width)  # 최소 1픽셀
                else:
                    beam_width = 20
                # 🌀 나선형 파장 애니메이션 (못 모양)
                # 빔 주위를 감싸고 도는 나선형 파장들
                num_spirals = 3  # 나선 개수
                for spiral_idx in range(num_spirals):
                    spiral_offset = (spiral_idx * 2 * math.pi / num_spirals) + (beam_time * 0.01)  # 시간에 따라 회전
                    # 빔을 따라 나선형 그리기
                    points_per_spiral = 30
                    for i in range(points_per_spiral):
                        t = i / points_per_spiral  # 0~1 사이의 빔 위치
                        # 빔 상의 위치
                        base_x = beam_start_x + (beam_end_x - beam_start_x) * t
                        base_y = beam_start_y + (beam_end_y - beam_start_y) * t
                        # 나선형 오프셋 계산
                        spiral_angle = spiral_offset + t * 8 * math.pi  # 빔을 따라 8회전
                        spiral_radius = beam_width + 10 + math.sin(t * math.pi) * 5  # 중간이 더 넓은 나선
                        # 빔에 수직인 방향으로 오프셋 적용
                        perpendicular_angle = angle_rad + math.pi/2
                        spiral_x = base_x + math.cos(perpendicular_angle) * math.cos(spiral_angle) * spiral_radius
                        spiral_y = base_y + math.sin(perpendicular_angle) * math.cos(spiral_angle) * spiral_radius
                        # 나선 입자 그리기
                        wave_alpha = int(150 * (1 - t))  # 끝으로 갈수록 투명
                        wave_size = 3 + int(2 * math.sin(spiral_angle))
                        wave_color = (100 + int(50 * math.sin(spiral_angle)), 
                                    150 + int(50 * math.cos(spiral_angle)), 
                                    255)
                        draw.circle(wave_color, (int(spiral_x), int(spiral_y)), wave_size)
                        # 연결선 그리기 (나선 흐름 표현)
                        if i > 0:
                            prev_t = (i-1) / points_per_spiral
                            prev_base_x = beam_start_x + (beam_end_x - beam_start_x) * prev_t
                            prev_base_y = beam_start_y + (beam_end_y - beam_start_y) * prev_t
                            prev_spiral_angle = spiral_offset + prev_t * 8 * math.pi
                            prev_spiral_x = prev_base_x + math.cos(perpendicular_angle) * math.cos(prev_spiral_angle) * spiral_radius
                            prev_spiral_y = prev_base_y + math.sin(perpendicular_angle) * math.cos(prev_spiral_angle) * spiral_radius
                            draw.line((*wave_color, wave_alpha//2), 
                                           (int(prev_spiral_x), int(prev_spiral_y)), 
                                           (int(spiral_x), int(spiral_y)), 1)
                # 외곽 글로우 효과 - 여러 개의 선으로 글로우 표현
                for i in range(5):
                    glow_alpha = 50 - i * 10
                    glow_width = beam_width + i * 8
                    glow_color = (50, 100, 255)
                    draw.line((*glow_color, glow_alpha),
                                   (beam_start_x, beam_start_y),
                                   (beam_end_x, beam_end_y), 
                                   glow_width)
                # 메인 빔
                draw.line((100, 150, 255), 
                               (beam_start_x, beam_start_y), (beam_end_x, beam_end_y), beam_width)
                draw.line((150, 200, 255), 
                               (beam_start_x, beam_start_y), (beam_end_x, beam_end_y), beam_width - 6)
                draw.line((200, 230, 255), 
                               (beam_start_x, beam_start_y), (beam_end_x, beam_end_y), beam_width - 12)
                # 전기 스파크 효과
                for _ in range(10):
                    t = random.random()  # 0~1 사이의 빔 위치
                    spark_x = beam_start_x + int((beam_end_x - beam_start_x) * t)
                    spark_y = beam_start_y + int((beam_end_y - beam_start_y) * t)
                    spark_offset = random.randint(-beam_width, beam_width)
                    spark_x += int(math.sin(angle_rad) * spark_offset)
                    spark_y -= int(math.cos(angle_rad) * spark_offset)
                    spark_length = random.randint(10, 30)
                    spark_end_x = spark_x + random.randint(-spark_length, spark_length)
                    draw.line((255, 255, 255), 
                                   (spark_x, spark_y), (spark_end_x, spark_y), 1)
                # 플레이어와 충돌 체크 (선분과 사각형 충돌)
                player_center_x = PLAYER.centerx
                player_center_y = PLAYER.centery
                # 선분과 점 사이의 최단 거리 계산
                line_vec_x = beam_end_x - beam_start_x
                line_vec_y = beam_end_y - beam_start_y
                line_len = math.sqrt(line_vec_x**2 + line_vec_y**2)
                if line_len > 0:
                    t = max(0, min(1, ((player_center_x - beam_start_x) * line_vec_x + 
                                      (player_center_y - beam_start_y) * line_vec_y) / (line_len**2)))
                    closest_x = beam_start_x + t * line_vec_x
                    closest_y = beam_start_y + t * line_vec_y
                    distance = math.sqrt((player_center_x - closest_x)**2 + (player_center_y - closest_y)**2)
                    # 플레이어 패들과 빔의 충돌 (빔 두께 + 패들 반지름, 연막 안에 있지 않을 때만)
                    if distance < beam_width/2 + PADDLE_WIDTH/2 and not player_stunned and not is_player_in_smoke():
                        # 플레이어 감전
                        player_stunned = True
                        player_stun_end_time = current_time + 1000  # 1초 스턴
                        # 감전 효과
                        SOUND_WALL.play()  # 전기 소리 대용
            else:
                laser_cannon_active = False
                # 레이저 빔 사운드 정지
                SOUND_STAGE6_BEAM.stop()
                # 다음 레이저 쿨타임을 5~9초 랜덤으로 설정
                laser_cooldown = random.randint(5000, 9000)
        # 플레이어 감전 상태 체크
        if player_stunned:
            if current_time > player_stun_end_time:
                player_stunned = False
            else:
                # 감전 효과 그리기
                for _ in range(5):
                    spark_x = PLAYER.x + random.randint(0, PLAYER.width)
                    spark_y = PLAYER.y + random.randint(0, PLAYER.height)
                    spark_size = random.randint(3, 8)
                    draw.circle((150, 200, 255), (spark_x, spark_y), spark_size)
                    draw.circle((255, 255, 255), (spark_x, spark_y), spark_size - 2)
    # === 쉴드 안테나 시스템 (스테이지 6) ===
    if current_stage == 6:
        current_time = pygame.time.get_ticks()
        # 체력이 70% 이하일 때만 쉴드 작동
        health_percent = (boss_current_health / boss_max_health) * 100
        # 쉴드 활성화 체크 (체력 70% 이하일 때만)
        if health_percent <= 70 and not shield_antenna_active and current_time - last_shield_time > shield_antenna_cooldown:
            shield_antenna_active = True
            shield_antenna_timer = current_time
            shield_fade_alpha = 255
            # 쉴드 위치 랜덤 설정 (왼쪽 또는 오른쪽)
            shield_position = random.choice(['left', 'right'])
            # 다음 쉴드 쿨다운 랜덤 설정
            shield_antenna_cooldown = random.randint(10000, 15000)
        # 쉴드 그리기 및 충돌 처리
        if shield_antenna_active:
            shield_elapsed = current_time - shield_antenna_timer
            if shield_elapsed < shield_duration:
                # 쉴드 위치에 따라 중심점 설정
                if shield_position == 'left':
                    # 왼쪽 대각선 (8시 방향 바라봄)
                    shield_center_x = BOSS.left - 50
                    shield_center_y = BOSS.bottom + 50
                    start_angle = 100  # 8시 방향 (100도~160도)
                    end_angle = 160
                elif shield_position == 'right':
                    # 오른쪽 대각선 (4시 방향 바라봄)
                    shield_center_x = BOSS.right + 50
                    shield_center_y = BOSS.bottom + 50
                    start_angle = 20  # 4시 방향 (20도~80도)
                    end_angle = 80
                else:  # center - 삭제하고 left/right만 사용
                    # 랜덤하게 left 또는 right 선택
                    if random.random() < 0.5:
                        # 왼쪽 대각선 (8시 방향)
                        shield_center_x = BOSS.left - 50
                        shield_center_y = BOSS.bottom + 50
                        start_angle = 100
                        end_angle = 160
                    else:
                        # 오른쪽 대각선 (4시 방향)
                        shield_center_x = BOSS.right + 50
                        shield_center_y = BOSS.bottom + 50
                        start_angle = 20
                        end_angle = 80
                shield_radius = 80  # 더 큰 쉴드
                # 페이드 효과
                if shield_elapsed > shield_duration - 500:  # 마지막 0.5초 페이드 아웃
                    shield_fade_alpha = int(255 * (shield_duration - shield_elapsed) / 500)
                # 초승달 모양 그리기
                shield_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
                # 여러 개의 호를 겹쳐서 초승달 효과
                for arc_num in range(3):
                    arc_radius = shield_radius + arc_num * 5
                    arc_alpha = shield_fade_alpha // (1 + arc_num)
                    arc_thickness = 3 - arc_num
                    # 호 그리기
                    for angle_deg in range(start_angle, end_angle):
                        angle = math.radians(angle_deg)
                        x1 = shield_center_x + int(math.cos(angle) * arc_radius)
                        y1 = shield_center_y + int(math.sin(angle) * arc_radius)
                        next_angle = math.radians(angle_deg + 1)
                        x2 = shield_center_x + int(math.cos(next_angle) * arc_radius)
                        y2 = shield_center_y + int(math.sin(next_angle) * arc_radius)
                        pygame.draw.line(shield_surface, (220, 240, 255, arc_alpha), 
                                       (x1, y1), (x2, y2), arc_thickness)
                # 빛나는 효과
                for i in range(2):
                    glow_alpha = shield_fade_alpha // (3 + i * 2)
                    glow_radius = shield_radius + 10 + i * 8
                    for angle_deg in range(start_angle, end_angle, 3):
                        angle = math.radians(angle_deg)
                        x = shield_center_x + int(math.cos(angle) * glow_radius)
                        y = shield_center_y + int(math.sin(angle) * glow_radius)
                        pygame.draw.circle(shield_surface, (200, 220, 255, glow_alpha), (x, y), 2)
                SCREEN.blit(shield_surface, (0, 0))
                # 쉴드 테두리 빛나는 입자
                for _ in range(5):
                    angle = random.uniform(math.radians(start_angle), math.radians(end_angle))
                    particle_dist = shield_radius + random.randint(-5, 5)
                    particle_x = shield_center_x + int(math.cos(angle) * particle_dist)
                    particle_y = shield_center_y + int(math.sin(angle) * particle_dist)
                    draw.circle((255, 255, 255), (particle_x, particle_y), 2)
                # 공과 쉴드 충돌 체크
                ball_center_x = BALL.centerx
                ball_center_y = BALL.centery
                distance_to_shield = math.sqrt((ball_center_x - shield_center_x)**2 + 
                                              (ball_center_y - shield_center_y)**2)
                # 공의 각도 계산 (쉴드 중심 기준)
                ball_angle = math.degrees(math.atan2(ball_center_y - shield_center_y, 
                                                     ball_center_x - shield_center_x))
                if ball_angle < 0:
                    ball_angle += 360
                # 공이 쉴드 호의 범위 내에 있고 적절한 거리에 있을 때 충돌
                angle_in_range = start_angle <= ball_angle <= end_angle
                distance_in_range = (shield_radius - 10) < distance_to_shield < (shield_radius + 20)
                # 공이 쉴드에 닿으면 튕겨냄
                if angle_in_range and distance_in_range and ball_vel[1] < 0:
                    # 공을 반사
                    ball_vel[1] = abs(ball_vel[1])
                    # 반사 이펙트
                    SOUND_WALL.play()
                    for _ in range(10):
                        spark_angle = random.uniform(0, math.pi * 2)
                        spark_dist = random.uniform(0, 20)
                        spark_x = ball_center_x + int(math.cos(spark_angle) * spark_dist)
                        spark_y = ball_center_y + int(math.sin(spark_angle) * spark_dist)
                        draw.circle((255, 255, 255), (spark_x, spark_y), random.randint(1, 3))
            else:
                # 쉴드 비활성화
                shield_antenna_active = False
                last_shield_time = current_time
    # === 인터셉터 시스템 (스타크래프트 캐리어 스타일) ===
    if current_stage == 6:
        current_time = pygame.time.get_ticks()
        health_percent = (boss_current_health / boss_max_health) * 100
        # 체력이 30% 이하일 때만 작동
        if health_percent <= 30:
            # 인터셉터 출격 체크 (혼란 상태가 아닐 때만)
            if not interceptor_launching and current_time - interceptor_launch_time > interceptor_cooldown and boss_confused_timer == 0:
                # 출격 준비
                interceptor_launching = True
                hangar_door_open = True
                hangar_door_timer = current_time
                # 3~4기 출격 대기 (기존 4~6기에서 25% 감소)
                num_interceptors = random.randint(3, 4)
                for i in range(num_interceptors):
                    interceptor_launch_queue.append({
                        'launch_time': current_time + 200 * i,  # 0.2초 간격으로 출격
                        'id': f"interceptor_{current_time}_{i}"
                    })
                # 다음 출격 쿨다운 설정 (시간도 늘려서 빈도 감소)
                interceptor_cooldown = random.randint(15000, 18000)
            # 격납고 문 애니메이션
            if hangar_door_open:
                door_elapsed = current_time - hangar_door_timer
                if door_elapsed < 1000:  # 1초간 열림
                    # 격납고 문 그리기
                    door_width = int(40 * (door_elapsed / 1000))
                    door_x = BOSS.centerx - 20
                    door_y = BOSS.bottom - 10
                    draw.rect((40, 40, 50), (door_x, door_y, door_width, 15))
                    draw.rect((20, 20, 30), (door_x, door_y, door_width, 15), 2)
                    # 내부 빛
                    draw.rect((100, 150, 200), (door_x + 2, door_y + 2, door_width - 4, 11))
                else:
                    # 문 완전 열림
                    door_x = BOSS.centerx - 20
                    door_y = BOSS.bottom - 10
                    draw.rect((40, 40, 50), (door_x, door_y, 40, 15))
                    draw.rect((100, 150, 200), (door_x + 2, door_y + 2, 36, 11))
            # 인터셉터 출격
            if interceptor_launch_queue:
                to_launch = []
                for interceptor_data in interceptor_launch_queue:
                    if current_time >= interceptor_data['launch_time']:
                        # 인터셉터 생성
                        new_interceptor = {
                            'id': interceptor_data['id'],
                            'x': BOSS.centerx,
                            'y': BOSS.bottom,
                            'target_x': BOSS.centerx + random.randint(-150, 150),
                            'target_y': BOSS.bottom + random.randint(80, 150),
                            'speed': 3,
                            'angle': 0,
                            'state': 'launching',  # launching, patrolling, intercepting, returning
                            'patrol_center_x': 0,
                            'patrol_center_y': 0,
                            'health': 1,  # 한 번 맞으면 파괴
                            'glow_timer': 0
                        }
                        interceptors.append(new_interceptor)
                        to_launch.append(interceptor_data)
                        SOUND_WALL.play()  # 출격 사운드
                # 출격한 인터셉터 제거
                for launched in to_launch:
                    interceptor_launch_queue.remove(launched)
                # 모든 인터셉터가 출격했으면
                if not interceptor_launch_queue:
                    interceptor_launching = False
                    interceptor_launch_time = current_time
                    # 격납고 문 닫기 타이머
                    hangar_door_timer = current_time + 1000
            # 격납고 문 닫기
            if not interceptor_launching and hangar_door_open:
                if current_time - hangar_door_timer > 500:  # 0.5초 후 닫기
                    hangar_door_open = False
            # 인터셉터 업데이트 및 그리기
            for interceptor in interceptors[:]:
                # 상태에 따른 이동
                if interceptor['state'] == 'launching':
                    # 목표 위치로 이동
                    dx = interceptor['target_x'] - interceptor['x']
                    dy = interceptor['target_y'] - interceptor['y']
                    dist = math.sqrt(dx**2 + dy**2)
                    if dist > 5:
                        interceptor['x'] += (dx / dist) * interceptor['speed']
                        interceptor['y'] += (dy / dist) * interceptor['speed']
                    else:
                        # 목표 도착, 순찰 시작
                        interceptor['state'] = 'patrolling'
                        interceptor['patrol_center_x'] = interceptor['x']
                        interceptor['patrol_center_y'] = interceptor['y']
                elif interceptor['state'] == 'patrolling':
                    # 원형 순찰
                    interceptor['angle'] += 0.05
                    patrol_radius = 30
                    interceptor['x'] = interceptor['patrol_center_x'] + math.cos(interceptor['angle']) * patrol_radius
                    interceptor['y'] = interceptor['patrol_center_y'] + math.sin(interceptor['angle']) * patrol_radius
                    # 공과의 거리 체크
                    ball_dist = math.sqrt((BALL.centerx - interceptor['x'])**2 + 
                                         (BALL.centery - interceptor['y'])**2)
                    # 공이 가까이 오면 요격 준비
                    if ball_dist < 100 and ball_vel[1] < 0:  # 공이 위로 올라가는 중
                        interceptor['state'] = 'intercepting'
                elif interceptor['state'] == 'intercepting':
                    # 공을 향해 이동
                    dx = BALL.centerx - interceptor['x']
                    dy = BALL.centery - interceptor['y']
                    dist = math.sqrt(dx**2 + dy**2)
                    if dist > 5:
                        interceptor['x'] += (dx / dist) * interceptor['speed'] * 2  # 빠른 이동
                        interceptor['y'] += (dy / dist) * interceptor['speed'] * 2
                    # 공과 충돌 체크
                    if dist < 20:
                        # 공 튀김
                        ball_vel[1] = abs(ball_vel[1])
                        ball_vel[0] += random.uniform(-2, 2)
                        # 인터셉터 파괴
                        interceptors.remove(interceptor)
                        # 폭발 이펙트
                        SOUND_STAGE6_INTERCEPTOR_HIT.play()
                        for _ in range(15):
                            spark_angle = random.uniform(0, math.pi * 2)
                            spark_dist = random.uniform(0, 25)
                            spark_x = interceptor['x'] + math.cos(spark_angle) * spark_dist
                            spark_y = interceptor['y'] + math.sin(spark_angle) * spark_dist
                            draw.circle((255, 200, 100), 
                                             (int(spark_x), int(spark_y)), random.randint(2, 4))
                        continue
                    # 공이 멀어지면 다시 순찰
                    if dist > 150 or ball_vel[1] > 0:
                        interceptor['state'] = 'patrolling'
                # 인터셉터 그리기
                interceptor['glow_timer'] += 0.1
                glow = abs(math.sin(interceptor['glow_timer'])) * 50
                # 본체 (삼각형 모양)
                points = []
                for angle in range(3):
                    angle_rad = math.radians(angle * 120 + interceptor['angle'] * 50)
                    px = interceptor['x'] + math.cos(angle_rad) * 8
                    py = interceptor['y'] + math.sin(angle_rad) * 8
                    points.append((px, py))
                # 그림자
                shadow_points = [(p[0] + 2, p[1] + 2) for p in points]
                draw.polygon((30, 30, 40), shadow_points)
                # 본체
                draw.polygon((100, 120, 140), points)
                draw.polygon((150, 170, 190), points, 2)
                # 에너지 코어
                draw.circle((100 + glow, 150 + glow, 255), 
                                 (int(interceptor['x']), int(interceptor['y'])), 3)
                draw.circle((255, 255, 255), 
                                 (int(interceptor['x']), int(interceptor['y'])), 1)
                # 추진 효과
                if interceptor['state'] in ['launching', 'intercepting']:
                    # 이동 방향 계산
                    if interceptor['state'] == 'launching':
                        move_dx = interceptor['target_x'] - interceptor['x']
                        move_dy = interceptor['target_y'] - interceptor['y']
                    else:  # intercepting
                        move_dx = BALL.centerx - interceptor['x']
                        move_dy = BALL.centery - interceptor['y']
                    move_dist = math.sqrt(move_dx**2 + move_dy**2)
                    for i in range(3):
                        trail_x = interceptor['x'] - (move_dx/move_dist if move_dist > 0 else 0) * i * 5
                        trail_y = interceptor['y'] - (move_dy/move_dist if move_dist > 0 else 0) * i * 5
                        trail_alpha = 100 - i * 30
                        draw.circle((100, 150, 200), 
                                         (int(trail_x), int(trail_y)), 4 - i)
    # 목성 띠 애니메이션 그리기 (무중력벨트 + 스피드기어 시너지)
    if gravity_speed_synergy:
        draw_jupiter_ring(SCREEN, PLAYER)
    # === HUD ===
    draw_tears()
    # 🆕 새로운 보스전에서는 UI 요소들 숨기기
    if not new_boss_mode_active:
        # 장인 아이템이 있으면 쿨타임 10% 감소 (0.8초), 쿨타임 아이템이 있으면 2.4초 추가 감소
        cooldown_reduction = 800 if master_obtained else 0  # 10% of 8000ms
        cooldown_reduction += 2400 if cooltime_obtained else 0  # 30% of 8000ms
        items.draw_active_item(SCREEN, active_item_slot, active_item_icon_size, selected_item_index, 8000 - cooldown_reduction)  # 쿨타임
        items.draw_items(SCREEN)
        draw_player_gauge()  # 플레이어 게이지바
    # 말풍선 그리기 (항상 그려야 함)
    draw_speech()
    # === Stage 3 멘헤라걸 게이지바 (세일러문 요술봉 스타일) ===
    if current_stage == 3:
        # 요술봉 위치와 크기
        wand_x = WIDTH - 50  # 오른쪽에서 50px
        wand_y = 30  # 상단에서 30px
        time_now = pygame.time.get_ticks()
        # 🌙 상단 달 장식 (반달 모양)
        moon_radius = 12
        moon_center_x = wand_x
        moon_center_y = wand_y
        # 달 배경 (금색 테두리)
        draw.circle((255, 215, 0), (moon_center_x, moon_center_y), moon_radius + 2)
        draw.circle((255, 255, 200), (moon_center_x, moon_center_y), moon_radius)
        # 반달 효과 (오른쪽을 가림)
        draw.circle((20, 20, 40), (moon_center_x + 5, moon_center_y), moon_radius - 2)
        # ⭐ 별 장식 (달 주변)
        star_offset = 20
        star_size = 4
        # 작은 별들 애니메이션
        twinkle = abs(math.sin(time_now * 0.003)) * 0.5 + 0.5
        star_color = (255, int(255 * twinkle), int(255 * twinkle))
        # 왼쪽 별
        draw.circle(star_color, (moon_center_x - star_offset, moon_center_y), star_size)
        # 오른쪽 별
        draw.circle(star_color, (moon_center_x + star_offset, moon_center_y - 5), star_size - 1)
        # 아래 별
        draw.circle(star_color, (moon_center_x + 10, moon_center_y + 15), star_size - 2)
        # 💎 보석 몸체 (육각형 스타일)
        gem_y = wand_y + 25
        gem_height = 60
        gem_width = 24
        # 보석 외곽선 (금색)
        gem_points = [
            (wand_x, gem_y),  # 상단
            (wand_x + gem_width//2, gem_y + gem_height//3),  # 오른쪽 상단
            (wand_x + gem_width//2, gem_y + gem_height*2//3),  # 오른쪽 하단
            (wand_x, gem_y + gem_height),  # 하단
            (wand_x - gem_width//2, gem_y + gem_height*2//3),  # 왼쪽 하단
            (wand_x - gem_width//2, gem_y + gem_height//3),  # 왼쪽 상단
        ]
        draw.polygon((255, 215, 0), gem_points, 3)
        # 보석 내부 배경 (반투명 분홍색)
        inner_gem_points = [
            (wand_x, gem_y + 3),
            (wand_x + gem_width//2 - 3, gem_y + gem_height//3),
            (wand_x + gem_width//2 - 3, gem_y + gem_height*2//3),
            (wand_x, gem_y + gem_height - 3),
            (wand_x - gem_width//2 + 3, gem_y + gem_height*2//3),
            (wand_x - gem_width//2 + 3, gem_y + gem_height//3),
        ]
        draw.polygon((40, 20, 40), inner_gem_points)
        # 게이지 채우기 (보석 내부에 마법 에너지)
        if displayed_boss_gauge > 0:
            fill_ratio = displayed_boss_gauge / 500
            fill_height = int((gem_height - 6) * fill_ratio)
            # 그라데이션 효과를 위한 세그먼트
            segments = 5
            for i in range(segments):
                segment_y = gem_y + gem_height - 3 - (fill_height * (i + 1) // segments)
                segment_height = fill_height // segments
                # 게이지 레벨별 색상 변화
                if displayed_boss_gauge <= 170:
                    # 은빛 → 연분홍
                    color_intensity = 200 + (55 * i // segments)
                    segment_color = (color_intensity, color_intensity, 255)
                elif displayed_boss_gauge <= 350:
                    # 연분홍 → 진분홍
                    color_intensity = 255 - (55 * i // segments)
                    segment_color = (255, color_intensity, 255)
                elif displayed_boss_gauge <= 499:
                    # 진보라색
                    color_intensity = 200 - (50 * i // segments)
                    segment_color = (200, color_intensity, 255)
                else:
                    # 무지개 효과
                    rainbow_index = int((time_now // 100 + i) % 7)
                    rainbow_colors = [(255,0,0), (255,165,0), (255,255,0), (0,255,0), (0,127,255), (0,0,255), (139,0,255)]
                    segment_color = rainbow_colors[rainbow_index]
                # 각 세그먼트를 육각형 모양에 맞춰 그리기
                if segment_y > gem_y + 3 and segment_y < gem_y + gem_height - 3:
                    # 육각형 너비 계산
                    relative_y = (segment_y - gem_y) / gem_height
                    if relative_y < 0.33:
                        width = int(gem_width * (relative_y * 3))
                    elif relative_y < 0.67:
                        width = gem_width - 6
                    else:
                        width = int(gem_width * ((1 - relative_y) * 3))
                    if width > 0:
                        draw.rect(segment_color,
                                       (wand_x - width//2, segment_y, width, segment_height))
        # ✨ 마법 반짝임 효과
        if displayed_boss_gauge >= 350:  # 파워 레벨 이상일 때
            sparkle_count = 3 if displayed_boss_gauge < 500 else 5
            for i in range(sparkle_count):
                sparkle_angle = (time_now * 0.002 + i * 2 * math.pi / sparkle_count) % (2 * math.pi)
                sparkle_x = wand_x + int(15 * math.cos(sparkle_angle))
                sparkle_y = gem_y + gem_height//2 + int(15 * math.sin(sparkle_angle))
                sparkle_size = int(2 + abs(math.sin(time_now * 0.005 + i)) * 2)
                draw.circle((255, 255, 255), (sparkle_x, sparkle_y), sparkle_size)
        # 🎀 하단 리본 장식
        ribbon_y = gem_y + gem_height + 5
        ribbon_width = 30
        ribbon_height = 8
        # 리본 중앙
        pygame.draw.ellipse(SCREEN, (255, 20, 147), 
                          (wand_x - ribbon_width//2, ribbon_y, ribbon_width, ribbon_height))
        # 리본 매듭
        draw.circle((255, 105, 180), (wand_x, ribbon_y + ribbon_height//2), 5)
        # 게이지 준비 상태 표시 (전체 요술봉 깜빡임 + 후광)
        if boss_special_ready:
            if (time_now // 250) % 2 == 0:
                # 후광 효과
                for radius in range(30, 10, -5):
                    alpha = 255 - (radius - 10) * 8
                    glow_color = (255, 200, 255, alpha)
                    draw.circle(glow_color[:3], (wand_x, gem_y + gem_height//2), radius, 2)
        # 🔢 멘헤라걸 게이지바 아래에 숫자 표시 (현재/최대)
        boss_gauge_text = f"{int(displayed_boss_gauge)}/500"
        boss_text_color = (255, 255, 255) if displayed_boss_gauge < 500 else (255, 255, 100)  # 만렙일 때는 노란색
        # 폰트 로드 (작은 크기)
        try:
            boss_gauge_font = pygame.font.Font("NanumSquareB.ttf", 14)
        except:
            boss_gauge_font = pygame.font.Font(None, 14)
        boss_gauge_text_surface = boss_gauge_font.render(boss_gauge_text, True, boss_text_color)
        boss_text_rect = boss_gauge_text_surface.get_rect()
        # 요술봉 아래쪽에 중앙 정렬
        boss_text_x = wand_x - boss_text_rect.width // 2
        boss_text_y = ribbon_y + ribbon_height + 10  # 리본 아래 10픽셀
        # 텍스트 배경 (반투명 검은 배경으로 가독성 향상)
        boss_text_bg_rect = pygame.Rect(boss_text_x - 2, boss_text_y - 1, boss_text_rect.width + 4, boss_text_rect.height + 2)
        draw.rect((0, 0, 0, 180), boss_text_bg_rect, border_radius=3)
        draw.rect((100, 100, 100), boss_text_bg_rect, 1, border_radius=3)
        # 텍스트 렌더링
        SCREEN.blit(boss_gauge_text_surface, (boss_text_x, boss_text_y))
        # === Stage 5 홍련폭염 게이지 - 용이 물고있는 신비로운 구슬 ===
    if current_stage == 5:
        # 구슬 크기와 간격
        orb_radius = 10  # 30% 작게 조정 (14 -> 10)
        spacing = 30  # 간격도 조정
        total_width = (orb_radius * 2 + spacing) * HONGRYUN_MAX_HITS - spacing
        start_x = WIDTH - total_width - 40  # 오른쪽 여백
        start_y = 30
        time_now = pygame.time.get_ticks()
        for i in range(HONGRYUN_MAX_HITS):
            orb_x = start_x + i * (orb_radius * 2 + spacing)
            # 🐉 용의 머리 그리기 (구슬 위) - 크기 조정
            dragon_color = (180, 40, 40) if i < hongryun_hit_count else (60, 60, 60)
            # 용의 머리 (삼각형) - 비율 조정
            dragon_head = [
                (orb_x - 6, start_y - orb_radius - 6),
                (orb_x + 6, start_y - orb_radius - 6),
                (orb_x, start_y - orb_radius - 11)
            ]
            draw.polygon(dragon_color, dragon_head)
            # 용의 눈 (활성화시 빛남) - 크기 조정
            if i < hongryun_hit_count:
                eye_glow = int(abs(math.sin(time_now * 0.005 + i)) * 100 + 155)
                draw.circle((eye_glow, eye_glow, 0), (orb_x - 2, start_y - orb_radius - 7), 1)
                draw.circle((eye_glow, eye_glow, 0), (orb_x + 2, start_y - orb_radius - 7), 1)
            # 🔮 영롱한 구슬 그리기
            if i < hongryun_hit_count:
                # 활성화된 구슬 - 다층 레이어로 영롱함 표현
                # 외부 광륜 (펄스 효과) - 더 붉은 색상
                pulse = abs(math.sin(time_now * 0.003 + i * 0.5))
                halo_radius = orb_radius + 5 + pulse * 3
                halo_color = (255, 50 + int(pulse * 30), 30)
                for r in range(3):
                    alpha = 60 - r * 20
                    draw.circle((*halo_color, alpha), 
                                     (orb_x, start_y), int(halo_radius - r), 1)
                # 메인 구슬 (붉은 물이 차오르는 효과)
                for layer in range(5):
                    layer_radius = orb_radius - layer * 2
                    if layer_radius > 0:
                        # 더 붉은 색상으로 변경
                        if layer == 0:  # 외곽 - 진한 붉은색
                            color = (180, 20, 20)
                        elif layer == 1:
                            color = (220, 30, 30)
                        elif layer == 2:
                            color = (255, 50, 40)
                        elif layer == 3:
                            color = (255, 80, 60)
                        else:  # 중심 - 밝은 붉은색
                            color = (255, 120, 100)
                        draw.circle(color, (orb_x, start_y), layer_radius)
                # 내부 불꽃 효과 - 붉은 핵
                flame_offset = math.sin(time_now * 0.008 + i) * 2
                draw.circle((255, 100, 80), 
                                 (orb_x + int(flame_offset), start_y), 2)
                # 빛 반사 효과 (하이라이트) - 크기 조정
                draw.circle((255, 200, 200), 
                                 (orb_x - 3, start_y - 3), 2)
                draw.circle((255, 240, 240), 
                                 (orb_x - 2, start_y - 2), 1)
                # 신비로운 불꽃 파티클 - 붉은 불씨
                if random.random() < 0.3:  # 30% 확률로 파티클 생성
                    for _ in range(2):
                        particle_angle = random.random() * math.pi * 2
                        particle_dist = orb_radius + random.randint(2, 6)
                        particle_x = orb_x + int(math.cos(particle_angle) * particle_dist)
                        particle_y = start_y + int(math.sin(particle_angle) * particle_dist)
                        particle_size = random.randint(1, 2)
                        draw.circle((255, 80, 40), 
                                         (particle_x, particle_y), particle_size)
            else:
                # 비활성 구슬 - 어둡고 투명한 느낌
                # 외곽 테두리
                draw.circle((50, 50, 50), (orb_x, start_y), orb_radius, 2)
                # 내부 (투명한 유리구슬 느낌)
                for layer in range(3):
                    layer_radius = orb_radius - layer * 3
                    if layer_radius > 0:
                        color = (40 + layer * 10, 40 + layer * 10, 40 + layer * 10)
                        draw.circle(color, (orb_x, start_y), layer_radius)
                # 희미한 하이라이트
                draw.circle((70, 70, 70), 
                                 (orb_x - 3, start_y - 3), 2)
            # 🐉 용의 턱 (구슬 아래) - 크기 조정
            jaw_points = [
                (orb_x - 7, start_y + orb_radius + 2),
                (orb_x - 4, start_y + orb_radius + 5),
                (orb_x + 4, start_y + orb_radius + 5),
                (orb_x + 7, start_y + orb_radius + 2)
            ]
            pygame.draw.lines(SCREEN, dragon_color, False, jaw_points, 2)
            # 용의 이빨 (활성화시만) - 크기 조정
            if i < hongryun_hit_count:
                for tooth_x in [-4, -1, 1, 4]:
                    draw.line((255, 255, 200), 
                                   (orb_x + tooth_x, start_y + orb_radius + 2),
                                   (orb_x + tooth_x, start_y + orb_radius + 4), 1)
def calculate_total_earned_medals(up_to_stage):
    total = 0
    for stage in range(1, up_to_stage + 1):
        total += stage_medal_rewards.get(stage, 0)
    return total
def show_victory_screen(stage_cleared, reward):
    # 스테이지 클리어 보상으로 스킬 포인트 2개 추가 (한 번만)
    import academy
    academy.add_skill_points(2)
    # 폰트 설정 (타이틀 폰트를 부드럽게 변경)
    font_title = pygame.font.Font("NanumSquareB.ttf", 48)    # 타이틀용 적당한 굵기
    font_subtitle = pygame.font.Font("NanumSquareB.ttf", 28)  # 서브타이틀용 굵은 폰트
    font_button = pygame.font.Font("NanumSquareB.ttf", 24)   # 버튼용 굵은 폰트
    font_info = pygame.font.Font("NanumSquareR.ttf", 22)     # 정보용 일반 폰트
    button_width = 280
    button_height = 70
    # 전체를 중앙으로 이동 (y 좌표 조정)
    next_stage_rect = pygame.Rect(WIDTH // 2 - button_width // 2, 420, button_width, button_height)
    skill_tree_rect = pygame.Rect(WIDTH // 2 - button_width // 2, 510, button_width, button_height)
    rest_rect = pygame.Rect(WIDTH // 2 - button_width // 2, 600, button_width, button_height)
    selected = 0  # 0: 다음 스테이지, 1: 스킬 트리, 2: 복귀
    # 화면 전환 전에 이벤트 큐 비우기
    pygame.event.get()
    # 애니메이션용 변수
    frame_count = 0
    glow_intensity = 0
    while True:
        frame_count += 1
        glow_intensity = abs(math.sin(frame_count * 0.05)) * 50  # 부드러운 글로우 효과
        # 그라데이션 배경
        for y in range(HEIGHT):
            intensity = int(20 + (y / HEIGHT) * 30)  # 20~50으로 그라데이션
            color = (intensity // 4, intensity // 8, intensity)
            draw.line(color, (0, y), (WIDTH, y))
        # 배경 파티클 효과 (별처럼 반짝이는 점들)
        for i in range(20):
            x = (i * 127) % WIDTH
            y = (i * 97 + frame_count * 2) % HEIGHT
            alpha = abs(math.sin(frame_count * 0.02 + i)) * 100 + 50
            size = int(abs(math.sin(frame_count * 0.03 + i * 0.5)) * 3) + 1
            color = (int(alpha), int(alpha), int(alpha * 1.2))
            draw.circle(color, (x, y), size)
        # 타이틀 텍스트 (부드러운 효과)
        title_text = f"Stage {stage_cleared} 클리어!"
        # 부드러운 그림자 효과
        shadow_surface = font_title.render(title_text, True, (50, 50, 80))
        shadow_rect = shadow_surface.get_rect(center=(WIDTH // 2 + 3, 153))
        SCREEN.blit(shadow_surface, shadow_rect)
        # 메인 타이틀 텍스트 (부드러운 색상)
        title_surface = font_title.render(title_text, True, (220, 220, 120))
        title_rect = title_surface.get_rect(center=(WIDTH // 2, 150))
        SCREEN.blit(title_surface, title_rect)
        # 장식용 라인
        line_y = 190
        line_color = (120, 150, 200)
        draw.line(line_color, (WIDTH // 2 - 120, line_y), (WIDTH // 2 + 120, line_y), 2)
        draw.circle(line_color, (WIDTH // 2 - 120, line_y), 4)
        draw.circle(line_color, (WIDTH // 2 + 120, line_y), 4)
        # 정보 패널 배경 (중앙으로 이동)
        info_panel_rect = pygame.Rect(WIDTH // 2 - 200, 220, 400, 150)
        draw.rect((30, 30, 60, 180), info_panel_rect)
        draw.rect((100, 150, 255), info_panel_rect, 2)
        # 메달 정보 출력 (메달 아이콘 + 숫자 + 보상)
        total_medals = calculate_total_earned_medals(stage_cleared)
        # 메달 아이콘과 텍스트를 중앙에 배치
        medal_y = 265
        # 메달 아이콘 로드 및 표시
        try:
            medal_img = pygame.image.load("medal.png")
            medal_img = pygame.transform.scale(medal_img, (35, 35))  # 적당한 크기로 조정
            medal_x = WIDTH // 2 - 70  # 중앙에서 왼쪽으로 이동
            SCREEN.blit(medal_img, (medal_x, medal_y - 17))
        except:
            # 메달 이미지 로드 실패 시 원형으로 대체
            draw.circle((255, 215, 0), (WIDTH // 2 - 55, medal_y), 17)
            draw.circle((200, 170, 0), (WIDTH // 2 - 55, medal_y), 15, 2)
        # 메달 개수 텍스트
        medal_count_text = font_info.render(f"{total_medals}", True, (255, 255, 255))
        medal_count_x = WIDTH // 2 - 25  # 메달 아이콘 옆
        SCREEN.blit(medal_count_text, (medal_count_x, medal_y - 10))
        # 보상 텍스트 (+ 형태로)
        reward_text = font_info.render(f"(+ {reward})", True, (100, 255, 100))
        reward_x = WIDTH // 2 + 15  # 메달 개수 옆
        SCREEN.blit(reward_text, (reward_x, medal_y - 10))
        # 트레이드포인트 정보 (메달 정보 아래)
        skill_point_y = medal_y + 40
        skill_point_text = font_info.render("Trade Point + 2", True, (150, 200, 255))
        skill_point_rect = skill_point_text.get_rect(center=(WIDTH // 2, skill_point_y))
        SCREEN.blit(skill_point_text, skill_point_rect)
        # 버튼들 (더 현대적인 스타일)
        buttons = [
            (next_stage_rect, "다음 스테이지로", 0),
            (skill_tree_rect, "아카데미", 1),
            (rest_rect, "복귀", 2)
        ]
        for rect, text, idx in buttons:
            is_selected = (selected == idx)
            # 버튼 배경 그라데이션
            if is_selected:
                # 선택된 버튼: 황금색 그라데이션
                for i in range(rect.height):
                    intensity = 1.0 - (i / rect.height) * 0.3
                    color = (int(255 * intensity), int(215 * intensity), int(50 * intensity))
                    draw.line(color, 
                                   (rect.left, rect.top + i), 
                                   (rect.right, rect.top + i))
                # 선택된 버튼 외곽선
                draw.rect((255, 255, 255), rect, 3)
                text_color = (30, 30, 30)
            else:
                # 일반 버튼: 블루 그라데이션
                for i in range(rect.height):
                    intensity = 1.0 - (i / rect.height) * 0.4
                    color = (int(70 * intensity), int(130 * intensity), int(200 * intensity))
                    draw.line(color, 
                                   (rect.left, rect.top + i), 
                                   (rect.right, rect.top + i))
                # 일반 버튼 외곽선
                draw.rect((120, 160, 220), rect, 2)
                text_color = (255, 255, 255)
            # 버튼 텍스트
            button_text = font_button.render(text, True, text_color)
            text_rect = button_text.get_rect(center=rect.center)
            SCREEN.blit(button_text, text_rect)
        pygame.display.flip()
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                if event.key in [pygame.K_UP, pygame.K_w]:
                    selected = (selected - 1) % 3
                elif event.key in [pygame.K_DOWN, pygame.K_s]:
                    selected = (selected + 1) % 3
                elif event.key == pygame.K_SPACE:
                    if selected == 0:
                        # 스테이지별 인트로 호출
                        if stage_cleared + 1 == 2:
                            show_stage2_intro()
                        elif stage_cleared + 1 == 3:
                            show_stage3_intro()
                        elif stage_cleared + 1 == 4:
                            show_stage4_intro()  # 추후 추가할거면 미리 준비
                        elif stage_cleared + 1 == 5:  # ✅ Stage 5 인트로 추가
                            show_stage5_intro()
                        if stage_cleared < 5:  # 스테이지 5까지만 진행
                            main(stage_cleared + 1)  # 다음 스테이지로 이동
                        else:
                            print("🎉 모든 스테이지 클리어! 게임 완료!")
                            show_start_screen()  # 메인 메뉴로 돌아가기
                        return
                    elif selected == 1:
                        # 아카데미 화면 표시
                        import academy
                        result = academy.show_academy_menu(SCREEN, WIDTH, HEIGHT)
                        if result == "quit":
                            pygame.quit()
                            sys.exit()
                        # 아카데미에서 돌아오면 계속 승리 화면 표시
                    elif selected == 2:
                        confirm_rest(stage_cleared, reward)
                        return
def confirm_rest(stage_cleared, reward):
    font_small = pygame.font.Font("NanumSquareR.ttf", 26)
    yes_rect = pygame.Rect(WIDTH // 2 - 130, 420, 100, 50)
    no_rect = pygame.Rect(WIDTH // 2 + 30, 420, 100, 50)
    selected = 0
    while True:
        SCREEN.fill((30, 0, 0))
        ui_manager.draw_centered_text("이번 회차에서 획득한 메달의 70%만 가져갈 수 있습니다.", 26, -50)
        ui_manager.draw_centered_text("괜찮으시겠습니까?", 30, 0)
        yes_color = (255, 255, 0) if selected == 0 else (100, 180, 100)
        no_color = (255, 255, 0) if selected == 1 else (180, 100, 100)
        draw.rect(yes_color, yes_rect)
        draw.rect(no_color, no_rect)
        yes_text = font_small.render("예", True, BLACK)
        no_text = font_small.render("아니오", True, BLACK)
        SCREEN.blit(yes_text, (yes_rect.centerx - yes_text.get_width() // 2, yes_rect.centery - yes_text.get_height() // 2))
        SCREEN.blit(no_text, (no_rect.centerx - no_text.get_width() // 2, no_rect.centery - no_text.get_height() // 2))
        pygame.display.flip()
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                if event.key in [pygame.K_LEFT, pygame.K_a, pygame.K_RIGHT, pygame.K_d]:
                    selected = (selected + 1) % 2
                elif event.key == pygame.K_SPACE:
                    if selected == 0:
                        global medal_score, session_medal_earned
                        earned = int(session_medal_earned * 0.7)
                        medal_score += earned
                        session_medal_earned = 0
                        # 아이템 전부 초기화
                        items.reset_items()
                        show_start_screen()
                        return
                    else:
                        # 인자 다시 넘겨주기
                        show_victory_screen(stage_cleared, reward)
                        return
def show_start_screen():
    global passive_item_list, active_item_slot, selected_item_index, MAX_ITEM_SLOTS  # bosspong.py 내부 전역변수 초기화 선언
    global chargebag_obtained, spikeboots_obtained, dashgear_obtained  # 🆕 패시브 아이템 변수 초기화
    # 아이템 초기화 (items.py 내부 변수 초기화)
    items.reset_items()
    # bosspong.py 내부 변수들도 초기화
    passive_item_list = []  # 패시브 아이템 초기화
    active_item_slot = []  # 엑티브 아이템 초기화
    selected_item_index = 0  # 선택 인덱스 초기화
    MAX_ITEM_SLOTS = 3  # 아이템 슬롯 기본값으로 초기화
    # 🆕 패시브 아이템 효과 초기화
    chargebag_obtained = False
    spikeboots_obtained = False
    dashgear_obtained = False
    # 🎓 아카데미 스킬 포인트 초기화 (게임 시작시 0포인트)
    academy.reset_skill_points()
    # 🎮 새로운 메뉴 시스템 초기화
    menu_system = MenuSystem(SCREEN, WIDTH, HEIGHT)
    menu_system.current_menu = menu_system.create_main_menu()
    # 기존 변수들 (임시 유지)
    menu_options = ["경기시작", "NEW BOSS BATTLE", "메달샵", "옵션", "게임종료"]
    selected = 0
    locked_message_timer = 0
    dev_code = [1]
    item_code = [2]
    input_buffer = []
    developer_unlocked = False
    item_manager_unlocked = False
    # 사이버펑크 홀로그램 테마 변수들
    animation_timer = 0
    # 네온 파티클 시스템 (최소화)
    neon_particles = []
    for _ in range(15):  # 파티클 수 대폭 감소
        neon_particles.append({
            "x": random.randint(0, WIDTH),
            "y": random.randint(0, HEIGHT),
            "vx": random.uniform(-0.5, 0.5),  # 더 느린 속도
            "vy": random.uniform(-0.5, 0.5),
            "size": random.randint(1, 2),  # 더 작은 크기
            "color": random.choice([(0, 255, 255), (255, 0, 128), (128, 255, 0)]),  # 색상 수 감소
            "alpha": random.randint(30, 80),  # 더 투명하게
            "pulse_speed": random.uniform(0.03, 0.08)
        })
    # 스캔라인 효과 (최소화)
    scan_lines = []
    for i in range(3):  # 스캔라인 수 대폭 감소
        scan_lines.append({
            "y": random.randint(0, HEIGHT),
            "speed": random.uniform(1.0, 2.0),
            "alpha": random.randint(20, 40),  # 더 투명하게
            "color": (0, 255, 255),  # 단일 색상
            "width": 1  # 얇은 라인
        })
    # 글리치 효과
    glitch_timer = 0
    glitch_active = False
    # 깔끔한 디지털 매트릭스 효과
    matrix_drops = []
    for x in range(0, WIDTH, 100):  # 간격을 넓게
        matrix_drops.append({
            "x": x,
            "y": random.randint(-HEIGHT, 0),
            "speed": random.uniform(0.5, 1.5),  # 느린 속도
            "chars": ["0", "1"],
            "color": (0, 80, 120)  # 어두운 청록색
        })
    # 🎬 시네마틱 영상 관련 변수들 (메인메뉴 진입 기준)
    idle_start_time = pygame.time.get_ticks()  # 대기 시작 시간 (실제 시간 기반)
    cinematic_trigger_time = 15000  # 15초 (밀리초)
    try:
        medal_icon = pygame.image.load("medal.png")
        medal_icon = pygame.transform.scale(medal_icon, (32, 32))
    except:
        medal_icon = pygame.Surface((32, 32))
        medal_icon.fill((255, 215, 0))
    while True:
        animation_timer += 1
        current_time = pygame.time.get_ticks()
        # 🎬 15초 대기 후 시네마틱 영상 재생 (실제 시간 기반)
        if current_time - idle_start_time >= cinematic_trigger_time:
            cinematic.show_cinematic_scenes(SCREEN, WIDTH, HEIGHT)
            idle_start_time = pygame.time.get_ticks()  # 시네마틱 종료 후 타이머 리셋
        # 사이버펑크 배경 그리기 (그라데이션) - 캐릭터 선택 화면과 동일
        for y in range(HEIGHT):
            ratio = y / HEIGHT
            r = int(10 + ratio * 30)  # 더 밝은 빨강
            g = int(20 + ratio * 40)  # 더 밝은 초록
            b = int(40 + ratio * 60)  # 더 밝은 파랑
            color = (r, g, b)
            draw.line(color, (0, y), (WIDTH, y))
        # 홀로그램 격자 패턴 - 캐릭터 선택 화면과 동일
        grid_color = (0, 150, 200, 25)
        grid_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        for x in range(0, WIDTH, 30):
            pygame.draw.line(grid_surface, grid_color, (x, 0), (x, HEIGHT))
        for y in range(0, HEIGHT, 30):
            pygame.draw.line(grid_surface, grid_color, (0, y), (WIDTH, y))
        SCREEN.blit(grid_surface, (0, 0))
        # 은하수 배경 (고퀄리티 사이버펑크)
        galaxy_surf = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        # 은하수 중심선
        for x in range(WIDTH):
            galaxy_y = HEIGHT // 3 + int(50 * math.sin(x * 0.01 + animation_timer * 0.02))
            for dy in range(-30, 30):
                distance = abs(dy)
                alpha = max(0, 40 - distance)
                if alpha > 0:
                    color_shift = math.sin(x * 0.02 + animation_timer * 0.01)
                    r = int(100 + 50 * color_shift)
                    g = int(50 + 100 * abs(color_shift))
                    b = int(150 + 50 * color_shift)
                    pygame.draw.circle(galaxy_surf, (r, g, b, alpha), (x, galaxy_y + dy), 1)
        # 성운 구름 효과
        for i in range(5):
            nebula_x = 100 + i * 100
            nebula_y = HEIGHT // 3 + int(30 * math.sin(i + animation_timer * 0.015))
            nebula_color = [(255, 100, 150, 20), (100, 150, 255, 20), (150, 255, 100, 20)][i % 3]
            for r in range(60, 0, -5):
                alpha = nebula_color[3] * (r / 60)
                nebula_circle = pygame.Surface((r * 2, r * 2), pygame.SRCALPHA)
                pygame.draw.circle(nebula_circle, (*nebula_color[:3], int(alpha)), (r, r), r)
                galaxy_surf.blit(nebula_circle, (nebula_x - r, nebula_y - r))
        SCREEN.blit(galaxy_surf, (0, 0))
        # 고퀄리티 자전하는 행성들
        # 1. 거대한 붉은 행성 (토성 스타일)
        planet1_x, planet1_y = 120, 150
        planet1_radius = 85
        rotation1 = animation_timer * 0.01
        # 행성 본체 (자전 표현)
        planet1_surf = pygame.Surface((planet1_radius * 2, planet1_radius * 2), pygame.SRCALPHA)
        for i in range(planet1_radius, 0, -1):
            ratio = i / planet1_radius
            # 자전에 따른 색상 변화
            rotation_offset = math.sin(rotation1 + i * 0.1) * 20
            color = (
                min(255, int(200 + 55 * (1 - ratio) + rotation_offset)),
                min(255, int(50 + 30 * (1 - ratio))),
                min(255, int(30 + 50 * (1 - ratio)))
            )
            pygame.draw.circle(planet1_surf, (*color, int(180 * ratio)), (planet1_radius, planet1_radius), i)
        # 자전 띠 패턴
        for j in range(5):
            band_y = planet1_radius - 30 + j * 15
            band_offset = int(20 * math.sin(rotation1 + j))
            pygame.draw.arc(planet1_surf, (255, 150, 100, 50), 
                          (band_offset, band_y - 5, planet1_radius * 2 - band_offset * 2, 10),
                          0, math.pi, 2)
        SCREEN.blit(planet1_surf, (planet1_x - planet1_radius, planet1_y - planet1_radius))
        # 삼중 고리 시스템
        for ring_num in range(3):
            ring_radius = planet1_radius + 20 + ring_num * 15
            ring_surf = pygame.Surface((ring_radius * 2, ring_radius // 2), pygame.SRCALPHA)
            ring_rotation = rotation1 * (1 + ring_num * 0.2)
            # 고리 입자들
            for angle in range(0, 360, 5):
                particle_angle = math.radians(angle + ring_rotation * 100)
                particle_x = ring_radius + math.cos(particle_angle) * (ring_radius - 10)
                particle_y = ring_radius // 4 + math.sin(particle_angle) * 20
                particle_color = (255, 200 - ring_num * 50, 100, 80 - ring_num * 20)
                pygame.draw.circle(ring_surf, particle_color, (int(particle_x), int(particle_y)), 2)
            SCREEN.blit(ring_surf, (planet1_x - ring_radius, planet1_y - 10))
        # 2. 사이버펑크 가스 거인 (목성 스타일)
        planet2_x, planet2_y = WIDTH - 100, 280
        planet2_radius = 65
        rotation2 = animation_timer * 0.015
        planet2_surf = pygame.Surface((planet2_radius * 2, planet2_radius * 2), pygame.SRCALPHA)
        # 소용돌이 패턴
        for i in range(planet2_radius, 0, -1):
            ratio = i / planet2_radius
            # 대적점 효과
            storm_offset = math.sin(rotation2 + i * 0.05) * 30
            color = (
                min(255, int(150 + 100 * (1 - ratio) + storm_offset * 0.5)),
                min(255, int(50 + 150 * (1 - ratio))),
                min(255, int(200 + 55 * (1 - ratio) + storm_offset))
            )
            pygame.draw.circle(planet2_surf, (*color, int(150 * ratio)), (planet2_radius, planet2_radius), i)
        # 대적점 (Great Storm)
        storm_x = planet2_radius + int(30 * math.cos(rotation2))
        storm_y = planet2_radius
        pygame.draw.ellipse(planet2_surf, (255, 100, 150, 100), 
                          (storm_x - 20, storm_y - 10, 40, 20))
        # 가스 띠 (움직이는)
        for j in range(6):
            band_y = planet2_radius - 40 + j * 15
            flow_offset = int(10 * math.sin(rotation2 * 2 + j))
            band_color = (200 - j * 20, 100 + j * 10, 255, 60)
            pygame.draw.line(planet2_surf, band_color,
                           (flow_offset, band_y), 
                           (planet2_radius * 2 - flow_offset, band_y), 3)
        SCREEN.blit(planet2_surf, (planet2_x - planet2_radius, planet2_y - planet2_radius))
        # 3. 네온 도시 행성 (사이버펑크 지구)
        planet3_x, planet3_y = 90, HEIGHT - 200
        planet3_radius = 50
        rotation3 = animation_timer * 0.02
        planet3_surf = pygame.Surface((planet3_radius * 2, planet3_radius * 2), pygame.SRCALPHA)
        # 행성 기본
        for i in range(planet3_radius, 0, -1):
            ratio = i / planet3_radius
            color = (
                int(30 + 70 * (1 - ratio)),
                int(80 + 100 * (1 - ratio)),
                int(120 + 100 * (1 - ratio))
            )
            pygame.draw.circle(planet3_surf, (*color, int(180 * ratio)), (planet3_radius, planet3_radius), i)
        # 도시 불빛 (자전하며 나타났다 사라짐)
        for angle in range(0, 360, 15):
            city_angle = math.radians(angle + rotation3 * 100)
            visibility = max(0, math.cos(city_angle))  # 앞면에만 보임
            if visibility > 0:
                dist = random.uniform(planet3_radius * 0.3, planet3_radius * 0.8)
                city_x = planet3_radius + math.cos(city_angle) * dist
                city_y = planet3_radius + math.sin(city_angle * 0.5) * dist * 0.7
                city_color = random.choice([(255, 255, 0), (0, 255, 255), (255, 0, 255)])
                alpha = int(visibility * 255)
                pygame.draw.circle(planet3_surf, (*city_color, alpha), 
                                 (int(city_x), int(city_y)), 2)
        # 대기층 글로우
        glow_surf = pygame.Surface((planet3_radius * 2 + 20, planet3_radius * 2 + 20), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (0, 200, 255, 30), 
                         (planet3_radius + 10, planet3_radius + 10), planet3_radius + 10)
        SCREEN.blit(glow_surf, (planet3_x - planet3_radius - 10, planet3_y - planet3_radius - 10))
        SCREEN.blit(planet3_surf, (planet3_x - planet3_radius, planet3_y - planet3_radius))
        # 4. 크리스탈 달 (얼음 위성)
        moon_x, moon_y = WIDTH - 150, HEIGHT - 180
        moon_radius = 30
        rotation4 = animation_timer * 0.025
        moon_surf = pygame.Surface((moon_radius * 2, moon_radius * 2), pygame.SRCALPHA)
        # 크리스탈 표면
        for i in range(moon_radius, 0, -1):
            ratio = i / moon_radius
            crystal_shift = math.sin(rotation4 + i * 0.2) * 20
            gray = min(255, max(0, int(180 + 70 * (1 - ratio) + crystal_shift)))
            moon_surf = pygame.Surface((i * 2, i * 2), pygame.SRCALPHA)
            alpha = min(255, max(0, int(150 * ratio)))
            color = (gray, gray, min(255, gray + 30), alpha)
            pygame.draw.circle(moon_surf, color, (i, i), i)
            SCREEN.blit(moon_surf, (moon_x - i, moon_y - i))
        # 크리스탈 반사 효과
        for angle in range(0, 360, 45):
            crystal_angle = math.radians(angle + rotation4 * 200)
            crystal_x = moon_x + math.cos(crystal_angle) * moon_radius * 0.7
            crystal_y = moon_y + math.sin(crystal_angle) * moon_radius * 0.7
            draw.circle((200, 220, 255, 100), 
                             (int(crystal_x), int(crystal_y)), 3)
        # 5. 파괴된 행성 잔해 (소행성 벨트)
        debris_center_x, debris_center_y = WIDTH // 2, 100
        for i in range(12):
            debris_angle = math.radians(i * 30 + animation_timer * 0.5)
            debris_dist = 40 + math.sin(i + animation_timer * 0.03) * 10
            dx = debris_center_x + math.cos(debris_angle) * debris_dist
            dy = debris_center_y + math.sin(debris_angle) * debris_dist
            # 각 조각마다 독립적 회전
            piece_rotation = animation_timer * (0.02 + i * 0.01)
            size = 5 + i % 3 * 3
            # 네온 테두리를 가진 조각
            debris_color = [(255, 100, 100), (100, 255, 100), (100, 100, 255)][i % 3]
            points = []
            for j in range(5):
                angle = math.radians(j * 72 + piece_rotation * 100)
                px = dx + math.cos(angle) * size
                py = dy + math.sin(angle) * size
                points.append((px, py))
            draw.polygon((*debris_color, 150), points)
            draw.polygon((0, 255, 255), points, 2)
        # 홀로그램 별 효과
        if not hasattr(show_start_screen, 'stars'):
            show_start_screen.stars = []
            for _ in range(100):
                show_start_screen.stars.append({
                    'x': random.randint(0, WIDTH),
                    'y': random.randint(0, HEIGHT),
                    'size': random.uniform(0.5, 2),
                    'twinkle': random.uniform(0, math.pi * 2)
                })
        for star in show_start_screen.stars:
            twinkle = abs(math.sin(star['twinkle'] + animation_timer * 0.05))
            star_alpha = int(twinkle * 100)
            star_color = (255, 255, 255, star_alpha)
            star_surf = pygame.Surface((int(star['size'] * 4), int(star['size'] * 4)), pygame.SRCALPHA)
            pygame.draw.circle(star_surf, star_color, 
                             (int(star['size'] * 2), int(star['size'] * 2)), int(star['size']))
            SCREEN.blit(star_surf, (star['x'] - star['size'] * 2, star['y'] - star['size'] * 2))
        # 네온 파티클 업데이트 및 그리기 - 캐릭터 선택 화면과 동일
        for particle in neon_particles:
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            # 화면 경계 처리
            if particle["x"] < 0 or particle["x"] > WIDTH:
                particle["vx"] *= -1
            if particle["y"] < 0 or particle["y"] > HEIGHT:
                particle["vy"] *= -1
            # 펄스 효과
            pulse = abs(math.sin(animation_timer * particle["pulse_speed"]))
            current_alpha = int(particle["alpha"] * (0.5 + pulse * 0.5))
            # 네온 글로우 파티클
            for i in range(2):
                glow_size = particle["size"] + i * 2
                glow_alpha = current_alpha // (i + 1)
                glow_surf = pygame.Surface((glow_size * 4, glow_size * 4), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*particle["color"], glow_alpha),
                                 (glow_size * 2, glow_size * 2), glow_size)
                SCREEN.blit(glow_surf, (particle["x"] - glow_size * 2, 
                                       particle["y"] - glow_size * 2))
        # 스캔라인 효과 - 캐릭터 선택 화면과 동일
        for scan_line in scan_lines:
            scan_line["y"] += scan_line["speed"]
            if scan_line["y"] > HEIGHT:
                scan_line["y"] = -10
            # 더 화려한 스캔라인
            for i in range(3):
                scan_alpha = scan_line["alpha"] - i * 10
                if scan_alpha > 0:
                    scan_surf = pygame.Surface((WIDTH, 2 - i), pygame.SRCALPHA)
                    scan_surf.fill((0, 255, 255, scan_alpha))
                    SCREEN.blit(scan_surf, (0, scan_line["y"] + i))
        # 홀로그램 메달 표시
        medal_panel = pygame.Surface((150, 50), pygame.SRCALPHA)
        medal_panel.fill((10, 15, 25, 180))
        pygame.draw.rect(medal_panel, (255, 215, 0), (0, 0, 150, 50), 2, border_radius=8)
        SCREEN.blit(medal_panel, (WIDTH - 170, 10))
        # 메달 아이콘과 텍스트
        try:
            font_medal = pygame.font.Font("NanumSquareB.ttf", 24)
        except:
            font_medal = pygame.font.Font(None, 24)
        # 전역 변수 medal_score 사용
        global medal_score
        medal_text = font_medal.render(f"🏅 {medal_score}", True, (255, 215, 0))
        medal_rect = medal_text.get_rect(center=(WIDTH - 95, 35))
        SCREEN.blit(medal_text, medal_rect)
        # 메뉴 제목 (우아하게)
        try:
            font_title = pygame.font.Font("NanumSquareB.ttf", 48)
        except:
            font_title = pygame.font.Font(None, 48)
        title_text = font_title.render("메인 메뉴", True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(WIDTH // 2, 120))
        # 간단한 텍스트 그림자만
        shadow_text = font_title.render("메인 메뉴", True, (0, 20, 30))
        shadow_rect = shadow_text.get_rect(center=(WIDTH // 2 + 2, 122))
        SCREEN.blit(shadow_text, shadow_rect)
        SCREEN.blit(title_text, title_rect)
        # 메뉴 출력 (우아하게)
        # 🆕 메뉴 옵션에 이모지와 설명 추가
        display_options = []
        for option in menu_options:
            if option == "경기시작":
                display_options.append("🏟️ 경기시작")
            elif option == "헬모드":
                display_options.append("🔥 헬모드")
            elif option == "NEW BOSS BATTLE":
                display_options.append("✨ NEW BOSS BATTLE")
            elif option == "메달샵":
                display_options.append("🏆 메달샵")
            elif option == "옵션":
                display_options.append("⚙️ 옵션")
            elif option == "게임종료":
                display_options.append("🚪 게임종료")
            else:
                display_options.append(option)
        # 개발자/아이템관리 옵션 추가
        if developer_unlocked:
            display_options.append("🔧 개발자")
        if item_manager_unlocked:
            display_options.append("📦 아이템관리")
        all_options = menu_options + (["개발자"] if developer_unlocked else []) + (["아이템관리"] if item_manager_unlocked else [])
        for i, (option, display_option) in enumerate(zip(all_options, display_options)):
            # 메뉴 아이템 배경 (선택된 항목만)
            if i == selected:
                # 선택된 항목 배경
                option_width = 300
                option_height = 50
                option_x = WIDTH // 2 - option_width // 2
                option_y = 220 + i * 60
                # 심플한 선택 표시
                option_bg = pygame.Surface((option_width, option_height), pygame.SRCALPHA)
                pygame.draw.rect(option_bg, (20, 30, 40, 100), (0, 0, option_width, option_height), border_radius=10)
                pygame.draw.rect(option_bg, (0, 150, 200, 200), (0, 0, option_width, option_height), width=2, border_radius=10)
                SCREEN.blit(option_bg, (option_x, option_y))
            # 텍스트 색상 결정
            if i == selected:
                color = (255, 255, 0)  # 선택된 항목은 노란색
                try:
                    font_option = pygame.font.Font("NanumSquareB.ttf", 32)
                except:
                    font_option = pygame.font.Font(None, 32)
            else:
                color = (220, 220, 220)  # 일반 항목은 은은한 흰색
                try:
                    font_option = pygame.font.Font("NanumSquareR.ttf", 28)
                except:
                    font_option = pygame.font.Font(None, 28)
            # 텍스트 그림자 제거 (깔끔함을 위해)
            # 메인 텍스트
            option_surface = font_option.render(display_option, True, color)
            option_rect = option_surface.get_rect(center=(WIDTH // 2, 245 + i * 60))
            SCREEN.blit(option_surface, option_rect)
            # 🆕 NEW BOSS BATTLE 선택 시 추가 설명 표시
            if i == selected and option == "NEW BOSS BATTLE":
                try:
                    font_desc = pygame.font.Font("NanumSquareR.ttf", 16)
                except:
                    font_desc = pygame.font.Font(None, 16)
                desc_text = font_desc.render("⚡🧊🔥💨 4명의 새로운 보스들의 대결!", True, (200, 200, 255))
                desc_rect = desc_text.get_rect(center=(WIDTH // 2, 245 + i * 60 + 25))
                SCREEN.blit(desc_text, desc_rect)
        if locked_message_timer > 0:
            # 잠금 메시지 배경
            message_width = 400
            message_height = 40
            message_x = WIDTH // 2 - message_width // 2
            message_y = 580
            # 배경 글로우
            for j in range(10, 0, -2):
                alpha = int(60 * (1 - j / 10))
                glow_surface = pygame.Surface((message_width + j*2, message_height + j*2), pygame.SRCALPHA)
                pygame.draw.rect(glow_surface, (255, 100, 100, alpha), (0, 0, message_width + j*2, message_height + j*2), border_radius=20)
                SCREEN.blit(glow_surface, (message_x - j, message_y - j))
            # 메인 배경
            message_bg = pygame.Surface((message_width, message_height), pygame.SRCALPHA)
            pygame.draw.rect(message_bg, (255, 100, 100, 40), (0, 0, message_width, message_height), border_radius=20)
            pygame.draw.rect(message_bg, (255, 100, 100, 120), (0, 0, message_width, message_height), width=2, border_radius=20)
            SCREEN.blit(message_bg, (message_x, message_y))
            # 메시지 텍스트
            try:
                font_message = pygame.font.Font("NanumSquareR.ttf", 24)
            except:
                font_message = pygame.font.Font(None, 24)
            # 텍스트 그림자
            message_shadow = font_message.render("모든 보스를 클리어시 해금됩니다", True, (100, 50, 50))
            message_rect = message_shadow.get_rect(center=(WIDTH // 2 + 1, 600 + 1))
            SCREEN.blit(message_shadow, message_rect)
            # 메인 텍스트
            locked_surface = font_message.render("모든 보스를 클리어시 해금됩니다", True, (255, 150, 150))
            message_rect = locked_surface.get_rect(center=(WIDTH // 2, 600))
            SCREEN.blit(locked_surface, message_rect)
            locked_message_timer -= 1
        pygame.display.flip()
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.MOUSEBUTTONDOWN or event.type == pygame.MOUSEMOTION:
                idle_start_time = pygame.time.get_ticks()  # 🎬 마우스 활동 시 대기 타이머 리셋
            elif event.type == pygame.KEYDOWN:
                idle_start_time = pygame.time.get_ticks()  # 🎬 키 입력 시 대기 타이머 리셋
                # 숫자 키 바로 이동
                if event.key == pygame.K_1:
                    SOUND_BUTTON_CLICK.play()  # 🎵 클릭 사운드
                    show_developer_stage_select()
                    return
                elif event.key == pygame.K_2:
                    SOUND_BUTTON_CLICK.play()  # 🎵 클릭 사운드
                    show_item_manager_menu()
                    return
                if pygame.K_0 <= event.key <= pygame.K_9:
                    num = event.key - pygame.K_0
                    input_buffer.append(num)
                    if input_buffer[-4:] == dev_code:
                        developer_unlocked = True
                    if input_buffer[-4:] == item_code:
                        item_manager_unlocked = True
                if event.key in [pygame.K_DOWN, pygame.K_s]:
                    selected = (selected + 1) % len(all_options)
                    SOUND_BUTTON_HOVER.play()  # 🎵 호버 사운드
                elif event.key in [pygame.K_UP, pygame.K_w]:
                    selected = (selected - 1) % len(all_options)
                    SOUND_BUTTON_HOVER.play()  # 🎵 호버 사운드
                elif event.key == pygame.K_SPACE:
                    SOUND_BUTTON_CLICK.play()  # 🎵 클릭 사운드
                    choice = all_options[selected]
                    if choice == "경기시작":
                        # 플레이어 캐릭터 선택 화면으로 이동
                        selected_character = show_character_selection()
                        if selected_character is not None:
                            # 캐릭터 선택 후 난이도 선택
                            selected_difficulty = show_difficulty_selection()
                            if selected_difficulty is not None:
                                # 선택한 난이도로 게임 시작
                                start_game_with_difficulty(selected_character, selected_difficulty)
                        return
# 헬모드 제거됨
                    elif choice == "NEW BOSS BATTLE":
                        # 🆕 새로운 보스 배틀 모드 바로 시작
                        main(1, new_boss_mode=True)
                        return
                    elif choice == "메달샵":
                        # 메달샵 기능 (아직 구현되지 않음)
                        locked_message_timer = 120
                    elif choice == "옵션":
                        option_module.show_options_menu(SCREEN, WIDTH, HEIGHT)
                    elif choice == "게임종료":
                        pygame.quit()
                        sys.exit()
                    elif choice == "개발자":
                        show_developer_stage_select()
                    elif choice == "아이템관리":
                        show_item_manager_menu()
def show_character_selection():
    """사이버펑크 스타일 홀로그램 캐릭터 선택 화면"""
    clock = pygame.time.Clock()
    # 6개 캐릭터 정의 (해금 시스템 포함)
    characters = [
        {
            "id": "ufo_player",
            "name": "UFO 파일럿",
            "description": "균형잡힌 올라운드 캐릭터",
            "image": "ufo_player.png",
            "stats": {"속도": 5, "파워": 5, "방어": 5},
            "special": "🌟 평범하지만 안정적인 플레이",
            "unlocked": True,
            "card_color": (0, 255, 255),  # 사이버 청록
            "glow_color": (0, 200, 255),
            "card_suit": "◆"
        },
        {
            "id": "speed_player",
            "name": "스피드 레이서",
            "description": "빠른 속도로 승부하는 캐릭터",
            "image": "speed_player.png",
            "stats": {"속도": 8, "파워": 3, "방어": 4},
            "special": "⚡ 고속 이동과 빠른 반응",
            "unlocked": False,
            "card_color": (255, 0, 128),  # 네온 핑크
            "glow_color": (255, 50, 150),
            "card_suit": "◆"
        },
        {
            "id": "power_player", 
            "name": "파워 스매셔",
            "description": "강력한 파워로 압도하는 캐릭터",
            "image": "power_player.png",
            "stats": {"속도": 3, "파워": 8, "방어": 4},
            "special": "💪 강력한 스매싱과 파워샷",
            "unlocked": False,
            "card_color": (255, 128, 0),  # 네온 오렌지
            "glow_color": (255, 150, 50),
            "card_suit": "◆"
        },
        {
            "id": "defense_player",
            "name": "가디언",
            "description": "견고한 방어력을 자랑하는 캐릭터",
            "image": "defense_player.png", 
            "stats": {"속도": 4, "파워": 3, "방어": 8},
            "special": "🛡️ 뛰어난 방어력과 카운터",
            "unlocked": False,
            "card_color": (128, 255, 0),  # 네온 그린
            "glow_color": (150, 255, 50),
            "card_suit": "◆"
        },
        {
            "id": "tech_player",
            "name": "테크 마스터",
            "description": "첨단 기술로 무장한 캐릭터",
            "image": "tech_player.png",
            "stats": {"속도": 6, "파워": 6, "방어": 3},
            "special": "🔧 특수 아이템과 기술력",
            "unlocked": False,
            "card_color": (128, 0, 255),  # 네온 퍼플
            "glow_color": (150, 50, 255),
            "card_suit": "◆"
        },
        {
            "id": "mystic_player",
            "name": "미스틱",
            "description": "신비로운 능력을 가진 캐릭터",
            "image": "mystic_player.png",
            "stats": {"속도": 7, "파워": 7, "방어": 1},
            "special": "🌟 예측 불가능한 특수 능력",
            "unlocked": False,
            "card_color": (255, 255, 0),  # 네온 옐로우
            "glow_color": (255, 255, 100),
            "card_suit": "◆"
        }
    ]
    selected = 0
    animation_timer = 0
    card_flip_timer = 0
    transition_progress = 0
    # 카드 이동 애니메이션 관련
    card_transition_active = False
    card_transition_progress = 0.0
    card_transition_duration = 45  # 더 부드러운 애니메이션
    previous_selected = 0
    # 카드 위치 저장용
    card_start_pos = (0, 0)
    card_target_pos = (0, 0)
    # 홀로그램 카드 관련 변수들
    card_width = 140  # 더 큰 카드
    card_height = 200
    # 선택된 카드는 더 크게
    # 부채꼴 카드들 위치 (하단, 더 넓은 배치)
    fan_radius = 320
    fan_angle_range = 120  # 더 넓은 부채꼴
    center_x = WIDTH // 2
    center_y = HEIGHT - 100
    # 홀로그램 카드 뒷면 패턴들 (사이버펑크 스타일)
    card_back_patterns = [
        {"color": (0, 20, 40), "pattern": "circuit", "accent": (0, 255, 255)},
        {"color": (40, 0, 20), "pattern": "matrix", "accent": (255, 0, 128)},
        {"color": (20, 40, 0), "pattern": "grid", "accent": (128, 255, 0)},
        {"color": (40, 30, 0), "pattern": "wave", "accent": (255, 128, 0)},
        {"color": (20, 0, 40), "pattern": "hex", "accent": (128, 0, 255)},
        {"color": (40, 40, 0), "pattern": "scan", "accent": (255, 255, 0)}
    ]
    # 사이버펑크 배경 효과용 변수들
    neon_particles = []
    for _ in range(50):  # 더 많은 네온 파티클
        neon_particles.append({
            "x": random.randint(0, WIDTH),
            "y": random.randint(0, HEIGHT),
            "vx": random.uniform(-1, 1),
            "vy": random.uniform(-1, 1),
            "size": random.randint(1, 3),
            "color": random.choice([(0, 255, 255), (255, 0, 255), (255, 255, 0)]),
            "alpha": random.randint(40, 100),
            "pulse_speed": random.uniform(0.05, 0.15)
        })
    # 스캔라인 효과
    scan_lines = []
    for i in range(5):  # 더 많은 스캔라인
        scan_lines.append({
            "y": random.randint(0, HEIGHT),
            "speed": random.uniform(2, 4),
            "alpha": random.randint(20, 40)
        })
    # 홀로그램 글리치 효과
    glitch_timer = 0
    glitch_active = False
    while True:
        animation_timer += 1
        card_flip_timer += 1
        glitch_timer += 1
        # 랜덤 글리치 효과 활성화
        if random.randint(0, 300) == 0:
            glitch_active = True
        if glitch_timer > 10:
            glitch_active = False
            glitch_timer = 0
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return None  # 메인 메뉴로 돌아가기
                elif event.key in [pygame.K_LEFT, pygame.K_a]:
                    if not card_transition_active:
                        previous_selected = selected
                        selected = (selected - 1) % len(characters)
                        start_card_transition()
                        SOUND_BUTTON_HOVER.play()
                elif event.key in [pygame.K_RIGHT, pygame.K_d]:
                    if not card_transition_active:
                        previous_selected = selected
                        selected = (selected + 1) % len(characters)
                        start_card_transition()
                        SOUND_BUTTON_HOVER.play()
                elif event.key in [pygame.K_SPACE, pygame.K_RETURN]:
                    if characters[selected]["unlocked"]:
                        SOUND_BUTTON_CLICK.play()
                        return characters[selected]["id"]
                    else:
                        # 해금 안된 캐릭터 선택 시 효과음 (선택 불가 사운드)
                        pass
        # 사이버펑크 배경 그리기 (그라데이션)
        for y in range(HEIGHT):
            ratio = y / HEIGHT
            r = int(10 + ratio * 30)  # 더 밝은 빨강
            g = int(20 + ratio * 40)  # 더 밝은 초록
            b = int(40 + ratio * 60)  # 더 밝은 파랑
            color = (r, g, b)
            draw.line(color, (0, y), (WIDTH, y))
        # 홀로그램 격자 패턴
        grid_color = (0, 150, 200, 25)
        grid_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        for x in range(0, WIDTH, 30):
            pygame.draw.line(grid_surface, grid_color, (x, 0), (x, HEIGHT))
        for y in range(0, HEIGHT, 30):
            pygame.draw.line(grid_surface, grid_color, (0, y), (WIDTH, y))
        SCREEN.blit(grid_surface, (0, 0))
        # 디지털 매트릭스 효과 (최소화)
        try:
            font_matrix = pygame.font.Font(None, 10)
        except:
            font_matrix = pygame.font.Font(None, 10)
        # 정적 매트릭스 배경 (매우 절제)
        for i in range(3):  # 열 수 대폭 감소
            x = 100 + i * 200  # 넓은 간격
            y = 150 + (i % 2) * 100  # 엇갈린 배치
            if random.random() < 0.1:  # 10% 확률로만 표시
                char = random.choice(["0", "1"])
                char_surface = font_matrix.render(char, True, (0, 60, 80))
                char_surface.set_alpha(20)  # 매우 희미하게
                SCREEN.blit(char_surface, (x, y))
        # 폰트 로드
        try:
            font_title = pygame.font.Font("NanumSquareB.ttf", 56)  # 더 큰 제목
            font_subtitle = pygame.font.Font("NanumSquareR.ttf", 28)
            font_desc = pygame.font.Font("NanumSquareR.ttf", 20)
            font_card = pygame.font.Font("NanumSquareB.ttf", 18)
            font_small = pygame.font.Font("NanumSquareR.ttf", 16)
        except:
            font_title = pygame.font.Font(None, 56)
            font_subtitle = pygame.font.Font(None, 28)
            font_desc = pygame.font.Font(None, 20)
            font_card = pygame.font.Font(None, 18)
            font_small = pygame.font.Font(None, 16)
        # 제목
        # 홀로그램 스타일 제목
        title_main = "◆ NEURAL SELECT PROTOCOL ◆"
        title_sub = ">> PILOT ACQUISITION SYSTEM <<"
        # 메인 제목 - 네온 글로우 효과
        title_y = 35
        # 글리치 효과 적용
        glitch_offset_x = 0
        glitch_offset_y = 0
        if glitch_active:
            glitch_offset_x = random.randint(-3, 3)
            glitch_offset_y = random.randint(-1, 1)
        # 네온 글로우 레이어들
        for i, (offset, color, alpha) in enumerate([(4, (0, 255, 255), 60), (2, (255, 0, 128), 120), (0, (255, 255, 255), 255)]):
            glow_text = font_title.render(title_main, True, (*color[:3], alpha))
            glow_rect = glow_text.get_rect(center=(WIDTH // 2 + offset + glitch_offset_x, title_y + glitch_offset_y))
            if alpha < 255:  # 글로우 레이어
                glow_surface = pygame.Surface(glow_text.get_size(), pygame.SRCALPHA)
                glow_surface.blit(glow_text, (0, 0))
                SCREEN.blit(glow_surface, glow_rect)
            else:  # 메인 텍스트
                SCREEN.blit(glow_text, glow_rect)
        # 서브 제목
        sub_text = font_subtitle.render(title_sub, True, (0, 255, 255))
        sub_rect = sub_text.get_rect(center=(WIDTH // 2, title_y + 45))
        SCREEN.blit(sub_text, sub_rect)
        # 타이핑 효과를 위한 커서 깜박이는 언더스코어
        if animation_timer % 60 < 30:  # 0.5초마다 깜박임
            cursor_surface = pygame.Surface((200, 3), pygame.SRCALPHA)
            pygame.draw.rect(cursor_surface, (0, 255, 255, 150), (0, 0, 200, 3))
            SCREEN.blit(cursor_surface, (WIDTH // 2 - 100, title_y + 55))
        # 애니메이션 관련 함수들
        def start_card_transition():
            nonlocal card_transition_active, card_transition_progress
            nonlocal card_start_pos, card_target_pos
            card_transition_active = True
            card_transition_progress = 0.0
            # 이전 카드의 중앙 위치 (시작점)
            card_start_pos = (WIDTH // 2 - card_width // 2, HEIGHT // 2 - card_height // 2)
            # 새 카드의 하단 부채꼴 위치 계산 (목표점)
            if len(characters) > 1:
                remaining_cards = len(characters) - 1
                if remaining_cards > 1:
                    angle_step = 90 / (remaining_cards - 1)  # fan_angle_range = 90
                    card_index = selected if selected < previous_selected else selected - 1
                    angle = -45 + card_index * angle_step  # -fan_angle_range/2
                else:
                    angle = 0
            else:
                angle = 0
            angle_rad = math.radians(angle)
            target_x = center_x + math.sin(angle_rad) * 180 - card_width // 2  # fan_radius = 180
            target_y = center_y - math.cos(angle_rad) * 180 * 0.2 - card_height // 2
            card_target_pos = (target_x, target_y)
        def update_card_transition():
            nonlocal card_transition_active, card_transition_progress
            if card_transition_active:
                card_transition_progress += 1.0 / card_transition_duration
                if card_transition_progress >= 1.0:
                    card_transition_progress = 1.0
                    card_transition_active = False
        def get_transition_position(start_pos, target_pos, progress):
            # 이지-아웃 애니메이션 (부드러운 감속)
            eased_progress = 1 - (1 - progress) ** 3
            x = start_pos[0] + (target_pos[0] - start_pos[0]) * eased_progress
            y = start_pos[1] + (target_pos[1] - start_pos[1]) * eased_progress
            # 약간의 아치 효과 (카드가 위로 올라갔다 내려오는 느낌)
            arc_height = -30 * math.sin(progress * math.pi)
            y += arc_height
            return (x, y)
        # 애니메이션 업데이트
        update_card_transition()
        transition_progress = min(transition_progress + 0.1, 1.0)
        # 포커 카드 렌더링 (애니메이션 적용)
        def draw_card_fan():
            # 애니메이션 중인 카드들 추적
            animated_cards = []
            # 1. 선택되지 않은 카드들을 하단 부채꼴로 그리기
            fan_angle_range = 90
            fan_radius = 180
            for i, character in enumerate(characters):
                is_selected = (i == selected)
                is_previous = (i == previous_selected)
                # 현재 애니메이션 중인지 확인
                if card_transition_active and (is_selected or is_previous):
                    animated_cards.append(i)
                    continue
                if not is_selected:
                    # 선택되지 않은 카드들 - 하단 부채꼴 배치
                    if len(characters) > 1:
                        remaining_cards = len(characters) - 1
                        if remaining_cards > 1:
                            angle_step = fan_angle_range / (remaining_cards - 1)
                            card_index = i if i < selected else i - 1
                            angle = -fan_angle_range/2 + card_index * angle_step
                        else:
                            angle = 0
                    else:
                        angle = 0
                    angle_rad = math.radians(angle)
                    card_x = center_x + math.sin(angle_rad) * fan_radius - card_width // 2
                    card_y = center_y - math.cos(angle_rad) * fan_radius * 0.2 - card_height // 2
                    # 뒷면으로 그리기
                    draw_character_card(character, card_x, card_y, angle, False, i, 
                                      card_width, card_height)
            # 2. 애니메이션 중이 아닌 선택된 카드를 중앙에 그리기
            if not card_transition_active:
                selected_char = characters[selected]
                selected_x = (WIDTH - card_width) // 2
                selected_y = HEIGHT // 2 - card_height // 2
                # 앞면으로 그리기
                draw_character_card(selected_char, selected_x, selected_y, 0, True, selected,
                                  card_width, card_height)
            # 3. 애니메이션 중인 카드들 그리기
            if card_transition_active:
                # 이전 카드 (중앙에서 하단으로 이동)
                if previous_selected < len(characters):
                    prev_char = characters[previous_selected]
                    transition_pos = get_transition_position(card_start_pos, card_target_pos, 
                                                           card_transition_progress)
                    # 뒷면으로 그리기 (애니메이션 진행에 따라)
                    draw_character_card(prev_char, transition_pos[0], transition_pos[1], 0, 
                                      False, previous_selected, card_width, card_height)
                # 새 선택된 카드 (하단에서 중앙으로 이동)
                selected_char = characters[selected]
                # 새 카드의 시작 위치 (하단 부채꼴)
                if len(characters) > 1:
                    remaining_cards = len(characters) - 1
                    if remaining_cards > 1:
                        angle_step = 90 / (remaining_cards - 1)
                        card_index = selected if selected < previous_selected else selected - 1
                        angle = -45 + card_index * angle_step
                    else:
                        angle = 0
                else:
                    angle = 0
                angle_rad = math.radians(angle)
                start_x = center_x + math.sin(angle_rad) * 180 - card_width // 2
                start_y = center_y - math.cos(angle_rad) * 180 * 0.2 - card_height // 2
                # 목표 위치 (중앙)
                target_x = WIDTH // 2 - card_width // 2
                target_y = HEIGHT // 2 - card_height // 2
                new_card_pos = get_transition_position((start_x, start_y), (target_x, target_y),
                                                     card_transition_progress)
                # 앞면으로 그리기
                draw_character_card(selected_char, new_card_pos[0], new_card_pos[1], 0, 
                                  True, selected, card_width, card_height)
        def draw_character_card(character, x, y, angle, is_selected, card_index, 
                               current_card_width=None, current_card_height=None):
            # 카드 크기 설정
            if current_card_width is None:
                current_card_width = card_width
            if current_card_height is None:
                current_card_height = card_height
            # 카드 표면 생성
            card_surface = pygame.Surface((current_card_width, current_card_height), pygame.SRCALPHA)
            # 카드 앞면/뒷면 로직 수정: 선택된 카드만 앞면, 나머지는 모두 뒷면
            if character["unlocked"] and is_selected:
                # 해금된 카드 중 선택된 것만 앞면
                draw_card_front(card_surface, character, is_selected, 
                              current_card_width, current_card_height)
            else:
                # 해금 안된 카드 또는 선택되지 않은 카드는 뒷면
                draw_card_back(card_surface, card_index, is_selected, 
                             current_card_width, current_card_height)
            # 카드 회전 및 배치
            if angle != 0:
                rotated_card = pygame.transform.rotate(card_surface, -angle)
                rotated_rect = rotated_card.get_rect(center=(x + current_card_width//2, y + current_card_height//2))
                SCREEN.blit(rotated_card, rotated_rect)
            else:
                SCREEN.blit(card_surface, (x, y))
        def draw_card_front(surface, character, is_selected, w, h):
            """홀로그램 스타일 카드 앞면 그리기"""
            border_color = character["card_color"] if is_selected else (150, 150, 150)
            glow_color = character.get("glow_color", border_color)
            # 홀로그램 글로우 효과 (다층 글로우)
            if is_selected:
                for glow_layer in range(5, 0, -1):
                    glow_intensity = int(abs(math.sin(animation_timer * 0.12 + glow_layer)) * 30) + 40
                    glow_size = glow_layer * 4
                    glow_surface = pygame.Surface((w + glow_size, h + glow_size), pygame.SRCALPHA)
                    pygame.draw.rect(glow_surface, (*glow_color, glow_intensity // glow_layer), 
                                   (0, 0, w + glow_size, h + glow_size), border_radius=20)
                    surface.blit(glow_surface, (-glow_size//2, -glow_size//2))
            # 홀로그램 카드 본체 (반투명 대신 어두운 배경)
            card_bg_color = (10, 15, 25, 220)  # 매우 어두운 반투명
            card_surface = pygame.Surface((w, h), pygame.SRCALPHA)
            pygame.draw.rect(card_surface, card_bg_color, (0, 0, w, h), border_radius=15)
            surface.blit(card_surface, (0, 0))
            # 네온 테두리
            pygame.draw.rect(surface, border_color, (0, 0, w, h), 2, border_radius=15)
            # 내부 테두리 (네온 전자 회로 느낌)
            inner_border = 4
            pygame.draw.rect(surface, (*border_color, 100), 
                           (inner_border, inner_border, w - inner_border*2, h - inner_border*2), 
                           1, border_radius=12)
            # 카드 모서리 장식 (트럼프 카드 스타일)
            suit_color = border_color
            suit_size = max(16, min(24, w // 6))  # 카드 크기에 비례한 폰트 크기
            suit_font = pygame.font.Font(None, suit_size)
            suit_text = suit_font.render(character["card_suit"], True, suit_color)
            # 좌상단
            surface.blit(suit_text, (8, 8))
            # 우하단 (회전)
            rotated_suit = pygame.transform.rotate(suit_text, 180)
            surface.blit(rotated_suit, (w - suit_text.get_width() - 8, h - suit_text.get_height() - 8))
            # 캐릭터 이미지 영역
            image_size = min(w - 20, h // 3)  # 카드 크기에 비례
            try:
                char_image = pygame.image.load(character["image"])
                char_image = pygame.transform.scale(char_image, (image_size, image_size))
                image_x = (w - image_size) // 2
                image_y = 30
                surface.blit(char_image, (image_x, image_y))
            except:
                # 이미지 로드 실패 시 대체 그래픽
                radius = image_size // 2
                pygame.draw.circle(surface, border_color, (w//2, 30 + radius), radius)
                pygame.draw.circle(surface, (255, 255, 255), (w//2, 30 + radius), radius - 5, 3)
            # 캐릭터 이름 (카드가 클 때만)
            if is_selected and w > 120:
                name_text = font_card.render(character["name"], True, (30, 30, 30))
                name_rect = name_text.get_rect(center=(w//2, 30 + image_size + 20))
                surface.blit(name_text, name_rect)
                # 간단한 스탯 표시 (선택된 카드일 때만)
                stats_y = 30 + image_size + 45
                for stat_name, stat_value in character["stats"].items():
                    stat_text = font_small.render(f"{stat_name}: {'★' * stat_value}", True, (60, 60, 60))
                    stat_rect = stat_text.get_rect(center=(w//2, stats_y))
                    surface.blit(stat_text, stat_rect)
                    stats_y += 15
        def draw_card_back(surface, card_index, is_selected, w, h):
            pattern = card_back_patterns[card_index % len(card_back_patterns)]
            base_color = pattern["color"]
            accent_color = pattern["accent"]
            # 선택 여부에 따른 색상 조정
            if is_selected:
                # 선택된 카드는 더 밝게
                base_color = tuple(min(255, c + 30) for c in base_color)
                accent_color = tuple(min(255, c + 50) for c in accent_color)
                # 글로우 효과
                glow_intensity = int(abs(math.sin(animation_timer * 0.15)) * 30) + 40
                glow_surface = pygame.Surface((w + 10, h + 10), pygame.SRCALPHA)
                pygame.draw.rect(glow_surface, (*accent_color, glow_intensity), 
                               (0, 0, w + 10, h + 10), border_radius=15)
                surface.blit(glow_surface, (-5, -5))
            else:
                # 선택되지 않은 카드는 더 어둡게
                base_color = tuple(max(20, c - 20) for c in base_color)
                accent_color = tuple(max(50, c - 30) for c in accent_color)
            # 카드 배경
            pygame.draw.rect(surface, base_color, (0, 0, w, h), border_radius=10)
            pygame.draw.rect(surface, accent_color, (0, 0, w, h), 3, border_radius=10)
            # 패턴 그리기
            draw_card_pattern(surface, pattern, w, h)
            # 물음표 또는 잠금 아이콘 (해금 여부에 따라)
            # characters 리스트에서 실제 해금 상태 확인
            character = characters[card_index] if card_index < len(characters) else None
            icon_size = max(16, min(32, w // 5))  # 카드 크기에 비례한 아이콘 크기
            icon_font = pygame.font.Font(None, icon_size)
            if character and not character["unlocked"]:
                # 해금 안된 카드는 잠금 아이콘
                lock_icon = icon_font.render("🔒", True, accent_color)
                lock_rect = lock_icon.get_rect(center=(w//2, h//2))
                surface.blit(lock_icon, lock_rect)
            else:
                # 해금된 카드는 물음표 (선택되지 않아서 뒷면)
                question_icon = icon_font.render("?", True, accent_color)
                question_rect = question_icon.get_rect(center=(w//2, h//2))
                surface.blit(question_icon, question_rect)
        def draw_card_pattern(surface, pattern, width, height):
            """사이버펑크 스타일 카드 패턴 그리기"""
            pattern_type = pattern["pattern"]
            color = pattern["accent"]
            # 카드 크기에 맞춘 패턴 간격 계산
            margin = 8
            pattern_width = width - 2 * margin
            pattern_height = height - 2 * margin
            # 사이버펑크 패턴별 그리기
            if pattern_type == "circuit":
                # 전자 회로 패턴
                # 가로선
                for y in range(margin, margin + pattern_height, 20):
                    alpha = int(abs(math.sin(animation_timer * 0.1 + y * 0.05)) * 100) + 50
                    line_color = (*color, alpha)
                    line_surface = pygame.Surface((pattern_width, 2), pygame.SRCALPHA)
                    pygame.draw.rect(line_surface, line_color, (0, 0, pattern_width, 2))
                    surface.blit(line_surface, (margin, y))
                # 세로선
                for x in range(margin, margin + pattern_width, 25):
                    alpha = int(abs(math.sin(animation_timer * 0.08 + x * 0.03)) * 80) + 40
                    line_color = (*color, alpha)
                    line_surface = pygame.Surface((2, pattern_height), pygame.SRCALPHA)
                    pygame.draw.rect(line_surface, line_color, (0, 0, 2, pattern_height))
                    surface.blit(line_surface, (x, margin))
                # 접점 노드
                for x in range(margin, margin + pattern_width, 25):
                    for y in range(margin, margin + pattern_height, 20):
                        node_alpha = int(abs(math.sin(animation_timer * 0.15 + x * 0.01 + y * 0.01)) * 150) + 80
                        pygame.draw.circle(surface, (*color, node_alpha), (x, y), 2)
            elif pattern_type == "matrix":
                # 매트릭스 코드 패턴
                chars = "01"
                font_size = 12
                try:
                    matrix_font = pygame.font.Font(None, font_size)
                except:
                    matrix_font = pygame.font.Font(None, font_size)
                for x in range(margin, margin + pattern_width, 15):
                    for y in range(margin, margin + pattern_height, 16):
                        if random.randint(0, 3) == 0:  # 25% 확률로 문자 표시
                            char = random.choice(chars)
                            alpha = int(abs(math.sin(animation_timer * 0.2 + x * 0.1 + y * 0.1)) * 120) + 60
                            char_surface = matrix_font.render(char, True, (*color, alpha))
                            surface.blit(char_surface, (x, y))
            elif pattern_type == "grid":
                # 네온 그리드 패턴
                grid_size = 15
                for x in range(margin, margin + pattern_width, grid_size):
                    for y in range(margin, margin + pattern_height, grid_size):
                        alpha = int(abs(math.sin(animation_timer * 0.1 + x * 0.02 + y * 0.02)) * 60) + 30
                        pygame.draw.rect(surface, (*color, alpha), (x, y, grid_size-1, grid_size-1), 1)
            elif pattern_type == "wave":
                # 사인 웨이브 패턴
                for y in range(margin, margin + pattern_height, 10):
                    points = []
                    for x in range(margin, margin + pattern_width, 5):
                        wave_y = y + math.sin((x + animation_timer) * 0.1) * 5
                        points.append((x, wave_y))
                    if len(points) > 1:
                        alpha = int(abs(math.sin(animation_timer * 0.05 + y * 0.05)) * 80) + 40
                        for i in range(len(points) - 1):
                            pygame.draw.line(surface, (*color, alpha), points[i], points[i+1])
            elif pattern_type == "hex":
                # 육각형 허니컴 패턴
                hex_size = 12
                for x in range(margin, margin + pattern_width, hex_size * 2):
                    for y in range(margin, margin + pattern_height, hex_size * 2):
                        alpha = int(abs(math.sin(animation_timer * 0.12 + x * 0.05 + y * 0.05)) * 100) + 50
                        draw_hexagon(surface, x + hex_size, y + hex_size, hex_size//2, (*color, alpha))
            elif pattern_type == "scan":
                # 스캔라인 패턴
                for i in range(5):
                    scan_y = margin + (animation_timer * 2 + i * 30) % pattern_height
                    alpha = 150 - i * 20
                    if alpha > 0:
                        scan_surface = pygame.Surface((pattern_width, 3), pygame.SRCALPHA)
                        pygame.draw.rect(scan_surface, (*color, alpha), (0, 0, pattern_width, 3))
                        surface.blit(scan_surface, (margin, scan_y))
            # 기존 패턴 처리 (하위 호환성)
            elif pattern_type == "diamond":
                cols = max(3, int(pattern_width // 20))
                rows = max(4, int(pattern_height // 25))
                spacing_x = pattern_width / cols
                spacing_y = pattern_height / rows
                for i in range(cols):
                    for j in range(rows):
                        x = margin + i * spacing_x + spacing_x/2
                        y = margin + j * spacing_y + spacing_y/2
                        size = min(spacing_x, spacing_y) * 0.3
                        points = [(x, y-size), (x+size, y), (x, y+size), (x-size, y)]
                        pygame.draw.polygon(surface, color, points)
            elif pattern_type == "circle":
                cols = max(4, int(pattern_width // 15))
                rows = max(5, int(pattern_height // 20))
                spacing_x = pattern_width / cols
                spacing_y = pattern_height / rows
                for i in range(cols):
                    for j in range(rows):
                        x = margin + i * spacing_x + spacing_x/2
                        y = margin + j * spacing_y + spacing_y/2
                        radius = min(spacing_x, spacing_y) * 0.25
                        pygame.draw.circle(surface, color, (int(x), int(y)), int(radius))
            elif pattern_type == "star":
                cols = max(3, int(pattern_width // 25))
                rows = max(4, int(pattern_height // 30))
                spacing_x = pattern_width / cols
                spacing_y = pattern_height / rows
                for i in range(cols):
                    for j in range(rows):
                        x = margin + i * spacing_x + spacing_x/2
                        y = margin + j * spacing_y + spacing_y/2
                        size = min(spacing_x, spacing_y) * 0.3
                        draw_star(surface, int(x), int(y), int(size), color)
            elif pattern_type == "triangle":
                cols = max(4, int(pattern_width // 18))
                rows = max(5, int(pattern_height // 22))
                spacing_x = pattern_width / cols
                spacing_y = pattern_height / rows
                for i in range(cols):
                    for j in range(rows):
                        x = margin + i * spacing_x + spacing_x/2
                        y = margin + j * spacing_y + spacing_y/2
                        size = min(spacing_x, spacing_y) * 0.3
                        points = [(x, y-size), (x-size, y+size), (x+size, y+size)]
                        pygame.draw.polygon(surface, color, points)
            elif pattern_type == "hexagon":
                cols = max(3, int(pattern_width // 22))
                rows = max(4, int(pattern_height // 25))
                spacing_x = pattern_width / cols
                spacing_y = pattern_height / rows
                for i in range(cols):
                    for j in range(rows):
                        x = margin + i * spacing_x + spacing_x/2
                        y = margin + j * spacing_y + spacing_y/2
                        size = min(spacing_x, spacing_y) * 0.3
                        draw_hexagon(surface, int(x), int(y), int(size), color)
            elif pattern_type == "cross":
                cols = max(4, int(pattern_width // 20))
                rows = max(5, int(pattern_height // 23))
                spacing_x = pattern_width / cols
                spacing_y = pattern_height / rows
                for i in range(cols):
                    for j in range(rows):
                        x = margin + i * spacing_x + spacing_x/2
                        y = margin + j * spacing_y + spacing_y/2
                        size = min(spacing_x, spacing_y) * 0.25
                        pygame.draw.rect(surface, color, (int(x-size), int(y-size/3), int(size*2), int(size*2/3)))
                        pygame.draw.rect(surface, color, (int(x-size/3), int(y-size), int(size*2/3), int(size*2)))
        def draw_star(surface, x, y, size, color):
            points = []
            for i in range(5):
                angle = i * 2 * math.pi / 5 - math.pi/2
                outer_x = x + math.cos(angle) * size
                outer_y = y + math.sin(angle) * size
                points.append((outer_x, outer_y))
                angle = (i + 0.5) * 2 * math.pi / 5 - math.pi/2
                inner_x = x + math.cos(angle) * size * 0.4
                inner_y = y + math.sin(angle) * size * 0.4
                points.append((inner_x, inner_y))
            pygame.draw.polygon(surface, color, points)
        def draw_hexagon(surface, x, y, size, color):
            points = []
            for i in range(6):
                angle = i * math.pi / 3
                point_x = x + math.cos(angle) * size
                point_y = y + math.sin(angle) * size
                points.append((point_x, point_y))
            pygame.draw.polygon(surface, color, points)
        # 네온 파티클 업데이트 및 그리기
        for particle in neon_particles:
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            # 화면 경계 처리
            if particle["x"] < 0 or particle["x"] > WIDTH:
                particle["vx"] *= -1
            if particle["y"] < 0 or particle["y"] > HEIGHT:
                particle["vy"] *= -1
            # 펄스 효과
            pulse = abs(math.sin(animation_timer * particle["pulse_speed"]))
            current_alpha = int(particle["alpha"] * (0.5 + pulse * 0.5))
            # 네온 글로우 파티클
            for i in range(2):
                glow_size = particle["size"] + i * 2
                glow_alpha = current_alpha // (i + 1)
                glow_surf = pygame.Surface((glow_size * 4, glow_size * 4), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*particle["color"], glow_alpha),
                                 (glow_size * 2, glow_size * 2), glow_size)
                SCREEN.blit(glow_surf, (particle["x"] - glow_size * 2, 
                                       particle["y"] - glow_size * 2))
        # 스캔라인 효과
        for scan_line in scan_lines:
            scan_line["y"] += scan_line["speed"]
            if scan_line["y"] > HEIGHT:
                scan_line["y"] = -10
            # 더 화려한 스캔라인
            for i in range(3):
                scan_alpha = scan_line["alpha"] - i * 10
                if scan_alpha > 0:
                    scan_surf = pygame.Surface((WIDTH, 2 - i), pygame.SRCALPHA)
                    scan_surf.fill((0, 255, 255, scan_alpha))
                    SCREEN.blit(scan_surf, (0, scan_line["y"] + i))
        # 카드 부채꼴 그리기
        draw_card_fan()
        # 홀로그램 상세 정보 패널 (상단)
        current_char = characters[selected]
        detail_card_width = 480  # 더 넓게
        detail_card_height = 160  # 더 높게
        detail_x = (WIDTH - detail_card_width) // 2
        detail_y = 90  # 제목 아래로 이동
        # 홀로그램 상세 정보 패널 배경
        border_color = current_char["card_color"] if current_char["unlocked"] else (100, 100, 100)
        glow_color = current_char.get("glow_color", border_color) if current_char["unlocked"] else (80, 80, 80)
        # 다층 글로우 효과
        for glow_layer in range(3, 0, -1):
            glow_intensity = int(abs(math.sin(animation_timer * 0.1 + glow_layer)) * 40) + 30
            glow_size = glow_layer * 6
            glow_surface = pygame.Surface((detail_card_width + glow_size, detail_card_height + glow_size), pygame.SRCALPHA)
            pygame.draw.rect(glow_surface, (*glow_color, glow_intensity // glow_layer), 
                           (0, 0, detail_card_width + glow_size, detail_card_height + glow_size), border_radius=20)
            SCREEN.blit(glow_surface, (detail_x - glow_size//2, detail_y - glow_size//2))
        # 메인 패널 배경
        detail_surface = pygame.Surface((detail_card_width, detail_card_height), pygame.SRCALPHA)
        detail_surface.fill((5, 10, 20, 240))  # 매우 어두운 반투명
        # 네온 테두리
        pygame.draw.rect(detail_surface, border_color, (0, 0, detail_card_width, detail_card_height), 2, border_radius=15)
        # 내부 전자 회로 패턴
        for x in range(0, detail_card_width, 40):
            for y in range(0, detail_card_height, 30):
                if random.randint(0, 5) == 0:  # 랜덤 전자 회로 노드
                    node_alpha = int(abs(math.sin(animation_timer * 0.2 + x * 0.1 + y * 0.1)) * 60) + 20
                    pygame.draw.circle(detail_surface, (*glow_color, node_alpha), (x, y), 1)
        SCREEN.blit(detail_surface, (detail_x, detail_y))
        if current_char["unlocked"]:
            # 해금된 캐릭터 - 홀로그램 스타일 정보 표시
            # 캐릭터 이름 (네온 글로우 효과)
            name_y = detail_y + 25
            for glow_offset in [(2, 2), (1, 1), (0, 0)]:
                alpha = 100 if glow_offset != (0, 0) else 255
                name_color = (*glow_color, alpha) if glow_offset != (0, 0) else (255, 255, 255)
                name_text = font_subtitle.render(current_char["name"], True, name_color)
                name_rect = name_text.get_rect(center=(detail_x + detail_card_width//2 + glow_offset[0], name_y + glow_offset[1]))
                SCREEN.blit(name_text, name_rect)
            # 캐릭터 설명 (홀로그램 스타일)
            desc_y = detail_y + 55
            desc_text = font_desc.render(current_char["description"], True, (180, 220, 255))
            desc_rect = desc_text.get_rect(center=(detail_x + detail_card_width//2, desc_y))
            SCREEN.blit(desc_text, desc_rect)
            # 특수 능력 (네온 강조)
            special_y = detail_y + 80
            for glow_offset in [(1, 1), (0, 0)]:
                alpha = 120 if glow_offset != (0, 0) else 255
                special_color = (*glow_color, alpha) if glow_offset != (0, 0) else glow_color
                special_text = font_desc.render(current_char["special"], True, special_color)
                special_rect = special_text.get_rect(center=(detail_x + detail_card_width//2 + glow_offset[0], special_y + glow_offset[1]))
                SCREEN.blit(special_text, special_rect)
            # 홀로그램 스탯 표시
            stats_start_y = detail_y + 110
            stats_start_x = detail_x + 60
            stat_width = 120  # 더 넓은 간격
            for i, (stat_name, stat_value) in enumerate(current_char["stats"].items()):
                stat_x = stats_start_x + (i * stat_width)
                # 스탯명
                stat_name_text = font_small.render(stat_name, True, glow_color)
                stat_name_rect = stat_name_text.get_rect(center=(stat_x, stats_start_y))
                SCREEN.blit(stat_name_text, stat_name_rect)
                # 홀로그램 스탯 바
                bar_width = 80
                bar_height = 6
                bar_x = stat_x - bar_width // 2
                bar_y = stats_start_y + 18
                # 홀로그램 배경 바
                draw.rect((10, 20, 30), (bar_x, bar_y, bar_width, bar_height), border_radius=3)
                draw.rect((*glow_color, 80), (bar_x, bar_y, bar_width, bar_height), 1, border_radius=3)
                # 네온 값 바 (글로우 효과)
                filled_width = int((stat_value / 8) * bar_width)
                if filled_width > 0:
                    # 메인 바
                    draw.rect(glow_color, (bar_x, bar_y, filled_width, bar_height), border_radius=3)
                    # 글로우 효과
                    for glow_layer in range(2, 0, -1):
                        glow_intensity = int(abs(math.sin(animation_timer * 0.15 + i)) * 30) + 50
                        glow_surface = pygame.Surface((filled_width + glow_layer*2, bar_height + glow_layer*2), pygame.SRCALPHA)
                        pygame.draw.rect(glow_surface, (*glow_color, glow_intensity // glow_layer), 
                                       (0, 0, filled_width + glow_layer*2, bar_height + glow_layer*2), border_radius=3)
                        SCREEN.blit(glow_surface, (bar_x - glow_layer, bar_y - glow_layer))
                # 홀로그램 숫자 표시
                value_text = font_small.render(str(stat_value), True, glow_color)
                value_rect = value_text.get_rect(center=(stat_x, stats_start_y + 38))
                SCREEN.blit(value_text, value_rect)
        else:
            # 해금되지 않은 캐릭터 - ???? 표시
            # 캐릭터 이름
            name_text = font_subtitle.render("????", True, (150, 150, 150))
            name_rect = name_text.get_rect(center=(detail_x + detail_card_width//2, detail_y + 25))
            SCREEN.blit(name_text, name_rect)
            # 캐릭터 설명
            desc_text = font_desc.render("????????????", True, (120, 120, 120))
            desc_rect = desc_text.get_rect(center=(detail_x + detail_card_width//2, detail_y + 50))
            SCREEN.blit(desc_text, desc_rect)
            # 특수 능력
            special_text = font_desc.render("?? ???????", True, (100, 120, 100))
            special_rect = special_text.get_rect(center=(detail_x + detail_card_width//2, detail_y + 75))
            SCREEN.blit(special_text, special_rect)
            # 상세 스탯 - ??? 표시
            stats_start_y = detail_y + 100
            stats_start_x = detail_x + 50
            stat_width = 80
            for i in range(3):  # 3개의 스탯
                stat_x = stats_start_x + (i * stat_width)
                # 스탯명
                stat_name_text = font_small.render("???", True, (150, 150, 150))
                stat_name_rect = stat_name_text.get_rect(center=(stat_x, stats_start_y))
                SCREEN.blit(stat_name_text, stat_name_rect)
                # 스탯 바 (빈 상태)
                bar_width = 60
                bar_height = 8
                bar_x = stat_x - bar_width // 2
                bar_y = stats_start_y + 15
                # 배경 바만 표시
                draw.rect((60, 60, 60), (bar_x, bar_y, bar_width, bar_height), border_radius=4)
                # 물음표 표시
                value_text = font_small.render("?", True, (150, 150, 150))
                value_rect = value_text.get_rect(center=(stat_x, stats_start_y + 35))
                SCREEN.blit(value_text, value_rect)
        # 홀로그램 캐릭터 선택 인디케이터 - 제거됨
        # indicator_y = HEIGHT - 30
        # total_width = len(characters) * 35  # 더 넓은 간격
        # start_x = (WIDTH - total_width) // 2
        # for i in range(len(characters)):
        #     indicator_x = start_x + i * 35 + 17
        #     char_glow = characters[i].get("glow_color", characters[i]["card_color"])
        #     if i == selected:
        #         # 선택된 인디케이터 (네온 글로우)
        #         color = char_glow if characters[i]["unlocked"] else (120, 120, 120)
        #         # 다층 글로우 효과
        #         for glow_size in [12, 10, 8]:
        #             glow_intensity = int(abs(math.sin(animation_timer * 0.2 + i)) * 50) + 80
        #             if glow_size == 8:
        #                 glow_intensity = 255  # 중심은 완전 불투명
        #             indicator_surface = pygame.Surface((glow_size*2, glow_size*2), pygame.SRCALPHA)
        #             pygame.draw.circle(indicator_surface, (*color, glow_intensity), (glow_size, glow_size), glow_size)
        #             SCREEN.blit(indicator_surface, (indicator_x - glow_size, indicator_y - glow_size))
        #         # 내부 네온 링
        #         draw.circle((255, 255, 255), (indicator_x, indicator_y), 6, 2)
        #     else:
        #         # 비선택 인디케이터
        #         if characters[i]["unlocked"]:
        #             # 해금된 캐릭터 - 어두운 네온
        #             color = tuple(c // 3 for c in char_glow)  # 더 어둑게
        #             draw.circle(color, (indicator_x, indicator_y), 6)
        #             draw.circle((*color, 150), (indicator_x, indicator_y), 8, 1)
        #         else:
        #             # 잠긴 캐릭터 - 매우 어두운 링
        #             draw.circle((50, 50, 50), (indicator_x, indicator_y), 4, 2)
        pygame.display.flip()
        clock.tick(60)
def show_difficulty_selection():
    """난이도 선택 화면 - 사이버펑크 스타일"""
    clock = pygame.time.Clock()
    # 4단계 리그 시스템 (홀로그램 테마)
    difficulties = [
        {
            "id": "junior",
            "name": "주니어리그",
            "description": "게임의 기본을 익히는 초보자 리그\n편안한 속도로 기술을 연습할 수 있습니다",
            "ai_mode": "junior",
            "color": (100, 255, 100),
            "icon": "🌱",
            "details": [
                "• 느린 공 속도",
                "• AI 실수 빈번 (25%)",
                "• 넉넉한 반응시간",
                "• 기본기 연습에 최적",
                "⚡ 보스 능력치: 기본 (100%)",
                "🎯 목표 승률: 80%"
            ]
        },
        {
            "id": "pro",
            "name": "프로리그", 
            "description": "본격적인 경쟁이 시작되는 중급자 리그\n전략과 반응속도가 중요해집니다",
            "ai_mode": "pro",
            "color": (255, 200, 100),
            "icon": "⚡",
            "details": [
                "• 표준 공 속도",
                "• AI 적당한 실수 (15%)",
                "• 예측 가능한 패턴",
                "• 실력 향상에 좋음",
                "⚡ 보스 능력치: +5% (105%)",
                "🎯 목표 승률: 60%"
            ]
        },
        {
            "id": "champion",
            "name": "챔피언리그",
            "description": "실력자들만이 도전하는 상급자 리그\n빠른 판단력과 정확한 컨트롤이 필수입니다",
            "ai_mode": "champion",
            "color": (255, 150, 255),
            "icon": "💎",
            "details": [
                "• 빠른 공 속도", 
                "• AI 소수 실수 (8%)",
                "• 고도의 전략 필요",
                "• 챔피언급 도전",
                "⚡ 보스 능력치: +10% (110%)",
                "🎯 목표 승률: 35%"
            ]
        },
        {
            "id": "mythic",
            "name": "신화리그",
            "description": "오직 최강자만이 생존하는 전설의 리그\n인간의 한계를 시험하는 극한의 난이도입니다",
            "ai_mode": "mythic",
            "color": (255, 215, 0),
            "icon": "👑",
            "details": [
                "• 완벽한 예측 능력",
                "• AI 거의 무실수 (2%)",
                "• 미래 시뮬레이션 AI",
                "• 신화급 난이도",
                "⚡ 보스 능력치: +20% (120%)",
                "🎯 목표 승률: 10%",
                "⚠️ 극강 주의!"
            ]
        }
    ]
    selected = 0
    animation_timer = 0
    glitch_timer = 0
    glitch_active = False
    # 사이버펑크 배경 효과용 변수들
    neon_particles = []
    for _ in range(50):  # 더 많은 네온 파티클
        neon_particles.append({
            "x": random.randint(0, WIDTH),
            "y": random.randint(0, HEIGHT),
            "vx": random.uniform(-1, 1),
            "vy": random.uniform(-1, 1),
            "size": random.randint(1, 3),
            "color": random.choice([(0, 255, 255), (255, 0, 255), (255, 255, 0)]),
            "alpha": random.randint(40, 100),
            "pulse_speed": random.uniform(0.05, 0.15)
        })
    # 스캔라인 효과
    scan_lines = []
    for i in range(5):  # 더 많은 스캔라인
        scan_lines.append({
            "y": random.randint(0, HEIGHT),
            "speed": random.uniform(2, 4),
            "alpha": random.randint(20, 40)
        })
    while True:
        animation_timer += 1
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return None  # 캐릭터 선택으로 돌아가기
                elif event.key in [pygame.K_UP, pygame.K_w]:
                    # 2x2 그리드에서 위로 이동
                    current_row = selected // cards_per_row
                    current_col = selected % cards_per_row
                    new_row = (current_row - 1) % 2  # 2행에서 순환
                    selected = new_row * cards_per_row + current_col
                    if selected >= len(difficulties):  # 인덱스 범위 초과 시 조정
                        selected = (len(difficulties) - 1)
                    SOUND_BUTTON_HOVER.play()
                elif event.key in [pygame.K_DOWN, pygame.K_s]:
                    # 2x2 그리드에서 아래로 이동
                    current_row = selected // cards_per_row
                    current_col = selected % cards_per_row
                    new_row = (current_row + 1) % 2  # 2행에서 순환
                    selected = new_row * cards_per_row + current_col
                    if selected >= len(difficulties):  # 인덱스 범위 초과 시 조정
                        selected = current_col if current_col < len(difficulties) else 0
                    SOUND_BUTTON_HOVER.play()
                elif event.key in [pygame.K_LEFT, pygame.K_a]:
                    # 2x2 그리드에서 왼쪽으로 이동
                    current_row = selected // cards_per_row
                    current_col = selected % cards_per_row
                    new_col = (current_col - 1) % cards_per_row  # 2열에서 순환
                    selected = current_row * cards_per_row + new_col
                    if selected >= len(difficulties):  # 인덱스 범위 초과 시 조정
                        selected = current_row * cards_per_row + (new_col % len(difficulties))
                    SOUND_BUTTON_HOVER.play()
                elif event.key in [pygame.K_RIGHT, pygame.K_d]:
                    # 2x2 그리드에서 오른쪽으로 이동
                    current_row = selected // cards_per_row
                    current_col = selected % cards_per_row
                    new_col = (current_col + 1) % cards_per_row  # 2열에서 순환
                    selected = current_row * cards_per_row + new_col
                    if selected >= len(difficulties):  # 인덱스 범위 초과 시 조정
                        selected = current_row * cards_per_row + (new_col % len(difficulties))
                    SOUND_BUTTON_HOVER.play()
                elif event.key in [pygame.K_SPACE, pygame.K_RETURN]:
                    SOUND_BUTTON_CLICK.play()
                    return difficulties[selected]["ai_mode"]
        # 사이버펑크 배경 그리기 (그라데이션)
        for y in range(HEIGHT):
            ratio = y / HEIGHT
            r = int(10 + ratio * 30)  # 더 밝은 빨강
            g = int(20 + ratio * 40)  # 더 밝은 초록
            b = int(40 + ratio * 60)  # 더 밝은 파랑
            color = (r, g, b)
            draw.line(color, (0, y), (WIDTH, y))
        # 홀로그램 격자 패턴
        grid_color = (0, 150, 200, 25)
        grid_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        for x in range(0, WIDTH, 30):
            pygame.draw.line(grid_surface, grid_color, (x, 0), (x, HEIGHT))
        for y in range(0, HEIGHT, 30):
            pygame.draw.line(grid_surface, grid_color, (0, y), (WIDTH, y))
        SCREEN.blit(grid_surface, (0, 0))
        # 디지털 매트릭스 효과 (최소화)
        try:
            font_matrix = pygame.font.Font(None, 10)
        except:
            font_matrix = pygame.font.Font(None, 10)
        # 정적 매트릭스 배경 (매우 절제)
        for i in range(3):  # 열 수 대폭 감소
            x = 100 + i * 200  # 넓은 간격
            y = 150 + (i % 2) * 100  # 엇갈린 배치
            if random.random() < 0.1:  # 10% 확률로만 표시
                char = random.choice(["0", "1"])
                char_surface = font_matrix.render(char, True, (0, 60, 80))
                char_surface.set_alpha(20)  # 매우 희미하게
                SCREEN.blit(char_surface, (x, y))
        # 글리치 효과
        glitch_timer += 1
        if random.randint(0, 300) == 0:
            glitch_active = True
        if glitch_timer > 10:
            glitch_active = False
            glitch_timer = 0
        # 폰트 설정
        try:
            font_title = pygame.font.Font("NanumSquareB.ttf", 36)  # 제목 폰트 크기 감소
            font_subtitle = pygame.font.Font("NanumSquareR.ttf", 18)
            font_desc = pygame.font.Font("NanumSquareR.ttf", 14)
            font_detail = pygame.font.Font("NanumSquareR.ttf", 12)  # 상세 폰트 크기 감소
        except:
            font_title = pygame.font.Font(None, 42)
            font_subtitle = pygame.font.Font(None, 20)
            font_desc = pygame.font.Font(None, 16)
            font_detail = pygame.font.Font(None, 14)
        # 홀로그램 스타일 제목
        title_main = "◆ DIFFICULTY MATRIX ◆"
        title_sub = ">> NEURAL CHALLENGE SELECTOR <<"
        # 글리치 효과 적용
        glitch_offset_x = 0
        glitch_offset_y = 0
        if glitch_active:
            glitch_offset_x = random.randint(-3, 3)
            glitch_offset_y = random.randint(-1, 1)
        # 네온 글로우 레이어들
        title_y = 50
        for i, (offset, color, alpha) in enumerate([(4, (0, 255, 255), 60), (2, (255, 0, 128), 120), (0, (255, 255, 255), 255)]):
            glow_text = font_title.render(title_main, True, (*color[:3], alpha))
            glow_rect = glow_text.get_rect(center=(WIDTH // 2 + offset + glitch_offset_x, title_y + glitch_offset_y))
            if alpha < 255:  # 글로우 레이어
                glow_surface = pygame.Surface(glow_text.get_size(), pygame.SRCALPHA)
                glow_surface.blit(glow_text, (0, 0))
                SCREEN.blit(glow_surface, glow_rect)
            else:  # 메인 텍스트
                SCREEN.blit(glow_text, glow_rect)
        # 서브 제목
        sub_text = font_desc.render(title_sub, True, (0, 255, 255))
        sub_rect = sub_text.get_rect(center=(WIDTH // 2, title_y + 35))
        SCREEN.blit(sub_text, sub_rect)
        # 타이핑 커서 효과
        if animation_timer % 60 < 30:
            cursor_surface = pygame.Surface((150, 2), pygame.SRCALPHA)
            pygame.draw.rect(cursor_surface, (0, 255, 255, 150), (0, 0, 150, 2))
            SCREEN.blit(cursor_surface, (WIDTH // 2 - 75, title_y + 45))
        # 네온 파티클 업데이트 및 그리기
        for particle in neon_particles:
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            # 화면 경계 처리
            if particle["x"] < 0 or particle["x"] > WIDTH:
                particle["vx"] *= -1
            if particle["y"] < 0 or particle["y"] > HEIGHT:
                particle["vy"] *= -1
            # 펄스 효과
            pulse = abs(math.sin(animation_timer * particle["pulse_speed"]))
            current_alpha = int(particle["alpha"] * (0.5 + pulse * 0.5))
            # 네온 글로우 파티클
            for i in range(2):
                glow_size = particle["size"] + i * 2
                glow_alpha = current_alpha // (i + 1)
                glow_surf = pygame.Surface((glow_size * 4, glow_size * 4), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*particle["color"], glow_alpha),
                                 (glow_size * 2, glow_size * 2), glow_size)
                SCREEN.blit(glow_surf, (particle["x"] - glow_size * 2, 
                                       particle["y"] - glow_size * 2))
        # 스캔라인 효과
        for scan_line in scan_lines:
            scan_line["y"] += scan_line["speed"]
            if scan_line["y"] > HEIGHT:
                scan_line["y"] = -10
            # 더 화려한 스캔라인
            for i in range(3):
                scan_alpha = scan_line["alpha"] - i * 10
                if scan_alpha > 0:
                    scan_surf = pygame.Surface((WIDTH, 2 - i), pygame.SRCALPHA)
                    scan_surf.fill((0, 255, 255, scan_alpha))
                    SCREEN.blit(scan_surf, (0, scan_line["y"] + i))
        # 홀로그램 난이도 카드들
        cards_per_row = 2  # 2x2 레이아웃
        card_width = 250  # 카드 너비 증가
        card_height = 170  # 카드 높이 증가
        card_margin = 40  # 마진 증가
        start_x = (WIDTH - (cards_per_row * card_width + (cards_per_row - 1) * card_margin)) // 2
        start_y = 120  # 시작 위치 약간 위로
        for i, difficulty in enumerate(difficulties):
            row = i // cards_per_row
            col = i % cards_per_row
            card_x = start_x + col * (card_width + card_margin)
            card_y = start_y + row * (card_height + card_margin + 20)  # 세로 간격 감소
            # 선택된 카드 효과 (다층 홀로그램 글로우)
            if i == selected:
                # 다층 네온 글로우
                for glow_layer in range(5, 0, -1):
                    glow_intensity = int(abs(math.sin(animation_timer * 0.15 + glow_layer * 0.5)) * 40) + 60
                    glow_size = glow_layer * 6
                    glow_surface = pygame.Surface((card_width + glow_size, card_height + glow_size), pygame.SRCALPHA)
                    # 무지개빛 효과
                    if glow_layer % 2 == 0:
                        holo_angle = animation_timer * 0.1 + glow_layer
                        holo_r = int(128 + 127 * math.sin(holo_angle))
                        holo_g = int(128 + 127 * math.sin(holo_angle + 2.094))
                        holo_b = int(128 + 127 * math.sin(holo_angle + 4.189))
                        layer_color = (holo_r, holo_g, holo_b)
                    else:
                        layer_color = difficulty["color"]
                    pygame.draw.rect(glow_surface, (*layer_color, glow_intensity // glow_layer),
                                   (0, 0, card_width + glow_size, card_height + glow_size), border_radius=20)
                    SCREEN.blit(glow_surface, (card_x - glow_size//2, card_y - glow_size//2))
                # 선택 테두리 (네온 스타일)
                draw.rect(difficulty["color"],
                               (card_x - 4, card_y - 4, card_width + 8, card_height + 8), 3, border_radius=15)
                # 내부 테두리
                draw.rect((*difficulty["color"], 100),
                               (card_x - 2, card_y - 2, card_width + 4, card_height + 4), 1, border_radius=13)
            # 홀로그램 카드 배경
            card_surface = pygame.Surface((card_width, card_height), pygame.SRCALPHA)
            # 어두운 배경과 회로 패턴
            if i == selected:
                card_surface.fill((10, 15, 25, 250))  # 더 진한 배경
                # 전자 회로 패턴 추가
                for _ in range(8):
                    node_x = random.randint(10, card_width - 10)
                    node_y = random.randint(10, card_height - 10)
                    pygame.draw.circle(card_surface, (*difficulty["color"], 30), (node_x, node_y), 1)
            else:
                card_surface.fill((15, 20, 30, 200))
            # 네온 테두리
            pygame.draw.rect(card_surface, (*difficulty["color"], 150), (0, 0, card_width, card_height), 2, border_radius=12)
            SCREEN.blit(card_surface, (card_x, card_y))
            # 리그 이름 표시 (선택된 카드만 이름 표시, 네온 효과)
            if i == selected:
                # 네온 글로우 텍스트
                for j in range(2, 0, -1):
                    name_glow = font_subtitle.render(difficulty['name'], True, (*difficulty["color"], 100 - j*30))
                    name_rect = name_glow.get_rect(center=(card_x + card_width//2, card_y + 30))
                    SCREEN.blit(name_glow, (name_rect.x - j, name_rect.y - j))
                    SCREEN.blit(name_glow, (name_rect.x + j, name_rect.y + j))
                name_text = font_subtitle.render(difficulty['name'], True, (255, 255, 255))
                name_rect = name_text.get_rect(center=(card_x + card_width//2, card_y + 30))
                SCREEN.blit(name_text, name_rect)
            # 리그별 엠블럼 그리기 (카드 중앙에 크고 화려하게)
            emblem_x = card_x + card_width // 2
            emblem_y = card_y + card_height // 2 + 10
            # 선택된 엠블럼은 회전 효과 적용
            rotation_angle = 0
            if i == selected:
                rotation_angle = (animation_timer * 2) % 360
            if difficulty["id"] == "junior":
                # 🌱 주니어리그 - 새싹 엠블럼
                # 회전 효과를 위한 스케일 계산
                scale_x = math.cos(math.radians(rotation_angle)) if i == selected else 1.0
                # 줄기
                draw.line((100, 200, 100), (emblem_x, emblem_y + 20), (emblem_x, emblem_y - 5), 3)
                # 잎사귀들 (회전 효과 적용)
                for j, (dx, dy, angle) in enumerate([(-15, -5, -30), (15, -5, 30), (-12, 5, -20), (12, 5, 20)]):
                    leaf_color = (50 + j*30, 255 - j*20, 50)
                    # 회전 효과 적용
                    rotated_dx = dx * scale_x
                    # 잎 본체
                    leaf_width = max(2, int(16 * abs(scale_x)))
                    pygame.draw.ellipse(SCREEN, leaf_color, (emblem_x + rotated_dx - leaf_width//2, emblem_y + dy - 4, leaf_width, 8))
                    if abs(scale_x) > 0.3:
                        pygame.draw.ellipse(SCREEN, (0, 150, 0), (emblem_x + rotated_dx - leaf_width//2, emblem_y + dy - 4, leaf_width, 8), 1)
                # 중심 새싹
                draw.circle((150, 255, 150), (emblem_x, emblem_y - 10), 8)
                draw.circle((100, 255, 100), (emblem_x, emblem_y - 10), 6)
                draw.circle((200, 255, 200), (emblem_x - 2, emblem_y - 12), 2)
                # 빛나는 효과
                for r in range(3):
                    alpha = 50 - r * 15
                    draw.circle((150, 255, 150, alpha), (emblem_x, emblem_y - 10), 12 + r * 3, 1)
            elif difficulty["id"] == "pro":
                # ⚡ 프로리그 - 번개 엠블럼
                # 회전 효과를 위한 스케일 계산
                scale_x = math.cos(math.radians(rotation_angle)) if i == selected else 1.0
                # 외곽 원 (회전 시 타원형으로)
                if abs(scale_x) > 0.1:
                    ellipse_width = int(50 * abs(scale_x))
                    ellipse_rect = (emblem_x - ellipse_width//2, emblem_y - 25, ellipse_width, 50)
                    pygame.draw.ellipse(SCREEN, (255, 200, 100), ellipse_rect, 2)
                # 번개 본체 (회전 효과 적용)
                lightning_points = [
                    (emblem_x - 8 * scale_x, emblem_y - 15),
                    (emblem_x + 3 * scale_x, emblem_y - 5),
                    (emblem_x - 3 * scale_x, emblem_y - 5),
                    (emblem_x + 8 * scale_x, emblem_y + 15),
                    (emblem_x - 2 * scale_x, emblem_y + 5),
                    (emblem_x + 4 * scale_x, emblem_y + 5)
                ]
                if abs(scale_x) > 0.2:
                    pygame.draw.lines(SCREEN, (255, 255, 100), False, lightning_points, 4)
                    pygame.draw.lines(SCREEN, (255, 200, 0), False, lightning_points, 2)
                # 전기 스파크 (회전과 무관하게 유지)
                for angle in range(0, 360, 60):
                    spark_angle = angle + rotation_angle if i == selected else angle
                    spark_x = emblem_x + 30 * math.cos(math.radians(spark_angle))
                    spark_y = emblem_y + 30 * math.sin(math.radians(spark_angle))
                    draw.line((255, 255, 150), (emblem_x, emblem_y), (spark_x, spark_y), 1)
                # 중심 광원
                draw.circle((255, 255, 200), (emblem_x, emblem_y), 5)
            elif difficulty["id"] == "champion":
                # 💎 챔피언리그 - 다이아몬드 엠블럼
                # 회전 효과를 위한 스케일 계산
                scale_x = math.cos(math.radians(rotation_angle)) if i == selected else 1.0
                # 다이아몬드 외형 (회전 효과 적용)
                diamond_points = [
                    (emblem_x, emblem_y - 25),  # 상단
                    (emblem_x + 20 * scale_x, emblem_y - 5),  # 우상
                    (emblem_x + 15 * scale_x, emblem_y + 5),  # 우중
                    (emblem_x, emblem_y + 20),  # 하단
                    (emblem_x - 15 * scale_x, emblem_y + 5),  # 좌중
                    (emblem_x - 20 * scale_x, emblem_y - 5),  # 좌상
                ]
                # 그라데이션 효과를 위한 여러 층
                colors = [(255, 150, 255), (255, 100, 255), (200, 50, 200)]
                for j, color in enumerate(colors):
                    scaled_points = []
                    scale = 1.0 - j * 0.2
                    for px, py in diamond_points:
                        scaled_x = emblem_x + (px - emblem_x) * scale
                        scaled_y = emblem_y + (py - emblem_y) * scale
                        scaled_points.append((scaled_x, scaled_y))
                    if abs(scale_x) > 0.1:
                        draw.polygon(color, scaled_points)
                # 반짝임 효과
                if abs(scale_x) > 0.2:
                    pygame.draw.lines(SCREEN, (255, 255, 255), True, diamond_points, 2)
                # 중심 빛
                draw.circle((255, 200, 255), (emblem_x, emblem_y), 3)
                # 광채 효과 (회전과 무관하게 유지)
                for angle in range(45, 360, 90):
                    ray_angle = angle + rotation_angle if i == selected else angle
                    ray_x = emblem_x + 35 * math.cos(math.radians(ray_angle))
                    ray_y = emblem_y + 35 * math.sin(math.radians(ray_angle))
                    draw.line((255, 200, 255, 100), (emblem_x, emblem_y), (ray_x, ray_y), 1)
            elif difficulty["id"] == "mythic":
                # 👑 신화리그 - 왕관 엠블럼
                # 회전 효과를 위한 스케일 계산
                scale_x = math.cos(math.radians(rotation_angle)) if i == selected else 1.0
                # 왕관 베이스 (회전 효과 적용)
                crown_base = [(emblem_x - 25 * scale_x, emblem_y + 10), (emblem_x + 25 * scale_x, emblem_y + 10)]
                if abs(scale_x) > 0.2:
                    draw.line((255, 215, 0), crown_base[0], crown_base[1], 3)
                # 왕관 봉우리들 (회전 효과 적용)
                peaks = [
                    (emblem_x - 20 * scale_x, emblem_y - 15, 12),  # 왼쪽
                    (emblem_x - 10 * scale_x, emblem_y - 10, 10),
                    (emblem_x, emblem_y - 20, 15),  # 중앙 (가장 높음)
                    (emblem_x + 10 * scale_x, emblem_y - 10, 10),
                    (emblem_x + 20 * scale_x, emblem_y - 15, 12),  # 오른쪽
                ]
                # 왕관 본체
                if abs(scale_x) > 0.2:
                    for j, (px, py, height) in enumerate(peaks):
                        # 봉우리 그리기
                        pygame.draw.lines(SCREEN, (255, 215, 0), False, 
                                        [(px - 5 * abs(scale_x), emblem_y + 10), (px, py), (px + 5 * abs(scale_x), emblem_y + 10)], 3)
                        # 보석
                        gem_colors = [(255, 50, 50), (50, 255, 50), (255, 255, 255), (50, 50, 255), (255, 50, 50)]
                        draw.circle(gem_colors[j], (px, py + 5), 3)
                        if scale_x > 0:
                            draw.circle((255, 255, 255), (px - 1, py + 4), 1)
                # 중앙 큰 보석
                draw.circle((255, 100, 255), (emblem_x, emblem_y), 5)
                draw.circle((255, 200, 255), (emblem_x, emblem_y), 3)
                draw.circle((255, 255, 255), (emblem_x - 1, emblem_y - 1), 1)
                # 황금빛 후광
                for r in range(3):
                    draw.circle((255, 215, 0, 30 - r*10), (emblem_x, emblem_y), 30 + r*5, 1)
        # 선택된 난이도 상세 정보
        if selected < len(difficulties):
            # 상세 정보 박스를 카드 아래쪽에 배치
            detail_y = start_y + 2 * (card_height + card_margin + 20) + 10  # 두 번째 줄 카드 아래
            selected_diff = difficulties[selected]
            # 홀로그램 상세 정보 패널
            detail_width = 520
            detail_height = 100
            detail_x = (WIDTH - detail_width) // 2
            # 다층 글로우 배경
            for j in range(3, 0, -1):
                glow_surface = pygame.Surface((detail_width + j*10, detail_height + j*10), pygame.SRCALPHA)
                glow_alpha = 30 - j*8
                pygame.draw.rect(glow_surface, (*selected_diff["color"], glow_alpha), 
                               (0, 0, detail_width + j*10, detail_height + j*10), 
                               border_radius=15)
                SCREEN.blit(glow_surface, (detail_x - j*5, detail_y - j*5))
            # 메인 패널
            detail_surface = pygame.Surface((detail_width, detail_height), pygame.SRCALPHA)
            detail_surface.fill((10, 15, 25, 220))
            pygame.draw.rect(detail_surface, selected_diff["color"], 
                           (0, 0, detail_width, detail_height), 2, border_radius=12)
            # 내부 회로 패턴
            for j in range(5):
                node_x = random.randint(10, detail_width - 10)
                node_y = random.randint(10, detail_height - 10)
                pygame.draw.circle(detail_surface, (*selected_diff["color"], 40), (node_x, node_y), 2)
            SCREEN.blit(detail_surface, (detail_x, detail_y))
            # 상세 제목 제거 (스크린샷처럼 내용만 표시)
            # 챔피언리그 텍스트만 표시 (스크린샷처럼)
            if selected_diff['id'] == 'champion':
                # 챔피언리그 - 상세 정보 텍스트 (가운데 정렬)
                champion_text1 = font_subtitle.render(f"{selected_diff['icon']} {selected_diff['name']} - 상세 정보", True, (255, 255, 255))
                champion_rect1 = champion_text1.get_rect(center=(detail_x + detail_width//2, detail_y + 25))
                SCREEN.blit(champion_text1, champion_rect1)
                # 공 속도와 AI 실수 텍스트 (가운데 정렬)
                champion_text2 = font_detail.render("빠른 공 속도", True, (200, 200, 200))
                champion_rect2 = champion_text2.get_rect(center=(detail_x + detail_width//2, detail_y + 45))
                SCREEN.blit(champion_text2, champion_rect2)
                champion_text3 = font_detail.render("AI 소수 실수 (8%)", True, (200, 200, 200))
                champion_rect3 = champion_text3.get_rect(center=(detail_x + detail_width//2, detail_y + 65))
                SCREEN.blit(champion_text3, champion_rect3)
            else:
                # 다른 리그들은 기존 설명 표시 (가운데 정렬)
                # 제목
                title_text = font_subtitle.render(f"{selected_diff['icon']} {selected_diff['name']} - 상세 정보", True, (255, 255, 255))
                title_rect = title_text.get_rect(center=(detail_x + detail_width//2, detail_y + 25))
                SCREEN.blit(title_text, title_rect)
                # 설명
                desc_lines = selected_diff["description"].split('\n')
                for i, desc_line in enumerate(desc_lines[:2]):
                    desc_text = font_detail.render(desc_line, True, (200, 200, 200))
                    desc_rect = desc_text.get_rect(center=(detail_x + detail_width//2, detail_y + 45 + i * 20))
                    SCREEN.blit(desc_text, desc_rect)
        # 홀로그램 스타일 조작 안내
        controls_y = HEIGHT - 35
        control_text = "↑↓←→ : Navigate    SPACE : Launch    ESC : Back"
        # 네온 텍스트 효과
        control_surface = font_desc.render(control_text, True, (0, 255, 255))
        control_rect = control_surface.get_rect(center=(WIDTH // 2, controls_y))
        SCREEN.blit(control_surface, control_rect)
        # 하단 스캔라인
        scan_y = HEIGHT - 20
        scan_alpha = int(abs(math.sin(animation_timer * 0.1)) * 100) + 50
        draw.line((0, 255, 255, scan_alpha), (50, scan_y), (WIDTH - 50, scan_y), 1)
        pygame.display.flip()
        clock.tick(60)
def start_game_with_difficulty(character_id, difficulty_mode):
    """선택한 캐릭터와 난이도로 게임 시작"""
    global ai_mode, ai_enabled
    # AI 모드 설정
    ai_mode = difficulty_mode
    ai_enabled = True
    # 캐릭터별 설정 (향후 확장용)
    # 현재는 UFO 플레이어만 있으므로 기본 설정 사용
    if character_id == "ufo_player":
        # 기본 UFO 플레이어 설정
        pass
    # 향후 다른 캐릭터들 추가:
    # elif character_id == "speed_player":
    #     # 스피드 캐릭터 설정
    #     pass
    # 스테이지 1 인트로 표시
    show_stage1_intro()
    # 선택한 난이도 정보 표시
    difficulty_names = {
        "junior": "🌱 주니어리그",
        "pro": "⚡ 프로리그", 
        "champion": "💎 챔피언리그",
        "mythic": "👑 신화리그"
    }
    difficulty_name = difficulty_names.get(difficulty_mode, difficulty_mode)
    # 난이도 선택 확인 메시지
    font = pygame.font.Font(None, 36)
    message = f"난이도: {difficulty_name}"
    # 반투명 배경
    overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
    overlay.fill((0, 0, 0, 150))
    SCREEN.blit(overlay, (0, 0))
    # 메시지 박스
    box_width = 400
    box_height = 150
    box_x = (WIDTH - box_width) // 2
    box_y = (HEIGHT - box_height) // 2
    draw.rect((30, 35, 50), (box_x, box_y, box_width, box_height), border_radius=10)
    draw.rect((100, 150, 255), (box_x, box_y, box_width, box_height), 3, border_radius=10)
    # 제목
    title_text = font.render("🎮 게임 시작!", True, (255, 255, 255))
    title_rect = title_text.get_rect(center=(WIDTH // 2, box_y + 40))
    SCREEN.blit(title_text, title_rect)
    # 난이도 표시
    diff_text = font.render(message, True, (100, 255, 100))
    diff_rect = diff_text.get_rect(center=(WIDTH // 2, box_y + 80))
    SCREEN.blit(diff_text, diff_rect)
    # 안내 메시지
    help_font = pygame.font.Font(None, 24)
    help_text = help_font.render("준비되면 아무 키나 누르세요...", True, (200, 200, 200))
    help_rect = help_text.get_rect(center=(WIDTH // 2, box_y + 110))
    SCREEN.blit(help_text, help_rect)
    pygame.display.flip()
    # 키 입력 대기
    waiting = True
    while waiting:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                waiting = False
                break
    # 게임 시작 (스테이지 1부터)
    print(f"🎮 게임 시작! 캐릭터: {character_id}, 난이도: {difficulty_mode}")
    main(1)
def show_developer_stage_select():
    # 개발자 모드 진입 시 자동으로 신화리그 설정
    global ai_mode
    ai_mode = "mythic"
    print("🔧 개발자 모드 진입: 신화리그 자동 설정")
    stage_buttons = []
    rows = 3
    cols = 5
    button_width = 100
    button_height = 50
    margin_x = (WIDTH - cols * button_width) // (cols + 1)
    margin_y = 20
    font = pygame.font.Font("NanumSquareR.ttf", 24)
    for i in range(15):
        row = i // cols
        col = i % cols
        x = margin_x + col * (button_width + margin_x)
        y = 150 + row * (button_height + margin_y)
        rect = pygame.Rect(x, y, button_width, button_height)
        stage_buttons.append((rect, i + 1))
    selected_index = 0  # 현재 선택된 버튼 인덱스
    while True:
        SCREEN.fill((10, 10, 40))
        ui_manager.draw_centered_text("개발자 스테이지 선택", 40, -250)
        ui_manager.draw_centered_text("←↑↓→ 또는 WASD로 이동, SPACE로 선택", 24, -200)
        # 버튼 그리기
        for idx, (rect, num) in enumerate(stage_buttons):
            color = (255, 255, 0) if idx == selected_index else (180, 220, 255)
            draw.rect(color, rect)
            label = font.render(f"Stage {num}", True, BLACK)
            SCREEN.blit(label, (rect.centerx - label.get_width() // 2, rect.centery - label.get_height() // 2))
        pygame.display.flip()
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                row = selected_index // cols
                col = selected_index % cols
                if event.key in [pygame.K_RIGHT, pygame.K_d]:
                    col = (col + 1) % cols
                elif event.key in [pygame.K_LEFT, pygame.K_a]:
                    col = (col - 1) % cols
                elif event.key in [pygame.K_DOWN, pygame.K_s]:
                    row = (row + 1) % rows
                elif event.key in [pygame.K_UP, pygame.K_w]:
                    row = (row - 1) % rows
                selected_index = row * cols + col
                selected_index = max(0, min(selected_index, len(stage_buttons) - 1))
                if event.key == pygame.K_SPACE:
                    _, stage_num = stage_buttons[selected_index]
                    main(stage_num)
                    return
            elif event.type == pygame.MOUSEBUTTONDOWN:
                mx, my = pygame.mouse.get_pos()
                for idx, (rect, num) in enumerate(stage_buttons):
                    if rect.collidepoint(mx, my):
                        main(num)
                        return
def show_item_manager_menu():
    """아이템 관리 메뉴 - 탭키 아이템창과 동일한 UI"""
    global active_item_slot, passive_item_list, selected_item_index, selected_passive_item, speedboots_obtained, speedgear_obtained, battery_obtained, revival_obtained, master_obtained, cooltime_obtained
    global chargebag_obtained, spikeboots_obtained, dashgear_obtained, bulkup_obtained, sensor_obtained, dashholder_obtained
    global rolling_charges, items
    # 아이템 선택 상태
    selected_category = 0  # 0: 엑티브, 1: 패시브
    selected_item_index = 0  # 현재 선택된 아이템 인덱스 (카테고리별로 공통 사용)
    # 선택된 아이템들을 저장할 리스트
    selected_active_items = []
    selected_passive_items = []
    # 아이템 그리드 설정
    grid_cols = 6
    grid_rows = 4
    item_size = 60
    item_spacing = 20
    grid_start_x = (WIDTH - (grid_cols * item_size + (grid_cols - 1) * item_spacing)) // 2
    grid_start_y = 200
    # 모든 아이템 목록
    all_items = [
        # 엑티브 아이템들
        {"name": "long_boost", "type": "active", "icon": long_boost_icon},
        {"name": "gauge_charge", "type": "active", "icon": gauge_200_icon},
        {"name": "life_elixir", "type": "active", "icon": life_elixir_icon},  # 🌈 생명수 추가
        {"name": "aipill", "type": "active", "icon": aipill_icon},
        {"name": "wall", "type": "active", "icon": wall_icon},
        {"name": "molotov", "type": "active", "icon": get_item_icon("molotov")},  # 화염병 추가
        {"name": "grenade", "type": "active", "icon": get_item_icon("grenade")},  # 수류탄 추가
        {"name": "flare", "type": "active", "icon": get_item_icon("flare")},  # 조명탄 추가
        {"name": "predictor", "type": "active", "icon": get_item_icon("predictor")},  # 레이저스코프 추가
        {"name": "smoke_grenade", "type": "active", "icon": get_item_icon("smoke_grenade")},  # 연막탄 추가
        {"name": "slot_add", "type": "passive", "icon": slot_add_icon},
        {"name": "revival", "type": "passive", "icon": revival_icon},
        {"name": "master", "type": "passive", "icon": master_icon},
        {"name": "cooltime", "type": "passive", "icon": cooltime_icon},
        {"name": "speedboots", "type": "passive", "icon": speedboots_icon},
        {"name": "gravitybelt", "type": "passive", "icon": gravitybelt_icon},
        {"name": "speedgear", "type": "passive", "icon": speedgear_icon},
        {"name": "battery", "type": "passive", "icon": battery_icon},
        {"name": "chargebag", "type": "passive", "icon": chargebag_icon},
        {"name": "spikeboots", "type": "passive", "icon": spikeboots_icon},
        {"name": "dashgear", "type": "passive", "icon": dashgear_icon},
        {"name": "bulkup", "type": "passive", "icon": bulkup_icon},
        {"name": "sensor", "type": "passive", "icon": sensor_icon},
        {"name": "dashholder", "type": "passive", "icon": dashholder_icon},
    ]
    # 엑티브/패시브 아이템 분리
    active_items = [item for item in all_items if item["type"] == "active"]
    passive_items = [item for item in all_items if item["type"] == "passive"]
    font_large = pygame.font.Font("NanumSquareB.ttf", 32)
    font_medium = pygame.font.Font("NanumSquareR.ttf", 24)
    font_small = pygame.font.Font("NanumSquareR.ttf", 18)
    while True:
        # 배경 그리기
        SCREEN.fill((10, 10, 40))
        # 제목
        title_text = font_large.render("아이템 관리", True, WHITE)
        title_rect = title_text.get_rect(center=(WIDTH // 2, 80))
        SCREEN.blit(title_text, title_rect)
        # 탭 버튼
        tab_width = 150
        tab_height = 40
        tab_y = 120
        # 엑티브 탭
        active_tab_rect = pygame.Rect(WIDTH // 2 - tab_width - 10, tab_y, tab_width, tab_height)
        active_tab_color = (100, 150, 255) if selected_category == 0 else (60, 60, 80)
        draw.rect(active_tab_color, active_tab_rect)
        draw.rect(WHITE, active_tab_rect, 2)
        active_tab_text = font_medium.render("엑티브", True, WHITE)
        active_tab_text_rect = active_tab_text.get_rect(center=active_tab_rect.center)
        SCREEN.blit(active_tab_text, active_tab_text_rect)
        # 패시브 탭
        passive_tab_rect = pygame.Rect(WIDTH // 2 + 10, tab_y, tab_width, tab_height)
        passive_tab_color = (100, 150, 255) if selected_category == 1 else (60, 60, 80)
        draw.rect(passive_tab_color, passive_tab_rect)
        draw.rect(WHITE, passive_tab_rect, 2)
        passive_tab_text = font_medium.render("패시브", True, WHITE)
        passive_tab_text_rect = passive_tab_text.get_rect(center=passive_tab_rect.center)
        SCREEN.blit(passive_tab_text, passive_tab_text_rect)
        # 현재 선택된 카테고리의 아이템들 표시
        current_items = active_items if selected_category == 0 else passive_items
        for i, item in enumerate(current_items):
            row = i // grid_cols
            col = i % grid_cols
            x = grid_start_x + col * (item_size + item_spacing)
            y = grid_start_y + row * (item_size + item_spacing)
            # 아이템 배경
            item_rect = pygame.Rect(x, y, item_size, item_size)
            # 선택된 아이템인지 확인
            is_selected = False
            if selected_category == 0:
                is_selected = item["name"] in selected_active_items
            else:
                is_selected = item["name"] in selected_passive_items
            # 현재 커서 위치인지 확인
            is_cursor = (i == selected_item_index)
            # 배경 색상
            if is_selected:
                draw.rect((255, 255, 0), item_rect)  # 선택된 아이템은 노란색
            elif is_cursor:
                draw.rect((100, 150, 255), item_rect)  # 현재 커서는 파란색
            else:
                draw.rect((60, 60, 80), item_rect)
            # 테두리 색상
            if is_cursor:
                draw.rect((255, 255, 255), item_rect, 3)  # 커서는 굵은 흰색 테두리
            else:
                draw.rect(WHITE, item_rect, 2)
            # 아이템 아이콘
            if item["icon"]:
                icon_surface = pygame.transform.scale(item["icon"], (item_size - 10, item_size - 10))
                icon_rect = icon_surface.get_rect(center=item_rect.center)
                SCREEN.blit(icon_surface, icon_rect)
            # 아이템 이름
            item_name = get_item_name_korean(item["name"])
            # 시너지 효과일 때 보라색으로 표시
            if item["name"] == "gravitybelt" and gravity_speed_synergy:
                name_color = (128, 0, 128)  # 보라색
            else:
                name_color = WHITE
            name_text = font_small.render(item_name, True, name_color)
            name_rect = name_text.get_rect(center=(x + item_size // 2, y + item_size + 15))
            SCREEN.blit(name_text, name_rect)
        # 선택된 아이템 정보 표시
        info_y = grid_start_y + (grid_rows * (item_size + item_spacing)) + 50
        info_text = font_medium.render("선택된 아이템:", True, WHITE)
        SCREEN.blit(info_text, (50, info_y))
        selected_items_text = ""
        if selected_category == 0:
            selected_items_text = ", ".join([get_item_name_korean(name) for name in selected_active_items]) if selected_active_items else "없음"
        else:
            selected_items_text = ", ".join([get_item_name_korean(name) for name in selected_passive_items]) if selected_passive_items else "없음"
        # 시너지 효과가 포함된 경우 보라색으로 표시
        text_color = (200, 200, 200)  # 기본 색상
        if "gravitybelt" in selected_passive_items and gravity_speed_synergy:
            text_color = (128, 0, 128)  # 보라색
        selected_text = font_small.render(selected_items_text, True, text_color)
        SCREEN.blit(selected_text, (50, info_y + 30))
        # 조작법 안내
        controls_text = font_small.render("방향키: 아이템 선택, SPACE: 아이템 선택/해제, TAB: 탭 전환, ENTER: 관리자 모드로 이동", True, (150, 150, 150))
        SCREEN.blit(controls_text, (50, HEIGHT - 50))
        pygame.display.flip()
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN:
                # 🎯 일시정지 토글 (P키 또는 ㅔ키)
                if event.key == pygame.K_p:  # P키
                    global game_paused
                    game_paused = not game_paused
                    print(f"🎯 게임 일시정지 토글: {'ON' if game_paused else 'OFF'}")
                    continue  # 일시정지 토글 후 다른 키 처리 건너뛰기
                elif event.key == pygame.K_TAB:
                    # 탭 전환
                    selected_category = (selected_category + 1) % 2
                    selected_item_index = 0  # 탭 전환 시 첫 번째 아이템으로 커서 이동
                elif event.key == pygame.K_ESCAPE:
                    # 취소하고 메인 메뉴로 돌아가기
                    return
                elif event.key == pygame.K_RETURN:
                    # 선택된 아이템들을 적용하고 관리자 모드로 이동
                    apply_selected_items(selected_active_items, selected_passive_items)
                    show_developer_stage_select()
                    return
                elif event.key in [pygame.K_LEFT, pygame.K_RIGHT, pygame.K_UP, pygame.K_DOWN]:
                    # 아이템 선택
                    current_items = active_items if selected_category == 0 else passive_items
                    if current_items:
                        current_row = selected_item_index // grid_cols
                        current_col = selected_item_index % grid_cols
                        if event.key == pygame.K_RIGHT:
                            current_col = (current_col + 1) % grid_cols
                        elif event.key == pygame.K_LEFT:
                            current_col = (current_col - 1) % grid_cols
                        elif event.key == pygame.K_DOWN:
                            current_row = (current_row + 1) % ((len(current_items) + grid_cols - 1) // grid_cols)
                        elif event.key == pygame.K_UP:
                            current_row = (current_row - 1) % ((len(current_items) + grid_cols - 1) // grid_cols)
                        new_index = current_row * grid_cols + current_col
                        if new_index < len(current_items):
                            selected_item_index = new_index
                elif event.key == pygame.K_SPACE:
                    # 아이템 선택/해제
                    current_items = active_items if selected_category == 0 else passive_items
                    if current_items and selected_item_index < len(current_items):
                        selected_item = current_items[selected_item_index]
                        item_name = selected_item["name"]
                        if selected_category == 0:
                            if item_name in selected_active_items:
                                selected_active_items.remove(item_name)
                            else:
                                selected_active_items.append(item_name)
                        else:
                            if item_name in selected_passive_items:
                                selected_passive_items.remove(item_name)
                            else:
                                selected_passive_items.append(item_name)
            elif event.type == pygame.MOUSEBUTTONDOWN:
                mx, my = pygame.mouse.get_pos()
                # 탭 클릭 처리
                if active_tab_rect.collidepoint(mx, my):
                    selected_category = 0
                elif passive_tab_rect.collidepoint(mx, my):
                    selected_category = 1
                # 아이템 클릭 처리
                current_items = active_items if selected_category == 0 else passive_items
                for i, item in enumerate(current_items):
                    row = i // grid_cols
                    col = i % grid_cols
                    x = grid_start_x + col * (item_size + item_spacing)
                    y = grid_start_y + row * (item_size + item_spacing)
                    item_rect = pygame.Rect(x, y, item_size, item_size)
                    if item_rect.collidepoint(mx, my):
                        item_name = item["name"]
                        if selected_category == 0:
                            if item_name in selected_active_items:
                                selected_active_items.remove(item_name)
                            else:
                                selected_active_items.append(item_name)
                        else:
                            if item_name in selected_passive_items:
                                selected_passive_items.remove(item_name)
                            else:
                                selected_passive_items.append(item_name)
def apply_selected_items(selected_active_items, selected_passive_items):
    """선택된 아이템들을 게임에 적용"""
    global active_item_slot, passive_item_list, speedboots_obtained, speedgear_obtained, battery_obtained, revival_obtained, master_obtained, cooltime_obtained
    global chargebag_obtained, spikeboots_obtained, dashgear_obtained, bulkup_obtained, sensor_obtained, danger_sensor_obtained, danger_sensor_enabled
    global dashholder_obtained, gravitybelt_obtained, items, rolling_charges
    # 아이템 슬롯 초기화
    active_item_slot = []
    passive_item_list = []
    # 선택된 엑티브 아이템들을 슬롯에 추가
    for item_name in selected_active_items:
        # 아이템 데이터 생성
        item_data = {
            "name": item_name,
            "icon": get_item_icon(item_name),
            "last_use": 0,
            "effect": item_name  # effect 키 추가
        }
        active_item_slot.append(item_data)
    # 선택된 패시브 아이템들을 적용
    for item_name in selected_passive_items:
        # 패시브 아이템을 passive_item_list에 추가
        item_data = {
            "name": item_name,
            "icon": get_item_icon(item_name),
            "type": "passive"
        }
        passive_item_list.append(item_data)
        # 아이템 효과 적용
        if item_name == "speedboots":
            speedboots_obtained = True
            items.speedboots_obtained = True
        # 패시브 아이템 활성화 매핑
        passive_items = {
            "speedgear": ("speedgear_obtained", True),
            "battery": ("battery_obtained", True),
            "revival": ("revival_obtained", True),
            "master": ("master_obtained", True),
            "cooltime": ("cooltime_obtained", True),
            "chargebag": ("chargebag_obtained", True),
            "spikeboots": ("spikeboots_obtained", True),
            "dashgear": ("dashgear_obtained", True),
            "bulkup": ("bulkup_obtained", True)
        }
        
        if item_name in passive_items:
            var_name, value = passive_items[item_name]
            globals()[var_name] = value
            setattr(items, var_name, value)
            
            # bulkup 특별 처리
            if item_name == "bulkup":
                # 패들 크기 영구 증가
                global PADDLE_WIDTH, PADDLE_HEIGHT
                PADDLE_WIDTH = int(PADDLE_WIDTH * 1.10)
            PADDLE_HEIGHT = int(PADDLE_HEIGHT * 1.10)
        elif item_name == "sensor":
            danger_sensor_obtained = True
            sensor_obtained = True  # 호환성을 위해 두 변수 모두 설정
            danger_sensor_enabled = True
            sensor_enabled = True  # 기본적으로 활성화 상태로 설정
            items.sensor_obtained = True
        elif item_name == "dashholder":
            dashholder_obtained = True
            items.dashholder_obtained = True
            rolling_charges = 2  # 대쉬 충전량을 2개로 증가
        elif item_name == "gravitybelt":
            gravitybelt_obtained = True
            items.gravitybelt_obtained = True
            print(f"무중력벨트 적용됨: {gravitybelt_obtained}")
            # 무중력벨트가 선택되었을 때 즉시 적용
            if "gravitybelt" in selected_passive_items:
                gravitybelt_obtained = True
                items.gravitybelt_obtained = True
                print(f"무중력벨트 즉시 적용: {gravitybelt_obtained}")
    print(f"선택된 엑티브 아이템: {selected_active_items}")
    print(f"선택된 패시브 아이템: {selected_passive_items}")
    # 무중력벨트가 선택되어 있으면 강제로 적용
    if "gravitybelt" in selected_passive_items:
        gravitybelt_obtained = True
        items.gravitybelt_obtained = True
        print(f"무중력벨트 강제 적용: {gravitybelt_obtained}")
        # 전역 변수 직접 수정
        globals()['gravitybelt_obtained'] = True
    # 무중력벨트 + 스피드기어 시너지 효과 확인
    global gravity_speed_synergy
    if gravitybelt_obtained and speedgear_obtained:
        gravity_speed_synergy = True
        print("무중력벨트 + 스피드기어 시너지 활성화!")
    else:
        gravity_speed_synergy = False
def get_item_icon(item_name):
    """아이템 이름에 따른 아이콘 반환"""
    icon_map = {
        "long_boost": long_boost_icon,
        "gauge_charge": gauge_200_icon,
        "life_elixir": life_elixir_icon,  # 🌈 생명수 아이콘 추가
        "aipill": aipill_icon,
        "wall": wall_icon,
        "slot_add": slot_add_icon,
        "revival": revival_icon,
        "master": master_icon,
        "cooltime": cooltime_icon,
        "speedboots": speedboots_icon,
        "gravitybelt": gravitybelt_icon,
        "speedgear": speedgear_icon,
        "battery": battery_icon,
        "chargebag": chargebag_icon,
        "spikeboots": spikeboots_icon,
        "dashgear": dashgear_icon,
        "bulkup": bulkup_icon,
        "sensor": sensor_icon,
        "dashholder": dashholder_icon,
    }
    # 화염병 아이콘 동적 로드
    if item_name == "molotov":
        try:
            molotov_icon = pygame.image.load("items/molotov.png").convert_alpha()
            molotov_icon = pygame.transform.scale(molotov_icon, (32, 32))
            return molotov_icon
        except:
            molotov_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
            pygame.draw.circle(molotov_icon, (255, 100, 0), (16, 16), 12)
            return molotov_icon
    # 수류탄 아이콘 동적 로드
    if item_name == "grenade":
        try:
            grenade_icon = pygame.image.load("items/grenade.png").convert_alpha()
            grenade_icon = pygame.transform.scale(grenade_icon, (32, 32))
            return grenade_icon
        except:
            grenade_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
            pygame.draw.circle(grenade_icon, (80, 100, 80), (16, 16), 12)
            return grenade_icon
    # 적외선스코프 아이콘 동적 로드
    if item_name == "predictor":
        try:
            predictor_icon = pygame.image.load("items/predictor.png").convert_alpha()
            predictor_icon = pygame.transform.scale(predictor_icon, (32, 32))
            return predictor_icon
        except:
            predictor_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
            pygame.draw.circle(predictor_icon, (200, 50, 50), (16, 16), 12)
            return predictor_icon
    # 조명탄 아이콘 생성
    if item_name == "flare":
        flare_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
        # 조명탄 몸체 (원통형)
        pygame.draw.rect(flare_icon, (180, 180, 180), (12, 8, 8, 18))
        pygame.draw.rect(flare_icon, (200, 200, 200), (13, 9, 6, 16))
        # 조명탄 머리 부분 (밝은 부분)
        pygame.draw.circle(flare_icon, (255, 255, 200), (16, 8), 5)
        pygame.draw.circle(flare_icon, (255, 255, 150), (16, 8), 3)
        pygame.draw.circle(flare_icon, (255, 255, 255), (16, 8), 2)
        # 빛나는 효과 (광선)
        for angle in range(0, 360, 45):
            rad = math.radians(angle)
            x1 = 16 + math.cos(rad) * 6
            y1 = 8 + math.sin(rad) * 6
            x2 = 16 + math.cos(rad) * 12
            y2 = 8 + math.sin(rad) * 12
            pygame.draw.line(flare_icon, (255, 255, 100, 150), (x1, y1), (x2, y2), 1)
        # 하단 안전핀
        pygame.draw.rect(flare_icon, (100, 100, 100), (14, 24, 4, 3))
        return flare_icon
    # 연막탄 아이콘 동적 로드
    if item_name == "smoke_grenade":
        try:
            smoke_grenade_icon = pygame.image.load("items/smoke_grenade.png").convert_alpha()
            smoke_grenade_icon = pygame.transform.scale(smoke_grenade_icon, (32, 32))
            return smoke_grenade_icon
        except:
            smoke_grenade_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
            pygame.draw.circle(smoke_grenade_icon, (150, 150, 150), (16, 16), 12)
            return smoke_grenade_icon
    return icon_map.get(item_name, None)
def show_stage1_intro():
    try:
        boss_img = pygame.image.load("stage1.png")
        boss_img = pygame.transform.scale(boss_img, (WIDTH, HEIGHT))
    except:
        boss_img = pygame.Surface((WIDTH, HEIGHT))
        boss_img.fill((50, 0, 0))
    # 페이드 인 (더 부드럽게)
    for alpha in range(0, 256, 8):
        boss_img.set_alpha(alpha)
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        # 고급스러운 텍스트 렌더링 (파랑~빨강 계통)
        fade_pulse = alpha / 255.0 * 20
        red_component = min(255, 120 + int(fade_pulse * 1.5))
        blue_component = max(80, 200 - int(fade_pulse))
        boss_fade_color = (red_component, 100, blue_component)
        ui_manager.draw_centered_text("STAGE 1", 56, -120, (255, 220, 220), "elegant")
        ui_manager.draw_centered_text("풍악보이", 42, -50, boss_fade_color, "glow")
        # 장식 요소 추가
        decoration_alpha = min(255, alpha + 50)
        if decoration_alpha > 0:
            line_color = (220, 160, 160, decoration_alpha)
            if decoration_alpha < 255:
                line_surface = pygame.Surface((300, 3), pygame.SRCALPHA)
                line_surface.fill(line_color)
                line_surface.set_alpha(decoration_alpha)
                SCREEN.blit(line_surface, (WIDTH // 2 - 150, HEIGHT // 2 - 80))
                SCREEN.blit(line_surface, (WIDTH // 2 - 150, HEIGHT // 2 - 20))
            else:
                draw.line(line_color[:3], (WIDTH // 2 - 150, HEIGHT // 2 - 80), (WIDTH // 2 + 150, HEIGHT // 2 - 80), 3)
                draw.line(line_color[:3], (WIDTH // 2 - 150, HEIGHT // 2 - 20), (WIDTH // 2 + 150, HEIGHT // 2 - 20), 3)
        pygame.display.flip()
        pygame.time.delay(25)
    # 대기 중 (SPACE 누를 때까지) - 애니메이션 효과 추가
    waiting = True
    frame_count = 0
    while waiting:
        frame_count += 1
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        # 맥동하는 효과 (파랑~빨강 계통)
        pulse = abs(math.sin(frame_count * 0.03)) * 20
        stage_color = (255, min(255, 220 + int(pulse)), min(255, 220 + int(pulse)))
        # 파랑에서 빨강으로 변하는 맥동 효과
        red_component = min(255, 120 + int(pulse * 1.5))
        blue_component = max(80, 200 - int(pulse))
        boss_color = (red_component, 100, blue_component)
        ui_manager.draw_centered_text("STAGE 1", 56, -120, stage_color, "elegant")
        ui_manager.draw_centered_text("풍악보이", 42, -50, boss_color, "glow")
        # 장식 라인 (맥동 효과)
        line_intensity = 160 + int(pulse)
        line_color = (min(255, line_intensity + 60), line_intensity, line_intensity)
        draw.line(line_color, (WIDTH // 2 - 150, HEIGHT // 2 - 80), (WIDTH // 2 + 150, HEIGHT // 2 - 80), 3)
        draw.line(line_color, (WIDTH // 2 - 150, HEIGHT // 2 - 20), (WIDTH // 2 + 150, HEIGHT // 2 - 20), 3)
        # 부드러운 Space 키 안내
        if frame_count % 120 < 60:
            hint_font = pygame.font.Font("NanumSquareR.ttf", 18)
            hint_text = hint_font.render("Press SPACE to continue", True, (150, 150, 150))
            hint_rect = hint_text.get_rect(center=(WIDTH // 2, HEIGHT - 50))
            SCREEN.blit(hint_text, hint_rect)
        pygame.display.flip()
        pygame.time.delay(16)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE:
                waiting = False
    # 페이드 아웃 (더 부드럽게)
    for alpha in range(255, -1, -8):
        boss_img.set_alpha(alpha)
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        pygame.display.flip()
        pygame.time.delay(25)
def show_stage2_intro():
    try:
        boss_img = pygame.image.load("stage2.png")  # stage2 전용 이미지 필요
        boss_img = pygame.transform.scale(boss_img, (WIDTH, HEIGHT))
    except:
        boss_img = pygame.Surface((WIDTH, HEIGHT))
        boss_img.fill((0, 0, 70))  # 다른 색감으로 구분
    # 페이드 인 (더 부드럽게)
    for alpha in range(0, 256, 8):
        boss_img.set_alpha(alpha)
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        # 고급스러운 텍스트 렌더링 (파랑~빨강 계통)
        fade_pulse = alpha / 255.0 * 20
        red_component = min(255, 120 + int(fade_pulse * 1.5))
        blue_component = max(80, 200 - int(fade_pulse))
        boss_fade_color = (red_component, 100, blue_component)
        ui_manager.draw_centered_text("STAGE 2", 56, -120, (240, 220, 180), "elegant")
        ui_manager.draw_centered_text("악어장군", 42, -50, boss_fade_color, "glow")
        # 장식 요소 추가
        decoration_alpha = min(255, alpha + 50)
        if decoration_alpha > 0:
            # 상하 장식 라인
            line_color = (180, 160, 120, decoration_alpha)
            if decoration_alpha < 255:
                line_surface = pygame.Surface((300, 3), pygame.SRCALPHA)
                line_surface.fill(line_color)
                line_surface.set_alpha(decoration_alpha)
                SCREEN.blit(line_surface, (WIDTH // 2 - 150, HEIGHT // 2 - 80))
                SCREEN.blit(line_surface, (WIDTH // 2 - 150, HEIGHT // 2 - 20))
            else:
                draw.line(line_color[:3], (WIDTH // 2 - 150, HEIGHT // 2 - 80), (WIDTH // 2 + 150, HEIGHT // 2 - 80), 3)
                draw.line(line_color[:3], (WIDTH // 2 - 150, HEIGHT // 2 - 20), (WIDTH // 2 + 150, HEIGHT // 2 - 20), 3)
        pygame.display.flip()
        pygame.time.delay(25)
    # 대기 중 (SPACE 누를 때까지) - 애니메이션 효과 추가
    waiting = True
    frame_count = 0
    while waiting:
        frame_count += 1
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        # 맥동하는 효과 (파랑~빨강 계통)
        pulse = abs(math.sin(frame_count * 0.03)) * 20
        stage_color = (min(255, 240 + int(pulse)), min(255, 220 + int(pulse)), min(255, 180 + int(pulse)))
        # 파랑에서 빨강으로 변하는 맥동 효과
        red_component = min(255, 120 + int(pulse * 1.5))
        blue_component = max(80, 200 - int(pulse))
        boss_color = (red_component, 100, blue_component)
        ui_manager.draw_centered_text("STAGE 2", 56, -120, stage_color, "elegant")
        ui_manager.draw_centered_text("악어장군", 42, -50, boss_color, "glow")
        # 장식 라인 (맥동 효과)
        line_intensity = 180 + int(pulse)
        line_color = (min(255, line_intensity), max(0, line_intensity - 20), max(0, line_intensity - 60))
        draw.line(line_color, (WIDTH // 2 - 150, HEIGHT // 2 - 80), (WIDTH // 2 + 150, HEIGHT // 2 - 80), 3)
        draw.line(line_color, (WIDTH // 2 - 150, HEIGHT // 2 - 20), (WIDTH // 2 + 150, HEIGHT // 2 - 20), 3)
        # 부드러운 Space 키 안내 (하단에)
        if frame_count % 120 < 60:  # 깜박임 효과
            hint_font = pygame.font.Font("NanumSquareR.ttf", 18)
            hint_text = hint_font.render("Press SPACE to continue", True, (150, 150, 150))
            hint_rect = hint_text.get_rect(center=(WIDTH // 2, HEIGHT - 50))
            SCREEN.blit(hint_text, hint_rect)
        pygame.display.flip()
        pygame.time.delay(16)  # 60fps
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE:
                waiting = False
    # 페이드 아웃 (더 부드럽게)
    for alpha in range(255, -1, -8):
        boss_img.set_alpha(alpha)
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        pygame.display.flip()
        pygame.time.delay(25)
def show_stage3_intro():
    try:
        boss_img = pygame.image.load("stage3.png")
        boss_img = pygame.transform.scale(boss_img, (WIDTH, HEIGHT))
    except:
        boss_img = pygame.Surface((WIDTH, HEIGHT))
        boss_img.fill((255, 0, 255))
    # 페이드 인 (더 부드럽게)
    for alpha in range(0, 256, 8):
        boss_img.set_alpha(alpha)
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        # 고급스러운 텍스트 렌더링 (파랑~빨강 계통)
        fade_pulse = alpha / 255.0 * 20
        red_component = min(255, 120 + int(fade_pulse * 1.5))
        blue_component = max(80, 200 - int(fade_pulse))
        boss_fade_color = (red_component, 100, blue_component)
        ui_manager.draw_centered_text("STAGE 3", 56, -120, (255, 180, 255), "elegant")
        ui_manager.draw_centered_text("멘헤라걸", 42, -50, boss_fade_color, "glow")
        pygame.display.flip()
        pygame.time.delay(25)
    # 대기 중 (SPACE 누를 때까지) - 애니메이션 효과 추가
    waiting = True
    frame_count = 0
    while waiting:
        frame_count += 1
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        # 맥동하는 효과 (파랑~빨강 계통)
        pulse = abs(math.sin(frame_count * 0.03)) * 20
        stage_color = (255, min(255, 180 + int(pulse)), 255)
        # 파랑에서 빨강으로 변하는 맥동 효과
        red_component = min(255, 120 + int(pulse * 1.5))
        blue_component = max(80, 200 - int(pulse))
        boss_color = (red_component, 100, blue_component)
        ui_manager.draw_centered_text("STAGE 3", 56, -120, stage_color, "elegant")
        ui_manager.draw_centered_text("멘헤라걸", 42, -50, boss_color, "glow")
        # 장식 라인 (맥동 효과)
        line_intensity = 160 + int(pulse)
        line_color = (min(255, line_intensity), 100, min(255, line_intensity))
        draw.line(line_color, (WIDTH // 2 - 150, HEIGHT // 2 - 80), (WIDTH // 2 + 150, HEIGHT // 2 - 80), 3)
        draw.line(line_color, (WIDTH // 2 - 150, HEIGHT // 2 - 20), (WIDTH // 2 + 150, HEIGHT // 2 - 20), 3)
        # 부드러운 Space 키 안내
        if frame_count % 120 < 60:
            hint_font = pygame.font.Font("NanumSquareR.ttf", 18)
            hint_text = hint_font.render("Press SPACE to continue", True, (150, 150, 150))
            hint_rect = hint_text.get_rect(center=(WIDTH // 2, HEIGHT - 50))
            SCREEN.blit(hint_text, hint_rect)
        pygame.display.flip()
        pygame.time.delay(16)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE:
                waiting = False
    # 페이드 아웃 (더 부드럽게)
    for alpha in range(255, -1, -8):
        boss_img.set_alpha(alpha)
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        pygame.display.flip()
        pygame.time.delay(25)
def show_stage4_intro():
    try:
        boss_img = pygame.image.load("stage4.png")
        boss_img = pygame.transform.scale(boss_img, (WIDTH, HEIGHT))
    except:
        boss_img = pygame.Surface((WIDTH, HEIGHT))
        boss_img.fill((180, 120, 80))
    # 페이드 인 (더 부드럽게)
    for alpha in range(0, 256, 8):
        boss_img.set_alpha(alpha)
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        # 고급스러운 텍스트 렌더링 (파랑~빨강 계통)
        fade_pulse = alpha / 255.0 * 20
        red_component = min(255, 120 + int(fade_pulse * 1.5))
        blue_component = max(80, 200 - int(fade_pulse))
        boss_fade_color = (red_component, 100, blue_component)
        ui_manager.draw_centered_text("STAGE 4", 56, -120, (255, 240, 200), "elegant")
        ui_manager.draw_centered_text("퐁크", 42, -50, boss_fade_color, "glow")
        pygame.display.flip()
        pygame.time.delay(25)
    # 대기 중 (SPACE 누를 때까지) - 애니메이션 효과 추가
    waiting = True
    frame_count = 0
    while waiting:
        frame_count += 1
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        # 맥동하는 효과 (파랑~빨강 계통)
        pulse = abs(math.sin(frame_count * 0.03)) * 20
        stage_color = (255, min(255, 240 + int(pulse)), min(255, 200 + int(pulse)))
        # 파랑에서 빨강으로 변하는 맥동 효과
        red_component = min(255, 120 + int(pulse * 1.5))
        blue_component = max(80, 200 - int(pulse))
        boss_color = (red_component, 100, blue_component)
        ui_manager.draw_centered_text("STAGE 4", 56, -120, stage_color, "elegant")
        ui_manager.draw_centered_text("퐁크", 42, -50, boss_color, "glow")
        # 장식 라인 (맥동 효과)
        line_intensity = 160 + int(pulse)
        line_color = (min(255, line_intensity + 30), min(255, line_intensity), max(100, line_intensity - 30))
        draw.line(line_color, (WIDTH // 2 - 150, HEIGHT // 2 - 80), (WIDTH // 2 + 150, HEIGHT // 2 - 80), 3)
        draw.line(line_color, (WIDTH // 2 - 150, HEIGHT // 2 - 20), (WIDTH // 2 + 150, HEIGHT // 2 - 20), 3)
        # 부드러운 Space 키 안내
        if frame_count % 120 < 60:
            hint_font = pygame.font.Font("NanumSquareR.ttf", 18)
            hint_text = hint_font.render("Press SPACE to continue", True, (150, 150, 150))
            hint_rect = hint_text.get_rect(center=(WIDTH // 2, HEIGHT - 50))
            SCREEN.blit(hint_text, hint_rect)
        pygame.display.flip()
        pygame.time.delay(16)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE:
                waiting = False
    # 페이드 아웃 (더 부드럽게)
    for alpha in range(255, -1, -8):
        boss_img.set_alpha(alpha)
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        pygame.display.flip()
        pygame.time.delay(25)
def show_stage5_intro():
    try:
        boss_img = pygame.image.load("stage5.png")
        boss_img = pygame.transform.scale(boss_img, (WIDTH, HEIGHT))
    except:
        boss_img = pygame.Surface((WIDTH, HEIGHT))
        boss_img.fill((180, 40, 0))
    # 페이드 인 (더 부드럽게)
    for alpha in range(0, 256, 8):
        boss_img.set_alpha(alpha)
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        # 고급스러운 텍스트 렌더링 (파랑~빨강 계통)
        fade_pulse = alpha / 255.0 * 20
        red_component = min(255, 120 + int(fade_pulse * 1.5))
        blue_component = max(80, 200 - int(fade_pulse))
        boss_fade_color = (red_component, 100, blue_component)
        ui_manager.draw_centered_text("STAGE 5", 56, -120, (255, 150, 100), "elegant")
        ui_manager.draw_centered_text("홍련", 42, -50, boss_fade_color, "glow")
        pygame.display.flip()
        pygame.time.delay(25)
    # 대기 중 (SPACE 누를 때까지) - 애니메이션 효과 추가
    waiting = True
    frame_count = 0
    while waiting:
        frame_count += 1
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        # 맥동하는 효과 (파랑~빨강 계통)
        pulse = abs(math.sin(frame_count * 0.03)) * 20
        stage_color = (255, min(255, 150 + int(pulse)), min(255, 100 + int(pulse)))
        # 파랑에서 빨강으로 변하는 맥동 효과
        red_component = min(255, 120 + int(pulse * 1.5))
        blue_component = max(80, 200 - int(pulse))
        boss_color = (red_component, 100, blue_component)
        ui_manager.draw_centered_text("STAGE 5", 56, -120, stage_color, "elegant")
        ui_manager.draw_centered_text("홍련", 42, -50, boss_color, "glow")
        # 장식 라인 (맥동 효과)
        line_intensity = 160 + int(pulse)
        line_color = (min(255, line_intensity + 50), max(50, line_intensity - 50), 50)
        draw.line(line_color, (WIDTH // 2 - 150, HEIGHT // 2 - 80), (WIDTH // 2 + 150, HEIGHT // 2 - 80), 3)
        draw.line(line_color, (WIDTH // 2 - 150, HEIGHT // 2 - 20), (WIDTH // 2 + 150, HEIGHT // 2 - 20), 3)
        # 부드러운 Space 키 안내
        if frame_count % 120 < 60:
            hint_font = pygame.font.Font("NanumSquareR.ttf", 18)
            hint_text = hint_font.render("Press SPACE to continue", True, (150, 150, 150))
            hint_rect = hint_text.get_rect(center=(WIDTH // 2, HEIGHT - 50))
            SCREEN.blit(hint_text, hint_rect)
        pygame.display.flip()
        pygame.time.delay(16)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE:
                waiting = False
    # 페이드 아웃 (더 부드럽게)
    for alpha in range(255, -1, -8):
        boss_img.set_alpha(alpha)
        SCREEN.fill(BLACK)
        SCREEN.blit(boss_img, (0, 0))
        pygame.display.flip()
        pygame.time.delay(25)
def draw_stage2_jungle_border():
    """스테이지 2 정글 테두리 그리기"""
    global stage2_border_timer, stage2_border_flash_timer
    # 기본 정글 테두리 (고정, 스테이지 1과 동일한 두께)
    if current_stage == 2:
        border_thickness = 10  # 스테이지 1과 동일한 두께
        # 기본 정글 색상 (진한 녹색 계열)
        base_green = (25, 51, 25)  # 매우 어두운 녹색 (베이스)
        jungle_green = (34, 70, 34)  # 어두운 녹색
        vine_green = (46, 87, 46)  # 덩굴 녹색
        highlight_green = (76, 122, 76)  # 하이라이트 녹색
        # 메인 테두리 (그라데이션 효과를 위한 레이어링)
        # 베이스 레이어
        draw.rect(base_green, (0, 0, WIDTH, border_thickness))
        draw.rect(base_green, (0, HEIGHT - border_thickness, WIDTH, border_thickness))
        draw.rect(base_green, (0, 0, border_thickness, HEIGHT))
        draw.rect(base_green, (WIDTH - border_thickness, 0, border_thickness, HEIGHT))
        # 내부 테두리 (더 밝은 색으로 깊이감 추가)
        inner_thickness = 2
        draw.rect(vine_green, (border_thickness - inner_thickness, border_thickness - inner_thickness, 
                                              WIDTH - 2*(border_thickness - inner_thickness), inner_thickness))
        draw.rect(vine_green, (border_thickness - inner_thickness, HEIGHT - border_thickness, 
                                              WIDTH - 2*(border_thickness - inner_thickness), inner_thickness))
        draw.rect(vine_green, (border_thickness - inner_thickness, border_thickness - inner_thickness, 
                                              inner_thickness, HEIGHT - 2*(border_thickness - inner_thickness)))
        draw.rect(vine_green, (WIDTH - border_thickness, border_thickness - inner_thickness, 
                                              inner_thickness, HEIGHT - 2*(border_thickness - inner_thickness)))
        # 테두리 장식 패턴 (정글 느낌)
        # 나뭇가지 패턴
        for i in range(0, WIDTH, 30):
            # 상단 나뭇가지
            draw.line(jungle_green, (i, 2), (i + 15, 8), 1)
            draw.line(jungle_green, (i + 15, 2), (i, 8), 1)
            # 하단 나뭇가지
            draw.line(jungle_green, (i, HEIGHT - 8), (i + 15, HEIGHT - 2), 1)
            draw.line(jungle_green, (i + 15, HEIGHT - 8), (i, HEIGHT - 2), 1)
        for i in range(0, HEIGHT, 30):
            # 좌측 나뭇가지
            draw.line(jungle_green, (2, i), (8, i + 15), 1)
            draw.line(jungle_green, (2, i + 15), (8, i), 1)
            # 우측 나뭇가지
            draw.line(jungle_green, (WIDTH - 8, i), (WIDTH - 2, i + 15), 1)
            draw.line(jungle_green, (WIDTH - 8, i + 15), (WIDTH - 2, i), 1)
        # 코너 장식 (덩굴 매듭)
        corner_radius = 4
        # 좌상단
        draw.circle(highlight_green, (border_thickness//2, border_thickness//2), corner_radius)
        # 우상단
        draw.circle(highlight_green, (WIDTH - border_thickness//2, border_thickness//2), corner_radius)
        # 좌하단
        draw.circle(highlight_green, (border_thickness//2, HEIGHT - border_thickness//2), corner_radius)
        # 우하단
        draw.circle(highlight_green, (WIDTH - border_thickness//2, HEIGHT - border_thickness//2), corner_radius)
        # 벽 충돌 시 깜빡임 효과
        if stage2_border_flash_timer > 0:
            flash_alpha = stage2_border_flash_timer / stage2_border_flash_duration
            flash_color = (
                int(100 + 155 * flash_alpha),
                int(200 + 55 * flash_alpha), 
                int(100 + 155 * flash_alpha)
            )
            # 테두리 하이라이트 (스테이지 1과 동일한 두께)
            draw.rect(flash_color, (0, 0, WIDTH, border_thickness), 0)
            draw.rect(flash_color, (0, HEIGHT - border_thickness, WIDTH, border_thickness), 0)
            draw.rect(flash_color, (0, 0, border_thickness, HEIGHT), 0)
            draw.rect(flash_color, (WIDTH - border_thickness, 0, border_thickness, HEIGHT), 0)
            stage2_border_flash_timer -= 1
def update_stage2_leaves():
    """떨어지는 잎사귀 업데이트"""
    global stage2_leaves
    new_leaves = []
    for leaf in stage2_leaves:
        # 물리 업데이트
        leaf['x'] += leaf['vx']
        leaf['y'] += leaf['vy']
        leaf['vy'] += 0.1  # 중력
        leaf['rotation'] += leaf['rotation_speed']
        leaf['life'] -= 1
        # 화면 안에 있고 수명이 남은 잎사귀만 유지
        if leaf['life'] > 0 and leaf['y'] < HEIGHT + 50:
            new_leaves.append(leaf)
    stage2_leaves = new_leaves
def draw_stage2_leaves():
    """떨어지는 잎사귀 그리기 (디테일한 버전)"""
    for leaf in stage2_leaves:
        # 투명도 계산 (페이드 아웃 효과)
        alpha = min(255, leaf['life'] * 2)
        # 잎사귀 그리기 (회전 적용)
        leaf_surface = pygame.Surface((leaf['size'] * 3, leaf['size'] * 3), pygame.SRCALPHA)
        center = leaf['size'] * 1.5
        # 잎사귀 종류별로 다른 모양 그리기 (항상 디테일한 버전만 사용)
        leaf_type = leaf.get('type', 'tropical')  # 기본값을 tropical로 설정
        if leaf_type == 'maple':
            # 단풍잎 모양 (5개 끝)
            points = []
            for i in range(10):
                angle = leaf['rotation'] + i * 36
                rad = math.radians(angle)
                if i % 2 == 0:
                    length = leaf['size']
                else:
                    length = leaf['size'] * 0.5
                points.append((center + math.cos(rad) * length,
                             center + math.sin(rad) * length))
            pygame.draw.polygon(leaf_surface, (*leaf['color'], alpha), points)
        elif leaf_type == 'oak':
            # 물결 모양 타원 (참나무잎)
            for i in range(3):
                offset = i * 2
                pygame.draw.ellipse(leaf_surface, (*leaf['color'], max(0, alpha - i * 50)),
                                  (center - leaf['size']//2 + offset, 
                                   center - leaf['size'] + offset,
                                   leaf['size'] - offset * 2, 
                                   leaf['size'] * 2 - offset * 2))
        else:  # tropical 또는 기타
            # 열대 잎 (뾰족한 타원)
            points = [
                (center, center - leaf['size'] * 1.2),
                (center + leaf['size'] * 0.4, center),
                (center, center + leaf['size'] * 1.2),
                (center - leaf['size'] * 0.4, center)
            ]
            pygame.draw.polygon(leaf_surface, (*leaf['color'], alpha), points)
        # 잎맥 추가
        vein_color = tuple(max(0, c - 40) for c in leaf['color']) + (alpha//2,)
        pygame.draw.line(leaf_surface, vein_color,
                        (center, center - leaf['size']), 
                        (center, center + leaf['size']), 1)
        # 회전 적용
        rotated_leaf = pygame.transform.rotate(leaf_surface, leaf['rotation'])
        leaf_rect = rotated_leaf.get_rect(center=(int(leaf['x']), int(leaf['y'])))
        SCREEN.blit(rotated_leaf, leaf_rect)
def draw_field():
    global psycho_bg_timer
    if current_stage == 3 and emotional_overdrive_active:
        # 깜빡이거나 색 바뀌는 배경
        psycho_bg_timer += 1
        if psycho_bg_timer % 35 < 15:
            # 밝은 보라색 계열
            SCREEN.fill((255, 100, 255))
        else:
            # 어두운 남보라 계열
            SCREEN.fill((100, 0, 150))
        # 또는 완전 무작위 컬러 배경 효과 (좀 더 강한 사이코 느낌)
        # random_color = (random.randint(100,255), random.randint(0,100), random.randint(100,255))
        # SCREEN.fill(random_color)
    elif current_stage == 1 and animated_bg is not None:
        # 스테이지1에서는 애니메이션 배경 사용
        animated_bg.update(clock.get_time())
        if FULLSCREEN_MODE:
            SCREEN.fill((0, 0, 0))
            temp_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            animated_bg.draw(temp_surface)
            SCREEN.blit(temp_surface, (GAME_OFFSET_X + screen_shake_offset_x, GAME_OFFSET_Y + screen_shake_offset_y))
        else:
            animated_bg.draw(SCREEN)
    elif current_stage == 2 and animated_bg_stage2 is not None:
        # 스테이지2에서는 정글 사이버펑크 애니메이션 배경 사용
        # 공 위치, 패들 위치, 점수를 배경에 전달 (눈동자 추적 + 덤불 흔들림 + 위기 상황용)
        animated_bg_stage2.update(clock.get_time(), BALL.centerx, BALL.centery, 
                                BOSS.centerx, PLAYER.centerx, round_wins, round_losses)
        # 🌋 정글 지진 효과 (스테이지 2 전용)
        earthquake_offset_x, earthquake_offset_y = animated_bg_stage2.get_earthquake_offset()
        if FULLSCREEN_MODE:
            SCREEN.fill((0, 0, 0))
            temp_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            animated_bg_stage2.draw(temp_surface)
            SCREEN.blit(temp_surface, (GAME_OFFSET_X + screen_shake_offset_x + earthquake_offset_x, 
                                     GAME_OFFSET_Y + screen_shake_offset_y + earthquake_offset_y))
        else:
            animated_bg_stage2.draw(SCREEN)
    elif current_stage == 3 and animated_bg_stage3 is not None and not emotional_overdrive_active:
        # 스테이지3에서는 멘헤라 사이버펑크 애니메이션 배경 사용 (감정 폭주 시 제외)
        animated_bg_stage3.update(clock.get_time())
        if FULLSCREEN_MODE:
            SCREEN.fill((0, 0, 0))
            temp_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            animated_bg_stage3.draw(temp_surface)
            SCREEN.blit(temp_surface, (GAME_OFFSET_X + screen_shake_offset_x, GAME_OFFSET_Y + screen_shake_offset_y))
        else:
            animated_bg_stage3.draw(SCREEN)
    elif current_stage == 4 and animated_bg_stage4 is not None:
        # 스테이지4에서는 몽크 수도 사이버펑크 애니메이션 배경 사용
        animated_bg_stage4.update(clock.get_time())
        if FULLSCREEN_MODE:
            SCREEN.fill((0, 0, 0))
            temp_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            animated_bg_stage4.draw(temp_surface)
            SCREEN.blit(temp_surface, (GAME_OFFSET_X + screen_shake_offset_x, GAME_OFFSET_Y + screen_shake_offset_y))
        else:
            animated_bg_stage4.draw(SCREEN)
    elif current_stage == 5 and animated_bg_stage5 is not None:
        # 스테이지5에서는 중국 전통 화염 꽃 애니메이션 배경 사용
        animated_bg_stage5.update(clock.get_time())
        if FULLSCREEN_MODE:
            SCREEN.fill((0, 0, 0))
            temp_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            animated_bg_stage5.draw(temp_surface)
            SCREEN.blit(temp_surface, (GAME_OFFSET_X + screen_shake_offset_x, GAME_OFFSET_Y + screen_shake_offset_y))
        else:
            animated_bg_stage5.draw(SCREEN)
    else:
        # 기본 배경 (화면 흔들림 오프셋 적용)
        if FULLSCREEN_MODE:
            # 전체화면 모드일 때는 검은 배경으로 채우고 게임 화면을 중앙에 배치
            SCREEN.fill((0, 0, 0))
            SCREEN.blit(CURRENT_BG, (GAME_OFFSET_X + screen_shake_offset_x, GAME_OFFSET_Y + screen_shake_offset_y))
        else:
            # 창모드일 때 화면 흔들림 효과 적용
            SCREEN.blit(CURRENT_BG, (screen_shake_offset_x, screen_shake_offset_y))
    # 💪 체력형 보스전 바리케이트 그리기
    if current_stage in boss_health_stages:
        barrier_height = 8
        barrier_y = 0
        # 바리케이트 기본 색상 (전기 청색)
        barrier_color = (50, 150, 255)
        # 애니메이션 효과 (깜빡임)
        time_now = pygame.time.get_ticks()
        pulse = abs(math.sin(time_now * 0.01)) * 0.5 + 0.5
        # 메인 바리케이트 바
        for i in range(0, WIDTH, 20):
            bar_width = 15
            # 바리케이트 그라데이션 효과
            for y_offset in range(barrier_height):
                intensity = 1.0 - (y_offset / barrier_height) * 0.6
                color = (
                    int(barrier_color[0] * intensity),
                    int(barrier_color[1] * intensity), 
                    int(barrier_color[2] * intensity)
                )
                draw.rect(color, (i, barrier_y + y_offset, bar_width, 1))
            # 전기 스파크 효과 (랜덤)
            if random.random() < 0.1:
                spark_x = i + random.randint(0, bar_width)
                spark_y = barrier_y + random.randint(0, barrier_height)
                draw.circle((255, 255, 255), (spark_x, spark_y), 1)
        # 바리케이트 경고 텍스트 (중앙에 작게)
        try:
            font_barrier = pygame.font.Font("NanumSquareR.ttf", 12)
        except:
            font_barrier = pygame.font.Font(None, 12)
        barrier_text = font_barrier.render("⚡ ENERGY BARRIER ⚡", True, (255, 255, 255))
        text_rect = barrier_text.get_rect(center=(WIDTH // 2, barrier_height + 15))
        # 텍스트 그림자
        shadow_text = font_barrier.render("⚡ ENERGY BARRIER ⚡", True, (0, 0, 0))
        SCREEN.blit(shadow_text, (text_rect.x + 1, text_rect.y + 1))
        SCREEN.blit(barrier_text, text_rect)
def check_deuce_system():
    """핑파이터 스타일 듀스 시스템을 체크하고 업데이트합니다."""
    global deuce_mode, deuce_wins, deuce_losses, deuce_goal
    # 듀스 조건: 2:2 동점
    if round_wins == 2 and round_losses == 2 and not deuce_mode:
        deuce_mode = True
        deuce_wins = 2  # 2:2 상태를 유지
        deuce_losses = 2  # 2:2 상태를 유지
        deuce_goal = 4  # 첫 번째 듀스는 4점
        show_fade_text("DEUCE!")
        print("듀스 모드 시작!")
        return "deuce_started"
    # 듀스 모드에서 3:3 동점이 되면 듀스 재시작 (5점으로)
    if deuce_mode and deuce_wins == 3 and deuce_losses == 3:
        deuce_wins = 3  # 3:3 상태를 유지
        deuce_losses = 3  # 3:3 상태를 유지
        deuce_goal = 5  # 두 번째 듀스는 5점
        show_fade_text("DEUCE!")
        print("듀스 재시작! (5점 목표)")
        return "deuce_restart"
    # 듀스 모드에서 승리 조건 체크
    if deuce_mode:
        if deuce_wins >= deuce_goal:
            # 승부 결과 기록 (듀스)
            record_victory_result(deuce_wins, deuce_losses)
            return "player_win"
        elif deuce_losses >= deuce_goal:
            # 듀스 패배 결과 기록 (감점)
            record_victory_result(deuce_wins, deuce_losses)
            return "boss_win"
    # 일반 모드에서 승리 조건 체크
    else:
        if round_wins >= win_goal:
            # 승부 결과 기록 (일반)
            record_victory_result(round_wins, round_losses)
            return "player_win"
        elif round_losses >= win_goal:
            # 패배 결과 기록 (감점)
            record_victory_result(round_wins, round_losses)
            return "boss_win"
    return "continue"
def draw_score():
    if deuce_mode:
        # 듀스 모드일 때 듀스 점수 표시
        score_text = f"{deuce_wins} : {deuce_losses}"
        font_large = pygame.font.SysFont("Arial", 60, bold=True)
        font_deuce = pygame.font.SysFont("Arial", 24, bold=True)
        # 듀스 표시
        deuce_text = f"DEUCE (First to {deuce_goal})"
        deuce_color = (255, 255, 100)  # 밝은 노란색으로 강조
        # 듀스 텍스트 그리기 (점수 위에) - 기존 "~win" UI와 통일감 있게
        for dx, dy in [(-2, -2), (2, -2), (-2, 2), (2, 2)]:
            shadow = font_deuce.render(deuce_text, True, (80, 80, 0))
            SCREEN.blit(shadow, (WIDTH // 2 - shadow.get_width() // 2 + dx, 30 + dy))
        neon_deuce = font_deuce.render(deuce_text, True, deuce_color)
        SCREEN.blit(neon_deuce, (WIDTH // 2 - neon_deuce.get_width() // 2, 30))
        # 듀스 점수 그리기 (듀스 모드에서는 노란색으로 강조 - "~win" UI와 통일감)
        for dx, dy in [(-2, -2), (2, -2), (-2, 2), (2, 2)]:
            shadow = font_large.render(score_text, True, (100, 100, 0))
            SCREEN.blit(shadow, (WIDTH // 2 - shadow.get_width() // 2 + dx, 60 + dy))
        neon = font_large.render(score_text, True, (255, 255, 100))
        SCREEN.blit(neon, (WIDTH // 2 - neon.get_width() // 2, 60))
    else:
        # 일반 모드
        score_text = f"{round_wins} : {round_losses}"
        font_large = pygame.font.SysFont("Arial", 60, bold=True)
        for dx, dy in [(-2, -2), (2, -2), (-2, 2), (2, 2)]:
            shadow = font_large.render(score_text, True, (0, 100, 100))
            SCREEN.blit(shadow, (WIDTH // 2 - shadow.get_width() // 2 + dx, 60 + dy))
        neon = font_large.render(score_text, True, (0, 255, 255))
        SCREEN.blit(neon, (WIDTH // 2 - neon.get_width() // 2, 60))
def draw_laser_cannon_gauge():
    """⚡ 레이저 캐논 쿨타임 게이지바 (야마토포 스타일)"""
    if current_stage != 6:
        return
    # 체력이 60% 이하일 때만 표시
    health_percent = (boss_current_health / boss_max_health) * 100
    if health_percent > 60:
        return
    current_time = pygame.time.get_ticks()
    # 게이지바 크기와 위치 (오른쪽 상단)
    gauge_width = 150
    gauge_height = 20
    gauge_x = WIDTH - gauge_width - 20
    gauge_y = 20
    # === 메카닉 프레임 ===
    frame_color = (100, 110, 120)
    dark_frame = (40, 45, 50)
    # 외곽 프레임 (경사진 모서리)
    frame_points = [
        (gauge_x - 3, gauge_y - 3),
        (gauge_x, gauge_y - 5),
        (gauge_x + gauge_width, gauge_y - 5),
        (gauge_x + gauge_width + 3, gauge_y - 3),
        (gauge_x + gauge_width + 3, gauge_y + gauge_height + 3),
        (gauge_x + gauge_width, gauge_y + gauge_height + 5),
        (gauge_x, gauge_y + gauge_height + 5),
        (gauge_x - 3, gauge_y + gauge_height + 3)
    ]
    draw.polygon(frame_color, frame_points)
    draw.polygon((20, 25, 30), frame_points, 2)
    # 내부 배경 (다크 그레이)
    bg_rect = pygame.Rect(gauge_x, gauge_y, gauge_width, gauge_height)
    draw.rect((10, 12, 15), bg_rect)
    # 그리드 패턴
    for i in range(0, gauge_width, 15):
        draw.line((20, 25, 30),
                        (gauge_x + i, gauge_y),
                        (gauge_x + i, gauge_y + gauge_height), 1)
    # === 쿨타임/충전 게이지 ===
    if laser_charging:
        # 충전 중 (빨간색 경고)
        charge_progress = min(1.0, (current_time - laser_charge_start) / 1500)
        fill_width = int(gauge_width * charge_progress)
        # 충전 바 (빨간색 그라데이션)
        for i in range(gauge_height):
            alpha = 1.0 - (i / gauge_height) * 0.4
            pulse = abs(math.sin(current_time * 0.01)) * 0.3 + 0.7
            color = (int(255 * alpha * pulse), int(50 * alpha), int(50 * alpha))
            draw.line(color,
                           (gauge_x, gauge_y + i),
                           (gauge_x + fill_width, gauge_y + i))
        # 경고 텍스트
        try:
            warning_font = pygame.font.Font("NanumSquareR.ttf", 14)
        except:
            warning_font = pygame.font.Font(None, 14)
        warning_text = warning_font.render("CHARGING", True, (255, 100, 100))
        text_x = gauge_x + (gauge_width - warning_text.get_width()) // 2
        text_y = gauge_y + (gauge_height - warning_text.get_height()) // 2
        SCREEN.blit(warning_text, (text_x, text_y))
    elif laser_cannon_active:
        # 레이저 발사 중 (파란색)
        beam_progress = 1.0 - min(1.0, (current_time - last_laser_time) / laser_beam_duration)
        fill_width = int(gauge_width * beam_progress)
        # 빔 바 (파란색 플라즈마)
        for i in range(gauge_height):
            alpha = 1.0 - (i / gauge_height) * 0.4
            pulse = abs(math.sin(current_time * 0.02)) * 0.3 + 0.7
            color = (int(100 * alpha), int(150 * alpha * pulse), int(255 * alpha * pulse))
            draw.line(color,
                           (gauge_x, gauge_y + i),
                           (gauge_x + fill_width, gauge_y + i))
        # 발사 텍스트
        try:
            fire_font = pygame.font.Font("NanumSquareR.ttf", 14)
        except:
            fire_font = pygame.font.Font(None, 14)
        fire_text = fire_font.render("FIRING", True, (100, 200, 255))
        text_x = gauge_x + (gauge_width - fire_text.get_width()) // 2
        text_y = gauge_y + (gauge_height - fire_text.get_height()) // 2
        SCREEN.blit(fire_text, (text_x, text_y))
    else:
        # 쿨타임 중 (녹색 충전)
        cooldown_progress = min(1.0, (current_time - last_laser_time) / 5000)
        fill_width = int(gauge_width * cooldown_progress)
        # 쿨타임 바 (녹색 그라데이션)
        for i in range(gauge_height):
            alpha = 1.0 - (i / gauge_height) * 0.4
            if cooldown_progress >= 1.0:
                # 준비 완료 (밝은 녹색)
                pulse = abs(math.sin(current_time * 0.005)) * 0.3 + 0.7
                color = (int(50 * alpha), int(255 * alpha * pulse), int(100 * alpha))
            else:
                # 충전 중 (어두운 녹색)
                color = (int(30 * alpha), int(100 * alpha), int(50 * alpha))
            draw.line(color,
                           (gauge_x, gauge_y + i),
                           (gauge_x + fill_width, gauge_y + i))
        # 준비 상태 표시
        if cooldown_progress >= 1.0:
            try:
                ready_font = pygame.font.Font("NanumSquareR.ttf", 14)
            except:
                ready_font = pygame.font.Font(None, 14)
            ready_text = ready_font.render("READY", True, (50, 255, 100))
            text_x = gauge_x + (gauge_width - ready_text.get_width()) // 2
            text_y = gauge_y + (gauge_height - ready_text.get_height()) // 2
            SCREEN.blit(ready_text, (text_x, text_y))
    # === 레이벨 ===
    # YAMATO 텍스트 (왼쪽)
    try:
        label_font = pygame.font.Font("NanumSquareR.ttf", 12)
    except:
        label_font = pygame.font.Font(None, 12)
    label_text = label_font.render("YAMATO", True, (150, 160, 170))
    SCREEN.blit(label_text, (gauge_x - label_text.get_width() - 5, gauge_y))
    # 전력 아이콘 (오른쪽)
    icon_x = gauge_x + gauge_width + 8
    icon_y = gauge_y + gauge_height // 2
    # 번개 모양 아이콘
    pygame.draw.lines(SCREEN, (100, 150, 200), False,
                     [(icon_x, icon_y - 5), (icon_x + 3, icon_y), 
                      (icon_x - 2, icon_y + 2), (icon_x + 5, icon_y + 5)], 2)
def draw_boss_health_bar():
    """🎯 메카닉 스타일 보스 체력바 (스무스 애니메이션)"""
    global boss_displayed_health, boss_damage_preview_health
    if current_stage not in boss_health_stages:
        return
    # 스무스한 체력 감소 애니메이션
    if boss_displayed_health > boss_current_health:
        boss_displayed_health -= 0.3  # 부드럽게 감소
        if boss_displayed_health < boss_current_health:
            boss_displayed_health = boss_current_health
    # 데미지 프리뷰 감소 (더 느리게)
    if boss_damage_preview_health > boss_current_health:
        boss_damage_preview_health -= 0.15
        if boss_damage_preview_health < boss_current_health:
            boss_damage_preview_health = boss_current_health
    # 보스 패들 위치에 맞춰 체력바 위치 계산
    health_bar_x = BOSS.centerx - boss_health_bar_width // 2
    health_bar_y = BOSS.bottom + 35
    # === 메카닉 스타일 프레임 ===
    # 외곽 메탈 프레임
    frame_color = (120, 130, 140)
    dark_frame = (60, 65, 70)
    # 메인 프레임 (경사진 모서리)
    frame_points = [
        (health_bar_x - 5, health_bar_y),
        (health_bar_x - 2, health_bar_y - 3),
        (health_bar_x + boss_health_bar_width + 2, health_bar_y - 3),
        (health_bar_x + boss_health_bar_width + 5, health_bar_y),
        (health_bar_x + boss_health_bar_width + 5, health_bar_y + boss_health_bar_height),
        (health_bar_x + boss_health_bar_width + 2, health_bar_y + boss_health_bar_height + 3),
        (health_bar_x - 2, health_bar_y + boss_health_bar_height + 3),
        (health_bar_x - 5, health_bar_y + boss_health_bar_height)
    ]
    draw.polygon(frame_color, frame_points)
    draw.polygon(dark_frame, frame_points, 2)
    # 내부 배경 (다크 그레이 + 그리드 패턴)
    bg_rect = pygame.Rect(health_bar_x, health_bar_y, boss_health_bar_width, boss_health_bar_height)
    draw.rect((20, 25, 30), bg_rect)
    # 그리드 라인 (메카닉 느낌)
    for i in range(0, boss_health_bar_width, 20):
        draw.line((30, 35, 40), 
                        (health_bar_x + i, health_bar_y), 
                        (health_bar_x + i, health_bar_y + boss_health_bar_height), 1)
    # === 체력 표시 ===
    # 데미지 프리뷰 (빨간색 잔상)
    if boss_damage_preview_health > boss_current_health:
        preview_ratio = boss_damage_preview_health / boss_max_health
        preview_width = int(boss_health_bar_width * preview_ratio)
        preview_rect = pygame.Rect(health_bar_x, health_bar_y, preview_width, boss_health_bar_height)
        draw.rect((100, 30, 30), preview_rect)
    # 메인 체력바 (스무스 애니메이션)
    if boss_displayed_health > 0:
        display_ratio = boss_displayed_health / boss_max_health
        current_width = int(boss_health_bar_width * display_ratio)
        # 체력 색상 (그라데이션)
        if display_ratio > 0.6:
            # 청록색 메카닉 스타일
            health_color = (0, 200, 180)
            glow_color = (0, 255, 220)
        elif display_ratio > 0.3:
            # 노란색 경고
            health_color = (200, 180, 0)
            glow_color = (255, 220, 0)
        else:
            # 빨간색 위험
            health_color = (200, 50, 50)
            glow_color = (255, 100, 100)
        # 메인 체력 그라데이션
        for i in range(boss_health_bar_height):
            alpha = 1.0 - (i / boss_health_bar_height) * 0.3
            color = tuple(int(c * alpha) for c in health_color)
            draw.line(color,
                           (health_bar_x, health_bar_y + i),
                           (health_bar_x + current_width - 1, health_bar_y + i))
        # 체력바 끝 부분 하이라이트 (펄스 효과)
        pulse = abs(math.sin(pygame.time.get_ticks() * 0.005))
        highlight_width = 3
        if current_width > highlight_width:
            for i in range(highlight_width):
                alpha = (1.0 - i / highlight_width) * pulse
                highlight_color = tuple(int(c * (0.7 + alpha * 0.3)) for c in glow_color)
                draw.line(highlight_color,
                               (health_bar_x + current_width - highlight_width + i, health_bar_y),
                               (health_bar_x + current_width - highlight_width + i, health_bar_y + boss_health_bar_height - 1))
    # === 디지털 수치 표시 ===
    # HP 라벨 (왼쪽)
    font_label = pygame.font.SysFont("Courier", 10, bold=True)
    hp_label = font_label.render("HP", True, (150, 160, 170))
    SCREEN.blit(hp_label, (health_bar_x - 20, health_bar_y - 1))
    # 체력 수치 (오른쪽, 디지털 스타일)
    font_digital = pygame.font.SysFont("Courier", 11, bold=True)
    hp_text = f"{int(boss_displayed_health):02d}/{boss_max_health:02d}"
    # 디지털 디스플레이 배경
    text_bg_x = health_bar_x + boss_health_bar_width + 10
    text_bg_rect = pygame.Rect(text_bg_x, health_bar_y - 2, 45, boss_health_bar_height + 4)
    draw.rect((30, 35, 40), text_bg_rect)
    draw.rect((60, 65, 70), text_bg_rect, 1)
    # 디지털 텍스트 (청록색 글로우)
    hp_surface = font_digital.render(hp_text, True, (0, 255, 200))
    SCREEN.blit(hp_surface, (text_bg_x + 3, health_bar_y))
    # === 위험 경고 효과 ===
    if boss_current_health <= 3:
        # 낮은 체력 경고 (빨간색 점멸)
        warning_alpha = int(abs(math.sin(pygame.time.get_ticks() * 0.01)) * 100)
        warning_surface = pygame.Surface((boss_health_bar_width + 10, boss_health_bar_height + 10), pygame.SRCALPHA)
        pygame.draw.rect(warning_surface, (255, 0, 0, warning_alpha), 
                        (0, 0, boss_health_bar_width + 10, boss_health_bar_height + 10), 2)
        SCREEN.blit(warning_surface, (health_bar_x - 5, health_bar_y - 5))
def show_fade_text(message):
    """깔끔하고 미니멀한 인게임 텍스트 애니메이션"""
    # 메시지 타입 분석
    is_serve_message = "서브" in message
    is_power_smashing = "파워스매싱" in message
    is_deuce = "듀스" in message
    is_special_skill = any(skill in message for skill in ["드라이브", "상모돌리기", "사이코볼", "홍련폭염"])
    # 🎨 깔끔한 스타일 설정
    if is_serve_message:
        if "플레이어" in message:
            font_size = 48
            main_color = (255, 255, 255)
            accent_color = (0, 200, 100)
            display_text = "Player Serve"
        else:
            font_size = 48
            main_color = (255, 255, 255)
            accent_color = (200, 80, 80)
            boss_name = boss_names.get(current_stage, "Boss")
            display_text = f"{boss_name} Serve"
    elif is_power_smashing:
        font_size = 56
        main_color = (255, 255, 255)
        accent_color = (255, 200, 0)
        display_text = "POWER SMASHING"
    elif is_deuce:
        font_size = 52
        main_color = (255, 255, 255)
        accent_color = (180, 100, 255)
        display_text = message  # 듀스 메시지 그대로
    elif is_special_skill:
        font_size = 44
        main_color = (255, 255, 255)
        accent_color = (100, 200, 255)
        display_text = message  # 스킬 메시지 그대로
    else:
        font_size = 42
        main_color = (255, 255, 255)
        accent_color = (150, 150, 150)
        display_text = message
    # 🎵 효과음 재생
    if is_power_smashing:
        try:
            power_smash_sound = pygame.mixer.Sound("sounds/power_smash.wav")
            power_smash_sound.play()
        except:
            pass
    # 폰트 생성 (깔끔한 폰트)
    font_main = pygame.font.Font("NanumSquareB.ttf", font_size)
    text_surface = font_main.render(display_text, True, main_color)
    # 🌟 빠른 페이드인 (0.3초)
    for alpha in range(0, 256, 32):
        draw_field()
        draw_objects()
        # 반투명 오버레이
        overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, min(120, alpha)))
        SCREEN.blit(overlay, (0, 0))
        # 깔끔한 라인 디자인
        text_rect = text_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2))
        line_width = text_rect.width + 60
        line_y = text_rect.centery + text_rect.height // 2 + 10
        # 액센트 라인
        line_alpha = min(255, alpha + 50)
        line_surface = pygame.Surface((line_width, 4), pygame.SRCALPHA)
        line_surface.fill((*accent_color, line_alpha))
        SCREEN.blit(line_surface, ((WIDTH - line_width) // 2, line_y))
        # 메인 텍스트
        text_surface.set_alpha(alpha)
        SCREEN.blit(text_surface, text_rect)
        pygame.display.flip()
        pygame.time.delay(15)
    # 💫 유지 (0.8초)
    hold_duration = 800 if is_power_smashing else (600 if is_serve_message else (1000 if is_deuce else 500))
    start_time = pygame.time.get_ticks()
    while pygame.time.get_ticks() - start_time < hold_duration:
        draw_field()
        draw_objects()
        # 반투명 오버레이
        overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 120))
        SCREEN.blit(overlay, (0, 0))
        # 액센트 라인 (미세한 펄스)
        text_rect = text_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2))
        line_width = text_rect.width + 60
        line_y = text_rect.centery + text_rect.height // 2 + 10
        pulse = int(5 * math.sin((pygame.time.get_ticks() - start_time) * 0.01))
        line_surface = pygame.Surface((line_width + pulse, 4), pygame.SRCALPHA)
        line_surface.fill(accent_color)
        SCREEN.blit(line_surface, ((WIDTH - line_width - pulse) // 2, line_y))
        # 메인 텍스트
        SCREEN.blit(text_surface, text_rect)
        pygame.display.flip()
        pygame.time.delay(16)
    # 🌅 빠른 페이드아웃 (0.2초)
    for alpha in range(255, -1, -42):
        draw_field()
        draw_objects()
        # 반투명 오버레이
        overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, max(0, alpha // 2)))
        SCREEN.blit(overlay, (0, 0))
        # 액센트 라인
        text_rect = text_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2))
        line_width = text_rect.width + 60
        line_y = text_rect.centery + text_rect.height // 2 + 10
        line_surface = pygame.Surface((line_width, 4), pygame.SRCALPHA)
        line_surface.fill((*accent_color, max(0, alpha)))
        SCREEN.blit(line_surface, ((WIDTH - line_width) // 2, line_y))
        # 메인 텍스트
        text_surface.set_alpha(max(0, alpha))
        SCREEN.blit(text_surface, text_rect)
        pygame.display.flip()
        pygame.time.delay(10)
    # 🎵 파워스매싱 두 번째 효과음
    if is_power_smashing:
        try:
            power_smash_launch_sound = pygame.mixer.Sound("sounds/power_smash_launch.wav")
            power_smash_launch_sound.play()
        except:
            pass
# 물리 관련 함수들은 physics_manager로 이동됨
def reset_round():
    global special_active, special_ready, ball_trail, ball_vel, PLAYER_SPEED
    global quake_active, quake_timer, speed_defense_active, speed_defense_timer
    global horizontal_bounce_count, ball_angle, drive_active, drive_spin_speed
    global rolling_active, rolling_timer, rolling_direction, rolling_speed, rolling_stun_timer, rolling_dash_available_timer, rolling_cooldown, rolling_charges, rolling_charge_timer, rolling_consecutive_count  # 🆕 대쉬 관련 변수 추가
    global acceleration_active, acceleration_original_speed  # 🚀 가속화 스킬 변수 추가
    global deuce_mode, deuce_wins, deuce_losses, deuce_goal  # 🆕 듀스 시스템 변수 추가
    global horizontal_movement_timer  # 🛡️ 수평 움직임 타이머 리셋
    global ai_frame_counter  # 🧠 AI 프레임 카운터 리셋
    global drive_global_cooldown, last_space_press_time  # 🆕 강화된 연타 방지 변수들
    global whip_active, whip_timer, whip_hit_by_player, whip_original_ball_speed  # 🆕 상모돌리기 관련 변수 추가
    global emotional_overdrive_active, emotional_overdrive_timer, overdrive_flash_timer, overdrive_trails  # 🆕 사이코볼 관련 변수 추가
    global round_start_time  # 🆕 불꽃탄 지연 시간 관련 변수 추가
    global fire_zones, molotovs  # 🔥 화염병 관련 변수 추가
    global boss_fire_hit_count, boss_fire_hit_timer  # 💪 보스 화염 타격 카운터
    global border_flash_active, border_flash_timer  # 🎨 테두리 깜빡임 효과
    global stage2_border_flash_timer, stage2_leaves  # 🌿 스테이지 2 정글 효과
    # 테두리 깜빡임 효과 초기화
    border_flash_active = False
    border_flash_timer = 0
    # 스테이지 2 효과 초기화
    stage2_border_flash_timer = 0
    stage2_leaves = []
    # 패들 위치 초기화
    PLAYER.centerx = WIDTH // 2
    PLAYER.bottom = HEIGHT - 40
    BOSS.centerx = WIDTH // 2
    BOSS.top = 25
    # 공 리셋
    ball_vel = [0, 0]
    physics_manager.reset_ball(is_player_serve)
    # 🔥 라운드 시작 시간 초기화 (화염탄 2.5초 지연용)
    round_start_time = pygame.time.get_ticks()
    # 🔥 화염병 관련 초기화 (라운드 전환 시 화염 지대 제거)
    fire_zones.clear()  # 모든 화염 지대 제거
    molotovs.clear()    # 날아가는 화염병도 제거
    # 💣 수류탄 관련 초기화
    grenades.clear()  # 날아가는 수류탄 제거
    explosion_zones.clear()  # 폭발 지역 제거
    # 💡 조명탄(섬광탄) 관련 초기화
    global boss_confused_timer, flares, flare_zones
    boss_confused_timer = 0  # 보스 혼란 상태 초기화
    flares.clear()  # 날아가는 조명탄 제거
    flare_zones.clear()  # 섬광 지역 제거
    # 💪 체력형 보스 시스템 - 라운드마다 체력 유지 (초기화하지 않음)
    # 체력형 보스는 게임 시작시에만 체력이 초기화되고, 라운드마다는 유지됨
    # 화염 타격 카운터는 라운드마다 초기화하지 않음 (누적으로 계산)
    # 💨 연막탄 관련 초기화
    global smoke_grenades, smoke_zones
    smoke_grenades.clear()  # 날아가는 연막탄 제거
    smoke_zones.clear()  # 연막 지역 제거
    # 🛡️ 수평 움직임 타이머 리셋
    horizontal_movement_timer = 0
    # 🌟 드라이브 공 상태 리셋
    global drive_ball_active, drive_hit_boss, drive_just_activated, drive_speed_increase, ball_spin_strength, ball_spin_direction  # 🆕 스핀 상태도 포함
    drive_ball_active = False
    drive_hit_boss = False
    drive_just_activated = False  # 🆕 방법1: 플래그 리셋
    drive_speed_increase = 0.0    # 🆕 드라이브 속도 증가량 리셋
    # 🌪️ 스핀 상태 완전히 초기화 (라운드 시작 시 드라이브 효과 제거)
    ball_spin_strength = 0.0
    ball_spin_direction = 0
    # 🚀 파워스매싱 상태 리셋
    global power_smashing_direction, power_smashing_original_speed, power_smashing_parabola_active, power_smashing_start_time, power_smashing_arc_strength
    global power_smashing_trails, power_smashing_particles
    power_smashing_direction = None  # 파워스매싱 방향 리셋
    power_smashing_original_speed = 0.0  # 파워스매싱 원래 속도 리셋
    power_smashing_parabola_active = False  # 포물선 궤적 리셋
    power_smashing_start_time = 0
    power_smashing_arc_strength = 0.0
    power_smashing_trails.clear()  # 잔상 효과 리셋
    power_smashing_particles.clear()  # 파티클 효과 리셋
    # 파워스매싱 정지 시간 관련 변수 리셋
    global power_smashing_freeze_start_time, power_smashing_freeze_active
    power_smashing_freeze_start_time = 0
    power_smashing_freeze_active = False
    mega_smashing_meteor_trail.clear()  # 고스트샷 유성 효과 리셋
    mega_smashing_active = False  # 고스트샷 비활성화
    mega_smashing_start_time = 0  # 고스트샷 시작 시간 리셋
    # 고스트샷 보너스 플래그 리셋
    global mega_smashing_bonus_applied
    mega_smashing_bonus_applied = False
    # 👻 고스트샷 귀신 이펙트 리셋
    global mega_smashing_ghosts, mega_smashing_ghost_scatter, mega_smashing_ghost_scatter_time
    mega_smashing_ghosts.clear()
    mega_smashing_ghost_scatter = False
    mega_smashing_ghost_scatter_time = 0
    # 고스트샷 함수 속성 리셋
    if hasattr(handle_mega_smashing_trajectory, 'boosted'):
        delattr(handle_mega_smashing_trajectory, 'boosted')
    if hasattr(handle_mega_smashing_trajectory, 'original_speed'):
        delattr(handle_mega_smashing_trajectory, 'original_speed')
    if hasattr(handle_mega_smashing_trajectory, 'shadow_burst'):
        delattr(handle_mega_smashing_trajectory, 'shadow_burst')
    if hasattr(handle_mega_smashing_trajectory, 'shadow_particles'):
        delattr(handle_mega_smashing_trajectory, 'shadow_particles')
    if hasattr(handle_mega_smashing_trajectory, 'base_angle'):
        delattr(handle_mega_smashing_trajectory, 'base_angle')
    if hasattr(handle_mega_smashing_trajectory, 'boost_speed'):
        delattr(handle_mega_smashing_trajectory, 'boost_speed')
    # 🆕 강화된 연타 방지 시스템 리셋
    drive_global_cooldown = 0
    last_space_press_time = 0
    # 점수에 따라 서브 텍스트 보여줄지 결정
    if round_wins >= win_goal or round_losses >= win_goal:
        choose_server(show_text=False)
    else:
        choose_server(show_text=True)
    # 필살기 관련 - 게이지는 유지, 발동 상태만 초기화
    special_active = False
    special_ready = (special_gauge >= 350)  # 파워스매시 비용 조정: 400 → 350  # ✅ 게이지 상태에 따라 갱신
    ball_trail.clear()
    ball_angle = 0
    # 기타 상태 초기화
    PLAYER_SPEED = 1
    quake_active = False
    quake_timer = 0
    speed_defense_active = False
    speed_defense_timer = 0
    horizontal_bounce_count = 0
    drive_active = False
    drive_spin_speed = 0
    # 🆕 대쉬 관련 상태 초기화 (라운드 시작 시 모든 대쉬 효과 제거)
    rolling_active = False
    rolling_timer = 0
    rolling_direction = 0  # 🔧 대쉬 방향 초기화 (라운드 전환 시 대쉬 버그 방지)
    rolling_speed = 0      # 🔧 대쉬 속도 초기화 (라운드 전환 시 대쉬 버그 방지)
    rolling_stun_timer = 0
    rolling_dash_available_timer = 0
    global dash_afterimages
    dash_afterimages = []  # 대쉬 잔상 초기화
    rolling_cooldown = 0
    # 🚀 가속화 스킬 상태 초기화
    acceleration_active = False
    acceleration_original_speed = [0, 0]
    # 기존 시스템 - 증폭 스킬 적용
    base_charges = 1  # 기본 1개
    holder_bonus = 1 if dashholder_obtained else 0  # 대쉬홀더 +1개
    amplification_bonus = academy.get_skill_bonus("dash_amplification")
    rolling_charges = int(base_charges + holder_bonus + amplification_bonus)
    rolling_charge_timer = 0
    rolling_consecutive_count = 0  # 🆕 연속 대쉬 카운터 초기화
    # 대쉬 매니저 상태 동기화
    if dash is not None:
        dash.update_bonuses(dashholder_obtained, dashgear_obtained, spikeboots_obtained)
        dash.reset_to_max()  # 최대 토큰으로 초기화
        # 🔧 개선된 동기화 (양방향 검증)
        dash_tokens, dash_timer, dash_consecutive, dash_max = dash.get_legacy_sync_data()
        if rolling_charges != dash_tokens or rolling_charge_timer != dash_timer:
            print(f"🔄 토큰 시스템 동기화: 레거시({rolling_charges},{rolling_charge_timer}) → 매니저({dash_tokens},{dash_timer})")
            rolling_charges = max(0, min(dash_tokens, dash_max))  # 안전한 동기화
            rolling_charge_timer = max(0, dash_timer)
            rolling_consecutive_count = max(0, dash_consecutive)
    # 🆕 듀스 시스템 상태 초기화 (라운드 시작 시 듀스 모드 유지, 듀스 점수는 유지)
    # 듀스 모드에서는 듀스 점수를 리셋하지 않음 (듀스 모드가 끝날 때까지 유지)
    # 🆕 상모돌리기 상태 초기화 (라운드 시작 시)
    whip_active = False
    whip_timer = 0
    whip_hit_by_player = False
    whip_original_ball_speed = [0, 0]
    # 🆕 사이코볼(감정 오버드라이브) 상태 초기화 (라운드 시작 시)
    emotional_overdrive_active = False
    emotional_overdrive_timer = 0
    overdrive_flash_timer = 0
    overdrive_trails.clear()
    # 🧠 AI 프레임 카운터 초기화 (부드러운 AI 업데이트를 위해)
    ai_frame_counter = 0
def reset_deuce_system():
    """듀스 시스템을 완전히 리셋합니다."""
    global deuce_mode, deuce_wins, deuce_losses, deuce_goal
    deuce_mode = False
    deuce_wins = 0
    deuce_losses = 0
    deuce_goal = 4
    # 🧠 AI 메모리 정리 (스테이지 간 성능 최적화)
    optimize_ai_memory_for_stage_transition()
def choose_server(show_text=True):
    global is_player_serve, is_waiting_for_serve, waiting_start_time, wait_delay, boss_fake_move, boss_fake_start_time, boss_fake_during_player_serve
    global rolling_charges, rolling_charge_timer, rolling_consecutive_count, rolling_cooldown, token_states, mega_smashing_active, mega_smashing_start_time, mega_smashing_bonus_applied, mega_smashing_boss_defense_count
    global power_smashing_freeze_active, power_smashing_freeze_start_time, rolling_active, rolling_timer, rolling_direction, rolling_stun_timer
    # 고스트샷 및 파워스매싱 상태 초기화 (라운드 시작 시)
    mega_smashing_active = False
    mega_smashing_start_time = 0
    mega_smashing_bonus_applied = False
    mega_smashing_boss_defense_count = 0  # 보스 방어 카운터 리셋
    power_smashing_freeze_active = False
    power_smashing_freeze_start_time = 0
    # 고스트샷 함수 속성 리셋
    if hasattr(handle_mega_smashing_trajectory, 'boosted'):
        delattr(handle_mega_smashing_trajectory, 'boosted')
    if hasattr(handle_mega_smashing_trajectory, 'original_speed'):
        delattr(handle_mega_smashing_trajectory, 'original_speed')
    if hasattr(handle_mega_smashing_trajectory, 'shadow_burst'):
        delattr(handle_mega_smashing_trajectory, 'shadow_burst')
    if hasattr(handle_mega_smashing_trajectory, 'shadow_particles'):
        delattr(handle_mega_smashing_trajectory, 'shadow_particles')
    if hasattr(handle_mega_smashing_trajectory, 'base_angle'):
        delattr(handle_mega_smashing_trajectory, 'base_angle')
    if hasattr(handle_mega_smashing_trajectory, 'boost_speed'):
        delattr(handle_mega_smashing_trajectory, 'boost_speed')
    # 스테이지 6에서는 항상 플레이어가 먼저 서브
    if current_stage == 6:
        is_player_serve = True
    else:
        is_player_serve = random.choice([True, False])
    is_waiting_for_serve = True
    waiting_start_time = pygame.time.get_ticks()
    # 🔧 새 라운드 시작 시 토큰 시스템 초기화
    base_charges = 1
    holder_bonus = 1 if dashholder_obtained else 0
    amplification_bonus = academy.get_skill_bonus("dash_amplification") if 'academy' in globals() else 0
    max_charges = int(base_charges + holder_bonus + amplification_bonus)
    rolling_charges = max_charges
    rolling_charge_timer = 0
    rolling_consecutive_count = 0
    rolling_cooldown = 0
    # 토큰 상태 리스트 초기화 (모든 토큰 사용 가능)
    global token_states
    token_states = [True] * max_charges  # 모든 토큰 충전된 상태로 시작
    # 키 이벤트 큐 비우기 - 대쉬 버그 방지
    pygame.event.clear()
    pygame.event.pump()
    # 대쉬 매니저와 동기화
    # 레거시 대쉬 변수 명시적 초기화
    rolling_active = False
    rolling_timer = 0
    rolling_direction = 0
    rolling_stun_timer = 0
    rolling_dash_available_timer = 0  # 추가 초기화
    # 플레이어 속도 초기화
    global current_speed
    current_speed = 0
    if 'dash' in globals() and dash is not None:
        dash.reset_to_max()
        dash.is_active = False  # 명시적으로 비활성화
        dash.timer = 0
        dash.stun_timer = 0
    if is_player_serve:
        # 플레이어 서브: 스페이스바 대기
        wait_delay = 0
        boss_fake_move = False
        boss_fake_during_player_serve = False
    else:
        # 보스 서브
        if random.random() < 0.5:
            # 🔹 즉시 서브 (바로 serve_ball 호출)
            wait_delay = 0
            boss_fake_move = False
        else:
            # 🔹 간보기 서브 (1.5~2.5초 동안 움직이다가 서브)
            wait_delay = random.randint(1500, 2500)
            boss_fake_move = True
            boss_fake_start_time = pygame.time.get_ticks()
    boss_fake_during_player_serve = is_player_serve
    physics_manager.reset_ball(is_player_serve)
    if show_text:
        boss_name = boss_names.get(current_stage, "보스")
        serve_text = "플레이어 서브!" if is_player_serve else f"{boss_name} 서브!"
        show_fade_text(serve_text)
def create_impact_effect(x, y, ball_speed, is_player=True):
    """타격 이펙트 생성 - 격투게임 스타일로 소소하고 빠름"""
    global impact_particles, last_impact_strength
    # 공 속도 계산 (속도 벡터의 크기)
    speed = math.sqrt(ball_speed[0]**2 + ball_speed[1]**2)
    # 속도에 따른 강도 계산 (2~6 범위, 매우 소소하게)
    strength = min(6, max(2, int(speed * 0.4)))  # 훨씬 작은 강도
    last_impact_strength = strength
    # 파티클 개수 - 매우 적게 (2~4개)
    particle_count = 2 + (strength // 3)  # 2~4개만
    # 격투게임 스타일 - 흰색 스파크만 사용
    base_color = (255, 255, 255)  # 심플한 흰색
    # 파티클 생성 - 스파크 라인 형태
    for _ in range(particle_count):
        # 각도: 충돌 지점에서 방사형으로 퍼짐 (격투게임 스타일)
        angle = random.uniform(0, 2 * math.pi)
        # 매우 빠른 초기 속도, 빠른 감속
        speed = random.uniform(8, 12)  # 빠른 초기 속도
        vx = math.cos(angle) * speed
        vy = math.sin(angle) * speed
        # 매우 작은 크기 (거의 티 안남)
        size = random.randint(1, 2)  # 1-2픽셀만
        # 파티클 추가 [x, y, vx, vy, size, alpha, color, life]
        impact_particles.append([
            x + random.uniform(-2, 2),  # 작은 위치 분산
            y + random.uniform(-2, 2),
            vx, vy, size, 180, base_color, 8  # 8프레임만 생존 (매우 빠름)
        ])
def update_impact_particles():
    """타격 이펙트 파티클 업데이트 - 격투게임 스타일"""
    global impact_particles
    for particle in impact_particles[:]:
        # 위치 업데이트
        particle[0] += particle[2]  # x += vx
        particle[1] += particle[3]  # y += vy
        # 격투게임 스타일 - 빠른 감속, 중력 없음
        particle[2] *= 0.85  # 빠른 감속
        particle[3] *= 0.85  # 빠른 감속
        # 생명력 감소
        particle[7] -= 1
        # 빠른 페이드아웃
        particle[5] = max(0, particle[5] - 22)  # 8프레임에 빠르게 사라짐
        # 생명력이 다하면 제거
        if particle[7] <= 0 or particle[5] <= 0:
            impact_particles.remove(particle)
def draw_impact_particles():
    """충격 파티클 이펙트 - EffectRenderer 사용"""
    if impact_particles:
        # impact_particles를 EffectRenderer가 기대하는 형식으로 변환
        converted_particles = []
        for p in impact_particles:
            if len(p) >= 8:  # [x, y, vx, vy, size, alpha, color, life]
                converted_particles.append({
                    'x': p[0],
                    'y': p[1],
                    'vx': p[2],
                    'vy': p[3],
                    'size': p[4],
                    'alpha': p[5],
                    'color': p[6],
                    'life': p[7]
                })
        if converted_particles:
            effect_renderer.draw_particles(SCREEN, converted_particles)
def calculate_bounce(paddle):
    global vertical_bounce_count, ball_angle, ball_impact_boost, perfect_timing_active, perfect_direction
    global drive_speed_increase
    # 패들 타입 확인 (플레이어 vs 보스)
    is_player_paddle = (paddle == PLAYER)
    # 드라이브 발동 여부를 반환하기 위한 변수
    drive_activated = False
    rel_x = (BALL.centerx - paddle.centerx) / (PADDLE_WIDTH / 2)
    rel_x = max(-1.0, min(1.0, rel_x))
    # 기본 각도
    angle = rel_x * (math.pi / 3)
    # 기본 속도
    speed = math.hypot(ball_vel[0], ball_vel[1])
    # 🏓 공속도에 따른 충돌 부스트 조정 (강화된 과속 방지 시스템)
    base_speed_threshold = 10.0  # 기준 속도 (더 낮은 속도부터 감소 시작)
    max_speed_threshold = 18.0   # 최대 속도 (더 낮은 속도에서 최소값 도달)
    # 공속도 비율 계산 (0.0 ~ 1.0)
    if speed <= base_speed_threshold:
        speed_ratio = 0.0
    elif speed >= max_speed_threshold:
        speed_ratio = 1.0
    else:
        speed_ratio = (speed - base_speed_threshold) / (max_speed_threshold - base_speed_threshold)
    # 🚀 수정: 속도가 높아져도 초기 임팩트 부스트는 유지
    base_boost = 2.0        # 기본 200% 부스트
    min_boost = 1.1         # 최소 110% 부스트 (고속에서 적절한 반응 시간 확보)
    # 🌊 관성 보존: 저속에서 벽 충돌 후 자연스러운 속도 유지
    current_time = pygame.time.get_ticks()
    # 최근 벽 충돌 후 800ms 내에는 관성 보존 적용
    if last_wall_collision_time > 0 and current_time - last_wall_collision_time < 800:
        if speed < 12:  # 저속 구간에서만 적용
            momentum_factor = min(1.4, 1.0 + (12 - speed) * 0.06)  # 속도가 낮을수록 더 큰 보너스
            print(f"🌊 관성 보존: 속도={speed:.1f}, 보너스={momentum_factor:.2f}x")
    # 🎯 완만한 감소 적용 (급격한 부스트 감소 방지)
    speed_ratio_softened = speed_ratio ** 0.7  # 더 완만한 곡선
    dynamic_boost = base_boost - (base_boost - min_boost) * speed_ratio_softened
    # 🏓 속도에 따른 동적 감속 시스템 설정
    global ball_boost_decay_rate, ball_min_boost
    # 감속 프레임 수 계산 (42프레임 → 35프레임까지 감소)
    base_decay_frames = 42        # 기본 감속 프레임 (느린 속도용)
    min_decay_frames = 35         # 최소 감속 프레임 (빠른 속도용) - 더 길게 감속
    dynamic_decay_frames = base_decay_frames - (base_decay_frames - min_decay_frames) * speed_ratio
    # 🚀 스무스 트랜지션 시스템: 속도 하락 완화 (70% → 55%로 조정)
    base_min_boost = 0.70         # 기본 최종 속도 (느린 속도용)
    min_min_boost = 0.55          # 최소 최종 속도 (빠른 속도용) - 감속 완화
    # 속도가 높을수록 더 낮은 값으로 감속 (기존보다 완화)
    dynamic_min_boost = base_min_boost - (base_min_boost - min_min_boost) * speed_ratio
    # 감속율 계산: dynamic_boost에서 dynamic_min_boost까지 dynamic_decay_frames에 걸쳐 감소
    adjusted_decay_frames = dynamic_decay_frames  # 기본값
    if dynamic_decay_frames > 0 and dynamic_boost > dynamic_min_boost:
        # 🌊 스무스 감속: 급격한 속도 변화 방지 (30% → 18%로 완화)
        speed_penalty_factor = 1.0 + speed_ratio * 0.18  # 고속일 때 감속 완화
        adjusted_decay_frames = dynamic_decay_frames / speed_penalty_factor
        ball_boost_decay_rate = (dynamic_min_boost / dynamic_boost) ** (1.0 / adjusted_decay_frames)
    else:
        ball_boost_decay_rate = 0.95  # 기본값
    ball_min_boost = dynamic_min_boost
    # 🎯 퍼펙트 타이밍 체크 (플레이어 패들만)
    if paddle == PLAYER and perfect_timing_active and perfect_direction is not None:
        # 🎯 드라이브 발동을 위한 게이지 확인 (150 게이지 필요)
        global special_gauge
        if special_gauge >= 150:
            drive_activated = True  # 🎯 드라이브 발동 표시
            special_gauge -= 150  # 🎯 드라이브 발동 시 150 게이지 소모
            print(f"🎯 퍼펙트 타이밍 성공! 드라이브 발동! (게이지 150 소모, 남은 게이지: {special_gauge})")
            # 🏆 드라이브 성공 기록
            record_skill_usage(success=True)
            # 🌪️ 드라이브 스핀 효과 적용 (기본 커브량 + 공속 비례 추가 커브)
            global ball_spin_strength, ball_spin_direction, drive_ball_active, drive_hit_boss, drive_just_activated
            # 기본 커브량 유지
            base_spin = 0.25  # 기본 커브량 (현재 수준 유지)
            # 공속에 비례한 추가 커브량 계산
            speed_bonus_multiplier = speed * 0.015  # 공속 1당 0.015 추가 커브
            additional_spin = speed_bonus_multiplier
            ball_spin_strength = base_spin + additional_spin
            # 최대 커브량 제한 (너무 과도하지 않게)
            ball_spin_strength = min(0.6, ball_spin_strength)
            ball_spin_direction = perfect_direction
            print(f"🌪️ 드라이브 커브량 - 공속: {speed:.2f}, 기본: {base_spin:.3f}, 추가: {additional_spin:.3f}, 총 커브: {ball_spin_strength:.3f}")
            drive_ball_active = True   # 드라이브 공 상태 활성화 (연두색)
            drive_hit_boss = False     # 드라이브 상태 초기화
            drive_just_activated = True  # 🆕 방법1: 드라이브 방금 발동됨 표시
            global drive_text_timer
            drive_text_timer = 30      # DRIVE! 텍스트 0.5초간 표시
            # 드라이브 성공 시 1.5% 속도 증가
            original_speed = speed
            speed *= 1.015
            # 🆕 드라이브로 증가한 속도량 추적 (보스 충돌 시 90% 감소용)
            drive_speed_increase = speed - original_speed
            print(f"🎯 드라이브 속도 증가: {original_speed:.2f} → {speed:.2f} (증가량: {drive_speed_increase:.2f})")
            # 🎯 패들 위치에 따른 드라이브 각도 조정 (균형잡힌 각도)
            if perfect_direction == -1:  # 왼쪽 드라이브
                # 패들 위치가 왼쪽일수록 각도 완화, 오른쪽일수록 각도 증가
                base_angle = -math.pi / 8.0  # 기본 22.5도
                position_factor = rel_x * 0.3  # 위치에 따른 조정 (-0.3 ~ +0.3)
                angle = base_angle + position_factor
            else:  # 오른쪽 드라이브
                # 패들 위치가 오른쪽일수록 각도 완화, 왼쪽일수록 각도 증가
                base_angle = math.pi / 8.0   # 기본 22.5도
                position_factor = rel_x * 0.3  # 위치에 따른 조정 (-0.3 ~ +0.3)
                angle = base_angle + position_factor
        else:
            print(f"🎯 퍼펙트 타이밍이지만 게이지 부족! (현재: {special_gauge}, 필요: 150)")
        # 퍼펙트 타이밍 상태 리셋
        perfect_timing_active = False
        perfect_direction = None
        # 일반 충돌과 동일한 속도 처리
        # 🚀 속도에 관계없이 일정한 가속 적용 (완화된 증가율)
        base_multiplier = random.uniform(1.02, 1.07)  # 기본 가속 (2~7%, 평균 4.5%)
        speed *= base_multiplier
        # 🏓 임팩트 부스트 적용 (이제 최소 1.5배 보장)
        ball_impact_boost = dynamic_boost
        print(f"🎯 플레이어 충돌: 속도 부스트 {base_multiplier:.2f}x, 임팩트 {dynamic_boost:.2f}x, 최종 속도: {speed:.1f}")
    else:
        # 일반 충돌 시 동일한 가속 (완화된 증가율)
        base_multiplier = random.uniform(1.02, 1.07)  # 기본 가속 (2~7%, 평균 4.5%)
        speed *= base_multiplier
        # 🏓 임팩트 부스트 적용
        ball_impact_boost = dynamic_boost
    # 🤖 보스 충돌 처리 (플레이어가 아닌 경우)
    if not is_player_paddle:
        # 보스 충돌 시 추가 가속 (속도에 관계없이 일정, 크게 완화)
        boss_multiplier = random.uniform(1.01, 1.045)  # 보스 추가 가속 (1~4.5%, 평균 2.3%)
        speed *= boss_multiplier
    direction = -1 if paddle == PLAYER else 1
    vector = pygame.math.Vector2(0, direction).rotate_rad(angle)
    # === 다이나믹 물리효과 ===
    # 🆕 추가 속도 증가량 추적 (드라이브 외 일반 가속)
    if drive_activated:
        # 드라이브 발동 시에만 추가 가속 효과 추적
        if abs(rel_x) < 0.05:  # 극중앙 맞춤
            additional_speed = speed * 0.03  # 3% 증가
            speed *= 1.03
            drive_speed_increase += additional_speed
            # 🌪️ 속도 증가에 따른 커브량 재계산
            base_spin = 0.25  # 기본 커브량 재선언
            speed_bonus_multiplier = speed * 0.015  # 증가된 공속에 비례한 커브
            ball_spin_strength = base_spin + speed_bonus_multiplier
            ball_spin_strength = min(0.6, ball_spin_strength)  # 최대치 제한
            print(f"🎯 드라이브 + 극중앙 추가 가속: +{additional_speed:.2f} (총 증가량: {drive_speed_increase:.2f}, 업데이트된 커브: {ball_spin_strength:.3f})")
        elif abs(rel_x) > 0.75:  # 스매시 zone
            additional_multiplier = random.uniform(1.015, 1.05)
            additional_speed = speed * (additional_multiplier - 1.0)
            speed *= additional_multiplier
            drive_speed_increase += additional_speed
            # 🌪️ 속도 증가에 따른 커브량 재계산
            base_spin = 0.25  # 기본 커브량 재선언
            speed_bonus_multiplier = speed * 0.015  # 증가된 공속에 비례한 커브
            ball_spin_strength = base_spin + speed_bonus_multiplier
            ball_spin_strength = min(0.6, ball_spin_strength)  # 최대치 제한
            print(f"🎯 드라이브 + 스매시존 추가 가속: +{additional_speed:.2f} (총 증가량: {drive_speed_increase:.2f}, 업데이트된 커브: {ball_spin_strength:.3f})")
            curve = random.uniform(-5, 5)
            vector = vector.rotate(curve)
            ball_angle += random.uniform(3, 7) * (-1 if rel_x < 0 else 1)
    else:
        # 일반 상황에서는 기존 로직 유지
        if abs(rel_x) < 0.05:  # 극중앙 맞춤
            speed *= 1.03  # 살짝 가속 보정
        elif abs(rel_x) < 0.15:  # 중앙 zone
            curve = random.uniform(-35, 35)
            vector = vector.rotate(curve)
            spin = random.uniform(-2, 2)
            ball_angle += spin
        elif abs(rel_x) > 0.75:  # 스매시 zone
            speed *= random.uniform(1.015, 1.05)  # 스매시존 가속 (1.5~5%)
            curve = random.uniform(-5, 5)
            vector = vector.rotate(curve)
            ball_angle += random.uniform(3, 7) * (-1 if rel_x < 0 else 1)
    # 중앙 zone 처리 (드라이브 여부와 무관)
    if abs(rel_x) >= 0.05 and abs(rel_x) < 0.15:  # 중앙 zone
        curve = random.uniform(-35, 35)
        vector = vector.rotate(curve)
        spin = random.uniform(-2, 2)
        ball_angle += spin
        # 각도 제한 처리
        angle_limit = math.radians(60)
        if abs(angle) > angle_limit:
            angle = angle_limit * (1 if angle > 0 else -1)
            vector = pygame.math.Vector2(0, direction).rotate_rad(angle)
    else:  # 중간 zone
        if random.random() < 0.3:
            curve = random.uniform(-20, 20)
            vector = vector.rotate(curve)
            ball_angle += random.uniform(-2, 2)
    # 최종 속도 반영
    ball_vel[0] = speed * vector.x
    ball_vel[1] = speed * vector.y
    # 수직 튕김 방지 처리
    if abs(ball_vel[0]) < 0.5:
        vertical_bounce_count += 1
        correction = math.radians(random.choice([-3, 3]))  # 미세 꺾임
        vector = vector.rotate_rad(correction)
        ball_vel[0] = speed * vector.x
        ball_vel[1] = speed * vector.y
    else:
        vertical_bounce_count = 0
    # 완전 수직 튕김 보정
    if vertical_bounce_count >= 2:
        correction = math.radians(random.choice([-15, 15]))  # 강제 꺾임
        vector = vector.rotate_rad(correction)
        ball_vel[0] = speed * vector.x
        ball_vel[1] = speed * vector.y
        vertical_bounce_count = 0
    # 🎯 드라이브 발동 여부 반환
    return drive_activated
# 🔹 화염탄 맞았을 때 플레이어 스턴 관련 변수
player_stunned_timer = 0      # 프레임 단위 (0이면 스턴 아님)
player_knockback_vel = 0      # 좌우 튕김 속도
# 🔥 화염병으로 보스 스턴 관련 변수
boss_stunned_timer = 0        # 프레임 단위 (0이면 스턴 아님)
boss_knockback_vel = 0        # 좌우 튕김 속도
# 🔥 화염 지대 내 보스 속도 감소 효과
boss_speed_reduction_active = False  # 보스가 화염 지대 안에 있는지
boss_speed_reduction_factor = 1.0    # 속도 감소 배율 (1.0 = 정상속도)
# 💥 고스트샷 보스 넉백 관련 변수
boss_knockback_timer = 0      # 넉백 지속 시간
mega_smashing_boss_defense_count = 0  # 보스가 고스트샷을 방어한 횟수
def handle_mega_smashing_trajectory():
    """고스트샷 전용 궤적 이동 처리 - 뫼비우스의 띠"""
    global ball_vel, BALL, mega_smashing_start_time, mega_smashing_particles, quantum_explosion_active, quantum_balls, quantum_collapse_timer
    global quantum_measurement_made, quantum_interference_pattern
    if not mega_smashing_active:
        return
    # 고스트샷 시작 시간이 0이면 무시 (초기화 안됨)
    if mega_smashing_start_time == 0:
        return
    current_time = pygame.time.get_ticks()
    elapsed_time = (current_time - mega_smashing_start_time) / 1000.0  # 초 단위
    # 디버그: 경과 시간 출력 (처음 몇 프레임만)
    if elapsed_time < 0.1:
        print(f"🐉 고스트샷 시작! 현재시간={current_time}, 시작시간={mega_smashing_start_time}, 경과={elapsed_time:.3f}초")
    # 2초 후 직진 모드로 전환
    if elapsed_time >= 2.0:
        # 한 번만 실행되도록 체크 (초기 설정)
        if not hasattr(handle_mega_smashing_trajectory, 'boosted'):
            handle_mega_smashing_trajectory.boosted = True
            # 원래 속도 저장 (초기 속도는 원래 속도 그대로 시작)
            if hasattr(handle_mega_smashing_trajectory, 'original_speed'):
                base_speed = handle_mega_smashing_trajectory.original_speed
            else:
                base_speed = BALL_BASE_SPEED
            # 초기에는 원래 속도로 시작 (가속은 나중에)
            new_speed = base_speed
            # 🌀 양자 순간이동 - 보스와 좌우로 멀리 떨어진 곳으로 텔레포트
            boss_x = BOSS.centerx
            # 보스가 왼쪽에 있으면 오른쪽으로, 오른쪽에 있으면 왼쪽으로 순간이동
            # 순간이동 거리 80%로 설정
            if boss_x < WIDTH // 2:
                # 보스가 왼쪽에 있으면 오른쪽으로 (거리 80%)
                teleport_x = WIDTH // 2 + int((WIDTH // 2 - 50) * 0.8)  # 중앙에서 끝까지 거리의 80%
            else:
                # 보스가 오른쪽에 있으면 왼쪽으로 (거리 80%)
                teleport_x = WIDTH // 2 - int((WIDTH // 2 - 50) * 0.8)  # 중앙에서 끝까지 거리의 80%
            # 높이는 현재 위치 유지 (이미 300픽셀 위에 있으므로)
            teleport_y = BALL.centery  # 현재 높이 그대로 유지
            # 공 순간이동
            BALL.centerx = teleport_x
            BALL.centery = teleport_y
            print(f"🌀 양자 순간이동! 위치: ({teleport_x}, {teleport_y})")
            # 순간이동 이펙트
            for _ in range(20):
                particle_angle = random.uniform(0, 2 * math.pi)
                particle_speed = random.uniform(5, 15)
                mega_smashing_particles.append({
                    'x': teleport_x,
                    'y': teleport_y,
                    'vx': math.cos(particle_angle) * particle_speed,
                    'vy': math.sin(particle_angle) * particle_speed,
                    'life': 30,
                    'color': (150, 100, 255),  # 보라색 순간이동 파티클
                    'size': random.randint(3, 8)
                })
            # 60도 ~ 120도 중 랜덤한 각도로 발사
            angle_degrees = random.uniform(60, 120)  # 60도~120도 랜덤
            angle = -math.radians(angle_degrees)  # 라디안으로 변환 (음수는 위쪽 방향)
            # 폭발 시 속도를 2.5배로 증가
            explosion_speed = new_speed * 2.5
            # 초기 발사 각도와 속도 저장
            handle_mega_smashing_trajectory.base_angle = angle
            handle_mega_smashing_trajectory.boost_speed = explosion_speed
            # 초기 속도 벡터 설정 (2.5배 속도)
            ball_vel[0] = math.cos(angle) * explosion_speed
            ball_vel[1] = math.sin(angle) * explosion_speed
            print(f"🐉 고스트샷 폭발! 기본속도: {new_speed:.1f} → 폭발속도: {explosion_speed:.1f} (2.5배), 각도: {math.degrees(angle):.1f}°")
            # ⚛️ 양자역학 효과 발동 - 공이 여러 양자 상태로 분열
            quantum_explosion_active = True
            quantum_balls.clear()
            quantum_wave_function.clear()
            quantum_entanglement_pairs.clear()
            quantum_collapse_timer = 120  # 2초 후 양자 붕괴
            quantum_measurement_made = False
            # 양자 중첩 상태 생성 (슈뢰딩거의 공)
            for i in range(quantum_superposition_count):
                # 각 양자 상태는 서로 다른 확률 진폭을 가짐
                phase = (i / quantum_superposition_count) * 2 * math.pi
                probability = random.uniform(0.3, 1.0)  # 확률 진폭
                # 하이젠베르크 불확정성 원리 적용 - 위치와 운동량의 불확정성
                position_uncertainty = random.uniform(-30, 30)
                # 양자 터널링 효과를 위한 속도 변화
                quantum_angle = angle + random.uniform(-math.pi/4, math.pi/4)
                quantum_speed = new_speed * random.uniform(0.7, 1.3)
                quantum_ball = {
                    'x': BALL.centerx + position_uncertainty * math.cos(phase),
                    'y': BALL.centery + position_uncertainty * math.sin(phase),
                    'vx': math.cos(quantum_angle) * quantum_speed,
                    'vy': math.sin(quantum_angle) * quantum_speed,
                    'alpha': probability * 150,  # 투명도
                    'phase': phase,
                    'probability': probability,
                    'collapsed': False,
                    'wave_amplitude': random.uniform(0.5, 1.5),
                    'entangled_with': None,
                    'spin': random.choice(['up', 'down']),  # 양자 스핀
                    'tunneling': random.random() < 0.3  # 30% 확률로 터널링 가능
                }
                quantum_balls.append(quantum_ball)
            # 양자 얽힘 쌍 생성 (EPR 패러독스)
            if len(quantum_balls) >= 2:
                for i in range(0, len(quantum_balls)-1, 2):
                    quantum_balls[i]['entangled_with'] = i + 1
                    quantum_balls[i+1]['entangled_with'] = i
                    quantum_balls[i+1]['spin'] = 'down' if quantum_balls[i]['spin'] == 'up' else 'up'
            print(f"⚛️ 양자 폭발! {quantum_superposition_count}개의 중첩 상태 생성")
            # 폭발 효과를 위한 추가 파티클 생성
            for ghost in mega_smashing_ghosts:
                ghost['scatter_vx'] = random.uniform(-20, 20)
                ghost['scatter_vy'] = random.uniform(-20, 20)
            # 🌑 검은 그림자 돌진 효과 시작
            if not hasattr(handle_mega_smashing_trajectory, 'shadow_burst'):
                handle_mega_smashing_trajectory.shadow_burst = True
                handle_mega_smashing_trajectory.shadow_particles = []
                # 검은 그림자 파티클 생성
                for i in range(20):  # 20개의 검은 그림자
                    shadow_angle = random.uniform(0, 2 * math.pi)
                    handle_mega_smashing_trajectory.shadow_particles.append({
                        'x': BALL.centerx,
                        'y': BALL.centery,
                        'vx': math.cos(shadow_angle) * random.uniform(5, 15),
                        'vy': math.sin(shadow_angle) * random.uniform(5, 15),
                        'size': random.randint(10, 30),
                        'life': 60,  # 1초간 지속
                        'alpha': 255
                    })
        # 🌀 지속적으로 휘어지는 궤적 적용 (벽 충돌 반사 유지)
        if hasattr(handle_mega_smashing_trajectory, 'base_angle'):
            boost_time = elapsed_time - 2.0  # 폭발 후 경과 시간
            # 🌌 상향 중력 제거 - 자연스러운 포물선 궤적 유지
            # 랜덤 각도로 발사된 방향을 그대로 유지하도록 수정
            pass  # 더 이상 강제로 위쪽으로 끌어당기지 않음
            # 💥 0.5초 동안 점진적으로 6배까지 가속 (폭주)
            if boost_time <= 0.5:
                # 가속 진행도 (0.0 ~ 1.0)
                accel_progress = boost_time / 0.5
                # 1배에서 6배까지 점진적 증가 (부드러운 가속 곡선)
                speed_multiplier = 1.0 + (5.0 * accel_progress * accel_progress)  # 제곱으로 부드러운 가속
                # 기본 속도 계산
                if hasattr(handle_mega_smashing_trajectory, 'original_speed'):
                    base_speed = handle_mega_smashing_trajectory.original_speed
                else:
                    base_speed = BALL_BASE_SPEED
                target_speed = base_speed * speed_multiplier
                # 디버그 출력 (처음 몇 프레임만)
                if boost_time < 0.1 or (boost_time > 0.45 and boost_time < 0.51):
                    print(f"🌌 상향 중력 적용중! Y속도: {ball_vel[1]:.1f}")
            else:
                # 0.5초 후에는 6배 속도 유지
                if hasattr(handle_mega_smashing_trajectory, 'original_speed'):
                    base_speed = handle_mega_smashing_trajectory.original_speed
                else:
                    base_speed = BALL_BASE_SPEED
                target_speed = base_speed * 6.0
            # 시간에 따라 좌우로 휘어지는 효과 (더 부드럽게)
            curve_time = boost_time * 3  # 휘어지는 주기
            curve_strength = 0.15  # 휘어지는 강도
            curve_factor = math.sin(curve_time) * curve_strength
            # 현재 속도 방향을 약간만 조정 (벽 충돌 반사 유지)
            current_speed = math.hypot(ball_vel[0], ball_vel[1])
            if current_speed > 0:
                # 현재 각도 계산
                current_angle = math.atan2(ball_vel[1], ball_vel[0])
                # 약간의 휘어짐만 추가
                new_angle = current_angle + curve_factor
                # 목표 속도로 설정하면서 방향 조정 (Y속도는 중력 영향 유지)
                ball_vel[0] = math.cos(new_angle) * target_speed
                # Y속도는 중력 효과가 이미 적용되어 있으므로 조정하지 않음
        return
    # 2초 이후에는 8자 패턴 실행하지 않음 (이미 폭발했으므로)
    if elapsed_time >= 2.0:
        return
    # 뫼비우스의 띠(8자) 움직임 패턴 (2초 동안) - 플레이어 패들 위쪽에서
    t = elapsed_time * math.pi * 3  # 0~6π (2초 동안 3회전)
    # 기본 속도 (조금 느리게)
    base_speed = 10.0  # 속도를 15.0에서 10.0으로 감소
    # 8자 패턴 중심을 원래 위치보다 300픽셀 위로 설정
    center_x = PLAYER.centerx
    if hasattr(handle_mega_smashing_trajectory, 'original_y'):
        # 원래 위치에서 300픽셀 위를 중심으로
        center_y = handle_mega_smashing_trajectory.original_y - 300
    else:
        center_y = PLAYER.centery - 500  # 기본값: 패들보다 500픽셀 위
    # 뫼비우스의 띠 (8자) 패턴 - 더 작고 컴팩트하게
    # 리사주 곡선을 사용하여 8자 움직임 생성
    lissajous_a = 2  # X축 주파수
    lissajous_b = 1  # Y축 주파수
    lissajous_delta = math.pi / 2  # 위상차
    # 8자 패턴의 크기 (좌우 움직임 4배 증가)
    pattern_size_x = 600  # X축 패턴 크기 (좌우 움직임) - 300에서 600으로 다시 2배 증가
    pattern_size_y = 100  # Y축 패턴 크기 (상하 움직임) - 유지
    # 뫼비우스 8자 움직임
    pattern_x = math.sin(lissajous_a * t + lissajous_delta) * pattern_size_x
    pattern_y = math.sin(lissajous_b * t) * pattern_size_y
    # 목표 위치 계산 (플레이어 패들 위쪽 영역)
    target_x = center_x + pattern_x
    target_y = center_y + pattern_y
    # 현재 위치에서 목표 위치로의 방향 벡터
    dx = target_x - BALL.centerx
    dy = target_y - BALL.centery
    # 부드러운 이동을 위한 속도 계산
    move_speed = 0.15  # 이동 속도 계수
    target_vx = dx * move_speed
    target_vy = dy * move_speed
    # 추가 꿈틀거림 (용의 몸부림) - 작게
    wiggle_x = math.sin(t * 7) * 2  # 작은 좌우 진동
    wiggle_y = math.cos(t * 6) * 2  # 작은 상하 진동
    target_vx += wiggle_x
    target_vy += wiggle_y
    # 부드러운 전환을 위한 보간
    smoothing = 0.25  # 더 빠른 반응
    ball_vel[0] = ball_vel[0] * (1 - smoothing) + target_vx * smoothing
    ball_vel[1] = ball_vel[1] * (1 - smoothing) + target_vy * smoothing
    # 최소 속도 보장 (느리게)
    min_speed = 6.0  # 최소 속도를 10.0에서 6.0으로 감소
    current_speed = math.hypot(ball_vel[0], ball_vel[1])
    if current_speed < min_speed and current_speed > 0:
        scale = min_speed / current_speed
        ball_vel[0] *= scale
        ball_vel[1] *= scale
    # 초기화 및 원래 속도 저장
    if elapsed_time < 0.1:
        handle_mega_smashing_trajectory.boosted = False
        if not hasattr(handle_mega_smashing_trajectory, 'original_speed'):
            handle_mega_smashing_trajectory.original_speed = max(
                math.hypot(ball_vel[0], ball_vel[1]), 
                BALL_BASE_SPEED
            )
    # ⚛️ 양자 상태 공들 업데이트
    if quantum_explosion_active and quantum_balls:
        # 양자 붕괴 타이머 감소
        if quantum_collapse_timer > 0:
            quantum_collapse_timer -= 1
        for qball in quantum_balls:
            if qball['collapsed']:
                continue
            # 양자 공 이동
            qball['x'] += qball['vx']
            qball['y'] += qball['vy']
            # 파동 함수 진동
            qball['phase'] += 0.1
            amplitude = qball['wave_amplitude'] * math.sin(qball['phase'])
            qball['x'] += amplitude * math.cos(qball['phase'])
            qball['y'] += amplitude * math.sin(qball['phase'])
            # 터널링 효과 - 벽 통과
            if qball['tunneling']:
                # 벽 근처에서 확률적으로 통과
                if qball['x'] <= 20 or qball['x'] >= WIDTH - 20:
                    if random.random() < 0.5:  # 50% 확률로 터널링
                        qball['vx'] *= -0.8  # 약간 느려지며 반사
                        qball['tunneling'] = False  # 터널링 능력 소진
                    # else: 그냥 통과
                elif qball['y'] <= 20 or qball['y'] >= HEIGHT - 20:
                    if random.random() < 0.5:
                        qball['vy'] *= -0.8
                        qball['tunneling'] = False
            else:
                # 일반 벽 충돌
                if qball['x'] <= BALL_RADIUS or qball['x'] >= WIDTH - BALL_RADIUS:
                    qball['vx'] *= -1
                    qball['x'] = max(BALL_RADIUS, min(WIDTH - BALL_RADIUS, qball['x']))
                if qball['y'] <= BALL_RADIUS or qball['y'] >= HEIGHT - BALL_RADIUS:
                    qball['vy'] *= -1
                    qball['y'] = max(BALL_RADIUS, min(HEIGHT - BALL_RADIUS, qball['y']))
            # 얽힘 효과 - 한 공이 변하면 얽힌 공도 영향받음
            if qball['entangled_with'] is not None:
                entangled = quantum_balls[qball['entangled_with']]
                if not entangled['collapsed']:
                    # 스핀 플립 상호작용
                    if random.random() < 0.01:  # 1% 확률로 스핀 플립
                        qball['spin'] = 'down' if qball['spin'] == 'up' else 'up'
                        entangled['spin'] = 'down' if entangled['spin'] == 'up' else 'up'
            # 확률 진폭 감소 (시간에 따른 decoherence)
            qball['alpha'] *= 0.995
            qball['probability'] *= 0.998
            # 양자 붕괴 조건
            if quantum_collapse_timer <= 0 or qball['alpha'] < 10:
                # 관측에 의한 붕괴 - 하나의 상태로 수렴
                if not quantum_measurement_made:
                    # 가장 높은 확률의 공 선택
                    max_prob_ball = max(quantum_balls, key=lambda b: b['probability'] if not b['collapsed'] else 0)
                    # 실제 공 위치를 선택된 양자 공 위치로 이동
                    # X축은 양자 공 위치 사용, Y축은 현재 위치 유지 (아래로 내려오지 않도록)
                    BALL.centerx = int(max_prob_ball['x'])
                    # BALL.centery는 변경하지 않음 (현재 높이 유지)
                    ball_vel[0] = max_prob_ball['vx']
                    ball_vel[1] = max_prob_ball['vy']  # 양자 공의 원래 방향 유지
                    quantum_measurement_made = True
                    print(f"⚛️ 양자 붕괴! 파동함수 수렴 완료 Y위치 유지: {BALL.centery}")
                # 모든 양자 공 붕괴
                qball['collapsed'] = True
boss_knockback_distance = 0   # 넉백 거리
def render_mega_smashing_effects():
    """고스트샷 전용 이펙트 렌더링 - 원한의 귀신들"""
    global mega_smashing_ghosts, mega_smashing_ghost_scatter, mega_smashing_ghost_scatter_time
    if not mega_smashing_active:
        return
    current_time = pygame.time.get_ticks()
    # 👻 귀신들 초기화 (고스트샷 시작 시)
    if len(mega_smashing_ghosts) == 0 and not mega_smashing_ghost_scatter:
        # 8-12개의 귀신 생성
        num_ghosts = random.randint(8, 12)
        for i in range(num_ghosts):
            angle = (i / num_ghosts) * 2 * math.pi + random.uniform(-0.3, 0.3)
            mega_smashing_ghosts.append({
                'x': BALL.centerx,
                'y': BALL.centery,
                'angle': angle,
                'radius': random.uniform(30, 50),  # 공 주위 회전 반경
                'speed': random.uniform(0.02, 0.04),  # 회전 속도
                'alpha': random.randint(100, 200),
                'wobble': random.uniform(0, 2 * math.pi),  # 떨림 효과
                'wobble_speed': random.uniform(0.1, 0.2),
                'scatter_vx': 0,  # 흩어짐 속도
                'scatter_vy': 0,
                'size': random.randint(15, 25)
            })
    # 👻 귀신들 업데이트 및 렌더링
    new_ghosts = []
    for ghost in mega_smashing_ghosts:
        if mega_smashing_ghost_scatter:
            # 흩어짐 모드
            elapsed = (current_time - mega_smashing_ghost_scatter_time) / 1000.0
            if elapsed < 2.0:  # 2초간 흩어짐
                ghost['x'] += ghost['scatter_vx']
                ghost['y'] += ghost['scatter_vy']
                ghost['alpha'] = max(0, ghost['alpha'] - 5)
                # 가속도 추가 (더 빠르게 흩어짐)
                ghost['scatter_vx'] *= 1.05
                ghost['scatter_vy'] *= 1.05
                if ghost['alpha'] > 0:
                    new_ghosts.append(ghost)
        else:
            # 공 주위를 도는 모드
            ghost['angle'] += ghost['speed']
            ghost['wobble'] += ghost['wobble_speed']
            # 불규칙한 움직임 (원한에 사무친 느낌)
            wobble_offset = math.sin(ghost['wobble']) * 10
            radius_with_wobble = ghost['radius'] + wobble_offset
            ghost['x'] = BALL.centerx + math.cos(ghost['angle']) * radius_with_wobble
            ghost['y'] = BALL.centery + math.sin(ghost['angle']) * radius_with_wobble
            # 알파값 변화 (깜빡임 효과)
            ghost['alpha'] = 100 + int(50 * math.sin(current_time * 0.01 + ghost['angle']))
            new_ghosts.append(ghost)
    mega_smashing_ghosts = new_ghosts
    # 👻 귀신 그리기
    for ghost in mega_smashing_ghosts:
        # 귀신 몸체 (반투명 원)
        ghost_surface = pygame.Surface((ghost['size'] * 2, ghost['size'] * 2), pygame.SRCALPHA)
        # 어두운 보라색/검은색 계열
        color = (random.randint(80, 120), random.randint(0, 40), random.randint(100, 150))
        # 중심부 (더 진한 색)
        pygame.draw.circle(ghost_surface, (*color, min(255, ghost['alpha'])), 
                         (ghost['size'], ghost['size']), ghost['size'])
        # 외곽 광채 (원한의 오라)
        for i in range(3):
            aura_size = ghost['size'] + (i + 1) * 5
            aura_alpha = max(0, ghost['alpha'] // (3 + i))
            pygame.draw.circle(ghost_surface, (*color, aura_alpha),
                             (ghost['size'], ghost['size']), aura_size, 2)
        # 눈 (빨간색 점)
        if not mega_smashing_ghost_scatter:
            eye_offset = 5
            pygame.draw.circle(ghost_surface, (255, 0, 0, min(255, ghost['alpha'] * 2)),
                             (ghost['size'] - eye_offset, ghost['size'] - 3), 2)
            pygame.draw.circle(ghost_surface, (255, 0, 0, min(255, ghost['alpha'] * 2)),
                             (ghost['size'] + eye_offset, ghost['size'] - 3), 2)
        SCREEN.blit(ghost_surface, (ghost['x'] - ghost['size'], ghost['y'] - ghost['size']))
    # 공 주위에 어두운 오라 효과
    if not mega_smashing_ghost_scatter:
        aura_surface = pygame.Surface((150, 150), pygame.SRCALPHA)
        for i in range(5):
            alpha = 30 - i * 5
            pygame.draw.circle(aura_surface, (50, 0, 70, alpha), (75, 75), 30 + i * 10)
        SCREEN.blit(aura_surface, (BALL.centerx - 75, BALL.centery - 75))
    # 🌑 검은 그림자 파티클 렌더링 (폭발 시)
    if hasattr(handle_mega_smashing_trajectory, 'shadow_particles'):
        new_particles = []
        for particle in handle_mega_smashing_trajectory.shadow_particles:
            # 파티클 업데이트
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1
            particle['alpha'] = int((particle['life'] / 60) * 255)
            # 중력 효과
            particle['vy'] += 0.3
            # 감속
            particle['vx'] *= 0.98
            particle['vy'] *= 0.98
            if particle['life'] > 0:
                new_particles.append(particle)
                # 검은 그림자 그리기
                shadow_surf = pygame.Surface((particle['size'] * 2, particle['size'] * 2), pygame.SRCALPHA)
                # 검은색에서 어두운 보라색으로 그라데이션
                color = (20, 0, 30)
                pygame.draw.circle(shadow_surf, (*color, min(255, particle['alpha'])), 
                                 (particle['size'], particle['size']), particle['size'])
                SCREEN.blit(shadow_surf, (particle['x'] - particle['size'], particle['y'] - particle['size']))
        handle_mega_smashing_trajectory.shadow_particles = new_particles
# 🔥 화염탄 폭발 이펙트 관련 변수
fireball_explosion_particles = []  # [(x, y, vx, vy, life, max_life), ...]
def create_fireball_explosion(x, y):
    """화염탄 폭발 이펙트 생성"""
    global fireball_explosion_particles
    # 🔥 더 많은 작은 파티클로 진짜 불꽃 효과 (40-60개)
    particle_count = random.randint(40, 60)
    for _ in range(particle_count):
        # 폭발 방향 (360도 전방향)
        angle = random.uniform(0, 2 * math.pi)
        # 폭발 속도 (더 강력하고 다양한 속도)
        speed = random.uniform(2.0, 12.0)
        vx = math.cos(angle) * speed
        vy = math.sin(angle) * speed
        # 파티클 생명 시간 (더 짧고 다양하게)
        life = random.randint(15, 35)  # 프레임 단위
        fireball_explosion_particles.append([x, y, vx, vy, life, life])
def update_fireball_explosion_particles():
    """화염탄 폭발 파티클 업데이트"""
    global fireball_explosion_particles
    new_particles = []
    for particle in fireball_explosion_particles:
        x, y, vx, vy, life, max_life = particle
        # 파티클 이동
        x += vx
        y += vy
        # 🔥 불꽃 물리 효과 (더 자연스러운 움직임)
        # 중력 효과 (아래쪽으로 가속, 더 강하게)
        vy += 0.3
        # 공기 저항 (속도 감소, 더 강하게)
        vx *= 0.95
        vy *= 0.96
        # 🔥 무작위 바람 효과 (불꽃의 자연스러운 흔들림)
        if random.random() < 0.3:
            vx += random.uniform(-0.5, 0.5)
            vy += random.uniform(-0.3, 0.1)
        # 생명력 감소
        life -= 1
        # 생명력이 남아있으면 계속 유지
        if life > 0:
            new_particles.append([x, y, vx, vy, life, max_life])
    fireball_explosion_particles = new_particles
def draw_fireball_explosion_particles():
    """파이어볼 폭발 파티클 - EffectRenderer 사용"""
    if fireball_explosion_particles:
        # fireball_explosion_particles를 EffectRenderer가 기대하는 형식으로 변환
        converted_particles = []
        for p in fireball_explosion_particles:
            if len(p) >= 6:  # [x, y, vx, vy, life, max_life]
                converted_particles.append({
                    'x': p[0],
                    'y': p[1],
                    'vx': p[2],
                    'vy': p[3],
                    'life': p[4],
                    'size': 3,  # 기본 크기
                    'alpha': int(255 * (p[4] / p[5])) if p[5] > 0 else 0,  # life 비율로 알파 계산
                    'color': (255, 100, 0)
                })
        if converted_particles:
            effect_renderer.draw_particles(SCREEN, converted_particles, (255, 100, 0))
def handle_ball():
    # 게임 상태 변수들
    global round_wins, round_losses, boss_speed_boost_timer, boss_fail_timer, is_waiting_for_serve, deuce_wins, deuce_losses
    # 플레이어 & 보스 게이지/스킬 시스템
    global special_gauge, special_ready, special_active, boss_special_gauge, boss_special_ready, boss_red_intensity
    global boss_special_gauge_stage4, boss_special_ready_stage4, boss_current_health  # 💪 체력형 보스 체력 변수
    # 충돌 쿨다운
    global player_collision_cooldown, boss_collision_cooldown, player_collision_handled, player_sound_cooldown
    # 공 물리 & 움직임
    global ball_vel, ball_angle, slow_ball_timer, horizontal_bounce_count, ball_impact_boost, ball_boost_decay_rate, ball_min_boost
    global player_last_shot_speed
    # 고스트샷 관련 변수들
    global mega_smashing_active, mega_smashing_bonus_applied, mega_smashing_meteor_trail, mega_smashing_boss_defense_count, mega_smashing_ghost_scatter, mega_smashing_ghost_scatter_time
    global mega_smashing_ghosts, dashholder_obtained, rolling_charges, rolling_charge_timer
    # 충돌 쿨다운 감소
    if player_collision_cooldown > 0:
        player_collision_cooldown -= 1
    if boss_collision_cooldown > 0:
        boss_collision_cooldown -= 1
    if player_sound_cooldown > 0:
        player_sound_cooldown -= 1
    # 프레임 시작 시 충돌 플래그 리셋 (매 프레임마다 리셋)
    player_collision_handled = False
    # 드라이브 & 파워스매싱 시스템
    global drive_ball_active, drive_hit_boss, ball_spin_strength, drive_speed_increase, drive_active, drive_spin_speed
    global power_smashing_original_speed, power_smashing_parabola_active, power_smashing_start_time, power_smashing_arc_strength
    global mega_smashing_active, mega_smashing_bonus_applied, mega_smashing_meteor_trail
    # 보스별 특수 스킬들
    global whip_hit_by_player, whip_active, original_speed, whip_original_ball_speed, meditation_active, meditation_timer, meditation_angle
    global stage4_magnetic_active, stage4_magnetic_timer, stage4_magnetic_radius, magnet_curve_angle, flame_trail_active, flame_trail_timer, flame_trail_phase
    global flame_trail_positions, flame_trail_start_time, flame_trail_base_vel, fireballs, fireball_cooldown, fireball_last_cast, fireball_speed
    global boss_throwing, boss_throw_timer, hongryun_hit_count, hongryun_ready
    # 아이템 & 효과 시스템
    global aipill_active, walls, rolling_charges, rolling_active, rolling_direction, rolling_timer
    global danger_sensor_obtained, danger_sensor_auto_dash_cooldown, danger_sensor_last_auto_dash_time
    # 애니메이션 & 이펙트
    global hit_animation_active, hit_animation_timer, boss_hit_timer, flame_particles, player_stunned_timer, player_knockback_vel
    global boss_fire_hit_timer  # 💪 보스 화염 타격 타이머
    # 방어 스킬들
    global speed_defense_active, speed_defense_timer, speed_defense_checked
    # 타이머들
    global last_tears_cast_time, quake_last_used_time
    special_gauge_max = get_max_gauge()  # 🔧 아카데미 스킬 적용된 최대치
    # 위험감지센서용 보스 히트 타이머 감소
    if boss_hit_timer > 0:
        boss_hit_timer -= 1
    # 💪 보스 화염 타격 타이머 감소
    if boss_fire_hit_timer > 0:
        boss_fire_hit_timer -= 1
    # === Stage 4 자기장 처리 ===
    if current_stage == 4 and stage4_magnetic_active:
        stage4_magnetic_timer -= 1
        distance = math.hypot(BALL.centerx - BOSS.centerx, BALL.centery - BOSS.centery)
        if distance < stage4_magnetic_radius:
            magnet_curve_angle += 4.1
            direction_to_player = pygame.math.Vector2(
                PLAYER.centerx - BALL.centerx,
                PLAYER.centery - BALL.centery
            )
            if direction_to_player.length() != 0:
                direction_to_player = direction_to_player.normalize()
            curve_vector = direction_to_player.rotate(magnet_curve_angle) * 1.8
            ball_vel[0] += curve_vector.x
            ball_vel[1] += curve_vector.y
            ball_vel[0] *= 1.04
            ball_vel[1] *= 1.04
            # 속도 상한
            current_speed = math.hypot(ball_vel[0], ball_vel[1])
            max_speed = BALL_BASE_SPEED * 2.2
            if current_speed > max_speed:
                scale = max_speed / current_speed
                ball_vel[0] *= scale
                ball_vel[1] *= scale
        if stage4_magnetic_timer <= 0:
            stage4_magnetic_active = False
            recover_speed = max(player_last_shot_speed, BALL_BASE_SPEED)
            direction = pygame.math.Vector2(ball_vel)
            if direction.length() == 0:
                direction = pygame.math.Vector2(0, 1)
            else:
                direction = direction.normalize()
            ball_vel = [direction.x * recover_speed, direction.y * recover_speed]
            magnet_curve_angle = 0
    # === Stage 4 명상타임 처리 ===
    if current_stage == 4 and meditation_active:
        meditation_timer -= 1
        meditation_angle += 9
        BALL.centerx = int(BOSS.centerx + math.cos(math.radians(meditation_angle)) * 80)
        BALL.centery = int(BOSS.centery + math.sin(math.radians(meditation_angle)) * 80)
        meditation_trails.append((BALL.centerx, BALL.centery, 200))
        meditation_trails[:] = [(x, y, a-15) for x, y, a in meditation_trails if a > 15][:12]
        if meditation_timer <= 0:
            meditation_active = False
            angle_deg = random.randint(-60, 60)
            speed = max(player_last_shot_speed, BALL_BASE_SPEED * random.uniform(1.1, 1.4))
            rad = math.radians(angle_deg)
            ball_vel = [speed * math.sin(rad), speed * math.cos(rad)]
            ball_angle = 0
            drive_active = True
            drive_spin_speed = random.choice([-0.6, 0.6])
        return
    # ✅ 서브 대기
    if is_waiting_for_serve:
        if is_player_serve:
            BALL.centerx = PLAYER.centerx
            BALL.bottom = PLAYER.top - 5
        else:
            BALL.centerx = BOSS.centerx
            BALL.top = BOSS.bottom + 5
        return
    # === Stage 5 화염탄 ===
    if current_stage == 5:
        now = pygame.time.get_ticks()
        # 🔥 라운드 시작 2.5초 후부터 화염탄 발사 가능
        if (now - fireball_last_cast > fireball_cooldown and 
            now - round_start_time >= 2500):
            fireball_last_cast = now
            fireball_cooldown = random.randint(3500, 5000)
            num_fireballs = random.randint(2, 3) if random.random() < 0.4 else 1
            # 🆕 화염탄 발사 효과음 재생
            SOUND_FIREBALL.play()
            for i in range(num_fireballs):
                pos = [BOSS.centerx, BOSS.bottom]
                offset_angle = random.uniform(-20, 20)
                dir_vec = pygame.math.Vector2(
                    PLAYER.centerx - BOSS.centerx,
                    PLAYER.centery - BOSS.centery
                ).normalize().rotate(offset_angle)
                vel = [dir_vec.x * fireball_speed, dir_vec.y * fireball_speed]
                fireballs.append([pos, vel])
            boss_throwing = True
            boss_throw_timer = 25      
        if boss_throwing:
            boss_throw_timer -= 1
            if boss_throw_timer <= 0:
                boss_throwing = False
        new_fireballs = []
        for pos, vel in fireballs:
            pos[0] += vel[0]
            pos[1] += vel[1]
            fireball_rect = pygame.Rect(pos[0]-8, pos[1]-8, 16, 16)
            if fireball_rect.colliderect(PLAYER):
                player_stunned_timer = int(0.3 * FPS)
                player_knockback_vel = random.choice([-18, 18])
                # 🔥 화염탄 폭발 이펙트 생성
                create_fireball_explosion(pos[0], pos[1])
                # 🔹 홍련 게이지 충전
                hongryun_hit_count += 1
                if hongryun_hit_count >= HONGRYUN_MAX_HITS:
                    hongryun_ready = True
                continue  # 화염탄 제거
            if 0 <= pos[0] <= WIDTH and 0 <= pos[1] <= HEIGHT:
                new_fireballs.append([pos, vel])
        fireballs = new_fireballs
        # 🔥 화염탄 폭발 파티클 업데이트
        update_fireball_explosion_particles()
    # === Stage 5 홍련폭염 (뱀 궤적) ===
    if flame_trail_active:
        flame_trail_timer -= 1
        flame_trail_positions.append((BALL.centerx, BALL.centery))
        if len(flame_trail_positions) > 30:
            flame_trail_positions.pop(0)
        effects_manager.spawn_flame_particles(BALL.centerx, BALL.centery, count=3)
        # 초기화
        if flame_trail_phase == 0:
            flame_trail_phase = 1
            flame_trail_start_time = pygame.time.get_ticks()
            flame_trail_base_vel = pygame.math.Vector2(
                PLAYER.centerx - BALL.centerx,
                PLAYER.centery - BALL.centery
            ).normalize()
        elapsed = (pygame.time.get_ticks() - flame_trail_start_time) / 1000.0
        # 0~1초 차징
        if elapsed < 1.0:
            BALL.x += math.sin(elapsed * 25) * 2
            BALL.y += math.cos(elapsed * 30) * 1
            return
        # 1초 이후 가속 + 뱀 궤적
        accel_elapsed = elapsed - 1.0
        max_speed = 6.0
        accel_time = 6.0
        current_speed = max_speed * min(1.0, accel_elapsed / accel_time)
        current_speed = max(0.001, current_speed ** 1.2)
        amplitude_x = min(40, 10 + accel_elapsed * 6)
        amplitude_y = min(20, 5 + accel_elapsed * 3)
        noise_x = random.uniform(-2, 2)
        noise_y = random.uniform(-1, 1)
        BALL.x += flame_trail_base_vel.x * current_speed + math.sin(accel_elapsed * 6) * amplitude_x + noise_x
        BALL.y += flame_trail_base_vel.y * current_speed + math.cos(accel_elapsed * 3) * amplitude_y + noise_y
        # 🔹 플레이어 충돌 처리 - 화려한 폭발 이벤트
        if BALL.colliderect(PLAYER):
            flame_trail_active = False
            flame_trail_positions.clear()
            player_stunned_timer = int(0.3 * FPS)
            player_knockback_vel = random.choice([-36, 36])
            # 🎆 대규모 화염 폭발 이벤트
            explosion_x = PLAYER.centerx
            explosion_y = PLAYER.top
            # 1️⃣ 중심 폭발 - 큰 화염구
            for ring in range(3):  # 3개의 링
                for angle_deg in range(0, 360, 15):  # 24방향
                    angle = math.radians(angle_deg)
                    speed = 8.0 - ring * 2.0  # 바깥 링일수록 느리게
                    size = 8 - ring * 2  # 바깥 링일수록 작게
                    vx = math.cos(angle) * speed
                    vy = math.sin(angle) * speed
                    flame_particles.append([
                        explosion_x, explosion_y,
                        vx, vy,
                        255,  # 알파
                        max(3, size)  # 크기
                    ])
            # 2️⃣ 화염 파편 - 작은 불꽃들 (80개)
            for _ in range(80):
                angle = random.uniform(0, 2*math.pi)
                speed = random.uniform(3.0, 12.0)
                vx = math.cos(angle) * speed
                vy = math.sin(angle) * speed
                # 다양한 크기의 파편
                size = random.choices([2, 3, 4, 5, 6], weights=[30, 25, 20, 15, 10])[0]
                flame_particles.append([
                    explosion_x + random.randint(-10, 10),
                    explosion_y + random.randint(-5, 5),
                    vx, vy,
                    255,
                    size
                ])
            # 3️⃣ 화염 기둥 효과 - 수직으로 솟아오르는 화염
            for i in range(15):
                for side in [-1, 0, 1]:  # 3개 기둥
                    column_x = explosion_x + side * 20
                    vy = -random.uniform(8.0, 15.0)  # 위로 솟구침
                    vx = side * random.uniform(0.5, 2.0)  # 약간 옆으로
                    flame_particles.append([
                        column_x + random.randint(-5, 5),
                        explosion_y,
                        vx, vy,
                        255,
                        random.randint(4, 7)
                    ])
            # 4️⃣ 스파크 효과 - 빠르게 튀는 작은 불씨들
            for _ in range(40):
                angle = random.uniform(0, 2*math.pi)
                speed = random.uniform(10.0, 18.0)  # 매우 빠름
                vx = math.cos(angle) * speed
                vy = math.sin(angle) * speed
                flame_particles.append([
                    explosion_x, explosion_y,
                    vx, vy,
                    255,
                    1  # 매우 작은 크기
                ])
            # 5️⃣ 화염 폭풍 효과 - 회전하는 화염
            for spiral in range(5):  # 5개의 나선
                base_angle = (spiral * 72) * math.pi / 180  # 72도씩 분리
                for i in range(10):
                    angle = base_angle + (i * 0.3)  # 나선형
                    distance = i * 4
                    spiral_x = explosion_x + math.cos(angle) * distance
                    spiral_y = explosion_y + math.sin(angle) * distance
                    # 나선을 따라 바깥으로 퍼지는 속도
                    vx = math.cos(angle) * 3.0
                    vy = math.sin(angle) * 3.0
                    flame_particles.append([
                        spiral_x, spiral_y,
                        vx, vy,
                        200,  # 약간 투명
                        random.randint(3, 5)
                    ])
            # 6️⃣ 화면 흔들림 효과를 위한 추가 시각 효과
            # 큰 플래시 효과를 위한 중심 폭발
            for _ in range(3):
                flash_size = random.randint(15, 25)
                flame_particles.append([
                    explosion_x + random.randint(-20, 20),
                    explosion_y + random.randint(-10, 10),
                    random.uniform(-1, 1),  # 거의 정지
                    random.uniform(-1, 1),
                    200,  # 반투명
                    flash_size  # 큰 크기
                ])
            # 🔊 시각적 임팩트를 위한 잔광 효과
            effects_manager.spawn_flame_particles(explosion_x, explosion_y, count=50)
            # 화면 전체 플래시 효과 (옵션)
            flash_surface = pygame.Surface((WIDTH, HEIGHT))
            flash_surface.fill((255, 200, 100))
            flash_surface.set_alpha(100)
            SCREEN.blit(flash_surface, (0, 0))
            return
    # --- 고스트샷 궤적 이동 (독립적 처리) ---
    if mega_smashing_active:
        if not power_smashing_parabola_active:
            handle_mega_smashing_trajectory()
        else:
            print(f"⚠️ 고스트샷 활성화되었지만 power_smashing_parabola_active={power_smashing_parabola_active}로 인해 실행 안됨")
    # --- 파워스매싱 포물선 궤적 이동 ---
    elif power_smashing_parabola_active:
        time_now = pygame.time.get_ticks()
        elapsed_time = (time_now - power_smashing_start_time) / 1000.0  # 초 단위
        # 파워스매싱만 처리 (고스트샷은 위에서 별도 처리)
        if False:  # 고스트샷 로직 제거
            # 🐍 고스트샷: 뱀처럼 구불거리고 예측불가능한 궤적
            # 패턴 선택 (시간에 따라 변화)
            pattern_phase = int(elapsed_time * 2) % 4  # 0.5초마다 패턴 변경
            if pattern_phase == 0:  # 🐍 뱀처럼 구불거리는 패턴
                snake_freq = 8.0 + math.sin(elapsed_time * 3) * 2  # 주파수 변화
                snake_amp = 6.0 + math.cos(elapsed_time * 2) * 3   # 진폭 변화
                # S자 움직임
                snake_x = math.sin(elapsed_time * snake_freq) * snake_amp
                # 진행 방향에 따른 추가 움직임
                progressive_x = math.sin(elapsed_time * 1.5) * 0.3  # 90% 감소
                horizontal_force = snake_x + progressive_x
                # 간혹 급격한 방향 전환 (15% 확률)
                if random.random() < 0.15:
                    horizontal_force *= -0.2  # 90% 감소
            elif pattern_phase == 1:  # 🌀 나선형 한바퀴 도는 패턴
                # 원형 궤도
                orbit_radius = 8.0 + elapsed_time * 2
                orbit_speed = 12.0  # 회전 속도
                circular_x = math.cos(elapsed_time * orbit_speed) * orbit_radius
                circular_y_component = math.sin(elapsed_time * orbit_speed) * 3  # Y축에도 영향
                horizontal_force = circular_x
                # 스파이럴 효과 추가
                spiral_factor = math.sin(elapsed_time * 20) * 2
                horizontal_force += spiral_factor
            elif pattern_phase == 2:  # ⚡ 지그재그 번개 패턴
                # 톱니파 움직임
                zigzag_period = 0.1  # 지그재그 주기
                zigzag_phase = (elapsed_time % zigzag_period) / zigzag_period
                if zigzag_phase < 0.5:
                    horizontal_force = 15.0  # 오른쪽으로 급격히
                else:
                    horizontal_force = -15.0  # 왼쪽으로 급격히
                # 진폭 변화
                amplitude_mod = math.sin(elapsed_time * 3) * 0.5 + 1.0
                horizontal_force *= amplitude_mod
            else:  # 🎯 불규칙한 텔레포트 패턴
                # 순간이동처럼 보이는 효과
                if random.random() < 0.3:  # 30% 확률로 순간이동
                    teleport_distance = random.uniform(-12, 12)
                    horizontal_force = teleport_distance * 3  # 강한 수평 이동
                else:
                    # 일반적인 리사주 곡선
                    freq1 = 3.7 + random.uniform(-0.5, 0.5)
                    horizontal_force = math.sin(freq1 * elapsed_time) * 5
            # 고스트샷 방향성 적용
            direction_factor = power_smashing_arc_strength / abs(power_smashing_arc_strength) if power_smashing_arc_strength != 0 else 1
            horizontal_force *= direction_factor
            ball_vel[0] += horizontal_force
            # 🚀 수직 움직임 - 위로 진행하되 약간의 변화 추가
            base_upward_force = -3.5  # 기본 위쪽 힘
            # 패턴에 따른 수직 변화
            if pattern_phase == 1:  # 나선형일 때 Y축 변화
                vertical_variation = math.sin(elapsed_time * 12) * 1.5
            elif pattern_phase == 2:  # 지그재그일 때 미세한 상하 움직임
                vertical_variation = math.cos(elapsed_time * 15) * 0.8
            else:
                vertical_variation = math.sin(elapsed_time * 5) * 1.0
            vertical_force = base_upward_force + vertical_variation
            # 가끔 부스트 (10% 확률)
            if random.random() < 0.1:
                vertical_force -= random.uniform(0.2, 0.5)  # 더 빠르게 위로 (90% 감소)
            ball_vel[1] += vertical_force
            # 속도 리미터 (너무 빨라지는 것 방지하되 여전히 빠름)
            max_speed = 4.5  # 고스트샷 속도 90% 감소 (45 -> 4.5)
            current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
            if current_speed > max_speed:
                speed_ratio = max_speed / current_speed
                ball_vel[0] *= speed_ratio
                ball_vel[1] *= speed_ratio
        else:
            # 일반 파워스매싱: 기존 포물선 궤적
            # 수평 이동: 강한 방향성 + 적당한 랜덤 변화
            horizontal_decay = max(0.4, 1.0 - elapsed_time * 0.15)  # 적당히 감소, 최소 40% 유지
            # 적당한 랜덤 요소 추가
            chaos_factor = math.sin(elapsed_time * 5.0) * 0.2 + random.uniform(-0.15, 0.15)
            horizontal_force = power_smashing_arc_strength * horizontal_decay * (1.0 + chaos_factor)
            ball_vel[0] += horizontal_force
            # 수직 이동: 뚜렷한 중력 효과로 명확한 포물선
            # 포물선의 상승과 하강을 뚜렷하게
            if elapsed_time < 1.8:  # 첫 1.8초 동안은 포물선 상승
                # 초기에는 확실하게 위로, 시간이 지나면서 감소
                base_lift = power_smashing_gravity_effect * 2.2 * (1.8 - elapsed_time) / 1.8  # 뚜렷하게 증가
                # 적당한 수직 변화 요소 추가
                vertical_chaos = math.cos(elapsed_time * 5.0) * 0.015
                vertical_lift = base_lift + vertical_chaos
                ball_vel[1] -= vertical_lift  # 위로 밀어올림 (음수)
                vertical_force = -vertical_lift
            else:  # 1.8초 후부터는 중력으로 뚜렷하게 하강
                base_pull = power_smashing_gravity_effect * 1.8 * (elapsed_time - 1.8)  # 뚜렷한 하강
                # 적당한 하강 변화 요소 추가
                descent_chaos = math.sin(elapsed_time * 7.0) * 0.015
                vertical_pull = base_pull + descent_chaos
                ball_vel[1] += vertical_pull  # 아래로 당김 (양수)
                vertical_force = vertical_pull
        # 디버깅 출력 (가끔씩만)
        if time_now % 120 == 0:  # 2초마다
            print(f"🎯 파워스매싱 포물선: 경과시간 {elapsed_time:.2f}s, 수평력 {horizontal_force:.3f}, 수직력 {vertical_force:.3f}")
    # --- 드라이브 이동 ---
    if drive_active:
        ball_vel[0] += drive_spin_speed
        ball_angle += drive_spin_speed * 25
        drive_spin_speed *= 0.995
        if abs(drive_spin_speed) < 0.05:
            drive_active = False
    # --- 수직 정지 방지 ---
    if abs(ball_vel[1]) < 0.5:
        ball_vel[1] += random.choice([-1, 1]) * 1.5
    # --- 위험감지센서 자동 대쉬 로직 ---
    # 디버깅: 센서 상태 확인
    if danger_sensor_obtained:
        print(f"센서 상태 - obtained: {danger_sensor_obtained}, enabled: {danger_sensor_enabled}, ball_vel[1]: {ball_vel[1]:.2f}, BALL.centery: {BALL.centery:.1f}, HEIGHT*0.75: {HEIGHT * 0.75:.1f}")
    # 공이 화면의 절반 이하(플레이어와 중간지점의 가운데)로 내려왔을 때만 탐지
    if danger_sensor_obtained and danger_sensor_enabled and ball_vel[1] > 0 and BALL.centery > HEIGHT * 0.75:  # 공이 아래로 내려오고 화면 3/4 지점 이하
        current_time = pygame.time.get_ticks()
        # 쿨타임 체크 (10초)
        if not hasattr(handle_ball, 'danger_sensor_last_activation_time'):
            handle_ball.danger_sensor_last_activation_time = 0
        # 쿨타임 중이면 위험감지센서만 비활성화하고 공 이동은 계속
        sensor_can_activate = current_time - handle_ball.danger_sensor_last_activation_time >= 10000
        # 공의 예상 위치 계산
        time_to_reach_player = (PLAYER.centery - BALL.centery) / ball_vel[1] if ball_vel[1] > 0 else 0
        if 0 < time_to_reach_player < 60:  # 1초 이내에 도달할 예정
            predicted_x = BALL.centerx + ball_vel[0] * time_to_reach_player
            # 플레이어가 현재 속도로 이동했을 때 도달할 수 있는지 계산
            player_speed = 8  # 플레이어 기본 이동 속도
            player_max_distance = player_speed * time_to_reach_player  # 플레이어 최대 이동 거리
            distance_to_predicted = abs(predicted_x - PLAYER.centerx)
            print(f"감지센서 계산 - time_to_reach: {time_to_reach_player:.1f}, predicted_x: {predicted_x:.1f}, distance: {distance_to_predicted:.1f}, max_distance: {player_max_distance:.1f}")
            # 도달할 수 없는 상황이면 자동 대쉬 (쿨타임 체크 포함)
            if distance_to_predicted > player_max_distance + PADDLE_WIDTH // 2 and sensor_can_activate:
                # 대쉬 방향 결정
                dash_direction = 1 if predicted_x > PLAYER.centerx else -1
                print(f"대쉬 조건 체크 - charges: {rolling_charges}, active: {rolling_active}, waiting: {is_waiting_for_serve}")
                # 대쉬 실행 - 위험감지센서는 게이지와 토큰 소모 없이 사용
                if not rolling_active and not is_waiting_for_serve:
                    global is_danger_sensor_dash
                    rolling_active = True
                    is_danger_sensor_dash = True  # 위험감지센서 대쉬 플래그 설정
                    # 대시기어 효과: 대시 거리 10% 증가
                    base_rolling_timer = 15  # 기본 대쉬 시간
                    if dashgear_obtained:
                        base_rolling_timer = 16  # 0.267초 대쉬 (15 * 1.1)
                    # 아카데미 스킬 효과 적용: 대쉬 거리 증가 (도약)
                    jump_bonus = academy.get_skill_bonus("dash_jump")  # 도약: 대쉬거리 증가
                    total_distance_bonus = jump_bonus
                    base_rolling_timer = int(base_rolling_timer * (1 + total_distance_bonus))
                    # 스킬 효과 적용: 대쉬 거리 증가 (기존 시스템 유지)
                    skill_distance_boost = skill.apply_dash_distance_boost(base_rolling_timer)
                    rolling_timer = int(skill_distance_boost)
                    rolling_direction = dash_direction
                    # rolling_charges -= 1  # 🚫 위험감지센서 자동 대쉬는 토큰을 소모하지 않음
                    # 🆕 위험감지센서 자동 대쉬는 게이지와 토큰을 소모하지 않음
                    # 쿨타임 설정
                    handle_ball.danger_sensor_last_activation_time = current_time
                    # 대쉬 효과음 재생
                    SOUND_DASH.play()
                else:
                    print(f"대쉬 조건 불만족 - charges: {rolling_charges}, active: {rolling_active}, waiting: {is_waiting_for_serve}")
    # --- 🏓 적응형 물리 효과: 충돌 후 점진적 감속 ---
    # 🌊 저속에서는 감속 완화, 고속에서는 감속 강화
    current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
    if ball_impact_boost > ball_min_boost:
        # 속도별 적응형 감속률 적용
        if current_speed < 10:  # 저속: 감속 60% 완화
            adaptive_decay_rate = 1.0 - (1.0 - ball_boost_decay_rate) * 0.4
        elif current_speed < 15:  # 중속: 기본 감속
            adaptive_decay_rate = ball_boost_decay_rate
        else:  # 고속: 감속 강화
            speed_ratio = min(current_speed / 25.0, 1.0)
            penalty_factor = 1.0 + speed_ratio * 0.5
            adaptive_decay_rate = 1.0 - (1.0 - ball_boost_decay_rate) * penalty_factor
        ball_impact_boost *= adaptive_decay_rate
        # 최소값 보정
        if ball_impact_boost < ball_min_boost:
            ball_impact_boost = ball_min_boost
        # 디버그 출력 (가끔씩만)
        # if pygame.time.get_ticks() % 300 < 16:  # 대략 5초마다
            # pass
    # --- 🌪️ 스핀 효과 처리 ---
    global ball_spin_strength, ball_spin_direction, ball_spin_decay
    if ball_spin_strength > 0.01:  # 스핀이 충분히 남아있을 때
        # 스핀에 의한 곡선 이동 (공의 횡방향 속도에 영향)
        spin_force = ball_spin_strength * ball_spin_direction * 3.5  # 커브율 증가
        ball_vel[0] += spin_force
        # 스핀 감소
        ball_spin_strength *= ball_spin_decay
        print(f"🌪️ 스핀 적용: strength={ball_spin_strength:.3f}, direction={ball_spin_direction}, force={spin_force:.2f}")
    else:
        # 스핀이 거의 없으면 완전히 제거
        ball_spin_strength = 0.0
        ball_spin_direction = 0
        # 드라이브 공 상태 비활성화 (자연스럽게 스핀이 끝난 경우)
        if drive_ball_active:
            drive_ball_active = False
            drive_hit_boss = False
            print("🌟 드라이브 효과가 자연스럽게 끝나서 원래 색상으로 복구됨!")
    # --- 🛡️ 무한 수평 왕복 방지 시스템 ---
    global horizontal_movement_timer, horizontal_threshold, max_horizontal_time, angle_correction_strength
    # Y속도가 매우 작으면 (거의 수평) 타이머 증가
    current_y_speed = abs(ball_vel[1] * ball_impact_boost)
    if current_y_speed < horizontal_threshold:
        horizontal_movement_timer += 1
        # 일정 시간 이상 수평 움직임이 지속되면 점진적으로 Y속도 보정
        if horizontal_movement_timer > max_horizontal_time:
            correction_factor = min(1.0, (horizontal_movement_timer - max_horizontal_time) / 60.0)  # 1초에 걸쳐 점진적 보정
            y_correction = angle_correction_strength * correction_factor
            # 공이 위쪽에 있으면 아래로, 아래쪽에 있으면 위로 보정
            if BALL.centery < HEIGHT // 2:
                ball_vel[1] += y_correction  # 아래쪽으로 보정
            else:
                ball_vel[1] -= y_correction  # 위쪽으로 보정
            if horizontal_movement_timer % 60 == 0:  # 1초마다 로그
                print(f"🛡️ 수평 움직임 보정 적용: timer={horizontal_movement_timer}, correction={y_correction:.3f}")
    else:
        # Y속도가 충분하면 타이머 리셋
        if horizontal_movement_timer > 0:
            print(f"🛡️ 수평 움직임 타이머 리셋: {horizontal_movement_timer} → 0")
            horizontal_movement_timer = 0
    # --- 공 이동 (현실적인 물리 부스트 적용) ---
    BALL.x += ball_vel[0] * ball_impact_boost
    BALL.y += ball_vel[1] * ball_impact_boost
    # --- 벽 충돌 처리 ---
    if BALL.left <= 0:
        BALL.left = 0
        ball_vel[0] *= -1
        SOUND_WALL.play()
        # 스테이지 1에서 벽 충돌 시 테두리 깜빡임 효과 활성화
        if current_stage == 1:
            border_flash_active = True
            border_flash_timer = border_flash_duration
            print(f"🔥 벽 충돌! 테두리 효과 활성화: stage={current_stage}, timer={border_flash_timer}")
        # 스테이지 2에서 벽 충돌 시 정글 테두리 효과 활성화
        elif current_stage == 2:
            stage2_border_flash_timer = stage2_border_flash_duration
            # 공 속도 계산
            current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
            # 속도에 비례한 잎사귀 개수 계산 (느릴 때 1-2개, 빠를 때 5-6개)
            # 속도 범위: 대략 3(느림) ~ 25(빠름)
            min_leaves = 1
            max_leaves = 6
            # 속도를 0-1 범위로 정규화 (3-25 속도 범위 기준)
            speed_normalized = min(1.0, max(0.0, (current_speed - 3) / 22))
            # 잎사귀 개수 계산
            leaves_count = int(min_leaves + speed_normalized * (max_leaves - min_leaves))
            # 최소값과 최대값 범위 보장
            leaves_count = max(1, min(6, leaves_count))
            # 충돌 위치에서 디테일한 잎사귀 생성
            leaf_types = ['maple', 'oak', 'tropical']
            for i in range(leaves_count):
                leaf = {
                    'x': 0 if BALL.left <= 0 else WIDTH,  # 좌벽 또는 우벽
                    'y': BALL.centery + random.randint(-50, 50),
                    'vx': random.uniform(1.0, 3.0) if BALL.left <= 0 else random.uniform(-3.0, -1.0),
                    'vy': random.uniform(0.5, 2.5),
                    'rotation': random.uniform(0, 360),
                    'rotation_speed': random.uniform(-8, 8),
                    'type': random.choice(leaf_types),
                    'color': random.choice([
                        (34, 139, 34),  # 숲 녹색
                        (0, 128, 0),    # 중간 녹색  
                        (85, 107, 47),  # 올리브 녹색
                        (107, 142, 35), # 황록색
                        (154, 205, 50), # 연두색
                        (50, 100, 50),  # 진한 녹색
                    ]),
                    'size': random.randint(12, 25),
                    'life': 150  # 2.5초 동안 떨어짐
                }
                stage2_leaves.append(leaf)
            print(f"🌿 정글 벽 충돌! 속도={current_speed:.1f}, 잎사귀={leaves_count}개")
        # 🌊 벽 충돌 시간 기록 (관성 보존용)
        last_wall_collision_time = pygame.time.get_ticks()
        if current_stage != 2:  # 스테이지 2가 아닐 때만 속도 재계산
            current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
        print(f"🧱 좌벽 충돌! 현재 속도: {current_speed:.1f}, 관성 보존 시작")
        # 충전가방 효과: 공이 벽에 닿을 때마다 플레이어 패들 충전량의 20% 충전
        if chargebag_obtained and not aipill_active:
            # 플레이어 패들이 공에 닿을 때 얻는 게이지량의 20% 계산
            base_gauge_gain = 80
            skill_gauge_boost = skill.apply_gauge_boost(0)
            total_gauge_gain = base_gauge_gain + skill_gauge_boost
            chargebag_gain = int(total_gauge_gain * 0.2)  # 20%
            print(f"🔍 DEBUG: 충전가방 효과 적용 시도 (게이지 증가: {chargebag_gain})")
            old_gauge = special_gauge
            # 🔧 동적 최대치 계산 적용
            current_max = get_max_gauge()
            special_gauge = min(current_max, special_gauge + chargebag_gain)
            print(f"충전가방 효과! 게이지 충전: {old_gauge} → {special_gauge} (+{chargebag_gain})")
    elif BALL.right >= WIDTH:
        BALL.right = WIDTH
        ball_vel[0] *= -1
        SOUND_WALL.play()
        # 스테이지 1에서 벽 충돌 시 테두리 깜빡임 효과 활성화
        if current_stage == 1:
            border_flash_active = True
            border_flash_timer = border_flash_duration
            print(f"🔥 벽 충돌! 테두리 효과 활성화: stage={current_stage}, timer={border_flash_timer}")
        # 스테이지 2에서 벽 충돌 시 정글 테두리 효과 활성화
        elif current_stage == 2:
            stage2_border_flash_timer = stage2_border_flash_duration
            # 공 속도 계산
            current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
            # 속도에 비례한 잎사귀 개수 계산 (느릴 때 1-2개, 빠를 때 5-6개)
            # 속도 범위: 대략 3(느림) ~ 25(빠름)
            min_leaves = 1
            max_leaves = 6
            # 속도를 0-1 범위로 정규화 (3-25 속도 범위 기준)
            speed_normalized = min(1.0, max(0.0, (current_speed - 3) / 22))
            # 잎사귀 개수 계산
            leaves_count = int(min_leaves + speed_normalized * (max_leaves - min_leaves))
            # 최소값과 최대값 범위 보장
            leaves_count = max(1, min(6, leaves_count))
            # 충돌 위치에서 디테일한 잎사귀 생성
            leaf_types = ['maple', 'oak', 'tropical']
            for i in range(leaves_count):
                leaf = {
                    'x': 0 if BALL.left <= 0 else WIDTH,  # 좌벽 또는 우벽
                    'y': BALL.centery + random.randint(-50, 50),
                    'vx': random.uniform(1.0, 3.0) if BALL.left <= 0 else random.uniform(-3.0, -1.0),
                    'vy': random.uniform(0.5, 2.5),
                    'rotation': random.uniform(0, 360),
                    'rotation_speed': random.uniform(-8, 8),
                    'type': random.choice(leaf_types),
                    'color': random.choice([
                        (34, 139, 34),  # 숲 녹색
                        (0, 128, 0),    # 중간 녹색  
                        (85, 107, 47),  # 올리브 녹색
                        (107, 142, 35), # 황록색
                        (154, 205, 50), # 연두색
                        (50, 100, 50),  # 진한 녹색
                    ]),
                    'size': random.randint(12, 25),
                    'life': 150  # 2.5초 동안 떨어짐
                }
                stage2_leaves.append(leaf)
            print(f"🌿 정글 벽 충돌! 속도={current_speed:.1f}, 잎사귀={leaves_count}개")
        # 🌊 벽 충돌 시간 기록 (관성 보존용)
        last_wall_collision_time = pygame.time.get_ticks()
        if current_stage != 2:  # 스테이지 2가 아닐 때만 속도 재계산
            current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
        print(f"🧱 우벽 충돌! 현재 속도: {current_speed:.1f}, 관성 보존 시작")
        # 충전가방 효과: 공이 벽에 닿을 때마다 플레이어 패들 충전량의 20% 충전
        if chargebag_obtained and not aipill_active:
            # 플레이어 패들이 공에 닿을 때 얻는 게이지량의 20% 계산
            base_gauge_gain = 80
            skill_gauge_boost = skill.apply_gauge_boost(0)
            total_gauge_gain = base_gauge_gain + skill_gauge_boost
            chargebag_gain = int(total_gauge_gain * 0.2)  # 20%
            print(f"🔍 DEBUG: 충전가방 효과 적용 시도 (게이지 증가: {chargebag_gain})")
            old_gauge = special_gauge
            # 🔧 동적 최대치 계산 적용
            current_max = get_max_gauge()
            special_gauge = min(current_max, special_gauge + chargebag_gain)
            print(f"충전가방 효과! 게이지 충전: {old_gauge} → {special_gauge} (+{chargebag_gain})")
    # --- 수평만 튕김 카운트 ---
    if abs(ball_vel[1]) < 1 and (BALL.left <= 0 or BALL.right >= WIDTH):
        horizontal_bounce_count += 1
    else:
        horizontal_bounce_count = 0
    # --- 무승부 처리 ---
    if horizontal_bounce_count >= 6:
        show_fade_text("무승부! 다시 대결!")
        reset_round()
        return
    # --- 천장 충돌 (플레이어 점수) ---
    if BALL.top <= 0:
        # 💪 체력형 보스전에서는 공이 보스 뒤로 나가지 않도록 바리케이트 적용
        if current_stage in boss_health_stages:
            # 🚫 스테이지 6에서 파워 스킬들이 벽에 맞으면 종료
            if current_stage == 6:
                # 드라이브 종료
                if drive_ball_active:
                    drive_ball_active = False
                    drive_hit_boss = False
                    drive_speed_increase = 0.0
                    ball_spin_strength = 0.0
                    ball_spin_direction = 0
                    print("🚫 스테이지 6: 드라이브가 벽에 맞아 종료됨!")
                # 파워스매싱 종료
                if power_smashing_parabola_active:
                    power_smashing_parabola_active = False
                    power_smashing_direction = None
                    power_smashing_trails.clear()
                    power_smashing_particles.clear()
                    print("🚫 스테이지 6: 파워스매싱이 벽에 맞아 종료됨!")
                # 고스트샷 종료
                if mega_smashing_active:
                    mega_smashing_active = False
                    mega_smashing_bonus_applied = False
                    mega_smashing_meteor_trail.clear()
                    print("🚫 스테이지 6: 고스트샷이 벽에 맞아 종료됨!")
            # 공을 경계에서 튕겨냄 (바리케이트 효과)
            BALL.top = 0
            ball_vel[1] = abs(ball_vel[1])  # 아래쪽으로 방향 전환
            # 바리케이트 충돌 이펙트 (텍스트 없이 파티클만)
            effects_manager.spawn_star_particles(BALL.centerx, 10, count=8)
            return
        # 🧠 AI 학습: 보스가 공을 놓쳤음 (제거됨)
        if deuce_mode:
            deuce_wins += 1
            show_winner_text("플레이어")
            show_score(SCREEN, deuce_wins, deuce_losses, WIDTH, HEIGHT, draw_field, draw_objects)
            # 스테이지 2에서 플레이어가 라운드 이길 때마다 악어 짧은 울상
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('sad')
        else:
            round_wins += 1
            # 🏗️ GameState 동기화 및 이벤트 발생
            game_state.round_wins = round_wins
            emit_event(EventType.ROUND_WIN, {'stage': current_stage, 'score': round_wins})
            show_winner_text("플레이어")
            show_score(SCREEN, round_wins, round_losses, WIDTH, HEIGHT, draw_field, draw_objects)
            # 스테이지 2에서 플레이어가 라운드 이길 때마다 악어 짧은 울상
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('sad')
        # 듀스 시스템 체크
        result = check_deuce_system()
        if result == "player_win":
            # 스테이지 2에서 플레이어 승리 시 악어 울상
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('sad')
            show_result(True)
            return
        elif result == "boss_win":
            # 스테이지 2에서 플레이어 패배 시 악어 활짝 웃기
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('happy')
            show_result(False)
            return
        elif result == "deuce_started" or result == "deuce_restart":
            # 듀스 시작/재시작 시 점수 표시 업데이트
            show_score(SCREEN, deuce_wins, deuce_losses, WIDTH, HEIGHT, draw_field, draw_objects)
        go_to_next_round()
        return
    # 🆕 벽돌 충돌 검사 (공이 벽돌 영역을 통과할 때)
    wall_hit = False
    for wall in walls:
        if BALL.colliderect(wall["rect"]):
            # 벽돌에 맞은 횟수 증가
            wall["hit_count"] += 1
            wall["crack_level"] = wall["hit_count"]
            # 공 튕기기
            ball_vel[1] = -abs(ball_vel[1])  # 위로 튕기기
            ball_vel[0] *= 0.8  # 좌우 속도 감소
            # 벽돌 파괴 효과음
            SOUND_WALL.play()
            print(f"벽돌에 맞음! ({wall['hit_count']}/2)")
            # 충전가방 효과: 공이 벽에 닿을 때마다 플레이어 패들 충전량의 20% 충전
            if chargebag_obtained and not aipill_active:
                # 플레이어 패들이 공에 닿을 때 얻는 게이지량의 20% 계산
                base_gauge_gain = 80
                skill_gauge_boost = skill.apply_gauge_boost(0)
                total_gauge_gain = base_gauge_gain + skill_gauge_boost
                chargebag_gain = int(total_gauge_gain * 0.2)  # 20%
                old_gauge = special_gauge
                # 🔧 동적 최대치 계산 적용
                current_max = get_max_gauge()
                special_gauge = min(current_max, special_gauge + chargebag_gain)
                print(f"충전가방 효과! 게이지 충전: {old_gauge} → {special_gauge} (+{chargebag_gain})")
            # 벽돌이 파괴되면 handle_wall에서 처리됨
            wall_hit = True
            break
    # 🗿 스테이지 2 위기 상황 바위 충돌 판정 (보스 실점 방지)
    rock_hit = False
    if current_stage == 2 and animated_bg_stage2 is not None:
        # 바위와 공 충돌 체크 (바위 파괴)
        if animated_bg_stage2.check_ball_rock_collision(BALL):
            # 공 반사
            ball_vel[0] = -ball_vel[0] * random.uniform(0.9, 1.1)
            ball_vel[1] = -ball_vel[1] * random.uniform(0.9, 1.1)
            rock_hit = True
            print(f"💥 바위 파괴! 공 반사!")
        else:
            # 기존 충돌 체크 (떨어지는 바위는 파괴 안됨)
            crisis_rocks = animated_bg_stage2.get_crisis_rocks()
            ball_rect = BALL
            for rock in crisis_rocks:
                if ball_rect.colliderect(rock['collision_rect']):
                    # 벽돌과 같은 방식으로 공 반사
                    # 위쪽에서 충돌 시 위로 반사
                    if ball_vel[1] > 0:  # 아래로 가던 공
                        ball_vel[1] = -abs(ball_vel[1])  # 위로 반사
                        BALL.bottom = rock['collision_rect'].top - 1
                    else:  # 위로 가던 공
                        ball_vel[1] = abs(ball_vel[1])  # 아래로 반사
                        BALL.top = rock['collision_rect'].bottom + 1
                    # 좌우 반사도 처리
                    if abs(BALL.centerx - rock['collision_rect'].centerx) > rock['collision_rect'].width // 3:
                        ball_vel[0] = -ball_vel[0]
                    rock_hit = True
                    print(f"💎 위기 상황 바위 충돌! 보스 실점 방지!")
                    break
    # --- 바닥 충돌 (보스 점수) - 바위에 맞지 않았을 때만 ---
    if BALL.bottom >= HEIGHT and not rock_hit:
        # 🏆 플레이어 미스 기록 및 실수 분석 - 강화된 실수 감지
        ball_distance = abs(BALL.centery - PLAYER.centery)
        ball_speed = math.hypot(ball_vel[0], ball_vel[1])
        # 치명적 실수 판정 (더 엄격한 기준)
        if ball_speed < 10 and ball_distance < 120:  # 느리고 가까운 공을 놓침 (기준 완화로 더 많이 감지)
            record_critical_miss()
        elif ball_distance < 80:  # 가까운 공을 놓침 (기준 완화)
            record_missed_opportunity()
        elif ball_speed < 6:  # 매우 느린 공을 놓침 (새로 추가)
            record_critical_miss()
        # 연속 실수에 대한 추가 페널티
        if player_analyzer and player_analyzer.stats.current_miss_streak > 2:
            record_poor_timing_hit()  # 연속 실수시 나쁜 타이밍으로 기록
        # 일반 미스 기록
        try:
            if player_analyzer:
                player_analyzer.record_miss()
        except:
            pass
        # 벽돌이 없거나 벽돌을 맞지 않았으면 보스 점수
        if deuce_mode:
            deuce_losses += 1
            boss_name = boss_names.get(current_stage, "보스")
            show_winner_text(boss_name)
            show_score(SCREEN, deuce_wins, deuce_losses, WIDTH, HEIGHT, draw_field, draw_objects)
            # 스테이지 2에서 보스가 라운드 이길 때마다 악어 짧은 웃음
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('happy')
        else:
            round_losses += 1
            # 🏗️ GameState 동기화 및 이벤트 발생
            game_state.round_losses = round_losses
            emit_event(EventType.ROUND_LOSE, {'stage': current_stage, 'score': round_losses})
            boss_name = boss_names.get(current_stage, "보스")
            show_winner_text(boss_name)
            show_score(SCREEN, round_wins, round_losses, WIDTH, HEIGHT, draw_field, draw_objects)
            # 스테이지 2에서 보스가 라운드 이길 때마다 악어 짧은 웃음
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('happy')
        # 듀스 시스템 체크
        result = check_deuce_system()
        if result == "player_win":
            # 스테이지 2에서 플레이어 승리 시 악어 울상
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('sad')
            show_result(True)
            return
        elif result == "boss_win":
            # 스테이지 2에서 플레이어 패배 시 악어 활짝 웃기
            if current_stage == 2 and animated_bg_stage2:
                animated_bg_stage2.set_expression('happy')
            show_result(False)
            return
        elif result == "deuce_started" or result == "deuce_restart":
            # 듀스 시작/재시작 시 점수 표시 업데이트
            show_score(SCREEN, deuce_wins, deuce_losses, WIDTH, HEIGHT, draw_field, draw_objects)
        go_to_next_round()
        return
    # --- 공 속도 느려질 때 보정 (파워스매싱 활성화 시 면역) ---
    current_speed = math.hypot(ball_vel[0], ball_vel[1])
    if current_speed < BALL_BASE_SPEED * 0.85 and not special_active:  # 🚀 파워스매싱 중에는 보정 무시
        slow_ball_timer += 1
        if slow_ball_timer >= 180:
            direction = pygame.math.Vector2(ball_vel).normalize()
            ball_vel[0] = direction.x * BALL_BASE_SPEED
            ball_vel[1] = direction.y * BALL_BASE_SPEED
            slow_ball_timer = 0
    else:
        slow_ball_timer = 0
        # === Stage 3 눈물샤워 충돌 처리 ===
    if tear_shower_active and BALL.colliderect(PLAYER):
        player_stunned_timer = int(0.3 * FPS)
        player_knockback_vel = random.choice([-12, 12])
        # 🚀 성능 최적화: 파티클 개수를 절반으로 줄임 (12 → 6)
        for _ in range(6):
            angle = random.uniform(200, 340)
            speed = random.uniform(1.0, 3.0)
            vx = math.cos(math.radians(angle)) * speed
            vy = math.sin(math.radians(angle)) * speed
            tear_particles.append([
                PLAYER.centerx, PLAYER.top,
                vx, vy,
                255,                   # 알파
                random.randint(2, 4)   # 크기
            ])
    # --- 플레이어 충돌 ---
    # 공이 패들과 충돌하고, 공이 위로 올라가지 않는지 확인 (중복 충돌 방지)
    # 패들 끝부분 충돌도 처리하기 위해 Y속도 조건 완화
    # 측면 충돌도 허용하기 위해 Y속도 조건을 더 완화 (>= -10)
    # 충돌 쿨다운이 없고 handle_player에서 처리되지 않았을 때만 처리
    # 서브 대기 중에는 충돌 체크하지 않음
    # handle_player가 놓친 충돌 처리 (Y속도 조건 제거 - handle_player와 동일하게)
    if BALL.colliderect(PLAYER) and player_collision_cooldown <= 0 and not player_collision_handled and not is_waiting_for_serve:
        # 디버그: 충돌 위치 정보
        collision_x = BALL.centerx - PLAYER.centerx
        collision_side = "LEFT" if collision_x < 0 else "RIGHT"
        edge_distance = abs(collision_x) - (PADDLE_WIDTH / 2)
        print(f"🎯 handle_ball 충돌! (handle_player에서 놓친 충돌) 위치: {collision_side}, 중심거리: {collision_x:.1f}, 가장자리거리: {edge_distance:.1f}, Y속도: {ball_vel[1]:.1f}")
        # 🏗️ 충돌 이벤트 발생
        emit_event(EventType.BALL_HIT_PLAYER, {
            'collision_x': collision_x,
            'collision_side': collision_side,
            'ball_speed': (ball_vel[0], ball_vel[1])
        })
        # 💥 고스트샷 종료 (플레이어 패들에 돌아왔을 때)
        # 고스트샷 첫 2초 동안은 패들 충돌을 무시하고 계속 진행
        if mega_smashing_active:
            elapsed_time = (pygame.time.get_ticks() - mega_smashing_start_time) / 1000
            if elapsed_time > 2.0:  # 2초 이후에만 고스트샷 종료
                mega_smashing_active = False
                mega_smashing_bonus_applied = False
                mega_smashing_meteor_trail.clear()
                mega_smashing_ghosts.clear()  # 귀신들 제거
                mega_smashing_ghost_scatter = False  # 흩어짐 상태 리셋
                # 🔧 고스트샷 종료 시 토큰 충전 타이머 초기화 (handle_ball에서도 처리)
                base_charges = 1
                holder_bonus = 1 if dashholder_obtained else 0
                amplification_bonus = academy.get_skill_bonus("dash_amplification")
                max_charges = int(base_charges + holder_bonus + amplification_bonus)
                print(f"[DEBUG] (handle_ball) 고스트샷 종료 - 현재 토큰: {rolling_charges}/{max_charges}, 타이머: {rolling_charge_timer}")
                # 토큰이 부족한 경우 무조건 충전 타이머 설정
                if rolling_charges < max_charges:
                    # 경량화 스킬 효과 적용
                    lightweight_bonus = academy.get_skill_bonus("dash_lightweight")
                    charge_time_reduction = lightweight_bonus
                    base_charge_time = 90  # 1.5초
                    rolling_charge_timer = int(base_charge_time * (1 - charge_time_reduction))
                    print(f"💥 고스트샷 종료! (handle_ball) 토큰 충전 시작 (타이머: {rolling_charge_timer})")
                    print(f"[DEBUG] (handle_ball) 충전 타이머 강제 설정: {rolling_charge_timer}")
                else:
                    print(f"💥 고스트샷 종료! (handle_ball) 토큰 이미 최대: {rolling_charges}/{max_charges}")
            else:
                print(f"🌟 고스트샷 궤적 진행 중 ({elapsed_time:.1f}/2.0초) - 패들 충돌 무시 (handle_ball)")
        if current_stage == 4 and boss_special_ready_stage4:
            stage4_magnetic_active = True
            stage4_magnetic_timer = 150
            boss_special_ready_stage4 = False
            boss_special_gauge_stage4 = 0
            show_speech("굴절자기장!", duration=90)
        if current_stage <= 5 and random.random() < boss_speed_config[current_stage]["fail_chance"]:
            boss_fail_timer = 60
        tear_chance = boss_speed_config[current_stage].get("tear_chance", 0.13) if current_stage <= 5 else 0.13
        if boss_fail_timer > 0:
            tear_chance = min(1.0, tear_chance + 0.3)
        time_now = pygame.time.get_ticks()
        if current_stage == 3:
            if time_now - last_tears_cast_time >= TEARS_COOLDOWN:
                if random.random() < tear_chance:
                    activate_tears_of_pain()
                    show_speech("눈물샤워!!", duration=90)
                    last_tears_cast_time = time_now
        calculate_bounce(PLAYER)  # handle_ball에서는 반환값 사용 안함 (게이지 처리가 handle_player에서 이미 됨)
        player_last_shot_speed = math.hypot(ball_vel[0], ball_vel[1])
        # 🎯 타격 이펙트 생성 (공 속도에 따라 강도 조절)
        create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=True)
        # 🆕 새로운 보스 모드에서 하단 보스의 스킬 발동 체크
        if new_boss_mode_active:
            print(f"🆕 handle_ball에서 새로운 보스 모드 하단 보스 스킬 체크! selected_bottom_boss={selected_bottom_boss}")  # 디버그
            if selected_bottom_boss == 1:
                print("🔥 파이어 나이트 스킬 호출!")
                handle_fire_knight_skills()  # 파이어 나이트 스킬
            elif selected_bottom_boss == 2:
                print("💨 윈드 스피릿 스킬 호출!")
                handle_wind_spirit_skills()  # 윈드 스피릿 스킬
        # 🌟 드라이브 공이 보스 패들에 맞고 다시 플레이어 패들에 맞으면 원래 색상으로 복구
        if drive_ball_active and drive_hit_boss:
            drive_ball_active = False
            drive_hit_boss = False
            drive_speed_increase = 0.0  # 🆕 드라이브 속도 증가량 리셋
            print("🌟 드라이브 공이 플레이어 패들에 재충돌하여 원래 색상으로 복구됨!")
        # handle_player에서 이미 사운드를 재생하므로 여기서는 재생하지 않음
        # handle_player에서 놓친 충돌의 경우에만 사운드 재생
        if not player_collision_handled and player_sound_cooldown <= 0:
            SOUND_PADDLE.play()
            player_sound_cooldown = 20  # 약 0.33초 쿨다운
            print("🔊 handle_ball에서 사운드 재생 (handle_player가 놓친 충돌)")
        hit_animation_active = True
        hit_animation_timer = HIT_ANIMATION_DURATION
        if ball_vel[0] != 0:
            direction = math.copysign(1, ball_vel[0])
            ball_angle += direction * 10
        ball_vel[0] *= 1.03
        ball_vel[1] *= 1.03
        # 🔹 handle_ball에서는 게이지 충전하지 않음 (handle_player에서만 처리)
        # handle_player에서 놓친 충돌의 경우에만 백업으로 게이지 충전
        global drive_just_activated
        print(f"🔍 DEBUG: handle_ball 충돌 감지 - handle_player가 놓친 충돌")
        # handle_player가 놓친 충돌에 대해서만 게이지 충전
        # 드라이브 발동 시에도 게이지 충전 차단
        if not aipill_active and not special_active and not rolling_active and player_collision_cooldown <= 0 and not drive_just_activated:
            # 스킬 효과 적용: 게이지 충전 증가
            base_gauge_gain = 80  # 사용자 요청에 따라 80으로 설정
            skill_gauge_boost = skill.apply_gauge_boost(0)
            total_gauge_gain = base_gauge_gain + skill_gauge_boost
            print(f"🔍 DEBUG: ✅ handle_ball에서 백업 게이지 충전 (handle_player가 놓친 충돌) ({total_gauge_gain})")
            special_gauge += total_gauge_gain
            # 🔧 동적 최대치 제한 적용
            current_max = get_max_gauge()
            if special_gauge > current_max:
                special_gauge = current_max
            # 🔧 필살기 준비 상태 업데이트 (400 이상일 때)
            if special_gauge >= 350:  # 파워스매시 발동 조건
                special_ready = True
            # 충돌 쿨다운 설정
            player_collision_cooldown = 15
        else:
            print(f"🔍 DEBUG: ❌ handle_ball에서 게이지 충전 차단됨 (쿨다운: {player_collision_cooldown}, rolling: {rolling_active}, drive: {drive_just_activated})")
        if drive_just_activated:
            drive_just_activated = False  # 🆕 한 번 사용 후 리셋
        # 🔹 게이지 상태 실시간 업데이트 (게이지가 감소했을 때도 반영)
        if special_gauge < 350:  # 파워스매시 발동 조건
            special_ready = False
        # handle_player에서 이미 쿨다운을 설정했으므로 여기서는 설정하지 않음
        if whip_active:
            whip_hit_by_player = True
        # 🚀 handle_ball에서의 파워스매싱은 이미 handle_player에서 처리되므로 제거
        # (중복 발동 방지를 위해 주석 처리)
    # --- 보스 충돌 ---
    # 서브 대기 중에는 충돌 체크하지 않음
    global last_hit_by
    # 스테이지 6에서만 보스 히트박스를 2배로 확장 (항공모함 보스 특성)
    if current_stage == 6:
        # 항공모함 보스는 큰 함체를 가지므로 히트박스 확장
        boss_hitbox_expanded = pygame.Rect(
            BOSS.x - BOSS.width // 2,  # 왼쪽으로 절반 폭만큼 확장
            BOSS.y,  # y 위치는 그대로
            BOSS.width * 2,  # 너비를 2배로
            BOSS.height  # 높이는 그대로
        )
    else:
        # 다른 스테이지는 원래 크기 사용
        boss_hitbox_expanded = BOSS
    if boss_hitbox_expanded.colliderect(BALL) and boss_collision_cooldown <= 0 and not is_waiting_for_serve:
        # 🎆 파워스매싱 상태 확인 (보스 충돌 직전에)
        was_power_smashing = power_smashing_parabola_active
        # 💥 고스트샷 공과 충돌 시 처리
        if mega_smashing_active:
            # 보스 방어 횟수 증가
            mega_smashing_boss_defense_count += 1
            print(f"🐉 고스트샷 보스 방어! 고스트샷 종료!")
            # 🎯 고스트샷 방어 시 공속도 50% 감소
            ball_vel[0] *= 0.5
            ball_vel[1] *= 0.5
            print(f"⚡ 고스트샷 방어로 공속도 50% 감소! 현재 속도: ({ball_vel[0]:.1f}, {ball_vel[1]:.1f})")
            # 1번 방어 시 즉시 고스트샷 종료로 변경
            if mega_smashing_boss_defense_count >= 1:
                # 👻 귀신들 흩어짐 효과 발동
                if not mega_smashing_ghost_scatter and len(mega_smashing_ghosts) > 0:
                    mega_smashing_ghost_scatter = True
                    mega_smashing_ghost_scatter_time = pygame.time.get_ticks()
                    # 각 귀신에게 무서운 속도로 흩어지는 방향 설정
                    for ghost in mega_smashing_ghosts:
                        # 보스 위치에서 귀신 위치로의 벡터 (반대 방향으로 튕김)
                        dx = ghost['x'] - BOSS.centerx
                        dy = ghost['y'] - BOSS.centery
                        distance = math.hypot(dx, dy)
                        if distance > 0:
                            dx /= distance
                            dy /= distance
                        else:
                            # 랜덤 방향
                            angle = random.uniform(0, 2 * math.pi)
                            dx = math.cos(angle)
                            dy = math.sin(angle)
                        # 무서운 속도로 흩어짐
                        scatter_speed = random.uniform(15, 25)
                        ghost['scatter_vx'] = dx * scatter_speed
                        ghost['scatter_vy'] = dy * scatter_speed
                    print("👻 귀신들이 무서운 속도로 흩어짐!")
                # 고스트샷 종료 (보스가 2번 방어)
                mega_smashing_active = False
                mega_smashing_bonus_applied = False
                mega_smashing_meteor_trail.clear()
                mega_smashing_boss_defense_count = 0  # 카운터 리셋
                print("💥 고스트샷 종료! (보스가 방어 성공)")
            # 일반 충돌로 처리하기 위해 아래로 계속 진행
        # 일반 충돌 처리 (고스트샷도 종료 후 일반 충돌 처리)
        last_hit_by = "boss"  # 보스가 공을 쳤음을 기록
        calculate_bounce(BOSS)
        # 💪 체력형 보스 데미지 적용 (파워스매싱, 드라이브, 일반 공격)
        if current_stage in boss_health_stages:
            # 파워스매싱 상태 체크 (최우선)
            if was_power_smashing:
                damage = boss_damage_values["power"]  # 파워스매싱 데미지 (3)
                # 🚫 스테이지 6에서는 파워스매싱 종료
                if current_stage == 6:
                    power_smashing_parabola_active = False
                    power_smashing_direction = None
                    power_smashing_trails.clear()
                    power_smashing_particles.clear()
                    print("🚫 스테이지 6: 파워스매싱이 보스 패들에 맞아 종료됨!")
            # 드라이브 상태 체크
            elif drive_ball_active:
                damage = boss_damage_values["drive"]  # 드라이브 데미지 (2)
                # 🚫 스테이지 6에서는 드라이브 종료
                if current_stage == 6:
                    drive_ball_active = False
                    drive_hit_boss = False
                    drive_speed_increase = 0.0
                    ball_spin_strength = 0.0
                    ball_spin_direction = 0
                    print("🚫 스테이지 6: 드라이브가 보스 패들에 맞아 종료됨!")
            else:
                damage = boss_damage_values["basic"]  # 기본 공격 데미지 (1)
            boss_current_health = max(0, boss_current_health - damage)
            # 🎯 스테이지 6 보스 피격 효과 (소닉 스타일)
            if current_stage == 6:
                global stage6_boss_hit_timer, stage6_boss_hit_flash
                stage6_boss_hit_timer = 30  # 0.5초간 깜빡임 (60 FPS 기준)
                stage6_boss_hit_flash = True
                SOUND_STAGE6_BOSS_HIT.play()  # 피격 사운드 재생
                print(f"🎯 스테이지 6 보스 피격! 체력: {boss_current_health}/{boss_max_health}")
            # 💪 보스 체력이 0이 되면 즉시 승리
            if boss_current_health <= 0:
                print("🏆 체력형 보스 체력이 0! 플레이어 승리!")
                show_result(True)
                return
            # 🎯 타격 이펙트 생성 (공 속도에 따라 강도 조절)
            create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
            # 체력형 보스에서는 정지화면 없이 바로 다음 처리로 넘어감
            # 드라이브 효과 종료만 처리하고 나머지 스킬 등은 건너뜀
            if drive_ball_active:
                drive_ball_active = False
                drive_hit_boss = False
                print("🌟 체력형 보스: 드라이브 효과 종료")
            # 충돌 쿨다운 설정
            boss_collision_cooldown = 10
            return  # 체력형 보스에서는 여기서 종료하여 정지화면 방지
            # 🎯 타격 이펙트 생성 (공 속도에 따라 강도 조절)
            create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
        # 🌟 드라이브 효과 종료 (보스가 받아치면)
        if drive_ball_active:
            drive_ball_active = False
            drive_hit_boss = False
            print("🌟 드라이브 효과가 보스 충돌로 종료됨!")
        # 🧠 AI 학습: 보스가 공을 성공적으로 맞췄음 (제거됨)
        # 🌪️ 상모돌리기 발동 체크 (스테이지 1, 보스 충돌 시 12% 확률)
        if not new_boss_mode_active and current_stage == 1 and random.random() <= 0.12:
            activate_whip()
            show_speech("상모돌리기!!", duration=whip_duration)
        # 🆕 새로운 보스 모드에서 상단 보스의 스킬 발동 체크
        if new_boss_mode_active:
            print(f"🆕 handle_ball에서 새로운 보스 모드 상단 보스 스킬 체크! selected_top_boss={selected_top_boss}")  # 디버그
            if selected_top_boss == 1:
                print("⚡ 라이트닝 마스터 스킬 호출!")
                handle_lightning_master_skills()  # 라이트닝 마스터 스킬
            elif selected_top_boss == 2:
                print("🧊 아이스 퀸 스킬 호출!")
                handle_ice_queen_skills()  # 아이스 퀸 스킬
        # 🚀 가속화 스킬 효과 복원: 보스 패들이 맞받아칠 때 원래 속도의 -10%로 복원
        global acceleration_active, acceleration_original_speed
        if acceleration_active:
            # 원래 속도의 90% (10% 감소)로 복원
            restore_speed_x = acceleration_original_speed[0] * 0.9
            restore_speed_y = acceleration_original_speed[1] * 0.9
            # 방향 보정: 보스가 맞받아치므로 Y방향 반전
            ball_vel[0] = restore_speed_x
            ball_vel[1] = -abs(restore_speed_y)  # 위쪽으로 (음수)
            # 가속화 효과 해제
            acceleration_active = False
            acceleration_original_speed = [0, 0]
        # 🌟 드라이브 공이 보스 패들에 닿으면 효과 50% 감소 + 드라이브 증가 공속의 90% 감소
        if drive_ball_active and not drive_hit_boss:
            drive_hit_boss = True
            ball_spin_strength *= 0.5  # 드라이브 효과 50% 감소
            # 🆕 드라이브로 증가한 공속의 90%를 감소시키는 새로운 메커니즘
            if drive_speed_increase > 0:
                # 현재 공속 계산
                current_speed = math.hypot(ball_vel[0], ball_vel[1])
                # 드라이브로 증가한 속도의 90%를 감소
                speed_reduction = drive_speed_increase * 0.9
                new_speed = max(1.0, current_speed - speed_reduction)  # 최소 속도 1.0 보장
                # 속도 비율 계산하여 ball_vel에 적용
                speed_ratio = new_speed / current_speed if current_speed > 0 else 1.0
                ball_vel[0] *= speed_ratio
                ball_vel[1] *= speed_ratio
                # 남은 드라이브 증가량 업데이트 (10%만 남김)
                drive_speed_increase *= 0.1
                print(f"🌟 드라이브 공이 보스 패들에 닿아 드라이브 증가 공속의 90% 감소!")
                print(f"   속도 감소: {current_speed:.2f} → {new_speed:.2f} (-{speed_reduction:.2f})")
                print(f"   남은 드라이브 증가량: {drive_speed_increase:.2f}")
            else:
                print("🌟 드라이브 공이 보스 패들에 닿았지만 추적된 증가 공속이 없음")
            # 🚨 드라이브 반격 속도 제한 시스템 (플레이어 대응 가능한 수준으로)
            current_speed_after = math.hypot(ball_vel[0], ball_vel[1])
            max_drive_counter_speed = 16.0  # 드라이브 반격 최대 속도 제한
            if current_speed_after > max_drive_counter_speed:
                speed_limit_ratio = max_drive_counter_speed / current_speed_after
                ball_vel[0] *= speed_limit_ratio
                ball_vel[1] *= speed_limit_ratio
                print(f"🚨 드라이브 반격 속도 제한 적용!")
                print(f"   제한 전: {current_speed_after:.2f} → 제한 후: {max_drive_counter_speed:.2f}")
                print(f"   플레이어 대응 가능한 수준으로 조정됨")
            # 🎯 추가 안전 장치: 플레이어 방향으로 향하는 빠른 공의 추가 감속
            if ball_vel[1] > 0:  # 플레이어 방향으로 향하는 공
                player_direction_speed = math.hypot(ball_vel[0], ball_vel[1])
                max_player_direction_speed = 14.0  # 플레이어 방향 최대 속도 더 엄격하게 제한
                if player_direction_speed > max_player_direction_speed:
                    safety_ratio = max_player_direction_speed / player_direction_speed
                    ball_vel[0] *= safety_ratio
                    ball_vel[1] *= safety_ratio
                    print(f"🛡️ 플레이어 방향 안전 제한 적용!")
                    print(f"   {player_direction_speed:.2f} → {max_player_direction_speed:.2f}")
                    print(f"   대응 시간 확보를 위한 추가 감속")
        # 🌟 상모돌리기 중 플레이어가 공을 맞춘 후 보스 패들에 재충돌 시 상모돌리기 강제종료 + 속도 복구
        if whip_active and whip_hit_by_player:
            # 🔥 상모돌리기 강제종료
            whip_active = False
            whip_timer = 0
            whip_sound.stop()  # 상모돌리기 사운드 중지
            print("🌟 상모돌리기 강제종료! (플레이어 패들→보스 패들 충돌)")
            # 🔄 공속도 원래대로 복구
            ball_vel[0] = whip_original_ball_speed[0]
            ball_vel[1] = whip_original_ball_speed[1]
            whip_hit_by_player = False  # 상태 리셋
            print(f"🌟 상모돌리기 속도 복구! 복구된 속도: {whip_original_ball_speed}")
        # 감지센서용 보스 히트 타이머 설정 (무제한)
        boss_hit_timer = 999999
        # 충돌 쿨다운 설정
        boss_collision_cooldown = 10
        # 보스 패들 충돌 애니메이션 활성화
        global boss_hit_animation_active, boss_hit_animation_timer
        boss_hit_animation_active = True
        # 스테이지별 애니메이션 지속시간 조정
        if current_stage == 1:
            base_duration = 5  # 스테이지 1: 빠른 회복
        elif current_stage == 2:
            base_duration = 7  # 스테이지 2: 중간 회복
        elif current_stage == 3:
            base_duration = 8  # 스테이지 3: 느린 회복
        elif current_stage == 4:
            base_duration = 6  # 스테이지 4: 기본 회복
        elif current_stage == 5:
            base_duration = 9  # 스테이지 5: 가장 느린 회복
        else:
            base_duration = BOSS_HIT_ANIMATION_DURATION
        boss_hit_animation_timer = base_duration
        # 충돌 강도에 따른 애니메이션 강화 (공 속도 기반)
        ball_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
        if ball_speed > 8:  # 빠른 공일 때 더 강한 애니메이션
            boss_hit_animation_timer = base_duration + 2
        if current_stage == 5 and hongryun_ready:
            flame_trail_active = True
            flame_trail_timer = 120
            flame_trail_phase = 0
            flame_trail_positions.clear()
            show_hongryun_explosion()  # ⬅ 추가된 장면 연출
            # ✅ 발동 후 게이지 초기화
            hongryun_ready = False
            hongryun_hit_count = 0
        # 보스 충돌 사운드 재생
        if current_stage == 2 and speed_defense_active:
            SOUND_DEFENSE_HIT.play()
        else:
            SOUND_PADDLE.play()
        if ball_vel[0] != 0:
            direction = math.copysign(1, ball_vel[0])
            ball_angle += direction * 10
        # 🚀 파워스매싱 종료 및 감속 로직
        if was_power_smashing:
            # 파워스매싱 공을 보스가 받아쳤을 때: 플레이어가 대응 가능한 속도로 조정
            if power_smashing_original_speed > 0:
                # 원래 속도의 70%로 감속 (플레이어가 대응하기 쉽게)
                target_speed = power_smashing_original_speed * 0.7  
                current_speed = math.hypot(ball_vel[0], ball_vel[1])
                if current_speed > 0:
                    speed_ratio = target_speed / current_speed
                    ball_vel[0] *= speed_ratio
                    ball_vel[1] *= speed_ratio
                else:
                    # 공이 정지 상태라면 기본 속도의 70%로 설정
                    ball_vel[0] = BALL_BASE_SPEED * 0.7 * 0.7
                    ball_vel[1] = BALL_BASE_SPEED * 0.7 * 0.7
            else:
                # 기존 로직 (원래 속도 정보가 없는 경우) - 더 많이 감속
                ball_vel[0] /= 2.0  # 1.5 -> 2.0으로 변경 (더 많이 감속)
                ball_vel[1] /= 2.0
            # special_active 리셋
            special_active = False
            ball_trail.clear()
            power_smashing_original_speed = 0.0  # 원래 속도 정보 초기화
            # 🎯 포물선 궤적 시스템 즉시 비활성화
            power_smashing_parabola_active = False
            power_smashing_start_time = 0
            power_smashing_arc_strength = 0.0
            # 🎆 파워스매싱 이펙트 즉시 정리
            power_smashing_trails.clear()
            power_smashing_particles.clear()
            mega_smashing_meteor_trail.clear()
            mega_smashing_active = False
            print(f"🎆 파워스매싱 이펙트 해제됨! (보스 반격)")
        # --- 스테이지별 보스 스킬 ---
        # 🆕 새로운 보스 모드에서는 기존 보스 스킬 발동 비활성화 (중복 방지)
        if not new_boss_mode_active and current_stage == 1:
            # 상모돌리기는 이제 보스 패들 충돌 시에만 발동 (매 프레임 체크 제거)
            if random.random() <= 0.15 and not balloon_used_this_round:  # 풍선 스킬 확률 15%, 한 라운드에 한 번만
                activate_balloon()
        elif not new_boss_mode_active and current_stage == 2:
            time_now = pygame.time.get_ticks()
            if (time_now - quake_last_used_time >= QUAKE_COOLDOWN) and random.random() <= 0.15:
                activate_quake()
                show_speech("정글지진!", duration=quake_duration)
                quake_last_used_time = time_now
        elif not new_boss_mode_active and current_stage == 3:
            if not boss_special_ready:
                boss_special_gauge += 60
                if boss_special_gauge >= 500:
                    boss_special_gauge = 500
                    boss_special_ready = True
                    boss_special_waiting = True
            target = 220 if boss_special_gauge >= 500 else (boss_special_gauge / 500) * 220
            if boss_red_intensity < target:
                boss_red_intensity += (target - boss_red_intensity) * 0.1
            else:
                boss_red_intensity -= (boss_red_intensity - target) * 0.1
            boss_red_intensity = min(220, max(0, boss_red_intensity))
            if boss_special_ready:
                show_fade_text("사이코볼!")
                activate_emotional_overdrive()
                boss_special_ready = False
                boss_special_gauge = 0
                boss_red_intensity = 0
        elif not new_boss_mode_active and current_stage == 4:
            if not meditation_active and random.random() <= 0.13:
                activate_meditation()
            if not stage4_magnetic_active:
                boss_special_gauge_stage4 += 90
                if boss_special_gauge_stage4 >= 300:
                    boss_special_gauge_stage4 = 300
                    boss_special_ready_stage4 = True
def predict_ball_position(frames=20):
    predict_x = BALL.centerx + ball_vel[0] * frames
    predict_x = max(0, min(WIDTH, predict_x))  # 벽 충돌 예외처리
    return predict_x
# 🧠 딥러닝 AI 시스템 초기화 및 관리 함수들
def initialize_enhanced_ai():
    """딥러닝 AI 시스템 초기화"""
    global enhanced_ai, ai_enabled, ai_mode
    if not AI_AVAILABLE:
        print("⚠️ 딥러닝 AI를 사용할 수 없습니다. 기본 AI로 실행됩니다.")
        ai_enabled = False
        return False
def initialize_player_analyzer():
    """플레이어 실력 분석 시스템 초기화"""
    global player_analyzer
    if not SKILL_ANALYZER_AVAILABLE:
        print("⚠️ 플레이어 실력 분석을 사용할 수 없습니다.")
        return False
    try:
        player_analyzer = get_player_analyzer()
        print("🏆 플레이어 실력 분석 시스템이 초기화되었습니다!")
        return True
    except Exception as e:
        print(f"❌ 플레이어 분석기 초기화 실패: {e}")
        return False
    try:
        enhanced_ai = EnhancedBossAI(ai_mode)
        ai_enabled = True
        print(f"🧠 딥러닝 AI 시스템이 초기화되었습니다! (모드: {ai_mode})")
        return True
    except Exception as e:
        print(f"❌ AI 초기화 실패: {e}")
        ai_enabled = False
        return False
def toggle_ai_mode():
    """AI 모드 전환 (N 키로 호출)"""
    global ai_mode, enhanced_ai
    if not AI_AVAILABLE:
        print("⚠️ 딥러닝 AI를 사용할 수 없습니다.")
        return
    if ai_mode == "junior":
        ai_mode = "pro"
        print("⚡ 프로리그로 승급!")
    elif ai_mode == "pro":
        ai_mode = "champion"
        print("💎 챔피언리그로 승급!")
    elif ai_mode == "champion":
        ai_mode = "mythic"
        print("👑 신화리그로 승급!")
    else:  # mythic
        ai_mode = "junior"
        print("🌱 주니어리그로 이동!")
    # AI 인스턴스 업데이트
    if enhanced_ai:
        enhanced_ai.ai_mode = ai_mode
def handle_boss_pro():
    """⚡ 프로리그: 표준 AI (15% 실수율)"""
    global boss_current_speed, boss_fail_timer, BOSS_ACCELERATION, BOSS_DECELERATION, BOSS_MAX_SPEED, BOSS_INSTANT_STOP_DECELERATION
    global boss_fake_move, boss_fake_start_time, is_player_serve, is_waiting_for_serve
    global boss_fake_during_player_serve, waiting_start_time, wait_delay
    global ball_vel, boss_stunned_timer, boss_knockback_vel
    # 🔥 보스 스턴 상태 처리 (화염병 효과)
    if boss_stunned_timer > 0:
        boss_stunned_timer -= 1
        # 넉백 적용
        BOSS.x += boss_knockback_vel
        BOSS.x = max(0, min(WIDTH - PADDLE_WIDTH, BOSS.x))
        # 감속
        boss_knockback_vel *= 0.85
        return  # 스턴 중에는 AI 비활성화
    # 🎾 서브 대기 상태 처리 (기존 로직과 동일)
    if is_waiting_for_serve:
        time_now = pygame.time.get_ticks()
        # 보스 패들 간보기 움직임
        def fake_motion():
            style = random.randint(1, 4)
            if style == 1:
                return math.sin(time_now / 100) * 2.5
            elif style == 2 and random.random() < 0.02:
                return random.choice([-1, 1]) * random.randint(20, 30)
            elif style == 3:
                return math.sin(time_now / 300) * 4
            elif style == 4 and random.random() < 0.015:
                return random.choice([-1, 1]) * 10
            return 0
        # --- 보스 서브 차례 ---
        if not is_player_serve:
            if boss_fake_move and time_now - boss_fake_start_time < wait_delay:
                BOSS.centerx += fake_motion()
            if wait_delay > 0 and time_now - waiting_start_time >= wait_delay:
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                calculate_bounce(BOSS)
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
            if wait_delay == 0:
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                calculate_bounce(BOSS)
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
        # --- 플레이어 서브 차례 ---
        elif boss_fake_during_player_serve:
            BOSS.centerx += fake_motion()
        return  # 서브 중에는 아래 일반 이동 로직 실행 안 함
    # 🚀 경량화된 기존 AI 로직 (성능 최적화) - 서브가 아닐 때만
    # ⚡ 프로리그: 통합 보스 설정 (스테이지별 + 리그별 완전 연계)
    config = get_final_boss_config(current_stage, "pro")
    config["fail_chance"] = 0.12  # 12% 실수율 (프로리그 표준)
    # 간단한 예측 로직
    predict_frame = max(10, min(30, int(60 / max(1, abs(ball_vel[0])))))
    # 조명탄 혼란 효과 체크
    if boss_confused_timer > 0:
        # 혼란 상태일 때는 완전히 랜덤하게 움직임 (공을 무시)
        if not hasattr(handle_boss, 'confusion_target'):
            handle_boss.confusion_target = random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)
            handle_boss.confusion_direction_timer = 0
        # 30프레임마다 새로운 랜덤 위치 선택
        handle_boss.confusion_direction_timer = getattr(handle_boss, 'confusion_direction_timer', 0) + 1
        if handle_boss.confusion_direction_timer >= 30:
            handle_boss.confusion_target = random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)
            handle_boss.confusion_direction_timer = 0
        # 랜덤 목표 지점으로 이동
        future_x = handle_boss.confusion_target
        # 가끔 갑자기 방향 전환 (20% 확률)
        if random.random() < 0.2:
            future_x = random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)
    elif boss_fail_timer > 0:
        # 실패 상태일 때 단순한 움직임
        future_x = BALL.centerx + random.randint(-50, 50)
        boss_fail_timer -= 1
    else:
        # 정상 상태일 때의 기본 AI
        # 기본 예측
        if random.random() < config["predict_chance"]:
            future_x = BALL.centerx + ball_vel[0] * predict_frame
        else:
            future_x = BALL.centerx
        # 오차 추가
        future_x += random.randint(-config["predict_error"], config["predict_error"])
        # 실패 확률 체크
        if random.random() < config["fail_chance"]:
            boss_fail_timer = 30
    # ⚡ 프로리그: 통합 설정 기반 이동 로직
    enhanced_max_speed = config["max_speed"]
    enhanced_acceleration = config["accel"]
    enhanced_deceleration = config["decel"]
    if future_x < BOSS.centerx - 10:
        if boss_current_speed > -enhanced_max_speed:
            boss_current_speed -= enhanced_acceleration
    elif future_x > BOSS.centerx + 10:
        if boss_current_speed < enhanced_max_speed:
            boss_current_speed += enhanced_acceleration
    else:
        # 감속
        if boss_current_speed > 0:
            boss_current_speed = max(0, boss_current_speed - enhanced_deceleration)
        elif boss_current_speed < 0:
            boss_current_speed = min(0, boss_current_speed + enhanced_deceleration)
    # 위치 업데이트
    BOSS.x += boss_current_speed
    BOSS.x = max(0, min(WIDTH - BOSS.width, BOSS.x))
def handle_boss_champion():
    """💎 챔피언리그: 고급 AI (8% 실수율)"""
    global boss_current_speed, boss_fail_timer, BOSS_ACCELERATION, BOSS_DECELERATION, BOSS_MAX_SPEED, BOSS_INSTANT_STOP_DECELERATION
    global boss_fake_move, boss_fake_start_time, is_player_serve, is_waiting_for_serve
    global boss_fake_during_player_serve, waiting_start_time, wait_delay
    global ball_vel, boss_stunned_timer, boss_knockback_vel
    # 🔥 보스 스턴 상태 처리 (화염병 효과)
    if boss_stunned_timer > 0:
        boss_stunned_timer -= 1
        # 넉백 적용
        BOSS.x += boss_knockback_vel
        BOSS.x = max(0, min(WIDTH - PADDLE_WIDTH, BOSS.x))
        # 감속
        boss_knockback_vel *= 0.85
        return  # 스턴 중에는 AI 비활성화
    # 🎾 서브 대기 상태 처리 (기존 로직과 동일)
    if is_waiting_for_serve:
        time_now = pygame.time.get_ticks()
        # 보스 패들 간보기 움직임
        def fake_motion():
            style = random.randint(1, 4)
            if style == 1:
                return math.sin(time_now / 100) * 2.5
            elif style == 2 and random.random() < 0.02:
                return random.choice([-1, 1]) * random.randint(20, 30)
            elif style == 3:
                return math.sin(time_now / 300) * 4
            elif style == 4 and random.random() < 0.015:
                return random.choice([-1, 1]) * 10
            return 0
        # --- 보스 서브 차례 ---
        if not is_player_serve:
            if boss_fake_move and time_now - boss_fake_start_time < wait_delay:
                BOSS.centerx += fake_motion()
            if wait_delay > 0 and time_now - waiting_start_time >= wait_delay:
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                calculate_bounce(BOSS)
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
            if wait_delay == 0:
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                calculate_bounce(BOSS)
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
        # --- 플레이어 서브 차례 ---
        elif boss_fake_during_player_serve:
            BOSS.centerx += fake_motion()
        return  # 서브 중에는 아래 일반 이동 로직 실행 안 함
    # ⚡ 극한 경량화: 최소한의 연산으로 스마트한 AI (서브가 아닐 때만)
    # 공의 방향과 속도 간단 분석 (최신 시스템)
    current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
    ball_speed = abs(ball_vel[0]) + abs(ball_vel[1])
    # 💎 챔피언리그: 통합 보스 설정 (스테이지별 + 리그별 완전 연계)
    config = get_final_boss_config(current_stage, "champion")
    enhanced_max_speed = config["max_speed"]
    enhanced_acceleration = config["accel"]
    enhanced_deceleration = config["decel"]
    # 예측 프레임을 공 속도에 따라 동적 조절
    if ball_speed > 15:
        predict_frame = 8  # 빠른 공
    elif ball_speed > 10:
        predict_frame = 12  # 중간 공
    else:
        predict_frame = 20  # 느린 공
    # 🔥 조명탄 혼란 효과 체크 (최우선 처리)
    if boss_confused_timer > 0:
        # 혼란 상태일 때는 완전히 랜덤하게 움직임 (공을 무시)
        if not hasattr(handle_boss_champion, 'confusion_target'):
            handle_boss_champion.confusion_target = random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)
            handle_boss_champion.confusion_direction_timer = 0
        # 30프레임마다 새로운 랜덤 위치 선택
        handle_boss_champion.confusion_direction_timer = getattr(handle_boss_champion, 'confusion_direction_timer', 0) + 1
        if handle_boss_champion.confusion_direction_timer >= 30:
            handle_boss_champion.confusion_target = random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)
            handle_boss_champion.confusion_direction_timer = 0
        # 랜덤 목표 지점으로 이동
        future_x = handle_boss_champion.confusion_target
        # 가끔 갑자기 방향 전환 (20% 확률)
        if random.random() < 0.2:
            future_x = random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)
    else:
        # 간단한 예측
        future_x = BALL.centerx + ball_vel[0] * predict_frame
        # 벽 바운스 간단 계산
        if future_x < 0:
            future_x = -future_x
        elif future_x > WIDTH:
            future_x = WIDTH * 2 - future_x
        # 💎 챔피언리그 난이도 조절 (8% 실수율, 최신 공 매커니즘 고려)
        champion_mistake_chance = 0.08  # 8% 실수율
        if random.random() < champion_mistake_chance:
            # 8% 확률로 실수 발생 (현재 공 속도에 비례한 실수 크기)
            mistake_magnitude = min(100, max(50, current_speed * 5))  # 속도에 비례한 실수
            future_x += random.randint(-int(mistake_magnitude), int(mistake_magnitude))
            boss_fail_timer = 25  # 짧은 실수 지속시간
            if random.random() < 0.1:
                print(f"💎 챔피언리그 AI: 실수 발생! 속도={current_speed:.1f}, 오차=±{mistake_magnitude:.0f}")
        # 스테이지별 정확도 (실수율이 이미 적용된 상태)
        if current_stage >= 4:
            accuracy = 0.95  # 95% 정확도 (챔피언리그는 더 정확)
        elif current_stage >= 3:
            accuracy = 0.8  # 80% 정확도
        else:
            accuracy = 0.7  # 70% 정확도
        # 오차 추가 (간단)
        if random.random() > accuracy:
            error = random.randint(-60, 60)
            future_x += error
    # 매우 간단한 이동 로직
    target_distance = future_x - BOSS.centerx
    if abs(target_distance) < 15:  # 충분히 가까우면 정지
        boss_current_speed *= 0.8
    elif target_distance < 0:  # 왼쪽으로
        boss_current_speed = max(-enhanced_max_speed, boss_current_speed - enhanced_acceleration * 1.2)
    else:  # 오른쪽으로
        boss_current_speed = min(enhanced_max_speed, boss_current_speed + enhanced_acceleration * 1.2)
    # 위치 업데이트
    BOSS.x += boss_current_speed
    BOSS.x = max(0, min(WIDTH - BOSS.width, BOSS.x))
def handle_boss_mythic():
    """👑 신화리그: 최강 AI (2% 실수율) - 거의 완벽한 플레이"""
    global boss_current_speed, boss_fail_timer, BOSS_ACCELERATION, BOSS_DECELERATION, BOSS_MAX_SPEED, BOSS_INSTANT_STOP_DECELERATION
    global boss_fake_move, boss_fake_start_time, is_player_serve, is_waiting_for_serve
    global boss_fake_during_player_serve, waiting_start_time, wait_delay
    global ball_vel, ball_impact_boost, fireball_last_cast, fireball_cooldown, current_stage
    global boss_stunned_timer, boss_knockback_vel
    # 🔥 보스 스턴 상태 처리 (화염병 효과)
    if boss_stunned_timer > 0:
        boss_stunned_timer -= 1
        # 넉백 적용
        BOSS.x += boss_knockback_vel
        BOSS.x = max(0, min(WIDTH - PADDLE_WIDTH, BOSS.x))
        # 감속
        boss_knockback_vel *= 0.85
        return  # 스턴 중에는 AI 비활성화
    # 서브 대기 상태에서는 기본 AI 사용
    if is_waiting_for_serve:
        # 서브 중에는 미세한 패들 움직임만
        time_now = pygame.time.get_ticks()
        if not is_player_serve:  # 보스 서브 차례
            if boss_fake_move and time_now - boss_fake_start_time < wait_delay:
                # 신의 영역: 더욱 정교한 페이크 움직임
                fake_motion = math.sin(time_now / 80) * 1.5 + math.cos(time_now / 120) * 0.8
                BOSS.centerx += fake_motion
                BOSS.x = max(0, min(WIDTH - BOSS.width, BOSS.x))
            if wait_delay > 0 and time_now - waiting_start_time >= wait_delay:
                # 서브 실행
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                calculate_bounce(BOSS)
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
            if wait_delay == 0:
                # 즉시 서브 실행
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                calculate_bounce(BOSS)
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
        elif boss_fake_during_player_serve:  # 플레이어 서브 차례
            # 플레이어 패들을 관찰하는 듯한 미세한 움직임
            player_direction = PLAYER.centerx - BOSS.centerx
            tracking_motion = math.copysign(0.3, player_direction)
            BOSS.centerx += tracking_motion
            BOSS.x = max(0, min(WIDTH - BOSS.width, BOSS.x))
        return
    # 👑 신화리그 AI: 최신 공 물리학 시스템 기반 예측 시스템
    # 🔥 조명탄 혼란 효과 체크 (최우선 처리)
    if boss_confused_timer > 0:
        # 혼란 상태일 때는 완전히 랜덤하게 움직임 (공을 무시)
        if not hasattr(handle_boss_mythic, 'confusion_target'):
            handle_boss_mythic.confusion_target = random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)
            handle_boss_mythic.confusion_direction_timer = 0
        # 30프레임마다 새로운 랜덤 위치 선택
        handle_boss_mythic.confusion_direction_timer = getattr(handle_boss_mythic, 'confusion_direction_timer', 0) + 1
        if handle_boss_mythic.confusion_direction_timer >= 30:
            handle_boss_mythic.confusion_target = random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)
            handle_boss_mythic.confusion_direction_timer = 0
        # 랜덤 목표 지점으로 이동
        target_distance = handle_boss_mythic.confusion_target - BOSS.centerx
        # 가끔 갑자기 방향 전환 (20% 확률)
        if random.random() < 0.2:
            target_distance = random.randint(-WIDTH // 2, WIDTH // 2)
        # 혼란 상태에서도 이동 속도 적용
        if abs(target_distance) < 10:
            boss_current_speed *= 0.8
        elif target_distance < 0:
            boss_current_speed = max(-BOSS_MAX_SPEED * 0.5, boss_current_speed - BOSS_ACCELERATION)
        else:
            boss_current_speed = min(BOSS_MAX_SPEED * 0.5, boss_current_speed + BOSS_ACCELERATION)
        # 위치 업데이트
        BOSS.x += boss_current_speed
        BOSS.x = max(0, min(WIDTH - BOSS.width, BOSS.x))
        return  # 혼란 상태에서는 나머지 AI 로직 무시
    # 1️⃣ 현재 공 상태 분석 (최신 시스템)
    current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
    # 👑 신화리그: 통합 보스 설정 (스테이지별 + 리그별 완전 연계)
    config = get_final_boss_config(current_stage, "mythic")
    enhanced_max_speed = config["max_speed"]
    enhanced_acceleration = config["accel"]
    enhanced_deceleration = config["decel"]
    # 관성 보존 상태 체크 (최근 벽 충돌 여부)
    try:
        pass  # 빈 try 블록 수정
    except:
        pass
    # 2️⃣ 다중 시나리오 시뮬레이션 (3가지 예측)
    predictions = []
    for scenario in range(3):
        # 시나리오별 예측 프레임 (짧은/중간/긴 예측)
        if scenario == 0:
            predict_frames = max(8, min(15, int(40 / max(1, effective_speed))))
        elif scenario == 1:
            predict_frames = max(12, min(25, int(60 / max(1, effective_speed))))
        else:
            predict_frames = max(20, min(35, int(80 / max(1, effective_speed))))
        # 시뮬레이션 시작
        sim_x = BALL.centerx
        sim_vel_x = ball_vel[0] * current_impact_boost
        sim_vel_y = ball_vel[1] * current_impact_boost
        # 최신 물리학 시뮬레이션
        sim_speed = current_speed
        for frame in range(predict_frames):
            sim_x += sim_vel_x
            # 벽 바운스 시뮬레이션 (관성 보존 시스템 반영)
            if sim_x < 0 or sim_x > WIDTH:
                if sim_x < 0:
                    sim_x = -sim_x
                else:
                    sim_x = WIDTH * 2 - sim_x
                sim_vel_x = -sim_vel_x
                # 관성 보존 보너스 (저속일 때만, 최신 시스템)
                if sim_speed < 12:
                    wall_bonus = min(1.4, 1.0 + (12 - sim_speed) * 0.03)
                    sim_speed *= wall_bonus
            # 적응형 감속 시스템 시뮬레이션 (최신)
            if sim_speed < 10:
                # 저속: 감속 완화 (60% 감소)
                adaptive_decay = 1.0 - (1.0 - 0.977) * 0.4
            elif sim_speed < 15:
                # 중속: 기본 감속
                adaptive_decay = 0.977
            else:
                # 고속: 강화 감속
                speed_ratio = min((sim_speed - 15) / 20, 1.0)
                adaptive_decay = 0.977 * (1.0 + speed_ratio * 0.5)
            sim_speed *= adaptive_decay
            # 속도 벡터 정규화
            current_sim_speed = math.sqrt(sim_vel_x**2 + sim_vel_y**2)
            if current_sim_speed > 0.1:
                scale = sim_speed / current_sim_speed
                sim_vel_x *= scale
                sim_vel_y *= scale
        predictions.append(sim_x)
    # 3️⃣ 예측값들의 가중평균 계산 (더 많은 시나리오 처리)
    if len(predictions) >= 3:
        weight_short = 0.5  # 짧은 예측에 높은 가중치
        weight_medium = 0.3
        weight_long = 0.2
        predicted_x = (predictions[0] * weight_short + 
                       predictions[1] * weight_medium + 
                       predictions[2] * weight_long)
    else:
        predicted_x = predictions[0] if predictions else BALL.centerx
    # 4️⃣ 최신 플레이어 패턴 분석 (동적 부스트 시스템 고려)
    player_center = PLAYER.centerx
    player_to_ball_distance = abs(player_center - BALL.centerx)
    # 플레이어가 퍼펙트 타이밍을 노릴 가능성 분석 (최신 시스템)
    perfect_timing_probability = 0.0
    if ball_vel[1] > 0 and abs(BALL.centery - PLAYER.top) < 150:  # 공이 플레이어로 향할 때
        if player_to_ball_distance < 30:
            perfect_timing_probability = 0.9  # 매우 높은 확률
        elif player_to_ball_distance < 60:
            perfect_timing_probability = 0.6  # 중간 확률
        elif player_to_ball_distance < 100:
            perfect_timing_probability = 0.3  # 낮은 확률
    # 최신 동적 부스트 시스템 예측
    if perfect_timing_probability > 0.5:
        # 현재 속도에 따른 부스트 예측 (최신 시스템 반영)
        if current_speed < 10:
            # 저속: 높은 임팩트 부스트 예상 (2.0x)
            anticipated_boost = 1.8 + perfect_timing_probability * 0.4
        elif current_speed < 15:
            # 중속: 중간 임팩트 부스트 예상 (1.5x)
            anticipated_boost = 1.3 + perfect_timing_probability * 0.3
        else:
            # 고속: 낮은 임팩트 부스트 예상 (1.2x)
            anticipated_boost = 1.1 + perfect_timing_probability * 0.2
        predicted_x *= anticipated_boost
        if random.random() < 0.1:  # 디버그 빈도 감소
            print(f"👑 신화리그 AI: 퍼펙트 타이밍 예상! 속도={current_speed:.1f}, 확률={perfect_timing_probability:.1f}, 부스트={anticipated_boost:.2f}")
    # 5️⃣ 드라이브 공 특수 처리
    drive_correction = 0
    try:
        if 'drive_ball_active' in globals() and drive_ball_active:
            # 드라이브 공의 커브 예측
            if current_stage >= 3:
                curve_strength = random.uniform(-1.2, 1.2)
                drive_correction = curve_strength * predict_frames * 4
                predicted_x += drive_correction
                if random.random() < 0.15:  # 드라이브 디버그 빈도 감소
                    print(f"👑 신화리그 AI: 드라이브 공 감지! 커브 보정={drive_correction:.1f}")
    except:
        pass
    # 6️⃣ 최종 목표 위치 결정
    target_distance = predicted_x - BOSS.centerx
    # 7️⃣ 플레이어 패턴 학습 시스템 (신화리그 전용)
    if not hasattr(handle_boss_mythic, 'player_hit_history'):
        handle_boss_mythic.player_hit_history = []
        handle_boss_mythic.player_move_history = []
    # 플레이어 위치 기록
    handle_boss_mythic.player_move_history.append(PLAYER.centerx)
    if len(handle_boss_mythic.player_move_history) > 30:
        handle_boss_mythic.player_move_history.pop(0)
    # 플레이어가 공을 칠 때만 기록
    if ball_vel[1] < 0 and abs(BALL.centery - PLAYER.top) < 30:
        handle_boss_mythic.player_hit_history.append({
            'position': PLAYER.centerx,
            'ball_x': BALL.centerx,
            'hit_offset': BALL.centerx - PLAYER.centerx
        })
        if len(handle_boss_mythic.player_hit_history) > 10:
            handle_boss_mythic.player_hit_history.pop(0)
    # 패턴 분석으로 예측 보정
    pattern_adjustment = 0
    if len(handle_boss_mythic.player_hit_history) >= 3:
        # 최근 타격 패턴 분석
        recent_hits = handle_boss_mythic.player_hit_history[-3:]
        avg_offset = sum(h['hit_offset'] for h in recent_hits) / len(recent_hits)
        # 플레이어가 주로 한쪽으로 치는 경향이 있으면 반대편 대비
        if abs(avg_offset) > 20:
            pattern_adjustment = -avg_offset * 1.5  # 반대 방향으로 예측
    predicted_x += pattern_adjustment
    # 8️⃣ 전략적 스킬 타이밍 계산 (신화리그 강화)
    # 보스가 사용 가능한 스킬을 미리 예측하고 최적 위치 선점
    skill_ready = False
    if current_stage >= 2:  # 스테이지 2 이상에서 스킬 사용
        # 스킬 쿨다운 체크 (예시: 홍련탄, 자기장 등)
        try:
            if 'fireball_cooldown' in globals() and fireball_cooldown <= 0:
                skill_ready = True
            elif 'magnetic_cooldown' in globals() and magnetic_cooldown <= 0:
                skill_ready = True
        except:
            pass
    if skill_ready and ball_vel[1] < 0:  # 스킬 준비되고 공이 보스로 향할 때
        # 스킬 사용을 위한 최적 위치로 이동
        skill_optimal_x = BALL.centerx  # 공 바로 아래로 이동
        predicted_x = predicted_x * 0.3 + skill_optimal_x * 0.7
    # 9️⃣ 신의 영역 이동 로직: 거의 완벽한 정확도
    reaction_threshold = 3  # 극도로 작은 허용 오차
    # 👑 신화리그 완벽성 조절 (0.5% 실수율) - 대폭 강화
    mythic_mistake_chance = 0.005  # 0.5% 실수율 (99.5% 정확도)
    if random.random() < mythic_mistake_chance:
        # 극히 드문 미세한 실수
        error = random.randint(-20, 20)  # 매우 작은 실수
        predicted_x += error
        if random.random() < 0.01:  # 디버그 메시지도 드물게
            print(f"👑 신화리그 AI: 극히 드문 실수! (오차: {error})")
    # 10️⃣ 극한 반응속도 이동 결정
    target_distance = predicted_x - BOSS.centerx
    # 거리별 세밀한 속도 제어
    if abs(target_distance) < reaction_threshold:
        # 정확한 위치: 즉시 정지
        boss_current_speed *= 0.95
    elif abs(target_distance) < 10:
        # 매우 가까움: 초정밀 제어
        boss_current_speed = math.copysign(min(3, enhanced_max_speed * 0.3), target_distance)
    elif abs(target_distance) < 25:
        # 가까움: 빠른 접근
        if target_distance < 0:
            boss_current_speed = max(-enhanced_max_speed * 0.7, 
                                    boss_current_speed - enhanced_acceleration * 2.0)
        else:
            boss_current_speed = min(enhanced_max_speed * 0.7, 
                                    boss_current_speed + enhanced_acceleration * 2.0)
    elif abs(target_distance) < 50:
        # 중간 거리: 가속
        if target_distance < 0:
            boss_current_speed = max(-enhanced_max_speed * 0.9, 
                                    boss_current_speed - enhanced_acceleration * 2.5)
        else:
            boss_current_speed = min(enhanced_max_speed * 0.9, 
                                    boss_current_speed + enhanced_acceleration * 2.5)
    elif target_distance < 0:
        # 왼쪽으로 최대 가속
        acceleration_multiplier = 3.0  # 극도로 빠른 반응
        boss_current_speed = max(-enhanced_max_speed * 1.1, 
                                boss_current_speed - enhanced_acceleration * acceleration_multiplier)
    else:
        # 오른쪽으로 최대 가속
        acceleration_multiplier = 3.0  # 극도로 빠른 반응
        boss_current_speed = min(enhanced_max_speed * 1.1, 
                                boss_current_speed + enhanced_acceleration * acceleration_multiplier)
    # 11️⃣ 예측적 포지셔닝 (신화리그 전용)
    # 공이 플레이어 쪽에 있을 때도 다음 타격을 준비
    if ball_vel[1] > 0 and BALL.centery > HEIGHT // 2:
        # 다음 반격을 위한 최적 위치로 미리 이동
        optimal_return_position = WIDTH // 2
        # 플레이어 평균 위치 기반 예측
        if len(handle_boss_mythic.player_move_history) >= 5:
            recent_avg = sum(handle_boss_mythic.player_move_history[-5:]) / 5
            # 플레이어가 주로 있는 쪽의 반대편으로 이동
            if recent_avg < WIDTH // 2:
                optimal_return_position = WIDTH // 2 + 40
            else:
                optimal_return_position = WIDTH // 2 - 40
        # 현재 위치와 최적 반격 위치 사이의 균형
        blend_factor = min(0.25, (BALL.centery - HEIGHT // 2) / (HEIGHT // 2))
        target_position = predicted_x * (1 - blend_factor) + optimal_return_position * blend_factor
        target_distance = target_position - BOSS.centerx
        # 부드러운 복귀 움직임
        if abs(target_distance) > 15:
            boss_current_speed = math.copysign(enhanced_max_speed * 0.6, target_distance)
    # 12️⃣ 위치 업데이트 및 벽 바운스 활용
    BOSS.x += boss_current_speed
    # 벽 근처에서 특수 움직임 (신화리그 전용)
    if BOSS.x <= 5:
        # 왼쪽 벽: 빠른 반사
        boss_current_speed = abs(boss_current_speed) * 0.8
        BOSS.x = 5
    elif BOSS.x >= WIDTH - BOSS.width - 5:
        # 오른쪽 벽: 빠른 반사
        boss_current_speed = -abs(boss_current_speed) * 0.8
        BOSS.x = WIDTH - BOSS.width - 5
    else:
        BOSS.x = max(0, min(WIDTH - BOSS.width, BOSS.x))
    # 9️⃣ 디버그 정보 (가끔씩만)
    if random.random() < 0.02:  # 2% 확률
        print(f"👑 신화리그 AI: 속도={current_speed:.1f}, 예측=[{predictions[0]:.0f},{predictions[1]:.0f},{predictions[2]:.0f}], 최종={predicted_x:.0f}, 거리={target_distance:.0f}")
def handle_boss_junior():
    """초보자 모드: Disabled보다 훨씬 쉬운 AI (연습용)"""
    global boss_current_speed, boss_fail_timer, BOSS_ACCELERATION, BOSS_DECELERATION, BOSS_MAX_SPEED, BOSS_INSTANT_STOP_DECELERATION
    global boss_fake_move, boss_fake_start_time, is_player_serve, is_waiting_for_serve
    global boss_fake_during_player_serve, waiting_start_time, wait_delay
    global ball_vel, boss_stunned_timer, boss_knockback_vel
    # 🔥 보스 스턴 상태 처리 (화염병 효과)
    if boss_stunned_timer > 0:
        boss_stunned_timer -= 1
        # 넉백 적용
        BOSS.x += boss_knockback_vel
        BOSS.x = max(0, min(WIDTH - PADDLE_WIDTH, BOSS.x))
        # 감속
        boss_knockback_vel *= 0.85
        return  # 스턴 중에는 AI 비활성화
    # 🎾 서브 대기 상태 처리 (기존 로직과 동일)
    if is_waiting_for_serve:
        time_now = pygame.time.get_ticks()
        # 보스 패들 간보기 움직임 (더 단순하게)
        def fake_motion():
            style = random.randint(1, 2)  # 스타일 2개만 사용
            if style == 1:
                return math.sin(time_now / 150) * 1.5  # 더 느리고 작은 움직임
            elif style == 2 and random.random() < 0.01:  # 확률 절반으로 감소
                return random.choice([-1, 1]) * random.randint(10, 20)  # 더 작은 움직임
            return 0
        # --- 보스 서브 차례 ---
        if not is_player_serve:
            if boss_fake_move and time_now - boss_fake_start_time < wait_delay:
                BOSS.centerx += fake_motion()
            if wait_delay > 0 and time_now - waiting_start_time >= wait_delay:
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                calculate_bounce(BOSS)
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
            if wait_delay == 0:
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                calculate_bounce(BOSS)
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
        # --- 플레이어 서브 차례 ---
        elif boss_fake_during_player_serve:
            BOSS.centerx += fake_motion()
        return  # 서브 중에는 아래 일반 이동 로직 실행 안 함
    # 😊 초보자를 위한 약간 쉬운 AI (서브가 아닐 때만)
    # 현재 공 속도 분석 (최신 시스템)
    current_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
    # 🌱 주니어리그: 통합 보스 설정 (스테이지별 + 리그별 완전 연계)
    config = get_final_boss_config(current_stage, "junior")
    enhanced_max_speed = config["max_speed"]
    enhanced_acceleration = config["accel"]
    enhanced_deceleration = config["decel"]
    # Disabled에 가까운 예측 프레임
    predict_frame = 10  # Disabled에 더 가까운 예측 프레임
    # 🌱 주니어리그용 설정 (초심자 친화적)
    junior_settings = {
        "predict_chance": 0.30,    # 30% 확률로 예측 (매우 낮은 예측 능력)
        "predict_error": 150,      # 매우 큰 오차 (±150px)
        "fail_chance": 0.30,       # 30% 확률로 실수 (매우 높은 실수율)
        "max_speed": 7.0,          # 매우 느린 최대 속도
        "acceleration": 1.0        # 매우 낮은 가속도
    }
    # 🌱 주니어리그 예측 로직 (매우 부정확)
    if random.random() < junior_settings["predict_chance"]:
        future_x = BALL.centerx + ball_vel[0] * predict_frame
    else:
        future_x = BALL.centerx  # 현재 위치로만 이동
    # 큰 오차 추가
    future_x += random.randint(-junior_settings["predict_error"], junior_settings["predict_error"])
    # 🌱 주니어리그 실수 모드 (빈번하게 발생, 최신 공 매커니즘 고려)
    if random.random() < junior_settings["fail_chance"]:
        boss_fail_timer = 40  # 1.3초간 실패 상태 (더 오래 실수)
        # 공 속도가 높을수록 더 큰 실수 (최신 시스템 반영)
        mistake_scale = min(200, max(100, current_speed * 8))
        future_x += random.randint(-int(mistake_scale), int(mistake_scale))
        if random.random() < 0.05:  # 가끔 디버그
            print(f"🌱 주니어리그 AI: 큰 실수! 속도={current_speed:.1f}, 오차=±{mistake_scale:.0f}")
    # 향상된 이동 로직
    target_distance = future_x - BOSS.centerx
    if abs(target_distance) < 25:  # 🌱 주니어리그: 더 큰 허용 범위 (정확도 낮음)
        boss_current_speed *= 0.85  # 느린 감속
    elif target_distance < 0:  # 왼쪽으로
        boss_current_speed = max(-enhanced_max_speed, boss_current_speed - enhanced_acceleration)
    else:  # 오른쪽으로
        boss_current_speed = min(enhanced_max_speed, boss_current_speed + enhanced_acceleration)
    # 위치 업데이트
    BOSS.x += boss_current_speed
    BOSS.x = max(0, min(WIDTH - BOSS.width, BOSS.x))
def optimize_ai_memory_for_round():
    """라운드 간 AI 메모리 최적화 (가벼운 정리)"""
    global enhanced_ai, ai_decisions_history, ai_performance_stats
    if not AI_AVAILABLE or not enhanced_ai:
        return
    try:
        # 🚀 결정 기록 정리 (최근 5개만 유지)
        if len(ai_decisions_history) > 5:
            ai_decisions_history = ai_decisions_history[-5:]
        # 🚀 성능 통계 압축 (최근 50개만 유지)
        if len(ai_performance_stats["confidence_history"]) > 50:
            ai_performance_stats["confidence_history"] = ai_performance_stats["confidence_history"][-50:]
        print("🧠 라운드 간 AI 메모리 정리 완료")
    except Exception as e:
        print(f"⚠️ AI 메모리 정리 중 오류: {e}")
def optimize_ai_memory_for_stage_transition():
    """스테이지 간 AI 메모리 최적화 (강력한 정리)"""
    global enhanced_ai, ai_decisions_history, ai_performance_stats
    if not AI_AVAILABLE or not enhanced_ai:
        return
    try:
        # 🚀 강력한 메모리 정리
        print("🧠 스테이지 전환: AI 메모리 최적화 시작...")
        # 결정 기록 완전 정리
        ai_decisions_history.clear()
        # 성능 통계 압축 (최근 20개만 유지)
        if len(ai_performance_stats["confidence_history"]) > 20:
            ai_performance_stats["confidence_history"] = ai_performance_stats["confidence_history"][-20:]
        # 성능 카운터 압축
        if ai_performance_stats["total_decisions"] > 1000:
            ai_performance_stats["total_decisions"] = min(ai_performance_stats["total_decisions"], 500)
        # 🚀 AI 메모리 최적화 (GodMode만 필요시)
            if hasattr(enhanced_ai, 'performance_history') and len(enhanced_ai.performance_history) > 100:
                enhanced_ai.performance_history = enhanced_ai.performance_history[-100:]
        print("✅ 스테이지 전환: AI 메모리 최적화 완료!")
    except Exception as e:
        print(f"⚠️ AI 메모리 최적화 중 오류: {e}")
def draw_ai_visualization():
    """AI 상태 및 성능 시각화 (극한 최적화 - 거의 비활성화)"""
    if not ai_enabled or not AI_AVAILABLE:
        return
    # 원래 AI 시각화 로직 (항상 활성화)
    # AI 모드 표시
    font_small = pygame.font.SysFont("Arial", 20, bold=True)
    # 리그별 색상
    league_colors = {
        "junior": (100, 255, 100),    # 연두색
        "pro": (255, 200, 100),       # 주황색
        "champion": (255, 150, 255),  # 보라색
        "mythic": (255, 215, 0)       # 황금색
    }
    mode_color = league_colors.get(ai_mode, (200, 200, 200))
    mode_text = f"AI: {ai_mode.upper()}"
    mode_surface = font_small.render(mode_text, True, mode_color)
    SCREEN.blit(mode_surface, (10, HEIGHT - 100))
    # AI 결정 시각화
    if ai_decisions_history and len(ai_decisions_history) > 0:
        recent_decisions = ai_decisions_history[-10:]  # 최근 10개
        for i, decision_data in enumerate(recent_decisions):
            pos = decision_data["position"]
            confidence = decision_data.get("confidence", 0.5)
            # 확신도에 따른 색상
            if ai_mode == "mythic":
                # 신화리그 AI는 황금색 계열
                red = 255
                green = int(215 * confidence)
                blue = int(50 * confidence)
                color = (red, green, blue)
            else:
                # 전통적 AI는 회색 계열
                intensity = int(255 * confidence)
                color = (intensity, intensity, intensity)
            # 확신도 원
            alpha = 50 + int(200 * (i / len(recent_decisions)))
            radius = 2 + int(4 * confidence)
            draw.circle(color, (int(pos[0]), int(pos[1])), radius)
    # AI 성능 통계 표시
    if ai_performance_stats["confidence_history"]:
        avg_confidence = sum(ai_performance_stats["confidence_history"][-20:]) / min(20, len(ai_performance_stats["confidence_history"]))
        confidence_text = f"Confidence: {avg_confidence:.2f}"
        confidence_surface = font_small.render(confidence_text, True, (255, 255, 255))
        SCREEN.blit(confidence_surface, (10, HEIGHT - 80))
        # 성공률 표시
        total_results = ai_performance_stats["successful_hits"] + ai_performance_stats["missed_balls"]
        if total_results > 0:
            success_rate = ai_performance_stats["successful_hits"] / total_results
            success_text = f"Success: {success_rate:.1%}"
            success_color = (100, 255, 100) if success_rate > 0.7 else ((255, 255, 100) if success_rate > 0.5 else (255, 100, 100))
            success_surface = font_small.render(success_text, True, success_color)
            SCREEN.blit(success_surface, (10, HEIGHT - 60))
    # 신화리그 AI 정보 표시 (mythic일 때만)
    if ai_mode == "mythic":
        try:
            mythic_text = "MYTHIC LEAGUE ACTIVE"
            learning_surface = font_small.render(mythic_text, True, (255, 215, 0))
            SCREEN.blit(learning_surface, (10, HEIGHT - 40))
        except:
            pass  # 에러 무시
    # 조작 안내 (우측 하단)
    help_text = "N: Toggle AI Mode | ESC: Menu"
    help_surface = font_small.render(help_text, True, (150, 150, 150))
    SCREEN.blit(help_surface, (WIDTH - help_surface.get_width() - 10, HEIGHT - 30))
def draw_player_skill_display():
    """플레이어 실력 등급 표시"""
    global player_analyzer, skill_display_enabled, last_skill_update_time
    if not skill_display_enabled or not player_analyzer:
        return
    current_time = pygame.time.get_ticks()
    # 1초마다 업데이트 (성능 최적화)
    if current_time - last_skill_update_time < 1000:
        return
    last_skill_update_time = current_time
    try:
        # 현재 등급 정보 가져오기 (현재 스테이지 반영)
        current_stage = game_stage if 'game_stage' in globals() else 1
        rank_info = player_analyzer.get_current_rank(current_stage)
        detailed_stats = player_analyzer.get_detailed_analysis(current_stage)
        # UI 위치 (좌측 상단, AI 표시 아래)
        start_x = 10
        start_y = 150
        # 배경 박스
        box_width = 280
        box_height = 120
        box_surface = pygame.Surface((box_width, box_height), pygame.SRCALPHA)
        box_surface.fill((0, 0, 0, 180))  # 반투명 검은색
        pygame.draw.rect(box_surface, (100, 100, 100), (0, 0, box_width, box_height), 2)
        SCREEN.blit(box_surface, (start_x, start_y))
        # 폰트 설정
        font_title = pygame.font.Font(None, 24)
        font_stat = pygame.font.Font(None, 20)
        font_small = pygame.font.Font(None, 16)
        # 등급 표시
        rank_color = rank_info["color"]
        rank_text = f"{rank_info['icon']} {rank_info['name']} ({rank_info['score']}점)"
        rank_surface = font_title.render(rank_text, True, rank_color)
        SCREEN.blit(rank_surface, (start_x + 10, start_y + 10))
        # 등급 설명 표시
        if 'details' in rank_info:
            detail_surface = font_small.render(rank_info['details'], True, (200, 200, 200))
            SCREEN.blit(detail_surface, (start_x + 10, start_y + 35))
        # 다음 등급까지 진행률
        progress = rank_info["progress_to_next"]
        progress_text = f"다음 등급까지: {progress:.1f}%"
        progress_surface = font_small.render(progress_text, True, (200, 200, 200))
        SCREEN.blit(progress_surface, (start_x + 10, start_y + 35))
        # 진행률 바
        bar_x = start_x + 10
        bar_y = start_y + 50
        bar_width = 200
        bar_height = 8
        # 배경 바
        draw.rect((50, 50, 50), (bar_x, bar_y, bar_width, bar_height))
        # 진행률 바
        progress_width = int((progress / 100) * bar_width)
        draw.rect(rank_color, (bar_x, bar_y, progress_width, bar_height))
        # 주요 통계
        stats = detailed_stats["stats"]
        accuracy = stats["accuracy"]
        hit_streak = stats["hit_streak"]
        stats_text = f"정확도: {accuracy:.1f}% | 연속히트: {hit_streak}"
        stats_surface = font_stat.render(stats_text, True, (255, 255, 255))
        SCREEN.blit(stats_surface, (start_x + 10, start_y + 65))
        # 등급 설명
        desc_text = rank_info["description"]
        desc_surface = font_small.render(desc_text, True, (180, 180, 180))
        SCREEN.blit(desc_surface, (start_x + 10, start_y + 85))
        # 실시간 업적 알림 (최근 업적이 있으면)
        achievements = detailed_stats["achievements"]
        if achievements:
            latest_achievement = achievements[-1]
            achievement_surface = font_small.render(f"🎉 {latest_achievement}", True, (255, 215, 0))
            SCREEN.blit(achievement_surface, (start_x + 10, start_y + 100))
    except Exception as e:
        # 조용히 실패 처리 (성능 우선)
        pass
def record_player_hit(is_perfect_timing=False, is_power_smash=False):
    """플레이어 히트 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_hit(is_perfect_timing, is_power_smash)
        except:
            pass  # 조용히 실패
def record_player_miss():
    """플레이어 미스 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_miss()
        except:
            pass  # 조용히 실패
def record_skill_usage(success=False):
    """스킬 사용 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_skill_usage(success)
        except:
            pass  # 조용히 실패
def record_dash_usage(success=False):
    """대쉬 사용 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            # 공과 플레이어 사이의 거리 계산
            ball_distance = abs(BALL.centerx - PLAYER.centerx)
            ball_speed = math.hypot(ball_vel[0], ball_vel[1])
            player_analyzer.record_dash_usage(ball_distance, ball_speed, success)
        except:
            pass  # 조용히 실패
def record_dash_life_save():
    """대쉬로 생명을 구한 경우 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.stats.dash_life_saves += 1
            print(f"🏆 대쉬 생명 구조 기록! (총 {player_analyzer.stats.dash_life_saves}회)")
        except:
            pass  # 조용히 실패
def record_dash_victory():
    """대쉬로 승리에 기여한 경우 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.stats.dash_victories += 1
            print(f"🏆 대쉬 승리 기여 기록! (총 {player_analyzer.stats.dash_victories}회)")
        except:
            pass  # 조용히 실패
def score_to_grade(score):
    """점수를 등급으로 변환"""
    if score == 0:
        return "플레이 필요", (100, 100, 100)  # 회색 - 아직 플레이 안함
    elif score >= 90:
        return "S", (255, 215, 0)  # 골드
    elif score >= 80:
        return "A", (255, 100, 100)  # 레드
    elif score >= 70:
        return "B", (100, 255, 100)  # 그린
    elif score >= 60:
        return "C", (100, 150, 255)  # 블루
    elif score >= 50:
        return "D", (255, 255, 100)  # 옐로우
    elif score >= 30:
        return "E", (255, 150, 100)  # 오렌지
    else:
        return "F", (150, 150, 150)  # 그레이
def draw_ability_radar_chart(stats, center_x, center_y, radius=120):
    """능력치 레이더 차트 그리기"""
    import math
    # 능력치 데이터 (0-100 범위로 정규화)
    abilities = {
        "스킬 활용": stats['skill_mastery_score'],
        "대쉬 활용": stats['dash_mastery_score'], 
        "아이템 활용": stats['item_mastery_score'],
        "가드 능력": stats['guard_ability_score']
    }
    # 능력치 수
    num_abilities = len(abilities)
    angle_step = 2 * math.pi / num_abilities
    # 배경 원형 그리드 그리기 (20, 40, 60, 80, 100%)
    for i in range(1, 6):
        grid_radius = radius * (i / 5)
        draw.circle((50, 50, 50), (center_x, center_y), int(grid_radius), 1)
    # 축 선 그리기
    ability_names = list(abilities.keys())
    points = []
    for i, ability_name in enumerate(ability_names):
        angle = -math.pi / 2 + i * angle_step  # -90도부터 시작 (위쪽)
        # 축 선 그리기
        end_x = center_x + math.cos(angle) * radius
        end_y = center_y + math.sin(angle) * radius
        draw.line((100, 100, 100), (center_x, center_y), (end_x, end_y), 1)
        # 능력치 값에 따른 점 위치 계산
        value = abilities[ability_name]
        value_radius = radius * (value / 100)
        point_x = center_x + math.cos(angle) * value_radius
        point_y = center_y + math.sin(angle) * value_radius
        points.append((point_x, point_y))
        # 능력명 텍스트 표시
        text_font = pygame.font.Font("NanumSquareR.ttf", 16)
        text_x = center_x + math.cos(angle) * (radius + 30)
        text_y = center_y + math.sin(angle) * (radius + 30)
        # 등급 색상 적용
        grade, color = score_to_grade(value)
        ability_text = text_font.render(f"{ability_name}", True, WHITE)
        grade_text = text_font.render(f"({grade})", True, color)
        # 텍스트 위치 조정
        if text_x < center_x:  # 왼쪽
            ability_rect = ability_text.get_rect(right=text_x - 5, centery=text_y)
            grade_rect = grade_text.get_rect(right=text_x - 5, centery=text_y + 18)
        else:  # 오른쪽
            ability_rect = ability_text.get_rect(left=text_x + 5, centery=text_y)
            grade_rect = grade_text.get_rect(left=text_x + 5, centery=text_y + 18)
        SCREEN.blit(ability_text, ability_rect)
        SCREEN.blit(grade_text, grade_rect)
    # 능력치 영역 채우기 (반투명)
    if len(points) >= 3:
        # 반투명 서페이스 생성
        overlay = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
        # 중심을 기준으로 좌표 변환
        relative_points = [(x - center_x + radius, y - center_y + radius) for x, y in points]
        pygame.draw.polygon(overlay, (100, 150, 255, 80), relative_points)
        SCREEN.blit(overlay, (center_x - radius, center_y - radius))
    # 능력치 점들을 선으로 연결
    if len(points) >= 2:
        draw.polygon((100, 150, 255), points, 2)
    # 능력치 점 표시
    for point in points:
        draw.circle((255, 255, 255), (int(point[0]), int(point[1])), 4)
        draw.circle((100, 150, 255), (int(point[0]), int(point[1])), 3)
    # 중심점 표시
    draw.circle((200, 200, 200), (center_x, center_y), 3)
    # 퍼센트 표시 (격자 옆)
    percent_font = pygame.font.Font("NanumSquareR.ttf", 12)
    for i in range(1, 6):
        percent = i * 20
        percent_text = percent_font.render(f"{percent}%", True, (150, 150, 150))
        percent_rect = percent_text.get_rect(left=center_x + radius * (i / 5) + 5, centery=center_y)
        SCREEN.blit(percent_text, percent_rect)
def record_stage_result(stage, cleared=False):
    """스테이지 결과 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_stage_result(stage, cleared)
            # 실시간 평가 시스템으로 변경됨 - 더 이상 특별 메시지 불필요
        except:
            pass  # 조용히 실패
def record_item_usage(item_name, was_effective=False, is_combo=False):
    """아이템 사용 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_item_usage(item_name, was_effective, is_combo)
        except:
            pass  # 조용히 실패
def record_guard_action(ball_distance, ball_speed, is_close_call=False):
    """가드 능력 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_guard_action(ball_distance, ball_speed, is_close_call)
        except:
            pass  # 조용히 실패
def record_skill_victory():
    """스킬로 승리한 경우 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_skill_victory()
        except:
            pass  # 조용히 실패
def record_dash_life_save():
    """대쉬로 생명을 구한 경우 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_dash_life_save()
        except:
            pass  # 조용히 실패
def record_dash_victory():
    """대쉬로 승리한 경우 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_dash_victory()
        except:
            pass  # 조용히 실패
def record_dash_defensive_save():
    """대쉬로 불가능한 영역에서 가드한 경우 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_dash_defensive_save()
        except:
            pass  # 조용히 실패
def record_dash_clutch_victory():
    """대쉬 공격으로 직접 승리한 경우 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_dash_clutch_victory()
        except:
            pass  # 조용히 실패
def record_speed_adaptation(ball_speed):
    """공속도 적응 점수 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_speed_adaptation(ball_speed)
        except:
            pass  # 조용히 실패
def record_victory_result(player_wins, boss_wins):
    """승부 결과 기록 (3-0, 3-1, 3-2 등)"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_victory_result(player_wins, boss_wins)
        except:
            pass  # 조용히 실패
def record_item_clutch_use():
    """상황에 맞는 아이템 사용 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_item_clutch_use()
        except:
            pass  # 조용히 실패
def record_critical_miss():
    """치명적인 실수 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_critical_miss()
        except:
            pass  # 조용히 실패
def record_poor_timing_hit():
    """타이밍이 나쁜 히트 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_poor_timing_hit()
        except:
            pass  # 조용히 실패
def record_wasted_skill():
    """무의미하게 낭비된 스킬 사용 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_wasted_skill()
        except:
            pass  # 조용히 실패
def record_wasted_dash():
    """무의미하게 낭비된 대쉬 사용 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_wasted_dash()
        except:
            pass  # 조용히 실패
def record_missed_opportunity():
    """놓친 기회 기록"""
    global player_analyzer
    if player_analyzer:
        try:
            player_analyzer.record_missed_opportunity()
        except:
            pass  # 조용히 실패
def handle_boss():
    global boss_speed_boost_timer, BOSS_SPEED, boss_fake_move, boss_fake_start_time
    global is_player_serve, is_waiting_for_serve, boss_fake_during_player_serve
    global speed_defense_active, speed_defense_timer, boss_current_speed, boss_fail_timer
    global BOSS_ACCELERATION, BOSS_DECELERATION, BOSS_MAX_SPEED, BOSS_INSTANT_STOP_DECELERATION, waiting_start_time, wait_delay
    global boss_throwing, boss_throw_timer  # 🔹 Stage 5 화염탄 관련 변수
    global ball_vel, boss_stunned_timer, boss_knockback_vel  # 🔥 화염병 스턴 관련 변수
    # 🏆 리그별 AI 모드 체크 및 분기 (4단계 리그 시스템)
    if ai_enabled and ai_mode == "junior":
        # 🌱 주니어리그: 초심자용 쉬운 AI (실수 25%)
        handle_boss_junior()
        return
    elif ai_enabled and ai_mode == "pro":
        # ⚡ 프로리그: 표준 AI (실수 15%)
        handle_boss_pro()
        return
    elif ai_enabled and ai_mode == "champion":
        # 💎 챔피언리그: 고급 AI (실수 8%)
        handle_boss_champion()
        return
    elif ai_enabled and ai_mode == "mythic":
        # 👑 신화리그: 최강 AI (실수 2%)
        handle_boss_mythic()
        return
    # 🆕 새로운 보스 모드에서는 상단 보스가 handle_boss 역할
    if new_boss_mode_active:
        if selected_top_boss == 1:
            handle_lightning_master_as_top()  # 라이트닝 마스터
        elif selected_top_boss == 2:
            handle_ice_queen_as_top()  # 아이스 퀸
        return
    # 💥 고스트샷 넉백 처리
    global boss_knockback_timer, boss_knockback_distance
    if boss_knockback_timer > 0:
        boss_knockback_timer -= 1
        # 보스를 위로 밀어냄
        knockback_amount = boss_knockback_distance / 30  # 30프레임에 걸쳐 밀려남
        BOSS.y -= knockback_amount
        BOSS.y = max(50, BOSS.y)  # 최소 Y 위치 제한
        # 좌우로도 약간 흔들림
        shake_x = random.uniform(-3, 3)
        BOSS.x += shake_x
        BOSS.x = max(0, min(WIDTH - PADDLE_WIDTH, BOSS.x))
        # 타이머가 끝나면 원위치로 돌아오기 시작
        if boss_knockback_timer == 0:
            boss_knockback_distance = 0
    else:
        # 원래 위치로 부드럽게 복귀
        if BOSS.y < BOSS_Y:
            BOSS.y += 2
            BOSS.y = min(BOSS_Y, BOSS.y)
    # 🔥 보스 스턴 상태 처리 (화염병 효과) - AI 비활성화 상태에서도 작동
    if boss_stunned_timer > 0:
        boss_stunned_timer -= 1
        # 넉백 적용
        BOSS.x += boss_knockback_vel
        BOSS.x = max(0, min(WIDTH - PADDLE_WIDTH, BOSS.x))
        # 감속
        boss_knockback_vel *= 0.85
        return  # 스턴 중에는 AI 비활성화
    # 일반 보스 AI: 통합 보스 설정 (스테이지별 + 리그별 완전 연계)
    config = get_final_boss_config(current_stage, ai_mode)
    # --- Stage 5 화염탄 던지는 중에는 0.5초간 이동 금지 ---
    if current_stage == 5 and boss_throwing:
        boss_current_speed = 0
        # boss_throw_timer를 프레임 단위로 사용하고 있다면 30fps 기준 약 15프레임 = 0.5초
        boss_throw_timer -= 1
        if boss_throw_timer <= 0:
            boss_throwing = False
        return  # 🔹 이동 로직을 아예 스킵
    # --- Stage 6 항공모함 보스: 서브 대기 상태가 아닐 때만 근엄한 움직임 ---
    if current_stage == 6 and not is_waiting_for_serve:
        # 중앙 기준점 설정
        center_x = WIDTH // 2
        movement_range = 80  # 중앙에서 좌우 80픽셀 범위
        # 항공모함 보스 전용 움직임 변수 초기화
        if not hasattr(handle_boss, 'carrier_target'):
            handle_boss.carrier_target = center_x
            handle_boss.carrier_direction = 1
            handle_boss.carrier_pause_timer = 0
        # 일정 시간마다 방향 전환 (근엄한 패턴)
        handle_boss.carrier_pause_timer += 1
        # 180프레임(3초)마다 새로운 목표점 설정
        if handle_boss.carrier_pause_timer >= 180:
            handle_boss.carrier_pause_timer = 0
            # 중앙 범위 내에서 새로운 목표점 선택
            handle_boss.carrier_target = center_x + random.randint(-movement_range, movement_range)
            handle_boss.carrier_target = max(BOSS.width // 2, 
                                           min(WIDTH - BOSS.width // 2, handle_boss.carrier_target))
        # 현재 목표점으로 천천히 이동 (근엄한 속도)
        carrier_speed = 1.5  # 매우 느린 속도
        if BOSS.centerx < handle_boss.carrier_target - 5:
            BOSS.centerx += carrier_speed
        elif BOSS.centerx > handle_boss.carrier_target + 5:
            BOSS.centerx -= carrier_speed
        # 경계 처리
        BOSS.centerx = max(BOSS.width // 2, min(WIDTH - BOSS.width // 2, BOSS.centerx))
        return  # 스테이지 6은 일반 AI 로직 스킵
    # --- 서브 대기 상태 처리 ---
    if is_waiting_for_serve:
        time_now = pygame.time.get_ticks()
        # 스테이지 6: 항공모함 보스는 서브 대기 중에도 특별한 움직임
        if current_stage == 6:
            # 항공모함 보스 서브 대기 중 움직임 (매우 미세한 좌우 이동)
            def carrier_standby_motion():
                return math.sin(time_now / 200) * 0.8  # 매우 느리고 작은 움직임
        else:
            # 보스 패들 간보기 움직임 (일반 스테이지)
            def fake_motion():
                style = random.randint(1, 4)
                if style == 1:
                    return math.sin(time_now / 100) * 2.5
                elif style == 2 and random.random() < 0.02:
                    return random.choice([-1, 1]) * random.randint(20, 30)
                elif style == 3:
                    return math.sin(time_now / 300) * 4
                elif style == 4 and random.random() < 0.015:
                    return random.choice([-1, 1]) * 10
                return 0
        # --- 보스 서브 차례 ---
        if not is_player_serve:
            if current_stage == 6:
                # 항공모함 보스는 항상 미세한 움직임
                BOSS.centerx += carrier_standby_motion()
                # 경계 처리
                BOSS.centerx = max(BOSS.width // 2, min(WIDTH - BOSS.width // 2, BOSS.centerx))
            elif boss_fake_move and time_now - boss_fake_start_time < wait_delay:
                BOSS.centerx += fake_motion()
            # 모든 스테이지에서 서브 로직 실행 (스테이지 6 포함)
            if wait_delay > 0 and time_now - waiting_start_time >= wait_delay:
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                # 🏓 보스 서브 시에도 물리 효과 적용
                calculate_bounce(BOSS)
                # 🎯 보스 서브 시 타격 이펙트 생성
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
            if wait_delay == 0:
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                # 🏓 보스 서브 시에도 물리 효과 적용
                calculate_bounce(BOSS)
                # 🎯 보스 서브 시 타격 이펙트 생성
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=False)
        # --- 플레이어 서브 차례 ---
        elif boss_fake_during_player_serve:
            if current_stage == 6:
                # 항공모함 보스는 플레이어 서브 중에도 미세한 움직임
                BOSS.centerx += carrier_standby_motion()
                # 경계 처리
                BOSS.centerx = max(BOSS.width // 2, min(WIDTH - BOSS.width // 2, BOSS.centerx))
            else:
                BOSS.centerx += fake_motion()
        return  # 서브 중에는 아래 일반 이동 로직 실행 안 함
    # --- 일반 AI 이동 로직 ---
    predict_frame = max(10, min(30, int(60 / max(1, abs(ball_vel[0])))))
    # --- 기존 AI 로직 ---
    enhanced_fail_chance = config["fail_chance"]
    enhanced_predict_chance = config["predict_chance"]
    enhanced_predict_error = config["predict_error"]
    enhanced_fail_error = config["fail_error"]
    # 조명탄 혼란 효과 체크 (최우선)
    if boss_confused_timer > 0:
        # 혼란 상태일 때는 완전히 랜덤하게 움직임 (공을 무시)
        if not hasattr(handle_boss, 'confusion_target_ai'):
            handle_boss.confusion_target_ai = random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)
            handle_boss.confusion_direction_timer_ai = 0
        # 30프레임마다 새로운 랜덤 위치 선택
        handle_boss.confusion_direction_timer_ai = getattr(handle_boss, 'confusion_direction_timer_ai', 0) + 1
        if handle_boss.confusion_direction_timer_ai >= 30:
            handle_boss.confusion_target_ai = random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)
            handle_boss.confusion_direction_timer_ai = 0
        # 랜덤 목표 지점으로 이동
        future_x = handle_boss.confusion_target_ai
        # 가끔 갑자기 방향 전환 (20% 확률)
        if random.random() < 0.2:
            future_x = random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)
    # --- 멍청 모드 처리 ---
    elif boss_fail_timer > 0:
        future_x = BALL.centerx + ball_vel[0] * predict_frame
        future_x += random.randint(-enhanced_fail_error, enhanced_fail_error)
        boss_fail_timer -= 1
    else:
        if random.random() < enhanced_fail_chance:
            boss_fail_timer = 60
            future_x = BALL.centerx + ball_vel[0] * predict_frame
            future_x += random.randint(-enhanced_fail_error, enhanced_fail_error)
        else:
            if random.random() < enhanced_predict_chance:
                future_x = BALL.centerx + ball_vel[0] * predict_frame
            else:
                future_x = BALL.centerx
            future_x += random.randint(-enhanced_predict_error, enhanced_predict_error)
    # --- 가속/감속 로직: 통합 설정 기반 ---
    # 스피드디펜스 활성화 시 전역 변수 사용, 아니면 config 사용
    if current_stage == 2 and speed_defense_active:
        enhanced_accel = BOSS_ACCELERATION
        enhanced_decel = BOSS_DECELERATION
        enhanced_max_speed = BOSS_MAX_SPEED
        enhanced_instant_stop = BOSS_INSTANT_STOP_DECELERATION
    else:
        enhanced_accel = config["accel"]
        enhanced_decel = config["decel"]
        enhanced_max_speed = config["max_speed"]
        enhanced_instant_stop = config["instant_stop"]
    # 🔥 화염 지대 내에서 속도 감소 효과 적용
    if boss_speed_reduction_active:
        enhanced_accel *= boss_speed_reduction_factor  # 가속도 50% 감소
        enhanced_max_speed *= boss_speed_reduction_factor  # 최대 속도 50% 감소
        # 현재 속도도 즉시 감소
        boss_current_speed *= boss_speed_reduction_factor
    # 기존 AI 움직임 로직
    if future_x < BOSS.centerx:
        if boss_current_speed > -enhanced_max_speed:
            boss_current_speed -= enhanced_accel
    elif future_x > BOSS.centerx:
        if boss_current_speed < enhanced_max_speed:
            boss_current_speed += enhanced_accel
    else:
        if boss_current_speed > 0:
            boss_current_speed -= enhanced_decel
        elif boss_current_speed < 0:
            boss_current_speed += enhanced_decel
    # 급정지 처리
    if future_x < BOSS.centerx and boss_current_speed > 0:
        boss_current_speed -= enhanced_instant_stop
    elif future_x > BOSS.centerx and boss_current_speed < 0:
        boss_current_speed += enhanced_instant_stop
    # 이동 적용
    BOSS.centerx += boss_current_speed
    BOSS.centerx = max(BOSS.width // 2, min(WIDTH - BOSS.width // 2, BOSS.centerx))
    # --- Stage 2 보스 스피드 디펜스 (위험감지센서 역할) ---
    if current_stage == 2:
        # 플레이어가 친 공이 보스에게 위험할 때 발동
        if not speed_defense_active and speed_defense_timer <= 0 and ball_vel[1] < 0:  # 공이 위로 향할 때
            # 공이 보스 근처에 도달할 시간 예측
            if BALL.centery < HEIGHT * 0.35:  # 공이 화면 상단 35% 지점 이상 (조금 더 일찍 감지)
                time_to_reach_boss = abs((BOSS.centery - BALL.centery) / ball_vel[1]) if ball_vel[1] < 0 else float('inf')
                if time_to_reach_boss < 30:  # 0.5초 이내에 도달 예정 (더 여유있게)
                    predicted_x = BALL.centerx + ball_vel[0] * time_to_reach_boss
                    distance_to_predicted = abs(predicted_x - BOSS.centerx)
                    # 보스가 현재 속도로 이동해도 도달하기 어려운 위치인지 확인
                    boss_max_move = BOSS_MAX_SPEED_DEFAULT * time_to_reach_boss
                    # 위험 감지: 보스가 도달하기 어려운 거리 (더 민감하게)
                    if distance_to_predicted > boss_max_move * 0.8:  # 80% 이상 도달 어려움 (더 민감)
                        # 3% 확률로 스피드디펜스 발동
                        if random.random() < 0.03:
                            speed_defense_active = True
                            speed_defense_timer = speed_defense_cooldown
                            # 현재 보스 속도의 160% (+60%)로 스피드디펜스 설정
                            # 리그와 스테이지에 따른 현재 보스 속도 가져오기
                            current_config = get_final_boss_config(current_stage, ai_mode if ai_enabled else "pro")
                            # 스피드디펜스: 현재 속도의 160% 적용
                            speed_multiplier = 1.6  # 60% 증가
                            BOSS_ACCELERATION = current_config["accel"] * speed_multiplier
                            BOSS_DECELERATION = current_config["decel"] * speed_multiplier
                            BOSS_MAX_SPEED = current_config["max_speed"] * speed_multiplier
                            BOSS_INSTANT_STOP_DECELERATION = current_config["instant_stop"] * speed_multiplier
                            # 즉시 목표 지점으로 가속 시작
                            if predicted_x < BOSS.centerx:
                                boss_current_speed = -BOSS_MAX_SPEED * 0.3  # 왼쪽으로 초기 속도 부여 (최대속도의 30%)
                            else:
                                boss_current_speed = BOSS_MAX_SPEED * 0.3   # 오른쪽으로 초기 속도 부여 (최대속도의 30%)
                            SOUND_DEFENSE_START.play()
                            print(f"⚡ 스피드디펜스 발동! 위험 감지 - 예상거리: {distance_to_predicted:.1f}, 최대이동가능: {boss_max_move:.1f}")
        if speed_defense_timer > 0:
            speed_defense_timer -= 1
        if speed_defense_active and speed_defense_timer <= 0:
            speed_defense_active = False
            boss_trail.clear()  # 🆕 스피드 디펜스 종료 시 꼬리 효과 즉시 정리
            BOSS_ACCELERATION = BOSS_ACCELERATION_DEFAULT
            BOSS_DECELERATION = BOSS_DECELERATION_DEFAULT
            BOSS_MAX_SPEED = BOSS_MAX_SPEED_DEFAULT
            BOSS_INSTANT_STOP_DECELERATION = BOSS_INSTANT_STOP_DECELERATION_DEFAULT
def show_death_evaluation():
    """사망 시 실력 평가 화면 표시"""
    global player_analyzer, current_stage
    if not player_analyzer:
        return
    clock = pygame.time.Clock()
    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE or event.key == pygame.K_SPACE:
                    return  # 평가 화면 종료
        SCREEN.fill(BLACK)
        # 제목
        title_font = pygame.font.Font("NanumSquareEB.ttf", 36)
        title_text = title_font.render("게임 종료 - 최종 실력 평가", True, WHITE)
        title_rect = title_text.get_rect(center=(WIDTH // 2, 60))
        SCREEN.blit(title_text, title_rect)
        # 스테이지별 난이도 반영된 평가 표시
        try:
            detailed_stats = player_analyzer.get_detailed_stats(current_stage)
            stats = detailed_stats["stats"]
            # 각 능력의 등급과 색상 계산
            skill_grade, skill_color = score_to_grade(stats['skill_mastery_score'])
            dash_grade, dash_color = score_to_grade(stats['dash_mastery_score'])
            item_grade, item_color = score_to_grade(stats['item_mastery_score'])
            guard_grade, guard_color = score_to_grade(stats['guard_ability_score'])
            font_medium = pygame.font.Font("NanumSquareB.ttf", 24)
            font_small = pygame.font.Font("NanumSquareR.ttf", 18)
            y_start = 120
            # 스테이지 정보
            stage_text = font_medium.render(f"도달 스테이지: {current_stage} (난이도 보정: {player_analyzer.get_stage_difficulty_multiplier(current_stage):.1f}x)", True, YELLOW)
            stage_rect = stage_text.get_rect(center=(WIDTH // 2, y_start))
            SCREEN.blit(stage_text, stage_rect)
            # 왼쪽에 텍스트, 오른쪽에 레이더 차트 동시 표시
            # 왼쪽 영역: 능력별 등급 표시
            abilities = [
                ("스킬 활용 능력", skill_grade, skill_color),
                ("대쉬 활용 능력", dash_grade, dash_color),
                ("아이템 활용 능력", item_grade, item_color),
                ("가드 능력", guard_grade, guard_color)
            ]
            left_start_x = WIDTH // 4
            for i, (ability_name, grade, color) in enumerate(abilities):
                y_pos = y_start + 80 + i * 40
                # 능력명 (흰색)
                name_text = font_medium.render(f"{ability_name}:", True, WHITE)
                name_rect = name_text.get_rect(center=(left_start_x - 50, y_pos))
                SCREEN.blit(name_text, name_rect)
                # 등급 (등급별 색상)
                grade_text = font_medium.render(grade, True, color)
                grade_rect = grade_text.get_rect(center=(left_start_x + 80, y_pos))
                SCREEN.blit(grade_text, grade_rect)
            # 전체 실력 점수 (왼쪽 하단)
            skill_score = player_analyzer.calculate_skill_score(current_stage)
            score_text = font_medium.render(f"전체 실력 점수: {skill_score}/2000", True, CYAN)
            score_rect = score_text.get_rect(center=(left_start_x, y_start + 250))
            SCREEN.blit(score_text, score_rect)
            # 점수 계산 세부사항 표시
            font_tiny = pygame.font.Font("NanumSquareR.ttf", 14)
            detail_y = y_start + 280
            # 각 능력별 점수 기여도 표시
            skill_contrib = min(250, stats['skill_mastery_score'] * 2.5 * player_analyzer.get_stage_difficulty_multiplier(current_stage))
            dash_contrib = min(250, stats['dash_mastery_score'] * 2.5 * player_analyzer.get_stage_difficulty_multiplier(current_stage))
            item_contrib = min(250, stats['item_mastery_score'] * 2.5 * player_analyzer.get_stage_difficulty_multiplier(current_stage))
            guard_contrib = min(250, stats['guard_ability_score'] * 2.5 * player_analyzer.get_stage_difficulty_multiplier(current_stage))
            detail_text = font_tiny.render(f"점수 구성: 스킬 {int(skill_contrib)} + 대쉬 {int(dash_contrib)} + 아이템 {int(item_contrib)} + 가드 {int(guard_contrib)}", True, (200, 200, 200))
            detail_rect = detail_text.get_rect(center=(WIDTH // 2, detail_y))
            SCREEN.blit(detail_text, detail_rect)
            # 보너스/페널티 표시
            victory_bonus = player_analyzer.get_victory_bonus()
            mistake_penalty = player_analyzer.get_mistake_penalty()
            stage_bonus = player_analyzer.get_stage_challenge_bonus(current_stage)
            bonus_text = font_tiny.render(f"보너스: +{victory_bonus + stage_bonus} (승리/스테이지) | 페널티: -{mistake_penalty} (실수)", True, (200, 200, 200))
            bonus_rect = bonus_text.get_rect(center=(WIDTH // 2, detail_y + 20))
            SCREEN.blit(bonus_text, bonus_rect)
            # 오른쪽 영역: 레이더 차트 (조금 더 왼쪽으로 이동)
            chart_center_x = WIDTH * 5 // 8  # 3/4에서 5/8로 변경하여 왼쪽으로 이동
            chart_center_y = y_start + 160
            draw_ability_radar_chart(stats, chart_center_x, chart_center_y, 100)
            # 조작 안내
            info_text = font_small.render("ESC/Space: 닫기", True, GRAY)
            info_rect = info_text.get_rect(center=(WIDTH // 2, HEIGHT - 40))
            SCREEN.blit(info_text, info_rect)
        except Exception as e:
            error_text = font_medium.render("평가 데이터를 불러올 수 없습니다.", True, RED)
            error_rect = error_text.get_rect(center=(WIDTH // 2, HEIGHT // 2))
            SCREEN.blit(error_text, error_rect)
        pygame.display.flip()
        clock.tick(60)
def show_result(won):
    global medal_score, current_stage, session_medal_earned, special_gauge, special_ready, special_active
    global speedboots_obtained, speedgear_obtained  # 🆕 패시브 아이템 효과 초기화용
    global aipill_active  # 🆕 AI 필 변수 추가
    global battery_obtained  # 🆕 배터리 변수 추가
    global revival_obtained, revival_used  # 🆕 부활 변수 추가
    global master_obtained, cooltime_obtained  # 🆕 장인, 쿨타임 변수 추가
    global chargebag_obtained, spikeboots_obtained, dashgear_obtained  # 🆕 충전가방, 스파이크부츠, 대쉬기어 변수 추가
    global bulkup_obtained, dashholder_obtained, gravitybelt_obtained  # 🆕 벌크업, 대쉬홀더, 무중력벨트 변수 추가
    global danger_sensor_obtained, sensor_obtained  # 🆕 센서 관련 변수 추가
    global rolling_charges, gravity_speed_synergy  # 🆕 대쉬 토큰 수, 시너지 효과 변수 추가
    global walls, passive_item_list, round_losses  # 🆕 벽돌 변수 추가
    global deuce_mode, deuce_wins, deuce_losses, deuce_goal  # 🆕 듀스 시스템 변수 추가
    global whip_sound  # 🆕 상모돌리기 사운드 추가
    global balloon_active, balloon_timer, balloons, balloon_used_this_round  # 🆕 풍선 스킬 변수 추가
    global boss_hit_animation_active, boss_hit_animation_timer  # 🆕 보스 충돌 애니메이션 변수 추가
    global whip_active, whip_timer, whip_hit_by_player, whip_original_ball_speed  # 🆕 상모돌리기 관련 변수 추가
    global emotional_overdrive_active, emotional_overdrive_timer, overdrive_flash_timer, overdrive_trails  # 🆕 사이코볼 관련 변수 추가
    global boss_special_gauge, boss_special_ready, boss_special_waiting, boss_red_intensity  # 🆕 멘헤라걸 관련 변수 추가
    # 필살기 초기화 (Aipill 활성화 시 또는 배터리 보유 시에는 게이지 유지)
    if not aipill_active and not battery_obtained:
        special_gauge = 0
        special_ready = False
        special_active = False
    # 🆕 벽돌 초기화 (다음 스테이지로 넘어가면 벽돌 사라짐)
    walls.clear()
    # 🆕 Aipill 초기화 (다음 라운드로 넘어가면 Aipill 효과 종료)
    if aipill_active:
        print("라운드 종료로 인해 Aipill 효과가 종료됩니다.")
        aipill_active = False
    # 🆕 상모돌리기 완전 초기화 (스테이지 종료 시)
    whip_active = False
    whip_timer = 0
    whip_hit_by_player = False
    whip_original_ball_speed = [0, 0]
    whip_sound.stop()
    if BOSS and hasattr(BOSS, 'whip_sound') and BOSS.whip_sound:
        BOSS.whip_sound.stop()
    # 🆕 사이코볼(감정 오버드라이브) 완전 초기화 (스테이지 종료 시)
    emotional_overdrive_active = False
    emotional_overdrive_timer = 0
    overdrive_flash_timer = 0
    overdrive_trails.clear()
    # 🆕 멘헤라걸 필살기 게이지 초기화 (스테이지 종료 시)
    global displayed_boss_gauge
    boss_special_gauge = 0
    displayed_boss_gauge = 0  # 표시 게이지도 초기화
    boss_special_ready = False
    boss_special_waiting = False
    boss_red_intensity = 0
    # 🆕 풍선 스킬 상태 초기화
    balloon_active = False
    balloon_timer = 0
    balloons.clear()
    balloon_used_this_round = False  # 다음 라운드에서 다시 사용 가능하도록 리셋
    # 🆕 보스 충돌 애니메이션 초기화
    boss_hit_animation_active = False
    boss_hit_animation_timer = 0
    # 🆕 대쉬 상태 완전 초기화 (게임 종료 시)
    global rolling_active, rolling_timer, rolling_direction, rolling_speed, rolling_stun_timer, rolling_dash_available_timer, rolling_cooldown, rolling_charges, rolling_charge_timer, rolling_consecutive_count
    rolling_active = False
    rolling_timer = 0
    rolling_direction = 0
    rolling_speed = 0
    rolling_stun_timer = 0
    rolling_dash_available_timer = 0
    rolling_cooldown = 0
    rolling_charges = 1  # 기본값으로 리셋
    rolling_charge_timer = 0
    rolling_consecutive_count = 0  # 🆕 연속 대쉬 카운터 초기화
    # 🆕 듀스 시스템 리셋 (게임 종료 시 듀스 모드 해제)
    reset_deuce_system()
    if won:
        reward = stage_medal_rewards.get(current_stage, 0)
        session_medal_earned += reward
        # 🏆 스테이지 클리어 기록
        record_stage_result(current_stage, cleared=True)
        show_fade_text(f"Stage {current_stage} 클리어!")
        SCREEN.fill(BLACK)
        pygame.display.flip()
        pygame.time.delay(300)
        # 🆕 뽑기 시작
        # 사용 가능한 아이템들 생성
        available_items = []
        # 패시브 아이템들 추가 (실제 아이콘) - 이미 획득한 것은 제외
        if not speedboots_obtained:
            available_items.append({"name": "speedboots", "color": (0, 255, 100), "type": "passive", "icon": speedboots_icon})
        if not speedgear_obtained:
            available_items.append({"name": "speedgear", "color": (255, 150, 0), "type": "passive", "icon": speedgear_icon})
        if not battery_obtained:
            available_items.append({"name": "battery", "color": (255, 255, 0), "type": "passive", "icon": battery_icon})
        if not revival_obtained and not revival_used:
            available_items.append({"name": "revival", "color": (255, 0, 255), "type": "passive", "icon": revival_icon})
        if not master_obtained:
            available_items.append({"name": "master", "color": (255, 215, 0), "type": "passive", "icon": master_icon})
        if not cooltime_obtained:
            available_items.append({"name": "cooltime", "color": (0, 255, 255), "type": "passive", "icon": cooltime_icon})
        if not chargebag_obtained:
            available_items.append({"name": "chargebag", "color": (100, 255, 100), "type": "passive", "icon": chargebag_icon})
        if not spikeboots_obtained:
            available_items.append({"name": "spikeboots", "color": (255, 100, 255), "type": "passive", "icon": spikeboots_icon})
        if not dashgear_obtained:
            available_items.append({"name": "dashgear", "color": (100, 100, 255), "type": "passive", "icon": dashgear_icon})
        if not bulkup_obtained:
            available_items.append({"name": "bulkup", "color": (255, 100, 100), "type": "passive", "icon": bulkup_icon})
        # 엑티브 아이템들 추가
        available_items.append({"name": "long_boost", "color": (255, 100, 100), "type": "active", "icon": long_boost_icon})
        available_items.append({"name": "gauge_charge", "color": (100, 255, 100), "type": "active", "icon": gauge_charge_icon})
        available_items.append({"name": "aipill", "color": (255, 255, 100), "type": "active", "icon": aipill_icon})
        available_items.append({"name": "wall", "color": (100, 100, 100), "type": "active", "icon": wall_icon})
        # 화염병 아이콘 추가
        try:
            molotov_icon = pygame.image.load("items/molotov.png").convert_alpha()
            molotov_icon = pygame.transform.scale(molotov_icon, (32, 32))
        except:
            molotov_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
            pygame.draw.circle(molotov_icon, (255, 100, 0), (16, 16), 12)
        available_items.append({"name": "molotov", "color": (255, 100, 0), "type": "active", "icon": molotov_icon})
        # 수류탄 아이콘 추가
        try:
            grenade_icon = pygame.image.load("items/grenade.png").convert_alpha()
            grenade_icon = pygame.transform.scale(grenade_icon, (32, 32))
        except:
            grenade_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
            pygame.draw.circle(grenade_icon, (80, 100, 80), (16, 16), 12)
        available_items.append({"name": "grenade", "color": (80, 100, 80), "type": "active", "icon": grenade_icon})
        # 조명탄 아이콘 추가
        try:
            flare_icon = pygame.image.load("items/flare.png").convert_alpha()
            flare_icon = pygame.transform.scale(flare_icon, (32, 32))
        except:
            flare_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
            pygame.draw.circle(flare_icon, (255, 255, 200), (16, 16), 12)
        available_items.append({"name": "flare", "color": (255, 255, 200), "type": "active", "icon": flare_icon})
        # 연막탄 아이콘 추가
        try:
            smoke_grenade_icon = pygame.image.load("items/smoke_grenade.png").convert_alpha()
            smoke_grenade_icon = pygame.transform.scale(smoke_grenade_icon, (32, 32))
        except:
            smoke_grenade_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
            pygame.draw.circle(smoke_grenade_icon, (150, 150, 150), (16, 16), 12)
        available_items.append({"name": "smoke_grenade", "color": (150, 150, 150), "type": "active", "icon": smoke_grenade_icon})
        # 레이저스코프 아이콘 추가
        try:
            predictor_icon = pygame.image.load("items/predictor.png").convert_alpha()
            predictor_icon = pygame.transform.scale(predictor_icon, (32, 32))
        except:
            predictor_icon = pygame.Surface((32, 32), pygame.SRCALPHA)
            pygame.draw.circle(predictor_icon, (100, 200, 255), (16, 16), 12)
        available_items.append({"name": "predictor", "color": (100, 200, 255), "type": "active", "icon": predictor_icon})
        # slot_add는 획득한 개수만큼 추가
        for i in range(items.slot_add_obtained):
            available_items.append({"name": "slot_add", "color": (255, 200, 100), "type": "passive", "icon": slot_add_icon})
        # 아이템이 없으면 기본 아이템 추가
        if not available_items:
            available_items = [{"name": "long_boost", "color": (100, 200, 255), "type": "active", "icon": long_boost_icon}]
        gacha.init_gacha(available_items)
        gacha.run_gacha(SCREEN, WIDTH, HEIGHT, get_item_name_korean, store_passive_item, store_active_item, get_item_description)
        show_victory_screen(stage_cleared=current_stage, reward=reward)
        current_stage += 1
    else:
        # 부활 아이템이 있고 아직 사용하지 않았다면 부활 기회 제공
        if revival_obtained and not revival_used:
            show_fade_text("부활 아이템이 발동됩니다!")
            SCREEN.fill(BLACK)
            pygame.display.flip()
            pygame.time.delay(1000)
            # 부활 아이템 사용
            revival_used = True
            items.revival_used = True  # items.py에서도 사용 상태 업데이트
            items.revival_obtained = False  # items.py에서도 제거
            revival_obtained = False  # 로컬에서도 제거
            # 패시브 아이템 리스트에서 revival 제거
            passive_item_list = [item for item in passive_item_list if item["name"] != "revival"]
            # 라운드 점수를 이전 상태로 되돌림 (부활)
            round_losses -= 1  # 패배 점수를 1 감소시켜 이전 라운드로 되돌림
            # 듀스 시스템 리셋 (부활 시 듀스 모드 해제)
            reset_deuce_system()
            # 라운드 리셋 (부활)
            reset_round()
            # 부활 후 게임 루프를 다시 시작하기 위해 main 함수를 재귀 호출
            main(current_stage)
            return  # 부활했으므로 게임 계속
        # 부활 아이템이 없거나 이미 사용했다면 일반 패배 처리
        earned = int(session_medal_earned * 0.5)
        medal_score += earned
        session_medal_earned = 0
        show_fade_text(f"패배... 획득 메달의 50%({earned})를 보상받았습니다.")
        SCREEN.fill(BLACK)
        pygame.display.flip()
        pygame.time.delay(1000)
        # 🏆 사망 시 실력 평가 표시
        show_death_evaluation()
        # 아이템 관련 전부 초기화
        items.reset_items()
        # 🆕 듀스 시스템 리셋 (게임 오버 시)
        reset_deuce_system()
        # 🆕 패시브 아이템 효과 초기화 (게임 오버 시)
        speedboots_obtained = False
        speedgear_obtained = False
        battery_obtained = False
        revival_obtained = False
        revival_used = False
        master_obtained = False
        cooltime_obtained = False
        chargebag_obtained = False  # 충전가방 아이템 제거
        spikeboots_obtained = False  # 스파이크부츠 아이템 제거
        dashgear_obtained = False  # 대쉬기어 아이템 제거
        bulkup_obtained = False  # 벌크업 아이템 제거
        dashholder_obtained = False  # 대쉬홀더 아이템 제거
        gravitybelt_obtained = False  # 무중력벨트 아이템 제거
        danger_sensor_obtained = False  # 위험감지센서 아이템 제거
        sensor_obtained = False  # 센서 아이템 제거
        items.speedboots_obtained = False
        items.speedgear_obtained = False
        items.battery_obtained = False
        items.revival_obtained = False
        items.revival_used = False
        items.master_obtained = False
        items.cooltime_obtained = False
        items.chargebag_obtained = False
        items.spikeboots_obtained = False
        items.dashgear_obtained = False
        items.bulkup_obtained = False
        items.dashholder_obtained = False
        items.gravitybelt_obtained = False
        items.sensor_obtained = False
        # 대쉬 토큰 수 및 시너지 효과 리셋 (대쉬홀더 없이는 기본 1개)
        rolling_charges = 1
        gravity_speed_synergy = False  # 시너지 효과 리셋
        # 대쉬 매니저 완전 리셋
        if dash is not None:
            dash.update_bonuses(False, False, False)  # 모든 아이템 비활성화
            dash.reset_to_base()  # 기본 상태로 리셋
        show_start_screen()
def show_new_boss_selection_screen():
    """새로운 보스 vs 보스 모드 선택 화면"""
    global selected_top_boss, selected_bottom_boss
    clock = pygame.time.Clock()
    # 선택 상태
    selection_step = 0  # 0: 상단 보스 선택, 1: 하단 보스 선택, 2: 완료
    top_selection = 0  # 0: 라이트닝 마스터, 1: 아이스 퀸
    bottom_selection = 0  # 0: 파이어 나이트, 1: 윈드 스피릿
    top_bosses = [
        {"name": "라이트닝 마스터", "element": "전기", "description": "전기충격, 초고속이동"},
        {"name": "아이스 퀸", "element": "얼음", "description": "얼음방벽, 방어전문"}
    ]
    bottom_bosses = [
        {"name": "파이어 나이트", "element": "화염", "description": "화염돌진, 균형형"},
        {"name": "윈드 스피릿", "element": "바람", "description": "바람폭발, 초고속"}
    ]
    while True:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                if selection_step == 0:  # 상단 보스 선택
                    if event.key == pygame.K_LEFT:
                        top_selection = (top_selection - 1) % len(top_bosses)
                    elif event.key == pygame.K_RIGHT:
                        top_selection = (top_selection + 1) % len(top_bosses)
                    elif event.key == pygame.K_SPACE or event.key == pygame.K_RETURN:
                        selected_top_boss = top_selection + 1
                        selection_step = 1
                elif selection_step == 1:  # 하단 보스 선택
                    if event.key == pygame.K_LEFT:
                        bottom_selection = (bottom_selection - 1) % len(bottom_bosses)
                    elif event.key == pygame.K_RIGHT:
                        bottom_selection = (bottom_selection + 1) % len(bottom_bosses)
                    elif event.key == pygame.K_SPACE or event.key == pygame.K_RETURN:
                        selected_bottom_boss = bottom_selection + 1
                        return
                    elif event.key == pygame.K_BACKSPACE:
                        selection_step = 0  # 뒤로 가기
                if event.key == pygame.K_ESCAPE:
                    return  # 선택 취소하고 돌아가기
        # 화면 그리기
        SCREEN.fill((15, 25, 35))
        # 제목
        try:
            font_title = pygame.font.Font("NanumSquareB.ttf", 48)
            font_subtitle = pygame.font.Font("NanumSquareB.ttf", 32)
            font_desc = pygame.font.Font("NanumSquareR.ttf", 20)
            font_hint = pygame.font.Font("NanumSquareR.ttf", 16)
        except:
            font_title = pygame.font.Font(None, 48)
            font_subtitle = pygame.font.Font(None, 32)
            font_desc = pygame.font.Font(None, 20)
            font_hint = pygame.font.Font(None, 16)
        # 메인 제목
        title_text = font_title.render("🆕 NEW BOSS BATTLE", True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(WIDTH//2, 80))
        SCREEN.blit(title_text, title_rect)
        if selection_step == 0:
            # 상단 보스 선택
            step_text = font_subtitle.render("1단계: 상단 보스 선택", True, (100, 200, 255))
            step_rect = step_text.get_rect(center=(WIDTH//2, 140))
            SCREEN.blit(step_text, step_rect)
            # 보스 선택지들
            for i, boss in enumerate(top_bosses):
                y = 200 + i * 80
                color = (255, 255, 100) if i == top_selection else (200, 200, 200)
                # 선택 표시
                if i == top_selection:
                    selector = font_subtitle.render("→", True, (255, 255, 100))
                    SCREEN.blit(selector, (WIDTH//2 - 200, y))
                # 보스 이름과 속성
                name_text = font_subtitle.render(f"{boss['name']} ({boss['element']})", True, color)
                name_rect = name_text.get_rect(center=(WIDTH//2, y))
                SCREEN.blit(name_text, name_rect)
                # 설명
                desc_text = font_desc.render(boss['description'], True, (150, 150, 150))
                desc_rect = desc_text.get_rect(center=(WIDTH//2, y + 25))
                SCREEN.blit(desc_text, desc_rect)
            # 힌트
            hint_text = font_hint.render("← → 키로 선택, 스페이스/엔터로 확인", True, (120, 120, 120))
            hint_rect = hint_text.get_rect(center=(WIDTH//2, HEIGHT - 50))
            SCREEN.blit(hint_text, hint_rect)
        elif selection_step == 1:
            # 하단 보스 선택
            step_text = font_subtitle.render("2단계: 하단 보스 선택", True, (255, 100, 100))
            step_rect = step_text.get_rect(center=(WIDTH//2, 140))
            SCREEN.blit(step_text, step_rect)
            # 선택된 상단 보스 표시
            top_boss_text = font_desc.render(f"상단: {top_bosses[top_selection]['name']}", True, (100, 200, 255))
            top_boss_rect = top_boss_text.get_rect(center=(WIDTH//2, 170))
            SCREEN.blit(top_boss_text, top_boss_rect)
            # 보스 선택지들
            for i, boss in enumerate(bottom_bosses):
                y = 220 + i * 80
                color = (255, 255, 100) if i == bottom_selection else (200, 200, 200)
                # 선택 표시
                if i == bottom_selection:
                    selector = font_subtitle.render("→", True, (255, 255, 100))
                    SCREEN.blit(selector, (WIDTH//2 - 200, y))
                # 보스 이름과 속성
                name_text = font_subtitle.render(f"{boss['name']} ({boss['element']})", True, color)
                name_rect = name_text.get_rect(center=(WIDTH//2, y))
                SCREEN.blit(name_text, name_rect)
                # 설명
                desc_text = font_desc.render(boss['description'], True, (150, 150, 150))
                desc_rect = desc_text.get_rect(center=(WIDTH//2, y + 25))
                SCREEN.blit(desc_text, desc_rect)
            # 힌트
            hint_text = font_hint.render("← → 키로 선택, 백스페이스로 뒤로, 스페이스/엔터로 확인", True, (120, 120, 120))
            hint_rect = hint_text.get_rect(center=(WIDTH//2, HEIGHT - 50))
            SCREEN.blit(hint_text, hint_rect)
        pygame.display.flip()
        clock.tick(60)
def main(stage_num, new_boss_mode=False):
    # 🏆 실시간 평가 시스템으로 변경됨
    # 관리자 단축키 변수 초기화
    global nine_just_pressed, last_nine_state
    nine_just_pressed = False
    last_nine_state = False
    # 게임 상태 & 스테이지 설정
    global current_stage, round_wins, round_losses, new_boss_mode_active, FIELD_GREEN, CURRENT_BG, BOSS_COLOR, SCREEN
    # 보스 AI 설정
    global BOSS_ACCELERATION, BOSS_DECELERATION, BOSS_MAX_SPEED, BOSS_INSTANT_STOP_DECELERATION, BOSS_ACCELERATION_DEFAULT, BOSS_DECELERATION_DEFAULT, BOSS_MAX_SPEED_DEFAULT, BOSS_INSTANT_STOP_DECELERATION_DEFAULT
    # 게임 진행 & 타이밍
    global is_waiting_for_serve, last_item_spawn_time, next_item_spawn_delay, boss_fail_timer, session_medal_earned, medal_score
    # 아이템 시스템
    global selected_item_index, last_item_use_time, master_obtained, cooltime_obtained
    # 보스 스킬들
    global whip_active, whip_timer, whip_sound
    # 충돌 애니메이션
    global hit_animation_active, hit_animation_timer
    # 일시정지 시스템
    global game_paused
    # 파워스매싱 정지 시간 관리
    global power_smashing_freeze_start_time, power_smashing_freeze_active, power_smashing_freeze_duration, power_smashing_parabola_active, power_smashing_start_time
    # 대쉬 및 아이템 관련 전역 변수
    global dashholder_obtained, rolling_charge_timer, rolling_charges
    # 스테이지 1 벽 충돌 테두리 깜빡임 효과
    global border_flash_active, border_flash_timer, border_flash_duration, border_flash_color, border_flash_thickness
    # 스테이지 2 정글 테두리 효과
    global stage2_border_active, stage2_border_timer, stage2_border_flash_timer, stage2_border_flash_duration, stage2_vines, stage2_leaves
    boss_fail_timer = 0  # 보스 실수 타이머 초기화
    current_stage = stage_num
    round_wins = 0
    round_losses = 0
    # 💪 체력형 보스 스테이지에서는 패배 조건을 5점으로 설정
    global win_goal, boss_current_health, boss_displayed_health, boss_damage_preview_health
    if current_stage in boss_health_stages:
        win_goal = 5  # 체력형 보스는 5점에서 패배
        # 체력형 보스 체력 초기화
        boss_current_health = boss_max_health  # 15
        boss_displayed_health = boss_max_health  # 15
        boss_damage_preview_health = boss_max_health  # 15
    else:
        win_goal = 3  # 일반 스테이지는 3점에서 패배
    # 🧠 딥러닝 AI 시스템 초기화
    initialize_enhanced_ai()
    # 🏆 플레이어 실력 분석 시스템 초기화
    initialize_player_analyzer()
    # 새로운 보스 배틀 모드 설정
    new_boss_mode_active = new_boss_mode
    if new_boss_mode_active:
        # 새로운 보스 선택 화면 표시
        show_new_boss_selection_screen()
        top_names = ["라이트닝 마스터", "아이스 퀸"]
        bottom_names = ["파이어 나이트", "윈드 스피릿"]
        top_name = top_names[selected_top_boss - 1]
        bottom_name = bottom_names[selected_bottom_boss - 1]
        print(f"🆕 NEW BOSS BATTLE: {top_name} vs {bottom_name}")
    # 듀스 시스템 초기화
    reset_deuce_system()
    # 🏆 통합 보스 설정: 스테이지별 + 리그별 완전 연계
    config = get_final_boss_config(stage_num, ai_mode)
    BOSS_ACCELERATION = config["accel"]
    BOSS_DECELERATION = config["decel"]
    BOSS_MAX_SPEED = config["max_speed"]
    BOSS_INSTANT_STOP_DECELERATION = config["instant_stop"]
    BOSS_ACCELERATION_DEFAULT = config["accel"]
    BOSS_DECELERATION_DEFAULT = config["decel"]
    BOSS_MAX_SPEED_DEFAULT = config["max_speed"]
    BOSS_INSTANT_STOP_DECELERATION_DEFAULT = config["instant_stop"]
    # 스테이지별 배경, 보스 컬러
    if stage_num == 1:
        CURRENT_BG = STAGE1_BG
        BOSS_COLOR = WHITE
    elif stage_num == 2:
        CURRENT_BG = STAGE2_BG
        BOSS_COLOR = (100, 255, 100)
    elif stage_num == 3:
        CURRENT_BG = STAGE3_BG
        BOSS_COLOR = (255, 255, 0)
    elif stage_num == 4:
        CURRENT_BG = STAGE4_BG
        BOSS_COLOR = (255, 255, 255)
    elif stage_num == 5:  # ✅ Stage 5 추가
        CURRENT_BG = STAGE5_BG
        BOSS_COLOR = (255, 80, 0)   # 홍련색
    elif stage_num == 6:  # ✅ Stage 6 추가 (항공모함)
        CURRENT_BG = STAGE6_BG
        BOSS_COLOR = (150, 200, 255)  # 금속/은색
    reset_round()
    # 아이템 첫 스폰 시간 설정 (첫스폰))
    last_item_spawn_time = pygame.time.get_ticks()
    next_item_spawn_delay = random.randint(10000, 20000)  # 첫 스폰 빠르게
    # selected_item_index 초기화 (active_item_slot이 비어있으면 0으로 설정)
    if not active_item_slot:
        selected_item_index = 0
    else:
        selected_item_index = min(selected_item_index, len(active_item_slot) - 1)
    running = True
    while running:
        # 프로파일러 프레임 시작
        if profiler:
            profiler.begin_frame()
        clock.tick(FPS)
        # 프로파일러 입력 처리 섹션
        if profiler:
            profiler.start_section("Input")
        # 키 입력 처리
        keys = pygame.key.get_pressed()
        # 7번키로 프로파일러 표시 토글
        if keys[pygame.K_7] and not getattr(main, 'key7_pressed', False):
            if profiler:
                profiler.toggle_visibility()
                print(f"프로파일러 표시: {'ON' if profiler.visible else 'OFF'}")
        main.key7_pressed = keys[pygame.K_7]
        # 🎯 퍼펙트 타이밍 시스템: 스페이스바 + 방향키 프레임 단위 입력 감지
        global space_just_pressed, last_space_state, perfect_timing_active, perfect_timing_frame_count, perfect_direction, left_just_pressed, last_left_state, right_just_pressed, last_right_state
        global left_press_frame, right_press_frame, space_press_frame, frame_counter, perfect_timing_cooldown, perfect_timing_cooldown_frames, perfect_timing_input_used
        global drive_global_cooldown, drive_global_cooldown_frames, last_space_press_time, special_ready, special_active, special_gauge  # 🚀 파워스매싱 관련 변수들
        global power_smashing_direction, power_smashing_original_speed, ball_vel  # 🚀 파워스매싱 관련 변수
        # 프레임 카운터 증가
        frame_counter += 1
        # 🔧 대쉬 매니저 업데이트 (매 프레임)
        if dash is not None:
            # 아이템 보너스 동기화 (매 프레임)
            dash.update_bonuses(dashholder_obtained, dashgear_obtained, spikeboots_obtained)
            dash.update()
            # 레거시 시스템과 동기화
            dash_tokens, dash_timer, dash_consecutive, dash_max = dash.get_legacy_sync_data()
            if rolling_charges != dash_tokens or rolling_charge_timer != dash_timer:
                rolling_charges = dash_tokens
                rolling_charge_timer = dash_timer
                rolling_consecutive_count = dash_consecutive
        # 관리자용 9키 단축키 (3-0 승리)
        global boss_score, player_score
        current_nine_state = keys[pygame.K_9]
        nine_just_pressed = current_nine_state and not last_nine_state
        if nine_just_pressed:
            print("🎮 관리자 단축키: 즉시 3-0 승리!")
            boss_score = 0
            player_score = 3
            # 승리 화면으로 이동
            show_result(True)
            return
        last_nine_state = current_nine_state
        # 스페이스바 입력 감지 (감전 상태일 때는 무시)
        if not player_stunned:
            current_space_state = keys[pygame.K_SPACE]
            space_just_pressed = current_space_state and not last_space_state
            if space_just_pressed:
                space_press_frame = frame_counter
            last_space_state = current_space_state
        else:
            space_just_pressed = False
            current_space_state = False
            last_space_state = False
        # 🆕 방향키 입력 감지 (감전 상태일 때는 무시)
        if not player_stunned:
            current_left_state = keys[pygame.K_LEFT]
            left_just_pressed = current_left_state and not last_left_state
            if left_just_pressed:
                left_press_frame = frame_counter
            last_left_state = current_left_state
            current_right_state = keys[pygame.K_RIGHT]
            right_just_pressed = current_right_state and not last_right_state
            if right_just_pressed:
                right_press_frame = frame_counter
            last_right_state = current_right_state
        else:
            # 감전 상태일 때는 모든 입력을 False로
            left_just_pressed = False
            right_just_pressed = False
            last_left_state = False
            last_right_state = False
        # 🎯 퍼펙트 타이밍 쿨다운 관리 (연타 방지)
        if perfect_timing_cooldown > 0:
            perfect_timing_cooldown -= 1
        # 🆕 드라이브 전역 쿨다운 관리 (강력한 연타 방지)
        if drive_global_cooldown > 0:
            drive_global_cooldown -= 1
        # 🆕 스페이스바 연타 감지 (너무 빠른 입력 차단)
        current_time = pygame.time.get_ticks()
        min_space_interval = 200  # 최소 200ms (0.2초) 간격
        if space_just_pressed:
            if current_time - last_space_press_time < min_space_interval:
                space_just_pressed = False  # 너무 빠른 입력은 무시
                print(f"🚫 스페이스바 입력이 너무 빠릅니다! (간격: {current_time - last_space_press_time}ms)")
            else:
                last_space_press_time = current_time
        # 🎯 퍼펙트 타이밍 윈도우 활성화 체크 (매 프레임 체크)
        # 올바른 거리 계산: 패들까지의 실제 거리
        ball_to_paddle_distance = PLAYER.top - BALL.centery  # 양수 = 공이 패들 위쪽에 있음
        # 🚀 개선된 퍼펙트 타이밍 윈도우: 실제 충돌 가능 범위와 일치시키기
        # 공이 패들과 실제로 충돌할 수 있는 범위 내에서만 활성화
        # 드라이브 선입력 방지: 거리를 더 짧게 설정
        ball_will_hit_paddle = (
            ball_to_paddle_distance <= 20 and  # 더 정확한 거리 (30 → 20) - 선입력 방지
            ball_to_paddle_distance > -10 and  # 약간의 여유 (0 → -10)
            ball_vel[1] > 0 and
            # 🎯 추가 조건: 공의 X좌표가 패들 범위 내 또는 근처에 있는지 확인
            abs(BALL.centerx - PLAYER.centerx) <= (PADDLE_WIDTH / 2 + BALL_RADIUS + 15)  # 패들 범위 + 약간의 여유 (20 → 15)
        )
        if ball_will_hit_paddle:
            if not perfect_timing_active:
                perfect_timing_active = True
                perfect_timing_frame_count = 0
                perfect_timing_input_used = False  # 🆕 새로운 윈도우 시작 시 플래그 초기화
                x_distance = abs(BALL.centerx - PLAYER.centerx)
                print(f"🎯 퍼펙트 타이밍 윈도우 활성화! (Y거리: {ball_to_paddle_distance:.1f}, X거리: {x_distance:.1f})")
        # 퍼펙트 타이밍 윈도우 관리
        if perfect_timing_active:
            perfect_timing_frame_count += 1
            # 🆕 퍼펙트 타이밍 입력 체크 (방향키 + 스페이스 동시 입력 필요)
            # 🚀 드라이브와 파워스매싱을 동일한 타이밍 윈도우에서 처리
            if (perfect_timing_frame_count <= perfect_timing_window and 
                perfect_timing_cooldown == 0 and not perfect_timing_input_used and 
                drive_global_cooldown == 0):
                # 🆕 개선된 동시 입력 감지 (2프레임 허용 범위) - 선입력 방지
                max_frame_gap = 2  # 최대 2프레임(0.033초) 차이까지 동시 입력으로 인정 (3 → 2)
                max_input_age = 8  # 최대 8프레임(약 0.13초) 전까지의 입력만 유효
                                    # 🚀 파워스매싱/고스트샷 발동: 게이지가 준비되었고 스페이스를 홀드하고 있다면
                if special_gauge >= 350 and keys[pygame.K_SPACE]:  # 파워스매시 발동 조건: 350 이상
                    # 먼저 고스트샷 조건 체크
                    global mega_smashing_active, mega_smashing_bonus_applied, recent_dash_time, mega_smashing_start_time, power_smashing_parabola_active  # global 선언을 먼저
                    current_time = pygame.time.get_ticks()
                    # 고스트샷 조건:
                    # 1. 대쉬 후 1초 이내
                    # 2. 스페이스바를 대쉬 후에 눌렀을 것 (대쉬 전부터 홀드한 것 제외)
                    mega_smashing_window = 1000  # 1초
                    if (recent_dash_time > 0 and 
                        (current_time - recent_dash_time) <= mega_smashing_window and
                        last_space_press_time > recent_dash_time):  # 스페이스바가 대쉬 후에 눌렸을 때만
                        mega_smashing_active = True
                        mega_smashing_start_time = pygame.time.get_ticks()  # 고스트샷 시작 시간 기록
                        mega_smashing_boss_defense_count = 0  # 보스 방어 카운터 초기화
                        power_smashing_parabola_active = False  # 고스트샷은 파워스매싱 포물선 사용 안함
                        # 🚀 고스트샷 발동 시 원래 위치 저장 후 300픽셀 위로 순간이동
                        original_y = BALL.centery  # 원래 위치 저장
                        BALL.centery = max(BALL_RADIUS, BALL.centery - 300)  # 화면 밖으로 나가지 않도록 제한
                        # 원래 위치 저장 (handle_mega_smashing_trajectory에서 사용)
                        handle_mega_smashing_trajectory.original_y = original_y
                        handle_mega_smashing_trajectory.return_to_original = True
                        # 🔧 고스트샷 발동 시 토큰 충전 타이머 확인 및 설정
                        base_charges = 1
                        holder_bonus = 1 if dashholder_obtained else 0
                        amplification_bonus = academy.get_skill_bonus("dash_amplification")
                        max_charges = int(base_charges + holder_bonus + amplification_bonus)
                        # 토큰이 소진된 상태면 무조건 충전 타이머 설정
                        print(f"[DEBUG] 고스트샷 발동 전 상태 - 토큰: {rolling_charges}/{max_charges}, 타이머: {rolling_charge_timer}")
                        if rolling_charges < max_charges:
                            lightweight_bonus = academy.get_skill_bonus("dash_lightweight")
                            charge_time_reduction = lightweight_bonus
                            base_charge_time = 90  # 1.5초
                            rolling_charge_timer = int(base_charge_time * (1 - charge_time_reduction))
                            print(f"💥 고스트샷 발동 시 토큰 충전 시작 (타이머: {rolling_charge_timer})")
                        else:
                            print(f"[DEBUG] 고스트샷 발동 - 토큰 이미 최대: {rolling_charges}/{max_charges}")
                        # 고스트샷 게이지 보너스
                        if not mega_smashing_bonus_applied:
                            special_gauge = min(special_gauge + 50, 1000)
                            mega_smashing_bonus_applied = True
                        print(f"💥 고스트샷 발동! (대쉬→스페이스 콤보) +50 게이지 보너스")
                        print(f"   대쉬 시간: {recent_dash_time}, 스페이스 시간: {last_space_press_time}, 간격: {last_space_press_time - recent_dash_time}ms")
                        show_fade_text("고스트샷!")
                    # else 제거 - 고스트샷이 이미 활성화되어 있을 수 있으므로
                    # 파워스매싱 방향 설정 (고스트샷이든 일반 파워스매싱이든 공통)
                    global power_smashing_direction, power_smashing_start_time, power_smashing_arc_strength, power_smashing_freeze_start_time, power_smashing_freeze_active
                    if keys[pygame.K_LEFT]:
                        power_smashing_direction = -1  # 왼쪽
                        # 뚜렷한 곡선 효과 적용
                        base_strength = -2.8  # 기본 강도 증가
                        random_variation = random.uniform(-0.4, 0.4)  # 랜덤 변화량
                        power_smashing_arc_strength = base_strength + random_variation  # 왼쪽 방향으로 뚜렷한 곡선
                    elif keys[pygame.K_RIGHT]:
                        power_smashing_direction = 1   # 오른쪽
                        # 뚜렷한 곡선 효과 적용
                        base_strength = 2.8  # 기본 강도 증가
                        random_variation = random.uniform(-0.4, 0.4)  # 랜덤 변화량
                        power_smashing_arc_strength = base_strength + random_variation  # 오른쪽 방향으로 뚜렷한 곡선
                    else:
                        power_smashing_direction = 0   # 직선
                        # 직선이므로 포물선 효과 없음
                        power_smashing_arc_strength = 0.0
                    # 고스트샷이 아닐 때만 special_active 설정 (고스트샷은 게이지 충전 가능)
                    if not mega_smashing_active:
                        special_active = True
                    special_ready = False
                    special_gauge = max(0, special_gauge - 350)
                    # 고스트샷 보너스: +50 게이지
                    if mega_smashing_active:
                        special_gauge += 50
                        current_max = get_max_gauge()
                        if special_gauge > current_max:
                            special_gauge = current_max  # 파워스매시 게이지 소모: 350
                    # 🎵 파워스매싱 발동 효과음 재생
                    SOUND_POWER_SMASH.play()
                    print("🎵 파워스매싱 발동 효과음 재생!")
                    # 🏆 파워스매싱 성공 기록
                    record_skill_usage(success=True)
                    # 🔧 고스트샷일 때는 파워스매싱 정지 시간 사용하지 않음
                    if not mega_smashing_active:
                        # 파워스매싱 정지 시간 시작
                        power_smashing_freeze_start_time = pygame.time.get_ticks()
                        power_smashing_freeze_active = True
                        print(f"🔧 파워스매싱 정지 시간 시작! (1초)")
                    else:
                        # 고스트샷은 정지 없이 바로 시작
                        power_smashing_freeze_active = False
                        power_smashing_parabola_active = False  # 고스트샷은 파워스매싱 포물선 사용 안함
                        power_smashing_start_time = pygame.time.get_ticks()  # 고스트샷 시작 시간 설정
                        print(f"🐉 고스트샷은 정지 없이 바로 시작!")
                    # 🔧 파워스매싱 발동 시 강제 충돌 처리 (범위 차이 문제 해결)
                    if not BALL.colliderect(PLAYER) and ball_to_paddle_distance <= 30 and ball_vel[1] > 0:
                        # 공을 패들 근처로 강제 이동시켜 충돌 발생시키기
                        BALL.centery = PLAYER.top - BALL_RADIUS
                        print(f"🔧 파워스매싱 강제 충돌 처리! 공 위치 조정: Y={BALL.centery}")
                        # 강제 충돌 처리 실행
                        drive_activated = calculate_bounce(PLAYER)
                        # 기존 SOUND_PADDLE.play() 제거 - 파워스매싱 전용 효과음 사용
                        # 메가드라이브일 때는 공을 위로 보내도록 y 속도를 음수로 설정
                        if mega_smashing_active:
                            ball_vel[1] = -abs(ball_vel[1])  # 공을 위로(보스 방향으로) 보냄
                            print(f"💥 메가드라이브 - 공 방향 보스쪽으로 변경: Y속도={ball_vel[1]}")
                        # 타격 이펙트 생성
                        create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=True)
                        # 충돌 애니메이션
                        hit_animation_active = True
                        hit_animation_timer = HIT_ANIMATION_DURATION
                    perfect_timing_cooldown = perfect_timing_cooldown_frames  # 쿨다운 시작
                    drive_global_cooldown = drive_global_cooldown_frames      # 🆕 전역 쿨다운 시작
                    perfect_timing_input_used = True  # 🆕 이 윈도우에서 입력 사용됨 표시
                    # 🚀 파워스매싱 - 속도 대폭 증가
                    current_speed = math.hypot(ball_vel[0], ball_vel[1])
                    power_smashing_original_speed = current_speed  # 🎯 원래 속도 저장 (보스 반격 시 감속용)
                    # 고스트샷은 초기에 느리게 시작 (용의 움직임을 위해)
                    if mega_smashing_active:
                        # 고스트샷은 천천히 시작
                        new_speed = BALL_BASE_SPEED * 0.5  # 기본 속도의 50%로 시작
                        actual_boost = new_speed - current_speed  # 고스트샷도 actual_boost 계산
                    else:
                        # 파워스매싱은 기존대로 빠르게
                        min_boost = BALL_BASE_SPEED * 1.2  # 최소 증가량
                        actual_boost = max(current_speed * 0.8, min_boost)  # 80% 증가 또는 최소값
                        new_speed = current_speed + actual_boost
                    # 속도 비율 적용으로 방향 유지하면서 속도 증가
                    if current_speed > 0:
                        speed_ratio = new_speed / current_speed
                        ball_vel[0] *= speed_ratio
                        ball_vel[1] *= speed_ratio
                    else:
                        # 정지 상태에서는 기본 속도로 설정
                        ball_vel[0] = BALL_BASE_SPEED * 0.8
                        ball_vel[1] = BALL_BASE_SPEED * 0.8
                    # 파워스매싱 방향에 따른 X축 속도 조정 (고스트샷도 동일하게 처리)
                    if power_smashing_direction == -1:  # 왼쪽 파워스매싱
                        ball_vel[0] = -abs(ball_vel[0]) * 1.3  # 왼쪽으로 강하게
                    elif power_smashing_direction == 1:  # 오른쪽 파워스매싱
                        ball_vel[0] = abs(ball_vel[0]) * 1.3  # 오른쪽으로 강하게
                    else:  # 직선 파워스매싱
                        ball_vel[0] *= 1.1  # X축 약간 부스트
                        ball_vel[1] *= 1.1  # Y축 추가 10% 부스트
                    # 고스트샷이 아닐 때만 POWER SMASHING 표시
                    if not mega_smashing_active:
                        show_fade_text("POWER SMASHING")
                    # 💫 이펙트 초기화 - 고스트샷일 때는 아무 이펙트도 생성하지 않음
                    if not mega_smashing_active:
                        # 파워스매싱일 때만 이펙트 생성
                        global power_smashing_trails, power_smashing_particles
                        power_smashing_trails.clear()
                        power_smashing_particles.clear()
                        # 파워스매싱 파티클 생성
                        for i in range(20):
                            angle = (i / 20) * 2 * math.pi
                            speed = random.uniform(4, 6)
                            power_smashing_particles.append({
                                'x': BALL.centerx,
                                'y': BALL.centery,
                                'vx': math.cos(angle) * speed,
                                'vy': math.sin(angle) * speed,
                                'life': 40,
                                'color': (150, 200, 255),
                                'type': 'energy'
                            })
                        # 전기 스파크
                        for _ in range(15):
                            angle = random.uniform(0, 2 * math.pi)
                            speed = random.uniform(5, 10)
                            power_smashing_particles.append({
                                'x': BALL.centerx,
                                'y': BALL.centery,
                                'vx': math.cos(angle) * speed,
                                'vy': math.sin(angle) * speed,
                                'life': 30,
                                'color': (200, 230, 255),
                                'type': 'spark'
                            })
                    # 홀드 방식이므로 프레임 초기화 불필요
                # 왼쪽 방향키 + 스페이스키 동시 입력 (드라이브 - 파워스매싱이 준비되지 않은 경우)
                # 추가 조건: 키 입력이 최근(8프레임 이내)에 이루어졌어야 함
                elif (left_press_frame >= 0 and space_press_frame >= 0 and 
                    abs(left_press_frame - space_press_frame) <= max_frame_gap and
                    (frame_counter - left_press_frame) <= max_input_age and  # 왼쪽 키가 최근에 눌렸는지
                    (frame_counter - space_press_frame) <= max_input_age):   # 스페이스 키가 최근에 눌렸는지
                    perfect_direction = -1  # 왼쪽 드라이브
                    perfect_timing_cooldown = perfect_timing_cooldown_frames  # 쿨다운 시작
                    drive_global_cooldown = drive_global_cooldown_frames      # 🆕 전역 쿨다운 시작
                    perfect_timing_input_used = True  # 🆕 이 윈도우에서 입력 사용됨 표시
                    frame_gap = abs(left_press_frame - space_press_frame)
                    input_age = max(frame_counter - left_press_frame, frame_counter - space_press_frame)
                    print(f"🎯 왼쪽 드라이브! (←+스페이스 동시 입력 성공, 프레임 차이: {frame_gap}, 입력 나이: {input_age})")
                    # 사용된 프레임 초기화
                    left_press_frame = -1
                    space_press_frame = -1
                # 오른쪽 방향키 + 스페이스키 동시 입력 (드라이브 - 파워스매싱이 준비되지 않은 경우)
                elif (right_press_frame >= 0 and space_press_frame >= 0 and 
                      abs(right_press_frame - space_press_frame) <= max_frame_gap and
                      (frame_counter - right_press_frame) <= max_input_age and  # 오른쪽 키가 최근에 눌렸는지
                      (frame_counter - space_press_frame) <= max_input_age):    # 스페이스 키가 최근에 눌렸는지
                    perfect_direction = 1   # 오른쪽 드라이브
                    perfect_timing_cooldown = perfect_timing_cooldown_frames  # 쿨다운 시작
                    drive_global_cooldown = drive_global_cooldown_frames      # 🆕 전역 쿨다운 시작
                    perfect_timing_input_used = True  # 🆕 이 윈도우에서 입력 사용됨 표시
                    frame_gap = abs(right_press_frame - space_press_frame)
                    input_age = max(frame_counter - right_press_frame, frame_counter - space_press_frame)
                    print(f"🎯 오른쪽 드라이브! (→+스페이스 동시 입력 성공, 프레임 차이: {frame_gap}, 입력 나이: {input_age})")
                    # 사용된 프레임 초기화
                    right_press_frame = -1
                    space_press_frame = -1
                # 🚫 스페이스바만 누르거나 방향키만 누른 경우
                elif space_just_pressed or left_just_pressed or right_just_pressed:
                    perfect_timing_input_used = True  # 입력은 사용됨으로 표시 (연타 방지)
                    print("🚫 드라이브 실패! 방향키(←/→)와 스페이스바를 동시에 눌러주세요!")
                    # 🏆 스킬 실패 기록
                    record_skill_usage(success=False)
            # 🚀 파워스매싱은 이제 동일한 타이밍 윈도우에서 우선순위로 처리됨
            elif space_just_pressed and drive_global_cooldown > 0:
                # 전역 쿨다운 중일 때 스페이스바를 누른 경우 (가장 우선적으로 체크)
                print(f"🚫 드라이브 전역 쿨다운 중! ({drive_global_cooldown} 프레임 남음) - 연타 차단!")
            elif space_just_pressed and perfect_timing_input_used:
                # 이미 이 윈도우에서 입력을 사용한 경우
                print("🎯 이미 이 퍼펙트 타이밍 윈도우에서 입력을 사용했습니다! (연타 방지)")
            elif space_just_pressed and perfect_timing_cooldown > 0:
                # 쿨다운 중일 때 스페이스바를 누른 경우
                print(f"🎯 퍼펙트 타이밍 쿨다운 중! ({perfect_timing_cooldown} 프레임 남음)")
            # 윈도우 시간 초과 시 리셋
            if perfect_timing_frame_count > perfect_timing_window:
                perfect_timing_active = False
                perfect_timing_frame_count = 0
                perfect_direction = None
                perfect_timing_input_used = False  # 🆕 플래그 리셋
                # 오래된 키 입력 기록 초기화 (선입력 방지)
                left_press_frame = -1
                right_press_frame = -1
                space_press_frame = -1
                print("🎯 퍼펙트 타이밍 윈도우 만료")
            # 🚀 개선된 윈도우 비활성화 조건: X축 범위도 체크
            ball_x_out_of_range = abs(BALL.centerx - PLAYER.centerx) > (PADDLE_WIDTH / 2 + BALL_RADIUS + 30)
            if (ball_to_paddle_distance > 100 or 
                ball_vel[1] <= 0 or 
                ball_to_paddle_distance < 0 or 
                ball_x_out_of_range):  # 🎯 X축 범위 벗어남도 체크
                perfect_timing_active = False
                perfect_timing_frame_count = 0
                if ball_x_out_of_range:
                    x_distance = abs(BALL.centerx - PLAYER.centerx)
                    print(f"🎯 퍼펙트 타이밍 윈도우 비활성화: 공이 패들 범위를 벗어남 (X거리: {x_distance:.1f})")
                perfect_direction = None
                perfect_timing_input_used = False  # 🆕 플래그 리셋
                # 오래된 키 입력 기록 초기화 (선입력 방지)
                left_press_frame = -1
                right_press_frame = -1
                space_press_frame = -1
                print(f"🎯 퍼펙트 타이밍 윈도우 비활성화 (거리: {ball_to_paddle_distance:.1f}, vel_y: {ball_vel[1]:.1f})")
                # 나쁜 타이밍 감지 - 기회를 놓쳤거나 부정확한 타이밍
                if ball_to_paddle_distance > 50 and abs(ball_vel[1]) > 8:  # 거리가 멀고 빠른 공 놓침
                    record_poor_timing_hit()
                elif perfect_timing_input_used and ball_to_paddle_distance > 30:  # 입력했지만 거리가 멀음
                    record_missed_opportunity()
        # 마우스 커서 설정 (비활성화됨)
        # if input_manager.get_control_mode() == "마우스":
        #     pygame.mouse.set_visible(False)  # 게임 중에는 마우스 커서 숨김
        # else:
        pygame.mouse.set_visible(True)   # 키보드 모드로 고정
        if profiler:
            profiler.end_section("Input")
            profiler.start_section("Events")
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            # 키보드 이벤트 처리
            if event.type == pygame.KEYDOWN:
                # 🎯 일시정지 토글 (P키)
                if event.key == pygame.K_p:
                    global game_paused
                    game_paused = not game_paused
                    print(f"🎯 게임 일시정지 토글: {'ON' if game_paused else 'OFF'}")
                    continue  # 일시정지 토글 후 다른 키 처리 건너뛰기
                # 🧠 AI 모드 전환 (N키)
                elif event.key == pygame.K_n:
                    toggle_ai_mode()
                # I키 기능 제거: ESC 메뉴의 '정보'에서 확인 가능
                # elif event.key == pygame.K_i:
                #     # 플레이어 스킬 표시 토글
                #     global skill_display_enabled
                #     skill_display_enabled = not skill_display_enabled
                #     print(f"🏆 플레이어 스킬 표시: {'ON' if skill_display_enabled else 'OFF'}")
                #     continue
            # 마우스 이벤트 처리 (비활성화됨)
            # if input_manager.get_control_mode() == "마우스":
            #     # 마우스 이벤트는 input_manager에서 처리
            #     input_manager.handle_mouse_event(event)
            #     # 마우스 휠로 아이템 선택 (조작 모드가 마우스일 때)
            #     if event.type == pygame.MOUSEWHEEL and input_manager.get_control_mode() == "마우스" and active_item_slot:
            #         if event.y > 0:  # 휠 위로
            #             selected_item_index = (selected_item_index - 1) % len(active_item_slot)
            #         elif event.y < 0:  # 휠 아래로
            #             selected_item_index = (selected_item_index + 1) % len(active_item_slot)
            # ESC 키로 일시정지 메뉴
            if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                result = show_pause_menu()
                if result == "surrender":
                    # 기권 처리 - 먼저 평가 결과 표시
                    try:
                        if player_analyzer:
                            show_death_evaluation()  # 기권 시에도 평가 결과 표시
                    except:
                        pass  # 평가 실패해도 계속 진행
                    # 기권 처리
                    earned = int(session_medal_earned * 0.5)
                    medal_score += earned
                    session_medal_earned = 0
                    # 아이템 관련 전부 초기화
                    items.reset_items()
                    # 듀스 시스템 리셋 (기권 시)
                    reset_deuce_system()
                    # 패시브 아이템 효과 초기화
                    speedboots_obtained = False
                    speedgear_obtained = False
                    battery_obtained = False
                    revival_obtained = False
                    revival_used = False
                    master_obtained = False
                    cooltime_obtained = False
                    chargebag_obtained = False
                    spikeboots_obtained = False
                    dashgear_obtained = False
                    bulkup_obtained = False
                    dashholder_obtained = False
                    gravitybelt_obtained = False
                    danger_sensor_obtained = False
                    sensor_obtained = False
                    items.speedboots_obtained = False
                    items.speedgear_obtained = False
                    items.battery_obtained = False
                    items.revival_obtained = False
                    items.revival_used = False
                    items.master_obtained = False
                    items.cooltime_obtained = False
                    items.chargebag_obtained = False
                    items.spikeboots_obtained = False
                    items.dashgear_obtained = False
                    items.bulkup_obtained = False
                    items.dashholder_obtained = False
                    items.gravitybelt_obtained = False
                    items.sensor_obtained = False
                    # 대쉬 토큰 수 및 시너지 효과 리셋 (대쉬홀더 없이는 기본 1개)
                    rolling_charges = 1
                    gravity_speed_synergy = False  # 시너지 효과 리셋
                    # 대쉬 매니저 완전 리셋
                    if dash is not None:
                        dash.update_bonuses(False, False, False)  # 모든 아이템 비활성화
                        dash.reset_to_base()  # 기본 상태로 리셋
                    return "main_menu"  # 메인 메뉴로 돌아감
            # Tab 키로 정보창 패시브 탭으로 이동
            if event.type == pygame.KEYDOWN and event.key == pygame.K_TAB:
                show_game_info()
            # 플레이어 서브 입력
            if is_player_serve and is_waiting_for_serve:
                if event.type == pygame.KEYDOWN and event.key == pygame.K_SPACE:
                    # 서브 실행 및 상태 업데이트
                    serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                    ball_vel = serve_result['ball_vel']
                    ball_impact_boost = serve_result['ball_impact_boost']
                    is_waiting_for_serve = serve_result['is_waiting_for_serve']
                    if serve_result['fireball_last_cast'] is not None:
                        fireball_last_cast = serve_result['fireball_last_cast']
                        fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                    SOUND_SERVE.play()
                    # 🏓 서브 시에도 물리 효과 적용
                    calculate_bounce(PLAYER)  # 서브는 드라이브 발동 안됨
                    # 🎯 서브 시 타격 이펙트 생성
                    create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=True)
            # 아이템 사용 - Aipill 활성화 시에는 아이템 사용 불가
            item_use_pressed = False
            direct_item_index = -1  # 숫자키로 직접 선택된 아이템 인덱스
            # 키보드 조작
            if event.type == pygame.KEYDOWN:
                if event.key in [pygame.K_s, 0x73, 0x6D]:  # 영어 S, 한글 ㅁ
                    item_use_pressed = True
                # 🔢 숫자키로 아이템 직접 사용 (1~6)
                elif event.key >= pygame.K_1 and event.key <= pygame.K_6:
                    number_key = event.key - pygame.K_1  # 0~5로 변환
                    if active_item_slot and number_key < len(active_item_slot):
                        direct_item_index = number_key
                        print(f"🔢 숫자키 {number_key + 1}번으로 아이템 직접 사용!")
                # 아이템 선택 - Aipill 활성화 시에도 선택은 가능 (시각적 피드백용)
                if event.key in [pygame.K_a, 0x61, 0x6E] and active_item_slot:  # 영어 A, 한글 ㄴ
                    selected_item_index = (selected_item_index - 1) % len(active_item_slot)
                elif event.key in [pygame.K_d, 0x64, 0x6F] and active_item_slot:  # 영어 D, 한글 ㅇ
                    selected_item_index = (selected_item_index + 1) % len(active_item_slot)
            # 마우스 조작 (비활성화됨)
            # if input_manager.get_control_mode() == "마우스":
            #     if mouse_controls.get("item_use", False):
            #         item_use_pressed = True
            # 📦 아이템 사용 처리 (S키 또는 숫자키)
            if not aipill_active and active_item_slot:
                use_item = False
                target_index = -1
                # S키로 현재 선택된 아이템 사용
                if item_use_pressed and selected_item_index < len(active_item_slot):
                    use_item = True
                    target_index = selected_item_index
                # 숫자키로 직접 아이템 사용
                elif direct_item_index >= 0:
                    use_item = True
                    target_index = direct_item_index
                if use_item:
                    item = active_item_slot[target_index]
                    current_time = pygame.time.get_ticks()
                    # 🔢 숫자키 사용 시 선택 인덱스도 업데이트
                    if direct_item_index >= 0:
                        selected_item_index = target_index
                    # 쿨타임 체크 (개별 아이템 쿨타임 + 전역 쿨타임)
                    # 장인 아이템이 있으면 쿨타임 10% 감소 (0.8초), 쿨타임 아이템이 있으면 2.4초 추가 감소
                    cooldown_reduction = 800 if master_obtained else 0  # 10% of 8000ms
                    cooldown_reduction += 2400 if cooltime_obtained else 0  # 30% of 8000ms
                    individual_cooldown_ok = "last_use" not in item or current_time - item["last_use"] >= (8000 - cooldown_reduction)
                    global_cooldown_ok = current_time - last_item_use_time >= (8000 - cooldown_reduction)
                    if individual_cooldown_ok and global_cooldown_ok:  # 둘 다 만족해야 사용 가능
                        apply_effect(item["effect"])
                        # 사용한 아이템 제거
                        del active_item_slot[target_index]
                        # 선택 인덱스 조정
                        if selected_item_index >= len(active_item_slot):
                            selected_item_index = max(0, len(active_item_slot) - 1)
                        elif target_index <= selected_item_index and selected_item_index > 0:
                            # 선택된 아이템보다 앞의 아이템이 삭제되면 인덱스 조정
                            selected_item_index -= 1
                        # 전역 쿨타임 업데이트
                        last_item_use_time = current_time
                        # 남은 다른 아이템들에만 쿨타임 적용 (사용한 아이템은 제거되었으므로)
                        for other_item in active_item_slot:
                            other_item["last_use"] = current_time
                    else:
                        # 쿨타임 중일 때 피드백
                        if not individual_cooldown_ok:
                            print("개별 아이템 쿨타임 중...")
                        if not global_cooldown_ok:
                            remaining_time = ((8000 - cooldown_reduction) - (current_time - last_item_use_time)) / 1000
                            print(f"전역 쿨타임 중... {remaining_time:.1f}초 남음")
        # ✅ 플레이어 서브 자동 발사 (3초 이상 대기하면 자동으로 serve)
        if is_player_serve and is_waiting_for_serve:
            if pygame.time.get_ticks() - waiting_start_time >= 3000:  # 3초
                # 서브 실행 및 상태 업데이트
                serve_result = physics_manager.serve_ball(is_player_serve, current_stage)
                ball_vel = serve_result['ball_vel']
                ball_impact_boost = serve_result['ball_impact_boost']
                is_waiting_for_serve = serve_result['is_waiting_for_serve']
                if serve_result['fireball_last_cast'] is not None:
                    fireball_last_cast = serve_result['fireball_last_cast']
                    fireball_cooldown = 1500  # 1.5초 쿨타임 강제 설정
                SOUND_SERVE.play()
                # 🏓 플레이어 자동 서브 시에도 물리 효과 적용
                calculate_bounce(PLAYER)  # 자동 서브는 드라이브 발동 안됨
                # 🎯 플레이어 자동 서브 시 타격 이펙트 생성
                create_impact_effect(BALL.centerx, BALL.centery, ball_vel, is_player=True)
        # 아이템 스폰 처리 (템스폰)
        if pygame.time.get_ticks() - last_item_spawn_time >= next_item_spawn_delay:
            items.spawn_random_item()
            last_item_spawn_time = pygame.time.get_ticks()
            next_item_spawn_delay = random.randint(15000, 25000)
        if profiler:
            profiler.end_section("Events")
            profiler.start_section("GameLogic")
        # 🎯 일시정지 상태가 아닐 때만 게임 로직 업데이트
        if not game_paused:
            # 🔧 파워스매싱 정지 시간 체크 및 처리
            if power_smashing_freeze_active:
                current_time = pygame.time.get_ticks()
                elapsed_freeze_time = current_time - power_smashing_freeze_start_time
                if elapsed_freeze_time >= power_smashing_freeze_duration:
                    # 정지 시간 종료 - 공 발사 및 효과음 재생
                    power_smashing_freeze_active = False
                    # 고스트샷이 아닐 때만 파워스매싱 포물선 활성화
                    if not mega_smashing_active:
                        power_smashing_parabola_active = True
                    else:
                        print(f"🐉 고스트샷 정지 시간 종료! mega_smashing_active={mega_smashing_active}")
                    power_smashing_start_time = current_time
                    # 파워스매시 발사 후 special_active를 False로 설정하여 게이지 충전 허용
                    special_active = False
                    # 🎵 파워스매싱 공 발사 효과음 재생
                    SOUND_POWER_SMASH_LAUNCH.play()
                    print("🎵 파워스매싱 정지 시간 종료! 공 발사 효과음 재생!")
                    # 고스트샷 상태 확인
                    if mega_smashing_active:
                        print(f"🐉 정지 시간 종료 후 고스트샷 여전히 활성화됨!")
            # 🔧 파워스매싱 정지 시간 중에는 게임 로직 업데이트 생략 (고스트샷일 때는 정지 안함)
            if not power_smashing_freeze_active or mega_smashing_active:
                # 상태 업데이트
                # 🆕 새로운 보스전에서는 빨간 효과 업데이트 생략 (게이지를 사용하지 않음)
                if not new_boss_mode_active:
                    update_red_intensity()
                    update_gauge_animation()  # 게이지 부드러운 애니메이션 업데이트
                update_item_obtained_effect()  # 🆕 아이템 획득 효과 업데이트
                # 풍선 터지는 효과는 effects_manager에서 통합 관리
                update_impact_particles()  # 🎯 타격 이펙트 파티클 업데이트
                handle_whip()
                handle_balloon()  # 🆕 풍선 스킬 처리
                handle_quake()
                handle_new_boss_skills_timer()  # 🆕 새로운 보스들 스킬 타이머 처리
                handle_emotional_overdrive()
                handle_tears()
                check_tear_collisions()
                check_balloon_collisions()  # 🆕 풍선 충돌 감지
                update_water_trail()  # 🆕 물자국 업데이트
                handle_aipill()  # 🆕 AI 필 타이머 처리
                handle_wall()  # 🆕 벽돌 처리
                # 아이템 업데이트
                items.update_items(PLAYER, apply_effect, store_passive_item, store_active_item)
                handle_player(keys)
                handle_ball()
                handle_boss()
                # 🌟 대쉬 스피릿 레이저 시스템 업데이트
                update_dash_spirit_lasers()
                check_laser_ball_collision()
        if profiler:
            profiler.end_section("GameLogic")
            profiler.start_section("Rendering")
        # 원래 렌더링 로직 (항상 60fps)
        # 화면 흔들림 효과 처리
        draw_shaking_screen()
        if screen_shake_offset_x != 0 or screen_shake_offset_y != 0:
            # 화면 흔들림이 있을 때만 임시 표면 사용
            print(f"🎮 화면 흔들림 렌더링: offset=({screen_shake_offset_x}, {screen_shake_offset_y})")
            temp_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            # 임시 표면에 모든 것 그리기
            temp_surface.fill((0, 0, 0, 0))  # 투명한 배경으로 지우기
            # SCREEN을 임시로 temp_surface로 교체
            temp_screen = SCREEN
            SCREEN = temp_surface
            draw_field()
            draw_objects()
            draw_boss_health_bar()  # 💪 체력형 보스 체력바 그리기
            draw_laser_cannon_gauge()  # ⚡ 레이저 쿨타임 게이지바
            # 스테이지 1 벽 충돌 테두리 깜빡임 효과
            if current_stage == 1 and border_flash_active:
                print(f"🎨 테두리 렌더링 체크: stage={current_stage}, active={border_flash_active}, timer={border_flash_timer}")
                if border_flash_timer > 0:
                    # 깜빡임 효과를 위한 알파값 계산 (빠른 페이드 아웃)
                    alpha = (border_flash_timer / border_flash_duration)
                    flash_color = (
                        int(border_flash_color[0] * alpha),
                        int(border_flash_color[1] * alpha),
                        int(border_flash_color[2] * alpha)
                    )
                    print(f"🎨 테두리 색상: {flash_color}, alpha={alpha}")
                    # 테두리 그리기 (상, 하, 좌, 우)
                    pygame.draw.rect(temp_surface, flash_color, (0, 0, WIDTH, border_flash_thickness))  # 상단
                    pygame.draw.rect(temp_surface, flash_color, (0, HEIGHT - border_flash_thickness, WIDTH, border_flash_thickness))  # 하단
                    pygame.draw.rect(temp_surface, flash_color, (0, 0, border_flash_thickness, HEIGHT))  # 좌측
                    pygame.draw.rect(temp_surface, flash_color, (WIDTH - border_flash_thickness, 0, border_flash_thickness, HEIGHT))  # 우측
                    border_flash_timer -= 1
                else:
                    border_flash_active = False
            # 원래 화면으로 복원하고 흔들림 적용
            SCREEN = temp_screen
            SCREEN.fill(BLACK)  # 원래 화면도 검은색으로 지우기
            SCREEN.blit(temp_surface, (screen_shake_offset_x, screen_shake_offset_y))
        else:
            # 흔들림이 없을 때는 직접 그리기
            draw_field()
            draw_objects()
            draw_boss_health_bar()  # 💪 체력형 보스 체력바 그리기
            draw_laser_cannon_gauge()  # ⚡ 레이저 쿨타임 게이지바
            # 스테이지 1 벽 충돌 테두리 깜빡임 효과
            if current_stage == 1 and border_flash_active:
                print(f"🎨 테두리 렌더링 체크: stage={current_stage}, active={border_flash_active}, timer={border_flash_timer}")
                if border_flash_timer > 0:
                    # 깜빡임 효과를 위한 알파값 계산 (빠른 페이드 아웃)
                    alpha = (border_flash_timer / border_flash_duration)
                    flash_color = (
                        int(border_flash_color[0] * alpha),
                        int(border_flash_color[1] * alpha),
                        int(border_flash_color[2] * alpha)
                    )
                    print(f"🎨 테두리 색상: {flash_color}, alpha={alpha}")
                    # 테두리 그리기 (상, 하, 좌, 우)
                    draw.rect(flash_color, (0, 0, WIDTH, border_flash_thickness))  # 상단
                    draw.rect(flash_color, (0, HEIGHT - border_flash_thickness, WIDTH, border_flash_thickness))  # 하단
                    draw.rect(flash_color, (0, 0, border_flash_thickness, HEIGHT))  # 좌측
                    draw.rect(flash_color, (WIDTH - border_flash_thickness, 0, border_flash_thickness, HEIGHT))  # 우측
                    border_flash_timer -= 1
                else:
                    border_flash_active = False
        # 스테이지 2 정글 테두리 효과
        if current_stage == 2:
            draw_stage2_jungle_border()
            update_stage2_leaves()
            draw_stage2_leaves()
        draw_water_trail()  # 🆕 물자국 그리기
        draw_balloons()  # 🆕 풍선 그리기
        # 풍선 터지는 효과는 effects_manager에서 통합 관리
        draw_item_obtained_effect()  # 🆕 아이템 획득 효과 그리기
        draw_dash_spirit_lasers(SCREEN, PLAYER, dash_spirit_lasers)  # 🌟 대쉬 스피릿 레이저 그리기
        draw_ai_visualization()  # 🧠 AI 상태 시각화
        # draw_player_skill_display()  # 🏆 플레이어 실력 표시 (ESC 메뉴에서 확인)
        # 🎯 일시정지 UI 렌더링
        if game_paused:
            draw_pause_overlay()
        # === DRIVE! 텍스트 표시 ===
        global drive_text_timer
        if drive_text_timer > 0:
            drive_text_timer -= 1
            # 텍스트 위치 (플레이어 패들 주변)
            text_x = PLAYER.centerx
            text_y = PLAYER.centery - 60
            # 텍스트 애니메이션 (페이드 인/아웃)
            if drive_text_timer > 22:
                alpha = int(255 * ((30 - drive_text_timer) / 8))
            elif drive_text_timer < 8:
                alpha = int(255 * (drive_text_timer / 8))
            else:
                alpha = 255
            # DRIVE! 텍스트 그리기 (깨끗한 흰색, 폰트 크기 축소)
            try:
                drive_font = pygame.font.Font("NanumSquareEB.ttf", 28)
            except:
                drive_font = pygame.font.Font(None, 36)
            # 그림자 효과
            shadow_surf = drive_font.render("DRIVE!", True, (50, 50, 50))
            shadow_surf.set_alpha(alpha)
            shadow_rect = shadow_surf.get_rect(center=(text_x + 2, text_y + 2))
            SCREEN.blit(shadow_surf, shadow_rect)
            # 메인 텍스트 (깨끗한 흰색)
            text_surf = drive_font.render("DRIVE!", True, (255, 255, 255))
            text_surf.set_alpha(alpha)
            text_rect = text_surf.get_rect(center=(text_x, text_y))
            SCREEN.blit(text_surf, text_rect)
        if profiler:
            profiler.end_section("Rendering")
            profiler.draw()  # 프로파일러 오버레이 그리기
        pygame.display.flip()
        # 프로파일러 프레임 종료
        if profiler:
            profiler.end_frame()
        # 마우스 상태 업데이트 (비활성화됨)
        # # 마우스 위치 업데이트는 input_manager에서 처리
        # input_manager.update_mouse_position()
        # # 마우스 휠 상태 초기화는 input_manager에서 처리
        # input_manager.reset_wheel_events()
        # # MOUSE_WHEEL_DOWN은 input_manager에서 처리
        # 라운드 종료 체크
        if round_wins >= win_goal:
            # 🆕 게임 종료 시 즉시 상모돌리기 사운드 정지
            whip_active = False
            whip_timer = 0
            whip_sound.stop()
            if BOSS and hasattr(BOSS, 'whip_sound') and BOSS.whip_sound:
                BOSS.whip_sound.stop()
            show_result(True)
            return
        elif round_losses >= win_goal:
            # 🆕 게임 종료 시 즉시 상모돌리기 사운드 정지
            whip_active = False
            whip_timer = 0
            whip_sound.stop()
            if BOSS and hasattr(BOSS, 'whip_sound') and BOSS.whip_sound:
                BOSS.whip_sound.stop()
            # 🏆 스테이지 실패 기록
            record_stage_result(current_stage, cleared=False)
            show_result(False)
            return
def game_loop():
    while True:
        show_start_screen()
        # show_start_screen()에서 게임이 시작되고 끝나면 다시 메인 메뉴로 돌아옴
def draw_pause_overlay():
    """일시정지 오버레이 UI 그리기"""
    # 반투명 검정 오버레이
    overlay = pygame.Surface((WIDTH, HEIGHT))
    overlay.set_alpha(120)  # 투명도 설정 (0-255, 낮을수록 투명)
    overlay.fill((0, 0, 0))
    SCREEN.blit(overlay, (0, 0))
    # PAUSE 텍스트
    font_pause = pygame.font.Font("NanumSquareEB.ttf", 80)
    pause_text = font_pause.render("PAUSE", True, (255, 255, 255))
    # 텍스트에 그림자 효과 추가
    shadow_text = font_pause.render("PAUSE", True, (50, 50, 50))
    shadow_rect = shadow_text.get_rect(center=(WIDTH//2 + 3, HEIGHT//2 + 3))
    SCREEN.blit(shadow_text, shadow_rect)
    # 메인 텍스트
    pause_rect = pause_text.get_rect(center=(WIDTH//2, HEIGHT//2))
    SCREEN.blit(pause_text, pause_rect)
    # 하단 힌트 텍스트
    font_hint = pygame.font.Font("NanumSquareR.ttf", 24)
    hint_text = font_hint.render("P키를 다시 눌러서 게임 재개", True, (200, 200, 200))
    hint_rect = hint_text.get_rect(center=(WIDTH//2, HEIGHT//2 + 80))
    SCREEN.blit(hint_text, hint_rect)
def show_pause_menu():
    """일시정지 메뉴"""
    global session_medal_earned, medal_score
    font_large = pygame.font.Font("NanumSquareB.ttf", 36)
    font_medium = pygame.font.Font("NanumSquareR.ttf", 28)
    font_small = pygame.font.Font("NanumSquareR.ttf", 24)
    button_width = 300
    button_height = 60
    button_spacing = 20
    # 버튼 위치 계산
    center_x = WIDTH // 2
    start_y = HEIGHT // 2 - 100
    continue_rect = pygame.Rect(center_x - button_width // 2, start_y, button_width, button_height)
    inventory_rect = pygame.Rect(center_x - button_width // 2, start_y + button_height + button_spacing, button_width, button_height)
    info_rect = pygame.Rect(center_x - button_width // 2, start_y + (button_height + button_spacing) * 2, button_width, button_height)
    quit_rect = pygame.Rect(center_x - button_width // 2, start_y + (button_height + button_spacing) * 3, button_width, button_height)
    selected = 0  # 0: 계속, 1: 인벤토리, 2: 정보, 3: 나가기
    while True:
        # 현재 게임 화면을 배경으로 사용
        draw_field()
        draw_shaking_screen()
        draw_objects()
        draw_water_trail()
        # 반투명 오버레이
        overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 128))  # 반투명 검은색
        SCREEN.blit(overlay, (0, 0))
        # 메뉴 제목
        title_text = font_large.render("일시정지", True, WHITE)
        title_rect = title_text.get_rect(center=(center_x, start_y - 60))
        SCREEN.blit(title_text, title_rect)
        # 버튼들 그리기
        buttons = [continue_rect, inventory_rect, info_rect, quit_rect]
        button_texts = ["계속", "인벤토리", "정보", "나가기"]
        for i, (rect, text) in enumerate(zip(buttons, button_texts)):
            if i == selected:
                # 선택된 버튼
                draw.rect((100, 150, 255), rect)
                draw.rect(WHITE, rect, 3)
                text_color = BLACK
            else:
                # 선택되지 않은 버튼
                draw.rect((50, 50, 50), rect)
                draw.rect((150, 150, 150), rect, 2)
                text_color = WHITE
            text_surface = font_medium.render(text, True, text_color)
            text_rect = text_surface.get_rect(center=rect.center)
            SCREEN.blit(text_surface, text_rect)
        pygame.display.flip()
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return "continue"  # ESC로 메뉴 닫기
                elif event.key == pygame.K_UP:
                    selected = (selected - 1) % 4
                    SOUND_BUTTON_HOVER.play()  # 🎵 호버 사운드
                elif event.key == pygame.K_DOWN:
                    selected = (selected + 1) % 4
                    SOUND_BUTTON_HOVER.play()  # 🎵 호버 사운드
                elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                    SOUND_BUTTON_CLICK.play()  # 🎵 클릭 사운드
                    if selected == 0:  # 계속
                        return "continue"
                    elif selected == 1:  # 인벤토리
                        show_game_info()
                    elif selected == 2:  # 정보
                        show_player_info()
                    elif selected == 3:  # 나가기
                        if show_surrender_confirm():
                            return "surrender"
            if event.type == pygame.MOUSEBUTTONDOWN:
                mouse_pos = pygame.mouse.get_pos()
                for i, rect in enumerate(buttons):
                    if rect.collidepoint(mouse_pos):
                        SOUND_BUTTON_CLICK.play()  # 🎵 클릭 사운드
                        if i == 0:  # 계속
                            return "continue"
                        elif i == 1:  # 인벤토리
                            show_game_info()
                        elif i == 2:  # 정보
                            show_player_info()
                        elif i == 3:  # 나가기
                            if show_surrender_confirm():
                                return "surrender"
def draw_gradient_background(surface, rect, color1, color2, horizontal=False):
    """그라데이션 배경 - DrawHelper 사용"""
    from rendering.draw_helper import DrawHelper
    helper = DrawHelper(surface)
    # 간단한 그라데이션 구현
    steps = 50
    for i in range(steps):
        ratio = i / steps
        color = [int(c1 + (c2 - c1) * ratio) for c1, c2 in zip(color1, color2)]
        if horizontal:
            r = pygame.Rect(rect.x + rect.width * i // steps, rect.y, rect.width // steps + 1, rect.height)
        else:
            r = pygame.Rect(rect.x, rect.y + rect.height * i // steps, rect.width, rect.height // steps + 1)
        helper.rect(color, r)
def draw_modern_panel(surface, rect, title="", title_color=(255, 215, 0)):
    """현대적인 패널 그리기"""
    # 메인 배경 (어두운 그라데이션)
    draw_gradient_background(surface, rect, (25, 25, 35), (45, 45, 55))
    # 외곽 테두리 (글로우 효과)
    for i in range(3):
        border_color = (100 + i*20, 150 + i*15, 200 + i*10)
        pygame.draw.rect(surface, border_color, 
                        (rect.x - i, rect.y - i, rect.width + 2*i, rect.height + 2*i), 2)
    # 내부 테두리
    pygame.draw.rect(surface, (80, 80, 100), rect, 2)
    # 상단 헤더 영역
    if title:
        header_rect = pygame.Rect(rect.x + 10, rect.y + 10, rect.width - 20, 50)
        draw_gradient_background(surface, header_rect, (60, 60, 80), (40, 40, 60))
        pygame.draw.rect(surface, (120, 120, 140), header_rect, 1)
        # 타이틀 텍스트
        font_title = pygame.font.Font("NanumSquareEB.ttf", 24)
        title_surface = font_title.render(title, True, title_color)
        title_rect = title_surface.get_rect(center=(header_rect.centerx, header_rect.centery))
        surface.blit(title_surface, title_rect)
def draw_section_container(surface, rect, title, icon=""):
    """섹션 컨테이너 그리기"""
    # 섹션 배경
    section_bg = pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)
    draw_gradient_background(section_bg, pygame.Rect(0, 0, rect.width, rect.height), 
                           (35, 35, 45, 200), (55, 55, 65, 200))
    surface.blit(section_bg, rect)
    # 섹션 테두리
    pygame.draw.rect(surface, (100, 150, 200, 150), rect, 2)
    # 섹션 제목
    font_section = pygame.font.Font("NanumSquareB.ttf", 18)
    title_text = f"{icon} {title}" if icon else title
    title_surface = font_section.render(title_text, True, (200, 220, 255))
    title_rect = title_surface.get_rect(left=rect.x + 15, top=rect.y + 10)
    surface.blit(title_surface, title_rect)
    # 제목 밑줄
    pygame.draw.line(surface, (150, 180, 220), 
                    (rect.x + 15, rect.y + 35), 
                    (rect.x + rect.width - 15, rect.y + 35), 2)
def show_player_info():
    """플레이어 실력 정보 화면 - 현대적인 디자인"""
    global player_analyzer
    if not player_analyzer:
        # 플레이어 분석기가 없는 경우 간단한 메시지 표시
        font_large = pygame.font.Font("NanumSquareB.ttf", 32)
        font_medium = pygame.font.Font("NanumSquareR.ttf", 24)
        while True:
            # 배경
            draw_field()
            draw_shaking_screen()
            draw_objects()
            # 반투명 오버레이
            overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, 180))
            SCREEN.blit(overlay, (0, 0))
            # 메시지
            title_text = font_large.render("플레이어 정보", True, WHITE)
            title_rect = title_text.get_rect(center=(WIDTH//2, HEIGHT//2 - 50))
            SCREEN.blit(title_text, title_rect)
            msg_text = font_medium.render("플레이어 분석 시스템을 사용할 수 없습니다.", True, (200, 200, 200))
            msg_rect = msg_text.get_rect(center=(WIDTH//2, HEIGHT//2))
            SCREEN.blit(msg_text, msg_rect)
            esc_text = font_medium.render("ESC를 눌러 돌아가기", True, (150, 150, 150))
            esc_rect = esc_text.get_rect(center=(WIDTH//2, HEIGHT//2 + 50))
            SCREEN.blit(esc_text, esc_rect)
            pygame.display.flip()
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                if event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        return
        return
    font_large = pygame.font.Font("NanumSquareB.ttf", 32)
    font_medium = pygame.font.Font("NanumSquareR.ttf", 24)
    font_small = pygame.font.Font("NanumSquareR.ttf", 20)
    font_tiny = pygame.font.Font("NanumSquareR.ttf", 16)
    show_feedback = False  # F키로 피드백 토글
    while True:
        try:
            # 현재 분석 데이터 가져오기 (현재 스테이지 반영)
            current_stage = game_stage if 'game_stage' in globals() else 1
            rank_info = player_analyzer.get_current_rank(current_stage)
            detailed_stats = player_analyzer.get_detailed_analysis(current_stage)
            # 배경
            draw_field()
            draw_shaking_screen()
            draw_objects()
            # 반투명 오버레이 (더 어둡게)
            overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, 200))
            SCREEN.blit(overlay, (0, 0))
            # 메인 패널 설정
            main_panel_width = 580
            main_panel_height = 680
            main_panel_x = (WIDTH - main_panel_width) // 2
            main_panel_y = 30
            main_panel_rect = pygame.Rect(main_panel_x, main_panel_y, main_panel_width, main_panel_height)
            # 메인 패널 그리기
            draw_modern_panel(SCREEN, main_panel_rect, "🏆 플레이어 실력 분석", (255, 215, 0))
            # 콘텐츠 영역 설정 (헤더 아래)
            content_y = main_panel_y + 80
            # === 섹션 1: 등급 정보 ===
            rank_section_rect = pygame.Rect(main_panel_x + 20, content_y, main_panel_width - 40, 120)
            draw_section_container(SCREEN, rank_section_rect, "현재 등급", "🎖️")
            # 등급 정보 표시
            rank_color = rank_info["color"]
            rank_text = f"{rank_info['icon']} {rank_info['name']}"
            rank_surface = font_medium.render(rank_text, True, rank_color)
            rank_rect = rank_surface.get_rect(center=(rank_section_rect.centerx, rank_section_rect.y + 60))
            SCREEN.blit(rank_surface, rank_rect)
            # 점수
            score_text = f"점수: {rank_info['score']:,}점"
            score_surface = font_small.render(score_text, True, WHITE)
            score_rect = score_surface.get_rect(center=(rank_section_rect.centerx, rank_section_rect.y + 85))
            SCREEN.blit(score_surface, score_rect)
            # 등급 설명
            desc_text = rank_info["description"]
            desc_surface = font_tiny.render(desc_text, True, (200, 200, 200))
            desc_rect = desc_surface.get_rect(center=(rank_section_rect.centerx, rank_section_rect.y + 105))
            SCREEN.blit(desc_surface, desc_rect)
            # === 섹션 2: 능력 통계 ===
            stats_section_y = content_y + 140
            stats_section_rect = pygame.Rect(main_panel_x + 20, stats_section_y, main_panel_width - 40, 200)
            draw_section_container(SCREEN, stats_section_rect, "능력 분석", "📊")
            stats = detailed_stats["stats"]
            # 왼쪽: 텍스트 통계, 오른쪽: 레이더 차트
            left_stats_x = stats_section_rect.x + 20
            # 각 능력의 등급과 색상 계산
            skill_grade, skill_color = score_to_grade(stats['skill_mastery_score'])
            dash_grade, dash_color = score_to_grade(stats['dash_mastery_score'])
            item_grade, item_color = score_to_grade(stats['item_mastery_score'])
            guard_grade, guard_color = score_to_grade(stats['guard_ability_score'])
            stat_items = [
                ("스킬 활용:", skill_grade, skill_color),
                ("대쉬 활용:", dash_grade, dash_color),
                ("아이템 활용:", item_grade, item_color),
                ("가드 능력:", guard_grade, guard_color),
                ("총 게임 수:", f"{stats['total_games']}게임", WHITE)
            ]
            # 텍스트 통계 표시 (왼쪽)
            for i, (stat_name, stat_value, color) in enumerate(stat_items):
                name_surface = font_tiny.render(stat_name, True, WHITE)
                value_surface = font_tiny.render(f" {stat_value}", True, color)
                name_rect = name_surface.get_rect(left=left_stats_x, top=stats_section_rect.y + 50 + i * 22)
                value_rect = value_surface.get_rect(left=name_rect.right, top=stats_section_rect.y + 50 + i * 22)
                SCREEN.blit(name_surface, name_rect)
                SCREEN.blit(value_surface, value_rect)
            # 오른쪽: 레이더 차트
            chart_center_x = stats_section_rect.x + stats_section_rect.width * 3 // 4
            chart_center_y = stats_section_rect.y + 120
            draw_ability_radar_chart(stats, chart_center_x, chart_center_y, 70)
            # === 섹션 3: 업적 & 피드백 ===
            bottom_section_y = stats_section_y + 220
            bottom_section_height = main_panel_y + main_panel_height - bottom_section_y - 80
            # 왼쪽: 업적
            achievements = detailed_stats["achievements"]
            if achievements:
                achievement_section_width = (main_panel_width - 60) // 2
                achievement_rect = pygame.Rect(main_panel_x + 20, bottom_section_y, achievement_section_width, bottom_section_height)
                draw_section_container(SCREEN, achievement_rect, "업적", "🏅")
                # 업적 표시 (최근 3개)
                for i, achievement in enumerate(achievements[-3:]):
                    if i < 3:  # 공간 제한
                        achievement_surface = font_tiny.render(achievement[:30] + "..." if len(achievement) > 30 else achievement, True, (255, 215, 0))
                        achievement_rect_text = achievement_surface.get_rect(left=achievement_rect.x + 15, top=achievement_rect.y + 50 + i * 25)
                        SCREEN.blit(achievement_surface, achievement_rect_text)
            # 오른쪽: 피드백
            tips = detailed_stats["improvement_tips"]
            if tips:
                feedback_section_width = (main_panel_width - 60) // 2
                feedback_x = main_panel_x + 30 + achievement_section_width if achievements else main_panel_x + 20
                feedback_rect = pygame.Rect(feedback_x, bottom_section_y, feedback_section_width, bottom_section_height)
                draw_section_container(SCREEN, feedback_rect, "개선 피드백", "💡")
                # 피드백 표시 (최대 2개)
                for i, tip in enumerate(tips[:2]):
                    # 텍스트 길이 제한
                    display_tip = tip[:35] + "..." if len(tip) > 35 else tip
                    tip_surface = font_tiny.render(display_tip, True, (150, 255, 150))
                    tip_rect_text = tip_surface.get_rect(left=feedback_rect.x + 15, top=feedback_rect.y + 50 + i * 30)
                    SCREEN.blit(tip_surface, tip_rect_text)
            # 상세 피드백 오버레이 (F키로 토글)
            if show_feedback:
                # 상세 피드백 전체 화면 오버레이
                try:
                    feedback_data = player_analyzer.get_detailed_feedback(current_stage)
                    # 피드백 오버레이 배경
                    feedback_overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
                    feedback_overlay.fill((0, 0, 0, 220))
                    SCREEN.blit(feedback_overlay, (0, 0))
                    # 피드백 패널
                    feedback_panel_width = 500
                    feedback_panel_height = 600
                    feedback_panel_x = (WIDTH - feedback_panel_width) // 2
                    feedback_panel_y = (HEIGHT - feedback_panel_height) // 2
                    feedback_panel_rect = pygame.Rect(feedback_panel_x, feedback_panel_y, feedback_panel_width, feedback_panel_height)
                    # 피드백 패널 그리기
                    draw_modern_panel(SCREEN, feedback_panel_rect, "📝 상세 피드백 분석", (100, 255, 100))
                    # 피드백 내용 영역
                    content_area = pygame.Rect(feedback_panel_x + 20, feedback_panel_y + 80, feedback_panel_width - 40, feedback_panel_height - 120)
                    # 스킬 피드백 텍스트 표시
                    skill_feedback = feedback_data["skill_feedback"]
                    lines = skill_feedback.split('\n')
                    y_pos = content_area.y
                    for line in lines[:20]:  # 최대 20줄 표시
                        if line.strip() and y_pos < content_area.y + content_area.height - 20:
                            display_line = line[:70] + "..." if len(line) > 70 else line
                            line_surface = font_tiny.render(display_line, True, WHITE)
                            line_rect = line_surface.get_rect(left=content_area.x, top=y_pos)
                            SCREEN.blit(line_surface, line_rect)
                            y_pos += 18
                except Exception as e:
                    print(f"🔴 피드백 로드 오류: {e}")
                    error_text = font_small.render(f"피드백 로드 오류: {str(e)[:40]}", True, (255, 100, 100))
                    error_rect = error_text.get_rect(center=(WIDTH//2, HEIGHT//2))
                    SCREEN.blit(error_text, error_rect)
            # 하단 조작 안내
            control_text = "F: 상세피드백 | ESC: 돌아가기" if not show_feedback else "F: 기본보기 | ESC: 돌아가기"
            control_surface = font_tiny.render(control_text, True, (180, 180, 180))
            control_rect = control_surface.get_rect(center=(main_panel_rect.centerx, main_panel_rect.bottom - 25))
            SCREEN.blit(control_surface, control_rect)
        except Exception as e:
            # 오류 발생 시 자세한 메시지 표시 및 로그 출력
            print(f"🔴 show_player_info 오류: {e}")
            print(f"🔴 오류 타입: {type(e).__name__}")
            import traceback
            traceback.print_exc()
            error_text = font_medium.render("정보를 불러올 수 없습니다.", True, (255, 100, 100))
            error_rect = error_text.get_rect(center=(WIDTH//2, HEIGHT//2))
            SCREEN.blit(error_text, error_rect)
            # 상세 오류 정보도 표시
            detail_text = font_small.render(f"오류: {str(e)[:60]}", True, (200, 100, 100))
            detail_rect = detail_text.get_rect(center=(WIDTH//2, HEIGHT//2 + 40))
            SCREEN.blit(detail_text, detail_rect)
        pygame.display.flip()
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return
                elif event.key == pygame.K_f:
                    show_feedback = not show_feedback
def show_game_info():
    """게임 정보 화면"""
    font_large = pygame.font.Font("NanumSquareB.ttf", 32)
    font_medium = pygame.font.Font("NanumSquareR.ttf", 24)
    font_small = pygame.font.Font("NanumSquareR.ttf", 20)
    # 페이지 상태 (0: 기본정보, 1: 아이템관리)
    current_page = 1  # Tab 키로 직접 아이템 관리로 이동
    # 공통 패널 변수 정의
    panel_width = 650
    panel_height = 450
    panel_x = (WIDTH - panel_width) // 2
    panel_y = 80
    # 기본정보 페이지 패널 변수
    info_panel_width = 500
    info_panel_height = 400
    info_panel_x = (WIDTH - info_panel_width) // 2
    info_panel_y = 80
    # 네비게이션 상태
    in_tab_selection = True  # True: 탭 선택 중, False: 아이템 선택 중
    selected_category = 0  # 0: 엑티브, 1: 패시브
    selected_active_item = -1  # -1: 선택되지 않음, 0 이상: 선택된 아이템 인덱스
    selected_passive_item = -1
    # Tab 키 상태
    while True:
        # 현재 게임 화면을 배경으로 사용
        draw_field()
        draw_shaking_screen()
        draw_objects()
        draw_water_trail()
        # 반투명 오버레이
        overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        SCREEN.blit(overlay, (0, 0))
        if current_page == 0:  # 기본정보 페이지
            # 패널 배경
            draw.rect((30, 30, 50), (info_panel_x, info_panel_y, info_panel_width, info_panel_height))
            draw.rect((100, 150, 255), (info_panel_x, info_panel_y, info_panel_width, info_panel_height), 3)
            # 제목
            title_text = font_large.render("게임 정보", True, WHITE)
            title_rect = title_text.get_rect(center=(info_panel_x + info_panel_width // 2, info_panel_y + 25))
            SCREEN.blit(title_text, title_rect)
            # 기본 정보
            info_y = info_panel_y + 60
            info_spacing = 28
            # 보스 vs 보스 모드 확인
            character_info = "새로운 보스 (하단)" if new_boss_mode_active else "UFO 플레이어"
            mode_info = "🆕 NEW BOSS BATTLE" if new_boss_mode_active else "일반 모드"
            info_items = [
                f"게임 모드: {mode_info}",
                f"현재 스테이지: {current_stage}",
                f"라운드 점수: {round_wins} : {round_losses}",
                f"획득한 메달: {session_medal_earned}",
                f"총 메달: {medal_score}",
                f"캐릭터: {character_info}",
                f"이동속도: {PLAYER_SPEED}",
                f"방향전환속도: {PLAYER_SPEED * (1.5 if speedgear_obtained else 1.0):.1f}",
                "",
                "조작법:" if not new_boss_mode_active else "AI 조작 (NEW BOSS BATTLE):",
                "방향키: 이동" if not new_boss_mode_active else "새로운 보스 AI가 자동 조작",
                "스페이스바: 서브" if not new_boss_mode_active else "서브는 자동으로 처리",
                "S: 아이템 사용" if not new_boss_mode_active else "아이템/스킬은 사용 안함",
                "1~6: 아이템 직접 사용" if not new_boss_mode_active else "새로운 보스들의 순수한 대결!",
                "A/D: 아이템 선택" if not new_boss_mode_active else "",
                "ESC: 일시정지"
            ]
            for i, info in enumerate(info_items):
                if info == "":
                    info_y += 15
                    continue
                if i < 7:  # 게임 정보
                    text_surface = font_medium.render(info, True, WHITE)
                else:  # 조작법
                    text_surface = font_small.render(info, True, (200, 200, 200))
                text_rect = text_surface.get_rect(left=info_panel_x + 40, top=info_y)
                SCREEN.blit(text_surface, text_rect)
                info_y += info_spacing
            # 페이지 전환 버튼
            next_button_rect = pygame.Rect(info_panel_x + info_panel_width - 130, info_panel_y + info_panel_height - 50, 100, 35)
            draw.rect((100, 150, 255), next_button_rect)
            draw.rect(WHITE, next_button_rect, 2)
            next_text = font_medium.render("아이템 →", True, BLACK)
            next_text_rect = next_text.get_rect(center=next_button_rect.center)
            SCREEN.blit(next_text, next_text_rect)
        else:  # 아이템관리 페이지
            # 아이템 관리 패널 (전체 화면)
            panel_width = 650
            panel_height = 450
            panel_x = (WIDTH - panel_width) // 2
            panel_y = 80
            # 패널 배경
            draw.rect((30, 30, 50), (panel_x, panel_y, panel_width, panel_height))
            draw.rect((100, 150, 255), (panel_x, panel_y, panel_width, panel_height), 3)
            # 제목
            title_text = font_large.render("아이템 관리", True, WHITE)
            title_rect = title_text.get_rect(center=(panel_x + panel_width // 2, panel_y + 25))
            SCREEN.blit(title_text, title_rect)
            # 아이템 카테고리 탭
            tab_width = 100
            tab_height = 35
            tab_x = panel_x + 40
            tab_y = panel_y + 60
            # 엑티브 탭
            if in_tab_selection and selected_category == 0:
                # 탭 선택 모드에서 엑티브 탭이 선택된 경우 - 밝은 하이라이트
                active_tab_color = (120, 180, 255)
                border_color = (255, 255, 255)
                border_width = 4
            elif selected_category == 0:
                # 아이템 선택 모드에서 엑티브 탭이 활성인 경우 - 중간 하이라이트
                active_tab_color = (80, 120, 200)
                border_color = (200, 200, 200)
                border_width = 2
            else:
                # 비활성 탭
                active_tab_color = (50, 50, 70)
                border_color = (100, 100, 100)
                border_width = 1
            draw.rect(active_tab_color, (tab_x, tab_y, tab_width, tab_height))
            draw.rect(border_color, (tab_x, tab_y, tab_width, tab_height), border_width)
            active_text = font_medium.render("엑티브", True, WHITE)
            active_text_rect = active_text.get_rect(center=(tab_x + tab_width // 2, tab_y + tab_height // 2))
            SCREEN.blit(active_text, active_text_rect)
            # 패시브 탭
            if in_tab_selection and selected_category == 1:
                # 탭 선택 모드에서 패시브 탭이 선택된 경우 - 밝은 하이라이트
                passive_tab_color = (120, 180, 255)
                border_color = (255, 255, 255)
                border_width = 4
            elif selected_category == 1:
                # 아이템 선택 모드에서 패시브 탭이 활성인 경우 - 중간 하이라이트
                passive_tab_color = (80, 120, 200)
                border_color = (200, 200, 200)
                border_width = 2
            else:
                # 비활성 탭
                passive_tab_color = (50, 50, 70)
                border_color = (100, 100, 100)
                border_width = 1
            draw.rect(passive_tab_color, (tab_x + tab_width + 15, tab_y, tab_width, tab_height))
            draw.rect(border_color, (tab_x + tab_width + 15, tab_y, tab_width, tab_height), border_width)
            passive_text = font_medium.render("패시브", True, WHITE)
            passive_text_rect = passive_text.get_rect(center=(tab_x + tab_width + 15 + tab_width // 2, tab_y + tab_height // 2))
            SCREEN.blit(passive_text, passive_text_rect)
            # 아이템 목록 (슬롯 형태)
            item_list_y = tab_y + tab_height + 25
            icon_size = 45  # 아이콘 크기 축소
            icon_spacing = 12  # 간격 축소
            icons_per_row = 8  # 한 줄에 8개 아이템 표시
            # 8개 아이템이 화면에 맞도록 시작 위치 계산
            total_width = icons_per_row * icon_size + (icons_per_row - 1) * icon_spacing
            start_x = panel_x + (panel_width - total_width) // 2
            if selected_category == 0:  # 엑티브 아이템
                items_to_show = active_item_slot if active_item_slot else []
                selected_index = selected_active_item
                if not items_to_show:
                    no_item_text = font_medium.render("소지한 엑티브 아이템이 없습니다", True, (150, 150, 150))
                    no_item_rect = no_item_text.get_rect(center=(panel_x + panel_width // 2, item_list_y + 100))
                    SCREEN.blit(no_item_text, no_item_rect)
                else:
                    # 아이콘들을 가로로 나열
                    for i, item in enumerate(items_to_show):
                        row = i // icons_per_row
                        col = i % icons_per_row
                        icon_x = start_x + col * (icon_size + icon_spacing)
                        icon_y = item_list_y + row * (icon_size + icon_spacing)  # 설명 공간 제거
                        # 선택된 아이콘 하이라이트
                        if i == selected_index and selected_index >= 0:
                            # 선택된 아이콘 배경
                            highlight_rect = pygame.Rect(icon_x - 5, icon_y - 5, icon_size + 10, icon_size + 10)
                            draw.rect((100, 150, 255), highlight_rect)
                            draw.rect(WHITE, highlight_rect, 3)
                        # 아이템 아이콘
                        if item.get("icon"):
                            icon = pygame.transform.scale(item["icon"], (icon_size, icon_size))
                            SCREEN.blit(icon, (icon_x, icon_y))
                        else:
                            # 기본 아이콘 (원형)
                            draw.circle((100, 100, 100), (icon_x + icon_size // 2, icon_y + icon_size // 2), icon_size // 2)
            else:  # 패시브 아이템
                items_to_show = passive_item_list if passive_item_list else []
                selected_index = selected_passive_item
                if not items_to_show:
                    no_item_text = font_medium.render("소지한 패시브 아이템이 없습니다", True, (150, 150, 150))
                    no_item_rect = no_item_text.get_rect(center=(panel_x + panel_width // 2, item_list_y + 100))
                    SCREEN.blit(no_item_text, no_item_rect)
                else:
                    # 아이콘들을 가로로 나열
                    for i, item in enumerate(items_to_show):
                        row = i // icons_per_row
                        col = i % icons_per_row
                        icon_x = start_x + col * (icon_size + icon_spacing)
                        icon_y = item_list_y + row * (icon_size + icon_spacing)  # 설명 공간 제거
                        # 선택된 아이콘 하이라이트
                        if i == selected_index and selected_index >= 0:
                            # 선택된 아이콘 배경
                            highlight_rect = pygame.Rect(icon_x - 5, icon_y - 5, icon_size + 10, icon_size + 10)
                            draw.rect((100, 150, 255), highlight_rect)
                            draw.rect(WHITE, highlight_rect, 3)
                        # 아이템 아이콘
                        if item.get("icon"):
                            icon = pygame.transform.scale(item["icon"], (icon_size, icon_size))
                            SCREEN.blit(icon, (icon_x, icon_y))
                        else:
                            # 기본 아이콘 (원형)
                            draw.circle((100, 100, 100), (icon_x + icon_size // 2, icon_y + icon_size // 2), icon_size // 2)
            # 아이템 설명 영역 (하단)
            desc_panel_width = panel_width - 60
            desc_panel_height = 80
            desc_panel_x = panel_x + 30
            desc_panel_y = panel_y + panel_height - 120
            # 설명 패널 배경
            draw.rect((20, 20, 40), (desc_panel_x, desc_panel_y, desc_panel_width, desc_panel_height))
            draw.rect((80, 120, 200), (desc_panel_x, desc_panel_y, desc_panel_width, desc_panel_height), 2)
            # 선택된 아이템의 설명 표시
            if selected_category == 0 and selected_active_item >= 0 and active_item_slot:
                selected_item = active_item_slot[selected_active_item]
                description = get_item_description(selected_item["name"])
            elif selected_category == 1 and selected_passive_item >= 0 and selected_passive_item < len(passive_item_list) and passive_item_list:
                selected_item = passive_item_list[selected_passive_item]
                description = get_item_description(selected_item["name"])
            else:
                description = "아이템을 선택하면 설명이 표시됩니다."
            # 설명 텍스트를 여러 줄로 나누기 (개선된 버전)
            def smart_text_wrap(text, max_width_chars=30):
                """텍스트를 보기 좋게 줄바꿈하는 함수"""
                if len(text) <= max_width_chars:
                    return [text]
                # 특수 문자로 구분할 수 있는 위치 찾기
                split_chars = [',', '/', '|', '·', ':', ';', '-']
                words = []
                # 먼저 공백으로 나누기
                temp_words = text.split()
                # 각 단어를 특수문자 기준으로 더 세분화
                for word in temp_words:
                    current_word = ""
                    for char in word:
                        current_word += char
                        if char in split_chars and len(current_word) > 1:
                            words.append(current_word)
                            current_word = "" 
                    if current_word:
                        words.append(current_word)
                if not words:
                    words = temp_words
                # 2줄로 나누는 경우 길이 균등하게 분배
                if len(' '.join(words)) <= max_width_chars * 2:
                    mid_point = len(words) // 2
                    # 최적의 분할점 찾기 (길이가 비슷하도록)
                    best_split = mid_point
                    target_length = len(text) // 2
                    min_diff = float('inf')
                    for i in range(1, len(words)):
                        line1_len = len(' '.join(words[:i]))
                        line2_len = len(' '.join(words[i:]))
                        diff = abs(line1_len - target_length) + abs(line2_len - target_length)
                        if diff < min_diff and line1_len <= max_width_chars and line2_len <= max_width_chars:
                            min_diff = diff
                            best_split = i
                    line1 = ' '.join(words[:best_split])
                    line2 = ' '.join(words[best_split:])
                    if line1 and line2:
                        return [line1, line2]
                # 기본 방식으로 폴백
                lines = []
                current_line = ""
                for word in words:
                    test_line = current_line + " " + word if current_line else word
                    if len(test_line) <= max_width_chars:
                        current_line = test_line
                    else:
                        if current_line:
                            lines.append(current_line)
                        current_line = word
                if current_line:
                    lines.append(current_line)
                return lines if lines else [text]
            lines = smart_text_wrap(description)
            # 설명 텍스트 그리기
            desc_text_y = desc_panel_y + 10
            line_spacing = 22  # 줄 간격 18 → 22로 증가
            for line_idx, line in enumerate(lines):
                if line_idx < 3:  # 최대 3줄까지만 표시
                    desc_text = font_small.render(line, True, (200, 200, 200))
                    desc_rect = desc_text.get_rect(left=desc_panel_x + 10, top=desc_text_y + line_idx * line_spacing)
                    SCREEN.blit(desc_text, desc_rect)
        pygame.display.flip()
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return
                elif event.key == pygame.K_TAB:
                    # Tab 키로 게임 복귀
                    return
                elif event.key == pygame.K_RIGHT and current_page == 0:
                    current_page = 1
                elif current_page == 1:  # 아이템 관리 페이지에서만
                    if in_tab_selection:  # 탭 선택 모드
                        if event.key == pygame.K_LEFT:
                            selected_category = 0  # 엑티브 탭
                        elif event.key == pygame.K_RIGHT:
                            selected_category = 1  # 패시브 탭
                        elif event.key == pygame.K_DOWN:
                            # 탭에서 아이템 선택 모드로 이동
                            in_tab_selection = False
                            current_items = active_item_slot if selected_category == 0 else passive_item_list
                            if current_items:
                                if selected_category == 0:
                                    selected_active_item = 0  # 첫 번째 아이템 선택
                                else:
                                    selected_passive_item = 0  # 첫 번째 아이템 선택
                    else:  # 아이템 선택 모드
                        current_items = active_item_slot if selected_category == 0 else passive_item_list
                        if current_items and event.key in [pygame.K_LEFT, pygame.K_RIGHT, pygame.K_UP, pygame.K_DOWN]:
                            current_index = selected_active_item if selected_category == 0 else selected_passive_item
                            if event.key == pygame.K_RIGHT:
                                # 오른쪽: 같은 줄에서 다음 아이템으로 (줄 끝에서 줄 처음으로 순환)
                                grid_cols = 8
                                current_row = current_index // grid_cols
                                current_col = current_index % grid_cols
                                # 현재 줄의 아이템 범위 계산
                                row_start = current_row * grid_cols
                                row_end = min(row_start + grid_cols - 1, len(current_items) - 1)
                                # 같은 줄 내에서 순환
                                if current_index == row_end:
                                    # 줄의 마지막 아이템이면 줄의 첫 번째 아이템으로
                                    new_index = row_start
                                else:
                                    # 다음 아이템으로
                                    new_index = current_index + 1
                            elif event.key == pygame.K_LEFT:
                                # 왼쪽: 같은 줄에서 이전 아이템으로 (줄 처음에서 줄 끝으로 순환)
                                grid_cols = 8
                                current_row = current_index // grid_cols
                                current_col = current_index % grid_cols
                                # 현재 줄의 아이템 범위 계산
                                row_start = current_row * grid_cols
                                row_end = min(row_start + grid_cols - 1, len(current_items) - 1)
                                # 같은 줄 내에서 순환
                                if current_index == row_start:
                                    # 줄의 첫 번째 아이템이면 줄의 마지막 아이템으로
                                    new_index = row_end
                                else:
                                    # 이전 아이템으로
                                    new_index = current_index - 1
                            elif event.key == pygame.K_DOWN:
                                # 아래: 그리드 기반 이동
                                grid_cols = 8
                                current_row = current_index // grid_cols
                                current_col = current_index % grid_cols
                                next_row = current_row + 1
                                new_index = next_row * grid_cols + current_col
                                if new_index >= len(current_items):
                                    # 아래로 갈 수 없으면 같은 열의 첫 번째 줄로
                                    new_index = current_col
                                    if new_index >= len(current_items):
                                        new_index = current_index  # 변경 없음
                            elif event.key == pygame.K_UP:
                                # 위: 그리드 기반 이동 또는 탭으로 복귀
                                grid_cols = 8
                                current_row = current_index // grid_cols
                                current_col = current_index % grid_cols
                                if current_row == 0:
                                    # 첫 번째 줄에서 위로 가면 탭 선택 모드로 복귀
                                    in_tab_selection = True
                                    selected_active_item = -1
                                    selected_passive_item = -1
                                    continue
                                else:
                                    # 위 줄로 이동
                                    prev_row = current_row - 1
                                    new_index = prev_row * grid_cols + current_col
                                    if new_index >= len(current_items):
                                        # 해당 위치에 아이템이 없으면 그 줄의 마지막 아이템으로
                                        new_index = len(current_items) - 1
                            # 새 인덱스 적용
                            if selected_category == 0:
                                selected_active_item = new_index
                            else:
                                selected_passive_item = new_index
                    if event.key == pygame.K_TAB:
                        # Tab 키로 필드 복귀
                        return
                    elif event.key == pygame.K_SPACE:
                        if selected_category == 0 and active_item_slot and selected_active_item >= 0:
                            show_item_management_menu(active_item_slot, selected_active_item, "active")
                        elif selected_category == 1 and passive_item_list and selected_passive_item >= 0:
                            show_item_management_menu(passive_item_list, selected_passive_item, "passive")
            if event.type == pygame.MOUSEBUTTONDOWN:
                mouse_pos = pygame.mouse.get_pos()
                if current_page == 0:
                    # 다음 페이지 버튼 클릭
                    next_button_rect = pygame.Rect(info_panel_x + info_panel_width - 130, info_panel_y + info_panel_height - 50, 100, 35)
                    if next_button_rect.collidepoint(mouse_pos):
                        current_page = 1
def get_item_name_korean(item_name):
    """아이템 이름을 한글로 변환"""
    # 무중력벨트 + 스피드기어 시너지 효과 확인
    if item_name == "gravitybelt" and gravity_speed_synergy:
        return "전설의벨트"
    korean_names = {
        "long_boost": "거대화포션",
        "gauge_charge": "에너지드링크",
        "life_elixir": "생명수",  # 🌈 생명수 추가
        "aipill": "AI 알약",
        "wall": "벽돌",
        "speedboots": "스피드부츠",
        "gravitybelt": "무중력벨트",
        "speedgear": "스피드기어",
        "battery": "배터리",
        "slot_add": "배낭",
        "revival": "부활",
        "master": "장인의 망치",
        "cooltime": "쿨링볼",
        "chargebag": "충전가방",
        "spikeboots": "스파이크부츠",
        "dashgear": "대쉬기어",
        "bulkup": "벌크업",
        "sensor": "위험감지센서",
        "dashholder": "대쉬홀더",
        "molotov": "화염병",
        "grenade": "수류탄",
        "flare": "조명탄",
        "predictor": "레이저스코프",
        "smoke_grenade": "연막탄"
    }
    return korean_names.get(item_name, item_name)
def get_item_description(item_name):
    """아이템 설명 반환"""
    # 무중력벨트 + 스피드기어 시너지 효과 확인
    if item_name == "gravitybelt" and gravity_speed_synergy:
        return "전설의벨트: 무중력벨트와 스피드기어의 시너지로 패들 크기가 60% 증가하고 별가루 파티클이 생성됩니다!"
    descriptions = {
        "long_boost": "거대화포션: 6초 동안 패들 크기가 1.5배로 증가합니다. (점진적 크기 변화)",
        "gauge_charge": "에너지드링크: 특수 게이지를 220만큼 충전합니다.",
        "life_elixir": "생명수: 특수 게이지를 500만큼 충전합니다. 무지개빛 신비한 물약입니다.",  # 🌈 생명수 추가
        "aipill": "AI 알약: 모든 방향에서 공을 반사하고, 공이 맞을 때마다 게이지가 감소합니다.",
        "wall": "벽돌: 패들 앞에 방어용 벽돌을 설치합니다.",
        "speedboots": "스피드부츠: 영구적으로 이동 속도가 15% 증가합니다.",
        "gravitybelt": "무중력벨트: 이동 시 감속이 없고 즉각적인 방향 전환이 가능합니다. 좌우 키를 누르면 0.1초 딜레이 없이 바로바로 이동할 수 있습니다.",
        "speedgear": "스피드기어: 영구적으로 방향 전환 속도가 증가합니다.",
        "battery": "배터리: 다음 스테이지로 넘어가도 게이지가 유지됩니다.",
        "slot_add": "배낭: 엑티브 아이템 슬롯이 1개 증가합니다.",
        "revival": "부활: 패배 시 한 번 기회를 제공합니다.",
        "master": "장인의 망치: 벽돌 길이 30% 증가, 제작 쿨타임 0.8초, 아이템 쿨타임 10% 감소.",
        "cooltime": "쿨링볼: 아이템 재사용 쿨타임이 30% 감소합니다.",
        "chargebag": "충전가방: 공이 벽에 닿을 때마다 기본 게이지 충전량의 20%를 얻습니다.",
        "spikeboots": "스파이크부츠: 대쉬 후 제어불능 시간이 15% 감소하고 쿨타임이 20% 감소합니다.",
        "dashgear": "대쉬기어: 대쉬 거리가 10% 증가하고 게이지 소모가 20% 감소합니다.",
        "bulkup": "벌크업: 플레이어 패들의 크기가 영구적으로 10% 증가합니다.",
        "sensor": "위험감지센서: 때때로 위험한 상황에 직면하면 자동으로 대쉬를 시전합니다.",
        "dashholder": "대쉬홀더: 대쉬토큰 1개를 추가로 얻습니다.",
        "molotov": "화염병: 보스 패들 뒤쪽에 폭발하여 3초간 화염 지대를 생성하고, 0.15초마다 보스를 밀어냅니다.",
        "grenade": "수류탄: 보스 패들 근처에 폭발하여 보스를 밀어내고 공속을 증가시킵니다.",
        "flare": "조명탄: 상대 진영에 도착 후 1.5초 뒤 폭발하여 2초간 보스를 혼란 상태로 만듭니다.",
        "predictor": "레이저스코프: 10초간 공의 궤적을 예측하여 표시합니다.",
        "smoke_grenade": "연막탄: 포물선으로 투척하여 플레이어 근처에 연막을 생성합니다. 연막 속 공은 속도가 50% 감소합니다."
    }
    return descriptions.get(item_name, "설명이 없습니다.")
def show_item_management_menu(item_list, selected_index, item_type):
    """아이템 관리 메뉴 (버리기/취소)"""
    global active_item_slot, passive_item_list, selected_item_index, selected_passive_item, speedboots_obtained, speedgear_obtained, battery_obtained, revival_obtained, master_obtained, cooltime_obtained
    global chargebag_obtained, spikeboots_obtained, dashgear_obtained, rolling_charges, sensor_enabled, sensor_obtained
    global items
    if not item_list or selected_index >= len(item_list):
        return
    font_large = pygame.font.Font("NanumSquareB.ttf", 32)
    font_medium = pygame.font.Font("NanumSquareR.ttf", 28)
    button_width = 150
    button_height = 50
    button_spacing = 30
    center_x = WIDTH // 2
    start_y = HEIGHT // 2 + 50
    # 위험감지센서인지 확인
    is_sensor_item = item_list[selected_index]["name"] == "sensor"
    if is_sensor_item:
        # 위험감지센서일 때: 버리기, 센서 ON/OFF, 취소 (3개 버튼)
        discard_rect = pygame.Rect(center_x - button_width - button_spacing, start_y, button_width, button_height)
        sensor_rect = pygame.Rect(center_x, start_y, button_width, button_height)
        cancel_rect = pygame.Rect(center_x + button_width + button_spacing, start_y, button_width, button_height)
        selected = 1  # 0: 버리기, 1: 센서 ON/OFF, 2: 취소 (기본값은 센서 ON/OFF)
    else:
        # 일반 아이템일 때: 버리기, 취소 (2개 버튼)
        discard_rect = pygame.Rect(center_x - button_width - button_spacing // 2, start_y, button_width, button_height)
        cancel_rect = pygame.Rect(center_x + button_spacing // 2, start_y, button_width, button_height)
        selected = 1  # 0: 버리기, 1: 취소 (기본값은 취소)
    while True:
        # 현재 게임 화면을 배경으로 사용
        draw_field()
        draw_shaking_screen()
        draw_objects()
        draw_water_trail()
        # 반투명 오버레이
        overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        SCREEN.blit(overlay, (0, 0))
        # 아이템 정보
        item = item_list[selected_index]
        item_name = item["name"]
        # 아이템 정보 패널
        panel_width = 400
        panel_height = 200
        panel_x = center_x - panel_width // 2
        panel_y = start_y - 200
        draw.rect((30, 30, 50), (panel_x, panel_y, panel_width, panel_height))
        draw.rect((100, 150, 255), (panel_x, panel_y, panel_width, panel_height), 3)
        # 아이템 아이콘
        if item.get("icon"):
            icon = pygame.transform.scale(item["icon"], (60, 60))
            SCREEN.blit(icon, (panel_x + 20, panel_y + 20))
        # 아이템 이름
        name_text = font_large.render(item_name, True, WHITE)
        name_rect = name_text.get_rect(left=panel_x + 100, top=panel_y + 20)
        SCREEN.blit(name_text, name_rect)
        # 아이템 설명
        description = get_item_description(item_name)
        desc_lines = description.split(': ')
        if len(desc_lines) > 1:
            effect_text = font_medium.render(desc_lines[1], True, (200, 200, 200))
            effect_rect = effect_text.get_rect(left=panel_x + 100, top=panel_y + 60)
            SCREEN.blit(effect_text, effect_rect)
        # 경고 메시지
        warning_text = font_medium.render("이 아이템을 버리시겠습니까?", True, (255, 200, 200))
        warning_rect = warning_text.get_rect(center=(center_x, start_y - 30))
        SCREEN.blit(warning_text, warning_rect)
        # 버튼들 그리기
        if is_sensor_item:
            buttons = [discard_rect, sensor_rect, cancel_rect]
            button_texts = ["버리기", "센서 OFF" if sensor_enabled else "센서 ON", "취소"]
        else:
            buttons = [discard_rect, cancel_rect]
            button_texts = ["버리기", "취소"]
        for i, (rect, text) in enumerate(zip(buttons, button_texts)):
            if i == selected:
                # 선택된 버튼
                draw.rect((255, 100, 100) if i == 0 else (100, 150, 255), rect)
                draw.rect(WHITE, rect, 3)
                text_color = BLACK
            else:
                # 선택되지 않은 버튼
                draw.rect((50, 50, 50), rect)
                draw.rect((150, 150, 150), rect, 2)
                text_color = WHITE
            text_surface = font_medium.render(text, True, text_color)
            text_rect = text_surface.get_rect(center=rect.center)
            SCREEN.blit(text_surface, text_rect)
        pygame.display.flip()
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return
                elif event.key == pygame.K_LEFT:
                    if is_sensor_item:
                        selected = (selected - 1) % 3
                    else:
                        selected = 0
                elif event.key == pygame.K_RIGHT:
                    if is_sensor_item:
                        selected = (selected + 1) % 3
                    else:
                        selected = 1
                elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                    if selected == 0:  # 버리기
                        # 아이템 제거
                        removed_item = item_list.pop(selected_index)
                        # 아이템 타입에 따른 효과 제거
                        if item_type == "active":
                            # 엑티브 아이템 제거 시 선택 인덱스 조정
                            if selected_item_index >= len(active_item_slot):
                                selected_item_index = max(0, len(active_item_slot) - 1)
                        else:  # passive
                            # 패시브 아이템 제거 시 선택 인덱스 조정
                            if selected_passive_item >= len(passive_item_list):
                                selected_passive_item = max(0, len(passive_item_list) - 1)
                            # 패시브 아이템 효과 제거 매핑
                            passive_removal = {
                                "speedboots": ("speedboots_obtained", False),
                                "speedgear": ("speedgear_obtained", False),
                                "battery": ("battery_obtained", False),
                                "revival": ("revival_obtained", False),
                                "master": ("master_obtained", False),
                                "cooltime": ("cooltime_obtained", False),
                                "chargebag": ("chargebag_obtained", False),
                                "spikeboots": ("spikeboots_obtained", False),
                                "dashgear": ("dashgear_obtained", False)
                            }
                            
                            if removed_item["name"] in passive_removal:
                                var_name, value = passive_removal[removed_item["name"]]
                                globals()[var_name] = value
                                setattr(items, var_name, value)
                            elif removed_item["name"] == "rolling":
                                items.rolling_obtained = False
                            elif removed_item["name"] == "sensor":
                                sensor_obtained = False
                                sensor_enabled = True  # 초기화
                                items.sensor_obtained = False
                        # 아이템 이름을 한글로 표시
                        item_name_korean = get_item_name_korean(removed_item['name'])
                        print(f"{item_name_korean} 아이템을 버렸습니다.")
                        return
                    elif is_sensor_item and selected == 1:  # 센서 ON/OFF
                        status_text = "ON" if sensor_enabled else "OFF"
                        print(f"위험감지센서가 {status_text} 상태로 변경되었습니다.")
                        return
                    else:  # 취소
                        return
            if event.type == pygame.MOUSEBUTTONDOWN:
                mouse_pos = pygame.mouse.get_pos()
                for i, rect in enumerate(buttons):
                    if rect.collidepoint(mouse_pos):
                        if i == 0:  # 버리기
                            # 아이템 제거
                            removed_item = item_list.pop(selected_index)
                            # 아이템 타입에 따른 효과 제거
                            if item_type == "active":
                                # 엑티브 아이템 제거 시 선택 인덱스 조정
                                if selected_item_index >= len(active_item_slot):
                                    selected_item_index = max(0, len(active_item_slot) - 1)
                            else:  # passive
                                # 패시브 아이템 제거 시 선택 인덱스 조정
                                if selected_passive_item >= len(passive_item_list):
                                    selected_passive_item = max(0, len(passive_item_list) - 1)
                                # 패시브 아이템 효과 제거
                                if removed_item["name"] == "speedboots":
                                    speedboots_obtained = False
                                    items.speedboots_obtained = False
                                elif removed_item["name"] == "speedgear":
                                    speedgear_obtained = False
                                    items.speedgear_obtained = False
                                elif removed_item["name"] == "battery":
                                    battery_obtained = False
                                    items.battery_obtained = False
                                elif removed_item["name"] == "revival":
                                    revival_obtained = False
                                    items.revival_obtained = False
                                elif removed_item["name"] == "master":
                                    master_obtained = False
                                    items.master_obtained = False
                                elif removed_item["name"] == "cooltime":
                                    cooltime_obtained = False
                                    items.cooltime_obtained = False
                                elif removed_item["name"] == "rolling":
                                    items.rolling_obtained = False
                                elif removed_item["name"] == "chargebag":
                                    chargebag_obtained = False
                                    items.chargebag_obtained = False
                                elif removed_item["name"] == "spikeboots":
                                    spikeboots_obtained = False
                                    items.spikeboots_obtained = False
                                elif removed_item["name"] == "dashgear":
                                    dashgear_obtained = False
                                    items.dashgear_obtained = False
                                elif removed_item["name"] == "sensor":
                                    danger_sensor_obtained = False  # 🆕 메인 변수 초기화
                                    sensor_obtained = False
                                    danger_sensor_enabled = True  # 🆕 메인 변수 초기화  
                                    items.sensor_obtained = False
                                elif removed_item["name"] == "gravitybelt":
                                    gravitybelt_obtained = False
                                    items.gravitybelt_obtained = False
                                elif removed_item["name"] == "gravitybelt":
                                    gravitybelt_obtained = False
                                    items.gravitybelt_obtained = False
                            # 아이템 이름을 한글로 표시
                            item_name_korean = get_item_name_korean(removed_item['name'])
                            print(f"{item_name_korean} 아이템을 버렸습니다.")
                            return
                        elif is_sensor_item and i == 1:  # 센서 ON/OFF
                            danger_sensor_enabled = not danger_sensor_enabled  # 🆕 메인 변수 토글
                            status_text = "ON" if danger_sensor_enabled else "OFF"
                            print(f"위험감지센서가 {status_text} 상태로 변경되었습니다.")
                            return
                        else:  # 취소
                            return
def show_surrender_confirm():
    """기권 확인 메뉴"""
    font_large = pygame.font.Font("NanumSquareB.ttf", 32)
    font_medium = pygame.font.Font("NanumSquareR.ttf", 28)
    button_width = 200
    button_height = 50
    button_spacing = 30
    center_x = WIDTH // 2
    start_y = HEIGHT // 2 + 50
    yes_rect = pygame.Rect(center_x - button_width - button_spacing // 2, start_y, button_width, button_height)
    no_rect = pygame.Rect(center_x + button_spacing // 2, start_y, button_width, button_height)
    selected = 0  # 0: 예, 1: 아니오 (기본값은 예)
    while True:
        # 현재 게임 화면을 배경으로 사용
        draw_field()
        draw_shaking_screen()
        draw_objects()
        draw_water_trail()
        # 반투명 오버레이
        overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 180))
        SCREEN.blit(overlay, (0, 0))
        # 기권 메시지
        message_text = font_large.render("기권하시겠습니까?", True, WHITE)
        message_rect = message_text.get_rect(center=(center_x, start_y - 80))
        SCREEN.blit(message_text, message_rect)
        warning_text = font_medium.render(f"획득한 메달의 50%만 받을 수 있습니다", True, (255, 200, 200))
        warning_rect = warning_text.get_rect(center=(center_x, start_y - 40))
        SCREEN.blit(warning_text, warning_rect)
        # 버튼들 그리기
        buttons = [yes_rect, no_rect]
        button_texts = ["예", "아니오"]
        for i, (rect, text) in enumerate(zip(buttons, button_texts)):
            if i == selected:
                # 선택된 버튼
                draw.rect((255, 100, 100) if i == 0 else (100, 150, 255), rect)
                draw.rect(WHITE, rect, 3)
                text_color = BLACK
            else:
                # 선택되지 않은 버튼
                draw.rect((50, 50, 50), rect)
                draw.rect((150, 150, 150), rect, 2)
                text_color = WHITE
            text_surface = font_medium.render(text, True, text_color)
            text_rect = text_surface.get_rect(center=rect.center)
            SCREEN.blit(text_surface, text_rect)
        pygame.display.flip()
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return False
                elif event.key == pygame.K_LEFT:
                    selected = 0
                elif event.key == pygame.K_RIGHT:
                    selected = 1
                elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                    return selected == 0  # 예를 선택했으면 True
            if event.type == pygame.MOUSEBUTTONDOWN:
                mouse_pos = pygame.mouse.get_pos()
                for i, rect in enumerate(buttons):
                    if rect.collidepoint(mouse_pos):
                        return i == 0  # 예를 선택했으면 True
if __name__ == "__main__":
    # 무조건 오프닝 애니메이션 표시
    opening.show_opening_animation(SCREEN, WIDTH, HEIGHT)
    game_loop()