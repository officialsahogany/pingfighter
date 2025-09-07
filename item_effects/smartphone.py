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
        """공을 놓칠 위험이 있는지 감지 - 플레이어가 반격할 수 없는 상황 판단"""
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
        
        # 공 속도가 너무 느리면 무시
        ball_speed = abs(ball_vx)
        if ball_speed < 5:  # 너무 느린 공
            print(f"[DEBUG] 공이 너무 느림 (속도: {ball_speed:.1f} < 5) - 위험 없음")
            return False
            
        # X거리와 Y거리 계산
        x_distance = ball_x - PLAYER_CENTERX
        y_distance = abs(ball_y - PLAYER_CENTERY)
        
        # 도달 시간 계산 (공이 플레이어 X 위치에 도달하는 시간)
        time_to_reach = x_distance / ball_speed if ball_speed > 0 else 999
        
        # 플레이어 이동 속도 (기본 이동 속도와 대쉬 속도)
        PLAYER_NORMAL_SPEED = 10  # 일반 이동 속도
        PLAYER_DASH_SPEED = 20  # 대쉬 속도
        DASH_DURATION = 15  # 대쉬 지속 프레임
        
        # 플레이어가 Y축으로 이동해야 하는 거리
        y_move_needed = y_distance
        
        # 시나리오 1: 매우 빠른 공 (반응 시간 부족)
        if ball_speed >= 20 and time_to_reach <= 8:
            print(f"[DEBUG] 🚨 초고속 공! 반응 불가 (속도: {ball_speed:.1f}, 도달시간: {time_to_reach:.1f}프레임)")
            return True
            
        # 시나리오 2: 가까운 거리에서 빠른 공 + Y축 이동 필요
        if x_distance <= 200 and ball_speed >= 12 and y_distance > 30:
            # 플레이어가 Y축 이동에 필요한 시간
            y_move_time = y_move_needed / PLAYER_NORMAL_SPEED
            if y_move_time > time_to_reach:
                print(f"[DEBUG] 🚨 Y축 이동 불가! (필요시간: {y_move_time:.1f} > 도달시간: {time_to_reach:.1f})")
                return True
                
        # 시나리오 3: 중거리에서 빠른 공
        if x_distance > 150 and x_distance <= 400 and ball_speed >= 15:
            # 대쉬를 사용해도 도달 불가능한지 체크
            if time_to_reach < 10:  # 더 관대한 조건
                print(f"[DEBUG] 🚨 대쉬로도 불가! (도달시간: {time_to_reach:.1f} < 10프레임)")
                return True
                
        # 시나리오 4: 공이 패들 가장자리를 노리는 경우
        if y_distance > PADDLE_HEIGHT - 15:  # 패들 가장자리 근처 (더 넓은 범위)
            if ball_speed >= 10 and time_to_reach <= 15:
                print(f"[DEBUG] 🚨 가장자리 위험! (Y거리: {y_distance:.1f}, 속도: {ball_speed:.1f})")
                return True
                
        # 시나리오 5: 플레이어 높이에서 벗어난 공
        if y_distance > PADDLE_HEIGHT * 2:  # 100픽셀 이상
            # 하지만 매우 빠르면 여전히 위험
            if ball_speed >= 25 and x_distance <= 200:
                print(f"[DEBUG] 🚨 높이 벗어났지만 초고속! (Y거리: {y_distance:.1f}, 속도: {ball_speed:.1f})")
                return True
            else:
                # print(f"[DEBUG] 공이 너무 높거나 낮음 (Y거리: {y_distance:.1f} > 100) - 위험 없음")
                return False
        
        # 시나리오 6: 기본 위험 감지 (심플한 조건)
        # 플레이어 근처에서 빠른 공
        if y_distance <= 80 and x_distance > 100 and ball_speed >= 10:
            print(f"[DEBUG] 🚨 기본 위험! (X:{x_distance:.0f}, Y:{y_distance:.0f}, 속도:{ball_speed:.0f})")
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