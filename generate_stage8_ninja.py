"""Stage 8 닌자 저택 배경 생성기 - 깔끔한 버전 v2.

사각형 패턴 없이 부드러운 그라데이션 기반의 어두운 분위기.
게임 오브젝트와 균형을 맞추기 위해 최소한의 디테일만 사용.
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
    """깔끔한 닌자 저택 배경 생성 - 미니멀 버전."""
    pygame.init()
    surface = pygame.Surface((WIDTH, HEIGHT))

    # 1. 기본 배경 - 부드러운 수직 그라데이션 (아주 어두운 색상)
    for y in range(HEIGHT):
        ratio = y / HEIGHT
        # 상단: 약간 푸른 어둠, 하단: 따뜻한 어둠
        r = int(18 + ratio * 8)   # 18-26
        g = int(15 + ratio * 10)  # 15-25
        b = int(22 + ratio * 5)   # 22-27
        pygame.draw.line(surface, (r, g, b), (0, y), (WIDTH, y))

    # 2. 미묘한 비네팅 효과 (모서리 어둡게)
    vignette = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
    center_x, center_y = WIDTH // 2, HEIGHT // 2
    max_dist = math.sqrt(center_x**2 + center_y**2)

    for y in range(0, HEIGHT, 4):  # 성능을 위해 4픽셀 단위
        for x in range(0, WIDTH, 4):
            dist = math.sqrt((x - center_x)**2 + (y - center_y)**2)
            alpha = int((dist / max_dist) * 35)  # 최대 35 알파
            pygame.draw.rect(vignette, (0, 0, 0, alpha), (x, y, 4, 4))

    surface.blit(vignette, (0, 0))

    # 3. 등불 위치 (4개의 코너에 은은한 빛)
    lantern_positions = [
        (35, 195),              # 왼쪽 상단
        (35, HEIGHT - 205),     # 왼쪽 하단
        (WIDTH - 35, 195),      # 오른쪽 상단
        (WIDTH - 35, HEIGHT - 205),  # 오른쪽 하단
    ]

    # 등불 빛 글로우 (매우 은은하게)
    for lx, ly in lantern_positions:
        glow = pygame.Surface((120, 120), pygame.SRCALPHA)
        for radius in range(60, 5, -5):
            alpha = int(8 * (60 - radius) / 55)  # 최대 8 알파
            color = (80, 50, 30, alpha)
            pygame.draw.circle(glow, color, (60, 60), radius)
        surface.blit(glow, (lx - 60, ly - 60))

    # 4. 등불 본체 (작은 사각형 - 매우 심플)
    for lx, ly in lantern_positions:
        # 등불 몸체
        lantern_color = (60, 45, 35)
        pygame.draw.rect(surface, lantern_color, (lx - 8, ly - 20, 16, 30))
        # 등불 빛 (중심)
        light_color = (100, 70, 40)
        pygame.draw.rect(surface, light_color, (lx - 5, ly - 15, 10, 20))
        # 등불 고리
        pygame.draw.rect(surface, (50, 40, 30), (lx - 10, ly - 22, 20, 3))
        # 등불 줄
        pygame.draw.line(surface, (40, 35, 30), (lx, ly - 22), (lx, ly - 50), 1)

    # 5. 스타디움 라인 (진한 붉은색)
    stadium_color = (100, 40, 40)
    center_y = HEIGHT // 2

    # 중앙 가로선
    pygame.draw.line(surface, stadium_color, (0, center_y), (WIDTH, center_y), 2)

    # 중앙 원
    pygame.draw.circle(surface, stadium_color, (WIDTH // 2, center_y), 80, 3)

    # 중앙 점
    pygame.draw.circle(surface, stadium_color, (WIDTH // 2, center_y), 5)

    # 6. 중앙 원 안의 십자 표시 (닌자 수리검 느낌)
    cx, cy = WIDTH // 2, center_y
    cross_color = (80, 35, 35)
    # 대각선 십자
    for angle in [45, 135, 225, 315]:
        rad = math.radians(angle)
        x1 = cx + int(math.cos(rad) * 15)
        y1 = cy + int(math.sin(rad) * 15)
        x2 = cx + int(math.cos(rad) * 50)
        y2 = cy + int(math.sin(rad) * 50)
        pygame.draw.line(surface, cross_color, (x1, y1), (x2, y2), 1)

    return surface


def main():
    """메인 실행 함수"""
    # 더미 디스플레이 (headless)
    pygame.display.set_mode((1, 1), pygame.HIDDEN)

    # 배경 생성
    background = generate_stage8_background()

    # 저장
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_path = os.path.join(script_dir, "stage8_field.png")
    pygame.image.save(background, output_path)

    print(f"Stage 8 background saved to: {output_path}")

    pygame.quit()


if __name__ == "__main__":
    main()
