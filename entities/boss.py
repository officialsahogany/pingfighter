"""
👾 Boss Entity
보스 엔티티 - 각 스테이지별 보스 캐릭터
"""

import pygame
import math
import random
from typing import Optional, Tuple, Dict, Any
from dataclasses import dataclass
from enum import Enum


class BossType(Enum):
    """보스 타입 열거형"""
    NORMAL = "normal"
    CROCODILE = "crocodile"  # Stage 2
    EMOTIONAL = "emotional"  # Stage 3
    SHAOLIN = "shaolin"      # Stage 4
    HONGRYUN = "hongryun"    # Stage 5
    CARRIER = "carrier"      # Stage 6


@dataclass
class BossConfig:
    """보스 설정 데이터 클래스"""
    acceleration: float = 0.5
    deceleration: float = 0.3
    max_speed: float = 7.0
    instant_stop_decel: float = 0.8
    width: int = 80
    height: int = 15
    color: Tuple[int, int, int] = (255, 255, 255)
    boss_type: BossType = BossType.NORMAL
    health: Optional[int] = None  # 체력형 보스용


class Boss:
    """
    👾 보스 엔티티 클래스
    
    각 스테이지의 보스를 표현하며, AI 움직임과 스킬을 관리합니다.
    """
    
    def __init__(self, x: int, y: int, stage: int = 1, config: Optional[BossConfig] = None):
        """
        보스 초기화
        
        Args:
            x: 초기 X 좌표
            y: 초기 Y 좌표
            stage: 스테이지 번호
            config: 보스 설정 (None일 경우 스테이지별 기본값 사용)
        """
        self.initial_x = x
        self.initial_y = y
        self.stage = stage
        
        # 설정 적용
        if config:
            self.config = config
        else:
            self.config = self._get_stage_config(stage)
        
        # 위치 및 속도
        self.x = x
        self.y = y
        self.vel_x = 0
        self.vel_y = 0
        
        # 렉트 생성
        self.rect = pygame.Rect(
            self.x - self.config.width // 2,
            self.y - self.config.height // 2,
            self.config.width,
            self.config.height
        )
        
        # AI 상태
        self.ai_target_x = x
        self.ai_prediction_time = 0
        self.ai_reaction_delay = 0.1  # 반응 지연 시간
        self.ai_error_margin = 10  # AI 오차 범위
        
        # 스킬 관련
        self.skill_cooldown = 0
        self.skill_active = False
        self.skill_timer = 0
        
        # 체력 (체력형 보스용)
        if self.config.health:
            self.max_health = self.config.health
            self.current_health = self.config.health
            self.displayed_health = self.config.health
            self.damage_preview = self.config.health
        
        # 특수 상태
        self.is_stunned = False
        self.stun_timer = 0
        self.is_invincible = False
        self.invincible_timer = 0
        
        # 애니메이션
        self.animation_timer = 0
        self.shake_offset_x = 0
        self.shake_offset_y = 0
        
        print(f"👾 Stage {stage} 보스 생성 완료")
    
    def _get_stage_config(self, stage: int) -> BossConfig:
        """스테이지별 보스 설정 가져오기"""
        configs = {
            1: BossConfig(
                acceleration=0.5,
                deceleration=0.3,
                max_speed=7.0,
                color=(255, 255, 255),
                boss_type=BossType.NORMAL
            ),
            2: BossConfig(
                acceleration=0.6,
                deceleration=0.35,
                max_speed=8.0,
                color=(100, 255, 100),
                boss_type=BossType.CROCODILE,
                health=15
            ),
            3: BossConfig(
                acceleration=0.55,
                deceleration=0.32,
                max_speed=7.5,
                color=(255, 255, 0),
                boss_type=BossType.EMOTIONAL,
                health=15
            ),
            4: BossConfig(
                acceleration=0.65,
                deceleration=0.38,
                max_speed=8.5,
                color=(255, 255, 255),
                boss_type=BossType.SHAOLIN
            ),
            5: BossConfig(
                acceleration=0.7,
                deceleration=0.4,
                max_speed=9.0,
                color=(255, 80, 0),
                boss_type=BossType.HONGRYUN,
                health=20
            ),
            6: BossConfig(
                acceleration=0.75,
                deceleration=0.42,
                max_speed=9.5,
                color=(150, 200, 255),
                boss_type=BossType.CARRIER,
                health=25
            )
        }
        return configs.get(stage, configs[1])
    
    def update(self, dt: float, ball: Any, player: Optional[Any] = None):
        """
        보스 업데이트
        
        Args:
            dt: 델타 타임
            ball: 공 객체
            player: 플레이어 객체 (선택적)
        """
        # 스턴 상태 체크
        if self.is_stunned:
            self.stun_timer -= dt
            if self.stun_timer <= 0:
                self.is_stunned = False
            return  # 스턴 중에는 움직이지 않음
        
        # 무적 상태 업데이트
        if self.is_invincible:
            self.invincible_timer -= dt
            if self.invincible_timer <= 0:
                self.is_invincible = False
        
        # AI 움직임 계산
        self._update_ai(ball, dt)
        
        # 속도 적용
        self._apply_movement(dt)
        
        # 스킬 업데이트
        self._update_skills(dt, ball, player)
        
        # 애니메이션 업데이트
        self._update_animation(dt)
        
        # 렉트 업데이트
        self.rect.centerx = int(self.x + self.shake_offset_x)
        self.rect.centery = int(self.y + self.shake_offset_y)
    
    def _update_ai(self, ball: Any, dt: float):
        """AI 움직임 업데이트"""
        # 공 위치 예측
        predicted_x = self._predict_ball_position(ball)
        
        # 목표 위치 설정 (약간의 오차 추가)
        error = random.uniform(-self.ai_error_margin, self.ai_error_margin)
        self.ai_target_x = predicted_x + error
        
        # 목표를 향해 이동
        diff = self.ai_target_x - self.x
        
        if abs(diff) > 5:  # 데드존
            if diff > 0:
                # 오른쪽으로 가속
                self.vel_x = min(
                    self.vel_x + self.config.acceleration,
                    self.config.max_speed
                )
            else:
                # 왼쪽으로 가속
                self.vel_x = max(
                    self.vel_x - self.config.acceleration,
                    -self.config.max_speed
                )
        else:
            # 감속
            if self.vel_x > 0:
                self.vel_x = max(0, self.vel_x - self.config.deceleration)
            elif self.vel_x < 0:
                self.vel_x = min(0, self.vel_x + self.config.deceleration)
    
    def _predict_ball_position(self, ball: Any) -> float:
        """공 위치 예측"""
        if not hasattr(ball, 'x') or not hasattr(ball, 'vel_x'):
            return self.x
        
        # 공이 보스에게 접근 중일 때만 예측
        if hasattr(ball, 'vel_y') and ball.vel_y < 0:
            # 공이 보스에 도달할 시간 계산
            if ball.vel_y != 0:
                time_to_reach = (self.y - ball.y) / abs(ball.vel_y)
                # 예측 위치 계산
                predicted_x = ball.x + ball.vel_x * time_to_reach
                return predicted_x
        
        return ball.x
    
    def _apply_movement(self, dt: float):
        """움직임 적용"""
        # 속도 제한
        self.vel_x = max(-self.config.max_speed, min(self.vel_x, self.config.max_speed))
        
        # 위치 업데이트
        self.x += self.vel_x
        
        # 화면 경계 체크
        half_width = self.config.width // 2
        if self.x < half_width:
            self.x = half_width
            self.vel_x = 0
        elif self.x > 600 - half_width:  # TODO: 화면 너비 상수화
            self.x = 600 - half_width
            self.vel_x = 0
    
    def _update_skills(self, dt: float, ball: Any, player: Optional[Any]):
        """스킬 업데이트"""
        # 스킬 쿨다운 감소
        if self.skill_cooldown > 0:
            self.skill_cooldown -= dt
        
        # 스킬 활성 상태 업데이트
        if self.skill_active:
            self.skill_timer -= dt
            if self.skill_timer <= 0:
                self.skill_active = False
        
        # 스테이지별 특수 스킬 체크
        if self.skill_cooldown <= 0:
            self._check_skill_activation(ball, player)
    
    def _check_skill_activation(self, ball: Any, player: Optional[Any]):
        """스킬 활성화 체크"""
        # 스테이지별 스킬 활성화 조건
        if self.config.boss_type == BossType.CROCODILE:
            # 악어 보스: 물 공격
            if random.random() < 0.01:  # 1% 확률
                self.activate_skill("water_attack")
        elif self.config.boss_type == BossType.EMOTIONAL:
            # 감정 보스: 눈물 공격
            if random.random() < 0.008:
                self.activate_skill("tears")
        elif self.config.boss_type == BossType.SHAOLIN:
            # 소림사 보스: 명상
            if random.random() < 0.01:
                self.activate_skill("meditation")
        elif self.config.boss_type == BossType.HONGRYUN:
            # 홍련 보스: 화염탄
            if random.random() < 0.012:
                self.activate_skill("fireball")
        elif self.config.boss_type == BossType.CARRIER:
            # 항공모함 보스: 미사일
            if random.random() < 0.015:
                self.activate_skill("missile")
    
    def activate_skill(self, skill_name: str):
        """스킬 활성화"""
        if self.skill_cooldown > 0:
            return False
        
        self.skill_active = True
        self.skill_timer = 3.0  # 3초 지속
        self.skill_cooldown = 5.0  # 5초 쿨다운
        
        print(f"🔥 보스 스킬 발동: {skill_name}")
        return True
    
    def _update_animation(self, dt: float):
        """애니메이션 업데이트"""
        self.animation_timer += dt
        
        # 흔들림 효과 (피격 시 등)
        if self.shake_offset_x != 0:
            self.shake_offset_x *= 0.9
            if abs(self.shake_offset_x) < 0.1:
                self.shake_offset_x = 0
        
        if self.shake_offset_y != 0:
            self.shake_offset_y *= 0.9
            if abs(self.shake_offset_y) < 0.1:
                self.shake_offset_y = 0
    
    def take_damage(self, amount: int = 1):
        """데미지 받기"""
        if self.is_invincible:
            return False
        
        if hasattr(self, 'current_health'):
            self.current_health -= amount
            self.damage_preview = self.current_health
            
            # 흔들림 효과
            self.shake_offset_x = random.uniform(-5, 5)
            self.shake_offset_y = random.uniform(-2, 2)
            
            # 짧은 무적 시간
            self.is_invincible = True
            self.invincible_timer = 0.5
            
            print(f"💥 보스 피격! 체력: {self.current_health}/{self.max_health}")
            return True
        
        return False
    
    def stun(self, duration: float):
        """스턴 효과 적용"""
        self.is_stunned = True
        self.stun_timer = duration
        self.vel_x = 0
        print(f"⚡ 보스 스턴! ({duration}초)")
    
    def reset(self, x: Optional[int] = None, y: Optional[int] = None):
        """보스 리셋"""
        self.x = x if x is not None else self.initial_x
        self.y = y if y is not None else self.initial_y
        self.vel_x = 0
        self.vel_y = 0
        self.skill_cooldown = 0
        self.skill_active = False
        self.is_stunned = False
        self.is_invincible = False
        
        if hasattr(self, 'current_health'):
            self.current_health = self.max_health
            self.displayed_health = self.max_health
            self.damage_preview = self.max_health
        
        self.rect.centerx = self.x
        self.rect.centery = self.y
    
    def render(self, screen: pygame.Surface):
        """보스 렌더링"""
        # 무적 상태일 때 깜빡임
        if self.is_invincible and int(self.animation_timer * 10) % 2:
            return
        
        # 보스 색상 (스턴 상태일 때 어둡게)
        color = self.config.color
        if self.is_stunned:
            color = tuple(c // 2 for c in color)
        
        # 보스 그리기
        pygame.draw.rect(screen, color, self.rect)
        
        # 보스 타입별 추가 렌더링
        if self.config.boss_type == BossType.CROCODILE:
            self._render_crocodile_features(screen)
        elif self.config.boss_type == BossType.CARRIER:
            self._render_carrier_features(screen)
    
    def _render_crocodile_features(self, screen: pygame.Surface):
        """악어 보스 특징 렌더링"""
        # 악어 눈
        eye_color = (255, 0, 0) if self.skill_active else (255, 255, 0)
        pygame.draw.circle(screen, eye_color, (self.rect.left + 20, self.rect.centery), 5)
        pygame.draw.circle(screen, eye_color, (self.rect.right - 20, self.rect.centery), 5)
        
        # 악어 이빨
        for i in range(3):
            x = self.rect.left + 25 + i * 20
            points = [
                (x, self.rect.bottom),
                (x + 5, self.rect.bottom + 5),
                (x + 10, self.rect.bottom)
            ]
            pygame.draw.polygon(screen, (255, 255, 255), points)
    
    def _render_carrier_features(self, screen: pygame.Surface):
        """항공모함 보스 특징 렌더링"""
        # 함교
        tower_rect = pygame.Rect(
            self.rect.centerx - 10,
            self.rect.top - 10,
            20,
            10
        )
        pygame.draw.rect(screen, (100, 100, 100), tower_rect)
        
        # 활주로 라인
        pygame.draw.line(
            screen,
            (255, 255, 0),
            (self.rect.left + 10, self.rect.centery),
            (self.rect.right - 10, self.rect.centery),
            2
        )
    
    def get_state(self) -> Dict[str, Any]:
        """보스 상태 반환"""
        state = {
            'x': self.x,
            'y': self.y,
            'vel_x': self.vel_x,
            'vel_y': self.vel_y,
            'stage': self.stage,
            'boss_type': self.config.boss_type.value,
            'skill_active': self.skill_active,
            'is_stunned': self.is_stunned,
            'is_invincible': self.is_invincible
        }
        
        if hasattr(self, 'current_health'):
            state['health'] = self.current_health
            state['max_health'] = self.max_health
        
        return state