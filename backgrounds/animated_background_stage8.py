"""Stage 8 전용 애니메이션 배경 - 닌자 저택.

닌자 컨셉 애니메이션: 수리검, 닌자 그림자, 연기, 창문 빛 효과.
"""

from __future__ import annotations

import math
import random
from typing import List, Tuple

import pygame

Color = Tuple[int, int, int]


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
        self.window_positions_top = [
            (90, 55, 100, 80),
            (width // 2 - 50, 55, 100, 80),
            (width - 190, 55, 100, 80),
        ]

        # 창문 빛 상태
        self.window_states: List[dict] = []
        for _ in range(9):
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
            if self.ninja_shadow_x > self.width + 150 or self.ninja_shadow_x < -150:
                self.ninja_shadow_active = False
                self.ninja_shadow_cooldown = random.uniform(10.0, 20.0)

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

        # 2. 창문 빛 효과
        self._draw_window_glow(overlay)

        # 3. 등불 빛 효과
        self._draw_lantern_glow(overlay)

        # 4. 벚꽃잎
        self._draw_petals(overlay)

        # 5. 먼지 입자
        self._draw_dust(overlay)

        # 6. 수리검
        self._draw_shurikens(overlay)

        # 7. 닌자 그림자
        if self.ninja_shadow_active:
            self._draw_ninja_shadow(overlay)

        # 8. 스타디움 펄스
        self._draw_stadium_pulse(overlay)

        surface.blit(overlay, (ox, oy))

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
        """스쳐 지나가는 닌자 그림자 - 대각선 점프 자세."""
        x = int(self.ninja_shadow_x)
        y = int(self.ninja_shadow_y)
        facing_right = self.ninja_shadow_speed > 0

        # 잔상 효과
        for i in range(5):
            trail_offset = i * (-20 if facing_right else 20)
            trail_alpha = max(0, 100 - i * 20)

            shadow_surf = pygame.Surface((90, 70), pygame.SRCALPHA)
            color = (10, 10, 15, trail_alpha)

            # 기준점
            cx, cy = 45, 35

            if facing_right:
                # === 대각선 점프 자세 (오른쪽으로 이동) ===

                # 머리 (앞아래로 향함)
                pygame.draw.circle(shadow_surf, color, (cx + 25, cy - 8), 9)

                # 몸통 (대각선으로 기울어짐 - 우하향)
                body_points = [
                    (cx + 18, cy - 15),  # 어깨 위
                    (cx + 30, cy - 5),   # 어깨 앞
                    (cx + 5, cy + 15),   # 엉덩이
                    (cx - 5, cy + 5),    # 등
                ]
                pygame.draw.polygon(shadow_surf, color, body_points)

                # 앞팔 (아래로 뻗음 - 칼 들고)
                pygame.draw.line(shadow_surf, color, (cx + 28, cy - 2), (cx + 40, cy + 15), 4)
                # 손
                pygame.draw.circle(shadow_surf, color, (cx + 40, cy + 15), 4)
                # 칼 (아래로 향함)
                pygame.draw.line(shadow_surf, color, (cx + 40, cy + 15), (cx + 50, cy + 30), 3)

                # 뒷팔 (위로 뻗음)
                pygame.draw.line(shadow_surf, color, (cx + 5, cy - 5), (cx - 15, cy - 20), 4)
                # 손
                pygame.draw.circle(shadow_surf, color, (cx - 15, cy - 20), 3)

                # 앞다리 (앞아래로 뻗음)
                pygame.draw.line(shadow_surf, color, (cx + 8, cy + 12), (cx + 30, cy + 35), 5)
                # 발
                pygame.draw.line(shadow_surf, color, (cx + 30, cy + 35), (cx + 38, cy + 38), 3)

                # 뒷다리 (뒤로 접힘)
                pygame.draw.line(shadow_surf, color, (cx, cy + 12), (cx - 15, cy + 5), 5)
                pygame.draw.line(shadow_surf, color, (cx - 15, cy + 5), (cx - 10, cy + 20), 4)

                # 스카프/복면 끈 (뒤로 펄럭)
                scarf_wobble = math.sin(self.time * 15 + i) * 3
                pygame.draw.line(shadow_surf, color, (cx + 18, cy - 10),
                               (cx - 5 + scarf_wobble, cy - 15), 3)
                pygame.draw.line(shadow_surf, color, (cx - 5 + scarf_wobble, cy - 15),
                               (cx - 15 + scarf_wobble, cy - 12), 2)
            else:
                # === 대각선 점프 자세 (왼쪽으로 이동) ===

                # 머리
                pygame.draw.circle(shadow_surf, color, (cx - 25, cy - 8), 9)

                # 몸통 (좌하향)
                body_points = [
                    (cx - 18, cy - 15),
                    (cx - 30, cy - 5),
                    (cx - 5, cy + 15),
                    (cx + 5, cy + 5),
                ]
                pygame.draw.polygon(shadow_surf, color, body_points)

                # 앞팔 + 칼
                pygame.draw.line(shadow_surf, color, (cx - 28, cy - 2), (cx - 40, cy + 15), 4)
                pygame.draw.circle(shadow_surf, color, (cx - 40, cy + 15), 4)
                pygame.draw.line(shadow_surf, color, (cx - 40, cy + 15), (cx - 50, cy + 30), 3)

                # 뒷팔
                pygame.draw.line(shadow_surf, color, (cx - 5, cy - 5), (cx + 15, cy - 20), 4)
                pygame.draw.circle(shadow_surf, color, (cx + 15, cy - 20), 3)

                # 앞다리
                pygame.draw.line(shadow_surf, color, (cx - 8, cy + 12), (cx - 30, cy + 35), 5)
                pygame.draw.line(shadow_surf, color, (cx - 30, cy + 35), (cx - 38, cy + 38), 3)

                # 뒷다리
                pygame.draw.line(shadow_surf, color, (cx, cy + 12), (cx + 15, cy + 5), 5)
                pygame.draw.line(shadow_surf, color, (cx + 15, cy + 5), (cx + 10, cy + 20), 4)

                # 스카프
                scarf_wobble = math.sin(self.time * 15 + i) * 3
                pygame.draw.line(shadow_surf, color, (cx - 18, cy - 10),
                               (cx + 5 - scarf_wobble, cy - 15), 3)
                pygame.draw.line(shadow_surf, color, (cx + 5 - scarf_wobble, cy - 15),
                               (cx + 15 - scarf_wobble, cy - 12), 2)

            overlay.blit(shadow_surf, (x - 45 + trail_offset, y - 35))

    def _draw_window_glow(self, overlay: pygame.Surface) -> None:
        """창문에서 나오는 은은한 빛."""
        all_windows = self.window_positions_left + self.window_positions_right + self.window_positions_top

        for i, (wx, wy, ww, wh) in enumerate(all_windows):
            state = self.window_states[i]
            intensity = state["intensity"]

            glow_alpha = int(25 * intensity)
            if glow_alpha > 0:
                glow_surf = pygame.Surface((ww, wh), pygame.SRCALPHA)
                pygame.draw.rect(glow_surf, (60, 50, 40, glow_alpha), (0, 0, ww, wh))
                overlay.blit(glow_surf, (wx + 4, wy + 4))

                for r in range(3):
                    spread_alpha = max(0, glow_alpha - r * 8)
                    pygame.draw.rect(overlay, (50, 40, 30, spread_alpha),
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
