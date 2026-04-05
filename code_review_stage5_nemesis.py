# -*- coding: utf-8 -*-
"""
============================================================================
 PingFighter - Stage 5 Nemesis: Ocean Cyberpunk Arena Background
============================================================================

 Redesigned animated background for the Nemesis boss battle.
 Theme: "Battleship arena floating over a stormy ocean at dusk"

 Rendering Stack (back to front):
   1.  Sky gradient       - dramatic dusk sky (dark navy → amber horizon)
   2.  Distant ships      - faint warship silhouettes on the horizon
   3.  Clouds             - dark, ominous storm clouds
   4.  Horizon haze       - atmospheric fog band separating sky/ocean
   5.  Ocean gradient     - deep indigo ocean
   6.  Background waves   - small, distant wave layer
   7.  Platform shadow    - dark ellipse on water surface
   8.  Floating arena     - multi-deck cyberpunk stadium with towers
   9.  Radar sweep        - rotating scan beam from central antenna
   10. Hologram scanlines - horizontal interference lines
   11. Fire lines         - burning midfield with particles (subdued)
   12. Foreground waves   - large, close wave layer (depth separation)
   13. Border             - thin neon trim (non-intrusive)

 Performance: all gradients numpy-cached, surfaces pre-allocated,
 silhouettes pre-rendered, particle glow from module LRU cache.
============================================================================
"""

import pygame
import pygame.surfarray
import math
import random
import numpy as np
from collections import OrderedDict

# ============================================================================
#  Surface Cache (OrderedDict LRU)
# ============================================================================

_surface_cache = OrderedDict()

def _get_cached_surface(width: int, height: int) -> pygame.Surface:
    """Return a cleared SRCALPHA surface from LRU cache."""
    key = (width, height)
    if key not in _surface_cache:
        if len(_surface_cache) > 100:
            _surface_cache.popitem(last=False)
        _surface_cache[key] = pygame.Surface((width, height), pygame.SRCALPHA)
    else:
        _surface_cache.move_to_end(key)
    surface = _surface_cache[key]
    surface.fill((0, 0, 0, 0))
    return surface


# ============================================================================
#  Constants
# ============================================================================

try:
    from config.constants import PILLAR_UI_WIDTH, GAME_PLAY_WIDTH, SCREEN_HEIGHT
    PILLAR_OFFSET = PILLAR_UI_WIDTH
    GAME_WIDTH = GAME_PLAY_WIDTH
    HEIGHT = SCREEN_HEIGHT
except ImportError:
    PILLAR_OFFSET = 80
    GAME_WIDTH = 600
    HEIGHT = 750


# ============================================================================
#  AnimatedBackgroundStage6 - Nemesis Ocean Arena (Redesigned)
# ============================================================================

