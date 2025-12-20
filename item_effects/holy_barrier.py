"""
홀리베리어 아이템 효과
4초동안 플레이어 뒤쪽 벽에 공을 반사하는 방벽을 소환합니다.
타이머형 액티브 아이템
"""

import os
import pygame
import math

# 상수
HOLY_BARRIER_DURATION_FRAMES = 240  # 4초 (60fps * 4)
HOLY_BARRIER_HEIGHT = 20  # 방벽 높이
HOLY_BARRIER_Y_OFFSET = 5  # 화면 하단으로부터의 오프셋


class HolyBarrier:
    def __init__(self):
        self.active = False
        self.duration = HOLY_BARRIER_DURATION_FRAMES
        self.timer = 0
        self.initial_timer = 0  # 가로형 타이머 게이지용 초기값
        self.barrier_rect = None  # 방벽 충돌 영역
        self.particles = []  # 파티클 효과
        self.glow_phase = 0  # 글로우 애니메이션 위상
        self.width = 600  # 화면 너비 (나중에 설정됨)
        self.height = 750  # 화면 높이 (나중에 설정됨)
        self.debug = os.environ.get("DEBUG_HOLY_BARRIER", "0") == "1"

    def activate(self, game_state=None, current_stage=None, width=600, height=750):
        """홀리베리어 활성화"""
        self.active = True
        self.width = width
        self.height = height

        # 카페인 스킬 효과 적용 (타이머형 아이템 지속시간 증가) - 아카데미 + 런타임 스킬
        frames = HOLY_BARRIER_DURATION_FRAMES
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

        # 방벽 위치 설정 (화면 하단)
        barrier_y = height - HOLY_BARRIER_Y_OFFSET - HOLY_BARRIER_HEIGHT
        self.barrier_rect = pygame.Rect(0, barrier_y, width, HOLY_BARRIER_HEIGHT)

        # 파티클 초기화
        self.particles = []
        self.glow_phase = 0

        if self.debug:
            print(f"[HOLY_BARRIER] 활성화! 지속시간: {self.timer/60:.1f}초")

    def deactivate(self):
        """홀리베리어 비활성화"""
        self.active = False
        self.timer = 0
        self.barrier_rect = None
        self.particles.clear()

        if self.debug:
            print("[HOLY_BARRIER] 비활성화")

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
        self.glow_phase += 0.1

        # 파티클 생성 (5프레임마다)
        if self.timer % 5 == 0 and self.barrier_rect:
            import random
            for _ in range(3):
                particle = {
                    'x': random.randint(0, self.width),
                    'y': self.barrier_rect.centery + random.randint(-5, 5),
                    'vx': random.uniform(-0.5, 0.5),
                    'vy': random.uniform(-1.5, -0.5),
                    'size': random.randint(2, 5),
                    'alpha': 255,
                    'color': random.choice([
                        (255, 255, 200),  # 밝은 노랑
                        (200, 220, 255),  # 밝은 하늘색
                        (255, 230, 150),  # 금색
                    ])
                }
                self.particles.append(particle)

        # 파티클 업데이트
        for particle in self.particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['alpha'] -= 8
            if particle['alpha'] <= 0:
                self.particles.remove(particle)

    def check_ball_collision(self, ball_rect, ball_vel):
        """공과 방벽 충돌 체크 및 반사 처리

        Returns:
            bool: 충돌이 발생했으면 True
        """
        if not self.active or not self.barrier_rect:
            return False

        # 공이 방벽과 충돌했는지 확인
        if ball_rect.colliderect(self.barrier_rect):
            # 공이 아래로 이동 중일 때만 반사 (위에서 아래로 내려오는 경우)
            if ball_vel[1] > 0:
                # 공을 방벽 위로 이동
                ball_rect.bottom = self.barrier_rect.top
                # Y 속도 반전
                ball_vel[1] = -abs(ball_vel[1])

                # 충돌 이펙트 파티클 추가
                import random
                for _ in range(10):
                    particle = {
                        'x': ball_rect.centerx + random.randint(-15, 15),
                        'y': ball_rect.bottom,
                        'vx': random.uniform(-2, 2),
                        'vy': random.uniform(-3, -1),
                        'size': random.randint(3, 7),
                        'alpha': 255,
                        'color': (255, 255, 100)  # 밝은 금색
                    }
                    self.particles.append(particle)

                if self.debug:
                    print(f"[HOLY_BARRIER] 공 반사! 남은 시간: {self.timer/60:.1f}초")

                return True

        return False

    def draw_effects(self, screen, **kwargs):
        """홀리베리어 이펙트 그리기"""
        if not self.active or not self.barrier_rect:
            return

        # 글로우 강도 계산 (0.5 ~ 1.0)
        glow_intensity = 0.75 + 0.25 * math.sin(self.glow_phase)

        # 방벽 배경 (반투명 그라데이션)
        barrier_surf = pygame.Surface((self.width, HOLY_BARRIER_HEIGHT + 30), pygame.SRCALPHA)

        # 그라데이션 효과 (아래가 더 밝음)
        for i in range(HOLY_BARRIER_HEIGHT + 20):
            alpha = int(80 * glow_intensity * (1 - i / (HOLY_BARRIER_HEIGHT + 20)))
            color = (255, 255, 200, alpha)
            pygame.draw.line(barrier_surf, color, (0, i), (self.width, i))

        screen.blit(barrier_surf, (0, self.barrier_rect.top - 10))

        # 메인 방벽 라인
        line_alpha = int(200 * glow_intensity)
        line_color = (255, 255, 150, line_alpha)

        # 여러 층의 라인으로 두께감 표현
        for offset in range(-2, 3):
            line_surf = pygame.Surface((self.width, 4), pygame.SRCALPHA)
            layer_alpha = int(line_alpha * (1 - abs(offset) * 0.2))
            pygame.draw.line(line_surf, (*line_color[:3], layer_alpha),
                           (0, 2), (self.width, 2), 2)
            screen.blit(line_surf, (0, self.barrier_rect.centery + offset))

        # 신성한 문양 (간단한 십자가 또는 별 패턴)
        symbol_spacing = 80
        symbol_size = 12
        for x in range(symbol_spacing // 2, self.width, symbol_spacing):
            # 별 모양 그리기
            cx, cy = x, self.barrier_rect.centery
            pulse = 0.7 + 0.3 * math.sin(self.glow_phase + x * 0.05)

            # 중앙 원
            pygame.draw.circle(screen, (255, 255, 200), (cx, cy), int(symbol_size * pulse * 0.4))

            # 빛나는 선
            for angle in range(0, 360, 45):
                rad = math.radians(angle)
                end_x = cx + math.cos(rad) * symbol_size * pulse
                end_y = cy + math.sin(rad) * symbol_size * pulse
                pygame.draw.line(screen, (255, 255, 180), (cx, cy), (int(end_x), int(end_y)), 1)

        # 파티클 그리기
        for particle in self.particles:
            if particle['alpha'] > 0:
                particle_surf = pygame.Surface((particle['size'] * 2, particle['size'] * 2), pygame.SRCALPHA)
                color = (*particle['color'], particle['alpha'])
                pygame.draw.circle(particle_surf, color,
                                 (particle['size'], particle['size']), particle['size'])
                screen.blit(particle_surf,
                          (int(particle['x'] - particle['size']),
                           int(particle['y'] - particle['size'])))

        # 남은 시간이 1초 미만이면 깜빡임 효과
        if self.timer < 60 and self.timer % 10 < 5:
            flash_surf = pygame.Surface((self.width, HOLY_BARRIER_HEIGHT + 10), pygame.SRCALPHA)
            flash_surf.fill((255, 255, 255, 50))
            screen.blit(flash_surf, (0, self.barrier_rect.top - 5))

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
holy_barrier_instance = None


def get_holy_barrier_instance():
    global holy_barrier_instance
    if holy_barrier_instance is None:
        holy_barrier_instance = HolyBarrier()
    return holy_barrier_instance


def activate_holy_barrier(game_state=None, current_stage=None, width=600, height=750):
    """홀리베리어 활성화"""
    barrier = get_holy_barrier_instance()
    barrier.activate(game_state, current_stage, width, height)
    return True


def deactivate_holy_barrier():
    """홀리베리어 비활성화"""
    barrier = get_holy_barrier_instance()
    barrier.deactivate()


def update_holy_barrier(current_stage=None):
    """홀리베리어 업데이트"""
    barrier = get_holy_barrier_instance()
    barrier.update(current_stage)


def draw_holy_barrier_effects(screen, **kwargs):
    """홀리베리어 효과 그리기"""
    barrier = get_holy_barrier_instance()
    barrier.draw_effects(screen, **kwargs)


def check_holy_barrier_collision(ball_rect, ball_vel):
    """공과 홀리베리어 충돌 체크"""
    barrier = get_holy_barrier_instance()
    return barrier.check_ball_collision(ball_rect, ball_vel)


def get_holy_barrier_remaining_time():
    """남은 시간 반환 (초)"""
    barrier = get_holy_barrier_instance()
    return barrier.get_remaining_time()


def get_holy_barrier_remaining_ratio():
    """남은 시간 비율 반환"""
    barrier = get_holy_barrier_instance()
    return barrier.get_remaining_ratio()


def is_holy_barrier_active():
    """홀리베리어 활성화 여부"""
    barrier = get_holy_barrier_instance()
    return barrier.active


def configure_holy_barrier(duration_sec: float = None) -> None:
    """롤 옵션에서 받은 지속 시간을 설정

    Args:
        duration_sec: 지속 시간(초)
    """
    barrier = get_holy_barrier_instance()
    if duration_sec is not None:
        barrier.duration = max(1, int(duration_sec * 60))
