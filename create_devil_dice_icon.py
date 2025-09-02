"""
악마의 주사위 아이콘 생성
"""

import pygame
import math

# Pygame 초기화
pygame.init()

# 아이콘 크기
ICON_SIZE = 32

# 아이콘 서페이스 생성
icon = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)

# 주사위 본체 그리기 (어두운 빨간색)
dice_size = 24
dice_x = (ICON_SIZE - dice_size) // 2
dice_y = (ICON_SIZE - dice_size) // 2

# 주사위 그라데이션
for i in range(dice_size):
    color_intensity = 139 - i * 2
    if color_intensity < 50:
        color_intensity = 50
    pygame.draw.rect(icon, (color_intensity, 0, 0), 
                    (dice_x + i//4, dice_y + i//4, 
                     dice_size - i//2, dice_size - i//2), 
                     border_radius=3)

# 주사위 테두리
pygame.draw.rect(icon, (200, 0, 0), 
                (dice_x, dice_y, dice_size, dice_size), 2, border_radius=3)

# 악마의 눈 (주사위 점 대신)
eye_positions = [
    (ICON_SIZE//2 - 5, ICON_SIZE//2 - 5),  # 왼쪽 위
    (ICON_SIZE//2 + 5, ICON_SIZE//2 - 5),  # 오른쪽 위
    (ICON_SIZE//2, ICON_SIZE//2 + 5),      # 중앙 아래
]

for x, y in eye_positions:
    # 빨간 눈 광채
    for i in range(3):
        alpha = 100 - i * 30
        size = 3 + i
        glow = pygame.Surface((size*2, size*2), pygame.SRCALPHA)
        pygame.draw.circle(glow, (255, 0, 0, alpha), (size, size), size)
        icon.blit(glow, (x - size, y - size))
    
    # 눈 중심
    pygame.draw.circle(icon, (255, 100, 100), (x, y), 2)
    pygame.draw.circle(icon, (255, 255, 255), (x, y), 1)

# 어두운 오라 효과
for i in range(3):
    aura_size = ICON_SIZE + i * 4
    aura_alpha = 30 - i * 10
    if aura_alpha > 0:
        aura = pygame.Surface((aura_size, aura_size), pygame.SRCALPHA)
        pygame.draw.circle(aura, (139, 0, 0, aura_alpha), 
                         (aura_size//2, aura_size//2), 
                         aura_size//2)
        # 오라를 아이콘 중심에 맞춰 블릿
        offset = (ICON_SIZE - aura_size) // 2
        temp_surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
        temp_surface.blit(aura, (offset, offset))
        icon.blit(temp_surface, (0, 0))

# 아이콘 저장
pygame.image.save(icon, "items/devil_dice.png")
print("✅ 악마의 주사위 아이콘이 생성되었습니다: items/devil_dice.png")