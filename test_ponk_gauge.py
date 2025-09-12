#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test script for Stage 4 Boss Ponk's magnetic field gauge"""

import pygame
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from ui.stage4_shaolin_temple import ShaolinTempleBackground

def main():
    """Test Ponk's magnetic field gauge display"""
    pygame.init()
    
    # Create window
    WIDTH = 600
    HEIGHT = 750
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Stage 4: Ponk Gauge Test (굴절자기장 게이지 테스트)")
    clock = pygame.time.Clock()
    
    # Initialize background
    background = ShaolinTempleBackground(WIDTH, HEIGHT)
    
    # Gauge variables (simulating boss_special_gauge_stage4)
    gauge_value = 0
    is_ready = False
    is_active = False
    magnetic_timer = 0
    
    # Font for instructions
    try:
        font = pygame.font.Font("NeoDGM.ttf", 20)
    except:
        font = pygame.font.Font(None, 20)
    
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # Charge gauge
                    if not is_active:
                        gauge_value += 50
                        if gauge_value >= 250:
                            gauge_value = 250
                            is_ready = True
                        print(f"게이지 충전: {gauge_value}/250")
                elif event.key == pygame.K_RETURN:
                    # Activate magnetic field
                    if is_ready:
                        is_active = True
                        is_ready = False
                        gauge_value = 0
                        magnetic_timer = 200  # 200 frames
                        print("굴절자기장 발동!")
                elif event.key == pygame.K_r:
                    # Reset
                    gauge_value = 0
                    is_ready = False
                    is_active = False
                    magnetic_timer = 0
                    print("게이지 초기화")
                elif event.key == pygame.K_f:
                    # Fill gauge instantly
                    gauge_value = 250
                    is_ready = True
                    print("게이지 즉시 충전!")
        
        # Update magnetic field timer
        if is_active and magnetic_timer > 0:
            magnetic_timer -= 1
            if magnetic_timer <= 0:
                is_active = False
                print("굴절자기장 종료")
        
        # Update background
        background.update()
        
        # Clear screen
        screen.fill((0, 0, 0))
        
        # Draw background
        background.draw(screen)
        
        # Draw Ponk's magnetic field gauge
        background.draw_ponk_gauge(screen, gauge_value, is_ready, is_active)
        
        # Draw instructions
        instructions = [
            "스페이스바: 게이지 충전 (+50)",
            "엔터: 굴절자기장 발동 (게이지 MAX시)",
            "F: 즉시 충전",
            "R: 초기화",
            "ESC: 종료"
        ]
        
        y_offset = HEIGHT - 140
        for instruction in instructions:
            text_surface = font.render(instruction, True, (255, 255, 255))
            text_rect = text_surface.get_rect(centerx=WIDTH//2, y=y_offset)
            # Draw background for better readability
            pygame.draw.rect(screen, (0, 0, 0, 128), text_rect.inflate(10, 5))
            screen.blit(text_surface, text_rect)
            y_offset += 25
        
        # Show magnetic field status
        if is_active:
            status = f"자기장 활성! (남은 시간: {magnetic_timer})"
            status_surface = font.render(status, True, (255, 100, 100))
            status_rect = status_surface.get_rect(centerx=WIDTH//2, y=100)
            screen.blit(status_surface, status_rect)
        
        # Update display
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    print("테스트 종료")

if __name__ == "__main__":
    main()