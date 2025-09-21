#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test script for Evangelion-style Smasher paddle"""

import pygame
import sys
import os
import math

# 리소스 경로 설정
def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

# Pygame 초기화
pygame.init()
SCREEN = pygame.display.set_mode((800, 600))
pygame.display.set_caption("Evangelion Smasher Paddle Test")

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
BG_COLOR = (30, 30, 40)

# 스매셔 패들 이미지 생성 (에반게리온 스타일)
SMASHER_PADDLE_IMG = pygame.Surface((250, 120), pygame.SRCALPHA)

# 중심점 설정 (항공샷 뷰)
eva_center_x = 125
eva_center_y = 60

# === EVA 파일럿 슈트 몸체 (상체, 정수리 뷰) ===
# 플러그슈트 본체 (보라색-검은색 계열)
body_color = (75, 50, 110)  # 어두운 보라색
pygame.draw.ellipse(SMASHER_PADDLE_IMG, body_color, 
                    (eva_center_x - 35, eva_center_y - 25, 70, 50))

# 플러그슈트 디테일 라인 (네온 느낌)
detail_color = (150, 100, 200)  # 밝은 보라색
pygame.draw.arc(SMASHER_PADDLE_IMG, detail_color, 
                (eva_center_x - 35, eva_center_y - 25, 70, 50), 
                0, 3.14159, 2)

# === 헬멧과 머리 (정수리 뷰) ===
# 헬멧 본체
helmet_color = (60, 60, 70)  # 어두운 회색
pygame.draw.circle(SMASHER_PADDLE_IMG, helmet_color, 
                   (eva_center_x, eva_center_y - 15), 20)

# 헬멧 바이저 (빨간색 - 에반게리온 시그니처)
visor_color = (220, 50, 50)  # 선명한 빨간색
pygame.draw.arc(SMASHER_PADDLE_IMG, visor_color,
                (eva_center_x - 15, eva_center_y - 25, 30, 20),
                3.14159, 0, 3)

# 바이저 광택 효과
glare_color = (255, 150, 150)  # 밝은 빨간색
pygame.draw.circle(SMASHER_PADDLE_IMG, glare_color,
                   (eva_center_x - 8, eva_center_y - 20), 3)

# === 왼팔과 탁구채 (미래지향적 디자인) ===
# 왼팔 (플러그슈트)
arm_color = (70, 45, 105)  # 팔 색상
# 어깨에서 팔꿈치까지
pygame.draw.polygon(SMASHER_PADDLE_IMG, arm_color, [
    (eva_center_x - 30, eva_center_y - 5),  # 어깨
    (eva_center_x - 50, eva_center_y + 10),  # 팔꿈치
    (eva_center_x - 45, eva_center_y + 15),
    (eva_center_x - 25, eva_center_y)
])

# 팔꿈치에서 손목까지
pygame.draw.polygon(SMASHER_PADDLE_IMG, arm_color, [
    (eva_center_x - 50, eva_center_y + 10),
    (eva_center_x - 65, eva_center_y + 25),  # 손목
    (eva_center_x - 60, eva_center_y + 30),
    (eva_center_x - 45, eva_center_y + 15)
])

# 네온 라인 디테일 (팔)
neon_color = (200, 150, 255)  # 네온 보라색
pygame.draw.line(SMASHER_PADDLE_IMG, neon_color,
                 (eva_center_x - 30, eva_center_y - 5),
                 (eva_center_x - 65, eva_center_y + 25), 1)

# === 미래지향적 탁구채 ===
# 탁구채 손잡이 (에너지 블레이드 느낌)
handle_color = (100, 100, 120)  # 메탈릭 회색
pygame.draw.rect(SMASHER_PADDLE_IMG, handle_color,
                 (eva_center_x - 75, eva_center_y + 22, 15, 6))

# 탁구채 면 (육각형 - 미래적 디자인)
paddle_color = (50, 200, 255)  # 청록색 (에너지 느낌)
paddle_points = [
    (eva_center_x - 90, eva_center_y + 25),  # 왼쪽 중앙
    (eva_center_x - 87, eva_center_y + 15),  # 왼쪽 위
    (eva_center_x - 77, eva_center_y + 10),  # 오른쪽 위
    (eva_center_x - 70, eva_center_y + 15),  # 오른쪽 중앙
    (eva_center_x - 73, eva_center_y + 35),  # 오른쪽 아래
    (eva_center_x - 87, eva_center_y + 40)   # 왼쪽 아래
]
pygame.draw.polygon(SMASHER_PADDLE_IMG, paddle_color, paddle_points)

# 탁구채 가장자리 (에너지 효과)
edge_color = (100, 255, 255)  # 밝은 청록색
pygame.draw.polygon(SMASHER_PADDLE_IMG, edge_color, paddle_points, 2)

# 탁구채 중앙 코어 (빛나는 효과)
core_color = (200, 255, 255)  # 매우 밝은 청록색
pygame.draw.circle(SMASHER_PADDLE_IMG, core_color,
                   (eva_center_x - 80, eva_center_y + 25), 5)

