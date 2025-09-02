import pygame
import sys

# Pygame 초기화
pygame.init()

# 32x32 아이콘 생성
icon_size = 32
icon_surface = pygame.Surface((icon_size, icon_size), pygame.SRCALPHA)

# 배경 투명
icon_surface.fill((0, 0, 0, 0))

# 조끼 몸체 그리기 (스틸 블루)
vest_color = (70, 130, 180)
vest_dark = (50, 100, 150)
vest_light = (100, 160, 210)

# 조끼 외곽선
vest_points = [
    (8, 10),   # 왼쪽 어깨
    (8, 24),   # 왼쪽 밑단
    (12, 26),  # 왼쪽 밑단 중앙
    (16, 27),  # 중앙 밑단
    (20, 26),  # 오른쪽 밑단 중앙
    (24, 24),  # 오른쪽 밑단
    (24, 10),  # 오른쪽 어깨
    (20, 8),   # 오른쪽 목
    (16, 7),   # 중앙 목
    (12, 8),   # 왼쪽 목
]

# 조끼 메인 색상
pygame.draw.polygon(icon_surface, vest_color, vest_points)

# 조끼 외곽선
pygame.draw.polygon(icon_surface, vest_dark, vest_points, 1)

# 조끼 포켓 (전술 조끼 느낌)
pocket_color = (50, 100, 150)
# 왼쪽 포켓
pygame.draw.rect(icon_surface, pocket_color, (10, 14, 5, 4))
pygame.draw.rect(icon_surface, vest_dark, (10, 14, 5, 4), 1)
# 오른쪽 포켓
pygame.draw.rect(icon_surface, pocket_color, (17, 14, 5, 4))
pygame.draw.rect(icon_surface, vest_dark, (17, 14, 5, 4), 1)

# 중앙 지퍼 라인
pygame.draw.line(icon_surface, vest_light, (16, 9), (16, 25), 1)

# 연막 효과 시각화 (작은 연기 구름)
smoke_color = (150, 150, 150, 100)
# 왼쪽 하단 연기
pygame.draw.circle(icon_surface, smoke_color, (7, 22), 3)
pygame.draw.circle(icon_surface, smoke_color, (5, 24), 2)
# 오른쪽 하단 연기  
pygame.draw.circle(icon_surface, smoke_color, (25, 22), 3)
pygame.draw.circle(icon_surface, smoke_color, (27, 24), 2)

# 아이콘 저장
pygame.image.save(icon_surface, "items/technical_vest.png")
print("테크니컬조끼 아이콘이 생성되었습니다: items/technical_vest.png")

pygame.quit()
sys.exit()