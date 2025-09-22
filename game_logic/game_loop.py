"""
게임 루프 매니저 - 메인 게임 루프를 관리하는 통합 시스템
점진적 리팩토링을 위한 게임 루프 분리
"""
from __future__ import annotations

import pygame
import time
from dataclasses import dataclass
from typing import Callable, Dict, Any, Optional, Tuple

from core.game_variables import get_game_vars


@dataclass
class RuntimeAdapters:
    """외부 시스템과의 연동을 위한 어댑터 모음."""

    update_player_input: Optional[Callable[["GameState", "InputHandler"], None]] = None
    update_ai: Optional[Callable[["GameState", float], None]] = None
    update_physics: Optional[Callable[["GameState", float], None]] = None
    check_collisions: Optional[Callable[["GameState"], None]] = None
    update_items: Optional[Callable[["GameState", float], None]] = None

class GameLoop:
    """게임 루프를 관리하는 메인 클래스"""
    
    def __init__(self, screen: pygame.Surface, adapters: Optional[RuntimeAdapters] = None):
        """게임 루프 초기화
        
        Args:
            screen: 메인 화면 Surface
        """
        self.screen = screen
        self.clock = pygame.time.Clock()
        self.running = False
        self.paused = False
        
        # 상태 관리
        self.state = GameState()
        
        # 입력 처리
        self.input_handler = InputHandler()
        
        # 업데이트 시스템
        self.update_system = UpdateSystem(adapters)

        # 렌더링 시스템 (render_manager 사용)
        from rendering.render_manager import RenderManager
        self.render_manager = RenderManager(screen)
        
        # 프레임 관리
        self.target_fps = 60
        self.delta_time = 0
        self.frame_count = 0
        self.last_time = time.time()
        
    def run(self, initial_state: Dict[str, Any] = None):
        """게임 루프 실행
        
        Args:
            initial_state: 초기 상태 설정
        """
        if initial_state:
            self.state.update(initial_state)
            
        self.running = True
        self._game_loop()
    
    def _game_loop(self):
        """실제 게임 루프"""
        while self.running:
            # 델타 타임 계산
            current_time = time.time()
            self.delta_time = current_time - self.last_time
            self.last_time = current_time
            
            # 이벤트 처리
            self._handle_events()
            
            # 일시정지 상태가 아닐 때만 업데이트
            if not self.paused:
                self._update()
            
            # 렌더링은 항상
            self._render()
            
            # 프레임 레이트 제한
            self.clock.tick(self.target_fps)
            self.frame_count += 1
    
    def _handle_events(self):
        """이벤트 처리"""
        events = pygame.event.get()
        for event in events:
            if event.type == pygame.QUIT:
                self.running = False
                
            # 입력 처리기로 전달
            self.input_handler.handle_event(event)
            
            # 일시정지 토글
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    self.toggle_pause()
                    
        # 키 상태 업데이트
        keys = pygame.key.get_pressed()
        self.input_handler.update_keys(keys)
    
    def _update(self):
        """게임 상태 업데이트"""
        # 업데이트 시스템 실행
        self.update_system.update(
            self.state,
            self.input_handler,
            self.delta_time
        )
    
    def _render(self):
        """렌더링"""
        # 게임 상태를 렌더 매니저에 전달
        game_state_dict = self.state.to_dict()
        self.render_manager.render_frame(game_state_dict)
        
        # 화면 갱신
        pygame.display.flip()
    
    def toggle_pause(self):
        """일시정지 토글"""
        self.paused = not self.paused
        
    def stop(self):
        """게임 루프 중지"""
        self.running = False

