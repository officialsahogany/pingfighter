"""
Paddle Entity - 패들 엔티티
플레이어와 보스 패들의 동작과 렌더링을 관리
"""

import pygame
import math
from typing import Tuple, Optional, Dict, Any
from entities.entity import Entity
from core.events import EventType, emit_event
from dash_manager import DashManager


class Paddle(Entity):
    """패들 엔티티 클래스"""
    
    def __init__(self, x: float, y: float, is_player: bool = True):
        """패들 초기화
        
        Args:
            x: 초기 X 좌표
            y: 초기 Y 좌표
            is_player: 플레이어 패들 여부
        """
        super().__init__(x, y)
        
        # 패들 속성
        self.is_player = is_player
        self.width = 100
        self.height = 20
        self.size = pygame.Vector2(self.width, self.height)
        
        # 이동 속성
        self.base_speed = 8.0
        self.speed = self.base_speed
        self.max_speed = 15.0
        self.acceleration_rate = 0.5
        
        # 대시 시스템
        if is_player:
            self.dash_manager = DashManager()
        else:
            self.dash_manager = None
            
        # 시각 효과
        self.color = (0, 255, 0) if is_player else (255, 0, 0)
        self.glow_color = (0, 200, 0) if is_player else (200, 0, 0)
        self.trail_color = (0, 150, 0) if is_player else (150, 0, 0)
        
        # 특수 효과
        self.is_charged = False
        self.charge_timer = 0
        self.charge_level = 0
        self.max_charge = 1.0
        
        # 파워업 상태
        self.power_ups = {
            'wide_paddle': False,
            'sticky_paddle': False,
            'magnetic_paddle': False,
            'shield': False
        }
        self.power_up_timers = {}
        
        # 트레일 효과
        self.trail_points = []
        self.max_trail_points = 5
        
        # 애니메이션
        self.hit_animation_timer = 0
        self.hit_animation_scale = 1.0
        
        # 입력 상태 (플레이어용)
        self.input_direction = 0
        self.is_charging = False
        
        # AI 상태 (보스용)
        self.ai_target_x = x
        self.ai_reaction_time = 0.1
        self.ai_prediction_time = 0.5
        
        # 태그 설정
        self.add_tag("paddle")
        if is_player:
            self.add_tag("player")
            self.add_to_group("player_group")
        else:
            self.add_tag("boss")
            self.add_to_group("boss_group")
            
        # Rect 업데이트
        self.update_rect()
        
    def update(self, dt: float):
        """패들 업데이트
        
        Args:
            dt: 델타 타임
        """
        if not self.active:
            return
            
        # 입력 처리 (플레이어) 또는 AI 업데이트 (보스)
        if self.is_player:
            self.handle_input(dt)
        else:
            self.update_ai(dt)
            
        # 이동 처리
        self.update_movement(dt)
        
        # 파워업 업데이트
        self.update_power_ups(dt)
        
        # 차징 업데이트
        self.update_charging(dt)
        
        # 대시 업데이트
        if self.dash_manager:
            self.dash_manager.update(dt)
            
        # 트레일 업데이트
        self.update_trail()
        
        # 애니메이션 업데이트
        self.update_animation(dt)
        
        # Rect 업데이트
        self.update_rect()
        
    def handle_input(self, dt: float):
        """입력 처리 (플레이어용)
        
        Args:
            dt: 델타 타임
        """
        keys = pygame.key.get_pressed()
        
        # 이동 입력
        self.input_direction = 0
        if keys[pygame.K_LEFT] or keys[pygame.K_a]:
            self.input_direction = -1
        elif keys[pygame.K_RIGHT] or keys[pygame.K_d]:
            self.input_direction = 1
            
        # 대시 입력
        if self.dash_manager:
            if keys[pygame.K_LSHIFT] or keys[pygame.K_RSHIFT]:
                if self.dash_manager.can_dash():
                    self.perform_dash()
                    
        # 차징 입력
        if keys[pygame.K_SPACE]:
            self.is_charging = True
        else:
            if self.is_charging and self.charge_level > 0.5:
                self.release_charge()
            self.is_charging = False
            
    def update_ai(self, dt: float):
        """AI 업데이트 (보스용)
        
        Args:
            dt: 델타 타임
        """
        # 간단한 AI: 공을 따라가기
        # (실제 AI는 나중에 AI 시스템에서 구현)
        
        # 목표 위치로 부드럽게 이동
        diff = self.ai_target_x - self.position.x
        
        if abs(diff) > 5:
            self.input_direction = 1 if diff > 0 else -1
        else:
            self.input_direction = 0
            
    def update_movement(self, dt: float):
        """이동 업데이트
        
        Args:
            dt: 델타 타임
        """
        if self.input_direction != 0:
            # 가속
            self.speed = min(self.speed + self.acceleration_rate, self.max_speed)
            
            # 이동
            move_distance = self.speed * self.input_direction
            
            # 대시 중이면 속도 증가
            if self.dash_manager and self.dash_manager.is_dashing:
                move_distance *= 3.0
                
            self.position.x += move_distance
            
            # 화면 경계 체크
            self.position.x = max(self.width / 2, 
                                 min(600 - self.width / 2, self.position.x))
        else:
            # 감속
            self.speed = max(self.base_speed, self.speed * 0.9)
            
    def update_power_ups(self, dt: float):
        """파워업 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 파워업 타이머 업데이트
        for power_up, timer in list(self.power_up_timers.items()):
            self.power_up_timers[power_up] = timer - dt
            if self.power_up_timers[power_up] <= 0:
                self.deactivate_power_up(power_up)
                del self.power_up_timers[power_up]
                
        # 와이드 패들 효과
        if self.power_ups['wide_paddle']:
            self.width = 150
        else:
            self.width = 100
            
        self.size.x = self.width
        
    def update_charging(self, dt: float):
        """차징 업데이트
        
        Args:
            dt: 델타 타임
        """
        if self.is_charging:
            # 차지 레벨 증가
            self.charge_level = min(self.charge_level + dt, self.max_charge)
            self.is_charged = self.charge_level >= self.max_charge
            
            if self.is_charged:
                # 차지 완료 효과
                emit_event(EventType.SPECIAL_CHARGED, {
                    'paddle': 'player' if self.is_player else 'boss'
                })
        else:
            # 차지 레벨 감소
            if self.charge_level > 0:
                self.charge_level = max(0, self.charge_level - dt * 2)
                if self.charge_level == 0:
                    self.is_charged = False
                    
    def update_trail(self):
        """트레일 효과 업데이트"""
        # 대시 중이거나 빠르게 움직일 때만 트레일 생성
        if (self.dash_manager and self.dash_manager.is_dashing) or abs(self.velocity.x) > 5:
            self.trail_points.append({
                'pos': self.position.copy(),
                'width': self.width,
                'alpha': 100
            })
            
            # 트레일 포인트 수 제한
            if len(self.trail_points) > self.max_trail_points:
                self.trail_points.pop(0)
                
        # 트레일 페이드
        for point in self.trail_points:
            point['alpha'] *= 0.9
            
        # 투명도가 낮은 포인트 제거
        self.trail_points = [p for p in self.trail_points if p['alpha'] > 10]
        
    def update_animation(self, dt: float):
        """애니메이션 업데이트
        
        Args:
            dt: 델타 타임
        """
        if self.hit_animation_timer > 0:
            self.hit_animation_timer -= dt
            # 스케일 애니메이션
            progress = self.hit_animation_timer / 0.3
            self.hit_animation_scale = 1.0 + 0.2 * math.sin(progress * math.pi)
        else:
            self.hit_animation_scale = 1.0
            
    def render(self, screen: pygame.Surface, camera_offset: Tuple[int, int] = (0, 0)):
        """패들 렌더링
        
        Args:
            screen: 렌더링할 화면
            camera_offset: 카메라 오프셋
        """
        if not self.visible:
            return
            
        # 렌더링 위치 계산
        render_x = int(self.position.x - camera_offset[0])
        render_y = int(self.position.y - camera_offset[1])
        
        # 트레일 렌더링
        self.render_trail(screen, camera_offset)
        
        # 차징 효과 렌더링
        if self.charge_level > 0:
            self.render_charge_effect(screen, render_x, render_y)
            
        # 파워업 효과 렌더링
        if self.power_ups['shield']:
            self.render_shield(screen, render_x, render_y)
            
        # 패들 본체 렌더링
        width = int(self.width * self.hit_animation_scale)
        height = int(self.height * self.hit_animation_scale)
        
        paddle_rect = pygame.Rect(
            render_x - width // 2,
            render_y - height // 2,
            width,
            height
        )
        
        # 패들 색상 결정
        color = self.color
        if self.is_charged:
            # 차징 완료 시 밝은 색상
            color = tuple(min(255, c + 100) for c in self.color)
            
        pygame.draw.rect(screen, color, paddle_rect)
        
        # 테두리 렌더링
        pygame.draw.rect(screen, (255, 255, 255), paddle_rect, 2)
        
        # 대시 쿨다운 표시 (플레이어용)
        if self.is_player and self.dash_manager:
            self.render_dash_cooldown(screen, render_x, render_y)
            
    def render_trail(self, screen: pygame.Surface, camera_offset: Tuple[int, int]):
        """트레일 효과 렌더링
        
        Args:
            screen: 렌더링할 화면
            camera_offset: 카메라 오프셋
        """
        for point in self.trail_points:
            x = int(point['pos'].x - camera_offset[0])
            y = int(point['pos'].y - camera_offset[1])
            width = int(point['width'])
            alpha = int(point['alpha'])
            
            if alpha > 0:
                s = pygame.Surface((width, self.height), pygame.SRCALPHA)
                color = (*self.trail_color, alpha)
                s.fill(color)
                screen.blit(s, (x - width // 2, y - self.height // 2))
                
    def render_charge_effect(self, screen: pygame.Surface, x: int, y: int):
        """차징 효과 렌더링
        
        Args:
            screen: 렌더링할 화면
            x: X 좌표
            y: Y 좌표
        """
        charge_width = int(self.width * self.charge_level)
        charge_height = int(self.height + 10 * self.charge_level)
        
        s = pygame.Surface((charge_width, charge_height), pygame.SRCALPHA)
        alpha = int(100 * self.charge_level)
        color = (*self.glow_color, alpha)
        s.fill(color)
        
        screen.blit(s, (x - charge_width // 2, y - charge_height // 2))
        
    def render_shield(self, screen: pygame.Surface, x: int, y: int):
        """실드 효과 렌더링
        
        Args:
            screen: 렌더링할 화면
            x: X 좌표
            y: Y 좌표
        """
        shield_radius = int(max(self.width, self.height) * 0.7)
        s = pygame.Surface((shield_radius * 2, shield_radius * 2), pygame.SRCALPHA)
        pygame.draw.circle(s, (100, 100, 255, 50), 
                         (shield_radius, shield_radius), shield_radius)
        pygame.draw.circle(s, (150, 150, 255, 100), 
                         (shield_radius, shield_radius), shield_radius, 2)
        screen.blit(s, (x - shield_radius, y - shield_radius))
        
    def render_dash_cooldown(self, screen: pygame.Surface, x: int, y: int):
        """대시 쿨다운 표시
        
        Args:
            screen: 렌더링할 화면
            x: X 좌표
            y: Y 좌표
        """
        if not self.dash_manager.can_dash():
            # 쿨다운 바 표시
            cooldown_ratio = self.dash_manager.get_cooldown_ratio()
            bar_width = int(self.width * cooldown_ratio)
            bar_height = 4
            
            bar_rect = pygame.Rect(
                x - self.width // 2,
                y + self.height // 2 + 5,
                bar_width,
                bar_height
            )
            
            pygame.draw.rect(screen, (100, 100, 255), bar_rect)
            
    def on_collision(self, other: Entity):
        """충돌 이벤트 처리
        
        Args:
            other: 충돌한 엔티티
        """
        if other.has_tag("ball"):
            # 히트 애니메이션 시작
            self.hit_animation_timer = 0.3
            
            # 차징된 상태면 특수 효과
            if self.is_charged:
                emit_event(EventType.SPECIAL_ACTIVATED, {
                    'type': 'charged_hit',
                    'paddle': 'player' if self.is_player else 'boss'
                })
                self.charge_level = 0
                self.is_charged = False
                
    def perform_dash(self):
        """대시 실행"""
        if self.dash_manager and self.dash_manager.start_dash():
            # 대시 이벤트
            emit_event(EventType.DASH_STARTED, {
                'paddle': 'player' if self.is_player else 'boss'
            })
            
            # 트레일 효과 강화
            self.max_trail_points = 10
            
    def release_charge(self):
        """차지 해제"""
        if self.charge_level > 0.5:
            # 차지샷 발동
            emit_event(EventType.SPECIAL_ACTIVATED, {
                'type': 'charge_shot',
                'paddle': 'player' if self.is_player else 'boss',
                'power': self.charge_level
            })
            
        self.charge_level = 0
        self.is_charged = False
        
    def activate_power_up(self, power_up: str, duration: float = 5.0):
        """파워업 활성화
        
        Args:
            power_up: 파워업 이름
            duration: 지속 시간
        """
        if power_up in self.power_ups:
            self.power_ups[power_up] = True
            self.power_up_timers[power_up] = duration
            
            emit_event(EventType.ITEM_ACTIVATED, {
                'item': power_up,
                'paddle': 'player' if self.is_player else 'boss'
            })
            
    def deactivate_power_up(self, power_up: str):
        """파워업 비활성화
        
        Args:
            power_up: 파워업 이름
        """
        if power_up in self.power_ups:
            self.power_ups[power_up] = False
            
            emit_event(EventType.ITEM_EXPIRED, {
                'item': power_up,
                'paddle': 'player' if self.is_player else 'boss'
            })
            
    def set_ai_target(self, target_x: float):
        """AI 목표 위치 설정 (보스용)
        
        Args:
            target_x: 목표 X 좌표
        """
        self.ai_target_x = target_x
        
    def reset(self):
        """패들 리셋"""
        super().reset()
        
        # 위치 리셋
        if self.is_player:
            self.position.x = 300
            self.position.y = 650
        else:
            self.position.x = 300
            self.position.y = 100
            
        # 상태 리셋
        self.speed = self.base_speed
        self.charge_level = 0
        self.is_charged = False
        self.is_charging = False
        
        # 파워업 리셋
        for power_up in self.power_ups:
            self.power_ups[power_up] = False
        self.power_up_timers.clear()
        
        # 시각 효과 리셋
        self.trail_points.clear()
        self.hit_animation_timer = 0
        
        # 대시 리셋
        if self.dash_manager:
            self.dash_manager.reset()