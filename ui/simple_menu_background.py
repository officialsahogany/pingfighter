"""
심플하고 세련된 사이버펑크 메인 메뉴 배경
— 패럴랙스, 성운, 3레이어 별밭, 비네팅, UI 패널, 마우스 트레일 추가
"""
import pygame
import math
import random
from typing import List, Tuple

# 파티클 Surface 캐시 (크기/색상/알파별)
_menu_particle_cache = {}

def get_cached_particle(size: int, color: tuple, alpha: int, shape: str = "circle") -> pygame.Surface:
    """메뉴 파티클 Surface 캐시 (매 프레임 생성 방지)"""
    # 크기 버킷팅 (2픽셀 단위)
    size_bucket = max(2, (size // 2) * 2)
    # 알파 버킷팅 (20 단위)
    alpha_bucket = max(0, min(255, (alpha // 20) * 20))
    # 색상 버킷팅 (16 단위로 양자화)
    color_bucket = tuple((c // 16) * 16 for c in color[:3])

    key = (size_bucket, color_bucket, alpha_bucket, shape)
    if key not in _menu_particle_cache:
        if len(_menu_particle_cache) > 100:
            _menu_particle_cache.clear()
        surf_size = size_bucket * 3
        surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
        center = surf_size // 2
        if shape == "circle":
            pygame.draw.circle(surf, (*color_bucket, alpha_bucket), (center, center), size_bucket // 2)
        _menu_particle_cache[key] = surf
    return _menu_particle_cache[key]

class SimpleMenuBackground:
    """심플한 사이버펑크 스타일 배경 관리 클래스 + 애니 감성"""

    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.time = 0

        # 사이버펑크 색상 팔레트 (차분한 톤)
        self.colors = {
            'bg_top': (15, 25, 45),      # 상단 (어두운 남색)
            'bg_bottom': (25, 35, 55),    # 하단 (약간 밝은 남색)
            'grid': (0, 100, 150, 15),    # 은은한 그리드
            'neon_cyan': (0, 200, 255),
            'neon_purple': (150, 100, 255),
            'particle': (100, 200, 255, 50)
        }

        # 심플한 공전 행성들
        self.planets = self._create_planets()

        # === 애니 감성 요소들 ===
        # 키라키라 반짝이 효과
        self.sparkles = []
        for _ in range(30):
            self.sparkles.append({
                'x': random.randint(0, width),
                'y': random.randint(0, height),
                'size': random.uniform(2, 6),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(2, 5),
                'color': random.choice([
                    (255, 200, 255),  # 핑크
                    (200, 255, 255),  # 시안
                    (255, 255, 200),  # 옐로우
                    (255, 220, 240),  # 라이트 핑크
                ])
            })

        # 하트/별 파티클
        self.cute_particles = []
        for _ in range(12):
            self.cute_particles.append({
                'x': random.randint(0, width),
                'y': random.randint(0, height),
                'vx': random.uniform(-0.3, 0.3),
                'vy': random.uniform(-0.5, -0.1),  # 위로 떠오름
                'type': random.choice(['heart', 'star', 'sparkle']),
                'size': random.uniform(8, 16),
                'alpha': random.randint(100, 200),
                'rotation': random.uniform(0, math.pi * 2),
                'rot_speed': random.uniform(-0.02, 0.02),
                'color': random.choice([
                    (255, 150, 200),  # 핑크
                    (200, 150, 255),  # 퍼플
                    (255, 220, 180),  # 피치
                ])
            })

        # 무지개빛 오로라 웨이브
        self.aurora_waves = []
        for i in range(5):
            self.aurora_waves.append({
                'y_offset': random.uniform(0, height * 0.4),
                'amplitude': random.uniform(20, 50),
                'frequency': random.uniform(0.003, 0.008),
                'phase': random.uniform(0, math.pi * 2),
                'speed': random.uniform(0.3, 0.8),
                'hue_offset': i * 60,  # 무지개 색상 오프셋
                'alpha': random.randint(15, 35)
            })

        # 별똥별 (유성)
        self.shooting_stars = []

        # =========================================================
        # [NEW] 패럴랙스 시스템
        # =========================================================
        self._prev_mouse_pos = (width // 2, height // 2)
        self._target_px = 0.0   # 목표 패럴랙스 X
        self._target_py = 0.0   # 목표 패럴랙스 Y
        self._cur_px = 0.0      # 현재(보간된) 패럴랙스 X
        self._cur_py = 0.0      # 현재(보간된) 패럴랙스 Y

        # =========================================================
        # [NEW] 마우스 트레일 파티클
        # =========================================================
        self.mouse_trail: List[dict] = []
        self._trail_timer = 0.0

        # =========================================================
        # [NEW] 3레이어 별밭 (근경/중경/원경)
        # =========================================================
        self.star_layers = self._create_star_layers()

        # =========================================================
        # [NEW] 성운/비네팅/UI패널 캐시 (lazy init)
        # =========================================================
        self._nebula_surface: pygame.Surface | None = None
        self._nebula_margin = 0
        self._gradient_surface: pygame.Surface | None = None
        self._vignette_surface: pygame.Surface | None = None
        self._ui_panel_surface: pygame.Surface | None = None

    # ==============================================================
    #  행성 생성
    # ==============================================================
    def _create_planets(self) -> List[dict]:
        """귀여운 애니 스타일 행성들 생성 - 하트, 별, 사탕, 리본 테마"""
        center_x = self.width // 2
        center_y = self.height // 2

        planets = [
            # 중심 - 큰 핑크 하트 (태양 대신)
            {
                'type': 'heart_sun',
                'name': '사랑의 별',
                'x': center_x,
                'y': center_y,
                'radius': 80,
                'color': (255, 100, 150),       # 핑크
                'color2': (255, 150, 180),      # 연핑크
                'color3': (255, 80, 130),       # 진핑크
                'glow_color': (255, 150, 200),
                'orbit_radius': 0,
                'orbit_speed': 0,
                'orbit_angle': 0,
                'rotation': 0,
                'rotation_speed': 0.005,
                'pulse': True,
                'pulse_phase': 0,
                'sparkles': [],  # 반짝이 효과
                'hearts_orbit': []  # 주변 미니 하트들
            },
            # 라벤더 별 행성
            {
                'type': 'star_planet',
                'name': '라벤더 스타',
                'radius': 35,
                'color': (200, 150, 255),  # 라벤더
                'color2': (230, 200, 255),
                'glow_color': (220, 180, 255),
                'orbit_radius': 130,
                'orbit_speed': 0.4,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.02,
                'trail': [],
                'star_points': 5,
                'twinkle_phase': random.uniform(0, math.pi * 2)
            },
            # 민트 구슬 행성
            {
                'type': 'candy_planet',
                'name': '민트 캔디',
                'radius': 30,
                'color': (150, 255, 220),  # 민트
                'color2': (200, 255, 240),
                'glow_color': (180, 255, 230),
                'orbit_radius': 170,
                'orbit_speed': 0.32,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.015,
                'trail': [],
                'stripes': True,  # 사탕 줄무늬
                'stripe_color': (255, 255, 255)
            },
            # 피치 하트 행성
            {
                'type': 'heart_planet',
                'name': '피치 하트',
                'radius': 40,
                'color': (255, 180, 150),  # 피치
                'color2': (255, 200, 180),
                'glow_color': (255, 200, 170),
                'orbit_radius': 220,
                'orbit_speed': 0.25,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.01,
                'trail': [],
                'mini_hearts': []  # 주변 미니 하트들
            },
            # 레몬 별 행성
            {
                'type': 'star_planet',
                'name': '레몬 스타',
                'radius': 32,
                'color': (255, 255, 150),  # 레몬 옐로우
                'color2': (255, 255, 200),
                'glow_color': (255, 255, 180),
                'orbit_radius': 270,
                'orbit_speed': 0.2,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.018,
                'trail': [],
                'star_points': 6,
                'twinkle_phase': random.uniform(0, math.pi * 2)
            },
            # 코튼캔디 행성 (리본 고리)
            {
                'type': 'ribbon_planet',
                'name': '코튼캔디',
                'radius': 55,
                'color': (255, 180, 220),  # 핑크
                'color2': (200, 180, 255),  # 보라
                'glow_color': (255, 200, 230),
                'orbit_radius': 340,
                'orbit_speed': 0.12,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.025,
                'trail': [],
                'ribbons': {
                    'inner_radius': 65,
                    'outer_radius': 90,
                    'colors': [(255, 150, 200), (200, 150, 255), (150, 200, 255)],
                    'rotation': 0,
                    'rotation_speed': 0.015
                }
            },
            # 하늘색 보석 행성
            {
                'type': 'gem_planet',
                'name': '스카이 젬',
                'radius': 38,
                'color': (150, 200, 255),  # 스카이 블루
                'color2': (200, 230, 255),
                'glow_color': (180, 220, 255),
                'orbit_radius': 400,
                'orbit_speed': 0.09,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.012,
                'trail': [],
                'facets': 8,  # 보석 면 개수
                'shimmer_phase': random.uniform(0, math.pi * 2)
            },
            # 보라색 별 행성
            {
                'type': 'star_planet',
                'name': '바이올렛 스타',
                'radius': 36,
                'color': (180, 100, 255),  # 바이올렛
                'color2': (220, 150, 255),
                'glow_color': (200, 130, 255),
                'orbit_radius': 460,
                'orbit_speed': 0.065,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': -0.015,
                'trail': [],
                'star_points': 4,
                'twinkle_phase': random.uniform(0, math.pi * 2)
            },
            # 핑크 작은 하트
            {
                'type': 'mini_heart',
                'name': '쁘띠 하트',
                'radius': 20,
                'color': (255, 150, 180),  # 베이비 핑크
                'color2': (255, 180, 200),
                'glow_color': (255, 170, 200),
                'orbit_radius': 510,
                'orbit_speed': 0.05,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.008,
                'trail': [],
                'wobble': True  # 흔들림 효과
            }
        ]

        # 행성별 특수 효과 초기화
        for planet in planets:
            if planet['type'] == 'heart_sun':
                # 중심 하트 주변 반짝이
                for _ in range(15):
                    planet['sparkles'].append({
                        'angle': random.uniform(0, math.pi * 2),
                        'distance': random.uniform(1.1, 1.8),
                        'size': random.uniform(3, 8),
                        'phase': random.uniform(0, math.pi * 2),
                        'speed': random.uniform(1.5, 3.0)
                    })
                # 주변 미니 하트들
                for i in range(6):
                    planet['hearts_orbit'].append({
                        'angle': i * math.pi / 3,
                        'distance': random.uniform(1.3, 1.6),
                        'size': random.uniform(8, 15),
                        'speed': random.uniform(0.3, 0.6),
                        'color': random.choice([
                            (255, 150, 200), (255, 200, 220), (255, 180, 210)
                        ])
                    })
            elif planet['type'] == 'heart_planet':
                # 하트 행성 주변 미니 하트
                for _ in range(4):
                    planet['mini_hearts'].append({
                        'angle': random.uniform(0, math.pi * 2),
                        'distance': random.uniform(1.5, 2.5),
                        'size': random.uniform(5, 10),
                        'speed': random.uniform(0.8, 1.5)
                    })
            elif planet['type'] == 'ribbon_planet':
                # 리본 파티클
                planet['ribbon_particles'] = []
                for _ in range(30):
                    planet['ribbon_particles'].append({
                        'angle': random.uniform(0, math.pi * 2),
                        'radius': random.uniform(planet['ribbons']['inner_radius'],
                                                planet['ribbons']['outer_radius']),
                        'speed': random.uniform(0.01, 0.03),
                        'size': random.uniform(2, 5),
                        'color_idx': random.randint(0, 2)
                    })

        return planets

    # ==============================================================
    #  [NEW] 3레이어 별밭 생성
    # ==============================================================
    def _create_star_layers(self) -> dict:
        """원경/중경/근경 3단계 별밭 생성 — 패럴랙스 깊이감용"""
        w, h = self.width, self.height
        layers: dict = {'far': [], 'mid': [], 'near': []}

        # 원경: 100개 — 아주 작고 희미, 느린 패럴랙스
        for _ in range(100):
            layers['far'].append({
                'x': random.randint(-20, w + 20),
                'y': random.randint(-20, h + 20),
                'brightness': random.uniform(0.15, 0.45),
                'twinkle_speed': random.uniform(0.3, 1.0),
                'twinkle_offset': random.uniform(0, math.pi * 2),
            })

        # 중경: 40개 — 작지만 색상 있고, 중간 패럴랙스
        for _ in range(40):
            layers['mid'].append({
                'x': random.randint(-20, w + 20),
                'y': random.randint(-20, h + 20),
                'brightness': random.uniform(0.4, 0.8),
                'size': random.choice([1, 1, 2]),
                'twinkle_speed': random.uniform(0.8, 2.0),
                'twinkle_offset': random.uniform(0, math.pi * 2),
                'color': random.choice([
                    (200, 220, 255), (255, 220, 200),
                    (220, 200, 255), (255, 255, 255),
                ])
            })

        # 근경: 15개 — 밝고 크며, 십자 플레어, 강한 패럴랙스
        for _ in range(15):
            layers['near'].append({
                'x': random.randint(-20, w + 20),
                'y': random.randint(-20, h + 20),
                'brightness': random.uniform(0.7, 1.0),
                'size': random.choice([2, 2, 3]),
                'twinkle_speed': random.uniform(1.5, 3.0),
                'twinkle_offset': random.uniform(0, math.pi * 2),
                'color': random.choice([
                    (200, 230, 255), (255, 200, 230),
                    (230, 200, 255), (255, 255, 220),
                    (220, 255, 255),
                ]),
                'flare': True,
            })

        return layers

    # ==============================================================
    #  [NEW] 캐시 Surface 초기화 헬퍼 (lazy)
    # ==============================================================
    def _ensure_nebula_surface(self) -> None:
        """성운 가스 구름 — 사이버펑크 딥 퍼플/핑크/시안 계열, 1회 렌더링 후 캐시"""
        if self._nebula_surface is not None:
            return
        margin = 50
        w = self.width + margin * 2
        h = self.height + margin * 2
        self._nebula_margin = margin
        self._nebula_surface = pygame.Surface((w, h), pygame.SRCALPHA)

        clouds = [
            (0.18, 0.28, 190, (100, 20, 100)),   # 딥 마젠타
            (0.78, 0.18, 160, (20, 45, 115)),     # 딥 블루
            (0.48, 0.55, 210, (80, 15, 110)),     # 다크 퍼플
            (0.22, 0.78, 140, (15, 70, 105)),     # 다크 틸
            (0.82, 0.68, 170, (130, 30, 85)),     # 크림슨
            (0.08, 0.48, 120, (35, 25, 95)),      # 인디고
            (0.62, 0.38, 150, (95, 15, 75)),      # 와인 퍼플
            (0.42, 0.12, 130, (20, 55, 105)),     # 오션 블루
        ]

        for xr, yr, radius, (cr, cg, cb) in clouds:
            cx = int(xr * w)
            cy = int(yr * h)
            # 겹치는 반투명 원으로 부드러운 가스 구름 표현
            for r in range(radius, 0, -3):
                ratio = r / radius
                alpha = int(16 * ratio ** 0.5)
                if alpha > 0:
                    pygame.draw.circle(
                        self._nebula_surface, (cr, cg, cb, alpha), (cx, cy), r
                    )

    def _ensure_vignette(self) -> None:
        """화면 가장자리를 어둡게 — 가독성 + 분위기 (1회 렌더링 캐시)"""
        if self._vignette_surface is not None:
            return
        w, h = self.width, self.height
        self._vignette_surface = pygame.Surface((w, h), pygame.SRCALPHA)
        cx, cy = w / 2.0, h / 2.0

        # 4px 수평 스트립 단위로 방사형 어둠 계산 (초기화 1회만)
        for y in range(0, h, 2):
            dy2 = ((y - cy) / cy) ** 2
            for x in range(0, w, 4):
                dx = (x - cx) / cx
                dist = math.sqrt(dx * dx + dy2)
                if dist > 0.40:
                    alpha = min(150, int(115 * ((dist - 0.40) / 0.85) ** 2))
                    if alpha > 2:
                        self._vignette_surface.fill(
                            (5, 5, 20, alpha), (x, y, 4, 2)
                        )

    def _ensure_ui_panel(self) -> None:
        """UI 가독성용 중앙 다크 패널 — 수직 그라데이션 마스크 (1회 캐시)"""
        if self._ui_panel_surface is not None:
            return
        w, h = self.width, self.height
        self._ui_panel_surface = pygame.Surface((w, h), pygame.SRCALPHA)

        # 상단 20% ~ 하단 90% 영역에 반투명 어둠, 가장자리 페이드
        panel_top = int(h * 0.18)
        panel_bottom = int(h * 0.92)
        fade = int((panel_bottom - panel_top) * 0.15)

        for y in range(panel_top, panel_bottom):
            if y < panel_top + fade:
                t = (y - panel_top) / fade
                alpha = int(55 * t * t)
            elif y > panel_bottom - fade:
                t = (panel_bottom - y) / fade
                alpha = int(55 * t * t)
            else:
                alpha = 55
            if alpha > 0:
                pygame.draw.line(
                    self._ui_panel_surface, (5, 5, 15, alpha),
                    (0, y), (w, y),
                )

    # ==============================================================
    #  업데이트 (패럴랙스 + 마우스 트레일 추가)
    # ==============================================================
    def update(self, dt: float, mouse_pos: Tuple[int, int] | None = None) -> None:
        """배경 업데이트 — mouse_pos 를 넘기면 패럴랙스 & 트레일 활성화"""
        self.time += dt

        # -----------------------------------------------------------
        # [NEW] 패럴랙스 — 마우스 오프셋에서 목표값 계산, 부드러운 보간
        # -----------------------------------------------------------
        if mouse_pos is not None:
            cx, cy = self.width / 2.0, self.height / 2.0
            dx = (mouse_pos[0] - cx) / max(cx, 1)   # -1 ~ +1
            dy = (mouse_pos[1] - cy) / max(cy, 1)
            self._target_px = -dx * 22   # 최대 ±22px
            self._target_py = -dy * 16

        lerp = min(1.0, dt * 3.5)
        self._cur_px += (self._target_px - self._cur_px) * lerp
        self._cur_py += (self._target_py - self._cur_py) * lerp

        # -----------------------------------------------------------
        # [NEW] 마우스 트레일 파티클 생성 & 업데이트
        # -----------------------------------------------------------
        self._update_mouse_trail(dt, mouse_pos)

        # -----------------------------------------------------------
        # 행성 공전/자전 (기존 로직)
        # -----------------------------------------------------------
        center_x = self.width // 2
        center_y = self.height // 2

        for planet in self.planets:
            planet['rotation'] += planet.get('rotation_speed', 0.01) * 60 * dt

            if planet['type'] == 'heart_sun':
                if planet.get('pulse'):
                    planet['pulse_phase'] = planet.get('pulse_phase', 0) + dt * 2
                    planet['current_radius'] = planet['radius'] + math.sin(planet['pulse_phase']) * 5
                for sparkle in planet.get('sparkles', []):
                    sparkle['phase'] += sparkle['speed'] * dt
                    sparkle['angle'] += 0.3 * dt
                for heart in planet.get('hearts_orbit', []):
                    heart['angle'] += heart['speed'] * dt

            elif planet['orbit_radius'] > 0:
                planet['orbit_angle'] += planet['orbit_speed'] * dt
                planet['x'] = center_x + math.cos(planet['orbit_angle']) * planet['orbit_radius']
                planet['y'] = center_y + math.sin(planet['orbit_angle']) * planet['orbit_radius'] * 0.5

                if 'trail' in planet:
                    if len(planet['trail']) > 20:
                        planet['trail'].pop(0)
                    planet['trail'].append((planet['x'], planet['y']))

                if planet['type'] == 'star_planet':
                    planet['twinkle_phase'] = planet.get('twinkle_phase', 0) + dt * 3
                elif planet['type'] == 'heart_planet':
                    for heart in planet.get('mini_hearts', []):
                        heart['angle'] += heart['speed'] * dt
                elif planet['type'] == 'ribbon_planet':
                    if 'ribbons' in planet:
                        planet['ribbons']['rotation'] += planet['ribbons']['rotation_speed'] * 60 * dt
                    for particle in planet.get('ribbon_particles', []):
                        particle['angle'] += particle['speed']
                elif planet['type'] == 'gem_planet':
                    planet['shimmer_phase'] = planet.get('shimmer_phase', 0) + dt * 4
                elif planet['type'] == 'mini_heart':
                    if planet.get('wobble'):
                        planet['wobble_phase'] = planet.get('wobble_phase', 0) + dt * 5

        # -----------------------------------------------------------
        # 애니 감성 요소 업데이트 (기존 로직)
        # -----------------------------------------------------------
        for sparkle in self.sparkles:
            sparkle['phase'] += sparkle['speed'] * dt
            if random.random() < 0.005:
                sparkle['x'] = random.randint(0, self.width)
                sparkle['y'] = random.randint(0, self.height)

        for p in self.cute_particles:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['rotation'] += p['rot_speed']
            if p['y'] < -50 or p['x'] < -50 or p['x'] > self.width + 50:
                p['x'] = random.randint(0, self.width)
                p['y'] = self.height + random.randint(10, 100)
                p['alpha'] = random.randint(100, 200)

        if random.random() < 0.008:
            self.shooting_stars.append({
                'x': random.randint(0, self.width),
                'y': random.randint(0, int(self.height * 0.3)),
                'vx': random.uniform(8, 15),
                'vy': random.uniform(4, 8),
                'life': 1.0,
                'length': random.randint(30, 80),
                'color': random.choice([
                    (255, 200, 255), (200, 255, 255), (255, 255, 200),
                ])
            })

        for star in self.shooting_stars[:]:
            star['x'] += star['vx']
            star['y'] += star['vy']
            star['life'] -= dt * 1.5
            if star['life'] <= 0 or star['x'] > self.width or star['y'] > self.height:
                self.shooting_stars.remove(star)

    # ==============================================================
    #  [NEW] 마우스 트레일 업데이트
    # ==============================================================
    def _update_mouse_trail(self, dt: float, mouse_pos: Tuple[int, int] | None) -> None:
        self._trail_timer += dt

        # 마우스가 움직였을 때만 새 파티클 생성 (~33ms 간격)
        if mouse_pos is not None and self._trail_timer > 0.033:
            self._trail_timer = 0.0
            mdx = mouse_pos[0] - self._prev_mouse_pos[0]
            mdy = mouse_pos[1] - self._prev_mouse_pos[1]
            if abs(mdx) > 1 or abs(mdy) > 1:
                self.mouse_trail.append({
                    'x': mouse_pos[0] + random.uniform(-4, 4),
                    'y': mouse_pos[1] + random.uniform(-4, 4),
                    'vx': random.uniform(-0.4, 0.4) - mdx * 0.03,
                    'vy': random.uniform(-0.8, -0.15),
                    'life': 1.0,
                    'size': random.uniform(3, 7),
                    'type': random.choice(['heart', 'star', 'sparkle']),
                    'color': random.choice([
                        (255, 150, 200), (200, 150, 255),
                        (255, 220, 180), (200, 255, 255),
                        (255, 200, 255),
                    ]),
                    'rotation': random.uniform(0, math.pi * 2),
                    'rot_speed': random.uniform(-0.08, 0.08),
                })
            self._prev_mouse_pos = mouse_pos

        # 기존 트레일 파티클 업데이트
        for p in self.mouse_trail[:]:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['life'] -= dt * 2.2
            p['rotation'] += p['rot_speed']
            p['size'] *= 0.97
            if p['life'] <= 0 or p['size'] < 0.8:
                self.mouse_trail.remove(p)

        # 최대 개수 제한
        while len(self.mouse_trail) > 35:
            self.mouse_trail.pop(0)

    # ==============================================================
    #  메인 드로우 (성운, 3레이어 별밭, 행성 — 패럴랙스 적용)
    # ==============================================================
    def draw(self, surface: pygame.Surface) -> None:
        """배경 그리기 — 성운/별밭에 패럴랙스 깊이감 적용"""
        px = self._cur_px
        py = self._cur_py

        # ① 그라데이션 배경 (캐시)
        surface.fill(self.colors['bg_top'])
        if self._gradient_surface is None:
            self._gradient_surface = pygame.Surface((self.width, self.height))
            for y in range(self.height):
                ratio = y / self.height
                r = int(self.colors['bg_top'][0] + ratio * (self.colors['bg_bottom'][0] - self.colors['bg_top'][0]))
                g = int(self.colors['bg_top'][1] + ratio * (self.colors['bg_bottom'][1] - self.colors['bg_top'][1]))
                b = int(self.colors['bg_top'][2] + ratio * (self.colors['bg_bottom'][2] - self.colors['bg_top'][2]))
                pygame.draw.rect(self._gradient_surface, (r, g, b), (0, y, self.width, 1))
        surface.blit(self._gradient_surface, (0, 0))

        # ② [NEW] 성운 가스 구름 (패럴랙스 0.15배)
        self._ensure_nebula_surface()
        neb_ox = int(px * 0.15) - self._nebula_margin
        neb_oy = int(py * 0.15) - self._nebula_margin
        surface.blit(self._nebula_surface, (neb_ox, neb_oy))

        # ③ [NEW] 원경 별밭 (패럴랙스 0.25배 — 가장 느림)
        self._draw_star_layer(surface, self.star_layers['far'], px * 0.25, py * 0.25, 'far')

        # ④ 궤도 선 (패럴랙스 0.4배)
        center_x = self.width // 2
        center_y = self.height // 2
        orb_ox = int(px * 0.4)
        orb_oy = int(py * 0.4)
        orbit_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        for planet in self.planets:
            if planet['orbit_radius'] > 0:
                orbit_rect = pygame.Rect(
                    center_x - planet['orbit_radius'],
                    center_y - planet['orbit_radius'] * 0.5,
                    planet['orbit_radius'] * 2,
                    planet['orbit_radius']
                )
                pygame.draw.ellipse(orbit_surface, (50, 100, 150, 20), orbit_rect, 1)
        surface.blit(orbit_surface, (orb_ox, orb_oy))

        # ⑤ [NEW] 중경 별밭 (패럴랙스 0.55배)
        self._draw_star_layer(surface, self.star_layers['mid'], px * 0.55, py * 0.55, 'mid')

        # ⑥ 행성 그리기 (패럴랙스 0.4배 — 궤도와 동기)
        sorted_planets = sorted(self.planets, key=lambda p: p.get('y', center_y))
        for planet in sorted_planets:
            bx = planet.get('x', center_x) + orb_ox
            by = planet.get('y', center_y) + orb_oy
            if planet['type'] == 'heart_sun':
                radius = planet.get('current_radius', planet['radius'])
                self._draw_heart_sun(surface, bx, by, radius, planet)
            elif planet['type'] == 'star_planet':
                self._draw_star_planet(surface, bx, by, planet)
            elif planet['type'] == 'candy_planet':
                self._draw_candy_planet(surface, bx, by, planet)
            elif planet['type'] == 'heart_planet':
                self._draw_heart_planet(surface, bx, by, planet)
            elif planet['type'] == 'ribbon_planet':
                self._draw_ribbon_planet(surface, bx, by, planet)
            elif planet['type'] == 'gem_planet':
                self._draw_gem_planet(surface, bx, by, planet)
            elif planet['type'] == 'mini_heart':
                self._draw_mini_heart(surface, bx, by, planet)
            else:
                self._draw_cute_planet_default(surface, bx, by, planet)

        # ⑦ [NEW] 근경 별밭 (패럴랙스 1.0배 — 가장 빠름)
        self._draw_star_layer(surface, self.star_layers['near'], px * 1.0, py * 1.0, 'near')

    # ==============================================================
    #  [NEW] 오버레이 (비네팅 + UI 패널 + 마우스 트레일)
    #  start_menu.py 에서 _draw_anime_effects() 다음에 호출
    # ==============================================================
    def draw_overlays(self, surface: pygame.Surface) -> None:
        """비네팅, UI 다크패널, 마우스 트레일 — 모든 배경 이펙트 위에 그려짐"""
        # 비네팅: 화면 가장자리 어둡게
        self._ensure_vignette()
        surface.blit(self._vignette_surface, (0, 0))

        # UI 패널: 메뉴 글씨 뒤 반투명 어둠
        self._ensure_ui_panel()
        surface.blit(self._ui_panel_surface, (0, 0))

        # 마우스 트레일 파티클
        self._draw_mouse_trail(surface)

    # ==============================================================
    #  [NEW] 별밭 레이어 렌더러
    # ==============================================================
    def _draw_star_layer(
        self,
        surface: pygame.Surface,
        stars: list,
        off_x: float,
        off_y: float,
        layer: str,
    ) -> None:
        """하나의 별밭 레이어를 패럴랙스 오프셋 적용해 그리기"""
        ox, oy = int(off_x), int(off_y)

        for star in stars:
            sx = int(star['x']) + ox
            sy = int(star['y']) + oy
            if sx < -5 or sx > self.width + 5 or sy < -5 or sy > self.height + 5:
                continue

            twinkle = math.sin(self.time * star['twinkle_speed'] + star['twinkle_offset'])
            bri = star['brightness'] + twinkle * 0.25
            bri = max(0.05, min(1.0, bri))

            if layer == 'far':
                # 원경: 흰색 1px 점
                c = int(255 * bri)
                surface.set_at((sx, sy), (c, c, c))

            elif layer == 'mid':
                # 중경: 색상 있는 1~2px 원
                cr, cg, cb = star.get('color', (255, 255, 255))
                color = (int(cr * bri), int(cg * bri), int(cb * bri))
                size = star.get('size', 1)
                if size <= 1:
                    surface.set_at((sx, sy), color)
                else:
                    pygame.draw.circle(surface, color, (sx, sy), 1)

            else:
                # 근경: 밝고 큰 별 + 십자 플레어
                cr, cg, cb = star.get('color', (255, 255, 255))
                color = (int(cr * bri), int(cg * bri), int(cb * bri))
                size = star.get('size', 2)
                pygame.draw.circle(surface, color, (sx, sy), size)

                # 십자 플레어 (밝기가 높을 때만)
                if star.get('flare') and bri > 0.65:
                    flare_len = int(size * (1.5 + bri * 2.5))
                    fa = int(140 * bri)
                    fc = (*color, fa)
                    pygame.draw.line(surface, fc, (sx - flare_len, sy), (sx + flare_len, sy), 1)
                    pygame.draw.line(surface, fc, (sx, sy - flare_len), (sx, sy + flare_len), 1)

    # ==============================================================
    #  [NEW] 마우스 트레일 렌더러
    # ==============================================================
    def _draw_mouse_trail(self, surface: pygame.Surface) -> None:
        for p in self.mouse_trail:
            alpha = int(200 * max(0.0, p['life']))
            size = int(p['size'])
            if alpha < 5 or size < 1:
                continue

            ps = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
            center = size * 1.5

            if p['type'] == 'heart':
                self._draw_heart(ps, center, center, size, (*p['color'], alpha))
            elif p['type'] == 'star':
                self._draw_star(ps, center, center, size, (*p['color'], alpha))
            else:
                pygame.draw.circle(ps, (*p['color'], alpha),
                                 (int(center), int(center)), max(1, size // 2))
                pygame.draw.line(ps, (*p['color'], alpha // 2),
                               (int(center - size), int(center)),
                               (int(center + size), int(center)), 1)
                pygame.draw.line(ps, (*p['color'], alpha // 2),
                               (int(center), int(center - size)),
                               (int(center), int(center + size)), 1)

            if p['rotation'] != 0:
                ps = pygame.transform.rotate(ps, math.degrees(p['rotation']))

            rect = ps.get_rect(center=(int(p['x']), int(p['y'])))
            surface.blit(ps, rect)

    # ==============================================================
    #  행성 렌더러 (기존 전체 유지)
    # ==============================================================
    def _draw_heart_sun(self, surface: pygame.Surface, x: float, y: float, radius: float, planet: dict):
        """중심 핑크 하트 그리기"""
        for i in range(4):
            glow_radius = radius + 20 + i * 15
            glow_alpha = 50 - i * 10
            glow_surf = pygame.Surface((int(glow_radius * 2.5), int(glow_radius * 2.5)), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*planet['glow_color'], glow_alpha),
                             (int(glow_radius * 1.25), int(glow_radius * 1.25)), int(glow_radius))
            surface.blit(glow_surf, (int(x - glow_radius * 1.25), int(y - glow_radius * 1.25)))

        heart_surf = pygame.Surface((int(radius * 3), int(radius * 3)), pygame.SRCALPHA)
        self._draw_big_heart(heart_surf, radius * 1.5, radius * 1.5, radius, planet['color'], planet['color2'])
        surface.blit(heart_surf, (int(x - radius * 1.5), int(y - radius * 1.5)))

        for sparkle in planet.get('sparkles', []):
            pulse = abs(math.sin(sparkle['phase']))
            sp_x = x + math.cos(sparkle['angle']) * radius * sparkle['distance']
            sp_y = y + math.sin(sparkle['angle']) * radius * sparkle['distance'] * 0.7
            sp_size = int(sparkle['size'] * (0.5 + pulse * 0.5))
            sp_alpha = int(200 * pulse + 55)
            if sp_size > 0:
                pygame.draw.line(surface, (255, 255, 255, sp_alpha),
                               (int(sp_x - sp_size), int(sp_y)), (int(sp_x + sp_size), int(sp_y)), 2)
                pygame.draw.line(surface, (255, 255, 255, sp_alpha),
                               (int(sp_x), int(sp_y - sp_size)), (int(sp_x), int(sp_y + sp_size)), 2)

        for heart in planet.get('hearts_orbit', []):
            h_x = x + math.cos(heart['angle']) * radius * heart['distance']
            h_y = y + math.sin(heart['angle']) * radius * heart['distance'] * 0.6
            h_size = int(heart['size'])
            mini_heart_surf = pygame.Surface((h_size * 3, h_size * 3), pygame.SRCALPHA)
            self._draw_heart(mini_heart_surf, h_size * 1.5, h_size * 1.5, h_size, (*heart['color'], 200))
            surface.blit(mini_heart_surf, (int(h_x - h_size * 1.5), int(h_y - h_size * 1.5)))

    def _draw_big_heart(self, surface: pygame.Surface, cx: float, cy: float, size: float, color: Tuple, color2: Tuple):
        """큰 하트 그리기 (그라데이션 효과)"""
        for glow in range(3):
            glow_size = size + 5 + glow * 3
            glow_alpha = 60 - glow * 15
            points = []
            for i in range(40):
                t = i / 40 * 2 * math.pi
                hx = 16 * (math.sin(t) ** 3)
                hy = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
                points.append((cx + hx * glow_size / 18, cy + hy * glow_size / 18))
            if len(points) > 2:
                pygame.draw.polygon(surface, (*color2, glow_alpha), points)

        points = []
        for i in range(40):
            t = i / 40 * 2 * math.pi
            hx = 16 * (math.sin(t) ** 3)
            hy = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
            points.append((cx + hx * size / 18, cy + hy * size / 18))
        if len(points) > 2:
            pygame.draw.polygon(surface, color, points)

        highlight_size = size * 0.3
        pygame.draw.circle(surface, (255, 255, 255, 100),
                         (int(cx - size * 0.25), int(cy - size * 0.3)), int(highlight_size))
        pygame.draw.circle(surface, (255, 255, 255, 60),
                         (int(cx - size * 0.15), int(cy - size * 0.2)), int(highlight_size * 0.6))

    def _draw_star_planet(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """별 모양 행성 그리기"""
        radius = planet['radius']
        points = planet.get('star_points', 5)
        twinkle = abs(math.sin(planet.get('twinkle_phase', 0)))

        self._draw_cute_trail(surface, planet)

        glow_radius = radius + 10 + twinkle * 5
        glow_surf = pygame.Surface((int(glow_radius * 3), int(glow_radius * 3)), pygame.SRCALPHA)
        for i in range(3):
            gr = glow_radius - i * 3
            ga = int(40 - i * 10 + twinkle * 20)
            pygame.draw.circle(glow_surf, (*planet['glow_color'], ga),
                             (int(glow_radius * 1.5), int(glow_radius * 1.5)), int(gr))
        surface.blit(glow_surf, (int(x - glow_radius * 1.5), int(y - glow_radius * 1.5)))

        star_surf = pygame.Surface((int(radius * 3), int(radius * 3)), pygame.SRCALPHA)
        star_points = []
        for i in range(points * 2):
            r = radius if i % 2 == 0 else radius * 0.4
            angle = i * math.pi / points - math.pi / 2 + planet['rotation']
            star_points.append((
                radius * 1.5 + math.cos(angle) * r,
                radius * 1.5 + math.sin(angle) * r
            ))
        if len(star_points) > 2:
            pygame.draw.polygon(star_surf, planet['color'], star_points)
            pygame.draw.polygon(star_surf, planet['color2'], star_points, 2)

        pygame.draw.circle(star_surf, (255, 255, 255, 120),
                         (int(radius * 1.2), int(radius * 1.2)), int(radius * 0.25))

        surface.blit(star_surf, (int(x - radius * 1.5), int(y - radius * 1.5)))

        if twinkle > 0.7:
            line_len = radius * (0.5 + twinkle * 0.5)
            pygame.draw.line(surface, (255, 255, 255, int(150 * twinkle)),
                           (int(x - line_len), int(y)), (int(x + line_len), int(y)), 2)
            pygame.draw.line(surface, (255, 255, 255, int(150 * twinkle)),
                           (int(x), int(y - line_len)), (int(x), int(y + line_len)), 2)

    def _draw_candy_planet(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """사탕 줄무늬 행성 그리기"""
        radius = planet['radius']

        self._draw_cute_trail(surface, planet)

        glow_radius = radius + 8
        glow_surf = pygame.Surface((int(glow_radius * 2.5), int(glow_radius * 2.5)), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*planet['glow_color'], 40),
                         (int(glow_radius * 1.25), int(glow_radius * 1.25)), int(glow_radius))
        surface.blit(glow_surf, (int(x - glow_radius * 1.25), int(y - glow_radius * 1.25)))

        candy_surf = pygame.Surface((int(radius * 2.5), int(radius * 2.5)), pygame.SRCALPHA)
        cx, cy = radius * 1.25, radius * 1.25

        pygame.draw.circle(candy_surf, planet['color'], (int(cx), int(cy)), radius)

        stripe_color = planet.get('stripe_color', (255, 255, 255))
        for i in range(6):
            stripe_angle = planet['rotation'] + i * math.pi / 3
            for j in range(-2, 3):
                offset = j * radius * 0.3
                sx1 = cx + math.cos(stripe_angle) * offset - math.sin(stripe_angle) * radius
                sy1 = cy + math.sin(stripe_angle) * offset + math.cos(stripe_angle) * radius
                sx2 = cx + math.cos(stripe_angle) * offset + math.sin(stripe_angle) * radius
                sy2 = cy + math.sin(stripe_angle) * offset - math.cos(stripe_angle) * radius
                pygame.draw.line(candy_surf, (*stripe_color, 150), (int(sx1), int(sy1)), (int(sx2), int(sy2)), 3)

        mask_surf = pygame.Surface((int(radius * 2.5), int(radius * 2.5)), pygame.SRCALPHA)
        pygame.draw.circle(mask_surf, (255, 255, 255, 255), (int(cx), int(cy)), radius)
        candy_surf.blit(mask_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)

        pygame.draw.circle(candy_surf, (255, 255, 255, 100),
                         (int(cx - radius * 0.3), int(cy - radius * 0.3)), int(radius * 0.25))

        surface.blit(candy_surf, (int(x - radius * 1.25), int(y - radius * 1.25)))

    def _draw_heart_planet(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """하트 모양 행성 그리기"""
        radius = planet['radius']

        self._draw_cute_trail(surface, planet)

        glow_radius = radius + 10
        glow_surf = pygame.Surface((int(glow_radius * 2.5), int(glow_radius * 2.5)), pygame.SRCALPHA)
        for i in range(2):
            pygame.draw.circle(glow_surf, (*planet['glow_color'], 35 - i * 15),
                             (int(glow_radius * 1.25), int(glow_radius * 1.25)), int(glow_radius - i * 5))
        surface.blit(glow_surf, (int(x - glow_radius * 1.25), int(y - glow_radius * 1.25)))

        heart_surf = pygame.Surface((int(radius * 3), int(radius * 3)), pygame.SRCALPHA)
        self._draw_heart(heart_surf, radius * 1.5, radius * 1.5, radius, (*planet['color'], 255))

        pygame.draw.circle(heart_surf, (255, 255, 255, 100),
                         (int(radius * 1.2), int(radius * 1.2)), int(radius * 0.2))

        surface.blit(heart_surf, (int(x - radius * 1.5), int(y - radius * 1.5)))

        for heart in planet.get('mini_hearts', []):
            h_x = x + math.cos(heart['angle']) * radius * heart['distance']
            h_y = y + math.sin(heart['angle']) * radius * heart['distance'] * 0.6
            h_size = int(heart['size'])
            mini_surf = pygame.Surface((h_size * 3, h_size * 3), pygame.SRCALPHA)
            self._draw_heart(mini_surf, h_size * 1.5, h_size * 1.5, h_size, (*planet['color'], 150))
            surface.blit(mini_surf, (int(h_x - h_size * 1.5), int(h_y - h_size * 1.5)))

    def _draw_ribbon_planet(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """리본 고리 행성 그리기 (코튼캔디)"""
        radius = planet['radius']

        self._draw_cute_trail(surface, planet)

        if 'ribbons' in planet:
            ribbons = planet['ribbons']
            ribbon_surf = pygame.Surface((int(ribbons['outer_radius'] * 3), int(ribbons['outer_radius'] * 2)), pygame.SRCALPHA)

            for i, color in enumerate(ribbons['colors']):
                ring_r = ribbons['inner_radius'] + i * 8
                ring_rotation = ribbons['rotation'] + i * 0.2

                for angle in range(180, 360, 5):
                    rad = math.radians(angle + math.degrees(ring_rotation))
                    px = ribbons['outer_radius'] * 1.5 + ring_r * math.cos(rad)
                    py = ribbons['outer_radius'] - ring_r * math.sin(rad) * 0.35
                    alpha = int(80 + math.sin(rad * 3) * 30)
                    pygame.draw.circle(ribbon_surf, (*color, alpha), (int(px), int(py)), 3)

            surface.blit(ribbon_surf, (int(x - ribbons['outer_radius'] * 1.5), int(y - ribbons['outer_radius'])))

        glow_radius = radius + 12
        glow_surf = pygame.Surface((int(glow_radius * 2.5), int(glow_radius * 2.5)), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*planet['glow_color'], 35),
                         (int(glow_radius * 1.25), int(glow_radius * 1.25)), int(glow_radius))
        surface.blit(glow_surf, (int(x - glow_radius * 1.25), int(y - glow_radius * 1.25)))

        for i in range(int(radius)):
            ratio = i / radius
            r = int(planet['color'][0] * (1 - ratio * 0.2) + planet['color2'][0] * ratio * 0.2)
            g = int(planet['color'][1] * (1 - ratio * 0.2) + planet['color2'][1] * ratio * 0.2)
            b = int(planet['color'][2] * (1 - ratio * 0.2) + planet['color2'][2] * ratio * 0.2)
            pygame.draw.circle(surface, (r, g, b), (int(x), int(y)), radius - i)

        pygame.draw.circle(surface, (255, 255, 255, 80),
                         (int(x - radius * 0.3), int(y - radius * 0.3)), int(radius * 0.25))

        if 'ribbons' in planet:
            ribbons = planet['ribbons']
            front_ribbon = pygame.Surface((int(ribbons['outer_radius'] * 3), int(ribbons['outer_radius'] * 2)), pygame.SRCALPHA)

            for i, color in enumerate(ribbons['colors']):
                ring_r = ribbons['inner_radius'] + i * 8
                ring_rotation = ribbons['rotation'] + i * 0.2

                for angle in range(0, 180, 5):
                    rad = math.radians(angle + math.degrees(ring_rotation))
                    px = ribbons['outer_radius'] * 1.5 + ring_r * math.cos(rad)
                    py = ribbons['outer_radius'] - ring_r * math.sin(rad) * 0.35
                    alpha = int(150 + math.sin(rad * 3) * 50)
                    pygame.draw.circle(front_ribbon, (*color, alpha), (int(px), int(py)), 4)

            surface.blit(front_ribbon, (int(x - ribbons['outer_radius'] * 1.5), int(y - ribbons['outer_radius'])))

    def _draw_gem_planet(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """보석 행성 그리기"""
        radius = planet['radius']
        facets = planet.get('facets', 8)
        shimmer = abs(math.sin(planet.get('shimmer_phase', 0)))

        self._draw_cute_trail(surface, planet)

        glow_radius = radius + 8 + shimmer * 5
        glow_surf = pygame.Surface((int(glow_radius * 3), int(glow_radius * 3)), pygame.SRCALPHA)
        glow_alpha = int(30 + shimmer * 30)
        pygame.draw.circle(glow_surf, (*planet['glow_color'], glow_alpha),
                         (int(glow_radius * 1.5), int(glow_radius * 1.5)), int(glow_radius))
        surface.blit(glow_surf, (int(x - glow_radius * 1.5), int(y - glow_radius * 1.5)))

        gem_surf = pygame.Surface((int(radius * 3), int(radius * 3)), pygame.SRCALPHA)
        cx, cy = radius * 1.5, radius * 1.5

        points = []
        for i in range(facets):
            angle = i * 2 * math.pi / facets + planet['rotation']
            points.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius * 0.8))

        if len(points) > 2:
            pygame.draw.polygon(gem_surf, planet['color'], points)
            pygame.draw.polygon(gem_surf, planet['color2'], points, 3)

            for i in range(0, facets, 2):
                next_i = (i + 1) % facets
                facet_points = [points[i], points[next_i], (cx, cy)]
                facet_color = tuple(min(255, c + 40) for c in planet['color'])
                pygame.draw.polygon(gem_surf, (*facet_color, 100), facet_points)

        pygame.draw.circle(gem_surf, (255, 255, 255, int(100 + shimmer * 80)),
                         (int(cx - radius * 0.2), int(cy - radius * 0.2)), int(radius * 0.3))

        if shimmer > 0.6:
            line_alpha = int(200 * shimmer)
            line_len = radius * 0.8
            pygame.draw.line(gem_surf, (255, 255, 255, line_alpha),
                           (int(cx - line_len), int(cy)), (int(cx + line_len), int(cy)), 1)
            pygame.draw.line(gem_surf, (255, 255, 255, line_alpha),
                           (int(cx), int(cy - line_len)), (int(cx), int(cy + line_len)), 1)

        surface.blit(gem_surf, (int(x - radius * 1.5), int(y - radius * 1.5)))

    def _draw_mini_heart(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """작은 하트 행성 그리기"""
        radius = planet['radius']
        wobble_phase = planet.get('wobble_phase', 0)

        wobble_x = math.sin(wobble_phase) * 3 if planet.get('wobble') else 0
        wobble_y = math.cos(wobble_phase * 0.7) * 2 if planet.get('wobble') else 0
        x += wobble_x
        y += wobble_y

        self._draw_cute_trail(surface, planet)

        glow_surf = pygame.Surface((int(radius * 4), int(radius * 4)), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*planet['glow_color'], 40),
                         (int(radius * 2), int(radius * 2)), int(radius + 5))
        surface.blit(glow_surf, (int(x - radius * 2), int(y - radius * 2)))

        heart_surf = pygame.Surface((int(radius * 3), int(radius * 3)), pygame.SRCALPHA)
        self._draw_heart(heart_surf, radius * 1.5, radius * 1.5, radius, (*planet['color'], 255))

        pygame.draw.circle(heart_surf, (255, 255, 255, 120),
                         (int(radius * 1.2), int(radius * 1.2)), int(radius * 0.2))

        surface.blit(heart_surf, (int(x - radius * 1.5), int(y - radius * 1.5)))

    def _draw_cute_planet_default(self, surface: pygame.Surface, x: float, y: float, planet: dict):
        """기본 귀여운 행성 (폴백)"""
        radius = planet['radius']

        self._draw_cute_trail(surface, planet)

        glow_radius = radius + 8
        glow_surf = pygame.Surface((int(glow_radius * 2.5), int(glow_radius * 2.5)), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*planet['glow_color'], 35),
                         (int(glow_radius * 1.25), int(glow_radius * 1.25)), int(glow_radius))
        surface.blit(glow_surf, (int(x - glow_radius * 1.25), int(y - glow_radius * 1.25)))

        pygame.draw.circle(surface, planet['color'], (int(x), int(y)), radius)

        pygame.draw.circle(surface, (255, 255, 255, 80),
                         (int(x - radius * 0.3), int(y - radius * 0.3)), int(radius * 0.25))

    def _draw_cute_trail(self, surface: pygame.Surface, planet: dict):
        """귀여운 반짝이 궤적 그리기"""
        trail = planet.get('trail', [])
        if len(trail) > 1:
            for i, pos in enumerate(trail):
                alpha = int(80 * (i / len(trail)))
                size = 2 + (i / len(trail)) * 2
                if alpha > 10:
                    color = (*planet['glow_color'], alpha)
                    pygame.draw.circle(surface, color, (int(pos[0]), int(pos[1])), int(size))

    # ==============================================================
    #  애니 감성 효과 (기존 전체 유지)
    # ==============================================================
    def _draw_anime_effects(self, surface: pygame.Surface):
        """애니 감성 효과 그리기"""

        # 1. 무지개빛 오로라 웨이브
        aurora_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        for wave in self.aurora_waves:
            hue = (self.time * wave['speed'] * 30 + wave['hue_offset']) % 360
            rgb = self._hsv_to_rgb(hue, 0.6, 1.0)

            points = []
            for x in range(0, self.width, 8):
                y = wave['y_offset'] + math.sin(x * wave['frequency'] + self.time * wave['speed'] + wave['phase']) * wave['amplitude']
                points.append((x, y))

            if len(points) > 2:
                for i in range(len(points) - 1):
                    alpha = int(wave['alpha'] * (1 - abs(i - len(points) // 2) / (len(points) // 2) * 0.5))
                    pygame.draw.line(aurora_surf, (*rgb, max(5, alpha)),
                                   points[i], points[i + 1], 3)
        surface.blit(aurora_surf, (0, 0))

        # 2. 별똥별 (유성)
        for star in self.shooting_stars:
            tail_length = int(star['length'] * star['life'])
            if tail_length > 0:
                for i in range(min(5, tail_length // 10)):
                    t_alpha = int(200 * star['life'] * (1 - i * 0.18))
                    t_width = max(1, 4 - i)
                    t_x = star['x'] - star['vx'] * i * 3
                    t_y = star['y'] - star['vy'] * i * 3
                    if t_alpha > 0:
                        pygame.draw.circle(surface, (*star['color'], t_alpha),
                                         (int(t_x), int(t_y)), t_width)

                head_alpha = int(255 * star['life'])
                pygame.draw.circle(surface, (*star['color'], head_alpha),
                                 (int(star['x']), int(star['y'])), 3)
                pygame.draw.circle(surface, (255, 255, 255, head_alpha),
                                 (int(star['x']), int(star['y'])), 1)

        # 3. 키라키라 반짝이 효과
        for sparkle in self.sparkles:
            pulse = abs(math.sin(sparkle['phase']))
            size = int(sparkle['size'] * (0.5 + pulse * 0.8))
            alpha = int(150 * pulse + 50)

            if size > 0 and alpha > 0:
                sx, sy = int(sparkle['x']), int(sparkle['y'])
                color = (*sparkle['color'], alpha)

                pygame.draw.line(surface, color, (sx - size, sy), (sx + size, sy), 1)
                pygame.draw.line(surface, color, (sx, sy - size), (sx, sy + size), 1)
                diag_size = size // 2
                pygame.draw.line(surface, color, (sx - diag_size, sy - diag_size), (sx + diag_size, sy + diag_size), 1)
                pygame.draw.line(surface, color, (sx - diag_size, sy + diag_size), (sx + diag_size, sy - diag_size), 1)

                if pulse > 0.7:
                    pygame.draw.circle(surface, (255, 255, 255, int(alpha * 0.8)), (sx, sy), 2)

        # 4. 하트/별 파티클
        for p in self.cute_particles:
            px, py = int(p['x']), int(p['y'])
            size = int(p['size'])
            alpha = p['alpha']

            particle_surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
            center = size * 1.5

            if p['type'] == 'heart':
                self._draw_heart(particle_surf, center, center, size, (*p['color'], alpha))
            elif p['type'] == 'star':
                self._draw_star(particle_surf, center, center, size, (*p['color'], alpha))
            else:
                pygame.draw.circle(particle_surf, (*p['color'], alpha),
                                 (int(center), int(center)), size // 2)
                pygame.draw.line(particle_surf, (*p['color'], alpha // 2),
                               (int(center - size), int(center)), (int(center + size), int(center)), 1)
                pygame.draw.line(particle_surf, (*p['color'], alpha // 2),
                               (int(center), int(center - size)), (int(center), int(center + size)), 1)

            if p['rotation'] != 0:
                particle_surf = pygame.transform.rotate(particle_surf, math.degrees(p['rotation']))

            rect = particle_surf.get_rect(center=(px, py))
            surface.blit(particle_surf, rect)

    # ==============================================================
    #  프리미티브 헬퍼 (기존 전체 유지)
    # ==============================================================
    def _draw_heart(self, surface: pygame.Surface, cx: float, cy: float, size: int, color: Tuple):
        """하트 모양 그리기"""
        points = []
        for i in range(30):
            t = i / 30 * 2 * math.pi
            x = 16 * (math.sin(t) ** 3)
            y = -(13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t))
            x = cx + x * size / 20
            y = cy + y * size / 20
            points.append((x, y))

        if len(points) > 2:
            pygame.draw.polygon(surface, color, points)
            highlight_color = (min(255, color[0] + 50), min(255, color[1] + 50), min(255, color[2] + 50), color[3] // 2)
            pygame.draw.circle(surface, highlight_color, (int(cx - size * 0.2), int(cy - size * 0.2)), size // 4)

    def _draw_star(self, surface: pygame.Surface, cx: float, cy: float, size: int, color: Tuple):
        """별 모양 그리기"""
        points = []
        for i in range(10):
            radius = size if i % 2 == 0 else size * 0.4
            angle = i * math.pi / 5 - math.pi / 2
            x = cx + math.cos(angle) * radius
            y = cy + math.sin(angle) * radius
            points.append((x, y))

        if len(points) > 2:
            pygame.draw.polygon(surface, color, points)
            highlight_color = (255, 255, 255, color[3] // 2)
            pygame.draw.circle(surface, highlight_color, (int(cx), int(cy)), size // 3)

    def _hsv_to_rgb(self, h: float, s: float, v: float) -> Tuple[int, int, int]:
        """HSV를 RGB로 변환"""
        h = h % 360
        c = v * s
        x = c * (1 - abs((h / 60) % 2 - 1))
        m = v - c

        if h < 60:
            r, g, b = c, x, 0
        elif h < 120:
            r, g, b = x, c, 0
        elif h < 180:
            r, g, b = 0, c, x
        elif h < 240:
            r, g, b = 0, x, c
        elif h < 300:
            r, g, b = x, 0, c
        else:
            r, g, b = c, 0, x

        return (int((r + m) * 255), int((g + m) * 255), int((b + m) * 255))