class GameState:
    """게임 상태 관리 클래스"""
    
    def __init__(self):
        """상태 초기화"""
        # 기본 상태
        self.stage = 1
        self.score = {'player': 0, 'boss': 0}
        self.round_wins = 0
        self.round_losses = 0
        
        # 객체 상태
        self.player = PlayerState()
        self.boss = BossState()
        self.ball = BallState()
        
        # 게임 플래그
        self.is_waiting_for_serve = True
        self.game_over = False
        self.victory = False
        
        # 타이머
        self.timer = 0
        self.frame_count = 0
        
        # 아이템
        self.items = []
        self.active_powerups = {}
        
        # 이펙트
        self.effects = []
        
        # UI
        self.messages = []
        self.combo = {'count': 0, 'multiplier': 1.0}
        
    def update(self, data: Dict[str, Any]):
        """상태 업데이트
        
        Args:
            data: 업데이트할 데이터
        """
        for key, value in data.items():
            if hasattr(self, key):
                setattr(self, key, value)
    
    def to_dict(self) -> Dict[str, Any]:
        """딕셔너리로 변환"""
        return {
            'stage': self.stage,
            'score': self.score,
            'player': self.player.to_dict(),
            'boss': self.boss.to_dict(),
            'ball': self.ball.to_dict(),
            'items': self.items,
            'active_powerups': self.active_powerups,
            'combo': self.combo,
            'timer': self.timer,
            'message': self.messages[0] if self.messages else None
        }

class PlayerState:
    """플레이어 상태"""
    
    def __init__(self):
        self.rect = pygame.Rect(250, 650, 100, 20)
        self.color = (0, 255, 0)
        self.speed = 10
        self.is_dashing = False
        self.is_charging = False
        self.charge_level = 0.0
        self.power_ups = {}
        
    def to_dict(self) -> Dict[str, Any]:
        """딕셔너리로 변환"""
        return {
            'rect': self.rect,
            'color': self.color,
            'is_dashing': self.is_dashing,
            'is_charging': self.is_charging,
            'charge_level': self.charge_level,
            'power_ups': self.power_ups
        }

class BossState:
    """보스 상태"""
    
    def __init__(self):
        self.rect = pygame.Rect(250, 50, 100, 20)
        self.color = (255, 0, 0)
        self.speed = 5
        self.stage = 1
        self.is_rage = False
        self.special_attack = None
        self.ai_level = 1
        
    def to_dict(self) -> Dict[str, Any]:
        """딕셔너리로 변환"""
        return {
            'rect': self.rect,
            'color': self.color,
            'stage': self.stage,
            'is_rage': self.is_rage,
            'special_attack': self.special_attack
        }

class BallState:
    """공 상태"""
    
    def __init__(self):
        self.pos = [300, 375]
        self.velocity = [0, 5]
        self.radius = 10
        self.color = (255, 255, 255)
        self.power_shot = False
        self.curve_ball = False
        self.ghost_ball = False
        self.speed_multiplier = 1.0
        
    def to_dict(self) -> Dict[str, Any]:
        """딕셔너리로 변환"""
        return {
            'pos': self.pos,
            'velocity': self.velocity,
            'radius': self.radius,
            'color': self.color,
            'power_shot': self.power_shot,
            'curve_ball': self.curve_ball,
            'ghost_ball': self.ghost_ball
        }

class InputHandler:
    """입력 처리 클래스"""
    
    def __init__(self):
        """입력 처리기 초기화"""
        self.keys = {}
        self.keys_just_pressed = set()
        self.keys_just_released = set()
        self.mouse_pos = (0, 0)
        self.mouse_buttons = [False, False, False]
        self.mouse_just_clicked = [False, False, False]
        
    def handle_event(self, event: pygame.event.Event):
        """이벤트 처리
        
        Args:
            event: pygame 이벤트
        """
        if event.type == pygame.KEYDOWN:
            self.keys_just_pressed.add(event.key)
            
        elif event.type == pygame.KEYUP:
            self.keys_just_released.add(event.key)
            
        elif event.type == pygame.MOUSEMOTION:
            self.mouse_pos = event.pos
            
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button <= 3:
                self.mouse_buttons[event.button - 1] = True
                self.mouse_just_clicked[event.button - 1] = True
                
        elif event.type == pygame.MOUSEBUTTONUP:
            if event.button <= 3:
                self.mouse_buttons[event.button - 1] = False
    
    def update_keys(self, keys):
        """키 상태 업데이트
        
        Args:
            keys: pygame.key.get_pressed() 결과
        """
        self.keys = keys
        # 프레임 종료 시 just_pressed/released 초기화
        self.keys_just_pressed.clear()
        self.keys_just_released.clear()
        self.mouse_just_clicked = [False, False, False]
    
    def is_key_pressed(self, key: int) -> bool:
        """키가 눌려있는지 확인"""
        return self.keys.get(key, False)
    
    def is_key_just_pressed(self, key: int) -> bool:
        """키가 방금 눌렸는지 확인"""
        return key in self.keys_just_pressed
    
    def is_key_just_released(self, key: int) -> bool:
        """키가 방금 떼어졌는지 확인"""
        return key in self.keys_just_released

