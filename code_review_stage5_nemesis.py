# -*- coding: utf-8 -*-
"""
============================================================================
 PingFighter - Stage 5 Nemesis: Ocean Cyberpunk Stadium Background
============================================================================

 An animated background system for a Pygame-based arcade game.
 Renders a cyberpunk stadium floating over an ocean battlefield,
 with layered rendering, particle effects, and GPU-friendly optimizations.

 Rendering Stack (back to front):
   1. Sky gradient     - numpy-precomputed sunset gradient
   2. Clouds           - semi-transparent drifting cloud sprites
   3. Ocean gradient   - numpy-precomputed deep ocean gradient
   4. Waves            - sine-wave animated ocean with foam
   5. Horizon line     - sunset-colored divider
   6. Floating platform - cyberpunk stadium hovering over water
   7. Fire lines       - burning stadium lines with glow particles
   8. Border           - neon-accented cyberpunk frame

 Performance Strategy:
   - All gradients pre-rendered to surfaces via numpy (eliminates ~374
     draw.rect calls per frame → 2 surface blits)
   - Cloud sprites pre-allocated and reused each frame
   - Wave/shadow/platform surfaces cached as instance attributes
   - Fire particle glow surfaces pulled from a module-level LRU cache
   - Deterministic foam placement (no per-frame random calls in draw)

 Resolution: 760 x 750 (full game area including pillar overlays)
============================================================================
"""

import pygame
import pygame.surfarray
import math
import random
import numpy as np

# ============================================================================
#  Surface Cache (Module-Level LRU)
# ============================================================================
# Reusable transparent surfaces keyed by (width, height).
# Avoids allocating new surfaces every frame for glow effects.
# Auto-clears when entries exceed 100 to prevent memory creep.

_stage6_surface_cache = {}

def _get_cached_surface(width: int, height: int) -> pygame.Surface:
    """Return a cleared SRCALPHA surface from cache, creating if needed."""
    key = (width, height)
    if key not in _stage6_surface_cache:
        if len(_stage6_surface_cache) > 100:
            _stage6_surface_cache.clear()
        _stage6_surface_cache[key] = pygame.Surface((width, height), pygame.SRCALPHA)
    surface = _stage6_surface_cache[key]
    surface.fill((0, 0, 0, 0))
    return surface


# ============================================================================
#  Constants
# ============================================================================

try:
    from config.constants import PILLAR_UI_WIDTH, GAME_PLAY_WIDTH, SCREEN_HEIGHT
    PILLAR_OFFSET = PILLAR_UI_WIDTH   # 80px - decorative pillar width
    GAME_WIDTH = GAME_PLAY_WIDTH      # 600px - central play area
    HEIGHT = SCREEN_HEIGHT            # 750px - full screen height
except ImportError:
    PILLAR_OFFSET = 80
    GAME_WIDTH = 600
    HEIGHT = 750


# ============================================================================
#  AnimatedBackgroundStage6 - Ocean Cyberpunk Stadium
# ============================================================================

