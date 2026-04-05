# -*- coding: utf-8 -*-
"""
============================================================================
 PingFighter — Stage 5 Nemesis: Ocean Battleship Pillar Frame
============================================================================

 The decorative frame surrounding the game area for the Nemesis boss stage.
 Renders a naval warship-themed border with ocean, sky, and cyberpunk accents
 around the 760×750 game viewport.

 ┌─────────────────────────────────────────────────────────────────┐
 │  PILLAR FRAME LAYOUT                                           │
 │                                                                 │
 │  ┌─ metal border (12px graded) + cyan neon line ──────────────┐│
 │  │  ┌─ rivet strip (35px spacing) ──────────────────────────┐ ││
 │  │  │                                                        │ ││
 │  │  │   ┌─ control panel ─┐  ┌── GAME AREA ──┐  ┌─ ctrl ─┐ │ ││
 │  │  │   │ ● red light     │  │                │  │ ● red  │ │ ││
 │  │  │   │ ● green light   │  │   760 × 750    │  │ ● grn  │ │ ││
 │  │  │   │ ● cyan light    │  │                │  │ ● cyan │ │ ││
 │  │  │   │ ▓▓▓ gauge ▓▓░░  │  │                │  │ ▓▓▓░░  │ │ ││
 │  │  │   └─────────────────┘  └────────────────┘  └────────┘ │ ││
 │  │  │                                                        │ ││
 │  │  └── armor plate (6px graded) + cyan glow + corner bolts ─┘ ││
 │  └─────────────────────────────────────────────────────────────┘│
 │                                                                 │
 │  BACKGROUND: sky gradient (top→horizon) + ocean gradient (below)│
 │  HORIZON LINE at game_height // 2 (synced with in-game ocean)   │
 └─────────────────────────────────────────────────────────────────┘

 STATIC LAYERS (pre-rendered once in _create_frame):
   1. Sky gradient       — sky_blue → horizon_color (line-by-line, step 2)
   2. Ocean gradient     — ocean_surface → ocean_deep (line-by-line, step 2)
   3. Horizon emphasis   — 3px bright line + 3-line glow fade
   4. Metal border       — 12px graded frame (dark → mid → light → mid)
   5. Cyan neon line     — 2px cyberpunk accent inside border
   6. Rivets             — alternating light/dark circles, 35px spacing
   7. Armor plates       — 6px graded inner frame + cyan glow + corner bolts
   8. Control panels     — left/right indicator panels with lights + gauge

 ANIMATED LAYERS (drawn per-frame):
   9. Clouds             — 4 drifting translucent cloud sprites (cached)
  10. Waves              — 3 sine-wave layers on left/right pillars (cached)
  11. Foam particles     — small rising bubbles below horizon (max 12)
  12. Warning lights     — blinking red/green indicators (4 lights)
  13. Game border glow   — pulsating cyan rect around game area

 PERFORMANCE STRATEGY
 ────────────────────
 • Static frame: pre-rendered once → single blit per frame
 • Clouds: surface-cached by (size_bucket, opacity_bucket)
 • Waves: cached left/right surfaces, updated every 6th frame
 • Foam: capped at 12 particles (was 25)
 • Gradient step: 2px (halves draw.line calls vs 1px)

 DESIGN NOTES
 ────────────────────
 • Colors match the in-game ocean background (sky_blue, ocean_surface, etc.)
 • Horizon Y is computed from game_height // 2 to align with in-game water
 • Metal + rivet + armor plate aesthetic = naval warship hull
 • Cyan neon accents tie into the cyberpunk theme
 • Control panels with indicator lights add "bridge of a warship" feel
 • Radar display exists but is disabled (commented out in draw/update)
============================================================================
"""

import math
import random
import pygame


