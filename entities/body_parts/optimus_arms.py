"""
OptimusLeftArmPart / OptimusRightArmPart — 옵티머스 양팔 + 손 + 팔꿈치 LED.
원본: pingfighter.py _create_mecha_paddle_surface() 내 draw_arm() 함수
라인 29063~29283 (일반 팔 렌더링 부분)

무기(패들)와 주먹(피스트)은 별도 파츠 파일에서 관리:
- optimus_weapon.py: 왼손 사이버 탁구채
- optimus_fist.py: 오른손 강철 전기 주먹
"""

import math
import pygame
from entities.player_skeleton import (
    BodyPart, Joint, Skeleton,
    ORDER_L_ARM, ORDER_R_ARM, SLOT_L_ARM, SLOT_R_ARM,
)
from typing import Optional


def _ease_out_cubic(t: float) -> float:
    t = max(0.0, min(1.0, t))
    return 1 - (1 - t) ** 3


def _compute_arm_positions(shoulder: tuple, side: int, walk_swing: int,
                           swing_ratio: float, cx: int):
    """걷기/스윙 포즈에 따른 팔꿈치, 손목 좌표 계산."""
    base_upper_len = 64
    base_fore_len = 60

    # 기본(걷기) 포즈
    idle_elbow = (
        shoulder[0] + side * 24,
        shoulder[1] + 36 + walk_swing * 0.5,
    )
    idle_wrist = (
        idle_elbow[0] + side * 24,
        idle_elbow[1] + 48 + walk_swing,
    )

    if swing_ratio > 0:
        forward_phase = min(1.0, swing_ratio * 2.0)
        return_phase = max(0.0, swing_ratio * 2.0 - 1.0)
        ease_fwd = _ease_out_cubic(forward_phase)
        ease_ret = _ease_out_cubic(return_phase)

        arc_height = 36 * math.sin(math.pi * forward_phase)
        arc_forward = 24 * math.sin(math.pi * forward_phase)

        peak_angle_deg = 20 if side < 0 else 160
        angle = math.radians(peak_angle_deg)

        swing_lift = 20 + 32 * forward_phase
        inward_pull = 28 + 24 * forward_phase
        upper_len = base_upper_len + 12 * forward_phase
        fore_len = base_fore_len + 20 * forward_phase

        peak_elbow = (
            shoulder[0] + math.cos(angle) * upper_len * 0.5
            + (-side) * (inward_pull + arc_forward),
            shoulder[1] + math.sin(angle) * upper_len * 0.5
            - swing_lift - arc_height,
        )
        peak_wrist = (
            peak_elbow[0] + math.cos(angle) * fore_len
            + (-side) * (inward_pull * 0.6 + arc_forward * 0.7),
            peak_elbow[1] + math.sin(angle) * fore_len
            - swing_lift * 0.7 - arc_height * 0.5,
        )

        # 중앙선 넘지 않도록 클램프
        if side < 0:
            peak_elbow = (min(peak_elbow[0], cx - 24), peak_elbow[1])
            peak_wrist = (min(peak_wrist[0], cx - 32), peak_wrist[1])
        else:
            peak_elbow = (max(peak_elbow[0], cx + 24), peak_elbow[1])
            peak_wrist = (max(peak_wrist[0], cx + 32), peak_wrist[1])

        def lerp_pt(a, b, t):
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)

        elbow = lerp_pt(idle_elbow, peak_elbow, ease_fwd)
        wrist = lerp_pt(idle_wrist, peak_wrist, ease_fwd)
        elbow = lerp_pt(elbow, idle_elbow, ease_ret)
        wrist = lerp_pt(wrist, idle_wrist, ease_ret)
    else:
        elbow = idle_elbow
        wrist = idle_wrist

    return elbow, wrist


