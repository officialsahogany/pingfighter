"""반칙호루라기 패시브 아이템 효과 및 연출."""

from __future__ import annotations

import math
import os
import random
import sys
from typing import List, Tuple

import pygame


def resource_path(relative_path: str) -> str:
    """PyInstaller 번들/일반 실행 모두에서 사용할 수 있는 리소스 경로."""

    try:
        base_path = sys._MEIPASS  # type: ignore[attr-defined]
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)


class FoulWhistle:
    """반칙호루라기 패시브 아이템 상태 및 애니메이션."""

    def __init__(self) -> None:
        if not pygame.font.get_init():
            pygame.font.init()

        self.active = False
        self.negate_chance = 0.1

        self.animation_active = False
        self.animation_frame = 0
        self.animation_total_frames = 120  # 약 2초
        self.reset_trigger_frame = 70  # 1.2초 후 라운드 재시작
        self.reset_ready = False

        self._font = self._load_font(size=72)
        self._text_surface = self._font.render(" 무 효 ! ", True, (255, 240, 140))
        self._text_shadow = self._font.render(" 무 효 ! ", True, (80, 40, 0))

        self._overlay_surface: pygame.Surface | None = None
        self._pulse_cache: List[Tuple[int, int]] = []
        self._frames = self._create_referee_frames()

    # ------------------------------------------------------------------
    # 라이프사이클
    # ------------------------------------------------------------------
    def activate(self) -> None:
        self.active = True

    def deactivate(self) -> None:
        self.active = False
        self.animation_active = False
        self.animation_frame = 0
        self.reset_ready = False

    def try_trigger(self) -> bool:
        """라운드 패배 무효화를 시도한다."""

        if not self.active or self.animation_active:
            return False
        if random.random() > self.negate_chance:
            return False

        self.animation_active = True
        self.animation_frame = 0
        self.reset_ready = False
        return True

    # ------------------------------------------------------------------
    # 상태 업데이트 & 신호
    # ------------------------------------------------------------------
    def update(self) -> None:
        if not self.animation_active:
            return

        self.animation_frame += 1
        if not self.reset_ready and self.animation_frame >= self.reset_trigger_frame:
            self.reset_ready = True

        if self.animation_frame >= self.animation_total_frames:
            self.animation_active = False
            self.animation_frame = 0
            self.reset_ready = False

    def consume_reset_ready(self) -> bool:
        if self.reset_ready:
            self.reset_ready = False
            return True
        return False

    # ------------------------------------------------------------------
    # 렌더링
    # ------------------------------------------------------------------
    def draw(self, screen: pygame.Surface, width: int, height: int) -> None:
        if not self.animation_active:
            return

        progress = self.animation_frame / max(1, self.animation_total_frames)
        overlay_alpha = int(100 + 120 * progress)

        overlay = self._get_overlay_surface(width, height)
        overlay.fill((0, 0, 0, 0))
        overlay.fill((0, 0, 0, overlay_alpha))

        # 파동 테두리
        center = (width // 2, height // 2 - 40)
        pulse_radius = int(80 + 200 * progress)
        pulse_alpha = max(0, 180 - int(progress * 180))
        pygame.draw.circle(overlay, (255, 240, 140, pulse_alpha), center, pulse_radius, 6)

        # 추가 파동 (겹쳐서 더 과장)
        secondary_radius = int(40 + 120 * progress)
        secondary_alpha = max(0, 140 - int(progress * 160))
        pygame.draw.circle(overlay, (255, 200, 80, secondary_alpha), center, secondary_radius, 4)

        screen.blit(overlay, (0, 0))

        # 심판 애니메이션 프레임
        frame = self._frames[(self.animation_frame // 6) % len(self._frames)]
        frame_rect = frame.get_rect(center=(width // 2, height // 2 - 40))
        screen.blit(frame, frame_rect)

        # 텍스트 (살짝 튕김 효과)
        scale = 1.0 + 0.08 * math.sin(self.animation_frame * 0.3)
        text_surface = pygame.transform.rotozoom(self._text_surface, 0, scale)
        shadow_surface = pygame.transform.rotozoom(self._text_shadow, 0, scale)
        text_rect = text_surface.get_rect(center=(width // 2, height // 2 + 90))
        shadow_rect = shadow_surface.get_rect(center=(width // 2 + 4, height // 2 + 95))

        screen.blit(shadow_surface, shadow_rect)
        screen.blit(text_surface, text_rect)

    # ------------------------------------------------------------------
    # 내부 유틸리티
    # ------------------------------------------------------------------
    def _get_overlay_surface(self, width: int, height: int) -> pygame.Surface:
        if self._overlay_surface is None or self._overlay_surface.get_size() != (width, height):
            self._overlay_surface = pygame.Surface((width, height), pygame.SRCALPHA)
        return self._overlay_surface

    def _load_font(self, size: int) -> pygame.font.Font:
        candidates = [
            "NeoDunggeunmoPro.ttf",
            os.path.join("..", "NeoDunggeunmoPro.ttf"),
            "NeoDGM.ttf",
            os.path.join("..", "NeoDGM.ttf"),
            "NanumSquareB.ttf",
            os.path.join("..", "NanumSquareB.ttf"),
            None,
        ]
        for name in candidates:
            try:
                if name is None:
                    return pygame.font.Font(None, size)
                return pygame.font.Font(resource_path(name), size)
            except Exception:
                continue
        return pygame.font.Font(None, size)

    def _create_referee_frames(self) -> List[pygame.Surface]:
        frames: List[pygame.Surface] = []
        size = (200, 220)
        center_x = size[0] // 2
        base_y = size[1] - 40

        for idx in range(4):
            surface = pygame.Surface(size, pygame.SRCALPHA)

            # 몸통
            pygame.draw.rect(surface, (230, 230, 230), (center_x - 20, base_y - 100, 40, 80), border_radius=8)
            pygame.draw.rect(surface, (40, 40, 40), (center_x - 28, base_y - 104, 56, 16), border_radius=6)

            # 머리
            pygame.draw.circle(surface, (245, 213, 180), (center_x, base_y - 120), 28)
            pygame.draw.circle(surface, (40, 40, 40), (center_x - 8, base_y - 128), 4)
            pygame.draw.circle(surface, (40, 40, 40), (center_x + 8, base_y - 128), 4)

            # 호루라기 (간단하게)
            whistle_offset = 4 if idx % 2 == 0 else 0
            pygame.draw.rect(surface, (255, 230, 120), (center_x - 8, base_y - 110 + whistle_offset, 16, 10), border_radius=3)
            pygame.draw.circle(surface, (200, 160, 60), (center_x + 8, base_y - 105 + whistle_offset), 4)

            # 팔 모션(호루라기 부는 제스처)
            arm_angle = math.radians(30 + idx * 5)
            arm_length = 60
            end_x = int(center_x - math.cos(arm_angle) * arm_length)
            end_y = int(base_y - 70 - math.sin(arm_angle) * arm_length)
            pygame.draw.line(surface, (245, 213, 180), (center_x - 15, base_y - 70), (end_x, end_y), 10)
            pygame.draw.circle(surface, (245, 213, 180), (end_x, end_y), 10)

            # 카드(조그만 빨간 카드) 흔들기
            card_angle = -15 + idx * 5
            card = pygame.Surface((24, 34), pygame.SRCALPHA)
            pygame.draw.rect(card, (220, 60, 60), (0, 0, 24, 34), border_radius=4)
            card_rot = pygame.transform.rotate(card, card_angle)
            card_pos = card_rot.get_rect(center=(end_x, end_y - 10))
            surface.blit(card_rot, card_pos)

            # 빛 효과
            pulse_alpha = 120 - idx * 15
            pygame.draw.circle(surface, (255, 240, 160, max(40, pulse_alpha)), (center_x, base_y - 120), 46, 6)

            frames.append(surface)

        return frames


_foul_whistle_instance: FoulWhistle | None = None


def get_foul_whistle_instance() -> FoulWhistle:
    global _foul_whistle_instance
    if _foul_whistle_instance is None:
        _foul_whistle_instance = FoulWhistle()
    return _foul_whistle_instance
