#!/usr/bin/env python3
"""
고퀄리티 3D 입체 사이버펑크 야구장 전광판 미리보기
- 실제 야구장 전광판 스타일
- 입체적 깊이감
- 역동적 애니메이션 효과
"""
import pygame
import math
import random
import sys
import os

# 화면 설정
WIDTH = 1400
HEIGHT = 800

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
NEON_CYAN = (0, 255, 255)
NEON_MAGENTA = (255, 0, 200)
NEON_LIME = (50, 255, 100)
NEON_ORANGE = (255, 150, 50)
NEON_PINK = (255, 100, 180)
GOLD = (255, 215, 0)

pygame.init()
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("3D 사이버펑크 전광판 미리보기")
clock = pygame.time.Clock()

# 폰트 로드
try:
    font_path = os.path.join(os.path.dirname(__file__), "fonts", "NeoDunggeunmoPro-Regular.ttf")
    if os.path.exists(font_path):
        font_huge = pygame.font.Font(font_path, 150)
        font_large = pygame.font.Font(font_path, 80)
        font_medium = pygame.font.Font(font_path, 48)
        font_small = pygame.font.Font(font_path, 32)
        font_title = pygame.font.Font(font_path, 42)
        font_tiny = pygame.font.Font(font_path, 24)
    else:
        font_huge = pygame.font.Font(None, 150)
        font_large = pygame.font.Font(None, 80)
        font_medium = pygame.font.Font(None, 48)
        font_small = pygame.font.Font(None, 32)
        font_title = pygame.font.Font(None, 42)
        font_tiny = pygame.font.Font(None, 24)
except:
    font_huge = pygame.font.Font(None, 150)
    font_large = pygame.font.Font(None, 80)
    font_medium = pygame.font.Font(None, 48)
    font_small = pygame.font.Font(None, 32)
    font_title = pygame.font.Font(None, 42)
    font_tiny = pygame.font.Font(None, 24)


def draw_3d_box(surface, rect, depth=20, base_color=(30, 40, 60),
                highlight_color=(80, 100, 140), shadow_color=(15, 20, 30)):
    """3D 입체 박스 그리기"""
    x, y, w, h = rect

    # 상단면 (밝은 면)
    top_points = [
        (x, y),
        (x + depth, y - depth),
        (x + w + depth, y - depth),
        (x + w, y)
    ]
    pygame.draw.polygon(surface, highlight_color, top_points)
    pygame.draw.polygon(surface, (min(255, highlight_color[0]+30),
                                   min(255, highlight_color[1]+30),
                                   min(255, highlight_color[2]+30)), top_points, 2)

    # 우측면 (어두운 면)
    right_points = [
        (x + w, y),
        (x + w + depth, y - depth),
        (x + w + depth, y + h - depth),
        (x + w, y + h)
    ]
    pygame.draw.polygon(surface, shadow_color, right_points)
    pygame.draw.polygon(surface, (shadow_color[0]+20, shadow_color[1]+20, shadow_color[2]+20), right_points, 2)

    # 정면
    pygame.draw.rect(surface, base_color, rect)
    pygame.draw.rect(surface, highlight_color, rect, 3)


def draw_neon_glow_rect(surface, rect, color, glow_intensity=8):
    """네온 글로우 효과가 있는 사각형"""
    x, y, w, h = rect
    for i in range(glow_intensity, 0, -1):
        alpha = int(80 / i)
        glow_surf = pygame.Surface((w + i*4, h + i*4), pygame.SRCALPHA)
        glow_color = (*color[:3], alpha)
        pygame.draw.rect(glow_surf, glow_color, (0, 0, w + i*4, h + i*4), border_radius=5)
        surface.blit(glow_surf, (x - i*2, y - i*2))
    pygame.draw.rect(surface, color, rect, 3, border_radius=3)


