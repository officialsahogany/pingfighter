"""
Player Skeletal Sprite System (플레이어 뼈대 스프라이트 시스템)
Phase 1: 코어 클래스 — Joint, Skeleton, BodyPart, MotionProfile, CharacterSkin

관절 트리 기반으로 캐릭터를 렌더링하여:
1) 캐릭터별로 다른 모션 (타격/이동 스타일)
2) 장비 착용 시 부위별 파츠 교체
3) 광장 꾸밈 아이템 외형 변경
을 가능하게 한다.
"""

import math
import pygame
from typing import Optional


# ─────────────────────────────────────────────
#  Joint (관절) — 뼈대의 기본 단위
# ─────────────────────────────────────────────

class Joint:
    """뼈대 트리의 관절 노드.

    부모 관절 기준 상대 좌표(local_pos)와 회전(local_angle)을 가지며,
    update_transform()으로 월드 좌표를 재귀 계산한다.
    """

    __slots__ = (
        "name", "local_pos", "local_angle", "local_scale",
        "parent", "children",
        "global_pos", "global_angle", "global_scale",
    )

    def __init__(self, name: str,
                 local_x: float = 0.0, local_y: float = 0.0,
                 local_angle: float = 0.0):
        self.name = name
        self.local_pos = (local_x, local_y)
        self.local_angle = local_angle      # degrees, 시계방향 양수
        self.local_scale = 1.0

        self.parent: Optional["Joint"] = None
        self.children: list["Joint"] = []

        # update_transform() 호출 후 채워짐
        self.global_pos = (0.0, 0.0)
        self.global_angle = 0.0
        self.global_scale = 1.0

    def add_child(self, child: "Joint"):
        child.parent = self
        self.children.append(child)

    def update_transform(self,
                         parent_pos: tuple[float, float] = (0.0, 0.0),
                         parent_angle: float = 0.0,
                         parent_scale: float = 1.0):
        """부모 트랜스폼을 받아 월드 좌표를 재귀 계산."""
        self.global_angle = parent_angle + self.local_angle
        self.global_scale = parent_scale * self.local_scale

        rad = math.radians(parent_angle)
        cos_a = math.cos(rad)
        sin_a = math.sin(rad)

        lx, ly = self.local_pos
        scaled_lx = lx * parent_scale
        scaled_ly = ly * parent_scale
        rotated_x = scaled_lx * cos_a - scaled_ly * sin_a
        rotated_y = scaled_lx * sin_a + scaled_ly * cos_a

        self.global_pos = (
            parent_pos[0] + rotated_x,
            parent_pos[1] + rotated_y,
        )

        for child in self.children:
            child.update_transform(self.global_pos, self.global_angle, self.global_scale)

    def world_int(self) -> tuple[int, int]:
        """global_pos를 정수 튜플로 반환 (pygame.draw 호출용)."""
        return (int(round(self.global_pos[0])), int(round(self.global_pos[1])))


# ─────────────────────────────────────────────
#  Skeleton (뼈대) — 관절 트리 + 포즈 적용
# ─────────────────────────────────────────────

