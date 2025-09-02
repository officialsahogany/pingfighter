"""
Physics System - 물리 엔진
공의 움직임, 중력, 속도, 가속도 등 물리 관련 처리
"""

import pygame
import math
import random
from typing import Tuple, List, Optional, Dict, Any
from core.game_state import GameState
from core.events import EventType, emit_event
from core.global_manager import GlobalManager


class PhysicsSystem:
    """물리 엔진 시스템"""
    
    def __init__(self):
        self.game_state = GameState.get_instance()
        self.global_manager = GlobalManager.get_instance()
        
        # 기본 물리 상수 (bosspong.py에서 가져옴)
        self.GRAVITY = 0.0  # 기본 중력 (필요시 활성화)
        self.FRICTION = 0.995  # 공기 저항
        self.MIN_SPEED = 3.0  # 최소 속도
        self.MAX_SPEED = 25.0  # 최대 속도
        self.BASE_SPEED = self.global_manager.get('BALL_BASE_SPEED', 9)  # 기본 속도
        
        # 공 상태 (bosspong.py에서 초기값 가져옴)
        width = self.global_manager.get('WIDTH', 600)
        height = self.global_manager.get('HEIGHT', 750)
        self.ball_position = [width // 2, height // 2]  # [x, y]
        self.ball_velocity = [
            self.global_manager.get('BALL_SPEED_X', 5),
            self.global_manager.get('BALL_SPEED_Y', 8)
        ]  # [vx, vy]
        self.ball_acceleration = [0, 0]  # [ax, ay]
        self.ball_spin = 0  # 회전
        self.ball_radius = self.global_manager.get('BALL_RADIUS', 22)
        
        # 물리 효과
        self.impact_boost = 1.0  # 충격 부스트
        self.boost_decay_rate = 0.975  # 부스트 감소율
        self.min_boost = 0.7
        
        # 특수 효과
        self.slow_motion_factor = 1.0  # 슬로우 모션
        self.magnetic_force = 0  # 자기력
        self.wind_force = [0, 0]  # 바람
        
        # 궤적 기록
        self.trajectory = []
        self.max_trajectory_points = 20
        
    def update(self, dt: float):
        """물리 시스템 업데이트
        
        Args:
            dt: 델타 타임 (초)
        """
        # 슬로우 모션 적용
        effective_dt = dt * self.slow_motion_factor
        
        # 가속도 적용
        self.ball_velocity[0] += self.ball_acceleration[0] * effective_dt
        self.ball_velocity[1] += self.ball_acceleration[1] * effective_dt
        
        # 중력 적용
        self.ball_velocity[1] += self.GRAVITY * effective_dt
        
        # 바람 적용
        self.ball_velocity[0] += self.wind_force[0] * effective_dt
        self.ball_velocity[1] += self.wind_force[1] * effective_dt
        
        # 공기 저항 적용
        self.ball_velocity[0] *= self.FRICTION
        self.ball_velocity[1] *= self.FRICTION
        
        # 부스트 감소
        if self.impact_boost > self.min_boost:
            self.impact_boost *= self.boost_decay_rate
            self.impact_boost = max(self.min_boost, self.impact_boost)
            
        # 속도 제한
        self.limit_velocity()
        
        # 위치 업데이트
        self.ball_position[0] += self.ball_velocity[0] * effective_dt * 60  # 60 FPS 기준
        self.ball_position[1] += self.ball_velocity[1] * effective_dt * 60
        
        # 궤적 기록
        self.update_trajectory()
        
    def limit_velocity(self):
        """속도 제한"""
        speed = self.get_speed()
        
        if speed < self.MIN_SPEED:
            # 최소 속도 보장
            if speed > 0:
                factor = self.MIN_SPEED / speed
                self.ball_velocity[0] *= factor
                self.ball_velocity[1] *= factor
        elif speed > self.MAX_SPEED:
            # 최대 속도 제한
            factor = self.MAX_SPEED / speed
            self.ball_velocity[0] *= factor
            self.ball_velocity[1] *= factor
            
    def get_speed(self) -> float:
        """현재 속도 반환"""
        return math.sqrt(self.ball_velocity[0]**2 + self.ball_velocity[1]**2)
        
    def set_velocity(self, vx: float, vy: float):
        """속도 설정
        
        Args:
            vx: X축 속도
            vy: Y축 속도
        """
        self.ball_velocity = [vx, vy]
        
    def add_impulse(self, fx: float, fy: float):
        """충격량 추가 (즉시 속도 변경)
        
        Args:
            fx: X축 충격량
            fy: Y축 충격량
        """
        self.ball_velocity[0] += fx
        self.ball_velocity[1] += fy
        
    def add_force(self, fx: float, fy: float):
        """힘 추가 (가속도로 변환)
        
        Args:
            fx: X축 힘
            fy: Y축 힘
        """
        # F = ma, a = F/m (질량을 1로 가정)
        self.ball_acceleration[0] += fx
        self.ball_acceleration[1] += fy
        
    def apply_spin(self, spin: float):
        """스핀 적용
        
        Args:
            spin: 스핀 값 (-1 ~ 1)
        """
        self.ball_spin = max(-1, min(1, spin))
        
        # 스핀에 따른 속도 변경
        spin_effect = self.ball_spin * 0.3
        self.ball_velocity[0] += spin_effect * abs(self.ball_velocity[1])
        
    def apply_power_shot(self, power: float = 1.5):
        """파워샷 적용
        
        Args:
            power: 파워 배수
        """
        self.ball_velocity[0] *= power
        self.ball_velocity[1] *= power
        self.impact_boost = min(2.0, self.impact_boost * power)
        
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'power_shot',
            'power': power
        })
        
    def apply_curve_ball(self, direction: int):
        """커브볼 효과 적용
        
        Args:
            direction: -1(왼쪽) or 1(오른쪽)
        """
        curve_strength = 0.5
        self.ball_velocity[0] += direction * curve_strength * abs(self.ball_velocity[1])
        self.apply_spin(direction * 0.5)
        
    def apply_slow_motion(self, factor: float, duration: float = 0):
        """슬로우 모션 적용
        
        Args:
            factor: 시간 배속 (0.5 = 절반 속도)
            duration: 지속 시간 (0 = 무한)
        """
        self.slow_motion_factor = factor
        
        if duration > 0:
            # 일정 시간 후 원래 속도로 복구
            # (실제 구현에서는 타이머 시스템 필요)
            pass
            
    def apply_magnetic_effect(self, target_x: float, strength: float):
        """자기장 효과 적용
        
        Args:
            target_x: 자기장 중심 X 좌표
            strength: 자기장 강도
        """
        dx = target_x - self.ball_position[0]
        distance = abs(dx)
        
        if distance > 0 and distance < 200:  # 유효 범위
            # 거리에 반비례하는 힘
            force = strength * (1 - distance / 200) * (dx / distance)
            self.add_force(force, 0)
            
    def bounce(self, normal: Tuple[float, float], damping: float = 0.95):
        """표면에서 튕기기
        
        Args:
            normal: 표면의 법선 벡터 (정규화됨)
            damping: 반발 계수 (0~1)
        """
        # 법선 방향 속도 성분
        dot = self.ball_velocity[0] * normal[0] + self.ball_velocity[1] * normal[1]
        
        # 반사 벡터 계산
        self.ball_velocity[0] -= 2 * dot * normal[0]
        self.ball_velocity[1] -= 2 * dot * normal[1]
        
        # 감쇠 적용
        self.ball_velocity[0] *= damping
        self.ball_velocity[1] *= damping
        
    def predict_position(self, time_ahead: float) -> Tuple[float, float]:
        """미래 위치 예측
        
        Args:
            time_ahead: 예측할 시간 (초)
            
        Returns:
            예측된 (x, y) 위치
        """
        # 간단한 선형 예측 (가속도 무시)
        future_x = self.ball_position[0] + self.ball_velocity[0] * time_ahead * 60
        future_y = self.ball_position[1] + self.ball_velocity[1] * time_ahead * 60
        
        return (future_x, future_y)
        
    def update_trajectory(self):
        """궤적 업데이트"""
        # 현재 위치를 궤적에 추가
        self.trajectory.append(tuple(self.ball_position))
        
        # 최대 개수 유지
        if len(self.trajectory) > self.max_trajectory_points:
            self.trajectory.pop(0)
            
    def get_trajectory(self) -> List[Tuple[float, float]]:
        """궤적 반환"""
        return self.trajectory.copy()
        
    def reset(self, x: float = 300, y: float = 375):
        """물리 시스템 리셋
        
        Args:
            x: 초기 X 위치
            y: 초기 Y 위치
        """
        self.ball_position = [x, y]
        self.ball_velocity = [
            random.uniform(-3, 3),
            random.choice([-self.BASE_SPEED, self.BASE_SPEED])
        ]
        self.ball_acceleration = [0, 0]
        self.ball_spin = 0
        self.impact_boost = 1.0
        self.trajectory.clear()
        
    def serve_ball(self, server: str = 'player'):
        """서브
        
        Args:
            server: 'player' or 'boss'
        """
        if server == 'player':
            self.ball_position[1] = 600
            self.ball_velocity[1] = -self.BASE_SPEED
        else:
            self.ball_position[1] = 150
            self.ball_velocity[1] = self.BASE_SPEED
            
        self.ball_velocity[0] = random.uniform(-3, 3)
        
        emit_event(EventType.ROUND_START, {'server': server})
        
    def get_state(self) -> Dict[str, Any]:
        """현재 물리 상태 반환"""
        return {
            'position': tuple(self.ball_position),
            'velocity': tuple(self.ball_velocity),
            'speed': self.get_speed(),
            'acceleration': tuple(self.ball_acceleration),
            'spin': self.ball_spin,
            'impact_boost': self.impact_boost
        }
        
    def set_state(self, state: Dict[str, Any]):
        """물리 상태 설정"""
        if 'position' in state:
            self.ball_position = list(state['position'])
        if 'velocity' in state:
            self.ball_velocity = list(state['velocity'])
        if 'acceleration' in state:
            self.ball_acceleration = list(state['acceleration'])
        if 'spin' in state:
            self.ball_spin = state['spin']
        if 'impact_boost' in state:
            self.impact_boost = state['impact_boost']


# 싱글톤 인스턴스
_physics_system = None

def get_physics_system() -> PhysicsSystem:
    """물리 시스템 인스턴스 반환"""
    global _physics_system
    if _physics_system is None:
        _physics_system = PhysicsSystem()
    return _physics_system

def reset_physics_system():
    """물리 시스템 리셋"""
    global _physics_system
    _physics_system = None