"""
Half-Dash System Module
======================
When player doesn't have enough gauge for a full dash,
activate a free half-dash with 50% distance.

Author: Claude Code
Date: 2024-08-22
"""

import pygame
import math
import random
from typing import Tuple, Optional, Dict, Any

class HalfDashSystem:
    """
    하프 대쉬 시스템
    게이지가 부족할 때 무료로 발동되는 50% 거리 대쉬
    """
    
    def __init__(self):
        """하프 대쉬 시스템 초기화"""
        # 하프 대쉬 상태
        self.half_dash_active = False
        self.half_dash_used_this_round = False
        
        # 하프 대쉬 설정
        self.HALF_DASH_DISTANCE_RATIO = 0.5  # 일반 대쉬의 50% 거리
        self.HALF_DASH_BASE_TIMER = 11  # 조정된 거리 (11프레임 = 143픽셀 = 60%)
        
        # 토큰 소모 설정
        self.HALF_DASH_TOKEN_COST = 1  # 토큰 1개 소모 (일반 대쉬와 동일)
        
        # 시각 효과 설정
        self.half_dash_effect_color = (150, 150, 255)  # 연한 파란색
        self.half_dash_trail_alpha = 100  # 반투명 잔상
        
        # 통계
        self.half_dash_count = 0
        self.half_dash_saves = 0  # 하프 대쉬로 공을 막은 횟수
        
    def check_half_dash_activation(self, 
                                  special_gauge: int,
                                  required_gauge: int,
                                  rolling_charges: int,
                                  rolling_active: bool,
                                  rolling_stun_timer: int,
                                  down_pressed: bool,
                                  left_key: bool,
                                  right_key: bool) -> Tuple[bool, int, int, int]:
        """
        하프 대쉬 발동 조건 체크
        
        Args:
            special_gauge: 현재 게이지
            required_gauge: 일반 대쉬에 필요한 게이지
            rolling_charges: 대쉬 토큰 수
            rolling_active: 현재 대쉬 활성 여부
            rolling_stun_timer: 대쉬 스턴 타이머 (일반 대쉬와 공유)
            down_pressed: 아래 키 눌림 여부
            left_key: 왼쪽 키 상태
            right_key: 오른쪽 키 상태
            
        Returns:
            (하프대쉬 발동 여부, 방향, 타이머, 토큰 소모량)
        """
        # 하프 대쉬 발동 조건
        # 1. 대쉬 토큰이 있음
        # 2. 게이지가 부족함
        # 3. 현재 대쉬 중이 아님
        # 4. 아래키가 눌렸음
        # 5. 방향키가 눌렸음
        # 6. 대쉬 스턴 타이머가 0 (일반 대쉬와 동일한 쿨다운)
        if (rolling_charges >= self.HALF_DASH_TOKEN_COST and 
            special_gauge < required_gauge and 
            not rolling_active and 
            rolling_stun_timer <= 0 and  # 일반 대쉬와 동일한 쿨다운 체크
            down_pressed and 
            (left_key or right_key)):
            
            # 방향 결정
            direction = -1 if left_key else 1
            
            # 하프 대쉬 타이머 계산
            timer = self.HALF_DASH_BASE_TIMER
            
            # 하프 대쉬 활성화
            self.half_dash_active = True
            self.half_dash_count += 1
            
            print(f"   ! ( : {special_gauge}/{required_gauge})")
            print(f"   : {'' if direction < 0 else ''}")
            print(f"   :   50%")
            print(f"    : {self.HALF_DASH_TOKEN_COST}")
            
            return True, direction, timer, self.HALF_DASH_TOKEN_COST
            
        return False, 0, 0, 0
    
    def apply_half_dash_effects(self, base_rolling_timer: int, 
                               dashgear_obtained: bool,
                               jump_bonus: float) -> int:
        """
        하프 대쉬 효과 적용
        
        Args:
            base_rolling_timer: 하프 대쉬 기본 타이머 (이미 조정된 값)
            dashgear_obtained: 대쉬기어 획득 여부
            jump_bonus: 도약 스킬 보너스
            
        Returns:
            조정된 타이머 값
        """
        # base_rolling_timer는 이미 HALF_DASH_BASE_TIMER (12)로 설정됨
        # 추가 50% 감소를 적용하지 않음
        half_timer = base_rolling_timer
        
        # 대쉬기어 효과는 하프 대쉬에도 적용 (10% 추가)
        if dashgear_obtained:
            half_timer = int(half_timer * 1.1)
            
        # 도약 스킬도 절반만 적용
        if jump_bonus > 0:
            half_timer = int(half_timer * (1 + jump_bonus * 0.5))
            
        return half_timer
    
    def draw_half_dash_effect(self, screen: pygame.Surface, 
                             player_rect: pygame.Rect,
                             direction: int):
        """
        하프 대쉬 시각 효과 그리기
        
        Args:
            screen: 게임 화면
            player_rect: 플레이어 위치
            direction: 대쉬 방향
        """
        if not self.half_dash_active:
            return

        # 하프 대쉬 잔상 효과 (더 연한 색상)
        # SRCALPHA로 생성하여 Windows 전체화면에서 알파 블렌딩 문제 방지
        trail_surface = pygame.Surface((player_rect.width, player_rect.height), pygame.SRCALPHA)
        # SRCALPHA 사용 시 fill에 알파값 포함
        trail_color_with_alpha = (*self.half_dash_effect_color, self.half_dash_trail_alpha)
        trail_surface.fill(trail_color_with_alpha)
        
        # 방향에 따른 잔상 위치
        for i in range(3):
            offset = direction * i * 15
            trail_rect = player_rect.copy()
            trail_rect.x -= offset
            screen.blit(trail_surface, trail_rect)
            
        # 하프 대쉬 표시 텍스트
        font = pygame.font.Font(None, 20)
        text = font.render("HALF", True, self.half_dash_effect_color)
        text_rect = text.get_rect(center=(player_rect.centerx, player_rect.top - 20))
        screen.blit(text, text_rect)
        
    def draw_cooldown_indicator(self, screen: pygame.Surface, x: int, y: int):
        """
        하프 대쉬 쿨다운 표시 (일반 대쉬와 공유하므로 별도 표시 없음)
        
        Args:
            screen: 게임 화면
            x, y: 표시 위치
        """
        # 일반 대쉬와 쿨다운을 공유하므로 별도 표시하지 않음
        pass
        
    def handle_ball_collision(self, ball_rect: pygame.Rect, 
                             player_rect: pygame.Rect) -> bool:
        """
        하프 대쉬 중 공과의 충돌 처리
        
        Args:
            ball_rect: 공 위치
            player_rect: 플레이어 위치
            
        Returns:
            충돌 여부
        """
        if self.half_dash_active and player_rect.colliderect(ball_rect):
            self.half_dash_saves += 1
            print(f"    ! ( {self.half_dash_saves})")
            
            # 무릎보호대 효과 체크
            try:
                from item_effects.knee_pads import get_knee_pads_instance
                knee_pads = get_knee_pads_instance()
                if knee_pads and knee_pads.active:
                    # 하프대쉬 성공 시 무릎보호대 효과 발동
                    ball_center = (ball_rect.centerx, ball_rect.centery)
                    knee_pads.on_half_dash_hit(ball_center)
                    print("무릎보호대 효과 발동 - 게이지 50% 충전 신호")
            except:
                pass
            
            return True
        return False
        
    def reset_round(self):
        """라운드 초기화"""
        self.half_dash_active = False
        self.half_dash_used_this_round = False
        # 쿨다운은 유지
        
    def get_statistics(self) -> Dict[str, Any]:
        """
        하프 대쉬 통계 반환
        
        Returns:
            통계 딕셔너리
        """
        return {
            'total_uses': self.half_dash_count,
            'ball_saves': self.half_dash_saves,
            'success_rate': self.half_dash_saves / max(1, self.half_dash_count)
        }
        
    def should_show_tutorial(self) -> bool:
        """
        하프 대쉬 튜토리얼 표시 여부
        
        Returns:
            첫 사용시 True
        """
        return self.half_dash_count == 1

# 전역 하프 대쉬 시스템 인스턴스
half_dash_system = None

def initialize_half_dash():
    """하프 대쉬 시스템 초기화"""
    global half_dash_system
    half_dash_system = HalfDashSystem()
    print("")
    return half_dash_system

def get_half_dash_system() -> Optional[HalfDashSystem]:
    """하프 대쉬 시스템 인스턴스 반환"""
    return half_dash_system