def draw_led_digit_3d(surface, x, y, digit, color, size=120, depth=8, time_offset=0):
    """3D 효과가 있는 LED 숫자 (도트 매트릭스)"""
    patterns = {
        '0': ["  111  ", " 11 11 ", "11   11", "11   11", "11   11", "11   11", "11   11", " 11 11 ", "  111  "],
        '1': ["   11  ", "  111  ", " 1111  ", "   11  ", "   11  ", "   11  ", "   11  ", "   11  ", " 111111"],
        '2': [" 11111 ", "11   11", "     11", "    11 ", "   11  ", "  11   ", " 11    ", "11     ", "1111111"],
        '3': [" 11111 ", "11   11", "     11", "  1111 ", "     11", "     11", "11   11", " 11111 ", "       "],
        '4': ["    111", "   1111", "  11 11", " 11  11", "1111111", "     11", "     11", "     11", "     11"],
        '5': ["1111111", "11     ", "11     ", "111111 ", "     11", "     11", "11   11", " 11111 ", "       "],
        '6': [" 11111 ", "11     ", "11     ", "111111 ", "11   11", "11   11", "11   11", " 11111 ", "       "],
        '7': ["1111111", "11   11", "    11 ", "   11  ", "  11   ", "  11   ", "  11   ", "  11   ", "       "],
        '8': [" 11111 ", "11   11", "11   11", " 11111 ", "11   11", "11   11", "11   11", " 11111 ", "       "],
        '9': [" 11111 ", "11   11", "11   11", " 111111", "     11", "     11", "11   11", " 11111 ", "       "]
    }

    pattern = patterns.get(str(digit), patterns['0'])
    spacing = size // 9
    dot_size = spacing // 2 - 1

    for row_idx, row in enumerate(pattern):
        for col_idx, char in enumerate(row):
            dot_x = x + col_idx * spacing
            dot_y = y + row_idx * spacing

            if char == '1':
                # 깊이 효과
                for d in range(depth, 0, -2):
                    dim_factor = d / depth
                    dim_color = (int(color[0] * 0.3 * dim_factor),
                                int(color[1] * 0.3 * dim_factor),
                                int(color[2] * 0.3 * dim_factor))
                    pygame.draw.circle(surface, dim_color, (dot_x + d//2, dot_y + d//2), dot_size)

                # 글로우 효과
                pulse = 0.8 + 0.2 * math.sin(time_offset + row_idx * 0.2 + col_idx * 0.1)
                for glow in range(4, 0, -1):
                    glow_alpha = int(60 / glow * pulse)
                    glow_surf = pygame.Surface((dot_size*2 + glow*4, dot_size*2 + glow*4), pygame.SRCALPHA)
                    glow_color = (*color[:3], glow_alpha)
                    pygame.draw.circle(glow_surf, glow_color, (dot_size + glow*2, dot_size + glow*2), dot_size + glow*2)
                    surface.blit(glow_surf, (dot_x - dot_size - glow*2, dot_y - dot_size - glow*2))

                # 메인 LED
                bright_color = (min(255, int(color[0] * pulse)),
                               min(255, int(color[1] * pulse)),
                               min(255, int(color[2] * pulse)))
                pygame.draw.circle(surface, bright_color, (dot_x, dot_y), dot_size)

                # 하이라이트
                highlight = (min(255, color[0] + 100), min(255, color[1] + 100), min(255, color[2] + 100))
                pygame.draw.circle(surface, highlight, (dot_x - dot_size//3, dot_y - dot_size//3), dot_size//3)
            else:
                # 꺼진 LED
                pygame.draw.circle(surface, (15, 15, 20), (dot_x, dot_y), dot_size - 1)


def draw_holographic_text(surface, text, x, y, font, color, time_offset=0):
    """홀로그래픽 효과가 있는 텍스트"""
    # RGB 분리 효과
    offset = int(2 * math.sin(time_offset * 2))

    # 레드 채널
    red_text = font.render(text, True, (color[0], 0, 0))
    surface.blit(red_text, (x - offset, y))

    # 그린 채널
    green_text = font.render(text, True, (0, color[1], 0))
    surface.blit(green_text, (x, y))

    # 블루 채널
    blue_text = font.render(text, True, (0, 0, color[2]))
    surface.blit(blue_text, (x + offset, y))

    # 메인 텍스트
    main_text = font.render(text, True, color)
    surface.blit(main_text, (x, y))


def draw_style1_stadium_3d(surface, time_offset):
    """스타일 1: 메이저리그 스타디움 3D - 실제 야구��� 전광판"""
    board_width = 900
    board_height = 500
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 배경 깊이감
    for i in range(5):
        depth_rect = (board_x - i*15, board_y - i*10, board_width + i*30, board_height + i*20)
        depth_color = (8 + i*2, 12 + i*3, 25 + i*4)
        pygame.draw.rect(surface, depth_color, depth_rect, border_radius=15 - i*2)

    # 메인 3D 프레임
    draw_3d_box(surface, (board_x, board_y, board_width, board_height),
                depth=30, base_color=(10, 15, 30),
                highlight_color=(50, 70, 100), shadow_color=(5, 8, 15))

    # 내부 스크린 영역
    screen_margin = 25
    screen_rect = (board_x + screen_margin, board_y + screen_margin,
                   board_width - screen_margin*2, board_height - screen_margin*2)
    pygame.draw.rect(surface, (3, 5, 12), screen_rect, border_radius=8)

    # 스캔라인 효과
    for y_line in range(board_y + screen_margin, board_y + board_height - screen_margin, 3):
        alpha = 15 + int(10 * math.sin(time_offset + y_line * 0.05))
        line_color = (0, alpha, alpha // 2)
        pygame.draw.line(surface, line_color,
                        (board_x + screen_margin, y_line),
                        (board_x + board_width - screen_margin, y_line), 1)

    # 상단 헤더 바 (3D)
    header_rect = (board_x + 40, board_y + 35, board_width - 80, 70)
    draw_3d_box(surface, header_rect, depth=10,
                base_color=(20, 40, 80), highlight_color=(60, 100, 180), shadow_color=(10, 20, 40))

    # 타이틀
    pulse = 0.9 + 0.1 * math.sin(time_offset * 3)
    title_color = (int(255 * pulse), int(220 * pulse), 0)
    draw_holographic_text(surface, "⚾ PING FIGHTER STADIUM ⚾",
                         board_x + 130, board_y + 50, font_title, title_color, time_offset)

    # 플레이어 섹션 (좌측 3D 박스)
    p_box = (board_x + 50, board_y + 130, 350, 320)
    draw_3d_box(surface, p_box, depth=15,
                base_color=(10, 30, 50), highlight_color=(30, 80, 140), shadow_color=(5, 15, 25))
    draw_neon_glow_rect(surface, p_box, NEON_CYAN, 6)

    # 플레이어 라벨
    p_label = font_medium.render("PLAYER", True, NEON_CYAN)
    surface.blit(p_label, (board_x + 130, board_y + 145))

    # 플레이어 점수 (3D LED)
    draw_led_digit_3d(surface, board_x + 130, board_y + 200, 2, NEON_CYAN, 140, 8, time_offset)

    # 보스 섹션 (우측 3D 박스)
    b_box = (board_x + board_width - 400, board_y + 130, 350, 320)
    draw_3d_box(surface, b_box, depth=15,
                base_color=(50, 15, 30), highlight_color=(140, 40, 80), shadow_color=(25, 8, 15))
    draw_neon_glow_rect(surface, b_box, NEON_MAGENTA, 6)

    # 보스 라벨
    b_label = font_medium.render("BOSS", True, NEON_MAGENTA)
    surface.blit(b_label, (board_x + board_width - 300, board_y + 145))

    # 보스 점수 (3D LED)
    draw_led_digit_3d(surface, board_x + board_width - 300, board_y + 200, 1, NEON_MAGENTA, 140, 8, time_offset)

    # 중앙 VS 섹터 (3D 다이아몬드)
    vs_x = board_x + board_width // 2
    vs_y = board_y + board_height // 2 + 20

    # 다중 다이아몬드 레이어
    for size in range(80, 30, -10):
        angle = time_offset * 0.5
        points = []
        for i in range(4):
            px = vs_x + size * math.cos(angle + i * math.pi / 2)
            py = vs_y + size * 0.7 * math.sin(angle + i * math.pi / 2)
            points.append((px, py))
        color_val = 255 - size * 2
        pygame.draw.polygon(surface, (color_val, color_val // 2, color_val), points, 3)

    vs_text = font_large.render("VS", True, GOLD)
    vs_rect = vs_text.get_rect(center=(vs_x, vs_y))
    surface.blit(vs_text, vs_rect)

    # 하단 상태 바 (3D)
    status_rect = (board_x + 40, board_y + board_height - 60, board_width - 80, 40)
    draw_3d_box(surface, status_rect, depth=8,
                base_color=(30, 20, 50), highlight_color=(80, 50, 120), shadow_color=(15, 10, 25))

    scroll_offset = int((time_offset * 50) % 400)
    status_text = font_small.render("🔥 INTENSE BATTLE IN PROGRESS 🔥   ⚡ ROUND 3 ⚡", True, NEON_ORANGE)
    surface.blit(status_text, (board_x + 180, board_y + board_height - 52))


def draw_style2_cyberpunk_tower(surface, time_offset):
    """스타일 2: 사이버펑크 타워 - 고층빌딩 전광판"""
    board_width = 850
    board_height = 520
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 건물 외관 효과
    for layer in range(6, 0, -1):
        offset = layer * 8
        rect = (board_x - offset, board_y - offset//2, board_width + offset*2, board_height + offset)
        color = (5 + layer*3, layer*2, 15 + layer*5)
        pygame.draw.rect(surface, color, rect)

    # 메인 보드
    pygame.draw.rect(surface, (2, 2, 8), (board_x, board_y, board_width, board_height))

    # 네온 테두리 애니메이션
    colors = [NEON_CYAN, NEON_MAGENTA, NEON_LIME]
    for i, color in enumerate(colors):
        offset = i * 4
        phase = time_offset + i * 0.5
        intensity = 0.6 + 0.4 * math.sin(phase)
        draw_color = (int(color[0] * intensity), int(color[1] * intensity), int(color[2] * intensity))
        pygame.draw.rect(surface, draw_color,
                        (board_x - offset, board_y - offset, board_width + offset*2, board_height + offset*2), 3)

    # 수직 네온 라인들 (건물 창문 효과)
    for x_pos in range(board_x + 30, board_x + board_width, 60):
        pulse = 0.5 + 0.5 * math.sin(time_offset * 2 + x_pos * 0.02)
        line_color = (0, int(200 * pulse), int(255 * pulse))
        pygame.draw.line(surface, line_color, (x_pos, board_y + 10), (x_pos, board_y + board_height - 10), 2)

    # 상단 네온 사인
    header_y = board_y + 30
    title_glow = pygame.Surface((board_width - 60, 80), pygame.SRCALPHA)
    for glow in range(30, 0, -3):
        alpha = int(50 / (glow / 5))
        pygame.draw.rect(title_glow, (*NEON_CYAN[:3], alpha),
                        (glow, glow, board_width - 60 - glow*2, 80 - glow*2), border_radius=10)
    surface.blit(title_glow, (board_x + 30, header_y))

    # 타이틀 (글리치 효과)
    glitch_offset = random.randint(-2, 2) if random.random() > 0.95 else 0
    draw_holographic_text(surface, "◆ CYBER ARENA ◆",
                         board_x + 230 + glitch_offset, header_y + 15, font_title, NEON_CYAN, time_offset)

    # 점수 디스플레이 영역 (3D 패널)
    score_y = board_y + 130

    # 플레이어 패널
    p_panel = (board_x + 40, score_y, 340, 300)
    # 깊이 레이어
    for d in range(4):
        layer_rect = (p_panel[0] + d*3, p_panel[1] + d*2, p_panel[2], p_panel[3])
        pygame.draw.rect(surface, (5 + d*5, 20 + d*10, 40 + d*15), layer_rect)
    pygame.draw.rect(surface, (10, 40, 70), p_panel)
    draw_neon_glow_rect(surface, p_panel, (0, 200, 255), 8)

    p_label = font_medium.render("P1", True, NEON_CYAN)
    surface.blit(p_label, (board_x + 160, score_y + 15))

    draw_led_digit_3d(surface, board_x + 100, score_y + 80, 2, NEON_CYAN, 180, 10, time_offset)

    # 보스 패널
    b_panel = (board_x + board_width - 380, score_y, 340, 300)
    for d in range(4):
        layer_rect = (b_panel[0] + d*3, b_panel[1] + d*2, b_panel[2], b_panel[3])
        pygame.draw.rect(surface, (40 + d*15, 5 + d*5, 30 + d*10), layer_rect)
    pygame.draw.rect(surface, (70, 10, 50), b_panel)
    draw_neon_glow_rect(surface, b_panel, NEON_MAGENTA, 8)

    b_label = font_medium.render("CPU", True, NEON_MAGENTA)
    surface.blit(b_label, (board_x + board_width - 280, score_y + 15))

    draw_led_digit_3d(surface, board_x + board_width - 310, score_y + 80, 1, NEON_MAGENTA, 180, 10, time_offset)

    # 중앙 VS 홀로그램
    vs_x = WIDTH // 2
    vs_y = board_y + board_height // 2 + 30

    # 홀로그램 원형 효과
    for radius in range(100, 20, -8):
        pulse = 0.5 + 0.5 * math.sin(time_offset * 3 + radius * 0.05)
        alpha = int(100 * pulse / (radius / 20))
        holo_surf = pygame.Surface((radius*2, radius*2), pygame.SRCALPHA)
        pygame.draw.circle(holo_surf, (*GOLD[:3], alpha), (radius, radius), radius, 2)
        surface.blit(holo_surf, (vs_x - radius, vs_y - radius))

    vs_text = font_large.render("VS", True, GOLD)
    vs_rect = vs_text.get_rect(center=(vs_x, vs_y))
    surface.blit(vs_text, vs_rect)

    # 하단 티커
    ticker_y = board_y + board_height - 50
    pygame.draw.rect(surface, (5, 5, 15), (board_x + 20, ticker_y, board_width - 40, 35))
    pygame.draw.rect(surface, NEON_LIME, (board_x + 20, ticker_y, board_width - 40, 35), 2)

    ticker_text = font_small.render("⚡ MAXIMUM POWER MODE ACTIVATED ⚡", True, NEON_LIME)
    surface.blit(ticker_text, (board_x + 200, ticker_y + 3))


def draw_style3_holographic_arena(surface, time_offset):
    """스타일 3: 홀로그래픽 아레나 - 미래형 입체 디스플레이"""
    board_width = 880
    board_height = 500
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 홀로그램 기반 효과
    for layer in range(8, 0, -1):
        offset = layer * 6
        alpha = 30 - layer * 3
        layer_surf = pygame.Surface((board_width + offset*2, board_height + offset*2), pygame.SRCALPHA)
        color = (0, 150 + layer*10, 200 + layer*5, alpha)
        pygame.draw.rect(layer_surf, color, (0, 0, board_width + offset*2, board_height + offset*2),
                        border_radius=20 - layer*2)
        surface.blit(layer_surf, (board_x - offset, board_y - offset))

    # 메인 디스플레이
    pygame.draw.rect(surface, (0, 5, 15), (board_x, board_y, board_width, board_height), border_radius=15)

    # 그리드 배경
    grid_color = (0, 40, 60)
    for gx in range(board_x, board_x + board_width, 25):
        pygame.draw.line(surface, grid_color, (gx, board_y), (gx, board_y + board_height), 1)
    for gy in range(board_y, board_y + board_height, 25):
        pygame.draw.line(surface, grid_color, (board_x, gy), (board_x + board_width, gy), 1)

    # 상단 아치 효과
    arc_center = (board_x + board_width // 2, board_y + 50)
    for radius in range(350, 280, -10):
        arc_color = (0, int(150 + (350 - radius) * 2), int(200 + (350 - radius)))
        pygame.draw.arc(surface, arc_color,
                       (arc_center[0] - radius, arc_center[1] - radius//2, radius*2, radius),
                       math.pi * 0.15, math.pi * 0.85, 3)

    # 타이틀
    title_y = board_y + 40
    draw_holographic_text(surface, "✦ HOLOGRAPHIC ARENA ✦",
                         board_x + 200, title_y, font_title, (0, 255, 230), time_offset)

    # 플레이어 홀로그램 패널
    p_center = (board_x + 200, board_y + 290)

    # 원형 플랫폼
    for r in range(120, 40, -10):
        pulse = 0.7 + 0.3 * math.sin(time_offset * 2 + r * 0.1)
        platform_color = (0, int(180 * pulse), int(255 * pulse))
        pygame.draw.ellipse(surface, platform_color,
                           (p_center[0] - r, p_center[1] + 100 - r//3, r*2, r//2), 2)

    # 플레이어 점수 (부유 효과)
    float_offset = int(5 * math.sin(time_offset * 2))
    draw_led_digit_3d(surface, p_center[0] - 60, p_center[1] - 80 + float_offset,
                     2, NEON_CYAN, 140, 8, time_offset)

    p_label = font_medium.render("PLAYER", True, NEON_CYAN)
    p_rect = p_label.get_rect(center=(p_center[0], p_center[1] + 80))
    surface.blit(p_label, p_rect)

    # 보스 홀로그램 패널
    b_center = (board_x + board_width - 200, board_y + 290)

    for r in range(120, 40, -10):
        pulse = 0.7 + 0.3 * math.sin(time_offset * 2 + r * 0.1 + math.pi)
        platform_color = (int(255 * pulse), 0, int(180 * pulse))
        pygame.draw.ellipse(surface, platform_color,
                           (b_center[0] - r, b_center[1] + 100 - r//3, r*2, r//2), 2)

    draw_led_digit_3d(surface, b_center[0] - 60, b_center[1] - 80 + float_offset,
                     1, NEON_MAGENTA, 140, 8, time_offset)

    b_label = font_medium.render("BOSS", True, NEON_MAGENTA)
    b_rect = b_label.get_rect(center=(b_center[0], b_center[1] + 80))
    surface.blit(b_label, b_rect)

    # 중앙 에너지 코어
    core_x = board_x + board_width // 2
    core_y = board_y + board_height // 2 + 20

    # 회전하는 육각형
    for layer in range(5):
        angle = time_offset * (1 + layer * 0.2)
        size = 60 - layer * 8
        points = []
        for i in range(6):
            px = core_x + size * math.cos(angle + i * math.pi / 3)
            py = core_y + size * math.sin(angle + i * math.pi / 3)
            points.append((px, py))
        color = (255 - layer*40, 200 - layer*30, 100 + layer*20)
        pygame.draw.polygon(surface, color, points, 3)

    vs_text = font_large.render("VS", True, GOLD)
    vs_rect = vs_text.get_rect(center=(core_x, core_y))
    surface.blit(vs_text, vs_rect)

    # 하단 에너지 바
    bar_y = board_y + board_height - 50
    pygame.draw.rect(surface, (0, 20, 40), (board_x + 30, bar_y, board_width - 60, 35), border_radius=5)

    # 애니메이션 에너지
    energy_width = int((board_width - 70) * (0.5 + 0.5 * math.sin(time_offset)))
    pygame.draw.rect(surface, (0, 200, 255), (board_x + 35, bar_y + 5, energy_width, 25), border_radius=3)


def draw_style4_neon_dynasty(surface, time_offset):
    """스타일 4: 네온 다이너스티 - 동양풍 사이버펑크"""
    board_width = 900
    board_height = 500
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 배경 그라디언트
    for y_pos in range(board_height):
        ratio = y_pos / board_height
        r = int(20 * (1 - ratio))
        g = int(5 + 15 * ratio)
        b = int(30 + 20 * ratio)
        pygame.draw.line(surface, (r, g, b),
                        (board_x, board_y + y_pos), (board_x + board_width, board_y + y_pos), 1)

    # 장식적 코너 (동양풍)
    corner_size = 60
    corner_color = GOLD

    # 좌상단
    pygame.draw.line(surface, corner_color, (board_x, board_y + corner_size), (board_x, board_y), 4)
    pygame.draw.line(surface, corner_color, (board_x, board_y), (board_x + corner_size, board_y), 4)
    pygame.draw.line(surface, corner_color, (board_x + 10, board_y + 10), (board_x + corner_size - 10, board_y + 10), 2)
    pygame.draw.line(surface, corner_color, (board_x + 10, board_y + 10), (board_x + 10, board_y + corner_size - 10), 2)

    # 우상단
    pygame.draw.line(surface, corner_color, (board_x + board_width, board_y + corner_size), (board_x + board_width, board_y), 4)
    pygame.draw.line(surface, corner_color, (board_x + board_width, board_y), (board_x + board_width - corner_size, board_y), 4)

    # 좌하단
    pygame.draw.line(surface, corner_color, (board_x, board_y + board_height - corner_size), (board_x, board_y + board_height), 4)
    pygame.draw.line(surface, corner_color, (board_x, board_y + board_height), (board_x + corner_size, board_y + board_height), 4)

    # 우하단
    pygame.draw.line(surface, corner_color, (board_x + board_width, board_y + board_height - corner_size), (board_x + board_width, board_y + board_height), 4)
    pygame.draw.line(surface, corner_color, (board_x + board_width, board_y + board_height), (board_x + board_width - corner_size, board_y + board_height), 4)

    # 상단 타이틀 배너
    banner_rect = (board_x + 100, board_y + 20, board_width - 200, 70)
    draw_3d_box(surface, banner_rect, depth=12,
                base_color=(30, 10, 10), highlight_color=(100, 50, 50), shadow_color=(15, 5, 5))
    pygame.draw.rect(surface, GOLD, banner_rect, 3)

    draw_holographic_text(surface, "龍 NEON DYNASTY 龍",
                         board_x + 250, board_y + 35, font_title, GOLD, time_offset)

    # 플레이어 영역 (스크롤 스타일)
    p_x = board_x + 50
    p_y = board_y + 120
    p_w = 350
    p_h = 320

    # 스크롤 배경
    pygame.draw.rect(surface, (10, 5, 20), (p_x, p_y, p_w, p_h))

    # 장식 테두리
    for offset in range(3):
        color = (0, 200 - offset*50, 255 - offset*40)
        pygame.draw.rect(surface, color, (p_x - offset*3, p_y - offset*3, p_w + offset*6, p_h + offset*6), 2)

    # 플레이어 한자
    p_kanji = font_large.render("勇", True, NEON_CYAN)
    surface.blit(p_kanji, (p_x + 20, p_y + 20))

    p_label = font_medium.render("PLAYER", True, NEON_CYAN)
    surface.blit(p_label, (p_x + 120, p_y + 30))

    draw_led_digit_3d(surface, p_x + 80, p_y + 120, 2, NEON_CYAN, 160, 8, time_offset)

    # 보스 영역
    b_x = board_x + board_width - 400
    b_y = board_y + 120

    pygame.draw.rect(surface, (20, 5, 10), (b_x, b_y, p_w, p_h))

    for offset in range(3):
        color = (255 - offset*40, 0, 150 - offset*40)
        pygame.draw.rect(surface, color, (b_x - offset*3, b_y - offset*3, p_w + offset*6, p_h + offset*6), 2)

    b_kanji = font_large.render("魔", True, NEON_MAGENTA)
    surface.blit(b_kanji, (b_x + 20, b_y + 20))

    b_label = font_medium.render("BOSS", True, NEON_MAGENTA)
    surface.blit(b_label, (b_x + 120, b_y + 30))

    draw_led_digit_3d(surface, b_x + 80, b_y + 120, 1, NEON_MAGENTA, 160, 8, time_offset)

    # 중앙 태극 무늬 VS
    vs_x = board_x + board_width // 2
    vs_y = board_y + board_height // 2 + 20

    # 회전하는 원
    for layer in range(4):
        angle = time_offset + layer * math.pi / 4
        radius = 70 - layer * 12
        pygame.draw.arc(surface, (255, 200 - layer*40, 100),
                       (vs_x - radius, vs_y - radius, radius*2, radius*2),
                       angle, angle + math.pi, 4)
        pygame.draw.arc(surface, (100, 200 - layer*40, 255),
                       (vs_x - radius, vs_y - radius, radius*2, radius*2),
                       angle + math.pi, angle + math.pi*2, 4)

    vs_text = font_large.render("戰", True, GOLD)
    vs_rect = vs_text.get_rect(center=(vs_x, vs_y))
    surface.blit(vs_text, vs_rect)

    # 하단 메시지
    msg_rect = (board_x + 80, board_y + board_height - 55, board_width - 160, 40)
    pygame.draw.rect(surface, (15, 5, 10), msg_rect)
    pygame.draw.rect(surface, GOLD, msg_rect, 2)

    msg_text = font_small.render("⚔ THE BATTLE OF LEGENDS ⚔", True, GOLD)
    msg_text_rect = msg_text.get_rect(center=(board_x + board_width // 2, board_y + board_height - 35))
    surface.blit(msg_text, msg_text_rect)


def draw_style5_quantum_display(surface, time_offset):
    """스타일 5: 퀀텀 디스플레이 - 양자 컴퓨터 스타일"""
    board_width = 900
    board_height = 500
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 배경 (깊은 우주)
    for y_pos in range(board_height):
        ratio = y_pos / board_height
        color = (int(5 + 10 * math.sin(ratio * math.pi)),
                int(5 + 15 * ratio),
                int(20 + 30 * ratio))
        pygame.draw.line(surface, color,
                        (board_x, board_y + y_pos), (board_x + board_width, board_y + y_pos), 1)

    # 양자 격자
    grid_spacing = 30
    for gx in range(board_x, board_x + board_width + grid_spacing, grid_spacing):
        for gy in range(board_y, board_y + board_height + grid_spacing, grid_spacing):
            pulse = 0.3 + 0.7 * math.sin(time_offset * 2 + gx * 0.01 + gy * 0.01)
            size = int(2 + 2 * pulse)
            color = (int(50 * pulse), int(150 * pulse), int(255 * pulse))
            pygame.draw.circle(surface, color, (gx, gy), size)

    # 연결선 (양자 얽힘 효과)
    for i in range(20):
        x1 = board_x + random.randint(0, board_width)
        y1 = board_y + random.randint(0, board_height)
        x2 = x1 + random.randint(-100, 100)
        y2 = y1 + random.randint(-100, 100)
        x2 = max(board_x, min(board_x + board_width, x2))
        y2 = max(board_y, min(board_y + board_height, y2))
        alpha = random.randint(20, 60)
        line_surf = pygame.Surface((board_width, board_height), pygame.SRCALPHA)
        pygame.draw.line(line_surf, (0, 200, 255, alpha),
                        (x1 - board_x, y1 - board_y), (x2 - board_x, y2 - board_y), 1)
        surface.blit(line_surf, (board_x, board_y))

    # 외곽 프레임 (에너지 필드)
    for layer in range(5):
        phase = time_offset * 2 + layer * 0.5
        intensity = 0.5 + 0.5 * math.sin(phase)
        color = (0, int(200 * intensity), int(255 * intensity))
        offset = layer * 5
        pygame.draw.rect(surface, color,
                        (board_x - offset, board_y - offset, board_width + offset*2, board_height + offset*2), 2)

    # 상단 디스플레이
    header_y = board_y + 25
    draw_holographic_text(surface, "◈ QUANTUM SCOREBOARD ◈",
                         board_x + 210, header_y, font_title, (0, 255, 255), time_offset)

    # 양자 비트 상태 표시줄
    qbit_y = board_y + 75
    for i in range(20):
        x = board_x + 60 + i * 40
        state = math.sin(time_offset * 3 + i * 0.5) > 0
        color = (0, 255, 200) if state else (100, 50, 100)
        pygame.draw.circle(surface, color, (x, qbit_y), 8)
        # 상태 텍스트
        state_text = font_tiny.render("|1⟩" if state else "|0⟩", True, color)
        surface.blit(state_text, (x - 12, qbit_y + 12))

    # 플레이어 양자 상태
    p_box = (board_x + 50, board_y + 130, 340, 310)

    # 파동 함수 시각화
    for wave in range(5):
        wave_y = p_box[1] + 50 + wave * 50
        points = []
        for x in range(p_box[0], p_box[0] + p_box[2], 5):
            y = wave_y + int(20 * math.sin(time_offset * 3 + x * 0.05 + wave))
            points.append((x, y))
        if len(points) > 1:
            pygame.draw.lines(surface, (0, 200 - wave*30, 255 - wave*20), False, points, 2)

    draw_neon_glow_rect(surface, p_box, NEON_CYAN, 8)

    p_label = font_medium.render("PLAYER |ψ⟩", True, NEON_CYAN)
    surface.blit(p_label, (p_box[0] + 60, p_box[1] + 15))

    draw_led_digit_3d(surface, p_box[0] + 80, p_box[1] + 120, 2, NEON_CYAN, 150, 8, time_offset)

    # 보스 양자 상태
    b_box = (board_x + board_width - 390, board_y + 130, 340, 310)

    for wave in range(5):
        wave_y = b_box[1] + 50 + wave * 50
        points = []
        for x in range(b_box[0], b_box[0] + b_box[2], 5):
            y = wave_y + int(20 * math.sin(time_offset * 3 + x * 0.05 + wave + math.pi))
            points.append((x, y))
        if len(points) > 1:
            pygame.draw.lines(surface, (255 - wave*20, 0, 200 - wave*30), False, points, 2)

    draw_neon_glow_rect(surface, b_box, NEON_MAGENTA, 8)

    b_label = font_medium.render("BOSS |φ⟩", True, NEON_MAGENTA)
    surface.blit(b_label, (b_box[0] + 80, b_box[1] + 15))

    draw_led_digit_3d(surface, b_box[0] + 80, b_box[1] + 120, 1, NEON_MAGENTA, 150, 8, time_offset)

    # 중앙 얽힘 상태
    entangle_x = board_x + board_width // 2
    entangle_y = board_y + board_height // 2 + 30

    # 슈뢰딩거 고양이 상자 (비유적)
    box_size = 80
    pygame.draw.rect(surface, (30, 30, 50),
                    (entangle_x - box_size//2, entangle_y - box_size//2, box_size, box_size), 2)

    # 얽힘 연결선
    pygame.draw.line(surface, NEON_CYAN, (p_box[0] + p_box[2], p_box[1] + p_box[3]//2),
                    (entangle_x - box_size//2, entangle_y), 2)
    pygame.draw.line(surface, NEON_MAGENTA, (b_box[0], b_box[1] + b_box[3]//2),
                    (entangle_x + box_size//2, entangle_y), 2)

    # VS 상태
    superposition = "VS" if math.sin(time_offset * 4) > 0 else "SV"
    vs_text = font_large.render(superposition, True, GOLD)
    vs_rect = vs_text.get_rect(center=(entangle_x, entangle_y))
    surface.blit(vs_text, vs_rect)

    # 하단 확률 표시
    prob_y = board_y + board_height - 50
    pygame.draw.rect(surface, (5, 10, 20), (board_x + 50, prob_y, board_width - 100, 35))

    p_prob = 0.5 + 0.3 * math.sin(time_offset)
    b_prob = 1 - p_prob

    prob_text = font_small.render(f"P(PLAYER WIN) = {p_prob:.2f}  |  P(BOSS WIN) = {b_prob:.2f}", True, (0, 255, 200))
    prob_rect = prob_text.get_rect(center=(board_x + board_width // 2, prob_y + 17))
    surface.blit(prob_text, prob_rect)


# 메인 루프
def main():
    styles = [
        ("메이저리그 스타디움 3D", draw_style1_stadium_3d),
        ("사이버펑크 타워", draw_style2_cyberpunk_tower),
        ("홀로그래픽 아레나", draw_style3_holographic_arena),
        ("네온 다이너스티", draw_style4_neon_dynasty),
        ("퀀텀 디스플레이", draw_style5_quantum_display),
    ]

    current_style = 0
    running = True
    time_offset = 0

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_LEFT:
                    current_style = (current_style - 1) % len(styles)
                elif event.key == pygame.K_RIGHT:
                    current_style = (current_style + 1) % len(styles)
                elif event.key == pygame.K_1:
                    current_style = 0
                elif event.key == pygame.K_2:
                    current_style = 1
                elif event.key == pygame.K_3:
                    current_style = 2
                elif event.key == pygame.K_4:
                    current_style = 3
                elif event.key == pygame.K_5:
                    current_style = 4

        # 배경
        screen.fill((5, 5, 15))

        # 현재 스타일 그리기
        styles[current_style][1](screen, time_offset)

        # UI 오버레이
        # 스타일 이름
        style_name = font_medium.render(f"◀ {current_style + 1}/5: {styles[current_style][0]} ▶", True, WHITE)
        style_rect = style_name.get_rect(center=(WIDTH // 2, 30))
        pygame.draw.rect(screen, (20, 20, 40), style_rect.inflate(30, 10), border_radius=8)
        screen.blit(style_name, style_rect)

        # 조작 안내
        help_text = font_tiny.render("← → 또는 1-5: 스타일 변경  |  ESC: 종료", True, (150, 150, 180))
        help_rect = help_text.get_rect(center=(WIDTH // 2, HEIGHT - 25))
        screen.blit(help_text, help_rect)

        pygame.display.flip()
        clock.tick(60)
        time_offset += 0.03

    pygame.quit()


if __name__ == "__main__":
    main()
