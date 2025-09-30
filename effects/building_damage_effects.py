"""발토르 건물 손상 시각 효과 시스템

체력에 따른 건물 손상 상태와 파티클 효과를 관리합니다.
"""

import pygame
import random
import math
from typing import List, Tuple, Dict, Optional

class DamageParticle:
    """손상 파티클 베이스 클래스"""
    def __init__(self, x: float, y: float):
        self.x = x
        self.y = y
        self.vx = 0.0
        self.vy = 0.0
        self.lifetime = 0
        self.max_lifetime = 60
        self.alive = True
        
    def update(self):
        """파티클 업데이트"""
        self.x += self.vx
        self.y += self.vy
        self.lifetime += 1
        
        if self.lifetime >= self.max_lifetime:
            self.alive = False
            
    def draw(self, surface: pygame.Surface):
        """파티클 그리기 (서브클래스에서 구현)"""
        pass

class SmokeParticle(DamageParticle):
    """연기 파티클"""
    def __init__(self, x: float, y: float):
        super().__init__(x, y)
        self.vx = random.uniform(-0.5, 0.5)
        self.vy = random.uniform(-1.5, -0.5)
        self.radius = random.uniform(2, 5)
        self.max_lifetime = random.randint(60, 120)
        self.color_base = random.randint(40, 80)
        
    def update(self):
        super().update()
        # 연기가 위로 올라가면서 퍼짐
        self.vy -= 0.01  # 약간의 부력
        self.vx *= 0.99  # 수평 속도 감속
        self.radius += 0.1  # 크기 증가
        
    def draw(self, surface: pygame.Surface):
        # 알파값 계산 (점점 투명해짐)
        alpha = int(255 * (1 - self.lifetime / self.max_lifetime))
        alpha = max(0, min(255, alpha))
        
        # 연기 색상 (회색)
        color = (self.color_base, self.color_base, self.color_base, alpha)
        
        # 연기 그리기 (블러 효과를 위해 여러 크기로)
        for i in range(3):
            radius = int(self.radius + i * 2)
            temp_alpha = alpha // (i + 1)
            if temp_alpha > 0:
                smoke_surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(smoke_surf, (*color[:3], temp_alpha), (radius, radius), radius)
                surface.blit(smoke_surf, (int(self.x - radius), int(self.y - radius)))

class FireParticle(DamageParticle):
    """불꽃 파티클"""
    def __init__(self, x: float, y: float):
        super().__init__(x, y)
        self.vx = random.uniform(-1.0, 1.0)
        self.vy = random.uniform(-2.5, -1.0)
        self.radius = random.uniform(3, 6)
        self.max_lifetime = random.randint(20, 40)
        self.heat = 1.0  # 열 강도 (색상 결정)
        
    def update(self):
        super().update()
        # 불꽃이 위로 올라가면서 식음
        self.vy -= 0.05  # 더 강한 부력
        self.vx *= 0.95
        self.radius *= 0.95  # 크기 감소
        self.heat = 1 - (self.lifetime / self.max_lifetime)
        
    def draw(self, surface: pygame.Surface):
        if self.radius < 1:
            return
            
        # 열에 따른 색상 (빨강 -> 주황 -> 노랑)
        if self.heat > 0.7:
            r, g, b = 255, 255, int(200 * (1 - self.heat))  # 밝은 노랑
        elif self.heat > 0.4:
            r, g, b = 255, int(200 * self.heat), 0  # 주황
        else:
            r, g, b = int(255 * self.heat), 0, 0  # 어두운 빨강
            
        alpha = int(255 * self.heat)
        
        # 불꽃 그리기 (빛나는 효과)
        for i in range(2):
            radius = int(self.radius * (2 - i * 0.5))
            temp_alpha = alpha // (i + 1)
            if temp_alpha > 0 and radius > 0:
                fire_surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(fire_surf, (r, g, b, temp_alpha), (radius, radius), radius)
                surface.blit(fire_surf, (int(self.x - radius), int(self.y - radius)))

