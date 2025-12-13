#!/usr/bin/env python3
"""
현재 적용중인 라운드 점수 전광판을 PNG로 저장
"""

import pygame
import sys
import os
import math
import random

# 상수
WIDTH, HEIGHT = 800, 700

# 색상
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)

def draw_premium_led(surface, x, y, color, size=5, intensity=1.0, is_on=True):
    """프리미엄 LED 도트"""
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


def draw_slim_digit(surface, x, y, digit, color, size=110, dot_radius=3):
    """슬림 도트 매트릭스 숫자 - 7x11 해상도"""
    patterns = {
        '0': [" 11111 ", "11   11", "11   11", "11   11", "11   11", "11   11", "11   11", "11   11", "11   11", "11   11", " 11111 "],
        '1': ["   11  ", "  111  ", " 1111  ", "   11  ", "   11  ", "   11  ", "   11  ", "   11  ", "   11  ", "   11  ", " 111111"],
        '2': [" 11111 ", "11   11", "     11", "     11", "    11 ", "   11  ", "  11   ", " 11    ", "11     ", "11   11", "1111111"],
        '3': [" 11111 ", "11   11", "     11", "     11", "  1111 ", "     11", "     11", "     11", "     11", "11   11", " 11111 "],
        '4': ["    111", "   1111", "  11 11", " 11  11", "11   11", "11   11", "1111111", "     11", "     11", "     11", "     11"],
        '5': ["1111111", "11     ", "11     ", "11     ", "111111 ", "     11", "     11", "     11", "     11", "11   11", " 11111 "],
        '6': [" 11111 ", "11   11", "11     ", "11     ", "111111 ", "11   11", "11   11", "11   11", "11   11", "11   11", " 11111 "],
        '7': ["1111111", "11   11", "     11", "    11 ", "    11 ", "   11  ", "   11  ", "  11   ", "  11   ", "  11   ", "  11   "],
        '8': [" 11111 ", "11   11", "11   11", "11   11", " 11111 ", "11   11", "11   11", "11   11", "11   11", "11   11", " 11111 "],
        '9': [" 11111 ", "11   11", "11   11", "11   11", " 111111", "     11", "     11", "     11", "     11", "11   11", " 11111 "]
    }
    pattern = patterns.get(str(digit), patterns['0'])
    spacing = size // 11
    for row_idx, row in enumerate(pattern):
        for col_idx, char in enumerate(row):
            dot_x = x + col_idx * spacing + spacing // 2
            dot_y = y + row_idx * spacing + spacing // 2
            draw_premium_led(surface, dot_x, dot_y, color, dot_radius, 1.0, char == '1')


def draw_brushed_metal(surface, rect, base_color=(70, 75, 85), direction='horizontal'):
    """브러시드 메탈 효과"""
    x, y, w, h = rect
    random.seed(42)  # 일관된 패턴
    for i in range(h if direction == 'horizontal' else w):
        variation = random.randint(-8, 8)
        line_color = tuple(max(0, min(255, c + variation)) for c in base_color)
        if direction == 'horizontal':
            pygame.draw.line(surface, line_color, (x, y + i), (x + w, y + i))
        else:
            pygame.draw.line(surface, line_color, (x + i, y), (x + i, y + h))


