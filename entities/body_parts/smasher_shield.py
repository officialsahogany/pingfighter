"""
SmasherShieldPart — 스매셔 오각형 에너지 방패 파츠.
Visual Polish: 6단 그라데이션 + 헥사 에너지 필드 + 회전 에너지 링 +
               방패 제너레이터 코어 + 엣지 크래클 + 룬/리벳 디테일
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
        shield_r = max(9, int(1.8 * b))
        ss_size = shield_r * 2 + 6
        ss = pygame.Surface((ss_size, ss_size), pygame.SRCALPHA)
        scx, scy = ss_size // 2, ss_size // 2

        pulse = 0.6 + 0.4 * math.sin(phase * math.tau * 1.5)
        fast_pulse = 0.5 + 0.5 * math.sin(phase * math.tau * 3)

        # ── 1. 외곽 글로우 (큰 블룸) ──
        outer_glow = pygame.Surface(ss.get_size(), pygame.SRCALPHA)
        outer_pts = [int_point(p) for p in
                     _regular_polygon_points((scx, scy), shield_r * 1.15)]
        pygame.draw.polygon(outer_glow,
                            (*palette["shield_glow"], int(15 * pulse)), outer_pts)
        ss.blit(outer_glow, (0, 0), special_flags=pygame.BLEND_RGBA_ADD)

        # ── 2. 레이어드 오각형 (6단 그라데이션) ──
        layers = (
            (1.05, 50, palette["shield_glow"]),
            (0.92, 70, palette["shield_glow"]),
            (0.78, 95, palette["shield_ring"]),
            (0.64, 120, palette["shield_ring"]),
            (0.50, 150, palette["shield_core"]),
            (0.36, 180, palette["shield_core"]),
        )
        for scale, alpha, color in layers:
            pts = [int_point(p) for p in
                   _regular_polygon_points((scx, scy), shield_r * scale)]
            a = min(255, int(alpha * pulse))
            pygame.draw.polygon(ss, (*color, a), pts)

        # ── 3. 헥사곤 에너지 필드 패턴 (방패 내부) ──
        hex_size = max(3, int(b * 0.35))
        hex_base_color = palette.get("hex_base", (40, 50, 80))
        hex_core_color = palette.get("hex_core", (82, 178, 248))
        # 작은 헥사곤 그리드
        for row in range(-2, 3):
            for col in range(-2, 3):
                hx = scx + col * int(hex_size * 1.7) + (row % 2) * int(hex_size * 0.85)
                hy = scy + row * int(hex_size * 1.5)
                # 방패 범위 내인지 확인
                dist = math.sqrt((hx - scx) ** 2 + (hy - scy) ** 2)
                if dist > shield_r * 0.75:
                    continue
                # 헥사곤 점 생성
                hex_pts = [int_point(p) for p in
                           _regular_polygon_points((hx, hy), hex_size, sides=6, rotation_deg=0)]
                # 거리에 따른 알파 감쇄
                dist_ratio = dist / (shield_r * 0.75)
                hex_alpha = int(35 * (1.0 - dist_ratio) * pulse)
                if hex_alpha > 3:
                    pygame.draw.polygon(ss, (*hex_core_color, hex_alpha), hex_pts, 1)

        # ── 4. 이중 외곽선 (두꺼운 + 얇은 테두리) ──
        outline_pts = [int_point(p) for p in
                       _regular_polygon_points((scx, scy), shield_r * 1.02)]
        # 어두운 바깥 테두리
        pygame.draw.polygon(ss, (*palette["shield_ring"], 180), outline_pts, width=3)
        # 밝은 안쪽 테두리
        inner_outline = [int_point(p) for p in
                         _regular_polygon_points((scx, scy), shield_r * 0.93)]
        pygame.draw.polygon(ss, (*palette["shield_ring"], 80), inner_outline, width=1)

        # ── 5. 회전 에너지 링 (중앙부에서 천천히 회전) ──
        ring_r = int(shield_r * 0.6)
        ring_rot = phase * 360 * 0.3  # 느린 회전
        ring_pts = [int_point(p) for p in
                    _regular_polygon_points((scx, scy), ring_r,
                                           sides=5, rotation_deg=-90 + ring_rot)]
        pygame.draw.polygon(ss, (*palette["shield_core"], int(60 * pulse)),
                            ring_pts, width=1)

        # ── 6. 코어 오각형 (밝은 중심) ──
        core_pts = [int_point(p) for p in
                    _regular_polygon_points((scx, scy), shield_r * 0.35)]
        core_alpha = min(255, int(200 + 55 * pulse))
        pygame.draw.polygon(ss, (*palette["shield_core"], core_alpha), core_pts)

        # ── 7. 방패 제너레이터 (중심 장치) ──
        gen_r = max(3, int(b * 0.3))
        # 제너레이터 외곽
        pygame.draw.circle(ss, (*palette["shield_ring"], 200),
                           (scx, scy), gen_r + 1)
        # 제너레이터 코어
        pygame.draw.circle(ss, (*palette["shield_core"], 240),
                           (scx, scy), gen_r)
        # 코어 하이라이트 도트
        pygame.draw.circle(ss, (255, 255, 255, 200),
                           (scx - 1, scy - 1), max(1, gen_r - 2))

        # 코어 블룸
        core_glow_r = int(shield_r * 0.45)
        core_glow = pygame.Surface((core_glow_r * 2, core_glow_r * 2), pygame.SRCALPHA)
        pygame.draw.circle(core_glow,
                           (*palette["shield_core"], int(25 * pulse)),
                           (core_glow_r, core_glow_r), core_glow_r)
        ss.blit(core_glow, (scx - core_glow_r, scy - core_glow_r),
                special_flags=pygame.BLEND_RGBA_ADD)

        # ── 8. 룬 라인 (꼭짓점→중심) ──
        rune_pts = [int_point(p) for p in
                    _regular_polygon_points((scx, scy), shield_r * 0.75)]
        for pt in rune_pts:
            rune_alpha = int(45 + 30 * pulse)
            pygame.draw.line(ss, (*palette["shield_core"], rune_alpha),
                             pt, (scx, scy), 1)

        # ── 9. 하이라이트 라인 (밝은 오각형) ──
        hl_pts = [int_point(p) for p in
                  _regular_polygon_points((scx, scy), shield_r * 0.88)]
        pygame.draw.lines(ss, (*palette["shield_core"], 90), True, hl_pts, 1)

        # ── 10. 리벳 (꼭짓점 — 3단 디테일) ──
        for pt in outline_pts:
            # 리벳 그림자
            pygame.draw.circle(ss, (*palette["shield_glow"], 100),
                               (pt[0] + 1, pt[1] + 1), 3)
            # 리벳 베이스
            pygame.draw.circle(ss, (*palette["shield_core"], 220), pt, 3)
            # 리벳 하이라이트
            pygame.draw.circle(ss, (255, 255, 255, 160),
                               (pt[0] - 1, pt[1] - 1), 1)

        # ── 11. 엣지 에너지 크래클 (방패 변을 따라 깜빡이는 작은 스파크) ──
        for i in range(len(outline_pts)):
            p1 = outline_pts[i]
            p2 = outline_pts[(i + 1) % len(outline_pts)]
            # 변 중간 + 1/3, 2/3 지점에 미세 스파크
            for t in (0.33, 0.5, 0.67):
                sp_x = int(p1[0] + (p2[0] - p1[0]) * t)
                sp_y = int(p1[1] + (p2[1] - p1[1]) * t)
                # 위상에 따라 깜빡임 (각 변마다 다른 타이밍)
                sp_phase = math.sin(phase * math.tau * 4 + i * 1.2 + t * 3)
                if sp_phase > 0.3:
                    sp_alpha = int(80 * sp_phase)
                    pygame.draw.circle(ss, (*palette["shield_core"], sp_alpha),
                                       (sp_x, sp_y), 1)

        # ── 블릿 ──
        half = ss_size // 2
        pos = (wx - half + int(0.45 * b), wy - half - int(0.15 * b))
        surface.blit(ss, pos)
