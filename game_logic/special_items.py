"""
Special Items System - 특수 아이템 시스템
레거시 bosspong의 모든 특수 아이템 기능 구현
"""

import pygame
import math
import random
from typing import List, Dict, Any, Optional, Tuple
from enum import Enum
from dataclasses import dataclass
from core.events import EventType, emit_event
from core.global_manager import GlobalManager

class ItemType(Enum):
    """특수 아이템 타입"""
    FIREBALL = "fireball"
    TEARS = "tears_of_pain"
    LONG_BOOST = "long_boost"
    FLARE = "flare"
    SMOKE_GRENADE = "smoke_grenade"
    GRENADE = "grenade"
    MOLOTOV = "molotov"
    WALL = "wall"
    MEDITATION = "meditation"
    QUAKE = "quake"
    WHIP = "whip"
    BALLOON = "balloon"

@dataclass
class SpecialItem:
    """특수 아이템 클래스"""
    item_type: ItemType
    position: Tuple[float, float]
    velocity: Tuple[float, float]
    duration: float
    active: bool = True
    data: Dict[str, Any] = None
    
    def __post_init__(self):
        if self.data is None:
            self.data = {}

class SpecialItemManager:
    """특수 아이템 매니저"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        self.items: List[SpecialItem] = []
        
        # 아이템별 쿨다운
        self.cooldowns: Dict[ItemType, float] = {}
        
        # 활성 효과들
        self.active_effects: Dict[str, Any] = {}
        
        # 화면 크기
        self.width = self.global_manager.get('WIDTH', 600)
        self.height = self.global_manager.get('HEIGHT', 750)
        
    def activate_fireball(self):
        """화염구 발동"""
        ball_rect = self.global_manager.get('BALL')
        if not ball_rect:
            return
            
        # 화염구 효과: 공이 빨간색으로 변하고 파괴력 증가
        self.active_effects['fireball'] = {
            'duration': 180,  # 3초
            'power_multiplier': 2.0,
            'color': (255, 100, 50)
        }
        
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'fireball',
            'duration': 180
        })
        
        # 사운드 재생
        emit_event(EventType.PLAY_SOUND, {'sound': 'fireball'})
        
    def activate_tears_of_pain(self):
        """고통의 눈물 발동"""
        # 여러 개의 눈물 생성
        boss_rect = self.global_manager.get('BOSS')
        if not boss_rect:
            return
            
        for i in range(5):
            tear = SpecialItem(
                item_type=ItemType.TEARS,
                position=(boss_rect.centerx + (i - 2) * 30, boss_rect.bottom),
                velocity=(random.uniform(-2, 2), random.uniform(3, 5)),
                duration=300  # 5초
            )
            self.items.append(tear)
            
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'tears',
            'count': 5
        })
        
        # 사운드 재생
        emit_event(EventType.PLAY_SOUND, {'sound': 'tears'})
        
    def activate_long_boost(self):
        """긴 부스트 발동"""
        # 플레이어 속도 대폭 증가
        self.active_effects['long_boost'] = {
            'duration': 300,  # 5초
            'speed_multiplier': 2.5
        }
        
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'long_boost',
            'duration': 300
        })
        
    def activate_flare(self):
        """조명탄 발동"""
        # 화면을 밝게 하고 궤적 예측 표시
        self.active_effects['flare'] = {
            'duration': 240,  # 4초
            'brightness': 1.5,
            'show_trajectory': True
        }
        
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'flare'
        })
        
    def activate_smoke_grenade(self):
        """연막탄 발동"""
        # 화면 일부를 가림
        player_rect = self.global_manager.get('PLAYER')
        if not player_rect:
            return
            
        smoke = SpecialItem(
            item_type=ItemType.SMOKE_GRENADE,
            position=(player_rect.centerx, player_rect.centery - 50),
            velocity=(0, -2),
            duration=180,
            data={'radius': 150, 'opacity': 200}
        )
        self.items.append(smoke)
        
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'smoke_grenade'
        })
        
    def activate_grenade(self):
        """수류탄 발동"""
        player_rect = self.global_manager.get('PLAYER')
        if not player_rect:
            return
            
        grenade = SpecialItem(
            item_type=ItemType.GRENADE,
            position=(player_rect.centerx, player_rect.centery - 30),
            velocity=(0, -8),
            duration=60,  # 1초 후 폭발
            data={'explosion_radius': 100, 'damage': 3}
        )
        self.items.append(grenade)
        
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'grenade'
        })
        
    def activate_molotov(self):
        """화염병 발동"""
        player_rect = self.global_manager.get('PLAYER')
        if not player_rect:
            return
            
        molotov = SpecialItem(
            item_type=ItemType.MOLOTOV,
            position=(player_rect.centerx, player_rect.centery - 30),
            velocity=(random.uniform(-2, 2), -6),
            duration=300,  # 5초간 불타는 영역
            data={'fire_radius': 80, 'damage_per_frame': 0.1}
        )
        self.items.append(molotov)
        
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'molotov'
        })
        
    def activate_wall(self):
        """벽 생성"""
        player_rect = self.global_manager.get('PLAYER')
        if not player_rect:
            return
            
        # 플레이어 앞에 임시 벽 생성
        wall = SpecialItem(
            item_type=ItemType.WALL,
            position=(player_rect.centerx, player_rect.centery - 100),
            velocity=(0, 0),
            duration=240,  # 4초
            data={'width': 150, 'height': 20, 'health': 5}
        )
        self.items.append(wall)
        
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'wall'
        })
        
    def activate_meditation(self):
        """명상 발동"""
        # 시간 느려짐 효과
        self.active_effects['meditation'] = {
            'duration': 180,  # 3초
            'time_scale': 0.5,  # 50% 속도
            'focus_bonus': 2.0
        }
        
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'meditation'
        })
        
    def activate_quake(self):
        """지진 발동"""
        # 화면 흔들림과 공 궤적 변화
        self.active_effects['quake'] = {
            'duration': 120,  # 2초
            'shake_intensity': 10,
            'ball_chaos': 3.0
        }
        
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'quake'
        })
        emit_event(EventType.SCREEN_SHAKE, {'intensity': 10, 'duration': 120})
        
    def activate_whip(self):
        """채찍 발동"""
        player_rect = self.global_manager.get('PLAYER')
        if not player_rect:
            return
            
        # 채찍 효과: 넓은 범위 타격
        whip = SpecialItem(
            item_type=ItemType.WHIP,
            position=(player_rect.centerx, player_rect.centery),
            velocity=(0, -10),
            duration=30,  # 0.5초
            data={'range': 200, 'width': 30}
        )
        self.items.append(whip)
        
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'whip'
        })
        emit_event(EventType.PLAY_SOUND, {'sound': 'whip'})
        
    def activate_balloon(self):
        """풍선 발동"""
        # 공이 천천히 떠오르는 효과
        self.active_effects['balloon'] = {
            'duration': 240,  # 4초
            'gravity_multiplier': -0.5,  # 역중력
            'float_speed': 2.0
        }
        
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'type': 'balloon'
        })
        
    def update(self, dt: float):
        """업데이트"""
        # 아이템 업데이트
        for item in self.items[:]:
            item.duration -= dt * 60
            
            # 위치 업데이트
            if item.velocity != (0, 0):
                item.position = (
                    item.position[0] + item.velocity[0] * dt * 60,
                    item.position[1] + item.velocity[1] * dt * 60
                )
                
            # 수류탄 폭발
            if item.item_type == ItemType.GRENADE and item.duration <= 0:
                self._explode_grenade(item)
                self.items.remove(item)
            # 화염병 착지
            elif item.item_type == ItemType.MOLOTOV and item.position[1] > self.height - 100:
                item.velocity = (0, 0)  # 멈춤
                item.data['burning'] = True
            # 만료된 아이템 제거
            elif item.duration <= 0:
                self.items.remove(item)
                
        # 활성 효과 업데이트
        for effect_name in list(self.active_effects.keys()):
            effect = self.active_effects[effect_name]
            effect['duration'] -= dt * 60
            
            if effect['duration'] <= 0:
                del self.active_effects[effect_name]
                
    def _explode_grenade(self, grenade: SpecialItem):
        """수류탄 폭발"""
        emit_event(EventType.EXPLOSION, {
            'position': grenade.position,
            'radius': grenade.data['explosion_radius'],
            'damage': grenade.data['damage']
        })
        emit_event(EventType.PLAY_SOUND, {'sound': 'explosion'})
        emit_event(EventType.SCREEN_SHAKE, {'intensity': 15, 'duration': 30})
        
    def render(self, screen: pygame.Surface):
        """렌더링"""
        # 아이템 렌더링
        for item in self.items:
            if item.item_type == ItemType.TEARS:
                # 눈물 그리기
                pygame.draw.circle(screen, (100, 150, 255), 
                                 (int(item.position[0]), int(item.position[1])), 8)
            elif item.item_type == ItemType.SMOKE_GRENADE:
                # 연막 그리기
                if item.data.get('radius'):
                    smoke_surface = pygame.Surface((item.data['radius'] * 2, 
                                                   item.data['radius'] * 2), 
                                                  pygame.SRCALPHA)
                    pygame.draw.circle(smoke_surface, (150, 150, 150, item.data['opacity']),
                                     (item.data['radius'], item.data['radius']), 
                                     item.data['radius'])
                    screen.blit(smoke_surface, 
                              (item.position[0] - item.data['radius'],
                               item.position[1] - item.data['radius']))
            elif item.item_type == ItemType.GRENADE:
                # 수류탄 그리기
                pygame.draw.circle(screen, (100, 100, 100), 
                                 (int(item.position[0]), int(item.position[1])), 10)
            elif item.item_type == ItemType.MOLOTOV:
                # 화염병 그리기
                if item.data.get('burning'):
                    # 불타는 영역
                    for i in range(5):
                        flame_x = item.position[0] + random.randint(-40, 40)
                        flame_y = item.position[1] + random.randint(-20, 0)
                        pygame.draw.circle(screen, (255, 100 + i * 30, 0),
                                         (int(flame_x), int(flame_y)), 
                                         random.randint(5, 15))
                else:
                    # 날아가는 화염병
                    pygame.draw.rect(screen, (200, 100, 50),
                                   (item.position[0] - 5, item.position[1] - 10, 10, 20))
            elif item.item_type == ItemType.WALL:
                # 벽 그리기
                pygame.draw.rect(screen, (150, 150, 150),
                               (item.position[0] - item.data['width'] // 2,
                                item.position[1] - item.data['height'] // 2,
                                item.data['width'], item.data['height']))
            elif item.item_type == ItemType.WHIP:
                # 채찍 그리기
                for i in range(5):
                    y = item.position[1] - i * 40
                    pygame.draw.line(screen, (200, 100, 50),
                                   (item.position[0] - item.data['width'] // 2, y),
                                   (item.position[0] + item.data['width'] // 2, y), 3)
                    
        # 조명탄 효과
        if 'flare' in self.active_effects:
            # 화면 밝게
            overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            overlay.fill((255, 255, 200, 50))
            screen.blit(overlay, (0, 0))
            
    def get_active_effects(self) -> Dict[str, Any]:
        """활성 효과 반환"""
        return self.active_effects.copy()
        
    def clear(self):
        """초기화"""
        self.items.clear()
        self.active_effects.clear()
        self.cooldowns.clear()

# 싱글톤 인스턴스
_special_item_manager = None

def get_special_item_manager() -> SpecialItemManager:
    """특수 아이템 매니저 싱글톤 반환"""
    global _special_item_manager
    if _special_item_manager is None:
        _special_item_manager = SpecialItemManager()
    return _special_item_manager
