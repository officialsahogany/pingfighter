#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate new soldier paddle image and save to file"""

import pygame
import math
import random

# Initialize Pygame
pygame.init()

# 군인 패들 이미지 생성 (위에서 바라본 각도 - 정수리가 보이는 버전)
SOLDIER_PADDLE_IMG = pygame.Surface((180, 100), pygame.SRCALPHA)  # 컴팩트한 사이즈

# 중심점 설정
center_x = 90
center_y = 45  # 라켓이 잘리지 않도록 충분한 공간 확보

# === 헬멧 (위에서 본 각도 - 정수리 중심) ===
helmet_center_y = center_y - 12
# 헬멧 그림자
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (30, 45, 20), 
                    (center_x - 17, helmet_center_y - 11, 34, 26))
# 헬멧 외곽
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (65, 85, 45), 
                    (center_x - 16, helmet_center_y - 10, 32, 24))
# 헬멧 내부
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (50, 70, 35), 
                    (center_x - 12, helmet_center_y - 8, 24, 19))
# 헬멧 정수리 패턴
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (55, 75, 38), 
                    (center_x - 8, helmet_center_y - 5, 16, 12))
# 헬멧 하이라이트
pygame.draw.arc(SOLDIER_PADDLE_IMG, (85, 105, 65), 
                (center_x - 14, helmet_center_y - 9, 28, 20), 
                math.radians(190), math.radians(350), 2)
# 헬멧 통풍구
for angle in [0, 120, 240]:
    rad = math.radians(angle)
    vent_x = center_x + int(4 * math.cos(rad))
    vent_y = helmet_center_y - 2 + int(3 * math.sin(rad))
    pygame.draw.circle(SOLDIER_PADDLE_IMG, (35, 55, 20), (vent_x, vent_y), 1)

# === 목 부분 ===
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (190, 150, 120), 
                    (center_x - 9, helmet_center_y + 6, 18, 11))

# === 군복 상체 ===
body_y = helmet_center_y + 16
# 어깨와 몸통
shoulder_points = [
    (center_x - 30, body_y),
    (center_x - 24, body_y - 3),
    (center_x - 14, body_y - 4),
    (center_x + 14, body_y - 4),
    (center_x + 24, body_y - 3),
    (center_x + 30, body_y),
    (center_x + 32, body_y + 8),
    (center_x + 28, body_y + 18),
    (center_x - 28, body_y + 18),
    (center_x - 32, body_y + 8)
]
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (110, 100, 60), shoulder_points)

# 군복 디테일
pygame.draw.line(SOLDIER_PADDLE_IMG, (80, 70, 40), 
                 (center_x, body_y - 3), (center_x, body_y + 16), 1)
# 주머니
pygame.draw.rect(SOLDIER_PADDLE_IMG, (90, 80, 50), 
                 (center_x - 16, body_y + 3, 10, 5))
pygame.draw.rect(SOLDIER_PADDLE_IMG, (90, 80, 50), 
                 (center_x + 6, body_y + 3, 10, 5))
# 계급장
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (150, 130, 60), [
    (center_x - 28, body_y - 1),
    (center_x - 20, body_y - 3),
    (center_x - 20, body_y + 1),
    (center_x - 28, body_y + 2)
])
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (150, 130, 60), [
    (center_x + 20, body_y - 3),
    (center_x + 28, body_y - 1),
    (center_x + 28, body_y + 2),
    (center_x + 20, body_y + 1)
])

# === 왼팔과 탁구채 ===
left_arm_x = center_x - 20
left_arm_y = body_y - 14
# 팔
arm_points = [
    (center_x - 26, body_y - 1),
    (center_x - 29, body_y),
    (left_arm_x - 5, left_arm_y),
    (left_arm_x - 3, left_arm_y - 9),
    (left_arm_x + 3, left_arm_y - 9),
    (left_arm_x + 5, left_arm_y),
    (center_x - 18, body_y - 2)
]
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (118, 103, 63), arm_points)

# 손
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (200, 160, 130), 
                    (left_arm_x - 5, left_arm_y - 13, 10, 8))

# 탁구채
paddle_x = left_arm_x
paddle_y = left_arm_y - 23
# 라켓 면
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (70, 90, 50), 
                    (paddle_x - 11, paddle_y - 9, 22, 28))
# 라켓 테두리
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (90, 100, 70), 
                    (paddle_x - 11, paddle_y - 9, 22, 28), 1)
# 라켓 고무
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (115, 30, 20), 
                    (paddle_x - 8, paddle_y - 6, 16, 22))
# 군용 별 마크
star_cx = paddle_x
star_cy = paddle_y + 3
for i in range(5):
    angle = math.radians(i * 72 - 90)
    x = star_cx + int(3 * math.cos(angle))
    y = star_cy + int(3 * math.sin(angle))
    pygame.draw.line(SOLDIER_PADDLE_IMG, (130, 40, 30), 
                     (star_cx, star_cy), (x, y), 1)
# 손잡이
pygame.draw.rect(SOLDIER_PADDLE_IMG, (90, 50, 30), 
                 (paddle_x - 2, paddle_y + 19, 4, 8))

