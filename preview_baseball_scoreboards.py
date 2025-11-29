#!/usr/bin/env python3
"""
프리미엄 야구 전광판 스타일 점수판 - 초고퀄리티 버전
실제 전광판처럼 세밀한 LED, 조명, 반사 효과
"""
import pygame
import math
import random
import sys
import os

# 화면 설정
WIDTH = 900
HEIGHT = 700

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
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("프리미엄 야구 전광판 - 초고퀄리티")
clock = pygame.time.Clock()

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
        # 외부 글로우 (여러 레이어)
        for i in range(6, 0, -1):
            glow_radius = size + i * 2
            glow_alpha = int(40 * intensity / i)
            glow_surf = pygame.Surface((glow_radius * 2 + 10, glow_radius * 2 + 10), pygame.SRCALPHA)
            glow_color = (color[0], color[1], color[2], glow_alpha)
            pygame.draw.circle(glow_surf, glow_color, (glow_radius + 5, glow_radius + 5), glow_radius)
            surface.blit(glow_surf, (x - glow_radius - 5 + size//2, y - glow_radius - 5 + size//2))

        # 메인 LED 바디
        pygame.draw.circle(surface, color, (x, y), size)

        # 밝은 중심부
        bright_color = (min(255, color[0] + 80), min(255, color[1] + 80), min(255, color[2] + 80))
        pygame.draw.circle(surface, bright_color, (x, y), size - 2)

        # 하이라이트 (반짝임)
        highlight = (min(255, color[0] + 150), min(255, color[1] + 150), min(255, color[2] + 150))
        pygame.draw.circle(surface, highlight, (x - size//3, y - size//3), size // 3)
    else:
        # 꺼진 LED (미묘한 반사)
        dim_color = (max(10, color[0] // 12), max(10, color[1] // 12), max(10, color[2] // 12))
        pygame.draw.circle(surface, dim_color, (x, y), size - 1)
        # 유리 반사
        pygame.draw.circle(surface, (30, 30, 35), (x - size//4, y - size//4), size // 4)


def draw_7segment_digit(surface, x, y, digit, color, size=120, thickness=None):
    """7세그먼트 LED 숫자 - 실제 전광판처럼"""
    if thickness is None:
        thickness = size // 8

    seg_length = size // 2 - thickness
    gap = thickness // 2

    # 7세그먼트 패턴 (a,b,c,d,e,f,g)
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

    # 세그먼트 위치 정의
    segments = [
        # a (상단 가로)
        [(x + gap, y), (x + seg_length + gap, y),
         (x + seg_length, y + thickness//2), (x + thickness, y + thickness//2)],
        # b (우상단 세로)
        [(x + seg_length + gap, y + gap), (x + seg_length + gap + thickness//2, y + thickness),
         (x + seg_length + gap + thickness//2, y + seg_length), (x + seg_length + gap, y + seg_length + gap)],
        # c (우하단 세로)
        [(x + seg_length + gap, y + seg_length + gap * 2), (x + seg_length + gap + thickness//2, y + seg_length + thickness + gap),
         (x + seg_length + gap + thickness//2, y + size - thickness), (x + seg_length + gap, y + size - gap)],
        # d (하단 가로)
        [(x + gap, y + size - gap), (x + seg_length + gap, y + size - gap),
         (x + seg_length, y + size - thickness//2 - gap), (x + thickness, y + size - thickness//2 - gap)],
        # e (좌하단 세로)
        [(x, y + seg_length + gap * 2), (x + thickness//2, y + seg_length + thickness + gap),
         (x + thickness//2, y + size - thickness), (x, y + size - gap)],
        # f (좌상단 세로)
        [(x, y + gap), (x + thickness//2, y + thickness),
         (x + thickness//2, y + seg_length), (x, y + seg_length + gap)],
        # g (중간 가로)
        [(x + gap, y + seg_length + gap), (x + seg_length + gap, y + seg_length + gap),
         (x + seg_length, y + seg_length + gap + thickness//2), (x + thickness, y + seg_length + gap + thickness//2)]
    ]

    for i, seg in enumerate(segments):
        if pattern[i]:
            # 켜진 세그먼트 - 글로우 효과
            for glow in range(4, 0, -1):
                glow_surf = pygame.Surface((size + 40, size + 40), pygame.SRCALPHA)
                glow_color = (*color[:3], 30 // glow)
                offset_seg = [(p[0] - x + 20, p[1] - y + 20) for p in seg]
                pygame.draw.polygon(glow_surf, glow_color, offset_seg)
                surface.blit(glow_surf, (x - 20 - glow, y - 20 - glow))

            # 메인 세그먼트
            pygame.draw.polygon(surface, color, seg)

            # 밝은 하이라이트
            bright = (min(255, color[0]+100), min(255, color[1]+100), min(255, color[2]+100))
            inner_seg = [(p[0] + (seg[2][0]-p[0])*0.2, p[1] + (seg[2][1]-p[1])*0.2) for p in seg[:2]]
            inner_seg += [(p[0] + (seg[0][0]-p[0])*0.2, p[1] + (seg[0][1]-p[1])*0.2) for p in seg[2:]]
            if len(inner_seg) >= 3:
                pygame.draw.polygon(surface, bright, inner_seg[:4])
        else:
            # 꺼진 세그먼트 (희미하게)
            dim = (max(8, color[0]//15), max(8, color[1]//15), max(8, color[2]//15))
            pygame.draw.polygon(surface, dim, seg)


def draw_dot_matrix_digit(surface, x, y, digit, color, size=140, dot_radius=4):
    """고밀도 도트 매트릭스 숫자 - 9x13 해상도"""
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


def draw_brushed_metal(surface, rect, base_color=(70, 75, 85), direction='horizontal'):
    """브러시드 메탈 효과"""
    x, y, w, h = rect
    for i in range(h if direction == 'horizontal' else w):
        variation = random.randint(-8, 8)
        line_color = tuple(max(0, min(255, c + variation)) for c in base_color)
        if direction == 'horizontal':
            pygame.draw.line(surface, line_color, (x, y + i), (x + w, y + i))
        else:
            pygame.draw.line(surface, line_color, (x + i, y), (x + i, y + h))


def draw_premium_frame(surface, rect, frame_color=(75, 80, 90), thickness=18):
    """프리미엄 금속 프레임 - 3D 효과"""
    x, y, w, h = rect

    # 외부 그림자
    shadow = pygame.Surface((w + 20, h + 20), pygame.SRCALPHA)
    pygame.draw.rect(shadow, (0, 0, 0, 80), (10, 10, w, h), border_radius=8)
    surface.blit(shadow, (x - 5, y - 5))

    # 프레임 배경 (브러시드 메탈)
    frame_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    draw_brushed_metal(frame_surf, (0, 0, w, thickness), frame_color)
    draw_brushed_metal(frame_surf, (0, h - thickness, w, thickness), frame_color)
    draw_brushed_metal(frame_surf, (0, 0, thickness, h), frame_color, 'vertical')
    draw_brushed_metal(frame_surf, (w - thickness, 0, thickness, h), frame_color, 'vertical')
    surface.blit(frame_surf, (x, y))

    # 하이라이트 (상단/좌측)
    highlight = tuple(min(255, c + 50) for c in frame_color)
    pygame.draw.line(surface, highlight, (x, y), (x + w - 1, y), 2)
    pygame.draw.line(surface, highlight, (x, y), (x, y + h - 1), 2)

    # 그림자 (하단/우측)
    shadow_color = tuple(max(0, c - 40) for c in frame_color)
    pygame.draw.line(surface, shadow_color, (x + 1, y + h - 1), (x + w, y + h - 1), 3)
    pygame.draw.line(surface, shadow_color, (x + w - 1, y + 1), (x + w - 1, y + h), 3)

    # 볼트 장식 (모서리)
    bolt_positions = [
        (x + thickness//2, y + thickness//2),
        (x + w - thickness//2, y + thickness//2),
        (x + thickness//2, y + h - thickness//2),
        (x + w - thickness//2, y + h - thickness//2)
    ]
    for bx, by in bolt_positions:
        # 볼트 구멍
        pygame.draw.circle(surface, (40, 45, 50), (bx, by), 8)
        pygame.draw.circle(surface, (60, 65, 70), (bx, by), 6)
        # + 모양
        pygame.draw.line(surface, (50, 55, 60), (bx - 4, by), (bx + 4, by), 2)
        pygame.draw.line(surface, (50, 55, 60), (bx, by - 4), (bx, by + 4), 2)
        # 하이라이트
        pygame.draw.circle(surface, (90, 95, 100), (bx - 2, by - 2), 2)


def draw_style1_premium_classic(surface, player_score, boss_score, animation_frame):
    """스타일 1: 프리미엄 클래식 (펜웨이 + 고급 마감)"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 진한 녹색 배경
    pygame.draw.rect(surface, (8, 35, 18), (board_x, board_y, board_width, board_height))

    # 프리미엄 프레임
    draw_premium_frame(surface, (board_x, board_y, board_width, board_height), (55, 60, 50), 20)

    # 내부 LED 패널 영역
    inner_x = board_x + 28
    inner_y = board_y + 28
    inner_w = board_width - 56
    inner_h = board_height - 56

    # LED 패널 배경 (깊은 검정)
    pygame.draw.rect(surface, (5, 15, 8), (inner_x, inner_y, inner_w, inner_h))
    pygame.draw.rect(surface, (30, 50, 35), (inner_x, inner_y, inner_w, inner_h), 3)

    # LED 그리드 패턴
    for gx in range(0, inner_w, 8):
        pygame.draw.line(surface, (8, 20, 12), (inner_x + gx, inner_y), (inner_x + gx, inner_y + inner_h), 1)
    for gy in range(0, inner_h, 8):
        pygame.draw.line(surface, (8, 20, 12), (inner_x, inner_y + gy), (inner_x + inner_w, inner_y + gy), 1)

    # 상단 타이틀 바
    title_bar = pygame.Rect(inner_x + 15, inner_y + 15, inner_w - 30, 55)
    pygame.draw.rect(surface, (3, 12, 5), title_bar)
    pygame.draw.rect(surface, (80, 120, 70), title_bar, 2)

    # PING FIGHTER 타이틀 (LED 스타일)
    title_color = (255, 200, 0)
    title = font_title.render("PING FIGHTER", True, title_color)
    title_rect = title.get_rect(center=(WIDTH // 2, inner_y + 42))
    # 글로우
    for i in range(3):
        glow = font_title.render("PING FIGHTER", True, (150, 120, 0))
        glow.set_alpha(100 - i * 30)
        surface.blit(glow, title_rect.move(i, i))
        surface.blit(glow, title_rect.move(-i, -i))
    surface.blit(title, title_rect)

    # 팀 정보 영역
    team_y = inner_y + 85

    # 플레이어
    p_box = pygame.Rect(inner_x + 30, team_y, 280, 45)
    pygame.draw.rect(surface, (0, 40, 20), p_box)
    pygame.draw.rect(surface, (100, 180, 120), p_box, 2)
    p_label = font_medium.render("PLAYER", True, (120, 255, 150))
    surface.blit(p_label, (inner_x + 110, team_y + 8))

    # 보스
    b_box = pygame.Rect(inner_x + inner_w - 310, team_y, 280, 45)
    pygame.draw.rect(surface, (50, 15, 15), b_box)
    pygame.draw.rect(surface, (180, 80, 80), b_box, 2)
    b_label = font_medium.render("BOSS", True, (255, 130, 130))
    surface.blit(b_label, (inner_x + inner_w - 200, team_y + 8))

    # 점수 표시 (도트 매트릭스)
    score_y = team_y + 60
    led_color = (255, 200, 0)
    pulse = 0.8 + 0.2 * math.sin(animation_frame * 0.1)

    if animation_frame % 150 < 140:
        draw_dot_matrix_digit(surface, inner_x + 80, score_y, player_score,
                             (int(led_color[0]*pulse), int(led_color[1]*pulse), int(led_color[2]*pulse)), 130, 5)
        draw_dot_matrix_digit(surface, inner_x + inner_w - 200, score_y, boss_score,
                             (int(led_color[0]*pulse), int(led_color[1]*pulse), int(led_color[2]*pulse)), 130, 5)

    # VS 장식
    vs_x = WIDTH // 2
    vs_y = score_y + 65
    pygame.draw.circle(surface, (40, 30, 10), (vs_x, vs_y), 40)
    pygame.draw.circle(surface, (60, 45, 20), (vs_x, vs_y), 35)
    pygame.draw.circle(surface, (180, 140, 60), (vs_x, vs_y), 35, 3)
    vs = font_medium.render("VS", True, (255, 200, 100))
    vs_rect = vs.get_rect(center=(vs_x, vs_y))
    surface.blit(vs, vs_rect)

    # 하단 정보
    footer_y = inner_y + inner_h - 50
    pygame.draw.rect(surface, (3, 12, 5), (inner_x + 15, footer_y, inner_w - 30, 35))
    info = font_small.render("◆ FIRST TO 3 WINS ◆", True, (200, 180, 100))
    info_rect = info.get_rect(center=(WIDTH // 2, footer_y + 17))
    surface.blit(info, info_rect)


def draw_style2_7segment_pro(surface, player_score, boss_score, animation_frame):
    """스타일 2: 7세그먼트 프로 (고급 세그먼트 디스플레이)"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 진한 파란색 배경
    pygame.draw.rect(surface, (10, 15, 35), (board_x, board_y, board_width, board_height))

    # 프리미엄 프레임 (실버)
    draw_premium_frame(surface, (board_x, board_y, board_width, board_height), (100, 105, 115), 18)

    # 내부
    inner_x = board_x + 25
    inner_y = board_y + 25
    inner_w = board_width - 50
    inner_h = board_height - 50

    pygame.draw.rect(surface, (5, 8, 20), (inner_x, inner_y, inner_w, inner_h))

    # 상단 정보 바
    top_bar = pygame.Rect(inner_x + 10, inner_y + 10, inner_w - 20, 50)
    pygame.draw.rect(surface, (15, 25, 50), top_bar, border_radius=5)
    pygame.draw.rect(surface, (100, 150, 220), top_bar, 2, border_radius=5)

    title = font_title.render("★ ROUND SCORE ★", True, (180, 220, 255))
    title_rect = title.get_rect(center=(WIDTH // 2, inner_y + 35))
    surface.blit(title, title_rect)

    # 점수 디스플레이 영역
    score_area_y = inner_y + 75
    score_area_h = 200

    # 플레이어 섹션
    p_section = pygame.Rect(inner_x + 30, score_area_y, 280, score_area_h)
    pygame.draw.rect(surface, (8, 15, 40), p_section)
    pygame.draw.rect(surface, (80, 150, 220), p_section, 3)

    p_label = font_small.render("PLAYER", True, (150, 200, 255))
    p_label_rect = p_label.get_rect(center=(p_section.centerx, score_area_y + 25))
    surface.blit(p_label, p_label_rect)

    # 7세그먼트 점수
    seg_color = (0, 200, 255)
    pulse = 0.85 + 0.15 * math.sin(animation_frame * 0.08)
    draw_7segment_digit(surface, inner_x + 95, score_area_y + 50, player_score,
                       (int(seg_color[0]*pulse), int(seg_color[1]*pulse), int(seg_color[2]*pulse)), 130)

    # 보스 섹션
    b_section = pygame.Rect(inner_x + inner_w - 310, score_area_y, 280, score_area_h)
    pygame.draw.rect(surface, (40, 12, 12), b_section)
    pygame.draw.rect(surface, (220, 80, 80), b_section, 3)

    b_label = font_small.render("BOSS", True, (255, 150, 150))
    b_label_rect = b_label.get_rect(center=(b_section.centerx, score_area_y + 25))
    surface.blit(b_label, b_label_rect)

    red_color = (255, 60, 60)
    draw_7segment_digit(surface, inner_x + inner_w - 245, score_area_y + 50, boss_score,
                       (int(red_color[0]*pulse), int(red_color[1]*pulse), int(red_color[2]*pulse)), 130)

    # VS 중앙
    vs_x = WIDTH // 2
    vs_y = score_area_y + 100
    # 육각형 배경
    hex_points = []
    for i in range(6):
        angle = i * math.pi / 3 - math.pi / 6
        hex_points.append((vs_x + 40 * math.cos(angle), vs_y + 40 * math.sin(angle)))
    pygame.draw.polygon(surface, (30, 40, 70), hex_points)
    pygame.draw.polygon(surface, (100, 150, 220), hex_points, 3)
    vs = font_medium.render("VS", True, WHITE)
    vs_rect = vs.get_rect(center=(vs_x, vs_y))
    surface.blit(vs, vs_rect)

    # 하단
    footer = pygame.Rect(inner_x + 10, inner_y + inner_h - 55, inner_w - 20, 45)
    pygame.draw.rect(surface, (12, 20, 45), footer, border_radius=5)
    info = font_small.render("PING FIGHTER - PROFESSIONAL EDITION", True, (150, 180, 220))
    info_rect = info.get_rect(center=(WIDTH // 2, inner_y + inner_h - 32))
    surface.blit(info, info_rect)


def draw_style3_jumbotron_ultra(surface, player_score, boss_score, animation_frame):
    """스타일 3: 점보트론 울트라 (대형 스타디움 스크린)"""
    board_width = 780
    board_height = 420
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 검정 배경
    pygame.draw.rect(surface, (3, 3, 8), (board_x, board_y, board_width, board_height))

    # 슬림 프레임
    for i in range(8):
        alpha = 255 - i * 25
        color = (60 + i * 10, 60 + i * 10, 70 + i * 10)
        pygame.draw.rect(surface, color, (board_x - 8 + i, board_y - 8 + i,
                                          board_width + 16 - i*2, board_height + 16 - i*2), 1)

    # LED 픽셀 그리드
    for gx in range(0, board_width, 5):
        for gy in range(0, board_height, 5):
            pygame.draw.rect(surface, (8, 8, 12), (board_x + gx, board_y + gy, 4, 4))

    # 상단 헤더
    header = pygame.Rect(board_x + 20, board_y + 15, board_width - 40, 55)
    pygame.draw.rect(surface, (15, 20, 40), header, border_radius=8)
    pygame.draw.rect(surface, (100, 150, 255), header, 2, border_radius=8)

    # 로고
    pygame.draw.circle(surface, (255, 200, 50), (board_x + 55, board_y + 42), 22)
    pygame.draw.circle(surface, (220, 170, 40), (board_x + 55, board_y + 42), 18)
    logo = font_tiny.render("PF", True, (60, 50, 20))
    surface.blit(logo, (board_x + 45, board_y + 35))

    title = font_title.render("ROUND SCORE", True, (200, 220, 255))
    title_rect = title.get_rect(center=(WIDTH // 2, board_y + 42))
    surface.blit(title, title_rect)

    # 라운드 표시
    round_text = font_tiny.render("ROUND 3", True, (150, 200, 255))
    surface.blit(round_text, (board_x + board_width - 110, board_y + 35))

    # 팀 카드 (플레이어)
    p_card = pygame.Rect(board_x + 30, board_y + 85, board_width - 60, 120)
    # 그라데이션
    for i in range(120):
        alpha = 40 + i // 3
        pygame.draw.line(surface, (20 + i//6, 50 + i//4, 100 + i//3),
                        (p_card.x, p_card.y + i), (p_card.x + p_card.width, p_card.y + i))
    pygame.draw.rect(surface, (80, 160, 255), p_card, 3, border_radius=10)

    # 팀 로고
    pygame.draw.circle(surface, (40, 100, 200), (board_x + 90, board_y + 145), 35)
    pygame.draw.circle(surface, (80, 150, 255), (board_x + 90, board_y + 145), 30)
    p_icon = font_large.render("P", True, WHITE)
    p_icon_rect = p_icon.get_rect(center=(board_x + 90, board_y + 145))
    surface.blit(p_icon, p_icon_rect)

    p_name = font_large.render("PLAYER", True, (150, 220, 255))
    surface.blit(p_name, (board_x + 140, board_y + 115))

    # 대형 점수
    p_score = font_huge.render(str(player_score), True, (100, 220, 255))
    p_score_rect = p_score.get_rect(center=(board_x + board_width - 100, board_y + 145))
    # 글로우
    for d in [(-3,0),(3,0),(0,-3),(0,3),(-2,-2),(2,2),(-2,2),(2,-2)]:
        g = font_huge.render(str(player_score), True, (40, 100, 150))
        surface.blit(g, p_score_rect.move(d))
    surface.blit(p_score, p_score_rect)

    # 보스 카드
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

    b_score = font_huge.render(str(boss_score), True, (255, 120, 120))
    b_score_rect = b_score.get_rect(center=(board_x + board_width - 100, board_y + 275))
    for d in [(-3,0),(3,0),(0,-3),(0,3)]:
        g = font_huge.render(str(boss_score), True, (150, 50, 50))
        surface.blit(g, b_score_rect.move(d))
    surface.blit(b_score, b_score_rect)

    # 뉴스 티커
    ticker = pygame.Rect(board_x + 20, board_y + board_height - 60, board_width - 40, 45)
    pygame.draw.rect(surface, (12, 18, 35), ticker, border_radius=8)

    scroll = (animation_frame * 4) % 1000
    news = "★ PING FIGHTER ★ FIRST TO 3 WINS ★ BATTLE FOR GLORY ★ PING FIGHTER ★"
    news_text = font_small.render(news, True, (255, 220, 100))

    clip_rect = pygame.Rect(board_x + 25, board_y + board_height - 55, board_width - 50, 35)
    surface.set_clip(clip_rect)
    surface.blit(news_text, (board_x + board_width - scroll, board_y + board_height - 48))
    surface.set_clip(None)


def draw_style4_kbo_premium(surface, player_score, boss_score, animation_frame):
    """스타일 4: KBO 프리미엄 (한글 + 하이엔드)"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 네이비 배경
    pygame.draw.rect(surface, (8, 12, 30), (board_x, board_y, board_width, board_height))

    # 골드 프레임
    draw_premium_frame(surface, (board_x, board_y, board_width, board_height), (90, 80, 60), 20)

    # 내부
    inner_x = board_x + 28
    inner_y = board_y + 28
    inner_w = board_width - 56
    inner_h = board_height - 56

    pygame.draw.rect(surface, (5, 8, 22), (inner_x, inner_y, inner_w, inner_h))

    # 상단 팀 로고 영역
    header = pygame.Rect(inner_x + 15, inner_y + 12, inner_w - 30, 70)
    pygame.draw.rect(surface, (12, 18, 40), header)
    pygame.draw.rect(surface, (200, 170, 80), header, 2)

    # 플레이어 로고
    pygame.draw.circle(surface, (30, 80, 180), (inner_x + 70, inner_y + 47), 30)
    pygame.draw.circle(surface, (80, 140, 255), (inner_x + 70, inner_y + 47), 26)
    p_icon = font_medium.render("P", True, WHITE)
    p_icon_rect = p_icon.get_rect(center=(inner_x + 70, inner_y + 47))
    surface.blit(p_icon, p_icon_rect)

    p_name = font_large.render("플레이어", True, (100, 180, 255))
    surface.blit(p_name, (inner_x + 110, inner_y + 25))

    # 보스 로고
    pygame.draw.circle(surface, (180, 50, 50), (inner_x + inner_w - 70, inner_y + 47), 30)
    pygame.draw.circle(surface, (255, 100, 100), (inner_x + inner_w - 70, inner_y + 47), 26)
    b_icon = font_medium.render("B", True, WHITE)
    b_icon_rect = b_icon.get_rect(center=(inner_x + inner_w - 70, inner_y + 47))
    surface.blit(b_icon, b_icon_rect)

    b_name = font_large.render("보스", True, (255, 120, 120))
    b_name_rect = b_name.get_rect(right=inner_x + inner_w - 110, top=inner_y + 25)
    surface.blit(b_name, b_name_rect)

    # 점수 영역
    score_area = pygame.Rect(inner_x + 20, inner_y + 95, inner_w - 40, 180)
    pygame.draw.rect(surface, (8, 12, 28), score_area)
    pygame.draw.rect(surface, (180, 150, 70), score_area, 3)

    # 중앙 분리선
    pygame.draw.line(surface, (180, 150, 70), (WIDTH // 2, inner_y + 100), (WIDTH // 2, inner_y + 270), 3)

    # LED 점수
    pulse = 0.85 + 0.15 * math.sin(animation_frame * 0.1)
    blue_led = (80, 180, 255)
    red_led = (255, 100, 100)

    draw_dot_matrix_digit(surface, inner_x + 90, inner_y + 115, player_score,
                         (int(blue_led[0]*pulse), int(blue_led[1]*pulse), int(blue_led[2]*pulse)), 140, 5)
    draw_dot_matrix_digit(surface, inner_x + inner_w - 210, inner_y + 115, boss_score,
                         (int(red_led[0]*pulse), int(red_led[1]*pulse), int(red_led[2]*pulse)), 140, 5)

    # VS
    vs_bg = pygame.Rect(WIDTH // 2 - 35, inner_y + 180, 70, 50)
    pygame.draw.rect(surface, (50, 40, 20), vs_bg)
    pygame.draw.rect(surface, (200, 170, 80), vs_bg, 2)
    vs = font_medium.render("VS", True, (255, 220, 120))
    vs_rect = vs.get_rect(center=(WIDTH // 2, inner_y + 205))
    surface.blit(vs, vs_rect)

    # 하단
    footer = pygame.Rect(inner_x + 15, inner_y + inner_h - 50, inner_w - 30, 40)
    pygame.draw.rect(surface, (15, 22, 45), footer)
    pygame.draw.rect(surface, (150, 130, 60), footer, 2)

    info = font_medium.render("◆ 3점 선취 승리 ◆", True, (255, 220, 120))
    info_rect = info.get_rect(center=(WIDTH // 2, inner_y + inner_h - 30))
    surface.blit(info, info_rect)


def draw_style5_neon_arcade(surface, player_score, boss_score, animation_frame):
    """스타일 5: 네온 아케이드 (사이버펑크 스타일)"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 검정 배경
    pygame.draw.rect(surface, (5, 5, 12), (board_x, board_y, board_width, board_height))

    # 네온 프레임 (다중 레이어)
    neon_colors = [(255, 0, 100), (0, 255, 200), (255, 100, 0)]
    for i, color in enumerate(neon_colors):
        offset = i * 3
        # 글로우
        for g in range(5, 0, -1):
            glow_surf = pygame.Surface((board_width + 20, board_height + 20), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*color, 20 // g), (10, 10, board_width, board_height), g + 2)
            surface.blit(glow_surf, (board_x - 10, board_y - 10))
        pygame.draw.rect(surface, color, (board_x - offset, board_y - offset, board_width + offset*2, board_height + offset*2), 2)

    # 스캔라인 효과
    for y in range(0, board_height, 3):
        pygame.draw.line(surface, (10, 10, 20), (board_x, board_y + y), (board_x + board_width, board_y + y), 1)

    # 상단 타이틀
    title_bar = pygame.Rect(board_x + 25, board_y + 20, board_width - 50, 60)
    pygame.draw.rect(surface, (10, 10, 25), title_bar, border_radius=5)

    # 네온 타이틀
    title_text = "▶ SCORE BOARD ◀"
    # 글로우 효과
    for color in [(0, 255, 200), (255, 0, 150)]:
        for offset in range(4, 0, -1):
            glow = font_title.render(title_text, True, (*color, 50 // offset))
            glow_rect = glow.get_rect(center=(WIDTH // 2, board_y + 50))
            surface.blit(glow, glow_rect.move(offset, offset))
            surface.blit(glow, glow_rect.move(-offset, -offset))
    title = font_title.render(title_text, True, (0, 255, 200))
    title_rect = title.get_rect(center=(WIDTH // 2, board_y + 50))
    surface.blit(title, title_rect)

    # 점수 영역
    score_y = board_y + 100

    # 플레이어 박스
    p_box = pygame.Rect(board_x + 40, score_y, 280, 200)
    pygame.draw.rect(surface, (8, 20, 25), p_box)
    # 네온 테두리
    for g in range(4):
        pygame.draw.rect(surface, (0, 255 - g*50, 200 - g*40), p_box.inflate(g*2, g*2), 2)

    p_label = font_medium.render("1P", True, (0, 255, 200))
    surface.blit(p_label, (board_x + 150, score_y + 10))

    # 점수 (네온 효과)
    cyan = (0, 255, 220)
    draw_7segment_digit(surface, board_x + 105, score_y + 50, player_score, cyan, 130)

    # 보스 박스
    b_box = pygame.Rect(board_x + board_width - 320, score_y, 280, 200)
    pygame.draw.rect(surface, (25, 10, 15), b_box)
    for g in range(4):
        pygame.draw.rect(surface, (255 - g*40, 0, 100 - g*20), b_box.inflate(g*2, g*2), 2)

    b_label = font_medium.render("CPU", True, (255, 50, 150))
    surface.blit(b_label, (board_x + board_width - 210, score_y + 10))

    magenta = (255, 50, 150)
    draw_7segment_digit(surface, board_x + board_width - 255, score_y + 50, boss_score, magenta, 130)

    # VS 중앙 (회전하는 효과)
    vs_x = WIDTH // 2
    vs_y = score_y + 100
    rotation = animation_frame * 2

    # 회전하는 다이아몬드
    diamond_size = 45
    for i in range(3):
        angle_offset = rotation + i * 30
        points = []
        for j in range(4):
            angle = math.radians(angle_offset + j * 90)
            px = vs_x + (diamond_size - i * 10) * math.cos(angle)
            py = vs_y + (diamond_size - i * 10) * math.sin(angle)
            points.append((px, py))
        color = (255 - i * 80, 100 + i * 50, 200 - i * 50)
        pygame.draw.polygon(surface, color, points, 2)

    vs = font_medium.render("VS", True, (255, 255, 255))
    vs_rect = vs.get_rect(center=(vs_x, vs_y))
    surface.blit(vs, vs_rect)

    # 하단 - 깜빡이는 텍스트
    if animation_frame % 40 < 30:
        footer = font_medium.render("INSERT COIN", True, (255, 220, 0))
        footer_rect = footer.get_rect(center=(WIDTH // 2, board_y + board_height - 40))
        # 글로우
        for g in range(3):
            glow = font_medium.render("INSERT COIN", True, (255, 150, 0))
            glow.set_alpha(80 - g * 25)
            surface.blit(glow, footer_rect.move(g, g))
        surface.blit(footer, footer_rect)


def main():
    current_style = 0
    styles = [
        ("1: 프리미엄 클래식", draw_style1_premium_classic),
        ("2: 7세그먼트 프로", draw_style2_7segment_pro),
        ("3: 점보트론 울트라", draw_style3_jumbotron_ultra),
        ("4: KBO 프리미엄", draw_style4_kbo_premium),
        ("5: 네온 아케이드", draw_style5_neon_arcade),
    ]

    player_score = 2
    boss_score = 1
    animation_frame = 0

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_LEFT:
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
                elif event.key == pygame.K_UP:
                    player_score = min(9, player_score + 1)
                elif event.key == pygame.K_DOWN:
                    player_score = max(0, player_score - 1)
                elif event.key == pygame.K_w:
                    boss_score = min(9, boss_score + 1)
                elif event.key == pygame.K_s:
                    boss_score = max(0, boss_score - 1)
                elif event.key == pygame.K_ESCAPE:
                    running = False

        # 배경
        screen.fill((10, 10, 18))

        # 현재 스타일 그리기
        style_name, draw_func = styles[current_style]
        draw_func(screen, player_score, boss_score, animation_frame)

        # 안내 텍스트
        guide = font_tiny.render("← → 스타일 | ↑↓ P점수 | W/S 보스점수 | 1-5 선택 | ESC 종료", True, (120, 120, 130))
        screen.blit(guide, (20, 12))

        # 현재 스타일 이름
        style_text = font_medium.render(style_name, True, YELLOW)
        style_rect = style_text.get_rect(center=(WIDTH // 2, HEIGHT - 40))

        # 배경 박스
        bg_rect = style_rect.inflate(30, 15)
        pygame.draw.rect(screen, (25, 25, 35), bg_rect, border_radius=8)
        pygame.draw.rect(screen, (255, 200, 50), bg_rect, 2, border_radius=8)
        screen.blit(style_text, style_rect)

        pygame.display.flip()
        clock.tick(60)
        animation_frame += 1

    pygame.quit()


if __name__ == "__main__":
    main()
