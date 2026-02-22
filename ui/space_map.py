# -*- coding: utf-8 -*-
"""
우주 행성 맵 시스템
캐릭터/난이도 선택 후 우주 맵이 펼쳐지고, 우주선이 행성 사이를 이동하는 화면.
"""

import pygame
import math
import random
import os
import sys

def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

try:
    from pixel_font_manager import get_font, FontStyle
except ImportError:
    get_font = lambda s, **kw: pygame.font.Font(None, s)

try:
    from config.planet_configs import PLANET_CONFIGS
except ImportError:
    PLANET_CONFIGS = {}


# ── 행성 배치 좌표 (760x750 내부 해상도 기준, S자 곡선) ──
def _compute_planet_positions(width, height, count=8):
    """S자 곡선을 따라 행성 위치를 생성한다."""
    positions = []
    margin_top = 80
    margin_bottom = 80
    usable_h = height - margin_top - margin_bottom
    cx = width // 2
    amplitude = 180  # 좌우 흔들림 폭
    for i in range(count):
        t = i / max(1, count - 1)
        y = margin_top + int(usable_h * t)
        # S자 곡선 (sin 기반)
        x = cx + int(amplitude * math.sin(t * math.pi * 2 - math.pi / 2))
        # 첫 행성은 중앙 상단에
        if i == 0:
            x = cx
        positions.append((x, y))
    return positions


class Star:
    """배경 별 파티클"""
    __slots__ = ('x', 'y', 'size', 'brightness', 'twinkle_speed', 'phase')

    def __init__(self, width, height):
        self.x = random.randint(0, width)
        self.y = random.randint(0, height)
        self.size = random.choice([1, 1, 1, 2, 2, 3])
        self.brightness = random.randint(80, 255)
        self.twinkle_speed = random.uniform(0.02, 0.08)
        self.phase = random.uniform(0, math.pi * 2)


