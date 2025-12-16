"""
클렌즈 스킬 - 스매셔 전용 상태이상 해제 스킬
N키를 빠르게 2번 누르면 발동
게이지 소모: 100
효과: 모든 상태이상(스턴, 둔화, 넉백) 즉시 해제
"""

import pygame
import math
import random

# 클렌즈 스킬 설정
CLEANSE_GAUGE_COST = 100           # 게이지 소모량
CLEANSE_DOUBLE_TAP_WINDOW = 300    # 더블탭 인식 시간 (ms)
CLEANSE_COOLDOWN = 60              # 쿨다운 (프레임, 1초)
CLEANSE_IMMUNITY_DURATION = 60     # 면역 지속 시간 (프레임, 1초)

class CleanseSkill:
    """스매셔 클렌즈 스킬 - 플라즈마 파동으로 상태이상 해제"""

    def __init__(self):
        # 더블탭 감지
        self.last_n_press_time = 0
        self.cooldown_timer = 0

        # 면역 상태 (클렌즈 발동 후 1초간 상태이상 면역)
        self.immunity_timer = 0

        # 애니메이션 상태
        self.active = False
        self.animation_timer = 0
        self.animation_duration = 30  # 0.5초 애니메이션

        # 파동 이펙트
        self.wave_rings = []  # 확산되는 링들
        self.particles = []   # 에너지 파티클
        self.center_x = 0
        self.center_y = 0

        # 플래시 효과
        self.flash_alpha = 0

        # 면역 이펙트 (플레이어 주변 보호막)
        self.shield_particles = []

    def can_activate(self, special_gauge, has_status_effect=True):
        """클렌즈 발동 가능 여부 확인"""
        if self.cooldown_timer > 0:
            return False
        if special_gauge < CLEANSE_GAUGE_COST:
            return False
        if self.active:
            return False
        if not has_status_effect:
            return False
        return True

    def check_double_tap(self, current_time):
        """N키 더블탭 감지"""
        if current_time - self.last_n_press_time <= CLEANSE_DOUBLE_TAP_WINDOW:
            # 더블탭 성공
            self.last_n_press_time = 0
            return True
        else:
            # 첫 번째 탭 기록
            self.last_n_press_time = current_time
            return False

    def activate(self, player_x, player_y):
        """클렌즈 스킬 발동"""
        self.active = True
        self.animation_timer = self.animation_duration
        self.center_x = player_x
        self.center_y = player_y
        self.cooldown_timer = CLEANSE_COOLDOWN

        # 면역 타이머 시작 (1초간 상태이상 면역)
        self.immunity_timer = CLEANSE_IMMUNITY_DURATION

        # 플래시 효과 초기화
        self.flash_alpha = 255

        # 파동 링 생성 (3개의 링이 순차적으로 퍼져나감)
        self.wave_rings = []
        for i in range(3):
            self.wave_rings.append({
                'radius': 10,
                'max_radius': 120 + i * 40,
                'alpha': 255,
                'thickness': 4 - i,
                'delay': i * 5,  # 순차적 발동
                'started': False
            })

        # 에너지 파티클 생성 (플라즈마 효과)
        self.particles = []
        for _ in range(40):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(3, 8)
            self.particles.append({
                'x': player_x,
                'y': player_y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'size': random.randint(3, 8),
                'alpha': 255,
                'color_shift': random.uniform(0, 1),  # 색상 변화
                'life': random.randint(20, 35)
            })

        print(f"✨ [CLEANSE] 클렌즈 스킬 발동! 위치: ({player_x}, {player_y})")
        return True

    def is_immune(self):
        """상태이상 면역 상태인지 확인"""
        return self.immunity_timer > 0

    def update(self):
        """애니메이션 업데이트"""
        # 쿨다운 감소
        if self.cooldown_timer > 0:
            self.cooldown_timer -= 1

        # 면역 타이머 감소
        if self.immunity_timer > 0:
            self.immunity_timer -= 1

        if not self.active and self.immunity_timer <= 0:
            return

        self.animation_timer -= 1

        # 플래시 효과 감소
        if self.flash_alpha > 0:
            self.flash_alpha = max(0, self.flash_alpha - 30)

        # 파동 링 업데이트
        for ring in self.wave_rings:
            if not ring['started']:
                if ring['delay'] <= 0:
                    ring['started'] = True
                else:
                    ring['delay'] -= 1
                continue

            # 링 확장
            expansion_speed = (ring['max_radius'] - 10) / 20  # 20프레임에 걸쳐 확장
            ring['radius'] = min(ring['radius'] + expansion_speed, ring['max_radius'])

            # 알파 감소 (확장하면서 투명해짐)
            progress = (ring['radius'] - 10) / (ring['max_radius'] - 10)
            ring['alpha'] = int(255 * (1 - progress * 0.8))

        # 파티클 업데이트
        for particle in self.particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['vx'] *= 0.95  # 감속
            particle['vy'] *= 0.95
            particle['life'] -= 1
            particle['alpha'] = int(255 * (particle['life'] / 35))

            if particle['life'] <= 0:
                self.particles.remove(particle)

        # 애니메이션 종료
        if self.animation_timer <= 0:
            self.active = False
            self.wave_rings = []
            self.particles = []

    def draw(self, screen, screen_shake_offset_x=0, screen_shake_offset_y=0):
        """클렌즈 이펙트 그리기"""
        if not self.active:
            return

        offset_x = screen_shake_offset_x
        offset_y = screen_shake_offset_y

        # 플래시 효과 (화면 전체에 밝은 빛)
        if self.flash_alpha > 0:
            flash_surface = pygame.Surface((screen.get_width(), screen.get_height()), pygame.SRCALPHA)
            flash_surface.fill((200, 220, 255, min(100, self.flash_alpha // 3)))
            screen.blit(flash_surface, (0, 0))

        # 파동 링 그리기 (플라즈마 색상: 청록 ~ 보라)
        for ring in self.wave_rings:
            if not ring['started'] or ring['alpha'] <= 0:
                continue

            # 내부 글로우 효과
            glow_surf = pygame.Surface((ring['max_radius'] * 2 + 20, ring['max_radius'] * 2 + 20), pygame.SRCALPHA)
            center = (ring['max_radius'] + 10, ring['max_radius'] + 10)

            # 외부 글로우 (청록색)
            for i in range(3):
                glow_alpha = max(0, ring['alpha'] // (3 + i))
                glow_radius = int(ring['radius']) + (2 - i) * 3
                if glow_radius > 0:
                    pygame.draw.circle(
                        glow_surf,
                        (100, 200, 255, glow_alpha),
                        center,
                        glow_radius,
                        max(1, ring['thickness'] + i)
                    )

            # 메인 링 (밝은 흰색/청록)
            if int(ring['radius']) > 0:
                pygame.draw.circle(
                    glow_surf,
                    (220, 240, 255, ring['alpha']),
                    center,
                    int(ring['radius']),
                    max(1, ring['thickness'])
                )

            # 화면에 블릿
            screen.blit(
                glow_surf,
                (self.center_x - ring['max_radius'] - 10 + offset_x,
                 self.center_y - ring['max_radius'] - 10 + offset_y)
            )

        # 에너지 파티클 그리기
        for particle in self.particles:
            if particle['alpha'] <= 0:
                continue

            # 색상 변화 (청록 → 보라 그라데이션)
            t = particle['color_shift']
            r = int(100 + 155 * t)
            g = int(200 - 100 * t)
            b = 255

            # 파티클 코어
            pygame.draw.circle(
                screen,
                (r, g, b, min(255, particle['alpha'])),
                (int(particle['x'] + offset_x), int(particle['y'] + offset_y)),
                particle['size']
            )

            # 파티클 글로우
            if particle['size'] > 3:
                pygame.draw.circle(
                    screen,
                    (r, g, b, particle['alpha'] // 3),
                    (int(particle['x'] + offset_x), int(particle['y'] + offset_y)),
                    particle['size'] + 3
                )

        # 중앙 에너지 코어 (발동 초기에만)
        if self.animation_timer > self.animation_duration - 10:
            core_alpha = min(255, (self.animation_duration - self.animation_timer + 10) * 25)
            core_size = 15 + (10 - (self.animation_duration - self.animation_timer)) * 2

            # 코어 글로우
            for i in range(4):
                pygame.draw.circle(
                    screen,
                    (150, 220, 255, max(0, core_alpha // (i + 1))),
                    (int(self.center_x + offset_x), int(self.center_y + offset_y)),
                    int(core_size + i * 5),
                    2
                )

    def draw_immunity_shield(self, screen, player_x, player_y, player_height, screen_shake_offset_x=0, screen_shake_offset_y=0):
        """면역 보호막 이펙트 그리기 (에너지 보호막이 생겼다가 서서히 사라짐)"""
        if self.immunity_timer <= 0:
            return

        offset_x = screen_shake_offset_x
        offset_y = screen_shake_offset_y

        # 면역 남은 시간 비율 (1.0 → 0.0)
        immunity_ratio = self.immunity_timer / CLEANSE_IMMUNITY_DURATION

        # 플레이어 중심 위치
        center_x = int(player_x + offset_x)
        center_y = int(player_y + player_height // 2 + offset_y)

        # 보호막 크기 (패들 기반)
        shield_height = int(player_height * 1.4)
        shield_width = 30

        # 보호막 투명도 (시간에 따라 서서히 사라짐)
        # 처음 0.2초는 완전히 보이고, 이후 서서히 사라짐
        if immunity_ratio > 0.8:
            alpha_multiplier = 1.0
        else:
            alpha_multiplier = immunity_ratio / 0.8

        # 미세한 펄스 효과
        pulse = 0.9 + 0.1 * math.sin(pygame.time.get_ticks() * 0.015)
        base_alpha = int(200 * alpha_multiplier * pulse)

        # 보호막 서피스 (충분히 큰 크기)
        surf_size = max(shield_width, shield_height) * 2 + 40
        shield_surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
        surf_center = surf_size // 2

        # 외곽 에너지 링 (3겹)
        for i in range(3):
            ring_alpha = max(0, int(base_alpha * (0.8 - i * 0.2)))
            ring_width = shield_width + i * 4
            ring_height = shield_height + i * 4
            thickness = 3 - i

            if ring_alpha > 0:
                pygame.draw.ellipse(
                    shield_surf,
                    (100, 200, 255, ring_alpha),
                    (surf_center - ring_width, surf_center - ring_height // 2,
                     ring_width * 2, ring_height),
                    max(1, thickness)
                )

        # 내부 반투명 채우기 (보호막 느낌)
        inner_alpha = int(base_alpha * 0.15)
        if inner_alpha > 0:
            pygame.draw.ellipse(
                shield_surf,
                (150, 220, 255, inner_alpha),
                (surf_center - shield_width + 4, surf_center - shield_height // 2 + 4,
                 (shield_width - 4) * 2, shield_height - 8),
                0  # 채우기
            )

        # 하이라이트 (상단에 밝은 빛)
        highlight_alpha = int(base_alpha * 0.4)
        if highlight_alpha > 0:
            pygame.draw.arc(
                shield_surf,
                (220, 240, 255, highlight_alpha),
                (surf_center - shield_width + 6, surf_center - shield_height // 2 + 2,
                 (shield_width - 6) * 2, shield_height // 2),
                math.pi * 0.2, math.pi * 0.8,
                2
            )

        # 화면에 블릿
        screen.blit(
            shield_surf,
            (center_x - surf_center, center_y - surf_center)
        )

    def reset(self):
        """스킬 상태 초기화"""
        self.last_n_press_time = 0
        self.cooldown_timer = 0
        self.immunity_timer = 0
        self.active = False
        self.animation_timer = 0
        self.wave_rings = []
        self.particles = []
        self.flash_alpha = 0


# 싱글톤 인스턴스
_cleanse_instance = None

def get_cleanse_skill():
    """클렌즈 스킬 인스턴스 반환"""
    global _cleanse_instance
    if _cleanse_instance is None:
        _cleanse_instance = CleanseSkill()
    return _cleanse_instance

def reset_cleanse_skill():
    """클렌즈 스킬 초기화"""
    global _cleanse_instance
    if _cleanse_instance:
        _cleanse_instance.reset()
    else:
        _cleanse_instance = CleanseSkill()

def is_cleanse_immune():
    """클렌즈 면역 상태인지 확인 (pingfighter.py에서 호출)"""
    global _cleanse_instance
    if _cleanse_instance is None:
        return False
    return _cleanse_instance.is_immune()


def check_player_has_status_effect(
    player_stunned_timer=0,
    player_missile_stunned_timer=0,
    player_slow_timer=0,
    player_knockback_vel=0,
    player_missile_knockback_vel=0,
    player_flame_zone_knockback_vel=0,
    smasher_power_recoil_timer=0,
    spider_mine_slow_active=False,
    player_burn_timer=0,
    player_knockback_y=0
):
    """플레이어가 상태이상 상태인지 확인"""
    if player_stunned_timer > 0:
        return True
    if player_missile_stunned_timer > 0:
        return True
    if player_slow_timer > 0:
        return True
    if abs(player_knockback_vel) > 0.5:
        return True
    if abs(player_missile_knockback_vel) > 0.5:
        return True
    if abs(player_flame_zone_knockback_vel) > 0.5:
        return True
    if smasher_power_recoil_timer > 0:
        return True
    if spider_mine_slow_active:
        return True
    # 스테이지4 붉은달 파편 화상/넉백 효과
    if player_burn_timer > 0:
        return True
    if abs(player_knockback_y) > 0.5:
        return True
    return False


def clear_all_status_effects():
    """모든 상태이상 해제 - pingfighter.py에서 호출용 (실제 해제는 pingfighter에서 수행)"""
    # 이 함수는 플래그 역할만 함
    # 실제 상태이상 변수들은 pingfighter.py의 전역 변수이므로
    # 해당 파일에서 직접 처리해야 함
    pass
