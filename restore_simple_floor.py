#!/usr/bin/env python3
import pygame
import os

# 현재 이미지 로드
current_path = "stage1_field.png"
current = pygame.image.load(current_path)
width, height = current.get_size()

# 새 이미지 생성 - 간단한 어두운 바닥
new_image = pygame.Surface((width, height))

# 단순한 어두운 바닥 색상 (약간의 회색빛이 도는 검은색)
base_color = (20, 20, 25)  # 매우 어두운 남색
new_image.fill(base_color)

# 미세한 그라데이션 효과 추가 (위에서 아래로 약간 밝아짐)
for y in range(height):
    gradient_factor = y / height * 0.1  # 최대 10% 밝기 증가
    r = min(255, int(base_color[0] * (1 + gradient_factor)))
    g = min(255, int(base_color[1] * (1 + gradient_factor)))
    b = min(255, int(base_color[2] * (1 + gradient_factor)))
    
    for x in range(width):
        new_image.set_at((x, y), (r, g, b))

# 중앙의 태극 문양 복사
center_x, center_y = width // 2, height // 2
radius = 65  # 태극 문양의 반경

for y in range(max(0, center_y - radius), min(height, center_y + radius)):
    for x in range(max(0, center_x - radius), min(width, center_x + radius)):
        dist = ((x - center_x) ** 2 + (y - center_y) ** 2) ** 0.5
        if dist <= radius:
            color = current.get_at((x, y))
            # 태극 문양 부분만 복사 (밝은 색상)
            if color[0] > 50 or color[1] > 50 or color[2] > 50:
                new_image.set_at((x, y), color)

# 결과 저장
pygame.image.save(new_image, current_path)
print(f"바닥을 단순한 어두운 스타일로 복원했습니다.")