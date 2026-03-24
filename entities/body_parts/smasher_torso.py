"""
SmasherTorsoPart — 스매셔 흉갑 + 복부 + 벨트 + 어깨갑 파츠.
Visual Polish: 3단 레이어링 + 에너지코어 블룸 + 리벳/패널라인
"""

import math
import pygame
from entities.player_skeleton import BodyPart, Joint, Skeleton, ORDER_TORSO, SLOT_TORSO
from typing import Optional


class SmasherTorsoPart(BodyPart):

    def __init__(self, block: int = 9):
        super().__init__(slot=SLOT_TORSO, draw_order=ORDER_TORSO,
                         joint_a="torso", joint_b="hip")
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, ty = joint_a.world_int()

        # ── 흉갑: 3단 레이어링 ──
        torso_width = int(3.4 * b)
        chest_height = int(2.2 * b)
        chest_rect = pygame.Rect(cx - torso_width // 2, ty - int(0.4 * b),
                                 torso_width, chest_height)

        # 그림자
        pygame.draw.rect(surface, (40, 50, 80), chest_rect.move(1, 2), border_radius=7)
        # 베이스
        pygame.draw.rect(surface, palette["armor_outer"], chest_rect, border_radius=7)
        # 중간 레이어
        mid_rect = chest_rect.inflate(-int(0.6 * b), -int(0.5 * b))
        pygame.draw.rect(surface, palette["armor_mid"], mid_rect, border_radius=6)
        # 내부 패널
        inner_panel = mid_rect.inflate(-int(0.7 * b), -int(0.45 * b))
        pygame.draw.rect(surface, palette["armor_inner"], inner_panel, border_radius=4)
        # 하이라이트 (상단 엣지)
        hl_rect = chest_rect.inflate(-int(0.3 * b), -int(0.3 * b))
        hl_rect.height = max(2, int(0.3 * b))
        pygame.draw.rect(surface, palette["trim"], hl_rect, border_radius=3)

        # 트림 테두리
        pygame.draw.rect(surface, palette["trim"], chest_rect, 1, border_radius=7)
        pygame.draw.rect(surface, palette["trim"], mid_rect, 1, border_radius=6)

        # 패널라인 (가로 3개)
        for i in range(3):
            py = inner_panel.top + int((i + 1) * inner_panel.height / 4)
            pygame.draw.line(surface, (35, 45, 70),
                           (inner_panel.left + 2, py),
                           (inner_panel.right - 2, py), 1)

        # ── 에너지 코어 + 블룸 (HP 연동) ──
        # VFX 에너지 코어 상태에서 색상/맥동 속도 가져오기
        _energy_core = getattr(self, '_skin_ref', None) and getattr(self._skin_ref, '_vfx_energy_core', None)
        if _energy_core:
            _pulse_speed = _energy_core.get_pulse_speed()
            _pulse_intensity = _energy_core.get_pulse_intensity()
            _base_core_color = _energy_core.get_core_color(palette.get("accent_core", (82, 178, 248)))
        else:
            _pulse_speed = 2.5
            _pulse_intensity = 0.4
            _base_core_color = palette.get("accent_core", (82, 178, 248))

        pulse = (1.0 - _pulse_intensity) + _pulse_intensity * math.sin(phase * math.tau * _pulse_speed)
        core_x = cx
        core_top = inner_panel.top + int(0.25 * b)
        core_bottom = inner_panel.bottom - int(0.25 * b)

        # 코어 라인 (HP 연동 색상 + 밝기 맥동)
        core_bright = int(200 + 55 * pulse)
        core_color = (
            min(255, int(_base_core_color[0] * pulse)),
            min(255, int(_base_core_color[1] * pulse)),
            min(255, int(_base_core_color[2] * pulse)),
        )
        pygame.draw.line(surface, core_color, (core_x, core_top), (core_x, core_bottom), 2)
        pygame.draw.line(surface, _base_core_color,
                        (core_x - int(0.5 * b), inner_panel.centery),
                        (core_x + int(0.5 * b), inner_panel.centery), 1)

        # 코어 블룸 (HP 연동 색상)
        glow_size = int(b * 1.2)
        glow_surf = pygame.Surface((glow_size * 2, inner_panel.height), pygame.SRCALPHA)
        glow_alpha = int(30 * pulse)
        pygame.draw.ellipse(glow_surf, (*_base_core_color, glow_alpha),
                           (0, 0, glow_size * 2, inner_panel.height))
        surface.blit(glow_surf,
                    (core_x - glow_size, inner_panel.top),
                    special_flags=pygame.BLEND_RGBA_ADD)

        # 코어 중심 도트
        dot_r = max(2, int(0.2 * b))
        _dot_color = (
            min(255, _base_core_color[0] + 80),
            min(255, _base_core_color[1] + 60),
            min(255, _base_core_color[2] + 10),
        )
        pygame.draw.circle(surface, _dot_color, (core_x, inner_panel.centery), dot_r)
        pygame.draw.circle(surface, (255, 255, 255), (core_x, inner_panel.centery), max(1, dot_r - 1))

        # ── 복부 패널 (3단) ──
        abs_width = int(2.4 * b)
        abs_height = int(1.4 * b)
        abs_rect = pygame.Rect(cx - abs_width // 2, inner_panel.bottom - int(0.2 * b),
                               abs_width, abs_height)
        pygame.draw.rect(surface, (28, 32, 48), abs_rect.move(0, 1), border_radius=3)  # 그림자
        pygame.draw.rect(surface, palette["undersuit"], abs_rect, border_radius=3)
        pygame.draw.rect(surface, palette["trim"], abs_rect, 1, border_radius=3)
        # 복부 세그먼트 라인
        pygame.draw.line(surface, palette["accent_core"],
                        (abs_rect.left + 2, abs_rect.centery),
                        (abs_rect.right - 2, abs_rect.centery), 1)

        # ── 벨트 (3단 + 버클 블룸) ──
        belt_rect = pygame.Rect(cx - int(2.0 * b), abs_rect.bottom - int(0.1 * b),
                               int(4.0 * b), int(0.8 * b))
        pygame.draw.rect(surface, (60, 50, 75), belt_rect.move(0, 1), border_radius=2)
        pygame.draw.rect(surface, palette["belt"], belt_rect, border_radius=2)
        pygame.draw.line(surface, palette["belt_glint"],
                        (belt_rect.left + 4, belt_rect.top + 1),
                        (belt_rect.right - 4, belt_rect.top + 1), 1)
        # 버클
        buckle_rect = pygame.Rect(cx - int(0.6 * b), belt_rect.top + 1,
                                  int(1.2 * b), belt_rect.height - 2)
        pygame.draw.rect(surface, palette["trim"], buckle_rect, border_radius=1)
        # 버클 블룸
        buckle_glow = pygame.Surface((int(1.6 * b), int(1.2 * b)), pygame.SRCALPHA)
        pygame.draw.ellipse(buckle_glow, (*palette["accent"], int(25 * pulse)),
                           buckle_glow.get_rect())
        surface.blit(buckle_glow,
                    (cx - int(0.8 * b), belt_rect.centery - int(0.6 * b)),
                    special_flags=pygame.BLEND_RGBA_ADD)

        # ── 어깨갑 (3단 + 리벳) ──
        for side in [-1, 1]:
            pauldron = [
                (cx + side * (int(2.2 * b) + 4), ty - int(0.5 * b)),
                (cx + side * int(1.2 * b), ty - int(0.9 * b)),
                (cx + side * int(0.9 * b), ty + int(0.8 * b)),
                (cx + side * (int(2.1 * b) + 3), ty + int(0.9 * b)),
            ]
            # 그림자
            shadow_p = [(x + side, y + 1) for x, y in pauldron]
            pygame.draw.polygon(surface, (35, 45, 70), shadow_p)
            # 베이스
            pygame.draw.polygon(surface, palette["armor_mid"], pauldron)
            # 하이라이트 엣지
            pygame.draw.line(surface, palette["trim"], pauldron[0], pauldron[1], 2)
            pygame.draw.line(surface, palette["arm_light"], pauldron[1], pauldron[2], 1)
            # 리벳 (4개 모서리)
            for pt in pauldron:
                pygame.draw.circle(surface, palette["trim"], (int(pt[0]), int(pt[1])), 1)

        self._last_chest_rect = chest_rect
        self._last_belt_rect = belt_rect
