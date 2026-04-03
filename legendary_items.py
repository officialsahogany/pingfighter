"""
전설 아이템 시스템
- 필드에서 스폰되지 않음
- 가챠에서 등장하지 않음
- 해금 조건 필요
- 붉은색 테두리와 움직이는 아이콘 효과
"""

import pygame
import math
import random
import os
import sys
from typing import Dict, List, Optional, Tuple, Callable, NamedTuple
from localization.manager import get_localization_manager

def _t(key, fallback=None):
    return get_localization_manager().get_text(key, fallback)

# 리소스 경로 헬퍼 (PyInstaller 호환)
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

# 디버그 플래그 (성능 영향으로 비활성화)
LEGENDARY_DEBUG_ENABLED = False

# 전설 아이템 티어 정의
LEGENDARY_TIER = "legendary"
LEGENDARY_COLOR = (255, 50, 50)  # 붉은색
LEGENDARY_GLOW_COLOR = (255, 100, 100, 128)  # 반투명 붉은색 글로우
COMMON_LEGENDARY_BORDER_COLOR = (180, 200, 255)
COMMON_LEGENDARY_CORNER_COLOR = (255, 215, 0)
_COMMON_LEGENDARY_BG_CACHE: Dict[Tuple[int, int], pygame.Surface] = {}

# 전설 플레이스홀더 이름 목록(아이콘만 표시용)
PLACEHOLDER_LEGENDARY_NAMES = (
    "empty",
    "empty1",
    "empty2",
    "empty_legendary",
    "empty_legendary2",
    "empty_legendary3",
    "empty_legendary4",
    "empty_legendary5",
    "empty_legendary6",
)

# 천사의 가호 옵션 키
ANGEL_BLESSING_OPTIONS = (
    "paddle_size",
    "gauge_max",
    "item_cooldown",
    "dash_cost",
    "dash_cooldown",
    "move_speed",
)

# 천사의 가호 지연 활성화 대기열 (전설 획득 애니메이션 완료 후 발동)
_pending_angel_blessing_activation: Optional[Dict] = None

# ============================================================================ 
# 전설 아이템 롤 옵션 정의
# ============================================================================
LEGENDARY_ROLL_OPTIONS: Dict[str, List[Dict]] = {
    "ragnarok_hammer": [
        {"key": "trigger_chance", "label": "발동 확률", "min": 20, "max": 50, "unit": "%", "default": 35},
        {"key": "stun_duration", "label": "스턴 시간", "min": 0.4, "max": 0.8, "unit": "초", "default": 0.6, "step": 0.1},
        {"key": "speed_boost", "label": "공속 증가율", "min": 15, "max": 35, "unit": "%", "default": 25},
        {"key": "gauge_cost", "label": "게이지 소모", "min": 20, "max": 40, "unit": "", "default": 30, "reverse": True},
    ],
    "poseidon_trident": [
        {"key": "cooldown", "label": "쿨타임", "min": 2, "max": 10, "unit": "초", "default": 6, "step": 1, "reverse": True},
        {"key": "gauge_cost", "label": "게이지 소모", "min": 20, "max": 40, "unit": "", "prefix": "-", "default": 30, "reverse": True},
    ],
    "hermes_shoes": [
        {"key": "speed_bonus", "label": "이동속도", "min": 30, "max": 60, "unit": "%", "default": 50},
    ],
    "angel_blessing": [
        {"key": "buff_level", "label": "버프 강도", "min": 1, "max": 5, "unit": "Lv", "default": 3},
    ],
    "sacred_laurel": [
        {"key": "leaf_count", "label": "월계수 잎", "min": 3, "max": 8, "unit": "개", "default": 6},
    ],
    "transcendent_crown": [
        {"key": "skill_bonus", "label": "모든 퍽 레벨 증가", "min": 1, "max": 2, "unit": "+", "default": 2},
    ],
    "odins_eye": [
        {"key": "revival_chance", "label": "부활 확률", "min": 25, "max": 40, "unit": "%", "default": 30},
    ],
    "pandora_legacy": [
        {"key": "selection_quality", "label": "매직찬스", "min": 10, "max": 30, "unit": "%", "default": 20},
        {"key": "trigger_chance", "label": "승리시 유산 발동률", "min": 40, "max": 70, "unit": "%", "default": 55},
    ],
}

# 전설 아이템 롤 값 저장소 (아이템명 -> {옵션키: 값})
legendary_roll_values: Dict[str, Dict[str, float]] = {}

def get_legendary_roll_value(item_name: str, option_key: str, apply_polish: bool = False, enhancement_bonus_pct: float = 0) -> float:
    """전설 아이템의 롤 옵션 값을 가져옵니다. 없으면 기본값 반환.

    Args:
        item_name: 전설 아이템 이름
        option_key: 롤옵션 키
        apply_polish: True면 연마 스킬 보너스 적용 (실제 효과 계산용)
        enhancement_bonus_pct: 강화 보너스 퍼센트 (0~100)
    """
    base_value = 0

    if item_name in legendary_roll_values:
        if option_key in legendary_roll_values[item_name]:
            base_value = legendary_roll_values[item_name][option_key]
        else:
            # 기본값 찾기
            if item_name in LEGENDARY_ROLL_OPTIONS:
                for opt in LEGENDARY_ROLL_OPTIONS[item_name]:
                    if opt["key"] == option_key:
                        base_value = opt.get("default", opt["min"])
                        break
    else:
        # 기본값 찾기
        if item_name in LEGENDARY_ROLL_OPTIONS:
            for opt in LEGENDARY_ROLL_OPTIONS[item_name]:
                if opt["key"] == option_key:
                    base_value = opt.get("default", opt["min"])
                    break

    # 연마 스킬 보너스 + 강화 보너스 적용 (옵션이 활성화된 경우에만)
    if (apply_polish or enhancement_bonus_pct > 0) and base_value != 0:
        try:
            # pingfighter에서 연마 배율 가져오기
            import sys
            polish_multiplier = 1.0
            if apply_polish and 'pingfighter' in sys.modules:
                pingfighter = sys.modules['pingfighter']

                # 초월자의 관은 기본 연마 배율 사용 (순환 의존성 방지)
                # 다른 아이템은 초월자의 관 보너스가 적용된 전체 연마 배율 사용
                if item_name == "transcendent_crown":
                    if hasattr(pingfighter, 'get_base_polish_multiplier'):
                        polish_multiplier = pingfighter.get_base_polish_multiplier()
                else:
                    if hasattr(pingfighter, 'get_effective_polish_multiplier'):
                        polish_multiplier = pingfighter.get_effective_polish_multiplier()

            # 총 배율 계산 (연마 + 강화)
            total_multiplier = polish_multiplier
            if enhancement_bonus_pct > 0:
                total_multiplier = total_multiplier * (1 + enhancement_bonus_pct / 100)

            # reverse 옵션 확인 (낮을수록 좋은 옵션)
            is_reverse = False
            if item_name in LEGENDARY_ROLL_OPTIONS:
                for opt in LEGENDARY_ROLL_OPTIONS[item_name]:
                    if opt["key"] == option_key:
                        is_reverse = opt.get("reverse", False)
                        break

            if is_reverse:
                # reverse 옵션: 값을 줄임 (예: 쿨타임 감소)
                base_value = base_value / total_multiplier
            else:
                # 일반 옵션: 값을 증가
                base_value = base_value * total_multiplier
        except Exception:
            pass

    return base_value

def set_legendary_roll_value(item_name: str, option_key: str, value: float):
    """전설 아이템의 롤 옵션 값을 설정합니다."""
    if item_name not in legendary_roll_values:
        legendary_roll_values[item_name] = {}
    legendary_roll_values[item_name][option_key] = value

def randomize_legendary_rolls(item_name: str):
    """전설 아이템의 롤 옵션을 랜덤으로 설정합니다."""
    if item_name not in LEGENDARY_ROLL_OPTIONS:
        return
    for opt in LEGENDARY_ROLL_OPTIONS[item_name]:
        step = opt.get("step", 1)
        if step < 1:
            # 소수점 스텝
            steps = int((opt["max"] - opt["min"]) / step) + 1
            value = opt["min"] + random.randint(0, steps - 1) * step
        else:
            value = random.randint(int(opt["min"]), int(opt["max"]))
        set_legendary_roll_value(item_name, opt["key"], value)


class KnockbackProfile(NamedTuple):
    base_power: float
    speed_weight: float
    speed_thresholds: Tuple[Tuple[float, float], ...]
    random_bonus: Tuple[float, float]
    max_power: Optional[float]


_STANDARD_KNOCKBACK_THRESHOLDS: Tuple[Tuple[float, float], ...] = (
    (25.0, 1.05),
    (20.0, 1.03),
    (15.0, 1.01),
)

# 공통 넉백 알고리즘 파라미터 (라그나로크 해머가 최장 거리 유지)
KNOCKBACK_PROFILES: Dict[str, KnockbackProfile] = {
    "bazooka": KnockbackProfile(  # 가장 짧은 넉백
        base_power=34.0,
        speed_weight=0.0,
        speed_thresholds=_STANDARD_KNOCKBACK_THRESHOLDS,
        random_bonus=(0.0, 0.03),
        max_power=44.0,
    ),
    "grenade": KnockbackProfile(  # 중간 넉백
        base_power=38.0, 
        speed_weight=0.0,
        speed_thresholds=_STANDARD_KNOCKBACK_THRESHOLDS,
        random_bonus=(0.01, 0.04),
        max_power=50.0,
    ),
    "ragnarok": KnockbackProfile(  # 가장 긴 넉백 (추가 하향 반영)
        base_power=18.326,
        speed_weight=0.0748,
        speed_thresholds=_STANDARD_KNOCKBACK_THRESHOLDS,
        random_bonus=(0.02, 0.06),
        max_power=25.823,
    ),
    "hammer_shock_stage1": KnockbackProfile(
        base_power=16.0,
        speed_weight=0.0,
        speed_thresholds=(),
        random_bonus=(0.0, 0.01),
        max_power=16.8,
    ),
    "hammer_shock_stage2": KnockbackProfile(
        base_power=22.0,
        speed_weight=0.0,
        speed_thresholds=(),
        random_bonus=(0.0, 0.015),
        max_power=23.5,
    ),
    "hammer_shock_stage3": KnockbackProfile(
        base_power=28.0,
        speed_weight=0.0,
        speed_thresholds=(),
        random_bonus=(0.005, 0.02),
        max_power=29.5,
    ),
    "hammer_shock_crack": KnockbackProfile(
        base_power=6.0,
        speed_weight=0.0,
        speed_thresholds=(),
        random_bonus=(0.0, 0.005),
        max_power=6.5,
    ),
}


def compute_knockback_magnitude(profile_key: str, ball_speed: float = 0.0) -> float:
    """Return a positive knockback magnitude using a shared algorithm."""
    if profile_key not in KNOCKBACK_PROFILES:
        raise KeyError(f"Unknown knockback profile: {profile_key}")

    profile = KNOCKBACK_PROFILES[profile_key]
    power = profile.base_power + abs(ball_speed) * profile.speed_weight

    for threshold, multiplier in profile.speed_thresholds:
        if abs(ball_speed) >= threshold:
            power *= multiplier

    min_bonus, max_bonus = profile.random_bonus
    if max_bonus > 0:
        bonus = random.uniform(1.0 + min_bonus, 1.0 + max_bonus)
        power *= bonus

    if profile.max_power is not None:
        power = min(power, profile.max_power)

    return power


def _clear_poseidon_background(surface: pygame.Surface) -> None:
    """포세이돈 아이콘에 남아있는 청색 사각 배경을 제거한다."""
    width, height = surface.get_size()
    original = surface.copy()
    center_x = width / 2
    center_y = height / 2
    radius_limit = (min(width, height) / 2) - 5
    radius_limit_sq = radius_limit * radius_limit
    for y in range(height):
        for x in range(width):
            color = original.get_at((x, y))
            if color.a == 0:
                continue
            is_turquoise = color.r < 170 and color.g > 140 and color.b > 180
            low_alpha = color.a < 210
            if not (is_turquoise or low_alpha):
                continue

            dx = x - center_x
            dy = y - center_y
            dist_sq = dx * dx + dy * dy
            if color.a < 120 or y < 2 or dist_sq > radius_limit_sq:
                surface.set_at((x, y), (0, 0, 0, 0))


def _extract_ring_overlay(surface: pygame.Surface) -> pygame.Surface:
    """라그나로크 해머 프레임에서 붉은 링/코너 하이라이트만 추출한다."""
    overlay = pygame.Surface(surface.get_size(), pygame.SRCALPHA)
    width, height = surface.get_size()
    center_x, center_y = width // 2, height // 2

    for y in range(height):
        for x in range(width):
            color = surface.get_at((x, y))
            if color.a == 0:
                continue

            # 중앙으로부터의 거리 계산
            dist_from_center = math.sqrt((x - center_x) ** 2 + (y - center_y) ** 2)

            # 갈색 해머 손잡이 필터링 (갈색 계열 색상 제외)
            is_brown = (color.r > 100 and color.r < 180 and
                       color.g > 50 and color.g < 120 and
                       color.b < 80)

            # 중앙 근처의 색상 제외 (해머 손잡이 영역)
            in_center_area = dist_from_center < width * 0.35

            # 테두리 근처 여부 (더 두꺼운 테두리를 위해 범위 확장)
            near_edge = x < 10 or x >= width - 10 or y < 10 or y >= height - 10

            # 빨간색 계열 (테두리) - 임계값을 낮춰서 더 많은 테두리 포함
            red_dominant = color.r > 150 and color.r > color.g + 15 and color.r > color.b + 15

            # 따뜻한 하이라이트 (모서리 장식) - 임계값 조정
            warm_highlight = color.r > 180 and color.g > 100 and color.b > 60

            # 테두리나 하이라이트이면서, 갈색이 아니고, 중앙이 아닌 경우만 복사
            if (near_edge or red_dominant or warm_highlight) and not is_brown and not in_center_area:
                overlay.set_at((x, y), color)

    return overlay


def _draw_common_legendary_frame(screen: pygame.Surface,
                                 x: int,
                                 y: int,
                                 size: int,
                                 animation_time: float,
                                 border_color: Tuple[int, int, int] = COMMON_LEGENDARY_BORDER_COLOR,
                                 corner_color: Tuple[int, int, int] = COMMON_LEGENDARY_CORNER_COLOR,
                                 offset_animation_time: Optional[float] = None,
                                 corner_style: str = "default",
                                 draw_inner_pulse: bool = True) -> int:
    """전설 아이콘의 공통 배경 프레임을 그린다.

    Returns:
        int: 프레임과 아이콘에 적용할 Y 오프셋 (살짝 위아래로 흔들리는 효과).
    """
    # 테두리와 배경이 부드럽게 흔들리도록 오프셋 계산
    offset_source = animation_time if offset_animation_time is None else offset_animation_time
    frame_offset = int(math.sin(offset_source * 2.5) * 2)
    frame_y = y + frame_offset

    # 파란색 원형 배경 애니메이션 (외곽/중앙 두 겹으로 펄싱)
    pulse = (math.sin(animation_time * 4.0) + 1) / 2  # 0~1
    pulse_bucket = int(pulse * 20)  # 캐시 양자화 단계 (0~20)
    cache_key = (size, pulse_bucket)

    glow_surface = _COMMON_LEGENDARY_BG_CACHE.get(cache_key)
    if glow_surface is None:
        pulse_ratio = pulse_bucket / 20 if pulse_bucket else 0
        base_radius = max(6, int(size * 0.42))
        outer_radius = min(size // 2, int(base_radius + size * 0.05 * pulse_ratio))
        inner_radius = max(4, int(outer_radius * 0.65))

        glow_surface = pygame.Surface((size, size), pygame.SRCALPHA)
        center = (size // 2, size // 2)
        pygame.draw.circle(glow_surface, (30, 90, 170, 80), center, outer_radius)
        pygame.draw.circle(glow_surface, (70, 140, 200, 150), center, int(outer_radius * 0.85))
        pygame.draw.circle(glow_surface, (140, 190, 220, 190), center, inner_radius)
        _COMMON_LEGENDARY_BG_CACHE[cache_key] = glow_surface

    screen.blit(glow_surface, (x, frame_y))

    if draw_inner_pulse:
        # 내부 붉은색 테두리 (프레임별 그라데이션)
        inner_pulse = (math.sin(animation_time * 6.0) + 1) / 2
        outer_inner_color = (
            int(150 + 70 * inner_pulse),
            int(30 + 35 * inner_pulse),
            int(30 + 35 * inner_pulse)
        )
        inner_inner_color = (
            int(120 + 60 * inner_pulse),
            int(10 + 25 * inner_pulse),
            int(10 + 25 * inner_pulse)
        )

        inner_rect_outer = pygame.Rect(x + 2, frame_y + 2, size - 4, size - 4)
        inner_rect_mid = inner_rect_outer.inflate(-2, -2)
        inner_rect_inner = inner_rect_outer.inflate(-4, -4)

        mid_inner_color = (
            (outer_inner_color[0] + inner_inner_color[0]) // 2,
            (outer_inner_color[1] + inner_inner_color[1]) // 2,
            (outer_inner_color[2] + inner_inner_color[2]) // 2,
        )

        pygame.draw.rect(screen, outer_inner_color, inner_rect_outer, 1)
        pygame.draw.rect(screen, mid_inner_color, inner_rect_mid, 1)
        pygame.draw.rect(screen, inner_inner_color, inner_rect_inner, 1)

    # 공통 테두리와 코너 장식
    border_rect = pygame.Rect(x - 1, frame_y - 1, size + 2, size + 2)
    pygame.draw.rect(screen, border_color, border_rect, 2)

    if corner_style == "block":
        block_size = max(8, size // 6)
        for cx, cy in [(x, frame_y), (x + size, frame_y), (x, frame_y + size), (x + size, frame_y + size)]:
            block_rect = pygame.Rect(cx - block_size // 2, cy - block_size // 2, block_size, block_size)
            pygame.draw.rect(screen, corner_color, block_rect, border_radius=0)
    else:
        corner_size = 8
        pygame.draw.lines(screen, corner_color, False,
                          [(x - 2, frame_y + corner_size), (x - 2, frame_y - 2), (x + corner_size, frame_y - 2)], 2)
        pygame.draw.lines(screen, corner_color, False,
                          [(x + size - corner_size + 2, frame_y - 2), (x + size + 2, frame_y - 2), (x + size + 2, frame_y + corner_size)], 2)
        pygame.draw.lines(screen, corner_color, False,
                          [(x - 2, frame_y + size - corner_size + 2), (x - 2, frame_y + size + 2), (x + corner_size, frame_y + size + 2)], 2)
        pygame.draw.lines(screen, corner_color, False,
                          [(x + size - corner_size + 2, frame_y + size + 2), (x + size + 2, frame_y + size + 2), (x + size + 2, frame_y + size - corner_size + 2)], 2)

        for cx, cy in [(x, frame_y), (x + size, frame_y), (x, frame_y + size), (x + size, frame_y + size)]:
            pygame.draw.circle(screen, corner_color, (cx, cy), 2)

    return frame_offset


def _draw_glow_and_inner_only(screen: pygame.Surface,
                              x: int,
                              y: int,
                              size: int,
                              animation_time: float,
                              offset_animation_time: Optional[float] = None) -> int:
    """전설 프레임 중 '파란 글로우 + 내부 붉은 테두리'만 그린다.

    외곽 테두리 및 코너 장식은 그리지 않는다. frame_offset을 반환한다.
    """
    offset_source = animation_time if offset_animation_time is None else offset_animation_time
    frame_offset = int(math.sin(offset_source * 2.5) * 2)
    frame_y = y + frame_offset

    # 파란색 원형 글로우 (공통 캐시 활용)
    pulse = (math.sin(animation_time * 4.0) + 1) / 2
    pulse_bucket = int(pulse * 20)
    cache_key = (size, pulse_bucket)

    glow_surface = _COMMON_LEGENDARY_BG_CACHE.get(cache_key)
    if glow_surface is None:
        pulse_ratio = pulse_bucket / 20 if pulse_bucket else 0
        base_radius = max(6, int(size * 0.42))
        outer_radius = min(size // 2, int(base_radius + size * 0.05 * pulse_ratio))
        inner_radius = max(4, int(outer_radius * 0.65))

        glow_surface = pygame.Surface((size, size), pygame.SRCALPHA)
        center = (size // 2, size // 2)
        pygame.draw.circle(glow_surface, (30, 90, 170, 80), center, outer_radius)
        pygame.draw.circle(glow_surface, (70, 140, 200, 150), center, int(outer_radius * 0.85))
        pygame.draw.circle(glow_surface, (140, 190, 220, 190), center, inner_radius)
        _COMMON_LEGENDARY_BG_CACHE[cache_key] = glow_surface

    screen.blit(glow_surface, (x, frame_y))

    # 내부 붉은색 테두리 (3중 라인)
    inner_pulse = (math.sin(animation_time * 6.0) + 1) / 2
    outer_inner_color = (
        int(150 + 70 * inner_pulse),
        int(30 + 35 * inner_pulse),
        int(30 + 35 * inner_pulse),
    )
    inner_inner_color = (
        int(120 + 60 * inner_pulse),
        int(10 + 25 * inner_pulse),
        int(10 + 25 * inner_pulse),
    )
    mid_inner_color = (
        (outer_inner_color[0] + inner_inner_color[0]) // 2,
        (outer_inner_color[1] + inner_inner_color[1]) // 2,
        (outer_inner_color[2] + inner_inner_color[2]) // 2,
    )

    inner_rect_outer = pygame.Rect(x + 2, frame_y + 2, size - 4, size - 4)
    inner_rect_mid = inner_rect_outer.inflate(-2, -2)
    inner_rect_inner = inner_rect_outer.inflate(-4, -4)

    pygame.draw.rect(screen, outer_inner_color, inner_rect_outer, 1)
    pygame.draw.rect(screen, mid_inner_color, inner_rect_mid, 1)
    pygame.draw.rect(screen, inner_inner_color, inner_rect_inner, 1)

    return frame_offset


def _strip_legendary_red_ring(frame: pygame.Surface,
                              red_threshold: int = 150,
                              green_threshold: int = 100,
                              blue_threshold: int = 100,
                              background_rules: Optional[List[Callable[[pygame.Color], bool]]] = None) -> pygame.Surface:
    """전설 아이콘 PNG에 포함된 붉은 배경 링을 투명화한다."""
    cleaned_frame = pygame.Surface(frame.get_size(), pygame.SRCALPHA)
    width, height = frame.get_size()

    for py in range(height):
        for px in range(width):
            color = frame.get_at((px, py))
            if color.a == 0:
                continue

            remove = False
            if color.r > red_threshold and color.g < green_threshold and color.b < blue_threshold:
                remove = True

            if not remove and background_rules:
                for rule in background_rules:
                    if rule(color):
                        remove = True
                        break

            if remove:
                continue

            cleaned_frame.set_at((px, py), color)

    return cleaned_frame


def _render_empty_legendary_frame(size: int,
                                  animation_time: float,
                                  offset_time: float = 0.0) -> pygame.Surface:
    """외곽/내곽 프레임과 중앙 펄스만을 포함한 프레임 Surface 생성."""
    frame_surface = pygame.Surface((size, size), pygame.SRCALPHA)
    _draw_common_legendary_frame(
        frame_surface,
        0,
        0,
        size,
        animation_time,
        offset_animation_time=offset_time,
    )
    return frame_surface


class LegendaryItem:
    """전설 아이템 베이스 클래스"""
    def __init__(self, name: str, korean_name: str, description: str, 
                 unlock_condition: str, icon_path: Optional[str] = None):
        self.name = name
        self.korean_name = korean_name
        self.description = description
        self.unlock_condition = unlock_condition
        self.icon_path = icon_path
        self.unlocked = False
        self.active = False
        self.animation_offset = 0
        self.animation_time = 0
        self.glow_intensity = 0
        self.particle_timer = 0
        
    @property
    def display_name(self) -> str:
        return _t(f"legend.{self.name}", self.korean_name)

    @property
    def display_description(self) -> str:
        return _t(f"legend.{self.name}.desc", self.description)

    @property
    def display_unlock(self) -> str:
        return _t(f"legend.{self.name}.unlock", self.unlock_condition)

    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """해금 조건 체크 - 각 아이템별로 오버라이드"""
        return False
        
    def activate(self, game_state: Dict):
        """아이템 활성화 - 각 아이템별로 오버라이드"""
        self.active = True
        if LEGENDARY_DEBUG_ENABLED:
            print(f"   [{self.korean_name}] !")
        
    def deactivate(self):
        """아이템 비활성화"""
        self.active = False
        
    def update(self, dt: float, ui_mode: bool = False):
        """애니메이션 업데이트
        Args:
            dt: 델타 타임
            ui_mode: UI 모드 여부 (True면 게임플레이 효과 비활성화)
        """
        dt_seconds = dt / 1000.0 if dt > 1.5 else dt
        self.animation_time += dt_seconds
        # 아이콘 흔들림 효과
        self.animation_offset = math.sin(self.animation_time * 3.0) * 2
        # 글로우 펄싱 효과
        self.glow_intensity = (math.sin(self.animation_time * 2.0) + 1) / 2
        # 파티클 타이머 (초 단위)
        self.particle_timer += dt_seconds
        
    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """아이콘 그리기 with 전설 효과"""
        # 글로우 효과
        glow_size = int(size * (1.2 + self.glow_intensity * 0.1))
        glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)
        for i in range(3):
            alpha = 50 - i * 15
            pygame.draw.circle(glow_surf, (*LEGENDARY_COLOR, alpha), 
                             (glow_size//2, glow_size//2), 
                             glow_size//2 - i * 5)
        screen.blit(glow_surf, (x - (glow_size - size)//2, y - (glow_size - size)//2))
        
        # 붉은색 테두리
        border_rect = pygame.Rect(x-2, y-2, size+4, size+4)
        pygame.draw.rect(screen, LEGENDARY_COLOR, border_rect, 3)
        
        # 아이콘 (움직임 효과 적용)
        icon_y = y + int(self.animation_offset)
        if self.icon_path:
            try:
                icon = pygame.image.load(self.icon_path).convert_alpha()
                icon = pygame.transform.scale(icon, (size, size))
                screen.blit(icon, (x, icon_y))
            except:
                # 아이콘 로드 실패시 에러 표시
                pass
        else:
            # 아이콘 경로가 없으면 에러 표시
            pass
            
        # 파티클 효과 (가끔씩)
        if self.particle_timer > 1.0:  # 1초마다
            self._spawn_particle(screen, x + size//2, y + size//2)
            self.particle_timer = 0
            
        
    def _spawn_particle(self, screen: pygame.Surface, x: int, y: int):
        """파티클 스폰"""
        for _ in range(3):
            px = x + random.randint(-20, 20)
            py = y + random.randint(-20, 20)
            pygame.draw.circle(screen, LEGENDARY_COLOR, (px, py), random.randint(1, 3))


# 전설 아이템 정의
class InfinityGauntlet(LegendaryItem):
    """무한의 건틀릿 - 모든 스킬 쿨다운 50% 감소"""
    def __init__(self):
        super().__init__(
            name="infinity_gauntlet",
            korean_name="무한의 건틀릿",
            description="모든 스킬 쿨다운이 50% 감소합니다",
            unlock_condition="모든 스테이지를 노데미지로 클리어",
            icon_path="items/legendary/infinity_gauntlet.png"  # 아이콘 경로 추가
        )
        self.cooldown_reduction = 0.5
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """노데미지 올클리어 체크"""
        return game_stats.get("perfect_all_stages", False)
        
    def activate(self, game_state: Dict):
        super().activate(game_state)
        # 쿨다운 감소 적용
        if 'cooldown_multiplier' in game_state:
            game_state['cooldown_multiplier'] *= (1 - self.cooldown_reduction)


class PhoenixFeather(LegendaryItem):
    """불사조의 깃털 - 체력이 0이 되어도 한 번 부활"""
    def __init__(self):
        super().__init__(
            name="phoenix_feather",
            korean_name="불사조의 깃털",
            description="게임 오버 시 체력 50%로 한 번 부활합니다",
            unlock_condition="연속 100라운드 승리",
            icon_path="items/legendary/phoenix_feather.png"  # 아이콘 경로 추가
        )
        self.revival_used = False
        self.revival_health = 0.5
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """연속 100승 체크"""
        return game_stats.get("consecutive_wins", 0) >= 100
        
    def try_revive(self, current_health: int, max_health: int) -> Optional[int]:
        """부활 시도"""
        if self.active and not self.revival_used and current_health <= 0:
            self.revival_used = True
            new_health = int(max_health * self.revival_health)
            if LEGENDARY_DEBUG_ENABLED:
                print(f"   !  {new_health} !")
            return new_health
        return None


class ChronosClock(LegendaryItem):
    """크로노스의 시계 - 시간 조작 능력"""
    def __init__(self):
        super().__init__(
            name="chronos_clock",
            korean_name="크로노스의 시계",
            description="스페이스바로 3초간 시간을 느리게 만듭니다 (쿨다운 30초)",
            unlock_condition="단일 게임에서 10,000점 이상 획득",
            icon_path="items/legendary/chronos_clock.png"  # 아이콘 경로 추가
        )
        self.time_slow_duration = 3000  # 3초
        self.time_slow_cooldown = 30000  # 30초
        self.time_slow_active = False
        self.time_slow_timer = 0
        self.cooldown_timer = 0
        self.time_scale = 0.3  # 30% 속도
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """고득점 체크"""
        return game_stats.get("max_score", 0) >= 10000
        
    def activate_time_slow(self) -> bool:
        """시간 감속 발동"""
        if self.active and self.cooldown_timer <= 0:
            self.time_slow_active = True
            self.time_slow_timer = self.time_slow_duration
            self.cooldown_timer = self.time_slow_cooldown
            if LEGENDARY_DEBUG_ENABLED:
                print(f"   !  ...")
            return True
        return False
        
    def update_time_slow(self, dt: float) -> float:
        """시간 배율 업데이트"""
        if self.time_slow_active:
            self.time_slow_timer -= dt
            if self.time_slow_timer <= 0:
                self.time_slow_active = False
                pass  # print(f"")  # 디버그 비활성화
            return self.time_scale
        
        if self.cooldown_timer > 0:
            self.cooldown_timer -= dt
            
        return 1.0  # 정상 속도


class ExcaliburBlade(LegendaryItem):
    """엑스칼리버 - 공격력 대폭 증가"""
    def __init__(self):
        super().__init__(
            name="excalibur_blade",
            korean_name="엑스칼리버",
            description="모든 공격의 데미지가 2배가 됩니다",
            unlock_condition="단일 라운드에서 적을 30초 내에 처치",
            icon_path="items/legendary/excalibur_blade.png"  # 아이콘 경로 추가
        )
        self.damage_multiplier = 2.0
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """스피드런 체크"""
        return game_stats.get("fastest_round_time", float('inf')) <= 30
        
    def apply_damage(self, base_damage: float) -> float:
        """데미지 배율 적용"""
        if self.active:
            return base_damage * self.damage_multiplier
        return base_damage


class PoseidonTrident(LegendaryItem):
    """포세이돈의 삼지창 - 물의 신의 무기 (롤 옵션: 쿨타임)"""
    def __init__(self):
        super().__init__(
            name="poseidon_trident",
            korean_name="포세이돈의 삼지창",
            description="대시 시 거대한 물결 회오리를 생성하여 공을 튕겨냅니다 (롤 옵션: 쿨타임)",
            unlock_condition="스테이지 7 클리어",
            icon_path="items/legendary/poseidon_trident.png"
        )
        # 물의 파동 효과 제거됨 (순수 대시 보조용 아이템)
        # self.wave_effect_radius = 100  # 물결 효과 반경 (제거됨)
        # self.trajectory_influence = 0.15  # 궤적 영향력 (제거됨)
        self.dash_wave_force = 5.0  # 대시 시 물결 힘
        self.wave_timer = 0
        self.dash_wave_active = False
        self.dash_wave_timer = 0
        
        # 거대한 물결 회오리 효과 속성 - 양쪽 회오리 지원
        self.vortex_active = False
        self.vortex_timer = 0
        # 왼쪽 회오리
        self.vortex_left_x = 0
        self.vortex_left_y = 0
        self.vortex_left_height = 0  # 시작 높이
        # 오른쪽 회오리
        self.vortex_right_x = 0
        self.vortex_right_y = 0
        self.vortex_right_height = 0  # 시작 높이
        # 공통 속성
        self.vortex_max_height = 350  # 최대 높이 (화면의 약 47% 커버)
        self.vortex_width = 200  # 회오리 너비 (영향 반경 100픽셀)
        self.vortex_spin_speed = 0  # 회전 속도
        self.vortex_particles = []  # 회오리 파티클
        self.vortex_deflection_seed = 0  # 공 굴절 랜덤 시드
        
        # 공 회전 상태 추적
        self.ball_in_vortex = False  # 공이 회오리 안에 있는지
        self.ball_vortex_timer = 0  # 공이 회오리에 머무른 시간
        self.ball_vortex_angle = 0  # 공의 회전 각도
        self.ball_vortex_radius = 0  # 현재 회전 반경
        self.ball_capture_duration = 2  # 공을 잡고 있는 시간 (2 프레임 = 0.03초) - 즉시 튕겨냄
        self.vortex_center_x = 0  # 회오리 중심 X
        self.vortex_center_y = 0  # 회오리 중심 Y
        self.captured_ball_speed = 0  # 캡처된 공의 원래 속도
        self.vortex_cooldown = 0  # 회오리 재진입 쿨다운
        self.vortex_affected = False  # 회오리 효과를 받았는지
        self.original_ball_speed = 0  # 회오리 효과 전 원래 속도 저장
        self.speed_restored = False  # 속도가 이미 복원되었는지 추적
        self.boss_hit_count = 0  # 보스가 공을 친 횟수 추적
        
        # 물 궤적 효과
        self.water_trail = []  # 물에 젖은 공의 궤적
        self.water_trail_active = False  # 물 궤적 활성화 여부
        self.water_droplets = []  # 물방울 파티클
        
        # 공 반사 효과 속성
        self.deflection_power = 15.0  # 반사 힘
        self.spin_power = 8.0  # 드라이브 회전력
        
        # 물의 추진력 지속 효과
        self.water_momentum_active = False  # 물에서 나온 후 추진력 유지
        self.water_momentum_timer = 0  # 추진력 유지 타이머
        self.water_momentum_force_y = 0  # 유지되는 Y축 힘
        self.water_momentum_force_x = 0  # 유지되는 X축 힘

        # 효과 발동 쿨타임 시스템 (롤 옵션으로 결정)
        self.effect_cooldown = 0  # 현재 쿨타임 타이머
        self._base_cooldown_max = 6.0  # 기본 쿨타임 (롤 옵션으로 덮어씀)
        self.effect_ready = True  # 효과 발동 가능 여부
        self.enhancement_bonus_pct = 0  # 강화 보너스 퍼센트

        # 쿨타임 충전 완료 물의 기운 응축 파티클
        self.water_condensation_particles = []  # 물의 기운 응축 파티클
        self.water_condensation_active = False  # 응축 효과 활성화
        self.water_condensation_timer = 0  # 응축 효과 타이머
        self.water_explosion_particles = []  # 폭발 파티클
        self.water_explosion_active = False  # 폭발 효과 활성화
        self.water_explosion_timer = 0  # 폭발 효과 타이머
        self.player_position = (300, 550)  # 플레이어 위치 (업데이트됨)
        
        # 애니메이션용 아이콘 프레임들
        self.icon_frames = []
        self.animation_frames = []  # legendary_acquisition에서 사용하는 속성
        self.current_frame = 0
        self.frame_timer = 0
        self.frame_counter = 0  # 프레임 카운터 추가
        self.animation_speed = 8  # 애니메이션 속도 (라그나로크와 동일)
        self.load_animation_frames()
        
    def load_animation_frames(self):
        """애니메이션 프레임 로드 - PNG 파일 사용 (라그나로크/헤르메스와 동일)"""
        import pygame
        import os
        
        # 포세이돈 삼지창 PNG 파일 로드
        frames_loaded = 0
        background_rules = [
            lambda c: abs(c.r - c.g) < 10 and abs(c.g - c.b) < 10 and 60 <= c.r <= 120
        ]
        for i in range(8):
            frame_path = resource_path(f"items/legendary/poseidon_trident_frame_{i}.png")
            background_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                frame = pygame.image.load(frame_path).convert_alpha()
                foreground = _strip_legendary_red_ring(frame, background_rules=background_rules)

                try:
                    background = pygame.image.load(background_path).convert_alpha()
                except Exception:
                    background = pygame.Surface(foreground.get_size(), pygame.SRCALPHA)

                target_size = background.get_size()
                if foreground.get_size() != target_size:
                    foreground = pygame.transform.smoothscale(foreground, target_size)

                overlay = _extract_ring_overlay(background)
                composite = overlay
                composite.blit(foreground, (0, 0))
                _clear_poseidon_background(composite)

                self.icon_frames.append(composite)
                self.animation_frames.append(composite)  # legendary_acquisition에서 사용
                frames_loaded += 1
                pass  # print(f"✓ 포세이돈 삼지창 프레임 {i} 동기화 완료")  # 디버그 비활성화
            except Exception as e:
                pass  # print(f"[ERROR] Frame {i} load failed: {frame_path} - {e}")  # 디버그 비활성화

        pass  # print(f"포세이돈 삼지창: PNG 프레임 {frames_loaded}/8개 로드")  # 디버그 비활성화

        # 프레임이 없으면 에러만 표시 (가짜 애니메이션 생성하지 않음)
        if not self.icon_frames or len(self.icon_frames) == 0:
            pass  # print("❌ 포세이돈 삼지창: PNG 프레임을 찾을 수 없습니다!")  # 디버그 비활성화
                
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """스테이지 7 클리어 체크"""
        return game_stats.get("highest_stage_cleared", 0) >= 7

    @property
    def effect_cooldown_max(self) -> float:
        """쿨타임 (롤 옵션 적용, 연마 스킬 + 강화 보너스 포함)"""
        return get_legendary_roll_value("poseidon_trident", "cooldown", apply_polish=True, enhancement_bonus_pct=self.enhancement_bonus_pct)

    @property
    def gauge_cost(self) -> float:
        """게이지 소모량 (롤 옵션 적용, 연마 스킬 + 강화 보너스 포함)"""
        return get_legendary_roll_value("poseidon_trident", "gauge_cost", apply_polish=True, enhancement_bonus_pct=self.enhancement_bonus_pct)

    def activate(self, game_state: Dict):
        """삼지창 활성화"""
        if LEGENDARY_DEBUG_ENABLED:
            print(f"🔱 [BEFORE] PoseidonTrident.activate 호출, self.active = {self.active}")
        super().activate(game_state)  # 부모 클래스의 activate 호출 (self.active = True 설정)
        self.wave_timer = 0
        if LEGENDARY_DEBUG_ENABLED:
            print(f"🔱 [AFTER] {self.korean_name} 활성화!")
            print(f"   - self.active = {self.active}")
            print(f"   - 대시 시 거대한 물결 회오리 생성!")

        # 강제로 active 확인
        if not self.active:
            if LEGENDARY_DEBUG_ENABLED:
                print(f"⚠️ WARNING: self.active가 False입니다! 강제로 True로 설정합니다.")
            self.active = True
            
    def deactivate(self):
        """삼지창 비활성화"""
        self.active = False
        self.dash_wave_active = False
        
    def reset_round_effects(self):
        """라운드 종료 시 효과 초기화 (물방울 파티클 등)"""
        # 물방울 파티클 초기화
        self.water_droplets.clear()

        # 물 궤적 초기화
        self.water_trail.clear()
        self.water_trail_active = False

        # 회오리 효과 초기화
        self.vortex_active = False
        self.vortex_timer = 0
        self.vortex_particles.clear()
        self.vortex_left_height = 0
        self.vortex_right_height = 0

        # 공 캡처 상태 초기화
        self.ball_in_vortex = False
        self.ball_vortex_timer = 0
        self.vortex_cooldown = 0
        self.vortex_affected = False

        # 물 추진력 초기화
        self.water_momentum_active = False
        self.water_momentum_timer = 0
        self.water_momentum_force_y = 0
        self.water_momentum_force_x = 0

        # 쿨타임 시스템 초기화 (라운드 시작 시 바로 사용 가능)
        self.effect_cooldown = 0
        self.effect_ready = True

        # 물의 기운 응축/폭발 효과 초기화
        self.water_condensation_particles.clear()
        self.water_condensation_active = False
        self.water_condensation_timer = 0
        self.water_explosion_particles.clear()
        self.water_explosion_active = False
        self.water_explosion_timer = 0

        if LEGENDARY_DEBUG_ENABLED:
            print(f"🔱 포세이돈의 삼지창 라운드 효과 초기화")

    def stop_water_momentum(self):
        """물의 추진력 즉시 중단 (보스 패들에 맞았을 때)"""
        self.water_momentum_active = False
        self.water_momentum_timer = 0
        self.water_momentum_force_y = 0
        self.water_momentum_force_x = 0
        if LEGENDARY_DEBUG_ENABLED:
            print(f"🔱 물의 추진력 종료 - 보스 패들 충돌")
        
    def apply_trajectory_influence(self, ball_x: float, ball_y: float, 
                                  ball_vx: float, ball_vy: float, 
                                  paddle_x: float, paddle_y: float) -> Tuple[float, float]:
        """물의 파동 효과 제거됨 - 순수 대시 보조용"""
        # 물의 파동 효과는 제거되었습니다
        # 이제 포세이돈의 삼지창은 순수하게 대시 물결 회오리만 생성합니다
        return ball_vx, ball_vy
        
    def trigger_dash_wave(self, paddle_x: float, paddle_y: float, direction: int = 0) -> bool:
        """대시 후 통제불능 시 양쪽에 거대한 물결 회오리 발동

        Returns:
            bool: 효과가 발동되었으면 True, 쿨타임 중이면 False
        """
        if not self.active:
            if LEGENDARY_DEBUG_ENABLED:
                print(f"⚠️ 포세이돈 삼지창이 비활성화 상태입니다!")
            return False

        # 쿨타임 체크
        if not self.effect_ready:
            if LEGENDARY_DEBUG_ENABLED:
                print(f"🔱 포세이돈 삼지창 쿨타임 중: {self.effect_cooldown:.1f}초 남음")
            return False

        # 효과 발동 후 쿨타임 시작
        self.effect_ready = False
        self.effect_cooldown = self.effect_cooldown_max
        if LEGENDARY_DEBUG_ENABLED:
            print(f"🔱 포세이돈 삼지창 효과 발동! 쿨타임 {self.effect_cooldown_max}초 시작")

        self.dash_wave_active = True
        self.dash_wave_timer = 0
        
        # 거대한 물결 회오리 활성화 - 양쪽에 생성
        self.vortex_active = True
        self.vortex_timer = 0
        
        # 왼쪽 회오리 (패들 왼쪽 120픽셀)
        self.vortex_left_x = paddle_x - 120
        self.vortex_left_y = paddle_y
        self.vortex_left_height = 0
        
        # 오른쪽 회오리 (패들 오른쪽 120픽셀)
        self.vortex_right_x = paddle_x + 120
        self.vortex_right_y = paddle_y
        self.vortex_right_height = 0
        
        self.vortex_spin_speed = 0
        
        
        # 양쪽 회오리에 대한 파티클 대량 생성 (용솟음치는 효과)
        # 왼쪽 회오리 파티클
        for i in range(30):  # 각 회오리당 30개
            angle = (i / 10) * math.pi * 2
            height_offset = random.uniform(0, 200)
            particle = {
                "x": self.vortex_left_x + random.uniform(-30, 30),
                "y": self.vortex_left_y - height_offset,
                "vx": math.cos(angle) * random.uniform(2, 8),
                "vy": random.uniform(-8, -3),  # 위로 솟구치는 속도
                "life": random.randint(40, 80),
                "color": (50, 150 + random.randint(0, 100), 255),
                "size": random.uniform(3, 10),
                "spiral_angle": angle,
                "spiral_radius": random.uniform(20, 60),
                "vortex_side": "left"  # 왼쪽 회오리 표시
            }
            self.vortex_particles.append(particle)
        
        # 오른쪽 회오리 파티클
        for i in range(30):  # 각 회오리당 30개
            angle = (i / 10) * math.pi * 2
            height_offset = random.uniform(0, 200)
            particle = {
                "x": self.vortex_right_x + random.uniform(-30, 30),
                "y": self.vortex_right_y - height_offset,
                "vx": math.cos(angle) * random.uniform(2, 8),
                "vy": random.uniform(-8, -3),  # 위로 솟구치는 속도
                "life": random.randint(40, 80),
                "color": (50, 150 + random.randint(0, 100), 255),
                "size": random.uniform(3, 10),
                "spiral_angle": angle,
                "spiral_radius": random.uniform(20, 60),
                "vortex_side": "right"  # 오른쪽 회오리 표시
            }
            self.vortex_particles.append(particle)

        return True  # 효과 발동 성공

    def apply_dash_wave_to_ball(self, ball_x: float, ball_y: float,
                               ball_vx: float, ball_vy: float,
                               paddle_x: float, paddle_y: float,
                               player_x: float = None, player_y: float = None) -> Tuple[float, float]:
        """거대한 물결 회오리가 공에 미치는 굴절 효과 (Stage 4 자기장과 동일한 메커니즘)"""
        
        # 회오리 효과를 받은 공이 보스에게 맞았는지 확인
        if self.vortex_affected:
            # 회오리 효과를 받은 공이 보스에게 맞았는지 확인
            if LEGENDARY_DEBUG_ENABLED:
                print(f"🔍 [물회오리 디버그] vortex_affected={self.vortex_affected}, ball_vy={ball_vy:.1f}, original_speed={self.original_ball_speed:.1f}")
                print(f"🔍 [물회오리 디버그] 현재 속도: vx={ball_vx:.1f}, vy={ball_vy:.1f}, total={math.sqrt(ball_vx**2 + ball_vy**2):.1f}")
                print(f"🔍 [물회오리 디버그] boss_hit_count={self.boss_hit_count}")
            
            # 보스가 실제로 공을 친 경우에만 속도 복원
            if self.boss_hit_count > 0:
                current_speed = math.sqrt(ball_vx ** 2 + ball_vy ** 2)
                if current_speed > 0:
                    # 무조건 현재 속도의 50%로 감속
                    target_speed = current_speed * 0.5
                    speed_ratio = target_speed / current_speed
                    new_vx = ball_vx * speed_ratio
                    new_vy = ball_vy * speed_ratio
                    if LEGENDARY_DEBUG_ENABLED:
                        print(f"🔱 [포세이돈] 보스 반격 - 속도 50% 감속: {current_speed:.1f} → {target_speed:.1f}")
                        print(f"🔍 [물회오리 디버그] 속도 조정: vx {ball_vx:.1f} → {new_vx:.1f}, vy {ball_vy:.1f} → {new_vy:.1f}")
                    
                    # 회오리 효과 플래그 해제
                    self.vortex_affected = False
                    self.original_ball_speed = 0
                    self.boss_hit_count = 0  # 카운트 리셋
                    
                    # 물 궤적 종료
                    self.water_trail_active = False
                    # 물 궤적 종료
                    
                    # 복원된 속도 반환
                    # 속도 복원 완료
                    return new_vx, new_vy
                else:
                    if LEGENDARY_DEBUG_ENABLED:
                        print(f"🔍 [DEBUG] 속도 복원 실패: current_speed={current_speed:.1f}, original_speed={self.original_ball_speed:.1f}")
        
        # 원래 속도 저장 (디버그용)
        original_speed = math.sqrt(ball_vx ** 2 + ball_vy ** 2)
        
        # 물 추진력이 남아있으면 계속 적용
        if self.water_momentum_active:
            # 추진력 타이머 감소
            self.water_momentum_timer -= 0.016  # 60fps 기준
            
            if self.water_momentum_timer <= 0:
                # 추진력 종료
                self.water_momentum_active = False
                self.water_momentum_force_y = 0
                self.water_momentum_force_x = 0
            else:
                # 추진력 적용 (시간이 지나면서 약해짐)
                fade_factor = self.water_momentum_timer / 2.0  # 2초 동안 서서히 감소
                new_vx = ball_vx + self.water_momentum_force_x * fade_factor
                new_vy = ball_vy + self.water_momentum_force_y * fade_factor
                return (new_vx, new_vy)
        
        if not self.dash_wave_active and not self.vortex_active:
            # 회오리가 비활성화되면 캡처 상태 초기화
            if self.ball_in_vortex:
                self.ball_in_vortex = False
                self.ball_vortex_timer = 0
            return ball_vx, ball_vy
            
        # 거대한 회오리 효과 (우선 처리) - 양쪽 회오리 체크
        # 소멸 단계(타이머 >= 48)에서는 효과 비활성화
        if self.vortex_active and self.vortex_timer < 48:
            # 회오리의 Y축 범위 (시간에 따라 확장)
            left_vortex_height = min(self.vortex_left_height, self.vortex_max_height)
            right_vortex_height = min(self.vortex_right_height, self.vortex_max_height)
            
            # 왼쪽 회오리 충돌 체크
            x_distance_left = abs(ball_x - self.vortex_left_x)
            x_in_left_vortex = x_distance_left <= (self.vortex_width / 2)  # 회오리 반경 100픽셀
            # Y축 체크: 회오리는 아래에서 위로 올라가므로, 공이 회오리 높이 범위 안에 있는지 체크
            # 회오리 아래쪽(패들 위치)부터 위로 솟은 높이까지 + 여유 공간
            y_in_left_vortex = (self.vortex_left_y - left_vortex_height - 20) <= ball_y <= (self.vortex_left_y + 100)
            
            # 오른쪽 회오리 충돌 체크
            x_distance_right = abs(ball_x - self.vortex_right_x)
            x_in_right_vortex = x_distance_right <= (self.vortex_width / 2)  # 회오리 반경 100픽셀
            # Y축 체크: 회오리는 아래에서 위로 올라가므로, 공이 회오리 높이 범위 안에 있는지 체크
            y_in_right_vortex = (self.vortex_right_y - right_vortex_height - 20) <= ball_y <= (self.vortex_right_y + 100)
            
            # 어느 쪽 회오리에든 들어갔는지 확인
            in_left = x_in_left_vortex and y_in_left_vortex
            in_right = x_in_right_vortex and y_in_right_vortex
            
            # 디버그: 회오리 위치와 크기 (최초 1회만)
            if not hasattr(self, '_vortex_debug_shown') and LEGENDARY_DEBUG_ENABLED:
                print(f"   최대 높이: {self.vortex_max_height:.0f}")
                self._vortex_debug_shown = True
            in_any_vortex = in_left or in_right
            
            # 어느 회오리에 들어갔는지에 따라 중심점 결정
            if in_left:
                vortex_x = self.vortex_left_x
                vortex_y = self.vortex_left_y
                current_vortex_height = left_vortex_height
                vortex_side = "왼쪽"
            elif in_right:
                vortex_x = self.vortex_right_x
                vortex_y = self.vortex_right_y
                current_vortex_height = right_vortex_height
                vortex_side = "오른쪽"
            else:
                vortex_x = 0
                vortex_y = 0
                current_vortex_height = 0
                vortex_side = "없음"
                # 회오리 밖에 있으면 캡처 상태 해제
                if self.ball_in_vortex:
                    self.ball_in_vortex = False
                    self.ball_vortex_timer = 0
                    self.vortex_cooldown = 30  # 쿨다운 설정
            
            # 디버그: 충돌 체크 상태 (항상 출력)
            if pygame.time.get_ticks() % 100 < 16:  # 0.1초마다 한 번
                if in_left:
                    pass  # Debug log removed
                elif in_right:
                    pass  # Debug log removed
            
            if in_any_vortex:
                
                # 플레이어가 발사한 공(위로 향하는 공)은 회오리 효과 무시
                if ball_vy < 0:  # 공이 위로 향하고 있음 = 플레이어가 친 공
                    return ball_vx, ball_vy
                
                # 보스가 친 공(아래로 향하는 공)에만 회오리 효과 적용
                # === 단순하고 강력한 즉시 반사 (복잡한 간섭 제거) ===
                
                # 보스가 친 공은 회오리에 닿으면 즉시 강력하게 반사 (간섭 없이)
                # 단, 이미 회오리 효과를 받았거나 쿨다운 중이면 무시
                if ball_vy > 0 and not self.vortex_affected and self.vortex_cooldown <= 0:  # 보스가 친 공
                    if LEGENDARY_DEBUG_ENABLED:
                        print(f"🌊 [즉시 반사] 보스 공 회오리 접촉!")
                    current_ball_speed = math.sqrt(ball_vx**2 + ball_vy**2)

                    # 원래 속도 저장 (복원용)
                    self.original_ball_speed = current_ball_speed
                    self.vortex_affected = True  # 회오리 효과를 받았음을 표시
                    self.boss_hit_count = 0  # 보스 히트 카운트 리셋
                    if LEGENDARY_DEBUG_ENABLED:
                        print(f"🔍 [즉시 반사] vortex_affected=True 설정, original_speed={self.original_ball_speed:.1f}, boss_hit_count=0")

                    # 물 궤적 활성화 (즉시 반사 후에도 궤적 유지)
                    self.water_trail_active = True
                    if LEGENDARY_DEBUG_ENABLED:
                        print(f"🌊 [즉시 반사] 물 궤적 활성화!")

                    # 랜덤 증폭 반사 (현재 공 속도의 150~200%)
                    amplify_factor = random.uniform(1.5, 2.0)  # 1.5배~2배 랜덤
                    amplified_speed = current_ball_speed * amplify_factor

                    # 최소 속도 보장 (회오리 영역을 확실히 벗어나도록)
                    min_speed = 20.0  # 최소 속도
                    if amplified_speed < min_speed:
                        amplified_speed = min_speed

                    if LEGENDARY_DEBUG_ENABLED:
                        print(f"🔍 [물회오리 즉시반사] 원래 속도: {current_ball_speed:.1f} × {amplify_factor:.2f} = 증폭 속도: {amplified_speed:.1f}")

                    # 위쪽 방향 랜덤 반사 (-90도 기준 ±30도) - 더 위쪽으로
                    base_angle = -math.pi / 2  # -90도 (위쪽)
                    random_spread = math.pi / 6  # ±30도 (더 좁은 범위)
                    random_offset = random.uniform(-random_spread, random_spread)
                    target_angle = base_angle + random_offset

                    # 최종 속도 계산 (간섭 없음)
                    final_vx = math.cos(target_angle) * amplified_speed
                    final_vy = math.sin(target_angle) * amplified_speed

                    if LEGENDARY_DEBUG_ENABLED:
                        print(f"🌊 [즉시 반사] 속도: {current_ball_speed:.1f} → {amplified_speed:.1f} ({amplify_factor:.1f}배) | 각도: {math.degrees(target_angle):.1f}도")
                        print(f"🌊 [즉시 반사] 결과: vx={final_vx:.1f}, vy={final_vy:.1f}")
                    
                    # 반사된 공의 현재 위치를 물궤적에 추가
                    self.update_water_trail(ball_x, ball_y)
                    
                    # 재진입 방지를 위한 쿨다운 설정
                    self.vortex_cooldown = 60  # 1초 쿨다운
                    
                    return final_vx, final_vy  # 즉시 반환하여 복잡한 간섭 제거
                
                # === 기존의 복잡한 Stage 4 굴절자기장 메커니즘 (플레이어 공용, 사실상 사용 안됨) ===
                # 회오리 중심과의 거리 계산
                # 회오리는 패들 위치에서 위로 솟아오르므로, Y축 거리는 회오리 범위 내에서만 계산
                vortex_center_y = vortex_y - current_vortex_height/2  # 회오리의 실제 중심
                # 공이 회오리 Y 범위 내에 있으면 Y축 거리는 0으로 처리
                # 바운딩 범위와 일치하도록 아래쪽 여유도 포함
                if vortex_y - current_vortex_height <= ball_y <= vortex_y + 20:
                    y_distance = 0  # 회오리 Y 범위 내에 있음
                else:
                    y_distance = abs(ball_y - vortex_center_y)
                
                distance = math.sqrt((ball_x - vortex_x) ** 2 + y_distance ** 2)
                
                # 회오리 반경 (충돌 범위를 더 크게 설정)
                # 시각 효과와 동일하게 설정하여 보이는 대로 작동하도록 함
                vortex_radius = min(self.vortex_width / 2, 100)  # 최대 반경 100
                
                # 공이 회오리에 처음 들어왔는지 확인 (바운딩에 있으면 더 관대하게)
                capture_threshold = vortex_radius * 0.9 if in_any_vortex else vortex_radius * 0.8
                if not self.ball_in_vortex and self.vortex_cooldown <= 0 and distance < capture_threshold:
                    # 공 캡처 시작
                    self.ball_in_vortex = True
                    self.ball_vortex_timer = 0
                    self.vortex_center_x = vortex_x
                    # 회오리 중심을 더 위쪽으로 설정하여 수평 왕복 방지
                    self.vortex_center_y = vortex_center_y - 20  # 중심을 위로 이동
                    self.ball_vortex_angle = math.atan2(ball_y - self.vortex_center_y, ball_x - vortex_x)
                    self.ball_vortex_radius = distance
                    self.captured_ball_speed = math.sqrt(ball_vx ** 2 + ball_vy ** 2)
                    self.original_ball_speed = self.captured_ball_speed  # 원래 속도 저장
                    
                    if LEGENDARY_DEBUG_ENABLED:
                        print(f"🌊 [포세이돈 DEBUG] 공 캡처! 입력 속도: {self.captured_ball_speed:.1f}")

                    # 물 궤적 시작
                    self.water_trail_active = True
                    self.water_trail = []  # 새로운 궤적 시작
                    if LEGENDARY_DEBUG_ENABLED:
                        print(f"[DEBUG] 물 궤적 활성화! 공 위치: ({ball_x:.0f}, {ball_y:.0f})")
                
                # 공이 회오리에 캡처되어 있는 경우 - 빙글빙글 회전
                if self.ball_in_vortex:
                    self.ball_vortex_timer += 1
                    
                    # 회전 각속도 (빠르게 회전)
                    rotation_speed = 0.4  # 라디안/프레임
                    self.ball_vortex_angle += rotation_speed
                    
                    # 회전 반경 점진적으로 감소 (중심으로 끌어당김)
                    self.ball_vortex_radius *= 0.95
                    if self.ball_vortex_radius < 10:
                        self.ball_vortex_radius = 10
                    
                    # 회전하는 공의 새 위치 계산 (위쪽으로 이동하도록 Y 오프셋 추가)
                    vertical_offset = -self.ball_vortex_timer * 0.5  # 시간에 따라 위로 이동
                    new_ball_x = self.vortex_center_x + math.cos(self.ball_vortex_angle) * self.ball_vortex_radius
                    new_ball_y = self.vortex_center_y + math.sin(self.ball_vortex_angle) * self.ball_vortex_radius + vertical_offset
                    
                    # 물 궤적 업데이트 (회전 중인 공 위치 추적)
                    self.update_water_trail(new_ball_x, new_ball_y)
                    
                    # 공 속도를 회전 운동으로 변경
                    # 목표 위치로 부드럽게 이동하기 위한 속도 계산
                    dx = new_ball_x - ball_x
                    dy = new_ball_y - ball_y
                    
                    # 스무스한 이동을 위해 속도 조정 (회전 속도 유지)
                    # 원래 속도의 일부만 적용하여 부드러운 회전
                    smooth_factor = 0.5  # 50% 속도로 목표 위치로 이동 (0.3에서 증가)
                    new_vx = dx * smooth_factor
                    new_vy = dy * smooth_factor
                    
                    # 캡처 중 아래 방향 이동 방지 및 수평 왕복 방지
                    if new_vy >= 0:  # 하향 또는 수평 이동
                        # 상향 이동 강제 (회전 각도에 따라 조정)
                        upward_force = -5 - abs(math.sin(self.ball_vortex_angle) * 3)
                        new_vy = upward_force
                        if abs(new_vx) > 5:  # 수평 속도가 너무 강하면 감소
                            new_vx *= 0.6
                        if LEGENDARY_DEBUG_ENABLED:
                            print(f"[DEBUG] 회오리 상향 강제: vx={new_vx:.1f}, vy={new_vy:.1f}")
                    
                    # 최소 속도 보장 (회전 운동 유지)
                    min_speed = 8  # 최소 속도
                    current_speed = math.sqrt(new_vx * new_vx + new_vy * new_vy)
                    if current_speed < min_speed and current_speed > 0:
                        # 속도가 너무 느리면 최소 속도로 증가
                        speed_ratio = min_speed / current_speed
                        new_vx *= speed_ratio
                        new_vy *= speed_ratio
                        # 상향 성분 추가 보장
                        if new_vy > -2:
                            new_vy = -2
                        if LEGENDARY_DEBUG_ENABLED:
                            print(f"[DEBUG] 회오리 속도 보정: {current_speed:.1f} → {min_speed:.1f}")
                    
                    # 속도 제한 (너무 빠르면 순간이동처럼 보임)
                    max_speed = 15
                    speed = math.sqrt(new_vx * new_vx + new_vy * new_vy)
                    if speed > max_speed:
                        new_vx = new_vx / speed * max_speed
                        new_vy = new_vy / speed * max_speed
                    
                    # 캡처 시간이 끝나면 랜덤 방향으로 튕겨냄
                    if self.ball_vortex_timer >= self.ball_capture_duration:
                        if LEGENDARY_DEBUG_ENABLED:
                            print(f"🌊 [포세이돈 DEBUG] 캡처 완료! 타이머: {self.ball_vortex_timer}/{self.ball_capture_duration}")
                        # 포세이돈의 삼지창은 항상 보스 쪽(위쪽)으로 공을 튕겨냄
                        # 플레이어에게 유리하도록 작동
                        
                        # 위쪽 부채꼴 범위로 반사 (안전한 범위)
                        base_angle = -math.pi / 2  # -90도 (위쪽)
                        fan_spread = math.pi / 6  # 30도로 더 축소 (안전한 각도)
                        
                        # 랜덤 시드 생성
                        self.vortex_deflection_seed = (ball_x * 1000 + ball_y * 100 + self.vortex_timer * 10) % 10000
                        random.seed(int(self.vortex_deflection_seed))
                        random_offset = random.uniform(-fan_spread, fan_spread)
                        random.seed()  # 시드 초기화
                        
                        target_angle = base_angle + random_offset
                        
                        # 반사 속도 (현재 공 속도의 150~200% 랜덤 증폭)
                        amplify_factor = random.uniform(1.5, 2.0)  # 1.5배~2배 랜덤
                        deflect_speed = self.captured_ball_speed * amplify_factor
                        new_vx = math.cos(target_angle) * deflect_speed
                        new_vy = math.sin(target_angle) * deflect_speed
                        
                        if LEGENDARY_DEBUG_ENABLED:
                            print(f"🌊 [포세이돈 DEBUG] 속도 계산: {self.captured_ball_speed:.1f} → {deflect_speed:.1f} ({amplify_factor:.1f}배 랜덤)")
                            print(f"🌊 [포세이돈 DEBUG] 각도 계산: {math.degrees(target_angle):.1f}도")
                        
                        # Y축 속도 안전장치 - 반드시 위쪽으로 향하도록 보장
                        min_upward_speed = -50  # 최소 위쪽 속도 (극도로 빠르게)
                        max_upward_speed = -30  # 최대 위쪽 속도 (매우 빠르게)
                        
                        # Y 속도가 아래쪽이거나 너무 느리면 강제로 위쪽으로
                        original_vy = new_vy
                        if new_vy >= 0:  # 아래쪽이나 수평이면
                            new_vy = min_upward_speed  # 강제로 위쪽으로
                            if LEGENDARY_DEBUG_ENABLED:
                                print(f"🌊 [포세이돈 DEBUG] Y축 보정: {original_vy:.1f} → {new_vy:.1f} (아래쪽→위쪽)")
                        elif new_vy > max_upward_speed:  # 위쪽이지만 너무 느리면
                            new_vy = max_upward_speed
                            if LEGENDARY_DEBUG_ENABLED:
                                print(f"🌊 [포세이돈 DEBUG] Y축 보정: {original_vy:.1f} → {new_vy:.1f} (너무 느림)")
                        elif new_vy < min_upward_speed:  # 너무 빠르면
                            new_vy = min_upward_speed
                            if LEGENDARY_DEBUG_ENABLED:
                                print(f"🌊 [포세이돈 DEBUG] Y축 보정: {original_vy:.1f} → {new_vy:.1f} (너무 빠름)")
                        
                        # X축 속도도 너무 극단적이지 않도록 제한
                        max_x_speed = 50  # 횡방향 속도 제한 (극도로 빠르게)
                        original_vx = new_vx
                        if abs(new_vx) > max_x_speed:
                            new_vx = max_x_speed if new_vx > 0 else -max_x_speed
                            if LEGENDARY_DEBUG_ENABLED:
                                print(f"🌊 [포세이돈 DEBUG] X축 보정: {original_vx:.1f} → {new_vx:.1f} (속도 제한)")
                        
                        # 최종 속도 계산 및 출력
                        final_speed = math.sqrt(new_vx ** 2 + new_vy ** 2)
                        if LEGENDARY_DEBUG_ENABLED:
                            print(f"🌊 [포세이돈 DEBUG] 최종 튕김: vx={new_vx:.1f}, vy={new_vy:.1f}, 총속도={final_speed:.1f}")
                        
                        # 캡처 상태 해제 및 쿨다운 설정
                        self.ball_in_vortex = False
                        self.ball_vortex_timer = 0
                        self.vortex_cooldown = 30  # 0.5초 쿨다운
                        self.vortex_affected = True  # 회오리 효과를 받았음을 표시
                        self.speed_restored = False  # 속도 복원 플래그 초기화
                        if LEGENDARY_DEBUG_ENABLED:
                            print(f"[DEBUG] vortex_affected 플래그 설정! original_ball_speed={self.original_ball_speed}")
                        # 물 궤적은 계속 유지 (보스가 칠 때까지)
                    
                    return new_vx, new_vy
                
                # 아직 캡처되지 않은 공이 회오리 영향권에 있는 경우 - 효과 제거
                # (캡처 효과만 사용하고, 캡처되지 않은 공은 영향 없음)
                elif False:  # 비활성화 - 캡처되지 않은 공은 영향 없음
                    
                    # 거리 기반 굴절 강도 계산 (중심에 가까울수록 강함)
                    refraction_strength = 1.0 - (distance / vortex_radius)
                    # 굴절 강도 대폭 증가 (최소 0.7 보장)
                    refraction_strength = max(0.7, refraction_strength)  # 최소 70% 강도 보장
                    
                    
                    # 현재 속도 벡터의 각도와 속력
                    current_angle = math.atan2(ball_vy, ball_vx)
                    current_speed = math.sqrt(ball_vx ** 2 + ball_vy ** 2)
                    
                    # 회오리에 들어온 공은 빙글빙글 돌다가 랜덤하게 튀겨냄
                    # 공의 회전 각도 계산 (회오리 중심 기준)
                    spin_angle = math.atan2(ball_y - vortex_y, ball_x - vortex_x)
                    spin_angle += self.vortex_timer * 10  # 시간에 따른 회전
                    
                    # 회전 반경을 점진적으로 줄여가며 중심으로 끌어당김
                    spin_radius = distance * (0.8 + 0.2 * math.sin(self.vortex_timer * 5))
                    
                    # 랜덤 방향 결정 (부채꼴 범위 내에서)
                    if ball_vy > 0:  # 보스가 친 공 (아래로 향하는)
                        # 보스 방향으로 부채꼴 범위 내에서 랜덤 반사
                        # 기본 방향: 직진 위로 (90도)
                        base_angle = -math.pi / 2  # -90도 (위쪽)
                        
                        # 부채꼴 범위: 왼우 60도씩 (120도 범위)
                        fan_spread = math.pi / 3  # 60도
                        # 공의 위치와 시간을 기반으로 랜덤 시드 생성
                        self.vortex_deflection_seed = (ball_x * 1000 + ball_y * 100 + self.vortex_timer * 10) % 10000
                        random.seed(int(self.vortex_deflection_seed))
                        random_offset = random.uniform(-fan_spread, fan_spread)
                        random.seed()  # 시드 초기화
                        
                        target_angle = base_angle + random_offset
                        
                        # 보스 방향으로 약간 편향
                        boss_x = 300  # 화면 중앙
                        boss_y = 50   # 보스 위치
                        angle_to_boss = math.atan2(boss_y - ball_y, boss_x - ball_x)
                        target_angle = target_angle * 0.7 + angle_to_boss * 0.3
                        
                        direction_to_target_x = math.cos(target_angle)
                        direction_to_target_y = math.sin(target_angle)
                    else:
                        # 플레이어가 친 공은 원래 방향 유지 (하지만 이미 위에서 걸러짐)
                        if player_x is None:
                            player_x = 300
                        if player_y is None:
                            player_y = 550
                        direction_to_target_x = player_x - ball_x
                        direction_to_target_y = player_y - ball_y
                        distance_to_target = math.sqrt(direction_to_target_x ** 2 + direction_to_target_y ** 2)
                        
                        if distance_to_target > 0:
                            direction_to_target_x /= distance_to_target
                            direction_to_target_y /= distance_to_target
                    
                    # 목표 각도
                    target_angle = math.atan2(direction_to_target_y, direction_to_target_x)
                    
                    # 각도 차이 계산
                    angle_diff = target_angle - current_angle
                    # 각도를 -π ~ π 범위로 정규화 (최적화)
                    angle_diff = math.atan2(math.sin(angle_diff), math.cos(angle_diff))
                    
                    # 굴절 적용 (강력한 굴절 효과)
                    # 보스가 친 공은 강하게 반사
                    if ball_vy > 0:  # 보스가 친 공
                        # 매우 강력한 굴절 (거의 직각으로 반사)
                        max_refraction = 3.14  # π radians (180도 - 완전 역방향)
                        refraction_amount = angle_diff * refraction_strength * 1.5  # 150% 굴절
                    else:
                        max_refraction = 0.52  # 약 30도 in radians
                        refraction_amount = angle_diff * refraction_strength * 0.3
                    refraction_amount = max(-max_refraction, min(max_refraction, refraction_amount))
                    
                    # 새로운 각도 계산
                    new_angle = current_angle + refraction_amount
                    
                    # 빙글빙글 회전 효과 강화
                    spin_effect = math.sin(self.vortex_timer * 12) * 0.3 * refraction_strength
                    new_angle += spin_effect
                    
                    # 회전 가속도 추가 (회오리에 빨려들어가는 효과)
                    if distance < vortex_radius * 0.5:  # 중심 근처
                        spin_acceleration = 0.2 * (1 - distance / (vortex_radius * 0.5))
                        new_angle += spin_acceleration * self.vortex_timer
                    
                    # 속도는 기본적으로 유지 (캡처되지 않은 공은 속도 변화 없음)
                    new_speed = current_speed
                    
                    # 보스가 친 공만 약간의 영향
                    if ball_vy > 0:  # 보스가 친 공
                        # 회오리 근처에서 약간의 가속 (회오리의 끌어당기는 효과)
                        if distance < vortex_radius * 0.5:
                            new_speed = current_speed * 1.1  # 10% 가속
                    else:
                        # 플레이어가 친 공은 속도 유지
                        new_speed = current_speed
                    
                    # 새로운 속도 벡터 계산
                    new_vx = math.cos(new_angle) * new_speed
                    new_vy = math.sin(new_angle) * new_speed
                    
                    # X축 속도는 크게 변경하지 않음 (약간의 회전 효과만)
                    # 원래 X속도를 대부분 유지
                    x_blend_factor = 0.2  # 20%만 새로운 속도 적용 (기존 속도 80% 유지)
                    new_vx = ball_vx * (1.0 - x_blend_factor) + new_vx * x_blend_factor
                    
                    # X축 속도 상한 설정 (너무 빠른 횡방향 이동 방지)
                    max_x_speed = 12.0
                    if abs(new_vx) > max_x_speed:
                        new_vx = max_x_speed if new_vx > 0 else -max_x_speed
                    
                    # 보스가 친 공은 위로 반사되도록 Y축 속도 조정 + 강력한 속도 증폭
                    if ball_vy > 0:  # 보스가 친 공
                        # 일정한 고속 반사 (편차 없이 항상 동일한 고속)
                        current_ball_speed = math.sqrt(ball_vx**2 + ball_vy**2)
                        amplified_speed = 65  # 항상 고정된 고속 (편차 제거)
                        
                        # 기본 위쪽 방향 (-90도)에서 좌우 60도 범위로 랜덤 반사
                        base_angle = -math.pi / 2  # -90도 (위쪽)
                        fan_spread = math.pi / 3  # 60도
                        random_offset = random.uniform(-fan_spread, fan_spread)
                        target_angle = base_angle + random_offset
                        
                        # 강력한 반사 속도 계산
                        new_vx = math.cos(target_angle) * amplified_speed
                        new_vy = math.sin(target_angle) * amplified_speed
                        
                        # Y축 속도 보정 (반드시 위쪽으로)
                        if new_vy >= 0:
                            new_vy = -40  # 강제로 위쪽 방향
                        elif new_vy < -50:
                            new_vy = -50  # 너무 빠르면 제한
                        
                        if LEGENDARY_DEBUG_ENABLED:
                            print(f"🌊 [보스공 반사] 속도: {current_ball_speed:.1f} → {amplified_speed} (고정 고속)")
                            print(f"🌊 [보스공 반사] 최종: vx={new_vx:.1f}, vy={new_vy:.1f}")
                    else:
                        # 플레이어가 친 공은 회오리 영향을 받지 않음
                        return ball_vx, ball_vy  # 원래 속도 그대로 반환
                    
                    # 물 추진력 비활성화 (회오리 밖에서 영향을 주지 않도록)
                    # 원래는 물에서 나온 후에도 추진력이 지속되었지만, 이제는 회오리 안에서만 작동
                    self.water_momentum_active = False
                    self.water_momentum_timer = 0
                    self.water_momentum_force_y = 0
                    self.water_momentum_force_x = 0
                    
                    
                    return new_vx, new_vy
                else:
                    # 회오리 범위 밖
                    return ball_vx, ball_vy
            else:
                # 회오리 충돌 범위 밖
                # 추진력이 활성화되어 있으면 위의 코드에서 이미 처리됨
                pass
        
        # 기존 물결 효과는 회오리가 없을 때만 작동
        # (회오리가 활성화되면 회오리가 모든 물 효과를 대체)
        # dash_wave는 회오리가 없을 때만 작동 (비활성화 - 불필요한 효과)
        if False and self.dash_wave_active and not self.vortex_active:
            # 플레이어가 발사한 공 (위로 향하는 공)은 영향받지 않음
            if ball_vy < 0:  # 공이 위로 향하고 있으면 (플레이어가 친 공)
                return ball_vx, ball_vy  # 물결 효과 무시
                
            distance = math.sqrt((ball_x - paddle_x) ** 2 + (ball_y - paddle_y) ** 2)
            wave_radius = 50 + self.dash_wave_timer * 10
            
            
            if distance < wave_radius and distance > 0:
                push_x = (ball_x - paddle_x) / distance * self.dash_wave_force
                push_y = (ball_y - paddle_y) / distance * self.dash_wave_force * 0.5
                attenuation = 1 - (distance / wave_radius)
                
                new_vx = ball_vx + push_x * attenuation
                new_vy = ball_vy + push_y * attenuation
                return new_vx, new_vy
            else:
                pass
        
        # 최종 속도 확인 (디버그)
        final_speed = math.sqrt(ball_vx ** 2 + ball_vy ** 2)
        if abs(final_speed - original_speed) > 2.0 and LEGENDARY_DEBUG_ENABLED:  # 속도가 2 이상 변했으면
            print(f"⚠️ 속도 변화 감지! 원래: {original_speed:.1f} → 최종: {final_speed:.1f}")
            print(f"   위치: ({ball_x:.0f}, {ball_y:.0f}), 회오리 활성: {self.vortex_active}, 캡처: {self.ball_in_vortex}")
        
        # 물 궤적이 활성화되어 있으면 공 위치 업데이트 (회오리 밖에서)
        if self.water_trail_active and not self.ball_in_vortex:
            # 회오리에서 나온 후에도 물 궤적 계속 업데이트
            self.update_water_trail(ball_x, ball_y)
        
        return ball_vx, ball_vy
        
    def update(self, dt: float, ui_mode: bool = False):
        """업데이트
        Args:
            dt: 델타 타임
            ui_mode: UI 모드 여부 (True면 게임플레이 효과 비활성화)
        """
        # 디버그: 업데이트 호출 확인
        if not hasattr(self, '_update_debug_counter'):
            self._update_debug_counter = 0
        self._update_debug_counter += 1
        
        if self._update_debug_counter <= 3 and LEGENDARY_DEBUG_ENABLED:
            print(f"🔱 PoseidonTrident.update 호출: dt={dt:.4f}, ui_mode={ui_mode}, active={self.active}")
        
        # 부모 클래스의 update 호출 (animation_offset 업데이트 포함)
        super().update(dt, ui_mode)
        
        # 라그나로크 해머와 동일한 애니메이션 프레임 카운터 업데이트
        if self.icon_frames and len(self.icon_frames) > 1:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.icon_frames)
        
        if not self.active:
            if self._update_debug_counter <= 3 and LEGENDARY_DEBUG_ENABLED:
                print(f"🔱 PoseidonTrident.update: active=False, 리턴")
            return
            
        # UI 모드에서는 아이콘 애니메이션만 업데이트하고 게임플레이 효과는 스킵
        if ui_mode:
            if self._update_debug_counter <= 3 and LEGENDARY_DEBUG_ENABLED:
                print(f"🔱 PoseidonTrident.update: ui_mode=True, 게임플레이 효과 스킵")
            return
            
        # 물결 타이머 (게임플레이에서만)
        self.wave_timer += dt * 60
        
        # 거대한 회오리 업데이트 (게임플레이에서만) - 양쪽 회오리
        if self.vortex_active:
            # 타이머와 높이 업데이트 디버그
            old_timer = self.vortex_timer
            old_left_height = self.vortex_left_height
            
            self.vortex_timer += dt
            
            # 디버그: 업데이트 확인
            if self._update_debug_counter <= 10 and LEGENDARY_DEBUG_ENABLED:
                print(f"🌀 Vortex UPDATE: dt={dt:.4f}, timer={old_timer:.3f}→{self.vortex_timer:.3f}")
                print(f"   왼쪽 높이: {old_left_height:.1f} → ", end="")

            # 왼쪽 회오리 높이 급속 확장 (용솟음치는 효과)
            if self.vortex_left_height < self.vortex_max_height:
                self.vortex_left_height += 800 * dt  # 빠르게 상승
                if self._update_debug_counter <= 10 and LEGENDARY_DEBUG_ENABLED:
                    print(f"{self.vortex_left_height:.1f} (증가: {800 * dt:.1f})")
            elif self._update_debug_counter <= 10 and LEGENDARY_DEBUG_ENABLED:
                print(f"{self.vortex_left_height:.1f} (최대값 도달)")
            
            # 오른쪽 회오리 높이 급속 확장 (용솟음치는 효과)
            if self.vortex_right_height < self.vortex_max_height:
                self.vortex_right_height += 800 * dt  # 빠르게 상승
                
            # 매 0.5초마다 업데이트 상태 출력
            if int(self.vortex_timer * 2) != int((self.vortex_timer - dt) * 2) and LEGENDARY_DEBUG_ENABLED:
                print(f"📈 Vortex Update: timer={self.vortex_timer:.2f}s, 왼쪽={self.vortex_left_height:.0f}, 오른쪽={self.vortex_right_height:.0f}")
            
            # 회전 속도 증가
            self.vortex_spin_speed += dt * 10
            
            # 회오리 파티클 업데이트 - 각 회오리별로 처리
            particle_count = 0
            for particle in self.vortex_particles[:]:
                particle_count += 1
                # 나선형 움직임 (dt를 프레임 단위로 변환: dt * 60 = 1프레임)
                old_angle = particle["spiral_angle"]
                particle["spiral_angle"] += dt * 60 * 0.3  # 프레임당 0.3 라디안 회전
                
                # 첫 번째 파티클의 움직임 디버그
                if particle_count == 1 and int(self.vortex_timer * 10) != int((self.vortex_timer - dt) * 10):
                    pass  # Debug log removed
                
                # 파티클이 어느 회오리에 속하는지에 따라 중심 결정
                if "vortex_side" in particle:
                    if particle["vortex_side"] == "left":
                        center_x = self.vortex_left_x
                        center_y = self.vortex_left_y
                    else:  # right
                        center_x = self.vortex_right_x
                        center_y = self.vortex_right_y
                else:
                    # 기본값 (호환성)
                    center_x = self.vortex_left_x
                    center_y = self.vortex_left_y
                
                particle["x"] = center_x + math.cos(particle["spiral_angle"]) * particle["spiral_radius"]
                particle["y"] -= dt * 60 * 3.5  # 프레임당 3.5픽셀 위로 상승
                
                particle["spiral_radius"] += dt * 60 * 0.5  # 프레임당 0.5픽셀 반경 확대
                particle["life"] -= dt * 60  # 프레임당 1씩 감소
                
                if particle["life"] <= 0:
                    self.vortex_particles.remove(particle)
                    
            # 새로운 파티클 지속적으로 생성 - 소멸 단계 전까지만 (0.8초)
            if self.vortex_timer < 0.8 and len(self.vortex_particles) < 150:  # 양쪽이니까 150개까지
                # 왼쪽 회오리 파티클
                for _ in range(2):
                    particle = {
                        "x": self.vortex_left_x + random.uniform(-30, 30),
                        "y": self.vortex_left_y,
                        "vx": random.uniform(-5, 5),
                        "vy": random.uniform(-10, -5),
                        "life": random.randint(30, 60),
                        "color": (50, 150 + random.randint(0, 100), 255),
                        "size": random.uniform(5, 15),
                        "spiral_angle": random.uniform(0, math.pi * 2),
                        "spiral_radius": random.uniform(10, 30),
                        "vortex_side": "left"
                    }
                    self.vortex_particles.append(particle)
                
                # 오른쪽 회오리 파티클
                for _ in range(2):
                    particle = {
                        "x": self.vortex_right_x + random.uniform(-30, 30),
                        "y": self.vortex_right_y,
                        "vx": random.uniform(-5, 5),
                        "vy": random.uniform(-10, -5),
                        "life": random.randint(30, 60),
                        "color": (50, 150 + random.randint(0, 100), 255),
                        "size": random.uniform(5, 15),
                        "spiral_angle": random.uniform(0, math.pi * 2),
                        "spiral_radius": random.uniform(10, 30),
                        "vortex_side": "right"
                    }
                    self.vortex_particles.append(particle)
            
            # 회오리 종료 체크 (1.3초 후: 0.3 + 0.5 + 0.5)
            if self.vortex_timer > 1.3:
                self.vortex_active = False
                self.vortex_left_height = 0
                self.vortex_right_height = 0
                self.vortex_particles.clear()
                # 물의 추진력은 유지! (회오리가 끝나도 공의 추진력은 계속됨)
                # 추진력은 자체 타이머로 관리되므로 여기서 리셋하지 않음
        
        # 대시 물결 타이머
        if self.dash_wave_active:
            self.dash_wave_timer += dt * 60
            if self.dash_wave_timer > 60:  # 1초 후 종료
                self.dash_wave_active = False
                self.dash_wave_timer = 0

        # === 쿨타임 시스템 업데이트 === (첫 번째 update 함수 - 사용 안됨, 두 번째 update가 실제 사용됨)

        # 물의 기운 응축 파티클 업데이트
        if self.water_condensation_active:
            self.water_condensation_timer += dt
            self._update_water_condensation_particles(dt)

        # 물의 기운 폭발 파티클 업데이트
        if self.water_explosion_active:
            self.water_explosion_timer += dt
            self._update_water_explosion_particles(dt)

    def update_player_position(self, player_x: float, player_y: float):
        """플레이어 위치 업데이트 (물의 기운 효과용)"""
        self.player_position = (player_x, player_y)

    def _start_water_condensation_effect(self):
        """쿨타임 충전 완료 시 물의 기운 응축 효과 시작"""
        self.water_condensation_active = True
        self.water_condensation_timer = 0
        self.water_condensation_particles.clear()

        player_x, player_y = self.player_position

        # 플레이어 주변에서 중심으로 모이는 물 파티클 생성
        for i in range(10):  # 10개 파티클
            angle = (i / 10) * math.pi * 2
            distance = random.uniform(70, 110)  # 70~110픽셀 거리 (2배)

            start_x = player_x + math.cos(angle) * distance
            start_y = player_y + math.sin(angle) * distance

            particle = {
                "x": start_x,
                "y": start_y,
                "target_x": player_x,
                "target_y": player_y,
                "start_x": start_x,
                "start_y": start_y,
                "angle": angle,
                "distance": distance,
                "speed": random.uniform(0.75, 1.0),  # 응축 속도 (2배 느리게)
                "size": random.uniform(8, 14),  # 크기 2배
                "life": 1.0,  # 응축 진행도 (1.0 → 0.0)
                "color": (80 + random.randint(0, 40),
                         180 + random.randint(0, 50),
                         230 + random.randint(0, 25)),
                "glow_phase": random.uniform(0, math.pi * 2)
            }
            self.water_condensation_particles.append(particle)

    def _update_water_condensation_particles(self, dt: float):
        """물의 기운 응축 파티클 업데이트 (간소화)"""
        player_x, player_y = self.player_position
        all_condensed = True

        for particle in self.water_condensation_particles[:]:
            # 타겟(플레이어 위치) 업데이트
            particle["target_x"] = player_x
            particle["target_y"] = player_y

            # 응축 진행 (중심으로 이동)
            particle["life"] -= dt * particle["speed"]

            if particle["life"] > 0:
                all_condensed = False
                # 현재 위치 계산 (단순히 중심으로 이동)
                progress = 1.0 - particle["life"]
                eased_progress = 1 - (1 - progress) ** 2  # ease-out 곡선

                # 직선으로 중심에 접근
                current_distance = particle["distance"] * (1 - eased_progress)
                particle["x"] = particle["target_x"] + math.cos(particle["angle"]) * current_distance
                particle["y"] = particle["target_y"] + math.sin(particle["angle"]) * current_distance

                # 빛나는 효과 업데이트
                particle["glow_phase"] += dt * 6

        # 모든 파티클이 응축 완료되면 폭발 효과 시작
        if all_condensed:
            self.water_condensation_active = False
            self.water_condensation_particles.clear()
            self._start_water_explosion_effect()

    def _start_water_explosion_effect(self):
        """물의 기운 폭발 효과 시작"""
        self.water_explosion_active = True
        self.water_explosion_timer = 0
        self.water_explosion_particles.clear()

        player_x, player_y = self.player_position

        # 시작 시 플레이어 위치 저장 (파티클이 플레이어를 따라다니도록)
        self.explosion_origin_x = player_x
        self.explosion_origin_y = player_y

        # 폭발 파티클 생성 (크기 1.5배)
        for i in range(12):  # 12개
            angle = (i / 12) * math.pi * 2 + random.uniform(-0.2, 0.2)
            speed = random.uniform(60, 90)  # 속도 1.5배 (더 넓게 퍼짐)

            particle = {
                "offset_x": 0,  # 플레이어 기준 상대 위치
                "offset_y": 0,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed,
                "size": random.uniform(12, 24),  # 크기 1.5배
                "life": random.uniform(1.2, 2.0),
                "max_life": 2.0,
                "color": (100 + random.randint(0, 40),
                         190 + random.randint(0, 50),
                         240 + random.randint(0, 15))
            }
            self.water_explosion_particles.append(particle)

    def _update_water_explosion_particles(self, dt: float):
        """물의 기운 폭발 파티클 업데이트 (플레이어 따라다님)"""
        particles_alive = False

        for particle in self.water_explosion_particles[:]:
            # 상대 위치 업데이트 (플레이어 기준)
            particle["offset_x"] += particle["vx"] * dt
            particle["offset_y"] += particle["vy"] * dt

            # 속도 감쇠
            particle["vx"] *= 0.92
            particle["vy"] *= 0.92

            # 수명 감소
            particle["life"] -= dt

            if particle["life"] > 0:
                particles_alive = True
            else:
                self.water_explosion_particles.remove(particle)

        # 모든 파티클 사라지면 폭발 효과 종료
        if not particles_alive:
            self.water_explosion_active = False
            self.water_explosion_particles.clear()

    def draw_effects(self, screen: pygame.Surface):
        """거대한 물결 회오리 효과 그리기"""
        if not self.active:
            return
        
        # 물 궤적 그리기 (회오리 효과보다 먼저 그려서 아래에 표시)
        self.draw_water_trail(screen)
            
        # 거대한 회오리 그리기
        if self.vortex_active:
            # 디버그 출력 추가
            if len(self.vortex_particles) > 0:
                pass  # Debug log removed
            # 물기둥 효과 제거 - 파티클만 표시
            # 두 회오리 중 더 높은 것 사용 (시각적 효과용)
            current_height = int(min(max(self.vortex_left_height, self.vortex_right_height), self.vortex_max_height))
            # 시각 효과는 제거하고 물리 효과만 유지
            
            # 회오리 파티클 그리기
            for particle in self.vortex_particles:
                if "size" in particle:
                    size = particle["size"]
                    alpha = min(255, int(particle["life"] * 5))
                    
                    # 거대한 물방울 효과
                    water_surf = pygame.Surface((int(size * 2), int(size * 2)), pygame.SRCALPHA)
                    color = (*particle["color"], alpha)
                    pygame.draw.circle(water_surf, color, (int(size), int(size)), int(size))
                    
                    # 하이라이트 효과
                    highlight_color = (200, 230, 255, alpha // 2)
                    pygame.draw.circle(water_surf, highlight_color,
                                     (int(size - size // 3), int(size - size // 3)),
                                     int(size // 3))

                    screen.blit(water_surf, (particle["x"] - size, particle["y"] - size))

        # 물의 기운 폭발 파티클 그리기
        self._draw_water_explosion_particles(screen)

    def _draw_water_condensation_particles(self, screen: pygame.Surface):
        """물의 기운 응축 파티클 그리기 (간소화 - 작은 원만)"""
        if not self.water_condensation_active:
            return

        for particle in self.water_condensation_particles:
            size = int(particle["size"])
            if size <= 0:
                continue

            px, py = int(particle["x"]), int(particle["y"])
            alpha = int(220 * particle["life"])

            # 글로우 효과 (더 큰 반투명 원)
            glow_size = size + 6  # 글로우 더 크게
            glow_alpha = alpha // 3
            glow_color = (100, 200, 255, glow_alpha)
            glow_surf = pygame.Surface((glow_size * 2 + 2, glow_size * 2 + 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, glow_color, (glow_size + 1, glow_size + 1), glow_size)
            screen.blit(glow_surf, (px - glow_size - 1, py - glow_size - 1))

            # 메인 물방울
            color = (*particle["color"], alpha)
            pygame.draw.circle(screen, color, (px, py), size)

    def _draw_water_explosion_particles(self, screen: pygame.Surface):
        """물의 기운 폭발 파티클 그리기"""
        if not self.water_explosion_active:
            return

        # 중심 폭발 플래시 (크기 1.5배)
        if self.water_explosion_timer < 0.4:
            player_x, player_y = self.player_position
            flash_progress = self.water_explosion_timer / 0.4
            flash_alpha = int(180 * (1 - flash_progress))
            flash_size = int(30 + flash_progress * 90)  # 30~120픽셀 (1.5배)

            # 글로우
            glow_surf = pygame.Surface((flash_size * 2 + 4, flash_size * 2 + 4), pygame.SRCALPHA)
            glow_color = (120, 200, 255, flash_alpha // 2)
            pygame.draw.circle(glow_surf, glow_color, (flash_size + 2, flash_size + 2), flash_size)
            screen.blit(glow_surf, (int(player_x) - flash_size - 2, int(player_y) - flash_size - 2))

            # 중심 밝은 부분
            center_color = (180, 230, 255, flash_alpha)
            pygame.draw.circle(screen, center_color, (int(player_x), int(player_y)), flash_size // 2)

        # 파티클 그리기 (플레이어 위치 + 상대 위치)
        player_x, player_y = self.player_position
        for particle in self.water_explosion_particles:
            life_ratio = particle["life"] / particle["max_life"]
            size = max(2, int(particle["size"] * life_ratio))
            # 현재 플레이어 위치 + 파티클의 상대 위치
            px = int(player_x + particle["offset_x"])
            py = int(player_y + particle["offset_y"])
            alpha = int(220 * life_ratio)

            # 글로우
            glow_size = size + 4  # 글로우도 더 크게
            glow_surf = pygame.Surface((glow_size * 2 + 2, glow_size * 2 + 2), pygame.SRCALPHA)
            glow_color = (100, 200, 255, alpha // 3)
            pygame.draw.circle(glow_surf, glow_color, (glow_size + 1, glow_size + 1), glow_size)
            screen.blit(glow_surf, (px - glow_size - 1, py - glow_size - 1))

            # 메인
            color = (*particle["color"], alpha)
            pygame.draw.circle(screen, color, (px, py), size)

    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """애니메이션 아이콘 그리기 - 라그나로크 해머와 완전 동일"""
        import pygame
        
        # 공통 전설 프레임 (라그나로크/헤르메스와 동일 배경)
        frame_offset = _draw_common_legendary_frame(screen, x, y, size, self.animation_time)
        
        # 애니메이션 프레임 그리기 (라그나로크 해머와 동일한 프레임 사용)
        if self.animation_frames and len(self.animation_frames) > 0:
            # 현재 프레임 그리기 (위아래 움직임 효과 포함)
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)

            icon_y = y + frame_offset + int(self.animation_offset)
            current_icon = self.animation_frames[self.current_frame % len(self.animation_frames)]
            scaled_icon = pygame.transform.scale(current_icon, (size, size))
            screen.blit(scaled_icon, (x, icon_y))

            # 번개 효과 추가 (프레임 0, 4에서) - 라그나로크와 동일
            if self.current_frame in [0, 4]:
                # 작은 번개 이펙트
                bolt_color = (255, 255, 150)
                pygame.draw.line(screen, bolt_color,
                               (x + size//4, y + frame_offset - 5),
                               (x + size//3, y + frame_offset + size//4), 2)
                pygame.draw.line(screen, bolt_color,
                               (x + size*3//4, y + frame_offset - 5),
                               (x + size*2//3, y + frame_offset + size//4), 2)
        else:
            # Fallback: 프레임이 없으면 기본 삼지창 아이콘 그리기
            icon_y = y + frame_offset + int(self.animation_offset)
            trident_color = (70, 180, 220)  # 바다색
            handle_color = (60, 130, 180)   # 어두운 바다색
            water_color = (100, 200, 255)   # 밝은 물색

            # 삼지창 손잡이
            handle_x = x + size//2 - size//16
            pygame.draw.rect(screen, handle_color,
                           (handle_x, icon_y + size//3, size//8, size//2))
            pygame.draw.rect(screen, (40, 100, 140),
                           (handle_x, icon_y + size//3, size//8, size//2), 1)

            # 삼지창 머리 (세 갈래)
            prong_y = icon_y + size//6
            center_x = x + size//2

            # 중앙 갈래
            pygame.draw.polygon(screen, trident_color, [
                (center_x, prong_y - size//8),
                (center_x - size//12, prong_y + size//6),
                (center_x + size//12, prong_y + size//6)
            ])
            # 왼쪽 갈래
            pygame.draw.polygon(screen, trident_color, [
                (center_x - size//5, prong_y),
                (center_x - size//4, prong_y + size//6),
                (center_x - size//7, prong_y + size//6)
            ])
            # 오른쪽 갈래
            pygame.draw.polygon(screen, trident_color, [
                (center_x + size//5, prong_y),
                (center_x + size//4, prong_y + size//6),
                (center_x + size//7, prong_y + size//6)
            ])

            # 물결 효과
            wave_y = icon_y + size*3//4
            for i in range(3):
                wave_x = x + size//4 + i * size//6
                pygame.draw.arc(screen, water_color,
                              (wave_x, wave_y, size//6, size//8),
                              0, 3.14, 2)

        # 파티클 효과
        if self.particle_timer > 1.0:
            self._spawn_particle(screen, x + size//2, y + frame_offset + size//2)
            self.particle_timer = 0
    
    def update(self, dt: float, ui_mode: bool = False):
        """애니메이션 업데이트 - 프레임 카운터 업데이트 포함
        
        Args:
            dt: 델타 타임
            ui_mode: UI 모드 여부 (True면 게임플레이 효과 비활성화)
        """
        super().update(dt, ui_mode)  # 부모 클래스의 update 호출 (animation_offset 등 업데이트)
        
        # 애니메이션 프레임 카운터 업데이트
        if self.animation_frames and len(self.animation_frames) > 1:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)
        
        # 회오리 애니메이션 업데이트 (ui_mode가 아닐 때만)
        if not ui_mode and self.vortex_active:
            # 타이머 업데이트 
            self.vortex_timer += dt * 60  # 60fps 기준으로 변환
            
            # 회오리 성장 단계 (0.3초 동안 성장)
            if self.vortex_timer < 18:  # 0.3초 * 60fps = 18 프레임
                growth_rate = self.vortex_timer / 18
                self.vortex_left_height = self.vortex_max_height * growth_rate
                self.vortex_right_height = self.vortex_max_height * growth_rate
                self.vortex_spin_speed = 10 * growth_rate
            # 회오리 유지 단계 (0.5초 동안 유지)
            elif self.vortex_timer < 48:  # 0.8초 * 60fps = 48 프레임 (0.3 + 0.5 = 0.8)
                self.vortex_left_height = self.vortex_max_height
                self.vortex_right_height = self.vortex_max_height
                self.vortex_spin_speed = 10
            # 회오리 소멸 단계 (0.8초 동안 소멸) - 효과 없음
            elif self.vortex_timer < 96:  # 1.6초 * 60fps = 96 프레임 (0.3 + 0.5 + 0.8 = 1.6)
                fade_rate = 1 - (self.vortex_timer - 48) / 48  # 48프레임(0.8초) 동안 소멸
                self.vortex_left_height = self.vortex_max_height * fade_rate
                self.vortex_right_height = self.vortex_max_height * fade_rate
                self.vortex_spin_speed = 10 * fade_rate
            else:
                # 회오리 종료
                self.vortex_active = False
                self.vortex_left_height = 0
                self.vortex_right_height = 0
                self.vortex_particles.clear()
            
            # 파티클 업데이트
            for particle in self.vortex_particles[:]:
                particle["life"] -= 1
                if particle["life"] <= 0:
                    self.vortex_particles.remove(particle)
                    continue
                
                # 회오리 회전 움직임
                if "vortex_side" in particle:
                    if particle["vortex_side"] == "left":
                        center_x = self.vortex_left_x
                        center_y = self.vortex_left_y
                    else:
                        center_x = self.vortex_right_x
                        center_y = self.vortex_right_y
                    
                    # 나선형 움직임
                    particle["spiral_angle"] += self.vortex_spin_speed * 0.1
                    particle["spiral_radius"] *= 0.98  # 서서히 중심으로
                    particle["x"] = center_x + math.cos(particle["spiral_angle"]) * particle["spiral_radius"]
                    particle["y"] -= 3  # 위로 상승
                    
                    # 크기 감소
                    particle["size"] *= 0.98
                
            # 새 파티클 추가 (소멸 단계 전까지만)
            if self.vortex_timer < 48 and len(self.vortex_particles) < 100:
                # 왼쪽 회오리 파티클
                for _ in range(2):
                    angle = random.uniform(0, math.pi * 2)
                    particle = {
                        "x": self.vortex_left_x + math.cos(angle) * random.uniform(10, 50),
                        "y": self.vortex_left_y + random.uniform(-20, 20),
                        "vx": math.cos(angle) * random.uniform(1, 3),
                        "vy": random.uniform(-5, -2),
                        "life": random.randint(30, 60),
                        "color": (50, 150 + random.randint(0, 100), 255),
                        "size": random.uniform(3, 8),
                        "spiral_angle": angle,
                        "spiral_radius": random.uniform(20, 60),
                        "vortex_side": "left"
                    }
                    self.vortex_particles.append(particle)
                
                # 오른쪽 회오리 파티클
                for _ in range(2):
                    angle = random.uniform(0, math.pi * 2)
                    particle = {
                        "x": self.vortex_right_x + math.cos(angle) * random.uniform(10, 50),
                        "y": self.vortex_right_y + random.uniform(-20, 20),
                        "vx": math.cos(angle) * random.uniform(1, 3),
                        "vy": random.uniform(-5, -2),
                        "life": random.randint(30, 60),
                        "color": (50, 150 + random.randint(0, 100), 255),
                        "size": random.uniform(3, 8),
                        "spiral_angle": angle,
                        "spiral_radius": random.uniform(20, 60),
                        "vortex_side": "right"
                    }
                    self.vortex_particles.append(particle)
        
        # 물결 타이머 업데이트
        if self.active and not ui_mode:
            self.wave_timer += dt * 60
            
        # 쿨다운 업데이트
        if self.vortex_cooldown > 0:
            self.vortex_cooldown -= 1
        
        # 물방울 파티클 업데이트
        for droplet in self.water_droplets[:]:
            droplet['lifetime'] -= dt * 60
            droplet['y'] += droplet['vy'] * dt * 60
            droplet['vy'] += 0.5  # 중력
            droplet['x'] += droplet['vx'] * dt * 60

            if droplet['lifetime'] <= 0 or droplet['y'] > 800:
                self.water_droplets.remove(droplet)

        # === 효과 발동 쿨타임 시스템 업데이트 ===
        if self.active and not ui_mode:
            if not self.effect_ready and self.effect_cooldown > 0:
                self.effect_cooldown -= dt

                # 쿨타임 완료 시 물의 기운 효과 시작 (폭발 효과만)
                if self.effect_cooldown <= 0:
                    self.effect_cooldown = 0
                    self.effect_ready = True
                    self._start_water_explosion_effect()  # 폭발 효과만 바로 실행

            # 물의 기운 폭발 파티클 업데이트
            if self.water_explosion_active:
                self.water_explosion_timer += dt
                self._update_water_explosion_particles(dt)

    def update_water_droplets_with_boss(self, boss_x: float, boss_y: float, boss_width: float, boss_height: float):
        """물방울 파티클과 보스 패들의 충돌 체크"""
        if not self.active:
            return
            
        # 보스 패들 히트박스 생성 (약간 확장)
        boss_rect = pygame.Rect(boss_x - 5, boss_y - 5, boss_width + 10, boss_height + 10)
        
        removed_count = 0
        # 물방울과 보스 패들 충돌 체크
        for droplet in self.water_droplets[:]:
            # 물방울의 위치와 크기로 충돌 체크
            size = int(droplet['size'])  # float를 int로 변환
            droplet_rect = pygame.Rect(
                int(droplet['x']) - size,
                int(droplet['y']) - size,
                size * 2,
                size * 2
            )
            
            # 충돌하면 물방울 제거
            if boss_rect.colliderect(droplet_rect):
                self.water_droplets.remove(droplet)
                removed_count += 1
        
        # 디버그 옵션 (필요시 활성화)
        # if removed_count > 0:
        #     print(f"🔱 포세이돈 삼지창: {removed_count}개의 물방울이 보스 패들과 충돌하여 제거됨")
    
    def on_boss_hit(self):
        """보스가 공을 칠 때 호출되는 함수"""
        # print(f"🔍 [on_boss_hit 호출됨] vortex_affected={self.vortex_affected}")  # 디버그 비활성화
        if self.vortex_affected and self.boss_hit_count == 0:  # 첫 번째 히트만 카운트
            self.boss_hit_count += 1
            # print(f"🔍 [보스 히트] boss_hit_count 증가: {self.boss_hit_count - 1} → {self.boss_hit_count}")  # 디버그 비활성화
    
    def deactivate_water_trail(self):
        """물 궤적 비활성화 (보스가 공을 칠 때 호출)"""
        # print(f"🔍 [deactivate_water_trail 호출됨] vortex_affected={self.vortex_affected}, water_trail_active={self.water_trail_active}")  # 디버그 비활성화
        # 회오리 효과를 받은 공은 보스가 쳐도 궤적 유지
        if self.vortex_affected:
            # print(f"🔱 포세이돈 삼지창: 회오리 효과 중이므로 물 궤적 유지")  # 디버그 비활성화
            self.on_boss_hit()  # 보스 히트 카운트 증가
            return  # 궤적을 끄지 않음
            
        if self.water_trail_active:
            self.water_trail_active = False
            self.water_trail.clear()
            if LEGENDARY_DEBUG_ENABLED:
                print(f"🔱 포세이돈 삼지창: 물 궤적 비활성화 (보스가 공을 쳤음)")
    
    def update_water_trail(self, ball_x, ball_y):
        """물 궤적 업데이트"""
        if self.water_trail_active:
            # 궤적에 현재 위치 추가
            self.water_trail.append({'x': ball_x, 'y': ball_y, 'lifetime': 30})
            
            # 물방울 파티클 생성 (확률적으로) - 물 궤적 대신 더 많은 파티클 생성
            if random.random() < 0.5:  # 50% 확률로 증가
                for _ in range(random.randint(2, 5)):  # 더 많은 파티클
                    droplet = {
                        'x': ball_x + random.uniform(-8, 8),
                        'y': ball_y + random.uniform(-8, 8),
                        'vx': random.uniform(-3, 3),
                        'vy': random.uniform(-2, 2),
                        'lifetime': 30,  # 더 오래 지속
                        'size': random.uniform(3, 6)  # 더 큰 물방울
                    }
                    self.water_droplets.append(droplet)
        
        # 궤적 수명 관리
        for point in self.water_trail[:]:
            point['lifetime'] -= 1
            if point['lifetime'] <= 0:
                self.water_trail.remove(point)
        
        # 궤적 길이 제한
        if len(self.water_trail) > 50:
            self.water_trail.pop(0)
    
    def draw_water_trail(self, screen: pygame.Surface):
        """물 궤적 그리기 - 물방울 파티클만 표시"""
        # 궤적 선은 그리지 않고 물방울 파티클만 그리도록 수정
        # (이전 코드는 주석 처리)
        
        # if len(self.water_trail) > 1:
        #     # 궤적 그리기 - 제거됨
        #     pass
        
        # 물방울 파티클 그리기 (더 화려하게)
        for droplet in self.water_droplets:
            alpha = min(255, int(droplet['lifetime'] * 8.5))
            if alpha > 0:
                # 물방울 색상 (더 선명하게)
                droplet_color = (80, 160, 255)
                
                # 물방울 그리기
                droplet_surf = pygame.Surface((int(droplet['size'] * 2), int(droplet['size'] * 2)), pygame.SRCALPHA)
                
                # 메인 물방울
                pygame.draw.circle(droplet_surf, (*droplet_color, alpha),
                                 (int(droplet['size']), int(droplet['size'])),
                                 int(droplet['size']))
                
                # 하이라이트 (더 밝게)
                if droplet['size'] > 2:
                    highlight_alpha = min(255, alpha + 50)
                    pygame.draw.circle(droplet_surf, (220, 240, 255, highlight_alpha // 2),
                                     (int(droplet['size'] - droplet['size']/3), 
                                      int(droplet['size'] - droplet['size']/3)),
                                     int(droplet['size'] / 2.5))
                
                # 외곽선 효과 추가
                if droplet['size'] > 3:
                    pygame.draw.circle(droplet_surf, (50, 120, 200, alpha // 3),
                                     (int(droplet['size']), int(droplet['size'])),
                                     int(droplet['size']), 1)
                
                screen.blit(droplet_surf, 
                          (int(droplet['x'] - droplet['size']), 
                           int(droplet['y'] - droplet['size'])))


class HermesShoes(LegendaryItem):
    """헤르메스의 신발 - 이동속도 증가 (롤 옵션: 이동속도 30~60%)"""
    def __init__(self):
        super().__init__(
            name="hermes_shoes",
            korean_name="헤르메스의 신발",
            description="패들 이동속도 증가 (롤 옵션: 30~60%)",
            unlock_condition="누적 이동 거리 100,000 픽셀 달성",
            icon_path="items/legendary/hermes_shoes.png"  # 아이콘 경로 추가
        )
        self._base_speed_bonus = 50  # 기본 이동속도 보너스 % (롤 옵션으로 덮어씀)
        self.enhancement_bonus_pct = 0  # 강화 보너스 퍼센트
        self.speed_trails = []  # 속도 잔상 효과
        self.wing_effects = []  # 날개 효과
        
        # 애니메이션 프레임 로드
        self.animation_frames = []
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 4  # 프레임당 틱 수 (12프레임에 맞춰 더 빠르게)
        self._load_animation_frames()
        
        # 헤르메스의 신발도 라그나로크 해머와 동일한 글로우 효과
        self.hermes_glow_multiplier = 1.8  # 라그나로크와 동일한 글로우 크기
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """누적 이동 거리 체크"""
        return game_stats.get("total_movement_distance", 0) >= 100000

    @property
    def speed_bonus(self) -> float:
        """이동속도 보너스 % (롤 옵션 적용, 연마 스킬 + 강화 보너스 포함)"""
        return get_legendary_roll_value("hermes_shoes", "speed_bonus", apply_polish=True, enhancement_bonus_pct=self.enhancement_bonus_pct)

    @property
    def speed_multiplier(self) -> float:
        """이동속도 배율 (1.0 + 보너스%)"""
        return 1.0 + (self.speed_bonus / 100.0)

    def activate(self, game_state: Dict):
        """헤르메스의 신발 활성화"""
        super().activate(game_state)
        # pingfighter.py의 전역 변수 설정
        import pingfighter
        import items
        pingfighter.hermes_shoes_obtained = True
        items.hermes_shoes_obtained = True
        if LEGENDARY_DEBUG_ENABLED:
            print(f"헤르메스의 신발 활성화! 이동속도 {self.speed_bonus}% 증가!")

    def apply_speed(self, base_speed: float) -> float:
        """이동속도 배율 적용"""
        if self.active:
            return base_speed * self.speed_multiplier
        return base_speed
        
    def add_speed_trail(self, paddle_x: int, paddle_y: int, paddle_width: int, paddle_height: int):
        """속도 잔상 추가"""
        if self.active:
            import time
            self.speed_trails.append({
                'x': paddle_x,
                'y': paddle_y,
                'width': paddle_width,
                'height': paddle_height,
                'time': time.time(),
                'alpha': 100
            })
            # 최대 5개의 잔상만 유지
            if len(self.speed_trails) > 5:
                self.speed_trails.pop(0)
                
    def draw_special_effects(self, screen, paddle_x: int, paddle_y: int, paddle_width: int, paddle_height: int):
        """특수 효과 그리기 (속도 잔상, 날개 효과)"""
        if not self.active:
            return
            
        import pygame
        import time
        
        current_time = time.time()
        
        # 속도 잔상 그리기
        for trail in self.speed_trails[:]:
            elapsed = current_time - trail['time']
            if elapsed > 0.5:  # 0.5초 후 제거
                self.speed_trails.remove(trail)
                continue
                
            alpha = int(trail['alpha'] * (1 - elapsed / 0.5))
            trail_surf = pygame.Surface((trail['width'], trail['height']), pygame.SRCALPHA)
            trail_surf.fill((255, 215, 0, alpha))  # 황금색 잔상
            screen.blit(trail_surf, (trail['x'], trail['y']))
        
        # 날개 효과 그리기 (패들 양옆)
        wing_offset = math.sin(current_time * 10) * 3  # 날개 펄럭임
        
        # 왼쪽 날개
        wing_points_left = [
            (paddle_x - 15 + wing_offset, paddle_y + paddle_height // 2 - 10),
            (paddle_x - 25 + wing_offset, paddle_y + paddle_height // 2),
            (paddle_x - 15 + wing_offset, paddle_y + paddle_height // 2 + 10),
            (paddle_x, paddle_y + paddle_height // 2)
        ]
        pygame.draw.polygon(screen, (255, 255, 255, 180), wing_points_left)
        pygame.draw.polygon(screen, (255, 215, 0), wing_points_left, 2)
        
        # 오른쪽 날개
        wing_points_right = [
            (paddle_x + paddle_width + 15 - wing_offset, paddle_y + paddle_height // 2 - 10),
            (paddle_x + paddle_width + 25 - wing_offset, paddle_y + paddle_height // 2),
            (paddle_x + paddle_width + 15 - wing_offset, paddle_y + paddle_height // 2 + 10),
            (paddle_x + paddle_width, paddle_y + paddle_height // 2)
        ]
        pygame.draw.polygon(screen, (255, 255, 255, 180), wing_points_right)
        pygame.draw.polygon(screen, (255, 215, 0), wing_points_right, 2)
        
        # 속도선 효과
        if abs(paddle_x - getattr(self, 'last_paddle_x', paddle_x)) > 5:
            for i in range(3):
                line_y = paddle_y + paddle_height // 4 + i * paddle_height // 4
                line_start = paddle_x - 30 if paddle_x > getattr(self, 'last_paddle_x', paddle_x) else paddle_x + paddle_width + 30
                line_end = paddle_x if paddle_x > getattr(self, 'last_paddle_x', paddle_x) else paddle_x + paddle_width
                pygame.draw.line(screen, (255, 255, 100, 150), (line_start, line_y), (line_end, line_y), 2)
        
        self.last_paddle_x = paddle_x
    
    def _load_animation_frames(self):
        """애니메이션 프레임 로드 - 라그나로크 해머 PNG 사용"""
        import pygame
        import os
        
        # 헤르메스 신발 전용 PNG 파일 사용
        frames_loaded = 0
        for i in range(8):
            # 헤르메스 신발 프레임을 로드
            frame_path = resource_path(f"items/legendary/hermes_shoes_frame_{i}.png")
            try:
                frame = pygame.image.load(frame_path).convert_alpha()
                cleaned_frame = _strip_legendary_red_ring(frame)
                self.animation_frames.append(cleaned_frame)
                frames_loaded += 1
                pass  # print(f"✓ 헤르메스 신발 프레임 {i} 로드 성공")  # 디버그 비활성화
            except Exception as e:
                pass  # print(f"[ERROR] Frame {i} load failed: {frame_path} - {e}")  # 디버그 비활성화

        pass  # print(f"헤르메스 신발: 전용 프레임 {frames_loaded}/8개 로드")  # 디버그 비활성화
        

        # 프레임이 없으면 에러만 표시 (가짜 애니메이션 생성하지 않음)
        if not self.animation_frames or len(self.animation_frames) == 0:
            pass  # print("❌ 헤르메스 신발: PNG 프레임을 찾을 수 없습니다!")  # 디버그 비활성화
            # 가짜 애니메이션 생성 코드 완전 제거
    
    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """애니메이션 아이콘 그리기"""
        import pygame
        
        # 공통 배경 프레임 연출 (라그나로크 해머와 동일 스타일)
        frame_offset = _draw_common_legendary_frame(screen, x, y, size, self.animation_time,
                                                    border_color=COMMON_LEGENDARY_BORDER_COLOR,
                                                    corner_color=COMMON_LEGENDARY_CORNER_COLOR)
        
        # 애니메이션 프레임 그리기
        if self.animation_frames and len(self.animation_frames) > 0:
            # 프레임 업데이트 (항상 진행)
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)
            
            # 현재 프레임 그리기 (위아래 움직임 효과 포함)
            icon_y = y + frame_offset + int(self.animation_offset)
            current_icon = self.animation_frames[self.current_frame % len(self.animation_frames)]
            scaled_icon = pygame.transform.scale(current_icon, (size, size))
            screen.blit(scaled_icon, (x, icon_y))
            
            # 헤르메스 특수 효과 없음 (번개 효과 대신)
        else:
            # 프레임이 없으면 기본 신발 아이콘 그리기
            icon_y = y + frame_offset + int(self.animation_offset)
            shoe_color = (100, 200, 255)  # 하늘색
            wing_color = (255, 255, 255)  # 흰색
            
            # 신발 본체
            pygame.draw.ellipse(screen, shoe_color, (x + size//4, y + size//2, size//2, size//4))
            pygame.draw.ellipse(screen, (50, 150, 200), (x + size//4, y + size//2, size//2, size//4), 2)
            
            # 날개 (왼쪽)
            wing_points = [
                (x + size//4 - 5, y + size//2 + 5),
                (x + size//4 - 15, y + size//2),
                (x + size//4 - 10, y + size//2 + 10),
                (x + size//4, y + size//2 + 8)
            ]
            pygame.draw.polygon(screen, wing_color, wing_points)
            pygame.draw.polygon(screen, shoe_color, wing_points, 1)
            
            # 날개 (오른쪽)
            wing_points = [
                (x + size*3//4 + 5, y + size//2 + 5),
                (x + size*3//4 + 15, y + size//2),
                (x + size*3//4 + 10, y + size//2 + 10),
                (x + size*3//4, y + size//2 + 8)
            ]
            pygame.draw.polygon(screen, wing_color, wing_points)
            pygame.draw.polygon(screen, shoe_color, wing_points, 1)
        
        # 파티클 효과
        if self.particle_timer > 1.0:
            self._spawn_particle(screen, x + size//2, y + frame_offset + size//2)
            self.particle_timer = 0


class DivineStone(LegendaryItem):
    """디바인스톤 — 보스 공 하강 차단 번개

    - 10초 쿨다운으로 발동
    - 보스가 친 공이 화면 하단(높이 50% 이하)으로 내려왔을 때 즉시 번개가 공을 타격
    - 번개는 디바인스톤 위치에서 공까지 '순간 도달' 형태(1~2프레임 표시)
    - 접촉 지점에서 전기 폭발 연출 후 공을 위쪽(Y-)으로 임의 각도로 재발사

    렌더/파티클은 발동 시에만 경량 생성하여 프레임 부하를 피한다.
    """
    def __init__(self):
        super().__init__(
            name="divine_stone",
            korean_name="디바인스톤",
            description="보스 공이 하강해 오면 10초마다 번개로 요격하고 위로 쏘아올립니다",
            unlock_condition="스테이지 5 클리어",
            icon_path=None,
        )
        # 트리거/쿨다운
        self.cooldown_ms = 10000
        self.last_strike_ms = -999999
        # 번개 이펙트
        self.lightning_active = False
        self.lightning_ms = 0
        self.lightning_life_ms = 120
        self.lightning_path = []  # [(x,y), ...]
        self.lightning_branches = []  # [ [(x,y), ...], ... ]
        self.stone_pos = (0, 0)
        self.strike_pos = (0, 0)
        # 전기 폭발 이펙트
        self.explosion_ms = 0
        self.explosion_life_ms = 220
        self.explosion_radius = 0
        self.explosion_center = (0, 0)
        # 스파크 파티클(경량)
        self.spark_particles = []  # [{'x','y','vx','vy','life','size'}]

    # ---------- 내부 유틸 ----------
    def _gen_lightning(self, start: tuple[int, int], end: tuple[int, int]) -> tuple[list[tuple[int,int]], list[list[tuple[int,int]]]]:
        """프랙탈 중점 변위로 단일 번개 경로와 소규모 가지를 생성한다."""
        sx, sy = start
        ex, ey = end
        points = [(sx, sy), (ex, ey)]

        def subdivide(pts: list[tuple[int,int]], disp: float) -> list[tuple[int,int]]:
            if disp < 6:
                return pts
            new_pts = [pts[0]]
            for i in range(len(pts) - 1):
                x1, y1 = pts[i]
                x2, y2 = pts[i + 1]
                mx = (x1 + x2) / 2
                my = (y1 + y2) / 2
                # 수직 방향 오프셋(좌/우 랜덤)
                dx = x2 - x1
                dy = y2 - y1
                length = math.hypot(dx, dy) or 1.0
                nx = -dy / length
                ny = dx / length
                offset = random.uniform(-disp, disp)
                mx += nx * offset
                my += ny * offset
                new_pts.append((int(mx), int(my)))
                new_pts.append((x2, y2))
            return subdivide(new_pts, disp * 0.55)

        base_disp = max(12.0, math.hypot(ex - sx, ey - sy) * 0.08)
        main = subdivide(points, base_disp)

        # 가지는 1~2개 소량만, 말단 쪽 짧게
        branches: list[list[tuple[int,int]]] = []
        if len(main) > 4:
            branch_count = 1 if random.random() < 0.6 else 2
            for _ in range(branch_count):
                idx = random.randrange(len(main) // 2, len(main) - 2)
                bx, by = main[idx]
                # 종단을 향하는 짧은 가지
                dirx = ex - bx
                diry = ey - by
                blen = max(18, int(math.hypot(dirx, diry) * 0.25))
                ang = math.atan2(diry, dirx) + random.uniform(-0.6, 0.6)
                ex2 = int(bx + math.cos(ang) * blen)
                ey2 = int(by + math.sin(ang) * blen)
                branch = subdivide([(bx, by), (ex2, ey2)], max(8.0, blen * 0.12))
                branches.append(branch)

        return main, branches

    def _spawn_sparks(self, x: float, y: float, count: int = 14):
        for _ in range(count):
            ang = random.uniform(0, math.tau)
            spd = random.uniform(3.0, 7.0)
            self.spark_particles.append({
                'x': float(x), 'y': float(y),
                'vx': math.cos(ang) * spd,
                'vy': math.sin(ang) * spd,
                'life': random.randint(14, 24),
                'size': random.uniform(1.5, 3.0)
            })

    # ---------- 외부 API ----------
    def should_trigger(self, ball_y: float, actual_step_vy: float, height: int, now_ms: int) -> bool:
        # 스톱워치/정지 상태에서는 작동 금지(외부에서 이미 step이 막히지만 안전 가드)
        if now_ms - self.last_strike_ms < self.cooldown_ms:
            return False
        # 보스가 친 공(아래로 이동) + 화면 하단 50% 이하
        return (actual_step_vy > 0) and (ball_y >= height * 0.5)

    def perform_strike(self, stone_pos: tuple[int, int], ball_pos: tuple[int, int],
                       actual_step_vel: tuple[float, float]) -> tuple[float, float]:
        """번개 발동과 동시에 반환 속도를 계산해 준다(실제 스텝 벨로시티 기준)."""
        self.stone_pos = (int(stone_pos[0]), int(stone_pos[1]))
        self.strike_pos = (int(ball_pos[0]), int(ball_pos[1]))
        self.last_strike_ms = pygame.time.get_ticks()

        # 번개/폭발 타이머 시작
        self.lightning_active = True
        self.lightning_ms = self.lightning_life_ms
        self.explosion_ms = self.explosion_life_ms
        self.explosion_center = self.strike_pos
        self.explosion_radius = 0

        # 경로 생성(1회)
        self.lightning_path, self.lightning_branches = self._gen_lightning(self.stone_pos, self.strike_pos)
        self._spawn_sparks(self.strike_pos[0], self.strike_pos[1])

        # 위쪽(보스 방향) 임의 각도로 재발사. 속도는 현재 속도 유지(과도한 상향 방지)
        step_vx, step_vy = actual_step_vel
        step_speed = max(1.0, math.hypot(step_vx, step_vy))
        base_angle = -math.pi / 2  # 위쪽
        random_offset = random.uniform(-math.pi/4, math.pi/4)  # ±45도 범위
        ang = base_angle + random_offset
        new_step_vx = math.cos(ang) * step_speed
        new_step_vy = math.sin(ang) * step_speed
        if new_step_vy >= -1.0:
            new_step_vy = -1.0  # 반드시 위쪽으로
        return new_step_vx, new_step_vy

    def update(self, dt: float, ui_mode: bool = False):
        super().update(dt, ui_mode)
        # ms 단위로 통일
        ms = int(dt if dt > 1.5 else dt * 1000)
        if self.lightning_active:
            self.lightning_ms -= ms
            if self.lightning_ms <= 0:
                self.lightning_active = False
                self.lightning_path = []
                self.lightning_branches = []
        if self.explosion_ms > 0:
            self.explosion_ms -= ms
            # 반지름은 초반 급팽창 후 서서히 감쇠
            life_ratio = self.explosion_ms / max(1, self.explosion_life_ms)
            self.explosion_radius = int(8 + (1 - life_ratio) * 36)
        # 스파크 파티클 업데이트
        if self.spark_particles:
            for p in self.spark_particles:
                p['x'] += p['vx']
                p['y'] += p['vy']
                p['vy'] += 0.08  # 약간의 중력감
                p['life'] -= 1
            self.spark_particles = [p for p in self.spark_particles if p['life'] > 0]

    def draw_world_effects(self, screen: pygame.Surface):
        """필드 상 번개/전기 폭발 시각 효과를 그린다."""
        # 번개: 얇은 본선 + 흐릿한 외곽선으로 가시성 확보
        if self.lightning_active and self.lightning_path:
            core = (255, 255, 180)
            glow = (170, 210, 255, 90)
            # 번개 경로의 경계 박스 계산(성능 최적화: 전체 화면 표면 생성 회피)
            all_pts = self.lightning_path[:]
            for br in self.lightning_branches:
                all_pts.extend(br)
            min_x = min(p[0] for p in all_pts)
            max_x = max(p[0] for p in all_pts)
            min_y = min(p[1] for p in all_pts)
            max_y = max(p[1] for p in all_pts)
            margin = 18
            w = max(2, (max_x - min_x) + margin * 2)
            h = max(2, (max_y - min_y) + margin * 2)
            offx, offy = min_x - margin, min_y - margin
            glow_surf = pygame.Surface((w, h), pygame.SRCALPHA)
            # 좌표를 로컬로 오프셋하여 그린 후 화면에 블릿
            def _offset(pts):
                return [(px - offx, py - offy) for (px, py) in pts]
            if len(self.lightning_path) >= 2:
                pygame.draw.lines(glow_surf, glow, False, _offset(self.lightning_path), 6)
            for br in self.lightning_branches:
                if len(br) >= 2:
                    pygame.draw.lines(glow_surf, glow, False, _offset(br), 4)
            screen.blit(glow_surf, (offx, offy))
            # 코어 라인(가늘고 밝게)
            pygame.draw.lines(screen, core, False, self.lightning_path, 2)
            for br in self.lightning_branches:
                pygame.draw.lines(screen, core, False, br, 1)

        # 전기 폭발: 링 + 코어 플래시 + 스파크
        if self.explosion_ms > 0:
            cx, cy = self.explosion_center
            r = max(2, self.explosion_radius)
            life_ratio = self.explosion_ms / max(1, self.explosion_life_ms)
            alpha = int(220 * life_ratio)
            # 코어 플래시
            core_surf = pygame.Surface((r*4, r*4), pygame.SRCALPHA)
            pygame.draw.circle(core_surf, (255, 255, 200, alpha), (r*2, r*2), int(r*0.6))
            pygame.draw.circle(core_surf, (255, 255, 255, int(alpha*0.6)), (r*2, r*2), int(r*0.35))
            screen.blit(core_surf, (cx - r*2, cy - r*2), special_flags=pygame.BLEND_ADD)
            # 링 파동
            ring_alpha = int(180 * life_ratio)
            pygame.draw.circle(screen, (180, 220, 255), (cx, cy), r, 2)
            if ring_alpha > 0 and r > 4:
                ring_surf = pygame.Surface((r*2+6, r*2+6), pygame.SRCALPHA)
                pygame.draw.circle(ring_surf, (180, 220, 255, ring_alpha), (r+3, r+3), r, 2)
                screen.blit(ring_surf, (cx - r - 3, cy - r - 3))
            # 스파크
            for p in self.spark_particles:
                s = max(1, int(p['size']))
                pygame.draw.line(screen, (255, 240, 180), (int(p['x']), int(p['y'])), (int(p['x'] + p['vx']*0.6), int(p['y'] + p['vy']*0.6)), 1)
                pygame.draw.circle(screen, (255, 255, 255), (int(p['x']), int(p['y'])), max(1, s//2))

    def reset_round_effects(self):
        """라운드/스테이지 전환 시 모든 일시 상태 초기화"""
        self.lightning_active = False
        self.lightning_ms = 0
        self.lightning_path = []
        self.lightning_branches = []
        self.explosion_ms = 0
        self.explosion_radius = 0
        self.spark_particles.clear()
        # 쿨다운은 초기화하지 않음(남은 쿨다운 유지). 즉시 발동이 필요하면 아래 라인 사용
        # self.last_strike_ms = -999999

    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """아이콘(이미지 없이 벡터 드로잉) + 공통 전설 프레임."""
        frame_offset = _draw_common_legendary_frame(screen, x, y, size, self.animation_time,
                                                    border_color=COMMON_LEGENDARY_BORDER_COLOR,
                                                    corner_color=COMMON_LEGENDARY_CORNER_COLOR)
        cx = x + size//2
        cy = y + frame_offset + size//2
        # 중앙 보석(디바인 스톤)
        gem = [
            (cx, cy - size//3),
            (cx + size//5, cy - size//8),
            (cx + size//7, cy + size//4),
            (cx, cy + size//3),
            (cx - size//7, cy + size//4),
            (cx - size//5, cy - size//8),
        ]
        pygame.draw.polygon(screen, (200, 230, 255), gem)
        pygame.draw.polygon(screen, (120, 170, 255), gem, 2)
        # 미니 번개 장식
        bx1 = cx - size//6; by1 = cy - size//10
        bx2 = cx - size//10; by2 = cy + size//10
        bx3 = cx + size//12; by3 = cy
        pygame.draw.lines(screen, (255, 255, 180), False, [(bx1, by1), (bx2, by2), (bx3, by3)], 2)

class RagnarokHammer(LegendaryItem):
    """라그나로크 해머 - 강력한 넉백 효과 (롤 옵션: 발동확률, 스턴시간)"""
    def __init__(self):
        super().__init__(
            name="ragnarok_hammer",
            korean_name="라그나로크 해머",
            description="보스가 공을 받을 때 확률적으로 넉백 + 스턴 (롤 옵션 적용)",
            unlock_condition="누적 넉백 거리 10,000 픽셀 달성",
            icon_path=None  # 고유 애니메이션만 사용 (중앙 PNG 제거)
        )
        self.knockback_multiplier = 5.0  # 넉백 배율
        self.max_knockback = 250  # 최대 넉백 거리
        self.impact_particles = []  # 충격 파티클
        # 롤 옵션으로 결정되는 값 (기본값)
        self._base_stun_duration = 0.6  # 스턴 시간 (롤 옵션으로 덮어씀)
        self._base_trigger_chance = 35  # 발동 확률 % (롤 옵션으로 덮어씀)
        self._base_speed_boost = 25  # 공속 증가율 % (롤 옵션으로 덮어씀)
        self._base_gauge_cost = 30  # 게이지 소모량 (롤 옵션으로 덮어씀)
        self.enhancement_bonus_pct = 0  # 강화 보너스 퍼센트

        # 애니메이션 프레임 로드
        self.animation_frames = []
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8  # 프레임당 틱 수
        self._load_animation_frames()
        
        # 라그나로크 해머 전용 더 큰 글로우
        self.hammer_glow_multiplier = 1.8  # 헤르메스보다 더 큰 글로우
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """누적 넉백 거리 체크"""
        return game_stats.get("total_knockback_distance", 0) >= 10000

    @property
    def trigger_chance(self) -> float:
        """발동 확률 (롤 옵션 적용, 연마 스킬 + 강화 보너스 포함)"""
        return get_legendary_roll_value("ragnarok_hammer", "trigger_chance", apply_polish=True, enhancement_bonus_pct=self.enhancement_bonus_pct)

    @property
    def stun_duration(self) -> float:
        """스턴 시간 (롤 옵션 적용, 연마 스킬 + 강화 보너스 포함)"""
        return get_legendary_roll_value("ragnarok_hammer", "stun_duration", apply_polish=True, enhancement_bonus_pct=self.enhancement_bonus_pct)

    @property
    def speed_boost(self) -> float:
        """공속 증가율 % (롤 옵션 적용, 연마 스킬 + 강화 보너스 포함)"""
        return get_legendary_roll_value("ragnarok_hammer", "speed_boost", apply_polish=True, enhancement_bonus_pct=self.enhancement_bonus_pct)

    @property
    def gauge_cost(self) -> float:
        """게이지 소모량 (롤 옵션 적용, 연마 스킬 + 강화 보너스 포함 - 낮을수록 좋음)"""
        return get_legendary_roll_value("ragnarok_hammer", "gauge_cost", apply_polish=True, enhancement_bonus_pct=self.enhancement_bonus_pct)

    def should_trigger(self) -> bool:
        """발동 확률 체크 - 보스가 공을 받을 때마다 호출"""
        if not self.active:
            return False
        roll = random.randint(1, 100)
        triggered = roll <= self.trigger_chance
        if LEGENDARY_DEBUG_ENABLED:
            print(f"[라그나로크 해머] 발동 확률 체크: {roll} <= {self.trigger_chance}% = {triggered}")
        return triggered

    def calculate_knockback(self, ball_speed: float, boss_x: float = 300, skip_trigger_check: bool = False) -> tuple:
        """
        공속에 비례한 수평 넉백 계산 (수류탄 방식)
        skip_trigger_check=True: 스턴공 발동 확정 시 확률 체크 생략
        Returns: (horizontal_knockback_velocity, stun_duration)
        """
        if not self.active:
            return 0, 0

        # 발동 확률 체크 (스턴공 확정 시 스킵)
        if not skip_trigger_check and not self.should_trigger():
            return 0, 0

        magnitude = compute_knockback_magnitude("ragnarok", ball_speed=ball_speed)

        # 보스 위치에 따라 방향 결정
        center_x = 380  # 화면 중앙 (WIDTH // 2 = 760 // 2)
        if boss_x + 50 < center_x:  # 보스가 왼쪽에 있으면
            horizontal_velocity = magnitude  # 오른쪽으로 넉백
        else:  # 보스가 오른쪽에 있으면
            horizontal_velocity = -magnitude  # 왼쪽으로 넉백

        # 롤 옵션에서 스턴 시간 가져오기
        current_stun = self.stun_duration

        if LEGENDARY_DEBUG_ENABLED:
            print(f"[라그나로크 해머 calculate_knockback]")
            print(f"  - 입력 공속: {ball_speed:.1f}")
            print(f"  - 최종 넉백 속도: {horizontal_velocity:.1f}")
            print(f"  - 스턴 시간: {current_stun:.1f}초")

        # 넉백 속도와 스턴 시간을 함께 반환
        return horizontal_velocity, current_stun
        
    def draw_special_effects(self, screen, boss_x: int, boss_y: int):
        """특수 효과 그리기"""
        if not self.active:
            return
            
        import pygame
        import time
        current_time = time.time()
        
        # 충격파 효과
        if hasattr(self, 'last_impact_time'):
            elapsed = current_time - self.last_impact_time
            if elapsed < 0.3:  # 0.3초 동안 충격파 표시
                radius = int(elapsed * 500)  # 충격파 확산
                alpha = int(255 * (1 - elapsed / 0.3))
                
                # 여러 개의 충격파 원
                for i in range(3):
                    r = radius - i * 20
                    if r > 0:
                        pygame.draw.circle(screen, (255, 200, 100), 
                                         (boss_x, boss_y), r, 2)
        
    def on_boss_hit(self, boss_x: int, boss_y: int):
        """보스가 공을 맞았을 때"""
        if self.active:
            import time
            self.last_impact_time = time.time()
            
            # 화면 흔들림 효과 추가 (선택사항)
            # 파티클 효과 추가
            import random
            for _ in range(10):
                self.impact_particles.append({
                    'x': boss_x + random.randint(-20, 20),
                    'y': boss_y + random.randint(-20, 20),
                    'vx': random.uniform(-5, 5),
                    'vy': random.uniform(-5, 5),
                    'life': 30
                })
    
    def _load_animation_frames(self):
        """애니메이션 프레임 로드"""
        import pygame

        self.animation_frames.clear()

        frames_loaded = 0
        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                frame = pygame.image.load(frame_path).convert_alpha()
                cleaned_frame = _strip_legendary_red_ring(frame)
                self.animation_frames.append(cleaned_frame)
                frames_loaded += 1
                pass  # print(f"✓ 프레임 {i} 로드 성공: {frame_path}")  # 디버그 비활성화
            except Exception as e:
                pass  # print(f"[ERROR] Frame {i} load failed: {frame_path} - {e}")  # 디버그 비활성화

        pass  # print(f"라그나로크 해머 프레임 {frames_loaded}/8개 로드")  # 디버그 비활성화

        if not self.animation_frames:
            pass  # print(f"❌ 라그나로크 해머: PNG 프레임을 찾을 수 없습니다!")  # 디버그 비활성화
    
    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """애니메이션 아이콘 그리기"""
        import pygame
        import math
        
        # 공통 배경 프레임 연출
        frame_offset = _draw_common_legendary_frame(screen, x, y, size, self.animation_time)

        # 애니메이션 프레임 그리기
        if self.animation_frames and len(self.animation_frames) > 0:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)

            icon_y = y + frame_offset + int(self.animation_offset)
            current_icon = self.animation_frames[self.current_frame % len(self.animation_frames)]
            scaled_icon = pygame.transform.scale(current_icon, (size, size))
            screen.blit(scaled_icon, (x, icon_y))

            if self.current_frame in [0, 4]:
                bolt_color = (255, 255, 150)
                pygame.draw.line(screen, bolt_color,
                                 (x + size // 4, y + frame_offset - 5),
                                 (x + size // 3, y + frame_offset + size // 4), 2)
                pygame.draw.line(screen, bolt_color,
                                 (x + size * 3 // 4, y + frame_offset - 5),
                                 (x + size * 2 // 3, y + frame_offset + size // 4), 2)
        else:
            # Fallback: 프레임이 없으면 기본 해머 아이콘 그리기
            icon_y = y + frame_offset + int(self.animation_offset)
            hammer_color = (180, 120, 60)  # 갈색 (해머 머리)
            handle_color = (120, 80, 40)   # 어두운 갈색 (손잡이)
            lightning_color = (255, 220, 100)  # 노란색 (번개)

            # 해머 손잡이
            handle_rect = pygame.Rect(x + size//2 - size//12, icon_y + size//4, size//6, size//2)
            pygame.draw.rect(screen, handle_color, handle_rect)
            pygame.draw.rect(screen, (80, 50, 30), handle_rect, 1)

            # 해머 머리
            head_rect = pygame.Rect(x + size//4, icon_y + size//6, size//2, size//4)
            pygame.draw.rect(screen, hammer_color, head_rect, border_radius=3)
            pygame.draw.rect(screen, (140, 90, 40), head_rect, 2, border_radius=3)

            # 번개 효과
            bolt_y = icon_y + size//8
            pygame.draw.line(screen, lightning_color,
                           (x + size//3, bolt_y), (x + size//2 - 2, bolt_y + size//6), 2)
            pygame.draw.line(screen, lightning_color,
                           (x + size//2 - 2, bolt_y + size//6), (x + size//3 + 4, bolt_y + size//4), 2)
            pygame.draw.line(screen, lightning_color,
                           (x + size*2//3, bolt_y), (x + size//2 + 2, bolt_y + size//6), 2)
            pygame.draw.line(screen, lightning_color,
                           (x + size//2 + 2, bolt_y + size//6), (x + size*2//3 - 4, bolt_y + size//4), 2)

        # 파티클 효과
        if self.particle_timer > 1.0:
            self._spawn_particle(screen, x + size//2, y + frame_offset + size//2)
            self.particle_timer = 0
    
    def update(self, dt: float, ui_mode: bool = False):
        """애니메이션 업데이트"""
        super().update(dt, ui_mode)
        
        # 애니메이션 프레임 카운터 업데이트 (draw_icon에서도 처리하지만 여기서도 추가)
        if self.animation_frames and len(self.animation_frames) > 1:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)
        
        # 파티클 업데이트
        for particle in self.impact_particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1
            particle['vy'] += 0.3  # 중력
            
            if particle['life'] <= 0:
                self.impact_particles.remove(particle)
    
    def draw_particles(self, screen):
        """파티클 그리기"""
        if not self.active:
            return
            
        import pygame
        for particle in self.impact_particles:
            alpha = particle['life'] * 8
            color = (255, 200, 100)
            size = max(1, particle['life'] // 10)
            pygame.draw.circle(screen, color,
                             (int(particle['x']), int(particle['y'])), size)


class SacredLaurel(LegendaryItem):
    """신성 월계수 - 월계수 잎이 플레이어 주변을 회전하며 공을 막아줌 (롤 옵션: 잎 개수 3~8)"""

    def __init__(self):
        super().__init__(
            name="sacred_laurel",
            korean_name="신성 월계수",
            description="월계수 잎이 플레이어 주변을 회전하며 보호 (롤 옵션: 잎 개수 3~8개)",
            unlock_condition="신화 아이템 획득"
        )
        self._base_max_leaves = 6  # 기본 잎 개수 (롤 옵션으로 덮어씀)
        self.leaves = []
        self.leaf_radius = 200  # 가로 길이 400% (50 -> 100 -> 200)
        self.leaf_size = 30  # 그림 크기 (12 -> 30, 2.5배 확대)
        self.leaf_hitbox_size = 35  # 타격 판정 범위
        self.rotation_speed = 1.5
        self.current_angle = 0
        self.respawn_timer = 0
        self.respawn_delay = 30 * 60  # 모든 잎 파괴 시 전체 리스폰 (사용 안함)
        self.all_leaves_destroyed = False
        self.glow_intensity = 0
        self.glow_direction = 1
        self.removal_particles = []
        # 개별 잎 재생 시스템 (15초마다 1개씩)
        self.leaf_regen_timer = 0
        self.leaf_regen_delay = 15 * 60  # 15초 (60fps 기준)
        # 장식 파티클 시스템 (잎 주변 꾸밈 효과)
        self.decoration_particles = []
        self.decoration_spawn_timer = 0
        self.decoration_spawn_delay = 8  # 8프레임마다 새 파티클 생성
        # 잎 상태 저장용 (장착 해제 후 재장착 시 상태 유지)
        self._saved_leaves = None
        self._saved_all_destroyed = False
        self._saved_respawn_timer = 0
        self._saved_current_angle = 0
        self._saved_regen_timer = 0
        self.animation_frames = []
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8
        self._load_animation_frames()
        self.player_x = 0
        self.player_y = 0
        self.enhancement_bonus_pct = 0  # 강화 버프 보너스 (장착 시 동기화)

    def _load_animation_frames(self):
        import pygame
        self.animation_frames.clear()
        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                if os.path.exists(frame_path):
                    original = pygame.image.load(frame_path).convert_alpha()
                    frame = self._create_laurel_frame(original, i)
                    self.animation_frames.append(frame)
            except Exception:
                pass
        if not self.animation_frames:
            for i in range(8):
                self.animation_frames.append(self._create_default_frame(i))

    def _create_laurel_frame(self, base_frame, frame_idx):
        import pygame
        import math
        frame = base_frame.copy()
        width, height = frame.get_size()
        cx, cy = width // 2, height // 2
        for y in range(height):
            for x in range(width):
                dist = math.sqrt((x - cx)**2 + (y - cy)**2)
                if dist < 12:
                    frame.set_at((x, y), (0, 0, 0, 0))
        # 금빛 잎 색상
        leaf_colors = [(220, 180, 60), (200, 160, 50), (240, 200, 70), (210, 170, 55),
                       (230, 190, 65), (190, 150, 45), (250, 210, 80), (205, 165, 52)]
        highlight_colors = [(255, 240, 150), (255, 230, 140), (255, 245, 160), (255, 235, 145),
                           (255, 242, 155), (255, 225, 135), (255, 250, 170), (255, 232, 142)]
        leaf_color = leaf_colors[frame_idx % len(leaf_colors)]
        highlight = highlight_colors[frame_idx % len(highlight_colors)]
        for i in range(3):
            angle = (frame_idx * 0.2) + (i * 2 * math.pi / 3)
            lx = cx + int(math.cos(angle) * 6)
            ly = cy + int(math.sin(angle) * 6)
            leaf_surf = pygame.Surface((8, 5), pygame.SRCALPHA)
            pygame.draw.ellipse(leaf_surf, leaf_color, (0, 0, 8, 5))
            pygame.draw.ellipse(leaf_surf, highlight, (1, 1, 3, 2))
            rotated = pygame.transform.rotate(leaf_surf, -math.degrees(angle))
            rect = rotated.get_rect(center=(lx, ly))
            frame.blit(rotated, rect)
        pygame.draw.circle(frame, (255, 215, 0), (cx, cy), 2)
        return frame

    def _create_default_frame(self, frame_idx):
        import pygame
        import math
        frame = pygame.Surface((32, 32), pygame.SRCALPHA)
        cx, cy = 16, 16
        # 금빛 배경
        bg_colors = [(160, 130, 50), (150, 120, 45), (170, 140, 55), (155, 125, 48),
                     (165, 135, 52), (145, 115, 42), (175, 145, 58), (152, 122, 46)]
        pygame.draw.circle(frame, bg_colors[frame_idx], (cx, cy), 14)
        # 금빛 잎
        leaf_colors = [(220, 180, 60), (200, 160, 50), (240, 200, 70), (210, 170, 55),
                       (230, 190, 65), (190, 150, 45), (250, 210, 80), (205, 165, 52)]
        highlight_colors = [(255, 240, 150), (255, 230, 140), (255, 245, 160), (255, 235, 145),
                           (255, 242, 155), (255, 225, 135), (255, 250, 170), (255, 232, 142)]
        for i in range(3):
            angle = (frame_idx * 0.2) + (i * 2 * math.pi / 3)
            lx = cx + int(math.cos(angle) * 8)
            ly = cy + int(math.sin(angle) * 8)
            leaf_surf = pygame.Surface((10, 6), pygame.SRCALPHA)
            pygame.draw.ellipse(leaf_surf, leaf_colors[frame_idx], (0, 0, 10, 6))
            pygame.draw.ellipse(leaf_surf, highlight_colors[frame_idx], (2, 1, 4, 3))
            rotated = pygame.transform.rotate(leaf_surf, -math.degrees(angle))
            rect = rotated.get_rect(center=(lx, ly))
            frame.blit(rotated, rect)
        pygame.draw.circle(frame, (255, 215, 0), (cx, cy), 3)
        pygame.draw.circle(frame, (255, 255, 200), (cx-1, cy-1), 1)
        border_colors = [(150, 0, 0), (224, 0, 0), (255, 0, 0), (224, 0, 0),
                         (150, 0, 0), (75, 0, 0), (45, 0, 0), (75, 0, 0)]
        pygame.draw.circle(frame, border_colors[frame_idx], (cx, cy), 15, 2)
        return frame

    @property
    def max_leaves(self) -> int:
        """최대 잎 개수 (롤 옵션 적용, 연마 스킬 + 강화 보너스 포함, 3~8개)"""
        return int(get_legendary_roll_value("sacred_laurel", "leaf_count", apply_polish=True, enhancement_bonus_pct=self.enhancement_bonus_pct))

    def activate(self, game_state: Dict = None):
        if self.active:
            return
        import math
        import random
        self.active = True

        # 저장된 잎 상태가 있으면 복원
        if self._saved_leaves is not None:
            self.leaves = self._saved_leaves
            self.all_leaves_destroyed = self._saved_all_destroyed
            self.respawn_timer = self._saved_respawn_timer
            self.current_angle = self._saved_current_angle
            self.leaf_regen_timer = self._saved_regen_timer
            active_count = sum(1 for leaf in self.leaves if leaf['active'])
            if LEGENDARY_DEBUG_ENABLED:
                print(f"🌿 신성 월계수 재활성화! {active_count}개의 월계수 잎이 남아있습니다!")
        else:
            # 처음 활성화 시 새로운 잎 생성
            self.leaves = []
            for i in range(self.max_leaves):
                angle = (2 * math.pi / self.max_leaves) * i
                # 4가지 다른 잎 모양 타입 랜덤 할당
                leaf_type = random.randint(0, 3)
                self.leaves.append({
                    'active': True,
                    'base_angle': angle,
                    'removal_effect': False,
                    'removal_timer': 0,
                    'leaf_type': leaf_type,  # 0: 클래식, 1: 뾰족한, 2: 둥근, 3: 톱니
                    'size_variation': random.uniform(0.8, 1.2)  # 크기 변화
                })
            self.current_angle = 0
            self.all_leaves_destroyed = False
            self.respawn_timer = 0
            self.leaf_regen_timer = 0
            if LEGENDARY_DEBUG_ENABLED:
                print(f"🌿 신성 월계수 활성화! {self.max_leaves}개의 월계수 잎이 당신을 보호합니다!")

        self.removal_particles = []

    def deactivate(self):
        # 현재 잎 상태 저장 (재장착 시 복원용)
        if self.leaves:
            import copy
            self._saved_leaves = copy.deepcopy(self.leaves)
            self._saved_all_destroyed = self.all_leaves_destroyed
            self._saved_respawn_timer = self.respawn_timer
            self._saved_current_angle = self.current_angle
            self._saved_regen_timer = self.leaf_regen_timer

        self.active = False
        self.leaves = []
        self.removal_particles = []
        self.decoration_particles = []

    def reset(self):
        """스테이지 리셋 - 저장된 상태 유지 (같은 게임 내)"""
        self.deactivate()

    def reset_for_new_game(self):
        """새 게임 시작 시 완전 초기화 - 저장된 상태도 클리어"""
        self.active = False
        self.leaves = []
        self.removal_particles = []
        self.decoration_particles = []
        self.decoration_spawn_timer = 0
        self.all_leaves_destroyed = False
        self.respawn_timer = 0
        self.current_angle = 0
        self.leaf_regen_timer = 0
        # 저장된 상태도 초기화
        self._saved_leaves = None
        self._saved_all_destroyed = False
        self._saved_respawn_timer = 0
        self._saved_current_angle = 0
        self._saved_regen_timer = 0

    def set_player_position(self, x, y):
        self.player_x = x
        self.player_y = y

    def update(self, dt, ui_mode: bool = False):
        # UI 모드에서는 애니메이션만 업데이트
        if ui_mode:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % max(1, len(self.animation_frames))
            return

        if not self.active:
            return
        import math
        self.current_angle += self.rotation_speed * dt
        if self.current_angle > 2 * math.pi:
            self.current_angle -= 2 * math.pi
        self.glow_intensity += 0.05 * self.glow_direction
        if self.glow_intensity > 1:
            self.glow_intensity = 1
            self.glow_direction = -1
        elif self.glow_intensity < 0:
            self.glow_intensity = 0
            self.glow_direction = 1
        # 개별 잎 재생 시스템: 파괴된 잎이 있으면 5초마다 1개씩 재생
        destroyed_leaves = [leaf for leaf in self.leaves if not leaf['active']]
        if destroyed_leaves:
            self.leaf_regen_timer += 1
            if self.leaf_regen_timer >= self.leaf_regen_delay:
                self.leaf_regen_timer = 0
                self._regenerate_one_leaf()
        else:
            self.leaf_regen_timer = 0  # 모든 잎이 살아있으면 타이머 리셋

        # 모든 잎이 파괴된 경우도 개별 재생 시스템으로 처리
        if self.all_leaves_destroyed:
            # 첫 번째 잎이 재생되면 all_leaves_destroyed 해제
            active_count = sum(1 for leaf in self.leaves if leaf['active'])
            if active_count > 0:
                self.all_leaves_destroyed = False

        for particle in self.removal_particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1
            particle['vy'] += 0.2
            if particle['life'] <= 0:
                self.removal_particles.remove(particle)

        # 장식 파티클 생성 (잎 주변에 반짝이는 효과)
        import random
        self.decoration_spawn_timer += 1
        if self.decoration_spawn_timer >= self.decoration_spawn_delay:
            self.decoration_spawn_timer = 0
            # 활성화된 잎 주변에서 파티클 생성
            active_leaves = [(i, leaf) for i, leaf in enumerate(self.leaves) if leaf['active']]
            if active_leaves:
                idx, leaf = random.choice(active_leaves)
                angle = self.current_angle + leaf['base_angle']
                ellipse_scale_y = 0.3
                leaf_x = self.player_x + math.cos(angle) * self.leaf_radius
                leaf_y = self.player_y + math.sin(angle) * self.leaf_radius * ellipse_scale_y
                # 파티클 타입 랜덤 선택
                particle_type = random.choice(['sparkle', 'trail', 'ring', 'star'])
                self.decoration_particles.append({
                    'x': leaf_x + random.uniform(-15, 15),
                    'y': leaf_y + random.uniform(-10, 10),
                    'vx': random.uniform(-0.5, 0.5),
                    'vy': random.uniform(-1.0, -0.3),
                    'life': random.randint(30, 60),
                    'max_life': random.randint(30, 60),
                    'size': random.uniform(2, 5),
                    'type': particle_type,
                    'color': random.choice([
                        (255, 215, 100),  # 금색
                        (255, 240, 150),  # 밝은 금색
                        (255, 200, 80),   # 진한 금색
                        (255, 255, 200),  # 크림색
                        (200, 180, 100),  # 어두운 금색
                    ]),
                    'angle': random.uniform(0, 6.28),
                    'spin': random.uniform(-0.1, 0.1),
                })

        # 장식 파티클 업데이트
        for particle in self.decoration_particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1
            particle['angle'] += particle['spin']
            # 부드러운 움직임
            particle['vx'] *= 0.98
            particle['vy'] *= 0.98
            if particle['life'] <= 0:
                self.decoration_particles.remove(particle)

        self.frame_counter += 1
        if self.frame_counter >= self.animation_speed:
            self.frame_counter = 0
            self.current_frame = (self.current_frame + 1) % max(1, len(self.animation_frames))

    def _respawn_leaves(self):
        """모든 잎 전체 리스폰 (사용 안함 - 개별 재생으로 대체)"""
        import math
        import random
        self.leaves = []
        for i in range(self.max_leaves):
            angle = (2 * math.pi / self.max_leaves) * i
            leaf_type = random.randint(0, 3)
            self.leaves.append({
                'active': True,
                'base_angle': angle,
                'removal_effect': False,
                'removal_timer': 0,
                'leaf_type': leaf_type,
                'size_variation': random.uniform(0.8, 1.2)
            })
        self.all_leaves_destroyed = False
        self.respawn_timer = 0
        self.leaf_regen_timer = 0

    def refresh_leaves(self):
        """강화 보너스 변경 시 잎 개수를 max_leaves에 맞게 조정"""
        if not self.active:
            return
        import math
        import random

        current_count = len(self.leaves)
        target_count = self.max_leaves

        if current_count == target_count:
            return  # 변경 없음

        if current_count < target_count:
            # 잎 추가 (부족한 만큼)
            for i in range(current_count, target_count):
                angle = (2 * math.pi / target_count) * i
                leaf_type = random.randint(0, 3)
                self.leaves.append({
                    'active': True,
                    'base_angle': angle,
                    'removal_effect': False,
                    'removal_timer': 0,
                    'leaf_type': leaf_type,
                    'size_variation': random.uniform(0.8, 1.2)
                })
            if LEGENDARY_DEBUG_ENABLED:
                print(f"🌿 신성 월계수 잎 추가! {current_count}개 → {target_count}개")
        else:
            # 잎 제거 (초과분 - 일반적으로 발생하지 않음)
            self.leaves = self.leaves[:target_count]
            if LEGENDARY_DEBUG_ENABLED:
                print(f"🌿 신성 월계수 잎 조정! {current_count}개 → {target_count}개")

        # 각도 재분배 (균등 배치)
        for i, leaf in enumerate(self.leaves):
            leaf['base_angle'] = (2 * math.pi / target_count) * i

        # 전멸 상태 재평가
        active_count = sum(1 for leaf in self.leaves if leaf['active'])
        self.all_leaves_destroyed = (active_count == 0)

    def _regenerate_one_leaf(self):
        """파괴된 잎 1개를 재생"""
        import random
        # 파괴된 잎 찾기
        destroyed_leaves = [leaf for leaf in self.leaves if not leaf['active']]
        if not destroyed_leaves:
            return

        # 첫 번째 파괴된 잎 재생
        leaf = destroyed_leaves[0]
        leaf['active'] = True
        leaf['removal_effect'] = False
        leaf['removal_timer'] = 0
        # 새로운 타입과 크기 랜덤 할당
        leaf['leaf_type'] = random.randint(0, 3)
        leaf['size_variation'] = random.uniform(0.8, 1.2)

        active_count = sum(1 for l in self.leaves if l['active'])
        if LEGENDARY_DEBUG_ENABLED:
            print(f"🌿 월계수 잎 1개 재생! (현재 {active_count}/{self.max_leaves}개)")

    def get_active_leaf_count(self):
        return sum(1 for leaf in self.leaves if leaf['active'])

    def check_ball_collision(self, ball_x, ball_y, ball_radius):
        if not self.active or self.all_leaves_destroyed:
            return False
        import math
        # 토성의 고리처럼 가로로 긴 타원 궤도 (ellipse_scale_y로 Y축 압축)
        ellipse_scale_y = 0.3  # Y축을 30%로 압축하여 가로로 납작한 고리 형성

        # 패들 앞쪽 시야 판정 기준 (플레이어보다 이 값 이상 위에 있으면 앞쪽으로 판정)
        # 타원 궤도의 Y축 반경 = leaf_radius * ellipse_scale_y = 200 * 0.3 = 60
        # 앞쪽 판정은 플레이어보다 30픽셀 이상 위에 있을 때
        front_threshold = 30

        for leaf in self.leaves:
            if not leaf['active']:
                continue
            angle = self.current_angle + leaf['base_angle']
            # 가로로 긴 타원 궤도: X는 원형, Y는 압축
            leaf_x = self.player_x + math.cos(angle) * self.leaf_radius
            leaf_y = self.player_y + math.sin(angle) * self.leaf_radius * ellipse_scale_y

            # 플레이어 앞쪽(패들 시야 앞)에 있는 잎만 보스 공과 충돌하지 않음
            # 스매셔 등 패들에 공을 맞춰야 하는 캐릭터를 위해
            # 잎이 플레이어보다 front_threshold 이상 위에 있을 때만 충돌 무시
            # (옆쪽 잎들은 정상적으로 공을 막아줌)
            if leaf_y < self.player_y - front_threshold:
                continue

            dist = math.sqrt((ball_x - leaf_x)**2 + (ball_y - leaf_y)**2)
            if dist < ball_radius + self.leaf_hitbox_size:  # 타격 판정은 2배 크기 사용
                self._remove_leaf(leaf, leaf_x, leaf_y)
                return True
        return False

    def _remove_leaf(self, leaf, x, y):
        import random
        leaf['active'] = False
        for _ in range(15):
            self.removal_particles.append({
                'x': x, 'y': y,
                'vx': random.uniform(-3, 3), 'vy': random.uniform(-4, 1),
                'life': random.randint(20, 40),
                'color': random.choice([
                    (255, 215, 100),  # 금색
                    (255, 240, 150),  # 밝은 금색
                    (255, 200, 80),   # 진한 금색
                    (220, 180, 60),   # 어두운 금색
                    (255, 255, 200),  # 크림색
                ])
            })
        if self.get_active_leaf_count() == 0:
            self.all_leaves_destroyed = True
            self.respawn_timer = 0

    def _draw_leaf_type_0(self, surf, w, h, depth_factor):
        """클래식 월계수 잎 - 타원형 기본 (금빛)"""
        import pygame
        # 메인 잎 몸체 (금빛)
        base_gold = (int(180 * depth_factor), int(140 * depth_factor), int(50 * depth_factor))
        mid_gold = (int(220 * depth_factor), int(180 * depth_factor), int(60 * depth_factor))
        light_gold = (int(255 * depth_factor), int(215 * depth_factor), int(80 * depth_factor))
        highlight = (int(255 * depth_factor), int(240 * depth_factor), int(150 * depth_factor))
        vein_color = (int(150 * depth_factor), int(110 * depth_factor), int(30 * depth_factor))

        # 외곽 그림자
        pygame.draw.ellipse(surf, base_gold, (1, 1, w-2, h-2))
        # 메인 잎
        pygame.draw.ellipse(surf, mid_gold, (2, 2, w-4, h-4))
        # 하이라이트 (왼쪽 상단)
        pygame.draw.ellipse(surf, light_gold, (3, 2, w//3, h//2))
        pygame.draw.ellipse(surf, highlight, (4, 3, w//5, h//3))
        # 중심 잎맥
        pygame.draw.line(surf, vein_color, (w-2, h//2), (3, h//2), 2)
        # 측면 잎맥들
        for i in range(3):
            offset = (i + 1) * w // 5
            pygame.draw.line(surf, vein_color, (w - offset, h//2), (w - offset - 4, h//4 + 1), 1)
            pygame.draw.line(surf, vein_color, (w - offset, h//2), (w - offset - 4, h*3//4 - 1), 1)

    def _draw_leaf_type_1(self, surf, w, h, depth_factor):
        """뾰족한 월계수 잎 - 창 모양 (금빛)"""
        import pygame
        base_gold = (int(170 * depth_factor), int(130 * depth_factor), int(40 * depth_factor))
        mid_gold = (int(210 * depth_factor), int(170 * depth_factor), int(55 * depth_factor))
        light_gold = (int(245 * depth_factor), int(205 * depth_factor), int(70 * depth_factor))
        highlight = (int(255 * depth_factor), int(235 * depth_factor), int(140 * depth_factor))
        vein_color = (int(140 * depth_factor), int(100 * depth_factor), int(25 * depth_factor))

        # 뾰족한 잎 모양 (폴리곤)
        points = [
            (w - 2, h // 2),  # 뾰족한 끝
            (w * 2 // 3, h // 5),  # 상단
            (w // 4, h // 4),
            (3, h // 2),  # 줄기 연결
            (w // 4, h * 3 // 4),
            (w * 2 // 3, h * 4 // 5),  # 하단
        ]
        pygame.draw.polygon(surf, base_gold, points)
        # 내부 레이어
        inner_points = [(int(p[0] * 0.9 + w * 0.05), int(p[1] * 0.85 + h * 0.075)) for p in points]
        pygame.draw.polygon(surf, mid_gold, inner_points)
        # 하이라이트
        pygame.draw.ellipse(surf, light_gold, (w//3, h//4, w//4, h//3))
        pygame.draw.ellipse(surf, highlight, (w//3 + 2, h//4 + 2, w//6, h//5))
        # 중심 잎맥
        pygame.draw.line(surf, vein_color, (w-3, h//2), (5, h//2), 2)

    def _draw_leaf_type_2(self, surf, w, h, depth_factor):
        """둥근 월계수 잎 - 부드러운 곡선 (금빛)"""
        import pygame
        base_gold = (int(190 * depth_factor), int(150 * depth_factor), int(55 * depth_factor))
        mid_gold = (int(225 * depth_factor), int(185 * depth_factor), int(65 * depth_factor))
        light_gold = (int(255 * depth_factor), int(220 * depth_factor), int(90 * depth_factor))
        highlight = (int(255 * depth_factor), int(245 * depth_factor), int(160 * depth_factor))
        vein_color = (int(155 * depth_factor), int(115 * depth_factor), int(35 * depth_factor))
        edge_color = (int(130 * depth_factor), int(95 * depth_factor), int(25 * depth_factor))

        # 둥근 외곽
        pygame.draw.ellipse(surf, edge_color, (0, 0, w, h))
        pygame.draw.ellipse(surf, base_gold, (1, 1, w-2, h-2))
        # 둥근 내부
        pygame.draw.ellipse(surf, mid_gold, (3, 2, w-6, h-4))
        # 원형 하이라이트
        pygame.draw.ellipse(surf, light_gold, (w//4, h//5, w//3, h//2))
        pygame.draw.ellipse(surf, highlight, (w//4 + 2, h//5 + 2, w//5, h//3))
        # 부드러운 잎맥
        pygame.draw.arc(surf, vein_color, (2, h//4, w-4, h//2), 3.14, 0, 2)
        pygame.draw.line(surf, vein_color, (w-2, h//2), (4, h//2), 1)

    def _draw_leaf_type_3(self, surf, w, h, depth_factor):
        """톱니 월계수 잎 - 가장자리 톱니 (금빛)"""
        import pygame
        import math
        base_gold = (int(175 * depth_factor), int(135 * depth_factor), int(45 * depth_factor))
        mid_gold = (int(215 * depth_factor), int(175 * depth_factor), int(60 * depth_factor))
        light_gold = (int(250 * depth_factor), int(210 * depth_factor), int(75 * depth_factor))
        highlight = (int(255 * depth_factor), int(238 * depth_factor), int(145 * depth_factor))
        vein_color = (int(145 * depth_factor), int(105 * depth_factor), int(28 * depth_factor))

        # 톱니 모양 외곽
        points = []
        num_teeth = 6
        for i in range(num_teeth * 2 + 1):
            t = i / (num_teeth * 2)
            x = w - 2 - (w - 4) * t
            if i % 2 == 0:
                y_offset = 0
            else:
                y_offset = h // 8 if i < num_teeth else -h // 8
            base_y = h // 2
            curve = math.sin(t * math.pi) * (h // 3)
            if i <= num_teeth:
                y = base_y - curve + y_offset
            else:
                y = base_y + curve + y_offset
            points.append((x, max(1, min(h-1, y))))

        if len(points) > 2:
            pygame.draw.polygon(surf, base_gold, points)
        # 내부
        pygame.draw.ellipse(surf, mid_gold, (w//6, h//4, w*2//3, h//2))
        # 하이라이트
        pygame.draw.ellipse(surf, light_gold, (w//4, h//4, w//3, h//3))
        pygame.draw.ellipse(surf, highlight, (w//4 + 3, h//4 + 2, w//5, h//5))
        # 잎맥
        pygame.draw.line(surf, vein_color, (w-3, h//2), (5, h//2), 2)
        # 측면 잎맥
        for i in range(2):
            offset = (i + 1) * w // 4
            pygame.draw.line(surf, vein_color, (w - offset, h//2), (w - offset - 5, h//3), 1)
            pygame.draw.line(surf, vein_color, (w - offset, h//2), (w - offset - 5, h*2//3), 1)

    def draw_effects(self, screen):
        if not self.active:
            return
        import pygame
        import math
        # 토성의 고리처럼 가로로 긴 타원 궤도 (ellipse_scale_y로 Y축 압축)
        ellipse_scale_y = 0.3  # Y축을 30%로 압축하여 가로로 납작한 고리 형성

        # 잎들을 Y좌표 기준으로 정렬하여 뒤쪽(위)부터 그리기 (3D 효과)
        leaf_draw_order = []
        for leaf in self.leaves:
            if not leaf['active']:
                continue
            angle = self.current_angle + leaf['base_angle']
            leaf_x = self.player_x + math.cos(angle) * self.leaf_radius
            leaf_y = self.player_y + math.sin(angle) * self.leaf_radius * ellipse_scale_y
            # sin(angle) 값으로 깊이 판단: 음수가 뒤쪽(위), 양수가 앞쪽(아래)
            depth = math.sin(angle)
            leaf_draw_order.append((depth, angle, leaf_x, leaf_y, leaf))

        # 뒤쪽(위)부터 앞쪽(아래) 순으로 정렬하여 그리기
        leaf_draw_order.sort(key=lambda x: x[0])

        for depth, angle, leaf_x, leaf_y, leaf in leaf_draw_order:
            # 깊이에 따라 크기와 투명도 조절 (3D 원근감)
            depth_factor = 0.6 + 0.4 * ((depth + 1) / 2)  # 0.6 ~ 1.0 범위
            size_var = leaf.get('size_variation', 1.0)
            current_leaf_size = int(self.leaf_size * depth_factor * size_var)
            alpha_factor = 0.5 + 0.5 * ((depth + 1) / 2)  # 0.5 ~ 1.0 범위

            # 글로우 효과 (옅은 금빛)
            glow_alpha = int((30 + 20 * self.glow_intensity) * alpha_factor)  # 투명하게 조절
            glow_surf = pygame.Surface((current_leaf_size * 4, current_leaf_size * 3), pygame.SRCALPHA)
            pygame.draw.ellipse(glow_surf, (255, 215, 100, glow_alpha),  # 옅은 금빛
                              (0, 0, current_leaf_size * 4, current_leaf_size * 3))
            screen.blit(glow_surf, (leaf_x - current_leaf_size * 2, leaf_y - current_leaf_size * 1.5))

            # 잎 서피스 생성 (가로로 길게)
            leaf_w = int(current_leaf_size * 2.5)
            leaf_h = int(current_leaf_size * 1.2)
            leaf_surf = pygame.Surface((leaf_w, leaf_h), pygame.SRCALPHA)

            # 잎 타입에 따라 다른 모양 그리기
            leaf_type = leaf.get('leaf_type', 0)
            if leaf_type == 0:
                self._draw_leaf_type_0(leaf_surf, leaf_w, leaf_h, depth_factor)
            elif leaf_type == 1:
                self._draw_leaf_type_1(leaf_surf, leaf_w, leaf_h, depth_factor)
            elif leaf_type == 2:
                self._draw_leaf_type_2(leaf_surf, leaf_w, leaf_h, depth_factor)
            else:
                self._draw_leaf_type_3(leaf_surf, leaf_w, leaf_h, depth_factor)

            rotated = pygame.transform.rotate(leaf_surf, -math.degrees(angle))
            rect = rotated.get_rect(center=(int(leaf_x), int(leaf_y)))
            screen.blit(rotated, rect)

        for particle in self.removal_particles:
            alpha = min(255, particle['life'] * 6)
            color = particle['color']
            size = max(1, particle['life'] // 8)
            part_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            pygame.draw.circle(part_surf, (*color, alpha), (size, size), size)
            screen.blit(part_surf, (int(particle['x'] - size), int(particle['y'] - size)))

        # 장식 파티클 그리기 (반짝이, 별, 고리 등)
        for particle in self.decoration_particles:
            life_ratio = particle['life'] / particle['max_life']
            alpha = int(255 * life_ratio * 0.8)
            color = particle['color']
            p_size = particle['size'] * (0.5 + 0.5 * life_ratio)
            px, py = int(particle['x']), int(particle['y'])
            p_type = particle['type']

            if p_type == 'sparkle':
                # 반짝이 효과 (십자가 모양)
                sparkle_surf = pygame.Surface((int(p_size * 4), int(p_size * 4)), pygame.SRCALPHA)
                center = int(p_size * 2)
                # 십자가 라인
                pygame.draw.line(sparkle_surf, (*color, alpha),
                               (center - int(p_size), center), (center + int(p_size), center), max(1, int(p_size * 0.4)))
                pygame.draw.line(sparkle_surf, (*color, alpha),
                               (center, center - int(p_size)), (center, center + int(p_size)), max(1, int(p_size * 0.4)))
                # 대각선 (더 짧게)
                diag = int(p_size * 0.6)
                pygame.draw.line(sparkle_surf, (*color, int(alpha * 0.6)),
                               (center - diag, center - diag), (center + diag, center + diag), 1)
                pygame.draw.line(sparkle_surf, (*color, int(alpha * 0.6)),
                               (center - diag, center + diag), (center + diag, center - diag), 1)
                # 중심 빛
                pygame.draw.circle(sparkle_surf, (*color, min(255, alpha + 50)), (center, center), max(1, int(p_size * 0.3)))
                screen.blit(sparkle_surf, (px - center, py - center))

            elif p_type == 'trail':
                # 꼬리 효과 (작은 원들이 이어진 형태)
                trail_surf = pygame.Surface((int(p_size * 6), int(p_size * 3)), pygame.SRCALPHA)
                for i in range(4):
                    trail_alpha = int(alpha * (1 - i * 0.2))
                    trail_size = max(1, int(p_size * (1 - i * 0.15)))
                    cx = int(p_size * 3) - i * int(p_size * 0.8)
                    cy = int(p_size * 1.5)
                    pygame.draw.circle(trail_surf, (*color, trail_alpha), (cx, cy), trail_size)
                # 회전 적용
                rotated = pygame.transform.rotate(trail_surf, math.degrees(particle['angle']))
                rect = rotated.get_rect(center=(px, py))
                screen.blit(rotated, rect)

            elif p_type == 'ring':
                # 고리 효과 (확장하는 원)
                ring_size = int(p_size * (2 - life_ratio))  # 점점 커짐
                ring_surf = pygame.Surface((ring_size * 2 + 4, ring_size * 2 + 4), pygame.SRCALPHA)
                center = ring_size + 2
                thickness = max(1, int(p_size * 0.3 * life_ratio))
                pygame.draw.circle(ring_surf, (*color, int(alpha * 0.7)), (center, center), ring_size, thickness)
                # 내부 빛
                inner_alpha = int(alpha * 0.3 * life_ratio)
                pygame.draw.circle(ring_surf, (*color, inner_alpha), (center, center), max(1, ring_size - thickness))
                screen.blit(ring_surf, (px - center, py - center))

            elif p_type == 'star':
                # 별 효과 (5각 별)
                star_surf = pygame.Surface((int(p_size * 4), int(p_size * 4)), pygame.SRCALPHA)
                center = int(p_size * 2)
                # 5각 별 포인트 계산
                points = []
                for i in range(10):
                    angle_offset = particle['angle'] + (i * math.pi / 5) - (math.pi / 2)
                    if i % 2 == 0:
                        r = p_size * 1.2
                    else:
                        r = p_size * 0.5
                    px_star = center + int(math.cos(angle_offset) * r)
                    py_star = center + int(math.sin(angle_offset) * r)
                    points.append((px_star, py_star))
                if len(points) >= 3:
                    pygame.draw.polygon(star_surf, (*color, alpha), points)
                    # 별 테두리
                    pygame.draw.polygon(star_surf, (255, 255, 255, int(alpha * 0.5)), points, 1)
                screen.blit(star_surf, (px - center, py - center))

    def draw_icon(self, screen, x, y, size=32):
        import pygame
        import math

        # 애니메이션 프레임 업데이트 (draw_icon 호출 시마다)
        if self.animation_frames and len(self.animation_frames) > 1:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)

        # 위아래 천천히 움직이는 오프셋 (헤르메스 신발과 동일 - 먼저 계산)
        frame_offset = int(math.sin(self.animation_time * 2.5) * 2)
        frame_y = y + frame_offset

        # 파란색 원형 배경 애니메이션 (헤르메스 신발/_draw_common_legendary_frame과 완전 동일)
        pulse = (math.sin(self.animation_time * 4.0) + 1) / 2  # 0~1
        pulse_ratio = pulse  # 펄스 비율로 크기 변화
        base_radius = max(6, int(size * 0.42))
        outer_radius = min(size // 2, int(base_radius + size * 0.05 * pulse_ratio))
        inner_radius = max(4, int(outer_radius * 0.65))

        glow_surf = pygame.Surface((size, size), pygame.SRCALPHA)
        center = (size // 2, size // 2)
        # 외곽 파란색 글로우 (헤르메스 신발과 동일 색상)
        pygame.draw.circle(glow_surf, (30, 90, 170, 80), center, outer_radius)
        pygame.draw.circle(glow_surf, (70, 140, 200, 150), center, int(outer_radius * 0.85))
        pygame.draw.circle(glow_surf, (140, 190, 220, 190), center, inner_radius)

        # 글로우 배치 (위아래 움직임 적용 - 헤르메스 신발과 동일 위치)
        screen.blit(glow_surf, (x, frame_y))

        # 내부 붉은색 테두리 (프레임별 그라데이션) - 3겹 (헤르메스 신발과 동일)
        inner_pulse = (math.sin(self.animation_time * 6.0) + 1) / 2
        outer_inner_color = (
            int(150 + 70 * inner_pulse),
            int(30 + 35 * inner_pulse),
            int(30 + 35 * inner_pulse)
        )
        inner_inner_color = (
            int(120 + 60 * inner_pulse),
            int(10 + 25 * inner_pulse),
            int(10 + 25 * inner_pulse)
        )
        mid_inner_color = (
            (outer_inner_color[0] + inner_inner_color[0]) // 2,
            (outer_inner_color[1] + inner_inner_color[1]) // 2,
            (outer_inner_color[2] + inner_inner_color[2]) // 2,
        )

        inner_rect_outer = pygame.Rect(x + 2, frame_y + 2, size - 4, size - 4)
        inner_rect_mid = inner_rect_outer.inflate(-2, -2)
        inner_rect_inner = inner_rect_outer.inflate(-4, -4)

        pygame.draw.rect(screen, outer_inner_color, inner_rect_outer, 1)
        pygame.draw.rect(screen, mid_inner_color, inner_rect_mid, 1)
        pygame.draw.rect(screen, inner_inner_color, inner_rect_inner, 1)

        # 외곽 빨간색 테두리 (헤르메스 신발과 동일)
        border_color = COMMON_LEGENDARY_BORDER_COLOR
        border_rect = pygame.Rect(x - 1, frame_y - 1, size + 2, size + 2)
        pygame.draw.rect(screen, border_color, border_rect, 2)

        # L자 코너 장식 (파란색/흰색 그라데이션 - 헤르메스 신발과 동일)
        corner_color = COMMON_LEGENDARY_CORNER_COLOR
        corner_size = 8

        pygame.draw.lines(screen, corner_color, False,
                          [(x - 2, frame_y + corner_size), (x - 2, frame_y - 2), (x + corner_size, frame_y - 2)], 2)
        pygame.draw.lines(screen, corner_color, False,
                          [(x + size - corner_size + 2, frame_y - 2), (x + size + 2, frame_y - 2), (x + size + 2, frame_y + corner_size)], 2)
        pygame.draw.lines(screen, corner_color, False,
                          [(x - 2, frame_y + size - corner_size + 2), (x - 2, frame_y + size + 2), (x + corner_size, frame_y + size + 2)], 2)
        pygame.draw.lines(screen, corner_color, False,
                          [(x + size - corner_size + 2, frame_y + size + 2), (x + size + 2, frame_y + size + 2), (x + size + 2, frame_y + size - corner_size + 2)], 2)

        # 코너 원형 장식
        for cx, cy in [(x, frame_y), (x + size, frame_y), (x, frame_y + size), (x + size, frame_y + size)]:
            pygame.draw.circle(screen, corner_color, (cx, cy), 2)

        # 아이콘 프레임 그리기
        if self.animation_frames:
            frame = self.animation_frames[self.current_frame % len(self.animation_frames)]
            if size != 32:
                frame = pygame.transform.scale(frame, (size, size))
            screen.blit(frame, (x, frame_y))
        else:
            # 금빛 기본 아이콘
            pygame.draw.circle(screen, (220, 180, 60), (x + size // 2, frame_y + size // 2), size // 2 - 2)
            pygame.draw.circle(screen, (255, 0, 0), (x + size // 2, frame_y + size // 2), size // 2, 2)


class EmptyLegendary(LegendaryItem):
    """아이템 관리자 전용 전설 프리뷰 슬롯 - 천사의 가호 스타일 (주사위 없음)."""

    def __init__(self, name: str = "empty_legendary", korean_name: str = "빈전설"):
        super().__init__(
            name=name,
            korean_name=korean_name,
            description=f"{korean_name}: 추후 전설 효과를 위한 빈 슬롯",
            unlock_condition="아이템 관리자 미리보기",
        )
        self.unlocked = True

        # 천사의 가호와 동일한 애니메이션 프레임 구조
        self.animation_frames = []
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8  # 천사의 가호와 동일
        self._load_animation_frames()

    def _load_animation_frames(self):
        """애니메이션 프레임 로드 - 천사의 가호와 동일 (라그나로크 해머 프레임에서 중앙 제거)"""
        self.animation_frames.clear()

        frames_loaded = 0
        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                frame = pygame.image.load(frame_path).convert_alpha()
                cleaned_frame = _strip_legendary_red_ring(frame)
                # 중앙 제거 (천사의 가호와 동일)
                center_cleared = self._clear_center_content(cleaned_frame)
                self.animation_frames.append(center_cleared)
                frames_loaded += 1
            except Exception as e:
                pass  # print(f"[INFO] 빈전설 프레임 {i} 로드 실패: {e}")  # 디버그 비활성화

        pass  # print(f"빈전설 프레임 {frames_loaded}/8개 로드")  # 디버그 비활성화

    def _clear_center_content(self, frame: pygame.Surface) -> pygame.Surface:
        """프레임에서 테두리 영역(가장자리 6픽셀) 그대로 유지, 내부만 완전 제거"""
        result = frame.copy()
        width, height = frame.get_size()

        # 테두리 두께 (가장자리에서 이 범위 내의 픽셀은 그대로 유지)
        border_thickness = 6

        for py in range(height):
            for px in range(width):
                color = frame.get_at((px, py))
                if color.a == 0:
                    continue

                # 가장자리에서의 거리 계산
                dist_from_left = px
                dist_from_right = width - 1 - px
                dist_from_top = py
                dist_from_bottom = height - 1 - py

                # 가장 가까운 가장자리까지의 거리
                min_dist = min(dist_from_left, dist_from_right, dist_from_top, dist_from_bottom)

                # 테두리 영역이 아니면 (내부면) 모두 제거
                if min_dist >= border_thickness:
                    result.set_at((px, py), (0, 0, 0, 0))

        return result

    def activate(self, game_state: Dict):
        """실제 게임 효과는 존재하지 않는다."""
        self.active = False

    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """애니메이션 아이콘 그리기 - 신성 월계수 스타일 (중앙 월계수 그림 제외)"""
        import math

        # 애니메이션 프레임 업데이트
        self.frame_counter += 1
        if self.frame_counter >= self.animation_speed:
            self.frame_counter = 0
            self.current_frame = (self.current_frame + 1) % 8

        # 위아래 천천히 움직이는 오프셋 (다른 전설 아이템과 동일)
        frame_offset = int(math.sin(self.animation_time * 2.5) * 2)
        frame_y = y + frame_offset

        # animation_time 기반 펄스 (신성 월계수와 동일한 속도)
        pulse = (math.sin(self.animation_time * 4.0) + 1) / 2  # 0~1 사이 값

        # 커졌다 작아졌다 하는 원형 글로우 (금빛)
        glow_base_size = int(size * 1.3)
        glow_size = int(glow_base_size + size * 0.15 * pulse)
        glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)

        # 그라데이션 원형 글로우 (금빛)
        center = glow_size // 2
        for i in range(4):
            radius = center - i * (center // 5)
            if radius > 0:
                alpha = int(60 - i * 12 + pulse * 20)
                alpha = max(0, min(255, alpha))
                gold_intensity = int(180 + pulse * 40)
                glow_color = (min(255, gold_intensity + 40), min(255, gold_intensity), int(50 + pulse * 30), alpha)
                pygame.draw.circle(glow_surf, glow_color, (center, center), radius)

        # 글로우 중앙에 배치
        glow_x = x - (glow_size - size) // 2
        glow_y = frame_y - (glow_size - size) // 2
        screen.blit(glow_surf, (glow_x, glow_y))

        # 내부 붉은색 테두리 (프레임별 그라데이션) - 3겹
        inner_pulse = (math.sin(self.animation_time * 6.0) + 1) / 2
        outer_inner_color = (
            int(150 + 70 * inner_pulse),
            int(30 + 35 * inner_pulse),
            int(30 + 35 * inner_pulse)
        )
        inner_inner_color = (
            int(120 + 60 * inner_pulse),
            int(10 + 25 * inner_pulse),
            int(10 + 25 * inner_pulse)
        )
        mid_inner_color = (
            (outer_inner_color[0] + inner_inner_color[0]) // 2,
            (outer_inner_color[1] + inner_inner_color[1]) // 2,
            (outer_inner_color[2] + inner_inner_color[2]) // 2,
        )

        inner_rect_outer = pygame.Rect(x + 2, frame_y + 2, size - 4, size - 4)
        inner_rect_mid = inner_rect_outer.inflate(-2, -2)
        inner_rect_inner = inner_rect_outer.inflate(-4, -4)

        pygame.draw.rect(screen, outer_inner_color, inner_rect_outer, 1)
        pygame.draw.rect(screen, mid_inner_color, inner_rect_mid, 1)
        pygame.draw.rect(screen, inner_inner_color, inner_rect_inner, 1)

        # 외곽 빨간색 테두리
        border_color = (180, 50, 50)
        border_rect = pygame.Rect(x - 1, frame_y - 1, size + 2, size + 2)
        pygame.draw.rect(screen, border_color, border_rect, 2)

        # 코너 장식 (파란색/흰색 그라데이션)
        corner_pulse = (math.sin(self.animation_time * 3.0) + 1) / 2  # 0~1
        corner_color = (
            int(100 + 155 * corner_pulse),   # 100~255 (파란색 → 흰색)
            int(150 + 105 * corner_pulse),   # 150~255
            int(255)                          # 255 고정
        )
        corner_size = 8

        # L자 코너 장식 (다른 전설 아이템과 동일)
        pygame.draw.lines(screen, corner_color, False,
                          [(x - 2, frame_y + corner_size), (x - 2, frame_y - 2), (x + corner_size, frame_y - 2)], 2)
        pygame.draw.lines(screen, corner_color, False,
                          [(x + size - corner_size + 2, frame_y - 2), (x + size + 2, frame_y - 2), (x + size + 2, frame_y + corner_size)], 2)
        pygame.draw.lines(screen, corner_color, False,
                          [(x - 2, frame_y + size - corner_size + 2), (x - 2, frame_y + size + 2), (x + corner_size, frame_y + size + 2)], 2)
        pygame.draw.lines(screen, corner_color, False,
                          [(x + size - corner_size + 2, frame_y + size + 2), (x + size + 2, frame_y + size + 2), (x + size + 2, frame_y + size - corner_size + 2)], 2)

        # 코너 원형 장식
        for cx, cy in [(x, frame_y), (x + size, frame_y), (x, frame_y + size), (x + size, frame_y + size)]:
            pygame.draw.circle(screen, corner_color, (cx, cy), 2)

        # 중앙은 비워둠 (월계수 그림 제외) - 금빛 배경만 표시
        bg_pulse = int(pulse * 20)
        bg_color = (160 + bg_pulse, 130 + bg_pulse, 50)
        pygame.draw.circle(screen, bg_color, (x + size // 2, frame_y + size // 2), size // 2 - 4)


class AngelBlessing(LegendaryItem):
    """천사의 가호 - 스테이지 시작 시 천사의 주사위로 버프 선택 (롤 옵션: 버프 강도 Lv1~5)."""

    # 디버그 플래그 (성능 영향으로 비활성화)
    DEBUG_ENABLED = False

    # 버프 강도 레벨별 배율 (Lv1=10%, Lv2=20%, Lv3=30%, Lv4=40%, Lv5=50%)
    BUFF_LEVEL_MULTIPLIERS = {
        1: 0.10,  # 10%
        2: 0.20,  # 20%
        3: 0.30,  # 30%
        4: 0.40,  # 40%
        5: 0.50,  # 50%
    }

    def __init__(self):
        super().__init__(
            name="angel_blessing",
            korean_name="천사의 가호",
            description="스테이지 시작 시 천사의 주사위를 굴려 버프 획득 (롤 옵션: 버프 강도 Lv1~5)",
            unlock_condition="신화 아이템 수집가 업적",
            icon_path=None,  # 직접 렌더링
        )
        self.unlocked = True
        self.applied_stage: Optional[int] = None
        self._triggered_stages: set = set()  # 발동된 스테이지 이력 (재장착 방지용)
        self.active_buffs: List[str] = []
        self.roll_timer = 0.0
        self.roll_face = 1
        self.roll_anim_active = False
        self.roll_anim_duration = 3.0  # 3초간 화려한 연출
        self.waiting_for_space = False  # 스페이스바 대기 상태
        self._base_buff_level = 3  # 기본 버프 레벨 (롤 옵션으로 덮어씀)
        # 화려한 연출용 파티클 리스트
        self.holy_particles = []
        self.light_rays = []
        self.feathers = []
        self._frame_cache: Dict[int, pygame.Surface] = {}

        # 라그나로크 해머와 동일한 애니메이션 프레임 구조
        self.animation_frames = []
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8  # 라그나로크 해머와 동일
        self._load_animation_frames()
        self.enhancement_bonus_pct = 0  # 강화 버프 보너스 (장착 시 동기화)

    @property
    def buff_level(self) -> int:
        """버프 강도 레벨 (롤 옵션 적용, 연마 스킬 + 강화 보너스 포함, Lv1~5)"""
        return int(get_legendary_roll_value("angel_blessing", "buff_level", apply_polish=True, enhancement_bonus_pct=self.enhancement_bonus_pct))

    @property
    def buff_multiplier(self) -> float:
        """버프 강도 배율 (레벨에 따라 10%~50%)"""
        return self.BUFF_LEVEL_MULTIPLIERS.get(self.buff_level, 0.30)

    def activate(self, game_state: Dict):
        """장착/획득 시 - 같은 스테이지에서는 재발동하지 않음."""
        global _pending_angel_blessing_activation

        super().activate(game_state)

        # 전설 획득 애니메이션이 활성 상태면 대기열에 넣고 리턴
        try:
            from effects.legendary_integration import is_legendary_effect_active
            if is_legendary_effect_active():
                if self.DEBUG_ENABLED: print(f"[AngelBlessing.activate] 전설 획득 애니메이션 진행 중 - 주사위 굴림 대기")
                _pending_angel_blessing_activation = dict(game_state) if game_state else {}
                return
        except Exception as e:
            if self.DEBUG_ENABLED: print(f"[AngelBlessing.activate] 애니메이션 상태 확인 실패: {e}")

        stage = None
        try:
            stage = int(game_state.get("current_stage")) if isinstance(game_state, dict) else None
        except Exception:
            stage = game_state.get("current_stage") if isinstance(game_state, dict) else None
        if stage is None:
            stage = self._get_current_stage()

        # 같은 스테이지에서 이미 주사위를 굴렸으면 다시 굴리지 않음 (재장착 방지)
        if stage is not None and stage in self._triggered_stages:
            if self.DEBUG_ENABLED: print(f"[AngelBlessing] 스테이지 {stage}에서 이미 발동됨 - 재장착해도 재발동 안됨")
            return

        # 새로운 스테이지에서만 주사위 굴림 (_roll_blessing 내부에서 _triggered_stages에 추가)
        if stage is not None:
            self._roll_blessing(stage)

    # ------------------------------------------------------------------ #
    # Helpers
    # ------------------------------------------------------------------ #
    def _get_current_stage(self) -> Optional[int]:
        """pingfighter 전역(current_stage) 우선 조회 후, 로컬 globals fallback."""
        import sys
        pf = sys.modules.get("pingfighter")
        if pf is not None and hasattr(pf, "current_stage"):
            try:
                return int(getattr(pf, "current_stage"))
            except Exception:
                return getattr(pf, "current_stage", None)
        return globals().get("current_stage", None)

    def _set_global_multiplier(self, key: str, value: float):
        """글로벌 배율 세터 (핑파이터 전역까지 동기화)"""
        globals()[key] = value
        try:
            import sys
            pf = sys.modules.get("pingfighter")
            if pf is not None:
                setattr(pf, key, value)
        except Exception:
            pass

    def _reset_globals(self):
        """적용된 버프에 따른 전역 배율 복구"""
        import items
        import academy
        if hasattr(academy, "ANGEL_ITEM_COOLDOWN_MULTIPLIER"):
            academy.ANGEL_ITEM_COOLDOWN_MULTIPLIER = 1.0
        self._set_global_multiplier("ANGEL_PADDLE_SCALE", 1.0)
        self._set_global_multiplier("ANGEL_GAUGE_MULT", 1.0)
        import sys
        pf = sys.modules.get("pingfighter")
        prev_speed_mult = (
            getattr(pf, "ANGEL_SPEED_MULT", None)
            if pf is not None else None
        )
        if prev_speed_mult is None:
            prev_speed_mult = globals().get("ANGEL_SPEED_MULT", 1.0)
        self._set_global_multiplier("ANGEL_SPEED_MULT", 1.0)
        try:
            import dash_manager
            # _GLOBAL_DASH_INST 우선 사용 (실제 게임에서 사용하는 인스턴스)
            dm = dash_manager._GLOBAL_DASH_INST or dash_manager.get_dash_manager()
            if dm:
                dm.set_external_multipliers(1.0, 1.0)
                if self.DEBUG_ENABLED: print(f"[AngelBlessing] 대쉬 버프 초기화됨: cost=1.0, cooldown=1.0")
        except Exception:
            pass
        # 이동 속도 복구 (MAX_SPEED)
        if hasattr(self, "_original_max_speed") and self._original_max_speed is not None:
            if pf is not None and hasattr(pf, "MAX_SPEED"):
                pf.MAX_SPEED = self._original_max_speed
                if self.DEBUG_ENABLED: print(f"[AngelBlessing] MAX_SPEED 복원: {self._original_max_speed}")
            self._original_max_speed = None
        # 가속도 복구 (ACCELERATION)
        if hasattr(self, "_original_acceleration") and self._original_acceleration is not None:
            if pf is not None and hasattr(pf, "ACCELERATION"):
                pf.ACCELERATION = self._original_acceleration
                if self.DEBUG_ENABLED: print(f"[AngelBlessing] ACCELERATION 복원: {self._original_acceleration}")
            self._original_acceleration = None
        # 게이지 재계산
        try:
            calc_max = None
            if pf is not None and hasattr(pf, "get_max_gauge"):
                calc_max = pf.get_max_gauge
            elif "get_max_gauge" in globals():
                calc_max = get_max_gauge  # type: ignore[name-defined]
            if calc_max:
                max_g = calc_max()
                if pf is not None:
                    pf.special_gauge_max = max_g
                    pf.special_gauge = min(getattr(pf, "special_gauge", 0), max_g)
                else:
                    globals()["special_gauge_max"] = max_g
                    globals()["special_gauge"] = min(globals().get("special_gauge", 0), max_g)
        except Exception:
            pass
        # 패들 스케일 재적용
        try:
            current_scale = None
            if pf is not None and hasattr(pf, "CURRENT_PADDLE_EFFECTIVE_SCALE"):
                current_scale = getattr(pf, "CURRENT_PADDLE_EFFECTIVE_SCALE", None)
            elif "CURRENT_PADDLE_EFFECTIVE_SCALE" in globals():
                current_scale = globals()["CURRENT_PADDLE_EFFECTIVE_SCALE"]

            if current_scale is not None:
                if pf is not None and hasattr(pf, "set_paddle_scale"):
                    pf.set_paddle_scale(current_scale)
                elif "set_paddle_scale" in globals():
                    set_paddle_scale(current_scale)  # type: ignore[name-defined]

            # 패들 배율 변경 후 즉시 재계산
            if pf is not None and hasattr(pf, "apply_equipment_paddle_modifiers"):
                pf.apply_equipment_paddle_modifiers()
            elif "apply_equipment_paddle_modifiers" in globals():
                apply_equipment_paddle_modifiers()  # type: ignore[name-defined]
        except Exception:
            pass

        if self.DEBUG_ENABLED: print(f"[AngelBlessing] 버프 효과 해제됨 - 모든 보너스 초기화")

    def _apply_buff(self, buff: str):
        """선택된 버프 적용 (buff_multiplier 롤옵션 적용)"""
        import items
        import academy
        import sys
        pf = sys.modules.get("pingfighter")

        # 롤옵션 버프 배율 가져오기 (Lv1=10%, Lv2=20%, ..., Lv5=50%)
        buff_mult = self.buff_multiplier  # 0.10 ~ 0.50
        positive_mult = 1.0 + buff_mult   # 1.10 ~ 1.50 (증가 효과용)
        negative_mult = 1.0 - buff_mult   # 0.90 ~ 0.50 (감소 효과용)

        if buff == "paddle_size":
            self._set_global_multiplier("ANGEL_PADDLE_SCALE", positive_mult)
            try:
                current_scale = None
                if pf is not None and hasattr(pf, "CURRENT_PADDLE_EFFECTIVE_SCALE"):
                    current_scale = getattr(pf, "CURRENT_PADDLE_EFFECTIVE_SCALE", None)
                elif "CURRENT_PADDLE_EFFECTIVE_SCALE" in globals():
                    current_scale = globals()["CURRENT_PADDLE_EFFECTIVE_SCALE"]
                if current_scale is not None:
                    if pf is not None and hasattr(pf, "set_paddle_scale"):
                        pf.set_paddle_scale(current_scale)
                    elif "set_paddle_scale" in globals():
                        set_paddle_scale(current_scale)  # type: ignore[name-defined]
                # 패들 배율 변경 후 즉시 재계산
                if pf is not None and hasattr(pf, "apply_equipment_paddle_modifiers"):
                    pf.apply_equipment_paddle_modifiers()
                elif "apply_equipment_paddle_modifiers" in globals():
                    apply_equipment_paddle_modifiers()  # type: ignore[name-defined]
            except Exception:
                pass
            if self.DEBUG_ENABLED: print(f"[AngelBlessing] 패들 크기 버프 적용: +{int(buff_mult*100)}%")
        elif buff == "gauge_max":
            self._set_global_multiplier("ANGEL_GAUGE_MULT", positive_mult)
            try:
                calc_max = None
                if pf is not None and hasattr(pf, "get_max_gauge"):
                    calc_max = pf.get_max_gauge
                elif "get_max_gauge" in globals():
                    calc_max = get_max_gauge  # type: ignore[name-defined]
                if calc_max:
                    max_g = calc_max()
                    if pf is not None:
                        pf.special_gauge_max = max_g
                        pf.special_gauge = min(getattr(pf, "special_gauge", 0), max_g)
                    else:
                        globals()["special_gauge_max"] = max_g
                        globals()["special_gauge"] = min(globals().get("special_gauge", 0), max_g)
            except Exception:
                pass
            if self.DEBUG_ENABLED: print(f"[AngelBlessing] 최대 게이지 버프 적용: +{int(buff_mult*100)}%")
        elif buff == "item_cooldown":
            academy.ANGEL_ITEM_COOLDOWN_MULTIPLIER = negative_mult
            if self.DEBUG_ENABLED: print(f"[AngelBlessing] 아이템 쿨타임 버프 적용: -{int(buff_mult*100)}%")
        elif buff == "dash_cost":
            try:
                import dash_manager
                # _GLOBAL_DASH_INST 사용 (pingfighter.py에서 직접 참조하는 인스턴스)
                dm = dash_manager._GLOBAL_DASH_INST or dash_manager.get_dash_manager()
                if dm:
                    old_cost = getattr(dm, 'external_cost_multiplier', 1.0)
                    dm.set_external_multipliers(cost_mul=negative_mult)
                    new_cost = getattr(dm, 'external_cost_multiplier', 1.0)
                    if self.DEBUG_ENABLED: print(f"[AngelBlessing] 대쉬 비용 버프 적용: {old_cost} -> {new_cost} (-{int(buff_mult*100)}%)")
                else:
                    if self.DEBUG_ENABLED: print(f"[AngelBlessing] 대쉬 매니저를 찾을 수 없음")
            except Exception as e:
                if self.DEBUG_ENABLED: print(f"[AngelBlessing] 대쉬 비용 버프 적용 실패: {e}")
        elif buff == "dash_cooldown":
            try:
                import dash_manager
                # _GLOBAL_DASH_INST 사용 (pingfighter.py에서 직접 참조하는 인스턴스)
                dm = dash_manager._GLOBAL_DASH_INST or dash_manager.get_dash_manager()
                if dm:
                    old_mul = getattr(dm, 'external_cooldown_multiplier', 1.0)
                    dm.set_external_multipliers(cooldown_mul=negative_mult)
                    new_mul = getattr(dm, 'external_cooldown_multiplier', 1.0)
                    if self.DEBUG_ENABLED: print(f"[AngelBlessing] 대쉬 쿨타임 버프 적용: {old_mul} -> {new_mul} (-{int(buff_mult*100)}%)")
                else:
                    if self.DEBUG_ENABLED: print(f"[AngelBlessing] 대쉬 매니저를 찾을 수 없음")
            except Exception as e:
                if self.DEBUG_ENABLED: print(f"[AngelBlessing] 대쉬 쿨타임 버프 적용 실패: {e}")
        elif buff == "move_speed":
            # MAX_SPEED 증가 (실제 이동속도 결정 변수)
            try:
                if pf is not None and hasattr(pf, "MAX_SPEED"):
                    base_max_speed = getattr(pf, "MAX_SPEED", 5)
                    # 기본 MAX_SPEED 저장 (복원용) - 값이 None이거나 속성이 없으면 저장
                    if not hasattr(self, "_original_max_speed") or self._original_max_speed is None:
                        self._original_max_speed = base_max_speed
                    pf.MAX_SPEED = int(self._original_max_speed * positive_mult)  # 항상 원본 기준으로 계산
                    self._set_global_multiplier("ANGEL_SPEED_MULT", positive_mult)
                    if self.DEBUG_ENABLED: print(f"[AngelBlessing] 이동속도 버프 적용: MAX_SPEED {self._original_max_speed} -> {pf.MAX_SPEED} (+{int(buff_mult*100)}%)")
                # ACCELERATION도 증가 (이동속도 버프의 절반 정도 적용)
                if pf is not None and hasattr(pf, "ACCELERATION"):
                    base_accel = getattr(pf, "ACCELERATION", 0.4)
                    # 기본 ACCELERATION 저장 (복원용) - 값이 None이거나 속성이 없으면 저장
                    if not hasattr(self, "_original_acceleration") or self._original_acceleration is None:
                        self._original_acceleration = base_accel
                    accel_mult = 1.0 + (buff_mult * 0.6)  # 이동속도의 60% 정도 적용
                    pf.ACCELERATION = self._original_acceleration * accel_mult  # 항상 원본 기준으로 계산
                    if self.DEBUG_ENABLED: print(f"[AngelBlessing] 가속도 버프 적용: ACCELERATION {self._original_acceleration} -> {pf.ACCELERATION}")
            except Exception as e:
                if self.DEBUG_ENABLED: print(f"[AngelBlessing] 이동속도 버프 적용 실패: {e}")

    def deactivate(self):
        """천사의 가호 비활성화 - 모든 버프 효과 즉시 해제

        NOTE: applied_stage와 _triggered_stages는 유지하여 같은 스테이지 내
        재장착 시 재발동을 방지합니다.
        """
        if self.DEBUG_ENABLED: print(f"[AngelBlessing] 비활성화 시작 - 현재 버프: {self.active_buffs}")
        super().deactivate()
        self._reset_globals()  # 모든 버프 효과 해제
        # applied_stage와 _triggered_stages는 유지 (같은 스테이지 내 재발동 방지)
        self.active_buffs.clear()
        self.roll_anim_active = False
        self.waiting_for_space = False
        if self.DEBUG_ENABLED: print(f"[AngelBlessing] 비활성화 완료 - 버프 제거됨 (스테이지 {self.applied_stage} 발동 이력 유지)")

    def reset_for_new_game(self):
        """새 게임 시작 시 모든 발동 이력 초기화 (게임 오버/메인 메뉴 복귀 시 호출)"""
        self._triggered_stages.clear()
        self.applied_stage = None
        self.active_buffs.clear()
        self.roll_anim_active = False
        self.waiting_for_space = False
        if self.DEBUG_ENABLED: print("[AngelBlessing] 새 게임 - 발동 이력 초기화됨")

    def _roll_blessing(self, current_stage: int):
        """주사위 굴림 및 버프 적용"""
        import random
        # 이미 발동된 스테이지면 스킵 (재장착 방지)
        if current_stage in self._triggered_stages:
            if self.DEBUG_ENABLED: print(f"[AngelBlessing] 스테이지 {current_stage}에서 이미 발동됨 - 스킵")
            return
        if self.applied_stage == current_stage:
            return
        debug = os.environ.get("PINGF_DEBUG_ANGEL", "0") == "1"
        if debug:
            print(f"[AngelBlessing][DEBUG] roll start (stage={current_stage})")
        self._reset_globals()
        self._triggered_stages.add(current_stage)  # 발동 이력 기록
        dice_face = random.choice([1, 2, 3])
        # 옵션 중 복원 없는 랜덤 샘플
        selected = random.sample(list(ANGEL_BLESSING_OPTIONS), k=dice_face)
        self.active_buffs = selected
        self.applied_stage = current_stage
        self.roll_face = dice_face
        self.roll_anim_active = True
        self.roll_timer = 0.0
        self.waiting_for_space = False  # 스페이스바 대기 상태 초기화
        # 버프 적용
        for buff in selected:
            self._apply_buff(buff)
        if debug:
            print(f"[AngelBlessing][DEBUG] Stage {current_stage} 주사위 {dice_face} → {selected}")
        elif self.DEBUG_ENABLED:
            print(f"[AngelBlessing] Stage {current_stage} 주사위 {dice_face} → {selected}")

    def _load_animation_frames(self):
        """애니메이션 프레임 로드 - 천사의 가호는 주사위+날개 아이콘 사용"""
        self.animation_frames.clear()

        # 천사의 가호는 주사위 테마이므로 주사위 프레임 직접 생성
        # (라그나로크 해머 프레임을 사용하면 중앙이 비어 보임)
        self._generate_dice_frames()
        if self.DEBUG_ENABLED: print(f"천사의 가호: 주사위+날개 애니메이션 프레임 {len(self.animation_frames)}개 생성 완료")

    def _clear_center_content(self, frame: pygame.Surface) -> pygame.Surface:
        """프레임에서 중앙 망치/번개/손잡이/그림자 모두 제거하고 테두리만 유지"""
        result = frame.copy()
        width, height = frame.get_size()
        cx, cy = width // 2, height // 2

        # 중앙 영역 반경 - 더 넓게 설정
        inner_radius = min(width, height) * 0.45

        for py in range(height):
            for px in range(width):
                # 중앙으로부터의 거리 계산
                dist = math.sqrt((px - cx) ** 2 + (py - cy) ** 2)

                # 중앙 영역 내부는 전부 투명하게 제거 (파란원 배경도 제거)
                if dist < inner_radius:
                    result.set_at((px, py), (0, 0, 0, 0))

        return result

    def _generate_dice_frames(self):
        """PNG가 없을 경우 주사위 애니메이션 프레임 동적 생성"""
        frame_size = 60
        for frame_idx in range(8):
            surf = pygame.Surface((frame_size, frame_size), pygame.SRCALPHA)

            # 회전 각도 (8프레임으로 360도)
            rot_y = frame_idx * 45
            rot_x = math.sin(frame_idx * 0.8) * 15

            self._draw_dice_to_surface(surf, frame_size, rot_x, rot_y)
            self.animation_frames.append(surf)

        pass  # print(f"천사의 가호: 주사위 프레임 8개 동적 생성 완료")  # 디버그 비활성화

    def _draw_dice_to_surface(self, surf, size, rot_x, rot_y):
        """주사위를 서피스에 그리기 - 천사 날개 포함"""
        dice_size = int(size * 0.5)  # 주사위 크기 확대
        # 서피스 크기를 기준으로 정확한 중앙 계산
        surf_w, surf_h = surf.get_size()
        cx, cy = surf_w // 2, surf_h // 2

        # 천사 날개 그리기 (주사위 뒤에)
        wing_color = (255, 255, 255, 180)
        wing_glow = (200, 220, 255, 100)
        wing_width = int(size * 0.35)
        wing_height = int(size * 0.25)

        # 날개 펄럭임 효과
        wing_flap = math.sin(rot_y * 0.1) * 3

        # 왼쪽/오른쪽 대칭을 위한 공통 오프셋
        wing_attach_offset = 3  # 주사위에 붙는 지점

        # 왼쪽 날개 - 대칭 좌표
        left_wing_points = [
            (cx - wing_attach_offset, cy - 2),  # 중앙 연결점
            (cx - wing_width, cy - wing_height + wing_flap),  # 상단
            (cx - wing_width - 3, cy + wing_flap),  # 중간 끝
            (cx - wing_width + 5, cy + wing_height//2 + wing_flap),  # 하단
            (cx - wing_attach_offset, cy + 3),  # 중앙 하단 연결점
        ]

        # 오른쪽 날개 - 완벽히 대칭
        right_wing_points = [
            (cx + wing_attach_offset, cy - 2),  # 중앙 연결점
            (cx + wing_width, cy - wing_height + wing_flap),  # 상단
            (cx + wing_width + 3, cy + wing_flap),  # 중간 끝
            (cx + wing_width - 5, cy + wing_height//2 + wing_flap),  # 하단
            (cx + wing_attach_offset, cy + 3),  # 중앙 하단 연결점
        ]

        # 날개 글로우 효과
        pygame.draw.polygon(surf, wing_glow, left_wing_points)
        pygame.draw.polygon(surf, wing_glow, right_wing_points)

        # 날개 본체
        pygame.draw.polygon(surf, wing_color, left_wing_points)
        pygame.draw.polygon(surf, wing_color, right_wing_points)

        # 날개 깃털 라인 - 대칭으로 수정
        feather_color = (220, 230, 255, 150)
        feather_start_offset = 5
        for i in range(3):
            offset = (i + 1) * wing_width // 4
            # 왼쪽 깃털
            pygame.draw.line(surf, feather_color,
                           (cx - feather_start_offset, cy),
                           (cx - offset - feather_start_offset, cy - wing_height//2 + i*3 + wing_flap), 1)
            # 오른쪽 깃털 - 대칭
            pygame.draw.line(surf, feather_color,
                           (cx + feather_start_offset, cy),
                           (cx + offset + feather_start_offset, cy - wing_height//2 + i*3 + wing_flap), 1)

        sin_x, cos_x = math.sin(math.radians(rot_x)), math.cos(math.radians(rot_x))
        sin_y, cos_y = math.sin(math.radians(rot_y)), math.cos(math.radians(rot_y))

        def rotate_point(px, py, pz):
            x1 = px * cos_y - pz * sin_y
            z1 = px * sin_y + pz * cos_y
            y1 = py * cos_x - z1 * sin_x
            z2 = py * sin_x + z1 * cos_x
            return cx + int(x1), cy + int(y1), z2

        half = dice_size // 2
        vertices_3d = [
            (-half, -half, -half), (half, -half, -half),
            (half, half, -half), (-half, half, -half),
            (-half, -half, half), (half, -half, half),
            (half, half, half), (-half, half, half),
        ]

        vertices_2d = []
        vertices_depth = []
        for vx, vy, vz in vertices_3d:
            rx, ry, rz = rotate_point(vx, vy, vz)
            vertices_2d.append((rx, ry))
            vertices_depth.append(rz)

        faces = [
            ([0, 1, 2, 3], 1, (0, 0, -half), (1, 0, 0), (0, 1, 0)),
            ([5, 4, 7, 6], 6, (0, 0, half), (-1, 0, 0), (0, 1, 0)),
            ([4, 5, 1, 0], 2, (0, -half, 0), (1, 0, 0), (0, 0, 1)),
            ([3, 2, 6, 7], 5, (0, half, 0), (1, 0, 0), (0, 0, -1)),
            ([4, 0, 3, 7], 3, (-half, 0, 0), (0, 0, -1), (0, 1, 0)),
            ([1, 5, 6, 2], 4, (half, 0, 0), (0, 0, 1), (0, 1, 0)),
        ]

        def get_face_depth(face_data):
            return sum(vertices_depth[i] for i in face_data[0]) / 4

        faces_sorted = sorted(faces, key=get_face_depth, reverse=True)

        # 주사위 색상
        white_light = (255, 255, 255)
        white_mid = (240, 245, 255)
        white_dark = (220, 230, 245)
        edge_color = (180, 190, 210)
        pip_color = (80, 110, 180)

        pip_positions_local = {
            1: [(0, 0)],
            2: [(-0.45, -0.45), (0.45, 0.45)],
            3: [(-0.45, -0.45), (0, 0), (0.45, 0.45)],
            4: [(-0.45, -0.45), (0.45, -0.45), (-0.45, 0.45), (0.45, 0.45)],
            5: [(-0.45, -0.45), (0.45, -0.45), (0, 0), (-0.45, 0.45), (0.45, 0.45)],
            6: [(-0.45, -0.45), (0.45, -0.45), (-0.45, 0), (0.45, 0), (-0.45, 0.45), (0.45, 0.45)],
        }

        pip_size = max(2, int(half * 0.2))
        pip_scale = half * 0.7

        for face_data in faces_sorted[:3]:
            indices, face_num, center_3d, u_axis, v_axis = face_data
            points = [vertices_2d[i] for i in indices]

            avg_depth = sum(vertices_depth[i] for i in indices) / 4
            brightness = 0.75 + 0.25 * (avg_depth / half + 1) / 2
            brightness = min(1.0, max(0.65, brightness))

            if brightness > 0.88:
                base_color = white_light
            elif brightness > 0.78:
                base_color = white_mid
            else:
                base_color = white_dark

            adj_color = tuple(min(255, int(c * brightness)) for c in base_color)

            pygame.draw.polygon(surf, adj_color, points)
            pygame.draw.polygon(surf, edge_color, points, 1)

            for pu, pv in pip_positions_local.get(face_num, []):
                pip_3d_x = center_3d[0] + u_axis[0] * pu * pip_scale + v_axis[0] * pv * pip_scale
                pip_3d_y = center_3d[1] + u_axis[1] * pu * pip_scale + v_axis[1] * pv * pip_scale
                pip_3d_z = center_3d[2] + u_axis[2] * pu * pip_scale + v_axis[2] * pv * pip_scale
                pip_x, pip_y, _ = rotate_point(pip_3d_x, pip_3d_y, pip_3d_z)

                pygame.draw.circle(surf, (pip_color[0]//2, pip_color[1]//2, pip_color[2]//2),
                                  (pip_x + 1, pip_y + 1), pip_size)
                pygame.draw.circle(surf, pip_color, (pip_x, pip_y), pip_size)
                pygame.draw.circle(surf, (220, 230, 255),
                                  (pip_x - 1, pip_y - 1), max(1, pip_size // 3))

    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """애니메이션 아이콘 그리기 - 천사의 기운 오오라 + 중앙 흰색 주사위"""
        # 공통 배경 프레임 연출 (라그나로크 해머와 동일)
        frame_offset = _draw_common_legendary_frame(screen, x, y, size, self.animation_time)

        # 애니메이션 프레임 그리기 (중앙 망치 제거된 프레임 = 테두리만)
        if self.animation_frames and len(self.animation_frames) > 0:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)

            icon_y = y + frame_offset + int(self.animation_offset)
            current_icon = self.animation_frames[self.current_frame % len(self.animation_frames)]
            scaled_icon = pygame.transform.scale(current_icon, (size, size))
            screen.blit(scaled_icon, (x, icon_y))

            # ========== 천사의 기운 오오라 애니메이션 ==========
            cx, cy = x + size // 2, icon_y + size // 2
            aura_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            aura_cx, aura_cy = size, size  # 오오라 서피스 중심

            # 맥동 값 (다른 효과에서 사용)
            pulse = math.sin(self.animation_time * 3) * 0.15 + 0.85  # 0.7 ~ 1.0

            # 1. 빛나는 광선 (회전하는 신성한 빛줄기) - 대칭 배치
            ray_count = 8
            # 모든 광선에 동일한 길이 적용 (대칭 유지)
            ray_length = int(size * 0.38 + math.sin(self.animation_time * 5) * 3)
            inner_r = int(size * 0.22)
            for ray_i in range(ray_count):
                # 정확히 균등한 각도 간격으로 배치
                ray_angle = (self.animation_time * 40 + ray_i * (360 / ray_count)) % 360
                ray_rad = math.radians(ray_angle)

                # 빛줄기 시작점과 끝점
                start_x = aura_cx + int(math.cos(ray_rad) * inner_r)
                start_y = aura_cy + int(math.sin(ray_rad) * inner_r)
                end_x = aura_cx + int(math.cos(ray_rad) * ray_length)
                end_y = aura_cy + int(math.sin(ray_rad) * ray_length)

                # 빛줄기 그라데이션 (중심에서 바깥으로 투명해짐)
                ray_alpha = int(120 * pulse)
                ray_color = (255, 255, 200, ray_alpha)
                pygame.draw.line(aura_surf, ray_color, (start_x, start_y), (end_x, end_y), 2)

                # 더 밝은 중심선
                mid_end_x = aura_cx + int(math.cos(ray_rad) * (ray_length * 0.7))
                mid_end_y = aura_cy + int(math.sin(ray_rad) * (ray_length * 0.7))
                pygame.draw.line(aura_surf, (255, 255, 240, int(ray_alpha * 0.8)),
                               (start_x, start_y), (mid_end_x, mid_end_y), 1)

            # 3. 반짝이는 별 파티클 (주사위 주변을 도는 작은 별들) - 대칭 배치
            star_count = 6
            # 모든 별에 동일한 궤도 반경 적용 (대칭 유지)
            orbit_radius = int(size * 0.32 + math.sin(self.animation_time * 2) * 4)
            for star_i in range(star_count):
                # 정확히 균등한 각도 간격으로 회전
                star_angle = (self.animation_time * 60 + star_i * (360 / star_count)) % 360
                star_rad = math.radians(star_angle)

                star_x = aura_cx + int(math.cos(star_rad) * orbit_radius)
                star_y = aura_cy + int(math.sin(star_rad) * orbit_radius)

                # 별 크기 맥동 - 모든 별에 동일한 크기 적용 (대칭)
                star_size = int(2 + math.sin(self.animation_time * 8) * 1.5)
                star_alpha = int(180 + math.sin(self.animation_time * 6) * 60)

                # 별 모양 (4각 별)
                star_points = []
                for point_i in range(8):
                    point_angle = point_i * (360 / 8) + self.animation_time * 100
                    point_rad = math.radians(point_angle)
                    point_dist = star_size if point_i % 2 == 0 else star_size * 0.4
                    px = star_x + int(math.cos(point_rad) * point_dist)
                    py = star_y + int(math.sin(point_rad) * point_dist)
                    star_points.append((px, py))

                if len(star_points) >= 3:
                    pygame.draw.polygon(aura_surf, (255, 255, 200, star_alpha), star_points)
                    # 별 중심 하이라이트
                    pygame.draw.circle(aura_surf, (255, 255, 255, min(255, star_alpha + 50)),
                                      (star_x, star_y), max(1, star_size // 2))

            # 4. 부드러운 내부 글로우 (주사위 주변 발광)
            glow_pulse = math.sin(self.animation_time * 2.5) * 0.2 + 0.8
            for glow_i in range(3):
                glow_radius = int(size * 0.25 - glow_i * 3)
                glow_alpha = int((50 - glow_i * 12) * glow_pulse)
                glow_color = (255, 250, 220, max(0, glow_alpha))
                pygame.draw.circle(aura_surf, glow_color, (aura_cx, aura_cy), glow_radius)

            # 5. 떨어지는 깃털/빛 파티클
            feather_count = 4
            for f_i in range(feather_count):
                # 각 깃털이 다른 위상으로 떨어짐
                fall_phase = (self.animation_time * 0.8 + f_i * 0.7) % 2.0
                feather_x = aura_cx + int(math.sin(self.animation_time * 1.5 + f_i * 2) * size * 0.3)
                feather_y = aura_cy - int(size * 0.35) + int(fall_phase * size * 0.35)

                # 깃털이 내려갈수록 투명해짐
                feather_alpha = int(150 * (1 - fall_phase / 2.0))
                if feather_alpha > 0:
                    feather_size = int(3 + math.sin(self.animation_time * 4 + f_i) * 1)
                    # 작은 타원형 깃털
                    feather_rect = pygame.Rect(feather_x - feather_size, feather_y - 1,
                                              feather_size * 2, 3)
                    pygame.draw.ellipse(aura_surf, (255, 255, 240, feather_alpha), feather_rect)

            # 오오라 서피스를 화면에 블리트 (중심 맞춤)
            screen.blit(aura_surf, (cx - size, cy - size), special_flags=pygame.BLEND_RGBA_ADD)
            # ========== 천사의 기운 오오라 끝 ==========

            # 중앙에 흰색 주사위 그리기 (날개 없음, 부드러운 회전)
            dice_surf = pygame.Surface((size, size), pygame.SRCALPHA)
            # 부드러운 회전을 위해 animation_time 기반 연속 회전
            rot_y = (self.animation_time * 25) % 360  # 부드럽게 연속 회전
            rot_x = math.sin(self.animation_time * 0.8) * 8  # 부드러운 기울기
            self._draw_angel_dice_no_wings(dice_surf, size, rot_x, rot_y)
            screen.blit(dice_surf, (x, icon_y))
        else:
            # Fallback: 프레임이 없으면 기본 천사 주사위 아이콘 그리기
            icon_y = y + frame_offset + int(self.animation_offset)
            dice_color = (255, 255, 255)  # 흰색 주사위
            wing_color = (255, 240, 200)  # 금빛 날개
            halo_color = (255, 255, 180)  # 후광

            center_x = x + size // 2
            center_y = icon_y + size // 2

            # 후광 효과
            for i in range(3):
                halo_radius = size // 3 + i * 3
                halo_alpha = 80 - i * 20
                halo_surf = pygame.Surface((halo_radius * 2, halo_radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(halo_surf, (*halo_color, halo_alpha),
                                 (halo_radius, halo_radius), halo_radius)
                screen.blit(halo_surf, (center_x - halo_radius, center_y - halo_radius))

            # 날개 (왼쪽)
            wing_points_left = [
                (center_x - size // 6, center_y),
                (center_x - size // 3, center_y - size // 6),
                (center_x - size * 2 // 5, center_y - size // 8),
                (center_x - size // 3, center_y + size // 8),
                (center_x - size // 6, center_y + size // 12)
            ]
            pygame.draw.polygon(screen, wing_color, wing_points_left)
            pygame.draw.polygon(screen, (220, 200, 150), wing_points_left, 1)

            # 날개 (오른쪽)
            wing_points_right = [
                (center_x + size // 6, center_y),
                (center_x + size // 3, center_y - size // 6),
                (center_x + size * 2 // 5, center_y - size // 8),
                (center_x + size // 3, center_y + size // 8),
                (center_x + size // 6, center_y + size // 12)
            ]
            pygame.draw.polygon(screen, wing_color, wing_points_right)
            pygame.draw.polygon(screen, (220, 200, 150), wing_points_right, 1)

            # 주사위 본체
            dice_size = size // 3
            dice_rect = pygame.Rect(center_x - dice_size // 2, center_y - dice_size // 2,
                                   dice_size, dice_size)
            pygame.draw.rect(screen, dice_color, dice_rect, border_radius=3)
            pygame.draw.rect(screen, (200, 200, 200), dice_rect, 1, border_radius=3)

            # 주사위 눈 (6 표시)
            pip_color = (100, 100, 100)
            pip_size = max(2, dice_size // 8)
            pip_offset = dice_size // 4
            # 왼쪽 열
            pygame.draw.circle(screen, pip_color, (center_x - pip_offset, center_y - pip_offset), pip_size)
            pygame.draw.circle(screen, pip_color, (center_x - pip_offset, center_y), pip_size)
            pygame.draw.circle(screen, pip_color, (center_x - pip_offset, center_y + pip_offset), pip_size)
            # 오른쪽 열
            pygame.draw.circle(screen, pip_color, (center_x + pip_offset, center_y - pip_offset), pip_size)
            pygame.draw.circle(screen, pip_color, (center_x + pip_offset, center_y), pip_size)
            pygame.draw.circle(screen, pip_color, (center_x + pip_offset, center_y + pip_offset), pip_size)

    def _draw_2d_dice_result(self, screen: pygame.Surface, cx: int, cy: int, size: int, result: int):
        """2D 주사위 결과 그리기 - 결과 숫자만 명확하게 표시

        Args:
            screen: 화면 Surface
            cx, cy: 중심 좌표
            size: 주사위 크기
            result: 주사위 결과 (1-6)
        """
        half = size // 2

        # 천사 날개 (주사위 뒤에) - 대칭 좌표
        wing_color = (255, 255, 255, 220)
        wing_width = int(size * 0.35)
        wing_height = int(size * 0.25)
        wing_flap = math.sin(pygame.time.get_ticks() * 0.005) * 3

        # 날개 연결점 (주사위 가장자리)
        wing_attach = half // 2

        # 왼쪽 날개 - 대칭 좌표
        left_wing = [
            (cx - wing_attach, cy),
            (cx - half - wing_width, cy - wing_height + wing_flap),
            (cx - half - wing_width - 5, cy + wing_flap),
            (cx - half - wing_width + 10, cy + wing_height//2 + wing_flap),
            (cx - wing_attach, cy + 5),
        ]
        # 오른쪽 날개 - 완벽히 대칭
        right_wing = [
            (cx + wing_attach, cy),
            (cx + half + wing_width, cy - wing_height + wing_flap),
            (cx + half + wing_width + 5, cy + wing_flap),
            (cx + half + wing_width - 10, cy + wing_height//2 + wing_flap),
            (cx + wing_attach, cy + 5),
        ]
        pygame.draw.polygon(screen, wing_color, left_wing)
        pygame.draw.polygon(screen, wing_color, right_wing)

        # 깃털 디테일 - 대칭
        feather_color = (230, 240, 255, 180)
        for i in range(3):
            offset = (i + 1) * wing_width // 3
            # 왼쪽 깃털
            pygame.draw.line(screen, feather_color,
                           (cx - wing_attach, cy),
                           (cx - half - offset, cy - wing_height//2 + i*4 + wing_flap), 1)
            # 오른쪽 깃털 - 대칭
            pygame.draw.line(screen, feather_color,
                           (cx + wing_attach, cy),
                           (cx + half + offset, cy - wing_height//2 + i*4 + wing_flap), 1)

        # 주사위 배경 (흰색 사각형)
        dice_rect = pygame.Rect(cx - half, cy - half, size, size)
        pygame.draw.rect(screen, (255, 255, 255), dice_rect, border_radius=8)
        pygame.draw.rect(screen, (200, 180, 140), dice_rect, 3, border_radius=8)  # 골드 테두리

        # 주사위 눈 위치 (결과에 따라)
        pip_color = (80, 50, 150)  # 보라색
        pip_size = max(8, size // 8)
        pip_positions = {
            1: [(0, 0)],
            2: [(-0.35, -0.35), (0.35, 0.35)],
            3: [(-0.35, -0.35), (0, 0), (0.35, 0.35)],
            4: [(-0.35, -0.35), (0.35, -0.35), (-0.35, 0.35), (0.35, 0.35)],
            5: [(-0.35, -0.35), (0.35, -0.35), (0, 0), (-0.35, 0.35), (0.35, 0.35)],
            6: [(-0.35, -0.35), (0.35, -0.35), (-0.35, 0), (0.35, 0), (-0.35, 0.35), (0.35, 0.35)],
        }

        for px, py in pip_positions.get(result, []):
            pip_x = cx + int(px * size * 0.7)
            pip_y = cy + int(py * size * 0.7)
            # 그림자
            pygame.draw.circle(screen, (40, 30, 80), (pip_x + 2, pip_y + 2), pip_size)
            # 본체
            pygame.draw.circle(screen, pip_color, (pip_x, pip_y), pip_size)
            # 하이라이트
            pygame.draw.circle(screen, (255, 255, 255), (pip_x - 2, pip_y - 2), pip_size // 2)

    def _draw_angel_dice(self, surf: pygame.Surface, size: int, rot_x: float, rot_y: float):
        """중앙에 천사의 주사위 그리기 (천사 날개 + 3D 주사위)"""
        dice_size = int(size * 0.45)  # 주사위 크기 증가 (더 잘 보이도록)
        # 서피스 크기를 기준으로 정확한 중앙 계산
        surf_w, surf_h = surf.get_size()
        cx, cy = surf_w // 2, surf_h // 2

        # 천사 날개 그리기 (주사위 뒤에)
        wing_color = (255, 255, 255, 200)
        wing_glow = (220, 230, 255, 120)
        wing_width = int(size * 0.32)
        wing_height = int(size * 0.22)

        # 날개 펄럭임 효과
        wing_flap = math.sin(rot_y * 0.1) * 3

        # 왼쪽 날개 - 대칭 좌표
        wing_attach_offset = 3  # 주사위에 붙는 지점
        left_wing_points = [
            (cx - wing_attach_offset, cy - 2),
            (cx - wing_width, cy - wing_height + wing_flap),
            (cx - wing_width - 3, cy + wing_flap),
            (cx - wing_width + 5, cy + wing_height//2 + wing_flap),
            (cx - wing_attach_offset, cy + 3),
        ]

        # 오른쪽 날개 - 완벽히 대칭으로 수정
        right_wing_points = [
            (cx + wing_attach_offset, cy - 2),
            (cx + wing_width, cy - wing_height + wing_flap),
            (cx + wing_width + 3, cy + wing_flap),
            (cx + wing_width - 5, cy + wing_height//2 + wing_flap),
            (cx + wing_attach_offset, cy + 3),
        ]

        # 날개 글로우 효과
        pygame.draw.polygon(surf, wing_glow, left_wing_points)
        pygame.draw.polygon(surf, wing_glow, right_wing_points)

        # 날개 본체
        pygame.draw.polygon(surf, wing_color, left_wing_points)
        pygame.draw.polygon(surf, wing_color, right_wing_points)

        # 날개 깃털 라인 - 대칭으로 수정
        feather_color = (230, 240, 255, 180)
        feather_start_offset = 5
        for i in range(3):
            offset = (i + 1) * wing_width // 4
            # 왼쪽 깃털
            pygame.draw.line(surf, feather_color,
                           (cx - feather_start_offset, cy),
                           (cx - offset - feather_start_offset, cy - wing_height//2 + i*3 + wing_flap), 1)
            # 오른쪽 깃털 - 대칭
            pygame.draw.line(surf, feather_color,
                           (cx + feather_start_offset, cy),
                           (cx + offset + feather_start_offset, cy - wing_height//2 + i*3 + wing_flap), 1)

        # 3D 주사위 그리기
        sin_x, cos_x = math.sin(math.radians(rot_x)), math.cos(math.radians(rot_x))
        sin_y, cos_y = math.sin(math.radians(rot_y)), math.cos(math.radians(rot_y))

        def rotate_point(px, py, pz):
            x1 = px * cos_y - pz * sin_y
            z1 = px * sin_y + pz * cos_y
            y1 = py * cos_x - z1 * sin_x
            z2 = py * sin_x + z1 * cos_x
            return cx + int(x1), cy + int(y1), z2

        half = dice_size // 2
        vertices_3d = [
            (-half, -half, -half), (half, -half, -half),
            (half, half, -half), (-half, half, -half),
            (-half, -half, half), (half, -half, half),
            (half, half, half), (-half, half, half),
        ]

        vertices_2d = []
        vertices_depth = []
        for vx, vy, vz in vertices_3d:
            rx, ry, rz = rotate_point(vx, vy, vz)
            vertices_2d.append((rx, ry))
            vertices_depth.append(rz)

        faces = [
            ([0, 1, 2, 3], 1, (0, 0, -half), (1, 0, 0), (0, 1, 0)),
            ([5, 4, 7, 6], 6, (0, 0, half), (-1, 0, 0), (0, 1, 0)),
            ([4, 5, 1, 0], 2, (0, -half, 0), (1, 0, 0), (0, 0, 1)),
            ([3, 2, 6, 7], 5, (0, half, 0), (1, 0, 0), (0, 0, -1)),
            ([4, 0, 3, 7], 3, (-half, 0, 0), (0, 0, -1), (0, 1, 0)),
            ([1, 5, 6, 2], 4, (half, 0, 0), (0, 0, 1), (0, 1, 0)),
        ]

        def get_face_depth(face_data):
            return sum(vertices_depth[i] for i in face_data[0]) / 4

        faces_sorted = sorted(faces, key=get_face_depth, reverse=True)

        # 주사위 색상 (흰색 기반 + 골드 하이라이트)
        white_light = (255, 255, 255)
        white_mid = (245, 248, 255)
        white_dark = (230, 235, 245)
        edge_color = (200, 180, 140)  # 골드 테두리
        pip_color = (100, 80, 180)  # 보라색 점

        pip_positions_local = {
            1: [(0, 0)],
            2: [(-0.4, -0.4), (0.4, 0.4)],
            3: [(-0.4, -0.4), (0, 0), (0.4, 0.4)],
            4: [(-0.4, -0.4), (0.4, -0.4), (-0.4, 0.4), (0.4, 0.4)],
            5: [(-0.4, -0.4), (0.4, -0.4), (0, 0), (-0.4, 0.4), (0.4, 0.4)],
            6: [(-0.4, -0.4), (0.4, -0.4), (-0.4, 0), (0.4, 0), (-0.4, 0.4), (0.4, 0.4)],
        }

        # 주사위 눈 크기 증가 (더 명확하게 보이도록)
        pip_size = max(4, int(half * 0.25))  # 크기 증가
        pip_scale = half * 0.55  # 눈금 간격 조정

        for face_data in faces_sorted[:3]:
            indices, face_num, center_3d, u_axis, v_axis = face_data
            points = [vertices_2d[i] for i in indices]

            avg_depth = sum(vertices_depth[i] for i in indices) / 4
            brightness = 0.75 + 0.25 * (avg_depth / half + 1) / 2
            brightness = min(1.0, max(0.65, brightness))

            if brightness > 0.88:
                base_color = white_light
            elif brightness > 0.78:
                base_color = white_mid
            else:
                base_color = white_dark

            adj_color = tuple(min(255, int(c * brightness)) for c in base_color)

            pygame.draw.polygon(surf, adj_color, points)
            pygame.draw.polygon(surf, edge_color, points, 2)  # 테두리 두께 증가

            for pu, pv in pip_positions_local.get(face_num, []):
                pip_3d_x = center_3d[0] + u_axis[0] * pu * pip_scale + v_axis[0] * pv * pip_scale
                pip_3d_y = center_3d[1] + u_axis[1] * pu * pip_scale + v_axis[1] * pv * pip_scale
                pip_3d_z = center_3d[2] + u_axis[2] * pu * pip_scale + v_axis[2] * pv * pip_scale
                pip_x, pip_y, _ = rotate_point(pip_3d_x, pip_3d_y, pip_3d_z)

                # 눈금 그림자 (더 진하게)
                pygame.draw.circle(surf, (40, 30, 80),
                                  (pip_x + 2, pip_y + 2), pip_size)
                # 눈금 본체 (더 진한 보라색)
                pygame.draw.circle(surf, (80, 50, 150), (pip_x, pip_y), pip_size)
                # 눈금 외곽선 (더 명확하게)
                pygame.draw.circle(surf, (60, 40, 120), (pip_x, pip_y), pip_size, 1)
                # 하이라이트 (더 크게)
                pygame.draw.circle(surf, (255, 255, 255),
                                  (pip_x - 1, pip_y - 1), max(2, pip_size // 2))

    def _draw_angel_dice_no_wings(self, surf: pygame.Surface, size: int, rot_x: float, rot_y: float):
        """중앙에 흰색 주사위 + 천사 날개 문양 그리기 - 아이콘용"""
        dice_size = int(size * 0.5)  # 주사위 크기
        cx, cy = size // 2, size // 2

        # 3D 주사위 그리기
        sin_x, cos_x = math.sin(math.radians(rot_x)), math.cos(math.radians(rot_x))
        sin_y, cos_y = math.sin(math.radians(rot_y)), math.cos(math.radians(rot_y))

        def rotate_point(px, py, pz):
            x1 = px * cos_y - pz * sin_y
            z1 = px * sin_y + pz * cos_y
            y1 = py * cos_x - z1 * sin_x
            z2 = py * sin_x + z1 * cos_x
            return cx + int(x1), cy + int(y1), z2

        half = dice_size // 2
        vertices_3d = [
            (-half, -half, -half), (half, -half, -half),
            (half, half, -half), (-half, half, -half),
            (-half, -half, half), (half, -half, half),
            (half, half, half), (-half, half, half),
        ]

        vertices_2d = []
        vertices_depth = []
        for vx, vy, vz in vertices_3d:
            rx, ry, rz = rotate_point(vx, vy, vz)
            vertices_2d.append((rx, ry))
            vertices_depth.append(rz)

        faces = [
            ([0, 1, 2, 3], 1, (0, 0, -half), (1, 0, 0), (0, 1, 0)),
            ([5, 4, 7, 6], 6, (0, 0, half), (-1, 0, 0), (0, 1, 0)),
            ([4, 5, 1, 0], 2, (0, -half, 0), (1, 0, 0), (0, 0, 1)),
            ([3, 2, 6, 7], 5, (0, half, 0), (1, 0, 0), (0, 0, -1)),
            ([4, 0, 3, 7], 3, (-half, 0, 0), (0, 0, -1), (0, 1, 0)),
            ([1, 5, 6, 2], 4, (half, 0, 0), (0, 0, 1), (0, 1, 0)),
        ]

        def get_face_depth(face_data):
            return sum(vertices_depth[i] for i in face_data[0]) / 4

        faces_sorted = sorted(faces, key=get_face_depth, reverse=True)

        # 흰색 주사위 색상 (순백색 계열)
        white_light = (255, 255, 255)
        white_mid = (248, 250, 255)
        white_dark = (235, 240, 250)
        edge_color = (200, 200, 210)  # 은색 테두리

        for face_data in faces_sorted[:3]:
            indices, face_num, center_3d, u_axis, v_axis = face_data
            points = [vertices_2d[i] for i in indices]

            avg_depth = sum(vertices_depth[i] for i in indices) / 4
            brightness = 0.75 + 0.25 * (avg_depth / half + 1) / 2
            brightness = min(1.0, max(0.65, brightness))

            if brightness > 0.88:
                base_color = white_light
            elif brightness > 0.78:
                base_color = white_mid
            else:
                base_color = white_dark

            adj_color = tuple(min(255, int(c * brightness)) for c in base_color)

            pygame.draw.polygon(surf, adj_color, points)
            pygame.draw.polygon(surf, edge_color, points, 1)

            # 각 면의 중심에 천사 날개 문양 그리기
            face_center_x = center_3d[0]
            face_center_y = center_3d[1]
            face_center_z = center_3d[2]
            wing_cx, wing_cy, _ = rotate_point(face_center_x, face_center_y, face_center_z)

            # 날개 크기 (면 크기에 비례)
            wing_scale = half * 0.6

            # 날개 색상 (은은한 금색/베이지)
            wing_color = (220, 200, 160, int(200 * brightness))
            wing_outline = (180, 160, 120, int(180 * brightness))

            # 왼쪽 날개 (작은 삼각형 형태)
            left_wing = [
                (wing_cx - 1, wing_cy),
                (wing_cx - int(wing_scale * 0.7), wing_cy - int(wing_scale * 0.4)),
                (wing_cx - int(wing_scale * 0.5), wing_cy + int(wing_scale * 0.2)),
            ]

            # 오른쪽 날개
            right_wing = [
                (wing_cx + 1, wing_cy),
                (wing_cx + int(wing_scale * 0.7), wing_cy - int(wing_scale * 0.4)),
                (wing_cx + int(wing_scale * 0.5), wing_cy + int(wing_scale * 0.2)),
            ]

            # 날개 그리기
            pygame.draw.polygon(surf, wing_color[:3], left_wing)
            pygame.draw.polygon(surf, wing_color[:3], right_wing)
            pygame.draw.polygon(surf, wing_outline[:3], left_wing, 1)
            pygame.draw.polygon(surf, wing_outline[:3], right_wing, 1)

            # 중앙에 작은 원 (천사의 머리/후광 표현)
            halo_color = (240, 220, 180)
            pygame.draw.circle(surf, halo_color, (wing_cx, wing_cy - int(wing_scale * 0.15)), max(2, int(wing_scale * 0.15)))

    def _spawn_particle(self, screen, cx, cy):
        """파티클 생성 - 라그나로크 해머와 동일"""
        for _ in range(2):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(8, 18)
            px = cx + int(math.cos(angle) * dist)
            py = cy + int(math.sin(angle) * dist)
            pygame.draw.circle(screen, (255, 255, 220, 180), (px, py), random.randint(1, 2))

    def draw_roll_animation(self, screen: pygame.Surface):
        """스테이지 시작 시 화면 전체에 천사의 주사위 애니메이션 그리기 (악마의 주사위와 유사)"""
        import pygame.freetype

        if not self.roll_anim_active:
            return False

        # 결과 표시 중이고 스페이스바 대기 상태인지 확인
        waiting_for_space = getattr(self, 'waiting_for_space', False)

        screen_w, screen_h = screen.get_size()

        # 전체 화면 반투명 오버레이 (어두운 보라색/남색 계열 - 눈이 편안하도록)
        overlay = pygame.Surface((screen_w, screen_h), pygame.SRCALPHA)
        overlay.fill((20, 15, 40, 180))  # 어두운 남색 배경
        screen.blit(overlay, (0, 0))

        # 패널 크기와 위치 (7개 옵션 모두 표시할 수 있도록 높이 증가)
        panel_width = 500
        panel_height = 520
        panel_x = (screen_w - panel_width) // 2
        panel_y = (screen_h - panel_height) // 2

        # 패널 배경 (어두운 보라색 계열)
        panel_surf = pygame.Surface((panel_width, panel_height), pygame.SRCALPHA)
        pygame.draw.rect(panel_surf, (40, 35, 70, 240), (0, 0, panel_width, panel_height), border_radius=20)
        pygame.draw.rect(panel_surf, (180, 160, 220, 255), (0, 0, panel_width, panel_height), 3, border_radius=20)
        screen.blit(panel_surf, (panel_x, panel_y))

        # 폰트 로드 (pygame.freetype 사용 - 한글 지원)
        title_font = None
        small_font = None
        font_paths = [
            "fonts/NanumSquareB.ttf",
            "fonts/NanumSquareR.ttf",
            "NanumSquareB.ttf",
            "NanumSquareR.ttf",
        ]
        for font_path in font_paths:
            if title_font and small_font:
                break
            try:
                title_font = pygame.freetype.Font(resource_path(font_path), 28)
                small_font = pygame.freetype.Font(resource_path(font_path), 18)
            except Exception:
                continue

        # 제목 "천사의 가호"
        if title_font:
            title_surf, title_rect = title_font.render(_t("legend.angel_blessing", "천사의 가호"), (220, 200, 255))
            title_rect.centerx = screen_w // 2
            title_rect.y = panel_y + 20
            screen.blit(title_surf, title_rect)
        else:
            # fallback: pygame.font 사용
            try:
                fallback_title = pygame.font.Font(None, 32)
                title_surf = fallback_title.render("Angel's Blessing", True, (220, 200, 255))
                title_rect = title_surf.get_rect(centerx=screen_w // 2, y=panel_y + 20)
                screen.blit(title_surf, title_rect)
            except Exception:
                pass

        # 주사위 애니메이션 중앙에 그리기
        dice_center_x = screen_w // 2
        dice_center_y = panel_y + 140
        base_dice_size = 120

        # 애니메이션 진행률 (0.0 ~ 1.0)
        progress = min(1.0, self.roll_timer / self.roll_anim_duration)
        anim_time = self.roll_timer

        # ========== 🌟 Phase 1: 성스러운 빛 강림 (0% ~ 20%) ==========
        if progress < 0.2:
            phase_progress = progress / 0.2

            # 하늘에서 내려오는 빛줄기들
            num_rays = 12
            for i in range(num_rays):
                ray_angle = (i / num_rays) * math.pi * 2 + anim_time * 2
                ray_length = 300 * phase_progress
                ray_width = 3 + int(5 * math.sin(anim_time * 8 + i))

                start_x = dice_center_x + int(math.cos(ray_angle) * 20)
                start_y = dice_center_y + int(math.sin(ray_angle) * 20)
                end_x = dice_center_x + int(math.cos(ray_angle) * ray_length)
                end_y = dice_center_y + int(math.sin(ray_angle) * ray_length)

                # 빛줄기 (황금색 그라데이션)
                ray_alpha = int(150 * phase_progress * (0.5 + 0.5 * math.sin(anim_time * 6 + i)))
                ray_color = (255, 220, 100, ray_alpha)
                pygame.draw.line(screen, ray_color, (start_x, start_y), (end_x, end_y), ray_width)

            # 중앙 글로우 효과
            glow_radius = int(80 * phase_progress)
            if glow_radius > 0:
                glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
                for r in range(glow_radius, 0, -3):
                    alpha = int(100 * (1 - r / glow_radius) * phase_progress)
                    pygame.draw.circle(glow_surf, (255, 255, 200, alpha), (glow_radius, glow_radius), r)
                screen.blit(glow_surf, (dice_center_x - glow_radius, dice_center_y - glow_radius))

            # Phase 1 후반: 주사위가 빛 속에서 등장
            if phase_progress > 0.3:
                appear_progress = (phase_progress - 0.3) / 0.7
                dice_alpha = int(255 * appear_progress)
                dice_size = int(base_dice_size * (0.5 + 0.5 * appear_progress))

                dice_surf = pygame.Surface((dice_size + 40, dice_size + 40), pygame.SRCALPHA)
                rot_y = anim_time * 100 % 360  # 빠르게 회전
                rot_x = math.sin(anim_time * 8) * 20
                self._draw_angel_dice(dice_surf, dice_size, rot_x, rot_y)
                dice_surf.set_alpha(dice_alpha)
                dice_rect = dice_surf.get_rect(center=(dice_center_x, dice_center_y))
                screen.blit(dice_surf, dice_rect)

        # ========== 🎲 Phase 2: 주사위 회전 (20% ~ 75%) ==========
        if progress >= 0.2 and progress < 0.75:
            phase_progress = (progress - 0.2) / 0.55

            # 회전 속도 (처음엔 매우 빠르게, 점점 느려짐)
            spin_speed = (1.0 - phase_progress) * 30
            rot_y = (anim_time * spin_speed * 80) % 360
            rot_x = math.sin(anim_time * 5) * 25 * (1.0 - phase_progress)

            # 주사위 크기 - 약간 커졌다 작아지는 펄스
            size_pulse = 1.0 + 0.15 * math.sin(anim_time * 12) * (1.0 - phase_progress)
            dice_size = int(base_dice_size * size_pulse)

            # 주사위 바운스 + 회전 효과 (먼저 계산)
            bounce_y = math.sin(anim_time * 10) * 15 * (1.0 - phase_progress)
            bounce_x = math.cos(anim_time * 7) * 10 * (1.0 - phase_progress)

            # 주사위 실제 중심 위치 (바운스 적용)
            actual_dice_x = dice_center_x + bounce_x
            actual_dice_y = dice_center_y + bounce_y

            # 회전하는 천사 깃털 파티클 (주사위 뒤에 먼저 그리기) - 중앙 대칭
            num_feathers = 8
            for i in range(num_feathers):
                # 정확히 균등한 각도 간격으로 배치
                feather_angle = (i / num_feathers) * math.pi * 2 + anim_time * 3
                # 모든 깃털에 동일한 거리 적용 (대칭 유지)
                feather_dist = 60 + 30 * math.sin(anim_time * 4)
                # 주사위 바운스 위치를 중심으로 대칭 배치
                feather_x = actual_dice_x + math.cos(feather_angle) * feather_dist
                feather_y = actual_dice_y + math.sin(feather_angle) * feather_dist

                # 깃털 모양 (대칭 타원) - 모든 깃털 동일한 크기
                feather_size = 4 + int(3 * math.sin(anim_time * 6))
                feather_height = max(1, feather_size)
                feather_width = feather_size * 2

                # 깃털 서피스 생성 및 회전
                feather_surf = pygame.Surface((feather_width + 4, feather_height + 4), pygame.SRCALPHA)
                pygame.draw.ellipse(feather_surf, (255, 255, 255, 200),
                                   (2, 2, feather_width, feather_height))
                # 깃털이 궤도 접선 방향으로 회전
                feather_rotation = math.degrees(feather_angle) + 90
                rotated_feather = pygame.transform.rotate(feather_surf, -feather_rotation)
                feather_rect = rotated_feather.get_rect(center=(int(feather_x), int(feather_y)))
                screen.blit(rotated_feather, feather_rect)

            # 3D 주사위 그리기 (깃털 위에) - 서피스 크기를 충분히 확보하여 중앙 정렬
            dice_surf_size = dice_size + 40
            dice_surf = pygame.Surface((dice_surf_size, dice_surf_size), pygame.SRCALPHA)
            self._draw_angel_dice(dice_surf, dice_size, rot_x, rot_y)
            dice_rect = dice_surf.get_rect(center=(int(actual_dice_x), int(actual_dice_y)))
            screen.blit(dice_surf, dice_rect)

            # 반짝이는 별 파티클 (주사위 주변, 대칭 배치)
            num_stars = 6
            for star_i in range(num_stars):
                # 시간 기반으로 결정적인 위치 계산 (랜덤 대신)
                star_angle = (star_i / num_stars) * math.pi * 2 + anim_time * 2
                star_dist = 50 + 30 * math.sin(anim_time * 3 + star_i * 0.5)
                star_x = int(actual_dice_x + math.cos(star_angle) * star_dist)
                star_y = int(actual_dice_y + math.sin(star_angle) * star_dist)
                star_size = 2 + int(2 * abs(math.sin(anim_time * 5 + star_i)))
                star_alpha = 150 + int(100 * abs(math.sin(anim_time * 4 + star_i * 0.7)))
                pygame.draw.circle(screen, (255, 255, 200, star_alpha), (star_x, star_y), star_size)

        # ========== ✨ Phase 3: 결과 확정 연출 (75% ~ 90%) ==========
        elif progress >= 0.75 and progress < 0.9:
            phase_progress = (progress - 0.75) / 0.15

            # 결과 확정 시 폭발하는 빛 (먼저 그리기)
            if phase_progress < 0.5:
                explosion_progress = phase_progress / 0.5
                explosion_radius = int(150 * explosion_progress)
                explosion_alpha = int(200 * (1.0 - explosion_progress))

                explosion_surf = pygame.Surface((explosion_radius * 2, explosion_radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(explosion_surf, (255, 255, 220, explosion_alpha),
                                  (explosion_radius, explosion_radius), explosion_radius)
                screen.blit(explosion_surf, (dice_center_x - explosion_radius, dice_center_y - explosion_radius))

            # 황금 링 이펙트
            ring_radius = int(50 + 100 * phase_progress)
            ring_alpha = int(255 * (1.0 - phase_progress * 0.5))
            pygame.draw.circle(screen, (255, 215, 0, ring_alpha),
                              (dice_center_x, dice_center_y), ring_radius, 3)

            # 2D 주사위 결과 표시 (정면 뷰)
            dice_size = int(base_dice_size * (1.0 + 0.1 * phase_progress))
            self._draw_2d_dice_result(screen, dice_center_x, dice_center_y, dice_size, self.roll_face)

        # ========== 🏆 Phase 4: 결과 표시 (90% ~ 100%) ==========
        else:
            phase_progress = (progress - 0.9) / 0.1 if progress < 1.0 else 1.0

            # 성스러운 후광 효과 (계속 유지)
            halo_pulse = 0.8 + 0.2 * math.sin(anim_time * 3)
            halo_radius = int(70 * halo_pulse)
            halo_surf = pygame.Surface((halo_radius * 2 + 20, halo_radius * 2 + 20), pygame.SRCALPHA)
            for r in range(halo_radius, 0, -5):
                alpha = int(60 * (1 - r / halo_radius))
                pygame.draw.circle(halo_surf, (255, 255, 200, alpha),
                                  (halo_radius + 10, halo_radius + 10), r)
            screen.blit(halo_surf, (dice_center_x - halo_radius - 10, dice_center_y - halo_radius - 10))

            # 2D 주사위 결과 표시 (정면 뷰) - 고정
            dice_size = int(base_dice_size * 1.1)
            self._draw_2d_dice_result(screen, dice_center_x, dice_center_y, dice_size, self.roll_face)

        # ========== 공통: 떨어지는 천사 깃털 (항상) ==========
        if progress > 0.1:
            num_falling_feathers = int(10 * min(1.0, progress * 2))
            for i in range(num_falling_feathers):
                feather_seed = i * 1234.5
                feather_x = screen_w // 2 + int(math.sin(feather_seed + anim_time * 0.5) * 200)
                feather_y = int((anim_time * 50 + feather_seed) % (screen_h + 50)) - 25
                feather_sway = math.sin(anim_time * 2 + feather_seed) * 20

                # 깃털 그리기
                feather_alpha = int(180 * (1.0 - feather_y / screen_h))
                if feather_alpha > 0:
                    pygame.draw.ellipse(screen, (255, 255, 255, min(255, feather_alpha)),
                                       (feather_x + feather_sway - 6, feather_y - 3, 12, 6))

        # 결과 텍스트 영역
        results_y = panel_y + 220

        # 버프 강도 퍼센트 (롤옵션 적용)
        buff_pct = int(self.buff_multiplier * 100)  # 10% ~ 50%

        # 버프 이름 (한글/영문) - 롤옵션 버프 강도 적용
        buff_names_kr = {
            "paddle_size": f"패들 크기 +{buff_pct}%",
            "gauge_max": f"최대 게이지 +{buff_pct}%",
            "item_cooldown": f"아이템 쿨타임 -{buff_pct}%",
            "dash_cost": f"대쉬 비용 -{buff_pct}%",
            "dash_cooldown": f"대쉬 쿨타임 -{buff_pct}%",
            "move_speed": f"이동 속도 +{buff_pct}%",
        }
        buff_names_en = {
            "paddle_size": f"Paddle Size +{buff_pct}%",
            "gauge_max": f"Max Gauge +{buff_pct}%",
            "item_cooldown": f"Item Cooldown -{buff_pct}%",
            "dash_cost": f"Dash Cost -{buff_pct}%",
            "dash_cooldown": f"Dash Cooldown -{buff_pct}%",
            "move_speed": f"Move Speed +{buff_pct}%",
        }

        # 주사위 숫자 표시 (Phase 4 이후에만)
        if progress > 0.9 or waiting_for_space:
            # 최종 결과 표시 - 주사위 눈 크게 표시
            dice_number_y = results_y - 10

            # 주사위 눈 숫자를 크게 표시 (굵은 폰트)
            try:
                big_font = pygame.freetype.Font(resource_path(font_paths[0]), 36)
            except Exception:
                big_font = None

            if big_font:
                # 주사위 결과 숫자 (크고 눈에 띄게)
                dice_text = f"🎲 {self.roll_face}"
                dice_surf, dice_rect = big_font.render(dice_text, (255, 215, 0))  # 골드색
                dice_rect.centerx = screen_w // 2
                dice_rect.y = dice_number_y
                screen.blit(dice_surf, dice_rect)
            elif small_font:
                result_surf, result_rect = small_font.render(_t("ui.angel_dice_result", "주사위 결과: {0}").format(self.roll_face), (255, 220, 150))
                result_rect.centerx = screen_w // 2
                result_rect.y = dice_number_y
                screen.blit(result_surf, result_rect)

            # 모든 옵션 표시 (선택된 것은 강조)
            all_options = list(ANGEL_BLESSING_OPTIONS)
            options_start_y = results_y + 30
            option_height = 26

            # 강조 애니메이션용 시간 계산
            anim_time = pygame.time.get_ticks() / 1000.0

            if small_font:
                for i, buff in enumerate(all_options):
                    buff_name = buff_names_kr.get(buff, buff)
                    is_selected = buff in self.active_buffs

                    option_y = options_start_y + i * option_height

                    if is_selected:
                        # 선택된 옵션 - 강조 애니메이션
                        # 펄스 효과 (밝기 변화)
                        pulse = 0.7 + 0.3 * math.sin(anim_time * 5 + i * 0.5)

                        # 배경 하이라이트 (깜빡이는 효과)
                        highlight_alpha = int(80 + 40 * math.sin(anim_time * 4 + i))
                        highlight_surf = pygame.Surface((panel_width - 40, option_height), pygame.SRCALPHA)
                        highlight_surf.fill((100, 255, 100, highlight_alpha))
                        screen.blit(highlight_surf, (panel_x + 20, option_y - 2))

                        # 텍스트 색상 (밝은 녹색 펄스)
                        green_val = int(200 + 55 * pulse)
                        buff_color = (120, min(255, green_val), 120)

                        # 선택 마커
                        marker = "★ "
                        buff_surf, buff_rect = small_font.render(f"{marker}{buff_name}", buff_color)

                        # 살짝 좌우 흔들림 효과
                        shake_x = int(math.sin(anim_time * 8 + i) * 2)
                        buff_rect.centerx = screen_w // 2 + shake_x
                        buff_rect.y = option_y
                        screen.blit(buff_surf, buff_rect)
                    else:
                        # 선택되지 않은 옵션 - 어둡게 표시
                        buff_color = (100, 100, 100)  # 회색
                        buff_surf, buff_rect = small_font.render(f"  {buff_name}", buff_color)
                        buff_rect.centerx = screen_w // 2
                        buff_rect.y = option_y
                        screen.blit(buff_surf, buff_rect)

                # 스페이스바 안내 문구 표시
                if waiting_for_space:
                    # 깜빡이는 효과
                    blink = int(128 + 127 * math.sin(anim_time * 3))
                    prompt_surf, prompt_rect = small_font.render(_t("ui.angel_press_space", "스페이스바를 눌러 계속하기"), (255, 255, blink))
                    prompt_rect.centerx = screen_w // 2
                    prompt_rect.y = panel_y + panel_height - 40
                    screen.blit(prompt_surf, prompt_rect)
            else:
                # fallback: pygame.font 사용 (영문)
                try:
                    fallback_small = pygame.font.Font(None, 22)
                    fallback_big = pygame.font.Font(None, 40)

                    # 주사위 결과 숫자
                    result_surf = fallback_big.render(f"Dice: {self.roll_face}", True, (255, 215, 0))
                    result_rect = result_surf.get_rect(centerx=screen_w // 2, y=dice_number_y)
                    screen.blit(result_surf, result_rect)

                    for i, buff in enumerate(all_options):
                        buff_name = buff_names_en.get(buff, buff)
                        is_selected = buff in self.active_buffs
                        option_y = options_start_y + i * option_height

                        if is_selected:
                            # 강조 효과
                            pulse = 0.7 + 0.3 * math.sin(anim_time * 5 + i * 0.5)
                            green_val = int(200 + 55 * pulse)
                            buff_surf = fallback_small.render(f"* {buff_name}", True, (120, min(255, green_val), 120))
                        else:
                            buff_surf = fallback_small.render(f"  {buff_name}", True, (100, 100, 100))

                        buff_rect = buff_surf.get_rect(centerx=screen_w // 2, y=option_y)
                        screen.blit(buff_surf, buff_rect)

                    # 스페이스바 안내 문구 표시 (영문)
                    if waiting_for_space:
                        blink = int(128 + 127 * math.sin(anim_time * 3))
                        prompt_surf = fallback_small.render("Press SPACE to continue", True, (255, 255, blink))
                        prompt_rect = prompt_surf.get_rect(centerx=screen_w // 2, y=panel_y + panel_height - 40)
                        screen.blit(prompt_surf, prompt_rect)
                except Exception:
                    pass
        else:
            # 굴리는 중 - ??? 표시
            if small_font:
                rolling_surf, rolling_rect = small_font.render(_t("ui.angel_rolling", "주사위를 굴리는 중..."), (200, 180, 255))
                rolling_rect.centerx = screen_w // 2
                rolling_rect.y = results_y
                screen.blit(rolling_surf, rolling_rect)
            else:
                try:
                    fallback_small = pygame.font.Font(None, 22)
                    rolling_surf = fallback_small.render("Rolling dice...", True, (200, 180, 255))
                    rolling_rect = rolling_surf.get_rect(centerx=screen_w // 2, y=results_y)
                    screen.blit(rolling_surf, rolling_rect)
                except Exception:
                    pass

        # 빛나는 파티클 효과 (황금색/흰색 계열)
        for _ in range(2):
            particle_angle = random.uniform(0, math.pi * 2)
            particle_dist = random.uniform(50, 100)
            particle_x = dice_center_x + int(math.cos(particle_angle) * particle_dist)
            particle_y = dice_center_y + int(math.sin(particle_angle) * particle_dist)
            particle_color = (255, 230, 150, random.randint(100, 200))
            pygame.draw.circle(screen, particle_color, (particle_x, particle_y), random.randint(1, 3))

        return True  # 애니메이션 진행 중

    def handle_input(self, event) -> bool:
        """스페이스바 입력 처리 - 결과 화면 닫기

        Returns:
            True if the event was handled (animation closed), False otherwise
        """
        if not self.roll_anim_active:
            return False

        if not getattr(self, 'waiting_for_space', False):
            return False

        # 스페이스바 또는 엔터키로 창 닫기
        if event.type == pygame.KEYDOWN and event.key in (pygame.K_SPACE, pygame.K_RETURN):
            self.roll_anim_active = False
            self.waiting_for_space = False
            if self.DEBUG_ENABLED: print(f"[AngelBlessing] 주사위 애니메이션 종료 - applied_stage: {self.applied_stage}")
            return True

        return False

    def update(self, dt: float, ui_mode: bool = False):
        super().update(dt, ui_mode)

        # 스테이지 변경 시 자동 주사위 굴림 (타이머 업데이트보다 먼저 체크)
        current_stage = self._get_current_stage()
        just_rolled = False
        if not ui_mode and current_stage is not None and current_stage != self.applied_stage:
            # 이미 발동된 스테이지면 스킵 (재장착 방지)
            if current_stage not in self._triggered_stages:
                if os.environ.get("PINGF_DEBUG_ANGEL", "0") == "1":
                    print(f"[AngelBlessing][DEBUG] stage change detected: prev={self.applied_stage}, now={current_stage}")
                self._roll_blessing(current_stage)
                just_rolled = True  # 방금 롤했으면 이번 프레임에서는 타이머 업데이트 스킵

        # 주사위 애니메이션 타이머 업데이트 (CRITICAL: 이 로직이 없으면 애니메이션이 진행되지 않음)
        if self.roll_anim_active and not just_rolled:
            # 스페이스바 대기 상태가 아니면 타이머 진행
            if not getattr(self, 'waiting_for_space', False):
                # dt 정규화: 비정상적으로 큰 dt 값 제한 (최대 0.1초 = 100ms)
                normalized_dt = dt if dt < 5 else dt / 1000.0
                normalized_dt = min(normalized_dt, 0.1)  # 최대 100ms로 제한
                self.roll_timer += normalized_dt
                if self.roll_timer >= self.roll_anim_duration:
                    # 타이머가 끝나면 스페이스바 대기 상태로 전환 (바로 닫지 않음)
                    self.waiting_for_space = True
                    if self.DEBUG_ENABLED: print(f"[AngelBlessing] 주사위 결과 표시 - 스페이스바 대기 중...")

        # 8프레임 애니메이션 업데이트
        self.frame_counter += 1
        if self.frame_counter >= self.animation_speed:
            self.frame_counter = 0
            self.current_frame = (self.current_frame + 1) % 8

        self.particle_timer = 0


class EmptyLegendarySlot(LegendaryItem):
    """아이템 관리자에서 사용하는 빈 전설 슬롯"""

    def __init__(self):
        super().__init__(
            name="empty",
            korean_name="empty",
            description="신화 슬롯을 비워두기 위한 플레이스홀더",
            unlock_condition="항상 사용 가능",
        )
        self.unlocked = True
        self.animation_frames: List[pygame.Surface] = []  # type: ignore[name-defined]
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 4  # 헤르메스 아이콘과 동일한 속도로 재생
        self._load_animation_frames()

    def _sync_with_hermes_state(self) -> bool:
        """현재 전설 매니저에 등록된 헤르메스 아이콘 상태를 그대로 복제한다."""
        manager = globals().get("_legendary_manager")
        if not manager or not hasattr(manager, "items"):
            return False

        hermes = manager.items.get("hermes_shoes")
        if not hermes:
            return False

        hermes_frames = getattr(hermes, "animation_frames", None)
        if hermes_frames and len(self.animation_frames) != len(hermes_frames):
            # 헤르메스 프레임 수가 변경되면 재생성한다.
            self._load_animation_frames()

        # 헤르메스의 애니메이션 진행도를 그대로 복제
        self.animation_time = getattr(hermes, "animation_time", self.animation_time)
        self.animation_offset = getattr(hermes, "animation_offset", self.animation_offset)
        self.glow_intensity = getattr(hermes, "glow_intensity", self.glow_intensity)
        self.particle_timer = getattr(hermes, "particle_timer", self.particle_timer)
        self.current_frame = getattr(hermes, "current_frame", self.current_frame)
        self.frame_counter = getattr(hermes, "frame_counter", self.frame_counter)
        self.animation_speed = getattr(hermes, "animation_speed", self.animation_speed)
        return True

    def activate(self, game_state: Dict):
        """빈 슬롯은 활성화되지 않는다."""
        self.active = False

    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """헤르메스 아이콘과 동일한 프레임/속도로 내부 프레임을 그린다."""
        import pygame

        # 헤르메스와 동일: 공통 프레임 호출 파라미터, 코너 스타일/색상 그대로
        frame_offset = _draw_common_legendary_frame(
            screen,
            x,
            y,
            size,
            self.animation_time,
            border_color=COMMON_LEGENDARY_BORDER_COLOR,
            corner_color=COMMON_LEGENDARY_CORNER_COLOR,
        )

        # 헤르메스와 동일: 프레임 카운터 진행 방식
        if self.animation_frames and len(self.animation_frames) > 0:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)

            icon_y = y + frame_offset + int(self.animation_offset)
            current_icon = self.animation_frames[self.current_frame % len(self.animation_frames)]
            scaled_icon = pygame.transform.scale(current_icon, (size, size))
            screen.blit(scaled_icon, (x, icon_y))

        # 파티클 처리도 동일
        if self.particle_timer > 1.0:
            self._spawn_particle(screen, x + size // 2, y + frame_offset + size // 2)
            self.particle_timer = 0

    def update(self, dt: float, ui_mode: bool = False):
        super().update(dt, ui_mode)

        # 헤르메스 아이콘과 완전히 동기화
        synced = self._sync_with_hermes_state()

        if self.animation_frames and len(self.animation_frames) > 1 and not synced:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)

    def _load_animation_frames(self):
        """빈 전설 슬롯은 내부 아이콘을 전혀 그리지 않도록 투명 프레임을 생성한다.

        - 아이템 관리자 전설 탭의 empty 아이콘 내부에 비치던 '헤르메스의 신발' 그림자를 완전히 제거하기 위함.
        - 공통 프레임(_draw_common_legendary_frame)이 배경/테두리/펄스를 그려주므로, 중앙 오버레이는 비워둔다.
        - 헤르메스와 동일한 8개 프레임을 사용하되, 모두 완전 투명한 Surface로 생성한다.
        """
        import pygame

        self.animation_frames.clear()

        # 헤르메스와 동일한 8개 프레임, 모두 완전 투명
        total_frames = 8
        for i in range(total_frames):
            # 60x60 크기의 완전 투명한 Surface 생성
            # 헤르메스 신발 이미지를 로드하지 않음
            transparent = pygame.Surface((60, 60), pygame.SRCALPHA)
            transparent.fill((0, 0, 0, 0))  # 완전 투명
            self.animation_frames.append(transparent)

        pass  # print(f"[INFO] empty 전설 슬롯: 투명 프레임 {total_frames}개 생성 (테두리 효과만 표시)")  # 디버그 비활성화

    def _erase_hermes_shoe(self, surface: pygame.Surface) -> None:
        """헤르메스 프레임에서 신발 본체와 잔상만 제거한다."""
        surface.lock()
        try:
            width, height = surface.get_size()
            for y in range(height):
                for x in range(width):
                    color = surface.get_at((x, y))
                    if color.a == 0:
                        continue

                    r, g, b = color.r, color.g, color.b

                    keep_red_ring = r >= 140 and g <= 65 and b <= 90
                    keep_blue_glow = (
                        b >= 200 and g >= 150
                    ) or (
                        b >= 220
                    )
                    keep_highlight = (
                        r >= 230 and g >= 230 and b >= 230
                    )

                    if not (keep_red_ring or keep_blue_glow or keep_highlight):
                        surface.set_at((x, y), (0, 0, 0, 0))
        finally:
            surface.unlock()


# 전설 빈 슬롯(variant 1) — 포세이돈의 삼지창과 동일 렌더링
class EmptyLegendarySlotPoseidon(LegendaryItem):
    """아이템 관리자 전설 탭에서 empty1 슬롯을 포세이돈 스타일 프레임만 표시.

    - 중앙 삼지창 그림 없이, 공통 프레임 + 붉은 링/코너 하이라이트(오버레이)만 사용
    - 프레임 속도, 그라데이션 감각은 포세이돈과 동일(8프레임)
    """

    def __init__(self):
        super().__init__(
            name="empty1",
            korean_name="empty1",
            description="UI용 빈 슬롯(포세이돈 프레임만 표시)",
            unlock_condition="항상 사용 가능",
        )
        self.unlocked = True
        self.animation_frames: List[pygame.Surface] = []  # 사용 안 함 (중앙 오버레이 없음)
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8  # 펄스 주기 동기화용(미사용 가능)
        self._last_tick: Optional[int] = None

    def activate(self, game_state: Dict):
        # UI용이므로 활성화되지 않음
        self.active = False

    def _load_ring_overlay_frames(self) -> None:
        # 중앙 오버레이를 사용하지 않으므로 noop로 유지
        self.animation_frames.clear()

    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        import pygame
        # 애니메이션 시간 보정(아이템관리자에서 update 주기가 없을 수 있음)
        now = pygame.time.get_ticks()
        if self._last_tick is None:
            self._last_tick = now
        else:
            dt_ms = max(0, now - self._last_tick)
            self._last_tick = now
            self.animation_time += dt_ms / 1000.0

        # 내부 테두리 + 글로우만 그리기(외곽 테두리/코너 장식/오버레이 없음)
        frame_offset = _draw_glow_and_inner_only(screen, x, y, size, self.animation_time)
        # 파티클은 비활성화(빈 슬롯)


class EmptyLegendarySlot2(LegendaryItem):
    """라그나로크 해머 스타일의 빈 전설 슬롯 (해머 그림 제외)"""

    def __init__(self):
        super().__init__(
            name="empty2",
            korean_name="empty2",
            description="라그나로크 해머 스타일의 빈 슬롯",
            unlock_condition="항상 사용 가능",
        )
        self.unlocked = True
        self.animation_frames: List[pygame.Surface] = []  # type: ignore[name-defined]
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8  # 라그나로크 해머와 동일한 속도
        self.hammer_glow_multiplier = 1.8  # 라그나로크 해머와 동일한 글로우
        self._load_animation_frames()

    def activate(self, game_state: Dict):
        """빈 슬롯은 활성화되지 않는다."""
        self.active = False

    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """라그나로크 해머와 동일한 스타일이지만 해머 그림 없이"""
        import pygame
        import math

        # 공통 배경 프레임 연출 (라그나로크 해머와 동일)
        frame_offset = _draw_common_legendary_frame(screen, x, y, size, self.animation_time)

        # 라그나로크 해머 스타일의 은색 모서리가 있는 내부 테두리 추가
        # 은색 그라데이션 모서리 그리기
        corner_size = 6
        silver_colors = [
            (200, 200, 200),  # 밝은 은색
            (160, 160, 160),  # 중간 은색
            (120, 120, 120),  # 어두운 은색
        ]

        # 각 모서리에 은색 그라데이션 사각형 그리기
        corners = [
            (x + 4, y + frame_offset + 4),  # 좌상단
            (x + size - corner_size - 4, y + frame_offset + 4),  # 우상단
            (x + 4, y + frame_offset + size - corner_size - 4),  # 좌하단
            (x + size - corner_size - 4, y + frame_offset + size - corner_size - 4),  # 우하단
        ]

        for corner_x, corner_y in corners:
            # 그라데이션 효과를 위해 여러 레이어 그리기
            for i, color in enumerate(silver_colors):
                offset = i * 1
                pygame.draw.rect(screen, color,
                               (corner_x + offset, corner_y + offset,
                                corner_size - offset * 2, corner_size - offset * 2))

        # 라그나로크 해머 스타일의 번개 효과만 그리기 (해머 그림 제외)
        if self.current_frame in [0, 4]:
            bolt_color = (255, 255, 150)
            pygame.draw.line(screen, bolt_color,
                           (x + size // 4, y + frame_offset - 5),
                           (x + size // 3, y + frame_offset + size // 4), 2)
            pygame.draw.line(screen, bolt_color,
                           (x + size * 3 // 4, y + frame_offset - 5),
                           (x + size * 2 // 3, y + frame_offset + size // 4), 2)

        # 파티클 효과
        if self.particle_timer > 1.0:
            self._spawn_particle(screen, x + size//2, y + frame_offset + size//2)
            self.particle_timer = 0

        # 프레임 카운터 업데이트 (애니메이션용)
        self.frame_counter += 1
        if self.frame_counter >= self.animation_speed:
            self.frame_counter = 0
            self.current_frame = (self.current_frame + 1) % 8  # 8프레임 애니메이션

    def update(self, dt: float, ui_mode: bool = False):
        """애니메이션 업데이트"""
        super().update(dt, ui_mode)

        # 프레임 카운터 업데이트
        self.frame_counter += 1
        if self.frame_counter >= self.animation_speed:
            self.frame_counter = 0
            self.current_frame = (self.current_frame + 1) % 8

    def _load_animation_frames(self):
        """완전 투명한 프레임 생성 (해머 그림 없음)"""
        import pygame
        self.animation_frames.clear()

        # 8개의 완전 투명한 프레임 생성
        for i in range(8):
            transparent = pygame.Surface((60, 60), pygame.SRCALPHA)
            transparent.fill((0, 0, 0, 0))  # 완전 투명
            self.animation_frames.append(transparent)

        pass  # print(f"[INFO] empty2 전설 슬롯: 라그나로크 스타일 빈 프레임 8개 생성 (테두리/글로우만 표시)")  # 디버그 비활성화


class TranscendentCrown(LegendaryItem):
    """초월자의 관 - 머리 부위 전설 아이템

    롤 옵션: 모든 스킬 레벨 +1 ~ +3
    투자한 런타임 스킬(아카데미 스킬)에 보너스 레벨을 부여합니다.
    """

    def __init__(self):
        super().__init__(
            name="transcendent_crown",
            korean_name="초월자의 관",
            description="모든 스킬 레벨 증가 (롤 옵션: +1~+3)",
            unlock_condition="신화 아이템 획득",
            icon_path=None  # 고유 애니메이션만 사용
        )
        self._base_skill_bonus = 2  # 기본 스킬 보너스 (롤 옵션으로 덮어씀)

        # 애니메이션 프레임 설정
        self.animation_frames = []
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8  # 프레임당 틱 수
        self._load_animation_frames()
        self.enhancement_bonus_pct = 0  # 강화 버프 보너스 (장착 시 동기화)

    @property
    def skill_bonus(self) -> int:
        """스킬 레벨 보너스 (롤 옵션 + 연마 배율 + 강화 보너스 적용)

        NOTE: 기본 연마 레벨의 배율만 적용 (순환 의존성 방지)
        예: 연마 Lv.5 (50%) + 초월자의 관 +3 → +3 * 1.5 = +4.5
        강화 보너스가 있으면 추가 적용: +4.5 * 1.33 (강화 100%) = +6
        """
        return int(get_legendary_roll_value("transcendent_crown", "skill_bonus", apply_polish=True, enhancement_bonus_pct=self.enhancement_bonus_pct))

    def activate(self, game_state: Dict):
        """초월자의 관 활성화 - 모든 투자된 스킬에 보너스 레벨 부여"""
        super().activate(game_state)
        import items
        items.transcendent_crown_obtained = True

        # 스킬 보너스 적용 (academy.py의 skill_system에 보너스 적용)
        try:
            import academy
            academy.transcendent_crown_skill_bonus = self.skill_bonus
            if LEGENDARY_DEBUG_ENABLED:
                print(f"초월자의 관 활성화 (academy)! 모든 스킬 레벨 +{self.skill_bonus}")
        except ImportError:
            pass

        # pingfighter.py의 런타임 스킬 보너스도 적용
        try:
            import pingfighter
            pingfighter.transcendent_crown_skill_bonus = self.skill_bonus
            # 기존 투자된 스킬 효과 재계산
            if hasattr(pingfighter, 'recalculate_transcendent_crown_effects'):
                pingfighter.recalculate_transcendent_crown_effects()
            if LEGENDARY_DEBUG_ENABLED:
                print(f"초월자의 관 활성화 (pingfighter)! 런타임 스킬 레벨 +{self.skill_bonus}")
        except ImportError:
            pass

    def deactivate(self):
        """초월자의 관 비활성화 - 보너스 레벨 제거"""
        super().deactivate()
        try:
            import academy
            academy.transcendent_crown_skill_bonus = 0
        except ImportError:
            pass

        # pingfighter.py의 런타임 스킬 보너스도 제거
        try:
            import pingfighter
            pingfighter.transcendent_crown_skill_bonus = 0
            # 스킬 효과 재계산 (보너스 제거 후)
            if hasattr(pingfighter, 'recalculate_transcendent_crown_effects'):
                pingfighter.recalculate_transcendent_crown_effects()
        except ImportError:
            pass

    def _load_animation_frames(self):
        """애니메이션 프레임 로드 (라그나로크 해머 프레임 기반)"""
        import pygame

        self.animation_frames.clear()

        # 라그나로크 해머 프레임을 기반으로 중앙 이미지만 왕관으로 교체
        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                if os.path.exists(frame_path):
                    original = pygame.image.load(frame_path).convert_alpha()
                    # 중앙 망치를 지우고 왕관 그리기
                    frame = self._create_crown_frame(original, i)
                    self.animation_frames.append(frame)
            except Exception:
                pass

        # 프레임 로드 실패시 기본 프레임 생성
        if not self.animation_frames:
            for i in range(8):
                self.animation_frames.append(self._create_default_crown_frame(i))

    def _create_crown_frame(self, base_frame, frame_idx):
        """기존 프레임에서 중앙 망치를 지우고 왕관 그리기"""
        import pygame
        import math

        frame = base_frame.copy()
        width, height = frame.get_size()
        cx, cy = width // 2, height // 2

        # 중앙 영역 전체 지우기 (손잡이 포함 - 테두리만 남김)
        # 라그나로크 해머의 망치 머리 + 손잡이 전체를 지우기 위해 넓은 영역 클리어
        clear_radius = min(width, height) // 2 - 3  # 테두리 3px 남기고 전체 지우기
        for y in range(height):
            for x in range(width):
                dist = math.sqrt((x - cx)**2 + (y - cy)**2)
                if dist < clear_radius:
                    frame.set_at((x, y), (0, 0, 0, 0))

        # 왕관 그리기
        self._draw_crown_on_surface(frame, cx, cy, frame_idx)

        return frame

    def _create_default_crown_frame(self, frame_idx):
        """기본 왕관 프레임 생성"""
        import pygame

        frame = pygame.Surface((32, 32), pygame.SRCALPHA)
        cx, cy = 16, 16

        # 배경 (붉은색 계열 그라데이션)
        border_colors = [(150, 0, 0), (224, 0, 0), (255, 0, 0), (224, 0, 0),
                         (150, 0, 0), (75, 0, 0), (45, 0, 0), (75, 0, 0)]
        pygame.draw.circle(frame, border_colors[frame_idx], (cx, cy), 15, 2)

        # 왕관 그리기
        self._draw_crown_on_surface(frame, cx, cy, frame_idx)

        return frame

    def _draw_crown_on_surface(self, surface, cx, cy, frame_idx):
        """왕관을 surface에 그리기"""
        import pygame
        import math

        # 왕관 색상 (금색 계열, 프레임마다 약간 변화)
        gold_base = [(255, 215, 0), (255, 220, 50), (255, 210, 30), (255, 225, 60),
                     (255, 205, 20), (255, 230, 70), (255, 200, 10), (255, 235, 80)]
        gold_dark = [(205, 175, 0), (215, 180, 30), (200, 170, 20), (220, 185, 40),
                     (195, 165, 10), (225, 190, 50), (190, 160, 0), (230, 195, 60)]
        gold_highlight = [(255, 255, 150), (255, 255, 160), (255, 255, 140), (255, 255, 170),
                          (255, 255, 130), (255, 255, 180), (255, 255, 120), (255, 255, 190)]

        crown_gold = gold_base[frame_idx % 8]
        crown_dark = gold_dark[frame_idx % 8]
        crown_light = gold_highlight[frame_idx % 8]

        # 보석 색상 (붉은 루비)
        ruby_colors = [(220, 30, 50), (240, 40, 60), (255, 50, 70), (230, 35, 55),
                       (210, 25, 45), (250, 45, 65), (200, 20, 40), (245, 42, 62)]
        ruby_color = ruby_colors[frame_idx % 8]
        ruby_highlight = (255, 150, 170)

        # 왕관 베이스 (아래 부분)
        base_rect = pygame.Rect(cx - 8, cy + 2, 16, 5)
        pygame.draw.rect(surface, crown_dark, base_rect)
        pygame.draw.rect(surface, crown_gold, base_rect.inflate(-2, -2))

        # 왕관 포인트 3개 (뾰족한 부분)
        points_left = [(cx - 7, cy + 2), (cx - 6, cy - 4), (cx - 4, cy + 2)]
        points_center = [(cx - 2, cy + 2), (cx, cy - 7), (cx + 2, cy + 2)]
        points_right = [(cx + 4, cy + 2), (cx + 6, cy - 4), (cx + 7, cy + 2)]

        # 왕관 뾰족한 부분 그리기
        pygame.draw.polygon(surface, crown_gold, points_left)
        pygame.draw.polygon(surface, crown_dark, points_left, 1)

        pygame.draw.polygon(surface, crown_gold, points_center)
        pygame.draw.polygon(surface, crown_dark, points_center, 1)

        pygame.draw.polygon(surface, crown_gold, points_right)
        pygame.draw.polygon(surface, crown_dark, points_right, 1)

        # 중앙 큰 보석 (루비)
        pygame.draw.circle(surface, ruby_color, (cx, cy - 2), 3)
        pygame.draw.circle(surface, ruby_highlight, (cx - 1, cy - 3), 1)

        # 좌우 작은 보석
        pygame.draw.circle(surface, ruby_color, (cx - 5, cy), 2)
        pygame.draw.circle(surface, ruby_highlight, (cx - 5, cy - 1), 1)
        pygame.draw.circle(surface, ruby_color, (cx + 5, cy), 2)
        pygame.draw.circle(surface, ruby_highlight, (cx + 5, cy - 1), 1)

        # 왕관 상단 하이라이트
        pygame.draw.line(surface, crown_light, (cx - 1, cy - 5), (cx + 1, cy - 5), 1)
        pygame.draw.line(surface, crown_light, (cx - 5, cy - 2), (cx - 4, cy - 2), 1)
        pygame.draw.line(surface, crown_light, (cx + 4, cy - 2), (cx + 5, cy - 2), 1)

        # 빛나는 효과 (애니메이션)
        sparkle_offset = math.sin(frame_idx * 0.8) * 2
        sparkle_alpha = int(180 + math.sin(frame_idx * 1.2) * 60)
        if frame_idx % 2 == 0:
            pygame.draw.circle(surface, (*crown_light[:3],), (cx, cy - 8 + int(sparkle_offset)), 1)

    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """애니메이션 아이콘 그리기"""
        import pygame
        import math

        # 공통 배경 프레임 연출 (라그나로크 해머와 동일한 붉은색 테두리 + 은색 모서리)
        frame_offset = _draw_common_legendary_frame(screen, x, y, size, self.animation_time)

        # 애니메이션 프레임 그리기
        if self.animation_frames and len(self.animation_frames) > 0:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)

            icon_y = y + frame_offset + int(self.animation_offset)
            current_icon = self.animation_frames[self.current_frame % len(self.animation_frames)]
            scaled_icon = pygame.transform.scale(current_icon, (size, size))
            screen.blit(scaled_icon, (x, icon_y))

            # 신성한 빛 효과 (왕관 위에서 반짝임)
            if self.current_frame in [0, 2, 4, 6]:
                sparkle_color = (255, 255, 200)
                sparkle_y = y + frame_offset - 3 + int(math.sin(self.animation_time * 4) * 2)
                pygame.draw.circle(screen, sparkle_color, (x + size // 2, sparkle_y), 2)
                pygame.draw.circle(screen, (255, 255, 255), (x + size // 2, sparkle_y), 1)
        else:
            # Fallback: 프레임이 없으면 기본 왕관 아이콘 그리기
            icon_y = y + frame_offset + int(self.animation_offset)

            # 간단한 왕관 모양
            crown_gold = (255, 215, 0)
            crown_dark = (205, 175, 0)
            ruby_color = (220, 50, 50)

            cx, cy = x + size // 2, icon_y + size // 2

            # 왕관 베이스
            base_w, base_h = size // 3, size // 8
            base_rect = pygame.Rect(cx - base_w // 2, cy + size // 8, base_w, base_h)
            pygame.draw.rect(screen, crown_gold, base_rect)
            pygame.draw.rect(screen, crown_dark, base_rect, 1)

            # 왕관 포인트 3개
            point_h = size // 4
            points_left = [(cx - base_w // 2, cy + size // 8),
                          (cx - base_w // 4, cy - point_h // 2),
                          (cx - base_w // 4 + size // 10, cy + size // 8)]
            points_center = [(cx - size // 10, cy + size // 8),
                            (cx, cy - point_h),
                            (cx + size // 10, cy + size // 8)]
            points_right = [(cx + base_w // 4 - size // 10, cy + size // 8),
                           (cx + base_w // 4, cy - point_h // 2),
                           (cx + base_w // 2, cy + size // 8)]

            pygame.draw.polygon(screen, crown_gold, points_left)
            pygame.draw.polygon(screen, crown_gold, points_center)
            pygame.draw.polygon(screen, crown_gold, points_right)

            # 중앙 보석
            pygame.draw.circle(screen, ruby_color, (cx, cy - size // 10), size // 12)

        # 파티클 효과
        if self.particle_timer > 1.0:
            self._spawn_particle(screen, x + size // 2, y + frame_offset + size // 2)
            self.particle_timer = 0

    def update(self, dt: float, ui_mode: bool = False):
        """애니메이션 업데이트"""
        super().update(dt, ui_mode)

        # 애니메이션 프레임 카운터 업데이트
        if self.animation_frames and len(self.animation_frames) > 1:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)


class OdinsEye(LegendaryItem):
    """오딘의 눈 - 벨트 부위 전설 아이템

    롤 옵션: 부활 확률 30% ~ 50%
    플레이어가 라운드를 잃을 때(공을 막지 못했을 때), 일정 확률로 패배하지 않고 부활합니다.
    부활 시 3초 동안 어둠의 기운 애니메이션 후 페널티가 적용됩니다:
    - 이동 속도 -50%
    - 대시 토큰 1개 고정
    - 대시 쿨타임 +100%
    페널티 상태에서 다시 공을 막지 못하면 진정한 패배입니다.
    페널티 상태에서 라운드를 승리하면 페널티가 해제됩니다.
    """

    def __init__(self):
        super().__init__(
            name="odins_eye",
            korean_name="오딘의 눈",
            description="라운드 패배 시 부활 (롤 옵션: 확률 30%~50%)",
            unlock_condition="신화 아이템 획득",
            icon_path=None  # 고유 애니메이션만 사용
        )
        self._base_revival_chance = 40  # 기본 부활 확률 (롤 옵션으로 덮어씀)
        self.enhancement_bonus_pct = 0  # 강화 보너스 퍼센트

        # 부활 상태 관리
        self.revival_used = False  # 이번 라운드에서 부활 사용 여부
        self.penalty_active = False  # 페널티 상태 여부
        self.dark_energy_timer = 0  # 어둠의 기운 애니메이션 타이머 (3초)
        self.dark_energy_active = False  # 어둠의 기운 활성화 여부
        self.dark_energy_until_round_end = False  # 라운드 종료까지 어둠의 기운 유지

        # 🎬 부활 애니메이션 상태 (3초 연출) - 악의 에너지 인간 형태
        self.is_revival_animating = False  # 부활 애니메이션 진행 중 여부
        self.revival_anim_timer = 0  # 부활 애니메이션 타이머 (프레임)
        self.revival_anim_phase = 0  # 0: 수집, 1: 형성, 2: 폭발, 3: 완료
        self.revival_anim_player_x = 0  # 애니메이션 위치 X
        self.revival_anim_player_y = 0  # 애니메이션 위치 Y
        self.revival_anim_particles = []  # 수집 파티클
        self.revival_burst_particles = []  # 폭발 파티클
        self.REVIVAL_ANIM_DURATION = 180  # 3초 (60fps 기준)
        self.REVIVAL_GATHER_PHASE = 90  # 1.5초 수집
        self.REVIVAL_FORM_PHASE = 60  # 1초 형성
        self.REVIVAL_BURST_PHASE = 30  # 0.5초 폭발

        # 인간 형태 실루엣 파라미터 (폭발 후에만 보임)
        self.human_silhouette_alpha = 0  # 인간 형태 투명도
        self.human_silhouette_scale = 0  # 인간 형태 스케일 (0~1)
        self.human_eye_glow = 0  # 눈 발광 강도
        self.silhouette_revealed = False  # 폭발 후 실루엣 공개 여부

        # 🌑 어둠의 구체 시스템 (변신 전 캐릭터를 덮는 구체)
        self.dark_sphere_radius = 0  # 어둠 구체 반지름
        self.dark_sphere_max_radius = 80  # 최대 구체 크기
        self.dark_sphere_alpha = 0  # 구체 투명도
        self.dark_sphere_pulse = 0  # 구체 맥동 효과
        self.dark_sphere_particles = []  # 구체 주변 파티클
        self.dark_sphere_inner_glow = 0  # 내부 발광 (폭발 직전)
        self.dark_sphere_cracks = []  # 구체 균열 (폭발 직전)

        # 🎇 드라마틱 변신 완료 폭발 이펙트 시스템
        self.dark_burst_active = False  # 어둠 폭발 활성화 여부
        self.dark_burst_timer = 0  # 폭발 타이머
        self.dark_burst_particles = []  # 폭발 파티클
        self.dark_burst_shockwaves = []  # 충격파 리스트
        self.DARK_BURST_DURATION = 45  # 폭발 이펙트 지속시간 (0.75초)

        # 🌑 땅에서 솟아오르기 애니메이션 (변신 완료 후)
        self.rise_from_ground_active = False
        self.rise_from_ground_timer = 0
        self.RISE_FROM_GROUND_DURATION = 35  # ~0.58초

        # 드라마틱 연출 파라미터
        self.screen_flash_alpha = 0  # 화면 플래시 강도
        self.screen_shake_intensity = 0  # 화면 흔들림 강도
        self.dramatic_zoom = 1.0  # 드라마틱 줌 효과
        self.energy_ring_radius = 0  # 에너지 링 반지름
        self.energy_tendrils = []  # 에너지 촉수 (모이는 효과)

        # 💀 죽음 애니메이션 시스템 (페널티 상태에서 패배 시)
        self.is_death_animating = False  # 죽음 애니메이션 진행 중
        self.death_anim_timer = 0  # 죽음 애니메이션 타이머
        self.death_anim_phase = 0  # 0: 폭발 직전, 1: 폭발, 2: 분해, 3: 완료
        self.death_anim_player_x = 0  # 애니메이션 위치 X
        self.death_anim_player_y = 0  # 애니메이션 위치 Y
        self.DEATH_PREEXPLOSION_PHASE = 120  # 2초 (폭발 직전)
        self.DEATH_EXPLOSION_PHASE = 60  # 1초 (폭발)
        self.DEATH_DISINTEGRATE_PHASE = 90  # 1.5초 (분해)
        self.DEATH_ANIM_DURATION = 270  # 총 4.5초
        self.death_particles = []  # 죽음 파티클
        self.death_shockwaves = []  # 죽음 충격파
        self.death_energy_buildup = 0  # 에너지 축적량 (0~1)
        self.death_cracks = []  # 균열 효과
        self.death_flash_intensity = 0  # 플래시 강도
        self.hide_paddle_after_death = False  # 죽음 후 패들 숨김 (점수 화면용)
        self.death_fragments = []  # 💀 분해 파편 (캐릭터 조각)
        self.death_disintegrate_progress = 0  # 분해 진행도

        # ═══════════════════════════════════════════════════════════════════
        # 👻 오딘 잔상 시스템 (변신 상태에서 이동 시 잔상 생성)
        # ═══════════════════════════════════════════════════════════════════
        self.odin_afterimages = []  # 잔상 리스트
        self.AFTERIMAGE_HOLD_DURATION = 60  # 1초 유지 (60fps)
        self.AFTERIMAGE_FADE_DURATION = 30  # 0.5초 페이드아웃
        self.AFTERIMAGE_HIT_DURATION = 45  # 0.75초 영혼 빠져나감 애니메이션
        self.afterimage_spawn_cooldown = 0  # 잔상 생성 쿨다운
        self.AFTERIMAGE_SPAWN_INTERVAL = 6  # 0.1초마다 잔상 생성
        self.last_afterimage_x = 0  # 마지막 잔상 위치 X
        self.last_afterimage_y = 0  # 마지막 잔상 위치 Y
        self.afterimage_soul_particles = []  # 영혼 파티클 (빠져나가는 효과)
        self.afterimage_hit_cooldown = 0  # 잔상 히트 쿨다운 (연속 히트 방지)

        # 애니메이션 프레임 설정
        self.animation_frames = []
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8  # 프레임당 틱 수
        self._load_animation_frames()

        # 어둠의 기운 파티클
        self.dark_particles = []

        # 👁 어둠 파편 (가시-보스 충돌 시 생성)
        self.dark_fragments = []

        # ═══════════════════════════════════════════════════════════════════
        # 🌑 오딘 대쉬 다이브 시스템 (변신 상태 대쉬 시 땅속 잠수 효과)
        # ═══════════════════════════════════════════════════════════════════
        self.odin_dash_dive_active = False        # 다이브 전체 활성 여부
        self.odin_dash_sink_phase = False         # 가라앉기 페이즈
        self.odin_dash_underground_phase = False  # 지하 이동 페이즈
        self.odin_dash_emerge_phase = False       # 솟아오르기 페이즈
        self.odin_dash_sink_timer = 0             # 가라앉기 타이머
        self.odin_dash_emerge_timer = 0           # 솟아오르기 타이머
        self.ODIN_DASH_SINK_DURATION = 8          # 가라앉기 지속시간 (~0.13초)
        self.ODIN_DASH_EMERGE_DURATION = 12       # 솟아오르기 지속시간 (~0.2초)
        self.odin_dash_sink_x = 0                 # 가라앉기 시작 X
        self.odin_dash_sink_y = 0                 # 가라앉기 시작 Y
        self.odin_dash_trail_positions = []       # 지하 이동 트레일 (어둠 그림자)
        self.odin_dash_trail_spawn_cooldown = 0   # 트레일 생성 쿨다운
        self.ODIN_DASH_TRAIL_INTERVAL = 2         # 2프레임마다 트레일 생성
        self.odin_dash_ground_cracks = []         # 땅 균열 이펙트
        self.odin_dash_burst_particles = []       # 다이브/솟아오르기 파티클
        self.odin_dash_ground_ripples = []        # 땅 파문 이펙트

        # ═══════════════════════════════════════════════════════════════════
        # 어둠의 늪 스킬 시스템
        # ═══════════════════════════════════════════════════════════════════
        self.dark_swamp_enabled = False  # 스킬 활성화 여부 (부활 후)
        self.dark_swamp_cost = 100  # 게이지 소모량
        self.dark_swamp_cooldown = 120  # 2초 쿨타임 (60fps 기준)
        self.dark_swamp_cooldown_timer = 0  # 현재 쿨타임 타이머
        self.dark_swamp_active = False  # 스킬 발동 중
        self.dark_swamp_orb_rect = None  # 스킬 아이콘 rect (툴팁용)

        # 럴커 가시 시스템
        self.lurker_spikes = []  # 활성 가시 리스트
        self.spike_spawn_timer = 0  # 가시 생성 타이머
        self.spike_spawn_interval = 8  # 가시 생성 간격 (프레임) - 느리게
        self.spike_count = 0  # 생성된 가시 개수
        self.max_spikes = 12  # 최대 가시 개수 - 적게, 간격 넓게
        self.spike_start_x = 0  # 시작 X (플레이어)
        self.spike_start_y = 0  # 시작 Y (플레이어)
        self.spike_end_x = 0  # 끝 X (보스)
        self.spike_end_y = 0  # 끝 Y (보스)

        # 가시 시각 효과
        self.spike_wave_active = False  # 가시 물결 활성화
        self.spike_wave_progress = 0.0  # 물결 진행도 (0~1)
        self.spike_smoke_particles = []  # 연기 파티클
        self.spike_fragments = []  # 타격 시 어둠의 파편
        self.spike_sparkle_particles = []  # 가시 주변 스파클 파티클

    @property
    def revival_chance(self) -> float:
        """부활 확률 (롤 옵션 + 연마 스킬 + 강화 보너스 적용, 30%~50%)"""
        return get_legendary_roll_value("odins_eye", "revival_chance", apply_polish=True, enhancement_bonus_pct=self.enhancement_bonus_pct)

    def activate(self, game_state: Dict = None):
        """오딘의 눈 활성화"""
        super().activate(game_state)
        import items
        items.odins_eye_obtained = True

        # 상태 초기화
        self.revival_used = False
        self.penalty_active = False
        self.dark_energy_timer = 0
        self.dark_energy_active = False
        self.dark_particles = []

        if LEGENDARY_DEBUG_ENABLED:
            print(f"👁 오딘의 눈 활성화! 부활 확률: {self.revival_chance:.0f}%")

    def deactivate(self):
        """오딘의 눈 비활성화"""
        super().deactivate()
        self.revival_used = False
        self.penalty_active = False
        self.dark_energy_timer = 0
        self.dark_energy_active = False
        self.dark_particles = []
        # 🌑 오딘 대쉬 다이브 초기화
        self._reset_dash_dive()

    def reset_for_new_round(self):
        """새 라운드 시작 시 부활 상태 리셋 (점수 화면 표시 후 호출됨)"""
        self.revival_used = False
        self.penalty_active = False  # 라운드 종료 시 페널티도 초기화
        # 어둠의 기운 효과 초기화
        self.dark_energy_active = False
        self.dark_energy_until_round_end = False
        self.dark_energy_timer = 0
        self.dark_particles = []
        # 💀 죽음 애니메이션 후 패들 숨김은 유지 (clear_death_hide()로 별도 초기화)
        # hide_paddle_after_death는 여기서 리셋하지 않음!
        self.death_fragments = []
        self.death_disintegrate_progress = 0
        # 👁 오딘의 혼 (가시) 초기화 - 라운드 전환 시 화면에서 제거
        self.lurker_spikes = []
        self.spike_smoke_particles = []
        self.spike_fragments = []
        self.dark_swamp_active = False
        self.spike_count = 0
        self.spike_spawn_timer = 0
        self.spike_wave_active = False
        self.spike_wave_progress = 0.0
        # 솟아오르기 애니메이션 초기화
        self.rise_from_ground_active = False
        self.rise_from_ground_timer = 0
        # 🌑 오딘 대쉬 다이브 초기화
        self._reset_dash_dive()

    def clear_death_hide(self):
        """💀 새 라운드 실제 시작 시 패들 숨김 해제"""
        self.hide_paddle_after_death = False

    # ==================== 🌑 오딘 대쉬 다이브 시스템 ====================

    def _reset_dash_dive(self):
        """대쉬 다이브 상태 완전 초기화"""
        self.odin_dash_dive_active = False
        self.odin_dash_sink_phase = False
        self.odin_dash_underground_phase = False
        self.odin_dash_emerge_phase = False
        self.odin_dash_sink_timer = 0
        self.odin_dash_emerge_timer = 0
        self.odin_dash_trail_positions = []
        self.odin_dash_trail_spawn_cooldown = 0
        self.odin_dash_ground_cracks = []
        self.odin_dash_burst_particles = []
        self.odin_dash_ground_ripples = []

    def start_dash_dive(self, player_x: int, player_y: int):
        """🌑 대쉬 다이브 시작 - 가라앉기 페이즈 개시"""
        if not self.is_transformed():
            return
        # 부활/죽음 애니메이션 중에는 시작 안 함
        if self.rise_from_ground_active or self.is_revival_animating or self.dark_burst_active:
            return
        if getattr(self, 'is_death_animating', False):
            return

        # 연속 대쉬: 이전 다이브가 진행 중이면 emerge 취소하고 새로 시작
        if self.odin_dash_dive_active:
            self.odin_dash_emerge_phase = False
            self.odin_dash_emerge_timer = 0

        self.odin_dash_dive_active = True
        self.odin_dash_sink_phase = True
        self.odin_dash_underground_phase = False
        self.odin_dash_emerge_phase = False
        self.odin_dash_sink_timer = 0
        self.odin_dash_emerge_timer = 0
        self.odin_dash_sink_x = player_x
        self.odin_dash_sink_y = player_y
        self.odin_dash_trail_positions = []
        self.odin_dash_trail_spawn_cooldown = 0

        # 가라앉기 지점에 이펙트 생성
        self._spawn_ground_cracks(player_x, player_y, count=5)
        self._spawn_ground_ripple(player_x, player_y)
        self._spawn_dive_particles(player_x, player_y, direction='down')

    def update_dash_dive(self, player_x: int, player_y: int, rolling_active: bool):
        """🌑 대쉬 다이브 매 프레임 업데이트"""
        if not self.odin_dash_dive_active:
            # 다이브 비활성이어도 잔여 이펙트 업데이트
            self._update_dash_dive_effects()
            return

        # 죽음/부활 애니메이션 시작 시 다이브 즉시 취소
        if getattr(self, 'is_death_animating', False) or self.is_revival_animating:
            self._reset_dash_dive()
            return

        # === 가라앉기 페이즈 ===
        if self.odin_dash_sink_phase:
            self.odin_dash_sink_timer += 1
            if self.odin_dash_sink_timer >= self.ODIN_DASH_SINK_DURATION:
                # 가라앉기 완료 -> 지하 이동 페이즈
                self.odin_dash_sink_phase = False
                self.odin_dash_underground_phase = True

        # === 지하 이동 페이즈 ===
        elif self.odin_dash_underground_phase:
            if rolling_active:
                # 대쉬 진행 중: 트레일 + 잔상 생성 (대쉬 경로를 따라 쭉 펼쳐짐)
                self.odin_dash_trail_spawn_cooldown -= 1
                if self.odin_dash_trail_spawn_cooldown <= 0:
                    self.odin_dash_trail_positions.append({
                        'x': player_x,
                        'y': player_y,
                        'alpha': 200,
                        'timer': 0,
                        'max_timer': 30,  # 0.5초 지속
                    })
                    # 👻 대쉬 경로에 잔상 생성
                    self.odin_afterimages.append({
                        'x': player_x,
                        'y': player_y,
                        'width': 155,
                        'height': 25,
                        'timer': 0,
                        'alpha': 200,
                        'phase': 'hold',
                        'glow_offset': 0,
                        'hit_timer': 0,
                        'dissolve_offset': 0,
                    })
                    self.odin_dash_trail_spawn_cooldown = self.ODIN_DASH_TRAIL_INTERVAL
            else:
                # 대쉬 종료 -> 솟아오르기 페이즈
                self.end_dash_dive(player_x, player_y)

        # === 솟아오르기 페이즈 ===
        elif self.odin_dash_emerge_phase:
            self.odin_dash_emerge_timer += 1
            if self.odin_dash_emerge_timer >= self.ODIN_DASH_EMERGE_DURATION:
                # 솟아오르기 완료 -> 다이브 종료
                self.odin_dash_emerge_phase = False
                self.odin_dash_dive_active = False

        # 이펙트 업데이트 (항상)
        self._update_dash_dive_effects()

    def end_dash_dive(self, player_x: int, player_y: int):
        """🌑 지하 이동 종료 -> 솟아오르기 페이즈 개시"""
        self.odin_dash_sink_phase = False
        self.odin_dash_underground_phase = False
        self.odin_dash_emerge_phase = True
        self.odin_dash_emerge_timer = 0

        # 솟아오르기 지점에 이펙트 생성 (더 화려하게)
        self._spawn_ground_cracks(player_x, player_y, count=8)
        self._spawn_ground_ripple(player_x, player_y)
        self._spawn_dive_particles(player_x, player_y, direction='up')

    def is_dash_diving(self) -> bool:
        """대쉬 다이브 중인지 확인"""
        return self.odin_dash_dive_active

    def should_hide_dark_paddle_for_dive(self) -> bool:
        """대쉬 다이브 중 패들 숨김 여부"""
        if not self.odin_dash_dive_active:
            return False
        # 가라앉기 50% 이후부터 숨김
        if self.odin_dash_sink_phase and self.odin_dash_sink_timer >= self.ODIN_DASH_SINK_DURATION // 2:
            return True
        # 지하 이동 중 항상 숨김
        if self.odin_dash_underground_phase:
            return True
        # 솟아오르기 초반 25% 동안 숨김 (아직 땅 아래)
        if self.odin_dash_emerge_phase and self.odin_dash_emerge_timer < self.ODIN_DASH_EMERGE_DURATION * 0.25:
            return True
        return False

    def get_dash_dive_visual_params(self):
        """대쉬 다이브 시 패들 시각 파라미터 반환

        Returns:
            dict or None: {'offset_y', 'alpha', 'visible'}
        """
        import math

        if not self.odin_dash_dive_active:
            return None

        # 가라앉기 페이즈
        if self.odin_dash_sink_phase:
            p = self.odin_dash_sink_timer / max(1, self.ODIN_DASH_SINK_DURATION)
            ease = p * p  # ease-in (빨려들어가는 느낌)
            return {
                'offset_y': int(120 * ease),
                'alpha': int(255 * max(0, 1.0 - ease * 1.5)),
                'visible': ease < 0.85,
            }

        # 지하 이동 페이즈
        if self.odin_dash_underground_phase:
            return {
                'offset_y': 120,
                'alpha': 0,
                'visible': False,
            }

        # 솟아오르기 페이즈
        if self.odin_dash_emerge_phase:
            p = self.odin_dash_emerge_timer / max(1, self.ODIN_DASH_EMERGE_DURATION)
            ease = 1 - (1 - p) * (1 - p)  # ease-out (힘차게 솟아오름)
            return {
                'offset_y': int(120 * (1 - ease)),
                'alpha': int(255 * min(1.0, p * 2.5)),
                'visible': True,
            }

        return None

    # --- 대쉬 다이브 이펙트 헬퍼 ---

    def _spawn_ground_cracks(self, x: int, y: int, count: int = 5):
        """땅 균열 이펙트 생성"""
        import random, math
        for i in range(count):
            angle = random.uniform(0, math.pi * 2)
            length = random.uniform(15, 45)
            self.odin_dash_ground_cracks.append({
                'x': x, 'y': y,
                'angle': angle,
                'length': length,
                'timer': 0,
                'max_timer': random.randint(20, 40),
                'width': random.randint(1, 3),
            })

    def _spawn_ground_ripple(self, x: int, y: int):
        """원형 파문 이펙트 생성"""
        self.odin_dash_ground_ripples.append({
            'x': x, 'y': y,
            'radius': 5,
            'max_radius': 65,
            'alpha': 220,
            'timer': 0,
            'max_timer': 25,
        })

    def _spawn_dive_particles(self, x: int, y: int, direction: str = 'down'):
        """다이브/솟아오르기 시 파티클 생성"""
        import random, math
        count = 18 if direction == 'up' else 12
        for i in range(count):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 7) if direction == 'up' else random.uniform(1, 4)
            vy_base = -random.uniform(2, 6) if direction == 'up' else random.uniform(1, 3)
            self.odin_dash_burst_particles.append({
                'x': x + random.uniform(-20, 20),
                'y': y + random.uniform(-5, 5),
                'vx': math.cos(angle) * speed,
                'vy': vy_base,
                'size': random.uniform(3, 9),
                'life': random.randint(15, 40),
                'max_life': 40,
                'color': random.choice([
                    (30, 15, 50),   # 어두운 보라
                    (50, 25, 80),   # 중간 보라
                    (20, 10, 35),   # 짙은 보라
                    (40, 20, 65),   # 진보라
                    (60, 30, 90),   # 밝은 보라
                ]),
            })

    def _update_dash_dive_effects(self):
        """모든 다이브 이펙트 업데이트"""
        # 트레일 업데이트
        for trail in self.odin_dash_trail_positions[:]:
            trail['timer'] += 1
            trail['alpha'] = int(200 * (1 - trail['timer'] / max(1, trail['max_timer'])))
            if trail['timer'] >= trail['max_timer'] or trail['alpha'] <= 0:
                self.odin_dash_trail_positions.remove(trail)

        # 균열 업데이트
        for crack in self.odin_dash_ground_cracks[:]:
            crack['timer'] += 1
            if crack['timer'] >= crack['max_timer']:
                self.odin_dash_ground_cracks.remove(crack)

        # 파문 업데이트
        for ripple in self.odin_dash_ground_ripples[:]:
            ripple['timer'] += 1
            progress = ripple['timer'] / max(1, ripple['max_timer'])
            ripple['radius'] = int(5 + (ripple['max_radius'] - 5) * progress)
            ripple['alpha'] = int(220 * (1 - progress))
            if ripple['timer'] >= ripple['max_timer']:
                self.odin_dash_ground_ripples.remove(ripple)

        # 버스트 파티클 업데이트
        for p in self.odin_dash_burst_particles[:]:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['vy'] += 0.12  # 중력
            p['vx'] *= 0.95  # 감속
            p['life'] -= 1
            if p['life'] <= 0:
                self.odin_dash_burst_particles.remove(p)

    def draw_dash_dive_effects(self, screen):
        """🌑 대쉬 다이브 전체 이펙트 그리기"""
        import pygame

        has_effects = (
            self.odin_dash_dive_active or
            self.odin_dash_trail_positions or
            self.odin_dash_ground_cracks or
            self.odin_dash_ground_ripples or
            self.odin_dash_burst_particles
        )
        if not has_effects:
            return

        # 1. 파문 (바닥 레이어)
        self._draw_ground_ripples(screen)
        # 2. 지하 이동 트레일 (그림자)
        self._draw_underground_trail(screen)
        # 3. 균열
        self._draw_ground_cracks(screen)
        # 4. 파티클
        self._draw_dive_particles(screen)

    def _draw_underground_trail(self, screen):
        """지하 이동 트레일 - 타원형 어둠 그림자"""
        import pygame, math
        for trail in self.odin_dash_trail_positions:
            alpha = max(0, min(255, trail['alpha']))
            if alpha <= 0:
                continue
            # 타원형 어둠 그림자 (땅 위에 비치는 형상)
            shadow_w, shadow_h = 60, 24
            shadow_surf = pygame.Surface((shadow_w, shadow_h), pygame.SRCALPHA)
            # 외곽 그림자
            pygame.draw.ellipse(shadow_surf, (25, 12, 40, alpha), (0, 0, shadow_w, shadow_h))
            # 내부 코어 (더 어둡게)
            inner_a = int(alpha * 0.7)
            pygame.draw.ellipse(shadow_surf, (12, 5, 22, inner_a),
                              (12, 5, shadow_w - 24, shadow_h - 10))
            # 가운데 밝은 눈 (작은 보라 빛)
            eye_a = int(alpha * 0.5)
            t = trail['timer'] * 0.3
            eye_pulse = int(3 + math.sin(t) * 2)
            pygame.draw.ellipse(shadow_surf, (80, 40, 120, eye_a),
                              (shadow_w // 2 - eye_pulse, shadow_h // 2 - eye_pulse // 2,
                               eye_pulse * 2, eye_pulse))
            screen.blit(shadow_surf, (trail['x'] - shadow_w // 2, trail['y'] - shadow_h // 2))

    def _draw_ground_cracks(self, screen):
        """땅 균열 이펙트 그리기"""
        import pygame, math
        for crack in self.odin_dash_ground_cracks:
            progress = crack['timer'] / max(1, crack['max_timer'])
            # 균열: 빠르게 나타나고 천천히 사라짐
            if progress < 0.2:
                visible_len = crack['length'] * (progress / 0.2)
                alpha = 220
            else:
                visible_len = crack['length']
                alpha = int(220 * (1 - (progress - 0.2) / 0.8))

            if alpha <= 0 or visible_len <= 0:
                continue

            end_x = crack['x'] + math.cos(crack['angle']) * visible_len
            end_y = crack['y'] + math.sin(crack['angle']) * visible_len * 0.4  # 수평 눌린 형태

            # 균열 선 (보라빛)
            crack_surf = pygame.Surface((abs(int(end_x - crack['x'])) + 10,
                                        abs(int(end_y - crack['y'])) + 10), pygame.SRCALPHA)
            ox = max(0, int(crack['x'] - min(crack['x'], end_x))) + 5
            oy = max(0, int(crack['y'] - min(crack['y'], end_y))) + 5
            ex = max(0, int(end_x - min(crack['x'], end_x))) + 5
            ey = max(0, int(end_y - min(crack['y'], end_y))) + 5

            # 글로우 (넓은 선)
            pygame.draw.line(crack_surf, (60, 30, 90, alpha // 3),
                           (ox, oy), (ex, ey), crack['width'] + 3)
            # 코어 (밝은 선)
            pygame.draw.line(crack_surf, (80, 40, 120, alpha),
                           (ox, oy), (ex, ey), crack['width'])

            screen.blit(crack_surf, (int(min(crack['x'], end_x)) - 5,
                                     int(min(crack['y'], end_y)) - 5))

    def _draw_ground_ripples(self, screen):
        """땅 파문 이펙트 (타원형 파동)"""
        import pygame
        for ripple in self.odin_dash_ground_ripples:
            alpha = max(0, ripple['alpha'])
            if alpha <= 0 or ripple['radius'] <= 0:
                continue
            # 타원형 파문 (위에서 보는 바닥 효과)
            rw = ripple['radius'] * 2
            rh = max(1, ripple['radius'])  # 수평 타원 (높이 절반)
            ripple_surf = pygame.Surface((rw + 4, rh + 4), pygame.SRCALPHA)
            # 외곽 파문
            pygame.draw.ellipse(ripple_surf, (70, 35, 100, alpha),
                              (0, 0, rw + 4, rh + 4), 2)
            # 안쪽 파문 (약하게)
            if rw > 20:
                inner_r = int(rw * 0.6)
                inner_h = max(1, int(rh * 0.6))
                inner_a = int(alpha * 0.5)
                ox = (rw + 4 - inner_r) // 2
                oy = (rh + 4 - inner_h) // 2
                pygame.draw.ellipse(ripple_surf, (50, 25, 75, inner_a),
                                  (ox, oy, inner_r, inner_h), 1)
            screen.blit(ripple_surf,
                       (ripple['x'] - rw // 2 - 2,
                        ripple['y'] - rh // 2 - 2))

    def _draw_dive_particles(self, screen):
        """다이브 버스트 파티클 그리기"""
        import pygame
        for p in self.odin_dash_burst_particles:
            life_ratio = max(0, p['life'] / max(1, p['max_life']))
            alpha = int(255 * life_ratio)
            size = max(1, int(p['size'] * life_ratio))
            if alpha <= 0 or size <= 0:
                continue
            r, g, b = p['color']
            # 글로우
            glow_size = size + 3
            glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (r, g, b, alpha // 4),
                             (glow_size, glow_size), glow_size)
            pygame.draw.circle(glow_surf, (r, g, b, alpha),
                             (glow_size, glow_size), size)
            screen.blit(glow_surf,
                       (int(p['x']) - glow_size, int(p['y']) - glow_size))

    # ==================== 👻 오딘 잔상 시스템 ====================

    def create_afterimage(self, player_x: int, player_y: int, paddle_width: int, paddle_height: int):
        """👻 잔상 생성 (변신 상태에서 이동 시)"""
        # 쿨다운 체크
        if self.afterimage_spawn_cooldown > 0:
            return

        # 너무 가까운 거리면 생성 안 함 (최소 10px 이동)
        dx = abs(player_x - self.last_afterimage_x)
        dy = abs(player_y - self.last_afterimage_y)
        if dx < 10 and dy < 10:
            return

        # 잔상 생성
        self.odin_afterimages.append({
            'x': player_x,
            'y': player_y,
            'width': paddle_width,
            'height': paddle_height,
            'timer': 0,
            'alpha': 200,  # 초기 알파
            'phase': 'hold',  # 'hold' (1초 유지), 'fade' (페이드아웃), 'hit' (영혼 빠져나감)
            'glow_offset': 0,  # 글로우 애니메이션 오프셋
            'hit_timer': 0,  # 히트 애니메이션 타이머
            'dissolve_offset': 0,  # 분해 오프셋 (연기 효과용)
        })

        # 쿨다운 및 위치 갱신
        self.afterimage_spawn_cooldown = self.AFTERIMAGE_SPAWN_INTERVAL
        self.last_afterimage_x = player_x
        self.last_afterimage_y = player_y

        if LEGENDARY_DEBUG_ENABLED:
            print(f"👻 잔상 생성: ({player_x}, {player_y}), 총 {len(self.odin_afterimages)}개")

    def update_afterimages(self):
        """👻 잔상 업데이트 (타이머, 페이드, 히트 애니메이션)"""
        import math
        import random

        # 쿨다운 감소
        if self.afterimage_spawn_cooldown > 0:
            self.afterimage_spawn_cooldown -= 1

        # 히트 쿨다운 감소 (연속 히트 방지)
        if self.afterimage_hit_cooldown > 0:
            self.afterimage_hit_cooldown -= 1

        # 잔상 업데이트
        for afterimage in self.odin_afterimages[:]:
            afterimage['timer'] += 1
            afterimage['glow_offset'] = math.sin(afterimage['timer'] * 0.15) * 5

            # 히트 상태 업데이트 (영혼 빠져나감)
            if afterimage['phase'] == 'hit':
                afterimage['hit_timer'] += 1
                hit_progress = afterimage['hit_timer'] / self.AFTERIMAGE_HIT_DURATION

                # 분해 오프셋 증가 (위로 올라가며 흩어짐)
                afterimage['dissolve_offset'] = hit_progress * 40

                # 알파 감소 (빠르게)
                afterimage['alpha'] = int(200 * (1 - hit_progress * 1.2))

                # 영혼 파티클 생성 (위로 올라가는 연기/영혼)
                if afterimage['hit_timer'] < 30 and random.random() < 0.6:
                    ax, ay = afterimage['x'], afterimage['y'] - 60
                    for _ in range(2):
                        self.afterimage_soul_particles.append({
                            'x': ax + random.uniform(-20, 20),
                            'y': ay + random.uniform(-30, 10) - afterimage['dissolve_offset'],
                            'vx': random.uniform(-1.5, 1.5),
                            'vy': random.uniform(-4, -1.5),  # 위로 올라감
                            'size': random.uniform(4, 12),
                            'life': random.randint(30, 60),
                            'max_life': 60,
                            'type': random.choice(['soul', 'smoke', 'wisp']),
                            'rotation': random.uniform(0, math.pi * 2),
                            'rot_speed': random.uniform(-0.1, 0.1),
                            'alpha': random.randint(150, 220),
                        })

                # 완전히 사라지면 제거
                if afterimage['hit_timer'] >= self.AFTERIMAGE_HIT_DURATION:
                    self.odin_afterimages.remove(afterimage)
                continue

            # 페이즈 전환: 1초 후 페이드 시작
            if afterimage['phase'] == 'hold' and afterimage['timer'] >= self.AFTERIMAGE_HOLD_DURATION:
                afterimage['phase'] = 'fade'

            # 페이드 아웃
            if afterimage['phase'] == 'fade':
                fade_progress = (afterimage['timer'] - self.AFTERIMAGE_HOLD_DURATION) / self.AFTERIMAGE_FADE_DURATION
                afterimage['alpha'] = int(200 * (1 - fade_progress))

                # 완전히 사라지면 제거
                if afterimage['alpha'] <= 0:
                    self.odin_afterimages.remove(afterimage)

        # 영혼 파티클 업데이트
        for particle in self.afterimage_soul_particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['vy'] -= 0.05  # 위로 가속 (부력)
            particle['vx'] *= 0.98  # 감속
            particle['rotation'] += particle['rot_speed']
            particle['life'] -= 1
            particle['alpha'] = int(particle['alpha'] * 0.95)  # 점점 투명해짐

            if particle['life'] <= 0 or particle['alpha'] <= 5:
                self.afterimage_soul_particles.remove(particle)

    def draw_afterimages(self, screen):
        """👻 잔상 그리기 (어둠의 인간 형태 실루엣 + 영혼 파티클)"""
        import pygame
        import math

        # 영혼 파티클 먼저 그리기 (잔상 뒤에)
        self._draw_soul_particles(screen)

        for afterimage in self.odin_afterimages:
            x, y = afterimage['x'], afterimage['y']
            alpha = max(0, min(255, afterimage['alpha']))
            glow = afterimage['glow_offset']
            timer = afterimage['timer']
            phase = afterimage['phase']

            if alpha <= 0:
                continue

            # 히트 상태일 때 분해 효과로 그리기
            if phase == 'hit':
                dissolve = afterimage.get('dissolve_offset', 0)
                hit_timer = afterimage.get('hit_timer', 0)
                self._draw_dissolving_afterimage(screen, x, y - 60, alpha, hit_timer, dissolve)
            else:
                # 일반 잔상 실루엣 그리기 (어둠의 인간 형태)
                self._draw_afterimage_silhouette(screen, x, y - 60, alpha, timer, glow)

    def _draw_afterimage_silhouette(self, screen, cx: int, cy: int, alpha: int, timer: int, glow_offset: float):
        """👻 잔상 실루엣 - 엘드리치 눈 미니 버전 (반투명 촉수 + 작은 눈)"""
        import pygame
        import math

        if alpha <= 0:
            return

        t = timer * 0.08
        s = 0.6  # 잔상은 메인보다 작게

        surf_w, surf_h = 80, 90
        silhouette_surf = pygame.Surface((surf_w, surf_h), pygame.SRCALPHA)
        scx, scy = surf_w // 2, surf_h // 2

        # === 1. 외곽 안개 ===
        for i in range(4):
            fog_angle = t * 0.4 + i * (math.pi / 2)
            fog_dist = 25 + math.sin(t * 2 + i) * 5
            fog_x = scx + math.cos(fog_angle) * fog_dist
            fog_y = scy + math.sin(fog_angle) * fog_dist * 0.6
            fog_alpha = int(alpha * 0.25)
            if fog_alpha > 0:
                pygame.draw.circle(silhouette_surf, (30, 15, 45, fog_alpha),
                                 (int(fog_x), int(fog_y)), 12)

        # === 2. 미니 촉수 (6개) ===
        num_tentacles = 6
        for i in range(num_tentacles):
            base_angle = (i / num_tentacles) * math.pi * 2 + t * 0.3
            wave_offset = math.sin(t * 4 + i) * 0.25

            tentacle_len = 25 + math.sin(t * 2 + i * 0.5) * 5
            segments = 5
            prev_x, prev_y = scx, scy

            for j in range(1, segments + 1):
                progress = j / segments
                dist = progress * tentacle_len * s
                angle = base_angle + wave_offset * progress * 2
                thickness = max(1, int((1 - progress * 0.6) * 4))

                px = scx + math.cos(angle) * dist
                py = scy + math.sin(angle) * dist * 0.7

                seg_alpha = int(alpha * 0.6 * (1 - progress * 0.4))
                pygame.draw.line(silhouette_surf, (35, 18, 50, seg_alpha),
                               (int(prev_x), int(prev_y)), (int(px), int(py)), thickness)
                prev_x, prev_y = px, py

        # === 3. 중앙 코어 ===
        core_r = int(12 * s)
        pygame.draw.circle(silhouette_surf, (20, 10, 30, int(alpha * 0.7)), (scx, scy), core_r)
        pygame.draw.circle(silhouette_surf, (50, 25, 70, int(alpha * 0.5)), (scx, scy), core_r, 1)

        # === 4. 작은 눈 (황금색) ===
        eye_glow_intensity = 0.6 + math.sin(t * 4) * 0.2
        eye_alpha = int(alpha * eye_glow_intensity)

        # 눈 글로우
        for i in range(3):
            glow_r = int((8 - i * 2) * s)
            if glow_r > 0:
                glow_a = int(eye_alpha * 0.5 * (1 - i * 0.25))
                pygame.draw.circle(silhouette_surf, (255, 200, 100, glow_a), (scx, scy), glow_r)

        # 눈 본체
        eye_r = int(5 * s)
        pygame.draw.circle(silhouette_surf, (255, 220, 130, eye_alpha), (scx, scy), eye_r)

        # 눈동자 (세로 슬릿)
        pupil_h = int(4 * s)
        pupil_w = int(2 * s)
        pupil_rect = pygame.Rect(scx - pupil_w // 2, scy - pupil_h // 2, max(1, pupil_w), max(1, pupil_h))
        pygame.draw.ellipse(silhouette_surf, (50, 25, 15, int(eye_alpha * 0.8)), pupil_rect)

        screen.blit(silhouette_surf, (cx - scx, cy - scy))

    def _draw_soul_particles(self, screen):
        """👻 영혼 파티클 그리기 (위로 빠져나가는 연기/영혼)"""
        import pygame
        import math

        for particle in self.afterimage_soul_particles:
            x, y = particle['x'], particle['y']
            size = int(particle['size'] * (particle['life'] / particle['max_life']))
            alpha = max(0, min(255, particle['alpha']))
            p_type = particle['type']

            if size <= 0 or alpha <= 0:
                continue

            p_surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
            p_cx, p_cy = size * 3 // 2, size * 3 // 2

            if p_type == 'soul':
                # 영혼 (밝은 보라/흰색, 글로우)
                pygame.draw.circle(p_surf, (180, 140, 220, alpha // 2), (p_cx, p_cy), size + 4)
                pygame.draw.circle(p_surf, (220, 200, 255, alpha), (p_cx, p_cy), size)
                pygame.draw.circle(p_surf, (255, 255, 255, alpha), (p_cx, p_cy), max(1, size // 2))
            elif p_type == 'smoke':
                # 연기 (어두운 보라, 불규칙한 형태)
                rot = particle['rotation']
                points = []
                num_pts = 6
                for i in range(num_pts):
                    angle = rot + (i / num_pts) * math.pi * 2
                    r = size * (0.6 + math.sin(angle * 3 + particle['life'] * 0.1) * 0.4)
                    points.append((int(p_cx + math.cos(angle) * r), int(p_cy + math.sin(angle) * r)))
                if len(points) >= 3:
                    pygame.draw.polygon(p_surf, (60, 40, 80, alpha), points)
            else:  # wisp
                # 윌오윕 (작고 밝은 점)
                pygame.draw.circle(p_surf, (200, 150, 255, alpha), (p_cx, p_cy), size)
                pygame.draw.circle(p_surf, (255, 220, 255, min(255, alpha + 30)), (p_cx, p_cy), max(1, size // 2))

            screen.blit(p_surf, (int(x - p_cx), int(y - p_cy)))

    def _draw_dissolving_afterimage(self, screen, cx: int, cy: int, alpha: int, hit_timer: int, dissolve_offset: float):
        """👻 분해되는 엘드리치 눈 잔상 (촉수가 흩어지며 눈이 깜빡이다 사라짐)"""
        import pygame
        import math

        if alpha <= 0:
            return

        hit_progress = hit_timer / self.AFTERIMAGE_HIT_DURATION
        t = hit_timer * 0.15

        surf_w, surf_h = 100, 110
        silhouette_surf = pygame.Surface((surf_w, surf_h), pygame.SRCALPHA)
        scx, scy = surf_w // 2, surf_h // 2

        # 흔들림 효과
        shake_x = math.sin(t * 10) * (3 + hit_progress * 10)
        shake_y = -dissolve_offset

        # === 1. 분해되는 촉수 (바깥으로 튕겨나감) ===
        num_tentacles = 6
        for i in range(num_tentacles):
            base_angle = (i / num_tentacles) * math.pi * 2 + t * 0.8
            spread = 1 + hit_progress * 3  # 바깥으로 퍼짐

            tentacle_len = (20 + math.sin(t * 4 + i) * 5) * spread
            segments = 4
            prev_x, prev_y = scx + shake_x, scy + shake_y

            for j in range(1, segments + 1):
                progress = j / segments
                dist = progress * tentacle_len * 0.6
                angle = base_angle + math.sin(t * 6 + i + j) * 0.3 * hit_progress
                thickness = max(1, int((1 - progress * 0.6) * 3 * (1 - hit_progress * 0.5)))

                px = scx + shake_x + math.cos(angle) * dist
                py = scy + shake_y + math.sin(angle) * dist * 0.7 - hit_progress * 15

                seg_alpha = int(alpha * 0.5 * (1 - progress * 0.3) * (1 - hit_progress * 0.7))
                if seg_alpha > 0 and thickness > 0:
                    pygame.draw.line(silhouette_surf, (50, 25, 70, seg_alpha),
                                   (int(prev_x), int(prev_y)), (int(px), int(py)), thickness)
                prev_x, prev_y = px, py

        # === 2. 분해되는 코어 ===
        core_r = int(10 * (1 - hit_progress * 0.6))
        if core_r > 0:
            core_alpha = int(alpha * 0.6 * (1 - hit_progress * 0.5))
            pygame.draw.circle(silhouette_surf, (25, 12, 35, core_alpha),
                             (int(scx + shake_x), int(scy + shake_y)), core_r)

        # === 3. 깜빡이다 사라지는 눈 ===
        flicker = 0.3 + math.sin(t * 15) * 0.7 if hit_progress < 0.8 else (1 - hit_progress) * 5
        eye_alpha = int(alpha * flicker * (1 - hit_progress * 0.8))

        if eye_alpha > 10:
            eye_cx = int(scx + shake_x)
            eye_cy = int(scy + shake_y - hit_progress * 20)

            # 글로우
            for i in range(3):
                glow_r = int((7 - i * 2) * (1 - hit_progress * 0.5))
                if glow_r > 0:
                    glow_a = int(eye_alpha * 0.5 * (1 - i * 0.25))
                    pygame.draw.circle(silhouette_surf, (255, 200, 100, glow_a), (eye_cx, eye_cy), glow_r)

            # 눈 본체
            eye_r = int(4 * (1 - hit_progress * 0.4))
            if eye_r > 0:
                pygame.draw.circle(silhouette_surf, (255, 220, 130, eye_alpha), (eye_cx, eye_cy), eye_r)

        # === 4. 연기 파티클 ===
        for i in range(5):
            p_angle = t * 0.5 + i * (math.pi * 2 / 5)
            p_dist = 15 + hit_progress * 25
            px = scx + shake_x + math.cos(p_angle) * p_dist
            py = scy + shake_y + math.sin(p_angle) * p_dist * 0.5 - hit_progress * 25

            p_alpha = int(alpha * 0.3 * (1 - hit_progress * 0.6))
            p_size = max(1, int(3 - hit_progress * 2))
            if p_alpha > 0:
                pygame.draw.circle(silhouette_surf, (60, 35, 80, p_alpha), (int(px), int(py)), p_size)

        screen.blit(silhouette_surf, (cx - scx, cy - scy))

    def check_afterimage_ball_collision(self, ball_x: float, ball_y: float, ball_radius: int,
                                        ball_vx: float, ball_vy: float) -> tuple:
        """👻 잔상과 공 충돌 체크 - 반사 효과 + 영혼 빠져나감 애니메이션

        Returns:
            (hit, new_vx, new_vy, afterimage_x, afterimage_y)
            hit이 True면 반사 발생, new_vx/vy는 새 속도
        """
        import math
        import random

        # 히트 쿨다운 중이면 충돌 체크 안 함 (한 번에 하나의 잔상만 맞음)
        if self.afterimage_hit_cooldown > 0:
            return (False, ball_vx, ball_vy, 0, 0)

        # 🛡️ 이미 히트 상태인 잔상이 있으면 추가 히트 방지
        hit_count = sum(1 for a in self.odin_afterimages if a['phase'] == 'hit')
        if hit_count > 0:
            return (False, ball_vx, ball_vy, 0, 0)

        # 잔상 리스트 복사본 사용 (충돌 중 리스트 수정 방지)
        for afterimage in list(self.odin_afterimages):
            # 이미 히트 상태인 잔상은 무시
            if afterimage['phase'] == 'hit':
                continue

            ax, ay = afterimage['x'], afterimage['y']
            aw, ah = afterimage['width'], afterimage['height']

            # 잔상 히트박스 (패들과 동일한 크기, 약간 위에 위치)
            hitbox_x = ax - aw // 2
            hitbox_y = ay - 60  # 실루엣 중심 위치
            hitbox_w = aw
            hitbox_h = 50  # 실루엣 높이

            # 공이 잔상 히트박스와 충돌하는지 체크
            # 공의 중심이 히트박스 확장 영역 내에 있는지
            closest_x = max(hitbox_x, min(ball_x, hitbox_x + hitbox_w))
            closest_y = max(hitbox_y, min(ball_y, hitbox_y + hitbox_h))

            dx = ball_x - closest_x
            dy = ball_y - closest_y
            dist = math.sqrt(dx * dx + dy * dy)

            if dist <= ball_radius:
                # 충돌! 패들과 동일한 반사 물리 적용
                # 현재 공 속도 계산
                current_speed = math.hypot(ball_vx, ball_vy)
                if current_speed < 4.0:
                    current_speed = 4.0  # 최소 속도 보장

                # 히트 위치에 따른 각도 계산 (패들과 동일: rel_x * 60도)
                hit_offset = (ball_x - ax) / (aw / 2) if aw > 0 else 0
                hit_offset = max(-1.0, min(1.0, hit_offset))
                angle = hit_offset * (math.pi / 3)  # 최대 ±60도

                # 방향 결정 (위에서 왔으면 위로, 아래에서 왔으면 아래로)
                direction = -1 if ball_vy > 0 else 1

                # 속도 부스트 적용 (잔상은 패들보다 약하게 - 기존 속도 유지 수준)
                speed_boost = random.uniform(1.0, 1.1)
                boosted_speed = min(current_speed * speed_boost, 14.0)  # 최대 속도 제한

                # 방향 벡터 계산 (패들과 동일한 방식)
                # (0, direction)을 angle만큼 회전
                cos_a = math.cos(angle)
                sin_a = math.sin(angle)
                # 회전 행렬: [cos -sin; sin cos] * [0; direction]
                vec_x = -sin_a * direction
                vec_y = cos_a * direction

                # 최종 속도 계산
                new_vx = boosted_speed * vec_x
                new_vy = boosted_speed * vec_y

                if LEGENDARY_DEBUG_ENABLED:
                    print(f"👻 잔상 반사 - 속도:{current_speed:.1f}→{boosted_speed:.1f} 부스트:{speed_boost:.2f}x 각도:{math.degrees(angle):.1f}°")

                # 👻 잔상을 'hit' 상태로 전환 (영혼 빠져나감 애니메이션 시작)
                afterimage['phase'] = 'hit'
                afterimage['hit_timer'] = 0
                afterimage['dissolve_offset'] = 0

                # 🛡️ 히트 쿨다운 설정 (연속 히트 방지 - 히트 애니메이션이 끝날 때까지 다른 잔상 히트 불가)
                self.afterimage_hit_cooldown = self.AFTERIMAGE_HIT_DURATION + 10  # 0.75초 + 여유 시간

                # 💨 초기 영혼 파티클 폭발 생성
                soul_cx, soul_cy = ax, ay - 60
                for _ in range(15):
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(2, 6)
                    self.afterimage_soul_particles.append({
                        'x': soul_cx + random.uniform(-15, 15),
                        'y': soul_cy + random.uniform(-25, 15),
                        'vx': math.cos(angle) * speed * 0.5,
                        'vy': -abs(math.sin(angle) * speed) - 2,  # 무조건 위로
                        'size': random.uniform(5, 14),
                        'life': random.randint(35, 70),
                        'max_life': 70,
                        'type': random.choice(['soul', 'soul', 'smoke', 'wisp']),  # 영혼 비중 높게
                        'rotation': random.uniform(0, math.pi * 2),
                        'rot_speed': random.uniform(-0.15, 0.15),
                        'alpha': random.randint(180, 255),
                    })

                if LEGENDARY_DEBUG_ENABLED:
                    print(f"👻 잔상 반사 + 영혼 빠져나감! 위치=({ax}, {ay})")

                return (True, new_vx, new_vy, ax, ay)

        return (False, ball_vx, ball_vy, 0, 0)

    def clear_afterimages(self):
        """👻 모든 잔상 및 영혼 파티클 제거"""
        self.odin_afterimages = []
        self.afterimage_soul_particles = []
        self.afterimage_spawn_cooldown = 0
        self.afterimage_hit_cooldown = 0
        self.last_afterimage_x = 0
        self.last_afterimage_y = 0

    def reset_for_new_game(self):
        """새 게임 시작 시 완전 초기화"""
        self.active = False
        self.revival_used = False
        self.penalty_active = False
        self.dark_energy_timer = 0
        self.dark_energy_active = False
        self.dark_energy_until_round_end = False
        self.dark_particles = []
        # 부활 애니메이션 초기화
        self.is_revival_animating = False
        self.revival_anim_timer = 0
        self.revival_anim_phase = 0
        self.revival_anim_particles = []
        self.revival_burst_particles = []
        # 인간 실루엣 초기화
        self.human_silhouette_alpha = 0
        self.human_silhouette_scale = 0
        self.human_eye_glow = 0
        self.silhouette_revealed = False
        # 어둠의 구체 초기화
        self.dark_sphere_radius = 0
        self.dark_sphere_alpha = 0
        self.dark_sphere_pulse = 0
        self.dark_sphere_particles = []
        self.dark_sphere_inner_glow = 0
        self.dark_sphere_cracks = []
        # 드라마틱 폭발 이펙트 초기화
        self.dark_burst_active = False
        self.dark_burst_timer = 0
        self.dark_burst_particles = []
        self.dark_burst_shockwaves = []
        self.screen_flash_alpha = 0
        self.screen_shake_intensity = 0
        self.energy_ring_radius = 0
        self.energy_tendrils = []
        # 솟아오르기 애니메이션 초기화
        self.rise_from_ground_active = False
        self.rise_from_ground_timer = 0
        # 🌑 오딘 대쉬 다이브 초기화
        self._reset_dash_dive()
        # 죽음 애니메이션 초기화
        self.is_death_animating = False
        self.death_anim_timer = 0
        self.death_anim_phase = 0
        self.death_particles = []
        self.death_shockwaves = []
        self.death_energy_buildup = 0
        self.death_cracks = []
        self.death_flash_intensity = 0
        # 👻 잔상 시스템 초기화
        self.clear_afterimages()
        # 👁 오딘의 혼 (가시) 시스템 초기화
        self.lurker_spikes = []
        self.spike_smoke_particles = []
        self.spike_fragments = []
        self.dark_swamp_enabled = False
        self.dark_swamp_active = False
        self.dark_swamp_cooldown_timer = 0
        self.spike_count = 0
        self.spike_spawn_timer = 0
        self.spike_wave_active = False
        self.spike_wave_progress = 0.0

    def on_round_win(self):
        """라운드 승리 시 호출 - 페널티 해제"""
        if self.penalty_active:
            self.penalty_active = False
            self.clear_afterimages()  # 👻 잔상도 함께 제거
            if LEGENDARY_DEBUG_ENABLED:
                print("👁 오딘의 눈: 라운드 승리! 페널티 해제!")

    # ==================== 부활 애니메이션 시스템 ====================

    def start_revival_animation(self, player_x: int, player_y: int):
        """부활 애니메이션 시작 (어둠의 구체가 플레이어를 덮고 폭발 후 변신)"""
        self.is_revival_animating = True
        self.revival_anim_timer = 0
        self.revival_anim_phase = 0  # 구체 생성 페이즈
        self.revival_anim_player_x = player_x
        self.revival_anim_player_y = player_y
        self.revival_anim_particles = []
        self.revival_burst_particles = []

        # 🔊 변신 사운드 재생
        try:
            import pygame
            import os
            sound_path = resource_path(os.path.join("sounds", "odinchange.wav"))
            if os.path.exists(sound_path):
                odin_change_sound = pygame.mixer.Sound(sound_path)
                odin_change_sound.set_volume(0.7)
                odin_change_sound.play()
                if LEGENDARY_DEBUG_ENABLED:
                    print("🔊 오딘의 눈: 변신 사운드 재생!")
        except Exception as e:
            if LEGENDARY_DEBUG_ENABLED:
                print(f"🔊 오딘의 눈: 사운드 재생 실패 - {e}")

        # 인간 실루엣 초기화 (폭발 후에만 보임)
        self.human_silhouette_alpha = 0
        self.human_silhouette_scale = 0
        self.human_eye_glow = 0
        self.silhouette_revealed = False  # 아직 공개 안됨

        # 🌑 어둠의 구체 초기화
        self.dark_sphere_radius = 0
        self.dark_sphere_alpha = 0
        self.dark_sphere_pulse = 0
        self.dark_sphere_particles = []
        self.dark_sphere_inner_glow = 0
        self.dark_sphere_cracks = []

        # 부활 상태 설정 (페널티 적용)
        self.revival_used = True
        self.penalty_active = True
        self.dark_energy_active = True
        self.dark_energy_timer = 180  # 3초

        if LEGENDARY_DEBUG_ENABLED:
            print(f"👁 오딘의 눈: 부활 애니메이션 시작! 위치=({player_x}, {player_y})")

    def update_revival_animation(self) -> bool:
        """부활 애니메이션 업데이트 - 어둠의 구체가 캐릭터를 덮고 폭발 후 변신. 완료 시 True 반환."""
        import random
        import math

        if not self.is_revival_animating and not self.dark_burst_active:
            return False

        # 폭발 이펙트 업데이트 (애니메이션 완료 후)
        if self.dark_burst_active:
            return self._update_dark_burst()

        self.revival_anim_timer += 1
        px, py = self.revival_anim_player_x, self.revival_anim_player_y
        sphere_center_y = py - 40  # 구체 중심 (캐릭터 중앙)

        # 🌑 실루엣은 폭발 전까지 숨김! (핵심 변경)
        self.human_silhouette_alpha = 0
        self.human_silhouette_scale = 0
        self.human_eye_glow = 0

        # 페이즈 0: 어둠의 구체 생성 & 성장 (캐릭터를 덮음)
        if self.revival_anim_timer <= self.REVIVAL_GATHER_PHASE:
            self.revival_anim_phase = 0
            progress = self.revival_anim_timer / self.REVIVAL_GATHER_PHASE

            # 🌑 어둠의 구체 성장
            self.dark_sphere_radius = self.dark_sphere_max_radius * progress
            self.dark_sphere_alpha = int(180 + progress * 75)  # 180 → 255
            self.dark_sphere_pulse = math.sin(self.revival_anim_timer * 0.15) * 5

            # 에너지 수집 파티클 생성 (사방에서 구체로 모임)
            if random.random() < 0.7 + progress * 0.3:
                angle = random.uniform(0, math.pi * 2)
                distance = random.uniform(120, 220)
                self.energy_tendrils.append({
                    'x': px + math.cos(angle) * distance,
                    'y': sphere_center_y + math.sin(angle) * distance,
                    'target_x': px + random.uniform(-5, 5),
                    'target_y': sphere_center_y + random.uniform(-5, 5),
                    'speed': random.uniform(4, 8),
                    'size': random.uniform(3, 8),
                    'life': random.randint(40, 80),
                    'color_type': random.choice(['purple', 'dark', 'gold'])
                })

            # 구체 표면 파티클 생성
            if random.random() < 0.4:
                angle = random.uniform(0, math.pi * 2)
                self.dark_sphere_particles.append({
                    'angle': angle,
                    'dist_offset': random.uniform(-5, 5),
                    'size': random.uniform(2, 5),
                    'life': random.randint(20, 40),
                    'speed': random.uniform(0.05, 0.1),
                    'color_type': random.choice(['purple', 'dark'])
                })

            # 에너지 수집 파티클 업데이트
            for tendril in self.energy_tendrils[:]:
                dx = tendril['target_x'] - tendril['x']
                dy = tendril['target_y'] - tendril['y']
                dist = max(1, math.sqrt(dx * dx + dy * dy))
                tendril['x'] += (dx / dist) * tendril['speed']
                tendril['y'] += (dy / dist) * tendril['speed']
                tendril['life'] -= 1
                if tendril['life'] <= 0 or dist < 10:
                    self.energy_tendrils.remove(tendril)

            # 화면 흔들림 (점점 강해짐)
            self.screen_shake_intensity = progress * 3

        # 페이즈 1: 구체 맥동 & 에너지 응축 (점점 불안정해짐)
        elif self.revival_anim_timer <= self.REVIVAL_GATHER_PHASE + self.REVIVAL_FORM_PHASE:
            if self.revival_anim_phase == 0:
                self.revival_anim_phase = 1
                self.energy_tendrils.clear()
                if LEGENDARY_DEBUG_ENABLED:
                    print("👁 오딘의 눈: 어둠의 구체 응축!")

            progress = (self.revival_anim_timer - self.REVIVAL_GATHER_PHASE) / self.REVIVAL_FORM_PHASE

            # 🌑 구체 맥동 강화 (점점 불안정하게)
            pulse_intensity = 1 + progress * 2  # 맥동 강도 증가
            self.dark_sphere_pulse = math.sin(self.revival_anim_timer * 0.2) * 8 * pulse_intensity
            self.dark_sphere_radius = self.dark_sphere_max_radius + self.dark_sphere_pulse
            self.dark_sphere_alpha = 255

            # 내부 발광 (폭발 에너지 축적)
            self.dark_sphere_inner_glow = progress

            # 에너지 링 (구체 주변 회전)
            self.energy_ring_radius = 20 + progress * 15

            # 화면 효과 강화
            self.screen_shake_intensity = 3 + progress * 5
            self.screen_flash_alpha = int(progress * 40)

            # 구체 주변 에너지 파편
            if random.random() < 0.6:
                angle = random.uniform(0, math.pi * 2)
                r = self.dark_sphere_radius + random.uniform(5, 20)
                self.revival_anim_particles.append({
                    'x': px + math.cos(angle) * r,
                    'y': sphere_center_y + math.sin(angle) * r,
                    'vx': math.cos(angle) * random.uniform(0.3, 1),
                    'vy': math.sin(angle) * random.uniform(0.3, 1),
                    'life': random.randint(15, 30),
                    'size': random.uniform(2, 5),
                    'alpha': 200
                })

        # 페이즈 2: 폭발 직전 - 구체 균열 & 빛 누출
        elif self.revival_anim_timer <= self.REVIVAL_ANIM_DURATION:
            if self.revival_anim_phase == 1:
                self.revival_anim_phase = 2
                # 균열 생성
                for _ in range(6):
                    self.dark_sphere_cracks.append({
                        'angle': random.uniform(0, math.pi * 2),
                        'length': random.uniform(0.3, 0.8),
                        'width': random.uniform(2, 4),
                        'glow': random.uniform(0.5, 1.0)
                    })
                if LEGENDARY_DEBUG_ENABLED:
                    print("👁 오딘의 눈: 구체 폭발 직전!")

            progress = (self.revival_anim_timer - self.REVIVAL_GATHER_PHASE - self.REVIVAL_FORM_PHASE) / self.REVIVAL_BURST_PHASE

            # 🌑 구체 급격히 수축 후 팽창 (폭발 준비)
            shrink_expand = 1 - math.sin(progress * math.pi) * 0.3
            self.dark_sphere_radius = self.dark_sphere_max_radius * shrink_expand
            self.dark_sphere_inner_glow = 1 + progress  # 내부 발광 최대
            self.dark_sphere_pulse = math.sin(self.revival_anim_timer * 0.4) * 5

            # 균열에서 빛 누출 강화
            for crack in self.dark_sphere_cracks:
                crack['glow'] = min(2.0, crack['glow'] + 0.05)

            # 화면 전체 밝아짐 (폭발 직전)
            self.screen_flash_alpha = int(40 + progress * 80)
            self.screen_shake_intensity = 7 + progress * 3

            # 에너지 링 축소 (폭발 준비)
            self.energy_ring_radius = 35 * (1 - progress * 0.7)

        # 구체 표면 파티클 업데이트
        for p in self.dark_sphere_particles[:]:
            p['angle'] += p['speed']
            p['life'] -= 1
            if p['life'] <= 0:
                self.dark_sphere_particles.remove(p)

        # 일반 파티클 업데이트
        for p in self.revival_anim_particles[:]:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['life'] -= 1
            p['alpha'] = max(0, p['alpha'] - 6)
            if p['life'] <= 0:
                self.revival_anim_particles.remove(p)

        # 애니메이션 완료 → 어둠 구체 폭발 시작!
        if self.revival_anim_timer >= self.REVIVAL_ANIM_DURATION:
            self.revival_anim_phase = 3
            self.is_revival_animating = False

            # 구체 상태 초기화
            self.dark_sphere_radius = 0
            self.dark_sphere_alpha = 0
            self.dark_sphere_particles = []
            self.dark_sphere_cracks = []

            # 🎇 어둠 폭발 이펙트 시작! (폭발 후 실루엣 공개)
            self._start_dark_burst(px, sphere_center_y)

            if LEGENDARY_DEBUG_ENABLED:
                print("👁 오딘의 눈: 구체 폭발! 변신 공개!")
            return False  # 폭발 완료까지 대기

        return False

    def _start_dark_burst(self, cx: int, cy: int):
        """어둠 폭발 이펙트 시작 - 폭발 후 변신된 캐릭터 공개 + 강력한 파동"""
        import random
        import math

        self.dark_burst_active = True
        self.dark_burst_timer = 0
        self.dark_burst_particles = []
        self.dark_burst_shockwaves = []
        self.screen_flash_alpha = 255  # 초기 플래시 (최대!)
        self.screen_shake_intensity = 20  # 즉시 강한 화면 흔들림

        # 💥 중앙 폭발 플래시 (즉시 나타남) - 매우 밝고 크게!
        self.center_burst_flash = 255  # 중앙 폭발 플래시 강도 (최대)
        self.center_burst_radius = 250  # 즉시 250px 크기로 시작 (더 크게!)

        # 🌟 폭발과 동시에 변신된 캐릭터 공개!
        self.silhouette_revealed = True
        self.human_silhouette_alpha = 255
        self.human_silhouette_scale = 1.0
        self.human_eye_glow = 2.5  # 눈 매우 강하게 발광 (더 강하게)

        # 중심 위치 저장
        self._burst_center_x = cx
        self._burst_center_y = cy

        # 💥 폭발 파티클 대량 생성 (더 많이, 더 빠르게)
        for _ in range(100):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(6, 25)
            self.dark_burst_particles.append({
                'x': cx,
                'y': cy,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'life': random.randint(40, 70),
                'max_life': 70,
                'size': random.uniform(5, 18),
                'type': random.choice(['dark', 'purple', 'gold', 'smoke', 'energy']),
                'rotation': random.uniform(0, math.pi * 2),
                'rot_speed': random.uniform(-0.3, 0.3)
            })

        # 🌊 강력한 메인 파동 (변신 공개와 동시에 즉시 보임!)
        # 💥 즉발 대형 파동 - 처음부터 매우 크게!
        self.dark_burst_shockwaves.append({
            'radius': 200,  # 💥 처음부터 200px! (바로 눈에 띔)
            'max_radius': 550,  # 화면 전체
            'speed': 35,  # 매우 빠름
            'alpha': 255,
            'thickness': 20,  # 더 두껍게
            'delay': 0,
            'color': (220, 140, 255),  # 더 밝은 보라
            'is_main': True
        })

        # 두 번째: 동시 발생 중형 파동
        self.dark_burst_shockwaves.append({
            'radius': 150,  # 즉시 보임
            'max_radius': 480,
            'speed': 30,
            'alpha': 255,
            'thickness': 14,
            'delay': 0,
            'color': (240, 170, 255),  # 더 밝은 보라
            'is_main': True  # 이것도 메인으로
        })

        # 세 번째: 동시 발생 내부 파동
        self.dark_burst_shockwaves.append({
            'radius': 100,  # 시작부터 보임
            'max_radius': 380,
            'speed': 25,
            'alpha': 240,
            'thickness': 10,
            'delay': 0,
            'color': (200, 120, 240),
            'is_main': True  # 이것도 메인으로 (더 밝게)
        })

        # 네 번째: 잔향 파동
        self.dark_burst_shockwaves.append({
            'radius': 0,
            'max_radius': 280,
            'speed': 12,
            'alpha': 160,
            'thickness': 4,
            'delay': 5,
            'color': (100, 50, 150),
            'is_main': False
        })

        # 다섯 번째: 어둠 파동
        self.dark_burst_shockwaves.append({
            'radius': 0,
            'max_radius': 240,
            'speed': 8,
            'alpha': 120,
            'thickness': 3,
            'delay': 10,
            'color': (60, 30, 100),
            'is_main': False
        })

        # 화면 흔들림 강하게
        self.screen_shake_intensity = 15

    def _update_dark_burst(self) -> bool:
        """어둠 폭발 이펙트 업데이트. 완료 시 True 반환."""
        import math

        self.dark_burst_timer += 1

        # 화면 플래시 감소
        self.screen_flash_alpha = max(0, self.screen_flash_alpha - 8)
        self.screen_shake_intensity = max(0, 8 - self.dark_burst_timer * 0.3)

        # 💥 중앙 폭발 플래시 감소 (빠르게 감소)
        if hasattr(self, 'center_burst_flash') and self.center_burst_flash > 0:
            self.center_burst_flash = max(0, self.center_burst_flash - 12)
        if hasattr(self, 'center_burst_radius') and self.center_burst_radius < 400:
            self.center_burst_radius += 20  # 빠르게 확장

        # 🌟 변신 캐릭터 서서히 안정화 (눈 발광 감소, 알파 유지)
        if self.silhouette_revealed:
            # 처음에는 눈이 강하게 빛나다가 점점 안정화
            if self.dark_burst_timer < 20:
                self.human_eye_glow = 1.5 - (self.dark_burst_timer / 20) * 0.5
            else:
                self.human_eye_glow = max(0.8, self.human_eye_glow - 0.01)  # 최소 0.8 유지
            self.human_silhouette_alpha = 255
            self.human_silhouette_scale = 1.0

        # 파티클 업데이트
        for p in self.dark_burst_particles[:]:
            p['x'] += p['vx']
            p['y'] += p['vy']
            p['vx'] *= 0.96  # 감속
            p['vy'] *= 0.96
            p['vy'] += 0.1  # 약간의 중력
            p['rotation'] += p['rot_speed']
            p['life'] -= 1

            if p['life'] <= 0:
                self.dark_burst_particles.remove(p)

        # 충격파 업데이트
        for wave in self.dark_burst_shockwaves[:]:
            if wave['delay'] > 0:
                wave['delay'] -= 1
                continue

            wave['radius'] += wave['speed']
            wave['alpha'] = max(0, wave['alpha'] - 5)

            if wave['radius'] >= wave['max_radius'] or wave['alpha'] <= 0:
                self.dark_burst_shockwaves.remove(wave)

        # 폭발 완료 체크
        if self.dark_burst_timer >= self.DARK_BURST_DURATION and len(self.dark_burst_particles) == 0 and len(self.dark_burst_shockwaves) == 0:
            self.dark_burst_active = False
            self.screen_flash_alpha = 0
            self.screen_shake_intensity = 0
            # 🌑 솟아오르기 애니메이션 시작
            self.rise_from_ground_active = True
            self.rise_from_ground_timer = 0
            if LEGENDARY_DEBUG_ENABLED:
                print("👁 오딘의 눈: 폭발 완료 → 솟아오르기 시작!")
            return True

        return False

    def _draw_horror_atmosphere(self, screen):
        """🎃 호러 분위기 오버레이 - 변신 중 화면 전체에 공포 느낌"""
        import pygame
        import math
        import random

        if not self.is_revival_animating:
            return

        w, h = screen.get_size()
        progress = self.revival_anim_timer / self.REVIVAL_ANIM_DURATION
        t = self.revival_anim_timer * 0.05

        # === 1. 어두운 비네트 효과 (가장자리 어둡게) ===
        vignette_intensity = 0.4 + progress * 0.3  # 점점 강해짐
        vignette_surf = pygame.Surface((w, h), pygame.SRCALPHA)

        # 가장자리에서 중앙으로 그라데이션
        for i in range(8):
            edge_dist = 80 - i * 10
            edge_alpha = int(vignette_intensity * (60 - i * 7))
            if edge_alpha > 0 and edge_dist > 0:
                # 상단
                pygame.draw.rect(vignette_surf, (10, 5, 20, edge_alpha), (0, 0, w, edge_dist))
                # 하단
                pygame.draw.rect(vignette_surf, (10, 5, 20, edge_alpha), (0, h - edge_dist, w, edge_dist))
                # 좌측
                pygame.draw.rect(vignette_surf, (10, 5, 20, edge_alpha), (0, 0, edge_dist, h))
                # 우측
                pygame.draw.rect(vignette_surf, (10, 5, 20, edge_alpha), (w - edge_dist, 0, edge_dist, h))

        screen.blit(vignette_surf, (0, 0))

        # === 2. 어두운 보라/붉은 색조 오버레이 (불안한 느낌) ===
        color_shift_alpha = int(30 + math.sin(t * 2) * 15 + progress * 20)
        # 색상이 미묘하게 변화 (보라 <-> 붉은 보라)
        red_shift = int(20 + math.sin(t * 1.5) * 15)
        color_overlay = pygame.Surface((w, h), pygame.SRCALPHA)
        color_overlay.fill((red_shift, 5, 25, color_shift_alpha))
        screen.blit(color_overlay, (0, 0))

        # === 3. 랜덤 화면 깜빡임 (공포 플리커) ===
        if random.random() < 0.03 + progress * 0.05:  # 점점 빈번해짐
            flicker_alpha = random.randint(20, 60)
            flicker_surf = pygame.Surface((w, h), pygame.SRCALPHA)
            flicker_surf.fill((0, 0, 0, flicker_alpha))
            screen.blit(flicker_surf, (0, 0))

        # === 4. 화면 가장자리에서 스며드는 어둠 촉수 ===
        if self.revival_anim_timer % 8 == 0 and random.random() < 0.4:
            # 촉수 파티클을 energy_tendrils에 추가하지 않고 직접 그림
            pass  # 아래에서 직접 그림

        # 가장자리 촉수 효과
        num_tendrils = 12
        for i in range(num_tendrils):
            tendril_progress = (t + i * 0.5) % 3.0
            if tendril_progress < 2.0:
                # 가장자리 위치 결정 (상하좌우)
                side = i % 4
                pos_along = (i // 4) / 3.0

                if side == 0:  # 상단
                    start_x = int(w * pos_along)
                    start_y = 0
                elif side == 1:  # 하단
                    start_x = int(w * pos_along)
                    start_y = h
                elif side == 2:  # 좌측
                    start_x = 0
                    start_y = int(h * pos_along)
                else:  # 우측
                    start_x = w
                    start_y = int(h * pos_along)

                # 촉수 길이 (화면 안쪽으로)
                tendril_len = int(40 + tendril_progress * 30 + math.sin(t * 3 + i) * 20)
                tendril_alpha = int(100 * (1 - tendril_progress / 2.0) * (0.5 + progress * 0.5))

                if tendril_alpha > 10:
                    # 중앙 방향 계산
                    cx, cy = w // 2, h // 2
                    dx = cx - start_x
                    dy = cy - start_y
                    dist = max(1, math.sqrt(dx * dx + dy * dy))
                    dx, dy = dx / dist, dy / dist

                    # 촉수 그리기 (웨이브 형태)
                    tendril_surf = pygame.Surface((w, h), pygame.SRCALPHA)
                    points = []
                    for j in range(tendril_len // 5):
                        wave_offset = math.sin(t * 4 + j * 0.5 + i) * (8 + j * 0.5)
                        px = start_x + dx * j * 5 + (-dy) * wave_offset
                        py = start_y + dy * j * 5 + dx * wave_offset
                        points.append((int(px), int(py)))

                    if len(points) >= 2:
                        # 촉수 두께 감소
                        for k in range(len(points) - 1):
                            thickness = max(1, 6 - k // 3)
                            seg_alpha = max(0, tendril_alpha - k * 5)
                            if seg_alpha > 0:
                                pygame.draw.line(tendril_surf, (30, 15, 45, seg_alpha),
                                               points[k], points[k + 1], thickness)

                        screen.blit(tendril_surf, (0, 0))

        # === 5. 미세한 화면 왜곡 (불안정한 느낌) ===
        # 구현하기 복잡하므로 대신 미세한 노이즈 오버레이
        if progress > 0.3:
            noise_intensity = int((progress - 0.3) * 15)
            if noise_intensity > 0 and random.random() < 0.3:
                for _ in range(20):
                    nx = random.randint(0, w - 1)
                    ny = random.randint(0, h - 1)
                    ns = random.randint(1, 3)
                    na = random.randint(10, noise_intensity)
                    pygame.draw.rect(screen, (random.randint(20, 40), 10, random.randint(30, 50), na),
                                   (nx, ny, ns, ns))

        # === 6. 맥동하는 어둠 (화면 전체가 숨쉬듯) ===
        pulse = math.sin(t * 2) * 0.5 + 0.5  # 0~1
        pulse_alpha = int(10 + pulse * 15 * progress)
        pulse_surf = pygame.Surface((w, h), pygame.SRCALPHA)
        pulse_surf.fill((15, 5, 25, pulse_alpha))
        screen.blit(pulse_surf, (0, 0))

    def draw_revival_animation(self, screen):
        """부활 애니메이션 그리기 - 드라마틱한 연출 + 어둠 폭발 이펙트"""
        import pygame
        import math

        # 폭발 이펙트 그리기 (애니메이션 완료 후)
        if self.dark_burst_active:
            self._draw_dark_burst(screen)
            return

        if not self.is_revival_animating:
            return

        # === 🎃 호러 분위기 오버레이 (변신 중 전체 화면) ===
        self._draw_horror_atmosphere(screen)

        px, py = self.revival_anim_player_x, self.revival_anim_player_y
        sphere_center_y = py - 40  # 구체 중심
        silhouette_center_y = py - 60  # 실루엣 중심 (폭발 후용)

        # === 0. 🌑 어둠의 구체 그리기 (핵심!) ===
        if self.dark_sphere_radius > 0 and self.dark_sphere_alpha > 0:
            self._draw_dark_sphere(screen, px, sphere_center_y)

        # === 1. 에너지 수집 파티클 (사방에서 모이는 효과) ===
        for tendril in self.energy_tendrils:
            life_ratio = tendril['life'] / 80
            size = int(tendril['size'] * life_ratio)
            alpha = int(200 * life_ratio)

            if size > 0:
                if tendril['color_type'] == 'purple':
                    color = (100, 40, 140, alpha)
                elif tendril['color_type'] == 'gold':
                    color = (200, 150, 50, alpha)
                else:  # dark
                    color = (30, 15, 50, alpha)

                # 꼬리 효과 (라인)
                dx = tendril['target_x'] - tendril['x']
                dy = tendril['target_y'] - tendril['y']
                dist = max(1, math.sqrt(dx * dx + dy * dy))
                if dist > 5:
                    tail_len = min(20, dist * 0.3)
                    tail_x = tendril['x'] - (dx / dist) * tail_len
                    tail_y = tendril['y'] - (dy / dist) * tail_len
                    pygame.draw.line(screen, color[:3],
                                   (int(tendril['x']), int(tendril['y'])),
                                   (int(tail_x), int(tail_y)), max(1, size // 2))

                # 파티클 본체
                surf = pygame.Surface((size * 2 + 4, size * 2 + 4), pygame.SRCALPHA)
                pygame.draw.circle(surf, color, (size + 2, size + 2), size)
                # 글로우 효과
                if tendril['color_type'] == 'gold':
                    pygame.draw.circle(surf, (255, 200, 100, alpha // 3), (size + 2, size + 2), size + 2)
                screen.blit(surf, (int(tendril['x'] - size - 2), int(tendril['y'] - size - 2)))

        # === 2. 에너지 링 (형상 주변 회전) ===
        if self.energy_ring_radius > 0:
            ring_surf = pygame.Surface((200, 200), pygame.SRCALPHA)
            ring_cx, ring_cy = 100, 100

            # 회전하는 에너지 세그먼트
            t = self.revival_anim_timer * 0.15
            for i in range(8):
                angle = (i / 8) * math.pi * 2 + t
                seg_x = ring_cx + math.cos(angle) * self.energy_ring_radius
                seg_y = ring_cy + math.sin(angle) * self.energy_ring_radius * 0.6

                # 세그먼트 글로우
                seg_alpha = int(150 + math.sin(t * 3 + i) * 50)
                pygame.draw.circle(ring_surf, (80, 40, 120, seg_alpha), (int(seg_x), int(seg_y)), 4)
                pygame.draw.circle(ring_surf, (150, 80, 180, seg_alpha // 2), (int(seg_x), int(seg_y)), 6)

            screen.blit(ring_surf, (px - 100, silhouette_center_y - 100))

        # === 3. 작은 어둠 파편 파티클 ===
        for p in self.revival_anim_particles:
            size = int(p['size'] * (p['life'] / 40))
            if size > 0:
                surf = pygame.Surface((size * 2 + 2, size * 2 + 2), pygame.SRCALPHA)
                pygame.draw.circle(surf, (40, 20, 60, p['alpha']), (size + 1, size + 1), size)
                screen.blit(surf, (int(p['x'] - size - 1), int(p['y'] - size - 1)))

        # === 4. 인간 실루엣 (제거됨 - draw_dark_paddle의 rise_from_ground 애니메이션으로 대체) ===
        # 기존 _draw_human_silhouette 호출 제거: 폭발 완료 후 새 캐릭터가 아래에서 솟아오름

        # === 5. 화면 플래시 오버레이 ===
        if self.screen_flash_alpha > 0:
            flash_surf = pygame.Surface(screen.get_size(), pygame.SRCALPHA)
            flash_surf.fill((60, 30, 80, self.screen_flash_alpha))
            screen.blit(flash_surf, (0, 0))

        # === 6. "부활!" 텍스트 (페이즈 2) ===
        if self.revival_anim_phase == 2:
            burst_progress = (self.revival_anim_timer - self.REVIVAL_GATHER_PHASE - self.REVIVAL_FORM_PHASE) / self.REVIVAL_BURST_PHASE
            if burst_progress > 0.3:
                try:
                    font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
                    if os.path.exists(font_path):
                        import pygame.freetype
                        font = pygame.freetype.Font(font_path, 24)
                        text_alpha = int(255 * min(1.0, (burst_progress - 0.3) * 2))
                        # 글로우 효과
                        glow_font = pygame.freetype.Font(font_path, 26)
                        glow_surf, glow_rect = glow_font.render(_t("ui.revival_excl", "부활!"), (120, 60, 140))
                        glow_surf.set_alpha(text_alpha // 2)
                        screen.blit(glow_surf, (px - glow_rect.width // 2, silhouette_center_y - 52))
                        # 본 텍스트
                        text_surf, text_rect = font.render(_t("ui.revival_excl", "부활!"), (200, 120, 180))
                        text_surf.set_alpha(text_alpha)
                        screen.blit(text_surf, (px - text_rect.width // 2, silhouette_center_y - 50))
                except Exception:
                    pass

    def _draw_dark_burst(self, screen):
        """어둠 폭발 이펙트 그리기 + 변신된 캐릭터 공개"""
        import pygame
        import math

        cx = getattr(self, '_burst_center_x', 380)
        cy = getattr(self, '_burst_center_y', 650)
        silhouette_y = cy - 20  # 실루엣 위치 보정

        # === 💥 0. 중앙 폭발 플래시 (가장 먼저! 즉시 눈에 띔) ===
        center_flash = getattr(self, 'center_burst_flash', 0)
        center_radius = getattr(self, 'center_burst_radius', 0)
        if center_flash > 0 and center_radius > 0:
            # 💥 거대한 빛 폭발 (BLEND_RGBA_ADD로 매우 밝게)
            flash_size = int(center_radius * 2 + 100)
            flash_surf = pygame.Surface((flash_size, flash_size), pygame.SRCALPHA)
            flash_cx, flash_cy = flash_size // 2, flash_size // 2

            # 바깥쪽 글로우 (여러 층으로 부드럽게)
            for i in range(8):
                layer_r = int(center_radius - i * 15)
                layer_alpha = max(0, center_flash - i * 25)
                if layer_r > 0 and layer_alpha > 0:
                    # 보라-흰색 그라데이션
                    r = min(255, 180 + i * 10)
                    g = min(255, 120 + i * 15)
                    b = min(255, 220 + i * 5)
                    pygame.draw.circle(flash_surf, (r, g, b, layer_alpha), (flash_cx, flash_cy), layer_r)

            # 중심부 (가장 밝은 흰색)
            core_r = int(center_radius * 0.4)
            if core_r > 0:
                pygame.draw.circle(flash_surf, (255, 255, 255, center_flash), (flash_cx, flash_cy), core_r)

            screen.blit(flash_surf, (cx - flash_cx, cy - flash_cy), special_flags=pygame.BLEND_RGBA_ADD)

        # === 1. 충격파 먼저 그리기 (캐릭터 뒤에) ===
        for wave in self.dark_burst_shockwaves:
            if wave['delay'] > 0:
                continue

            if wave['radius'] > 0 and wave['alpha'] > 0:
                is_main = wave.get('is_main', False)
                radius = int(wave['radius'])

                # 💥 직접 화면에 그리기 (더 밝고 선명하게)
                r, g, b = wave['color']
                thickness = max(2, wave['thickness'])
                alpha = wave['alpha']

                if is_main:
                    # 💥 메인 파동: 매우 밝고 두꺼운 링
                    # 외곽 글로우 (가장 넓은 범위, 희미하게)
                    glow_surf = pygame.Surface((radius * 2 + 100, radius * 2 + 100), pygame.SRCALPHA)
                    glow_cx, glow_cy = radius + 50, radius + 50

                    # 바깥쪽 글로우 (그라데이션)
                    for i in range(8):
                        glow_r = radius + 20 - i * 2
                        glow_alpha = max(0, alpha - i * 25)
                        if glow_r > 0 and glow_alpha > 0:
                            pygame.draw.circle(glow_surf, (min(255, r + 50), min(255, g + 30), min(255, b + 30), glow_alpha),
                                             (glow_cx, glow_cy), glow_r, thickness + 8 - i)

                    # 메인 링 (밝은 흰색/보라)
                    pygame.draw.circle(glow_surf, (255, 220, 255, alpha), (glow_cx, glow_cy), radius, thickness + 4)
                    pygame.draw.circle(glow_surf, (255, 255, 255, min(255, alpha + 20)), (glow_cx, glow_cy), radius, thickness)

                    # 내부 글로우
                    inner_r = radius - 10
                    if inner_r > 0:
                        pygame.draw.circle(glow_surf, (200, 150, 255, alpha // 2), (glow_cx, glow_cy), inner_r, thickness // 2)

                    screen.blit(glow_surf, (cx - glow_cx, cy - glow_cy), special_flags=pygame.BLEND_RGBA_ADD)

                else:
                    # 일반 파동: 단순하지만 밝은 링
                    wave_surf = pygame.Surface((radius * 2 + 40, radius * 2 + 40), pygame.SRCALPHA)
                    wave_cx, wave_cy = radius + 20, radius + 20

                    # 글로우
                    for i in range(3):
                        glow_alpha = max(0, alpha - i * 40)
                        if glow_alpha > 0:
                            pygame.draw.circle(wave_surf, (r, g, b, glow_alpha),
                                             (wave_cx, wave_cy), radius + 5 - i * 2, thickness + 2 - i)

                    # 메인 링
                    pygame.draw.circle(wave_surf, (min(255, r + 60), min(255, g + 40), min(255, b + 40), alpha),
                                     (wave_cx, wave_cy), radius, thickness)

                    screen.blit(wave_surf, (cx - wave_cx, cy - wave_cy))

        # === 0. 변신된 캐릭터 (제거됨 - draw_dark_paddle의 rise_from_ground로 대체) ===
        # 기존 _draw_human_silhouette 호출 제거: 폭발 완료 후 새 캐릭터가 아래에서 솟아오름

        # === 1-1. 파동 가장자리 빛나는 점들 ===
        for wave in self.dark_burst_shockwaves:
            if wave['delay'] > 0:
                continue
            if wave.get('is_main', False) and wave['radius'] > 30 and wave['alpha'] > 50:
                radius = int(wave['radius'])
                num_dots = 24
                for i in range(num_dots):
                    dot_angle = (i / num_dots) * math.pi * 2
                    dot_x = cx + math.cos(dot_angle) * radius
                    dot_y = cy + math.sin(dot_angle) * radius
                    # 밝은 점
                    dot_surf = pygame.Surface((12, 12), pygame.SRCALPHA)
                    pygame.draw.circle(dot_surf, (255, 255, 255, wave['alpha']), (6, 6), 4)
                    pygame.draw.circle(dot_surf, (200, 150, 255, wave['alpha'] // 2), (6, 6), 6)
                    screen.blit(dot_surf, (int(dot_x - 6), int(dot_y - 6)), special_flags=pygame.BLEND_RGBA_ADD)

        # === 2. 폭발 파티클 그리기 ===
        for p in self.dark_burst_particles:
            life_ratio = p['life'] / p['max_life']
            size = int(p['size'] * life_ratio)

            if size <= 0:
                continue

            # 파티클 색상
            if p['type'] == 'purple':
                color = (120, 50, 150, int(220 * life_ratio))
            elif p['type'] == 'gold':
                color = (220, 180, 80, int(220 * life_ratio))
            elif p['type'] == 'smoke':
                color = (40, 30, 50, int(150 * life_ratio))
            elif p['type'] == 'energy':
                # 에너지 파티클 (밝은 보라/흰색)
                color = (200, 150, 255, int(255 * life_ratio))
            else:  # dark
                color = (30, 15, 45, int(200 * life_ratio))

            # 파티클 서피스
            p_size = size * 2 + 4
            p_surf = pygame.Surface((p_size, p_size), pygame.SRCALPHA)
            p_cx, p_cy = p_size // 2, p_size // 2

            if p['type'] == 'smoke':
                # 연기 파티클 (불규칙한 형태)
                points = []
                for i in range(6):
                    angle = (i / 6) * math.pi * 2 + p['rotation']
                    r = size * (0.6 + math.sin(angle * 3) * 0.4)
                    points.append((int(p_cx + math.cos(angle) * r),
                                 int(p_cy + math.sin(angle) * r)))
                if len(points) >= 3:
                    pygame.draw.polygon(p_surf, color, points)
            else:
                # 일반 파티클 (글로우 포함)
                pygame.draw.circle(p_surf, color, (p_cx, p_cy), size)
                # 밝은 중심
                if p['type'] == 'gold':
                    pygame.draw.circle(p_surf, (255, 230, 150, int(180 * life_ratio)),
                                     (p_cx, p_cy), max(1, size // 2))
                elif p['type'] == 'energy':
                    # 에너지 파티클: 밝은 코어 + 외곽 글로우
                    pygame.draw.circle(p_surf, (255, 255, 255, int(220 * life_ratio)),
                                     (p_cx, p_cy), max(1, size // 2))
                    pygame.draw.circle(p_surf, (180, 120, 220, int(100 * life_ratio)),
                                     (p_cx, p_cy), size + 2)

            screen.blit(p_surf, (int(p['x'] - p_cx), int(p['y'] - p_cy)))

        # === 3. 화면 플래시 (매우 밝게) ===
        if self.screen_flash_alpha > 0:
            flash_surf = pygame.Surface(screen.get_size(), pygame.SRCALPHA)
            # 밝은 보라-흰색 플래시 (처음 몇 프레임은 거의 흰색)
            if self.dark_burst_timer < 3:
                # 첫 3프레임: 거의 흰색 플래시
                flash_surf.fill((200, 180, 220, min(255, self.screen_flash_alpha + 50)))
            else:
                flash_surf.fill((100, 60, 140, self.screen_flash_alpha))
            screen.blit(flash_surf, (0, 0))

        # === 4. 중심 글로우 (폭발 직후) ===
        if self.dark_burst_timer < 15:
            glow_intensity = 1 - (self.dark_burst_timer / 15)
            glow_size = int(40 + glow_intensity * 60)
            glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            glow_cx, glow_cy = glow_size, glow_size

            # 다중 글로우 레이어
            for i in range(4):
                layer_r = glow_size - i * 10
                layer_alpha = int(glow_intensity * (150 - i * 30))
                if layer_r > 0 and layer_alpha > 0:
                    pygame.draw.circle(glow_surf, (100, 50, 130, layer_alpha),
                                     (glow_cx, glow_cy), layer_r)

            screen.blit(glow_surf, (int(cx - glow_cx), int(cy - glow_cy)),
                       special_flags=pygame.BLEND_RGBA_ADD)

    def get_screen_shake(self) -> tuple:
        """화면 흔들림 오프셋 반환 (x, y)"""
        import random
        if self.screen_shake_intensity > 0:
            return (
                random.uniform(-self.screen_shake_intensity, self.screen_shake_intensity),
                random.uniform(-self.screen_shake_intensity, self.screen_shake_intensity)
            )
        return (0, 0)

    # ==================== 💀 죽음 애니메이션 시스템 ====================

    def start_death_animation(self, player_x: int, player_y: int):
        """죽음 애니메이션 시작 (페널티 상태에서 패배 시)"""
        self.is_death_animating = True
        self.death_anim_timer = 0
        self.death_anim_phase = 0  # 폭발 직전
        self.death_anim_player_x = player_x
        self.death_anim_player_y = player_y
        self.death_particles = []
        self.death_shockwaves = []
        self.death_cracks = []
        self.death_energy_buildup = 0
        self.death_flash_intensity = 0

        # 🔊 죽음 사운드 재생
        try:
            import pygame
            import os
            sound_path = resource_path(os.path.join("sounds", "odindeath.wav"))
            if os.path.exists(sound_path):
                death_sound = pygame.mixer.Sound(sound_path)
                death_sound.set_volume(0.7)
                death_sound.play()
                if LEGENDARY_DEBUG_ENABLED:
                    print("🔊 오딘의 눈: 죽음 사운드 재생")
        except Exception as e:
            if LEGENDARY_DEBUG_ENABLED:
                print(f"🔊 오딘의 눈: 죽음 사운드 재생 실패 - {e}")

        if LEGENDARY_DEBUG_ENABLED:
            print(f"💀 오딘의 눈: 죽음 애니메이션 시작! 위치=({player_x}, {player_y})")

    def update_death_animation(self) -> bool:
        """죽음 애니메이션 업데이트. 완료 시 True 반환."""
        import random
        import math

        if not self.is_death_animating:
            return False

        self.death_anim_timer += 1
        px, py = self.death_anim_player_x, self.death_anim_player_y
        silhouette_y = py - 60

        # ═══════════════════════════════════════════════════════════════
        # 페이즈 0: 폭발 직전 (2초) - 에너지 축적 + 균열 + 떨림
        # ═══════════════════════════════════════════════════════════════
        if self.death_anim_timer <= self.DEATH_PREEXPLOSION_PHASE:
            self.death_anim_phase = 0
            progress = self.death_anim_timer / self.DEATH_PREEXPLOSION_PHASE

            # 에너지 축적 (점점 빨라짐)
            self.death_energy_buildup = progress ** 1.5

            # 화면 흔들림 (점점 강해짐)
            self.screen_shake_intensity = progress * 8

            # 플래시 효과 (깜빡임)
            flash_freq = 2 + progress * 15  # 점점 빨라지는 깜빡임
            self.death_flash_intensity = int((math.sin(self.death_anim_timer * flash_freq * 0.1) + 1) * 40 * progress)

            # 균열 생성 (점점 늘어남)
            if random.random() < 0.1 + progress * 0.3:
                angle = random.uniform(0, math.pi * 2)
                length = random.uniform(10, 30 + progress * 40)
                self.death_cracks.append({
                    'x': px + random.uniform(-15, 15),
                    'y': silhouette_y + random.uniform(-30, 20),
                    'angle': angle,
                    'length': length,
                    'width': random.randint(1, 3),
                    'alpha': 255,
                    'life': random.randint(30, 60)
                })

            # 에너지 파티클 (몸에서 새어나옴)
            if random.random() < 0.3 + progress * 0.5:
                angle = random.uniform(0, math.pi * 2)
                self.death_particles.append({
                    'x': px + random.uniform(-20, 20),
                    'y': silhouette_y + random.uniform(-40, 30),
                    'vx': math.cos(angle) * random.uniform(0.5, 2),
                    'vy': math.sin(angle) * random.uniform(0.5, 2) - 1,
                    'size': random.uniform(2, 6),
                    'life': random.randint(20, 50),
                    'max_life': 50,
                    'type': random.choice(['dark', 'purple', 'red']),
                    'phase': 0
                })

            # 실루엣 맥동 효과
            pulse = math.sin(self.death_anim_timer * 0.3) * 0.1
            self.human_silhouette_scale = 1.0 + pulse + progress * 0.15
            self.human_silhouette_alpha = 220 + int(progress * 35)
            self.human_eye_glow = 0.5 + progress * 1.5  # 눈이 점점 밝아짐

        # ═══════════════════════════════════════════════════════════════
        # 페이즈 1: 폭발 (1초) - 대폭발 + 충격파
        # ═══════════════════════════════════════════════════════════════
        elif self.death_anim_timer <= self.DEATH_PREEXPLOSION_PHASE + self.DEATH_EXPLOSION_PHASE:
            if self.death_anim_phase == 0:
                self.death_anim_phase = 1
                self._trigger_death_explosion(px, silhouette_y)
                if LEGENDARY_DEBUG_ENABLED:
                    print("💀 오딘의 눈: 폭발!")

            progress = (self.death_anim_timer - self.DEATH_PREEXPLOSION_PHASE) / self.DEATH_EXPLOSION_PHASE

            # 화면 플래시 (폭발 직후 밝아졌다가 감소)
            if progress < 0.2:
                self.death_flash_intensity = int(255 * (1 - progress * 5))
            else:
                self.death_flash_intensity = max(0, int(200 * (1 - progress)))

            # 화면 흔들림 감소
            self.screen_shake_intensity = max(0, 10 * (1 - progress * 0.5))

            # 실루엣이 폭발로 인해 흔들리며 약간 투명해짐
            self.human_silhouette_alpha = max(100, int(255 * (1 - progress * 0.6)))
            self.human_silhouette_scale = 1.15 + progress * 0.15
            self.human_eye_glow = 2.0 - progress * 0.5  # 눈이 매우 밝게

        # ═══════════════════════════════════════════════════════════════
        # 페이즈 2: 분해 (1.5초) - 캐릭터가 완전히 분해되어 파편으로 흩어짐
        # ═══════════════════════════════════════════════════════════════
        elif self.death_anim_timer <= self.DEATH_ANIM_DURATION:
            if self.death_anim_phase == 1:
                self.death_anim_phase = 2
                self._trigger_disintegration(px, silhouette_y)
                if LEGENDARY_DEBUG_ENABLED:
                    print("💀 오딘의 눈: 분해 시작!")

            progress = (self.death_anim_timer - self.DEATH_PREEXPLOSION_PHASE - self.DEATH_EXPLOSION_PHASE) / self.DEATH_DISINTEGRATE_PHASE
            self.death_disintegrate_progress = progress

            # 화면 흔들림 유지 후 감소
            self.screen_shake_intensity = max(0, 5 * (1 - progress))

            # 플래시 완전히 사라짐
            self.death_flash_intensity = max(0, int(50 * (1 - progress * 2)))

            # 실루엣 완전히 사라짐 (분해되면서)
            self.human_silhouette_alpha = max(0, int(100 * (1 - progress * 1.5)))
            self.human_silhouette_scale = 1.3 + progress * 0.5  # 확대되며 사라짐
            self.human_eye_glow = max(0, 1.5 * (1 - progress))

            # 지속적으로 파편 생성 (분해 효과)
            if progress < 0.8 and random.random() < 0.6:
                for _ in range(3):
                    angle = random.uniform(0, math.pi * 2)
                    speed = random.uniform(3, 12)
                    self.death_fragments.append({
                        'x': px + random.uniform(-25, 25),
                        'y': silhouette_y + random.uniform(-40, 30),
                        'vx': math.cos(angle) * speed,
                        'vy': math.sin(angle) * speed - 2,
                        'size': random.uniform(4, 14),
                        'life': random.randint(50, 90),
                        'max_life': 90,
                        'rotation': random.uniform(0, math.pi * 2),
                        'rot_speed': random.uniform(-0.15, 0.15),
                        'type': random.choice(['body', 'dark', 'purple', 'eye']),
                        'trail': []  # 잔상 효과용
                    })

        # 파티클 업데이트
        for p in self.death_particles[:]:
            p['x'] += p['vx']
            p['y'] += p['vy']
            if p['phase'] == 1:  # 폭발 파티클
                p['vx'] *= 0.97
                p['vy'] *= 0.97
                p['vy'] += 0.05
            p['life'] -= 1
            if p['life'] <= 0:
                self.death_particles.remove(p)

        # 💀 파편 업데이트 (분해된 캐릭터 조각)
        for frag in self.death_fragments[:]:
            # 잔상 기록
            if len(frag['trail']) < 5:
                frag['trail'].append({'x': frag['x'], 'y': frag['y'], 'alpha': 150})
            else:
                frag['trail'].pop(0)
                frag['trail'].append({'x': frag['x'], 'y': frag['y'], 'alpha': 150})

            # 잔상 페이드 아웃
            for trail in frag['trail']:
                trail['alpha'] = max(0, trail['alpha'] - 25)

            frag['x'] += frag['vx']
            frag['y'] += frag['vy']
            frag['vx'] *= 0.98
            frag['vy'] *= 0.98
            frag['vy'] += 0.15  # 중력
            frag['rotation'] += frag['rot_speed']
            frag['life'] -= 1

            if frag['life'] <= 0:
                self.death_fragments.remove(frag)

        # 균열 업데이트
        for crack in self.death_cracks[:]:
            crack['life'] -= 1
            if crack['life'] <= 0:
                self.death_cracks.remove(crack)
            else:
                crack['alpha'] = int(255 * (crack['life'] / 60))

        # 충격파 업데이트
        for wave in self.death_shockwaves[:]:
            wave['radius'] += wave['speed']
            wave['alpha'] = max(0, wave['alpha'] - 4)
            if wave['radius'] >= wave['max_radius'] or wave['alpha'] <= 0:
                self.death_shockwaves.remove(wave)

        # 애니메이션 완료
        if self.death_anim_timer >= self.DEATH_ANIM_DURATION:
            self.death_anim_phase = 3  # 완료 상태
            self.is_death_animating = False
            self.screen_shake_intensity = 0
            self.death_flash_intensity = 0
            self.human_silhouette_alpha = 0
            self.human_silhouette_scale = 0
            self.human_eye_glow = 0
            # 💀 점수 화면에서 패들 숨김 유지
            self.hide_paddle_after_death = True

            if LEGENDARY_DEBUG_ENABLED:
                print("💀 오딘의 눈: 죽음 애니메이션 완료! 패들 숨김 활성화")
            return True

        return False

    def _trigger_death_explosion(self, cx: int, cy: int):
        """죽음 폭발 이펙트 생성"""
        import random
        import math

        # 대량의 폭발 파티클
        for _ in range(80):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(5, 20)
            self.death_particles.append({
                'x': cx,
                'y': cy,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'size': random.uniform(5, 15),
                'life': random.randint(40, 70),
                'max_life': 70,
                'type': random.choice(['dark', 'purple', 'red', 'smoke', 'flame']),
                'phase': 1,
                'rotation': random.uniform(0, math.pi * 2),
                'rot_speed': random.uniform(-0.2, 0.2)
            })

        # 다중 충격파
        for i in range(4):
            self.death_shockwaves.append({
                'x': cx,
                'y': cy,
                'radius': 0,
                'max_radius': 180 + i * 40,
                'speed': 10 - i * 1.5,
                'alpha': 220 - i * 30,
                'thickness': 5 - i,
                'color': (120 - i * 20, 40 - i * 10, 80 - i * 15) if i < 2 else (60, 20, 40)
            })

    def _trigger_disintegration(self, cx: int, cy: int):
        """💀 분해 이펙트 시작 - 캐릭터가 파편으로 분해됨"""
        import random
        import math

        # 💀 캐릭터 몸체 파편 (큰 조각들)
        body_parts = [
            ('head', 0, -35, 12),      # 머리
            ('torso', 0, -15, 15),     # 몸통
            ('arm_l', -15, -20, 8),    # 왼팔
            ('arm_r', 15, -20, 8),     # 오른팔
            ('leg_l', -8, 5, 10),      # 왼다리
            ('leg_r', 8, 5, 10),       # 오른다리
            ('eye_l', -6, -38, 5),     # 왼눈
            ('eye_r', 6, -38, 5),      # 오른눈
        ]

        for part_name, ox, oy, size in body_parts:
            # 사방으로 튀어나가는 각도
            angle = math.atan2(oy, ox) + random.uniform(-0.5, 0.5) if (ox != 0 or oy != 0) else random.uniform(0, math.pi * 2)
            speed = random.uniform(6, 14)

            frag_type = 'eye' if 'eye' in part_name else 'body'

            self.death_fragments.append({
                'x': cx + ox,
                'y': cy + oy,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - random.uniform(2, 5),  # 위로 튀어오름
                'size': size + random.uniform(-2, 4),
                'life': random.randint(70, 110),
                'max_life': 110,
                'rotation': random.uniform(0, math.pi * 2),
                'rot_speed': random.uniform(-0.2, 0.2),
                'type': frag_type,
                'trail': [],
                'is_main': True  # 주요 파편
            })

        # 💀 작은 어둠 파편들 (대량 생성)
        for _ in range(50):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(4, 18)
            self.death_fragments.append({
                'x': cx + random.uniform(-20, 20),
                'y': cy + random.uniform(-35, 10),
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - random.uniform(1, 4),
                'size': random.uniform(3, 10),
                'life': random.randint(50, 90),
                'max_life': 90,
                'rotation': random.uniform(0, math.pi * 2),
                'rot_speed': random.uniform(-0.25, 0.25),
                'type': random.choice(['dark', 'purple', 'smoke']),
                'trail': [],
                'is_main': False
            })

        # 💀 추가 충격파 (분해용)
        self.death_shockwaves.append({
            'x': cx,
            'y': cy,
            'radius': 0,
            'max_radius': 120,
            'speed': 8,
            'alpha': 180,
            'thickness': 3,
            'color': (80, 30, 60)
        })

    def draw_death_animation(self, screen):
        """죽음 애니메이션 그리기"""
        import pygame
        import math
        import random

        if not self.is_death_animating:
            return

        px, py = self.death_anim_player_x, self.death_anim_player_y
        silhouette_y = py - 60

        # === 1. 충격파 그리기 (뒤에서) ===
        for wave in self.death_shockwaves:
            if wave['radius'] > 0 and wave['alpha'] > 0:
                wave_size = int(wave['radius'] * 2) + 20
                wave_surf = pygame.Surface((wave_size, wave_size), pygame.SRCALPHA)
                wave_cx, wave_cy = wave_size // 2, wave_size // 2

                r, g, b = wave['color']
                thickness = max(1, wave['thickness'])

                # 충격파 링
                for j in range(3):
                    glow_alpha = max(0, wave['alpha'] // (j + 2))
                    glow_r = int(wave['radius']) + j * 3
                    if glow_r > 0:
                        pygame.draw.circle(wave_surf, (r, g, b, glow_alpha),
                                         (wave_cx, wave_cy), glow_r, thickness + j)

                screen.blit(wave_surf, (int(wave['x'] - wave_cx), int(wave['y'] - wave_cy)))

        # === 2. 균열 효과 그리기 ===
        for crack in self.death_cracks:
            if crack['alpha'] > 0:
                end_x = crack['x'] + math.cos(crack['angle']) * crack['length']
                end_y = crack['y'] + math.sin(crack['angle']) * crack['length']

                # 균열 글로우
                pygame.draw.line(screen, (150, 50, 80, crack['alpha'] // 2),
                               (int(crack['x']), int(crack['y'])),
                               (int(end_x), int(end_y)), crack['width'] + 2)
                # 균열 본체
                pygame.draw.line(screen, (200, 100, 120),
                               (int(crack['x']), int(crack['y'])),
                               (int(end_x), int(end_y)), crack['width'])

        # === 3. 에너지 오라 (폭발 직전 페이즈) ===
        if self.death_anim_phase == 0 and self.death_energy_buildup > 0:
            aura_size = int(60 + self.death_energy_buildup * 40)
            aura_surf = pygame.Surface((aura_size * 2, aura_size * 2), pygame.SRCALPHA)
            aura_cx, aura_cy = aura_size, aura_size

            # 맥동하는 오라
            pulse = math.sin(self.death_anim_timer * 0.4) * 0.2 + 1
            for i in range(4):
                r = int((aura_size - i * 10) * pulse)
                alpha = int(self.death_energy_buildup * (80 - i * 15))
                if r > 0 and alpha > 0:
                    # 붉은/보라 그라데이션
                    color = (100 + i * 20, 30, 60 + i * 15, alpha)
                    pygame.draw.circle(aura_surf, color, (aura_cx, aura_cy), r)

            screen.blit(aura_surf, (int(px - aura_cx), int(silhouette_y - aura_cy)))

        # === 4. 어둠의 인간 실루엣 ===
        if self.human_silhouette_alpha > 0:
            self._draw_death_silhouette(screen, px, silhouette_y)

        # === 5. 파티클 그리기 ===
        for p in self.death_particles:
            life_ratio = p['life'] / p['max_life']
            size = int(p['size'] * life_ratio)

            if size <= 0:
                continue

            # 색상 선택
            if p['type'] == 'purple':
                color = (140, 60, 160, int(220 * life_ratio))
            elif p['type'] == 'red':
                color = (180, 50, 70, int(220 * life_ratio))
            elif p['type'] == 'smoke':
                color = (50, 35, 55, int(150 * life_ratio))
            elif p['type'] == 'flame':
                color = (200, 100, 50, int(200 * life_ratio))
            else:  # dark
                color = (40, 20, 50, int(200 * life_ratio))

            p_surf = pygame.Surface((size * 2 + 4, size * 2 + 4), pygame.SRCALPHA)
            p_cx, p_cy = size + 2, size + 2

            if p['type'] == 'flame':
                # 불꽃 형태
                points = [
                    (p_cx, p_cy - size),
                    (p_cx - size * 0.6, p_cy + size * 0.4),
                    (p_cx, p_cy),
                    (p_cx + size * 0.6, p_cy + size * 0.4)
                ]
                pygame.draw.polygon(p_surf, color, [(int(x), int(y)) for x, y in points])
            else:
                pygame.draw.circle(p_surf, color, (p_cx, p_cy), size)

            screen.blit(p_surf, (int(p['x'] - p_cx), int(p['y'] - p_cy)))

        # === 5.5. 💀 분해 파편 그리기 ===
        for frag in self.death_fragments:
            life_ratio = frag['life'] / frag['max_life']
            size = int(frag['size'] * (0.3 + life_ratio * 0.7))

            if size <= 0:
                continue

            # 잔상 그리기
            for trail in frag.get('trail', []):
                if trail['alpha'] > 10:
                    trail_size = max(1, int(size * 0.6))
                    trail_surf = pygame.Surface((trail_size * 2 + 2, trail_size * 2 + 2), pygame.SRCALPHA)
                    pygame.draw.circle(trail_surf, (40, 20, 50, trail['alpha'] // 3),
                                      (trail_size + 1, trail_size + 1), trail_size)
                    screen.blit(trail_surf, (int(trail['x'] - trail_size - 1), int(trail['y'] - trail_size - 1)))

            # 파편 색상
            frag_type = frag.get('type', 'dark')
            is_main = frag.get('is_main', False)

            if frag_type == 'eye':
                # 눈 파편 - 빨간색 발광
                glow_alpha = int(200 * life_ratio)
                color = (200, 60, 80, int(255 * life_ratio))
                glow_color = (255, 100, 120, glow_alpha // 2)
            elif frag_type == 'body':
                # 몸체 파편 - 어두운 보라
                color = (35, 18, 45, int(240 * life_ratio))
                glow_color = (80, 40, 70, int(100 * life_ratio))
            elif frag_type == 'purple':
                color = (100, 40, 120, int(220 * life_ratio))
                glow_color = (140, 60, 160, int(80 * life_ratio))
            elif frag_type == 'smoke':
                color = (45, 30, 50, int(150 * life_ratio))
                glow_color = None
            else:  # dark
                color = (30, 15, 40, int(200 * life_ratio))
                glow_color = (60, 30, 70, int(60 * life_ratio))

            frag_surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
            frag_cx, frag_cy = size * 3 // 2, size * 3 // 2

            # 글로우 효과 (큰 파편만)
            if glow_color and is_main:
                pygame.draw.circle(frag_surf, glow_color, (frag_cx, frag_cy), size + 4)

            # 파편 본체 (불규칙한 형태)
            if is_main and frag_type in ['body', 'eye']:
                # 불규칙한 다각형 형태
                import math as m
                rot = frag['rotation']
                points = []
                num_points = 6
                for i in range(num_points):
                    angle = rot + (i / num_points) * m.pi * 2
                    r = size * (0.7 + random.uniform(0, 0.3) if random.random() > 0.7 else 1.0)
                    px_pt = frag_cx + m.cos(angle) * r
                    py_pt = frag_cy + m.sin(angle) * r
                    points.append((int(px_pt), int(py_pt)))
                if len(points) >= 3:
                    pygame.draw.polygon(frag_surf, color, points)
                    # 가장자리
                    pygame.draw.polygon(frag_surf, (color[0] + 30, color[1] + 20, color[2] + 30, color[3]),
                                       points, 1)
            else:
                # 일반 원형 파편
                pygame.draw.circle(frag_surf, color, (frag_cx, frag_cy), size)

            # 눈 파편은 중심에 밝은 점
            if frag_type == 'eye':
                pygame.draw.circle(frag_surf, (255, 200, 200, int(255 * life_ratio)),
                                  (frag_cx, frag_cy), max(1, size // 3))

            screen.blit(frag_surf, (int(frag['x'] - frag_cx), int(frag['y'] - frag_cy)))

        # === 6. 화면 플래시 ===
        if self.death_flash_intensity > 0:
            flash_surf = pygame.Surface(screen.get_size(), pygame.SRCALPHA)
            # 붉은/보라 플래시
            flash_surf.fill((80, 30, 50, min(200, self.death_flash_intensity)))
            screen.blit(flash_surf, (0, 0))

        # === 7. 폭발 중심 글로우 (폭발 페이즈) ===
        if self.death_anim_phase == 1:
            progress = (self.death_anim_timer - self.DEATH_PREEXPLOSION_PHASE) / self.DEATH_EXPLOSION_PHASE
            if progress < 0.3:
                glow_intensity = 1 - progress * 3
                glow_size = int(80 + glow_intensity * 100)
                glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                glow_cx, glow_cy = glow_size, glow_size

                for i in range(5):
                    layer_r = glow_size - i * 15
                    layer_alpha = int(glow_intensity * (180 - i * 30))
                    if layer_r > 0 and layer_alpha > 0:
                        pygame.draw.circle(glow_surf, (150, 60, 90, layer_alpha),
                                         (glow_cx, glow_cy), layer_r)

                screen.blit(glow_surf, (int(px - glow_cx), int(silhouette_y - glow_cy)),
                           special_flags=pygame.BLEND_RGBA_ADD)

    def _draw_death_silhouette(self, screen, cx: int, cy: int):
        """💀 죽음 상태의 엘드리치 눈 (분해되며 사라지는 효과)"""
        import pygame
        import math

        alpha = min(255, self.human_silhouette_alpha)
        scale = self.human_silhouette_scale
        eye_glow = self.human_eye_glow

        if alpha <= 0 or scale <= 0:
            return

        t = self.death_anim_timer * 0.1
        death_progress = min(1.0, self.death_anim_timer / 60)  # 분해 진행도
        shake = math.sin(t * 8) * (3 + death_progress * 5)  # 격렬한 흔들림

        surf_w, surf_h = 160, 180
        silhouette_surf = pygame.Surface((surf_w, surf_h), pygame.SRCALPHA)
        scx, scy = surf_w // 2 + shake, surf_h // 2 - 10

        # === 1. 분해되는 촉수 (바깥으로 흩어짐) ===
        num_tentacles = 8
        for i in range(num_tentacles):
            base_angle = (i / num_tentacles) * math.pi * 2 + t * 0.5
            # 죽음 시 촉수가 바깥으로 튕겨나감
            spread = 1 + death_progress * 2
            wave_offset = math.sin(t * 6 + i) * 0.5

            tentacle_len = (30 + math.sin(t * 3 + i) * 8) * spread
            segments = 6
            prev_x, prev_y = scx, scy

            for j in range(1, segments + 1):
                progress = j / segments
                dist = progress * tentacle_len * scale
                angle = base_angle + wave_offset * progress + shake * 0.02
                thickness = max(1, int((1 - progress * 0.7) * 6 * (1 - death_progress * 0.5)))

                px = scx + math.cos(angle) * dist
                py = scy + math.sin(angle) * dist * 0.7

                # 붉은빛 혼합 (죽음)
                r = int(60 + death_progress * 80 - progress * 30)
                g = int(20 - progress * 10)
                b = int(50 - progress * 30)
                seg_alpha = int(alpha * 0.6 * (1 - progress * 0.4) * (1 - death_progress * 0.3))

                if seg_alpha > 0 and thickness > 0:
                    pygame.draw.line(silhouette_surf, (r, g, b, seg_alpha),
                                   (int(prev_x), int(prev_y)), (int(px), int(py)), thickness)
                prev_x, prev_y = px, py

        # === 2. 균열이 생기는 코어 ===
        core_r = int(25 * scale * (1 - death_progress * 0.3))
        if core_r > 0:
            # 코어 (균열 효과)
            core_alpha = int(alpha * (1 - death_progress * 0.5))
            pygame.draw.circle(silhouette_surf, (30 + int(death_progress * 50), 10, 25, core_alpha),
                             (int(scx), int(scy)), core_r)

            # 균열선
            num_cracks = 5
            for i in range(num_cracks):
                crack_angle = (i / num_cracks) * math.pi * 2 + t * 0.2
                crack_len = core_r * (0.5 + death_progress * 0.8)
                crack_end_x = scx + math.cos(crack_angle) * crack_len
                crack_end_y = scy + math.sin(crack_angle) * crack_len
                crack_alpha = int(200 * death_progress)
                if crack_alpha > 0:
                    pygame.draw.line(silhouette_surf, (255, 150, 100, crack_alpha),
                                   (int(scx), int(scy)), (int(crack_end_x), int(crack_end_y)), 2)

        # === 3. 죽어가는 눈 (붉게 변하며 깜빡임) ===
        if eye_glow > 0:
            flicker = 0.5 + math.sin(t * 12) * 0.5  # 빠른 깜빡임
            dying_intensity = eye_glow * flicker * (1 - death_progress * 0.7)

            # 붉은 글로우 (죽음)
            for i in range(4):
                glow_r = int((15 - i * 3) * scale * dying_intensity)
                if glow_r > 0:
                    glow_alpha = int(dying_intensity * 100 * (1 - i * 0.2))
                    # 황금색 → 붉은색 전환
                    r = 255
                    g = int(200 - death_progress * 150 - i * 20)
                    b = int(80 - death_progress * 60)
                    pygame.draw.circle(silhouette_surf, (r, g, b, glow_alpha), (int(scx), int(scy)), glow_r)

            # 눈 본체
            eye_r = int(10 * scale * dying_intensity)
            if eye_r > 0:
                pygame.draw.circle(silhouette_surf, (255, int(180 - death_progress * 100), 100, int(dying_intensity * 255)),
                                 (int(scx), int(scy)), eye_r)

        # === 4. 분해 파티클 ===
        for i in range(8):
            particle_angle = t * 0.3 + i * (math.pi / 4)
            particle_dist = 20 + death_progress * 40 + i * 5
            px = scx + math.cos(particle_angle) * particle_dist
            py = scy + math.sin(particle_angle) * particle_dist * 0.7 - death_progress * 20

            p_alpha = int(alpha * 0.4 * (1 - death_progress * 0.5))
            p_size = max(1, int(3 - death_progress * 2))
            if p_alpha > 0:
                pygame.draw.circle(silhouette_surf, (80 + int(death_progress * 60), 30, 50, p_alpha),
                                 (int(px), int(py)), p_size)

        screen.blit(silhouette_surf, (cx - surf_w // 2, cy - surf_h // 2))

    def is_death_animation_complete(self) -> bool:
        """죽음 애니메이션이 완료되었는지 확인"""
        return not self.is_death_animating and self.death_anim_phase == 2

    # ==================== 💀 죽음 애니메이션 끝 ====================

    # ==================== 🌑 어둠의 구체 렌더링 ====================

    def _draw_dark_sphere(self, screen, cx: int, cy: int):
        """어둠의 구체 그리기 - 캐릭터를 덮는 불길한 구체"""
        import pygame
        import math

        radius = self.dark_sphere_radius + self.dark_sphere_pulse
        alpha = self.dark_sphere_alpha
        inner_glow = self.dark_sphere_inner_glow

        if radius <= 0 or alpha <= 0:
            return

        # 구체 서피스 생성
        sphere_size = int(radius * 2) + 60
        sphere_surf = pygame.Surface((sphere_size, sphere_size), pygame.SRCALPHA)
        scx, scy = sphere_size // 2, sphere_size // 2

        # === 1. 외곽 글로우 (여러 레이어) ===
        for i in range(4):
            glow_radius = int(radius) + 15 + i * 8
            glow_alpha = max(0, int((alpha // 4) * (1 - i * 0.2)))
            if glow_radius > 0 and glow_alpha > 0:
                pygame.draw.circle(sphere_surf, (60, 20, 80, glow_alpha),
                                 (scx, scy), glow_radius)

        # === 2. 메인 구체 (어둠의 핵심) ===
        # 그라데이션 효과 (바깥에서 안으로 점점 어두워짐)
        for i in range(int(radius), 0, -3):
            ratio = i / radius
            r = int(30 * ratio + 10)
            g = int(15 * ratio + 5)
            b = int(45 * ratio + 15)
            a = int(alpha * (0.7 + 0.3 * (1 - ratio)))
            pygame.draw.circle(sphere_surf, (r, g, b, a), (scx, scy), i)

        # === 3. 내부 발광 (폭발 직전 에너지) ===
        if inner_glow > 0:
            glow_intensity = inner_glow
            glow_r = int(radius * 0.6)
            # 보라색/금색 혼합 발광
            for i in range(3):
                layer_r = glow_r - i * 8
                if layer_r > 0:
                    layer_alpha = int(100 * glow_intensity * (1 - i * 0.3))
                    # 보라/금색 교차
                    if i % 2 == 0:
                        color = (150, 80, 180, layer_alpha)
                    else:
                        color = (200, 150, 80, layer_alpha)
                    pygame.draw.circle(sphere_surf, color, (scx, scy), layer_r)

        # === 4. 구체 표면 파티클 (회전하는 에너지) ===
        for p in self.dark_sphere_particles:
            p_x = scx + math.cos(p['angle']) * (radius + p['dist_offset'])
            p_y = scy + math.sin(p['angle']) * (radius + p['dist_offset'])
            p_alpha = int(200 * (p['life'] / 40))
            p_size = int(p['size'] * (p['life'] / 40))

            if p_size > 0:
                if p['color_type'] == 'purple':
                    p_color = (120, 50, 150, p_alpha)
                else:
                    p_color = (40, 20, 60, p_alpha)
                pygame.draw.circle(sphere_surf, p_color, (int(p_x), int(p_y)), p_size)

        # === 5. 균열 효과 (폭발 직전) ===
        for crack in self.dark_sphere_cracks:
            crack_glow = crack['glow']
            crack_alpha = int(200 * min(1.0, crack_glow))
            crack_color = (220, 180, 100, crack_alpha)  # 금색 균열

            angle = crack['angle']
            length = crack['length'] * radius
            width = int(crack['width'] * crack_glow)

            # 균열 시작점 (구체 표면 안쪽)
            start_x = scx + math.cos(angle) * (radius * 0.3)
            start_y = scy + math.sin(angle) * (radius * 0.3)
            # 균열 끝점 (표면까지)
            end_x = scx + math.cos(angle) * (radius * 0.9)
            end_y = scy + math.sin(angle) * (radius * 0.9)

            if width > 0:
                pygame.draw.line(sphere_surf, crack_color,
                               (int(start_x), int(start_y)),
                               (int(end_x), int(end_y)), width)
                # 균열 끝 발광
                pygame.draw.circle(sphere_surf, (255, 220, 150, crack_alpha // 2),
                                 (int(end_x), int(end_y)), width + 2)

        # === 6. 구체 테두리 (어둠의 경계) ===
        pygame.draw.circle(sphere_surf, (80, 40, 100, int(alpha * 0.8)),
                         (scx, scy), int(radius), 3)

        # 화면에 그리기
        screen.blit(sphere_surf, (cx - scx, cy - scy))

    # ==================== 🌑 어둠의 구체 렌더링 끝 ====================

    def _draw_human_silhouette(self, screen, cx: int, cy: int):
        """👁 오딘의 눈 - 아지랑이 소용돌이 엘드리치 실루엣 (부활 연출용)"""
        import pygame
        import math
        import random

        alpha = self.human_silhouette_alpha
        scale = self.human_silhouette_scale
        eye_glow = self.human_eye_glow

        if alpha <= 0 or scale <= 0:
            return

        # 애니메이션 타이머
        t = self.revival_anim_timer * 0.05

        # Surface 크기
        surf_w, surf_h = 180, 190
        silhouette_surf = pygame.Surface((surf_w, surf_h), pygame.SRCALPHA)
        scx = surf_w // 2
        head_y = 42  # 머리(눈) 위치
        body_center_y = head_y + 50  # 몸통 중심

        # === 0. 배경 아지랑이 후광 ===
        for i in range(5):
            glow_w = int((75 - i * 10) * scale)
            glow_h = int((110 - i * 16) * scale)
            wobble_x = math.sin(t * 0.7 + i * 0.5) * 3
            wobble_y = math.cos(t * 0.5 + i * 0.3) * 2
            glow_alpha = int(alpha * 0.15 * (1 - i * 0.15))
            if glow_alpha > 0 and glow_w > 0 and glow_h > 0:
                glow_rect = pygame.Rect(scx - glow_w // 2 + int(wobble_x),
                                       head_y + 20 - glow_h // 3 + int(wobble_y), glow_w, glow_h)
                pygame.draw.ellipse(silhouette_surf, (30, 15, 48, glow_alpha), glow_rect)

        # === 1. 몸통 - 부드러운 연기/아지랑이 ===
        smoke_layers = 20
        for i in range(smoke_layers):
            progress = i / smoke_layers
            sy = head_y + 18 + progress * 120
            width = int((28 * (1.0 - progress * 0.7) + math.sin(t * 1.2 + progress * 5) * 3) * scale)
            swirl_x = math.sin(t * 1.0 + progress * 4.5) * (6 * progress)
            sx = scx + int(swirl_x)
            smoke_alpha = int(alpha * 0.6 * (1.0 - progress * 0.6) * (0.85 + math.sin(t * 2 + progress * 3) * 0.15))
            r = int(32 - progress * 16)
            g = int(16 - progress * 8)
            b = int(50 - progress * 25)
            if width > 0 and smoke_alpha > 0:
                pygame.draw.ellipse(silhouette_surf, (r, g, b, smoke_alpha),
                                  (sx - width, int(sy) - 5, width * 2, 10))

        # === 2. 소용돌이 곡선 (감싸는 나선) ===
        num_spirals = 6
        for s in range(num_spirals):
            spiral_offset = s * (math.pi * 2 / num_spirals)
            spiral_dir = 1 if s % 2 == 0 else -1
            seg_count = 18
            points = []
            for j in range(seg_count):
                progress = j / seg_count
                angle = spiral_offset + t * 0.6 * spiral_dir + progress * math.pi * 2.5
                radius = (12 + 22 * math.sin(progress * math.pi)) * scale * (0.8 + math.sin(t * 1.5 + s) * 0.2)
                sy = head_y + 5 + progress * 135
                sx = scx + math.cos(angle) * radius
                points.append((int(sx), int(sy)))

            for j in range(1, len(points)):
                progress = j / len(points)
                seg_alpha = int(alpha * 0.3 * (1.0 - progress * 0.5) * (0.6 + math.sin(t * 3 + s + j * 0.3) * 0.4))
                thickness = max(1, int(3 * scale * (1 - progress * 0.6)))
                r = int(55 - progress * 25)
                g = int(28 - progress * 12)
                b = int(75 - progress * 30)
                if seg_alpha > 0:
                    pygame.draw.line(silhouette_surf, (r, g, b, seg_alpha),
                                   points[j-1], points[j], thickness)

        # === 3. 양쪽 팔 (부드러운 연기 촉수) ===
        arm_base_y = head_y + 22

        for side in [-1, 1]:
            arm_segments = 14
            arm_length = (50 + math.sin(t * 1.5 + side) * 6) * scale

            arm_start_x = scx + side * int(16 * scale)
            arm_start_y = arm_base_y

            prev_x, prev_y = float(arm_start_x), float(arm_start_y)

            for j in range(1, arm_segments + 1):
                progress = j / arm_segments
                base_angle = side * (0.3 + progress * 0.5)
                wave = math.sin(t * 2.0 + j * 0.4 + side * 2) * 0.25 * progress
                angle = base_angle + wave

                dist = progress * arm_length
                px = arm_start_x + math.cos(angle + math.pi/2 * side) * dist * 0.5 + side * dist * 0.5
                py = arm_start_y + math.sin(angle) * dist * 0.3 + progress * 28 * scale

                thickness_glow = max(2, int((1 - progress * 0.6) * 10 * scale))
                thickness_core = max(1, int((1 - progress * 0.7) * 6 * scale))

                glow_alpha = int(alpha * 0.18 * (1 - progress * 0.5))
                if glow_alpha > 0:
                    pygame.draw.line(silhouette_surf, (45, 22, 65, glow_alpha),
                                   (int(prev_x), int(prev_y)), (int(px), int(py)), thickness_glow)

                seg_alpha = int(alpha * 0.7 * (1 - progress * 0.45))
                r = int(42 - progress * 24)
                g = int(20 - progress * 12)
                b = int(62 - progress * 35)
                pygame.draw.line(silhouette_surf, (r, g, b, seg_alpha),
                               (int(prev_x), int(prev_y)), (int(px), int(py)), thickness_core)

                prev_x, prev_y = px, py

            # 팔 끝 연기 흩어짐
            for k in range(3):
                fork_angle = side * 0.6 + (k - 1) * 0.35 + math.sin(t * 2.5 + k) * 0.15
                fork_len = (8 + math.sin(t * 3 + k) * 3) * scale
                fork_x = prev_x + math.cos(fork_angle) * fork_len * side
                fork_y = prev_y + math.sin(fork_angle) * fork_len * 0.4 + fork_len * 0.3
                pygame.draw.line(silhouette_surf, (30, 14, 45, int(alpha * 0.4)),
                               (int(prev_x), int(prev_y)), (int(fork_x), int(fork_y)), 2)

        # === 4. 머리 주변 아지랑이 ===
        for i in range(8):
            wisp_angle = (i / 8) * math.pi * 2 + t * 0.3
            wisp_len = (18 + math.sin(t * 2 + i * 1.2) * 5) * scale
            prev_wx, prev_wy = float(scx), float(head_y)

            for j in range(1, 5):
                progress = j / 4
                dist = (10 + progress * wisp_len)
                a = wisp_angle + math.sin(t * 2.5 + i + j * 0.5) * 0.3 * progress
                wx = scx + math.cos(a) * dist
                wy = head_y + math.sin(a) * dist * 0.5

                wisp_alpha = int(alpha * 0.45 * (1 - progress * 0.55))
                thickness = max(1, int(3 * scale * (1 - progress * 0.5)))
                pygame.draw.line(silhouette_surf, (40, 20, 58, wisp_alpha),
                               (int(prev_wx), int(prev_wy)), (int(wx), int(wy)), thickness)
                prev_wx, prev_wy = wx, wy

        # === 5. 머리/얼굴 영역 (코어) ===
        head_x = scx
        core_radius = int(22 * scale)

        for i in range(5):
            glow_r = core_radius + int((12 - i * 3) * scale)
            glow_alpha = int(alpha * 0.2 * (1 - i * 0.12))
            if glow_r > 0:
                pygame.draw.circle(silhouette_surf, (50, 25, 78, glow_alpha), (head_x, head_y), glow_r)

        if core_radius > 0:
            pygame.draw.circle(silhouette_surf, (15, 7, 28, alpha), (head_x, head_y), core_radius)
            pygame.draw.circle(silhouette_surf, (45, 22, 68, int(alpha * 0.7)), (head_x, head_y), core_radius, 2)

        # === 6. 오딘의 눈 ===
        if eye_glow > 0:
            eye_x = head_x
            eye_y = head_y
            eye_intensity = eye_glow * (0.88 + math.sin(t * 3.5) * 0.12)

            for i in range(6):
                glow_r = int((16 - i * 2) * scale * eye_intensity)
                if glow_r > 0:
                    glow_alpha = int(eye_glow * 85 * (1 - i * 0.12))
                    glow_color = (255, 205 - i * 12, 85 - i * 10, glow_alpha)
                    pygame.draw.circle(silhouette_surf, glow_color, (eye_x, eye_y), glow_r)

            eye_r = int(10 * scale * eye_intensity)
            if eye_r > 0:
                pygame.draw.circle(silhouette_surf, (255, 220, 115, int(eye_glow * 255)), (eye_x, eye_y), eye_r)

            mid_r = int(7 * scale * eye_intensity)
            if mid_r > 0:
                pygame.draw.circle(silhouette_surf, (255, 235, 150, int(eye_glow * 255)), (eye_x, eye_y), mid_r)

            inner_r = int(4 * scale * eye_intensity)
            if inner_r > 0:
                pygame.draw.circle(silhouette_surf, (255, 250, 215, int(eye_glow * 255)), (eye_x, eye_y), inner_r)

            pupil_h = int(8 * scale * eye_intensity)
            pupil_w = int(3 * scale * eye_intensity)
            if pupil_h > 0 and pupil_w > 0:
                pupil_rect = pygame.Rect(eye_x - pupil_w // 2, eye_y - pupil_h // 2, pupil_w, pupil_h)
                pygame.draw.ellipse(silhouette_surf, (52, 28, 18, int(eye_glow * 230)), pupil_rect)

            highlight_offset = int(3 * scale)
            hl_r = int(2 * scale)
            if hl_r > 0:
                pygame.draw.circle(silhouette_surf, (255, 255, 250, int(eye_glow * 200)),
                                 (eye_x - highlight_offset, eye_y - highlight_offset), hl_r)

        # === 7. 룬 문자 ===
        rune_symbols = ['ᚠ', 'ᚢ', 'ᚦ', 'ᚨ', 'ᚱ', 'ᚲ', 'ᚷ', 'ᚹ', 'ᚺ', 'ᚾ', 'ᛁ', 'ᛃ', 'ᛇ', 'ᛈ']

        try:
            rune_font = pygame.font.Font(None, 18)
            num_runes = 5
            for i in range(num_runes):
                rune_angle = t * 0.12 + i * (math.pi * 2 / num_runes)
                rune_dist = (42 + math.sin(t * 1.3 + i * 1.8) * 5) * scale
                rune_x = scx + math.cos(rune_angle) * rune_dist
                rune_y = head_y + math.sin(rune_angle) * rune_dist * 0.5

                rune_alpha = int(alpha * 0.7 * (0.5 + math.sin(t * 2.5 + i * 1.5) * 0.5))
                symbol_idx = (i + int(t * 0.35)) % len(rune_symbols)

                glow_surf = rune_font.render(rune_symbols[symbol_idx], True, (210, 170, 245))
                glow_surf.set_alpha(int(rune_alpha * 0.3))
                silhouette_surf.blit(glow_surf, (int(rune_x) - 5, int(rune_y) - 7))

                rune_surf = rune_font.render(rune_symbols[symbol_idx], True, (185, 120, 210))
                rune_surf.set_alpha(rune_alpha)
                silhouette_surf.blit(rune_surf, (int(rune_x) - 4, int(rune_y) - 6))
        except:
            pass

        # === 8. 파티클 효과 ===
        random.seed(int(t * 10) % 1000)
        for i in range(10):
            particle_angle = (i / 10) * math.pi * 2 + t * 0.1
            particle_dist = (30 + (i % 3) * 10 + math.sin(t * 1.5 + i) * 4) * scale
            px = scx + math.cos(particle_angle) * particle_dist
            py = head_y + 24 + math.sin(particle_angle) * particle_dist * 0.8

            color_type = i % 4
            if color_type == 0:
                p_color = (110, 80, 190)
            elif color_type == 1:
                p_color = (190, 65, 110)
            elif color_type == 2:
                p_color = (75, 110, 185)
            else:
                p_color = (85, 170, 175)

            p_alpha = int(alpha * 0.5 * (0.4 + math.sin(t * 4 + i * 2) * 0.6))
            p_size = 2 + int(math.sin(t * 2.5 + i) * 1)
            if p_alpha > 0 and p_size > 0:
                pygame.draw.circle(silhouette_surf, (*p_color, p_alpha), (int(px), int(py)), p_size)

        # === 9. 에너지 파동 효과 ===
        for i in range(2):
            wave_progress = (t * 0.3 + i * 0.5) % 1.0
            wave_w = int((30 + wave_progress * 32) * scale)
            wave_h = int((42 + wave_progress * 48) * scale)
            wave_alpha = int(alpha * 0.2 * (1 - wave_progress))
            if wave_alpha > 0 and wave_w > 0 and wave_h > 0:
                wave_rect = pygame.Rect(scx - wave_w // 2, head_y + 10 - wave_h // 4, wave_w, wave_h)
                pygame.draw.ellipse(silhouette_surf, (65, 32, 88, wave_alpha), wave_rect, 2)

        # 화면에 그리기
        screen.blit(silhouette_surf, (cx - surf_w // 2, cy - surf_h // 2))

    def is_revival_animation_complete(self) -> bool:
        """부활 애니메이션이 완료되었는지 확인 (폭발 이펙트 포함)"""
        return not self.is_revival_animating and not self.dark_burst_active and self.revival_anim_phase == 3

    # ==================== 부활 애니메이션 끝 ====================

    def try_revival(self) -> bool:
        """라운드 패배 시 부활 시도.

        Returns:
            True: 부활 성공 (페널티 적용됨)
            False: 부활 실패 또는 이미 부활 사용함 (진정한 패배)
        """
        if not self.active:
            return False

        # 이미 부활 사용했거나 페널티 상태면 진정한 패배
        if self.revival_used or self.penalty_active:
            if LEGENDARY_DEBUG_ENABLED:
                print("👁 오딘의 눈: 이미 부활 사용함 또는 페널티 상태 - 진정한 패배!")
            return False

        # 부활 확률 체크
        import random
        roll = random.random() * 100
        if roll <= self.revival_chance:
            # 부활 성공!
            self.revival_used = True
            self.penalty_active = True
            self.dark_energy_active = True
            self.dark_energy_timer = 180  # 3초 (60fps 기준)

            if LEGENDARY_DEBUG_ENABLED:
                print(f"👁 오딘의 눈: 부활 성공! (확률: {self.revival_chance:.0f}%, 굴림: {roll:.1f})")
            return True
        else:
            # 부활 실패
            if LEGENDARY_DEBUG_ENABLED:
                print(f"👁 오딘의 눈: 부활 실패 (확률: {self.revival_chance:.0f}%, 굴림: {roll:.1f})")
            return False

    def get_movement_penalty(self) -> float:
        """이동 속도 페널티 배율 반환 (1.0 = 패널티 없음, 0.5 = 50% 감소)"""
        if self.penalty_active:
            return 0.5
        return 1.0

    def get_dash_token_limit(self) -> int:
        """대시 토큰 제한 (None = 제한 없음)"""
        if self.penalty_active:
            return 1
        return None

    def get_dash_distance_multiplier(self) -> float:
        """변신 상태에서 대쉬 거리 배율 반환 (1.0 = 기본, 1.5 = 50% 증가)"""
        if self.penalty_active or self.dark_energy_active:
            return 1.5
        return 1.0

    def get_dash_cooldown_multiplier(self) -> float:
        """대시 쿨다운 배율 (1.0 = 기본, 2.0 = +100%)"""
        if self.penalty_active:
            return 2.0
        return 1.0

    def update(self, dt: float, ui_mode: bool = False):
        """애니메이션 및 상태 업데이트"""
        super().update(dt, ui_mode)

        # 🌑 솟아오르기 애니메이션 타이머
        if self.rise_from_ground_active and not ui_mode:
            self.rise_from_ground_timer += 1
            if self.rise_from_ground_timer >= self.RISE_FROM_GROUND_DURATION:
                self.rise_from_ground_active = False

        # 어둠의 기운 타이머 업데이트
        if self.dark_energy_active and not ui_mode:
            # 라운드 종료까지 유지 모드가 아닐 때만 타이머 감소
            if not self.dark_energy_until_round_end:
                self.dark_energy_timer -= 1
                if self.dark_energy_timer <= 0:
                    self.dark_energy_active = False
                    self.dark_energy_timer = 0

            # 어둠 파티클 생성
            self._update_dark_particles()

        # 애니메이션 프레임 카운터 업데이트
        if self.animation_frames and len(self.animation_frames) > 1:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)

    def _update_dark_particles(self):
        """어둠 파티클 업데이트"""
        import random

        # 파티클 생성
        if random.random() < 0.3:  # 30% 확률로 파티클 생성
            self.dark_particles.append({
                'x': random.uniform(-30, 30),
                'y': random.uniform(-30, 30),
                'vx': random.uniform(-1, 1),
                'vy': random.uniform(-2, -0.5),
                'life': random.randint(30, 60),
                'size': random.uniform(3, 8),
                'alpha': 200
            })

        # 파티클 업데이트
        for particle in self.dark_particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['life'] -= 1
            particle['alpha'] = max(0, particle['alpha'] - 4)

            if particle['life'] <= 0:
                self.dark_particles.remove(particle)

    def draw_dark_energy_effect(self, screen, player_x: int, player_y: int):
        """플레이어 주변에 어둠의 기운 이펙트 그리기 - 원형 효과 제거됨"""
        if not self.dark_energy_active:
            return
        # 원형 글로우 및 파티클 모두 제거됨 - 아무것도 그리지 않음
        pass

    def draw_dark_paddle(self, screen, paddle_rect, player_vx: float = 0):
        """👁 오딘의 눈 변신 상태: 인간형 엘드리치 (폴리곤 몸통 + 소용돌이 에너지 + 촉수 팔)"""
        if not self.penalty_active and not self.dark_energy_active:
            return None

        if self.is_revival_animating or self.dark_burst_active:
            return None

        import pygame
        import math
        import random

        cx = paddle_rect.centerx
        cy = paddle_rect.centery - 55
        t = self.animation_time * 0.8
        lean = player_vx * 0.012
        pulse = (math.sin(t * 3) + 1) / 2
        lean_px = int(lean * 8)

        # 🌑 솟아오르기 애니메이션 오프셋 계산
        rise_offset_y = 0
        rise_alpha = 255
        if self.rise_from_ground_active:
            rp = min(1.0, self.rise_from_ground_timer / self.RISE_FROM_GROUND_DURATION)
            # ease-out: 처음 빠르게, 끝에 감속
            ease = 1 - (1 - rp) * (1 - rp)
            rise_offset_y = int(120 * (1 - ease))  # 아래 120px에서 올라옴
            rise_alpha = int(255 * min(1.0, rp * 2.5))  # 빠르게 페이드인

        if not hasattr(self, '_eldritch_particles'):
            self._eldritch_particles = []

        surf_w, surf_h = 180, 185
        main_surf = pygame.Surface((surf_w, surf_h), pygame.SRCALPHA)
        scx = surf_w // 2
        head_y = 36
        shoulder_y = 55
        body_end_y = 170

        # ═══════════════════════════════════════════════════════════════════
        # 0. 보라빛 원형 후광 오라
        # ═══════════════════════════════════════════════════════════════════
        aura_cx = scx + int(lean * 4)
        aura_cy = head_y + 30
        for i in range(10):
            ar = 74 - i * 5 + int(math.sin(t * 0.7 + i * 0.3) * 3)
            aa = int(22 - i * 1.8)
            if ar > 0 and aa > 0:
                pygame.draw.circle(main_surf, (55, 25, 85, aa),
                                  (aura_cx + int(math.sin(t * 0.4 + i * 0.6) * 2),
                                   aura_cy + int(math.cos(t * 0.35 + i * 0.5) * 1.5)), ar)

        # ═══════════════════════════════════════════════════════════════════
        # 1. 몸통 - 연속 폴리곤 (하나의 덩어리)
        # ═══════════════════════════════════════════════════════════════════
        # 좌우 외곽선을 계산하여 하나의 폴리곤으로 채움
        body_steps = 24
        left_edge = []
        right_edge = []

        for i in range(body_steps + 1):
            progress = i / body_steps
            by = shoulder_y + progress * (body_end_y - shoulder_y)

            # 폭: 어깨(넓음) → 허리(좁아짐) → 하단(사라짐)
            if progress < 0.12:
                half_w = 22 + progress * 60  # 어깨 확장
            elif progress < 0.35:
                p2 = (progress - 0.12) / 0.23
                half_w = 29 - p2 * 8  # 가슴~허리
            elif progress < 0.65:
                p3 = (progress - 0.35) / 0.3
                half_w = 21 - p3 * 6  # 허리
            else:
                p4 = (progress - 0.65) / 0.35
                half_w = 15 - p4 * 11  # 하단 소멸

            # 유기적 외곽 흔들림
            wave_l = math.sin(t * 1.0 + progress * 5) * 3 * progress
            wave_r = math.sin(t * 1.0 + progress * 5 + 2.0) * 3 * progress
            swirl = math.sin(t * 0.7 + progress * 3.5) * 4 * progress

            center_x = scx + lean_px * (1 - progress * 0.5) + int(swirl)
            half_w = max(1, int(half_w))

            left_edge.append((center_x - half_w + int(wave_l), int(by)))
            right_edge.append((center_x + half_w + int(wave_r), int(by)))

        # 폴리곤 포인트 (왼쪽 위→아래, 오른쪽 아래→위)
        poly_points = left_edge + list(reversed(right_edge))

        if len(poly_points) >= 3:
            # 글로우 레이어 (확장된 폴리곤)
            glow_poly = []
            mid_x = sum(p[0] for p in poly_points) / len(poly_points)
            mid_y = sum(p[1] for p in poly_points) / len(poly_points)
            for px, py in poly_points:
                dx, dy = px - mid_x, py - mid_y
                dist = math.sqrt(dx*dx + dy*dy) if (dx*dx + dy*dy) > 0 else 1
                glow_poly.append((int(px + dx/dist * 8), int(py + dy/dist * 5)))
            pygame.draw.polygon(main_surf, (40, 18, 60, 35), glow_poly)

            # 중간 레이어
            mid_poly = []
            for px, py in poly_points:
                dx, dy = px - mid_x, py - mid_y
                dist = math.sqrt(dx*dx + dy*dy) if (dx*dx + dy*dy) > 0 else 1
                mid_poly.append((int(px + dx/dist * 3), int(py + dy/dist * 2)))
            pygame.draw.polygon(main_surf, (22, 9, 35, 160), mid_poly)

            # 코어 (가장 어두운)
            pygame.draw.polygon(main_surf, (12, 4, 20, 220), poly_points)

        # ═══════════════════════════════════════════════════════════════════
        # 2. 몸통 감싸는 소용돌이 에너지 (어둠의 기운)
        # ═══════════════════════════════════════════════════════════════════
        # 몸통을 감싸는 곡선들 (나선/소용돌이)
        num_wisps = 8
        for wi in range(num_wisps):
            wisp_offset = wi * (math.pi * 2 / num_wisps)
            wisp_dir = 1 if wi % 2 == 0 else -1
            wisp_segs = 20
            prev_wx, prev_wy = None, None

            for j in range(wisp_segs):
                wp = j / wisp_segs
                # 나선 경로: 몸통 주변을 감싸면서 위→아래
                wisp_y = shoulder_y - 5 + wp * (body_end_y - shoulder_y + 10)
                angle = wisp_offset + t * 0.5 * wisp_dir + wp * math.pi * 3
                # 반경: 몸통 폭에 맞춰 (위는 넓고 아래는 좁게)
                if wp < 0.2:
                    rad = 20 + wp * 40
                elif wp < 0.5:
                    rad = 28 - (wp - 0.2) / 0.3 * 6
                else:
                    rad = 22 - (wp - 0.5) / 0.5 * 14

                rad = max(3, rad + math.sin(t * 1.5 + wi + wp * 4) * 4)
                wisp_x = scx + lean_px * (1 - wp * 0.5) + math.cos(angle) * rad

                # 알파: 위아래 끝은 투명, 중간은 진하게
                edge_fade = min(wp, 1 - wp) * 2  # 0→1→0
                wisp_alpha = int(70 * edge_fade * (0.6 + math.sin(t * 2.5 + wi * 1.3 + wp * 3) * 0.4))
                thickness = max(1, int(4 * edge_fade * (1 + math.sin(t * 2 + wi) * 0.3)))

                if prev_wx is not None and wisp_alpha > 0:
                    pygame.draw.line(main_surf, (50, 24, 72, wisp_alpha),
                                   (int(prev_wx), int(prev_wy)), (int(wisp_x), int(wisp_y)), thickness)
                prev_wx, prev_wy = wisp_x, wisp_y

        # ═══════════════════════════════════════════════════════════════════
        # 3. 팔 촉수 (양쪽, 길고 두꺼운 엘드리치 팔)
        # ═══════════════════════════════════════════════════════════════════
        arm_configs = [
            # (side, Y오프셋, 초기각, 길이, 두께, 컬방향, 속도, 컬강도)
            (-1, -2,  -0.35, 75, 12,  1,  0.65, 1.4),  # 메인 왼팔
            (-1,  6,  -0.1,  62,  8, -1,  0.85, 1.7),  # 보조 왼팔
            (-1, -8,  -0.6,  55,  7,  1,  1.0,  1.9),  # 상단 왼팔
            ( 1, -2,   0.35, 73, 12, -1,  0.7,  1.4),  # 메인 오른팔
            ( 1,  6,   0.1,  60,  8,  1,  0.9,  1.7),  # 보조 오른팔
            ( 1, -8,   0.6,  53,  7, -1,  1.05, 1.9),  # 상단 오른팔
        ]

        for idx, (side, y_off, base_angle, length, thickness, curl_dir, speed, curl_strength) in enumerate(arm_configs):
            segments = 18
            points = []

            arm_sx = scx + lean_px + side * 20
            arm_sy = shoulder_y + y_off

            for j in range(segments + 1):
                progress = j / segments
                curl = curl_dir * progress * progress * curl_strength
                wave = math.sin(t * speed + idx * 1.1 + progress * 3) * 0.3 * progress
                angle = (math.pi * 0.5 * side) + base_angle + curl + wave + lean * (1 - progress)

                dist = progress * length
                px = arm_sx + math.cos(angle) * dist
                py = arm_sy + math.sin(angle) * dist * 0.55 + progress * 18

                px += math.sin(t * 0.8 + idx * 1.5 + progress * 4) * 3 * progress
                py += math.cos(t * 0.6 + idx * 0.9 + progress * 3) * 2 * progress

                points.append((int(px), int(py)))

            for j in range(1, len(points)):
                progress = j / len(points)
                w_outer = max(2, int(thickness * 1.6 * (1 - progress * 0.7)))
                w_mid = max(1, int(thickness * 1.05 * (1 - progress * 0.65)))
                w_core = max(1, int(thickness * 0.6 * (1 - progress * 0.6)))

                a_outer = int(30 * (1 - progress * 0.5))
                a_mid = int(160 * (1 - progress * 0.4))
                a_core = int(230 * (1 - progress * 0.35))

                rv = int(38 - progress * 20)
                gv = int(15 - progress * 8)
                bv = int(55 - progress * 28)

                if a_outer > 0 and w_outer > 1:
                    pygame.draw.line(main_surf, (55, 28, 75, a_outer),
                                   points[j-1], points[j], w_outer)
                if a_mid > 0 and w_mid > 0:
                    pygame.draw.line(main_surf, (rv, gv, bv, a_mid),
                                   points[j-1], points[j], w_mid)
                if a_core > 0 and w_core > 0:
                    pygame.draw.line(main_surf, (max(0, 14 - int(progress*10)),
                                                max(0, 4 - int(progress*3)),
                                                max(0, 24 - int(progress*15)), a_core),
                                   points[j-1], points[j], w_core)

            # 팔 끝 갈래
            if len(points) >= 2:
                tip_x, tip_y = points[-1]
                tp_x, tp_y = points[-2]
                tip_a = math.atan2(tip_y - tp_y, tip_x - tp_x)
                for k in range(3):
                    fa = tip_a + (k - 1) * 0.5 + math.sin(t * 2.5 + idx + k) * 0.2
                    fl = 9 + math.sin(t * 3 + k + idx) * 3
                    fx = tip_x + math.cos(fa) * fl
                    fy = tip_y + math.sin(fa) * fl
                    pygame.draw.line(main_surf, (22, 8, 35, 100),
                                   (tip_x, tip_y), (int(fx), int(fy)), max(1, thickness // 3))

        # ═══════════════════════════════════════════════════════════════════
        # 4. 머리 주변 촉수 (뿔/머리카락)
        # ═══════════════════════════════════════════════════════════════════
        head_x = scx + lean_px
        horn_configs = [
            (-0.8, 28, 5), (-1.3, 22, 4), (0.8, 26, 5), (1.3, 20, 4),
            (-1.6, 16, 3), (1.6, 16, 3),
        ]
        for hi, (h_angle, h_len, h_thick) in enumerate(horn_configs):
            prev_hx, prev_hy = float(head_x), float(head_y - 8)
            for j in range(1, 11):
                hp = j / 10
                ha = h_angle - math.pi * 0.5 + math.sin(t * 1.2 + hi + hp * 3) * 0.25 * hp
                hx = head_x + math.cos(ha) * hp * h_len
                hy = (head_y - 8) + math.sin(ha) * hp * h_len
                w = max(1, int(h_thick * (1 - hp * 0.7)))
                a = int(180 * (1 - hp * 0.5))
                pygame.draw.line(main_surf, (30, 12, 45, a),
                               (int(prev_hx), int(prev_hy)), (int(hx), int(hy)), w)
                prev_hx, prev_hy = hx, hy

        # ═══════════════════════════════════════════════════════════════════
        # 5. 머리/얼굴 코어
        # ═══════════════════════════════════════════════════════════════════
        core_radius = 19
        for i in range(5):
            gr = core_radius + 9 - i * 2 + int(pulse * 2)
            if gr > 0:
                pygame.draw.circle(main_surf, (46, 20, 70, int(42 * (1 - i * 0.14))),
                                  (head_x, head_y), gr)
        pygame.draw.circle(main_surf, (12, 5, 22, 245), (head_x, head_y), core_radius)
        pygame.draw.circle(main_surf, (40, 16, 58, 140), (head_x, head_y), core_radius, 2)

        # ═══════════════════════════════════════════════════════════════════
        # 6. 오딘의 눈
        # ═══════════════════════════════════════════════════════════════════
        eye_x = head_x + int(player_vx * 0.04)
        eye_y = head_y
        ei = 0.88 + pulse * 0.12

        for i in range(8):
            gr = int((19 - i * 2.1) * ei)
            if gr > 0:
                pygame.draw.circle(main_surf, (255, 195 - i * 14, 60 - i * 6, int(62 * (1 - i * 0.1))),
                                  (eye_x, eye_y), gr)
        pygame.draw.circle(main_surf, (255, 218, 105, 255), (eye_x, eye_y), int(10 * ei))
        pygame.draw.circle(main_surf, (255, 235, 148, 255), (eye_x, eye_y), int(7 * ei))
        pygame.draw.circle(main_surf, (255, 250, 215, 255), (eye_x, eye_y), int(4 * ei))

        pupil_h = int(8 * ei)
        pupil_w = int(3 * ei)
        pr = pygame.Rect(eye_x + int(player_vx * 0.03) - pupil_w // 2,
                         eye_y - pupil_h // 2, pupil_w, pupil_h)
        pygame.draw.ellipse(main_surf, (52, 28, 18, 230), pr)
        ho = int(3 * ei)
        pygame.draw.circle(main_surf, (255, 255, 250, 200), (eye_x - ho, eye_y - ho), int(2 * ei))

        # ═══════════════════════════════════════════════════════════════════
        # 7. 룬 문자
        # ═══════════════════════════════════════════════════════════════════
        rune_symbols = ['ᚠ', 'ᚢ', 'ᚦ', 'ᚨ', 'ᚱ', 'ᚲ', 'ᚷ', 'ᚹ']
        try:
            rune_font = pygame.font.Font(None, 22)
            for i in range(7):
                ra = t * 0.15 + i * (math.pi * 2 / 7)
                rd = 54 + math.sin(t * 1.2 + i * 1.5) * 7
                rx = scx + lean * 4 + math.cos(ra) * rd
                ry = head_y + 22 + math.sin(ra) * rd * 0.75
                rune_alpha = int(200 * (0.45 + math.sin(t * 2.0 + i * 1.3) * 0.55))
                si = (i + int(t * 0.3)) % len(rune_symbols)
                gs = rune_font.render(rune_symbols[si], True, (210, 160, 248))
                gs.set_alpha(int(rune_alpha * 0.4))
                main_surf.blit(gs, (int(rx) - 6, int(ry) - 8))
                rs = rune_font.render(rune_symbols[si], True, (185, 115, 218))
                rs.set_alpha(rune_alpha)
                main_surf.blit(rs, (int(rx) - 5, int(ry) - 7))
        except:
            pass

        # ═══════════════════════════════════════════════════════════════════
        # 8. 파티클
        # ═══════════════════════════════════════════════════════════════════
        if len(self._eldritch_particles) < 14 and random.random() < 0.5:
            sa = random.uniform(0, math.pi * 2)
            sd = random.uniform(22, 55)
            self._eldritch_particles.append({
                'x': scx + math.cos(sa) * sd,
                'y': head_y + 25 + math.sin(sa) * sd * 0.8,
                'vx': random.uniform(-0.3, 0.3) + player_vx * 0.01,
                'vy': random.uniform(-0.65, -0.15),
                'size': random.uniform(1.5, 3.2),
                'life': random.randint(30, 60),
                'max_life': 60,
                'color_type': random.randint(0, 3)
            })
        for p in self._eldritch_particles[:]:
            p['x'] += p['vx'] + math.sin(t * 4 + p['life'] * 0.1) * 0.15
            p['y'] += p['vy']
            p['life'] -= 1
            if p['life'] <= 0:
                self._eldritch_particles.remove(p)
                continue
            lr = p['life'] / p['max_life']
            ps = int(p['size'] * lr)
            pa = int(145 * lr)
            if ps > 0 and pa > 0:
                cols = [(115,75,190), (165,60,115), (70,100,185), (80,155,175)]
                c = cols[p['color_type']]
                pygame.draw.circle(main_surf, (c[0], c[1], c[2], pa), (int(p['x']), int(p['y'])), ps)

        # ═══════════════════════════════════════════════════════════════════
        # 9. 에너지 파동
        # ═══════════════════════════════════════════════════════════════════
        for i in range(2):
            wp = (t * 0.25 + i * 0.5) % 1.0
            wr = int(25 + wp * 38)
            wa = int(18 * (1 - wp))
            if wa > 0 and wr > 0:
                pygame.draw.circle(main_surf, (58, 26, 82, wa),
                                  (scx + int(lean * 4), head_y + 15), wr, 2)

        # 🌑 솟아오르기: 알파 적용 + Y 오프셋
        if rise_alpha < 255:
            main_surf.set_alpha(rise_alpha)

        # 🌀 어둠의 늪 발동 중: Y축 회전 (좌우 빙글빙글 스핀)
        if self.dark_swamp_active or (hasattr(self, 'lurker_spikes') and len(self.lurker_spikes) > 0):
            spin_speed = 20.0  # 회전 속도
            spin_angle = t * spin_speed
            scale_x = math.cos(spin_angle)
            abs_scale = abs(scale_x)

            if abs_scale < 0.05:
                # 완전 옆면일 때: 얇은 실루엣 라인만 표시
                line_surf = pygame.Surface((3, surf_h), pygame.SRCALPHA)
                line_surf.fill((40, 18, 60, 180))
                blit_x = cx - 1
                blit_y = cy - surf_h // 2 + rise_offset_y
                screen.blit(line_surf, (blit_x, blit_y))
            else:
                # X축 스케일링으로 Y축 회전 효과
                scaled_w = max(4, int(surf_w * abs_scale))
                if scale_x < 0:
                    # 뒷면: 좌우 반전
                    flipped = pygame.transform.flip(main_surf, True, False)
                    scaled_surf = pygame.transform.scale(flipped, (scaled_w, surf_h))
                else:
                    scaled_surf = pygame.transform.scale(main_surf, (scaled_w, surf_h))
                blit_x = cx - scaled_w // 2
                blit_y = cy - surf_h // 2 + rise_offset_y
                screen.blit(scaled_surf, (blit_x, blit_y))
        else:
            screen.blit(main_surf, (cx - surf_w // 2, cy - surf_h // 2 + rise_offset_y))
        return True

    # ═══════════════════════════════════════════════════════════════════════════
    # 어둠의 늪 스킬 시스템
    # ═══════════════════════════════════════════════════════════════════════════

    def is_transformed(self) -> bool:
        """오딘의 눈 변신 상태인지 확인 (기존 스킬 잠금용)"""
        return self.penalty_active or self.dark_energy_active

    def enable_dark_swamp(self):
        """어둠의 늪 스킬 활성화 (부활 후 호출)"""
        self.dark_swamp_enabled = True
        self.dark_swamp_cooldown_timer = 0
        print("👁 [오딘의 눈] 어둠의 늪 스킬 활성화!")

    def disable_dark_swamp(self):
        """어둠의 늪 스킬 비활성화"""
        self.dark_swamp_enabled = False
        self.dark_swamp_active = False
        self.lurker_spikes = []
        self.dark_swamp_cooldown_timer = 0

    def can_use_dark_swamp(self, current_gauge: float) -> bool:
        """어둠의 늪 스킬 사용 가능 여부"""
        if not self.dark_swamp_enabled:
            return False
        if not self.is_transformed():
            return False
        # 👁 변신 애니메이션 중에는 스킬 사용 불가 (애니메이션 완료 후 사용 가능)
        if self.is_revival_animating or self.dark_burst_active:
            return False
        if self.dark_swamp_cooldown_timer > 0:
            return False
        if current_gauge < self.dark_swamp_cost:
            return False
        if self.dark_swamp_active:
            return False
        return True

    def get_dark_swamp_cooldown_ratio(self) -> float:
        """쿨타임 비율 반환 (0=사용가능, 1=쿨타임중)"""
        if self.dark_swamp_cooldown <= 0:
            return 0.0
        return min(1.0, self.dark_swamp_cooldown_timer / self.dark_swamp_cooldown)

    def activate_dark_swamp(self, player_x: int, player_y: int, boss_y: int, boss_x: int = None) -> bool:
        """어둠의 늪 스킬 발동 - 럴커 가시 발사 (플레이어 → 보스 방향)"""
        if self.dark_swamp_active:
            return False

        import pygame
        try:
            # 스킬 발동 사운드
            sound_path = resource_path("sounds/lurker_attack.wav")
            if os.path.exists(sound_path):
                sound = pygame.mixer.Sound(sound_path)
                sound.set_volume(0.5)
                sound.play()
        except:
            pass

        self.dark_swamp_active = True
        self.spike_spawn_timer = 0
        self.spike_count = 0
        self.lurker_spikes = []
        self.spike_smoke_particles = []
        self.spike_sparkle_particles = []

        # 가시 경로 설정 (플레이어 → 보스 방향으로 순차 발사)
        self.spike_start_x = player_x  # 시작 X (플레이어)
        self.spike_start_y = player_y - 30  # 시작 Y (플레이어 위)
        self.spike_end_x = boss_x if boss_x is not None else player_x  # 끝 X (보스)
        self.spike_end_y = boss_y + 30  # 끝 Y (보스 아래)

        # 쿨타임 시작
        self.dark_swamp_cooldown_timer = self.dark_swamp_cooldown

        # 가시 물결 효과 시작
        self.spike_wave_active = True
        self.spike_wave_progress = 0.0

        return True

    def update_dark_swamp(self, dt: float = 1/60):
        """어둠의 늪 스킬 업데이트"""
        import math
        import random

        # 쿨타임 감소
        if self.dark_swamp_cooldown_timer > 0:
            self.dark_swamp_cooldown_timer -= 1

        if not self.dark_swamp_active:
            return

        # 가시 물결 진행
        if self.spike_wave_active:
            self.spike_wave_progress += 0.025  # 약 40프레임(0.67초)에 완료

            if self.spike_wave_progress >= 1.0:
                self.spike_wave_active = False
                self.spike_wave_progress = 1.0

        # 가시 생성
        self.spike_spawn_timer += 1
        if self.spike_spawn_timer >= self.spike_spawn_interval and self.spike_count < self.max_spikes:
            self.spike_spawn_timer = 0
            self._spawn_lurker_spike()
            self.spike_count += 1

        # 가시 업데이트
        for spike in self.lurker_spikes[:]:
            spike['timer'] += 1
            spike['phase_timer'] += 1

            # 페이즈 진행: 올라옴 → 유지 → 내려감
            if spike['phase'] == 'rising':
                progress = min(1.0, spike['phase_timer'] / spike['rise_time'])
                spike['height'] = spike['max_height'] * self._ease_out_back(progress)

                if spike['phase_timer'] >= spike['rise_time']:
                    spike['phase'] = 'hold'
                    spike['phase_timer'] = 0

            elif spike['phase'] == 'hold':
                if spike['phase_timer'] >= spike['hold_time']:
                    spike['phase'] = 'falling'
                    spike['phase_timer'] = 0

            elif spike['phase'] == 'falling':
                progress = min(1.0, spike['phase_timer'] / spike['fall_time'])
                spike['height'] = spike['max_height'] * (1 - self._ease_in_quad(progress))

                if spike['phase_timer'] >= spike['fall_time']:
                    self.lurker_spikes.remove(spike)
                    continue

            elif spike['phase'] == 'dissolving':
                # 녹는 효과: 빠르게 투명해지면서 작아짐
                dissolve_time = 15  # 녹는 시간 (프레임)
                progress = min(1.0, spike['phase_timer'] / dissolve_time)
                spike['dissolve_alpha'] = int(255 * (1 - progress))
                spike['height'] = spike['max_height'] * (1 - progress * 0.5)  # 살짝 줄어듦
                spike['width'] = max(1, spike['width'] * (1 - progress * 0.3))  # 가늘어짐

                if spike['phase_timer'] >= dissolve_time:
                    self.lurker_spikes.remove(spike)
                    continue

            # 흔들림 효과
            spike['wobble'] = math.sin(spike['timer'] * 0.3 + spike['offset']) * 2

        # 연기 파티클 업데이트
        self._update_smoke_particles()

        # 파편 업데이트
        self._update_spike_fragments()

        # 모든 가시가 사라지면 스킬 종료
        if self.spike_count >= self.max_spikes and len(self.lurker_spikes) == 0 and len(self.spike_smoke_particles) == 0 and len(self.spike_fragments) == 0 and len(self.spike_sparkle_particles) == 0:
            self.dark_swamp_active = False

    def _spawn_lurker_spike(self):
        """럴커 가시 하나 생성 (플레이어 → 보스 방향으로 순차 발사)"""
        import random

        # 진행도 계산 (0 = 플레이어 위치, 1 = 보스 위치)
        progress = self.spike_count / max(1, self.max_spikes - 1)

        # Y 위치: 플레이어에서 보스 방향으로 진행
        spike_y = self.spike_start_y - (self.spike_start_y - self.spike_end_y) * progress

        # X 위치: 가로로 넓게 퍼지게 (좌우 번갈아가며)
        spread_offset = ((self.spike_count % 2) * 2 - 1) * (self.spike_count // 2 + 1) * 25
        spike_x = self.spike_start_x + spread_offset + random.randint(-10, 10)

        # X 범위 제한 (게임 영역 내)
        spike_x = max(100, min(660, spike_x))

        # 서브 크리스탈 데이터 생성 (각 가시마다 2-4개의 보조 크리스탈)
        num_sub = random.randint(2, 4)
        sub_crystals = []
        for si in range(num_sub):
            side = -1 if si % 2 == 0 else 1
            sub_crystals.append({
                'offset_x': side * random.randint(6, 18),
                'offset_y': random.uniform(0.1, 0.4),  # 메인 높이 대비 base 위치 비율
                'height_ratio': random.uniform(0.3, 0.6),  # 메인 대비 높이
                'width_ratio': random.uniform(0.5, 0.8),
                'angle': side * random.uniform(5, 20),  # 기울기 (도)
            })

        spike = {
            'x': spike_x,
            'y': spike_y,
            'height': 0,
            'max_height': random.randint(38, 63),  # 적절한 크기 (-30%)
            'width': random.randint(6, 10),  # 적절한 굵기 (-30%)
            'timer': 0,
            'phase': 'rising',
            'phase_timer': 0,
            'rise_time': 10,  # 올라오는 시간
            'hold_time': 35,  # 유지 시간
            'fall_time': 15,  # 내려가는 시간
            'offset': random.uniform(0, 6.28),
            'wobble': 0,
            'hit_ball': False,
            'hit_boss': False,
            'color_shift': random.uniform(0, 1),
            'sub_crystals': sub_crystals,  # 보조 크리스탈 데이터
        }

        self.lurker_spikes.append(spike)

        # 🔊 가시 생성 사운드 재생
        try:
            import pygame
            import os
            sound_path = resource_path(os.path.join("sounds", "odinspirit.wav"))
            if os.path.exists(sound_path):
                spike_sound = pygame.mixer.Sound(sound_path)
                spike_sound.set_volume(0.5)  # 볼륨 50% (여러 개 연속 재생되므로)
                spike_sound.play()
        except Exception as e:
            if LEGENDARY_DEBUG_ENABLED:
                print(f"🔊 가시 사운드 재생 실패: {e}")

        # 연기 파티클 생성
        self._spawn_smoke_particles(spike_x, spike_y)

    def _spawn_smoke_particles(self, x: int, y: int):
        """가시 스폰 시 어둠의 연기 파티클 생성 (고퀄리티)"""
        import random
        import math

        # 바닥 연기 - 넓게 퍼지는 어두운 연기 (12개)
        for _ in range(12):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(5, 35)
            particle = {
                'x': x + math.cos(angle) * dist,
                'y': y + random.randint(-3, 8),
                'vx': math.cos(angle) * random.uniform(0.5, 2.0),
                'vy': random.uniform(-1.8, -0.3),
                'size': random.randint(12, 28),
                'alpha': random.randint(160, 240),
                'life': random.randint(30, 55),
                'max_life': 55,
                'color_shift': random.uniform(0, 1),
                'type': 'ground'  # 바닥 연기
            }
            self.spike_smoke_particles.append(particle)

        # 상승 연기 - 가시를 따라 올라가는 연기 (5개)
        for _ in range(5):
            particle = {
                'x': x + random.randint(-8, 8),
                'y': y + random.randint(-10, 0),
                'vx': random.uniform(-0.5, 0.5),
                'vy': random.uniform(-3.5, -1.5),
                'size': random.randint(6, 14),
                'alpha': random.randint(120, 180),
                'life': random.randint(20, 35),
                'max_life': 35,
                'color_shift': random.uniform(0.3, 1.0),
                'type': 'rising'  # 상승 연기
            }
            self.spike_smoke_particles.append(particle)

        # 스파클 파티클 생성 (가시 주변 반짝임)
        for _ in range(6):
            angle = random.uniform(0, math.pi * 2)
            dist = random.uniform(10, 40)
            self.spike_sparkle_particles.append({
                'x': x + math.cos(angle) * dist,
                'y': y - random.uniform(10, 60),
                'vx': random.uniform(-0.3, 0.3),
                'vy': random.uniform(-0.8, -0.2),
                'size': random.uniform(1.5, 3.5),
                'alpha': random.randint(180, 255),
                'life': random.randint(20, 50),
                'max_life': 50,
                'twinkle_speed': random.uniform(0.15, 0.35),
                'twinkle_offset': random.uniform(0, 6.28),
            })

    def _update_smoke_particles(self):
        """연기 파티클 업데이트"""
        for particle in self.spike_smoke_particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            p_type = particle.get('type', 'ground')
            if p_type == 'ground':
                particle['vy'] += 0.03  # 바닥 연기는 느리게 상승
                particle['vx'] *= 0.97  # 수평 감속
                particle['size'] += 0.4  # 더 크게 퍼짐
            else:
                particle['vy'] += 0.02
                particle['size'] += 0.2
            particle['life'] -= 1
            particle['alpha'] = int(particle['alpha'] * 0.91)

            if particle['life'] <= 0 or particle['alpha'] < 8:
                self.spike_smoke_particles.remove(particle)

        # 스파클 파티클 업데이트
        for sp in self.spike_sparkle_particles[:]:
            sp['x'] += sp['vx']
            sp['y'] += sp['vy']
            sp['life'] -= 1
            sp['alpha'] = int(255 * (sp['life'] / sp['max_life']))
            if sp['life'] <= 0 or sp['alpha'] < 5:
                self.spike_sparkle_particles.remove(sp)

    def _ease_out_back(self, t: float) -> float:
        """이징 함수 - 튀어나오는 효과"""
        c1 = 1.70158
        c3 = c1 + 1
        return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)

    def _ease_in_quad(self, t: float) -> float:
        """이징 함수 - 가속"""
        return t * t

    def draw_lurker_spikes(self, screen):
        """럴커 가시 그리기 (고퀄리티 크리스탈 스타일)"""
        if not self.dark_swamp_active and len(self.lurker_spikes) == 0 and len(self.spike_smoke_particles) == 0 and len(self.spike_fragments) == 0 and len(self.spike_sparkle_particles) == 0:
            return

        import pygame
        import math

        for spike in self.lurker_spikes:
            if spike['height'] <= 0:
                continue

            x = int(spike['x'] + spike['wobble'])
            base_y = int(spike['y'])
            h = int(spike['height'])
            w = int(spike['width'])
            timer = spike['timer']

            is_dissolving = spike['phase'] == 'dissolving'
            alpha = spike.get('dissolve_alpha', 255) if is_dissolving else 255
            if alpha <= 0:
                continue

            # ─── 서페이스 준비 (모든 렌더링을 하나의 서페이스에) ───
            pad_x = 50  # 바닥 연기/그림자용 좌우 여유
            pad_top = 22  # 팁 글로우용 상단 여유
            pad_bot = 18  # 바닥 효과용 하단 여유
            surf_w = pad_x * 2
            surf_h = h + pad_top + pad_bot
            cx = pad_x  # 서페이스 내 가시 중앙 X
            by = h + pad_top  # 서페이스 내 가시 바닥 Y

            spike_surf = pygame.Surface((surf_w, surf_h), pygame.SRCALPHA)

            # ─── 1. 바닥 그라운드 이펙트 (어두운 원형 그림자/웅덩이) ───
            ground_pulse = 0.85 + 0.15 * math.sin(timer * 0.08)
            # 큰 어두운 타원 (그림자 풀)
            ground_w = int((w * 3 + 14) * ground_pulse)
            ground_h = int(9 * ground_pulse)
            ground_surf = pygame.Surface((ground_w * 2, ground_h * 2), pygame.SRCALPHA)
            # 바깥 레이어 (매우 어두운 보라)
            pygame.draw.ellipse(ground_surf, (15, 5, 25, int(alpha * 0.5)),
                                (0, 0, ground_w * 2, ground_h * 2))
            # 중간 레이어
            inner_w = int(ground_w * 0.7)
            inner_h = int(ground_h * 0.7)
            pygame.draw.ellipse(ground_surf, (30, 10, 50, int(alpha * 0.7)),
                                (ground_w - inner_w, ground_h - inner_h, inner_w * 2, inner_h * 2))
            # 안쪽 코어 (보라 빛)
            core_w = int(ground_w * 0.35)
            core_h = int(ground_h * 0.4)
            pygame.draw.ellipse(ground_surf, (80, 30, 120, int(alpha * 0.4)),
                                (ground_w - core_w, ground_h - core_h, core_w * 2, core_h * 2))
            spike_surf.blit(ground_surf, (cx - ground_w, by - ground_h))

            # ─── 2. 서브 크리스탈 (보조 가시들) ───
            sub_crystals = spike.get('sub_crystals', [])
            for sc in sub_crystals:
                sc_x = cx + sc['offset_x']
                sc_base_y = by - int(h * sc['offset_y'])
                sc_h = int(h * sc['height_ratio'])
                sc_w = int(w * sc['width_ratio'])
                if sc_h <= 2 or sc_w <= 1:
                    continue

                angle_rad = math.radians(sc['angle'])

                # 서브 크리스탈 꼭지점 (기울어진 크리스탈)
                tip_x = sc_x + int(math.sin(angle_rad) * sc_h * 0.3)
                tip_y = sc_base_y - sc_h

                sub_points = [
                    (sc_x - sc_w, sc_base_y),
                    (sc_x + sc_w, sc_base_y),
                    (sc_x + int(sc_w * 0.4) + int(math.sin(angle_rad) * sc_h * 0.15), sc_base_y - int(sc_h * 0.6)),
                    (tip_x, tip_y),
                    (sc_x - int(sc_w * 0.4) + int(math.sin(angle_rad) * sc_h * 0.15), sc_base_y - int(sc_h * 0.6)),
                ]

                # 서브 크리스탈 색상 (메인보다 약간 어둡게)
                sub_base = (100, 45, 135, alpha)
                sub_dark = (65, 25, 95, alpha)
                sub_highlight = (155, 80, 200, alpha)

                if is_dissolving:
                    blend = 1 - (alpha / 255)
                    sub_base = (min(255, int(100 + 80 * blend)), min(255, int(45 + 40 * blend)), min(255, int(135 + 60 * blend)), alpha)
                    sub_dark = (min(255, int(65 + 60 * blend)), min(255, int(25 + 30 * blend)), min(255, int(95 + 50 * blend)), alpha)
                    sub_highlight = (min(255, int(155 + 50 * blend)), min(255, int(80 + 80 * blend)), min(255, int(200 + 35 * blend)), alpha)

                # 서브 그림자
                shadow_offset = 3
                shadow_pts = [(p[0] + shadow_offset, p[1] + shadow_offset) for p in sub_points]
                pygame.draw.polygon(spike_surf, (10, 5, 18, int(alpha * 0.3)), shadow_pts)

                # 서브 메인 폴리곤
                pygame.draw.polygon(spike_surf, sub_base, sub_points)

                # 서브 어두운 면
                if len(sub_points) >= 5:
                    right_pts = [sub_points[1], sub_points[2], sub_points[3],
                                 (sc_x + int(sc_w * 0.2), sc_base_y - int(sc_h * 0.4))]
                    pygame.draw.polygon(spike_surf, sub_dark, right_pts)

                    # 서브 밝은 면
                    left_pts = [sub_points[0], sub_points[4], sub_points[3],
                                (sc_x - int(sc_w * 0.2), sc_base_y - int(sc_h * 0.4))]
                    pygame.draw.polygon(spike_surf, sub_highlight, left_pts)

                # 서브 테두리 (은은한 글로우)
                pygame.draw.polygon(spike_surf, (170, 100, 230, int(alpha * 0.6)), sub_points, 1)

                # 서브 팁 글로우 (작은)
                if not is_dissolving:
                    sg_size = int(4 + math.sin(timer * 0.25 + sc['offset_x']) * 1.5)
                    sg_surf = pygame.Surface((sg_size * 2, sg_size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(sg_surf, (180, 100, 255, 90), (sg_size, sg_size), sg_size)
                    pygame.draw.circle(sg_surf, (230, 170, 255, 60), (sg_size, sg_size), max(1, sg_size // 2))
                    spike_surf.blit(sg_surf, (tip_x - sg_size, tip_y - sg_size))

            # ─── 3. 메인 크리스탈 (중앙 대형 가시) ───
            # 색상 정의
            base_color = (130, 55, 165)
            dark_color = (75, 30, 105)
            mid_color = (150, 75, 190)
            highlight_color = (195, 110, 235)
            edge_color = (210, 140, 255)

            if is_dissolving:
                blend = 1 - (alpha / 255)
                base_color = (min(255, int(130 + 80 * blend)), min(255, int(55 + 50 * blend)), min(255, int(165 + 50 * blend)))
                dark_color = (min(255, int(75 + 70 * blend)), min(255, int(30 + 40 * blend)), min(255, int(105 + 60 * blend)))
                mid_color = (min(255, int(150 + 60 * blend)), min(255, int(75 + 60 * blend)), min(255, int(190 + 40 * blend)))
                highlight_color = (min(255, int(195 + 40 * blend)), min(255, int(110 + 70 * blend)), min(255, int(235 + 20 * blend)))

            # 메인 크리스탈 폴리곤 (7점 - 더 복잡한 크리스탈 형태)
            # 바닥 넓고 → 중간에 각진 부분 → 뾰족한 꼭대기
            jag1 = int(w * 0.15 * math.sin(timer * 0.12))  # 미세한 흔들림
            main_points = [
                (cx - w - 2, by),                          # 왼쪽 아래
                (cx + w + 2, by),                          # 오른쪽 아래
                (cx + int(w * 0.8), by - int(h * 0.35)),   # 오른쪽 하단 각
                (cx + int(w * 0.5) + jag1, by - int(h * 0.65)),  # 오른쪽 상단 각
                (cx, by - h),                              # 꼭대기
                (cx - int(w * 0.5) - jag1, by - int(h * 0.65)),  # 왼쪽 상단 각
                (cx - int(w * 0.8), by - int(h * 0.35)),   # 왼쪽 하단 각
            ]

            # 메인 그림자
            shadow_pts = [(p[0] + 4, p[1] + 4) for p in main_points]
            pygame.draw.polygon(spike_surf, (10, 5, 18, int(alpha * 0.4)), shadow_pts)

            # 메인 크리스탈 채우기
            pygame.draw.polygon(spike_surf, (*base_color, alpha), main_points)

            # 오른쪽 어두운 면 (3D 입체감)
            right_face = [
                main_points[1],  # 오른쪽 아래
                main_points[2],  # 오른쪽 하단 각
                main_points[3],  # 오른쪽 상단 각
                main_points[4],  # 꼭대기
                (cx + int(w * 0.15), by - int(h * 0.5)),  # 내부 중심
                (cx + int(w * 0.1), by),  # 내부 아래
            ]
            pygame.draw.polygon(spike_surf, (*dark_color, alpha), right_face)

            # 왼쪽 밝은 면 (하이라이트)
            left_face = [
                main_points[0],  # 왼쪽 아래
                main_points[6],  # 왼쪽 하단 각
                main_points[5],  # 왼쪽 상단 각
                main_points[4],  # 꼭대기
                (cx - int(w * 0.15), by - int(h * 0.5)),  # 내부 중심
                (cx - int(w * 0.1), by),  # 내부 아래
            ]
            pygame.draw.polygon(spike_surf, (*highlight_color, alpha), left_face)

            # 중앙 하이라이트 스트라이프 (크리스탈 광택)
            if not is_dissolving and h > 20:
                stripe_points = [
                    (cx - int(w * 0.15), by - int(h * 0.1)),
                    (cx + int(w * 0.08), by - int(h * 0.1)),
                    (cx + int(w * 0.12), by - int(h * 0.7)),
                    (cx, by - h + 3),
                    (cx - int(w * 0.1), by - int(h * 0.7)),
                ]
                pygame.draw.polygon(spike_surf, (*mid_color, int(alpha * 0.6)), stripe_points)

            # 외곽선 (은은한 글로우 라인)
            pygame.draw.polygon(spike_surf, (*edge_color, int(alpha * 0.7)), main_points, 2)

            # 내부 에지 라인 (크리스탈 결)
            if not is_dissolving and h > 25:
                # 가로 결
                for frac in [0.3, 0.55]:
                    ly = by - int(h * frac)
                    lx1 = cx - int(w * (1 - frac * 0.6))
                    lx2 = cx + int(w * (1 - frac * 0.6))
                    pygame.draw.line(spike_surf, (*edge_color, int(alpha * 0.25)),
                                     (lx1, ly), (lx2, ly), 1)

            # ─── 4. 팁 글로우 (빛나는 구체) ───
            if not is_dissolving:
                pulse = 0.8 + 0.2 * math.sin(timer * 0.15)
                # 외부 글로우 (큰 보라 후광)
                g1 = int(13 * pulse)
                g1_surf = pygame.Surface((g1 * 2, g1 * 2), pygame.SRCALPHA)
                pygame.draw.circle(g1_surf, (140, 60, 220, 50), (g1, g1), g1)
                spike_surf.blit(g1_surf, (cx - g1, by - h - g1))

                # 중간 글로우 (밝은 보라)
                g2 = int(8 * pulse)
                g2_surf = pygame.Surface((g2 * 2, g2 * 2), pygame.SRCALPHA)
                pygame.draw.circle(g2_surf, (190, 120, 255, 100), (g2, g2), g2)
                spike_surf.blit(g2_surf, (cx - g2, by - h - g2))

                # 내부 코어 (밝은 핑크/화이트)
                g3 = int(4 * pulse)
                g3_surf = pygame.Surface((g3 * 2, g3 * 2), pygame.SRCALPHA)
                pygame.draw.circle(g3_surf, (230, 180, 255, 180), (g3, g3), g3)
                pygame.draw.circle(g3_surf, (255, 220, 255, 220), (g3, g3), max(1, g3 // 2))
                spike_surf.blit(g3_surf, (cx - g3, by - h - g3))

            # ─── 서페이스를 화면에 블릿 ───
            screen.blit(spike_surf, (x - cx, base_y - by))

        # 연기 파티클 그리기
        self._draw_smoke_particles(screen)

        # 스파클 파티클 그리기
        self._draw_sparkle_particles(screen)

        # 파편 그리기
        self._draw_spike_fragments(screen)

    def _draw_smoke_particles(self, screen):
        """어둠의 연기 파티클 그리기 (고퀄리티)"""
        import pygame

        for particle in self.spike_smoke_particles:
            if particle['alpha'] <= 0:
                continue

            size = int(particle['size'])
            alpha = min(255, max(0, int(particle['alpha'])))
            p_type = particle.get('type', 'ground')

            color_shift = particle['color_shift']

            if p_type == 'ground':
                # 바닥 연기: 더 어둡고 넓은 보라/검정
                r = int(20 + color_shift * 25)
                g = int(8 + color_shift * 12)
                b = int(35 + color_shift * 30)
            else:
                # 상승 연기: 약간 밝은 보라
                r = int(50 + color_shift * 30)
                g = int(20 + color_shift * 15)
                b = int(60 + color_shift * 35)

            smoke_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)

            # 4겹 레이어로 부드러운 연기 (바깥→안쪽 더 진하게)
            for i in range(4):
                layer_size = size - i * max(1, size // 5)
                if layer_size > 0:
                    layer_alpha = int(alpha * (0.3 + i * 0.15))
                    layer_alpha = min(255, layer_alpha)
                    pygame.draw.circle(smoke_surf, (r, g, b, layer_alpha),
                                       (size, size), layer_size)

            # 바닥 연기에 보라빛 글로우 추가
            if p_type == 'ground' and alpha > 60:
                glow_size = max(1, size // 3)
                pygame.draw.circle(smoke_surf, (80, 30, 120, alpha // 4),
                                   (size, size), glow_size)

            screen.blit(smoke_surf, (int(particle['x']) - size, int(particle['y']) - size))

    def _draw_sparkle_particles(self, screen):
        """가시 주변 스파클(반짝임) 파티클 그리기"""
        import pygame
        import math

        for sp in self.spike_sparkle_particles:
            if sp['alpha'] <= 0:
                continue

            # 반짝임 효과 (sin 파형으로 밝기 변화)
            twinkle = 0.5 + 0.5 * math.sin(sp['life'] * sp['twinkle_speed'] + sp['twinkle_offset'])
            visible_alpha = int(sp['alpha'] * twinkle)
            if visible_alpha <= 5:
                continue

            size = sp['size']
            px = int(sp['x'])
            py = int(sp['y'])

            # 작은 빛나는 점 (코어 + 글로우)
            sp_size = max(2, int(size * 2 + 4))
            sp_surf = pygame.Surface((sp_size * 2, sp_size * 2), pygame.SRCALPHA)
            center = sp_size

            # 외부 글로우 (보라)
            pygame.draw.circle(sp_surf, (160, 80, 230, int(visible_alpha * 0.3)),
                               (center, center), sp_size)
            # 중간 (밝은 보라)
            mid_r = max(1, int(size * 1.2))
            pygame.draw.circle(sp_surf, (200, 140, 255, int(visible_alpha * 0.6)),
                               (center, center), mid_r)
            # 코어 (화이트)
            core_r = max(1, int(size * 0.6))
            pygame.draw.circle(sp_surf, (240, 220, 255, visible_alpha),
                               (center, center), core_r)

            screen.blit(sp_surf, (px - center, py - center))

    def _spawn_spike_fragments(self, x: int, y: int, spike_height: int):
        """가시 타격 시 어둠의 파편 생성"""
        import random
        import math

        # 파편 개수 (가시 크기에 비례)
        num_fragments = int(8 + spike_height // 10)

        for i in range(num_fragments):
            # 방사형으로 퍼지는 각도
            angle = (i / num_fragments) * math.pi * 2 + random.uniform(-0.3, 0.3)
            speed = random.uniform(3, 8)

            fragment = {
                'x': x + random.randint(-10, 10),
                'y': y + random.randint(-spike_height // 2, 0),
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - 2,  # 약간 위로
                'size': random.randint(4, 10),
                'alpha': 255,
                'life': random.randint(30, 50),
                'rotation': random.uniform(0, math.pi * 2),
                'rot_speed': random.uniform(-0.3, 0.3),
                'color_shift': random.uniform(0, 1),
                'shape': random.choice(['triangle', 'diamond', 'shard'])
            }
            self.spike_fragments.append(fragment)

    def _update_spike_fragments(self):
        """파편 업데이트"""
        for fragment in self.spike_fragments[:]:
            fragment['x'] += fragment['vx']
            fragment['y'] += fragment['vy']
            fragment['vy'] += 0.25  # 중력
            fragment['vx'] *= 0.98  # 공기 저항
            fragment['rotation'] += fragment['rot_speed']
            fragment['life'] -= 1
            fragment['alpha'] = int(255 * (fragment['life'] / 50))
            fragment['size'] = max(1, fragment['size'] * 0.97)  # 점점 작아짐

            if fragment['life'] <= 0 or fragment['alpha'] < 10:
                self.spike_fragments.remove(fragment)

    def _draw_spike_fragments(self, screen):
        """어둠의 파편 그리기"""
        import pygame
        import math

        for fragment in self.spike_fragments:
            if fragment['alpha'] <= 0:
                continue

            x = int(fragment['x'])
            y = int(fragment['y'])
            size = int(fragment['size'])
            alpha = min(255, max(0, int(fragment['alpha'])))
            rotation = fragment['rotation']

            # 파편 색상 (어두운 보라/자주)
            color_shift = fragment['color_shift']
            r = int(100 + color_shift * 50)
            g = int(40 + color_shift * 30)
            b = int(130 + color_shift * 40)

            # 서페이스 생성
            frag_surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
            center = size * 3 // 2

            # 파편 모양에 따라 그리기
            if fragment['shape'] == 'triangle':
                points = []
                for i in range(3):
                    angle = rotation + (i * 2 * math.pi / 3)
                    px = center + math.cos(angle) * size
                    py = center + math.sin(angle) * size
                    points.append((px, py))
                pygame.draw.polygon(frag_surf, (r, g, b, alpha), points)
                # 밝은 테두리
                pygame.draw.polygon(frag_surf, (r + 50, g + 30, b + 30, alpha // 2), points, 1)

            elif fragment['shape'] == 'diamond':
                points = [
                    (center, center - size),
                    (center + size * 0.7, center),
                    (center, center + size),
                    (center - size * 0.7, center)
                ]
                # 회전 적용
                rotated_points = []
                for px, py in points:
                    dx = px - center
                    dy = py - center
                    rx = dx * math.cos(rotation) - dy * math.sin(rotation) + center
                    ry = dx * math.sin(rotation) + dy * math.cos(rotation) + center
                    rotated_points.append((rx, ry))
                pygame.draw.polygon(frag_surf, (r, g, b, alpha), rotated_points)
                pygame.draw.polygon(frag_surf, (r + 50, g + 30, b + 30, alpha // 2), rotated_points, 1)

            else:  # shard - 날카로운 파편
                points = [
                    (center, center - size * 1.2),
                    (center + size * 0.4, center),
                    (center, center + size * 0.5),
                    (center - size * 0.4, center)
                ]
                rotated_points = []
                for px, py in points:
                    dx = px - center
                    dy = py - center
                    rx = dx * math.cos(rotation) - dy * math.sin(rotation) + center
                    ry = dx * math.sin(rotation) + dy * math.cos(rotation) + center
                    rotated_points.append((rx, ry))
                pygame.draw.polygon(frag_surf, (r, g, b, alpha), rotated_points)
                # 글로우 효과
                glow_surf = pygame.Surface((size * 3, size * 3), pygame.SRCALPHA)
                pygame.draw.polygon(glow_surf, (r, g, b, alpha // 3), rotated_points)
                screen.blit(glow_surf, (x - center - 2, y - center - 2))

            screen.blit(frag_surf, (x - center, y - center))

    def check_spike_ball_collision(self, ball_rect, ball_vx: float = 0, ball_vy: float = 0) -> dict:
        """가시-공 충돌 체크. 충돌 시 공에 적용할 효과 반환

        Args:
            ball_rect: 공의 Rect
            ball_vx: 공의 현재 X 속도 (패들 수준 물리 적용용)
            ball_vy: 공의 현재 Y 속도 (패들 수준 물리 적용용)
        """
        import pygame
        import math
        import random

        result = {
            'hit': False,
            'force_x': 0,
            'force_y': 0,
            'new_vx': None,  # None이면 force 방식 사용, 값 있으면 직접 설정
            'new_vy': None
        }

        for spike in self.lurker_spikes:
            if spike['hit_ball']:
                continue
            if spike['phase'] != 'hold' and spike['phase'] != 'rising':
                continue
            if spike['height'] < 10:
                continue

            # 가시 히트박스
            spike_rect = pygame.Rect(
                spike['x'] - spike['width'] - 5,
                spike['y'] - spike['height'],
                spike['width'] * 2 + 10,
                spike['height']
            )

            if spike_rect.colliderect(ball_rect):
                spike['hit_ball'] = True
                result['hit'] = True

                # 패들 수준의 물리 적용 (속도 정보가 있는 경우)
                current_speed = math.hypot(ball_vx, ball_vy) if (ball_vx != 0 or ball_vy != 0) else 0

                if current_speed > 3.0:
                    # 패들과 동일한 반사 물리 적용
                    if current_speed < 8.0:
                        current_speed = 10.0  # 최소 속도 보장

                    # 히트 위치에 따른 각도 계산 (가시 너비 기준)
                    spike_half_w = spike['width'] + 2.5
                    hit_offset = (ball_rect.centerx - spike['x']) / spike_half_w if spike_half_w > 0 else 0
                    hit_offset = max(-1.0, min(1.0, hit_offset))
                    angle = hit_offset * (math.pi / 4)  # 최대 ±45도

                    # 속도 부스트 적용 (패들처럼 1.4~1.7배 가속)
                    speed_boost = random.uniform(1.4, 1.7)
                    boosted_speed = current_speed * speed_boost

                    # 항상 위로 반사 (보스 방향)
                    cos_a = math.cos(angle)
                    sin_a = math.sin(angle)
                    # 회전 행렬: [cos -sin; sin cos] * [0; -1]
                    vec_x = sin_a  # -(-1) * sin_a
                    vec_y = -cos_a  # -1 * cos_a

                    result['new_vx'] = boosted_speed * vec_x
                    result['new_vy'] = boosted_speed * vec_y

                    print(f"👁 [가시] 공 타격! 속도:{current_speed:.1f}→{boosted_speed:.1f} 부스트:{speed_boost:.2f}x 각도:{math.degrees(angle):.1f}°")
                else:
                    # 폴백: 기존 방식 (고정 힘)
                    result['force_y'] = -12  # 기존 -8에서 강화
                    if ball_rect.centerx < spike['x']:
                        result['force_x'] = -5  # 기존 -3에서 강화
                    else:
                        result['force_x'] = 5
                    print(f"👁 [가시] 공 타격! force=({result['force_x']}, {result['force_y']})")

                # 녹는 효과 시작 및 파편 생성
                spike['phase'] = 'dissolving'
                spike['phase_timer'] = 0
                spike['dissolve_alpha'] = 255
                self._spawn_spike_fragments(int(spike['x']), int(spike['y'] - spike['height'] // 2), int(spike['height']))

                break

        return result

    def check_spike_boss_collision(self, boss_rect) -> dict:
        """가시-보스 충돌 체크. 충돌 시 넉백/스턴 정보 반환"""
        import pygame

        result = {
            'hit': False,
            'knockback_direction': 0,  # -1=왼쪽, 1=오른쪽
            'knockback_power': 0,
            'stun_duration': 0  # 프레임 단위
        }

        for spike in self.lurker_spikes:
            if spike['hit_boss']:
                continue
            if spike['phase'] != 'hold' and spike['phase'] != 'rising':
                continue
            if spike['height'] < 20:
                continue

            # 가시 히트박스 (끝부분)
            spike_tip_rect = pygame.Rect(
                spike['x'] - spike['width'] - 3,
                spike['y'] - spike['height'] - 5,
                spike['width'] * 2 + 6,
                15
            )

            if spike_tip_rect.colliderect(boss_rect):
                spike['hit_boss'] = True
                result['hit'] = True

                # 넉백 방향 결정 (가시가 보스의 어느 쪽을 맞췄는지)
                if spike['x'] < boss_rect.centerx:
                    result['knockback_direction'] = 1  # 오른쪽으로 밀림
                else:
                    result['knockback_direction'] = -1  # 왼쪽으로 밀림

                result['knockback_power'] = 25  # 넉백 강도
                result['stun_duration'] = 60  # 1초 스턴

                # 녹는 효과 시작 및 파편 생성
                spike['phase'] = 'dissolving'
                spike['phase_timer'] = 0
                spike['dissolve_alpha'] = 255
                self._spawn_spike_fragments(int(spike['x']), int(spike['y'] - spike['height']), int(spike['height']))

                print(f"👁 [가시] 보스 타격! 방향={result['knockback_direction']}, 스턴=1초")
                break

        return result

    def spawn_dark_fragments(self, x: int, y: int, count: int = 12):
        """어둠 파편 이펙트 생성 (가시-보스 충돌 시)"""
        import random
        import math

        for _ in range(count):
            # 360도 방향으로 퍼지는 파편
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(3, 8)
            size = random.uniform(3, 8)

            fragment = {
                'x': x + random.uniform(-10, 10),
                'y': y + random.uniform(-10, 10),
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed - random.uniform(1, 3),  # 약간 위로
                'size': size,
                'life': random.randint(30, 50),
                'max_life': random.randint(30, 50),
                'color_type': random.choice(['purple', 'dark', 'red']),
                'rotation': random.uniform(0, 360),
                'rotation_speed': random.uniform(-10, 10),
                'gravity': 0.15
            }
            self.dark_fragments.append(fragment)

    def update_dark_fragments(self):
        """어둠 파편 업데이트"""
        for frag in self.dark_fragments[:]:
            frag['x'] += frag['vx']
            frag['y'] += frag['vy']
            frag['vy'] += frag['gravity']  # 중력 적용
            frag['vx'] *= 0.98  # 공기 저항
            frag['rotation'] += frag['rotation_speed']
            frag['life'] -= 1

            if frag['life'] <= 0:
                self.dark_fragments.remove(frag)

    def draw_dark_fragments(self, screen):
        """어둠 파편 그리기"""
        import pygame

        for frag in self.dark_fragments:
            alpha = int(255 * (frag['life'] / frag['max_life']))
            size = int(frag['size'] * (0.5 + 0.5 * (frag['life'] / frag['max_life'])))

            if size < 1:
                continue

            # 색상 선택
            if frag['color_type'] == 'purple':
                base_color = (120, 40, 180)
            elif frag['color_type'] == 'dark':
                base_color = (30, 20, 40)
            else:  # red
                base_color = (150, 30, 50)

            # 파편 표면 생성
            surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)

            # 회전된 다이아몬드/파편 모양
            import math
            rad = math.radians(frag['rotation'])
            points = []
            for i in range(4):
                a = rad + i * math.pi / 2
                px = size + math.cos(a) * size * 0.8
                py = size + math.sin(a) * size * 0.6
                points.append((px, py))

            color_with_alpha = (*base_color, alpha)
            pygame.draw.polygon(surf, color_with_alpha, points)

            # 글로우 효과
            glow_color = (*base_color, alpha // 3)
            pygame.draw.polygon(surf, glow_color, points, 2)

            screen.blit(surf, (int(frag['x']) - size, int(frag['y']) - size))

    def draw_dark_swamp_skill_orb(self, screen, orb_x: int, orb_y: int, current_gauge: float):
        """어둠의 늪 스킬 구슬 그리기 (왼쪽 필러)"""
        if not self.dark_swamp_enabled or not self.is_transformed():
            self.dark_swamp_orb_rect = None
            return

        import pygame
        import math

        orb_radius = 22
        t = self.animation_time * 2

        # 쿨타임 비율
        cooldown_ratio = self.get_dark_swamp_cooldown_ratio()
        can_use = self.can_use_dark_swamp(current_gauge)
        is_on_cooldown = cooldown_ratio > 0

        # 아이콘 rect 저장 (툴팁 충돌 검사용)
        self.dark_swamp_orb_rect = pygame.Rect(
            orb_x - orb_radius, orb_y - orb_radius,
            orb_radius * 2, orb_radius * 2
        )

        # 배경 오라
        for i in range(3):
            aura_r = orb_radius + 8 - i * 3
            aura_alpha = 40 + i * 20 if can_use else 20 + i * 10
            aura_surf = pygame.Surface((aura_r * 2, aura_r * 2), pygame.SRCALPHA)
            color = (60, 30, 90, aura_alpha) if can_use else (30, 15, 45, aura_alpha)
            pygame.draw.circle(aura_surf, color, (aura_r, aura_r), aura_r)
            screen.blit(aura_surf, (orb_x - aura_r, orb_y - aura_r))

        # 구슬 배경
        bg_color = (20, 10, 35) if can_use else (15, 8, 20)
        pygame.draw.circle(screen, bg_color, (orb_x, orb_y), orb_radius)

        # 가시 아이콘 (스킬 심볼) - 쿨타임/비활성 시 어두운 색
        spike_color = (180, 100, 220) if can_use else (80, 50, 100)
        # 중앙 가시
        pygame.draw.polygon(screen, spike_color, [
            (orb_x, orb_y - 12),
            (orb_x - 4, orb_y + 6),
            (orb_x + 4, orb_y + 6)
        ])
        # 좌우 작은 가시
        for side in [-1, 1]:
            pygame.draw.polygon(screen, spike_color, [
                (orb_x + side * 8, orb_y - 6),
                (orb_x + side * 5, orb_y + 4),
                (orb_x + side * 11, orb_y + 4)
            ])

        # 테두리 (활성: 밝은 보라, 비활성: 어두운 회색)
        border_color = (120, 60, 160) if can_use else (60, 40, 60)
        pygame.draw.circle(screen, border_color, (orb_x, orb_y), orb_radius, 2)

        # 쿨타임 오버레이 (부채꼴 방식 - 다른 스킬과 동일)
        if is_on_cooldown:
            cd_diameter = orb_radius * 2 + 4
            cd_surface = pygame.Surface((cd_diameter, cd_diameter), pygame.SRCALPHA)
            cd_center = cd_diameter // 2

            start_angle = -math.pi / 2  # 12시 방향
            end_angle = start_angle + (2 * math.pi * cooldown_ratio)

            if cooldown_ratio > 0.01:
                points = [(cd_center, cd_center)]
                num_segments = max(3, int(36 * cooldown_ratio))
                for j in range(num_segments + 1):
                    angle = start_angle + (end_angle - start_angle) * j / num_segments
                    px = cd_center + int(math.cos(angle) * orb_radius)
                    py = cd_center + int(math.sin(angle) * orb_radius)
                    points.append((px, py))

                if len(points) >= 3:
                    pygame.draw.polygon(cd_surface, (0, 0, 0, 180), points)

            screen.blit(cd_surface, (orb_x - cd_diameter // 2, orb_y - cd_diameter // 2))

        # 사용 가능 시 펄스 효과
        if can_use:
            pulse = (math.sin(t * 3) + 1) / 2
            pulse_r = orb_radius + int(pulse * 4)
            pulse_surf = pygame.Surface((pulse_r * 2 + 4, pulse_r * 2 + 4), pygame.SRCALPHA)
            pygame.draw.circle(pulse_surf, (150, 80, 200, int(60 * pulse)),
                             (pulse_r + 2, pulse_r + 2), pulse_r, 2)
            screen.blit(pulse_surf, (orb_x - pulse_r - 2, orb_y - pulse_r - 2))

    def _draw_dark_paddle_disabled(self, screen, paddle_rect, player_vx: float = 0):
        """[비활성화됨] 이전 어둠의 패들 코드"""
        if not self.penalty_active and not self.dark_energy_active:
            return None

        import pygame
        import math
        import random

        pw = paddle_rect.width   # ~155
        ph = paddle_rect.height  # ~50

        # 여백 없이 패들 크기 그대로
        surface = pygame.Surface((pw, ph), pygame.SRCALPHA)
        cx = pw // 2
        cy = ph // 2

        # 애니메이션
        t = self.animation_time * 2.0
        pulse = (math.sin(t * 2) + 1) / 2
        wave = math.sin(t * 1.5) * 1.5

        # 이동 효과
        lean = player_vx * 0.02

        # 색상
        body_color = (15, 12, 18, 230)
        edge_color = (30, 25, 38, 180)

        # ═══════════════════════════════════════════════════════════════
        # 1. 메인 바디 (패들 영역에 딱 맞는 가로 타원)
        # ═══════════════════════════════════════════════════════════════
        body_w = pw - 10
        body_h = ph - 6
        body_points = []
        for i in range(20):
            angle = (i / 20) * 2 * math.pi
            noise = math.sin(angle * 5 + t * 3) * 1.5
            rx = body_w / 2 + noise
            ry = body_h / 2 + noise * 0.3
            bx = cx + math.cos(angle + lean) * rx
            by = cy + math.sin(angle) * ry + wave * 0.3
            body_points.append((int(bx), int(by)))

        pygame.draw.polygon(surface, body_color, body_points)

        # ═══════════════════════════════════════════════════════════════
        # 2. 황금 눈 (중앙)
        # ═══════════════════════════════════════════════════════════════
        eye_x = cx + int(player_vx * 0.03)
        eye_y = cy

        # 눈 글로우 (작게)
        for i in range(2):
            gr = 6 - i * 2 + int(pulse * 2)
            ga = 50 - i * 20
            glow_surf = pygame.Surface((gr * 2, gr * 2), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (200, 160, 60, ga), (gr, gr), gr)
            surface.blit(glow_surf, (int(eye_x - gr), int(eye_y - gr)))

        # 눈 흰자위
        eye_w = 10 + int(pulse)
        eye_h = 6
        pygame.draw.ellipse(surface, (230, 225, 210),
                           (eye_x - eye_w // 2, eye_y - eye_h // 2, eye_w, eye_h))

        # 홍채
        iris_w = 6
        iris_h = 4
        pygame.draw.ellipse(surface, (180, 130, 50),
                           (eye_x - iris_w // 2, eye_y - iris_h // 2, iris_w, iris_h))
        pygame.draw.ellipse(surface, (220, 175, 70),
                           (eye_x - iris_w // 2 + 1, eye_y - iris_h // 2 + 1, iris_w - 2, iris_h - 2))

        # 동공
        pupil_ox = int(player_vx * 0.05)
        pygame.draw.ellipse(surface, (5, 5, 5),
                           (eye_x - 1 + pupil_ox, eye_y - 2, 2, 4))

        # 하이라이트
        pygame.draw.circle(surface, (255, 255, 250), (eye_x - 2 + pupil_ox, eye_y - 1), 1)

        # ═══════════════════════════════════════════════════════════════
        # 3. 외곽 흐릿한 테두리
        # ═══════════════════════════════════════════════════════════════
        pygame.draw.polygon(surface, edge_color, body_points, 2)

        # ═══════════════════════════════════════════════════════════════
        # 4. 작은 연기 파티클 (위쪽으로만)
        # ═══════════════════════════════════════════════════════════════
        if not hasattr(self, '_smoke_particles'):
            self._smoke_particles = []

        # 연기 생성 (작게, 적게)
        if len(self._smoke_particles) < 5 and random.random() < 0.2:
            self._smoke_particles.append({
                'x': cx + random.randint(-20, 20),
                'y': cy - ph // 2 + 5,
                'vx': random.uniform(-0.2, 0.2) + player_vx * 0.01,
                'vy': random.uniform(-0.5, -0.2),
                'size': random.uniform(2, 4),
                'life': random.randint(15, 30),
                'alpha': random.randint(60, 100)
            })

        # 연기 업데이트 & 그리기
        for s in self._smoke_particles[:]:
            s['x'] += s['vx']
            s['y'] += s['vy']
            s['life'] -= 1
            s['alpha'] = max(0, s['alpha'] - 4)
            s['size'] = max(0.5, s['size'] - 0.08)

            if s['life'] <= 0:
                self._smoke_particles.remove(s)
                continue

            sx = int(s['x'])
            sy = int(s['y'])
            sz = int(s['size'])
            if sz > 0 and 0 <= sx < pw and 0 <= sy < ph:
                pygame.draw.circle(surface, (20, 15, 28, int(s['alpha'])), (sx, sy), sz)

        # 화면에 그리기 (패들 위치 그대로)
        screen.blit(surface, paddle_rect.topleft)
        return surface

    def _load_animation_frames(self):
        """애니메이션 프레임 로드 (라그나로크 해머 프레임 기반)"""
        import pygame

        self.animation_frames.clear()

        # 라그나로크 해머 프레임을 기반으로 중앙 이미지를 벨트+오딘의 눈으로 교체
        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                if os.path.exists(frame_path):
                    original = pygame.image.load(frame_path).convert_alpha()
                    # 중앙을 지우고 벨트+눈 그리기
                    frame = self._create_belt_eye_frame(original, i)
                    self.animation_frames.append(frame)
            except Exception:
                pass

        # 프레임 로드 실패시 기본 프레임 생성
        if not self.animation_frames:
            for i in range(8):
                self.animation_frames.append(self._create_default_belt_eye_frame(i))

    def _create_belt_eye_frame(self, base_frame, frame_idx):
        """기존 프레임에서 중앙을 지우고 벨트+오딘의 눈 그리기"""
        import pygame
        import math

        frame = base_frame.copy()
        width, height = frame.get_size()
        cx, cy = width // 2, height // 2

        # 중앙 영역 전체 지우기 (테두리만 남김)
        clear_radius = min(width, height) // 2 - 3
        for y in range(height):
            for x in range(width):
                dist = math.sqrt((x - cx)**2 + (y - cy)**2)
                if dist < clear_radius:
                    frame.set_at((x, y), (0, 0, 0, 0))

        # 벨트+눈 그리기
        self._draw_belt_eye_on_surface(frame, cx, cy, frame_idx)

        return frame

    def _create_default_belt_eye_frame(self, frame_idx):
        """기본 벨트+눈 프레임 생성"""
        import pygame

        frame = pygame.Surface((32, 32), pygame.SRCALPHA)
        cx, cy = 16, 16

        # 배경 (붉은색/보라색 계열 그라데이션)
        border_colors = [(100, 0, 50), (150, 0, 75), (180, 0, 90), (150, 0, 75),
                         (100, 0, 50), (60, 0, 30), (40, 0, 20), (60, 0, 30)]
        pygame.draw.circle(frame, border_colors[frame_idx], (cx, cy), 15, 2)

        # 벨트+눈 그리기
        self._draw_belt_eye_on_surface(frame, cx, cy, frame_idx)

        return frame

    def _draw_belt_eye_on_surface(self, surface, cx, cy, frame_idx):
        """벨트와 오딘의 눈을 surface에 그리기"""
        import pygame
        import math

        # 벨트 색상 (어두운 가죽 색상, 프레임마다 약간 변화)
        belt_base = [(60, 40, 30), (65, 42, 32), (55, 38, 28), (70, 45, 35),
                     (50, 35, 25), (75, 48, 38), (45, 32, 22), (80, 50, 40)]
        belt_dark = [(40, 25, 18), (45, 28, 20), (35, 22, 15), (50, 30, 22),
                     (30, 20, 12), (55, 32, 25), (25, 18, 10), (60, 35, 28)]
        belt_highlight = [(100, 70, 50), (105, 72, 52), (95, 68, 48), (110, 75, 55),
                          (90, 65, 45), (115, 78, 58), (85, 62, 42), (120, 80, 60)]

        belt_color = belt_base[frame_idx % 8]
        belt_dark_color = belt_dark[frame_idx % 8]
        belt_light = belt_highlight[frame_idx % 8]

        # 눈 색상 (붉은색/주황색 - 저주받은 느낌)
        eye_colors = [(200, 50, 0), (220, 60, 10), (240, 70, 20), (230, 55, 5),
                      (210, 45, 0), (250, 75, 25), (190, 40, 0), (255, 80, 30)]
        eye_glow_colors = [(255, 100, 50), (255, 110, 60), (255, 120, 70), (255, 105, 55),
                           (255, 95, 45), (255, 125, 75), (255, 90, 40), (255, 130, 80)]
        pupil_colors = [(0, 0, 0), (10, 0, 5), (5, 0, 0), (15, 0, 8),
                        (0, 0, 0), (20, 0, 10), (0, 0, 0), (25, 5, 12)]

        eye_color = eye_colors[frame_idx % 8]
        eye_glow = eye_glow_colors[frame_idx % 8]
        pupil_color = pupil_colors[frame_idx % 8]

        # 벨트 본체 그리기 (수평 직사각형)
        belt_width = 18
        belt_height = 6
        belt_rect = pygame.Rect(cx - belt_width // 2, cy - belt_height // 2 + 2, belt_width, belt_height)
        pygame.draw.rect(surface, belt_dark_color, belt_rect)
        pygame.draw.rect(surface, belt_color, belt_rect.inflate(-2, -2))

        # 벨트 하이라이트
        pygame.draw.line(surface, belt_light,
                        (belt_rect.left + 2, belt_rect.top + 1),
                        (belt_rect.right - 2, belt_rect.top + 1), 1)

        # 벨트 버클 위치에 오딘의 눈 그리기 (중앙)
        eye_cx = cx
        eye_cy = cy - 2

        # 눈 외곽 글로우
        glow_pulse = (math.sin(frame_idx * 0.8) + 1) / 2
        glow_radius = 6 + int(glow_pulse * 2)

        # 글로우 효과
        for i in range(3):
            alpha = 80 - i * 20
            glow_surface = pygame.Surface((glow_radius * 2 + i * 4, glow_radius * 2 + i * 4), pygame.SRCALPHA)
            pygame.draw.ellipse(glow_surface, (*eye_glow[:3], alpha),
                              (0, 0, glow_radius * 2 + i * 4, glow_radius + i * 2 + 2))
            surface.blit(glow_surface, (eye_cx - glow_radius - i * 2, eye_cy - glow_radius // 2 - i))

        # 눈 본체 (타원형)
        eye_width = 10
        eye_height = 6
        pygame.draw.ellipse(surface, eye_glow, (eye_cx - eye_width // 2, eye_cy - eye_height // 2, eye_width, eye_height))
        pygame.draw.ellipse(surface, eye_color, (eye_cx - eye_width // 2 + 1, eye_cy - eye_height // 2 + 1, eye_width - 2, eye_height - 2))

        # 동공 (세로로 긴 고양이 눈처럼)
        pupil_width = 2
        pupil_height = 4
        pygame.draw.ellipse(surface, pupil_color,
                          (eye_cx - pupil_width // 2, eye_cy - pupil_height // 2, pupil_width, pupil_height))

        # 눈 하이라이트 (작은 흰색 점)
        pygame.draw.circle(surface, (255, 255, 255), (eye_cx - 2, eye_cy - 1), 1)

        # 벨트 양쪽 끝 장식 (작은 금속 조각)
        metal_color = (180, 160, 100)
        metal_dark = (120, 100, 60)

        # 왼쪽 금속
        pygame.draw.rect(surface, metal_dark, (cx - belt_width // 2 - 2, cy, 3, 4))
        pygame.draw.rect(surface, metal_color, (cx - belt_width // 2 - 1, cy + 1, 2, 2))

        # 오른쪽 금속
        pygame.draw.rect(surface, metal_dark, (cx + belt_width // 2, cy, 3, 4))
        pygame.draw.rect(surface, metal_color, (cx + belt_width // 2 + 1, cy + 1, 2, 2))

    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """애니메이션 아이콘 그리기"""
        import pygame
        import math

        # 공통 배경 프레임 연출 (붉은색/보라색 테두리)
        # 오딘의 눈은 붉은색 그라데이션 + 파란색 코너 애니메이션
        frame_offset = _draw_common_legendary_frame(
            screen, x, y, size, self.animation_time,
            border_color=(150, 50, 100),  # 붉은 보라색 테두리
            corner_color=(100, 150, 255)   # 파란색 코너
        )

        # 애니메이션 프레임 그리기
        if self.animation_frames and len(self.animation_frames) > 0:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)

            icon_y = y + frame_offset + int(self.animation_offset)
            current_icon = self.animation_frames[self.current_frame % len(self.animation_frames)]
            scaled_icon = pygame.transform.scale(current_icon, (size, size))
            screen.blit(scaled_icon, (x, icon_y))

            # 저주받은 빛 효과 (눈 위에서 깜빡임)
            if self.current_frame in [0, 2, 4, 6]:
                sparkle_color = (255, 100, 50)
                sparkle_y = y + frame_offset + size // 3 + int(math.sin(self.animation_time * 4) * 2)
                pygame.draw.circle(screen, sparkle_color, (x + size // 2, sparkle_y), 2)
                pygame.draw.circle(screen, (255, 200, 150), (x + size // 2, sparkle_y), 1)
        else:
            # Fallback: 프레임이 없으면 기본 아이콘 그리기
            icon_y = y + frame_offset + int(self.animation_offset)

            # 간단한 벨트+눈 모양
            belt_color = (60, 40, 30)
            eye_color = (200, 50, 0)

            cx, cy = x + size // 2, icon_y + size // 2

            # 벨트
            belt_rect = pygame.Rect(cx - size // 4, cy, size // 2, size // 8)
            pygame.draw.rect(screen, belt_color, belt_rect)

            # 눈
            pygame.draw.ellipse(screen, eye_color, (cx - size // 8, cy - size // 10, size // 4, size // 6))
            pygame.draw.ellipse(screen, (0, 0, 0), (cx - size // 20, cy - size // 16, size // 10, size // 8))

        # 파티클 효과
        if self.particle_timer > 1.0:
            self._spawn_particle(screen, x + size // 2, y + frame_offset + size // 2)
            self.particle_timer = 0


class PandoraLegacy(LegendaryItem):
    """판도라의 유산 - 장신구 부위 전설 아이템

    판도라의 상자 업그레이드 버전.
    매 라운드 승리 후 다음 라운드 시작 시 3개의 액티브 아이템 선택지가 화면에 표시되고
    플레이어가 하나를 선택하여 획득.

    롤 옵션: 매직찬스 (아이템 등급 상승 확률) 10~30%
    """

    def __init__(self):
        super().__init__(
            name="pandora_legacy",
            korean_name="판도라의 유산",
            description="라운드 승리 시 3개 액티브 아이템 중 하나를 선택 (롤 옵션: 매직찬스 10~30%)",
            unlock_condition="신화 아이템 획득",
            icon_path=None  # 고유 애니메이션만 사용
        )
        # 선택 UI 상태
        self.selection_active = False
        self.selection_items = []  # 3개 선택지 [{name, color, icon, ...}, ...]
        self.selected_index = -1
        self.selection_animation_timer = 0
        self.selection_fade_alpha = 0

        # 애니메이션 프레임 설정
        self.animation_frames = []
        self.current_frame = 0
        self.frame_counter = 0
        self.animation_speed = 8
        self._load_animation_frames()
        self.enhancement_bonus_pct = 0  # 강화 버프 보너스 (장착 시 동기화)

    @property
    def selection_quality(self) -> float:
        """매직찬스 보너스 (롤 옵션 적용, 연마 스킬 + 강화 보너스 포함, 10~30%)"""
        return get_legendary_roll_value(
            "pandora_legacy", "selection_quality",
            apply_polish=True,
            enhancement_bonus_pct=self.enhancement_bonus_pct
        )

    @property
    def trigger_chance(self) -> float:
        """승리시 유산 발동률 (롤 옵션 적용, 연마 스킬 + 강화 보너스 포함, 40~70%)"""
        return get_legendary_roll_value(
            "pandora_legacy", "trigger_chance",
            apply_polish=True,
            enhancement_bonus_pct=self.enhancement_bonus_pct
        )

    def activate(self, game_state: Dict = None):
        """판도라의 유산 활성화"""
        if self.active:
            return
        super().activate(game_state)
        import items
        items.pandora_legacy_obtained = True

    def deactivate(self):
        """판도라의 유산 비활성화"""
        super().deactivate()
        self.selection_active = False
        self.selection_items = []

    def generate_selection_choices(self):
        """라운드 승리 시 3개 액티브 아이템 선택지 생성"""
        import items as items_module
        import random

        quality_bonus = self.selection_quality / 100.0  # 퍼센트 → 비율

        # 액티브 아이템 후보 풀 구성 (chance > 0인 아이템만)
        active_pool = []
        passive_names = {
            "speedboots", "speedgear", "battery", "slot_add", "revival", "master", "cooltime",
            "chargebag", "spikeboots", "dashgear", "sensor", "bulkup", "dashholder", "gravitybelt",
            "dowsing_pendulum", "commando_arm", "technical_vest", "fuel_pouch", "bluetooth_ring",
            "star_detector", "foul_whistle", "smartphone", "knee_pads", "ragnarok_hammer",
            "hermes_shoes", "poseidon_trident", "angel_blessing", "sacred_laurel",
            "transcendent_crown", "odins_eye", "pandora_legacy",
            "bulletproof_hat", "spiked_helmet", "gold_bar", "gold_digger", "lucky_coin",
            "adversity_armor", "shrapnel_armor", "soul_burst", "sage_ring"
        }
        excluded = {"ammo_box", "fire_support", "doping_potion"}  # 물자보급 전용
        # 발토르(blacksmith) 전용 아이템 — 다른 캐릭터에서는 제외
        blacksmith_only = {"repair_kit", "berserk_potion"}
        try:
            from pingfighter import selected_character_type as _cur_char
        except Exception:
            _cur_char = ""

        for item_type in items_module.ITEM_TYPES:
            name = item_type.get("name", "")
            if name in passive_names or name in excluded:
                continue
            if name in blacksmith_only and _cur_char != "blacksmith":
                continue
            if item_type.get("chance", 0) <= 0:
                continue
            if not items_module.unlocked_items.get(name, False):
                continue
            active_pool.append(item_type)

        if len(active_pool) < 3:
            return []

        # 품질 보너스 적용: 높은 등급 아이템 가중치 증가
        weighted_pool = []
        for item in active_pool:
            chance = item.get("chance", 0.01)
            # 낮은 확률(희귀)일수록 품질 보너스로 가중치 증가
            if chance < 0.005:
                weight = 1.0 + quality_bonus * 3  # 희귀 아이템 가중치 상승
            elif chance < 0.01:
                weight = 1.0 + quality_bonus * 2
            else:
                weight = 1.0
            weighted_pool.append((item, weight))

        # 3개 선택 (중복 없이)
        selected = []
        remaining = list(weighted_pool)
        for _ in range(3):
            if not remaining:
                break
            weights = [w for _, w in remaining]
            total = sum(weights)
            if total <= 0:
                break
            r = random.random() * total
            cumulative = 0
            for idx, (item, w) in enumerate(remaining):
                cumulative += w
                if r <= cumulative:
                    selected.append(item.copy())
                    remaining.pop(idx)
                    break

        self.selection_items = selected
        self.selection_active = True
        self.selected_index = -1
        self.selection_animation_timer = 0
        self.selection_fade_alpha = 0
        return selected

    def _load_animation_frames(self):
        """애니메이션 프레임 로드 (라그나로크 해머 프레임 기반, 중앙 아이콘만 판도라 상자로 교체)"""
        import pygame

        self.animation_frames.clear()

        for i in range(8):
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                if os.path.exists(frame_path):
                    original = pygame.image.load(frame_path).convert_alpha()
                    frame = self._create_pandora_frame(original, i)
                    self.animation_frames.append(frame)
            except Exception:
                pass

        if not self.animation_frames:
            for i in range(8):
                self.animation_frames.append(self._create_default_frame(i))

    def _create_pandora_frame(self, base_frame, frame_idx):
        """라그나로크 해머 프레임 무시, 무지개 가방만 투명 배경에 그리기
        (글로우/테두리는 draw_icon에서 _draw_common_legendary_frame이 담당)"""
        import pygame

        width, height = base_frame.get_size()
        frame = pygame.Surface((width, height), pygame.SRCALPHA)
        cx, cy = width // 2, height // 2
        self._draw_rainbow_bag(frame, cx, cy, frame_idx)
        return frame

    def _create_default_frame(self, frame_idx):
        """기본 프레임 (무지개 가방만, 투명 배경)"""
        import pygame

        frame = pygame.Surface((32, 32), pygame.SRCALPHA)
        self._draw_rainbow_bag(frame, 16, 16, frame_idx)
        return frame

    def _draw_rainbow_bag(self, surface, cx, cy, frame_idx):
        """무지개빛 가방 아이콘을 surface에 그리기"""
        import pygame
        import math

        # ── 무지개 색상 (프레임마다 순환) ──
        rainbow = [
            (255, 80, 80),    # 빨
            (255, 160, 50),   # 주
            (255, 230, 50),   # 노
            (80, 220, 80),    # 초
            (60, 160, 255),   # 파
            (100, 80, 255),   # 남
            (200, 80, 255),   # 보
            (255, 120, 180),  # 핑크
        ]
        # 프레임마다 무지개 색상 회전
        c1 = rainbow[(frame_idx + 0) % 8]
        c2 = rainbow[(frame_idx + 2) % 8]
        c3 = rainbow[(frame_idx + 4) % 8]
        c4 = rainbow[(frame_idx + 6) % 8]

        # ── 가방 본체 (둥근 사각형) ──
        bag_w, bag_h = 14, 11
        bag_x = cx - bag_w // 2
        bag_y = cy - bag_h // 2 + 1

        # 무지개 줄무늬 (가로 4줄)
        stripe_h = bag_h // 4
        stripes = [c1, c2, c3, c4]
        for i, sc in enumerate(stripes):
            sy = bag_y + i * stripe_h
            sh = stripe_h if i < 3 else (bag_h - stripe_h * 3)
            pygame.draw.rect(surface, sc, (bag_x, sy, bag_w, sh))

        # 가방 윤곽
        pygame.draw.rect(surface, (60, 40, 30), (bag_x, bag_y, bag_w, bag_h), 1)

        # ── 가방 뚜껑 / 플랩 (반원형) ──
        flap_color_base = rainbow[(frame_idx + 1) % 8]
        flap_bright = tuple(min(255, c + 40) for c in flap_color_base)
        flap_rect = pygame.Rect(bag_x - 1, bag_y - 4, bag_w + 2, 5)
        pygame.draw.rect(surface, flap_bright, flap_rect, border_radius=2)
        pygame.draw.rect(surface, (60, 40, 30), flap_rect, 1, border_radius=2)

        # ── 손잡이 (반원 아치) ──
        handle_color = rainbow[(frame_idx + 3) % 8]
        pygame.draw.arc(surface, handle_color,
                       (cx - 4, bag_y - 7, 8, 6),
                       0, math.pi, 2)

        # ── 금색 버클 / 잠금장치 ──
        gold = (255, 215, 0)
        pygame.draw.rect(surface, gold, (cx - 2, bag_y - 1, 4, 3))
        pygame.draw.rect(surface, (200, 170, 0), (cx - 2, bag_y - 1, 4, 3), 1)

        # ── 반짝이 파티클 (프레임별 위치 변화) ──
        sparkle_offsets = [
            (-4, -3), (5, -2), (-3, 4), (4, 3),
            (-5, 1), (3, -4), (-2, 5), (5, 0),
        ]
        sp_x, sp_y = sparkle_offsets[frame_idx % 8]
        sparkle_color = rainbow[(frame_idx + 5) % 8]
        bright_sparkle = tuple(min(255, c + 80) for c in sparkle_color)
        pygame.draw.rect(surface, bright_sparkle, (cx + sp_x, cy + sp_y, 2, 2))

    def update(self, dt: float, ui_mode: bool = False):
        """애니메이션 업데이트"""
        super().update(dt, ui_mode)
        if self.animation_frames:
            self.frame_counter += 1
            if self.frame_counter >= self.animation_speed:
                self.frame_counter = 0
                self.current_frame = (self.current_frame + 1) % len(self.animation_frames)

    def draw_icon(self, screen: pygame.Surface, x: int, y: int, size: int = 60):
        """판도라의 유산 아이콘 (공통 파란 글로우 프레임 + 무지개 가방 애니메이션)"""
        # 공통 전설 프레임 (파란 글로우 + 파란 테두리 + 금색 코너)
        frame_offset = _draw_common_legendary_frame(
            screen, x, y, size, self.animation_time,
            border_color=COMMON_LEGENDARY_BORDER_COLOR,
            corner_color=COMMON_LEGENDARY_CORNER_COLOR,
        )

        # 가운데 무지개 가방 애니메이션 프레임
        frame_y = y + frame_offset
        if self.animation_frames:
            frame = self.animation_frames[self.current_frame % len(self.animation_frames)]
            # 프레임에서 중앙 아이콘만 추출 (테두리 제외)
            inner_size = size - 6
            scaled = pygame.transform.scale(frame, (inner_size, inner_size))
            screen.blit(scaled, (x + 3, frame_y + 3))
        else:
            self._draw_fallback_icon(screen, x + 3, frame_y + 3, size - 6)

        # 파티클 효과
        if self.particle_timer > 1.0:
            self._spawn_particle(screen, x + size // 2, frame_y + size // 2)
            self.particle_timer = 0

    def _draw_fallback_icon(self, screen, x, y, size):
        """폴백 무지개 가방 아이콘"""
        cx, cy = x + size // 2, y + size // 2
        rainbow = [(255,80,80),(255,230,50),(60,160,255),(200,80,255)]
        bw = size * 7 // 16
        bh = size * 11 // 32
        bx = cx - bw // 2
        by = cy - bh // 2 + size // 32
        sh = bh // 4
        for i, sc in enumerate(rainbow):
            sy = by + i * sh
            pygame.draw.rect(screen, sc, (bx, sy, bw, sh if i < 3 else bh - sh * 3))
        pygame.draw.rect(screen, (60, 40, 30), (bx, by, bw, bh), 1)


# 전설 아이템 관리자
class LegendaryItemManager:
    """전설 아이템 시스템 관리"""
    def __init__(self):
        self.items: Dict[str, LegendaryItem] = {}
        self.unlocked_items: List[str] = []
        self.active_items: List[str] = []
        self._initialize_items()
        
    def _initialize_items(self):
        """전설 아이템 초기화"""
        # 모든 전설 아이템 등록
        self.items["infinity_gauntlet"] = InfinityGauntlet()
        self.items["phoenix_feather"] = PhoenixFeather()
        self.items["chronos_clock"] = ChronosClock()
        self.items["excalibur_blade"] = ExcaliburBlade()
        self.items["ragnarok_hammer"] = RagnarokHammer()
        self.items["hermes_shoes"] = HermesShoes()
        poseidon_item = PoseidonTrident()
        self.items["poseidon_trident"] = poseidon_item
        self.items["angel_blessing"] = AngelBlessing()
        self.items["sacred_laurel"] = SacredLaurel()
        self.items["transcendent_crown"] = TranscendentCrown()
        self.items["odins_eye"] = OdinsEye()
        self.items["pandora_legacy"] = PandoraLegacy()

        placeholder_defs = [
            ("empty_legendary", "빈전설"),
            ("empty_legendary2", "빈전설2"),
            ("empty_legendary3", "빈전설3"),
            ("empty_legendary4", "빈전설4"),
            ("empty_legendary5", "빈전설5"),
            ("empty_legendary6", "빈전설6"),
        ]
        for name, label in placeholder_defs:
            placeholder = EmptyLegendary(name=name, korean_name=label)
            placeholder.unlocked = True
            self.items[name] = placeholder

        # 테스트용: 전설 아이템 강제 해금
        self.items["ragnarok_hammer"].unlocked = True
        if "ragnarok_hammer" not in self.unlocked_items:
            self.unlocked_items.append("ragnarok_hammer")

        self.items["hermes_shoes"].unlocked = True
        if "hermes_shoes" not in self.unlocked_items:
            self.unlocked_items.append("hermes_shoes")


        self.items["poseidon_trident"].unlocked = True
        if "poseidon_trident" not in self.unlocked_items:
            self.unlocked_items.append("poseidon_trident")

        self.items["angel_blessing"].unlocked = True
        if "angel_blessing" not in self.unlocked_items:
            self.unlocked_items.append("angel_blessing")

        self.items["sacred_laurel"].unlocked = True
        if "sacred_laurel" not in self.unlocked_items:
            self.unlocked_items.append("sacred_laurel")

        self.items["transcendent_crown"].unlocked = True
        if "transcendent_crown" not in self.unlocked_items:
            self.unlocked_items.append("transcendent_crown")

        self.items["odins_eye"].unlocked = True
        if "odins_eye" not in self.unlocked_items:
            self.unlocked_items.append("odins_eye")

        self.items["pandora_legacy"].unlocked = True
        if "pandora_legacy" not in self.unlocked_items:
            self.unlocked_items.append("pandora_legacy")

        for name, _ in placeholder_defs:
            if name not in self.unlocked_items:
                self.unlocked_items.append(name)

        # 디바인스톤(건설형으로 전환): 전설 탭에는 노출하지 않음


        # empty/empty1/empty2 플레이스홀더는 등록/해금하지 않음(전설 탭 간소화)


    
    def _init_legendary_items(self):
        """전설 아이템 초기화 (애니메이션용)"""
        # 라그나로크 해머 초기화
        if "ragnarok_hammer" not in self.items:
            self.items["ragnarok_hammer"] = RagnarokHammer()
        # 헤르메스 신발 초기화
        if "hermes_shoes" not in self.items:
            self.items["hermes_shoes"] = HermesShoes()
        # 포세이돈의 삼지창 초기화
        if "poseidon_trident" not in self.items:
            self.items["poseidon_trident"] = PoseidonTrident()
        if "angel_blessing" not in self.items:
            self.items["angel_blessing"] = AngelBlessing()
        # 신성 월계수 초기화
        if "sacred_laurel" not in self.items:
            self.items["sacred_laurel"] = SacredLaurel()
        # 초월자의 관 초기화
        if "transcendent_crown" not in self.items:
            self.items["transcendent_crown"] = TranscendentCrown()
        # 오딘의 눈 초기화
        if "odins_eye" not in self.items:
            self.items["odins_eye"] = OdinsEye()
        # 판도라의 유산 초기화
        if "pandora_legacy" not in self.items:
            self.items["pandora_legacy"] = PandoraLegacy()
        # empty/empty1/empty2 보정 생성하지 않음
        
    def check_unlocks(self, game_stats: Dict):
        """해금 조건 체크"""
        for item_name, item in self.items.items():
            if not item.unlocked and item.check_unlock_condition(game_stats):
                item.unlocked = True
                self.unlocked_items.append(item_name)
                if LEGENDARY_DEBUG_ENABLED:
                    print(f"   [{item.korean_name}] !")
                
    def get_unlocked_items(self) -> List[LegendaryItem]:
        """해금된 아이템 목록 반환"""
        return [self.items[name] for name in self.unlocked_items]
        
    def get_item(self, name: str) -> Optional[LegendaryItem]:
        """아이템 가져오기"""
        return self.items.get(name)
        
    def activate_item(self, name: str, game_state: Dict):
        """아이템 활성화"""
        global _pending_angel_blessing_activation

        if name in PLACEHOLDER_LEGENDARY_NAMES:
            return
        if name in self.items:
            # 아이템이 해금되지 않았으면 자동으로 해금
            if name not in self.unlocked_items:
                if LEGENDARY_DEBUG_ENABLED:
                    print(f"   ⚠️ {name}이 unlocked_items에 없음! 자동 추가")
                self.unlocked_items.append(name)
                self.items[name].unlocked = True

            # 이미 활성 상태이면 재활성화 스킵 (force 플래그로 무시 가능)
            force = False
            try:
                force = bool(game_state.get("_force_reactivate", False))
            except Exception:
                force = False
            if name in self.active_items and not force:
                return

            # 디버그 출력은 실제 활성화 시점에만
            if LEGENDARY_DEBUG_ENABLED:
                print(f"🎮 activate_item 호출: name={name}")
                print(f"   - items에 있음: {name in self.items}")
                print(f"   - unlocked_items에 있음: {name in self.unlocked_items}")
                print(f"   - unlocked_items: {self.unlocked_items}")

            item = self.items[name]

            # 천사의 가호: 전설 획득 애니메이션이 활성 상태면 대기열에 넣기
            if name == "angel_blessing":
                try:
                    from effects.legendary_integration import is_legendary_effect_active
                    if is_legendary_effect_active():
                        if AngelBlessing.DEBUG_ENABLED: print(f"[AngelBlessing] 전설 획득 애니메이션 진행 중 - 대기열에 추가")
                        _pending_angel_blessing_activation = dict(game_state) if game_state else {}
                        # active_items에는 추가하되 주사위 굴림은 나중에
                        if name not in self.active_items:
                            self.active_items.append(name)
                        return
                except Exception as e:
                    if AngelBlessing.DEBUG_ENABLED: print(f"[AngelBlessing] 애니메이션 상태 확인 실패: {e}")

            item.activate(game_state)
            # 천사의 가호는 활성화 시점에 현재 스테이지 확인
            # NOTE: _triggered_stages에 이미 발동된 스테이지가 있으면 재발동하지 않음
            if name == "angel_blessing":
                try:
                    current_stage_hint = None
                    try:
                        current_stage_hint = int(game_state.get("current_stage"))
                    except Exception:
                        current_stage_hint = game_state.get("current_stage")
                    # 해당 스테이지에서 아직 발동 안 했으면 발동
                    if current_stage_hint not in item._triggered_stages:
                        item.applied_stage = None  # 새 발동을 위해 리셋
                        item.update(0.0, ui_mode=False)
                except Exception:
                    pass
            if name not in self.active_items:
                self.active_items.append(name)
                if LEGENDARY_DEBUG_ENABLED:
                    print(f"   ✅ {name}을 active_items에 추가: {self.active_items}")
            else:
                if LEGENDARY_DEBUG_ENABLED:
                    print(f"   ℹ️ {name}은 이미 active_items에 있음")
                
    def deactivate_item(self, name: str):
        """아이템 비활성화"""
        if name in self.items:
            self.items[name].deactivate()
            if name in self.active_items:
                self.active_items.remove(name)
                
    def update(self, dt: float, ui_mode: bool = False):
        """모든 활성 아이템 업데이트
        Args:
            dt: 델타 타임
            ui_mode: UI 모드 여부 (True면 게임플레이 효과 비활성화)
        """
        # 디버그: 첫 프레임에만 출력
        if hasattr(self, '_debug_counter'):
            self._debug_counter += 1
        else:
            self._debug_counter = 0
            
        if self._debug_counter == 1 and os.environ.get("PINGF_DEBUG_LEGENDARY", "0") == "1":
            print(f"🔍 LegendaryManager.update: active_items={self.active_items}, ui_mode={ui_mode}")
            
        for name in self.active_items:
            if name in self.items:
                # PoseidonTrident는 ui_mode 파라미터를 받음
                if name == "poseidon_trident":
                    self.items[name].update(dt, ui_mode)
                else:
                    # 다른 아이템들도 ui_mode를 받을 수 있도록 처리
                    try:
                        self.items[name].update(dt, ui_mode)
                    except TypeError:
                        # ui_mode 파라미터를 받지 않는 아이템은 dt만 전달
                        self.items[name].update(dt)
                
    def draw_active_items(self, screen: pygame.Surface, x: int, y: int):
        """활성 아이템 표시"""
        for i, name in enumerate(self.active_items):
            if name in self.items:
                item = self.items[name]
                item.draw_icon(screen, x + i * 70, y, 60)
                
    def save_state(self) -> Dict:
        """상태 저장"""
        return {
            "unlocked_items": self.unlocked_items,
            "active_items": self.active_items
        }
        
    def load_state(self, state: Dict):
        """상태 로드"""
        self.unlocked_items = state.get("unlocked_items", [])
        self.active_items = state.get("active_items", [])
        # 해금 상태 복원
        for name in self.unlocked_items:
            if name in self.items:
                self.items[name].unlocked = True
        # 활성 상태 복원
        for name in self.active_items:
            if name in self.items:
                self.items[name].active = True
    
    def reset_round_effects(self):
        """라운드 종료 시 모든 활성 아이템의 효과 초기화"""
        for name in self.active_items:
            if name in self.items:
                item = self.items[name]
                # reset_round_effects 메서드가 있는 아이템만 호출
                if hasattr(item, 'reset_round_effects'):
                    item.reset_round_effects()

        pass  # print(f"🎮 모든 전설 아이템 라운드 효과 초기화 완료")  # 디버그 비활성화

    def reset_for_new_game(self):
        """새 게임 시작 시 모든 아이템 발동 이력 초기화 (게임 오버/메인 메뉴 복귀 시 호출)"""
        for name, item in self.items.items():
            # reset_for_new_game 메서드가 있는 아이템만 호출
            if hasattr(item, 'reset_for_new_game'):
                item.reset_for_new_game()
        pass  # print(f"🎮 모든 전설 아이템 새 게임 초기화 완료")  # 디버그 비활성화


# 싱글톤 인스턴스
_legendary_manager = None

def get_legendary_manager() -> LegendaryItemManager:
    """전설 아이템 매니저 싱글톤 반환"""
    global _legendary_manager
    if _legendary_manager is None:
        _legendary_manager = LegendaryItemManager()
    return _legendary_manager

def reset_legendary_manager():
    """전설 아이템 매니저 리셋"""
    global _legendary_manager
    _legendary_manager = None


def process_pending_angel_blessing():
    """대기 중인 천사의 가호 활성화 처리 (전설 획득 애니메이션 완료 후 호출)"""
    global _pending_angel_blessing_activation

    if _pending_angel_blessing_activation is None:
        return False

    game_state = _pending_angel_blessing_activation
    _pending_angel_blessing_activation = None

    try:
        legendary_manager = get_legendary_manager()
        angel_blessing = legendary_manager.get_item("angel_blessing")
        if angel_blessing and "angel_blessing" in legendary_manager.active_items:
            if AngelBlessing.DEBUG_ENABLED: print(f"[AngelBlessing] 전설 획득 애니메이션 완료 - 지연된 주사위 굴림 처리")
            # 현재 스테이지 확인
            current_stage_hint = None
            try:
                current_stage_hint = int(game_state.get("current_stage"))
            except Exception:
                current_stage_hint = game_state.get("current_stage")
            if current_stage_hint is None:
                current_stage_hint = angel_blessing._get_current_stage()

            # 전설 애니메이션 완료 후 즉시 주사위 굴림 (조건 체크 없이 강제 실행)
            if current_stage_hint is not None:
                # _triggered_stages에서 현재 스테이지 제거 (전설 획득 시 처음 획득이므로)
                angel_blessing._triggered_stages.discard(current_stage_hint)
                angel_blessing.applied_stage = None
                angel_blessing._roll_blessing(current_stage_hint)
                if AngelBlessing.DEBUG_ENABLED: print(f"[AngelBlessing] 전설 획득 후 주사위 애니메이션 시작 (스테이지 {current_stage_hint})")
            return True
    except Exception as e:
        if AngelBlessing.DEBUG_ENABLED: print(f"[AngelBlessing] 지연 활성화 처리 실패: {e}")

    return False


def has_pending_angel_blessing() -> bool:
    """대기 중인 천사의 가호 활성화가 있는지 확인"""
    return _pending_angel_blessing_activation is not None
