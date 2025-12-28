#!/usr/bin/env python3
"""
인페르노 화염 전광판 - 듀스 모드용
지옥불 스타일의 화염 효과 점수판
"""
import pygame
import math
import random

# 화염 색상 팔레트
FIRE_COLORS = [
    (255, 255, 200),  # 중심 (흰색-노랑)
    (255, 230, 100),  # 밝은 노랑
    (255, 180, 50),   # 오렌지
    (255, 120, 30),   # 진한 오렌지
    (255, 60, 20),    # 빨강-오렌지
    (200, 30, 10),    # 진한 빨강
    (120, 20, 5),     # 어두운 빨강
    (60, 10, 0),      # 거의 검정
]

# 애니메이션 프레임 카운터
_animation_frame = 0


def get_animation_frame():
    """현재 애니메이션 프레임 반환"""
    global _animation_frame
    _animation_frame += 1
    return _animation_frame


def draw_fire_particle(surface, x, y, size, intensity, animation_frame):
    """화염 파티클 효과"""
    color_idx = int((1 - intensity) * (len(FIRE_COLORS) - 1))
    color_idx = max(0, min(len(FIRE_COLORS) - 1, color_idx))
    color = FIRE_COLORS[color_idx]

    wobble_x = math.sin(animation_frame * 0.3 + y * 0.1) * size * 0.3
    wobble_y = math.cos(animation_frame * 0.25 + x * 0.1) * size * 0.2

    for i in range(4, 0, -1):
        glow_size = size + i * 3
        glow_alpha = int(60 * intensity / i)
        glow_surf = pygame.Surface((glow_size * 2 + 20, glow_size * 2 + 20), pygame.SRCALPHA)
        glow_color = (*color, min(255, glow_alpha))
        pygame.draw.circle(glow_surf, glow_color, (glow_size + 10, glow_size + 10), glow_size)
        surface.blit(glow_surf, (x + wobble_x - glow_size - 10, y + wobble_y - glow_size - 10))

    pygame.draw.circle(surface, color, (int(x + wobble_x), int(y + wobble_y)), size)


