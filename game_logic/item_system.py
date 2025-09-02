"""
ItemSystem - 아이템 시스템 관리
아이템 효과, 획득, 적용 관리
"""

from typing import Dict, Any, List, Optional
from core.game_state import GameState
from core.events import EventType, emit_event


class ItemSystem:
    """아이템 시스템 관리자"""
    
    def __init__(self):
        self.game_state = GameState.get_instance()
        
        # 아이템 정의
        self.item_definitions = {
            'speedboots': {
                'name': '스피드부츠',
                'description': '이동속도 15% 증가',
                'type': 'passive',
                'effect': {'speed_multiplier': 1.15},
                'permanent': True
            },
            'speedgear': {
                'name': '스피드기어',
                'description': '방향 전환 속도 150% 증가',
                'type': 'passive',
                'effect': {'turn_speed_multiplier': 2.5},
                'permanent': True
            },
            'battery': {
                'name': '배터리',
                'description': '스테이지 전환 시 게이지 유지',
                'type': 'passive',
                'effect': {'keep_gauge': True},
                'permanent': True
            },
            'revival': {
                'name': '부활',
                'description': '패배 시 한 번 부활',
                'type': 'consumable',
                'effect': {'extra_life': 1},
                'permanent': True
            },
            'master': {
                'name': '장인의 망치',
                'description': '벽돌 길이 30% 증가, 쿨타임 10% 감소',
                'type': 'passive',
                'effect': {
                    'wall_length_multiplier': 1.3,
                    'cooldown_reduction': 0.1
                },
                'permanent': True
            },
            'cooltime': {
                'name': '쿨링볼',
                'description': '아이템 쿨타임 30% 감소',
                'type': 'passive',
                'effect': {'item_cooldown_reduction': 0.3},
                'permanent': True
            },
            'chargebag': {
                'name': '충전가방',
                'description': '벽 충돌 시 게이지 20% 충전',
                'type': 'passive',
                'effect': {'wall_charge_percent': 0.2},
                'permanent': True
            },
            'spikeboots': {
                'name': '스파이크부츠',
                'description': '대시 후 제어불능 15% 감소, 쿨타임 20% 감소',
                'type': 'passive',
                'effect': {
                    'dash_stun_reduction': 0.15,
                    'dash_cooldown_reduction': 0.2
                },
                'permanent': True
            },
            'dashgear': {
                'name': '대시기어',
                'description': '대시 거리 10% 증가, 게이지 소모 20% 감소',
                'type': 'passive',
                'effect': {
                    'dash_distance_multiplier': 1.1,
                    'dash_cost_reduction': 0.2
                },
                'permanent': True
            },
            'bulkup': {
                'name': '벌크업',
                'description': '패들 크기 10% 증가',
                'type': 'passive',
                'effect': {'paddle_size_multiplier': 1.1},
                'permanent': True
            },
            'dashholder': {
                'name': '대시홀더',
                'description': '대시 최대 횟수 +1',
                'type': 'passive',
                'effect': {'dash_charges_bonus': 1},
                'permanent': True
            },
            'gravitybelt': {
                'name': '무중력벨트',
                'description': '중력 효과 감소',
                'type': 'passive',
                'effect': {'gravity_reduction': 0.5},
                'permanent': True
            },
            'sensor': {
                'name': '위험감지센서',
                'description': '위험 상황 경고',
                'type': 'passive',
                'effect': {'danger_detection': True},
                'permanent': True
            }
        }
        
    def collect_item(self, item_name: str) -> bool:
        """아이템 획득
        
        Args:
            item_name: 아이템 이름
            
        Returns:
            획득 성공 여부
        """
        if item_name not in self.item_definitions:
            return False
            
        # 이미 획득한 아이템인지 확인
        if self.is_item_obtained(item_name):
            return False
            
        # GameState에 아이템 획득 표시
        self.set_item_obtained(item_name, True)
        
        # 아이템 효과 적용
        self.apply_item_effect(item_name)
        
        # 이벤트 발생
        emit_event(EventType.ITEM_COLLECTED, {
            'item_name': item_name,
            'item_type': self.item_definitions[item_name]['type'],
            'permanent': self.item_definitions[item_name]['permanent']
        })
        
        return True
        
    def is_item_obtained(self, item_name: str) -> bool:
        """아이템 획득 여부 확인
        
        Args:
            item_name: 아이템 이름
            
        Returns:
            획득 여부
        """
        # GameState의 아이템 상태 확인
        if item_name == 'speedboots':
            return self.game_state.speedboots_obtained
        elif item_name == 'speedgear':
            return self.game_state.speedgear_obtained
        elif item_name == 'battery':
            return self.game_state.battery_obtained
        elif item_name == 'revival':
            return self.game_state.revival_obtained
        elif item_name == 'master':
            return self.game_state.master_obtained
        elif item_name == 'cooltime':
            return self.game_state.cooltime_obtained
        elif item_name == 'chargebag':
            return self.game_state.chargebag_obtained
        elif item_name == 'spikeboots':
            return self.game_state.spikeboots_obtained
        elif item_name == 'dashgear':
            return self.game_state.dashgear_obtained
        elif item_name == 'bulkup':
            return self.game_state.bulkup_obtained
        elif item_name == 'dashholder':
            return self.game_state.dashholder_obtained
        elif item_name == 'gravitybelt':
            return self.game_state.gravitybelt_obtained
        elif item_name == 'sensor':
            return self.game_state.danger_sensor_obtained
        return False
        
    def set_item_obtained(self, item_name: str, obtained: bool):
        """아이템 획득 상태 설정
        
        Args:
            item_name: 아이템 이름
            obtained: 획득 여부
        """
        if item_name == 'speedboots':
            self.game_state.speedboots_obtained = obtained
        elif item_name == 'speedgear':
            self.game_state.speedgear_obtained = obtained
        elif item_name == 'battery':
            self.game_state.battery_obtained = obtained
        elif item_name == 'revival':
            self.game_state.revival_obtained = obtained
        elif item_name == 'master':
            self.game_state.master_obtained = obtained
        elif item_name == 'cooltime':
            self.game_state.cooltime_obtained = obtained
        elif item_name == 'chargebag':
            self.game_state.chargebag_obtained = obtained
        elif item_name == 'spikeboots':
            self.game_state.spikeboots_obtained = obtained
        elif item_name == 'dashgear':
            self.game_state.dashgear_obtained = obtained
        elif item_name == 'bulkup':
            self.game_state.bulkup_obtained = obtained
        elif item_name == 'dashholder':
            self.game_state.dashholder_obtained = obtained
        elif item_name == 'gravitybelt':
            self.game_state.gravitybelt_obtained = obtained
        elif item_name == 'sensor':
            self.game_state.danger_sensor_obtained = obtained
            self.game_state.sensor_obtained = obtained  # 호환성
            
    def apply_item_effect(self, item_name: str):
        """아이템 효과 적용
        
        Args:
            item_name: 아이템 이름
        """
        if item_name not in self.item_definitions:
            return
            
        item = self.item_definitions[item_name]
        effect = item['effect']
        
        # 효과별 처리
        if 'speed_multiplier' in effect:
            # 플레이어 속도 증가 (실제 게임에서 적용)
            pass
            
        if 'paddle_size_multiplier' in effect:
            # 패들 크기 증가 (실제 게임에서 적용)
            pass
            
        if 'dash_charges_bonus' in effect:
            # 대시 최대 횟수 증가
            if hasattr(self.game_state, 'dash_max'):
                self.game_state.dash_max += effect['dash_charges_bonus']
                
        # 이벤트 발생
        emit_event(EventType.ITEM_ACTIVATED, {
            'item_name': item_name,
            'effect': effect
        })
        
    def get_active_effects(self) -> Dict[str, Any]:
        """현재 활성화된 모든 아이템 효과 반환
        
        Returns:
            활성 효과 딕셔너리
        """
        active_effects = {}
        
        for item_name, item_data in self.item_definitions.items():
            if self.is_item_obtained(item_name):
                effect = item_data['effect']
                active_effects.update(effect)
                
        return active_effects
        
    def calculate_modified_value(self, base_value: float, effect_type: str) -> float:
        """아이템 효과가 적용된 값 계산
        
        Args:
            base_value: 기본값
            effect_type: 효과 타입
            
        Returns:
            수정된 값
        """
        active_effects = self.get_active_effects()
        
        # 곱셈 효과
        if f'{effect_type}_multiplier' in active_effects:
            base_value *= active_effects[f'{effect_type}_multiplier']
            
        # 감소 효과
        if f'{effect_type}_reduction' in active_effects:
            base_value *= (1 - active_effects[f'{effect_type}_reduction'])
            
        # 보너스 효과
        if f'{effect_type}_bonus' in active_effects:
            base_value += active_effects[f'{effect_type}_bonus']
            
        return base_value
        
    def handle_revival(self) -> bool:
        """부활 처리
        
        Returns:
            부활 성공 여부
        """
        if self.game_state.revival_obtained and not self.game_state.revival_used:
            self.game_state.revival_used = True
            
            # 이벤트 발생
            emit_event(EventType.ITEM_ACTIVATED, {
                'item_name': 'revival',
                'effect': 'extra_life'
            })
            
            return True
        return False
        
    def get_item_info(self, item_name: str) -> Optional[Dict[str, Any]]:
        """아이템 정보 반환
        
        Args:
            item_name: 아이템 이름
            
        Returns:
            아이템 정보 딕셔너리
        """
        if item_name in self.item_definitions:
            info = self.item_definitions[item_name].copy()
            info['obtained'] = self.is_item_obtained(item_name)
            return info
        return None
        
    def get_all_obtained_items(self) -> List[str]:
        """획득한 모든 아이템 목록 반환
        
        Returns:
            획득한 아이템 이름 리스트
        """
        obtained_items = []
        for item_name in self.item_definitions.keys():
            if self.is_item_obtained(item_name):
                obtained_items.append(item_name)
        return obtained_items