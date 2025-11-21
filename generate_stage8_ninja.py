"""Stage 8 닌자 저택 배경 생성기 - 아름다운 버전.

닌자 저택 분위기: 창문, 다다미 바닥, 조화로운 디자인.
스타디움 서클 정확히 중앙 정렬.
"""

import os
import sys
import math
import random

# Headless mode for background generation
os.environ['SDL_VIDEODRIVER'] = 'dummy'
os.environ['PYGAME_HIDE_SUPPORT_PROMPT'] = '1'

import pygame

# 게임 화면 크기
WIDTH = 600
HEIGHT = 700


def generate_stage8_background():
    """아름다운 닌자 저택 배경 생성."""
    pygame.init()
    surface = pygame.Surface((WIDTH, HEIGHT))

    # 1. 기본 배경 - 어두운 따뜻한 그라데이션
    for y in range(HEIGHT):
        ratio = y / HEIGHT
        r = int(22 + ratio * 10)   # 22-32
        g = int(18 + ratio * 8)    # 18-26
        b = int(20 + ratio * 6)    # 20-26
        pygame.draw.line(surface, (r, g, b), (0, y), (WIDTH, y))

    # 2. 다다미 바닥 패턴 (은은하게)
    draw_tatami_floor(surface)

    # 3. 양쪽 벽 - 창문/장지문
    draw_wall_windows(surface)

    # 4. 천장 영역 (어두운 처마)
    draw_ceiling(surface)

    # 5. 등불 (4개 코너)
    draw_lanterns(surface)

    # 6. 스타디움 라인과 서클 (정확히 중앙)
    draw_stadium_elements(surface)

    # 7. 미묘한 비네팅
    draw_vignette(surface)

    return surface


