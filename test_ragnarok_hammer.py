#!/usr/bin/env python3
"""
라그나로크 해머 전설 아이템 테스트
"""

import pygame
import math
import random
from legendary_items import get_legendary_manager

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("라그나로크 해머 테스트")
clock = pygame.time.Clock()

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
BLUE = (0, 100, 255)
YELLOW = (255, 255, 0)

# 게임 상수 정의
WINDOW_WIDTH = 800
PADDLE_WIDTH = 100

# 전설 아이템 매니저
legendary_manager = get_legendary_manager()

# 라그나로크 해머 활성화
game_state = {
    'current_stage': 1,
    'cooldown_multiplier': 1.0
}
legendary_manager.activate_item("ragnarok_hammer", game_state)

# 테스트용 패들 및 공
boss_paddle = pygame.Rect(350, 50, 100, 20)
player_paddle = pygame.Rect(350, 530, 100, 20)
ball = pygame.Rect(390, 300, 20, 20)
ball_vel = [5, -8]

# 넉백 애니메이션 변수
boss_knockback_timer = 0
boss_knockback_offset = 0
boss_original_y = boss_paddle.y

# 폰트
font = pygame.font.Font(None, 24)
font_large = pygame.font.Font(None, 36)

# 게임 루프
running = True
dt = 0
total_knockback = 0
hit_count = 0
boss_stun_timer = 0

print("\n=== 라그나로크 해머 테스트 ===")
print("SPACE: 공 발사 | ESC: 종료")
print("공이 보스 패들에 맞을 때 넉백 효과를 확인하세요!\n")

while running:
    dt = clock.tick(60)
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                # 공을 플레이어에서 보스로 발사
                ball.center = player_paddle.center
                ball.y -= 30
                ball_vel = [random.uniform(-3, 3), random.uniform(-10, -15)]
    
    # 공 업데이트
    ball.x += ball_vel[0]
    ball.y += ball_vel[1]
    
    # 벽 충돌
    if ball.x <= 0 or ball.x >= 780:
        ball_vel[0] *= -1
    
    # 보스 패들 충돌
    if ball.colliderect(boss_paddle) and ball_vel[1] < 0:
        ball_vel[1] *= -1
        
        # 라그나로크 해머 넉백 효과
        hammer = legendary_manager.items.get("ragnarok_hammer")
        if hammer and hammer.active:
            ball_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
            knockback_velocity, stun_duration = hammer.calculate_knockback(ball_speed, boss_paddle.x)
            
            if abs(knockback_velocity) > 0:
                # 넉백 적용 (수평 넉백)
                boss_paddle.x += knockback_velocity
                boss_paddle.x = max(0, min(WINDOW_WIDTH - PADDLE_WIDTH, boss_paddle.x))
                boss_knockback_timer = 36  # 0.6초 (60 FPS)
                boss_stun_timer = int(stun_duration * 60)  # 스턴도 0.6초
                
                # 통계 업데이트
                total_knockback += abs(knockback_velocity)
                hit_count += 1
                
                print(f"💥 넉백 발생! 속도: {knockback_velocity:.1f} | 공속: {ball_speed:.1f} | 스턴: {stun_duration}초")
    
    # 플레이어 패들 충돌
    if ball.colliderect(player_paddle) and ball_vel[1] > 0:
        ball_vel[1] *= -1
        # 각도 조절
        hit_pos = (ball.centerx - player_paddle.centerx) / (player_paddle.width / 2)
        ball_vel[0] = 8 * hit_pos
    
    # 공이 화면 밖으로 나가면 리셋
    if ball.y < -20 or ball.y > 620:
        ball.center = (400, 300)
        ball_vel = [random.uniform(-3, 3), 5]
    
    # 보스 패들 넉백 애니메이션
    if boss_knockback_timer > 0:
        boss_knockback_timer -= 1
        # 흔들림 효과
        shake_x = random.uniform(-boss_knockback_offset/10, boss_knockback_offset/10)
        boss_paddle.x += shake_x
        boss_paddle.x = max(0, min(700, boss_paddle.x))
    else:
        # 원위치로 복귀
        if boss_paddle.y < boss_original_y:
            boss_paddle.y += 2
            boss_paddle.y = min(boss_original_y, boss_paddle.y)
    
    # 마우스로 플레이어 패들 제어
    mouse_x = pygame.mouse.get_pos()[0]
    player_paddle.centerx = mouse_x
    player_paddle.x = max(0, min(700, player_paddle.x))
    
    # 화면 그리기
    screen.fill(BLACK)
    
    # 배경 격자
    for i in range(0, 800, 50):
        pygame.draw.line(screen, (30, 30, 30), (i, 0), (i, 600), 1)
    for i in range(0, 600, 50):
        pygame.draw.line(screen, (30, 30, 30), (0, i), (800, i), 1)
    
    # 패들 그리기
    pygame.draw.rect(screen, RED, boss_paddle)
    pygame.draw.rect(screen, BLUE, player_paddle)
    
    # 공 그리기
    pygame.draw.circle(screen, YELLOW, ball.center, 10)
    
    # 라그나로크 해머 효과 그리기
    hammer = legendary_manager.items.get("ragnarok_hammer")
    if hammer and hammer.active:
        hammer.update(dt)
        hammer.draw_special_effects(screen, boss_paddle.centerx, boss_paddle.centery)
        
        # 아이콘 그리기
        hammer.draw_icon(screen, 20, 20, 40)
        
        # 상태 텍스트
        status_text = font.render("라그나로크 해머 활성화", True, (255, 100, 100))
        screen.blit(status_text, (70, 30))
    
    # 통계 표시
    if hit_count > 0:
        avg_knockback = total_knockback / hit_count
        stats_text = font.render(f"총 넉백: {total_knockback:.0f}px | 평균: {avg_knockback:.1f}px | 횟수: {hit_count}", True, WHITE)
        screen.blit(stats_text, (20, 560))
    
    # 공 속도 표시
    ball_speed = math.sqrt(ball_vel[0]**2 + ball_vel[1]**2)
    speed_text = font.render(f"공 속도: {ball_speed:.1f}", True, WHITE)
    screen.blit(speed_text, (20, 530))
    
    # 안내 텍스트
    help_text = font.render("SPACE: 공 발사 | 마우스: 패들 이동", True, (150, 150, 150))
    screen.blit(help_text, (250, 10))
    
    pygame.display.flip()

pygame.quit()
print(f"\n테스트 종료")
print(f"총 넉백 거리: {total_knockback:.0f}px")
print(f"평균 넉백: {total_knockback/hit_count if hit_count > 0 else 0:.1f}px")
print(f"총 충돌 횟수: {hit_count}")