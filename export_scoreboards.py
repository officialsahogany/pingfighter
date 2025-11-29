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


# 각 스타일을 개별 이미지로 저장
styles = [
    ("style1_premium_classic", draw_style1, "프리미엄 클래식 - Fenway 스타일"),
    ("style2_7segment_pro", draw_style2, "7세그먼트 프로 - 디지털 스타일"),
    ("style3_jumbotron_ultra", draw_style3, "점보트론 울트라 - 대형 스크린"),
    ("style4_kbo_premium", draw_style4, "KBO 프리미엄 - 한글 스타일"),
    ("style5_neon_arcade", draw_style5, "네온 아케이드 - 사이버펑크"),
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