class SparkParticle(DamageParticle):
    """불꽃 튀는 파티클 (작은 불씨)"""
    def __init__(self, x: float, y: float):
        super().__init__(x, y)
        angle = random.uniform(0, math.pi * 2)
        speed = random.uniform(2, 4)
        self.vx = math.cos(angle) * speed
        self.vy = math.sin(angle) * speed - 1  # 약간 위로
        self.radius = random.uniform(1, 2)
        self.max_lifetime = random.randint(10, 20)
        self.trail = []  # 궤적
        
    def update(self):
        # 궤적 저장
        if len(self.trail) < 5:
            self.trail.append((self.x, self.y))
        else:
            self.trail.pop(0)
            self.trail.append((self.x, self.y))
            
        super().update()
        self.vy += 0.1  # 중력
        self.vx *= 0.98
        
    def draw(self, surface: pygame.Surface):
        alpha = int(255 * (1 - self.lifetime / self.max_lifetime))
        
        # 궤적 그리기
        for i, pos in enumerate(self.trail):
            trail_alpha = alpha * (i + 1) // len(self.trail)
            if trail_alpha > 0:
                pygame.draw.circle(surface, (255, 200, 0, trail_alpha), 
                                 (int(pos[0]), int(pos[1])), 1)
        
        # 불씨 그리기
        if alpha > 0:
            pygame.draw.circle(surface, (255, 255, 0, alpha), 
                             (int(self.x), int(self.y)), int(self.radius))

