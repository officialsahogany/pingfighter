"""
SmasherHeadPart — 스매셔 헬멧 + 바이저 + 페이스 + 릿지 파츠.

원본: pingfighter.py create_smasher_paddle_surface() 29642~29670줄
관절 바인딩: head (단일 관절)
"""

import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_HEAD, SLOT_HEAD
from typing import Optional


class SmasherHeadPart(BodyPart):
    """스매셔 메카 헬멧.

    head 관절의 월드 좌표를 기준으로 헬멧, 사이드 모듈, 페이스,
    바이저, 하이라이트, 릿지를 그린다.
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

        # ── 헬멧 본체 (타원) ──
        helmet_w = int(2.7 * b)
        helmet_h = int(2.2 * b)
        helmet_rect = pygame.Rect(
            hx - helmet_w // 2,
            hy - helmet_h // 2 - int(0.4 * b),     # 관절 위쪽으로 오프셋
            helmet_w, helmet_h,
        )
        pygame.draw.ellipse(surface, palette["helmet"], helmet_rect)

        # ── 사이드 모듈 (좌/우 귀 부분) ──
        side_w = int(0.8 * b)
        side_h = int(1.4 * b)
        side_mod_left = pygame.Rect(
            helmet_rect.left - int(0.6 * b),
            helmet_rect.centery - int(0.6 * b),
            side_w, side_h,
        )
        pygame.draw.ellipse(surface, palette["helmet_side"], side_mod_left)

        side_mod_right = pygame.Rect(
            helmet_rect.right - int(0.2 * b),
            helmet_rect.centery - int(0.6 * b),
            side_w, side_h,
        )
        pygame.draw.ellipse(surface, palette["helmet_side"], side_mod_right)

        # ── 페이스 (타원) ──
        face_rect = helmet_rect.inflate(-int(0.95 * b), -int(0.85 * b))
        face_rect.move_ip(0, int(0.65 * b))
        pygame.draw.ellipse(surface, palette["face"], face_rect)

        # ── 바이저 ──
        visor_rect = face_rect.inflate(int(0.2 * b), int(-0.35 * b))
        pygame.draw.ellipse(surface, palette["visor"], visor_rect)
        pygame.draw.ellipse(
            surface, palette["visor_core"],
            visor_rect.inflate(-int(0.55 * b), -int(0.4 * b)),
        )
        # 바이저 하이라이트 라인
        pygame.draw.line(
            surface, palette["helmet_high"],
            (visor_rect.left + 1, visor_rect.centery - 1),
            (visor_rect.right - 1, visor_rect.centery - 1), 1,
        )

        # ── 헬멧 하이라이트 (상단 광택) ──
        helmet_high = helmet_rect.inflate(-int(1.3 * b), -int(1.2 * b))
        helmet_high.move_ip(-1, -1)
        pygame.draw.ellipse(surface, palette["helmet_high"], helmet_high, 1)

        # ── 릿지 (중앙 세로 장식) ──
        ridge_rect = pygame.Rect(
            hx - int(0.25 * b),
            helmet_rect.top + int(0.2 * b),
            int(0.5 * b),
            helmet_rect.height - int(0.5 * b),
        )
        pygame.draw.rect(surface, palette["helmet_high"], ridge_rect, border_radius=2)

        # 외곽선용으로 helmet_rect을 저장 (OutlinePart에서 참조 가능)
        self._last_helmet_rect = helmet_rect
