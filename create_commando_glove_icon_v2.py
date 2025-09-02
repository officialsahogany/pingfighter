import pygame
import sys
import math

# Initialize Pygame
pygame.init()

# Create icon surface
icon_size = 32
icon = pygame.Surface((icon_size, icon_size), pygame.SRCALPHA)
icon.fill((0, 0, 0, 0))  # Transparent background

# Colors
glove_black = (25, 25, 30)  # Main black tactical color
glove_dark = (35, 35, 40)  # Dark gray for shadows
glove_mid = (55, 55, 65)  # Mid gray for base
glove_light = (75, 75, 85)  # Light gray for highlights
carbon_fiber = (45, 45, 55)  # Carbon fiber texture
knuckle_armor = (90, 90, 100)  # Metallic knuckle guards
accent_red = (180, 30, 30)  # Red accent color
accent_orange = (255, 140, 0)  # Orange accent for power
metal_silver = (180, 180, 190)  # Metal parts
rubber_grip = (30, 30, 35)  # Rubber grip areas

# Draw main glove shape with better proportions
# Wrist/cuff area (wider base)
pygame.draw.polygon(icon, glove_black, [
    (6, 26), (6, 30), (20, 30), (20, 26),
    (18, 24), (8, 24)
])
pygame.draw.polygon(icon, glove_mid, [
    (7, 27), (7, 29), (19, 29), (19, 27),
    (17, 25), (9, 25)
])

# Palm area (main body)
pygame.draw.polygon(icon, glove_black, [
    (8, 24), (6, 20), (6, 14), (8, 10),
    (18, 10), (20, 14), (20, 20), (18, 24)
])
pygame.draw.polygon(icon, glove_mid, [
    (9, 23), (7, 19), (7, 15), (9, 11),
    (17, 11), (19, 15), (19, 19), (17, 23)
])

# Carbon fiber texture on palm
for i in range(3):
    y = 14 + i * 3
    pygame.draw.line(icon, carbon_fiber, (9, y), (17, y), 1)
    if i < 2:
        pygame.draw.line(icon, glove_dark, (10, y+1), (16, y+1), 1)

# Draw fingers with tactical segments
# Thumb (side position)
pygame.draw.polygon(icon, glove_black, [
    (5, 14), (3, 12), (3, 9), (5, 7), (7, 7), (8, 10), (7, 14)
])
pygame.draw.polygon(icon, glove_mid, [
    (5, 13), (4, 11), (4, 9), (5, 8), (6, 8), (7, 10), (6, 13)
])

# Four main fingers
finger_data = [
    # (base_x, width, height, tip_offset)
    (9, 3, 9, 0),    # Index
    (12, 3, 10, -1),  # Middle (longest)
    (15, 3, 9, 0),    # Ring
    (18, 2, 8, 1),    # Pinky (shortest)
]

for base_x, width, height, tip_offset in finger_data:
    # Draw finger
    pygame.draw.polygon(icon, glove_black, [
        (base_x, 10),
        (base_x, 10 - height),
        (base_x + width, 10 - height + tip_offset),
        (base_x + width, 10)
    ])
    pygame.draw.polygon(icon, glove_mid, [
        (base_x + 1, 9),
        (base_x + 1, 10 - height + 1),
        (base_x + width - 1, 10 - height + tip_offset + 1),
        (base_x + width - 1, 9)
    ])
    
    # Finger joints/segments
    for j in range(2):
        joint_y = 10 - height + 2 + j * 3
        if joint_y < 10:
            pygame.draw.line(icon, glove_dark, (base_x, joint_y), (base_x + width, joint_y), 1)

# Draw armored knuckle guards (metallic protection)
knuckle_positions = [(10, 11), (13, 10), (16, 11), (18, 12)]
for kx, ky in knuckle_positions:
    # Outer armor plate
    pygame.draw.circle(icon, knuckle_armor, (kx, ky), 2)
    pygame.draw.circle(icon, metal_silver, (kx, ky), 1)
    # Inner detail
    pygame.draw.circle(icon, glove_black, (kx, ky), 0)

# Tactical straps with buckles
# Upper strap
pygame.draw.rect(icon, rubber_grip, (6, 17, 14, 3))
pygame.draw.rect(icon, glove_black, (6, 18, 14, 1))
# Buckle
pygame.draw.rect(icon, metal_silver, (11, 17, 4, 3))
pygame.draw.rect(icon, knuckle_armor, (12, 18, 2, 1))

# Wrist strap with velcro detail
pygame.draw.rect(icon, rubber_grip, (6, 27, 14, 2))
for i in range(7, 19, 2):
    pygame.draw.line(icon, glove_black, (i, 27), (i, 29), 1)

# Power indicator/accent lighting
# Red power lines along sides
pygame.draw.line(icon, accent_red, (6, 16), (6, 22), 1)
pygame.draw.line(icon, accent_red, (20, 16), (20, 22), 1)

# Orange glow effect on knuckles (power boost indication)
for kx, ky in knuckle_positions:
    # Create glow effect
    glow_surface = pygame.Surface((6, 6), pygame.SRCALPHA)
    pygame.draw.circle(glow_surface, (*accent_orange, 40), (3, 3), 3)
    icon.blit(glow_surface, (kx-3, ky-3))

# Tactical grip dots/texture
grip_pattern = [
    (10, 14), (12, 15), (14, 14), (16, 15),
    (10, 17), (12, 18), (14, 17), (16, 18),
    (11, 20), (13, 21), (15, 20)
]
for gx, gy in grip_pattern:
    pygame.draw.circle(icon, rubber_grip, (gx, gy), 0)

# Add brand/logo detail (small tactical symbol)
# Draw a small power/speed symbol
pygame.draw.lines(icon, accent_orange, False, [
    (24, 6), (26, 4), (28, 6)
], 1)
pygame.draw.circle(icon, accent_red, (26, 7), 1)

# Edge highlights for 3D effect
# Left edge highlight
for i in range(10, 24):
    icon.set_at((7, i), glove_light)
# Top finger highlights
for i in range(9, 19):
    if i in [10, 13, 16, 18]:
        icon.set_at((i, 2), glove_light)

# Shadow for depth
shadow_color = (15, 15, 20, 80)
for i in range(8, 20):
    for j in range(28, 31):
        if j < 30:
            icon.set_at((i, j), shadow_color)

# Save the icon
pygame.image.save(icon, "items/commando_arm.png")
print("✅ Commando Arm (Cool Tactical Glove) icon created successfully!")

# Display the icon for preview
screen = pygame.display.set_mode((256, 256))
pygame.display.set_caption("Commando Arm - Tactical Combat Glove")
screen.fill((80, 80, 80))

# Scale up for preview
scaled_icon = pygame.transform.scale(icon, (256, 256))
screen.blit(scaled_icon, (0, 0))

# Also show original size in corner
original_bg = pygame.Surface((48, 48))
original_bg.fill((120, 120, 120))
original_bg.blit(icon, (8, 8))
screen.blit(original_bg, (200, 200))

pygame.display.flip()

# Wait for user to close
running = True
clock = pygame.time.Clock()
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
    clock.tick(60)

pygame.quit()
sys.exit()