#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""포세이돈 삼지창 회오리 버그 수정 테스트"""

import pygame
import sys
import os
import math

# 부모 디렉토리를 Python 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 모듈 임포트
from legendary_items import PoseidonTrident

# Pygame 초기화
pygame.init()

# 화면 설정
SCREEN_WIDTH = 600
SCREEN_HEIGHT = 700
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("포세이돈 삼지창 - 버그 수정 테스트")

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
BLUE = (0, 100, 255)
GREEN = (0, 255, 0)
YELLOW = (255, 255, 0)

# 시계
clock = pygame.time.Clock()

# 포세이돈 삼지창 생성
trident = PoseidonTrident()
trident.active = True

# 공 속성 (실제 게임과 유사하게)
ball = {
    'rect': pygame.Rect(300, 100, 16, 16),  # BALL 객체와 유사
    'vel': [0, 5],  # ball_vel과 유사 (느린 속도)
    'trail': [],
    'impact_boost': 1.0
}

# 패들 속성
player = {
    'rect': pygame.Rect(250, 600, 100, 15),
}

# 폰트
font = pygame.font.Font(None, 24)
small_font = pygame.font.Font(None, 18)

# 게임 상태
game_state = {
    'frame_count': 0,
    'ball_lost': False,
    'num_steps': 5  # 실제 게임처럼 여러 스텝으로 나누어 처리
}

def draw_info(screen, trident, ball, game_state):
    """정보 표시"""
    vel_x = ball['vel'][0] * ball['impact_boost']
    vel_y = ball['vel'][1] * ball['impact_boost']
    speed = math.sqrt(vel_x**2 + vel_y**2)
    
    info_texts = [
        f"FPS: {int(clock.get_fps())}",
        f"Ball Position: ({ball['rect'].centerx:.0f}, {ball['rect'].centery:.0f})",
        f"Ball Velocity: ({vel_x:.1f}, {vel_y:.1f})",
        f"Ball Speed: {speed:.1f}",
        "",
        f"Vortex Active: {trident.vortex_active}",
        f"Vortex Timer: {trident.vortex_timer}/78",
        f"Ball in Vortex: {trident.ball_in_vortex}",
        f"Ball Lost: {game_state['ball_lost']}",
        "",
        "SPACE: 회오리 발동",
        "R: 리셋",
        "↑↓: 공 속도 조절"
    ]
    
    y_offset = 10
    for text in info_texts:
        if text:
            text_surface = small_font.render(text, True, BLACK)
            screen.blit(text_surface, (10, y_offset))
        y_offset += 20

def reset_test():
    """테스트 리셋"""
    ball['rect'].center = (300, 100)
    ball['vel'] = [0, 5]
    ball['trail'] = []
    ball['impact_boost'] = 1.0
    
    trident.vortex_active = False
    trident.vortex_timer = 0
    trident.ball_in_vortex = False
    trident.ball_vortex_timer = 0
    
    game_state['ball_lost'] = False
    game_state['frame_count'] = 0

# 메인 루프
running = True
while running:
    dt = clock.tick(60) / 1000.0  # 60 FPS
    
    # 이벤트 처리
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE and not trident.vortex_active:
                # 회오리 발동
                trident.trigger_dash_wave(player['rect'].centerx, player['rect'].centery)
                print("\n=== 회오리 발동! ===")
            elif event.key == pygame.K_r:
                # 리셋
                reset_test()
                print("\n=== 테스트 리셋 ===")
            elif event.key == pygame.K_UP:
                ball['vel'][1] -= 1
                print(f"공 속도 증가: {ball['vel'][1]}")
            elif event.key == pygame.K_DOWN:
                ball['vel'][1] += 1
                print(f"공 속도 감소: {ball['vel'][1]}")
    
    # 삼지창 업데이트
    trident.update(dt)
    
    # 공 물리 업데이트 (실제 게임과 유사하게)
    if not game_state['ball_lost']:
        # 실제 속도 계산
        actual_vel_x = ball['vel'][0] * ball['impact_boost']
        actual_vel_y = ball['vel'][1] * ball['impact_boost']
        
        # 여러 스텝으로 나누어 처리
        num_steps = game_state['num_steps']
        step_vel_x = actual_vel_x / num_steps
        step_vel_y = actual_vel_y / num_steps
        
        for step in range(num_steps):
            # 회오리 효과 적용
            if trident.vortex_active or trident.ball_in_vortex:
                wave_vx, wave_vy = trident.apply_dash_wave_to_ball(
                    ball['rect'].centerx, ball['rect'].centery,
                    step_vel_x, step_vel_y,
                    player['rect'].centerx, player['rect'].centery,
                    player['rect'].centerx, player['rect'].centery
                )
                
                # 속도 변화 적용
                if wave_vx != step_vel_x or wave_vy != step_vel_y:
                    # 실제 게임처럼 ball_vel 업데이트
                    ball['vel'][0] = wave_vx * num_steps / ball['impact_boost']
                    ball['vel'][1] = wave_vy * num_steps / ball['impact_boost']
                    step_vel_x = wave_vx
                    step_vel_y = wave_vy
            
            # 한 스텝 이동
            ball['rect'].x += step_vel_x
            ball['rect'].y += step_vel_y
        
        # 공 궤적 추가
        ball['trail'].append(ball['rect'].center)
        if len(ball['trail']) > 100:
            ball['trail'].pop(0)
        
        # 벽 충돌
        if ball['rect'].left <= 0 or ball['rect'].right >= SCREEN_WIDTH:
            ball['vel'][0] = -ball['vel'][0]
            if ball['rect'].left <= 0:
                ball['rect'].left = 0
            else:
                ball['rect'].right = SCREEN_WIDTH
        
        # 화면 벗어남 체크 (승리/패배 조건)
        if ball['rect'].bottom < 0:
            print("⚡ 플레이어 승리! (공이 위로 나감)")
            game_state['ball_lost'] = True
        elif ball['rect'].top > SCREEN_HEIGHT:
            print("💀 플레이어 패배! (공이 아래로 나감)")
            game_state['ball_lost'] = True
    
    # 화면 그리기
    screen.fill(WHITE)
    
    # 회오리 영역 표시 (디버그용)
    if trident.vortex_active:
        # 왼쪽 회오리 영역
        pygame.draw.circle(screen, (200, 200, 255), 
                         (int(trident.vortex_left_x), int(trident.vortex_left_y)), 
                         70, 2)
        
        # 오른쪽 회오리 영역
        pygame.draw.circle(screen, (200, 200, 255),
                          (int(trident.vortex_right_x), int(trident.vortex_right_y)),
                          70, 2)
    
    # 회오리 효과 그리기
    trident.draw_effects(screen)
    
    # 공 궤적 그리기
    for i in range(1, len(ball['trail'])):
        alpha = int(255 * (i / len(ball['trail'])))
        color = YELLOW if trident.ball_in_vortex else BLUE
        pygame.draw.line(screen, color, ball['trail'][i-1], ball['trail'][i], 2)
    
    # 공 그리기
    if not game_state['ball_lost']:
        if trident.ball_in_vortex:
            pygame.draw.circle(screen, YELLOW, ball['rect'].center, 8)
            pygame.draw.circle(screen, RED, ball['rect'].center, 8, 2)
        else:
            pygame.draw.circle(screen, RED, ball['rect'].center, 8)
    
    # 패들 그리기
    pygame.draw.rect(screen, GREEN, player['rect'])
    
    # 정보 표시
    draw_info(screen, trident, ball, game_state)
    
    # 화면 업데이트
    pygame.display.flip()
    game_state['frame_count'] += 1

pygame.quit()