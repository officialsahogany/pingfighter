#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test script for Stage 4 Temple Destruction Animation"""

import pygame
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from ui.stage4_shaolin_temple import ShaolinTempleBackground

def main():
    """Test temple destruction animation"""
    pygame.init()
    
    # Create window
    WIDTH = 600
    HEIGHT = 750
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Stage 4: Temple Destruction Test (사원 파괴 테스트)")
    clock = pygame.time.Clock()
    
    # Initialize background
    background = ShaolinTempleBackground(WIDTH, HEIGHT)
    
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
                    # Start destruction animation
                    if not background.temple_destroyed:
                        background.start_destruction_animation()
                        print("사원 파괴 애니메이션 시작!")
                elif event.key == pygame.K_r:
                    # Reset
                    background.temple_destroyed = False
                    background.destruction_animation_active = False
                    background.destruction_phase = 0
                    background.destruction_timer = 0
                    background.destruction_debris = []
                    background.moon_color = (255, 250, 200)
                    background.red_light_alpha = 0
                    background.shake_intensity = 0
                    background.shake_offset = (0, 0)
                    background.monks = []
                    print("사원 상태 초기화")
        
        # Update background
        background.update()
        
        # Clear screen
        screen.fill((0, 0, 0))
        
        # Draw background
        background.draw(screen)
        
        # Draw instructions
        instructions = []
        if background.is_destruction_animation_active():
            instructions.append(f"파괴 애니메이션 진행중... (Phase {background.destruction_phase}/4)")
        elif background.temple_destroyed:
            instructions.append("사원이 파괴됨!")
            instructions.append("R: 초기화")
        else:
            instructions.append("스페이스바: 사원 파괴 시작")
            instructions.append("R: 초기화")
        instructions.append("ESC: 종료")
        
        y_offset = HEIGHT - 100
        for instruction in instructions:
            text_surface = font.render(instruction, True, (255, 255, 255))
            text_rect = text_surface.get_rect(centerx=WIDTH//2, y=y_offset)
            # Draw background for better readability
            pygame.draw.rect(screen, (0, 0, 0, 128), text_rect.inflate(10, 5))
            screen.blit(text_surface, text_rect)
            y_offset += 25
        
        # Update display
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    print("테스트 종료")

if __name__ == "__main__":
    main()