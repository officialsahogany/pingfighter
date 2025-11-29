"""
레이저스코프 아이템 효과
발동 시 15초간 모든 보스의 공/스킬/장애물의 궤적을 레이저 선으로 표시
공의 최종 도달 지점을 정확히 알려줌
"""

import pygame
import math

class LaserScope:
    def __init__(self):
        self.active = False
        self.duration = 900  # 15초 (60 FPS 기준)
        self.timer = 0
        self.max_duration = 900  # 최대 지속 시간 저장

        # 레이저 효과 설정
        self.laser_color = (255, 50, 50, 150)  # 빨간색 레이저
        self.laser_glow_color = (255, 100, 100, 50)  # 글로우 효과
        self.impact_color = (255, 255, 0, 200)  # 충돌 지점 (노란색)
        self.trajectory_segments = []  # 궤적 세그먼트 저장

        # 애니메이션용 변수
        self.pulse_timer = 0
        self.pulse_speed = 0.1

    def activate(self):
        """레이저스코프 활성화"""
        self.active = True
        self.timer = self.duration
        self.trajectory_segments = []

    def deactivate(self):
        """레이저스코프 비활성화"""
        self.active = False
        self.timer = 0
        self.trajectory_segments = []

    def update(self):
        """레이저스코프 상태 업데이트"""
        if not self.active:
            return

        self.timer -= 1
        self.pulse_timer += self.pulse_speed

        if self.timer <= 0:
            self.deactivate()

    def calculate_trajectory(self, ball_x, ball_y, ball_vx, ball_vy,
                           screen_width=600, screen_height=750,
                           paddle_y=None, boss_paddle_y=None,
                           obstacles=None, max_bounces=10):
        """
        공의 궤적을 계산하여 최종 도달 지점을 예측

        Args:
            ball_x, ball_y: 공의 현재 위치
            ball_vx, ball_vy: 공의 현재 속도
            screen_width, screen_height: 화면 크기
            paddle_y: 플레이어 패들 Y 위치
            boss_paddle_y: 보스 패들 Y 위치
            obstacles: 장애물 목록 [(x, y, width, height), ...]
            max_bounces: 최대 반사 횟수

        Returns:
            list: 궤적 세그먼트 [(start_x, start_y, end_x, end_y), ...]
        """
        if not self.active:
            return []

        segments = []
        current_x, current_y = ball_x, ball_y
        vx, vy = ball_vx, ball_vy

        # 속도가 없으면 계산 불필요
        if abs(vx) < 0.001 and abs(vy) < 0.001:
            return []

        # 기본 패들 위치 설정
        if paddle_y is None:
            paddle_y = screen_height - 50
        if boss_paddle_y is None:
            boss_paddle_y = 50

        if obstacles is None:
            obstacles = []

        for _ in range(max_bounces):
            start_x, start_y = current_x, current_y

            # 다음 충돌 지점 계산
            # 1. 좌우 벽 충돌
            if vx > 0:
                t_right = (screen_width - 15 - current_x) / vx if vx != 0 else float('inf')
            else:
                t_right = float('inf')

            if vx < 0:
                t_left = (15 - current_x) / vx if vx != 0 else float('inf')
            else:
                t_left = float('inf')

            # 2. 상하 경계 (패들 위치) 충돌
            if vy > 0:
                t_bottom = (paddle_y - current_y) / vy if vy != 0 else float('inf')
            else:
                t_bottom = float('inf')

            if vy < 0:
                t_top = (boss_paddle_y - current_y) / vy if vy != 0 else float('inf')
            else:
                t_top = float('inf')

            # 가장 가까운 충돌 지점 선택
            min_t = float('inf')
            collision_type = None

            if 0 < t_right < min_t:
                min_t = t_right
                collision_type = 'right_wall'
            if 0 < t_left < min_t:
                min_t = t_left
                collision_type = 'left_wall'
            if 0 < t_bottom < min_t:
                min_t = t_bottom
                collision_type = 'player_paddle'
            if 0 < t_top < min_t:
                min_t = t_top
                collision_type = 'boss_paddle'

            # 장애물 충돌 체크
            for obs in obstacles:
                obs_x, obs_y, obs_w, obs_h = obs
                t_obs = self._check_obstacle_collision(
                    current_x, current_y, vx, vy,
                    obs_x, obs_y, obs_w, obs_h
                )
                if 0 < t_obs < min_t:
                    min_t = t_obs
                    collision_type = 'obstacle'

            if min_t == float('inf') or min_t <= 0:
                break

            # 충돌 지점 계산
            end_x = current_x + vx * min_t
            end_y = current_y + vy * min_t

            # 경계 내로 제한
            end_x = max(15, min(screen_width - 15, end_x))
            end_y = max(15, min(screen_height - 15, end_y))

            segments.append((start_x, start_y, end_x, end_y, collision_type))

            # 패들에 도달하면 종료
            if collision_type in ['player_paddle', 'boss_paddle']:
                break

            # 반사 처리
            current_x, current_y = end_x, end_y
            if collision_type in ['left_wall', 'right_wall']:
                vx = -vx
            elif collision_type == 'obstacle':
                # 간단한 반사 (실제로는 더 복잡한 로직 필요)
                vy = -vy

        self.trajectory_segments = segments
        return segments

    def _check_obstacle_collision(self, x, y, vx, vy, obs_x, obs_y, obs_w, obs_h):
        """장애물과의 충돌 시간 계산"""
        # 간단한 AABB 충돌 체크
        t_min = float('inf')

        if vx > 0:
            t = (obs_x - x) / vx
            if t > 0:
                hit_y = y + vy * t
                if obs_y <= hit_y <= obs_y + obs_h:
                    t_min = min(t_min, t)
        elif vx < 0:
            t = (obs_x + obs_w - x) / vx
            if t > 0:
                hit_y = y + vy * t
                if obs_y <= hit_y <= obs_y + obs_h:
                    t_min = min(t_min, t)

        if vy > 0:
            t = (obs_y - y) / vy
            if t > 0:
                hit_x = x + vx * t
                if obs_x <= hit_x <= obs_x + obs_w:
                    t_min = min(t_min, t)
        elif vy < 0:
            t = (obs_y + obs_h - y) / vy
            if t > 0:
                hit_x = x + vx * t
                if obs_x <= hit_x <= obs_x + obs_w:
                    t_min = min(t_min, t)

        return t_min

    def draw_effects(self, screen, ball_x=None, ball_y=None, ball_vx=None, ball_vy=None,
                    screen_width=600, screen_height=750, paddle_y=None, boss_paddle_y=None,
                    obstacles=None, **kwargs):
        """레이저 궤적 효과 그리기"""
        if not self.active:
            return

        # 공 정보가 있으면 궤적 계산
        if ball_x is not None and ball_vx is not None:
            self.calculate_trajectory(
                ball_x, ball_y, ball_vx, ball_vy,
                screen_width, screen_height,
                paddle_y, boss_paddle_y, obstacles
            )

        # 펄스 효과를 위한 알파 계산
        pulse = 0.7 + 0.3 * math.sin(self.pulse_timer)

        for segment in self.trajectory_segments:
            if len(segment) < 4:
                continue
            start_x, start_y, end_x, end_y = segment[:4]
            collision_type = segment[4] if len(segment) > 4 else None

            # 레이저 라인 그리기 (���러 겹으로 글로우 효과)
            # 외곽 글로우
            glow_surface = pygame.Surface((screen_width, screen_height), pygame.SRCALPHA)

            # 굵은 글로우 라인
            glow_alpha = int(30 * pulse)
            pygame.draw.line(glow_surface, (255, 100, 100, glow_alpha),
                           (int(start_x), int(start_y)), (int(end_x), int(end_y)), 8)

            # 중간 글로우
            pygame.draw.line(glow_surface, (255, 80, 80, int(60 * pulse)),
                           (int(start_x), int(start_y)), (int(end_x), int(end_y)), 5)

            # 핵심 레이저 라인
            pygame.draw.line(glow_surface, (255, 50, 50, int(180 * pulse)),
                           (int(start_x), int(start_y)), (int(end_x), int(end_y)), 2)

            # 중앙 밝은 라인
            pygame.draw.line(glow_surface, (255, 200, 200, int(200 * pulse)),
                           (int(start_x), int(start_y)), (int(end_x), int(end_y)), 1)

            screen.blit(glow_surface, (0, 0))

            # 충돌 지점 표시 (점선 원)
            if collision_type in ['player_paddle', 'boss_paddle']:
                # 최종 도달 지점 강조
                impact_surface = pygame.Surface((100, 100), pygame.SRCALPHA)
                cx, cy = 50, 50

                # 외곽 원
                for i in range(3):
                    radius = 20 - i * 5
                    alpha = int((80 + i * 40) * pulse)
                    color = (255, 255, 0, alpha) if collision_type == 'player_paddle' else (255, 100, 100, alpha)
                    pygame.draw.circle(impact_surface, color, (cx, cy), radius, 2)

                # 십자선
                cross_size = 15
                pygame.draw.line(impact_surface, (255, 255, 255, int(200 * pulse)),
                               (cx - cross_size, cy), (cx + cross_size, cy), 2)
                pygame.draw.line(impact_surface, (255, 255, 255, int(200 * pulse)),
                               (cx, cy - cross_size), (cx, cy + cross_size), 2)

                screen.blit(impact_surface, (int(end_x) - 50, int(end_y) - 50))

            elif collision_type in ['left_wall', 'right_wall', 'obstacle']:
                # 반사 지점 표시
                bounce_surface = pygame.Surface((40, 40), pygame.SRCALPHA)
                pygame.draw.circle(bounce_surface, (100, 200, 255, int(150 * pulse)), (20, 20), 8, 2)
                screen.blit(bounce_surface, (int(end_x) - 20, int(end_y) - 20))

    def draw_gauge(self, screen, x, y, width, height):
        """게이지 바 그리기"""
        if not self.active:
            return

        # 배경
        pygame.draw.rect(screen, (50, 50, 50), (x, y, width, height))

        # 게이지
        fill_ratio = self.timer / self.max_duration
        fill_width = int(width * fill_ratio)

        # 그라데이션 효과
        if fill_ratio > 0.5:
            color = (100, 255, 100)  # 초록
        elif fill_ratio > 0.25:
            color = (255, 255, 100)  # 노랑
        else:
            color = (255, 100, 100)  # 빨강

        pygame.draw.rect(screen, color, (x, y, fill_width, height))

        # 테두리
        pygame.draw.rect(screen, (255, 255, 255), (x, y, width, height), 2)

    def get_remaining_time(self):
        """남은 시간을 초 단위로 반환"""
        return self.timer / 60.0

    def get_gauge_ratio(self):
        """게이지 비율 반환 (0.0 ~ 1.0)"""
        if self.max_duration <= 0:
            return 0.0
        return self.timer / self.max_duration


