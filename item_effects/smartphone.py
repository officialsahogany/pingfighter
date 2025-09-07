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
        """공을 놓칠 위험이 있는지 감지 - 플레이어가 패배 직전 상황 판단"""
        # 게임 상수
        PADDLE_WIDTH = 155  # 패들 너비
        PADDLE_HEIGHT = 50  # 패들 높이
        PLAYER_CENTERX = player_x if player_x is not None else 50  # 실제 플레이어 X 위치
        PLAYER_CENTERY = paddle_y  # 실제 플레이어 Y 위치
        SCREEN_HEIGHT = 800  # 게임 화면 높이
        
        # 플레이어 영역 정의 (화면 하단 영역)
        PLAYER_ZONE_MIN_Y = 550  # 플레이어 영역 시작 Y (화면 하단 250픽셀)
        
        # 공이 플레이어 영역에 있지 않으면 위험 없음
        if ball_y < PLAYER_ZONE_MIN_Y:
            # print(f"[DEBUG] 공이 플레이어 영역 밖에 있음 (y={ball_y:.0f} < {PLAYER_ZONE_MIN_Y}) - 위험 없음")
            return False
        
        # 첫 번째 체크: 공이 플레이어를 향해 오고 있는지 (왼쪽으로 이동)
        if ball_vx >= 0:  # 공이 오른쪽으로 가거나 정지 = 플레이어를 향하지 않음
            # print(f"[DEBUG] 공이 오른쪽으로 이동 중 (vx={ball_vx:.1f}) - 위험 없음")
            return False
        
        # 두 번째 체크: last_hit_by 확인 - 플레이어가 친 공이면 발동 안함
        import sys
        main_module = sys.modules.get('__main__')
        if main_module and hasattr(main_module, 'last_hit_by'):
            last_hit_by = main_module.last_hit_by
            if last_hit_by == "player":
                # print("[DEBUG] 플레이어가 마지막으로 친 공 - 스마트폰 발동 안함")
                return False
            # print(f"[DEBUG] last_hit_by: {last_hit_by}")
        
        # 세 번째 체크: 공이 플레이어 X축 근처에 있는지
        if ball_x > 200:  # 공이 아직 멀리 있으면 (플레이어는 보통 x=50 근처)
            # print(f"[DEBUG] 공이 아직 X축으로 멀리 있음 (x={ball_x:.0f}) - 위험 없음")
            return False
        
        # 공이 플레이어 뒤에 있으면 이미 놓친 것
        if ball_x <= PLAYER_CENTERX:
            print(f"[DEBUG] 공이 이미 플레이어 뒤에 있음 (ball_x: {ball_x:.1f} <= {PLAYER_CENTERX})")
            return False
        
        # X축 거리 계산 (패배 임박 감지의 핵심!)
        x_distance = ball_x - PLAYER_CENTERX
        
        # Y축 거리 계산
        y_distance = abs(ball_y - PLAYER_CENTERY)
        
        # 공 속도
        ball_speed = abs(ball_vx)
        
        # 시나리오 1: 공이 매우 가까이 있음 (절대 위험!)
        if x_distance <= 15 and ball_speed >= 5:  # 15픽셀 이내는 무조건 위험
            print(f"[DEBUG] 🚨🚨 패배 직전! X거리:{x_distance:.0f}px, 속도:{ball_speed:.0f}")
            return True
        
        # 시나리오 1-2: 가까이 있고 Y축 체크 필요
        if x_distance <= 30 and ball_speed >= 5:  # 30픽셀 이내
            # X거리가 20 이하면 대부분 위험 (Y가 가깝고 속도가 느린 경우만 제외)
            if x_distance <= 20:
                # 반응 시간 계산: 20픽셀을 속도로 나눔
                reaction_frames = x_distance / ball_speed
                # Y가 가까우면 (20픽셀 이내) 일반적으로 도달 가능
                if y_distance <= 20:
                    # Y가 매우 가까우면 (10픽셀 이내) 거의 항상 도달 가능
                    if y_distance <= 10:
                        # 초고속이 아니면 안전
                        if reaction_frames <= 2 and ball_speed >= 10:
                            print(f"[DEBUG] 🚨 초고속 근접! 반응시간:{reaction_frames:.1f}프레임")
                            return True
                    else:
                        # Y가 10-20픽셀 거리면 속도에 따라 판단
                        if reaction_frames <= 3 and ball_speed >= 10:
                            print(f"[DEBUG] 🚨 빠른 근접 공! 반응시간:{reaction_frames:.1f}프레임")
                            return True
                    
                    # 특별 케이스: 정확히 같은 Y위치에서 속도 5 이상
                    if y_distance == 0 and ball_speed >= 5 and reaction_frames <= 4:
                        print(f"[DEBUG] 🚨 동일 Y축 빠른 공! 반응시간:{reaction_frames:.1f}프레임")
                        return True
                else:
                    # Y가 멀면 반응 시간이 짧으면 위험
                    if reaction_frames <= 4:
                        print(f"[DEBUG] 🚨 반응 시간 부족! X거리:{x_distance:.0f}, Y거리:{y_distance:.0f}, 반응:{reaction_frames:.1f}프레임")
                        return True
            # 속도가 빠르면 Y축 관계없이 위험
            elif ball_speed >= 10:
                print(f"[DEBUG] 🚨 빠른 공 접근! X거리:{x_distance:.0f}, 속도:{ball_speed:.0f}")
                return True
            # 속도가 보통이면 Y축 체크
            elif y_distance > 30:
                print(f"[DEBUG] 🚨 가까운 공 + Y축 멀음! X거리:{x_distance:.0f}, Y거리:{y_distance:.0f}")
                return True
        
        # 시나리오 1-3: 중간 거리지만 조건부 위험
        if x_distance <= 80 and ball_speed >= 5:  # 80픽셀 이내
            # 플레이어가 Y축으로 도달 가능한지 체크
            PLAYER_NORMAL_SPEED = 10
            frames_to_impact = x_distance / ball_speed if ball_speed > 0 else 999
            frames_needed_for_y = y_distance / PLAYER_NORMAL_SPEED
            
            # Y축으로 도달 불가능하거나 시간이 부족하면 위험
            if y_distance > 50 and frames_needed_for_y > frames_to_impact * 1.2:  # 20% 여유 마진
                print(f"[DEBUG] 🚨 Y축 도달 불가! X거리:{x_distance:.0f}, Y거리:{y_distance:.0f}, 충돌까지:{frames_to_impact:.1f}프레임")
                return True
        
        # 시나리오 2: 초고속 공이 매우 가까이 있음 (거리 조건 강화)
        if x_distance <= 60 and ball_speed >= 20:  # 60픽셀 이내로 축소
            print(f"[DEBUG] 🚨 초고속 공 접근! X거리:{x_distance:.0f}, 속도:{ball_speed:.0f}")
            return True
        
        # 시나리오 3: 공이 패들 범위를 벗어난 위치에 있고 가까이 있음
        PADDLE_REACH = PADDLE_HEIGHT + 20  # 패들이 닿을 수 있는 범위
        if x_distance <= 60 and y_distance > PADDLE_REACH:
            print(f"[DEBUG] 🚨 패들 범위 밖! X거리:{x_distance:.0f}, Y거리:{y_distance:.0f}")
            return True
        
        # 시나리오 4: Y축 이동 시간이 극도로 긴 경우 (80프레임 이상)
        CRITICAL_Y_FRAMES = 80
        frames_needed_for_y = y_distance / 10  # 플레이어 속도 10
        if frames_needed_for_y >= CRITICAL_Y_FRAMES and x_distance <= 200:
            print(f"[DEBUG] 🚨 Y축 이동 불가능! 필요 프레임:{frames_needed_for_y:.0f}, X거리:{x_distance:.0f}")
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