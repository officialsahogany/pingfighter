#!/usr/bin/env python3
import pygame
import sys

# Initialize Pygame
pygame.init()

# Create a 32x32 icon for fuel pouch
size = 32
icon = pygame.Surface((size, size), pygame.SRCALPHA)

# Colors
BROWN_DARK = (101, 67, 33)     # 짙은 갈색 (가죽)
BROWN_LIGHT = (139, 90, 43)    # 밝은 갈색
BROWN_SHADOW = (70, 45, 25)    # 그림자용 어두운 갈색
FUEL_GLOW = (255, 200, 100)    # 연료 빛 (밝은 황금색)
FUEL_CORE = (255, 150, 50)     # 연료 중심 (짙은 오렌지)
METAL = (150, 150, 150)        # 금속 마개
METAL_DARK = (100, 100, 100)   # 금속 그림자

# Draw the pouch body (rounded bag shape)
# 주머니 본체
pygame.draw.ellipse(icon, BROWN_DARK, (7, 8, 18, 20))
pygame.draw.ellipse(icon, BROWN_LIGHT, (8, 9, 16, 18))

# Draw the pouch neck/opening
pygame.draw.rect(icon, BROWN_DARK, (13, 6, 6, 5))
pygame.draw.rect(icon, METAL, (14, 5, 4, 3))
pygame.draw.rect(icon, METAL_DARK, (14, 5, 4, 1))

# Draw stitching details
for i in range(3):
    pygame.draw.line(icon, BROWN_SHADOW, (9, 12 + i*4), (10, 13 + i*4), 1)
    pygame.draw.line(icon, BROWN_SHADOW, (22, 12 + i*4), (23, 13 + i*4), 1)

# Draw fuel glow effect in center
# 연료의 빛나는 효과
pygame.draw.circle(icon, FUEL_GLOW, (16, 18), 5)
pygame.draw.circle(icon, FUEL_CORE, (16, 18), 3)
pygame.draw.circle(icon, (255, 255, 200), (16, 18), 1)  # 중심 하이라이트

# Draw string/cord on top
pygame.draw.arc(icon, BROWN_SHADOW, (12, 3, 8, 6), 0, 3.14, 2)

# Add subtle highlight on the pouch
pygame.draw.ellipse(icon, (160, 105, 55), (10, 11, 5, 3))

# Add shadow at bottom
pygame.draw.ellipse(icon, (0, 0, 0, 50), (8, 25, 16, 4))

# Save the icon
pygame.image.save(icon, "items/fuel_pouch.png")
print("fuel_pouch.png icon created successfully at items/fuel_pouch.png")