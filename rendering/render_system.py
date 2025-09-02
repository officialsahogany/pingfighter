# -*- coding: utf-8 -*-
"""
🎨 Rendering System
렌더링 시스템 - 화면 그리기와 시각 효과 관리
"""

import pygame
import math
import random
from typing import List, Dict, Optional, Any, Tuple
from enum import Enum
from dataclasses import dataclass, field


class RenderLayer(Enum):
    """렌더링 레이어 (그리기 순서)"""
    BACKGROUND = 0
    EFFECTS_BACK = 1
    ENTITIES = 2
    PARTICLES = 3
    EFFECTS_FRONT = 4
    UI = 5
    OVERLAY = 6
    DEBUG = 7


class BlendMode(Enum):
    """블렌드 모드"""
    NORMAL = "normal"
    ADD = "add"
    MULTIPLY = "multiply"
    SCREEN = "screen"
    OVERLAY = "overlay"


@dataclass
class RenderObject:
    """렌더링 객체"""
    layer: RenderLayer
    position: Tuple[float, float]
    draw_func: callable
    z_order: int = 0
    visible: bool = True
    alpha: int = 255
    blend_mode: BlendMode = BlendMode.NORMAL
    transform: Optional[Dict[str, Any]] = None


@dataclass
class ParticleEffect:
    """파티클 효과"""
    position: Tuple[float, float]
    velocity: Tuple[float, float]
    color: Tuple[int, int, int]
    size: float
    lifetime: float
    max_lifetime: float
    gravity: float = 0
    fade: bool = True
    
    def update(self, dt: float):
        """파티클 업데이트"""
        # 위치 업데이트
        self.position = (
            self.position[0] + self.velocity[0] * dt,
            self.position[1] + self.velocity[1] * dt + self.gravity * dt * dt
        )
        
        # 속도 업데이트 (중력)
        self.velocity = (
            self.velocity[0],
            self.velocity[1] + self.gravity * dt
        )
        
        # 수명 감소
        self.lifetime -= dt
        
        # 크기 감소
        if self.lifetime < self.max_lifetime * 0.3:
            self.size *= 0.95
    
    def get_alpha(self) -> int:
        """알파값 계산"""
        if not self.fade:
            return 255
        
        ratio = self.lifetime / self.max_lifetime
        return int(255 * ratio)
    
    def is_alive(self) -> bool:
        """생존 여부"""
        return self.lifetime > 0 and self.size > 0.1


