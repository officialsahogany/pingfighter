#!/usr/bin/env python3
"""
패들로만 별 수집 가능 테스트
공으로는 별을 수집할 수 없고, 오직 패들로만 수집 가능한지 확인
"""

import pygame
import sys
from trade_point_system import TradePointSystem

# Pygame 초기화
pygame.init()

# 화면 설정
SCREEN_WIDTH = 600
SCREEN_HEIGHT = 750
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Paddle-Only Star Collection Test")

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
BLUE = (100, 100, 255)
RED = (255, 100, 100)

# 트레이드 포인트 시스템 초기화
trade_system = TradePointSystem(screen)

# 테스트용 별 생성
print("⭐ 테스트 별 생성 중...")
for i in range(5):
    x = 100 + i * 100
    y = 300
    trade_system.spawn_star(x, y, "test")
    print(f"  └─ 별 #{i+1} 생성: ({x}, {y})")

# 공 클래스
class Ball:
    def __init__(self):
        self.x = SCREEN_WIDTH // 2
        self.y = 100
        self.radius = 10
        self.rect = pygame.Rect(self.x - self.radius, self.y - self.radius, 
                                self.radius * 2, self.radius * 2)
    
    def update(self):
        # 마우스 위치를 따라다니는 공 (테스트용)
        mouse_x, mouse_y = pygame.mouse.get_pos()
        if pygame.mouse.get_pressed()[2]:  # 우클릭시 공 이동
            self.x = mouse_x
            self.y = mouse_y
        
        self.rect.x = self.x - self.radius
        self.rect.y = self.y - self.radius
    
    def draw(self, surface):
        pygame.draw.circle(surface, RED, (self.x, self.y), self.radius)
        # 충돌 영역 표시
        pygame.draw.rect(surface, (255, 0, 0, 50), self.rect, 1)

# 패들 클래스
class Paddle:
    def __init__(self):
        self.width = 100
        self.height = 20
        self.x = SCREEN_WIDTH // 2 - self.width // 2
        self.y = SCREEN_HEIGHT - 50
        self.rect = pygame.Rect(self.x, self.y, self.width, self.height)
    
    def update(self):
        # 마우스 위치를 따라다니는 패들 (좌클릭시)
        if pygame.mouse.get_pressed()[0]:  # 좌클릭시 패들 이동
            mouse_x, _ = pygame.mouse.get_pos()
            self.x = mouse_x - self.width // 2
            
            if self.x < 0:
                self.x = 0
            if self.x + self.width > SCREEN_WIDTH:
                self.x = SCREEN_WIDTH - self.width
            
            self.rect.x = self.x
    
    def draw(self, surface):
        pygame.draw.rect(surface, BLUE, self.rect)

# 메인 루프
def main():
    clock = pygame.time.Clock()
    running = True
    ball = Ball()
    paddle = Paddle()
    
    # 폰트
    try:
        font = pygame.font.Font("NeoDGM.ttf", 24)
        small_font = pygame.font.Font("NeoDGM.ttf", 16)
    except:
        font = pygame.font.Font(None, 24)
        small_font = pygame.font.Font(None, 16)
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE:
                    # 스페이스바로 별 추가 생성
                    import random
                    x = random.randint(50, SCREEN_WIDTH - 50)
                    y = random.randint(50, 400)
                    trade_system.spawn_star(x, y, "manual")
                    print(f"⭐ 수동 별 생성: ({x}, {y})")
                elif event.key == pygame.K_r:
                    # R키로 리셋
                    trade_system.reset()
                    print("🔄 시스템 리셋!")
        
        # 업데이트
        ball.update()
        paddle.update()
        
        # 트레이드 포인트 시스템 업데이트 (공과 패들 둘 다 전달)
        collected = trade_system.update(ball.rect, paddle.rect)
        if collected > 0:
            print(f"⭐ {collected}개 별 수집! 총: {trade_system.get_collected_count()}")
        
        # 화면 그리기
        screen.fill(BLACK)
        
        # 격자 배경
        for x in range(0, SCREEN_WIDTH, 50):
            pygame.draw.line(screen, (30, 30, 30), (x, 0), (x, SCREEN_HEIGHT), 1)
        for y in range(0, SCREEN_HEIGHT, 50):
            pygame.draw.line(screen, (30, 30, 30), (0, y), (SCREEN_WIDTH, y), 1)
        
        # 트레이드 포인트 시스템 그리기
        trade_system.draw()
        
        # 공 그리기
        ball.draw(screen)
        
        # 패들 그리기
        paddle.draw(screen)
        
        # UI 정보
        star_count = trade_system.get_active_star_count()
        collected_count = trade_system.get_collected_count()
        
        info_text = font.render(f"Stars: {star_count} | Collected: {collected_count}", True, WHITE)
        screen.blit(info_text, (10, 10))
        
        instruction1 = small_font.render("LEFT CLICK: Move Paddle (can collect)", True, (100, 255, 100))
        instruction2 = small_font.render("RIGHT CLICK: Move Ball (CANNOT collect)", True, (255, 100, 100))
        instruction3 = small_font.render("SPACE: Add Star | R: Reset", True, (150, 150, 150))
        
        screen.blit(instruction1, (10, SCREEN_HEIGHT - 70))
        screen.blit(instruction2, (10, SCREEN_HEIGHT - 50))
        screen.blit(instruction3, (10, SCREEN_HEIGHT - 30))
        
        # 화면 업데이트
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()