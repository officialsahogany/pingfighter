"""
SmasherHeadPart — 스매셔 헬멧 + 바이저 + 페이스 + 릿지 파츠.
Visual Polish: 3단 레이어링 + 바이저 블룸 + 리벳/패널라인
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_HEAD, SLOT_HEAD
from typing import Optional


class SmasherHeadPart(BodyPart):

    def __init__(self, block: int = 9):
        super().__init__(slot=SLOT_HEAD, draw_order=ORDER_HEAD,
                         joint_a="head", joint_b=None)
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        hx, hy = joint_a.world_int()

        helmet_w = int(2.7 * b)
        helmet_h = int(2.2 * b)
        helmet_rect = pygame.Rect(
            hx - helmet_w // 2, hy - helmet_h // 2 - int(0.4 * b),
            helmet_w, helmet_h,
        )

        # ── 헬멧: 3단 레이어링 (그림자 → 베이스 → 하이라이트) ──
        shadow_rect = helmet_rect.move(1, 2)
        pygame.draw.ellipse(surface, (40, 55, 90), shadow_rect)          # 그림자
        pygame.draw.ellipse(surface, palette["helmet"], helmet_rect)      # 베이스
        inner_hl = helmet_rect.inflate(-int(0.7 * b), -int(0.6 * b))
        inner_hl.move_ip(-1, -2)
        pygame.draw.ellipse(surface, palette["helmet_high"], inner_hl, 1)  # 상단 광택

        # ── 사이드 모듈 (3단) ──
        side_w, side_h = int(0.8 * b), int(1.4 * b)
        for sx, mirror in [(helmet_rect.left - int(0.6 * b), False),
                           (helmet_rect.right - int(0.2 * b), True)]:
            sr = pygame.Rect(sx, helmet_rect.centery - int(0.6 * b), side_w, side_h)
            pygame.draw.ellipse(surface, (38, 52, 86), sr.move(1, 1))     # 그림자
            pygame.draw.ellipse(surface, palette["helmet_side"], sr)       # 베이스
            hl_r = sr.inflate(-2, -2)
            hl_r.move_ip(-1 if not mirror else 1, -1)
            pygame.draw.ellipse(surface, palette["helmet_high"], hl_r, 1)  # 하이라이트
            # 리벳 (나사못)
            pygame.draw.circle(surface, palette["trim"], (sr.centerx, sr.top + 3), 1)
            pygame.draw.circle(surface, palette["trim"], (sr.centerx, sr.bottom - 3), 1)

        # ── 페이스 (3단) ──
        face_rect = helmet_rect.inflate(-int(0.95 * b), -int(0.85 * b))
        face_rect.move_ip(0, int(0.65 * b))
        pygame.draw.ellipse(surface, (180, 165, 148), face_rect.move(0, 1))  # 그림자
        pygame.draw.ellipse(surface, palette["face"], face_rect)
        face_hl = face_rect.inflate(-int(0.5 * b), -int(0.4 * b))
        face_hl.move_ip(-1, -1)
        pygame.draw.ellipse(surface, (232, 220, 200), face_hl, 1)  # 피부 하이라이트

        # ── 바이저 + 블룸 (아이들 깜빡임 지원) ──
        visor_rect = face_rect.inflate(int(0.2 * b), int(-0.35 * b))
        # 바이저 외곽 (어두운 테두리)
        pygame.draw.ellipse(surface, (60, 100, 140), visor_rect.inflate(2, 2))

        # VFX 바이저 깜빡임 알파 (1.0=정상, 0.3=깜빡임 중)
        _blink_alpha = getattr(
            getattr(self, '_skin_ref', None), '_vfx_visor_blink_alpha', 1.0
        )
        _visor_color = palette["visor"]
        _visor_core_color = palette["visor_core"]
        if _blink_alpha < 1.0:
            # 깜빡임: 바이저를 어둡게
            _visor_color = tuple(int(c * _blink_alpha) for c in _visor_color)
            _visor_core_color = tuple(int(c * _blink_alpha) for c in _visor_core_color)

        pygame.draw.ellipse(surface, _visor_color, visor_rect)
        core_r = visor_rect.inflate(-int(0.55 * b), -int(0.4 * b))
        pygame.draw.ellipse(surface, _visor_core_color, core_r)

        # 바이저 블룸 (발광)
        pulse = 0.7 + 0.3 * math.sin(phase * math.tau * 2)
        glow_w = visor_rect.width + int(b * 0.6)
        glow_h = visor_rect.height + int(b * 0.4)
        glow_surf = pygame.Surface((glow_w, glow_h), pygame.SRCALPHA)
        glow_alpha = int(35 * pulse * _blink_alpha)
        pygame.draw.ellipse(glow_surf, (*_visor_core_color, glow_alpha),
                           (0, 0, glow_w, glow_h))
        surface.blit(glow_surf,
                    (visor_rect.centerx - glow_w // 2,
                     visor_rect.centery - glow_h // 2),
                    special_flags=pygame.BLEND_RGBA_ADD)

        # 바이저 스캔라인
        pygame.draw.line(surface, palette["helmet_high"],
                        (visor_rect.left + 2, visor_rect.centery - 1),
                        (visor_rect.right - 2, visor_rect.centery - 1), 1)

        # ── 릿지 (중앙 장식 + 패널라인) ──
        ridge_x = hx - int(0.25 * b)
        ridge_top = helmet_rect.top + int(0.2 * b)
        ridge_h = helmet_rect.height - int(0.5 * b)
        ridge_rect = pygame.Rect(ridge_x, ridge_top, int(0.5 * b), ridge_h)
        pygame.draw.rect(surface, (100, 130, 180), ridge_rect, border_radius=2)  # 어두운 베이스
        pygame.draw.rect(surface, palette["helmet_high"],
                        ridge_rect.inflate(-1, -2), border_radius=1)            # 밝은 면
        # 패널라인 (가로 절개선 2개)
        for py_off in [ridge_h // 3, ridge_h * 2 // 3]:
            pygame.draw.line(surface, (50, 65, 100),
                           (ridge_rect.left, ridge_top + py_off),
                           (ridge_rect.right, ridge_top + py_off), 1)

        # ── 헬멧 외곽 테두리 ──
        pygame.draw.ellipse(surface, (30, 40, 70), helmet_rect, 1)

        self._last_helmet_rect = helmet_rect