class UpdateSystem:
    """업데이트 시스템"""
    
    def __init__(self, adapters: Optional[RuntimeAdapters] = None):
        """업데이트 시스템 초기화"""
        self.adapters = adapters or RuntimeAdapters()
        self.physics = PhysicsSystem()
        self.collision = CollisionSystem()
        self.item_manager = ItemManager()
        self.ai_manager = AIManager()
        
    def update(self, state: GameState, input_handler: InputHandler, delta_time: float):
        """전체 업데이트
        
        Args:
            state: 게임 상태
            input_handler: 입력 처리기
            delta_time: 프레임 시간
        """
        _sync_state_from_game_vars(state)

        # 플레이어 입력 처리
        if self.adapters.update_player_input is not None:
            self.adapters.update_player_input(state, input_handler)
        else:
            self._update_player_input_default(state, input_handler)

        # AI 업데이트
        if self.adapters.update_ai is not None:
            self.adapters.update_ai(state, delta_time)
        else:
            self.ai_manager.update(state, delta_time)

        # 물리 업데이트
        if self.adapters.update_physics is not None:
            self.adapters.update_physics(state, delta_time)
        else:
            self.physics.update(state, delta_time)

        # 충돌 검사
        if self.adapters.check_collisions is not None:
            self.adapters.check_collisions(state)
        else:
            self.collision.check_collisions(state)

        # 아이템 업데이트
        if self.adapters.update_items is not None:
            self.adapters.update_items(state, delta_time)
        else:
            self.item_manager.update(state, delta_time)

        # 타이머 업데이트
        state.frame_count += 1
        if state.frame_count % 60 == 0:
            state.timer += 1

        _sync_game_vars_from_state(state)
    
    def _update_player_input_default(self, state: GameState, input_handler: InputHandler):
        """플레이어 입력 처리"""
        # 마우스로 패들 이동
        state.player.rect.centerx = input_handler.mouse_pos[0]
        
        # 패들 경계 체크
        if state.player.rect.left < 0:
            state.player.rect.left = 0
        elif state.player.rect.right > 600:
            state.player.rect.right = 600
        
        # 스페이스바로 서브
        if input_handler.is_key_just_pressed(pygame.K_SPACE):
            if state.is_waiting_for_serve:
                state.is_waiting_for_serve = False
                state.ball.velocity = [5, 5]
        
        # Shift로 대시
        if input_handler.is_key_pressed(pygame.K_LSHIFT):
            state.player.is_dashing = True
        else:
            state.player.is_dashing = False

class PhysicsSystem:
    """물리 시스템"""
    
    def update(self, state: GameState, delta_time: float):
        """물리 업데이트"""
        if state.is_waiting_for_serve:
            # 서브 대기 중이면 공을 플레이어 패들 위에 고정
            state.ball.pos[0] = state.player.rect.centerx
            state.ball.pos[1] = state.player.rect.top - 20
        else:
            # 공 움직임
            state.ball.pos[0] += state.ball.velocity[0] * state.ball.speed_multiplier
            state.ball.pos[1] += state.ball.velocity[1] * state.ball.speed_multiplier
            
            # 벽 충돌
            if state.ball.pos[0] <= state.ball.radius:
                state.ball.pos[0] = state.ball.radius
                state.ball.velocity[0] *= -1
                
            if state.ball.pos[0] >= 600 - state.ball.radius:
                state.ball.pos[0] = 600 - state.ball.radius
                state.ball.velocity[0] *= -1

