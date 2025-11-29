#!/usr/bin/env python3
"""
5가지 전광판 스타일을 개별 이미지로 내보내기
"""
import pygame
import math
import random
import os

# 화면 설정
WIDTH = 1200
HEIGHT = 600

# 색상
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
YELLOW = (255, 220, 0)
ORANGE = (255, 150, 50)
RED = (255, 50, 50)
GREEN = (50, 255, 100)
CYAN = (0, 255, 255)
BLUE = (50, 100, 255)

pygame.init()

# 폰트
try:
    font_path = os.path.join(os.path.dirname(__file__), "fonts", "NeoDunggeunmoPro-Regular.ttf")
    if os.path.exists(font_path):
        font_huge = pygame.font.Font(font_path, 120)
        font_large = pygame.font.Font(font_path, 80)
        font_medium = pygame.font.Font(font_path, 40)
        font_small = pygame.font.Font(font_path, 28)
        font_title = pygame.font.Font(font_path, 36)
        font_tiny = pygame.font.Font(font_path, 20)
    else:
        font_huge = pygame.font.Font(None, 120)
        font_large = pygame.font.Font(None, 80)
        font_medium = pygame.font.Font(None, 40)
        font_small = pygame.font.Font(None, 28)
        font_title = pygame.font.Font(None, 36)
        font_tiny = pygame.font.Font(None, 20)
except:
    font_huge = pygame.font.Font(None, 120)
    font_large = pygame.font.Font(None, 80)
    font_medium = pygame.font.Font(None, 40)
    font_small = pygame.font.Font(None, 28)
    font_title = pygame.font.Font(None, 36)
    font_tiny = pygame.font.Font(None, 20)