class SpaceMap:
    """우주 행성 맵 화면"""

    def __init__(self, screen, width, height):
        self.screen = screen
        self.width = width
        self.height = height
        self.clock = pygame.time.Clock()

        # 별 생성
        self.stars = [Star(width, height) for _ in range(200)]

        # 행성 위치
        planet_count = len(PLANET_CONFIGS) if PLANET_CONFIGS else 8
        self.planet_positions = _compute_planet_positions(width, height, planet_count)

        # 우주선 상태
        self.ship_x = float(width // 2)
        self.ship_y = float(self.height + 40)  # 화면 아래에서 시작
        self.ship_angle = 0.0  # 회전 각도 (도)

        # 애니메이션 타이머
        self.time = 0.0

        # 폰트
        try:
            self.font_name = get_font(14, style="bold")
            self.font_title = get_font(28, style="bold")
            self.font_small = get_font(12, style="regular")
        except Exception:
            self.font_name = pygame.font.Font(None, 18)
            self.font_title = pygame.font.Font(None, 36)
            self.font_small = pygame.font.Font(None, 14)

    # ─── 렌더링 ───

    def _draw_background(self):
        """우주 배경 + 별"""
        self.screen.fill((5, 5, 15))
        for s in self.stars:
            b = int(s.brightness * (0.5 + 0.5 * math.sin(self.time * s.twinkle_speed * 60 + s.phase)))
            b = max(30, min(255, b))
            color = (b, b, int(b * 0.9))
            if s.size <= 1:
                self.screen.set_at((s.x, s.y), color)
            else:
                pygame.draw.circle(self.screen, color, (s.x, s.y), s.size)

    def _draw_path(self, cleared_planets):
        """행성 간 경로선 (점선)"""
        for i in range(len(self.planet_positions) - 1):
            x1, y1 = self.planet_positions[i]
            x2, y2 = self.planet_positions[i + 1]
            # 클리어된 구간은 밝게, 아닌 구간은 어둡게
            is_cleared = (i + 1) in cleared_planets
            color = (80, 120, 180) if is_cleared else (30, 40, 60)
            # 점선 그리기
            dx = x2 - x1
            dy = y2 - y1
            dist = math.sqrt(dx * dx + dy * dy)
            if dist < 1:
                continue
            steps = int(dist / 8)
            for j in range(steps):
                if j % 2 == 0:
                    t = j / max(1, steps)
                    px = int(x1 + dx * t)
                    py = int(y1 + dy * t)
                    pygame.draw.circle(self.screen, color, (px, py), 1)

    def _draw_planet(self, planet_num, x, y, cleared_planets, is_current_target=False):
        """행성 하나 그리기"""
        config = PLANET_CONFIGS.get(planet_num, {})
        base_color = config.get("theme_color", (100, 100, 100))
        glow_color = config.get("glow_color", (150, 150, 150))
        ring_color = config.get("ring_color", None)
        radius = config.get("size", 28)
        name = config.get("name", f"행성 {planet_num}")

        is_cleared = planet_num in cleared_planets

        # 빛남 효과 (현재 목표 행성)
        if is_current_target:
            glow_radius = radius + 12 + int(4 * math.sin(self.time * 3))
            glow_surf = pygame.Surface((glow_radius * 2 + 20, glow_radius * 2 + 20), pygame.SRCALPHA)
            for r in range(glow_radius, radius, -2):
                alpha = int(40 * (1 - (r - radius) / (glow_radius - radius)))
                pygame.draw.circle(glow_surf, (*glow_color, alpha),
                                   (glow_radius + 10, glow_radius + 10), r)
            self.screen.blit(glow_surf, (x - glow_radius - 10, y - glow_radius - 10))

        # 행성 본체
        if is_cleared:
            # 클리어된 행성: 약간 어두움
            dark = tuple(max(0, c - 60) for c in base_color)
            pygame.draw.circle(self.screen, dark, (x, y), radius)
            # 체크마크
            cx, cy = x, y
            check_color = (100, 255, 100)
            pygame.draw.line(self.screen, check_color, (cx - 8, cy), (cx - 2, cy + 7), 3)
            pygame.draw.line(self.screen, check_color, (cx - 2, cy + 7), (cx + 10, cy - 8), 3)
        else:
            # 행성 그라데이션 (간단한 구현: 밝은 면 + 그림자)
            pygame.draw.circle(self.screen, base_color, (x, y), radius)
            # 하이라이트
            highlight = tuple(min(255, c + 60) for c in base_color)
            pygame.draw.circle(self.screen, highlight, (x - radius // 4, y - radius // 4), radius // 3)

        # 고리
        if ring_color and not is_cleared:
            ring_surf = pygame.Surface((radius * 3, radius * 2), pygame.SRCALPHA)
            ring_cx = radius * 3 // 2
            ring_cy = radius
            pygame.draw.ellipse(ring_surf, (*ring_color, 120),
                                (ring_cx - radius - 8, ring_cy - 6, (radius + 8) * 2, 12), 2)
            self.screen.blit(ring_surf, (x - radius * 3 // 2, y - radius))

        # 행성 외곽선
        outline_color = glow_color if is_current_target else (60, 70, 90)
        pygame.draw.circle(self.screen, outline_color, (x, y), radius, 1)

        # 행성 이름
        name_surf = self.font_name.render(name, True, (200, 210, 230))
        name_rect = name_surf.get_rect(center=(x, y + radius + 16))
        self.screen.blit(name_surf, name_rect)

        # 스테이지 번호
        num_surf = self.font_small.render(f"Stage {planet_num}", True, (120, 130, 150))
        num_rect = num_surf.get_rect(center=(x, y + radius + 30))
        self.screen.blit(num_surf, num_rect)

    def _draw_ship(self):
        """우주선 그리기 (삼각형 로켓)"""
        x, y = int(self.ship_x), int(self.ship_y)
        angle_rad = math.radians(self.ship_angle)

        # 로켓 모양 (삼각형 + 꼬리)
        size = 14
        # 앞쪽 (이동 방향)
        nose_x = x + int(size * 1.5 * math.sin(angle_rad))
        nose_y = y - int(size * 1.5 * math.cos(angle_rad))
        # 왼쪽 날개
        left_x = x + int(size * math.sin(angle_rad + 2.5))
        left_y = y - int(size * math.cos(angle_rad + 2.5))
        # 오른쪽 날개
        right_x = x + int(size * math.sin(angle_rad - 2.5))
        right_y = y - int(size * math.cos(angle_rad - 2.5))

        # 엔진 불꽃 (뒤쪽)
        tail_x = x - int(size * 0.8 * math.sin(angle_rad))
        tail_y = y + int(size * 0.8 * math.cos(angle_rad))
        flame_len = random.randint(6, 14)
        flame_x = tail_x - int(flame_len * math.sin(angle_rad))
        flame_y = tail_y + int(flame_len * math.cos(angle_rad))

        # 불꽃
        pygame.draw.line(self.screen, (255, 200, 50), (tail_x, tail_y), (flame_x, flame_y), 3)
        pygame.draw.line(self.screen, (255, 100, 30),
                         (tail_x + random.randint(-2, 2), tail_y + random.randint(-2, 2)),
                         (flame_x + random.randint(-3, 3), flame_y + random.randint(-3, 3)), 2)

        # 로켓 본체
        pygame.draw.polygon(self.screen, (220, 230, 255),
                            [(nose_x, nose_y), (left_x, left_y), (right_x, right_y)])
        pygame.draw.polygon(self.screen, (180, 190, 220),
                            [(nose_x, nose_y), (left_x, left_y), (right_x, right_y)], 1)

    def _draw_title(self, text, alpha=255):
        """상단 타이틀 텍스트"""
        title_surf = self.font_title.render(text, True, (220, 230, 255))
        if alpha < 255:
            title_surf.set_alpha(alpha)
        title_rect = title_surf.get_rect(center=(self.width // 2, 30))
        self.screen.blit(title_surf, title_rect)

    # ─── 애니메이션 ───

    def show_travel_animation(self, from_planet, to_planet, cleared_planets=None):
        """
        우주선이 from_planet에서 to_planet으로 이동하는 애니메이션.
        from_planet=0이면 화면 아래에서 시작 (첫 진입).
        """
        if cleared_planets is None:
            cleared_planets = []

        # 시작/도착 좌표
        if from_planet == 0:
            start_x = float(self.width // 2)
            start_y = float(self.height + 40)
        else:
            idx = from_planet - 1
            if idx < len(self.planet_positions):
                sx, sy = self.planet_positions[idx]
                start_x, start_y = float(sx), float(sy)
            else:
                start_x = float(self.width // 2)
                start_y = float(self.height + 40)

        to_idx = to_planet - 1
        if to_idx < len(self.planet_positions):
            end_x, end_y = self.planet_positions[to_idx]
        else:
            end_x, end_y = self.width // 2, self.height // 2

        end_x, end_y = float(end_x), float(end_y)

        # 우주선 초기 위치
        self.ship_x = start_x
        self.ship_y = start_y

        # 이동 방향 각도 계산
        dx = end_x - start_x
        dy = end_y - start_y
        target_angle = math.degrees(math.atan2(dx, -dy))  # 위가 0도
        self.ship_angle = target_angle

        # 페이즈: fade_in → travel → arrive
        phase = "fade_in"
        fade_timer = 0
        fade_duration = 40  # 프레임
        travel_timer = 0
        travel_duration = 90  # 프레임
        arrive_timer = 0
        arrive_duration = 50  # 프레임

        running = True
        while running:
            dt = self.clock.tick(60) / 1000.0
            self.time += dt

            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    pygame.quit()
                    sys.exit()
                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE or event.key == pygame.K_SPACE:
                        # 스킵: 즉시 도착
                        self.ship_x = end_x
                        self.ship_y = end_y
                        running = False

            if phase == "fade_in":
                fade_timer += 1
                alpha = min(255, int(255 * fade_timer / fade_duration))
                self._draw_background()
                self._draw_path(cleared_planets)
                for i, (px, py) in enumerate(self.planet_positions):
                    pnum = i + 1
                    is_target = (pnum == to_planet)
                    self._draw_planet(pnum, px, py, cleared_planets, is_current_target=is_target)
                self._draw_ship()
                self._draw_title("은하계 항해", alpha)

                # 페이드 오버레이
                if alpha < 255:
                    overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
                    overlay.fill((0, 0, 0, 255 - alpha))
                    self.screen.blit(overlay, (0, 0))

                pygame.display.flip()
                if fade_timer >= fade_duration:
                    phase = "travel"
                continue

            elif phase == "travel":
                travel_timer += 1
                # 이징 (ease-in-out)
                t = travel_timer / travel_duration
                t = t * t * (3 - 2 * t)  # smoothstep
                self.ship_x = start_x + (end_x - start_x) * t
                self.ship_y = start_y + (end_y - start_y) * t

                # 동적 각도
                if travel_timer < travel_duration:
                    next_t = min(1.0, (travel_timer + 1) / travel_duration)
                    next_t = next_t * next_t * (3 - 2 * next_t)
                    next_x = start_x + (end_x - start_x) * next_t
                    next_y = start_y + (end_y - start_y) * next_t
                    ddx = next_x - self.ship_x
                    ddy = next_y - self.ship_y
                    if abs(ddx) > 0.01 or abs(ddy) > 0.01:
                        self.ship_angle = math.degrees(math.atan2(ddx, -ddy))

                self._draw_background()
                self._draw_path(cleared_planets)
                for i, (px, py) in enumerate(self.planet_positions):
                    pnum = i + 1
                    is_target = (pnum == to_planet)
                    self._draw_planet(pnum, px, py, cleared_planets, is_current_target=is_target)
                self._draw_ship()
                self._draw_title("은하계 항해")
                pygame.display.flip()

                if travel_timer >= travel_duration:
                    phase = "arrive"
                continue

            elif phase == "arrive":
                arrive_timer += 1
                self.ship_x = end_x
                self.ship_y = end_y

                self._draw_background()
                self._draw_path(cleared_planets)
                for i, (px, py) in enumerate(self.planet_positions):
                    pnum = i + 1
                    is_target = (pnum == to_planet)
                    self._draw_planet(pnum, px, py, cleared_planets, is_current_target=is_target)
                self._draw_ship()

                # 도착 행성 이름 표시
                planet_name = PLANET_CONFIGS.get(to_planet, {}).get("name", f"행성 {to_planet}")
                arrival_alpha = min(255, arrive_timer * 8)
                arr_surf = self.font_title.render(f"{planet_name} 도착!", True, (255, 230, 150))
                arr_surf.set_alpha(arrival_alpha)
                arr_rect = arr_surf.get_rect(center=(self.width // 2, self.height // 2 + 100))
                self.screen.blit(arr_surf, arr_rect)

                self._draw_title("은하계 항해")
                pygame.display.flip()

                if arrive_timer >= arrive_duration:
                    running = False
                continue

        # 이벤트 큐 정리
        pygame.event.clear()
