#!/usr/bin/env python3
"""
사이버펑크 테두리 전광판 - 5가지 색상 조합 이미지 저장
"""
import pygame
import math
import os

WIDTH = 1400
HEIGHT = 800

WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
YELLOW = (255, 220, 0)

pygame.init()

try:
    font_path = os.path.join(os.path.dirname(__file__), "fonts", "NeoDunggeunmoPro-Regular.ttf")
    if os.path.exists(font_path):
        font_huge = pygame.font.Font(font_path, 160)
        font_very_large = pygame.font.Font(font_path, 120)
        font_large = pygame.font.Font(font_path, 80)
        font_medium = pygame.font.Font(font_path, 50)
        font_small = pygame.font.Font(font_path, 32)
    else:
        raise FileNotFoundError
except:
    font_huge = pygame.font.Font(None, 160)
    font_very_large = pygame.font.Font(None, 120)
    font_large = pygame.font.Font(None, 80)
    font_medium = pygame.font.Font(None, 50)
    font_small = pygame.font.Font(None, 32)


def draw_neon_glow_rect(surface, rect, color, glow_layers=12, thickness=4):
    """네온 글로우 사각형"""
    x, y, w, h = rect

    # 글로우 레이어
    for i in range(glow_layers, 0, -1):
        alpha = int(60 * (1 - i / glow_layers))
        glow_surf = pygame.Surface((w + i*4, h + i*4), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*color, alpha), (0, 0, w + i*4, h + i*4), thickness + i//2, border_radius=10)
        surface.blit(glow_surf, (x - i*2, y - i*2))

    # 메인 테두리
    pygame.draw.rect(surface, color, rect, thickness, border_radius=10)


def draw_cyberpunk_scoreboard(surface, player_score, boss_score, color1, color2, style_name):
    """사이버펑크 테두리 전광판"""

    # 어두운 배경
    surface.fill((5, 5, 12))

    # 메인 프레임
    main_rect = (50, 80, WIDTH - 100, HEIGHT - 160)

    # 외부 테두리 (color1)
    draw_neon_glow_rect(surface, main_rect, color1, glow_layers=15, thickness=6)

    # 내부 테두리 (color2)
    inner_rect = (60, 90, WIDTH - 120, HEIGHT - 180)
    pygame.draw.rect(surface, color2, inner_rect, 2, border_radius=8)

    # 내부 배경
    pygame.draw.rect(surface, (8, 8, 18), (70, 100, WIDTH - 140, HEIGHT - 200), border_radius=5)

    # 타이틀
    title = font_very_large.render("PING FIGHTER", True, color1)
    title_rect = title.get_rect(center=(WIDTH//2, 160))

    # 타이틀 글로우
    for i in range(4):
        glow = font_very_large.render("PING FIGHTER", True, color2)
        glow.set_alpha(80 - i*20)
        surface.blit(glow, title_rect.move(i, i))
    surface.blit(title, title_rect)

    # 플레이어 카드
    p_card = (100, 280, 480, 380)
    draw_neon_glow_rect(surface, p_card, color1, glow_layers=10, thickness=4)
    pygame.draw.rect(surface, (12, 12, 22), (108, 288, 464, 364), border_radius=8)

    # 플레이어 라벨
    p_label = font_large.render("PLAYER", True, color1)
    surface.blit(p_label, (160, 310))

    # 플레이어 점수
    p_score = font_huge.render(str(player_score), True, color1)
    p_score_rect = p_score.get_rect(center=(340, 480))
    for i in range(3):
        glow = font_huge.render(str(player_score), True, color2)
        glow.set_alpha(60 - i*20)
        surface.blit(glow, p_score_rect.move(i*2, i*2))
    surface.blit(p_score, p_score_rect)

    # 보스 카드
    b_card = (WIDTH - 580, 280, 480, 380)
    draw_neon_glow_rect(surface, b_card, color2, glow_layers=10, thickness=4)
    pygame.draw.rect(surface, (22, 12, 15), (WIDTH - 572, 288, 464, 364), border_radius=8)

    # 보스 라벨
    b_label = font_large.render("BOSS", True, color2)
    b_label_rect = b_label.get_rect(right=WIDTH - 160, top=310)
    surface.blit(b_label, b_label_rect)

    # 보스 점수
    b_score = font_huge.render(str(boss_score), True, color2)
    b_score_rect = b_score.get_rect(center=(WIDTH - 340, 480))
    for i in range(3):
        glow = font_huge.render(str(boss_score), True, color1)
        glow.set_alpha(60 - i*20)
        surface.blit(glow, b_score_rect.move(i*2, i*2))
    surface.blit(b_score, b_score_rect)

    # VS 중앙
    vs_rect = (WIDTH//2 - 70, 420, 140, 100)
    draw_neon_glow_rect(surface, vs_rect, YELLOW, glow_layers=8, thickness=3)
    pygame.draw.rect(surface, (25, 20, 10), (WIDTH//2 - 62, 428, 124, 84), border_radius=5)

    vs = font_large.render("VS", True, YELLOW)
    vs_rect = vs.get_rect(center=(WIDTH//2, 470))
    surface.blit(vs, vs_rect)

    # 하단 정보
    info = font_small.render("◆ FIRST TO 3 WINS ◆", True, color1)
    info_rect = info.get_rect(center=(WIDTH//2, HEIGHT - 80))
    pygame.draw.rect(surface, (15, 10, 20), info_rect.inflate(50, 25), border_radius=8)
    pygame.draw.rect(surface, color1, info_rect.inflate(50, 25), 2, border_radius=8)
    pygame.draw.rect(surface, color2, info_rect.inflate(40, 18), 1, border_radius=6)
    surface.blit(info, info_rect)

    # 스타일 이름 표시
    name_text = font_medium.render(style_name, True, color1)
    name_rect = name_text.get_rect(center=(WIDTH//2, 40))
    surface.blit(name_text, name_rect)


# 5가지 사이버펑크 색상 조합
styles = [
    ("cyber1_cyan_magenta", (0, 255, 200), (255, 0, 150), "시안 + 매그넨타"),
    ("cyber2_magenta_yellow", (255, 0, 200), (255, 220, 0), "매그넨타 + 옐로우"),
    ("cyber3_lime_violet", (0, 255, 100), (200, 50, 255), "라임 + 바이올렛"),
    ("cyber4_orange_blue", (255, 120, 0), (0, 180, 255), "오렌지 + 스카이블루"),
    ("cyber5_pink_mint", (255, 50, 120), (0, 255, 180), "핫핑크 + 민트"),
]

for filename, color1, color2, style_name in styles:
    surface = pygame.Surface((WIDTH, HEIGHT))
    draw_cyberpunk_scoreboard(surface, 2, 1, color1, color2, style_name)
    pygame.image.save(surface, f"/tmp/{filename}.png")
    print(f"✅ {filename}.png 저장완료")

print("\n🎉 사이버펑크 테두리 전광판 5종 저장 완료!")
pygame.quit()
