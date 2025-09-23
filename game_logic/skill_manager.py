"""
Skill Manager - 스킬 시스템 관리
플레이어와 보스의 스킬 관리
"""

import pygame
import random
import math
from typing import Dict, List, Optional, Tuple
from core.global_manager import GlobalManager
from core.events import EventType, emit_event
from game_logic.physics import get_physics_system


class SkillManager:
    """스킬 관리 시스템"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        self.physics = get_physics_system()
        
        # 활성 스킬들
        self.active_skills = []
        
        # 스킬 쿨다운
        self.skill_cooldowns = {}
        
        # 스킬 효과들
        self.skill_effects = {}
        
        # 스테이지별 스킬
        self.stage_skills = {
            1: [],  # Training - 기본 스킬만
            2: ['speed_boost', 'afterimage'],
            3: ['tears_of_pain', 'emotional_overdrive'],
            4: ['meditation', 'quake', 'magnetic_field'],
            5: ['fireball', 'flame_trail', 'explosion'],
            6: ['interceptors', 'yamato_cannon', 'plasma_shield']
        }
        
        # 아이템 스킬
        self.item_skills = {
            'grenade': self.activate_grenade,
            'smoke_grenade': self.activate_smoke_grenade,
            'flare': self.activate_flare,
            'molotov': self.activate_molotov,
            'wall': self.activate_wall,
            'predictor': self.activate_predictor,
            'long_boost': self.activate_long_boost,
            'balloon': self.activate_balloon,
            'whip': self.activate_whip,
            'doping_potion': self.activate_doping_potion
        }
        
        # 특수 스킬 상태
        self.tears_active = False
        self.tears_list = []
        self.meditation_active = False
        self.meditation_timer = 0
        self.quake_active = False
        self.quake_timer = 0
        self.fireballs = []
        self.flame_trails = []
        
    def activate_skill(self, skill_name: str, caster: str = 'player') -> bool:
        """스킬 활성화
        
        Args:
            skill_name: 스킬 이름
            caster: 시전자 ('player' or 'boss')
            
        Returns:
            활성화 성공 여부
        """
        # 쿨다운 체크
        if self.is_on_cooldown(skill_name):
            return False
            
        # 스킬별 처리
        if skill_name in self.item_skills:
            self.item_skills[skill_name]()
        else:
            # 스테이지 특수 스킬
            self._activate_stage_skill(skill_name, caster)
            
        # 쿨다운 설정
        self.set_cooldown(skill_name, self.get_skill_cooldown(skill_name))
        
        # 이벤트 발생
        emit_event(EventType.SPECIAL_ACTIVATED, {
            'skill': skill_name,
            'caster': caster
        })
        
        return True
    
    def _activate_stage_skill(self, skill_name: str, caster: str):
        """스테이지 특수 스킬 활성화"""
        if skill_name == 'tears_of_pain':
            self.activate_tears_of_pain()
        elif skill_name == 'emotional_overdrive':
            self.activate_emotional_overdrive()
        elif skill_name == 'meditation':
            self.activate_meditation()
        elif skill_name == 'quake':
            self.activate_quake()
        elif skill_name == 'fireball':
            self.activate_fireball()
        elif skill_name == 'speed_boost':
            self.activate_speed_boost(caster)
        elif skill_name == 'afterimage':
            self.activate_afterimage(caster)
            
    def activate_grenade(self):
        """수류탄 발동"""
        self.global_manager.set('grenade_active', True)
        self.global_manager.set('grenade_timer', 0)
        
        # 효과음
        sound = self.global_manager.get('SOUND_ACTIVE_ITEM')
        if sound:
            sound.play()
            
    def activate_smoke_grenade(self):
        """연막탄 발동"""
        self.global_manager.set('smoke_active', True)
        self.global_manager.set('smoke_timer', 0)
        self.global_manager.set('smoke_opacity', 0)
        
    def activate_flare(self):
        """조명탄 발동"""
        self.global_manager.set('flare_active', True)
        self.global_manager.set('flare_timer', 0)
        
    def activate_molotov(self):
        """화염병 발동"""
        self.global_manager.set('molotov_active', True)
        self.global_manager.set('molotov_timer', 0)
        
    def activate_wall(self):
        """벽 생성"""
        wall_data = {
            'x': random.randint(100, 500),
            'y': random.randint(200, 550),
            'width': 100,
            'height': 20,
            'duration': 300
        }
        self.global_manager.set('wall_active', True)
        self.global_manager.set('wall_data', wall_data)
        
    def activate_predictor(self):
        """궤적 예측"""
        self.global_manager.set('predictor_active', True)
        self.global_manager.set('predictor_timer', 180)  # 3초
        
    def activate_long_boost(self):
        """롱부스트 발동"""
        self.global_manager.set('long_boost_active', True)
        self.global_manager.set('long_boost_timer', 0)
        self.global_manager.set('LONG_BOOST_DURATION', 360)
        
        # 패들 크기 증가 시작
        paddle_width = self.global_manager.get('PADDLE_WIDTH', 100)
        self.global_manager.set('PADDLE_BASE_WIDTH', paddle_width)
        
    def activate_balloon(self):
        """풍선 스킬"""
        self.global_manager.set('balloon_active', True)
        self.global_manager.set('balloon_timer', 0)
        
        # 풍선 효과음
        sound = self.global_manager.get('SOUND_BALLOON_BOOM')
        if sound:
            sound.play()
            
    def activate_whip(self):
        """채찍 스킬"""
        self.global_manager.set('whip_active', True)
        self.global_manager.set('whip_timer', 0)

        # 강한 타격 효과
        self.physics.apply_power_shot(2.0)

    def activate_doping_potion(self):
        """도핑물약 발동"""
        fps = max(1, self.global_manager.get('FPS', 60))
        duration_frames = int(8 * fps)
        self.global_manager.set('doping_potion_active', True)
        self.global_manager.set('doping_potion_timer_frames', duration_frames)
        self.global_manager.set('doping_potion_duration_frames', duration_frames)
        self.global_manager.set('doping_potion_refresh', True)

        drink_sound = self.global_manager.get('SOUND_DRINK')
        if drink_sound:
            try:
                drink_sound.play()
            except Exception:  # noqa: BLE001
                pass
        else:
            active_sound = self.global_manager.get('SOUND_ACTIVE_ITEM')
            if active_sound:
                try:
                    active_sound.play()
                except Exception:  # noqa: BLE001
                    pass
        
    def activate_tears_of_pain(self):
        """눈물의 비 발동 (Stage 3)"""
        self.tears_active = True
        self.tears_list = []
        
        # 눈물 생성
        for _ in range(10):
            tear = {
                'x': random.randint(50, 550),
                'y': random.randint(-200, -50),
                'speed': random.uniform(2, 5),
                'size': random.randint(10, 20)
            }
            self.tears_list.append(tear)
            
    def activate_emotional_overdrive(self):
        """감정 폭발 (Stage 3)"""
        self.global_manager.set('overdrive_active', True)
        self.global_manager.set('overdrive_timer', 300)
        
        # 화면 빨간색 오버레이
        self.global_manager.set('red_overlay', 100)
        
    def activate_meditation(self):
        """명상 타임 (Stage 4)"""
        self.meditation_active = True
        self.meditation_timer = 180  # 3초
        
        # 시간 느려짐
        self.physics.apply_slow_motion(0.3, 3.0)
        
    def activate_quake(self):
        """지진 (Stage 4)"""
        self.quake_active = True
        self.quake_timer = 120  # 2초
        
        # 지진 효과음
        sound = self.global_manager.get('SOUND_QUAKE')
        if sound:
            sound.play()
            
        # 화면 흔들림
        self.global_manager.set('screen_shake', 20)
        
    def activate_fireball(self):
        """화염탄 (Stage 5)"""
        fireball = {
            'x': self.global_manager.get('boss_x', 300),
            'y': self.global_manager.get('boss_y', 100),
            'target_x': self.global_manager.get('player_x', 300),
            'target_y': self.global_manager.get('player_y', 650),
            'speed': 5,
            'size': 20
        }
        self.fireballs.append(fireball)
        
        # 화염탄 효과음
        sound = self.global_manager.get('SOUND_FIREBALL')
        if sound:
            sound.play()
            
    def activate_speed_boost(self, target: str):
        """속도 부스트 (Stage 2)"""
        if target == 'boss':
            current_speed = self.global_manager.get('BOSS_MAX_SPEED', 6.3)
            self.global_manager.set('BOSS_MAX_SPEED', current_speed * 1.5)
        else:
            current_speed = self.global_manager.get('MAX_SPEED', 5)
            self.global_manager.set('MAX_SPEED', current_speed * 1.5)
            
        # 3초 후 원래대로
        self.skill_effects['speed_boost'] = {
            'target': target,
            'original_speed': current_speed,
            'timer': 180
        }
        
    def activate_afterimage(self, target: str):
        """잔상 효과 (Stage 2)"""
        self.global_manager.set(f'{target}_afterimage', True)
        self.global_manager.set(f'{target}_afterimage_timer', 120)
        
    def update(self, dt: float):
        """스킬 시스템 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 쿨다운 업데이트
        for skill in list(self.skill_cooldowns.keys()):
            self.skill_cooldowns[skill] -= dt
            if self.skill_cooldowns[skill] <= 0:
                del self.skill_cooldowns[skill]
                
        # 활성 스킬 업데이트
        self.update_active_skills(dt)
        
        # 스킬 효과 업데이트
        self.update_skill_effects(dt)
        
    def update_active_skills(self, dt: float):
        """활성 스킬 업데이트"""
        # 눈물의 비
        if self.tears_active:
            for tear in self.tears_list:
                tear['y'] += tear['speed']
                # 화면 밖으로 나가면 제거
                if tear['y'] > 750:
                    self.tears_list.remove(tear)
            if not self.tears_list:
                self.tears_active = False
                
        # 명상
        if self.meditation_active:
            self.meditation_timer -= dt * 60
            if self.meditation_timer <= 0:
                self.meditation_active = False
                self.physics.apply_slow_motion(1.0)  # 원래 속도로
                
        # 지진
        if self.quake_active:
            self.quake_timer -= dt * 60
            if self.quake_timer <= 0:
                self.quake_active = False
                self.global_manager.set('screen_shake', 0)
                
        # 화염탄
        for fireball in self.fireballs[:]:
            # 목표를 향해 이동
            dx = fireball['target_x'] - fireball['x']
            dy = fireball['target_y'] - fireball['y']
            dist = math.sqrt(dx**2 + dy**2)
            
            if dist > 5:
                fireball['x'] += (dx / dist) * fireball['speed']
                fireball['y'] += (dy / dist) * fireball['speed']
            else:
                # 폭발
                self.fireballs.remove(fireball)
                emit_event(EventType.EXPLOSION, {
                    'x': fireball['x'],
                    'y': fireball['y'],
                    'size': 50
                })
                
    def update_skill_effects(self, dt: float):
        """스킬 효과 업데이트"""
        for effect_name in list(self.skill_effects.keys()):
            effect = self.skill_effects[effect_name]
            effect['timer'] -= dt * 60
            
            if effect['timer'] <= 0:
                # 효과 종료
                if effect_name == 'speed_boost':
                    # 속도 원래대로
                    if effect['target'] == 'boss':
                        self.global_manager.set('BOSS_MAX_SPEED', effect['original_speed'])
                    else:
                        self.global_manager.set('MAX_SPEED', effect['original_speed'])
                        
                del self.skill_effects[effect_name]
                
    def is_on_cooldown(self, skill_name: str) -> bool:
        """스킬이 쿨다운 중인지 확인
        
        Args:
            skill_name: 스킬 이름
            
        Returns:
            쿨다운 중 여부
        """
        return skill_name in self.skill_cooldowns
    
    def set_cooldown(self, skill_name: str, duration: float):
        """스킬 쿨다운 설정
        
        Args:
            skill_name: 스킬 이름
            duration: 쿨다운 시간 (초)
        """
        self.skill_cooldowns[skill_name] = duration
        
    def get_skill_cooldown(self, skill_name: str) -> float:
        """스킬 쿨다운 시간 반환
        
        Args:
            skill_name: 스킬 이름
            
        Returns:
            쿨다운 시간 (초)
        """
        cooldowns = {
            'grenade': 5.0,
            'smoke_grenade': 7.0,
            'flare': 4.0,
            'molotov': 8.0,
            'wall': 10.0,
            'predictor': 3.0,
            'long_boost': 15.0,
            'balloon': 6.0,
            'whip': 4.0,
            'tears_of_pain': 7.0,
            'emotional_overdrive': 10.0,
            'meditation': 12.0,
            'quake': 8.0,
            'fireball': 2.0,
            'speed_boost': 5.0,
            'afterimage': 6.0
        }
        return cooldowns.get(skill_name, 5.0)
    
    def get_available_skills(self, stage: int) -> List[str]:
        """사용 가능한 스킬 목록 반환
        
        Args:
            stage: 스테이지 번호
            
        Returns:
            스킬 이름 리스트
        """
        return self.stage_skills.get(stage, [])
    
    def reset(self):
        """스킬 시스템 리셋"""
        self.active_skills.clear()
        self.skill_cooldowns.clear()
        self.skill_effects.clear()
        self.tears_active = False
        self.tears_list.clear()
        self.meditation_active = False
        self.quake_active = False
        self.fireballs.clear()
        self.flame_trails.clear()


# 싱글톤 인스턴스
_skill_manager = None

def get_skill_manager() -> SkillManager:
    """스킬 매니저 싱글톤 반환"""
    global _skill_manager
    if _skill_manager is None:
        _skill_manager = SkillManager()
    return _skill_manager
