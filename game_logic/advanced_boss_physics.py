"""
Advanced Boss Physics System v2.0
물리 기반 초부드러운 보스 움직임 시스템
PID 컨트롤러 + 간소화된 칼만 필터 + 물리 엔진
"""

import math
import time
from collections import deque


class PIDController:
    """PID 제어기 - 부드러운 움직임 제어"""
    
    def __init__(self, kp=0.4, ki=0.02, kd=0.15):
        self.kp = kp  # 비례 게인
        self.ki = ki  # 적분 게인
        self.kd = kd  # 미분 게인
        
        self.prev_error = 0
        self.integral = 0
        self.last_time = time.time()
        
        # Anti-windup
        self.integral_limit = 100
        self.output_limit = 10
        
    def update(self, target, current, dt=None):
        """PID 제어 업데이트"""
        if dt is None:
            current_time = time.time()
            dt = current_time - self.last_time
            self.last_time = current_time
            
        if dt <= 0:
            dt = 1/60  # 기본값
            
        # 오차 계산
        error = target - current
        
        # 적분 항 (Anti-windup 포함)
        self.integral += error * dt
        self.integral = max(-self.integral_limit, min(self.integral_limit, self.integral))
        
        # 미분 항
        derivative = (error - self.prev_error) / dt if dt > 0 else 0
        
        # PID 출력
        output = self.kp * error + self.ki * self.integral + self.kd * derivative
        
        # 출력 제한
        output = max(-self.output_limit, min(self.output_limit, output))
        
        self.prev_error = error
        return output
        
    def reset(self):
        """PID 상태 초기화"""
        self.prev_error = 0
        self.integral = 0


class SimpleKalmanFilter:
    """간소화된 1D 칼만 필터 - 노이즈 제거 및 예측"""
    
    def __init__(self, process_variance=0.01, measurement_variance=0.1):
        self.q = process_variance  # 프로세스 노이즈
        self.r = measurement_variance  # 측정 노이즈
        
        # 상태 변수
        self.x = 0  # 추정 위치
        self.v = 0  # 추정 속도
        self.p = 1.0  # 추정 오차 공분산
        
        self.initialized = False
        
    def predict(self, dt=1/60):
        """예측 단계"""
        # 위치 예측
        self.x = self.x + self.v * dt
        # 오차 공분산 예측
        self.p = self.p + self.q
        
    def update(self, measurement):
        """업데이트 단계"""
        if not self.initialized:
            self.x = measurement
            self.initialized = True
            return self.x
            
        # 칼만 게인 계산
        k = self.p / (self.p + self.r)
        
        # 상태 업데이트
        residual = measurement - self.x
        self.x = self.x + k * residual
        
        # 속도 추정 (간단한 방법)
        self.v = self.v * 0.9 + residual * 0.1
        
        # 오차 공분산 업데이트
        self.p = (1 - k) * self.p
        
        return self.x
        
    def get_prediction(self, steps_ahead=5, dt=1/60):
        """미래 위치 예측"""
        return self.x + self.v * dt * steps_ahead


class PhysicsEngine:
    """물리 엔진 - 실제 물리법칙 기반 움직임"""
    
    def __init__(self, mass=2.0, friction=0.94):
        self.mass = mass  # 질량
        self.friction = friction  # 마찰 계수 (0.9-0.99)
        
        self.position = 0
        self.velocity = 0
        self.acceleration = 0
        
        # 힘 제한
        self.max_force = 15.0
        self.max_velocity = 8.0
        
    def apply_force(self, force):
        """힘 적용"""
        # 힘 제한
        force = max(-self.max_force, min(self.max_force, force))
        
        # F = ma -> a = F/m
        self.acceleration = force / self.mass
        
    def update(self, dt=1/60):
        """물리 업데이트 (Verlet Integration)"""
        # 속도 업데이트
        self.velocity += self.acceleration * dt
        
        # 마찰 적용
        self.velocity *= self.friction
        
        # 속도 제한
        self.velocity = max(-self.max_velocity, min(self.max_velocity, self.velocity))
        
        # 위치 업데이트
        self.position += self.velocity * dt
        
        # 가속도 리셋
        self.acceleration = 0
        
        return self.position


class AdaptiveBehavior:
    """적응형 행동 시스템 - 상황에 따른 매개변수 조정"""
    
    def __init__(self):
        self.modes = {
            'precision': {  # 정밀 모드 (가까운 거리)
                'pid_kp': 0.2,
                'pid_ki': 0.01,
                'pid_kd': 0.25,
                'mass': 3.0,
                'friction': 0.88,
                'max_force': 8.0
            },
            'normal': {  # 일반 모드
                'pid_kp': 0.4,
                'pid_ki': 0.02,
                'pid_kd': 0.15,
                'mass': 2.0,
                'friction': 0.94,
                'max_force': 12.0
            },
            'tracking': {  # 추적 모드 (먼 거리)
                'pid_kp': 0.6,
                'pid_ki': 0.03,
                'pid_kd': 0.1,
                'mass': 1.5,
                'friction': 0.96,
                'max_force': 20.0
            }
        }
        
    def get_mode(self, distance):
        """거리에 따른 모드 선택"""
        abs_distance = abs(distance)
        
        if abs_distance < 30:
            return 'precision'
        elif abs_distance < 100:
            return 'normal'
        else:
            return 'tracking'
            
    def apply_parameters(self, mode, pid, physics):
        """매개변수 적용"""
        params = self.modes[mode]
        
        # PID 매개변수 부드럽게 전환
        pid.kp = self._smooth_transition(pid.kp, params['pid_kp'], 0.1)
        pid.ki = self._smooth_transition(pid.ki, params['pid_ki'], 0.1)
        pid.kd = self._smooth_transition(pid.kd, params['pid_kd'], 0.1)
        
        # 물리 매개변수 부드럽게 전환
        physics.mass = self._smooth_transition(physics.mass, params['mass'], 0.1)
        physics.friction = self._smooth_transition(physics.friction, params['friction'], 0.05)
        physics.max_force = self._smooth_transition(physics.max_force, params['max_force'], 0.2)
        
    def _smooth_transition(self, current, target, rate):
        """부드러운 매개변수 전환"""
        return current + (target - current) * rate