# === 오른팔 (자연스러운 자세) ===
# 오른팔은 몸 옆에 자연스럽게 위치
pygame.draw.polygon(SMASHER_PADDLE_IMG, arm_color, [
    (eva_center_x + 30, eva_center_y - 5),   # 어깨
    (eva_center_x + 45, eva_center_y + 8),   # 팔꿈치
    (eva_center_x + 40, eva_center_y + 13),
    (eva_center_x + 25, eva_center_y)
])

# === 보스 방향 표시 (방향성) ===
# 전방을 향한 시선 표시 (V자 형태)
direction_color = (255, 200, 100)  # 주황색
pygame.draw.lines(SMASHER_PADDLE_IMG, direction_color, False, [
    (eva_center_x - 10, eva_center_y - 35),
    (eva_center_x, eva_center_y - 45),
    (eva_center_x + 10, eva_center_y - 35)
], 2)

# === AT 필드 효과 (육각형 패턴) ===
# 플레이어 주변에 희미한 육각형 패턴
at_field_color = (150, 100, 200, 50)  # 반투명 보라색
hexagon_surface = pygame.Surface((250, 120), pygame.SRCALPHA)

# 작은 육각형들로 AT 필드 표현
hex_positions = [(40, 30), (80, 20), (120, 35), (160, 25), (200, 30),
                 (60, 60), (100, 70), (140, 65), (180, 70),
                 (50, 90), (90, 100), (130, 95), (170, 90)]

for hx, hy in hex_positions:
    hex_points = []
    for i in range(6):
        angle = 3.14159 * 2 * i / 6
        px = hx + 8 * math.cos(angle)
        py = hy + 8 * math.sin(angle)
        hex_points.append((px, py))
    pygame.draw.polygon(hexagon_surface, at_field_color, hex_points, 1)

SMASHER_PADDLE_IMG.blit(hexagon_surface, (0, 0))

# 테스트 실행
clock = pygame.time.Clock()
running = True
rotation = 0
show_grid = True
show_original = False
scale = 2.0

# 원본 UFO 이미지도 생성하여 비교
ORIGINAL_UFO = pygame.Surface((250, 100), pygame.SRCALPHA)
pygame.draw.ellipse(ORIGINAL_UFO, (0, 255, 0), (50, 20, 150, 60))
pygame.draw.circle(ORIGINAL_UFO, (255, 255, 0), (125, 50), 15)

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                show_original = not show_original
            elif event.key == pygame.K_g:
                show_grid = not show_grid
            elif event.key == pygame.K_UP:
                scale = min(scale + 0.1, 5.0)
            elif event.key == pygame.K_DOWN:
                scale = max(scale - 0.1, 0.5)
            elif event.key == pygame.K_r:
                rotation = 0
    
    # 키 입력으로 회전
    keys = pygame.key.get_pressed()
    if keys[pygame.K_LEFT]:
        rotation -= 2
    if keys[pygame.K_RIGHT]:
        rotation += 2
    
    # 화면 그리기
    SCREEN.fill(BG_COLOR)
    
    # 그리드 표시
    if show_grid:
        for x in range(0, 800, 50):
            pygame.draw.line(SCREEN, (50, 50, 60), (x, 0), (x, 600), 1)
        for y in range(0, 600, 50):
            pygame.draw.line(SCREEN, (50, 50, 60), (0, y), (800, y), 1)
    
    # 패들 이미지 표시
    if show_original:
        display_img = ORIGINAL_UFO
        title = "Original UFO Paddle"
    else:
        display_img = SMASHER_PADDLE_IMG
        title = "Evangelion Smasher Paddle"
    
    # 회전 및 스케일 적용
    scaled_img = pygame.transform.scale(display_img, 
                                        (int(display_img.get_width() * scale),
                                         int(display_img.get_height() * scale)))
    rotated_img = pygame.transform.rotate(scaled_img, rotation)
    
    # 중앙에 표시
    img_rect = rotated_img.get_rect(center=(400, 300))
    SCREEN.blit(rotated_img, img_rect)
    
    # 정보 텍스트
    font = pygame.font.Font(None, 36)
    title_text = font.render(title, True, WHITE)
    SCREEN.blit(title_text, (400 - title_text.get_width() // 2, 50))
    
    # 조작 안내
    font_small = pygame.font.Font(None, 24)
    instructions = [
        "Space: Toggle Original/Evangelion",
        "Left/Right: Rotate",
        "Up/Down: Scale",
        "G: Toggle Grid",
        "R: Reset Rotation",
        f"Rotation: {rotation}°, Scale: {scale:.1f}x"
    ]
    
    y_pos = 450
    for instruction in instructions:
        text = font_small.render(instruction, True, WHITE)
        SCREEN.blit(text, (400 - text.get_width() // 2, y_pos))
        y_pos += 25
    
    pygame.display.flip()
    clock.tick(60)

pygame.quit()
sys.exit()