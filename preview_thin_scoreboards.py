"""
얇은 폰트 야구 전광판 프리뷰 - 5가지 스타일
숫자 폰트를 더 얇고 세련되게 수정
"""

import pygame
import math
import sys

pygame.init()

# 화면 설정
WIDTH, HEIGHT = 900, 700
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("얇은 폰트 전광판 프리뷰")

# 폰트
font_title = pygame.font.SysFont("Arial", 24, bold=True)
font_info = pygame.font.SysFont("Arial", 16)

# 얇은 도트 매트릭스 패턴 (7x11) - 더 슬림한 디자인
THIN_PATTERNS = {
    '0': [
        " 11111 ",
        "11   11",
        "11   11",
        "11   11",
        "11   11",
        "11   11",
        "11   11",
        "11   11",
        "11   11",
        "11   11",
        " 11111 "
    ],
    '1': [
        "   11  ",
        "  111  ",
        " 1111  ",
        "   11  ",
        "   11  ",
        "   11  ",
        "   11  ",
        "   11  ",
        "   11  ",
        "   11  ",
        " 111111"
    ],
    '2': [
        " 11111 ",
        "11   11",
        "     11",
        "     11",
        "    11 ",
        "   11  ",
        "  11   ",
        " 11    ",
        "11     ",
        "11   11",
        "1111111"
    ],
    '3': [
        " 11111 ",
        "11   11",
        "     11",
        "     11",
        "  1111 ",
        "     11",
        "     11",
        "     11",
        "     11",
        "11   11",
        " 11111 "
    ],
    '4': [
        "    11 ",
        "   111 ",
        "  1111 ",
        " 11 11 ",
        "11  11 ",
        "11  11 ",
        "1111111",
        "    11 ",
        "    11 ",
        "    11 ",
        "    11 "
    ],
    '5': [
        "1111111",
        "11     ",
        "11     ",
        "11     ",
        "111111 ",
        "     11",
        "     11",
        "     11",
        "     11",
        "11   11",
        " 11111 "
    ],
    '6': [
        " 11111 ",
        "11   11",
        "11     ",
        "11     ",
        "111111 ",
        "11   11",
        "11   11",
        "11   11",
        "11   11",
        "11   11",
        " 11111 "
    ],
    '7': [
        "1111111",
        "11   11",
        "     11",
        "    11 ",
        "    11 ",
        "   11  ",
        "   11  ",
        "  11   ",
        "  11   ",
        "  11   ",
        "  11   "
    ],
    '8': [
        " 11111 ",
        "11   11",
        "11   11",
        "11   11",
        " 11111 ",
        "11   11",
        "11   11",
        "11   11",
        "11   11",
        "11   11",
        " 11111 "
    ],
    '9': [
        " 11111 ",
        "11   11",
        "11   11",
        "11   11",
        " 111111",
        "     11",
        "     11",
        "     11",
        "     11",
        "11   11",
        " 11111 "
    ]
}

