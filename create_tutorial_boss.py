#!/usr/bin/env python3
"""
Tutorial Boss Instructor Image Generator
Creates a top-down view of a table tennis instructor with red cap
"""

import pygame
import sys
import os

# Initialize Pygame
pygame.init()

# Image dimensions (similar to other boss images)
WIDTH = 120
HEIGHT = 160

# Create surface with transparency
surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
surface.fill((0, 0, 0, 0))  # Transparent background

# Colors
RED_CAP = (200, 40, 40)
RED_CAP_DARK = (150, 30, 30)
RED_CAP_LIGHT = (220, 60, 60)
SKIN_COLOR = (255, 220, 177)
SKIN_SHADOW = (220, 180, 140)
UNIFORM_COLOR = (70, 100, 140)  # Navy blue uniform
UNIFORM_DARK = (50, 70, 100)
UNIFORM_LIGHT = (90, 120, 160)
PADDLE_WOOD = (180, 120, 60)
PADDLE_RUBBER_RED = (200, 40, 40)
PADDLE_RUBBER_BLACK = (40, 40, 40)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
GRAY = (100, 100, 100)

# Center position
center_x = WIDTH // 2
center_y = HEIGHT // 2 - 20  # Slightly above center

# Draw body (torso) - instructor uniform
body_width = 70
body_height = 80
body_y = center_y + 20

