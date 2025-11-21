"""
Dash Manager - 대시 시스템
플레이어 대시(회피) 기능 관리
"""

import pygame
from typing import Dict, Optional, Tuple
from core.global_manager import GlobalManager
from core.events import EventType, emit_event
from managers.effects_manager import get_effects_manager
from core.input_keys import is_move_down_pressed, is_move_left_pressed, is_move_right_pressed


class DashManager:
    """대시 관리 시스템"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        self.effects_manager = get_effects_manager()
        
        # 대시 상태
        self.dash_active = False
        self.dash_timer = 0
        self.dash_cooldown = 0
        self.dash_direction = 0  # -1: 왼쪽, 0: 제자리, 1: 오른쪽
        
        # 대시 설정
        self.dash_speed = 15  # 대시 속도
        self.dash_duration = 0.25  # 대시 지속시간 (초)
        self.dash_cooldown_time = 1.0  # 대시 쿨다운 (초)
        self.dash_invulnerable = True  # 대시 중 무적 여부
        
        # 대시 능력치 (업그레이드 가능)
        self.dash_charges = 1  # 대시 충전 수
        self.current_charges = 1
        self.dash_damage = 0  # 대시로 적에게 주는 데미지
        self.dash_trail = True  # 잔상 효과 여부
        
        # 롤링 애니메이션 설정
        self.rolling_angle = 0
        self.rolling_speed = 720  # 초당 회전 각도
        
    def can_dash(self) -> bool:
        """대시 가능 여부 확인
        
        Returns:
            대시 가능 여부
        """
        return not self.dash_active and self.current_charges > 0 and self.dash_cooldown <= 0
        
    def start_dash(self, direction: int = 0) -> bool:
        """대시 시작
        
        Args:
            direction: 대시 방향 (-1: 왼쪽, 0: 제자리, 1: 오른쪽)
            
        Returns:
            대시 시작 성공 여부
        """
        if not self.can_dash():
            return False
            
        self.dash_active = True
        self.dash_timer = self.dash_duration
        self.dash_direction = direction
        self.current_charges -= 1
        self.rolling_angle = 0
        
        # 대시 시작 이벤트
        emit_event(EventType.DASH_START, {
            'direction': direction,
            'charges_left': self.current_charges
        })
        
        # 사운드 재생 (sound_manager가 이벤트 처리)
        
        return True
        
    def update(self, dt: float):
        """대시 시스템 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 대시 중인 경우
        if self.dash_active:
            self.dash_timer -= dt
            
            # 플레이어 위치 업데이트
            player_rect = self.global_manager.get('PLAYER')
            if player_rect and self.dash_direction != 0:
                # 대시 이동
                move_amount = self.dash_speed * self.dash_direction * dt * 60
                player_rect.x += move_amount
                
                # 화면 경계 체크
                width = self.global_manager.get('WIDTH', 600)
                player_rect.x = max(0, min(width - player_rect.width, player_rect.x))
                
            # 롤링 애니메이션
            self.rolling_angle += self.rolling_speed * dt
            
            # 잔상 효과
            if self.dash_trail and player_rect:
                # 플레이어 이미지 가져오기
                player_img = self.global_manager.get('PLAYER_IMG')
                if player_img:
                    # 회전된 이미지로 잔상 생성
                    rotated_img = pygame.transform.rotate(player_img, self.rolling_angle)
                    self.effects_manager.create_dash_afterimage(
                        rotated_img, 
                        player_rect.centerx, 
                        player_rect.centery,
                        alpha=100
                    )
            
            # 대시 종료
            if self.dash_timer <= 0:
                self.end_dash()
                
        # 쿨다운 업데이트
        if self.dash_cooldown > 0:
            self.dash_cooldown -= dt
            
            # 충전 완료
            if self.dash_cooldown <= 0 and self.current_charges < self.dash_charges:
                self.current_charges += 1
                if self.current_charges < self.dash_charges:
                    # 다음 충전 시작
                    self.dash_cooldown = self.dash_cooldown_time
                    
    def end_dash(self):
        """대시 종료"""
        self.dash_active = False
        self.dash_timer = 0
        self.rolling_angle = 0
        
        # 쿨다운 시작
        if self.current_charges == 0:
            self.dash_cooldown = self.dash_cooldown_time
            
        # 대시 종료 이벤트
        emit_event(EventType.DASH_END, {
            'charges_left': self.current_charges
        })
        
    def handle_input(self, keys):
        """입력 처리
        
        Args:
            keys: pygame.key.get_pressed() 결과
        """
        if not self.can_dash():
            return
            
        # Shift + 방향키로 대시
        if keys[pygame.K_LSHIFT] or keys[pygame.K_RSHIFT]:
            if is_move_left_pressed(keys):
                self.start_dash(-1)
            elif is_move_right_pressed(keys):
                self.start_dash(1)
            elif is_move_down_pressed(keys):
                self.start_dash(0)  # 제자리 회피
                
    def is_invulnerable(self) -> bool:
        """무적 상태 여부
        
        Returns:
            무적 여부
        """
        return self.dash_active and self.dash_invulnerable
        
    def get_movement_multiplier(self) -> float:
        """이동 속도 배율 반환
        
        Returns:
            이동 속도 배율 (대시 중일 때 증가)
        """
        if self.dash_active and self.dash_direction != 0:
            return 3.0  # 대시 중 3배속
        return 1.0
        
    def upgrade_dash(self, upgrade_type: str):
        """대시 업그레이드
        
        Args:
            upgrade_type: 업그레이드 타입
                - 'charges': 충전 수 증가
                - 'speed': 대시 속도 증가
                - 'duration': 대시 지속시간 증가
                - 'cooldown': 쿨다운 감소
                - 'damage': 대시 데미지 추가
        """
        if upgrade_type == 'charges':
            self.dash_charges += 1
            self.current_charges = self.dash_charges
        elif upgrade_type == 'speed':
            self.dash_speed *= 1.2
        elif upgrade_type == 'duration':
            self.dash_duration *= 1.2
        elif upgrade_type == 'cooldown':
            self.dash_cooldown_time *= 0.8
        elif upgrade_type == 'damage':
            self.dash_damage += 10
            
    def render_ui(self, screen: pygame.Surface):
        """대시 UI 렌더링
        
        Args:
            screen: 화면 Surface
        """
        # 대시 충전 인디케이터
        x = 10
        y = self.global_manager.get('HEIGHT', 750) - 100
        
        for i in range(self.dash_charges):
            color = (100, 255, 100) if i < self.current_charges else (50, 50, 50)
            pygame.draw.circle(screen, color, (x + i * 25, y), 8)
            
        # 쿨다운 표시
        if self.dash_cooldown > 0 and self.current_charges == 0:
            # 쿨다운 진행률
            progress = 1 - (self.dash_cooldown / self.dash_cooldown_time)
            bar_width = self.dash_charges * 25 - 10
            bar_height = 4
            
            # 배경 바
            pygame.draw.rect(screen, (30, 30, 30), 
                           (x - 5, y + 12, bar_width, bar_height))
            
            # 진행 바
            pygame.draw.rect(screen, (100, 100, 255),
                           (x - 5, y + 12, int(bar_width * progress), bar_height))
                           
    def get_rotation_angle(self) -> float:
        """현재 회전 각도 반환 (롤링 애니메이션용)
        
        Returns:
            회전 각도
        """
        if self.dash_active:
            return self.rolling_angle
        return 0
        
    def reset(self):
        """대시 시스템 리셋"""
        self.dash_active = False
        self.dash_timer = 0
        self.dash_cooldown = 0
        self.current_charges = self.dash_charges
        self.rolling_angle = 0
        
    def get_stats(self) -> Dict:
        """대시 상태 반환"""
        return {
            'active': self.dash_active,
            'charges': f"{self.current_charges}/{self.dash_charges}",
            'cooldown': round(self.dash_cooldown, 1),
            'invulnerable': self.is_invulnerable(),
            'direction': self.dash_direction
        }


# 싱글톤 인스턴스
_dash_manager = None

def get_dash_manager() -> DashManager:
    """대시 매니저 싱글톤 반환"""
    global _dash_manager
    if _dash_manager is None:
        _dash_manager = DashManager()
    return _dash_manager