class BuildingDamageManager:
    """건물 손상 효과 관리자"""
    def __init__(self):
        self.damage_states: Dict[str, Dict] = {}
        
    def register_building(self, building_id: str, rect: pygame.Rect, max_hp: int):
        """건물 등록"""
        self.damage_states[building_id] = {
            'rect': rect.copy() if hasattr(rect, 'copy') else pygame.Rect(rect),
            'max_hp': max_hp,
            'current_hp': max_hp,
            'smoke_timer': 0,
            'fire_timer': 0,
            'spark_timer': 0,
            'damage_level': 0,  # 0: 정상, 1: 경미한 손상, 2: 심각한 손상
            'particles': []  # 이 건물의 파티클들
        }
        print(f"[손상 시스템] {building_id} 등록: rect={rect}, max_hp={max_hp}")
        
    def update_building_rect(self, building_id: str, rect: pygame.Rect):
        """건물 위치 업데이트"""
        if building_id in self.damage_states:
            self.damage_states[building_id]['rect'] = rect.copy() if hasattr(rect, 'copy') else pygame.Rect(rect)
    
    def update_building_hp(self, building_id: str, current_hp: int):
        """건물 체력 업데이트"""
        if building_id not in self.damage_states:
            return
            
        state = self.damage_states[building_id]
        state['current_hp'] = current_hp
        
        # 손상 레벨 결정 - HP 절대값 기준
        prev_level = state.get('damage_level', 0)
        if current_hp >= 3:  # 체력 3 이상
            state['damage_level'] = 0
        elif current_hp == 2:  # 체력이 정확히 2
            state['damage_level'] = 1
        else:  # 체력 1 이하
            state['damage_level'] = 2
            
        # 디버그 로그
        if prev_level != state['damage_level']:
            print(f"[손상 효과] {building_id}: HP {current_hp}, 손상 레벨 {prev_level} → {state['damage_level']}")
            state['debug_update_logged'] = False  # 리셋
            
    def update(self):
        """파티클 업데이트"""
        # 디버그: 건물 상태 확인
        has_damaged = False
        for building_id, state in self.damage_states.items():
            if state['damage_level'] > 0:
                has_damaged = True
                if not state.get('debug_update_logged'):
                    print(f"[손상 업데이트] {building_id}: 레벨 {state['damage_level']}, HP {state['current_hp']}/{state['max_hp']}")
                    state['debug_update_logged'] = True
        
        # 건물별 파티클 생성 및 업데이트
        for building_id, state in self.damage_states.items():
            if state['damage_level'] >= 1:
                # 연기 생성
                state['smoke_timer'] += 1
                if state['smoke_timer'] >= 5:  # 5프레임마다
                    self._spawn_smoke(state)
                    state['smoke_timer'] = 0
                    
            if state['damage_level'] >= 2:
                # 불꽃 생성
                state['fire_timer'] += 1
                if state['fire_timer'] >= 3:  # 3프레임마다
                    self._spawn_fire(state)
                    state['fire_timer'] = 0
                    
                # 불씨 생성
                state['spark_timer'] += 1
                if state['spark_timer'] >= 10:  # 10프레임마다
                    self._spawn_sparks(state)
                    state['spark_timer'] = 0
            
            # 파티클 업데이트
            for particle in state['particles'][:]:
                particle.update()
                if not particle.alive:
                    state['particles'].remove(particle)
                    
    def _spawn_smoke(self, state: Dict):
        """연기 생성"""
        rect = state['rect']
        # 건물 상단에서 연기 생성
        for _ in range(random.randint(1, 3)):
            x = rect.centerx + random.randint(-rect.width//3, rect.width//3)
            y = rect.top + random.randint(0, rect.height//4)
            state['particles'].append(SmokeParticle(x, y))
            
    def _spawn_fire(self, state: Dict):
        """불꽃 생성"""
        rect = state['rect']
        # 건물 곳곳에서 불꽃 생성
        for _ in range(random.randint(2, 4)):
            x = rect.centerx + random.randint(-rect.width//2, rect.width//2)
            y = rect.centery + random.randint(-rect.height//3, rect.height//3)
            state['particles'].append(FireParticle(x, y))
            
    def _spawn_sparks(self, state: Dict):
        """불씨 생성"""
        rect = state['rect']
        # 불꽃이 튀는 효과
        x = rect.centerx + random.randint(-rect.width//3, rect.width//3)
        y = rect.centery + random.randint(-rect.height//3, rect.height//3)
        
        for _ in range(random.randint(3, 6)):
            state['particles'].append(SparkParticle(x, y))
            
    def draw(self, surface: pygame.Surface):
        """모든 파티클 그리기"""
        # 디버그: 파티클 수 확인
        total_particles = 0
        for building_id, state in self.damage_states.items():
            total_particles += len(state['particles'])
            
        if total_particles > 0 and not hasattr(self, '_draw_logged'):
            print(f"[손상 그리기] 총 파티클 수: {total_particles}")
            for building_id, state in self.damage_states.items():
                if len(state['particles']) > 0:
                    print(f"  - {building_id}: {len(state['particles'])} 파티클")
            self._draw_logged = True
        
        # 모든 건물의 파티클 그리기
        for building_id, state in self.damage_states.items():
            for particle in state['particles']:
                particle.draw(surface)
            
    def draw_damage_overlay(self, surface: pygame.Surface, building_id: str, rect: pygame.Rect):
        """건물 손상 오버레이 그리기"""
        if building_id not in self.damage_states:
            return
            
        state = self.damage_states[building_id]
        damage_level = state['damage_level']
        
        if damage_level == 0:
            return
            
        # 손상 오버레이 (갈라진 효과)
        overlay = pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)
        
        if damage_level >= 1:
            # 경미한 손상 - 작은 균열
            self._draw_cracks(overlay, rect.width, rect.height, 3, 50)
            
        if damage_level >= 2:
            # 심각한 손상 - 큰 균열과 검은 그을음
            self._draw_cracks(overlay, rect.width, rect.height, 5, 80)
            # 그을음 효과
            for _ in range(10):
                x = random.randint(0, rect.width)
                y = random.randint(0, rect.height)
                radius = random.randint(5, 15)
                pygame.draw.circle(overlay, (0, 0, 0, 30), (x, y), radius)
                
        surface.blit(overlay, rect.topleft)
        
    def _draw_cracks(self, surface: pygame.Surface, width: int, height: int, 
                     crack_count: int, max_alpha: int):
        """균열 그리기"""
        for _ in range(crack_count):
            # 시작점
            start_x = random.randint(0, width)
            start_y = random.randint(0, height)
            
            # 균열 경로
            points = [(start_x, start_y)]
            current_x, current_y = start_x, start_y
            
            for _ in range(random.randint(3, 6)):
                # 랜덤한 방향으로 진행
                dx = random.randint(-20, 20)
                dy = random.randint(-20, 20)
                current_x = max(0, min(width, current_x + dx))
                current_y = max(0, min(height, current_y + dy))
                points.append((current_x, current_y))
                
            # 균열 그리기
            if len(points) > 1:
                pygame.draw.lines(surface, (20, 20, 20, max_alpha), False, points, 2)
                
    def clear_building(self, building_id: str):
        """건물 제거"""
        if building_id in self.damage_states:
            print(f"[손상 시스템] {building_id} 제거")
            del self.damage_states[building_id]

# 싱글톤 인스턴스
_damage_manager = None

def get_damage_manager() -> BuildingDamageManager:
    """손상 효과 관리자 인스턴스 반환"""
    global _damage_manager
    if _damage_manager is None:
        _damage_manager = BuildingDamageManager()
    return _damage_manager