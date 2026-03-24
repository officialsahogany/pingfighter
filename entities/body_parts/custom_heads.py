"""
커스텀 헬멧 파츠 — 파츠 스왑 시스템 데모용.

기존 SmasherHeadPart와 동일한 슬롯(SLOT_HEAD)을 사용하므로,
skin.set_part()로 교체하면 즉시 헬멧이 바뀐다.
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_HEAD, SLOT_HEAD
from typing import Optional


class HornedHelmetPart(BodyPart):
    """뿔 달린 바이킹 투구.

    기본 헬멧 형태 + 양쪽에 붉은 뿔 2개.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_HEAD,
            draw_order=ORDER_HEAD,
            joint_a="head",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        hx, hy = joint_a.world_int()

        # ── 헬멧 본체 (짙은 철색) ──
        helmet_w = int(2.8 * b)
        helmet_h = int(2.3 * b)
        helmet_rect = pygame.Rect(
            hx - helmet_w // 2,
            hy - helmet_h // 2 - int(0.4 * b),
            helmet_w, helmet_h,
        )
        # 다크 메탈 헬멧
        pygame.draw.ellipse(surface, (60, 55, 50), helmet_rect)
        # 철 하이라이트
        inner = helmet_rect.inflate(-int(0.4 * b), -int(0.4 * b))
        pygame.draw.ellipse(surface, (90, 82, 72), inner)

        # ── 뿔 (왼쪽) ──
        horn_base_l = (helmet_rect.left + int(0.3 * b), helmet_rect.top + int(0.5 * b))
        horn_mid_l = (horn_base_l[0] - int(1.2 * b), horn_base_l[1] - int(1.0 * b))
        horn_tip_l = (horn_mid_l[0] - int(0.4 * b), horn_mid_l[1] - int(0.8 * b))

        pygame.draw.line(surface, (180, 140, 80), horn_base_l, horn_mid_l, max(2, b // 3))
        pygame.draw.line(surface, (220, 180, 100), horn_mid_l, horn_tip_l, max(1, b // 4))
        # 뿔 끝 빛남
        pygame.draw.circle(surface, (255, 220, 140), horn_tip_l, 2)

        # ── 뿔 (오른쪽) ──
        horn_base_r = (helmet_rect.right - int(0.3 * b), helmet_rect.top + int(0.5 * b))
        horn_mid_r = (horn_base_r[0] + int(1.2 * b), horn_base_r[1] - int(1.0 * b))
        horn_tip_r = (horn_mid_r[0] + int(0.4 * b), horn_mid_r[1] - int(0.8 * b))

        pygame.draw.line(surface, (180, 140, 80), horn_base_r, horn_mid_r, max(2, b // 3))
        pygame.draw.line(surface, (220, 180, 100), horn_mid_r, horn_tip_r, max(1, b // 4))
        pygame.draw.circle(surface, (255, 220, 140), horn_tip_r, 2)

        # ── T자 바이저 (눈 슬릿) ──
        visor_y = helmet_rect.centery + int(0.2 * b)
        visor_w = int(1.6 * b)
        # 가로 슬릿
        pygame.draw.line(
            surface, (200, 60, 40),
            (hx - visor_w // 2, visor_y),
            (hx + visor_w // 2, visor_y), 2,
        )
        # 세로 코 가드
        pygame.draw.line(
            surface, (80, 70, 60),
            (hx, visor_y - int(0.3 * b)),
            (hx, visor_y + int(0.5 * b)), 2,
        )

        # ── 릿지 (중앙 세로선) ──
        ridge_top = helmet_rect.top + int(0.3 * b)
        ridge_bottom = helmet_rect.centery - int(0.1 * b)
        pygame.draw.line(surface, (120, 110, 95), (hx, ridge_top), (hx, ridge_bottom), 2)


class CrownHelmetPart(BodyPart):
    """황금 왕관.

    왕관 본체 + 5개 꼭짓점 + 보석 3개.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_HEAD,
            draw_order=ORDER_HEAD,
            joint_a="head",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        hx, hy = joint_a.world_int()

        # ── 왕관 베이스 ──
        crown_w = int(2.6 * b)
        crown_h = int(1.0 * b)
        base_rect = pygame.Rect(
            hx - crown_w // 2,
            hy - int(0.2 * b),
            crown_w, crown_h,
        )
        pygame.draw.rect(surface, (200, 170, 50), base_rect, border_radius=2)
        pygame.draw.rect(surface, (240, 210, 80), base_rect.inflate(-2, -2), border_radius=2)

        # ── 왕관 톱니 (5개 삼각형) ──
        num_points = 5
        point_w = crown_w // num_points
        point_height = int(1.5 * b)

        # 연한 반짝임 (phase 기반)
        sparkle = int(20 * math.sin(phase * math.tau * 3))

        for i in range(num_points):
            px = base_rect.left + point_w * i + point_w // 2
            tip_y = base_rect.top - point_height
            tri = [
                (px - point_w // 2 + 1, base_rect.top),
                (px, tip_y),
                (px + point_w // 2 - 1, base_rect.top),
            ]
            gold = (min(255, 220 + sparkle), min(255, 190 + sparkle), 60)
            pygame.draw.polygon(surface, gold, tri)
            # 꼭짓점 하이라이트
            pygame.draw.circle(surface, (255, 255, 200), (px, tip_y + 1), 2)

        # ── 보석 3개 (루비/사파이어/에메랄드) ──
        gem_y = base_rect.centery
        gems = [
            (hx - int(0.8 * b), (220, 40, 40)),     # 루비 (좌)
            (hx, (40, 80, 220)),                      # 사파이어 (중)
            (hx + int(0.8 * b), (40, 180, 60)),      # 에메랄드 (우)
        ]
        gem_r = max(2, int(0.25 * b))
        for gx, gc in gems:
            # 보석 테두리
            pygame.draw.circle(surface, (160, 140, 40), (gx, gem_y), gem_r + 1)
            # 보석
            pygame.draw.circle(surface, gc, (gx, gem_y), gem_r)
            # 하이라이트
            pygame.draw.circle(surface, (255, 255, 255), (gx - 1, gem_y - 1), max(1, gem_r // 2))

        # ── 페이스 (왕관 아래 얼굴) ──
        face_w = int(1.8 * b)
        face_h = int(1.4 * b)
        face_rect = pygame.Rect(
            hx - face_w // 2,
            base_rect.bottom - int(0.1 * b),
            face_w, face_h,
        )
        pygame.draw.ellipse(surface, palette.get("face", (212, 196, 176)), face_rect)

        # 눈 (바이저 스타일)
        eye_y = face_rect.centery - int(0.1 * b)
        eye_w = int(0.5 * b)
        pygame.draw.ellipse(
            surface, palette.get("visor", (170, 224, 255)),
            (hx - int(0.6 * b), eye_y, eye_w, int(0.35 * b)),
        )
        pygame.draw.ellipse(
            surface, palette.get("visor", (170, 224, 255)),
            (hx + int(0.1 * b), eye_y, eye_w, int(0.35 * b)),
        )
