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

# 리소스 경로 헬퍼 (PyInstaller 호환)
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

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
    "item_spawn",
    "item_cooldown",
    "dash_cost",
    "dash_cooldown",
    "move_speed",
)


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
        
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """해금 조건 체크 - 각 아이템별로 오버라이드"""
        return False
        
    def activate(self, game_state: Dict):
        """아이템 활성화 - 각 아이템별로 오버라이드"""
        self.active = True
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
            print(f"   !  ...")
            return True
        return False
        
    def update_time_slow(self, dt: float) -> float:
        """시간 배율 업데이트"""
        if self.time_slow_active:
            self.time_slow_timer -= dt
            if self.time_slow_timer <= 0:
                self.time_slow_active = False
                print(f"")
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
    """포세이돈의 삼지창 - 물의 신의 무기"""
    def __init__(self):
        super().__init__(
            name="poseidon_trident",
            korean_name="포세이돈의 삼지창",
            description="대시 시 거대한 물결 회오리를 생성하여 공을 튕겨냅니다 (순수 대시 보조용)",
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
                print(f"✓ 포세이돈 삼지창 프레임 {i} 동기화 완료")
            except Exception as e:
                print(f"[ERROR] Frame {i} load failed: {frame_path} - {e}")
        
        print(f"포세이돈 삼지창: PNG 프레임 {frames_loaded}/8개 로드")
        
        # 프레임이 없으면 에러만 표시 (가짜 애니메이션 생성하지 않음)
        if not self.icon_frames or len(self.icon_frames) == 0:
            print("❌ 포세이돈 삼지창: PNG 프레임을 찾을 수 없습니다!")
                
    def check_unlock_condition(self, game_stats: Dict) -> bool:
        """스테이지 7 클리어 체크"""
        return game_stats.get("highest_stage_cleared", 0) >= 7
        
    def activate(self, game_state: Dict):
        """삼지창 활성화"""
        print(f"🔱 [BEFORE] PoseidonTrident.activate 호출, self.active = {self.active}")
        super().activate(game_state)  # 부모 클래스의 activate 호출 (self.active = True 설정)
        self.wave_timer = 0
        print(f"🔱 [AFTER] {self.korean_name} 활성화!")
        print(f"   - self.active = {self.active}")
        print(f"   - 대시 시 거대한 물결 회오리 생성!")
        
        # 강제로 active 확인
        if not self.active:
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
        
        print(f"🔱 포세이돈의 삼지창 라운드 효과 초기화")
        
    def stop_water_momentum(self):
        """물의 추진력 즉시 중단 (보스 패들에 맞았을 때)"""
        self.water_momentum_active = False
        self.water_momentum_timer = 0
        self.water_momentum_force_y = 0
        self.water_momentum_force_x = 0
        print(f"🔱 물의 추진력 종료 - 보스 패들 충돌")
        
    def apply_trajectory_influence(self, ball_x: float, ball_y: float, 
                                  ball_vx: float, ball_vy: float, 
                                  paddle_x: float, paddle_y: float) -> Tuple[float, float]:
        """물의 파동 효과 제거됨 - 순수 대시 보조용"""
        # 물의 파동 효과는 제거되었습니다
        # 이제 포세이돈의 삼지창은 순수하게 대시 물결 회오리만 생성합니다
        return ball_vx, ball_vy
        
    def trigger_dash_wave(self, paddle_x: float, paddle_y: float, direction: int = 0):
        """대시 후 통제불능 시 양쪽에 거대한 물결 회오리 발동"""
        if not self.active:
            print(f"⚠️ 포세이돈 삼지창이 비활성화 상태입니다!")
            return
            
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
                
    def apply_dash_wave_to_ball(self, ball_x: float, ball_y: float,
                               ball_vx: float, ball_vy: float,
                               paddle_x: float, paddle_y: float,
                               player_x: float = None, player_y: float = None) -> Tuple[float, float]:
        """거대한 물결 회오리가 공에 미치는 굴절 효과 (Stage 4 자기장과 동일한 메커니즘)"""
        
        # 회오리 효과를 받은 공이 보스에게 맞았는지 확인
        if self.vortex_affected:
            # 회오리 효과를 받은 공이 보스에게 맞았는지 확인
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
            if not hasattr(self, '_vortex_debug_shown'):
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
                    print(f"🌊 [즉시 반사] 보스 공 회오리 접촉!")
                    current_ball_speed = math.sqrt(ball_vx**2 + ball_vy**2)
                    
                    # 원래 속도 저장 (복원용)
                    self.original_ball_speed = current_ball_speed
                    self.vortex_affected = True  # 회오리 효과를 받았음을 표시
                    self.boss_hit_count = 0  # 보스 히트 카운트 리셋
                    print(f"🔍 [즉시 반사] vortex_affected=True 설정, original_speed={self.original_ball_speed:.1f}, boss_hit_count=0")
                    
                    # 물 궤적 활성화 (즉시 반사 후에도 궤적 유지)
                    self.water_trail_active = True
                    print(f"🌊 [즉시 반사] 물 궤적 활성화!")
                    
                    # 랜덤 증폭 반사 (현재 공 속도의 150~200%)
                    amplify_factor = random.uniform(1.5, 2.0)  # 1.5배~2배 랜덤
                    amplified_speed = current_ball_speed * amplify_factor
                    
                    # 최소 속도 보장 (회오리 영역을 확실히 벗어나도록)
                    min_speed = 20.0  # 최소 속도
                    if amplified_speed < min_speed:
                        amplified_speed = min_speed
                    
                    print(f"🔍 [물회오리 즉시반사] 원래 속도: {current_ball_speed:.1f} × {amplify_factor:.2f} = 증폭 속도: {amplified_speed:.1f}")
                    
                    # 위쪽 방향 랜덤 반사 (-90도 기준 ±30도) - 더 위쪽으로
                    base_angle = -math.pi / 2  # -90도 (위쪽)
                    random_spread = math.pi / 6  # ±30도 (더 좁은 범위)
                    random_offset = random.uniform(-random_spread, random_spread)
                    target_angle = base_angle + random_offset
                    
                    # 최종 속도 계산 (간섭 없음)
                    final_vx = math.cos(target_angle) * amplified_speed
                    final_vy = math.sin(target_angle) * amplified_speed
                    
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
                    
                    print(f"🌊 [포세이돈 DEBUG] 공 캡처! 입력 속도: {self.captured_ball_speed:.1f}")
                    
                    # 물 궤적 시작
                    self.water_trail_active = True
                    self.water_trail = []  # 새로운 궤적 시작
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
                        print(f"[DEBUG] 회오리 속도 보정: {current_speed:.1f} → {min_speed:.1f}")
                    
                    # 속도 제한 (너무 빠르면 순간이동처럼 보임)
                    max_speed = 15
                    speed = math.sqrt(new_vx * new_vx + new_vy * new_vy)
                    if speed > max_speed:
                        new_vx = new_vx / speed * max_speed
                        new_vy = new_vy / speed * max_speed
                    
                    # 캡처 시간이 끝나면 랜덤 방향으로 튕겨냄
                    if self.ball_vortex_timer >= self.ball_capture_duration:
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
                        
                        print(f"🌊 [포세이돈 DEBUG] 속도 계산: {self.captured_ball_speed:.1f} → {deflect_speed:.1f} ({amplify_factor:.1f}배 랜덤)")
                        print(f"🌊 [포세이돈 DEBUG] 각도 계산: {math.degrees(target_angle):.1f}도")
                        
                        # Y축 속도 안전장치 - 반드시 위쪽으로 향하도록 보장
                        min_upward_speed = -50  # 최소 위쪽 속도 (극도로 빠르게)
                        max_upward_speed = -30  # 최대 위쪽 속도 (매우 빠르게)
                        
                        # Y 속도가 아래쪽이거나 너무 느리면 강제로 위쪽으로
                        original_vy = new_vy
                        if new_vy >= 0:  # 아래쪽이나 수평이면
                            new_vy = min_upward_speed  # 강제로 위쪽으로
                            print(f"🌊 [포세이돈 DEBUG] Y축 보정: {original_vy:.1f} → {new_vy:.1f} (아래쪽→위쪽)")
                        elif new_vy > max_upward_speed:  # 위쪽이지만 너무 느리면
                            new_vy = max_upward_speed
                            print(f"🌊 [포세이돈 DEBUG] Y축 보정: {original_vy:.1f} → {new_vy:.1f} (너무 느림)")
                        elif new_vy < min_upward_speed:  # 너무 빠르면
                            new_vy = min_upward_speed
                            print(f"🌊 [포세이돈 DEBUG] Y축 보정: {original_vy:.1f} → {new_vy:.1f} (너무 빠름)")
                        
                        # X축 속도도 너무 극단적이지 않도록 제한
                        max_x_speed = 50  # 횡방향 속도 제한 (극도로 빠르게)
                        original_vx = new_vx
                        if abs(new_vx) > max_x_speed:
                            new_vx = max_x_speed if new_vx > 0 else -max_x_speed
                            print(f"🌊 [포세이돈 DEBUG] X축 보정: {original_vx:.1f} → {new_vx:.1f} (속도 제한)")
                        
                        # 최종 속도 계산 및 출력
                        final_speed = math.sqrt(new_vx ** 2 + new_vy ** 2)
                        print(f"🌊 [포세이돈 DEBUG] 최종 튕김: vx={new_vx:.1f}, vy={new_vy:.1f}, 총속도={final_speed:.1f}")
                        
                        # 캡처 상태 해제 및 쿨다운 설정
                        self.ball_in_vortex = False
                        self.ball_vortex_timer = 0
                        self.vortex_cooldown = 30  # 0.5초 쿨다운
                        self.vortex_affected = True  # 회오리 효과를 받았음을 표시
                        self.speed_restored = False  # 속도 복원 플래그 초기화
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
        if abs(final_speed - original_speed) > 2.0:  # 속도가 2 이상 변했으면
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
        
        if self._update_debug_counter <= 3:
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
            if self._update_debug_counter <= 3:
                print(f"🔱 PoseidonTrident.update: active=False, 리턴")
            return
            
        # UI 모드에서는 아이콘 애니메이션만 업데이트하고 게임플레이 효과는 스킵
        if ui_mode:
            if self._update_debug_counter <= 3:
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
            if self._update_debug_counter <= 10:
                print(f"🌀 Vortex UPDATE: dt={dt:.4f}, timer={old_timer:.3f}→{self.vortex_timer:.3f}")
                print(f"   왼쪽 높이: {old_left_height:.1f} → ", end="")
            
            # 왼쪽 회오리 높이 급속 확장 (용솟음치는 효과)
            if self.vortex_left_height < self.vortex_max_height:
                self.vortex_left_height += 800 * dt  # 빠르게 상승
                if self._update_debug_counter <= 10:
                    print(f"{self.vortex_left_height:.1f} (증가: {800 * dt:.1f})")
            elif self._update_debug_counter <= 10:
                print(f"{self.vortex_left_height:.1f} (최대값 도달)")
            
            # 오른쪽 회오리 높이 급속 확장 (용솟음치는 효과)
            if self.vortex_right_height < self.vortex_max_height:
                self.vortex_right_height += 800 * dt  # 빠르게 상승
                
            # 매 0.5초마다 업데이트 상태 출력
            if int(self.vortex_timer * 2) != int((self.vortex_timer - dt) * 2):
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
        print(f"🔍 [on_boss_hit 호출됨] vortex_affected={self.vortex_affected}")
        if self.vortex_affected and self.boss_hit_count == 0:  # 첫 번째 히트만 카운트
            self.boss_hit_count += 1
            print(f"🔍 [보스 히트] boss_hit_count 증가: {self.boss_hit_count - 1} → {self.boss_hit_count}")
    
    def deactivate_water_trail(self):
        """물 궤적 비활성화 (보스가 공을 칠 때 호출)"""
        print(f"🔍 [deactivate_water_trail 호출됨] vortex_affected={self.vortex_affected}, water_trail_active={self.water_trail_active}")
        # 회오리 효과를 받은 공은 보스가 쳐도 궤적 유지
        if self.vortex_affected:
            print(f"🔱 포세이돈 삼지창: 회오리 효과 중이므로 물 궤적 유지")
            self.on_boss_hit()  # 보스 히트 카운트 증가
            return  # 궤적을 끄지 않음
            
        if self.water_trail_active:
            self.water_trail_active = False
            self.water_trail.clear()
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
    """헤르메스의 신발 - 이동속도 50% 증가"""
    def __init__(self):
        super().__init__(
            name="hermes_shoes",
            korean_name="헤르메스의 신발",
            description="패들 이동속도가 50% 증가합니다",
            unlock_condition="누적 이동 거리 100,000 픽셀 달성",
            icon_path="items/legendary/hermes_shoes.png"  # 아이콘 경로 추가
        )
        self.speed_multiplier = 1.5  # 50% 속도 증가
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
        
    def activate(self, game_state: Dict):
        """헤르메스의 신발 활성화"""
        super().activate(game_state)
        # pingfighter.py의 전역 변수 설정
        import pingfighter
        import items
        pingfighter.hermes_shoes_obtained = True
        items.hermes_shoes_obtained = True
        print(f"헤르메스의 신발 활성화! 이동속도 50% 증가!")
        
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
                print(f"✓ 헤르메스 신발 프레임 {i} 로드 성공")
            except Exception as e:
                print(f"[ERROR] Frame {i} load failed: {frame_path} - {e}")
        
        print(f"헤르메스 신발: 전용 프레임 {frames_loaded}/8개 로드")
        

        # 프레임이 없으면 에러만 표시 (가짜 애니메이션 생성하지 않음)
        if not self.animation_frames or len(self.animation_frames) == 0:
            print("❌ 헤르메스 신발: PNG 프레임을 찾을 수 없습니다!")
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
    """라그나로크 해머 - 강력한 넉백 효과"""
    def __init__(self):
        super().__init__(
            name="ragnarok_hammer",
            korean_name="라그나로크 해머",
            description="보스가 공을 받을 때 공속에 비례한 강력한 넉백을 받고 0.6초간 스턴됩니다",
            unlock_condition="누적 넉백 거리 10,000 픽셀 달성",
            icon_path=None  # 고유 애니메이션만 사용 (중앙 PNG 제거)
        )
        self.knockback_multiplier = 5.0  # 넉백 배율 (3.0 -> 5.0 증가)
        self.max_knockback = 250  # 최대 넉백 거리 (150 -> 250 증가)
        self.impact_particles = []  # 충격 파티클
        self.stun_duration = 0.6  # 넉백 후 스턴 시간 (초)
        
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
        
    def calculate_knockback(self, ball_speed: float, boss_x: float = 300) -> tuple:
        """
        공속에 비례한 수평 넉백 계산 (수류탄 방식)
        Returns: (horizontal_knockback_velocity, stun_duration)
        """
        if not self.active:
            return 0, 0
            
        magnitude = compute_knockback_magnitude("ragnarok", ball_speed=ball_speed)

        # 보스 위치에 따라 방향 결정
        center_x = 300  # 화면 중앙
        if boss_x + 50 < center_x:  # 보스가 왼쪽에 있으면
            horizontal_velocity = magnitude  # 오른쪽으로 넉백
        else:  # 보스가 오른쪽에 있으면
            horizontal_velocity = -magnitude  # 왼쪽으로 넉백

        print(f"[라그나로크 해머 calculate_knockback]")
        print(f"  - 입력 공속: {ball_speed:.1f}")
        print(f"  - 최종 넉백 속도: {horizontal_velocity:.1f}")
        print(f"  - 스턴 시간: {self.stun_duration:.1f}초")

        # 넉백 속도와 스턴 시간을 함께 반환
        return horizontal_velocity, self.stun_duration
        
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
                print(f"✓ 프레임 {i} 로드 성공: {frame_path}")
            except Exception as e:
                print(f"[ERROR] Frame {i} load failed: {frame_path} - {e}")

        print(f"라그나로크 해머 프레임 {frames_loaded}/8개 로드")

        if not self.animation_frames:
            print(f"❌ 라그나로크 해머: PNG 프레임을 찾을 수 없습니다!")
    
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
    """신성 월계수 - 6개의 월계수 잎이 플레이어 주변을 회전하며 공을 막아줌"""

    def __init__(self):
        super().__init__(
            name="sacred_laurel",
            korean_name="신성 월계수",
            description="6개의 신성한 월계수 잎이 플레이어 주변을 회전하며 보호. 공이 잎에 닿으면 잎이 제거되고, 모든 잎이 제거되면 30초 후 리스폰.",
            unlock_condition="전설 아이템 획득"
        )
        self.max_leaves = 6
        self.leaves = []
        self.leaf_radius = 200  # 가로 길이 400% (50 -> 100 -> 200)
        self.leaf_size = 12
        self.rotation_speed = 1.5
        self.current_angle = 0
        self.respawn_timer = 0
        self.respawn_delay = 30 * 60  # 모든 잎 파괴 시 전체 리스폰 (사용 안함)
        self.all_leaves_destroyed = False
        self.glow_intensity = 0
        self.glow_direction = 1
        self.removal_particles = []
        # 개별 잎 재생 시스템 (12초마다 1개씩)
        self.leaf_regen_timer = 0
        self.leaf_regen_delay = 12 * 60  # 12초 (60fps 기준)
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
        print(f"🌿 월계수 잎 1개 재생! (현재 {active_count}/{self.max_leaves}개)")

    def get_active_leaf_count(self):
        return sum(1 for leaf in self.leaves if leaf['active'])

    def check_ball_collision(self, ball_x, ball_y, ball_radius):
        if not self.active or self.all_leaves_destroyed:
            return False
        import math
        # 토성의 고리처럼 가로로 긴 타원 궤도 (ellipse_scale_y로 Y축 압축)
        ellipse_scale_y = 0.3  # Y축을 30%로 압축하여 가로로 납작한 고리 형성
        for leaf in self.leaves:
            if not leaf['active']:
                continue
            angle = self.current_angle + leaf['base_angle']
            # 가로로 긴 타원 궤도: X는 원형, Y는 압축
            leaf_x = self.player_x + math.cos(angle) * self.leaf_radius
            leaf_y = self.player_y + math.sin(angle) * self.leaf_radius * ellipse_scale_y
            dist = math.sqrt((ball_x - leaf_x)**2 + (ball_y - leaf_y)**2)
            if dist < ball_radius + self.leaf_size:
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
                print(f"[INFO] 빈전설 프레임 {i} 로드 실패: {e}")

        print(f"빈전설 프레임 {frames_loaded}/8개 로드")

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
    """천사의 가호 - 스테이지 시작 시 천사의 주사위로 버프 선택."""

    def __init__(self):
        super().__init__(
            name="angel_blessing",
            korean_name="천사의 가호",
            description="스테이지 시작 시 천사의 주사위를 굴려 1~3개의 랜덤 축복을 받습니다.",
            unlock_condition="전설 아이템 수집가 업적",
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

    def activate(self, game_state: Dict):
        """장착/획득 시 - 같은 스테이지에서는 재발동하지 않음."""
        super().activate(game_state)
        stage = None
        try:
            stage = int(game_state.get("current_stage")) if isinstance(game_state, dict) else None
        except Exception:
            stage = game_state.get("current_stage") if isinstance(game_state, dict) else None
        if stage is None:
            stage = self._get_current_stage()

        # 같은 스테이지에서 이미 주사위를 굴렸으면 다시 굴리지 않음 (재장착 방지)
        if stage is not None and stage in self._triggered_stages:
            print(f"[AngelBlessing] 스테이지 {stage}에서 이미 발동됨 - 재장착해도 재발동 안됨")
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
        if hasattr(items, "LEGENDARY_ITEM_SPAWN_MULT"):
            items.LEGENDARY_ITEM_SPAWN_MULT = 1.0
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
                print(f"[AngelBlessing] 대쉬 버프 초기화됨: cost=1.0, cooldown=1.0")
        except Exception:
            pass
        # 이동 속도 복구 (MAX_SPEED)
        if hasattr(self, "_original_max_speed") and self._original_max_speed is not None:
            if pf is not None and hasattr(pf, "MAX_SPEED"):
                pf.MAX_SPEED = self._original_max_speed
                print(f"[AngelBlessing] MAX_SPEED 복원: {self._original_max_speed}")
            self._original_max_speed = None
        # 가속도 복구 (ACCELERATION)
        if hasattr(self, "_original_acceleration") and self._original_acceleration is not None:
            if pf is not None and hasattr(pf, "ACCELERATION"):
                pf.ACCELERATION = self._original_acceleration
                print(f"[AngelBlessing] ACCELERATION 복원: {self._original_acceleration}")
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

        print(f"[AngelBlessing] 버프 효과 해제됨 - 모든 보너스 초기화")

    def _apply_buff(self, buff: str):
        """선택된 버프 적용"""
        import items
        import academy
        import sys
        pf = sys.modules.get("pingfighter")
        if buff == "paddle_size":
            self._set_global_multiplier("ANGEL_PADDLE_SCALE", 1.5)
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
        elif buff == "gauge_max":
            self._set_global_multiplier("ANGEL_GAUGE_MULT", 1.5)
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
        elif buff == "item_spawn":
            if hasattr(items, "LEGENDARY_ITEM_SPAWN_MULT"):
                items.LEGENDARY_ITEM_SPAWN_MULT = 1.5
        elif buff == "item_cooldown":
            academy.ANGEL_ITEM_COOLDOWN_MULTIPLIER = 0.5
        elif buff == "dash_cost":
            try:
                import dash_manager
                # _GLOBAL_DASH_INST 사용 (pingfighter.py에서 직접 참조하는 인스턴스)
                dm = dash_manager._GLOBAL_DASH_INST or dash_manager.get_dash_manager()
                if dm:
                    old_cost = getattr(dm, 'external_cost_multiplier', 1.0)
                    dm.set_external_multipliers(cost_mul=0.5)
                    new_cost = getattr(dm, 'external_cost_multiplier', 1.0)
                    print(f"[AngelBlessing] 대쉬 비용 버프 적용: {old_cost} -> {new_cost}")
                else:
                    print(f"[AngelBlessing] 대쉬 매니저를 찾을 수 없음")
            except Exception as e:
                print(f"[AngelBlessing] 대쉬 비용 버프 적용 실패: {e}")
        elif buff == "dash_cooldown":
            try:
                import dash_manager
                # _GLOBAL_DASH_INST 사용 (pingfighter.py에서 직접 참조하는 인스턴스)
                dm = dash_manager._GLOBAL_DASH_INST or dash_manager.get_dash_manager()
                if dm:
                    old_mul = getattr(dm, 'external_cooldown_multiplier', 1.0)
                    dm.set_external_multipliers(cooldown_mul=0.5)
                    new_mul = getattr(dm, 'external_cooldown_multiplier', 1.0)
                    print(f"[AngelBlessing] 대쉬 쿨타임 버프 적용: {old_mul} -> {new_mul}")
                else:
                    print(f"[AngelBlessing] 대쉬 매니저를 찾을 수 없음")
            except Exception as e:
                print(f"[AngelBlessing] 대쉬 쿨타임 버프 적용 실패: {e}")
        elif buff == "move_speed":
            # MAX_SPEED 증가 (실제 이동속도 결정 변수)
            try:
                if pf is not None and hasattr(pf, "MAX_SPEED"):
                    base_max_speed = getattr(pf, "MAX_SPEED", 5)
                    # 기본 MAX_SPEED 저장 (복원용) - 값이 None이거나 속성이 없으면 저장
                    if not hasattr(self, "_original_max_speed") or self._original_max_speed is None:
                        self._original_max_speed = base_max_speed
                    pf.MAX_SPEED = int(self._original_max_speed * 1.5)  # 항상 원본 기준으로 계산
                    self._set_global_multiplier("ANGEL_SPEED_MULT", 1.5)
                    print(f"[AngelBlessing] 이동속도 버프 적용: MAX_SPEED {self._original_max_speed} -> {pf.MAX_SPEED}")
                # ACCELERATION도 증가
                if pf is not None and hasattr(pf, "ACCELERATION"):
                    base_accel = getattr(pf, "ACCELERATION", 0.4)
                    # 기본 ACCELERATION 저장 (복원용) - 값이 None이거나 속성이 없으면 저장
                    if not hasattr(self, "_original_acceleration") or self._original_acceleration is None:
                        self._original_acceleration = base_accel
                    pf.ACCELERATION = self._original_acceleration * 1.3  # 항상 원본 기준으로 계산
                    print(f"[AngelBlessing] 가속도 버프 적용: ACCELERATION {self._original_acceleration} -> {pf.ACCELERATION}")
            except Exception as e:
                print(f"[AngelBlessing] 이동속도 버프 적용 실패: {e}")

    def deactivate(self):
        """천사의 가호 비활성화 - 모든 버프 효과 즉시 해제

        NOTE: applied_stage와 _triggered_stages는 유지하여 같은 스테이지 내
        재장착 시 재발동을 방지합니다.
        """
        print(f"[AngelBlessing] 비활성화 시작 - 현재 버프: {self.active_buffs}")
        super().deactivate()
        self._reset_globals()  # 모든 버프 효과 해제
        # applied_stage와 _triggered_stages는 유지 (같은 스테이지 내 재발동 방지)
        self.active_buffs.clear()
        self.roll_anim_active = False
        self.waiting_for_space = False
        print(f"[AngelBlessing] 비활성화 완료 - 버프 제거됨 (스테이지 {self.applied_stage} 발동 이력 유지)")

    def reset_for_new_game(self):
        """새 게임 시작 시 모든 발동 이력 초기화 (게임 오버/메인 메뉴 복귀 시 호출)"""
        self._triggered_stages.clear()
        self.applied_stage = None
        self.active_buffs.clear()
        self.roll_anim_active = False
        self.waiting_for_space = False
        print("[AngelBlessing] 새 게임 - 발동 이력 초기화됨")

    def _roll_blessing(self, current_stage: int):
        """주사위 굴림 및 버프 적용"""
        import random
        # 이미 발동된 스테이지면 스킵 (재장착 방지)
        if current_stage in self._triggered_stages:
            print(f"[AngelBlessing] 스테이지 {current_stage}에서 이미 발동됨 - 스킵")
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
        else:
            print(f"[AngelBlessing] Stage {current_stage} 주사위 {dice_face} → {selected}")

    def _load_animation_frames(self):
        """애니메이션 프레임 로드 - 라그나로크 해머 프레임에서 중앙 망치/번개만 제거"""
        self.animation_frames.clear()

        frames_loaded = 0
        for i in range(8):
            # 라그나로크 해머 프레임 사용
            frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
            try:
                frame = pygame.image.load(frame_path).convert_alpha()
                cleaned_frame = _strip_legendary_red_ring(frame)
                # 중앙 망치와 번개만 제거 (테두리/배경 효과 유지)
                center_cleared = self._clear_center_content(cleaned_frame)
                self.animation_frames.append(center_cleared)
                frames_loaded += 1
                print(f"✓ 천사의 가호 프레임 {i} 로드 성공 (중앙 제거): {frame_path}")
            except Exception as e:
                print(f"[INFO] 천사의 가호 프레임 {i} 로드 실패: {e}")

        print(f"천사의 가호 프레임 {frames_loaded}/8개 로드 (중앙 제거)")

        # PNG 프레임이 없으면 동적으로 주사위 프레임 생성
        if not self.animation_frames:
            self._generate_dice_frames()

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

        print(f"천사의 가호: 주사위 프레임 8개 동적 생성 완료")

    def _draw_dice_to_surface(self, surf, size, rot_x, rot_y):
        """주사위를 서피스에 그리기 - 천사 날개 포함"""
        dice_size = int(size * 0.5)  # 주사위 크기 확대
        cx, cy = size // 2, size // 2

        # 천사 날개 그리기 (주사위 뒤에)
        wing_color = (255, 255, 255, 180)
        wing_glow = (200, 220, 255, 100)
        wing_width = int(size * 0.35)
        wing_height = int(size * 0.25)

        # 날개 펄럭임 효과
        wing_flap = math.sin(rot_y * 0.1) * 3

        # 왼쪽 날개
        left_wing_points = [
            (cx - 3, cy - 2),  # 중앙 연결점
            (cx - wing_width, cy - wing_height + wing_flap),  # 상단
            (cx - wing_width - 3, cy + wing_flap),  # 중간 끝
            (cx - wing_width + 5, cy + wing_height//2 + wing_flap),  # 하단
            (cx - 3, cy + 3),  # 중앙 하단 연결점
        ]

        # 오른쪽 날개
        right_wing_points = [
            (cx + 3, cy - 2),  # 중앙 연결점
            (cx + wing_width, cy - wing_height + wing_flap),  # 상단
            (cx + wing_width + 3, cy + wing_flap),  # 중간 끝
            (cx + wing_width - 5, cy + wing_height//2 + wing_flap),  # 하단
            (cx + 3, cy + 3),  # 중앙 하단 연결점
        ]

        # 날개 글로우 효과
        pygame.draw.polygon(surf, wing_glow, left_wing_points)
        pygame.draw.polygon(surf, wing_glow, right_wing_points)

        # 날개 본체
        pygame.draw.polygon(surf, wing_color, left_wing_points)
        pygame.draw.polygon(surf, wing_color, right_wing_points)

        # 날개 깃털 라인
        feather_color = (220, 230, 255, 150)
        for i in range(3):
            offset = (i + 1) * wing_width // 4
            pygame.draw.line(surf, feather_color,
                           (cx - 5, cy),
                           (cx - offset - 5, cy - wing_height//2 + i*3 + wing_flap), 1)
            pygame.draw.line(surf, feather_color,
                           (cx + 5, cy),
                           (cx + offset + 5, cy - wing_height//2 + i*3 + wing_flap), 1)

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

            # 1. 빛나는 광선 (회전하는 신성한 빛줄기)
            ray_count = 8
            for ray_i in range(ray_count):
                ray_angle = (self.animation_time * 40 + ray_i * (360 / ray_count)) % 360
                ray_rad = math.radians(ray_angle)
                ray_length = int(size * 0.38 + math.sin(self.animation_time * 5 + ray_i) * 3)
                inner_r = int(size * 0.22)

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

            # 3. 반짝이는 별 파티클 (주사위 주변을 도는 작은 별들)
            star_count = 6
            for star_i in range(star_count):
                # 각 별이 다른 속도와 궤도로 회전
                star_angle = (self.animation_time * (60 + star_i * 10) + star_i * 60) % 360
                star_rad = math.radians(star_angle)
                orbit_radius = int(size * 0.32 + math.sin(self.animation_time * 2 + star_i) * 4)

                star_x = aura_cx + int(math.cos(star_rad) * orbit_radius)
                star_y = aura_cy + int(math.sin(star_rad) * orbit_radius)

                # 별 크기 맥동
                star_size = int(2 + math.sin(self.animation_time * 8 + star_i * 1.5) * 1.5)
                star_alpha = int(180 + math.sin(self.animation_time * 6 + star_i) * 60)

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

    def _draw_2d_dice_result(self, screen: pygame.Surface, cx: int, cy: int, size: int, result: int):
        """2D 주사위 결과 그리기 - 결과 숫자만 명확하게 표시

        Args:
            screen: 화면 Surface
            cx, cy: 중심 좌표
            size: 주사위 크기
            result: 주사위 결과 (1-6)
        """
        half = size // 2

        # 천사 날개 (주사위 뒤에)
        wing_color = (255, 255, 255, 220)
        wing_width = int(size * 0.35)
        wing_height = int(size * 0.25)
        wing_flap = math.sin(pygame.time.get_ticks() * 0.005) * 3

        # 왼쪽 날개
        left_wing = [
            (cx - half//2, cy),
            (cx - half - wing_width, cy - wing_height + wing_flap),
            (cx - half - wing_width - 5, cy + wing_flap),
            (cx - half - wing_width + 10, cy + wing_height//2 + wing_flap),
            (cx - half//2, cy + 5),
        ]
        # 오른쪽 날개
        right_wing = [
            (cx + half//2, cy),
            (cx + half + wing_width, cy - wing_height + wing_flap),
            (cx + half + wing_width + 5, cy + wing_flap),
            (cx + half + wing_width - 10, cy + wing_height//2 + wing_flap),
            (cx + half//2, cy + 5),
        ]
        pygame.draw.polygon(screen, wing_color, left_wing)
        pygame.draw.polygon(screen, wing_color, right_wing)

        # 깃털 디테일
        feather_color = (230, 240, 255, 180)
        for i in range(3):
            offset = (i + 1) * wing_width // 3
            pygame.draw.line(screen, feather_color,
                           (cx - half//2, cy),
                           (cx - half - offset, cy - wing_height//2 + i*4 + wing_flap), 1)
            pygame.draw.line(screen, feather_color,
                           (cx + half//2, cy),
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
        cx, cy = size // 2, size // 2

        # 천사 날개 그리기 (주사위 뒤에)
        wing_color = (255, 255, 255, 200)
        wing_glow = (220, 230, 255, 120)
        wing_width = int(size * 0.32)
        wing_height = int(size * 0.22)

        # 날개 펄럭임 효과
        wing_flap = math.sin(rot_y * 0.1) * 3

        # 왼쪽 날개
        left_wing_points = [
            (cx - 3, cy - 2),
            (cx - wing_width, cy - wing_height + wing_flap),
            (cx - wing_width - 3, cy + wing_flap),
            (cx - wing_width + 5, cy + wing_height//2 + wing_flap),
            (cx - 3, cy + 3),
        ]

        # 오른쪽 날개
        right_wing_points = [
            (cx + 3, cy - 2),
            (cx + wing_width, cy - wing_height + wing_flap),
            (cx + wing_width + 3, cy + wing_flap),
            (cx + wing_width - 5, cy + wing_height//2 + wing_flap),
            (cx + 3, cy + 3),
        ]

        # 날개 글로우 효과
        pygame.draw.polygon(surf, wing_glow, left_wing_points)
        pygame.draw.polygon(surf, wing_glow, right_wing_points)

        # 날개 본체
        pygame.draw.polygon(surf, wing_color, left_wing_points)
        pygame.draw.polygon(surf, wing_color, right_wing_points)

        # 날개 깃털 라인
        feather_color = (230, 240, 255, 180)
        for i in range(3):
            offset = (i + 1) * wing_width // 4
            pygame.draw.line(surf, feather_color,
                           (cx - 5, cy),
                           (cx - offset - 5, cy - wing_height//2 + i*3 + wing_flap), 1)
            pygame.draw.line(surf, feather_color,
                           (cx + 5, cy),
                           (cx + offset + 5, cy - wing_height//2 + i*3 + wing_flap), 1)

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
            title_surf, title_rect = title_font.render("천사의 가호", (220, 200, 255))
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

            # 회전하는 천사 깃털 파티클 (주사위 뒤에 먼저 그리기)
            num_feathers = 8
            for i in range(num_feathers):
                feather_angle = (i / num_feathers) * math.pi * 2 + anim_time * 3
                feather_dist = 60 + 30 * math.sin(anim_time * 4 + i * 0.5)
                # 주사위 바운스 위치를 따라감
                feather_x = actual_dice_x + math.cos(feather_angle) * feather_dist
                feather_y = actual_dice_y + math.sin(feather_angle) * feather_dist

                # 깃털 모양 (대칭 타원) - 깃털이 궤도 방향으로 회전
                feather_size = 4 + int(3 * math.sin(anim_time * 6 + i))
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

            # 3D 주사위 그리기 (깃털 위에)
            dice_surf = pygame.Surface((dice_size + 40, dice_size + 40), pygame.SRCALPHA)
            self._draw_angel_dice(dice_surf, dice_size, rot_x, rot_y)
            dice_rect = dice_surf.get_rect(center=(int(actual_dice_x), int(actual_dice_y)))
            screen.blit(dice_surf, dice_rect)

            # 반짝이는 별 파티클 (주사위 주변, 바운스 따라감)
            for _ in range(3):
                star_offset_x = random.randint(-80, 80)
                star_offset_y = random.randint(-80, 80)
                star_x = int(actual_dice_x + star_offset_x)
                star_y = int(actual_dice_y + star_offset_y)
                star_size = random.randint(2, 5)
                star_alpha = random.randint(150, 255)
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

        # 버프 이름 (한글/영문)
        buff_names_kr = {
            "paddle_size": "패들 크기 +50%",
            "gauge_max": "최대 게이지 +50%",
            "item_spawn": "아이템 스폰률 +50%",
            "item_cooldown": "아이템 쿨타임 -50%",
            "dash_cost": "대쉬 비용 -50%",
            "dash_cooldown": "대쉬 쿨타임 -50%",
            "move_speed": "이동 속도 +50%",
        }
        buff_names_en = {
            "paddle_size": "Paddle Size +50%",
            "gauge_max": "Max Gauge +50%",
            "item_spawn": "Item Spawn +50%",
            "item_cooldown": "Item Cooldown -50%",
            "dash_cost": "Dash Cost -50%",
            "dash_cooldown": "Dash Cooldown -50%",
            "move_speed": "Move Speed +50%",
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
                result_surf, result_rect = small_font.render(f"주사위 결과: {self.roll_face}", (255, 220, 150))
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
                    prompt_surf, prompt_rect = small_font.render("스페이스바를 눌러 계속하기", (255, 255, blink))
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
                rolling_surf, rolling_rect = small_font.render("주사위를 굴리는 중...", (200, 180, 255))
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
            print(f"[AngelBlessing] 주사위 애니메이션 종료 - applied_stage: {self.applied_stage}")
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
                    print(f"[AngelBlessing] 주사위 결과 표시 - 스페이스바 대기 중...")

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
            description="전설 슬롯을 비워두기 위한 플레이스홀더",
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

        print(f"[INFO] empty 전설 슬롯: 투명 프레임 {total_frames}개 생성 (테두리 효과만 표시)")

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

        print(f"[INFO] empty2 전설 슬롯: 라그나로크 스타일 빈 프레임 8개 생성 (테두리/글로우만 표시)")

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
        # empty/empty1/empty2 보정 생성하지 않음
        
    def check_unlocks(self, game_stats: Dict):
        """해금 조건 체크"""
        for item_name, item in self.items.items():
            if not item.unlocked and item.check_unlock_condition(game_stats):
                item.unlocked = True
                self.unlocked_items.append(item_name)
                print(f"   [{item.korean_name}] !")
                
    def get_unlocked_items(self) -> List[LegendaryItem]:
        """해금된 아이템 목록 반환"""
        return [self.items[name] for name in self.unlocked_items]
        
    def get_item(self, name: str) -> Optional[LegendaryItem]:
        """아이템 가져오기"""
        return self.items.get(name)
        
    def activate_item(self, name: str, game_state: Dict):
        """아이템 활성화"""
        if name in PLACEHOLDER_LEGENDARY_NAMES:
            return
        if name in self.items:
            # 아이템이 해금되지 않았으면 자동으로 해금
            if name not in self.unlocked_items:
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
            print(f"🎮 activate_item 호출: name={name}")
            print(f"   - items에 있음: {name in self.items}")
            print(f"   - unlocked_items에 있음: {name in self.unlocked_items}")
            print(f"   - unlocked_items: {self.unlocked_items}")
            
            item = self.items[name]
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
                print(f"   ✅ {name}을 active_items에 추가: {self.active_items}")
            else:
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

        print(f"🎮 모든 전설 아이템 라운드 효과 초기화 완료")

    def reset_for_new_game(self):
        """새 게임 시작 시 모든 아이템 발동 이력 초기화 (게임 오버/메인 메뉴 복귀 시 호출)"""
        for name, item in self.items.items():
            # reset_for_new_game 메서드가 있는 아이템만 호출
            if hasattr(item, 'reset_for_new_game'):
                item.reset_for_new_game()
        print(f"🎮 모든 전설 아이템 새 게임 초기화 완료")


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
