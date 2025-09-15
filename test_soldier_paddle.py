#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test script for soldier paddle image"""

import pygame
import math
import random

# Initialize Pygame
pygame.init()

# Create a test window
WIDTH, HEIGHT = 800, 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Soldier Paddle Test")

# Colors
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
GRAY = (128, 128, 128)

# Create soldier paddle image (increased height for full body with legs)
SOLDIER_PADDLE_IMG = pygame.Surface((250, 150), pygame.SRCALPHA)

# 중심점 설정
center_x = 125
center_y = 50

# === 헬멧 (위에서 본 각도 - 정수리 중심) ===
helmet_center_y = center_y - 15  # 머리가 더 위쪽에 위치
# 헬멧 정수리 (원형으로 표현)
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (50, 70, 30), 
                    (center_x - 25, helmet_center_y - 20, 50, 40))
# 헬멧 내부 원 (더 어두운 색)
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (40, 60, 25), 
                    (center_x - 20, helmet_center_y - 15, 40, 30))
# 헬멧 중앙 패턴 (정수리 부분)
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (45, 65, 28), 
                    (center_x - 12, helmet_center_y - 10, 24, 20))
# 헬멧 하이라이트
pygame.draw.arc(SOLDIER_PADDLE_IMG, (70, 90, 50), 
                (center_x - 23, helmet_center_y - 18, 46, 36), 
                math.radians(220), math.radians(320), 2)

# 헬멧 통풍구 (정수리 디테일)
for angle in [0, 120, 240]:
    rad = math.radians(angle)
    vent_x = center_x + int(8 * math.cos(rad))
    vent_y = helmet_center_y - 5 + int(6 * math.sin(rad))
    pygame.draw.circle(SOLDIER_PADDLE_IMG, (35, 55, 20), (vent_x, vent_y), 2)

# === 머리/얼굴 (헬멧 아래 살짝 보이는 부분) ===
# 뒷머리와 목 부분
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (190, 150, 120), 
                    (center_x - 15, helmet_center_y + 10, 30, 20))

# === 군복 상체 (위에서 본 각도) ===
body_y = helmet_center_y + 25
# 어깨 (넓게 펼쳐진 모습)
shoulder_points = [
    (center_x - 45, body_y),        # 왼쪽 어깨 끝
    (center_x - 35, body_y - 5),    # 왼쪽 어깨 위
    (center_x - 20, body_y - 8),    # 왼쪽 목 연결부
    (center_x + 20, body_y - 8),    # 오른쪽 목 연결부
    (center_x + 35, body_y - 5),    # 오른쪽 어깨 위
    (center_x + 45, body_y),        # 오른쪽 어깨 끝
    (center_x + 48, body_y + 15),   # 오른쪽 몸통
    (center_x + 40, body_y + 30),   # 오른쪽 하단
    (center_x - 40, body_y + 30),   # 왼쪽 하단
    (center_x - 48, body_y + 15)    # 왼쪽 몸통
]
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (100, 90, 50), shoulder_points)

# 군복 중앙 지퍼
pygame.draw.line(SOLDIER_PADDLE_IMG, (70, 60, 30), 
                 (center_x, body_y - 5), (center_x, body_y + 25), 2)

# 가슴 주머니 (위에서 본 각도)
pygame.draw.rect(SOLDIER_PADDLE_IMG, (80, 70, 40), 
                 (center_x - 25, body_y + 5, 18, 10))
pygame.draw.rect(SOLDIER_PADDLE_IMG, (80, 70, 40), 
                 (center_x + 7, body_y + 5, 18, 10))

# 계급장 (어깨 위)
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (130, 110, 40), [
    (center_x - 40, body_y - 3),
    (center_x - 28, body_y - 5),
    (center_x - 28, body_y + 2),
    (center_x - 40, body_y + 4)
])
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (130, 110, 40), [
    (center_x + 28, body_y - 5),
    (center_x + 40, body_y - 3),
    (center_x + 40, body_y + 4),
    (center_x + 28, body_y + 2)
])

