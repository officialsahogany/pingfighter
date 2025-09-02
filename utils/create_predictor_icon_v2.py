import pygame
import sys
import math

# Pygame 초기화
pygame.init()

# 아이콘 크기
ICON_SIZE = 60
surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)

# 중앙 위치
center = ICON_SIZE // 2

# 스나이퍼 스코프 본체 (원통형 망원경)
# 스코프 몸통 (검은색 금속)
scope_body = pygame.Rect(8, center - 8, 44, 16)
pygame.draw.rect(surface, (30, 30, 35), scope_body)
pygame.draw.rect(surface, (50, 50, 55), scope_body, 2)

# 스코프 앞부분 (렌즈 하우징)
lens_front = pygame.Rect(44, center - 10, 12, 20)
pygame.draw.rect(surface, (40, 40, 45), lens_front)
pygame.draw.rect(surface, (60, 60, 65), lens_front, 1)

# 스코프 렌즈 (빨간색 레이저 렌즈)
lens_x = 50
lens_y = center

# 렌즈 글로우 효과
for i in range(10, 0, -1):
    alpha = int(150 - i * 10)
    red_intensity = int(200 + i * 5)
    lens_glow = (red_intensity, 50, 50, alpha)
    pygame.draw.circle(surface, lens_glow, (lens_x, lens_y), i + 2)

# 메인 렌즈
pygame.draw.circle(surface, (180, 40, 40), (lens_x, lens_y), 8)
pygame.draw.circle(surface, (255, 60, 60), (lens_x, lens_y), 6)
pygame.draw.circle(surface, (255, 150, 150), (lens_x - 2, lens_y - 2), 3)

# 레이저 빔 (렌즈에서 나가는)
beam_points = [
    (lens_x + 8, lens_y),
    (ICON_SIZE, lens_y - 2),
    (ICON_SIZE, lens_y + 2),
    (lens_x + 8, lens_y)
]
# 빔 글로우
beam_glow = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
pygame.draw.polygon(beam_glow, (255, 100, 100, 80), beam_points)
surface.blit(beam_glow, (0, 0))
# 빔 코어
pygame.draw.line(surface, (255, 0, 0), (lens_x + 8, lens_y), (ICON_SIZE, lens_y), 2)
pygame.draw.line(surface, (255, 200, 200), (lens_x + 8, lens_y), (ICON_SIZE, lens_y), 1)

# 조준경 십자선 (스코프 위에 작은 십자선)
crosshair_x = 20
crosshair_y = center
crosshair_size = 4

# 십자선
pygame.draw.line(surface, (200, 200, 200), 
                (crosshair_x - crosshair_size, crosshair_y), 
                (crosshair_x + crosshair_size, crosshair_y), 1)
pygame.draw.line(surface, (200, 200, 200), 
                (crosshair_x, crosshair_y - crosshair_size), 
                (crosshair_x, crosshair_y + crosshair_size), 1)

# 조정 다이얼 (스코프 상단)
dial_x = 25
dial_y = center - 6
pygame.draw.circle(surface, (70, 70, 75), (dial_x, dial_y), 3)
pygame.draw.circle(surface, (100, 100, 105), (dial_x, dial_y), 2)
# 다이얼 노치
pygame.draw.line(surface, (150, 150, 155), (dial_x, dial_y - 2), (dial_x, dial_y), 1)

# 마운트 레일 (아래쪽)
rail_y = center + 8
pygame.draw.rect(surface, (80, 80, 85), (12, rail_y, 32, 3))
# 레일 홈
for i in range(4):
    groove_x = 14 + i * 8
    pygame.draw.line(surface, (60, 60, 65), (groove_x, rail_y), (groove_x, rail_y + 2), 1)

# 접안 렌즈 (왼쪽 끝)
eyepiece = pygame.Rect(4, center - 6, 8, 12)
pygame.draw.rect(surface, (45, 45, 50), eyepiece)
pygame.draw.rect(surface, (65, 65, 70), eyepiece, 1)

# 접안 렌즈 유리
pygame.draw.circle(surface, (100, 120, 140), (8, center), 4)
pygame.draw.circle(surface, (150, 170, 190), (7, center - 1), 2)

# 거리 측정 숫자 (스코프 위)
try:
    font = pygame.font.Font(None, 10)
    distance_text = font.render("100m", True, (255, 100, 100))
    surface.blit(distance_text, (20, 8))
except:
    pass

# 하이라이트 효과
pygame.draw.line(surface, (255, 255, 255, 150), (10, center - 7), (30, center - 7), 1)

# 파일로 저장
pygame.image.save(surface, "items/predictor_v2.png")
print("레이저스코프 아이콘 V2가 items/predictor_v2.png에 저장되었습니다!")

pygame.quit()
sys.exit()