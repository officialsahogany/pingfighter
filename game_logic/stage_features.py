"""
Stage Features - 스테이지별 특수 기능
각 스테이지의 고유 메커니즘과 보스 능력
"""

import pygame
import math
import random
from typing import Dict, Optional, Tuple, List
from core.global_manager import GlobalManager
from core.events import EventType, emit_event
from managers.effects_manager import get_effects_manager
from entities.entity import get_entity_manager
from game_logic.stage7_tetriser import get_tetro_wall_spawn_spec


class StageFeatures:
    """스테이지별 특수 기능 관리"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        self.effects_manager = get_effects_manager()
        self.entity_manager = get_entity_manager()
        
        self.current_stage = 1
        # Stage7 디버그 플래그(모듈 런타임 전용)
        self.stage7_debug = {
            'HUD': False,   # 화면 좌측 상단 간단 HUD
            'GAUGE': False, # 게이지 로그 출력(미사용, 향후 확장)
        }
        self._hud_font = None

        # Stage7 렌더링용 임시 Surface 캐시(크기별 1장 재사용)
        self._t7_cache_cell: dict[tuple[int, int], pygame.Surface] = {}
        
        # 스테이지 1: 채찍 시스템
        self.stage1_whip = {
            'active': False,
            'timer': 0,
            'duration': 0.5,
            'cooldown': 0,
            'cooldown_time': 3.0,
            'angle': 0,
            'length': 150
        }
        
        # 스테이지 2: 스피드 디펜스
        self.stage2_speed = {
            'defense_active': False,
            'defense_timer': 0,
            'defense_duration': 2.0,
            'speed_boost': 2.0,
            'afterimage_active': False,
            'rock_walls': [],  # 바위 벽 리스트
            'max_rocks': 3
        }
        
        # 스테이지 3: 감정 폭발 시스템
        self.stage3_emotion = {
            'overdrive_active': False,
            'overdrive_timer': 0,
            'overdrive_duration': 5.0,
            'tears_active': False,
            'tears': [],  # 눈물 투사체
            'heart_broken': False,
            'emotional_gauge': 0,
            'max_gauge': 100
        }
        
        # 스테이지 4: 자기장 시스템
        self.stage4_magnetic = {
            'field_active': False,
            'field_timer': 0,
            'field_duration': 3.0,
            'meditation_active': False,
            'meditation_timer': 0,
            'zen_particles': [],
            'pull_strength': 3.0
        }
        
        # 스테이지 5: 화염 시스템
        self.stage5_flame = {
            'throwing': False,
            'throw_timer': 0,
            'fireballs': [],
            'flame_trail_active': False,
            'inferno_mode': False,
            'heat_gauge': 0,
            'max_heat': 100
        }
        
        # 스테이지 6: 전함 시스템
        self.stage6_battleship = {
            'missile_barrage_active': False,
            'missiles': [],
            'laser_active': False,
            'laser_timer': 0,
            'laser_position': 0,
            'shield_active': False,
            'shield_hp': 100,
            'yamato_cannon_charging': False,
            'yamato_charge': 0
        }

        # 스테이지 7: 테트리스 벽 시스템
        # - 30초마다 양쪽 벽에 랜덤 테트로미노 10개씩을 쌓아 생성
        # - 보스 스킬 게이지 소모량: 50
        # - 충돌: 공과 충돌 시 축에 따라 반사 처리
        spec = get_tetro_wall_spawn_spec(
            width=self.global_manager.get('WIDTH', 600),
            height=self.global_manager.get('HEIGHT', 750),
        )
        self.stage7_tetris = {
            'enabled': False,
            'interval': float(spec.get('interval_sec', 30.0)),
            'timer': 0.0,
            'skill_cost': int(spec.get('skill_cost', 50)),
            'gauge_current': 0.0,
            'gauge_max': 200.0,
            'recharge_per_sec': 2.0,
            'tile': int(spec.get('tile', 24)),
            'cols': int(spec.get('cols', 5)),
            'left_blocks': [],
            'right_blocks': [],
        }
        
    def set_stage(self, stage: int):
        """스테이지 설정
        
        Args:
            stage: 스테이지 번호
        """
        self.current_stage = stage
        self.reset_all_features()
        if stage == 7:
            self.stage7_tetris['enabled'] = True
            # 화면 크기 변화에 따른 스펙 반영(안전 재설정)
            spec = get_tetro_wall_spawn_spec(
                width=self.global_manager.get('WIDTH', 600),
                height=self.global_manager.get('HEIGHT', 750),
            )
            self.stage7_tetris['interval'] = float(spec.get('interval_sec', self.stage7_tetris['interval']))
            self.stage7_tetris['skill_cost'] = int(spec.get('skill_cost', self.stage7_tetris['skill_cost']))
            self.stage7_tetris['tile'] = int(spec.get('tile', self.stage7_tetris['tile']))
            self.stage7_tetris['cols'] = int(spec.get('cols', self.stage7_tetris['cols']))
        
    def reset_all_features(self):
        """모든 특수 기능 리셋"""
        # 각 스테이지 특수 기능 초기화
        self.stage1_whip['active'] = False
        self.stage1_whip['cooldown'] = 0
        
        self.stage2_speed['defense_active'] = False
        self.stage2_speed['rock_walls'].clear()
        
        self.stage3_emotion['overdrive_active'] = False
        self.stage3_emotion['tears'].clear()
        self.stage3_emotion['emotional_gauge'] = 0
        
        self.stage4_magnetic['field_active'] = False
        self.stage4_magnetic['meditation_active'] = False
        
        self.stage5_flame['throwing'] = False
        self.stage5_flame['fireballs'].clear()
        self.stage5_flame['heat_gauge'] = 0
        
        self.stage6_battleship['missile_barrage_active'] = False
        self.stage6_battleship['missiles'].clear()
        self.stage6_battleship['yamato_charge'] = 0

        # 스테이지7 초기화
        self.stage7_tetris['enabled'] = False
        self.stage7_tetris['timer'] = 0.0
        self.stage7_tetris['gauge_current'] = 0.0
        self.stage7_tetris['left_blocks'].clear()
        self.stage7_tetris['right_blocks'].clear()
        
    def update(self, dt: float):
        """스테이지 기능 업데이트
        
        Args:
            dt: 델타 타임
        """
        if self.current_stage == 1:
            self._update_stage1(dt)
        elif self.current_stage == 2:
            self._update_stage2(dt)
        elif self.current_stage == 3:
            self._update_stage3(dt)
        elif self.current_stage == 4:
            self._update_stage4(dt)
        elif self.current_stage == 5:
            self._update_stage5(dt)
        elif self.current_stage == 6:
            self._update_stage6(dt)
        elif self.current_stage == 7:
            self._update_stage7(dt)
            
    def _update_stage1(self, dt: float):
        """스테이지 1 업데이트 - 채찍"""
        whip = self.stage1_whip
        
        # 채찍 활성화
        if whip['active']:
            whip['timer'] -= dt
            if whip['timer'] <= 0:
                whip['active'] = False
                whip['cooldown'] = whip['cooldown_time']
                
            # 채찍 회전
            whip['angle'] += 720 * dt  # 초당 2회전
            
        # 쿨다운
        if whip['cooldown'] > 0:
            whip['cooldown'] -= dt
            
    def activate_whip(self) -> bool:
        """채찍 활성화
        
        Returns:
            활성화 성공 여부
        """
        whip = self.stage1_whip
        if whip['cooldown'] <= 0 and not whip['active']:
            whip['active'] = True
            whip['timer'] = whip['duration']
            whip['angle'] = 0
            
            # 효과음 및 이펙트
            emit_event(EventType.BOSS_SPECIAL_ATTACK, {
                'attack': 'whip',
                'stage': 1
            })
            
            # 채찍 충돌 체크 (공을 밀어냄)
            ball_rect = self.global_manager.get('BALL')
            boss_rect = self.global_manager.get('BOSS')
            if ball_rect and boss_rect:
                dx = ball_rect.centerx - boss_rect.centerx
                dy = ball_rect.centery - boss_rect.centery
                dist = math.sqrt(dx**2 + dy**2)
                
                if dist < whip['length']:
                    # 공을 밀어냄
                    push_x = (dx / dist) * 10 if dist > 0 else 10
                    push_y = (dy / dist) * 10 if dist > 0 else 10
                    
                    self.global_manager.set('ball_dx', 
                                          self.global_manager.get('ball_dx', 0) + push_x)
                    self.global_manager.set('ball_dy', 
                                          self.global_manager.get('ball_dy', 5) + push_y)
                    
                    # 타격 효과
                    self.effects_manager.create_hit_effect(
                        ball_rect.centerx, ball_rect.centery
                    )
            
            return True
        return False
        
    def _update_stage2(self, dt: float):
        """스테이지 2 업데이트 - 스피드 디펜스"""
        speed = self.stage2_speed
        
        # 스피드 디펜스 활성화
        if speed['defense_active']:
            speed['defense_timer'] -= dt
            if speed['defense_timer'] <= 0:
                speed['defense_active'] = False
                
        # 바위 벽 업데이트
        for rock in speed['rock_walls']:
            if 'hp' in rock and rock['hp'] <= 0:
                speed['rock_walls'].remove(rock)
                # 파괴 이펙트
                self.effects_manager.create_explosion(rock['x'], rock['y'], radius=30)
                
    def activate_speed_defense(self) -> bool:
        """스피드 디펜스 활성화
        
        Returns:
            활성화 성공 여부
        """
        speed = self.stage2_speed
        if not speed['defense_active']:
            speed['defense_active'] = True
            speed['defense_timer'] = speed['defense_duration']
            
            # 바위 벽 생성
            self.spawn_rock_walls()
            
            emit_event(EventType.BOSS_SPECIAL_ATTACK, {
                'attack': 'speed_defense',
                'stage': 2
            })
            
            return True
        return False
        
    def spawn_rock_walls(self):
        """바위 벽 생성"""
        speed = self.stage2_speed
        speed['rock_walls'].clear()
        
        width = self.global_manager.get('WIDTH', 600)
        
        for i in range(speed['max_rocks']):
            x = (i + 1) * (width // (speed['max_rocks'] + 1))
            y = 200 + random.randint(-50, 50)
            
            rock = self.entity_manager.create_wall(x - 30, y, 60, 40)
            rock.add_component('hp', 3)
            rock.add_component('rock_type', 'defense')
            rock.add_component('shadow', True)  # 그림자 효과
            
            speed['rock_walls'].append({
                'entity': rock,
                'x': x,
                'y': y,
                'hp': 3,
                'shadow_offset': random.randint(5, 15)
            })
            
            # 바위 생성 애니메이션
            self.effects_manager.create_dust_cloud(x, y, radius=40)
            
    def _update_stage3(self, dt: float):
        """스테이지 3 업데이트 - 감정 폭발"""
        emotion = self.stage3_emotion
        
        # 감정 게이지 충전
        if not emotion['overdrive_active']:
            emotion['emotional_gauge'] = min(emotion['max_gauge'], 
                                           emotion['emotional_gauge'] + 10 * dt)
            
        # 감정 폭발 활성화
        if emotion['overdrive_active']:
            emotion['overdrive_timer'] -= dt
            if emotion['overdrive_timer'] <= 0:
                emotion['overdrive_active'] = False
                emotion['emotional_gauge'] = 0
                
            # 눈물 생성
            if random.random() < 0.05:  # 5% 확률
                self.spawn_tear()
                
        # 눈물 업데이트
        for tear in emotion['tears'][:]:
            tear['y'] += tear['speed'] * dt * 60
            
            # 화면 밖으로 나가면 제거
            if tear['y'] > self.global_manager.get('HEIGHT', 750):
                emotion['tears'].remove(tear)
                
    def activate_emotional_overdrive(self) -> bool:
        """감정 폭발 활성화
        
        Returns:
            활성화 성공 여부
        """
        emotion = self.stage3_emotion
        if emotion['emotional_gauge'] >= emotion['max_gauge'] and not emotion['overdrive_active']:
            emotion['overdrive_active'] = True
            emotion['overdrive_timer'] = emotion['overdrive_duration']
            emotion['tears_active'] = True
            
            # 화면 효과
            self.effects_manager.flash_screen(color=(255, 100, 100), duration=0.5)
            
            emit_event(EventType.BOSS_SPECIAL_ATTACK, {
                'attack': 'emotional_overdrive',
                'stage': 3
            })
            
            return True
        return False
        
    def spawn_tear(self):
        """눈물 생성"""
        emotion = self.stage3_emotion
        
        x = random.randint(50, self.global_manager.get('WIDTH', 600) - 50)
        tear = {
            'x': x,
            'y': 100,
            'speed': random.uniform(3, 6),
            'size': random.randint(10, 20)
        }
        emotion['tears'].append(tear)
        
        # 엔티티 생성
        self.entity_manager.create_projectile(x, 100, 0, tear['speed'], 'tear')
        
    def _update_stage4(self, dt: float):
        """스테이지 4 업데이트 - 자기장"""
        magnetic = self.stage4_magnetic
        
        # 자기장 활성화
        if magnetic['field_active']:
            magnetic['field_timer'] -= dt
            if magnetic['field_timer'] <= 0:
                magnetic['field_active'] = False
                
            # 공을 보스쪽으로 끌어당김
            ball_rect = self.global_manager.get('BALL')
            boss_rect = self.global_manager.get('BOSS')
            
            if ball_rect and boss_rect:
                # 자기장 효과
                dx = boss_rect.centerx - ball_rect.centerx
                dy = boss_rect.centery - ball_rect.centery
                dist = math.sqrt(dx**2 + dy**2)
                
                if dist > 0:
                    pull_x = (dx / dist) * magnetic['pull_strength'] * dt * 60
                    pull_y = (dy / dist) * magnetic['pull_strength'] * dt * 60
                    
                    ball_rect.x += pull_x
                    ball_rect.y += pull_y
                    
        # 명상 모드
        if magnetic['meditation_active']:
            magnetic['meditation_timer'] -= dt
            if magnetic['meditation_timer'] <= 0:
                magnetic['meditation_active'] = False
                
    def activate_magnetic_field(self) -> bool:
        """자기장 활성화
        
        Returns:
            활성화 성공 여부
        """
        magnetic = self.stage4_magnetic
        if not magnetic['field_active']:
            magnetic['field_active'] = True
            magnetic['field_timer'] = magnetic['field_duration']
            
            # 자기장 이펙트
            boss_rect = self.global_manager.get('BOSS')
            if boss_rect:
                self.effects_manager.create_thunder_effect(boss_rect.centerx, boss_rect.centery)
                
            emit_event(EventType.BOSS_SPECIAL_ATTACK, {
                'attack': 'magnetic_field',
                'stage': 4
            })
            
            return True
        return False
        
    def _update_stage5(self, dt: float):
        """스테이지 5 업데이트 - 화염"""
        flame = self.stage5_flame
        
        # 화염구 던지기
        if flame['throwing']:
            flame['throw_timer'] -= dt
            if flame['throw_timer'] <= 0:
                flame['throwing'] = False
                self.throw_fireball()
                
        # 화염구 업데이트
        for fireball in flame['fireballs'][:]:
            fireball['x'] += fireball['vel_x'] * dt * 60
            fireball['y'] += fireball['vel_y'] * dt * 60
            
            # 화면 밖으로 나가면 제거
            if (fireball['x'] < 0 or fireball['x'] > self.global_manager.get('WIDTH', 600) or
                fireball['y'] < 0 or fireball['y'] > self.global_manager.get('HEIGHT', 750)):
                flame['fireballs'].remove(fireball)
                
        # 열기 게이지 관리
        if flame['inferno_mode']:
            flame['heat_gauge'] = max(0, flame['heat_gauge'] - 20 * dt)
            if flame['heat_gauge'] <= 0:
                flame['inferno_mode'] = False
                
    def activate_flame_throw(self) -> bool:
        """화염구 던지기 활성화
        
        Returns:
            활성화 성공 여부
        """
        flame = self.stage5_flame
        if not flame['throwing']:
            flame['throwing'] = True
            flame['throw_timer'] = 0.5
            
            emit_event(EventType.BOSS_SPECIAL_ATTACK, {
                'attack': 'flame_throw',
                'stage': 5
            })
            
            return True
        return False
        
    def throw_fireball(self):
        """화염구 투척"""
        flame = self.stage5_flame
        boss_rect = self.global_manager.get('BOSS')
        player_rect = self.global_manager.get('PLAYER')
        
        if boss_rect and player_rect:
            # 플레이어를 향해 투척
            dx = player_rect.centerx - boss_rect.centerx
            dy = player_rect.centery - boss_rect.centery
            dist = math.sqrt(dx**2 + dy**2)
            
            if dist > 0:
                vel_x = (dx / dist) * 8
                vel_y = (dy / dist) * 8
                
                fireball = {
                    'x': boss_rect.centerx,
                    'y': boss_rect.centery,
                    'vel_x': vel_x,
                    'vel_y': vel_y,
                    'size': 20
                }
                flame['fireballs'].append(fireball)
                
                # 엔티티 생성
                self.entity_manager.create_projectile(
                    boss_rect.centerx, boss_rect.centery, 
                    vel_x, vel_y, 'fireball'
                )
                
                # 폭발 이펙트
                self.effects_manager.create_explosion(
                    boss_rect.centerx, boss_rect.centery, 
                    radius=30, color=(255, 100, 0)
                )
                
    def _update_stage6(self, dt: float):
        """스테이지 6 업데이트 - 전함"""
        battleship = self.stage6_battleship
        
        # 미사일 포격
        if battleship['missile_barrage_active']:
            # 미사일 생성
            if random.random() < 0.03:  # 3% 확률
                self.spawn_missile()
                
        # 미사일 업데이트
        for missile in battleship['missiles'][:]:
            missile['y'] += missile['speed'] * dt * 60
            
            # 유도 기능
            if missile['homing']:
                player_rect = self.global_manager.get('PLAYER')
                if player_rect:
                    dx = player_rect.centerx - missile['x']
                    missile['x'] += dx * 0.02 * dt * 60
                    
            # 화면 밖으로 나가면 제거
            if missile['y'] > self.global_manager.get('HEIGHT', 750):
                battleship['missiles'].remove(missile)
                
        # 야마토 캐논 충전
        if battleship['yamato_cannon_charging']:
            battleship['yamato_charge'] = min(100, battleship['yamato_charge'] + 20 * dt)
            
            if battleship['yamato_charge'] >= 100:
                self.fire_yamato_cannon()
                battleship['yamato_cannon_charging'] = False
                battleship['yamato_charge'] = 0
                
    def activate_missile_barrage(self) -> bool:
        """미사일 포격 활성화
        
        Returns:
            활성화 성공 여부
        """
        battleship = self.stage6_battleship
        if not battleship['missile_barrage_active']:
            battleship['missile_barrage_active'] = True
            
            emit_event(EventType.BOSS_SPECIAL_ATTACK, {
                'attack': 'missile_barrage',
                'stage': 6
            })
            
            return True
        return False
        
    def spawn_missile(self):
        """미사일 생성"""
        battleship = self.stage6_battleship
        
        x = random.randint(50, self.global_manager.get('WIDTH', 600) - 50)
        missile = {
            'x': x,
            'y': 50,
            'speed': random.uniform(4, 7),
            'homing': random.random() < 0.3,  # 30% 유도 미사일
            'size': 15
        }
        battleship['missiles'].append(missile)
        
        # 엔티티 생성
        self.entity_manager.create_projectile(x, 50, 0, missile['speed'], 'missile')
        
    def charge_yamato_cannon(self) -> bool:
        """야마토 캐논 충전 시작
        
        Returns:
            충전 시작 성공 여부
        """
        battleship = self.stage6_battleship
        if not battleship['yamato_cannon_charging'] and battleship['yamato_charge'] == 0:
            battleship['yamato_cannon_charging'] = True
            
            # 충전 이펙트
            boss_rect = self.global_manager.get('BOSS')
            if boss_rect:
                self.effects_manager.create_thunder_effect(boss_rect.centerx, boss_rect.centery)
                
            emit_event(EventType.BOSS_SPECIAL_ATTACK, {
                'attack': 'yamato_charging',
                'stage': 6
            })
            
            return True
        return False
        
    def fire_yamato_cannon(self):
        """야마토 캐논 발사"""
        # 강력한 레이저 발사
        boss_rect = self.global_manager.get('BOSS')
        if boss_rect:
            # 화면 전체를 관통하는 레이저
            self.effects_manager.flash_screen(color=(255, 255, 0), duration=0.3)
            self.effects_manager.shake_screen(intensity=20, duration=0.5)
            
            # 거대 레이저 빔
            width = self.global_manager.get('WIDTH', 600)
            height = self.global_manager.get('HEIGHT', 750)
            
            # 메인 레이저
            self.entity_manager.create_projectile(
                boss_rect.centerx,
                boss_rect.centery,
                0, 20, 'yamato_beam'
            ).add_component('width', width // 3)
            
            # 보조 레이저들
            for i in range(4):  # 4발의 작은 레이저
                angle = (i - 1.5) * 15  # -22.5, -7.5, 7.5, 22.5도
                vel_x = math.sin(math.radians(angle)) * 15
                vel_y = math.cos(math.radians(angle)) * 15
                
                self.entity_manager.create_projectile(
                    boss_rect.centerx + random.randint(-30, 30),
                    boss_rect.centery,
                    vel_x, vel_y, 'laser'
                )
            
            # 충격파 효과
            self.effects_manager.create_shockwave(
                boss_rect.centerx, boss_rect.centery, 
                max_radius=width, duration=1.0
            )
                
            emit_event(EventType.BOSS_SPECIAL_ATTACK, {
                'attack': 'yamato_fire',
                'stage': 6,
                'damage': 'massive'
            })
            
    def render(self, screen: pygame.Surface):
        """스테이지 특수 효과 렌더링
        
        Args:
            screen: 화면 Surface
        """
        if self.current_stage == 1:
            self._render_stage1(screen)
        elif self.current_stage == 2:
            self._render_stage2(screen)
        elif self.current_stage == 3:
            self._render_stage3(screen)
        elif self.current_stage == 4:
            self._render_stage4(screen)
        elif self.current_stage == 5:
            self._render_stage5(screen)
        elif self.current_stage == 6:
            self._render_stage6(screen)
        elif self.current_stage == 7:
            self._render_stage7(screen)
            
    def _render_stage1(self, screen: pygame.Surface):
        """스테이지 1 렌더링 - 채찍"""
        whip = self.stage1_whip
        if whip['active']:
            boss_rect = self.global_manager.get('BOSS')
            if boss_rect:
                # 채찍 그리기
                end_x = boss_rect.centerx + whip['length'] * math.cos(math.radians(whip['angle']))
                end_y = boss_rect.centery + whip['length'] * math.sin(math.radians(whip['angle']))
                
                pygame.draw.line(screen, (255, 255, 100), 
                               (boss_rect.centerx, boss_rect.centery),
                               (end_x, end_y), 3)
                               
    def _render_stage2(self, screen: pygame.Surface):
        """스테이지 2 렌더링 - 바위"""
        speed = self.stage2_speed
        
        # 바위 그림자 렌더링
        for rock in speed['rock_walls']:
            if 'shadow_offset' in rock:
                # 그림자 그리기
                shadow_surface = pygame.Surface((60, 40), pygame.SRCALPHA)
                shadow_surface.fill((0, 0, 0, 100))
                screen.blit(shadow_surface, 
                          (rock['x'] - 30 + rock['shadow_offset'], 
                           rock['y'] + rock['shadow_offset']))
        
        # 스피드 디펜스 활성화시 잔상 효과
        if speed['defense_active']:
            boss_rect = self.global_manager.get('BOSS')
            if boss_rect:
                # 잔상 효과
                alpha = int(150 * (speed['defense_timer'] / speed['defense_duration']))
                afterimage = pygame.Surface((boss_rect.width, boss_rect.height), pygame.SRCALPHA)
                afterimage.fill((100, 100, 255, alpha))
                
                # 여러 개의 잔상
                for i in range(3):
                    offset = (i + 1) * 10
                    screen.blit(afterimage, (boss_rect.x - offset, boss_rect.y))
                    screen.blit(afterimage, (boss_rect.x + offset, boss_rect.y))
        
    def _render_stage3(self, screen: pygame.Surface):
        """스테이지 3 렌더링 - 눈물"""
        emotion = self.stage3_emotion
        
        # 감정 게이지
        if not emotion['overdrive_active']:
            gauge_width = 200
            gauge_height = 10
            x = (self.global_manager.get('WIDTH', 600) - gauge_width) // 2
            y = 30
            
            # 배경
            pygame.draw.rect(screen, (50, 50, 50), (x, y, gauge_width, gauge_height))
            
            # 게이지
            fill_width = int(gauge_width * (emotion['emotional_gauge'] / emotion['max_gauge']))
            color = (255, 100, 100) if emotion['emotional_gauge'] > 80 else (255, 200, 200)
            pygame.draw.rect(screen, color, (x, y, fill_width, gauge_height))
            
        # 눈물
        for tear in emotion['tears']:
            pygame.draw.circle(screen, (100, 100, 255), 
                             (int(tear['x']), int(tear['y'])), tear['size'])
                             
    def _render_stage4(self, screen: pygame.Surface):
        """스테이지 4 렌더링 - 자기장"""
        magnetic = self.stage4_magnetic
        if magnetic['field_active']:
            boss_rect = self.global_manager.get('BOSS')
            if boss_rect:
                # 자기장 효과
                for i in range(3):
                    radius = 100 + i * 30
                    alpha = int(100 * (1 - magnetic['field_timer'] / magnetic['field_duration']))
                    s = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                    pygame.draw.circle(s, (100, 100, 255, alpha), (radius, radius), radius, 2)
                    screen.blit(s, (boss_rect.centerx - radius, boss_rect.centery - radius))
                    
    def _render_stage5(self, screen: pygame.Surface):
        """스테이지 5 렌더링 - 화염"""
        flame = self.stage5_flame
        
        # 열기 게이지
        if flame['heat_gauge'] > 0:
            gauge_width = 200
            gauge_height = 10
            x = (self.global_manager.get('WIDTH', 600) - gauge_width) // 2
            y = 30
            
            # 배경
            pygame.draw.rect(screen, (50, 50, 50), (x, y, gauge_width, gauge_height))
            
            # 게이지
            fill_width = int(gauge_width * (flame['heat_gauge'] / flame['max_heat']))
            color = (255, 100, 0) if flame['inferno_mode'] else (255, 200, 0)
            pygame.draw.rect(screen, color, (x, y, fill_width, gauge_height))
            
        # 화염구
        for fireball in flame['fireballs']:
            pygame.draw.circle(screen, (255, 100, 0), 
                             (int(fireball['x']), int(fireball['y'])), fireball['size'])
                             
    def _render_stage6(self, screen: pygame.Surface):
        """스테이지 6 렌더링 - 전함"""
        battleship = self.stage6_battleship
        
        # 야마토 캐논 충전
        if battleship['yamato_cannon_charging']:
            boss_rect = self.global_manager.get('BOSS')
            if boss_rect:
                # 충전 효과
                charge_radius = int(50 * (battleship['yamato_charge'] / 100))
                color = (255, 255, 0, int(100 * (battleship['yamato_charge'] / 100)))
                s = pygame.Surface((charge_radius * 2, charge_radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(s, color, (charge_radius, charge_radius), charge_radius)
                screen.blit(s, (boss_rect.centerx - charge_radius, boss_rect.centery - charge_radius))
                
        # 미사일
        for missile in battleship['missiles']:
            color = (255, 0, 0) if missile['homing'] else (200, 200, 200)
            pygame.draw.circle(screen, color, 
                             (int(missile['x']), int(missile['y'])), missile['size'])
                             
    # -------------------------
    # Stage 7: 테트로미노 벽
    # -------------------------
    def _update_stage7(self, dt: float):
        """스테이지 7 업데이트 - 테트리스 벽 소환 및 충돌"""
        t7 = self.stage7_tetris
        if not t7['enabled']:
            return

        # 간이 보스 게이지 충전 (스탑워치 중 비충전 불변식 적용)
        try:
            from game_logic.stage7_tetriser import should_charge_gauge
            stop_active = bool(self.global_manager.get('stopwatch_active', False))
            stop_timer = int(self.global_manager.get('stopwatch_timer', 0) or 0)
            if should_charge_gauge(current_stage=self.current_stage,
                                   stopwatch_active=stop_active,
                                   stopwatch_timer=stop_timer):
                t7['gauge_current'] = min(t7['gauge_max'], t7['gauge_current'] + t7['recharge_per_sec'] * dt)
        except Exception:
            t7['gauge_current'] = min(t7['gauge_max'], t7['gauge_current'] + t7['recharge_per_sec'] * dt)

        # 30초마다 소환 시도
        t7['timer'] += dt
        if t7['timer'] >= t7['interval']:
            if t7['gauge_current'] >= t7['skill_cost']:
                t7['gauge_current'] -= t7['skill_cost']
                self._spawn_tetris_clusters()
                emit_event(EventType.BOSS_SPECIAL_ATTACK, {
                    'attack': 'tetromino_walls',
                    'stage': 7,
                    'cost': t7['skill_cost']
                })
            t7['timer'] = 0.0

        # 공-블록 충돌 처리
        ball_rect: pygame.Rect = self.global_manager.get('BALL')
        if not ball_rect:
            return
        ball_dx = self.global_manager.get('ball_dx', 0)
        ball_dy = self.global_manager.get('ball_dy', 0)
        prev_rect = pygame.Rect(ball_rect.x - ball_dx, ball_rect.y - ball_dy, ball_rect.width, ball_rect.height)

        # 기존 테트로미노 타격 조건과 동일: 플레이어가 마지막으로 친 공만 타격 처리
        last_hit_by = self.global_manager.get('last_hit_by', 'player')

        for blocks in (t7['left_blocks'], t7['right_blocks']):
            for b in blocks:
                if ball_rect.colliderect(b):
                    if last_hit_by != 'player':
                        continue
                    try:
                        from game_logic.stage7_tetriser import choose_reflection_axis
                        axis = choose_reflection_axis(prev_rect, ball_rect, b)
                    except Exception:
                        # 폴백: 간단 비교
                        overlap_x = min(ball_rect.right - b.left, b.right - ball_rect.left)
                        overlap_y = min(ball_rect.bottom - b.top, b.bottom - ball_rect.top)
                        axis = 'h' if overlap_x < overlap_y else 'v'

                    if axis == 'h':
                        ball_dx = -ball_dx
                        if prev_rect.centerx < b.centerx:
                            ball_rect.right = b.left
                        else:
                            ball_rect.left = b.right
                    else:
                        ball_dy = -ball_dy
                        if prev_rect.centery < b.centery:
                            ball_rect.bottom = b.top
                        else:
                            ball_rect.top = b.bottom
                    # 최소 속도 보정 및 각도 단조 완화(원본 규칙 유사)
                    min_v_speed = 6.0
                    min_h_speed = 3.0
                    if abs(ball_dy) < min_v_speed:
                        ball_dy = -min_v_speed if ball_dy < 0 else min_v_speed
                    if abs(ball_dx) < min_h_speed:
                        ball_dx = -min_h_speed if ball_dx < 0 else min_h_speed
                    ball_dx += random.uniform(-0.35, 0.35)
                    # 플레이어 타격 시 해당 블록은 파괴(제거)
                    try:
                        blocks.remove(b)
                    except ValueError:
                        pass
                    # 한 프레임에 다중 반사를 방지하기 위해 첫 충돌만 처리
                    break

        self.global_manager.set('ball_dx', ball_dx)
        self.global_manager.set('ball_dy', ball_dy)

    def _spawn_tetris_clusters(self):
        """양쪽 벽에 테트로미노 클러스터(각 10개) 소환"""
        t7 = self.stage7_tetris
        width = self.global_manager.get('WIDTH', 600)
        height = self.global_manager.get('HEIGHT', 750)

        tile = t7['tile']
        cols = t7['cols']
        grid_w = cols * tile
        rows = max(1, height // tile)

        # 기존 블록 교체 (누적 방지)
        t7['left_blocks'].clear()
        t7['right_blocks'].clear()

        left_origin = (0, height - tile)
        right_origin = (width - grid_w, height - tile)

        self._spawn_tetris_cluster_for_side(t7['left_blocks'], left_origin, cols, rows, tile)
        self._spawn_tetris_cluster_for_side(t7['right_blocks'], right_origin, cols, rows, tile)

    @staticmethod
    def _tetromino_shapes():
        return {
            'I': [(0,0),(1,0),(2,0),(3,0)],
            'O': [(0,0),(1,0),(0,1),(1,1)],
            'T': [(0,0),(1,0),(2,0),(1,1)],
            'S': [(1,0),(2,0),(0,1),(1,1)],
            'Z': [(0,0),(1,0),(1,1),(2,1)],
            'J': [(0,0),(0,1),(1,1),(2,1)],
            'L': [(2,0),(0,1),(1,1),(2,1)],
        }

    @staticmethod
    def _rotate(shape_cells, times: int):
        cells = shape_cells
        for _ in range(times % 4):
            cells = [(-y, x) for (x, y) in cells]
            min_x = min(c[0] for c in cells)
            min_y = min(c[1] for c in cells)
            cells = [(x - min_x, y - min_y) for (x, y) in cells]
        return cells

    def _spawn_tetris_cluster_for_side(self, out_list: list, origin: tuple, cols: int, rows: int, tile: int):
        grid_x, bottom_y = origin
        occupied = set()
        shapes = self._tetromino_shapes()

        # 공용 스펙의 기본 개수 사용(없으면 10)
        spec = get_tetro_wall_spawn_spec(
            width=self.global_manager.get('WIDTH', 600),
            height=self.global_manager.get('HEIGHT', 750),
        )
        pieces = int(spec.get('pieces_per_side', 10))
        for _ in range(pieces):
            base_cells = shapes[random.choice(list(shapes.keys()))]
            cells = self._rotate(base_cells, random.randint(0, 3))
            max_cx = max(c[0] for c in cells)
            max_cy = max(c[1] for c in cells)
            width_cells = max_cx + 1
            start_col = random.randint(0, max(0, cols - width_cells))

            row = 0
            while True:
                blocked = False
                for (cx, cy) in cells:
                    nx = start_col + cx
                    ny = row + cy + 1
                    if ny >= rows or (nx, ny) in occupied:
                        blocked = True
                        break
                if blocked:
                    break
                row += 1
                if row + max_cy >= rows - 1:
                    break

            for (cx, cy) in cells:
                col = start_col + cx
                r = row + cy
                occupied.add((col, r))
                x = grid_x + col * tile
                y = bottom_y - r * tile - tile
                out_list.append(pygame.Rect(x, y, tile, tile))

    def _render_stage7(self, screen: pygame.Surface):
        t7 = self.stage7_tetris
        if not t7['enabled']:
            return

        # 블록 렌더링(반투명 채움 + 외곽선) - 가시성 강화
        colors = [(90, 180, 255, 220), (90, 220, 180, 220), (255, 200, 90, 220), (220, 120, 255, 220), (255, 120, 120, 220)]
        for idx, blocks in enumerate((t7['left_blocks'], t7['right_blocks'])):
            color = colors[idx % len(colors)]
            for r in blocks:
                key = (r.width, r.height)
                s = self._t7_cache_cell.get(key)
                if s is None:
                    s = pygame.Surface(key, pygame.SRCALPHA)
                    self._t7_cache_cell[key] = s
                else:
                    s.fill((0, 0, 0, 0))
                s.fill(color)
                screen.blit(s, r.topleft)
                pygame.draw.rect(screen, (30, 30, 30), r, 2)

        # 간이 보스 스킬 게이지 표시(상단 중앙)
        gauge = t7['gauge_current']
        gmax = t7['gauge_max']
        bar_w, bar_h = 180, 10
        x = (self.global_manager.get('WIDTH', 600) - bar_w) // 2
        y = 48
        pygame.draw.rect(screen, (50, 50, 50), (x, y, bar_w, bar_h))
        fill = int(bar_w * max(0.0, min(1.0, gauge / gmax)))
        pygame.draw.rect(screen, (255, 120, 120), (x, y, fill, bar_h))
        pygame.draw.rect(screen, (255, 255, 255), (x, y, bar_w, bar_h), 2)
        need_x = x + int(bar_w * (t7['skill_cost'] / gmax))
        pygame.draw.line(screen, (255, 255, 255), (need_x, y - 2), (need_x, y + bar_h + 2), 1)

        # 디버그 HUD (옵션)
        if self.stage7_debug.get('HUD', False):
            self._render_stage7_hud(screen)

    def _render_stage7_hud(self, screen: pygame.Surface):
        t7 = self.stage7_tetris
        try:
            if self._hud_font is None:
                self._hud_font = pygame.font.Font(None, 16)
        except Exception:
            return
        # 다음 스폰 ETA 계산
        timer = float(t7.get('timer', 0.0))
        interval = float(t7.get('interval', 30.0))
        eta = max(0.0, interval - timer)
        left_cnt = len(t7.get('left_blocks', []))
        right_cnt = len(t7.get('right_blocks', []))
        gauge = int(t7.get('gauge_current', 0))
        gmax = int(t7.get('gauge_max', 200))
        cost = int(t7.get('skill_cost', 50))
        lines = [
            "Stage7 HUD",
            f"Gauge {gauge}/{gmax} (cost {cost})",
            f"Timer {timer:0.1f}/{interval:0.1f} (ETA {eta:0.1f}s)",
            f"Walls L{left_cnt}/R{right_cnt}",
        ]
        pad = 6
        # 크기 산정
        w = 0
        h = pad
        renders = []
        for s in lines:
            r = self._hud_font.render(s, True, (220, 235, 255))
            renders.append(r)
            w = max(w, r.get_width())
            h += r.get_height() + 2
        w += pad * 2
        h += pad - 2
        bg = pygame.Surface((w, h), pygame.SRCALPHA)
        bg.fill((10, 18, 30, 150))
        pygame.draw.rect(bg, (40, 80, 160, 220), bg.get_rect(), 1)
        screen.blit(bg, (8, 52))
        cy = 52 + pad
        for r in renders:
            screen.blit(r, (8 + pad, cy))
            cy += r.get_height() + 2

    # 외부에서 디버그 토글 용이하도록 제공
    def set_stage7_debug(self, *, hud: bool | None = None, gauge: bool | None = None):
        if hud is not None:
            self.stage7_debug['HUD'] = bool(hud)
        if gauge is not None:
            self.stage7_debug['GAUGE'] = bool(gauge)

    def get_stats(self) -> Dict:
        """스테이지 특수 기능 상태 반환"""
        stats = {
            'stage': self.current_stage
        }
        
        if self.current_stage == 1:
            stats['whip_active'] = self.stage1_whip['active']
            stats['whip_cooldown'] = round(self.stage1_whip['cooldown'], 1)
        elif self.current_stage == 2:
            stats['speed_defense'] = self.stage2_speed['defense_active']
            stats['rock_count'] = len(self.stage2_speed['rock_walls'])
        elif self.current_stage == 3:
            stats['emotional_gauge'] = self.stage3_emotion['emotional_gauge']
            stats['overdrive'] = self.stage3_emotion['overdrive_active']
            stats['tears'] = len(self.stage3_emotion['tears'])
        elif self.current_stage == 4:
            stats['magnetic_field'] = self.stage4_magnetic['field_active']
            stats['meditation'] = self.stage4_magnetic['meditation_active']
        elif self.current_stage == 5:
            stats['heat_gauge'] = self.stage5_flame['heat_gauge']
            stats['fireballs'] = len(self.stage5_flame['fireballs'])
            stats['inferno'] = self.stage5_flame['inferno_mode']
        elif self.current_stage == 6:
            stats['missiles'] = len(self.stage6_battleship['missiles'])
            stats['yamato_charge'] = self.stage6_battleship['yamato_charge']
            stats['shield_hp'] = self.stage6_battleship['shield_hp']
            
        return stats


# 싱글톤 인스턴스
_stage_features = None

def get_stage_features() -> StageFeatures:
    """스테이지 특수 기능 싱글톤 반환"""
    global _stage_features
    if _stage_features is None:
        _stage_features = StageFeatures()
    return _stage_features
