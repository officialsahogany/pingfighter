"""Stage 8 전용 애니메이션 배경 - 닌자 저택.

닌자 컨셉 애니메이션: 수리검, 닌자 그림자, 연기, 창문 빛 효과.
"""

from __future__ import annotations

import math
import random
from typing import List, Tuple

import pygame

Color = Tuple[int, int, int]

# 화면 크기 - config에서 가져오기
try:
    from config.constants import PILLAR_UI_WIDTH, GAME_PLAY_WIDTH
    PILLAR_OFFSET = PILLAR_UI_WIDTH  # 80px
    GAME_WIDTH = GAME_PLAY_WIDTH  # 600px
except ImportError:
    PILLAR_OFFSET = 80
    GAME_WIDTH = 600


class AnimatedBackgroundStage8:
    """Stage 8 배경 위에 얹는 애니메이션 오버레이."""

    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.time = 0.0

        # 등불 위치 (배경과 동일)
        self.lantern_positions: List[Tuple[int, int]] = [
            (30, 200),
            (30, height - 200),
            (width - 30, 200),
            (width - 30, height - 200),
        ]

        # 등불 상태
        self.lantern_states: List[dict] = []
        for _ in range(len(self.lantern_positions)):
            self.lantern_states.append({
                "phase": random.uniform(0, math.tau),
                "intensity": random.uniform(0.7, 1.0),
                "flicker_speed": random.uniform(2.0, 4.0),
            })

        # 창문 위치
        self.window_positions_left = [
            (5, 80, 50, 120),
            (5, 280, 50, 120),
            (5, 480, 50, 120),
        ]
        self.window_positions_right = [
            (width - 55, 80, 50, 120),
            (width - 55, 280, 50, 120),
            (width - 55, 480, 50, 120),
        ]
        # 상단 창문 위치 (5개 연속 창문) - 오동나무 저택
        total_win_width = width - 120 - 60
        num_windows = 5
        win_margin = 8
        win_w = (total_win_width - (num_windows + 1) * win_margin) // num_windows
        self.window_positions_top = []
        for i in range(num_windows):
            wx = 60 + win_margin + i * (win_w + win_margin)
            self.window_positions_top.append((wx, 25, win_w, 85))

        # 창문 빛 상태 (6 + 5 = 11개)
        self.window_states: List[dict] = []
        for _ in range(11):
            self.window_states.append({
                "phase": random.uniform(0, math.tau),
                "intensity": random.uniform(0.3, 0.6),
                "speed": random.uniform(0.5, 1.5),
            })

        # 스타디움 펄스
        self.stadium_pulse_phase = 0.0
        self.stadium_line_y = height // 2
        self.stadium_circle_radius = 80

        # === 닌자 애니메이션 요소들 ===

        # 회전하는 수리검들
        self.shurikens: List[dict] = []
        for _ in range(3):
            self._spawn_shuriken()

        # 스쳐 지나가는 닌자 그림자
        self.ninja_shadow_active = False
        self.ninja_shadow_x = -100
        self.ninja_shadow_y = height // 2
        self.ninja_shadow_speed = 0
        self.ninja_shadow_cooldown = random.uniform(8.0, 15.0)
        self.ninja_run_phase = 0.0  # 달리기 애니메이션 페이즈

        # 연기/안개 효과
        self.smoke_particles: List[dict] = []
        for _ in range(12):
            self.smoke_particles.append({
                "x": random.uniform(70, width - 70),
                "y": random.uniform(height - 150, height - 50),
                "size": random.uniform(20, 50),
                "alpha": random.randint(15, 35),
                "speed_x": random.uniform(-10, 10),
                "speed_y": random.uniform(-8, -2),
                "phase": random.uniform(0, math.tau),
            })

        # 떨어지는 벚꽃잎 (닌자 저택 분위기)
        self.petals: List[dict] = []
        for _ in range(8):
            self.petals.append({
                "x": random.uniform(70, width - 70),
                "y": random.uniform(-50, height),
                "speed_y": random.uniform(15, 35),
                "sway_phase": random.uniform(0, math.tau),
                "sway_speed": random.uniform(1.5, 3.0),
                "size": random.randint(3, 6),
                "rotation": random.uniform(0, math.tau),
                "rot_speed": random.uniform(1, 3),
            })

        # 먼지 입자
        self.dust_particles: List[dict] = []
        for _ in range(15):
            self.dust_particles.append({
                "x": random.uniform(70, width - 70),
                "y": random.uniform(60, height - 60),
                "speed_x": random.uniform(-5.0, 5.0),
                "speed_y": random.uniform(-3.0, 3.0),
                "phase": random.uniform(0, math.tau),
                "radius": random.uniform(1.0, 2.0),
                "alpha": random.randint(20, 40),
            })

        # 족자 캐시 생성 (마지막 창문 오른쪽에 배치)
        self._scroll_cache: pygame.Surface | None = None
        self._create_scroll_cache()

    def _create_scroll_cache(self) -> None:
        """족자(카게무노) 캐시 생성 - 마지막 창문 오른쪽에 배치."""
        # 마지막(5번째) 창문 위치 가져오기
        if not self.window_positions_top or len(self.window_positions_top) < 5:
            return

        last_win = self.window_positions_top[4]  # 5번째 창문 (0-indexed)
        last_win_x, last_win_y, last_win_w, last_win_h = last_win
        last_win_right = last_win_x + last_win_w

        # 족자 위치: 마지막 창문 오른쪽 + 여백
        scroll_x = last_win_right + 8
        # 게임 영역 오른쪽 끝 (width - 60)까지 남은 공간
        game_right_edge = self.width - 60
        available_width = game_right_edge - scroll_x - 5

        if available_width < 25:
            return

        # 족자 크기 (창문과 같은 높이)
        scroll_width = min(available_width - 4, 45)
        scroll_height = last_win_h  # 창문 높이와 동일 (85)
        scroll_y = last_win_y  # 창문 Y와 동일 (25)

        # 족자 캐시 생성
        cache_w = scroll_width + 20  # 여유 공간
        cache_h = scroll_height + 30
        self._scroll_cache = pygame.Surface((cache_w, cache_h), pygame.SRCALPHA)
        self._scroll_x = scroll_x
        self._scroll_y = scroll_y - 10  # 걸이 끈 공간

        # 족자 그리기 (캐시 내 로컬 좌표)
        local_x = 10  # 캐시 내 여백
        local_y = 10

        self._draw_hanging_scroll(self._scroll_cache, local_x, local_y,
                                  scroll_width, scroll_height)

    def _draw_hanging_scroll(self, surface: pygame.Surface, x: int, y: int,
                             width: int, height: int) -> None:
        """족자(카게무노) 그리기."""
        # 색상 정의
        wood_dark = (85, 65, 32)
        wood_mid = (120, 95, 48)
        scroll_border = (60, 45, 25)
        scroll_paper = (220, 210, 185)
        scroll_paper_dark = (180, 170, 145)
        scroll_gold = (180, 150, 80)
        scroll_red = (140, 45, 35)
        ink_black = (20, 18, 15)

        center_x = x + width // 2

        # === 상단 나무 봉 (축봉) ===
        rod_height = 6
        rod_extend = 4
        pygame.draw.rect(surface, wood_dark,
                        (x - rod_extend, y, width + rod_extend * 2, rod_height))
        pygame.draw.rect(surface, wood_mid,
                        (x - rod_extend, y + 1, width + rod_extend * 2, rod_height - 2))
        # 봉 끝 장식
        pygame.draw.circle(surface, scroll_gold,
                          (x - rod_extend + 2, y + rod_height // 2), 3)
        pygame.draw.circle(surface, scroll_gold,
                          (x + width + rod_extend - 2, y + rod_height // 2), 3)

        # 걸이 끈
        rope_y = y - 8
        pygame.draw.line(surface, scroll_border,
                        (center_x, rope_y), (center_x - 5, y), 1)
        pygame.draw.line(surface, scroll_border,
                        (center_x, rope_y), (center_x + 5, y), 1)
        pygame.draw.circle(surface, scroll_gold, (center_x, rope_y), 2)

        # === 족자 본체 ===
        body_y = y + rod_height
        border_width = 3

        # 테두리
        pygame.draw.rect(surface, scroll_border,
                        (x - border_width, body_y,
                         width + border_width * 2, height))

        # 종이 영역
        paper_margin = 2
        paper_rect = pygame.Rect(
            x - border_width + paper_margin,
            body_y + paper_margin,
            width + border_width * 2 - paper_margin * 2,
            height - paper_margin * 2
        )
        pygame.draw.rect(surface, scroll_paper, paper_rect)

        # 종이 그라데이션 (오래된 느낌)
        for i in range(0, paper_rect.height, 2):
            alpha = random.randint(3, 8)
            pygame.draw.line(surface, (*scroll_paper_dark, alpha),
                           (paper_rect.left, paper_rect.top + i),
                           (paper_rect.right, paper_rect.top + i), 1)

        # === 수묵화 대나무 ===
        bamboo_x = paper_rect.centerx - 2
        bamboo_bottom = paper_rect.bottom - 12
        bamboo_top = paper_rect.top + 13

        # 줄기
        pygame.draw.line(surface, ink_black,
                        (bamboo_x, bamboo_bottom), (bamboo_x, bamboo_top), 2)

        # 마디 (2개)
        bamboo_height = bamboo_bottom - bamboo_top
        for i in range(1, 3):
            node_y = bamboo_bottom - (bamboo_height * i) // 3
            pygame.draw.line(surface, ink_black,
                           (bamboo_x - 3, node_y), (bamboo_x + 2, node_y), 1)

        # 잎
        leaves = [
            (bamboo_x, bamboo_top + 5, 10, -0.6),
            (bamboo_x, bamboo_top + 10, 8, 0.5),
            (bamboo_x, bamboo_top + 20, 9, -0.4),
        ]
        for lx, ly, length, angle in leaves:
            end_x = lx + math.cos(angle) * length
            end_y = ly + math.sin(angle) * length * 0.3
            pygame.draw.line(surface, ink_black,
                           (lx, int(ly)), (int(end_x), int(end_y)), 2)

        # === 빨간 인장 ===
        seal_x = paper_rect.right - 8
        seal_y = paper_rect.bottom - 10
        seal_size = 6
        pygame.draw.rect(surface, scroll_red,
                        (seal_x - seal_size // 2, seal_y - seal_size // 2,
                         seal_size, seal_size))

        # === 하단 나무 봉 ===
        bottom_rod_y = body_y + height
        pygame.draw.rect(surface, wood_dark,
                        (x - rod_extend, bottom_rod_y,
                         width + rod_extend * 2, rod_height))
        pygame.draw.rect(surface, wood_mid,
                        (x - rod_extend, bottom_rod_y + 1,
                         width + rod_extend * 2, rod_height - 2))
        # 봉 끝 장식
        pygame.draw.circle(surface, scroll_gold,
                          (x - rod_extend + 2, bottom_rod_y + rod_height // 2), 3)
        pygame.draw.circle(surface, scroll_gold,
                          (x + width + rod_extend - 2, bottom_rod_y + rod_height // 2), 3)

    def _spawn_shuriken(self) -> None:
        """새 수리검 생성."""
        side = random.choice(["left", "right", "top"])
        if side == "left":
            x = -30
            y = random.randint(100, self.height - 100)
            speed_x = random.uniform(60, 120)
            speed_y = random.uniform(-30, 30)
        elif side == "right":
            x = self.width + 30
            y = random.randint(100, self.height - 100)
            speed_x = random.uniform(-120, -60)
            speed_y = random.uniform(-30, 30)
        else:
            x = random.randint(100, self.width - 100)
            y = -30
            speed_x = random.uniform(-30, 30)
            speed_y = random.uniform(60, 100)

        self.shurikens.append({
            "x": x,
            "y": y,
            "speed_x": speed_x,
            "speed_y": speed_y,
            "rotation": 0,
            "rot_speed": random.uniform(8, 15),
            "size": random.randint(12, 18),
            "alpha": random.randint(60, 100),
        })

    def update(self, elapsed_ms: int | float | None = None) -> None:
        """프레임마다 호출."""
        if elapsed_ms is None:
            elapsed_ms = 16
        dt = (elapsed_ms or 0) / 1000.0
        self.time += dt

        # 등불 업데이트
        for state in self.lantern_states:
            state["intensity"] = 0.7 + 0.3 * (0.5 + 0.5 * math.sin(
                self.time * state["flicker_speed"] + state["phase"]))
            if random.random() < 0.008:
                state["intensity"] *= random.uniform(0.4, 0.7)

        # 창문 빛 업데이트
        for state in self.window_states:
            state["intensity"] = 0.3 + 0.2 * math.sin(
                self.time * state["speed"] + state["phase"])

        # 스타디움 펄스
        self.stadium_pulse_phase = self.time * 1.0

        # 수리검 업데이트
        for shuriken in self.shurikens[:]:
            shuriken["x"] += shuriken["speed_x"] * dt
            shuriken["y"] += shuriken["speed_y"] * dt
            shuriken["rotation"] += shuriken["rot_speed"] * dt

            # 화면 밖으로 나가면 재생성
            if (shuriken["x"] < -50 or shuriken["x"] > self.width + 50 or
                shuriken["y"] < -50 or shuriken["y"] > self.height + 50):
                self.shurikens.remove(shuriken)
                self._spawn_shuriken()

        # 닌자 그림자 업데이트
        self.ninja_shadow_cooldown -= dt
        if self.ninja_shadow_cooldown <= 0 and not self.ninja_shadow_active:
            self._trigger_ninja_shadow()

        if self.ninja_shadow_active:
            self.ninja_shadow_x += self.ninja_shadow_speed * dt
            self.ninja_run_phase += dt * 18  # 빠른 달리기 애니메이션 속도
            if self.ninja_shadow_x > self.width + 150 or self.ninja_shadow_x < -150:
                self.ninja_shadow_active = False
                self.ninja_shadow_cooldown = random.uniform(10.0, 20.0)
                self.ninja_run_phase = 0.0

        # 연기 업데이트
        for smoke in self.smoke_particles:
            smoke["x"] += smoke["speed_x"] * dt
            smoke["y"] += smoke["speed_y"] * dt
            smoke["size"] += dt * 3  # 서서히 커짐
            smoke["alpha"] -= dt * 8  # 서서히 투명해짐

            # 리셋
            if smoke["alpha"] <= 0 or smoke["y"] < self.height - 200:
                smoke["x"] = random.uniform(70, self.width - 70)
                smoke["y"] = random.uniform(self.height - 100, self.height - 30)
                smoke["size"] = random.uniform(20, 40)
                smoke["alpha"] = random.randint(20, 40)
                smoke["speed_x"] = random.uniform(-10, 10)
                smoke["speed_y"] = random.uniform(-15, -5)

        # 벚꽃잎 업데이트
        for petal in self.petals:
            petal["y"] += petal["speed_y"] * dt
            petal["x"] += math.sin(self.time * petal["sway_speed"] + petal["sway_phase"]) * 20 * dt
            petal["rotation"] += petal["rot_speed"] * dt

            # 화면 아래로 나가면 위에서 다시
            if petal["y"] > self.height + 20:
                petal["y"] = -20
                petal["x"] = random.uniform(70, self.width - 70)

        # 먼지 입자 업데이트
        for dust in self.dust_particles:
            dust["x"] += dust["speed_x"] * dt
            dust["y"] += dust["speed_y"] * dt + math.sin(self.time * 0.5 + dust["phase"]) * 0.2

            if dust["x"] < 70:
                dust["x"] = self.width - 70
            elif dust["x"] > self.width - 70:
                dust["x"] = 70
            if dust["y"] < 60:
                dust["y"] = self.height - 60
            elif dust["y"] > self.height - 60:
                dust["y"] = 60

    def _trigger_ninja_shadow(self) -> None:
        """닌자 그림자 트리거."""
        self.ninja_shadow_active = True
        self.ninja_shadow_y = random.randint(150, self.height - 150)
        if random.random() > 0.5:
            self.ninja_shadow_x = -120
            self.ninja_shadow_speed = random.uniform(350, 550)
        else:
            self.ninja_shadow_x = self.width + 120
            self.ninja_shadow_speed = -random.uniform(350, 550)

    def draw(self, surface: pygame.Surface, *, offset: Tuple[int, int] = (0, 0)) -> None:
        """애니메이션 레이어를 그린다."""
        ox, oy = offset
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

        # 1. 연기 효과 (뒤쪽)
        self._draw_smoke(overlay)

        # 2. 족자 (창문 옆에 배치 - 다른 요소 뒤에)
        self._draw_scroll(overlay)

        # 3. 창문 빛 효과
        self._draw_window_glow(overlay)

        # 4. 등불 빛 효과
        self._draw_lantern_glow(overlay)

        # 5. 벚꽃잎
        self._draw_petals(overlay)

        # 6. 먼지 입자
        self._draw_dust(overlay)

        # 7. 수리검
        self._draw_shurikens(overlay)

        # 8. 닌자 그림자
        if self.ninja_shadow_active:
            self._draw_ninja_shadow(overlay)

        # 9. 스타디움 펄스
        self._draw_stadium_pulse(overlay)

        surface.blit(overlay, (ox, oy))

        # 테두리 (마지막에 그려서 위에 표시)
        self._draw_border(surface)

    def _draw_border(self, surface: pygame.Surface) -> None:
        """닌자 저택 테마 테두리 그리기"""
        border_thickness = 10
        # SCREEN Surface 전체를 감싸는 테두리 (SCREEN은 이미 게임 전체 영역)
        x_off = 0
        game_w = self.width
        h = self.height

        # 기본 테두리 색상 (진한 나무색/갈색 - 일본 저택 테마)
        base_color = (35, 25, 20)  # 어두운 갈색
        inner_color = (60, 45, 35)  # 밝은 갈색
        red_accent = (140, 50, 50)  # 붉은색 악센트

        # 메인 테두리
        pygame.draw.rect(surface, base_color, (x_off, 0, game_w, border_thickness))
        pygame.draw.rect(surface, base_color, (x_off, h - border_thickness, game_w, border_thickness))
        pygame.draw.rect(surface, base_color, (x_off, 0, border_thickness, h))
        pygame.draw.rect(surface, base_color, (x_off + game_w - border_thickness, 0, border_thickness, h))

        # 내부 테두리 (깊이감)
        inner_thickness = 2
        pygame.draw.rect(surface, inner_color,
                        (x_off + border_thickness - inner_thickness, border_thickness - inner_thickness,
                         game_w - 2*(border_thickness - inner_thickness), inner_thickness))
        pygame.draw.rect(surface, inner_color,
                        (x_off + border_thickness - inner_thickness, h - border_thickness,
                         game_w - 2*(border_thickness - inner_thickness), inner_thickness))
        pygame.draw.rect(surface, inner_color,
                        (x_off + border_thickness - inner_thickness, border_thickness - inner_thickness,
                         inner_thickness, h - 2*(border_thickness - inner_thickness)))
        pygame.draw.rect(surface, inner_color,
                        (x_off + game_w - border_thickness, border_thickness - inner_thickness,
                         inner_thickness, h - 2*(border_thickness - inner_thickness)))

        # 코너 장식 (붉은색 악센트)
        corner_radius = 5
        # 좌상단
        pygame.draw.circle(surface, red_accent, (x_off + border_thickness//2, border_thickness//2), corner_radius)
        # 우상단
        pygame.draw.circle(surface, red_accent, (x_off + game_w - border_thickness//2, border_thickness//2), corner_radius)
        # 좌하단
        pygame.draw.circle(surface, red_accent, (x_off + border_thickness//2, h - border_thickness//2), corner_radius)
        # 우하단
        pygame.draw.circle(surface, red_accent, (x_off + game_w - border_thickness//2, h - border_thickness//2), corner_radius)

    def _draw_scroll(self, overlay: pygame.Surface) -> None:
        """족자 캐시를 화면에 그리기."""
        if self._scroll_cache is not None and hasattr(self, '_scroll_x'):
            overlay.blit(self._scroll_cache, (self._scroll_x - 10, self._scroll_y))

    def _draw_smoke(self, overlay: pygame.Surface) -> None:
        """연기/안개 효과."""
        for smoke in self.smoke_particles:
            if smoke["alpha"] <= 0:
                continue
            size = int(smoke["size"])
            alpha = int(max(0, smoke["alpha"]))
            smoke_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            # 여러 겹의 원으로 부드러운 연기
            for i in range(3):
                r = size - i * (size // 4)
                a = alpha - i * (alpha // 4)
                if r > 0 and a > 0:
                    pygame.draw.circle(smoke_surf, (50, 45, 40, a), (size, size), r)
            overlay.blit(smoke_surf, (int(smoke["x"] - size), int(smoke["y"] - size)))

    def _draw_petals(self, overlay: pygame.Surface) -> None:
        """떨어지는 벚꽃잎."""
        for petal in self.petals:
            x, y = int(petal["x"]), int(petal["y"])
            size = petal["size"]
            rot = petal["rotation"]

            # 꽃잎 모양 (타원)
            petal_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            # 연한 분홍색
            color = (180, 120, 130, 80)
            pygame.draw.ellipse(petal_surf, color, (size // 2, 0, size, size * 2))

            # 회전 적용
            rotated = pygame.transform.rotate(petal_surf, math.degrees(rot))
            rect = rotated.get_rect(center=(x, y))
            overlay.blit(rotated, rect)

    def _draw_shurikens(self, overlay: pygame.Surface) -> None:
        """회전하는 수리검."""
        for shuriken in self.shurikens:
            x, y = int(shuriken["x"]), int(shuriken["y"])
            size = shuriken["size"]
            rot = shuriken["rotation"]
            alpha = shuriken["alpha"]

            # 수리검 그리기 (4개의 뾰족한 날)
            shuriken_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            center = size

            for i in range(4):
                angle = rot + i * (math.pi / 2)
                # 바깥 뾰족점
                outer_x = center + math.cos(angle) * size
                outer_y = center + math.sin(angle) * size
                # 안쪽 점 (양 옆)
                left_angle = angle - 0.4
                right_angle = angle + 0.4
                inner_dist = size * 0.3
                left_x = center + math.cos(left_angle) * inner_dist
                left_y = center + math.sin(left_angle) * inner_dist
                right_x = center + math.cos(right_angle) * inner_dist
                right_y = center + math.sin(right_angle) * inner_dist

                points = [(center, center), (left_x, left_y), (outer_x, outer_y), (right_x, right_y)]
                pygame.draw.polygon(shuriken_surf, (60, 60, 70, alpha), points)
                pygame.draw.polygon(shuriken_surf, (100, 100, 110, alpha), points, 1)

            # 중앙 원
            pygame.draw.circle(shuriken_surf, (50, 50, 55, alpha), (center, center), size // 4)

            overlay.blit(shuriken_surf, (x - size, y - size))

    def _draw_ninja_shadow(self, overlay: pygame.Surface) -> None:
        """스쳐 지나가는 닌자 그림자 - 빠르게 달리는 애니메이션."""
        x = int(self.ninja_shadow_x)
        y = int(self.ninja_shadow_y)
        facing_right = self.ninja_shadow_speed > 0

        # 달리기 애니메이션 사이클 (0~1)
        run_cycle = math.sin(self.ninja_run_phase) * 0.5 + 0.5

        # 잔상 효과
        for i in range(5):
            trail_offset = i * (-25 if facing_right else 25)
            trail_alpha = max(0, 110 - i * 22)

            # 잔상마다 약간 다른 애니메이션 페이즈 (달리는 느낌)
            trail_run_cycle = math.sin(self.ninja_run_phase - i * 0.4) * 0.5 + 0.5

            shadow_surf = pygame.Surface((100, 80), pygame.SRCALPHA)
            color = (10, 10, 15, trail_alpha)

            # 기준점
            cx, cy = 50, 40

            # 다리 애니메이션 값 계산 (교차하며 움직임)
            front_leg_angle = trail_run_cycle * 50 - 25  # -25도 ~ +25도
            back_leg_angle = -front_leg_angle  # 반대 방향

            # 팔 스윙 (다리와 반대)
            front_arm_swing = -trail_run_cycle * 20 + 10
            back_arm_swing = trail_run_cycle * 20 - 10

            # 몸의 상하 움직임 (달릴 때 약간 위아래로)
            body_bounce = math.sin(self.ninja_run_phase * 2 - i * 0.4) * 3

            if facing_right:
                # === 달리는 자세 (오른쪽으로 이동) ===

                # 머리 (앞으로 기울임)
                head_x = cx + 20
                head_y = cy - 12 + body_bounce
                pygame.draw.circle(shadow_surf, color, (head_x, int(head_y)), 9)

                # 몸통 (앞으로 기울어짐)
                body_y = cy + body_bounce
                body_points = [
                    (cx + 12, int(body_y - 18)),   # 어깨 위
                    (cx + 22, int(body_y - 8)),    # 어깨 앞
                    (cx + 5, int(body_y + 12)),    # 엉덩이
                    (cx - 5, int(body_y + 2)),     # 등
                ]
                pygame.draw.polygon(shadow_surf, color, body_points)

                # 앞팔 (달릴 때 뒤로 - 칼 들고)
                arm_start = (cx + 18, int(body_y - 5))
                arm_angle_rad = math.radians(-30 + front_arm_swing)
                arm_end_x = arm_start[0] + math.cos(arm_angle_rad) * 22
                arm_end_y = arm_start[1] + math.sin(arm_angle_rad) * 22
                pygame.draw.line(shadow_surf, color, arm_start, (int(arm_end_x), int(arm_end_y)), 4)
                # 칼
                sword_angle_rad = arm_angle_rad + 0.3
                sword_end_x = arm_end_x + math.cos(sword_angle_rad) * 18
                sword_end_y = arm_end_y + math.sin(sword_angle_rad) * 18
                pygame.draw.line(shadow_surf, color, (int(arm_end_x), int(arm_end_y)),
                               (int(sword_end_x), int(sword_end_y)), 3)

                # 뒷팔 (달릴 때 앞으로)
                back_arm_start = (cx + 5, int(body_y - 5))
                back_arm_angle_rad = math.radians(-60 + back_arm_swing)
                back_arm_end_x = back_arm_start[0] + math.cos(back_arm_angle_rad) * 18
                back_arm_end_y = back_arm_start[1] + math.sin(back_arm_angle_rad) * 18
                pygame.draw.line(shadow_surf, color, back_arm_start,
                               (int(back_arm_end_x), int(back_arm_end_y)), 4)

                # 앞다리 (달리기 - 앞으로 뻗음)
                hip = (cx + 8, int(body_y + 10))
                front_leg_rad = math.radians(70 + front_leg_angle)
                knee_x = hip[0] + math.cos(front_leg_rad) * 22
                knee_y = hip[1] + math.sin(front_leg_rad) * 22
                pygame.draw.line(shadow_surf, color, hip, (int(knee_x), int(knee_y)), 5)
                # 무릎부터 발
                foot_angle_rad = front_leg_rad + math.radians(20 - front_leg_angle * 0.5)
                foot_x = knee_x + math.cos(foot_angle_rad) * 18
                foot_y = knee_y + math.sin(foot_angle_rad) * 18
                pygame.draw.line(shadow_surf, color, (int(knee_x), int(knee_y)),
                               (int(foot_x), int(foot_y)), 4)

                # 뒷다리 (달리기 - 뒤로 뻗음)
                back_hip = (cx, int(body_y + 10))
                back_leg_rad = math.radians(110 + back_leg_angle)
                back_knee_x = back_hip[0] + math.cos(back_leg_rad) * 22
                back_knee_y = back_hip[1] + math.sin(back_leg_rad) * 22
                pygame.draw.line(shadow_surf, color, back_hip, (int(back_knee_x), int(back_knee_y)), 5)
                # 뒷다리 무릎부터 발
                back_foot_angle_rad = back_leg_rad + math.radians(-30 - back_leg_angle * 0.5)
                back_foot_x = back_knee_x + math.cos(back_foot_angle_rad) * 18
                back_foot_y = back_knee_y + math.sin(back_foot_angle_rad) * 18
                pygame.draw.line(shadow_surf, color, (int(back_knee_x), int(back_knee_y)),
                               (int(back_foot_x), int(back_foot_y)), 4)

                # 스카프/복면 끈 (뒤로 펄럭)
                scarf_wobble = math.sin(self.time * 15 + i) * 4
                pygame.draw.line(shadow_surf, color, (cx + 15, int(body_y - 14)),
                               (cx - 8 + scarf_wobble, int(body_y - 18)), 3)
                pygame.draw.line(shadow_surf, color, (cx - 8 + scarf_wobble, int(body_y - 18)),
                               (cx - 20 + scarf_wobble, int(body_y - 15)), 2)
            else:
                # === 달리는 자세 (왼쪽으로 이동) ===

                # 머리
                head_x = cx - 20
                head_y = cy - 12 + body_bounce
                pygame.draw.circle(shadow_surf, color, (head_x, int(head_y)), 9)

                # 몸통
                body_y = cy + body_bounce
                body_points = [
                    (cx - 12, int(body_y - 18)),
                    (cx - 22, int(body_y - 8)),
                    (cx - 5, int(body_y + 12)),
                    (cx + 5, int(body_y + 2)),
                ]
                pygame.draw.polygon(shadow_surf, color, body_points)

                # 앞팔 + 칼
                arm_start = (cx - 18, int(body_y - 5))
                arm_angle_rad = math.radians(180 + 30 - front_arm_swing)
                arm_end_x = arm_start[0] + math.cos(arm_angle_rad) * 22
                arm_end_y = arm_start[1] + math.sin(arm_angle_rad) * 22
                pygame.draw.line(shadow_surf, color, arm_start, (int(arm_end_x), int(arm_end_y)), 4)
                sword_angle_rad = arm_angle_rad - 0.3
                sword_end_x = arm_end_x + math.cos(sword_angle_rad) * 18
                sword_end_y = arm_end_y + math.sin(sword_angle_rad) * 18
                pygame.draw.line(shadow_surf, color, (int(arm_end_x), int(arm_end_y)),
                               (int(sword_end_x), int(sword_end_y)), 3)

                # 뒷팔
                back_arm_start = (cx - 5, int(body_y - 5))
                back_arm_angle_rad = math.radians(180 + 60 - back_arm_swing)
                back_arm_end_x = back_arm_start[0] + math.cos(back_arm_angle_rad) * 18
                back_arm_end_y = back_arm_start[1] + math.sin(back_arm_angle_rad) * 18
                pygame.draw.line(shadow_surf, color, back_arm_start,
                               (int(back_arm_end_x), int(back_arm_end_y)), 4)

                # 앞다리
                hip = (cx - 8, int(body_y + 10))
                front_leg_rad = math.radians(110 - front_leg_angle)
                knee_x = hip[0] + math.cos(front_leg_rad) * 22
                knee_y = hip[1] + math.sin(front_leg_rad) * 22
                pygame.draw.line(shadow_surf, color, hip, (int(knee_x), int(knee_y)), 5)
                foot_angle_rad = front_leg_rad + math.radians(-20 + front_leg_angle * 0.5)
                foot_x = knee_x + math.cos(foot_angle_rad) * 18
                foot_y = knee_y + math.sin(foot_angle_rad) * 18
                pygame.draw.line(shadow_surf, color, (int(knee_x), int(knee_y)),
                               (int(foot_x), int(foot_y)), 4)

                # 뒷다리
                back_hip = (cx, int(body_y + 10))
                back_leg_rad = math.radians(70 - back_leg_angle)
                back_knee_x = back_hip[0] + math.cos(back_leg_rad) * 22
                back_knee_y = back_hip[1] + math.sin(back_leg_rad) * 22
                pygame.draw.line(shadow_surf, color, back_hip, (int(back_knee_x), int(back_knee_y)), 5)
                back_foot_angle_rad = back_leg_rad + math.radians(30 + back_leg_angle * 0.5)
                back_foot_x = back_knee_x + math.cos(back_foot_angle_rad) * 18
                back_foot_y = back_knee_y + math.sin(back_foot_angle_rad) * 18
                pygame.draw.line(shadow_surf, color, (int(back_knee_x), int(back_knee_y)),
                               (int(back_foot_x), int(back_foot_y)), 4)

                # 스카프
                scarf_wobble = math.sin(self.time * 15 + i) * 4
                pygame.draw.line(shadow_surf, color, (cx - 15, int(body_y - 14)),
                               (cx + 8 - scarf_wobble, int(body_y - 18)), 3)
                pygame.draw.line(shadow_surf, color, (cx + 8 - scarf_wobble, int(body_y - 18)),
                               (cx + 20 - scarf_wobble, int(body_y - 15)), 2)

            overlay.blit(shadow_surf, (x - 50 + trail_offset, y - 40))

    def _draw_window_glow(self, overlay: pygame.Surface) -> None:
        """창문에서 나오는 은은한 빛."""
        all_windows = self.window_positions_left + self.window_positions_right + self.window_positions_top

        for i, (wx, wy, ww, wh) in enumerate(all_windows):
            if i >= len(self.window_states):
                break
            state = self.window_states[i]
            intensity = state["intensity"]

            # 상단 창문은 더 밝은 따뜻한 빛 (오동나무 저택)
            is_top_window = i >= 6
            if is_top_window:
                glow_alpha = int(40 * intensity)
                glow_color = (140, 110, 70, glow_alpha)  # 따뜻한 황색 빛
                spread_color = (120, 95, 60)
            else:
                glow_alpha = int(25 * intensity)
                glow_color = (60, 50, 40, glow_alpha)
                spread_color = (50, 40, 30)

            if glow_alpha > 0:
                glow_surf = pygame.Surface((ww, wh), pygame.SRCALPHA)
                pygame.draw.rect(glow_surf, glow_color, (0, 0, ww, wh))
                overlay.blit(glow_surf, (wx + 4, wy + 4))

                for r in range(3):
                    spread_alpha = max(0, glow_alpha - r * 8)
                    pygame.draw.rect(overlay, (*spread_color, spread_alpha),
                                   (wx - r * 3, wy - r * 3, ww + r * 6, wh + r * 6), 1)

    def _draw_lantern_glow(self, overlay: pygame.Surface) -> None:
        """등불 빛 효과."""
        for i, (lx, ly) in enumerate(self.lantern_positions):
            state = self.lantern_states[i]
            intensity = state["intensity"]

            for layer in range(3):
                radius = int(18 + layer * 10)
                alpha = int(18 * intensity - layer * 5)
                if alpha > 0:
                    glow_color = (
                        int(100 * intensity),
                        int(55 * intensity),
                        int(20 * intensity),
                        alpha
                    )
                    pygame.draw.circle(overlay, glow_color, (lx, ly), radius)

    def _draw_dust(self, overlay: pygame.Surface) -> None:
        """떠다니는 먼지 입자."""
        for dust in self.dust_particles:
            wobble = 0.3 * math.sin(self.time * 2 + dust["phase"])
            radius = max(1, int(dust["radius"] + wobble))
            color = (70, 65, 55, dust["alpha"])
            pygame.draw.circle(overlay, color, (int(dust["x"]), int(dust["y"])), radius)

    def _draw_stadium_pulse(self, overlay: pygame.Surface) -> None:
        """스타디움 펄스 효과."""
        pulse = 0.5 + 0.5 * math.sin(self.stadium_pulse_phase)
        center_x = self.width // 2
        center_y = self.stadium_line_y

        glow_alpha = int(15 + 10 * pulse)
        glow_color = (130, 50, 50)

        for i in range(2):
            line_alpha = max(0, glow_alpha - i * 6)
            pygame.draw.line(overlay, (*glow_color, line_alpha),
                           (60, center_y - i), (self.width - 60, center_y - i), 1)
            pygame.draw.line(overlay, (*glow_color, line_alpha),
                           (60, center_y + i), (self.width - 60, center_y + i), 1)

        for i in range(3):
            circle_alpha = max(0, glow_alpha - i * 4)
            pygame.draw.circle(overlay, (*glow_color, circle_alpha),
                             (center_x, center_y), self.stadium_circle_radius + i * 2, 1)
