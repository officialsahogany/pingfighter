"""
Gacha System - 가챠(뽑기) 시스템
캡슐 뽑기, 보상, 애니메이션 관리
"""

import pygame
import random
import math
from typing import Dict, List, Optional, Tuple
from core.global_manager import GlobalManager
from core.events import EventType, emit_event
from managers.effects_manager import get_effects_manager


class Capsule:
    """캡슐 클래스"""
    
    def __init__(self, x: float, y: float, item: Dict, color: Tuple[int, int, int]):
        self.x = x
        self.y = y
        self.item = item
        self.color = color
        self.velocity_y = 0
        self.bounce_count = 0
        self.scale = 1.0
        self.rotation = random.uniform(0, 360)
        self.rotation_speed = random.uniform(-5, 5)
        
    def update(self, dt: float):
        """캡슐 업데이트"""
        # 중력
        self.velocity_y += 0.8 * dt * 60
        self.y += self.velocity_y * dt * 60
        
        # 회전
        self.rotation += self.rotation_speed * dt * 60
        
    def bounce(self):
        """바닥에 튀어오름"""
        self.velocity_y = -self.velocity_y * 0.6
        self.bounce_count += 1
        
    def render(self, screen: pygame.Surface):
        """캡슐 렌더링"""
        # 캡슐 크기
        size = int(20 * self.scale)
        
        # 외곽선
        pygame.draw.circle(screen, self.color, (int(self.x), int(self.y)), size, 2)
        
        # 내부 채우기 (투명도)
        s = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
        color_with_alpha = (*self.color, 100)
        pygame.draw.circle(s, color_with_alpha, (size, size), size)
        screen.blit(s, (self.x - size, self.y - size))


