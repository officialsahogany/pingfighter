"""
자기장 발생기 (Magnet Field) 아이템 효과
3초 동안 공이 플레이어 패들 쪽으로 약간 끌려옴
보스 투사체도 살짝 궤도 변경
타이머형 액티브 아이템
"""

import os
import pygame
import math
import random

# 상수
MAGNET_FIELD_DURATION_FRAMES = 180  # 3초 (60fps * 3)
MAGNET_PULL_STRENGTH = 0.35  # 공을 끌어당기는 힘 (Y축 아래로)
MAGNET_PULL_X_FACTOR = 0.15  # 공을 패들 X 중앙으로 끌어당기는 힘
MAGNET_PROJECTILE_DEFLECT = 0.2  # 보스 투사체 궤도 변경 힘


class MagnetField:
    def __init__(self):
        self.active = False
        self.duration = MAGNET_FIELD_DURATION_FRAMES
        self.timer = 0
        self.initial_timer = 0  # 가로형 타이머 게이지용 초기값
        self.particles = []  # 자기장 파티클
        self.field_phase = 0  # 필드 애니메이션 위상
        self.width = 760
        self.height = 750
        self.player_center_x = 380  # 플레이어 패들 중앙 X (업데이트됨)
        self.player_y = 710  # 플레이어 패들 Y
        self.debug = os.environ.get("DEBUG_MAGNET_FIELD", "0") == "1"

    def activate(self, game_state=None, current_stage=None, width=760, height=750):
        """자기장 발생기 활성화"""
        self.active = True
        self.width = width
        self.height = height

        # 카페인 스킬 효과 적용
        frames = MAGNET_FIELD_DURATION_FRAMES
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
        self.initial_timer = frames

        # 파티클 초기화
        self.particles = []
        self.field_phase = 0

        if self.debug:
            print(f"[MAGNET_FIELD] 활성화! 지속시간: {self.timer / 60:.1f}초")

    def deactivate(self):
        """자기장 발생기 비활성화"""
        self.active = False
        self.timer = 0
        self.particles.clear()

        if self.debug:
            print("[MAGNET_FIELD] 비활성화")

    def update(self, current_stage=None, player_rect=None):
        """상태 업데이트"""
        if not self.active:
            return

        # 플레이어 위치 업데이트
        if player_rect is not None:
            self.player_center_x = player_rect.centerx
            self.player_y = player_rect.centery

        # 타이머 감소
        self.timer -= 1
        if self.timer <= 0:
            self.deactivate()
            return

        # 필드 애니메이션 업데이트
        self.field_phase += 0.08

        # 자기장 파티클 생성 (3프레임마다)
        if self.timer % 3 == 0:
            for _ in range(2):
                # 플레이어 주변에서 위로 올라가는 자기장 라인 파티클
                angle = random.uniform(0, math.pi * 2)
                radius = random.uniform(40, 150)
                px = self.player_center_x + math.cos(angle) * radius
                py = self.player_y - random.uniform(20, 120)
                particle = {
                    'x': px,
                    'y': py,
                    'vx': math.cos(angle) * random.uniform(-0.3, 0.3),
                    'vy': random.uniform(-1.5, -0.5),
                    'size': random.randint(2, 4),
                    'alpha': 200,
                    'color': random.choice([
                        (100, 150, 255),  # 파란색
                        (150, 100, 255),  # 보라색
                        (80, 200, 255),   # 시안
                        (200, 150, 255),  # 연보라
                    ])
                }
                self.particles.append(particle)

        # 파티클 업데이트
        for particle in self.particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['alpha'] -= 6
            if particle['alpha'] <= 0:
                self.particles.remove(particle)

    def apply_ball_pull(self, ball_rect, ball_vel):
        """공에 자기장 끌어당기는 힘 적용

        Returns:
            bool: 힘이 적용되었으면 True
        """
        if not self.active:
            return False

        # 공이 플레이어 진영(하단)에 가까울수록 힘이 강함
        # 중앙선(375) 이하에서만 작용
        if ball_rect.centery < 300:
            return False

        # 거리 기반 힘 계산 (가까울수록 강함)
        distance_y = self.player_y - ball_rect.centery
        if distance_y <= 0:
            return False

        # Y축: 아래로 당기는 힘 (플레이어 쪽으로)
        pull_factor = min(1.0, (ball_rect.centery - 300) / 400)  # 300~700 범위에서 0~1
        y_pull = MAGNET_PULL_STRENGTH * pull_factor

        # X축: 패들 중앙으로 살짝 끌어당김
        dx = self.player_center_x - ball_rect.centerx
        x_pull = MAGNET_PULL_X_FACTOR * (dx / max(1, abs(dx))) * pull_factor * 0.5

        ball_vel[1] += y_pull
        ball_vel[0] += x_pull

        return True

    def apply_projectile_deflect(self, projectile_vel):
        """보스 투사체 궤도 약간 변경 (X축으로 살짝 밀어냄)

        Args:
            projectile_vel: [vx, vy] 투사체 속도 리스트

        Returns:
            bool: 힘이 적용되었으면 True
        """
        if not self.active:
            return False

        # 투사체가 아래로 내려오고 있을 때만 약간 궤도 변경
        if projectile_vel[1] > 0:
            # 패들 중앙에서 먼 쪽으로 살짝 밀어냄 (회피 보조)
            deflect_x = random.uniform(-MAGNET_PROJECTILE_DEFLECT, MAGNET_PROJECTILE_DEFLECT)
            projectile_vel[0] += deflect_x
            return True

        return False

    def draw_effects(self, screen, **kwargs):
        """자기장 이펙트 그리기"""
        if not self.active:
            return

        # 남은 시간 비율로 투명도 계산
        alpha_base = min(180, int(180 * (self.timer / max(1, self.initial_timer))))

        # 자기장 필드 링 (플레이어 주변 동심원)
        field_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

        # 동심원 그리기 (펄스 효과)
        num_rings = 3
        for i in range(num_rings):
            ring_phase = self.field_phase + i * (math.pi * 2 / num_rings)
            pulse = 0.6 + 0.4 * math.sin(ring_phase)
            radius = int((60 + i * 50) * pulse)
            alpha = int(alpha_base * 0.3 * (1 - i / num_rings))

            if alpha > 0 and radius > 0:
                color = (100, 150, 255, alpha)
                pygame.draw.circle(field_surface, color,
                                   (self.player_center_x, self.player_y),
                                   radius, 2)

        # 자력선 (위에서 패들로 모여드는 곡선)
        num_lines = 6
        for i in range(num_lines):
            line_phase = self.field_phase * 0.5 + i * (math.pi * 2 / num_lines)
            start_radius = 120 + 30 * math.sin(line_phase)
            angle = math.pi * 2 * i / num_lines

            start_x = self.player_center_x + math.cos(angle) * start_radius
            start_y = self.player_y - 80 - 20 * math.sin(line_phase)

            mid_x = self.player_center_x + math.cos(angle) * start_radius * 0.5
            mid_y = self.player_y - 40

            line_alpha = int(alpha_base * 0.4)
            if line_alpha > 0:
                color = (150, 120, 255, line_alpha)
                # 시작점 → 중간점 → 패들
                points = [
                    (int(start_x), int(start_y)),
                    (int(mid_x), int(mid_y)),
                    (self.player_center_x, self.player_y)
                ]
                if len(points) >= 2:
                    pygame.draw.lines(field_surface, color, False, points, 1)

        screen.blit(field_surface, (0, 0))

        # 파티클 그리기
        for particle in self.particles:
            if particle['alpha'] > 0:
                particle_surf = pygame.Surface(
                    (particle['size'] * 2, particle['size'] * 2), pygame.SRCALPHA)
                color = (*particle['color'], min(255, particle['alpha']))
                pygame.draw.circle(particle_surf, color,
                                   (particle['size'], particle['size']),
                                   particle['size'])
                screen.blit(particle_surf,
                            (int(particle['x'] - particle['size']),
                             int(particle['y'] - particle['size'])))

        # 남은 시간 1초 미만이면 깜빡임
        if self.timer < 60 and self.timer % 10 < 5:
            flash_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            cx, cy = self.player_center_x, self.player_y
            pygame.draw.circle(flash_surf, (150, 100, 255, 30), (cx, cy), 100)
            screen.blit(flash_surf, (0, 0))

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
magnet_field_instance = None


