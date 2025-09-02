"""
연료파우치 아이콘 생성 스크립트
32x32 픽셀 아이콘을 생성합니다.
"""

import pygame
import math

# Pygame 초기화
pygame.init()

# 32x32 서페이스 생성
icon_size = 32
icon = pygame.Surface((icon_size, icon_size), pygame.SRCALPHA)

# 배경 투명
icon.fill((0, 0, 0, 0))

# 색상 정의
POUCH_COLOR = (139, 90, 43)  # 가죽 갈색
POUCH_DARK = (110, 70, 30)  # 어두운 갈색 (그림자)
POUCH_LIGHT = (160, 110, 60)  # 밝은 갈색 (하이라이트)
ROPE_COLOR = (101, 67, 33)  # 끈 색상
FUEL_GLOW = (255, 200, 100)  # 연료 빛
FUEL_COLOR = (255, 150, 50)  # 연료 색상

# 파우치 몸통 그리기 (둥근 사각형)
pygame.draw.ellipse(icon, POUCH_COLOR, (8, 10, 16, 18))
pygame.draw.ellipse(icon, POUCH_DARK, (8, 10, 16, 18), 1)

# 파우치 입구 그리기
pygame.draw.rect(icon, POUCH_COLOR, (10, 10, 12, 8))
pygame.draw.rect(icon, POUCH_DARK, (10, 10, 12, 8), 1)

# 끈 그리기 (파우치 입구를 묶는 끈)
pygame.draw.line(icon, ROPE_COLOR, (9, 11), (23, 11), 2)
pygame.draw.line(icon, ROPE_COLOR, (9, 12), (23, 12), 1)

# 연료 표시 (빛나는 효과)
# 중앙에 작은 원으로 연료 표시
pygame.draw.circle(icon, FUEL_GLOW, (16, 20), 4)
pygame.draw.circle(icon, FUEL_COLOR, (16, 20), 3)
pygame.draw.circle(icon, (255, 255, 200), (16, 19), 1)

# 하이라이트 추가 (입체감)
pygame.draw.arc(icon, POUCH_LIGHT, (9, 11, 14, 16), 3.14, 4.71, 2)

# 작은 디테일 - 스티치 표시
for i in range(3):
    x = 12 + i * 4
    y = 14
    pygame.draw.circle(icon, ROPE_COLOR, (x, y), 0)

# 그림자 효과
pygame.draw.ellipse(icon, (0, 0, 0, 30), (8, 25, 16, 4))

# 아이콘 저장
pygame.image.save(icon, "items/fuel_pouch.png")
print("연료파우치 아이콘이 items/fuel_pouch.png로 저장되었습니다.")