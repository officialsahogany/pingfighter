"""
SkillSystem - 스킬 시스템 관리
플레이어와 보스의 특수 스킬 관리
"""

from typing import Dict, Any, Optional, Callable
from core.game_state import GameState
from core.events import EventType, emit_event


class SkillSystem:
    """스킬 시스템 관리자"""
    
    def __init__(self):
        self.game_state = GameState.get_instance()
        self.active_skills = {}  # 현재 활성화된 스킬들
        self.skill_cooldowns = {}  # 스킬 쿨다운
        
        # 스킬 정의
        self.skills = {
            'power_shot': {
                'name': '파워샷',
                'gauge_cost': 100,
                'duration': 180,  # 3초
                'cooldown': 300,  # 5초
                'type': 'active'
            },
            'drive': {
                'name': '드라이브',
                'gauge_cost': 80,
                'duration': 120,
                'cooldown': 240,
                'type': 'active'
            },
            'ghost_shot': {
                'name': '고스트샷',
                'gauge_cost': 150,
                'duration': 300,
                'cooldown': 600,
                'type': 'active'
            },
            'wall_builder': {
                'name': '벽돌 생성',
                'gauge_cost': 50,
                'duration': 0,  # 즉시 발동
                'cooldown': 180,
                'type': 'instant'
            },
            'balloon_shield': {
                'name': '풍선 방어',
                'gauge_cost': 60,
                'duration': 120,
                'cooldown': 300,
                'type': 'instant'
            },
            'speed_boost': {
                'name': '스피드 부스트',
                'gauge_cost': 30,
                'duration': 180,
                'cooldown': 120,
                'type': 'buff'
            }
        }
        
    def can_use_skill(self, skill_name: str) -> bool:
        """스킬 사용 가능 여부 확인
        
        Args:
            skill_name: 스킬 이름
            
        Returns:
            사용 가능 여부
        """
        if skill_name not in self.skills:
            return False
            
        skill = self.skills[skill_name]
        
        # 게이지 확인
        if self.game_state.special_gauge < skill['gauge_cost']:
            return False
            
        # 쿨다운 확인
        if skill_name in self.skill_cooldowns and self.skill_cooldowns[skill_name] > 0:
            return False
            
        # 이미 활성화된 스킬인지 확인
        if skill_name in self.active_skills:
            return False
            
        return True
        
    def activate_skill(self, skill_name: str) -> bool:
        """스킬 활성화
        
        Args:
            skill_name: 스킬 이름
            
        Returns:
            활성화 성공 여부
        """
        if not self.can_use_skill(skill_name):
            return False
            
        skill = self.skills[skill_name]
        
        # 게이지 소모
        self.game_state.special_gauge -= skill['gauge_cost']
        
        # 스킬 활성화
        if skill['type'] != 'instant':
            self.active_skills[skill_name] = {
                'duration': skill['duration'],
                'start_time': 0  # 실제 게임에서는 pygame.time.get_ticks() 사용
            }
            
        # 쿨다운 설정
        self.skill_cooldowns[skill_name] = skill['cooldown']
        
        # 이벤트 발생
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'skill_name': skill_name,
            'skill_type': skill['type'],
            'duration': skill['duration']
        })
        
        # GameState 업데이트
        if skill_name in ['power_shot', 'drive', 'ghost_shot']:
            self.game_state.special_active = True
            self.game_state.special_duration = skill['duration']
            
        return True
        
    def deactivate_skill(self, skill_name: str):
        """스킬 비활성화
        
        Args:
            skill_name: 스킬 이름
        """
        if skill_name in self.active_skills:
            del self.active_skills[skill_name]
            
            # 이벤트 발생
            emit_event(EventType.SPECIAL_ENDED, {
                'skill_name': skill_name
            })
            
            # GameState 업데이트
            if skill_name in ['power_shot', 'drive', 'ghost_shot']:
                self.game_state.special_active = False
                self.game_state.special_duration = 0
                
    def update(self, dt: int = 1):
        """스킬 시스템 업데이트 (매 프레임 호출)
        
        Args:
            dt: 델타 타임 (프레임)
        """
        # 활성 스킬 지속시간 업데이트
        skills_to_deactivate = []
        for skill_name, skill_data in self.active_skills.items():
            skill_data['duration'] -= dt
            if skill_data['duration'] <= 0:
                skills_to_deactivate.append(skill_name)
                
        # 종료된 스킬 비활성화
        for skill_name in skills_to_deactivate:
            self.deactivate_skill(skill_name)
            
        # 쿨다운 업데이트
        for skill_name in list(self.skill_cooldowns.keys()):
            self.skill_cooldowns[skill_name] -= dt
            if self.skill_cooldowns[skill_name] <= 0:
                del self.skill_cooldowns[skill_name]
                
    def charge_gauge(self, amount: int):
        """게이지 충전
        
        Args:
            amount: 충전량
        """
        max_gauge = self.get_max_gauge()
        self.game_state.special_gauge = min(max_gauge, self.game_state.special_gauge + amount)
        
        # 게이지가 가득 찼는지 확인
        if self.game_state.special_gauge >= max_gauge and not self.game_state.special_ready:
            self.game_state.special_ready = True
            emit_event(EventType.SPECIAL_CHARGED, {
                'gauge': self.game_state.special_gauge,
                'max_gauge': max_gauge
            })
            
    def get_max_gauge(self) -> int:
        """최대 게이지량 반환
        
        Returns:
            최대 게이지량
        """
        base_max = 500
        
        # 아이템 보너스
        if self.game_state.master_obtained:
            base_max += 100
            
        return base_max
        
    def get_skill_info(self, skill_name: str) -> Optional[Dict[str, Any]]:
        """스킬 정보 반환
        
        Args:
            skill_name: 스킬 이름
            
        Returns:
            스킬 정보 딕셔너리
        """
        if skill_name in self.skills:
            info = self.skills[skill_name].copy()
            info['can_use'] = self.can_use_skill(skill_name)
            info['cooldown_remaining'] = self.skill_cooldowns.get(skill_name, 0)
            info['is_active'] = skill_name in self.active_skills
            return info
        return None
        
    def apply_skill_effect(self, skill_name: str, target: Dict[str, Any]) -> Dict[str, Any]:
        """스킬 효과 적용
        
        Args:
            skill_name: 스킬 이름
            target: 효과를 적용할 대상 (공, 패들 등)
            
        Returns:
            효과가 적용된 대상
        """
        if skill_name == 'power_shot':
            # 파워샷: 공 속도 2배
            if 'ball_speed' in target:
                target['ball_speed'] *= 2
                target['power_shot_active'] = True
                
        elif skill_name == 'drive':
            # 드라이브: 스핀 효과
            if 'ball_spin' in target:
                target['ball_spin'] = 1.0  # 최대 스핀
                target['drive_active'] = True
                
        elif skill_name == 'ghost_shot':
            # 고스트샷: 관통 효과
            target['ghost_mode'] = True
            target['penetration'] = True
            
        elif skill_name == 'speed_boost':
            # 스피드 부스트: 패들 속도 증가
            if 'paddle_speed' in target:
                target['paddle_speed'] *= 1.5
                
        return target