# 울트라 슬림 패턴 (5x9) - 매우 얇은 디자인
ULTRA_SLIM_PATTERNS = {
    '0': [
        " 111 ",
        "1   1",
        "1   1",
        "1   1",
        "1   1",
        "1   1",
        "1   1",
        "1   1",
        " 111 "
    ],
    '1': [
        "  1  ",
        " 11  ",
        "  1  ",
        "  1  ",
        "  1  ",
        "  1  ",
        "  1  ",
        "  1  ",
        " 111 "
    ],
    '2': [
        " 111 ",
        "1   1",
        "    1",
        "   1 ",
        "  1  ",
        " 1   ",
        "1    ",
        "1   1",
        "11111"
    ],
    '3': [
        " 111 ",
        "1   1",
        "    1",
        "  11 ",
        "    1",
        "    1",
        "    1",
        "1   1",
        " 111 "
    ],
    '4': [
        "   1 ",
        "  11 ",
        " 1 1 ",
        "1  1 ",
        "11111",
        "   1 ",
        "   1 ",
        "   1 ",
        "   1 "
    ],
    '5': [
        "11111",
        "1    ",
        "1    ",
        "1111 ",
        "    1",
        "    1",
        "    1",
        "1   1",
        " 111 "
    ],
    '6': [
        " 111 ",
        "1   1",
        "1    ",
        "1111 ",
        "1   1",
        "1   1",
        "1   1",
        "1   1",
        " 111 "
    ],
    '7': [
        "11111",
        "1   1",
        "    1",
        "   1 ",
        "  1  ",
        "  1  ",
        " 1   ",
        " 1   ",
        " 1   "
    ],
    '8': [
        " 111 ",
        "1   1",
        "1   1",
        " 111 ",
        "1   1",
        "1   1",
        "1   1",
        "1   1",
        " 111 "
    ],
    '9': [
        " 111 ",
        "1   1",
        "1   1",
        " 1111",
        "    1",
        "    1",
        "    1",
        "1   1",
        " 111 "
    ]
}

# 7세그먼트 스타일 (세그먼트 기반)
SEGMENT_PATTERNS = {
    '0': "1111110",  # a,b,c,d,e,f,g (g=중앙)
    '1': "0110000",
    '2': "1101101",
    '3': "1111001",
    '4': "0110011",
    '5': "1011011",
    '6': "1011111",
    '7': "1110000",
    '8': "1111111",
    '9': "1111011"
}


