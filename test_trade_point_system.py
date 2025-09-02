"""
트레이드 포인트 시스템 테스트
"""

import pygame
import sys
from trade_point_system import TradePointSystem

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH = 600
HEIGHT = 750
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Trade Point System Test")

# 색상
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 255, 0)

# 시계
clock = pygame.time.Clock()

# 트레이드 포인트 시스템 생성
trade_system = TradePointSystem(SCREEN)

# 플레이어 (테스트용)
player_x = WIDTH // 2
player_y = HEIGHT - 100
player_size = 30

# 폰트
try:
    font = pygame.font.Font("NeoDGM.ttf", 24)
except:
    font = pygame.font.Font(None, 24)

# 게임 루프
running = True
spawn_timer = 0

while running:
    dt = clock.tick(60)
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                # 스페이스바로 별 생성
                import random
                x = random.randint(50, WIDTH - 50)
                y = random.randint(100, 300)
                source_type = random.choice(["wall", "crow", "balloon"])
                trade_system.spawn_star(x, y, source_type)
                print(f"⭐ 별 생성! 위치: ({x}, {y}), 타입: {source_type}")
            elif event.key == pygame.K_r:
                # R키로 리셋
                trade_system.reset()
                print("🔄 시스템 리셋!")
    
    # 플레이어 이동 (마우스)
    mouse_x, mouse_y = pygame.mouse.get_pos()
    player_x = mouse_x
    player_y = mouse_y
    
    # 자동 별 생성 (3초마다)
    spawn_timer += dt
    if spawn_timer > 3000:  # 3초
        spawn_timer = 0
        import random
        x = random.randint(50, WIDTH - 50)
        y = random.randint(100, 300)
        source_type = random.choice(["wall", "crow", "balloon"])
        trade_system.spawn_star(x, y, source_type)
        print(f"⭐ 자동 별 생성! 위치: ({x}, {y})")
    
    # 플레이어 충돌 영역
    player_rect = pygame.Rect(player_x - player_size, player_y - player_size,
                             player_size * 2, player_size * 2)
    
    # 시스템 업데이트
    collected = trade_system.update(player_rect)
    if collected > 0:
        print(f"✨ {collected}개 수집! 총: {trade_system.get_collected_count()}")
    
    # 화면 그리기
    SCREEN.fill(BLACK)
    
    # 트레이드 포인트 시스템 그리기
    trade_system.draw()
    
    # 플레이어 그리기
    pygame.draw.circle(SCREEN, YELLOW, (player_x, player_y), player_size, 2)
    
    # 정보 표시
    info_text1 = font.render(f"수집: {trade_system.get_collected_count()}", True, WHITE)
    info_text2 = font.render(f"활성 별: {trade_system.get_active_star_count()}", True, WHITE)
    info_text3 = font.render("SPACE: 별 생성, R: 리셋, 마우스: 이동", True, WHITE)
    
    SCREEN.blit(info_text1, (10, 10))
    SCREEN.blit(info_text2, (10, 40))
    SCREEN.blit(info_text3, (10, HEIGHT - 30))
    
    pygame.display.flip()

pygame.quit()
sys.exit()