#!/usr/bin/env python3
"""Create knee pads icon for the item"""

import pygame
import os
import sys

# Add parent directory to path
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def create_knee_pads_icon():
    # Initialize Pygame
    pygame.init()
    
    # Create surface
    icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    icon.fill((0, 0, 0, 0))
    
    # Colors
    pad_color = (60, 60, 80)  # Dark gray-blue for the pad
    strap_color = (40, 40, 50)  # Darker for straps
    highlight_color = (100, 100, 120)  # Lighter for highlights
    cushion_color = (80, 80, 100)  # Medium for cushioning
    
    # Draw main knee pad shape (rounded rectangle)
    # Main body
    pygame.draw.ellipse(icon, pad_color, (8, 6, 16, 20))
    pygame.draw.ellipse(icon, cushion_color, (10, 8, 12, 16))
    
    # Draw straps (top and bottom)
    # Top strap
    pygame.draw.rect(icon, strap_color, (6, 8, 20, 3))
    pygame.draw.rect(icon, (30, 30, 40), (6, 9, 20, 1))  # Strap detail
    
    # Bottom strap
    pygame.draw.rect(icon, strap_color, (6, 21, 20, 3))
    pygame.draw.rect(icon, (30, 30, 40), (6, 22, 20, 1))  # Strap detail
    
    # Draw cushion pattern (hexagonal padding)
    # Center padding
    points = [(14, 12), (18, 12), (19, 16), (18, 20), (14, 20), (13, 16)]
    pygame.draw.polygon(icon, highlight_color, points, 1)
    
    # Inner cushion detail
    pygame.draw.line(icon, highlight_color, (14, 14), (18, 14), 1)
    pygame.draw.line(icon, highlight_color, (14, 18), (18, 18), 1)
    
    # Draw buckles on straps
    # Top buckle
    pygame.draw.rect(icon, (150, 150, 160), (24, 8, 4, 3))
    pygame.draw.rect(icon, (120, 120, 130), (25, 9, 2, 1))
    
    # Bottom buckle
    pygame.draw.rect(icon, (150, 150, 160), (24, 21, 4, 3))
    pygame.draw.rect(icon, (120, 120, 130), (25, 22, 2, 1))
    
    # Add some shading/depth
    pygame.draw.ellipse(icon, (50, 50, 70), (8, 6, 16, 20), 1)  # Outline
    
    # Add highlight on the pad
    pygame.draw.arc(icon, (120, 120, 140), (10, 8, 12, 16), 3.14, 4.71, 2)
    
    # Save the icon
    output_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "items", "knee_pads.png")
    pygame.image.save(icon, output_path)
    print(f"무릎보호대 아이콘 생성 완료: {output_path}")
    
    return icon

if __name__ == "__main__":
    icon = create_knee_pads_icon()
    
    # Display the icon for preview
    screen = pygame.display.set_mode((320, 320))
    pygame.display.set_caption("Knee Pads Icon Preview")
    
    # Scale up for better visibility
    scaled_icon = pygame.transform.scale(icon, (256, 256))
    
    running = True
    clock = pygame.time.Clock()
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
        
        screen.fill((200, 200, 200))
        screen.blit(scaled_icon, (32, 32))
        
        # Also show original size
        screen.blit(icon, (144, 280))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()