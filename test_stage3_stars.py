"""
Stage 3 트레이드 포인트 별 시스템 테스트
- 공이 벽에 맞으면 별이 떨어짐
- 플레이어 패들에 닿아야 트레이드 포인트 증가
"""

import pygame
import sys
import random
import math
from trade_point_system import TradePointSystem

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH = 600
HEIGHT = 750
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Stage 3 Trade Point Stars Test")

# 색상
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 255, 0)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (100, 150, 255)

# 시계
clock = pygame.time.Clock()

# 트레이드 포인트 시스템 생성
trade_system = TradePointSystem(SCREEN)

# 플레이어 패들
player_rect = pygame.Rect(WIDTH // 2 - 60, HEIGHT - 100, 120, 20)
player_speed = 8

# 공
ball_x = WIDTH // 2
ball_y = HEIGHT // 2
ball_vx = 5
ball_vy = 5
ball_radius = 10

# 폰트
try:
    font = pygame.font.Font("NeoDGM.ttf", 24)
    small_font = pygame.font.Font("NeoDGM.ttf", 16)
except:
    font = pygame.font.Font(None, 24)
    small_font = pygame.font.Font(None, 16)

# 통계
wall_hits = 0
stars_spawned = 0

# 게임 루프
running = True

while running:
    dt = clock.tick(60)
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_r:
                # R키로 리셋
                trade_system.reset()
                wall_hits = 0
                stars_spawned = 0
                ball_x = WIDTH // 2
                ball_y = HEIGHT // 2
                print("🔄 시스템 리셋!")
    
    # 플레이어 이동
    keys = pygame.key.get_pressed()
    if keys[pygame.K_LEFT] and player_rect.left > 0:
        player_rect.x -= player_speed
    if keys[pygame.K_RIGHT] and player_rect.right < WIDTH:
        player_rect.x += player_speed
    
    # 공 이동
    ball_x += ball_vx
    ball_y += ball_vy
    
    # 공 충돌 처리
    # 좌우 벽 충돌
    if ball_x - ball_radius <= 0 or ball_x + ball_radius >= WIDTH:
        ball_vx = -ball_vx
        wall_hits += 1
        
        # Stage 3 로직: 7% 확률로 별 생성
        if random.random() < 0.07:
            star_x = 30 if ball_x - ball_radius <= 0 else WIDTH - 30
            star_y = ball_y + random.randint(-30, 30)
            trade_system.spawn_star(star_x, star_y, "wall")
            stars_spawned += 1
            print(f"💫 별 생성! 위치: ({star_x}, {star_y}) - 총 {stars_spawned}개")
    
    # 상하 벽 충돌
    if ball_y - ball_radius <= 0:
        ball_vy = -ball_vy
    
    # 플레이어 패들과 충돌
    ball_rect = pygame.Rect(ball_x - ball_radius, ball_y - ball_radius,
                           ball_radius * 2, ball_radius * 2)
    if ball_rect.colliderect(player_rect) and ball_vy > 0:
        ball_vy = -ball_vy
        ball_y = player_rect.top - ball_radius
    
    # 공이 아래로 나가면 리셋
    if ball_y > HEIGHT:
        ball_x = WIDTH // 2
        ball_y = HEIGHT // 2
        ball_vy = -abs(ball_vy)
    
    # 트레이드 포인트 시스템 업데이트 (플레이어 패들과 충돌 체크)
    collected = trade_system.update(player_rect)
    if collected > 0:
        print(f"✨ {collected}개 수집! 총: {trade_system.get_collected_count()}")
    
    # 화면 그리기
    SCREEN.fill(BLACK)
    
    # 벽 표시
    pygame.draw.line(SCREEN, WHITE, (0, 0), (0, HEIGHT), 2)
    pygame.draw.line(SCREEN, WHITE, (WIDTH-1, 0), (WIDTH-1, HEIGHT), 2)
    pygame.draw.line(SCREEN, WHITE, (0, 0), (WIDTH, 0), 2)
    
    # 트레이드 포인트 시스템 그리기
    trade_system.draw()
    
    # 플레이어 패들 그리기
    pygame.draw.rect(SCREEN, GREEN, player_rect)
    pygame.draw.rect(SCREEN, WHITE, player_rect, 2)
    
    # 공 그리기
    pygame.draw.circle(SCREEN, BLUE, (int(ball_x), int(ball_y)), ball_radius)
    pygame.draw.circle(SCREEN, WHITE, (int(ball_x), int(ball_y)), ball_radius, 2)
    
    # 정보 표시
    info1 = font.render(f"트레이드 포인트: {trade_system.get_collected_count()}", True, YELLOW)
    info2 = small_font.render(f"벽 충돌: {wall_hits} | 별 생성: {stars_spawned} | 활성 별: {trade_system.get_active_star_count()}", True, WHITE)
    info3 = small_font.render("← → 이동 | R: 리셋 | Stage 3 시뮬레이션 (7% 확률)", True, WHITE)
    
    SCREEN.blit(info1, (10, 10))
    SCREEN.blit(info2, (10, 40))
    SCREEN.blit(info3, (10, HEIGHT - 25))
    
    # 7% 확률 표시
    chance_text = small_font.render("7%", True, RED)
    SCREEN.blit(chance_text, (5, HEIGHT//2))
    SCREEN.blit(chance_text, (WIDTH - 30, HEIGHT//2))
    
    pygame.display.flip()

pygame.quit()
sys.exit()