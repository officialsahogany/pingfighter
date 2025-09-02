# -*- coding: utf-8 -*-
"""
🎁 Item System
아이템 시스템 - 아이템 생성, 효과, 관리
"""

import pygame
import random
import math
from typing import List, Dict, Optional, Any, Tuple
from enum import Enum
from dataclasses import dataclass, field


class ItemType(Enum):
    """아이템 타입"""
    PASSIVE = "passive"     # 즉시 효과
    ACTIVE = "active"       # 지속 효과
    LEGENDARY = "legendary" # 전설 아이템
    SPECIAL = "special"     # 특수 아이템


class ItemRarity(Enum):
    """아이템 희귀도"""
    COMMON = "common"       # 일반 (회색)
    UNCOMMON = "uncommon"   # 고급 (녹색)
    RARE = "rare"          # 희귀 (파란색)
    EPIC = "epic"          # 영웅 (보라색)
    LEGENDARY = "legendary" # 전설 (주황색)


@dataclass
class ItemEffect:
    """아이템 효과"""
    name: str
    value: float
    duration: float = 0
    description: str = ""
    
    def apply(self, target: Any):
        """효과 적용"""
        pass
    
    def remove(self, target: Any):
        """효과 제거"""
        pass


@dataclass
class Item:
    """아이템 클래스"""
    id: str
    name: str
    korean_name: str
    type: ItemType
    rarity: ItemRarity
    icon_path: str = ""
    icon: Optional[pygame.Surface] = None
    color: Tuple[int, int, int] = (128, 128, 128)
    effects: List[ItemEffect] = field(default_factory=list)
    duration: float = 0
    spawn_chance: float = 0.01
    unlock_condition: Optional[str] = None
    description: str = ""
    korean_description: str = ""
    
    # 런타임 상태
    active: bool = False
    remaining_duration: float = 0
    position: Optional[Tuple[float, float]] = None
    size: float = 30
    
    def __post_init__(self):
        """초기화 후 처리"""
        # 희귀도별 색상 설정
        if self.rarity == ItemRarity.UNCOMMON:
            self.color = (0, 255, 0)
        elif self.rarity == ItemRarity.RARE:
            self.color = (0, 100, 255)
        elif self.rarity == ItemRarity.EPIC:
            self.color = (150, 0, 255)
        elif self.rarity == ItemRarity.LEGENDARY:
            self.color = (255, 165, 0)
    
    def activate(self, game_state: Any):
        """아이템 활성화"""
        if self.type == ItemType.PASSIVE:
            # 즉시 효과 적용
            for effect in self.effects:
                effect.apply(game_state)
        else:
            # 지속 효과 시작
            self.active = True
            self.remaining_duration = self.duration
            for effect in self.effects:
                effect.apply(game_state)
    
    def update(self, dt: float, game_state: Any):
        """아이템 업데이트"""
        if self.active and self.type != ItemType.PASSIVE:
            self.remaining_duration -= dt
            
            if self.remaining_duration <= 0:
                self.deactivate(game_state)
    
    def deactivate(self, game_state: Any):
        """아이템 비활성화"""
        if self.active:
            self.active = False
            for effect in self.effects:
                effect.remove(game_state)
    
    def draw(self, screen: pygame.Surface):
        """아이템 그리기 (필드에 스폰된 경우)"""
        if self.position:
            x, y = self.position
            
            # 아이템 원 그리기
            pygame.draw.circle(screen, self.color, 
                             (int(x), int(y)), int(self.size))
            pygame.draw.circle(screen, (255, 255, 255), 
                             (int(x), int(y)), int(self.size), 2)
            
            # 아이콘이 있으면 그리기
            if self.icon:
                icon_rect = self.icon.get_rect(center=(int(x), int(y)))
                screen.blit(self.icon, icon_rect)