class Skeleton:
    """관절들의 트리 구조. apply_pose()로 모션 데이터를 주입하고
    update()로 월드 좌표를 일괄 계산한다."""

    def __init__(self):
        self.joints: dict[str, Joint] = {}
        self.root: Optional[Joint] = None

    def add_joint(self, joint: Joint, parent_name: Optional[str] = None):
        """관절을 트리에 추가. parent_name=None이면 루트."""
        self.joints[joint.name] = joint
        if parent_name is None:
            self.root = joint
        elif parent_name in self.joints:
            self.joints[parent_name].add_child(joint)

    def get_joint(self, name: str) -> Optional[Joint]:
        return self.joints.get(name)

    def update(self, root_pos: tuple[float, float] = (0.0, 0.0),
               root_angle: float = 0.0):
        """루트부터 재귀적으로 모든 관절의 월드 좌표를 갱신."""
        if self.root:
            self.root.update_transform(root_pos, root_angle)

    # ── 포즈 적용 ──

    def apply_pose(self, pose: dict[str, float]):
        """단일 포즈 적용: {관절이름: 회전각도}"""
        for jname, angle in pose.items():
            j = self.joints.get(jname)
            if j:
                j.local_angle = angle

    def reset_pose(self):
        """모든 관절을 0도로 리셋."""
        for j in self.joints.values():
            j.local_angle = 0.0
            j.local_scale = 1.0

    # ── 포즈 블렌딩 유틸리티 (static) ──

    @staticmethod
    def blend_pose(pose_a: dict[str, float],
                   pose_b: dict[str, float],
                   weight: float) -> dict[str, float]:
        """두 포즈를 weight(0~1)로 선형 보간.
        weight=0이면 pose_a, weight=1이면 pose_b."""
        all_keys = set(pose_a) | set(pose_b)
        result = {}
        for key in all_keys:
            a = pose_a.get(key, 0.0)
            b = pose_b.get(key, 0.0)
            result[key] = a + (b - a) * weight
        return result

    @staticmethod
    def layer_pose(base: dict[str, float],
                   overlay: dict[str, float],
                   mask: Optional[set[str]] = None) -> dict[str, float]:
        """base 위에 overlay를 덮어쓰기.
        mask가 주어지면 해당 관절만 overlay 적용."""
        result = dict(base)
        for key, val in overlay.items():
            if mask is None or key in mask:
                result[key] = val
        return result

    @staticmethod
    def additive_pose(base: dict[str, float],
                      additive: dict[str, float],
                      weight: float = 1.0) -> dict[str, float]:
        """base에 additive 포즈를 가산 블렌딩.
        걷기 + 머리 흔들기 같은 독립 레이어에 유용."""
        result = dict(base)
        for key, val in additive.items():
            result[key] = result.get(key, 0.0) + val * weight
        return result


# ─────────────────────────────────────────────
#  BodyPart (부위) — 관절에 붙는 시각 요소
# ─────────────────────────────────────────────

class BodyPart:
    """특정 관절(들)에 바인딩되어 자신의 외형을 그리는 기본 클래스.

    서브클래스에서 _render()를 구현한다.
    joint_a: 시작 관절 (필수)
    joint_b: 끝 관절 (선택 — 팔/다리처럼 두 관절 사이에 그리는 파츠용)
    """

    def __init__(self, slot: str, draw_order: int,
                 joint_a: str, joint_b: Optional[str] = None):
        self.slot = slot
        self.draw_order = draw_order
        self.joint_a = joint_a
        self.joint_b = joint_b

        # 정적 파츠 캐싱용
        self._cached_surface: Optional[pygame.Surface] = None
        self._cache_key: Optional[tuple] = None

    def draw(self, surface: pygame.Surface, skeleton: Skeleton,
             palette: dict, phase: float):
        """관절 좌표를 조회하여 _render()를 호출."""
        ja = skeleton.get_joint(self.joint_a)
        if ja is None:
            return
        jb = skeleton.get_joint(self.joint_b) if self.joint_b else None
        self._render(surface, ja, jb, palette, phase)

    def _render(self, surface: pygame.Surface,
                joint_a: Joint, joint_b: Optional[Joint],
                palette: dict, phase: float):
        """서브클래스에서 구현: 실제 그리기 로직."""
        raise NotImplementedError

    def invalidate_cache(self):
        """캐시 무효화 (팔레트/크기 변경 시 호출)."""
        self._cached_surface = None
        self._cache_key = None


# ─────────────────────────────────────────────
#  MotionProfile (모션 프로파일) — 캐릭터별 모션 차이
# ─────────────────────────────────────────────

# 상체/하체 관절 마스크 (포즈 레이어링에 사용)
UPPER_BODY_JOINTS = {
    "torso", "neck", "head",
    "l_shoulder", "l_elbow", "l_wrist",
    "r_shoulder", "r_elbow", "r_wrist",
}

LOWER_BODY_JOINTS = {
    "l_hip", "l_knee", "l_ankle",
    "r_hip", "r_knee", "r_ankle",
}