def _draw_arm_segment(surface: pygame.Surface, shoulder: tuple,
                      elbow: tuple, wrist: tuple,
                      palette: dict, phase: float):
    """팔 세그먼트 + 팔꿈치 LED + 아머 플레이트 (좌/우 공용)."""
    # 상완 + 전완
    pygame.draw.line(surface, palette["body"], shoulder, elbow, 24)
    pygame.draw.line(surface, palette["body"], elbow, wrist, 20)
    pygame.draw.line(surface, palette["arm_line"], shoulder, elbow, 6)
    pygame.draw.line(surface, palette["arm_line"], elbow, wrist, 6)

    # 팔꿈치 관절 LED
    elbow_int = (int(elbow[0]), int(elbow[1]))
    pygame.draw.circle(surface, palette["hex_base"], elbow_int, 10)
    pygame.draw.circle(surface, palette["accent"], elbow_int, 6, 2)
    pygame.draw.circle(surface, palette["hex_core"], elbow_int, 4)

    # 팔 중간 아머 플레이트
    mid_arm = ((int(shoulder[0]) + elbow_int[0]) // 2,
               (int(shoulder[1]) + elbow_int[1]) // 2)
    pygame.draw.circle(surface, palette["helmet"], mid_arm, 8)
    pygame.draw.circle(surface, palette["accent"], mid_arm, 5, 2)


def _draw_hand(surface: pygame.Surface, wrist_int: tuple,
               palette: dict, side: int):
    """손 + 손가락 렌더링."""
    pygame.draw.circle(surface, palette["hand"], wrist_int, 12)

    # 손가락 4개
    for finger_idx in range(4):
        finger_angle = math.radians(-30 + finger_idx * 20)
        finger_len = 10 + (1 if finger_idx in (1, 2) else 0) * 2
        fx = wrist_int[0] + int(math.cos(finger_angle) * finger_len) + side * 8
        fy = wrist_int[1] + int(math.sin(finger_angle) * finger_len) + 6
        pygame.draw.line(surface, palette["hand"], wrist_int, (fx, fy), 4)
        pygame.draw.circle(surface, palette["hand"], (fx, fy), 3)

    # 엄지
    thumb_x = wrist_int[0] + side * 6
    thumb_y = wrist_int[1] - 6
    pygame.draw.line(surface, palette["hand"], wrist_int, (thumb_x, thumb_y), 4)
    pygame.draw.circle(surface, palette["hand"], (thumb_x, thumb_y), 3)


class OptimusLeftArmPart(BodyPart):
    """왼팔 (탁구채 쪽) — 팔 세그먼트 + 손.
    탁구채는 OptimusWeaponPart에서 별도로 그린다.
    """

    def __init__(self):
        super().__init__(slot=SLOT_L_ARM, draw_order=ORDER_L_ARM,
                         joint_a="l_shoulder", joint_b="l_wrist")

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        shoulder = joint_a.world_int()
        side = -1

        # 스킨에서 게임 상태 가져오기
        gs = getattr(getattr(self, '_skin_ref', None), '_game_state', None)
        swing_duration = getattr(gs, 'arm_swing_duration', 1) or 1
        left_timer = getattr(gs, 'arm_swing_left_timer', 0)
        swing_ratio = max(0.0, min(1.0,
            1.0 - (left_timer / swing_duration) if left_timer > 0 else 0.0))

        stride = math.sin(phase * math.tau)
        walk_swing = int(stride * 12)

        # 팔 관절 위치 보정 — 스켈레톤 joint 대신 직접 계산 (원본 호환)
        # 스켈레톤에서 cx는 shoulder_x + 60 (= 루트의 X)
        cx = shoulder[0] + 60  # shoulder는 cx - 60 위치

        elbow, wrist = _compute_arm_positions(
            shoulder, side, walk_swing, swing_ratio, cx)

        _draw_arm_segment(surface, shoulder, elbow, wrist, palette, phase)
        wrist_int = (int(wrist[0]), int(wrist[1]))
        _draw_hand(surface, wrist_int, palette, side)

        # 손목 위치를 스킨에 공유 (무기 파츠에서 참조)
        skin = getattr(self, '_skin_ref', None)
        if skin:
            skin._l_wrist_pos = wrist_int
            skin._l_elbow_pos = (int(elbow[0]), int(elbow[1]))


class OptimusRightArmPart(BodyPart):
    """오른팔 (주먹 쪽) — 팔 세그먼트 + 손.
    주먹은 OptimusFistPart에서 별도로 그린다.
    옵티머스 암 스킬 활성화 시 일반 팔 렌더링을 스킵한다.
    """

    def __init__(self):
        super().__init__(slot=SLOT_R_ARM, draw_order=ORDER_R_ARM,
                         joint_a="r_shoulder", joint_b="r_wrist")

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        shoulder = joint_a.world_int()
        side = 1

        # 옵티머스 암 스킬 상태 확인 — 활성화 시 일반 팔 렌더링 스킵
        gs = getattr(getattr(self, '_skin_ref', None), '_game_state', None)
        arm_state = getattr(gs, 'arm_state', 'idle')
        if arm_state != 'idle':
            # 옵티머스 암 활성화 — 이 파츠에서는 스킵,
            # draw_optimus_arm()이 별도로 그림
            skin = getattr(self, '_skin_ref', None)
            if skin:
                skin._r_wrist_pos = None  # 주먹 파츠도 스킵하도록 None
            return

        swing_duration = getattr(gs, 'arm_swing_duration', 1) or 1
        right_timer = getattr(gs, 'arm_swing_right_timer', 0)
        swing_ratio = max(0.0, min(1.0,
            1.0 - (right_timer / swing_duration) if right_timer > 0 else 0.0))

        stride = math.sin(phase * math.tau)
        walk_swing = int(-stride * 12 // 2)

        cx = shoulder[0] - 60  # shoulder는 cx + 60 위치

        elbow, wrist = _compute_arm_positions(
            shoulder, side, walk_swing, swing_ratio, cx)

        _draw_arm_segment(surface, shoulder, elbow, wrist, palette, phase)
        wrist_int = (int(wrist[0]), int(wrist[1]))
        _draw_hand(surface, wrist_int, palette, side)

        # 손목 위치를 스킨에 공유 (주먹 파츠에서 참조)
        skin = getattr(self, '_skin_ref', None)
        if skin:
            skin._r_wrist_pos = wrist_int
            skin._r_elbow_pos = (int(elbow[0]), int(elbow[1]))
