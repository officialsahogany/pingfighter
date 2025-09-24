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
    """Create new explosion surface with energy wave effects"""
    cache_key = (stage, radius)
    cached = _blacksmith_hammer_explosion_cache.get(cache_key)
    if cached is not None:
        return cached
    
    size = radius * 5  # 큰 캔버스로 화려한 효과 구현
    surface = pygame.Surface((size, size), pygame.SRCALPHA)
    center = size // 2
    
    # 1. 에너지 파동 - 원형 파문 효과
    wave_count = 4 + stage
    for wave in range(wave_count):
        wave_progress = wave / wave_count
        wave_radius = int(radius * (0.3 + wave_progress * 1.7))
        wave_thickness = max(1, 5 - wave)
        
        # 파동 색상 - 안쪽부터 밝게
        for thickness in range(wave_thickness):
            alpha = int(255 * (1 - wave_progress) * 0.7)
            t_ratio = thickness / max(1, wave_thickness)
            
            if stage >= 3:
                # Stage 3: 황금 에너지 파동
                color = (255, int(220 - 40 * t_ratio), int(100 + 50 * wave_progress), alpha)
            elif stage >= 2:
                # Stage 2: 보라색 에너지 파동
                color = (int(200 + 55 * t_ratio), int(150 + 50 * t_ratio), 255, alpha)
            else:
                # Stage 1: 청록색 에너지 파동
                color = (int(100 + 100 * t_ratio), int(200 + 55 * t_ratio), 255, alpha)
            
            pygame.draw.circle(surface, color, (center, center), wave_radius - thickness, 2)
    
    # 2. 에너지 기둥 - 방사형 빔 효과
    beam_count = 8 + stage * 4
    for i in range(beam_count):
        angle = (i / beam_count) * 2 * math.pi
        
        # 빔 길이는 랜덤하게
        beam_length = radius * random.uniform(1.2, 2.0)
        beam_width = random.randint(2, 5)
        
        # 빔의 끝점 계산
        end_x = center + math.cos(angle) * beam_length
        end_y = center + math.sin(angle) * beam_length
        
        # 빔 색상
        if stage >= 3:
            beam_color = (255, random.randint(200, 255), random.randint(50, 150))
        elif stage >= 2:
            beam_color = (random.randint(180, 220), random.randint(150, 200), 255)
        else:
            beam_color = (random.randint(150, 200), random.randint(220, 255), 255)
        
        # 빔 그리기 - 여러 층으로
        for layer in range(3):
            layer_alpha = int(200 * (1 - layer / 3))
            layer_width = beam_width + layer * 2
            layer_color = (*beam_color, layer_alpha)
            
            # 빔 그리기
            pygame.draw.line(surface, layer_color, (center, center), 
                           (int(end_x), int(end_y)), layer_width)
    
    # 3. 중심 플라즈마 구체 (간단한 버전)
    plasma_radius = int(radius * 0.35)
    for i in range(plasma_radius, 0, -2):
        ratio = i / plasma_radius
        alpha = int(255 * (1 - ratio * 0.3))
        
        if stage >= 3:
            color = (255, 230, 150, alpha)
        elif stage >= 2:
            color = (220, 200, 255, alpha)
        else:
            color = (200, 240, 255, alpha)
        
        pygame.draw.circle(surface, color, (center, center), i)
    
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