"""
패시브 아이템 연동 팔 파츠 — 코만도암, 골드디거.
"""

import math
import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton,
    ORDER_L_ARM, SLOT_L_ARM,
)
from typing import Optional


class CommandoArmPart(BodyPart):
    """코만도암 (commando_arm).

    군용 기계팔: 다크 메탈 장갑판 + 붉은 LED + 유압 실린더.
    효과: 공 타격 시 추가 데미지.
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
        shoulder = joint_a.world_int()

        elbow_joint = None
        for child in joint_a.children:
            if child.name == "l_elbow":
                elbow_joint = child
                break
        if elbow_joint is None:
            return

        elbow = elbow_joint.world_int()
        wrist = joint_b.world_int() if joint_b else elbow

        # ── 상완 (두꺼운 장갑판) ──
        pygame.draw.line(surface, (50, 55, 60), shoulder, elbow, b + 2)     # 외곽
        pygame.draw.line(surface, (70, 75, 80), shoulder, elbow, b)          # 내부
        pygame.draw.line(surface, (90, 95, 100), shoulder, elbow, b - 3)     # 하이라이트

        # ── 전완 (유압 실린더 느낌) ──
        pygame.draw.line(surface, (50, 55, 60), elbow, wrist, b)
        pygame.draw.line(surface, (80, 85, 90), elbow, wrist, b - 2)

        # 유압 라인 (평행선)
        dx = wrist[0] - elbow[0]
        dy = wrist[1] - elbow[1]
        length = max(1, math.sqrt(dx * dx + dy * dy))
        nx = -dy / length * 2  # 법선 벡터
        ny = dx / length * 2
        pygame.draw.line(
            surface, (100, 40, 40),
            (int(elbow[0] + nx), int(elbow[1] + ny)),
            (int(wrist[0] + nx), int(wrist[1] + ny)), 1,
        )

        # ── 관절 리벳 ──
        pygame.draw.circle(surface, (100, 105, 110), elbow, max(3, b // 2))
        pygame.draw.circle(surface, (60, 65, 70), elbow, max(2, b // 3))

        # ── LED 포인트 (팔꿈치) ──
        led_pulse = int(40 * math.sin(phase * math.tau * 3))
        led_color = (min(255, 200 + led_pulse), 50, 40)
        pygame.draw.circle(surface, led_color, elbow, 2)

        # ── 글러브 (강화 주먹) ──
        fist_r = max(3, b // 2 + 2)
        pygame.draw.circle(surface, (60, 65, 70), wrist, fist_r)
        pygame.draw.circle(surface, (80, 85, 90), wrist, fist_r - 1)
        # 너클 가드
        pygame.draw.arc(
            surface, (100, 105, 110),
            (wrist[0] - fist_r, wrist[1] - fist_r, fist_r * 2, fist_r * 2),
            math.radians(180), math.radians(360), 2,
        )


class GoldDiggerArmPart(BodyPart):
    """골드디거 (gold_digger).

    황금 채굴 장갑 + 빛나는 손톱 + 골드 파티클.
    효과: 골드 획득량 증가.
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
        shoulder = joint_a.world_int()

        elbow_joint = None
        for child in joint_a.children:
            if child.name == "l_elbow":
                elbow_joint = child
                break
        if elbow_joint is None:
            return

        elbow = elbow_joint.world_int()
        wrist = joint_b.world_int() if joint_b else elbow

        # ── 상완 (기본 팔 + 골드 트림) ──
        pygame.draw.line(surface, palette.get("arm_light", (132, 152, 204)), shoulder, elbow, b)
        pygame.draw.line(surface, palette.get("armor_mid", (60, 76, 120)), shoulder, elbow, b - 2)
        # 골드 트림
        pygame.draw.line(surface, (200, 170, 50), shoulder, elbow, 1)

        # ── 전완 (골드 장갑) ──
        pygame.draw.line(surface, (180, 150, 40), elbow, wrist, b)
        pygame.draw.line(surface, (220, 190, 60), elbow, wrist, b - 2)

        # ── 황금 글러브 ──
        glove_r = max(3, b // 2 + 2)
        pygame.draw.circle(surface, (200, 170, 50), wrist, glove_r)
        pygame.draw.circle(surface, (240, 210, 80), wrist, glove_r - 1)

        # 손톱/클로 (3개)
        for i in range(3):
            claw_angle = math.radians(-120 + i * 40)
            cx = wrist[0] + int(math.cos(claw_angle) * (glove_r + 2))
            cy = wrist[1] + int(math.sin(claw_angle) * (glove_r + 2))
            tip_x = wrist[0] + int(math.cos(claw_angle) * (glove_r + int(0.6 * b)))
            tip_y = wrist[1] + int(math.sin(claw_angle) * (glove_r + int(0.6 * b)))
            pygame.draw.line(surface, (255, 230, 100), (cx, cy), (tip_x, tip_y), 2)

        # ── 빛나는 골드 파티클 (phase 기반) ──
        sparkle_surf = pygame.Surface((b * 4, b * 4), pygame.SRCALPHA)
        scx, scy = b * 2, b * 2
        num_sparkles = 3
        for i in range(num_sparkles):
            angle = phase * math.tau * 2 + i * math.tau / num_sparkles
            dist = int(b * 0.8 + b * 0.3 * math.sin(phase * math.tau * 4 + i))
            sx = scx + int(math.cos(angle) * dist)
            sy = scy + int(math.sin(angle) * dist)
            alpha = int(120 + 80 * math.sin(phase * math.tau * 3 + i * 2))
            pygame.draw.circle(sparkle_surf, (255, 230, 100, alpha), (sx, sy), 2)

        surface.blit(
            sparkle_surf,
            (wrist[0] - scx, wrist[1] - scy),
            special_flags=pygame.BLEND_RGBA_ADD,
        )
