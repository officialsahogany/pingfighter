"""
🎈 Balloon Machine Event Test
Stage 1 풍선 기계 이벤트 테스트 및 통합 예시
"""

import pygame
import sys
from events.stage1_event_integration import Stage1EventManager

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH = 600
HEIGHT = 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Stage 1 - Balloon Machine Event Test")
clock = pygame.time.Clock()

# 폰트 설정
try:
    font = pygame.font.Font("NeoDGM.ttf", 24)
    small_font = pygame.font.Font("NeoDGM.ttf", 18)
except:
    font = pygame.font.Font(None, 24)
    small_font = pygame.font.Font(None, 18)

# 이벤트 매니저 초기화
event_manager = Stage1EventManager()

# 게임 상태
player_score = 0
boss_score = 0
current_stage = 1
round_count = 1

# 공 위치 (시뮬레이션용)
ball_x = WIDTH // 2
ball_y = HEIGHT // 2
ball_vx = 5
ball_vy = 3

# 패들 위치
paddle_y = HEIGHT - 50
paddle_x = WIDTH // 2
paddle_width = 100
paddle_height = 15

boss_paddle_y = 50
boss_paddle_x = WIDTH // 2

def draw_game_elements():
    """기본 게임 요소 그리기"""
    # 배경
    screen.fill((30, 30, 40))
    
    # 스테이지 1 느낌의 배경 패턴
    for i in range(0, HEIGHT, 50):
        pygame.draw.line(screen, (40, 40, 50), (0, i), (WIDTH, i), 1)
    for i in range(0, WIDTH, 50):
        pygame.draw.line(screen, (40, 40, 50), (i, 0), (i, HEIGHT), 1)
    
    # 점수 표시
    score_text = font.render(f"Player: {player_score} | Boss: {boss_score}", True, (255, 255, 255))
    score_rect = score_text.get_rect(center=(WIDTH // 2, 30))
    screen.blit(score_text, score_rect)
    
    # 스테이지 정보
    stage_text = small_font.render(f"Stage {current_stage} - Round {round_count}", True, (200, 200, 200))
    stage_rect = stage_text.get_rect(center=(WIDTH // 2, 60))
    screen.blit(stage_text, stage_rect)
    
    # 패들 그리기
    pygame.draw.rect(screen, (100, 200, 100), 
                    (paddle_x - paddle_width // 2, paddle_y, paddle_width, paddle_height))
    pygame.draw.rect(screen, (200, 100, 100),
                    (boss_paddle_x - paddle_width // 2, boss_paddle_y, paddle_width, paddle_height))
    
    # 공 그리기 (이벤트 중이 아닐 때만)
    if not event_manager.should_pause_game():
        pygame.draw.circle(screen, (255, 255, 255), (int(ball_x), int(ball_y)), 10)
    
    # 이벤트 트리거 힌트
    if player_score < 2 and not event_manager.balloon_machine.triggered:
        hint_text = small_font.render("Get 2 points to trigger the event!", True, (255, 255, 100))
        hint_rect = hint_text.get_rect(center=(WIDTH // 2, HEIGHT - 100))
        screen.blit(hint_text, hint_rect)
    
    # 이벤트 상태 표시
    if event_manager.is_event_active():
        event_info = event_manager.get_event_info()
        status_text = font.render(f"EVENT: {event_info['phase']}", True, (255, 100, 100))
        status_rect = status_text.get_rect(center=(WIDTH // 2, HEIGHT // 2 - 200))
        screen.blit(status_text, status_rect)

def update_ball():
    """공 위치 업데이트 (간단한 시뮬레이션)"""
    global ball_x, ball_y, ball_vx, ball_vy, player_score, boss_score, round_count
    
    # 이벤트 중에는 공 업데이트 중지
    if event_manager.should_pause_game():
        return
    
    ball_x += ball_vx
    ball_y += ball_vy
    
    # 벽 충돌
    if ball_x <= 10 or ball_x >= WIDTH - 10:
        ball_vx = -ball_vx
    
    # 패들 충돌 (간단한 버전)
    if ball_y >= paddle_y and abs(ball_x - paddle_x) < paddle_width // 2:
        ball_vy = -ball_vy
        ball_y = paddle_y - 1
    
    if ball_y <= boss_paddle_y + paddle_height and abs(ball_x - boss_paddle_x) < paddle_width // 2:
        ball_vy = -ball_vy
        ball_y = boss_paddle_y + paddle_height + 1
    
    # 풍선과 공의 충돌 체크
    if event_manager.get_active_balloons():
        ball_rect = pygame.Rect(ball_x - 10, ball_y - 10, 20, 20)
        ball_velocity = [ball_vx, ball_vy]
        event_manager.check_balloon_collisions(ball_rect, 10, ball_velocity)
        ball_vx = ball_velocity[0]
        ball_vy = ball_velocity[1]
    
    # 득점 (간단한 버전)
    if ball_y > HEIGHT:
        boss_score += 1
        ball_x = WIDTH // 2
        ball_y = HEIGHT // 2
        ball_vy = -abs(ball_vy)
        round_count += 1
    
    if ball_y < 0:
        player_score += 1
        ball_x = WIDTH // 2
        ball_y = HEIGHT // 2
        ball_vy = abs(ball_vy)
        round_count += 1
        
        # 이벤트 트리거 체크
        if event_manager.check_events(player_score, boss_score, current_stage, round_count):
            event_manager.trigger_event(screen, player_score, current_stage)

def main():
    """메인 게임 루프"""
    global paddle_x, boss_paddle_x, player_score, boss_score, round_count
    
    running = True
    
    print("=" * 50)
    print("🎈 BALLOON MACHINE EVENT TEST")
    print("=" * 50)
    print("Controls:")
    print("- Arrow Keys: Move paddle")
    print("- SPACE: Add 1 point to player (for testing)")
    print("- R: Reset game")
    print("- ESC: Exit")
    print("=" * 50)
    print("Get 2 points to trigger the balloon machine event!")
    print("=" * 50)
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 테스트용: 스페이스바로 점수 추가
                    player_score += 1
                    print(f"Player Score: {player_score}")
                    
                    # 이벤트 트리거 체크
                    if event_manager.check_events(player_score, boss_score, current_stage, round_count):
                        event_manager.trigger_event(screen, player_score, current_stage)
                        
                elif event.key == pygame.K_r:
                    # 게임 리셋
                    player_score = 0
                    boss_score = 0
                    round_count = 1
                    event_manager.reset()
                    print("Game Reset!")
        
        # 키 입력 처리
        keys = pygame.key.get_pressed()
        if not event_manager.should_pause_game():
            if keys[pygame.K_LEFT]:
                paddle_x = max(paddle_width // 2, paddle_x - 8)
            if keys[pygame.K_RIGHT]:
                paddle_x = min(WIDTH - paddle_width // 2, paddle_x + 8)
        
        # 보스 패들 AI (간단한 추적)
        if not event_manager.should_pause_game():
            if boss_paddle_x < ball_x:
                boss_paddle_x = min(WIDTH - paddle_width // 2, boss_paddle_x + 3)
            elif boss_paddle_x > ball_x:
                boss_paddle_x = max(paddle_width // 2, boss_paddle_x - 3)
        
        # 게임 업데이트
        update_ball()
        
        # 이벤트 업데이트
        event_manager.update()
        
        # 화면 그리기
        draw_game_elements()
        
        # 이벤트 그리기 (게임 요소 위에)
        event_manager.draw(screen)
        
        # 컨트롤 힌트
        control_text = small_font.render("SPACE: +1 Point | R: Reset | ESC: Exit", True, (150, 150, 150))
        screen.blit(control_text, (10, HEIGHT - 20))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()