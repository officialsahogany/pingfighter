#!/usr/bin/env python3
"""
테스트: 포세이돈의 삼지창 거대 물결 회오리 효과
"""

import sys
import os
import pygame
import math

# 게임 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Import legendary items
from legendary_items import PoseidonTrident, get_legendary_manager

def test_vortex():
    """거대 물결 회오리 테스트"""
    
    # Initialize pygame
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("Poseidon Vortex Test")
    clock = pygame.time.Clock()
    font = pygame.font.Font(None, 24)
    
    # Create Poseidon's Trident
    trident = PoseidonTrident()
    
    # Activate it
    trident.activate({})
    print(f"Poseidon's Trident activated: {trident.active}")
    
    # Ball properties
    ball_x, ball_y = 400, 200
    ball_vx, ball_vy = 5.0, 3.0
    ball_radius = 10
    
    # Paddle properties
    paddle_x, paddle_y = 400, 450
    paddle_width, paddle_height = 100, 20
    
    # Main loop
    running = True
    dash_cooldown = 0
    
    while running:
        dt = clock.tick(60) / 1000.0  # Convert to seconds
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE and dash_cooldown <= 0:
                    # Trigger massive vortex on spacebar
                    trident.trigger_dash_wave(paddle_x, paddle_y, 1)
                    dash_cooldown = 2.0  # 2 second cooldown
                    print("🌊 VORTEX TRIGGERED!")
        
        # Update cooldown
        if dash_cooldown > 0:
            dash_cooldown -= dt
        
        # Move paddle with mouse
        mouse_x, _ = pygame.mouse.get_pos()
        paddle_x = mouse_x
        
        # Update ball physics
        ball_x += ball_vx
        ball_y += ball_vy
        
        # Apply vortex effect to ball
        new_vx, new_vy = trident.apply_dash_wave_to_ball(
            ball_x, ball_y, ball_vx, ball_vy,
            paddle_x, paddle_y
        )
        
        if new_vx != ball_vx or new_vy != ball_vy:
            print(f"⚡ BALL DEFLECTED! Velocity: ({ball_vx:.1f}, {ball_vy:.1f}) -> ({new_vx:.1f}, {new_vy:.1f})")
            ball_vx, ball_vy = new_vx, new_vy
        
        # Ball boundaries
        if ball_x <= ball_radius or ball_x >= 800 - ball_radius:
            ball_vx = -ball_vx
        if ball_y <= ball_radius:
            ball_vy = abs(ball_vy)
        if ball_y >= 600 - ball_radius:
            # Reset ball
            ball_x, ball_y = 400, 200
            ball_vx, ball_vy = 5.0, 3.0
        
        # Update trident
        trident.update(dt)
        
        # Clear screen
        screen.fill((20, 20, 40))  # Dark blue background
        
        # Draw effects (vortex)
        trident.draw_effects(screen)
        
        # Draw paddle
        pygame.draw.rect(screen, (100, 200, 100), 
                        (paddle_x - paddle_width // 2, paddle_y - paddle_height // 2, 
                         paddle_width, paddle_height))
        
        # Draw ball
        pygame.draw.circle(screen, (255, 255, 255), (int(ball_x), int(ball_y)), ball_radius)
        
        # Draw vortex collision area (debug)
        if trident.vortex_active:
            # Show vortex area
            vortex_rect = pygame.Rect(
                trident.vortex_x - trident.vortex_width // 2,
                trident.vortex_y - trident.vortex_height,
                trident.vortex_width,
                trident.vortex_height
            )
            pygame.draw.rect(screen, (0, 255, 255, 50), vortex_rect, 2)
        
        # Instructions
        inst_text = "SPACEBAR: Trigger Massive Vortex | Move mouse to control paddle"
        screen.blit(font.render(inst_text, True, (200, 200, 200)), (50, 20))
        
        if dash_cooldown > 0:
            cd_text = f"Cooldown: {dash_cooldown:.1f}s"
            screen.blit(font.render(cd_text, True, (255, 100, 100)), (350, 50))
        else:
            ready_text = "VORTEX READY!"
            screen.blit(font.render(ready_text, True, (100, 255, 100)), (350, 50))
        
        # Vortex status
        if trident.vortex_active:
            vortex_text = f"VORTEX ACTIVE! Height: {trident.vortex_height:.0f}"
            screen.blit(font.render(vortex_text, True, (100, 200, 255)), (300, 80))
        
        # Update display
        pygame.display.flip()
    
    pygame.quit()
    print("Test complete!")

if __name__ == "__main__":
    test_vortex()