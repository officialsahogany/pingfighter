"""
Test script for Stage 4 Brazier ignition system with smoke grenade
"""

import pygame
import sys
import math
from ui.stage4_shaolin_temple import ShaolinTempleBackground

def main():
    pygame.init()
    screen = pygame.display.set_mode((600, 750))
    pygame.display.set_caption("Stage 4: Brazier Test")
    clock = pygame.time.Clock()
    font = pygame.font.Font(None, 24)
    
    # Create background
    background = ShaolinTempleBackground(600, 750)
    
    # Smoke grenade state
    smoke_active = False
    smoke_x = 0
    smoke_y = 0
    smoke_radius = 60
    smoke_timer = 0
    smoke_duration = 300  # 5 seconds at 60 FPS
    
    # Get brazier position for reference
    brazier_x, brazier_y = background.get_brazier_position()
    
    running = True
    while running:
        mouse_x, mouse_y = pygame.mouse.get_pos()
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # Activate smoke grenade at mouse position
                    if not smoke_active:
                        smoke_active = True
                        smoke_x = mouse_x
                        smoke_y = mouse_y
                        smoke_timer = smoke_duration
                        print(f"💨 연막탄 발동! 위치: ({smoke_x}, {smoke_y})")
                        print(f"🎯 화로 위치: ({brazier_x}, {brazier_y})")
                        print(f"📏 화로와의 거리: {math.sqrt((smoke_x - brazier_x)**2 + (smoke_y - brazier_y)**2):.1f}")
                elif event.key == pygame.K_r:
                    # Reset brazier
                    background.brazier_lit = False
                    background.monks.clear()
                    print("🔄 화로와 몽크 리셋!")
        
        # Update smoke grenade
        if smoke_active:
            smoke_timer -= 1
            
            # Check if smoke touches brazier
            lit = background.check_smoke_touches_brazier(smoke_x, smoke_y, smoke_radius)
            if lit:
                print("🔥✅ 화로에 불이 붙었습니다!")
            
            if smoke_timer <= 0:
                smoke_active = False
                # Trigger monk return
                background.trigger_smoke_grenade_monk_return()
                print("💨 연막탄 종료, 몽크 복귀 타이머 시작")
        
        # Clear screen
        screen.fill((0, 0, 0))
        
        # Draw background
        background.draw(screen)
        
        # Draw smoke grenade effect
        if smoke_active:
            # Draw smoke cloud
            for i in range(3):
                alpha = 100 - i * 30
                radius = smoke_radius - i * 10
                smoke_surface = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(smoke_surface, (200, 200, 200, alpha), 
                                 (radius, radius), radius)
                screen.blit(smoke_surface, (smoke_x - radius, smoke_y - radius))
            
            # Draw smoke border for hitbox visualization
            pygame.draw.circle(screen, (255, 255, 0), (smoke_x, smoke_y), smoke_radius, 2)
        
        # Draw brazier hitbox for debugging
        brazier_hitbox = background.brazier_hitbox
        pygame.draw.rect(screen, (255, 0, 0), brazier_hitbox, 2)
        
        # Draw debug info
        debug_texts = [
            f"Mouse: ({mouse_x}, {mouse_y})",
            f"Brazier: ({brazier_x}, {brazier_y})",
            f"Brazier Lit: {background.brazier_lit}",
            f"Monks: {len(background.monks)}",
            f"Smoke Active: {smoke_active}",
            "",
            "SPACE: Drop smoke at mouse",
            "R: Reset brazier & monks",
            "",
            "Yellow circle: Smoke radius",
            "Red box: Brazier hitbox",
        ]
        
        y_offset = 10
        for text in debug_texts:
            text_surface = font.render(text, True, (255, 255, 255))
            screen.blit(text_surface, (10, y_offset))
            y_offset += 25
        
        # Draw crosshair at mouse
        pygame.draw.line(screen, (0, 255, 0), (mouse_x - 10, mouse_y), (mouse_x + 10, mouse_y), 1)
        pygame.draw.line(screen, (0, 255, 0), (mouse_x, mouse_y - 10), (mouse_x, mouse_y + 10), 1)
        
        # Update display
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()

if __name__ == "__main__":
    main()