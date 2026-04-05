# -*- coding: utf-8 -*-
"""
============================================================================
 PingFighter — Stage 5 Nemesis: Ocean Cyberpunk Arena Background
============================================================================

 An animated background system for a Pygame arcade game's boss battle.
 Theme: "Damaged battleship arena floating over a stormy ocean at dusk"

 ┌──────────────────────────────────────────────────────────────┐
 │  RENDERING STACK (back → front, 16 layers)                  │
 │                                                              │
 │  FAR ─────────────────────────────────────────────────────── │
 │   1. Sky gradient        numpy-cached dusk (navy→indigo→amber)│
 │   2. Distant warships    3 pre-rendered silhouettes          │
 │   3. Storm clouds        5 drifting dark ellipses            │
 │   4. Horizon haze        atmospheric fog band                │
 │   5. Ship nav lights     4 blinking lights (per-ship phase)  │
 │   6. Horizon line        subtle warm amber line              │
 │                                                              │
 │  MID ─────────────────────────────────────────────────────── │
 │   7. Ocean gradient      numpy-cached deep indigo            │
 │   8. Background waves    5 small sine-wave layers            │
 │   9. Platform shadow     dark ellipse on water surface       │
 │  10. Water reflection    cyan + orange flicker beneath arena │
 │  11. Floating arena      multi-deck stadium (pre-rendered)   │
 │  12. Pulsating beacon    red glow on central antenna tip     │
 │  13. Radar sweep         rotating scan beam from antenna     │
 │  14. Fire lines          burning midfield + particles        │
 │                                                              │
 │  NEAR ────────────────────────────────────────────────────── │
 │  15. Foreground waves    2 large sine-wave layers            │
 │  16. Hologram scanlines  horizontal CRT interference         │
 │  17. Border              4px thin neon trim                  │
 │                                                              │
 │  ASYMMETRY: Right antenna tower is broken (30px vs left 45px)│
 │  with tilted tip, debris fragments, and an orange spark.     │
 │  This breaks visual symmetry and adds narrative tension —    │
 │  the arena has been through combat before you arrived.       │
 └──────────────────────────────────────────────────────────────┘

 PERFORMANCE STRATEGY
 ────────────────────
 • Gradients: numpy vectorized → 2 surface blits (was ~374 draw.rect)
 • Static elements (ships, platform, haze): pre-rendered once in __init__
 • Reusable surfaces: 9 pre-allocated, cleared each frame (no alloc)
 • Glow cache: OrderedDict LRU (evicts oldest, not full clear)
 • Waves: deterministic foam (no per-frame random in draw)
 • Fire particles: capped at 80, spawn rate 20%
 • Beacon/lights: pure math (sin), no surface allocation

 RESOLUTION: 760×750 (full game area including pillar overlays)
============================================================================
"""

import pygame
import pygame.surfarray
import math
import random
import numpy as np
from collections import OrderedDict


# ============================================================================
#  Surface Cache — OrderedDict LRU
# ============================================================================
# Reusable transparent surfaces keyed by (width, height).
# When capacity (100) is exceeded, only the OLDEST entry is evicted
# (not a full clear — prevents the frame-stutter spike the old dict
# approach caused when 101+ unique sizes were requested).

_surface_cache = OrderedDict()

def _get_cached_surface(width: int, height: int) -> pygame.Surface:
    """Return a cleared SRCALPHA surface from the LRU cache."""
    key = (width, height)
    if key not in _surface_cache:
        if len(_surface_cache) > 100:
            _surface_cache.popitem(last=False)   # evict oldest only
        _surface_cache[key] = pygame.Surface((width, height), pygame.SRCALPHA)
    else:
        _surface_cache.move_to_end(key)          # mark as recently used
    surface = _surface_cache[key]
    surface.fill((0, 0, 0, 0))
    return surface


# ============================================================================
#  Constants (imported from game config, with fallback)
# ============================================================================

try:
    from config.constants import PILLAR_UI_WIDTH, GAME_PLAY_WIDTH, SCREEN_HEIGHT
    PILLAR_OFFSET = PILLAR_UI_WIDTH   # 80px — decorative pillar width
    GAME_WIDTH    = GAME_PLAY_WIDTH   # 600px — central play area
    HEIGHT        = SCREEN_HEIGHT     # 750px — full screen height
except ImportError:
    PILLAR_OFFSET = 80
    GAME_WIDTH    = 600
    HEIGHT        = 750


# ============================================================================
#  AnimatedBackgroundStage6 — Nemesis Ocean Arena
# ============================================================================

