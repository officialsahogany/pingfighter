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