# === 왼팔 (탁구채 들고 있음 - 전방을 향해) ===
left_arm_x = center_x - 30
left_arm_y = body_y - 20  # 팔이 앞쪽으로 뻗어있음
# 왼쪽 팔 (앞으로 뻗은 모습)
arm_points = [
    (center_x - 35, body_y - 2),      # 어깨 시작
    (center_x - 40, body_y),          # 어깨 외곽
    (left_arm_x - 8, left_arm_y),     # 팔꿈치
    (left_arm_x - 5, left_arm_y - 15),# 손목
    (left_arm_x + 5, left_arm_y - 15),# 손목 안쪽
    (left_arm_x + 8, left_arm_y),     # 팔꿈치 안쪽
    (center_x - 25, body_y - 4)       # 어깨 안쪽
]
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (110, 95, 55), arm_points)

# 왼손 (탁구채를 잡고 있음)
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (200, 160, 130), 
                    (left_arm_x - 8, left_arm_y - 20, 16, 14))

# === 군용 탁구채 (전방을 향해) ===
paddle_x = left_arm_x
paddle_y = left_arm_y - 35
# 탁구채 면 (타원형 - 전방을 향한 각도)
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (60, 80, 40), 
                    (paddle_x - 18, paddle_y - 15, 36, 45))
# 탁구채 고무 (빨간색)
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (120, 30, 20), 
                    (paddle_x - 14, paddle_y - 11, 28, 37))
# 탁구채 중앙 원
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (100, 25, 15), 
                    (paddle_x - 8, paddle_y - 5, 16, 20))
# 탁구채 손잡이 (일부만 보임)
pygame.draw.rect(SOLDIER_PADDLE_IMG, (80, 40, 20), 
                 (paddle_x - 4, paddle_y + 28, 8, 15))

# === 오른팔 (자연스럽게 옆에) ===
right_arm_x = center_x + 35
right_arm_y = body_y + 5
# 오른팔
arm_points_right = [
    (center_x + 35, body_y - 2),
    (center_x + 40, body_y),
    (right_arm_x + 5, right_arm_y + 10),
    (right_arm_x, right_arm_y + 18),
    (right_arm_x - 8, right_arm_y + 15),
    (right_arm_x - 5, right_arm_y + 5),
    (center_x + 25, body_y - 4)
]
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (110, 95, 55), arm_points_right)

# 오른손
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (200, 160, 130), 
                    (right_arm_x - 5, right_arm_y + 15, 12, 10))

# === 위장 패턴 (위에서 본 각도) ===
# 몸통에 카무플라주 패턴 추가
camo_colors = [(70, 60, 30), (90, 80, 40), (80, 70, 35)]
for i in range(8):
    camo_x = center_x - 30 + (i % 3) * 20 + random.randint(-5, 5)
    camo_y = body_y - 5 + (i // 3) * 10 + random.randint(-3, 3)
    camo_size = random.randint(8, 15)
    pygame.draw.ellipse(SOLDIER_PADDLE_IMG, camo_colors[i % 3], 
                        (camo_x, camo_y, camo_size, camo_size - 2))

# 어깨 위장 패턴
for i in range(4):
    camo_x = center_x - 40 + i * 20 + random.randint(-3, 3)
    camo_y = body_y - 2 + random.randint(-2, 2)
    pygame.draw.circle(SOLDIER_PADDLE_IMG, camo_colors[i % 3], 
                       (camo_x, camo_y), random.randint(3, 6))

# === 추가 디테일 ===
# 군복 주름 (위에서 본 각도로 간략화)
pygame.draw.line(SOLDIER_PADDLE_IMG, (70, 60, 30), 
                 (center_x - 15, body_y + 10), (center_x - 18, body_y + 20), 1)
pygame.draw.line(SOLDIER_PADDLE_IMG, (70, 60, 30), 
                 (center_x + 15, body_y + 10), (center_x + 18, body_y + 20), 1)

# === 다리 (위에서 본 각도 - 스매셔처럼 전체 몸이 보이도록) ===
# 하체 위치 설정
hip_y = body_y + 30  # 몸통 아래에서 시작

# 벨트 부분
pygame.draw.rect(SOLDIER_PADDLE_IMG, (50, 40, 20), 
                 (center_x - 30, hip_y - 2, 60, 5))
# 벨트 버클
pygame.draw.rect(SOLDIER_PADDLE_IMG, (120, 100, 40), 
                 (center_x - 8, hip_y - 3, 16, 7))
pygame.draw.rect(SOLDIER_PADDLE_IMG, (100, 80, 30), 
                 (center_x - 5, hip_y - 2, 10, 5))

# 왼쪽 다리 (위에서 본 각도)
left_leg_x = center_x - 15
# 허벅지
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (100, 90, 50), [
    (left_leg_x - 8, hip_y + 2),      # 엉덩이 연결부
    (left_leg_x - 10, hip_y + 15),    # 허벅지 외곽
    (left_leg_x - 8, hip_y + 25),     # 무릎 위
    (left_leg_x - 5, hip_y + 28),     # 무릎
    (left_leg_x + 2, hip_y + 25),     # 무릎 안쪽
    (left_leg_x + 5, hip_y + 15),     # 허벅지 안쪽
    (left_leg_x + 8, hip_y + 2)       # 엉덩이 안쪽
])

