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


class StageFeatures:
    """스테이지별 특수 기능 관리"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        self.effects_manager = get_effects_manager()
        self.entity_manager = get_entity_manager()
        
        self.current_stage = 1
        
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
        
    def set_stage(self, stage: int):
        """스테이지 설정
        
        Args:
            stage: 스테이지 번호
        """
        self.current_stage = stage
        self.reset_all_features()
        
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