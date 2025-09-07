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
        print(f"[DEBUG] 위험 감지 체크 - ball_x: {ball_x:.1f}, ball_vx: {ball_vx:.1f}, ball_y: {ball_y:.1f}, paddle_y: {paddle_y:.1f}")
        
        if ball_vx >= 0:  # Ball moving away from player
            print("[DEBUG] 공이 멀어지는 중 - 위험 없음")
            return False
            
        # 플레이어 패들 X 위치 (왼쪽)
        paddle_x = 50
        
        # 공이 패들 X 위치에 도달할 때까지의 시간 계산
        time_to_paddle = abs(ball_x - paddle_x) / abs(ball_vx) if ball_vx != 0 else float('inf')
        
        # 공이 패들 위치에 도달했을 때의 Y 위치 예측
        future_ball_y = ball_y + ball_vy * time_to_paddle
        
        # 패들의 상하 범위
        paddle_top = paddle_y - paddle_size // 2
        paddle_bottom = paddle_y + paddle_size // 2
        
        # 대쉬로 커버 가능한 거리 (테스트를 위해 줄임)
        dash_coverage = 60  # 120 → 60으로 감소 (더 쉽게 발동)
        
        print(f"[DEBUG] 예측 Y: {future_ball_y:.1f}, 패들 범위: {paddle_top:.1f}~{paddle_bottom:.1f}, 대쉬 커버: {dash_coverage}")
        
        # 위험 판단 조건:
        # 1. 공이 패들 높이를 벗어날 예정이고
        # 2. 대쉬로도 닿을 수 없는 거리이며
        # 3. 공이 충분히 가까이 왔을 때 (테스트를 위해 조건 완화)
        if (future_ball_y < paddle_top - dash_coverage or future_ball_y > paddle_bottom + dash_coverage):
            # 공이 패들에 가까이 왔고 대쉬로도 막을 수 없는 상황
            if ball_x < 200 and ball_vx < 0:  # 120 → 200으로 증가 (더 일찍 발동)
                # 공 속도도 고려 (조건 완화)
                ball_speed = abs(ball_vx)
                if ball_speed > 5 or ball_x < 150:  # 8→5, 100→150으로 완화
                    print(f"[DEBUG] 🚨 위험 감지! ball_x: {ball_x:.1f}, speed: {ball_speed:.1f}")
                    return True
                
        return False
        
    def update(self, game_state, current_stage):
        """위험 감지 및 자동 아이템 사용"""
        if not self.active:
            print("[DEBUG] 스마트폰 update - active가 False라서 중단")
            return
            
        # Cooldown check
        if self.last_activation_time > 0:
            self.last_activation_time -= 1
            if self.last_activation_time % 60 == 0:  # 1초마다 출력
                print(f"[DEBUG] 스마트폰 쿨다운 중: {self.last_activation_time/60:.1f}초 남음")
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
                active_items = game_state.get('active_items', [])
                print(f"[DEBUG] 위험 감지됨! active_items 개수: {len(active_items)}")
                
                # Priority: Stopwatch > AI Pill
                stopwatch_available = False
                ai_pill_available = False
                
                for i, item in enumerate(active_items):
                    if item and isinstance(item, dict):
                        item_name = item.get('name', '')
                        print(f"[DEBUG] 슬롯 {i}: {item_name}")
                        if item_name == 'stopwatch':
                            stopwatch_available = True
                            print("[DEBUG] 스탑워치 발견!")
                        elif item_name == 'aipill':  # Changed from 'ai_pill' to 'aipill'
                            ai_pill_available = True
                            print("[DEBUG] AI알약 발견!")
                            
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
        # Call the global activate_stopwatch function from pingfighter.py
        import sys
        # Get the main module (pingfighter.py)
        main_module = sys.modules.get('__main__')
        if main_module and hasattr(main_module, 'activate_stopwatch'):
            # Check if stopwatch is not already active
            if not getattr(main_module, 'stopwatch_active', False):
                main_module.activate_stopwatch()
                # Remove stopwatch from active items
                active_items = game_state.get('active_items', [])
                for i, item in enumerate(active_items):
                    if item and item.get('name') == 'stopwatch':
                        active_items[i] = None
                        break
        else:
            print("스탑워치 함수를 찾을 수 없습니다")
            
    def activate_ai_pill(self, game_state, current_stage):
        """AI알약 자동 활성화"""
        # Call the global activate_aipill function from pingfighter.py
        import sys
        # Get the main module (pingfighter.py)
        main_module = sys.modules.get('__main__')
        if main_module and hasattr(main_module, 'activate_aipill'):
            # Check if aipill is not already active
            if not getattr(main_module, 'aipill_active', False):
                main_module.activate_aipill()
                # Remove aipill from active items
                active_items = game_state.get('active_items', [])
                for i, item in enumerate(active_items):
                    if item and item.get('name') == 'aipill':
                        active_items[i] = None
                        break
        else:
            print("AI알약 함수를 찾을 수 없습니다")
            
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
        print("[DEBUG] 스마트폰 인스턴스 최초 생성")
        smartphone_instance = Smartphone()
    else:
        print(f"[DEBUG] 기존 스마트폰 인스턴스 반환 - active: {smartphone_instance.active}")
    return smartphone_instance