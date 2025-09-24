#!/usr/bin/env python3
"""Simple test for blacksmith hammer explosion effects"""

import pygame
import sys
import os
import math
import random

# Initialize Pygame
pygame.init()
WIDTH, HEIGHT = 800, 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Explosion Test - No Lightning")
clock = pygame.time.Clock()

# Global constants from pingfighter.py
FPS = 60
BLACKSMITH_HAMMER_SHOCK_BASE_RADIUS = 90
BLACKSMITH_HAMMER_SHOCK_STAGE2_RADIUS_SCALE = 1.1
BLACKSMITH_HAMMER_SHOCK_STAGE3_RADIUS_SCALE = 1.2

# Cache
_blacksmith_hammer_explosion_cache = {}

def _get_blacksmith_hammer_explosion_surface(stage, radius):
    """Create explosion surface without lightning effects"""
    cache_key = (stage, radius)
    cached = _blacksmith_hammer_explosion_cache.get(cache_key)
    if cached is not None:
        return cached
    
    size = radius * 2
    surface = pygame.Surface((size, size), pygame.SRCALPHA)
    center = radius
    
    # 1. 중심부 흰색 코어
    core_radius = radius // 3
    for i in range(core_radius, 0, -2):
        alpha = int(255 * (i / core_radius))
        pygame.draw.circle(surface, (255, 255, 255, alpha), (center, center), i)
    
    # 2. 중간층 - 스테이지별 색상
    mid_radius = int(radius * 0.7)
    for i in range(mid_radius, core_radius, -3):
        ratio = (i - core_radius) / (mid_radius - core_radius)
        alpha = int(200 * ratio)
        
        if stage >= 3:
            color = (255, 220, 100, alpha)  # 금빛
        elif stage >= 2:
            color = (220, 180, 255, alpha)  # 보라색
        else:
            color = (150, 220, 255, alpha)  # 하늘색
        
        pygame.draw.circle(surface, color, (center, center), i)
    
    # 3. 외곽층 그라데이션
    outer_radius = radius
    for i in range(outer_radius, mid_radius, -4):
        ratio = (i - mid_radius) / (outer_radius - mid_radius) 
        alpha = int(150 * ratio)
        color = (70 + stage * 10, 120 + stage * 15, 200 + stage * 20, alpha)
        pygame.draw.circle(surface, color, (center, center), i)
    
    # 4. 에너지 파편과 디테일한 효과는 메인 파일에서 구현
    
    # 5. 스파크 효과
    spark_count = 20 + stage * 10
    for _ in range(spark_count):
        angle = random.uniform(0, 2 * math.pi)
        dist = random.uniform(radius * 0.5, radius * 1.2)
        x = center + math.cos(angle) * dist
        y = center + math.sin(angle) * dist
        size_spark = random.randint(2, 5)
        spark_color = (255, 255, 255, random.randint(150, 255))
        pygame.draw.circle(surface, spark_color, (int(x), int(y)), size_spark)
    
    _blacksmith_hammer_explosion_cache[cache_key] = surface
    return surface

# Test parameters
test_stages = [1, 2, 3]
current_stage_idx = 0

# Main loop
running = True
font = pygame.font.Font(None, 36)

print("=== Explosion Test - No Lightning ===")
print("Controls:")
print("- SPACE: Create explosion")
print("- 1/2/3: Select stage")
print("")
print("Lightning effects removed - only gradient and spark effects remain")

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                # Create explosion
                stage = test_stages[current_stage_idx]
                radius = BLACKSMITH_HAMMER_SHOCK_BASE_RADIUS
                if stage == 2:
                    radius *= BLACKSMITH_HAMMER_SHOCK_STAGE2_RADIUS_SCALE
                elif stage >= 3:
                    radius *= BLACKSMITH_HAMMER_SHOCK_STAGE3_RADIUS_SCALE
                
                explosion_surface = _get_blacksmith_hammer_explosion_surface(stage, int(radius))
                
                # Draw explosion
                screen.fill((20, 20, 30))
                screen.blit(explosion_surface, 
                           (WIDTH // 2 - int(radius), HEIGHT // 2 - int(radius)))
                
                print(f"Stage {stage} explosion created!")
            elif event.key == pygame.K_1:
                current_stage_idx = 0
            elif event.key == pygame.K_2:
                current_stage_idx = 1
            elif event.key == pygame.K_3:
                current_stage_idx = 2
            elif event.key == pygame.K_ESCAPE:
                running = False
    
    # Draw UI
    stage_text = font.render(f"Current Stage: {test_stages[current_stage_idx]}", True, (255, 255, 255))
    screen.blit(stage_text, (10, 10))
    
    instructions = [
        "Press SPACE to create explosion",
        "Press 1/2/3 to select stage",
        "Press ESC to exit"
    ]
    
    for i, text in enumerate(instructions):
        inst_surf = font.render(text, True, (200, 200, 200))
        screen.blit(inst_surf, (10, 50 + i * 30))
    
    pygame.display.flip()
    clock.tick(60)

pygame.quit()
print("Test completed!")