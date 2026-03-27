"""
OptimusSkin — 옵티머스 캐릭터 스킨 팩토리.

모든 파츠 + 팔레트 + 모션을 조합하여 CharacterSkin을 생성한다.
_create_mecha_paddle_surface()의 모듈화된 대체 진입점.
"""

import math
import pygame
from entities.player_skeleton import (
    CharacterSkin, Skeleton, create_optimus_skeleton,
    UPPER_BODY_JOINTS,
)
from entities.body_parts.optimus_head import OptimusHeadPart
from entities.body_parts.optimus_torso import OptimusTorsoPart
from entities.body_parts.optimus_arms import OptimusLeftArmPart, OptimusRightArmPart
from entities.body_parts.optimus_weapon import OptimusWeaponPart
from entities.body_parts.optimus_fist import OptimusFistPart
from entities.body_parts.optimus_legs import OptimusLegsPart
from entities.body_parts.optimus_motion import OptimusMotionProfile


# ── 옵티머스 팔레트 (pingfighter.py OPTIMUS_MECHA_PALETTE에서 추출) ──
OPTIMUS_PALETTE = {
    # 실버+네온 청록 기반 테슬라 사이버 로봇 컬러링
    "body": (205, 215, 228),
    "accent": (120, 235, 255),
    "helmet": (46, 58, 78),
    "helmet_inner": (26, 34, 48),
    "visor": (110, 235, 255),
    "visor_highlight": (210, 255, 255),
    "ear_inner": (90, 150, 190),
    "line": (120, 235, 255),
    "grip": (50, 64, 82),
    "grip_line": (140, 230, 255),
    "hex_base": (36, 46, 64),
    "hex_border": (120, 235, 255),
    "hex_core": (200, 245, 255),
    "hex_core_inner": (120, 235, 255),
    "arm_line": (120, 235, 255),
    "hand": (225, 235, 240),
    "glow": (120, 235, 255),
    "at_field": (100, 200, 255),
}

# ── 스프라이트 크기/좌표 상수 ──
OPTIMUS_SPRITE_SIZE = (416, 720)
OPTIMUS_ROOT_X = 208      # MECHA_CENTER_X = 416 / 2
OPTIMUS_ROOT_Y = 608      # MECHA_CENTER_Y(576) + 32
OPTIMUS_BASE_CY = 576     # MECHA_CENTER_Y


class OptimusGameState:
    """옵티머스 게임 상태 — 바디 파츠에서 참조.

    pingfighter.py에서 렌더링 전에 이 값들을 동기화한다.
    """
    def __init__(self):
        # 팔 스윙 (공 타격 시)
        self.arm_swing_left_timer: int = 0
        self.arm_swing_right_timer: int = 0
        self.arm_swing_duration: int = 1

        # 탁구채 강화 상태
        self.paddle_upgrade_complete: bool = False
        self.paddle_upgrade_active: bool = False
        self.paddle_upgrade_timer: int = 0
        self.paddle_upgrade_particles: list = []

        # 기계손 강화 상태
        self.mech_arm_upgrade_complete: bool = False
        self.mech_arm_upgrade_active: bool = False
        self.mech_arm_upgrade_timer: int = 0
        self.mech_arm_particles: list = []

        # 옵티머스 암 스킬 상태
        self.arm_state: str = "idle"
        self.arm_length: float = 0
        self.arm_target_x: float = 0
        self.arm_target_y: float = 0
        self.arm_start_ms: int = 0
        self.arm_grabbed_boss: bool = False
        self.player_rect = None


def create_optimus_skin() -> CharacterSkin:
    """옵티머스 캐릭터 스킨 생성.

    Returns:
        모든 파츠가 조합된 CharacterSkin 인스턴스.
    """
    skin = CharacterSkin(
        name="optimus",
        palette=OPTIMUS_PALETTE,
        motion=OptimusMotionProfile(),
    )

    # 파츠 등록 (draw_order에 따라 뒤→앞 순서로 렌더링됨)
    skin.set_part(OptimusLegsPart())        # ORDER_LEGS = 10
    skin.set_part(OptimusTorsoPart())       # ORDER_TORSO = 20
    skin.set_part(OptimusRightArmPart())    # ORDER_R_ARM = 25
    skin.set_part(OptimusFistPart())        # ORDER_FIST = 26
    skin.set_part(OptimusHeadPart())        # ORDER_HEAD = 30
    skin.set_part(OptimusLeftArmPart())     # ORDER_L_ARM = 40
    skin.set_part(OptimusWeaponPart())      # ORDER_WEAPON = 45

    return skin


# ── 싱글톤 인스턴스 (매 프레임 재생성 방지) ──
_optimus_skeleton: Skeleton | None = None
_optimus_skin: CharacterSkin | None = None
_optimus_game_state: OptimusGameState | None = None


