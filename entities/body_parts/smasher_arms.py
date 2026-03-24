"""
SmasherLeftArmPart / SmasherRightArmPart — 스매셔 양팔 + 글러브 파츠.

원본: pingfighter.py create_smasher_paddle_surface() 29729~29840줄
왼팔은 탁구채(weapon) 쪽, 오른팔은 방패(shield) 쪽.
팔 관절의 월드 좌표를 사용하여 상완-전완-글러브를 그린다.
"""

import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton,
    ORDER_L_ARM, ORDER_R_ARM, SLOT_L_ARM, SLOT_R_ARM,
)
from typing import Optional


class SmasherLeftArmPart(BodyPart):
    """스매셔 왼팔 (탁구채 쪽): shoulder → elbow → wrist + 글러브.

    뼈대 시스템에서는 모션에 의해 관절 각도가 이미 결정되어 있으므로,
    단순히 관절 좌표를 연결하여 팔을 그린다.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_L_ARM,
            draw_order=ORDER_L_ARM,
            joint_a="l_shoulder",
            joint_b="l_wrist",
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        skeleton = None  # joint_a에서 sibling 접근 불가 → 직접 elbow 참조 필요

        # 관절 좌표 가져오기 (shoulder → elbow → wrist)
        shoulder = joint_a.world_int()

        # elbow는 l_shoulder의 자식 중 l_elbow
        elbow_joint = None
        for child in joint_a.children:
            if child.name == "l_elbow":
                elbow_joint = child
                break

        if elbow_joint is None:
            return

        elbow = elbow_joint.world_int()
        wrist = joint_b.world_int() if joint_b else elbow

        # ── 상완 (shoulder → elbow) ──
        pygame.draw.line(surface, palette["arm_light"], shoulder, elbow, b)
        pygame.draw.line(surface, palette["armor_mid"], shoulder, elbow, b - 2)

        # ── 전완 (elbow → wrist) ──
        pygame.draw.line(surface, palette["arm_light"], elbow, wrist, b - 1)
        pygame.draw.line(surface, palette["armor_mid"], elbow, wrist, b - 3)

        # ── 글러브 ──
        pygame.draw.circle(surface, palette["glove"], wrist, max(2, b // 2 + 1))
        pygame.draw.line(
            surface, palette["glove_detail"],
            (wrist[0] - 2, wrist[1] - 1),
            (wrist[0] + 2, wrist[1] + 2), 1,
        )


class SmasherRightArmPart(BodyPart):
    """스매셔 오른팔 (방패 쪽): shoulder → elbow → wrist + 글러브."""

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_R_ARM,
            draw_order=ORDER_R_ARM,
            joint_a="r_shoulder",
            joint_b="r_wrist",
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        shoulder = joint_a.world_int()

        # elbow 찾기
        elbow_joint = None
        for child in joint_a.children:
            if child.name == "r_elbow":
                elbow_joint = child
                break

        if elbow_joint is None:
            return

        elbow = elbow_joint.world_int()
        wrist = joint_b.world_int() if joint_b else elbow

        # ── 상완 ──
        pygame.draw.line(surface, palette["arm_light"], shoulder, elbow, b)
        pygame.draw.line(surface, palette["armor_mid"], shoulder, elbow, b - 2)

        # ── 전완 ──
        pygame.draw.line(surface, palette["arm_light"], elbow, wrist, b - 1)
        pygame.draw.line(surface, palette["armor_mid"], elbow, wrist, b - 3)

        # ── 글러브 ──
        pygame.draw.circle(surface, palette["glove"], wrist, max(2, b // 2 + 1))
        pygame.draw.line(
            surface, palette["glove_detail"],
            (wrist[0] - 2, wrist[1]),
            (wrist[0] + 2, wrist[1] + 2), 1,
        )
