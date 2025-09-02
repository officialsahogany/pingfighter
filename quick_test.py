#!/usr/bin/env python3
"""Quick test for balloon machine event"""

import pygame
import sys
from events.stage1_event_integration import Stage1EventManager

# Initialize Pygame
pygame.init()

# Setup
WIDTH = 600
HEIGHT = 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Quick Balloon Event Test")
clock = pygame.time.Clock()

# Create event manager
event_manager = Stage1EventManager()

# Font
try:
    font = pygame.font.Font("NeoDGM.ttf", 24)
except:
    font = pygame.font.Font(None, 24)

print("=" * 50)
print("🎈 QUICK BALLOON EVENT TEST")
print("=" * 50)
print("Testing event trigger at 2 points...")

# Simulate triggering condition
player_score = 2
current_stage = 1

# Check if event should trigger
if event_manager.check_events(player_score, 0, current_stage, 1):
    print("✅ Event trigger condition met!")
    
    # Trigger the event
    if event_manager.trigger_event(screen, player_score, current_stage):
        print("✅ Event triggered successfully!")
    else:
        print("❌ Event failed to trigger")
else:
    print("❌ Event trigger condition not met")

# Run for a few frames to test
running = True
frames = 0
max_frames = 300  # 5 seconds at 60 FPS

while running and frames < max_frames:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
    
    # Clear screen
    screen.fill((30, 30, 40))
    
    # Update event
    event_active = event_manager.update()
    
    # Draw event
    event_manager.draw(screen)
    
    # Show status
    status = "Event Active" if event_active else "Event Completed" if frames > 60 else "Event Running"
    text = font.render(status, True, (255, 255, 255))
    screen.blit(text, (WIDTH // 2 - text.get_width() // 2, 50))
    
    # Show balloon count
    balloon_count = len(event_manager.get_active_balloons())
    balloon_text = font.render(f"Balloons: {balloon_count}", True, (255, 255, 100))
    screen.blit(balloon_text, (WIDTH // 2 - balloon_text.get_width() // 2, 80))
    
    pygame.display.flip()
    clock.tick(60)
    frames += 1
    
    if frames == 60:
        print(f"Frame 60: {balloon_count} balloons active")
    elif frames == 120:
        print(f"Frame 120: {balloon_count} balloons active")

print(f"Test completed. Final balloon count: {len(event_manager.get_active_balloons())}")
pygame.quit()
sys.exit()