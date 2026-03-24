"""
패시브 아이템 연동 무기 파츠 — 라그나로크 해머, 포세이돈의 삼지창.
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_WEAPON, SLOT_WEAPON, ORDER_SHIELD, SLOT_SHIELD
from typing import Optional


class RagnarokHammerPart(BodyPart):
    """라그나로크 해머 (ragnarok_hammer).

    전설 무기: 거대한 붉은 해머 + 룬 문양 + 에너지 아우라.
    효과: 확률적으로 번개 타격.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_WEAPON,
            draw_order=ORDER_WEAPON,
            joint_a="l_wrist",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        wx, wy = joint_a.world_int()

        # ── 자루 (다크 브라운, 긴 핸들) ──
        handle_w = max(3, int(0.5 * b))
        handle_h = int(2.0 * b)
        handle_rect = pygame.Rect(
            wx - handle_w // 2,
            wy - int(1.5 * b),
            handle_w, handle_h,
        )
        pygame.draw.rect(surface, (80, 50, 30), handle_rect, border_radius=1)
        pygame.draw.rect(surface, (100, 65, 40), handle_rect.inflate(-2, -2), border_radius=1)
        # 그립 밴딩
        for gy in range(handle_rect.top + 2, handle_rect.bottom - 2, 3):
            pygame.draw.line(
                surface, (70, 45, 25),
                (handle_rect.left + 1, gy),
                (handle_rect.right - 1, gy), 1,
            )

        # ── 해머 헤드 (큰 직사각형) ──
        head_w = int(2.4 * b)
        head_h = int(1.4 * b)
        head_cx = handle_rect.centerx - int(0.8 * b)
        head_cy = handle_rect.top - int(0.2 * b)
        head_rect = pygame.Rect(
            head_cx - head_w // 2,
            head_cy - head_h // 2,
            head_w, head_h,
        )

        # 해머 그림자
        shadow = head_rect.move(2, 2)
        pygame.draw.rect(surface, (40, 20, 20), shadow, border_radius=3)

        # 해머 본체 (진홍-회색)
        pygame.draw.rect(surface, (120, 40, 35), head_rect, border_radius=3)
        pygame.draw.rect(surface, (150, 55, 45), head_rect.inflate(-3, -3), border_radius=2)

        # ── 룬 문양 (중앙 십자) ──
        pulse = int(30 * math.sin(phase * math.tau * 2))
        rune_color = (min(255, 220 + pulse), min(255, 160 + pulse), 60)
        rcx, rcy = head_rect.centerx, head_rect.centery
        # 세로
        pygame.draw.line(surface, rune_color, (rcx, head_rect.top + 3), (rcx, head_rect.bottom - 3), 2)
        # 가로
        pygame.draw.line(surface, rune_color, (head_rect.left + 3, rcy), (head_rect.right - 3, rcy), 2)
        # 대각선
        pygame.draw.line(surface, rune_color, (head_rect.left + 5, head_rect.top + 5), (head_rect.right - 5, head_rect.bottom - 5), 1)
        pygame.draw.line(surface, rune_color, (head_rect.right - 5, head_rect.top + 5), (head_rect.left + 5, head_rect.bottom - 5), 1)

        # ── 에너지 아우라 (해머 주위 글로우) ──
        aura_surf = pygame.Surface((head_w + b * 2, head_h + b * 2), pygame.SRCALPHA)
        acx, acy = aura_surf.get_width() // 2, aura_surf.get_height() // 2
        aura_alpha = int(50 + 30 * math.sin(phase * math.tau * 3))
        pygame.draw.ellipse(
            aura_surf,
            (255, 100, 60, aura_alpha),
            (0, 0, aura_surf.get_width(), aura_surf.get_height()),
        )
        surface.blit(
            aura_surf,
            (head_rect.centerx - acx, head_rect.centery - acy),
            special_flags=pygame.BLEND_RGBA_ADD,
        )

        # 테두리
        pygame.draw.rect(surface, (100, 30, 25), head_rect, 1, border_radius=3)


