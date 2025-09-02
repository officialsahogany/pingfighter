"""
Test Stage 1 Balloon Event with Trade Point System Integration
스테이지1 특별 풍선(삼태극)과 트레이드 포인트 시스템 연동 테스트
"""

import pygame
import sys
import math
import random
from events.balloon_machine_event import BalloonMachineEvent
from trade_point_system import TradePointSystem

# Pygame 초기화
pygame.init()

# 화면 설정
SCREEN_WIDTH = 600
SCREEN_HEIGHT = 750
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Stage 1 - Balloon Star Integration Test")

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
BLUE = (100, 100, 255)
RED = (255, 100, 100)
YELLOW = (255, 255, 100)

# 게임 요소
class Ball:
    def __init__(self):
        self.x = SCREEN_WIDTH // 2
        self.y = SCREEN_HEIGHT // 2
        self.radius = 10
        self.vx = random.choice([-5, 5])
        self.vy = random.choice([-5, 5])
        self.rect = pygame.Rect(self.x - self.radius, self.y - self.radius, 
                                self.radius * 2, self.radius * 2)
    
    def update(self):
        self.x += self.vx
        self.y += self.vy
        
        # 벽 충돌
        if self.x - self.radius <= 0 or self.x + self.radius >= SCREEN_WIDTH:
            self.vx = -self.vx
        if self.y - self.radius <= 0 or self.y + self.radius >= SCREEN_HEIGHT:
            self.vy = -self.vy
        
        # Rect 업데이트
        self.rect.x = self.x - self.radius
        self.rect.y = self.y - self.radius
    
    def draw(self, surface):
        pygame.draw.circle(surface, WHITE, (int(self.x), int(self.y)), self.radius)

class Paddle:
    def __init__(self):
        self.width = 100
        self.height = 20
        self.x = SCREEN_WIDTH // 2 - self.width // 2
        self.y = SCREEN_HEIGHT - 50
        self.rect = pygame.Rect(self.x, self.y, self.width, self.height)
    
    def update(self):
        mouse_x, _ = pygame.mouse.get_pos()
        self.x = mouse_x - self.width // 2
        
        # 화면 경계 제한
        if self.x < 0:
            self.x = 0
        if self.x + self.width > SCREEN_WIDTH:
            self.x = SCREEN_WIDTH - self.width
        
        self.rect.x = self.x
    
    def draw(self, surface):
        pygame.draw.rect(surface, BLUE, self.rect)

# 메인 게임
def main():
    clock = pygame.time.Clock()
    running = True
    
    # 게임 객체 초기화
    ball = Ball()
    paddle = Paddle()
    
    # 이벤트 시스템 초기화
    balloon_event = BalloonMachineEvent(SCREEN_WIDTH, SCREEN_HEIGHT)
    trade_system = TradePointSystem(screen)
    
    # 플레이어 점수
    player_score = 0
    
    # 폰트
    try:
        font = pygame.font.Font("NeoDGM.ttf", 24)
        small_font = pygame.font.Font("NeoDGM.ttf", 16)
    except:
        font = pygame.font.Font(None, 24)
        small_font = pygame.font.Font(None, 16)
    
    # 수동 트리거 상태
    manual_trigger = False
    
    while running:
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE:
                    # 스페이스바로 수동 트리거
                    manual_trigger = True
                    print("🎈 Manual trigger activated!")
                elif event.key == pygame.K_r:
                    # R키로 리셋
                    balloon_event.reset()
                    trade_system.reset()
                    player_score = 0
                    manual_trigger = False
                    print("🔄 Reset!")
        
        # 업데이트
        ball.update()
        paddle.update()
        
        # 이벤트 트리거 (2점 또는 수동)
        if (player_score >= 2 or manual_trigger) and not balloon_event.triggered:
            balloon_event.activate(screen)
            manual_trigger = False
        
        # 풍선 이벤트 업데이트
        balloon_event.update()
        
        # 풍선과 공 충돌 체크
        if balloon_event.get_balloons():
            ball_vel = [ball.vx, ball.vy]
            collision = balloon_event.check_balloon_collisions(
                ball.rect, ball.radius, ball_vel,
                None, None, False, trade_system  # trade_system 전달!
            )
            if collision:
                ball.vx = ball_vel[0]
                ball.vy = ball_vel[1]
                player_score += 1
                print(f"💥 Balloon hit! Score: {player_score}")
        
        # 트레이드 포인트 시스템 업데이트 (패들과 공 모두 별 수집 가능)
        collected = trade_system.update(ball.rect, paddle.rect)
        if collected > 0:
            print(f"⭐ Collected {collected} star(s)! Total: {trade_system.get_collected_count()}")
        
        # 화면 그리기
        screen.fill(BLACK)
        
        # 배경 격자
        for x in range(0, SCREEN_WIDTH, 50):
            pygame.draw.line(screen, (30, 30, 30), (x, 0), (x, SCREEN_HEIGHT), 1)
        for y in range(0, SCREEN_HEIGHT, 50):
            pygame.draw.line(screen, (30, 30, 30), (0, y), (SCREEN_WIDTH, y), 1)
        
        # 게임 요소 그리기
        ball.draw(screen)
        paddle.draw(screen)
        
        # 풍선 이벤트 그리기
        balloon_event.draw(screen)
        
        # 트레이드 포인트 시스템 그리기
        trade_system.draw()
        
        # UI 그리기
        score_text = font.render(f"Score: {player_score}", True, WHITE)
        screen.blit(score_text, (10, 10))
        
        star_text = font.render(f"Stars: {trade_system.get_collected_count()}", True, YELLOW)
        screen.blit(star_text, (10, 40))
        
        # 도움말
        help_texts = [
            "SPACE: Trigger Balloon Event",
            "R: Reset",
            "Mouse: Move Paddle",
            "Hit SPECIAL balloon (samtaegeuk) to spawn star!"
        ]
        for i, text in enumerate(help_texts):
            help_surface = small_font.render(text, True, (150, 150, 150))
            screen.blit(help_surface, (10, SCREEN_HEIGHT - 100 + i * 20))
        
        # 이벤트 상태 표시
        if balloon_event.active:
            event_text = font.render(f"EVENT ACTIVE: {balloon_event.phase}", True, RED)
            screen.blit(event_text, (SCREEN_WIDTH // 2 - 100, 100))
        
        # 화면 업데이트
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()