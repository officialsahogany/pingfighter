#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test script for Stage 4 Shaolin Temple monk gauge"""

import pygame
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from ui.stage4_shaolin_temple import ShaolinTempleBackground

def main():
    """Test the monk gauge display"""
    pygame.init()
    
    # Create window
    WIDTH = 600
    HEIGHT = 750
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Stage 4: Monk Gauge Test (무승장법 게이지 테스트)")
    clock = pygame.time.Clock()
    
    # Initialize background
    background = ShaolinTempleBackground(WIDTH, HEIGHT)
    
    # Force spawn a monk for testing
    background._spawn_monk()
    print("테스트용 수도승 생성 완료")
    
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
                    # Simulate monk swing
                    if background.monks:
                        monk = background.monks[0]
                        if monk['state'] != 'swinging':
                            monk['state'] = 'swinging'
                            monk['swing_count'] = min(monk['swing_count'] + 1, 2)
                            monk['swing_cooldown'] = 180  # 3 seconds
                            print(f"수도승 봉술 시전! (횟수: {monk['swing_count']}/2)")
                elif event.key == pygame.K_r:
                    # Reset monk swing count
                    if background.monks:
                        monk = background.monks[0]
                        monk['swing_count'] = 0
                        monk['swing_cooldown'] = 0
                        monk['state'] = 'walking'
                        print("수도승 상태 초기화")
                elif event.key == pygame.K_m:
                    # Toggle meditation
                    if background.monks:
                        monk = background.monks[0]
                        if monk['state'] == 'meditating':
                            monk['state'] = 'walking'
                        else:
                            monk['state'] = 'meditating'
                        print(f"수도승 상태: {monk['state']}")
        
        # Update background
        background.update()
        
        # Clear screen
        screen.fill((0, 0, 0))
        
        # Draw background
        background.draw(screen)
        
        # Draw monk gauge (막대바 스타일)
        background.draw_monk_gauge(screen)
        
        # Draw instructions
        instructions = [
            "스페이스바: 봉술 시전 (Swing Staff)",
            "R: 초기화 (Reset)",
            "M: 명상 전환 (Toggle Meditation)",
            "ESC: 종료 (Exit)"
        ]
        
        y_offset = HEIGHT - 120
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