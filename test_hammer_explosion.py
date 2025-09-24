#!/usr/bin/env python3
"""Test script for Blacksmith Hammer Shock Explosion effects"""

import pygame
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import the functions we need to test
from pingfighter import (
    _get_blacksmith_hammer_explosion_surface,
    draw_blacksmith_hammer_shock,
    blacksmith_hammer_explosions,
    screen_shake_timer,
    screen_shake_intensity,
    BLACKSMITH_HAMMER_SHOCK_EXPLOSION_SIZE,
    init_blacksmith_globals
)

# Initialize Pygame
pygame.init()
WIDTH, HEIGHT = 800, 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Hammer Shock Explosion Test")
clock = pygame.time.Clock()

# Initialize blacksmith globals
init_blacksmith_globals()

# Test parameters
test_stages = [1, 2, 3]
current_stage_idx = 0
explosion_timer = 0

# Main loop
running = True
font = pygame.font.Font(None, 36)

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                # Create a new explosion
                stage = test_stages[current_stage_idx]
                explosion_surface = _get_blacksmith_hammer_explosion_surface(
                    BLACKSMITH_HAMMER_SHOCK_EXPLOSION_SIZE[stage-1], 
                    stage
                )
                blacksmith_hammer_explosions.append({
                    "surface": explosion_surface,
                    "center": (WIDTH // 2, HEIGHT // 2),
                    "life": 40,  # 40 frames
                    "max_life": 40,
                    "stage": stage,
                    "offsets": [],
                    "sparks": [],
                    "shards": [],
                    "radius": BLACKSMITH_HAMMER_SHOCK_EXPLOSION_SIZE[stage-1],
                    "first_frame": True,
                })
                print(f"Created Stage {stage} explosion!")
            elif event.key == pygame.K_1:
                current_stage_idx = 0
            elif event.key == pygame.K_2:
                current_stage_idx = 1
            elif event.key == pygame.K_3:
                current_stage_idx = 2
    
    # Clear screen
    screen.fill((20, 20, 30))
    
    # Draw explosions
    draw_blacksmith_hammer_shock(screen)
    
    # Draw UI
    stage_text = font.render(f"Current Stage: {test_stages[current_stage_idx]}", True, (255, 255, 255))
    screen.blit(stage_text, (10, 10))
    
    instructions = [
        "Press SPACE to create explosion",
        "Press 1/2/3 to select stage",
        f"Screen shake: {screen_shake_timer > 0} (intensity: {screen_shake_intensity})"
    ]
    
    for i, text in enumerate(instructions):
        inst_surf = font.render(text, True, (200, 200, 200))
        screen.blit(inst_surf, (10, 50 + i * 30))
    
    # Update explosions
    for explosion in blacksmith_hammer_explosions:
        if explosion["life"] > 0:
            explosion["life"] -= 1
    
    # Update screen shake
    if screen_shake_timer > 0:
        screen_shake_timer -= 1
    
    pygame.display.flip()
    clock.tick(60)

pygame.quit()
print("Test completed!")