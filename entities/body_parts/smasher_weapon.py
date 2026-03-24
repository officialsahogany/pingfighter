"""
SmasherWeaponPart — 스매셔 탁구채 (핸들 + 라켓면 + 글로우) 파츠.
Visual Polish: 3단 레이어링 + 라켓면 네온 블룸 + 그립 디테일
"""

import math
import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton, ORDER_WEAPON, SLOT_WEAPON,
)
from typing import Optional


class SmasherWeaponPart(BodyPart):

    def __init__(self, block: int = 9):
        super().__init__(slot=SLOT_WEAPON, draw_order=ORDER_WEAPON,
                         joint_a="l_wrist", joint_b=None)
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        wx, wy = joint_a.world_int()

        # ── 핸들: 3단 + 그립 밴딩 ──
        handle_rect = pygame.Rect(wx - b // 2, wy - int(1.3 * b),
                                  int(0.9 * b), int(1.6 * b))
        # 그림자
        pygame.draw.rect(surface, (120, 90, 65), handle_rect.move(1, 1))
        # 베이스
        pygame.draw.rect(surface, palette["handle"], handle_rect)
        # 코어
        core_r = handle_rect.inflate(-max(1, b // 3), -max(1, b // 3))
        pygame.draw.rect(surface, palette["handle_core"], core_r)
        # 그립 밴딩 (가로줄)
        for gy in range(handle_rect.top + 2, handle_rect.bottom - 2, 3):
            pygame.draw.line(surface, (150, 115, 80),
                           (handle_rect.left + 1, gy),
                           (handle_rect.right - 1, gy), 1)

        # ── 라켓면: 3단 + 블룸 ──
        paddle_cx = handle_rect.centerx - int(1.2 * b)
        paddle_cy = handle_rect.top - int(0.4 * b)
        paddle_r = int(1.7 * b)

        # 그림자
        pygame.draw.circle(surface, palette["paddle_shadow"],
                          (paddle_cx + 1, paddle_cy + 1), paddle_r)
        # 베이스
        pygame.draw.circle(surface, palette["paddle"], (paddle_cx, paddle_cy), paddle_r)
        # 내부 밝은면
        pygame.draw.circle(surface, palette["paddle_core"],
                          (paddle_cx, paddle_cy), max(2, paddle_r - 3))
        # 상단 하이라이트 아크
        paddle_box = pygame.Rect(paddle_cx - paddle_r, paddle_cy - paddle_r,
                                paddle_r * 2, paddle_r * 2)
        pygame.draw.arc(surface, (255, 180, 180),
                       paddle_box.inflate(-4, -4),
                       math.radians(200), math.radians(300), 2)

        # 라켓면 네온 블룸
        pulse = 0.6 + 0.4 * math.sin(phase * math.tau * 2)
        glow_r = paddle_r + int(b * 0.3)
        glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
        glow_alpha = int(25 * pulse)
        pygame.draw.circle(glow_surf, (*palette["paddle_core"], glow_alpha),
                          (glow_r, glow_r), glow_r)
        surface.blit(glow_surf,
                    (paddle_cx - glow_r, paddle_cy - glow_r),
                    special_flags=pygame.BLEND_RGBA_ADD)

        # ── 라켓 외곽 테두리 ──
        pygame.draw.circle(surface, palette["paddle_shadow"],
                          (paddle_cx, paddle_cy), paddle_r, 1)

        # ── 연결부 리벳 (핸들-라켓 접합) ──
        conn_x = handle_rect.centerx - int(0.4 * b)
        conn_y = handle_rect.top
        pygame.draw.circle(surface, palette.get("trim", (190, 206, 236)),
                          (conn_x, conn_y), 2)
