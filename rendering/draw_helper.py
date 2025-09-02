"""
DrawHelper - Simple wrapper for pygame drawing
"""

import pygame

class DrawHelper:
    """pygame 그리기 함수 래퍼"""
    
    def __init__(self, screen):
        self.screen = screen
        
    def circle(self, color, pos, radius, width=0):
        """원 그리기"""
        pygame.draw.circle(self.screen, color, pos, radius, width)
        
    def rect(self, color, rect, width=0):
        """사각형 그리기"""
        pygame.draw.rect(self.screen, color, rect, width)
        
    def line(self, color, start_pos, end_pos, width=1):
        """선 그리기"""
        pygame.draw.line(self.screen, color, start_pos, end_pos, width)
        
    def polygon(self, color, points, width=0):
        """다각형 그리기"""
        pygame.draw.polygon(self.screen, color, points, width)
        
    def ellipse(self, color, rect, width=0):
        """타원 그리기"""
        pygame.draw.ellipse(self.screen, color, rect, width)