def draw_premium_led(surface, x, y, color, size=5, intensity=1.0, is_on=True):
    """프리미엄 LED 도트 - 실제 LED처럼 발광 효과"""
    if is_on:
        for i in range(6, 0, -1):
            glow_radius = size + i * 2
            glow_alpha = int(40 * intensity / i)
            glow_surf = pygame.Surface((glow_radius * 2 + 10, glow_radius * 2 + 10), pygame.SRCALPHA)
            glow_color = (color[0], color[1], color[2], glow_alpha)
            pygame.draw.circle(glow_surf, glow_color, (glow_radius + 5, glow_radius + 5), glow_radius)
            surface.blit(glow_surf, (x - glow_radius - 5 + size//2, y - glow_radius - 5 + size//2))

        pygame.draw.circle(surface, color, (x, y), size)
        bright_color = (min(255, color[0] + 80), min(255, color[1] + 80), min(255, color[2] + 80))
        pygame.draw.circle(surface, bright_color, (x, y), size - 2)
        highlight = (min(255, color[0] + 150), min(255, color[1] + 150), min(255, color[2] + 150))
        pygame.draw.circle(surface, highlight, (x - size//3, y - size//3), size // 3)
    else:
        dim_color = (max(10, color[0] // 12), max(10, color[1] // 12), max(10, color[2] // 12))
        pygame.draw.circle(surface, dim_color, (x, y), size - 1)
        pygame.draw.circle(surface, (30, 30, 35), (x - size//4, y - size//4), size // 4)


def draw_7segment_digit(surface, x, y, digit, color, size=120, thickness=None):
    """7세그먼트 LED 숫자"""
    if thickness is None:
        thickness = size // 8

    seg_length = size // 2 - thickness
    gap = thickness // 2

    patterns = {
        '0': (1,1,1,1,1,1,0),
        '1': (0,1,1,0,0,0,0),
        '2': (1,1,0,1,1,0,1),
        '3': (1,1,1,1,0,0,1),
        '4': (0,1,1,0,0,1,1),
        '5': (1,0,1,1,0,1,1),
        '6': (1,0,1,1,1,1,1),
        '7': (1,1,1,0,0,0,0),
        '8': (1,1,1,1,1,1,1),
        '9': (1,1,1,1,0,1,1)
    }

    pattern = patterns.get(str(digit), patterns['0'])

    segments = [
        [(x + gap, y), (x + seg_length + gap, y),
         (x + seg_length, y + thickness//2), (x + thickness, y + thickness//2)],
        [(x + seg_length + gap, y + gap), (x + seg_length + gap + thickness//2, y + thickness),
         (x + seg_length + gap + thickness//2, y + seg_length), (x + seg_length + gap, y + seg_length + gap)],
        [(x + seg_length + gap, y + seg_length + gap * 2), (x + seg_length + gap + thickness//2, y + seg_length + thickness + gap),
         (x + seg_length + gap + thickness//2, y + size - thickness), (x + seg_length + gap, y + size - gap)],
        [(x + gap, y + size - gap), (x + seg_length + gap, y + size - gap),
         (x + seg_length, y + size - thickness//2 - gap), (x + thickness, y + size - thickness//2 - gap)],
        [(x, y + seg_length + gap * 2), (x + thickness//2, y + seg_length + thickness + gap),
         (x + thickness//2, y + size - thickness), (x, y + size - gap)],
        [(x, y + gap), (x + thickness//2, y + thickness),
         (x + thickness//2, y + seg_length), (x, y + seg_length + gap)],
        [(x + gap, y + seg_length + gap), (x + seg_length + gap, y + seg_length + gap),
         (x + seg_length, y + seg_length + gap + thickness//2), (x + thickness, y + seg_length + gap + thickness//2)]
    ]

    for i, seg in enumerate(segments):
        if pattern[i]:
            for glow in range(4, 0, -1):
                glow_surf = pygame.Surface((size + 40, size + 40), pygame.SRCALPHA)
                glow_color = (*color[:3], 30 // glow)
                offset_seg = [(p[0] - x + 20, p[1] - y + 20) for p in seg]
                pygame.draw.polygon(glow_surf, glow_color, offset_seg)
                surface.blit(glow_surf, (x - 20 - glow, y - 20 - glow))

            pygame.draw.polygon(surface, color, seg)
            bright = (min(255, color[0]+100), min(255, color[1]+100), min(255, color[2]+100))
            inner_seg = [(p[0] + (seg[2][0]-p[0])*0.2, p[1] + (seg[2][1]-p[1])*0.2) for p in seg[:2]]
            inner_seg += [(p[0] + (seg[0][0]-p[0])*0.2, p[1] + (seg[0][1]-p[1])*0.2) for p in seg[2:]]
            if len(inner_seg) >= 3:
                pygame.draw.polygon(surface, bright, inner_seg[:4])
        else:
            dim = (max(8, color[0]//15), max(8, color[1]//15), max(8, color[2]//15))
            pygame.draw.polygon(surface, dim, seg)


def draw_dot_matrix_digit(surface, x, y, digit, color, size=140, dot_radius=4):
    """고밀도 도트 매트릭스 숫자"""
    patterns = {
        '0': [
            "  11111  ",
            " 1111111 ",
            "111   111",
            "111   111",
            "111   111",
            "111   111",
            "111   111",
            "111   111",
            "111   111",
            "111   111",
            "111   111",
            " 1111111 ",
            "  11111  "
        ],
        '1': [
            "    111  ",
            "   1111  ",
            "  11111  ",
            " 111111  ",
            "    111  ",
            "    111  ",
            "    111  ",
            "    111  ",
            "    111  ",
            "    111  ",
            "    111  ",
            " 1111111 ",
            "111111111"
        ],
        '2': [
            " 1111111 ",
            "111111111",
            "111   111",
            "      111",
            "     111 ",
            "    111  ",
            "   111   ",
            "  111    ",
            " 111     ",
            "111      ",
            "111   111",
            "111111111",
            "111111111"
        ],
        '3': [
            " 1111111 ",
            "111111111",
            "111   111",
            "      111",
            "      111",
            "  111111 ",
            "  111111 ",
            "      111",
            "      111",
            "111   111",
            "111   111",
            "111111111",
            " 1111111 "
        ],
        '4': [
            "     111 ",
            "    1111 ",
            "   11111 ",
            "  111111 ",
            " 111 111 ",
            "111  111 ",
            "111  111 ",
            "111111111",
            "111111111",
            "     111 ",
            "     111 ",
            "     111 ",
            "     111 "
        ],
        '5': [
            "111111111",
            "111111111",
            "111      ",
            "111      ",
            "11111111 ",
            "111111111",
            "      111",
            "      111",
            "      111",
            "111   111",
            "111   111",
            "111111111",
            " 1111111 "
        ],
        '6': [
            " 1111111 ",
            "111111111",
            "111   111",
            "111      ",
            "111      ",
            "11111111 ",
            "111111111",
            "111   111",
            "111   111",
            "111   111",
            "111   111",
            "111111111",
            " 1111111 "
        ],
        '7': [
            "111111111",
            "111111111",
            "111   111",
            "      111",
            "     111 ",
            "    111  ",
            "   111   ",
            "   111   ",
            "   111   ",
            "   111   ",
            "   111   ",
            "   111   ",
            "   111   "
        ],
        '8': [
            " 1111111 ",
            "111111111",
            "111   111",
            "111   111",
            "111   111",
            " 1111111 ",
            " 1111111 ",
            "111   111",
            "111   111",
            "111   111",
            "111   111",
            "111111111",
            " 1111111 "
        ],
        '9': [
            " 1111111 ",
            "111111111",
            "111   111",
            "111   111",
            "111   111",
            "111111111",
            " 11111111",
            "      111",
            "      111",
            "111   111",
            "111   111",
            "111111111",
            " 1111111 "
        ]
    }

    pattern = patterns.get(str(digit), patterns['0'])
    spacing = size // 13

    for row_idx, row in enumerate(pattern):
        for col_idx, char in enumerate(row):
            dot_x = x + col_idx * spacing + spacing // 2
            dot_y = y + row_idx * spacing + spacing // 2
            draw_premium_led(surface, dot_x, dot_y, color, dot_radius, 1.0, char == '1')


def draw_premium_frame(surface, rect, frame_color=(75, 80, 90), thickness=18):
    """프리미엄 금속 프레임"""
    x, y, w, h = rect

    shadow = pygame.Surface((w + 20, h + 20), pygame.SRCALPHA)
    pygame.draw.rect(shadow, (0, 0, 0, 80), (10, 10, w, h), border_radius=8)
    surface.blit(shadow, (x - 5, y - 5))

    pygame.draw.rect(surface, (20, 20, 25), (x, y, w, h))
    pygame.draw.rect(surface, frame_color, (x, y, w, h), thickness)

    highlight = tuple(min(255, c + 50) for c in frame_color)
    pygame.draw.line(surface, highlight, (x, y), (x + w - 1, y), 2)
    pygame.draw.line(surface, highlight, (x, y), (x, y + h - 1), 2)

    shadow_color = tuple(max(0, c - 40) for c in frame_color)
    pygame.draw.line(surface, shadow_color, (x + 1, y + h - 1), (x + w, y + h - 1), 3)
    pygame.draw.line(surface, shadow_color, (x + w - 1, y + 1), (x + w - 1, y + h), 3)


def draw_style1(surface):
    """스타일 1: 프리미엄 클래식 (펜웨이)"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    pygame.draw.rect(surface, (8, 35, 18), (board_x, board_y, board_width, board_height))
    draw_premium_frame(surface, (board_x, board_y, board_width, board_height), (55, 60, 50), 20)

    inner_x = board_x + 28
    inner_y = board_y + 28
    inner_w = board_width - 56
    inner_h = board_height - 56

    pygame.draw.rect(surface, (5, 15, 8), (inner_x, inner_y, inner_w, inner_h))
    pygame.draw.rect(surface, (30, 50, 35), (inner_x, inner_y, inner_w, inner_h), 3)

    title_color = (255, 200, 0)
    title = font_title.render("PING FIGHTER", True, title_color)
    title_rect = title.get_rect(center=(WIDTH // 2, inner_y + 50))
    surface.blit(title, title_rect)

    led_color = (255, 200, 0)
    draw_dot_matrix_digit(surface, inner_x + 80, inner_y + 120, 2, led_color, 130, 5)
    draw_dot_matrix_digit(surface, inner_x + inner_w - 200, inner_y + 120, 1, led_color, 130, 5)

    vs_x = WIDTH // 2
    vs_y = inner_y + 210
    pygame.draw.circle(surface, (40, 30, 10), (vs_x, vs_y), 40)
    vs = font_medium.render("VS", True, (255, 200, 100))
    vs_rect = vs.get_rect(center=(vs_x, vs_y))
    surface.blit(vs, vs_rect)


def draw_style2(surface):
    """스타일 2: 7세그먼트 프로"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    pygame.draw.rect(surface, (10, 15, 35), (board_x, board_y, board_width, board_height))
    draw_premium_frame(surface, (board_x, board_y, board_width, board_height), (100, 105, 115), 18)

    inner_x = board_x + 25
    inner_y = board_y + 25
    inner_w = board_width - 50
    inner_h = board_height - 50

    pygame.draw.rect(surface, (5, 8, 20), (inner_x, inner_y, inner_w, inner_h))

    top_bar = pygame.Rect(inner_x + 10, inner_y + 10, inner_w - 20, 50)
    pygame.draw.rect(surface, (15, 25, 50), top_bar, border_radius=5)
    pygame.draw.rect(surface, (100, 150, 220), top_bar, 2, border_radius=5)

    title = font_title.render("★ ROUND SCORE ★", True, (180, 220, 255))
    title_rect = title.get_rect(center=(WIDTH // 2, inner_y + 35))
    surface.blit(title, title_rect)

    score_area_y = inner_y + 75
    score_area_h = 200

    p_section = pygame.Rect(inner_x + 30, score_area_y, 280, score_area_h)
    pygame.draw.rect(surface, (8, 15, 40), p_section)
    pygame.draw.rect(surface, (80, 150, 220), p_section, 3)

    p_label = font_small.render("PLAYER", True, (150, 200, 255))
    p_label_rect = p_label.get_rect(center=(p_section.centerx, score_area_y + 25))
    surface.blit(p_label, p_label_rect)

    seg_color = (0, 200, 255)
    draw_7segment_digit(surface, inner_x + 95, score_area_y + 50, 2, seg_color, 130)

    b_section = pygame.Rect(inner_x + inner_w - 310, score_area_y, 280, score_area_h)
    pygame.draw.rect(surface, (40, 12, 12), b_section)
    pygame.draw.rect(surface, (220, 80, 80), b_section, 3)

    b_label = font_small.render("BOSS", True, (255, 150, 150))
    b_label_rect = b_label.get_rect(center=(b_section.centerx, score_area_y + 25))
    surface.blit(b_label, b_label_rect)

    red_color = (255, 60, 60)
    draw_7segment_digit(surface, inner_x + inner_w - 245, score_area_y + 50, 1, red_color, 130)


def draw_style3(surface):
    """스타일 3: 점보트론 울트라"""
    board_width = 780
    board_height = 420
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    pygame.draw.rect(surface, (3, 3, 8), (board_x, board_y, board_width, board_height))

    header = pygame.Rect(board_x + 20, board_y + 15, board_width - 40, 55)
    pygame.draw.rect(surface, (15, 20, 40), header, border_radius=8)
    pygame.draw.rect(surface, (100, 150, 255), header, 2, border_radius=8)

    pygame.draw.circle(surface, (255, 200, 50), (board_x + 55, board_y + 42), 22)
    pygame.draw.circle(surface, (220, 170, 40), (board_x + 55, board_y + 42), 18)
    logo = font_tiny.render("PF", True, (60, 50, 20))
    surface.blit(logo, (board_x + 45, board_y + 35))

    title = font_title.render("ROUND SCORE", True, (200, 220, 255))
    title_rect = title.get_rect(center=(WIDTH // 2, board_y + 42))
    surface.blit(title, title_rect)

    p_card = pygame.Rect(board_x + 30, board_y + 85, board_width - 60, 120)
    for i in range(120):
        pygame.draw.line(surface, (20 + i//6, 50 + i//4, 100 + i//3),
                        (p_card.x, p_card.y + i), (p_card.x + p_card.width, p_card.y + i))
    pygame.draw.rect(surface, (80, 160, 255), p_card, 3, border_radius=10)

    pygame.draw.circle(surface, (40, 100, 200), (board_x + 90, board_y + 145), 35)
    pygame.draw.circle(surface, (80, 150, 255), (board_x + 90, board_y + 145), 30)
    p_icon = font_large.render("P", True, WHITE)
    p_icon_rect = p_icon.get_rect(center=(board_x + 90, board_y + 145))
    surface.blit(p_icon, p_icon_rect)

    p_name = font_large.render("PLAYER", True, (150, 220, 255))
    surface.blit(p_name, (board_x + 140, board_y + 115))

    p_score = font_huge.render("2", True, (100, 220, 255))
    p_score_rect = p_score.get_rect(center=(board_x + board_width - 100, board_y + 145))
    surface.blit(p_score, p_score_rect)

    b_card = pygame.Rect(board_x + 30, board_y + 215, board_width - 60, 120)
    for i in range(120):
        pygame.draw.line(surface, (100 + i//4, 30 + i//8, 30 + i//8),
                        (b_card.x, b_card.y + i), (b_card.x + b_card.width, b_card.y + i))
    pygame.draw.rect(surface, (255, 100, 100), b_card, 3, border_radius=10)

    pygame.draw.circle(surface, (180, 50, 50), (board_x + 90, board_y + 275), 35)
    pygame.draw.circle(surface, (255, 100, 100), (board_x + 90, board_y + 275), 30)
    b_icon = font_large.render("B", True, WHITE)
    b_icon_rect = b_icon.get_rect(center=(board_x + 90, board_y + 275))
    surface.blit(b_icon, b_icon_rect)

    b_name = font_large.render("BOSS", True, (255, 150, 150))
    surface.blit(b_name, (board_x + 140, board_y + 245))

    b_score = font_huge.render("1", True, (255, 120, 120))
    b_score_rect = b_score.get_rect(center=(board_x + board_width - 100, board_y + 275))
    surface.blit(b_score, b_score_rect)


def draw_style4(surface):
    """스타일 4: KBO 프리미엄"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    pygame.draw.rect(surface, (8, 12, 30), (board_x, board_y, board_width, board_height))
    draw_premium_frame(surface, (board_x, board_y, board_width, board_height), (90, 80, 60), 20)

    inner_x = board_x + 28
    inner_y = board_y + 28
    inner_w = board_width - 56
    inner_h = board_height - 56

    pygame.draw.rect(surface, (5, 8, 22), (inner_x, inner_y, inner_w, inner_h))

    header = pygame.Rect(inner_x + 15, inner_y + 12, inner_w - 30, 70)
    pygame.draw.rect(surface, (12, 18, 40), header)
    pygame.draw.rect(surface, (200, 170, 80), header, 2)

    pygame.draw.circle(surface, (30, 80, 180), (inner_x + 70, inner_y + 47), 30)
    pygame.draw.circle(surface, (80, 140, 255), (inner_x + 70, inner_y + 47), 26)
    p_icon = font_medium.render("P", True, WHITE)
    p_icon_rect = p_icon.get_rect(center=(inner_x + 70, inner_y + 47))
    surface.blit(p_icon, p_icon_rect)

    p_name = font_large.render("플레이어", True, (100, 180, 255))
    surface.blit(p_name, (inner_x + 110, inner_y + 25))

    pygame.draw.circle(surface, (180, 50, 50), (inner_x + inner_w - 70, inner_y + 47), 30)
    pygame.draw.circle(surface, (255, 100, 100), (inner_x + inner_w - 70, inner_y + 47), 26)
    b_icon = font_medium.render("B", True, WHITE)
    b_icon_rect = b_icon.get_rect(center=(inner_x + inner_w - 70, inner_y + 47))
    surface.blit(b_icon, b_icon_rect)

    b_name = font_large.render("보스", True, (255, 120, 120))
    b_name_rect = b_name.get_rect(right=inner_x + inner_w - 110, top=inner_y + 25)
    surface.blit(b_name, b_name_rect)

    score_area = pygame.Rect(inner_x + 20, inner_y + 95, inner_w - 40, 180)
    pygame.draw.rect(surface, (8, 12, 28), score_area)
    pygame.draw.rect(surface, (180, 150, 70), score_area, 3)

    pygame.draw.line(surface, (180, 150, 70), (WIDTH // 2, inner_y + 100), (WIDTH // 2, inner_y + 270), 3)

    blue_led = (80, 180, 255)
    red_led = (255, 100, 100)

    draw_dot_matrix_digit(surface, inner_x + 90, inner_y + 115, 2, blue_led, 140, 5)
    draw_dot_matrix_digit(surface, inner_x + inner_w - 210, inner_y + 115, 1, red_led, 140, 5)

    vs_bg = pygame.Rect(WIDTH // 2 - 35, inner_y + 180, 70, 50)
    pygame.draw.rect(surface, (50, 40, 20), vs_bg)
    pygame.draw.rect(surface, (200, 170, 80), vs_bg, 2)
    vs = font_medium.render("VS", True, (255, 220, 120))
    vs_rect = vs.get_rect(center=(WIDTH // 2, inner_y + 205))
    surface.blit(vs, vs_rect)


def draw_style5(surface):
    """스타일 5: 네온 아케이드"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    pygame.draw.rect(surface, (5, 5, 12), (board_x, board_y, board_width, board_height))

    neon_colors = [(255, 0, 100), (0, 255, 200), (255, 100, 0)]
    for i, color in enumerate(neon_colors):
        offset = i * 3
        pygame.draw.rect(surface, color, (board_x - offset, board_y - offset, board_width + offset*2, board_height + offset*2), 2)

    for y in range(0, board_height, 3):
        pygame.draw.line(surface, (10, 10, 20), (board_x, board_y + y), (board_x + board_width, board_y + y), 1)

    title_bar = pygame.Rect(board_x + 25, board_y + 20, board_width - 50, 60)
    pygame.draw.rect(surface, (10, 10, 25), title_bar, border_radius=5)

    title_text = "▶ SCORE BOARD ◀"
    title = font_title.render(title_text, True, (0, 255, 200))
    title_rect = title.get_rect(center=(WIDTH // 2, board_y + 50))
    surface.blit(title, title_rect)

    score_y = board_y + 100

    p_box = pygame.Rect(board_x + 40, score_y, 280, 200)
    pygame.draw.rect(surface, (8, 20, 25), p_box)
    for g in range(4):
        pygame.draw.rect(surface, (0, 255 - g*50, 200 - g*40), p_box.inflate(g*2, g*2), 2)

    p_label = font_medium.render("1P", True, (0, 255, 200))
    surface.blit(p_label, (board_x + 150, score_y + 10))

    cyan = (0, 255, 220)
    draw_7segment_digit(surface, board_x + 105, score_y + 50, 2, cyan, 130)

    b_box = pygame.Rect(board_x + board_width - 320, score_y, 280, 200)
    pygame.draw.rect(surface, (25, 10, 15), b_box)
    for g in range(4):
        pygame.draw.rect(surface, (255 - g*40, 0, 100 - g*20), b_box.inflate(g*2, g*2), 2)

    b_label = font_medium.render("CPU", True, (255, 50, 150))
    surface.blit(b_label, (board_x + board_width - 210, score_y + 10))

    magenta = (255, 50, 150)
    draw_7segment_digit(surface, board_x + board_width - 255, score_y + 50, 1, magenta, 130)

    vs_x = WIDTH // 2
    vs_y = score_y + 100

    diamond_size = 45
    for i in range(3):
        points = []
        for j in range(4):
            angle = math.radians(j * 90)
            px = vs_x + (diamond_size - i * 10) * math.cos(angle)
            py = vs_y + (diamond_size - i * 10) * math.sin(angle)
            points.append((px, py))
        color = (255 - i * 80, 100 + i * 50, 200 - i * 50)
        pygame.draw.polygon(surface, color, points, 2)

    vs = font_medium.render("VS", True, (255, 255, 255))
    vs_rect = vs.get_rect(center=(vs_x, vs_y))
    surface.blit(vs, vs_rect)

    footer = font_medium.render("INSERT COIN", True, (255, 220, 0))
    footer_rect = footer.get_rect(center=(WIDTH // 2, board_y + board_height - 40))
    surface.blit(footer, footer_rect)


def draw_style6_cyberpunk_edge(surface):
    """스타일 6: 사이버펑크 엣지 - 예각 테두리"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    pygame.draw.rect(surface, (8, 3, 15), (board_x, board_y, board_width, board_height))

    # 네온 라임 테두리 - 예각 스타일
    corner_size = 40
    thickness = 4
    neon_lime = (0, 255, 100)

    # 코너 예각 라인
    points = [
        [(board_x + corner_size, board_y), (board_x + board_width - corner_size, board_y)],
        [(board_x + board_width, board_y + corner_size), (board_x + board_width, board_y + board_height - corner_size)],
        [(board_x + board_width - corner_size, board_y + board_height), (board_x + corner_size, board_y + board_height)],
        [(board_x, board_y + board_height - corner_size), (board_x, board_y + corner_size)]
    ]

    for line in points:
        pygame.draw.line(surface, neon_lime, line[0], line[1], thickness)

    # 코너 대각선
    pygame.draw.line(surface, neon_lime, (board_x, board_y), (board_x + corner_size, board_y), thickness)
    pygame.draw.line(surface, neon_lime, (board_x, board_y), (board_x, board_y + corner_size), thickness)
    pygame.draw.line(surface, neon_lime, (board_x + board_width, board_y), (board_x + board_width - corner_size, board_y), thickness)
    pygame.draw.line(surface, neon_lime, (board_x + board_width, board_y), (board_x + board_width, board_y + corner_size), thickness)
    pygame.draw.line(surface, neon_lime, (board_x, board_y + board_height), (board_x + corner_size, board_y + board_height), thickness)
    pygame.draw.line(surface, neon_lime, (board_x, board_y + board_height), (board_x, board_y + board_height - corner_size), thickness)
    pygame.draw.line(surface, neon_lime, (board_x + board_width, board_y + board_height), (board_x + board_width - corner_size, board_y + board_height), thickness)
    pygame.draw.line(surface, neon_lime, (board_x + board_width, board_y + board_height), (board_x + board_width, board_y + board_height - corner_size), thickness)

    # 내부 컨텐츠
    title = font_title.render("⚡ ROUND SCORE ⚡", True, neon_lime)
    title_rect = title.get_rect(center=(WIDTH // 2, board_y + 50))
    surface.blit(title, title_rect)

    score_y = board_y + 120

    # 플레이어 섹션
    p_box = pygame.Rect(board_x + 50, score_y, 270, 180)
    pygame.draw.rect(surface, (5, 25, 15), p_box)
    pygame.draw.rect(surface, neon_lime, p_box, 2)

    p_label = font_medium.render("PLAYER", True, neon_lime)
    surface.blit(p_label, (board_x + 70, score_y + 15))

    draw_dot_matrix_digit(surface, board_x + 90, score_y + 60, 2, neon_lime, 100, 4)

    # 보스 섹션
    b_box = pygame.Rect(board_x + board_width - 320, score_y, 270, 180)
    pygame.draw.rect(surface, (25, 5, 15), b_box)
    pygame.draw.rect(surface, (255, 50, 150), b_box, 2)

    b_label = font_medium.render("BOSS", True, (255, 50, 150))
    surface.blit(b_label, (board_x + board_width - 300, score_y + 15))

    draw_dot_matrix_digit(surface, board_x + board_width - 265, score_y + 60, 1, (255, 50, 150), 100, 4)


def draw_style7_cyberpunk_diamond(surface):
    """스타일 7: 사이버펑크 다이아몬드 - 기하학적 무늬"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    pygame.draw.rect(surface, (3, 8, 12), (board_x, board_y, board_width, board_height))

    # 다이아몬드 패턴 테두리
    neon_cyan = (0, 255, 255)
    neon_magenta = (255, 0, 200)

    diamond_size = 30
    for x in range(board_x, board_x + board_width + diamond_size, diamond_size):
        # 상단
        points = [(x, board_y), (x + diamond_size//2, board_y - 15), (x + diamond_size, board_y), (x + diamond_size//2, board_y + 15)]
        pygame.draw.polygon(surface, neon_cyan, points, 2)
        # 하단
        points = [(x, board_y + board_height), (x + diamond_size//2, board_y + board_height - 15), (x + diamond_size, board_y + board_height), (x + diamond_size//2, board_y + board_height + 15)]
        pygame.draw.polygon(surface, neon_magenta, points, 2)

    for y in range(board_y, board_y + board_height + diamond_size, diamond_size):
        # 좌측
        points = [(board_x, y), (board_x - 15, y + diamond_size//2), (board_x, y + diamond_size), (board_x + 15, y + diamond_size//2)]
        pygame.draw.polygon(surface, neon_cyan, points, 2)
        # 우측
        points = [(board_x + board_width, y), (board_x + board_width - 15, y + diamond_size//2), (board_x + board_width, y + diamond_size), (board_x + board_width + 15, y + diamond_size//2)]
        pygame.draw.polygon(surface, neon_magenta, points, 2)

    # 내부 테두리
    pygame.draw.rect(surface, neon_cyan, (board_x + 10, board_y + 10, board_width - 20, board_height - 20), 3)

    title = font_title.render("◆ SCORE BOARD ◆", True, neon_cyan)
    title_rect = title.get_rect(center=(WIDTH // 2, board_y + 50))
    surface.blit(title, title_rect)

    score_y = board_y + 120

    p_box = pygame.Rect(board_x + 50, score_y, 270, 180)
    pygame.draw.rect(surface, (5, 15, 25), p_box)
    pygame.draw.rect(surface, neon_cyan, p_box, 2)

    p_label = font_medium.render("PLAYER", True, neon_cyan)
    surface.blit(p_label, (board_x + 70, score_y + 15))

    draw_7segment_digit(surface, board_x + 90, score_y + 60, 2, neon_cyan, 100)

    b_box = pygame.Rect(board_x + board_width - 320, score_y, 270, 180)
    pygame.draw.rect(surface, (25, 5, 20), b_box)
    pygame.draw.rect(surface, neon_magenta, b_box, 2)

    b_label = font_medium.render("BOSS", True, neon_magenta)
    surface.blit(b_label, (board_x + board_width - 300, score_y + 15))

    draw_7segment_digit(surface, board_x + board_width - 265, score_y + 60, 1, neon_magenta, 100)


def draw_style8_cyberpunk_wave(surface):
    """스타일 8: 사이버펑크 웨이브 - 파동 테두리"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    pygame.draw.rect(surface, (5, 3, 10), (board_x, board_y, board_width, board_height))

    # 파동 테두리
    neon_lime = (50, 255, 80)
    neon_pink = (255, 0, 127)

    wave_amplitude = 8
    wave_frequency = 0.05

    # 상단 파동
    points = []
    for x in range(board_x, board_x + board_width + 1):
        y = board_y - wave_amplitude + int(wave_amplitude * math.sin((x - board_x) * wave_frequency))
        points.append((x, y))
    for i in range(len(points) - 1):
        color = neon_lime if i % 2 == 0 else neon_pink
        pygame.draw.line(surface, color, points[i], points[i+1], 3)

    # 하단 파동
    points = []
    for x in range(board_x, board_x + board_width + 1):
        y = board_y + board_height + wave_amplitude - int(wave_amplitude * math.sin((x - board_x) * wave_frequency))
        points.append((x, y))
    for i in range(len(points) - 1):
        color = neon_lime if i % 2 == 0 else neon_pink
        pygame.draw.line(surface, color, points[i], points[i+1], 3)

    # 좌측 파동
    points = []
    for y in range(board_y, board_y + board_height + 1):
        x = board_x - wave_amplitude + int(wave_amplitude * math.sin((y - board_y) * wave_frequency))
        points.append((x, y))
    for i in range(len(points) - 1):
        color = neon_lime if i % 2 == 0 else neon_pink
        pygame.draw.line(surface, color, points[i], points[i+1], 3)

    # 우측 파동
    points = []
    for y in range(board_y, board_y + board_height + 1):
        x = board_x + board_width + wave_amplitude - int(wave_amplitude * math.sin((y - board_y) * wave_frequency))
        points.append((x, y))
    for i in range(len(points) - 1):
        color = neon_lime if i % 2 == 0 else neon_pink
        pygame.draw.line(surface, color, points[i], points[i+1], 3)

    title = font_title.render("≈ SCORE BOARD ≈", True, neon_lime)
    title_rect = title.get_rect(center=(WIDTH // 2, board_y + 50))
    surface.blit(title, title_rect)

    score_y = board_y + 120

    p_box = pygame.Rect(board_x + 50, score_y, 270, 180)
    pygame.draw.rect(surface, (8, 15, 10), p_box)
    pygame.draw.rect(surface, neon_lime, p_box, 2)

    p_label = font_medium.render("PLAYER", True, neon_lime)
    surface.blit(p_label, (board_x + 70, score_y + 15))

    draw_dot_matrix_digit(surface, board_x + 90, score_y + 60, 2, neon_lime, 100, 4)

    b_box = pygame.Rect(board_x + board_width - 320, score_y, 270, 180)
    pygame.draw.rect(surface, (15, 5, 10), b_box)
    pygame.draw.rect(surface, neon_pink, b_box, 2)

    b_label = font_medium.render("BOSS", True, neon_pink)
    surface.blit(b_label, (board_x + board_width - 300, score_y + 15))

    draw_dot_matrix_digit(surface, board_x + board_width - 265, score_y + 60, 1, neon_pink, 100, 4)


def draw_style9_cyberpunk_holo(surface):
    """스타일 9: 사이버펑크 홀로그래픽 - 레이어 효과"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    pygame.draw.rect(surface, (2, 5, 15), (board_x, board_y, board_width, board_height))

    # 홀로그래픽 레이어 테두리
    neon_cyan = (0, 200, 255)
    neon_lime = (0, 255, 150)
    neon_magenta = (200, 0, 255)

    layer_offset = [0, 3, 6, 9]
    layer_colors = [neon_magenta, neon_cyan, neon_lime, neon_cyan]

    for offset, color in zip(layer_offset, layer_colors):
        pygame.draw.rect(surface, color, (board_x - offset, board_y - offset, board_width + offset*2, board_height + offset*2), 2)

    # 스캔라인 효과
    for y in range(board_y, board_y + board_height, 2):
        pygame.draw.line(surface, (0, 255, 150, 30), (board_x, y), (board_x + board_width, y), 1)

    title = font_title.render("╔ SCORE BOARD ╗", True, neon_lime)
    title_rect = title.get_rect(center=(WIDTH // 2, board_y + 50))
    surface.blit(title, title_rect)

    score_y = board_y + 120

    p_box = pygame.Rect(board_x + 50, score_y, 270, 180)
    pygame.draw.rect(surface, (5, 20, 30), p_box)
    for offset in [0, 2, 4]:
        pygame.draw.rect(surface, (0, 200 - offset*30, 255 - offset*20), p_box.inflate(-offset*2, -offset*2), 2)

    p_label = font_medium.render("PLAYER", True, neon_cyan)
    surface.blit(p_label, (board_x + 70, score_y + 15))

    draw_7segment_digit(surface, board_x + 90, score_y + 60, 2, neon_cyan, 100)

    b_box = pygame.Rect(board_x + board_width - 320, score_y, 270, 180)
    pygame.draw.rect(surface, (30, 5, 25), b_box)
    for offset in [0, 2, 4]:
        pygame.draw.rect(surface, (200 - offset*30, 0, 255 - offset*20), b_box.inflate(-offset*2, -offset*2), 2)

    b_label = font_medium.render("BOSS", True, neon_magenta)
    surface.blit(b_label, (board_x + board_width - 300, score_y + 15))

    draw_7segment_digit(surface, board_x + board_width - 265, score_y + 60, 1, neon_magenta, 100)


def draw_style10_cyberpunk_grid(surface):
    """스타일 10: 사이버펑크 그리드 - 격자 무늬"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    pygame.draw.rect(surface, (3, 5, 12), (board_x, board_y, board_width, board_height))

    # 격자 배경
    grid_size = 15
    neon_lime = (0, 255, 120)
    neon_purple = (150, 0, 255)

    for x in range(board_x, board_x + board_width + grid_size, grid_size):
        pygame.draw.line(surface, (20, 80, 40), (x, board_y), (x, board_y + board_height), 1)

    for y in range(board_y, board_y + board_height + grid_size, grid_size):
        pygame.draw.line(surface, (20, 80, 40), (board_x, y), (board_x + board_width, y), 1)

    # 강조 테두리
    pygame.draw.rect(surface, neon_lime, (board_x, board_y, board_width, board_height), 4)

    # 코너 강조
    corner_size = 25
    pygame.draw.rect(surface, neon_purple, (board_x, board_y, corner_size, corner_size), 2)
    pygame.draw.rect(surface, neon_purple, (board_x + board_width - corner_size, board_y, corner_size, corner_size), 2)
    pygame.draw.rect(surface, neon_purple, (board_x, board_y + board_height - corner_size, corner_size, corner_size), 2)
    pygame.draw.rect(surface, neon_purple, (board_x + board_width - corner_size, board_y + board_height - corner_size, corner_size, corner_size), 2)

    title = font_title.render("┌─ SCORE BOARD ─┐", True, neon_lime)
    title_rect = title.get_rect(center=(WIDTH // 2, board_y + 50))
    surface.blit(title, title_rect)

    score_y = board_y + 120

    p_box = pygame.Rect(board_x + 50, score_y, 270, 180)
    pygame.draw.rect(surface, (5, 15, 25), p_box)
    pygame.draw.rect(surface, neon_lime, p_box, 3)

    p_label = font_medium.render("PLAYER", True, neon_lime)
    surface.blit(p_label, (board_x + 70, score_y + 15))

    draw_dot_matrix_digit(surface, board_x + 90, score_y + 60, 2, neon_lime, 100, 4)

    b_box = pygame.Rect(board_x + board_width - 320, score_y, 270, 180)
    pygame.draw.rect(surface, (25, 5, 20), b_box)
    pygame.draw.rect(surface, neon_purple, b_box, 3)

    b_label = font_medium.render("BOSS", True, neon_purple)
    surface.blit(b_label, (board_x + board_width - 300, score_y + 15))

    draw_dot_matrix_digit(surface, board_x + board_width - 265, score_y + 60, 1, neon_purple, 100, 4)


def draw_style11_aaa_premium(surface):
    """AAA급 프리미엄 - 풀HD 실제 야구장 전광판"""
    board_width = 900
    board_height = 450
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 배경: 깊이감 있는 검은색
    pygame.draw.rect(surface, (5, 5, 10), (board_x, board_y, board_width, board_height))

    # 외부 조명 효과
    for glow in range(60, 0, -5):
        glow_alpha = int(30 * (1 - glow/60))
        glow_surf = pygame.Surface((board_width + glow*2, board_height + glow*2), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (50, 200, 255, glow_alpha), glow_surf.get_rect(), 3)
        surface.blit(glow_surf, (board_x - glow, board_y - glow))

    # 메인 테두리: 광택 효과
    pygame.draw.rect(surface, (30, 150, 255), (board_x, board_y, board_width, board_height), 4)
    pygame.draw.rect(surface, (100, 200, 255), (board_x + 2, board_y + 2, board_width - 4, board_height - 4), 2)

    # 상단 헤더 섹션
    header_height = 80
    for i in range(header_height):
        ratio = i / header_height
        g_val = int(100 + 100 * ratio)
        b_val = int(200 + 55 * ratio)
        pygame.draw.line(surface, (0, g_val, b_val), (board_x, board_y + i), (board_x + board_width, board_y + i), 1)

    # 로고/제목 영역
    title_font = pygame.font.Font(None, 48)
    title = title_font.render("⚾ PING FIGHTER ⚾", True, (255, 255, 100))
    surface.blit(title, (board_x + board_width // 2 - title.get_width() // 2, board_y + 15))

    # 경기 정보 바
    info_bar_y = board_y + 65
    pygame.draw.line(surface, (100, 200, 255), (board_x + 20, info_bar_y), (board_x + board_width - 20, info_bar_y), 3)

    # 플레이어 섹션 (좌측)
    p_section_x = board_x + 40
    p_section_y = board_y + 120
    p_section_w = 350
    p_section_h = 280

    # 플레이어 배경 박스
    pygame.draw.rect(surface, (10, 40, 80), (p_section_x, p_section_y, p_section_w, p_section_h))
    for i in range(p_section_h):
        alpha = int(100 * (i / p_section_h))
        color = (20 + i // 2, 60 + i // 2, 120 + i // 3)
        pygame.draw.line(surface, color, (p_section_x, p_section_y + i), (p_section_x + p_section_w, p_section_y + i), 1)

    pygame.draw.rect(surface, (100, 200, 255), (p_section_x, p_section_y, p_section_w, p_section_h), 3)

    # 플레이어 라벨
    label_font = pygame.font.Font(None, 36)
    p_label = label_font.render("● PLAYER", True, (100, 220, 255))
    surface.blit(p_label, (p_section_x + 20, p_section_y + 15))

    draw_dot_matrix_digit(surface, p_section_x + 60, p_section_y + 80, 2, (0, 255, 150), 180, 6)

    # 보스 섹션 (우측)
    b_section_x = board_x + board_width - p_section_w - 40
    b_section_y = board_y + 120

    pygame.draw.rect(surface, (80, 10, 40), (b_section_x, b_section_y, p_section_w, p_section_h))
    for i in range(p_section_h):
        alpha = int(100 * (i / p_section_h))
        color = (120 + i // 3, 20 + i // 2, 60 + i // 2)
        pygame.draw.line(surface, color, (b_section_x, b_section_y + i), (b_section_x + p_section_w, b_section_y + i), 1)

    pygame.draw.rect(surface, (255, 100, 150), (b_section_x, b_section_y, p_section_w, p_section_h), 3)

    b_label = label_font.render("● BOSS", True, (255, 150, 200))
    surface.blit(b_label, (b_section_x + 20, b_section_y + 15))

    draw_dot_matrix_digit(surface, b_section_x + 60, b_section_y + 80, 1, (255, 80, 150), 180, 6)

    # 중앙 VS 섹션
    vs_center_x = board_x + board_width // 2
    vs_center_y = board_y + board_height // 2

    # VS 배경
    vs_box_size = 120
    pygame.draw.rect(surface, (20, 20, 40),
                     (vs_center_x - vs_box_size // 2, vs_center_y - vs_box_size // 2, vs_box_size, vs_box_size))
    pygame.draw.rect(surface, (150, 200, 255),
                     (vs_center_x - vs_box_size // 2, vs_center_y - vs_box_size // 2, vs_box_size, vs_box_size), 3)

    vs_text = pygame.font.Font(None, 60).render("VS", True, (255, 255, 100))
    surface.blit(vs_text, (vs_center_x - vs_text.get_width() // 2, vs_center_y - vs_text.get_height() // 2))

    # 하단 상태바
    status_bar_y = board_y + board_height - 50
    pygame.draw.rect(surface, (20, 60, 100), (board_x + 10, status_bar_y, board_width - 20, 40))
    pygame.draw.rect(surface, (100, 200, 255), (board_x + 10, status_bar_y, board_width - 20, 40), 2)

    status_text = pygame.font.Font(None, 24).render("🔥 INTENSE MATCH IN PROGRESS 🔥", True, (255, 200, 100))
    surface.blit(status_text, (board_x + board_width // 2 - status_text.get_width() // 2, status_bar_y + 8))


def draw_style12_aaa_neon_dynasty(surface):
    """AAA급 네온 왕조 - 사이버펑크 스타디움"""
    board_width = 900
    board_height = 450
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 배경: 다이나믹한 그래디언트
    for i in range(board_height):
        ratio = i / board_height
        r = int(10 + 20 * ratio)
        g = int(5 + 10 * ratio)
        b = int(20 + 30 * ratio)
        pygame.draw.line(surface, (r, g, b), (board_x, board_y + i), (board_x + board_width, board_y + i), 1)

    # 다중 네온 테두리
    neon_colors = [(255, 0, 150), (0, 255, 200), (200, 100, 255)]
    for idx, color in enumerate(neon_colors):
        offset = idx * 4
        pygame.draw.rect(surface, color, (board_x - offset, board_y - offset, board_width + offset*2, board_height + offset*2), 3)

    # 스캔라인 효과
    for y in range(board_y, board_y + board_height, 3):
        pygame.draw.line(surface, (50, 200, 255), (board_x, y), (board_x + board_width, y), 1)

    # 상단 타이틀
    title = pygame.font.Font(None, 56).render("▶ NEON DYNASTY ◀", True, (0, 255, 200))
    title_shadow = pygame.font.Font(None, 56).render("▶ NEON DYNASTY ◀", True, (0, 100, 150))
    surface.blit(title_shadow, (board_x + board_width // 2 - title.get_width() // 2 + 2, board_y + 20))
    surface.blit(title, (board_x + board_width // 2 - title.get_width() // 2, board_y + 18))

    # 플레이어 섹션
    p_x = board_x + 50
    p_y = board_y + 100
    p_w = 350
    p_h = 300

    pygame.draw.rect(surface, (5, 30, 40), (p_x, p_y, p_w, p_h))
    for glow in range(20, 0, -2):
        glow_color = (0, 255 - glow*10, 200 - glow*8)
        pygame.draw.rect(surface, glow_color, (p_x - glow, p_y - glow, p_w + glow*2, p_h + glow*2), 1)

    p_label = pygame.font.Font(None, 40).render("PLAYER 1", True, (0, 255, 200))
    surface.blit(p_label, (p_x + 30, p_y + 20))

    draw_dot_matrix_digit(surface, p_x + 60, p_y + 90, 2, (0, 255, 200), 180, 6)

    # 보스 섹션
    b_x = board_x + board_width - p_w - 50
    b_y = board_y + 100

    pygame.draw.rect(surface, (40, 5, 30), (b_x, b_y, p_w, p_h))
    for glow in range(20, 0, -2):
        glow_color = (max(0, 255 - glow*10), max(0, 50 - glow*2), max(0, 150 - glow*8))
        pygame.draw.rect(surface, glow_color, (b_x - glow, b_y - glow, p_w + glow*2, p_h + glow*2), 1)

    b_label = pygame.font.Font(None, 40).render("BOSS MODE", True, (255, 100, 200))
    surface.blit(b_label, (b_x + 30, b_y + 20))

    draw_dot_matrix_digit(surface, b_x + 60, b_y + 90, 1, (255, 100, 200), 180, 6)

    # 중앙 VS
    vs_x = board_x + board_width // 2
    vs_y = board_y + board_height // 2

    for size in [100, 80, 60]:
        color = (255 if size < 80 else 200, 200 - size // 2, 255 - size // 2)
        points = [
            (vs_x, vs_y - size // 2),
            (vs_x + size // 2, vs_y),
            (vs_x, vs_y + size // 2),
            (vs_x - size // 2, vs_y)
        ]
        pygame.draw.polygon(surface, color, points, 2)

    vs_text = pygame.font.Font(None, 72).render("VS", True, (255, 255, 100))
    surface.blit(vs_text, (vs_x - vs_text.get_width() // 2, vs_y - vs_text.get_height() // 2))

    # 하단 상태바
    pygame.draw.rect(surface, (10, 10, 25), (board_x + 10, board_y + board_height - 50, board_width - 20, 40))
    pygame.draw.rect(surface, (0, 255, 200), (board_x + 10, board_y + board_height - 50, board_width - 20, 40), 2)

    status = pygame.font.Font(None, 28).render("⚡ CRITICAL MOMENT - FINAL ROUND ⚡", True, (0, 255, 200))
    surface.blit(status, (board_x + board_width // 2 - status.get_width() // 2, board_y + board_height - 42))


def draw_style13_aaa_epic_showdown(surface):
    """AAA급 에픽 쇼다운 - 영화급 연출"""
    board_width = 900
    board_height = 450
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 배경: 영화 포스터 스타일
    pygame.draw.rect(surface, (15, 15, 25), (board_x, board_y, board_width, board_height))

    # 배경 효과: 극적인 라이팅
    for i in range(board_height):
        ratio = (i - board_height // 2) / board_height
        intensity = int(255 * (1 - abs(ratio) * 2))
        color = (20 + intensity // 20, 10, 40 + intensity // 10)
        pygame.draw.line(surface, color, (board_x, board_y + i), (board_x + board_width, board_y + i), 1)

    # 외부 금속 프레임
    frame_colors = [(255, 200, 100), (200, 150, 50), (150, 100, 30)]
    for idx, color in enumerate(frame_colors):
        pygame.draw.rect(surface, color, (board_x - idx*2, board_y - idx*2, board_width + idx*4, board_height + idx*4), 2)

    # 타이틀: 영화 스타일
    title_font = pygame.font.Font(None, 64)
    title1 = title_font.render("EPIC", True, (255, 200, 100))
    title2 = title_font.render("SHOWDOWN", True, (255, 100, 100))
    surface.blit(title1, (board_x + board_width // 2 - title1.get_width() // 2, board_y + 15))
    surface.blit(title2, (board_x + board_width // 2 - title2.get_width() // 2, board_y + 45))

    # 플레이어 정보 카드
    p_card_x = board_x + 40
    p_card_y = board_y + 110
    p_card_w = 320
    p_card_h = 300

    pygame.draw.rect(surface, (30, 50, 80), (p_card_x, p_card_y, p_card_w, p_card_h))
    pygame.draw.rect(surface, (200, 200, 255), (p_card_x, p_card_y, p_card_w, p_card_h), 3)

    pygame.draw.line(surface, (100, 200, 255), (p_card_x, p_card_y + 50), (p_card_x + p_card_w, p_card_y + 50), 2)

    p_name = pygame.font.Font(None, 48).render("YOU", True, (100, 220, 255))
    surface.blit(p_name, (p_card_x + 20, p_card_y + 12))

    draw_dot_matrix_digit(surface, p_card_x + 40, p_card_y + 100, 2, (100, 220, 255), 160, 5)

    # 보스 정보 카드
    b_card_x = board_x + board_width - p_card_w - 40
    b_card_y = board_y + 110

    pygame.draw.rect(surface, (80, 30, 50), (b_card_x, b_card_y, p_card_w, p_card_h))
    pygame.draw.rect(surface, (255, 150, 150), (b_card_x, b_card_y, p_card_w, p_card_h), 3)

    pygame.draw.line(surface, (255, 100, 100), (b_card_x, b_card_y + 50), (b_card_x + p_card_w, b_card_y + 50), 2)

    b_name = pygame.font.Font(None, 48).render("BOSS", True, (255, 150, 150))
    surface.blit(b_name, (b_card_x + 20, b_card_y + 12))

    draw_dot_matrix_digit(surface, b_card_x + 40, b_card_y + 100, 1, (255, 150, 150), 160, 5)

    # 중앙: 극적인 VS
    vs_center_x = board_x + board_width // 2
    vs_center_y = board_y + board_height // 2 + 20

    for radius in range(80, 30, -5):
        alpha_color = (255 - radius, 200 - radius // 2, 100)
        pygame.draw.circle(surface, alpha_color, (vs_center_x, vs_center_y), radius, 2)

    vs_text = pygame.font.Font(None, 80).render("VS", True, (255, 255, 100))
    surface.blit(vs_text, (vs_center_x - vs_text.get_width() // 2, vs_center_y - vs_text.get_height() // 2))

    # 하단 상태: 극적인 메시지
    pygame.draw.rect(surface, (50, 20, 20), (board_x + 10, board_y + board_height - 45, board_width - 20, 35))
    pygame.draw.rect(surface, (255, 100, 100), (board_x + 10, board_y + board_height - 45, board_width - 20, 35), 2)

    status_msg = pygame.font.Font(None, 32).render("🔥 THE FINAL BATTLE - EVERYTHING IS AT STAKE 🔥", True, (255, 150, 100))
    surface.blit(status_msg, (board_x + board_width // 2 - status_msg.get_width() // 2, board_y + board_height - 38))


# 각 스타일을 개별 이미지로 저장
styles = [
    ("style1_premium_classic", draw_style1, "프리미엄 클래식 - Fenway 스타일"),
    ("style2_7segment_pro", draw_style2, "7세그먼트 프로 - 디지털 스타일"),
    ("style3_jumbotron_ultra", draw_style3, "점보트론 울트라 - 대형 스크린"),
    ("style4_kbo_premium", draw_style4, "KBO 프리미엄 - 한글 스타일"),
    ("style5_neon_arcade", draw_style5, "네온 아케이드 - 사이버펑크"),
    ("style6_cyberpunk_edge", draw_style6_cyberpunk_edge, "사이버펑크 엣지 - 예각 테두리"),
    ("style7_cyberpunk_diamond", draw_style7_cyberpunk_diamond, "사이버펑크 다이아몬드 - 기하학적 무늬"),
    ("style8_cyberpunk_wave", draw_style8_cyberpunk_wave, "사이버펑크 웨이브 - 파동 테두리"),
    ("style9_cyberpunk_holo", draw_style9_cyberpunk_holo, "사이버펑크 홀로그래픽 - 레이어 효과"),
    ("style10_cyberpunk_grid", draw_style10_cyberpunk_grid, "사이버펑크 그리드 - 격자 무늬"),
    ("style11_aaa_premium", draw_style11_aaa_premium, "AAA급 프리미엄 - 풀HD 야구장 전광판"),
    ("style12_aaa_neon_dynasty", draw_style12_aaa_neon_dynasty, "AAA급 네온 왕조 - 사이버펑크 스타디움"),
    ("style13_aaa_epic_showdown", draw_style13_aaa_epic_showdown, "AAA급 에픽 쇼다운 - 영화급 연출"),
]

for filename, draw_func, description in styles:
    surface = pygame.Surface((WIDTH, HEIGHT))
    surface.fill((10, 10, 20))

    # 배경 제목
    bg_title = font_medium.render(description, True, YELLOW)
    bg_title_rect = bg_title.get_rect(center=(WIDTH // 2, 20))
    surface.blit(bg_title, bg_title_rect)

    draw_func(surface)

    pygame.image.save(surface, f"/tmp/{filename}.png")
    print(f"✅ {filename}.png 저장완료")

print("\n🎉 모든 스코어보드 이미지가 /tmp에 저장되었습니다!")
pygame.quit()
