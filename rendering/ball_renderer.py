"""
Ball Renderer - 공 렌더링 모듈
draw_objects_module.py에서 분리한 공 관련 렌더링 코드
"""
import pygame
import pygame.gfxdraw
import math
import random
from typing import Tuple, List, Optional
from utils.color_utils import get_neon_color, blend_colors
from utils.particle_utils import create_trail_particle, create_spark_particle
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
        surf.fill((0, 0, 0, 0))  # 이전 내용 클리어
    return surf


class BallRenderer:
    """공 렌더링 클래스"""

    def __init__(self, screen: pygame.Surface):
        """초기화

        Args:
            screen: 렌더링할 화면
        """
        self.screen = screen
        self.width = screen.get_width()
        self.height = screen.get_height()

        # 트레일 설정
        self.trail_points = []
        self.max_trail_length = 20
        self.trail_fade_speed = 0.9

        # 파티클 설정
        self.particles = []

        # 애니메이션 설정
        self.rotation_angle = 0
        self.pulse_scale = 1.0
        self.pulse_direction = 1

    def render(self, ball_pos: Tuple[float, float], ball_radius: int = 10,
              ball_color: Tuple[int, int, int] = (255, 255, 255),
              power_shot: bool = False, curve_ball: bool = False,
              ghost_ball: bool = False, velocity: Optional[Tuple[float, float]] = None):
        """공 렌더링

        Args:
            ball_pos: 공 위치 (x, y)
            ball_radius: 공 반지름
            ball_color: 공 색상
            power_shot: 파워샷 활성화 여부
            curve_ball: 커브볼 활성화 여부
            ghost_ball: 고스트볼 활성화 여부
            velocity: 공 속도 벡터 (vx, vy)
        """
        x, y = ball_pos

        # 트레일 업데이트
        self._update_trail(ball_pos, ball_color)

        # 파티클 업데이트
        if velocity:
            self._update_particles(ball_pos, velocity, power_shot)

        # 트레일 그리기
        self._draw_trail()

        # 파티클 그리기
        self._draw_particles()

        # 특수 효과
        if power_shot:
            self._draw_power_shot_effect(ball_pos, ball_radius)

        if curve_ball:
            self._draw_curve_ball_effect(ball_pos, ball_radius)

        if ghost_ball:
            self._draw_ghost_ball_effect(ball_pos, ball_radius, ball_color)
        else:
            # 일반 공 그리기
            self._draw_normal_ball(ball_pos, ball_radius, ball_color)

        # 회전 애니메이션
        if velocity:
            self.rotation_angle += math.sqrt(velocity[0]**2 + velocity[1]**2) * 2

    def _update_trail(self, ball_pos: Tuple[float, float], ball_color: Tuple[int, int, int]):
        """트레일 업데이트"""
        # 새 위치 추가
        self.trail_points.append({
            'pos': ball_pos,
            'color': ball_color,
            'alpha': 255,
            'size': 8
        })

        # 트레일 길이 제한
        if len(self.trail_points) > self.max_trail_length:
            self.trail_points.pop(0)

        # 알파값 감소
        for i, point in enumerate(self.trail_points):
            point['alpha'] *= self.trail_fade_speed
            point['size'] *= 0.95
            if point['alpha'] < 5:
                point['alpha'] = 0

    def _update_particles(self, ball_pos: Tuple[float, float],
                         velocity: Tuple[float, float], power_shot: bool):
        """파티클 업데이트"""
        # 새 파티클 생성 (확률적)
        if random.random() < 0.3:
            particle = {
                'pos': list(ball_pos),
                'vel': [velocity[0] * -0.2 + random.uniform(-1, 1),
                        velocity[1] * -0.2 + random.uniform(-1, 1)],
                'life': 30,
                'color': (255, 200, 100) if power_shot else (100, 200, 255),
                'size': random.randint(2, 4)
            }
            self.particles.append(particle)

        # 파티클 업데이트
        updated_particles = []
        for particle in self.particles:
            particle['pos'][0] += particle['vel'][0]
            particle['pos'][1] += particle['vel'][1]
            particle['life'] -= 1
            particle['size'] *= 0.95

            if particle['life'] > 0:
                updated_particles.append(particle)

        self.particles = updated_particles

    def _draw_trail(self):
        """트레일 그리기 - gfxdraw 직접 렌더링 (Surface 생성 제거)"""
        for point in self.trail_points:
            if point['alpha'] > 5:
                radius = int(point['size'])
                if radius > 0:
                    px = int(point['pos'][0])
                    py = int(point['pos'][1])
                    alpha = min(255, int(point['alpha']))
                    r, g, b = point['color']
                    pygame.gfxdraw.filled_circle(self.screen, px, py, radius, (r, g, b, alpha))

    def _draw_particles(self):
        """파티클 그리기 - gfxdraw 직접 렌더링 (Surface 생성 제거)"""
        for particle in self.particles:
            alpha = int(255 * (particle['life'] / 30))
            size = int(particle['size'])
            if alpha > 0 and size > 0:
                px = int(particle['pos'][0])
                py = int(particle['pos'][1])
                r, g, b = particle['color']
                pygame.gfxdraw.filled_circle(self.screen, px, py, size, (r, g, b, alpha))

    def _draw_normal_ball(self, ball_pos: Tuple[float, float], ball_radius: int,
                         ball_color: Tuple[int, int, int]):
        """일반 공 그리기"""
        x, y = ball_pos

        # 글로우 효과
        draw_glow_effect(self.screen, (int(x), int(y)), ball_radius,
                        get_neon_color(ball_color), intensity=2)

        # 공 본체
        pygame.draw.circle(self.screen, ball_color, (int(x), int(y)), ball_radius)

        # 하이라이트
        highlight_offset = ball_radius // 3
        highlight_radius = ball_radius // 4
        pygame.draw.circle(self.screen, (255, 255, 255),
                         (int(x - highlight_offset), int(y - highlight_offset)),
                         highlight_radius)

    def _draw_power_shot_effect(self, ball_pos: Tuple[float, float], ball_radius: int):
        """파워샷 효과 그리기 - Surface 풀 사용"""
        x, y = ball_pos

        # 화염 효과
        colors = [(255, 100, 0), (255, 150, 0), (255, 200, 0)]
        for i in range(3):
            flame_radius = ball_radius + i * 5
            flame_alpha = 100 - i * 30

            size = flame_radius * 2
            flame_surf = _get_pooled_surface(size, size)

            color = colors[i]
            pygame.draw.circle(flame_surf, (*color, flame_alpha),
                             (flame_radius, flame_radius), flame_radius)
            self.screen.blit(flame_surf,
                           (x - flame_radius, y - flame_radius),
                           special_flags=pygame.BLEND_ADD)

    def _draw_curve_ball_effect(self, ball_pos: Tuple[float, float], ball_radius: int):
        """커브볼 효과 그리기 - gfxdraw 직접 렌더링 (Surface 생성 제거)"""
        x, y = ball_pos

        # 회전 궤적 표시
        num_arcs = 3
        for i in range(num_arcs):
            arc_angle = self.rotation_angle + i * (math.pi * 2 / num_arcs)
            arc_x = int(x + math.cos(arc_angle) * (ball_radius + 5))
            arc_y = int(y + math.sin(arc_angle) * (ball_radius + 5))

            pygame.gfxdraw.filled_circle(self.screen, arc_x, arc_y, 3, (100, 255, 100, 150))

    def _draw_ghost_ball_effect(self, ball_pos: Tuple[float, float], ball_radius: int,
                               ball_color: Tuple[int, int, int]):
        """고스트볼 효과 그리기 - Surface 풀 사용 (복합 알파 합성)"""
        x, y = ball_pos

        size = ball_radius * 4
        ghost_surf = _get_pooled_surface(size, size)

        # 잔상 효과
        for i in range(3):
            offset = i * 3
            alpha = 80 - i * 25
            color_with_alpha = (*ball_color, alpha)
            pygame.draw.circle(ghost_surf, color_with_alpha,
                             (ball_radius * 2 + offset, ball_radius * 2 + offset),
                             ball_radius)

        self.screen.blit(ghost_surf, (x - ball_radius * 2, y - ball_radius * 2))

    def clear_effects(self):
        """모든 효과 초기화"""
        self.trail_points.clear()
        self.particles.clear()
        self.rotation_angle = 0
        self.pulse_scale = 1.0

