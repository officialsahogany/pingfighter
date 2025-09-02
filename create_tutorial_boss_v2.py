#!/usr/bin/env python3
"""
Tutorial Boss Instructor Image Generator V2
Creates a more detailed top-down view with better proportions
"""

import pygame
import math

# Initialize Pygame
pygame.init()

# Smaller dimensions
WIDTH = 80
HEIGHT = 100

# Create surface with transparency
surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
surface.fill((0, 0, 0, 0))  # Transparent background

# Colors
RED_CAP = (200, 40, 40)
RED_CAP_DARK = (150, 30, 30)
RED_CAP_LIGHT = (220, 60, 60)
SKIN_COLOR = (255, 220, 177)
SKIN_SHADOW = (220, 180, 140)
SKIN_DARK = (200, 160, 120)
UNIFORM_COLOR = (70, 100, 140)  # Navy blue uniform
UNIFORM_DARK = (50, 70, 100)
UNIFORM_LIGHT = (90, 120, 160)
PADDLE_WOOD = (180, 120, 60)
PADDLE_RUBBER_RED = (200, 40, 40)
PADDLE_RUBBER_BLACK = (40, 40, 40)
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
GRAY = (100, 100, 100)
HAIR_COLOR = (60, 40, 30)
EYE_COLOR = (30, 30, 50)

# Center position
center_x = WIDTH // 2
center_y = HEIGHT // 2 - 10

# Draw shadow first
shadow_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
pygame.draw.ellipse(shadow_surface, (0, 0, 0, 30),
                   (center_x - 25, HEIGHT - 15, 50, 10))
surface.blit(shadow_surface, (0, 0))

# Draw body (more athletic shape, less round)
body_width = 45
body_height = 50
body_y = center_y + 15

# Shoulders (broader, more athletic)
shoulder_points = [
    (center_x - 22, body_y + 5),
    (center_x - 20, body_y),
    (center_x + 20, body_y),
    (center_x + 22, body_y + 5),
    (center_x + 18, body_y + 35),
    (center_x - 18, body_y + 35)
]
pygame.draw.polygon(surface, UNIFORM_DARK, shoulder_points)
pygame.draw.polygon(surface, UNIFORM_COLOR, 
                   [(x + (2 if x < center_x else -2), y + 2) for x, y in shoulder_points[:-2]] + 
                   [(center_x - 16, body_y + 33)])

# Add uniform details
# Collar with more detail
collar_points = [
    (center_x - 10, body_y + 3),
    (center_x, body_y),
    (center_x + 10, body_y + 3),
    (center_x + 8, body_y + 10),
    (center_x, body_y + 8),
    (center_x - 8, body_y + 10)
]
pygame.draw.polygon(surface, WHITE, collar_points)
pygame.draw.polygon(surface, (200, 200, 200), collar_points, 1)

# Pocket detail
pygame.draw.rect(surface, UNIFORM_DARK,
                (center_x - 15, body_y + 12, 8, 6))
pygame.draw.rect(surface, UNIFORM_DARK,
                (center_x + 7, body_y + 12, 8, 6))

# Draw arms with more detail
# Left arm (holding paddle)
arm_left_x = center_x - 20
arm_left_y = body_y + 10

# Upper arm
pygame.draw.ellipse(surface, UNIFORM_DARK,
                   (arm_left_x - 6, arm_left_y, 12, 20))
pygame.draw.ellipse(surface, UNIFORM_COLOR,
                   (arm_left_x - 5, arm_left_y + 1, 10, 18))

# Forearm and hand
pygame.draw.ellipse(surface, SKIN_SHADOW,
                   (arm_left_x - 5, arm_left_y + 18, 10, 15))
pygame.draw.ellipse(surface, SKIN_COLOR,
                   (arm_left_x - 4, arm_left_y + 19, 8, 13))

# Fingers detail
for i in range(3):
    finger_x = arm_left_x - 2 + i * 2
    finger_y = arm_left_y + 30
    pygame.draw.circle(surface, SKIN_DARK, (finger_x, finger_y), 1)

# Right arm (relaxed)
arm_right_x = center_x + 20
arm_right_y = body_y + 10

# Upper arm
pygame.draw.ellipse(surface, UNIFORM_DARK,
                   (arm_right_x - 6, arm_right_y, 12, 20))
pygame.draw.ellipse(surface, UNIFORM_COLOR,
                   (arm_right_x - 5, arm_right_y + 1, 10, 18))

