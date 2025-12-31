"""
대쉬부스트 아이템 효과
8초동안 대쉬비용이 100% 할인(무료)되고 대쉬토큰 쿨타임이 99% 감소(거의 즉시충전)됩니다.
타이머형 액티브 아이템
"""

import os
import pygame
import math

# 상수
DASH_BOOST_DURATION_FRAMES = 480  # 8초 (60fps * 8)
DASH_BOOST_COST_DISCOUNT = 1.00  # 100% 할인 (대쉬 무료)
DASH_BOOST_COOLDOWN_REDUCTION = 0.99  # 99% 쿨타임 감소 (거의 즉시충전)


class DashBoost:
    def __init__(self):
        self.active = False
        self.duration = DASH_BOOST_DURATION_FRAMES
        self.timer = 0
        self.initial_timer = 0  # 가로형 타이머 게이지용 초기값
        self.particles = []  # 파티클 효과
        self.glow_phase = 0  # 글로우 애니메이션 위상
        self.width = 600  # 화면 너비
        self.height = 750  # 화면 높이
        self.debug = os.environ.get("DEBUG_DASH_BOOST", "0") == "1"

    def activate(self, game_state=None, current_stage=None, width=600, height=750):
        """대쉬부스트 활성화"""
        self.active = True
        self.width = width
        self.height = height

        # 카페인 스킬 효과 적용 (타이머형 아이템 지속시간 증가) - 아카데미 + 런타임 스킬
        frames = DASH_BOOST_DURATION_FRAMES
        try:
            import academy
            caffeine_multiplier = academy.get_caffeine_duration_multiplier()
            frames = int(frames * caffeine_multiplier)
        except (ImportError, AttributeError):
            pass
        # 런타임 스킬 보너스 추가 적용
        try:
            import pingfighter
            runtime_level = pingfighter.runtime_skill_levels.get("item_caffeine", 0)
            if runtime_level > 0:
                runtime_bonus = runtime_level * 0.25
                frames = int(frames * (1 + runtime_bonus))
        except (ImportError, AttributeError):
            pass

        self.timer = frames
        self.initial_timer = frames  # 초기값 저장

        # 파티클 초기화
        self.particles = []
        self.glow_phase = 0

        if self.debug:
            print(f"[DASH_BOOST] 활성화! 지속시간: {self.timer/60:.1f}초")

    def deactivate(self):
        """대쉬부스트 비활성화"""
        self.active = False
        self.timer = 0
        self.particles.clear()

        if self.debug:
            print("[DASH_BOOST] 비활성화")

    def update(self, current_stage=None):
        """상태 업데이트"""
        if not self.active:
            return

        # 타이머 감소
        self.timer -= 1
        if self.timer <= 0:
            self.deactivate()
            return

        # 글로우 애니메이션 업데이트
        self.glow_phase += 0.15

        # 파티클 생성 (3프레임마다)
        if self.timer % 3 == 0:
            import random
            for _ in range(2):
                particle = {
                    'x': random.randint(50, self.width - 50),
                    'y': self.height - random.randint(30, 80),
                    'vx': random.uniform(-1, 1),
                    'vy': random.uniform(-2, -0.5),
                    'size': random.randint(2, 4),
                    'alpha': 200,
                    'color': random.choice([
                        (100, 200, 255),  # 시안
                        (150, 255, 200),  # 민트
                        (200, 150, 255),  # 라벤더
                        (255, 200, 100),  # 골드
                    ])
                }
                self.particles.append(particle)

        # 파티클 업데이트
        for particle in self.particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['alpha'] -= 6
            particle['size'] = max(1, particle['size'] - 0.05)
            if particle['alpha'] <= 0:
                self.particles.remove(particle)

    def is_unlimited_dash(self):
        """대쉬 토큰 무제한 여부 반환 (비활성화됨 - 항상 False)"""
        return False  # 토큰 무제한 기능 제거

    def get_cost_multiplier(self):
        """대쉬 비용 배율 반환 (활성화시 0.0, 비활성화시 1.0)"""
        if self.active:
            return 1.0 - DASH_BOOST_COST_DISCOUNT  # 100% 할인 = 0.0배 (무료)
        return 1.0

    def get_cooldown_multiplier(self):
        """대쉬 쿨타임 배율 반환 (활성화시 0.01, 비활성화시 1.0)"""
        if self.active:
            return 1.0 - DASH_BOOST_COOLDOWN_REDUCTION  # 99% 감소 = 0.01배 (거의 즉시)
        return 1.0

    def draw_effects(self, screen, player_rect=None, **kwargs):
        """대쉬부스트 효과 그리기"""
        if not self.active:
            return

        # 파티클 그리기
        for particle in self.particles:
            if particle['alpha'] > 0:
                particle_surf = pygame.Surface(
                    (particle['size'] * 2 + 4, particle['size'] * 2 + 4),
                    pygame.SRCALPHA
                )
                color = (*particle['color'], int(particle['alpha']))
                pygame.draw.circle(
                    particle_surf, color,
                    (particle['size'] + 2, particle['size'] + 2),
                    int(particle['size'])
                )
                # 글로우 효과
                glow_color = (*particle['color'], int(particle['alpha'] * 0.3))
                pygame.draw.circle(
                    particle_surf, glow_color,
                    (particle['size'] + 2, particle['size'] + 2),
                    int(particle['size'] * 1.5)
                )
                screen.blit(
                    particle_surf,
                    (int(particle['x'] - particle['size'] - 2),
                     int(particle['y'] - particle['size'] - 2))
                )

        # 플레이어 주변 대쉬 오라 효과
        if player_rect:
            pulse = abs(math.sin(self.glow_phase))

            # 오라 서페이스
            aura_size = 60 + int(10 * pulse)
            aura_surf = pygame.Surface((aura_size * 2, aura_size * 2), pygame.SRCALPHA)

            # 여러 겹의 오라
            for i in range(3):
                radius = aura_size - i * 15
                alpha = int(30 + 20 * pulse) - i * 10
                if radius > 0 and alpha > 0:
                    color = (100, 200, 255, alpha)  # 시안 오라
                    pygame.draw.circle(aura_surf, color, (aura_size, aura_size), radius, 2)

            # 속도선 효과
            for i in range(4):
                angle = self.glow_phase + i * (math.pi / 2)
                length = 20 + 10 * pulse
                start_x = aura_size + math.cos(angle) * 25
                start_y = aura_size + math.sin(angle) * 25
                end_x = aura_size + math.cos(angle) * (25 + length)
                end_y = aura_size + math.sin(angle) * (25 + length)
                pygame.draw.line(
                    aura_surf, (150, 255, 200, int(100 * pulse)),
                    (start_x, start_y), (end_x, end_y), 2
                )

            screen.blit(
                aura_surf,
                (player_rect.centerx - aura_size, player_rect.centery - aura_size)
            )

    def get_remaining_time(self):
        """남은 시간을 초 단위로 반환"""
        if not self.active:
            return 0.0
        return self.timer / 60.0

    def get_remaining_ratio(self):
        """남은 시간 비율 반환 (0.0 ~ 1.0)"""
        if not self.active or self.initial_timer <= 0:
            return 0.0
        return self.timer / self.initial_timer


