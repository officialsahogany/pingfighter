"""
Special Abilities System - 특수 능력 시스템
모든 특수 능력과 스킬 관리
"""

import pygame
import random
import math
from typing import Dict, Any, Optional, List, Tuple
from core.events import EventType, emit_event
from core.global_manager import GlobalManager
from managers.sound_manager import get_sound_manager
from managers.effects_manager import get_effects_manager


class SpecialAbility:
    """특수 능력 기본 클래스"""
    
    def __init__(self, name: str, cooldown: float, gauge_cost: int = 0):
        self.name = name
        self.cooldown = cooldown
        self.gauge_cost = gauge_cost
        self.active = False
        self.timer = 0
        self.cooldown_timer = 0
        
    def can_activate(self, gauge: int = 0) -> bool:
        """활성화 가능 여부"""
        return not self.active and self.cooldown_timer <= 0 and gauge >= self.gauge_cost
        
    def activate(self):
        """능력 활성화"""
        if not self.can_activate():
            return False
            
        self.active = True
        self.timer = 0
        self.cooldown_timer = self.cooldown
        
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': self.name,
            'gauge_cost': self.gauge_cost
        })
        
        return True
        
    def update(self, dt: float):
        """업데이트"""
        if self.active:
            self.timer += dt
            
        if self.cooldown_timer > 0:
            self.cooldown_timer -= dt
            
    def deactivate(self):
        """능력 비활성화"""
        self.active = False
        self.timer = 0


class FireballAbility(SpecialAbility):
    """파이어볼 능력"""
    
    def __init__(self):
        super().__init__("fireball", cooldown=5.0, gauge_cost=30)
        self.fireballs = []
        
    def activate(self):
        """파이어볼 활성화"""
        if not super().activate():
            return False
            
        global_manager = GlobalManager.get_instance()
        player_rect = global_manager.get('PLAYER')
        
        if player_rect:
            # 파이어볼 생성
            fireball = {
                'x': player_rect.centerx,
                'y': player_rect.centery - 50,
                'dx': 0,
                'dy': -10,
                'radius': 15,
                'damage': 2
            }
            self.fireballs.append(fireball)
            
            # 사운드 재생
            sound_manager = get_sound_manager()
            sound_manager.play_sound('fireball')
            
            # 이펙트 생성
            effects_manager = get_effects_manager()
            effects_manager.create_explosion(
                player_rect.centerx,
                player_rect.centery - 50,
                color=(255, 100, 0)
            )
            
        return True
        
    def update(self, dt: float):
        """파이어볼 업데이트"""
        super().update(dt)
        
        # 파이어볼 이동
        for fireball in self.fireballs[:]:
            fireball['y'] += fireball['dy'] * dt * 60
            
            # 화면 밖으로 나가면 제거
            if fireball['y'] < -50:
                self.fireballs.remove(fireball)
                
    def render(self, screen: pygame.Surface):
        """파이어볼 렌더링"""
        for fireball in self.fireballs:
            # 파이어볼 그리기
            pygame.draw.circle(
                screen,
                (255, 100, 0),
                (int(fireball['x']), int(fireball['y'])),
                fireball['radius']
            )
            
            # 불꽃 효과
            for i in range(3):
                offset_x = random.randint(-5, 5)
                offset_y = random.randint(-5, 5)
                pygame.draw.circle(
                    screen,
                    (255, 200, 0),
                    (int(fireball['x'] + offset_x), int(fireball['y'] + offset_y)),
                    fireball['radius'] // 2
                )


class TearsOfPainAbility(SpecialAbility):
    """고통의 눈물 능력"""
    
    def __init__(self):
        super().__init__("tears_of_pain", cooldown=10.0, gauge_cost=50)
        self.tears = []
        self.tear_spawn_timer = 0
        self.duration = 5.0
        
    def activate(self):
        """눈물 활성화"""
        if not super().activate():
            return False
            
        # 사운드 재생
        sound_manager = get_sound_manager()
        sound_manager.play_sound('tears')
        
        return True
        
    def update(self, dt: float):
        """눈물 업데이트"""
        super().update(dt)
        
        if self.active:
            # 지속 시간 체크
            if self.timer >= self.duration:
                self.deactivate()
                return
                
            # 눈물 생성
            self.tear_spawn_timer += dt
            if self.tear_spawn_timer >= 0.1:  # 0.1초마다 눈물 생성
                self.tear_spawn_timer = 0
                self._spawn_tear()
                
        # 눈물 이동
        global_manager = GlobalManager.get_instance()
        for tear in self.tears[:]:
            tear['y'] += tear['dy'] * dt * 60
            
            # 화면 밖으로 나가면 제거
            if tear['y'] > global_manager.get('HEIGHT', 750):
                self.tears.remove(tear)
                
    def _spawn_tear(self):
        """눈물 생성"""
        global_manager = GlobalManager.get_instance()
        boss_rect = global_manager.get('BOSS')
        
        if boss_rect:
            tear = {
                'x': boss_rect.centerx + random.randint(-30, 30),
                'y': boss_rect.centery,
                'dy': random.uniform(3, 6),
                'radius': 5
            }
            self.tears.append(tear)
            
    def render(self, screen: pygame.Surface):
        """눈물 렌더링"""
        for tear in self.tears:
            # 눈물 그리기 (파란색)
            pygame.draw.circle(
                screen,
                (100, 150, 255),
                (int(tear['x']), int(tear['y'])),
                tear['radius']
            )