class RenderSystem:
    """
    🎨 렌더링 시스템
    
    모든 게임 객체의 렌더링을 관리하고 최적화합니다.
    """
    
    def __init__(self, screen: pygame.Surface):
        """
        렌더링 시스템 초기화
        
        Args:
            screen: Pygame 화면 Surface
        """
        self.screen = screen
        self.screen_width = screen.get_width()
        self.screen_height = screen.get_height()
        
        # 렌더링 객체 관리
        self.render_objects: Dict[RenderLayer, List[RenderObject]] = {
            layer: [] for layer in RenderLayer
        }
        
        # 파티클 시스템
        self.particles: List[ParticleEffect] = []
        self.max_particles = 500
        
        # 카메라 설정
        self.camera_offset = (0, 0)
        self.camera_shake = 0
        self.camera_shake_intensity = 0
        
        # 후처리 효과
        self.post_effects = []
        self.screen_tint = None
        self.flash_effect = None
        
        # 성능 최적화
        self.dirty_rects: List[pygame.Rect] = []
        self.use_dirty_rects = False
        
        # 디버그 모드
        self.debug_mode = False
        self.show_fps = False
        self.fps_font = None
        
        print("🎨 렌더링 시스템 초기화 완료")
    
    def add_render_object(self, obj: RenderObject):
        """렌더링 객체 추가"""
        self.render_objects[obj.layer].append(obj)
        
        # Z-order로 정렬
        self.render_objects[obj.layer].sort(key=lambda x: x.z_order)
    
    def remove_render_object(self, obj: RenderObject):
        """렌더링 객체 제거"""
        if obj in self.render_objects[obj.layer]:
            self.render_objects[obj.layer].remove(obj)
    
    def clear_layer(self, layer: RenderLayer):
        """특정 레이어 초기화"""
        self.render_objects[layer].clear()
    
    def add_particle(self, position: Tuple[float, float], 
                     velocity: Tuple[float, float],
                     color: Tuple[int, int, int],
                     size: float = 3,
                     lifetime: float = 1.0,
                     gravity: float = 0):
        """파티클 추가"""
        if len(self.particles) >= self.max_particles:
            # 가장 오래된 파티클 제거
            self.particles.pop(0)
        
        particle = ParticleEffect(
            position=position,
            velocity=velocity,
            color=color,
            size=size,
            lifetime=lifetime,
            max_lifetime=lifetime,
            gravity=gravity
        )
        self.particles.append(particle)
    
    def create_explosion(self, position: Tuple[float, float], 
                        count: int = 30,
                        color: Tuple[int, int, int] = (255, 200, 0),
                        speed: float = 200):
        """폭발 효과 생성"""
        for _ in range(count):
            angle = random.uniform(0, math.pi * 2)
            velocity = (
                math.cos(angle) * random.uniform(speed/2, speed),
                math.sin(angle) * random.uniform(speed/2, speed)
            )
            
            self.add_particle(
                position=position,
                velocity=velocity,
                color=color,
                size=random.uniform(2, 6),
                lifetime=random.uniform(0.3, 0.8),
                gravity=100
            )
    
    def create_trail(self, position: Tuple[float, float],
                    direction: Tuple[float, float],
                    color: Tuple[int, int, int] = (100, 200, 255),
                    count: int = 5):
        """궤적 효과 생성"""
        for i in range(count):
            offset = i * 5
            pos = (
                position[0] - direction[0] * offset,
                position[1] - direction[1] * offset
            )
            
            self.add_particle(
                position=pos,
                velocity=(random.uniform(-20, 20), random.uniform(-20, 20)),
                color=color,
                size=3 - i * 0.5,
                lifetime=0.2 + i * 0.05
            )
    
    def shake_camera(self, intensity: float = 10, duration: float = 0.3):
        """카메라 흔들기"""
        self.camera_shake = duration
        self.camera_shake_intensity = intensity
    
    def flash_screen(self, color: Tuple[int, int, int] = (255, 255, 255),
                    duration: float = 0.1):
        """화면 플래시 효과"""
        self.flash_effect = {
            'color': color,
            'duration': duration,
            'max_duration': duration
        }
    
    def tint_screen(self, color: Tuple[int, int, int, int]):
        """화면 색조 변경"""
        self.screen_tint = color
    
    def update(self, dt: float):
        """
        렌더링 시스템 업데이트
        
        Args:
            dt: 델타 타임
        """
        # 파티클 업데이트
        for particle in self.particles[:]:
            particle.update(dt)
            if not particle.is_alive():
                self.particles.remove(particle)
        
        # 카메라 흔들기 업데이트
        if self.camera_shake > 0:
            self.camera_shake -= dt
            if self.camera_shake <= 0:
                self.camera_offset = (0, 0)
            else:
                self.camera_offset = (
                    random.uniform(-self.camera_shake_intensity, self.camera_shake_intensity),
                    random.uniform(-self.camera_shake_intensity, self.camera_shake_intensity)
                )
        
        # 플래시 효과 업데이트
        if self.flash_effect:
            self.flash_effect['duration'] -= dt
            if self.flash_effect['duration'] <= 0:
                self.flash_effect = None
    
    def render(self):
        """전체 화면 렌더링"""
        # 카메라 오프셋 적용
        if self.camera_offset != (0, 0):
            self.screen.scroll(int(self.camera_offset[0]), int(self.camera_offset[1]))
        
        # 레이어별로 렌더링
        for layer in RenderLayer:
            for obj in self.render_objects[layer]:
                if obj.visible:
                    self._render_object(obj)
        
        # 파티클 렌더링
        self._render_particles()
        
        # 후처리 효과
        self._apply_post_effects()
        
        # 디버그 정보
        if self.debug_mode:
            self._render_debug_info()
    
    def _render_object(self, obj: RenderObject):
        """개별 객체 렌더링"""
        # 변환 적용
        if obj.transform:
            # 회전, 스케일 등 변환 처리
            pass
        
        # 블렌드 모드 설정
        if obj.blend_mode != BlendMode.NORMAL:
            # 특수 블렌드 모드 처리
            pass
        
        # 알파 적용
        if obj.alpha < 255:
            # 투명도 처리
            pass
        
        # 그리기 함수 호출
        obj.draw_func(self.screen, obj.position)
    
    def _render_particles(self):
        """파티클 렌더링"""
        for particle in self.particles:
            alpha = particle.get_alpha()
            if alpha > 0:
                # 파티클 그리기
                pos = (int(particle.position[0]), int(particle.position[1]))
                
                # 글로우 효과
                if particle.size > 2:
                    glow_size = int(particle.size * 2)
                    glow_color = tuple(c // 2 for c in particle.color)
                    pygame.draw.circle(self.screen, glow_color, pos, glow_size)
                
                # 파티클 본체
                pygame.draw.circle(self.screen, particle.color, pos, int(particle.size))
    
    def _apply_post_effects(self):
        """후처리 효과 적용"""
        # 화면 색조
        if self.screen_tint:
            tint_surface = pygame.Surface((self.screen_width, self.screen_height))
            tint_surface.set_alpha(self.screen_tint[3] if len(self.screen_tint) > 3 else 128)
            tint_surface.fill(self.screen_tint[:3])
            self.screen.blit(tint_surface, (0, 0))
        
        # 플래시 효과
        if self.flash_effect:
            alpha_ratio = self.flash_effect['duration'] / self.flash_effect['max_duration']
            alpha = int(255 * alpha_ratio)
            
            flash_surface = pygame.Surface((self.screen_width, self.screen_height))
            flash_surface.set_alpha(alpha)
            flash_surface.fill(self.flash_effect['color'])
            self.screen.blit(flash_surface, (0, 0))
    
    def _render_debug_info(self):
        """디버그 정보 렌더링"""
        if self.show_fps and self.fps_font:
            # FPS 표시
            pass
        
        # 충돌 박스 표시
        for layer in [RenderLayer.ENTITIES]:
            for obj in self.render_objects[layer]:
                # 충돌 박스 그리기
                pass
    
    def draw_line(self, start: Tuple[float, float], end: Tuple[float, float],
                 color: Tuple[int, int, int], width: int = 1):
        """선 그리기"""
        pygame.draw.line(self.screen, color,
                        (int(start[0]), int(start[1])),
                        (int(end[0]), int(end[1])), width)
    
    def draw_circle(self, center: Tuple[float, float], radius: float,
                   color: Tuple[int, int, int], width: int = 0):
        """원 그리기"""
        pygame.draw.circle(self.screen, color,
                         (int(center[0]), int(center[1])),
                         int(radius), width)
    
    def draw_rect(self, rect: pygame.Rect, color: Tuple[int, int, int],
                 width: int = 0):
        """사각형 그리기"""
        pygame.draw.rect(self.screen, color, rect, width)
    
    def draw_text(self, text: str, position: Tuple[float, float],
                 font: pygame.font.Font, color: Tuple[int, int, int],
                 center: bool = False):
        """텍스트 그리기"""
        text_surface = font.render(text, True, color)
        text_rect = text_surface.get_rect()
        
        if center:
            text_rect.center = (int(position[0]), int(position[1]))
        else:
            text_rect.topleft = (int(position[0]), int(position[1]))
        
        self.screen.blit(text_surface, text_rect)
    
    def clear(self, color: Tuple[int, int, int] = (0, 0, 0)):
        """화면 지우기"""
        self.screen.fill(color)
    
    def reset(self):
        """렌더링 시스템 초기화"""
        # 모든 레이어 초기화
        for layer in RenderLayer:
            self.render_objects[layer].clear()
        
        # 파티클 초기화
        self.particles.clear()
        
        # 효과 초기화
        self.camera_offset = (0, 0)
        self.camera_shake = 0
        self.screen_tint = None
        self.flash_effect = None
        
        print("🎨 렌더링 시스템 리셋 완료")