"""
패시브 아이템 연동 팔 파츠 — 코만도암, 골드디거, 독안개장갑.

각 파츠는 좌/우 팔 버전이 있어서, 양팔 동시 착용이 가능하다.
- 첫 번째 획득 → l_arm 슬롯
- 두 번째 획득 → r_arm 슬롯
"""

import math
import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton,
    ORDER_L_ARM, ORDER_R_ARM, SLOT_L_ARM, SLOT_R_ARM,
)
from typing import Optional


# ─────────────────────────────────────────────
#  코만도암 (Commando Arm)
# ─────────────────────────────────────────────

class _CommandoArmBase(BodyPart):
    """코만도암 공통 렌더링. side로 좌/우 구분."""

    def __init__(self, slot: str, draw_order: int,
                 joint_a: str, joint_b: str, elbow_name: str,
                 block: int = 9):
        super().__init__(slot=slot, draw_order=draw_order,
                         joint_a=joint_a, joint_b=joint_b)
        self.block = block
        self._elbow_name = elbow_name

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        shoulder = joint_a.world_int()

        elbow_joint = None
        for child in joint_a.children:
            if child.name == self._elbow_name:
                elbow_joint = child
                break
        if elbow_joint is None:
            return

        elbow = elbow_joint.world_int()
        wrist = joint_b.world_int() if joint_b else elbow

        # ── 상완 (두꺼운 장갑판) ──
        pygame.draw.line(surface, (50, 55, 60), shoulder, elbow, b + 2)
        pygame.draw.line(surface, (70, 75, 80), shoulder, elbow, b)
        pygame.draw.line(surface, (90, 95, 100), shoulder, elbow, b - 3)

        # ── 전완 (유압 실린더) ──
        pygame.draw.line(surface, (50, 55, 60), elbow, wrist, b)
        pygame.draw.line(surface, (80, 85, 90), elbow, wrist, b - 2)

        # 유압 라인
        dx = wrist[0] - elbow[0]
        dy = wrist[1] - elbow[1]
        length = max(1, math.sqrt(dx * dx + dy * dy))
        nx = -dy / length * 2
        ny = dx / length * 2
        pygame.draw.line(
            surface, (100, 40, 40),
            (int(elbow[0] + nx), int(elbow[1] + ny)),
            (int(wrist[0] + nx), int(wrist[1] + ny)), 1,
        )

        # ── 관절 리벳 ──
        pygame.draw.circle(surface, (100, 105, 110), elbow, max(3, b // 2))
        pygame.draw.circle(surface, (60, 65, 70), elbow, max(2, b // 3))

        # ── LED ──
        led_pulse = int(40 * math.sin(phase * math.tau * 3))
        led_color = (min(255, 200 + led_pulse), 50, 40)
        pygame.draw.circle(surface, led_color, elbow, 2)

        # ── 강화 주먹 ──
        fist_r = max(3, b // 2 + 2)
        pygame.draw.circle(surface, (60, 65, 70), wrist, fist_r)
        pygame.draw.circle(surface, (80, 85, 90), wrist, fist_r - 1)
        pygame.draw.arc(
            surface, (100, 105, 110),
            (wrist[0] - fist_r, wrist[1] - fist_r, fist_r * 2, fist_r * 2),
            math.radians(180), math.radians(360), 2,
        )


class CommandoArmPart(_CommandoArmBase):
    """코만도암 — 왼팔 (l_arm)."""
    def __init__(self, block: int = 9):
        super().__init__(SLOT_L_ARM, ORDER_L_ARM,
                         "l_shoulder", "l_wrist", "l_elbow", block)


class CommandoArmRightPart(_CommandoArmBase):
    """코만도암 — 오른팔 (r_arm)."""
    def __init__(self, block: int = 9):
        super().__init__(SLOT_R_ARM, ORDER_R_ARM,
                         "r_shoulder", "r_wrist", "r_elbow", block)


# ─────────────────────────────────────────────
#  골드디거 (Gold Digger)
# ─────────────────────────────────────────────

class _GoldDiggerArmBase(BodyPart):
    """골드디거 공통 렌더링. side로 좌/우 구분."""

    def __init__(self, slot: str, draw_order: int,
                 joint_a: str, joint_b: str, elbow_name: str,
                 block: int = 9):
        super().__init__(slot=slot, draw_order=draw_order,
                         joint_a=joint_a, joint_b=joint_b)
        self.block = block
        self._elbow_name = elbow_name

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        shoulder = joint_a.world_int()

        elbow_joint = None
        for child in joint_a.children:
            if child.name == self._elbow_name:
                elbow_joint = child
                break
        if elbow_joint is None:
            return

        elbow = elbow_joint.world_int()
        wrist = joint_b.world_int() if joint_b else elbow

        # ── 상완 + 골드 트림 ──
        pygame.draw.line(surface, palette.get("arm_light", (132, 152, 204)), shoulder, elbow, b)
        pygame.draw.line(surface, palette.get("armor_mid", (60, 76, 120)), shoulder, elbow, b - 2)
        pygame.draw.line(surface, (200, 170, 50), shoulder, elbow, 1)

        # ── 전완 (골드 장갑) ──
        pygame.draw.line(surface, (180, 150, 40), elbow, wrist, b)
        pygame.draw.line(surface, (220, 190, 60), elbow, wrist, b - 2)

        # ── 황금 글러브 ──
        glove_r = max(3, b // 2 + 2)
        pygame.draw.circle(surface, (200, 170, 50), wrist, glove_r)
        pygame.draw.circle(surface, (240, 210, 80), wrist, glove_r - 1)

        # 클로 (3개)
        for i in range(3):
            claw_angle = math.radians(-120 + i * 40)
            cx = wrist[0] + int(math.cos(claw_angle) * (glove_r + 2))
            cy = wrist[1] + int(math.sin(claw_angle) * (glove_r + 2))
            tip_x = wrist[0] + int(math.cos(claw_angle) * (glove_r + int(0.6 * b)))
            tip_y = wrist[1] + int(math.sin(claw_angle) * (glove_r + int(0.6 * b)))
            pygame.draw.line(surface, (255, 230, 100), (cx, cy), (tip_x, tip_y), 2)

        # ── 골드 파티클 ──
        sparkle_surf = pygame.Surface((b * 4, b * 4), pygame.SRCALPHA)
        scx, scy = b * 2, b * 2
        for i in range(3):
            angle = phase * math.tau * 2 + i * math.tau / 3
            dist = int(b * 0.8 + b * 0.3 * math.sin(phase * math.tau * 4 + i))
            sx = scx + int(math.cos(angle) * dist)
            sy = scy + int(math.sin(angle) * dist)
            alpha = int(120 + 80 * math.sin(phase * math.tau * 3 + i * 2))
            pygame.draw.circle(sparkle_surf, (255, 230, 100, alpha), (sx, sy), 2)
        surface.blit(sparkle_surf, (wrist[0] - scx, wrist[1] - scy),
                     special_flags=pygame.BLEND_RGBA_ADD)


class GoldDiggerArmPart(_GoldDiggerArmBase):
    """골드디거 — 왼팔 (l_arm)."""
    def __init__(self, block: int = 9):
        super().__init__(SLOT_L_ARM, ORDER_L_ARM,
                         "l_shoulder", "l_wrist", "l_elbow", block)


class GoldDiggerArmRightPart(_GoldDiggerArmBase):
    """골드디거 — 오른팔 (r_arm)."""
    def __init__(self, block: int = 9):
        super().__init__(SLOT_R_ARM, ORDER_R_ARM,
                         "r_shoulder", "r_wrist", "r_elbow", block)


# ─────────────────────────────────────────────
#  독안개장갑 (Venom Mist Gauntlet)
# ─────────────────────────────────────────────

class _VenomMistGauntletBase(BodyPart):
    """독안개장갑 공통 렌더링. 독기가 흐르는 보라색 장갑."""

    def __init__(self, slot: str, draw_order: int,
                 joint_a: str, joint_b: str, elbow_name: str,
                 block: int = 9):
        super().__init__(slot=slot, draw_order=draw_order,
                         joint_a=joint_a, joint_b=joint_b)
        self.block = block
        self._elbow_name = elbow_name

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        b = self.block
        shoulder = joint_a.world_int()

        elbow_joint = None
        for child in joint_a.children:
            if child.name == self._elbow_name:
                elbow_joint = child
                break
        if elbow_joint is None:
            return

        elbow = elbow_joint.world_int()
        wrist = joint_b.world_int() if joint_b else elbow

        # ── 상완 (어두운 보라색 장갑판) ──
        pygame.draw.line(surface, (40, 20, 50), shoulder, elbow, b + 2)
        pygame.draw.line(surface, (60, 30, 80), shoulder, elbow, b)
        pygame.draw.line(surface, (80, 40, 100), shoulder, elbow, b - 3)

        # ── 전완 (독기 순환 라인) ──
        pygame.draw.line(surface, (50, 25, 60), elbow, wrist, b)
        pygame.draw.line(surface, (70, 35, 90), elbow, wrist, b - 2)

        # 독기 순환 라인 (맥동하는 녹색)
        dx = wrist[0] - elbow[0]
        dy = wrist[1] - elbow[1]
        length = max(1, math.sqrt(dx * dx + dy * dy))
        nx = -dy / length * 2
        ny = dx / length * 2
        venom_pulse = int(40 * math.sin(phase * math.tau * 2))
        venom_color = (40 + venom_pulse, min(255, 180 + venom_pulse), 40)
        pygame.draw.line(
            surface, venom_color,
            (int(elbow[0] + nx), int(elbow[1] + ny)),
            (int(wrist[0] + nx), int(wrist[1] + ny)), 1,
        )

        # ── 관절 (독기 주입구) ──
        pygame.draw.circle(surface, (80, 50, 100), elbow, max(3, b // 2))
        glow_g = int(160 + 60 * math.sin(phase * math.tau * 3))
        pygame.draw.circle(surface, (40, glow_g, 40), elbow, max(2, b // 3))

        # ── 독안개 글러브 ──
        fist_r = max(3, b // 2 + 2)
        pygame.draw.circle(surface, (50, 30, 65), wrist, fist_r)
        pygame.draw.circle(surface, (70, 40, 90), wrist, fist_r - 1)

        # 독기 이펙트 (손 주변 미스트)
        mist_surf = pygame.Surface((b * 4, b * 4), pygame.SRCALPHA)
        mcx, mcy = b * 2, b * 2
        for i in range(4):
            angle = phase * math.tau * 1.5 + i * math.tau / 4
            dist = int(b * 0.6 + b * 0.3 * math.sin(phase * math.tau * 2 + i))
            mx = mcx + int(math.cos(angle) * dist)
            my = mcy + int(math.sin(angle) * dist)
            alpha = int(60 + 40 * math.sin(phase * math.tau * 2.5 + i * 1.5))
            pygame.draw.circle(mist_surf, (80, 200, 80, alpha), (mx, my), 3)
        surface.blit(mist_surf, (wrist[0] - mcx, wrist[1] - mcy),
                     special_flags=pygame.BLEND_RGBA_ADD)


class VenomMistGauntletPart(_VenomMistGauntletBase):
    """독안개장갑 — 왼팔 (l_arm)."""
    def __init__(self, block: int = 9):
        super().__init__(SLOT_L_ARM, ORDER_L_ARM,
                         "l_shoulder", "l_wrist", "l_elbow", block)


class VenomMistGauntletRightPart(_VenomMistGauntletBase):
    """독안개장갑 — 오른팔 (r_arm)."""
    def __init__(self, block: int = 9):
        super().__init__(SLOT_R_ARM, ORDER_R_ARM,
                         "r_shoulder", "r_wrist", "r_elbow", block)
