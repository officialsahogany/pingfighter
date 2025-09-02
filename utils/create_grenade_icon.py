import pygame
import sys

# Pygame 초기화
pygame.init()

# 아이콘 크기
ICON_SIZE = 60
surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)

# 수류탄 본체 (타원형)
body_color = (60, 80, 60)  # 군용 녹색
body_rect = pygame.Rect(18, 25, 24, 30)
pygame.draw.ellipse(surface, body_color, body_rect)

# 수류탄 몸체 하이라이트
highlight_color = (80, 100, 80)
highlight_rect = pygame.Rect(22, 28, 8, 10)
pygame.draw.ellipse(surface, highlight_color, highlight_rect)

# 수류탄 상단 캡 (안전핀 부분)
cap_color = (40, 40, 40)  # 어두운 회색
cap_rect = pygame.Rect(22, 20, 16, 8)
pygame.draw.rect(surface, cap_color, cap_rect, border_radius=2)

# 안전핀 고리
ring_color = (150, 150, 150)  # 은색
pygame.draw.arc(surface, ring_color, pygame.Rect(26, 15, 8, 8), 0, 3.14159, 2)

# 수류탄 세로줄 무늬 (파인애플 수류탄 스타일)
line_color = (40, 60, 40)
for i in range(3):
    x = 23 + i * 6
    pygame.draw.line(surface, line_color, (x, 30), (x, 50), 1)

# 수류탄 가로줄 무늬
for i in range(3):
    y = 32 + i * 6
    pygame.draw.rect(surface, line_color, (20, y, 20, 1))

# 위험 표시 (작은 빨간 점)
danger_color = (200, 0, 0)
pygame.draw.circle(surface, danger_color, (30, 35), 2)

# 그림자 효과
shadow_color = (0, 0, 0, 30)
shadow_surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
shadow_rect = pygame.Rect(20, 27, 24, 30)
pygame.draw.ellipse(shadow_surface, shadow_color, shadow_rect)
surface.blit(shadow_surface, (2, 2))

# 파일로 저장
pygame.image.save(surface, "items/grenade.png")
print("수류탄 아이콘이 items/grenade.png에 저장되었습니다!")

pygame.quit()
sys.exit()