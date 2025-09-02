"""
블루투스링 아이템 효과
패들에 공이 닿을 때 게이지 충전량 25% 증가
"""

import pygame

class BluetoothRing:
    def __init__(self):
        self.active = False
        self.gauge_charge_bonus = 0.25  # 25% 게이지 충전량 증가
        
    def activate(self, game_state, current_stage):
        """블루투스링 아이템 활성화"""
        print(f" DEBUG: BluetoothRing.activate()  -  : {self.active}")
        if not self.active:
            self.active = True
            print(f"  !   +{int(self.gauge_charge_bonus * 100)}%")
        print(f" DEBUG: BluetoothRing.activate()  -  : {self.active}")
        
    def deactivate(self):
        """블루투스링 비활성화 (스테이지 종료 시)"""
        self.active = False
        
    def update(self, current_stage):
        """상태 업데이트 (패시브 아이템이므로 특별한 업데이트 없음)"""
        pass
    
    def draw_effects(self, screen, **kwargs):
        """시각 효과 그리기"""
        if not self.active:
            return
            
        # 패들 근처에 작은 블루투스 아이콘 표시 (선택사항)
        if 'paddle_rect' in kwargs:
            paddle_rect = kwargs['paddle_rect']
            # 패들 오른쪽 상단에 작은 블루투스 인디케이터
            indicator_x = paddle_rect.right + 5
            indicator_y = paddle_rect.centery
            
            # 블루투스 심볼 그리기 (간단한 B 모양)
            pygame.draw.circle(screen, (100, 150, 255), (indicator_x, indicator_y), 8)
            font = pygame.font.Font(None, 12)
            b_text = font.render("B", True, (255, 255, 255))
            b_rect = b_text.get_rect(center=(indicator_x, indicator_y))
            screen.blit(b_text, b_rect)
    
    def get_gauge_charge_multiplier(self):
        """게이지 충전 배율 반환"""
        if self.active:
            return 1.0 + self.gauge_charge_bonus  # 1.25배
        return 1.0
    
    def calculate_gauge_charge(self, base_charge):
        """실제 게이지 충전량 계산"""
        if self.active:
            result = int(base_charge * (1.0 + self.gauge_charge_bonus))
            print(f" BluetoothRing.calculate_gauge_charge: {base_charge} → {result} (+{self.gauge_charge_bonus*100:.0f}%)")
            return result
        return base_charge

# 싱글톤 인스턴스
bluetooth_ring_instance = None

def get_bluetooth_ring_instance():
    global bluetooth_ring_instance
    if bluetooth_ring_instance is None:
        bluetooth_ring_instance = BluetoothRing()
    return bluetooth_ring_instance

def activate_bluetooth_ring(game_state, current_stage):
    """블루투스링 활성화"""
    ring = get_bluetooth_ring_instance()
    ring.activate(game_state, current_stage)
    return ring.get_gauge_charge_multiplier()

def deactivate_bluetooth_ring():
    """블루투스링 비활성화"""
    ring = get_bluetooth_ring_instance()
    ring.deactivate()

def update_bluetooth_ring(current_stage):
    """블루투스링 업데이트"""
    ring = get_bluetooth_ring_instance()
    ring.update(current_stage)

def draw_bluetooth_ring_effects(screen, **kwargs):
    """블루투스링 효과 그리기"""
    ring = get_bluetooth_ring_instance()
    ring.draw_effects(screen, **kwargs)

def get_bluetooth_ring_gauge_multiplier():
    """현재 블루투스링의 게이지 충전 배율 반환"""
    ring = get_bluetooth_ring_instance()
    return ring.get_gauge_charge_multiplier()

def calculate_bluetooth_ring_gauge_charge(base_charge):
    """블루투스링이 적용된 게이지 충전량 계산"""
    ring = get_bluetooth_ring_instance()
    return ring.calculate_gauge_charge(base_charge)

def is_bluetooth_ring_active():
    """블루투스링 활성 상태 확인"""
    ring = get_bluetooth_ring_instance()
    return ring.active