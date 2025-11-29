#!/usr/bin/env python3
"""
인페르노 화염 전광판 스타일 - 5가지 불꽃 테마
지옥불, 용암, 불사조, 마그마, 태양 폭발 스타일
"""
import pygame
import math
import random
import sys
import os

# 화면 설정
WIDTH = 900
HEIGHT = 700

# 색상
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
YELLOW = (255, 220, 0)
ORANGE = (255, 150, 50)
RED = (255, 50, 50)

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

pygame.init()
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("인페르노 화염 전광판 - 5가지 스타일")
clock = pygame.time.Clock()

# 폰트
try:
    font_path = os.path.join(os.path.dirname(__file__), "fonts", "NeoDunggeunmoPro-Regular.ttf")
    if os.path.exists(font_path):
        font_huge = pygame.font.Font(font_path, 120)
        font_large = pygame.font.Font(font_path, 80)
        font_medium = pygame.font.Font(font_path, 40)
        font_small = pygame.font.Font(font_path, 28)
        font_title = pygame.font.Font(font_path, 36)
        font_tiny = pygame.font.Font(font_path, 20)
    else:
        font_huge = pygame.font.Font(None, 120)
        font_large = pygame.font.Font(None, 80)
        font_medium = pygame.font.Font(None, 40)
        font_small = pygame.font.Font(None, 28)
        font_title = pygame.font.Font(None, 36)
        font_tiny = pygame.font.Font(None, 20)
except:
    font_huge = pygame.font.Font(None, 120)
    font_large = pygame.font.Font(None, 80)
    font_medium = pygame.font.Font(None, 40)
    font_small = pygame.font.Font(None, 28)
    font_title = pygame.font.Font(None, 36)
    font_tiny = pygame.font.Font(None, 20)


def draw_fire_particle(surface, x, y, size, intensity, animation_frame):
    """화염 파티클 효과"""
    # 불꽃 색상 선택 (intensity에 따라)
    color_idx = int((1 - intensity) * (len(FIRE_COLORS) - 1))
    color_idx = max(0, min(len(FIRE_COLORS) - 1, color_idx))
    color = FIRE_COLORS[color_idx]

    # 흔들림 효과
    wobble_x = math.sin(animation_frame * 0.3 + y * 0.1) * size * 0.3
    wobble_y = math.cos(animation_frame * 0.25 + x * 0.1) * size * 0.2

    # 글로우
    for i in range(4, 0, -1):
        glow_size = size + i * 3
        glow_alpha = int(60 * intensity / i)
        glow_surf = pygame.Surface((glow_size * 2 + 20, glow_size * 2 + 20), pygame.SRCALPHA)
        glow_color = (*color, min(255, glow_alpha))
        pygame.draw.circle(glow_surf, glow_color, (glow_size + 10, glow_size + 10), glow_size)
        surface.blit(glow_surf, (x + wobble_x - glow_size - 10, y + wobble_y - glow_size - 10))

    # 메인 파티클
    pygame.draw.circle(surface, color, (int(x + wobble_x), int(y + wobble_y)), size)


