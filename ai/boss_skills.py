"""
Boss Skills System - 보스 스킬 시스템
레거시 bosspong의 고급 보스 스킬 구현
"""

import pygame
import math
import random
from typing import List, Dict, Any, Optional, Tuple
from enum import Enum
from dataclasses import dataclass
from core.events import EventType, emit_event
from core.global_manager import GlobalManager

class BossType(Enum):
    """보스 타입"""
    LIGHTNING_MASTER = "lightning_master"
    ICE_QUEEN = "ice_queen"
    FIRE_KNIGHT = "fire_knight"
    WIND_SPIRIT = "wind_spirit"

@dataclass
class BossSkill:
    """보스 스킬 클래스"""
    name: str
    cooldown: float
    duration: float
    damage: float
    effect: Dict[str, Any]

class BossSkillManager:
    """보스 스킬 매니저"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        
        # 현재 보스 타입
        self.current_boss: Optional[BossType] = None
        
        # 스킬 쿨다운
        self.skill_cooldowns: Dict[str, float] = {}
        
        # 활성 스킬 효과
        self.active_skills: List[Dict[str, Any]] = []
        
        # 화면 크기
        self.width = self.global_manager.get('WIDTH', 600)
        self.height = self.global_manager.get('HEIGHT', 750)
        
        # 보스별 스킬 정의
        self.boss_skills = self._define_boss_skills()
        
    def _define_boss_skills(self) -> Dict[BossType, List[BossSkill]]:
        """보스별 스킬 정의"""
        return {
            BossType.LIGHTNING_MASTER: [
                BossSkill(
                    name="thunder_strike",
                    cooldown=5.0,
                    duration=0.5,
                    damage=2.0,
                    effect={'type': 'lightning', 'range': 100, 'stun': 1.0}
                ),
                BossSkill(
                    name="chain_lightning",
                    cooldown=8.0,
                    duration=1.0,
                    damage=1.0,
                    effect={'type': 'chain', 'bounces': 3, 'range': 150}
                ),
                BossSkill(
                    name="electric_field",
                    cooldown=12.0,
                    duration=5.0,
                    damage=0.5,
                    effect={'type': 'field', 'radius': 200, 'slow': 0.5}
                )
            ],
            BossType.ICE_QUEEN: [
                BossSkill(
                    name="ice_shard",
                    cooldown=3.0,
                    duration=0.3,
                    damage=1.5,
                    effect={'type': 'projectile', 'speed': 8, 'freeze': 0.5}
                ),
                BossSkill(
                    name="blizzard",
                    cooldown=10.0,
                    duration=4.0,
                    damage=0.3,
                    effect={'type': 'area', 'radius': 300, 'slow': 0.7}
                ),
                BossSkill(
                    name="ice_wall",
                    cooldown=7.0,
                    duration=6.0,
                    damage=0.0,
                    effect={'type': 'wall', 'width': 200, 'height': 30}
                )
            ],
            BossType.FIRE_KNIGHT: [
                BossSkill(
                    name="flame_wave",
                    cooldown=4.0,
                    duration=1.0,
                    damage=2.0,
                    effect={'type': 'wave', 'width': 300, 'speed': 5}
                ),
                BossSkill(
                    name="meteor_strike",
                    cooldown=9.0,
                    duration=2.0,
                    damage=3.0,
                    effect={'type': 'meteor', 'radius': 80, 'count': 3}
                ),
                BossSkill(
                    name="inferno",
                    cooldown=15.0,
                    duration=5.0,
                    damage=0.8,
                    effect={'type': 'burn', 'radius': 250, 'dot': 0.2}
                )
            ],
            BossType.WIND_SPIRIT: [
                BossSkill(
                    name="tornado",
                    cooldown=6.0,
                    duration=3.0,
                    damage=1.0,
                    effect={'type': 'tornado', 'radius': 60, 'pull': 3.0}
                ),
                BossSkill(
                    name="wind_blade",
                    cooldown=2.5,
                    duration=0.5,
                    damage=1.2,
                    effect={'type': 'blade', 'range': 400, 'width': 20}
                ),
                BossSkill(
                    name="hurricane",
                    cooldown=12.0,
                    duration=6.0,
                    damage=0.5,
                    effect={'type': 'hurricane', 'push': 5.0, 'chaos': 2.0}
                )
            ]
        }
        
    def set_boss_type(self, boss_type: BossType):
        """보스 타입 설정"""
        self.current_boss = boss_type
        self.skill_cooldowns.clear()
        self.active_skills.clear()
        
        # 스킬 쿨다운 초기화
        if boss_type in self.boss_skills:
            for skill in self.boss_skills[boss_type]:
                self.skill_cooldowns[skill.name] = 0
                
    def use_skill(self, skill_name: str) -> bool:
        """스킬 사용
        
        Args:
            skill_name: 스킬 이름
            
        Returns:
            사용 성공 여부
        """
        if not self.current_boss:
            return False
            
        # 쿨다운 체크
        if self.skill_cooldowns.get(skill_name, 0) > 0:
            return False
            
        # 스킬 찾기
        skills = self.boss_skills.get(self.current_boss, [])
        skill = None
        for s in skills:
            if s.name == skill_name:
                skill = s
                break
                
        if not skill:
            return False
            
        # 스킬 발동
        self._activate_skill(skill)
        
        # 쿨다운 설정
        self.skill_cooldowns[skill_name] = skill.cooldown
        
        return True
        
    def _activate_skill(self, skill: BossSkill):
        """스킬 발동"""
        boss_rect = self.global_manager.get('BOSS')
        if not boss_rect:
            return
            
        # 스킬 타입별 처리
        if self.current_boss == BossType.LIGHTNING_MASTER:
            self._activate_lightning_skill(skill, boss_rect)
        elif self.current_boss == BossType.ICE_QUEEN:
            self._activate_ice_skill(skill, boss_rect)
        elif self.current_boss == BossType.FIRE_KNIGHT:
            self._activate_fire_skill(skill, boss_rect)
        elif self.current_boss == BossType.WIND_SPIRIT:
            self._activate_wind_skill(skill, boss_rect)
            
        # 이벤트 발생
        emit_event(EventType.BOSS_SPECIAL_ATTACK, {
            'boss': self.current_boss.value,
            'skill': skill.name,
            'damage': skill.damage
        })
        
    def _activate_lightning_skill(self, skill: BossSkill, boss_rect):
        """번개 스킬 발동"""
        if skill.name == "thunder_strike":
            # 번개 공격
            player_rect = self.global_manager.get('PLAYER')
            if player_rect:
                self.active_skills.append({
                    'type': 'lightning_bolt',
                    'start': (boss_rect.centerx, boss_rect.centery),
                    'end': (player_rect.centerx, player_rect.centery),
                    'duration': skill.duration * 60,
                    'damage': skill.damage,
                    'color': (255, 255, 100)
                })
                emit_event(EventType.PLAY_SOUND, {'sound': 'thunder'})
                
        elif skill.name == "chain_lightning":
            # 연쇄 번개
            self.active_skills.append({
                'type': 'chain_lightning',
                'position': (boss_rect.centerx, boss_rect.centery),
                'bounces': skill.effect['bounces'],
                'duration': skill.duration * 60,
                'damage': skill.damage,
                'range': skill.effect['range']
            })
            
        elif skill.name == "electric_field":
            # 전기장
            self.active_skills.append({
                'type': 'electric_field',
                'center': (boss_rect.centerx, boss_rect.centery),
                'radius': skill.effect['radius'],
                'duration': skill.duration * 60,
                'damage': skill.damage,
                'slow': skill.effect['slow']
            })
            
    def _activate_ice_skill(self, skill: BossSkill, boss_rect):
        """얼음 스킬 발동"""
        if skill.name == "ice_shard":
            # 얼음 파편
            player_rect = self.global_manager.get('PLAYER')
            if player_rect:
                dx = player_rect.centerx - boss_rect.centerx
                dy = player_rect.centery - boss_rect.centery
                dist = math.sqrt(dx**2 + dy**2)
                if dist > 0:
                    dx /= dist
                    dy /= dist
                    
                self.active_skills.append({
                    'type': 'ice_shard',
                    'position': [boss_rect.centerx, boss_rect.centery],
                    'velocity': [dx * skill.effect['speed'], dy * skill.effect['speed']],
                    'duration': skill.duration * 60,
                    'damage': skill.damage,
                    'freeze': skill.effect['freeze']
                })
                
        elif skill.name == "blizzard":
            # 눈보라
            self.active_skills.append({
                'type': 'blizzard',
                'center': (self.width // 2, self.height // 2),
                'radius': skill.effect['radius'],
                'duration': skill.duration * 60,
                'damage': skill.damage,
                'slow': skill.effect['slow'],
                'particles': []
            })
            
        elif skill.name == "ice_wall":
            # 얼음 벽
            self.active_skills.append({
                'type': 'ice_wall',
                'position': (self.width // 2, boss_rect.centery + 100),
                'width': skill.effect['width'],
                'height': skill.effect['height'],
                'duration': skill.duration * 60,
                'health': 10
            })
            
    def _activate_fire_skill(self, skill: BossSkill, boss_rect):
        """화염 스킬 발동"""
        if skill.name == "flame_wave":
            # 화염파
            self.active_skills.append({
                'type': 'flame_wave',
                'position': [boss_rect.centerx, boss_rect.centery],
                'width': skill.effect['width'],
                'speed': skill.effect['speed'],
                'duration': skill.duration * 60,
                'damage': skill.damage,
                'direction': 1 if random.random() > 0.5 else -1
            })
            
        elif skill.name == "meteor_strike":
            # 운석 공격
            for i in range(skill.effect['count']):
                self.active_skills.append({
                    'type': 'meteor',
                    'position': [random.randint(50, self.width - 50), -50],
                    'target': [random.randint(50, self.width - 50), 
                              random.randint(200, self.height - 200)],
                    'radius': skill.effect['radius'],
                    'duration': skill.duration * 60,
                    'damage': skill.damage,
                    'delay': i * 20
                })
                
        elif skill.name == "inferno":
            # 지옥불
            self.active_skills.append({
                'type': 'inferno',
                'center': (boss_rect.centerx, boss_rect.centery),
                'radius': skill.effect['radius'],
                'duration': skill.duration * 60,
                'damage': skill.damage,
                'dot': skill.effect['dot']
            })
            
    def _activate_wind_skill(self, skill: BossSkill, boss_rect):
        """바람 스킬 발동"""
        if skill.name == "tornado":
            # 토네이도
            self.active_skills.append({
                'type': 'tornado',
                'position': [boss_rect.centerx, boss_rect.centery],
                'velocity': [random.uniform(-2, 2), random.uniform(-1, 1)],
                'radius': skill.effect['radius'],
                'duration': skill.duration * 60,
                'damage': skill.damage,
                'pull': skill.effect['pull']
            })
            
        elif skill.name == "wind_blade":
            # 바람 칼날
            player_rect = self.global_manager.get('PLAYER')
            if player_rect:
                angle = math.atan2(player_rect.centery - boss_rect.centery,
                                  player_rect.centerx - boss_rect.centerx)
                self.active_skills.append({
                    'type': 'wind_blade',
                    'position': (boss_rect.centerx, boss_rect.centery),
                    'angle': angle,
                    'range': skill.effect['range'],
                    'width': skill.effect['width'],
                    'duration': skill.duration * 60,
                    'damage': skill.damage
                })
                
        elif skill.name == "hurricane":
            # 허리케인
            self.active_skills.append({
                'type': 'hurricane',
                'duration': skill.duration * 60,
                'damage': skill.damage,
                'push': skill.effect['push'],
                'chaos': skill.effect['chaos']
            })
            
    def update(self, dt: float):
        """업데이트"""
        # 쿨다운 업데이트
        for skill_name in self.skill_cooldowns:
            if self.skill_cooldowns[skill_name] > 0:
                self.skill_cooldowns[skill_name] -= dt
                
        # 활성 스킬 업데이트
        for skill in self.active_skills[:]:
            skill['duration'] -= dt * 60
            
            # 이동하는 스킬 업데이트
            if 'position' in skill and 'velocity' in skill:
                skill['position'][0] += skill['velocity'][0] * dt * 60
                skill['position'][1] += skill['velocity'][1] * dt * 60
                
            # 지연된 스킬 처리
            if 'delay' in skill:
                skill['delay'] -= dt * 60
                if skill['delay'] > 0:
                    continue
                    
            # 만료된 스킬 제거
            if skill['duration'] <= 0:
                self.active_skills.remove(skill)
                
    def render(self, screen: pygame.Surface):
        """렌더링"""
        for skill in self.active_skills:
            if 'delay' in skill and skill['delay'] > 0:
                continue
                
            if skill['type'] == 'lightning_bolt':
                # 번개 그리기
                pygame.draw.line(screen, skill['color'], 
                               skill['start'], skill['end'], 3)
                # 번개 효과
                for i in range(3):
                    offset_x = random.randint(-10, 10)
                    offset_y = random.randint(-10, 10)
                    pygame.draw.line(screen, (255, 255, 200),
                                   (skill['start'][0] + offset_x, skill['start'][1] + offset_y),
                                   (skill['end'][0] + offset_x, skill['end'][1] + offset_y), 1)
                                   
            elif skill['type'] == 'electric_field':
                # 전기장 그리기
                for i in range(5):
                    radius = skill['radius'] * (1 - i * 0.2)
                    alpha = int(100 * (1 - i * 0.2))
                    s = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                    pygame.draw.circle(s, (200, 200, 255, alpha),
                                     (radius, radius), int(radius))
                    screen.blit(s, (skill['center'][0] - radius, 
                                   skill['center'][1] - radius))
                                   
            elif skill['type'] == 'ice_shard':
                # 얼음 파편 그리기
                pygame.draw.polygon(screen, (150, 200, 255),
                                   [(skill['position'][0] - 5, skill['position'][1]),
                                    (skill['position'][0] + 5, skill['position'][1]),
                                    (skill['position'][0], skill['position'][1] + 15)])
                                    
            elif skill['type'] == 'ice_wall':
                # 얼음 벽 그리기
                pygame.draw.rect(screen, (150, 200, 255),
                               (skill['position'][0] - skill['width'] // 2,
                                skill['position'][1] - skill['height'] // 2,
                                skill['width'], skill['height']))
                                
            elif skill['type'] == 'flame_wave':
                # 화염파 그리기
                for i in range(10):
                    x = skill['position'][0] + i * 30 * skill['direction']
                    y = skill['position'][1] + math.sin(i * 0.5) * 20
                    pygame.draw.circle(screen, (255, 100 + i * 10, 0),
                                     (int(x), int(y)), 15 - i)
                                     
            elif skill['type'] == 'meteor':
                # 운석 그리기
                if skill['delay'] <= 0:
                    pygame.draw.circle(screen, (255, 100, 0),
                                     (int(skill['position'][0]), int(skill['position'][1])),
                                     int(skill['radius']))
                    # 화염 꼬리
                    for i in range(5):
                        pygame.draw.circle(screen, (255, 150 + i * 20, 0),
                                         (int(skill['position'][0] - i * 5),
                                          int(skill['position'][1] - i * 10)),
                                         int(skill['radius'] * (1 - i * 0.15)))
                                         
            elif skill['type'] == 'tornado':
                # 토네이도 그리기
                for i in range(10):
                    radius = skill['radius'] * (1 - i * 0.08)
                    y_offset = i * 15
                    pygame.draw.circle(screen, (200, 200, 200),
                                     (int(skill['position'][0]), 
                                      int(skill['position'][1] - y_offset)),
                                     int(radius), 2)
                                     
            elif skill['type'] == 'wind_blade':
                # 바람 칼날 그리기
                end_x = skill['position'][0] + math.cos(skill['angle']) * skill['range']
                end_y = skill['position'][1] + math.sin(skill['angle']) * skill['range']
                pygame.draw.line(screen, (150, 255, 150),
                               skill['position'], (end_x, end_y), skill['width'])
                               
    def get_ai_recommendation(self) -> Optional[str]:
        """AI용 스킬 추천
        
        Returns:
            추천 스킬 이름 또는 None
        """
        if not self.current_boss:
            return None
            
        # 사용 가능한 스킬 찾기
        available_skills = []
        skills = self.boss_skills.get(self.current_boss, [])
        
        for skill in skills:
            if self.skill_cooldowns.get(skill.name, 0) <= 0:
                available_skills.append(skill)
                
        if not available_skills:
            return None
            
        # 상황에 따라 스킬 선택
        player_rect = self.global_manager.get('PLAYER')
        boss_rect = self.global_manager.get('BOSS')
        
        if player_rect and boss_rect:
            # 거리 계산
            dist = abs(player_rect.centerx - boss_rect.centerx)
            
            # 거리에 따른 스킬 선택
            if dist < 100:
                # 근거리: 강력한 스킬
                for skill in available_skills:
                    if skill.damage >= 2.0:
                        return skill.name
            elif dist > 300:
                # 원거리: 투사체 스킬
                for skill in available_skills:
                    if 'projectile' in skill.effect.get('type', '') or \
                       'wave' in skill.effect.get('type', ''):
                        return skill.name
                        
        # 랜덤 선택
        return random.choice(available_skills).name if available_skills else None
        
    def clear(self):
        """초기화"""
        self.active_skills.clear()
        self.skill_cooldowns.clear()
        self.current_boss = None

# 싱글톤 인스턴스
_boss_skill_manager = None

def get_boss_skill_manager() -> BossSkillManager:
    """보스 스킬 매니저 싱글톤 반환"""
    global _boss_skill_manager
    if _boss_skill_manager is None:
        _boss_skill_manager = BossSkillManager()
    return _boss_skill_manager