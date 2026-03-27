"""
OptimusTorsoPart — 옵티머스 상체 (바디+V라인+에너지코어+어깨패드+벨트).
원본: pingfighter.py _create_mecha_paddle_surface() 라인 28912~28998
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_TORSO, SLOT_TORSO
from typing import Optional


class OptimusTorsoPart(BodyPart):

    def __init__(self):
        super().__init__(slot=SLOT_TORSO, draw_order=ORDER_TORSO,
                         joint_a="torso", joint_b="hip")

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        # torso(어깨) 위치
        cx, shoulder_y = joint_a.world_int()
        # hip 위치
        _, hip_y = joint_b.world_int() if joint_b else (cx, shoulder_y + 44)

        # ── 상체 폴리곤 ──
        torso = [
            (cx - 80, shoulder_y + 8),
            (cx + 80, shoulder_y + 8),
            (cx + 64, hip_y + 8),
            (cx - 64, hip_y + 8),
        ]
        pygame.draw.polygon(surface, palette["body"], torso)
        pygame.draw.polygon(surface, palette["line"], torso, 4)

        # ── 가슴 패널 라인 + LED ──
        for panel_side in (-1, 1):
            panel_x = cx + panel_side * 50
            pygame.draw.line(surface, palette["helmet"],
                             (panel_x, shoulder_y + 16),
                             (panel_x - panel_side * 20, hip_y), 3)
            for led_i in range(3):
                led_y = shoulder_y + 24 + led_i * 16
                led_x = panel_x - panel_side * (4 + led_i * 4)
                pygame.draw.circle(surface, palette["accent"], (led_x, led_y), 3)
                pygame.draw.circle(surface, palette["visor_highlight"],
                                   (led_x, led_y), 2)

        # ── 허리 벨트 ──
        belt_y = hip_y - 4
        belt_rect = pygame.Rect(cx - 56, belt_y, 112, 12)
        pygame.draw.rect(surface, palette["grip"], belt_rect, border_radius=4)
        pygame.draw.rect(surface, palette["grip_line"],
                         belt_rect.inflate(-4, -4), 1, border_radius=3)
        # 벨트 버클
        buckle_rect = pygame.Rect(cx - 14, belt_y - 2, 28, 16)
        pygame.draw.rect(surface, palette["hex_base"], buckle_rect, border_radius=4)
        pygame.draw.rect(surface, palette["accent"], buckle_rect, 2, border_radius=4)
        pygame.draw.circle(surface, palette["hex_core"], (cx, belt_y + 6), 5)
        pygame.draw.circle(surface, palette["visor_highlight"], (cx, belt_y + 6), 3)

        # ── 네온 V 라인 (테슬라 시그니처) ──
        v_points = [
            (cx - 44, shoulder_y + 12),
            (cx, hip_y + 4),
            (cx + 44, shoulder_y + 12),
        ]
        pygame.draw.lines(surface, palette["accent"], False, v_points, 8)
        # V라인 교차점 발광
        v_glow = pygame.Surface((40, 40), pygame.SRCALPHA)
        pygame.draw.circle(v_glow, (*palette["accent"], 50), (20, 20), 20)
        surface.blit(v_glow, (cx - 20, hip_y - 16))

        # ── 중앙 에너지 코어 ──
        core_rect = pygame.Rect(cx - 18, shoulder_y + 20, 36, 52)
        pygame.draw.rect(surface, palette["hex_base"], core_rect, border_radius=8)
        pygame.draw.rect(surface, palette["hex_border"],
                         core_rect.inflate(8, 8), 4, border_radius=12)
        pygame.draw.rect(surface, palette["hex_core"],
                         core_rect.inflate(-8, -12), border_radius=6)

        # 테슬라 T 로고
        t_cx, t_cy = core_rect.centerx, core_rect.centery
        t_color = palette["hex_base"]
        pygame.draw.line(surface, t_color,
                         (t_cx - 8, t_cy - 10), (t_cx + 8, t_cy - 10), 4)
        pygame.draw.line(surface, t_color,
                         (t_cx, t_cy - 10), (t_cx, t_cy + 12), 4)

        # 코어 에너지 펄스
        pulse_alpha = int(80 + 40 * math.sin(phase * math.tau * 3))
        core_pulse_surf = pygame.Surface((50, 66), pygame.SRCALPHA)
        pygame.draw.rect(core_pulse_surf, (*palette["hex_core"], pulse_alpha),
                         (0, 0, 50, 66), border_radius=10)
        surface.blit(core_pulse_surf, (core_rect.left - 7, core_rect.top - 7),
                     special_flags=pygame.BLEND_RGBA_ADD)

        # 코어 상하 배기구
        for vent_y in (core_rect.top - 6, core_rect.bottom + 2):
            pygame.draw.rect(surface, palette["grip"],
                             (cx - 12, vent_y, 24, 4), border_radius=2)
            for vx in range(-8, 10, 6):
                pygame.draw.line(surface, palette["accent"],
                                 (cx + vx, vent_y), (cx + vx, vent_y + 4), 1)

        # ── 어깨 패드 (양쪽) ──
        for side in (-1, 1):
            pad_rect = pygame.Rect(0, 0, 52, 28)
            pad_rect.center = (cx + side * 60, shoulder_y)
            pygame.draw.rect(surface, palette["helmet"], pad_rect, border_radius=12)
            pygame.draw.rect(surface, palette["accent"], pad_rect, 4, border_radius=12)
            # 내부 라인
            inner_pad = pad_rect.inflate(-16, -10)
            pygame.draw.rect(surface, palette["hex_base"], inner_pad, border_radius=6)
            pygame.draw.line(surface, palette["accent"],
                             (inner_pad.left + 4, inner_pad.centery),
                             (inner_pad.right - 4, inner_pad.centery), 2)
            # LED 인디케이터
            led_x = pad_rect.centerx + side * 12
            pygame.draw.circle(surface, palette["hex_core"],
                               (led_x, pad_rect.centery), 4)
            pygame.draw.circle(surface, palette["visor_highlight"],
                               (led_x, pad_rect.centery), 2)
