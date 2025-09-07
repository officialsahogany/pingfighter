"""
스마트폰 (Smartphone) - 패시브 아이템
플레이어가 스탑워치나 AI알약을 소지하고 있을 경우,
공을 놓치기 직전 순간에 자동으로 해당 아이템을 사용합니다.
"""

import pygame
import math

class Smartphone:
    def __init__(self):
        self.active = False
        self.last_activation_time = 0
        self.activation_cooldown = 180  # 3 seconds cooldown at 60 FPS
        self.danger_threshold = 50  # Distance threshold for danger detection
        self.auto_activated = False  # Flag to prevent multiple activations
        
    def activate(self, game_state, current_stage):
        """패시브 아이템 활성화"""
        self.active = True
        print("스마트폰 패시브 아이템 활성화 - 위험 순간 자동 아이템 사용")
        
    def check_danger(self, ball_x, ball_y, ball_vx, ball_vy, paddle_y, paddle_size):
        """공을 놓칠 위험이 있는지 감지"""
        if ball_vx >= 0:  # Ball moving away from player
            return False
            
        # Calculate where ball will be when it reaches paddle x position
        time_to_paddle = abs(ball_x - 50) / abs(ball_vx) if ball_vx != 0 else float('inf')
        future_ball_y = ball_y + ball_vy * time_to_paddle
        
        # Check if ball will be outside paddle reach
        paddle_top = paddle_y - paddle_size // 2
        paddle_bottom = paddle_y + paddle_size // 2
        
        # Consider it dangerous if ball will be significantly outside paddle range
        if future_ball_y < paddle_top - self.danger_threshold or future_ball_y > paddle_bottom + self.danger_threshold:
            # Also check if ball is close enough to paddle (x-wise)
            if ball_x < 150 and ball_vx < 0:  # Ball approaching and close
                return True
                
        return False
        
    def update(self, game_state, current_stage):
        """위험 감지 및 자동 아이템 사용"""
        if not self.active:
            return
            
        # Cooldown check
        if self.last_activation_time > 0:
            self.last_activation_time -= 1
            return
            
        # Reset auto activation flag if cooldown is over
        if self.last_activation_time <= 0:
            self.auto_activated = False
            
        # Get necessary game state
        ball_x = getattr(current_stage, 'ball_x', 400)
        ball_y = getattr(current_stage, 'ball_y', 300)
        ball_vx = getattr(current_stage, 'ball_vx', 0)
        ball_vy = getattr(current_stage, 'ball_vy', 0)
        paddle_y = getattr(current_stage, 'paddle_y', 300)
        paddle_size = getattr(current_stage, 'paddle_size', 100)
        
        # Check if in danger
        if self.check_danger(ball_x, ball_y, ball_vx, ball_vy, paddle_y, paddle_size):
            if not self.auto_activated:  # Prevent multiple activations
                # Check for active items in player's slots
                active_items = getattr(game_state, 'active_items', [])
                
                # Priority: Stopwatch > AI Pill
                stopwatch_available = False
                ai_pill_available = False
                
                for item in active_items:
                    if item and isinstance(item, dict):
                        item_name = item.get('name', '')
                        if item_name == 'stopwatch':
                            stopwatch_available = True
                        elif item_name == 'ai_pill':
                            ai_pill_available = True
                            
                # Auto-activate appropriate item
                if stopwatch_available:
                    print("🚨 스마트폰: 위험 감지! 스탑워치 자동 사용!")
                    self.activate_stopwatch(game_state, current_stage)
                    self.auto_activated = True
                    self.last_activation_time = self.activation_cooldown
                elif ai_pill_available:
                    print("🚨 스마트폰: 위험 감지! AI알약 자동 사용!")
                    self.activate_ai_pill(game_state, current_stage)
                    self.auto_activated = True
                    self.last_activation_time = self.activation_cooldown
                    
    def activate_stopwatch(self, game_state, current_stage):
        """스탑워치 자동 활성화"""
        # Import stopwatch module
        try:
            from item_effects.stopwatch import get_stopwatch_instance
            stopwatch = get_stopwatch_instance()
            if stopwatch and not stopwatch.active:
                stopwatch.activate(game_state, current_stage)
                # Remove stopwatch from active items
                active_items = getattr(game_state, 'active_items', [])
                for i, item in enumerate(active_items):
                    if item and item.get('name') == 'stopwatch':
                        active_items[i] = None
                        break
        except ImportError:
            print("스탑워치 모듈을 찾을 수 없습니다")
            
    def activate_ai_pill(self, game_state, current_stage):
        """AI알약 자동 활성화"""
        # Import ai_pill module
        try:
            from item_effects.ai_pill import get_ai_pill_instance
            ai_pill = get_ai_pill_instance()
            if ai_pill and not ai_pill.active:
                ai_pill.activate(game_state, current_stage)
                # Remove ai_pill from active items
                active_items = getattr(game_state, 'active_items', [])
                for i, item in enumerate(active_items):
                    if item and item.get('name') == 'ai_pill':
                        active_items[i] = None
                        break
        except ImportError:
            print("AI알약 모듈을 찾을 수 없습니다")
            
    def draw_effects(self, screen, **kwargs):
        """시각적 효과 (선택사항)"""
        if self.active and self.last_activation_time > 0:
            # Draw a small notification when auto-activation happens
            font = pygame.font.Font(None, 24)
            text = font.render("AUTO!", True, (255, 255, 0))
            screen.blit(text, (100, 50))
            
    def draw_icon(self, surface, x, y, size):
        """아이콘 그리기"""
        # Smartphone body
        body_color = (40, 40, 45)
        screen_color = (100, 150, 200)
        button_color = (60, 60, 65)
        
        # Draw body
        body_rect = pygame.Rect(x + size//4, y + size//6, size//2, size*2//3)
        pygame.draw.rect(surface, body_color, body_rect, border_radius=3)
        
        # Draw screen
        screen_rect = pygame.Rect(x + size//4 + 2, y + size//6 + 3, size//2 - 4, size//2 - 4)
        pygame.draw.rect(surface, screen_color, screen_rect)
        
        # Draw home button
        button_rect = pygame.Rect(x + size//2 - 3, y + size*2//3 - 5, 6, 6)
        pygame.draw.circle(surface, button_color, button_rect.center, 3)
        
        # Draw notification icon on screen
        if self.active:
            # Bell icon
            bell_x = x + size//2
            bell_y = y + size//3
            pygame.draw.circle(surface, (255, 255, 100), (bell_x, bell_y), 3)
            pygame.draw.line(surface, (255, 255, 100), (bell_x - 2, bell_y + 2), (bell_x + 2, bell_y + 2))

# Singleton instance
smartphone_instance = None

def get_smartphone_instance():
    global smartphone_instance
    if smartphone_instance is None:
        smartphone_instance = Smartphone()
    return smartphone_instance