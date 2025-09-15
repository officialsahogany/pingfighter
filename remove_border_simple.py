#!/usr/bin/env python3
import pygame
import os

# 이미지 로드
original_path = "stage1_field.png"
original = pygame.image.load(original_path)
width, height = original.get_size()

# 새 이미지 생성 - 원본 복사
new_image = original.copy()

# 테두리 두께 (단청 테두리는 약 40픽셀)
border_thickness = 40

# 중앙 영역에서 바닥 색상 샘플링
center_x, center_y = width // 2, height // 2
# 태극 문양 아래쪽에서 바닥 색상 가져오기
floor_color = original.get_at((center_x, center_y + 150))

# 테두리 영역을 바닥 색상으로 채우기
# 상단
for y in range(border_thickness):
    for x in range(width):
        new_image.set_at((x, y), floor_color)

# 하단
for y in range(height - border_thickness, height):
    for x in range(width):
        new_image.set_at((x, y), floor_color)

# 좌측
for x in range(border_thickness):
    for y in range(height):
        new_image.set_at((x, y), floor_color)

# 우측
for x in range(width - border_thickness, width):
    for y in range(height):
        new_image.set_at((x, y), floor_color)

# 결과 저장
pygame.image.save(new_image, original_path)
print(f"테두리를 제거한 이미지를 {original_path}에 저장했습니다.")
print(f"사용된 바닥 색상: {floor_color}")