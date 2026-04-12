"""
Effect Renderer - 이펙트 렌더링 모듈
파티클, 폭발, 레이저, 특수 효과 등 렌더링
"""
import pygame
import pygame.gfxdraw
import math
import random
from typing import List, Tuple, Dict, Any, Optional
from utils.color_utils import get_neon_color, blend_colors, NEON_PALETTE
from utils.particle_utils import update_particles, draw_particles
from utils.draw_utils import draw_glow_effect

# --- Surface Pool: 크기별 재사용 가능한 SRCALPHA Surface 캐시 ---
_surface_pool: dict = {}

def _get_pooled_surface(w: int, h: int) -> pygame.Surface:
    """크기별 Surface를 캐시에서 가져오거나 새로 생성 (매 프레임 new 방지)"""
    key = (w, h)
    surf = _surface_pool.get(key)
    if surf is None:
        surf = pygame.Surface((w, h), pygame.SRCALPHA)
        _surface_pool[key] = surf
    else:
        surf.fill((0, 0, 0, 0))
    return surf


class EffectRenderer:
    """이펙트 렌더링 클래스"""

    def __init__(self, screen: pygame.Surface):
        """초기화

        Args:
            screen: 렌더링할 화면
        """
        self.screen = screen
        self.width = screen.get_width()
        self.height = screen.get_height()

        # 파티클 시스템
        self.particles = []
        self.explosions = []
        self.lasers = []
        self.lightning_bolts = []
        self.shockwaves = []

        # 화면 효과
        self.screen_shake_intensity = 0
        self.screen_flash_alpha = 0
        self.screen_flash_color = (255, 255, 255)

        # 화면 플래시용 재사용 Surface (한 번만 생성)
        self._flash_surface = None

    def add_explosion(self, pos: Tuple[float, float], size: str = "medium",
                     color: Optional[Tuple[int, int, int]] = None):
        """폭발 효과 추가"""
        sizes = {
            "small": (10, 20, 30),
            "medium": (20, 40, 60),
            "large": (30, 60, 100)
        }
        particle_count, min_radius, max_radius = sizes.get(size, (20, 40, 60))

        if color is None:
            color = (255, 150, 0)

        explosion = {
            'pos': pos,
            'timer': 30,
            'max_radius': max_radius,
            'current_radius': 0,
            'color': color,
            'particles': []
        }

        # 파티클 생성
        for _ in range(particle_count):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 8)
            explosion['particles'].append({
                'x': pos[0],
                'y': pos[1],
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': random.randint(20, 40),
                'color': blend_colors(color, (255, 255, 0), random.random()),
                'size': random.randint(3, 6)
            })

        self.explosions.append(explosion)

        # 화면 흔들림
        if size == "large":
            self.add_screen_shake(10)

    def add_laser(self, start_pos: Tuple[float, float], end_pos: Tuple[float, float],
                 width: int = 5, color: Tuple[int, int, int] = (255, 0, 0),
                 duration: int = 10):
        """레이저 효과 추가"""
        laser = {
            'start': start_pos,
            'end': end_pos,
            'width': width,
            'color': color,
            'timer': duration,
            'max_timer': duration,
            'particles': []
        }

        # 레이저 경로에 파티클 생성
        distance = math.sqrt((end_pos[0] - start_pos[0])**2 +
                           (end_pos[1] - start_pos[1])**2)
        if distance > 0:
            steps = int(distance / 20)
            for i in range(steps):
                t = i / steps
                x = start_pos[0] + (end_pos[0] - start_pos[0]) * t
                y = start_pos[1] + (end_pos[1] - start_pos[1]) * t

                if random.random() < 0.5:
                    laser['particles'].append({
                        'x': x + random.uniform(-5, 5),
                        'y': y + random.uniform(-5, 5),
                        'vx': random.uniform(-1, 1),
                        'vy': random.uniform(-1, 1),
                        'life': 10,
                        'color': get_neon_color(color),
                        'size': random.randint(1, 3)
                    })

        self.lasers.append(laser)

    def add_lightning(self, start_pos: Tuple[float, float], end_pos: Tuple[float, float],
                     branches: int = 3):
        """번개 효과 추가"""
        lightning = {
            'segments': self._generate_lightning_path(start_pos, end_pos, branches),
            'timer': 15,
            'color': (200, 200, 255),
            'width': 3
        }
        self.lightning_bolts.append(lightning)

        # 번개 끝점에 작은 폭발
        self.add_explosion(end_pos, "small", (200, 200, 255))

    def add_shockwave(self, center: Tuple[float, float], max_radius: float = 100,
                     color: Tuple[int, int, int] = (255, 255, 255)):
        """충격파 효과 추가"""
        shockwave = {
            'center': center,
            'current_radius': 0,
            'max_radius': max_radius,
            'timer': 20,
            'color': color,
            'thickness': 3
        }
        self.shockwaves.append(shockwave)

    def add_screen_shake(self, intensity: int = 5, duration: int = 10):
        """화면 흔들림 추가"""
        self.screen_shake_intensity = max(self.screen_shake_intensity, intensity)
        self.screen_shake_timer = duration

    def add_screen_flash(self, color: Tuple[int, int, int] = (255, 255, 255),
                        alpha: int = 100):
        """화면 플래시 효과"""
        self.screen_flash_color = color
        self.screen_flash_alpha = alpha

    def update(self):
        """이펙트 업데이트"""
        self._update_explosions()
        self._update_lasers()
        self._update_lightning()
        self._update_shockwaves()
        self._update_screen_effects()
        self.particles = update_particles(self.particles)

    def render(self):
        """모든 이펙트 렌더링"""
        shake_offset = self._get_screen_shake_offset()

        # 충격파 (가장 뒤)
        self._render_shockwaves()

        # 레이저
        self._render_lasers()

        # 번개
        self._render_lightning()

        # 폭발
        self._render_explosions()

        # 일반 파티클
        draw_particles(self.screen, self.particles)

        # 화면 플래시 (가장 앞)
        self._render_screen_flash()

        return shake_offset

    def _update_explosions(self):
        """폭발 업데이트"""
        updated = []
        for explosion in self.explosions:
            explosion['timer'] -= 1
            explosion['current_radius'] = (1 - explosion['timer'] / 30) * explosion['max_radius']

            # 파티클 업데이트
            updated_particles = []
            for particle in explosion['particles']:
                particle['x'] += particle['vx']
                particle['y'] += particle['vy']
                particle['vx'] *= 0.95
                particle['vy'] += 0.3  # 중력
                particle['life'] -= 1
                particle['size'] *= 0.95

                if particle['life'] > 0 and particle['size'] > 0.5:
                    updated_particles.append(particle)

            explosion['particles'] = updated_particles

            if explosion['timer'] > 0:
                updated.append(explosion)

        self.explosions = updated

    def _update_lasers(self):
        """레이저 업데이트"""
        updated = []
        for laser in self.lasers:
            laser['timer'] -= 1

            # 파티클 업데이트
            updated_particles = []
            for particle in laser['particles']:
                particle['x'] += particle['vx']
                particle['y'] += particle['vy']
                particle['life'] -= 1

                if particle['life'] > 0:
                    updated_particles.append(particle)

            laser['particles'] = updated_particles

            if laser['timer'] > 0:
                updated.append(laser)

        self.lasers = updated

    def _update_lightning(self):
        """번개 업데이트"""
        updated = []
        for lightning in self.lightning_bolts:
            lightning['timer'] -= 1

            # 깜빡임 효과
            if lightning['timer'] % 3 == 0:
                lightning['width'] = random.randint(2, 4)

            if lightning['timer'] > 0:
                updated.append(lightning)

        self.lightning_bolts = updated

    def _update_shockwaves(self):
        """충격파 업데이트"""
        updated = []
        for wave in self.shockwaves:
            wave['timer'] -= 1
            progress = 1 - (wave['timer'] / 20)
            wave['current_radius'] = wave['max_radius'] * progress

            # 두께 감소
            wave['thickness'] = max(1, 3 * (1 - progress))

            if wave['timer'] > 0:
                updated.append(wave)

        self.shockwaves = updated

    def _update_screen_effects(self):
        """화면 효과 업데이트"""
        # 화면 흔들림
        if hasattr(self, 'screen_shake_timer') and self.screen_shake_timer > 0:
            self.screen_shake_timer -= 1
            if self.screen_shake_timer <= 0:
                self.screen_shake_intensity = 0

        # 화면 플래시
        if self.screen_flash_alpha > 0:
            self.screen_flash_alpha -= 5

    def _render_explosions(self):
        """폭발 렌더링 - Surface 풀 + gfxdraw 사용"""
        for explosion in self.explosions:
            # 폭발 원
            cr = int(explosion['current_radius'])
            if cr > 0:
                alpha = int(150 * (explosion['timer'] / 30))
                if alpha > 0:
                    size = cr * 2
                    exp_surf = _get_pooled_surface(size, size)

                    # 여러 레이어로 그리기
                    for i in range(3):
                        radius = int(cr * (1 - i * 0.2))
                        color = blend_colors(explosion['color'], (255, 255, 255), i * 0.3)
                        layer_alpha = alpha - i * 30
                        if layer_alpha > 0 and radius > 0:
                            pygame.draw.circle(exp_surf, (*color, layer_alpha),
                                             (cr, cr), radius)

                    pos = (explosion['pos'][0] - cr,
                          explosion['pos'][1] - cr)
                    self.screen.blit(exp_surf, pos, special_flags=pygame.BLEND_ADD)

            # 파티클 - gfxdraw 직접 렌더링
            for particle in explosion['particles']:
                alpha = int(255 * (particle['life'] / 40))
                size = int(particle['size'])
                if alpha > 0 and size > 0:
                    px = int(particle['x'])
                    py = int(particle['y'])
                    r, g, b = particle['color']
                    bright_r = min(255, r + alpha // 2)
                    bright_g = min(255, g + alpha // 2)
                    bright_b = min(255, b + alpha // 2)
                    pygame.gfxdraw.filled_circle(self.screen, px, py, size,
                                                 (bright_r, bright_g, bright_b, alpha))

    def _render_lasers(self):
        """레이저 렌더링"""
        for laser in self.lasers:
            alpha = int(255 * (laser['timer'] / laser['max_timer']))

            if alpha > 0:
                # 레이저 코어
                pygame.draw.line(self.screen, laser['color'],
                               laser['start'], laser['end'], laser['width'])

                # 글로우 효과
                for i in range(1, 4):
                    glow_width = laser['width'] + i * 3
                    glow_alpha = alpha // (i + 1)
                    if glow_alpha > 0:
                        dx = laser['end'][0] - laser['start'][0]
                        dy = laser['end'][1] - laser['start'][1]
                        length = math.sqrt(dx**2 + dy**2)

                        if length > 0:
                            angle = math.atan2(dy, dx)
                            glow_color = blend_colors(laser['color'], (255, 255, 255), 0.3)

                            for j in range(-glow_width//2, glow_width//2 + 1):
                                offset_x = math.sin(angle) * j
                                offset_y = -math.cos(angle) * j

                                start_glow = (laser['start'][0] + offset_x,
                                            laser['start'][1] + offset_y)
                                end_glow = (laser['end'][0] + offset_x,
                                          laser['end'][1] + offset_y)

                                line_alpha = glow_alpha * (1 - abs(j) / (glow_width/2))
                                if line_alpha > 0:
                                    pygame.draw.line(self.screen,
                                                   (*glow_color, int(line_alpha)),
                                                   start_glow, end_glow, 1)

                # 파티클
                for particle in laser['particles']:
                    if particle['life'] > 0:
                        pygame.draw.circle(self.screen, particle['color'],
                                         (int(particle['x']), int(particle['y'])),
                                         particle['size'])

    def _render_lightning(self):
        """번개 렌더링"""
        for lightning in self.lightning_bolts:
            alpha = int(255 * (lightning['timer'] / 15))

            if alpha > 0:
                # 번개 세그먼트 그리기
                for i in range(len(lightning['segments']) - 1):
                    start = lightning['segments'][i]
                    end = lightning['segments'][i + 1]

                    # 메인 번개
                    pygame.draw.line(self.screen, lightning['color'],
                                   start, end, lightning['width'])

                    # 글로우
                    for j in range(1, 3):
                        glow_alpha = alpha // (j + 1)
                        if glow_alpha > 0:
                            pygame.draw.line(self.screen,
                                           (*lightning['color'], glow_alpha),
                                           start, end, lightning['width'] + j * 2)

    def _render_shockwaves(self):
        """충격파 렌더링 - gfxdraw 직접 렌더링 (Surface 생성 제거)"""
        for wave in self.shockwaves:
            cr = int(wave['current_radius'])
            if cr > 0:
                alpha = int(200 * (wave['timer'] / 20))

                if alpha > 0:
                    cx = int(wave['center'][0])
                    cy = int(wave['center'][1])
                    r, g, b = wave['color']

                    # 여러 개의 동심원으로 충격파 표현 - gfxdraw 직접 렌더링
                    for i in range(3):
                        radius = cr - i * 5
                        if radius > 0:
                            ring_alpha = min(255, alpha - i * 50)
                            if ring_alpha > 0:
                                pygame.gfxdraw.aacircle(self.screen, cx, cy, radius,
                                                        (r, g, b, ring_alpha))

    def _render_screen_flash(self):
        """화면 플래시 렌더링 - 재사용 Surface"""
        if self.screen_flash_alpha > 0:
            # 화면 크기 변경 시에만 Surface 재생성
            if (self._flash_surface is None or
                self._flash_surface.get_width() != self.width or
                self._flash_surface.get_height() != self.height):
                self._flash_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

            self._flash_surface.fill((*self.screen_flash_color, self.screen_flash_alpha))
            self.screen.blit(self._flash_surface, (0, 0), special_flags=pygame.BLEND_ADD)

    def _get_screen_shake_offset(self) -> Tuple[int, int]:
        """화면 흔들림 오프셋 계산"""
        if self.screen_shake_intensity > 0:
            offset_x = random.randint(-self.screen_shake_intensity,
                                     self.screen_shake_intensity)
            offset_y = random.randint(-self.screen_shake_intensity,
                                     self.screen_shake_intensity)
            return (offset_x, offset_y)
        return (0, 0)

    def _generate_lightning_path(self, start: Tuple[float, float],
                                end: Tuple[float, float],
                                branches: int) -> List[Tuple[float, float]]:
        """번개 경로 생성"""
        segments = [start]

        # 주 경로
        steps = 10
        for i in range(1, steps):
            t = i / steps
            base_x = start[0] + (end[0] - start[0]) * t
            base_y = start[1] + (end[1] - start[1]) * t

            # 랜덤 오프셋
            offset_x = random.uniform(-20, 20) * (1 - t)
            offset_y = random.uniform(-20, 20) * (1 - t)

            segments.append((base_x + offset_x, base_y + offset_y))

        segments.append(end)

        # 분기 추가
        for _ in range(branches):
            if len(segments) > 2:
                branch_start_idx = random.randint(1, len(segments) - 2)
                branch_start = segments[branch_start_idx]

                branch_angle = random.uniform(-math.pi/3, math.pi/3)
                branch_length = random.uniform(30, 60)

                branch_end = (branch_start[0] + math.cos(branch_angle) * branch_length,
                            branch_start[1] + math.sin(branch_angle) * branch_length)

        return segments

    def clear_all(self):
        """모든 이펙트 클리어"""
        self.particles.clear()
        self.explosions.clear()
        self.lasers.clear()
        self.lightning_bolts.clear()
        self.shockwaves.clear()
        self.screen_shake_intensity = 0
        self.screen_flash_alpha = 0
