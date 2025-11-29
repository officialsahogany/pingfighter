#!/usr/bin/env python3
"""
아이스 크리스탈 전광판 - 기본 점수판
얼음 결정 + 서리 효과
"""
import pygame
import math
import random

# 애니메이션 프레임 카운터
_animation_frame = 0


def get_animation_frame():
    """현재 애니메이션 프레임 반환"""
    global _animation_frame
    _animation_frame += 1
    return _animation_frame


def draw_ice_crystal_scoreboard(surface, player_score, boss_score, screen_width, screen_height):
    """
    아이스 크리스탈 전광판 그리기

    Args:
        surface: pygame 화면
        player_score: 플레이어 점수
        boss_score: 보스 점수
        screen_width: 화면 너비
        screen_height: 화면 높이
    """
    frame = get_animation_frame()

    # 전광판 크기 및 위치 (상단 중앙)
    w = 400
    h = 140
    x = (screen_width - w) // 2
    y = 10

    # 차가운 블루 그라데이션 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(h):
        ratio = row / h
        r = int(20 + 30 * ratio)
        g = int(40 + 60 * ratio)
        b_col = int(80 + 80 * ratio)
        pygame.draw.line(bg, (r, g, b_col, 250), (0, row), (w, row))
    surface.blit(bg, (x, y))

    # 눈 결정 패턴
    crystal_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    random.seed(42)
    for _ in range(8):
        cx = random.randint(30, w - 30)
        cy = random.randint(30, h - 30)
        size = random.randint(15, 35)
        rotation = frame * 0.02 + cx * 0.1

        # 6각형 눈송이
        for arm in range(6):
            angle = rotation + arm * math.pi / 3
            end_x = cx + size * math.cos(angle)
            end_y = cy + size * math.sin(angle)

            alpha = int(80 + 40 * math.sin(frame * 0.05 + arm))
            pygame.draw.line(crystal_surf, (200, 230, 255, alpha),
                           (cx, cy), (end_x, end_y), 2)

            # 가지
            for branch in [0.4, 0.7]:
                bx = cx + size * branch * math.cos(angle)
                by = cy + size * branch * math.sin(angle)
                for side in [-1, 1]:
                    branch_angle = angle + side * math.pi / 4
                    branch_len = size * 0.3
                    bex = bx + branch_len * math.cos(branch_angle)
                    bey = by + branch_len * math.sin(branch_angle)
                    pygame.draw.line(crystal_surf, (180, 220, 255, alpha // 2),
                                   (bx, by), (bex, bey), 1)

    surface.blit(crystal_surf, (x, y))

    # 서리 텍스처
    frost_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    random.seed(42)
    for _ in range(100):
        fx = random.randint(0, w)
        fy = random.randint(0, h)
        sparkle = 0.3 + 0.7 * random.random()
        size = 1 if sparkle < 0.7 else 2
        alpha = int(100 * sparkle)
        pygame.draw.circle(frost_surf, (220, 240, 255, alpha), (fx, fy), size)
    surface.blit(frost_surf, (x, y))

    # 빛 반사 효과
    reflection_x = int((frame * 2) % (w + 60)) - 30
    if 0 < reflection_x < w:
        for g in range(4, 0, -1):
            alpha = 40 // g
            ref_surf = pygame.Surface((30, h), pygame.SRCALPHA)
            for ry in range(h):
                line_alpha = int(alpha * (1 - abs(ry - h // 2) / (h // 2)))
                if line_alpha > 0:
                    pygame.draw.line(ref_surf, (255, 255, 255, line_alpha),
                                   (15 - g, ry), (15 + g, ry))
            surface.blit(ref_surf, (x + reflection_x - 15, y))

    # 얼음 테두리
    for i in range(3, 0, -1):
        shimmer = 0.6 + 0.4 * math.sin(frame * 0.05 + i)
        color = (int(150 + 50 * shimmer), int(200 + 55 * shimmer), 255)
        border = pygame.Surface((w + i * 6, h + i * 6), pygame.SRCALPHA)
        pygame.draw.rect(border, (*color, 70 // i), (0, 0, w + i * 6, h + i * 6),
                        width=2, border_radius=10)
        surface.blit(border, (x - i * 3, y - i * 3))

    # 점수 표시
    draw_ice_score(surface, player_score, boss_score, x, y, w, h, frame)


def draw_ice_score(surface, p_score, b_score, x, y, w, h, frame):
    """아이스 스타일 점수 표시"""
    try:
        font = pygame.font.SysFont("Arial", 64, bold=True)
        small_font = pygame.font.SysFont("Arial", 18, bold=True)
    except:
        font = pygame.font.Font(None, 72)
        small_font = pygame.font.Font(None, 22)

    center_x = x + w // 2
    score_y = y + h // 2 - 12

    # 플레이어 색상 (밝은 아이스 블루)
    p_color = (180, 220, 255)
    # 보스 색상 (진한 아이스 블루)
    b_color = (100, 180, 255)

    # 플레이어 점수
    p_text = font.render(str(p_score), True, p_color)
    p_x = center_x - 55 - p_text.get_width() // 2

    # 글로우 효과
    for g in range(3, 0, -1):
        glow = font.render(str(p_score), True, p_color)
        glow.set_alpha(60 // g)
        surface.blit(glow, (p_x - g, score_y - g))
    surface.blit(p_text, (p_x, score_y))

    # VS
    vs = small_font.render("VS", True, (180, 200, 220))
    surface.blit(vs, (center_x - vs.get_width() // 2, score_y + 20))

    # 보스 점수
    b_text = font.render(str(b_score), True, b_color)
    b_x = center_x + 55 - b_text.get_width() // 2

    for g in range(3, 0, -1):
        glow = font.render(str(b_score), True, b_color)
        glow.set_alpha(60 // g)
        surface.blit(glow, (b_x - g, score_y - g))
    surface.blit(b_text, (b_x, score_y))
