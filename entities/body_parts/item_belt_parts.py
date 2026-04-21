"""
패시브 아이템 연동 벨트 파츠 — 메긴교르드.
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_BELT, SLOT_BELT
from typing import Optional


class MegingjordBeltPart(BodyPart):
    """메긴교르드 (megingjord).

    토르의 힘의 벨트. 금색 가죽 벨트 + 번개 문양 버클.
    효과: 퍽 선택 시 추가 선택 기회.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_BELT,
            draw_order=ORDER_BELT,  # 벨트 슬롯: 몸통 위, 팔 아래
            joint_a="hip",
            joint_b=None,
        )
        self.block = block
        self._time = 0.0

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, hy = joint_a.world_int()
        self._time += 0.016

        # ── 벨트 색상 ──
        belt_dark = (60, 35, 20)
        belt_mid = (90, 55, 30)
        belt_light = (110, 70, 38)
        gold = (255, 215, 0)
        gold_bright = (255, 240, 100)
        lightning_blue = (100, 180, 255)

        # ── 벨트 본체 (허리 부분) ──
        belt_w = int(3.4 * b)
        belt_h = max(3, int(0.7 * b))
        belt_y = hy - belt_h // 2

        # 벨트 그림자
        shadow_rect = pygame.Rect(cx - belt_w // 2, belt_y + 1, belt_w, belt_h)
        pygame.draw.rect(surface, belt_dark, shadow_rect, border_radius=2)

        # 벨트 본체
        belt_rect = pygame.Rect(cx - belt_w // 2, belt_y, belt_w, belt_h)
        pygame.draw.rect(surface, belt_mid, belt_rect, border_radius=2)

        # 벨트 하이라이트 (상단)
        hl_rect = pygame.Rect(cx - belt_w // 2 + 1, belt_y, belt_w - 2, max(1, belt_h // 3))
        pygame.draw.rect(surface, belt_light, hl_rect, border_radius=1)

        # ── 버클 (중앙 원형, 금색) ──
        buckle_r = max(2, int(0.55 * b))
        buckle_cx = cx
        buckle_cy = belt_y + belt_h // 2

        # 버클 글로우 (미약한 펄스)
        glow_alpha = int(40 + 20 * math.sin(self._time * 3.0))
        glow_surf = pygame.Surface((buckle_r * 4, buckle_r * 4), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (255, 215, 0, glow_alpha),
                         (buckle_r * 2, buckle_r * 2), buckle_r * 2)
        surface.blit(glow_surf,
                    (buckle_cx - buckle_r * 2, buckle_cy - buckle_r * 2))

        # 버클 본체
        pygame.draw.circle(surface, gold, (buckle_cx, buckle_cy), buckle_r)
        pygame.draw.circle(surface, gold_bright, (buckle_cx, buckle_cy), max(1, buckle_r - 1))

        # 번개 문양 (지그재그)
        lh = max(2, int(0.4 * b))
        lightning_pts = [
            (buckle_cx - 1, buckle_cy - lh),
            (buckle_cx + 1, buckle_cy - 1),
            (buckle_cx - 1, buckle_cy + 1),
            (buckle_cx + 1, buckle_cy + lh),
        ]
        pygame.draw.lines(surface, lightning_blue, False, lightning_pts,
                        max(1, int(0.15 * b)))

        # ── 룬 장식 (좌우 작은 다이아몬드) ──
        for side in [-1, 1]:
            rx = buckle_cx + side * int(1.2 * b)
            ry = buckle_cy
            rs = max(1, int(0.2 * b))
            rune_pts = [
                (rx, ry - rs), (rx + rs, ry),
                (rx, ry + rs), (rx - rs, ry),
            ]
            pygame.draw.polygon(surface, gold, rune_pts)

        # ── 벨트 구멍 장식 ──
        for side in [-1, 1]:
            hx = buckle_cx + side * int(1.5 * b)
            pygame.draw.circle(surface, belt_dark, (hx, buckle_cy), max(1, int(0.1 * b)))


class TimerBeltPart(BodyPart):
    """타이머벨트 (timer_belt).

    스킬 쿨타임 감소 패시브의 허리 외형. 갈색 가죽 벨트 + 모래시계 버클 + 시안 크로노 글로우.
    효과: 모든 캐릭터 스킬의 쿨타임을 감소시킴.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_BELT,
            draw_order=ORDER_BELT,  # 벨트 슬롯: 몸통 위, 팔 아래 (megingjord와 동일 레이어)
            joint_a="hip",
            joint_b=None,
        )
        self.block = block
        self._time = 0.0

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, hy = joint_a.world_int()
        self._time += 0.016

        # ── 벨트 색상 (가죽 갈색 + 시안 크로노) ──
        belt_dark = (55, 30, 15)
        belt_mid = (110, 65, 35)
        belt_light = (150, 95, 50)
        steel_dark = (90, 100, 115)
        steel_light = (170, 185, 200)
        cyan_core = (90, 220, 230)
        cyan_bright = (200, 245, 255)

        # ── 벨트 본체 (허리 부분) ──
        belt_w = int(3.4 * b)
        belt_h = max(3, int(0.7 * b))
        belt_y = hy - belt_h // 2

        # 벨트 그림자
        shadow_rect = pygame.Rect(cx - belt_w // 2, belt_y + 1, belt_w, belt_h)
        pygame.draw.rect(surface, belt_dark, shadow_rect, border_radius=2)

        # 벨트 본체
        belt_rect = pygame.Rect(cx - belt_w // 2, belt_y, belt_w, belt_h)
        pygame.draw.rect(surface, belt_mid, belt_rect, border_radius=2)

        # 벨트 하이라이트 (상단)
        hl_rect = pygame.Rect(cx - belt_w // 2 + 1, belt_y, belt_w - 2, max(1, belt_h // 3))
        pygame.draw.rect(surface, belt_light, hl_rect, border_radius=1)

        # ── 모래시계 버클 (중앙, 시안 크로노 코어) ──
        buckle_half = max(2, int(0.55 * b))
        buckle_cx = cx
        buckle_cy = belt_y + belt_h // 2

        # 시안 글로우 (크로노 펄스)
        glow_alpha = int(60 + 30 * math.sin(self._time * 3.0))
        glow_surf = pygame.Surface((buckle_half * 4, buckle_half * 4), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*cyan_core, glow_alpha),
                           (buckle_half * 2, buckle_half * 2), buckle_half * 2)
        surface.blit(glow_surf,
                     (buckle_cx - buckle_half * 2, buckle_cy - buckle_half * 2))

        # 모래시계 상단 삼각형 (강철)
        top_tri = [
            (buckle_cx - buckle_half, buckle_cy - buckle_half),
            (buckle_cx + buckle_half, buckle_cy - buckle_half),
            (buckle_cx, buckle_cy),
        ]
        pygame.draw.polygon(surface, steel_light, top_tri)
        pygame.draw.polygon(surface, steel_dark, top_tri, 1)

        # 모래시계 하단 삼각형 (강철)
        bot_tri = [
            (buckle_cx - buckle_half, buckle_cy + buckle_half),
            (buckle_cx + buckle_half, buckle_cy + buckle_half),
            (buckle_cx, buckle_cy),
        ]
        pygame.draw.polygon(surface, steel_light, bot_tri)
        pygame.draw.polygon(surface, steel_dark, bot_tri, 1)

        # 모래시계 내부 시안 코어 (상단)
        inner_top = [
            (buckle_cx - buckle_half + 1, buckle_cy - buckle_half + 1),
            (buckle_cx + buckle_half - 1, buckle_cy - buckle_half + 1),
            (buckle_cx, buckle_cy),
        ]
        pygame.draw.polygon(surface, cyan_core, inner_top)

        # 모래시계 내부 시안 코어 (하단)
        inner_bot = [
            (buckle_cx - buckle_half + 1, buckle_cy + buckle_half - 1),
            (buckle_cx + buckle_half - 1, buckle_cy + buckle_half - 1),
            (buckle_cx, buckle_cy),
        ]
        pygame.draw.polygon(surface, cyan_core, inner_bot)

        # 중심 빛 (펄스)
        if int(self._time * 3) % 2 == 0:
            pygame.draw.circle(surface, cyan_bright, (buckle_cx, buckle_cy), max(1, int(0.15 * b)))

        # ── 벨트 구멍 장식 ──
        for side in [-1, 1]:
            hx = buckle_cx + side * int(1.5 * b)
            pygame.draw.circle(surface, belt_dark, (hx, buckle_cy), max(1, int(0.1 * b)))
