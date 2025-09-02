#!/usr/bin/env python3
import pygame
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Initialize pygame
pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("Icon Test")

# Import after pygame init
from pingfighter import (
    technical_vest_icon, commando_arm_icon, bluetooth_ring_icon,
    devil_dice_icon, pandora_box_icon, fuel_pouch_icon,
    dowsing_pendulum_icon, molotov_icon, grenade_icon,
    flare_icon, predictor_icon, smoke_grenade_icon, stopwatch_icon
)

# Icon list with names
icons = [
    ("Technical Vest", technical_vest_icon),
    ("Commando Arm", commando_arm_icon),
    ("Bluetooth Ring", bluetooth_ring_icon),
    ("Devil Dice", devil_dice_icon),
    ("Pandora Box", pandora_box_icon),
    ("Fuel Pouch", fuel_pouch_icon),
    ("Dowsing Pendulum", dowsing_pendulum_icon),
    ("Molotov", molotov_icon),
    ("Grenade", grenade_icon),
    ("Flare", flare_icon),
    ("Predictor", predictor_icon),
    ("Smoke Grenade", smoke_grenade_icon),
    ("Stopwatch", stopwatch_icon)
]

# Font for labels
font = pygame.font.Font(None, 24)

# Main loop
clock = pygame.time.Clock()
running = True

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
    
    # Clear screen
    screen.fill((30, 30, 40))
    
    # Draw icons
    x, y = 50, 50
    for name, icon in icons:
        if icon:
            # Draw icon
            screen.blit(icon, (x, y))
            # Draw label
            text = font.render(name, True, (255, 255, 255))
            screen.blit(text, (x + 40, y + 5))
            
            # Status
            status_text = "✓" if icon else "✗"
            status_color = (0, 255, 0) if icon else (255, 0, 0)
            status = font.render(status_text, True, status_color)
            screen.blit(status, (x + 250, y + 5))
        else:
            # Draw error message
            text = font.render(f"{name}: NOT LOADED", True, (255, 0, 0))
            screen.blit(text, (x, y))
        
        y += 40
        if y > 550:
            y = 50
            x += 300
    
    # Update display
    pygame.display.flip()
    clock.tick(60)

pygame.quit()
print("\nIcon Test Complete!")
print(f"Icons loaded: {sum(1 for _, icon in icons if icon)}/{len(icons)}")