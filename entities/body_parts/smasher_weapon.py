"""
SmasherWeaponPart — 스매셔 탁구채 (핸들 + 라켓면 + 글로우) 파츠.
Visual Polish: 나무 그레인 핸들 + 금속 칼라 + 스펀지층 + 러버 텍스처 + 네온 블룸
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

        # ── 핸들: 나무 그레인 + 그립 밴딩 + 엔드캡 ──
        handle_w = int(1.0 * b)
        handle_h = int(1.8 * b)
        handle_rect = pygame.Rect(wx - handle_w // 2, wy - int(1.4 * b),
                                  handle_w, handle_h)

        # 핸들 그림자
        pygame.draw.rect(surface, (110, 82, 55), handle_rect.move(1, 1),
                         border_radius=2)
        # 핸들 베이스 (진한 나무색)
        pygame.draw.rect(surface, palette["handle"], handle_rect, border_radius=2)
        # 나무 코어 (밝은 면)
        core_r = handle_rect.inflate(-max(1, b // 4), -max(1, b // 4))
        pygame.draw.rect(surface, palette["handle_core"], core_r, border_radius=1)

        # 나무결 (세로 미세 라인)
        grain_color = (160, 120, 85)
        for gx_off in [-1, 1]:
            pygame.draw.line(surface, grain_color,
                             (handle_rect.centerx + gx_off, handle_rect.top + 2),
                             (handle_rect.centerx + gx_off, handle_rect.bottom - 2), 1)

        # 그립 밴딩 (어두운 가로줄 — 가죽 래핑)
        grip_top = handle_rect.top + handle_h // 3
        grip_bot = handle_rect.bottom - 3
        for gy in range(grip_top, grip_bot, 3):
            pygame.draw.line(surface, (135, 100, 70),
                             (handle_rect.left + 1, gy),
                             (handle_rect.right - 1, gy), 1)

        # 엔드캡 (핸들 하단 금속)
        endcap_rect = pygame.Rect(handle_rect.left - 1, handle_rect.bottom - 3,
                                  handle_rect.width + 2, 4)
        pygame.draw.rect(surface, palette.get("trim", (190, 206, 236)),
                         endcap_rect, border_radius=1)
        pygame.draw.line(surface, (220, 230, 245),
                         (endcap_rect.left + 1, endcap_rect.top),
                         (endcap_rect.right - 1, endcap_rect.top), 1)

        # ── 금속 칼라 (핸들-라켓 접합부) ──
        collar_rect = pygame.Rect(handle_rect.left - 2, handle_rect.top - 3,
                                  handle_rect.width + 4, 5)
        pygame.draw.rect(surface, (85, 95, 130), collar_rect.move(0, 1))   # 그림자
        pygame.draw.rect(surface, palette.get("trim", (190, 206, 236)),
                         collar_rect, border_radius=1)
        pygame.draw.line(surface, (220, 235, 250),
                         (collar_rect.left + 1, collar_rect.top),
                         (collar_rect.right - 1, collar_rect.top), 1)    # 하이라이트
        # 리벳 2개
        pygame.draw.circle(surface, (220, 230, 245),
                           (collar_rect.left + 2, collar_rect.centery), 1)
        pygame.draw.circle(surface, (220, 230, 245),
                           (collar_rect.right - 2, collar_rect.centery), 1)

        # ── 라켓면 ──
        paddle_cx = handle_rect.centerx - int(1.3 * b)
        paddle_cy = handle_rect.top - int(0.5 * b)
        paddle_r = int(1.8 * b)

        # 라켓면 그림자
        pygame.draw.circle(surface, palette["paddle_shadow"],
                           (paddle_cx + 1, paddle_cy + 2), paddle_r)

        # 라켓면 베이스 (진한 빨강)
        pygame.draw.circle(surface, palette["paddle"], (paddle_cx, paddle_cy), paddle_r)

        # 스펀지 층 (라켓면 안쪽 얇은 오렌지 링)
        sponge_r = paddle_r - 2
        pygame.draw.circle(surface, (230, 140, 90),
                           (paddle_cx, paddle_cy), sponge_r, 2)

        # 러버면 (밝은 빨강)
        rubber_r = paddle_r - 4
        pygame.draw.circle(surface, palette["paddle_core"],
                           (paddle_cx, paddle_cy), rubber_r)

        # 러버 텍스처 (가로 미세 라인 — 핌플 패턴 시뮬레이션)
        for ty_off in range(-rubber_r + 2, rubber_r - 1, 3):
            # 원 안쪽에만 그리기 — 반원 폭 계산
            chord_half = int(math.sqrt(max(0, rubber_r * rubber_r - ty_off * ty_off)))
            if chord_half < 2:
                continue
            line_y = paddle_cy + ty_off
            # 밝은 라인과 어두운 라인 교대
            if (ty_off // 3) % 2 == 0:
                line_color = (255, 130, 140, 40)
            else:
                line_color = (200, 80, 95, 40)
            tex_surf = pygame.Surface((chord_half * 2, 1), pygame.SRCALPHA)
            tex_surf.fill(line_color)
            surface.blit(tex_surf, (paddle_cx - chord_half, line_y))

        # 상단 하이라이트 아크 (광택)
        paddle_box = pygame.Rect(paddle_cx - paddle_r, paddle_cy - paddle_r,
                                 paddle_r * 2, paddle_r * 2)
        pygame.draw.arc(surface, (255, 190, 190),
                        paddle_box.inflate(-6, -6),
                        math.radians(200), math.radians(300), 2)
        # 2차 하이라이트 (더 작은 아크)
        pygame.draw.arc(surface, (255, 210, 210),
                        paddle_box.inflate(-10, -10),
                        math.radians(220), math.radians(280), 1)

        # 라켓면 하단 그림자 아크
        pygame.draw.arc(surface, palette["paddle_shadow"],
                        paddle_box.inflate(-3, -3),
                        math.radians(20), math.radians(160), 2)

        # ── 라켓 외곽 테두리 (어두운 엣지) ──
        pygame.draw.circle(surface, palette["paddle_shadow"],
                           (paddle_cx, paddle_cy), paddle_r, 1)

        # ── 라켓면 네온 블룸 (은은하게) ──
        pulse = 0.6 + 0.4 * math.sin(phase * math.tau * 2)
        glow_r = paddle_r + int(b * 0.25)
        glow_surf = pygame.Surface((glow_r * 2, glow_r * 2), pygame.SRCALPHA)
        glow_alpha = int(18 * pulse)
        pygame.draw.circle(glow_surf, (*palette["paddle_core"], glow_alpha),
                           (glow_r, glow_r), glow_r)
        surface.blit(glow_surf,
                     (paddle_cx - glow_r, paddle_cy - glow_r),
                     special_flags=pygame.BLEND_RGBA_ADD)

        # ── 핸들-라켓 연결 목 (넥) ──
        neck_x = handle_rect.centerx - int(0.5 * b)
        neck_y = collar_rect.top
        pygame.draw.line(surface, palette["handle"],
                         (neck_x, neck_y),
                         (paddle_cx + int(0.6 * b), paddle_cy + paddle_r - 2), 3)
        pygame.draw.line(surface, palette["handle_core"],
                         (neck_x, neck_y),
                         (paddle_cx + int(0.6 * b), paddle_cy + paddle_r - 2), 1)
