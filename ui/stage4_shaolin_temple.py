# -*- coding: utf-8 -*-
"""
Stage 4: Shaolin Temple (소림사 사원) Background
Oriental temple theme with traditional Chinese architecture and martial arts atmosphere
"""

import pygame
import math
import random
from typing import List, Tuple, Dict, Any

class ShaolinTempleBackground:
    def __init__(self, width: int = 600, height: int = 750):
        self.width = width
        self.height = height
        self.frame_count = 0
        
        # Temple destruction state
        self.temple_destroyed = False
        self.destruction_animation_active = False
        self.destruction_phase = 0  # 0: idle, 1: moon turning red, 2: red light, 3: collapsing, 4: ruins
        self.destruction_timer = 0
        self.moon_red_intensity = 0.0
        self.red_light_alpha = 0
        self.collapse_offset = 0
        self.collapse_debris = []
        self.screen_shake_offset = [0, 0]
        self.screen_shake_intensity = 0
        self.falling_lanterns = []  # Lanterns that are falling during destruction
        self.ground_fires = []  # Fire effects on ground from broken lanterns
        
        # Moon crater fragments system
        self.moon_fragments = []  # Active moon crater fragments
        self.moon_fragment_timer = 0  # Timer for spawning fragments
        self.moon_fragment_interval = random.randint(1200, 1800)  # 20-30 seconds at 60 FPS
        self.moon_fragment_active = False  # Only active after moon turns red
        
        # Moon pulsing effect when firing fragments
        self.moon_pulse_timer = 0  # Timer for pulsing animation
        self.moon_pulse_active = False  # Whether moon is pulsing
        self.moon_pulse_scale = 1.0  # Scale factor for moon size
        
        # OPTIMIZATION: Cache for red moon effect
        self.red_moon_cache = None  # Cached red moon surface
        self.red_moon_cache_intensity = -1  # Last cached intensity
        self.red_moon_cache_scale = -1  # Last cached scale
        self.red_moon_update_counter = 0  # Update every N frames
        
        # OPTIMIZATION: Performance mode for low FPS
        self.performance_mode = False  # Enable reduced quality for better FPS
        self.fps_counter = 0
        self.low_fps_threshold = 50  # Enable performance mode below 50 FPS
        
        # Colors - Muted night palette (불 꺼진 밤 느낌)
        self.colors = {
            'sky_top': (40, 35, 55),  # 어두운 보라빛 밤하늘
            'sky_bottom': (60, 50, 70),  # 약간 밝은 보라
            'moon': (255, 248, 220),  # 달빛
            'moon_glow': (255, 248, 220, 30),  # 달 광채
            'moon_red': (255, 50, 50),  # 붉은 달
            'moon_red_glow': (255, 50, 50, 60),  # 붉은 달 광채
            'temple_dark': (35, 32, 40),  # 사원 그림자 (보라빛 밤에 어울리게)
            'temple_main': (45, 42, 50),  # 사원 메인 색상 (어두운 회보라)
            'temple_highlight': (55, 52, 60),  # 사원 하이라이트 (약간 밝은 회보라)
            'roof_red': (60, 35, 40),  # 어두운 기와 (붉은기 거의 없음)
            'roof_dark': (40, 30, 35),  # 기와 그림자
            'gold_accent': (120, 105, 70),  # 매우 어두운 금색 (거의 갈색)
            'gold_dim': (80, 70, 50),  # 더 어두운 금색
            'lantern_red': (255, 60, 40),  # 등롱 빨강 (유지 - 빛나는 부분)
            'lantern_glow': (255, 100, 60, 60),  # 등롱 빛
            'incense_smoke': (150, 150, 160, 40),  # 향 연기
            'stone_gray': (55, 50, 60),  # 돌계단 (어둡게)
            'stone_dark': (40, 35, 45),  # 돌 그림자
            'tree_dark': (20, 25, 20),  # 나무 실루엣
            'mist': (200, 200, 210, 20),  # 안개
            'star': (255, 255, 230),  # 별
            'ruins': (30, 25, 30),  # 폐허 색상
            'fragment_core': (255, 80, 60),  # 붉은 크레이터 파편 중심
            'fragment_glow': (255, 50, 30),  # 파편 빛
            'fragment_trail': (255, 100, 80, 100),  # 파편 궤적
        }
        
        # Animated elements
        self.lanterns = self._create_lanterns()
        self.incense_particles = []
        self.stars = self._create_stars()
        self.floating_leaves = self._create_leaves()
        self.mist_layers = self._create_mist_layers()
        
        # Temple structure elements
        self.pagoda_levels = 5  # 5층 탑
        self.bell_swing = 0  # 종 흔들림
        self.dragon_ornaments = self._create_dragon_ornaments()
        
        # Martial arts training dummies
        self.training_dummies = self._create_training_dummies()
        self.dummy_animations = {}
        
        # Flying crows (can be caught for skill points)
        self.crows = []
        self.crow_spawn_timer = 0
        self.crow_spawn_interval = random.randint(720, 1380)  # 12-23 seconds
        
        # Crow explosion fragments and particles
        self.crow_fragments = []
        self.crow_particles = []
        
        # Falling crow corpses (hit crows that fall down) - kept for compatibility
        self.crow_corpses = []
        
        # Wandering monk
        self.monks = []
        self.monk_spawn_timer = 0
        self.monk_spawn_interval = random.randint(1200, 2400)  # 20~40초 (초기 스폰)
        
        # Monk hit effects (공을 칠 때 이펙트)
        self.monk_hit_effects = []  # 충격파 이펙트
        
        # Monk death effects (사원 파괴 시 수도승 죽음)
        self.monk_death_particles = []  # 수도승 폭발 파티클
        self.monk_body_parts = []  # 수도승 신체 파편
        
        # Ritual brazier state (의식용 화로 상태)
        self.brazier_lit = False  # 화로에 불이 붙어있는지
        self.brazier_fire_animation = 0  # 불꽃 애니메이션
        self.brazier_x = self.width // 2
        self.brazier_y = 570
        self.brazier_hitbox = pygame.Rect(self.brazier_x - 40, self.brazier_y - 20, 80, 40)
        
        # Background surface for static elements (with transparency support)
        self.static_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        self._draw_static_background()
        
    def _create_lanterns(self) -> List[Dict[str, Any]]:
        """Create hanging lanterns"""
        lanterns = []
        positions = [
            # (100, 150), (500, 150),  # 상단 좌우 - 제거됨
            (50, 300), (550, 300),   # 중단 좌우
            (150, 250), (450, 250),  # 중앙 좌우
            (250, 180), (350, 180),  # 중앙 상단
        ]
        
        for x, y in positions:
            lanterns.append({
                'x': x,
                'y': y,
                'base_y': y,
                'swing_offset': random.uniform(0, math.pi * 2),
                'swing_speed': random.uniform(0.02, 0.04),
                'glow_radius': random.randint(30, 40),
                'glow_pulse': random.uniform(0, math.pi * 2),
                'size': random.choice(['small', 'medium', 'large']),
            })
        return lanterns
    
    def _create_stars(self) -> List[Dict[str, Any]]:
        """Create twinkling stars"""
        stars = []
        for _ in range(50):
            stars.append({
                'x': random.randint(0, self.width),
                'y': random.randint(0, 200),  # 상단 하늘에만
                'size': random.randint(1, 3),
                'twinkle_speed': random.uniform(0.02, 0.05),
                'twinkle_offset': random.uniform(0, math.pi * 2),
                'brightness': random.uniform(0.3, 1.0),
            })
        return stars
    
    def _create_leaves(self) -> List[Dict[str, Any]]:
        """Create floating bamboo leaves"""
        leaves = []
        for _ in range(15):
            leaves.append({
                'x': random.randint(-50, self.width + 50),
                'y': random.randint(-50, self.height),
                'vx': random.uniform(-0.5, -1.5),  # 왼쪽으로 날림
                'vy': random.uniform(0.5, 1.5),  # 아래로 떨어짐
                'rotation': random.uniform(0, math.pi * 2),
                'rotation_speed': random.uniform(-0.05, 0.05),
                'size': random.randint(8, 15),
                'color_variant': random.randint(0, 2),
            })
        return leaves
    
    def _create_mist_layers(self) -> List[Dict[str, Any]]:
        """Create floating mist layers"""
        mist = []
        for i in range(3):
            mist.append({
                'x': 0,
                'y': 400 + i * 100,
                'width': self.width * 1.5,
                'height': 150,
                'speed': 0.2 + i * 0.1,
                'opacity': 20 + i * 10,
            })
        return mist
    
    def _create_dragon_ornaments(self) -> List[Dict[str, Any]]:
        """Create dragon decorations on temple roof"""
        dragons = []
        positions = [(200, 280), (400, 280)]  # 좌우 용 장식
        
        for x, y in positions:
            dragons.append({
                'x': x,
                'y': y,
                'eye_glow': 0,
                'eye_glow_speed': random.uniform(0.02, 0.03),
                'facing': 'left' if x < self.width / 2 else 'right',
            })
        return dragons
    
    def _create_training_dummies(self) -> List[Dict[str, Any]]:
        """Create martial arts training dummies"""
        dummies = []
        positions = [(120, 500), (480, 500)]  # 가운데 더미 제거
        
        for x, y in positions:
            dummies.append({
                'x': x,
                'y': y,
                'rotation': 0,
                'hit_animation': 0,
                'recovery_speed': 0.1,
            })
        return dummies
    
    def _draw_red_moon(self, surface: pygame.Surface):
        """Draw red moon overlay during destruction with gradient and pulsing"""
        moon_x, moon_y = self.width - 120, 100
        
        # Add pulsing effect
        pulse = 0.0
        if hasattr(self, 'frame_count'):
            pulse = math.sin(self.frame_count * 0.05) * 0.15  # Gentle pulsing
        
        # Apply fragment firing pulse effect (stronger pulse when firing)
        moon_scale = getattr(self, 'moon_pulse_scale', 1.0)
        
        # OPTIMIZATION: Use cached surface if available and unchanged
        # Only update cache every 6 frames (10fps) or when intensity/scale changes significantly
        self.red_moon_update_counter += 1
        intensity_changed = abs(self.moon_red_intensity - self.red_moon_cache_intensity) > 0.1
        scale_changed = abs(moon_scale - self.red_moon_cache_scale) > 0.1
        
        if (self.red_moon_cache is None or intensity_changed or scale_changed or 
            self.red_moon_update_counter >= 6):
            # Create new cache
            self.red_moon_cache = self._create_red_moon_surface(pulse, moon_scale)
            self.red_moon_cache_intensity = self.moon_red_intensity
            self.red_moon_cache_scale = moon_scale
            self.red_moon_update_counter = 0
        
        # Draw cached surface
        if self.red_moon_cache:
            surface.blit(self.red_moon_cache, (moon_x - 200, moon_y - 200))
    
    def _create_red_moon_surface(self, pulse: float, moon_scale: float) -> pygame.Surface:
        """Create the red moon effect surface (for caching)"""
        # Create a surface large enough for the effect (400x400 to fit all glows)
        cache_surface = pygame.Surface((400, 400), pygame.SRCALPHA)
        cache_surface.fill((0, 0, 0, 0))
        
        # Center position in cache surface
        center_x, center_y = 200, 200
        
        # OPTIMIZATION: Reduce quality in performance mode
        if self.performance_mode:
            # Ultra-simple red moon with only 3 glow layers
            for i in [8, 16, 24]:
                distance_ratio = i / 24.0
                alpha = int(40 * (distance_ratio ** 1.5) * self.moon_red_intensity)
                glow_radius = int((35 + i * 6) * moon_scale)
                glow_color = (255, int(40 * (1 - distance_ratio)), 0, min(255, alpha))
                pygame.draw.circle(cache_surface, glow_color, (center_x, center_y), glow_radius)
            
            # Simple moon without gradient
            moon_radius = int(35 * moon_scale)
            base_intensity = int(200 * self.moon_red_intensity)
            moon_color = (255, int(60 - 50 * self.moon_red_intensity), 
                         int(40 - 35 * self.moon_red_intensity), min(255, base_intensity))
            pygame.draw.circle(cache_surface, moon_color, (center_x, center_y), moon_radius)
            
            return cache_surface
        
        # Optimized quality rendering - reduced from 20 to 10 layers
        # Create gradient red glow with optimized falloff
        for i in range(10, 0, -1):
            # Gradient calculation - more transparent as distance increases
            distance_ratio = i / 10.0
            # Use exponential falloff for smoother gradient
            alpha_multiplier = (distance_ratio ** 2) * self.moon_red_intensity * (1.0 + pulse)
            alpha = int(60 * alpha_multiplier)  # Reduced alpha for better performance
            
            glow_radius = int((35 + i * 12) * moon_scale)  # Adjusted spacing for 10 layers
            
            # Simplified glow - single circle per layer instead of gradient
            glow_color = (255, int(80 * (1 - distance_ratio * 0.8)), 0, min(255, alpha))
            pygame.draw.circle(cache_surface, glow_color, (center_x, center_y), glow_radius)
        
        # Draw red moon overlay with better blending
        moon_size = int(80 * moon_scale)  # Apply scale to moon size
        moon_surface = pygame.Surface((moon_size, moon_size), pygame.SRCALPHA)
        
        # Optimized gradient moon surface - reduced gradient steps
        moon_radius = int(35 * moon_scale)  # Scale the radius too
        base_intensity = int(200 * self.moon_red_intensity * (1.0 + pulse * 0.5))
        
        # Create simplified 3-layer gradient instead of pixel-by-pixel
        for layer in range(3):
            r = moon_radius - layer * (moon_radius // 3)
            if r <= 0:
                break
                
            r_ratio = r / float(moon_radius)
            
            # Gradient from center to edge
            if layer == 0:  # Center
                red, green, blue = 255, int(80 - 60 * self.moon_red_intensity), int(60 - 50 * self.moon_red_intensity)
            elif layer == 1:  # Middle
                red = 255
                green = int(120 - 90 * self.moon_red_intensity * r_ratio)
                blue = int(100 - 80 * self.moon_red_intensity * r_ratio)
            else:  # Outer
                red = int(255 - (3 - layer) * 20)
                green = int(180 - 130 * self.moon_red_intensity * r_ratio)
                blue = int(130 - 110 * self.moon_red_intensity * r_ratio)
            
            moon_color = (red, green, blue, min(255, base_intensity))
            pygame.draw.circle(moon_surface, moon_color, (moon_size // 2, moon_size // 2), r)
        
        # Add subtle craters with transparency (scaled positions)
        crater_intensity = int(180 * self.moon_red_intensity)
        crater_color = (180, 40, 20, crater_intensity)
        center = moon_size // 2
        pygame.draw.circle(moon_surface, crater_color, 
                         (int(center - 10 * moon_scale), int(center - 5 * moon_scale)), 
                         int(5 * moon_scale))
        pygame.draw.circle(moon_surface, crater_color, 
                         (int(center + 8 * moon_scale), int(center + 10 * moon_scale)), 
                         int(3 * moon_scale))
        pygame.draw.circle(moon_surface, crater_color, 
                         (int(center + 15 * moon_scale), int(center - 8 * moon_scale)), 
                         int(4 * moon_scale))
        
        cache_surface.blit(moon_surface, (center_x - moon_size // 2, center_y - moon_size // 2))
        return cache_surface
    
    def _draw_static_background(self):
        """Draw static background elements"""
        # Gradient sky
        for y in range(self.height):
            ratio = y / self.height
            color = self._interpolate_color(self.colors['sky_top'], self.colors['sky_bottom'], ratio)
            pygame.draw.line(self.static_surface, color, (0, y), (self.width, y))
        
        # Moon with natural glow effect
        moon_x, moon_y = self.width - 120, 100
        
        # Create softer, more natural glow layers
        for i in range(8, 0, -1):
            # Progressive alpha fade for natural glow
            alpha = int(5 * i)  # More gradual fade
            glow_radius = 35 + i * 12
            
            # Draw glow directly on static surface with alpha blending
            glow_color = (*self.colors['moon_glow'][:3], alpha)
            
            # Create a temporary surface for this glow layer
            glow_size = glow_radius * 2 + 10
            glow_surface = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
            glow_surface.fill((0, 0, 0, 0))  # Clear with transparent
            
            # Draw the glow circle
            pygame.draw.circle(glow_surface, glow_color, 
                             (glow_size // 2, glow_size // 2), 
                             glow_radius)
            
            # Blit with proper centering
            self.static_surface.blit(glow_surface, 
                                    (moon_x - glow_size // 2, 
                                     moon_y - glow_size // 2))
        
        # Draw the moon itself
        pygame.draw.circle(self.static_surface, self.colors['moon'], (moon_x, moon_y), 35)
        
        # Moon craters
        pygame.draw.circle(self.static_surface, (230, 223, 195), (moon_x - 10, moon_y - 5), 5)
        pygame.draw.circle(self.static_surface, (230, 223, 195), (moon_x + 8, moon_y + 10), 3)
        pygame.draw.circle(self.static_surface, (230, 223, 195), (moon_x + 15, moon_y - 8), 4)
        
    def _interpolate_color(self, color1: Tuple[int, int, int], color2: Tuple[int, int, int], ratio: float) -> Tuple[int, int, int]:
        """Interpolate between two colors"""
        return tuple(int(c1 + (c2 - c1) * ratio) for c1, c2 in zip(color1, color2))
    
    def _draw_temple(self, surface: pygame.Surface):
        """Draw the main temple structure"""
        # Base temple building
        temple_x = self.width // 2
        temple_base_y = 450
        
        # Apply gradual collapse offset if destruction is active
        collapse_y_offset = 0
        collapse_rotation = 0
        collapse_opacity = 255
        
        if hasattr(self, 'collapse_offset') and self.collapse_offset > 0:
            # Temple gradually sinks and becomes transparent
            collapse_y_offset = self.collapse_offset
            # Add slight rotation for tilting effect
            collapse_rotation = min(5, self.collapse_offset / 30)
            # Gradually fade temple
            collapse_opacity = max(100, 255 - self.collapse_offset)
        
        # Create temple surface for collapse effects
        temple_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        # 5층 탑 그리기
        for level in range(self.pagoda_levels):
            # Each level falls at slightly different speed for more natural collapse
            level_collapse_offset = collapse_y_offset * (1 + level * 0.1)
            level_y = temple_base_y - level * 60 + level_collapse_offset
            level_width = 200 - level * 25
            level_height = 50
            
            # 층 몸체 (with collapse opacity)
            body_rect = pygame.Rect(
                temple_x - level_width // 2,
                level_y - level_height,
                level_width,
                level_height
            )
            # Apply opacity for collapse effect
            main_color = (*self.colors['temple_main'], collapse_opacity)
            dark_color = (*self.colors['temple_dark'], collapse_opacity)
            
            # Draw on temple surface with opacity
            pygame.draw.rect(temple_surface, main_color, body_rect)
            pygame.draw.rect(temple_surface, dark_color, body_rect, 2)
            
            # 기와 지붕 (with collapse opacity)
            roof_points = [
                (temple_x - level_width // 2 - 15, level_y - level_height),
                (temple_x + level_width // 2 + 15, level_y - level_height),
                (temple_x + level_width // 2 + 5, level_y - level_height - 20),
                (temple_x - level_width // 2 - 5, level_y - level_height - 20),
            ]
            roof_color = (*self.colors['roof_red'], collapse_opacity)
            roof_dark_color = (*self.colors['roof_dark'], collapse_opacity)
            pygame.draw.polygon(temple_surface, roof_color, roof_points)
            pygame.draw.polygon(temple_surface, roof_dark_color, roof_points, 2)
            
            # 금색 장식 (with collapse opacity)
            if level == 0:  # 최상층
                # 탑 꼭대기 장식
                gold_color = (*self.colors['gold_accent'], collapse_opacity)
                pygame.draw.circle(temple_surface, gold_color, 
                                 (temple_x, level_y - level_height - 30), 8)
                pygame.draw.lines(temple_surface, gold_color, False,
                                [(temple_x, level_y - level_height - 38),
                                 (temple_x, level_y - level_height - 50)], 2)
            
            # 창문
            if level < self.pagoda_levels - 1:
                window_y = level_y - level_height // 2
                window_dark_color = (*self.colors['temple_dark'], collapse_opacity)
                window_gold_color = (*self.colors['gold_dim'], collapse_opacity)
                pygame.draw.rect(temple_surface, window_dark_color,
                               (temple_x - 15, window_y - 8, 30, 16))
                pygame.draw.rect(temple_surface, window_gold_color,
                               (temple_x - 15, window_y - 8, 30, 16), 1)
        
        # 입구 (with collapse offset)
        entrance_y = temple_base_y + collapse_y_offset
        entrance_dark_color = (*self.colors['temple_dark'], collapse_opacity)
        entrance_gold_color = (*self.colors['gold_accent'], collapse_opacity)
        pygame.draw.rect(temple_surface, entrance_dark_color,
                        (temple_x - 25, entrance_y - 40, 50, 40))
        pygame.draw.rect(temple_surface, entrance_gold_color,
                        (temple_x - 25, entrance_y - 40, 50, 40), 2)
        
        # 돌계단 (with collapse offset)
        for step in range(5):
            step_y = entrance_y + step * 8
            step_width = 150 + step * 20
            stone_color = (*self.colors['stone_gray'], collapse_opacity)
            stone_dark_color = (*self.colors['stone_dark'], collapse_opacity)
            pygame.draw.rect(temple_surface, stone_color,
                           (temple_x - step_width // 2, step_y, step_width, 8))
            pygame.draw.line(temple_surface, stone_dark_color,
                           (temple_x - step_width // 2, step_y),
                           (temple_x + step_width // 2, step_y), 1)
        
        # Blit the temple surface to the main surface
        # Apply rotation if collapsing for tilting effect
        if collapse_rotation > 0:
            rotated_temple = pygame.transform.rotate(temple_surface, collapse_rotation)
            # Center the rotated surface
            rot_rect = rotated_temple.get_rect(center=(self.width // 2, self.height // 2))
            surface.blit(rotated_temple, rot_rect)
        else:
            surface.blit(temple_surface, (0, 0))
    
    def _draw_dragon_ornament(self, surface: pygame.Surface, dragon: Dict[str, Any]):
        """Draw a dragon ornament"""
        x, y = dragon['x'], dragon['y']
        
        # Dragon body (simplified oriental style)
        if dragon['facing'] == 'left':
            # Body curves
            points = [
                (x, y),
                (x - 20, y + 5),
                (x - 35, y + 10),
                (x - 45, y + 20),
                (x - 40, y + 30),
                (x - 25, y + 35),
                (x - 10, y + 30),
                (x, y + 20),
            ]
        else:
            # Mirror for right-facing
            points = [
                (x, y),
                (x + 20, y + 5),
                (x + 35, y + 10),
                (x + 45, y + 20),
                (x + 40, y + 30),
                (x + 25, y + 35),
                (x + 10, y + 30),
                (x, y + 20),
            ]
        
        pygame.draw.lines(surface, self.colors['gold_dim'], False, points, 2)
        
        # Dragon head (darker)
        head_x = x - 45 if dragon['facing'] == 'left' else x + 45
        pygame.draw.circle(surface, self.colors['gold_dim'], (head_x, y + 20), 8)
        
        # Glowing eyes (dimmer)
        eye_glow = abs(math.sin(dragon['eye_glow']))
        eye_color = (
            150,
            int(50 + 30 * eye_glow),
            int(30 * eye_glow)
        )
        eye_offset = 3 if dragon['facing'] == 'left' else -3
        pygame.draw.circle(surface, eye_color, (head_x + eye_offset, y + 18), 2)
        
        dragon['eye_glow'] += dragon['eye_glow_speed']
    
    def _draw_lantern(self, surface: pygame.Surface, lantern: Dict[str, Any]):
        """Draw a hanging lantern"""
        # Calculate swing
        swing = math.sin(self.frame_count * lantern['swing_speed'] + lantern['swing_offset']) * 5
        x = lantern['x'] + swing
        y = lantern['y']
        
        # Lantern size
        sizes = {
            'small': (15, 20),
            'medium': (20, 25),
            'large': (25, 30),
        }
        width, height = sizes[lantern['size']]
        
        # Glow effect
        glow_alpha = abs(math.sin(lantern['glow_pulse'])) * 0.3 + 0.7
        glow_radius = int(lantern['glow_radius'] * glow_alpha)
        
        glow_surface = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
        for i in range(glow_radius, 0, -2):
            alpha = int(60 * (i / glow_radius) * glow_alpha)
            color = (*self.colors['lantern_glow'][:3], alpha)
            pygame.draw.circle(glow_surface, color, (glow_radius, glow_radius), i)
        surface.blit(glow_surface, (x - glow_radius, y - glow_radius))
        
        # Lantern string
        pygame.draw.line(surface, self.colors['temple_dark'],
                        (lantern['x'], lantern['base_y'] - 30),
                        (x, y - height // 2), 1)
        
        # Lantern body
        points = [
            (x - width // 2, y - height // 2),
            (x + width // 2, y - height // 2),
            (x + width // 2 - 3, y + height // 2),
            (x - width // 2 + 3, y + height // 2),
        ]
        pygame.draw.polygon(surface, self.colors['lantern_red'], points)
        pygame.draw.polygon(surface, self.colors['temple_dark'], points, 1)
        
        # Decorative lines
        for i in range(3):
            line_y = y - height // 2 + (i + 1) * (height // 4)
            pygame.draw.line(surface, self.colors['gold_dim'],
                           (x - width // 2 + 2, line_y),
                           (x + width // 2 - 2, line_y), 1)
        
        lantern['glow_pulse'] += 0.03
    
    def _draw_incense(self, surface: pygame.Surface):
        """Draw incense smoke particles"""
        # Spawn new incense particles
        if self.frame_count % 3 == 0:
            # Three incense burner positions
            positions = [(150, 480), (300, 480), (450, 480)]
            for px, py in positions:
                self.incense_particles.append({
                    'x': px + random.uniform(-3, 3),
                    'y': py,
                    'vx': random.uniform(-0.3, 0.3),
                    'vy': random.uniform(-1, -0.5),
                    'life': 120,
                    'size': random.randint(3, 6),
                })
        
        # Update and draw particles
        for particle in self.incense_particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1
            
            # Wave motion
            particle['vx'] += math.sin(self.frame_count * 0.05) * 0.02
            
            if particle['life'] <= 0:
                self.incense_particles.remove(particle)
                continue
            
            # Draw smoke
            alpha = int((particle['life'] / 120) * 40)
            color = (*self.colors['incense_smoke'][:3], alpha)
            smoke_surface = pygame.Surface((particle['size'] * 2, particle['size'] * 2), pygame.SRCALPHA)
            pygame.draw.circle(smoke_surface, color, 
                             (particle['size'], particle['size']), 
                             particle['size'])
            surface.blit(smoke_surface, (particle['x'] - particle['size'], 
                                        particle['y'] - particle['size']))
        
        # Draw incense burners (darker colors)
        positions = [(150, 480), (300, 480), (450, 480)]
        for px, py in positions:
            # Burner base (darker)
            pygame.draw.rect(surface, self.colors['temple_main'],
                           (px - 10, py - 5, 20, 10))
            pygame.draw.rect(surface, self.colors['temple_dark'],
                           (px - 10, py - 5, 20, 10), 1)
            # Incense sticks (darker brown)
            for i in range(-1, 2):
                pygame.draw.line(surface, (50, 40, 35),
                               (px + i * 3, py - 5),
                               (px + i * 3, py - 15), 1)
                # Glowing tips (dimmer)
                pygame.draw.circle(surface, (180, 80, 50),
                                 (px + i * 3, py - 15), 1)
    
    def _draw_training_dummy(self, surface: pygame.Surface, dummy: Dict[str, Any]):
        """Draw a martial arts training dummy"""
        x, y = dummy['x'], dummy['y']
        
        # Apply hit animation
        if dummy['hit_animation'] > 0:
            offset = int(dummy['hit_animation'] * 5)
            x += random.randint(-offset, offset)
            dummy['hit_animation'] -= dummy['recovery_speed']
        
        # Wooden post (darker)
        pygame.draw.rect(surface, self.colors['temple_main'],
                        (x - 8, y - 40, 16, 60))
        pygame.draw.rect(surface, self.colors['temple_dark'],
                        (x - 8, y - 40, 16, 60), 1)
        
        # Rotating arms (darker)
        arm_angle = dummy['rotation']
        for angle_offset in [0, math.pi/2, math.pi, 3*math.pi/2]:
            arm_end_x = x + math.cos(arm_angle + angle_offset) * 25
            arm_end_y = y - 20 + math.sin(arm_angle + angle_offset) * 25
            pygame.draw.line(surface, self.colors['temple_dark'],
                           (x, y - 20), (arm_end_x, arm_end_y), 3)
            # Pads at the end (much darker red)
            pygame.draw.circle(surface, self.colors['roof_dark'],
                             (int(arm_end_x), int(arm_end_y)), 5)
        
        # Base
        pygame.draw.ellipse(surface, self.colors['stone_gray'],
                          (x - 15, y + 15, 30, 10))
        
        # Rotate dummy
        dummy['rotation'] += 0.02
        
        # Random hit animation
        if random.random() < 0.005:
            dummy['hit_animation'] = 1.0
    
    def _draw_bamboo_trees(self, surface: pygame.Surface):
        """Draw bamboo silhouettes"""
        # Left side bamboo grove
        for i in range(5):
            x = 20 + i * 15
            height = 400 + random.randint(-50, 50)
            sway = math.sin(self.frame_count * 0.01 + i) * 3
            
            # Bamboo segments
            segment_height = 40
            current_y = self.height
            current_x = x
            
            while current_y > self.height - height:
                # Draw segment
                pygame.draw.line(surface, self.colors['tree_dark'],
                               (current_x, current_y),
                               (current_x + sway, current_y - segment_height), 4)
                # Node
                pygame.draw.circle(surface, self.colors['tree_dark'],
                                 (current_x + int(sway), current_y - segment_height), 5)
                current_y -= segment_height
                current_x += sway / 10
            
            # Leaves at top
            for j in range(3):
                leaf_x = current_x + random.randint(-20, 20)
                leaf_y = current_y + random.randint(-20, 0)
                pygame.draw.ellipse(surface, self.colors['tree_dark'],
                                  (leaf_x, leaf_y, 15, 5))
        
        # Right side bamboo grove (similar)
        for i in range(5):
            x = self.width - 20 - i * 15
            height = 400 + random.randint(-50, 50)
            sway = math.sin(self.frame_count * 0.01 + i + 5) * 3
            
            segment_height = 40
            current_y = self.height
            current_x = x
            
            while current_y > self.height - height:
                pygame.draw.line(surface, self.colors['tree_dark'],
                               (current_x, current_y),
                               (current_x + sway, current_y - segment_height), 4)
                pygame.draw.circle(surface, self.colors['tree_dark'],
                                 (current_x + int(sway), current_y - segment_height), 5)
                current_y -= segment_height
                current_x += sway / 10
            
            for j in range(3):
                leaf_x = current_x + random.randint(-20, 20)
                leaf_y = current_y + random.randint(-20, 0)
                pygame.draw.ellipse(surface, self.colors['tree_dark'],
                                  (leaf_x, leaf_y, 15, 5))
    
    def _draw_floating_leaves(self, surface: pygame.Surface):
        """Draw floating bamboo leaves"""
        leaf_colors = [
            (40, 60, 40),  # Dark green
            (50, 70, 50),  # Medium green
            (30, 50, 30),  # Very dark green
        ]
        
        for leaf in self.floating_leaves:
            # Update position
            leaf['x'] += leaf['vx']
            leaf['y'] += leaf['vy']
            leaf['rotation'] += leaf['rotation_speed']
            
            # Wrap around screen
            if leaf['x'] < -50:
                leaf['x'] = self.width + 50
                leaf['y'] = random.randint(-50, self.height // 2)
            if leaf['y'] > self.height + 50:
                leaf['y'] = -50
                leaf['x'] = random.randint(0, self.width)
            
            # Draw leaf
            color = leaf_colors[leaf['color_variant']]
            
            # Create rotated leaf shape
            leaf_surface = pygame.Surface((leaf['size'] * 2, leaf['size'] * 2), pygame.SRCALPHA)
            pygame.draw.ellipse(leaf_surface, color,
                              (leaf['size'] // 2, leaf['size'] // 2, 
                               leaf['size'], leaf['size'] // 2))
            
            # Rotate
            rotated = pygame.transform.rotate(leaf_surface, math.degrees(leaf['rotation']))
            surface.blit(rotated, (leaf['x'] - rotated.get_width() // 2,
                                  leaf['y'] - rotated.get_height() // 2))
    
    def _draw_mist(self, surface: pygame.Surface):
        """Draw floating mist layers"""
        for mist in self.mist_layers:
            # Update position
            mist['x'] -= mist['speed']
            if mist['x'] < -mist['width']:
                mist['x'] = 0
            
            # Draw mist
            mist_surface = pygame.Surface((mist['width'], mist['height']), pygame.SRCALPHA)
            
            # Create gradient mist effect
            for i in range(0, int(mist['width']), 20):
                alpha = int(mist['opacity'] * abs(math.sin(i / 100 + self.frame_count * 0.01)))
                color = (*self.colors['mist'][:3], alpha)
                pygame.draw.circle(mist_surface, color,
                                 (i, mist['height'] // 2), mist['height'] // 2)
            
            surface.blit(mist_surface, (mist['x'], mist['y']))
    
    def _draw_stars(self, surface: pygame.Surface):
        """Draw twinkling stars with soft glow"""
        for star in self.stars:
            # Calculate twinkle
            twinkle = abs(math.sin(self.frame_count * star['twinkle_speed'] + star['twinkle_offset']))
            brightness = star['brightness'] * twinkle
            
            if brightness > 0.3:  # Only draw visible stars
                # Create soft glow for larger stars
                if star['size'] > 1 and brightness > 0.5:
                    # Subtle glow effect
                    glow_alpha = int(20 * brightness)
                    glow_color = (255, 255, 230, glow_alpha)
                    glow_size = star['size'] * 3
                    
                    star_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                    star_surface.fill((0, 0, 0, 0))
                    pygame.draw.circle(star_surface, glow_color, 
                                     (glow_size, glow_size), glow_size)
                    surface.blit(star_surface, 
                               (star['x'] - glow_size, star['y'] - glow_size))
                
                # Draw the star itself
                color = (
                    int(255 * brightness),
                    int(255 * brightness),
                    int(230 * brightness)
                )
                
                if star['size'] == 1:
                    surface.set_at((star['x'], star['y']), color)
                else:
                    pygame.draw.circle(surface, color, (star['x'], star['y']), star['size'])
    
    def _draw_ritual_brazier(self, surface: pygame.Surface):
        """Draw ritual brazier (의식용 화로 - 불이 꺼진/켜진 상태)"""
        brazier_x = self.brazier_x
        brazier_y = self.brazier_y
        
        # 화로 받침대 (삼각 다리)
        leg_color = self.colors['temple_dark']
        # 왼쪽 다리
        pygame.draw.lines(surface, leg_color, False, [
            (brazier_x - 25, brazier_y + 30),
            (brazier_x - 15, brazier_y + 10),
            (brazier_x - 10, brazier_y)
        ], 3)
        # 오른쪽 다리
        pygame.draw.lines(surface, leg_color, False, [
            (brazier_x + 25, brazier_y + 30),
            (brazier_x + 15, brazier_y + 10),
            (brazier_x + 10, brazier_y)
        ], 3)
        # 뒤쪽 다리
        pygame.draw.lines(surface, leg_color, False, [
            (brazier_x, brazier_y + 35),
            (brazier_x, brazier_y + 10),
            (brazier_x, brazier_y)
        ], 3)
        
        # 화로 몸체 (큰 그릇 형태)
        bowl_color = self.colors['temple_main']
        bowl_dark = self.colors['temple_dark']
        
        # 그릇 바닥
        pygame.draw.ellipse(surface, bowl_dark,
                          (brazier_x - 30, brazier_y - 5, 60, 15))
        
        # 그릇 몸체 (사다리꼴)
        bowl_points = [
            (brazier_x - 35, brazier_y - 15),
            (brazier_x + 35, brazier_y - 15),
            (brazier_x + 28, brazier_y + 5),
            (brazier_x - 28, brazier_y + 5)
        ]
        pygame.draw.polygon(surface, bowl_color, bowl_points)
        pygame.draw.polygon(surface, bowl_dark, bowl_points, 2)
        
        # 화로 테두리 장식
        rim_points = [
            (brazier_x - 38, brazier_y - 18),
            (brazier_x + 38, brazier_y - 18),
            (brazier_x + 35, brazier_y - 15),
            (brazier_x - 35, brazier_y - 15)
        ]
        pygame.draw.polygon(surface, self.colors['gold_dim'], rim_points)
        
        # 화로 안의 내용물 (불이 켜진/꺼진 상태에 따라 다름)
        if self.brazier_lit:
            # 불이 붙은 상태 - 불꽃 애니메이션
            self.brazier_fire_animation += 0.15
            
            # 붉은 숯불
            for i in range(8):
                coal_x = brazier_x + random.randint(-18, 18)
                coal_y = brazier_y - 8 + random.randint(-5, 2)
                coal_w = random.randint(4, 8)
                coal_h = random.randint(3, 6)
                # 빛나는 숯 색상
                glow_intensity = abs(math.sin(self.brazier_fire_animation + i * 0.5))
                coal_color = (
                    min(255, 180 + int(75 * glow_intensity)),
                    min(255, 60 + int(40 * glow_intensity)),
                    30
                )
                pygame.draw.ellipse(surface, coal_color,
                                  (coal_x - coal_w//2, coal_y - coal_h//2, coal_w, coal_h))
            
            # 불꽃 효과
            flame_height = 25 + abs(math.sin(self.brazier_fire_animation)) * 10
            flame_width = 20 + abs(math.cos(self.brazier_fire_animation * 1.5)) * 5
            
            # 여러 층의 불꽃
            for layer in range(3):
                flame_y_offset = -10 - layer * 8
                flame_alpha = 150 - layer * 40
                flame_color = (255, 180 - layer * 40, 60 - layer * 20)
                
                # 불꽃 그리기
                flame_points = [
                    (brazier_x - flame_width//2, brazier_y + flame_y_offset),
                    (brazier_x - flame_width//3, brazier_y + flame_y_offset - flame_height//2),
                    (brazier_x, brazier_y + flame_y_offset - flame_height),
                    (brazier_x + flame_width//3, brazier_y + flame_y_offset - flame_height//2),
                    (brazier_x + flame_width//2, brazier_y + flame_y_offset),
                ]
                
                # 반투명 불꽃 효과
                flame_surface = pygame.Surface((80, 60), pygame.SRCALPHA)
                pygame.draw.polygon(flame_surface, (*flame_color, flame_alpha), 
                                  [(p[0] - brazier_x + 40, p[1] - brazier_y + 30) for p in flame_points])
                surface.blit(flame_surface, (brazier_x - 40, brazier_y - 30))
            
            # 불빛 광채 효과
            glow_radius = int(40 + abs(math.sin(self.brazier_fire_animation * 0.5)) * 10)
            glow_surface = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
            for i in range(glow_radius, 0, -2):
                alpha = int(30 * (i / glow_radius))
                pygame.draw.circle(glow_surface, (255, 150, 50, alpha), 
                                 (glow_radius, glow_radius), i)
            surface.blit(glow_surface, (brazier_x - glow_radius, brazier_y - glow_radius))
            
        else:
            # 불이 꺼진 상태
            ash_color = (45, 40, 38)  # 어두운 회색 재
            charcoal_color = (25, 20, 18)  # 검은 숯
            
            # 재 더미
            for i in range(5):
                ash_x = brazier_x + random.randint(-20, 20)
                ash_y = brazier_y - 10 + random.randint(-3, 3)
                ash_size = random.randint(3, 6)
                pygame.draw.circle(surface, ash_color, (ash_x, ash_y), ash_size)
            
            # 탄 조각들
            for i in range(8):
                coal_x = brazier_x + random.randint(-18, 18)
                coal_y = brazier_y - 8 + random.randint(-5, 2)
                coal_w = random.randint(4, 8)
                coal_h = random.randint(3, 6)
                pygame.draw.ellipse(surface, charcoal_color,
                                  (coal_x - coal_w//2, coal_y - coal_h//2, coal_w, coal_h))
        
        # 화로 측면 장식 문양
        pattern_color = self.colors['gold_dim']
        # 왼쪽 문양
        pygame.draw.circle(surface, pattern_color, (brazier_x - 20, brazier_y - 5), 3, 1)
        # 오른쪽 문양
        pygame.draw.circle(surface, pattern_color, (brazier_x + 20, brazier_y - 5), 3, 1)
        # 중앙 문양
        pygame.draw.lines(surface, pattern_color, False, [
            (brazier_x - 8, brazier_y - 2),
            (brazier_x, brazier_y - 6),
            (brazier_x + 8, brazier_y - 2)
        ], 1)
    
    def _draw_bell(self, surface: pygame.Surface):
        """Draw temple bell with animation"""
        bell_x = 100
        bell_y = 350
        
        # Bell swing animation
        self.bell_swing = math.sin(self.frame_count * 0.02) * 0.1
        
        # Bell rope
        pygame.draw.line(surface, self.colors['temple_dark'],
                        (bell_x, bell_y - 20),
                        (bell_x + self.bell_swing * 50, bell_y), 2)
        
        # Bell shape (much darker)
        bell_points = [
            (bell_x - 15 + self.bell_swing * 50, bell_y),
            (bell_x + 15 + self.bell_swing * 50, bell_y),
            (bell_x + 20 + self.bell_swing * 50, bell_y + 25),
            (bell_x - 20 + self.bell_swing * 50, bell_y + 25),
        ]
        pygame.draw.polygon(surface, self.colors['gold_dim'], bell_points)
        pygame.draw.polygon(surface, self.colors['temple_dark'], bell_points, 2)
        
        # Bell clapper
        pygame.draw.circle(surface, self.colors['temple_dark'],
                         (bell_x + int(self.bell_swing * 70), bell_y + 20), 3)
    
    def _spawn_crow(self):
        """Spawn a new crow"""
        # Limit maximum crows on screen
        if len(self.crows) >= 3:  # Max 3 crows at once
            return
            
        # Spawn from left or right side
        start_side = random.choice(['left', 'right'])
        
        if start_side == 'left':
            x = -50
            vx = random.uniform(1.5, 3.0)
        else:
            x = self.width + 50
            vx = random.uniform(-3.0, -1.5)
        
        crow = {
            'x': x,
            'y': random.randint(50, 200),  # Upper sky area (boss paddle area)
            'vx': vx,
            'vy': random.uniform(-0.3, 0.3),
            'wing_phase': random.uniform(0, math.pi * 2),
            'wing_speed': random.uniform(0.15, 0.25),
            'size': random.randint(20, 30),
            'caught': False,
            'glow_timer': 0,
            'hitbox_radius': 25,  # For collision detection
        }
        self.crows.append(crow)
    
    def _draw_crow(self, surface: pygame.Surface, crow: Dict[str, Any]):
        """Draw a flying crow with realistic bird shape"""
        if crow['caught']:
            # Draw caught effect (glow)
            glow_alpha = int(255 - crow['glow_timer'] * 5)
            if glow_alpha > 0:
                glow_surface = pygame.Surface((60, 60), pygame.SRCALPHA)
                pygame.draw.circle(glow_surface, (255, 215, 0, glow_alpha), (30, 30), 30)
                surface.blit(glow_surface, (crow['x'] - 30, crow['y'] - 30))
            crow['glow_timer'] += 1
            if crow['glow_timer'] > 50:
                return False  # Remove crow
        else:
            # Calculate wing flapping for more natural movement
            wing_flap = math.sin(crow['wing_phase']) 
            wing_angle = wing_flap * 40  # Degrees for wing rotation
            
            # Draw crow body (more bird-like silhouette)
            body_color = (15, 10, 20)  # Very dark purple-black
            
            # Body (elongated oval)
            body_length = crow['size'] * 0.8
            body_width = crow['size'] * 0.35
            pygame.draw.ellipse(surface, body_color,
                              (crow['x'] - body_length//2, crow['y'] - body_width//2,
                               body_length, body_width))
            
            # Head (smaller, more proportional)
            head_size = crow['size'] * 0.25
            head_x = crow['x'] - body_length//2 - head_size//2 + 2
            pygame.draw.circle(surface, body_color,
                             (int(head_x), int(crow['y'])), int(head_size))
            
            # Beak (triangular)
            beak_points = [
                (head_x - head_size - 3, crow['y']),
                (head_x - head_size + 2, crow['y'] - 2),
                (head_x - head_size + 2, crow['y'] + 2),
            ]
            pygame.draw.polygon(surface, body_color, beak_points)
            
            # Tail feathers
            tail_points = [
                (crow['x'] + body_length//2, crow['y']),
                (crow['x'] + body_length//2 + 8, crow['y'] - 3),
                (crow['x'] + body_length//2 + 10, crow['y']),
                (crow['x'] + body_length//2 + 8, crow['y'] + 3),
            ]
            pygame.draw.polygon(surface, body_color, tail_points)
            
            # Wings (animated with realistic flapping)
            wing_lift = abs(wing_flap) * 15  # How high wings go up/down
            wing_spread = crow['size'] * 0.8  # Wing span
            
            # Left wing (more detailed shape)
            if wing_flap > 0:  # Wing up
                wing_points_left = [
                    (crow['x'] - 3, crow['y'] - 2),
                    (crow['x'] - wing_spread, crow['y'] - wing_lift),
                    (crow['x'] - wing_spread * 0.8, crow['y'] - wing_lift * 1.2),
                    (crow['x'] - wing_spread * 0.5, crow['y'] - wing_lift * 0.5),
                    (crow['x'] - 5, crow['y'] + 3),
                ]
            else:  # Wing down
                wing_points_left = [
                    (crow['x'] - 3, crow['y'] - 2),
                    (crow['x'] - wing_spread, crow['y'] + wing_lift * 0.7),
                    (crow['x'] - wing_spread * 0.8, crow['y'] + wing_lift),
                    (crow['x'] - wing_spread * 0.5, crow['y'] + wing_lift * 0.3),
                    (crow['x'] - 5, crow['y'] + 3),
                ]
            pygame.draw.polygon(surface, body_color, wing_points_left)
            
            # Right wing (mirror of left)
            if wing_flap > 0:  # Wing up
                wing_points_right = [
                    (crow['x'] + 3, crow['y'] - 2),
                    (crow['x'] + wing_spread, crow['y'] - wing_lift),
                    (crow['x'] + wing_spread * 0.8, crow['y'] - wing_lift * 1.2),
                    (crow['x'] + wing_spread * 0.5, crow['y'] - wing_lift * 0.5),
                    (crow['x'] + 5, crow['y'] + 3),
                ]
            else:  # Wing down
                wing_points_right = [
                    (crow['x'] + 3, crow['y'] - 2),
                    (crow['x'] + wing_spread, crow['y'] + wing_lift * 0.7),
                    (crow['x'] + wing_spread * 0.8, crow['y'] + wing_lift),
                    (crow['x'] + wing_spread * 0.5, crow['y'] + wing_lift * 0.3),
                    (crow['x'] + 5, crow['y'] + 3),
                ]
            pygame.draw.polygon(surface, body_color, wing_points_right)
            
            # Eye (small red dot for mystical effect)
            eye_x = int(head_x - 2)
            pygame.draw.circle(surface, (150, 30, 30), (eye_x, crow['y'] - 2), 2)
            
            # Small body details (feather texture)
            for i in range(3):
                detail_x = crow['x'] - body_length//4 + i * 6
                pygame.draw.line(surface, (25, 20, 30), 
                               (detail_x, crow['y'] - 2), 
                               (detail_x + 2, crow['y'] + 2), 1)
            
            # Update wing animation
            crow['wing_phase'] += crow['wing_speed']
        
        return True  # Keep crow
    
    def _update_crows(self):
        """Update crow positions and spawn new ones"""
        # Update existing crows
        for crow in self.crows[:]:
            if not crow['caught']:
                crow['x'] += crow['vx']
                crow['y'] += crow['vy']
                
                # Slight vertical movement
                crow['vy'] += math.sin(self.frame_count * 0.05) * 0.02
                
                # Remove if off screen
                if crow['x'] < -100 or crow['x'] > self.width + 100:
                    self.crows.remove(crow)
        
        # Spawn new crow occasionally
        self.crow_spawn_timer += 1
        if self.crow_spawn_timer >= self.crow_spawn_interval:
            self._spawn_crow()
            self.crow_spawn_timer = 0
            self.crow_spawn_interval = random.randint(720, 1380)  # 12-23 seconds
    
    def get_crow_positions(self) -> List[Dict[str, Any]]:
        """Get positions of all active crows for collision detection"""
        return [{'x': crow['x'], 'y': crow['y'], 'radius': crow['hitbox_radius'], 'index': i}
                for i, crow in enumerate(self.crows) if not crow['caught']]
    
    def catch_crow(self, index: int):
        """Crow is hit by ball - create explosion fragments"""
        if 0 <= index < len(self.crows):
            crow = self.crows[index]
            # Create explosion fragments instead of corpse
            self._create_crow_explosion(crow['x'], crow['y'], crow['size'])
            # Remove the living crow
            self.crows.pop(index)
            return True
        return False
    
    def _create_crow_explosion(self, x, y, size):
        """Create explosion fragments when crow is hit"""
        # Create 8-12 feather fragments
        num_fragments = random.randint(8, 12)
        
        for i in range(num_fragments):
            angle = (i / num_fragments) * 2 * math.pi + random.uniform(-0.3, 0.3)
            speed = random.uniform(2, 6)
            
            fragment = {
                'x': x,
                'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - random.uniform(1, 3),  # Upward bias
                'size': random.randint(3, size // 2),
                'rotation': random.uniform(0, 360),
                'rotation_speed': random.uniform(-15, 15),
                'gravity': 0.15,
                'life': random.randint(60, 90),  # 1-1.5 seconds
                'color': random.choice([(20, 15, 25), (30, 25, 35), (15, 10, 20)]),  # Dark feather colors
                'type': random.choice(['feather', 'fragment']),
                'opacity': 255
            }
            self.crow_fragments.append(fragment)
        
        # Create some small particles for effect
        for _ in range(15):
            particle_angle = random.uniform(0, 2 * math.pi)
            particle_speed = random.uniform(1, 4)
            
            particle = {
                'x': x,
                'y': y,
                'vx': math.cos(particle_angle) * particle_speed,
                'vy': math.sin(particle_angle) * particle_speed - 2,
                'size': random.randint(1, 3),
                'life': random.randint(20, 40),
                'color': (40, 35, 45),
                'opacity': 200
            }
            self.crow_particles.append(particle)
    
    def _update_crow_fragments(self):
        """Update crow explosion fragments"""
        for fragment in self.crow_fragments[:]:
            # Update position
            fragment['x'] += fragment['vx']
            fragment['y'] += fragment['vy']
            
            # Apply gravity
            fragment['vy'] += fragment['gravity']
            
            # Air resistance
            fragment['vx'] *= 0.98
            
            # Update rotation
            fragment['rotation'] += fragment['rotation_speed']
            
            # Update life
            fragment['life'] -= 1
            
            # Fade out
            if fragment['life'] < 30:
                fragment['opacity'] = int(255 * (fragment['life'] / 30))
            
            # Remove if dead or off screen
            if fragment['life'] <= 0 or fragment['y'] > self.height + 50:
                self.crow_fragments.remove(fragment)
    
    def _update_crow_particles(self):
        """Update crow explosion particles"""
        for particle in self.crow_particles[:]:
            # Update position
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            
            # Apply gravity
            particle['vy'] += 0.1
            
            # Update life
            particle['life'] -= 1
            
            # Fade out
            particle['opacity'] = int(particle['opacity'] * 0.95)
            
            # Remove if dead
            if particle['life'] <= 0 or particle['opacity'] < 10:
                self.crow_particles.remove(particle)
    
    def _update_crow_corpses(self):
        """Update falling crow corpses"""
        for corpse in self.crow_corpses[:]:
            if not corpse['collected']:
                # Apply physics
                corpse['vy'] += corpse['gravity']
                # Cap maximum falling speed for easier catching
                if corpse['vy'] > 3.0:
                    corpse['vy'] = 3.0
                corpse['y'] += corpse['vy']
                corpse['x'] += corpse['vx']
                corpse['vx'] *= 0.99  # Lighter air resistance
                corpse['rotation'] += corpse['rotation_speed']
                
                # Remove if falls off screen bottom
                if corpse['y'] > self.height + 50:
                    self.crow_corpses.remove(corpse)
    
    def _draw_crow_corpse(self, surface: pygame.Surface, corpse: Dict[str, Any]):
        """Draw a falling crow corpse"""
        if corpse['collected']:
            # Draw collection effect
            corpse['opacity'] -= 15
            if corpse['opacity'] <= 0:
                return False
        
        # Create rotated corpse surface
        corpse_surface = pygame.Surface((corpse['size'] * 3, corpse['size'] * 3), pygame.SRCALPHA)
        
        # Draw dead crow (wings spread in death pose)
        body_color = (40, 35, 45, corpse['opacity'])  # Darker dead color
        
        # Body (centered for rotation)
        center_x = corpse['size'] * 1.5
        center_y = corpse['size'] * 1.5
        
        # Body (elongated oval - same as living crow)
        body_length = corpse['size'] * 0.8
        body_width = corpse['size'] * 0.35
        pygame.draw.ellipse(corpse_surface, body_color,
                          (center_x - body_length//2, center_y - body_width//2,
                           body_length, body_width))
        
        # Head (drooping)
        head_size = corpse['size'] * 0.25
        head_x = center_x - body_length//2 - head_size//2 + 2
        pygame.draw.circle(corpse_surface, body_color,
                         (int(head_x), int(center_y + 3)), int(head_size))
        
        # Spread wings (death pose - fully extended)
        wing_spread = corpse['size'] * 1.2
        
        # Left wing (spread out in death)
        wing_points_left = [
            (center_x - 3, center_y - 2),
            (center_x - wing_spread, center_y - 8),
            (center_x - wing_spread * 0.9, center_y),
            (center_x - wing_spread * 0.7, center_y + 5),
            (center_x - 5, center_y + 3),
        ]
        pygame.draw.polygon(corpse_surface, body_color, wing_points_left)
        
        # Right wing (spread out in death)
        wing_points_right = [
            (center_x + 3, center_y - 2),
            (center_x + wing_spread, center_y - 8),
            (center_x + wing_spread * 0.9, center_y),
            (center_x + wing_spread * 0.7, center_y + 5),
            (center_x + 5, center_y + 3),
        ]
        pygame.draw.polygon(corpse_surface, body_color, wing_points_right)
        
        # Tail feathers (limp)
        tail_points = [
            (center_x + body_length//2, center_y),
            (center_x + body_length//2 + 6, center_y + 2),
            (center_x + body_length//2 + 8, center_y),
            (center_x + body_length//2 + 6, center_y - 2),
        ]
        pygame.draw.polygon(corpse_surface, body_color, tail_points)
        
        # Dead eye (X mark)
        eye_x = int(head_x - 2)
        pygame.draw.line(corpse_surface, (80, 20, 20), 
                        (eye_x - 2, center_y + 1), (eye_x + 2, center_y + 5), 1)
        pygame.draw.line(corpse_surface, (80, 20, 20), 
                        (eye_x + 2, center_y + 1), (eye_x - 2, center_y + 5), 1)
        
        # Rotate the corpse
        rotated_corpse = pygame.transform.rotate(corpse_surface, corpse['rotation'])
        
        # Blit to main surface
        corpse_rect = rotated_corpse.get_rect(center=(int(corpse['x']), int(corpse['y'])))
        surface.blit(rotated_corpse, corpse_rect)
        
        return corpse['opacity'] > 0
    
    def get_crow_corpse_positions(self) -> List[Dict[str, Any]]:
        """Get positions of all falling crow corpses for collision detection with player paddle"""
        return [{'x': corpse['x'], 'y': corpse['y'], 'radius': 20, 'index': i}
                for i, corpse in enumerate(self.crow_corpses) if not corpse['collected']]
    
    def collect_corpse(self, index: int):
        """Mark a corpse as collected by player paddle"""
        if 0 <= index < len(self.crow_corpses):
            self.crow_corpses[index]['collected'] = True
            return True
        return False
    
    def trigger_monk_swing(self, ball_x: float, ball_y: float, last_hit_by: str = "player") -> bool:
        """Check if monk should swing staff when both player and boss hit ball
        Returns True if monk deflects the ball"""
        # 플레이어나 보스가 친 공 모두에 반응
        if last_hit_by not in ["player", "boss"]:
            return False
        
        # 보스가 친 공일 때 특별 처리 플래그
        is_boss_ball = (last_hit_by == "boss")
            
        # 디버그 출력 줄이기 - 몽크가 있을 때만 출력
        
        for i, monk in enumerate(self.monks):
            
            # Check conditions for swinging (명상 상태도 봉 휘두르기 가능하도록 수정)
            # 중요: 이미 스윙 중이면 다시 스윙하지 않음
            if (monk['state'] not in ['swinging', 'returning'] and
                monk['swing_cooldown'] <= 0 and
                monk['swing_count'] < 2 and
                monk['can_deflect'] and
                not monk['returning_to_temple']):
                
                # Calculate distance from monk to ball
                distance = math.sqrt((monk['x'] - ball_x)**2 + (monk['y'] - ball_y)**2)
                
                # 공이 범위를 벗어나면 기회 플래그 리셋
                if distance >= 60:  # 80 -> 60으로 범위 축소
                    monk['swing_chance_used'] = False
                # 스윙 확률 체크 (보스 공에 대해서는 모든 몽크가 30% 확률)
                elif distance < 60 and not monk['swing_chance_used']:  # 80 -> 60으로 범위 축소
                    monk['swing_chance_used'] = True  # 이번 패스에서 기회 사용됨
                    
                    if is_boss_ball:
                        # 보스가 친 공: 모든 몽크가 30% 확률
                        swing_probability = 0.3
                    else:
                        # 플레이어가 친 공: 기존 확률 (일반 20%, 연막탄 30%)
                        swing_probability = monk.get('swing_chance', 0.2)
                    
                    if random.random() < swing_probability:
                        target_type = "보스 공" if is_boss_ball else "플레이어 공"
                        print(f"    {i} {target_type}  ! : {distance:.1f}, : ({monk['x']:.0f}, {monk['y']:.0f})")
                        # Start swing animation
                        monk['state'] = 'swinging'
                        monk['swing_animation'] = 0
                        # swing_count는 스윙이 완료된 후에 증가시켜야 함
                        monk['has_hit_ball'] = False  # Reset hit flag for new swing
                        monk['is_countering_boss'] = is_boss_ball  # 보스 공 반격 여부 저장
                        
                        # Face the ball
                        monk['direction'] = 1 if ball_x > monk['x'] else -1
                        print(f"   : {'' if monk['direction'] == 1 else ''}")
                        
                        return True  # Monk will deflect the ball
        
        return False
    
    def get_monk_staff_deflection(self, ball_x: float = 300, ball_y: float = 400) -> tuple:
        """Get deflection angle for ball based on monk's staff swing
        Returns (deflection_x, deflection_y) or None if no deflection
        Note: Ball speed is increased by 50~80% in pingfighter.py when monk hits"""
        # 몽크가 있는지 체크
        if not self.monks:
            return None
            
        for i, monk in enumerate(self.monks):
            if monk['state'] == 'swinging' and not monk['has_hit_ball']:
                # Only check if this swing hasn't hit the ball yet
                if 10 <= monk['swing_animation'] <= 15:
                    # During the swing phase, deflect the ball
                    # 보스 공을 칠 때는 커브 추가
                    is_countering_boss = monk.get('is_countering_boss', False)
                    
                    if is_countering_boss:
                        # 보스 공 반격: 확실히 위쪽(보스 방향)으로 반격
                        # 현재 공 속도를 반전시켜 위로 보냄
                        
                        # 강한 커브 추가 (좌우 랜덤)
                        curve_direction = random.choice([-1, 1])
                        deflection_x = curve_direction * random.uniform(0.3, 0.6)  # 적당한 커브
                        
                        # 위쪽으로 매우 강하게 (공의 y 속도를 완전 반전 + 추가 부스트)
                        # deflection은 현재 속도에 더해지므로, 아래로 가는 공을 위로 보내려면 큰 음수값 필요
                        deflection_y = -abs(random.uniform(2.5, 3.5))  # 강한 위쪽 힘
                        
                        # 속도 부스트 (30% 추가)
                        speed_multiplier = monk.get('speed_boost', 1.0) * 1.3
                        deflection_x *= speed_multiplier
                        deflection_y *= speed_multiplier
                        
                        print(f"     !  ! : {deflection_x:.2f},  : {deflection_y:.2f}")
                    else:
                        # 플레이어 공 반격: 보스 방향을 고려한 균형잡힌 반격
                        # 몽크 위치 기준으로 공이 어느 쪽에서 왔는지 확인
                        ball_from_left = ball_x < monk['x']
                        
                        # 공을 보스 쪽으로 보내기 위한 각도 계산
                        # 공이 왼쪽에서 왔으면 오른쪽으로, 오른쪽에서 왔으면 왼쪽으로
                        if ball_from_left:
                            # 공이 왼쪽에서 옴 -> 오른쪽 위로 반격
                            deflection_angle = -math.pi / 3  # 60도 위쪽 오른쪽
                            deflection_x = random.uniform(0.3, 0.5)  # 오른쪽
                        else:
                            # 공이 오른쪽에서 옴 -> 왼쪽 위로 반격
                            deflection_angle = -2 * math.pi / 3  # 120도 위쪽 왼쪽
                            deflection_x = random.uniform(-0.5, -0.3)  # 왼쪽
                        
                        # 위쪽으로 보내기 (보스 방향)
                        deflection_y = random.uniform(-0.4, -0.6)
                        
                        # 연막탄 몽크는 30% 더 강하게 공을 튕김
                        speed_multiplier = monk.get('speed_boost', 1.0)  # 기본 1.0, 연막탄 몽크는 1.3
                        deflection_x *= speed_multiplier
                        deflection_y *= speed_multiplier
                        
                        # 추가 랜덤성 부여
                        deflection_x += random.uniform(-0.1, 0.1)
                        
                        print(f"     !  : {'' if ball_from_left else ''} →"
                              f"반격 방향: {'오른쪽' if deflection_x > 0 else '왼쪽'} 위 ({deflection_x:.2f}, {deflection_y:.2f})")
                    
                    if not is_countering_boss:
                        print(f"    ! : {math.degrees(deflection_angle):.1f}°,"
                              f"방향 변경: ({deflection_x:.2f}, {deflection_y:.2f})")
                    
                    # Mark that this swing has hit the ball
                    monk['has_hit_ball'] = True
                    
                    # Create hit effect at monk's staff position
                    self._create_monk_hit_effect(monk)
                    
                    return (deflection_x, deflection_y)
        
        return None
    
    def _spawn_monk(self, is_smoke_grenade_monk=False):
        """Spawn a monk that walks out from temple entrance"""
        # Only allow 1 normal monk at a time (연막탄 몽크는 예외)
        if not is_smoke_grenade_monk and len([m for m in self.monks if not m.get('is_smoke_grenade_monk', False)]) >= 1:
            return
        
        # Spawn from temple entrance
        temple_x = self.width // 2
        entrance_y = 450  # Temple entrance position
        
        monk = {
            'x': temple_x,
            'y': entrance_y,
            'target_x': random.choice([100, 200, 400, 500]),  # Random wander target
            'target_y': random.randint(480, 550),
            'speed': 0.3,  # Very slow walking speed
            'direction': random.choice([-1, 1]),  # Initial facing direction
            'walking_phase': 0,
            'robe_sway': 0,
            'meditation_timer': 0,
            'state': 'walking',  # 'walking', 'standing', 'meditating', 'swinging', 'returning'
            'state_timer': random.randint(180, 360),  # 3-6 seconds per state
            'staff_angle': 0,
            'opacity': 0,  # Fade in effect
            'fade_in': True,
            'swing_count': 0,  # Number of times staff has been swung
            'swing_animation': 0,  # Current swing animation frame
            'swing_cooldown': 0,  # Cooldown between swings
            'can_deflect': True,  # Whether monk can deflect balls
            'returning_to_temple': False,  # Is monk going back to temple
            'has_hit_ball': False,  # Whether this swing has already hit the ball
            'swing_chance_used': False,  # Whether chance check was already done for current ball pass
            'is_smoke_grenade_monk': is_smoke_grenade_monk,  # 연막탄으로 소환된 몽크인지
            'smoke_return_timer': 0,  # 연막탄 종료 후 복귀 타이머
        }
        self.monks.append(monk)
    
    def _update_monks(self):
        """Update monk positions and behaviors"""
        # Don't spawn monks if temple is destroyed
        if self.temple_destroyed:
            # Still update existing monks if any
            for monk in self.monks[:]:
                # Existing monk update logic continues...
                pass
            return
            
        # Spawn timer
        self.monk_spawn_timer += 1
        if self.monk_spawn_timer >= self.monk_spawn_interval:
            self._spawn_monk()
            print(f"  !")
            self.monk_spawn_timer = 0
            self.monk_spawn_interval = random.randint(1200, 2400)  # 20~40초 (일반 스폰)
        
        # Update existing monks
        for monk in self.monks[:]:
            # Fade in effect
            if monk['fade_in'] and monk['opacity'] < 255:
                monk['opacity'] = min(255, monk['opacity'] + 5)
                if monk['opacity'] >= 255:
                    monk['fade_in'] = False
            
            # Update swing cooldown
            if monk['swing_cooldown'] > 0:
                monk['swing_cooldown'] -= 1
            
            # 연막탄 몽크의 복귀 타이머 처리 (라운드 관계없이 계속 진행)
            if monk.get('is_smoke_grenade_monk', False):
                # 타이머가 있고 아직 복귀중이 아닌 경우
                if monk.get('smoke_return_timer', 0) > 0 and not monk.get('returning_to_temple', False):
                    monk['smoke_return_timer'] -= 1
                    
                    # 남은 시간 표시 (5초마다)
                    if monk['smoke_return_timer'] % 300 == 0 and monk['smoke_return_timer'] > 0:
                        remaining_seconds = monk['smoke_return_timer'] / 60
                        monk_state = monk.get('state', 'unknown')
                        print(f"⏰    {remaining_seconds:.0f}  (: {monk_state},    )")
                    
                    # 타이머가 0이 되면 즉시 복귀 시작
                    if monk['smoke_return_timer'] <= 0:
                        print(f"     ! (30  )")
                        monk['returning_to_temple'] = True
                        monk['state'] = 'returning'
                        monk['target_x'] = self.width // 2  # Temple entrance
                        monk['target_y'] = 450
                        # 스윙 카운트에 관계없이 강제 복귀
                        monk['swing_count'] = 99  # 복귀 우선
            
            # Check if monk should return to temple after 2 swings (백업 체크)
            # 이미 스윙 완료 시점에서 처리하지만, 혹시 놓친 경우를 위한 백업
            if monk['swing_count'] >= 2 and not monk['returning_to_temple'] and monk['state'] != 'returning':
                print(f"  :  2  !")
                monk['returning_to_temple'] = True
                monk['state'] = 'returning'
                monk['target_x'] = self.width // 2  # Temple entrance
                monk['target_y'] = 450
            
            # State timer (don't change state if swinging or returning)
            if monk['state'] not in ['swinging', 'returning']:
                monk['state_timer'] -= 1
                if monk['state_timer'] <= 0:
                    # Change state
                    states = ['walking', 'standing', 'meditating']
                    monk['state'] = random.choice(states)
                    monk['state_timer'] = random.randint(180, 360)
                    
                    # Set new target for walking
                    if monk['state'] == 'walking':
                        monk['target_x'] = random.randint(100, 500)
                        monk['target_y'] = random.randint(480, 550)
            
            # Update based on state
            if monk['state'] == 'walking':
                # Move towards target
                dx = monk['target_x'] - monk['x']
                dy = monk['target_y'] - monk['y']
                distance = math.sqrt(dx*dx + dy*dy)
                
                if distance > 5:
                    # Normalize and apply speed
                    monk['x'] += (dx / distance) * monk['speed']
                    monk['y'] += (dy / distance) * monk['speed']
                    monk['walking_phase'] += 0.05
                    monk['direction'] = 1 if dx > 0 else -1
                else:
                    # Reached target, change state
                    monk['state'] = random.choice(['standing', 'meditating'])
                    monk['state_timer'] = random.randint(180, 360)
            
            elif monk['state'] == 'standing':
                # Just standing, slight robe sway
                monk['robe_sway'] = math.sin(self.frame_count * 0.02) * 2
                
            elif monk['state'] == 'meditating':
                # Meditation pose
                monk['meditation_timer'] += 1
                monk['robe_sway'] = math.sin(self.frame_count * 0.01) * 1
            
            elif monk['state'] == 'swinging':
                # Staff swing animation
                monk['swing_animation'] += 1
                
                if monk['swing_animation'] < 10:
                    # Wind up
                    monk['staff_angle'] = -math.pi / 4 * (monk['swing_animation'] / 10)
                elif monk['swing_animation'] < 20:
                    # Swing through
                    progress = (monk['swing_animation'] - 10) / 10
                    monk['staff_angle'] = -math.pi / 4 + (math.pi / 2) * progress
                else:
                    # Swing complete
                    monk['swing_count'] += 1  # 스윙이 완료된 후에 카운트 증가
                    print(f" DEBUG:   !  : {monk['swing_count']}/2")
                    
                    # 2번 스윙 완료 시 즉시 사원으로 복귀
                    if monk['swing_count'] >= 2:
                        print(f"  2  !")
                        monk['returning_to_temple'] = True
                        monk['state'] = 'returning'
                        monk['target_x'] = self.width // 2  # Temple entrance
                        monk['target_y'] = 450
                    else:
                        monk['state'] = 'standing'
                        monk['state_timer'] = 60  # Brief pause after swing
                    
                    monk['swing_animation'] = 0
                    monk['staff_angle'] = 0
                    monk['swing_cooldown'] = 120  # 2 second cooldown
                    monk['has_hit_ball'] = False  # Reset for next swing
            
            # 넉백 상태 처리 (Stage 5 화염 등에 의한 넉백)
            elif monk['state'] == 'knockback':
                # 넉백 속도가 있으면 적용
                if 'knockback_vel_x' in monk and 'knockback_vel_y' in monk:
                    # 위치 업데이트
                    monk['x'] += monk['knockback_vel_x']
                    monk['y'] += monk['knockback_vel_y']
                    
                    # 넉백 속도 감속 (마찰)
                    monk['knockback_vel_x'] *= 0.9
                    monk['knockback_vel_y'] *= 0.9
                    
                    # 맵 경계 체크
                    monk['x'] = max(30, min(self.width - 30, monk['x']))
                    monk['y'] = max(450, min(self.height - 50, monk['y']))
                    
                    # 넉백 타이머 감소
                    if 'knockback_timer' in monk:
                        monk['knockback_timer'] -= 1
                        if monk['knockback_timer'] <= 0:
                            # 넉백 끝, 일반 상태로 복귀
                            monk['state'] = 'standing'
                            monk['state_timer'] = 60
                            monk['knockback_vel_x'] = 0
                            monk['knockback_vel_y'] = 0
                            print(f"   ,")
            
            # returning_to_temple이 True인데 state가 returning이 아닌 경우 강제 설정
            if monk.get('returning_to_temple', False) and monk['state'] != 'returning':
                monk['state'] = 'returning'
                monk['target_x'] = self.width // 2
                monk['target_y'] = 450
                print(f"    : returning")
            
            elif monk['state'] == 'returning':
                # Return to temple entrance
                dx = monk['target_x'] - monk['x']
                dy = monk['target_y'] - monk['y']
                distance = math.sqrt(dx*dx + dy*dy)
                
                if distance > 5:
                    # Move towards temple at slightly faster speed
                    monk['x'] += (dx / distance) * (monk['speed'] * 2)
                    monk['y'] += (dy / distance) * (monk['speed'] * 2)
                    monk['walking_phase'] += 0.08
                    monk['direction'] = 1 if dx > 0 else -1
                else:
                    # Reached temple, start fading out
                    monk['opacity'] -= 10
                    if monk['opacity'] <= 0:
                        self.monks.remove(monk)
                        
                        # 연막탄 몽크가 모두 사원에 들어갔는지 체크
                        remaining_smoke_monks = [m for m in self.monks if m.get('is_smoke_grenade_monk', False)]
                        if len(remaining_smoke_monks) == 0 and self.brazier_lit:
                            # 모든 연막탄 몽크가 사원에 들어가면 화로 불 끄기
                            self.brazier_lit = False
                            print(f"       !")
                        
                        # 몽크가 사원으로 들어간 후 다음 스폰까지 15~30초
                        if not monk.get('is_smoke_grenade_monk', False):
                            self.monk_spawn_timer = 0
                            self.monk_spawn_interval = random.randint(900, 1800)  # 15~30초
                            print(f"   .   {self.monk_spawn_interval/60:.0f}")
                        continue
            
            # Update staff angle (if not swinging)
            if monk['state'] != 'swinging':
                monk['staff_angle'] = math.sin(monk['walking_phase']) * 0.1
            
            # Remove monk if they've been around too long (after 2 minutes)
            if not monk['fade_in'] and random.random() < 0.0002:  # Small chance to leave
                monk['fade_in'] = True  # Reuse for fade out
                monk['opacity'] -= 5
                if monk['opacity'] <= 0:
                    self.monks.remove(monk)
    
    def _create_monk_hit_effect(self, monk: Dict[str, Any]):
        """Create visual effect when monk hits the ball"""
        # Calculate staff end position for effect
        staff_angle = monk['staff_angle'] - math.pi/2
        staff_length = 50
        staff_x = monk['x'] + math.cos(staff_angle) * staff_length
        staff_y = monk['y'] - 15 + math.sin(staff_angle) * staff_length
        
        # Add shockwave effect
        self.monk_hit_effects.append({
            'x': staff_x,
            'y': staff_y,
            'radius': 5,
            'max_radius': 40,
            'alpha': 255,
            'color': (255, 220, 100),  # Golden yellow
            'type': 'shockwave'
        })
        
        # Add spark particles
        for _ in range(8):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 5)
            self.monk_hit_effects.append({
                'x': staff_x,
                'y': staff_y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': 20,
                'color': (255, random.randint(200, 255), random.randint(50, 150)),
                'type': 'spark'
            })
    
    def _update_monk_death_effects(self):
        """Update monk death particles and body parts"""
        # Update death particles
        for particle in self.monk_death_particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['vy'] += particle.get('gravity', 0.2)
            particle['lifetime'] -= 1
            
            # Fade out dust particles
            if 'opacity' in particle:
                particle['opacity'] = int(particle['opacity'] * 0.95)
            
            if particle['lifetime'] <= 0:
                self.monk_death_particles.remove(particle)
        
        # Update body parts
        for part in self.monk_body_parts[:]:
            part['x'] += part['vx']
            part['y'] += part['vy']
            part['vy'] += part['gravity']
            part['rotation'] += part['rotation_speed']
            part['lifetime'] -= 1
            
            # Slow down horizontal movement
            part['vx'] *= 0.98
            
            # Remove if off screen or expired
            if part['lifetime'] <= 0 or part['y'] > self.height + 50:
                self.monk_body_parts.remove(part)
    
    def _update_monk_hit_effects(self):
        """Update monk hit effects"""
        effects_to_remove = []
        
        for effect in self.monk_hit_effects:
            if effect['type'] == 'shockwave':
                # Expand shockwave
                effect['radius'] += 3
                effect['alpha'] = max(0, 255 - (effect['radius'] / effect['max_radius']) * 255)
                
                if effect['radius'] >= effect['max_radius']:
                    effects_to_remove.append(effect)
                    
            elif effect['type'] == 'spark':
                # Move spark particle
                effect['x'] += effect['vx']
                effect['y'] += effect['vy']
                effect['vy'] += 0.3  # Gravity
                effect['life'] -= 1
                
                if effect['life'] <= 0:
                    effects_to_remove.append(effect)
        
        # Remove finished effects
        for effect in effects_to_remove:
            if effect in self.monk_hit_effects:
                self.monk_hit_effects.remove(effect)
    
    def _draw_monk_death_effects(self, surface: pygame.Surface):
        """Draw monk death particles and body parts"""
        # Draw particles
        for particle in self.monk_death_particles:
            if particle.get('type') == 'shockwave':
                # Draw expanding shockwave
                particle['radius'] += 3
                if particle['radius'] < particle['max_radius']:
                    alpha = int(255 * (1 - particle['radius'] / particle['max_radius']))
                    color = (*particle['color'], alpha)
                    pygame.draw.circle(surface, color,
                                     (int(particle['x']), int(particle['y'])),
                                     int(particle['radius']), 2)
            elif particle.get('type') == 'sparkle':
                # Draw sparkle with glow
                pygame.draw.circle(surface, particle['color'],
                                 (int(particle['x']), int(particle['y'])),
                                 particle['size'])
                # Add glow
                glow_surf = pygame.Surface((particle['size']*4, particle['size']*4), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*particle['color'], 50),
                                 (particle['size']*2, particle['size']*2),
                                 particle['size']*2)
                surface.blit(glow_surf, (particle['x'] - particle['size']*2,
                                       particle['y'] - particle['size']*2))
            elif 'opacity' in particle and particle['opacity'] > 0:
                # Dust particles with opacity
                color = (*particle['color'], particle['opacity'])
                pygame.draw.circle(surface, color, 
                                 (int(particle['x']), int(particle['y'])), 
                                 particle['size'])
            else:
                # Regular particles (blood, gold, etc)
                pygame.draw.circle(surface, particle['color'], 
                                 (int(particle['x']), int(particle['y'])), 
                                 particle['size'])
                
                # Add glow for golden particles
                if particle.get('glow'):
                    glow_surf = pygame.Surface((particle['size']*3, particle['size']*3), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surf, (*particle['color'], 30),
                                     (particle['size']*1.5, particle['size']*1.5),
                                     particle['size']*1.5)
                    surface.blit(glow_surf, (particle['x'] - particle['size']*1.5,
                                           particle['y'] - particle['size']*1.5))
        
        # Draw body parts
        for part in self.monk_body_parts:
            # Create surface for rotation
            size = part['size'] * 2
            part_surface = pygame.Surface((size, size), pygame.SRCALPHA)
            
            # Draw different body part shapes
            if part['type'] == 'head':
                pygame.draw.circle(part_surface, part['color'], 
                                 (size//2, size//2), part['size']//2)
            elif part['type'] == 'torso':
                pygame.draw.ellipse(part_surface, part['color'],
                                  (size//4, size//4, size//2, size//2))
            elif part['type'] in ['arm', 'leg']:
                pygame.draw.rect(part_surface, part['color'],
                               (size//3, 0, size//3, size))
            
            # Add glow for hero parts
            if part.get('is_hero') and part.get('glow'):
                glow_color = (*part['color'], 100)
                pygame.draw.circle(part_surface, glow_color,
                                 (size//2, size//2), size//2, 2)
            
            # Apply rotation
            rotated = pygame.transform.rotate(part_surface, part['rotation'])
            rect = rotated.get_rect(center=(int(part['x']), int(part['y'])))
            surface.blit(rotated, rect)
    
    def _draw_monk_hit_effects(self, surface: pygame.Surface):
        """Draw monk hit effects"""
        for effect in self.monk_hit_effects:
            if effect['type'] == 'shockwave':
                if effect['alpha'] > 0:
                    # Draw expanding ring
                    color = (*effect['color'], int(effect['alpha']))
                    # Create temporary surface for alpha
                    temp_surface = pygame.Surface((effect['radius'] * 2 + 4, effect['radius'] * 2 + 4), pygame.SRCALPHA)
                    pygame.draw.circle(temp_surface, color, 
                                     (effect['radius'] + 2, effect['radius'] + 2), 
                                     int(effect['radius']), 3)
                    surface.blit(temp_surface, 
                               (effect['x'] - effect['radius'] - 2, 
                                effect['y'] - effect['radius'] - 2))
                    
            elif effect['type'] == 'spark':
                # Draw spark particle
                alpha = int(255 * (effect['life'] / 20))
                if alpha > 0:
                    color = (*effect['color'], alpha)
                    temp_surface = pygame.Surface((6, 6), pygame.SRCALPHA)
                    pygame.draw.circle(temp_surface, color, (3, 3), 2)
                    surface.blit(temp_surface, (int(effect['x'] - 3), int(effect['y'] - 3)))
    
    def _draw_monk(self, surface: pygame.Surface, monk: Dict[str, Any]):
        """Draw a wandering monk with unique appearance"""
        x, y = int(monk['x']), int(monk['y'])
        
        # Create monk surface with alpha for opacity
        monk_surface = pygame.Surface((60, 80), pygame.SRCALPHA)
        
        # Colors for monk (개성있는 색상 적용)
        base_robe_color = monk.get('robe_color', (60, 50, 40))
        robe_color = (*base_robe_color, monk['opacity'])  # Custom robe color
        skin_color = (180, 160, 140, monk['opacity'])  # Skin tone
        
        # 무기 색상 (개성있는 무기 색상)
        base_staff_color = monk.get('weapon_color', (80, 60, 40))
        staff_color = (*base_staff_color, monk['opacity'])
        
        # Walking animation offset
        walk_offset = 0
        if monk['state'] == 'walking':
            walk_offset = abs(math.sin(monk['walking_phase'])) * 2
        
        # Draw staff (behind monk) - 개성있는 무기 그리기
        weapon_type = monk.get('weapon_type', 'basic_staff')
        if monk['state'] != 'meditating':
            if monk['state'] == 'swinging':
                # Animated staff during swing
                staff_base_x = 30
                staff_base_y = 35
                staff_length = 50
                
                # Calculate staff end position based on swing angle
                staff_end_x = staff_base_x + math.cos(monk['staff_angle'] - math.pi/2) * staff_length
                staff_end_y = staff_base_y + math.sin(monk['staff_angle'] - math.pi/2) * staff_length
                
                # 무기 타입별 다른 그리기
                if weapon_type == 'golden_staff':
                    # 금장 봉 - 화려한 장식
                    pygame.draw.line(monk_surface, staff_color,
                                   (staff_base_x, staff_base_y),
                                   (int(staff_end_x), int(staff_end_y)), 6)
                    # 금빛 장식 고리들
                    for i in range(3):
                        ring_pos = 0.3 + i * 0.2
                        ring_x = staff_base_x + (staff_end_x - staff_base_x) * ring_pos
                        ring_y = staff_base_y + (staff_end_y - staff_base_y) * ring_pos
                        pygame.draw.circle(monk_surface, (255, 215, 0, monk['opacity']),
                                         (int(ring_x), int(ring_y)), 3, 1)
                elif weapon_type == 'chain_staff':
                    # 쇠사슬 달린 봉
                    pygame.draw.line(monk_surface, staff_color,
                                   (staff_base_x, staff_base_y),
                                   (int(staff_end_x), int(staff_end_y)), 4)
                    # 끝에 쇠사슬 효과
                    chain_x = staff_end_x + math.cos(monk['staff_angle']) * 8
                    chain_y = staff_end_y + math.sin(monk['staff_angle']) * 8
                    pygame.draw.circle(monk_surface, (100, 100, 110, monk['opacity']),
                                     (int(chain_x), int(chain_y)), 4)
                    pygame.draw.line(monk_surface, (80, 80, 90, monk['opacity']),
                                   (int(staff_end_x), int(staff_end_y)),
                                   (int(chain_x), int(chain_y)), 2)
                elif weapon_type == 'iron_staff':
                    # 철봉 - 두껍고 묵직함
                    pygame.draw.line(monk_surface, staff_color,
                                   (staff_base_x, staff_base_y),
                                   (int(staff_end_x), int(staff_end_y)), 7)
                    # 철 리벳 표현
                    pygame.draw.circle(monk_surface, (40, 40, 50, monk['opacity']),
                                     (int(staff_end_x), int(staff_end_y)), 6)
                elif weapon_type == 'bamboo_staff':
                    # 대나무 봉 - 마디 표현
                    segments = 4
                    for i in range(segments):
                        seg_start = i / segments
                        seg_end = (i + 1) / segments
                        start_x = staff_base_x + (staff_end_x - staff_base_x) * seg_start
                        start_y = staff_base_y + (staff_end_y - staff_base_y) * seg_start
                        end_x = staff_base_x + (staff_end_x - staff_base_x) * seg_end
                        end_y = staff_base_y + (staff_end_y - staff_base_y) * seg_end
                        pygame.draw.line(monk_surface, staff_color,
                                       (int(start_x), int(start_y)),
                                       (int(end_x), int(end_y)), 4)
                        # 마디
                        if i < segments - 1:
                            pygame.draw.circle(monk_surface, (100, 80, 50, monk['opacity']),
                                             (int(end_x), int(end_y)), 3)
                elif weapon_type == 'curved_staff':
                    # 굽은 봉 - 곡선 효과
                    pygame.draw.line(monk_surface, staff_color,
                                   (staff_base_x, staff_base_y),
                                   (int(staff_end_x), int(staff_end_y)), 5)
                    # 끝이 굽은 효과
                    curve_x = staff_end_x + math.cos(monk['staff_angle'] - math.pi/4) * 10
                    curve_y = staff_end_y + math.sin(monk['staff_angle'] - math.pi/4) * 10
                    pygame.draw.lines(monk_surface, staff_color, False,
                                    [(int(staff_end_x), int(staff_end_y)),
                                     (int(curve_x), int(curve_y))], 4)
                else:
                    # 기본 봉
                    pygame.draw.line(monk_surface, staff_color,
                                   (staff_base_x, staff_base_y),
                                   (int(staff_end_x), int(staff_end_y)), 5)
                
                # Staff top ornament (무기별 장식)
                if weapon_type != 'chain_staff':  # 쇠사슬 봉은 이미 끝 장식이 있음
                    pygame.draw.circle(monk_surface, staff_color,
                                     (int(staff_end_x), int(staff_end_y)), 5)
                
                # Motion blur effect
                if 10 <= monk['swing_animation'] <= 15:
                    for i in range(3):
                        blur_angle = monk['staff_angle'] - (i * 0.2)
                        blur_x = staff_base_x + math.cos(blur_angle - math.pi/2) * staff_length
                        blur_y = staff_base_y + math.sin(blur_angle - math.pi/2) * staff_length
                        blur_color = (80, 60, 40, monk['opacity'] // (4 + i*2))
                        pygame.draw.line(monk_surface, blur_color,
                                       (staff_base_x, staff_base_y),
                                       (int(blur_x), int(blur_y)), 3 - i)
            else:
                # Normal staff position
                staff_x = 30 + monk['direction'] * 15
                staff_top = 10
                staff_bottom = 60
                # Staff line
                pygame.draw.line(monk_surface, staff_color,
                               (staff_x, staff_top),
                               (staff_x + math.sin(monk['staff_angle']) * 5, staff_bottom), 3)
                # Staff top ornament
                pygame.draw.circle(monk_surface, staff_color,
                                 (staff_x, staff_top), 4)
        
        # Draw monk body (robe)
        robe_x = 30
        robe_y = 35 - walk_offset
        
        # Main robe shape (triangular/cone)
        robe_points = [
            (int(robe_x - 15 + monk['robe_sway']), int(robe_y + 30)),  # Bottom left
            (int(robe_x + 15 + monk['robe_sway']), int(robe_y + 30)),  # Bottom right
            (int(robe_x + 10), int(robe_y + 10)),  # Right shoulder
            (int(robe_x + 5), int(robe_y)),  # Right neck
            (int(robe_x - 5), int(robe_y)),  # Left neck
            (int(robe_x - 10), int(robe_y + 10)),  # Left shoulder
        ]
        pygame.draw.polygon(monk_surface, robe_color, robe_points)
        
        # Robe fold lines
        fold_color = (50, 40, 30, monk['opacity'] // 2)
        pygame.draw.line(monk_surface, fold_color,
                       (robe_x - 5, int(robe_y + 10)),
                       (robe_x - 8, int(robe_y + 25)), 1)
        pygame.draw.line(monk_surface, fold_color,
                       (robe_x + 5, int(robe_y + 10)),
                       (robe_x + 8, int(robe_y + 25)), 1)
        
        # Draw head and hat/hood
        head_y = 20 - walk_offset
        hat_type = monk.get('hat_type', None)
        
        if hat_type == 'straw':
            # 삿갓 그리기
            # 머리 먼저
            pygame.draw.circle(monk_surface, skin_color, (robe_x, int(head_y)), 8)
            # 삿갓 (원뿔형 모자)
            hat_color = (100, 85, 60, monk['opacity'])  # 짚 색상
            hat_points = [
                (robe_x, int(head_y - 10)),      # 꼭대기
                (robe_x - 15, int(head_y + 3)),  # 왼쪽
                (robe_x + 15, int(head_y + 3))   # 오른쪽
            ]
            pygame.draw.polygon(monk_surface, hat_color, hat_points)
            # 삿갓 테두리
            pygame.draw.line(monk_surface, (70, 60, 40, monk['opacity']),
                           (robe_x - 15, int(head_y + 3)), 
                           (robe_x + 15, int(head_y + 3)), 2)
        elif hat_type == 'hood':
            # 두건 그리기
            hood_color = (35, 30, 28, monk['opacity'])  # 어두운 두건
            # 두건으로 머리 덮기
            pygame.draw.ellipse(monk_surface, hood_color,
                              (robe_x - 8, int(head_y - 7), 16, 18))
            # 얼굴 부분만 노출
            pygame.draw.circle(monk_surface, skin_color, (robe_x, int(head_y + 1)), 6)
            # 두건 그림자
            pygame.draw.arc(monk_surface, (20, 18, 15, monk['opacity']),
                          (robe_x - 8, int(head_y - 7), 16, 18), 0, math.pi, 2)
        else:
            # 모자 없음 - 일반 머리 (대머리)
            pygame.draw.circle(monk_surface, skin_color,
                             (robe_x, int(head_y)), 8)
        
        # Draw simple facial features if not too small
        if monk['opacity'] > 100:
            # Eyes (closed if meditating)
            if monk['state'] == 'meditating':
                # Closed eyes (meditation)
                eye_color = (40, 30, 20, monk['opacity'] // 2)
                pygame.draw.line(monk_surface, eye_color,
                               (robe_x - 3, int(head_y - 1)),
                               (robe_x - 1, int(head_y - 1)), 1)
                pygame.draw.line(monk_surface, eye_color,
                               (robe_x + 1, int(head_y - 1)),
                               (robe_x + 3, int(head_y - 1)), 1)
            else:
                # Open eyes
                eye_color = (20, 15, 10, monk['opacity'])
                monk_surface.set_at((int(robe_x - 2), int(head_y - 1)), eye_color)
                monk_surface.set_at((int(robe_x + 2), int(head_y - 1)), eye_color)
        
        # Arms/sleeves
        if monk['state'] == 'meditating':
            # Hands together in prayer position
            pygame.draw.circle(monk_surface, skin_color,
                             (robe_x, int(robe_y + 15)), 4)
        else:
            # Walking arms
            arm_swing = math.sin(monk['walking_phase']) * 5 if monk['state'] == 'walking' else 0
            # Left arm
            pygame.draw.line(monk_surface, robe_color,
                           (robe_x - 8, int(robe_y + 10)),
                           (int(robe_x - 10 - arm_swing), int(robe_y + 20)), 4)
            # Right arm
            pygame.draw.line(monk_surface, robe_color,
                           (robe_x + 8, int(robe_y + 10)),
                           (int(robe_x + 10 + arm_swing), int(robe_y + 20)), 4)
        
        # Feet (simple)
        if monk['state'] == 'walking':
            # Animated feet
            foot_offset = math.sin(monk['walking_phase'] * 2) * 3
            pygame.draw.circle(monk_surface, (40, 30, 20, monk['opacity']),
                             (int(robe_x - 5 + foot_offset), int(robe_y + 32)), 2)
            pygame.draw.circle(monk_surface, (40, 30, 20, monk['opacity']),
                             (int(robe_x + 5 - foot_offset), int(robe_y + 32)), 2)
        else:
            # Static feet
            pygame.draw.circle(monk_surface, (40, 30, 20, monk['opacity']),
                             (robe_x - 5, int(robe_y + 32)), 2)
            pygame.draw.circle(monk_surface, (40, 30, 20, monk['opacity']),
                             (robe_x + 5, int(robe_y + 32)), 2)
        
        # Flip if facing left
        if monk['direction'] == -1:
            monk_surface = pygame.transform.flip(monk_surface, True, False)
        
        # Draw to main surface
        surface.blit(monk_surface, (x - 30, y - 40))
    
    def update(self, dt: float = 0.016):
        """Update animations"""
        self.frame_count += 1
        
        # OPTIMIZATION: Auto-detect low FPS and enable performance mode
        if dt > 0 and self.moon_red_intensity > 0:  # Only check during red moon
            current_fps = 1.0 / dt
            if current_fps < self.low_fps_threshold:
                self.fps_counter += 1
                if self.fps_counter > 30:  # If low FPS for 0.5 seconds (faster activation)
                    self.performance_mode = True
                    self.red_moon_cache = None  # Force cache refresh
                    print(f"Performance mode enabled (FPS: {current_fps:.1f})")
            else:
                self.fps_counter = max(0, self.fps_counter - 1)
                if self.fps_counter == 0 and self.performance_mode:
                    self.performance_mode = False
                    self.red_moon_cache = None  # Force cache refresh
                    print("Performance mode disabled")
        self._update_crows()
        self._update_monk_hit_effects()  # Update monk hit effects
        self._update_monk_death_effects()  # Update monk death particles
        self._update_crow_corpses()
        self._update_crow_fragments()
        self._update_crow_particles()
        self._update_monks()
        self._update_destruction_animation()  # Update temple destruction
        self._update_moon_fragments()  # Update moon crater fragments
    
    def draw(self, surface: pygame.Surface):
        """Draw the complete Shaolin Temple background"""
        # Apply screen shake if active
        shake_x, shake_y = 0, 0
        if self.screen_shake_intensity > 0:
            shake_x = random.randint(-self.screen_shake_intensity, self.screen_shake_intensity)
            shake_y = random.randint(-self.screen_shake_intensity, self.screen_shake_intensity)
        
        # Create temporary surface for shaking effect
        temp_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        # Draw static background
        if self.static_surface is None:
            self.static_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            self._draw_static_background()
        temp_surface.blit(self.static_surface, (0, 0))
        
        # Draw red moon during destruction (overlay on top of normal moon)
        if self.moon_red_intensity > 0:
            self._draw_red_moon(temp_surface)
        
        # Draw stars
        self._draw_stars(temp_surface)
        
        # Draw back layer elements
        self._draw_bamboo_trees(temp_surface)
        
        # Draw mist (back layer)
        self._draw_mist(temp_surface)
        
        # Draw temple or ruins
        if self.temple_destroyed:
            self._draw_ruins(temp_surface)
        else:
            self._draw_temple(temp_surface)
        
        # Draw dragon ornaments (only if temple not destroyed)
        if not self.temple_destroyed:
            for dragon in self.dragon_ornaments:
                self._draw_dragon_ornament(temp_surface, dragon)
        
        # Draw bell (only if temple not destroyed)
        if not self.temple_destroyed:
            self._draw_bell(temp_surface)
        
        # Draw training dummies
        for dummy in self.training_dummies:
            self._draw_training_dummy(temp_surface, dummy)
        
        # Draw ritual brazier (불이 꺼진 의식용 화로)
        if not self.temple_destroyed:
            self._draw_ritual_brazier(temp_surface)
        
        # Draw monks
        for monk in self.monks:
            self._draw_monk(temp_surface, monk)
        
        # Draw monk hit effects (on top of monks)
        self._draw_monk_hit_effects(temp_surface)
        
        # Draw monk death effects
        self._draw_monk_death_effects(temp_surface)
        
        # Draw incense
        self._draw_incense(temp_surface)
        
        # Draw lanterns (hide during destruction)
        if not self.destruction_animation_active:
            for lantern in self.lanterns:
                self._draw_lantern(temp_surface, lantern)
        
        # Draw falling lanterns during destruction
        if self.destruction_animation_active:
            self._draw_falling_lanterns(temp_surface)
        
        # Draw moon crater fragments
        self._draw_moon_fragments(temp_surface)
        
        # Draw floating leaves
        self._draw_floating_leaves(temp_surface)
        
        # Draw flying crows
        for crow in self.crows[:]:
            if not self._draw_crow(temp_surface, crow):
                self.crows.remove(crow)  # Remove caught crows after animation
        
        # Draw crow explosion fragments and particles
        self._draw_crow_fragments(temp_surface)
        self._draw_crow_particles(temp_surface)
        
        # Draw falling crow corpses (kept for compatibility)
        for corpse in self.crow_corpses[:]:
            if not self._draw_crow_corpse(temp_surface, corpse):
                self.crow_corpses.remove(corpse)  # Remove collected corpses after fade
        
        # Draw collapse debris
        self._draw_collapse_debris(temp_surface)
        
        # Draw ground fires from broken lanterns
        self._draw_ground_fires(temp_surface)
        
        # Apply shaking and draw to main surface
        surface.blit(temp_surface, (shake_x, shake_y))
        
        # Draw red light overlay (after shaking)
        if self.red_light_alpha > 0:
            red_overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            red_overlay.fill((255, 50, 50, self.red_light_alpha))
            surface.blit(red_overlay, (0, 0))
        
        # Note: update() should be called separately from the main game loop, not here
    
    def check_smoke_touches_brazier(self, smoke_x: float, smoke_y: float, smoke_radius: float) -> bool:
        """연막탄 연기가 화로에 닿았는지 체크
        Returns: True if smoke touches brazier and lights it"""
        
        # 사원이 파괴된 후에는 이벤트 발생하지 않음
        if self.temple_destroyed:
            return False
        
        # 이미 불이 붙어있으면 False
        if self.brazier_lit:
            return False
        
        # 연막 영역과 화로 히트박스 충돌 체크
        smoke_rect = pygame.Rect(smoke_x - smoke_radius, smoke_y - smoke_radius, 
                                smoke_radius * 2, smoke_radius * 2)
        
        if smoke_rect.colliderect(self.brazier_hitbox):
            # 화로에 불 붙이기
            self.brazier_lit = True
            self.brazier_fire_animation = 0
            print(f"   !")
            
            # 불이 붙으면 몽크 5명 소환
            self._spawn_smoke_grenade_monks_from_brazier()
            return True
        
        return False
    
    def _spawn_smoke_grenade_monks_from_brazier(self):
        """화로에 불이 붙으면 특별한 몽크 5명 소환"""
        print(f"      5 !")
        
        # 5명의 개성있는 몽크 타입 정의
        monk_types = [
            {
                'type': 'straw_hat',  # 삿갓 쓴 몽크
                'robe_color': (70, 60, 50),  # 일반 갈색
                'hat_type': 'straw',
                'weapon_type': 'bamboo_staff',  # 대나무 봉
                'weapon_color': (150, 120, 80),  # 밝은 나무색
            },
            {
                'type': 'crimson',  # 붉은 옷 몽크
                'robe_color': (90, 40, 35),  # 검붉은색
                'hat_type': None,
                'weapon_type': 'iron_staff',  # 철봉
                'weapon_color': (60, 60, 70),  # 무쇠색
            },
            {
                'type': 'shadow',  # 검은 옷 몽크
                'robe_color': (25, 20, 25),  # 검은색
                'hat_type': None,
                'weapon_type': 'chain_staff',  # 쇠사슬 달린 봉
                'weapon_color': (40, 40, 45),  # 어두운 금속색
            },
            {
                'type': 'golden',  # 금빛 장식 몽크
                'robe_color': (80, 70, 40),  # 황금빛 갈색
                'hat_type': None,
                'weapon_type': 'golden_staff',  # 금장 봉
                'weapon_color': (180, 150, 60),  # 금색
            },
            {
                'type': 'veteran',  # 노련한 몽크
                'robe_color': (50, 45, 40),  # 회갈색
                'hat_type': 'hood',  # 두건
                'weapon_type': 'curved_staff',  # 굽은 봉
                'weapon_color': (70, 50, 35),  # 오래된 나무색
            }
        ]
        
        # 5명의 몽크를 사원 입구에서 나오도록 소환
        for i in range(5):
            monk_info = monk_types[i]
            
            # 몽크들이 조금씩 다른 위치로 이동하도록 설정
            monk = {
                'x': self.width // 2 + (i - 2) * 20,  # 사원 입구에서 살짝 퍼져서 시작
                'y': 450,  # Temple entrance position
                'target_x': random.randint(100, 500),  # 각자 다른 목표 지점
                'target_y': random.randint(480, 550),
                'speed': 0.5,  # 연막탄 몽크는 조금 빠르게 이동
                'direction': random.choice([-1, 1]),
                'walking_phase': i * 0.5,  # 걷는 애니메이션 위상 차이
                'robe_sway': 0,
                'meditation_timer': 0,
                'state': 'walking',
                'state_timer': random.randint(180, 360),
                'staff_angle': 0,
                'opacity': 255,  # 즉시 나타남
                'fade_in': False,
                'swing_count': 0,
                'swing_animation': 0,
                'swing_cooldown': 0,
                'can_deflect': True,
                'returning_to_temple': False,
                'has_hit_ball': False,
                'swing_chance_used': False,
                'is_smoke_grenade_monk': True,  # 연막탄으로 소환된 특별한 몽크
                'smoke_return_timer': 0,  # 연막탄 종료 후 복귀 타이머
                # 개성있는 외형 정보
                'monk_type': monk_info['type'],
                'robe_color': monk_info['robe_color'],
                'hat_type': monk_info['hat_type'],
                'weapon_type': monk_info['weapon_type'],
                'weapon_color': monk_info['weapon_color'],
                'swing_chance': 0.3,  # 30% 확률로 스윙 (기본 20%에서 증가)
                'speed_boost': 1.3,  # 30% 속도 증가
            }
            self.monks.append(monk)
        
        print(f"   : {len(self.monks)}")
    
    def spawn_smoke_grenade_monks(self):
        """연막탄 사용 시 호출 (기존 메서드 - 화로 체크로 대체됨)"""
        # 이제 이 메서드는 사용하지 않음 - check_smoke_touches_brazier를 통해 처리
        pass
    
    def trigger_smoke_grenade_monk_return(self):
        """연막탄 종료 시 몽크들이 30초 후 사원으로 복귀하도록 설정"""
        smoke_monk_count = 0
        for monk in self.monks:
            if monk.get('is_smoke_grenade_monk', False) and not monk['returning_to_temple']:
                monk['smoke_return_timer'] = 1800  # 30초 (60 FPS * 30)
                smoke_monk_count += 1
        if smoke_monk_count > 0:
            print(f"   {smoke_monk_count}   ! 30")
            print(f"     !")
    
    def get_brazier_position(self) -> tuple:
        """화로의 위치를 반환 (연막탄 충돌 체크용)"""
        return (self.brazier_x, self.brazier_y)
    
    def is_brazier_lit(self) -> bool:
        """화로에 불이 켜져있는지 반환"""
        return self.brazier_lit
    
    def _draw_crow_fragments(self, surface: pygame.Surface):
        """Draw crow explosion fragments"""
        for fragment in self.crow_fragments:
            # Create a surface for the fragment with alpha
            frag_surface = pygame.Surface((fragment['size'] * 2, fragment['size'] * 2), pygame.SRCALPHA)
            
            if fragment['type'] == 'feather':
                # Draw feather-like shape
                points = []
                for i in range(6):
                    angle = (i / 6) * 2 * math.pi + math.radians(fragment['rotation'])
                    if i % 2 == 0:
                        r = fragment['size']
                    else:
                        r = fragment['size'] * 0.5
                    x = fragment['size'] + r * math.cos(angle)
                    y = fragment['size'] + r * math.sin(angle)
                    points.append((x, y))
                
                # Draw with opacity
                color = (*fragment['color'], fragment['opacity'])
                if len(points) >= 3:
                    pygame.draw.polygon(frag_surface, color, points)
            else:
                # Draw fragment as irregular shape
                color = (*fragment['color'], fragment['opacity'])
                pygame.draw.circle(frag_surface, color, 
                                 (fragment['size'], fragment['size']), 
                                 fragment['size'])
            
            # Blit to main surface
            surface.blit(frag_surface, 
                        (int(fragment['x'] - fragment['size']), 
                         int(fragment['y'] - fragment['size'])))
    
    def _draw_crow_particles(self, surface: pygame.Surface):
        """Draw crow explosion particles"""
        for particle in self.crow_particles:
            # Draw small particle with opacity
            particle_surface = pygame.Surface((particle['size'] * 2, particle['size'] * 2), pygame.SRCALPHA)
            color = (*particle['color'], particle['opacity'])
            pygame.draw.circle(particle_surface, color,
                             (particle['size'], particle['size']), 
                             particle['size'])
            surface.blit(particle_surface,
                        (int(particle['x'] - particle['size']), 
                         int(particle['y'] - particle['size'])))
    
    def _draw_stage_title(self, surface: pygame.Surface):
        """Draw stage title"""
        try:
            font = pygame.font.Font("NeoDGM.ttf", 24)
        except:
            font = pygame.font.Font(None, 24)
        
        title = "Stage 4: Shaolin Temple"
        subtitle = "소림사"
        
        # Create glowing text effect
        for offset in [(2, 2), (-2, -2), (2, -2), (-2, 2)]:
            shadow_text = font.render(title, True, self.colors['gold_dim'])
            surface.blit(shadow_text, (self.width // 2 - shadow_text.get_width() // 2 + offset[0], 
                                      30 + offset[1]))
        
        title_text = font.render(title, True, self.colors['gold_accent'])
        surface.blit(title_text, (self.width // 2 - title_text.get_width() // 2, 30))
        
        # Korean subtitle
        try:
            font_kr = pygame.font.Font("NeoDGM.ttf", 20)
        except:
            font_kr = pygame.font.Font(None, 20)
        
        subtitle_text = font_kr.render(subtitle, True, self.colors['moon'])
        surface.blit(subtitle_text, (self.width // 2 - subtitle_text.get_width() // 2, 60))
    
    def draw_ponk_gauge(self, surface: pygame.Surface, gauge_value: int, is_ready: bool, is_active: bool):
        """Draw Stage 4 Boss Ponk's magnetic field gauge in vertical Shaolin temple style
        Shows the charging progress for the refraction magnetic field skill"""
        
        # Initialize display gauge value for smooth animation
        if not hasattr(self, 'ponk_display_gauge'):
            self.ponk_display_gauge = 0
        
        # Smooth gauge animation (progressive filling)
        if gauge_value != self.ponk_display_gauge:
            diff = gauge_value - self.ponk_display_gauge
            # Smooth interpolation - adjust speed as needed
            if abs(diff) > 5:
                self.ponk_display_gauge += diff * 0.15  # 15% per frame for fast changes
            elif abs(diff) > 1:
                self.ponk_display_gauge += diff * 0.25  # 25% per frame for medium changes
            else:
                self.ponk_display_gauge += diff * 0.4  # 40% per frame for small changes
            
            # Clamp to actual value to prevent overshooting
            if diff > 0:
                self.ponk_display_gauge = min(self.ponk_display_gauge, gauge_value)
            else:
                self.ponk_display_gauge = max(self.ponk_display_gauge, gauge_value)
        
        # Gauge position (upper right corner) - vertical bar style like player gauge
        gauge_x = self.width - 45  # Right side
        gauge_y = 50  # Higher position (was 80)
        gauge_width = 16  # 10% smaller (was 18)
        gauge_height = 108  # 10% smaller (was 120)
        max_gauge = 250  # Maximum gauge value for Ponk's magnetic field
        
        # Shaolin temple style decorative elements
        time_now = pygame.time.get_ticks()
        
        # Dynamic colors based on state
        if is_active:
            primary_color = (255, 80, 80)  # Crimson red
            secondary_color = (255, 150, 100)
            glow_intensity = abs(math.sin(time_now * 0.005)) * 100
        elif is_ready:
            primary_color = (255, 180, 50)  # Golden orange
            secondary_color = (255, 220, 100)
            glow_intensity = abs(math.sin(time_now * 0.003)) * 80
        else:
            primary_color = self.colors['gold_accent']  # Temple gold
            secondary_color = self.colors['gold_dim']
            glow_intensity = 30
        
        # Draw ornamental top piece (pagoda roof style)
        pagoda_top = [
            (gauge_x + gauge_width // 2, gauge_y - 12),  # Peak
            (gauge_x - 4, gauge_y - 2),  # Left corner
            (gauge_x - 6, gauge_y + 2),  # Left edge
            (gauge_x, gauge_y + 4),  # Left base
            (gauge_x + gauge_width, gauge_y + 4),  # Right base
            (gauge_x + gauge_width + 6, gauge_y + 2),  # Right edge
            (gauge_x + gauge_width + 4, gauge_y - 2),  # Right corner
        ]
        pygame.draw.polygon(surface, primary_color, pagoda_top)
        pygame.draw.polygon(surface, secondary_color, pagoda_top, 2)
        
        # Draw ornamental bottom piece (lotus base style)
        lotus_bottom = [
            (gauge_x - 2, gauge_y + gauge_height - 4),
            (gauge_x - 4, gauge_y + gauge_height),
            (gauge_x, gauge_y + gauge_height + 4),
            (gauge_x + gauge_width // 3, gauge_y + gauge_height + 6),
            (gauge_x + gauge_width // 2, gauge_y + gauge_height + 8),  # Center petal
            (gauge_x + 2 * gauge_width // 3, gauge_y + gauge_height + 6),
            (gauge_x + gauge_width, gauge_y + gauge_height + 4),
            (gauge_x + gauge_width + 4, gauge_y + gauge_height),
            (gauge_x + gauge_width + 2, gauge_y + gauge_height - 4),
        ]
        pygame.draw.polygon(surface, primary_color, lotus_bottom)
        pygame.draw.polygon(surface, secondary_color, lotus_bottom, 2)
        
        # Main gauge frame with Chinese lattice pattern
        main_frame = pygame.Rect(gauge_x - 3, gauge_y, gauge_width + 6, gauge_height)
        
        # Outer frame with gradient
        pygame.draw.rect(surface, (40, 35, 45), main_frame)  # Dark background
        pygame.draw.rect(surface, primary_color, main_frame, 3)  # Main border
        pygame.draw.rect(surface, secondary_color, 
                        (gauge_x - 1, gauge_y + 2, gauge_width + 2, gauge_height - 4), 1)  # Inner border
        
        # Inner gauge area
        inner_x = gauge_x + 1
        inner_y = gauge_y + 3
        inner_width = gauge_width - 2
        inner_height = gauge_height - 6
        pygame.draw.rect(surface, (15, 12, 18),
                        (inner_x, inner_y, inner_width, inner_height))
        
        # Draw Chinese lattice decorations on sides
        for i in range(4):
            deco_y = gauge_y + 15 + i * 25
            # Left decoration
            pygame.draw.lines(surface, secondary_color, False,
                            [(gauge_x - 5, deco_y), (gauge_x - 2, deco_y - 3), 
                             (gauge_x - 2, deco_y + 3), (gauge_x - 5, deco_y)], 1)
            # Right decoration  
            pygame.draw.lines(surface, secondary_color, False,
                            [(gauge_x + gauge_width + 5, deco_y), 
                             (gauge_x + gauge_width + 2, deco_y - 3),
                             (gauge_x + gauge_width + 2, deco_y + 3),
                             (gauge_x + gauge_width + 5, deco_y)], 1)
        
        # Calculate gauge fill (vertical - fills from bottom to top)
        # Use animated display value instead of raw value
        fill_ratio = min(self.ponk_display_gauge / max_gauge, 1.0)
        
        # Draw the gauge fill
        if self.ponk_display_gauge > 0:
            fill_height = int(inner_height * fill_ratio)
            fill_y = inner_y + inner_height - fill_height  # Start from bottom
            
            # Multi-layer fill for depth effect
            if is_active:
                # Active - pulsing crimson with chi energy effect
                pulse = abs(math.sin(time_now * 0.004))
                base_color = (200, 40, 40)
                mid_color = (255, 80 + pulse * 40, 60)
                core_color = (255, 120 + pulse * 60, 100)
            elif is_ready:
                # Ready - golden chi energy
                pulse = abs(math.sin(time_now * 0.003))
                base_color = (180, 120, 40)
                mid_color = (255, 180 + pulse * 30, 80)
                core_color = (255, 220 + pulse * 35, 150)
            else:
                # Charging - temple blue to gold gradient
                progress = fill_ratio
                base_color = (
                    int(80 + progress * 100),
                    int(100 + progress * 80),
                    int(120 + progress * 60)
                )
                mid_color = (
                    int(120 + progress * 100),
                    int(140 + progress * 80),
                    int(160 + progress * 60)
                )
                core_color = (
                    int(160 + progress * 95),
                    int(180 + progress * 75),
                    int(200 + progress * 55)
                )
            
            # Draw three layers for depth
            # Outer layer (darkest)
            pygame.draw.rect(surface, base_color,
                           (inner_x, fill_y, inner_width, fill_height))
            
            # Middle layer 
            if inner_width > 4:
                pygame.draw.rect(surface, mid_color,
                               (inner_x + 2, fill_y + 2, inner_width - 4, fill_height - 4))
            
            # Core layer (brightest) with vertical gradient
            if inner_width > 6:
                core_width = inner_width - 6
                core_x = inner_x + 3
                for i in range(fill_height - 6):
                    gradient_ratio = i / max(1, fill_height - 6)
                    # Gradient from bright at top to darker at bottom
                    gradient_color = tuple(
                        int(core_color[j] * (1.5 - gradient_ratio * 0.5)) 
                        for j in range(3)
                    )
                    # Clamp to valid color range
                    gradient_color = tuple(min(255, c) for c in gradient_color)
                    pygame.draw.line(surface, gradient_color,
                                   (core_x, fill_y + 3 + i),
                                   (core_x + core_width - 1, fill_y + 3 + i))
            
            # Add chi energy effect when ready or active
            if is_ready or is_active:
                # Floating energy particles (only if there's fill to show particles in)
                if fill_height > 0:
                    for _ in range(3):
                        if random.random() < 0.3:  # 30% chance per frame
                            particle_x = inner_x + random.randint(2, inner_width - 3)
                            particle_y = fill_y + random.randint(0, max(1, fill_height - 1))
                            particle_size = random.randint(1, 2)
                            # Golden particles
                            particle_color = (255, random.randint(200, 255), random.randint(100, 200))
                            pygame.draw.circle(surface, particle_color, (particle_x, particle_y), particle_size)
                
                # Energy wisps at the top of the fill
                if self.frame_count % 2 == 0:
                    wisp_height = 8
                    pulse = abs(math.sin(time_now * 0.004))
                    wisp_alpha = int(128 + pulse * 127)
                    for i in range(wisp_height):
                        wisp_y = fill_y - i
                        if wisp_y >= inner_y:
                            alpha_factor = 1.0 - (i / wisp_height)
                            wisp_color = tuple(int(c * alpha_factor) for c in core_color)
                            pygame.draw.line(surface, wisp_color,
                                           (inner_x + 2, wisp_y),
                                           (inner_x + inner_width - 3, wisp_y))
        
        # Draw decorative dividers (segment marks)
        segment_height = inner_height // 4
        for i in range(1, 4):
            divider_y = inner_y + inner_height - (segment_height * i)
            # Draw notches on sides
            pygame.draw.line(surface, secondary_color,
                           (gauge_x - 1, divider_y),
                           (gauge_x + 3, divider_y), 1)
            pygame.draw.line(surface, secondary_color,
                           (gauge_x + gauge_width - 3, divider_y),
                           (gauge_x + gauge_width + 1, divider_y), 1)
        
        # Text labels removed per user request - no title text
        
        # Numerical values and state text removed per user request
    
    def start_destruction_animation(self):
        """Start the temple destruction animation sequence"""
        if not self.destruction_animation_active and not self.temple_destroyed:
            self.destruction_animation_active = True
            self.destruction_phase = 1
            self.destruction_timer = 0
            print("Temple destruction animation started!")
    
    def is_destruction_animation_active(self):
        """Check if destruction animation is currently playing"""
        return self.destruction_animation_active
    
    def _update_destruction_animation(self):
        """Update the temple destruction animation"""
        if not self.destruction_animation_active:
            return
        
        self.destruction_timer += 1
        
        if self.destruction_phase == 1:  # Moon turning red (3 seconds)
            # Gradually increase red intensity with more dramatic curve
            progress = self.destruction_timer / 180.0  # 3 seconds
            # Use exponential curve for more intense transition
            self.moon_red_intensity = min(1.0, progress ** 0.5)  # Faster initial change
            
            if self.destruction_timer >= 180:  # 3 seconds at 60 FPS
                self.moon_red_intensity = 1.0  # Ensure it's fully red
                self.destruction_phase = 2
                self.destruction_timer = 0
                
        elif self.destruction_phase == 2:  # Red light emission (1.5 seconds)
            # Flash red light across the map
            if self.destruction_timer < 45:
                self.red_light_alpha = min(150, self.destruction_timer * 3.3)
            else:
                self.red_light_alpha = max(0, 150 - (self.destruction_timer - 45) * 3.3)
            
            if self.destruction_timer >= 90:  # 1.5 seconds
                self.destruction_phase = 3
                self.destruction_timer = 0
                self._create_collapse_debris()
                self._start_lanterns_falling()  # Start lanterns falling
                
        elif self.destruction_phase == 3:  # Temple collapsing (4.5 seconds)
            # Kill all monks and dummies when temple starts collapsing
            if self.destruction_timer == 0:
                self._explode_all_monks()
                self._explode_all_training_dummies()
            
            # More intense screen shake
            if self.destruction_timer < 90:
                self.screen_shake_intensity = 5 + int(self.destruction_timer / 15)
            elif self.destruction_timer < 180:
                self.screen_shake_intensity = 10
            else:
                self.screen_shake_intensity = max(0, 10 - (self.destruction_timer - 180) // 15)
            
            # Gradual collapse animation with acceleration
            collapse_progress = self.destruction_timer / 270.0  # 4.5 seconds
            # Use exponential curve for more natural collapse
            self.collapse_offset = int(350 * (collapse_progress ** 1.5))
            
            # Update debris with more realistic physics
            for debris in self.collapse_debris:
                debris['y'] += debris['vy']
                debris['x'] += debris['vx']
                debris['vy'] += 0.4  # Slightly less gravity for more float time
                debris['vx'] *= 0.98  # Air resistance
                debris['rotation'] += debris['rotation_speed']
                # Slower fade for better visibility
                if self.destruction_timer > 90:  # Start fading after 1.5 seconds
                    debris['opacity'] = max(0, debris['opacity'] - 0.3)
            
            # Add more debris periodically for continuous collapse effect
            if self.destruction_timer % 20 == 0 and self.destruction_timer < 180:
                self._create_additional_debris()
            
            # Update falling lanterns
            self._update_falling_lanterns()
            
            # Update ground fires
            self._update_ground_fires()
            
            if self.destruction_timer >= 270:  # 4.5 seconds
                self.destruction_phase = 4
                self.destruction_timer = 0
                # Clear lanterns from the map after they've fallen
                self.lanterns.clear()
                
        elif self.destruction_phase == 4:  # Complete - show ruins
            self.temple_destroyed = True
            self.destruction_animation_active = False
            self.screen_shake_intensity = 0
            self.monks.clear()  # Remove all monks
            self.monk_spawn_timer = float('inf')  # Stop monk spawning
            print("Temple destruction complete! No more monks will spawn.")
    
    def _create_collapse_debris(self):
        """Create debris particles for temple collapse"""
        self.collapse_debris = []
        
        # Create many debris pieces with varied sizes and positions
        for _ in range(80):  # More debris for better effect
            debris = {
                'x': self.width // 2 + random.randint(-150, 150),
                'y': 350 + random.randint(-100, 100),  # Various starting heights
                'vx': random.uniform(-8, 8),
                'vy': random.uniform(-15, -3),  # Stronger initial upward velocity
                'size': random.randint(3, 25),  # More size variation
                'rotation': random.uniform(0, 360),
                'rotation_speed': random.uniform(-15, 15),
                'color': random.choice([
                    self.colors['temple_main'],
                    self.colors['temple_dark'],
                    self.colors['roof_red'],
                    self.colors['stone_gray'],
                    (80, 60, 40),  # Wood color
                    (100, 80, 60),  # Light wood
                ]),
                'opacity': 255,
                'type': random.choice(['square', 'rectangle', 'triangle'])  # Different shapes
            }
            self.collapse_debris.append(debris)
    
    def _create_additional_debris(self):
        """Create additional debris during collapse for continuous effect"""
        # Add 5-10 new debris pieces
        for _ in range(random.randint(5, 10)):
            debris = {
                'x': self.width // 2 + random.randint(-120, 120),
                'y': 400 + random.randint(-50, 50),
                'vx': random.uniform(-6, 6),
                'vy': random.uniform(-8, -2),
                'size': random.randint(4, 15),
                'rotation': random.uniform(0, 360),
                'rotation_speed': random.uniform(-12, 12),
                'color': random.choice([
                    self.colors['temple_main'],
                    self.colors['temple_dark'],
                    self.colors['roof_red'],
                    (90, 70, 50),  # Darker wood
                ]),
                'opacity': 255,
                'type': random.choice(['square', 'rectangle', 'triangle'])
            }
            self.collapse_debris.append(debris)
    
    def _start_lanterns_falling(self):
        """Start all lanterns falling during destruction"""
        for lantern in self.lanterns:
            # Calculate horizontal movement to aim for player floor area
            # Player area is roughly at y=650, x centered around 300
            target_x = 300 + random.randint(-100, 100)  # Player floor area width
            distance_x = target_x - lantern['x']
            # Add some randomness but bias toward player area
            vx = (distance_x / 100) + random.uniform(-1, 1)
            vx = max(-4, min(4, vx))  # Limit horizontal speed
            
            falling_lantern = {
                'x': lantern['x'],
                'y': lantern['y'],
                'vx': vx,  # Horizontal movement toward player area
                'vy': 0,  # Start with no vertical velocity
                'rotation': 0,
                'rotation_speed': random.uniform(-5, 5),
                'size': lantern['size'],
                'broken': False,
                'ground_y': 650 + random.randint(-10, 10),  # Player floor area (around y=650)
                'deformation': 0,  # For squash effect when landing
                'bounce_count': 0,  # Track bounces for deformation
            }
            self.falling_lanterns.append(falling_lantern)
    
    def _update_falling_lanterns(self):
        """Update falling lanterns during destruction"""
        for lantern in self.falling_lanterns[:]:
            if not lantern['broken']:
                # Apply gravity (reduced for slower falling)
                lantern['vy'] += 0.35  # Reduced gravity for slower fall
                lantern['y'] += lantern['vy']
                lantern['x'] += lantern['vx']
                lantern['rotation'] += lantern['rotation_speed'] * 0.7  # Slower rotation
                
                # Apply air resistance to horizontal movement
                lantern['vx'] *= 0.98  # More air resistance
                
                # Check if hit ground
                if lantern['y'] >= lantern['ground_y']:
                    # First impact - apply deformation
                    if lantern['bounce_count'] == 0:
                        lantern['deformation'] = 0.5  # Squash to 50% height
                        lantern['y'] = lantern['ground_y']
                        lantern['vy'] = -lantern['vy'] * 0.3  # Small bounce
                        lantern['bounce_count'] += 1
                        lantern['rotation_speed'] *= 0.5  # Slow rotation after impact
                    elif lantern['bounce_count'] == 1 and lantern['vy'] > 0:
                        # Second impact - break
                        lantern['broken'] = True
                        lantern['deformation'] = 0.3  # Maximum squash
                        # Create fire effect at crash site
                        self._create_ground_fire(lantern['x'], lantern['ground_y'])
                        # Create glass breaking debris with more particles
                        self._create_lantern_debris(lantern['x'], lantern['ground_y'])
                
                # Update deformation (spring back effect)
                if lantern['deformation'] > 0:
                    lantern['deformation'] = max(0, lantern['deformation'] - 0.05)
    
    def _create_ground_fire(self, x: float, y: float):
        """Create fire effect on ground when lantern breaks"""
        fire = {
            'x': x,
            'y': y,
            'lifetime': 60,  # 1 second at 60 FPS
            'particles': []
        }
        
        # Create initial fire particles
        for _ in range(20):
            particle = {
                'x': x + random.randint(-20, 20),
                'y': y + random.randint(-5, 5),
                'vx': random.uniform(-2, 2),
                'vy': random.uniform(-3, -1),
                'size': random.randint(3, 8),
                'life': random.randint(20, 40),
                'color_phase': random.uniform(0, 1),
            }
            fire['particles'].append(particle)
        
        self.ground_fires.append(fire)
    
    def _create_lantern_debris(self, x: float, y: float):
        """Create glass debris when lantern breaks"""
        # More debris for dramatic breaking effect
        for _ in range(25):
            # Debris flies more horizontally when hitting ground
            debris = {
                'x': x,
                'y': y - 5,  # Start slightly above ground
                'vx': random.uniform(-8, 8),  # More horizontal spread
                'vy': random.uniform(-6, -2),  # Less vertical, more sideways
                'size': random.randint(2, 6),
                'rotation': random.uniform(0, 360),
                'rotation_speed': random.uniform(-30, 30),
                'color': random.choice([
                    (255, 200, 150),  # Glass color
                    (255, 100, 50),   # Red glass
                    (200, 150, 100),  # Brown frame
                    (255, 150, 100),  # Orange glass
                    (180, 50, 30),    # Dark red frame
                ]),
                'opacity': 255,
                'type': 'glass',
            }
            self.collapse_debris.append(debris)
        
        # Add some larger frame pieces
        for _ in range(5):
            frame_piece = {
                'x': x,
                'y': y - 5,
                'vx': random.uniform(-6, 6),
                'vy': random.uniform(-4, -1),
                'size': random.randint(6, 10),
                'rotation': random.uniform(0, 360),
                'rotation_speed': random.uniform(-15, 15),
                'color': (100, 70, 40),  # Dark wood color
                'opacity': 255,
                'type': 'rectangle',  # Frame pieces are rectangular
            }
            self.collapse_debris.append(frame_piece)
    
    def _update_ground_fires(self):
        """Update ground fire effects"""
        for fire in self.ground_fires[:]:
            fire['lifetime'] -= 1
            
            # Update fire particles
            for particle in fire['particles'][:]:
                particle['y'] += particle['vy']
                particle['x'] += particle['vx']
                particle['vy'] -= 0.1  # Rise faster
                particle['life'] -= 1
                particle['size'] = max(1, particle['size'] - 0.1)
                
                if particle['life'] <= 0 or particle['size'] <= 0:
                    fire['particles'].remove(particle)
            
            # Add new particles while fire is active
            if fire['lifetime'] > 30 and len(fire['particles']) < 15:
                for _ in range(3):
                    particle = {
                        'x': fire['x'] + random.randint(-15, 15),
                        'y': fire['y'],
                        'vx': random.uniform(-1, 1),
                        'vy': random.uniform(-2, -0.5),
                        'size': random.randint(3, 6),
                        'life': random.randint(15, 25),
                        'color_phase': random.uniform(0, 1),
                    }
                    fire['particles'].append(particle)
            
            # Remove fire when done
            if fire['lifetime'] <= 0 and len(fire['particles']) == 0:
                self.ground_fires.remove(fire)
    
    def _draw_collapse_debris(self, surface: pygame.Surface):
        """Draw falling debris during collapse"""
        for debris in self.collapse_debris:
            # Check if debris has opacity (default to 255 if not)
            opacity = debris.get('opacity', 255)
            if opacity > 0:
                # Create surface for debris
                debris_surf = pygame.Surface((debris['size'] * 2, debris['size'] * 2), pygame.SRCALPHA)
                
                # Draw debris piece based on type
                color = (*debris['color'], opacity)
                
                if debris.get('type') == 'triangle':
                    # Draw triangle debris
                    points = []
                    for i in range(3):
                        angle = math.radians(debris['rotation'] + i * 120)
                        x = debris['size'] + debris['size'] * 0.9 * math.cos(angle)
                        y = debris['size'] + debris['size'] * 0.9 * math.sin(angle)
                        points.append((x, y))
                    if len(points) >= 3:
                        pygame.draw.polygon(debris_surf, color, points)
                
                elif debris.get('type') == 'rectangle':
                    # Draw rectangular debris
                    rect_width = debris['size'] * 1.5
                    rect_height = debris['size'] * 0.7
                    # Create rotated rectangle
                    points = []
                    for dx, dy in [(-rect_width/2, -rect_height/2), 
                                  (rect_width/2, -rect_height/2),
                                  (rect_width/2, rect_height/2),
                                  (-rect_width/2, rect_height/2)]:
                        angle = math.radians(debris['rotation'])
                        x = debris['size'] + dx * math.cos(angle) - dy * math.sin(angle)
                        y = debris['size'] + dx * math.sin(angle) + dy * math.cos(angle)
                        points.append((x, y))
                    pygame.draw.polygon(debris_surf, color, points)
                
                else:  # square or default
                    # Draw square debris
                    points = []
                    for i in range(4):
                        angle = math.radians(debris['rotation'] + i * 90)
                        x = debris['size'] + debris['size'] * 0.8 * math.cos(angle)
                        y = debris['size'] + debris['size'] * 0.8 * math.sin(angle)
                        points.append((x, y))
                    if len(points) >= 3:
                        pygame.draw.polygon(debris_surf, color, points)
                
                surface.blit(debris_surf, 
                           (int(debris['x'] - debris['size']), 
                            int(debris['y'] - debris['size'])))
    
    def _draw_falling_lanterns(self, surface: pygame.Surface):
        """Draw lanterns falling during destruction"""
        for lantern in self.falling_lanterns:
            if not lantern['broken']:
                # Lantern size
                sizes = {
                    'small': (15, 20),
                    'medium': (20, 25),
                    'large': (25, 30),
                }
                base_width, base_height = sizes[lantern['size']]
                
                # Apply deformation (squash effect)
                deformation = lantern.get('deformation', 0)
                width = base_width * (1 + deformation * 0.5)  # Wider when squashed
                height = base_height * (1 - deformation)  # Shorter when squashed
                
                # Create larger surface for deformed lantern
                surf_size = max(int(width * 2), int(height * 2)) + 20
                lantern_surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
                
                # Draw lantern body with deformation
                cx, cy = surf_size // 2, surf_size // 2
                
                # Adjust shape based on deformation
                if deformation > 0:
                    # Squashed shape - wider at bottom, flattened
                    points = [
                        (cx - width // 2 * 0.7, cy - height // 2),  # Top left (narrower)
                        (cx + width // 2 * 0.7, cy - height // 2),  # Top right (narrower)
                        (cx + width // 2, cy + height // 2),  # Bottom right (wider)
                        (cx - width // 2, cy + height // 2),  # Bottom left (wider)
                    ]
                else:
                    # Normal lantern shape
                    points = [
                        (cx - width // 2, cy - height // 2),
                        (cx + width // 2, cy - height // 2),
                        (cx + width // 2 - 3, cy + height // 2),
                        (cx - width // 2 + 3, cy + height // 2),
                    ]
                
                # Rotate points
                rotated_points = []
                angle = math.radians(lantern['rotation'])
                for px, py in points:
                    dx = px - cx
                    dy = py - cy
                    rx = cx + dx * math.cos(angle) - dy * math.sin(angle)
                    ry = cy + dx * math.sin(angle) + dy * math.cos(angle)
                    rotated_points.append((rx, ry))
                
                # Draw lantern with some transparency as it falls
                # More damaged appearance when deformed
                opacity = 200 if deformation == 0 else int(200 - deformation * 100)
                pygame.draw.polygon(lantern_surf, (*self.colors['lantern_red'], opacity), rotated_points)
                pygame.draw.polygon(lantern_surf, self.colors['temple_dark'], rotated_points, 1)
                
                # Draw flame inside (flickering, dimmer when deformed)
                if self.frame_count % 3 == 0 and deformation < 0.3:
                    flame_opacity = int(150 * (1 - deformation * 2))
                    flame_color = (255, 200, 100, flame_opacity)
                    flame_size = int(width // 3 * (1 - deformation))
                    pygame.draw.circle(lantern_surf, flame_color, (cx, cy), flame_size)
                
                # Add cracks when deformed
                if deformation > 0.2:
                    crack_color = (50, 30, 20, 100)
                    for i in range(3):
                        angle = random.random() * math.pi * 2
                        start_x = cx + random.randint(-int(width//3), int(width//3))
                        start_y = cy + random.randint(-int(height//3), int(height//3))
                        end_x = start_x + math.cos(angle) * width // 2
                        end_y = start_y + math.sin(angle) * height // 2
                        pygame.draw.line(lantern_surf, crack_color, 
                                       (start_x, start_y), (end_x, end_y), 1)
                
                surface.blit(lantern_surf, 
                           (int(lantern['x'] - surf_size // 2), 
                            int(lantern['y'] - surf_size // 2)))
    
    def _draw_ground_fires(self, surface: pygame.Surface):
        """Draw fire effects on the ground"""
        for fire in self.ground_fires:
            for particle in fire['particles']:
                # Fire color gradient (yellow -> orange -> red)
                if particle['color_phase'] < 0.3:
                    color = (255, 255, 100)  # Yellow
                elif particle['color_phase'] < 0.6:
                    color = (255, 150, 50)   # Orange
                else:
                    color = (255, 50, 50)     # Red
                
                # Add transparency based on life
                alpha = int(200 * (particle['life'] / 40))
                
                # Create particle surface
                particle_surf = pygame.Surface((particle['size'] * 2, particle['size'] * 2), pygame.SRCALPHA)
                pygame.draw.circle(particle_surf, (*color, alpha), 
                                 (particle['size'], particle['size']), 
                                 particle['size'])
                
                surface.blit(particle_surf,
                           (int(particle['x'] - particle['size']),
                            int(particle['y'] - particle['size'])))
    
    def _draw_ruins(self, surface: pygame.Surface):
        """Draw the ruined temple after destruction"""
        # Draw broken temple base
        ruins_y = 550 + self.collapse_offset // 2
        
        # Broken foundation
        pygame.draw.polygon(surface, self.colors['ruins'],
                          [(self.width//2 - 120, ruins_y),
                           (self.width//2 - 80, ruins_y - 20),
                           (self.width//2 + 90, ruins_y - 15),
                           (self.width//2 + 110, ruins_y + 10)])
        
        # Scattered stones
        for i in range(8):
            stone_x = self.width//2 - 100 + i * 30 + random.randint(-10, 10)
            stone_y = ruins_y + random.randint(-10, 20)
            stone_size = random.randint(10, 25)
            pygame.draw.ellipse(surface, self.colors['stone_dark'],
                              (stone_x, stone_y, stone_size, stone_size // 2))
        
        # Broken pillars
        for offset in [-60, 60]:
            pillar_x = self.width//2 + offset
            # Broken pillar stub
            pygame.draw.rect(surface, self.colors['temple_dark'],
                           (pillar_x - 8, ruins_y - 30, 16, 30))
            # Cracks
            for j in range(3):
                crack_y = ruins_y - 25 + j * 8
                pygame.draw.line(surface, (20, 20, 20),
                               (pillar_x - 5, crack_y),
                               (pillar_x + 5, crack_y + 3), 1)
    
    def _spawn_moon_fragments(self):
        """Spawn red crater fragments from the moon"""
        # Spawn 3-5 fragments at once
        num_fragments = random.randint(3, 5)
        
        # Moon position (top-right area, same as where moon is drawn)
        moon_x = self.width - 120
        moon_y = 100
        
        # Activate moon pulsing effect
        self.moon_pulse_active = True
        self.moon_pulse_timer = 30  # 0.5 second pulse
        
        for _ in range(num_fragments):
            # Random target position across the entire map, including player area
            target_x = random.randint(50, self.width - 50)
            # Target area from middle to player position (500-710)
            # Player is around HEIGHT-140 (610) to HEIGHT-40 (710)
            target_y = random.randint(500, self.height - 40)  # Cover full playable area including player
            
            # Calculate trajectory
            dx = target_x - moon_x
            dy = target_y - moon_y
            distance = math.sqrt(dx*dx + dy*dy)
            
            # Normalize and set velocity (increased speed for better reach)
            speed = random.uniform(5, 8)  # Increased from 3-5 to 5-8
            vx = (dx / distance) * speed
            vy = (dy / distance) * speed
            
            fragment = {
                'x': moon_x + random.randint(-30, 30),  # Start near moon
                'y': moon_y + random.randint(-30, 30),
                'vx': vx,
                'vy': vy,
                'target_x': target_x,
                'target_y': target_y,
                'size': random.randint(8, 15),
                'rotation': 0,
                'rotation_speed': random.uniform(-10, 10),
                'lifetime': 300,  # 5 seconds - increased for better reach
                'trail': [],  # Trail effect
                'impact': False,
                'glow_phase': random.uniform(0, math.pi * 2),
            }
            self.moon_fragments.append(fragment)
        
        print(f"Spawned {num_fragments} moon fragments from ({moon_x}, {moon_y})!")
        for frag in self.moon_fragments[-num_fragments:]:
            print(f"  Fragment target: ({frag['target_x']}, {frag['target_y']}), speed: {math.sqrt(frag['vx']**2 + frag['vy']**2):.1f}")
    
    def _update_moon_fragments(self):
        """Update moon crater fragments"""
        # Update moon pulsing effect
        if self.moon_pulse_active:
            if self.moon_pulse_timer > 0:
                self.moon_pulse_timer -= 1
                # Create pulsing effect with sin wave
                pulse_progress = (30 - self.moon_pulse_timer) / 30.0
                self.moon_pulse_scale = 1.0 + math.sin(pulse_progress * math.pi) * 0.3  # Pulse up to 30% larger
            else:
                self.moon_pulse_active = False
                self.moon_pulse_scale = 1.0
        
        # Only spawn fragments if moon is red and temple is destroyed
        if self.moon_fragment_active or (self.temple_destroyed and self.moon_red_intensity > 0):
            self.moon_fragment_active = True
            
            # Update spawn timer
            self.moon_fragment_timer += 1
            if self.moon_fragment_timer >= self.moon_fragment_interval:
                self._spawn_moon_fragments()
                self.moon_fragment_timer = 0
                # Reset interval for next spawn
                self.moon_fragment_interval = random.randint(1200, 1800)  # 20-30 seconds
        
        # Update existing fragments
        for fragment in self.moon_fragments[:]:
            if not fragment['impact']:
                # Update position
                fragment['x'] += fragment['vx']
                fragment['y'] += fragment['vy']
                fragment['rotation'] += fragment['rotation_speed']
                fragment['glow_phase'] += 0.1
                
                # Add to trail
                if len(fragment['trail']) < 15:
                    fragment['trail'].append({
                        'x': fragment['x'],
                        'y': fragment['y'],
                        'size': fragment['size'] * 0.7,
                        'alpha': 150,
                    })
                else:
                    # Shift trail and add new position
                    fragment['trail'].pop(0)
                    fragment['trail'].append({
                        'x': fragment['x'],
                        'y': fragment['y'],
                        'size': fragment['size'] * 0.7,
                        'alpha': 150,
                    })
                
                # Fade trail
                for i, trail_point in enumerate(fragment['trail']):
                    trail_point['alpha'] = int(150 * (i / len(fragment['trail'])))
                
                # Check if reached target or went off screen
                dist_to_target = math.sqrt((fragment['x'] - fragment['target_x'])**2 + 
                                          (fragment['y'] - fragment['target_y'])**2)
                
                # Only impact when went completely off screen
                # Remove target distance check - let fragments continue until off screen
                off_screen = (fragment['y'] >= self.height + 10 or  # Give more room at bottom
                             fragment['x'] < -30 or fragment['x'] > self.width + 30)
                
                # Also check lifetime
                fragment['lifetime'] -= 1
                expired = fragment['lifetime'] <= 0
                
                if off_screen or expired:
                    # Debug: print why fragment is impacting
                    if off_screen:
                        print(f"Fragment impact: off screen at ({fragment['x']:.0f}, {fragment['y']:.0f})")
                    elif expired:
                        print(f"Fragment impact: expired at ({fragment['x']:.0f}, {fragment['y']:.0f})")
                    
                    fragment['impact'] = True
                    fragment['impact_timer'] = 30  # 0.5 second impact effect
                    # Create impact shockwave effect
                    fragment['shockwave_radius'] = 0
            else:
                # Handle impact animation
                if fragment.get('impact_timer', 0) > 0:
                    fragment['impact_timer'] -= 1
                    fragment['shockwave_radius'] = (30 - fragment['impact_timer']) * 3
                else:
                    # Remove fragment after impact
                    self.moon_fragments.remove(fragment)
    
    def _explode_all_monks(self):
        """Explode all monks when temple is destroyed"""
        for monk in self.monks:
            # Check if this is a hero monk (star reward monk)
            is_hero = monk.get('type') == 'star_reward'
            
            if is_hero:
                # Special explosion for hero monks - bigger and more dramatic
                self._create_hero_monk_explosion(monk['x'], monk['y'])
                
                # More body parts for hero monks
                for i in range(10):  # 10 body parts for heroes
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(8, 16)  # Faster flying parts
                    body_part = {
                        'x': monk['x'],
                        'y': monk['y'],
                        'vx': math.cos(angle) * speed,
                        'vy': math.sin(angle) * speed - 8,  # More upward force
                        'gravity': 0.5,
                        'rotation': random.uniform(0, 360),
                        'rotation_speed': random.uniform(-30, 30),
                        'size': random.randint(10, 20),  # Bigger parts
                        'color': (255, 215, 0),  # Gold color for hero parts
                        'lifetime': 240,  # 4 seconds
                        'type': random.choice(['arm', 'leg', 'torso', 'head']),
                        'is_hero': True,
                        'glow': True
                    }
                    self.monk_body_parts.append(body_part)
            else:
                # Normal explosion for regular monks
                self._create_monk_explosion(monk['x'], monk['y'], monk.get('color', self.colors['temple_main']))
                
                # Create body parts flying in random directions
                for i in range(6):  # 6 body parts
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(5, 12)
                    body_part = {
                        'x': monk['x'],
                        'y': monk['y'],
                        'vx': math.cos(angle) * speed,
                        'vy': math.sin(angle) * speed - 5,  # Add upward force
                        'gravity': 0.4,
                        'rotation': random.uniform(0, 360),
                        'rotation_speed': random.uniform(-20, 20),
                        'size': random.randint(8, 16),
                        'color': monk.get('color', self.colors['temple_main']),
                        'lifetime': 180,  # 3 seconds
                        'type': random.choice(['arm', 'leg', 'torso', 'head'])
                    }
                    self.monk_body_parts.append(body_part)
        
        # Clear all monks
        self.monks.clear()
        print(f"All monks exploded during temple destruction!")
    
    def _explode_all_training_dummies(self):
        """Explode all training dummies when temple is destroyed"""
        for dummy in self.training_dummies:
            # Create wooden splinters
            for i in range(8):
                angle = random.uniform(0, math.pi * 2)
                speed = random.uniform(3, 8)
                splinter = {
                    'x': dummy['x'],
                    'y': dummy['y'],
                    'vx': math.cos(angle) * speed,
                    'vy': math.sin(angle) * speed - 3,
                    'gravity': 0.3,
                    'rotation': random.uniform(0, 360),
                    'rotation_speed': random.uniform(-15, 15),
                    'size': random.randint(5, 12),
                    'color': (139, 90, 43),  # Wood brown
                    'lifetime': 150,
                    'opacity': 255,  # Add opacity
                }
                self.collapse_debris.append(splinter)
                
            # Add dust cloud
            self._create_dust_cloud(dummy['x'], dummy['y'])
        
        # Clear all dummies
        self.training_dummies.clear()
        self.dummy_animations.clear()
    
    def _create_monk_explosion(self, x, y, color):
        """Create blood explosion effect when monk dies"""
        # Create blood particles
        for i in range(20):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 8)
            particle = {
                'x': x,
                'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'size': random.randint(2, 6),
                'color': (200, 0, 0),  # Blood red
                'lifetime': 60,
                'gravity': 0.2,
            }
            self.monk_death_particles.append(particle)
        
        # Add some darker blood droplets
        for i in range(10):
            angle = random.uniform(0, math.pi * 2) 
            speed = random.uniform(1, 4)
            particle = {
                'x': x,
                'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'size': random.randint(3, 8),
                'color': (120, 0, 0),  # Dark blood
                'lifetime': 80,
                'gravity': 0.3,
            }
            self.monk_death_particles.append(particle)
    
    def _create_hero_monk_explosion(self, x, y):
        """Create epic explosion effect for hero monks"""
        # Create golden explosion particles
        for i in range(40):  # More particles for heroes
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(3, 12)
            particle = {
                'x': x,
                'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - 2,
                'size': random.randint(3, 8),
                'color': (255, 215, 0),  # Gold
                'lifetime': 80,
                'gravity': 0.3,
                'glow': True
            }
            self.monk_death_particles.append(particle)
        
        # Add sparkles
        for i in range(20):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(5, 15)
            sparkle = {
                'x': x,
                'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - 3,
                'size': random.randint(2, 4),
                'color': (255, 255, 200),  # Bright yellow-white
                'lifetime': 40,
                'gravity': 0.1,
                'type': 'sparkle'
            }
            self.monk_death_particles.append(sparkle)
        
        # Add shockwave effect
        shockwave = {
            'x': x,
            'y': y,
            'radius': 0,
            'max_radius': 80,
            'color': (255, 215, 0),
            'lifetime': 30,
            'type': 'shockwave'
        }
        self.monk_death_particles.append(shockwave)
    
    def _create_dust_cloud(self, x, y):
        """Create dust cloud effect"""
        for i in range(15):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(1, 3)
            dust = {
                'x': x,
                'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - 1,
                'size': random.randint(10, 20),
                'color': (150, 130, 100),  # Dust color
                'lifetime': 45,
                'opacity': 150,
            }
            self.monk_death_particles.append(dust)
    
    def reset(self):
        """Reset stage 4 background to initial state"""
        # Reset temple destruction state
        self.temple_destroyed = False
        self.destruction_animation_active = False
        self.destruction_phase = 0
        self.destruction_timer = 0
        self.moon_red_intensity = 0.0
        self.red_light_alpha = 0
        self.collapse_offset = 0
        self.collapse_debris = []
        self.screen_shake_offset = [0, 0]
        self.screen_shake_intensity = 0
        self.falling_lanterns = []
        self.ground_fires = []
        
        # Reset moon crater fragments
        self.moon_fragments = []
        self.moon_fragment_timer = 0
        self.moon_fragment_interval = random.randint(1200, 1800)
        self.moon_fragment_active = False
        
        # Reset moon pulsing
        self.moon_pulse_timer = 0
        self.moon_pulse_active = False
        self.moon_pulse_scale = 1.0
        
        # Reset performance mode
        self.performance_mode = False
        self.fps_counter = 0
        
        # Clear caches
        self.red_moon_cache = None
        self.red_moon_cache_intensity = -1
        self.red_moon_cache_scale = -1
        self.red_moon_update_counter = 0
        
        # Reset monk animations
        for monk_id in self.monk_hit_effects:
            self.monk_hit_effects[monk_id] = {
                'timer': 0,
                'intensity': 0,
                'direction': 0
            }
        
        # Clear hit effects
        self.moon_fragments.clear()
        
        # Clear death effects
        self.monk_death_particles.clear()
        self.monk_body_parts.clear()
        
        # Reset crows positions
        for crow in self.crows:
            crow['reset_timer'] = 30  # Will respawn at original position
        
        # Clear crow fragments
        self.crow_fragments.clear()
        
        # Reset animated elements
        self.lanterns = self._create_lanterns()
        self.incense_particles = []
        self.floating_leaves = self._create_leaves()
        self.bell_swing = 0
        
        # Force recreation of static surface
        self.static_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self._draw_static_background()
        
        print("Stage 4: Shaolin Temple background reset to initial state")
    
    def _draw_moon_fragments(self, surface: pygame.Surface):
        """Draw moon crater fragments"""
        for fragment in self.moon_fragments:
            if not fragment['impact']:
                # Draw trail
                for trail_point in fragment['trail']:
                    trail_surf = pygame.Surface((trail_point['size'] * 2, trail_point['size'] * 2), pygame.SRCALPHA)
                    # Glowing trail
                    for i in range(3):
                        radius = trail_point['size'] - i * 2
                        if radius > 0:
                            alpha = trail_point['alpha'] // (i + 1)
                            color = (*self.colors['fragment_trail'][:3], alpha)
                            pygame.draw.circle(trail_surf, color,
                                             (trail_point['size'], trail_point['size']),
                                             radius)
                    surface.blit(trail_surf,
                               (int(trail_point['x'] - trail_point['size']),
                                int(trail_point['y'] - trail_point['size'])))
                
                # Draw main fragment with glow
                fragment_surf = pygame.Surface((fragment['size'] * 4, fragment['size'] * 4), pygame.SRCALPHA)
                center = fragment['size'] * 2
                
                # Outer glow (pulsing)
                glow_intensity = abs(math.sin(fragment['glow_phase'])) * 0.5 + 0.5
                glow_size = fragment['size'] * 2 * glow_intensity
                pygame.draw.circle(fragment_surf, (*self.colors['fragment_glow'], 50),
                                 (center, center), int(glow_size))
                
                # Middle glow
                pygame.draw.circle(fragment_surf, (*self.colors['fragment_glow'], 100),
                                 (center, center), int(fragment['size'] * 1.5))
                
                # Core (rocky texture)
                points = []
                num_points = 8
                for i in range(num_points):
                    angle = (i * 2 * math.pi / num_points) + math.radians(fragment['rotation'])
                    radius = fragment['size'] * random.uniform(0.8, 1.0)
                    x = center + radius * math.cos(angle)
                    y = center + radius * math.sin(angle)
                    points.append((x, y))
                
                if len(points) >= 3:
                    pygame.draw.polygon(fragment_surf, self.colors['fragment_core'], points)
                    pygame.draw.polygon(fragment_surf, (255, 255, 200), points, 2)  # Bright edge
                
                surface.blit(fragment_surf,
                           (int(fragment['x'] - center),
                            int(fragment['y'] - center)))
            else:
                # Draw impact effect
                if fragment.get('impact_timer', 0) > 0:
                    # Shockwave
                    if fragment.get('shockwave_radius', 0) > 0:
                        shockwave_surf = pygame.Surface((fragment['shockwave_radius'] * 2, 
                                                        fragment['shockwave_radius'] * 2), pygame.SRCALPHA)
                        alpha = int(150 * (fragment['impact_timer'] / 30))
                        pygame.draw.circle(shockwave_surf, (*self.colors['fragment_glow'], alpha),
                                         (fragment['shockwave_radius'], fragment['shockwave_radius']),
                                         fragment['shockwave_radius'], 3)
                        surface.blit(shockwave_surf,
                                   (int(fragment['x'] - fragment['shockwave_radius']),
                                    int(fragment['y'] - fragment['shockwave_radius'])))
                    
                    # Impact sparks
                    for i in range(5):
                        spark_angle = (i * 72 + fragment['rotation']) * math.pi / 180
                        spark_dist = fragment.get('shockwave_radius', 0) * 0.5
                        spark_x = fragment['x'] + math.cos(spark_angle) * spark_dist
                        spark_y = fragment['y'] + math.sin(spark_angle) * spark_dist
                        spark_size = random.randint(2, 4)
                        pygame.draw.circle(surface, self.colors['fragment_core'],
                                         (int(spark_x), int(spark_y)), spark_size)
    
    def get_moon_fragments(self):
        """Get current moon fragments for collision detection"""
        active_fragments = []
        for fragment in self.moon_fragments:
            if not fragment['impact']:
                active_fragments.append({
                    'x': fragment['x'],
                    'y': fragment['y'],
                    'radius': fragment['size'],
                })
        return active_fragments


def main():
    """Test the Shaolin Temple background"""
    pygame.init()
    screen = pygame.display.set_mode((600, 750))
    pygame.display.set_caption("Stage 4: Shaolin Temple")
    clock = pygame.time.Clock()
    
    background = ShaolinTempleBackground(600, 750)
    
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
        
        # Clear screen
        screen.fill((0, 0, 0))
        
        # Draw background
        background.draw(screen)
        
        # Update display
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()


if __name__ == "__main__":
    main()