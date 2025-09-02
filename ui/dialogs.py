"""
대화창 및 결과 화면 모듈
- 승리 화면
- 결과 화면
- 승자 텍스트 표시
"""

import pygame
import math
import random


class DialogSystem:
    """대화창 시스템"""
    
    def __init__(self, screen, width, height):
        self.screen = screen
        self.width = width
        self.height = height
        
        # 폰트 초기화
        try:
            self.font_large = pygame.font.Font("NanumSquareEB.ttf", 72)
            self.font_medium = pygame.font.Font("NanumSquareB.ttf", 48)
            self.font_small = pygame.font.Font("NanumSquareR.ttf", 36)
            self.font_tiny = pygame.font.Font("NanumSquareR.ttf", 24)
        except:
            self.font_large = pygame.font.Font(None, 72)
            self.font_medium = pygame.font.Font(None, 48)
            self.font_small = pygame.font.Font(None, 36)
            self.font_tiny = pygame.font.Font(None, 24)
            
        # 색상 정의
        self.WHITE = (255, 255, 255)
        self.BLACK = (0, 0, 0)
        self.RED = (255, 0, 0)
        self.GREEN = (0, 255, 0)
        self.BLUE = (0, 0, 255)
        self.YELLOW = (255, 255, 0)
        self.CYAN = (0, 255, 255)
        self.MAGENTA = (255, 0, 255)
        
    def show_winner_text(self, winner_name):
        """임시 함수 - 나중에 구현"""
        pass
        
    def show_victory_screen(self, stage_cleared, reward):
        """임시 함수 - 나중에 구현"""
        pass
        
    def show_result(self, won):
        """임시 함수 - 나중에 구현"""
        pass


# 싱글톤 인스턴스
_dialog_system = None

def init_dialog_system(screen, width, height):
    """대화창 시스템 초기화"""
    global _dialog_system
    _dialog_system = DialogSystem(screen, width, height)
    return _dialog_system

# 호환성을 위한 래퍼 함수들
def show_winner_text(winner_name, screen=None, width=600, height=750):
    """승자 텍스트 표시 (호환성 래퍼)"""
    global _dialog_system
    if _dialog_system is None:
        _dialog_system = DialogSystem(screen, width, height)
    _dialog_system.show_winner_text(winner_name)

def show_victory_screen(stage_cleared, reward, screen=None, width=600, height=750):
    """승리 화면 표시 (호환성 래퍼)"""
    global _dialog_system
    if _dialog_system is None:
        _dialog_system = DialogSystem(screen, width, height)
    _dialog_system.show_victory_screen(stage_cleared, reward)

def show_result(won, screen=None, width=600, height=750):
    """결과 화면 표시 (호환성 래퍼)"""
    global _dialog_system
    if _dialog_system is None:
        _dialog_system = DialogSystem(screen, width, height)
    _dialog_system.show_result(won)