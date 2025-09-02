"""
Collision System - 충돌 감지 및 처리 시스템
모든 충돌 관련 로직을 중앙에서 관리
"""

import pygame
import math
import random
from typing import Tuple, Optional, Dict, Any, List
from core.game_state import GameState
from core.events import EventType, emit_event
from core.global_manager import GlobalManager


class CollisionSystem:
    """충돌 감지 및 처리 시스템"""
    
    def __init__(self):
        self.game_state = GameState.get_instance()
        self.global_manager = GlobalManager.get_instance()
        
        # 충돌 설정
        self.paddle_hit_boost = 1.1
        self.wall_damping = 0.95
        self.last_hit_by = None
        
        # 히트박스 설정
        self.hitbox_padding = 5
        
    def check_ball_paddle_collision(self, ball_rect: pygame.Rect, 
                                   paddle_rect: pygame.Rect, 
                                   ball_vel: List[float],
                                   is_player: bool = True) -> bool:
        """공-패들 충돌 체크
        
        Args:
            ball_rect: 공의 Rect
            paddle_rect: 패들의 Rect
            ball_vel: 공의 속도 [vx, vy]
            is_player: 플레이어 패들인지 여부
            
        Returns:
            충돌 여부
        """
        # 확장된 히트박스로 체크
        expanded_paddle = paddle_rect.inflate(self.hitbox_padding, self.hitbox_padding)
        
        if ball_rect.colliderect(expanded_paddle):
            # Y 방향 체크 (플레이어는 아래에서 위로, 보스는 위에서 아래로)
            if (is_player and ball_vel[1] > 0) or (not is_player and ball_vel[1] < 0):
                # 충돌 지점 계산
                hit_pos = (ball_rect.centerx - paddle_rect.centerx) / (paddle_rect.width / 2)
                hit_pos = max(-1, min(1, hit_pos))
                
                # 반사 각도 계산
                max_angle = 60
                angle = hit_pos * max_angle
                angle_rad = math.radians(angle)
                
                # 속도 계산
                speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2) * self.paddle_hit_boost
                
                # 새로운 속도
                if is_player:
                    ball_vel[0] = speed * math.sin(angle_rad)
                    ball_vel[1] = -abs(speed * math.cos(angle_rad))
                else:
                    ball_vel[0] = speed * math.sin(angle_rad)
                    ball_vel[1] = abs(speed * math.cos(angle_rad))
                
                # 위치 조정
                if is_player:
                    ball_rect.bottom = paddle_rect.top - 1
                else:
                    ball_rect.top = paddle_rect.bottom + 1
                
                # 효과음
                sound = self.global_manager.get('SOUND_PADDLE')
                if sound:
                    sound.play()
                
                # 이벤트 발생
                emit_event(EventType.COLLISION, {
                    'type': 'paddle',
                    'is_player': is_player,
                    'hit_position': hit_pos
                })
                
                # 마지막 타격자 기록
                self.last_hit_by = 'player' if is_player else 'boss'
                
                return True
                
        return False
    
    def check_ball_wall_collision(self, ball_rect: pygame.Rect, 
                                 ball_vel: List[float],
                                 screen_width: int) -> bool:
        """공-벽 충돌 체크
        
        Args:
            ball_rect: 공의 Rect
            ball_vel: 공의 속도 [vx, vy]
            screen_width: 화면 너비
            
        Returns:
            충돌 여부
        """
        hit = False
        
        # 왼쪽 벽
        if ball_rect.left <= 0 and ball_vel[0] < 0:
            ball_rect.left = 0
            ball_vel[0] = -ball_vel[0] * self.wall_damping
            hit = True
            
        # 오른쪽 벽
        elif ball_rect.right >= screen_width and ball_vel[0] > 0:
            ball_rect.right = screen_width
            ball_vel[0] = -ball_vel[0] * self.wall_damping
            hit = True
            
        if hit:
            # 효과음
            sound = self.global_manager.get('SOUND_WALL')
            if sound:
                sound.play()
                
            # 이벤트 발생
            emit_event(EventType.COLLISION, {'type': 'wall'})
            
        return hit
    
    def check_ball_out_of_bounds(self, ball_rect: pygame.Rect, 
                                screen_height: int) -> Optional[str]:
        """공이 화면 밖으로 나갔는지 체크
        
        Args:
            ball_rect: 공의 Rect
            screen_height: 화면 높이
            
        Returns:
            득점한 쪽 ('player' or 'boss') 또는 None
        """
        # 위쪽으로 나감 (플레이어 득점)
        if ball_rect.bottom < 0:
            return 'player'
            
        # 아래쪽으로 나감 (보스 득점)
        elif ball_rect.top > screen_height:
            return 'boss'
            
        return None
    
    def check_item_collision(self, ball_rect: pygame.Rect, 
                            item_rect: pygame.Rect) -> bool:
        """아이템 충돌 체크
        
        Args:
            ball_rect: 공의 Rect
            item_rect: 아이템의 Rect
            
        Returns:
            충돌 여부
        """
        return ball_rect.colliderect(item_rect)
    
    def check_laser_ball_collision(self, laser_rect: pygame.Rect, 
                                  ball_rect: pygame.Rect) -> bool:
        """레이저-공 충돌 체크
        
        Args:
            laser_rect: 레이저의 Rect
            ball_rect: 공의 Rect
            
        Returns:
            충돌 여부
        """
        return laser_rect.colliderect(ball_rect)
    
    def predict_ball_position(self, ball_pos: Tuple[float, float],
                            ball_vel: Tuple[float, float],
                            target_y: float,
                            screen_width: int) -> float:
        """공의 미래 위치 예측
        
        Args:
            ball_pos: 현재 공 위치
            ball_vel: 현재 공 속도
            target_y: 목표 Y 좌표
            screen_width: 화면 너비
            
        Returns:
            예측된 X 좌표
        """
        if abs(ball_vel[1]) < 0.1:
            return ball_pos[0]
            
        # 목표 Y까지 도달 시간
        time_to_reach = (target_y - ball_pos[1]) / ball_vel[1]
        
        if time_to_reach < 0:
            return ball_pos[0]
            
        # X 위치 예측
        predicted_x = ball_pos[0] + ball_vel[0] * time_to_reach
        
        # 벽 반사 고려
        while predicted_x < 0 or predicted_x > screen_width:
            if predicted_x < 0:
                predicted_x = -predicted_x
            elif predicted_x > screen_width:
                predicted_x = 2 * screen_width - predicted_x
                
        return predicted_x
    
    def apply_stage_effects(self, stage: int):
        """스테이지별 충돌 효과 적용
        
        Args:
            stage: 스테이지 번호
        """
        if stage == 2:
            # Speed Demon
            self.paddle_hit_boost = 1.2
            self.wall_damping = 0.98
        elif stage == 3:
            # Menhera Girl
            self.paddle_hit_boost = random.uniform(0.9, 1.3)
        elif stage == 4:
            # Zen Master
            self.paddle_hit_boost = 1.0
            self.wall_damping = 1.0
        elif stage == 5:
            # Crimson Flame
            self.paddle_hit_boost = 1.3
        elif stage == 6:
            # Battlecruiser
            self.wall_damping = 0.99


