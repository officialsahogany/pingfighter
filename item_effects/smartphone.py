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
        
    def check_danger(self, ball_x, ball_y, ball_vx, ball_vy, paddle_y, paddle_size, player_x=None):
        """공을 놓칠 위험이 있는지 감지 - 플레이어가 가드할 수 없는 상황 판단"""
        # 게임 상수
        PADDLE_WIDTH = 155  # 패들 너비
        PADDLE_HEIGHT = 50  # 패들 높이
        PLAYER_CENTERX = player_x if player_x is not None else 50  # 실제 플레이어 X 위치
        PLAYER_CENTERY = paddle_y  # 실제 플레이어 Y 위치
        
        # 기본 조건: 공이 플레이어를 향해 오고 있는지
        if ball_vx >= 0:  # 공이 오른쪽으로 가거나 정지
            print("[DEBUG] 공이 플레이어를 향하지 않음 - 위험 없음")
            return False
        
        # 공이 플레이어 뒤에 있으면 무시
        if ball_x <= PLAYER_CENTERX:
            print(f"[DEBUG] 공이 플레이어 뒤에 있음 (ball_x: {ball_x:.1f} <= {PLAYER_CENTERX}) - 위험 없음")
            return False
        
        # Y축 거리 계산 (이것이 핵심!)
        y_distance = abs(ball_y - PLAYER_CENTERY)
        
        # 플레이어 이동 속도
        PLAYER_NORMAL_SPEED = 10  # 일반 이동 속도 (픽셀/프레임)
        
        # Y축 이동에 필요한 시간 계산 (프레임)
        frames_needed_for_y = y_distance / PLAYER_NORMAL_SPEED
        
        # 핵심 조건: Y축 이동에 80프레임 이상 필요하면 가드 불가능
        CRITICAL_FRAME_THRESHOLD = 80  # 80프레임 (약 1.3초)
        
        if frames_needed_for_y >= CRITICAL_FRAME_THRESHOLD:
            print(f"[DEBUG] 🚨🚨🚨 가드 불가능! Y축 이동에 {frames_needed_for_y:.0f}프레임 필요 (임계값: {CRITICAL_FRAME_THRESHOLD})")
            print(f"[DEBUG] 공 위치: ({ball_x:.0f}, {ball_y:.0f}), 플레이어 Y: {PLAYER_CENTERY:.0f}, Y거리: {y_distance:.0f}")
            return True
        
        # 추가 보호 조건: 공이 매우 가까이 있고 Y축 거리가 멀 때
        x_distance = ball_x - PLAYER_CENTERX
        
        # 공이 플레이어에게 도달하는 시간 계산
        ball_speed = abs(ball_vx)
        if ball_speed > 0 and x_distance < 100:  # 매우 가까운 공만 체크
            time_to_reach = x_distance / ball_speed
            
            # 공이 도달하는 시간보다 Y축 이동 시간이 더 오래 걸리면 위험
            # 그리고 Y축 거리가 충분히 멀 때만
            if frames_needed_for_y > time_to_reach and y_distance > 50:
                print(f"[DEBUG] 🚨 가까운 공! Y축 이동 시간({frames_needed_for_y:.0f}) > 공 도달 시간({time_to_reach:.0f}) - 가드 불가!")
                return True
        
        # 모든 조건을 통과하면 안전
        return False
        
    def update(self, game_state, current_stage):
        """위험 감지 및 자동 아이템 사용"""
        print(f"[DEBUG] 스마트폰 update 호출됨 - active: {self.active}")
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
        
        # Get actual player X position from main module if available
        import sys
        main_module = sys.modules.get('__main__')
        if main_module and hasattr(main_module, 'PLAYER'):
            player_rect = main_module.PLAYER
            if player_rect:
                player_x = player_rect.centerx
                print(f"[DEBUG] 실제 플레이어 X 위치: {player_x}")
            else:
                player_x = 50  # Default fallback
        else:
            player_x = 50  # Default fallback
        
        # Check if in danger (pass actual player X position)
        if self.check_danger(ball_x, ball_y, ball_vx, ball_vy, paddle_y, paddle_size, player_x):
            if not self.auto_activated:  # Prevent multiple activations
                # Check for active items in player's slots
                active_items = game_state.get('active_items', [])
                print(f"[DEBUG] 위험 감지됨! active_items 개수: {len(active_items)}")
                print(f"[DEBUG] active_items 내용: {[item.get('name') if item else None for item in active_items]}")
                
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
                # Remove stopwatch from active items in the actual game slot
                if hasattr(main_module, 'active_item_slot'):
                    active_item_slot = main_module.active_item_slot
                    if active_item_slot:
                        # Find and delete the stopwatch item (like normal usage)
                        for i in range(len(active_item_slot) - 1, -1, -1):  # Iterate backwards to avoid index issues
                            item = active_item_slot[i]
                            if item and item.get('name') == 'stopwatch':
                                del active_item_slot[i]  # Completely remove from list
                                print(f"[DEBUG] 스마트폰이 스탑워치를 슬롯 {i}에서 완전히 제거 (del 사용)")
                                # Adjust selected index if needed
                                if hasattr(main_module, 'selected_item_index'):
                                    if main_module.selected_item_index >= len(active_item_slot):
                                        main_module.selected_item_index = max(0, len(active_item_slot) - 1)
                                break
                # Also remove from local game_state for consistency
                active_items = game_state.get('active_items', [])
                for i in range(len(active_items) - 1, -1, -1):
                    if active_items[i] and active_items[i].get('name') == 'stopwatch':
                        del active_items[i]
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
                # Remove aipill from active items in the actual game slot
                if hasattr(main_module, 'active_item_slot'):
                    active_item_slot = main_module.active_item_slot
                    if active_item_slot:
                        # Find and delete the aipill item (like normal usage)
                        for i in range(len(active_item_slot) - 1, -1, -1):  # Iterate backwards to avoid index issues
                            item = active_item_slot[i]
                            if item and item.get('name') == 'aipill':
                                del active_item_slot[i]  # Completely remove from list
                                print(f"[DEBUG] 스마트폰이 AI알약을 슬롯 {i}에서 완전히 제거 (del 사용)")
                                # Adjust selected index if needed
                                if hasattr(main_module, 'selected_item_index'):
                                    if main_module.selected_item_index >= len(active_item_slot):
                                        main_module.selected_item_index = max(0, len(active_item_slot) - 1)
                                break
                # Also remove from local game_state for consistency
                active_items = game_state.get('active_items', [])
                for i in range(len(active_items) - 1, -1, -1):
                    if active_items[i] and active_items[i].get('name') == 'aipill':
                        del active_items[i]
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