class WallAbility(SpecialAbility):
    """벽 생성 능력"""
    
    def __init__(self):
        super().__init__("wall", cooldown=15.0, gauge_cost=40)
        self.walls = []
        self.max_walls = 3
        
    def activate(self):
        """벽 생성"""
        if not super().activate():
            return False
            
        global_manager = GlobalManager.get_instance()
        player_rect = global_manager.get('PLAYER')
        
        if player_rect and len(self.walls) < self.max_walls:
            # 벽 생성
            wall = {
                'x': player_rect.centerx,
                'y': player_rect.centery - 100,
                'width': 100,
                'height': 20,
                'hp': 3,
                'max_hp': 3
            }
            self.walls.append(wall)
            
            # 사운드 재생
            sound_manager = get_sound_manager()
            sound_manager.play_sound('wall_create')
            
            # 이펙트 생성
            effects_manager = get_effects_manager()
            effects_manager.create_impact_effect(
                player_rect.centerx,
                player_rect.centery - 100
            )
            
        return True
        
    def update(self, dt: float):
        """벽 업데이트"""
        super().update(dt)
        
        # 파괴된 벽 제거
        self.walls = [wall for wall in self.walls if wall['hp'] > 0]
        
    def check_collision(self, ball_rect: pygame.Rect, ball_vel: List[float]) -> bool:
        """벽과 공 충돌 체크"""
        for wall in self.walls:
            wall_rect = pygame.Rect(
                wall['x'] - wall['width'] // 2,
                wall['y'] - wall['height'] // 2,
                wall['width'],
                wall['height']
            )
            
            if ball_rect.colliderect(wall_rect):
                # 벽 데미지
                wall['hp'] -= 1
                
                # 공 반사
                ball_vel[1] = -ball_vel[1]
                
                # 이펙트
                effects_manager = get_effects_manager()
                effects_manager.create_impact_effect(
                    ball_rect.centerx,
                    ball_rect.centery
                )
                
                return True
                
        return False
        
    def render(self, screen: pygame.Surface):
        """벽 렌더링"""
        for wall in self.walls:
            # 벽 색상 (체력에 따라)
            hp_ratio = wall['hp'] / wall['max_hp']
            color = (
                int(100 + 155 * hp_ratio),
                int(100 + 155 * hp_ratio),
                int(100 + 155 * hp_ratio)
            )
            
            # 벽 그리기
            wall_rect = pygame.Rect(
                wall['x'] - wall['width'] // 2,
                wall['y'] - wall['height'] // 2,
                wall['width'],
                wall['height']
            )
            pygame.draw.rect(screen, color, wall_rect)
            pygame.draw.rect(screen, (255, 255, 255), wall_rect, 2)


class MeditationAbility(SpecialAbility):
    """명상 능력"""
    
    def __init__(self):
        super().__init__("meditation", cooldown=20.0, gauge_cost=60)
        self.duration = 5.0
        self.heal_rate = 0.5  # 초당 회복량
        self.speed_boost = 1.5
        
    def activate(self):
        """명상 활성화"""
        if not super().activate():
            return False
            
        # 사운드 재생
        sound_manager = get_sound_manager()
        sound_manager.play_sound('meditation')
        
        # 이펙트
        global_manager = GlobalManager.get_instance()
        player_rect = global_manager.get('PLAYER')
        
        if player_rect:
            effects_manager = get_effects_manager()
            effects_manager.create_aura_effect(
                player_rect.centerx,
                player_rect.centery,
                color=(100, 255, 100),
                duration=self.duration
            )
            
        return True
        
    def update(self, dt: float):
        """명상 업데이트"""
        super().update(dt)
        
        if self.active:
            # 지속 시간 체크
            if self.timer >= self.duration:
                self.deactivate()
                return
                
            # 체력 회복 (구현 필요)
            # 속도 부스트 적용
            global_manager = GlobalManager.get_instance()
            global_manager.set('player_speed_multiplier', self.speed_boost)
            
    def deactivate(self):
        """명상 비활성화"""
        super().deactivate()
        
        # 속도 부스트 제거
        global_manager = GlobalManager.get_instance()
        global_manager.set('player_speed_multiplier', 1.0)


