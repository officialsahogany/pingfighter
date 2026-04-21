# -*- coding: utf-8 -*-
"""PingFighter 스플래시 스크린 - 최소한의 import로 즉시 로딩 화면 표시

이 모듈은 게임 시작 시 즉시 로딩 화면을 표시하기 위해
pygame만 최소한으로 초기화합니다.
붉게 타오르는 태양 필러 애니메이션 포함 - 로딩 진행률에 따라 점진적으로 강렬해짐
"""

import os
import sys
import math
import time

# PyInstaller 경로 설정
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

# pygame 초기화 (최소한만)
os.environ.setdefault("PYGAME_HIDE_SUPPORT_PROMPT", "1")
import pygame

# 불타는 태양 필러
from pillar_blazing_sun import BlazingSunFrame

# 화면 크기 (게임과 동일하게 세로로 긴 화면)
BASE_WIDTH, BASE_HEIGHT = 600, 750
# 게임 영역 크기 (필러용 - 화면 전체가 게임 영역)
BASE_GAME_WIDTH, BASE_GAME_HEIGHT = 520, 670


def _get_desktop_resolution():
    """Choose the largest detected desktop size for the startup splash."""
    try:
        desktop_sizes = pygame.display.get_desktop_sizes()
        if desktop_sizes:
            return max(desktop_sizes, key=lambda size: size[0] * size[1])
    except Exception:
        pass

    try:
        info = pygame.display.Info()
        if info.current_w > 0 and info.current_h > 0:
            return (info.current_w, info.current_h)
    except Exception:
        pass

    return (BASE_WIDTH, BASE_HEIGHT)


def _get_preferred_window_size():
    """Match the main window's large startup footprint instead of a mini popup."""
    monitor_w, monitor_h = _get_desktop_resolution()
    base_h = int(monitor_h * 0.85)
    win_scale = base_h / BASE_HEIGHT
    game_w = int(BASE_WIDTH * win_scale)
    pillar_pad_x = int(game_w * 0.30)
    pillar_pad_y = max(int(base_h * 0.065), 30)
    target_w = game_w + pillar_pad_x * 2
    target_h = base_h + pillar_pad_y * 2

    target_w = min(target_w, int(monitor_w * 0.90))
    target_h = min(target_h, int(monitor_h * 0.85))
    target_w = max(BASE_WIDTH, target_w)
    target_h = max(BASE_HEIGHT, target_h)
    return (target_w, target_h)

