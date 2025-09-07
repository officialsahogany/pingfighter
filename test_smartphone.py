"""
테스트 스크립트 - 스마트폰 패시브 아이템
스탑워치나 AI알약 소지 시 위험 순간 자동 사용 테스트
"""

import pygame
import sys
import os
import random

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Initialize Pygame
pygame.init()
pygame.mixer.init()

# Screen setup
WIDTH, HEIGHT = 600, 750
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Smartphone Item Test")
clock = pygame.time.Clock()

# Import modules
from item_effects.smartphone import get_smartphone_instance
import items

# Colors
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 100, 100)
GREEN = (100, 255, 100)
BLUE = (100, 150, 255)
YELLOW = (255, 255, 100)
CYAN = (100, 255, 255)

# Game state
paddle_y = HEIGHT - 100
paddle_height = 80
paddle_width = 15
ball_x = WIDTH // 2
ball_y = 100
ball_vx = -3
ball_vy = 5
danger_timer = 0

# Active items (stopwatch, ai_pill)
active_items = [
    {"name": "stopwatch", "active": False},
    {"name": "ai_pill", "active": False},
    None
]

# Smartphone instance
smartphone = get_smartphone_instance()
items.smartphone_obtained = True

def draw_game_state():
    """게임 상태 그리기"""
    SCREEN.fill(BLACK)
    
    # Draw paddle
    paddle_rect = pygame.Rect(50 - paddle_width//2, paddle_y - paddle_height//2, paddle_width, paddle_height)
    pygame.draw.rect(SCREEN, WHITE, paddle_rect)
    
    # Draw ball
    pygame.draw.circle(SCREEN, YELLOW, (int(ball_x), int(ball_y)), 10)
    
    # Draw ball trajectory preview
    if ball_vx < 0:  # Ball moving towards player
        time_to_paddle = abs(ball_x - 50) / abs(ball_vx) if ball_vx != 0 else float('inf')
        future_y = ball_y + ball_vy * time_to_paddle
        pygame.draw.circle(SCREEN, (100, 100, 100), (50, int(future_y)), 5)
        
        # Show danger zone
        if abs(future_y - paddle_y) > paddle_height // 2 + 50:
            pygame.draw.circle(SCREEN, RED, (50, int(future_y)), 8, 2)
    
    # Status text
    font = pygame.font.Font(None, 24)
    
    # Title
    title = font.render("Smartphone Auto-Item Test", True, CYAN)
    SCREEN.blit(title, (WIDTH//2 - title.get_width()//2, 20))
    
    # Instructions
    inst_font = pygame.font.Font(None, 20)
    instructions = [
        "1-3: Toggle active items (Stopwatch/AI Pill)",
        "SPACE: Activate smartphone passive",
        "R: Reset ball position",
        "UP/DOWN: Move paddle"
    ]
    y_pos = 60
    for inst in instructions:
        text = inst_font.render(inst, True, WHITE)
        SCREEN.blit(text, (20, y_pos))
        y_pos += 25
    
    # Active items display
    y_pos = 200
    text = font.render("Active Items:", True, YELLOW)
    SCREEN.blit(text, (20, y_pos))
    y_pos += 30
    
    for i, item in enumerate(active_items):
        if item:
            color = GREEN if not item.get("active", False) else RED
            item_text = f"Slot {i+1}: {item['name']}"
            text = inst_font.render(item_text, True, color)
            SCREEN.blit(text, (40, y_pos))
        else:
            text = inst_font.render(f"Slot {i+1}: Empty", True, (100, 100, 100))
            SCREEN.blit(text, (40, y_pos))
        y_pos += 25
    
    # Smartphone status
    y_pos = 320
    status_color = GREEN if smartphone.active else RED
    status_text = "ACTIVE" if smartphone.active else "INACTIVE"
    text = font.render(f"Smartphone: {status_text}", True, status_color)
    SCREEN.blit(text, (20, y_pos))
    
    if smartphone.last_activation_time > 0:
        cooldown_text = f"Cooldown: {smartphone.last_activation_time} frames"
        text = inst_font.render(cooldown_text, True, YELLOW)
        SCREEN.blit(text, (20, y_pos + 30))
    
    # Danger detection
    if ball_vx < 0:
        danger = smartphone.check_danger(ball_x, ball_y, ball_vx, ball_vy, paddle_y, paddle_height)
        if danger:
            danger_text = font.render("DANGER DETECTED!", True, RED)
            SCREEN.blit(danger_text, (WIDTH//2 - danger_text.get_width()//2, HEIGHT//2))

def main():
    global ball_x, ball_y, ball_vx, ball_vy, paddle_y
    global active_items
    
    running = True
    smartphone.active = False
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_1:
                    # Toggle stopwatch in slot 0
                    if active_items[0] and active_items[0]["name"] == "stopwatch":
                        active_items[0] = None
                    else:
                        active_items[0] = {"name": "stopwatch", "active": False}
                elif event.key == pygame.K_2:
                    # Toggle AI pill in slot 1
                    if active_items[1] and active_items[1]["name"] == "ai_pill":
                        active_items[1] = None
                    else:
                        active_items[1] = {"name": "ai_pill", "active": False}
                elif event.key == pygame.K_3:
                    # Clear slot 2
                    active_items[2] = None
                elif event.key == pygame.K_SPACE:
                    # Activate smartphone
                    game_state = {
                        'current_stage': None,
                        'active_items': active_items
                    }
                    smartphone.activate(game_state, None)
                elif event.key == pygame.K_r:
                    # Reset ball
                    ball_x = WIDTH // 2
                    ball_y = 100
                    ball_vx = -3
                    ball_vy = 5
                    # Reset active item states
                    for item in active_items:
                        if item:
                            item["active"] = False
                    smartphone.auto_activated = False
        
        # Handle input
        keys = pygame.key.get_pressed()
        if keys[pygame.K_UP]:
            paddle_y = max(paddle_height//2, paddle_y - 5)
        if keys[pygame.K_DOWN]:
            paddle_y = min(HEIGHT - paddle_height//2, paddle_y + 5)
        
        # Update ball
        ball_x += ball_vx
        ball_y += ball_vy
        
        # Ball boundaries
        if ball_x <= 10 or ball_x >= WIDTH - 10:
            ball_vx = -ball_vx
        if ball_y <= 10:
            ball_vy = -ball_vy
        if ball_y >= HEIGHT - 10:
            # Reset ball
            ball_x = WIDTH // 2
            ball_y = 100
            ball_vx = -3
            ball_vy = 5
        
        # Check paddle collision
        if ball_x <= 60 and abs(ball_y - paddle_y) < paddle_height // 2 + 10:
            ball_vx = abs(ball_vx)
        
        # Update smartphone
        if smartphone.active:
            game_state = {
                'current_stage': None,
                'active_items': active_items
            }
            
            # Create stage info
            class StageInfo:
                def __init__(self):
                    self.ball_x = ball_x
                    self.ball_y = ball_y
                    self.ball_vx = ball_vx
                    self.ball_vy = ball_vy
                    self.paddle_y = paddle_y
                    self.paddle_size = paddle_height
            
            stage_info = StageInfo()
            smartphone.update(game_state, stage_info)
        
        # Decrease cooldown
        if smartphone.last_activation_time > 0:
            smartphone.last_activation_time -= 1
        
        # Draw everything
        draw_game_state()
        
        # Draw smartphone effects
        if smartphone.active:
            smartphone.draw_effects(SCREEN)
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()