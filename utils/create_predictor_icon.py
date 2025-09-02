import pygame
import sys
import math

# Pygame 초기화
pygame.init()

# 아이콘 크기
ICON_SIZE = 60
surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)

# 스코프 원형 외곽
center = ICON_SIZE // 2
radius = 25

# 메탈릭한 스코프 테두리
for i in range(4):
    color_val = 150 - i * 20
    pygame.draw.circle(surface, (color_val, color_val, color_val + 30), 
                      (center, center), radius - i, 1)

# 스코프 렌즈 (그라데이션 효과)
lens_surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
for i in range(radius - 4, 0, -1):
    alpha = int(50 + (radius - 4 - i) * 3)
    blue_val = min(255, 100 + i * 5)
    pygame.draw.circle(lens_surface, (50, blue_val, 255, alpha), 
                      (center, center), i)
surface.blit(lens_surface, (0, 0))

# 십자선 (굵은 메인 라인)
# 수직선
pygame.draw.line(surface, (255, 0, 0), (center, 8), (center, 52), 2)
pygame.draw.line(surface, (255, 100, 100), (center, 8), (center, 52), 1)

# 수평선
pygame.draw.line(surface, (255, 0, 0), (8, center), (52, center), 2)
pygame.draw.line(surface, (255, 100, 100), (8, center), (52, center), 1)

# 거리 측정 마커 (작은 눈금)
for i in range(4):
    offset = 8 + i * 5
    # 상하좌우 작은 눈금
    pygame.draw.line(surface, (200, 50, 50), (center - 2, center - offset), 
                    (center + 2, center - offset), 1)
    pygame.draw.line(surface, (200, 50, 50), (center - 2, center + offset), 
                    (center + 2, center + offset), 1)
    pygame.draw.line(surface, (200, 50, 50), (center - offset, center - 2), 
                    (center - offset, center + 2), 1)
    pygame.draw.line(surface, (200, 50, 50), (center + offset, center - 2), 
                    (center + offset, center + 2), 1)

# 중앙 조준점 (빛나는 효과)
pygame.draw.circle(surface, (255, 255, 255), (center, center), 3)
pygame.draw.circle(surface, (255, 0, 0), (center, center), 2)
pygame.draw.circle(surface, (255, 200, 200), (center, center), 1)

# 레이저 빔 효과 (스코프에서 나가는 레이저)
beam_end_points = [
    (52, 15),  # 우상단
    (52, 45),  # 우하단
    (45, 8),   # 상단
]

for end_x, end_y in beam_end_points:
    # 빔 라인
    pygame.draw.line(surface, (255, 50, 50, 150), (center, center), (end_x, end_y), 2)
    pygame.draw.line(surface, (255, 150, 150, 100), (center, center), (end_x, end_y), 1)
    
    # 빔 끝 포인트
    pygame.draw.circle(surface, (255, 100, 100), (end_x, end_y), 2)
    pygame.draw.circle(surface, (255, 255, 255), (end_x, end_y), 1)

# 하이라이트 효과 (좌상단)
highlight_pos = (center - radius // 2, center - radius // 2)
pygame.draw.circle(surface, (255, 255, 255, 100), highlight_pos, 4)
pygame.draw.circle(surface, (255, 255, 255, 150), highlight_pos, 2)

# 파일로 저장
pygame.image.save(surface, "items/predictor.png")
print("레이저스코프 아이콘이 items/predictor.png에 저장되었습니다!")

pygame.quit()
sys.exit()