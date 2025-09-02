#!/usr/bin/env python3
"""
Test script for visualizing the enhanced ultra-kawaii Kuromi character in Stage 3
Tests the tail rotation following the ball position within a circle
"""

import pygame
import math
import sys

# Add parent directory to path for imports
sys.path.insert(0, '/Users/pika/Desktop/game/bosspong')

from ui.stage3_menhera_world import Stage3MenheraWorld

# Constants
WIDTH = 600
HEIGHT = 750
FPS = 60

def main():
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("🎀 Ultra Kawaii Kuromi - Stage 3 Test")
    clock = pygame.time.Clock()
    
    # Create Stage 3 instance
    stage3 = Stage3MenheraWorld()
    
    # Simulated ball position (rotating around center)
    ball_angle = 0
    ball_radius = 150
    center_x = WIDTH // 2
    center_y = HEIGHT // 2
    
    # Manual control mode
    manual_mode = False
    mouse_pos = (center_x, center_y)
    
    # Emotional phase control
    emotion_timer = 0
    
    running = True
    while running:
        dt = clock.tick(FPS)
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # Toggle manual/auto mode
                    manual_mode = not manual_mode
                    print(f"Mode: {'Manual (Mouse)' if manual_mode else 'Auto (Rotating)'}")
                elif event.key == pygame.K_1:
                    # Set emotional phase to calm
                    stage3.emotional_phase = 0
                    print("Emotional Phase: Calm")
                elif event.key == pygame.K_2:
                    # Set emotional phase to happy
                    stage3.emotional_phase = 1
                    print("Emotional Phase: Happy")
                elif event.key == pygame.K_3:
                    # Set emotional phase to sad
                    stage3.emotional_phase = 2
                    print("Emotional Phase: Sad")
                elif event.key == pygame.K_r:
                    # Simulate round change
                    stage3.round_count += 1
                    print(f"Round: {stage3.round_count}")
            elif event.type == pygame.MOUSEMOTION:
                if manual_mode:
                    mouse_pos = event.pos
        
        # Calculate ball position
        if manual_mode:
            ball_x, ball_y = mouse_pos
        else:
            # Auto-rotate ball around center
            ball_angle += 0.02  # Rotation speed
            ball_x = center_x + int(math.cos(ball_angle) * ball_radius)
            ball_y = center_y + int(math.sin(ball_angle) * ball_radius * 0.7)  # Elliptical path
        
        ball_pos = (ball_x, ball_y)
        
        # Update stage
        stage3.update(dt)
        
        # Draw everything
        screen.fill((40, 30, 45))  # Dark background
        
        # Draw stage with ball position for tail tracking
        stage3.draw(screen, ball_pos)
        
        # Draw the simulated ball
        pygame.draw.circle(screen, (255, 255, 100), ball_pos, 8)
        pygame.draw.circle(screen, (255, 255, 255), ball_pos, 8, 2)
        
        # Draw UI instructions
        font = pygame.font.Font(None, 20)
        instructions = [
            "SPACE: Toggle Manual/Auto Mode",
            "1/2/3: Change Emotion (Calm/Happy/Sad)",
            "R: Next Round",
            "Mouse: Control Ball (Manual Mode)",
            f"Mode: {'Manual' if manual_mode else 'Auto'}"
        ]
        
        y_offset = 10
        for text in instructions:
            surface = font.render(text, True, (200, 200, 200))
            screen.blit(surface, (10, y_offset))
            y_offset += 25
        
        # Show current emotional phase
        emotion_names = ["Calm 😌", "Happy 😊", "Sad 😢"]
        emotion_text = f"Emotion: {emotion_names[stage3.emotional_phase]}"
        emotion_surface = font.render(emotion_text, True, (255, 182, 193))
        screen.blit(emotion_surface, (WIDTH - 150, 10))
        
        pygame.display.flip()
    
    pygame.quit()
    print("Test completed!")

if __name__ == "__main__":
    main()