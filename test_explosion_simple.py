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
    """Create explosion surface (effects removed)"""
    cache_key = (stage, radius)
    cached = _blacksmith_hammer_explosion_cache.get(cache_key)
    if cached is not None:
        return cached
    
    size = radius * 5  # 큰 캔버스
    surface = pygame.Surface((size, size), pygame.SRCALPHA)
    
    # 빈 surface만 반환 (이펙트 제거)
    
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