def get_magnet_field_instance():
    global magnet_field_instance
    if magnet_field_instance is None:
        magnet_field_instance = MagnetField()
    return magnet_field_instance


def activate_magnet_field(game_state=None, current_stage=None, width=760, height=750):
    """자기장 발생기 활성화"""
    field = get_magnet_field_instance()
    field.activate(game_state, current_stage, width, height)
    return True


def deactivate_magnet_field():
    """자기장 발생기 비활성화"""
    field = get_magnet_field_instance()
    field.deactivate()


def update_magnet_field(current_stage=None, player_rect=None):
    """자기장 발생기 업데이트"""
    field = get_magnet_field_instance()
    field.update(current_stage, player_rect)


def draw_magnet_field_effects(screen, **kwargs):
    """자기장 효과 그리기"""
    field = get_magnet_field_instance()
    field.draw_effects(screen, **kwargs)


def apply_magnet_ball_pull(ball_rect, ball_vel):
    """공에 자기장 끌어당기는 힘 적용"""
    field = get_magnet_field_instance()
    return field.apply_ball_pull(ball_rect, ball_vel)


def apply_magnet_projectile_deflect(projectile_vel):
    """보스 투사체 궤도 변경"""
    field = get_magnet_field_instance()
    return field.apply_projectile_deflect(projectile_vel)


def is_magnet_field_active():
    """자기장 발생기 활성화 여부"""
    field = get_magnet_field_instance()
    return field.active


def get_magnet_field_remaining_time():
    """남은 시간 반환 (초)"""
    field = get_magnet_field_instance()
    return field.get_remaining_time()


def get_magnet_field_remaining_ratio():
    """남은 시간 비율 반환"""
    field = get_magnet_field_instance()
    return field.get_remaining_ratio()
