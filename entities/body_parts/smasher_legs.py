"""
SmasherLegsPart — 스매셔 양다리 (골반+허벅지+무릎패드+종아리) 파츠.
Visual Polish: 3단 레이어링 + 무릎 LED + 패널라인/리벳
"""

import math
import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton, ORDER_LEGS, SLOT_LEGS,
)
from typing import Optional


class SmasherLegsPart(BodyPart):

    def __init__(self, block: int = 9):
        super().__init__(slot=SLOT_LEGS, draw_order=ORDER_LEGS,
                         joint_a="hip", joint_b=None)
        self.block = block

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        cx, hip_y = joint_a.world_int()

        # 다리 관절 탐색
        l_hip = r_hip = None
        for child in joint_a.children:
            if child.name == "l_hip":
                l_hip = child
            elif child.name == "r_hip":
                r_hip = child

        # ── 골반: 3단 ──
        pelvis = pygame.Rect(cx - int(1.5 * b), hip_y + int(0.7 * b) - int(0.4 * b),
                            int(3.0 * b), int(1.0 * b))
        pygame.draw.rect(surface, (40, 50, 80), pelvis.move(0, 1), border_radius=3)
        pygame.draw.rect(surface, palette["armor_mid"], pelvis, border_radius=3)
        pygame.draw.rect(surface, palette["trim"], pelvis, 1, border_radius=3)
        # 골반 중앙 패널라인
        pygame.draw.line(surface, (45, 55, 85),
                        (cx, pelvis.top + 2), (cx, pelvis.bottom - 2), 1)
        # 골반 리벳
        for rx in [pelvis.left + 3, pelvis.right - 3]:
            pygame.draw.circle(surface, palette["trim"], (rx, pelvis.centery), 1)

        thigh_height = int(2.2 * b)
        thigh_width = int(0.9 * b)

        pulse = 0.5 + 0.5 * math.sin(phase * math.tau * 2)

        for side_name, hip_joint, x_offset, phase_off in [
            ("left", l_hip, -int(1.2 * b) - thigh_width, 0),
            ("right", r_hip, int(0.25 * b), math.pi),
        ]:
            leg_y_offset = 0
            if hip_joint:
                _, jhy = hip_joint.world_int()
                leg_y_offset = jhy - (hip_y + int(0.7 * b))

            thigh_y = hip_y + int(0.7 * b) + leg_y_offset
            tr = pygame.Rect(cx + x_offset, thigh_y, thigh_width, thigh_height)

            # ── 허벅지: 3단 ──
            pygame.draw.rect(surface, (16, 18, 30), tr.move(0, 1), border_radius=3)  # 그림자
            pygame.draw.rect(surface, palette["undersuit"], tr, border_radius=3)
            pygame.draw.rect(surface, palette["undersuit_dark"], tr.inflate(-2, -2), border_radius=3)
            # 근육 패널라인
            pygame.draw.line(surface, (30, 34, 50),
                           (tr.centerx, tr.top + 3),
                           (tr.centerx, tr.bottom - 3), 1)

            # ── 무릎패드: 3단 + LED ──
            kp = pygame.Rect(tr.left - 2, tr.top + int(1.2 * b),
                            thigh_width + 4, int(0.8 * b))
            pygame.draw.rect(surface, (65, 80, 120), kp.move(0, 1), border_radius=2)  # 그림자
            pygame.draw.rect(surface, palette["knee"], kp, border_radius=2)
            # 하이라이트 상단
            pygame.draw.line(surface, palette["trim"],
                           (kp.left + 1, kp.top + 1),
                           (kp.right - 1, kp.top + 1), 1)
            # 패널라인
            pygame.draw.line(surface, palette["trim"],
                           (kp.left + 1, kp.centery),
                           (kp.right - 1, kp.centery), 1)

            # 무릎 LED 블룸 (HP 연동 — 에너지 코어와 동기화)
            _leg_energy = getattr(
                getattr(self, '_skin_ref', None), '_vfx_energy_core', None
            )
            if _leg_energy:
                _led_speed = _leg_energy.get_pulse_speed()
                led_color = _leg_energy.get_core_color(palette.get("accent", (118, 214, 255)))
            else:
                _led_speed = 3.0
                led_color = palette.get("accent", (118, 214, 255))
            led_pulse = 0.5 + 0.5 * math.sin(phase * math.tau * _led_speed + phase_off)
            led_cx, led_cy = kp.centerx, kp.centery
            glow_size = max(6, int(b * 0.5))
            glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*led_color, int(30 * led_pulse)),
                             (glow_size, glow_size), glow_size)
            surface.blit(glow_surf,
                        (led_cx - glow_size, led_cy - glow_size),
                        special_flags=pygame.BLEND_RGBA_ADD)
            pygame.draw.circle(surface, led_color, (led_cx, led_cy), max(1, int(b * 0.15)))

            # ── 종아리(부츠): 3단 ──
            calf_h = int(1.1 * b)
            cr = pygame.Rect(tr.left - 2, tr.bottom - 4, tr.width + 4, calf_h)
            pygame.draw.rect(surface, (40, 48, 72), cr.move(0, 1), border_radius=2)  # 그림자
            pygame.draw.rect(surface, palette["boot"], cr, border_radius=2)
            # 하이라이트
            pygame.draw.line(surface, palette["boot_high"],
                           (cr.left + 2, cr.top + 1),
                           (cr.right - 2, cr.top + 1), 1)
            # 리벳 (상/하)
            pygame.draw.circle(surface, palette.get("trim", (190, 206, 236)),
                             (cr.centerx, cr.top + 2), 1)
            pygame.draw.circle(surface, palette.get("trim", (190, 206, 236)),
                             (cr.centerx, cr.bottom - 2), 1)

            if side_name == "left":
                self._last_left_calf = cr
            else:
                self._last_right_calf = cr

        self._last_pelvis = pelvis