class AnimatedBackgroundStage6:
    """
    Redesigned background for Stage 5 Nemesis.

    Design goals:
      - Strong central silhouette (multi-deck arena, not a flat rectangle)
      - 3-layer depth: foreground waves / midground arena / background sky
      - Narrative tension: distant warships, radar sweep, hologram glitch
      - Subdued border that frames without competing
      - Cyan neon as accent only, platform body in dark gunmetal
    """

    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.time = 0
        self.cx = width // 2       # center x
        self.cy = height // 2      # center y (midfield)

        # ------------------------------------------------------------------
        #  Color Palette (darker, more dramatic than original)
        # ------------------------------------------------------------------
        # Sky: stormy dusk
        self.sky_top = (15, 20, 45)           # Deep navy
        self.sky_mid = (40, 35, 65)           # Indigo-purple
        self.horizon_color = (180, 120, 60)   # Muted amber sunset
        # Ocean: deep and threatening
        self.ocean_surface = (10, 40, 80)     # Dark navy
        self.ocean_deep = (5, 15, 40)         # Abyss
        self.wave_foam = (180, 200, 220)      # Cold white foam
        # Neon accents (used sparingly)
        self.cyan_accent = (0, 180, 220)      # Cyan (edges only)
        self.cyan_dim = (0, 80, 110)          # Dimmed cyan (secondary)
        # Platform body
        self.gunmetal = (30, 35, 50)          # Dark gunmetal
        self.gunmetal_light = (45, 50, 65)    # Lighter gunmetal (upper deck)
        self.gunmetal_edge = (55, 60, 75)     # Edge highlight
        # Fire (toned down)
        self.fire_colors = [
            (255, 100, 50),
            (255, 80, 30),
            (200, 60, 20),
            (150, 40, 10),
        ]

        # ------------------------------------------------------------------
        #  Pre-allocated Surfaces
        # ------------------------------------------------------------------
        self._glow_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        self._wave_surface = pygame.Surface((width, 50), pygame.SRCALPHA)
        self._fg_wave_surface = pygame.Surface((width, 60), pygame.SRCALPHA)
        self._shadow_surface = pygame.Surface((width, 80), pygame.SRCALPHA)
        self._platform_surface = pygame.Surface((width, height // 3), pygame.SRCALPHA)
        self._haze_surface = pygame.Surface((width, 40), pygame.SRCALPHA)
        self._ship_surface = pygame.Surface((width, 60), pygame.SRCALPHA)
        self._scanline_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        self._transparent = (0, 0, 0, 0)

        # ------------------------------------------------------------------
        #  Gradient Caches
        # ------------------------------------------------------------------
        self._sky_gradient_cache = None
        self._ocean_gradient_cache = None
        self._init_gradient_caches()

        # ------------------------------------------------------------------
        #  Pre-rendered Static Elements
        # ------------------------------------------------------------------
        self._init_horizon_haze()
        self._init_distant_ships()
        self._init_platform_static()

        # ------------------------------------------------------------------
        #  Background Waves (5 layers, small amplitude - distant feel)
        # ------------------------------------------------------------------
        self.bg_waves = []
        for i in range(5):
            self.bg_waves.append({
                'y': self.cy + 20 + i * 25,
                'amplitude': random.uniform(3, 8),
                'frequency': random.uniform(0.01, 0.025),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.015, 0.03),
            })

        # ------------------------------------------------------------------
        #  Foreground Waves (2 layers, large - creates depth)
        # ------------------------------------------------------------------
        self.fg_waves = []
        for i in range(2):
            self.fg_waves.append({
                'y': height - 80 + i * 35,
                'amplitude': random.uniform(8, 18),
                'frequency': random.uniform(0.008, 0.02),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.025, 0.045),
            })

        # ------------------------------------------------------------------
        #  Clouds (darker, more ominous)
        # ------------------------------------------------------------------
        self.clouds = []
        self._cloud_surfaces = []
        for _ in range(5):
            cloud_w = random.randint(60, 130)
            cloud_h = random.randint(20, 40)
            self.clouds.append({
                'x': random.randint(-cloud_w, width),
                'y': random.randint(30, self.cy - 80),
                'w': cloud_w,
                'h': cloud_h,
                'speed': random.uniform(0.08, 0.25),
                'opacity': random.randint(20, 45),
            })
            self._cloud_surfaces.append(
                pygame.Surface((cloud_w + 20, cloud_h + 10), pygame.SRCALPHA)
            )

        # ------------------------------------------------------------------
        #  Radar Sweep
        # ------------------------------------------------------------------
        self.radar_angle = 0.0
        self.radar_speed = 0.02

        # ------------------------------------------------------------------
        #  Hologram Scanlines
        # ------------------------------------------------------------------
        self.scanline_offset = 0

        # ------------------------------------------------------------------
        #  Fire Line Particle System (subdued)
        # ------------------------------------------------------------------
        self.fire_line_particles = []
        self.fire_glow_phase = 0.0
        self.center_circle_radius = min(width, height) // 10
        self.stadium_line_y = self.cy

    # ======================================================================
    #  One-time Pre-rendering
    # ======================================================================

    def _init_gradient_caches(self):
        """Numpy-vectorized sky and ocean gradients (computed once)."""
        half_h = self.height // 2
        denom = max(half_h - 1, 1)
        factors = np.arange(half_h, dtype=np.float32) / denom

        # Sky: sky_top → horizon_color (two-stage: navy → purple → amber)
        self._sky_gradient_cache = pygame.Surface((self.width, half_h))
        arr = np.zeros((self.width, half_h, 3), dtype=np.uint8)
        # First half of sky: top → mid
        # Second half: mid → horizon
        mid_point = half_h // 2
        f1 = np.arange(mid_point, dtype=np.float32) / max(mid_point - 1, 1)
        f2 = np.arange(half_h - mid_point, dtype=np.float32) / max(half_h - mid_point - 1, 1)

        for ch in range(3):
            upper = (self.sky_top[ch] + (self.sky_mid[ch] - self.sky_top[ch]) * f1).astype(np.uint8)
            lower = (self.sky_mid[ch] + (self.horizon_color[ch] - self.sky_mid[ch]) * f2).astype(np.uint8)
            arr[:, :mid_point, ch] = upper
            arr[:, mid_point:, ch] = lower

        pygame.surfarray.blit_array(self._sky_gradient_cache, arr)

        # Ocean: ocean_surface → ocean_deep
        self._ocean_gradient_cache = pygame.Surface((self.width, half_h))
        arr2 = np.zeros((self.width, half_h, 3), dtype=np.uint8)
        for ch in range(3):
            arr2[:, :, ch] = (self.ocean_surface[ch] +
                              (self.ocean_deep[ch] - self.ocean_surface[ch]) * factors).astype(np.uint8)
        pygame.surfarray.blit_array(self._ocean_gradient_cache, arr2)

    def _init_horizon_haze(self):
        """Pre-render atmospheric haze band at horizon."""
        self._haze_surface.fill(self._transparent)
        haze_h = self._haze_surface.get_height()
        for y in range(haze_h):
            alpha = int(40 * (1.0 - abs(y - haze_h // 2) / (haze_h // 2)))
            pygame.draw.line(self._haze_surface, (180, 140, 80, alpha),
                           (0, y), (self.width, y))

    def _init_distant_ships(self):
        """Pre-render distant warship silhouettes on the horizon."""
        self._ship_surface.fill(self._transparent)
        ship_color = (25, 20, 35, 60)  # Very faint, atmospheric
        w = self.width

        # Ship 1: large carrier (left side)
        ship1_x = int(w * 0.12)
        ship1_w = int(w * 0.12)
        ship1_y = 35
        # Hull
        hull_pts = [
            (ship1_x, ship1_y),
            (ship1_x + ship1_w, ship1_y),
            (ship1_x + ship1_w - 8, ship1_y + 12),
            (ship1_x + 5, ship1_y + 12),
        ]
        pygame.draw.polygon(self._ship_surface, ship_color, hull_pts)
        # Bridge tower
        bridge_x = ship1_x + ship1_w // 3
        pygame.draw.rect(self._ship_surface, ship_color,
                        (bridge_x, ship1_y - 18, 15, 18))
        pygame.draw.rect(self._ship_surface, ship_color,
                        (bridge_x + 3, ship1_y - 25, 8, 7))
        # Antenna
        pygame.draw.line(self._ship_surface, ship_color,
                        (bridge_x + 7, ship1_y - 25), (bridge_x + 7, ship1_y - 35), 1)

        # Ship 2: destroyer (right side)
        ship2_x = int(w * 0.75)
        ship2_w = int(w * 0.08)
        ship2_y = 38
        hull_pts2 = [
            (ship2_x, ship2_y),
            (ship2_x + ship2_w, ship2_y),
            (ship2_x + ship2_w + 5, ship2_y + 8),
            (ship2_x - 3, ship2_y + 8),
        ]
        pygame.draw.polygon(self._ship_surface, ship_color, hull_pts2)
        pygame.draw.rect(self._ship_surface, ship_color,
                        (ship2_x + ship2_w // 3, ship2_y - 12, 10, 12))

        # Ship 3: small vessel (far right, barely visible)
        ship3_x = int(w * 0.9)
        pygame.draw.rect(self._ship_surface, (20, 18, 30, 35),
                        (ship3_x, 40, int(w * 0.04), 5))
        pygame.draw.rect(self._ship_surface, (20, 18, 30, 35),
                        (ship3_x + 8, 34, 4, 6))

    def _init_platform_static(self):
        """Pre-render the static multi-deck arena platform."""
        surf = self._platform_surface
        surf.fill(self._transparent)
        w = self.width
        # Platform is drawn relative to a local coordinate space
        # It will be blit at platform_y offset during draw()
        # Local y=0 corresponds to the top of the platform area

        base_y = surf.get_height() // 2  # Center of platform surface
        deck_w = int(w * 0.55)           # Main deck width
        deck_x = (w - deck_w) // 2       # Centered

        upper_w = int(w * 0.38)          # Upper deck width
        upper_x = (w - upper_w) // 2

        ring_w = int(w * 0.65)           # Outer ring width
        ring_x = (w - ring_w) // 2

        # --- Outer Ring (elliptical frame around arena) ---
        pygame.draw.ellipse(surf, self.gunmetal_edge,
                          (ring_x, base_y - 8, ring_w, 30), 2)
        # Neon accent on ring (thin)
        pygame.draw.ellipse(surf, (*self.cyan_dim, 60),
                          (ring_x + 2, base_y - 6, ring_w - 4, 26), 1)

        # --- Main Deck (trapezoid shape for perspective) ---
        deck_inset = 15  # Top edge is narrower than bottom
        deck_h = 28
        deck_pts = [
            (deck_x + deck_inset, base_y - deck_h // 2),          # top-left
            (deck_x + deck_w - deck_inset, base_y - deck_h // 2), # top-right
            (deck_x + deck_w, base_y + deck_h // 2),              # bottom-right
            (deck_x, base_y + deck_h // 2),                       # bottom-left
        ]
        pygame.draw.polygon(surf, self.gunmetal, deck_pts)
        pygame.draw.polygon(surf, self.gunmetal_edge, deck_pts, 1)
        # Cyan edge line (top edge only - neon strip)
        pygame.draw.line(surf, (*self.cyan_accent, 120),
                        deck_pts[0], deck_pts[1], 1)

        # --- Upper Deck (narrower tier) ---
        upper_h = 12
        upper_pts = [
            (upper_x + 8, base_y - deck_h // 2 - upper_h),
            (upper_x + upper_w - 8, base_y - deck_h // 2 - upper_h),
            (upper_x + upper_w, base_y - deck_h // 2),
            (upper_x, base_y - deck_h // 2),
        ]
        pygame.draw.polygon(surf, self.gunmetal_light, upper_pts)
        pygame.draw.polygon(surf, self.gunmetal_edge, upper_pts, 1)

        # --- Crowd Silhouette bumps (on upper deck edges) ---
        crowd_y = base_y - deck_h // 2 - upper_h
        for i in range(12):
            bx = upper_x + 15 + i * ((upper_w - 30) // 12)
            bh = random.randint(3, 6)
            pygame.draw.rect(surf, (25, 28, 40), (bx, crowd_y - bh, 4, bh))

        # --- Antenna Towers (two sides) ---
        tower_h = 45
        # Left tower
        lt_x = deck_x + 20
        lt_base_y = base_y - deck_h // 2 - upper_h
        pygame.draw.line(surf, self.gunmetal_edge,
                        (lt_x, lt_base_y), (lt_x, lt_base_y - tower_h), 2)
        pygame.draw.line(surf, self.gunmetal_edge,
                        (lt_x - 5, lt_base_y - tower_h + 10),
                        (lt_x + 5, lt_base_y - tower_h + 10), 1)
        # Tower top light (cyan dot)
        pygame.draw.circle(surf, self.cyan_accent, (lt_x, lt_base_y - tower_h), 2)

        # Right tower
        rt_x = deck_x + deck_w - 20
        pygame.draw.line(surf, self.gunmetal_edge,
                        (rt_x, lt_base_y), (rt_x, lt_base_y - tower_h), 2)
        pygame.draw.line(surf, self.gunmetal_edge,
                        (rt_x - 5, lt_base_y - tower_h + 10),
                        (rt_x + 5, lt_base_y - tower_h + 10), 1)
        pygame.draw.circle(surf, self.cyan_accent, (rt_x, lt_base_y - tower_h), 2)

        # --- Central Antenna (taller, main radar mast) ---
        center_tower_h = 55
        ct_base_y = base_y - deck_h // 2 - upper_h
        pygame.draw.line(surf, self.gunmetal_edge,
                        (self.cx, ct_base_y), (self.cx, ct_base_y - center_tower_h), 2)
        # Radar dish (small triangle)
        dish_y = ct_base_y - center_tower_h + 8
        pygame.draw.polygon(surf, self.gunmetal_edge, [
            (self.cx - 8, dish_y),
            (self.cx + 8, dish_y),
            (self.cx, dish_y - 6),
        ])
        # Top beacon
        pygame.draw.circle(surf, (255, 60, 40), (self.cx, ct_base_y - center_tower_h), 2)

        # --- Support Struts (hanging below deck into water) ---
        strut_count = 5
        for i in range(strut_count):
            sx = deck_x + (deck_w // (strut_count + 1)) * (i + 1)
            pygame.draw.line(surf, (20, 25, 40, 150),
                           (sx, base_y + deck_h // 2),
                           (sx, base_y + deck_h // 2 + 25), 2)

        # --- Neon Panel Accents (thin horizontal strips on deck face) ---
        panel_y = base_y + 2
        for i in range(3):
            py = panel_y + i * 6
            px1 = deck_x + 30 + i * 20
            px2 = deck_x + deck_w - 30 - i * 20
            pygame.draw.line(surf, (*self.cyan_accent, 50 + i * 20),
                           (px1, py), (px2, py), 1)

        # Store measurements for radar sweep reference
        self._platform_base_y_local = base_y
        self._platform_deck_h = deck_h
        self._platform_upper_h = upper_h
        self._center_tower_h = center_tower_h

    # ======================================================================
    #  Update
    # ======================================================================

    def update(self):
        """Advance all animation state by one frame."""
        self.time += 1
        self.fire_glow_phase += 0.04  # Slightly slower pulsation
        self.radar_angle += self.radar_speed
        self.scanline_offset = (self.scanline_offset + 1) % self.height

        # Background waves
        for wave in self.bg_waves:
            wave['phase'] += wave['speed']

        # Foreground waves
        for wave in self.fg_waves:
            wave['phase'] += wave['speed']

        # Cloud drift
        for cloud in self.clouds:
            cloud['x'] += cloud['speed']
            if cloud['x'] > self.width + cloud['w']:
                cloud['x'] = -cloud['w'] - random.randint(0, 50)
                cloud['y'] = random.randint(30, self.cy - 80)

        # Fire particles
        self._update_fire_lines()

    # ======================================================================
    #  Draw (composites all layers)
    # ======================================================================

    def draw(self, screen):
        """
        Render complete background with 3-layer depth separation.

        Far:   sky gradient → distant ships → clouds → horizon haze
        Mid:   ocean gradient → bg waves → platform shadow → arena → radar → fire
        Near:  foreground waves → hologram scanlines → border
        """
        # --- FAR LAYER ---
        screen.blit(self._sky_gradient_cache, (0, 0))
        screen.blit(self._ship_surface, (0, self.cy - 60))
        self._draw_clouds(screen)
        screen.blit(self._haze_surface, (0, self.cy - 20))

        # Horizon line (subtle, warm)
        pygame.draw.line(screen, (*self.horizon_color, 180),
                        (0, self.cy), (self.width, self.cy), 1)

        # --- MID LAYER ---
        screen.blit(self._ocean_gradient_cache, (0, self.cy))
        self._draw_waves(screen, self.bg_waves, self._wave_surface, alpha=35)

        # Platform
        platform_y = self.cy - self._platform_surface.get_height() // 2 + 30
        self._draw_platform_shadow(screen, platform_y)
        screen.blit(self._platform_surface, (0, platform_y))
        self._draw_radar_sweep(screen, platform_y)

        # Fire lines (subdued - drawn after platform so it's on top but not dominant)
        self._draw_fire_lines(screen)

        # --- NEAR LAYER ---
        self._draw_waves(screen, self.fg_waves, self._fg_wave_surface,
                        alpha=55, circle_r=12, step=6, foam_interval=60)
        self._draw_scanlines(screen)
        self._draw_border(screen)

    # ======================================================================
    #  Layer Renderers
    # ======================================================================

    def _draw_clouds(self, screen):
        """Dark ominous clouds with elongated shapes."""
        for idx, cloud in enumerate(self.clouds):
            surf = self._cloud_surfaces[idx]
            surf.fill(self._transparent)
            cw, ch = cloud['w'], cloud['h']
            opacity = cloud['opacity']
            # Elongated ellipse cloud shape
            pygame.draw.ellipse(surf, (20, 20, 30, opacity),
                              (5, 3, cw, ch))
            # Slightly brighter core
            inner_w = cw * 2 // 3
            inner_x = 5 + (cw - inner_w) // 2
            pygame.draw.ellipse(surf, (30, 30, 45, opacity // 2),
                              (inner_x, 5, inner_w, ch - 4))
            screen.blit(surf, (int(cloud['x']), cloud['y']))

    def _draw_waves(self, screen, wave_list, surface, alpha=40,
                    circle_r=8, step=8, foam_interval=80):
        """Animated sine-wave ocean layer (reusable for bg/fg)."""
        ocean_color = (*self.ocean_surface, alpha)
        foam_color = (*self.wave_foam, alpha + 15)
        w = self.width

        for wave in wave_list:
            surface.fill(self._transparent)
            amp = wave['amplitude']
            freq = wave['frequency']
            phase = wave['phase']

            for x in range(0, w, step):
                y = surface.get_height() // 2 + amp * math.sin(x * freq + phase)
                iy = int(y)
                pygame.draw.circle(surface, ocean_color, (x, iy), circle_r)
                if foam_interval > 0 and x % foam_interval < step:
                    pygame.draw.circle(surface, foam_color, (x, iy - 4), 3)

            screen.blit(surface, (0, wave['y']))

    def _draw_platform_shadow(self, screen, platform_y):
        """Dark shadow ellipse on the ocean surface below the arena."""
        self._shadow_surface.fill(self._transparent)
        shadow_w = int(self.width * 0.5)
        shadow_x = (self.width - shadow_w) // 2
        base_y = self._platform_base_y_local + self._platform_deck_h // 2
        pygame.draw.ellipse(self._shadow_surface, (0, 0, 0, 25),
                          (shadow_x, 15, shadow_w, 50))
        screen.blit(self._shadow_surface, (0, platform_y + base_y + 30))

    def _draw_radar_sweep(self, screen, platform_y):
        """Rotating radar scan beam from the central antenna."""
        # Radar origin: top of center antenna
        origin_y = (platform_y + self._platform_base_y_local
                    - self._platform_deck_h // 2
                    - self._platform_upper_h
                    - self._center_tower_h)
        origin_x = self.cx

        sweep_len = min(self.width, self.height) // 4
        end_x = origin_x + math.cos(self.radar_angle) * sweep_len
        end_y = origin_y + math.sin(self.radar_angle) * sweep_len * 0.4  # Elliptical

        # Sweep beam (faint cyan triangle)
        sweep_surface = _get_cached_surface(self.width, self.height)
        spread = 12
        perp_x = -math.sin(self.radar_angle) * spread
        perp_y = math.cos(self.radar_angle) * spread * 0.4

        pts = [
            (int(origin_x), int(origin_y)),
            (int(end_x + perp_x), int(end_y + perp_y)),
            (int(end_x - perp_x), int(end_y - perp_y)),
        ]
        pygame.draw.polygon(sweep_surface, (*self.cyan_accent, 12), pts)
        pygame.draw.line(sweep_surface, (*self.cyan_accent, 30),
                        (int(origin_x), int(origin_y)),
                        (int(end_x), int(end_y)), 1)
        screen.blit(sweep_surface, (0, 0))

    def _draw_scanlines(self, screen):
        """Faint horizontal hologram interference lines."""
        self._scanline_surface.fill(self._transparent)
        # Draw every 6th line for a subtle CRT/hologram feel
        for y in range(self.scanline_offset % 6, self.height, 6):
            alpha = 8 + int(4 * math.sin(y * 0.05 + self.time * 0.03))
            pygame.draw.line(self._scanline_surface, (0, 200, 220, alpha),
                           (0, y), (self.width, y))
        screen.blit(self._scanline_surface, (0, 0))

    def _draw_border(self, screen):
        """
        Thin, non-intrusive neon border.
        4px outer + 1px cyan inner accent. Corners: small dots.
        """
        t = 4  # Much thinner than original 10px
        w, h = self.width, self.height
        base = (10, 15, 30)     # Nearly invisible dark frame
        accent = (*self.cyan_dim, 100)  # Subtle cyan

        # Outer frame
        pygame.draw.rect(screen, base, (0, 0, w, t))
        pygame.draw.rect(screen, base, (0, h - t, w, t))
        pygame.draw.rect(screen, base, (0, 0, t, h))
        pygame.draw.rect(screen, base, (w - t, 0, t, h))

        # Inner accent line
        pygame.draw.rect(screen, accent, (t, t, w - 2 * t, 1))
        pygame.draw.rect(screen, accent, (t, h - t - 1, w - 2 * t, 1))
        pygame.draw.rect(screen, accent, (t, t, 1, h - 2 * t))
        pygame.draw.rect(screen, accent, (w - t - 1, t, 1, h - 2 * t))

        # Corner dots (tiny)
        for cx, cy in [(t, t), (w - t, t), (t, h - t), (w - t, h - t)]:
            pygame.draw.circle(screen, self.cyan_accent, (cx, cy), 2)

    # ======================================================================
    #  Fire Line Particle System (subdued intensity)
    # ======================================================================

    def _update_fire_lines(self):
        """Spawn and update fire particles along midfield lines."""
        if random.random() < 0.2:  # Lower spawn rate (was 0.3)
            angle = random.uniform(0, math.pi * 2)
            x = self.cx + math.cos(angle) * self.center_circle_radius
            y = self.stadium_line_y + math.sin(angle) * self.center_circle_radius
            self._create_fire_particle(x, y)

            if random.random() < 0.4:
                x = random.randint(self.width // 6, self.width * 5 // 6)
                self._create_fire_particle(x, self.stadium_line_y)

        for particle in self.fire_line_particles[:]:
            particle['y'] -= particle['vy']
            particle['x'] += particle['vx']
            particle['life'] -= 1
            particle['size'] *= 0.94

            if particle['life'] <= 0 or particle['size'] < 0.5:
                self.fire_line_particles.remove(particle)

    def _create_fire_particle(self, x, y):
        """Create a fire particle (max 80, reduced from 100)."""
        if len(self.fire_line_particles) < 80:
            self.fire_line_particles.append({
                'x': x, 'y': y,
                'vx': random.uniform(-0.4, 0.4),
                'vy': random.uniform(0.4, 1.5),
                'size': random.uniform(1.5, 3.5),
                'life': random.randint(15, 35),
                'color': random.choice(self.fire_colors),
                'glow': random.uniform(0.5, 0.9),
            })

    def _draw_fire_lines(self, screen):
        """Burning midfield lines with glow (subdued to not overpower arena)."""
        glow = (math.sin(self.fire_glow_phase) + 1) * 0.25 + 0.35  # 0.35~0.85

        # Center circle glow (2 layers instead of 3)
        for i in range(2):
            alpha = int(18 * glow * (1 - i * 0.4))
            radius = self.center_circle_radius + i * 2
            color = (180 + int(55 * glow), 50 + int(30 * glow), 15)

            gs = radius * 2 + 16
            glow_surface = _get_cached_surface(gs, gs)
            pygame.draw.circle(glow_surface, (*color, alpha),
                             (radius + 8, radius + 8), radius, 2 + i)
            screen.blit(glow_surface, (self.cx - radius - 8,
                                       self.stadium_line_y - radius - 8))

        # Circle outline
        main_color = (230, int(80 + 40 * glow), 40)
        pygame.draw.circle(screen, main_color,
                          (self.cx, self.stadium_line_y),
                          self.center_circle_radius, 1)

        # Dashed midfield line
        dash_len = 18
        gap_len = 14
        margin = self.width // 6
        current_x = margin
        while current_x < self.width - margin:
            dash_end = min(current_x + dash_len, self.width - margin)
            # Single glow pass (was 2)
            alpha = int(15 * glow)
            gs = _get_cached_surface(dash_len + 8, 8)
            color = (180 + int(55 * glow), 50 + int(30 * glow), 15)
            pygame.draw.line(gs, (*color, alpha), (4, 4), (dash_len + 4, 4), 2)
            screen.blit(gs, (current_x - 4, self.stadium_line_y - 4))

            pygame.draw.line(screen, main_color,
                           (current_x, self.stadium_line_y),
                           (dash_end, self.stadium_line_y), 1)
            current_x += dash_len + gap_len

        # Fire particles
        for p in self.fire_line_particles:
            ga = int(p['glow'] * p['life'] * 1.2)
            if ga > 0:
                gs_size = max(1, int(p['size'] * 1.5) * 2)
                gs = _get_cached_surface(gs_size, gs_size)
                center = gs_size // 2
                pygame.draw.circle(gs, (*p['color'], min(ga, 80)),
                                 (center, center), center)
                screen.blit(gs, (p['x'] - center, p['y'] - center))
            pygame.draw.circle(screen, p['color'],
                             (int(p['x']), int(p['y'])), int(p['size']))