class ItemSystem:
    """
    🎁 아이템 시스템 관리자
    
    아이템의 생성, 관리, 효과 적용을 담당합니다.
    """
    
    def __init__(self, screen_width: int = 600, screen_height: int = 750):
        """
        아이템 시스템 초기화
        
        Args:
            screen_width: 화면 너비
            screen_height: 화면 높이
        """
        self.screen_width = screen_width
        self.screen_height = screen_height
        
        # 아이템 레지스트리
        self.item_registry: Dict[str, Item] = {}
        self.unlocked_items: Dict[str, bool] = {}
        
        # 활성 아이템
        self.spawned_items: List[Item] = []
        self.active_items: List[Item] = []
        self.passive_items: List[Item] = []
        
        # 아이템 스폰 설정
        self.spawn_timer = 0
        self.spawn_interval = 600  # 10초 (60 FPS)
        self.max_spawned_items = 3
        
        # 아이템 획득 기록
        self.collected_items: List[str] = []
        self.item_stats: Dict[str, int] = {}
        
        print("🎁 아이템 시스템 초기화 완료")
    
    def register_item(self, item: Item):
        """
        아이템 등록
        
        Args:
            item: 등록할 아이템
        """
        self.item_registry[item.id] = item
        self.unlocked_items[item.id] = item.unlock_condition is None
        self.item_stats[item.id] = 0
    
    def unlock_item(self, item_id: str):
        """아이템 잠금 해제"""
        if item_id in self.unlocked_items:
            self.unlocked_items[item_id] = True
            print(f"🔓 아이템 잠금 해제: {item_id}")
    
    def update(self, dt: float, game_state: Any):
        """
        아이템 시스템 업데이트
        
        Args:
            dt: 델타 타임
            game_state: 게임 상태
        """
        # 아이템 스폰 타이머
        self.spawn_timer += dt * 60
        if self.spawn_timer >= self.spawn_interval:
            self.spawn_timer = 0
            self.try_spawn_item()
        
        # 활성 아이템 업데이트
        for item in self.active_items[:]:
            item.update(dt, game_state)
            if not item.active:
                self.active_items.remove(item)
        
        # 스폰된 아이템 업데이트 (애니메이션 등)
        for item in self.spawned_items:
            if hasattr(item, 'animation_update'):
                item.animation_update(dt)
    
    def try_spawn_item(self):
        """아이템 스폰 시도"""
        if len(self.spawned_items) >= self.max_spawned_items:
            return
        
        # 잠금 해제된 아이템 중에서 선택
        available_items = [
            item for item_id, item in self.item_registry.items()
            if self.unlocked_items.get(item_id, False)
        ]
        
        if not available_items:
            return
        
        # 확률에 따라 아이템 선택
        total_chance = sum(item.spawn_chance for item in available_items)
        if total_chance <= 0:
            return
        
        rand = random.random() * total_chance
        cumulative = 0
        
        for item in available_items:
            cumulative += item.spawn_chance
            if rand <= cumulative:
                self.spawn_item(item)
                break
    
    def spawn_item(self, item_template: Item, position: Optional[Tuple[float, float]] = None):
        """
        아이템 스폰
        
        Args:
            item_template: 스폰할 아이템 템플릿
            position: 스폰 위치 (None이면 랜덤)
        """
        # 아이템 복사 (새 인스턴스 생성)
        import copy
        item = copy.deepcopy(item_template)
        
        # 위치 설정
        if position:
            item.position = position
        else:
            # 랜덤 위치
            margin = 50
            item.position = (
                random.randint(margin, self.screen_width - margin),
                random.randint(100, self.screen_height - 200)
            )
        
        self.spawned_items.append(item)
        print(f"🎁 아이템 스폰: {item.name} at {item.position}")
    
    def check_collection(self, collector_rect: pygame.Rect) -> Optional[Item]:
        """
        아이템 수집 체크
        
        Args:
            collector_rect: 수집자의 충돌 박스
            
        Returns:
            수집된 아이템 또는 None
        """
        for item in self.spawned_items[:]:
            if item.position:
                x, y = item.position
                item_rect = pygame.Rect(
                    x - item.size, y - item.size,
                    item.size * 2, item.size * 2
                )
                
                if collector_rect.colliderect(item_rect):
                    self.spawned_items.remove(item)
                    self.collect_item(item)
                    return item
        
        return None
    
    def collect_item(self, item: Item):
        """
        아이템 수집 처리
        
        Args:
            item: 수집된 아이템
        """
        # 통계 업데이트
        self.collected_items.append(item.id)
        self.item_stats[item.id] = self.item_stats.get(item.id, 0) + 1
        
        # 타입별 처리
        if item.type == ItemType.PASSIVE:
            self.passive_items.append(item)
        else:
            self.active_items.append(item)
        
        print(f"💎 아이템 획득: {item.name} ({item.type.value})")
    
    def activate_item(self, item_id: str, game_state: Any):
        """
        아이템 활성화
        
        Args:
            item_id: 활성화할 아이템 ID
            game_state: 게임 상태
        """
        if item_id in self.item_registry:
            item = self.item_registry[item_id]
            item.activate(game_state)
            
            if item.type != ItemType.PASSIVE:
                self.active_items.append(item)
    
    def draw_spawned_items(self, screen: pygame.Surface):
        """스폰된 아이템 그리기"""
        for item in self.spawned_items:
            item.draw(screen)
    
    def draw_active_effects(self, screen: pygame.Surface):
        """활성 효과 표시"""
        y_offset = 10
        for item in self.active_items:
            if item.active:
                # 효과 이름과 남은 시간 표시
                text = f"{item.name}: {item.remaining_duration:.1f}s"
                # 실제 게임에서는 폰트 렌더링 사용
                # 여기서는 간단한 표시만
                pass
    
    def get_active_items(self) -> List[Item]:
        """활성 아이템 목록 반환"""
        return self.active_items
    
    def get_passive_items(self) -> List[Item]:
        """패시브 아이템 목록 반환"""
        return self.passive_items
    
    def get_item_stats(self) -> Dict[str, int]:
        """아이템 통계 반환"""
        return self.item_stats.copy()
    
    def reset(self):
        """아이템 시스템 초기화"""
        self.spawned_items.clear()
        self.active_items.clear()
        self.passive_items.clear()
        self.collected_items.clear()
        self.spawn_timer = 0
        
        print("🎁 아이템 시스템 리셋 완료")


