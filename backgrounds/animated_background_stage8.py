"""Stage 8 전용 애니메이션 배경.

음습하고 어두운 일본풍 닌자 저택 분위기를 유지하면서
은은한 등불 깜빡임, 먼지 입자, 그림자 움직임을 추가하여
정적인 배경 위에 생동감을 더한다.
"""

from __future__ import annotations

import math
import random
from typing import List, Tuple

import pygame

Color = Tuple[int, int, int]


class AnimatedBackgroundStage8:
    """Stage 8 배경 위에 얹는 경량 애니메이션 오버레이."""

    def __init__(self, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.time = 0.0

        # 등불 위치 (정적인 배경과 동일 위치)
        self.lantern_positions: List[Tuple[int, int]] = [
            (35, 195),              # 왼쪽 상단
            (35, height - 205),     # 왼쪽 하단
            (width - 35, 195),      # 오른쪽 상단
            (width - 35, height - 205),  # 오른쪽 하단
        ]

        # 등불 상태 (개별 깜빡임 위상)
        self.lantern_states: List[dict] = []
        for i in range(len(self.lantern_positions)):
            self.lantern_states.append({
                "phase": random.uniform(0, math.tau),
                "intensity": random.uniform(0.7, 1.0),
                "flicker_speed": random.uniform(3.0, 5.0),
            })

        # 떠다니는 먼지 입자
        self.dust_particles: List[dict] = []
        for _ in range(30):
            self.dust_particles.append({
                "x": random.uniform(70, width - 70),
                "y": random.uniform(50, height - 50),
                "speed_x": random.uniform(-8.0, 8.0),
                "speed_y": random.uniform(-5.0, 5.0),
                "phase": random.uniform(0, math.tau),
                "radius": random.uniform(1.0, 3.0),
                "alpha": random.randint(15, 40),
            })

        # 그림자 패치 (느리게 움직이는 어두운 영역)
        self.shadow_patches: List[dict] = []
        for _ in range(8):
            self.shadow_patches.append({
                "x": random.uniform(100, width - 100),
                "y": random.uniform(100, height - 100),
                "base_x": 0,  # 초기화 후 설정
                "base_y": 0,
                "width": random.randint(60, 120),
                "height": random.randint(40, 80),
                "phase": random.uniform(0, math.tau),
                "move_speed": random.uniform(0.3, 0.8),
                "alpha": random.randint(20, 40),
            })
        for patch in self.shadow_patches:
            patch["base_x"] = patch["x"]
            patch["base_y"] = patch["y"]

        # 달빛 광선 효과
        self.moonbeam_phase = 0.0
        self.moonbeam_intensity = 0.7

        # 스타디움 라인 펄스 효과
        self.stadium_pulse_phase = 0.0
        self.stadium_line_y = height // 2
        self.stadium_circle_radius = 80
        self.stadium_color = (100, 40, 40)
        self.stadium_glow_color = (140, 50, 50)

        # 닌자 그림자 (가끔 스쳐 지나가는 효과)
        self.ninja_shadow_active = False
        self.ninja_shadow_x = -100
        self.ninja_shadow_speed = 0
        self.ninja_shadow_cooldown = random.uniform(15.0, 30.0)

    def update(self, elapsed_ms: int | float | None = None) -> None:
        """프레임마다 호출. elapsed_ms는 pygame clock 값(ms)"""
        if elapsed_ms is None:
            elapsed_ms = 16
        dt = (elapsed_ms or 0) / 1000.0
        self.time += dt

        # 등불 상태 업데이트
        for state in self.lantern_states:
            state["intensity"] = 0.6 + 0.4 * (0.5 + 0.5 * math.sin(
                self.time * state["flicker_speed"] + state["phase"]))
            # 가끔 깜빡임 (랜덤 플리커)
            if random.random() < 0.01:
                state["intensity"] *= random.uniform(0.3, 0.7)

        # 먼지 입자 업데이트
        for dust in self.dust_particles:
            # 부유하는 움직임
            dust["x"] += dust["speed_x"] * dt
            dust["y"] += dust["speed_y"] * dt + math.sin(self.time * 0.5 + dust["phase"]) * 0.3

            # 화면 경계 처리 (부드러운 래핑)
            if dust["x"] < 50:
                dust["x"] = self.width - 50
            elif dust["x"] > self.width - 50:
                dust["x"] = 50
            if dust["y"] < 30:
                dust["y"] = self.height - 30
            elif dust["y"] > self.height - 30:
                dust["y"] = 30

        # 그림자 패치 업데이트
        for patch in self.shadow_patches:
            patch["x"] = patch["base_x"] + math.sin(
                self.time * patch["move_speed"] + patch["phase"]) * 15
            patch["y"] = patch["base_y"] + math.cos(
                self.time * patch["move_speed"] * 0.7 + patch["phase"]) * 10

        # 달빛 효과 업데이트
        self.moonbeam_phase = self.time * 0.2
        self.moonbeam_intensity = 0.5 + 0.3 * math.sin(self.time * 0.15)

        # 스타디움 펄스 업데이트
        self.stadium_pulse_phase = self.time * 1.5

        # 닌자 그림자 업데이트
        self.ninja_shadow_cooldown -= dt
        if self.ninja_shadow_cooldown <= 0 and not self.ninja_shadow_active:
            self._trigger_ninja_shadow()

        if self.ninja_shadow_active:
            self.ninja_shadow_x += self.ninja_shadow_speed * dt
            if self.ninja_shadow_x > self.width + 100 or self.ninja_shadow_x < -200:
                self.ninja_shadow_active = False
                self.ninja_shadow_cooldown = random.uniform(20.0, 40.0)

    def _trigger_ninja_shadow(self) -> None:
        """닌자 그림자 효과 트리거"""
        self.ninja_shadow_active = True
        # 랜덤 방향
        if random.random() > 0.5:
            self.ninja_shadow_x = -150
            self.ninja_shadow_speed = random.uniform(400, 700)
        else:
            self.ninja_shadow_x = self.width + 150
            self.ninja_shadow_speed = -random.uniform(400, 700)

    def draw(self, surface: pygame.Surface, *, offset: Tuple[int, int] = (0, 0)) -> None:
        """애니메이션 레이어를 그린다."""
        ox, oy = offset
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

        # 1. 움직이는 그림자 패치
        self._draw_shadow_patches(overlay)

        # 2. 등불 빛 효과
        self._draw_lantern_glow(overlay)

        # 3. 달빛 효과
        self._draw_moonbeam(overlay)

        # 4. 먼지 입자
        self._draw_dust(overlay)

        # 5. 닌자 그림자 (지나가는 효과)
        if self.ninja_shadow_active:
            self._draw_ninja_shadow(overlay)

        # 6. 스타디움 라인 펄스 효과
        self._draw_stadium_pulse(overlay)

        surface.blit(overlay, (ox, oy))

    def _draw_shadow_patches(self, overlay: pygame.Surface) -> None:
        """움직이는 그림자 패치"""
        for patch in self.shadow_patches:
            shadow_surf = pygame.Surface((patch["width"], patch["height"]), pygame.SRCALPHA)
            # 타원형 그림자
            pygame.draw.ellipse(
                shadow_surf,
                (0, 0, 10, patch["alpha"]),
                (0, 0, patch["width"], patch["height"])
            )
            overlay.blit(shadow_surf, (int(patch["x"] - patch["width"] // 2),
                                       int(patch["y"] - patch["height"] // 2)))

    def _draw_lantern_glow(self, overlay: pygame.Surface) -> None:
        """등불 빛 효과 (깜빡이는 따뜻한 빛)"""
        for i, (lx, ly) in enumerate(self.lantern_positions):
            state = self.lantern_states[i]
            intensity = state["intensity"]

            # 여러 겹의 글로우
            base_color = (120, 60, 20)
            for layer in range(4):
                radius = int(25 + layer * 15)
                alpha = int(30 * intensity - layer * 6)
                if alpha > 0:
                    glow_color = (
                        min(255, int(base_color[0] * intensity)),
                        min(255, int(base_color[1] * intensity)),
                        min(255, int(base_color[2] * intensity)),
                        alpha
                    )
                    pygame.draw.circle(overlay, glow_color, (lx, ly), radius)

            # 밝은 중심부
            core_alpha = int(60 * intensity)
            core_color = (200, 120, 50, core_alpha)
            pygame.draw.circle(overlay, core_color, (lx, ly), 8)

    def _draw_moonbeam(self, overlay: pygame.Surface) -> None:
        """달빛 광선 효과"""
        # 오른쪽 위에서 들어오는 빛
        beam_alpha = int(12 * self.moonbeam_intensity)
        if beam_alpha <= 0:
            return

        # 빛 줄기 (시간에 따라 약간 흔들림)
        wobble = math.sin(self.moonbeam_phase) * 10
        start_x = self.width - 80 + wobble
        start_y = 30

        for i in range(20):
            points = [
                (start_x - i * 5, start_y),
                (start_x + 60 - i * 3, start_y),
                (start_x - 60 - i * 8, start_y + 350),
                (start_x - 120 - i * 8, start_y + 350)
            ]
            alpha = max(0, beam_alpha - i)
            pygame.draw.polygon(overlay, (80, 85, 100, alpha), points)

    def _draw_dust(self, overlay: pygame.Surface) -> None:
        """떠다니는 먼지 입자"""
        for dust in self.dust_particles:
            # 먼지 크기 변동
            wobble = 0.3 * math.sin(self.time * 2 + dust["phase"])
            radius = max(1, int(dust["radius"] + wobble))

            # 달빛에 비치는 먼지는 약간 밝게
            if dust["x"] > self.width * 0.6:
                color = (100, 95, 90, dust["alpha"] + 10)
            else:
                color = (70, 65, 60, dust["alpha"])

            pygame.draw.circle(overlay, color, (int(dust["x"]), int(dust["y"])), radius)

    def _draw_ninja_shadow(self, overlay: pygame.Surface) -> None:
        """스쳐 지나가는 닌자 그림자"""
        # 빠르게 지나가는 검은 실루엣
        shadow_height = 200
        shadow_width = 80
        shadow_y = self.height // 2 - shadow_height // 2

        # 잔상 효과 (여러 겹)
        for i in range(5):
            trail_offset = i * (-15 if self.ninja_shadow_speed > 0 else 15)
            trail_alpha = max(0, 60 - i * 15)

            shadow_surf = pygame.Surface((shadow_width, shadow_height), pygame.SRCALPHA)

            # 닌자 실루엣 (간단한 형태)
            # 머리
            pygame.draw.circle(shadow_surf, (0, 0, 0, trail_alpha), (shadow_width // 2, 30), 20)
            # 몸통
            pygame.draw.ellipse(shadow_surf, (0, 0, 0, trail_alpha),
                              (shadow_width // 2 - 15, 45, 30, 80))
            # 망토/옷자락 (동적)
            cape_wobble = math.sin(self.time * 15 + i) * 10
            points = [
                (shadow_width // 2, 60),
                (shadow_width // 2 - 30 + cape_wobble, 150),
                (shadow_width // 2, 130),
                (shadow_width // 2 + 30 - cape_wobble, 150)
            ]
            pygame.draw.polygon(shadow_surf, (0, 0, 0, trail_alpha // 2), points)

            overlay.blit(shadow_surf,
                        (int(self.ninja_shadow_x - shadow_width // 2 + trail_offset),
                         shadow_y))

    def _draw_stadium_pulse(self, overlay: pygame.Surface) -> None:
        """스타디움 라인 펄스 효과"""
        pulse = 0.5 + 0.5 * math.sin(self.stadium_pulse_phase)
        center_x = self.width // 2
        center_y = self.stadium_line_y

        # 글로우 효과 (맥동)
        glow_alpha = int(20 + 15 * pulse)

        # 중앙 라인 글로우
        for i in range(3):
            line_alpha = max(0, glow_alpha - i * 5)
            pygame.draw.line(
                overlay,
                (*self.stadium_glow_color, line_alpha),
                (0, center_y - i), (self.width, center_y - i),
                1
            )
            pygame.draw.line(
                overlay,
                (*self.stadium_glow_color, line_alpha),
                (0, center_y + i), (self.width, center_y + i),
                1
            )

        # 중앙 서클 글로우
        for i in range(4):
            circle_alpha = max(0, glow_alpha - i * 4)
            pygame.draw.circle(
                overlay,
                (*self.stadium_glow_color, circle_alpha),
                (center_x, center_y),
                self.stadium_circle_radius + i * 2,
                1
            )
