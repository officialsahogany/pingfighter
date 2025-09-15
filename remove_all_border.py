#!/usr/bin/env python3
import pygame
import os

# 이미지 로드
original_path = "stage1_field.png"
original = pygame.image.load(original_path)
width, height = original.get_size()

# 새 이미지 생성
new_image = pygame.Surface((width, height))

# 중앙 영역의 바닥 패턴을 분석
# 테두리가 아닌 내부 영역에서 샘플링
inner_region_start = 50  # 테두리 안쪽
inner_region_end_x = width - 50
inner_region_end_y = height - 50

# 바닥 영역의 색상 패턴을 수집
floor_pattern = []
for y in range(inner_region_start, inner_region_end_y, 10):
    row_colors = []
    for x in range(inner_region_start, inner_region_end_x, 10):
        color = original.get_at((x, y))
        # 어두운 색상만 (바닥 패턴) - 태극 문양이나 테두리가 아닌 부분
        if color[0] < 80 and color[1] < 80 and color[2] < 80:
            row_colors.append(color)
    if row_colors:
        floor_pattern.append(row_colors)

# 전체 이미지를 바닥 패턴으로 채우기
for y in range(height):
    for x in range(width):
        # 패턴에서 적절한 색상 선택
        if floor_pattern:
            pattern_y = y % len(floor_pattern)
            if floor_pattern[pattern_y]:
                pattern_x = x % len(floor_pattern[pattern_y])
                color = floor_pattern[pattern_y][pattern_x]
                new_image.set_at((x, y), color)

# 원본에서 태극 문양과 중요 요소들 복사
center_x, center_y = width // 2, height // 2

# 원본 이미지에서 밝은 부분(태극 문양 등)만 복사
for y in range(height):
    for x in range(width):
        original_color = original.get_at((x, y))
        # 밝은 색상 (태극 문양 부분)
        if (original_color[0] > 100 or original_color[1] > 100 or original_color[2] > 100):
            # 테두리 영역이 아닌 경우만 복사
            if (50 < x < width - 50 and 50 < y < height - 50):
                new_image.set_at((x, y), original_color)

# 결과 저장
output_path = "stage1_field_no_border.png"
pygame.image.save(new_image, output_path)
print(f"테두리를 제거하고 바닥 패턴으로 채운 이미지를 {output_path}에 저장했습니다.")

# 원본 파일 교체
import shutil
shutil.copy(output_path, original_path)
print(f"원본 파일 {original_path}을 업데이트했습니다.")