"""
패시브 아이템 연동 몸통 파츠 — 테크니컬조끼, 벌크업슈트.
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_TORSO, SLOT_TORSO
from typing import Optional


class TechnicalVestPart(BodyPart):
    """테크니컬조끼 (technical_vest).

    스틸블루 전술 조끼 + 탄창 포켓 + MOLLE 웨빙.
    효과: 아이템 드랍률 증가.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_TORSO,
            draw_order=ORDER_TORSO,
            joint_a="torso",
            joint_b="hip",
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, ty = joint_a.world_int()

        # ── 조끼 본체 ──
        vest_w = int(3.6 * b)
        vest_h = int(2.4 * b)
        vest_rect = pygame.Rect(cx - vest_w // 2, ty - int(0.5 * b), vest_w, vest_h)
        pygame.draw.rect(surface, (55, 100, 140), vest_rect, border_radius=5)
        # 내부
        inner = vest_rect.inflate(-int(0.4 * b), -int(0.4 * b))
        pygame.draw.rect(surface, (70, 120, 160), inner, border_radius=4)

        # ── MOLLE 웨빙 (가로줄 패턴) ──
        for wy in range(inner.top + 3, inner.bottom - 3, 4):
            pygame.draw.line(
                surface, (50, 90, 130),
                (inner.left + 2, wy), (inner.right - 2, wy), 1,
            )

        # ── 탄창 포켓 (좌/우 2개씩) ──
        pocket_w = int(0.6 * b)
        pocket_h = int(0.9 * b)
        pocket_color = (45, 85, 120)
        pocket_highlight = (65, 110, 150)
        for px_off, py_off in [(-int(1.2 * b), int(0.2 * b)),
                                (-int(0.5 * b), int(0.2 * b)),
                                (int(0.5 * b), int(0.2 * b)),
                                (int(1.2 * b), int(0.2 * b))]:
            pr = pygame.Rect(
                cx + px_off - pocket_w // 2,
                ty + py_off,
                pocket_w, pocket_h,
            )
            pygame.draw.rect(surface, pocket_color, pr, border_radius=1)
            # 포켓 플랩
            flap = pygame.Rect(pr.left, pr.top, pr.width, max(2, int(0.2 * b)))
            pygame.draw.rect(surface, pocket_highlight, flap, border_radius=1)

        # ── 중앙 지퍼 ──
        pygame.draw.line(
            surface, (80, 130, 170),
            (cx, vest_rect.top + 3), (cx, vest_rect.bottom - 3), 1,
        )

        # ── 어깨 스트랩 ──
        for side in [-1, 1]:
            sx = cx + side * int(1.5 * b)
            pygame.draw.line(
                surface, (50, 90, 130),
                (sx, ty - int(0.5 * b)),
                (sx + side * int(0.3 * b), ty - int(1.0 * b)), 3,
            )

        # ── 벨트 ──
        belt_rect = pygame.Rect(
            cx - int(2.0 * b), vest_rect.bottom - int(0.2 * b),
            int(4.0 * b), int(0.7 * b),
        )
        pygame.draw.rect(surface, (40, 70, 100), belt_rect, border_radius=2)
        # 버클
        buckle = pygame.Rect(cx - int(0.5 * b), belt_rect.top + 1, int(1.0 * b), belt_rect.height - 2)
        pygame.draw.rect(surface, (80, 130, 170), buckle, border_radius=1)

        # 테두리
        pygame.draw.rect(surface, (40, 80, 120), vest_rect, 1, border_radius=5)


class BulkupSuitPart(BodyPart):
    """벌크업슈트 (bulkup).

    근육 강화 파워 슈트 + 에너지 라인 + 팽창된 실루엣.
    효과: 패들 사이즈 증가.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_TORSO,
            draw_order=ORDER_TORSO,
            joint_a="torso",
            joint_b="hip",
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, ty = joint_a.world_int()

        # ── 슈트 본체 (넓고 두꺼움) ──
        suit_w = int(4.0 * b)   # 기본 torso보다 넓음
        suit_h = int(2.6 * b)
        suit_rect = pygame.Rect(cx - suit_w // 2, ty - int(0.5 * b), suit_w, suit_h)

        # 베이스 (짙은 보라-회색)
        pygame.draw.rect(surface, (50, 40, 65), suit_rect, border_radius=8)
        # 근육 패널 (양쪽)
        for side in [-1, 1]:
            muscle_x = cx + side * int(0.8 * b)
            muscle_rect = pygame.Rect(
                muscle_x - int(0.7 * b), ty - int(0.2 * b),
                int(1.4 * b), int(1.8 * b),
            )
            pygame.draw.rect(surface, (65, 55, 80), muscle_rect, border_radius=5)
            pygame.draw.rect(surface, (80, 70, 95), muscle_rect.inflate(-3, -3), border_radius=4)

        # ── 에너지 라인 (phase 기반 맥동) ──
        pulse = int(30 * math.sin(phase * math.tau * 2))
        energy_color = (min(255, 120 + pulse), 80, min(255, 200 + pulse))

        # 중앙 세로선
        pygame.draw.line(
            surface, energy_color,
            (cx, suit_rect.top + 4), (cx, suit_rect.bottom - 4), 2,
        )
        # 가로 분절선 3개
        for ey_off in [-int(0.5 * b), 0, int(0.5 * b)]:
            ey = ty + int(0.5 * b) + ey_off
            pygame.draw.line(
                surface, energy_color,
                (cx - int(0.6 * b), ey), (cx + int(0.6 * b), ey), 1,
            )

        # ── 어깨패드 (넓고 각진) ──
        pad_w = int(1.4 * b)
        pad_h = int(0.8 * b)
        for side in [-1, 1]:
            pad_x = cx + side * int(1.6 * b) - (pad_w // 2 if side > 0 else -pad_w // 2 + pad_w)
            pad_rect = pygame.Rect(
                cx + side * int(1.6 * b) - pad_w // 2,
                ty - int(0.8 * b),
                pad_w, pad_h,
            )
            pygame.draw.rect(surface, (60, 50, 75), pad_rect, border_radius=3)
            # 어깨 에너지 포인트
            pygame.draw.circle(
                surface, energy_color,
                (pad_rect.centerx, pad_rect.centery), max(2, int(0.2 * b)),
            )

        # ── 복부 패널 ──
        abs_rect = pygame.Rect(
            cx - int(1.2 * b), suit_rect.bottom - int(0.8 * b),
            int(2.4 * b), int(0.7 * b),
        )
        pygame.draw.rect(surface, (40, 35, 55), abs_rect, border_radius=3)

        # ── 벨트 (두꺼움) ──
        belt_rect = pygame.Rect(
            cx - int(2.1 * b), suit_rect.bottom - int(0.1 * b),
            int(4.2 * b), int(0.9 * b),
        )
        pygame.draw.rect(surface, (55, 45, 70), belt_rect, border_radius=2)
        # 파워 버클
        buckle_r = max(3, int(0.35 * b))
        pygame.draw.circle(surface, (70, 60, 85), (cx, belt_rect.centery), buckle_r + 1)
        pygame.draw.circle(surface, energy_color, (cx, belt_rect.centery), buckle_r)

        # 외곽선
        pygame.draw.rect(surface, (35, 30, 50), suit_rect, 1, border_radius=8)


class AdversityArmorPart(BodyPart):
    """역경의 갑옷 (adversity_armor).

    어두운 보라색 갑옷 + 황금 십자 문양 + 보석 + 숄더 가드.
    효과: 실점 후 확률적 무적 발동.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_TORSO,
            draw_order=ORDER_TORSO,
            joint_a="torso",
            joint_b="hip",
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, ty = joint_a.world_int()

        # ── 갑옷 본체 (짙은 보라) ──
        armor_w = int(3.8 * b)
        armor_h = int(2.5 * b)
        armor_rect = pygame.Rect(cx - armor_w // 2, ty - int(0.5 * b), armor_w, armor_h)

        # 베이스 어두운 보라
        pygame.draw.rect(surface, (40, 25, 70), armor_rect, border_radius=6)
        # 내부 패널
        inner = armor_rect.inflate(-int(0.3 * b), -int(0.3 * b))
        pygame.draw.rect(surface, (55, 35, 90), inner, border_radius=5)

        # ── 가슴 패널 (중앙, 약간 밝은 보라) ──
        chest_w = int(2.0 * b)
        chest_h = int(1.6 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2, ty - int(0.2 * b), chest_w, chest_h)
        pygame.draw.rect(surface, (65, 45, 105), chest_rect, border_radius=4)

        # ── 황금 십자 문양 ──
        cross_color = (255, 200, 50)
        cross_cx = cx
        cross_cy = ty + int(0.5 * b)
        # 세로
        pygame.draw.line(surface, cross_color,
                         (cross_cx, cross_cy - int(0.5 * b)),
                         (cross_cx, cross_cy + int(0.5 * b)), 2)
        # 가로
        pygame.draw.line(surface, cross_color,
                         (cross_cx - int(0.4 * b), cross_cy),
                         (cross_cx + int(0.4 * b), cross_cy), 2)

        # ── 중앙 보석 (황금, 맥동) ──
        pulse = int(25 * math.sin(phase * math.tau * 2))
        gem_color = (255, min(255, 210 + pulse), min(255, 80 + pulse))
        gem_r = max(3, int(0.3 * b))
        pygame.draw.circle(surface, gem_color, (cross_cx, cross_cy), gem_r)
        # 보석 하이라이트
        pygame.draw.circle(surface, (255, 255, 200),
                           (cross_cx - 1, cross_cy - 1), max(1, gem_r // 2))

        # ── 어깨 가드 (각진 숄더패드) ──
        guard_w = int(1.2 * b)
        guard_h = int(0.7 * b)
        for side in [-1, 1]:
            guard_rect = pygame.Rect(
                cx + side * int(1.6 * b) - guard_w // 2,
                ty - int(0.8 * b),
                guard_w, guard_h,
            )
            pygame.draw.rect(surface, (50, 30, 80), guard_rect, border_radius=2)
            # 가드 테두리
            pygame.draw.rect(surface, (90, 60, 140), guard_rect, 1, border_radius=2)
            # 가드 위 장식 (작은 뾰족이)
            spike_x = guard_rect.centerx
            spike_top = guard_rect.top - int(0.25 * b)
            pygame.draw.polygon(surface, (70, 45, 110), [
                (spike_x - int(0.2 * b), guard_rect.top),
                (spike_x, spike_top),
                (spike_x + int(0.2 * b), guard_rect.top),
            ])

        # ── 복부 장갑 (쉐브런 패턴) ──
        abs_top = chest_rect.bottom + 1
        for i in range(3):
            vy = abs_top + i * int(0.25 * b)
            half_w = int((1.0 - i * 0.15) * b)
            pygame.draw.line(surface, (80, 55, 120),
                             (cx - half_w, vy), (cx + half_w, vy), 1)

        # ── 벨트 (황금 버클) ──
        belt_rect = pygame.Rect(
            cx - int(2.0 * b), armor_rect.bottom - int(0.2 * b),
            int(4.0 * b), int(0.7 * b),
        )
        pygame.draw.rect(surface, (35, 20, 60), belt_rect, border_radius=2)
        # 황금 버클
        buckle_w = int(0.8 * b)
        buckle_h = belt_rect.height - 2
        buckle_rect = pygame.Rect(cx - buckle_w // 2, belt_rect.top + 1, buckle_w, buckle_h)
        pygame.draw.rect(surface, cross_color, buckle_rect, border_radius=1)
        # 버클 내부 보석
        pygame.draw.circle(surface, gem_color, (cx, belt_rect.centery), max(2, int(0.15 * b)))

        # ── 외곽선 ──
        pygame.draw.rect(surface, (30, 18, 55), armor_rect, 1, border_radius=6)


class ShrapnelArmorPart(BodyPart):
    """파편갑옷 (shrapnel_armor).

    갈색/금속 갑옷 + 방사형 파편 문양 + 오렌지 보석.
    효과: 공을 칠 때 확률적 파편 발사 → 보스 넉백.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_TORSO,
            draw_order=ORDER_TORSO,
            joint_a="torso",
            joint_b="hip",
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, ty = joint_a.world_int()

        # ── 갑옷 본체 (짙은 갈색/철색) ──
        armor_w = int(3.8 * b)
        armor_h = int(2.5 * b)
        armor_rect = pygame.Rect(cx - armor_w // 2, ty - int(0.5 * b), armor_w, armor_h)

        # 베이스 갈색
        pygame.draw.rect(surface, (100, 70, 45), armor_rect, border_radius=6)
        # 내부 패널 (어두운 갈색)
        inner = armor_rect.inflate(-int(0.3 * b), -int(0.3 * b))
        pygame.draw.rect(surface, (75, 50, 30), inner, border_radius=5)

        # ── 가슴 패널 (중앙, 약간 밝은 갈색) ──
        chest_w = int(2.0 * b)
        chest_h = int(1.6 * b)
        chest_rect = pygame.Rect(cx - chest_w // 2, ty - int(0.2 * b), chest_w, chest_h)
        pygame.draw.rect(surface, (90, 60, 38), chest_rect, border_radius=4)

        # ── 방사형 파편 문양 ──
        frag_color = (200, 150, 70)
        frag_cx = cx
        frag_cy = ty + int(0.5 * b)
        for i in range(5):
            angle = math.radians(-90 + 72 * i + phase * 360 * 0.3)
            inner_r = int(0.2 * b)
            outer_r = int(0.65 * b)
            fx1 = frag_cx + int(math.cos(angle) * inner_r)
            fy1 = frag_cy + int(math.sin(angle) * inner_r)
            fx2 = frag_cx + int(math.cos(angle) * outer_r)
            fy2 = frag_cy + int(math.sin(angle) * outer_r)
            pygame.draw.line(surface, frag_color, (fx1, fy1), (fx2, fy2), 2)

        # ── 중앙 보석 (오렌지, 맥동) ──
        pulse = int(20 * math.sin(phase * math.tau * 2))
        gem_color = (255, max(0, min(255, 120 + pulse)), max(0, min(255, 40 + pulse)))
        gem_r = max(3, int(0.3 * b))
        pygame.draw.circle(surface, gem_color, (frag_cx, frag_cy), gem_r)
        pygame.draw.circle(surface, (255, 200, 120), (frag_cx - 1, frag_cy - 1), max(1, gem_r // 2))

        # ── 어깨 가드 ──
        guard_w = int(1.2 * b)
        guard_h = int(0.7 * b)
        for side in [-1, 1]:
            guard_rect = pygame.Rect(
                cx + side * int(1.6 * b) - guard_w // 2,
                ty - int(0.8 * b),
                guard_w, guard_h,
            )
            pygame.draw.rect(surface, (85, 60, 38), guard_rect, border_radius=2)
            pygame.draw.rect(surface, (130, 95, 60), guard_rect, 1, border_radius=2)
            # 가드 위 뾰족한 파편 장식
            spike_x = guard_rect.centerx
            spike_top = guard_rect.top - int(0.25 * b)
            pygame.draw.polygon(surface, (160, 110, 60), [
                (spike_x - int(0.2 * b), guard_rect.top),
                (spike_x, spike_top),
                (spike_x + int(0.2 * b), guard_rect.top),
            ])

        # ── 벨트 (금속 버클) ──
        belt_rect = pygame.Rect(
            cx - int(2.0 * b), armor_rect.bottom - int(0.2 * b),
            int(4.0 * b), int(0.7 * b),
        )
        pygame.draw.rect(surface, (60, 40, 25), belt_rect, border_radius=2)
        buckle_w = int(0.8 * b)
        buckle_h = belt_rect.height - 2
        buckle_rect = pygame.Rect(cx - buckle_w // 2, belt_rect.top + 1, buckle_w, buckle_h)
        pygame.draw.rect(surface, (180, 130, 60), buckle_rect, border_radius=1)

        # ── 외곽선 ──
        pygame.draw.rect(surface, (60, 40, 25), armor_rect, 1, border_radius=6)


class ValhallaWarplatePart(BodyPart):
    """발할라의 전갑 (valhalla_warplate).

    은빛 강철 갑옷 + 금빛 날개 문양 + 룬 각인.
    효과: 공 타격 시 영웅 소환.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_TORSO,
            draw_order=ORDER_TORSO,
            joint_a="torso",
            joint_b="hip",
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, ty = joint_a.world_int()

        # ── 갑옷 본체 (은빛 강철) ──
        armor_w = int(3.8 * b)
        armor_h = int(2.6 * b)
        armor_rect = pygame.Rect(cx - armor_w // 2, ty - int(0.5 * b), armor_w, armor_h)

        # 베이스 강철색
        pygame.draw.rect(surface, (85, 95, 115), armor_rect, border_radius=6)
        # 내부 패널
        inner = armor_rect.inflate(-int(0.3 * b), -int(0.3 * b))
        pygame.draw.rect(surface, (100, 115, 140), inner, border_radius=5)
        # 상단 하이라이트
        highlight_h = int(0.6 * b)
        highlight_rect = pygame.Rect(inner.left + 2, inner.top + 1, inner.width - 4, highlight_h)
        pygame.draw.rect(surface, (140, 155, 180), highlight_rect, border_radius=3)

        # ── 중앙 장식선 ──
        line_x = cx
        pygame.draw.line(surface, (170, 140, 40), (line_x, armor_rect.top + 4), (line_x, armor_rect.bottom - 4), 2)
        pygame.draw.line(surface, (210, 185, 60), (line_x, armor_rect.top + 5), (line_x, armor_rect.bottom - 5), 1)

        # ── 발할라 문양 (중앙 원형 + 날개) ──
        emblem_cy = ty + int(0.5 * b)
        # 문양 글로우
        glow_pulse = (math.sin(phase * math.tau * 1.5) + 1) / 2
        glow_r = max(1, int(0.5 * b + 0.1 * b * glow_pulse))
        glow_alpha = int(40 + 40 * glow_pulse)
        glow_surf = pygame.Surface((glow_r * 2 + 4, glow_r * 2 + 4), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (255, 210, 80, glow_alpha), (glow_r + 2, glow_r + 2), glow_r)
        surface.blit(glow_surf, (cx - glow_r - 2, emblem_cy - glow_r - 2))
        # 원형 심볼
        pygame.draw.circle(surface, (180, 150, 30), (cx, emblem_cy), max(1, int(0.3 * b)))
        pygame.draw.circle(surface, (230, 200, 60), (cx, emblem_cy), max(1, int(0.22 * b)))
        # 날개
        for side in [-1, 1]:
            wing_pts = [
                (cx + side * int(0.3 * b), emblem_cy),
                (cx + side * int(0.9 * b), emblem_cy - int(0.4 * b)),
                (cx + side * int(0.7 * b), emblem_cy),
            ]
            pygame.draw.polygon(surface, (210, 185, 60), wing_pts)

        # ── 룬 각인 (좌우) ──
        rune_color = (170, 155, 80)
        for side in [-1, 1]:
            rx = cx + side * int(1.0 * b)
            ry = ty + int(0.2 * b)
            pygame.draw.line(surface, rune_color, (rx, ry - 3), (rx, ry + 3), 1)
            pygame.draw.line(surface, rune_color, (rx - 2, ry - 1), (rx + 2, ry + 1), 1)

        # ── 어깨 보호대 ──
        guard_w = int(1.3 * b)
        guard_h = int(0.7 * b)
        for side in [-1, 1]:
            guard_rect = pygame.Rect(
                cx + side * int(1.6 * b) - guard_w // 2,
                ty - int(0.8 * b),
                guard_w, guard_h,
            )
            pygame.draw.rect(surface, (110, 125, 150), guard_rect, border_radius=3)
            pygame.draw.rect(surface, (140, 155, 180), guard_rect.inflate(-2, -2), border_radius=2)
            pygame.draw.rect(surface, (75, 85, 105), guard_rect, 1, border_radius=3)
            # 금 테두리
            pygame.draw.line(surface, (200, 170, 50),
                           (guard_rect.left + 2, guard_rect.bottom - 2),
                           (guard_rect.right - 2, guard_rect.bottom - 2), 1)

        # ── 외곽선 ──
        pygame.draw.rect(surface, (60, 70, 85), armor_rect, 1, border_radius=6)