class MotionProfile:
    """캐릭터별 모션 데이터를 생성하는 기본 클래스.

    각 메서드는 {관절이름: 회전각도} 딕셔너리를 반환한다.
    서브클래스에서 오버라이드하여 캐릭터마다 다른 모션을 정의.
    """

    def get_idle_pose(self, phase: float) -> dict[str, float]:
        """대기 상태 포즈. phase: 0~1 루프."""
        return {}

    def get_walk_pose(self, phase: float) -> dict[str, float]:
        """걷기/이동 포즈. phase: 0~1 루프."""
        return {}

    def get_hit_pose(self, progress: float) -> dict[str, float]:
        """타격 포즈. progress: 0(시작)~1(끝)."""
        return {}

    def get_shield_raise_pose(self, strength: float) -> dict[str, float]:
        """방패 들기 포즈. strength: 0~1."""
        return {}

    def get_dash_pose(self, progress: float, direction: int) -> dict[str, float]:
        """대시 포즈. direction: -1(좌), 1(우)."""
        return {}


# ─────────────────────────────────────────────
#  CharacterSkin (캐릭터 스킨) — 파츠 조합
# ─────────────────────────────────────────────

class CharacterSkin:
    """BodyPart들의 조합 + 팔레트 + 모션 프로파일.

    이 단위로 캐릭터를 정의하고, 장비 착용 시 특정 slot의
    BodyPart만 교체하여 외형을 바꿀 수 있다.
    """

    def __init__(self, name: str, palette: dict,
                 motion: Optional[MotionProfile] = None):
        self.name = name
        self.palette = palette
        self.motion = motion or MotionProfile()
        self.parts: dict[str, BodyPart] = {}    # slot → BodyPart

    def set_part(self, part: BodyPart):
        """슬롯에 파츠를 등록/교체."""
        self.parts[part.slot] = part

    def remove_part(self, slot: str):
        """슬롯에서 파츠를 제거."""
        self.parts.pop(slot, None)

    def get_part(self, slot: str) -> Optional[BodyPart]:
        return self.parts.get(slot)

    def draw_all(self, surface: pygame.Surface, skeleton: Skeleton, phase: float):
        """draw_order 순으로 모든 파츠를 렌더링."""
        sorted_parts = sorted(self.parts.values(), key=lambda p: p.draw_order)
        for part in sorted_parts:
            # VFX 상태를 파츠에 전달 (에너지 코어, 바이저 깜빡임 등)
            part._skin_ref = self
            part.draw(surface, skeleton, self.palette, phase)


# ─────────────────────────────────────────────
#  유틸리티 함수
# ─────────────────────────────────────────────

def blit_rotated(target: pygame.Surface, source: pygame.Surface,
                 pos: tuple[float, float], angle: float,
                 pivot: Optional[tuple[float, float]] = None):
    """pivot 기준으로 source를 회전 후 target에 블릿.

    Args:
        target: 블릿할 대상 Surface
        source: 회전할 원본 Surface
        pos: 피벗이 위치할 월드 좌표
        angle: 회전 각도 (degrees, 시계방향 양수)
        pivot: source 내부의 피벗 좌표 (None이면 center)
    """
    if pivot is None:
        pivot = (source.get_width() / 2, source.get_height() / 2)

    # pygame.transform.rotate는 반시계방향이 양수이므로 부호 반전
    rotated = pygame.transform.rotate(source, -angle)

    # 회전 후 피벗 보정:
    # 원본에서 피벗→center 벡터를 구하고, 회전 후 새 center에서 빼줌
    orig_center = (source.get_width() / 2, source.get_height() / 2)
    pivot_to_center = (orig_center[0] - pivot[0], orig_center[1] - pivot[1])

    rad = math.radians(-angle)
    cos_a = math.cos(rad)
    sin_a = math.sin(rad)
    rotated_offset = (
        pivot_to_center[0] * cos_a - pivot_to_center[1] * sin_a,
        pivot_to_center[0] * sin_a + pivot_to_center[1] * cos_a,
    )

    new_center = (pos[0] + rotated_offset[0], pos[1] + rotated_offset[1])
    rot_rect = rotated.get_rect(center=(int(new_center[0]), int(new_center[1])))
    target.blit(rotated, rot_rect)


def lerp(a: float, b: float, t: float) -> float:
    """선형 보간."""
    return a + (b - a) * t


def lerp_point(start: tuple[float, float], end: tuple[float, float],
               t: float) -> tuple[float, float]:
    """2D 점 선형 보간."""
    return (start[0] + (end[0] - start[0]) * t,
            start[1] + (end[1] - start[1]) * t)