# === 오른팔 ===
right_arm_x = center_x + 26
right_arm_y = body_y + 3
arm_points_right = [
    (center_x + 26, body_y - 1),
    (center_x + 29, body_y),
    (right_arm_x + 3, right_arm_y + 6),
    (right_arm_x, right_arm_y + 10),
    (right_arm_x - 5, right_arm_y + 9),
    (right_arm_x - 3, right_arm_y + 3),
    (center_x + 18, body_y - 2)
]
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (118, 103, 63), arm_points_right)

# 오른손
pygame.draw.ellipse(SOLDIER_PADDLE_IMG, (200, 160, 130), 
                    (right_arm_x - 3, right_arm_y + 8, 8, 6))

# === 위장 패턴 ===
camo_colors = [(80, 70, 40), (100, 90, 50), (90, 80, 45)]
for i in range(5):
    camo_x = center_x - 20 + (i % 3) * 13 + random.randint(-3, 3)
    camo_y = body_y - 2 + (i // 3) * 6 + random.randint(-1, 1)
    camo_size = random.randint(5, 9)
    pygame.draw.ellipse(SOLDIER_PADDLE_IMG, camo_colors[i % 3], 
                        (camo_x, camo_y, camo_size, camo_size - 1))

# === 다리 ===
hip_y = body_y + 20

# 벨트
pygame.draw.rect(SOLDIER_PADDLE_IMG, (55, 45, 25), 
                 (center_x - 20, hip_y - 1, 40, 3))
pygame.draw.rect(SOLDIER_PADDLE_IMG, (130, 110, 50), 
                 (center_x - 5, hip_y - 1, 10, 3))

# 왼쪽 다리
left_leg_x = center_x - 10
# 허벅지
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (105, 95, 55), [
    (left_leg_x - 5, hip_y + 1),
    (left_leg_x - 6, hip_y + 6),
    (left_leg_x - 5, hip_y + 10),
    (left_leg_x - 3, hip_y + 12),
    (left_leg_x + 2, hip_y + 10),
    (left_leg_x + 3, hip_y + 6),
    (left_leg_x + 4, hip_y + 1)
])
# 종아리
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (95, 85, 50), [
    (left_leg_x - 3, hip_y + 12),
    (left_leg_x - 4, hip_y + 16),
    (left_leg_x - 3, hip_y + 19),
    (left_leg_x - 1, hip_y + 20),
    (left_leg_x + 1, hip_y + 20),
    (left_leg_x + 3, hip_y + 19),
    (left_leg_x + 4, hip_y + 16),
    (left_leg_x + 2, hip_y + 12)
])

# 오른쪽 다리
right_leg_x = center_x + 10
# 허벅지
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (105, 95, 55), [
    (right_leg_x - 4, hip_y + 1),
    (right_leg_x - 3, hip_y + 6),
    (right_leg_x - 2, hip_y + 10),
    (right_leg_x + 3, hip_y + 12),
    (right_leg_x + 5, hip_y + 10),
    (right_leg_x + 6, hip_y + 6),
    (right_leg_x + 5, hip_y + 1)
])
# 종아리
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (95, 85, 50), [
    (right_leg_x - 2, hip_y + 12),
    (right_leg_x - 4, hip_y + 16),
    (right_leg_x - 3, hip_y + 19),
    (right_leg_x - 1, hip_y + 20),
    (right_leg_x + 1, hip_y + 20),
    (right_leg_x + 3, hip_y + 19),
    (right_leg_x + 4, hip_y + 16),
    (right_leg_x + 3, hip_y + 12)
])

# === 군화 ===
boot_y = hip_y + 20
# 왼쪽 군화
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (35, 30, 20), [
    (left_leg_x - 3, boot_y),
    (left_leg_x - 4, boot_y + 1),
    (left_leg_x - 3, boot_y + 3),
    (left_leg_x - 1, boot_y + 4),
    (left_leg_x + 1, boot_y + 4),
    (left_leg_x + 3, boot_y + 3),
    (left_leg_x + 4, boot_y + 1),
    (left_leg_x + 3, boot_y)
])
# 오른쪽 군화
pygame.draw.polygon(SOLDIER_PADDLE_IMG, (35, 30, 20), [
    (right_leg_x - 3, boot_y),
    (right_leg_x - 4, boot_y + 1),
    (right_leg_x - 3, boot_y + 3),
    (right_leg_x - 1, boot_y + 4),
    (right_leg_x + 1, boot_y + 4),
    (right_leg_x + 3, boot_y + 3),
    (right_leg_x + 4, boot_y + 1),
    (right_leg_x + 3, boot_y)
])

# 바지 위장 패턴
for i in range(3):
    camo_x = left_leg_x - 3 + random.randint(-1, 4)
    camo_y = hip_y + 3 + i * 4
    pygame.draw.ellipse(SOLDIER_PADDLE_IMG, camo_colors[i % 3], 
                        (camo_x, camo_y, 4, 3))
    
    camo_x = right_leg_x - 3 + random.randint(-1, 4)
    camo_y = hip_y + 3 + i * 4
    pygame.draw.ellipse(SOLDIER_PADDLE_IMG, camo_colors[i % 3], 
                        (camo_x, camo_y, 4, 3))

# Save the image
pygame.image.save(SOLDIER_PADDLE_IMG, "/Volumes/T7/윈도우용최신/game/bosspong/soldier_paddle_new.png")
print("New soldier paddle image saved to soldier_paddle_new.png")
print(f"Image size: {SOLDIER_PADDLE_IMG.get_width()}x{SOLDIER_PADDLE_IMG.get_height()}")