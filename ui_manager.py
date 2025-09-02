"""
UI 매니저 모듈
- 텍스트 렌더링 (고급 스타일링 포함)
- 기본 UI 요소 그리기
- 메시지 및 알림 표시
"""

import pygame
import pygame.freetype
import math
import os
import sys

# 리소스 경로 헬퍼
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        # 현재 파일의 디렉토리를 기준으로 함 (ui_manager.py가 있는 위치)
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    return os.path.join(base_path, relative_path)


# 전역 변수들 (bosspong.py에서 import됨)
SCREEN = None
FONT = None
WIDTH = 600
HEIGHT = 750
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
YELLOW = (255, 255, 0)


def init_ui_manager(screen, font, width=600, height=750):
    """UI 매니저 초기화"""
    global SCREEN, FONT, WIDTH, HEIGHT
    SCREEN = screen
    FONT = font
    WIDTH = width
    HEIGHT = height
    print("UI")


def draw_centered_text(text, size, y_offset=0, color=(255, 255, 255), style="elegant"):
    """고급스러운 중앙 정렬 텍스트 렌더링"""
    # 한글 렌더링 개선을 위해 freetype 사용 시도
    use_freetype = False
    
    if style == "elegant":
        # 고급스러운 스타일: 세리프체 느낌의 볼드 폰트 + 그림자 효과
        try:
            # freetype으로 먼저 시도 (한글 렌더링 개선)
            font = pygame.freetype.Font(resource_path("NanumSquareEB.ttf"), size)
            use_freetype = True
        except:
            # 실패하면 기본 Font 사용
            font = pygame.font.Font(resource_path("NanumSquareEB.ttf"), size)
            use_freetype = False
        
        # 부드러운 그림자 효과 (여러 레이어)
        shadow_offsets = [(4, 4), (3, 3), (2, 2), (1, 1)]
        shadow_colors = [(30, 30, 30, 200), (50, 50, 50, 150), (70, 70, 70, 100), (90, 90, 90, 50)]
        
        # 텍스트 위치 계산
        if use_freetype:
            surface, rect = font.render(text, color)
            x = WIDTH // 2 - rect.width // 2
            y = HEIGHT // 2 - rect.height // 2 + y_offset
        else:
            surface = font.render(text, True, color)
            x = WIDTH // 2 - surface.get_width() // 2
            y = HEIGHT // 2 - surface.get_height() // 2 + y_offset
        
        # 그림자 레이어들 그리기
        for offset, shadow_color in zip(shadow_offsets, shadow_colors):
            if use_freetype:
                shadow_surface, _ = font.render(text, shadow_color[:3])
            else:
                shadow_surface = font.render(text, True, shadow_color[:3])
            if len(shadow_color) > 3:  # 알파 값이 있는 경우
                shadow_surface.set_alpha(shadow_color[3])
            SCREEN.blit(shadow_surface, (x + offset[0], y + offset[1]))
        
        # 메인 텍스트
        SCREEN.blit(surface, (x, y))
        
    elif style == "glow":
        # 글로우 효과 스타일
        try:
            font = pygame.freetype.Font(resource_path("NanumSquareB.ttf"), size)
            use_freetype = True
        except:
            font = pygame.font.Font(resource_path("NanumSquareB.ttf"), size)
            use_freetype = False
        
        # 텍스트 위치 계산
        if use_freetype:
            surface, rect = font.render(text, color)
            x = WIDTH // 2 - rect.width // 2
            y = HEIGHT // 2 - rect.height // 2 + y_offset
        else:
            surface = font.render(text, True, color)
            x = WIDTH // 2 - surface.get_width() // 2
            y = HEIGHT // 2 - surface.get_height() // 2 + y_offset
        
        # 글로우 효과 (바깥쪽부터 안쪽으로)
        glow_color = (min(255, color[0] + 50), min(255, color[1] + 50), min(255, color[2] + 50))
        for radius in range(6, 0, -1):
            alpha = int(30 * (6 - radius) / 6)
            if use_freetype:
                glow_surface, _ = font.render(text, glow_color)
            else:
                glow_surface = font.render(text, True, glow_color)
            glow_surface.set_alpha(alpha)
            for dx in range(-radius, radius + 1):
                for dy in range(-radius, radius + 1):
                    if dx*dx + dy*dy <= radius*radius:
                        SCREEN.blit(glow_surface, (x + dx, y + dy))
        
        # 메인 텍스트
        SCREEN.blit(surface, (x, y))
    else:
        # 기본 스타일
        font = pygame.font.Font(resource_path("NanumSquareR.ttf"), size)
        surface = font.render(text, True, color)
        x = WIDTH // 2 - surface.get_width() // 2
        y = HEIGHT // 2 - surface.get_height() // 2 + y_offset
        SCREEN.blit(surface, (x, y))


