"""
클렌즈 스킬 - 스매셔 전용 상태이상 해제 스킬
W키(ㅈ키) 1번 누르면 발동
게이지 소모: 100
효과: 모든 상태이상(스턴, 둔화, 넉백) 즉시 해제
"""

import pygame
import math
import random

# 클렌즈 스킬 설정
CLEANSE_GAUGE_COST = 100           # 게이지 소모량
CLEANSE_COOLDOWN = 60              # 쿨다운 (프레임, 1초)
CLEANSE_IMMUNITY_DURATION = 300    # 면역 지속 시간 (프레임, 5초) - 현재 버전 유지

class CleanseSkill:
    """스매셔 클렌즈 스킬 - 플라즈마 파동으로 상태이상 해제"""

    def __init__(self):
        # 쿨다운
        self.cooldown_timer = 0

        # 면역 상태 (클렌즈 발동 후 상태이상 면역)
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

        # 보호막 전환 애니메이션 상태
        self.shield_transition_timer = 0      # 전환 애니메이션 타이머
        self.shield_transition_duration = 20  # 전환 애니메이션 지속 시간 (프레임)
        self.shield_fully_formed = False      # 보호막이 완전히 형성되었는지

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

    def check_key_press(self):
        """J키 단일 입력 감지 (항상 True 반환, 발동 가능 여부는 can_activate에서 체크)"""
        return True

    def activate(self, player_x, player_y):
        """클렌즈 스킬 발동"""
        self.active = True
        self.animation_timer = self.animation_duration
        self.center_x = player_x
        self.center_y = player_y
        self.cooldown_timer = CLEANSE_COOLDOWN

        # 면역 타이머 시작
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

        # 보호막 전환 애니메이션 초기화
        self.shield_transition_timer = 0
        self.shield_fully_formed = False

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

        # 애니메이션 종료 → 보호막 전환 시작 (한 번만 실행)
        if self.animation_timer <= 0:
            if self.active:  # active가 True일 때만 전환 시작 (중복 방지)
                self.active = False
                self.wave_rings = []
                self.particles = []
                # 파동 애니메이션 종료 시 보호막 전환 시작
                if not self.shield_fully_formed and self.immunity_timer > 0:
                    self.shield_transition_timer = self.shield_transition_duration

        # 보호막 전환 애니메이션 업데이트
        if self.shield_transition_timer > 0:
            self.shield_transition_timer -= 1
            if self.shield_transition_timer <= 0:
                self.shield_fully_formed = True

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

        # 파동 애니메이션 끝자락: 수축하는 에너지 링 (보호막 전환 예고)
        if self.animation_timer <= 10 and self.animation_timer > 0:
            # 수축 진행률 (0.0 → 1.0)
            shrink_progress = 1 - (self.animation_timer / 10)
            # 수축하는 링의 반지름 (150 → 60)
            shrink_radius = int(150 - 90 * shrink_progress)
            # 밝기 증가 (수축하면서 밝아짐)
            shrink_alpha = int(100 + 155 * shrink_progress)

            # 수축 링 그리기
            for i in range(3):
                ring_alpha = max(0, shrink_alpha - i * 40)
                ring_radius = shrink_radius + i * 8

                if ring_alpha > 0 and ring_radius > 0:
                    pygame.draw.circle(
                        screen,
                        (180, 230, 255, ring_alpha),
                        (int(self.center_x + offset_x), int(self.center_y + offset_y)),
                        ring_radius,
                        max(1, 3 - i)
                    )

    def draw_immunity_shield(self, screen, player_x, player_y, player_height, screen_shake_offset_x=0, screen_shake_offset_y=0, player_width=100):
        """면역 보호막 이펙트 그리기 - 패들 전체를 둘러싸는 플라즈마 보호막"""
        # 디버그: 함수 진입 확인
        if self.immunity_timer % 60 == 0:
            print(f"[SHIELD ENTRY] immunity_timer={self.immunity_timer}, active={self.active}, transition={self.shield_transition_timer}")

        if self.immunity_timer <= 0:
            return

        # 파동 애니메이션 중에는 보호막 그리지 않음 (파동이 먼저 완료되어야 함)
        if self.active:
            return

        offset_x = screen_shake_offset_x
        offset_y = screen_shake_offset_y

        # 면역 남은 시간 비율 (1.0 → 0.0)
        immunity_ratio = self.immunity_timer / CLEANSE_IMMUNITY_DURATION

        # 플레이어 패들 중심 위치
        center_x = int(player_x + player_width // 2 + offset_x)
        center_y = int(player_y + player_height // 2 + offset_y)

        # 보호막 최종 크기 (정원 - 반지름)
        final_shield_radius = 100  # 정원 반지름

        # === 전환 애니메이션: 파동 링 → 보호막 수축 효과 ===
        if self.shield_transition_timer > 0:
            # 전환 진행률 (1.0 → 0.0)
            transition_progress = self.shield_transition_timer / self.shield_transition_duration
            # 이징 함수 (ease-out: 빠르게 시작, 느리게 끝)
            eased_progress = 1 - (1 - transition_progress) ** 2

            # 보호막 크기: 큰 원에서 최종 원으로 수축
            start_radius = 150  # 파동 링의 마지막 크기와 비슷하게
            shield_radius = int(final_shield_radius + (start_radius - final_shield_radius) * eased_progress)

            # 전환 중 알파 (서서히 밝아짐)
            alpha_multiplier = (1 - transition_progress) * 0.8 + 0.2
        else:
            shield_radius = final_shield_radius

            # 보호막 투명도 (시간에 따라 점점 투명해지면서 사라짐)
            # 전체 5초 동안 선형적으로 투명해짐
            # immunity_ratio: 1.0(시작) → 0.0(끝)
            # alpha_multiplier도 동일하게 1.0 → 0.0
            alpha_multiplier = immunity_ratio

            # 디버그: 매 60프레임(1초)마다 출력
            if self.immunity_timer % 60 == 0:
                print(f"[SHIELD DEBUG] immunity_timer={self.immunity_timer}, immunity_ratio={immunity_ratio:.3f}, alpha_multiplier={alpha_multiplier:.3f}")

        # 시간 기반 애니메이션
        current_time = pygame.time.get_ticks()

        # 펄스 효과 (빠르게 깜박임)
        pulse = 0.85 + 0.15 * math.sin(current_time * 0.012)
        base_alpha = int(220 * alpha_multiplier * pulse)

        # 디버그: base_alpha 확인
        if self.immunity_timer % 60 == 0 and not self.shield_transition_timer > 0:
            print(f"[SHIELD DEBUG] base_alpha={base_alpha}, pulse={pulse:.3f}")

        # 보호막 서피스 (정원용)
        surf_size = shield_radius * 2 + 60
        shield_surf = pygame.Surface((surf_size, surf_size), pygame.SRCALPHA)
        surf_center = surf_size // 2

        # === 플라즈마 보호막 레이어 (정원) ===

        # 1. 외곽 플라즈마 글로우 (가장 바깥쪽, 흐릿하게)
        for i in range(4):
            glow_alpha = max(0, int(base_alpha * (0.3 - i * 0.06)))
            glow_radius = shield_radius + 8 + i * 6

            if glow_alpha > 0:
                # 색상 변화 (청록 → 보라)
                color_shift = math.sin(current_time * 0.003 + i * 0.5)
                r = int(80 + 60 * max(0, color_shift))
                g = int(180 - 40 * abs(color_shift))
                b = 255

                pygame.draw.circle(
                    shield_surf,
                    (r, g, b, glow_alpha),
                    (surf_center, surf_center),
                    glow_radius,
                    0  # 채우기
                )

        # 2. 메인 플라즈마 쉴드 (3겹의 에너지 링) - 페이드아웃 시 두께도 감소
        for i in range(3):
            ring_alpha = max(0, int(base_alpha * (0.9 - i * 0.25)))
            ring_radius = shield_radius + i * 4
            # 두께도 alpha_multiplier에 따라 점점 얇아짐
            base_thickness = 4 - i
            thickness = max(1, int(base_thickness * (0.5 + 0.5 * alpha_multiplier)))

            if ring_alpha > 0:
                # 회전하는 색상 효과
                phase = current_time * 0.008 + i * 1.2
                r = int(100 + 80 * math.sin(phase))
                g = int(200 + 40 * math.sin(phase + 1.5))
                b = 255

                pygame.draw.circle(
                    shield_surf,
                    (r, g, b, ring_alpha),
                    (surf_center, surf_center),
                    ring_radius,
                    thickness
                )

        # 3. 내부 에너지 필드 (반투명 채우기 - 정원)
        inner_alpha = int(base_alpha * 0.12)
        if inner_alpha > 0:
            # 내부 색상도 미세하게 변화
            inner_phase = current_time * 0.005
            inner_r = int(120 + 30 * math.sin(inner_phase))
            inner_g = int(200 + 30 * math.sin(inner_phase + 1))

            pygame.draw.circle(
                shield_surf,
                (inner_r, inner_g, 255, inner_alpha),
                (surf_center, surf_center),
                shield_radius - 4,
                0
            )

        # 4. 플라즈마 아크 (전기 효과) - 회전하는 에너지 선 (정원 기준)
        num_arcs = 6
        for arc_i in range(num_arcs):
            arc_angle = (current_time * 0.006 + arc_i * (2 * math.pi / num_arcs)) % (2 * math.pi)
            arc_alpha = int(base_alpha * (0.5 + 0.3 * math.sin(current_time * 0.02 + arc_i)))

            if arc_alpha > 0:
                # 아크 시작점과 끝점 (정원 기준)
                arc_x1 = surf_center + int(shield_radius * 0.8 * math.cos(arc_angle))
                arc_y1 = surf_center + int(shield_radius * 0.8 * math.sin(arc_angle))
                arc_x2 = surf_center + int(shield_radius * 0.85 * math.cos(arc_angle + 0.4))
                arc_y2 = surf_center + int(shield_radius * 0.85 * math.sin(arc_angle + 0.4))

                # 전기 아크 색상
                arc_r = int(150 + 105 * math.sin(current_time * 0.015 + arc_i))
                arc_g = int(220 + 35 * math.sin(current_time * 0.02 + arc_i))

                pygame.draw.line(shield_surf, (arc_r, arc_g, 255, arc_alpha),
                               (arc_x1, arc_y1), (arc_x2, arc_y2), 2)

        # 5. 상단 하이라이트 (빛 반사 - 정원 상단)
        highlight_alpha = int(base_alpha * 0.35)
        if highlight_alpha > 0:
            highlight_radius = int(shield_radius * 0.5)

            pygame.draw.circle(
                shield_surf,
                (220, 245, 255, highlight_alpha),
                (surf_center, surf_center - int(shield_radius * 0.4)),
                highlight_radius,
                0
            )

        # 6. 에너지 파티클 (보호막 표면에 떠다니는 입자들 - 정원 기준)
        num_particles = 12
        for p_i in range(num_particles):
            p_angle = (current_time * 0.004 + p_i * (2 * math.pi / num_particles)) % (2 * math.pi)
            p_radius = shield_radius * (0.9 + 0.1 * math.sin(current_time * 0.008 + p_i))

            p_x = surf_center + int(p_radius * math.cos(p_angle))
            p_y = surf_center + int(p_radius * math.sin(p_angle))

            p_alpha = int(base_alpha * (0.6 + 0.4 * math.sin(current_time * 0.025 + p_i * 0.5)))
            p_size = int(3 + 2 * math.sin(current_time * 0.015 + p_i))

            if p_alpha > 0 and p_size > 0:
                # 파티클 색상 (청록 ~ 흰색)
                p_brightness = 0.7 + 0.3 * math.sin(current_time * 0.02 + p_i)
                pygame.draw.circle(
                    shield_surf,
                    (int(180 * p_brightness), int(230 * p_brightness), 255, p_alpha),
                    (p_x, p_y),
                    p_size
                )

        # 화면에 블릿
        screen.blit(
            shield_surf,
            (center_x - surf_center, center_y - surf_center)
        )

    def reset(self):
        """스킬 상태 초기화"""
        self.cooldown_timer = 0
        self.immunity_timer = 0
        self.active = False
        self.animation_timer = 0
        self.wave_rings = []
        self.particles = []
        self.flash_alpha = 0
        self.shield_transition_timer = 0
        self.shield_fully_formed = False


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
    player_knockback_y=0,
    player_stunned=False  # 스테이지5 네메시스 레이저 감전
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
    # 스테이지5 네메시스 레이저 감전
    if player_stunned:
        return True
    return False


def clear_all_status_effects():
    """모든 상태이상 해제 - pingfighter.py에서 호출용 (실제 해제는 pingfighter에서 수행)"""
    # 이 함수는 플래그 역할만 함
    # 실제 상태이상 변수들은 pingfighter.py의 전역 변수이므로
    # 해당 파일에서 직접 처리해야 함
    pass
