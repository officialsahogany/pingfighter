#!/usr/bin/env python3
import pygame
import os
import numpy as np

# 원본 이미지 로드
backup_path = "/Volumes/T7/윈도우용 백업/윈도우용최신/game/bosspong/stage1_field.png"
original = pygame.image.load(backup_path)
width, height = original.get_size()

# 새 이미지 생성
new_image = pygame.Surface((width, height))

# 테두리 두께
border_thickness = 40

# 내부 영역의 그라데이션 분석
# 여러 라인에서 색상 샘플링하여 그라데이션 패턴 파악
gradient_samples = []

# 수직 방향 그라데이션 분석 (위에서 아래로)
for y in range(border_thickness, height - border_thickness, 10):
    x = width // 2  # 중앙
    color = original.get_at((x, y))
    # 어두운 바닥 색상만 수집
    if color[0] < 80 and color[1] < 80 and color[2] < 80:
        gradient_samples.append((y, color))

# 그라데이션 함수 생성 (선형 보간)
def get_gradient_color(y):
    if not gradient_samples:
        return (20, 20, 25)  # 기본 어두운 색상
    
    # y 위치에 가장 가까운 두 샘플 찾기
    for i in range(len(gradient_samples) - 1):
        y1, color1 = gradient_samples[i]
        y2, color2 = gradient_samples[i + 1]
        
        if y1 <= y <= y2:
            # 선형 보간
            t = (y - y1) / (y2 - y1) if y2 != y1 else 0
            r = int(color1[0] * (1 - t) + color2[0] * t)
            g = int(color1[1] * (1 - t) + color2[1] * t)
            b = int(color1[2] * (1 - t) + color2[2] * t)
            return (r, g, b)
    
    # 범위 밖인 경우 가장 가까운 색상 사용
    if y < gradient_samples[0][0]:
        return gradient_samples[0][1][:3]
    else:
        return gradient_samples[-1][1][:3]

# 수평 방향의 미세한 변화도 분석
horizontal_variation = []
y_sample = height // 2
for x in range(border_thickness, width - border_thickness, 20):
    color = original.get_at((x, y_sample))
    if color[0] < 80 and color[1] < 80 and color[2] < 80:
        horizontal_variation.append(color)

# 평균 수평 변화량 계산
avg_h_var = 0
if len(horizontal_variation) > 1:
    for i in range(len(horizontal_variation) - 1):
        diff = abs(horizontal_variation[i][0] - horizontal_variation[i+1][0])
        avg_h_var += diff
    avg_h_var /= (len(horizontal_variation) - 1)

# 전체 이미지를 그라데이션으로 채우기
for y in range(height):
    base_color = get_gradient_color(y)
    
    for x in range(width):
        # 수평 방향 미세 변화 추가
        h_offset = int(np.sin(x * 0.02) * avg_h_var)
        
        r = max(0, min(255, base_color[0] + h_offset))
        g = max(0, min(255, base_color[1] + h_offset))
        b = max(0, min(255, base_color[2] + h_offset))
        
        new_image.set_at((x, y), (r, g, b))

# 원본에서 태극 문양 복사
center_x, center_y = width // 2, height // 2
radius = 75  # 태극 문양의 반경

for y in range(max(0, center_y - radius), min(height, center_y + radius)):
    for x in range(max(0, center_x - radius), min(width, center_x + radius)):
        dist = ((x - center_x) ** 2 + (y - center_y) ** 2) ** 0.5
        if dist <= radius:
            original_color = original.get_at((x, y))
            # 태극 문양 부분 (밝은 색상)
            if original_color[0] > 50 or original_color[1] > 50 or original_color[2] > 50:
                new_image.set_at((x, y), original_color)

# 결과 저장
output_path = "stage1_field.png"
pygame.image.save(new_image, output_path)
print(f"그라데이션을 전체로 확장한 이미지를 {output_path}에 저장했습니다.")
print(f"분석된 그라데이션 샘플 수: {len(gradient_samples)}")
print(f"평균 수평 변화량: {avg_h_var:.2f}")