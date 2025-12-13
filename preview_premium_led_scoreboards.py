#!/usr/bin/env python3
"""
프리미엄 LED 전광판 미리보기 - 5가지 고급 디자인
실제 LED 발광다이오드 효과가 가미된 입체적이고 예술적인 디테일
"""
import pygame
import math
import random
import sys
import os

pygame.init()

# 화면 설정
PREVIEW_WIDTH = 1400
PREVIEW_HEIGHT = 900
screen = pygame.display.set_mode((PREVIEW_WIDTH, PREVIEW_HEIGHT))
pygame.display.set_caption("프리미엄 LED 전광판 미리보기 - 5가지 디자인")

# 색상 정의
COLORS = {
    'deep_space': (8, 12, 25),
    'gold': (255, 200, 80),
    'rose_gold': (220, 160, 140),
    'platinum': (200, 205, 215),
    'neon_blue': (0, 180, 255),
    'neon_pink': (255, 50, 150),
    'emerald': (0, 200, 120),
    'crimson': (220, 50, 70),
    'amber': (255, 170, 50),
    'ice_blue': (150, 220, 255),
}

# =====================================================
# 공통 유틸리티 함수들
# =====================================================

def draw_led_dot(surface, x, y, color, size=4, intensity=1.0, is_on=True, glow_layers=5):
    """고급 LED 도트 - 다층 글로우 효과"""
    if is_on:
        # 외부 글로우 (다층)
        for i in range(glow_layers, 0, -1):
            glow_radius = size + i * 2
            glow_alpha = int(50 * intensity / i)
            glow_surf = pygame.Surface((glow_radius * 4, glow_radius * 4), pygame.SRCALPHA)
            glow_color = (color[0], color[1], color[2], glow_alpha)
            pygame.draw.circle(glow_surf, glow_color, (glow_radius * 2, glow_radius * 2), glow_radius)
            surface.blit(glow_surf, (x - glow_radius * 2, y - glow_radius * 2))

        # LED 바디 (그라데이션 효과)
        pygame.draw.circle(surface, color, (int(x), int(y)), size)

        # 밝은 중심
        bright = (min(255, color[0] + 60), min(255, color[1] + 60), min(255, color[2] + 60))
        pygame.draw.circle(surface, bright, (int(x), int(y)), size - 1)

        # 하이라이트
        highlight = (min(255, color[0] + 120), min(255, color[1] + 120), min(255, color[2] + 120))
        pygame.draw.circle(surface, highlight, (int(x) - size//3, int(y) - size//3), size // 3)
    else:
        # 꺼진 LED (미묘한 반사)
        dim = (max(8, color[0] // 15), max(8, color[1] // 15), max(8, color[2] // 15))
        pygame.draw.circle(surface, dim, (int(x), int(y)), size - 1)


def draw_digit_pattern(surface, x, y, digit, color, size=100, dot_radius=3, animation_frame=0, style='slim'):
    """도트 매트릭스 숫자 패턴"""
    patterns_slim = {
        '0': [" 1111 ", "11  11", "11  11", "11  11", "11  11", "11  11", "11  11", "11  11", " 1111 "],
        '1': ["   11 ", "  111 ", " 1111 ", "   11 ", "   11 ", "   11 ", "   11 ", "   11 ", " 11111"],
        '2': [" 1111 ", "11  11", "    11", "   11 ", "  11  ", " 11   ", "11    ", "11  11", "111111"],
        '3': [" 1111 ", "11  11", "    11", "  111 ", "    11", "    11", "    11", "11  11", " 1111 "],
        '4': ["    11", "   111", "  1111", " 11 11", "11  11", "111111", "    11", "    11", "    11"],
        '5': ["111111", "11    ", "11    ", "11111 ", "    11", "    11", "    11", "11  11", " 1111 "],
        '6': [" 1111 ", "11  11", "11    ", "11111 ", "11  11", "11  11", "11  11", "11  11", " 1111 "],
        '7': ["111111", "11  11", "    11", "   11 ", "   11 ", "  11  ", "  11  ", "  11  ", "  11  "],
        '8': [" 1111 ", "11  11", "11  11", " 1111 ", "11  11", "11  11", "11  11", "11  11", " 1111 "],
        '9': [" 1111 ", "11  11", "11  11", "11  11", " 11111", "    11", "    11", "11  11", " 1111 "]
    }

    pattern = patterns_slim.get(str(digit), patterns_slim['0'])
    rows = len(pattern)
    cols = len(pattern[0]) if pattern else 0
    spacing = size // rows

    for row_idx, row in enumerate(pattern):
        for col_idx, char in enumerate(row):
            dot_x = x + col_idx * spacing + spacing // 2
            dot_y = y + row_idx * spacing + spacing // 2

            # 애니메이션 펄스
            pulse = 0.85 + 0.15 * math.sin(animation_frame * 0.08 + row_idx * 0.2 + col_idx * 0.15)
            pulsed_color = (int(color[0] * pulse), int(color[1] * pulse), int(color[2] * pulse))

            draw_led_dot(surface, dot_x, dot_y, pulsed_color, dot_radius, pulse, char == '1')


def draw_metallic_frame(surface, rect, frame_color, thickness=12, style='brushed'):
    """고급 메탈 프레임"""
    x, y, w, h = rect

    # 그림자
    shadow = pygame.Surface((w + 20, h + 20), pygame.SRCALPHA)
    pygame.draw.rect(shadow, (0, 0, 0, 100), (10, 10, w, h), border_radius=6)
    surface.blit(shadow, (x - 5, y - 5))

    # 프레임 본체
    if style == 'brushed':
        for i in range(h):
            variation = random.randint(-5, 5)
            line_color = tuple(max(0, min(255, c + variation)) for c in frame_color)
            pygame.draw.line(surface, line_color, (x, y + i), (x + thickness, y + i))
            pygame.draw.line(surface, line_color, (x + w - thickness, y + i), (x + w, y + i))
        for i in range(w):
            variation = random.randint(-5, 5)
            line_color = tuple(max(0, min(255, c + variation)) for c in frame_color)
            pygame.draw.line(surface, line_color, (x + i, y), (x + i, y + thickness))
            pygame.draw.line(surface, line_color, (x + i, y + h - thickness), (x + i, y + h))

    # 하이라이트
    highlight = tuple(min(255, c + 40) for c in frame_color)
    pygame.draw.line(surface, highlight, (x, y), (x + w, y), 2)
    pygame.draw.line(surface, highlight, (x, y), (x, y + h), 2)

    # 그림자
    dark = tuple(max(0, c - 30) for c in frame_color)
    pygame.draw.line(surface, dark, (x, y + h), (x + w, y + h), 2)
    pygame.draw.line(surface, dark, (x + w, y), (x + w, y + h), 2)


def draw_rivets(surface, rect, count=4, style='cross'):
    """장식용 리벳/볼트"""
    x, y, w, h = rect
    margin = 15
    positions = [
        (x + margin, y + margin),
        (x + w - margin, y + margin),
        (x + margin, y + h - margin),
        (x + w - margin, y + h - margin)
    ]

    for px, py in positions[:count]:
        pygame.draw.circle(surface, (40, 45, 55), (px, py), 7)
        pygame.draw.circle(surface, (70, 75, 85), (px, py), 5)
        if style == 'cross':
            pygame.draw.line(surface, (50, 55, 65), (px - 3, py), (px + 3, py), 2)
            pygame.draw.line(surface, (50, 55, 65), (px, py - 3), (px, py + 3), 2)
        pygame.draw.arc(surface, (100, 105, 115), (px - 4, py - 4, 8, 8), 0.5, 2.5, 1)


# =====================================================
# 디자인 1: 크리스탈 다이아몬드 전광판
# =====================================================
def draw_crystal_diamond_scoreboard(surface, x, y, width, height, player_name, boss_name,
                                    player_score, boss_score, animation_frame):
    """크리스탈 다이아몬드 전광판 - 보석처럼 빛나는 다이아몬드 컷 LED"""

    # 깊은 보라색 배경
    pygame.draw.rect(surface, (15, 8, 30), (x, y, width, height))

    # 다이아몬드 패턴 배경
    for i in range(0, width, 20):
        for j in range(0, height, 20):
            if (i + j) % 40 == 0:
                alpha = 20 + 10 * math.sin(animation_frame * 0.05 + i * 0.1)
                diamond = pygame.Surface((15, 15), pygame.SRCALPHA)
                pygame.draw.polygon(diamond, (180, 150, 255, int(alpha)),
                                   [(7, 0), (14, 7), (7, 14), (0, 7)])
                surface.blit(diamond, (x + i, y + j))

    # 플래티넘 프레임
    draw_metallic_frame(surface, (x, y, width, height), COLORS['platinum'], 14)
    draw_rivets(surface, (x, y, width, height), 4, 'cross')

    # 내부 보석 테두리
    inner_x, inner_y = x + 20, y + 20
    inner_w, inner_h = width - 40, height - 40
    for i in range(3):
        border_color = (150 + i * 30, 100 + i * 40, 200 + i * 20)
        pygame.draw.rect(surface, border_color, (inner_x + i * 2, inner_y + i * 2,
                                                  inner_w - i * 4, inner_h - i * 4), 1)

    # 상단 헤더 - 크리스탈 바
    header_y = inner_y + 10
    header_h = 50
    header_surf = pygame.Surface((inner_w - 20, header_h), pygame.SRCALPHA)
    for i in range(header_h):
        alpha = 80 + 40 * math.sin(i * 0.15)
        pygame.draw.line(header_surf, (100, 80, 180, int(alpha)), (0, i), (inner_w - 20, i))
    surface.blit(header_surf, (inner_x + 10, header_y))

    # 플레이어 이름 (왼쪽) - 크리스탈 글로우
    font = pygame.font.SysFont("Arial", 28, bold=True)
    for glow in range(3, 0, -1):
        glow_text = font.render(player_name, True, (150, 180, 255))
        glow_text.set_alpha(60 // glow)
        surface.blit(glow_text, (inner_x + 25 + glow, header_y + 12 + glow))
    player_text = font.render(player_name, True, (200, 220, 255))
    surface.blit(player_text, (inner_x + 25, header_y + 12))

    # VS 다이아몬드
    center_x = x + width // 2
    diamond_size = 20
    for i in range(4, 0, -1):
        glow_surf = pygame.Surface((50, 50), pygame.SRCALPHA)
        pygame.draw.polygon(glow_surf, (180, 150, 255, 30 // i),
                           [(25, 5), (45, 25), (25, 45), (5, 25)])
        surface.blit(glow_surf, (center_x - 25, header_y + 5))
    pygame.draw.polygon(surface, (220, 200, 255),
                       [(center_x, header_y + 10), (center_x + 15, header_y + 25),
                        (center_x, header_y + 40), (center_x - 15, header_y + 25)])
    pygame.draw.polygon(surface, (255, 255, 255),
                       [(center_x, header_y + 15), (center_x + 8, header_y + 25),
                        (center_x, header_y + 35), (center_x - 8, header_y + 25)], 1)

    # 보스 이름 (오른쪽) - 루비 글로우
    for glow in range(3, 0, -1):
        glow_text = font.render(boss_name, True, (255, 150, 180))
        glow_text.set_alpha(60 // glow)
        boss_rect = glow_text.get_rect(right=inner_x + inner_w - 25 + glow, top=header_y + 12 + glow)
        surface.blit(glow_text, boss_rect)
    boss_text = font.render(boss_name, True, (255, 200, 220))
    boss_rect = boss_text.get_rect(right=inner_x + inner_w - 25, top=header_y + 12)
    surface.blit(boss_text, boss_rect)

    # 점수 영역
    score_y = header_y + header_h + 20
    score_h = inner_h - header_h - 70

    # 크리스탈 LED 점수
    led_size = min(90, score_h - 10)
    led_x_left = inner_x + 50
    led_x_right = inner_x + inner_w - 50 - led_size // 2
    led_y = score_y + (score_h - led_size) // 2

    # 사파이어 블루 LED (플레이어)
    sapphire = (80, 150, 255)
    draw_digit_pattern(surface, led_x_left, led_y, player_score, sapphire, led_size, 4, animation_frame)

    # 중앙 분리 - 크리스탈 라인
    for i in range(score_y, score_y + score_h, 8):
        pulse = 0.5 + 0.5 * math.sin(animation_frame * 0.1 + i * 0.05)
        color = (int(180 * pulse), int(150 * pulse), int(255 * pulse))
        pygame.draw.circle(surface, color, (center_x, i), 2)

    # 루비 레드 LED (보스)
    ruby = (255, 80, 120)
    draw_digit_pattern(surface, led_x_right, led_y, boss_score, ruby, led_size, 4, animation_frame)

    # 하단 장식 - 크리스탈 스트라이프
    footer_y = inner_y + inner_h - 35
    for i in range(5):
        stripe_alpha = 60 + 20 * math.sin(animation_frame * 0.08 + i * 0.5)
        stripe_color = (150, 120, 220, int(stripe_alpha))
        stripe_surf = pygame.Surface((inner_w - 20, 4), pygame.SRCALPHA)
        stripe_surf.fill(stripe_color)
        surface.blit(stripe_surf, (inner_x + 10, footer_y + i * 5))


# =====================================================
# 디자인 2: 네온 시티 사이버펑크 전광판
# =====================================================
def draw_neon_cyber_scoreboard(surface, x, y, width, height, player_name, boss_name,
                                player_score, boss_score, animation_frame):
    """네온 시티 사이버펑크 전광판 - 홀로그램 효과와 네온 글로우"""

    # 다크 사이버 배경
    pygame.draw.rect(surface, (5, 10, 20), (x, y, width, height))

    # 스캔라인 효과
    for i in range(0, height, 3):
        alpha = 15 + 5 * math.sin(animation_frame * 0.02 + i * 0.1)
        pygame.draw.line(surface, (0, 50, 80, int(alpha)), (x, y + i), (x + width, y + i))

    # 네온 프레임 (다층)
    neon_colors = [(255, 0, 100), (0, 255, 200), (100, 0, 255)]
    for idx, nc in enumerate(neon_colors):
        offset = idx * 3
        for glow in range(5, 0, -1):
            glow_rect = pygame.Rect(x - offset - glow, y - offset - glow,
                                   width + offset * 2 + glow * 2, height + offset * 2 + glow * 2)
            glow_surf = pygame.Surface((glow_rect.width, glow_rect.height), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*nc, 20 // glow), (0, 0, glow_rect.width, glow_rect.height), 3)
            surface.blit(glow_surf, glow_rect.topleft)

    # 코너 사이버 장식
    corner_size = 30
    corners = [(x, y), (x + width - corner_size, y),
               (x, y + height - corner_size), (x + width - corner_size, y + height - corner_size)]
    for cx, cy in corners:
        pygame.draw.line(surface, (0, 255, 200), (cx, cy), (cx + corner_size, cy), 2)
        pygame.draw.line(surface, (0, 255, 200), (cx, cy), (cx, cy + corner_size), 2)
        # 글로우
        for g in range(3):
            glow_surf = pygame.Surface((corner_size + 10, corner_size + 10), pygame.SRCALPHA)
            pygame.draw.line(glow_surf, (0, 255, 200, 30 // (g + 1)), (5, 5), (corner_size + 5, 5), 4)
            pygame.draw.line(glow_surf, (0, 255, 200, 30 // (g + 1)), (5, 5), (5, corner_size + 5), 4)
            surface.blit(glow_surf, (cx - 5, cy - 5))

    # 헤더 - 홀로그램 바
    header_y = y + 25
    header_h = 55

    # 홀로그램 글리치 효과
    glitch_offset = int(3 * math.sin(animation_frame * 0.3))

    # 플레이어 이름 - 시안 네온
    font = pygame.font.SysFont("Consolas", 26, bold=True)
    for glow in range(4, 0, -1):
        glow_surf = font.render(player_name, True, (0, 255, 255))
        glow_surf.set_alpha(40 // glow)
        surface.blit(glow_surf, (x + 35 + glow + glitch_offset, header_y + 15 + glow))
    player_text = font.render(player_name, True, (150, 255, 255))
    surface.blit(player_text, (x + 35 + glitch_offset, header_y + 15))

    # 중앙 - 네온 VS 홀로그램
    center_x = x + width // 2
    # 회전하는 육각형
    angle = animation_frame * 0.05
    hex_points = []
    for i in range(6):
        a = angle + i * math.pi / 3
        hx = center_x + 20 * math.cos(a)
        hy = header_y + 27 + 20 * math.sin(a)
        hex_points.append((hx, hy))

    for glow in range(4, 0, -1):
        glow_surf = pygame.Surface((60, 60), pygame.SRCALPHA)
        adjusted_points = [(p[0] - center_x + 30, p[1] - header_y - 27 + 30) for p in hex_points]
        pygame.draw.polygon(glow_surf, (255, 0, 150, 30 // glow), adjusted_points, 2)
        surface.blit(glow_surf, (center_x - 30, header_y + 27 - 30))

    pygame.draw.polygon(surface, (255, 100, 200), hex_points, 2)
    vs_font = pygame.font.SysFont("Consolas", 18, bold=True)
    vs_text = vs_font.render("VS", True, (255, 200, 255))
    vs_rect = vs_text.get_rect(center=(center_x, header_y + 28))
    surface.blit(vs_text, vs_rect)

    # 보스 이름 - 마젠타 네온
    for glow in range(4, 0, -1):
        glow_surf = font.render(boss_name, True, (255, 0, 150))
        glow_surf.set_alpha(40 // glow)
        boss_rect = glow_surf.get_rect(right=x + width - 35 + glow - glitch_offset, top=header_y + 15 + glow)
        surface.blit(glow_surf, boss_rect)
    boss_text = font.render(boss_name, True, (255, 150, 200))
    boss_rect = boss_text.get_rect(right=x + width - 35 - glitch_offset, top=header_y + 15)
    surface.blit(boss_text, boss_rect)

    # 점수 영역
    score_y = header_y + header_h + 15
    score_h = height - header_h - 100

    # 홀로그램 LED 점수
    led_size = min(95, score_h - 10)
    led_x_left = x + 55
    led_x_right = x + width - 55 - led_size // 2
    led_y = score_y + (score_h - led_size) // 2

    # 시안 LED (플레이어)
    cyan = (0, 255, 220)
    draw_digit_pattern(surface, led_x_left, led_y, player_score, cyan, led_size, 4, animation_frame)

    # 중앙 분리 - 데이터 스트림
    for i in range(0, score_h, 5):
        data_y = score_y + i
        data_alpha = 100 + 50 * math.sin(animation_frame * 0.15 + i * 0.1)
        data_width = 2 + int(3 * random.random())
        pygame.draw.rect(surface, (0, 255, 200, int(data_alpha)),
                        (center_x - 1, data_y, data_width, 3))

    # 마젠타 LED (보스)
    magenta = (255, 50, 150)
    draw_digit_pattern(surface, led_x_right, led_y, boss_score, magenta, led_size, 4, animation_frame)

    # 하단 - 사이버 인포 바
    footer_y = y + height - 40
    pygame.draw.rect(surface, (10, 20, 40), (x + 20, footer_y, width - 40, 25))
    info_font = pygame.font.SysFont("Consolas", 14)
    info_text = info_font.render("◈ FIRST TO 3 WINS ◈", True, (0, 200, 180))
    info_rect = info_text.get_rect(center=(center_x, footer_y + 12))
    surface.blit(info_text, info_rect)


# =====================================================
# 디자인 3: 로얄 골드 럭셔리 전광판
# =====================================================
def draw_royal_gold_scoreboard(surface, x, y, width, height, player_name, boss_name,
                                player_score, boss_score, animation_frame):
    """로얄 골드 럭셔리 전광판 - 금박 장식과 고급스러운 LED"""

    # 진한 버건디 배경
    pygame.draw.rect(surface, (35, 10, 15), (x, y, width, height))

    # 다마스크 패턴 (고급 벽지 느낌)
    pattern_surf = pygame.Surface((width, height), pygame.SRCALPHA)
    for i in range(0, width, 40):
        for j in range(0, height, 40):
            damask_alpha = 25 + 10 * math.sin(i * 0.05 + j * 0.05)
            pygame.draw.circle(pattern_surf, (80, 40, 50, int(damask_alpha)), (i + 20, j + 20), 15, 1)
            pygame.draw.circle(pattern_surf, (80, 40, 50, int(damask_alpha)), (i + 20, j + 20), 8, 1)
    surface.blit(pattern_surf, (x, y))

    # 골드 프레임 (다층 금박 효과)
    for layer in range(3):
        offset = layer * 4
        gold_shade = (200 - layer * 30, 160 - layer * 30, 60 - layer * 15)
        pygame.draw.rect(surface, gold_shade, (x + offset, y + offset,
                                               width - offset * 2, height - offset * 2), 4 - layer)

    # 금박 코너 장식
    corner_detail_size = 45
    corner_positions = [(x + 5, y + 5), (x + width - corner_detail_size - 5, y + 5),
                       (x + 5, y + height - corner_detail_size - 5),
                       (x + width - corner_detail_size - 5, y + height - corner_detail_size - 5)]

    for cx, cy in corner_positions:
        # 복잡한 금박 모티프
        for r in range(20, 5, -5):
            alpha = 150 - r * 5
            pygame.draw.circle(surface, (255, 200, 80, alpha), (cx + corner_detail_size//2, cy + corner_detail_size//2), r, 1)
        # 중심 보석
        pygame.draw.circle(surface, (180, 50, 60), (cx + corner_detail_size//2, cy + corner_detail_size//2), 6)
        pygame.draw.circle(surface, (255, 100, 120), (cx + corner_detail_size//2, cy + corner_detail_size//2), 4)
        pygame.draw.circle(surface, (255, 200, 200), (cx + corner_detail_size//2 - 2, cy + corner_detail_size//2 - 2), 2)

    # 헤더 - 골드 명판
    header_y = y + 30
    header_h = 55
    header_x = x + 25
    header_w = width - 50

    # 금속 명판 효과
    for i in range(header_h):
        shade = 160 + int(30 * math.sin(i * 0.2))
        pygame.draw.line(surface, (shade, shade - 30, shade - 80),
                        (header_x, header_y + i), (header_x + header_w, header_y + i))
    pygame.draw.rect(surface, (200, 170, 80), (header_x, header_y, header_w, header_h), 3)

    # 플레이어 이름 - 금색 각인
    font = pygame.font.SysFont("Times New Roman", 30, bold=True)
    # 엠보싱 효과
    shadow_text = font.render(player_name, True, (100, 80, 40))
    surface.blit(shadow_text, (header_x + 22, header_y + 14))
    player_text = font.render(player_name, True, (255, 220, 150))
    surface.blit(player_text, (header_x + 20, header_y + 12))

    # 중앙 왕관 장식
    center_x = x + width // 2
    crown_y = header_y + 5
    # 왕관 모양
    crown_points = [
        (center_x - 18, header_y + header_h - 10),
        (center_x - 22, crown_y + 20),
        (center_x - 12, crown_y + 10),
        (center_x, crown_y),
        (center_x + 12, crown_y + 10),
        (center_x + 22, crown_y + 20),
        (center_x + 18, header_y + header_h - 10)
    ]
    # 글로우
    for g in range(3, 0, -1):
        glow_surf = pygame.Surface((60, 60), pygame.SRCALPHA)
        adjusted = [(p[0] - center_x + 30, p[1] - crown_y + 10) for p in crown_points]
        pygame.draw.polygon(glow_surf, (255, 200, 100, 40 // g), adjusted)
        surface.blit(glow_surf, (center_x - 30, crown_y - 10))

    pygame.draw.polygon(surface, (255, 200, 80), crown_points)
    pygame.draw.polygon(surface, (255, 230, 150), crown_points, 2)
    # 보석 장식
    pygame.draw.circle(surface, (200, 50, 50), (center_x, crown_y + 20), 5)
    pygame.draw.circle(surface, (255, 100, 100), (center_x, crown_y + 20), 3)

    # 보스 이름 - 금색 각인
    shadow_text = font.render(boss_name, True, (100, 80, 40))
    boss_rect = shadow_text.get_rect(right=header_x + header_w - 18, top=header_y + 14)
    surface.blit(shadow_text, boss_rect)
    boss_text = font.render(boss_name, True, (255, 220, 150))
    boss_rect = boss_text.get_rect(right=header_x + header_w - 20, top=header_y + 12)
    surface.blit(boss_text, boss_rect)

    # 점수 영역 - 벨벳 배경
    score_y = header_y + header_h + 20
    score_h = height - header_h - 110
    score_area = (x + 30, score_y, width - 60, score_h)
    pygame.draw.rect(surface, (25, 8, 12), score_area)
    pygame.draw.rect(surface, (180, 140, 60), score_area, 2)

    # 골드 LED 점수
    led_size = min(100, score_h - 20)
    led_x_left = x + 60
    led_x_right = x + width - 60 - led_size // 2
    led_y = score_y + (score_h - led_size) // 2

    # 로얄 블루 LED (플레이어)
    royal_blue = (80, 120, 200)
    draw_digit_pattern(surface, led_x_left, led_y, player_score, royal_blue, led_size, 5, animation_frame)

    # 중앙 장식 - 금박 라인
    ornament_surf = pygame.Surface((20, score_h), pygame.SRCALPHA)
    for i in range(0, score_h, 8):
        pulse = 0.7 + 0.3 * math.sin(animation_frame * 0.1 + i * 0.08)
        color = (int(255 * pulse), int(200 * pulse), int(80 * pulse), 200)
        pygame.draw.circle(ornament_surf, color, (10, i), 3)
    surface.blit(ornament_surf, (center_x - 10, score_y))

    # 크림슨 레드 LED (보스)
    crimson = (220, 60, 80)
    draw_digit_pattern(surface, led_x_right, led_y, boss_score, crimson, led_size, 5, animation_frame)

    # 하단 - 금박 문구
    footer_y = y + height - 45
    footer_font = pygame.font.SysFont("Times New Roman", 18, bold=True)
    footer_text = footer_font.render("❖ 3점 선취 승리 ❖", True, (255, 200, 100))
    footer_rect = footer_text.get_rect(center=(center_x, footer_y + 15))
    surface.blit(footer_text, footer_rect)


# =====================================================
# 디자인 4: 아이스 오로라 전광판
# =====================================================
def draw_ice_aurora_scoreboard(surface, x, y, width, height, player_name, boss_name,
                                player_score, boss_score, animation_frame):
    """아이스 오로라 전광판 - 북극 오로라와 얼음 결정 LED"""

    # 깊은 남색 배경
    pygame.draw.rect(surface, (5, 15, 35), (x, y, width, height))

    # 오로라 효과 (물결치는 빛)
    aurora_colors = [(0, 255, 150, 30), (0, 200, 255, 25), (150, 100, 255, 20)]
    for idx, ac in enumerate(aurora_colors):
        wave_offset = animation_frame * 0.03 + idx * 0.5
        for i in range(0, width, 5):
            wave_y = 30 * math.sin(i * 0.02 + wave_offset) + height // 3 + idx * 40
            aurora_surf = pygame.Surface((8, 80), pygame.SRCALPHA)
            for j in range(80):
                alpha = ac[3] * (1 - j / 80)
                pygame.draw.line(aurora_surf, (ac[0], ac[1], ac[2], int(alpha)), (0, j), (8, j))
            surface.blit(aurora_surf, (x + i, y + wave_y - 40))

    # 얼음 결정 프레임
    ice_color = (180, 220, 255)
    dark_ice = (80, 120, 180)

    # 외부 프레임
    pygame.draw.rect(surface, ice_color, (x, y, width, height), 3)
    pygame.draw.rect(surface, dark_ice, (x + 4, y + 4, width - 8, height - 8), 2)

    # 결정 코너 장식
    crystal_size = 35
    corners = [(x, y), (x + width - crystal_size, y),
               (x, y + height - crystal_size), (x + width - crystal_size, y + height - crystal_size)]

    for cx, cy in corners:
        # 육각 결정
        hex_points = []
        for i in range(6):
            angle = i * math.pi / 3 + animation_frame * 0.02
            hx = cx + crystal_size // 2 + 15 * math.cos(angle)
            hy = cy + crystal_size // 2 + 15 * math.sin(angle)
            hex_points.append((hx, hy))
        pygame.draw.polygon(surface, (200, 230, 255, 150), hex_points)
        pygame.draw.polygon(surface, (255, 255, 255), hex_points, 1)
        # 내부 패턴
        for i in range(3):
            pygame.draw.line(surface, (220, 240, 255), hex_points[i], hex_points[i + 3], 1)

    # 헤더 - 얼음 명판
    header_y = y + 25
    header_h = 50
    header_x = x + 20
    header_w = width - 40

    # 얼음 텍스처
    ice_surf = pygame.Surface((header_w, header_h), pygame.SRCALPHA)
    for i in range(header_w):
        for j in range(header_h):
            noise = random.randint(-10, 10)
            color = (100 + noise, 140 + noise, 180 + noise, 180)
            ice_surf.set_at((i, j), color)
    surface.blit(ice_surf, (header_x, header_y))
    pygame.draw.rect(surface, (200, 230, 255), (header_x, header_y, header_w, header_h), 2)

    # 플레이어 이름 - 시안 글로우
    font = pygame.font.SysFont("Helvetica", 26, bold=True)
    for glow in range(3, 0, -1):
        glow_text = font.render(player_name, True, (0, 200, 255))
        glow_text.set_alpha(50 // glow)
        surface.blit(glow_text, (header_x + 17 + glow, header_y + 13 + glow))
    player_text = font.render(player_name, True, (200, 240, 255))
    surface.blit(player_text, (header_x + 15, header_y + 11))

    # 중앙 - 눈결정
    center_x = x + width // 2
    snowflake_size = 18
    for i in range(6):
        angle = i * math.pi / 3 + animation_frame * 0.03
        # 주 가지
        end_x = center_x + snowflake_size * math.cos(angle)
        end_y = header_y + 25 + snowflake_size * math.sin(angle)
        pygame.draw.line(surface, (255, 255, 255), (center_x, header_y + 25), (end_x, end_y), 2)
        # 작은 가지
        mid_x = center_x + snowflake_size * 0.6 * math.cos(angle)
        mid_y = header_y + 25 + snowflake_size * 0.6 * math.sin(angle)
        for branch_angle in [angle + 0.5, angle - 0.5]:
            branch_x = mid_x + 8 * math.cos(branch_angle)
            branch_y = mid_y + 8 * math.sin(branch_angle)
            pygame.draw.line(surface, (200, 230, 255), (mid_x, mid_y), (branch_x, branch_y), 1)

    # 보스 이름 - 보라 글로우
    for glow in range(3, 0, -1):
        glow_text = font.render(boss_name, True, (180, 100, 255))
        glow_text.set_alpha(50 // glow)
        boss_rect = glow_text.get_rect(right=header_x + header_w - 15 + glow, top=header_y + 13 + glow)
        surface.blit(glow_text, boss_rect)
    boss_text = font.render(boss_name, True, (220, 180, 255))
    boss_rect = boss_text.get_rect(right=header_x + header_w - 15, top=header_y + 11)
    surface.blit(boss_text, boss_rect)

    # 점수 영역
    score_y = header_y + header_h + 20
    score_h = height - header_h - 100

    # 얼음 LED 점수
    led_size = min(95, score_h - 10)
    led_x_left = x + 50
    led_x_right = x + width - 50 - led_size // 2
    led_y = score_y + (score_h - led_size) // 2

    # 아이스 블루 LED (플레이어)
    ice_blue = (100, 200, 255)
    draw_digit_pattern(surface, led_x_left, led_y, player_score, ice_blue, led_size, 4, animation_frame)

    # 중앙 - 얼음 결정 라인
    for i in range(score_y, score_y + score_h, 10):
        crystal_pulse = 0.5 + 0.5 * math.sin(animation_frame * 0.08 + i * 0.1)
        size = 3 + int(2 * crystal_pulse)
        color = (int(200 * crystal_pulse), int(230 * crystal_pulse), 255)
        # 육각형
        for j in range(6):
            angle = j * math.pi / 3
            px = center_x + size * math.cos(angle)
            py = i + size * math.sin(angle)
            pygame.draw.line(surface, color, (center_x, i), (px, py), 1)

    # 오로라 퍼플 LED (보스)
    aurora_purple = (180, 100, 255)
    draw_digit_pattern(surface, led_x_right, led_y, boss_score, aurora_purple, led_size, 4, animation_frame)

    # 하단 - 얼음 인포
    footer_y = y + height - 40
    footer_font = pygame.font.SysFont("Helvetica", 16)
    footer_text = footer_font.render("❄ 3점 선취 승리 ❄", True, (180, 220, 255))
    footer_rect = footer_text.get_rect(center=(center_x, footer_y + 12))
    surface.blit(footer_text, footer_rect)


# =====================================================
# 디자인 5: 인페르노 화염 전광판
# =====================================================
def draw_inferno_flame_scoreboard(surface, x, y, width, height, player_name, boss_name,
                                   player_score, boss_score, animation_frame):
    """인페르노 화염 전광판 - 지옥불 효과와 용암 LED"""

    # 어두운 용암 배경
    pygame.draw.rect(surface, (20, 5, 5), (x, y, width, height))

    # 용암 텍스처
    for i in range(0, width, 6):
        for j in range(0, height, 6):
            noise = math.sin(i * 0.08 + animation_frame * 0.04) * math.cos(j * 0.06 + animation_frame * 0.03)
            noise += math.sin((i + j) * 0.04 + animation_frame * 0.06) * 0.5
            intensity = (noise + 1) / 2

            if intensity > 0.75:
                g_val = max(0, min(255, 200 + int(55 * noise)))
                color = (255, g_val, 100)
            elif intensity > 0.5:
                g_val = max(0, min(255, 120 + int(60 * intensity)))
                color = (255, g_val, 30)
            elif intensity > 0.25:
                r_val = max(0, min(255, 180 + int(40 * intensity)))
                color = (r_val, 50, 15)
            else:
                r_val = max(0, min(255, 80 + int(40 * intensity)))
                color = (r_val, 20, 8)

            pygame.draw.rect(surface, color, (x + i, y + j, 6, 6))

    # 어두운 오버레이
    dark_overlay = pygame.Surface((width, height), pygame.SRCALPHA)
    dark_overlay.fill((0, 0, 0, 160))
    surface.blit(dark_overlay, (x, y))

    # 화염 프레임
    fire_colors = [(255, 200, 80), (255, 120, 40), (200, 50, 20)]
    for idx, fc in enumerate(fire_colors):
        offset = idx * 2
        pygame.draw.rect(surface, fc, (x + offset, y + offset,
                                       width - offset * 2, height - offset * 2), 3 - idx)

    # 상단 화염 효과
    for i in range(0, width, 12):
        flame_height = 25 + 15 * math.sin(animation_frame * 0.1 + i * 0.2) + random.randint(-5, 5)
        for layer in range(3):
            fy = y - flame_height * (1 - layer * 0.3)
            size = 8 - layer * 2
            # 화염 색상
            colors = [(255, 255, 200), (255, 180, 80), (255, 100, 40)]
            color = colors[min(layer, 2)]

            # 글로우
            for g in range(3, 0, -1):
                glow_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*color, 40 // g), (size * 2, size * 2), size + g * 2)
                surface.blit(glow_surf, (x + i - size * 2, fy - size * 2))
            pygame.draw.circle(surface, color, (x + i, int(fy)), size)

    # 헤더 - 용암 명판
    header_y = y + 30
    header_h = 50
    header_x = x + 25
    header_w = width - 50

    # 뜨거운 금속 효과
    metal_surf = pygame.Surface((header_w, header_h), pygame.SRCALPHA)
    for i in range(header_h):
        heat = 0.5 + 0.5 * math.sin(i * 0.15 + animation_frame * 0.05)
        r = int(100 + 100 * heat)
        g = int(40 + 40 * heat)
        pygame.draw.line(metal_surf, (r, g, 20, 200), (0, i), (header_w, i))
    surface.blit(metal_surf, (header_x, header_y))
    pygame.draw.rect(surface, (255, 150, 50), (header_x, header_y, header_w, header_h), 2)

    # 플레이어 이름 - 오렌지 글로우
    font = pygame.font.SysFont("Impact", 28)
    for glow in range(4, 0, -1):
        glow_text = font.render(player_name, True, (255, 150, 50))
        glow_text.set_alpha(50 // glow)
        surface.blit(glow_text, (header_x + 17 + glow, header_y + 12 + glow))
    player_text = font.render(player_name, True, (255, 220, 150))
    surface.blit(player_text, (header_x + 15, header_y + 10))

    # 중앙 - 화염 원
    center_x = x + width // 2
    for ring in range(4, 0, -1):
        ring_color = (255, 100 + ring * 30, ring * 20)
        pygame.draw.circle(surface, ring_color, (center_x, header_y + 25), 15 + ring * 4, 2)
    pygame.draw.circle(surface, (80, 30, 15), (center_x, header_y + 25), 14)
    pygame.draw.circle(surface, (255, 200, 100), (center_x, header_y + 25), 12, 2)

    vs_font = pygame.font.SysFont("Impact", 16)
    vs_text = vs_font.render("VS", True, (255, 200, 150))
    vs_rect = vs_text.get_rect(center=(center_x, header_y + 26))
    surface.blit(vs_text, vs_rect)

    # 보스 이름 - 레드 글로우
    for glow in range(4, 0, -1):
        glow_text = font.render(boss_name, True, (255, 80, 50))
        glow_text.set_alpha(50 // glow)
        boss_rect = glow_text.get_rect(right=header_x + header_w - 15 + glow, top=header_y + 12 + glow)
        surface.blit(glow_text, boss_rect)
    boss_text = font.render(boss_name, True, (255, 180, 150))
    boss_rect = boss_text.get_rect(right=header_x + header_w - 15, top=header_y + 10)
    surface.blit(boss_text, boss_rect)

    # 점수 영역
    score_y = header_y + header_h + 20
    score_h = height - header_h - 100
    score_area = (x + 25, score_y, width - 50, score_h)
    pygame.draw.rect(surface, (30, 10, 8), score_area)
    pygame.draw.rect(surface, (200, 100, 40), score_area, 2)

    # 용암 LED 점수
    led_size = min(100, score_h - 15)
    led_x_left = x + 55
    led_x_right = x + width - 55 - led_size // 2
    led_y = score_y + (score_h - led_size) // 2

    # 앰버 LED (플레이어)
    amber = (255, 180, 80)
    draw_digit_pattern(surface, led_x_left, led_y, player_score, amber, led_size, 5, animation_frame)

    # 중앙 - 불씨 파티클
    for i in range(score_y, score_y + score_h, 8):
        ember_x = center_x + random.randint(-3, 3)
        ember_y = i + int(5 * math.sin(animation_frame * 0.1 + i * 0.1))
        ember_size = 2 + random.random() * 2
        ember_alpha = 150 + int(100 * random.random())
        ember_color = random.choice([(255, 200, 100), (255, 150, 50), (255, 100, 30)])

        glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*ember_color, ember_alpha // 2), (10, 10), int(ember_size * 2))
        pygame.draw.circle(glow_surf, (*ember_color, ember_alpha), (10, 10), int(ember_size))
        surface.blit(glow_surf, (ember_x - 10, ember_y - 10))

    # 크림슨 LED (보스)
    crimson_fire = (255, 60, 40)
    draw_digit_pattern(surface, led_x_right, led_y, boss_score, crimson_fire, led_size, 5, animation_frame)

    # 하단 - 화염 인포
    footer_y = y + height - 40
    footer_font = pygame.font.SysFont("Impact", 16)
    footer_text = footer_font.render("🔥 BURN TO WIN 🔥", True, (255, 180, 100))
    footer_rect = footer_text.get_rect(center=(center_x, footer_y + 12))
    surface.blit(footer_text, footer_rect)


# =====================================================
# 메인 미리보기 루프
# =====================================================
def main():
    clock = pygame.time.Clock()
    running = True
    animation_frame = 0

    # 샘플 데이터
    player_name = "플레이어"
    boss_name = "아마테라스"
    player_score = 2
    boss_score = 1

    # 전광판 레이아웃
    board_width = 520
    board_height = 320
    margin = 30

    # 2행 3열 배치 (5개 + 빈 공간)
    positions = [
        (margin, 50),  # 1
        (margin + board_width + margin, 50),  # 2
        (margin, 50 + board_height + margin),  # 3
        (margin + board_width + margin, 50 + board_height + margin),  # 4
        (margin + board_width // 2 + margin // 2, 50 + (board_height + margin) * 2),  # 5
    ]

    titles = [
        "1. 크리스탈 다이아몬드",
        "2. 네온 시티 사이버펑크",
        "3. 로얄 골드 럭셔리",
        "4. 아이스 오로라",
        "5. 인페르노 화염"
    ]

    draw_functions = [
        draw_crystal_diamond_scoreboard,
        draw_neon_cyber_scoreboard,
        draw_royal_gold_scoreboard,
        draw_ice_aurora_scoreboard,
        draw_inferno_flame_scoreboard
    ]

    font = pygame.font.SysFont("Arial", 20, bold=True)
    title_font = pygame.font.SysFont("Arial", 32, bold=True)

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 점수 변경
                    player_score = (player_score + 1) % 10
                elif event.key == pygame.K_RETURN:
                    boss_score = (boss_score + 1) % 10

        # 배경
        screen.fill((15, 15, 25))

        # 타이틀
        main_title = title_font.render("프리미엄 LED 전광판 미리보기 - ESC: 종료, SPACE: 플레이어 점수, ENTER: 보스 점수",
                                       True, (200, 200, 220))
        screen.blit(main_title, (30, 10))

        # 각 전광판 그리기
        for idx, (pos, title, draw_func) in enumerate(zip(positions, titles, draw_functions)):
            # 제목
            title_text = font.render(title, True, (180, 180, 200))
            screen.blit(title_text, (pos[0], pos[1] - 25))

            # 전광판
            draw_func(screen, pos[0], pos[1], board_width, board_height,
                     player_name, boss_name, player_score, boss_score, animation_frame)

        pygame.display.flip()
        clock.tick(60)
        animation_frame += 1

    pygame.quit()


if __name__ == "__main__":
    main()
