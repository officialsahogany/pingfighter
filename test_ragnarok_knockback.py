"""
라그나로크 해머 넉백 효과 테스트
강화된 넉백 효과가 제대로 작동하는지 확인
"""

import pygame
import sys
import os
import math
import time

# 상위 디렉토리를 Python 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from legendary_items import LegendaryManager, RagnarokHammer

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH = 600
HEIGHT = 400
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("라그나로크 해머 넉백 테스트")

# 색상
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
BLUE = (0, 0, 255)
GREEN = (0, 255, 0)
YELLOW = (255, 255, 0)

# 폰트
FONT = pygame.font.Font(None, 36)
SMALL_FONT = pygame.font.Font(None, 24)

# 보스 패들
boss_rect = pygame.Rect(300, 200, 80, 100)
boss_knockback_vel = 0
boss_knockback_timer = 0
boss_stun_timer = 0
ragnarok_stun_pending = 0

# 공
ball_pos = [100, 200]
ball_vel = [15, 0]  # 초기 속도
ball_radius = 10

# 전설 아이템 매니저
legendary_manager = LegendaryManager()
legendary_manager._init_legendary_items()
hammer = legendary_manager.get_item("ragnarok_hammer")
hammer.active = True  # 강제 활성화

# 테스트 상태
test_state = "ready"  # ready, firing, knockback, stunned
space_pressed = False

clock = pygame.time.Clock()
running = True

while running:
    dt = clock.tick(60) / 1000.0
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE and test_state == "ready":
                # 공 발사
                ball_pos = [100, boss_rect.centery]
                ball_vel = [20, 0]  # 공속 20 (스턴공이면 30이 됨)
                test_state = "firing"
            elif event.key == pygame.K_1:
                ball_vel = [10, 0]  # 느린 공
            elif event.key == pygame.K_2:
                ball_vel = [20, 0]  # 보통 공
            elif event.key == pygame.K_3:
                ball_vel = [30, 0]  # 빠른 공
            elif event.key == pygame.K_r:
                # 리셋
                boss_rect.x = 300
                ball_pos = [100, 200]
                ball_vel = [15, 0]
                boss_knockback_vel = 0
                boss_knockback_timer = 0
                boss_stun_timer = 0
                ragnarok_stun_pending = 0
                test_state = "ready"
    
    # 공 업데이트
    if test_state == "firing":
        ball_pos[0] += ball_vel[0]
        ball_pos[1] += ball_vel[1]
        
        # 보스와 충돌 체크
        if boss_rect.collidepoint(ball_pos[0] + ball_radius, ball_pos[1]):
            # 넉백 계산
            ball_speed = abs(ball_vel[0])
            horizontal_velocity, stun_duration = hammer.calculate_knockback(ball_speed, boss_rect.x)
            
            if horizontal_velocity != 0:
                boss_knockback_timer = 60  # 1초간 넉백
                boss_knockback_vel = horizontal_velocity
                if stun_duration > 0:
                    ragnarok_stun_pending = int(stun_duration * 60)
                test_state = "knockback"
                
                # 공 리셋
                ball_pos = [100, 200]
                
                print(f"넉백 발동! 속도: {boss_knockback_vel:.1f}, 스턴 예정: {ragnarok_stun_pending/60:.1f}초")
    
    # 보스 넉백 처리
    if boss_knockback_timer > 0:
        boss_knockback_timer -= 1
        boss_rect.x += boss_knockback_vel
        boss_rect.x = max(0, min(WIDTH - boss_rect.width, boss_rect.x))
        
        # 라그나로크 해머 감속 (pingfighter.py와 동일)
        if boss_knockback_timer > 40:
            boss_knockback_vel *= 0.98
        elif boss_knockback_timer > 20:
            boss_knockback_vel *= 0.96
        else:
            boss_knockback_vel *= 0.93
        
        # 넉백 종료 시 스턴 적용
        if boss_knockback_timer == 0 and ragnarok_stun_pending > 0:
            boss_stun_timer = ragnarok_stun_pending
            ragnarok_stun_pending = 0
            test_state = "stunned"
    
    # 보스 스턴 처리
    if boss_stun_timer > 0:
        boss_stun_timer -= 1
        if boss_stun_timer == 0:
            test_state = "ready"
    
    # 화면 그리기
    SCREEN.fill(BLACK)
    
    # 보스 그리기
    if boss_stun_timer > 0:
        # 스턴 중 - 빨간색
        pygame.draw.rect(SCREEN, RED, boss_rect)
        # 전기 효과
        for i in range(3):
            start_y = boss_rect.top + i * 30
            end_y = start_y + 20
            pygame.draw.line(SCREEN, YELLOW, 
                           (boss_rect.centerx - 10, start_y),
                           (boss_rect.centerx + 10, end_y), 2)
    else:
        pygame.draw.rect(SCREEN, BLUE, boss_rect)
    
    # 공 그리기
    if test_state == "firing":
        pygame.draw.circle(SCREEN, WHITE, (int(ball_pos[0]), int(ball_pos[1])), ball_radius)
    
    # 정보 표시
    info_texts = [
        f"공속: {abs(ball_vel[0]):.0f}",
        f"넉백 속도: {boss_knockback_vel:.1f}",
        f"넉백 타이머: {boss_knockback_timer}",
        f"스턴 타이머: {boss_stun_timer}",
        f"상태: {test_state}"
    ]
    
    y_offset = 10
    for text in info_texts:
        text_surf = SMALL_FONT.render(text, True, WHITE)
        SCREEN.blit(text_surf, (10, y_offset))
        y_offset += 25
    
    # 조작법
    control_texts = [
        "SPACE: 공 발사",
        "1,2,3: 공속 설정 (10,20,30)",
        "R: 리셋"
    ]
    
    y_offset = HEIGHT - 80
    for text in control_texts:
        text_surf = SMALL_FONT.render(text, True, GREEN)
        SCREEN.blit(text_surf, (10, y_offset))
        y_offset += 25
    
    # 넉백 거리 표시
    if test_state in ["knockback", "stunned"]:
        distance = abs(boss_rect.x - 300)
        dist_text = FONT.render(f"넉백 거리: {distance:.0f}px", True, YELLOW)
        SCREEN.blit(dist_text, (WIDTH//2 - 100, HEIGHT//2))
    
    pygame.display.flip()

pygame.quit()