"""
테크니컬조끼 아이템 테스트
플레이어 패들에 공이 닿았을 때 30% 확률로 연막 생성
"""

import pygame
import sys
import random
import math
from item_effects.technical_vest import get_technical_vest_instance

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 600, 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("테크니컬조끼 테스트")

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
BLUE = (0, 0, 255)
GRAY = (150, 150, 150)
GREEN = (0, 255, 0)

# 게임 객체 설정
ball_x = WIDTH // 2
ball_y = 100
ball_vel_x = random.choice([-5, 5])
ball_vel_y = 5
BALL_RADIUS = 8

# 패들 설정
paddle_width = 100
paddle_height = 15
paddle_x = WIDTH // 2 - paddle_width // 2
paddle_y = HEIGHT - 100

# 테크니컬조끼 인스턴스 가져오기
technical_vest = get_technical_vest_instance()

# 게임 상태
game_state = {'current_stage': 1}

# 테크니컬조끼 활성화
technical_vest.activate(game_state, 1)

# 폰트 설정
font = pygame.font.Font(None, 36)
small_font = pygame.font.Font(None, 24)

# 통계
collision_count = 0
smoke_triggered_count = 0

# 시뮬레이션 모드
simulation_mode = False
simulation_collisions = 0

clock = pygame.time.Clock()
running = True

while running:
    dt = clock.tick(60)
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                # 수동으로 충돌 발생시키기
                paddle_rect = pygame.Rect(paddle_x, paddle_y, paddle_width, paddle_height)
                technical_vest.on_ball_paddle_collision(paddle_rect)
                collision_count += 1
                if len(technical_vest.smoke_instances) > smoke_triggered_count:
                    smoke_triggered_count = len(technical_vest.smoke_instances)
            elif event.key == pygame.K_s:
                # 시뮬레이션 모드 토글
                simulation_mode = not simulation_mode
                if simulation_mode:
                    simulation_collisions = 0
                    print("시뮬레이션 모드 시작 - 100회 충돌 테스트")
            elif event.key == pygame.K_r:
                # 통계 리셋
                collision_count = 0
                smoke_triggered_count = 0
                technical_vest.smoke_instances.clear()
    
    # 시뮬레이션 모드에서 자동 충돌 생성
    if simulation_mode and simulation_collisions < 100:
        paddle_rect = pygame.Rect(paddle_x, paddle_y, paddle_width, paddle_height)
        technical_vest.on_ball_paddle_collision(paddle_rect)
        simulation_collisions += 1
        collision_count += 1
        if len(technical_vest.smoke_instances) > smoke_triggered_count:
            smoke_triggered_count += 1
        
        if simulation_collisions >= 100:
            simulation_mode = False
            print(f"시뮬레이션 완료! 100회 중 {smoke_triggered_count}회 연막 발동 ({smoke_triggered_count}%)")
    
    # 패들 이동 (마우스)
    mouse_x, _ = pygame.mouse.get_pos()
    paddle_x = mouse_x - paddle_width // 2
    paddle_x = max(0, min(WIDTH - paddle_width, paddle_x))
    
    # 공 움직임
    ball_x += ball_vel_x
    ball_y += ball_vel_y
    
    # 벽 충돌
    if ball_x - BALL_RADIUS <= 0 or ball_x + BALL_RADIUS >= WIDTH:
        ball_vel_x = -ball_vel_x
    if ball_y - BALL_RADIUS <= 0:
        ball_vel_y = -ball_vel_y
    
    # 패들 충돌
    paddle_rect = pygame.Rect(paddle_x, paddle_y, paddle_width, paddle_height)
    ball_rect = pygame.Rect(ball_x - BALL_RADIUS, ball_y - BALL_RADIUS, 
                            BALL_RADIUS * 2, BALL_RADIUS * 2)
    
    if ball_rect.colliderect(paddle_rect) and ball_vel_y > 0:
        ball_vel_y = -ball_vel_y
        # 충돌 시 테크니컬조끼 효과 발동
        technical_vest.on_ball_paddle_collision(paddle_rect)
        collision_count += 1
        if len(technical_vest.smoke_instances) > smoke_triggered_count:
            smoke_triggered_count = len(technical_vest.smoke_instances)
    
    # 공이 화면 밖으로 나가면 리셋
    if ball_y - BALL_RADIUS > HEIGHT:
        ball_x = WIDTH // 2
        ball_y = 100
        ball_vel_y = 5
    
    # 테크니컬조끼 업데이트 (플레이어 패들 위치 전달)
    paddle_rect = pygame.Rect(paddle_x, paddle_y, paddle_width, paddle_height)
    technical_vest.update(paddle_rect)
    
    # 화면 그리기
    screen.fill(BLACK)
    
    # 배경 격자 그리기
    for x in range(0, WIDTH, 50):
        pygame.draw.line(screen, (30, 30, 30), (x, 0), (x, HEIGHT))
    for y in range(0, HEIGHT, 50):
        pygame.draw.line(screen, (30, 30, 30), (0, y), (WIDTH, y))
    
    # 연막 효과 그리기
    technical_vest.draw_effects(screen)
    
    # 연막 영역 표시 (디버그용)
    for smoke in technical_vest.smoke_instances:
        # 활성 파티클 수 표시
        active_particles = len(smoke['trail_particles'])
        if active_particles > 0:
            particles_text = small_font.render(f"파티클: {active_particles}", True, GREEN)
            screen.blit(particles_text, (10, 140))
    
    # 패들 그리기
    pygame.draw.rect(screen, BLUE, paddle_rect)
    
    # 공 그리기
    color = RED
    # 공이 연막 안에 있는지 확인
    if technical_vest.check_smoke_collision(ball_x, ball_y):
        color = GREEN  # 연막 안에서는 초록색
    pygame.draw.circle(screen, color, (int(ball_x), int(ball_y)), BALL_RADIUS)
    
    # 정보 표시
    info_text = font.render("테크니컬조끼 테스트", True, WHITE)
    screen.blit(info_text, (WIDTH // 2 - info_text.get_width() // 2, 20))
    
    # 충돌 통계
    stats_text = small_font.render(f"충돌: {collision_count} | 연막 발동: {smoke_triggered_count}", True, WHITE)
    screen.blit(stats_text, (10, 60))
    
    if collision_count > 0:
        percentage = (smoke_triggered_count / collision_count) * 100
        percent_text = small_font.render(f"발동률: {percentage:.1f}%", True, WHITE)
        screen.blit(percent_text, (10, 85))
    
    # 현재 연막 수
    smoke_text = small_font.render(f"활성 연막: {len(technical_vest.smoke_instances)}", True, WHITE)
    screen.blit(smoke_text, (10, 110))
    
    # 조작법
    help_texts = [
        "마우스: 패들 이동",
        "스페이스: 수동 충돌 발동", 
        "S: 100회 시뮬레이션",
        "R: 통계 리셋"
    ]
    
    for i, text in enumerate(help_texts):
        help_text = small_font.render(text, True, WHITE)
        screen.blit(help_text, (WIDTH - 200, 60 + i * 25))
    
    pygame.display.flip()

pygame.quit()
sys.exit()