class BallEffectManager:
    """공 이펙트 매니저"""

    def __init__(self):
        """초기화"""
        self.hit_effects = []
        self.charge_effects = []
        self.special_effects = []

    def add_hit_effect(self, pos: Tuple[float, float], intensity: float = 1.0):
        """히트 이펙트 추가"""
        effect = {
            'pos': pos,
            'timer': 30,
            'intensity': intensity,
            'particles': []
        }

        # 파티클 생성
        for _ in range(int(10 * intensity)):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 5) * intensity
            effect['particles'].append({
                'x': pos[0],
                'y': pos[1],
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': 20,
                'color': (255, 255, 100)
            })

        self.hit_effects.append(effect)

    def update(self):
        """이펙트 업데이트"""
        # 히트 이펙트 업데이트
        updated_effects = []
        for effect in self.hit_effects:
            effect['timer'] -= 1

            # 파티클 업데이트
            updated_particles = []
            for particle in effect['particles']:
                particle['x'] += particle['vx']
                particle['y'] += particle['vy']
                particle['vx'] *= 0.95
                particle['vy'] *= 0.95
                particle['life'] -= 1

                if particle['life'] > 0:
                    updated_particles.append(particle)

            effect['particles'] = updated_particles

            if effect['timer'] > 0:
                updated_effects.append(effect)

        self.hit_effects = updated_effects

    def render(self, screen: pygame.Surface):
        """이펙트 렌더링 - gfxdraw 직접 렌더링 (Surface 생성 제거)"""
        for effect in self.hit_effects:
            for particle in effect['particles']:
                alpha = int(255 * (particle['life'] / 20))
                if alpha > 0:
                    px = int(particle['x'])
                    py = int(particle['y'])
                    r, g, b = particle['color']
                    # BLEND_ADD 대신 밝은 색상으로 직접 그리기
                    bright_r = min(255, r + alpha // 2)
                    bright_g = min(255, g + alpha // 2)
                    bright_b = min(255, b + alpha // 2)
                    pygame.gfxdraw.filled_circle(screen, px, py, 3, (bright_r, bright_g, bright_b, alpha))
