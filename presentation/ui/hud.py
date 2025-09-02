"""
HUD (Heads-Up Display) 시스템 모듈
- 인게임 점수 표시
- 체력바, 게이지바
- 대시 표시
- 아이템 슬롯
- 각종 인게임 정보 표시
"""

import pygame
import math
import random


class HUDSystem:
    """HUD 시스템 클래스"""
    
    def __init__(self, screen, width, height):
        self.screen = screen
        self.width = width
        self.height = height
        
        # 폰트 초기화
        try:
            self.font_large = pygame.font.Font("NanumSquareEB.ttf", 48)
            self.font_medium = pygame.font.Font("NanumSquareB.ttf", 36)
            self.font_small = pygame.font.Font("NanumSquareR.ttf", 24)
            self.font_tiny = pygame.font.Font("NanumSquareR.ttf", 18)
        except:
            self.font_large = pygame.font.Font(None, 48)
            self.font_medium = pygame.font.Font(None, 36)
            self.font_small = pygame.font.Font(None, 24)
            self.font_tiny = pygame.font.Font(None, 18)
        
        # 색상 정의
        self.WHITE = (255, 255, 255)
        self.BLACK = (0, 0, 0)
        self.RED = (255, 0, 0)
        self.GREEN = (0, 255, 0)
        self.BLUE = (0, 0, 255)
        self.YELLOW = (255, 255, 0)
        self.CYAN = (0, 255, 255)
        self.ORANGE = (255, 165, 0)
        self.PURPLE = (128, 0, 128)
        
    def draw_score(self, player_score, ai_score, y_position=50):
        """점수 표시"""
        # 플레이어 점수
        player_text = self.font_large.render(str(player_score), True, self.WHITE)
        player_rect = player_text.get_rect(center=(self.width // 4, y_position))
        
        # AI 점수
        ai_text = self.font_large.render(str(ai_score), True, self.WHITE)
        ai_rect = ai_text.get_rect(center=(3 * self.width // 4, y_position))
        
        # 그림자 효과
        shadow_offset = 3
        shadow_color = (50, 50, 50)
        
        player_shadow = self.font_large.render(str(player_score), True, shadow_color)
        ai_shadow = self.font_large.render(str(ai_score), True, shadow_color)
        
        self.screen.blit(player_shadow, (player_rect.x + shadow_offset, player_rect.y + shadow_offset))
        self.screen.blit(ai_shadow, (ai_rect.x + shadow_offset, ai_rect.y + shadow_offset))
        
        # 실제 점수
        self.screen.blit(player_text, player_rect)
        self.screen.blit(ai_text, ai_rect)
        
        # VS 텍스트
        vs_text = self.font_medium.render("VS", True, self.YELLOW)
        vs_rect = vs_text.get_rect(center=(self.width // 2, y_position))
        self.screen.blit(vs_text, vs_rect)
    
    def draw_boss_health_bar(self, current_hp, max_hp, boss_name="BOSS", y_position=100):
        """보스 체력바 표시"""
        if max_hp <= 0:
            return
            
        # 체력바 크기 및 위치
        bar_width = 400
        bar_height = 30
        bar_x = (self.width - bar_width) // 2
        bar_y = y_position
        
        # 배경 (어두운 회색)
        bg_rect = pygame.Rect(bar_x - 2, bar_y - 2, bar_width + 4, bar_height + 4)
        pygame.draw.rect(self.screen, (40, 40, 40), bg_rect)
        pygame.draw.rect(self.screen, self.WHITE, bg_rect, 2)
        
        # 체력 비율 계산
        hp_ratio = max(0, min(1, current_hp / max_hp))
        
        # 체력바 색상 (체력에 따라 변경)
        if hp_ratio > 0.6:
            bar_color = self.GREEN
        elif hp_ratio > 0.3:
            bar_color = self.YELLOW
        else:
            bar_color = self.RED
        
        # 체력바 그리기
        if hp_ratio > 0:
            hp_rect = pygame.Rect(bar_x, bar_y, int(bar_width * hp_ratio), bar_height)
            pygame.draw.rect(self.screen, bar_color, hp_rect)
            
            # 체력바 광택 효과
            gloss_rect = pygame.Rect(bar_x, bar_y, int(bar_width * hp_ratio), bar_height // 3)
            gloss_color = tuple(min(255, c + 50) for c in bar_color)
            pygame.draw.rect(self.screen, gloss_color, gloss_rect)
        
        # 보스 이름
        name_text = self.font_small.render(boss_name, True, self.WHITE)
        name_rect = name_text.get_rect(center=(self.width // 2, bar_y - 25))
        self.screen.blit(name_text, name_rect)
        
        # 체력 수치 표시
        hp_text = f"{int(current_hp)} / {int(max_hp)}"
        hp_surface = self.font_tiny.render(hp_text, True, self.WHITE)
        hp_rect = hp_surface.get_rect(center=(self.width // 2, bar_y + bar_height // 2))
        self.screen.blit(hp_surface, hp_rect)
    
    def draw_player_gauge(self, gauge_value, max_gauge=100, y_position=None):
        """플레이어 게이지바 표시"""
        if y_position is None:
            y_position = self.height - 100
        
        # 게이지바 크기 및 위치
        bar_width = 300
        bar_height = 20
        bar_x = (self.width - bar_width) // 2
        bar_y = y_position
        
        # 배경
        bg_rect = pygame.Rect(bar_x - 2, bar_y - 2, bar_width + 4, bar_height + 4)
        pygame.draw.rect(self.screen, (30, 30, 30), bg_rect)
        pygame.draw.rect(self.screen, self.CYAN, bg_rect, 1)
        
        # 게이지 비율
        gauge_ratio = max(0, min(1, gauge_value / max_gauge))
        
        # 게이지 색상 (충전 정도에 따라)
        if gauge_ratio >= 1.0:
            gauge_color = (255, 215, 0)  # 골드 (MAX)
            # 반짝임 효과
            pulse = abs(math.sin(pygame.time.get_ticks() * 0.005))
            gauge_color = tuple(int(c * (0.7 + 0.3 * pulse)) for c in gauge_color)
        elif gauge_ratio >= 0.8:
            gauge_color = self.YELLOW
        elif gauge_ratio >= 0.5:
            gauge_color = self.CYAN
        else:
            gauge_color = (100, 150, 200)
        
        # 게이지 그리기
        if gauge_ratio > 0:
            gauge_rect = pygame.Rect(bar_x, bar_y, int(bar_width * gauge_ratio), bar_height)
            pygame.draw.rect(self.screen, gauge_color, gauge_rect)
            
            # 세그먼트 표시 (25% 단위)
            for i in range(1, 4):
                segment_x = bar_x + int(bar_width * (i * 0.25))
                pygame.draw.line(self.screen, (50, 50, 50), 
                               (segment_x, bar_y), (segment_x, bar_y + bar_height), 2)
        
        # 게이지 라벨
        gauge_text = "POWER"
        if gauge_ratio >= 1.0:
            gauge_text = "MAX POWER!"
        
        text_surface = self.font_tiny.render(gauge_text, True, self.WHITE)
        text_rect = text_surface.get_rect(center=(self.width // 2, bar_y - 15))
        self.screen.blit(text_surface, text_rect)
        
        # 게이지 수치
        gauge_percent = f"{int(gauge_ratio * 100)}%"
        percent_surface = self.font_tiny.render(gauge_percent, True, self.WHITE)
        percent_rect = percent_surface.get_rect(center=(self.width // 2, bar_y + bar_height // 2))
        self.screen.blit(percent_surface, percent_rect)
    
    def draw_dash_indicator(self, dash_count, max_dashes=2, cooldown_ratio=0, x_position=50, y_position=None):
        """대시 표시기"""
        if y_position is None:
            y_position = self.height - 150
        
        # 대시 아이콘 크기
        icon_size = 30
        spacing = 10
        
        for i in range(max_dashes):
            x = x_position + i * (icon_size + spacing)
            y = y_position
            
            # 아이콘 배경
            icon_rect = pygame.Rect(x, y, icon_size, icon_size)
            
            if i < dash_count:
                # 사용 가능한 대시
                pygame.draw.rect(self.screen, self.CYAN, icon_rect)
                pygame.draw.rect(self.screen, self.WHITE, icon_rect, 2)
                
                # 대시 화살표 심볼
                arrow_points = [
                    (x + 5, y + icon_size // 2),
                    (x + icon_size - 10, y + 8),
                    (x + icon_size - 10, y + 12),
                    (x + icon_size - 5, y + icon_size // 2),
                    (x + icon_size - 10, y + icon_size - 12),
                    (x + icon_size - 10, y + icon_size - 8),
                    (x + 5, y + icon_size // 2)
                ]
                pygame.draw.polygon(self.screen, self.WHITE, arrow_points)
            else:
                # 쿨다운 중
                pygame.draw.rect(self.screen, (50, 50, 50), icon_rect)
                pygame.draw.rect(self.screen, (100, 100, 100), icon_rect, 1)
                
                # 쿨다운 진행 표시
                if i == dash_count and cooldown_ratio > 0:
                    cooldown_height = int(icon_size * (1 - cooldown_ratio))
                    cooldown_rect = pygame.Rect(x, y + cooldown_height, icon_size, icon_size - cooldown_height)
                    pygame.draw.rect(self.screen, (100, 150, 200, 128), cooldown_rect)
        
        # 대시 라벨
        dash_text = "DASH"
        text_surface = self.font_tiny.render(dash_text, True, self.WHITE)
        text_rect = text_surface.get_rect(x=x_position, y=y_position - 20)
        self.screen.blit(text_surface, text_rect)
    
    def draw_item_slots(self, active_items, passive_items, selected_index=0, x_position=None, y_position=50):
        """아이템 슬롯 표시"""
        if x_position is None:
            x_position = self.width - 200
        
        slot_size = 40
        spacing = 10
        
        # 액티브 아이템 슬롯
        active_label = self.font_tiny.render("ACTIVE", True, self.WHITE)
        self.screen.blit(active_label, (x_position, y_position - 20))
        
        for i, item in enumerate(active_items[:3]):  # 최대 3개
            x = x_position + i * (slot_size + spacing)
            y = y_position
            
            # 슬롯 배경
            slot_rect = pygame.Rect(x, y, slot_size, slot_size)
            
            if i == selected_index:
                # 선택된 슬롯
                pygame.draw.rect(self.screen, self.YELLOW, slot_rect, 3)
            else:
                pygame.draw.rect(self.screen, self.WHITE, slot_rect, 1)
            
            if item:
                # 아이템이 있는 경우 (실제로는 아이템 아이콘을 그려야 함)
                pygame.draw.rect(self.screen, (100, 100, 255), slot_rect.inflate(-10, -10))
                
                # 아이템 이름 첫 글자
                if isinstance(item, dict) and 'name' in item:
                    initial = item['name'][0].upper()
                else:
                    initial = "?"
                
                text = self.font_tiny.render(initial, True, self.WHITE)
                text_rect = text.get_rect(center=slot_rect.center)
                self.screen.blit(text, text_rect)
        
        # 패시브 아이템 슬롯
        if passive_items:
            passive_y = y_position + slot_size + 30
            passive_label = self.font_tiny.render("PASSIVE", True, self.WHITE)
            self.screen.blit(passive_label, (x_position, passive_y - 20))
            
            for i, item in enumerate(passive_items[:5]):  # 최대 5개
                x = x_position + (i % 3) * (slot_size + spacing)
                y = passive_y + (i // 3) * (slot_size + spacing)
                
                slot_rect = pygame.Rect(x, y, slot_size - 10, slot_size - 10)
                pygame.draw.rect(self.screen, (150, 150, 150), slot_rect, 1)
                
                if item:
                    pygame.draw.rect(self.screen, (100, 255, 100), slot_rect.inflate(-5, -5))
    
    def draw_stage_info(self, stage_number, stage_name="", time_elapsed=0):
        """스테이지 정보 표시"""
        # 스테이지 번호
        stage_text = f"STAGE {stage_number}"
        if stage_name:
            stage_text += f" - {stage_name}"
        
        stage_surface = self.font_medium.render(stage_text, True, self.YELLOW)
        stage_rect = stage_surface.get_rect(center=(self.width // 2, 30))
        
        # 배경 패널
        panel_rect = stage_rect.inflate(40, 20)
        pygame.draw.rect(self.screen, (0, 0, 0, 128), panel_rect)
        pygame.draw.rect(self.screen, self.YELLOW, panel_rect, 2)
        
        self.screen.blit(stage_surface, stage_rect)
        
        # 경과 시간
        if time_elapsed > 0:
            minutes = int(time_elapsed // 60)
            seconds = int(time_elapsed % 60)
            time_text = f"{minutes:02d}:{seconds:02d}"
            time_surface = self.font_tiny.render(time_text, True, self.WHITE)
            time_rect = time_surface.get_rect(center=(self.width // 2, 60))
            self.screen.blit(time_surface, time_rect)
    
    def draw_combo_counter(self, combo_count, x_position=50, y_position=200):
        """콤보 카운터 표시"""
        if combo_count <= 0:
            return
        
        # 콤보 크기 (콤보가 높을수록 크게)
        font_size = min(24 + combo_count * 2, 48)
        combo_font = pygame.font.Font(None, font_size)
        
        # 콤보 색상 (단계별)
        if combo_count >= 10:
            color = (255, 215, 0)  # 골드
        elif combo_count >= 5:
            color = self.YELLOW
        elif combo_count >= 3:
            color = self.CYAN
        else:
            color = self.WHITE
        
        # 콤보 텍스트
        combo_text = f"COMBO x{combo_count}"
        text_surface = combo_font.render(combo_text, True, color)
        text_rect = text_surface.get_rect(x=x_position, y=y_position)
        
        # 효과 (펄스)
        pulse = abs(math.sin(pygame.time.get_ticks() * 0.01))
        scale_factor = 1 + pulse * 0.1
        
        # 그림자
        shadow_surface = combo_font.render(combo_text, True, (50, 50, 50))
        self.screen.blit(shadow_surface, (text_rect.x + 2, text_rect.y + 2))
        
        # 실제 텍스트
        self.screen.blit(text_surface, text_rect)
        
        # 콤보 이펙트 파티클
        if combo_count >= 5:
            for _ in range(combo_count // 5):
                if pygame.time.get_ticks() % 10 == 0:
                    particle_x = text_rect.x + text_rect.width // 2 + random.randint(-20, 20)
                    particle_y = text_rect.y + text_rect.height // 2 + random.randint(-20, 20)
                    pygame.draw.circle(self.screen, color, (particle_x, particle_y), 2)


# 싱글톤 인스턴스
_hud_system = None

def init_hud_system(screen, width, height):
    """HUD 시스템 초기화"""
    global _hud_system
    _hud_system = HUDSystem(screen, width, height)
    return _hud_system

# 호환성을 위한 래퍼 함수들
def show_score(screen, player_score, ai_score, width=600, height=750):
    """점수 표시 (호환성 래퍼)"""
    global _hud_system
    if _hud_system is None:
        _hud_system = HUDSystem(screen, width, height)
    _hud_system.draw_score(player_score, ai_score)

def draw_boss_health_bar(screen, current_hp, max_hp, boss_name="BOSS", width=600, height=750):
    """보스 체력바 표시 (호환성 래퍼)"""
    global _hud_system
    if _hud_system is None:
        _hud_system = HUDSystem(screen, width, height)
    _hud_system.draw_boss_health_bar(current_hp, max_hp, boss_name)

def draw_player_gauge(screen, gauge_value, max_gauge=100, width=600, height=750):
    """플레이어 게이지 표시 (호환성 래퍼)"""
    global _hud_system
    if _hud_system is None:
        _hud_system = HUDSystem(screen, width, height)
    _hud_system.draw_player_gauge(gauge_value, max_gauge)