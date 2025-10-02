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

    for y in range(height):
        for x in range(width):
            color = surface.get_at((x, y))
            if color.a == 0:
                continue

            near_edge = x < 6 or x >= width - 6 or y < 6 or y >= height - 6
            red_dominant = color.r > 170 and color.r > color.g + 20 and color.r > color.b + 20
            warm_highlight = color.r > 200 and color.g > 120 and color.b > 80

            if near_edge or red_dominant or warm_highlight:
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
                                 corner_style: str = "default") -> int:
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


class RagnarokHammer(LegendaryItem):
    """라그나로크 해머 - 강력한 넉백 효과"""
    def __init__(self):
        super().__init__(
            name="ragnarok_hammer",
            korean_name="라그나로크 해머",
            description="보스가 공을 받을 때 공속에 비례한 강력한 넉백을 받고 0.6초간 스턴됩니다",
            unlock_condition="누적 넉백 거리 10,000 픽셀 달성",
            icon_path="items/legendary/ragnarok_hammer.png"  # 아이콘 경로 추가
        )
        self.knockback_multiplier = 5.0  # 넉백 배율 (3.0 -> 5.0 증가)
        self.max_knockback = 250  # 최대 넉백 거리 (150 -> 250 증가)
        self.thunder_effects = []  # 번개 효과 리스트
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

        # 번개 효과 추가
        self._spawn_thunder_effect()
        
        print(f"[라그나로크 해머 calculate_knockback]")
        print(f"  - 입력 공속: {ball_speed:.1f}")
        print(f"  - 최종 넉백 속도: {horizontal_velocity:.1f}")
        print(f"  - 스턴 시간: {self.stun_duration:.1f}초")
        
        # 넉백 속도와 스턴 시간을 함께 반환
        return horizontal_velocity, self.stun_duration
        
    def _spawn_thunder_effect(self):
        """번개 효과 생성"""
        import random
        import time
        self.thunder_effects.append({
            'time': time.time(),
            'duration': 0.5,
            'intensity': random.uniform(0.7, 1.0)
        })
        
    def draw_special_effects(self, screen, boss_x: int, boss_y: int):
        """특수 효과 그리기"""
        if not self.active:
            return
            
        import pygame
        import math
        import random
        import time
        
        current_time = time.time()
        
        # 번개 효과 그리기
        for effect in self.thunder_effects[:]:
            elapsed = current_time - effect['time']
            if elapsed > effect['duration']:
                self.thunder_effects.remove(effect)
                continue
                
            alpha = int(255 * (1 - elapsed / effect['duration']))
            
            # 번개 가지 그리기
            for _ in range(3):
                start_x = boss_x + random.randint(-30, 30)
                start_y = boss_y - 50
                end_x = boss_x + random.randint(-50, 50)
                end_y = boss_y + random.randint(-20, 20)
                
                # 지그재그 번개
                points = [(start_x, start_y)]
                segments = 5
                for i in range(segments):
                    t = (i + 1) / segments
                    x = start_x + (end_x - start_x) * t + random.randint(-20, 20)
                    y = start_y + (end_y - start_y) * t
                    points.append((x, y))
                points.append((end_x, end_y))
                
                # 번개 그리기 (두께 변화)
                for i in range(len(points) - 1):
                    thickness = max(1, int(5 * (1 - i / len(points)) * effect['intensity']))
                    color = (255, 255, min(255, 100 + alpha), alpha)
                    pygame.draw.line(screen, color[:3], points[i], points[i+1], thickness)
        
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
        import os
        
        # 8개 프레임 로드 시도
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
        
        # 프레임이 없으면 에러만 표시 (가짜 애니메이션 생성하지 않음)
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
            
            # 번개 효과 추가 (프레임 0, 4에서)
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
        poseidon_ref = self.items.get("poseidon_trident")
        
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
        print(f"🎮 activate_item 호출: name={name}")
        print(f"   - items에 있음: {name in self.items}")
        print(f"   - unlocked_items에 있음: {name in self.unlocked_items}")
        print(f"   - unlocked_items: {self.unlocked_items}")
        
        if name in self.items:
            # 아이템이 해금되지 않았으면 자동으로 해금
            if name not in self.unlocked_items:
                print(f"   ⚠️ {name}이 unlocked_items에 없음! 자동 추가")
                self.unlocked_items.append(name)
                self.items[name].unlocked = True
            
            item = self.items[name]
            item.activate(game_state)
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
            
        if self._debug_counter == 1:
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
