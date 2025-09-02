"""
Effects Manager - 이펙트 시스템
시각적 효과, 파티클, 애니메이션 관리
"""

import pygame
import random
import math
from typing import List, Dict, Tuple, Optional
from core.global_manager import GlobalManager
from core.events import EventType, EventManager
from entities.entity import get_entity_manager


class Particle:
    """파티클 클래스"""
    
    def __init__(self, x: float, y: float, vel_x: float, vel_y: float, 
                 color: Tuple[int, int, int], lifetime: float, size: int = 3,
                 particle_type: str = 'normal'):
        self.x = x
        self.y = y
        self.vel_x = vel_x
        self.vel_y = vel_y
        self.color = color
        self.lifetime = lifetime
        self.max_lifetime = lifetime
        self.size = size
        self.gravity = 0.5
        self.particle_type = particle_type
        
        # 특수 파티클 속성
        self.rotation = 0
        self.rotation_speed = 0
        self.scale = 1.0
        self.fade_in = False
        self.glow = False
        self.trail = []
        
    def update(self, dt: float):
        """파티클 업데이트"""
        # 이전 위치 저장 (트레일용)
        if self.particle_type in ['comet', 'missile', 'laser']:
            self.trail.append((self.x, self.y, self.lifetime / self.max_lifetime))
            if len(self.trail) > 10:
                self.trail.pop(0)
        
        self.x += self.vel_x * dt * 60
        self.y += self.vel_y * dt * 60
        self.vel_y += self.gravity * dt * 60
        self.lifetime -= dt
        
        # 회전 업데이트
        if self.rotation_speed != 0:
            self.rotation += self.rotation_speed * dt * 60
            
        # 특수 움직임 패턴
        if self.particle_type == 'spiral':
            # 나선형 움직임
            angle = self.rotation * 0.1
            self.vel_x = math.cos(angle) * 3
            self.vel_y = math.sin(angle) * 3
        elif self.particle_type == 'wave':
            # 파동 움직임
            self.vel_x = math.sin(self.lifetime * 10) * 2
        elif self.particle_type == 'homing':
            # 유도 움직임 (타겟이 있다면)
            pass
        
    def render(self, screen: pygame.Surface):
        """파티클 렌더링"""
        if self.lifetime <= 0:
            return
            
        # 수명에 따른 알파값 계산
        life_ratio = self.lifetime / self.max_lifetime
        if self.fade_in and life_ratio > 0.8:
            alpha = int(255 * (1 - life_ratio) * 5)  # 페이드 인
        else:
            alpha = int(255 * life_ratio)
            
        # 트레일 그리기
        if self.trail:
            for i, (tx, ty, t_alpha) in enumerate(self.trail):
                trail_size = self.size * (i / len(self.trail)) * 0.7
                trail_alpha = int(alpha * t_alpha * (i / len(self.trail)))
                if trail_alpha > 0 and trail_size > 0:
                    s = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(s, (*self.color, trail_alpha), 
                                     (trail_size, trail_size), trail_size)
                    screen.blit(s, (tx - trail_size, ty - trail_size))
        
        # 글로우 효과
        if self.glow:
            glow_size = self.size * 2
            glow_alpha = alpha // 4
            s = pygame.Surface((glow_size * 4, glow_size * 4), pygame.SRCALPHA)
            pygame.draw.circle(s, (*self.color, glow_alpha), 
                             (glow_size * 2, glow_size * 2), glow_size * 2)
            screen.blit(s, (self.x - glow_size * 2, self.y - glow_size * 2))
        
        # 메인 파티클 그리기
        actual_size = self.size * self.scale
        particle_color = (*self.color, alpha)
        
        if self.particle_type == 'square':
            s = pygame.Surface((actual_size * 2, actual_size * 2), pygame.SRCALPHA)
            pygame.draw.rect(s, particle_color, 
                           (0, 0, actual_size * 2, actual_size * 2))
            if self.rotation != 0:
                s = pygame.transform.rotate(s, self.rotation)
        elif self.particle_type == 'star':
            s = pygame.Surface((actual_size * 2, actual_size * 2), pygame.SRCALPHA)
            # 별 모양 그리기
            points = []
            for i in range(10):
                angle = (i * math.pi / 5) + self.rotation
                if i % 2 == 0:
                    r = actual_size
                else:
                    r = actual_size * 0.5
                x = actual_size + r * math.cos(angle)
                y = actual_size + r * math.sin(angle)
                points.append((x, y))
            if len(points) > 2:
                pygame.draw.polygon(s, particle_color, points)
        else:
            # 기본 원형
            s = pygame.Surface((actual_size * 2, actual_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(s, particle_color, (actual_size, actual_size), actual_size)
            
        screen.blit(s, (self.x - actual_size, self.y - actual_size))


class EffectsManager:
    """이펙트 관리자"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        self.event_manager = EventManager.get_instance()
        self.entity_manager = get_entity_manager()
        
        # 파티클 리스트
        self.particles = []
        self.max_particles = 500  # 성능 제한
        
        # 이펙트 애니메이션
        self.animations = []
        
        # 화면 효과
        self.screen_effects = {
            'shake': {
                'active': False,
                'intensity': 0,
                'duration': 0,
                'timer': 0,
                'offset_x': 0,
                'offset_y': 0
            },
            'flash': {
                'active': False,
                'color': (255, 255, 255),
                'alpha': 0,
                'duration': 0,
                'timer': 0
            },
            'fade': {
                'active': False,
                'alpha': 0,
                'target_alpha': 0,
                'speed': 1.0,
                'color': (0, 0, 0)
            },
            'chromatic': {  # 색수차 효과
                'active': False,
                'intensity': 0,
                'duration': 0,
                'timer': 0
            },
            'blur': {  # 블러 효과
                'active': False,
                'intensity': 0,
                'duration': 0,
                'timer': 0
            }
        }
        
        # 잔상 효과
        self.afterimages = []
        
        # 충격파 리스트
        self.shockwaves = []
        
        # 지속 이펙트
        self.persistent_effects = {}
        
        # 이벤트 핸들러 등록
        self.setup_event_handlers()
        
    def setup_event_handlers(self):
        """이벤트 핸들러 설정"""
        self.event_manager.subscribe(EventType.COLLISION, self.on_collision)
        self.event_manager.subscribe(EventType.SKILL_ACTIVATED, self.on_skill_activated)
        self.event_manager.subscribe(EventType.ITEM_COLLECTED, self.on_item_collected)
        self.event_manager.subscribe(EventType.BOSS_SPECIAL_ATTACK, self.on_boss_special)
        self.event_manager.subscribe(EventType.DASH_STARTED, self.on_dash_start)
        self.event_manager.subscribe(EventType.EXPLOSION, self.on_explosion)
        
    def on_collision(self, event):
        """충돌 이벤트 처리"""
        collision_type = event.data.get('type')
        position = event.data.get('position')
        
        if collision_type == 'ball_paddle' and position:
            # 충돌 스파크 효과
            self.create_spark_burst(position[0], position[1])
            # 작은 화면 흔들림
            self.shake_screen(intensity=3, duration=0.1)
            
    def on_skill_activated(self, event):
        """스킬 활성화 이벤트 처리"""
        skill_name = event.data.get('skill_name')
        position = event.data.get('position')
        
        if skill_name == 'thunder' and position:
            self.create_thunder_effect(position[0], position[1])
        elif skill_name == 'fireball' and position:
            self.create_explosion(position[0], position[1], radius=50)
            
    def on_item_collected(self, event):
        """아이템 수집 이벤트 처리"""
        position = event.data.get('position')
        if position:
            self.create_collect_effect(position[0], position[1])
            
    def create_explosion(self, x: float, y: float, radius: float = 30, 
                        color: Tuple[int, int, int] = (255, 100, 0)):
        """폭발 효과 생성
        
        Args:
            x: X 좌표
            y: Y 좌표
            radius: 폭발 반경
            color: 폭발 색상
        """
        # 엔티티 시스템에 폭발 이펙트 생성
        self.entity_manager.create_effect(x, y, 'explosion', duration=0.5)
        
        # 충격파 링
        self.create_shockwave(x, y, radius * 2, duration=0.3)
        
        # 다양한 파티클 생성
        particle_count = int(radius * 2)
        
        # 불꽃 파티클
        for _ in range(particle_count):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 8)
            vel_x = math.cos(angle) * speed
            vel_y = math.sin(angle) * speed
            
            particle_color = (
                min(255, color[0] + random.randint(-50, 50)),
                min(255, color[1] + random.randint(-50, 50)),
                min(255, color[2] + random.randint(-50, 50))
            )
            
            particle = Particle(x, y, vel_x, vel_y, particle_color, 
                              lifetime=random.uniform(0.3, 0.8),
                              particle_type='normal')
            particle.glow = True
            self.particles.append(particle)
            
        # 불씨 파티클 (작고 오래 지속)
        for _ in range(particle_count // 2):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(1, 3)
            vel_x = math.cos(angle) * speed
            vel_y = math.sin(angle) * speed
            
            ember = Particle(x, y, vel_x, vel_y, (255, 200, 100),
                           lifetime=random.uniform(0.8, 1.5),
                           size=1, particle_type='normal')
            ember.gravity = 0.2
            self.particles.append(ember)
            
        # 연기 파티클
        for _ in range(particle_count // 3):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(0.5, 2)
            vel_x = math.cos(angle) * speed
            vel_y = math.sin(angle) * speed - 1  # 위로 올라감
            
            smoke = Particle(x, y, vel_x, vel_y, (100, 100, 100),
                           lifetime=random.uniform(1.0, 2.0),
                           size=random.randint(5, 10),
                           particle_type='normal')
            smoke.gravity = -0.1  # 위로 뜸
            smoke.fade_in = True
            self.particles.append(smoke)
            
    def create_spark_burst(self, x: float, y: float, count: int = 10):
        """스파크 버스트 효과
        
        Args:
            x: X 좌표
            y: Y 좌표
            count: 스파크 개수
        """
        for _ in range(count):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(1, 5)
            vel_x = math.cos(angle) * speed
            vel_y = math.sin(angle) * speed
            
            color = (255, 255, random.randint(100, 255))  # 노란색 계열
            particle = Particle(x, y, vel_x, vel_y, color, 
                              lifetime=random.uniform(0.2, 0.4), size=2)
            self.particles.append(particle)
            
    def create_collect_effect(self, x: float, y: float):
        """아이템 수집 효과
        
        Args:
            x: X 좌표
            y: Y 좌표
        """
        # 원형으로 퍼지는 파티클
        for i in range(12):
            angle = (i / 12) * math.pi * 2
            vel_x = math.cos(angle) * 3
            vel_y = math.sin(angle) * 3
            
            color = (100, 255, 100)  # 초록색
            particle = Particle(x, y, vel_x, vel_y, color, lifetime=0.5)
            particle.gravity = 0  # 중력 제거
            self.particles.append(particle)
            
    def create_thunder_effect(self, x: float, y: float):
        """번개 효과
        
        Args:
            x: X 좌표
            y: Y 좌표
        """
        # 번개 엔티티 생성
        self.entity_manager.create_effect(x, y, 'thunder', duration=0.3)
        
        # 화면 플래시
        self.flash_screen(color=(200, 200, 255), duration=0.1)
        
        # 번개 줄기 (브랜치)
        branches = 3
        for branch in range(branches):
            start_x = x
            start_y = y
            branch_angle = (branch - 1) * 30  # -30, 0, 30도
            
            segments = 5
            for seg in range(segments):
                end_x = start_x + math.cos(math.radians(branch_angle)) * 30
                end_y = start_y + 30  # 아래로
                
                # 번개 세그먼트 파티클
                for i in range(5):
                    px = start_x + (end_x - start_x) * (i / 5)
                    py = start_y + (end_y - start_y) * (i / 5)
                    
                    lightning = Particle(px + random.randint(-5, 5), 
                                       py + random.randint(-5, 5),
                                       0, 0, (200, 200, 255),
                                       lifetime=0.2 + seg * 0.05,
                                       size=3 - seg // 2,
                                       particle_type='normal')
                    lightning.gravity = 0
                    lightning.glow = True
                    self.particles.append(lightning)
                    
                start_x = end_x
                start_y = end_y
                branch_angle += random.randint(-20, 20)  # 랜덤 방향
        
        # 전기 스파크
        for _ in range(30):
            offset_x = random.randint(-50, 50)
            offset_y = random.randint(-50, 50)
            color = (150 + random.randint(0, 105), 200 + random.randint(0, 55), 255)
            
            spark = Particle(x + offset_x, y + offset_y, 
                           random.uniform(-2, 2), random.uniform(-2, 2),
                           color, lifetime=0.4, size=1,
                           particle_type='star')
            spark.gravity = 0
            spark.rotation_speed = random.uniform(-10, 10)
            self.particles.append(spark)
            
    def create_dash_afterimage(self, image: pygame.Surface, x: float, y: float, 
                               alpha: int = 100):
        """대시 잔상 효과
        
        Args:
            image: 잔상 이미지
            x: X 좌표
            y: Y 좌표
            alpha: 투명도
        """
        afterimage = {
            'image': image.copy(),
            'x': x,
            'y': y,
            'alpha': alpha,
            'lifetime': 0.3
        }
        self.afterimages.append(afterimage)
        
        # 최대 5개 유지
        if len(self.afterimages) > 5:
            self.afterimages.pop(0)
            
    def shake_screen(self, intensity: float = 10, duration: float = 0.5):
        """화면 흔들림 효과
        
        Args:
            intensity: 흔들림 강도
            duration: 지속 시간
        """
        self.screen_effects['shake'].update({
            'active': True,
            'intensity': intensity,
            'duration': duration,
            'timer': 0
        })
        
    def flash_screen(self, color: Tuple[int, int, int] = (255, 255, 255), 
                    duration: float = 0.2):
        """화면 플래시 효과
        
        Args:
            color: 플래시 색상
            duration: 지속 시간
        """
        self.screen_effects['flash'].update({
            'active': True,
            'color': color,
            'alpha': 255,
            'duration': duration,
            'timer': 0
        })
        
    def fade_screen(self, target_alpha: int, speed: float = 1.0, 
                   color: Tuple[int, int, int] = (0, 0, 0)):
        """화면 페이드 효과
        
        Args:
            target_alpha: 목표 알파값
            speed: 페이드 속도
            color: 페이드 색상
        """
        self.screen_effects['fade'].update({
            'active': True,
            'target_alpha': target_alpha,
            'speed': speed,
            'color': color
        })
        
    def update(self, dt: float):
        """이펙트 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 파티클 업데이트 (성능 제한)
        self.particles = [p for p in self.particles if p.lifetime > 0]
        if len(self.particles) > self.max_particles:
            # 오래된 파티클부터 제거
            self.particles.sort(key=lambda p: p.lifetime)
            self.particles = self.particles[-self.max_particles:]
            
        for particle in self.particles:
            particle.update(dt)
            
        # 잔상 업데이트
        new_afterimages = []
        for afterimage in self.afterimages:
            afterimage['lifetime'] -= dt
            afterimage['alpha'] = int(255 * (afterimage['lifetime'] / 0.3))
            if afterimage['lifetime'] > 0 and afterimage['alpha'] > 0:
                new_afterimages.append(afterimage)
        self.afterimages = new_afterimages
        
        # 충격파 업데이트
        new_shockwaves = []
        for shockwave in self.shockwaves:
            shockwave['timer'] += dt
            if shockwave['timer'] < shockwave['duration']:
                progress = shockwave['timer'] / shockwave['duration']
                shockwave['current_radius'] = shockwave['max_radius'] * progress
                shockwave['alpha'] = int(255 * (1 - progress))
                new_shockwaves.append(shockwave)
        self.shockwaves = new_shockwaves
        
        # 화면 효과 업데이트
        self._update_screen_effects(dt)
        
    def _update_screen_effects(self, dt: float):
        """화면 효과 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 화면 흔들림
        shake = self.screen_effects['shake']
        if shake['active']:
            shake['timer'] += dt
            if shake['timer'] >= shake['duration']:
                shake['active'] = False
                shake['offset_x'] = 0
                shake['offset_y'] = 0
            else:
                # 흔들림 오프셋 계산
                progress = shake['timer'] / shake['duration']
                current_intensity = shake['intensity'] * (1 - progress)
                shake['offset_x'] = random.uniform(-current_intensity, current_intensity)
                shake['offset_y'] = random.uniform(-current_intensity, current_intensity)
                
        # 화면 플래시
        flash = self.screen_effects['flash']
        if flash['active']:
            flash['timer'] += dt
            if flash['timer'] >= flash['duration']:
                flash['active'] = False
                flash['alpha'] = 0
            else:
                # 알파값 감소
                progress = flash['timer'] / flash['duration']
                flash['alpha'] = int(255 * (1 - progress))
                
        # 화면 페이드
        fade = self.screen_effects['fade']
        if fade['active']:
            # 알파값 보간
            alpha_diff = fade['target_alpha'] - fade['alpha']
            if abs(alpha_diff) < 1:
                fade['alpha'] = fade['target_alpha']
                if fade['target_alpha'] == 0:
                    fade['active'] = False
            else:
                fade['alpha'] += alpha_diff * fade['speed'] * dt
                
    def render(self, screen: pygame.Surface):
        """이펙트 렌더링
        
        Args:
            screen: 화면 Surface
        """
        # 잔상 그리기
        for afterimage in self.afterimages:
            img = afterimage['image'].copy()
            img.set_alpha(afterimage['alpha'])
            screen.blit(img, (afterimage['x'], afterimage['y']))
            
        # 충격파 그리기
        for shockwave in self.shockwaves:
            if shockwave['alpha'] > 0:
                s = pygame.Surface((shockwave['current_radius'] * 2, 
                                  shockwave['current_radius'] * 2), pygame.SRCALPHA)
                pygame.draw.circle(s, (*shockwave['color'], shockwave['alpha']),
                                 (shockwave['current_radius'], shockwave['current_radius']),
                                 shockwave['current_radius'], 3)
                screen.blit(s, (shockwave['x'] - shockwave['current_radius'],
                              shockwave['y'] - shockwave['current_radius']))
        
        # 파티클 그리기 (Z-order 정렬)
        sorted_particles = sorted(self.particles, key=lambda p: p.y)
        for particle in sorted_particles:
            particle.render(screen)
            
    def render_screen_effects(self, screen: pygame.Surface):
        """화면 효과 렌더링 (최상위 레이어)
        
        Args:
            screen: 화면 Surface
        """
        # 화면 플래시
        flash = self.screen_effects['flash']
        if flash['active'] and flash['alpha'] > 0:
            flash_surface = pygame.Surface(screen.get_size(), pygame.SRCALPHA)
            flash_surface.fill((*flash['color'], flash['alpha']))
            screen.blit(flash_surface, (0, 0))
            
        # 화면 페이드
        fade = self.screen_effects['fade']
        if fade['active'] and fade['alpha'] > 0:
            fade_surface = pygame.Surface(screen.get_size(), pygame.SRCALPHA)
            fade_surface.fill((*fade['color'], int(fade['alpha'])))
            screen.blit(fade_surface, (0, 0))
            
    def get_screen_shake_offset(self) -> Tuple[float, float]:
        """화면 흔들림 오프셋 반환
        
        Returns:
            (offset_x, offset_y) 튜플
        """
        shake = self.screen_effects['shake']
        if shake['active']:
            return (shake['offset_x'], shake['offset_y'])
        return (0, 0)
        
    def clear(self):
        """모든 이펙트 제거"""
        self.particles.clear()
        self.afterimages.clear()
        self.animations.clear()
        
        # 화면 효과 리셋
        for effect in self.screen_effects.values():
            effect['active'] = False
            
    def create_shockwave(self, x: float, y: float, max_radius: float = 100,
                        duration: float = 0.5, color: Tuple[int, int, int] = (255, 255, 255)):
        """충격파 효과 생성
        
        Args:
            x: X 좌표
            y: Y 좌표
            max_radius: 최대 반경
            duration: 지속 시간
            color: 색상
        """
        shockwave = {
            'x': x,
            'y': y,
            'max_radius': max_radius,
            'current_radius': 0,
            'duration': duration,
            'timer': 0,
            'color': color,
            'alpha': 255
        }
        self.shockwaves.append(shockwave)
        
    def create_hit_effect(self, x: float, y: float, effect_type: str = 'normal'):
        """타격 효과 생성
        
        Args:
            x: X 좌표
            y: Y 좌표  
            effect_type: 효과 타입
        """
        if effect_type == 'critical':
            # 크리티컬 히트
            self.create_spark_burst(x, y, count=20)
            self.shake_screen(intensity=5, duration=0.2)
            self.flash_screen(color=(255, 100, 100), duration=0.1)
        elif effect_type == 'electric':
            # 전기 타격
            self.create_thunder_effect(x, y)
        elif effect_type == 'fire':
            # 화염 타격
            self.create_explosion(x, y, radius=20, color=(255, 100, 0))
        else:
            # 일반 타격
            self.create_spark_burst(x, y, count=10)
            
    def create_dust_cloud(self, x: float, y: float, radius: float = 30):
        """먼지 구름 효과
        
        Args:
            x: X 좌표
            y: Y 좌표
            radius: 반경
        """
        for _ in range(20):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(0, radius)
            px = x + math.cos(angle) * dist
            py = y + math.sin(angle) * dist
            
            dust = Particle(px, py, 
                          random.uniform(-1, 1), random.uniform(-2, 0),
                          (150, 130, 100), lifetime=random.uniform(0.5, 1.0),
                          size=random.randint(3, 8), particle_type='normal')
            dust.gravity = -0.05
            dust.fade_in = True
            self.particles.append(dust)
            
    def on_boss_special(self, event):
        """보스 특수 공격 이벤트 처리"""
        attack = event.data.get('attack')
        stage = event.data.get('stage')
        
        if attack == 'whip':
            # 채찍 효과
            boss_rect = self.global_manager.get('BOSS')
            if boss_rect:
                for i in range(10):
                    angle = i * 36
                    x = boss_rect.centerx + math.cos(math.radians(angle)) * 100
                    y = boss_rect.centery + math.sin(math.radians(angle)) * 100
                    self.create_spark_burst(x, y, count=5)
                    
        elif attack == 'yamato_fire':
            # 야마토 캐논
            self.shake_screen(intensity=20, duration=1.0)
            self.flash_screen(color=(255, 255, 0), duration=0.5)
            # 색수차 효과 추가
            self.screen_effects['chromatic']['active'] = True
            self.screen_effects['chromatic']['intensity'] = 10
            self.screen_effects['chromatic']['duration'] = 0.5
            self.screen_effects['chromatic']['timer'] = 0
            
    def on_dash_start(self, event):
        """대시 시작 이벤트 처리"""
        position = event.data.get('position')
        if position:
            # 대시 이펙트
            for _ in range(10):
                vel_x = random.uniform(-3, 3)
                vel_y = random.uniform(-3, 3)
                particle = Particle(position[0], position[1], vel_x, vel_y,
                                  (100, 200, 255), lifetime=0.3, size=2,
                                  particle_type='star')
                particle.rotation_speed = 10
                self.particles.append(particle)
                
    def on_explosion(self, event):
        """폭발 이벤트 처리"""
        position = event.data.get('position')
        radius = event.data.get('radius', 30)
        if position:
            self.create_explosion(position[0], position[1], radius)
            
    def get_stats(self) -> Dict:
        """이펙트 통계 반환"""
        return {
            'particles': len(self.particles),
            'afterimages': len(self.afterimages),
            'animations': len(self.animations),
            'shockwaves': len(self.shockwaves),
            'screen_shake': self.screen_effects['shake']['active'],
            'screen_flash': self.screen_effects['flash']['active'],
            'screen_fade': self.screen_effects['fade']['active'],
            'max_particles': self.max_particles
        }


# 싱글톤 인스턴스
_effects_manager = None

def get_effects_manager() -> EffectsManager:
    """이펙트 매니저 싱글톤 반환"""
    global _effects_manager
    if _effects_manager is None:
        _effects_manager = EffectsManager()
    return _effects_manager