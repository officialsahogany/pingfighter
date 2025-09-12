"""무릎보호대 - 하프대쉬로 공을 맞출 때 게이지 50% 충전"""

import pygame

class KneePads:
    def __init__(self):
        self.active = False
        self.obtained = False
        self.flash_timer = 0  # 빛나는 이펙트 타이머
        self.flash_pos = None  # 이펙트 위치
        
    def activate(self):
        """무릎보호대 획득 시 활성화"""
        self.active = True
        self.obtained = True
        print("무릎보호대 활성화 - 하프대쉬 공 타격 시 게이지 50% 충전")
    
    def deactivate(self):
        """무릎보호대 비활성화 (게임오버 시)"""
        self.active = False
        self.obtained = False
        self.flash_timer = 0
        self.flash_pos = None
        print("무릎보호대 비활성화")
    
    def on_half_dash_hit(self, ball_pos):
        """하프대쉬로 공을 맞췄을 때 호출"""
        if self.active:
            # 빛나는 이펙트 시작
            self.flash_timer = 15  # 15프레임 동안 이펙트
            self.flash_pos = ball_pos
            return True  # 게이지 충전 신호
        return False
    
    def update(self):
        """매 프레임 업데이트"""
        if self.flash_timer > 0:
            self.flash_timer -= 1
    
    def draw_effect(self, screen):
        """빛나는 이펙트 그리기"""
        if self.flash_timer > 0 and self.flash_pos:
            # 노란색 빛나는 효과
            alpha = int(255 * (self.flash_timer / 15))
            
            # 원형 플래시 효과
            flash_surface = pygame.Surface((100, 100), pygame.SRCALPHA)
            for i in range(3):
                radius = 20 + i * 10
                color = (255, 255, 0, alpha // (i + 1))
                pygame.draw.circle(flash_surface, color, (50, 50), radius)
            
            screen.blit(flash_surface, 
                       (self.flash_pos[0] - 50, self.flash_pos[1] - 50))
            
            # 별 모양 파티클
            if self.flash_timer > 10:
                for angle in range(0, 360, 45):
                    import math
                    x = self.flash_pos[0] + math.cos(math.radians(angle)) * 30
                    y = self.flash_pos[1] + math.sin(math.radians(angle)) * 30
                    pygame.draw.circle(screen, (255, 255, 100, alpha), (int(x), int(y)), 3)

# 싱글톤 인스턴스
knee_pads_instance = None

def get_knee_pads_instance():
    global knee_pads_instance
    if knee_pads_instance is None:
        knee_pads_instance = KneePads()
    return knee_pads_instance