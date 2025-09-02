"""
서바이벌 모드 - 무한으로 계속되는 도전!
새로운 게임 모드 예시
"""

import pygame
import random
import math

class SurvivalMode:
    """서바이벌 모드 클래스"""
    
    def __init__(self):
        self.screen = None
        self.clock = None
        self.running = False
        self.wave = 1
        self.score = 0
        self.player_lives = 3
        
    def init(self):
        """서바이벌 모드 초기화"""
        pygame.init()
        self.screen = pygame.display.set_mode((600, 750))
        pygame.display.set_caption("BossPong - Survival Mode")
        self.clock = pygame.time.Clock()
        self.font = pygame.font.Font("NanumSquareR.ttf", 30)
        
    def run(self):
        """서바이벌 모드 메인 루프"""
        self.init()
        self.running = True
        
        while self.running:
            # 이벤트 처리
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.running = False
                elif event.type == pygame.KEYDOWN:
                    if event.key == pygame.K_ESCAPE:
                        self.running = False
            
            # 화면 그리기
            self.screen.fill((30, 30, 50))
            
            # UI 표시
            wave_text = self.font.render(f"Wave: {self.wave}", True, (255, 255, 255))
            score_text = self.font.render(f"Score: {self.score}", True, (255, 255, 255))
            lives_text = self.font.render(f"Lives: {self.player_lives}", True, (255, 100, 100))
            
            self.screen.blit(wave_text, (10, 10))
            self.screen.blit(score_text, (10, 50))
            self.screen.blit(lives_text, (10, 90))
            
            # 중앙에 안내 텍스트
            info = self.font.render("서바이벌 모드 - 개발 중!", True, (100, 200, 255))
            info_rect = info.get_rect(center=(300, 375))
            self.screen.blit(info, info_rect)
            
            small_font = pygame.font.Font("NanumSquareR.ttf", 20)
            esc_text = small_font.render("ESC: 메인 메뉴로", True, (150, 150, 150))
            esc_rect = esc_text.get_rect(center=(300, 450))
            self.screen.blit(esc_text, esc_rect)
            
            pygame.display.flip()
            self.clock.tick(60)
        
        pygame.quit()

def start_survival():
    """서바이벌 모드 시작 함수"""
    mode = SurvivalMode()
    mode.run()

# 나중에 bosspong.py의 기능들을 import해서 사용 가능
# from bosspong import BALL, PLAYER, play_paddle_sound
# 하지만 bosspong.py 자체는 수정하지 않음!