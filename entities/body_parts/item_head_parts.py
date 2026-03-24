"""
패시브 아이템 연동 헬멧 파츠 — 가시투구, 방탄모자.

아이템 획득 시 skin.set_part()로 교체하여 외형을 변경한다.
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_HEAD, SLOT_HEAD
from typing import Optional


class SpikedHelmetPart(BodyPart):
    """가시투구 (spiked_helmet).

    짙은 강철색 투구 + 상단/측면 가시 5개.
    효과: 공 넉백 저항 증가.
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

        # ── 투구 본체 (강철색) ──
        helmet_w = int(2.8 * b)
        helmet_h = int(2.4 * b)
        helmet_rect = pygame.Rect(
            hx - helmet_w // 2,
            hy - helmet_h // 2 - int(0.3 * b),
            helmet_w, helmet_h,
        )
        # 베이스
        pygame.draw.ellipse(surface, (80, 90, 105), helmet_rect)
        # 내부 밝은 면
        inner = helmet_rect.inflate(-int(0.5 * b), -int(0.5 * b))
        pygame.draw.ellipse(surface, (100, 115, 130), inner)

        # ── 가시 5개 (상단 부채꼴) ──
        spike_colors = [(140, 150, 160), (160, 170, 180)]
        num_spikes = 5
        for i in range(num_spikes):
            angle = math.radians(-140 + i * 70)  # -140° ~ +140° 범위
            base_x = hx + int(math.cos(angle) * helmet_w * 0.42)
            base_y = helmet_rect.top + int(0.3 * b) + int(math.sin(angle) * helmet_h * 0.15)

            tip_x = hx + int(math.cos(angle) * (helmet_w * 0.42 + int(1.0 * b)))
            tip_y = base_y - int(1.2 * b)

            # 가시 삼각형
            spike_w = max(2, int(0.3 * b))
            tri = [
                (base_x - spike_w, base_y),
                (tip_x, tip_y),
                (base_x + spike_w, base_y),
            ]
            pygame.draw.polygon(surface, spike_colors[i % 2], tri)
            # 가시 하이라이트
            pygame.draw.line(surface, (200, 210, 220), (base_x, base_y), (tip_x, tip_y), 1)

        # ── T자 바이저 ──
        visor_y = helmet_rect.centery + int(0.3 * b)
        visor_w = int(1.4 * b)
        pygame.draw.line(
            surface, (200, 80, 60),
            (hx - visor_w // 2, visor_y),
            (hx + visor_w // 2, visor_y), 2,
        )
        # 코 가드
        pygame.draw.line(
            surface, (90, 100, 110),
            (hx, visor_y - int(0.3 * b)),
            (hx, visor_y + int(0.4 * b)), 2,
        )

        # ── 테두리 ──
        pygame.draw.ellipse(surface, (60, 70, 80), helmet_rect, 1)


class BulletproofHatPart(BodyPart):
    """방탄모자 (bulletproof_hat).

    군용 네이비 방탄 헬멧 + 고글 + NVG 마운트.
    효과: 투사체 데미지 감소.
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

        # ── 헬멧 본체 (네이비/올리브) ──
        helmet_w = int(2.9 * b)
        helmet_h = int(2.0 * b)
        helmet_rect = pygame.Rect(
            hx - helmet_w // 2,
            hy - helmet_h // 2 - int(0.5 * b),
            helmet_w, helmet_h,
        )
        pygame.draw.ellipse(surface, (55, 75, 55), helmet_rect)  # 올리브드랩
        # 밝은 면
        highlight = helmet_rect.inflate(-int(0.8 * b), -int(0.7 * b))
        highlight.move_ip(-2, -2)
        pygame.draw.ellipse(surface, (75, 95, 70), highlight, 1)

        # ── 헬멧 밴드 (수평) ──
        band_y = helmet_rect.centery - int(0.1 * b)
        pygame.draw.line(
            surface, (40, 55, 40),
            (helmet_rect.left + int(0.3 * b), band_y),
            (helmet_rect.right - int(0.3 * b), band_y), 2,
        )

        # ── 고글 (원형 2개) ──
        goggle_y = helmet_rect.centery + int(0.3 * b)
        goggle_r = max(3, int(0.45 * b))
        for gx_off in [-int(0.55 * b), int(0.55 * b)]:
            gx = hx + gx_off
            # 고글 프레임
            pygame.draw.circle(surface, (30, 35, 30), (gx, goggle_y), goggle_r + 1)
            # 렌즈 (녹색 야시경 느낌)
            pygame.draw.circle(surface, (100, 180, 80), (gx, goggle_y), goggle_r)
            # 렌즈 하이라이트
            pygame.draw.circle(surface, (160, 220, 140), (gx - 1, goggle_y - 1), max(1, goggle_r // 2))
        # 고글 브릿지
        pygame.draw.line(
            surface, (30, 35, 30),
            (hx - int(0.55 * b) + goggle_r, goggle_y),
            (hx + int(0.55 * b) - goggle_r, goggle_y), 2,
        )

        # ── 페이스 (헬멧 아래) ──
        face_w = int(1.6 * b)
        face_h = int(1.0 * b)
        face_rect = pygame.Rect(
            hx - face_w // 2,
            helmet_rect.bottom - int(0.2 * b),
            face_w, face_h,
        )
        pygame.draw.ellipse(surface, palette.get("face", (212, 196, 176)), face_rect)

        # ── NVG 마운트 (상단 중앙) ──
        nvg_rect = pygame.Rect(hx - int(0.3 * b), helmet_rect.top - int(0.2 * b), int(0.6 * b), int(0.5 * b))
        pygame.draw.rect(surface, (40, 50, 40), nvg_rect, border_radius=1)
        pygame.draw.rect(surface, (60, 80, 60), nvg_rect.inflate(-2, -2), border_radius=1)
