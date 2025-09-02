#!/usr/bin/env python3
"""
대시 방구 구름 효과 테스트
"""

import pygame
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

import effects_manager

# Pygame 초기화
pygame.init()

WIDTH = 600
HEIGHT = 750
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("대시 방구 구름 효과 테스트")

# 효과 매니저 초기화
effects_manager.init_effects_manager(SCREEN, WIDTH, HEIGHT)

# 색상
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
BROWN = (139, 69, 19)  # 바닥 색상

# 플레이어 위치
player_x = WIDTH // 2
player_y = HEIGHT // 2

clock = pygame.time.Clock()
running = True

# 테스트용 연기 생성
test_smoke_timer = 0

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_LEFT:
                # 왼쪽 대시 - 오른쪽에 먼지
                effects_manager.create_dash_smoke(player_x, player_y, 'left')
                print("왼쪽 대시 - 먼지 생성!")
            elif event.key == pygame.K_RIGHT:
                # 오른쪽 대시 - 왼쪽에 먼지
                effects_manager.create_dash_smoke(player_x, player_y, 'right')
                print("오른쪽 대시 - 먼지 생성!")
            elif event.key == pygame.K_SPACE:
                # 스페이스바로 양쪽 먼지 동시 생성
                effects_manager.create_dash_smoke(player_x, player_y, 'left')
                effects_manager.create_dash_smoke(player_x, player_y, 'right')
                print("양쪽 먼지 생성!")
    
    # 자동 먼지 생성 (테스트용)
    test_smoke_timer += 1
    if test_smoke_timer > 120:  # 2초마다 (더 잘 보이도록)
        effects_manager.create_dash_smoke(player_x, player_y, 'left' if test_smoke_timer % 240 < 120 else 'right')
        test_smoke_timer = 0
    
    # 화면 그리기
    SCREEN.fill(BLACK)
    
    # 바닥 표시 (야구장 느낌)
    pygame.draw.rect(SCREEN, BROWN, (0, player_y + 15, WIDTH, HEIGHT - player_y - 15))
    
    # 플레이어 위치 표시 (빨간 원)
    pygame.draw.circle(SCREEN, RED, (player_x, player_y), 20)
    
    # 먼지 효과 업데이트 및 그리기
    effects_manager.update_dash_smoke()
    effects_manager.draw_dash_smoke(SCREEN)
    
    # 안내 텍스트
    font = pygame.font.Font(None, 24)
    text1 = font.render("Left Arrow: Left Dash | Right Arrow: Right Dash", True, WHITE)
    text2 = font.render("Space: Both Directions | Auto dust every 2 sec", True, WHITE)
    text3 = font.render(f"Dust particles: {len(effects_manager.dash_smoke_particles)}", True, WHITE)
    text4 = font.render("Fart cloud effect! Poof~", True, WHITE)
    SCREEN.blit(text1, (10, 10))
    SCREEN.blit(text2, (10, 35))
    SCREEN.blit(text3, (10, 60))
    SCREEN.blit(text4, (10, 85))
    
    pygame.display.flip()
    clock.tick(60)

pygame.quit()