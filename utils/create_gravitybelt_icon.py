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

# 벨트 버클 (중앙의 원형 장치)
# 외곽 금속 링
pygame.draw.circle(surface, (100, 100, 120), (center, center), 18, 3)
pygame.draw.circle(surface, (150, 150, 170), (center, center), 16, 2)
pygame.draw.circle(surface, (200, 200, 220), (center, center), 14, 1)

# 중앙 반중력 코어 (파란색 빛나는 구체)
for i in range(12, 0, -1):
    alpha = int(255 - i * 15)
    blue_intensity = int(100 + i * 12)
    core_color = (50, blue_intensity, 255, alpha)
    pygame.draw.circle(surface, core_color, (center, center), i)

# 중력 필드 효과 (물결 무늬)
for ring in range(3):
    radius = 8 + ring * 4
    alpha = 100 - ring * 30
    pygame.draw.circle(surface, (100, 150, 255, alpha), (center, center), radius, 1)

# 벨트 스트랩 (좌우로 뻗어나가는 띠)
belt_color = (60, 60, 70)
belt_highlight = (80, 80, 90)

# 왼쪽 벨트
left_belt = [
    (5, center - 6),
    (center - 16, center - 8),
    (center - 16, center + 8),
    (5, center + 6)
]
pygame.draw.polygon(surface, belt_color, left_belt)
pygame.draw.polygon(surface, belt_highlight, left_belt, 1)

# 오른쪽 벨트
right_belt = [
    (center + 16, center - 8),
    (55, center - 6),
    (55, center + 6),
    (center + 16, center + 8)
]
pygame.draw.polygon(surface, belt_color, right_belt)
pygame.draw.polygon(surface, belt_highlight, right_belt, 1)

# 벨트 구멍 디테일
hole_color = (40, 40, 50)
for i in range(3):
    # 왼쪽 구멍들
    hole_x = 10 + i * 6
    pygame.draw.circle(surface, hole_color, (hole_x, center), 2)
    # 오른쪽 구멍들
    hole_x = 50 - i * 6
    pygame.draw.circle(surface, hole_color, (hole_x, center), 2)

# 무중력 효과 (떠있는 작은 파티클들)
particles = [
    (center - 10, center - 15, 2),
    (center + 12, center - 12, 1),
    (center - 8, center + 14, 2),
    (center + 10, center + 10, 1),
]

for px, py, size in particles:
    # 파티클 글로우
    glow_surface = pygame.Surface((size * 6, size * 6), pygame.SRCALPHA)
    pygame.draw.circle(glow_surface, (150, 200, 255, 60), 
                      (size * 3, size * 3), size * 3)
    surface.blit(glow_surface, (px - size * 3, py - size * 3))
    # 파티클 본체
    pygame.draw.circle(surface, (200, 230, 255), (px, py), size)

# 중앙 G 문자 (Gravity)
try:
    font = pygame.font.Font(None, 14)
    g_text = font.render("G", True, (255, 255, 255))
    text_rect = g_text.get_rect(center=(center, center))
    surface.blit(g_text, text_rect)
except:
    # 폰트 로드 실패시 작은 G 모양 그리기
    pygame.draw.lines(surface, (255, 255, 255), False, 
                     [(center + 3, center - 4), (center - 3, center - 4),
                      (center - 3, center + 4), (center + 3, center + 4),
                      (center + 3, center), (center, center)], 1)

# 하이라이트 효과
pygame.draw.arc(surface, (255, 255, 255, 150), 
                (center - 16, center - 16, 32, 32), 
                -1.2, -0.2, 2)

# 파일로 저장
pygame.image.save(surface, "items/gravitybelt.png")
print("무중력벨트 아이콘이 items/gravitybelt.png에 저장되었습니다!")

pygame.quit()
sys.exit()