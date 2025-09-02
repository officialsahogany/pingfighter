"""
Smooth Boss Movement System
보스 움직임을 부드럽게 만들기 위한 개선 시스템
"""

import math
import time


class SmoothBossMovement:
    """보스 움직임 스무딩 시스템"""
    
    def __init__(self):
        # 스무딩 설정
        self.smoothing_factor = 0.15  # 0.1~0.3 사이가 적절 (낮을수록 부드러움)
        self.prediction_smoothing = 0.25  # 예측 위치 스무딩
        self.min_movement_threshold = 0.5  # 최소 움직임 임계값
        
        # 보간 시스템
        self.current_position = None
        self.target_position = None
        self.interpolated_position = None
        self.last_update_time = 0
        
        # 속도 스무딩
        self.velocity_history = []
        self.max_history_size = 5
        self.current_smooth_velocity = 0
        
        # 가속도 제한
        self.max_acceleration = 0.8  # 프레임당 최대 가속도
        self.max_velocity = 8.0  # 최대 속도
        
        # 반응 지연 (더 자연스러운 움직임)
        self.reaction_delay = 0.1  # 초 단위
        self.delayed_targets = []
        
        # 데드존 설정 (좁은 반경에서 떨림 방지)
        self.deadzone_radius = 15  # 보스가 무시할 반경
        self.deadzone_active = False
        self.last_significant_target = None
        
        # 타겟 변화 스무딩
        self.target_change_smoothing = 0.3  # 타겟 변경 시 스무딩
        self.last_target = None
        self.target_change_timer = 0
        
    def initialize(self, initial_position):
        """초기화"""
        self.current_position = initial_position
        self.target_position = initial_position
        self.interpolated_position = initial_position
        self.last_update_time = time.time()
        
    def update_target(self, new_target, immediate=False):
        """
        목표 위치 업데이트
        
        Args:
            new_target: 새로운 목표 위치
            immediate: True면 즉시 반응, False면 지연 적용
        """
        if immediate:
            self.target_position = new_target
        else:
            # 반응 지연 적용
            current_time = time.time()
            self.delayed_targets.append({
                'position': new_target,
                'time': current_time + self.reaction_delay
            })
            
    def calculate_smooth_position(self, boss_x, target_x, current_speed, dt=1/60):
        """
        부드러운 위치 계산 (데드존 및 개선된 스무딩 적용)
        
        Args:
            boss_x: 현재 보스 X 위치
            target_x: 목표 X 위치
            current_speed: 현재 속도
            dt: 델타 타임 (기본 60 FPS)
            
        Returns:
            tuple: (새로운 위치, 새로운 속도)
        """
        # 지연된 목표 처리
        current_time = time.time()
        while self.delayed_targets and self.delayed_targets[0]['time'] <= current_time:
            self.target_position = self.delayed_targets.pop(0)['position']
            
        # 목표까지의 거리
        distance = target_x - boss_x
        abs_distance = abs(distance)
        
        # 데드존 처리 - 좁은 반경에서는 움직임 최소화
        if abs_distance < self.deadzone_radius:
            if not self.deadzone_active:
                self.deadzone_active = True
                self.last_significant_target = boss_x
            
            # 데드존 안에서는 매우 느리게만 움직임
            if abs_distance < self.min_movement_threshold:
                # 거의 움직이지 않음
                return boss_x, current_speed * 0.8  # 속도만 감속
            else:
                # 아주 작은 보정만 적용
                target_velocity = distance * 0.03  # 매우 낮은 반응
        else:
            # 데드존 밖으로 나왔을 때
            if self.deadzone_active:
                self.deadzone_active = False
                # 부드럽게 새 목표로 전환
                if self.last_significant_target:
                    target_x = self.apply_easing(self.last_significant_target, target_x, 0.5)
            
            # 거리에 따른 적응형 스무딩 팩터
            if abs_distance > 200:
                # 먼 거리: 빠른 이동
                adaptive_smoothing = self.smoothing_factor * 1.5
            elif abs_distance > 100:
                # 중간 거리: 보통 속도
                adaptive_smoothing = self.smoothing_factor
            elif abs_distance > 50:
                # 가까운 거리: 느린 이동
                adaptive_smoothing = self.smoothing_factor * 0.7
            else:
                # 매우 가까움: 매우 느린 이동
                adaptive_smoothing = self.smoothing_factor * 0.4
            
            # 목표 속도 계산
            target_velocity = distance * adaptive_smoothing
        
        # 속도를 최대 속도로 제한
        target_velocity = max(-self.max_velocity, min(self.max_velocity, target_velocity))
        
        # 부드러운 가속도 제한 (거리에 따라 조정)
        if abs_distance < 30:
            # 가까울 때는 더 부드럽게
            max_accel = self.max_acceleration * 0.3
        elif abs_distance < 60:
            max_accel = self.max_acceleration * 0.5
        else:
            max_accel = self.max_acceleration
            
        velocity_change = target_velocity - current_speed
        if abs(velocity_change) > max_accel:
            velocity_change = max_accel if velocity_change > 0 else -max_accel
            
        # 새로운 속도 계산
        new_velocity = current_speed + velocity_change
        
        # 속도 히스토리 업데이트 (추가 스무딩)
        self.velocity_history.append(new_velocity)
        if len(self.velocity_history) > self.max_history_size:
            self.velocity_history.pop(0)
            
        # 평균 속도 계산 (데드존에서는 더 많은 스무딩)
        if self.velocity_history:
            if self.deadzone_active or abs_distance < 50:
                # 가까울 때는 더 많은 평균화
                smooth_velocity = sum(self.velocity_history) / len(self.velocity_history)
            else:
                # 멀 때는 덜 평균화 (더 반응적)
                recent_weight = 0.6
                old_weight = 0.4 / max(1, len(self.velocity_history) - 1)
                smooth_velocity = (new_velocity * recent_weight + 
                                  sum(self.velocity_history[:-1]) * old_weight)
        else:
            smooth_velocity = new_velocity
            
        # 새로운 위치 계산
        new_position = boss_x + smooth_velocity
        
        return new_position, smooth_velocity
        
    def apply_easing(self, current, target, factor=0.1):
        """
        이징 함수 적용 (ease-out)
        
        Args:
            current: 현재 값
            target: 목표 값
            factor: 이징 팩터 (0~1, 낮을수록 부드러움)
            
        Returns:
            float: 이징이 적용된 새 값
        """
        return current + (target - current) * factor
        
    def calculate_prediction_smoothing(self, ball_x, ball_vel_x, predict_frames):
        """
        예측 위치를 부드럽게 계산
        
        Args:
            ball_x: 공의 현재 X 위치
            ball_vel_x: 공의 X 속도
            predict_frames: 예측할 프레임 수
            
        Returns:
            float: 스무딩된 예측 위치
        """
        # 기본 예측
        raw_prediction = ball_x + ball_vel_x * predict_frames
        
        # 이전 예측과 블렌딩 (갑작스러운 변화 방지)
        if hasattr(self, 'last_prediction'):
            smoothed_prediction = self.apply_easing(
                self.last_prediction, 
                raw_prediction, 
                self.prediction_smoothing
            )
        else:
            smoothed_prediction = raw_prediction
            
        self.last_prediction = smoothed_prediction
        return smoothed_prediction
        
    def apply_confusion_smoothing(self, confusion_target, current_x):
        """
        혼란 상태 움직임 스무딩
        
        Args:
            confusion_target: 혼란 목표 위치
            current_x: 현재 위치
            
        Returns:
            float: 스무딩된 혼란 목표
        """
        # 혼란 상태에서도 부드럽게 움직이도록
        if not hasattr(self, 'smooth_confusion_target'):
            self.smooth_confusion_target = confusion_target
            
        # 천천히 새 목표로 전환
        self.smooth_confusion_target = self.apply_easing(
            self.smooth_confusion_target,
            confusion_target,
            0.08  # 혼란 상태에서는 더 느리게
        )
        
        return self.smooth_confusion_target
        
    def reset_smoothing(self):
        """스무딩 상태 초기화"""
        self.velocity_history.clear()
        self.delayed_targets.clear()
        self.current_smooth_velocity = 0
        if hasattr(self, 'last_prediction'):
            delattr(self, 'last_prediction')
        if hasattr(self, 'smooth_confusion_target'):
            delattr(self, 'smooth_confusion_target')


# 싱글톤 인스턴스
_smooth_movement_instance = None


def get_smooth_movement():
    """싱글톤 인스턴스 반환"""
    global _smooth_movement_instance
    if _smooth_movement_instance is None:
        _smooth_movement_instance = SmoothBossMovement()
    return _smooth_movement_instance


def apply_smooth_boss_movement(boss_x, target_x, current_speed, 
                              max_speed=8, acceleration=0.5, deceleration=0.3):
    """
    기존 코드와의 호환성을 위한 간단한 래퍼 함수
    
    Args:
        boss_x: 현재 보스 X 위치
        target_x: 목표 X 위치  
        current_speed: 현재 속도
        max_speed: 최대 속도
        acceleration: 가속도
        deceleration: 감속도
        
    Returns:
        tuple: (새로운 위치, 새로운 속도)
    """
    smoother = get_smooth_movement()
    
    # 스무더 설정 업데이트
    smoother.max_velocity = max_speed
    smoother.max_acceleration = acceleration
    
    # 부드러운 위치 계산
    new_position, new_speed = smoother.calculate_smooth_position(
        boss_x, target_x, current_speed
    )
    
    return new_position, new_speed