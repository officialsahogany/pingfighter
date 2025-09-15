#!/usr/bin/env python3
import pygame
import os

# 이미지 로드
original_path = "stage1_field.png"
original = pygame.image.load(original_path)
width, height = original.get_size()

# 새 이미지 생성 - 원본 복사
new_image = original.copy()

# 테두리 두께 추정 (약 40 픽셀)
border_thickness = 40

# 테두리 내부의 바닥 색상 샘플링
# 여러 지점에서 샘플링하여 평균값 사용
floor_colors = []
sample_points = [
    (width // 2, height // 2 + 100),  # 태극 아래
    (width // 2 - 50, height // 2 + 100),
    (width // 2 + 50, height // 2 + 100),
    (width // 2, height // 2 - 100),  # 태극 위
]

for x, y in sample_points:
    if 0 <= x < width and 0 <= y < height:
        color = original.get_at((x, y))
        # 어두운 색상만 (바닥)
        if color[0] < 50 and color[1] < 50 and color[2] < 50:
            floor_colors.append(color)

# 평균 바닥 색상 계산
if floor_colors:
    avg_r = sum(c[0] for c in floor_colors) // len(floor_colors)
    avg_g = sum(c[1] for c in floor_colors) // len(floor_colors)
    avg_b = sum(c[2] for c in floor_colors) // len(floor_colors)
    floor_color = (avg_r, avg_g, avg_b)
else:
    floor_color = (20, 20, 25)  # 기본 어두운 색상

# 테두리 영역을 바닥색으로 채우기
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