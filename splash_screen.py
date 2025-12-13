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
WIDTH, HEIGHT = 600, 750
# 게임 영역 크기 (필러용 - 화면 전체가 게임 영역)
GAME_WIDTH, GAME_HEIGHT = 520, 670

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
        self.screen = pygame.display.set_mode((WIDTH, HEIGHT))
        self.clock = pygame.time.Clock()
        self.start_time = time.time()
        self.progress = 0.0
        self.message = "게임을 시작하는 중..."

        # 폰트 로드 (시스템 폰트 사용 - 빠른 로딩)
        pygame.font.init()
        self.title_font = pygame.font.Font(None, 72)
        self.font = pygame.font.Font(None, 36)
        self.small_font = pygame.font.Font(None, 24)

        # 한글 폰트 시도
        try:
            font_path = resource_path("NanumSquareB.ttf")
            if os.path.exists(font_path):
                self.title_font = pygame.font.Font(font_path, 48)
                self.font = pygame.font.Font(font_path, 28)
                self.small_font = pygame.font.Font(font_path, 18)
        except:
            pass

        # 불타는 태양 필러 초기화
        self.blazing_sun = BlazingSunFrame(WIDTH, HEIGHT, GAME_WIDTH, GAME_HEIGHT)
        self.last_time = time.time()

        # 별 배경 초기화 (게임 영역 내부용)
        self.stars = []
        game_x = (WIDTH - GAME_WIDTH) // 2
        game_y = (HEIGHT - GAME_HEIGHT) // 2
        for _ in range(80):
            self.stars.append({
                'x': game_x + float(hash(str(_) + 'x') % GAME_WIDTH),
                'y': game_y + float(hash(str(_) + 'y') % GAME_HEIGHT),
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
        game_x = (WIDTH - GAME_WIDTH) // 2
        game_y = (HEIGHT - GAME_HEIGHT) // 2
        for star in self.stars:
            star['y'] += star['speed']
            if star['y'] > game_y + GAME_HEIGHT:
                star['y'] = game_y
                star['x'] = game_x + float(hash(str(now) + str(star['x'])) % GAME_WIDTH)

            alpha = int(star['alpha'] * (0.5 + 0.5 * math.sin(now * 2 + star['x'])))
            color = (alpha, alpha, alpha)
            pygame.draw.circle(self.screen, color, (int(star['x']), int(star['y'])), star['size'])

        # 타이틀 글로우 효과
        title_text = "PING FIGHTER"
        glow_colors = [(255, 0, 150), (0, 255, 255)]

        for i, color in enumerate(glow_colors):
            glow_surface = self.title_font.render(title_text, True, color)
            glow_rect = glow_surface.get_rect(center=(WIDTH // 2, HEIGHT // 3 - 20))
            glow_alpha = pygame.Surface(glow_surface.get_size(), pygame.SRCALPHA)
            glow_alpha.blit(glow_surface, (0, 0))
            glow_alpha.set_alpha(int(30 + pulse * 20))
            for offset in [(3, 3), (-3, -3), (3, -3), (-3, 3)]:
                self.screen.blit(glow_alpha, (glow_rect.x + offset[0], glow_rect.y + offset[1]))

        # 메인 타이틀
        title_surface = self.title_font.render(title_text, True, (255, 255, 255))
        title_rect = title_surface.get_rect(center=(WIDTH // 2, HEIGHT // 3 - 20))
        self.screen.blit(title_surface, title_rect)

        # 서브라인 효과
        line_y = HEIGHT // 3 + 20
        line_width = 200
        pygame.draw.line(self.screen, (0, 200, 255),
                        (WIDTH // 2 - line_width, line_y),
                        (WIDTH // 2, line_y), 2)
        pygame.draw.line(self.screen, (255, 0, 150),
                        (WIDTH // 2, line_y),
                        (WIDTH // 2 + line_width, line_y), 2)

        # 로딩 메시지
        msg_alpha = int(180 + 75 * math.sin(now * 4))
        msg_surface = self.font.render(self.message, True, (200, 220, 255))
        msg_rect = msg_surface.get_rect(center=(WIDTH // 2, HEIGHT // 2 + 30))
        self.screen.blit(msg_surface, msg_rect)

        # 프로그레스 바
        bar_width = min(500, int(WIDTH * 0.55))
        bar_height = 8
        bar_x = (WIDTH - bar_width) // 2
        bar_y = HEIGHT // 2 + 80

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
        percent_rect = percent_surface.get_rect(center=(WIDTH // 2, bar_y + 35))
        self.screen.blit(percent_surface, percent_rect)

        # 하단 정보
        info_text = "© 2025 PingFighter Team"
        info_surface = self.small_font.render(info_text, True, (80, 100, 120))
        info_rect = info_surface.get_rect(center=(WIDTH // 2, HEIGHT - 40))
        self.screen.blit(info_surface, info_rect)

        # 화면 업데이트
        pygame.display.flip()
        self.clock.tick(60)

    def close(self):
        """스플래시 화면 종료 (pygame은 유지)"""
        pass  # pygame은 메인 게임에서 계속 사용


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
