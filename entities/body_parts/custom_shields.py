"""
커스텀 방패 파츠 — 파츠 스왑 시스템 데모용.

SLOT_SHIELD를 사용하므로 기존 오각형 방패와 교체 가능.
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_SHIELD, SLOT_SHIELD
from typing import Optional


class MirrorShieldPart(BodyPart):
    """거울 방패 — 원형 거울 + 빛 반사 이펙트.

    phase에 따라 빛 반사가 회전한다.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_SHIELD,
            draw_order=ORDER_SHIELD,
            joint_a="r_wrist",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        wx, wy = joint_a.world_int()

        shield_r = max(9, int(1.8 * b))
        shield_surf = pygame.Surface(
            (shield_r * 2 + 4, shield_r * 2 + 4), pygame.SRCALPHA,
        )
        scx, scy = shield_r + 2, shield_r + 2

        # ── 방패 프레임 (은색 금속) ──
        pygame.draw.circle(shield_surf, (140, 145, 160), (scx, scy), shield_r)
        pygame.draw.circle(shield_surf, (180, 185, 200), (scx, scy), shield_r - 2)

        # ── 거울면 (밝은 반사) ──
        mirror_r = shield_r - 4
        pygame.draw.circle(shield_surf, (210, 220, 240), (scx, scy), mirror_r)

        # 거울 그라데이션 (위쪽이 더 밝음)
        for i in range(mirror_r, 0, -2):
            ratio = i / mirror_r
            brightness = int(210 + 40 * ratio)
            pygame.draw.circle(
                shield_surf,
                (brightness, min(255, brightness + 5), min(255, brightness + 15), 30),
                (scx, scy - int(mirror_r * 0.15)),
                i,
            )

        # ── 빛 반사 효과 (회전하는 광택) ──
        reflect_angle = phase * math.tau * 1.5
        reflect_x = scx + int(math.cos(reflect_angle) * mirror_r * 0.4)
        reflect_y = scy + int(math.sin(reflect_angle) * mirror_r * 0.4)

        # 메인 반사점
        glare_r = max(3, int(b * 0.5))
        glare_surf = pygame.Surface((glare_r * 4, glare_r * 4), pygame.SRCALPHA)
        gcx, gcy = glare_r * 2, glare_r * 2
        pygame.draw.circle(glare_surf, (255, 255, 255, 200), (gcx, gcy), glare_r)
        pygame.draw.circle(glare_surf, (255, 255, 255, 255), (gcx, gcy), max(1, glare_r // 2))
        shield_surf.blit(
            glare_surf,
            (reflect_x - gcx, reflect_y - gcy),
            special_flags=pygame.BLEND_RGBA_ADD,
        )

        # 보조 반사점 (반대편, 작게)
        reflect_x2 = scx - int(math.cos(reflect_angle) * mirror_r * 0.3)
        reflect_y2 = scy - int(math.sin(reflect_angle) * mirror_r * 0.3)
        pygame.draw.circle(shield_surf, (255, 255, 255, 100), (reflect_x2, reflect_y2), 2)

        # ── 테두리 장식 ──
        pygame.draw.circle(shield_surf, (160, 165, 180), (scx, scy), shield_r, 2)
        # 테두리 리벳 (8개)
        for i in range(8):
            a = i * math.tau / 8
            rx = scx + int(math.cos(a) * (shield_r - 1))
            ry = scy + int(math.sin(a) * (shield_r - 1))
            pygame.draw.circle(shield_surf, (200, 200, 210), (rx, ry), 2)

        # ── 블릿 ──
        offset_x = int(0.45 * b)
        offset_y = -int(0.15 * b)
        blit_pos = (
            wx - scx + offset_x,
            wy - scy + offset_y,
        )
        surface.blit(shield_surf, blit_pos)
