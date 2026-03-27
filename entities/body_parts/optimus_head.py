"""
OptimusHeadPart — 옵티머스 헬멧 + 사이버 바이저 + 안테나 + 귀 센서 파츠.
원본: pingfighter.py _create_mecha_paddle_surface() 라인 29000~29031
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_HEAD, SLOT_HEAD
from typing import Optional


class OptimusHeadPart(BodyPart):

    def __init__(self):
        super().__init__(slot=SLOT_HEAD, draw_order=ORDER_HEAD,
                         joint_a="head", joint_b=None)

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        hx, hy = joint_a.world_int()

        # ── 헬멧 (고해상도 88x68) ──
        helmet_rect = pygame.Rect(hx - 44, hy - 16, 88, 68)
        pygame.draw.rect(surface, palette["helmet"], helmet_rect, border_radius=20)
        pygame.draw.rect(surface, palette["helmet_inner"],
                         helmet_rect.inflate(-20, -20), border_radius=16)

        # ── 바이저 ──
        visor_rect = helmet_rect.inflate(-16, -12)
        pygame.draw.rect(surface, palette["visor"], visor_rect, border_radius=16)
        pygame.draw.line(surface, palette["visor_highlight"],
                         visor_rect.midleft,
                         (visor_rect.centerx, visor_rect.top + 8), 4)
        pygame.draw.line(surface, palette["visor_highlight"],
                         (visor_rect.centerx, visor_rect.bottom - 8),
                         visor_rect.midright, 4)

        # 바이저 스캔라인 효과
        for scan_y in range(visor_rect.top + 6, visor_rect.bottom - 6, 8):
            scan_alpha = 40 + int(20 * math.sin(phase * math.tau + scan_y * 0.1))
            pygame.draw.line(surface, (*palette["visor_highlight"], scan_alpha),
                             (visor_rect.left + 8, scan_y),
                             (visor_rect.right - 8, scan_y), 1)

        # ── 안테나/센서 (헬멧 상단) ──
        pygame.draw.rect(surface, palette["grip"],
                         (hx - 6, helmet_rect.top - 12, 12, 16), border_radius=3)
        pygame.draw.circle(surface, palette["accent"], (hx, helmet_rect.top - 14), 5)
        pygame.draw.circle(surface, palette["visor_highlight"],
                           (hx, helmet_rect.top - 14), 3)
        # 안테나 발광
        antenna_glow = pygame.Surface((20, 20), pygame.SRCALPHA)
        pygame.draw.circle(antenna_glow, (*palette["accent"], 60), (10, 10), 10)
        surface.blit(antenna_glow, (hx - 10, helmet_rect.top - 24))

        # ── 귀 센서 (양쪽) ──
        for side in (-1, 1):
            ear_center = (helmet_rect.centerx + side * 40,
                          helmet_rect.centery + 4)
            pygame.draw.circle(surface, palette["helmet"], ear_center, 14)
            pygame.draw.circle(surface, palette["ear_inner"], ear_center, 10)
            # LED 링
            pygame.draw.circle(surface, palette["accent"], ear_center, 7, 2)
            pygame.draw.circle(surface, palette["visor_highlight"], ear_center, 4)
