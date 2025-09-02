"""
Power Smashing System - 파워 스매싱 시스템
강력한 스매시 공격 메커니즘
"""

import pygame
import math
import random
from typing import Dict, Any, Optional, Tuple
from enum import Enum
from dataclasses import dataclass
from core.events import EventType, emit_event
from core.global_manager import GlobalManager

class SmashType(Enum):
    """스매시 타입"""
    NORMAL = "normal"
    POWER = "power"
    MEGA = "mega"
    ULTIMATE = "ultimate"

@dataclass
class SmashEffect:
    """스매시 효과"""
    power_multiplier: float
    speed_multiplier: float
    trail_color: Tuple[int, int, int]
    screen_shake: int
    sound_name: str

class PowerSmashingManager:
    """파워 스매싱 매니저"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        
        # 스매시 게이지
        self.smash_gauge = 0.0
        self.max_gauge = 100.0
        self.gauge_charge_rate = 1.0
        
        # 스매시 상태
        self.charging = False
        self.charge_start_time = 0.0
        self.charge_power = 0.0
        self.max_charge_time = 3.0
        
        # 활성 스매시
        self.active_smash = None
        self.smash_duration = 0.0
        self.smash_trail = []
        
        # 스매시 효과 정의
        self.smash_effects = {
            SmashType.NORMAL: SmashEffect(1.5, 1.2, (255, 200, 100), 5, 'power_smash'),
            SmashType.POWER: SmashEffect(2.0, 1.5, (255, 150, 50), 10, 'power_smash'),
            SmashType.MEGA: SmashEffect(3.0, 2.0, (255, 100, 0), 15, 'power_smash_launch'),
            SmashType.ULTIMATE: SmashEffect(5.0, 3.0, (255, 50, 0), 20, 'power_smash_launch')
        }
        
        # 스매시 콤보
        self.smash_combo = 0
        self.combo_timer = 0.0
        
        # 특수 스매시 조건
        self.special_conditions = {
            'counter_smash': False,  # 반격 스매시
            'perfect_smash': False,  # 퍼펙트 스매시
            'chain_smash': False,    # 연쇄 스매시
            'aerial_smash': False     # 공중 스매시
        }
        
        # 통계
        self.stats = {
            'total_smashes': 0,
            'power_smashes': 0,
            'mega_smashes': 0,
            'ultimate_smashes': 0,
            'max_combo': 0,
            'total_damage': 0.0
        }
        
    def update(self, dt: float):
        """업데이트"""
        # 게이지 자동 충전
        if self.smash_gauge < self.max_gauge:
            self.smash_gauge += self.gauge_charge_rate * dt * 10
            self.smash_gauge = min(self.smash_gauge, self.max_gauge)
            
        # 차징 업데이트
        if self.charging:
            self.charge_power = min(self.charge_power + dt, self.max_charge_time)
            
        # 활성 스매시 업데이트
        if self.active_smash:
            self.smash_duration -= dt
            if self.smash_duration <= 0:
                self.deactivate_smash()
                
        # 콤보 타이머
        if self.combo_timer > 0:
            self.combo_timer -= dt
            if self.combo_timer <= 0:
                self.smash_combo = 0
                
        # 트레일 업데이트
        self.update_trail()
        
    def start_charging(self):
        """차징 시작"""
        if self.smash_gauge >= 20:  # 최소 게이지 필요
            self.charging = True
            self.charge_start_time = pygame.time.get_ticks() / 1000.0
            self.charge_power = 0.0
            
            emit_event(EventType.PLAY_SOUND, {'sound': 'charge'})
            
    def release_charge(self) -> bool:
        """차징 해제 및 스매시 발동
        
        Returns:
            스매시 성공 여부
        """
        if not self.charging:
            return False
            
        self.charging = False
        
        # 차징 시간에 따른 스매시 타입 결정
        smash_type = self.determine_smash_type(self.charge_power)
        
        # 게이지 소모
        gauge_cost = self.get_gauge_cost(smash_type)
        if self.smash_gauge < gauge_cost:
            return False
            
        self.smash_gauge -= gauge_cost
        
        # 스매시 발동
        self.activate_smash(smash_type)
        
        return True
        
    def determine_smash_type(self, charge_time: float) -> SmashType:
        """스매시 타입 결정
        
        Args:
            charge_time: 차징 시간
            
        Returns:
            스매시 타입
        """
        if charge_time >= 2.5:
            return SmashType.ULTIMATE
        elif charge_time >= 1.5:
            return SmashType.MEGA
        elif charge_time >= 0.5:
            return SmashType.POWER
        else:
            return SmashType.NORMAL
            
    def get_gauge_cost(self, smash_type: SmashType) -> float:
        """게이지 소모량 반환
        
        Args:
            smash_type: 스매시 타입
            
        Returns:
            게이지 소모량
        """
        costs = {
            SmashType.NORMAL: 20,
            SmashType.POWER: 40,
            SmashType.MEGA: 60,
            SmashType.ULTIMATE: 80
        }
        return costs.get(smash_type, 20)
        
    def activate_smash(self, smash_type: SmashType):
        """스매시 발동
        
        Args:
            smash_type: 스매시 타입
        """
        self.active_smash = smash_type
        self.smash_duration = 0.5  # 0.5초간 효과 지속
        
        effect = self.smash_effects[smash_type]
        
        # 공 속도 변경
        ball_dx = self.global_manager.get('ball_dx', 0)
        ball_dy = self.global_manager.get('ball_dy', 5)
        
        self.global_manager.set('ball_dx', ball_dx * effect.speed_multiplier)
        self.global_manager.set('ball_dy', -abs(ball_dy) * effect.speed_multiplier)
        
        # 화면 효과
        emit_event(EventType.SCREEN_SHAKE, {
            'intensity': effect.screen_shake,
            'duration': 30
        })
        
        # 사운드 재생
        emit_event(EventType.PLAY_SOUND, {'sound': effect.sound_name})
        
        # 이벤트 발생
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'power_smash',
            'smash_type': smash_type.value,
            'power': effect.power_multiplier
        })
        
        # 통계 업데이트
        self.update_stats(smash_type)
        
        # 콤보 추가
        self.add_combo()
        
        # 특수 조건 체크
        self.check_special_conditions()
        
    def deactivate_smash(self):
        """스매시 비활성화"""
        self.active_smash = None
        self.smash_trail.clear()
        
    def add_combo(self):
        """콤보 추가"""
        self.smash_combo += 1
        self.combo_timer = 3.0  # 3초 내에 다음 스매시
        
        if self.smash_combo > self.stats['max_combo']:
            self.stats['max_combo'] = self.smash_combo
            
        # 콤보 보너스
        if self.smash_combo >= 3:
            bonus_gauge = self.smash_combo * 5
            self.smash_gauge = min(self.smash_gauge + bonus_gauge, self.max_gauge)
            
            emit_event(EventType.SPECIAL_ACTIVATED, {
                'type': 'smash_combo',
                'combo': self.smash_combo,
                'bonus': bonus_gauge
            })
            
    def check_special_conditions(self):
        """특수 조건 체크"""
        ball_rect = self.global_manager.get('BALL')
        player_rect = self.global_manager.get('PLAYER')
        
        if not ball_rect or not player_rect:
            return
            
        # 반격 스매시: 공이 빠르게 접근할 때
        ball_dy = self.global_manager.get('ball_dy', 0)
        if ball_dy > 8:
            self.special_conditions['counter_smash'] = True
            self.smash_gauge += 10
            
        # 공중 스매시: 공이 높은 위치에 있을 때
        if ball_rect.centery < 200:
            self.special_conditions['aerial_smash'] = True
            self.smash_gauge += 5
            
    def update_trail(self):
        """트레일 업데이트"""
        if not self.active_smash:
            self.smash_trail.clear()
            return
            
        ball_rect = self.global_manager.get('BALL')
        if ball_rect:
            # 트레일 포인트 추가
            self.smash_trail.append({
                'pos': (ball_rect.centerx, ball_rect.centery),
                'alpha': 255,
                'size': ball_rect.width
            })
            
            # 트레일 페이드 아웃
            for trail in self.smash_trail[:]:
                trail['alpha'] -= 15
                trail['size'] *= 0.95
                if trail['alpha'] <= 0:
                    self.smash_trail.remove(trail)
                    
            # 트레일 길이 제한
            if len(self.smash_trail) > 20:
                self.smash_trail.pop(0)
                
    def update_stats(self, smash_type: SmashType):
        """통계 업데이트
        
        Args:
            smash_type: 스매시 타입
        """
        self.stats['total_smashes'] += 1
        
        if smash_type == SmashType.POWER:
            self.stats['power_smashes'] += 1
        elif smash_type == SmashType.MEGA:
            self.stats['mega_smashes'] += 1
        elif smash_type == SmashType.ULTIMATE:
            self.stats['ultimate_smashes'] += 1
            
        # 데미지 계산
        effect = self.smash_effects[smash_type]
        self.stats['total_damage'] += effect.power_multiplier
        
    def render(self, screen: pygame.Surface):
        """렌더링"""
        # 트레일 그리기
        if self.active_smash and self.smash_trail:
            effect = self.smash_effects[self.active_smash]
            
            for trail in self.smash_trail:
                if trail['alpha'] > 0:
                    s = pygame.Surface((trail['size'] * 2, trail['size'] * 2), pygame.SRCALPHA)
                    color = (*effect.trail_color, trail['alpha'])
                    pygame.draw.circle(s, color, 
                                     (trail['size'], trail['size']), 
                                     int(trail['size']))
                    screen.blit(s, (trail['pos'][0] - trail['size'],
                                   trail['pos'][1] - trail['size']))
                                   
        # 차징 효과
        if self.charging:
            self.render_charging_effect(screen)
            
    def render_charging_effect(self, screen: pygame.Surface):
        """차징 효과 렌더링"""
        player_rect = self.global_manager.get('PLAYER')
        if not player_rect:
            return
            
        # 차징 파워에 따른 색상
        charge_ratio = self.charge_power / self.max_charge_time
        r = int(255 * charge_ratio)
        g = int(255 * (1 - charge_ratio))
        b = 0
        
        # 차징 오라
        for i in range(3):
            radius = 30 + i * 10 + int(charge_ratio * 20)
            alpha = int(100 * (1 - i * 0.3) * charge_ratio)
            
            s = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
            pygame.draw.circle(s, (r, g, b, alpha),
                             (radius, radius), radius)
            screen.blit(s, (player_rect.centerx - radius,
                           player_rect.centery - radius))
                           
        # 차징 게이지 바
        bar_width = 100
        bar_height = 10
        bar_x = player_rect.centerx - bar_width // 2
        bar_y = player_rect.top - 30
        
        # 배경
        pygame.draw.rect(screen, (50, 50, 50),
                        (bar_x, bar_y, bar_width, bar_height))
        # 차징량
        fill_width = int(bar_width * charge_ratio)
        pygame.draw.rect(screen, (r, g, b),
                        (bar_x, bar_y, fill_width, bar_height))
        # 테두리
        pygame.draw.rect(screen, (255, 255, 255),
                        (bar_x, bar_y, bar_width, bar_height), 2)
                        
    def render_ui(self, screen: pygame.Surface):
        """UI 렌더링"""
        font = pygame.font.Font(None, 24)
        
        # 스매시 게이지
        gauge_x = 10
        gauge_y = 200
        gauge_width = 30
        gauge_height = 200
        
        # 게이지 배경
        pygame.draw.rect(screen, (50, 50, 50),
                        (gauge_x, gauge_y, gauge_width, gauge_height))
        
        # 게이지 채움
        fill_height = int(gauge_height * (self.smash_gauge / self.max_gauge))
        fill_y = gauge_y + gauge_height - fill_height
        
        # 게이지 색상 (양에 따라)
        if self.smash_gauge >= 80:
            color = (255, 50, 50)  # 빨강
        elif self.smash_gauge >= 60:
            color = (255, 150, 50)  # 주황
        elif self.smash_gauge >= 40:
            color = (255, 255, 50)  # 노랑
        else:
            color = (100, 200, 100)  # 초록
            
        pygame.draw.rect(screen, color,
                        (gauge_x, fill_y, gauge_width, fill_height))
        
        # 게이지 구분선
        for i in range(1, 5):
            y = gauge_y + gauge_height - (gauge_height * i // 5)
            pygame.draw.line(screen, (200, 200, 200),
                           (gauge_x, y), (gauge_x + gauge_width, y), 1)
                           
        # 게이지 테두리
        pygame.draw.rect(screen, (255, 255, 255),
                        (gauge_x, gauge_y, gauge_width, gauge_height), 2)
                        
        # 게이지 텍스트
        gauge_text = f"{int(self.smash_gauge)}%"
        text_surface = font.render(gauge_text, True, (255, 255, 255))
        screen.blit(text_surface, (gauge_x, gauge_y - 25))
        
        # 콤보 표시
        if self.smash_combo > 0:
            combo_text = f"SMASH x{self.smash_combo}"
            text_surface = font.render(combo_text, True, (255, 200, 50))
            text_rect = text_surface.get_rect(center=(300, 200))
            screen.blit(text_surface, text_rect)
            
        # 활성 스매시 표시
        if self.active_smash:
            smash_text = f"{self.active_smash.value.upper()} SMASH!"
            text_surface = font.render(smash_text, True, (255, 100, 0))
            text_rect = text_surface.get_rect(center=(300, 250))
            
            # 깜빡임 효과
            if pygame.time.get_ticks() % 200 < 100:
                screen.blit(text_surface, text_rect)
                
    def get_power_multiplier(self) -> float:
        """현재 파워 배율 반환"""
        if self.active_smash:
            return self.smash_effects[self.active_smash].power_multiplier
        return 1.0
        
    def is_charging(self) -> bool:
        """차징 중인지 확인"""
        return self.charging
        
    def get_stats(self) -> Dict[str, Any]:
        """통계 반환"""
        return self.stats.copy()

# 싱글톤 인스턴스
_power_smashing_manager = None

def get_power_smashing_manager() -> PowerSmashingManager:
    """파워 스매싱 매니저 싱글톤 반환"""
    global _power_smashing_manager
    if _power_smashing_manager is None:
        _power_smashing_manager = PowerSmashingManager()
    return _power_smashing_manager