"""
SmasherSkin — 스매셔 캐릭터 스킨 팩토리.

모든 파츠 + 팔레트 + 모션을 조합하여 CharacterSkin을 생성한다.
create_smasher_paddle_surface()의 대체 진입점.
"""

import math
import pygame
from entities.player_skeleton import (
    CharacterSkin, Skeleton, create_smasher_skeleton,
    UPPER_BODY_JOINTS,
)
from entities.body_parts.smasher_head import SmasherHeadPart
from entities.body_parts.smasher_torso import SmasherTorsoPart
from entities.body_parts.smasher_arms import SmasherLeftArmPart, SmasherRightArmPart
from entities.body_parts.smasher_weapon import SmasherWeaponPart
from entities.body_parts.smasher_shield import SmasherShieldPart
from entities.body_parts.smasher_legs import SmasherLegsPart
from entities.body_parts.smasher_board import SmasherBoardPart
from entities.body_parts.smasher_motion import SmasherMotionProfile


# ── 스매셔 팔레트 (원본 29600~29640줄에서 추출) ──
SMASHER_PALETTE = {
    "shadow": (0, 0, 0, 64),
    "helmet": (70, 102, 162),
    "helmet_side": (58, 82, 136),
    "helmet_high": (148, 182, 236),
    "face": (212, 196, 176),
    "visor": (170, 224, 255),
    "visor_core": (126, 192, 246),
    "visor_highlight": (220, 240, 255),
    "armor_outer": (80, 96, 150),
    "armor_mid": (60, 76, 120),
    "armor_inner": (46, 58, 92),
    "trim": (190, 206, 236),
    "accent": (118, 214, 255),
    "accent_core": (82, 178, 248),
    "undersuit": (36, 40, 58),
    "undersuit_dark": (22, 26, 40),
    "arm_light": (132, 152, 204),
    "glove": (198, 182, 164),
    "glove_detail": (156, 134, 110),
    "paddle": (220, 56, 74),
    "paddle_core": (244, 116, 132),
    "paddle_shadow": (154, 42, 58),
    "handle": (174, 132, 98),
    "handle_core": (206, 166, 128),
    "belt": (88, 78, 108),
    "belt_glint": (158, 140, 196),
    "boot": (64, 74, 110),
    "boot_high": (128, 146, 190),
    "knee": (96, 118, 176),
    "outline": (20, 24, 36),
    "board_base": (58, 72, 118),
    "board_shadow": (34, 40, 68),
    "board_highlight": (142, 182, 242),
    "board_glow": (100, 198, 255),
    "thruster_core": (255, 234, 170),
    "thruster_glow": (118, 214, 255),
    "thruster_heat": (254, 156, 94),
    "shield_core": (200, 252, 255),
    "shield_ring": (120, 210, 255),
    "shield_glow": (70, 160, 255),
    # 메카 전용 (옵티머스 팔레트 호환용)
    "hex_base": (40, 50, 80),
    "hex_core": (82, 178, 248),
}


def create_smasher_skin(block: int = 9) -> CharacterSkin:
    """스매셔 캐릭터 스킨 생성.

    Returns:
        모든 파츠가 조합된 CharacterSkin 인스턴스.
    """
    skin = CharacterSkin(
        name="smasher",
        palette=SMASHER_PALETTE,
        motion=SmasherMotionProfile(),
    )

    # 파츠 등록 (draw_order에 따라 뒤→앞 순서로 렌더링됨)
    skin.set_part(SmasherBoardPart(block))       # ORDER_BOARD = 5
    skin.set_part(SmasherLegsPart(block))        # ORDER_LEGS = 10
    skin.set_part(SmasherTorsoPart(block))       # ORDER_TORSO = 20
    skin.set_part(SmasherRightArmPart(block))    # ORDER_R_ARM = 25
    skin.set_part(SmasherShieldPart(block))      # ORDER_SHIELD = 27
    skin.set_part(SmasherHeadPart(block))        # ORDER_HEAD = 30
    skin.set_part(SmasherLeftArmPart(block))     # ORDER_L_ARM = 40
    skin.set_part(SmasherWeaponPart(block))      # ORDER_WEAPON = 45

    return skin


# ── 싱글톤 인스턴스 (매 프레임 재생성 방지) ──
_smasher_skeleton: Skeleton | None = None
_smasher_skin: CharacterSkin | None = None


def get_smasher_skeleton(block: int = 9) -> Skeleton:
    """스매셔 뼈대 싱글톤."""
    global _smasher_skeleton
    if _smasher_skeleton is None:
        _smasher_skeleton = create_smasher_skeleton(block)
    return _smasher_skeleton


def get_smasher_skin(block: int = 9) -> CharacterSkin:
    """스매셔 스킨 싱글톤."""
    global _smasher_skin
    if _smasher_skin is None:
        _smasher_skin = create_smasher_skin(block)
    return _smasher_skin


def render_smasher_skeletal(step_phase: float = 0.0,
                            hit_pose_ratio: float = 0.0,
                            shield_raise_strength: float = 0.0,
                            left_raise_strength: float = 0.0) -> pygame.Surface:
    """뼈대 시스템으로 스매셔를 렌더링.

    기존 create_smasher_paddle_surface()와 동일한 시그니처의 래퍼.
    기존 함수를 대체할 때 이 함수를 호출하면 된다.

    Args:
        step_phase: 걷기 애니메이션 위상 (0~1)
        hit_pose_ratio: 타격 포즈 강도 (0~1)
        shield_raise_strength: 방패 들기 강도 (0~1)
        left_raise_strength: 왼팔 들기 강도 (0~1)

    Returns:
        250x120 SRCALPHA Surface (기존과 동일 크기).
    """
    skeleton = get_smasher_skeleton()
    skin = get_smasher_skin()
    motion = skin.motion

    # 위상 정규화
    phase = 0.0 if step_phase is None else float(step_phase) % 1.0

    # ── 포즈 블렌딩 ──

    # 1) 기본: 걷기 포즈
    base_pose = motion.get_walk_pose(phase)

    # 2) 타격 포즈 레이어 (상체만)
    if hit_pose_ratio > 0:
        hit_pose = motion.get_hit_pose(1.0 - hit_pose_ratio)  # ratio가 클수록 강함
        base_pose = Skeleton.layer_pose(base_pose, hit_pose, mask=UPPER_BODY_JOINTS)

    # 3) 방패 들기 레이어 (오른팔만)
    if shield_raise_strength > 0:
        shield_pose = motion.get_shield_raise_pose(shield_raise_strength)
        r_arm_mask = {"r_shoulder", "r_elbow", "r_wrist"}
        base_pose = Skeleton.layer_pose(base_pose, shield_pose, mask=r_arm_mask)

    # 4) 왼팔 들기 레이어
    if left_raise_strength > 0:
        left_pose = motion.get_left_raise_pose(left_raise_strength)
        l_arm_mask = {"l_shoulder", "l_elbow", "l_wrist"}
        base_pose = Skeleton.layer_pose(base_pose, left_pose, mask=l_arm_mask)

    # ── 뼈대 업데이트 ──
    skeleton.apply_pose(base_pose)
    # 루트 위치: Surface 중앙(125, 56) — 기존 center_x=125, torso_base_y=56
    skeleton.update(root_pos=(125.0, 56.0))

    # ── 렌더링 ──
    surface = pygame.Surface((250, 120), pygame.SRCALPHA)
    skin.draw_all(surface, skeleton, phase)

    return surface