def rotate_point(origin: tuple[float, float], point: tuple[float, float],
                 degrees: float) -> tuple[float, float]:
    """origin을 기준으로 point를 시계방향 회전."""
    rad = math.radians(degrees)
    cos_v = math.cos(rad)
    sin_v = math.sin(rad)
    dx = point[0] - origin[0]
    dy = point[1] - origin[1]
    return (
        origin[0] + dx * cos_v - dy * sin_v,
        origin[1] + dx * sin_v + dy * cos_v,
    )


def int_point(point: tuple[float, float]) -> tuple[int, int]:
    """float 튜플을 int 튜플로 변환."""
    return (int(round(point[0])), int(round(point[1])))


# ─────────────────────────────────────────────
#  표준 뼈대 팩토리 (스매셔 좌표 기반)
# ─────────────────────────────────────────────

# 슬롯 이름 상수 (파츠 교체 시 사용)
SLOT_HEAD = "head"
SLOT_FACE = "face"
SLOT_TORSO = "torso"
SLOT_BELT = "belt"          # 허리 벨트 계열 (megingjord, timer_belt 등) — top과 독립
SLOT_L_ARM = "l_arm"
SLOT_R_ARM = "r_arm"
SLOT_WEAPON = "weapon"
SLOT_SHIELD = "shield"
SLOT_LEGS = "legs"
SLOT_BOARD = "board"
SLOT_BACK = "back"          # 날개, 망토, 제트팩 등 악세서리

# draw_order 상수 (뒤→앞)
ORDER_BACK = 0
ORDER_BOARD = 5
ORDER_LEGS = 10
ORDER_TORSO = 20
ORDER_BELT = 22              # 벨트는 몸통 위, 팔 아래
ORDER_R_ARM = 25             # 방패 팔 (몸통 뒤)
ORDER_SHIELD = 27
ORDER_HEAD = 30
ORDER_FACE = 35
ORDER_L_ARM = 40             # 무기 팔 (몸통 앞)
ORDER_WEAPON = 45
ORDER_OUTLINE = 90


def create_smasher_skeleton(block: int = 9) -> Skeleton:
    """스매셔 캐릭터용 표준 뼈대 생성.

    create_smasher_paddle_surface()의 좌표를 역산하여 관절 위치를 결정.
    루트는 torso_base_y (= 허리 중심).
    모든 좌표는 Surface 중앙(center_x) 기준 상대값.
    """
    b = block
    sk = Skeleton()

    # 루트: hip (torso_base_y 위치 = 벨트/허리)
    sk.add_joint(Joint("hip", 0, 0), parent_name=None)

    # 상체: hip → torso → neck → head
    # 원본 좌표 역산 (block=9, torso_base_y=56 기준):
    #   torso = torso_base_y 그 자체 (흉갑 기준점)
    #   helmet_rect.top = torso_y - 3.1*b = 56 - 27.9 ≈ 29
    #   helmet 중심 ≈ 29 + (2.2*b)/2 = 29 + 9.9 ≈ 39
    # → head 관절 = torso_base_y로부터 약 -17px 위
    sk.add_joint(Joint("torso", 0, 0), "hip")                      # torso = hip과 동일 위치
    sk.add_joint(Joint("neck", 0, -int(1.4 * b)), "torso")         # 목 (흉갑 상단)
    sk.add_joint(Joint("head", 0, -int(0.5 * b)), "neck")          # 머리 중심 (원본 helmet center ≈ torso_y - 17)

    # 왼팔 (탁구채 쪽): torso → l_shoulder → l_elbow → l_wrist
    sk.add_joint(Joint("l_shoulder", -int(1.8 * b), 0), "torso")
    sk.add_joint(Joint("l_elbow", -int(1.05 * b), int(0.05 * b)), "l_shoulder")
    sk.add_joint(Joint("l_wrist", -int(0.9 * b), -int(0.5 * b)), "l_elbow")

    # 오른팔 (방패 쪽): torso → r_shoulder → r_elbow → r_wrist
    sk.add_joint(Joint("r_shoulder", int(1.8 * b), 0), "torso")
    sk.add_joint(Joint("r_elbow", int(1.2 * b), int(0.35 * b)), "r_shoulder")
    sk.add_joint(Joint("r_wrist", int(1.0 * b), int(0.7 * b)), "r_elbow")

    # 왼다리: hip → l_hip → l_knee → l_ankle
    sk.add_joint(Joint("l_hip", -int(0.8 * b), int(0.7 * b)), "hip")
    sk.add_joint(Joint("l_knee", 0, int(2.2 * b)), "l_hip")
    sk.add_joint(Joint("l_ankle", 0, int(1.1 * b)), "l_knee")

    # 오른다리: hip → r_hip → r_knee → r_ankle
    sk.add_joint(Joint("r_hip", int(0.8 * b), int(0.7 * b)), "hip")
    sk.add_joint(Joint("r_knee", 0, int(2.2 * b)), "r_hip")
    sk.add_joint(Joint("r_ankle", 0, int(1.1 * b)), "r_knee")

    return sk


