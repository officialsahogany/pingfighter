"""
프리미엄 얇은 폰트 야구 전광판 - 5가지 초고퀄리티 스타일
디테일과 시각 효과를 극대화한 버전
"""

import pygame
import math
import random
import sys

pygame.init()

# 화면 설정
WIDTH, HEIGHT = 1000, 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("프리미엄 얇은 폰트 전광판")

# 폰트
try:
    font_korean = pygame.font.Font("/System/Library/Fonts/AppleSDGothicNeo.ttc", 18)
    font_korean_large = pygame.font.Font("/System/Library/Fonts/AppleSDGothicNeo.ttc", 24)
except:
    font_korean = pygame.font.SysFont("Arial", 18)
    font_korean_large = pygame.font.SysFont("Arial", 24)

font_title = pygame.font.SysFont("Arial", 28, bold=True)
font_info = pygame.font.SysFont("Arial", 14)

# ============================================
# 얇은 도트 매트릭스 패턴 (7x11) - 슬림 디자인
# ============================================
SLIM_PATTERNS_7x11 = {
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
        "    111",
        "   1111",
        "  11 11",
        " 11  11",
        "11   11",
        "11   11",
        "1111111",
        "     11",
        "     11",
        "     11",
        "     11"
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

# 7세그먼트 패턴
SEGMENT_MAP = {
    '0': [1,1,1,1,1,1,0],
    '1': [0,1,1,0,0,0,0],
    '2': [1,1,0,1,1,0,1],
    '3': [1,1,1,1,0,0,1],
    '4': [0,1,1,0,0,1,1],
    '5': [1,0,1,1,0,1,1],
    '6': [1,0,1,1,1,1,1],
    '7': [1,1,1,0,0,0,0],
    '8': [1,1,1,1,1,1,1],
    '9': [1,1,1,1,0,1,1]
}


def draw_premium_led(surface, x, y, color, size=4, intensity=1.0, is_on=True, style="circle"):
    """프리미엄 LED 도트 - 다층 글로우 효과"""
    if is_on:
        # 6단계 글로우 레이어
        for i in range(6, 0, -1):
            glow_radius = size + i * 2
            glow_alpha = int(50 * intensity / i)
            glow_surf = pygame.Surface((glow_radius * 2 + 12, glow_radius * 2 + 12), pygame.SRCALPHA)
            glow_color = (color[0], color[1], color[2], glow_alpha)
            if style == "circle":
                pygame.draw.circle(glow_surf, glow_color, (glow_radius + 6, glow_radius + 6), glow_radius)
            else:
                pygame.draw.rect(glow_surf, glow_color, (6, 6, glow_radius * 2, glow_radius * 2))
            surface.blit(glow_surf, (x - glow_radius - 6, y - glow_radius - 6))

        # 메인 LED
        if style == "circle":
            pygame.draw.circle(surface, color, (x, y), size)
            # 밝은 중심
            bright = (min(255, color[0] + 80), min(255, color[1] + 80), min(255, color[2] + 80))
            pygame.draw.circle(surface, bright, (x, y), size - 1)
            # 하이라이트
            highlight = (min(255, color[0] + 150), min(255, color[1] + 150), min(255, color[2] + 150))
            pygame.draw.circle(surface, highlight, (x - size//3, y - size//3), max(1, size//3))
        else:
            pygame.draw.rect(surface, color, (x - size, y - size, size * 2, size * 2))
            bright = (min(255, color[0] + 80), min(255, color[1] + 80), min(255, color[2] + 80))
            pygame.draw.rect(surface, bright, (x - size + 1, y - size + 1, size * 2 - 2, size * 2 - 2))
    else:
        # 꺼진 LED
        dim = (max(8, color[0] // 15), max(8, color[1] // 15), max(8, color[2] // 15))
        if style == "circle":
            pygame.draw.circle(surface, dim, (x, y), size - 1)
            # 유리 반사
            pygame.draw.circle(surface, (25, 25, 30), (x - size//4, y - size//4), max(1, size//4))
        else:
            pygame.draw.rect(surface, dim, (x - size + 1, y - size + 1, size * 2 - 2, size * 2 - 2))


def draw_slim_digit(surface, x, y, digit, color, height=110, style="circle"):
    """슬림 도트 매트릭스 숫자 (7x11)"""
    pattern = SLIM_PATTERNS_7x11.get(str(digit), SLIM_PATTERNS_7x11['0'])
    rows = 11
    cols = 7
    spacing = height // rows
    dot_size = max(2, spacing // 3)

    for row_idx, row in enumerate(pattern):
        for col_idx, char in enumerate(row):
            dot_x = x + col_idx * spacing + spacing // 2
            dot_y = y + row_idx * spacing + spacing // 2
            draw_premium_led(surface, dot_x, dot_y, color, dot_size, 1.0, char == '1', style)

    # 숫자 너비 반환
    return cols * spacing


def draw_7segment_premium(surface, x, y, digit, color, width=55, height=100, thickness=6):
    """프리미엄 7세그먼트 - 얇고 세련된 버전"""
    segments = SEGMENT_MAP.get(str(digit), [0]*7)

    half_h = height // 2
    t = thickness

    def draw_h_segment(sx, sy, length, on):
        """가로 세그먼트 - 다이아몬드 형태"""
        if on:
            # 글로우 효과
            for i in range(4, 0, -1):
                glow_surf = pygame.Surface((length + 20, t + 16), pygame.SRCALPHA)
                glow_color = (*color, 40 // i)
                points = [
                    (t + 10, t//2 + 8),
                    (t//2 + 10, 8),
                    (length - t//2 + 10, 8),
                    (length - t + 10, t//2 + 8),
                    (length - t//2 + 10, t + 8),
                    (t//2 + 10, t + 8)
                ]
                pygame.draw.polygon(glow_surf, glow_color, points)
                surface.blit(glow_surf, (sx - 10, sy - 8))

            # 메인 세그먼트
            points = [
                (sx + t, sy + t//2),
                (sx + t//2, sy),
                (sx + length - t//2, sy),
                (sx + length - t, sy + t//2),
                (sx + length - t//2, sy + t),
                (sx + t//2, sy + t)
            ]
            pygame.draw.polygon(surface, color, points)
            # 하이라이트
            bright = tuple(min(255, c + 100) for c in color)
            pygame.draw.line(surface, bright, (sx + t, sy + 1), (sx + length - t, sy + 1), 1)
        else:
            dim = tuple(max(5, c // 20) for c in color)
            pygame.draw.line(surface, dim, (sx + t, sy + t//2), (sx + length - t, sy + t//2), 2)

    def draw_v_segment(sx, sy, length, on):
        """세로 세그먼트 - 다이아몬드 형태"""
        if on:
            # 글로우 효과
            for i in range(4, 0, -1):
                glow_surf = pygame.Surface((t + 16, length + 16), pygame.SRCALPHA)
                glow_color = (*color, 40 // i)
                points = [
                    (t//2 + 8, t + 8),
                    (8, t//2 + 8),
                    (8, length - t//2 + 8),
                    (t//2 + 8, length - t + 8),
                    (t + 8, length - t//2 + 8),
                    (t + 8, t//2 + 8)
                ]
                pygame.draw.polygon(glow_surf, glow_color, points)
                surface.blit(glow_surf, (sx - 8, sy - 8))

            # 메인 세그먼트
            points = [
                (sx + t//2, sy + t),
                (sx, sy + t//2),
                (sx, sy + length - t//2),
                (sx + t//2, sy + length - t),
                (sx + t, sy + length - t//2),
                (sx + t, sy + t//2)
            ]
            pygame.draw.polygon(surface, color, points)
            # 하이라이트
            bright = tuple(min(255, c + 100) for c in color)
            pygame.draw.line(surface, bright, (sx + 1, sy + t), (sx + 1, sy + length - t), 1)
        else:
            dim = tuple(max(5, c // 20) for c in color)
            pygame.draw.line(surface, dim, (sx + t//2, sy + t), (sx + t//2, sy + length - t), 2)

    # a: 상단
    draw_h_segment(x, y, width, segments[0])
    # b: 우상
    draw_v_segment(x + width - t, y, half_h, segments[1])
    # c: 우하
    draw_v_segment(x + width - t, y + half_h, half_h, segments[2])
    # d: 하단
    draw_h_segment(x, y + height - t, width, segments[3])
    # e: 좌하
    draw_v_segment(x, y + half_h, half_h, segments[4])
    # f: 좌상
    draw_v_segment(x, y, half_h, segments[5])
    # g: 중앙
    draw_h_segment(x, y + half_h - t//2, width, segments[6])

    return width


def draw_brushed_metal(surface, rect, base_color, direction='h'):
    """브러시드 메탈 효과"""
    x, y, w, h = rect
    for i in range(h if direction == 'h' else w):
        var = random.randint(-6, 6)
        line_color = tuple(max(0, min(255, c + var)) for c in base_color)
        if direction == 'h':
            pygame.draw.line(surface, line_color, (x, y + i), (x + w, y + i))
        else:
            pygame.draw.line(surface, line_color, (x + i, y), (x + i, y + h))


def draw_premium_frame(surface, rect, color, thickness=12):
    """프리미엄 3D 메탈 프레임"""
    x, y, w, h = rect

    # 외부 그림자
    shadow_surf = pygame.Surface((w + 16, h + 16), pygame.SRCALPHA)
    pygame.draw.rect(shadow_surf, (0, 0, 0, 100), (8, 8, w, h), border_radius=6)
    surface.blit(shadow_surf, (x - 4, y - 4))

    # 프레임
    frame_surf = pygame.Surface((w, h), pygame.SRCALPHA)

    # 상단
    draw_brushed_metal(frame_surf, (0, 0, w, thickness), color)
    # 하단
    draw_brushed_metal(frame_surf, (0, h - thickness, w, thickness), color)
    # 좌측
    draw_brushed_metal(frame_surf, (0, 0, thickness, h), color, 'v')
    # 우측
    draw_brushed_metal(frame_surf, (w - thickness, 0, thickness, h), color, 'v')

    surface.blit(frame_surf, (x, y))

    # 하이라이트
    bright = tuple(min(255, c + 60) for c in color)
    pygame.draw.line(surface, bright, (x, y), (x + w - 1, y), 2)
    pygame.draw.line(surface, bright, (x, y), (x, y + h - 1), 2)

    # 그림자
    dark = tuple(max(0, c - 50) for c in color)
    pygame.draw.line(surface, dark, (x + 1, y + h - 1), (x + w, y + h - 1), 3)
    pygame.draw.line(surface, dark, (x + w - 1, y + 1), (x + w - 1, y + h), 3)

    # 볼트
    bolt_pos = [
        (x + thickness//2, y + thickness//2),
        (x + w - thickness//2, y + thickness//2),
        (x + thickness//2, y + h - thickness//2),
        (x + w - thickness//2, y + h - thickness//2)
    ]
    for bx, by in bolt_pos:
        pygame.draw.circle(surface, (40, 45, 55), (bx, by), 6)
        pygame.draw.circle(surface, (70, 75, 85), (bx, by), 4)
        pygame.draw.line(surface, (50, 55, 65), (bx - 3, by), (bx + 3, by), 1)
        pygame.draw.line(surface, (50, 55, 65), (bx, by - 3), (bx, by + 3), 1)
        pygame.draw.circle(surface, (100, 105, 115), (bx - 1, by - 1), 1)


def draw_neon_glow_line(surface, start, end, color, width=2):
    """네온 글로우 라인"""
    for i in range(5, 0, -1):
        glow_surf = pygame.Surface((surface.get_width(), surface.get_height()), pygame.SRCALPHA)
        glow_color = (*color, 40 // i)
        pygame.draw.line(glow_surf, glow_color, start, end, width + i * 2)
        surface.blit(glow_surf, (0, 0))
    pygame.draw.line(surface, color, start, end, width)
    bright = tuple(min(255, c + 100) for c in color)
    pygame.draw.line(surface, bright, start, end, max(1, width - 1))


# ============================================
# 스타일 1: KBO 프리미엄 슬림
# ============================================
def draw_style_1(surface, rect, p_score, b_score, timer):
    """KBO 프리미엄 슬림 - 골드 프레임 + 슬림 LED"""
    x, y, w, h = rect

    # 네이비 배경
    pygame.draw.rect(surface, (8, 12, 28), rect)

    # 골드 프레임
    draw_premium_frame(surface, rect, (100, 90, 65), 14)

    # 내부 LED 패널
    inner = (x + 18, y + 18, w - 36, h - 36)
    pygame.draw.rect(surface, (5, 8, 20), inner)

    # 상단 팀 영역
    header_rect = (x + 26, y + 26, w - 52, 50)
    pygame.draw.rect(surface, (12, 18, 38), header_rect)
    pygame.draw.rect(surface, (200, 170, 80), header_rect, 2)

    # 플레이어 로고
    p_cx = x + 55
    p_cy = y + 51
    for i in range(3, 0, -1):
        glow = pygame.Surface((60, 60), pygame.SRCALPHA)
        pygame.draw.circle(glow, (50, 120, 200, 40//i), (30, 30), 20 + i*3)
        surface.blit(glow, (p_cx - 30, p_cy - 30))
    pygame.draw.circle(surface, (30, 80, 180), (p_cx, p_cy), 20)
    pygame.draw.circle(surface, (80, 140, 255), (p_cx, p_cy), 16)
    p_icon = font_korean.render("P", True, (255, 255, 255))
    surface.blit(p_icon, (p_cx - p_icon.get_width()//2, p_cy - p_icon.get_height()//2))

    # 플레이어 이름
    p_name = font_korean_large.render("플레이어", True, (100, 180, 255))
    surface.blit(p_name, (p_cx + 28, y + 38))

    # 보스 로고
    b_cx = x + w - 55
    b_cy = y + 51
    for i in range(3, 0, -1):
        glow = pygame.Surface((60, 60), pygame.SRCALPHA)
        pygame.draw.circle(glow, (200, 80, 80, 40//i), (30, 30), 20 + i*3)
        surface.blit(glow, (b_cx - 30, b_cy - 30))
    pygame.draw.circle(surface, (180, 50, 50), (b_cx, b_cy), 20)
    pygame.draw.circle(surface, (255, 100, 100), (b_cx, b_cy), 16)
    b_icon = font_korean.render("B", True, (255, 255, 255))
    surface.blit(b_icon, (b_cx - b_icon.get_width()//2, b_cy - b_icon.get_height()//2))

    # 보스 이름
    b_name = font_korean_large.render("보스", True, (255, 120, 120))
    surface.blit(b_name, (b_cx - 28 - b_name.get_width(), y + 38))

    # 점수 영역
    score_rect = (x + 28, y + 82, w - 56, h - 130)
    pygame.draw.rect(surface, (8, 12, 26), score_rect)
    pygame.draw.rect(surface, (180, 150, 70), score_rect, 2)

    center_x = x + w // 2
    pygame.draw.line(surface, (180, 150, 70), (center_x, y + 88), (center_x, y + h - 58), 2)

    # 펄스 효과
    pulse = 0.85 + 0.15 * math.sin(timer * 0.1)

    # 숫자 크기
    digit_h = min(95, score_rect[3] - 20)
    digit_w = 7 * (digit_h // 11)

    # 플레이어 점수
    left_area = center_x - score_rect[0] - 10
    p_x = score_rect[0] + (left_area - digit_w) // 2
    p_y = score_rect[1] + (score_rect[3] - digit_h) // 2
    p_color = (int(80*pulse), int(180*pulse), int(255*pulse))
    draw_slim_digit(surface, p_x, p_y, p_score, p_color, digit_h)

    # 보스 점수
    right_area = score_rect[0] + score_rect[2] - center_x - 10
    b_x = center_x + (right_area - digit_w) // 2 + 10
    b_y = score_rect[1] + (score_rect[3] - digit_h) // 2
    b_color = (int(255*pulse), int(100*pulse), int(100*pulse))
    draw_slim_digit(surface, b_x, b_y, b_score, b_color, digit_h)

    # VS 배지
    vs_x = center_x
    vs_y = score_rect[1] + score_rect[3] // 2
    pygame.draw.rect(surface, (50, 40, 25), (vs_x - 22, vs_y - 16, 44, 32))
    pygame.draw.rect(surface, (200, 170, 80), (vs_x - 22, vs_y - 16, 44, 32), 2)
    vs_text = font_korean.render("VS", True, (255, 220, 120))
    surface.blit(vs_text, (vs_x - vs_text.get_width()//2, vs_y - vs_text.get_height()//2))

    # 하단 정보
    footer_rect = (x + 28, y + h - 48, w - 56, 28)
    pygame.draw.rect(surface, (15, 22, 42), footer_rect)
    pygame.draw.rect(surface, (150, 130, 60), footer_rect, 1)
    info = font_korean.render("◆ 3점 선취 승리 ◆", True, (255, 220, 120))
    surface.blit(info, (x + w//2 - info.get_width()//2, footer_rect[1] + 5))


# ============================================
# 스타일 2: 사이버펑크 네온
# ============================================
def draw_style_2(surface, rect, p_score, b_score, timer):
    """사이버펑크 네온 - 글로우 라인 + 홀로그램 효과"""
    x, y, w, h = rect

    # 다크 배경
    pygame.draw.rect(surface, (5, 5, 12), rect)

    # 네온 테두리 글로우
    colors = [(0, 255, 255), (255, 0, 200)]
    for i, color in enumerate(colors):
        for j in range(4, 0, -1):
            glow_surf = pygame.Surface((w, h), pygame.SRCALPHA)
            glow_color = (*color, 30 // j)
            pygame.draw.rect(glow_surf, glow_color, (0, 0, w, h), 3 + j)
            surface.blit(glow_surf, (x, y))

    pygame.draw.rect(surface, (0, 255, 255), rect, 2)

    # 스캔라인 효과
    for i in range(y, y + h, 4):
        pygame.draw.line(surface, (255, 255, 255, 5), (x, i), (x + w, i), 1)

    # 코너 장식
    corner_size = 15
    corners = [
        [(x, y), (x + corner_size, y), (x, y + corner_size)],
        [(x + w, y), (x + w - corner_size, y), (x + w, y + corner_size)],
        [(x, y + h), (x + corner_size, y + h), (x, y + h - corner_size)],
        [(x + w, y + h), (x + w - corner_size, y + h), (x + w, y + h - corner_size)]
    ]
    for corner in corners:
        pygame.draw.lines(surface, (255, 0, 200), False, corner, 2)

    # 상단 라인
    draw_neon_glow_line(surface, (x + 20, y + 35), (x + w - 20, y + 35), (0, 200, 255), 1)

    # 팀 표시
    p_label = font_korean.render("PLAYER", True, (0, 255, 255))
    surface.blit(p_label, (x + 25, y + 12))
    b_label = font_korean.render("BOSS", True, (255, 0, 200))
    surface.blit(b_label, (x + w - 25 - b_label.get_width(), y + 12))

    center_x = x + w // 2
    score_y = y + 45
    score_h = h - 60

    # 중앙 네온 라인
    draw_neon_glow_line(surface, (center_x, score_y), (center_x, y + h - 15), (150, 0, 255), 2)

    # 펄스
    pulse = 0.8 + 0.2 * math.sin(timer * 0.12)
    flicker = 0.95 + 0.05 * math.sin(timer * 0.5)  # 플리커 효과

    # 숫자 크기
    digit_h = min(90, score_h - 15)
    digit_w = 7 * (digit_h // 11)

    # 플레이어 점수 (시안)
    left_area = center_x - x - 15
    p_x = x + (left_area - digit_w) // 2 + 8
    p_y = score_y + (score_h - digit_h) // 2
    p_color = (int(0*pulse*flicker), int(255*pulse*flicker), int(255*pulse*flicker))
    draw_slim_digit(surface, p_x, p_y, p_score, p_color, digit_h)

    # 보스 점수 (마젠타)
    right_area = x + w - center_x - 15
    b_x = center_x + (right_area - digit_w) // 2 + 8
    b_y = score_y + (score_h - digit_h) // 2
    b_color = (int(255*pulse*flicker), int(0*pulse*flicker), int(200*pulse*flicker))
    draw_slim_digit(surface, b_x, b_y, b_score, b_color, digit_h)

    # VS 글리치 효과
    vs_y = score_y + score_h // 2
    offset = int(2 * math.sin(timer * 0.3))
    vs1 = font_korean.render("VS", True, (255, 0, 0))
    vs2 = font_korean.render("VS", True, (0, 255, 255))
    vs3 = font_korean.render("VS", True, (255, 255, 255))
    surface.blit(vs1, (center_x - vs1.get_width()//2 + offset, vs_y - vs1.get_height()//2))
    surface.blit(vs2, (center_x - vs2.get_width()//2 - offset, vs_y - vs2.get_height()//2))
    surface.blit(vs3, (center_x - vs3.get_width()//2, vs_y - vs3.get_height()//2))


# ============================================
# 스타일 3: 프리미엄 7세그먼트
# ============================================
def draw_style_3(surface, rect, p_score, b_score, timer):
    """프리미엄 7세그먼트 - LCD 스타일"""
    x, y, w, h = rect

    # 다크 그린 LCD 배경
    pygame.draw.rect(surface, (5, 18, 12), rect)

    # 메탈 프레임
    draw_premium_frame(surface, rect, (60, 70, 65), 12)

    # LCD 패널
    lcd_rect = (x + 16, y + 16, w - 32, h - 32)
    pygame.draw.rect(surface, (8, 25, 18), lcd_rect)

    # LCD 내부 글로우
    inner_glow = pygame.Surface((lcd_rect[2], lcd_rect[3]), pygame.SRCALPHA)
    for i in range(20):
        alpha = 30 - i
        pygame.draw.rect(inner_glow, (0, 80, 50, alpha), (i, i, lcd_rect[2] - i*2, lcd_rect[3] - i*2), 1)
    surface.blit(inner_glow, (lcd_rect[0], lcd_rect[1]))

    # 팀 라벨
    p_label = font_korean.render("PLAYER", True, (50, 180, 120))
    b_label = font_korean.render("BOSS", True, (180, 80, 80))
    surface.blit(p_label, (x + 28, y + 22))
    surface.blit(b_label, (x + w - 28 - b_label.get_width(), y + 22))

    center_x = x + w // 2
    score_y = y + 50
    score_h = h - 70

    # 중앙 구분
    pygame.draw.line(surface, (30, 80, 55), (center_x, score_y), (center_x, y + h - 20), 2)

    # 펄스
    pulse = 0.85 + 0.15 * math.sin(timer * 0.1)

    # 7세그먼트 크기
    seg_h = min(85, score_h - 15)
    seg_w = int(seg_h * 0.5)

    # 플레이어 점수
    left_area = center_x - x - 20
    p_x = x + (left_area - seg_w) // 2 + 10
    p_y = score_y + (score_h - seg_h) // 2
    p_color = (int(50*pulse), int(255*pulse), int(180*pulse))
    draw_7segment_premium(surface, p_x, p_y, p_score, p_color, seg_w, seg_h, 5)

    # 보스 점수
    right_area = x + w - center_x - 20
    b_x = center_x + (right_area - seg_w) // 2 + 10
    b_y = score_y + (score_h - seg_h) // 2
    b_color = (int(255*pulse), int(80*pulse), int(80*pulse))
    draw_7segment_premium(surface, b_x, b_y, b_score, b_color, seg_w, seg_h, 5)

    # VS
    vs_y = score_y + score_h // 2
    vs = font_korean.render("VS", True, (100, 200, 150))
    surface.blit(vs, (center_x - vs.get_width()//2, vs_y - vs.get_height()//2))


# ============================================
# 스타일 4: 레트로 아케이드
# ============================================
def draw_style_4(surface, rect, p_score, b_score, timer):
    """레트로 아케이드 - CRT 효과 + 픽셀 느낌"""
    x, y, w, h = rect

    # CRT 배경
    pygame.draw.rect(surface, (2, 2, 8), rect)

    # CRT 베젤
    bezel_color = (35, 30, 25)
    pygame.draw.rect(surface, bezel_color, rect, 10)
    # 베젤 하이라이트
    pygame.draw.line(surface, (60, 55, 50), (x, y), (x + w, y), 2)
    pygame.draw.line(surface, (60, 55, 50), (x, y), (x, y + h), 2)
    pygame.draw.line(surface, (20, 18, 15), (x, y + h), (x + w, y + h), 3)
    pygame.draw.line(surface, (20, 18, 15), (x + w, y), (x + w, y + h), 3)

    # 스캔라인 효과
    for i in range(y + 12, y + h - 12, 2):
        pygame.draw.line(surface, (0, 0, 0, 50), (x + 12, i), (x + w - 12, i), 1)

    # CRT 글로우
    crt_glow = pygame.Surface((w - 24, h - 24), pygame.SRCALPHA)
    for i in range(15):
        alpha = 20 - i
        pygame.draw.rect(crt_glow, (50, 80, 100, alpha), (i, i, w - 24 - i*2, h - 24 - i*2), 1)
    surface.blit(crt_glow, (x + 12, y + 12))

    # 상단 바
    bar_rect = (x + 15, y + 15, w - 30, 35)
    pygame.draw.rect(surface, (20, 15, 30), bar_rect)

    # 팀 이름 (픽셀 스타일)
    p_name = font_korean.render("1P", True, (100, 200, 255))
    b_name = font_korean.render("2P", True, (255, 100, 100))
    surface.blit(p_name, (x + 30, y + 22))
    surface.blit(b_name, (x + w - 50, y + 22))

    # 하이스코어 스타일 라인
    pygame.draw.line(surface, (255, 200, 50), (x + 60, y + 32), (x + w - 60, y + 32), 1)

    center_x = x + w // 2
    score_y = y + 55
    score_h = h - 75

    # 중앙 구분 (점선)
    for i in range(score_y, y + h - 18, 6):
        pygame.draw.line(surface, (80, 70, 100), (center_x, i), (center_x, i + 3), 2)

    # 펄스 + CRT 왜곡
    pulse = 0.9 + 0.1 * math.sin(timer * 0.15)
    distort = math.sin(timer * 0.02) * 0.02

    # 숫자 크기
    digit_h = min(90, score_h - 15)
    digit_w = 7 * (digit_h // 11)

    # 플레이어 점수 (아케이드 블루)
    left_area = center_x - x - 18
    p_x = x + (left_area - digit_w) // 2 + 10
    p_y = score_y + (score_h - digit_h) // 2
    p_color = (int(80*pulse), int(200*pulse), int(255*pulse))
    draw_slim_digit(surface, p_x, p_y, p_score, p_color, digit_h, "square")

    # 보스 점수 (아케이드 레드)
    right_area = x + w - center_x - 18
    b_x = center_x + (right_area - digit_w) // 2 + 8
    b_y = score_y + (score_h - digit_h) // 2
    b_color = (int(255*pulse), int(80*pulse), int(80*pulse))
    draw_slim_digit(surface, b_x, b_y, b_score, b_color, digit_h, "square")

    # VS (레트로 스타일)
    vs_y = score_y + score_h // 2
    vs_bg = pygame.Surface((40, 24), pygame.SRCALPHA)
    pygame.draw.rect(vs_bg, (150, 100, 0), (0, 0, 40, 24))
    surface.blit(vs_bg, (center_x - 20, vs_y - 12))
    vs = font_korean.render("VS", True, (255, 255, 0))
    surface.blit(vs, (center_x - vs.get_width()//2, vs_y - vs.get_height()//2))

    # INSERT COIN 깜빡임
    if timer % 60 < 40:
        coin = font_info.render("ROUND IN PROGRESS", True, (255, 200, 50))
        surface.blit(coin, (x + w//2 - coin.get_width()//2, y + h - 22))


# ============================================
# 스타일 5: 미래형 홀로그램
# ============================================
def draw_style_5(surface, rect, p_score, b_score, timer):
    """미래형 홀로그램 - 투명 + 3D 효과"""
    x, y, w, h = rect

    # 반투명 배경
    bg_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    pygame.draw.rect(bg_surf, (10, 20, 40, 200), (0, 0, w, h))
    surface.blit(bg_surf, (x, y))

    # 홀로그램 테두리
    for i in range(3):
        color = (100 + i*30, 200 + i*20, 255, 150 - i*40)
        border = pygame.Surface((w, h), pygame.SRCALPHA)
        pygame.draw.rect(border, color, (0, 0, w, h), 2 + i)
        surface.blit(border, (x, y))

    # 그리드 라인 효과
    grid_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for i in range(0, w, 20):
        pygame.draw.line(grid_surf, (100, 200, 255, 30), (i, 0), (i, h), 1)
    for i in range(0, h, 20):
        pygame.draw.line(grid_surf, (100, 200, 255, 30), (0, i), (w, i), 1)
    surface.blit(grid_surf, (x, y))

    # 상단 헤더
    header_surf = pygame.Surface((w - 20, 40), pygame.SRCALPHA)
    pygame.draw.rect(header_surf, (50, 100, 150, 150), (0, 0, w - 20, 40))
    surface.blit(header_surf, (x + 10, y + 10))

    # 팀 표시 (홀로그램 효과)
    p_label = font_korean_large.render("플레이어", True, (150, 220, 255))
    b_label = font_korean_large.render("보스", True, (255, 150, 150))
    # 글로우
    for offset in [(1, 1), (-1, -1), (1, -1), (-1, 1)]:
        p_glow = font_korean_large.render("플레이어", True, (100, 180, 255))
        b_glow = font_korean_large.render("보스", True, (255, 100, 100))
        p_glow.set_alpha(80)
        b_glow.set_alpha(80)
        surface.blit(p_glow, (x + 20 + offset[0], y + 18 + offset[1]))
        surface.blit(b_glow, (x + w - 20 - b_label.get_width() + offset[0], y + 18 + offset[1]))
    surface.blit(p_label, (x + 20, y + 18))
    surface.blit(b_label, (x + w - 20 - b_label.get_width(), y + 18))

    center_x = x + w // 2
    score_y = y + 55
    score_h = h - 70

    # 중앙 홀로그램 라인
    for i in range(3):
        line_surf = pygame.Surface((4, score_h), pygame.SRCALPHA)
        pygame.draw.rect(line_surf, (100, 200, 255, 100 - i*30), (i, 0, 2, score_h))
        surface.blit(line_surf, (center_x - 2 + i, score_y))

    # 펄스 + 홀로그램 플리커
    pulse = 0.85 + 0.15 * math.sin(timer * 0.1)
    holo_flicker = 0.9 + 0.1 * math.sin(timer * 0.3) * math.sin(timer * 0.17)

    # 숫자 크기
    digit_h = min(90, score_h - 15)
    digit_w = 7 * (digit_h // 11)

    # 플레이어 점수 (홀로그램 블루)
    left_area = center_x - x - 15
    p_x = x + (left_area - digit_w) // 2 + 8
    p_y = score_y + (score_h - digit_h) // 2

    # 3D 효과 - 여러 레이어
    for layer in range(3, 0, -1):
        layer_color = (int(60*pulse*holo_flicker), int(150*pulse*holo_flicker), int(220*pulse*holo_flicker))
        draw_slim_digit(surface, p_x + layer, p_y + layer, p_score,
                       tuple(max(0, c - layer*30) for c in layer_color), digit_h)
    p_color = (int(100*pulse*holo_flicker), int(200*pulse*holo_flicker), int(255*pulse*holo_flicker))
    draw_slim_digit(surface, p_x, p_y, p_score, p_color, digit_h)

    # 보스 점수 (홀로그램 레드)
    right_area = x + w - center_x - 15
    b_x = center_x + (right_area - digit_w) // 2 + 8
    b_y = score_y + (score_h - digit_h) // 2

    for layer in range(3, 0, -1):
        layer_color = (int(200*pulse*holo_flicker), int(80*pulse*holo_flicker), int(80*pulse*holo_flicker))
        draw_slim_digit(surface, b_x + layer, b_y + layer, b_score,
                       tuple(max(0, c - layer*30) for c in layer_color), digit_h)
    b_color = (int(255*pulse*holo_flicker), int(120*pulse*holo_flicker), int(120*pulse*holo_flicker))
    draw_slim_digit(surface, b_x, b_y, b_score, b_color, digit_h)

    # VS (홀로그램)
    vs_y = score_y + score_h // 2
    vs_surf = pygame.Surface((50, 30), pygame.SRCALPHA)
    pygame.draw.rect(vs_surf, (100, 180, 255, 100), (0, 0, 50, 30))
    surface.blit(vs_surf, (center_x - 25, vs_y - 15))
    vs = font_korean.render("VS", True, (200, 240, 255))
    surface.blit(vs, (center_x - vs.get_width()//2, vs_y - vs.get_height()//2))

    # 하단 상태 바
    status_y = y + h - 25
    status_surf = pygame.Surface((w - 20, 18), pygame.SRCALPHA)
    pygame.draw.rect(status_surf, (50, 100, 150, 120), (0, 0, w - 20, 18))
    surface.blit(status_surf, (x + 10, status_y))

    status = font_info.render("◆ MATCH IN PROGRESS ◆", True, (150, 220, 255))
    surface.blit(status, (x + w//2 - status.get_width()//2, status_y + 2))


def main():
    clock = pygame.time.Clock()
    timer = 0
    p_score, b_score = 2, 1

    styles = [
        ("1. KBO 프리미엄 슬림", draw_style_1),
        ("2. 사이버펑크 네온", draw_style_2),
        ("3. 프리미엄 7세그먼트", draw_style_3),
        ("4. 레트로 아케이드", draw_style_4),
        ("5. 미래형 홀로그램", draw_style_5)
    ]

    # 레이아웃
    board_w, board_h = 290, 200
    positions = [
        (60, 100),
        (355, 100),
        (650, 100),
        (200, 360),
        (510, 360)
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

        # 배경 그라데이션
        for i in range(HEIGHT):
            color = (10 + i//20, 10 + i//25, 20 + i//15)
            pygame.draw.line(screen, color, (0, i), (WIDTH, i))

        # 타이틀
        title = font_title.render("프리미엄 슬림 폰트 전광판 - 5가지 스타일", True, (255, 255, 255))
        screen.blit(title, (WIDTH//2 - title.get_width()//2, 25))

        # 조작 안내
        info = font_info.render("SPACE: 플레이어 점수 증가 / ENTER: 보스 점수 증가 / ESC: 종료", True, (180, 180, 180))
        screen.blit(info, (WIDTH//2 - info.get_width()//2, 60))

        # 각 스타일 그리기
        for i, (name, draw_func) in enumerate(styles):
            px, py = positions[i]

            # 스타일 이름
            name_surf = font_korean.render(name, True, (220, 220, 220))
            screen.blit(name_surf, (px + board_w//2 - name_surf.get_width()//2, py - 25))

            # 전광판
            draw_func(screen, (px, py, board_w, board_h), p_score, b_score, timer)

        # 하단 안내
        bottom = font_korean_large.render("마음에 드는 스타일 번호를 알려주세요!", True, (255, 220, 100))
        screen.blit(bottom, (WIDTH//2 - bottom.get_width()//2, HEIGHT - 50))

        pygame.display.flip()
        clock.tick(60)
        timer += 1

    pygame.quit()


if __name__ == "__main__":
    main()