def draw_led_dot(surface, x, y, color, size=4, is_on=True, style="standard"):
    """LED 도트 그리기"""
    if is_on:
        if style == "glow":
            # 글로우 효과
            for i in range(4, 0, -1):
                glow_surf = pygame.Surface((size*4 + i*4, size*4 + i*4), pygame.SRCALPHA)
                glow_alpha = 60 // i
                glow_color = (*color, glow_alpha)
                pygame.draw.circle(glow_surf, glow_color, (size*2 + i*2, size*2 + i*2), size + i*2)
                surface.blit(glow_surf, (x - size*2 - i*2, y - size*2 - i*2))
            pygame.draw.circle(surface, color, (x, y), size)
            bright = tuple(min(255, c + 100) for c in color)
            pygame.draw.circle(surface, bright, (x, y), size - 1)
        elif style == "soft":
            # 부드러운 LED
            pygame.draw.circle(surface, color, (x, y), size)
            bright = tuple(min(255, c + 60) for c in color)
            pygame.draw.circle(surface, bright, (x, y), size - 1)
        elif style == "sharp":
            # 선명한 사각 LED
            pygame.draw.rect(surface, color, (x - size, y - size, size*2, size*2))
            bright = tuple(min(255, c + 80) for c in color)
            pygame.draw.rect(surface, bright, (x - size + 1, y - size + 1, size*2 - 2, size*2 - 2))
        else:
            pygame.draw.circle(surface, color, (x, y), size)
    else:
        dim = tuple(max(8, c // 15) for c in color)
        if style == "sharp":
            pygame.draw.rect(surface, dim, (x - size, y - size, size*2, size*2))
        else:
            pygame.draw.circle(surface, dim, (x, y), size - 1)


def draw_thin_digit(surface, x, y, digit, color, size=100, style="standard", dot_style="glow"):
    """얇은 도트 매트릭스 숫자"""
    pattern = THIN_PATTERNS.get(str(digit), THIN_PATTERNS['0'])
    rows = len(pattern)
    cols = len(pattern[0])
    spacing = size // rows
    dot_size = max(2, spacing // 3)

    for row_idx, row in enumerate(pattern):
        for col_idx, char in enumerate(row):
            dot_x = x + col_idx * spacing + spacing // 2
            dot_y = y + row_idx * spacing + spacing // 2
            draw_led_dot(surface, dot_x, dot_y, color, dot_size, char == '1', dot_style)


def draw_ultra_slim_digit(surface, x, y, digit, color, size=100, dot_style="glow"):
    """울트라 슬림 숫자"""
    pattern = ULTRA_SLIM_PATTERNS.get(str(digit), ULTRA_SLIM_PATTERNS['0'])
    rows = len(pattern)
    cols = len(pattern[0])
    spacing = size // rows
    dot_size = max(3, spacing // 2)

    for row_idx, row in enumerate(pattern):
        for col_idx, char in enumerate(row):
            dot_x = x + col_idx * spacing + spacing // 2
            dot_y = y + row_idx * spacing + spacing // 2
            draw_led_dot(surface, dot_x, dot_y, color, dot_size, char == '1', dot_style)


def draw_7segment_digit(surface, x, y, digit, color, width=60, height=100, thickness=8):
    """7세그먼트 디스플레이 숫자"""
    segments = SEGMENT_PATTERNS.get(str(digit), "0000000")

    # 세그먼트 위치 정의
    # a: 상단, b: 우상, c: 우하, d: 하단, e: 좌하, f: 좌상, g: 중앙
    half_w = width // 2
    half_h = height // 2
    t = thickness

    def draw_h_segment(sx, sy, on):
        """가로 세그먼트"""
        if on:
            points = [
                (sx + t, sy),
                (sx + width - t, sy),
                (sx + width - t//2, sy + t//2),
                (sx + width - t, sy + t),
                (sx + t, sy + t),
                (sx + t//2, sy + t//2)
            ]
            # 글로우
            glow_surf = pygame.Surface((width + 20, t + 20), pygame.SRCALPHA)
            pygame.draw.polygon(glow_surf, (*color, 60), [(p[0] - sx + 10, p[1] - sy + 10) for p in points])
            surface.blit(glow_surf, (sx - 10, sy - 10))
            pygame.draw.polygon(surface, color, points)
            bright = tuple(min(255, c + 80) for c in color)
            inner_points = [
                (sx + t + 2, sy + 2),
                (sx + width - t - 2, sy + 2),
                (sx + width - t//2 - 1, sy + t//2),
                (sx + width - t - 2, sy + t - 2),
                (sx + t + 2, sy + t - 2),
                (sx + t//2 + 1, sy + t//2)
            ]
            pygame.draw.polygon(surface, bright, inner_points)
        else:
            dim = tuple(max(5, c // 20) for c in color)
            pygame.draw.rect(surface, dim, (sx + t, sy + 1, width - t*2, t - 2))

    def draw_v_segment(sx, sy, on):
        """세로 세그먼트"""
        if on:
            points = [
                (sx + t//2, sy + t//2),
                (sx + t, sy + t),
                (sx + t, sy + half_h - t),
                (sx + t//2, sy + half_h - t//2),
                (sx, sy + half_h - t),
                (sx, sy + t)
            ]
            glow_surf = pygame.Surface((t + 20, half_h + 10), pygame.SRCALPHA)
            pygame.draw.polygon(glow_surf, (*color, 60), [(p[0] - sx + 10, p[1] - sy + 5) for p in points])
            surface.blit(glow_surf, (sx - 10, sy - 5))
            pygame.draw.polygon(surface, color, points)
            bright = tuple(min(255, c + 80) for c in color)
            pygame.draw.polygon(surface, bright, [
                (sx + t//2, sy + t//2 + 2),
                (sx + t - 2, sy + t + 2),
                (sx + t - 2, sy + half_h - t - 2),
                (sx + t//2, sy + half_h - t//2 - 1),
                (sx + 2, sy + half_h - t - 2),
                (sx + 2, sy + t + 2)
            ])
        else:
            dim = tuple(max(5, c // 20) for c in color)
            pygame.draw.rect(surface, dim, (sx + 1, sy + t, t - 2, half_h - t*2))

    # 세그먼트 그리기
    draw_h_segment(x, y, segments[0] == '1')  # a
    draw_v_segment(x + width - t, y, segments[1] == '1')  # b
    draw_v_segment(x + width - t, y + half_h, segments[2] == '1')  # c
    draw_h_segment(x, y + height - t, segments[3] == '1')  # d
    draw_v_segment(x, y + half_h, segments[4] == '1')  # e
    draw_v_segment(x, y, segments[5] == '1')  # f
    draw_h_segment(x, y + half_h - t//2, segments[6] == '1')  # g


def draw_outline_digit(surface, x, y, digit, color, size=100):
    """외곽선 스타일 숫자"""
    pattern = THIN_PATTERNS.get(str(digit), THIN_PATTERNS['0'])
    rows = len(pattern)
    cols = len(pattern[0])
    spacing = size // rows

    # 외곽선 추출
    for row_idx, row in enumerate(pattern):
        for col_idx, char in enumerate(row):
            if char == '1':
                # 주변에 빈칸이 있으면 외곽선
                is_edge = False
                for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    nr, nc = row_idx + dr, col_idx + dc
                    if nr < 0 or nr >= rows or nc < 0 or nc >= cols:
                        is_edge = True
                    elif pattern[nr][nc] == ' ':
                        is_edge = True

                dot_x = x + col_idx * spacing + spacing // 2
                dot_y = y + row_idx * spacing + spacing // 2
                dot_size = max(2, spacing // 3)

                if is_edge:
                    # 외곽선 - 밝게
                    draw_led_dot(surface, dot_x, dot_y, color, dot_size, True, "glow")
                else:
                    # 내부 - 어둡게
                    dim = tuple(c // 3 for c in color)
                    draw_led_dot(surface, dot_x, dot_y, dim, dot_size - 1, True, "soft")


def draw_style_1(surface, rect, p_score, b_score, timer):
    """스타일 1: 슬림 도트 매트릭스 (7x11)"""
    x, y, w, h = rect

    # 배경
    pygame.draw.rect(surface, (5, 10, 25), rect)
    pygame.draw.rect(surface, (180, 150, 80), rect, 3)

    # 상단 바
    pygame.draw.rect(surface, (20, 30, 60), (x + 10, y + 10, w - 20, 40))
    pygame.draw.rect(surface, (150, 130, 60), (x + 10, y + 10, w - 20, 40), 2)

    # 팀 이름
    title_font = pygame.font.SysFont("Arial", 20, bold=True)
    p_text = title_font.render("PLAYER", True, (100, 180, 255))
    b_text = title_font.render("BOSS", True, (255, 100, 100))
    surface.blit(p_text, (x + 30, y + 20))
    surface.blit(b_text, (x + w - 80, y + 20))

    # 점수 영역
    score_y = y + 60
    score_h = h - 80
    center_x = x + w // 2

    pygame.draw.line(surface, (150, 130, 60), (center_x, score_y), (center_x, y + h - 15), 2)

    # 펄스 효과
    pulse = 0.85 + 0.15 * math.sin(timer * 0.1)

    # 숫자 크기 및 위치 계산
    digit_h = min(100, score_h - 20)
    digit_w = 7 * (digit_h // 11)

    # 플레이어 점수 - 왼쪽 영역 중앙
    left_area = center_x - x - 10
    p_x = x + (left_area - digit_w) // 2 + 5
    p_y = score_y + (score_h - digit_h) // 2
    p_color = (int(80*pulse), int(180*pulse), int(255*pulse))
    draw_thin_digit(surface, p_x, p_y, p_score, p_color, digit_h, dot_style="glow")

    # 보스 점수 - 오른쪽 영역 중앙
    right_area = x + w - center_x - 10
    b_x = center_x + (right_area - digit_w) // 2 + 5
    b_y = score_y + (score_h - digit_h) // 2
    b_color = (int(255*pulse), int(100*pulse), int(100*pulse))
    draw_thin_digit(surface, b_x, b_y, b_score, b_color, digit_h, dot_style="glow")

    # VS
    vs_font = pygame.font.SysFont("Arial", 18, bold=True)
    vs = vs_font.render("VS", True, (255, 220, 100))
    vs_rect = vs.get_rect(center=(center_x, score_y + score_h // 2))
    pygame.draw.rect(surface, (40, 35, 20), vs_rect.inflate(16, 8))
    pygame.draw.rect(surface, (180, 150, 70), vs_rect.inflate(16, 8), 2)
    surface.blit(vs, vs_rect)


def draw_style_2(surface, rect, p_score, b_score, timer):
    """스타일 2: 울트라 슬림 (5x9) - 미니멀"""
    x, y, w, h = rect

    # 다크 배경
    pygame.draw.rect(surface, (10, 10, 15), rect)
    pygame.draw.rect(surface, (60, 60, 70), rect, 2)

    # 심플 상단 라인
    pygame.draw.line(surface, (80, 80, 90), (x + 15, y + 35), (x + w - 15, y + 35), 1)

    # 팀 라벨
    font = pygame.font.SysFont("Arial", 14)
    p_text = font.render("P", True, (80, 150, 220))
    b_text = font.render("B", True, (220, 80, 80))
    surface.blit(p_text, (x + 25, y + 15))
    surface.blit(b_text, (x + w - 35, y + 15))

    center_x = x + w // 2
    score_y = y + 45
    score_h = h - 60

    # 중앙 점선
    for i in range(score_y, y + h - 10, 8):
        pygame.draw.line(surface, (50, 50, 60), (center_x, i), (center_x, i + 4), 1)

    # 펄스
    pulse = 0.9 + 0.1 * math.sin(timer * 0.15)

    # 숫자 크기 계산
    digit_h = min(80, score_h - 10)
    digit_w = 5 * (digit_h // 9)

    # 플레이어 점수
    left_area = center_x - x - 10
    p_x = x + (left_area - digit_w) // 2 + 5
    p_y = score_y + (score_h - digit_h) // 2
    p_color = (int(60*pulse), int(200*pulse), int(255*pulse))
    draw_ultra_slim_digit(surface, p_x, p_y, p_score, p_color, digit_h, "soft")

    # 보스 점수
    right_area = x + w - center_x - 10
    b_x = center_x + (right_area - digit_w) // 2 + 5
    b_y = score_y + (score_h - digit_h) // 2
    b_color = (int(255*pulse), int(80*pulse), int(100*pulse))
    draw_ultra_slim_digit(surface, b_x, b_y, b_score, b_color, digit_h, "soft")


def draw_style_3(surface, rect, p_score, b_score, timer):
    """스타일 3: 7세그먼트 디스플레이"""
    x, y, w, h = rect

    # 짙은 녹색 배경 (LCD 느낌)
    pygame.draw.rect(surface, (5, 20, 15), rect)
    pygame.draw.rect(surface, (40, 80, 60), rect, 4)

    # 내부 패널
    inner_rect = (x + 8, y + 8, w - 16, h - 16)
    pygame.draw.rect(surface, (8, 25, 18), inner_rect)

    # 팀 표시
    font = pygame.font.SysFont("Consolas", 16)
    p_text = font.render("PLY", True, (50, 150, 100))
    b_text = font.render("BOS", True, (150, 80, 80))
    surface.blit(p_text, (x + 20, y + 15))
    surface.blit(b_text, (x + w - 55, y + 15))

    center_x = x + w // 2
    score_y = y + 40
    score_h = h - 55

    # 구분선
    pygame.draw.line(surface, (30, 70, 50), (center_x, score_y), (center_x, y + h - 10), 2)

    # 펄스
    pulse = 0.85 + 0.15 * math.sin(timer * 0.12)

    # 7세그먼트 크기
    seg_h = min(90, score_h - 15)
    seg_w = int(seg_h * 0.55)

    # 플레이어 점수
    left_area = center_x - x - 15
    p_x = x + (left_area - seg_w) // 2 + 8
    p_y = score_y + (score_h - seg_h) // 2
    p_color = (int(50*pulse), int(220*pulse), int(150*pulse))
    draw_7segment_digit(surface, p_x, p_y, p_score, p_color, seg_w, seg_h, 6)

    # 보스 점수
    right_area = x + w - center_x - 15
    b_x = center_x + (right_area - seg_w) // 2 + 8
    b_y = score_y + (score_h - seg_h) // 2
    b_color = (int(220*pulse), int(80*pulse), int(80*pulse))
    draw_7segment_digit(surface, b_x, b_y, b_score, b_color, seg_w, seg_h, 6)


def draw_style_4(surface, rect, p_score, b_score, timer):
    """스타일 4: 외곽선 네온"""
    x, y, w, h = rect

    # 검은 배경
    pygame.draw.rect(surface, (2, 2, 8), rect)

    # 네온 테두리
    for i in range(3):
        color = (80 - i*20, 0, 150 - i*30, 150 - i*40)
        border_surf = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.rect(border_surf, color, (0, 0, w, h), 3 - i)
        surface.blit(border_surf, (x, y))

    # 사이버펑크 라인
    pygame.draw.line(surface, (100, 0, 180), (x + 10, y + 30), (x + w - 10, y + 30), 1)

    center_x = x + w // 2
    score_y = y + 40
    score_h = h - 50

    # 중앙 네온 라인
    for i in range(3):
        line_color = (120 - i*30, 0, 200 - i*40)
        pygame.draw.line(surface, line_color, (center_x, score_y), (center_x, y + h - 10), 2 - i//2)

    # 펄스
    pulse = 0.8 + 0.2 * math.sin(timer * 0.08)

    # 외곽선 숫자 크기
    digit_h = min(95, score_h - 15)
    digit_w = 7 * (digit_h // 11)

    # 플레이어 점수 (시안)
    left_area = center_x - x - 10
    p_x = x + (left_area - digit_w) // 2 + 5
    p_y = score_y + (score_h - digit_h) // 2
    p_color = (int(0*pulse), int(255*pulse), int(255*pulse))
    draw_outline_digit(surface, p_x, p_y, p_score, p_color, digit_h)

    # 보스 점수 (마젠타)
    right_area = x + w - center_x - 10
    b_x = center_x + (right_area - digit_w) // 2 + 5
    b_y = score_y + (score_h - digit_h) // 2
    b_color = (int(255*pulse), int(0*pulse), int(180*pulse))
    draw_outline_digit(surface, b_x, b_y, b_score, b_color, digit_h)

    # VS 네온
    vs_font = pygame.font.SysFont("Arial", 16, bold=True)
    vs = vs_font.render("VS", True, (255, 255, 0))
    vs_rect = vs.get_rect(center=(center_x, score_y + score_h // 2))
    surface.blit(vs, vs_rect)


def draw_style_5(surface, rect, p_score, b_score, timer):
    """스타일 5: 샤프 사각 LED"""
    x, y, w, h = rect

    # 메탈릭 배경
    for i in range(h):
        shade = 15 + (i % 3) * 2
        pygame.draw.line(surface, (shade, shade + 2, shade + 5), (x, y + i), (x + w, y + i))

    # 금속 프레임
    pygame.draw.rect(surface, (100, 100, 110), rect, 4)
    pygame.draw.rect(surface, (60, 60, 70), (x + 2, y + 2, w - 4, h - 4), 2)

    # 디스플레이 영역
    display_rect = (x + 12, y + 12, w - 24, h - 24)
    pygame.draw.rect(surface, (5, 8, 15), display_rect)
    pygame.draw.rect(surface, (40, 45, 55), display_rect, 2)

    # 팀 표시
    font = pygame.font.SysFont("Consolas", 14, bold=True)
    p_text = font.render("[P]", True, (100, 160, 220))
    b_text = font.render("[B]", True, (220, 100, 100))
    surface.blit(p_text, (x + 20, y + 18))
    surface.blit(b_text, (x + w - 45, y + 18))

    center_x = x + w // 2
    score_y = y + 45
    score_h = h - 60

    # 중앙 구분
    pygame.draw.rect(surface, (30, 35, 45), (center_x - 2, score_y, 4, score_h - 5))

    # 펄스
    pulse = 0.9 + 0.1 * math.sin(timer * 0.1)

    # 사각 LED 숫자
    digit_h = min(90, score_h - 10)
    digit_w = 7 * (digit_h // 11)

    # 플레이어 점수
    left_area = center_x - x - 15
    p_x = x + (left_area - digit_w) // 2 + 8
    p_y = score_y + (score_h - digit_h) // 2
    p_color = (int(80*pulse), int(200*pulse), int(255*pulse))
    draw_thin_digit(surface, p_x, p_y, p_score, p_color, digit_h, dot_style="sharp")

    # 보스 점수
    right_area = x + w - center_x - 15
    b_x = center_x + (right_area - digit_w) // 2 + 8
    b_y = score_y + (score_h - digit_h) // 2
    b_color = (int(255*pulse), int(100*pulse), int(80*pulse))
    draw_thin_digit(surface, b_x, b_y, b_score, b_color, digit_h, dot_style="sharp")

    # VS
    vs_font = pygame.font.SysFont("Consolas", 14, bold=True)
    vs = vs_font.render("VS", True, (200, 200, 210))
    vs_rect = vs.get_rect(center=(center_x, score_y + score_h // 2))
    surface.blit(vs, vs_rect)


def main():
    clock = pygame.time.Clock()
    timer = 0
    p_score, b_score = 2, 1

    styles = [
        ("1. 슬림 도트 (7x11)", draw_style_1),
        ("2. 울트라 슬림 (5x9)", draw_style_2),
        ("3. 7세그먼트", draw_style_3),
        ("4. 네온 아웃라인", draw_style_4),
        ("5. 샤프 사각 LED", draw_style_5)
    ]

    # 레이아웃: 상단 3개, 하단 2개
    board_w, board_h = 260, 180
    positions = [
        (50, 80),
        (320, 80),
        (590, 80),
        (185, 320),
        (455, 320)
    ]

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    p_score = (p_score + 1) % 10
                elif event.key == pygame.K_RETURN:
                    b_score = (b_score + 1) % 10

        # 배경
        screen.fill((20, 20, 30))

        # 타이틀
        title = font_title.render("얇은 폰트 야구 전광판 - 5가지 스타일", True, (255, 255, 255))
        screen.blit(title, (WIDTH // 2 - title.get_width() // 2, 20))

        # 조작 안내
        info = font_info.render("SPACE: 플레이어 점수 / ENTER: 보스 점수 / ESC: 종료", True, (150, 150, 150))
        screen.blit(info, (WIDTH // 2 - info.get_width() // 2, 55))

        # 각 스타일 그리기
        for i, (name, draw_func) in enumerate(styles):
            px, py = positions[i]

            # 스타일 이름
            name_text = font_info.render(name, True, (200, 200, 200))
            screen.blit(name_text, (px + board_w // 2 - name_text.get_width() // 2, py - 20))

            # 전광판 그리기
            draw_func(screen, (px, py, board_w, board_h), p_score, b_score, timer)

        # 하단 안내
        bottom_info = font_info.render("마음에 드는 스타일 번호를 알려주세요!", True, (255, 220, 100))
        screen.blit(bottom_info, (WIDTH // 2 - bottom_info.get_width() // 2, HEIGHT - 40))

        pygame.display.flip()
        clock.tick(60)
        timer += 1

    pygame.quit()


if __name__ == "__main__":
    main()
