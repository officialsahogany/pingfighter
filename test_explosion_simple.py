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
    """Create new explosion surface with energy pulse and crystal effects"""
    cache_key = (stage, radius)
    cached = _blacksmith_hammer_explosion_cache.get(cache_key)
    if cached is not None:
        return cached
    
    size = radius * 5  # 큰 캔버스로 화려한 효과 구현
    surface = pygame.Surface((size, size), pygame.SRCALPHA)
    center = size // 2
    
    # 1. 에너지 펄스 - 동심원 확장 효과
    pulse_layers = 5 + stage * 2
    for layer in range(pulse_layers):
        layer_progress = layer / pulse_layers
        
        # 각 레이어는 다른 크기와 투명도를 가짐
        pulse_radius = int(radius * (0.2 + layer_progress * 2.0))
        fade_factor = 1.0 - layer_progress
        
        # 그라데이션 원 그리기
        for r in range(pulse_radius, max(0, pulse_radius - 15), -1):
            r_ratio = (pulse_radius - r) / 15.0 if pulse_radius > r else 0
            alpha = int(120 * fade_factor * (1.0 - r_ratio))
            
            if stage >= 3:
                # Stage 3: 황금빛 펄스
                color = (255, int(220 - 20 * r_ratio), int(80 + 70 * layer_progress), alpha)
            elif stage >= 2:
                # Stage 2: 보라빛 펄스
                color = (int(180 + 75 * r_ratio), int(130 + 70 * r_ratio), 255, alpha)
            else:
                # Stage 1: 청록빛 펄스
                color = (int(80 + 120 * r_ratio), int(200 + 55 * r_ratio), 255, alpha)
            
            pygame.draw.circle(surface, color, (center, center), r, 1)
    
    # 2. 에너지 나선 - 회오리 효과
    spiral_count = 3 + stage
    for spiral in range(spiral_count):
        spiral_offset = (spiral / spiral_count) * 2 * math.pi
        points = []
        
        # 나선 생성
        for t in range(60):
            progress = t / 59.0
            angle = spiral_offset + progress * 4 * math.pi
            spiral_radius = radius * 0.2 + radius * 1.5 * progress
            
            # 나선이 바깥쪽으로 갈수록 흐려짐
            x = center + math.cos(angle) * spiral_radius
            y = center + math.sin(angle) * spiral_radius
            points.append((int(x), int(y)))
        
        # 나선 그리기
        for i in range(len(points) - 1):
            progress = i / (len(points) - 1)
            alpha = int(200 * (1.0 - progress))
            width = max(1, 4 - int(progress * 3))
            
            if stage >= 3:
                color = (255, 200, 100, alpha)
            elif stage >= 2:
                color = (200, 160, 255, alpha)
            else:
                color = (120, 220, 255, alpha)
            
            pygame.draw.line(surface, color, points[i], points[i + 1], width)
    
    # 3. 중심 에너지 코어
    core_radius = int(radius * 0.4)
    
    # 코어 중심부
    for r in range(core_radius, 0, -1):
        progress = 1.0 - (r / core_radius)
        intensity = 0.7 + 0.3 * progress
        
        if stage >= 3:
            # 황금빛 코어
            r_val = min(255, int(255 * intensity))
            g_val = min(255, int(240 * intensity))
            b_val = min(255, int(180 * intensity * (1.0 - progress * 0.5)))
        elif stage >= 2:
            # 보라빛 코어
            r_val = min(255, int(240 * intensity))
            g_val = min(255, int(220 * intensity))
            b_val = min(255, int(255 * intensity))
        else:
            # 청백빛 코어
            r_val = min(255, int(180 * intensity))
            g_val = min(255, int(240 * intensity))
            b_val = min(255, int(255 * intensity))
        
        alpha = min(255, int(255 * (0.8 + 0.2 * progress)))
        color = (r_val, g_val, b_val, alpha)
        pygame.draw.circle(surface, color, (center, center), r)
    
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