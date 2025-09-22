"""
Academy Mode - 아카데미 모드
스킬 트리, 훈련, 업그레이드 시스템
"""

import pygame
import json
import os
from typing import Dict, List, Optional, Any
from core.global_manager import GlobalManager
from core.events import EventType, emit_event


class SkillTree:
    """스킬 트리 시스템"""
    
    def __init__(self, tree_data: Dict):
        self.name = tree_data['name']
        self.color = tree_data['color']
        self.skills = tree_data['skills']
        self.skill_levels = {}  # 스킬 ID -> 현재 레벨
        self.total_tp_spent = 0  # 총 사용한 TP
        
        # 모든 스킬 초기화
        for skill in self.skills:
            self.skill_levels[skill['id']] = 0
            
    def can_upgrade(self, skill_id: str, available_tp: int) -> bool:
        """스킬 업그레이드 가능 여부 확인
        
        Args:
            skill_id: 스킬 ID
            available_tp: 사용 가능한 TP
            
        Returns:
            업그레이드 가능 여부
        """
        skill = self.get_skill(skill_id)
        if not skill:
            return False
            
        current_level = self.skill_levels[skill_id]
        
        # 최대 레벨 체크
        if current_level >= skill['max_level']:
            return False
            
        # TP 체크
        if available_tp < skill['cost']:
            return False
            
        # 선행 조건 체크
        if skill.get('requires'):
            required_skill = skill['requires']
            if self.skill_levels.get(required_skill, 0) == 0:
                return False
                
        # OR 조건 체크 (여러 스킬 중 하나)
        if skill.get('requires_or'):
            has_any = False
            for req in skill['requires_or']:
                if self.skill_levels.get(req, 0) > 0:
                    has_any = True
                    break
            if not has_any:
                return False
                
        # 누적 TP 요구사항 체크
        if skill.get('total_tp_required'):
            if self.total_tp_spent < skill['total_tp_required']:
                return False
                
        return True
        
    def upgrade_skill(self, skill_id: str, tp_cost: int) -> bool:
        """스킬 업그레이드
        
        Args:
            skill_id: 스킬 ID
            tp_cost: 소모할 TP
            
        Returns:
            업그레이드 성공 여부
        """
        if skill_id not in self.skill_levels:
            return False
            
        skill = self.get_skill(skill_id)
        if not skill:
            return False
            
        self.skill_levels[skill_id] += 1
        self.total_tp_spent += tp_cost
        
        return True
        
    def get_skill(self, skill_id: str) -> Optional[Dict]:
        """스킬 정보 가져오기"""
        for skill in self.skills:
            if skill['id'] == skill_id:
                return skill
        return None
        
    def get_skill_level(self, skill_id: str) -> int:
        """스킬 레벨 가져오기"""
        return self.skill_levels.get(skill_id, 0)
        
    def get_skill_effects(self) -> Dict[str, float]:
        """활성화된 스킬 효과 계산"""
        effects = {}
        
        for skill_id, level in self.skill_levels.items():
            if level == 0:
                continue
                
            skill = self.get_skill(skill_id)
            if not skill:
                continue
                
            # 스킬별 효과 계산
            if skill_id == 'dash_lightweight':
                effects['dash_cooldown_reduction'] = level * 0.05
            elif skill_id == 'dash_module_control':
                effects['control_loss_reduction'] = level * 0.05
            elif skill_id == 'dash_jump':
                effects['dash_distance_increase'] = level * 0.03
            elif skill_id == 'dash_battery_pack':
                effects['gauge_consumption_reduction'] = level * 0.05
            elif skill_id == 'dash_acceleration':
                effects['ball_speed_boost'] = level * 0.10
            elif skill_id == 'dash_amplification':
                effects['extra_dash_tokens'] = level
            elif skill_id == 'dash_spirit':
                effects['dash_spirit_chance'] = 0.35 if level == 1 else 0.50
                
        return effects


