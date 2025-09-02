#!/usr/bin/env python3
"""
Test script for Stage 4 Shaolin Temple background
"""

import pygame
import sys
sys.path.append('.')

from ui.stage4_shaolin_temple import ShaolinTempleBackground

def main():
    pygame.init()
    screen = pygame.display.set_mode((600, 750))
    pygame.display.set_caption("Stage 4: Shaolin Temple - Test")
    clock = pygame.time.Clock()
    
    # Create background
    background = ShaolinTempleBackground(600, 750)
    
    # Show FPS
    font = pygame.font.Font(None, 36)
    
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
        
        # Clear screen
        screen.fill((0, 0, 0))
        
        # Draw background
        background.draw(screen)
        
        # Draw FPS
        fps = clock.get_fps()
        fps_text = font.render(f"FPS: {fps:.1f}", True, (255, 255, 255))
        screen.blit(fps_text, (10, 10))
        
        # Update display
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()

if __name__ == "__main__":
    main()