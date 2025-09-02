"""
게임 전역 변수 관리 모듈
점진적 리팩토링을 위한 중간 단계
"""
import pygame
from config.constants import *

class BallState:
    """공 관련 상태 관리"""
    def __init__(self):
        self.radius = 22
        self.rect = pygame.Rect(WIDTH // 2 - self.radius // 2, 
                               HEIGHT // 2 - self.radius // 2, 
                               self.radius, self.radius)
        self.vel = [0, 0]
        self.speed_x = 5
        self.speed_y = 8
        self.base_speed = 9
        self.angle = 0
        self.spin_strength = 0.0
        self.spin_direction = 0
        self.impact_boost = 1.0
        self.boost_decay_rate = 0.975
        self.min_boost = 0.7
        self.slow_timer = 0
        self.vertical_bounce_count = 0
        self.last_hit_by = "player"

class PlayerState:
    """플레이어 관련 상태 관리"""
    def __init__(self):
        self.rect = pygame.Rect(WIDTH // 2 - PADDLE_WIDTH // 2, 
                                HEIGHT - 40, 
                                PADDLE_WIDTH, 
                                PADDLE_HEIGHT)
        self.speed = PADDLE_SPEED
        self.color = WHITE

class BossState:
    """보스 관련 상태 관리"""
    def __init__(self):
        self.y_position = 25
        self.rect = pygame.Rect(WIDTH // 2 - 130 // 2, 
                                self.y_position, 
                                130, 40)
        self.speed = 1
        self.color = WHITE
        self.acceleration = 0.798
        self.deceleration = 0.798
        self.names = {
            1: "⚔️ Stage 1: 빛의 기사 세라프",
            2: "🔥 Stage 2: 불꽃 군주 이프리트",
            3: "❄️ Stage 3: 얼음 여왕 프로스티나",
            4: "⚡ Stage 4: 번개 제왕 볼트라",
            5: "🌑 Stage 5: 그림자 지배자 노크티스",
            6: "✨ Final Boss: 시공의 지배자 크로노스"
        }

class InputState:
    """입력 관련 상태 관리"""
    def __init__(self):
        self.left_press_frame = -1
        self.right_press_frame = -1
        self.space_press_frame = -1
        self.frame_counter = 0
        self.last_space_press_time = 0
        self.space_just_pressed = False
        self.last_space_state = False
        self.left_just_pressed = False
        self.last_left_state = False
        self.right_just_pressed = False
        self.last_right_state = False

class GameVariables:
    """모든 게임 변수를 관리하는 클래스"""
    def __init__(self):
        self.ball = BallState()
        self.player = PlayerState()
        self.boss = BossState()
        self.input = InputState()
        
        # 기타 전역 변수들 (점진적으로 정리 예정)
        self.recent_dash_time = 0
        self.recent_dash_success_window = 120
        self.perfect_timing_cooldown = 0
        self.perfect_timing_cooldown_frames = 30
        self.perfect_timing_input_used = False
        self.drive_global_cooldown = 0
        self.drive_global_cooldown_frames = 120

# 싱글톤 인스턴스
_game_vars = None

def get_game_vars():
    """게임 변수 싱글톤 인스턴스 반환"""
    global _game_vars
    if _game_vars is None:
        _game_vars = GameVariables()
    return _game_vars