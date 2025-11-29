#!/usr/bin/env python3
"""
사이버펑크 테두리 스타일 - 5가지 색상 조합
기존 전광판 + 화려한 네온 테두리
"""
import pygame
import math
import random
import sys
import os

WIDTH = 1400
HEIGHT = 800

WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
YELLOW = (255, 220, 0)
RED = (255, 50, 80)
BLUE = (50, 150, 255)
CYAN = (0, 255, 200)
GREEN = (100, 255, 150)
PURPLE = (200, 100, 255)
ORANGE = (255, 150, 50)
MAGENTA = (255, 0, 200)
LIME = (0, 255, 100)

pygame.init()
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("사이버펑크 테두리 전광판")
clock = pygame.time.Clock()

try:
    font_path = os.path.join(os.path.dirname(__file__), "fonts", "NeoDunggeunmoPro-Regular.ttf")
    if os.path.exists(font_path):
        font_huge = pygame.font.Font(font_path, 160)
        font_very_large = pygame.font.Font(font_path, 120)
        font_large = pygame.font.Font(font_path, 80)
        font_medium = pygame.font.Font(font_path, 50)
        font_small = pygame.font.Font(font_path, 32)
        font_tiny = pygame.font.Font(font_path, 24)
    else:
        raise FileNotFoundError
except:
    font_huge = pygame.font.Font(None, 160)
    font_very_large = pygame.font.Font(None, 120)
    font_large = pygame.font.Font(None, 80)
    font_medium = pygame.font.Font(None, 50)
    font_small = pygame.font.Font(None, 32)
    font_tiny = pygame.font.Font(None, 24)


def draw_cyberpunk_border(surface, rect, color1, color2, thickness=8, glow_intensity=0.7, animation_frame=0):
    """사이버펑크 멀티레이어 테두리"""
    x, y, w, h = rect

    # 애니메이션 색상 변화
    pulse = 0.5 + 0.5 * math.sin(animation_frame * 0.05)

    # 레이어 1: 외부 글로우 (color1)
    for i in range(15, 0, -1):
        alpha = int(30 * glow_intensity * (1 - i / 15) * pulse)
        glow_color = (*color1[:3], alpha)
        pygame.draw.rect(surface, glow_color, (x - i, y - i, w + i*2, h + i*2), 2)

    # 레이어 2: 메인 테두리 (color1)
    pygame.draw.rect(surface, color1, (x, y, w, h), thickness)

    # 레이어 3: 내부 테두리 (color2)
    pygame.draw.rect(surface, color2, (x + thickness, y + thickness, w - thickness*2, h - thickness*2), 2)

    # 레이어 4: 추가 악센트 라인
    pygame.draw.line(surface, color2, (x, y), (x + 40, y), 3)
    pygame.draw.line(surface, color2, (x + w - 40, y), (x + w, y), 3)
    pygame.draw.line(surface, color2, (x, y + h), (x + 40, y + h), 3)
    pygame.draw.line(surface, color2, (x + w - 40, y + h), (x + w, y + h), 3)


