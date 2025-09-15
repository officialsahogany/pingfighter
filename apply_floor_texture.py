#!/usr/bin/env python3
import pygame
import os

# 원본 이미지 로드 (단청 테두리가 있는 원본)
backup_path = "/Volumes/T7/윈도우용 백업/윈도우용최신/game/bosspong/stage1_field.png"
current_path = "stage1_field.png"

# 백업 이미지와 현재 이미지 로드
backup_img = pygame.image.load(backup_path)
current_img = pygame.image.load(current_path)
width, height = current_img.get_size()

# 새 이미지 생성
new_image = pygame.Surface((width, height))

# 백업 이미지에서 바닥 패턴 영역 추출
# 테두리 안쪽의 바닥 부분을 샘플로 사용
border_inside = 45  # 테두리 안쪽 시작점
pattern_width = width - (border_inside * 2)
pattern_height = height - (border_inside * 2)

# 전체 이미지를 백업의 바닥 패턴으로 채우기
for y in range(height):
    for x in range(width):
        # 백업 이미지의 바닥 패턴 좌표 계산
        source_x = border_inside + (x % pattern_width)
        source_y = border_inside + (y % pattern_height)
        
        # 백업 이미지에서 색상 가져오기
        if source_x < width and source_y < height:
            color = backup_img.get_at((source_x, source_y))
            # 테두리 색상이 아닌 경우만 사용 (어두운 색상)
            if color[0] < 100 and color[1] < 100 and color[2] < 100:
                new_image.set_at((x, y), color)
            else:
                # 테두리 색상인 경우 주변 바닥 색상 사용
                if source_y + 50 < height:
                    color = backup_img.get_at((source_x, source_y + 50))
                    new_image.set_at((x, y), color)

# 현재 이미지에서 태극 문양 복사
center_x, center_y = width // 2, height // 2
radius = 70  # 태극 문양의 반경 (좀 더 크게)

for y in range(max(0, center_y - radius), min(height, center_y + radius)):
    for x in range(max(0, center_x - radius), min(width, center_x + radius)):
        dist = ((x - center_x) ** 2 + (y - center_y) ** 2) ** 0.5
        if dist <= radius:
            color = current_img.get_at((x, y))
            # 태극 문양 부분 (밝은 색상)
            if color[0] > 50 or color[1] > 50 or color[2] > 50:
                new_image.set_at((x, y), color)

# 결과 저장
pygame.image.save(new_image, current_path)
print(f"바닥 텍스처를 적용한 이미지를 {current_path}에 저장했습니다.")