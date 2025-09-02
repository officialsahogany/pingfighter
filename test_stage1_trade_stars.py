"""
Stage 1 특별한 풍선 + 트레이드 포인트 별 시스템 테스트
테스트 목적:
1. 플레이어가 2점 획득하면 풍선 기계 이벤트 발동
2. 4번째 풍선(특별한 삼태극 풍선)이 터지면 별이 생성됨
3. 별이 플레이어 패들에 닿으면 트레이드 포인트 증가
"""

import pygame
import sys
from events.stage1_event_integration import Stage1EventManager
from trade_point_system import TradePointSystem

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH = 600
HEIGHT = 750
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Stage 1 Special Balloon + Trade Stars Test")

# 색상
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
YELLOW = (255, 255, 0)
RED = (255, 100, 100)
BLUE = (100, 100, 255)
GREEN = (100, 255, 100)

# 시계
clock = pygame.time.Clock()

# 폰트
try:
    font = pygame.font.Font("NeoDGM.ttf", 24)
    small_font = pygame.font.Font("NeoDGM.ttf", 16)
except:
    font = pygame.font.Font(None, 24)
    small_font = pygame.font.Font(None, 16)

# 시스템 초기화
stage1_events = Stage1EventManager()
trade_point_system = TradePointSystem(SCREEN)

# 게임 상태
player_score = 0
boss_score = 0
current_stage = 1
round_count = 1

# 공
ball_x = WIDTH // 2
ball_y = HEIGHT // 2
ball_vx = 5
ball_vy = 5
ball_radius = 10