def draw_flame_effect(surface, x, y, width, height, animation_frame, intensity=1.0):
    """화염 효과 그리기"""
    num_flames = int(width // 15)

    for i in range(num_flames):
        fx = x + i * 15 + random.randint(-3, 3)
        base_height = height * 0.4 + random.random() * height * 0.3
        phase = (animation_frame * 0.15 + i * 0.5) % (math.pi * 2)
        flame_height = base_height + math.sin(phase) * height * 0.2

        for layer in range(3):
            fy = y + height - flame_height * (1 - layer * 0.25)
            size = 8 - layer * 2
            layer_intensity = intensity * (1 - layer * 0.25)
            draw_fire_particle(surface, fx, fy, size, layer_intensity, animation_frame + layer * 10)


def draw_ember_particles(surface, rect, animation_frame, count=30):
    """떠다니는 불씨 효과"""
    x, y, w, h = rect
    random.seed(42)

    for i in range(count):
        base_x = x + random.random() * w
        base_y = y + random.random() * h
        t = animation_frame * 0.02 + i * 0.5
        px = base_x + math.sin(t + i) * 20
        py = base_y - (animation_frame * 2 + i * 30) % h

        if x <= px <= x + w and y <= py <= y + h:
            size = 2 + random.random() * 3
            alpha = int(100 + random.random() * 155)
            color = random.choice(FIRE_COLORS[:4])
            glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*color, alpha // 2), (10, 10), int(size * 2))
            pygame.draw.circle(glow_surf, (*color, alpha), (10, 10), int(size))
            surface.blit(glow_surf, (px - 10, py - 10))

    random.seed()  # 시드 리셋 (다른 랜덤 로직에 영향 방지)


def draw_lava_flow(surface, rect, animation_frame):
    """용암 흐름 효과"""
    x, y, w, h = rect

    for i in range(0, w, 4):
        for j in range(0, h, 4):
            noise = math.sin(i * 0.05 + animation_frame * 0.03) * math.cos(j * 0.05 + animation_frame * 0.02)
            noise += math.sin((i + j) * 0.03 + animation_frame * 0.05) * 0.5
            intensity = (noise + 1) / 2

            if intensity > 0.7:
                g = max(0, min(255, 200 + int(55 * noise)))
                color = (255, g, 100)
            elif intensity > 0.4:
                g = max(0, min(255, 100 + int(80 * intensity)))
                color = (255, g, 20)
            else:
                r = max(0, min(255, 150 + int(50 * intensity)))
                color = (r, 30, 10)

            pygame.draw.rect(surface, color, (x + i, y + j, 4, 4))


def draw_dot_matrix_fire(surface, x, y, digit, color, size=140, animation_frame=0):
    """화염 효과 도트 매트릭스 숫자"""
    patterns = {
        '0': ["  11111  ", " 1111111 ", "111   111", "111   111", "111   111",
              "111   111", "111   111", "111   111", "111   111", "111   111",
              "111   111", " 1111111 ", "  11111  "],
        '1': ["    111  ", "   1111  ", "  11111  ", " 111111  ", "    111  ",
              "    111  ", "    111  ", "    111  ", "    111  ", "    111  ",
              "    111  ", " 1111111 ", "111111111"],
        '2': [" 1111111 ", "111111111", "111   111", "      111", "     111 ",
              "    111  ", "   111   ", "  111    ", " 111     ", "111      ",
              "111   111", "111111111", "111111111"],
        '3': [" 1111111 ", "111111111", "111   111", "      111", "      111",
              "  111111 ", "  111111 ", "      111", "      111", "111   111",
              "111   111", "111111111", " 1111111 "],
        '4': ["     111 ", "    1111 ", "   11111 ", "  111111 ", " 111 111 ",
              "111  111 ", "111  111 ", "111111111", "111111111", "     111 ",
              "     111 ", "     111 ", "     111 "],
        '5': ["111111111", "111111111", "111      ", "111      ", "11111111 ",
              "111111111", "      111", "      111", "      111", "111   111",
              "111   111", "111111111", " 1111111 "],
        '6': [" 1111111 ", "111111111", "111   111", "111      ", "111      ",
              "11111111 ", "111111111", "111   111", "111   111", "111   111",
              "111   111", "111111111", " 1111111 "],
        '7': ["111111111", "111111111", "111   111", "      111", "     111 ",
              "    111  ", "   111   ", "   111   ", "   111   ", "   111   ",
              "   111   ", "   111   ", "   111   "],
        '8': [" 1111111 ", "111111111", "111   111", "111   111", "111   111",
              " 1111111 ", " 1111111 ", "111   111", "111   111", "111   111",
              "111   111", "111111111", " 1111111 "],
        '9': [" 1111111 ", "111111111", "111   111", "111   111", "111   111",
              "111111111", " 11111111", "      111", "      111", "111   111",
              "111   111", "111111111", " 1111111 "]
    }

    pattern = patterns.get(str(digit), patterns['0'])
    spacing = size // 13
    dot_radius = 4

    for row_idx, row in enumerate(pattern):
        for col_idx, char in enumerate(row):
            dot_x = x + col_idx * spacing + spacing // 2
            dot_y = y + row_idx * spacing + spacing // 2

            if char == '1':
                pulse = 0.7 + 0.3 * math.sin(animation_frame * 0.1 + row_idx * 0.3 + col_idx * 0.2)

                for g in range(4, 0, -1):
                    glow_size = dot_radius + g * 2
                    glow_alpha = int(60 * pulse / g)
                    glow_surf = pygame.Surface((glow_size * 2 + 10, glow_size * 2 + 10), pygame.SRCALPHA)
                    glow_color = (color[0], color[1] // 2, 0, glow_alpha)
                    pygame.draw.circle(glow_surf, glow_color, (glow_size + 5, glow_size + 5), glow_size)
                    surface.blit(glow_surf, (dot_x - glow_size - 5, dot_y - glow_size - 5))

                pygame.draw.circle(surface, color, (dot_x, dot_y), dot_radius)
                bright = (min(255, color[0] + 80), min(255, color[1] + 60), min(255, color[2] + 40))
                pygame.draw.circle(surface, bright, (dot_x, dot_y), dot_radius - 1)
                pygame.draw.circle(surface, (255, 255, 230), (dot_x - 1, dot_y - 1), 1)
            else:
                pygame.draw.circle(surface, (30, 12, 8), (dot_x, dot_y), dot_radius - 1)


def draw_inferno_deuce_scoreboard(surface, player_score, boss_score, deuce_goal, screen_width, screen_height):
    """
    듀스 모드용 인페르노 전광판 그리기

    Args:
        surface: pygame 화면
        player_score: 플레이어 점수 (듀스 점수)
        boss_score: 보스 점수 (듀스 점수)
        deuce_goal: 듀스 목표 점수 (6 또는 7)
        screen_width: 화면 너비
        screen_height: 화면 높이
    """
    animation_frame = get_animation_frame()

    # 전광판 크기 및 위치 (상단 중앙, 작게)
    board_width = 400
    board_height = 140
    board_x = (screen_width - board_width) // 2
    board_y = 10

    # 어두운 빨강 배경
    pygame.draw.rect(surface, (20, 5, 5), (board_x, board_y, board_width, board_height))

    # 용암 텍스처
    lava_rect = (board_x + 5, board_y + 5, board_width - 10, board_height - 10)
    draw_lava_flow(surface, lava_rect, animation_frame)

    # 검은 오버레이 (부분 투명)
    overlay = pygame.Surface((board_width - 10, board_height - 10), pygame.SRCALPHA)
    overlay.fill((0, 0, 0, 180))
    surface.blit(overlay, (board_x + 5, board_y + 5))

    # 화염 프레임
    frame_color = (180, 60, 20)
    pygame.draw.rect(surface, frame_color, (board_x, board_y, board_width, board_height), 4)
    pygame.draw.rect(surface, (255, 120, 40), (board_x + 2, board_y + 2, board_width - 4, board_height - 4), 2)
    pygame.draw.rect(surface, (255, 200, 100), (board_x + 4, board_y + 4, board_width - 8, board_height - 8), 1)

    # 상단 화염 효과 (작게)
    draw_flame_effect(surface, board_x + 10, board_y - 25, board_width - 20, 40, animation_frame, 0.6)

    # 떠다니는 불씨 (적게)
    draw_ember_particles(surface, (board_x, board_y, board_width, board_height), animation_frame, 15)

    # 듀스 타이틀
    try:
        title_font = pygame.font.SysFont("Arial", 18, bold=True)
    except:
        title_font = pygame.font.Font(None, 22)

    title_text = f"DEUCE (First to {deuce_goal})"

    # 화염 글로우
    for i in range(3, 0, -1):
        glow = title_font.render(title_text, True, (255, 100, 0))
        glow.set_alpha(40 // i)
        surface.blit(glow, (screen_width // 2 - glow.get_width() // 2 + i, board_y + 12 + i))
        surface.blit(glow, (screen_width // 2 - glow.get_width() // 2 - i, board_y + 12 - i))

    title_surf = title_font.render(title_text, True, (255, 220, 100))
    surface.blit(title_surf, (screen_width // 2 - title_surf.get_width() // 2, board_y + 12))

    # 점수 표시 (도트 매트릭스)
    score_y = board_y + 40
    digit_size = 70

    # 플레이어 점수 (오렌지)
    orange = (255, 150, 50)
    draw_dot_matrix_fire(surface, board_x + 40, score_y, player_score, orange, digit_size, animation_frame)

    # VS
    try:
        vs_font = pygame.font.SysFont("Arial", 24, bold=True)
    except:
        vs_font = pygame.font.Font(None, 28)

    vs_x = screen_width // 2
    vs_y = score_y + 35

    # 화염 원
    for i in range(3, 0, -1):
        pygame.draw.circle(surface, (255, 100 + i * 30, i * 15), (vs_x, vs_y), 18 + i * 3, 2)
    pygame.draw.circle(surface, (60, 20, 10), (vs_x, vs_y), 16)
    pygame.draw.circle(surface, (255, 180, 80), (vs_x, vs_y), 14, 2)

    vs = vs_font.render(":", True, (255, 220, 150))
    surface.blit(vs, (vs_x - vs.get_width() // 2, vs_y - vs.get_height() // 2))

    # 보스 점수 (빨강)
    red = (255, 80, 40)
    draw_dot_matrix_fire(surface, board_x + board_width - 110, score_y, boss_score, red, digit_size, animation_frame)

    # 하단 정보
    try:
        info_font = pygame.font.SysFont("Arial", 12, bold=True)
    except:
        info_font = pygame.font.Font(None, 16)

    info = info_font.render("BURN TO WIN", True, (255, 180, 80))
    surface.blit(info, (screen_width // 2 - info.get_width() // 2, board_y + board_height - 18))
