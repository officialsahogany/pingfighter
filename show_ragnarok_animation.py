#!/usr/bin/env python3
"""
라그나로크 해머 애니메이션 구성 요소 뷰어
각 레이어를 개별적으로 표시합니다.
"""

import pygame
import sys
import math
import random
import os

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH = 900
HEIGHT = 600
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("라그나로크 해머 - 애니메이션 레이어 분석")

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (220, 50, 50)
YELLOW = (255, 255, 150)
BLUE = (100, 150, 255)
GRAY = (150, 150, 150)
DARK_GRAY = (50, 50, 50)

# 폰트 설정
font_title = pygame.font.Font(None, 36)
font_label = pygame.font.Font(None, 24)
font_info = pygame.font.Font(None, 20)

def resource_path(relative_path):
    """리소스 경로 얻기"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))

    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

def draw_hammer_icon(surface, x, y, size, frame_index):
    """해머 아이콘 그리기 (8프레임 애니메이션 시뮬레이션)"""
    # 해머 본체
    hammer_color = (120, 80, 40) if frame_index < 4 else (140, 90, 50)

    # 해머 헤드
    hammer_rect = pygame.Rect(x + size//4, y + size//3, size//2, size//3)
    pygame.draw.rect(surface, hammer_color, hammer_rect)
    pygame.draw.rect(surface, (80, 50, 20), hammer_rect, 2)

    # 해머 손잡이
    handle_rect = pygame.Rect(x + size//2 - 5, y + size//2, 10, size//3)
    pygame.draw.rect(surface, (60, 40, 20), handle_rect)

    # 해머 장식
    if frame_index in [0, 4]:  # 특정 프레임에서 반짝임
        pygame.draw.circle(surface, (255, 220, 100), (x + size//2, y + size//2), 5)

def draw_blue_background_frame(surface, x, y, size, animation_time):
    """파란색 원형 배경 프레임 (전설 아이템 공통)"""
    # 펄싱 효과
    pulse = (math.sin(animation_time * 4.0) + 1) / 2

    # 외부 글로우
    outer_radius = int(size * 0.45 + size * 0.05 * pulse)
    inner_radius = int(outer_radius * 0.65)

    # 겹쳐진 원으로 글로우 효과
    glow_surf = pygame.Surface((size, size), pygame.SRCALPHA)
    center = (size // 2, size // 2)

    pygame.draw.circle(glow_surf, (30, 90, 170, 80), center, outer_radius)
    pygame.draw.circle(glow_surf, (70, 140, 200, 150), center, int(outer_radius * 0.85))
    pygame.draw.circle(glow_surf, (140, 190, 220, 190), center, inner_radius)

    surface.blit(glow_surf, (x, y))

def draw_red_border(surface, x, y, size, animation_time):
    """붉은색 테두리 (내부 + 외부)"""
    # 펄싱 효과
    pulse = (math.sin(animation_time * 6.0) + 1) / 2

    # 외부 테두리
    outer_color = (220, 50, 50)
    border_rect = pygame.Rect(x - 2, y - 2, size + 4, size + 4)
    pygame.draw.rect(surface, outer_color, border_rect, 3)

    # 내부 그라데이션 테두리
    inner_color = (
        int(150 + 70 * pulse),
        int(30 + 35 * pulse),
        int(30 + 35 * pulse)
    )
    inner_rect = pygame.Rect(x + 2, y + 2, size - 4, size - 4)
    pygame.draw.rect(surface, inner_color, inner_rect, 2)

def draw_lightning_effect(surface, x, y, size, frame_index):
    """번개 효과 애니메이션"""
    # 프레임 0, 4에서만 번개 표시
    if frame_index in [0, 4]:
        bolt_color = YELLOW

        # 왼쪽 번개
        points1 = [
            (x + size//4, y - 5),
            (x + size//3, y + size//4),
            (x + size//4 + 10, y + size//3),
            (x + size//3 + 5, y + size//2)
        ]
        pygame.draw.lines(surface, bolt_color, False, points1, 3)

        # 오른쪽 번개
        points2 = [
            (x + size*3//4, y - 5),
            (x + size*2//3, y + size//4),
            (x + size*3//4 - 10, y + size//3),
            (x + size*2//3 - 5, y + size//2)
        ]
        pygame.draw.lines(surface, bolt_color, False, points2, 3)

        # 번개 글로우
        for point in points1 + points2:
            pygame.draw.circle(surface, (255, 255, 200, 100), point, 3)

def draw_glow_effect(surface, x, y, size, animation_time):
    """글로우 효과"""
    glow_intensity = (math.sin(animation_time * 3) + 1) * 0.5
    glow_size = int(size * (1.3 + glow_intensity * 0.2))

    glow_surf = pygame.Surface((glow_size, glow_size), pygame.SRCALPHA)

    for i in range(4):
        alpha = int(100 - i * 20)
        radius = glow_size // 2 - i * 8
        color = (220, 100, 100, alpha)
        pygame.draw.circle(glow_surf, color, (glow_size // 2, glow_size // 2), radius)

    surface.blit(glow_surf, (x - (glow_size - size) // 2, y - (glow_size - size) // 2))

def draw_particles(surface, x, y, size, animation_time):
    """파티클 효과"""
    random.seed(int(animation_time * 10))

    for _ in range(8):
        px = x + size // 2 + random.randint(-40, 40)
        py = y + size // 2 + random.randint(-40, 40)
        particle_size = random.randint(1, 3)
        particle_color = random.choice([(255, 200, 100), (255, 150, 50), (255, 100, 100)])
        pygame.draw.circle(surface, particle_color, (px, py), particle_size)

def draw_complete_animation(surface, x, y, size, animation_time, frame_index):
    """모든 레이어를 합친 완성된 애니메이션"""
    # 1. 글로우 효과 (가장 아래)
    draw_glow_effect(surface, x, y, size, animation_time)

    # 2. 파란색 배경 프레임
    draw_blue_background_frame(surface, x, y, size, animation_time)

    # 3. 붉은색 테두리
    draw_red_border(surface, x, y, size, animation_time)

    # 4. 해머 아이콘
    draw_hammer_icon(surface, x, y, size, frame_index)

    # 5. 번개 효과
    draw_lightning_effect(surface, x, y, size, frame_index)

    # 6. 파티클 (가장 위)
    draw_particles(surface, x, y, size, animation_time)

def main():
    clock = pygame.time.Clock()
    running = True

    # 애니메이션 변수
    animation_time = 0
    frame_counter = 0
    current_frame = 0
    animation_speed = 8  # 8틱마다 프레임 변경

    # 레이어 정보
    layers = [
        {"name": "해머 아이콘", "x": 100, "y": 150, "draw": draw_hammer_icon},
        {"name": "파란 배경프레임", "x": 250, "y": 150, "draw": draw_blue_background_frame},
        {"name": "붉은 테두리", "x": 400, "y": 150, "draw": draw_red_border},
        {"name": "번개 애니메이션", "x": 550, "y": 150, "draw": draw_lightning_effect},
        {"name": "글로우 효과", "x": 700, "y": 150, "draw": draw_glow_effect},
        {"name": "파티클 효과", "x": 175, "y": 350, "draw": draw_particles},
        {"name": "완성된 조합", "x": 475, "y": 350, "draw": draw_complete_animation},
    ]

    icon_size = 100

    while running:
        dt = clock.tick(60) / 1000.0
        animation_time += dt
        frame_counter += 1

        # 프레임 업데이트
        if frame_counter >= animation_speed:
            frame_counter = 0
            current_frame = (current_frame + 1) % 8

        # 화면 초기화
        SCREEN.fill((30, 30, 40))

        # 타이틀
        title = font_title.render("라그나로크 해머 - 애니메이션 구성 요소", True, WHITE)
        title_rect = title.get_rect(center=(WIDTH // 2, 50))
        SCREEN.blit(title, title_rect)

        # 각 레이어 그리기
        for layer in layers:
            # 레이어 배경
            layer_bg = pygame.Rect(layer["x"] - 10, layer["y"] - 10, icon_size + 20, icon_size + 20)
            pygame.draw.rect(SCREEN, DARK_GRAY, layer_bg)
            pygame.draw.rect(SCREEN, GRAY, layer_bg, 2)

            # 레이어 컨텐츠 그리기
            if layer["name"] == "해머 아이콘":
                layer["draw"](SCREEN, layer["x"], layer["y"], icon_size, current_frame)
            elif layer["name"] == "번개 애니메이션":
                layer["draw"](SCREEN, layer["x"], layer["y"], icon_size, current_frame)
            elif layer["name"] == "완성된 조합":
                layer["draw"](SCREEN, layer["x"], layer["y"], icon_size, animation_time, current_frame)
            else:
                layer["draw"](SCREEN, layer["x"], layer["y"], icon_size, animation_time)

            # 레이어 이름
            label = font_label.render(layer["name"], True, WHITE)
            label_rect = label.get_rect(center=(layer["x"] + icon_size // 2, layer["y"] + icon_size + 25))
            SCREEN.blit(label, label_rect)

        # 프레임 정보
        frame_info = font_info.render(f"프레임: {current_frame + 1}/8", True, WHITE)
        SCREEN.blit(frame_info, (WIDTH // 2 - 50, HEIGHT - 50))

        # 안내 메시지
        help_text = font_info.render("ESC - 종료", True, GRAY)
        SCREEN.blit(help_text, (WIDTH // 2 - 40, HEIGHT - 25))

        pygame.display.flip()

        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()