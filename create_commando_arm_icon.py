import pygame
import sys

# Initialize Pygame
pygame.init()

# Create icon surface
icon_size = 32
icon = pygame.Surface((icon_size, icon_size), pygame.SRCALPHA)
icon.fill((0, 0, 0, 0))  # Transparent background

# Colors
arm_color = (60, 60, 70)  # Dark gray metallic
muscle_color = (100, 100, 110)  # Light gray
band_color = (200, 50, 50)  # Red tactical band
joint_color = (40, 40, 50)  # Dark joint

# Draw muscular arm silhouette
# Upper arm
pygame.draw.ellipse(icon, muscle_color, (8, 6, 10, 14))
pygame.draw.ellipse(icon, arm_color, (9, 7, 8, 12))

# Elbow joint
pygame.draw.circle(icon, joint_color, (13, 20), 3)

# Forearm (more muscular)
pygame.draw.polygon(icon, muscle_color, [
    (11, 20),  # Elbow
    (9, 22),   # Upper forearm outer
    (8, 26),   # Mid forearm outer
    (10, 29),  # Lower forearm outer
    (14, 30),  # Wrist outer
    (16, 29),  # Wrist inner
    (18, 26),  # Lower forearm inner
    (17, 22),  # Mid forearm inner
    (15, 20)   # Elbow inner
])

# Forearm detail
pygame.draw.polygon(icon, arm_color, [
    (12, 21),
    (10, 23),
    (10, 27),
    (13, 29),
    (15, 28),
    (16, 25),
    (15, 22),
    (13, 21)
])

# Tactical bands/straps
pygame.draw.rect(icon, band_color, (9, 24, 8, 2))
pygame.draw.rect(icon, band_color, (10, 27, 6, 2))

# Hand/fist
pygame.draw.ellipse(icon, muscle_color, (11, 28, 7, 6))
pygame.draw.ellipse(icon, arm_color, (12, 29, 5, 4))

# Throwing motion lines (speed effect)
motion_color = (150, 150, 255, 100)
for i in range(3):
    y = 8 + i * 3
    pygame.draw.line(icon, (150, 150, 255), (20 + i * 2, y), (26 + i * 2, y + 1), 1)

# Muscle definition lines
pygame.draw.line(icon, joint_color, (11, 10), (13, 13), 1)
pygame.draw.line(icon, joint_color, (14, 23), (15, 26), 1)

# Power/speed indicator (small star)
star_color = (255, 220, 100)
pygame.draw.circle(icon, star_color, (23, 12), 2)
# Star points
for angle in range(0, 360, 72):
    import math
    x = 23 + int(3 * math.cos(math.radians(angle)))
    y = 12 + int(3 * math.sin(math.radians(angle)))
    pygame.draw.line(icon, star_color, (23, 12), (x, y), 1)

# Save the icon
pygame.image.save(icon, "items/commando_arm.png")
print("✅ Commando Arm icon created successfully!")

# Display the icon for preview
screen = pygame.display.set_mode((128, 128))
pygame.display.set_caption("Commando Arm Icon")
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