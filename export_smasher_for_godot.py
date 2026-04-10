#!/usr/bin/env python3
"""Export current skeletal smasher sprites for the Godot prototype."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pygame
import numpy as np

from entities.body_parts.smasher_skin import get_smasher_skin, get_smasher_skeleton
from entities.player_skeleton import Skeleton, UPPER_BODY_JOINTS


OUT_DIR = os.environ.get(
    "PINGFIGHTER_GODOT_SPRITES",
    "C:/Users/woduq/Documents/pingfighter/assets/sprites",
)
SURFACE_SIZE = (250, 120)
ROOT_POS = (125.0, 56.0)
BLOCK = 9
ALPHA_CUTOFF = 8


def _prepare_skin():
    skin = get_smasher_skin(BLOCK)
    skin._vfx_energy_core = None
    skin._vfx_visor_blink_alpha = 1.0
    return skin


def _sanitize_surface(surface: pygame.Surface) -> pygame.Surface:
    width, height = surface.get_size()
    rgba = np.frombuffer(
        pygame.image.tostring(surface, "RGBA"),
        dtype=np.uint8,
    ).copy().reshape((height, width, 4))
    low_alpha_mask = rgba[:, :, 3] <= ALPHA_CUTOFF
    rgba[low_alpha_mask] = 0
    return pygame.image.frombuffer(rgba.tobytes(), (width, height), "RGBA").copy()


def _apply_walk_offsets(skeleton: Skeleton, phase: float) -> tuple[float, float]:
    wave = math.sin(phase * math.tau)
    abs_wave = abs(wave)

    torso_bob = int(abs_wave * 2)
    hip_sway = int(wave * 2)
    arm_swing = int(wave * 5)
    shoulder_shift = int(wave * 2)
    left_leg_lift = -int(max(0.0, wave) * 4)
    right_leg_lift = -int(max(0.0, -wave) * 4)

    torso = skeleton.get_joint("torso")
    if torso:
        torso.local_pos = (0, -torso_bob)

    left_elbow = skeleton.get_joint("l_elbow")
    if left_elbow:
        left_elbow.local_pos = (-BLOCK - arm_swing, int(0.05 * BLOCK) - arm_swing // 2)

    left_wrist = skeleton.get_joint("l_wrist")
    if left_wrist:
        left_wrist.local_pos = (-BLOCK + 1, int(-0.5 * BLOCK) - int(arm_swing * 0.5))

    right_elbow = skeleton.get_joint("r_elbow")
    if right_elbow:
        right_elbow.local_pos = (int(1.2 * BLOCK) + arm_swing, int(0.35 * BLOCK) + arm_swing // 2)

    right_wrist = skeleton.get_joint("r_wrist")
    if right_wrist:
        right_wrist.local_pos = (BLOCK, int(0.7 * BLOCK) + int(arm_swing * 0.5))

    left_shoulder = skeleton.get_joint("l_shoulder")
    if left_shoulder:
        left_shoulder.local_pos = (-int(1.8 * BLOCK), shoulder_shift)

    right_shoulder = skeleton.get_joint("r_shoulder")
    if right_shoulder:
        right_shoulder.local_pos = (int(1.8 * BLOCK), -shoulder_shift)

    left_hip = skeleton.get_joint("l_hip")
    if left_hip:
        left_hip.local_pos = (-int(0.8 * BLOCK), int(0.7 * BLOCK) + left_leg_lift)

    right_hip = skeleton.get_joint("r_hip")
    if right_hip:
        right_hip.local_pos = (int(0.8 * BLOCK), int(0.7 * BLOCK) + right_leg_lift)

    return (ROOT_POS[0] + hip_sway * 0.3, ROOT_POS[1])


def render_export_frame(
    *,
    mode: str = "walk",
    phase: float = 0.0,
    hit_pose_ratio: float = 0.0,
    shield_raise_strength: float = 0.0,
    left_raise_strength: float = 0.0,
) -> pygame.Surface:
    skeleton = get_smasher_skeleton(BLOCK, force_recreate=True)
    skin = _prepare_skin()
    motion = skin.motion

    phase = float(phase) % 1.0
    if mode == "idle":
        base_pose = motion.get_idle_pose(phase)
    else:
        base_pose = motion.get_walk_pose(phase)

    if hit_pose_ratio > 0.0:
        hit_pose = motion.get_hit_pose(1.0 - hit_pose_ratio)
        base_pose = Skeleton.layer_pose(base_pose, hit_pose, mask=UPPER_BODY_JOINTS)

    if shield_raise_strength > 0.0:
        shield_pose = motion.get_shield_raise_pose(shield_raise_strength)
        base_pose = Skeleton.layer_pose(base_pose, shield_pose, mask={"r_shoulder", "r_elbow", "r_wrist"})

    if left_raise_strength > 0.0:
        left_pose = motion.get_left_raise_pose(left_raise_strength)
        base_pose = Skeleton.layer_pose(base_pose, left_pose, mask={"l_shoulder", "l_elbow", "l_wrist"})

    skeleton.apply_pose(base_pose)

    root_pos = ROOT_POS
    if mode == "walk":
        root_pos = _apply_walk_offsets(skeleton, phase)

    skeleton.update(root_pos=root_pos)

    surface = pygame.Surface(SURFACE_SIZE, pygame.SRCALPHA)
    skin.draw_all(surface, skeleton, phase)
    return surface


def _save_strip(name: str, frames: list[pygame.Surface]) -> pygame.Surface:
    frame_w = frames[0].get_width()
    frame_h = frames[0].get_height()
    strip = pygame.Surface((frame_w * len(frames), frame_h), pygame.SRCALPHA)
    for index, frame in enumerate(frames):
        strip.blit(_sanitize_surface(frame), (frame_w * index, 0))
    strip = _sanitize_surface(strip)
    out_path = os.path.join(OUT_DIR, name)
    pygame.image.save(strip, out_path)
    print(f"Saved {name}: {strip.get_width()}x{strip.get_height()}")
    return strip


def _save_single(name: str, frame: pygame.Surface) -> None:
    frame = _sanitize_surface(frame)
    out_path = os.path.join(OUT_DIR, name)
    pygame.image.save(frame, out_path)
    print(f"Saved {name}: {frame.get_width()}x{frame.get_height()}")


def _export_idle() -> None:
    idle_frames = [
        render_export_frame(mode="idle", phase=index / 8.0)
        for index in range(8)
    ]
    _save_single("smasher_current_idle.png", idle_frames[0])
    _save_strip("smasher_idle_strip.png", idle_frames)


def _export_walk() -> None:
    walk_frames = [
        render_export_frame(mode="walk", phase=index / 6.0)
        for index in range(6)
    ]
    _save_strip("smasher_walk_strip.png", walk_frames)


def _export_hit_sets() -> None:
    hit_strengths = [1.0, 0.72, 0.38, 0.0]

    left_frames = [
        render_export_frame(
            mode="walk",
            phase=0.18,
            hit_pose_ratio=strength,
            left_raise_strength=strength,
        )
        for strength in hit_strengths
    ]
    right_frames = [
        render_export_frame(
            mode="walk",
            phase=0.82,
            hit_pose_ratio=strength,
            shield_raise_strength=strength,
        )
        for strength in hit_strengths
    ]

    _save_single("smasher_hit_pose.png", left_frames[0])
    _save_single("smasher_shield_pose.png", right_frames[0])
    _save_strip("smasher_hit_left_strip.png", left_frames)
    _save_strip("smasher_hit_right_strip.png", right_frames)


def main() -> None:
    os.makedirs(OUT_DIR, exist_ok=True)
    pygame.init()
    pygame.display.set_mode((1, 1), pygame.NOFRAME)

    try:
        _export_idle()
        _export_walk()
        _export_hit_sets()
        print("Done.")
    finally:
        pygame.quit()


if __name__ == "__main__":
    main()