# 왼쪽 종아리
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (90, 80, 45), [
    (left_leg_x - 5, hip_y + 28),     # 무릎 시작
    (left_leg_x - 6, hip_y + 35),     # 종아리 외곽
    (left_leg_x - 5, hip_y + 42),     # 발목 위
    (left_leg_x - 3, hip_y + 45),     # 발목
    (left_leg_x + 3, hip_y + 45),     # 발목 안쪽
    (left_leg_x + 4, hip_y + 42),     # 발목 위 안쪽
    (left_leg_x + 5, hip_y + 35),     # 종아리 안쪽
    (left_leg_x + 2, hip_y + 28)      # 무릎 끝
])

# 오른쪽 다리 (위에서 본 각도)
right_leg_x = center_x + 15
# 허벅지
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (100, 90, 50), [
    (right_leg_x - 8, hip_y + 2),
    (right_leg_x - 5, hip_y + 15),
    (right_leg_x - 2, hip_y + 25),
    (right_leg_x + 5, hip_y + 28),
    (right_leg_x + 8, hip_y + 25),
    (right_leg_x + 10, hip_y + 15),
    (right_leg_x + 8, hip_y + 2)
])

# 오른쪽 종아리
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (90, 80, 45), [
    (right_leg_x - 2, hip_y + 28),
    (right_leg_x - 5, hip_y + 35),
    (right_leg_x - 4, hip_y + 42),
    (right_leg_x - 3, hip_y + 45),
    (right_leg_x + 3, hip_y + 45),
    (right_leg_x + 5, hip_y + 42),
    (right_leg_x + 6, hip_y + 35),
    (right_leg_x + 5, hip_y + 28)
])

# === 군화 (전투화) ===
# 왼쪽 군화
boot_left_y = hip_y + 45
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (30, 25, 15), [
    (left_leg_x - 6, boot_left_y),       # 발목 연결부
    (left_leg_x - 8, boot_left_y + 3),   # 뒤꿈치
    (left_leg_x - 7, boot_left_y + 8),   # 발바닥 뒤
    (left_leg_x - 4, boot_left_y + 10),  # 발바닥 중간
    (left_leg_x + 2, boot_left_y + 10),  # 발바닥 앞
    (left_leg_x + 5, boot_left_y + 8),   # 발끝
    (left_leg_x + 6, boot_left_y + 3),   # 발등
    (left_leg_x + 6, boot_left_y)        # 발목 안쪽
])

# 왼쪽 군화 끈
pygame.draw.line(SOLDIER_PADDLE_IMG, (20, 15, 10), 
                 (left_leg_x - 4, boot_left_y + 2), 
                 (left_leg_x + 4, boot_left_y + 2), 1)
pygame.draw.line(SOLDIER_PADDLE_IMG, (20, 15, 10), 
                 (left_leg_x - 3, boot_left_y + 4), 
                 (left_leg_x + 3, boot_left_y + 4), 1)

