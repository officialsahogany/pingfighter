#!/usr/bin/env python3
"""
Test actual player position in game
게임에서 실제 플레이어 위치 확인
"""

import pygame
import sys

# Initialize Pygame
pygame.init()

# Typical game screen size
WIDTH, HEIGHT = 800, 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Player Position Test")

# Player paddle properties (matching game constants)
PADDLE_WIDTH = 155
PADDLE_HEIGHT = 50

# Create player paddle (typically on left side)
PLAYER = pygame.Rect(5, HEIGHT // 2 - PADDLE_HEIGHT // 2, PADDLE_WIDTH, PADDLE_HEIGHT)

print("=" * 60)
print("플레이어 패들 위치 정보:")
print("-" * 60)
print(f"화면 크기: {WIDTH} x {HEIGHT}")
print(f"패들 크기: {PADDLE_WIDTH} x {PADDLE_HEIGHT}")
print(f"PLAYER.left: {PLAYER.left}")
print(f"PLAYER.centerx: {PLAYER.centerx}")  # 이것이 플레이어 중심 X 좌표
print(f"PLAYER.right: {PLAYER.right}")
print(f"PLAYER.centery: {PLAYER.centery}")
print("-" * 60)
print(f"플레이어 중심 X 좌표: {PLAYER.centerx}")
print("게임에서 일반적으로 플레이어는 왼쪽에 위치합니다.")
print("=" * 60)

# 공이 다양한 위치에 있을 때 거리 계산
ball_positions = [
    (100, 300),
    (200, 300),
    (400, 300),
    (600, 300),
    (700, 300)
]

print("\n공 위치별 X축 거리:")
print("-" * 60)
for ball_x, ball_y in ball_positions:
    x_distance = ball_x - PLAYER.centerx
    print(f"공 위치: ({ball_x}, {ball_y}) -> X거리: {x_distance}")
    if x_distance <= 600:
        print(f"  => 위험 감지! (600픽셀 이내)")
    else:
        print(f"  => 안전 (600픽셀 밖)")

pygame.quit()