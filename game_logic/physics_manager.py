"""
PhysicsManager - 물리 시스템 관리
공의 움직임, 속도, 반사각 등 물리 연산 담당
"""

import pygame
import random
import math
from typing import Tuple, Optional, Dict, Any
from core.events import EventType, emit_event
from core.game_state import GameState


class PhysicsManager:
    """물리 시스템 관리자"""
    
    def __init__(self, screen_width: int = 600, screen_height: int = 750):
        self.game_state = GameState.get_instance()
        self.screen_width = screen_width
        self.screen_height = screen_height
        
        # 물리 상수
        self.base_ball_speed = 9
        self.gravity = 0.0  # 기본적으로 중력 없음
        self.friction = 1.0  # 기본적으로 마찰 없음
        self.max_speed = 30
        self.min_speed = 3
        
    def reset_ball(self, ball_rect: pygame.Rect, is_player_serve: bool = True):
        """공 위치 리셋
        
        Args:
            ball_rect: 공의 Rect
            is_player_serve: 플레이어 서브 여부
        """
        # 공을 화면 중앙에 위치
        ball_rect.centerx = self.screen_width // 2
        
        if is_player_serve:
            # 플레이어 서브: 플레이어 패들 근처
            ball_rect.centery = self.screen_height - 80
        else:
            # 보스 서브: 보스 패들 근처
            ball_rect.centery = 80
            
        # 공 위치 GameState에 저장
        self.game_state.ball_x = ball_rect.centerx
        self.game_state.ball_y = ball_rect.centery
        
    def serve_ball(self, is_player_serve: bool = True) -> Tuple[float, float]:
        """공 서브
        
        Args:
            is_player_serve: 플레이어 서브 여부
            
        Returns:
            공의 초기 속도 (vx, vy)
        """
        # 스테이지별 속도 계산
        stage_multiplier = 1.0 + (self.game_state.current_stage - 1) * 0.03
        base_speed = self.base_ball_speed * stage_multiplier
        
        if is_player_serve:
            # 플레이어 서브: 위로
            vx = random.choice([-3, 3]) * stage_multiplier
            vy = -base_speed
        else:
            # 보스 서브: 아래로
            vx = random.choice([-3, 3]) * stage_multiplier
            vy = base_speed
            
        # 속도 GameState에 저장
        self.game_state.ball_speed_x = vx
        self.game_state.ball_speed_y = vy
        
        # 서브 이벤트 발생
        emit_event(EventType.ROUND_START, {
            'server': 'player' if is_player_serve else 'boss',
            'initial_velocity': (vx, vy)
        })
        
        return vx, vy
        
    def calculate_reflection_angle(self, ball_center_x: float, paddle_center_x: float, 
                                  paddle_width: float, current_vy: float) -> Tuple[float, float]:
        """패들 충돌 시 반사각 계산
        
        Args:
            ball_center_x: 공의 중심 X 좌표
            paddle_center_x: 패들의 중심 X 좌표
            paddle_width: 패들 너비
            current_vy: 현재 Y 속도
            
        Returns:
            새로운 속도 (vx, vy)
        """
        # 충돌 위치에 따른 반사각 계산
        hit_position = (ball_center_x - paddle_center_x) / (paddle_width / 2)
        hit_position = max(-1.0, min(1.0, hit_position))  # -1 ~ 1 범위로 제한
        
        # 반사각 계산 (최대 60도)
        max_angle = math.pi / 3  # 60도
        reflection_angle = hit_position * max_angle
        
        # 속도 크기 유지하면서 방향 변경
        speed = math.sqrt(self.game_state.ball_speed_x ** 2 + self.game_state.ball_speed_y ** 2)
        
        # 새로운 속도 계산
        vx = speed * math.sin(reflection_angle)
        vy = -abs(current_vy) if current_vy > 0 else abs(current_vy)
        
        return vx, vy
        
    def apply_spin(self, vx: float, vy: float, spin_amount: float) -> Tuple[float, float]:
        """스핀 효과 적용
        
        Args:
            vx: 현재 X 속도
            vy: 현재 Y 속도
            spin_amount: 스핀 양 (-1 ~ 1, 음수는 백스핀, 양수는 톱스핀)
            
        Returns:
            스핀이 적용된 속도 (vx, vy)
        """
        # 스핀에 따른 속도 변화
        spin_effect = spin_amount * 0.3
        
        # X 방향 스핀 효과
        vx += spin_effect * abs(vy) * 0.1
        
        # Y 방향 스핀 효과 (톱스핀은 가속, 백스핀은 감속)
        if spin_amount > 0:  # 톱스핀
            vy *= (1 + abs(spin_effect) * 0.2)
        else:  # 백스핀
            vy *= (1 - abs(spin_effect) * 0.1)
            
        return vx, vy
        
    def apply_gravity(self, vy: float, gravity_strength: float = 0.0) -> float:
        """중력 효과 적용
        
        Args:
            vy: 현재 Y 속도
            gravity_strength: 중력 강도
            
        Returns:
            중력이 적용된 Y 속도
        """
        return vy + gravity_strength
        
    def apply_friction(self, vx: float, vy: float, friction_coefficient: float = 1.0) -> Tuple[float, float]:
        """마찰 효과 적용
        
        Args:
            vx: 현재 X 속도
            vy: 현재 Y 속도
            friction_coefficient: 마찰 계수 (1.0 = 마찰 없음)
            
        Returns:
            마찰이 적용된 속도 (vx, vy)
        """
        vx *= friction_coefficient
        vy *= friction_coefficient
        return vx, vy
        
    def limit_speed(self, vx: float, vy: float) -> Tuple[float, float]:
        """속도 제한
        
        Args:
            vx: 현재 X 속도
            vy: 현재 Y 속도
            
        Returns:
            제한된 속도 (vx, vy)
        """
        speed = math.sqrt(vx ** 2 + vy ** 2)
        
        if speed > self.max_speed:
            ratio = self.max_speed / speed
            vx *= ratio
            vy *= ratio
        elif speed < self.min_speed and speed > 0:
            ratio = self.min_speed / speed
            vx *= ratio
            vy *= ratio
            
        return vx, vy
        
    def update_ball_position(self, ball_rect: pygame.Rect, vx: float, vy: float, dt: float = 1.0):
        """공 위치 업데이트
        
        Args:
            ball_rect: 공의 Rect
            vx: X 속도
            vy: Y 속도
            dt: 델타 타임 (프레임 보정용)
        """
        ball_rect.x += vx * dt
        ball_rect.y += vy * dt
        
        # GameState 업데이트
        self.game_state.ball_x = ball_rect.centerx
        self.game_state.ball_y = ball_rect.centery
        self.game_state.ball_speed_x = vx
        self.game_state.ball_speed_y = vy
        
    def predict_ball_trajectory(self, start_pos: Tuple[float, float], 
                               velocity: Tuple[float, float], 
                               time_steps: int = 60) -> list:
        """공의 궤적 예측
        
        Args:
            start_pos: 시작 위치 (x, y)
            velocity: 속도 (vx, vy)
            time_steps: 예측할 프레임 수
            
        Returns:
            예측된 위치들의 리스트
        """
        trajectory = []
        x, y = start_pos
        vx, vy = velocity
        
        for _ in range(time_steps):
            x += vx
            y += vy
            
            # 벽 충돌 시뮬레이션
            if x <= 0 or x >= self.screen_width:
                vx = -vx
                x = max(0, min(self.screen_width, x))
                
            trajectory.append((x, y))
            
            # 화면 밖으로 나가면 중단
            if y < 0 or y > self.screen_height:
                break
                
        return trajectory