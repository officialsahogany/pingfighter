#!/usr/bin/env python3
"""
라운드 전환 시 물방울 파티클 초기화 시각 테스트
- 실제 게임처럼 공이 떨어지고 새 라운드가 시작되는 것을 시뮬레이션
"""
import pygame
import sys
import os
import random
import math

# 모듈 임포트를 위한 경로 설정
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from legendary_items import get_legendary_manager

def test_round_transition_visual():
    """라운드 전환 시각 테스트"""
    print("=" * 60)
    print("라운드 전환 시 물방울 파티클 초기화 시각 테스트")
    print("=" * 60)
    
    # Pygame 초기화
    pygame.init()
    WIDTH, HEIGHT = 800, 600
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Round Transition Visual Test")
    clock = pygame.time.Clock()
    
    # 전설 아이템 매니저
    legendary_manager = get_legendary_manager()
    trident = legendary_manager.get_item("poseidon_trident")
    trident.activate({})
    
    # 게임 상태
    player_score = 0
    ai_score = 0
    ball_x = WIDTH // 2
    ball_y = HEIGHT // 2
    ball_vx = 5
    ball_vy = 8
    round_over = False
    round_transition_timer = 0
    
    font = pygame.font.Font(None, 36)
    small_font = pygame.font.Font(None, 24)
    
    def spawn_water_droplets(x, y, count=5):
        """물방울 생성"""
        for _ in range(count):
            droplet = {
                'x': x + random.randint(-20, 20),
                'y': y + random.randint(-20, 20),
                'vx': random.uniform(-3, 3),
                'vy': random.uniform(-4, -1),
                'life': 1.0,
                'size': random.randint(3, 6)
            }
            trident.water_droplets.append(droplet)
    
    # 메인 루프
    running = True
    while running:
        dt = clock.tick(60) / 1000.0
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_r and round_over:
                    # R키로 새 라운드 시작
                    round_over = False
                    round_transition_timer = 0
                    ball_x = WIDTH // 2
                    ball_y = HEIGHT // 2
                    ball_vx = random.choice([-5, 5])
                    ball_vy = random.choice([-8, 8])
                    
                    # 라운드 효과 초기화
                    legendary_manager.reset_round_effects()
                    print(f"새 라운드 시작! 물방울 초기화됨")
        
        # 화면 그리기
        screen.fill((20, 20, 40))
        
        if not round_over:
            # 공 이동
            ball_x += ball_vx
            ball_y += ball_vy
            
            # 벽 충돌
            if ball_x <= 20 or ball_x >= WIDTH - 20:
                ball_vx = -ball_vx
                spawn_water_droplets(ball_x, ball_y, 3)
            
            # 패들 충돌 시뮬레이션 (상단/하단 근처)
            if ball_y <= 100 and ball_vy < 0:
                ball_vy = -ball_vy
                spawn_water_droplets(ball_x, ball_y, 8)
            elif ball_y >= HEIGHT - 100 and ball_vy > 0:
                ball_vy = -ball_vy
                spawn_water_droplets(ball_x, ball_y, 8)
            
            # 공이 화면 밖으로 나감 (점수)
            if ball_y < 0:
                ai_score += 1
                round_over = True
                print(f"AI 득점! (플레이어 {player_score} - {ai_score} AI)")
            elif ball_y > HEIGHT:
                player_score += 1
                round_over = True
                print(f"플레이어 득점! (플레이어 {player_score} - {ai_score} AI)")
            
            # 공 그리기
            pygame.draw.circle(screen, (255, 255, 255), (int(ball_x), int(ball_y)), 10)
        
        # 물방울 업데이트 및 그리기
        for droplet in trident.water_droplets[:]:
            droplet['x'] += droplet['vx']
            droplet['y'] += droplet['vy']
            droplet['vy'] += 0.3  # 중력
            droplet['life'] -= 0.015
            
            if droplet['life'] <= 0 or droplet['y'] > HEIGHT:
                trident.water_droplets.remove(droplet)
                continue
            
            # 그리기
            alpha = int(droplet['life'] * 200)
            color = (100, 150, 255)
            pygame.draw.circle(screen, color, 
                             (int(droplet['x']), int(droplet['y'])), 
                             droplet['size'])
            # 하이라이트
            highlight_pos = (int(droplet['x'] - droplet['size']//3), 
                           int(droplet['y'] - droplet['size']//3))
            pygame.draw.circle(screen, (200, 220, 255), 
                             highlight_pos, droplet['size']//2)
        
        # UI 그리기
        score_text = font.render(f"{player_score} - {ai_score}", True, (255, 255, 255))
        score_rect = score_text.get_rect(center=(WIDTH//2, 50))
        screen.blit(score_text, score_rect)
        
        droplet_text = small_font.render(f"Water Droplets: {len(trident.water_droplets)}", True, (100, 200, 255))
        screen.blit(droplet_text, (10, 10))
        
        if round_over:
            # 라운드 종료 메시지
            round_text = font.render("Round Over!", True, (255, 100, 100))
            round_rect = round_text.get_rect(center=(WIDTH//2, HEIGHT//2))
            screen.blit(round_text, round_rect)
            
            restart_text = small_font.render("Press R to start new round", True, (200, 200, 200))
            restart_rect = restart_text.get_rect(center=(WIDTH//2, HEIGHT//2 + 40))
            screen.blit(restart_text, restart_rect)
            
            notice_text = small_font.render("(Water droplets will be cleared)", True, (100, 255, 100))
            notice_rect = notice_text.get_rect(center=(WIDTH//2, HEIGHT//2 + 70))
            screen.blit(notice_text, notice_rect)
        else:
            # 게임 진행 중 안내
            info_text = small_font.render("Ball bounces create water droplets", True, (150, 150, 150))
            screen.blit(info_text, (10, HEIGHT - 30))
        
        pygame.display.flip()
    
    pygame.quit()
    
    print("\n테스트 종료")
    print(f"최종 점수: 플레이어 {player_score} - {ai_score} AI")
    print(f"남은 물방울: {len(trident.water_droplets)}개")

if __name__ == "__main__":
    test_round_transition_visual()