class PoseidonTridentPart(BodyPart):
    """포세이돈의 삼지창 (poseidon_trident).

    전설 무기: 푸른 삼지창 + 물결 이펙트 + 바다빛 아우라.
    효과: 대시 시 물결 파동, 공 궤적 영향.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_WEAPON,
            draw_order=ORDER_WEAPON,
            joint_a="l_wrist",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        wx, wy = joint_a.world_int()

        # ── 자루 (바다색 긴 핸들) ──
        handle_w = max(3, int(0.4 * b))
        handle_h = int(2.8 * b)
        handle_rect = pygame.Rect(
            wx - handle_w // 2,
            wy - int(2.0 * b),
            handle_w, handle_h,
        )
        pygame.draw.rect(surface, (40, 80, 120), handle_rect, border_radius=1)
        pygame.draw.rect(surface, (60, 110, 160), handle_rect.inflate(-2, -2), border_radius=1)
        # 나선 장식
        for sy in range(handle_rect.top + 2, handle_rect.bottom - 2, 4):
            pygame.draw.line(
                surface, (80, 140, 190),
                (handle_rect.left + 1, sy),
                (handle_rect.right - 1, sy + 2), 1,
            )

        # ── 삼지창 헤드 (3개의 창날) ──
        prong_base_y = handle_rect.top
        prong_h = int(1.5 * b)
        prong_w = max(2, int(0.3 * b))
        prong_spacing = int(0.6 * b)

        for i, px_off in enumerate([-prong_spacing, 0, prong_spacing]):
            px = wx + px_off
            tip_y = prong_base_y - prong_h - (int(0.4 * b) if i == 1 else 0)  # 중앙이 더 긺

            # 창날 본체
            tri = [
                (px - prong_w, prong_base_y),
                (px, tip_y),
                (px + prong_w, prong_base_y),
            ]
            pygame.draw.polygon(surface, (60, 140, 200), tri)
            # 밝은 면
            inner_tri = [
                (px - prong_w + 1, prong_base_y - 1),
                (px, tip_y + 2),
                (px + prong_w - 1, prong_base_y - 1),
            ]
            pygame.draw.polygon(surface, (100, 180, 240), inner_tri)
            # 중심선 하이라이트
            pygame.draw.line(surface, (160, 220, 255), (px, tip_y + 2), (px, prong_base_y - 2), 1)

        # ── 가드 (창날과 자루 연결부) ──
        guard_w = int(1.8 * b)
        guard_h = max(3, int(0.35 * b))
        guard_rect = pygame.Rect(
            wx - guard_w // 2,
            prong_base_y - guard_h // 2,
            guard_w, guard_h,
        )
        pygame.draw.rect(surface, (50, 100, 160), guard_rect, border_radius=2)
        pygame.draw.rect(surface, (80, 140, 200), guard_rect.inflate(-2, -2), border_radius=1)

        # ── 바다빛 아우라 (삼지창 주위) ──
        aura_w = int(2.5 * b)
        aura_h = int(2.5 * b)
        aura_surf = pygame.Surface((aura_w, aura_h), pygame.SRCALPHA)
        aura_pulse = 0.5 + 0.5 * math.sin(phase * math.tau * 2)
        aura_alpha = int(35 * aura_pulse)
        pygame.draw.ellipse(
            aura_surf, (60, 160, 255, aura_alpha),
            (0, 0, aura_w, aura_h),
        )
        surface.blit(
            aura_surf,
            (wx - aura_w // 2, prong_base_y - prong_h - aura_h // 3),
            special_flags=pygame.BLEND_RGBA_ADD,
        )

        # ── 물방울 파티클 (삼지창 끝에서) ──
        drop_phase = (phase * 3) % 1.0
        drop_y = prong_base_y - prong_h + int(drop_phase * prong_h * 0.8)
        drop_alpha = int(120 * (1.0 - drop_phase))
        drop_r = max(1, int(0.15 * b))
        drop_surf = pygame.Surface((drop_r * 4, drop_r * 4), pygame.SRCALPHA)
        pygame.draw.circle(
            drop_surf, (100, 200, 255, drop_alpha),
            (drop_r * 2, drop_r * 2), drop_r,
        )
        surface.blit(
            drop_surf,
            (wx - drop_r * 2 - int(0.3 * b), drop_y - drop_r * 2),
            special_flags=pygame.BLEND_RGBA_ADD,
        )


class RagnarokHammerRightPart(BodyPart):
    """라그나로크 해머 오른손 버전 (shield 슬롯).

    포세이돈 삼지창과 동시 장착 시 오른손에 표시.
    렌더링은 왼손 버전과 동일하되 joint를 r_wrist에 연결.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_SHIELD,
            draw_order=ORDER_SHIELD,
            joint_a="r_wrist",
            joint_b=None,
        )
        self.block = block
        self._left_part = RagnarokHammerPart(block)

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        self._left_part._render(surface, joint_a, joint_b, palette, phase)


class PoseidonTridentRightPart(BodyPart):
    """포세이돈의 삼지창 오른손 버전 (shield 슬롯).

    라그나로크 해머와 동시 장착 시 오른손에 표시.
    렌더링은 왼손 버전과 동일하되 joint를 r_wrist에 연결.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_SHIELD,
            draw_order=ORDER_SHIELD,
            joint_a="r_wrist",
            joint_b=None,
        )
        self.block = block
        self._left_part = PoseidonTridentPart(block)

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        self._left_part._render(surface, joint_a, joint_b, palette, phase)
