import pygame
import sys

# Pygame 초기화
pygame.init()

# 아이콘 크기
ICON_SIZE = 60
surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)

# 중앙 위치
center = ICON_SIZE // 2

# 홀더 본체 (메탈릭한 원형 홀더)
# 외곽 메탈 링
for i in range(3):
    color_val = 180 - i * 20
    pygame.draw.circle(surface, (color_val, color_val, color_val + 10), 
                      (center, center), 22 - i, 2)

# 내부 원 (빨간색 계열 그라데이션)
for i in range(18, 0, -1):
    alpha = int(200 - i * 8)
    color_intensity = int(150 + i * 5)
    inner_color = (color_intensity, 50, 50, alpha)
    pygame.draw.circle(surface, inner_color, (center, center), i)

# 대쉬 토큰 슬롯 (2개)
token_radius = 6
token_offset = 12

# 첫 번째 토큰 (왼쪽)
token1_x = center - token_offset
token1_y = center

# 토큰 1 - 빛나는 빨간 구슬
pygame.draw.circle(surface, (80, 20, 20), (token1_x, token1_y), token_radius + 1)
pygame.draw.circle(surface, (255, 80, 80), (token1_x, token1_y), token_radius)
pygame.draw.circle(surface, (255, 150, 150), (token1_x - 2, token1_y - 2), token_radius // 2)

# 두 번째 토큰 (오른쪽)
token2_x = center + token_offset
token2_y = center

# 토큰 2 - 빛나는 빨간 구슬
pygame.draw.circle(surface, (80, 20, 20), (token2_x, token2_y), token_radius + 1)
pygame.draw.circle(surface, (255, 80, 80), (token2_x, token2_y), token_radius)
pygame.draw.circle(surface, (255, 150, 150), (token2_x - 2, token2_y - 2), token_radius // 2)

# 연결선 (두 토큰을 잇는 에너지 라인)
pygame.draw.line(surface, (255, 100, 100, 150), 
                (token1_x + token_radius, token1_y), 
                (token2_x - token_radius, token2_y), 3)
pygame.draw.line(surface, (255, 200, 200, 100), 
                (token1_x + token_radius, token1_y), 
                (token2_x - token_radius, token2_y), 1)

# 홀더 클립 (위아래 고정 장치)
clip_color = (200, 200, 210)
# 위쪽 클립
pygame.draw.rect(surface, clip_color, (center - 8, 5, 16, 6))
pygame.draw.rect(surface, (150, 150, 160), (center - 8, 5, 16, 6), 1)

# 아래쪽 클립
pygame.draw.rect(surface, clip_color, (center - 8, 49, 16, 6))
pygame.draw.rect(surface, (150, 150, 160), (center - 8, 49, 16, 6), 1)

# 하이라이트 효과
pygame.draw.arc(surface, (255, 255, 255, 180), 
                (center - 20, center - 20, 40, 40), 
                -1.0, 0.5, 2)

# 파일로 저장
pygame.image.save(surface, "items/dashholder.png")
print("대쉬홀더 아이콘이 items/dashholder.png에 저장되었습니다!")

pygame.quit()
sys.exit()