"""
커스텀 무기 파츠 — 파츠 스왑 시스템 데모용.

SLOT_WEAPON을 사용하므로 기존 탁구채와 교체 가능.
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_WEAPON, SLOT_WEAPON
from typing import Optional


class FlameRacketPart(BodyPart):
    """화염 라켓.

    검은 핸들 + 붉은 라켓면 + 화염 이펙트.
    phase에 따라 화염이 흔들린다.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_WEAPON,
            draw_order=ORDER_WEAPON,
            joint_a="l_wrist",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        wx, wy = joint_a.world_int()

        # ── 핸들 (다크 레드) ──
        handle_rect = pygame.Rect(
            wx - b // 2,
            wy - int(1.3 * b),
            int(0.9 * b), int(1.6 * b),
        )
        pygame.draw.rect(surface, (60, 20, 20), handle_rect)
        pygame.draw.rect(surface, (100, 30, 30), handle_rect.inflate(-2, -2))
        # 그립 밴딩
        for gy in range(handle_rect.top + 3, handle_rect.bottom - 3, 4):
            pygame.draw.line(
                surface, (80, 25, 25),
                (handle_rect.left + 1, gy),
                (handle_rect.right - 1, gy), 1,
            )

        # ── 라켓면 (진홍색 원형) ──
        paddle_cx = handle_rect.centerx - int(1.2 * b)
        paddle_cy = handle_rect.top - int(0.4 * b)
        paddle_r = int(1.7 * b)

        pygame.draw.circle(surface, (160, 30, 20), (paddle_cx, paddle_cy), paddle_r)
        pygame.draw.circle(surface, (200, 50, 30), (paddle_cx, paddle_cy), paddle_r - 2)

        # 라켓면 열 무늬 (크로스해치)
        inner_r = paddle_r - 4
        for i in range(-inner_r, inner_r + 1, 5):
            # Y 범위 안에서만 선 그리기
            half_w = int(math.sqrt(max(0, inner_r ** 2 - i ** 2)))
            if half_w > 2:
                y = paddle_cy + i
                pygame.draw.line(
                    surface, (220, 80, 40, 100),
                    (paddle_cx - half_w, y),
                    (paddle_cx + half_w, y), 1,
                )

        # ── 화염 이펙트 (라켓면 주위) ──
        flame_surf = pygame.Surface((paddle_r * 3, paddle_r * 3), pygame.SRCALPHA)
        fcx, fcy = flame_surf.get_width() // 2, flame_surf.get_height() // 2

        num_flames = 6
        for i in range(num_flames):
            angle = (i / num_flames) * math.tau + phase * math.tau * 2
            flicker = 0.7 + 0.3 * math.sin(phase * math.tau * 4 + i * 1.3)

            fx = fcx + int(math.cos(angle) * paddle_r * 0.9)
            fy = fcy + int(math.sin(angle) * paddle_r * 0.9)
            flame_size = int(b * 0.6 * flicker)

            # 외곽 (주황)
            if flame_size > 1:
                pygame.draw.circle(flame_surf, (255, 120, 30, 120), (fx, fy), flame_size)
            # 내곽 (노랑)
            inner_size = max(1, flame_size - 2)
            pygame.draw.circle(flame_surf, (255, 220, 80, 160), (fx, fy), inner_size)

        surface.blit(
            flame_surf,
            (paddle_cx - fcx, paddle_cy - fcy),
            special_flags=pygame.BLEND_RGBA_ADD,
        )

        # ── 라켓 중심 코어 (불씨) ──
        core_pulse = int(40 * math.sin(phase * math.tau * 3))
        pygame.draw.circle(
            surface,
            (255, min(255, 180 + core_pulse), 60),
            (paddle_cx, paddle_cy), max(2, b // 2),
        )
        pygame.draw.circle(
            surface, (255, 255, 200),
            (paddle_cx, paddle_cy), max(1, b // 4),
        )
