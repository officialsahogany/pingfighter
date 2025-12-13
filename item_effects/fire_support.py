from __future__ import annotations

import random
from dataclasses import dataclass
from typing import Callable, List, Optional
import sys

import pygame


@dataclass
class Bomb:
    """내부 폭탄 상태를 추적."""

    x: float
    y: float
    vx: float
    vy: float
    gravity: float
    target_y: float
    life: int = 240


class FireSupportAircraft:
    """화력지원 호출 시 등장하는 폭격기."""

    def __init__(
        self,
        screen_width: int,
        screen_height: int,
        cruise_y: Optional[float] = None,
        engine_sound: Optional[pygame.mixer.Sound] = None,
        direction: str = "left_to_right",
    ) -> None:
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.width = 160  # B-2는 더 큰 날개폭
        self.height = 50  # B-2는 얇은 프로필
        self.direction = direction
        supply_altitude = _get_supply_aircraft_altitude()
        desired_y = cruise_y if cruise_y is not None else supply_altitude
        lower_bound = 20
        upper_bound = self.screen_height - self.height - 20
        self.y = max(lower_bound, min(upper_bound, desired_y))
        if self.direction == "right_to_left":
            self.x = self.screen_width + self.width
            self.speed = -1.8
        else:
            self.direction = "left_to_right"
            self.x = -self.width
            self.speed = 1.8
        self.active = True
        self.crashing = False
        self.spawn_timer = 0
        self.invulnerable_frames = 45
        self.crash_velocity_y = 0.4
        self.crash_gravity = 0.18
        self.engine_sound = engine_sound
        self.sound_channel: Optional[pygame.mixer.Channel] = None
        self.flame_particles: list[dict[str, float]] = []
        if self.engine_sound is not None:
            try:
                self.sound_channel = self.engine_sound.play(-1)
                if self.sound_channel:
                    self.sound_channel.set_volume(0.6)
            except Exception:  # noqa: BLE001
                self.sound_channel = None

    def get_rect(self) -> pygame.Rect:
        return pygame.Rect(int(self.x), int(self.y), self.width, self.height)

    def update(self, ball_rect: Optional[pygame.Rect], last_hit_by: Optional[str]) -> dict:
        if not self.active:
            self._update_flame_particles()
            return {"finished": True}

        self.spawn_timer += 1
        events: dict = {}

        if not self.crashing:
            self.x += self.speed
            # 폭격기는 공에 맞아도 추락하지 않는다
            if self.direction == "left_to_right" and self.x > self.screen_width + self.width:
                self.active = False
                events["finished"] = True
            elif self.direction == "right_to_left" and self.x < -self.width:
                self.active = False
                events["finished"] = True
            self._spawn_flame_particles(count=2)
        else:
            self.x += self.speed * 0.35
            self.crash_velocity_y = min(self.crash_velocity_y + self.crash_gravity, 6)
            self.y += self.crash_velocity_y
            if self.y >= self.screen_height - 96:
                self.active = False
                events["crash_landed"] = True
            self._spawn_flame_particles(count=1)

        self._update_flame_particles()

        if not self.active:
            self.stop_sound()

        return events

    def can_drop(self) -> bool:
        return self.active and not self.crashing and self.spawn_timer >= self.invulnerable_frames

    def drop_anchor(self, center_y: float) -> tuple[float, float]:
        drop_x = self.x + self.width * 0.3
        drop_y = center_y + random.uniform(-40, 40)
        return drop_x, drop_y

    def draw(self, surface: pygame.Surface) -> None:
        if not self.active and not self.crashing and not self.flame_particles:
            return

        # 엔진 배기 화염 그리기
        for particle in self.flame_particles:
            ratio = particle["life"] / particle["max_life"] if particle["max_life"] else 0
            outer_color = (
                int(120 + 135 * ratio),
                int(60 + 110 * ratio),
                int(30 + 70 * ratio),
            )
            inner_color = (
                255,
                int(200 * ratio + 40),
                int(120 * ratio + 20),
            )
            center = (int(particle["x"]), int(particle["y"]))
            outer_radius = max(1, int(particle["radius"]))
            inner_radius = max(1, int(particle["radius"] * 0.55))
            pygame.draw.circle(surface, outer_color, center, outer_radius)
            pygame.draw.circle(surface, inner_color, center, inner_radius)

        if not self.active and not self.crashing:
            return

        import math
        current_time = pygame.time.get_ticks()

        base_x = self.x
        base_y = self.y
        w = self.width
        h = self.height

        # === 지면 그림자 (입체감) ===
        shadow_y = min(base_y + 80, self.screen_height - 20)
        shadow_scale = max(0.4, 1 - (shadow_y - base_y) / 150)
        shadow_width = int(w * 1.1 * shadow_scale)
        shadow_height = int(h * 0.3 * shadow_scale)
        shadow_surface = pygame.Surface((shadow_width + 20, shadow_height + 10), pygame.SRCALPHA)
        shadow_alpha = int(40 * shadow_scale)
        pygame.draw.ellipse(shadow_surface, (0, 0, 0, shadow_alpha), (10, 5, shadow_width, shadow_height))
        surface.blit(shadow_surface, (int(base_x + w // 2 - shadow_width // 2 - 10), int(shadow_y)))

        # B-2 스텔스 폭격기 - 고퀄리티 검정색 디자인
        # 색상 팔레트 (사진 참조 - 매우 어두운 회색/검정)
        if not self.crashing:
            main_dark = (18, 18, 22)       # 가장 어두운 부분
            main_mid = (28, 28, 32)        # 중간 톤
            main_light = (38, 38, 45)      # 밝은 부분 (반사광)
            highlight = (55, 55, 65)       # 하이라이트
            outline = (8, 8, 10)           # 외곽선
            panel_line = (22, 22, 26)      # 패널 라인
        else:
            main_dark = (45, 35, 30)
            main_mid = (60, 50, 40)
            main_light = (75, 60, 50)
            highlight = (90, 75, 60)
            outline = (30, 25, 20)
            panel_line = (40, 32, 28)

        # B-2 Spirit 스텔스 폭격기 - 실제 사진 참고
        # 특징: 앞=뾰족한 노즈, 뒤=W자 형태 (중앙이 앞으로 튀어나옴)
        # 날개가 매우 넓고 얇은 형태
        if self.direction == "left_to_right":
            # 오른쪽으로 날아감 (오른쪽=앞, 왼쪽=뒤)
            body_points = [
                # === 노즈 (앞부분 - 뾰족한 삼각형) ===
                self._to_screen_point(base_x, base_y, w, h, 1.00, 0.50),  # 노즈 끝

                # === 상단 날개 leading edge (앞전) ===
                self._to_screen_point(base_x, base_y, w, h, 0.85, 0.20),  # 노즈에서 날개로
                self._to_screen_point(base_x, base_y, w, h, 0.55, 0.00),  # 상단 날개 끝

                # === 상단 날개 trailing edge (뒷전) - W자의 상단 부분 ===
                self._to_screen_point(base_x, base_y, w, h, 0.35, 0.08),  # 날개 뒤쪽 시작
                self._to_screen_point(base_x, base_y, w, h, 0.18, 0.25),  # W자 외측 끝 (상단)

                # === W자 중앙 돌출부 (상단) ===
                self._to_screen_point(base_x, base_y, w, h, 0.28, 0.38),  # W자 안쪽 (상단)

                # === 중앙 후방 (W자의 가운데 튀어나온 부분) ===
                self._to_screen_point(base_x, base_y, w, h, 0.08, 0.50),  # 중앙 꼬리

                # === W자 중앙 돌출부 (하단) ===
                self._to_screen_point(base_x, base_y, w, h, 0.28, 0.62),  # W자 안쪽 (하단)

                # === 하단 날개 trailing edge - W자의 하단 부분 ===
                self._to_screen_point(base_x, base_y, w, h, 0.18, 0.75),  # W자 외측 끝 (하단)
                self._to_screen_point(base_x, base_y, w, h, 0.35, 0.92),  # 날개 뒤쪽 끝

                # === 하단 날개 leading edge (앞전) ===
                self._to_screen_point(base_x, base_y, w, h, 0.55, 1.00),  # 하단 날개 끝
                self._to_screen_point(base_x, base_y, w, h, 0.85, 0.80),  # 날개에서 노즈로
            ]
        else:
            # 왼쪽으로 날아감 (왼쪽=앞, 오른쪽=뒤)
            body_points = [
                # === 노즈 (앞부분 - 뾰족한 삼각형) ===
                self._to_screen_point(base_x, base_y, w, h, 0.00, 0.50),  # 노즈 끝

                # === 상단 날개 leading edge ===
                self._to_screen_point(base_x, base_y, w, h, 0.15, 0.20),
                self._to_screen_point(base_x, base_y, w, h, 0.45, 0.00),  # 상단 날개 끝

                # === 상단 날개 trailing edge - W자 ===
                self._to_screen_point(base_x, base_y, w, h, 0.65, 0.08),
                self._to_screen_point(base_x, base_y, w, h, 0.82, 0.25),  # W자 외측 끝 (상단)

                # === W자 중앙 돌출부 (상단) ===
                self._to_screen_point(base_x, base_y, w, h, 0.72, 0.38),

                # === 중앙 후방 ===
                self._to_screen_point(base_x, base_y, w, h, 0.92, 0.50),  # 중앙 꼬리

                # === W자 중앙 돌출부 (하단) ===
                self._to_screen_point(base_x, base_y, w, h, 0.72, 0.62),

                # === 하단 날개 trailing edge - W자 ===
                self._to_screen_point(base_x, base_y, w, h, 0.82, 0.75),  # W자 외측 끝 (하단)
                self._to_screen_point(base_x, base_y, w, h, 0.65, 0.92),

                # === 하단 날개 leading edge ===
                self._to_screen_point(base_x, base_y, w, h, 0.45, 1.00),  # 하단 날개 끝
                self._to_screen_point(base_x, base_y, w, h, 0.15, 0.80),
            ]

        # === 메인 동체 (다층 레이어로 입체감) ===
        # 1. 베이스 레이어 (가장 어두운)
        pygame.draw.polygon(surface, main_dark, body_points)

        # 2. 중앙 볼록한 부분 (동체 중심부)
        if self.direction == "left_to_right":
            center_body = [
                self._to_screen_point(base_x, base_y, w, h, 0.92, 0.50),  # 노즈 쪽
                self._to_screen_point(base_x, base_y, w, h, 0.75, 0.35),  # 상단
                self._to_screen_point(base_x, base_y, w, h, 0.40, 0.40),  # 후방 상단
                self._to_screen_point(base_x, base_y, w, h, 0.18, 0.50),  # 후방 중앙
                self._to_screen_point(base_x, base_y, w, h, 0.40, 0.60),  # 후방 하단
                self._to_screen_point(base_x, base_y, w, h, 0.75, 0.65),  # 하단
            ]
        else:
            center_body = [
                self._to_screen_point(base_x, base_y, w, h, 0.08, 0.50),  # 노즈 쪽
                self._to_screen_point(base_x, base_y, w, h, 0.25, 0.35),  # 상단
                self._to_screen_point(base_x, base_y, w, h, 0.60, 0.40),  # 후방 상단
                self._to_screen_point(base_x, base_y, w, h, 0.82, 0.50),  # 후방 중앙
                self._to_screen_point(base_x, base_y, w, h, 0.60, 0.60),  # 후방 하단
                self._to_screen_point(base_x, base_y, w, h, 0.25, 0.65),  # 하단
            ]
        pygame.draw.polygon(surface, main_mid, center_body)

        # 3. 상단 반사광 (광원 효과)
        if self.direction == "left_to_right":
            highlight_body = [
                self._to_screen_point(base_x, base_y, w, h, 0.88, 0.48),
                self._to_screen_point(base_x, base_y, w, h, 0.70, 0.40),
                self._to_screen_point(base_x, base_y, w, h, 0.45, 0.44),
                self._to_screen_point(base_x, base_y, w, h, 0.45, 0.50),
                self._to_screen_point(base_x, base_y, w, h, 0.70, 0.48),
            ]
        else:
            highlight_body = [
                self._to_screen_point(base_x, base_y, w, h, 0.12, 0.48),
                self._to_screen_point(base_x, base_y, w, h, 0.30, 0.40),
                self._to_screen_point(base_x, base_y, w, h, 0.55, 0.44),
                self._to_screen_point(base_x, base_y, w, h, 0.55, 0.50),
                self._to_screen_point(base_x, base_y, w, h, 0.30, 0.48),
            ]
        pygame.draw.polygon(surface, main_light, highlight_body)

        # === 외곽선 (선명한 실루엣) ===
        pygame.draw.polygon(surface, outline, body_points, 2)

        # === 패널 라인 디테일 (스텔스 코팅 패널) ===
        if self.direction == "left_to_right":
            # 상단 날개 패널 라인들
            panel_sets = [
                (0.80, 0.25, 0.50, 0.15),   # 상단 날개 앞쪽
                (0.70, 0.20, 0.45, 0.12),   # 상단 날개 중간
                (0.60, 0.15, 0.40, 0.10),   # 상단 날개 끝쪽
                # 하단 날개 패널 라인들 (대칭)
                (0.80, 0.75, 0.50, 0.85),   # 하단 날개 앞쪽
                (0.70, 0.80, 0.45, 0.88),   # 하단 날개 중간
                (0.60, 0.85, 0.40, 0.90),   # 하단 날개 끝쪽
            ]
        else:
            panel_sets = [
                (0.20, 0.25, 0.50, 0.15),
                (0.30, 0.20, 0.55, 0.12),
                (0.40, 0.15, 0.60, 0.10),
                (0.20, 0.75, 0.50, 0.85),
                (0.30, 0.80, 0.55, 0.88),
                (0.40, 0.85, 0.60, 0.90),
            ]

        for px1, py1, px2, py2 in panel_sets:
            p1 = self._to_screen_point(base_x, base_y, w, h, px1, py1)
            p2 = self._to_screen_point(base_x, base_y, w, h, px2, py2)
            pygame.draw.line(surface, panel_line, p1, p2, 1)

        # === 엔진 배기구 (4개 - B-2 특징, 동체 후방에 위치) ===
        if self.direction == "left_to_right":
            engine_positions = [
                (0.25, 0.40), (0.25, 0.46),
                (0.25, 0.54), (0.25, 0.60),
            ]
        else:
            engine_positions = [
                (0.75, 0.40), (0.75, 0.46),
                (0.75, 0.54), (0.75, 0.60),
            ]

        for ex, ey in engine_positions:
            engine_pos = self._to_screen_point(base_x, base_y, w, h, ex, ey)
            # 엔진 노즐 (어두운 원)
            pygame.draw.circle(surface, (5, 5, 8), engine_pos, 5)
            pygame.draw.circle(surface, (15, 15, 20), engine_pos, 4)
            pygame.draw.circle(surface, outline, engine_pos, 5, 1)

            # 엔진 열기 효과 (추진 중)
            if not self.crashing:
                heat_glow = pygame.Surface((16, 16), pygame.SRCALPHA)
                heat_alpha = int(60 + 30 * math.sin(current_time * 0.01))
                pygame.draw.circle(heat_glow, (255, 150, 80, heat_alpha), (8, 8), 6)
                if self.direction == "left_to_right":
                    surface.blit(heat_glow, (engine_pos[0] - 16, engine_pos[1] - 8))
                else:
                    surface.blit(heat_glow, (engine_pos[0] + 2, engine_pos[1] - 8))

        # === 콕핏 (유리창 반사 - 노즈 근처에 위치) ===
        if self.direction == "left_to_right":
            cockpit_center = self._to_screen_point(base_x, base_y, w, h, 0.78, 0.50)
        else:
            cockpit_center = self._to_screen_point(base_x, base_y, w, h, 0.22, 0.50)

        cockpit_w = int(w * 0.08)
        cockpit_h = int(h * 0.18)

        # 콕핏 베이스 (어두운 유리)
        cockpit_rect = pygame.Rect(
            cockpit_center[0] - cockpit_w // 2,
            cockpit_center[1] - cockpit_h // 2,
            cockpit_w,
            cockpit_h,
        )
        pygame.draw.ellipse(surface, (15, 20, 30), cockpit_rect)

        # 콕핏 유리 반사 (밝은 부분)
        reflection_rect = pygame.Rect(
            cockpit_center[0] - cockpit_w // 3,
            cockpit_center[1] - cockpit_h // 3,
            cockpit_w // 2,
            cockpit_h // 3,
        )
        pygame.draw.ellipse(surface, (40, 50, 70), reflection_rect)

        # 콕핏 하이라이트 (작은 반사점)
        pygame.draw.circle(surface, (70, 85, 110), (cockpit_center[0] - 2, cockpit_center[1] - 3), 2)

        pygame.draw.ellipse(surface, outline, cockpit_rect, 1)

        # === 날개 앞전 하이라이트 (스텔스 코팅 반사) ===
        if self.direction == "left_to_right":
            # 노즈에서 상단 날개 끝까지 (leading edge)
            edge_start = self._to_screen_point(base_x, base_y, w, h, 1.00, 0.50)
            edge_mid = self._to_screen_point(base_x, base_y, w, h, 0.85, 0.20)
            edge_end = self._to_screen_point(base_x, base_y, w, h, 0.55, 0.00)
            pygame.draw.line(surface, highlight, edge_start, edge_mid, 2)
            pygame.draw.line(surface, highlight, edge_mid, edge_end, 1)
            # 노즈에서 하단 날개 끝까지
            edge_mid2 = self._to_screen_point(base_x, base_y, w, h, 0.85, 0.80)
            edge_end2 = self._to_screen_point(base_x, base_y, w, h, 0.55, 1.00)
            pygame.draw.line(surface, highlight, edge_start, edge_mid2, 2)
            pygame.draw.line(surface, highlight, edge_mid2, edge_end2, 1)
        else:
            edge_start = self._to_screen_point(base_x, base_y, w, h, 0.00, 0.50)
            edge_mid = self._to_screen_point(base_x, base_y, w, h, 0.15, 0.20)
            edge_end = self._to_screen_point(base_x, base_y, w, h, 0.45, 0.00)
            pygame.draw.line(surface, highlight, edge_start, edge_mid, 2)
            pygame.draw.line(surface, highlight, edge_mid, edge_end, 1)
            edge_mid2 = self._to_screen_point(base_x, base_y, w, h, 0.15, 0.80)
            edge_end2 = self._to_screen_point(base_x, base_y, w, h, 0.45, 1.00)
            pygame.draw.line(surface, highlight, edge_start, edge_mid2, 2)
            pygame.draw.line(surface, highlight, edge_mid2, edge_end2, 1)

        # === 항법등 (깜빡임) - 날개 끝에 위치 ===
        nav_blink = (current_time // 500) % 2 == 0

        if self.direction == "left_to_right":
            # 상단 날개 끝 (녹색 - 우현)
            right_nav = self._to_screen_point(base_x, base_y, w, h, 0.55, 0.02)
            # 하단 날개 끝 (빨간 - 좌현)
            left_nav = self._to_screen_point(base_x, base_y, w, h, 0.55, 0.98)
        else:
            right_nav = self._to_screen_point(base_x, base_y, w, h, 0.45, 0.02)
            left_nav = self._to_screen_point(base_x, base_y, w, h, 0.45, 0.98)

        if nav_blink:
            # 빨간 항법등 (좌측)
            nav_glow_r = pygame.Surface((12, 12), pygame.SRCALPHA)
            pygame.draw.circle(nav_glow_r, (255, 50, 50, 100), (6, 6), 5)
            surface.blit(nav_glow_r, (left_nav[0] - 6, left_nav[1] - 6))
            pygame.draw.circle(surface, (255, 80, 80), left_nav, 2)

            # 녹색 항법등 (우측)
            nav_glow_g = pygame.Surface((12, 12), pygame.SRCALPHA)
            pygame.draw.circle(nav_glow_g, (50, 255, 50, 100), (6, 6), 5)
            surface.blit(nav_glow_g, (right_nav[0] - 6, right_nav[1] - 6))
            pygame.draw.circle(surface, (80, 255, 80), right_nav, 2)

        # === 꼬리 부분 안티 콜리전 라이트 (흰색 깜빡임 - 중앙 후방) ===
        if self.direction == "left_to_right":
            tail_light = self._to_screen_point(base_x, base_y, w, h, 0.10, 0.50)
        else:
            tail_light = self._to_screen_point(base_x, base_y, w, h, 0.90, 0.50)

        strobe_blink = (current_time // 200) % 4 == 0
        if strobe_blink:
            strobe_glow = pygame.Surface((16, 16), pygame.SRCALPHA)
            pygame.draw.circle(strobe_glow, (255, 255, 255, 150), (8, 8), 6)
            surface.blit(strobe_glow, (tail_light[0] - 8, tail_light[1] - 8))
            pygame.draw.circle(surface, (255, 255, 255), tail_light, 3)
        else:
            pygame.draw.circle(surface, (100, 100, 100), tail_light, 2)

        # === "USAF" 마킹 (미세한 디테일) ===
        # 작은 크기로 마킹 표시 (선택적)
        if self.direction == "left_to_right":
            marking_pos = self._to_screen_point(base_x, base_y, w, h, 0.50, 0.50)
        else:
            marking_pos = self._to_screen_point(base_x, base_y, w, h, 0.50, 0.50)

        # 작은 별 마크 (미 공군 표시)
        star_size = 3
        pygame.draw.circle(surface, (45, 45, 55), marking_pos, star_size)

    def _ratio_to_x(self, base_x: float, width: float, ratio: float) -> float:
        if self.direction == "left_to_right":
            return base_x + width * ratio
        return base_x + width * (1 - ratio)

    def _to_screen_point(
        self,
        base_x: float,
        base_y: float,
        width: float,
        height: float,
        px: float,
        py: float,
    ) -> tuple[int, int]:
        return (
            int(self._ratio_to_x(base_x, width, px)),
            int(base_y + height * py),
        )

    def _engine_positions(self) -> list[tuple[float, float]]:
        base_x = self.x
        base_y = self.y
        w = self.width
        h = self.height
        # B-2의 엔진은 날개 상단에 매립되어 있음
        if self.direction == "left_to_right":
            return [
                (self._ratio_to_x(base_x, w, 0.25), base_y + h * 0.30),
                (self._ratio_to_x(base_x, w, 0.25), base_y + h * 0.70),
            ]
        else:
            return [
                (self._ratio_to_x(base_x, w, 0.75), base_y + h * 0.30),
                (self._ratio_to_x(base_x, w, 0.75), base_y + h * 0.70),
            ]

    def _spawn_flame_particles(self, *, count: int) -> None:
        if count <= 0:
            return
        max_particles = 120
        if len(self.flame_particles) >= max_particles:
            return

        direction_sign = 1 if self.direction == "left_to_right" else -1
        for engine_x, engine_y in self._engine_positions():
            for _ in range(count):
                spawn_x = engine_x - direction_sign * random.uniform(5.5, 9.5)
                spawn_y = engine_y + random.uniform(-2.5, 2.5)
                particle = {
                    "x": spawn_x,
                    "y": spawn_y,
                    "vx": -direction_sign * random.uniform(0.6, 1.4),
                    "vy": random.uniform(-0.25, 0.25),
                    "gravity": 0.02,
                    "radius": random.uniform(3.2, 5.6),
                    "life": random.randint(12, 18),
                }
                particle["max_life"] = particle["life"]
                self.flame_particles.append(particle)
                if len(self.flame_particles) >= max_particles:
                    return

    def _update_flame_particles(self) -> None:
        if not self.flame_particles:
            return
        updated: list[dict[str, float]] = []
        for particle in self.flame_particles:
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            particle["vy"] += particle["gravity"]
            particle["radius"] = max(1.2, particle["radius"] * 0.94)
            particle["life"] -= 1
            if particle["life"] > 0:
                updated.append(particle)
        self.flame_particles = updated

    def stop_sound(self) -> None:
        if self.sound_channel:
            try:
                self.sound_channel.stop()
            except Exception:  # noqa: BLE001
                pass
            self.sound_channel = None


class FireSupport:
    """병사 화력지원 무기."""

    CALL_LOCK_FRAMES = 42  # 0.7초 동안 무전 교신 연출 유지 (60fps 기준)
    MIN_DELAY_FRAMES = 120
    MAX_DELAY_FRAMES = 180
    BOMB_INTERVAL_FRAMES = 60
    BOMB_MIN_COUNT = 5
    BOMB_MAX_COUNT = 7
    BOMB_GRAVITY = 0.35
    BOMB_INITIAL_VY = 2.0
    BOMB_HORIZONTAL_JITTER = 1.1
    MAX_AMMO = 1

    def __init__(self) -> None:
        self.equipped = False
        self.ammo_count = 0
        self.strike_active = False
        self.calling = False
        self.call_timer = 0
        self.delay_timer = 0
        self.bombs_remaining = 0
        self.bomb_cooldown = 0
        self.bombs: List[Bomb] = []
        self.aircraft: Optional[FireSupportAircraft] = None
        self.screen_width = 0
        self.screen_height = 0
        self.finished = False
        self.radio_active = False
        self.last_bomb_y = 0.0
        self.max_ammo = self.MAX_AMMO
        self._has_initial_load = False
        self.reuse_locked = False
        self.radio_channel: Optional[pygame.mixer.Channel] = None
        self._radio_sound: pygame.mixer.Sound | bool | None = None
        self.radio_volume = 0.85
        self.radio_sound_played = False

    def reset_state(self) -> None:
        self.strike_active = False
        self.calling = False
        self.call_timer = 0
        self.delay_timer = 0
        self.bombs_remaining = 0
        self.bomb_cooldown = 0
        self.bombs.clear()
        if self.aircraft:
            self.aircraft.stop_sound()
        self.aircraft = None
        self.finished = False
        self.radio_active = False
        self.last_bomb_y = 0.0
        self.reuse_locked = False
        self._stop_radio_sound()
        self.radio_sound_played = False

    def on_acquired(self) -> None:
        track_reload = self._has_initial_load
        self.rearm(track_reload=track_reload)
        self._has_initial_load = True

    def reset_runtime(self) -> None:
        self.reset_state()
        self.ammo_count = 0
        self._has_initial_load = False

    def rearm(self, *, track_reload: bool = False, ammo_override: Optional[int] = None) -> None:
        self.reset_state()
        if ammo_override is not None:
            self.max_ammo = max(1, ammo_override)
        self.ammo_count = self.max_ammo
        # 화력지원은 재장전 시 곧바로 재사용 가능해야 하므로 equip 상태를 복원한다.
        self.equip()
        if track_reload:
            tracker = self._get_reload_tracker()
            if tracker:
                tracker("fire_support")

    def equip(self) -> None:
        self.equipped = True

    def unequip(self) -> None:
        self.equipped = False

    def can_call(self) -> bool:
        return (
            self.equipped
            and self.ammo_count > 0
            and not self.strike_active
            and not self.reuse_locked
        )

    def start_call(self, screen_width: int, screen_height: int, cruise_y: Optional[float] = None) -> bool:
        if not self.can_call():
            return False

        self.reset_state()
        self.strike_active = True
        self.calling = True
        self.call_timer = self.CALL_LOCK_FRAMES
        self.delay_timer = random.randint(self.MIN_DELAY_FRAMES, self.MAX_DELAY_FRAMES)
        self.bombs_remaining = random.randint(self.BOMB_MIN_COUNT, self.BOMB_MAX_COUNT)
        self.screen_width = screen_width
        self.screen_height = screen_height
        self.ammo_count = max(0, self.ammo_count - 1)
        self.radio_active = True
        self.reuse_locked = True
        self.radio_sound_played = False
        self._play_radio_sound_once()
        # equip 상태를 유지해 화기 슬롯 UI 애니메이션이 끊기지 않도록 한다.
        self._notify_lockout()
        if cruise_y is not None:
            engine_sound = self._get_aircraft_sound()
            direction = random.choice(["left_to_right", "right_to_left"])
            self.aircraft = FireSupportAircraft(
                screen_width,
                screen_height,
                cruise_y,
                engine_sound=engine_sound,
                direction=direction,
            )
            self.aircraft.spawn_timer = self.aircraft.invulnerable_frames
            self.calling = False
            self.delay_timer = 0
        return True

    def update(
        self,
        *,
        boss_rect: pygame.Rect,
        ball_rect: Optional[pygame.Rect],
        last_hit_by: Optional[str],
        create_explosion: Callable[[float, float], None],
    ) -> None:
        if not self.strike_active:
            return

        if self.radio_channel and not self.radio_channel.get_busy():
            self.radio_channel = None

        if self.radio_active and not self.radio_sound_played:
            self._play_radio_sound_once()

        if self.calling:
            if self.call_timer > 0:
                self.call_timer -= 1
            if self.call_timer <= 0:
                self.calling = False
            return

        if self.delay_timer > 0:
            self.delay_timer -= 1
            if self.delay_timer == 0:
                cruise_y = _get_supply_aircraft_altitude()
                engine_sound = self._get_aircraft_sound()
                self.aircraft = FireSupportAircraft(
                    self.screen_width,
                    self.screen_height,
                    cruise_y,
                    engine_sound=engine_sound,
                )
                self.last_bomb_y = boss_rect.centery

        if self.aircraft:
            events = self.aircraft.update(ball_rect, last_hit_by)
            if events.get("crash_landed") or events.get("finished"):
                self.aircraft.stop_sound()
                self.aircraft = None
            if self.aircraft and self.aircraft.can_drop() and self.bombs_remaining > 0:
                if self.bomb_cooldown <= 0 and self.aircraft.spawn_timer >= 60:
                    drop_x = random.uniform(60, self.screen_width - 60)
                    drop_y = boss_rect.centery + random.uniform(-50, 50)
                    self.last_bomb_y = drop_y
                    bomb = Bomb(
                        x=drop_x,
                        y=drop_y,
                        vx=0.0,
                        vy=self.BOMB_INITIAL_VY,
                        gravity=self.BOMB_GRAVITY,
                        target_y=min(self.screen_height - 60, boss_rect.centery + random.randint(-50, 50)),
                    )
                    self.bombs.append(bomb)
                    self.bombs_remaining -= 1
                    self.bomb_cooldown = self.BOMB_INTERVAL_FRAMES
                if self.bomb_cooldown > 0:
                    self.bomb_cooldown -= 1
        else:
            self.bomb_cooldown = 0

        if self.bombs:
            new_bombs: List[Bomb] = []
            for bomb in self.bombs:
                bomb.x += bomb.vx
                bomb.y += bomb.vy
                bomb.vy += bomb.gravity
                bomb.life -= 1
                if bomb.y >= bomb.target_y or bomb.life <= 0:
                    create_explosion(bomb.x, bomb.y)
                elif bomb.y < self.screen_height:
                    new_bombs.append(bomb)
            self.bombs = new_bombs

        if self.aircraft is None and not self.bombs and self.bombs_remaining <= 0:
            self.strike_active = False
            self.finished = True
            self.radio_active = False
            self.reuse_locked = False

    def draw(self, surface: pygame.Surface) -> None:
        if self.aircraft:
            self.aircraft.draw(surface)
        for bomb in self.bombs:
            pos = (int(bomb.x), int(bomb.y))
            pygame.draw.circle(surface, (255, 200, 120), pos, 6)
            pygame.draw.circle(surface, (255, 120, 60), pos, 3)

    def is_calling(self) -> bool:
        return self.strike_active and self.calling

    def is_active(self) -> bool:
        return self.strike_active or bool(self.bombs)

    def is_locked(self) -> bool:
        return self.reuse_locked

    def should_remove_weapon(self) -> bool:
        # 화력지원 장비는 탄약이 소진되어도 UI에서 비활성 상태를 표시해야 하므로 슬롯에서 제거하지 않는다.
        return False

    def clear_finished_flag(self) -> None:
        self.finished = False

    def _notify_lockout(self) -> None:
        module = sys.modules.get("pingfighter")
        if not module:
            return
        handler = getattr(module, "handle_fire_support_lockout", None)
        if callable(handler):
            try:
                handler()
            except Exception:  # noqa: BLE001
                pass

    def _stop_radio_sound(self) -> None:
        if self.radio_channel:
            try:
                self.radio_channel.stop()
            except Exception:  # noqa: BLE001
                pass
            self.radio_channel = None

    def _play_radio_sound_once(self) -> None:
        if self.radio_sound_played:
            return
        sound = self._get_radio_sound()
        if sound is None:
            return
        try:
            self.radio_channel = sound.play()
            if self.radio_channel:
                self.radio_channel.set_volume(self.radio_volume)
        except Exception:  # noqa: BLE001
            self.radio_channel = None
        self.radio_sound_played = True

    def _get_radio_sound(self) -> Optional[pygame.mixer.Sound]:
        if self._radio_sound is None:
            try:
                from resource_path import resource_path

                sound_path = resource_path("sounds/radio.wav")
                sound = pygame.mixer.Sound(sound_path)
                sound.set_volume(self.radio_volume)
                self._radio_sound = sound
            except Exception:  # noqa: BLE001
                self._radio_sound = False
        if self._radio_sound is False:
            return None
        return self._radio_sound

    def _get_reload_tracker(self) -> Callable[[str], None] | None:
        for module_name in ("__main__", "pingfighter"):
            module = sys.modules.get(module_name)
            if not module:
                continue
            tracker = getattr(module, "register_weapon_reload", None)
            if callable(tracker):
                return tracker
        return None

    def _get_aircraft_sound(self) -> Optional[pygame.mixer.Sound]:
        for module_name in ("pingfighter", "__main__"):
            module = sys.modules.get(module_name)
            if not module:
                continue
            sound = getattr(module, "SOUND_AIRPLANE", None)
            if sound is not None:
                return sound
        try:
            from resource_path import resource_path

            sound_path = resource_path("sounds/airplane.wav")
            return pygame.mixer.Sound(sound_path)
        except Exception:  # noqa: BLE001
            return None


_fire_support_instance: Optional[FireSupport] = None


def get_fire_support_instance() -> FireSupport:
    global _fire_support_instance
    if _fire_support_instance is None:
        _fire_support_instance = FireSupport()
    return _fire_support_instance
def _get_supply_aircraft_altitude() -> float:
    """물자보급 비행기의 기본 고도를 조회한다."""

    module = sys.modules.get("pingfighter")
    if module:
        supply_cls = getattr(module, "SupplyAircraft", None)
        if supply_cls is not None:
            if hasattr(supply_cls, "DEFAULT_ALTITUDE"):
                return float(getattr(supply_cls, "DEFAULT_ALTITUDE"))
            if hasattr(supply_cls, "y"):
                try:
                    return float(getattr(supply_cls, "y"))
                except Exception:  # noqa: BLE001
                    pass
    return 50.0