def draw_premium_frame(surface, rect, frame_color=(75, 80, 90), thickness=18):
    """프리미엄 금속 프레임"""
    x, y, w, h = rect
    shadow = pygame.Surface((w + 20, h + 20), pygame.SRCALPHA)
    pygame.draw.rect(shadow, (0, 0, 0, 80), (10, 10, w, h), border_radius=8)
    surface.blit(shadow, (x - 5, y - 5))
    frame_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    draw_brushed_metal(frame_surf, (0, 0, w, thickness), frame_color)
    draw_brushed_metal(frame_surf, (0, h - thickness, w, thickness), frame_color)
    draw_brushed_metal(frame_surf, (0, 0, thickness, h), frame_color, 'vertical')
    draw_brushed_metal(frame_surf, (w - thickness, 0, thickness, h), frame_color, 'vertical')
    surface.blit(frame_surf, (x, y))
    highlight = tuple(min(255, c + 50) for c in frame_color)
    pygame.draw.line(surface, highlight, (x, y), (x + w - 1, y), 2)
    pygame.draw.line(surface, highlight, (x, y), (x, y + h - 1), 2)
    shadow_color = tuple(max(0, c - 40) for c in frame_color)
    pygame.draw.line(surface, shadow_color, (x + 1, y + h - 1), (x + w, y + h - 1), 3)
    pygame.draw.line(surface, shadow_color, (x + w - 1, y + 1), (x + w - 1, y + h), 3)
    bolt_positions = [(x + thickness//2, y + thickness//2), (x + w - thickness//2, y + thickness//2),
                     (x + thickness//2, y + h - thickness//2), (x + w - thickness//2, y + h - thickness//2)]
    for bx, by in bolt_positions:
        pygame.draw.circle(surface, (40, 45, 50), (bx, by), 8)
        pygame.draw.circle(surface, (60, 65, 70), (bx, by), 6)
        pygame.draw.line(surface, (50, 55, 60), (bx - 4, by), (bx + 4, by), 2)
        pygame.draw.line(surface, (50, 55, 60), (bx, by - 4), (bx, by + 4), 2)
        pygame.draw.circle(surface, (90, 95, 100), (bx - 2, by - 2), 2)


def create_scoreboard_image(player_score, ai_score, filename):
    """점수판 이미지 생성 및 저장"""
    pygame.init()
    screen = pygame.Surface((WIDTH, HEIGHT))

    # 배경 그라데이션
    for y in range(HEIGHT):
        color = (15 + y // 30, 20 + y // 40, 35 + y // 25)
        pygame.draw.line(screen, color, (0, y), (WIDTH, y))

    board_width, board_height = 680, 380
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2
    inner_w, inner_h = board_width - 48, board_height - 48

    board_surface = pygame.Surface((board_width + 40, board_height + 40), pygame.SRCALPHA)
    pygame.draw.rect(board_surface, (8, 12, 30), (20, 20, board_width, board_height))
    draw_premium_frame(board_surface, (20, 20, board_width, board_height), (90, 80, 60), 18)
    pygame.draw.rect(board_surface, (5, 8, 22), (44, 44, inner_w, inner_h))

    # 헤더 영역
    header_x, header_y, header_w, header_h = 54, 52, inner_w - 20, 60
    pygame.draw.rect(board_surface, (12, 18, 40), (header_x, header_y, header_w, header_h))
    pygame.draw.rect(board_surface, (200, 170, 80), (header_x, header_y, header_w, header_h), 2)

    font_large = pygame.font.Font(None, 60)
    font_medium = pygame.font.Font(None, 36)
    font_small = pygame.font.Font(None, 28)

    # 플레이어 로고
    p_logo_x, p_logo_y = header_x + 50, header_y + 30
    for i in range(4, 0, -1):
        glow_surf = pygame.Surface((70, 70), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (50, 120, 200, 50 // i), (35, 35), 22 + i * 4)
        board_surface.blit(glow_surf, (p_logo_x - 35, p_logo_y - 35))
    pygame.draw.circle(board_surface, (30, 80, 180), (p_logo_x, p_logo_y), 22)
    pygame.draw.circle(board_surface, (80, 140, 255), (p_logo_x, p_logo_y), 18)
    pygame.draw.circle(board_surface, (120, 180, 255), (p_logo_x, p_logo_y), 14)
    p_icon = font_medium.render("P", True, WHITE)
    board_surface.blit(p_icon, p_icon.get_rect(center=(p_logo_x, p_logo_y)))
    p_name = font_large.render("PLAYER", True, (100, 180, 255))
    board_surface.blit(p_name, (header_x + 85, header_y + 12))

    # 보스 로고
    b_logo_x, b_logo_y = header_x + header_w - 50, header_y + 30
    for i in range(4, 0, -1):
        glow_surf = pygame.Surface((70, 70), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (200, 80, 80, 50 // i), (35, 35), 22 + i * 4)
        board_surface.blit(glow_surf, (b_logo_x - 35, b_logo_y - 35))
    pygame.draw.circle(board_surface, (180, 50, 50), (b_logo_x, b_logo_y), 22)
    pygame.draw.circle(board_surface, (255, 100, 100), (b_logo_x, b_logo_y), 18)
    pygame.draw.circle(board_surface, (255, 140, 140), (b_logo_x, b_logo_y), 14)
    b_icon = font_medium.render("B", True, WHITE)
    board_surface.blit(b_icon, b_icon.get_rect(center=(b_logo_x, b_logo_y)))
    b_name = font_large.render("BOSS", True, (255, 120, 120))
    board_surface.blit(b_name, b_name.get_rect(right=header_x + header_w - 85, top=header_y + 12))

    # 점수 영역
    score_area_x = header_x + 5
    score_area_y = header_y + header_h + 15
    score_area_w = header_w - 10
    score_area_h = inner_h - header_h - 70
    pygame.draw.rect(board_surface, (8, 12, 28), (score_area_x, score_area_y, score_area_w, score_area_h))
    pygame.draw.rect(board_surface, (180, 150, 70), (score_area_x, score_area_y, score_area_w, score_area_h), 3)

    center_x = 20 + board_width // 2
    pygame.draw.line(board_surface, (180, 150, 70), (center_x, score_area_y + 5), (center_x, score_area_y + score_area_h - 5), 3)

    # LED 점수
    led_size = min(100, score_area_h - 25)
    dot_radius = max(2, led_size // 35)
    digit_width = 7 * (led_size // 11)
    digit_height = led_size
    left_area_width = center_x - score_area_x
    right_area_width = (score_area_x + score_area_w) - center_x

    p_score_x = score_area_x + (left_area_width - digit_width) // 2
    p_score_y = score_area_y + (score_area_h - digit_height) // 2
    draw_slim_digit(board_surface, p_score_x, p_score_y, player_score, (80, 180, 255), led_size, dot_radius)

    b_score_x = center_x + (right_area_width - digit_width) // 2
    b_score_y = score_area_y + (score_area_h - digit_height) // 2
    draw_slim_digit(board_surface, b_score_x, b_score_y, ai_score, (255, 100, 100), led_size, dot_radius)

    # VS 배지
    vs_bg_x = center_x - 28
    vs_bg_y = score_area_y + score_area_h // 2 - 22
    pygame.draw.rect(board_surface, (50, 40, 20), (vs_bg_x, vs_bg_y, 56, 44))
    pygame.draw.rect(board_surface, (200, 170, 80), (vs_bg_x, vs_bg_y, 56, 44), 2)
    vs_text = font_medium.render("VS", True, (255, 220, 120))
    board_surface.blit(vs_text, vs_text.get_rect(center=(center_x, score_area_y + score_area_h // 2)))

    # 하단 정보
    footer_x, footer_y = header_x + 5, 44 + inner_h - 52
    footer_w, footer_h = header_w - 10, 36
    pygame.draw.rect(board_surface, (15, 22, 45), (footer_x, footer_y, footer_w, footer_h))
    pygame.draw.rect(board_surface, (150, 130, 60), (footer_x, footer_y, footer_w, footer_h), 2)
    info_text = font_medium.render("◆ 3 ROUND WIN ◆", True, (255, 220, 120))
    board_surface.blit(info_text, info_text.get_rect(center=(20 + board_width // 2, footer_y + footer_h // 2)))

    screen.blit(board_surface, (board_x - 20, board_y - 20))

    # 타이틀
    title_font = pygame.font.Font(None, 32)
    title = title_font.render(f"KBO Premium Scoreboard - Score: {player_score} vs {ai_score}", True, (180, 180, 200))
    screen.blit(title, (WIDTH // 2 - title.get_width() // 2, 20))

    pygame.image.save(screen, filename)
    print(f"Saved: {filename}")
    pygame.quit()


def main():
    # 다양한 점수 상황 저장
    score_sets = [
        (0, 0, "scoreboard_0_0.png"),
        (1, 0, "scoreboard_1_0.png"),
        (2, 1, "scoreboard_2_1.png"),
        (2, 2, "scoreboard_2_2.png"),
    ]

    output_dir = "/tmp/scoreboard_previews"
    os.makedirs(output_dir, exist_ok=True)

    for p_score, ai_score, filename in score_sets:
        filepath = os.path.join(output_dir, filename)
        create_scoreboard_image(p_score, ai_score, filepath)

    print(f"\n모든 이미지가 {output_dir}에 저장되었습니다.")


if __name__ == "__main__":
    main()