class SplashScreen:
    """즉시 표시되는 스플래시/로딩 화면"""

    def __init__(self):
        # pygame 초기화
        pygame.init()
        pygame.display.set_caption("PingFighter - Loading...")

        # 아이콘 설정
        try:
            icon_path = resource_path("ball.ico")
            if os.path.exists(icon_path):
                icon = pygame.image.load(icon_path)
                pygame.display.set_icon(icon)
        except:
            pass

        # 화면 생성
        self.width, self.height = _get_preferred_window_size()
        self.scale = min(self.height / BASE_HEIGHT, self.width / BASE_WIDTH)
        self.game_width = max(BASE_GAME_WIDTH, int(BASE_GAME_WIDTH * self.scale))
        self.game_height = max(BASE_GAME_HEIGHT, int(BASE_GAME_HEIGHT * self.scale))
        self.game_x = (self.width - self.game_width) // 2
        self.game_y = (self.height - self.game_height) // 2
        os.environ['SDL_VIDEO_CENTERED'] = '1'
        self.screen = pygame.display.set_mode((self.width, self.height), pygame.DOUBLEBUF)
        os.environ.pop('SDL_VIDEO_CENTERED', None)
        self.clock = pygame.time.Clock()
        self.start_time = time.time()
        self.progress = 0.0
        self.message = "게임을 시작하는 중..."

        # 폰트 로드 (시스템 폰트 사용 - 빠른 로딩)
        pygame.font.init()
        self.title_font = pygame.font.Font(None, max(72, int(72 * self.scale)))
        self.font = pygame.font.Font(None, max(36, int(36 * self.scale)))
        self.small_font = pygame.font.Font(None, max(24, int(24 * self.scale)))

        # 한글 폰트 시도
        try:
            font_path = resource_path("NanumSquareB.ttf")
            if os.path.exists(font_path):
                self.title_font = pygame.font.Font(font_path, max(48, int(48 * self.scale)))
                self.font = pygame.font.Font(font_path, max(28, int(28 * self.scale)))
                self.small_font = pygame.font.Font(font_path, max(18, int(18 * self.scale)))
        except:
            pass

        # 불타는 태양 필러 초기화
        self.blazing_sun = BlazingSunFrame(
            self.width,
            self.height,
            self.game_width,
            self.game_height,
        )
        self.last_time = time.time()

        # 별 배경 초기화 (게임 영역 내부용)
        self.stars = []
        for _ in range(max(80, int(80 * self.scale))):
            self.stars.append({
                'x': self.game_x + float(hash(str(_) + 'x') % self.game_width),
                'y': self.game_y + float(hash(str(_) + 'y') % self.game_height),
                'speed': 0.5 + (hash(str(_)) % 100) / 100,
                'size': 1 + (hash(str(_) + 's') % 3),
                'alpha': 100 + (hash(str(_) + 'a') % 155)
            })

        # 첫 프레임 즉시 표시
        self.draw()

    def update_progress(self, progress: float, message: str = None):
        """진행률과 메시지 업데이트"""
        self.progress = min(1.0, max(0.0, progress))
        if message:
            self.message = message
        self.draw()

    def draw(self):
        """로딩 화면 그리기"""
        # 이벤트 처리 (창 닫기 등)
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()

        now = time.time()
        dt = now - self.last_time
        self.last_time = now
        elapsed = now - self.start_time
        pulse = (math.sin(now * 3) + 1) / 2

        # 불타는 태양 필러 업데이트 및 그리기
        # 로딩 진행률에 따라 강렬함 설정
        self.blazing_sun.set_intensity(self.progress)
        self.blazing_sun.update(dt)
        self.blazing_sun.draw(self.screen)

        # 게임 영역 내부에 별 배경 그리기
        game_x = self.game_x
        game_y = self.game_y
        for star in self.stars:
            star['y'] += star['speed']
            if star['y'] > game_y + self.game_height:
                star['y'] = game_y
                star['x'] = game_x + float(hash(str(now) + str(star['x'])) % self.game_width)

            alpha = int(star['alpha'] * (0.5 + 0.5 * math.sin(now * 2 + star['x'])))
            color = (alpha, alpha, alpha)
            pygame.draw.circle(self.screen, color, (int(star['x']), int(star['y'])), star['size'])

        # 타이틀 글로우 효과
        title_text = "PING FIGHTER"
        glow_colors = [(255, 0, 150), (0, 255, 255)]

        for i, color in enumerate(glow_colors):
            glow_surface = self.title_font.render(title_text, True, color)
            glow_rect = glow_surface.get_rect(center=(self.width // 2, self.height // 3 - int(20 * self.scale)))
            glow_alpha = pygame.Surface(glow_surface.get_size(), pygame.SRCALPHA)
            glow_alpha.blit(glow_surface, (0, 0))
            glow_alpha.set_alpha(int(30 + pulse * 20))
            for offset in [(3, 3), (-3, -3), (3, -3), (-3, 3)]:
                self.screen.blit(glow_alpha, (glow_rect.x + offset[0], glow_rect.y + offset[1]))

        # 메인 타이틀
        title_surface = self.title_font.render(title_text, True, (255, 255, 255))
        title_rect = title_surface.get_rect(center=(self.width // 2, self.height // 3 - int(20 * self.scale)))
        self.screen.blit(title_surface, title_rect)

        # 서브라인 효과
        line_y = self.height // 3 + int(20 * self.scale)
        line_width = max(200, int(200 * self.scale))
        pygame.draw.line(self.screen, (0, 200, 255),
                        (self.width // 2 - line_width, line_y),
                        (self.width // 2, line_y), 2)
        pygame.draw.line(self.screen, (255, 0, 150),
                        (self.width // 2, line_y),
                        (self.width // 2 + line_width, line_y), 2)

        # 로딩 메시지
        msg_alpha = int(180 + 75 * math.sin(now * 4))
        msg_surface = self.font.render(self.message, True, (200, 220, 255))
        msg_rect = msg_surface.get_rect(center=(self.width // 2, self.height // 2 + int(30 * self.scale)))
        self.screen.blit(msg_surface, msg_rect)

        # 프로그레스 바
        bar_width = min(int(500 * self.scale), int(self.width * 0.55))
        bar_height = max(8, int(8 * self.scale))
        bar_x = (self.width - bar_width) // 2
        bar_y = self.height // 2 + int(80 * self.scale)

        # 외곽 프레임
        frame_rect = pygame.Rect(bar_x - 4, bar_y - 4, bar_width + 8, bar_height + 8)
        pygame.draw.rect(self.screen, (0, 80, 100), frame_rect, border_radius=4)
        pygame.draw.rect(self.screen, (0, 200, 255), frame_rect, 2, border_radius=4)

        # 배경 바
        bg_rect = pygame.Rect(bar_x, bar_y, bar_width, bar_height)
        pygame.draw.rect(self.screen, (20, 30, 50), bg_rect, border_radius=3)

        # 진행 바
        fill_width = int(bar_width * self.progress)
        if fill_width > 0:
            # 그라데이션 효과
            for i in range(fill_width):
                ratio = i / bar_width
                r = int(0 + ratio * 255)
                g = int(200 - ratio * 50)
                b = int(255 - ratio * 105)
                pygame.draw.line(self.screen, (r, g, b),
                               (bar_x + i, bar_y), (bar_x + i, bar_y + bar_height - 1))

            # 하이라이트
            highlight_rect = pygame.Rect(bar_x, bar_y, fill_width, bar_height // 3)
            pygame.draw.rect(self.screen, (255, 255, 255, 50), highlight_rect, border_radius=2)

        # 퍼센트 표시
        percent_text = f"{int(self.progress * 100)}%"
        percent_surface = self.small_font.render(percent_text, True, (150, 200, 255))
        percent_rect = percent_surface.get_rect(center=(self.width // 2, bar_y + int(35 * self.scale)))
        self.screen.blit(percent_surface, percent_rect)

        # 하단 정보
        info_text = "© 2025 PingFighter Team"
        info_surface = self.small_font.render(info_text, True, (80, 100, 120))
        info_rect = info_surface.get_rect(center=(self.width // 2, self.height - int(40 * self.scale)))
        self.screen.blit(info_surface, info_rect)

        # 화면 업데이트
        pygame.display.flip()
        self.clock.tick(60)

    def close(self):
        """스플래시 화면 종료 (pygame display만 정리, pygame 자체는 유지)"""
        # 현재 디스플레이 모드를 정리하여 다음 set_mode가 깨끗하게 시작되도록 함
        # 이렇게 하면 pygame.display.Info()가 스플래시 창 크기가 아닌
        # 실제 모니터 해상도를 반환함
        try:
            pygame.display.quit()
            pygame.display.init()
        except Exception:
            pass  # 에러 발생 시 무시


# 전역 스플래시 인스턴스
_splash_instance = None

def show_splash():
    """스플래시 화면 표시 및 인스턴스 반환"""
    global _splash_instance
    if _splash_instance is None:
        _splash_instance = SplashScreen()
    return _splash_instance

def update_splash(progress: float, message: str = None):
    """스플래시 화면 진행률 업데이트"""
    global _splash_instance
    if _splash_instance is not None:
        _splash_instance.update_progress(progress, message)

def close_splash():
    """스플래시 화면 종료"""
    global _splash_instance
    if _splash_instance is not None:
        _splash_instance.close()
        _splash_instance = None


if __name__ == "__main__":
    # 테스트
    splash = show_splash()

    messages = [
        "초기화 중...",
        "리소스 로딩 중...",
        "사운드 로딩 중...",
        "그래픽 준비 중...",
        "게임 시작!"
    ]

    for i, msg in enumerate(messages):
        progress = (i + 1) / len(messages)
        update_splash(progress, msg)
        time.sleep(0.5)

    time.sleep(1)
    close_splash()
    pygame.quit()