# 오른쪽 군화
boot_right_y = hip_y + 45
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (30, 25, 15), [
    (right_leg_x - 6, boot_right_y),
    (right_leg_x - 6, boot_right_y + 3),
    (right_leg_x - 5, boot_right_y + 8),
    (right_leg_x - 2, boot_right_y + 10),
    (right_leg_x + 4, boot_right_y + 10),
    (right_leg_x + 7, boot_right_y + 8),
    (right_leg_x + 8, boot_right_y + 3),
    (right_leg_x + 6, boot_right_y)
])

# 오른쪽 군화 끈
pygame.draw.line(SOLDIER_PADDLE_IMG, (20, 15, 10), 
                 (right_leg_x - 4, boot_right_y + 2), 
                 (right_leg_x + 4, boot_right_y + 2), 1)
pygame.draw.line(SOLDIER_PADDLE_IMG, (20, 15, 10), 
                 (right_leg_x - 3, boot_right_y + 4), 
                 (right_leg_x + 3, boot_right_y + 4), 1)

# 바지 위장 패턴
for i in range(6):
    camo_x = left_leg_x - 5 + random.randint(-3, 8)
    camo_y = hip_y + 5 + i * 6 + random.randint(-2, 2)
    pygame.draw.ellipse(SOLDIER_PADDLE_IMG, camo_colors[i % 3], 
                        (camo_x, camo_y, random.randint(5, 8), random.randint(4, 6)))
    
    camo_x = right_leg_x - 5 + random.randint(-3, 8)
    camo_y = hip_y + 5 + i * 6 + random.randint(-2, 2)
    pygame.draw.ellipse(SOLDIER_PADDLE_IMG, camo_colors[i % 3], 
                        (camo_x, camo_y, random.randint(5, 8), random.randint(4, 6)))

# 바지 주름
pygame.draw.line(SOLDIER_PADDLE_IMG, (70, 60, 30), 
                 (left_leg_x - 3, hip_y + 26), (left_leg_x - 2, hip_y + 30), 1)
pygame.draw.line(SOLDIER_PADDLE_IMG, (70, 60, 30), 
                 (right_leg_x + 3, hip_y + 26), (right_leg_x + 2, hip_y + 30), 1)

# === 헬멧 스트랩 (정수리 부분에서 이어짐) ===
# 턱끈 연결부 (헬멧 아래 부분)
pygame.draw.arc(SOLDIER_PADDLE_IMG, (40, 60, 25), 
                (center_x - 20, helmet_center_y + 15, 40, 20), 
                math.radians(10), math.radians(170), 2)

# Main loop
clock = pygame.time.Clock()
running = True
scale = 1.0
angle = 0

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_UP:
                scale = min(scale + 0.1, 3.0)
            elif event.key == pygame.K_DOWN:
                scale = max(scale - 0.1, 0.5)
            elif event.key == pygame.K_LEFT:
                angle -= 10
            elif event.key == pygame.K_RIGHT:
                angle += 10
    
    # Clear screen
    screen.fill(GRAY)
    
    # Draw grid for reference
    for x in range(0, WIDTH, 50):
        pygame.draw.line(screen, (100, 100, 100), (x, 0), (x, HEIGHT))
    for y in range(0, HEIGHT, 50):
        pygame.draw.line(screen, (100, 100, 100), (0, y), (WIDTH, y))
    
    # Transform and draw the paddle
    scaled_img = pygame.transform.scale(SOLDIER_PADDLE_IMG, 
                                        (int(250 * scale), int(100 * scale)))
    rotated_img = pygame.transform.rotate(scaled_img, angle)
    
    # Center the image
    rect = rotated_img.get_rect(center=(WIDTH // 2, HEIGHT // 2))
    screen.blit(rotated_img, rect)
    
    # Draw info text
    font = pygame.font.Font(None, 36)
    info_text = [
        f"Scale: {scale:.1f}x (UP/DOWN to change)",
        f"Angle: {angle}° (LEFT/RIGHT to rotate)",
        "ESC to exit"
    ]
    
    y = 20
    for text in info_text:
        rendered = font.render(text, True, WHITE)
        screen.blit(rendered, (20, y))
        y += 40
    
    # Update display
    pygame.display.flip()
    clock.tick(60)

pygame.quit()