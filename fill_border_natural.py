#!/usr/bin/env python3
import pygame
import os
import random

# 원본 이미지 로드 (단청 테두리가 있는 원본)
backup_path = "/Volumes/T7/윈도우용 백업/윈도우용최신/game/bosspong/stage1_field.png"
original = pygame.image.load(backup_path)
width, height = original.get_size()

# 새 이미지 생성
new_image = pygame.Surface((width, height))

# 테두리 두께
border_thickness = 40

# 안전한 내부 영역에서 바닥 패턴 수집
# 여러 영역에서 샘플링하여 자연스러운 패턴 생성
floor_samples = []
sample_size = 50  # 샘플 크기

# 다양한 위치에서 바닥 샘플 수집
sample_positions = [
    (width // 4, height // 4),
    (3 * width // 4, height // 4),
    (width // 4, 3 * height // 4),
    (3 * width // 4, 3 * height // 4),
    (width // 2, height // 4),
    (width // 2, 3 * height // 4),
]

for base_x, base_y in sample_positions:
    sample = []
    for dy in range(-sample_size//2, sample_size//2):
        row = []
        for dx in range(-sample_size//2, sample_size//2):
            x = base_x + dx
            y = base_y + dy
            if border_thickness < x < width - border_thickness and border_thickness < y < height - border_thickness:
                color = original.get_at((x, y))
                # 바닥 색상만 수집 (어두운 색상)
                if color[0] < 80 and color[1] < 80 and color[2] < 80:
                    row.append(color)
        if row:
            sample.append(row)
    if sample:
        floor_samples.append(sample)

# 전체 이미지 채우기
for y in range(height):
    for x in range(width):
        # 원본에서 직접 복사 (테두리가 아닌 부분)
        if border_thickness <= x < width - border_thickness and border_thickness <= y < height - border_thickness:
            new_image.set_at((x, y), original.get_at((x, y)))
        else:
            # 테두리 영역은 샘플에서 자연스럽게 채우기
            if floor_samples:
                # 랜덤하게 샘플 선택
                sample = random.choice(floor_samples)
                if sample:
                    sample_y = y % len(sample)
                    if sample[sample_y]:
                        sample_x = x % len(sample[sample_y])
                        color = sample[sample_y][sample_x]
                        
                        # 약간의 노이즈 추가로 더 자연스럽게
                        noise = random.randint(-3, 3)
                        r = max(0, min(255, color[0] + noise))
                        g = max(0, min(255, color[1] + noise))
                        b = max(0, min(255, color[2] + noise))
                        
                        new_image.set_at((x, y), (r, g, b))

# 경계 부분 부드럽게 처리
# 테두리와 내부 경계에서 블렌딩
blend_width = 5
for y in range(height):
    for x in range(width):
        # 왼쪽 경계
        if border_thickness - blend_width <= x < border_thickness:
            blend_factor = (x - (border_thickness - blend_width)) / blend_width
            border_color = new_image.get_at((x, y))
            inner_color = new_image.get_at((border_thickness, y))
            
            r = int(border_color[0] * (1 - blend_factor) + inner_color[0] * blend_factor)
            g = int(border_color[1] * (1 - blend_factor) + inner_color[1] * blend_factor)
            b = int(border_color[2] * (1 - blend_factor) + inner_color[2] * blend_factor)
            
            new_image.set_at((x, y), (r, g, b))
        
        # 오른쪽 경계
        elif width - border_thickness < x <= width - border_thickness + blend_width:
            blend_factor = (width - border_thickness + blend_width - x) / blend_width
            border_color = new_image.get_at((x, y))
            inner_color = new_image.get_at((width - border_thickness - 1, y))
            
            r = int(border_color[0] * (1 - blend_factor) + inner_color[0] * blend_factor)
            g = int(border_color[1] * (1 - blend_factor) + inner_color[1] * blend_factor)
            b = int(border_color[2] * (1 - blend_factor) + inner_color[2] * blend_factor)
            
            new_image.set_at((x, y), (r, g, b))

# 위아래 경계도 동일하게 처리
for x in range(width):
    for y in range(height):
        # 위쪽 경계
        if border_thickness - blend_width <= y < border_thickness:
            blend_factor = (y - (border_thickness - blend_width)) / blend_width
            border_color = new_image.get_at((x, y))
            if border_thickness < height:
                inner_color = new_image.get_at((x, border_thickness))
                
                r = int(border_color[0] * (1 - blend_factor) + inner_color[0] * blend_factor)
                g = int(border_color[1] * (1 - blend_factor) + inner_color[1] * blend_factor)
                b = int(border_color[2] * (1 - blend_factor) + inner_color[2] * blend_factor)
                
                new_image.set_at((x, y), (r, g, b))
        
        # 아래쪽 경계
        elif height - border_thickness < y <= height - border_thickness + blend_width:
            blend_factor = (height - border_thickness + blend_width - y) / blend_width
            border_color = new_image.get_at((x, y))
            if height - border_thickness - 1 >= 0:
                inner_color = new_image.get_at((x, height - border_thickness - 1))
                
                r = int(border_color[0] * (1 - blend_factor) + inner_color[0] * blend_factor)
                g = int(border_color[1] * (1 - blend_factor) + inner_color[1] * blend_factor)
                b = int(border_color[2] * (1 - blend_factor) + inner_color[2] * blend_factor)
                
                new_image.set_at((x, y), (r, g, b))

# 결과 저장
output_path = "stage1_field.png"
pygame.image.save(new_image, output_path)
print(f"테두리를 자연스러운 바닥 패턴으로 채운 이미지를 {output_path}에 저장했습니다.")