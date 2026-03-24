"""
SmasherShieldPart — 스매셔 오각형 에너지 방패 파츠.
Visual: 홀로그래픽 에너지 실드 — 헥사 그리드 + 스캔라인 +
        회전 에너지 링 + 제너레이터 코어 + 에너지 파동 + 엣지 스파크
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


def _point_in_polygon(px, py, pts):
    """간단한 점-오각형 내부 판정 (ray casting)."""
    n = len(pts)
    inside = False
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if ((yi > py) != (yj > py)) and (px < (xj - xi) * (py - yi) / (yj - yi + 0.001) + xi):
            inside = not inside
        j = i
    return inside


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
        shield_r = max(9, int(1.8 * b))
        ss_size = shield_r * 2 + 6
        ss = pygame.Surface((ss_size, ss_size), pygame.SRCALPHA)
        scx, scy = ss_size // 2, ss_size // 2

        pulse = 0.6 + 0.4 * math.sin(phase * math.tau * 1.5)

        # 방패 경계 오각형 (클리핑 판정용)
        boundary_pts = _regular_polygon_points((scx, scy), shield_r * 0.92)

        # ── 1. 외곽 글로우 필드 ──
        outer_pts = [int_point(p) for p in
                     _regular_polygon_points((scx, scy), shield_r * 1.12)]
        outer_glow = pygame.Surface(ss.get_size(), pygame.SRCALPHA)
        pygame.draw.polygon(outer_glow,
                            (*palette["shield_glow"], int(12 * pulse)), outer_pts)
        ss.blit(outer_glow, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)

        # ── 2. 베이스 레이어 (6단 그라데이션) ──
        layers = (
            (1.05, 40, palette["shield_glow"]),
            (0.92, 55, palette["shield_glow"]),
            (0.78, 75, palette["shield_ring"]),
            (0.64, 95, palette["shield_ring"]),
            (0.50, 120, palette["shield_core"]),
            (0.36, 150, palette["shield_core"]),
        )
        for scale, alpha, color in layers:
            pts = [int_point(p) for p in
                   _regular_polygon_points((scx, scy), shield_r * scale)]
            pygame.draw.polygon(ss, (*color, min(255, int(alpha * pulse))), pts)

        # ── 3. 헥사곤 에너지 그리드 (미래적 패턴) ──
        hex_size = max(3, int(b * 0.32))
        hex_core_color = palette.get("hex_core", (82, 178, 248))
        for row in range(-3, 4):
            for col in range(-3, 4):
                hx = scx + col * int(hex_size * 1.7) + (row % 2) * int(hex_size * 0.85)
                hy = scy + row * int(hex_size * 1.5)
                # 오각형 내부만
                if not _point_in_polygon(hx, hy, boundary_pts):
                    continue
                dist = math.sqrt((hx - scx) ** 2 + (hy - scy) ** 2)
                dist_ratio = dist / (shield_r * 0.9)
                if dist_ratio > 1.0:
                    continue
                hex_pts = [int_point(p) for p in
                           _regular_polygon_points((hx, hy), hex_size, sides=6, rotation_deg=0)]
                # 중심에 가까울수록 밝게
                hex_alpha = int(30 * (1.0 - dist_ratio * 0.7) * pulse)
                if hex_alpha > 2:
                    pygame.draw.polygon(ss, (*hex_core_color, hex_alpha), hex_pts, 1)

        # ── 4. 홀로그래픽 스캔라인 (위에서 아래로 순환하는 수평선) ──
        scan_y = scy - shield_r + int((phase * 2.0 % 1.0) * shield_r * 2)
        for dy in range(-1, 2):
            ly = scan_y + dy * 2
            if scy - shield_r < ly < scy + shield_r:
                scan_alpha = 35 if dy == 0 else 15
                scan_surf = pygame.Surface((ss_size, 1), pygame.SRCALPHA)
                scan_surf.fill((*palette["shield_core"], int(scan_alpha * pulse)))
                ss.blit(scan_surf, (0, ly))

        # ── 5. 에너지 파동 (중심에서 바깥으로 퍼지는 링) ──
        wave_phase = (phase * 1.8) % 1.0
        wave_r = int(shield_r * 0.2 + shield_r * 0.7 * wave_phase)
        wave_alpha = int(50 * (1.0 - wave_phase))
        if wave_r > 3 and wave_alpha > 3:
            wave_pts = [int_point(p) for p in
                        _regular_polygon_points((scx, scy), wave_r)]
            pygame.draw.polygon(ss, (*palette["shield_core"], wave_alpha),
                                wave_pts, width=1)

        # ── 6. 회전 에너지 링 ──
        ring_r = int(shield_r * 0.58)
        ring_rot = phase * 360 * 0.25
        ring_pts = [int_point(p) for p in
                    _regular_polygon_points((scx, scy), ring_r,
                                           sides=5, rotation_deg=-90 + ring_rot)]
        pygame.draw.polygon(ss, (*palette["shield_core"], int(45 * pulse)),
                            ring_pts, width=1)

        # ── 7. 이중 외곽선 ──
        outline_pts = [int_point(p) for p in
                       _regular_polygon_points((scx, scy), shield_r * 1.02)]
        pygame.draw.polygon(ss, (*palette["shield_ring"], 160), outline_pts, width=2)
        inner_outline = [int_point(p) for p in
                         _regular_polygon_points((scx, scy), shield_r * 0.93)]
        pygame.draw.polygon(ss, (*palette["shield_ring"], 60), inner_outline, width=1)

        # ── 8. 제너레이터 코어 ──
        gen_r = max(3, int(b * 0.3))
        pygame.draw.circle(ss, (*palette["shield_ring"], 180),
                           (scx, scy), gen_r + 2)
        pygame.draw.circle(ss, (*palette["shield_core"], 230),
                           (scx, scy), gen_r)
        pygame.draw.circle(ss, (255, 255, 255, 180),
                           (scx - 1, scy - 1), max(1, gen_r - 2))
        # 코어 블룸
        core_glow_r = int(shield_r * 0.4)
        core_glow = pygame.Surface((core_glow_r * 2, core_glow_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(core_glow,
                           (*palette["shield_core"], int(20 * pulse)),
                           (core_glow_r, core_glow_r), core_glow_r)
        ss.blit(core_glow, (scx - core_glow_r, scy - core_glow_r),
                special_flags=pygame.BLEND_RGBA_ADD)

        # ── 9. 룬 라인 (꼭짓점→코어) ──
        rune_pts = [int_point(p) for p in
                    _regular_polygon_points((scx, scy), shield_r * 0.72)]
        for pt in rune_pts:
            pygame.draw.line(ss, (*palette["shield_core"], int(35 + 25 * pulse)),
                             pt, (scx, scy), 1)

        # ── 10. 하이라이트 오각형 ──
        hl_pts = [int_point(p) for p in
                  _regular_polygon_points((scx, scy), shield_r * 0.86)]
        pygame.draw.lines(ss, (*palette["shield_core"], 70), True, hl_pts, 1)

        # ── 11. 리벳 (꼭짓점) ──
        for pt in outline_pts:
            pygame.draw.circle(ss, (*palette["shield_glow"], 80),
                               (pt[0] + 1, pt[1] + 1), 3)
            pygame.draw.circle(ss, (*palette["shield_core"], 200), pt, 2)
            pygame.draw.circle(ss, (255, 255, 255, 140),
                               (pt[0], pt[1] - 1), 1)

        # ── 12. 엣지 스파크 (변을 따라 깜빡임) ──
        for i in range(len(outline_pts)):
            p1 = outline_pts[i]
            p2 = outline_pts[(i + 1) % len(outline_pts)]
            for t in (0.3, 0.5, 0.7):
                sp_x = int(p1[0] + (p2[0] - p1[0]) * t)
                sp_y = int(p1[1] + (p2[1] - p1[1]) * t)
                sp_val = math.sin(phase * math.tau * 4 + i * 1.3 + t * 3)
                if sp_val > 0.4:
                    sp_alpha = int(60 * (sp_val - 0.4) / 0.6)
                    pygame.draw.circle(ss, (*palette["shield_core"], sp_alpha),
                                       (sp_x, sp_y), 1)

        # ── 블릿 ──
        half = ss_size // 2
        pos = (wx - half + int(0.45 * b), wy - half - int(0.15 * b))
        surface.blit(ss, pos)