# 플레이어 패들
player_rect = pygame.Rect(WIDTH // 2 - 60, HEIGHT - 100, 120, 20)
player_speed = 8

# 풍선 기계 이벤트 트리거 플래그
balloon_event_triggered = False

# 사운드 (옵션)
try:
    sound_balloon = pygame.mixer.Sound("sounds/balloon_boom.wav")
    sound_balloon.set_volume(0.5)
except:
    sound_balloon = None
    print("⚠️ 풍선 터지는 효과음을 찾을 수 없습니다")

# 게임 루프
running = True

print("=" * 60)
print("🎈 Stage 1 특별한 풍선 + 트레이드 포인트 별 테스트")
print("=" * 60)
print("조작:")
print("← → : 패들 이동")
print("SPACE : 플레이어 점수 +1 (테스트용)")
print("R : 리셋")
print("Q : 종료")
print("")
print("테스트 순서:")
print("1. SPACE를 2번 눌러 플레이어 점수를 2점으로 만들기")
print("2. 풍선 기계가 나타나며 8개 풍선 발사")
print("3. 4번째 풍선(삼태극 무늬)을 공으로 터뜨리기")
print("4. 별이 떨어지면 패들로 받기")
print("5. 트레이드 포인트가 증가하는지 확인")
print("=" * 60)

while running:
    dt = clock.tick(60)
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_q:
                running = False
            elif event.key == pygame.K_SPACE:
                # 플레이어 점수 증가 (테스트용)
                player_score += 1
                print(f"📊 플레이어 점수: {player_score}")
                
                # 2점 달성 시 이벤트 트리거
                if player_score >= 2 and not balloon_event_triggered:
                    if stage1_events.check_events(player_score, boss_score, current_stage, round_count):
                        stage1_events.trigger_event(SCREEN, player_score, current_stage, sound_balloon)
                        balloon_event_triggered = True
                        print("🎈 풍선 기계 이벤트 발동!")
                        print("💡 4번째 풍선(삼태극 무늬)을 터뜨리면 별이 생성됩니다!")
            elif event.key == pygame.K_r:
                # 리셋
                player_score = 0
                boss_score = 0
                balloon_event_triggered = False
                stage1_events.reset()
                trade_point_system.reset()
                ball_x = WIDTH // 2
                ball_y = HEIGHT // 2
                print("🔄 시스템 리셋!")
    
    # 플레이어 이동
    keys = pygame.key.get_pressed()
    if keys[pygame.K_LEFT] and player_rect.left > 0:
        player_rect.x -= player_speed
    if keys[pygame.K_RIGHT] and player_rect.right < WIDTH:
        player_rect.x += player_speed
    
    # 이벤트 업데이트
    stage1_events.update()
    
    # 이벤트 중이 아닐 때만 공 업데이트
    if not stage1_events.should_pause_game():
        # 공 이동
        ball_x += ball_vx
        ball_y += ball_vy
        
        # 벽 충돌
        if ball_x - ball_radius <= 0 or ball_x + ball_radius >= WIDTH:
            ball_vx = -ball_vx
        if ball_y - ball_radius <= 0 or ball_y + ball_radius >= HEIGHT:
            ball_vy = -ball_vy
        
        # 패들 충돌
        ball_rect = pygame.Rect(ball_x - ball_radius, ball_y - ball_radius,
                               ball_radius * 2, ball_radius * 2)
        if ball_rect.colliderect(player_rect) and ball_vy > 0:
            ball_vy = -ball_vy
        
        # 풍선과 공의 충돌 체크 (트레이드 포인트 시스템 포함)
        if stage1_events.get_active_balloons():
            collision = stage1_events.check_balloon_collisions(
                ball_rect, ball_radius, [ball_vx, ball_vy],
                None,  # effects_manager (없음)
                sound_balloon,  # 풍선 터지는 효과음
                False,  # whip_active (비활성)
                trade_point_system  # 트레이드 포인트 시스템 전달!
            )
            if collision:
                print("💥 풍선과 충돌!")
    
    # 트레이드 포인트 시스템 업데이트 (플레이어 패들과 충돌 체크)
    collected = trade_point_system.update(player_rect)
    if collected > 0:
        print(f"⭐ 트레이드 포인트 획득! 총: {trade_point_system.get_collected_count()}")
    
    # 화면 그리기
    SCREEN.fill(BLACK)
    
    # 게임 요소 그리기
    # 점수 표시
    score_text = font.render(f"플레이어: {player_score} | 보스: {boss_score}", True, WHITE)
    SCREEN.blit(score_text, (WIDTH // 2 - 120, 20))
    
    # 트레이드 포인트 표시
    trade_text = font.render(f"트레이드 포인트: {trade_point_system.get_collected_count()}", True, YELLOW)
    SCREEN.blit(trade_text, (WIDTH // 2 - 100, 50))
    
    # 활성 별 개수 표시
    star_info = small_font.render(f"활성 별: {trade_point_system.get_active_star_count()}", True, WHITE)
    SCREEN.blit(star_info, (10, HEIGHT - 40))
    
    # 플레이어 패들
    pygame.draw.rect(SCREEN, GREEN, player_rect)
    pygame.draw.rect(SCREEN, WHITE, player_rect, 2)
    
    # 공 그리기 (이벤트 중이 아닐 때만)
    if not stage1_events.should_pause_game():
        pygame.draw.circle(SCREEN, BLUE, (int(ball_x), int(ball_y)), ball_radius)
        pygame.draw.circle(SCREEN, WHITE, (int(ball_x), int(ball_y)), ball_radius, 2)
    
    # 트레이드 포인트 시스템 그리기 (별과 파티클)
    trade_point_system.draw()
    
    # Stage 1 이벤트 그리기 (풍선 기계와 풍선들)
    stage1_events.draw(SCREEN)
    
    # 이벤트 상태 표시
    if stage1_events.is_event_active():
        event_info = stage1_events.get_event_info()
        if event_info['phase']:
            phase_text = font.render(f"이벤트: {event_info['phase']}", True, RED)
            SCREEN.blit(phase_text, (WIDTH // 2 - 60, HEIGHT // 2 - 200))
    
    # 힌트 표시
    if player_score < 2:
        hint = small_font.render("SPACE를 눌러 2점을 만드세요!", True, YELLOW)
        SCREEN.blit(hint, (WIDTH // 2 - 100, HEIGHT - 20))
    elif stage1_events.get_active_balloons():
        hint = small_font.render("삼태극 풍선(4번째)을 터뜨리면 별이 나옵니다!", True, YELLOW)
        SCREEN.blit(hint, (WIDTH // 2 - 150, HEIGHT - 20))
    
    pygame.display.flip()

pygame.quit()
sys.exit()