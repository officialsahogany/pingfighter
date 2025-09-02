# -*- coding: utf-8 -*-
"""
게임 서비스 레이어
비즈니스 로직을 캡슐화하고 컨트롤러와 데이터 레이어를 분리
"""

from typing import Optional, Dict, Any, List
from dataclasses import dataclass
from enum import Enum
from core.dependency_injection import inject
from core.game_state import GameState
from core.event_bus import EventBus, Event, EventPriority, GameEvents
from game_logic.physics_engine import PhysicsEngine
from game_logic.collision_system import CollisionSystem
from repositories.game_repository import GameRepository


class GameAction(Enum):
    """게임 액션 타입"""
    START_GAME = "start_game"
    PAUSE_GAME = "pause_game"
    RESUME_GAME = "resume_game"
    END_GAME = "end_game"
    RESET_ROUND = "reset_round"
    PLAYER_ACTION = "player_action"
    USE_ITEM = "use_item"
    ACTIVATE_SPECIAL = "activate_special"


@dataclass
class GameCommand:
    """게임 명령 DTO"""
    action: GameAction
    data: Dict[str, Any] = None
    timestamp: float = None


class GameService:
    """게임 비즈니스 로직 서비스
    
    모든 게임 로직을 중앙에서 관리하고
    프레젠테이션 레이어와 데이터 레이어를 분리합니다.
    """
    
    def __init__(self, 
                 game_state: GameState = None,
                 event_bus: EventBus = None,
                 physics_engine: PhysicsEngine = None,
                 collision_system: CollisionSystem = None,
                 game_repository: GameRepository = None):
        """서비스 초기화
        
        Args:
            game_state: 게임 상태 관리자
            event_bus: 이벤트 버스
            physics_engine: 물리 엔진
            collision_system: 충돌 시스템
            game_repository: 게임 데이터 리포지토리
        """
        self.game_state = game_state or inject(GameState)
        self.event_bus = event_bus or inject(EventBus)
        self.physics_engine = physics_engine or inject(PhysicsEngine)
        self.collision_system = collision_system or inject(CollisionSystem)
        self.game_repository = game_repository or inject(GameRepository)
        
        self._register_event_handlers()
    
    def _register_event_handlers(self):
        """이벤트 핸들러 등록"""
        self.event_bus.subscribe(GameEvents.PLAYER_HIT, self._handle_player_hit)
        self.event_bus.subscribe(GameEvents.BOSS_HIT, self._handle_boss_hit)
        self.event_bus.subscribe(GameEvents.ITEM_COLLECT, self._handle_item_collect)
    
    # ========== 게임 상태 관리 ==========
    
    def start_game(self, stage: int = 1) -> bool:
        """게임 시작
        
        Args:
            stage: 시작 스테이지
            
        Returns:
            시작 성공 여부
        """
        try:
            # 게임 상태 초기화
            self.game_state.reset_stage()
            self.game_state.current_stage = stage
            self.game_state.game_running = True
            
            # 데이터 로드
            stage_data = self.game_repository.get_stage_data(stage)
            if not stage_data:
                return False
            
            # 물리 엔진 초기화
            self.physics_engine.reset()
            
            # 이벤트 발행
            self.event_bus.publish(Event(
                type=GameEvents.GAME_START,
                data={'stage': stage},
                priority=EventPriority.HIGH
            ))
            
            return True
            
        except Exception as e:
            print(f"게임 시작 오류: {e}")
            return False
    
    def pause_game(self) -> bool:
        """게임 일시정지"""
        if not self.game_state.game_running or self.game_state.game_paused:
            return False
        
        self.game_state.game_paused = True
        self.event_bus.publish(Event(
            type=GameEvents.GAME_PAUSE,
            priority=EventPriority.NORMAL
        ))
        return True
    
    def resume_game(self) -> bool:
        """게임 재개"""
        if not self.game_state.game_paused:
            return False
        
        self.game_state.game_paused = False
        self.event_bus.publish(Event(
            type=GameEvents.GAME_RESUME,
            priority=EventPriority.NORMAL
        ))
        return True
    
    def end_game(self, reason: str = "normal") -> Dict[str, Any]:
        """게임 종료
        
        Args:
            reason: 종료 사유
            
        Returns:
            게임 결과 데이터
        """
        if not self.game_state.game_running:
            return {}
        
        # 게임 결과 수집
        result = {
            'stage': self.game_state.current_stage,
            'score': self.game_state.player_score,
            'medals': self.game_state.medal_score,
            'time_played': self._calculate_play_time(),
            'reason': reason
        }
        
        # 데이터 저장
        self.game_repository.save_game_result(result)
        
        # 상태 정리
        self.game_state.game_running = False
        
        # 이벤트 발행
        self.event_bus.publish(Event(
            type=GameEvents.GAME_OVER,
            data=result,
            priority=EventPriority.HIGH
        ))
        
        return result
    
    # ========== 게임 플레이 로직 ==========
    
    def process_player_input(self, input_data: Dict[str, Any]) -> None:
        """플레이어 입력 처리
        
        Args:
            input_data: 입력 데이터
        """
        if self.game_state.game_paused:
            return
        
        # 이동 처리
        if 'move' in input_data:
            self._process_player_movement(input_data['move'])
        
        # 대시 처리
        if input_data.get('dash'):
            self._process_dash()
        
        # 특수 능력 처리
        if input_data.get('special'):
            self._activate_special_ability()
    
    def _process_player_movement(self, direction: int) -> None:
        """플레이어 이동 처리"""
        speed = self.game_state.player_speed
        
        # 스피드 부츠 효과
        if self.game_state.speedboots_obtained:
            speed *= 1.2
        
        # 이동 적용
        new_x = self.game_state.player_x + (direction * speed)
        
        # 경계 체크
        max_x = 800 - self.game_state.player_width
        new_x = max(0, min(new_x, max_x))
        
        self.game_state.player_x = new_x
    
    def _process_dash(self) -> bool:
        """대시 처리"""
        if self.game_state.dash_charges <= 0:
            return False
        
        if self.game_state.dash_cooldown > 0:
            return False
        
        # 대시 시작
        self.game_state.dash_charges -= 1
        self.game_state.dash_active = True
        self.game_state.dash_timer = 10
        self.game_state.dash_cooldown = 30
        
        return True
    
    def _activate_special_ability(self) -> bool:
        """특수 능력 활성화"""
        if not self.game_state.special_ready:
            return False
        
        self.game_state.special_active = True
        self.game_state.special_duration = 300  # 5초
        self.game_state.special_gauge = 0
        self.game_state.special_ready = False
        
        # 이벤트 발행
        self.event_bus.publish(Event(
            type=GameEvents.PLAYER_POWERUP,
            data={'type': 'special_ability'},
            priority=EventPriority.HIGH
        ))
        
        return True
    
    # ========== 게임 업데이트 ==========
    
    def update(self, dt: float) -> None:
        """게임 상태 업데이트
        
        Args:
            dt: 델타 시간
        """
        if self.game_state.game_paused:
            return
        
        # 물리 업데이트
        self._update_physics(dt)
        
        # 충돌 체크
        self._check_collisions()
        
        # 아이템 업데이트
        self._update_items(dt)
        
        # 특수 능력 업데이트
        self._update_special_abilities(dt)
        
        # 보스 업데이트
        self._update_boss(dt)
    
    def _update_physics(self, dt: float) -> None:
        """물리 엔진 업데이트"""
        # 공 위치 업데이트
        ball_data = {
            'x': self.game_state.ball_x,
            'y': self.game_state.ball_y,
            'vel_x': self.game_state.ball_speed_x,
            'vel_y': self.game_state.ball_speed_y
        }
        
        # 물리 엔진 계산
        new_ball_data = self.physics_engine.update(ball_data, dt)
        
        # 상태 업데이트
        self.game_state.ball_x = new_ball_data['x']
        self.game_state.ball_y = new_ball_data['y']
        self.game_state.ball_speed_x = new_ball_data['vel_x']
        self.game_state.ball_speed_y = new_ball_data['vel_y']
    
    def _check_collisions(self) -> None:
        """충돌 검사"""
        entities = {
            'ball': [(self.game_state.ball_x, self.game_state.ball_y)],
            'player': [(self.game_state.player_x, self.game_state.player_y)],
            'boss': [(self.game_state.boss_x, self.game_state.boss_y)]
        }
        
        collisions = self.collision_system.check_collisions(entities)
        
        for collision in collisions:
            self._handle_collision(collision)
    
    def _handle_collision(self, collision: Dict[str, Any]) -> None:
        """충돌 처리"""
        if collision['type'] == 'ball_player':
            self._handle_ball_player_collision()
        elif collision['type'] == 'ball_boss':
            self._handle_ball_boss_collision()
    
    # ========== 이벤트 핸들러 ==========
    
    def _handle_player_hit(self, event: Event) -> None:
        """플레이어 피격 처리"""
        damage = event.data.get('damage', 1)
        
        # 방어 아이템 체크
        if self.game_state.revival_obtained and not self.game_state.revival_used:
            self.game_state.revival_used = True
            return
        
        # 점수 감소
        self.game_state.ai_score += damage
    
    def _handle_boss_hit(self, event: Event) -> None:
        """보스 피격 처리"""
        damage = event.data.get('damage', 1)
        
        # 보스 체력 감소
        self.game_state.boss_health -= damage
        
        if self.game_state.boss_health <= 0:
            self._handle_boss_defeat()
    
    def _handle_item_collect(self, event: Event) -> None:
        """아이템 수집 처리"""
        item_name = event.data.get('item_name')
        
        # 아이템 효과 적용
        self._apply_item_effect(item_name)
    
    # ========== 헬퍼 메서드 ==========
    
    def _calculate_play_time(self) -> float:
        """플레이 시간 계산"""
        # 실제 구현에서는 시작 시간과 현재 시간 차이 계산
        return 0.0
    
    def _update_items(self, dt: float) -> None:
        """아이템 업데이트"""
        pass
    
    def _update_special_abilities(self, dt: float) -> None:
        """특수 능력 업데이트"""
        if self.game_state.special_active:
            self.game_state.special_duration -= dt * 60
            if self.game_state.special_duration <= 0:
                self.game_state.special_active = False
    
    def _update_boss(self, dt: float) -> None:
        """보스 AI 업데이트"""
        pass
    
    def _handle_ball_player_collision(self) -> None:
        """공-플레이어 충돌 처리"""
        self.game_state.ball_speed_y *= -1
        self.game_state.last_hit_by = "player"
    
    def _handle_ball_boss_collision(self) -> None:
        """공-보스 충돌 처리"""
        self.game_state.ball_speed_y *= -1
        self.game_state.last_hit_by = "boss"
    
    def _handle_boss_defeat(self) -> None:
        """보스 격파 처리"""
        self.event_bus.publish(Event(
            type=GameEvents.BOSS_DEFEATED,
            data={'stage': self.game_state.current_stage},
            priority=EventPriority.CRITICAL
        ))
    
    def _apply_item_effect(self, item_name: str) -> None:
        """아이템 효과 적용"""
        # 아이템별 효과 구현
        pass