class AcademyMode:
    """아카데미 모드 관리"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        
        # 스킬 트리 데이터
        self.skill_tree_data = self._load_skill_trees()
        self.skill_trees = {}
        
        # 플레이어 데이터
        self.player_data = {
            'tp': 0,  # 테크 포인트
            'medals': 0,  # 메달
            'level': 1,
            'exp': 0,
            'exp_to_next': 100,
            'unlocked_skills': [],
            'completed_challenges': []
        }
        
        # 세이브 파일
        self.save_file = 'academy_save.json'
        
        # 초기화
        self._init_skill_trees()
        self.load_progress()
        
    def _load_skill_trees(self) -> Dict:
        """스킬 트리 데이터 로드"""
        return {
            "dash": {
                "name": "대쉬 스킬",
                "color": (100, 150, 255),
                "skills": [
                    {
                        "id": "dash_lightweight",
                        "name": "경량화",
                        "description": "대쉬토큰 충전시간 5% 감소",
                        "max_level": 5,
                        "cost": 1,
                        "icon_color": (100, 150, 255),
                        "requires": None,
                        "row": 0,
                        "col": 0
                    },
                    {
                        "id": "dash_module_control",
                        "name": "모듈제어",
                        "description": "통제불능시간 5% 감소",
                        "max_level": 5,
                        "cost": 1,
                        "icon_color": (100, 150, 255),
                        "requires": None,
                        "row": 0,
                        "col": 1
                    },
                    {
                        "id": "dash_jump",
                        "name": "도약",
                        "description": "대쉬 거리 3% 증가",
                        "max_level": 5,
                        "cost": 1,
                        "icon_color": (150, 200, 255),
                        "requires": "dash_lightweight",
                        "total_tp_required": 3,
                        "row": 1,
                        "col": 0
                    },
                    {
                        "id": "dash_battery_pack",
                        "name": "배터리팩",
                        "description": "게이지 소모량 5% 감소",
                        "max_level": 5,
                        "cost": 1,
                        "icon_color": (150, 200, 255),
                        "requires": "dash_module_control",
                        "total_tp_required": 3,
                        "row": 1,
                        "col": 1
                    },
                    {
                        "id": "dash_acceleration",
                        "name": "가속화",
                        "description": "대쉬 사용시 공 속도 10% 증가",
                        "max_level": 5,
                        "cost": 1,
                        "icon_color": (200, 220, 255),
                        "requires_or": ["dash_battery_pack", "dash_jump"],
                        "total_tp_required": 6,
                        "row": 2,
                        "col": 0
                    },
                    {
                        "id": "dash_amplification",
                        "name": "증폭",
                        "description": "대쉬토큰 1개 증가",
                        "max_level": 2,
                        "cost": 2,
                        "icon_color": (200, 220, 255),
                        "requires": "dash_battery_pack",
                        "total_tp_required": 6,
                        "row": 2,
                        "col": 1
                    },
                    {
                        "id": "dash_spirit",
                        "name": "대쉬 스피릿",
                        "description": "대쉬 시전시 35% 확률로 하늘색 레이저 잔상 생성",
                        "max_level": 2,
                        "cost": 3,
                        "icon_color": (255, 200, 100),
                        "requires": "dash_acceleration",
                        "total_tp_required": 9,
                        "row": 3,
                        "col": 0
                    }
                ]
            },
            "item": {
                "name": "아이템 스킬",
                "color": (255, 150, 100),
                "skills": [
                    {
                        "id": "item_spawn",
                        "name": "아이템 스폰 확률",
                        "description": "아이템 스폰 확률 10% 증가",
                        "max_level": 5,
                        "cost": 1,
                        "icon_color": (255, 150, 100),
                        "requires": None,
                        "row": 0,
                        "col": 0
                    },
                    {
                        "id": "item_cooldown",
                        "name": "아이템 쿨타임 감소",
                        "description": "엑티브 아이템 쿨타임 0.6초 감소",
                        "max_level": 5,
                        "cost": 1,
                        "icon_color": (255, 150, 100),
                        "requires": "item_spawn",
                        "row": 1,
                        "col": 0
                    },
                    {
                        "id": "item_slot",
                        "name": "아이템 슬롯 증가",
                        "description": "엑티브 아이템 슬롯 1칸 증가",
                        "max_level": 2,
                        "cost": 2,
                        "icon_color": (255, 150, 100),
                        "requires": "item_cooldown",
                        "row": 2,
                        "col": 0
                    },
                    {
                        "id": "item_pachinko",
                        "name": "빠칭코 보너스",
                        "description": "스테이지 클리어 시 5% 확률로 빠칭코 2회",
                        "max_level": 2,
                        "cost": 2,
                        "icon_color": (255, 150, 100),
                        "requires": "item_slot",
                        "row": 3,
                        "col": 0
                    },
                    {
                        "id": "item_legendary",
                        "name": "전설 아이템 해금",
                        "description": "전설 아이템 드랍 활성화",
                        "max_level": 1,
                        "cost": 3,
                        "icon_color": (255, 200, 100),
                        "requires": "item_pachinko",
                        "row": 4,
                        "col": 0
                    }
                ]
            },
            "special": {
                "name": "필살기 스킬",
                "color": (255, 100, 255),
                "skills": [
                    {
                        "id": "special_charge",
                        "name": "충전 속도",
                        "description": "필살기 충전 속도 10% 증가",
                        "max_level": 5,
                        "cost": 1,
                        "icon_color": (255, 100, 255),
                        "requires": None,
                        "row": 0,
                        "col": 0
                    },
                    {
                        "id": "special_duration",
                        "name": "지속 시간",
                        "description": "필살기 지속시간 0.5초 증가",
                        "max_level": 3,
                        "cost": 2,
                        "icon_color": (255, 100, 255),
                        "requires": "special_charge",
                        "row": 1,
                        "col": 0
                    },
                    {
                        "id": "special_power",
                        "name": "강화",
                        "description": "필살기 효과 20% 증가",
                        "max_level": 3,
                        "cost": 2,
                        "icon_color": (255, 200, 100),
                        "requires": "special_duration",
                        "row": 2,
                        "col": 0
                    }
                ]
            }
        }
        
    def _init_skill_trees(self):
        """스킬 트리 초기화"""
        for tree_id, tree_data in self.skill_tree_data.items():
            self.skill_trees[tree_id] = SkillTree(tree_data)
            
    def load_progress(self) -> bool:
        """진행 상황 로드
        
        Returns:
            로드 성공 여부
        """
        if not os.path.exists(self.save_file):
            return False
            
        try:
            with open(self.save_file, 'r') as f:
                save_data = json.load(f)
                
            # 플레이어 데이터 로드
            self.player_data.update(save_data.get('player_data', {}))
            
            # 스킬 트리 상태 로드
            skill_tree_states = save_data.get('skill_trees', {})
            for tree_id, tree_state in skill_tree_states.items():
                if tree_id in self.skill_trees:
                    self.skill_trees[tree_id].skill_levels = tree_state.get('skill_levels', {})
                    self.skill_trees[tree_id].total_tp_spent = tree_state.get('total_tp_spent', 0)
                    
            return True
            
        except Exception as e:
            print(f"Failed to load academy save: {e}")
            return False
            
    def save_progress(self) -> bool:
        """진행 상황 저장
        
        Returns:
            저장 성공 여부
        """
        try:
            save_data = {
                'player_data': self.player_data,
                'skill_trees': {}
            }
            
            # 스킬 트리 상태 저장
            for tree_id, tree in self.skill_trees.items():
                save_data['skill_trees'][tree_id] = {
                    'skill_levels': tree.skill_levels,
                    'total_tp_spent': tree.total_tp_spent
                }
                
            with open(self.save_file, 'w') as f:
                json.dump(save_data, f, indent=2)
                
            return True
            
        except Exception as e:
            print(f"Failed to save academy progress: {e}")
            return False
            
    def add_tp(self, amount: int):
        """테크 포인트 추가
        
        Args:
            amount: 추가할 TP
        """
        self.player_data['tp'] += amount
        emit_event(EventType.MEDAL_EARNED, {
            'type': 'tp',
            'amount': amount,
            'total': self.player_data['tp']
        })
        
    def spend_tp(self, amount: int) -> bool:
        """테크 포인트 소비
        
        Args:
            amount: 소비할 TP
            
        Returns:
            소비 성공 여부
        """
        if self.player_data['tp'] >= amount:
            self.player_data['tp'] -= amount
            return True
        return False
        
    def upgrade_skill(self, tree_id: str, skill_id: str) -> bool:
        """스킬 업그레이드
        
        Args:
            tree_id: 스킬 트리 ID
            skill_id: 스킬 ID
            
        Returns:
            업그레이드 성공 여부
        """
        if tree_id not in self.skill_trees:
            return False
            
        tree = self.skill_trees[tree_id]
        
        # 업그레이드 가능 체크
        if not tree.can_upgrade(skill_id, self.player_data['tp']):
            return False
            
        skill = tree.get_skill(skill_id)
        if not skill:
            return False
            
        # TP 소비
        if not self.spend_tp(skill['cost']):
            return False
            
        # 스킬 업그레이드
        if tree.upgrade_skill(skill_id, skill['cost']):
            # 저장
            self.save_progress()
            
            # 이벤트 발생
            emit_event(EventType.SKILL_ACTIVATED, {
                'tree': tree_id,
                'skill': skill_id,
                'level': tree.get_skill_level(skill_id)
            })
            
            return True
            
        return False
        
    def get_all_skill_effects(self) -> Dict[str, float]:
        """모든 활성 스킬 효과 합산"""
        all_effects = {}
        
        for tree in self.skill_trees.values():
            effects = tree.get_skill_effects()
            for key, value in effects.items():
                if key in all_effects:
                    all_effects[key] += value
                else:
                    all_effects[key] = value
                    
        return all_effects
        
    def add_exp(self, amount: int):
        """경험치 추가
        
        Args:
            amount: 추가할 경험치
        """
        self.player_data['exp'] += amount
        
        # 레벨업 체크
        while self.player_data['exp'] >= self.player_data['exp_to_next']:
            self.player_data['exp'] -= self.player_data['exp_to_next']
            self.player_data['level'] += 1
            self.player_data['exp_to_next'] = int(self.player_data['exp_to_next'] * 1.2)
            
            # 레벨업 보상
            self.add_tp(1)
            
            # 이벤트 발생
            emit_event(EventType.PLAYER_SCORE, {
                'type': 'levelup',
                'level': self.player_data['level']
            })
            
    def convert_medals_to_tp(self, medals: int) -> int:
        """메달을 TP로 변환
        
        Args:
            medals: 변환할 메달 수
            
        Returns:
            획득한 TP
        """
        # 100 메달 = 1 TP
        tp_gained = medals // 100
        if tp_gained > 0:
            self.add_tp(tp_gained)
            self.player_data['medals'] -= tp_gained * 100
            self.save_progress()
            
        return tp_gained
        
    def get_stats(self) -> Dict:
        """아카데미 통계 반환"""
        return {
            'level': self.player_data['level'],
            'exp': self.player_data['exp'],
            'exp_to_next': self.player_data['exp_to_next'],
            'tp': self.player_data['tp'],
            'medals': self.player_data['medals'],
            'total_skills': sum(
                sum(tree.skill_levels.values()) 
                for tree in self.skill_trees.values()
            )
        }

    def get_tree_total_tp(self, tree_id: str) -> int:
        """특정 스킬 탭에 투자된 누적 TP 반환"""
        tree = self.skill_trees.get(tree_id)
        if not tree:
            return 0
        return tree.total_tp_spent


# 싱글톤 인스턴스
_academy_mode = None

def get_academy_mode() -> AcademyMode:
    """아카데미 모드 싱글톤 반환"""
    global _academy_mode
    if _academy_mode is None:
        _academy_mode = AcademyMode()
    return _academy_mode
