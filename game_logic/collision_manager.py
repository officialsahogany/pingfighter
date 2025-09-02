"""
CollisionManager - 충돌 감지 및 처리
모든 충돌 관련 로직을 중앙집중식으로 관리
"""

import pygame
from typing import Tuple, Optional, Dict, Any
from core.events import EventType, emit_event
from core.game_state import GameState


class CollisionManager:
    """충돌 감지 및 처리 관리자"""
    
    def __init__(self):
        self.game_state = GameState.get_instance()
        self.collision_cooldown = 0
        self.last_collision_time = 0
        
    def check_ball_player_collision(self, ball_rect: pygame.Rect, player_rect: pygame.Rect, 
                                   ball_vel: Tuple[float, float]) -> bool:
        """공과 플레이어 패들 충돌 체크
        
        Args:
            ball_rect: 공의 Rect
            player_rect: 플레이어 패들의 Rect
            ball_vel: 공의 속도 (vx, vy)
            
        Returns:
            충돌 여부
        """
        if not ball_rect.colliderect(player_rect):
            return False
            
        # 충돌 위치 계산
        collision_x = ball_rect.centerx - player_rect.centerx
        collision_side = "LEFT" if collision_x < 0 else "RIGHT"
        
        # 충돌 이벤트 발생
        emit_event(EventType.BALL_HIT_PLAYER, {
            'collision_x': collision_x,
            'collision_side': collision_side,
            'ball_speed': ball_vel,
            'paddle_center': player_rect.centerx
        })
        
        return True
        
    def check_ball_boss_collision(self, ball_rect: pygame.Rect, boss_rect: pygame.Rect,
                                 ball_vel: Tuple[float, float]) -> bool:
        """공과 보스 패들 충돌 체크
        
        Args:
            ball_rect: 공의 Rect
            boss_rect: 보스 패들의 Rect
            ball_vel: 공의 속도 (vx, vy)
            
        Returns:
            충돌 여부
        """
        if not ball_rect.colliderect(boss_rect):
            return False
            
        # 충돌 위치 계산
        collision_x = ball_rect.centerx - boss_rect.centerx
        collision_side = "LEFT" if collision_x < 0 else "RIGHT"
        
        # 충돌 이벤트 발생
        emit_event(EventType.BALL_HIT_BOSS, {
            'collision_x': collision_x,
            'collision_side': collision_side,
            'ball_speed': ball_vel,
            'paddle_center': boss_rect.centerx
        })
        
        return True
        
    def check_ball_wall_collision(self, ball_rect: pygame.Rect, screen_width: int) -> Optional[str]:
        """공과 벽 충돌 체크
        
        Args:
            ball_rect: 공의 Rect
            screen_width: 화면 너비
            
        Returns:
            충돌한 벽 방향 ('left', 'right') 또는 None
        """
        if ball_rect.left <= 0:
            emit_event(EventType.BALL_HIT_WALL, {'wall': 'left'})
            return 'left'
        elif ball_rect.right >= screen_width:
            emit_event(EventType.BALL_HIT_WALL, {'wall': 'right'})
            return 'right'
            
        return None
        
    def check_ball_out_of_bounds(self, ball_rect: pygame.Rect, screen_height: int) -> Optional[str]:
        """공이 화면 밖으로 나갔는지 체크
        
        Args:
            ball_rect: 공의 Rect
            screen_height: 화면 높이
            
        Returns:
            나간 방향 ('top', 'bottom') 또는 None
        """
        if ball_rect.bottom <= 0:
            emit_event(EventType.BALL_OUT_OF_BOUNDS, {'side': 'top', 'winner': 'player'})
            return 'top'
        elif ball_rect.top >= screen_height:
            emit_event(EventType.BALL_OUT_OF_BOUNDS, {'side': 'bottom', 'winner': 'boss'})
            return 'bottom'
            
        return None
        
    def handle_collision_response(self, collision_type: str, collision_data: Dict[str, Any]) -> Tuple[float, float]:
        """충돌에 대한 반응 처리
        
        Args:
            collision_type: 충돌 타입
            collision_data: 충돌 관련 데이터
            
        Returns:
            수정된 공 속도 (vx, vy)
        """
        # 이 부분은 기존 충돌 반응 로직을 가져와서 구현
        # 현재는 간단한 반사만 구현
        vx, vy = collision_data.get('ball_speed', (0, 0))
        
        if collision_type == 'player':
            vy = -abs(vy)  # 위로 반사
        elif collision_type == 'boss':
            vy = abs(vy)   # 아래로 반사
        elif collision_type == 'wall_left':
            vx = abs(vx)   # 오른쪽으로 반사
        elif collision_type == 'wall_right':
            vx = -abs(vx)  # 왼쪽으로 반사
            
        return vx, vy