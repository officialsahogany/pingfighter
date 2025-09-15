#!/usr/bin/env python3
import pygame
import os

# 이미지 로드
original_path = "stage1_field.png"
original = pygame.image.load(original_path)
width, height = original.get_size()

# 새 이미지 생성
new_image = pygame.Surface((width, height))

# 바닥 패턴 샘플링 - 테두리 안쪽의 검은 바닥 부분에서 색상 추출
# 중앙 근처의 바닥 색상들을 샘플링
floor_colors = []
sample_points = [
    (width//2 - 100, height//2),
    (width//2 + 100, height//2),
    (width//2, height//2 - 100),
    (width//2, height//2 + 100),
    (width//2 - 50, height//2 - 50),
    (width//2 + 50, height//2 + 50),
]

for x, y in sample_points:
    if 0 <= x < width and 0 <= y < height:
        color = original.get_at((x, y))
        # 태극 문양 색상이 아닌 경우만 추가
        if color[0] < 50 and color[1] < 50 and color[2] < 50:  # 어두운 색상만
            floor_colors.append(color)

# 평균 바닥 색상 계산
if floor_colors:
    avg_r = sum(c[0] for c in floor_colors) // len(floor_colors)
    avg_g = sum(c[1] for c in floor_colors) // len(floor_colors)
    avg_b = sum(c[2] for c in floor_colors) // len(floor_colors)
    floor_color = (avg_r, avg_g, avg_b)
else:
    floor_color = (20, 20, 20)  # 기본 어두운 회색

# 전체를 바닥 색상으로 채우기
new_image.fill(floor_color)

# 미세한 텍스처 추가 (바닥의 자연스러운 느낌)
import random
for y in range(height):
    for x in range(width):
        # 약간의 노이즈 추가
        noise = random.randint(-5, 5)
        r = max(0, min(255, floor_color[0] + noise))
        g = max(0, min(255, floor_color[1] + noise))
        b = max(0, min(255, floor_color[2] + noise))
        if random.random() < 0.3:  # 30% 확률로 노이즈 적용
            new_image.set_at((x, y), (r, g, b))

# 중앙의 태극 문양 복사
center_x, center_y = width // 2, height // 2
radius = 65  # 태극 문양의 반경 (좀 더 크게)

for y in range(center_y - radius, center_y + radius):
    for x in range(center_x - radius, center_x + radius):
        if 0 <= x < width and 0 <= y < height:
            dist = ((x - center_x) ** 2 + (y - center_y) ** 2) ** 0.5
            if dist <= radius:
                color = original.get_at((x, y))
                # 태극 문양 부분만 복사 (밝은 색상)
                if color[0] > 50 or color[1] > 50 or color[2] > 50:
                    new_image.set_at((x, y), color)

# 결과 저장
output_path = "stage1_field_filled.png"
pygame.image.save(new_image, output_path)
print(f"바닥 스타일로 채운 이미지를 {output_path}에 저장했습니다.")