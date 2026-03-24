"""
SmasherShieldPart — 스매셔 오각형 에너지 방패 파츠.
Visual Polish: 다중 레이어 + 에너지 필드 블룸 + 룬 패턴
"""

import math
import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton, int_point,
    ORDER_SHIELD, SLOT_SHIELD,
)
from typing import Optional


def _regular_polygon_points(center, radius, *, sides=5, rotation_deg=-90.0):
    rotation = math.radians(rotation_deg)
    return [
        (center[0] + radius * math.cos(rotation + i * math.tau / sides),
         center[1] + radius * math.sin(rotation + i * math.tau / sides))
        for i in range(sides)
    ]


class SmasherShieldPart(BodyPart):

    def __init__(self, block: int = 9):
        super().__init__(slot=SLOT_SHIELD, draw_order=ORDER_SHIELD,
                         joint_a="r_wrist", joint_b=None)
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        wx, wy = joint_a.world_int()
        shield_r = max(9, int(1.7 * b))
        ss = pygame.Surface((shield_r * 2 + 4, shield_r * 2 + 4), pygame.SRCALPHA)
        scx, scy = shield_r + 2, shield_r + 2

        pulse = 0.6 + 0.4 * math.sin(phase * math.tau * 1.5)

        # ── 외곽 블룸 (가장 큰 글로우) ──
        outer_glow = pygame.Surface(ss.get_size(), pygame.SRCALPHA)
        outer_pts = [int_point(p) for p in
                     _regular_polygon_points((scx, scy), shield_r * 1.2)]
        pygame.draw.polygon(outer_glow,
                           (*palette["shield_glow"], int(20 * pulse)), outer_pts)
        ss.blit(outer_glow, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)

        # ── 레이어드 오각형 (4단 그라데이션) ──
        for scale, alpha in ((1.05, 70), (0.85, 110), (0.65, 150), (0.45, 190)):
            pts = [int_point(p) for p in
                   _regular_polygon_points((scx, scy), shield_r * scale)]
            pygame.draw.polygon(ss, (*palette["shield_glow"], min(255, int(alpha * pulse))), pts)

        # ── 외곽선 (두꺼운 + 얇은 이중 테두리) ──
        outline_pts = [int_point(p) for p in
                       _regular_polygon_points((scx, scy), shield_r * 1.05)]
        pygame.draw.polygon(ss, (*palette["shield_ring"], 230), outline_pts, width=3)
        inner_outline = [int_point(p) for p in
                        _regular_polygon_points((scx, scy), shield_r * 0.95)]
        pygame.draw.polygon(ss, (*palette["shield_ring"], 100), inner_outline, width=1)

        # ── 코어 오각형 + 블룸 ──
        core_pts = [int_point(p) for p in
                    _regular_polygon_points((scx, scy), shield_r * 0.38)]
        core_alpha = int(200 + 55 * pulse)
        pygame.draw.polygon(ss, (*palette["shield_core"], min(255, core_alpha)), core_pts)

        # 코어 블룸
        core_glow_r = int(shield_r * 0.55)
        core_glow = pygame.Surface((core_glow_r * 2, core_glow_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(core_glow,
                          (*palette["shield_core"], int(35 * pulse)),
                          (core_glow_r, core_glow_r), core_glow_r)
        ss.blit(core_glow, (scx - core_glow_r, scy - core_glow_r),
                special_flags=pygame.BLEND_RGBA_ADD)

        # ── 룬 패턴 (꼭짓점→중심 라인) ──
        rune_pts = [int_point(p) for p in
                    _regular_polygon_points((scx, scy), shield_r * 0.75)]
        for pt in rune_pts:
            rune_alpha = int(60 + 40 * pulse)
            pygame.draw.line(ss, (*palette["shield_core"], rune_alpha),
                           pt, (scx, scy), 1)

        # ── 하이라이트 라인 ──
        hl_pts = [int_point(p) for p in
                  _regular_polygon_points((scx, scy), shield_r * 0.9)]
        pygame.draw.lines(ss, (*palette["shield_core"], 120), True, hl_pts, 1)

        # ── 리벳 (꼭짓점마다) ──
        for pt in outline_pts:
            pygame.draw.circle(ss, (*palette["shield_core"], 200), pt, 2)
            pygame.draw.circle(ss, (255, 255, 255, 150), pt, 1)

        # ── 블릿 ──
        pos = (wx - scx + int(0.45 * b), wy - scy - int(0.15 * b))
        surface.blit(ss, pos)
        surface.blit(ss, pos, special_flags=pygame.BLEND_ADD)
