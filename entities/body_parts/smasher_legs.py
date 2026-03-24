"""
SmasherLegsPart — 스매셔 양다리 (골반+허벅지+무릎패드+종아리) 파츠.

원본: pingfighter.py create_smasher_paddle_surface() 29912~29947줄
관절 바인딩: hip (루트) — 다리 전체를 hip 기준으로 그림
"""

import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton,
    ORDER_LEGS, SLOT_LEGS,
)
from typing import Optional


class SmasherLegsPart(BodyPart):
    """스매셔 메카 양다리.

    hip 관절을 기준으로 골반, 좌/우 허벅지, 무릎 패드, 종아리를 그린다.
    개별 다리 관절(l_hip, l_knee 등)의 월드 좌표를 사용하여
    다리 위치와 걷기 모션을 반영한다.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_LEGS,
            draw_order=ORDER_LEGS,
            joint_a="hip",
            joint_b=None,
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, hip_y = joint_a.world_int()

        # 뼈대에서 다리 관절 좌표 가져오기
        l_hip = l_knee = l_ankle = None
        r_hip = r_knee = r_ankle = None
        for child in joint_a.children:
            if child.name == "l_hip":
                l_hip = child
                for gc in child.children:
                    if gc.name == "l_knee":
                        l_knee = gc
                        for ggc in gc.children:
                            if ggc.name == "l_ankle":
                                l_ankle = ggc
            elif child.name == "r_hip":
                r_hip = child
                for gc in child.children:
                    if gc.name == "r_knee":
                        r_knee = gc
                        for ggc in gc.children:
                            if ggc.name == "r_ankle":
                                r_ankle = ggc

        # ── 골반 ──
        pelvis = pygame.Rect(
            cx - int(1.5 * b), hip_y + int(0.7 * b) - int(0.4 * b),
            int(3.0 * b), int(1.0 * b),
        )
        pygame.draw.rect(surface, palette["armor_mid"], pelvis, border_radius=3)
        pygame.draw.rect(surface, palette["trim"], pelvis, 1, border_radius=3)

        # ── 양 허벅지 / 무릎 / 종아리 ──
        thigh_height = int(2.2 * b)
        thigh_width = int(0.9 * b)

        for side, hip_joint, knee_joint, ankle_joint, x_offset in [
            ("left", l_hip, l_knee, l_ankle, -int(1.2 * b) - thigh_width),
            ("right", r_hip, r_knee, r_ankle, int(0.25 * b)),
        ]:
            # 다리 Y 오프셋 (관절이 있으면 사용, 없으면 기본)
            leg_y_offset = 0
            if hip_joint:
                _, jhy = hip_joint.world_int()
                leg_y_offset = jhy - (hip_y + int(0.7 * b))

            thigh_y = hip_y + int(0.7 * b) + leg_y_offset
            thigh_rect = pygame.Rect(cx + x_offset, thigh_y, thigh_width, thigh_height)

            # 허벅지
            pygame.draw.rect(surface, palette["undersuit"], thigh_rect, border_radius=3)
            pygame.draw.rect(
                surface, palette["undersuit_dark"],
                thigh_rect.inflate(-2, -2), border_radius=3,
            )

            # 무릎 패드
            knee_pad = pygame.Rect(
                thigh_rect.left - 2,
                thigh_rect.top + int(1.2 * b),
                thigh_width + 4, int(0.8 * b),
            )
            pygame.draw.rect(surface, palette["knee"], knee_pad, border_radius=2)
            pygame.draw.line(
                surface, palette["trim"],
                (knee_pad.left + 1, knee_pad.centery),
                (knee_pad.right - 1, knee_pad.centery), 1,
            )

            # 종아리 (부츠)
            calf_height = int(1.1 * b)
            calf_rect = pygame.Rect(
                thigh_rect.left - 2, thigh_rect.bottom - 4,
                thigh_rect.width + 4, calf_height,
            )
            pygame.draw.rect(surface, palette["boot"], calf_rect, border_radius=2)
            pygame.draw.line(
                surface, palette["boot_high"],
                (calf_rect.left + 2, calf_rect.centery - 1),
                (calf_rect.right - 2, calf_rect.centery - 1), 1,
            )

            # 외곽선용으로 마지막 종아리 위치 저장
            if side == "left":
                self._last_left_calf = calf_rect
            else:
                self._last_right_calf = calf_rect

        self._last_pelvis = pelvis