class UltraSmoothBossMovement:
    """Ultra Smooth Boss Movement System - 최종 통합 시스템"""
    
    def __init__(self):
        # 핵심 컴포넌트
        self.pid = PIDController()
        self.kalman = SimpleKalmanFilter()
        self.physics = PhysicsEngine()
        self.behavior = AdaptiveBehavior()
        
        # 타겟 필터링
        self.target_filter = deque(maxlen=5)
        self.filtered_target = 0
        
        # 출력 스무딩
        self.output_filter = deque(maxlen=3)
        
        # 상태
        self.last_update_time = time.time()
        self.debug_mode = False
        
        # 부가 기능
        self.prediction_enabled = True
        self.adaptive_enabled = True
        
    def update(self, boss_x, ball_x, ball_vel_x=0):
        """메인 업데이트 - 초부드러운 움직임 계산"""
        
        # 시간 계산
        current_time = time.time()
        dt = min(current_time - self.last_update_time, 0.1)  # 최대 100ms
        self.last_update_time = current_time
        
        if dt <= 0:
            dt = 1/60
            
        # 1. 타겟 필터링 (노이즈 제거)
        self.target_filter.append(ball_x)
        if len(self.target_filter) > 0:
            # 가중 평균 (최근 값에 더 많은 가중치)
            weights = [0.1, 0.15, 0.2, 0.25, 0.3][-len(self.target_filter):]
            self.filtered_target = sum(w * t for w, t in zip(weights, self.target_filter)) / sum(weights)
        else:
            self.filtered_target = ball_x
            
        # 2. 칼만 필터로 타겟 예측
        if self.prediction_enabled:
            self.kalman.predict(dt)
            filtered_target = self.kalman.update(self.filtered_target)
            
            # 미래 위치 예측 (3-5 프레임 앞)
            if abs(ball_vel_x) > 0.5:  # 공이 움직일 때만
                prediction_frames = min(5, int(30 / abs(ball_vel_x)))
                predicted_target = self.kalman.get_prediction(prediction_frames, dt)
            else:
                predicted_target = filtered_target
        else:
            predicted_target = self.filtered_target
            
        # 3. 적응형 행동 시스템
        distance = predicted_target - boss_x
        if self.adaptive_enabled:
            mode = self.behavior.get_mode(distance)
            self.behavior.apply_parameters(mode, self.pid, self.physics)
            
        # 4. PID 제어기로 힘 계산
        control_force = self.pid.update(predicted_target, boss_x, dt)
        
        # 5. 물리 엔진에 힘 적용
        self.physics.position = boss_x  # 현재 위치 동기화
        self.physics.apply_force(control_force)
        new_position = self.physics.update(dt)
        
        # 6. 출력 스무딩 (최종 단계)
        self.output_filter.append(new_position)
        if len(self.output_filter) > 0:
            smoothed_position = sum(self.output_filter) / len(self.output_filter)
        else:
            smoothed_position = new_position
            
        # 7. 디버그 정보
        if self.debug_mode:
            self._debug_info(boss_x, ball_x, predicted_target, control_force, smoothed_position)
            
        return smoothed_position, self.physics.velocity
        
    def _debug_info(self, boss_x, ball_x, predicted_target, force, output):
        """디버그 정보 출력"""
        print(f"Boss: {boss_x:.1f} → {output:.1f}")
        print(f"Ball: {ball_x:.1f} → Predicted: {predicted_target:.1f}")
        print(f"Force: {force:.2f}, Velocity: {self.physics.velocity:.2f}")
        print(f"Mode: {self.behavior.get_mode(predicted_target - boss_x)}")
        print("---")
        
    def reset(self):
        """시스템 리셋"""
        self.pid.reset()
        self.kalman = SimpleKalmanFilter()
        self.physics.velocity = 0
        self.physics.acceleration = 0
        self.target_filter.clear()
        self.output_filter.clear()


# 싱글톤 인스턴스
_ultra_smooth_instance = None


def get_ultra_smooth_movement():
    """싱글톤 인스턴스 반환"""
    global _ultra_smooth_instance
    if _ultra_smooth_instance is None:
        _ultra_smooth_instance = UltraSmoothBossMovement()
    return _ultra_smooth_instance


def apply_ultra_smooth_movement(boss_x, ball_x, ball_vel_x=0):
    """간단한 API"""
    smoother = get_ultra_smooth_movement()
    return smoother.update(boss_x, ball_x, ball_vel_x)