# 기본 아이템 효과 클래스들
class SpeedBoostEffect(ItemEffect):
    """속도 증가 효과"""
    
    def apply(self, target: Any):
        if hasattr(target, 'speed_multiplier'):
            target.speed_multiplier *= (1 + self.value)
    
    def remove(self, target: Any):
        if hasattr(target, 'speed_multiplier'):
            target.speed_multiplier /= (1 + self.value)


class DamageBoostEffect(ItemEffect):
    """데미지 증가 효과"""
    
    def apply(self, target: Any):
        if hasattr(target, 'damage_multiplier'):
            target.damage_multiplier *= (1 + self.value)
    
    def remove(self, target: Any):
        if hasattr(target, 'damage_multiplier'):
            target.damage_multiplier /= (1 + self.value)


class ShieldEffect(ItemEffect):
    """실드 효과"""
    
    def apply(self, target: Any):
        if hasattr(target, 'shield'):
            target.shield = True
            target.shield_hp = self.value
    
    def remove(self, target: Any):
        if hasattr(target, 'shield'):
            target.shield = False
            target.shield_hp = 0


def create_default_items() -> List[Item]:
    """기본 아이템 생성"""
    items = []
    
    # 속도 부스트 아이템
    speed_item = Item(
        id="speed_boost",
        name="Speed Boost",
        korean_name="속도 부스트",
        type=ItemType.ACTIVE,
        rarity=ItemRarity.COMMON,
        effects=[SpeedBoostEffect("speed", 0.5, 300, "속도 50% 증가")],
        duration=300,
        spawn_chance=0.03,
        description="Increases movement speed by 50%",
        korean_description="이동 속도를 50% 증가시킵니다"
    )
    items.append(speed_item)
    
    # 파워 부스트 아이템
    power_item = Item(
        id="power_boost",
        name="Power Boost",
        korean_name="파워 부스트",
        type=ItemType.ACTIVE,
        rarity=ItemRarity.UNCOMMON,
        effects=[DamageBoostEffect("damage", 1.0, 300, "데미지 2배")],
        duration=300,
        spawn_chance=0.02,
        description="Doubles damage output",
        korean_description="공격력을 2배로 증가시킵니다"
    )
    items.append(power_item)
    
    # 실드 아이템
    shield_item = Item(
        id="shield",
        name="Shield",
        korean_name="실드",
        type=ItemType.ACTIVE,
        rarity=ItemRarity.RARE,
        effects=[ShieldEffect("shield", 3, 600, "3회 방어")],
        duration=600,
        spawn_chance=0.01,
        description="Blocks 3 hits",
        korean_description="3회의 공격을 막아줍니다"
    )
    items.append(shield_item)
    
    return items