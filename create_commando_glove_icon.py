import pygame
import sys

# Initialize Pygame
pygame.init()

# Create icon surface
icon_size = 32
icon = pygame.Surface((icon_size, icon_size), pygame.SRCALPHA)
icon.fill((0, 0, 0, 0))  # Transparent background

# Colors
glove_base = (45, 45, 50)  # Dark tactical gray
glove_highlight = (65, 65, 70)  # Lighter gray for details
knuckle_guard = (35, 35, 40)  # Darker for knuckle protection
strap_color = (80, 50, 30)  # Brown leather straps
buckle_color = (160, 160, 160)  # Metal buckles
padding_color = (55, 55, 60)  # Padding areas

# Draw main glove shape (palm and fingers)
# Palm area
pygame.draw.ellipse(icon, glove_base, (7, 12, 14, 16))
pygame.draw.ellipse(icon, glove_highlight, (8, 13, 12, 14))

# Draw fingers
finger_positions = [
    (7, 10, 3, 7),    # Thumb
    (11, 7, 3, 8),    # Index finger
    (14, 6, 3, 9),    # Middle finger
    (17, 7, 3, 8),    # Ring finger
    (20, 9, 3, 7),    # Pinky
]

for x, y, w, h in finger_positions:
    pygame.draw.ellipse(icon, glove_base, (x, y, w, h))
    # Add highlight on each finger
    pygame.draw.ellipse(icon, glove_highlight, (x, y+1, w-1, h-2))

# Draw knuckle guards (tactical protection)
knuckle_positions = [(11, 11), (14, 10), (17, 11), (20, 12)]
for kx, ky in knuckle_positions:
    pygame.draw.circle(icon, knuckle_guard, (kx, ky), 2)
    # Metal stud on knuckles
    pygame.draw.circle(icon, buckle_color, (kx, ky), 1)

# Draw wrist area
pygame.draw.rect(icon, glove_base, (8, 24, 12, 6))
pygame.draw.rect(icon, glove_highlight, (9, 25, 10, 4))

# Draw tactical straps
# Horizontal strap across palm
pygame.draw.rect(icon, strap_color, (7, 18, 14, 2))
# Buckle on strap
pygame.draw.rect(icon, buckle_color, (12, 18, 3, 2))
pygame.draw.rect(icon, (100, 100, 100), (13, 18, 1, 2))  # Buckle detail

# Wrist strap
pygame.draw.rect(icon, strap_color, (7, 26, 14, 2))
pygame.draw.rect(icon, buckle_color, (9, 26, 2, 2))

# Add reinforced padding details
# Palm padding
pygame.draw.ellipse(icon, padding_color, (10, 15, 8, 6))

# Add tactical grip texture (dots)
grip_dots = [
    (11, 16), (13, 15), (15, 16),
    (11, 18), (13, 17), (15, 18),
    (12, 20), (14, 19)
]
for dx, dy in grip_dots:
    pygame.draw.circle(icon, knuckle_guard, (dx, dy), 0)

# Add slight shadow/3D effect on edges
shadow_color = (25, 25, 30, 100)
# Left edge shadow
for i in range(7, 24):
    pygame.draw.line(icon, shadow_color, (6, i), (6, i+1), 1)
# Bottom edge shadow
for i in range(8, 20):
    pygame.draw.line(icon, shadow_color, (i, 29), (i+1, 29), 1)

# Add small military marking/logo
# Small tactical cross or star
pygame.draw.line(icon, (200, 100, 50), (24, 8), (26, 10), 1)
pygame.draw.line(icon, (200, 100, 50), (26, 8), (24, 10), 1)

# Save the icon
pygame.image.save(icon, "items/commando_arm.png")
print("✅ Commando Arm (Tactical Glove) icon created successfully!")

# Display the icon for preview
screen = pygame.display.set_mode((128, 128))
pygame.display.set_caption("Commando Arm - Tactical Glove")
screen.fill((100, 100, 100))

# Scale up for preview
scaled_icon = pygame.transform.scale(icon, (128, 128))
screen.blit(scaled_icon, (0, 0))
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