import pygame
import math

# 아이콘 크기
SIZE = 60
surface = pygame.Surface((SIZE, SIZE), pygame.SRCALPHA)

# 자석의 U자 모양 그리기
center_x = SIZE // 2
top_y = 10
bottom_y = SIZE - 15
width = 35
thickness = 8

# 자석 색상 (빨강-파랑)
RED = (220, 50, 50)
BLUE = (50, 100, 220)
GRAY = (100, 100, 100)

# 왼쪽 막대 (빨강 - N극)
left_x = center_x - width // 2
pygame.draw.rect(surface, RED, (left_x - thickness//2, top_y, thickness, 25))

# 오른쪽 막대 (파랑 - S극)  
right_x = center_x + width // 2
pygame.draw.rect(surface, BLUE, (right_x - thickness//2, top_y, thickness, 25))

# U자 곡선 부분 (회색)
arc_rect = pygame.Rect(center_x - width//2 - thickness//2, top_y + 20, width + thickness, 25)
pygame.draw.arc(surface, GRAY, arc_rect, 0, math.pi, thickness)

# 자력선 효과 (점선)
for i in range(3):
    y = top_y + 5 + i * 8
    for x in range(left_x - 10, left_x - thickness//2, -3):
        pygame.draw.circle(surface, (150, 150, 150, 100), (x, y), 1)
    for x in range(right_x + thickness//2, right_x + 10, 3):
        pygame.draw.circle(surface, (150, 150, 150, 100), (x, y), 1)

# N, S 표시
try:
    font = pygame.font.Font(None, 12)
    n_text = font.render("N", True, (255, 255, 255))
    s_text = font.render("S", True, (255, 255, 255))
    surface.blit(n_text, (left_x - 2, top_y + 2))
    surface.blit(s_text, (right_x - 2, top_y + 2))
except:
    pass

# 파일로 저장
pygame.image.save(surface, "items/dowsing_pendulum.png")
print("다우징팬들럼 아이콘이 생성되었습니다: items/dowsing_pendulum.png")