class CollisionSystem:
    """충돌 시스템"""
    
    def check_collisions(self, state: GameState):
        """충돌 검사"""
        ball_rect = pygame.Rect(
            state.ball.pos[0] - state.ball.radius,
            state.ball.pos[1] - state.ball.radius,
            state.ball.radius * 2,
            state.ball.radius * 2
        )
        
        # 플레이어 패들 충돌
        if ball_rect.colliderect(state.player.rect):
            if state.ball.velocity[1] > 0:  # 아래로 가는 중일 때만
                state.ball.velocity[1] = -abs(state.ball.velocity[1])
                state.combo['count'] += 1
                state.combo['multiplier'] = 1.0 + (state.combo['count'] * 0.1)
                
                # 히트 위치에 따른 각도 변경
                hit_pos = (state.ball.pos[0] - state.player.rect.centerx) / (state.player.rect.width / 2)
                state.ball.velocity[0] = hit_pos * 8
        
        # 보스 패들 충돌
        if ball_rect.colliderect(state.boss.rect):
            if state.ball.velocity[1] < 0:  # 위로 가는 중일 때만
                state.ball.velocity[1] = abs(state.ball.velocity[1])
        
        # 골 체크
        if state.ball.pos[1] < 0:
            # 보스 골
            state.score['player'] += 1
            state.is_waiting_for_serve = True
            state.combo['count'] = 0
            state.combo['multiplier'] = 1.0
            
        elif state.ball.pos[1] > 750:
            # 플레이어 골
            state.score['boss'] += 1
            state.is_waiting_for_serve = True
            state.combo['count'] = 0
            state.combo['multiplier'] = 1.0

class ItemManager:
    """아이템 관리자"""
    
    def update(self, state: GameState, delta_time: float):
        """아이템 업데이트"""
        # 아이템 스폰 (랜덤)
        import random
        if state.frame_count % 300 == 0:  # 5초마다
            if len(state.items) < 3:
                state.items.append({
                    'pos': [random.randint(50, 550), random.randint(200, 500)],
                    'size': 20,
                    'color': (255, 255, 0),
                    'type': 'speed_up',
                    'duration': 300  # 5초간 유지
                })
        
        # 아이템 지속시간 업데이트
        for item in state.items[:]:
            item['duration'] -= 1
            if item['duration'] <= 0:
                state.items.remove(item)
        
        # 아이템 충돌 체크
        ball_rect = pygame.Rect(
            state.ball.pos[0] - state.ball.radius,
            state.ball.pos[1] - state.ball.radius,
            state.ball.radius * 2,
            state.ball.radius * 2
        )
        
        for item in state.items[:]:
            item_rect = pygame.Rect(
                item['pos'][0] - item['size'],
                item['pos'][1] - item['size'],
                item['size'] * 2,
                item['size'] * 2
            )
            if ball_rect.colliderect(item_rect):
                # 아이템 효과 적용
                if item['type'] == 'speed_up':
                    state.ball.speed_multiplier = 1.5
                    state.active_powerups['speed_up'] = 300  # 5초간 지속
                state.items.remove(item)
        
        # 파워업 지속시간 업데이트
        for powerup, duration in list(state.active_powerups.items()):
            state.active_powerups[powerup] = duration - 1
            if state.active_powerups[powerup] <= 0:
                # 파워업 종료
                if powerup == 'speed_up':
                    state.ball.speed_multiplier = 1.0
                del state.active_powerups[powerup]

class AIManager:
    """AI 관리자"""
    
    def update(self, state: GameState, delta_time: float):
        """AI 업데이트"""
        # 간단한 보스 AI
        target_x = state.ball.pos[0]
        boss_x = state.boss.rect.centerx
        
        # 난이도에 따른 속도 조절
        speed = state.boss.speed * state.boss.ai_level
        
        # 패들 이동
        if abs(target_x - boss_x) > 5:
            if target_x > boss_x:
                state.boss.rect.x += min(speed, target_x - boss_x)
            else:
                state.boss.rect.x -= min(speed, boss_x - target_x)
        
        # 경계 체크
        if state.boss.rect.left < 0:
            state.boss.rect.left = 0
        elif state.boss.rect.right > 600:
            state.boss.rect.right = 600
        
        # 스테이지별 특수 패턴
        if state.boss.stage >= 3:
            # 스테이지 3 이상에서는 예측 AI 사용
            if state.ball.velocity[1] < 0:  # 공이 위로 올라갈 때
                # 공의 도착 지점 예측
                time_to_reach = (state.boss.rect.centery - state.ball.pos[1]) / abs(state.ball.velocity[1])
                predicted_x = state.ball.pos[0] + state.ball.velocity[0] * time_to_reach
                
                # 벽 반사 고려
                if predicted_x < 0 or predicted_x > 600:
                    predicted_x = 600 - abs(predicted_x) if predicted_x > 600 else abs(predicted_x)
                
                target_x = predicted_x