def draw_cyberpunk_scoreboard(surface, player_score, boss_score, animation_frame, border_color1, border_color2):
    """사이버펑크 테두리가 있는 전광판"""

    # 배경
    pygame.draw.rect(surface, (8, 8, 15), (0, 0, WIDTH, HEIGHT))

    # 메인 보드 영역
    board_rect = pygame.Rect(40, 80, WIDTH-80, HEIGHT-160)

    # 사이버펑크 테두리
    draw_cyberpunk_border(surface, board_rect, border_color1, border_color2,
                         thickness=12, glow_intensity=0.8, animation_frame=animation_frame)

    # 내부 배경
    pygame.draw.rect(surface, (10, 10, 20), board_rect.inflate(-24, -24))

    # 타이틀
    title = font_very_large.render("PING FIGHTER", True, border_color1)
    title_rect = title.get_rect(center=(WIDTH//2, 150))

    # 타이틀 글로우
    for i in range(3):
        glow = font_very_large.render("PING FIGHTER", True, border_color2)
        glow.set_alpha(100 - i*30)
        surface.blit(glow, title_rect.move(i-1, i-1))
    surface.blit(title, title_rect)

    # 점수 영역
    score_y = 300

    # 플레이어 카드
    p_card = pygame.Rect(100, score_y, 500, 350)
    draw_cyberpunk_border(surface, p_card, border_color1, border_color2,
                         thickness=6, glow_intensity=0.6, animation_frame=animation_frame)
    pygame.draw.rect(surface, (15, 15, 25), p_card.inflate(-12, -12))

    # 플레이어 정보
    p_label = font_large.render("PLAYER", True, border_color1)
    surface.blit(p_label, (150, score_y + 30))

    # 플레이어 점수
    p_score = font_huge.render(str(player_score), True, border_color1)
    p_score_rect = p_score.get_rect(center=(350, score_y + 180))

    for i in range(5):
        glow = font_huge.render(str(player_score), True, border_color2)
        glow.set_alpha(80 - i*15)
        surface.blit(glow, p_score_rect.move(i//2, i//2))
    surface.blit(p_score, p_score_rect)

    # 보스 카드
    b_card = pygame.Rect(WIDTH - 600, score_y, 500, 350)
    draw_cyberpunk_border(surface, b_card, border_color2, border_color1,
                         thickness=6, glow_intensity=0.6, animation_frame=animation_frame)
    pygame.draw.rect(surface, (25, 15, 15), b_card.inflate(-12, -12))

    # 보스 정보
    b_label = font_large.render("BOSS", True, border_color2)
    b_label_rect = b_label.get_rect(right=b_card.right - 50, top=score_y + 30)
    surface.blit(b_label, b_label_rect)

    # 보스 점수
    b_score = font_huge.render(str(boss_score), True, border_color2)
    b_score_rect = b_score.get_rect(center=(WIDTH - 300, score_y + 180))

    for i in range(5):
        glow = font_huge.render(str(boss_score), True, border_color1)
        glow.set_alpha(80 - i*15)
        surface.blit(glow, b_score_rect.move(i//2, i//2))
    surface.blit(b_score, b_score_rect)

    # VS 배경
    vs_circle = pygame.Rect(WIDTH//2 - 60, score_y + 100, 120, 120)
    pygame.draw.rect(surface, (20, 10, 20), vs_circle)
    pygame.draw.rect(surface, border_color1, vs_circle, 3)
    pygame.draw.rect(surface, border_color2, vs_circle.inflate(-8, -8), 1)

    vs = font_large.render("VS", True, YELLOW)
    vs_rect = vs.get_rect(center=(WIDTH//2, score_y + 160))
    surface.blit(vs, vs_rect)

    # 하단 정보
    info = font_small.render("⬢ BATTLE READY ⬢", True, border_color1)
    info_rect = info.get_rect(center=(WIDTH//2, HEIGHT - 70))
    pygame.draw.rect(surface, (20, 10, 20), info_rect.inflate(40, 20), border_radius=10)
    pygame.draw.rect(surface, border_color1, info_rect.inflate(40, 20), 2, border_radius=10)
    surface.blit(info, info_rect)


def main():
    current_style = 0

    # 사이버펑크 색상 조합 (color1, color2, 이름)
    styles = [
        ((0, 255, 200), (255, 0, 150), "사이버 시안 - 매직핑크"),  # 1: 시안 + 매직핑크
        ((255, 0, 150), (255, 200, 0), "네온 매그넨타 - 일렉트릭 옐로우"),  # 2: 매그넨타 + 옐로우
        ((0, 255, 100), (255, 0, 200), "네온 라임 - 바이올렛"),  # 3: 라임 + 바이올렛
        ((255, 100, 0), (0, 200, 255), "번닝 오렌지 - 스카이 블루"),  # 4: 오렌지 + 스카이블루
        ((255, 0, 100), (0, 255, 200), "핫 핑크 - 아쿠아 민트"),  # 5: 핫핑크 + 민트
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

        # 현재 스타일 색상
        color1, color2, style_name = styles[current_style]

        # 스코어보드 그리기
        draw_cyberpunk_scoreboard(screen, player_score, boss_score, animation_frame, color1, color2)

        # 안내 텍스트
        guide = font_tiny.render("← → 스타일 | ↑↓ P점수 | W/S 보스점수 | 1-5 선택 | ESC 종료", True, (150, 150, 200))
        screen.blit(guide, (30, 15))

        # 현재 스타일 이름
        style_text = font_medium.render(style_name, True, color1)
        style_rect = style_text.get_rect(center=(WIDTH // 2, HEIGHT - 30))

        # 배경 박스
        bg_rect = style_rect.inflate(40, 20)
        pygame.draw.rect(screen, (20, 10, 20), bg_rect, border_radius=8)
        pygame.draw.rect(screen, color1, bg_rect, 2, border_radius=8)
        pygame.draw.rect(screen, color2, bg_rect, 1, border_radius=8)
        screen.blit(style_text, style_rect)

        pygame.display.flip()
        clock.tick(60)
        animation_frame += 1

    pygame.quit()


if __name__ == "__main__":
    main()
