#!/usr/bin/env python3
"""
현재 적용중인 라운드 점수 전광판 미리보기
KBO 프리미엄 야구 전광판 스타일
"""

import pygame
import sys
import os
import math
import random

# 현재 디렉토리를 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 상수
WIDTH, HEIGHT = 800, 700

# 색상
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)

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


def draw_slim_digit(surface, x, y, digit, color, size=110, dot_radius=3):
    """슬림 도트 매트릭스 숫자 - 7x11 해상도"""
    patterns = {
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

    pattern = patterns.get(str(digit), patterns['0'])
    rows = 11
    cols = 7
    spacing = size // rows

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


def draw_kbo_scoreboard(screen, player_score, ai_score, animation_timer):
    """KBO 프리미엄 야구 전광판 스타일 점수판"""

    # 점수판 크기 및 위치 설정
    board_width = 680
    board_height = 380
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 내부 영역 계산
    inner_x = board_x + 24
    inner_y = board_y + 24
    inner_w = board_width - 48
    inner_h = board_height - 48

    # 메인 점수판 서피스
    board_surface = pygame.Surface((board_width + 40, board_height + 40), pygame.SRCALPHA)

    # 네이비 배경
    pygame.draw.rect(board_surface, (8, 12, 30), (20, 20, board_width, board_height))

    # 골드 프레임
    draw_premium_frame(board_surface, (20, 20, board_width, board_height), (90, 80, 60), 18)

    # 내부 LED 패널
    pygame.draw.rect(board_surface, (5, 8, 22), (44, 44, inner_w, inner_h))

    # 상단 팀 로고 영역
    header_x = 54
    header_y = 52
    header_w = inner_w - 20
    header_h = 60
    pygame.draw.rect(board_surface, (12, 18, 40), (header_x, header_y, header_w, header_h))
    pygame.draw.rect(board_surface, (200, 170, 80), (header_x, header_y, header_w, header_h), 2)

    # 폰트 로드
    try:
        font_large = pygame.font.Font(None, 60)
        font_medium = pygame.font.Font(None, 36)
    except:
        font_large = pygame.font.SysFont('Arial', 50)
        font_medium = pygame.font.SysFont('Arial', 30)

    # 플레이어 로고 (파란색 원) - 글로우 효과 추가
    p_logo_x = header_x + 50
    p_logo_y = header_y + 30
    # 글로우 효과
    for i in range(4, 0, -1):
        glow_surf = pygame.Surface((70, 70), pygame.SRCALPHA)
        glow_color = (50, 120, 200, 50 // i)
        pygame.draw.circle(glow_surf, glow_color, (35, 35), 22 + i * 4)
        board_surface.blit(glow_surf, (p_logo_x - 35, p_logo_y - 35))
    pygame.draw.circle(board_surface, (30, 80, 180), (p_logo_x, p_logo_y), 22)
    pygame.draw.circle(board_surface, (80, 140, 255), (p_logo_x, p_logo_y), 18)
    pygame.draw.circle(board_surface, (120, 180, 255), (p_logo_x, p_logo_y), 14)
    p_icon = font_medium.render("P", True, WHITE)
    p_icon_rect = p_icon.get_rect(center=(p_logo_x, p_logo_y))
    board_surface.blit(p_icon, p_icon_rect)

    # 플레이어 이름
    p_name = font_large.render("PLAYER", True, (100, 180, 255))
    board_surface.blit(p_name, (header_x + 85, header_y + 12))

    # 보스 로고 (빨간색 원) - 글로우 효과 추가
    b_logo_x = header_x + header_w - 50
    b_logo_y = header_y + 30
    # 글로우 효과
    for i in range(4, 0, -1):
        glow_surf = pygame.Surface((70, 70), pygame.SRCALPHA)
        glow_color = (200, 80, 80, 50 // i)
        pygame.draw.circle(glow_surf, glow_color, (35, 35), 22 + i * 4)
        board_surface.blit(glow_surf, (b_logo_x - 35, b_logo_y - 35))
    pygame.draw.circle(board_surface, (180, 50, 50), (b_logo_x, b_logo_y), 22)
    pygame.draw.circle(board_surface, (255, 100, 100), (b_logo_x, b_logo_y), 18)
    pygame.draw.circle(board_surface, (255, 140, 140), (b_logo_x, b_logo_y), 14)
    b_icon = font_medium.render("B", True, WHITE)
    b_icon_rect = b_icon.get_rect(center=(b_logo_x, b_logo_y))
    board_surface.blit(b_icon, b_icon_rect)

    # 보스 이름
    b_name = font_large.render("BOSS", True, (255, 120, 120))
    b_name_rect = b_name.get_rect(right=header_x + header_w - 85, top=header_y + 12)
    board_surface.blit(b_name, b_name_rect)

    # 점수 영역
    score_area_x = header_x + 5
    score_area_y = header_y + header_h + 15
    score_area_w = header_w - 10
    score_area_h = inner_h - header_h - 70
    pygame.draw.rect(board_surface, (8, 12, 28), (score_area_x, score_area_y, score_area_w, score_area_h))
    pygame.draw.rect(board_surface, (180, 150, 70), (score_area_x, score_area_y, score_area_w, score_area_h), 3)

    # 중앙 분리선
    center_x = 20 + board_width // 2
    pygame.draw.line(board_surface, (180, 150, 70),
                    (center_x, score_area_y + 5), (center_x, score_area_y + score_area_h - 5), 3)

    # LED 점수 (펄스 애니메이션)
    pulse = 0.85 + 0.15 * math.sin(animation_timer * 0.1)
    blue_led = (80, 180, 255)
    red_led = (255, 100, 100)

    # 슬림 LED 크기 계산 (7x11 패턴)
    led_size = min(100, score_area_h - 25)
    dot_radius = max(2, led_size // 35)

    # 슬림 도트 매트릭스 숫자의 실제 크기 계산 (7열 x 11행)
    digit_width = 7 * (led_size // 11)
    digit_height = led_size

    # 왼쪽 영역 (플레이어): score_area_x ~ center_x
    left_area_width = center_x - score_area_x
    # 오른쪽 영역 (보스): center_x ~ score_area_x + score_area_w
    right_area_width = (score_area_x + score_area_w) - center_x

    # 플레이어 점수 - 왼쪽 영역 중앙
    p_score_x = score_area_x + (left_area_width - digit_width) // 2
    p_score_y = score_area_y + (score_area_h - digit_height) // 2
    p_color = (int(blue_led[0]*pulse), int(blue_led[1]*pulse), int(blue_led[2]*pulse))
    draw_slim_digit(board_surface, p_score_x, p_score_y, player_score, p_color, led_size, dot_radius)

    # 보스 점수 - 오른쪽 영역 중앙
    b_score_x = center_x + (right_area_width - digit_width) // 2
    b_score_y = score_area_y + (score_area_h - digit_height) // 2
    b_color = (int(red_led[0]*pulse), int(red_led[1]*pulse), int(red_led[2]*pulse))
    draw_slim_digit(board_surface, b_score_x, b_score_y, ai_score, b_color, led_size, dot_radius)

    # VS 배지
    vs_bg_x = center_x - 28
    vs_bg_y = score_area_y + score_area_h // 2 - 22
    pygame.draw.rect(board_surface, (50, 40, 20), (vs_bg_x, vs_bg_y, 56, 44))
    pygame.draw.rect(board_surface, (200, 170, 80), (vs_bg_x, vs_bg_y, 56, 44), 2)
    vs_text = font_medium.render("VS", True, (255, 220, 120))
    vs_rect = vs_text.get_rect(center=(center_x, score_area_y + score_area_h // 2))
    board_surface.blit(vs_text, vs_rect)

    # 하단 정보
    footer_x = header_x + 5
    footer_y = 44 + inner_h - 52
    footer_w = header_w - 10
    footer_h = 36
    pygame.draw.rect(board_surface, (15, 22, 45), (footer_x, footer_y, footer_w, footer_h))
    pygame.draw.rect(board_surface, (150, 130, 60), (footer_x, footer_y, footer_w, footer_h), 2)

    info_text = font_medium.render("◆ 3 ROUND WIN ◆", True, (255, 220, 120))
    info_rect = info_text.get_rect(center=(20 + board_width // 2, footer_y + footer_h // 2))
    board_surface.blit(info_text, info_rect)

    # 화면에 그리기
    screen.blit(board_surface, (board_x - 20, board_y - 20))


def main():
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("현재 적용중인 라운드 점수 전광판 미리보기")
    clock = pygame.time.Clock()

    # 테스트 점수 세트
    score_sets = [
        (0, 0),
        (1, 0),
        (1, 1),
        (2, 1),
        (2, 2),
        (3, 2),
    ]
    current_set = 0
    animation_timer = 0

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 다음 점수 세트로
                    current_set = (current_set + 1) % len(score_sets)
                elif event.key == pygame.K_LEFT:
                    current_set = (current_set - 1) % len(score_sets)
                elif event.key == pygame.K_RIGHT:
                    current_set = (current_set + 1) % len(score_sets)

        # 배경
        screen.fill((20, 25, 40))

        # 배경 그라데이션 효과
        for y in range(HEIGHT):
            color = (15 + y // 30, 20 + y // 40, 35 + y // 25)
            pygame.draw.line(screen, color, (0, y), (WIDTH, y))

        # 전광판 그리기
        player_score, ai_score = score_sets[current_set]
        draw_kbo_scoreboard(screen, player_score, ai_score, animation_timer)

        # 조작법 안내
        try:
            small_font = pygame.font.Font(None, 24)
        except:
            small_font = pygame.font.SysFont('Arial', 20)

        help_texts = [
            "KBO Premium Baseball Scoreboard Style",
            f"Score: {player_score} - {ai_score}",
            "",
            "Controls:",
            "SPACE / Arrow Keys: Change Score",
            "ESC: Exit"
        ]

        y_offset = 20
        for text in help_texts:
            if text:
                help_surface = small_font.render(text, True, (150, 150, 180))
                screen.blit(help_surface, (20, y_offset))
            y_offset += 22

        pygame.display.flip()
        clock.tick(60)
        animation_timer += 1

    pygame.quit()


if __name__ == "__main__":
    main()