# 싱글톤 인스턴스
_collision_system = None

def get_collision_system() -> CollisionSystem:
    """충돌 시스템 싱글톤 반환"""
    global _collision_system
    if _collision_system is None:
        _collision_system = CollisionSystem()
    return _collision_system

    
    def __init__(self):
        self.game_state = GameState.get_instance()
        
        # 충돌 설정
        self.paddle_hit_cooldown = 0
        self.wall_hit_cooldown = 0
        self.last_hit_by = None
        
        # 충돌 통계
        self.collision_stats = {
            'paddle_hits': 0,
            'wall_hits': 0,
            'boss_hits': 0,
            'perfect_hits': 0,
            'edge_hits': 0
        }
        
    def check_ball_paddle_collision(self, ball_rect: pygame.Rect, 
                                   paddle_rect: pygame.Rect, 
                                   ball_vel: list,
                                   is_player: bool = True) -> bool:
        """공과 패들의 충돌 검사
        
        Args:
            ball_rect: 공의 Rect
            paddle_rect: 패들의 Rect
            ball_vel: 공의 속도 [vx, vy]
            is_player: 플레이어 패들인지 여부
            
        Returns:
            충돌 여부
        """
        if not ball_rect.colliderect(paddle_rect):
            return False
            
        # 쿨다운 체크
        if self.paddle_hit_cooldown > 0:
            return False
            
        # 올바른 방향에서 충돌하는지 체크
        if is_player and ball_vel[1] <= 0:  # 플레이어는 공이 아래로 갈 때만
            return False
        elif not is_player and ball_vel[1] >= 0:  # 보스는 공이 위로 갈 때만
            return False
            
        # 충돌 처리
        self.handle_paddle_collision(ball_rect, paddle_rect, ball_vel, is_player)
        return True
        
    def handle_paddle_collision(self, ball_rect: pygame.Rect,
                               paddle_rect: pygame.Rect,
                               ball_vel: list,
                               is_player: bool):
        """패들 충돌 처리
        
        Args:
            ball_rect: 공의 Rect
            paddle_rect: 패들의 Rect  
            ball_vel: 공의 속도 [vx, vy]
            is_player: 플레이어 패들인지 여부
        """
        # 충돌 위치 계산
        hit_pos = (ball_rect.centerx - paddle_rect.centerx) / (paddle_rect.width / 2)
        hit_pos = max(-1, min(1, hit_pos))  # -1 ~ 1 사이로 제한
        
        # 반사 각도 계산
        bounce_angle = hit_pos * 60  # 최대 60도
        
        # 속도 계산
        speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
        
        # 엣지 히트 체크 (패들 가장자리)
        is_edge_hit = abs(hit_pos) > 0.8
        if is_edge_hit:
            speed *= 1.2  # 엣지 히트 시 속도 증가
            self.collision_stats['edge_hits'] += 1
            emit_event(EventType.SPECIAL_ACTIVATED, {'type': 'edge_hit'})
            
        # 새로운 속도 설정
        ball_vel[0] = speed * math.sin(math.radians(bounce_angle))
        ball_vel[1] = -ball_vel[1]  # Y 방향 반전
        
        # 이벤트 발생
        event_type = EventType.BALL_HIT_PLAYER if is_player else EventType.BALL_HIT_BOSS
        emit_event(event_type, {
            'hit_pos': hit_pos,
            'edge_hit': is_edge_hit,
            'speed': speed
        })
        
        # 통계 업데이트
        if is_player:
            self.collision_stats['paddle_hits'] += 1
        else:
            self.collision_stats['boss_hits'] += 1
            
        # 쿨다운 설정
        self.paddle_hit_cooldown = 10
        
        # 마지막 타격자 기록
        self.last_hit_by = 'player' if is_player else 'boss'
        
    def check_ball_wall_collision(self, ball_rect: pygame.Rect,
                                 ball_vel: list,
                                 screen_width: int) -> bool:
        """공과 벽의 충돌 검사
        
        Args:
            ball_rect: 공의 Rect
            ball_vel: 공의 속도 [vx, vy]
            screen_width: 화면 너비
            
        Returns:
            충돌 여부
        """
        hit_wall = False
        
        # 왼쪽 벽
        if ball_rect.left <= 0 and ball_vel[0] < 0:
            ball_vel[0] = abs(ball_vel[0])
            ball_rect.left = 0
            hit_wall = True
            
        # 오른쪽 벽
        elif ball_rect.right >= screen_width and ball_vel[0] > 0:
            ball_vel[0] = -abs(ball_vel[0])
            ball_rect.right = screen_width
            hit_wall = True
            
        if hit_wall:
            self.handle_wall_collision(ball_rect, ball_vel)
            
        return hit_wall
        
    def handle_wall_collision(self, ball_rect: pygame.Rect, ball_vel: list):
        """벽 충돌 처리
        
        Args:
            ball_rect: 공의 Rect
            ball_vel: 공의 속도 [vx, vy]
        """
        # 속도 감소 (벽 충돌 시 에너지 손실)
        ball_vel[0] *= 0.95
        ball_vel[1] *= 0.98
        
        # 이벤트 발생
        emit_event(EventType.BALL_HIT_WALL, {
            'position': (ball_rect.centerx, ball_rect.centery),
            'velocity': (ball_vel[0], ball_vel[1])
        })
        
        # 통계 업데이트
        self.collision_stats['wall_hits'] += 1
        
        # 스크린 쉐이크 효과
        emit_event(EventType.SCREEN_SHAKE, {
            'intensity': 5,
            'duration': 0.2
        })
        
    def check_ball_out_of_bounds(self, ball_rect: pygame.Rect,
                                screen_height: int) -> Optional[str]:
        """공이 화면 밖으로 나갔는지 검사
        
        Args:
            ball_rect: 공의 Rect
            screen_height: 화면 높이
            
        Returns:
            'player' or 'boss' or None
        """
        # 위쪽 (보스 측)
        if ball_rect.bottom < 0:
            emit_event(EventType.BALL_OUT_OF_BOUNDS, {'side': 'boss'})
            return 'player'  # 플레이어 득점
            
        # 아래쪽 (플레이어 측)
        elif ball_rect.top > screen_height:
            emit_event(EventType.BALL_OUT_OF_BOUNDS, {'side': 'player'})
            return 'boss'  # 보스 득점
            
        return None
        
    def check_perfect_timing(self, ball_rect: pygame.Rect,
                           paddle_rect: pygame.Rect,
                           ball_vel: list) -> bool:
        """퍼펙트 타이밍 체크
        
        Args:
            ball_rect: 공의 Rect
            paddle_rect: 패들의 Rect
            ball_vel: 공의 속도 [vx, vy]
            
        Returns:
            퍼펙트 타이밍 여부
        """
        # 공이 패들에 가까이 있고 아래로 향하는지 체크
        distance = paddle_rect.top - ball_rect.centery
        
        if 0 < distance < 30 and ball_vel[1] > 0:
            # X축 범위 체크
            x_distance = abs(ball_rect.centerx - paddle_rect.centerx)
            if x_distance <= paddle_rect.width / 2 + ball_rect.width / 2:
                self.collision_stats['perfect_hits'] += 1
                return True
                
        return False
        
    def check_item_collision(self, ball_rect: pygame.Rect,
                            item_rect: pygame.Rect) -> bool:
        """아이템과 공의 충돌 검사
        
        Args:
            ball_rect: 공의 Rect
            item_rect: 아이템의 Rect
            
        Returns:
            충돌 여부
        """
        return ball_rect.colliderect(item_rect)
        
    def check_wall_collision(self, ball_rect: pygame.Rect,
                            wall_rect: pygame.Rect,
                            ball_vel: list) -> bool:
        """벽돌과 공의 충돌 검사
        
        Args:
            ball_rect: 공의 Rect
            wall_rect: 벽돌의 Rect
            ball_vel: 공의 속도 [vx, vy]
            
        Returns:
            충돌 여부
        """
        if not ball_rect.colliderect(wall_rect):
            return False
            
        # 충돌 방향 결정
        ball_center_x = ball_rect.centerx
        ball_center_y = ball_rect.centery
        wall_center_x = wall_rect.centerx
        wall_center_y = wall_rect.centery
        
        # 상대 위치 계산
        dx = ball_center_x - wall_center_x
        dy = ball_center_y - wall_center_y
        
        # 충돌 면 결정
        if abs(dx) > abs(dy):
            # 좌우 충돌
            ball_vel[0] = -ball_vel[0]
        else:
            # 상하 충돌
            ball_vel[1] = -ball_vel[1]
            
        return True
        
    def update(self, dt: float):
        """충돌 시스템 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 쿨다운 감소
        if self.paddle_hit_cooldown > 0:
            self.paddle_hit_cooldown -= 1
            
        if self.wall_hit_cooldown > 0:
            self.wall_hit_cooldown -= 1
            
    def get_stats(self) -> Dict[str, int]:
        """충돌 통계 반환"""
        return self.collision_stats.copy()
        
    def reset_stats(self):
        """충돌 통계 초기화"""
        for key in self.collision_stats:
            self.collision_stats[key] = 0
            
    def get_last_hit_by(self) -> Optional[str]:
        """마지막으로 공을 친 대상 반환"""
        return self.last_hit_by


# 싱글톤 인스턴스
_collision_system = None

def get_collision_system() -> CollisionSystem:
    """충돌 시스템 인스턴스 반환"""
    global _collision_system
    if _collision_system is None:
        _collision_system = CollisionSystem()
    return _collision_system

def reset_collision_system():
    """충돌 시스템 리셋"""
    global _collision_system
    _collision_system = None