# Body shape (shoulders and torso)
pygame.draw.ellipse(surface, UNIFORM_DARK, 
                   (center_x - body_width//2, body_y, body_width, body_height))
pygame.draw.ellipse(surface, UNIFORM_COLOR, 
                   (center_x - body_width//2 + 5, body_y + 5, body_width - 10, body_height - 10))

# Add uniform details - collar
collar_points = [
    (center_x - 15, body_y + 10),
    (center_x, body_y + 5),
    (center_x + 15, body_y + 10),
    (center_x + 10, body_y + 20),
    (center_x, body_y + 15),
    (center_x - 10, body_y + 20)
]
pygame.draw.polygon(surface, WHITE, collar_points)
pygame.draw.polygon(surface, GRAY, collar_points, 2)

# Draw arms
# Left arm (holding paddle)
arm_left_x = center_x - 35
arm_left_y = body_y + 20
pygame.draw.ellipse(surface, SKIN_SHADOW,
                   (arm_left_x - 10, arm_left_y, 20, 40))
pygame.draw.ellipse(surface, SKIN_COLOR,
                   (arm_left_x - 8, arm_left_y + 2, 16, 36))

# Right arm
arm_right_x = center_x + 35
arm_right_y = body_y + 20
pygame.draw.ellipse(surface, SKIN_SHADOW,
                   (arm_right_x - 10, arm_right_y, 20, 40))
pygame.draw.ellipse(surface, SKIN_COLOR,
                   (arm_right_x - 8, arm_right_y + 2, 16, 36))

# Draw paddle in left hand
paddle_x = arm_left_x
paddle_y = arm_left_y + 35
paddle_width = 35
paddle_height = 40

# Paddle handle
handle_width = 8
handle_height = 20
pygame.draw.rect(surface, PADDLE_WOOD,
                (paddle_x - handle_width//2, paddle_y + paddle_height//2 - 5, 
                 handle_width, handle_height))
pygame.draw.rect(surface, BLACK,
                (paddle_x - handle_width//2, paddle_y + paddle_height//2 - 5, 
                 handle_width, handle_height), 1)

# Paddle blade (oval shape)
pygame.draw.ellipse(surface, BLACK,
                   (paddle_x - paddle_width//2 - 2, paddle_y - 2, 
                    paddle_width + 4, paddle_height + 4))
pygame.draw.ellipse(surface, PADDLE_RUBBER_RED,
                   (paddle_x - paddle_width//2, paddle_y, 
                    paddle_width, paddle_height))

# Add paddle rubber texture
for i in range(3):
    y_offset = paddle_y + 10 + i * 10
    pygame.draw.line(surface, (180, 35, 35),
                    (paddle_x - paddle_width//3, y_offset),
                    (paddle_x + paddle_width//3, y_offset), 1)

# Draw head (top-down view)
head_radius = 28
pygame.draw.circle(surface, SKIN_SHADOW, (center_x, center_y), head_radius + 2)
pygame.draw.circle(surface, SKIN_COLOR, (center_x, center_y), head_radius)

# Draw red instructor cap (military style)
cap_y_offset = -5  # Cap sits on top of head

# Cap brim (front part)
brim_width = 50
brim_height = 20
pygame.draw.ellipse(surface, RED_CAP_DARK,
                   (center_x - brim_width//2, center_y - head_radius + cap_y_offset, 
                    brim_width, brim_height))
pygame.draw.ellipse(surface, RED_CAP,
                   (center_x - brim_width//2 + 2, center_y - head_radius + cap_y_offset + 2, 
                    brim_width - 4, brim_height - 4))

# Cap crown (main part)
crown_radius = head_radius - 3
pygame.draw.circle(surface, RED_CAP_DARK, 
                  (center_x, center_y + cap_y_offset), crown_radius)
pygame.draw.circle(surface, RED_CAP, 
                  (center_x, center_y + cap_y_offset), crown_radius - 2)

# Cap button on top
pygame.draw.circle(surface, RED_CAP_LIGHT, 
                  (center_x, center_y + cap_y_offset), 4)
pygame.draw.circle(surface, RED_CAP_DARK, 
                  (center_x, center_y + cap_y_offset), 4, 1)

# Add cap insignia (instructor badge)
badge_size = 12
badge_y = center_y - 10 + cap_y_offset
pygame.draw.circle(surface, (255, 215, 0), (center_x, badge_y), badge_size//2)
pygame.draw.circle(surface, (200, 170, 0), (center_x, badge_y), badge_size//2, 2)

# Draw "COACH" text on badge (if visible)
try:
    font = pygame.font.Font(None, 8)
    text = font.render("T", True, BLACK)
    text_rect = text.get_rect(center=(center_x, badge_y))
    surface.blit(text, text_rect)
except:
    # If font fails, just draw a star
    star_points = []
    for i in range(5):
        angle = i * 144 - 90
        x = center_x + 3 * pygame.math.Vector2(1, 0).rotate(angle).x
        y = badge_y + 3 * pygame.math.Vector2(1, 0).rotate(angle).y
        star_points.append((x, y))
    if len(star_points) > 2:
        pygame.draw.polygon(surface, BLACK, star_points)

# Add some hair visible around cap edges
hair_color = (60, 40, 30)
# Small hair tufts around the edges
for angle in range(30, 151, 30):
    x = center_x + (head_radius - 5) * pygame.math.Vector2(1, 0).rotate(angle + 90).x
    y = center_y + (head_radius - 5) * pygame.math.Vector2(1, 0).rotate(angle + 90).y
    pygame.draw.circle(surface, hair_color, (int(x), int(y)), 3)

# Add facial features hint (since it's top-down, very subtle)
# Just a hint of nose
nose_y = center_y + 5
pygame.draw.circle(surface, SKIN_SHADOW, (center_x, nose_y), 2)

# Add whistle around neck (instructor detail)
whistle_y = body_y + 25
pygame.draw.line(surface, BLACK, 
                (center_x - 10, body_y + 15), 
                (center_x - 5, whistle_y), 2)
pygame.draw.line(surface, BLACK, 
                (center_x + 10, body_y + 15), 
                (center_x + 5, whistle_y), 2)

# Whistle
pygame.draw.rect(surface, (200, 200, 200), 
                (center_x - 5, whistle_y, 10, 6))
pygame.draw.rect(surface, (150, 150, 150), 
                (center_x - 5, whistle_y, 10, 6), 1)

# Add shadow for depth
shadow_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
for i in range(5):
    alpha = 30 - i * 5
    pygame.draw.ellipse(shadow_surface, (0, 0, 0, alpha),
                       (center_x - 40 - i*2, HEIGHT - 30 - i, 80 + i*4, 20 + i*2))
surface.blit(shadow_surface, (0, 0))

# Save the image
output_path = '/Volumes/T7/윈도우용최신/game/bosspong/boss_tutorial.png'
pygame.image.save(surface, output_path)

print(f"✅ Tutorial boss instructor image created: {output_path}")
print("✅ Features:")
print("   - Red instructor cap with badge")
print("   - Navy blue uniform with collar")
print("   - Holding table tennis paddle")
print("   - Top-down perspective view")
print("   - Whistle detail for instructor look")

# Cleanup
pygame.quit()