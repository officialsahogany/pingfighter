"""
Item Entity - 아이템 엔티티
게임 내 파워업 아이템의 동작과 렌더링을 관리
"""

import pygame
import math
import random
from typing import Tuple, Optional, Dict, Any
from entities.entity import Entity
from core.events import EventType, emit_event


class ItemEntity(Entity):
    """아이템 엔티티 클래스"""
    
    # 아이템 타입 정의
    ITEM_TYPES = {
        'speedboost': {
            'color': (255, 255, 0),
            'icon': 'lightning',
            'duration': 5.0,
            'description': 'Speed Boost'
        },
        'widePaddle': {
            'color': (0, 255, 255),
            'icon': 'expand',
            'duration': 7.0,
            'description': 'Wide Paddle'
        },
        'multiball': {
            'color': (255, 0, 255),
            'icon': 'triple',
            'duration': 0,
            'description': 'Multi Ball'
        },
        'shield': {
            'color': (100, 100, 255),
            'icon': 'shield',
            'duration': 10.0,
            'description': 'Shield'
        },
        'powershot': {
            'color': (255, 100, 0),
            'icon': 'power',
            'duration': 3.0,
            'description': 'Power Shot'
        },
        'slowmotion': {
            'color': (150, 150, 150),
            'icon': 'clock',
            'duration': 5.0,
            'description': 'Slow Motion'
        },
        'magnetic': {
            'color': (200, 50, 200),
            'icon': 'magnet',
            'duration': 8.0,
            'description': 'Magnetic Paddle'
        },
        'ghost': {
            'color': (200, 200, 200),
            'icon': 'ghost',
            'duration': 4.0,
            'description': 'Ghost Ball'
        }
    }
    
    def __init__(self, x: float, y: float, item_type: str = None):
        """아이템 초기화
        
        Args:
            x: 초기 X 좌표
            y: 초기 Y 좌표
            item_type: 아이템 타입 (None이면 랜덤)
        """
        super().__init__(x, y)
        
        # 아이템 타입 설정
        if item_type and item_type in self.ITEM_TYPES:
            self.item_type = item_type
        else:
            self.item_type = random.choice(list(self.ITEM_TYPES.keys()))
            
        self.item_data = self.ITEM_TYPES[self.item_type]
        
        # 아이템 속성
        self.radius = 15
        self.size = pygame.Vector2(self.radius * 2, self.radius * 2)
        
        # 이동 속성
        self.fall_speed = 2.0
        self.float_amplitude = 10
        self.float_frequency = 2.0
        self.float_timer = random.uniform(0, math.pi * 2)
        
        # 회전 애니메이션
        self.rotation = 0
        self.rotation_speed = 90  # 도/초
        
        # 수명
        self.lifetime = 10.0  # 10초 후 사라짐
        self.age = 0
        self.blink_start_time = 7.0  # 7초부터 깜빡임 시작
        
        # 시각 효과
        self.glow_intensity = 0
        self.glow_timer = 0
        self.pulse_timer = 0
        
        # 파티클 효과
        self.particles = []
        self.particle_spawn_timer = 0
        self.particle_spawn_rate = 0.1
        
        # 수집 상태
        self.is_collected = False
        self.collect_animation_timer = 0
        
        # 태그 설정
        self.add_tag("item")
        self.add_tag(f"item_{self.item_type}")
        self.add_to_group("items")
        
        # 초기 속도 설정
        self.velocity.y = self.fall_speed
        
        # 아이템 생성 이벤트
        emit_event(EventType.ITEM_SPAWNED, {
            'item_type': self.item_type,
            'position': (x, y)
        })
        
    def update(self, dt: float):
        """아이템 업데이트
        
        Args:
            dt: 델타 타임
        """
        if not self.active:
            return
            
        # 수집 애니메이션 중이면 특별 처리
        if self.is_collected:
            self.update_collect_animation(dt)
            return
            
        # 나이 증가
        self.age += dt
        
        # 수명 체크
        if self.age >= self.lifetime:
            self.destroy()
            return
            
        # 떨어지는 움직임
        self.update_movement(dt)
        
        # 회전 애니메이션
        self.rotation += self.rotation_speed * dt
        
        # 시각 효과 업데이트
        self.update_visual_effects(dt)
        
        # 파티클 업데이트
        self.update_particles(dt)
        
        # 깜빡임 효과 (수명이 얼마 안 남았을 때)
        if self.age >= self.blink_start_time:
            blink_frequency = 10 * (1 - (self.lifetime - self.age) / (self.lifetime - self.blink_start_time))
            self.visible = math.sin(self.age * blink_frequency * math.pi) > 0
            
        # Rect 업데이트
        self.update_rect()
        
    def update_movement(self, dt: float):
        """이동 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 떨어지기
        self.position.y += self.velocity.y
        
        # 좌우 떠다니기 효과
        self.float_timer += dt * self.float_frequency
        float_offset = math.sin(self.float_timer) * self.float_amplitude * dt
        self.position.x += float_offset
        
        # 화면 경계 체크
        if self.position.x < self.radius:
            self.position.x = self.radius
        elif self.position.x > 600 - self.radius:
            self.position.x = 600 - self.radius
            
        # 화면 아래로 나가면 제거
        if self.position.y > 750 + self.radius:
            self.destroy()
            
    def update_visual_effects(self, dt: float):
        """시각 효과 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 펄스 효과
        self.pulse_timer += dt * 3
        self.glow_intensity = 0.5 + 0.5 * math.sin(self.pulse_timer)
        
        # 글로우 타이머
        self.glow_timer += dt
        
    def update_particles(self, dt: float):
        """파티클 효과 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 파티클 생성
        self.particle_spawn_timer += dt
        if self.particle_spawn_timer >= self.particle_spawn_rate:
            self.particle_spawn_timer = 0
            self.spawn_particle()
            
        # 파티클 업데이트
        for particle in self.particles:
            particle['pos'][0] += particle['vel'][0] * dt
            particle['pos'][1] += particle['vel'][1] * dt
            particle['life'] -= dt
            particle['alpha'] = int(255 * (particle['life'] / particle['max_life']))
            
        # 죽은 파티클 제거
        self.particles = [p for p in self.particles if p['life'] > 0]
        
    def spawn_particle(self):
        """파티클 생성"""
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(20, 50)
        life = random.uniform(0.5, 1.0)
        
        particle = {
            'pos': [self.position.x, self.position.y],
            'vel': [math.cos(angle) * speed, math.sin(angle) * speed],
            'life': life,
            'max_life': life,
            'alpha': 255,
            'color': self.item_data['color'],
            'size': random.uniform(2, 4)
        }
        
        self.particles.append(particle)
        
    def update_collect_animation(self, dt: float):
        """수집 애니메이션 업데이트
        
        Args:
            dt: 델타 타임
        """
        self.collect_animation_timer += dt
        
        # 수집 애니메이션 (확대 후 사라짐)
        if self.collect_animation_timer < 0.3:
            scale = 1.0 + self.collect_animation_timer * 3
            self.radius = 15 * scale
            self.glow_intensity = 1.0
            
            # 파티클 대량 생성
            for _ in range(3):
                self.spawn_particle()
        else:
            self.destroy()
            
    def render(self, screen: pygame.Surface, camera_offset: Tuple[int, int] = (0, 0)):
        """아이템 렌더링
        
        Args:
            screen: 렌더링할 화면
            camera_offset: 카메라 오프셋
        """
        if not self.visible:
            return
            
        # 렌더링 위치 계산
        render_x = int(self.position.x - camera_offset[0])
        render_y = int(self.position.y - camera_offset[1])
        
        # 파티클 렌더링
        self.render_particles(screen, camera_offset)
        
        # 글로우 효과 렌더링
        self.render_glow(screen, render_x, render_y)
        
        # 아이템 본체 렌더링
        self.render_item_body(screen, render_x, render_y)
        
        # 아이콘 렌더링
        self.render_icon(screen, render_x, render_y)
        
    def render_particles(self, screen: pygame.Surface, camera_offset: Tuple[int, int]):
        """파티클 효과 렌더링
        
        Args:
            screen: 렌더링할 화면
            camera_offset: 카메라 오프셋
        """
        for particle in self.particles:
            x = int(particle['pos'][0] - camera_offset[0])
            y = int(particle['pos'][1] - camera_offset[1])
            size = int(particle['size'])
            alpha = particle['alpha']
            
            if alpha > 0:
                s = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                color = (*particle['color'], alpha)
                pygame.draw.circle(s, color, (size, size), size)
                screen.blit(s, (x - size, y - size))
                
    def render_glow(self, screen: pygame.Surface, x: int, y: int):
        """글로우 효과 렌더링
        
        Args:
            screen: 렌더링할 화면
            x: X 좌표
            y: Y 좌표
        """
        glow_radius = int(self.radius * 2)
        alpha = int(self.glow_intensity * 50)
        
        s = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
        color = (*self.item_data['color'], alpha)
        pygame.draw.circle(s, color, (glow_radius, glow_radius), glow_radius)
        
        screen.blit(s, (x - glow_radius, y - glow_radius))
        
    def render_item_body(self, screen: pygame.Surface, x: int, y: int):
        """아이템 본체 렌더링
        
        Args:
            screen: 렌더링할 화면
            x: X 좌표
            y: Y 좌표
        """
        # 회전된 육각형 렌더링
        points = []
        for i in range(6):
            angle = math.radians(self.rotation + i * 60)
            px = x + int(math.cos(angle) * self.radius)
            py = y + int(math.sin(angle) * self.radius)
            points.append((px, py))
            
        pygame.draw.polygon(screen, self.item_data['color'], points)
        pygame.draw.polygon(screen, (255, 255, 255), points, 2)
        
    def render_icon(self, screen: pygame.Surface, x: int, y: int):
        """아이콘 렌더링 (간단한 심볼)
        
        Args:
            screen: 렌더링할 화면
            x: X 좌표
            y: Y 좌표
        """
        icon_type = self.item_data['icon']
        icon_color = (255, 255, 255)
        
        if icon_type == 'lightning':
            # 번개 모양
            points = [
                (x - 5, y - 8),
                (x + 2, y - 2),
                (x - 2, y + 2),
                (x + 5, y + 8)
            ]
            pygame.draw.lines(screen, icon_color, False, points, 2)
            
        elif icon_type == 'expand':
            # 확장 화살표
            pygame.draw.line(screen, icon_color, (x - 8, y), (x + 8, y), 2)
            pygame.draw.line(screen, icon_color, (x - 8, y), (x - 5, y - 3), 2)
            pygame.draw.line(screen, icon_color, (x - 8, y), (x - 5, y + 3), 2)
            pygame.draw.line(screen, icon_color, (x + 8, y), (x + 5, y - 3), 2)
            pygame.draw.line(screen, icon_color, (x + 8, y), (x + 5, y + 3), 2)
            
        elif icon_type == 'triple':
            # 세 개의 원
            pygame.draw.circle(screen, icon_color, (x - 5, y), 3)
            pygame.draw.circle(screen, icon_color, (x + 5, y), 3)
            pygame.draw.circle(screen, icon_color, (x, y - 5), 3)
            
        elif icon_type == 'shield':
            # 방패 모양
            points = [
                (x, y - 8),
                (x - 6, y - 4),
                (x - 6, y + 2),
                (x, y + 8),
                (x + 6, y + 2),
                (x + 6, y - 4)
            ]
            pygame.draw.polygon(screen, icon_color, points, 2)
            
        elif icon_type == 'power':
            # 파워 심볼 (P)
            pygame.draw.line(screen, icon_color, (x - 4, y - 6), (x - 4, y + 6), 2)
            pygame.draw.arc(screen, icon_color, 
                          pygame.Rect(x - 4, y - 6, 8, 8), 
                          -math.pi/2, math.pi/2, 2)
                          
        elif icon_type == 'clock':
            # 시계
            pygame.draw.circle(screen, icon_color, (x, y), 6, 2)
            pygame.draw.line(screen, icon_color, (x, y), (x, y - 4), 2)
            pygame.draw.line(screen, icon_color, (x, y), (x + 3, y), 2)
            
        elif icon_type == 'magnet':
            # 자석 (U 모양)
            pygame.draw.arc(screen, icon_color,
                          pygame.Rect(x - 6, y - 4, 12, 12),
                          0, math.pi, 3)
            pygame.draw.line(screen, icon_color, (x - 6, y + 2), (x - 6, y - 4), 2)
            pygame.draw.line(screen, icon_color, (x + 6, y + 2), (x + 6, y - 4), 2)
            
        elif icon_type == 'ghost':
            # 고스트
            pygame.draw.circle(screen, icon_color, (x, y - 2), 5, 2)
            points = [
                (x - 5, y - 2),
                (x - 5, y + 4),
                (x - 3, y + 6),
                (x, y + 4),
                (x + 3, y + 6),
                (x + 5, y + 4),
                (x + 5, y - 2)
            ]
            pygame.draw.lines(screen, icon_color, False, points, 2)
            
    def on_collision(self, other: Entity):
        """충돌 이벤트 처리
        
        Args:
            other: 충돌한 엔티티
        """
        # 패들과 충돌 시 수집
        if other.has_tag("paddle") and not self.is_collected:
            self.collect(other)
            
    def collect(self, collector: Entity):
        """아이템 수집
        
        Args:
            collector: 수집한 엔티티
        """
        self.is_collected = True
        self.collidable = False
        
        # 수집 이벤트
        emit_event(EventType.ITEM_COLLECTED, {
            'item_type': self.item_type,
            'collector': 'player' if collector.has_tag("player") else 'boss',
            'duration': self.item_data['duration'],
            'position': (self.position.x, self.position.y)
        })
        
        # 수집 사운드
        emit_event(EventType.PLAY_SOUND, {'sound': 'item_collect'})
        
    def destroy(self):
        """아이템 파괴"""
        if not self.is_collected:
            emit_event(EventType.ITEM_EXPIRED, {
                'item_type': self.item_type,
                'position': (self.position.x, self.position.y)
            })
            
        super().destroy()
        
    @classmethod
    def spawn_random(cls, x: float = None, y: float = None) -> 'ItemEntity':
        """랜덤 아이템 생성
        
        Args:
            x: X 좌표 (None이면 랜덤)
            y: Y 좌표 (None이면 화면 위)
            
        Returns:
            생성된 아이템 엔티티
        """
        if x is None:
            x = random.randint(50, 550)
        if y is None:
            y = -30
            
        return cls(x, y)
        
    @classmethod
    def spawn_specific(cls, item_type: str, x: float = None, y: float = None) -> 'ItemEntity':
        """특정 아이템 생성
        
        Args:
            item_type: 아이템 타입
            x: X 좌표 (None이면 랜덤)
            y: Y 좌표 (None이면 화면 위)
            
        Returns:
            생성된 아이템 엔티티
        """
        if x is None:
            x = random.randint(50, 550)
        if y is None:
            y = -30
            
        return cls(x, y, item_type)