# 싱글톤 인스턴스
dash_boost_instance = None


def get_dash_boost_instance():
    global dash_boost_instance
    if dash_boost_instance is None:
        dash_boost_instance = DashBoost()
    return dash_boost_instance


def activate_dash_boost(game_state=None, current_stage=None, width=600, height=750):
    """대쉬부스트 활성화"""
    boost = get_dash_boost_instance()
    boost.activate(game_state, current_stage, width, height)
    return True


def deactivate_dash_boost():
    """대쉬부스트 비활성화"""
    boost = get_dash_boost_instance()
    boost.deactivate()


def update_dash_boost(current_stage=None):
    """대쉬부스트 업데이트"""
    boost = get_dash_boost_instance()
    boost.update(current_stage)


def draw_dash_boost_effects(screen, player_rect=None, **kwargs):
    """대쉬부스트 효과 그리기"""
    boost = get_dash_boost_instance()
    boost.draw_effects(screen, player_rect, **kwargs)


def get_dash_boost_remaining_time():
    """남은 시간 반환 (초)"""
    boost = get_dash_boost_instance()
    return boost.get_remaining_time()


def get_dash_boost_remaining_ratio():
    """남은 시간 비율 반환"""
    boost = get_dash_boost_instance()
    return boost.get_remaining_ratio()


def is_dash_boost_active():
    """대쉬부스트 활성화 여부"""
    boost = get_dash_boost_instance()
    return boost.active


def is_dash_unlimited():
    """대쉬 토큰 무제한 여부 (비활성화됨 - 항상 False)"""
    return False  # 토큰 무제한 기능 제거, 대쉬비용 할인만 적용


def get_dash_cost_multiplier():
    """대쉬 비용 배율 반환 (0.0 = 100% 할인, 무료)"""
    boost = get_dash_boost_instance()
    return boost.get_cost_multiplier()


def get_dash_cooldown_multiplier():
    """대쉬 쿨타임 배율 반환 (0.01 = 99% 감소, 거의 즉시충전)"""
    boost = get_dash_boost_instance()
    return boost.get_cooldown_multiplier()


def configure_dash_boost(duration_sec: float = None, discount_pct: float = None) -> None:
    """롤 옵션에서 받은 설정을 적용

    Args:
        duration_sec: 지속 시간(초)
        discount_pct: 할인율(%) - 0~100
    """
    global DASH_BOOST_COST_DISCOUNT
    boost = get_dash_boost_instance()
    if duration_sec is not None:
        boost.duration = max(1, int(duration_sec * 60))
    if discount_pct is not None:
        DASH_BOOST_COST_DISCOUNT = max(0.0, min(1.0, discount_pct / 100.0))