def draw_flame_effect(surface, x, y, width, height, animation_frame, intensity=1.0):
    """화염 효과 그리기"""
    num_flames = int(width // 15)

    for i in range(num_flames):
        fx = x + i * 15 + random.randint(-3, 3)

        # 불꽃 높이 (위로 올라가는 효과)
        base_height = height * 0.4 + random.random() * height * 0.3
        phase = (animation_frame * 0.15 + i * 0.5) % (math.pi * 2)
        flame_height = base_height + math.sin(phase) * height * 0.2

        # 여러 레이어의 불꽃
        for layer in range(3):
            fy = y + height - flame_height * (1 - layer * 0.25)
            size = 8 - layer * 2
            layer_intensity = intensity * (1 - layer * 0.25)
            draw_fire_particle(surface, fx, fy, size, layer_intensity, animation_frame + layer * 10)


def draw_ember_particles(surface, rect, animation_frame, count=30):
    """떠다니는 불씨 효과"""
    x, y, w, h = rect
    random.seed(42)  # 일관된 패턴

    for i in range(count):
        # 각 파티클의 위치 계산
        base_x = x + random.random() * w
        base_y = y + random.random() * h

        # 시간에 따른 움직임
        t = animation_frame * 0.02 + i * 0.5
        px = base_x + math.sin(t + i) * 20
        py = base_y - (animation_frame * 2 + i * 30) % h  # 위로 올라감

        if x <= px <= x + w and y <= py <= y + h:
            size = 2 + random.random() * 3
            alpha = int(100 + random.random() * 155)
            color = random.choice(FIRE_COLORS[:4])

            # 작은 글로우
            glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*color, alpha // 2), (10, 10), int(size * 2))
            pygame.draw.circle(glow_surf, (*color, alpha), (10, 10), int(size))
            surface.blit(glow_surf, (px - 10, py - 10))


def draw_lava_flow(surface, rect, animation_frame):
    """용암 흐름 효과"""
    x, y, w, h = rect

    for i in range(0, w, 4):
        for j in range(0, h, 4):
            # 노이즈 패턴
            noise = math.sin(i * 0.05 + animation_frame * 0.03) * math.cos(j * 0.05 + animation_frame * 0.02)
            noise += math.sin((i + j) * 0.03 + animation_frame * 0.05) * 0.5

            # 색상 결정 (0-255 범위로 클램핑)
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


def draw_7segment_fire(surface, x, y, digit, base_color, size=120, animation_frame=0):
    """화염 효과가 있는 7세그먼트"""
    thickness = size // 8
    seg_length = size // 2 - thickness
    gap = thickness // 2

    patterns = {
        '0': (1,1,1,1,1,1,0), '1': (0,1,1,0,0,0,0), '2': (1,1,0,1,1,0,1),
        '3': (1,1,1,1,0,0,1), '4': (0,1,1,0,0,1,1), '5': (1,0,1,1,0,1,1),
        '6': (1,0,1,1,1,1,1), '7': (1,1,1,0,0,0,0), '8': (1,1,1,1,1,1,1),
        '9': (1,1,1,1,0,1,1)
    }

    pattern = patterns.get(str(digit), patterns['0'])

    segments = [
        [(x + gap, y), (x + seg_length + gap, y),
         (x + seg_length, y + thickness//2), (x + thickness, y + thickness//2)],
        [(x + seg_length + gap, y + gap), (x + seg_length + gap + thickness//2, y + thickness),
         (x + seg_length + gap + thickness//2, y + seg_length), (x + seg_length + gap, y + seg_length + gap)],
        [(x + seg_length + gap, y + seg_length + gap * 2), (x + seg_length + gap + thickness//2, y + seg_length + thickness + gap),
         (x + seg_length + gap + thickness//2, y + size - thickness), (x + seg_length + gap, y + size - gap)],
        [(x + gap, y + size - gap), (x + seg_length + gap, y + size - gap),
         (x + seg_length, y + size - thickness//2 - gap), (x + thickness, y + size - thickness//2 - gap)],
        [(x, y + seg_length + gap * 2), (x + thickness//2, y + seg_length + thickness + gap),
         (x + thickness//2, y + size - thickness), (x, y + size - gap)],
        [(x, y + gap), (x + thickness//2, y + thickness),
         (x + thickness//2, y + seg_length), (x, y + seg_length + gap)],
        [(x + gap, y + seg_length + gap), (x + seg_length + gap, y + seg_length + gap),
         (x + seg_length, y + seg_length + gap + thickness//2), (x + thickness, y + seg_length + gap + thickness//2)]
    ]

    for i, seg in enumerate(segments):
        if pattern[i]:
            # 화염 글로우
            pulse = 0.7 + 0.3 * math.sin(animation_frame * 0.15 + i * 0.5)

            # 다중 글로우 레이어
            for glow in range(5, 0, -1):
                glow_surf = pygame.Surface((size + 60, size + 60), pygame.SRCALPHA)
                glow_intensity = int(40 * pulse / glow)
                glow_color = (base_color[0], base_color[1] // 2, 0, glow_intensity)
                offset_seg = [(p[0] - x + 30, p[1] - y + 30) for p in seg]
                pygame.draw.polygon(glow_surf, glow_color, offset_seg)
                surface.blit(glow_surf, (x - 30 - glow * 2, y - 30 - glow * 2))

            # 메인 세그먼트 (밝은 중심)
            inner_color = (min(255, base_color[0] + 50), min(255, base_color[1] + 30), base_color[2])
            pygame.draw.polygon(surface, inner_color, seg)

            # 중심 하이라이트
            center_color = (255, 255, 200)
            inner_seg = []
            center = (sum(p[0] for p in seg) / 4, sum(p[1] for p in seg) / 4)
            for p in seg:
                inner_seg.append((p[0] + (center[0] - p[0]) * 0.4, p[1] + (center[1] - p[1]) * 0.4))
            if len(inner_seg) >= 3:
                pygame.draw.polygon(surface, center_color, inner_seg[:4])
        else:
            # 꺼진 세그먼트 (은은한 빨강)
            dim = (40, 15, 10)
            pygame.draw.polygon(surface, dim, seg)


def draw_dot_matrix_fire(surface, x, y, digit, color, size=140, animation_frame=0):
    """화염 효과 도트 매트릭스"""
    patterns = {
        '0': [
            "  11111  ", " 1111111 ", "111   111", "111   111", "111   111",
            "111   111", "111   111", "111   111", "111   111", "111   111",
            "111   111", " 1111111 ", "  11111  "
        ],
        '1': [
            "    111  ", "   1111  ", "  11111  ", " 111111  ", "    111  ",
            "    111  ", "    111  ", "    111  ", "    111  ", "    111  ",
            "    111  ", " 1111111 ", "111111111"
        ],
        '2': [
            " 1111111 ", "111111111", "111   111", "      111", "     111 ",
            "    111  ", "   111   ", "  111    ", " 111     ", "111      ",
            "111   111", "111111111", "111111111"
        ],
        '3': [
            " 1111111 ", "111111111", "111   111", "      111", "      111",
            "  111111 ", "  111111 ", "      111", "      111", "111   111",
            "111   111", "111111111", " 1111111 "
        ],
        '4': [
            "     111 ", "    1111 ", "   11111 ", "  111111 ", " 111 111 ",
            "111  111 ", "111  111 ", "111111111", "111111111", "     111 ",
            "     111 ", "     111 ", "     111 "
        ],
        '5': [
            "111111111", "111111111", "111      ", "111      ", "11111111 ",
            "111111111", "      111", "      111", "      111", "111   111",
            "111   111", "111111111", " 1111111 "
        ],
        '6': [
            " 1111111 ", "111111111", "111   111", "111      ", "111      ",
            "11111111 ", "111111111", "111   111", "111   111", "111   111",
            "111   111", "111111111", " 1111111 "
        ],
        '7': [
            "111111111", "111111111", "111   111", "      111", "     111 ",
            "    111  ", "   111   ", "   111   ", "   111   ", "   111   ",
            "   111   ", "   111   ", "   111   "
        ],
        '8': [
            " 1111111 ", "111111111", "111   111", "111   111", "111   111",
            " 1111111 ", " 1111111 ", "111   111", "111   111", "111   111",
            "111   111", "111111111", " 1111111 "
        ],
        '9': [
            " 1111111 ", "111111111", "111   111", "111   111", "111   111",
            "111111111", " 11111111", "      111", "      111", "111   111",
            "111   111", "111111111", " 1111111 "
        ]
    }

    pattern = patterns.get(str(digit), patterns['0'])
    spacing = size // 13
    dot_radius = 4

    for row_idx, row in enumerate(pattern):
        for col_idx, char in enumerate(row):
            dot_x = x + col_idx * spacing + spacing // 2
            dot_y = y + row_idx * spacing + spacing // 2

            if char == '1':
                # 화염 도트
                pulse = 0.7 + 0.3 * math.sin(animation_frame * 0.1 + row_idx * 0.3 + col_idx * 0.2)

                # 글로우
                for g in range(4, 0, -1):
                    glow_size = dot_radius + g * 2
                    glow_alpha = int(60 * pulse / g)
                    glow_surf = pygame.Surface((glow_size * 2 + 10, glow_size * 2 + 10), pygame.SRCALPHA)
                    glow_color = (color[0], color[1] // 2, 0, glow_alpha)
                    pygame.draw.circle(glow_surf, glow_color, (glow_size + 5, glow_size + 5), glow_size)
                    surface.blit(glow_surf, (dot_x - glow_size - 5, dot_y - glow_size - 5))

                # 메인 도트
                pygame.draw.circle(surface, color, (dot_x, dot_y), dot_radius)
                # 밝은 중심
                bright = (min(255, color[0] + 80), min(255, color[1] + 60), min(255, color[2] + 40))
                pygame.draw.circle(surface, bright, (dot_x, dot_y), dot_radius - 1)
                # 하이라이트
                pygame.draw.circle(surface, (255, 255, 230), (dot_x - 1, dot_y - 1), 1)
            else:
                # 꺼진 도트 (은은한 빨강)
                pygame.draw.circle(surface, (30, 12, 8), (dot_x, dot_y), dot_radius - 1)


def draw_style1_hellfire(surface, player_score, boss_score, animation_frame):
    """스타일 1: 지옥불 (Hell Fire)"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 어두운 빨강 배경
    pygame.draw.rect(surface, (20, 5, 5), (board_x, board_y, board_width, board_height))

    # 용암 텍스처
    lava_rect = (board_x + 15, board_y + 15, board_width - 30, board_height - 30)
    draw_lava_flow(surface, lava_rect, animation_frame)

    # 검은 오버레이 (부분 투명)
    overlay = pygame.Surface((board_width - 30, board_height - 30), pygame.SRCALPHA)
    overlay.fill((0, 0, 0, 180))
    surface.blit(overlay, (board_x + 15, board_y + 15))

    # 화염 프레임
    frame_color = (180, 60, 20)
    pygame.draw.rect(surface, frame_color, (board_x, board_y, board_width, board_height), 8)
    pygame.draw.rect(surface, (255, 120, 40), (board_x + 4, board_y + 4, board_width - 8, board_height - 8), 3)
    pygame.draw.rect(surface, (255, 200, 100), (board_x + 8, board_y + 8, board_width - 16, board_height - 16), 1)

    # 상단 화염
    draw_flame_effect(surface, board_x + 20, board_y - 50, board_width - 40, 80, animation_frame, 0.8)

    # 떠다니는 불씨
    draw_ember_particles(surface, (board_x, board_y, board_width, board_height), animation_frame, 40)

    # 타이틀
    title_y = board_y + 30
    title = "🔥 HELL FIRE 🔥"

    # 화염 글로우
    for i in range(5, 0, -1):
        glow = font_title.render(title, True, (255, 100, 0))
        glow.set_alpha(40 // i)
        surface.blit(glow, (WIDTH // 2 - glow.get_width() // 2 + i, title_y + i))
        surface.blit(glow, (WIDTH // 2 - glow.get_width() // 2 - i, title_y - i))

    title_surf = font_title.render(title, True, (255, 220, 100))
    surface.blit(title_surf, (WIDTH // 2 - title_surf.get_width() // 2, title_y))

    # 팀 영역
    team_y = board_y + 80

    # 플레이어
    p_box = pygame.Rect(board_x + 40, team_y, 280, 50)
    pygame.draw.rect(surface, (40, 15, 10), p_box)
    pygame.draw.rect(surface, (255, 150, 80), p_box, 2)
    p_label = font_medium.render("PLAYER", True, (255, 180, 100))
    surface.blit(p_label, (p_box.centerx - p_label.get_width() // 2, team_y + 8))

    # 보스
    b_box = pygame.Rect(board_x + board_width - 320, team_y, 280, 50)
    pygame.draw.rect(surface, (50, 10, 10), b_box)
    pygame.draw.rect(surface, (255, 80, 60), b_box, 2)
    b_label = font_medium.render("DEMON", True, (255, 100, 80))
    surface.blit(b_label, (b_box.centerx - b_label.get_width() // 2, team_y + 8))

    # 점수
    score_y = team_y + 70
    orange = (255, 150, 50)
    draw_dot_matrix_fire(surface, board_x + 90, score_y, player_score, orange, 140, animation_frame)

    red = (255, 80, 40)
    draw_dot_matrix_fire(surface, board_x + board_width - 220, score_y, boss_score, red, 140, animation_frame)

    # VS (불타는 효과)
    vs_x = WIDTH // 2
    vs_y = score_y + 80

    # 화염 원
    for i in range(5, 0, -1):
        pygame.draw.circle(surface, (255, 100 + i * 20, i * 10), (vs_x, vs_y), 40 + i * 5, 2)
    pygame.draw.circle(surface, (80, 20, 10), (vs_x, vs_y), 38)
    pygame.draw.circle(surface, (255, 180, 80), (vs_x, vs_y), 35, 3)

    vs = font_medium.render("VS", True, (255, 220, 150))
    surface.blit(vs, (vs_x - vs.get_width() // 2, vs_y - vs.get_height() // 2))

    # 하단
    footer_y = board_y + board_height - 55
    info = font_small.render("◆ BURN TO WIN ◆", True, (255, 180, 80))
    surface.blit(info, (WIDTH // 2 - info.get_width() // 2, footer_y))


def draw_style2_lava_core(surface, player_score, boss_score, animation_frame):
    """스타일 2: 용암 코어 (Lava Core)"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 검은 배경
    pygame.draw.rect(surface, (10, 5, 5), (board_x, board_y, board_width, board_height))

    # 용암 균열 효과
    crack_surf = pygame.Surface((board_width, board_height), pygame.SRCALPHA)
    random.seed(100)

    for _ in range(15):
        cx = random.randint(0, board_width)
        cy = random.randint(0, board_height)

        # 균열 라인
        points = [(cx, cy)]
        for _ in range(random.randint(3, 6)):
            last = points[-1]
            new_x = last[0] + random.randint(-50, 50)
            new_y = last[1] + random.randint(-30, 30)
            points.append((new_x, new_y))

        # 글로우
        pulse = 0.5 + 0.5 * math.sin(animation_frame * 0.08 + cx * 0.01)
        for width in range(8, 0, -2):
            color = (255, int(100 * pulse), 0, 40 - width * 4)
            if len(points) >= 2:
                pygame.draw.lines(crack_surf, color, False, points, width)

        # 밝은 중심
        if len(points) >= 2:
            pygame.draw.lines(crack_surf, (255, 200, 100), False, points, 1)

    surface.blit(crack_surf, (board_x, board_y))

    # 프레임 (용암 테두리)
    for i in range(4):
        pulse = 0.7 + 0.3 * math.sin(animation_frame * 0.1 + i * 0.5)
        color = (int(200 * pulse) + 55, int(80 * pulse), 0)
        pygame.draw.rect(surface, color, (board_x + i * 3, board_y + i * 3,
                        board_width - i * 6, board_height - i * 6), 3)

    # 상단 타이틀 영역
    title_bar = pygame.Rect(board_x + 25, board_y + 20, board_width - 50, 60)
    pygame.draw.rect(surface, (30, 10, 5), title_bar)
    pygame.draw.rect(surface, (255, 120, 50), title_bar, 2)

    title = font_title.render("⚫ LAVA CORE ⚫", True, (255, 200, 100))
    surface.blit(title, (WIDTH // 2 - title.get_width() // 2, board_y + 35))

    # 점수 영역 (7세그먼트)
    score_y = board_y + 100

    # 플레이어 박스
    p_area = pygame.Rect(board_x + 40, score_y, 280, 200)
    pygame.draw.rect(surface, (15, 5, 5), p_area)
    # 용암 테두리 애니메이션
    for i in range(3):
        phase = (animation_frame * 0.05 + i * 0.3) % 1
        brightness = int(200 * phase) + 55
        pygame.draw.rect(surface, (brightness, brightness // 3, 0), p_area.inflate(i * 4, i * 4), 2)

    p_label = font_small.render("PLAYER", True, (255, 180, 100))
    surface.blit(p_label, (p_area.centerx - p_label.get_width() // 2, score_y + 10))

    draw_7segment_fire(surface, board_x + 100, score_y + 45, player_score, (255, 180, 50), 130, animation_frame)

    # 보스 박스
    b_area = pygame.Rect(board_x + board_width - 320, score_y, 280, 200)
    pygame.draw.rect(surface, (20, 5, 5), b_area)
    for i in range(3):
        phase = (animation_frame * 0.05 + i * 0.3 + 0.5) % 1
        brightness = int(200 * phase) + 55
        pygame.draw.rect(surface, (brightness, brightness // 4, 0), b_area.inflate(i * 4, i * 4), 2)

    b_label = font_small.render("MOLTEN BEAST", True, (255, 120, 80))
    surface.blit(b_label, (b_area.centerx - b_label.get_width() // 2, score_y + 10))

    draw_7segment_fire(surface, board_x + board_width - 260, score_y + 45, boss_score, (255, 100, 30), 130, animation_frame)

    # VS (용암 방울)
    vs_x = WIDTH // 2
    vs_y = score_y + 100

    # 용암 방울 효과
    drop_offset = math.sin(animation_frame * 0.1) * 5
    pygame.draw.ellipse(surface, (200, 80, 20), (vs_x - 35, vs_y - 30 + drop_offset, 70, 60))
    pygame.draw.ellipse(surface, (255, 150, 50), (vs_x - 30, vs_y - 25 + drop_offset, 60, 50))
    pygame.draw.ellipse(surface, (255, 220, 150), (vs_x - 20, vs_y - 18 + drop_offset, 40, 35))

    vs = font_medium.render("VS", True, (80, 30, 10))
    surface.blit(vs, (vs_x - vs.get_width() // 2, vs_y - vs.get_height() // 2 + int(drop_offset)))

    # 하단 정보
    footer = pygame.Rect(board_x + 25, board_y + board_height - 60, board_width - 50, 45)
    pygame.draw.rect(surface, (25, 10, 5), footer)
    pygame.draw.rect(surface, (180, 80, 30), footer, 2)

    info = font_small.render("FIRST TO 3 WINS", True, (255, 180, 100))
    surface.blit(info, (WIDTH // 2 - info.get_width() // 2, board_y + board_height - 48))


def draw_style3_phoenix_blaze(surface, player_score, boss_score, animation_frame):
    """스타일 3: 불사조 블레이즈 (Phoenix Blaze)"""
    board_width = 780
    board_height = 420
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 그라데이션 배경 (아래에서 위로 어두워짐)
    for i in range(board_height):
        ratio = i / board_height
        r = int(60 * (1 - ratio) + 10 * ratio)
        g = int(20 * (1 - ratio) + 5 * ratio)
        b = int(10 * (1 - ratio) + 5 * ratio)
        pygame.draw.line(surface, (r, g, b),
                        (board_x, board_y + i), (board_x + board_width, board_y + i))

    # 깃털 패턴 (불사조)
    feather_surf = pygame.Surface((board_width, board_height), pygame.SRCALPHA)
    random.seed(55)

    for _ in range(20):
        fx = random.randint(0, board_width)
        fy = random.randint(0, board_height)
        size = random.randint(20, 50)
        angle = random.uniform(0, math.pi * 2)

        # 깃털 그리기 (곡선)
        pulse = 0.5 + 0.5 * math.sin(animation_frame * 0.05 + fx * 0.01)
        for j in range(size):
            t = j / size
            px = fx + j * math.cos(angle) + math.sin(j * 0.3 + animation_frame * 0.1) * 10
            py = fy + j * math.sin(angle) * 0.5
            alpha = int(100 * (1 - t) * pulse)
            color = (255, int(180 * (1 - t)), 50, alpha)
            pygame.draw.circle(feather_surf, color, (int(px), int(py)), int(3 * (1 - t) + 1))

    surface.blit(feather_surf, (board_x, board_y))

    # 금빛 프레임
    gold_colors = [(255, 200, 100), (255, 180, 50), (200, 140, 30), (150, 100, 20)]
    for i, color in enumerate(gold_colors):
        pygame.draw.rect(surface, color, (board_x + i * 3, board_y + i * 3,
                        board_width - i * 6, board_height - i * 6), 3)

    # 불사조 날개 효과 (상단)
    wing_y = board_y - 20
    for side in [-1, 1]:
        wing_x = WIDTH // 2 + side * 200

        for i in range(8):
            angle = (animation_frame * 0.03 + i * 0.2) * side
            length = 80 - i * 8

            start = (wing_x, wing_y + 40)
            end = (wing_x + side * length * math.cos(angle + side * 0.5),
                   wing_y + 40 - length * math.sin(abs(angle) + 0.5))

            color = (255, 200 - i * 20, 50 - i * 5)
            pygame.draw.line(surface, color, start, end, 4 - i // 3)

    # 타이틀
    title_y = board_y + 25
    title = "🦅 PHOENIX BLAZE 🦅"

    # 금빛 글로우
    for i in range(4, 0, -1):
        glow = font_title.render(title, True, (255, 200, 50))
        glow.set_alpha(50 // i)
        surface.blit(glow, (WIDTH // 2 - glow.get_width() // 2 + i, title_y + i))

    title_surf = font_title.render(title, True, (255, 240, 180))
    surface.blit(title_surf, (WIDTH // 2 - title_surf.get_width() // 2, title_y))

    # 팀 카드 (플레이어 - 골드)
    p_card = pygame.Rect(board_x + 35, board_y + 80, 300, 240)
    # 그라데이션
    for i in range(p_card.height):
        ratio = i / p_card.height
        r = int(80 * (1 - ratio) + 30 * ratio)
        g = int(50 * (1 - ratio) + 20 * ratio)
        b = int(20 * (1 - ratio) + 10 * ratio)
        pygame.draw.line(surface, (r, g, b),
                        (p_card.x, p_card.y + i), (p_card.x + p_card.width, p_card.y + i))

    pygame.draw.rect(surface, (255, 200, 100), p_card, 3)

    # 플레이어 아이콘 (불사조)
    px = board_x + 80
    py = board_y + 130
    pygame.draw.circle(surface, (255, 180, 80), (px, py), 25)
    pygame.draw.circle(surface, (255, 220, 150), (px, py), 20)
    p_icon = font_medium.render("P", True, (100, 50, 20))
    surface.blit(p_icon, (px - p_icon.get_width() // 2, py - p_icon.get_height() // 2))

    p_name = font_medium.render("PLAYER", True, (255, 220, 150))
    surface.blit(p_name, (board_x + 120, board_y + 115))

    # 플레이어 점수
    draw_7segment_fire(surface, board_x + 110, board_y + 170, player_score, (255, 200, 100), 120, animation_frame)

    # 보스 카드 (레드 피닉스)
    b_card = pygame.Rect(board_x + board_width - 335, board_y + 80, 300, 240)
    for i in range(b_card.height):
        ratio = i / b_card.height
        r = int(100 * (1 - ratio) + 40 * ratio)
        g = int(30 * (1 - ratio) + 15 * ratio)
        b_val = int(20 * (1 - ratio) + 10 * ratio)
        pygame.draw.line(surface, (r, g, b_val),
                        (b_card.x, b_card.y + i), (b_card.x + b_card.width, b_card.y + i))

    pygame.draw.rect(surface, (255, 120, 80), b_card, 3)

    bx = board_x + board_width - 290
    by = board_y + 130
    pygame.draw.circle(surface, (255, 100, 60), (bx, by), 25)
    pygame.draw.circle(surface, (255, 150, 100), (bx, by), 20)
    b_icon = font_medium.render("B", True, (80, 30, 20))
    surface.blit(b_icon, (bx - b_icon.get_width() // 2, by - b_icon.get_height() // 2))

    b_name = font_medium.render("PHOENIX", True, (255, 150, 100))
    surface.blit(b_name, (board_x + board_width - 250, board_y + 115))

    draw_7segment_fire(surface, board_x + board_width - 250, board_y + 170, boss_score, (255, 100, 50), 120, animation_frame)

    # VS (태양)
    vs_x = WIDTH // 2
    vs_y = board_y + 200

    # 태양 광선
    for i in range(12):
        angle = animation_frame * 0.02 + i * math.pi / 6
        length = 50 + math.sin(animation_frame * 0.1 + i) * 10
        end_x = vs_x + length * math.cos(angle)
        end_y = vs_y + length * math.sin(angle)
        pygame.draw.line(surface, (255, 200, 100), (vs_x, vs_y), (end_x, end_y), 3)

    pygame.draw.circle(surface, (255, 180, 80), (vs_x, vs_y), 35)
    pygame.draw.circle(surface, (255, 220, 150), (vs_x, vs_y), 28)
    pygame.draw.circle(surface, (255, 250, 220), (vs_x, vs_y), 20)

    vs = font_medium.render("VS", True, (150, 80, 30))
    surface.blit(vs, (vs_x - vs.get_width() // 2, vs_y - vs.get_height() // 2))

    # 하단
    footer = pygame.Rect(board_x + 30, board_y + board_height - 65, board_width - 60, 50)
    pygame.draw.rect(surface, (50, 25, 15), footer)
    pygame.draw.rect(surface, (255, 180, 100), footer, 2)

    info = font_small.render("◆ RISE FROM THE ASHES ◆", True, (255, 220, 150))
    surface.blit(info, (WIDTH // 2 - info.get_width() // 2, board_y + board_height - 50))


def draw_style4_magma_eruption(surface, player_score, boss_score, animation_frame):
    """스타일 4: 마그마 분출 (Magma Eruption)"""
    board_width = 750
    board_height = 400
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 검은 암석 배경
    pygame.draw.rect(surface, (15, 10, 10), (board_x, board_y, board_width, board_height))

    # 암석 텍스처
    rock_surf = pygame.Surface((board_width, board_height), pygame.SRCALPHA)
    random.seed(77)

    for _ in range(100):
        rx = random.randint(0, board_width)
        ry = random.randint(0, board_height)
        rsize = random.randint(5, 20)
        brightness = random.randint(10, 40)
        pygame.draw.circle(rock_surf, (brightness, brightness - 5, brightness - 5), (rx, ry), rsize)

    surface.blit(rock_surf, (board_x, board_y))

    # 마그마 분출 효과 (상단에서)
    eruption_x = WIDTH // 2
    eruption_base_y = board_y - 30

    for i in range(20):
        t = (animation_frame * 0.1 + i * 0.5) % 5
        if t < 3:  # 분출 중
            py = eruption_base_y + t * 40
            spread = t * 15
            px = eruption_x + math.sin(i * 2) * spread

            size = max(1, 8 - t * 2)
            color_idx = min(len(FIRE_COLORS) - 1, int(t * 2))
            color = FIRE_COLORS[color_idx]

            # 글로우
            glow_surf = pygame.Surface((30, 30), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*color, 100), (15, 15), int(size * 2))
            pygame.draw.circle(glow_surf, color, (15, 15), int(size))
            surface.blit(glow_surf, (px - 15, py - 15))

    # 마그마 테두리
    for i in range(5):
        pulse = 0.7 + 0.3 * math.sin(animation_frame * 0.1 + i * 0.4)
        r = int((200 + i * 10) * pulse)
        g = int((50 + i * 15) * pulse)
        pygame.draw.rect(surface, (r, g, 0), (board_x + i * 2, board_y + i * 2,
                        board_width - i * 4, board_height - i * 4), 2)

    # 화산 균열
    crack_positions = [(100, 50), (200, 300), (500, 80), (600, 350)]
    for cx, cy in crack_positions:
        pulse = 0.5 + 0.5 * math.sin(animation_frame * 0.08 + cx * 0.01)

        # 균열에서 빛
        for g in range(5, 0, -1):
            glow_surf = pygame.Surface((40, 40), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (255, 100, 0, int(30 * pulse / g)), (20, 20), g * 5)
            surface.blit(glow_surf, (board_x + cx - 20, board_y + cy - 20))

        pygame.draw.circle(surface, (255, int(150 * pulse), 50), (board_x + cx, board_y + cy), 5)

    # 타이틀 (마그마 스타일)
    title_y = board_y + 25
    title = "🌋 MAGMA ERUPTION 🌋"

    title_surf = font_title.render(title, True, (255, 180, 80))
    surface.blit(title_surf, (WIDTH // 2 - title_surf.get_width() // 2, title_y))

    # 점수 영역
    score_y = board_y + 80

    # 플레이어 (암석 + 마그마)
    p_area = pygame.Rect(board_x + 40, score_y, 280, 220)
    pygame.draw.rect(surface, (25, 15, 12), p_area)

    # 마그마 테두리 (애니메이션)
    for i in range(3):
        phase = (animation_frame * 0.03 + i * 0.5) % 1
        glow = int(150 + 105 * phase)
        pygame.draw.rect(surface, (glow, glow // 3, 0), p_area.inflate(i * 4, i * 4), 2)

    p_label = font_small.render("PLAYER", True, (255, 200, 120))
    surface.blit(p_label, (p_area.centerx - p_label.get_width() // 2, score_y + 10))

    orange_fire = (255, 180, 60)
    draw_dot_matrix_fire(surface, board_x + 85, score_y + 50, player_score, orange_fire, 150, animation_frame)

    # 보스 (진한 마그마)
    b_area = pygame.Rect(board_x + board_width - 320, score_y, 280, 220)
    pygame.draw.rect(surface, (35, 12, 10), b_area)

    for i in range(3):
        phase = (animation_frame * 0.03 + i * 0.5 + 0.3) % 1
        glow = int(150 + 105 * phase)
        pygame.draw.rect(surface, (glow, glow // 4, 0), b_area.inflate(i * 4, i * 4), 2)

    b_label = font_small.render("VOLCANO", True, (255, 120, 80))
    surface.blit(b_label, (b_area.centerx - b_label.get_width() // 2, score_y + 10))

    red_fire = (255, 100, 40)
    draw_dot_matrix_fire(surface, board_x + board_width - 225, score_y + 50, boss_score, red_fire, 150, animation_frame)

    # VS (분화구)
    vs_x = WIDTH // 2
    vs_y = score_y + 110

    # 분화구 효과
    for i in range(6, 0, -1):
        color = (200 + i * 8, 80 + i * 10, 10)
        pygame.draw.circle(surface, color, (vs_x, vs_y), 30 + i * 5, 3)

    pygame.draw.circle(surface, (50, 20, 15), (vs_x, vs_y), 30)
    # 용암 중심
    pulse = 0.7 + 0.3 * math.sin(animation_frame * 0.15)
    pygame.draw.circle(surface, (int(255 * pulse), int(120 * pulse), 20), (vs_x, vs_y), 20)
    pygame.draw.circle(surface, (255, 220, 150), (vs_x, vs_y), 10)

    vs = font_medium.render("VS", True, (80, 40, 20))
    surface.blit(vs, (vs_x - vs.get_width() // 2, vs_y - vs.get_height() // 2))

    # 하단 (뉴스 티커 스타일)
    footer = pygame.Rect(board_x + 25, board_y + board_height - 55, board_width - 50, 40)
    pygame.draw.rect(surface, (30, 15, 10), footer)
    pygame.draw.rect(surface, (200, 100, 40), footer, 2)

    info = font_small.render("◆ EXPLOSIVE BATTLE ◆", True, (255, 180, 100))
    surface.blit(info, (WIDTH // 2 - info.get_width() // 2, board_y + board_height - 45))


def draw_style5_solar_flare(surface, player_score, boss_score, animation_frame):
    """스타일 5: 태양 폭발 (Solar Flare)"""
    board_width = 780
    board_height = 420
    board_x = (WIDTH - board_width) // 2
    board_y = (HEIGHT - board_height) // 2

    # 우주 배경 (검은색 + 별)
    pygame.draw.rect(surface, (5, 3, 10), (board_x, board_y, board_width, board_height))

    random.seed(99)
    for _ in range(50):
        sx = random.randint(board_x, board_x + board_width)
        sy = random.randint(board_y, board_y + board_height)
        brightness = random.randint(100, 255)
        size = random.randint(1, 3)
        pygame.draw.circle(surface, (brightness, brightness, brightness), (sx, sy), size)

    # 태양 (중앙 뒤)
    sun_x = WIDTH // 2
    sun_y = board_y + board_height // 2

    # 코로나 (외부 발광)
    for i in range(20, 0, -1):
        pulse = 0.6 + 0.4 * math.sin(animation_frame * 0.05 + i * 0.2)
        radius = 180 + i * 15
        alpha = int(10 * pulse)

        corona_surf = pygame.Surface((radius * 2 + 20, radius * 2 + 20), pygame.SRCALPHA)
        color = (255, int(180 * pulse), 0, alpha)
        pygame.draw.circle(corona_surf, color, (radius + 10, radius + 10), radius)
        surface.blit(corona_surf, (sun_x - radius - 10, sun_y - radius - 10))

    # 태양 플레어 (불규칙한 광선)
    for i in range(24):
        angle = animation_frame * 0.01 + i * math.pi / 12
        length = 150 + math.sin(animation_frame * 0.08 + i * 0.5) * 50
        wobble = math.sin(animation_frame * 0.15 + i * 0.7) * 20

        end_x = sun_x + (length + wobble) * math.cos(angle)
        end_y = sun_y + (length + wobble) * math.sin(angle)

        # 플레어 광선
        for w in range(5, 0, -1):
            alpha = 150 // w
            flare_surf = pygame.Surface((abs(end_x - sun_x) + 50, abs(end_y - sun_y) + 50), pygame.SRCALPHA)
            color = (255, 200 - w * 30, 0, alpha)
            pygame.draw.line(surface, color, (sun_x, sun_y), (end_x, end_y), w)

    # 태양 본체
    for r in range(120, 40, -10):
        ratio = (r - 40) / 80
        g = int(200 * ratio + 255 * (1 - ratio))
        pygame.draw.circle(surface, (255, g, int(100 * (1 - ratio))), (sun_x, sun_y), r)

    pygame.draw.circle(surface, (255, 255, 230), (sun_x, sun_y), 40)

    # 반투명 오버레이 (점수판 영역)
    overlay = pygame.Surface((board_width, board_height), pygame.SRCALPHA)
    overlay.fill((0, 0, 0, 200))
    surface.blit(overlay, (board_x, board_y))

    # 프레임 (태양빛 색상)
    frame_colors = [(255, 220, 100), (255, 180, 50), (255, 140, 30), (200, 100, 20)]
    for i, color in enumerate(frame_colors):
        pygame.draw.rect(surface, color, (board_x + i * 2, board_y + i * 2,
                        board_width - i * 4, board_height - i * 4), 2)

    # 타이틀
    title_y = board_y + 25
    title = "☀ SOLAR FLARE ☀"

    # 태양빛 글로우
    for i in range(5, 0, -1):
        glow = font_title.render(title, True, (255, 200, 0))
        glow.set_alpha(40 // i)
        surface.blit(glow, (WIDTH // 2 - glow.get_width() // 2 + i * 2, title_y))
        surface.blit(glow, (WIDTH // 2 - glow.get_width() // 2 - i * 2, title_y))

    title_surf = font_title.render(title, True, (255, 255, 200))
    surface.blit(title_surf, (WIDTH // 2 - title_surf.get_width() // 2, title_y))

    # 팀 영역 (반투명 패널)
    team_y = board_y + 80

    # 플레이어 (골드-오렌지)
    p_panel = pygame.Rect(board_x + 35, team_y, 300, 250)
    p_surf = pygame.Surface((300, 250), pygame.SRCALPHA)
    p_surf.fill((40, 30, 10, 200))
    surface.blit(p_surf, p_panel.topleft)
    pygame.draw.rect(surface, (255, 200, 100), p_panel, 3)

    # 태양 아이콘
    pygame.draw.circle(surface, (255, 200, 80), (board_x + 80, team_y + 40), 25)
    pygame.draw.circle(surface, (255, 240, 180), (board_x + 80, team_y + 40), 18)

    p_name = font_medium.render("SOLAR", True, (255, 230, 150))
    surface.blit(p_name, (board_x + 115, team_y + 25))

    # 점수
    draw_7segment_fire(surface, board_x + 100, team_y + 80, player_score, (255, 220, 100), 130, animation_frame)

    # 보스 (레드-오렌지)
    b_panel = pygame.Rect(board_x + board_width - 335, team_y, 300, 250)
    b_surf = pygame.Surface((300, 250), pygame.SRCALPHA)
    b_surf.fill((50, 20, 10, 200))
    surface.blit(b_surf, b_panel.topleft)
    pygame.draw.rect(surface, (255, 120, 80), b_panel, 3)

    # 태양 폭발 아이콘
    bx = board_x + board_width - 80
    by = team_y + 40
    for i in range(8):
        angle = animation_frame * 0.05 + i * math.pi / 4
        pygame.draw.line(surface, (255, 150, 80), (bx, by),
                        (bx + 20 * math.cos(angle), by + 20 * math.sin(angle)), 3)
    pygame.draw.circle(surface, (255, 100, 50), (bx, by), 18)
    pygame.draw.circle(surface, (255, 180, 120), (bx, by), 12)

    b_name = font_medium.render("FLARE", True, (255, 150, 100))
    b_name_rect = b_name.get_rect(right=bx - 30, centery=team_y + 40)
    surface.blit(b_name, b_name_rect)

    draw_7segment_fire(surface, board_x + board_width - 265, team_y + 80, boss_score, (255, 120, 60), 130, animation_frame)

    # VS (플라즈마 링)
    vs_x = WIDTH // 2
    vs_y = team_y + 130

    # 플라즈마 링
    for i in range(5):
        angle_offset = animation_frame * 0.03 * (1 if i % 2 == 0 else -1)
        for j in range(12):
            angle = angle_offset + j * math.pi / 6
            px = vs_x + (35 + i * 5) * math.cos(angle)
            py = vs_y + (35 + i * 5) * math.sin(angle)
            color = (255, 200 - i * 30, 50 - i * 10)
            pygame.draw.circle(surface, color, (int(px), int(py)), 3 - i // 2)

    pygame.draw.circle(surface, (60, 40, 20), (vs_x, vs_y), 30)
    pygame.draw.circle(surface, (255, 220, 150), (vs_x, vs_y), 25, 3)

    vs = font_medium.render("VS", True, (255, 240, 200))
    surface.blit(vs, (vs_x - vs.get_width() // 2, vs_y - vs.get_height() // 2))

    # 하단
    footer = pygame.Rect(board_x + 30, board_y + board_height - 60, board_width - 60, 45)
    footer_surf = pygame.Surface((footer.width, footer.height), pygame.SRCALPHA)
    footer_surf.fill((30, 25, 15, 220))
    surface.blit(footer_surf, footer.topleft)
    pygame.draw.rect(surface, (255, 200, 100), footer, 2)

    # 깜빡이는 텍스트
    blink = (animation_frame // 30) % 2
    if blink:
        info = font_small.render("★ COSMIC BATTLE ★", True, (255, 230, 150))
    else:
        info = font_small.render("★ COSMIC BATTLE ★", True, (255, 180, 80))
    surface.blit(info, (WIDTH // 2 - info.get_width() // 2, board_y + board_height - 48))


def main():
    current_style = 0
    styles = [
        ("1: 지옥불 (Hell Fire)", draw_style1_hellfire),
        ("2: 용암 코어 (Lava Core)", draw_style2_lava_core),
        ("3: 불사조 블레이즈 (Phoenix)", draw_style3_phoenix_blaze),
        ("4: 마그마 분출 (Magma)", draw_style4_magma_eruption),
        ("5: 태양 폭발 (Solar Flare)", draw_style5_solar_flare),
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

        # 배경 (어두운 빨강)
        screen.fill((15, 5, 5))

        # 현재 스타일 그리기
        style_name, draw_func = styles[current_style]
        draw_func(screen, player_score, boss_score, animation_frame)

        # 안내 텍스트
        guide = font_tiny.render("← → 스타일 | ↑↓ P점수 | W/S 보스점수 | 1-5 선택 | ESC 종료", True, (150, 100, 80))
        screen.blit(guide, (20, 12))

        # 현재 스타일 이름
        style_text = font_medium.render(style_name, True, (255, 180, 80))
        style_rect = style_text.get_rect(center=(WIDTH // 2, HEIGHT - 40))

        # 배경 박스
        bg_rect = style_rect.inflate(30, 15)
        pygame.draw.rect(screen, (40, 15, 10), bg_rect, border_radius=8)
        pygame.draw.rect(screen, (255, 150, 50), bg_rect, 2, border_radius=8)
        screen.blit(style_text, style_rect)

        pygame.display.flip()
        clock.tick(60)
        animation_frame += 1

    pygame.quit()


if __name__ == "__main__":
    main()
