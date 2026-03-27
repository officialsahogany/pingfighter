"""
OptimusLegsPart — 옵티머스 양다리 (LED 관절 + 아머 플레이트 + 추진기 노즐).
원본: pingfighter.py _create_mecha_paddle_surface() 라인 28851~28910
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_LEGS, SLOT_LEGS
from typing import Optional

# 발 바닥 고정 Y 좌표 (base_cy + 120 = 696, torso_bob 미적용)
OPTIMUS_FOOT_BASE_Y = 696


class OptimusLegsPart(BodyPart):

    def __init__(self):
        super().__init__(slot=SLOT_LEGS, draw_order=ORDER_LEGS,
                         joint_a="hip", joint_b=None)

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        cx, hip_y = joint_a.world_int()

        stride = math.sin(phase * math.tau)
        foot_base_y = OPTIMUS_FOOT_BASE_Y

        def draw_leg(side: int, leg_stride: float) -> tuple:
            """LED 강조 다리 관절 애니메이션 (고해상도)."""
            hip = (cx + side * 36, hip_y)
            foot_x = cx + side * 44 + int(leg_stride * 12)
            foot_y = foot_base_y
            knee_x = int((hip[0] * 0.55 + foot_x * 0.45)
                         + side * 8 - leg_stride * 6)
            knee_y = int((hip[1] * 0.55 + foot_y * 0.45) + 4)
            knee = (knee_x, knee_y)
            foot = (foot_x, foot_y)

            # 다리 세그먼트
            pygame.draw.line(surface, palette["body"], hip, knee, 24)
            pygame.draw.line(surface, palette["body"], knee, foot, 24)
            pygame.draw.line(surface, palette["line"], hip, knee, 6)
            pygame.draw.line(surface, palette["line"], knee, foot, 6)

            # 다리 아머 플레이트
            mid_upper = ((hip[0] + knee[0]) // 2, (hip[1] + knee[1]) // 2)
            mid_lower = ((knee[0] + foot[0]) // 2, (knee[1] + foot[1]) // 2)
            pygame.draw.circle(surface, palette["helmet"], mid_upper, 10)
            pygame.draw.circle(surface, palette["accent"], mid_upper, 6, 2)
            pygame.draw.circle(surface, palette["helmet"], mid_lower, 8)
            pygame.draw.circle(surface, palette["accent"], mid_lower, 5, 2)

            # LED 관절
            for joint in (hip, knee, foot):
                pygame.draw.circle(surface, palette["hex_base"], joint, 14)
                pygame.draw.circle(surface, palette["accent"], joint, 8)
                pygame.draw.circle(surface, palette["hex_core"], joint, 5)
                pygame.draw.circle(surface, palette["visor_highlight"], joint, 3)

            # 발
            foot_rect = pygame.Rect(0, 0, 52, 24)
            foot_rect.center = (foot_x, foot_y + 12)
            pygame.draw.rect(surface, palette["grip"], foot_rect, border_radius=8)
            pygame.draw.rect(surface, palette["grip_line"],
                             foot_rect.inflate(-12, -4), 2, border_radius=6)

            # 발바닥 추진기 노즐
            nozzle_x = foot_x
            nozzle_y = foot_y + 20
            pygame.draw.ellipse(surface, palette["hex_base"],
                                (nozzle_x - 12, nozzle_y, 24, 8))
            pygame.draw.ellipse(surface, palette["accent"],
                                (nozzle_x - 8, nozzle_y + 2, 16, 4))
            # 추진기 발광
            thruster_glow = pygame.Surface((32, 16), pygame.SRCALPHA)
            glow_alpha = int(40 + 30 * math.sin(phase * math.tau * 2 + side))
            pygame.draw.ellipse(thruster_glow,
                                (*palette["accent"], glow_alpha), (0, 0, 32, 16))
            surface.blit(thruster_glow, (nozzle_x - 16, nozzle_y + 4))

            return hip

        draw_leg(-1, stride)
        draw_leg(1, -stride)

        # 하체 외곽 광택
        sprite_w = surface.get_width()
        sprite_h = surface.get_height()
        leg_glow = pygame.Surface((sprite_w, sprite_h), pygame.SRCALPHA)
        pygame.draw.ellipse(
            leg_glow,
            (*palette["glow"], 55),
            (cx - 140, foot_base_y - 60, 280, 36),
            4,
        )
        surface.blit(leg_glow, (0, 0))
