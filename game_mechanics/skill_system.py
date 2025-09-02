# -*- coding: utf-8 -*-
"""
⚔️ Skill System
스킬 시스템 - 플레이어와 보스의 특수 능력
"""

import pygame
import math
import random
from typing import Dict, List, Optional, Any, Callable
from enum import Enum
from dataclasses import dataclass, field


class SkillType(Enum):
    """스킬 타입"""
    ACTIVE = "active"       # 액티브 스킬 (수동 발동)
    PASSIVE = "passive"     # 패시브 스킬 (자동 효과)
    ULTIMATE = "ultimate"   # 궁극 스킬
    COUNTER = "counter"     # 카운터 스킬


class SkillTarget(Enum):
    """스킬 대상"""
    SELF = "self"           # 자신
    ENEMY = "enemy"         # 적
    BALL = "ball"          # 공
    AREA = "area"          # 범위


@dataclass
class SkillCooldown:
    """스킬 쿨다운 관리"""
    base_cooldown: float
    current_cooldown: float = 0
    reduction_rate: float = 0  # 쿨다운 감소율
    
    def update(self, dt: float):
        """쿨다운 업데이트"""
        if self.current_cooldown > 0:
            self.current_cooldown = max(0, self.current_cooldown - dt)
    
    def is_ready(self) -> bool:
        """스킬 사용 가능 여부"""
        return self.current_cooldown <= 0
    
    def use(self):
        """스킬 사용 (쿨다운 시작)"""
        actual_cooldown = self.base_cooldown * (1 - self.reduction_rate)
        self.current_cooldown = actual_cooldown
    
    def get_progress(self) -> float:
        """쿨다운 진행률 (0~1)"""
        if self.base_cooldown <= 0:
            return 1.0
        return 1.0 - (self.current_cooldown / self.base_cooldown)


@dataclass
class Skill:
    """스킬 클래스"""
    id: str
    name: str
    korean_name: str
    type: SkillType
    target: SkillTarget
    icon: Optional[pygame.Surface] = None
    
    # 스킬 파라미터
    damage: float = 0
    duration: float = 0
    range: float = 0
    cost: float = 0  # 마나/에너지 코스트
    
    # 쿨다운
    cooldown: Optional[SkillCooldown] = None
    
    # 레벨 시스템
    level: int = 0
    max_level: int = 5
    level_bonuses: Dict[str, float] = field(default_factory=dict)
    
    # 설명
    description: str = ""
    korean_description: str = ""
    
    # 실행 함수
    execute_func: Optional[Callable] = None
    
    # 시각 효과
    effect_color: tuple = (255, 255, 255)
    effect_particles: bool = False
    
    def __post_init__(self):
        """초기화 후 처리"""
        if self.cooldown is None and self.type == SkillType.ACTIVE:
            self.cooldown = SkillCooldown(base_cooldown=5.0)
    
    def can_use(self, user: Any) -> bool:
        """스킬 사용 가능 여부 확인"""
        if self.type == SkillType.PASSIVE:
            return False  # 패시브는 수동 사용 불가
        
        if self.cooldown and not self.cooldown.is_ready():
            return False
        
        # 코스트 체크
        if hasattr(user, 'energy') and self.cost > 0:
            if user.energy < self.cost:
                return False
        
        return True
    
    def use(self, user: Any, target: Any = None, **kwargs):
        """스킬 사용"""
        if not self.can_use(user):
            return False
        
        # 코스트 소모
        if hasattr(user, 'energy') and self.cost > 0:
            user.energy -= self.cost
        
        # 쿨다운 시작
        if self.cooldown:
            self.cooldown.use()
        
        # 스킬 실행
        if self.execute_func:
            self.execute_func(user, target, self, **kwargs)
        
        return True
    
    def upgrade(self):
        """스킬 레벨업"""
        if self.level < self.max_level:
            self.level += 1
            
            # 레벨 보너스 적용
            for stat, bonus in self.level_bonuses.items():
                if hasattr(self, stat):
                    current = getattr(self, stat)
                    setattr(self, stat, current + bonus)
            
            return True
        return False
    
    def get_tooltip(self) -> str:
        """스킬 툴팁 텍스트"""
        text = f"{self.korean_name} Lv.{self.level}/{self.max_level}\n"
        text += f"{self.korean_description}\n"
        
        if self.damage > 0:
            text += f"데미지: {self.damage}\n"
        if self.duration > 0:
            text += f"지속시간: {self.duration}초\n"
        if self.cooldown:
            text += f"쿨다운: {self.cooldown.base_cooldown}초\n"
        if self.cost > 0:
            text += f"코스트: {self.cost}\n"
        
        return text


