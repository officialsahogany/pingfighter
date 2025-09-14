#!/usr/bin/env python3
"""
Test script to verify brick collision detection fix
Tests that balls with various speeds properly collide with bricks
"""

import pygame
import sys
import os
import math

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Initialize Pygame
pygame.init()
WIDTH, HEIGHT = 800, 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Brick Collision Test")
clock = pygame.time.Clock()

# Colors
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
BROWN = (139, 69, 19)
YELLOW = (255, 255, 0)

# Test parameters
test_cases = [
    {"name": "Slow Ball", "speed": 5, "angle": 45},
    {"name": "Medium Ball", "speed": 15, "angle": 45},
    {"name": "Fast Ball", "speed": 25, "angle": 45},
    {"name": "Very Fast Ball", "speed": 35, "angle": 45},
    {"name": "Extreme Ball", "speed": 50, "angle": 45},
]

current_test = 0
ball_pos = [WIDTH // 2, HEIGHT - 100]
ball_vel = [0, 0]
ball_radius = 5
walls = []
wall_width = 60
wall_height = 30

# Create test walls
for i in range(3):
    for j in range(5):
        wall = {
            "rect": pygame.Rect(150 + j * 100, 100 + i * 60, wall_width, wall_height),
            "hit_count": 0,
            "crack_level": 0
        }
        walls.append(wall)

def start_test(test_index):
    """Start a new test with given parameters"""
    global ball_pos, ball_vel
    if test_index >= len(test_cases):
        return False
    
    test = test_cases[test_index]
    ball_pos = [WIDTH // 2, HEIGHT - 100]
    angle_rad = math.radians(test["angle"])
    ball_vel = [
        test["speed"] * math.cos(angle_rad),
        -test["speed"] * math.sin(angle_rad)
    ]
    
    # Reset walls
    for wall in walls:
        wall["hit_count"] = 0
        wall["crack_level"] = 0
    
    print(f"\nStarting test: {test['name']} (Speed: {test['speed']})")
    return True

def update_physics(dt):
    """Update ball physics with sub-stepping"""
    global ball_pos, ball_vel, walls
    
    # Calculate total movement
    total_vel_x = ball_vel[0] * dt
    total_vel_y = ball_vel[1] * dt
    
    # Sub-stepping for collision detection
    max_step = 5  # Maximum step size in pixels
    total_distance = math.sqrt(total_vel_x**2 + total_vel_y**2)
    
    if total_distance > 0:
        num_steps = max(1, int(total_distance / max_step))
        step_vel_x = total_vel_x / num_steps
        step_vel_y = total_vel_y / num_steps
        
        for step in range(num_steps):
            # Save old position
            old_x = ball_pos[0]
            old_y = ball_pos[1]
            
            # Move ball
            ball_pos[0] += step_vel_x
            ball_pos[1] += step_vel_y
            
            # Create ball rect for collision
            ball_rect = pygame.Rect(
                ball_pos[0] - ball_radius,
                ball_pos[1] - ball_radius,
                ball_radius * 2,
                ball_radius * 2
            )
            
            # Check wall collisions
            for wall in walls[:]:
                if ball_rect.colliderect(wall["rect"]):
                    # Restore position
                    ball_pos[0] = old_x
                    ball_pos[1] = old_y
                    
                    # Increase hit count
                    wall["hit_count"] += 1
                    wall["crack_level"] = wall["hit_count"]
                    
                    # Calculate collision response
                    wall_center_x = wall["rect"].centerx
                    wall_center_y = wall["rect"].centery
                    dx = ball_pos[0] - wall_center_x
                    dy = ball_pos[1] - wall_center_y
                    
                    # Determine collision side and reflect
                    if abs(dy) > abs(dx):
                        ball_vel[1] = -ball_vel[1]
                        if dy > 0:
                            ball_pos[1] = wall["rect"].bottom + ball_radius
                        else:
                            ball_pos[1] = wall["rect"].top - ball_radius
                    else:
                        ball_vel[0] = -ball_vel[0]
                        if dx > 0:
                            ball_pos[0] = wall["rect"].right + ball_radius
                        else:
                            ball_pos[0] = wall["rect"].left - ball_radius
                    
                    # Apply damping
                    ball_vel[0] *= 0.9
                    ball_vel[1] *= 0.9
                    
                    print(f"  Hit wall at ({wall_center_x}, {wall_center_y}), hits: {wall['hit_count']}")
                    
                    # Remove wall if destroyed
                    if wall["hit_count"] >= 2:
                        walls.remove(wall)
                        print(f"  Wall destroyed!")
                    
                    break
    
    # Boundary collisions
    if ball_pos[0] - ball_radius <= 0 or ball_pos[0] + ball_radius >= WIDTH:
        ball_vel[0] = -ball_vel[0]
        ball_pos[0] = max(ball_radius, min(WIDTH - ball_radius, ball_pos[0]))
    
    if ball_pos[1] - ball_radius <= 0:
        ball_vel[1] = -ball_vel[1]
        ball_pos[1] = ball_radius
    
    # Reset if ball goes off bottom
    if ball_pos[1] > HEIGHT:
        return False
    
    return True

def draw_scene():
    """Draw the test scene"""
    screen.fill(BLACK)
    
    # Draw walls
    for wall in walls:
        color = BROWN
        if wall["crack_level"] == 1:
            color = (109, 49, 9)  # Darker brown for cracked
        pygame.draw.rect(screen, color, wall["rect"])
        pygame.draw.rect(screen, WHITE, wall["rect"], 1)
    
    # Draw ball
    pygame.draw.circle(screen, YELLOW, (int(ball_pos[0]), int(ball_pos[1])), ball_radius)
    
    # Draw test info
    if current_test < len(test_cases):
        test = test_cases[current_test]
        font = pygame.font.Font(None, 36)
        text = font.render(f"Test: {test['name']} (Speed: {test['speed']})", True, WHITE)
        screen.blit(text, (10, 10))
        
        text2 = font.render(f"Walls remaining: {len(walls)}", True, WHITE)
        screen.blit(text2, (10, 50))
        
        text3 = font.render("Press SPACE for next test, ESC to exit", True, GREEN)
        screen.blit(text3, (10, HEIGHT - 40))
    
    pygame.display.flip()

# Start first test
start_test(0)

# Main loop
running = True
while running:
    dt = clock.tick(60) / 1000.0  # Delta time in seconds
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                current_test += 1
                if not start_test(current_test):
                    print("\nAll tests completed!")
                    current_test = 0
                    start_test(0)
    
    # Update physics
    if not update_physics(dt):
        # Ball went off screen, restart current test
        print(f"  Ball went off screen, restarting test...")
        start_test(current_test)
    
    # Draw everything
    draw_scene()

pygame.quit()
print("\nTest completed. Check console output for collision results.")