def draw_text_center(text, color=WHITE, y_offset=0, alpha=255):
    """간단한 중앙 정렬 텍스트 렌더링"""
    txt_surface = FONT.render(text, True, color)
    txt_surface.set_alpha(alpha)
    SCREEN.blit(txt_surface, (WIDTH//2 - txt_surface.get_width()//2, HEIGHT//2 - txt_surface.get_height()//2 + y_offset))


def draw_text_at_position(text, x, y, color=WHITE, font_size=24, alpha=255, center=False):
    """지정된 위치에 텍스트 렌더링"""
    try:
        font = pygame.font.Font(resource_path("NanumSquareR.ttf"), font_size)
    except:
        font = pygame.font.Font(None, font_size)
    
    surface = font.render(text, True, color)
    surface.set_alpha(alpha)
    
    if center:
        x = x - surface.get_width() // 2
        y = y - surface.get_height() // 2
    
    SCREEN.blit(surface, (x, y))
    return surface.get_width(), surface.get_height()  # 텍스트 크기 반환


def draw_outlined_text(text, x, y, font_size=24, text_color=WHITE, outline_color=BLACK, outline_width=2):
    """테두리가 있는 텍스트 렌더링"""
    try:
        font = pygame.font.Font(resource_path("NanumSquareR.ttf"), font_size)
    except:
        font = pygame.font.Font(None, font_size)
    
    # 테두리 그리기
    for dx in range(-outline_width, outline_width + 1):
        for dy in range(-outline_width, outline_width + 1):
            if dx*dx + dy*dy <= outline_width*outline_width:
                outline_surface = font.render(text, True, outline_color)
                SCREEN.blit(outline_surface, (x + dx, y + dy))
    
    # 메인 텍스트 그리기
    text_surface = font.render(text, True, text_color)
    SCREEN.blit(text_surface, (x, y))


def show_winner_text(winner_name):
    """승자 텍스트 표시"""
    # 배경 어둡게
    overlay = pygame.Surface((WIDTH, HEIGHT))
    overlay.set_alpha(180)
    overlay.fill((0, 0, 0))
    SCREEN.blit(overlay, (0, 0))
    
    # 승자 텍스트
    if winner_name == "Player":
        draw_centered_text("승리!", 80, -50, (255, 215, 0), "glow")  # 골드 컬러
        draw_centered_text("Victory!", 50, 20, (255, 255, 255), "elegant")
    else:
        draw_centered_text("패배", 80, -50, (255, 100, 100), "glow")  # 빨간색
        draw_centered_text("Defeat", 50, 20, (200, 200, 200), "elegant")


def show_speech(text, duration=60):
    """말풍선 스타일 텍스트 표시"""
    # 말풍선 배경
    speech_width = 400
    speech_height = 100
    speech_x = WIDTH // 2 - speech_width // 2
    speech_y = HEIGHT // 4
    
    # 둥근 사각형 배경
    pygame.draw.rect(SCREEN, (50, 50, 50, 200), (speech_x, speech_y, speech_width, speech_height), border_radius=20)
    pygame.draw.rect(SCREEN, WHITE, (speech_x, speech_y, speech_width, speech_height), 3, border_radius=20)
    
    # 텍스트
    draw_text_at_position(text, WIDTH // 2, speech_y + speech_height // 2, WHITE, 24, center=True)


def create_button(x, y, width, height, text, font_size=24, 
                 bg_color=(70, 70, 70), text_color=WHITE, 
                 border_color=WHITE, border_width=2, hover=False):
    """재사용 가능한 버튼 생성"""
    # 호버 효과
    if hover:
        bg_color = (min(255, bg_color[0] + 30), min(255, bg_color[1] + 30), min(255, bg_color[2] + 30))
    
    # 버튼 배경
    pygame.draw.rect(SCREEN, bg_color, (x, y, width, height), border_radius=10)
    if border_width > 0:
        pygame.draw.rect(SCREEN, border_color, (x, y, width, height), border_width, border_radius=10)
    
    # 버튼 텍스트
    draw_text_at_position(text, x + width // 2, y + height // 2, text_color, font_size, center=True)
    
    return pygame.Rect(x, y, width, height)


def draw_progress_bar(x, y, width, height, progress, bg_color=(50, 50, 50), 
                     fill_color=(0, 255, 0), border_color=WHITE):
    """진행률 바 그리기"""
    # 배경
    pygame.draw.rect(SCREEN, bg_color, (x, y, width, height))
    
    # 진행률 (0.0 ~ 1.0)
    fill_width = int(width * max(0, min(1, progress)))
    if fill_width > 0:
        pygame.draw.rect(SCREEN, fill_color, (x, y, fill_width, height))
    
    # 테두리
    pygame.draw.rect(SCREEN, border_color, (x, y, width, height), 2)


def draw_gradient_background(start_color, end_color, direction="vertical"):
    """그라데이션 배경 그리기"""
    if direction == "vertical":
        for y in range(HEIGHT):
            ratio = y / HEIGHT
            color = [
                int(start_color[i] + (end_color[i] - start_color[i]) * ratio)
                for i in range(3)
            ]
            pygame.draw.line(SCREEN, color, (0, y), (WIDTH, y))
    else:  # horizontal
        for x in range(WIDTH):
            ratio = x / WIDTH
            color = [
                int(start_color[i] + (end_color[i] - start_color[i]) * ratio)
                for i in range(3)
            ]
            pygame.draw.line(SCREEN, color, (x, 0), (x, HEIGHT))


def apply_screen_effect(effect_type, intensity=0.5):
    """화면 효과 적용"""
    overlay = pygame.Surface((WIDTH, HEIGHT))
    
    if effect_type == "red":
        overlay.fill((255, 0, 0))
        overlay.set_alpha(int(100 * intensity))
    elif effect_type == "blue":
        overlay.fill((0, 100, 255))
        overlay.set_alpha(int(80 * intensity))
    elif effect_type == "white_flash":
        overlay.fill((255, 255, 255))
        overlay.set_alpha(int(150 * intensity))
    elif effect_type == "darken":
        overlay.fill((0, 0, 0))
        overlay.set_alpha(int(180 * intensity))
    
    SCREEN.blit(overlay, (0, 0))


def smart_text_wrap(text, max_width_chars=30):
    """텍스트 자동 줄바꿈"""
    words = text.split(' ')
    lines = []
    current_line = ""
    
    for word in words:
        if len(current_line + word) <= max_width_chars:
            current_line += word + " "
        else:
            if current_line:
                lines.append(current_line.strip())
            current_line = word + " "
    
    if current_line:
        lines.append(current_line.strip())
    
    return lines


def draw_multiline_text(text_lines, x, y, font_size=24, color=WHITE, 
                       line_spacing=5, center=False):
    """여러 줄 텍스트 렌더링"""
    try:
        font = pygame.font.Font(resource_path("NanumSquareR.ttf"), font_size)
    except:
        font = pygame.font.Font(None, font_size)
    
    total_height = len(text_lines) * (font_size + line_spacing) - line_spacing
    start_y = y - total_height // 2 if center else y
    
    for i, line in enumerate(text_lines):
        line_y = start_y + i * (font_size + line_spacing)
        surface = font.render(line, True, color)
        
        if center:
            line_x = x - surface.get_width() // 2
        else:
            line_x = x
            
        SCREEN.blit(surface, (line_x, line_y))


def create_notification(text, duration=120, pos_type="center"):
    """알림 메시지 표시"""
    # 알림 창 크기 계산
    text_lines = smart_text_wrap(text, 25)
    notification_width = 350
    notification_height = 80 + len(text_lines) * 25
    
    # 위치 계산
    if pos_type == "center":
        x = WIDTH // 2 - notification_width // 2
        y = HEIGHT // 2 - notification_height // 2
    elif pos_type == "top":
        x = WIDTH // 2 - notification_width // 2
        y = 50
    else:  # bottom
        x = WIDTH // 2 - notification_width // 2
        y = HEIGHT - notification_height - 50
    
    # 배경
    pygame.draw.rect(SCREEN, (40, 40, 40, 220), (x, y, notification_width, notification_height), border_radius=15)
    pygame.draw.rect(SCREEN, (100, 100, 100), (x, y, notification_width, notification_height), 3, border_radius=15)
    
    # 텍스트
    draw_multiline_text(text_lines, x + notification_width // 2, y + 40, 20, WHITE, center=True)


# 애니메이션 관련 함수들
def lerp(start, end, t):
    """선형 보간"""
    return start + (end - start) * t


def ease_in_out(t):
    """이징 함수 (부드러운 시작과 끝)"""
    return t * t * (3.0 - 2.0 * t)


def ease_bounce(t):
    """바운스 이징"""
    if t < 0.5:
        return 2 * t * t
    else:
        return 1 - 2 * (1 - t) * (1 - t)


def animate_value(start_value, end_value, progress, easing_func=None):
    """값 애니메이션"""
    if easing_func:
        progress = easing_func(progress)
    return lerp(start_value, end_value, progress)


def test_ui_functions():
    """UI 함수 테스트 (개발용)"""
    print("UI")
    
    # pygame 초기화
    pygame.init()
    screen = pygame.display.set_mode((600, 750))
    font = pygame.font.Font(None, 24)
    
    # UI 매니저 초기화
    init_ui_manager(screen, font)
    
    # 테스트 화면
    clock = pygame.time.Clock()
    running = True
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
        
        # 배경
        screen.fill((20, 20, 40))
        
        # 다양한 텍스트 스타일 테스트
        draw_centered_text("Elegant Style", 40, -200, (255, 215, 0), "elegant")
        draw_centered_text("Glow Style", 40, -150, (0, 255, 255), "glow")
        draw_centered_text("Basic Style", 40, -100, WHITE, "basic")
        
        # 버튼 테스트
        create_button(250, 300, 100, 40, "Button", hover=True)
        
        # 진행률 바 테스트
        draw_progress_bar(200, 400, 200, 20, 0.7)
        
        # 알림 테스트
        create_notification("This is a test notification!", pos_type="bottom")
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()


# 모듈 테스트
if __name__ == "__main__":
    test_ui_functions()