def get_optimus_skeleton(force_recreate: bool = False) -> Skeleton:
    """옵티머스 뼈대 싱글톤."""
    global _optimus_skeleton
    if _optimus_skeleton is None or force_recreate:
        _optimus_skeleton = create_optimus_skeleton()
    return _optimus_skeleton


def get_optimus_skin() -> CharacterSkin:
    """옵티머스 스킨 싱글톤."""
    global _optimus_skin
    if _optimus_skin is None:
        _optimus_skin = create_optimus_skin()
    return _optimus_skin


def get_optimus_game_state() -> OptimusGameState:
    """옵티머스 게임 상태 싱글톤."""
    global _optimus_game_state
    if _optimus_game_state is None:
        _optimus_game_state = OptimusGameState()
    return _optimus_game_state


def render_optimus_skeletal(step_phase: float = 0.0,
                            hit_pose_ratio: float = 0.0,
                            shield_raise_strength: float = 0.0,
                            left_raise_strength: float = 0.0) -> pygame.Surface:
    """뼈대 시스템으로 옵티머스를 렌더링.

    기존 _create_mecha_paddle_surface()와 호환되는 래퍼.
    이 함수를 호출하면 모듈화된 파츠 시스템으로 렌더링된다.

    Args:
        step_phase: 걷기 애니메이션 위상 (0~1)
        hit_pose_ratio: 타격 포즈 강도 (0~1)
        shield_raise_strength: 오른팔 들기 강도 (0~1)
        left_raise_strength: 왼팔 들기 강도 (0~1)

    Returns:
        416x720 SRCALPHA Surface.
    """
    skeleton = get_optimus_skeleton()
    skin = get_optimus_skin()
    motion = skin.motion
    game_state = get_optimus_game_state()

    # 게임 상태를 스킨에 연결
    skin._game_state = game_state

    # 위상 정규화
    phase = 0.0 if step_phase is None else float(step_phase) % 1.0

    # torso_bob 계산 (루트 Y 오프셋으로 적용)
    torso_bob = int(math.sin(phase * math.tau * 2.0) * 6)

    # ── 포즈 블렌딩 ──
    base_pose = motion.get_walk_pose(phase)

    if hit_pose_ratio > 0:
        hit_pose = motion.get_hit_pose(1.0 - hit_pose_ratio)
        base_pose = Skeleton.layer_pose(
            base_pose, hit_pose, mask=UPPER_BODY_JOINTS)

    if shield_raise_strength > 0:
        shield_pose = motion.get_shield_raise_pose(shield_raise_strength)
        r_arm_mask = {"r_shoulder", "r_elbow", "r_wrist"}
        base_pose = Skeleton.layer_pose(
            base_pose, shield_pose, mask=r_arm_mask)

    if left_raise_strength > 0:
        left_pose = motion.get_left_raise_pose(left_raise_strength)
        l_arm_mask = {"l_shoulder", "l_elbow", "l_wrist"}
        base_pose = Skeleton.layer_pose(
            base_pose, left_pose, mask=l_arm_mask)

    # ── 뼈대 업데이트 ──
    skeleton.apply_pose(base_pose)
    # 루트(hip)를 torso_bob 만큼 이동하여 상체 바운스 구현
    skeleton.update(root_pos=(
        float(OPTIMUS_ROOT_X),
        float(OPTIMUS_ROOT_Y) + torso_bob,
    ))

    # ── 렌더링 ──
    surface = pygame.Surface(OPTIMUS_SPRITE_SIZE, pygame.SRCALPHA)
    skin.draw_all(surface, skeleton, phase)

    # ── 후처리: 상체/머리 글로우 ──
    glow_surface = pygame.Surface(OPTIMUS_SPRITE_SIZE, pygame.SRCALPHA)
    base_cy = OPTIMUS_BASE_CY
    head_y = base_cy - 64 + torso_bob
    pygame.draw.ellipse(
        glow_surface,
        (*OPTIMUS_PALETTE["glow"], 50),
        (OPTIMUS_ROOT_X - 130, base_cy - 64 + torso_bob, 260, 180),
        4)
    pygame.draw.ellipse(
        glow_surface,
        (*OPTIMUS_PALETTE["glow"], 70),
        (OPTIMUS_ROOT_X - 68, head_y - 12, 136, 84),
        2)
    surface.blit(glow_surface, (0, 0))

    # ── 후처리: 육각 실드 ──
    for i in range(2):
        at_radius = 112 + i * 20
        at_alpha = max(0, 28 - i * 10)
        points = []
        for j in range(6):
            angle = math.radians(j * 60 + 30)
            points.append((
                OPTIMUS_ROOT_X + int(math.cos(angle) * at_radius),
                base_cy + int(math.sin(angle) * at_radius * 0.75) + torso_bob,
            ))
        at_surface = pygame.Surface(OPTIMUS_SPRITE_SIZE, pygame.SRCALPHA)
        pygame.draw.polygon(
            at_surface,
            (*OPTIMUS_PALETTE["at_field"], at_alpha),
            points, 2)
        surface.blit(at_surface, (0, 0))

    return surface