def _sync_state_from_game_vars(state: GameState) -> None:
    """core.game_variables와 GameState를 동기화."""
    try:
        game_vars = get_game_vars()
    except Exception:
        return

    try:
        player_rect = game_vars.player.rect
        boss_rect = game_vars.boss.rect
        ball_rect = game_vars.ball.rect
        ball_vel = game_vars.ball.vel
    except AttributeError:
        return

    state.player.rect = player_rect.copy()
    state.player.speed = getattr(game_vars.player, "speed", state.player.speed)

    state.boss.rect = boss_rect.copy()
    state.boss.speed = getattr(game_vars.boss, "speed", state.boss.speed)

    state.ball.pos = [float(ball_rect.centerx), float(ball_rect.centery)]
    if len(ball_vel) >= 2:
        state.ball.velocity = [float(ball_vel[0]), float(ball_vel[1])]
    state.ball.radius = getattr(game_vars.ball, "radius", state.ball.radius)


def _sync_game_vars_from_state(state: GameState) -> None:
    """GameState 변화 내용을 core.game_variables에 반영."""
    try:
        game_vars = get_game_vars()
    except Exception:
        return

    try:
        player_rect = game_vars.player.rect
        boss_rect = game_vars.boss.rect
        ball_rect = game_vars.ball.rect
        ball_vel = game_vars.ball.vel
    except AttributeError:
        return

    player_rect.x = state.player.rect.x
    player_rect.y = state.player.rect.y
    player_rect.width = state.player.rect.width
    player_rect.height = state.player.rect.height
    if hasattr(game_vars.player, "speed"):
        game_vars.player.speed = state.player.speed

    boss_rect.x = state.boss.rect.x
    boss_rect.y = state.boss.rect.y
    boss_rect.width = state.boss.rect.width
    boss_rect.height = state.boss.rect.height
    if hasattr(game_vars.boss, "speed"):
        game_vars.boss.speed = state.boss.speed

    ball_rect.centerx = int(state.ball.pos[0])
    ball_rect.centery = int(state.ball.pos[1])
    if len(ball_vel) >= 2:
        ball_vel[0] = float(state.ball.velocity[0])
        ball_vel[1] = float(state.ball.velocity[1])
    if hasattr(game_vars.ball, "radius"):
        game_vars.ball.radius = int(state.ball.radius)


def _game_vars_update_player_input(state: GameState, input_handler: InputHandler) -> None:
    """game_vars와 연동되는 입력 업데이트 어댑터."""
    # 마우스로 패들 이동
    state.player.rect.centerx = input_handler.mouse_pos[0]

    # 패들 경계 체크
    if state.player.rect.left < 0:
        state.player.rect.left = 0
    elif state.player.rect.right > 600:
        state.player.rect.right = 600

    # 스페이스바로 서브
    if input_handler.is_key_just_pressed(pygame.K_SPACE):
        if state.is_waiting_for_serve:
            state.is_waiting_for_serve = False
            state.ball.velocity = [5, 5]

    # Shift로 대시
    state.player.is_dashing = input_handler.is_key_pressed(pygame.K_LSHIFT)

    _sync_game_vars_from_state(state)


def create_game_vars_adapters() -> RuntimeAdapters:
    """core.game_variables와 동기화되는 RuntimeAdapters 생성."""
    return RuntimeAdapters(update_player_input=_game_vars_update_player_input)