class SkillSystem:
    """
    ⚔️ 스킬 시스템 관리자
    
    플레이어와 보스의 스킬을 관리하고 실행합니다.
    """
    
    def __init__(self):
        """스킬 시스템 초기화"""
        # 스킬 레지스트리
        self.skill_registry: Dict[str, Skill] = {}
        
        # 엔티티별 스킬
        self.entity_skills: Dict[Any, List[str]] = {}
        
        # 활성 스킬 효과
        self.active_effects: List[Dict[str, Any]] = []
        
        # 스킬 실행 함수 등록
        self._register_skill_functions()
        
        print("⚔️ 스킬 시스템 초기화 완료")
    
    def _register_skill_functions(self):
        """기본 스킬 실행 함수 등록"""
        # 대시 스킬
        self.register_skill_function("dash", self._execute_dash)
        # 파워 샷
        self.register_skill_function("power_shot", self._execute_power_shot)
        # 슬로우 모션
        self.register_skill_function("slow_motion", self._execute_slow_motion)
        # 실드
        self.register_skill_function("shield", self._execute_shield)
        # 버스트
        self.register_skill_function("burst", self._execute_burst)
    
    def register_skill(self, skill: Skill):
        """
        스킬 등록
        
        Args:
            skill: 등록할 스킬
        """
        self.skill_registry[skill.id] = skill
    
    def register_skill_function(self, skill_id: str, func: Callable):
        """
        스킬 실행 함수 등록
        
        Args:
            skill_id: 스킬 ID
            func: 실행 함수
        """
        if skill_id in self.skill_registry:
            self.skill_registry[skill_id].execute_func = func
    
    def grant_skill(self, entity: Any, skill_id: str):
        """
        엔티티에 스킬 부여
        
        Args:
            entity: 스킬을 받을 엔티티
            skill_id: 부여할 스킬 ID
        """
        if entity not in self.entity_skills:
            self.entity_skills[entity] = []
        
        if skill_id not in self.entity_skills[entity]:
            self.entity_skills[entity].append(skill_id)
            
            # 패시브 스킬은 즉시 적용
            skill = self.skill_registry.get(skill_id)
            if skill and skill.type == SkillType.PASSIVE:
                skill.use(entity)
    
    def use_skill(self, entity: Any, skill_id: str, target: Any = None, **kwargs) -> bool:
        """
        스킬 사용
        
        Args:
            entity: 스킬 사용자
            skill_id: 사용할 스킬 ID
            target: 대상
            
        Returns:
            스킬 사용 성공 여부
        """
        # 엔티티가 스킬을 보유하고 있는지 확인
        if entity not in self.entity_skills:
            return False
        
        if skill_id not in self.entity_skills[entity]:
            return False
        
        # 스킬 사용
        skill = self.skill_registry.get(skill_id)
        if skill:
            return skill.use(entity, target, **kwargs)
        
        return False
    
    def update(self, dt: float):
        """
        스킬 시스템 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 쿨다운 업데이트
        for skill in self.skill_registry.values():
            if skill.cooldown:
                skill.cooldown.update(dt)
        
        # 활성 효과 업데이트
        for effect in self.active_effects[:]:
            effect['duration'] -= dt
            if effect['duration'] <= 0:
                # 효과 종료
                if 'on_end' in effect:
                    effect['on_end']()
                self.active_effects.remove(effect)
    
    def get_entity_skills(self, entity: Any) -> List[Skill]:
        """
        엔티티의 스킬 목록 반환
        
        Args:
            entity: 엔티티
            
        Returns:
            스킬 목록
        """
        if entity not in self.entity_skills:
            return []
        
        skills = []
        for skill_id in self.entity_skills[entity]:
            skill = self.skill_registry.get(skill_id)
            if skill:
                skills.append(skill)
        
        return skills
    
    def get_skill_cooldown(self, entity: Any, skill_id: str) -> float:
        """
        스킬 쿨다운 진행률 반환
        
        Args:
            entity: 엔티티
            skill_id: 스킬 ID
            
        Returns:
            쿨다운 진행률 (0~1)
        """
        if entity not in self.entity_skills:
            return 0
        
        if skill_id not in self.entity_skills[entity]:
            return 0
        
        skill = self.skill_registry.get(skill_id)
        if skill and skill.cooldown:
            return skill.cooldown.get_progress()
        
        return 1.0
    
    # 기본 스킬 실행 함수들
    def _execute_dash(self, user: Any, target: Any, skill: Skill, **kwargs):
        """대시 스킬 실행"""
        if hasattr(user, 'vel_x'):
            direction = kwargs.get('direction', 1)
            user.vel_x += direction * skill.range
            
            # 효과 추가
            self.active_effects.append({
                'type': 'dash',
                'user': user,
                'duration': 0.2,
                'trail': True
            })
    
    def _execute_power_shot(self, user: Any, target: Any, skill: Skill, **kwargs):
        """파워 샷 스킬 실행"""
        if target and hasattr(target, 'vel_y'):
            # 공 속도 증가
            target.vel_y *= 1.5
            if hasattr(target, 'damage'):
                target.damage = skill.damage
            
            # 효과 추가
            self.active_effects.append({
                'type': 'power_shot',
                'target': target,
                'duration': skill.duration,
                'color': skill.effect_color
            })
    
    def _execute_slow_motion(self, user: Any, target: Any, skill: Skill, **kwargs):
        """슬로우 모션 스킬 실행"""
        # 전역 시간 스케일 조정
        game_state = kwargs.get('game_state')
        if game_state:
            old_scale = getattr(game_state, 'time_scale', 1.0)
            game_state.time_scale = 0.3
            
            # 효과 추가
            self.active_effects.append({
                'type': 'slow_motion',
                'duration': skill.duration,
                'on_end': lambda: setattr(game_state, 'time_scale', old_scale)
            })
    
    def _execute_shield(self, user: Any, target: Any, skill: Skill, **kwargs):
        """실드 스킬 실행"""
        if hasattr(user, 'shield'):
            user.shield = True
            user.shield_hp = skill.damage
            
            # 효과 추가
            self.active_effects.append({
                'type': 'shield',
                'user': user,
                'duration': skill.duration,
                'on_end': lambda: setattr(user, 'shield', False)
            })
    
    def _execute_burst(self, user: Any, target: Any, skill: Skill, **kwargs):
        """버스트 스킬 실행"""
        # 범위 내 모든 공에 영향
        balls = kwargs.get('balls', [])
        for ball in balls:
            if hasattr(ball, 'x') and hasattr(user, 'x'):
                distance = math.sqrt((ball.x - user.x)**2 + (ball.y - user.y)**2)
                if distance <= skill.range:
                    # 공을 밀어냄
                    dx = ball.x - user.x
                    dy = ball.y - user.y
                    if distance > 0:
                        dx /= distance
                        dy /= distance
                    ball.vel_x += dx * skill.damage
                    ball.vel_y += dy * skill.damage
        
        # 효과 추가
        self.active_effects.append({
            'type': 'burst',
            'center': (user.x, user.y) if hasattr(user, 'x') else (0, 0),
            'radius': skill.range,
            'duration': 0.5
        })
    
    def draw_effects(self, screen: pygame.Surface):
        """스킬 효과 그리기"""
        for effect in self.active_effects:
            if effect['type'] == 'burst':
                # 버스트 효과 그리기
                center = effect['center']
                radius = effect['radius'] * (1 - effect['duration'] / 0.5)
                alpha = int(255 * effect['duration'] / 0.5)
                
                # 반투명 원 그리기 (실제로는 Surface와 알파 블렌딩 필요)
                pygame.draw.circle(screen, (255, 255, 255, alpha),
                                 center, int(radius), 2)
            
            elif effect['type'] == 'power_shot':
                # 파워 샷 효과 (공 주변 이펙트)
                if 'target' in effect and hasattr(effect['target'], 'x'):
                    target = effect['target']
                    pygame.draw.circle(screen, effect.get('color', (255, 0, 0)),
                                     (int(target.x), int(target.y)),
                                     int(target.radius * 1.5), 2)
    
    def reset(self):
        """스킬 시스템 초기화"""
        # 쿨다운 리셋
        for skill in self.skill_registry.values():
            if skill.cooldown:
                skill.cooldown.current_cooldown = 0
        
        # 활성 효과 제거
        self.active_effects.clear()
        
        print("⚔️ 스킬 시스템 리셋 완료")


def create_default_skills() -> List[Skill]:
    """기본 스킬 생성"""
    skills = []
    
    # 대시 스킬
    dash = Skill(
        id="dash",
        name="Dash",
        korean_name="대시",
        type=SkillType.ACTIVE,
        target=SkillTarget.SELF,
        range=100,
        cooldown=SkillCooldown(base_cooldown=2.0),
        description="Quickly dash in a direction",
        korean_description="빠르게 대시합니다",
        effect_color=(0, 255, 255)
    )
    skills.append(dash)
    
    # 파워 샷
    power_shot = Skill(
        id="power_shot",
        name="Power Shot",
        korean_name="파워 샷",
        type=SkillType.ACTIVE,
        target=SkillTarget.BALL,
        damage=2.0,
        duration=1.0,
        cooldown=SkillCooldown(base_cooldown=5.0),
        cost=20,
        description="Increases ball speed and damage",
        korean_description="공의 속도와 데미지를 증가시킵니다",
        effect_color=(255, 0, 0)
    )
    skills.append(power_shot)
    
    # 슬로우 모션
    slow_motion = Skill(
        id="slow_motion",
        name="Slow Motion",
        korean_name="슬로우 모션",
        type=SkillType.ULTIMATE,
        target=SkillTarget.AREA,
        duration=3.0,
        cooldown=SkillCooldown(base_cooldown=30.0),
        cost=50,
        description="Slows down time",
        korean_description="시간을 느리게 만듭니다",
        effect_color=(128, 128, 255)
    )
    skills.append(slow_motion)
    
    # 실드
    shield = Skill(
        id="shield",
        name="Shield",
        korean_name="실드",
        type=SkillType.ACTIVE,
        target=SkillTarget.SELF,
        damage=3,  # Shield HP
        duration=10.0,
        cooldown=SkillCooldown(base_cooldown=15.0),
        cost=30,
        description="Creates a protective shield",
        korean_description="보호막을 생성합니다",
        effect_color=(0, 255, 0)
    )
    skills.append(shield)
    
    # 버스트
    burst = Skill(
        id="burst",
        name="Burst",
        korean_name="버스트",
        type=SkillType.COUNTER,
        target=SkillTarget.AREA,
        damage=50,  # Push force
        range=200,
        cooldown=SkillCooldown(base_cooldown=10.0),
        cost=25,
        description="Pushes all nearby balls away",
        korean_description="주변의 모든 공을 밀어냅니다",
        effect_color=(255, 255, 0)
    )
    skills.append(burst)
    
    return skills