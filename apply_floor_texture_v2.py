#!/usr/bin/env python3
import pygame
import os

# 원본 이미지 로드 (단청 테두리가 있는 원본)
backup_path = "/Volumes/T7/윈도우용 백업/윈도우용최신/game/bosspong/stage1_field.png"
current_path = "stage1_field.png"

# 백업 이미지 로드
backup_img = pygame.image.load(backup_path)
width, height = backup_img.get_size()

# 새 이미지 생성 - 백업 이미지를 복사
new_image = backup_img.copy()

# 테두리 영역만 바닥 패턴으로 대체
border_thickness = 40

# 안전한 바닥 영역에서 패턴 샘플링
safe_area_start = 60
safe_area_end_x = width - 60
safe_area_end_y = height - 60

# 상단 테두리를 바닥 패턴으로 대체
for y in range(border_thickness):
    for x in range(width):
        # 안전한 영역에서 바닥 패턴 가져오기
        source_y = safe_area_start + (y % (safe_area_end_y - safe_area_start))
        source_x = safe_area_start + (x % (safe_area_end_x - safe_area_start))
        
        if source_x < width and source_y < height:
            color = backup_img.get_at((source_x, source_y))
            # 어두운 색상만 사용
            if color[0] < 80 and color[1] < 80 and color[2] < 80:
                new_image.set_at((x, y), color)

# 하단 테두리를 바닥 패턴으로 대체
for y in range(height - border_thickness, height):
    for x in range(width):
        source_y = safe_area_start + ((y - (height - border_thickness)) % (safe_area_end_y - safe_area_start))
        source_x = safe_area_start + (x % (safe_area_end_x - safe_area_start))
        
        if source_x < width and source_y < height:
            color = backup_img.get_at((source_x, source_y))
            if color[0] < 80 and color[1] < 80 and color[2] < 80:
                new_image.set_at((x, y), color)

# 좌측 테두리를 바닥 패턴으로 대체
for x in range(border_thickness):
    for y in range(height):
        source_y = safe_area_start + (y % (safe_area_end_y - safe_area_start))
        source_x = safe_area_start + (x % (safe_area_end_x - safe_area_start))
        
        if source_x < width and source_y < height:
            color = backup_img.get_at((source_x, source_y))
            if color[0] < 80 and color[1] < 80 and color[2] < 80:
                new_image.set_at((x, y), color)

# 우측 테두리를 바닥 패턴으로 대체
for x in range(width - border_thickness, width):
    for y in range(height):
        source_y = safe_area_start + (y % (safe_area_end_y - safe_area_start))
        source_x = safe_area_start + ((x - (width - border_thickness)) % (safe_area_end_x - safe_area_start))
        
        if source_x < width and source_y < height:
            color = backup_img.get_at((source_x, source_y))
            if color[0] < 80 and color[1] < 80 and color[2] < 80:
                new_image.set_at((x, y), color)

# 결과 저장
pygame.image.save(new_image, current_path)
print(f"원본 바닥 텍스처로 테두리를 대체한 이미지를 {current_path}에 저장했습니다.")