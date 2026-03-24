"""
패시브 아이템 연동 무기 파츠 — 라그나로크 해머.
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_WEAPON, SLOT_WEAPON
from typing import Optional


class RagnarokHammerPart(BodyPart):
    """라그나로크 해머 (ragnarok_hammer).

    전설 무기: 거대한 붉은 해머 + 룬 문양 + 에너지 아우라.
    효과: 확률적으로 번개 타격.
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

        # ── 자루 (다크 브라운, 긴 핸들) ──
        handle_w = max(3, int(0.5 * b))
        handle_h = int(2.0 * b)
        handle_rect = pygame.Rect(
            wx - handle_w // 2,
            wy - int(1.5 * b),
            handle_w, handle_h,
        )
        pygame.draw.rect(surface, (80, 50, 30), handle_rect, border_radius=1)
        pygame.draw.rect(surface, (100, 65, 40), handle_rect.inflate(-2, -2), border_radius=1)
        # 그립 밴딩
        for gy in range(handle_rect.top + 2, handle_rect.bottom - 2, 3):
            pygame.draw.line(
                surface, (70, 45, 25),
                (handle_rect.left + 1, gy),
                (handle_rect.right - 1, gy), 1,
            )

        # ── 해머 헤드 (큰 직사각형) ──
        head_w = int(2.4 * b)
        head_h = int(1.4 * b)
        head_cx = handle_rect.centerx - int(0.8 * b)
        head_cy = handle_rect.top - int(0.2 * b)
        head_rect = pygame.Rect(
            head_cx - head_w // 2,
            head_cy - head_h // 2,
            head_w, head_h,
        )

        # 해머 그림자
        shadow = head_rect.move(2, 2)
        pygame.draw.rect(surface, (40, 20, 20), shadow, border_radius=3)

        # 해머 본체 (진홍-회색)
        pygame.draw.rect(surface, (120, 40, 35), head_rect, border_radius=3)
        pygame.draw.rect(surface, (150, 55, 45), head_rect.inflate(-3, -3), border_radius=2)

        # ── 룬 문양 (중앙 십자) ──
        pulse = int(30 * math.sin(phase * math.tau * 2))
        rune_color = (min(255, 220 + pulse), min(255, 160 + pulse), 60)
        rcx, rcy = head_rect.centerx, head_rect.centery
        # 세로
        pygame.draw.line(surface, rune_color, (rcx, head_rect.top + 3), (rcx, head_rect.bottom - 3), 2)
        # 가로
        pygame.draw.line(surface, rune_color, (head_rect.left + 3, rcy), (head_rect.right - 3, rcy), 2)
        # 대각선
        pygame.draw.line(surface, rune_color, (head_rect.left + 5, head_rect.top + 5), (head_rect.right - 5, head_rect.bottom - 5), 1)
        pygame.draw.line(surface, rune_color, (head_rect.right - 5, head_rect.top + 5), (head_rect.left + 5, head_rect.bottom - 5), 1)

        # ── 에너지 아우라 (해머 주위 글로우) ──
        aura_surf = pygame.Surface((head_w + b * 2, head_h + b * 2), pygame.SRCALPHA)
        acx, acy = aura_surf.get_width() // 2, aura_surf.get_height() // 2
        aura_alpha = int(50 + 30 * math.sin(phase * math.tau * 3))
        pygame.draw.ellipse(
            aura_surf,
            (255, 100, 60, aura_alpha),
            (0, 0, aura_surf.get_width(), aura_surf.get_height()),
        )
        surface.blit(
            aura_surf,
            (head_rect.centerx - acx, head_rect.centery - acy),
            special_flags=pygame.BLEND_RGBA_ADD,
        )

        # 테두리
        pygame.draw.rect(surface, (100, 30, 25), head_rect, 1, border_radius=3)