# 싱글톤 인스턴스
laser_scope_instance = None


def get_laser_scope_instance():
    """레이저스코프 싱글톤 인스턴스 반환"""
    global laser_scope_instance
    if laser_scope_instance is None:
        laser_scope_instance = LaserScope()
    return laser_scope_instance


def activate_laser_scope():
    """레이저스코프 활성화"""
    scope = get_laser_scope_instance()
    scope.activate()
    return scope


def deactivate_laser_scope():
    """레이저스코프 비활성화"""
    scope = get_laser_scope_instance()
    scope.deactivate()


def update_laser_scope():
    """레이저스코프 업데이트"""
    scope = get_laser_scope_instance()
    scope.update()


def draw_laser_scope_effects(screen, **kwargs):
    """레이저스코프 효과 그리기"""
    scope = get_laser_scope_instance()
    scope.draw_effects(screen, **kwargs)


def draw_laser_scope_gauge(screen, x, y, width, height):
    """레이저스코프 게이지 바 그리기"""
    scope = get_laser_scope_instance()
    scope.draw_gauge(screen, x, y, width, height)


def is_laser_scope_active():
    """레이저스코프 활성 상태 확인"""
    scope = get_laser_scope_instance()
    return scope.active


def get_laser_scope_remaining_time():
    """레이저스코프 남은 시간 반환"""
    scope = get_laser_scope_instance()
    return scope.get_remaining_time()


def get_laser_scope_gauge_ratio():
    """레이저스코프 게이지 비율 반환"""
    scope = get_laser_scope_instance()
    return scope.get_gauge_ratio()