class AnimatedBackgroundStage6:
    """
    Animated background for Stage 5 (Nemesis — Ocean Battleship).

    Design principles:
      • Strong central silhouette — multi-deck arena, not a flat rectangle
      • Asymmetric damage — right tower broken, adding narrative tension
      • 3-layer depth — foreground waves / midground arena / background sky
      • Narrative details — distant warships with blinking lights,
        pulsating red beacon, water reflections, radar sweep
      • Subdued border — frames without competing with the scene
      • Cyan neon as accent only — platform body in dark gunmetal

    Public API:
      __init__(width, height)   Pre-allocates all surfaces + caches
      update()                  Advances animation state (call once/frame)
      draw(screen)              Composites all layers onto screen
    """

    def __init__(self, width, height):
        self.width  = width
        self.height = height
        self.time   = 0
        self.cx     = width  // 2     # center x
        self.cy     = height // 2     # center y (= midfield line)

        # ==================================================================
        #  Color Palette — darker & more dramatic than the original
        # ==================================================================

        # Sky: stormy dusk
        self.sky_top       = (15,  20,  45)    # deep navy (top)
        self.sky_mid       = (40,  35,  65)    # indigo-purple (mid)
        self.horizon_color = (180, 120, 60)    # muted amber sunset

        # Ocean: deep and threatening
        self.ocean_surface = (10,  40,  80)    # dark navy
        self.ocean_deep    = (5,   15,  40)    # abyss
        self.wave_foam     = (180, 200, 220)   # cold white foam

        # Neon accents — used sparingly
        self.cyan_accent   = (0, 180, 220)     # bright cyan (edges only)
        self.cyan_dim      = (0,  80, 110)     # dimmed cyan (secondary)

        # Platform body — dark gunmetal tones
        self.gunmetal       = (30, 35, 50)     # main deck fill
        self.gunmetal_light = (45, 50, 65)     # upper deck (lighter tier)
        self.gunmetal_edge  = (55, 60, 75)     # edge highlight / outlines

        # Fire — toned down from original
        self.fire_colors = [
            (255, 100, 50),   # bright orange
            (255,  80, 30),   # deep orange
            (200,  60, 20),   # red-orange
            (150,  40, 10),   # dark red
        ]

        # ==================================================================
        #  Pre-allocated Render Surfaces (avoid per-frame allocation)
        # ==================================================================

        self._glow_surface      = pygame.Surface((width, height),      pygame.SRCALPHA)
        self._wave_surface      = pygame.Surface((width, 50),          pygame.SRCALPHA)
        self._fg_wave_surface   = pygame.Surface((width, 60),          pygame.SRCALPHA)
        self._shadow_surface    = pygame.Surface((width, 80),          pygame.SRCALPHA)
        self._platform_surface  = pygame.Surface((width, height // 3), pygame.SRCALPHA)
        self._haze_surface      = pygame.Surface((width, 40),          pygame.SRCALPHA)
        self._ship_surface      = pygame.Surface((width, 60),          pygame.SRCALPHA)
        self._scanline_surface  = pygame.Surface((width, height),      pygame.SRCALPHA)
        self._reflection_surface = pygame.Surface((width, 30),         pygame.SRCALPHA)
        self._transparent       = (0, 0, 0, 0)

        # ==================================================================
        #  Gradient Caches (numpy-optimized, computed once)
        # ==================================================================

        self._sky_gradient_cache   = None
        self._ocean_gradient_cache = None
        self._init_gradient_caches()

        # ==================================================================
        #  Static Elements (pre-rendered once)
        # ==================================================================

        self._init_horizon_haze()
        self._init_distant_ships()
        self._init_platform_static()

        # ==================================================================
        #  Background Waves — 5 layers, small amplitude (distant feel)
        # ==================================================================

        self.bg_waves = []
        for i in range(5):
            self.bg_waves.append({
                'y':         self.cy + 20 + i * 25,
                'amplitude': random.uniform(3, 8),
                'frequency': random.uniform(0.01, 0.025),
                'phase':     random.uniform(0, math.pi * 2),
                'speed':     random.uniform(0.015, 0.03),
            })

        # ==================================================================
        #  Foreground Waves — 2 layers, large amplitude (depth separation)
        # ==================================================================

        self.fg_waves = []
        for i in range(2):
            self.fg_waves.append({
                'y':         height - 80 + i * 35,
                'amplitude': random.uniform(8, 18),
                'frequency': random.uniform(0.008, 0.02),
                'phase':     random.uniform(0, math.pi * 2),
                'speed':     random.uniform(0.025, 0.045),
            })

        # ==================================================================
        #  Clouds — 5 dark, ominous storm clouds
        # ==================================================================

        self.clouds = []
        self._cloud_surfaces = []
        for _ in range(5):
            cloud_w = random.randint(60, 130)
            cloud_h = random.randint(20, 40)
            self.clouds.append({
                'x':       random.randint(-cloud_w, width),
                'y':       random.randint(30, self.cy - 80),
                'w':       cloud_w,
                'h':       cloud_h,
                'speed':   random.uniform(0.08, 0.25),
                'opacity': random.randint(20, 45),
            })
            self._cloud_surfaces.append(
                pygame.Surface((cloud_w + 20, cloud_h + 10), pygame.SRCALPHA)
            )

        # ==================================================================
        #  Animated Systems
        # ==================================================================

        self.radar_angle      = 0.0
        self.radar_speed      = 0.02     # radians/frame
        self.beacon_phase     = 0.0      # red beacon pulsation
        self.ship_light_phase = 0.0      # distant ship nav lights
        self.scanline_offset  = 0

        # ==================================================================
        #  Fire Line Particle System — subdued intensity
        # ==================================================================

        self.fire_line_particles  = []
        self.fire_glow_phase      = 0.0
        self.center_circle_radius = min(width, height) // 10   # resolution-independent
        self.stadium_line_y       = self.cy                    # midfield Y

    # ======================================================================
    #  ONE-TIME PRE-RENDERING
    # ======================================================================

    def _init_gradient_caches(self):
        """
        Pre-render sky and ocean gradients via numpy array operations.

        Sky uses a two-stage gradient (navy → indigo → amber) for a
        more dramatic dusk feel than a simple linear interpolation.

        Eliminates ~374 per-frame draw.rect calls → 2 surface blits.
        """
        half_h = self.height // 2
        denom  = max(half_h - 1, 1)
        factors = np.arange(half_h, dtype=np.float32) / denom

        # --- Sky: two-stage gradient ---
        self._sky_gradient_cache = pygame.Surface((self.width, half_h))
        arr = np.zeros((self.width, half_h, 3), dtype=np.uint8)

        mid_point = half_h // 2
        f1 = np.arange(mid_point, dtype=np.float32) / max(mid_point - 1, 1)
        f2 = np.arange(half_h - mid_point, dtype=np.float32) / max(half_h - mid_point - 1, 1)

        for ch in range(3):
            upper = (self.sky_top[ch] + (self.sky_mid[ch] - self.sky_top[ch]) * f1).astype(np.uint8)
            lower = (self.sky_mid[ch] + (self.horizon_color[ch] - self.sky_mid[ch]) * f2).astype(np.uint8)
            arr[:, :mid_point, ch] = upper
            arr[:, mid_point:, ch] = lower

        pygame.surfarray.blit_array(self._sky_gradient_cache, arr)

        # --- Ocean: linear gradient ---
        self._ocean_gradient_cache = pygame.Surface((self.width, half_h))
        arr2 = np.zeros((self.width, half_h, 3), dtype=np.uint8)
        for ch in range(3):
            arr2[:, :, ch] = (
                self.ocean_surface[ch]
                + (self.ocean_deep[ch] - self.ocean_surface[ch]) * factors
            ).astype(np.uint8)
        pygame.surfarray.blit_array(self._ocean_gradient_cache, arr2)

    def _init_horizon_haze(self):
        """
        Pre-render an atmospheric haze band at the horizon.
        Alpha peaks at center and fades to edges — creates a soft
        sky/ocean separation without a hard line.
        """
        self._haze_surface.fill(self._transparent)
        haze_h = self._haze_surface.get_height()
        for y in range(haze_h):
            alpha = int(40 * (1.0 - abs(y - haze_h // 2) / (haze_h // 2)))
            pygame.draw.line(self._haze_surface, (180, 140, 80, alpha),
                           (0, y), (self.width, y))

    def _init_distant_ships(self):
        """
        Pre-render distant warship silhouettes on the horizon.
        Three ships at different scales create parallax depth:
          • Ship 1 (left):  large carrier with bridge tower + antenna
          • Ship 2 (right): destroyer with bridge
          • Ship 3 (far right): tiny vessel, barely visible

        All drawn in very faint colors (alpha 35–60) for atmospheric
        distance. Navigation lights are drawn separately in _draw_ship_lights()
        since they need per-frame animation (blinking).
        """
        self._ship_surface.fill(self._transparent)
        ship_color = (25, 20, 35, 60)
        w = self.width

        # Ship 1: carrier (left side, 12% of screen width)
        s1x = int(w * 0.12)
        s1w = int(w * 0.12)
        s1y = 35
        pygame.draw.polygon(self._ship_surface, ship_color, [
            (s1x, s1y), (s1x + s1w, s1y),
            (s1x + s1w - 8, s1y + 12), (s1x + 5, s1y + 12),
        ])
        bx = s1x + s1w // 3
        pygame.draw.rect(self._ship_surface, ship_color, (bx, s1y - 18, 15, 18))
        pygame.draw.rect(self._ship_surface, ship_color, (bx + 3, s1y - 25, 8, 7))
        pygame.draw.line(self._ship_surface, ship_color,
                        (bx + 7, s1y - 25), (bx + 7, s1y - 35), 1)

        # Ship 2: destroyer (right side, 8% width)
        s2x = int(w * 0.75)
        s2w = int(w * 0.08)
        s2y = 38
        pygame.draw.polygon(self._ship_surface, ship_color, [
            (s2x, s2y), (s2x + s2w, s2y),
            (s2x + s2w + 5, s2y + 8), (s2x - 3, s2y + 8),
        ])
        pygame.draw.rect(self._ship_surface, ship_color,
                        (s2x + s2w // 3, s2y - 12, 10, 12))

        # Ship 3: small vessel (far right, barely visible)
        s3x = int(w * 0.9)
        faint = (20, 18, 30, 35)
        pygame.draw.rect(self._ship_surface, faint, (s3x, 40, int(w * 0.04), 5))
        pygame.draw.rect(self._ship_surface, faint, (s3x + 8, 34, 4, 6))

    def _init_platform_static(self):
        """
        Pre-render the multi-deck cyberpunk arena platform.

        Structure (top to bottom):
          ╭── Central antenna (70px tall, 2-stage mast + radar dish + crossbar)
          │   Left antenna tower (45px, intact, cyan top light)
          │   Right antenna tower (30px, BROKEN — tilted tip + debris + spark)
          │   Crowd silhouette bumps (12 random-height blocks)
          ├── Upper deck (trapezoid, lighter gunmetal, 38% width)
          ├── Main deck (trapezoid, dark gunmetal, 55% width)
          │   Cyan neon strip on top edge
          │   3 neon panel accent lines on face
          ├── Outer ring (elliptical frame, 65% width)
          │   Dimmed cyan accent on ring
          ├── Support struts (5 vertical lines)
          ├── Horizontal beam connecting struts
          └── X-brace reinforcement (structural weight)

        The right tower is deliberately broken (30px vs left 45px)
        with a tilted tip, debris lines, and an orange spark dot.
        This asymmetry is the "signature element" that makes the
        arena feel battle-scarred — Nemesis has been here before.

        The central tower is taller (70px vs original 55px) with a
        2-stage structure: thick base column (3px) + thin mast (2px),
        larger radar dish, and a structural crossbar at mid-height.
        The red beacon at the top is animated in _draw_beacon().

        All coordinates use proportional widths (% of screen width)
        for resolution independence.
        """
        surf = self._platform_surface
        surf.fill(self._transparent)
        w = self.width

        base_y  = surf.get_height() // 2    # vertical center of surface
        deck_w  = int(w * 0.55)              # main deck width
        deck_x  = (w - deck_w) // 2          # centered

        upper_w = int(w * 0.38)              # upper deck width
        upper_x = (w - upper_w) // 2

        ring_w  = int(w * 0.65)              # outer ring width
        ring_x  = (w - ring_w) // 2

        # --- Outer ring (elliptical frame) ---
        pygame.draw.ellipse(surf, self.gunmetal_edge,
                          (ring_x, base_y - 8, ring_w, 30), 2)
        pygame.draw.ellipse(surf, (*self.cyan_dim, 60),
                          (ring_x + 2, base_y - 6, ring_w - 4, 26), 1)

        # --- Main deck (trapezoid for perspective) ---
        deck_inset = 15
        deck_h     = 28
        deck_pts   = [
            (deck_x + deck_inset, base_y - deck_h // 2),
            (deck_x + deck_w - deck_inset, base_y - deck_h // 2),
            (deck_x + deck_w, base_y + deck_h // 2),
            (deck_x, base_y + deck_h // 2),
        ]
        pygame.draw.polygon(surf, self.gunmetal, deck_pts)
        pygame.draw.polygon(surf, self.gunmetal_edge, deck_pts, 1)
        pygame.draw.line(surf, (*self.cyan_accent, 120),
                        deck_pts[0], deck_pts[1], 1)  # neon top edge

        # --- Upper deck (narrower tier) ---
        upper_h  = 12
        upper_pts = [
            (upper_x + 8, base_y - deck_h // 2 - upper_h),
            (upper_x + upper_w - 8, base_y - deck_h // 2 - upper_h),
            (upper_x + upper_w, base_y - deck_h // 2),
            (upper_x, base_y - deck_h // 2),
        ]
        pygame.draw.polygon(surf, self.gunmetal_light, upper_pts)
        pygame.draw.polygon(surf, self.gunmetal_edge, upper_pts, 1)

        # --- Crowd silhouette bumps ---
        crowd_y = base_y - deck_h // 2 - upper_h
        for i in range(12):
            bx = upper_x + 15 + i * ((upper_w - 30) // 12)
            bh = random.randint(3, 6)
            pygame.draw.rect(surf, (25, 28, 40), (bx, crowd_y - bh, 4, bh))

        # --- Left antenna tower (intact) ---
        tower_h   = 45
        lt_x      = deck_x + 20
        lt_base_y = crowd_y
        pygame.draw.line(surf, self.gunmetal_edge,
                        (lt_x, lt_base_y), (lt_x, lt_base_y - tower_h), 2)
        pygame.draw.line(surf, self.gunmetal_edge,
                        (lt_x - 5, lt_base_y - tower_h + 10),
                        (lt_x + 5, lt_base_y - tower_h + 10), 1)
        pygame.draw.circle(surf, self.cyan_accent, (lt_x, lt_base_y - tower_h), 2)

        # --- Right antenna tower (BROKEN — asymmetric signature element) ---
        rt_x           = deck_x + deck_w - 20
        broken_tower_h = 30  # shorter than left (45px)
        # Main shaft (up to break point only)
        pygame.draw.line(surf, self.gunmetal_edge,
                        (rt_x, lt_base_y), (rt_x, lt_base_y - broken_tower_h), 2)
        # Tilted upper section (~15° lean)
        broken_tip_x = rt_x + 8
        broken_tip_y = lt_base_y - broken_tower_h - 10
        pygame.draw.line(surf, (40, 40, 55),
                        (rt_x, lt_base_y - broken_tower_h),
                        (broken_tip_x, broken_tip_y), 2)
        # Debris fragments (small line shards)
        pygame.draw.line(surf, (35, 35, 50),
                        (rt_x + 2, lt_base_y - broken_tower_h + 3),
                        (rt_x + 6, lt_base_y - broken_tower_h - 2), 1)
        # Orange spark at break point
        pygame.draw.circle(surf, (200, 80, 30),
                         (rt_x, lt_base_y - broken_tower_h), 2)

        # --- Central antenna (70px, 2-stage mast — tallest, most dramatic) ---
        center_tower_h = 70
        ct_base_y      = crowd_y
        # Thick base column (lower 25px)
        pygame.draw.line(surf, self.gunmetal_edge,
                        (self.cx, ct_base_y), (self.cx, ct_base_y - 25), 3)
        # Thin mast (upper section)
        pygame.draw.line(surf, self.gunmetal_edge,
                        (self.cx, ct_base_y - 25),
                        (self.cx, ct_base_y - center_tower_h), 2)
        # Radar dish (larger triangle than before)
        dish_y = ct_base_y - center_tower_h + 10
        pygame.draw.polygon(surf, self.gunmetal_edge, [
            (self.cx - 12, dish_y), (self.cx + 12, dish_y),
            (self.cx, dish_y - 8),
        ])
        # Structural crossbar at mid-height
        cross_y = ct_base_y - 40
        pygame.draw.line(surf, self.gunmetal_edge,
                        (self.cx - 10, cross_y), (self.cx + 10, cross_y), 1)
        # Beacon position stored for animated draw
        self._beacon_x       = self.cx
        self._beacon_local_y = ct_base_y - center_tower_h

        # --- Undercarriage (structural weight) ---
        strut_count  = 5
        deck_bottom_y = base_y + deck_h // 2
        # Vertical support struts (thicker, longer than before)
        for i in range(strut_count):
            sx = deck_x + (deck_w // (strut_count + 1)) * (i + 1)
            pygame.draw.line(surf, (20, 25, 40, 150),
                           (sx, deck_bottom_y), (sx, deck_bottom_y + 30), 2)
        # Horizontal beam connecting struts
        pygame.draw.line(surf, (25, 30, 45, 120),
                        (deck_x + 30, deck_bottom_y + 15),
                        (deck_x + deck_w - 30, deck_bottom_y + 15), 1)
        # X-brace reinforcement (visual mass)
        pygame.draw.line(surf, (20, 25, 40, 80),
                        (deck_x + 40, deck_bottom_y),
                        (deck_x + deck_w // 2 - 10, deck_bottom_y + 28), 1)
        pygame.draw.line(surf, (20, 25, 40, 80),
                        (deck_x + deck_w - 40, deck_bottom_y),
                        (deck_x + deck_w // 2 + 10, deck_bottom_y + 28), 1)

        # --- Neon panel accents (thin strips on deck face) ---
        for i in range(3):
            py  = base_y + 2 + i * 6
            px1 = deck_x + 30 + i * 20
            px2 = deck_x + deck_w - 30 - i * 20
            pygame.draw.line(surf, (*self.cyan_accent, 50 + i * 20),
                           (px1, py), (px2, py), 1)

        # Store geometry for radar sweep calculations
        self._platform_base_y_local = base_y
        self._platform_deck_h       = deck_h
        self._platform_upper_h      = upper_h
        self._center_tower_h        = center_tower_h

    # ======================================================================
    #  UPDATE — called once per frame
    # ======================================================================

    def update(self):
        """Advance all animation state by one frame."""
        self.time            += 1
        self.fire_glow_phase += 0.04           # slower pulsation than original
        self.radar_angle     += self.radar_speed
        self.beacon_phase    += 0.08           # beacon pulses faster than fire
        self.ship_light_phase += 0.05          # ship nav lights
        self.scanline_offset  = (self.scanline_offset + 1) % self.height

        for wave in self.bg_waves:
            wave['phase'] += wave['speed']

        for wave in self.fg_waves:
            wave['phase'] += wave['speed']

        for cloud in self.clouds:
            cloud['x'] += cloud['speed']
            if cloud['x'] > self.width + cloud['w']:
                cloud['x'] = -cloud['w'] - random.randint(0, 50)
                cloud['y'] = random.randint(30, self.cy - 80)

        self._update_fire_lines()

    # ======================================================================
    #  DRAW — composites all layers
    # ======================================================================

    def draw(self, screen):
        """
        Render the complete background with 3-layer depth separation.

        FAR:   sky → ships → clouds → haze → nav lights → horizon
        MID:   ocean → bg waves → shadow → reflection → arena → beacon → radar → fire
        NEAR:  fg waves → scanlines → border
        """
        # --- FAR LAYER ---
        screen.blit(self._sky_gradient_cache, (0, 0))
        screen.blit(self._ship_surface, (0, self.cy - 60))
        self._draw_clouds(screen)
        screen.blit(self._haze_surface, (0, self.cy - 20))
        self._draw_ship_lights(screen)
        pygame.draw.line(screen, (*self.horizon_color, 180),
                        (0, self.cy), (self.width, self.cy), 1)

        # --- MID LAYER ---
        screen.blit(self._ocean_gradient_cache, (0, self.cy))
        self._draw_waves(screen, self.bg_waves, self._wave_surface, alpha=35)

        platform_y = self.cy - self._platform_surface.get_height() // 2 + 30
        self._draw_platform_shadow(screen, platform_y)
        self._draw_water_reflection(screen, platform_y)
        screen.blit(self._platform_surface, (0, platform_y))
        self._draw_beacon(screen, platform_y)
        self._draw_radar_sweep(screen, platform_y)
        self._draw_fire_lines(screen)

        # --- NEAR LAYER ---
        self._draw_waves(screen, self.fg_waves, self._fg_wave_surface,
                        alpha=55, circle_r=12, step=6, foam_interval=60)
        self._draw_scanlines(screen)
        self._draw_border(screen)

    # ======================================================================
    #  LAYER RENDERERS
    # ======================================================================

    def _draw_clouds(self, screen):
        """Dark storm clouds — elongated ellipses with brighter cores."""
        for idx, cloud in enumerate(self.clouds):
            surf = self._cloud_surfaces[idx]
            surf.fill(self._transparent)
            cw, ch, op = cloud['w'], cloud['h'], cloud['opacity']
            pygame.draw.ellipse(surf, (20, 20, 30, op), (5, 3, cw, ch))
            inner_w = cw * 2 // 3
            inner_x = 5 + (cw - inner_w) // 2
            pygame.draw.ellipse(surf, (30, 30, 45, op // 2),
                              (inner_x, 5, inner_w, ch - 4))
            screen.blit(surf, (int(cloud['x']), cloud['y']))

    def _draw_waves(self, screen, wave_list, surface, alpha=40,
                    circle_r=8, step=8, foam_interval=80):
        """
        Parameterized sine-wave ocean layer — shared by bg and fg waves.

        Background: small circles (r=8), step 8, faint (alpha 35)
        Foreground: large circles (r=12), step 6, bold (alpha 55)
        This size/density difference creates visual depth separation.
        """
        ocean_color = (*self.ocean_surface, alpha)
        foam_color  = (*self.wave_foam, alpha + 15)
        w = self.width

        for wave in wave_list:
            surface.fill(self._transparent)
            amp, freq, phase = wave['amplitude'], wave['frequency'], wave['phase']

            for x in range(0, w, step):
                y  = surface.get_height() // 2 + amp * math.sin(x * freq + phase)
                iy = int(y)
                pygame.draw.circle(surface, ocean_color, (x, iy), circle_r)
                if foam_interval > 0 and x % foam_interval < step:
                    pygame.draw.circle(surface, foam_color, (x, iy - 4), 3)

            screen.blit(surface, (0, wave['y']))

    def _draw_platform_shadow(self, screen, platform_y):
        """Soft shadow ellipse on the ocean surface beneath the arena."""
        self._shadow_surface.fill(self._transparent)
        shadow_w = int(self.width * 0.5)
        shadow_x = (self.width - shadow_w) // 2
        base_y   = self._platform_base_y_local + self._platform_deck_h // 2
        pygame.draw.ellipse(self._shadow_surface, (0, 0, 0, 25),
                          (shadow_x, 15, shadow_w, 50))
        screen.blit(self._shadow_surface, (0, platform_y + base_y + 30))

    def _draw_water_reflection(self, screen, platform_y):
        """
        Faint water reflection beneath the platform.

        Two color components that flicker with sin():
        • Cyan ellipse — reflection of the neon panel accents
        • Orange ellipse (offset right) — reflection of the broken
          tower's spark, adding warmth to the cold water

        The flicker creates a sense of water surface movement without
        needing additional wave geometry.
        """
        self._reflection_surface.fill(self._transparent)
        base_y    = self._platform_base_y_local + self._platform_deck_h // 2
        reflect_y = platform_y + base_y + 35
        ref_w     = int(self.width * 0.4)
        ref_x     = (self.width - ref_w) // 2
        flicker   = (math.sin(self.time * 0.03) + 1) * 0.3 + 0.4
        # Cyan reflection (from neon panels)
        cyan_a = int(12 * flicker)
        pygame.draw.ellipse(self._reflection_surface, (0, 160, 200, cyan_a),
                          (ref_x, 5, ref_w, 15))
        # Orange reflection (from broken tower spark)
        orange_a = int(8 * flicker)
        orange_x = ref_x + ref_w * 2 // 3
        pygame.draw.ellipse(self._reflection_surface, (200, 100, 40, orange_a),
                          (orange_x, 8, ref_w // 4, 10))
        screen.blit(self._reflection_surface, (0, reflect_y))

    def _draw_beacon(self, screen, platform_y):
        """
        Pulsating red beacon at the top of the central antenna.

        Two-layer rendering:
        • Outer glow: large circle, low alpha (atmospheric halo)
        • Inner core: small bright dot (the actual light source)

        Intensity oscillates via sin(beacon_phase) mapped to 0.3–1.0.
        Faster pulsation than fire (0.08/frame vs 0.04) to feel urgent.
        """
        beacon_x = self._beacon_x
        beacon_y = platform_y + self._beacon_local_y
        intensity = (math.sin(self.beacon_phase) + 1) * 0.35 + 0.3
        # Outer glow
        glow_r    = int(6 * intensity)
        glow_alpha = int(40 * intensity)
        gs = _get_cached_surface(glow_r * 2 + 4, glow_r * 2 + 4)
        pygame.draw.circle(gs, (255, 40, 20, glow_alpha),
                         (glow_r + 2, glow_r + 2), glow_r)
        screen.blit(gs, (beacon_x - glow_r - 2, beacon_y - glow_r - 2))
        # Core
        core_r = max(1, int(2 * intensity))
        core_color = (255, int(60 + 80 * intensity), int(20 + 30 * intensity))
        pygame.draw.circle(screen, core_color, (beacon_x, int(beacon_y)), core_r)

    def _draw_ship_lights(self, screen):
        """
        Blinking navigation lights on distant warships.

        4 lights with different phase offsets and colors:
        • Ship 1 bridge light (warm white) — phase 0.0
        • Ship 1 starboard light (red, maritime convention) — phase 1.5
        • Ship 2 bridge light (warm white) — phase 2.8
        • Ship 3 nav light (green, maritime convention) — phase 4.0

        Lights only render when sin() > 0.6 threshold, creating a
        realistic blink-on/blink-off pattern rather than smooth fade.
        """
        ship_y = self.cy - 60
        w = self.width
        lights = [
            (0.12 + 0.04, 35 - 25, 0.0, (255, 200, 100)),
            (0.12 + 0.08, 35,      1.5, (255, 50, 30)),
            (0.75 + 0.03, 38 - 12, 2.8, (255, 200, 100)),
            (0.91,        34,      4.0, (100, 255, 100)),
        ]
        for x_ratio, y_off, phase_off, color in lights:
            alpha = (math.sin(self.ship_light_phase + phase_off) + 1) * 0.5
            if alpha > 0.6:
                lx = int(w * x_ratio)
                ly = ship_y + y_off
                a  = int(25 * alpha)
                pygame.draw.circle(screen, (*color, a), (lx, ly), 2)

    def _draw_radar_sweep(self, screen, platform_y):
        """
        Rotating radar scan beam from the central antenna tip.

        The beam is an elongated triangle (spread=12px) with:
        • Faint cyan fill (alpha 12) — the sweep cone
        • Thin cyan center line (alpha 30) — the scan ray

        Y-axis is scaled by 0.4 to create an elliptical sweep pattern
        that feels like a real radar rotating on a horizontal plane.
        """
        origin_x = self.cx
        origin_y = (platform_y + self._platform_base_y_local
                    - self._platform_deck_h // 2
                    - self._platform_upper_h
                    - self._center_tower_h)

        sweep_len = min(self.width, self.height) // 4
        end_x = origin_x + math.cos(self.radar_angle) * sweep_len
        end_y = origin_y + math.sin(self.radar_angle) * sweep_len * 0.4

        sweep_surface = _get_cached_surface(self.width, self.height)
        spread = 12
        perp_x = -math.sin(self.radar_angle) * spread
        perp_y =  math.cos(self.radar_angle) * spread * 0.4

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
        """
        Faint horizontal hologram interference lines.
        Every 6th pixel row gets a subtle cyan line with oscillating alpha,
        creating a CRT/hologram overlay that adds sci-fi atmosphere.
        """
        self._scanline_surface.fill(self._transparent)
        for y in range(self.scanline_offset % 6, self.height, 6):
            alpha = 8 + int(4 * math.sin(y * 0.05 + self.time * 0.03))
            pygame.draw.line(self._scanline_surface, (0, 200, 220, alpha),
                           (0, y), (self.width, y))
        screen.blit(self._scanline_surface, (0, 0))

    def _draw_border(self, screen):
        """
        Thin neon border — 4px (was 10px in original).

        Designed to frame without competing with the scene:
        • Outer: nearly invisible dark frame (10, 15, 30)
        • Inner: 1px cyan accent line (subdued alpha 100)
        • Corners: tiny 2px cyan dots
        """
        t = 4
        w, h = self.width, self.height
        base   = (10, 15, 30)
        accent = (*self.cyan_dim, 100)

        pygame.draw.rect(screen, base, (0, 0, w, t))
        pygame.draw.rect(screen, base, (0, h - t, w, t))
        pygame.draw.rect(screen, base, (0, 0, t, h))
        pygame.draw.rect(screen, base, (w - t, 0, t, h))

        pygame.draw.rect(screen, accent, (t, t, w - 2 * t, 1))
        pygame.draw.rect(screen, accent, (t, h - t - 1, w - 2 * t, 1))
        pygame.draw.rect(screen, accent, (t, t, 1, h - 2 * t))
        pygame.draw.rect(screen, accent, (w - t - 1, t, 1, h - 2 * t))

        for corner_x, corner_y in [(t, t), (w - t, t), (t, h - t), (w - t, h - t)]:
            pygame.draw.circle(screen, self.cyan_accent, (corner_x, corner_y), 2)

    # ======================================================================
    #  FIRE LINE PARTICLE SYSTEM — subdued intensity
    # ======================================================================

    def _update_fire_lines(self):
        """
        Spawn and update fire particles along midfield lines.

        Spawn rate: 20% per frame (was 30%) — less dominant.
        Max particles: 80 (was 100) — lighter GPU load.
        Shrink rate: 0.94 (was 0.95) — particles die faster.
        """
        if random.random() < 0.2:
            angle = random.uniform(0, math.pi * 2)
            x = self.cx + math.cos(angle) * self.center_circle_radius
            y = self.stadium_line_y + math.sin(angle) * self.center_circle_radius
            self._create_fire_particle(x, y)

            if random.random() < 0.4:
                x = random.randint(self.width // 6, self.width * 5 // 6)
                self._create_fire_particle(x, self.stadium_line_y)

        for particle in self.fire_line_particles[:]:
            particle['y']    -= particle['vy']
            particle['x']    += particle['vx']
            particle['life'] -= 1
            particle['size'] *= 0.94

            if particle['life'] <= 0 or particle['size'] < 0.5:
                self.fire_line_particles.remove(particle)

    def _create_fire_particle(self, x, y):
        """Create a single fire particle (capped at 80)."""
        if len(self.fire_line_particles) < 80:
            self.fire_line_particles.append({
                'x': x, 'y': y,
                'vx':    random.uniform(-0.4, 0.4),
                'vy':    random.uniform(0.4, 1.5),
                'size':  random.uniform(1.5, 3.5),
                'life':  random.randint(15, 35),
                'color': random.choice(self.fire_colors),
                'glow':  random.uniform(0.5, 0.9),
            })

    def _draw_fire_lines(self, screen):
        """
        Burning midfield lines with pulsating glow.

        Deliberately subdued compared to original (2 glow layers vs 3,
        lower alpha values, single glow pass on dashes) so the arena
        platform reads as the primary visual element, not the fire.

        glow oscillation: sin(phase) mapped to 0.35–0.85 range
        """
        glow = (math.sin(self.fire_glow_phase) + 1) * 0.25 + 0.35

        # Center circle glow (2 layers)
        for i in range(2):
            alpha  = int(18 * glow * (1 - i * 0.4))
            radius = self.center_circle_radius + i * 2
            color  = (180 + int(55 * glow), 50 + int(30 * glow), 15)

            gs = radius * 2 + 16
            glow_surface = _get_cached_surface(gs, gs)
            pygame.draw.circle(glow_surface, (*color, alpha),
                             (radius + 8, radius + 8), radius, 2 + i)
            screen.blit(glow_surface, (self.cx - radius - 8,
                                       self.stadium_line_y - radius - 8))

        main_color = (230, int(80 + 40 * glow), 40)
        pygame.draw.circle(screen, main_color,
                          (self.cx, self.stadium_line_y),
                          self.center_circle_radius, 1)

        # Dashed midfield line
        dash_len  = 18
        gap_len   = 14
        margin    = self.width // 6
        current_x = margin
        while current_x < self.width - margin:
            dash_end = min(current_x + dash_len, self.width - margin)

            alpha = int(15 * glow)
            gs    = _get_cached_surface(dash_len + 8, 8)
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
                gs      = _get_cached_surface(gs_size, gs_size)
                center  = gs_size // 2
                pygame.draw.circle(gs, (*p['color'], min(ga, 80)),
                                 (center, center), center)
                screen.blit(gs, (p['x'] - center, p['y'] - center))
            pygame.draw.circle(screen, p['color'],
                             (int(p['x']), int(p['y'])), int(p['size']))