def draw_tatami_floor(surface):
    """은은한 다다미 바닥 패턴."""
    tatami_width = 90
    tatami_height = 45

    # 바닥 영역 (전체 화면에 은은하게)
    for row in range(0, HEIGHT, tatami_height):
        offset = ((row // tatami_height) % 2) * (tatami_width // 2)
        for col in range(-tatami_width, WIDTH + tatami_width, tatami_width):
            x = col + offset
            y = row

            # 다다미 색상 (매우 은은하게)
            base_brightness = 28 + (y / HEIGHT) * 8  # 아래로 갈수록 약간 밝게
            color_var = random.randint(-2, 2)
            tatami_color = (
                int(base_brightness + color_var),
                int(base_brightness - 2 + color_var),
                int(base_brightness - 4 + color_var)
            )

            # 다다미 매트 영역
            rect = pygame.Rect(x + 1, y + 1, tatami_width - 2, tatami_height - 2)
            pygame.draw.rect(surface, tatami_color, rect)

            # 다다미 테두리 (아주 은은한 라인)
            border_color = (20, 17, 15)
            pygame.draw.rect(surface, border_color,
                           pygame.Rect(x, y, tatami_width, tatami_height), 1)


def draw_wall_windows(surface):
    """양쪽 벽의 창문/장지문."""
    window_width = 50
    window_height = 120
    wall_color = (30, 25, 22)
    frame_color = (45, 38, 32)
    paper_color = (40, 36, 32)  # 어두운 창호지

    # 왼쪽 벽
    pygame.draw.rect(surface, wall_color, (0, 0, 60, HEIGHT))

    # 왼쪽 창문들
    window_positions_left = [
        (5, 80),
        (5, 280),
        (5, 480),
    ]

    for wx, wy in window_positions_left:
        # 창문 프레임
        pygame.draw.rect(surface, frame_color,
                        (wx, wy, window_width, window_height))
        # 창호지 (내부)
        pygame.draw.rect(surface, paper_color,
                        (wx + 4, wy + 4, window_width - 8, window_height - 8))
        # 창살 (세로 2개, 가로 3개)
        for i in range(1, 3):
            gx = wx + 4 + (window_width - 8) * i // 3
            pygame.draw.line(surface, frame_color, (gx, wy + 4), (gx, wy + window_height - 4), 2)
        for i in range(1, 4):
            gy = wy + 4 + (window_height - 8) * i // 4
            pygame.draw.line(surface, frame_color, (wx + 4, gy), (wx + window_width - 4, gy), 2)

    # 오른쪽 벽
    pygame.draw.rect(surface, wall_color, (WIDTH - 60, 0, 60, HEIGHT))

    # 오른쪽 창문들
    window_positions_right = [
        (WIDTH - 55, 80),
        (WIDTH - 55, 280),
        (WIDTH - 55, 480),
    ]

    for wx, wy in window_positions_right:
        pygame.draw.rect(surface, frame_color,
                        (wx, wy, window_width, window_height))
        pygame.draw.rect(surface, paper_color,
                        (wx + 4, wy + 4, window_width - 8, window_height - 8))
        for i in range(1, 3):
            gx = wx + 4 + (window_width - 8) * i // 3
            pygame.draw.line(surface, frame_color, (gx, wy + 4), (gx, wy + window_height - 4), 2)
        for i in range(1, 4):
            gy = wy + 4 + (window_height - 8) * i // 4
            pygame.draw.line(surface, frame_color, (wx + 4, gy), (wx + window_width - 4, gy), 2)


def draw_ceiling(surface):
    """천장 처마 영역 + 오동나무 닌자 저택 + 밝은 창문."""
    # === 보스 쪽 닌자 저택 배경 (오동나무 톤) ===
    mansion_height = 140  # 저택 높이

    # 오동나무 색상 팔레트
    paulownia_dark = (55, 45, 38)      # 오동나무 어두운 부분
    paulownia_mid = (70, 58, 48)       # 오동나무 중간
    paulownia_light = (85, 70, 58)     # 오동나무 밝은 부분
    paulownia_highlight = (95, 80, 65) # 하이라이트

    # 저택 벽면 기본 (오동나무 그라데이션)
    for y in range(mansion_height):
        ratio = y / mansion_height
        r = int(paulownia_dark[0] + (paulownia_mid[0] - paulownia_dark[0]) * ratio)
        g = int(paulownia_dark[1] + (paulownia_mid[1] - paulownia_dark[1]) * ratio)
        b = int(paulownia_dark[2] + (paulownia_mid[2] - paulownia_dark[2]) * ratio)
        pygame.draw.line(surface, (r, g, b), (60, y), (WIDTH - 60, y))

    # 나무 판자 무늬 (수평 라인)
    plank_color = (50, 40, 33)
    for i in range(0, mansion_height, 22):
        pygame.draw.line(surface, plank_color, (60, i), (WIDTH - 60, i), 1)

    # === 밝은 창문들 (연속으로 이어짐) ===
    window_y = 25
    window_height = 85
    window_margin = 8  # 창문 사이 간격

    # 밝은 창문 색상 (따뜻한 빛)
    window_glow_outer = (120, 100, 70)   # 외부 글로우
    window_paper = (160, 140, 100)       # 창호지 (밝은 황색)
    window_light = (200, 180, 130)       # 창문 내부 빛
    window_bright = (230, 210, 160)      # 가장 밝은 부분
    frame_color = (60, 50, 42)           # 프레임 (오동나무)

    # 5개의 연속된 창문
    total_width = WIDTH - 120 - 60  # 양쪽 벽 제외
    num_windows = 5
    window_width = (total_width - (num_windows + 1) * window_margin) // num_windows

    for i in range(num_windows):
        wx = 60 + window_margin + i * (window_width + window_margin)
        wy = window_y

        # 창문 글로우 효과 (빛이 새어나오는 느낌)
        glow_surf = pygame.Surface((window_width + 20, window_height + 20), pygame.SRCALPHA)
        for g in range(3):
            glow_alpha = 30 - g * 10
            pygame.draw.rect(glow_surf, (*window_glow_outer, glow_alpha),
                           (10 - g*3, 10 - g*3, window_width + g*6, window_height + g*6),
                           border_radius=3)
        surface.blit(glow_surf, (wx - 10, wy - 10))

        # 창문 프레임 (외부)
        pygame.draw.rect(surface, frame_color,
                        (wx - 3, wy - 3, window_width + 6, window_height + 6), border_radius=2)

        # 창호지 배경 (밝은 황색 빛)
        pygame.draw.rect(surface, window_paper,
                        (wx, wy, window_width, window_height))

        # 창문 내부 그라데이션 (중앙이 더 밝음)
        inner_surf = pygame.Surface((window_width - 6, window_height - 6), pygame.SRCALPHA)
        center_x = (window_width - 6) // 2
        center_y = (window_height - 6) // 2
        for iy in range(window_height - 6):
            for ix in range(0, window_width - 6, 3):
                dist = math.sqrt((ix - center_x)**2 + (iy - center_y)**2)
                max_dist = math.sqrt(center_x**2 + center_y**2)
                brightness = 1 - (dist / max_dist) * 0.3
                r = min(255, int(window_light[0] * brightness))
                g = min(255, int(window_light[1] * brightness))
                b = min(255, int(window_light[2] * brightness))
                pygame.draw.rect(inner_surf, (r, g, b), (ix, iy, 3, 1))
        surface.blit(inner_surf, (wx + 3, wy + 3))

        # 창살 (세로 2개, 가로 2개)
        grid_color = (70, 58, 48)
        # 세로 창살
        for j in range(1, 3):
            gx = wx + window_width * j // 3
            pygame.draw.line(surface, grid_color, (gx, wy + 2), (gx, wy + window_height - 2), 3)
        # 가로 창살
        for j in range(1, 3):
            gy = wy + window_height * j // 3
            pygame.draw.line(surface, grid_color, (wx + 2, gy), (wx + window_width - 2, gy), 3)

    # === 처마 (저택 아래 부분) ===
    eave_y = mansion_height
    eave_height = 15

    # 처마 그라데이션
    for y in range(eave_height):
        ratio = y / eave_height
        darkness = int(paulownia_dark[0] - 15 + ratio * 20)
        pygame.draw.line(surface, (darkness, darkness - 5, darkness - 8),
                        (55, eave_y + y), (WIDTH - 55, eave_y + y))

    # 처마 끝 라인 (그림자)
    pygame.draw.line(surface, (35, 28, 22), (55, eave_y + eave_height), (WIDTH - 55, eave_y + eave_height), 4)
    pygame.draw.line(surface, (45, 38, 30), (55, eave_y + eave_height + 2), (WIDTH - 55, eave_y + eave_height + 2), 2)

    # === 지붕 장식 (처마 위) ===
    # 작은 기와 느낌
    tile_color = (45, 38, 32)
    for x in range(60, WIDTH - 60, 30):
        # 기와 곡선
        pygame.draw.arc(surface, tile_color, (x, eave_y - 8, 30, 16), 0, math.pi, 2)


def draw_lanterns(surface):
    """4개 코너의 등불."""
    lantern_positions = [
        (30, 200),              # 왼쪽 상단 (창문 사이)
        (30, HEIGHT - 200),     # 왼쪽 하단
        (WIDTH - 30, 200),      # 오른쪽 상단
        (WIDTH - 30, HEIGHT - 200),  # 오른쪽 하단
    ]

    for lx, ly in lantern_positions:
        # 등불 빛 글로우
        glow_surf = pygame.Surface((80, 80), pygame.SRCALPHA)
        for radius in range(40, 5, -3):
            alpha = int(12 * (40 - radius) / 35)
            pygame.draw.circle(glow_surf, (100, 60, 25, alpha), (40, 40), radius)
        surface.blit(glow_surf, (lx - 40, ly - 40))

        # 등불 본체
        pygame.draw.rect(surface, (50, 40, 30), (lx - 6, ly - 15, 12, 25))
        pygame.draw.rect(surface, (90, 60, 30), (lx - 4, ly - 12, 8, 19))
        # 등불 고리
        pygame.draw.rect(surface, (40, 35, 28), (lx - 8, ly - 17, 16, 3))
        # 등불 줄
        pygame.draw.line(surface, (35, 30, 25), (lx, ly - 17), (lx, ly - 40), 1)


def draw_stadium_elements(surface):
    """스타디움 라인과 서클 - 정확히 중앙."""
    # 정확한 중앙 좌표
    center_x = WIDTH // 2  # 300
    center_y = HEIGHT // 2  # 350

    stadium_color = (90, 40, 40)
    stadium_light = (110, 50, 50)

    # 중앙 가로선
    pygame.draw.line(surface, stadium_color, (60, center_y), (WIDTH - 60, center_y), 2)

    # 중앙 서클 (정확히 중앙)
    pygame.draw.circle(surface, stadium_color, (center_x, center_y), 80, 3)

    # 내부 장식 원
    pygame.draw.circle(surface, stadium_light, (center_x, center_y), 75, 1)

    # 중앙 점
    pygame.draw.circle(surface, stadium_color, (center_x, center_y), 5)
    pygame.draw.circle(surface, stadium_light, (center_x, center_y), 3)


def draw_vignette(surface):
    """미묘한 비네팅 효과."""
    vignette = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
    center_x, center_y = WIDTH // 2, HEIGHT // 2
    max_dist = math.sqrt(center_x**2 + center_y**2)

    for y in range(0, HEIGHT, 6):
        for x in range(0, WIDTH, 6):
            dist = math.sqrt((x - center_x)**2 + (y - center_y)**2)
            alpha = int((dist / max_dist) * 25)
            pygame.draw.rect(vignette, (0, 0, 0, alpha), (x, y, 6, 6))

    surface.blit(vignette, (0, 0))


def main():
    """메인 실행 함수."""
    pygame.display.set_mode((1, 1), pygame.HIDDEN)

    background = generate_stage8_background()

    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "stage8_field.png")
    pygame.image.save(background, output_path)

    print(f"Stage 8 background saved to: {output_path}")
    pygame.quit()


if __name__ == "__main__":
    main()