def create_mecha_skeleton(block: int = 18) -> Skeleton:
    """메카(옵티머스) 캐릭터용 뼈대 생성 (레거시 호환).

    _create_mecha_paddle_surface()의 고해상도(416x720) 좌표 기반.
    block=18은 스매셔 block=9의 2배.
    """
    # 메카는 스매셔와 동일한 비율, 2배 스케일
    return create_smasher_skeleton(block)


def create_optimus_skeleton() -> Skeleton:
    """옵티머스 캐릭터 전용 뼈대 생성.

    _create_mecha_paddle_surface()의 실제 좌표를 역산하여 관절 위치를 결정.
    스프라이트 크기: 416x720
    루트(hip)는 (208, 608) — MECHA_CENTER_X, MECHA_CENTER_Y+32.

    좌표 역산 기준:
      cx = 208, base_cy = 576
      hip_y      = base_cy + 32  = 608   (루트)
      shoulder_y = base_cy - 12  = 564   → torso offset = -44
      head_y     = base_cy - 64  = 512   → neck+head offset = -52 from torso
      foot_base_y= base_cy + 120 = 696   → +88 from hip (고정, bob 없음)
    """
    sk = Skeleton()

    # 루트: hip (허리/벨트)
    sk.add_joint(Joint("hip", 0, 0), parent_name=None)

    # ── 상체 ──
    # torso = shoulder 높이 (hip으로부터 -44)
    sk.add_joint(Joint("torso", 0, -44), "hip")
    # neck = torso로부터 -28
    sk.add_joint(Joint("neck", 0, -28), "torso")
    # head = neck으로부터 -24  → 총 -96 from hip = head_y - hip_y ✓
    sk.add_joint(Joint("head", 0, -24), "neck")

    # ── 왼팔 (탁구채 쪽) ──
    # shoulder = (cx - 60, shoulder_y + 4) → torso 기준 (-60, +4)
    sk.add_joint(Joint("l_shoulder", -60, 4), "torso")
    # 아이들 팔꿈치: shoulder + (side*24, +36)
    sk.add_joint(Joint("l_elbow", -24, 36), "l_shoulder")
    # 아이들 손목: elbow + (side*24, +48)
    sk.add_joint(Joint("l_wrist", -24, 48), "l_elbow")

    # ── 오른팔 (주먹 쪽) ──
    sk.add_joint(Joint("r_shoulder", 60, 4), "torso")
    sk.add_joint(Joint("r_elbow", 24, 36), "r_shoulder")
    sk.add_joint(Joint("r_wrist", 24, 48), "r_elbow")

    # ── 왼다리 ──
    # draw_leg side=-1: hip = (cx - 36, hip_y) → (-36, 0)
    sk.add_joint(Joint("l_hip", -36, 0), "hip")
    sk.add_joint(Joint("l_knee", 0, 44), "l_hip")
    sk.add_joint(Joint("l_ankle", 0, 44), "l_knee")

    # ── 오른다리 ──
    sk.add_joint(Joint("r_hip", 36, 0), "hip")
    sk.add_joint(Joint("r_knee", 0, 44), "r_hip")
    sk.add_joint(Joint("r_ankle", 0, 44), "r_knee")

    return sk
