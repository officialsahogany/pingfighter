# -*- coding: utf-8 -*-
"""
Stage 4: Shaolin Temple (소림사 사원) Background
Oriental temple theme with traditional Chinese architecture and martial arts atmosphere
"""

import pygame
import math
import random
import os
import sys
from typing import List, Tuple, Dict, Any

def resource_path(relative_path):
    """PyInstaller 번들과 일반 실행 모두에서 작동하는 리소스 경로 반환"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
        if os.path.basename(base_path) == "ui":
            base_path = os.path.dirname(base_path)
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

# 픽셀 폰트 경로
PIXEL_FONT = resource_path("PFStardust.ttf")

# 화면 크기 - config에서 가져오기
try:
    from config.constants import SCREEN_WIDTH, SCREEN_HEIGHT, PILLAR_UI_WIDTH, GAME_PLAY_WIDTH
    DEFAULT_WIDTH = SCREEN_WIDTH  # 760px
    DEFAULT_HEIGHT = SCREEN_HEIGHT  # 750px
    PILLAR_OFFSET = PILLAR_UI_WIDTH  # 80px
    GAME_WIDTH = GAME_PLAY_WIDTH  # 600px
except ImportError:
    DEFAULT_WIDTH = 760
    DEFAULT_HEIGHT = 750
    PILLAR_OFFSET = 80
    GAME_WIDTH = 600

class ShaolinTempleBackground:
    def __init__(self, width: int = None, height: int = None):
        self.width = width if width is not None else DEFAULT_WIDTH
        self.height = height if height is not None else DEFAULT_HEIGHT
        self.pillar_offset = PILLAR_OFFSET
        self.game_width = GAME_WIDTH
        # 게임 영역 중앙 X 좌표
        self.game_center_x = self.pillar_offset + self.game_width // 2
        self.frame_count = 0
        
        # Temple destruction state
        self.temple_destroyed = False
        self.destruction_animation_active = False
        self.destruction_phase = 0  # 0: idle, 1: moon turning red, 2: red light, 3: destruction wave, 4: collapsing, 5: ruins
        self.destruction_timer = 0
        self.moon_red_intensity = 0.0
        self.red_light_alpha = 0
        self.collapse_offset = 0
        self.collapse_debris = []
        self.screen_shake_offset = [0, 0]
        self.screen_shake_intensity = 0
        self.falling_lanterns = []  # Lanterns that are falling during destruction
        self.ground_fires = []  # Fire effects on ground from broken lanterns

        # 새로운 건물 찌그러짐/가라앉음 애니메이션 변수
        self.building_sink_amount = 0.0  # 건물이 가라앉는 정도 (0.0 ~ 1.0)
        self.building_crush_factor = 1.0  # 건물 수직 압축 비율 (1.0 = 정상, 0.3 = 70% 압축)
        self.level_crush_offsets = [0, 0, 0, 0, 0]  # 각 층별 압축 오프셋
        self.roof_fragments = []  # 지붕 기와 파편
        self.wall_cracks = []  # 벽 균열 효과
        self.dust_clouds = []  # 먼지 구름 효과
        self.spire_fallen = False  # 상륜부 무너짐 여부
        self.spire_fall_angle = 0  # 상륜부 기울어진 각도
        
        # Moon crater fragments system
        self.moon_fragments = []  # Active moon crater fragments
        self.moon_fragment_timer = 0  # Timer for spawning fragments
        self.moon_fragment_interval = random.randint(120, 900)  # 2-15 seconds at 60 FPS
        self.moon_fragment_active = False  # Only active after moon turns red
        self.fragment_hit_cooldowns = {}  # 다단히트용 파편별 히트 쿨다운 (fragment_id -> last_hit_time)
        
        # Moon pulsing effect when firing fragments
        self.moon_pulse_timer = 0  # Timer for pulsing animation
        self.moon_pulse_active = False  # Whether moon is pulsing
        self.moon_pulse_scale = 1.0  # Scale factor for moon size
        
        # Destruction wave from moon
        self.destruction_wave = None  # Active destruction wave
        self.destruction_wave_charging = False  # Moon charging up wave
        # Stage4 moon fragment hit sound (building impact)
        self.stage4_hit_sound = None
        self.stage4_moon_shoot_sound = None
        self.stage4_fragment_shoot_sound = None
        try:
            self.stage4_hit_sound = pygame.mixer.Sound(resource_path("sounds/stage4hitting.wav"))
        except Exception:
            # Sound load failure should not break gameplay
            self.stage4_hit_sound = None
        try:
            self.stage4_moon_shoot_sound = pygame.mixer.Sound(resource_path("sounds/stage4moonshoot.wav"))
        except Exception:
            self.stage4_moon_shoot_sound = None
        try:
            self.stage4_fragment_shoot_sound = pygame.mixer.Sound(resource_path("sounds/stage4moonshoot2.wav"))
        except Exception:
            self.stage4_fragment_shoot_sound = None

        # Approximate temple hitbox used for moon-fragment collision
        temple_width = 280
        temple_height = 380
        temple_x = self.game_center_x - temple_width // 2  # 게임 영역 중앙 기준
        temple_y = max(0, 450 - temple_height)  # top of temple
        self.temple_hitbox = pygame.Rect(temple_x, temple_y, temple_width, temple_height + 60)  # include stairs
        
        # OPTIMIZATION: Cache for red moon effect
        self.red_moon_cache = None  # Cached red moon surface
        self.red_moon_cache_intensity = -1  # Last cached intensity
        self.red_moon_cache_scale = -1  # Last cached scale
        self.red_moon_update_counter = 0  # Update every N frames
        
        # OPTIMIZATION: Performance mode for low FPS
        self.performance_mode = False  # Enable reduced quality for better FPS
        self.fps_counter = 0
        self.low_fps_threshold = 55  # Enable performance mode below 55 FPS (increased from 50)
        
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

        # Temple door animation state (사원 쌍여닫이 문 애니메이션)
        self.door_open_amount = 0.0  # 0.0 = 닫힘, 1.0 = 완전히 열림
        self.door_target_open = 0.0  # 목표 열림 상태
        self.door_animation_speed = 0.08  # 문 열림/닫힘 속도
        self.door_entrance_y = 450  # 입구 Y 좌표
        self.door_trigger_distance = 30  # 문 열림을 트리거하는 거리
        
        # Background surface for static elements (with transparency support)
        self.static_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self._draw_static_background()
        # Reusable working surfaces to avoid per-frame allocations
        self._temp_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self._red_overlay_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
    def _create_lanterns(self) -> List[Dict[str, Any]]:
        """Create hanging lanterns"""
        lanterns = []
        # 필러 오프셋 적용
        offset = self.pillar_offset
        positions = [
            # (100, 150), (500, 150),  # 상단 좌우 - 제거됨
            (offset + 50, 300), (offset + 550, 300),   # 중단 좌우
            (offset + 150, 250), (offset + 450, 250),  # 중앙 좌우
            (offset + 250, 180), (offset + 350, 180),  # 중앙 상단
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
        offset = self.pillar_offset
        positions = [(offset + 200, 280), (offset + 400, 280)]  # 좌우 용 장식

        for x, y in positions:
            dragons.append({
                'x': x,
                'y': y,
                'eye_glow': 0,
                'eye_glow_speed': random.uniform(0.02, 0.03),
                'facing': 'left' if x < self.game_center_x else 'right',
            })
        return dragons

    def _create_training_dummies(self) -> List[Dict[str, Any]]:
        """Create martial arts training dummies"""
        dummies = []
        offset = self.pillar_offset
        positions = [(offset + 120, 500), (offset + 480, 500)]  # 가운데 더미 제거

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
        moon_x, moon_y = self.pillar_offset + self.game_width - 120, 100
        
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
        moon_x, moon_y = self.pillar_offset + self.game_width - 120, 100
        
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
        """Draw the main temple structure - Ultra High Quality version"""
        # Base temple building
        temple_x = self.game_center_x
        temple_base_y = 450

        # Apply gradual collapse offset if destruction is active
        collapse_y_offset = 0
        collapse_rotation = 0
        collapse_opacity = 255

        # 새로운 찌그러짐/가라앉음 효과 변수
        building_crush = getattr(self, 'building_crush_factor', 1.0)
        building_sink = getattr(self, 'building_sink_amount', 0.0)
        level_crushes = getattr(self, 'level_crush_offsets', [0, 0, 0, 0, 0])
        spire_angle = getattr(self, 'spire_fall_angle', 0)

        if hasattr(self, 'collapse_offset') and self.collapse_offset > 0:
            collapse_y_offset = self.collapse_offset
            collapse_rotation = min(5, self.collapse_offset / 30)
            collapse_opacity = max(100, 255 - self.collapse_offset)

        # Create temple surface for collapse effects
        temple_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

        # 5층 탑 그리기 (울트라 고품질 버전)
        # 가라앉음 오프셋 계산 (최대 300 픽셀까지 가라앉음)
        sink_offset = building_sink * 300

        for level in range(self.pagoda_levels):
            level_collapse_offset = collapse_y_offset * (1 + level * 0.1)

            # 층별 찌그러짐 효과 적용
            # 각 층의 높이가 crush_factor에 따라 압축됨
            original_level_height = 60  # 원래 층 간격
            crushed_level_height = original_level_height * building_crush

            # 층별 개별 찌그러짐 오프셋 적용 (위층일수록 더 많이 압축)
            level_crush_offset = level_crushes[level] if level < len(level_crushes) else 0

            # 새로운 Y 좌표 계산: 베이스에서 시작하여 압축된 층 높이 적용 + 가라앉음
            level_y = temple_base_y - level * crushed_level_height + level_collapse_offset + sink_offset + level_crush_offset
            level_width = 200 - level * 25

            # 층 높이도 압축됨
            level_height = int(50 * building_crush)
            level_height = max(level_height, 10)  # 최소 높이 보장

            # === 층 몸체 (다층 그라데이션 + 벽돌 질감) ===
            body_x = temple_x - level_width // 2
            body_y = level_y - level_height

            # 다층 그림자 (깊이감 강화)
            for shadow_i in range(3):
                shadow_alpha = int(collapse_opacity * (0.4 - shadow_i * 0.1))
                shadow_offset = 4 - shadow_i
                shadow_color = (*self.colors['temple_dark'], shadow_alpha)
                pygame.draw.rect(temple_surface, shadow_color,
                               (body_x + shadow_offset, body_y + shadow_offset, level_width, level_height))

            # 베이스 레이어 (그라데이션 효과)
            for grad_y in range(level_height):
                grad_ratio = grad_y / level_height
                # 위에서 아래로 점점 어두워지는 그라데이션
                r = int(self.colors['temple_main'][0] * (1 - grad_ratio * 0.15))
                g = int(self.colors['temple_main'][1] * (1 - grad_ratio * 0.15))
                b = int(self.colors['temple_main'][2] * (1 - grad_ratio * 0.15))
                grad_color = (r, g, b, collapse_opacity)
                pygame.draw.line(temple_surface, grad_color,
                               (body_x, body_y + grad_y), (body_x + level_width, body_y + grad_y), 1)

            # 벽돌/돌 질감 패턴
            brick_dark = (*self.colors['temple_dark'], int(collapse_opacity * 0.3))
            brick_light = (*self.colors['temple_highlight'], int(collapse_opacity * 0.2))
            brick_height = 8
            brick_width = 20
            for by in range(0, level_height, brick_height):
                offset = (by // brick_height % 2) * (brick_width // 2)
                for bx in range(0, level_width, brick_width):
                    brick_x = body_x + bx + offset
                    if brick_x < body_x + level_width - 5:
                        # 벽돌 아래쪽 그림자
                        pygame.draw.line(temple_surface, brick_dark,
                                       (brick_x, body_y + by + brick_height - 1),
                                       (min(brick_x + brick_width, body_x + level_width), body_y + by + brick_height - 1), 1)
                        # 벽돌 오른쪽 그림자
                        pygame.draw.line(temple_surface, brick_dark,
                                       (min(brick_x + brick_width, body_x + level_width - 1), body_y + by),
                                       (min(brick_x + brick_width, body_x + level_width - 1), body_y + by + brick_height), 1)

            # 하이라이트 그라데이션 (상단 - 더 정교하게)
            for hi in range(10):
                hi_alpha = int(collapse_opacity * 0.5 * (1 - hi / 10))
                highlight_color = (*self.colors['temple_highlight'], hi_alpha)
                pygame.draw.line(temple_surface, highlight_color,
                               (body_x + 2, body_y + hi), (body_x + level_width - 2, body_y + hi), 1)

            # 세로 기둥 (3D 효과)
            num_pillars = max(3, level_width // 35)
            for p in range(num_pillars + 1):
                px = body_x + (level_width * p) // num_pillars
                pillar_width = 6
                # 기둥 그림자
                pillar_shadow = (*self.colors['temple_dark'], int(collapse_opacity * 0.7))
                pygame.draw.rect(temple_surface, pillar_shadow,
                               (px - pillar_width // 2 + 1, body_y + 3, pillar_width, level_height - 6))
                # 기둥 메인
                pillar_main = (*self.colors['temple_main'], int(collapse_opacity * 0.9))
                pygame.draw.rect(temple_surface, pillar_main,
                               (px - pillar_width // 2, body_y + 2, pillar_width - 1, level_height - 4))
                # 기둥 하이라이트
                pillar_light = (*self.colors['temple_highlight'], int(collapse_opacity * 0.5))
                pygame.draw.line(temple_surface, pillar_light,
                               (px - pillar_width // 2, body_y + 4),
                               (px - pillar_width // 2, body_y + level_height - 6), 1)
                # 기둥 상단 장식
                pygame.draw.rect(temple_surface, (*self.colors['gold_dim'], int(collapse_opacity * 0.6)),
                               (px - pillar_width // 2 - 1, body_y + 1, pillar_width + 2, 3))

            # 가로 띠 장식 (다층)
            band_y = body_y + level_height - 14
            band_shadow = (*self.colors['temple_dark'], int(collapse_opacity * 0.6))
            pygame.draw.rect(temple_surface, band_shadow, (body_x + 4, band_y + 2, level_width - 8, 5))
            band_color = (*self.colors['gold_dim'], int(collapse_opacity * 0.7))
            pygame.draw.rect(temple_surface, band_color, (body_x + 3, band_y, level_width - 6, 4))
            band_light = (min(255, self.colors['gold_dim'][0] + 30),
                         min(255, self.colors['gold_dim'][1] + 25),
                         min(255, self.colors['gold_dim'][2] + 15), int(collapse_opacity * 0.5))
            pygame.draw.line(temple_surface, band_light,
                           (body_x + 5, band_y), (body_x + level_width - 5, band_y), 1)

            # 작은 난간 장식 (상단)
            railing_y = body_y - 3
            for rx in range(body_x + 10, body_x + level_width - 10, 12):
                # 난간 기둥
                pygame.draw.rect(temple_surface, (*self.colors['temple_dark'], int(collapse_opacity * 0.8)),
                               (rx, railing_y, 3, 5))
                pygame.draw.rect(temple_surface, (*self.colors['temple_highlight'], int(collapse_opacity * 0.4)),
                               (rx, railing_y, 1, 4))

            # 테두리 (다층)
            pygame.draw.rect(temple_surface, (*self.colors['temple_dark'], int(collapse_opacity * 0.9)),
                           (body_x, body_y, level_width, level_height), 2)
            pygame.draw.rect(temple_surface, (*self.colors['temple_highlight'], int(collapse_opacity * 0.3)),
                           (body_x + 1, body_y + 1, level_width - 2, level_height - 2), 1)

            # === 기와 지붕 (울트라 고품질) ===
            roof_overhang = 22 + level * 3
            # 지붕 높이도 압축 적용
            base_roof_height = 28 + level * 2
            roof_height = int(base_roof_height * building_crush)
            roof_height = max(roof_height, 8)  # 최소 높이 보장

            roof_left = temple_x - level_width // 2 - roof_overhang
            roof_right = temple_x + level_width // 2 + roof_overhang
            roof_top = level_y - level_height - roof_height
            roof_bottom = level_y - level_height

            # 지붕 두께감 (다층 그림자)
            for ri in range(4):
                roof_shadow = [
                    (roof_left + 4 - ri, roof_bottom + 3 - ri),
                    (roof_right + 4 - ri, roof_bottom + 3 - ri),
                    (roof_right - roof_overhang // 2 + 4 - ri, roof_top + 6 + 3 - ri),
                    (roof_left + roof_overhang // 2 + 4 - ri, roof_top + 6 + 3 - ri),
                ]
                shadow_alpha = int(collapse_opacity * (0.5 - ri * 0.1))
                pygame.draw.polygon(temple_surface, (15, 10, 20, shadow_alpha), roof_shadow)

            # 메인 지붕
            roof_points = [
                (roof_left, roof_bottom),
                (roof_right, roof_bottom),
                (roof_right - roof_overhang // 2, roof_top + 6),
                (roof_left + roof_overhang // 2, roof_top + 6),
            ]
            roof_color = (*self.colors['roof_red'], collapse_opacity)
            pygame.draw.polygon(temple_surface, roof_color, roof_points)

            # 기와 패턴 (3D 효과 - 반원형 기와)
            tile_rows = 5
            for t in range(tile_rows):
                ty = roof_bottom - (t + 1) * (roof_height // (tile_rows + 1))
                t_ratio = t / tile_rows
                t_left = roof_left + (roof_overhang // 2) * t_ratio + 8
                t_right = roof_right - (roof_overhang // 2) * t_ratio - 8
                row_width = t_right - t_left

                # 기와 열 (반원형 기와 패턴)
                tile_width = 12
                num_tiles = int(row_width // tile_width)
                for ti in range(num_tiles):
                    tx = t_left + ti * tile_width + (t % 2) * (tile_width // 2)
                    if tx < t_right - tile_width // 2:
                        # 기와 그림자
                        tile_shadow = (*self.colors['roof_dark'], int(collapse_opacity * 0.8))
                        pygame.draw.arc(temple_surface, tile_shadow,
                                      (int(tx) + 1, ty - 3, tile_width, 8), 0, math.pi, 2)
                        # 기와 메인
                        tile_main = (*self.colors['roof_red'], collapse_opacity)
                        pygame.draw.arc(temple_surface, tile_main,
                                      (int(tx), ty - 4, tile_width, 8), 0, math.pi, 2)
                        # 기와 하이라이트
                        tile_light = (min(255, self.colors['roof_red'][0] + 20),
                                     min(255, self.colors['roof_red'][1] + 15),
                                     min(255, self.colors['roof_red'][2] + 10), int(collapse_opacity * 0.5))
                        pygame.draw.arc(temple_surface, tile_light,
                                      (int(tx) + 2, ty - 5, tile_width - 4, 5), 0, math.pi, 1)

            # 처마 끝 곡선 장식 (용머리 형태)
            eave_gold = (*self.colors['gold_accent'], collapse_opacity)
            eave_dark = (*self.colors['gold_dim'], collapse_opacity)
            # 좌측 처마 장식
            pygame.draw.arc(temple_surface, eave_dark, (roof_left - 8, roof_bottom - 20, 25, 25),
                          math.pi * 0.4, math.pi * 0.9, 3)
            pygame.draw.arc(temple_surface, eave_gold, (roof_left - 6, roof_bottom - 18, 22, 22),
                          math.pi * 0.4, math.pi * 0.9, 2)
            # 처마 끝 장식구
            pygame.draw.circle(temple_surface, eave_dark, (roof_left - 2, roof_bottom - 8), 5)
            pygame.draw.circle(temple_surface, eave_gold, (roof_left - 3, roof_bottom - 9), 4)
            pygame.draw.circle(temple_surface, (min(255, self.colors['gold_accent'][0] + 50),
                              min(255, self.colors['gold_accent'][1] + 40),
                              min(255, self.colors['gold_accent'][2] + 30), collapse_opacity),
                             (roof_left - 4, roof_bottom - 10), 2)

            # 우측 처마 장식
            pygame.draw.arc(temple_surface, eave_dark, (roof_right - 17, roof_bottom - 20, 25, 25),
                          math.pi * 0.1, math.pi * 0.6, 3)
            pygame.draw.arc(temple_surface, eave_gold, (roof_right - 16, roof_bottom - 18, 22, 22),
                          math.pi * 0.1, math.pi * 0.6, 2)
            pygame.draw.circle(temple_surface, eave_dark, (roof_right + 2, roof_bottom - 8), 5)
            pygame.draw.circle(temple_surface, eave_gold, (roof_right + 1, roof_bottom - 9), 4)
            pygame.draw.circle(temple_surface, (min(255, self.colors['gold_accent'][0] + 50),
                              min(255, self.colors['gold_accent'][1] + 40),
                              min(255, self.colors['gold_accent'][2] + 30), collapse_opacity),
                             (roof_right, roof_bottom - 10), 2)

            # 용마루 (3D 효과)
            ridge_y = roof_top + 4
            ridge_left = roof_left + roof_overhang // 2 + 5
            ridge_right = roof_right - roof_overhang // 2 - 5
            # 용마루 그림자
            pygame.draw.line(temple_surface, (*self.colors['temple_dark'], int(collapse_opacity * 0.7)),
                           (ridge_left + 2, ridge_y + 3), (ridge_right + 2, ridge_y + 3), 5)
            # 용마루 메인
            pygame.draw.line(temple_surface, (*self.colors['gold_dim'], collapse_opacity),
                           (ridge_left, ridge_y), (ridge_right, ridge_y), 4)
            # 용마루 하이라이트
            pygame.draw.line(temple_surface, (min(255, self.colors['gold_dim'][0] + 40),
                            min(255, self.colors['gold_dim'][1] + 35),
                            min(255, self.colors['gold_dim'][2] + 25), int(collapse_opacity * 0.7)),
                           (ridge_left, ridge_y - 1), (ridge_right, ridge_y - 1), 2)

            # 용마루 끝 장식 (치미 형태)
            for end_x, direction in [(ridge_left - 5, -1), (ridge_right + 5, 1)]:
                # 치미 몸체
                pygame.draw.polygon(temple_surface, eave_dark, [
                    (end_x, ridge_y - 2),
                    (end_x + direction * 12, ridge_y - 15),
                    (end_x + direction * 8, ridge_y - 18),
                    (end_x + direction * 3, ridge_y - 8),
                ])
                pygame.draw.polygon(temple_surface, eave_gold, [
                    (end_x - 1, ridge_y - 3),
                    (end_x + direction * 10, ridge_y - 14),
                    (end_x + direction * 7, ridge_y - 16),
                    (end_x + direction * 2, ridge_y - 7),
                ])

            # 테두리
            roof_dark_color = (*self.colors['roof_dark'], collapse_opacity)
            pygame.draw.polygon(temple_surface, roof_dark_color, roof_points, 2)

            # === 탑 꼭대기 장식 (상륜부) - 울트라 고품질 ===
            if level == 0:
                spire_base_y = level_y - level_height - roof_height
                gold_color = (*self.colors['gold_accent'], collapse_opacity)
                gold_light = (min(255, self.colors['gold_accent'][0] + 50),
                             min(255, self.colors['gold_accent'][1] + 40),
                             min(255, self.colors['gold_accent'][2] + 30), collapse_opacity)
                gold_dark = (*self.colors['gold_dim'], collapse_opacity)

                # 상륜부를 별도 Surface에 그린 후 기울기 적용
                spire_height = 90
                spire_width = 60
                spire_surf = pygame.Surface((spire_width, spire_height), pygame.SRCALPHA)
                spire_cx = spire_width // 2  # 상륜부 중심 X
                spire_cy = spire_height - 10  # 상륜부 밑부분에서 회전

                # 상륜부 받침 (노반)
                pygame.draw.ellipse(spire_surf, gold_dark,
                                  (spire_cx - 16, spire_height - 16, 32, 10))
                pygame.draw.ellipse(spire_surf, gold_color,
                                  (spire_cx - 14, spire_height - 18, 28, 10))
                pygame.draw.ellipse(spire_surf, gold_light,
                                  (spire_cx - 10, spire_height - 19, 18, 6), 1)

                # 복발 (원형 장식) - 더 정교하게
                for i in range(4):
                    bowl_y = spire_height - 24 - i * 10
                    bowl_size = 12 - i * 2
                    # 그림자
                    pygame.draw.ellipse(spire_surf, gold_dark,
                                      (spire_cx - bowl_size + 2, bowl_y - bowl_size // 2 + 2,
                                       bowl_size * 2, bowl_size + 2))
                    # 메인
                    pygame.draw.ellipse(spire_surf, gold_color,
                                      (spire_cx - bowl_size, bowl_y - bowl_size // 2,
                                       bowl_size * 2, bowl_size))
                    # 하이라이트
                    pygame.draw.ellipse(spire_surf, gold_light,
                                      (spire_cx - bowl_size + 3, bowl_y - bowl_size // 2 + 1,
                                       bowl_size - 2, bowl_size // 2), 1)
                    # 테두리 장식
                    pygame.draw.ellipse(spire_surf, gold_dark,
                                      (spire_cx - bowl_size, bowl_y - bowl_size // 2,
                                       bowl_size * 2, bowl_size), 1)

                # 앙화 (연꽃 장식)
                lotus_y = spire_height - 62
                for petal in range(8):
                    angle = (petal / 8) * math.pi * 2 - math.pi / 2
                    petal_x = spire_cx + math.cos(angle) * 8
                    petal_y = lotus_y + math.sin(angle) * 4
                    pygame.draw.ellipse(spire_surf, gold_color,
                                      (int(petal_x) - 3, int(petal_y) - 2, 6, 5))

                # 찰주 (중심 기둥)
                spire_top_y = 15
                pygame.draw.line(spire_surf, gold_dark,
                               (spire_cx + 2, spire_height - 65), (spire_cx + 2, spire_top_y + 2), 4)
                pygame.draw.line(spire_surf, gold_color,
                               (spire_cx, spire_height - 65), (spire_cx, spire_top_y), 3)
                pygame.draw.line(spire_surf, gold_light,
                               (spire_cx - 1, spire_height - 65), (spire_cx - 1, spire_top_y), 1)

                # 보주 (꼭대기 구슬) - 보석처럼
                pygame.draw.circle(spire_surf, gold_dark, (spire_cx + 2, spire_top_y - 4), 9)
                pygame.draw.circle(spire_surf, gold_color, (spire_cx, spire_top_y - 6), 8)
                pygame.draw.circle(spire_surf, gold_light, (spire_cx - 2, spire_top_y - 8), 5)
                pygame.draw.circle(spire_surf, (255, 255, 240, int(collapse_opacity * 0.8)),
                                 (spire_cx - 3, spire_top_y - 9), 2)

                # 상륜부 기울기 적용 (spire_angle)
                if spire_angle != 0:
                    # 회전된 상륜부
                    rotated_spire = pygame.transform.rotate(spire_surf, -spire_angle)
                    # 회전 후 위치 조정
                    rot_rect = rotated_spire.get_rect()
                    # 회전 중심을 상륜부 밑부분에 맞춤
                    rot_x = temple_x - rot_rect.width // 2 + int(spire_angle * 0.5)
                    rot_y = spire_base_y - spire_height + 10 + int(abs(spire_angle) * 0.3)
                    temple_surface.blit(rotated_spire, (rot_x, rot_y))
                else:
                    # 기울기 없을 때 정상 위치
                    temple_surface.blit(spire_surf, (temple_x - spire_width // 2, spire_base_y - spire_height + 10))

            # === 창문 (울트라 고품질 - 전통 격자창) ===
            if level < self.pagoda_levels - 1:
                window_y = level_y - level_height // 2
                window_width = 32
                window_height = 22
                window_x = temple_x - window_width // 2

                # 창문 깊이 (다층 그림자)
                for wi in range(3):
                    frame_shadow = (*self.colors['temple_dark'], int(collapse_opacity * (0.6 - wi * 0.15)))
                    pygame.draw.rect(temple_surface, frame_shadow,
                                   (window_x + 3 - wi, window_y - window_height // 2 + 3 - wi,
                                    window_width, window_height))

                # 창문 내부 (깊은 어둠 + 미세한 빛)
                inner_colors = [(10, 8, 15), (15, 12, 22), (12, 10, 18)]
                for ic, inner_c in enumerate(inner_colors):
                    pygame.draw.rect(temple_surface, (*inner_c, collapse_opacity),
                                   (window_x + ic, window_y - window_height // 2 + ic,
                                    window_width - ic * 2, window_height - ic * 2))

                # 창살 (전통 꽃살문 패턴)
                grid_color = (*self.colors['gold_dim'], int(collapse_opacity * 0.9))
                grid_light = (min(255, self.colors['gold_dim'][0] + 30),
                             min(255, self.colors['gold_dim'][1] + 25),
                             min(255, self.colors['gold_dim'][2] + 15), int(collapse_opacity * 0.6))

                # 외곽 프레임
                pygame.draw.rect(temple_surface, grid_color,
                               (window_x, window_y - window_height // 2, window_width, window_height), 2)

                # 가로 창살 (3개)
                for gy in range(3):
                    gy_pos = window_y - window_height // 2 + (gy + 1) * (window_height // 4)
                    pygame.draw.line(temple_surface, grid_color,
                                   (window_x + 2, gy_pos), (window_x + window_width - 2, gy_pos), 1)

                # 세로 창살 (3개)
                for gx in range(3):
                    gx_pos = window_x + (gx + 1) * (window_width // 4)
                    pygame.draw.line(temple_surface, grid_color,
                                   (gx_pos, window_y - window_height // 2 + 2),
                                   (gx_pos, window_y + window_height // 2 - 2), 1)

                # 대각선 장식 (꽃살 느낌)
                for cell_y in range(3):
                    for cell_x in range(3):
                        cx = window_x + (cell_x + 0.5) * (window_width // 4) + window_width // 8
                        cy = window_y - window_height // 2 + (cell_y + 0.5) * (window_height // 4) + window_height // 8
                        cell_size = min(window_width // 8, window_height // 8) - 1
                        # 작은 마름모 장식
                        pygame.draw.line(temple_surface, grid_light,
                                       (int(cx) - cell_size, int(cy)), (int(cx), int(cy) - cell_size), 1)
                        pygame.draw.line(temple_surface, grid_light,
                                       (int(cx), int(cy) - cell_size), (int(cx) + cell_size, int(cy)), 1)
                        pygame.draw.line(temple_surface, grid_light,
                                       (int(cx) + cell_size, int(cy)), (int(cx), int(cy) + cell_size), 1)
                        pygame.draw.line(temple_surface, grid_light,
                                       (int(cx), int(cy) + cell_size), (int(cx) - cell_size, int(cy)), 1)

                # 창문 상단 아치 장식 (더 정교하게)
                arch_dark = (*self.colors['gold_dim'], int(collapse_opacity * 0.8))
                arch_light = (*self.colors['gold_accent'], collapse_opacity)
                pygame.draw.arc(temple_surface, arch_dark,
                              (window_x - 4, window_y - window_height // 2 - 12, window_width + 8, 16),
                              0, math.pi, 3)
                pygame.draw.arc(temple_surface, arch_light,
                              (window_x - 3, window_y - window_height // 2 - 11, window_width + 6, 14),
                              0, math.pi, 2)
                # 아치 꼭대기 장식
                pygame.draw.circle(temple_surface, arch_light,
                                 (temple_x, window_y - window_height // 2 - 10), 3)

        # === 입구 (울트라 고품질) ===
        entrance_y = temple_base_y + collapse_y_offset
        entrance_width = 60
        entrance_height = 55
        entrance_x = temple_x - entrance_width // 2

        # 입구 깊이감 (다층 그라데이션)
        for di in range(5):
            depth_alpha = collapse_opacity - di * 30
            inner_dark = (10 - di * 2, 8 - di * 2, 15 - di * 2, max(0, depth_alpha))
            pygame.draw.rect(temple_surface, inner_dark,
                            (entrance_x + 5 + di * 2, entrance_y - entrance_height + 5 + di,
                             entrance_width - 10 - di * 4, entrance_height - 5 - di * 2))

        # 입구 프레임 (3D 효과)
        frame_shadow = (*self.colors['temple_dark'], int(collapse_opacity * 0.8))
        pygame.draw.rect(temple_surface, frame_shadow,
                        (entrance_x + 2, entrance_y - entrance_height + 2, entrance_width, entrance_height))
        entrance_dark_color = (*self.colors['temple_dark'], collapse_opacity)
        pygame.draw.rect(temple_surface, entrance_dark_color,
                        (entrance_x, entrance_y - entrance_height, entrance_width, entrance_height))

        # 문 (이중문 표현 - 애니메이션 적용)
        door_width = (entrance_width - 10) // 2
        door_height = entrance_height - 15

        # 문 열림 오프셋 계산 (왼쪽 문은 왼쪽으로, 오른쪽 문은 오른쪽으로 열림)
        max_door_open_offset = door_width - 4  # 최대 열림 거리
        door_open_offset = int(self.door_open_amount * max_door_open_offset)

        # 왼쪽 문, 오른쪽 문 베이스 위치
        left_door_base_x = entrance_x + 3
        right_door_base_x = entrance_x + entrance_width // 2 + 2

        for door_i, door_base_x in enumerate([left_door_base_x, right_door_base_x]):
            # 문 열림에 따른 X 오프셋 (왼쪽 문은 -, 오른쪽 문은 +)
            if door_i == 0:  # 왼쪽 문
                door_x = door_base_x - door_open_offset
            else:  # 오른쪽 문
                door_x = door_base_x + door_open_offset

            # 문이 입구 프레임 밖으로 나가지 않도록 클리핑
            # (문이 열릴 때 벽 뒤로 숨어들어가는 효과)
            visible_width = door_width - 2
            if door_i == 0:  # 왼쪽 문
                clip_left = max(entrance_x, door_x)
                clip_width = min(visible_width, door_base_x + visible_width - clip_left)
                if clip_width <= 0:
                    continue  # 문이 완전히 숨겨짐
                draw_x = clip_left
                draw_width = clip_width
            else:  # 오른쪽 문
                clip_right = min(entrance_x + entrance_width, door_x + visible_width)
                clip_width = min(visible_width, clip_right - door_x)
                if clip_width <= 0:
                    continue  # 문이 완전히 숨겨짐
                draw_x = door_x
                draw_width = clip_width

            # 문 패널
            door_color = (*self.colors['roof_dark'], collapse_opacity)
            pygame.draw.rect(temple_surface, door_color,
                           (draw_x, entrance_y - door_height - 5, draw_width, door_height))
            # 문 테두리
            pygame.draw.rect(temple_surface, (*self.colors['gold_dim'], int(collapse_opacity * 0.8)),
                           (draw_x, entrance_y - door_height - 5, draw_width, door_height), 1)

            # 문 장식 패널 (문이 충분히 보일 때만)
            panel_margin = 3
            if draw_width > panel_margin * 2 + 4:
                pygame.draw.rect(temple_surface, (*self.colors['temple_dark'], int(collapse_opacity * 0.6)),
                               (draw_x + panel_margin, entrance_y - door_height - 5 + panel_margin,
                                draw_width - panel_margin * 2, door_height - panel_margin * 2), 1)

            # 문고리 (문이 충분히 보일 때만)
            ring_offset_from_edge = 8 if door_i == 0 else draw_width - 8
            if draw_width > 15:
                ring_x = draw_x + ring_offset_from_edge
                ring_y = entrance_y - door_height // 2 - 5
                pygame.draw.circle(temple_surface, (*self.colors['gold_dim'], collapse_opacity), (ring_x, ring_y), 4)
                pygame.draw.circle(temple_surface, (*self.colors['gold_accent'], int(collapse_opacity * 0.7)),
                                 (ring_x - 1, ring_y - 1), 2)

        # 입구 기둥 (원형 기둥 - 3D 효과)
        for pillar_x, highlight_offset in [(entrance_x - 10, -2), (entrance_x + entrance_width + 2, 2)]:
            pillar_w = 12
            # 기둥 그림자
            pygame.draw.ellipse(temple_surface, (*self.colors['temple_dark'], int(collapse_opacity * 0.5)),
                              (pillar_x - 1, entrance_y - 2, pillar_w + 2, 6))
            # 기둥 메인 (그라데이션 효과)
            for py in range(entrance_height + 15):
                shade = 1 - abs((pillar_w // 2) - 3) / (pillar_w // 2) * 0.3
                r = int(self.colors['temple_main'][0] * shade)
                g = int(self.colors['temple_main'][1] * shade)
                b = int(self.colors['temple_main'][2] * shade)
                pygame.draw.line(temple_surface, (r, g, b, collapse_opacity),
                               (pillar_x, entrance_y - entrance_height - 15 + py),
                               (pillar_x + pillar_w, entrance_y - entrance_height - 15 + py), 1)
            # 기둥 하이라이트
            pygame.draw.line(temple_surface, (*self.colors['temple_highlight'], int(collapse_opacity * 0.6)),
                           (pillar_x + highlight_offset + pillar_w // 2, entrance_y - entrance_height - 12),
                           (pillar_x + highlight_offset + pillar_w // 2, entrance_y - 3), 2)
            # 기둥 주두 (상단 장식)
            pygame.draw.rect(temple_surface, (*self.colors['gold_dim'], collapse_opacity),
                           (pillar_x - 2, entrance_y - entrance_height - 18, pillar_w + 4, 6))
            pygame.draw.rect(temple_surface, (*self.colors['gold_accent'], int(collapse_opacity * 0.7)),
                           (pillar_x - 1, entrance_y - entrance_height - 17, pillar_w + 2, 4), 1)
            # 기둥 기단 (하단 장식)
            pygame.draw.rect(temple_surface, (*self.colors['stone_gray'], collapse_opacity),
                           (pillar_x - 2, entrance_y - 3, pillar_w + 4, 5))

        # 입구 상단 현판 (더 정교하게)
        plaque_x = entrance_x + 3
        plaque_y = entrance_y - entrance_height - 8
        plaque_w = entrance_width - 6
        plaque_h = 16
        # 현판 그림자
        pygame.draw.rect(temple_surface, (*self.colors['temple_dark'], int(collapse_opacity * 0.6)),
                        (plaque_x + 2, plaque_y + 2, plaque_w, plaque_h))
        # 현판 메인
        pygame.draw.rect(temple_surface, (*self.colors['roof_red'], collapse_opacity),
                        (plaque_x, plaque_y, plaque_w, plaque_h))
        # 현판 테두리 (다층)
        pygame.draw.rect(temple_surface, (*self.colors['gold_dim'], collapse_opacity),
                        (plaque_x, plaque_y, plaque_w, plaque_h), 2)
        pygame.draw.rect(temple_surface, (*self.colors['gold_accent'], int(collapse_opacity * 0.7)),
                        (plaque_x + 2, plaque_y + 2, plaque_w - 4, plaque_h - 4), 1)
        # 현판 글자 표현 (추상적)
        for tx in range(3):
            text_x = plaque_x + 10 + tx * 15
            pygame.draw.line(temple_surface, (*self.colors['gold_accent'], int(collapse_opacity * 0.8)),
                           (text_x, plaque_y + 4), (text_x, plaque_y + plaque_h - 4), 2)
            pygame.draw.line(temple_surface, (*self.colors['gold_accent'], int(collapse_opacity * 0.6)),
                           (text_x - 3, plaque_y + plaque_h // 2), (text_x + 5, plaque_y + plaque_h // 2), 1)

        # === 돌계단 (울트라 고품질) ===
        for step in range(5):
            step_y = entrance_y + step * 12
            step_width = 170 + step * 28
            step_height = 12
            step_x = temple_x - step_width // 2

            # 계단 다층 그림자
            for si in range(3):
                shadow_alpha = int(collapse_opacity * (0.4 - si * 0.1))
                pygame.draw.rect(temple_surface, (20, 18, 25, shadow_alpha),
                               (step_x + 3 - si, step_y + 3 - si, step_width, step_height))

            # 계단 메인 (그라데이션)
            for sy in range(step_height):
                grad = 1 - sy / step_height * 0.2
                r = int(self.colors['stone_gray'][0] * grad)
                g = int(self.colors['stone_gray'][1] * grad)
                b = int(self.colors['stone_gray'][2] * grad)
                pygame.draw.line(temple_surface, (r, g, b, collapse_opacity),
                               (step_x, step_y + sy), (step_x + step_width, step_y + sy), 1)

            # 계단 하이라이트 (상단 엣지)
            stone_light = (min(255, self.colors['stone_gray'][0] + 25),
                          min(255, self.colors['stone_gray'][1] + 20),
                          min(255, self.colors['stone_gray'][2] + 15), int(collapse_opacity * 0.8))
            pygame.draw.line(temple_surface, stone_light,
                           (step_x + 1, step_y), (step_x + step_width - 1, step_y), 2)

            # 돌 블록 패턴
            stone_dark_color = (*self.colors['stone_dark'], int(collapse_opacity * 0.6))
            block_width = 35
            num_blocks = step_width // block_width
            for bi in range(num_blocks + 1):
                bx = step_x + bi * block_width + (step % 2) * (block_width // 2)
                if bx < step_x + step_width - 5:
                    # 블록 세로선
                    pygame.draw.line(temple_surface, stone_dark_color,
                                   (bx, step_y + 1), (bx, step_y + step_height - 1), 1)
                    # 블록 질감 (미세한 점)
                    if bi % 2 == 0:
                        pygame.draw.circle(temple_surface, stone_dark_color,
                                         (bx + block_width // 2, step_y + step_height // 2), 1)

            # 계단 측면 그림자
            pygame.draw.line(temple_surface, stone_dark_color,
                           (step_x, step_y + step_height - 1),
                           (step_x + step_width, step_y + step_height - 1), 1)

        # === 석등/화로 받침대 ===
        brazier_base_y = entrance_y + 30
        # 받침대 (3D)
        pygame.draw.rect(temple_surface, (*self.colors['stone_dark'], int(collapse_opacity * 0.7)),
                        (temple_x - 22, brazier_base_y + 2, 44, 10))
        pygame.draw.rect(temple_surface, (*self.colors['stone_gray'], collapse_opacity),
                        (temple_x - 20, brazier_base_y, 40, 8))
        pygame.draw.line(temple_surface, (min(255, self.colors['stone_gray'][0] + 20),
                        min(255, self.colors['stone_gray'][1] + 15),
                        min(255, self.colors['stone_gray'][2] + 10), int(collapse_opacity * 0.7)),
                       (temple_x - 18, brazier_base_y + 1), (temple_x + 18, brazier_base_y + 1), 1)

        # Blit the temple surface to the main surface
        if collapse_rotation > 0:
            rotated_temple = pygame.transform.rotate(temple_surface, collapse_rotation)
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
        """Draw a hanging lantern (optimized)"""
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

        # OPTIMIZATION: Cache glow surfaces by size
        if not hasattr(self, '_lantern_glow_cache'):
            self._lantern_glow_cache = {}

        # Glow effect - quantize alpha to reduce cache variations
        glow_alpha = abs(math.sin(lantern['glow_pulse'])) * 0.3 + 0.7
        glow_radius = int(lantern['glow_radius'] * glow_alpha)
        cache_key = (glow_radius, int(glow_alpha * 10))  # Quantized alpha

        if cache_key not in self._lantern_glow_cache:
            glow_surface = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
            # OPTIMIZATION: Draw fewer circles (step by 4 instead of 2)
            for i in range(glow_radius, 0, -4):
                alpha = int(60 * (i / glow_radius) * glow_alpha)
                color = (*self.colors['lantern_glow'][:3], alpha)
                pygame.draw.circle(glow_surface, color, (glow_radius, glow_radius), i)
            self._lantern_glow_cache[cache_key] = glow_surface
            # Limit cache size
            if len(self._lantern_glow_cache) > 30:
                # Remove oldest entries
                keys = list(self._lantern_glow_cache.keys())
                for k in keys[:10]:
                    del self._lantern_glow_cache[k]

        surface.blit(self._lantern_glow_cache[cache_key], (x - glow_radius, y - glow_radius))

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
        """Draw incense smoke particles (optimized)"""
        # OPTIMIZATION: Limit max particles and spawn less frequently
        MAX_INCENSE_PARTICLES = 60  # Reduced from unlimited

        # Spawn new incense particles (every 6 frames instead of 3)
        if self.frame_count % 6 == 0 and len(self.incense_particles) < MAX_INCENSE_PARTICLES:
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

        # OPTIMIZATION: Cache smoke surfaces by size
        if not hasattr(self, '_smoke_surf_cache'):
            self._smoke_surf_cache = {}

        # Update and draw particles
        new_particles = []
        for particle in self.incense_particles:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1

            # Wave motion
            particle['vx'] += math.sin(self.frame_count * 0.05) * 0.02

            if particle['life'] <= 0:
                continue

            new_particles.append(particle)

            # Draw smoke using cached surface
            alpha = int((particle['life'] / 120) * 40)
            size = particle['size']
            cache_key = (size, alpha // 10)  # Quantized alpha

            if cache_key not in self._smoke_surf_cache:
                smoke_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                color = (*self.colors['incense_smoke'][:3], alpha)
                pygame.draw.circle(smoke_surface, color, (size, size), size)
                self._smoke_surf_cache[cache_key] = smoke_surface
                # Limit cache size
                if len(self._smoke_surf_cache) > 20:
                    keys = list(self._smoke_surf_cache.keys())
                    del self._smoke_surf_cache[keys[0]]

            surface.blit(self._smoke_surf_cache[cache_key],
                        (particle['x'] - size, particle['y'] - size))

        self.incense_particles = new_particles
        
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
        offset = self.pillar_offset
        game_right = offset + self.game_width

        # Left side bamboo grove
        for i in range(5):
            x = offset + 20 + i * 15
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
            x = game_right - 20 - i * 15
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
        """Create explosion fragments when crow is hit (optimized)"""
        # OPTIMIZATION: Reduce fragment count from 8-12 to 6-8
        num_fragments = random.randint(6, 8)

        for i in range(num_fragments):
            angle = (i / num_fragments) * 2 * math.pi + random.uniform(-0.3, 0.3)
            speed = random.uniform(2, 6)
            frag_type = random.choice(['feather', 'fragment'])

            # Pre-generate shape offsets for rendering (avoid per-frame random calls)
            if frag_type == 'fragment':
                num_points = random.randint(5, 7)
                shape_offsets = [random.uniform(0.6, 1.0) for _ in range(num_points)]
            else:
                num_points = 6
                shape_offsets = None  # Feathers use fixed pattern

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
                'type': frag_type,
                'opacity': 255,
                'num_points': num_points,
                'shape_offsets': shape_offsets,  # Pre-cached for rendering
            }
            self.crow_fragments.append(fragment)

        # OPTIMIZATION: Reduce particle count from 15 to 8
        for _ in range(8):
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
                'opacity': 200,
                'rotation': random.uniform(0, 360),  # Pre-cache rotation
                'shape_offsets': [random.uniform(0.7, 1.0) for _ in range(4)],  # Pre-cache shape
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

    def _update_door_animation(self):
        """Update temple door open/close animation (사원 문 열림/닫힘 애니메이션)"""
        # 부드러운 보간으로 문 열림 상태 업데이트
        if self.door_open_amount < self.door_target_open:
            self.door_open_amount = min(self.door_target_open,
                                       self.door_open_amount + self.door_animation_speed)
        elif self.door_open_amount > self.door_target_open:
            self.door_open_amount = max(self.door_target_open,
                                       self.door_open_amount - self.door_animation_speed)

    def _spawn_monk(self, is_smoke_grenade_monk=False):
        """Spawn a monk that walks out from temple entrance"""
        # Only allow 1 normal monk at a time (연막탄 몽크는 예외)
        if not is_smoke_grenade_monk and len([m for m in self.monks if not m.get('is_smoke_grenade_monk', False)]) >= 1:
            return
        
        # Spawn from temple entrance
        temple_x = self.game_center_x
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
            # 사원 파괴 시 문도 닫힘
            self.door_target_open = 0.0
            self._update_door_animation()
            return

        # === 문 열림 상태 업데이트 ===
        # 입구 근처에 있는 몽크 확인 (나가거나 들어오는 중)
        temple_x = self.game_center_x
        entrance_y = self.door_entrance_y

        monk_near_entrance = False
        for monk in self.monks:
            # 몽크가 입구 근처에 있는지 체크
            dx = abs(monk['x'] - temple_x)
            dy = abs(monk['y'] - entrance_y)

            # 스폰 직후 (opacity가 낮을 때 = 나오는 중) 또는 복귀 중 (returning)
            is_entering_or_exiting = monk['opacity'] < 255 or monk.get('returning_to_temple', False)

            if dx < self.door_trigger_distance and dy < 20 and is_entering_or_exiting:
                monk_near_entrance = True
                break

        # 문 열림 목표 설정
        if monk_near_entrance:
            self.door_target_open = 1.0  # 열림
        else:
            self.door_target_open = 0.0  # 닫힘

        # 문 애니메이션 업데이트
        self._update_door_animation()

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
        # Debug logging
        if len(self.monk_death_particles) > 0 or len(self.monk_body_parts) > 0:
            print(f"Updating monk death effects: {len(self.monk_death_particles)} particles, {len(self.monk_body_parts)} body parts")
        
        # Update death particles
        for particle in self.monk_death_particles[:]:
            # Only update position for particles with velocity
            if 'vx' in particle and 'vy' in particle:
                particle['x'] += particle['vx']
                particle['y'] += particle['vy']
                particle['vy'] += particle.get('gravity', 0.2)
            
            # Handle both life and lifetime keys for compatibility
            if 'life' in particle:
                particle['life'] -= 1
                life_remaining = particle['life']
            elif 'lifetime' in particle:
                particle['lifetime'] -= 1
                life_remaining = particle['lifetime']
            else:
                # Default lifetime if neither exists
                particle['life'] = 60
                life_remaining = 60
            
            # Fade out particles
            if 'opacity' in particle:
                particle['opacity'] = max(0, int(particle['opacity'] * 0.95))
            
            if life_remaining <= 0:
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
        # Draw particles - simplified for visibility
        for particle in self.monk_death_particles:
            try:
                x, y = int(particle['x']), int(particle['y'])
                
                if particle.get('type') == 'shockwave':
                    # Draw expanding shockwave as polygonal blast
                    if particle['radius'] < particle['max_radius']:
                        # Create jagged shockwave effect
                        points = []
                        num_points = 12
                        for i in range(num_points):
                            angle = (i * 2 * math.pi / num_points)
                            radius = particle['radius'] * random.uniform(0.8, 1.2)  # Jagged edge
                            px = x + radius * math.cos(angle)
                            py = y + radius * math.sin(angle)
                            points.append((px, py))
                        if len(points) >= 3:
                            pygame.draw.polygon(surface, particle['color'], points, 3)
                        particle['radius'] += 5  # Expand faster for visibility
                elif particle.get('type') in ['head', 'torso', 'arm', 'leg']:
                    # Draw body fragments as irregular shapes based on type
                    size = max(particle.get('size', 5), 8)
                    frag_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    
                    if particle['type'] == 'head':
                        # Draw skull-like fragment
                        points = []
                        for i in range(6):
                            angle = (i * 2 * math.pi / 6) + math.radians(particle.get('rotation', 0))
                            radius = size * (0.9 if i % 2 == 0 else 0.7)  # Irregular head shape
                            px = size + radius * math.cos(angle)
                            py = size + radius * math.sin(angle)
                            points.append((px, py))
                    elif particle['type'] == 'torso':
                        # Draw torso fragment as oval
                        oval_width = size * 1.4
                        oval_height = size * 1.8
                        points = []
                        for i in range(8):
                            angle = (i * 2 * math.pi / 8) + math.radians(particle.get('rotation', 0))
                            rx = oval_width * 0.7 * math.cos(angle)
                            ry = oval_height * 0.7 * math.sin(angle)
                            px = size + rx
                            py = size + ry
                            points.append((px, py))
                    elif particle['type'] in ['arm', 'leg']:
                        # Draw limb fragments as elongated shapes
                        limb_width = size * 0.6
                        limb_length = size * 2.0
                        points = [
                            (size, size - limb_length/2),  # Top
                            (size + limb_width/2, size - limb_length/4),
                            (size + limb_width/2, size + limb_length/4),
                            (size, size + limb_length/2),  # Bottom
                            (size - limb_width/2, size + limb_length/4),
                            (size - limb_width/2, size - limb_length/4)
                        ]
                        # Apply rotation
                        rotated_points = []
                        angle = math.radians(particle.get('rotation', 0))
                        for px, py in points:
                            rx = size + (px - size) * math.cos(angle) - (py - size) * math.sin(angle)
                            ry = size + (px - size) * math.sin(angle) + (py - size) * math.cos(angle)
                            rotated_points.append((rx, ry))
                        points = rotated_points
                    
                    if len(points) >= 3:
                        color = (*particle['color'], particle.get('opacity', 255))
                        pygame.draw.polygon(frag_surface, color, points)
                        # Add darker outline for definition
                        darker_color = tuple(max(0, c - 50) for c in particle['color']) + (particle.get('opacity', 255),)
                        pygame.draw.polygon(frag_surface, darker_color, points, 2)
                    
                    surface.blit(frag_surface, (x - size, y - size))
                else:
                    # Blood droplets as small irregular shapes
                    size = max(particle.get('size', 3), 4)
                    droplet_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    
                    # Create droplet shape (teardrop-like)
                    points = []
                    for i in range(6):
                        angle = (i * 2 * math.pi / 6)
                        if i == 0:  # Top point (teardrop tip)
                            radius = size * 1.2
                        else:
                            radius = size * 0.8
                        px = size + radius * math.cos(angle)
                        py = size + radius * math.sin(angle)
                        points.append((px, py))
                    
                    if len(points) >= 3:
                        color = (*particle['color'], particle.get('opacity', 255))
                        pygame.draw.polygon(droplet_surface, color, points)
                    
                    surface.blit(droplet_surface, (x - size, y - size))
                    
            except Exception as e:
                print(f"Error drawing particle at ({particle.get('x', 0)}, {particle.get('y', 0)}): {e}")
        
        # Draw body parts with realistic shapes
        for part in self.monk_body_parts:
            try:
                x, y = int(part['x']), int(part['y'])
                size = max(part.get('size', 8), 10)  # Minimum size 10
                
                # Create surface for body part
                part_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                center = size
                
                # Draw realistic body part shapes
                if part['type'] == 'head':
                    # Draw head as irregular oval
                    points = []
                    for i in range(8):
                        angle = (i * 2 * math.pi / 8) + math.radians(part.get('rotation', 0))
                        # Head is slightly wider than tall
                        rx = size * 0.8 * math.cos(angle)
                        ry = size * 0.9 * math.sin(angle)
                        px = center + rx
                        py = center + ry
                        points.append((px, py))
                    
                    if len(points) >= 3:
                        pygame.draw.polygon(part_surface, part['color'], points)
                        # Add face features with darker color
                        darker_color = tuple(max(0, c - 30) for c in part['color'])
                        pygame.draw.polygon(part_surface, darker_color, points, 2)
                        
                        # Add simple facial features (eyes, mouth)
                        eye_color = (20, 20, 20)
                        eye1_x, eye1_y = int(center - size * 0.3), int(center - size * 0.2)
                        eye2_x, eye2_y = int(center + size * 0.3), int(center - size * 0.2)
                        mouth_x, mouth_y = int(center), int(center + size * 0.3)
                        
                        # Draw simple pixel eyes and mouth
                        part_surface.set_at((eye1_x, eye1_y), eye_color)
                        part_surface.set_at((eye2_x, eye2_y), eye_color)
                        part_surface.set_at((mouth_x, mouth_y), eye_color)
                
                elif part['type'] == 'torso':
                    # Draw torso as rectangular body shape
                    torso_width = size * 1.2
                    torso_height = size * 1.6
                    
                    points = []
                    for dx, dy in [(-torso_width/2, -torso_height/2),
                                  (torso_width/2, -torso_height/2),
                                  (torso_width/2, torso_height/2),
                                  (-torso_width/2, torso_height/2)]:
                        angle = math.radians(part.get('rotation', 0))
                        px = center + dx * math.cos(angle) - dy * math.sin(angle)
                        py = center + dx * math.sin(angle) + dy * math.cos(angle)
                        points.append((px, py))
                    
                    pygame.draw.polygon(part_surface, part['color'], points)
                    # Add robe details
                    darker_color = tuple(max(0, c - 40) for c in part['color'])
                    pygame.draw.polygon(part_surface, darker_color, points, 2)
                
                elif part['type'] == 'arm':
                    # Draw arm as elongated shape
                    arm_width = size * 0.5
                    arm_length = size * 1.8
                    
                    points = [
                        (center - arm_width/2, center - arm_length/2),  # Shoulder
                        (center + arm_width/2, center - arm_length/2),
                        (center + arm_width/3, center),  # Elbow (narrower)
                        (center + arm_width/2, center + arm_length/2),  # Hand
                        (center - arm_width/2, center + arm_length/2),
                        (center - arm_width/3, center),  # Elbow
                    ]
                    
                    # Apply rotation
                    rotated_points = []
                    angle = math.radians(part.get('rotation', 0))
                    for px, py in points:
                        rx = center + (px - center) * math.cos(angle) - (py - center) * math.sin(angle)
                        ry = center + (px - center) * math.sin(angle) + (py - center) * math.cos(angle)
                        rotated_points.append((rx, ry))
                    
                    pygame.draw.polygon(part_surface, part['color'], rotated_points)
                    darker_color = tuple(max(0, c - 30) for c in part['color'])
                    pygame.draw.polygon(part_surface, darker_color, rotated_points, 2)
                
                elif part['type'] == 'leg':
                    # Draw leg as elongated shape with foot
                    leg_width = size * 0.6
                    leg_length = size * 2.0
                    
                    points = [
                        (center - leg_width/2, center - leg_length/2),  # Hip
                        (center + leg_width/2, center - leg_length/2),
                        (center + leg_width/2, center + leg_length/3),  # Knee
                        (center + leg_width/2, center + leg_length/2),  # Ankle
                        (center + leg_width, center + leg_length/2),    # Foot tip
                        (center - leg_width/2, center + leg_length/2),
                        (center - leg_width/2, center + leg_length/3),  # Knee
                    ]
                    
                    # Apply rotation
                    rotated_points = []
                    angle = math.radians(part.get('rotation', 0))
                    for px, py in points:
                        rx = center + (px - center) * math.cos(angle) - (py - center) * math.sin(angle)
                        ry = center + (px - center) * math.sin(angle) + (py - center) * math.cos(angle)
                        rotated_points.append((rx, ry))
                    
                    pygame.draw.polygon(part_surface, part['color'], rotated_points)
                    darker_color = tuple(max(0, c - 30) for c in part['color'])
                    pygame.draw.polygon(part_surface, darker_color, rotated_points, 2)
                
                # No special glow for hero parts - removed as requested
                
                # Blit the body part
                surface.blit(part_surface, (x - center, y - center))
                    
            except Exception as e:
                print(f"Error drawing body part: {e}")
    
    def _draw_monk_hit_effects(self, surface: pygame.Surface):
        """Draw monk hit effects (optimized)"""
        for effect in self.monk_hit_effects:
            if effect['type'] == 'shockwave':
                if effect['alpha'] > 0:
                    # OPTIMIZATION: Draw directly to surface instead of creating temp surface
                    color = (*effect['color'][:3], int(effect['alpha']))
                    pygame.draw.circle(surface, color,
                                     (int(effect['x']), int(effect['y'])),
                                     int(effect['radius']), 3)

            elif effect['type'] == 'spark':
                # Draw spark particle directly
                alpha = int(255 * (effect['life'] / 20))
                if alpha > 0:
                    color = (*effect['color'][:3], alpha)
                    pygame.draw.circle(surface, color,
                                     (int(effect['x']), int(effect['y'])), 2)
    
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
        self._update_destruction_wave()  # Update destruction wave
        self._update_moon_fragments()  # Update moon crater fragments
    
    def draw(self, surface: pygame.Surface):
        """Draw the complete Shaolin Temple background"""
        # Apply screen shake if active
        shake_x, shake_y = 0, 0
        if self.screen_shake_intensity > 0:
            shake_x = random.randint(-self.screen_shake_intensity, self.screen_shake_intensity)
            shake_y = random.randint(-self.screen_shake_intensity, self.screen_shake_intensity)
        
        # Create temporary surface for shaking effect
        temp_surface = getattr(self, "_temp_surface", None)
        if temp_surface is None or temp_surface.get_size() != (self.width, self.height):
            temp_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            self._temp_surface = temp_surface
        temp_surface.fill((0, 0, 0, 0))
        
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
        
        # Draw destruction wave
        self._draw_destruction_wave(temp_surface)
        
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

        # Draw dust clouds during building collapse
        self._draw_dust_clouds(temp_surface)

        # Draw ground fires from broken lanterns
        self._draw_ground_fires(temp_surface)
        
        # Apply shaking and draw to main surface
        surface.blit(temp_surface, (shake_x, shake_y))
        
        # Draw red light overlay (after shaking)
        if self.red_light_alpha > 0:
            red_overlay = getattr(self, "_red_overlay_surface", None)
            if red_overlay is None or red_overlay.get_size() != (self.width, self.height):
                red_overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
                self._red_overlay_surface = red_overlay
            red_overlay.fill((255, 50, 50, self.red_light_alpha))
            surface.blit(red_overlay, (0, 0))

        # Note: update() should be called separately from the main game loop, not here
        # 테두리는 pillar_background.py에서 그려짐
    
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
        """Draw crow explosion fragments (optimized)"""
        for fragment in self.crow_fragments:
            size = fragment['size']
            center = size
            color = (*fragment['color'], fragment['opacity'])

            if fragment['type'] == 'feather':
                # Draw feather-like shape with fixed pattern
                points = []
                for i in range(6):
                    angle = (i / 6) * 2 * math.pi + math.radians(fragment['rotation'])
                    r = size if i % 2 == 0 else size * 0.5
                    x = center + r * math.cos(angle)
                    y = center + r * math.sin(angle)
                    points.append((x, y))

                # Draw directly to surface (avoid creating temp surface for small fragments)
                offset_x = int(fragment['x'] - size)
                offset_y = int(fragment['y'] - size)
                offset_points = [(x + offset_x, y + offset_y) for x, y in points]
                if len(offset_points) >= 3:
                    pygame.draw.polygon(surface, color, offset_points)
            else:
                # Draw fragment with pre-cached shape offsets
                num_points = fragment.get('num_points', 6)
                shape_offsets = fragment.get('shape_offsets', [0.8] * num_points)

                points = []
                for i in range(num_points):
                    angle = (i * 2 * math.pi / num_points) + math.radians(fragment['rotation'])
                    radius = size * shape_offsets[i]
                    x = center + radius * math.cos(angle)
                    y = center + radius * math.sin(angle)
                    points.append((x, y))

                # Draw directly to surface
                offset_x = int(fragment['x'] - size)
                offset_y = int(fragment['y'] - size)
                offset_points = [(x + offset_x, y + offset_y) for x, y in points]
                if len(offset_points) >= 3:
                    pygame.draw.polygon(surface, color, offset_points)
    
    def _draw_crow_particles(self, surface: pygame.Surface):
        """Draw crow explosion particles as small debris (optimized)"""
        for particle in self.crow_particles:
            color = (*particle['color'], particle['opacity'])
            size = particle['size']
            center = size

            # Use pre-cached shape offsets
            shape_offsets = particle.get('shape_offsets', [0.85] * 4)
            rotation = particle.get('rotation', 0)

            # Create small irregular debris shape
            points = []
            num_points = 4  # Small triangular/diamond debris
            for i in range(num_points):
                angle = (i * 2 * math.pi / num_points) + math.radians(rotation)
                radius = size * shape_offsets[i]
                x = center + radius * math.cos(angle)
                y = center + radius * math.sin(angle)
                points.append((x, y))

            # Draw directly to surface (optimized - no temp surface needed)
            if len(points) >= 3:
                offset_x = int(particle['x'] - size)
                offset_y = int(particle['y'] - size)
                offset_points = [(x + offset_x, y + offset_y) for x, y in points]
                pygame.draw.polygon(surface, color, offset_points)
    
    def _draw_stage_title(self, surface: pygame.Surface):
        """Draw stage title"""
        try:
            font = pygame.font.Font(PIXEL_FONT, 24)
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
            font_kr = pygame.font.Font(PIXEL_FONT, 20)
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
        max_gauge = 500  # Maximum gauge value for Ponk's magnetic field (250 → 500)
        
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
        
        # Draw gauge value text (like player gauge and Stage 3 boss)
        # Create fonts if not already exists
        if not hasattr(self, 'gauge_value_font'):
            self.gauge_value_font = pygame.font.Font(None, 20)
            self.gauge_value_font_small = pygame.font.Font(None, 16)
        
        # Draw current value / max value
        gauge_text = f"{int(self.ponk_display_gauge)}/{max_gauge}"
        text_surface = self.gauge_value_font.render(gauge_text, True, (255, 255, 255))
        text_rect = text_surface.get_rect(centerx=gauge_x + gauge_width // 2, 
                                          centery=gauge_y + gauge_height + 20)
        
        # Draw text shadow for better visibility
        shadow_surface = self.gauge_value_font.render(gauge_text, True, (0, 0, 0))
        shadow_rect = text_rect.copy()
        shadow_rect.x += 1
        shadow_rect.y += 1
        surface.blit(shadow_surface, shadow_rect)
        surface.blit(text_surface, text_rect)
        
        # Draw state text if ready or active
        if is_active:
            state_text = "굴절자기장!"
            state_color = (255, 100, 100)
        elif is_ready:
            state_text = "준비 완료"
            state_color = (255, 220, 100)
        else:
            state_text = None
            
        if state_text:
            state_surface = self.gauge_value_font_small.render(state_text, True, state_color)
            state_rect = state_surface.get_rect(centerx=gauge_x + gauge_width // 2,
                                                centery=gauge_y - 20)
            # Shadow for state text
            shadow_surface = self.gauge_value_font_small.render(state_text, True, (0, 0, 0))
            shadow_rect = state_rect.copy()
            shadow_rect.x += 1
            shadow_rect.y += 1
            surface.blit(shadow_surface, shadow_rect)
            surface.blit(state_surface, state_rect)
    
    def start_destruction_animation(self):
        """Start the temple destruction animation sequence"""
        if not self.destruction_animation_active and not self.temple_destroyed:
            self.destruction_animation_active = True
            self.destruction_phase = 1
            self.destruction_timer = 0
            # Stop any ongoing moon fragments during the cinematic
            self.moon_fragment_active = False
            self.moon_fragment_timer = 0
            self.moon_fragments.clear()
            print("Temple destruction animation started!")
    
    def is_destruction_animation_active(self):
        """Check if destruction animation is currently playing"""
        return self.destruction_animation_active
    
    def _update_destruction_animation(self):
        """Update the temple destruction animation"""
        if not self.destruction_animation_active:
            return
        
        self.destruction_timer += 1
        
        # Debug: Track phase changes
        if self.destruction_timer % 60 == 0:  # Every second
            print(f"🔥 Destruction Phase {self.destruction_phase}, Timer: {self.destruction_timer}")
        
        if self.destruction_phase == 1:  # Moon turning red (3 seconds)
            # Gradually increase red intensity with more dramatic curve
            progress = self.destruction_timer / 180.0  # 3 seconds
            # Use exponential curve for more intense transition
            self.moon_red_intensity = min(1.0, progress ** 0.5)  # Faster initial change
            
            if self.destruction_timer >= 180:  # 3 seconds at 60 FPS
                self.moon_red_intensity = 1.0  # Ensure it's fully red
                self.destruction_phase = 2
                self.destruction_timer = 0
                print("🔥 Entering Phase 2: Red light emission")
                
        elif self.destruction_phase == 2:  # Red light emission (1.5 seconds)
            # Flash red light across the map
            if self.destruction_timer < 45:
                self.red_light_alpha = min(150, self.destruction_timer * 3.3)
            else:
                self.red_light_alpha = max(0, 150 - (self.destruction_timer - 45) * 3.3)
            
            if self.destruction_timer >= 90:  # 1.5 seconds
                print("🔥 Entering Phase 3: Destruction wave charging!")
                self.destruction_phase = 3
                self.destruction_timer = 0
                self.destruction_wave_charging = True
                
        elif self.destruction_phase == 3:  # Destruction wave (2 seconds)
            # Moon charges up and fires destruction wave
            if self.destruction_timer <= 60:  # 1 second charging
                self.moon_pulse_active = True
                self.moon_pulse_scale = 1.0 + (self.destruction_timer / 60.0) * 0.5  # Grow to 1.5x
            elif self.destruction_timer == 61:  # Fire the wave
                print("🌙 FIRING DESTRUCTION WAVE!")
                self._play_stage4_moon_shoot_sound()
                self._fire_destruction_wave()
                self.destruction_wave_charging = False
                self.moon_pulse_active = False
                self.moon_pulse_scale = 1.0
            
            if self.destruction_timer >= 120:  # 2 seconds total
                print("🔥 Entering Phase 4: Temple collapsing - MONKS SHOULD EXPLODE!")
                self.destruction_phase = 4
                self.destruction_timer = 0
                self._create_collapse_debris()
                self._start_lanterns_falling()  # Start lanterns falling
                
        elif self.destruction_phase == 4:  # Temple collapsing (5 seconds) - 건물 찌그러짐 + 가라앉음
            # Kill all monks and dummies when temple starts collapsing
            if self.destruction_timer == 1:
                print(f"🔥 Temple collapsing! Current monks: {len(self.monks)}")
                for i, monk in enumerate(self.monks):
                    print(f"   Monk {i}: at ({monk['x']}, {monk['y']}) - type: {monk.get('type', 'normal')}")

                # Always spawn some test monks to ensure explosion effect is visible
                for i in range(2):
                    test_monk = {
                        'x': self.width // 2 + random.randint(-80, 80),
                        'y': 480 + random.randint(-30, 30),
                        'color': (100, 80, 60),
                        'type': 'star_reward' if i == 0 else 'normal'
                    }
                    self.monks.append(test_monk)

                print(f"🔥 About to explode {len(self.monks)} monks...")
                self._explode_all_monks()
                print(f"🔥 After explosion: {len(self.monk_death_particles)} particles, {len(self.monk_body_parts)} body parts")
                self._explode_all_training_dummies()

            # 화면 흔들림 (초반에 강하게, 후반에 약하게)
            if self.destruction_timer < 60:
                self.screen_shake_intensity = 8 + int(self.destruction_timer / 10)
            elif self.destruction_timer < 150:
                self.screen_shake_intensity = 12 - int((self.destruction_timer - 60) / 20)
            else:
                self.screen_shake_intensity = max(0, 6 - (self.destruction_timer - 150) // 30)

            # === 건물 찌그러짐 + 가라앉음 애니메이션 ===
            total_duration = 300.0  # 5초
            progress = min(1.0, self.destruction_timer / total_duration)

            # 상륜부 먼저 기울어짐 (0~20%)
            if progress < 0.2:
                spire_progress = progress / 0.2
                self.spire_fall_angle = spire_progress * 45  # 최대 45도 기울어짐
                if spire_progress > 0.8 and not self.spire_fallen:
                    self.spire_fallen = True

            # 건물 수직 압축 (찌그러짐) - 위층부터 순서대로
            # 0.1~0.6 구간에서 점진적으로 압축
            if progress > 0.1:
                crush_progress = min(1.0, (progress - 0.1) / 0.5)
                self.building_crush_factor = 1.0 - crush_progress * 0.6  # 최종 40%까지 압축

                # 각 층별 압축 (위층일수록 더 많이 압축)
                for level in range(self.pagoda_levels):
                    level_delay = level * 0.08
                    level_progress = max(0, min(1.0, (crush_progress - level_delay) / 0.5))
                    # 각 층이 아래로 내려오는 오프셋
                    self.level_crush_offsets[level] = int(level_progress * (4 - level) * 15)

            # 건물 전체 가라앉음 (0.3~1.0 구간)
            if progress > 0.3:
                sink_progress = (progress - 0.3) / 0.7
                # 점점 가속되다가 마지막에 감속
                if sink_progress < 0.7:
                    self.building_sink_amount = sink_progress * 1.2  # 가속
                else:
                    # 마지막 30%에서 감속하며 정지
                    final_progress = (sink_progress - 0.7) / 0.3
                    self.building_sink_amount = 0.84 + final_progress * 0.16

            # 기존 collapse_offset도 가라앉음에 맞춰 조정
            self.collapse_offset = int(self.building_sink_amount * 200)

            # === 파편 물리 업데이트 (지연 시간 적용) ===
            for debris in self.collapse_debris:
                delay = debris.get('delay', 0)
                if self.destruction_timer > delay:
                    debris['y'] += debris['vy']
                    debris['x'] += debris['vx']
                    debris['vy'] += 0.35
                    debris['vx'] *= 0.98
                    debris['rotation'] += debris['rotation_speed']
                    # 화면 밖으로 나가면 페이드 아웃
                    if debris['y'] > self.height or self.destruction_timer > 200:
                        debris['opacity'] = max(0, debris['opacity'] - 2)

            # 지붕 기와 파편 업데이트
            for tile in self.roof_fragments:
                delay = tile.get('delay', 0)
                if self.destruction_timer > delay:
                    tile['y'] += tile['vy']
                    tile['x'] += tile['vx']
                    tile['vy'] += 0.3
                    tile['vx'] *= 0.97
                    tile['rotation'] += tile['rotation_speed']
                    if tile['y'] > self.height or self.destruction_timer > 220:
                        tile['opacity'] = max(0, tile['opacity'] - 2)

            # 먼지 구름 업데이트
            for dust in self.dust_clouds:
                delay = dust.get('delay', 0)
                if self.destruction_timer > delay:
                    if dust['opacity'] < dust['max_opacity']:
                        dust['opacity'] = min(dust['max_opacity'], dust['opacity'] + 3)
                    dust['size'] += dust['expand_rate']
                    dust['y'] += dust['rise_speed']
                    # 서서히 사라짐
                    if self.destruction_timer > delay + 120:
                        dust['opacity'] = max(0, dust['opacity'] - 1)

            # 추가 파편 생성 (건물이 찌그러지는 동안)
            if self.destruction_timer % 25 == 0 and self.destruction_timer < 200:
                self._create_additional_crush_debris()

            # 등롱 및 불 효과 업데이트
            self._update_falling_lanterns()
            self._update_ground_fires()

            if self.destruction_timer >= 300:  # 5초
                self.destruction_phase = 5
                self.destruction_timer = 0
                self.lanterns.clear()
                
        elif self.destruction_phase == 5:  # Complete - show ruins
            self.temple_destroyed = True
            self.destruction_animation_active = False
            self.screen_shake_intensity = 0
            self.monks.clear()  # Remove all monks
            self.monk_spawn_timer = float('inf')  # Stop monk spawning
            print("Temple destruction complete! No more monks will spawn.")
    
    def _fire_destruction_wave(self):
        """Fire a destruction wave from the moon towards the temple"""
        # Get moon position
        moon_x = self.game_center_x + 100
        moon_y = 70
        
        # Get temple position (target)
        temple_x = self.game_center_x
        temple_y = 350
        
        # Create destruction wave with enhanced properties
        self.destruction_wave = {
            'start_x': moon_x,
            'start_y': moon_y,
            'current_x': moon_x,
            'current_y': moon_y,
            'target_x': temple_x,
            'target_y': temple_y,
            'speed': 12.0,  # Faster for more impact
            'radius': 25,  # Larger initial radius
            'max_radius': 120,  # Much larger maximum radius
            'intensity': 1.0,
            'lifetime': 0,
            'max_lifetime': 90,  # 1.5 seconds at 60 FPS
            'trail': [],  # Trail particles
            'beam_particles': [],  # New: beam particles for laser effect
            'energy_rings': [],  # New: expanding energy rings
            'core_rotation': 0,  # New: rotating core
            'charge_particles': []  # New: particles during charging phase
        }
        
        # Calculate direction
        import math
        dx = temple_x - moon_x
        dy = temple_y - moon_y
        distance = math.sqrt(dx*dx + dy*dy)
        if distance > 0:
            self.destruction_wave['vx'] = (dx / distance) * self.destruction_wave['speed']
            self.destruction_wave['vy'] = (dy / distance) * self.destruction_wave['speed']
        else:
            self.destruction_wave['vx'] = 0
            self.destruction_wave['vy'] = self.destruction_wave['speed']
        
        print(f"🌙 Destruction wave fired from ({moon_x}, {moon_y}) to ({temple_x}, {temple_y})")
    
    def _update_destruction_wave(self):
        """Update the destruction wave animation"""
        if self.destruction_wave is None:
            return
            
        wave = self.destruction_wave
        wave['lifetime'] += 1
        wave['core_rotation'] += 15  # Rotate the core
        
        # Move the wave
        wave['current_x'] += wave['vx']
        wave['current_y'] += wave['vy']
        
        # Expand the wave as it travels
        progress = wave['lifetime'] / wave['max_lifetime']
        wave['radius'] = wave['max_radius'] * min(1.0, progress * 1.5)  # Expand faster
        
        # Create multiple trail particles for denser effect
        if wave['lifetime'] % 2 == 0:  # Every 2 frames
            # Main trail particles
            for _ in range(5):  # Multiple particles per frame
                trail_particle = {
                    'x': wave['current_x'] + random.randint(-20, 20),
                    'y': wave['current_y'] + random.randint(-20, 20),
                    'life': 30,
                    'size': random.randint(5, 15),
                    'color': (255, random.randint(50, 100), random.randint(0, 50)),
                    'type': 'trail'
                }
                wave['trail'].append(trail_particle)
            
            # Beam particles for laser effect
            for _ in range(3):
                beam_particle = {
                    'x': wave['current_x'] + random.randint(-5, 5),
                    'y': wave['current_y'] + random.randint(-5, 5),
                    'life': 40,
                    'length': random.randint(20, 40),
                    'width': random.randint(2, 4),
                    'angle': math.atan2(wave['vy'], wave['vx']),
                    'color': (255, 255, random.randint(150, 255))
                }
                wave['beam_particles'].append(beam_particle)
        
        # Create energy rings periodically
        if wave['lifetime'] % 10 == 0:
            energy_ring = {
                'x': wave['current_x'],
                'y': wave['current_y'],
                'radius': 10,
                'max_radius': wave['radius'] * 2,
                'life': 20,
                'opacity': 255
            }
            wave['energy_rings'].append(energy_ring)
        
        # Update trail particles
        for particle in wave['trail'][:]:
            particle['life'] -= 1
            particle['size'] *= 0.95  # Shrink over time
            if particle['life'] <= 0 or particle['size'] < 1:
                wave['trail'].remove(particle)
        
        # Update beam particles
        for beam in wave['beam_particles'][:]:
            beam['life'] -= 1
            beam['length'] *= 0.98  # Shorten over time
            if beam['life'] <= 0:
                wave['beam_particles'].remove(beam)
        
        # Update energy rings
        for ring in wave['energy_rings'][:]:
            ring['radius'] += 8  # Expand rapidly
            ring['opacity'] -= 12  # Fade out
            ring['life'] -= 1
            if ring['life'] <= 0 or ring['opacity'] <= 0:
                wave['energy_rings'].remove(ring)
        
        # Check if wave reached temple or expired
        temple_distance = math.sqrt((wave['current_x'] - wave['target_x'])**2 + 
                                  (wave['current_y'] - wave['target_y'])**2)
        
        if temple_distance < 50:
            print("🌙 Destruction wave hit the temple!")
            self._play_stage4_hit_sound()
            self.destruction_wave = None  # Remove the wave
        elif wave['lifetime'] >= wave['max_lifetime']:
            # Expired before reaching the target (failsafe)
            self.destruction_wave = None
    
    def _draw_destruction_wave(self, surface: pygame.Surface):
        """Draw the destruction wave from moon to temple"""
        if self.destruction_wave is None:
            return
        
        wave = self.destruction_wave
        
        # Draw energy rings first (background layer)
        for ring in wave['energy_rings']:
            if ring['opacity'] > 0:
                ring_surf = pygame.Surface((ring['radius'] * 2, ring['radius'] * 2), pygame.SRCALPHA)
                center = ring['radius']
                # Draw glowing ring
                for width in range(5, 0, -1):
                    opacity = min(255, ring['opacity'] * (width / 5))
                    color = (255, 100 + width * 20, 50, int(opacity))
                    pygame.draw.circle(ring_surf, color, (center, center), 
                                     int(ring['radius'] - width * 2), width)
                surface.blit(ring_surf, 
                           (int(ring['x'] - ring['radius']), 
                            int(ring['y'] - ring['radius'])))
        
        # Draw beam particles for laser effect
        for beam in wave['beam_particles']:
            if beam['life'] > 0:
                beam_surf = pygame.Surface((beam['length'] * 2, beam['width'] * 4), pygame.SRCALPHA)
                
                # Calculate beam opacity based on life
                opacity = int(255 * (beam['life'] / 40))
                
                # Draw multiple layers for glow effect
                for layer in range(3):
                    layer_width = beam['width'] * (3 - layer)
                    layer_opacity = opacity // (layer + 1)
                    layer_color = (*beam['color'][:3], layer_opacity)
                    
                    # Draw beam line
                    start_x = 0
                    end_x = beam['length']
                    center_y = beam_surf.get_height() // 2
                    
                    pygame.draw.line(beam_surf, layer_color,
                                   (start_x, center_y),
                                   (end_x, center_y),
                                   layer_width)
                
                # Rotate and position beam
                angle_degrees = math.degrees(beam['angle'])
                rotated_beam = pygame.transform.rotate(beam_surf, -angle_degrees)
                beam_rect = rotated_beam.get_rect(center=(beam['x'], beam['y']))
                surface.blit(rotated_beam, beam_rect)
        
        # Draw trail particles with enhanced effects
        for particle in wave['trail']:
            alpha = int(255 * (particle['life'] / 30))
            if alpha > 0 and particle['size'] > 0:
                # Create glowing particle
                particle_surf = pygame.Surface((particle['size'] * 4, particle['size'] * 4), pygame.SRCALPHA)
                center = particle['size'] * 2
                
                # Draw multiple layers for glow
                for layer in range(3):
                    layer_size = particle['size'] * (3 - layer) / 2
                    layer_alpha = alpha // (layer + 1)
                    
                    # Create irregular shape with more detail
                    points = []
                    num_points = 8
                    for i in range(num_points):
                        angle = (i * 2 * math.pi / num_points) + random.uniform(-0.3, 0.3)
                        radius = layer_size * random.uniform(0.6, 1.2)
                        x = center + radius * math.cos(angle)
                        y = center + radius * math.sin(angle)
                        points.append((x, y))
                    
                    if len(points) >= 3:
                        color = (*particle['color'], layer_alpha)
                        pygame.draw.polygon(particle_surf, color, points)
                
                surface.blit(particle_surf, 
                           (int(particle['x'] - center), 
                            int(particle['y'] - center)))
        
        # Draw main wave core with enhanced destruction effect
        wave_size = int(wave['radius'] * 3)  # Larger surface for effects
        wave_surf = pygame.Surface((wave_size, wave_size), pygame.SRCALPHA)
        center = wave_size // 2
        
        # Draw outer shockwave
        for ring_offset in range(0, 30, 5):
            ring_radius = wave['radius'] + ring_offset
            if ring_radius < wave_size // 2:
                opacity = max(0, 100 - ring_offset * 3)
                pygame.draw.circle(wave_surf, (255, 50, 0, opacity), 
                                 (center, center), int(ring_radius), 2)
        
        # Create destructive energy core with rotation
        rotation_angle = math.radians(wave['core_rotation'])
        
        # Multiple layers of destructive energy
        for layer in range(5):
            layer_scale = 1.0 - (layer * 0.15)
            layer_rotation = rotation_angle + (layer * 0.2)
            
            # Create jagged, rotating energy shape
            wave_points = []
            num_points = 24  # More points for detail
            for i in range(num_points):
                angle = (i * 2 * math.pi / num_points) + layer_rotation
                
                # Create more dramatic variations
                if i % 3 == 0:  # Energy spikes
                    radius_variation = random.uniform(1.2, 1.5)
                else:
                    radius_variation = random.uniform(0.7, 1.0)
                    
                radius = wave['radius'] * layer_scale * radius_variation
                x = center + radius * math.cos(angle)
                y = center + radius * math.sin(angle)
                wave_points.append((x, y))
            
            if len(wave_points) >= 3:
                # Layer colors from outer to inner
                if layer == 0:  # Outermost - dark red
                    color = (150, 0, 0, 80)
                elif layer == 1:  # Outer glow - bright red
                    color = (255, 0, 0, 120)
                elif layer == 2:  # Middle - orange
                    color = (255, 150, 50, 150)
                elif layer == 3:  # Inner - yellow
                    color = (255, 255, 100, 180)
                else:  # Core - white hot
                    color = (255, 255, 255, 220)
                    
                pygame.draw.polygon(wave_surf, color, wave_points)
        
        # Add lightning/energy bolts emanating from core
        num_bolts = 8
        for i in range(num_bolts):
            bolt_angle = (i * 2 * math.pi / num_bolts) + rotation_angle
            bolt_length = wave['radius'] * random.uniform(1.2, 1.8)
            bolt_end_x = center + bolt_length * math.cos(bolt_angle)
            bolt_end_y = center + bolt_length * math.sin(bolt_angle)
            
            # Draw lightning bolt with multiple segments
            bolt_points = [(center, center)]
            segments = 5
            for seg in range(1, segments + 1):
                progress = seg / segments
                base_x = center + (bolt_end_x - center) * progress
                base_y = center + (bolt_end_y - center) * progress
                
                # Add random offset for lightning effect
                offset_x = random.randint(-10, 10) * (1 - progress)  # Less offset near the end
                offset_y = random.randint(-10, 10) * (1 - progress)
                
                bolt_points.append((base_x + offset_x, base_y + offset_y))
            
            # Draw the bolt with glow
            for width in range(4, 0, -1):
                opacity = 255 // width
                color = (255, 255, 255 - width * 20, opacity)
                for j in range(len(bolt_points) - 1):
                    pygame.draw.line(wave_surf, color, bolt_points[j], bolt_points[j + 1], width)
        
        # Add central blinding core
        core_radius = int(wave['radius'] * 0.2)
        for glow_radius in range(core_radius * 3, 0, -2):
            glow_alpha = min(255, 255 * (core_radius * 3 - glow_radius) // (core_radius * 3))
            glow_color = (255, 255, 255, glow_alpha // 2)
            pygame.draw.circle(wave_surf, glow_color, (center, center), glow_radius)
        
        # Draw bright white core
        pygame.draw.circle(wave_surf, (255, 255, 255, 255), (center, center), core_radius)
        
        # Blit the enhanced wave
        surface.blit(wave_surf, 
                   (int(wave['current_x'] - center), 
                    int(wave['current_y'] - center)))
    
    def _create_collapse_debris(self):
        """Create debris particles for temple collapse - 새 건물에 맞는 파편들"""
        self.collapse_debris = []
        self.roof_fragments = []
        self.wall_cracks = []
        self.dust_clouds = []

        temple_x = self.game_center_x
        temple_base_y = 450

        # === 상륜부(첨탑) 파편 - 가장 먼저 떨어짐 ===
        spire_y = temple_base_y - 5 * 60 - 80  # 맨 위
        for _ in range(8):
            self.collapse_debris.append({
                'x': temple_x + random.randint(-20, 20),
                'y': spire_y + random.randint(-40, 20),
                'vx': random.uniform(-4, 4),
                'vy': random.uniform(-8, -2),
                'size': random.randint(8, 20),
                'rotation': random.uniform(0, 360),
                'rotation_speed': random.uniform(-10, 10),
                'color': self.colors['gold_accent'],
                'opacity': 255,
                'type': 'spire_ornament',  # 상륜부 장식 (금색)
                'delay': 0  # 즉시 시작
            })

        # === 지붕 기와 파편 (반원형 기와) ===
        for level in range(self.pagoda_levels):
            level_y = temple_base_y - level * 60
            level_width = 200 - level * 25

            for _ in range(12 - level * 2):  # 아래층일수록 많은 기와
                self.roof_fragments.append({
                    'x': temple_x + random.randint(-level_width // 2, level_width // 2),
                    'y': level_y - 50 + random.randint(-10, 10),
                    'vx': random.uniform(-6, 6),
                    'vy': random.uniform(-5, 0),
                    'size': random.randint(10, 18),
                    'rotation': random.uniform(0, 360),
                    'rotation_speed': random.uniform(-12, 12),
                    'color': self.colors['roof_red'],
                    'dark_color': self.colors['roof_dark'],
                    'opacity': 255,
                    'type': 'roof_tile',
                    'delay': level * 15  # 위층부터 순서대로 떨어짐
                })

        # === 벽돌/돌 파편 ===
        for level in range(self.pagoda_levels):
            level_y = temple_base_y - level * 60
            level_width = 200 - level * 25

            for _ in range(8 - level):
                side = random.choice([-1, 1])
                self.collapse_debris.append({
                    'x': temple_x + side * random.randint(level_width // 4, level_width // 2),
                    'y': level_y - random.randint(10, 40),
                    'vx': side * random.uniform(2, 5),
                    'vy': random.uniform(-3, 1),
                    'size': random.randint(8, 20),
                    'rotation': random.uniform(0, 360),
                    'rotation_speed': random.uniform(-8, 8),
                    'color': self.colors['temple_main'],
                    'opacity': 255,
                    'type': 'brick',
                    'delay': level * 20 + random.randint(0, 30)
                })

        # === 기둥 파편 ===
        for level in range(self.pagoda_levels):
            level_y = temple_base_y - level * 60
            level_width = 200 - level * 25

            for side in [-1, 1]:
                self.collapse_debris.append({
                    'x': temple_x + side * (level_width // 2 - 15),
                    'y': level_y - 25,
                    'vx': side * random.uniform(1, 3),
                    'vy': random.uniform(-2, 0),
                    'size': random.randint(15, 25),
                    'rotation': random.uniform(0, 90),
                    'rotation_speed': random.uniform(-5, 5),
                    'color': self.colors['temple_main'],
                    'opacity': 255,
                    'type': 'pillar_chunk',
                    'delay': level * 25 + 50
                })

        # === 창문 격자 파편 (꽃살문) ===
        for level in range(1, 4):  # 1~3층에 창문
            level_y = temple_base_y - level * 60
            for side in [-1, 1]:
                self.collapse_debris.append({
                    'x': temple_x + side * 50,
                    'y': level_y - 25,
                    'vx': side * random.uniform(2, 4),
                    'vy': random.uniform(-4, -1),
                    'size': random.randint(12, 18),
                    'rotation': random.uniform(0, 360),
                    'rotation_speed': random.uniform(-15, 15),
                    'color': self.colors['gold_dim'],
                    'opacity': 255,
                    'type': 'window_lattice',
                    'delay': level * 30 + 20
                })

        # === 입구 문 파편 ===
        for i in range(4):
            self.collapse_debris.append({
                'x': temple_x + random.randint(-25, 25),
                'y': temple_base_y - 30,
                'vx': random.uniform(-3, 3),
                'vy': random.uniform(-2, 1),
                'size': random.randint(15, 25),
                'rotation': random.uniform(0, 360),
                'rotation_speed': random.uniform(-6, 6),
                'color': self.colors['roof_dark'],
                'opacity': 255,
                'type': 'door_fragment',
                'delay': 80 + i * 10
            })

        # === 돌계단 파편 ===
        for step in range(5):
            for _ in range(3):
                self.collapse_debris.append({
                    'x': temple_x + random.randint(-80, 80),
                    'y': temple_base_y + step * 12 + 5,
                    'vx': random.uniform(-2, 2),
                    'vy': random.uniform(-1, 0),
                    'size': random.randint(10, 20),
                    'rotation': random.uniform(0, 360),
                    'rotation_speed': random.uniform(-4, 4),
                    'color': self.colors['stone_gray'],
                    'opacity': 255,
                    'type': 'stone',
                    'delay': 120 + step * 15
                })

        # === 먼지 구름 효과 ===
        for _ in range(15):
            self.dust_clouds.append({
                'x': temple_x + random.randint(-100, 100),
                'y': temple_base_y + random.randint(-50, 50),
                'size': random.randint(30, 60),
                'opacity': 0,  # 서서히 나타남
                'max_opacity': random.randint(80, 150),
                'expand_rate': random.uniform(0.5, 1.5),
                'rise_speed': random.uniform(-0.5, -0.2),
                'delay': random.randint(30, 120)
            })
    
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
                'type': random.choice(['brick', 'roof_tile', 'wood_beam', 'stone', 'pillar_chunk'])
            }
            self.collapse_debris.append(debris)

    def _create_additional_crush_debris(self):
        """Create additional debris during building crush/sink animation"""
        temple_x = self.game_center_x
        temple_base_y = 450

        # 현재 가라앉음 상태에 맞춰 파편 생성 위치 조정
        sink_offset = getattr(self, 'building_sink_amount', 0) * 300
        crush_factor = getattr(self, 'building_crush_factor', 1.0)

        # 파편 개수 (건물이 많이 찌그러질수록 더 많은 파편)
        num_debris = int(3 + (1 - crush_factor) * 10)

        for _ in range(num_debris):
            # 파편 타입 선택 (가중치 적용)
            debris_type = random.choices(
                ['brick', 'roof_tile', 'stone', 'pillar_chunk', 'dust'],
                weights=[30, 25, 20, 10, 15]
            )[0]

            if debris_type == 'dust':
                # 먼지 구름 추가
                self.dust_clouds.append({
                    'x': temple_x + random.randint(-80, 80),
                    'y': temple_base_y + sink_offset + random.randint(-30, 30),
                    'size': random.randint(20, 40),
                    'opacity': 0,
                    'max_opacity': random.randint(60, 100),
                    'expand_rate': random.uniform(0.8, 2.0),
                    'rise_speed': random.uniform(-0.8, -0.3),
                    'color': (70, 60, 50),  # 갈색 먼지
                    'delay': 0
                })
            else:
                # 일반 파편
                level = random.randint(0, 4)
                level_y = temple_base_y - level * 60 * crush_factor + sink_offset

                # 파편 색상 결정
                if debris_type == 'roof_tile':
                    color = self.colors['roof_red']
                elif debris_type == 'pillar_chunk':
                    color = self.colors['temple_main']
                elif debris_type == 'stone':
                    color = self.colors['stone_gray']
                else:  # brick
                    color = self.colors['temple_main']

                self.collapse_debris.append({
                    'x': temple_x + random.randint(-100, 100),
                    'y': level_y + random.randint(-20, 20),
                    'vx': random.uniform(-3, 3),
                    'vy': random.uniform(-2, 2),
                    'size': random.randint(6, 14),
                    'rotation': random.uniform(0, 360),
                    'rotation_speed': random.uniform(-8, 8),
                    'color': color,
                    'opacity': 255,
                    'type': debris_type,
                    'delay': 0
                })

        # 지붕 기와 추가 (확률적으로)
        if random.random() < 0.3 and crush_factor < 0.8:
            for _ in range(2):
                self.roof_fragments.append({
                    'x': temple_x + random.randint(-60, 60),
                    'y': temple_base_y - 200 * crush_factor + sink_offset,
                    'vx': random.uniform(-4, 4),
                    'vy': random.uniform(-3, 0),
                    'size': random.randint(8, 14),
                    'rotation': random.uniform(0, 360),
                    'rotation_speed': random.uniform(-10, 10),
                    'color': self.colors['roof_red'],
                    'dark_color': self.colors['roof_dark'],
                    'opacity': 255,
                    'type': 'roof_tile',
                    'delay': 0
                })

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
                'type': 'wood_beam',  # Frame pieces are wooden beams
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
        """Draw falling debris during collapse as realistic building fragments"""
        # roof_fragments도 collapse_debris와 함께 그리기
        roof_fragments = getattr(self, 'roof_fragments', [])
        all_debris = list(self.collapse_debris) + list(roof_fragments)

        for debris in all_debris:
            # Check if debris has opacity (default to 255 if not)
            opacity = debris.get('opacity', 255)
            if opacity > 0:
                # Create surface for debris
                debris_surf = pygame.Surface((debris['size'] * 3, debris['size'] * 3), pygame.SRCALPHA)
                center = debris['size'] * 1.5
                
                # Draw debris piece based on type with building fragment appearance
                color = (*debris['color'], opacity)
                darker_color = tuple(max(0, c - 30) for c in debris['color']) + (opacity,)
                
                if debris.get('type') == 'brick':
                    # Draw brick fragment (rectangular with texture lines)
                    brick_width = debris['size'] * 1.8
                    brick_height = debris['size'] * 0.9
                    
                    # Main brick shape
                    points = []
                    for dx, dy in [(-brick_width/2, -brick_height/2), 
                                  (brick_width/2, -brick_height/2),
                                  (brick_width/2, brick_height/2),
                                  (-brick_width/2, brick_height/2)]:
                        angle = math.radians(debris['rotation'])
                        x = center + dx * math.cos(angle) - dy * math.sin(angle)
                        y = center + dx * math.sin(angle) + dy * math.cos(angle)
                        points.append((x, y))
                    pygame.draw.polygon(debris_surf, color, points)
                    
                    # Add mortar lines for brick texture
                    pygame.draw.polygon(debris_surf, darker_color, points, 2)
                
                elif debris.get('type') == 'roof_tile':
                    # Draw curved roof tile fragment
                    tile_width = debris['size'] * 1.2
                    tile_height = debris['size'] * 1.6
                    
                    # Curved tile shape using multiple points
                    points = []
                    for i in range(8):
                        t = i / 7.0
                        # Create curved top edge
                        if i < 4:
                            dx = (t - 0.5) * tile_width
                            dy = -tile_height/2 + (t * (1-t)) * tile_height * 0.3
                        else:
                            dx = (1 - t + 0.5) * tile_width
                            dy = tile_height/2
                        
                        angle = math.radians(debris['rotation'])
                        x = center + dx * math.cos(angle) - dy * math.sin(angle)
                        y = center + dx * math.sin(angle) + dy * math.cos(angle)
                        points.append((x, y))
                    
                    if len(points) >= 3:
                        pygame.draw.polygon(debris_surf, color, points)
                        pygame.draw.polygon(debris_surf, darker_color, points, 1)
                
                elif debris.get('type') == 'wood_beam':
                    # Draw wooden beam fragment (long and narrow)
                    beam_width = debris['size'] * 2.2
                    beam_height = debris['size'] * 0.6
                    
                    # Main beam shape
                    points = []
                    for dx, dy in [(-beam_width/2, -beam_height/2), 
                                  (beam_width/2, -beam_height/2),
                                  (beam_width/2, beam_height/2),
                                  (-beam_width/2, beam_height/2)]:
                        angle = math.radians(debris['rotation'])
                        x = center + dx * math.cos(angle) - dy * math.sin(angle)
                        y = center + dx * math.sin(angle) + dy * math.cos(angle)
                        points.append((x, y))
                    pygame.draw.polygon(debris_surf, color, points)
                    
                    # Add wood grain lines
                    for i in range(3):
                        line_x = center + (i - 1) * beam_width * 0.2
                        line_start = (line_x, center - beam_height/2)
                        line_end = (line_x, center + beam_height/2)
                        pygame.draw.line(debris_surf, darker_color, line_start, line_end, 1)
                
                elif debris.get('type') == 'stone':
                    # Draw irregular stone fragment
                    num_points = 6
                    points = []
                    for i in range(num_points):
                        angle = (i * 2 * math.pi / num_points) + math.radians(debris['rotation'])
                        # Irregular radius for natural stone look
                        radius = debris['size'] * random.uniform(0.7, 1.1)
                        x = center + radius * math.cos(angle)
                        y = center + radius * math.sin(angle)
                        points.append((x, y))
                    
                    if len(points) >= 3:
                        pygame.draw.polygon(debris_surf, color, points)
                        pygame.draw.polygon(debris_surf, darker_color, points, 2)
                
                elif debris.get('type') == 'pillar_chunk':
                    # Draw cylindrical pillar chunk
                    chunk_radius = debris['size'] * 0.9
                    # Draw as octagon for pillar appearance
                    points = []
                    for i in range(8):
                        angle = (i * 2 * math.pi / 8) + math.radians(debris['rotation'])
                        x = center + chunk_radius * math.cos(angle)
                        y = center + chunk_radius * math.sin(angle)
                        points.append((x, y))
                    
                    pygame.draw.polygon(debris_surf, color, points)
                    # Add pillar ridges
                    pygame.draw.polygon(debris_surf, darker_color, points, 2)
                    pygame.draw.circle(debris_surf, darker_color, (int(center), int(center)), int(chunk_radius * 0.6), 1)
                
                elif debris.get('type') == 'glass':
                    # Draw glass shard (sharp triangular pieces)
                    shard_length = debris['size'] * 1.4
                    shard_width = debris['size'] * 0.5
                    
                    # Create sharp glass shard shape
                    points = [
                        (center, center - shard_length/2),  # Sharp tip
                        (center - shard_width/2, center + shard_length/2),  # Bottom left
                        (center + shard_width/2, center + shard_length/2),  # Bottom right
                    ]
                    
                    # Apply rotation
                    rotated_points = []
                    for px, py in points:
                        angle = math.radians(debris['rotation'])
                        rx = center + (px - center) * math.cos(angle) - (py - center) * math.sin(angle)
                        ry = center + (px - center) * math.sin(angle) + (py - center) * math.cos(angle)
                        rotated_points.append((rx, ry))
                    
                    pygame.draw.polygon(debris_surf, color, rotated_points)
                    # Add sharp edge highlight
                    bright_color = tuple(min(255, c + 50) for c in debris['color']) + (opacity,)
                    pygame.draw.polygon(debris_surf, bright_color, rotated_points, 1)

                elif debris.get('type') == 'spire_ornament':
                    # Draw golden spire ornament fragment (상륜부 장식 파편)
                    ornament_size = debris['size'] * 1.2

                    # Draw as decorative oval/bowl shape
                    pygame.draw.ellipse(debris_surf, color,
                                      (center - ornament_size, center - ornament_size * 0.6,
                                       ornament_size * 2, ornament_size * 1.2))
                    # Add golden highlight
                    bright_gold = tuple(min(255, c + 60) for c in debris['color']) + (opacity,)
                    pygame.draw.ellipse(debris_surf, bright_gold,
                                      (center - ornament_size * 0.6, center - ornament_size * 0.4,
                                       ornament_size * 0.8, ornament_size * 0.5))
                    # Add border
                    pygame.draw.ellipse(debris_surf, darker_color,
                                      (center - ornament_size, center - ornament_size * 0.6,
                                       ornament_size * 2, ornament_size * 1.2), 2)

                elif debris.get('type') == 'window_lattice':
                    # Draw window lattice fragment (꽃살문 격자 파편)
                    lattice_size = debris['size'] * 1.4
                    angle = math.radians(debris['rotation'])

                    # Draw diamond pattern (마름모 격자)
                    # Main diamond
                    points = [
                        (center, center - lattice_size),      # Top
                        (center + lattice_size * 0.8, center), # Right
                        (center, center + lattice_size),       # Bottom
                        (center - lattice_size * 0.8, center), # Left
                    ]
                    # Apply rotation
                    rotated_points = []
                    for px, py in points:
                        rx = center + (px - center) * math.cos(angle) - (py - center) * math.sin(angle)
                        ry = center + (px - center) * math.sin(angle) + (py - center) * math.cos(angle)
                        rotated_points.append((rx, ry))

                    # Draw as outline (lattice is hollow)
                    pygame.draw.polygon(debris_surf, color, rotated_points, 2)
                    # Cross lines inside
                    pygame.draw.line(debris_surf, color, rotated_points[0], rotated_points[2], 1)
                    pygame.draw.line(debris_surf, color, rotated_points[1], rotated_points[3], 1)

                elif debris.get('type') == 'door_fragment':
                    # Draw wooden door fragment (문짝 파편)
                    door_width = debris['size'] * 1.6
                    door_height = debris['size'] * 2.0

                    # Rotate door fragment
                    angle = math.radians(debris['rotation'])
                    points = []
                    for dx, dy in [(-door_width/2, -door_height/2),
                                  (door_width/2, -door_height/2),
                                  (door_width/2, door_height/2),
                                  (-door_width/2, door_height/2)]:
                        x = center + dx * math.cos(angle) - dy * math.sin(angle)
                        y = center + dx * math.sin(angle) + dy * math.cos(angle)
                        points.append((x, y))

                    pygame.draw.polygon(debris_surf, color, points)
                    pygame.draw.polygon(debris_surf, darker_color, points, 2)
                    # Add door decoration lines
                    for i in range(2):
                        line_offset = (i - 0.5) * door_width * 0.4
                        start_x = center + line_offset * math.cos(angle)
                        start_y = center + line_offset * math.sin(angle)
                        pygame.draw.circle(debris_surf, darker_color, (int(start_x), int(start_y)), 2)

                elif debris.get('type') == 'stair_stone':
                    # Draw stone stair fragment (계단 돌 파편)
                    stair_width = debris['size'] * 1.8
                    stair_height = debris['size'] * 0.7

                    angle = math.radians(debris['rotation'])
                    points = []
                    for dx, dy in [(-stair_width/2, -stair_height/2),
                                  (stair_width/2, -stair_height/2),
                                  (stair_width/2, stair_height/2),
                                  (-stair_width/2, stair_height/2)]:
                        x = center + dx * math.cos(angle) - dy * math.sin(angle)
                        y = center + dx * math.sin(angle) + dy * math.cos(angle)
                        points.append((x, y))

                    pygame.draw.polygon(debris_surf, color, points)
                    pygame.draw.polygon(debris_surf, darker_color, points, 2)
                    # Add stone texture line
                    pygame.draw.line(debris_surf, darker_color,
                                   (center - stair_width * 0.3, center),
                                   (center + stair_width * 0.3, center), 1)

                else:  # default irregular fragment
                    # Draw irregular building fragment
                    num_points = random.randint(4, 7)
                    points = []
                    for i in range(num_points):
                        angle = (i * 2 * math.pi / num_points) + math.radians(debris['rotation'])
                        radius = debris['size'] * random.uniform(0.6, 1.0)
                        x = center + radius * math.cos(angle)
                        y = center + radius * math.sin(angle)
                        points.append((x, y))
                    
                    if len(points) >= 3:
                        pygame.draw.polygon(debris_surf, color, points)
                        pygame.draw.polygon(debris_surf, darker_color, points, 1)
                
                surface.blit(debris_surf,
                           (int(debris['x'] - center),
                            int(debris['y'] - center)))

    def _draw_dust_clouds(self, surface: pygame.Surface):
        """Draw dust clouds during building collapse (건물 붕괴 시 먼지 구름)"""
        dust_clouds = getattr(self, 'dust_clouds', [])

        for dust in dust_clouds:
            if dust.get('alpha', 0) <= 0:
                continue

            # 먼지 구름 크기와 투명도
            size = dust.get('size', 30)
            alpha = int(dust.get('alpha', 100))
            x = dust.get('x', 0)
            y = dust.get('y', 0)

            # 먼지 색상 (갈색/회색 계열)
            base_color = dust.get('color', (80, 70, 60))

            # 여러 겹의 원으로 먼지 구름 표현
            for layer in range(3):
                layer_size = size * (1 - layer * 0.2)
                layer_alpha = int(alpha * (1 - layer * 0.3))

                if layer_alpha > 0:
                    # 메인 구름
                    dust_surf = pygame.Surface((int(layer_size * 2.5), int(layer_size * 2)), pygame.SRCALPHA)
                    dust_color = (*base_color, layer_alpha)

                    # 불규칙한 구름 모양 (여러 원 조합)
                    cx, cy = int(layer_size * 1.25), int(layer_size)
                    offsets = [
                        (0, 0, 1.0),
                        (-layer_size * 0.3, -layer_size * 0.2, 0.7),
                        (layer_size * 0.3, -layer_size * 0.1, 0.6),
                        (-layer_size * 0.2, layer_size * 0.2, 0.5),
                        (layer_size * 0.2, layer_size * 0.15, 0.55),
                    ]

                    for ox, oy, scale in offsets:
                        circle_x = int(cx + ox)
                        circle_y = int(cy + oy)
                        circle_r = int(layer_size * scale * 0.5)
                        if circle_r > 0:
                            pygame.draw.circle(dust_surf, dust_color,
                                             (circle_x, circle_y), circle_r)

                    # 화면에 그리기
                    surface.blit(dust_surf,
                               (int(x - layer_size * 1.25), int(y - layer_size)),
                               special_flags=pygame.BLEND_ADD)

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
                
                # Create particle surface for flame shape
                particle_surf = pygame.Surface((particle['size'] * 2, particle['size'] * 2), pygame.SRCALPHA)
                
                # Create flame-like shape (teardrop pointing up)
                center = particle['size']
                flame_points = []
                
                # Create flame shape with pointed top and wider base
                for i in range(8):
                    angle = (i * 2 * math.pi / 8)
                    if i == 0:  # Top point (flame tip)
                        radius = particle['size'] * 1.3
                        x = center + radius * math.cos(angle - math.pi/2)
                        y = center + radius * math.sin(angle - math.pi/2)
                    elif i <= 2 or i >= 6:  # Upper sides
                        radius = particle['size'] * 0.7
                        x = center + radius * math.cos(angle - math.pi/2)
                        y = center + radius * math.sin(angle - math.pi/2)
                    else:  # Base of flame (wider)
                        radius = particle['size'] * 0.9
                        x = center + radius * math.cos(angle - math.pi/2)
                        y = center + radius * math.sin(angle - math.pi/2)
                    flame_points.append((x, y))
                
                if len(flame_points) >= 3:
                    pygame.draw.polygon(particle_surf, (*color, alpha), flame_points)
                    # Add bright core
                    core_color = tuple(min(255, c + 50) for c in color)
                    core_size = max(1, particle['size'] // 3)
                    if core_size > 0:
                        core_points = []
                        for i in range(4):
                            angle = (i * 2 * math.pi / 4)
                            radius = core_size
                            x = center + radius * math.cos(angle - math.pi/2)
                            y = center + radius * math.sin(angle - math.pi/2)
                            core_points.append((x, y))
                        if len(core_points) >= 3:
                            pygame.draw.polygon(particle_surf, (*core_color, alpha), core_points)
                
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
        moon_x = self.pillar_offset + self.game_width - 120
        moon_y = 100
        
        # Activate moon pulsing effect
        self.moon_pulse_active = True
        self.moon_pulse_timer = 30  # 0.5 second pulse

        # Play firing sound for the fragment volley
        self._play_stage4_fragment_shoot_sound()
        
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
            
            # 다단히트용 고유 ID 생성 (타임스탬프 + 랜덤)
            fragment_id = pygame.time.get_ticks() * 1000 + random.randint(0, 999)

            # Pre-generate random values for rendering (optimization)
            frag_size = random.randint(8, 15)
            glow_offsets = [(random.uniform(0.8, 1.2), random.uniform(0.8, 1.2)) for _ in range(12)]
            middle_glow_offsets = [(random.uniform(0.9, 1.1), random.uniform(0.9, 1.1)) for _ in range(10)]
            core_offsets = [random.uniform(0.8, 1.0) for _ in range(8)]

            fragment = {
                'fragment_id': fragment_id,  # 다단히트 쿨다운 추적용 고유 ID
                'x': moon_x + random.randint(-30, 30),  # Start near moon
                'y': moon_y + random.randint(-30, 30),
                'vx': vx,
                'vy': vy,
                'target_x': target_x,
                'target_y': target_y,
                'size': frag_size,
                'rotation': 0,
                'rotation_speed': random.uniform(-10, 10),
                'lifetime': 300,  # 5 seconds - increased for better reach
                'trail': [],  # Trail effect
                'impact': False,
                'glow_phase': random.uniform(0, math.pi * 2),
                # Pre-cached random offsets for rendering (avoid per-frame random calls)
                'glow_offsets': glow_offsets,
                'middle_glow_offsets': middle_glow_offsets,
                'core_offsets': core_offsets,
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
                self.moon_fragment_interval = random.randint(120, 900)  # 2-15 seconds
        
        # Update existing fragments
        for fragment in self.moon_fragments[:]:
            if not fragment['impact']:
                # Update position
                fragment['x'] += fragment['vx']
                fragment['y'] += fragment['vy']
                fragment['rotation'] += fragment['rotation_speed']
                fragment['glow_phase'] += 0.1
                
                # Check collision with temple during destruction event
                if self.destruction_animation_active and not self.temple_destroyed:
                    if self._get_temple_hitbox().collidepoint(fragment['x'], fragment['y']):
                        fragment['impact'] = True
                        fragment['impact_timer'] = 30  # 0.5 second impact effect
                        fragment['shockwave_radius'] = 0
                        fragment['impact_reason'] = "temple"
                        self._play_stage4_hit_sound()
                        continue
                
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
                    # 다단히트 쿨다운 딕셔너리에서도 정리
                    fragment_id = fragment.get('fragment_id', id(fragment))
                    if fragment_id in self.fragment_hit_cooldowns:
                        del self.fragment_hit_cooldowns[fragment_id]
                    self.moon_fragments.remove(fragment)

    def _get_temple_hitbox(self) -> pygame.Rect:
        """Return current temple hitbox, adjusted for collapse offset"""
        base_y = 450 + getattr(self, "collapse_offset", 0)
        width = self.temple_hitbox.width
        height = self.temple_hitbox.height
        x = self.width // 2 - width // 2
        y = max(0, base_y - height)
        return pygame.Rect(x, y, width, height)

    def _play_stage4_hit_sound(self):
        """Play moon-fragment-to-temple impact sound"""
        if self.stage4_hit_sound:
            try:
                self.stage4_hit_sound.play()
            except Exception:
                pass

    def _play_stage4_moon_shoot_sound(self):
        """Play moon destruction beam firing sound"""
        if self.stage4_moon_shoot_sound:
            try:
                self.stage4_moon_shoot_sound.play()
            except Exception:
                pass

    def _play_stage4_fragment_shoot_sound(self):
        """Play moon fragment volley firing sound"""
        if self.stage4_fragment_shoot_sound:
            try:
                self.stage4_fragment_shoot_sound.play()
            except Exception:
                pass
    
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
        print(f"Created {len(self.monk_death_particles)} death particles and {len(self.monk_body_parts)} body parts")
    
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
        """Create monk body fragments explosion like crow explosion"""
        # Create monk body fragments (like crow fragments)
        for _ in range(8):  # 8 body fragments
            fragment_angle = random.uniform(0, 2 * math.pi)
            fragment_speed = random.uniform(4, 12)
            
            fragment = {
                'x': x,
                'y': y,
                'vx': math.cos(fragment_angle) * fragment_speed,
                'vy': math.sin(fragment_angle) * fragment_speed - 3,  # Upward bias
                'rotation': random.uniform(0, 360),
                'rotation_speed': random.uniform(-15, 15),
                'size': random.randint(8, 15),
                'gravity': 0.4,
                'life': random.randint(90, 150),  # 1.5-2.5 seconds
                'color': color,  # Use monk's robe color
                'type': random.choice(['head', 'torso', 'arm', 'leg']),
                'opacity': 255
            }
            self.monk_death_particles.append(fragment)
        
        # Create small blood droplets (fewer than before)
        for _ in range(8):  # Reduced from 30
            particle_angle = random.uniform(0, 2 * math.pi)
            particle_speed = random.uniform(2, 6)
            
            particle = {
                'x': x,
                'y': y,
                'vx': math.cos(particle_angle) * particle_speed,
                'vy': math.sin(particle_angle) * particle_speed - 2,
                'size': random.randint(3, 6),
                'color': (200, 0, 0),  # Blood red
                'life': random.randint(40, 60),
                'opacity': 200
            }
            self.monk_death_particles.append(particle)
    
    def _create_hero_monk_explosion(self, x, y):
        """Create epic hero monk body fragments explosion"""
        # Create golden monk body fragments (bigger and more dramatic)
        for _ in range(12):  # More fragments for hero
            fragment_angle = random.uniform(0, 2 * math.pi)
            fragment_speed = random.uniform(6, 15)  # Faster
            
            fragment = {
                'x': x,
                'y': y,
                'vx': math.cos(fragment_angle) * fragment_speed,
                'vy': math.sin(fragment_angle) * fragment_speed - 5,  # Strong upward force
                'rotation': random.uniform(0, 360),
                'rotation_speed': random.uniform(-20, 20),
                'size': random.randint(12, 20),  # Bigger fragments
                'gravity': 0.3,  # Slower fall
                'life': random.randint(120, 180),  # Longer life
                'color': (255, 215, 0),  # Gold color
                'type': random.choice(['head', 'torso', 'arm', 'leg']),
                'opacity': 255,
                'is_hero': True  # Special flag for hero fragments
            }
            self.monk_death_particles.append(fragment)
        
        # Create golden sparkle particles (fewer)
        for _ in range(15):  # Reduced from 30
            particle_angle = random.uniform(0, 2 * math.pi)
            particle_speed = random.uniform(3, 8)
            
            particle = {
                'x': x,
                'y': y,
                'vx': math.cos(particle_angle) * particle_speed,
                'vy': math.sin(particle_angle) * particle_speed - 3,
                'size': random.randint(4, 8),
                'color': (255, 255, 100),  # Bright golden
                'life': random.randint(60, 90),
                'opacity': 255,
                'type': 'sparkle'
            }
            self.monk_death_particles.append(particle)
    
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
        self.moon_fragment_interval = random.randint(120, 900)
        self.moon_fragment_active = False
        
        # Reset moon pulsing
        self.moon_pulse_timer = 0
        self.moon_pulse_active = False
        self.moon_pulse_scale = 1.0
        
        # Reset destruction wave
        self.destruction_wave = None
        self.destruction_wave_charging = False

        # Reset building sink/crush animation variables (건물 찌그러짐/가라앉음)
        self.building_sink_amount = 0.0
        self.building_crush_factor = 1.0
        self.level_crush_offsets = [0, 0, 0, 0, 0]
        self.roof_fragments = []
        self.wall_cracks = []
        self.dust_clouds = []
        self.spire_fallen = False
        self.spire_fall_angle = 0

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
        self._temp_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self._red_overlay_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        print("Stage 4: Shaolin Temple background reset to initial state")
    
    def _draw_moon_fragments(self, surface: pygame.Surface):
        """Draw moon crater fragments (optimized)"""
        # OPTIMIZATION: Get cached trail surface or create once
        if not hasattr(self, '_trail_surf_cache'):
            self._trail_surf_cache = {}

        for fragment in self.moon_fragments:
            if not fragment['impact']:
                # Draw trail (optimized - skip every other trail point)
                trail_len = len(fragment['trail'])
                for idx, trail_point in enumerate(fragment['trail']):
                    # Skip every other point for performance
                    if idx % 2 == 0 and idx < trail_len - 1:
                        continue

                    trail_size = int(trail_point['size'])
                    cache_key = (trail_size, trail_point['alpha'] // 30)  # Group by size and alpha range

                    if cache_key not in self._trail_surf_cache:
                        trail_surf = pygame.Surface((trail_size * 2, trail_size * 2), pygame.SRCALPHA)
                        # Simplified trail - single circle instead of 3 layers
                        alpha = trail_point['alpha']
                        color = (*self.colors['fragment_trail'][:3], alpha)
                        pygame.draw.circle(trail_surf, color, (trail_size, trail_size), trail_size)
                        self._trail_surf_cache[cache_key] = trail_surf

                    surface.blit(self._trail_surf_cache[cache_key],
                               (int(trail_point['x'] - trail_size),
                                int(trail_point['y'] - trail_size)))

                # Draw main fragment with glow
                fragment_surf = pygame.Surface((fragment['size'] * 4, fragment['size'] * 4), pygame.SRCALPHA)
                center = fragment['size'] * 2

                # Outer glow (pulsing) - use pre-cached random offsets
                glow_intensity = abs(math.sin(fragment['glow_phase'])) * 0.5 + 0.5
                glow_size = fragment['size'] * 2 * glow_intensity

                # Use pre-cached offsets instead of random.uniform() per frame
                glow_offsets = fragment.get('glow_offsets', [(1.0, 1.0)] * 12)
                glow_points = []
                for i in range(12):
                    angle = (i * 2 * math.pi / 12) + math.radians(fragment['rotation'])
                    radius = glow_size * glow_offsets[i][0]
                    x = center + radius * math.cos(angle)
                    y = center + radius * math.sin(angle)
                    glow_points.append((x, y))

                if len(glow_points) >= 3:
                    pygame.draw.polygon(fragment_surf, (*self.colors['fragment_glow'], 50), glow_points)

                # Middle glow - use pre-cached offsets
                middle_glow_offsets = fragment.get('middle_glow_offsets', [(1.0, 1.0)] * 10)
                middle_glow_points = []
                for i in range(10):
                    angle = (i * 2 * math.pi / 10) + math.radians(fragment['rotation'])
                    radius = fragment['size'] * 1.5 * middle_glow_offsets[i][0]
                    x = center + radius * math.cos(angle)
                    y = center + radius * math.sin(angle)
                    middle_glow_points.append((x, y))

                if len(middle_glow_points) >= 3:
                    pygame.draw.polygon(fragment_surf, (*self.colors['fragment_glow'], 100), middle_glow_points)

                # Core (rocky texture) - use pre-cached offsets
                core_offsets = fragment.get('core_offsets', [0.9] * 8)
                points = []
                num_points = 8
                for i in range(num_points):
                    angle = (i * 2 * math.pi / num_points) + math.radians(fragment['rotation'])
                    radius = fragment['size'] * core_offsets[i]
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
                    # Shockwave - use simpler circle instead of jagged polygon
                    shockwave_radius = fragment.get('shockwave_radius', 0)
                    if shockwave_radius > 0:
                        alpha = int(150 * (fragment['impact_timer'] / 30))
                        # OPTIMIZATION: Draw directly to surface instead of creating new surface
                        pygame.draw.circle(surface, (*self.colors['fragment_glow'][:3], alpha),
                                         (int(fragment['x']), int(fragment['y'])),
                                         int(shockwave_radius), 3)

                    # Impact sparks - reduced from 5 to 3 and simplified
                    for i in range(3):
                        spark_angle = (i * 120 + fragment['rotation']) * math.pi / 180
                        spark_dist = shockwave_radius * 0.5
                        spark_x = fragment['x'] + math.cos(spark_angle) * spark_dist
                        spark_y = fragment['y'] + math.sin(spark_angle) * spark_dist
                        # Draw simple circle instead of polygon
                        pygame.draw.circle(surface, self.colors['fragment_core'],
                                         (int(spark_x), int(spark_y)), 3)
    
    def get_moon_fragments(self):
        """Get current moon fragments for collision detection"""
        active_fragments = []
        for fragment in self.moon_fragments:
            if not fragment['impact']:
                active_fragments.append({
                    'x': fragment['x'],
                    'y': fragment['y'],
                    'radius': fragment['size'],
                    'fragment_id': fragment.get('fragment_id', id(fragment)),  # 다단히트용 고유 ID
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