class GachaSystem:
    """가챠 시스템"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        self.effects_manager = get_effects_manager()
        
        # 상태
        self.active = False
        self.phase = 0  # 0: 대기, 1: 동전 투입, 2: 캡슐 떨어짐, 3: 결과 표시
        self.animation_timer = 0
        
        # 가챠 머신 설정
        self.machine_width = 300
        self.machine_height = 400
        self.globe_radius = 120
        self.base_height = 80
        
        # 캡슐
        self.capsules_in_machine = []
        self.falling_capsule = None
        self.result = None
        
        # 아이템 풀
        self.item_pool = self._create_item_pool()
        
        # 확률 테이블
        self.rarity_chances = {
            'common': 0.60,    # 60%
            'rare': 0.30,      # 30%
            'epic': 0.08,      # 8%
            'legendary': 0.02  # 2%
        }
        
        # 캡슐 색상
        self.capsule_colors = {
            'common': (150, 150, 150),      # 회색
            'rare': (100, 150, 255),        # 파랑
            'epic': (200, 100, 255),        # 보라
            'legendary': (255, 215, 0)      # 금색
        }
        
    def _create_item_pool(self) -> List[Dict]:
        """아이템 풀 생성"""
        return [
            # Common 아이템
            {'name': '스피드 부스트', 'rarity': 'common', 'type': 'buff', 'effect': 'speed_boost'},
            {'name': '슬로우 필드', 'rarity': 'common', 'type': 'debuff', 'effect': 'slow_field'},
            {'name': '미니 쉴드', 'rarity': 'common', 'type': 'defense', 'effect': 'mini_shield'},
            {'name': '파워 샷', 'rarity': 'common', 'type': 'attack', 'effect': 'power_shot'},
            
            # Rare 아이템
            {'name': '더블 대시', 'rarity': 'rare', 'type': 'dash', 'effect': 'double_dash'},
            {'name': '자석 필드', 'rarity': 'rare', 'type': 'field', 'effect': 'magnetic_field'},
            {'name': '화염구', 'rarity': 'rare', 'type': 'projectile', 'effect': 'fireball'},
            {'name': '얼음 벽', 'rarity': 'rare', 'type': 'wall', 'effect': 'ice_wall'},
            
            # Epic 아이템
            {'name': '번개 폭풍', 'rarity': 'epic', 'type': 'aoe', 'effect': 'thunder_storm'},
            {'name': '시간 정지', 'rarity': 'epic', 'type': 'time', 'effect': 'time_stop'},
            {'name': '거대화', 'rarity': 'epic', 'type': 'transform', 'effect': 'giant_mode'},
            {'name': '분신술', 'rarity': 'epic', 'type': 'clone', 'effect': 'shadow_clone'},
            
            # Legendary 아이템
            {'name': '무적 모드', 'rarity': 'legendary', 'type': 'invincible', 'effect': 'god_mode'},
            {'name': '최종 병기', 'rarity': 'legendary', 'type': 'ultimate', 'effect': 'ultimate_weapon'},
            {'name': '시공간 균열', 'rarity': 'legendary', 'type': 'space', 'effect': 'dimension_rift'},
        ]
        
    def start_gacha(self, cost: int = 100) -> bool:
        """가챠 시작
        
        Args:
            cost: 가챠 비용 (메달)
            
        Returns:
            시작 성공 여부
        """
        # 메달 체크 (실제 구현시 연동 필요)
        # if not self.can_afford(cost):
        #     return False
            
        self.active = True
        self.phase = 0
        self.animation_timer = 0
        
        # 머신 안 캡슐 초기화
        self._fill_machine()
        
        emit_event(EventType.MENU_OPENED, {'type': 'gacha'})
        return True
        
    def _fill_machine(self):
        """가챠 머신 채우기"""
        self.capsules_in_machine.clear()
        
        width = self.global_manager.get('WIDTH', 600)
        height = self.global_manager.get('HEIGHT', 750)
        center_x = width // 2
        center_y = height // 2
        
        # 40개의 캡슐 생성
        for i in range(40):
            # 랜덤 위치 (구 내부)
            angle = random.uniform(0, math.pi * 2)
            radius = random.uniform(0, self.globe_radius - 20)
            x = center_x + radius * math.cos(angle)
            y = center_y - 100 + radius * math.sin(angle)
            
            # 랜덤 아이템
            rarity = self._roll_rarity()
            items = [item for item in self.item_pool if item['rarity'] == rarity]
            item = random.choice(items) if items else self.item_pool[0]
            
            # 캡슐 생성
            color = self.capsule_colors.get(rarity, (255, 255, 255))
            capsule = Capsule(x, y, item.copy(), color)
            self.capsules_in_machine.append(capsule)
            
    def _roll_rarity(self) -> str:
        """희귀도 뽑기"""
        roll = random.random()
        cumulative = 0
        
        for rarity, chance in self.rarity_chances.items():
            cumulative += chance
            if roll < cumulative:
                return rarity
                
        return 'common'
        
    def insert_coin(self):
        """동전 투입"""
        if self.phase != 0:
            return
            
        self.phase = 1
        self.animation_timer = 0
        
        # 사운드 효과
        emit_event(EventType.PLAY_SOUND, {'sound': 'coin_insert'})
        
    def update(self, dt: float):
        """시스템 업데이트
        
        Args:
            dt: 델타 타임
        """
        if not self.active:
            return
            
        self.animation_timer += dt * 60
        
        if self.phase == 1:  # 동전 투입 애니메이션
            # 머신 내 캡슐들 흔들기
            for capsule in self.capsules_in_machine:
                capsule.x += random.uniform(-2, 2)
                capsule.y += random.uniform(-2, 2)
                
            # 1초 후 캡슐 떨어뜨리기
            if self.animation_timer >= 60:
                self.phase = 2
                self.animation_timer = 0
                self._drop_capsule()
                
        elif self.phase == 2:  # 캡슐 떨어지는 중
            if self.falling_capsule:
                self.falling_capsule.update(dt)
                
                # 바닥 체크
                ground_y = self.global_manager.get('HEIGHT', 750) - 100
                if self.falling_capsule.y >= ground_y and self.falling_capsule.velocity_y > 0:
                    self.falling_capsule.bounce()
                    
                    # 효과음
                    emit_event(EventType.PLAY_SOUND, {'sound': 'bounce'})
                    
                    # 3번 튀어오른 후 결과 표시
                    if self.falling_capsule.bounce_count >= 3:
                        self.phase = 3
                        self.animation_timer = 0
                        self._show_result()
                        
        elif self.phase == 3:  # 결과 표시
            # 3초 후 자동 종료
            if self.animation_timer >= 180:
                self.close_gacha()
                
    def _drop_capsule(self):
        """캡슐 떨어뜨리기"""
        # 랜덤 캡슐 선택
        if self.capsules_in_machine:
            selected = random.choice(self.capsules_in_machine)
            self.capsules_in_machine.remove(selected)
            
            # 떨어지는 캡슐 설정
            width = self.global_manager.get('WIDTH', 600)
            selected.x = width // 2
            selected.y = 200
            selected.velocity_y = 0
            self.falling_capsule = selected
            self.result = selected.item
            
    def _show_result(self):
        """결과 표시"""
        if self.result:
            # 희귀도에 따른 이펙트
            rarity = self.result.get('rarity', 'common')
            
            if rarity == 'legendary':
                # 화려한 이펙트
                self.effects_manager.flash_screen(color=(255, 215, 0), duration=0.5)
                self.effects_manager.shake_screen(intensity=10, duration=0.5)
                
                # 폭죽 효과
                width = self.global_manager.get('WIDTH', 600)
                height = self.global_manager.get('HEIGHT', 750)
                for _ in range(20):
                    x = random.randint(100, width - 100)
                    y = random.randint(100, height - 100)
                    self.effects_manager.create_explosion(x, y, radius=30, color=(255, 215, 0))
                    
            elif rarity == 'epic':
                # 중간 이펙트
                self.effects_manager.flash_screen(color=(200, 100, 255), duration=0.3)
                
            elif rarity == 'rare':
                # 작은 이펙트
                self.effects_manager.flash_screen(color=(100, 150, 255), duration=0.2)
                
            # 이벤트 발생
            emit_event(EventType.ITEM_COLLECTED, {
                'item': self.result,
                'source': 'gacha'
            })
            
    def render(self, screen: pygame.Surface):
        """렌더링
        
        Args:
            screen: 화면 Surface
        """
        if not self.active:
            return
            
        width = self.global_manager.get('WIDTH', 600)
        height = self.global_manager.get('HEIGHT', 750)
        center_x = width // 2
        center_y = height // 2
        
        # 배경 (반투명 검정)
        overlay = pygame.Surface((width, height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 200))
        screen.blit(overlay, (0, 0))
        
        # 가챠 머신 그리기
        self._draw_machine(screen, center_x, center_y)
        
        # 떨어지는 캡슐
        if self.falling_capsule and self.phase == 2:
            self.falling_capsule.render(screen)
            
        # 결과 표시
        if self.phase == 3 and self.result:
            self._draw_result(screen, center_x, center_y)
            
        # 안내 텍스트
        if self.phase == 0:
            try:
                font = pygame.font.Font(None, 30)
                text = font.render("Press SPACE to insert coin", True, (255, 255, 255))
                text_rect = text.get_rect(center=(center_x, height - 50))
                screen.blit(text, text_rect)
            except:
                pass
                
    def _draw_machine(self, screen: pygame.Surface, center_x: int, center_y: int):
        """가챠 머신 그리기"""
        # 사이버펑크 스타일 홀로그램 효과
        pulse = abs(math.sin(self.animation_timer * 0.05)) * 0.3 + 0.7
        
        # 구체 (캡슐 보관함)
        for i in range(3):
            radius = self.globe_radius + i * 5
            alpha = 100 - i * 30
            color = (0, int(255 * pulse), int(255 * pulse), alpha)
            
            s = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
            pygame.draw.circle(s, color, (radius, radius), radius, 2)
            screen.blit(s, (center_x - radius, center_y - 100 - radius))
            
        # 머신 내 캡슐들
        for capsule in self.capsules_in_machine:
            capsule.render(screen)
            
        # 베이스
        base_rect = pygame.Rect(
            center_x - self.machine_width // 2 + 50,
            center_y + self.machine_height // 2 - self.base_height,
            self.machine_width - 100,
            self.base_height
        )
        
        # 네온 글로우
        for i in range(3):
            glow_rect = base_rect.inflate(i * 10, i * 10)
            pygame.draw.rect(screen, (0, 255, 255, 50 - i * 15), glow_rect, 2, border_radius=10)
            
        # 베이스 본체
        pygame.draw.rect(screen, (0, 100, 150), base_rect, border_radius=10)
        pygame.draw.rect(screen, (0, 255, 255), base_rect, 3, border_radius=10)
        
        # 동전 투입구
        if self.phase == 0:
            coin_color = (255, 255, 0) if int(self.animation_timer) % 30 < 15 else (200, 200, 0)
            pygame.draw.circle(screen, coin_color, (center_x, center_y + 100), 20, 3)
            
    def _draw_result(self, screen: pygame.Surface, center_x: int, center_y: int):
        """결과 화면 그리기"""
        if not self.result:
            return
            
        # 결과 박스
        box_width = 400
        box_height = 200
        box_rect = pygame.Rect(
            center_x - box_width // 2,
            center_y - box_height // 2,
            box_width,
            box_height
        )
        
        # 배경
        pygame.draw.rect(screen, (20, 20, 40), box_rect, border_radius=20)
        
        # 희귀도에 따른 테두리
        rarity = self.result.get('rarity', 'common')
        border_color = self.capsule_colors.get(rarity, (255, 255, 255))
        pygame.draw.rect(screen, border_color, box_rect, 3, border_radius=20)
        
        # 아이템 이름
        try:
            font_large = pygame.font.Font(None, 40)
            name_text = font_large.render(self.result['name'], True, border_color)
            name_rect = name_text.get_rect(center=(center_x, center_y - 30))
            screen.blit(name_text, name_rect)
            
            # 희귀도
            font_medium = pygame.font.Font(None, 30)
            rarity_text = font_medium.render(f"[{rarity.upper()}]", True, border_color)
            rarity_rect = rarity_text.get_rect(center=(center_x, center_y + 10))
            screen.blit(rarity_text, rarity_rect)
            
            # 타입
            type_text = font_medium.render(f"Type: {self.result['type']}", True, (200, 200, 200))
            type_rect = type_text.get_rect(center=(center_x, center_y + 40))
            screen.blit(type_text, type_rect)
            
        except:
            pass
            
        # 축하 메시지 (레전더리)
        if rarity == 'legendary':
            try:
                font_huge = pygame.font.Font(None, 60)
                congrats = font_huge.render("LEGENDARY!", True, (255, 215, 0))
                
                # 깜빡임 효과
                if int(self.animation_timer) % 20 < 10:
                    congrats_rect = congrats.get_rect(center=(center_x, 100))
                    screen.blit(congrats, congrats_rect)
            except:
                pass
                
    def handle_input(self, event) -> bool:
        """입력 처리
        
        Args:
            event: pygame 이벤트
            
        Returns:
            처리 여부
        """
        if not self.active:
            return False
            
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE and self.phase == 0:
                # 동전 투입
                self.insert_coin()
                return True
            elif event.key == pygame.K_ESCAPE:
                # 가챠 종료
                self.close_gacha()
                return True
            elif event.key == pygame.K_RETURN and self.phase == 3:
                # 결과 확인 후 종료
                self.close_gacha()
                return True
                
        return False
        
    def close_gacha(self):
        """가챠 종료"""
        self.active = False
        self.phase = 0
        self.falling_capsule = None
        self.result = None
        self.capsules_in_machine.clear()
        
        emit_event(EventType.MENU_CLOSED, {'type': 'gacha'})
        
    def is_active(self) -> bool:
        """활성 상태 확인"""
        return self.active
        
    def get_stats(self) -> Dict:
        """가챠 통계"""
        return {
            'active': self.active,
            'phase': self.phase,
            'capsules_in_machine': len(self.capsules_in_machine),
            'current_result': self.result['name'] if self.result else None
        }


# 싱글톤 인스턴스
_gacha_system = None

def get_gacha_system() -> GachaSystem:
    """가챠 시스템 싱글톤 반환"""
    global _gacha_system
    if _gacha_system is None:
        _gacha_system = GachaSystem()
    return _gacha_system