class AnimatedBackgroundStage6:
    """
    Animated background for Stage 5 (Nemesis - Ocean Battleship).

    Architecture:
      - __init__: Pre-allocates all surfaces and caches gradients
      - update():  Advances animation state (waves, clouds, particles)
      - draw():    Composites all layers onto the screen surface

    The class owns its animation state and render surfaces.
    No external dependencies beyond pygame and numpy.
    """

    def __init__(self, width, height):
        self.width = width
        self.height = height
        self.time = 0

        # ------------------------------------------------------------------
        #  Color Palette
        # ------------------------------------------------------------------
        self.sky_blue = (135, 206, 235)       # Upper sky
        self.horizon_color = (255, 200, 150)  # Sunset horizon
        self.ocean_surface = (0, 119, 190)    # Ocean top
        self.ocean_deep = (0, 80, 140)        # Ocean bottom
        self.wave_foam = (255, 255, 255)      # Wave foam highlights
        self.cyan_glow = (0, 200, 220)        # Neon cyan accent
        self.arena_color = (0, 180, 200)      # Arena line color

        # ------------------------------------------------------------------
        #  Pre-allocated Render Surfaces (avoid per-frame allocation)
        # ------------------------------------------------------------------
        self._glow_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        self._wave_surface = pygame.Surface((width, 40), pygame.SRCALPHA)
        self._shadow_surface = pygame.Surface((width, 100), pygame.SRCALPHA)
        self._platform_surface = pygame.Surface((width, 100), pygame.SRCALPHA)
        self._transparent = (0, 0, 0, 0)

        # ------------------------------------------------------------------
        #  Gradient Caches (numpy-optimized, computed once)
        # ------------------------------------------------------------------
        self._sky_gradient_cache = None
        self._ocean_gradient_cache = None
        self._init_gradient_caches()

        # ------------------------------------------------------------------
        #  Wave Animation System
        # ------------------------------------------------------------------
        #  5 overlapping sine waves with different frequencies create
        #  a natural-looking ocean surface animation.
        self.waves = []
        for i in range(5):
            self.waves.append({
                'y': height // 2 + i * 30,           # Vertical offset
                'amplitude': random.uniform(5, 15),   # Wave height
                'frequency': random.uniform(0.01, 0.03),  # Horizontal density
                'phase': random.uniform(0, math.pi * 2),  # Initial phase
                'speed': random.uniform(0.02, 0.04)   # Animation speed
            })

        # ------------------------------------------------------------------
        #  Cloud System
        # ------------------------------------------------------------------
        #  4 drifting clouds, each pre-rendered to its own surface.
        self.clouds = []
        self._cloud_surfaces = []
        for _ in range(4):
            cloud_size = random.randint(40, 80)
            cloud_data = {
                'x': random.randint(0, width),
                'y': random.randint(50, 200),
                'size': cloud_size,
                'speed': random.uniform(0.1, 0.3),
                'opacity': random.randint(30, 60)
            }
            self.clouds.append(cloud_data)
            self._cloud_surfaces.append(
                pygame.Surface((cloud_size * 2, cloud_size), pygame.SRCALPHA)
            )

        # ------------------------------------------------------------------
        #  Arena Geometry
        # ------------------------------------------------------------------
        self.arena_center_x = width // 2
        self.arena_center_y = height // 2
        self.arena_radius = min(width, height) // 3

        # ------------------------------------------------------------------
        #  Fire Line Particle System
        # ------------------------------------------------------------------
        #  Burning stadium lines with glow particles rising from
        #  both the center circle and horizontal midfield line.
        self.fire_line_particles = []
        self.fire_glow_phase = 0          # Pulsating glow oscillator
        self.center_circle_radius = 80    # Center circle radius
        self.stadium_line_y = height // 2   # Midfield line Y position
        self.fire_colors = [
            (255, 100, 50),   # Bright orange
            (255, 80, 30),    # Deep orange
            (200, 60, 20),    # Red-orange
            (150, 40, 10),    # Dark red
        ]

    # ======================================================================
    #  Gradient Pre-computation (numpy vectorized)
    # ======================================================================

    def _init_gradient_caches(self):
        """
        Pre-render sky and ocean gradients using numpy array operations.

        Before optimization: 374 individual pygame.draw.rect() calls per frame
        After optimization:  2 surface blits from pre-computed caches

        Uses numpy broadcasting to compute RGB interpolation across all
        scanlines simultaneously, then blits the result array to a surface.
        """
        half_height = self.height // 2

        # --- Sky: sky_blue → horizon_color (top to middle) ---
        self._sky_gradient_cache = pygame.Surface((self.width, half_height))
        sky_arr = np.zeros((self.width, half_height, 3), dtype=np.uint8)
        factors = np.arange(half_height, dtype=np.float32) / max(half_height - 1, 1)

        sky_arr[:, :, 0] = (self.sky_blue[0] + (self.horizon_color[0] - self.sky_blue[0]) * factors).astype(np.uint8)
        sky_arr[:, :, 1] = (self.sky_blue[1] + (self.horizon_color[1] - self.sky_blue[1]) * factors).astype(np.uint8)
        sky_arr[:, :, 2] = (self.sky_blue[2] + (self.horizon_color[2] - self.sky_blue[2]) * factors).astype(np.uint8)
        pygame.surfarray.blit_array(self._sky_gradient_cache, sky_arr)

        # --- Ocean: ocean_surface → ocean_deep (middle to bottom) ---
        self._ocean_gradient_cache = pygame.Surface((self.width, half_height))
        ocean_arr = np.zeros((self.width, half_height, 3), dtype=np.uint8)

        ocean_arr[:, :, 0] = (self.ocean_surface[0] + (self.ocean_deep[0] - self.ocean_surface[0]) * factors).astype(np.uint8)
        ocean_arr[:, :, 1] = (self.ocean_surface[1] + (self.ocean_deep[1] - self.ocean_surface[1]) * factors).astype(np.uint8)
        ocean_arr[:, :, 2] = (self.ocean_surface[2] + (self.ocean_deep[2] - self.ocean_surface[2]) * factors).astype(np.uint8)
        pygame.surfarray.blit_array(self._ocean_gradient_cache, ocean_arr)

    # ======================================================================
    #  Update (called once per frame)
    # ======================================================================

    def update(self):
        """Advance all animation state by one frame."""
        self.time += 1
        self.fire_glow_phase += 0.05

        # Wave phase progression
        for wave in self.waves:
            wave['phase'] += wave['speed']

        # Cloud horizontal drift (wraps around screen)
        for cloud in self.clouds:
            cloud['x'] += cloud['speed']
            if cloud['x'] > self.width + cloud['size']:
                cloud['x'] = -cloud['size']
                cloud['y'] = random.randint(50, 200)

        # Fire particle lifecycle
        self._update_fire_lines()

    # ======================================================================
    #  Draw (composites all layers)
    # ======================================================================

    def draw(self, screen):
        """
        Render the complete background.

        Layer order (back to front):
          sky → clouds → ocean → waves → horizon → platform → fire → border
        """
        # Layer 1: Sky gradient (cached)
        screen.blit(self._sky_gradient_cache, (0, 0))

        # Layer 2: Clouds
        self._draw_clouds(screen)

        # Layer 3: Ocean gradient (cached)
        screen.blit(self._ocean_gradient_cache, (0, self.height // 2))

        # Layer 4: Animated waves
        self._draw_waves(screen)

        # Layer 5: Horizon line
        pygame.draw.line(screen, self.horizon_color,
                        (0, self.height // 2), (self.width, self.height // 2), 2)

        # Layer 6: Floating cyberpunk platform
        self._draw_floating_platform(screen)

        # Layer 7: Burning stadium lines + particles
        self._draw_fire_lines(screen)

        # Layer 8: Neon border frame (drawn last = always on top)
        self._draw_border(screen)

    # ======================================================================
    #  Layer Renderers
    # ======================================================================

    def _draw_border(self, screen):
        """
        Cyberpunk-themed neon border with corner accent lights.

        Structure:
          - Outer border: dark teal (0, 60, 80)
          - Inner border: cyan highlight (0, 120, 150)
          - Corner dots:  neon glow accent (0, 200, 220)
        """
        border_thickness = 10
        x_off = 0
        game_w = self.width
        h = self.height

        base_color = (0, 60, 80)
        cyan_color = (0, 120, 150)
        glow_accent = (0, 200, 220)

        # Outer border (4 sides)
        pygame.draw.rect(screen, base_color, (x_off, 0, game_w, border_thickness))
        pygame.draw.rect(screen, base_color, (x_off, h - border_thickness, game_w, border_thickness))
        pygame.draw.rect(screen, base_color, (x_off, 0, border_thickness, h))
        pygame.draw.rect(screen, base_color, (x_off + game_w - border_thickness, 0, border_thickness, h))

        # Inner highlight border (depth effect)
        inner = 2
        pygame.draw.rect(screen, cyan_color,
                        (x_off + border_thickness - inner, border_thickness - inner,
                         game_w - 2 * (border_thickness - inner), inner))
        pygame.draw.rect(screen, cyan_color,
                        (x_off + border_thickness - inner, h - border_thickness,
                         game_w - 2 * (border_thickness - inner), inner))
        pygame.draw.rect(screen, cyan_color,
                        (x_off + border_thickness - inner, border_thickness - inner,
                         inner, h - 2 * (border_thickness - inner)))
        pygame.draw.rect(screen, cyan_color,
                        (x_off + game_w - border_thickness, border_thickness - inner,
                         inner, h - 2 * (border_thickness - inner)))

        # Corner accent dots (neon glow)
        r = 5
        half = border_thickness // 2
        pygame.draw.circle(screen, glow_accent, (x_off + half, half), r)
        pygame.draw.circle(screen, glow_accent, (x_off + game_w - half, half), r)
        pygame.draw.circle(screen, glow_accent, (x_off + half, h - half), r)
        pygame.draw.circle(screen, glow_accent, (x_off + game_w - half, h - half), r)

    def _draw_clouds(self, screen):
        """
        Render drifting clouds using pre-allocated surfaces.
        Each cloud is composed of 3 overlapping circles for a soft shape.
        """
        for idx, cloud in enumerate(self.clouds):
            surf = self._cloud_surfaces[idx]
            surf.fill(self._transparent)
            for i in range(3):
                x = cloud['size'] // 2 + i * cloud['size'] // 3
                y = cloud['size'] // 2
                radius = cloud['size'] // 3
                pygame.draw.circle(surf, (255, 255, 255, cloud['opacity']),
                                 (x, y), radius)
            screen.blit(surf, (cloud['x'], cloud['y']))

    def _draw_waves(self, screen):
        """
        Animated sine-wave ocean surface.

        Optimization notes:
          - Step size 8px (vs naive 1px) for 8x fewer draw calls
          - Deterministic foam at every 80px (no per-frame random())
          - Single cached wave surface reused across all 5 wave layers
        """
        ocean_color = (*self.ocean_surface, 40)
        foam_color = (*self.wave_foam, 60)
        w = self.width

        for wave in self.waves:
            self._wave_surface.fill(self._transparent)
            amp = wave['amplitude']
            freq = wave['frequency']
            phase = wave['phase']

            for x in range(0, w, 8):
                y = 20 + amp * math.sin(x * freq + phase)
                iy = int(y)
                pygame.draw.circle(self._wave_surface, ocean_color, (x, iy), 8)
                # Deterministic foam placement (every 80px)
                if x % 80 < 8:
                    pygame.draw.circle(self._wave_surface, foam_color, (x, iy - 5), 3)

            screen.blit(self._wave_surface, (0, wave['y']))

    def _draw_floating_platform(self, screen):
        """
        Cyberpunk stadium platform hovering over the ocean.
        Includes a shadow ellipse on the water surface beneath.
        """
        platform_y = self.height // 2 + 100

        # Shadow on water
        self._shadow_surface.fill(self._transparent)
        pygame.draw.ellipse(self._shadow_surface, (0, 0, 0, 30),
                          (self.width // 4, 20, self.width // 2, 60))
        screen.blit(self._shadow_surface, (0, platform_y + 20))

        # Platform body
        self._platform_surface.fill(self._transparent)
        pygame.draw.rect(self._platform_surface, (80, 80, 100, 100),
                        (self.width // 4, 30, self.width // 2, 40))
        pygame.draw.rect(self._platform_surface, self.cyan_glow,
                        (self.width // 4, 30, self.width // 2, 40), 2)

        # Support pillars
        for i in range(3):
            x = self.width // 4 + (self.width // 8) * (i + 1)
            pygame.draw.line(self._platform_surface, (60, 60, 80),
                           (x, 70), (x, 90), 3)

        screen.blit(self._platform_surface, (0, platform_y))

    # ======================================================================
    #  Fire Line Particle System
    # ======================================================================

    def _update_fire_lines(self):
        """
        Spawn and update fire particles along stadium lines.

        Particles spawn from two sources:
          1. Center circle perimeter (random angle)
          2. Horizontal midfield line (random x position)

        Each particle rises upward, drifts slightly, shrinks, and dies.
        Max particle count: 100 (prevents runaway memory usage).
        """
        if random.random() < 0.3:
            # Spawn on center circle
            angle = random.uniform(0, math.pi * 2)
            x = self.width // 2 + math.cos(angle) * self.center_circle_radius
            y = self.stadium_line_y + math.sin(angle) * self.center_circle_radius
            self._create_fire_particle(x, y)

            # Spawn on midfield line (50% chance for dotted effect)
            if random.random() < 0.5:
                x = random.randint(50, self.width - 50)
                self._create_fire_particle(x, self.stadium_line_y)

        # Update existing particles
        for particle in self.fire_line_particles[:]:
            particle['y'] -= particle['vy']    # Rise upward
            particle['x'] += particle['vx']    # Lateral drift
            particle['life'] -= 1
            particle['size'] *= 0.95           # Shrink over time

            if particle['life'] <= 0 or particle['size'] < 0.5:
                self.fire_line_particles.remove(particle)

    def _create_fire_particle(self, x, y):
        """Create a single fire particle with randomized properties."""
        if len(self.fire_line_particles) < 100:
            self.fire_line_particles.append({
                'x': x,
                'y': y,
                'vx': random.uniform(-0.5, 0.5),
                'vy': random.uniform(0.5, 2.0),
                'size': random.uniform(2, 4),
                'life': random.randint(20, 40),
                'color': random.choice(self.fire_colors),
                'glow': random.uniform(0.6, 1.0),
            })

    def _draw_fire_lines(self, screen):
        """
        Render burning stadium lines with multi-layer glow effects.

        Visual components:
          1. Center circle - triple-layer glow + thin bright outline
          2. Midfield line - dashed with glow underlayer
          3. Fire particles - glowing circles with alpha falloff

        The glow_intensity oscillates via sin() to create a pulsating
        "breathing fire" effect on all line elements.
        """
        glow_intensity = (math.sin(self.fire_glow_phase) + 1) * 0.3 + 0.4  # Range: 0.4 ~ 1.0
        center_x = self.width // 2
        center_y = self.stadium_line_y

        # --- Center circle: triple glow layers ---
        for i in range(3):
            alpha = int(25 * glow_intensity * (1 - i * 0.3))
            radius = self.center_circle_radius + i * 2
            color = (200 + int(55 * glow_intensity),
                    60 + int(40 * glow_intensity),
                    20)

            glow_size = radius * 2 + 20
            glow_surface = _get_cached_surface(glow_size, glow_size)
            pygame.draw.circle(glow_surface, (*color, alpha),
                             (radius + 10, radius + 10), radius, 2 + i)
            screen.blit(glow_surface, (center_x - radius - 10, center_y - radius - 10))

        # Center circle outline (thin, bright)
        main_color = (255, int(100 + 50 * glow_intensity), 50)
        pygame.draw.circle(screen, main_color, (center_x, center_y),
                          self.center_circle_radius, 1)

        # --- Midfield dashed line with glow ---
        line_start_x = 50
        line_end_x = self.width - 50
        dash_length = 20
        gap_length = 15

        current_x = line_start_x
        while current_x < line_end_x:
            dash_end = min(current_x + dash_length, line_end_x)

            # Glow underlayer (2 passes)
            for i in range(2):
                alpha = int(20 * glow_intensity * (1 - i * 0.4))
                thickness = 1 + i
                color = (200 + int(55 * glow_intensity),
                        60 + int(40 * glow_intensity),
                        20)
                glow_surface = _get_cached_surface(dash_length + 10, 10)
                pygame.draw.line(glow_surface, (*color, alpha),
                               (5, 5), (dash_length + 5, 5), thickness)
                screen.blit(glow_surface, (current_x - 5, self.stadium_line_y - 5))

            # Main dash line (bright, thin)
            pygame.draw.line(screen, main_color,
                            (current_x, self.stadium_line_y),
                            (dash_end, self.stadium_line_y), 1)

            current_x += dash_length + gap_length

        # --- Fire particles ---
        for particle in self.fire_line_particles:
            glow_alpha = int(particle['glow'] * particle['life'] * 1.5)
            if glow_alpha > 0:
                glow_size = int(particle['size'] * 1.5)
                surf_size = max(1, glow_size * 2)
                glow_surface = _get_cached_surface(surf_size, surf_size)
                pygame.draw.circle(glow_surface, (*particle['color'], min(glow_alpha, 100)),
                                 (glow_size, glow_size), glow_size)
                screen.blit(glow_surface, (particle['x'] - glow_size, particle['y'] - glow_size))

            pygame.draw.circle(screen, particle['color'],
                             (int(particle['x']), int(particle['y'])),
                             int(particle['size']))

    # ======================================================================
    #  Unused (kept for reference)
    # ======================================================================

    def _draw_arena_circle(self, screen):
        """Central arena circle with neon glow (currently disabled in draw())."""
        pygame.draw.circle(screen, self.arena_color,
                         (self.arena_center_x, self.arena_center_y),
                         self.arena_radius, 3)

        self._glow_surface.fill(self._transparent)
        pygame.draw.circle(self._glow_surface, (*self.cyan_glow, 30),
                         (self.arena_center_x, self.arena_center_y),
                         self.arena_radius + 5, 2)
        screen.blit(self._glow_surface, (0, 0))

        line_length = 40
        pygame.draw.line(screen, self.arena_color,
                        (self.arena_center_x - line_length, self.arena_center_y),
                        (self.arena_center_x + line_length, self.arena_center_y), 2)
        pygame.draw.line(screen, self.arena_color,
                        (self.arena_center_x, self.arena_center_y - line_length),
                        (self.arena_center_x, self.arena_center_y + line_length), 2)
