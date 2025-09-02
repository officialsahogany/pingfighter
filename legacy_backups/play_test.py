#!/usr/bin/env python3
"""
BossPong 플레이 테스트
실제 게임플레이가 가능한지 확인
"""

import pygame
import sys

def simple_pong():
    """간단한 Pong 게임 테스트"""
    pygame.init()
    
    # 화면 설정
    WIDTH, HEIGHT = 600, 750
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("BossPong v2.0 - Play Test")
    clock = pygame.time.Clock()
    
    # 색상
    WHITE = (255, 255, 255)
    BLACK = (0, 0, 0)
    RED = (255, 100, 100)
    BLUE = (100, 100, 255)
    
    # 게임 객체
    ball = pygame.Rect(WIDTH//2 - 5, HEIGHT//2 - 5, 10, 10)
    player = pygame.Rect(WIDTH//2 - 50, HEIGHT - 60, 100, 10)
    boss = pygame.Rect(WIDTH//2 - 50, 50, 100, 10)
    
    # 속도
    ball_dx, ball_dy = 5, 5
    player_speed = 10
    boss_speed = 5
    
    # 점수
    player_score = 0
    boss_score = 0
    font = pygame.font.Font(None, 36)
    
    # 게임 상태
    running = True
    game_over = False
    
    print("=" * 50)
    print("BossPong v2.0 - 플레이 테스트")
    print("=" * 50)
    print("조작법:")
    print("  ← / → : 패들 이동")
    print("  A / D : 패들 이동 (대체)")
    print("  SPACE : 게임 재시작")
    print("  ESC : 종료")
    print("=" * 50)
    
    while running:
        dt = clock.tick(60) / 1000.0
        
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE and game_over:
                    # 게임 재시작
                    ball.center = (WIDTH//2, HEIGHT//2)
                    ball_dx, ball_dy = 5, 5
                    player_score = 0
                    boss_score = 0
                    game_over = False
        
        if not game_over:
            # 입력 처리
            keys = pygame.key.get_pressed()
            if keys[pygame.K_LEFT] or keys[pygame.K_a]:
                player.x = max(0, player.x - player_speed)
            if keys[pygame.K_RIGHT] or keys[pygame.K_d]:
                player.x = min(WIDTH - player.width, player.x + player_speed)
            
            # 보스 AI (공 따라가기)
            if ball.centerx < boss.centerx:
                boss.x = max(0, boss.x - boss_speed)
            elif ball.centerx > boss.centerx:
                boss.x = min(WIDTH - boss.width, boss.x + boss_speed)
            
            # 공 이동
            ball.x += ball_dx
            ball.y += ball_dy
            
            # 벽 충돌
            if ball.left <= 0 or ball.right >= WIDTH:
                ball_dx = -ball_dx
            
            # 패들 충돌
            if ball.colliderect(player):
                ball_dy = -abs(ball_dy)
                # 패들 위치에 따른 각도 변경
                hit_pos = (ball.centerx - player.centerx) / (player.width / 2)
                ball_dx = 8 * hit_pos
                player_score += 10
                
            if ball.colliderect(boss):
                ball_dy = abs(ball_dy)
                # 보스 히트 시 랜덤 각도
                import random
                ball_dx = random.uniform(-8, 8)
                
            # 공이 화면 밖으로 나감
            if ball.top <= 0:
                boss_score += 1
                ball.center = (WIDTH//2, HEIGHT//2)
                ball_dy = abs(ball_dy)
                
            if ball.bottom >= HEIGHT:
                player_score -= 5
                ball.center = (WIDTH//2, HEIGHT//2) 
                ball_dy = -abs(ball_dy)
                
            # 게임 오버 체크
            if player_score >= 100:
                game_over = True
                print("🎉 승리! 최종 점수:", player_score)
            elif boss_score >= 10:
                game_over = True
                print("💀 패배! 보스 점수:", boss_score)
        
        # 렌더링
        screen.fill(BLACK)
        
        # 게임 객체 그리기
        pygame.draw.rect(screen, WHITE, ball)
        pygame.draw.rect(screen, BLUE, player)
        pygame.draw.rect(screen, RED, boss)
        
        # 중앙선
        for i in range(0, HEIGHT, 20):
            pygame.draw.rect(screen, (50, 50, 50), (WIDTH//2 - 2, i, 4, 10))
        
        # 점수 표시
        score_text = font.render(f"Score: {player_score}", True, WHITE)
        screen.blit(score_text, (10, 10))
        
        boss_text = font.render(f"Boss: {boss_score}", True, RED)
        screen.blit(boss_text, (WIDTH - 150, 10))
        
        # 게임 오버 메시지
        if game_over:
            over_text = font.render("GAME OVER - Press SPACE to restart", True, WHITE)
            text_rect = over_text.get_rect(center=(WIDTH//2, HEIGHT//2))
            screen.blit(over_text, text_rect)
        
        # FPS 표시
        fps_text = font.render(f"FPS: {int(clock.get_fps())}", True, (100, 100, 100))
        screen.blit(fps_text, (WIDTH - 100, HEIGHT - 30))
        
        pygame.display.flip()
    
    pygame.quit()
    print("\n게임 종료")

if __name__ == "__main__":
    simple_pong()