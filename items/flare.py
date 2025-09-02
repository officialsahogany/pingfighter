import pygame
import math

# Create flare icon
size = 64
surface = pygame.Surface((size, size), pygame.SRCALPHA)

# Draw flare body (cylindrical shape)
body_color = (200, 200, 180)
body_rect = pygame.Rect(20, 12, 24, 40)
pygame.draw.rect(surface, body_color, body_rect)
pygame.draw.rect(surface, (150, 150, 130), body_rect, 2)

# Draw cap on top
cap_color = (220, 60, 60)
pygame.draw.rect(surface, cap_color, (20, 12, 24, 8))
pygame.draw.rect(surface, (180, 40, 40), (20, 12, 24, 8), 1)

# Draw pull ring
ring_color = (160, 160, 160)
pygame.draw.circle(surface, ring_color, (32, 10), 4, 2)

# Draw light/spark effect on top
for i in range(3):
    spark_color = (255, 255 - i*30, 200 - i*50, 150 - i*40)
    pygame.draw.circle(surface, spark_color, (32, 8), 8 - i*2)

# Draw some warning stripes
stripe_color = (50, 50, 50)
for i in range(3):
    y = 24 + i * 10
    pygame.draw.line(surface, stripe_color, (22, y), (26, y-4), 2)
    pygame.draw.line(surface, stripe_color, (38, y-4), (42, y), 2)

# Save the icon
pygame.image.save(surface, '/Users/pika/Desktop/game/bosspong/items/flare.png')