# Forearm
pygame.draw.ellipse(surface, SKIN_SHADOW,
                   (arm_right_x - 5, arm_right_y + 18, 10, 15))
pygame.draw.ellipse(surface, SKIN_COLOR,
                   (arm_right_x - 4, arm_right_y + 19, 8, 13))

# Draw paddle with more detail
paddle_x = arm_left_x
paddle_y = arm_left_y + 25
paddle_width = 25
paddle_height = 30

# Paddle handle
handle_width = 6
handle_height = 15
pygame.draw.rect(surface, PADDLE_WOOD,
                (paddle_x - handle_width//2, paddle_y + paddle_height//2 - 3, 
                 handle_width, handle_height))
pygame.draw.rect(surface, (100, 60, 20),
                (paddle_x - handle_width//2, paddle_y + paddle_height//2 - 3, 
                 handle_width, handle_height), 1)

# Paddle blade with better shape
blade_points = [
    (paddle_x - paddle_width//2, paddle_y + 5),
    (paddle_x - paddle_width//2 + 2, paddle_y),
    (paddle_x + paddle_width//2 - 2, paddle_y),
    (paddle_x + paddle_width//2, paddle_y + 5),
    (paddle_x + paddle_width//2, paddle_y + paddle_height - 5),
    (paddle_x + paddle_width//2 - 2, paddle_y + paddle_height),
    (paddle_x - paddle_width//2 + 2, paddle_y + paddle_height),
    (paddle_x - paddle_width//2, paddle_y + paddle_height - 5)
]

pygame.draw.polygon(surface, BLACK, blade_points)
# Shrink slightly for rubber
inner_blade = [(x + (2 if x < paddle_x else -2) if abs(x - paddle_x) > 3 else x, 
                y + (1 if y < paddle_y + paddle_height//2 else -1)) 
               for x, y in blade_points]
pygame.draw.polygon(surface, PADDLE_RUBBER_RED, inner_blade)

# Paddle texture lines
for i in range(2):
    y_offset = paddle_y + 8 + i * 8
    pygame.draw.line(surface, (180, 35, 35),
                    (paddle_x - paddle_width//3, y_offset),
                    (paddle_x + paddle_width//3, y_offset), 1)

# Draw head with more facial detail
head_radius = 18
head_y = center_y - 5

# Head shape (slightly oval, not perfectly round)
pygame.draw.ellipse(surface, SKIN_SHADOW, 
                   (center_x - head_radius - 1, head_y - head_radius - 1, 
                    head_radius * 2 + 2, head_radius * 2 + 4))
pygame.draw.ellipse(surface, SKIN_COLOR, 
                   (center_x - head_radius, head_y - head_radius, 
                    head_radius * 2, head_radius * 2 + 2))

# Facial features (more detailed)
# Eyes
eye_y = head_y - 2
left_eye_x = center_x - 6
right_eye_x = center_x + 6

# Eye whites
pygame.draw.ellipse(surface, WHITE,
                   (left_eye_x - 3, eye_y - 2, 6, 4))
pygame.draw.ellipse(surface, WHITE,
                   (right_eye_x - 3, eye_y - 2, 6, 4))

# Pupils
pygame.draw.circle(surface, EYE_COLOR, (left_eye_x, eye_y), 2)
pygame.draw.circle(surface, EYE_COLOR, (right_eye_x, eye_y), 2)
pygame.draw.circle(surface, BLACK, (left_eye_x, eye_y), 1)
pygame.draw.circle(surface, BLACK, (right_eye_x, eye_y), 1)

# Eyebrows
pygame.draw.line(surface, HAIR_COLOR,
                (left_eye_x - 3, eye_y - 4),
                (left_eye_x + 2, eye_y - 5), 2)
pygame.draw.line(surface, HAIR_COLOR,
                (right_eye_x - 2, eye_y - 5),
                (right_eye_x + 3, eye_y - 4), 2)

# Nose
nose_y = head_y + 2
pygame.draw.circle(surface, SKIN_SHADOW, (center_x - 1, nose_y), 1)
pygame.draw.circle(surface, SKIN_SHADOW, (center_x + 1, nose_y), 1)

# Mouth (slight smile)
mouth_y = head_y + 6
pygame.draw.arc(surface, (150, 100, 100),
               (center_x - 4, mouth_y - 2, 8, 4),
               0, 3.14, 2)

# Ears
pygame.draw.ellipse(surface, SKIN_SHADOW,
                   (center_x - head_radius - 2, head_y - 3, 5, 8))
pygame.draw.ellipse(surface, SKIN_COLOR,
                   (center_x - head_radius - 1, head_y - 2, 4, 6))
pygame.draw.ellipse(surface, SKIN_SHADOW,
                   (center_x + head_radius - 3, head_y - 3, 5, 8))
pygame.draw.ellipse(surface, SKIN_COLOR,
                   (center_x + head_radius - 2, head_y - 2, 4, 6))

# Draw red instructor cap with more detail
cap_y_offset = -8

# Cap brim (more pronounced)
brim_width = 35
brim_height = 12
pygame.draw.ellipse(surface, RED_CAP_DARK,
                   (center_x - brim_width//2, head_y - head_radius + cap_y_offset - 2, 
                    brim_width, brim_height))
pygame.draw.ellipse(surface, RED_CAP,
                   (center_x - brim_width//2 + 1, head_y - head_radius + cap_y_offset - 1, 
                    brim_width - 2, brim_height - 2))

# Cap crown with seams
crown_radius = head_radius - 2
pygame.draw.circle(surface, RED_CAP_DARK, 
                  (center_x, head_y + cap_y_offset), crown_radius)
pygame.draw.circle(surface, RED_CAP, 
                  (center_x, head_y + cap_y_offset), crown_radius - 1)

# Cap seam lines
for angle in [0, 60, 120, 180, 240, 300]:
    end_x = center_x + crown_radius * math.cos(math.radians(angle))
    end_y = head_y + cap_y_offset + crown_radius * math.sin(math.radians(angle))
    pygame.draw.line(surface, RED_CAP_DARK,
                    (center_x, head_y + cap_y_offset),
                    (end_x, end_y), 1)

# Cap button
pygame.draw.circle(surface, RED_CAP_LIGHT, 
                  (center_x, head_y + cap_y_offset), 3)
pygame.draw.circle(surface, RED_CAP_DARK, 
                  (center_x, head_y + cap_y_offset), 3, 1)

# Cap insignia (instructor badge)
badge_size = 10
badge_y = head_y - 8 + cap_y_offset
pygame.draw.circle(surface, (255, 215, 0), (center_x, badge_y), badge_size//2)
pygame.draw.circle(surface, (200, 170, 0), (center_x, badge_y), badge_size//2, 1)

# Star on badge
star_points = []
for i in range(10):
    angle = i * 36 - 90
    radius = 3 if i % 2 == 0 else 1.5
    x = center_x + radius * math.cos(math.radians(angle))
    y = badge_y + radius * math.sin(math.radians(angle))
    star_points.append((x, y))
pygame.draw.polygon(surface, (150, 100, 0), star_points)

# Hair visible at sides
for x_offset in [-head_radius + 2, head_radius - 2]:
    pygame.draw.ellipse(surface, HAIR_COLOR,
                       (center_x + x_offset - 2, head_y - 2, 4, 6))

# Whistle on cord (detailed)
whistle_y = body_y + 18
pygame.draw.line(surface, BLACK, 
                (center_x - 8, body_y + 10), 
                (center_x - 3, whistle_y), 1)
pygame.draw.line(surface, BLACK, 
                (center_x + 8, body_y + 10), 
                (center_x + 3, whistle_y), 1)

# Whistle body
pygame.draw.ellipse(surface, (200, 200, 200), 
                   (center_x - 4, whistle_y, 8, 5))
pygame.draw.ellipse(surface, (150, 150, 150), 
                   (center_x - 4, whistle_y, 8, 5), 1)
pygame.draw.circle(surface, (100, 100, 100), 
                  (center_x + 3, whistle_y + 2), 1)

# Save the image
output_path = '/Volumes/T7/윈도우용최신/game/bosspong/boss_tutorial.png'
pygame.image.save(surface, output_path)

print(f"✅ Tutorial boss instructor V2 created: {output_path}")
print("✅ Improvements:")
print("   - Smaller size: 80x100px")
print("   - More detailed facial features (eyes, nose, mouth)")
print("   - Athletic body shape (less round)")
print("   - Better proportioned limbs")
print("   - Detailed uniform with pockets")
print("   - Enhanced cap with seams")
print("   - More realistic paddle grip")

# Cleanup
pygame.quit()