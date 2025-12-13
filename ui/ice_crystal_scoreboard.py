#!/usr/bin/env python3
"""
메탈릭 블루 전광판 - 기본 점수판
메탈릭 블루 그라데이션 + 광택 효과
"""
import pygame
import math
import random

# 애니메이션 프레임 카운터
_animation_frame = 0

# 보스 이름 매핑 (디스플레이 스테이지 번호 기준)
BOSS_NAMES = {
    1: "풍악보이",
    2: "악어장군",
    3: "멘헤라걸",
    4: "퐁크",
    5: "네메시스",
    6: "홍련",
    7: "테트리서",
    8: "토네이도",
}

# 스테이지 5, 6 스왑 맵 (로직 스테이지 → 디스플레이 스테이지)
STAGE_SWAP_MAP = {5: 6, 6: 5}


def get_animation_frame():
    """현재 애니메이션 프레임 반환"""
    global _animation_frame
    _animation_frame += 1
    return _animation_frame


def draw_ice_crystal_scoreboard(surface, player_score, boss_score, screen_width, screen_height, current_stage=1):
    """
    메탈릭 블루 전광판 그리기

    Args:
        surface: pygame 화면
        player_score: 플레이어 점수
        boss_score: 보스 점수
        screen_width: 화면 너비
        screen_height: 화면 높이
        current_stage: 현재 스테이지 번호
    """
    frame = get_animation_frame()

    # 전광판 크기 및 위치 (상단 중앙)
    w = 400
    h = 140
    x = (screen_width - w) // 2
    y = 10

    # 메탈릭 블루 그라데이션 배경
    bg = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(h):
        ratio = row / h
        # 메탈릭 블루: 어두운 네이비에서 밝은 스틸 블루로
        r = int(25 + 45 * ratio)
        g = int(50 + 80 * ratio)
        b_col = int(100 + 100 * ratio)
        pygame.draw.line(bg, (r, g, b_col, 250), (0, row), (w, row))
    surface.blit(bg, (x, y))

    # 메탈릭 광택 패턴 (수평선)
    metallic_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for row in range(0, h, 3):
        shimmer = 0.3 + 0.7 * math.sin(frame * 0.03 + row * 0.1)
        alpha = max(0, min(255, int(30 * shimmer)))
        pygame.draw.line(metallic_surf, (180, 210, 255, alpha), (0, row), (w, row), 1)
    surface.blit(metallic_surf, (x, y))

    # 메탈릭 하이라이트 (상단 광택)
    highlight_surf = pygame.Surface((w, 30), pygame.SRCALPHA)
    for row in range(30):
        alpha = int(60 * (1 - row / 30))
        pygame.draw.line(highlight_surf, (200, 230, 255, alpha), (0, row), (w, row))
    surface.blit(highlight_surf, (x, y))

    # 반짝이는 스파클 효과
    sparkle_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    random.seed(42)
    for _ in range(60):
        sx = random.randint(0, w)
        sy = random.randint(0, h)
        sparkle_phase = (frame * 0.1 + sx * 0.05 + sy * 0.03) % (2 * math.pi)
        sparkle_alpha = int(80 * max(0, math.sin(sparkle_phase)))
        if sparkle_alpha > 20:
            pygame.draw.circle(sparkle_surf, (220, 240, 255, sparkle_alpha), (sx, sy), 1)
    surface.blit(sparkle_surf, (x, y))

    # 이동하는 광택 효과
    reflection_x = int((frame * 1.5) % (w + 80)) - 40
    if 0 < reflection_x < w:
        ref_surf = pygame.Surface((60, h), pygame.SRCALPHA)
        for rx in range(60):
            dist = abs(rx - 30)
            alpha = int(50 * (1 - dist / 30))
            if alpha > 0:
                pygame.draw.line(ref_surf, (255, 255, 255, alpha), (rx, 0), (rx, h))
        surface.blit(ref_surf, (x + reflection_x - 30, y))

    # 메탈릭 블루 테두리
    for i in range(3, 0, -1):
        shimmer = 0.6 + 0.4 * math.sin(frame * 0.04 + i)
        # 메탈릭 블루 색상
        color = (int(80 + 60 * shimmer), int(140 + 80 * shimmer), int(220 + 35 * shimmer))
        border = pygame.Surface((w + i * 6, h + i * 6), pygame.SRCALPHA)
        pygame.draw.rect(border, (*color, 100 // i), (0, 0, w + i * 6, h + i * 6),
                        width=3, border_radius=12)
        surface.blit(border, (x - i * 3, y - i * 3))

    # 점수 표시 (로직 스테이지 → 디스플레이 스테이지 변환 후 보스 이름 조회)
    display_stage = STAGE_SWAP_MAP.get(current_stage, current_stage)
    boss_name = BOSS_NAMES.get(display_stage, "Boss")
    draw_metallic_score(surface, player_score, boss_score, x, y, w, h, frame, boss_name)


def draw_metallic_score(surface, p_score, b_score, x, y, w, h, frame, boss_name="Boss"):
    """메탈릭 블루 스타일 점수 표시 (20% 축소 + Player vs 보스이름)"""
    try:
        # 20% 축소: 64 -> 51, 18 -> 14
        font = pygame.font.SysFont("Arial", 51, bold=True)
        small_font = pygame.font.SysFont("Arial", 14, bold=True)
        label_font = pygame.font.SysFont("Arial", 16, bold=True)
    except:
        font = pygame.font.Font(None, 58)
        small_font = pygame.font.Font(None, 18)
        label_font = pygame.font.Font(None, 20)

    center_x = x + w // 2
    score_y = y + h // 2 - 5

    # 메탈릭 블루 색상
    p_color = (150, 200, 255)  # 플레이어: 밝은 메탈릭 블루
    b_color = (100, 160, 230)  # 보스: 진한 메탈릭 블루
    label_color = (180, 210, 255)  # 라벨: 밝은 스틸 블루

    # 플레이어 라벨 "Player"
    player_label = label_font.render("Player", True, label_color)
    player_label_x = center_x - 55 - player_label.get_width() // 2
    surface.blit(player_label, (player_label_x, y + 12))

    # 플레이어 점수
    p_text = font.render(str(p_score), True, p_color)
    p_x = center_x - 55 - p_text.get_width() // 2

    # 메탈릭 글로우 효과
    for g in range(3, 0, -1):
        glow = font.render(str(p_score), True, (100, 180, 255))
        glow.set_alpha(50 // g)
        surface.blit(glow, (p_x - g, score_y - g))
    surface.blit(p_text, (p_x, score_y))

    # VS
    vs = small_font.render("VS", True, (140, 180, 220))
    surface.blit(vs, (center_x - vs.get_width() // 2, score_y + 15))

    # 보스 라벨 (현재 스테이지 보스 이름)
    boss_label = label_font.render(boss_name, True, label_color)
    boss_label_x = center_x + 55 - boss_label.get_width() // 2
    surface.blit(boss_label, (boss_label_x, y + 12))

    # 보스 점수
    b_text = font.render(str(b_score), True, b_color)
    b_x = center_x + 55 - b_text.get_width() // 2

    for g in range(3, 0, -1):
        glow = font.render(str(b_score), True, (60, 140, 200))
        glow.set_alpha(50 // g)
        surface.blit(glow, (b_x - g, score_y - g))
    surface.blit(b_text, (b_x, score_y))


def draw_ice_score(surface, p_score, b_score, x, y, w, h, frame):
    """아이스 스타일 점수 표시 (레거시 - 사용되지 않음)"""
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
