"""
🎨 Game Renderer
게임 렌더링 시스템 - 모든 시각적 요소 렌더링
"""

import pygame
import math
import random
from typing import Optional, List, Tuple, Any
from dataclasses import dataclass
from enum import Enum


class RenderLayer(Enum):
    """렌더링 레이어 열거형"""
    BACKGROUND = 0
    FIELD = 1
    ENTITIES = 2
    EFFECTS = 3
    UI = 4
    OVERLAY = 5


@dataclass
class RenderConfig:
    """렌더링 설정"""
    enable_particles: bool = True
    enable_shadows: bool = True
    enable_glow: bool = True
    enable_antialiasing: bool = True
    particle_quality: int = 2  # 1: Low, 2: Medium, 3: High
    effect_quality: int = 2


class GameRenderer:
    """
    🎨 게임 렌더러 클래스
    
    모든 게임 요소를 화면에 렌더링하는 중앙 시스템입니다.
    레이어 기반 렌더링을 통해 올바른 그리기 순서를 보장합니다.
    """
    
    def __init__(self, screen: pygame.Surface, config: Optional[RenderConfig] = None):
        """
        렌더러 초기화
        
        Args:
            screen: 렌더링할 화면 Surface
            config: 렌더링 설정
        """
        self.screen = screen
        self.config = config or RenderConfig()
        self.screen_width = screen.get_width()
        self.screen_height = screen.get_height()
        
        # 레이어별 Surface 생성
        self.layers = {}
        for layer in RenderLayer:
            self.layers[layer] = pygame.Surface(
                (self.screen_width, self.screen_height),
                pygame.SRCALPHA
            )
        
        # 캐시된 배경
        self.cached_backgrounds = {}
        
        # 파티클 리스트
        self.particles = []
        
        # 화면 효과
        self.screen_shake = 0
        self.screen_shake_intensity = 0
        self.screen_flash = 0
        self.screen_flash_color = (255, 255, 255)
        
        # 카메라
        self.camera_x = 0
        self.camera_y = 0
        
        print("🎨 게임 렌더러 초기화 완료")
    
    def begin_frame(self):
        """프레임 렌더링 시작"""
        # 모든 레이어 클리어
        for layer in self.layers.values():
            layer.fill((0, 0, 0, 0))
        
        # 화면 효과 업데이트
        self._update_screen_effects()
    
    def end_frame(self):
        """프레임 렌더링 종료"""
        # 카메라 오프셋 적용
        offset_x = self.camera_x
        offset_y = self.camera_y
        
        # 화면 흔들림 적용
        if self.screen_shake > 0:
            offset_x += random.uniform(-self.screen_shake_intensity, self.screen_shake_intensity)
            offset_y += random.uniform(-self.screen_shake_intensity, self.screen_shake_intensity)
        
        # 레이어 순서대로 화면에 블릿
        for layer in RenderLayer:
            self.screen.blit(self.layers[layer], (offset_x, offset_y))
        
        # 화면 플래시 효과
        if self.screen_flash > 0:
            flash_surface = pygame.Surface((self.screen_width, self.screen_height))
            flash_surface.fill(self.screen_flash_color)
            flash_surface.set_alpha(int(self.screen_flash * 255))
            self.screen.blit(flash_surface, (0, 0))
    
    def render_background(self, stage: int):
        """배경 렌더링"""
        layer = self.layers[RenderLayer.BACKGROUND]
        
        # 캐시된 배경 확인
        if stage not in self.cached_backgrounds:
            self.cached_backgrounds[stage] = self._create_stage_background(stage)
        
        layer.blit(self.cached_backgrounds[stage], (0, 0))
    
    def _create_stage_background(self, stage: int) -> pygame.Surface:
        """스테이지별 배경 생성"""
        surface = pygame.Surface((self.screen_width, self.screen_height))
        
        if stage == 1:
            # Stage 1: 사이버펑크 배경
            self._render_cyberpunk_background(surface)
        elif stage == 2:
            # Stage 2: 정글 배경
            self._render_jungle_background(surface)
        elif stage == 3:
            # Stage 3: 멘헤라 배경
            self._render_menhera_background(surface)
        elif stage == 4:
            # Stage 4: 소림사 배경
            self._render_shaolin_background(surface)
        elif stage == 5:
            # Stage 5: 중국 시장 배경
            self._render_market_background(surface)
        elif stage == 6:
            # Stage 6: 항공모함 배경
            self._render_carrier_background(surface)
        else:
            # 기본 배경
            surface.fill((20, 20, 40))
        
        return surface
    
    def _render_cyberpunk_background(self, surface: pygame.Surface):
        """사이버펑크 배경 렌더링"""
        # 그라데이션 배경
        for y in range(self.screen_height):
            color_value = int(20 + (y / self.screen_height) * 30)
            color = (color_value, 0, color_value + 10)
            pygame.draw.line(surface, color, (0, y), (self.screen_width, y))
        
        # 네온 그리드
        grid_color = (50, 0, 100)
        for x in range(0, self.screen_width, 50):
            pygame.draw.line(surface, grid_color, (x, 0), (x, self.screen_height), 1)
        for y in range(0, self.screen_height, 50):
            pygame.draw.line(surface, grid_color, (0, y), (self.screen_width, y), 1)
    
    def _render_jungle_background(self, surface: pygame.Surface):
        """정글 배경 렌더링"""
        # 녹색 그라데이션
        for y in range(self.screen_height):
            color_value = int(20 + (y / self.screen_height) * 40)
            color = (0, color_value + 30, 0)
            pygame.draw.line(surface, color, (0, y), (self.screen_width, y))
        
        # 나뭇잎 패턴
        leaf_color = (0, 80, 0)
        for _ in range(20):
            x = random.randint(0, self.screen_width)
            y = random.randint(0, self.screen_height)
            pygame.draw.circle(surface, leaf_color, (x, y), random.randint(10, 30), 1)
    
    def _render_menhera_background(self, surface: pygame.Surface):
        """멘헤라 배경 렌더링"""
        # 분홍색 그라데이션
        for y in range(self.screen_height):
            color_value = int(100 + (y / self.screen_height) * 50)
            color = (color_value + 50, color_value, color_value + 30)
            pygame.draw.line(surface, color, (0, y), (self.screen_width, y))
        
        # 하트 패턴
        heart_color = (255, 100, 150)
        for _ in range(15):
            x = random.randint(20, self.screen_width - 20)
            y = random.randint(20, self.screen_height - 20)
            self._draw_heart(surface, x, y, 15, heart_color)
    
    def _render_shaolin_background(self, surface: pygame.Surface):
        """소림사 배경 렌더링"""
        # 황금색 그라데이션
        for y in range(self.screen_height):
            color_value = int(50 + (y / self.screen_height) * 30)
            color = (color_value + 30, color_value + 20, 0)
            pygame.draw.line(surface, color, (0, y), (self.screen_width, y))
        
        # 사원 기둥
        pillar_color = (80, 60, 20)
        for x in range(100, self.screen_width, 200):
            pygame.draw.rect(surface, pillar_color, (x - 20, 0, 40, self.screen_height))
    
    def _render_market_background(self, surface: pygame.Surface):
        """중국 시장 배경 렌더링"""
        # 붉은색 그라데이션
        for y in range(self.screen_height):
            color_value = int(40 + (y / self.screen_height) * 40)
            color = (color_value + 40, color_value, 0)
            pygame.draw.line(surface, color, (0, y), (self.screen_width, y))
        
        # 등불 패턴
        lantern_color = (255, 100, 0)
        for x in range(50, self.screen_width, 100):
            for y in range(50, self.screen_height, 150):
                pygame.draw.circle(surface, lantern_color, (x, y), 20, 2)
    
    def _render_carrier_background(self, surface: pygame.Surface):
        """항공모함 배경 렌더링"""
        # 강철 회색 그라데이션
        for y in range(self.screen_height):
            color_value = int(50 + (y / self.screen_height) * 30)
            color = (color_value, color_value + 10, color_value + 20)
            pygame.draw.line(surface, color, (0, y), (self.screen_width, y))
        
        # 활주로 표시
        runway_color = (255, 255, 0)
        pygame.draw.line(surface, runway_color, 
                        (self.screen_width // 2, 0),
                        (self.screen_width // 2, self.screen_height), 3)
        
        # 대시 라인
        for y in range(0, self.screen_height, 40):
            pygame.draw.line(surface, (100, 100, 100),
                           (self.screen_width // 2 - 50, y),
                           (self.screen_width // 2 - 50, y + 20), 2)
            pygame.draw.line(surface, (100, 100, 100),
                           (self.screen_width // 2 + 50, y),
                           (self.screen_width // 2 + 50, y + 20), 2)
    
    def render_field(self):
        """게임 필드 렌더링"""
        layer = self.layers[RenderLayer.FIELD]
        
        # 필드 경계선
        border_color = (100, 100, 100)
        pygame.draw.rect(layer, border_color, 
                        (10, 10, self.screen_width - 20, self.screen_height - 20), 2)
        
        # 중앙선
        center_y = self.screen_height // 2
        pygame.draw.line(layer, (50, 50, 50),
                        (20, center_y), (self.screen_width - 20, center_y), 1)
    
    def render_entity(self, entity: Any):
        """엔티티 렌더링"""
        layer = self.layers[RenderLayer.ENTITIES]
        
        if hasattr(entity, 'render'):
            # 엔티티가 자체 렌더 메서드를 가진 경우
            entity.render(layer)
        elif hasattr(entity, 'rect') and hasattr(entity, 'color'):
            # 기본 렉트 렌더링
            if self.config.enable_shadows:
                # 그림자 렌더링
                shadow_rect = entity.rect.copy()
                shadow_rect.x += 5
                shadow_rect.y += 5
                shadow_color = (0, 0, 0, 100)
                shadow_surface = pygame.Surface((shadow_rect.width, shadow_rect.height), pygame.SRCALPHA)
                shadow_surface.fill(shadow_color)
                layer.blit(shadow_surface, shadow_rect.topleft)
            
            # 엔티티 렌더링
            pygame.draw.rect(layer, entity.color, entity.rect)
            
            if self.config.enable_glow:
                # 글로우 효과
                self._render_glow(layer, entity.rect, entity.color)
    
    def render_particle(self, particle: dict):
        """파티클 렌더링"""
        if not self.config.enable_particles:
            return
        
        layer = self.layers[RenderLayer.EFFECTS]
        
        x = int(particle.get('x', 0))
        y = int(particle.get('y', 0))
        size = particle.get('size', 2)
        color = particle.get('color', (255, 255, 255))
        alpha = particle.get('alpha', 255)
        
        if alpha < 255:
            particle_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            color_with_alpha = (*color, alpha)
            pygame.draw.circle(particle_surface, color_with_alpha, (size, size), size)
            layer.blit(particle_surface, (x - size, y - size))
        else:
            pygame.draw.circle(layer, color, (x, y), size)
    
    def render_text(self, text: str, pos: Tuple[int, int], 
                   font_size: int = 24, color: Tuple[int, int, int] = (255, 255, 255),
                   center: bool = False):
        """텍스트 렌더링"""
        layer = self.layers[RenderLayer.UI]
        
        font = pygame.font.Font(None, font_size)
        text_surface = font.render(text, True, color)
        
        if center:
            text_rect = text_surface.get_rect(center=pos)
            layer.blit(text_surface, text_rect)
        else:
            layer.blit(text_surface, pos)
    
    def render_health_bar(self, pos: Tuple[int, int], current: int, maximum: int,
                         width: int = 200, height: int = 20,
                         color: Tuple[int, int, int] = (255, 0, 0)):
        """체력바 렌더링"""
        layer = self.layers[RenderLayer.UI]
        
        # 배경
        bg_rect = pygame.Rect(pos[0], pos[1], width, height)
        pygame.draw.rect(layer, (50, 50, 50), bg_rect)
        
        # 체력
        health_width = int((current / maximum) * width)
        health_rect = pygame.Rect(pos[0], pos[1], health_width, height)
        pygame.draw.rect(layer, color, health_rect)
        
        # 테두리
        pygame.draw.rect(layer, (200, 200, 200), bg_rect, 2)
        
        # 텍스트
        text = f"{current}/{maximum}"
        self.render_text(text, (pos[0] + width // 2, pos[1] + height // 2),
                        font_size=16, center=True)
    
    def _render_glow(self, surface: pygame.Surface, rect: pygame.Rect, 
                    color: Tuple[int, int, int], intensity: int = 3):
        """글로우 효과 렌더링"""
        for i in range(intensity):
            glow_rect = rect.inflate(i * 4, i * 4)
            alpha = 50 - (i * 15)
            if alpha > 0:
                glow_surface = pygame.Surface((glow_rect.width, glow_rect.height), pygame.SRCALPHA)
                glow_color = (*color, alpha)
                pygame.draw.rect(glow_surface, glow_color, (0, 0, glow_rect.width, glow_rect.height))
                surface.blit(glow_surface, glow_rect.topleft)
    
    def _draw_heart(self, surface: pygame.Surface, x: int, y: int, 
                   size: int, color: Tuple[int, int, int]):
        """하트 그리기"""
        # 하트 모양을 두 개의 원과 삼각형으로 구성
        pygame.draw.circle(surface, color, (x - size // 2, y), size // 2)
        pygame.draw.circle(surface, color, (x + size // 2, y), size // 2)
        pygame.draw.polygon(surface, color, [
            (x - size, y),
            (x + size, y),
            (x, y + size * 1.5)
        ])
    
    def add_particle(self, x: float, y: float, vel_x: float = 0, vel_y: float = 0,
                    size: int = 2, color: Tuple[int, int, int] = (255, 255, 255),
                    lifetime: float = 1.0):
        """파티클 추가"""
        if not self.config.enable_particles:
            return
        
        # 파티클 품질에 따라 수 제한
        if len(self.particles) >= self.config.particle_quality * 100:
            return
        
        particle = {
            'x': x,
            'y': y,
            'vel_x': vel_x,
            'vel_y': vel_y,
            'size': size,
            'color': color,
            'lifetime': lifetime,
            'max_lifetime': lifetime,
            'alpha': 255
        }
        self.particles.append(particle)
    
    def update_particles(self, dt: float):
        """파티클 업데이트"""
        if not self.config.enable_particles:
            return
        
        for particle in self.particles[:]:
            # 위치 업데이트
            particle['x'] += particle['vel_x'] * dt * 60
            particle['y'] += particle['vel_y'] * dt * 60
            
            # 수명 감소
            particle['lifetime'] -= dt
            
            # 알파값 계산
            life_ratio = particle['lifetime'] / particle['max_lifetime']
            particle['alpha'] = int(255 * life_ratio)
            
            # 죽은 파티클 제거
            if particle['lifetime'] <= 0:
                self.particles.remove(particle)
    
    def shake_screen(self, intensity: float = 10, duration: float = 0.5):
        """화면 흔들기 효과"""
        self.screen_shake = duration
        self.screen_shake_intensity = intensity
    
    def flash_screen(self, color: Tuple[int, int, int] = (255, 255, 255),
                    duration: float = 0.2):
        """화면 플래시 효과"""
        self.screen_flash = 1.0
        self.screen_flash_color = color
        self.flash_duration = duration
    
    def _update_screen_effects(self):
        """화면 효과 업데이트"""
        dt = 1/60  # 60 FPS 기준
        
        # 화면 흔들림 감소
        if self.screen_shake > 0:
            self.screen_shake -= dt
            if self.screen_shake < 0:
                self.screen_shake = 0
        
        # 화면 플래시 감소
        if self.screen_flash > 0:
            self.screen_flash -= dt * 5  # 빠르게 사라짐
            if self.screen_flash < 0:
                self.screen_flash = 0
    
    def set_camera(self, x: float, y: float):
        """카메라 위치 설정"""
        self.camera_x = x
        self.camera_y = y
    
    def clear(self):
        """렌더러 클리어"""
        self.particles.clear()
        self.cached_backgrounds.clear()
        self.screen_shake = 0
        self.screen_flash = 0