class QuakeAbility(SpecialAbility):
    """지진 능력"""
    
    def __init__(self):
        super().__init__("quake", cooldown=15.0, gauge_cost=70)
        self.duration = 3.0
        self.shake_intensity = 10
        
    def activate(self):
        """지진 활성화"""
        if not super().activate():
            return False
            
        # 사운드 재생
        sound_manager = get_sound_manager()
        sound_manager.play_sound('quake', loop=True)
        
        # 화면 흔들림
        effects_manager = get_effects_manager()
        effects_manager.trigger_screen_shake(
            intensity=self.shake_intensity,
            duration=self.duration
        )
        
        return True
        
    def update(self, dt: float):
        """지진 업데이트"""
        super().update(dt)
        
        if self.active:
            # 지속 시간 체크
            if self.timer >= self.duration:
                self.deactivate()
                return
                
            # 공 속도 변화
            global_manager = GlobalManager.get_instance()
            ball_dx = global_manager.get('ball_dx', 0)
            ball_dy = global_manager.get('ball_dy', 5)
            
            # 랜덤 흔들림
            ball_dx += random.uniform(-0.5, 0.5)
            ball_dy += random.uniform(-0.5, 0.5)
            
            global_manager.set('ball_dx', ball_dx)
            global_manager.set('ball_dy', ball_dy)
            
    def deactivate(self):
        """지진 비활성화"""
        super().deactivate()
        
        # 사운드 중지
        sound_manager = get_sound_manager()
        sound_manager.stop_sound('quake')


class SpecialAbilityManager:
    """특수 능력 관리자"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        self.abilities: Dict[str, SpecialAbility] = {}
        
        # 기본 능력들 등록
        self.register_ability('fireball', FireballAbility())
        self.register_ability('tears_of_pain', TearsOfPainAbility())
        self.register_ability('wall', WallAbility())
        self.register_ability('meditation', MeditationAbility())
        self.register_ability('quake', QuakeAbility())
        
        # 게이지 시스템
        self.special_gauge = 0
        self.max_gauge = 100
        
    def register_ability(self, name: str, ability: SpecialAbility):
        """능력 등록"""
        self.abilities[name] = ability
        
    def activate_ability(self, name: str) -> bool:
        """능력 활성화"""
        if name not in self.abilities:
            return False
            
        ability = self.abilities[name]
        
        # 게이지 체크
        if ability.gauge_cost > self.special_gauge:
            return False
            
        # 능력 활성화
        if ability.activate():
            self.special_gauge -= ability.gauge_cost
            return True
            
        return False
        
    def update(self, dt: float):
        """업데이트"""
        # 모든 능력 업데이트
        for ability in self.abilities.values():
            ability.update(dt)
            
        # 게이지 자연 회복
        self.special_gauge = min(self.max_gauge, self.special_gauge + dt * 5)
        
    def render(self, screen: pygame.Surface):
        """렌더링"""
        # 능력별 렌더링
        for ability in self.abilities.values():
            if hasattr(ability, 'render'):
                ability.render(screen)
                
        # 게이지 UI 렌더링
        self._render_gauge_ui(screen)
        
    def _render_gauge_ui(self, screen: pygame.Surface):
        """게이지 UI 렌더링"""
        # 게이지 바
        gauge_width = 200
        gauge_height = 20
        gauge_x = 10
        gauge_y = self.global_manager.get('HEIGHT', 750) - 100
        
        # 배경
        pygame.draw.rect(screen, (50, 50, 50),
                        (gauge_x, gauge_y, gauge_width, gauge_height))
                        
        # 게이지
        fill_width = int(gauge_width * (self.special_gauge / self.max_gauge))
        if fill_width > 0:
            pygame.draw.rect(screen, (255, 200, 0),
                           (gauge_x, gauge_y, fill_width, gauge_height))
                           
        # 테두리
        pygame.draw.rect(screen, (255, 255, 255),
                        (gauge_x, gauge_y, gauge_width, gauge_height), 2)
                        
        # 텍스트
        font = pygame.font.Font(None, 16)
        text = font.render(f"SPECIAL: {int(self.special_gauge)}/{self.max_gauge}",
                          True, (255, 255, 255))
        screen.blit(text, (gauge_x, gauge_y - 20))
        
    def add_gauge(self, amount: int):
        """게이지 추가"""
        self.special_gauge = min(self.max_gauge, self.special_gauge + amount)
        
    def check_wall_collision(self, ball_rect: pygame.Rect, ball_vel: List[float]) -> bool:
        """벽 충돌 체크"""
        if 'wall' in self.abilities:
            wall_ability = self.abilities['wall']
            if isinstance(wall_ability, WallAbility):
                return wall_ability.check_collision(ball_rect, ball_vel)
        return False


# 싱글톤 인스턴스
_special_ability_manager = None

def get_special_ability_manager() -> SpecialAbilityManager:
    """특수 능력 매니저 싱글톤 반환"""
    global _special_ability_manager
    if _special_ability_manager is None:
        _special_ability_manager = SpecialAbilityManager()
    return _special_ability_manager