"""
DialogSystem - 다이얼로그 시스템
게임 내 대화창, 알림, 확인창 관리
"""

import pygame
import math
from typing import Optional, Callable, List, Tuple
from core.events import EventType, emit_event


class DialogSystem:
    """다이얼로그 시스템 관리자"""
    
    def __init__(self, screen: pygame.Surface, width: int = 600, height: int = 750):
        self.screen = screen
        self.width = width
        self.height = height
        
        # 폰트 초기화
        self.init_fonts()
        
        # 다이얼로그 상태
        self.active_dialog = None
        self.dialog_queue = []
        self.animation_timer = 0
        self.fade_alpha = 0
        
        # 색상 설정
        self.colors = {
            'background': (20, 20, 30),
            'border': (100, 150, 255),
            'text': (255, 255, 255),
            'button': (0, 255, 200),
            'button_hover': (255, 200, 50),
            'overlay': (0, 0, 0, 180)
        }
        
    def init_fonts(self):
        """폰트 초기화"""
        try:
            self.font_title = pygame.font.Font("NanumSquareEB.ttf", 36)
            self.font_text = pygame.font.Font("NanumSquareR.ttf", 24)
            self.font_button = pygame.font.Font("NanumSquareB.ttf", 28)
        except:
            self.font_title = pygame.font.Font(None, 36)
            self.font_text = pygame.font.Font(None, 24)
            self.font_button = pygame.font.Font(None, 28)
            
    def show_dialog(self, title: str, message: str, 
                   buttons: Optional[List[Tuple[str, Callable]]] = None,
                   dialog_type: str = "info"):
        """다이얼로그 표시
        
        Args:
            title: 제목
            message: 메시지
            buttons: 버튼 리스트 [(텍스트, 콜백), ...]
            dialog_type: 다이얼로그 타입 (info, warning, error, confirm)
        """
        dialog = {
            'title': title,
            'message': message,
            'buttons': buttons or [("확인", lambda: self.close_dialog())],
            'type': dialog_type,
            'selected_button': 0,
            'animation_state': 'opening'
        }
        
        if self.active_dialog:
            self.dialog_queue.append(dialog)
        else:
            self.active_dialog = dialog
            self.fade_alpha = 0
            emit_event(EventType.DIALOG_SHOWN, {'type': dialog_type, 'title': title})
            
    def show_winner_text(self, winner: str):
        """승자 텍스트 표시"""
        message = f"{winner} 승리!"
        self.show_dialog("라운드 종료", message, 
                        [("계속", lambda: self.close_dialog())],
                        "info")
                        
    def show_victory_screen(self, stage: int, medal_earned: int):
        """승리 화면 표시"""
        message = f"스테이지 {stage} 클리어!\n획득 메달: {medal_earned}"
        self.show_dialog("승리!", message,
                        [("다음 스테이지", lambda: self.next_stage()),
                         ("메인 메뉴", lambda: self.main_menu())],
                        "info")
                        
    def show_defeat_screen(self):
        """패배 화면 표시"""
        message = "아쉽네요! 다시 도전하시겠습니까?"
        self.show_dialog("패배", message,
                        [("재시도", lambda: self.retry()),
                         ("메인 메뉴", lambda: self.main_menu())],
                        "error")
                        
    def show_pause_menu(self):
        """일시정지 메뉴 표시"""
        message = "게임이 일시정지되었습니다"
        self.show_dialog("일시정지", message,
                        [("계속하기", lambda: self.resume()),
                         ("재시작", lambda: self.restart()),
                         ("메인 메뉴", lambda: self.main_menu())],
                        "info")
                        
    def draw(self):
        """다이얼로그 그리기"""
        if not self.active_dialog:
            return
            
        dialog = self.active_dialog
        
        # 페이드 애니메이션
        if dialog['animation_state'] == 'opening':
            self.fade_alpha = min(255, self.fade_alpha + 15)
            if self.fade_alpha >= 255:
                dialog['animation_state'] = 'open'
        elif dialog['animation_state'] == 'closing':
            self.fade_alpha = max(0, self.fade_alpha - 15)
            if self.fade_alpha <= 0:
                self.close_dialog_complete()
                return
                
        # 오버레이
        overlay = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, min(180, self.fade_alpha)))
        self.screen.blit(overlay, (0, 0))
        
        # 다이얼로그 박스
        box_width = 500
        box_height = 300
        box_x = (self.width - box_width) // 2
        box_y = (self.height - box_height) // 2
        
        # 애니메이션 효과
        self.animation_timer += 0.1
        scale = 1.0 + 0.02 * math.sin(self.animation_timer)
        
        # 박스 그리기
        box_surface = pygame.Surface((box_width, box_height), pygame.SRCALPHA)
        
        # 배경
        bg_alpha = int(self.fade_alpha * 0.9)
        pygame.draw.rect(box_surface, (*self.colors['background'], bg_alpha),
                        (0, 0, box_width, box_height), border_radius=20)
                        
        # 테두리
        border_color = self.get_border_color(dialog['type'])
        pygame.draw.rect(box_surface, (*border_color, self.fade_alpha),
                        (0, 0, box_width, box_height), 3, border_radius=20)
                        
        # 제목
        title_surface = self.font_title.render(dialog['title'], True, self.colors['text'])
        title_rect = title_surface.get_rect(centerx=box_width // 2, y=30)
        box_surface.blit(title_surface, title_rect)
        
        # 구분선
        pygame.draw.line(box_surface, (*self.colors['border'], self.fade_alpha // 2),
                        (50, 80), (box_width - 50, 80), 2)
                        
        # 메시지
        lines = dialog['message'].split('\n')
        y = 120
        for line in lines:
            text_surface = self.font_text.render(line, True, self.colors['text'])
            text_rect = text_surface.get_rect(centerx=box_width // 2, y=y)
            box_surface.blit(text_surface, text_rect)
            y += 35
            
        # 버튼들
        button_y = box_height - 80
        button_width = 120
        button_height = 40
        button_spacing = 20
        
        total_width = len(dialog['buttons']) * button_width + (len(dialog['buttons']) - 1) * button_spacing
        start_x = (box_width - total_width) // 2
        
        for i, (text, callback) in enumerate(dialog['buttons']):
            x = start_x + i * (button_width + button_spacing)
            
            # 선택된 버튼 강조
            if i == dialog['selected_button']:
                color = self.colors['button_hover']
                button_scale = scale
            else:
                color = self.colors['button']
                button_scale = 1.0
                
            # 버튼 그리기
            button_rect = pygame.Rect(x, button_y, button_width, button_height)
            
            # 버튼 배경
            pygame.draw.rect(box_surface, (*color, self.fade_alpha // 2),
                           button_rect, border_radius=10)
            pygame.draw.rect(box_surface, (*color, self.fade_alpha),
                           button_rect, 2, border_radius=10)
                           
            # 버튼 텍스트
            button_text = self.font_button.render(text, True, color)
            text_rect = button_text.get_rect(center=button_rect.center)
            box_surface.blit(button_text, text_rect)
            
        # 스케일 적용
        if scale != 1.0:
            scaled_width = int(box_width * scale)
            scaled_height = int(box_height * scale)
            box_surface = pygame.transform.scale(box_surface, (scaled_width, scaled_height))
            box_x = (self.width - scaled_width) // 2
            box_y = (self.height - scaled_height) // 2
            
        self.screen.blit(box_surface, (box_x, box_y))
        
    def get_border_color(self, dialog_type: str) -> Tuple[int, int, int]:
        """다이얼로그 타입에 따른 테두리 색상"""
        colors = {
            'info': (100, 150, 255),
            'warning': (255, 200, 50),
            'error': (255, 80, 80),
            'confirm': (0, 255, 200)
        }
        return colors.get(dialog_type, (100, 150, 255))
        
    def handle_input(self, event: pygame.event.Event) -> bool:
        """입력 처리"""
        if not self.active_dialog:
            return False
            
        dialog = self.active_dialog
        
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_LEFT:
                dialog['selected_button'] = max(0, dialog['selected_button'] - 1)
                return True
            elif event.key == pygame.K_RIGHT:
                dialog['selected_button'] = min(len(dialog['buttons']) - 1, 
                                              dialog['selected_button'] + 1)
                return True
            elif event.key in [pygame.K_RETURN, pygame.K_SPACE]:
                self.select_button(dialog['selected_button'])
                return True
            elif event.key == pygame.K_ESCAPE:
                if len(dialog['buttons']) > 1:
                    self.select_button(len(dialog['buttons']) - 1)  # 마지막 버튼 (보통 취소)
                else:
                    self.close_dialog()
                return True
                
        return False
        
    def select_button(self, index: int):
        """버튼 선택"""
        if self.active_dialog and 0 <= index < len(self.active_dialog['buttons']):
            _, callback = self.active_dialog['buttons'][index]
            if callback:
                callback()
                
    def close_dialog(self):
        """다이얼로그 닫기 시작"""
        if self.active_dialog:
            self.active_dialog['animation_state'] = 'closing'
            
    def close_dialog_complete(self):
        """다이얼로그 완전히 닫기"""
        self.active_dialog = None
        
        # 큐에 대기 중인 다이얼로그가 있으면 표시
        if self.dialog_queue:
            next_dialog = self.dialog_queue.pop(0)
            self.show_dialog(next_dialog['title'], next_dialog['message'],
                           next_dialog['buttons'], next_dialog['type'])
                           
    # 액션 메서드들
    def next_stage(self):
        """다음 스테이지"""
        self.close_dialog()
        emit_event(EventType.ROUND_START, {'next_stage': True})
        
    def retry(self):
        """재시도"""
        self.close_dialog()
        emit_event(EventType.ROUND_START, {'retry': True})
        
    def main_menu(self):
        """메인 메뉴"""
        self.close_dialog()
        emit_event(EventType.MENU_OPENED, {'menu_type': 'main'})
        
    def resume(self):
        """게임 재개"""
        self.close_dialog()
        emit_event(EventType.GAME_RESUME, {})
        
    def restart(self):
        """게임 재시작"""
        self.close_dialog()
        emit_event(EventType.GAME_START, {'restart': True})