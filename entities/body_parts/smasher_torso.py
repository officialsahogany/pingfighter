"""
SmasherTorsoPart — 스매셔 흉갑 + 복부 + 벨트 + 어깨갑 파츠.

원본: pingfighter.py create_smasher_paddle_surface() 29672~29727줄
관절 바인딩: torso → neck (흉갑), hip (벨트)
"""

import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_TORSO, SLOT_TORSO
from typing import Optional


class SmasherTorsoPart(BodyPart):
    """스매셔 메카 상체 갑옷.

    torso 관절 기준으로 흉갑, 에너지 코어 라인, 복부 패널,
    벨트, 좌/우 어깨갑(pauldron)을 그린다.
    """

    def __init__(self, block: int = 9):
        super().__init__(
            slot=SLOT_TORSO,
            draw_order=ORDER_TORSO,
            joint_a="torso",
            joint_b="hip",
        )
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, ty = joint_a.world_int()    # torso 관절 (흉부 중심)

        # hip 관절에서 shoulder_shift 계산
        # (원본에서는 wave 기반이지만 뼈대 시스템에서는
        #  l_shoulder/r_shoulder 관절 위치로 대체 가능.
        #  현재는 호환성을 위해 hip 관절 위치 기반으로 추정)

        # ── 흉갑 (chest plate) ──
        torso_width = int(3.4 * b)
        chest_height = int(2.2 * b)
        chest_rect = pygame.Rect(
            cx - torso_width // 2,
            ty - int(0.4 * b),
            torso_width, chest_height,
        )
        pygame.draw.rect(surface, palette["armor_outer"], chest_rect, border_radius=7)

        # 중간 레이어
        mid_rect = chest_rect.inflate(-int(0.6 * b), -int(0.5 * b))
        pygame.draw.rect(surface, palette["armor_mid"], mid_rect, border_radius=6)

        # 내부 패널
        inner_panel = mid_rect.inflate(-int(0.7 * b), -int(0.45 * b))
        pygame.draw.rect(surface, palette["armor_inner"], inner_panel, border_radius=4)

        # 트림(테두리)
        pygame.draw.rect(surface, palette["trim"], chest_rect, 1, border_radius=7)
        pygame.draw.rect(surface, palette["trim"], mid_rect, 1, border_radius=6)

        # ── 에너지 코어 라인 ──
        core_line_top = (cx, inner_panel.top + int(0.25 * b))
        core_line_bottom = (cx, inner_panel.bottom - int(0.25 * b))
        pygame.draw.line(surface, palette["accent"], core_line_top, core_line_bottom, 2)
        pygame.draw.line(
            surface, palette["accent_core"],
            (cx - int(0.5 * b), inner_panel.centery),
            (cx + int(0.5 * b), inner_panel.centery), 1,
        )

        # ── 복부 패널 (undersuit) ──
        abs_width = int(2.4 * b)
        abs_height = int(1.4 * b)
        abs_rect = pygame.Rect(
            cx - abs_width // 2,
            inner_panel.bottom - int(0.2 * b),
            abs_width, abs_height,
        )
        pygame.draw.rect(surface, palette["undersuit"], abs_rect, border_radius=3)
        pygame.draw.rect(surface, palette["trim"], abs_rect, 1, border_radius=3)
        pygame.draw.line(
            surface, palette["accent_core"],
            (abs_rect.left + 2, abs_rect.centery),
            (abs_rect.right - 2, abs_rect.centery), 1,
        )

        # ── 벨트 ──
        belt_rect = pygame.Rect(
            cx - int(2.0 * b),
            abs_rect.bottom - int(0.1 * b),
            int(4.0 * b), int(0.8 * b),
        )
        pygame.draw.rect(surface, palette["belt"], belt_rect, border_radius=2)
        pygame.draw.line(
            surface, palette["belt_glint"],
            (belt_rect.left + 4, belt_rect.centery - 1),
            (belt_rect.right - 4, belt_rect.centery - 1), 1,
        )
        # 버클
        buckle_rect = pygame.Rect(
            cx - int(0.6 * b), belt_rect.top + 1,
            int(1.2 * b), belt_rect.height - 2,
        )
        pygame.draw.rect(surface, palette["trim"], buckle_rect, border_radius=1)

        # ── 어깨갑 (pauldrons) ──
        # 왼쪽 어깨갑
        l_shoulder = surface.get_width() // 2  # 기본 center 기준
        left_pauldron = [
            (cx - int(2.2 * b) - 4, ty - int(0.5 * b)),
            (cx - int(1.2 * b), ty - int(0.9 * b)),
            (cx - int(0.9 * b), ty + int(0.8 * b)),
            (cx - int(2.1 * b) - 3, ty + int(0.9 * b)),
        ]
        pygame.draw.polygon(surface, palette["armor_mid"], left_pauldron)
        pygame.draw.line(surface, palette["trim"], left_pauldron[0], left_pauldron[1], 2)
        pygame.draw.line(surface, palette["arm_light"], left_pauldron[1], left_pauldron[2], 1)

        # 오른쪽 어깨갑
        right_pauldron = [
            (cx + int(2.2 * b) + 4, ty - int(0.5 * b)),
            (cx + int(1.2 * b), ty - int(0.9 * b)),
            (cx + int(0.9 * b), ty + int(0.8 * b)),
            (cx + int(2.1 * b) + 3, ty + int(0.9 * b)),
        ]
        pygame.draw.polygon(surface, palette["armor_mid"], right_pauldron)
        pygame.draw.line(surface, palette["trim"], right_pauldron[0], right_pauldron[1], 2)
        pygame.draw.line(surface, palette["arm_light"], right_pauldron[1], right_pauldron[2], 1)

        # 외곽선용으로 rect들 저장
        self._last_chest_rect = chest_rect
        self._last_belt_rect = belt_rect
