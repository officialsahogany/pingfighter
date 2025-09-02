"""
⚡ Physics Engine
물리 엔진 - 공의 움직임과 물리 시뮬레이션
"""

import pygame
import math
import random
from typing import Tuple, Optional, Dict, Any
from dataclasses import dataclass
from enum import Enum


class PhysicsMode(Enum):
    """물리 모드"""
    NORMAL = "normal"      # 일반 물리
    GRAVITY = "gravity"    # 중력 적용
    MAGNETIC = "magnetic"  # 자기장 영향
    CHAOS = "chaos"       # 혼돈 모드


@dataclass
class PhysicsConfig:
    """물리 설정"""
    gravity: float = 0.0
    friction: float = 0.99
    bounce_damping: float = 1.0
    max_speed: float = 15.0
    min_speed: float = 3.0
    spin_factor: float = 0.3
    wind_force: Tuple[float, float] = (0, 0)


class PhysicsEngine:
    """
    ⚡ 물리 엔진 클래스
    
    공의 움직임, 충돌 반응, 특수 효과 등을 관리합니다.
    """
    
    def __init__(self, screen_width: int = 600, screen_height: int = 750):
        """
        물리 엔진 초기화
        
        Args:
            screen_width: 화면 너비
            screen_height: 화면 높이
        """
        self.screen_width = screen_width
        self.screen_height = screen_height
        
        # 기본 물리 설정
        self.config = PhysicsConfig()
        self.mode = PhysicsMode.NORMAL
        
        # 특수 효과
        self.magnetic_field = None
        self.gravity_well = None
        self.wind_active = False
        
        # 시간 왜곡
        self.time_scale = 1.0
        self.slow_motion_active = False
        self.slow_motion_timer = 0
        
        # 궤적 예측
        self.trajectory_points = []
        self.prediction_enabled = False
        
        print("⚡ 물리 엔진 초기화 완료")
    
    def update(self, ball: Any, paddle: Any, boss: Any, dt: float):
        """
        물리 업데이트
        
        Args:
            ball: 공 객체
            paddle: 패들 객체
            boss: 보스 객체
            dt: 델타 타임
        """
        # 시간 스케일 적용
        adjusted_dt = dt * self.time_scale
        
        # 슬로우 모션 업데이트
        if self.slow_motion_active:
            self.slow_motion_timer -= dt
            if self.slow_motion_timer <= 0:
                self.end_slow_motion()
        
        # 공 물리 업데이트
        if ball:
            self._update_ball_physics(ball, adjusted_dt)
            
            # 특수 효과 적용
            if self.mode == PhysicsMode.GRAVITY:
                self._apply_gravity(ball, adjusted_dt)
            elif self.mode == PhysicsMode.MAGNETIC:
                self._apply_magnetic_field(ball, paddle, boss, adjusted_dt)
            elif self.mode == PhysicsMode.CHAOS:
                self._apply_chaos(ball, adjusted_dt)
            
            # 바람 효과
            if self.wind_active:
                self._apply_wind(ball, adjusted_dt)
            
            # 속도 제한
            self._limit_speed(ball)
        
        # 궤적 예측 업데이트
        if self.prediction_enabled and ball:
            self._update_trajectory_prediction(ball)
    
    def _update_ball_physics(self, ball: Any, dt: float):
        """공 물리 업데이트"""
        if not hasattr(ball, 'x') or not hasattr(ball, 'vel_x'):
            return
        
        # 위치 업데이트
        ball.x += ball.vel_x * dt * 60
        ball.y += ball.vel_y * dt * 60
        
        # 마찰 적용
        ball.vel_x *= self.config.friction
        ball.vel_y *= self.config.friction
        
        # 스핀 적용 (있을 경우)
        if hasattr(ball, 'spin'):
            # 스핀이 속도에 영향
            spin_effect = ball.spin * self.config.spin_factor
            ball.vel_x += spin_effect * dt
            
            # 스핀 감소
            ball.spin *= 0.98
    
    def _apply_gravity(self, ball: Any, dt: float):
        """중력 적용"""
        if hasattr(ball, 'vel_y'):
            ball.vel_y += self.config.gravity * dt * 60
    
    def _apply_magnetic_field(self, ball: Any, paddle: Any, boss: Any, dt: float):
        """자기장 효과 적용"""
        if not self.magnetic_field:
            return
        
        # 자기장 중심
        mx, my = self.magnetic_field['position']
        strength = self.magnetic_field['strength']
        
        # 공과 자기장 중심 사이의 거리
        dx = mx - ball.x
        dy = my - ball.y
        distance = math.sqrt(dx*dx + dy*dy)
        
        if distance > 0 and distance < 200:  # 자기장 범위
            # 인력/척력 계산
            force = strength / (distance * distance) * 100
            
            # 방향 벡터
            fx = (dx / distance) * force
            fy = (dy / distance) * force
            
            # 속도에 적용
            ball.vel_x += fx * dt
            ball.vel_y += fy * dt
    
    def _apply_chaos(self, ball: Any, dt: float):
        """혼돈 모드 - 랜덤한 힘 적용"""
        if random.random() < 0.05:  # 5% 확률
            ball.vel_x += random.uniform(-2, 2)
            ball.vel_y += random.uniform(-2, 2)
    
    def _apply_wind(self, ball: Any, dt: float):
        """바람 효과 적용"""
        wind_x, wind_y = self.config.wind_force
        ball.vel_x += wind_x * dt
        ball.vel_y += wind_y * dt
    
    def _limit_speed(self, ball: Any):
        """속도 제한"""
        if not hasattr(ball, 'vel_x') or not hasattr(ball, 'vel_y'):
            return
        
        # 현재 속도 계산
        speed = math.sqrt(ball.vel_x**2 + ball.vel_y**2)
        
        # 최대 속도 제한
        if speed > self.config.max_speed:
            scale = self.config.max_speed / speed
            ball.vel_x *= scale
            ball.vel_y *= scale
        
        # 최소 속도 보장
        elif speed > 0 and speed < self.config.min_speed:
            scale = self.config.min_speed / speed
            ball.vel_x *= scale
            ball.vel_y *= scale
    
    def handle_collision(self, ball: Any, collision_type: str, 
                        collision_point: Tuple[float, float],
                        collision_normal: Tuple[float, float],
                        other_entity: Any = None):
        """
        충돌 처리
        
        Args:
            ball: 공 객체
            collision_type: 충돌 타입
            collision_point: 충돌 지점
            collision_normal: 충돌 법선
            other_entity: 충돌한 다른 엔티티
        """
        if collision_type == 'paddle':
            self._handle_paddle_collision(ball, collision_point, other_entity)
        elif collision_type == 'boss':
            self._handle_boss_collision(ball, collision_point, other_entity)
        elif collision_type == 'wall':
            self._handle_wall_collision(ball, collision_normal)
    
    def _handle_paddle_collision(self, ball: Any, collision_point: Tuple[float, float],
                                paddle: Any):
        """패들 충돌 처리"""
        if not paddle or not hasattr(paddle, 'rect'):
            return
        
        # 충돌 위치에 따른 반사각 계산
        hit_pos = (ball.x - paddle.rect.centerx) / (paddle.rect.width / 2)
        hit_pos = max(-1, min(1, hit_pos))
        
        # 반사 각도 (최대 60도)
        max_angle = math.pi / 3
        angle = hit_pos * max_angle
        
        # 현재 속도 크기
        speed = math.sqrt(ball.vel_x**2 + ball.vel_y**2)
        
        # 가속
        speed = min(speed * 1.05, self.config.max_speed)
        
        # 새 속도 벡터
        ball.vel_x = speed * math.sin(angle)
        ball.vel_y = -abs(speed * math.cos(angle))
        
        # 패들 움직임 영향
        if hasattr(paddle, 'vel_x'):
            ball.vel_x += paddle.vel_x * 0.3
        
        # 스핀 추가
        if hasattr(ball, 'spin'):
            ball.spin = hit_pos * 5
    
    def _handle_boss_collision(self, ball: Any, collision_point: Tuple[float, float],
                              boss: Any):
        """보스 충돌 처리"""
        if not boss or not hasattr(boss, 'rect'):
            return
        
        # 충돌 위치에 따른 반사각
        hit_pos = (ball.x - boss.rect.centerx) / (boss.rect.width / 2)
        hit_pos = max(-1, min(1, hit_pos))
        
        # 반사 각도
        max_angle = math.pi / 3
        angle = hit_pos * max_angle
        
        # 속도 계산
        speed = math.sqrt(ball.vel_x**2 + ball.vel_y**2)
        
        # 보스 스킬 영향
        if hasattr(boss, 'skill_active') and boss.skill_active:
            speed *= 1.2  # 스킬 활성 시 가속
        
        # 새 속도 벡터
        ball.vel_x = speed * math.sin(angle)
        ball.vel_y = abs(speed * math.cos(angle))
    
    def _handle_wall_collision(self, ball: Any, collision_normal: Tuple[float, float]):
        """벽 충돌 처리"""
        nx, ny = collision_normal
        
        # 반사 벡터 계산
        dot = ball.vel_x * nx + ball.vel_y * ny
        ball.vel_x -= 2 * dot * nx
        ball.vel_y -= 2 * dot * ny
        
        # 감쇠 적용
        ball.vel_x *= self.config.bounce_damping
        ball.vel_y *= self.config.bounce_damping
    
    def start_slow_motion(self, duration: float = 2.0, scale: float = 0.3):
        """슬로우 모션 시작"""
        self.slow_motion_active = True
        self.slow_motion_timer = duration
        self.time_scale = scale
        print(f"⏱️ 슬로우 모션 시작 (x{scale})")
    
    def end_slow_motion(self):
        """슬로우 모션 종료"""
        self.slow_motion_active = False
        self.time_scale = 1.0
        print("⏱️ 슬로우 모션 종료")
    
    def set_physics_mode(self, mode: PhysicsMode):
        """물리 모드 설정"""
        self.mode = mode
        
        # 모드별 기본 설정
        if mode == PhysicsMode.GRAVITY:
            self.config.gravity = 0.3
        elif mode == PhysicsMode.MAGNETIC:
            # 화면 중앙에 자기장 생성
            self.magnetic_field = {
                'position': (self.screen_width // 2, self.screen_height // 2),
                'strength': 50,
                'type': 'attract'  # 'attract' or 'repel'
            }
        elif mode == PhysicsMode.CHAOS:
            self.config.friction = 0.95
        else:  # NORMAL
            self.config = PhysicsConfig()  # 기본값으로 리셋
        
        print(f"⚡ 물리 모드 변경: {mode.value}")
    
    def set_magnetic_field(self, position: Tuple[float, float], 
                          strength: float, field_type: str = 'attract'):
        """자기장 설정"""
        self.magnetic_field = {
            'position': position,
            'strength': strength,
            'type': field_type
        }
    
    def set_wind(self, force_x: float, force_y: float):
        """바람 설정"""
        self.config.wind_force = (force_x, force_y)
        self.wind_active = True
    
    def stop_wind(self):
        """바람 정지"""
        self.config.wind_force = (0, 0)
        self.wind_active = False
    
    def _update_trajectory_prediction(self, ball: Any):
        """궤적 예측 업데이트"""
        if not hasattr(ball, 'x') or not hasattr(ball, 'vel_x'):
            return
        
        self.trajectory_points.clear()
        
        # 시뮬레이션용 가상 공
        sim_x = ball.x
        sim_y = ball.y
        sim_vx = ball.vel_x
        sim_vy = ball.vel_y
        
        # 1초 후까지 예측 (60프레임)
        for i in range(60):
            # 위치 업데이트
            sim_x += sim_vx
            sim_y += sim_vy
            
            # 물리 적용
            if self.mode == PhysicsMode.GRAVITY:
                sim_vy += self.config.gravity
            
            # 벽 충돌 체크
            if sim_x <= 10 or sim_x >= self.screen_width - 10:
                sim_vx = -sim_vx
            
            # 궤적 포인트 저장 (5프레임마다)
            if i % 5 == 0:
                self.trajectory_points.append((int(sim_x), int(sim_y)))
            
            # 화면 밖으로 나가면 중단
            if sim_y < -50 or sim_y > self.screen_height + 50:
                break
    
    def get_trajectory_points(self):
        """예측된 궤적 포인트 반환"""
        return self.trajectory_points
    
    def enable_trajectory_prediction(self):
        """궤적 예측 활성화"""
        self.prediction_enabled = True
    
    def disable_trajectory_prediction(self):
        """궤적 예측 비활성화"""
        self.prediction_enabled = False
        self.trajectory_points.clear()
    
    def apply_impulse(self, ball: Any, force_x: float, force_y: float):
        """충격력 적용"""
        if hasattr(ball, 'vel_x') and hasattr(ball, 'vel_y'):
            ball.vel_x += force_x
            ball.vel_y += force_y
            self._limit_speed(ball)
    
    def get_physics_info(self) -> Dict[str, Any]:
        """물리 정보 반환"""
        return {
            'mode': self.mode.value,
            'time_scale': self.time_scale,
            'gravity': self.config.gravity,
            'friction': self.config.friction,
            'wind': self.config.wind_force if self.wind_active else None,
            'magnetic_field': self.magnetic_field,
            'slow_motion': self.slow_motion_active
        }