"""
다우징팬들럼 아이템 효과 모듈
플레이어 패들 근처의 아이템을 자석처럼 끌어당기는 효과
"""

import math
import pygame

class DowsingPendulumEffect:
    """다우징팬들럼 효과 클래스"""
    
    def __init__(self):
        self.enabled = False
        self.attraction_range = 180  # 끌어당기는 범위 (픽셀)
        self.attraction_force = 3.5   # 끌어당기는 힘
        self.min_distance = 30       # 최소 거리 (너무 가까우면 끌어당기지 않음)
        
    def activate(self):
        """다우징팬들럼 효과 활성화"""
        self.enabled = True
        
    def deactivate(self):
        """다우징팬들럼 효과 비활성화"""
        self.enabled = False
        
    def apply_attraction(self, item_list, player_rect):
        """
        아이템들을 플레이어 패들 쪽으로 끌어당기는 효과 적용
        
        Args:
            item_list: 현재 맵에 있는 아이템 리스트
            player_rect: 플레이어 패들의 pygame.Rect 객체
        """
        if not self.enabled:
            return
            
        player_center_x = player_rect.centerx
        player_center_y = player_rect.centery
        
        # 디버그: 첫 실행 시 상태 출력
        if len(item_list) > 0 and not hasattr(self, '_debug_printed'):
            print(f"[DEBUG]    ...")
            print(f"[DEBUG]  : {len(item_list)}")
            print(f"[DEBUG]  : ({player_center_x}, {player_center_y})")
            self._debug_printed = True
        
        for item in item_list:
            # 아이템과 플레이어 사이의 거리 계산
            dx = player_center_x - item["x"]
            dy = player_center_y - item["y"]
            distance = math.sqrt(dx**2 + dy**2)
            
            # 범위 내에 있고 최소 거리보다 멀 때만 끌어당김
            if self.min_distance < distance <= self.attraction_range:
                # 거리가 가까울수록 강한 힘으로 끌어당김
                force_multiplier = 1 - (distance / self.attraction_range)
                force = self.attraction_force * force_multiplier
                
                # 방향 벡터 정규화
                if distance > 0:
                    dx_norm = dx / distance
                    dy_norm = dy / distance
                    
                    # 아이템 속도에 끌어당기는 힘 추가
                    item["vel"][0] += dx_norm * force
                    item["vel"][1] += dy_norm * force
                    
                    # 최대 속도 제한 (너무 빠르게 움직이지 않도록)
                    max_speed = 8
                    current_speed = math.sqrt(item["vel"][0]**2 + item["vel"][1]**2)
                    if current_speed > max_speed:
                        item["vel"][0] = (item["vel"][0] / current_speed) * max_speed
                        item["vel"][1] = (item["vel"][1] / current_speed) * max_speed
    
    def draw_attraction_range(self, screen, player_rect, alpha=30):
        """
        끌어당기는 범위를 시각적으로 표시 (디버그/시각 효과용)
        
        Args:
            screen: pygame 화면 객체
            player_rect: 플레이어 패들의 pygame.Rect 객체
            alpha: 투명도 (0-255)
        """
        if not self.enabled:
            return
            
        # 반투명 원 그리기를 위한 서피스 생성
        range_surface = pygame.Surface((self.attraction_range * 2, self.attraction_range * 2), pygame.SRCALPHA)
        
        # 자력장 효과 - 여러 개의 동심원
        for i in range(3):
            radius = self.attraction_range - (i * 20)
            alpha_level = alpha - (i * 10)
            if radius > 0 and alpha_level > 0:
                pygame.draw.circle(
                    range_surface,
                    (100, 150, 255, alpha_level),  # 파란색 계열
                    (self.attraction_range, self.attraction_range),
                    radius,
                    2
                )
        
        # 플레이어 중심에 범위 표시
        screen.blit(
            range_surface,
            (player_rect.centerx - self.attraction_range, 
             player_rect.centery - self.attraction_range)
        )
        
    def get_status_text(self):
        """상태 표시용 텍스트 반환"""
        if self.enabled:
            return "다우징팬들럼 활성화 (자력 범위: {}px)".format(self.attraction_range)
        return None


# 전역 인스턴스 생성 (싱글톤 패턴)
dowsing_pendulum_effect = DowsingPendulumEffect()