#!/usr/bin/env python3
"""물자보급 비행기 충돌 테스트 - 보스 패들 충돌 버그 수정 확인"""

import pygame
import sys
import os
import random

# 게임 모듈 임포트를 위한 경로 설정
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pingfighter import (
    supply_drop_state,
    SupplyAircraft,
    BALL,
    WIDTH,
    HEIGHT
)

# Pygame 초기화
pygame.init()
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("물자보급 비행기 충돌 테스트")
clock = pygame.time.Clock()

# 테스트용 패들 생성
PLAYER = pygame.Rect(WIDTH // 2 - 40, HEIGHT - 60, 80, 20)
BOSS = pygame.Rect(WIDTH // 2 - 40, 60, 80, 20)

# 테스트용 공 초기화
ball = BALL.copy()
ball.centerx = WIDTH // 2
ball.centery = HEIGHT // 2
ball_vel = [0, 5]  # 아래로 이동하는 공
ball_hit_by = "player"  # 플레이어가 친 공

def main():
    """메인 테스트 루프"""
    global ball, ball_vel, ball_hit_by
    
    # 비행기 직접 생성
    aircraft = SupplyAircraft("right_to_left")
    aircraft.y = BOSS.bottom + 50  # 보스 패들 아래에 위치
    
    running = True
    font = pygame.font.Font(None, 24)
    
    # 테스트 시나리오
    test_scenario = 1  # 1: 보스 패들 충돌, 2: 플레이어 공 충돌
    test_message = ""
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_1:
                    # 시나리오 1: 비행기가 보스 패들 근처로 이동
                    test_scenario = 1
                    aircraft = SupplyAircraft("right_to_left")
                    aircraft.y = BOSS.centery
                    aircraft.x = BOSS.x + 200
                    test_message = "테스트 1: 비행기가 보스 패들로 이동"
                    
                elif event.key == pygame.K_2:
                    # 시나리오 2: 플레이어 공이 비행기와 충돌
                    test_scenario = 2
                    aircraft = SupplyAircraft("left_to_right")
                    aircraft.y = HEIGHT // 2
                    aircraft.x = 100
                    ball.centerx = aircraft.x
                    ball.centery = aircraft.y - 50
                    ball_vel = [0, 5]
                    ball_hit_by = "player"
                    test_message = "테스트 2: 플레이어 공이 비행기와 충돌"
                    
                elif event.key == pygame.K_3:
                    # 시나리오 3: 보스 공이 비행기와 충돌 (격추 안됨)
                    test_scenario = 3
                    aircraft = SupplyAircraft("left_to_right")
                    aircraft.y = HEIGHT // 2
                    aircraft.x = 100
                    ball.centerx = aircraft.x
                    ball.centery = aircraft.y - 50
                    ball_vel = [0, 5]
                    ball_hit_by = "boss"
                    test_message = "테스트 3: 보스 공이 비행기와 충돌 (격추 안됨)"
        
        # 화면 클리어
        SCREEN.fill((30, 30, 30))
        
        # 패들 그리기
        pygame.draw.rect(SCREEN, (100, 200, 100), PLAYER)
        pygame.draw.rect(SCREEN, (255, 100, 100), BOSS)
        
        # 패들 레이블
        player_text = font.render("PLAYER", True, (255, 255, 255))
        boss_text = font.render("BOSS", True, (255, 255, 255))
        SCREEN.blit(player_text, (PLAYER.centerx - player_text.get_width()//2, PLAYER.bottom + 5))
        SCREEN.blit(boss_text, (BOSS.centerx - boss_text.get_width()//2, BOSS.top - 25))
        
        # 비행기 업데이트 및 그리기
        if aircraft.active:
            aircraft.update()
            aircraft.draw(SCREEN)
            
            # 충돌 체크
            if test_scenario == 1:
                # 보스 패들과의 충돌 테스트
                aircraft.check_paddle_brick_collision(PLAYER, BOSS, None)
            else:
                # 공과의 충돌 테스트
                aircraft.check_ball_collision(ball, ball_hit_by)
        
        # 공 업데이트 및 그리기
        if test_scenario in [2, 3]:
            ball.y += ball_vel[1]
            color = (100, 200, 100) if ball_hit_by == "player" else (255, 100, 100)
            pygame.draw.circle(SCREEN, color, ball.center, 10)
            
            # 공 소유자 표시
            owner_text = font.render(f"Ball: {ball_hit_by}", True, color)
            SCREEN.blit(owner_text, (ball.centerx - owner_text.get_width()//2, ball.centery - 30))
        
        # 상태 정보 표시
        info_y = 10
        status_texts = [
            f"비행기 활성: {aircraft.active}",
            f"추락 중: {aircraft.is_crashing if aircraft else False}",
            f"비행기 위치: ({aircraft.x:.0f}, {aircraft.y:.0f})" if aircraft else "비행기 없음",
            "",
            "테스트 키:",
            "1 - 보스 패들 충돌 테스트",
            "2 - 플레이어 공 충돌 테스트", 
            "3 - 보스 공 충돌 테스트",
            "",
            test_message
        ]
        
        for text in status_texts:
            if text:  # 빈 문자열이 아닐 때만 렌더링
                text_surface = font.render(text, True, (255, 255, 255))
                SCREEN.blit(text_surface, (10, info_y))
            info_y += 25
        
        # 중요 메시지 강조
        if aircraft and aircraft.is_crashing:
            crash_text = font.render("✈️ 비행기 추락 중!", True, (255, 255, 0))
            SCREEN.blit(crash_text, (WIDTH // 2 - crash_text.get_width() // 2, HEIGHT // 2))
        
        # 화면 업데이트
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()

if __name__ == "__main__":
    main()