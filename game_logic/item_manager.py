"""
Item Manager - 아이템 시스템 관리
전체 아이템 드롭, 획득, 효과 관리
"""

import pygame
import random
import math
from typing import Dict, List, Optional, Any
from core.global_manager import GlobalManager
from core.events import EventType, emit_event
import items  # 기존 items.py 활용


class ItemManager:
    """아이템 관리 시스템"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        
        # 아이템 리스트
        self.active_items = []  # 화면에 떠있는 아이템
        self.passive_items = []  # 획득한 패시브 아이템
        self.active_item_slots = []  # 액티브 아이템 슬롯
        
        # 슬롯 설정
        self.max_item_slots = 3
        self.selected_slot_index = 0
        
        # 아이템 획득 상태 (items.py와 연동)
        self.item_states = {
            'slot_add_obtained': 0,
            'speedboots_obtained': False,
            'speedgear_obtained': False,
            'battery_obtained': False,
            'revival_obtained': False,
            'revival_used': False,
            'master_obtained': False,
            'cooltime_obtained': False,
            'chargebag_obtained': False,
            'spikeboots_obtained': False,
            'dashgear_obtained': False,
            'bulkup_obtained': False,
            'sensor_obtained': False,
            'gravitybelt_obtained': False,
            'dashholder_obtained': False
        }
        
        # 아이템 쿨다운
        self.item_cooldowns = {}
        self.default_cooldown = 8000  # 8초
        
    def spawn_item(self) -> bool:
        """랜덤 아이템 스폰
        
        Returns:
            스폰 성공 여부
        """
        # items.py의 spawn_random_item 활용
        available_items = self._get_available_items()
        
        if not available_items:
            return False
            
        # 확률 계산
        total_chance = sum(item['chance'] for item in available_items)
        random_value = random.random() * total_chance
        
        current_chance = 0
        selected_item = None
        
        for item in available_items:
            current_chance += item['chance']
            if random_value <= current_chance:
                selected_item = item
                break
                
        if selected_item:
            self._create_item(selected_item)
            return True
            
        return False
        
    def _get_available_items(self) -> List[Dict]:
        """스폰 가능한 아이템 목록 반환"""
        available = []
        
        for item_type in items.ITEM_TYPES:
            # 해금 체크
            if not items.unlocked_items.get(item_type['name'], False):
                continue
                
            # 획득 제한 체크
            if self._is_item_limited(item_type['name']):
                continue
                
            available.append(item_type)
            
        return available
        
    def _is_item_limited(self, item_name: str) -> bool:
        """아이템이 획득 제한에 걸렸는지 체크"""
        # slot_add는 2개까지
        if item_name == 'slot_add' and self.item_states['slot_add_obtained'] >= 2:
            return True
            
        # 1회성 아이템들
        one_time_items = [
            'speedboots', 'speedgear', 'battery', 'revival',
            'master', 'cooltime', 'chargebag', 'spikeboots',
            'dashgear', 'bulkup', 'sensor', 'gravitybelt', 'dashholder'
        ]
        
        if item_name in one_time_items:
            if self.item_states.get(f'{item_name}_obtained', False):
                return True
                
        # 부활 아이템 특별 처리
        if item_name == 'revival' and self.item_states['revival_used']:
            return True
            
        return False
        
    def _create_item(self, item_type: Dict):
        """아이템 생성"""
        width = self.global_manager.get('WIDTH', 600)
        height = self.global_manager.get('HEIGHT', 750)
        
        item = {
            'x': width // 2,
            'y': height // 2,
            'vel': [random.choice([-4, -3, 3, 4]), random.choice([-4, -3, 3, 4])],
            'type': item_type,
            'timer': item_type['duration'],
            'bounce_count': 0,
            'max_bounces': random.randint(3, 6),
            'angle': 0
        }
        
        self.active_items.append(item)
        
        # 이벤트 발생
        emit_event(EventType.ITEM_SPAWNED, {
            'item': item_type['name'],
            'position': (item['x'], item['y'])
        })
        
    def update(self, dt: float, player_rect: pygame.Rect):
        """아이템 시스템 업데이트
        
        Args:
            dt: 델타 타임
            player_rect: 플레이어 Rect
        """
        # 활성 아이템 업데이트
        self._update_active_items(dt, player_rect)
        
        # 쿨다운 업데이트
        self._update_cooldowns(dt)
        
        # 아이템 효과 업데이트
        self._update_item_effects(dt)
        
    def _update_active_items(self, dt: float, player_rect: pygame.Rect):
        """화면에 떠있는 아이템 업데이트"""
        width = self.global_manager.get('WIDTH', 600)
        height = self.global_manager.get('HEIGHT', 750)
        
        new_items = []
        
        for item in self.active_items:
            # 위치 이동
            item['x'] += item['vel'][0]
            item['y'] += item['vel'][1]
            
            # 회전
            item['angle'] = (item['angle'] + 2) % 360
            
            # 벽 충돌
            if item['x'] <= 0 or item['x'] >= width:
                item['vel'][0] *= -1
                item['bounce_count'] += 1
            if item['y'] <= 0 or item['y'] >= height:
                item['vel'][1] *= -1
                item['bounce_count'] += 1
                
            # 플레이어 충돌
            item_rect = pygame.Rect(item['x'] - 15, item['y'] - 15, 30, 30)
            
            if item_rect.colliderect(player_rect):
                self._collect_item(item)
            elif item['bounce_count'] < item['max_bounces']:
                new_items.append(item)
                
        self.active_items = new_items
        
    def _collect_item(self, item: Dict):
        """아이템 획득 처리"""
        item_name = item['type']['name']
        
        # 패시브/액티브 구분
        passive_items = [
            'speedboots', 'speedgear', 'battery', 'slot_add', 'revival',
            'master', 'cooltime', 'chargebag', 'spikeboots', 'dashgear',
            'sensor', 'bulkup', 'dashholder', 'gravitybelt'
        ]
        
        if item_name in passive_items:
            self._collect_passive_item(item)
        else:
            self._collect_active_item(item)
            
        # 효과음
        sound = self.global_manager.get('SOUND_ITEM_PICKUP')
        if sound:
            sound.play()
            
        # 이벤트 발생
        emit_event(EventType.ITEM_COLLECTED, {
            'item': item_name,
            'position': (item['x'], item['y'])
        })
        
    def _collect_passive_item(self, item: Dict):
        """패시브 아이템 획득"""
        item_name = item['type']['name']
        
        # 상태 업데이트
        if item_name == 'slot_add':
            self.item_states['slot_add_obtained'] += 1
            self.max_item_slots += 1
            items.slot_add_obtained += 1
        else:
            self.item_states[f'{item_name}_obtained'] = True
            setattr(items, f'{item_name}_obtained', True)
            
        # 패시브 아이템 리스트에 추가
        self.passive_items.append({
            'name': item_name,
            'color': item['type']['color'],
            'effect': item_name,
            'icon': item['type'].get('icon')
        })
        
        # 특수 효과 적용
        self._apply_passive_effect(item_name)
        
    def _collect_active_item(self, item: Dict):
        """액티브 아이템 획득"""
        if len(self.active_item_slots) >= self.max_item_slots:
            # 현재 선택된 슬롯 교체
            self.active_item_slots[self.selected_slot_index] = {
                'name': item['type']['name'],
                'color': item['type']['color'],
                'effect': item['type']['name'],
                'icon': item['type'].get('icon'),
                'last_use': 0
            }
        else:
            # 새 슬롯에 추가
            self.active_item_slots.append({
                'name': item['type']['name'],
                'color': item['type']['color'],
                'effect': item['type']['name'],
                'icon': item['type'].get('icon'),
                'last_use': 0
            })
            
    def _apply_passive_effect(self, item_name: str):
        """패시브 아이템 효과 적용"""
        if item_name == 'speedboots':
            # 이동속도 증가
            current_speed = self.global_manager.get('PLAYER_SPEED', 5)
            self.global_manager.set('PLAYER_SPEED', current_speed * 1.3)
            
        elif item_name == 'speedgear':
            # 공 속도 증가
            current_speed = self.global_manager.get('BALL_BASE_SPEED', 9)
            self.global_manager.set('BALL_BASE_SPEED', current_speed * 1.2)
            
        elif item_name == 'battery':
            # 게이지 감소 방지
            self.global_manager.set('gauge_decay_disabled', True)
            
        elif item_name == 'bulkup':
            # 패들 크기 증가
            current_width = self.global_manager.get('PADDLE_WIDTH', 100)
            self.global_manager.set('PADDLE_WIDTH', current_width * 1.3)
            
        elif item_name == 'sensor':
            # 예측선 표시
            self.global_manager.set('show_prediction', True)
            
        elif item_name == 'gravitybelt':
            # 중력 감소
            self.global_manager.set('gravity_reduced', True)
            
        elif item_name == 'dashholder':
            # 대시 저장
            self.global_manager.set('dash_storage_enabled', True)
            
    def use_active_item(self, slot_index: int = None) -> bool:
        """액티브 아이템 사용
        
        Args:
            slot_index: 사용할 슬롯 인덱스 (None이면 현재 선택된 슬롯)
            
        Returns:
            사용 성공 여부
        """
        if slot_index is None:
            slot_index = self.selected_slot_index
            
        if slot_index >= len(self.active_item_slots):
            return False
            
        item = self.active_item_slots[slot_index]
        
        # 쿨다운 체크
        now = pygame.time.get_ticks()
        if now - item.get('last_use', 0) < self.default_cooldown:
            return False
            
        # 아이템 효과 발동
        self._activate_item_effect(item['name'])
        
        # 쿨다운 설정
        item['last_use'] = now
        
        # 효과음
        sound = self.global_manager.get('SOUND_ACTIVE_ITEM')
        if sound:
            sound.play()
            
        return True
        
    def _activate_item_effect(self, item_name: str):
        """아이템 효과 발동"""
        # 스킬 매니저를 통해 효과 발동
        from game_logic.skill_manager import get_skill_manager
        skill_manager = get_skill_manager()
        skill_manager.activate_skill(item_name)
        
    def _update_cooldowns(self, dt: float):
        """쿨다운 업데이트"""
        for item_name in list(self.item_cooldowns.keys()):
            self.item_cooldowns[item_name] -= dt * 1000  # ms 단위
            if self.item_cooldowns[item_name] <= 0:
                del self.item_cooldowns[item_name]
                
    def _update_item_effects(self, dt: float):
        """아이템 효과 업데이트"""
        # 일부 아이템의 지속 효과 처리
        pass
        
    def select_slot(self, index: int):
        """아이템 슬롯 선택
        
        Args:
            index: 슬롯 인덱스
        """
        if 0 <= index < len(self.active_item_slots):
            self.selected_slot_index = index
            
    def get_active_slots(self) -> List[Dict]:
        """액티브 아이템 슬롯 반환"""
        return self.active_item_slots
        
    def get_passive_items(self) -> List[Dict]:
        """패시브 아이템 목록 반환"""
        return self.passive_items
        
    def reset(self):
        """아이템 시스템 리셋"""
        self.active_items.clear()
        self.passive_items.clear()
        self.active_item_slots.clear()
        self.selected_slot_index = 0
        self.max_item_slots = 3
        
        # 상태 초기화
        for key in self.item_states:
            if key.endswith('_obtained'):
                self.item_states[key] = False if 'obtained' in key else 0
                
        # items.py 상태도 초기화
        items.reset_items()


# 싱글톤 인스턴스
_item_manager = None

def get_item_manager() -> ItemManager:
    """아이템 매니저 싱글톤 반환"""
    global _item_manager
    if _item_manager is None:
        _item_manager = ItemManager()
    return _item_manager