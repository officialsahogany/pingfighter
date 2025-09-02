import pygame
import math

# 초기화
pygame.init()

# 화염병 아이콘 생성
size = 64
icon = pygame.Surface((size, size), pygame.SRCALPHA)

# 색상 정의
BOTTLE_COLOR = (100, 180, 100, 200)  # 반투명 녹색 병
LIQUID_COLOR = (255, 100, 0, 180)  # 주황색 액체
CLOTH_COLOR = (200, 150, 100)  # 갈색 천
FLAME_COLOR1 = (255, 200, 0)  # 노란 불꽃
FLAME_COLOR2 = (255, 100, 0)  # 주황 불꽃
FLAME_COLOR3 = (255, 50, 0)  # 붉은 불꽃

# 병 몸통 그리기 (둥근 사각형)
bottle_rect = pygame.Rect(20, 24, 24, 32)
pygame.draw.rect(icon, BOTTLE_COLOR, bottle_rect, border_radius=4)
pygame.draw.rect(icon, (60, 120, 60), bottle_rect, 2, border_radius=4)

# 병 목 부분
neck_rect = pygame.Rect(26, 18, 12, 10)
pygame.draw.rect(icon, BOTTLE_COLOR, neck_rect)
pygame.draw.rect(icon, (60, 120, 60), neck_rect, 2)

# 병 안의 액체
liquid_rect = pygame.Rect(22, 36, 20, 18)
pygame.draw.rect(icon, LIQUID_COLOR, liquid_rect, border_radius=3)

# 천 조각 (병 목에서 나온 심지)
points = [
    (32, 18),  # 병 목 중앙
    (30, 14),
    (34, 12),
    (32, 8),
    (36, 10),
    (34, 14),
]
pygame.draw.polygon(icon, CLOTH_COLOR, points)

# 불꽃 효과
# 큰 불꽃
flame_center = (32, 8)
for i in range(3):
    offset = i * 2
    radius = 8 - offset
    if i == 0:
        color = FLAME_COLOR1
    elif i == 1:
        color = FLAME_COLOR2
    else:
        color = FLAME_COLOR3
    pygame.draw.circle(icon, color, flame_center, radius)

# 작은 불꽃들
small_flames = [(28, 6), (36, 6), (32, 4)]
for pos in small_flames:
    pygame.draw.circle(icon, FLAME_COLOR1, pos, 2)
    
# 광택 효과
pygame.draw.rect(icon, (255, 255, 255, 80), (24, 26, 4, 8))

# 파일 저장
pygame.image.save(icon, "/Users/pika/Desktop/game/bosspong/items/molotov.png")
print("화염병 아이콘이 생성되었습니다: items/molotov.png")