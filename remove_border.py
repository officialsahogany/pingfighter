#!/usr/bin/env python3
import pygame
import os

# 이미지 로드
image_path = "stage1_field.png"
image = pygame.image.load(image_path)
width, height = image.get_size()

# 새로운 검은색 배경 이미지 생성
new_image = pygame.Surface((width, height))
new_image.fill((0, 0, 0))  # 검은색 배경

# 중앙의 태극 문양만 복사
# 태극 문양이 대략 중앙에 위치하므로 해당 부분만 복사
center_x, center_y = width // 2, height // 2
radius = 60  # 태극 문양의 대략적인 반경

# 태극 문양 영역만 복사
for y in range(center_y - radius, center_y + radius):
    for x in range(center_x - radius, center_x + radius):
        if 0 <= x < width and 0 <= y < height:
            # 원형 영역 내부인지 확인
            dist = ((x - center_x) ** 2 + (y - center_y) ** 2) ** 0.5
            if dist <= radius:
                color = image.get_at((x, y))
                new_image.set_at((x, y), color)

# 결과 저장
output_path = "stage1_field_no_border.png"
pygame.image.save(new_image, output_path)
print(f"테두리를 제거한 이미지를 {output_path}에 저장했습니다.")