class NemesisOceanFrame:
    """
    Naval warship-themed pillar frame for Stage 5 Nemesis.

    The frame wraps around the game area, rendering the border regions
    as the hull of a cyberpunk battleship. The horizon line is synced
    with the in-game ocean background so the water level appears
    continuous across the pillar boundary.

    Architecture:
      • _create_frame(): one-time pre-render of all static elements
      • update(dt):      advances animation state (waves, clouds, particles)
      • draw(surface):   blits static frame + draws animated overlays

    Color palette is shared with AnimatedBackgroundStage6 (in-game bg)
    to maintain visual consistency across the pillar/game boundary.
    """

    # Color palette — synced with in-game ocean background
    COLORS = {
        # Sky (matches in-game gradient)
        'sky_blue': (135, 206, 235),
        'horizon_color': (255, 200, 150),
        # Ocean (matches in-game gradient)
        'ocean_surface': (0, 119, 190),
        'ocean_deep': (0, 80, 140),
        'wave_foam': (255, 255, 255),
        # Wave tones
        'wave': (45, 100, 160),
        'wave_light': (75, 140, 200),
        'foam': (200, 230, 245),
        'white_foam': (240, 248, 255),
        # Warship metal
        'metal': (80, 90, 105),
        'metal_light': (120, 130, 145),
        'metal_dark': (50, 55, 65),
        'gold_trim': (180, 150, 80),
        'cyan_glow': (0, 200, 220),
        # Indicator lights
        'red_light': (180, 60, 60),
        'green_light': (60, 180, 80),
        'radar_green': (50, 255, 100),
    }

    def __init__(self, screen_width: int, screen_height: int,
                 game_width: int, game_height: int):
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.game_width = game_width
        self.game_height = game_height

        # Game area positioning
        self.game_x = (screen_width - game_width) // 2
        self.game_y = (screen_height - game_height) // 2

        # Horizon Y — synced with in-game ocean midpoint
        self.horizon_y = self.game_y + game_height // 2

        # Animation state
        self.time = 0.0
        self.radar_angle = 0
        self.warning_flash = 0

        # Dynamic elements
        self.waves = []
        self._create_waves()
        self.foam_particles = []
        self.clouds = []
        self._create_clouds()

        # Pre-rendered static frame
        self._frame_surface = None
        self._create_frame()

        # Performance caches
        self._cloud_cache = {}
        self._wave_cache_left = None
        self._wave_cache_right = None
        self._wave_cache_phase = 0
        self._wave_update_interval = 6  # update wave cache every 6th frame

    # ==================================================================
    #  INITIALIZATION
    # ==================================================================

    def _create_waves(self):
        """Create 3 sine-wave layers below the horizon."""
        for i in range(3):
            self.waves.append({
                'y_offset': i * 45,
                'amplitude': random.uniform(5, 15),
                'frequency': random.uniform(0.01, 0.03),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.02, 0.04),
            })

    def _create_clouds(self):
        """Create 4 translucent drifting clouds above the horizon."""
        for _ in range(4):
            self.clouds.append({
                'x': random.randint(0, self.screen_width),
                'y': random.randint(20, self.horizon_y - 100),
                'size': random.randint(30, 70),
                'speed': random.uniform(0.05, 0.2),
                'opacity': random.randint(40, 80),
            })

    # ==================================================================
    #  STATIC FRAME (pre-rendered once)
    # ==================================================================

    def _create_frame(self):
        """Pre-render all static frame elements onto a single surface."""
        self._frame_surface = pygame.Surface(
            (self.screen_width, self.screen_height), pygame.SRCALPHA
        )
        self._draw_sky_ocean_background(self._frame_surface)
        self._draw_metal_border(self._frame_surface)
        self._draw_rivets(self._frame_surface)
        self._draw_armor_plates(self._frame_surface)
        self._draw_ship_details(self._frame_surface)

    def _draw_sky_ocean_background(self, surface: pygame.Surface):
        """
        Sky + ocean gradient background with horizon emphasis.

        The horizon Y position is computed from game_height // 2
        so the water level appears continuous with the in-game background.
        The game area rectangle is cleared to transparent.
        """
        sky = self.COLORS['sky_blue']
        horizon = self.COLORS['horizon_color']
        ocean_s = self.COLORS['ocean_surface']
        ocean_d = self.COLORS['ocean_deep']

        # Sky gradient (step 2px for performance)
        for y in range(0, self.horizon_y, 2):
            f = y / max(1, self.horizon_y)
            color = (
                int(sky[0] + (horizon[0] - sky[0]) * f),
                int(sky[1] + (horizon[1] - sky[1]) * f),
                int(sky[2] + (horizon[2] - sky[2]) * f),
                255,
            )
            pygame.draw.line(surface, color, (0, y), (self.screen_width, y), 2)

        # Ocean gradient (step 2px)
        ocean_h = self.screen_height - self.horizon_y
        for y in range(self.horizon_y, self.screen_height, 2):
            f = (y - self.horizon_y) / max(1, ocean_h)
            color = (
                int(ocean_s[0] + (ocean_d[0] - ocean_s[0]) * f),
                int(ocean_s[1] + (ocean_d[1] - ocean_s[1]) * f),
                int(ocean_s[2] + (ocean_d[2] - ocean_s[2]) * f),
                255,
            )
            pygame.draw.line(surface, color, (0, y), (self.screen_width, y), 2)

        # Horizon emphasis (bright line + glow fade)
        pygame.draw.line(surface, (*horizon, 255),
                        (0, self.horizon_y), (self.screen_width, self.horizon_y), 3)
        for i in range(1, 4):
            a = 100 - i * 25
            pygame.draw.line(surface, (*horizon, a),
                           (0, self.horizon_y - i), (self.screen_width, self.horizon_y - i), 1)
            pygame.draw.line(surface, (*ocean_s, a),
                           (0, self.horizon_y + i), (self.screen_width, self.horizon_y + i), 1)

        # Clear game area to transparent
        game_rect = pygame.Rect(self.game_x, self.game_y,
                               self.game_width, self.game_height)
        pygame.draw.rect(surface, (0, 0, 0, 0), game_rect)

    def _draw_metal_border(self, surface: pygame.Surface):
        """
        12px graded metal frame around the entire screen.

        Gradient pattern: dark → mid → light → mid (simulates
        beveled metal edge with highlight). Topped with a 2px
        cyan neon line for cyberpunk accent.
        """
        border_w = 12
        metal = self.COLORS['metal']
        metal_l = self.COLORS['metal_light']
        metal_d = self.COLORS['metal_dark']

        for i in range(border_w):
            t = i / border_w
            if t < 0.2:      color = metal_d
            elif t < 0.6:    color = metal
            elif t < 0.8:    color = metal_l
            else:            color = metal
            rect = pygame.Rect(i, i, self.screen_width - i * 2,
                             self.screen_height - i * 2)
            pygame.draw.rect(surface, (*color, 255), rect, 1)

        # Cyan neon accent
        pygame.draw.rect(surface, (*self.COLORS['cyan_glow'], 150),
                        pygame.Rect(4, 4, self.screen_width - 8,
                                   self.screen_height - 8), 2)

    def _draw_rivets(self, surface: pygame.Surface):
        """Rivet/bolt decorations along all four border edges."""
        ml = self.COLORS['metal_light']
        md = self.COLORS['metal_dark']
        sp = 35  # spacing
        r = 3    # radius

        for x in range(sp, self.screen_width - sp, sp):
            pygame.draw.circle(surface, (*md, 255), (x, 7), r)
            pygame.draw.circle(surface, (*ml, 200), (x - 1, 6), r - 1)
            pygame.draw.circle(surface, (*md, 255), (x, self.screen_height - 7), r)
            pygame.draw.circle(surface, (*ml, 200), (x - 1, self.screen_height - 8), r - 1)

        for y in range(sp, self.screen_height - sp, sp):
            pygame.draw.circle(surface, (*md, 255), (7, y), r)
            pygame.draw.circle(surface, (*ml, 200), (6, y - 1), r - 1)
            pygame.draw.circle(surface, (*md, 255), (self.screen_width - 7, y), r)
            pygame.draw.circle(surface, (*ml, 200), (self.screen_width - 8, y - 1), r - 1)

    def _draw_armor_plates(self, surface: pygame.Surface):
        """
        6px graded inner frame around the game area.
        Includes cyan glow border and corner bolt accents.
        """
        margin = 10
        pw = 6  # plate width
        metal = self.COLORS['metal']
        ml = self.COLORS['metal_light']
        md = self.COLORS['metal_dark']
        cyan = self.COLORS['cyan_glow']

        inner = pygame.Rect(
            self.game_x - margin - pw, self.game_y - margin - pw,
            self.game_width + (margin + pw) * 2,
            self.game_height + (margin + pw) * 2,
        )

        for i in range(pw):
            t = i / pw
            if t < 0.3:      c = ml
            elif t < 0.7:    c = metal
            else:            c = md
            pygame.draw.rect(surface, (*c, 255), inner.inflate(-i * 2, -i * 2), 1)

        pygame.draw.rect(surface, (*cyan, 180), inner, 2)

        # Corner bolts with cyan core
        for bx, by in [
            (inner.left + 8, inner.top + 8),
            (inner.right - 8, inner.top + 8),
            (inner.left + 8, inner.bottom - 8),
            (inner.right - 8, inner.bottom - 8),
        ]:
            pygame.draw.circle(surface, (*md, 255), (bx, by), 5)
            pygame.draw.circle(surface, (*ml, 220), (bx - 1, by - 1), 3)
            pygame.draw.circle(surface, (*cyan, 200), (bx, by), 2)

    def _draw_ship_details(self, surface: pygame.Surface):
        """Control panels on left/right pillar areas."""
        if self.game_x < 50:
            return
        self._draw_control_panel(surface, 15, self.game_y + 40, 'left')
        self._draw_control_panel(surface, self.screen_width - 15,
                               self.game_y + 40, 'right')

    def _draw_control_panel(self, surface: pygame.Surface,
                           x: int, y: int, side: str):
        """
        Indicator panel with 3 status lights + gauge bar.
        Placed on the warship hull beside the game area.
        """
        pw = min(45, self.game_x - 25)
        ph = 120
        if side == 'right':
            x = x - pw

        md = self.COLORS['metal_dark']
        cyan = self.COLORS['cyan_glow']

        # Panel background
        panel = pygame.Rect(x, y, pw, ph)
        pygame.draw.rect(surface, (*md, 230), panel)
        pygame.draw.rect(surface, (*cyan, 150), panel, 1)

        # 3 indicator lights
        for i, color in enumerate([
            self.COLORS['red_light'],
            self.COLORS['green_light'],
            self.COLORS['cyan_glow'],
        ]):
            ly = y + 18 + i * 22
            lx = x + pw // 2
            pygame.draw.circle(surface, (*md, 255), (lx, ly), 7)
            pygame.draw.circle(surface, (*color, 150), (lx, ly), 5)

        # Gauge bar
        gy = y + 90
        gw = pw - 12
        pygame.draw.rect(surface, (*md, 255), (x + 6, gy, gw, 10))
        pygame.draw.rect(surface, (*cyan, 180), (x + 8, gy + 2, int(gw * 0.7), 6))

    # ==================================================================
    #  ANIMATED LAYERS (per-frame)
    # ==================================================================

    def _draw_animated_clouds(self, surface: pygame.Surface):
        """Drift clouds across the sky region (cached by size/opacity)."""
        for cloud in self.clouds:
            if cloud['y'] < self.horizon_y - 20:
                cs = self._get_cached_cloud(cloud['size'], cloud['opacity'])
                surface.blit(cs, (int(cloud['x']), int(cloud['y'])))

    def _get_cached_cloud(self, size: int, opacity: int) -> pygame.Surface:
        """Return cached cloud surface (bucketed by 10px size, 20 opacity)."""
        sb = (size // 10) * 10
        ob = (opacity // 20) * 20
        key = (sb, ob)

        if key in self._cloud_cache:
            return self._cloud_cache[key]

        surf = pygame.Surface((sb * 2, sb), pygame.SRCALPHA)
        for i in range(3):
            cx = sb // 2 + i * sb // 3
            pygame.draw.circle(surf, (255, 255, 255, ob), (cx, sb // 2), sb // 3)

        if len(self._cloud_cache) > 50:
            self._cloud_cache.clear()
        self._cloud_cache[key] = surf
        return surf

    def _draw_animated_waves(self, surface: pygame.Surface):
        """
        Sine-wave ocean animation on left/right pillar areas.
        Wave surfaces are cached and only updated every 6th frame.
        """
        if not hasattr(self, '_wave_frame_counter'):
            self._wave_frame_counter = 0
        self._wave_frame_counter += 1

        if (self._wave_frame_counter % self._wave_update_interval == 0
                or self._wave_cache_left is None):
            self._update_wave_cache()

        if self._wave_cache_left is not None and self.game_x > 20:
            surface.blit(self._wave_cache_left, (0, self.horizon_y))
        if self._wave_cache_right is not None:
            surface.blit(self._wave_cache_right,
                        (self.game_x + self.game_width, self.horizon_y))

    def _update_wave_cache(self):
        """Regenerate cached wave surfaces for left/right pillars."""
        oc = self.COLORS['ocean_surface']
        max_yo = max(w['y_offset'] + w['amplitude'] for w in self.waves) + 20
        wh = int(max_yo) + 30

        # Left pillar waves
        if self.game_x > 20:
            if self._wave_cache_left is None:
                self._wave_cache_left = pygame.Surface(
                    (self.game_x, wh), pygame.SRCALPHA)
            self._wave_cache_left.fill((0, 0, 0, 0))
            for wave in self.waves:
                yb = wave['y_offset']
                for x in range(0, self.game_x - 10, 20):
                    y = yb + wave['amplitude'] * math.sin(
                        x * wave['frequency'] + wave['phase'])
                    pygame.draw.circle(self._wave_cache_left, (*oc, 60),
                                     (x, int(y)), 8)

        # Right pillar waves
        rs = self.game_x + self.game_width
        rw = self.screen_width - rs
        if rw > 20:
            if self._wave_cache_right is None:
                self._wave_cache_right = pygame.Surface(
                    (rw, wh), pygame.SRCALPHA)
            self._wave_cache_right.fill((0, 0, 0, 0))
            for wave in self.waves:
                yb = wave['y_offset']
                for x in range(10, rw, 20):
                    y = yb + wave['amplitude'] * math.sin(
                        (x + rs) * wave['frequency'] + wave['phase'])
                    pygame.draw.circle(self._wave_cache_right, (*oc, 60),
                                     (x, int(y)), 8)

    def _draw_foam_particles(self, surface: pygame.Surface):
        """Render rising foam bubbles below the horizon."""
        for foam in self.foam_particles:
            a = int(foam['alpha'])
            if a > 0:
                pygame.draw.circle(surface, (*self.COLORS['white_foam'], a),
                                 (int(foam['x']), int(foam['y'])), foam['size'])

    def _draw_warning_lights(self, surface: pygame.Surface):
        """Blinking red/green indicator lights on control panels."""
        if self.game_x < 50:
            return
        flash = self.warning_flash > 0.5

        for base_x in [
            15 + min(45, self.game_x - 25) // 2,                    # left
            self.screen_width - 15 - min(45, self.game_x - 25) // 2  # right
        ]:
            for i in range(2):
                ly = self.game_y + 40 + 18 + i * 28
                if i == 0:
                    c = self.COLORS['red_light'] if flash else (80, 30, 30)
                else:
                    c = self.COLORS['green_light']
                pygame.draw.circle(surface, (*c, 255), (base_x, ly), 4)

    def _draw_game_border_glow(self, surface: pygame.Surface):
        """Pulsating cyan glow rectangle around the game area."""
        pulse = int(15 + 8 * math.sin(self.time * 1.5))
        if pulse > 0:
            rect = pygame.Rect(self.game_x - 10, self.game_y - 10,
                             self.game_width + 20, self.game_height + 20)
            pygame.draw.rect(surface, (*self.COLORS['cyan_glow'], pulse), rect, 1)

    # ==================================================================
    #  UPDATE + DRAW
    # ==================================================================

    def update(self, dt: float):
        """Advance all animation state."""
        self.time += dt

        for wave in self.waves:
            wave['phase'] += wave['speed']

        for cloud in self.clouds:
            cloud['x'] += cloud['speed']
            if cloud['x'] > self.screen_width + cloud['size']:
                cloud['x'] = -cloud['size']
                cloud['y'] = random.randint(20, self.horizon_y - 100)

        self.warning_flash += dt
        if self.warning_flash > 1.0:
            self.warning_flash = 0

        self._spawn_foam()
        for foam in self.foam_particles[:]:
            foam['x'] += foam['vx']
            foam['y'] += foam['vy']
            foam['alpha'] -= foam['decay']
            if foam['alpha'] <= 0 or foam['y'] < self.horizon_y:
                self.foam_particles.remove(foam)

    def draw(self, surface: pygame.Surface):
        """
        Render complete pillar frame.

        Order: static frame → clouds → waves → foam → lights → glow
        """
        if self._frame_surface:
            surface.blit(self._frame_surface, (0, 0))
        self._draw_animated_clouds(surface)
        self._draw_animated_waves(surface)
        self._draw_foam_particles(surface)
        self._draw_warning_lights(surface)
        self._draw_game_border_glow(surface)

    def _spawn_foam(self):
        """Spawn foam bubbles below horizon (1% chance, max 12)."""
        if random.random() < 0.01 and len(self.foam_particles) < 12:
            if self.game_x > 20:
                if random.random() < 0.5:
                    x = random.randint(5, self.game_x - 15)
                else:
                    x = random.randint(self.game_x + self.game_width + 15,
                                      self.screen_width - 5)
                self.foam_particles.append({
                    'x': x,
                    'y': random.randint(self.horizon_y + 20, self.screen_height - 20),
                    'vx': random.uniform(-0.2, 0.2),
                    'vy': random.uniform(-0.8, -0.2),
                    'size': random.randint(2, 4),
                    'alpha': random.randint(80, 150),
                    'decay': random.uniform(0.3, 1.0),
                })

    def resize(self, screen_width: int, screen_height: int,
               game_width: int, game_height: int):
        """Handle screen resize — rebuilds all caches."""
        self.__init__(screen_width, screen_height, game_width, game_height)

    def trigger_excitement(self, level: float = 1.5):
        """Burst foam particles on score events."""
        for _ in range(int(12 * level)):
            self._spawn_foam()


# Compatibility alias
Stage5PillarBackground = NemesisOceanFrame

# Global instance
_nemesis_ocean_bg = None

def init_nemesis_ocean_background(screen_width, screen_height,
                                   game_width, game_height):
    global _nemesis_ocean_bg
    _nemesis_ocean_bg = NemesisOceanFrame(screen_width, screen_height,
                                          game_width, game_height)
    return _nemesis_ocean_bg

def get_nemesis_ocean_background():
    return _nemesis_ocean_bg
