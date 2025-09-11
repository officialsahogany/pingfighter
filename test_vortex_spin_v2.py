#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""포세이돈 삼지창 회오리 회전 효과 테스트"""

import pygame
import sys
import os
import math
import random

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
pygame.display.set_caption("포세이돈 삼지창 - 회오리 회전 효과 테스트")

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
BLUE = (0, 100, 255)
GREEN = (0, 255, 0)
YELLOW = (255, 255, 0)
CYAN = (0, 255, 255)
MAGENTA = (255, 0, 255)

# 시계
clock = pygame.time.Clock()

# 포세이돈 삼지창 생성
trident = PoseidonTrident()
trident.active = True

# 공 속성
ball = {
    'x': 300,
    'y': 100,
    'vx': 0,
    'vy': 10,  # 보스가 친 공 (아래로)
    'radius': 8,
    'trail': []  # 공 궤적
}

# 패들 속성
player = {
    'x': 300,
    'y': 600,
    'width': 100,
    'height': 15
}

# 폰트
font = pygame.font.Font(None, 24)
small_font = pygame.font.Font(None, 18)

# 게임 상태
game_state = {
    'vortex_triggered': False,
    'frame_count': 0,
    'test_phase': 'waiting',  # waiting, spinning, deflected
    'original_speed': 10
}

def draw_info(screen, trident, ball, game_state):
    """정보 표시"""
    info_texts = [
        f"FPS: {int(clock.get_fps())}",
        f"Ball Position: ({ball['x']:.0f}, {ball['y']:.0f})",
        f"Ball Velocity: ({ball['vx']:.1f}, {ball['vy']:.1f})",
        f"Ball Speed: {math.sqrt(ball['vx']**2 + ball['vy']**2):.1f}",
        "",
        f"Vortex Active: {trident.vortex_active}",
        f"Vortex Timer: {trident.vortex_timer}/78",
        f"Ball in Vortex: {trident.ball_in_vortex}",
        f"Vortex Capture Timer: {trident.ball_vortex_timer}/{trident.ball_capture_duration}",
        f"Test Phase: {game_state['test_phase']}",
        "",
        "SPACE: 회오리 발동",
        "R: 리셋"
    ]
    
    y_offset = 10
    for text in info_texts:
        if text:
            text_surface = small_font.render(text, True, BLACK)
            screen.blit(text_surface, (10, y_offset))
        y_offset += 20

def reset_test():
    """테스트 리셋"""
    ball['x'] = 300
    ball['y'] = 100
    ball['vx'] = 0
    ball['vy'] = 10
    ball['trail'] = []
    
    trident.vortex_active = False
    trident.vortex_timer = 0
    trident.ball_in_vortex = False
    trident.ball_vortex_timer = 0
    
    game_state['vortex_triggered'] = False
    game_state['frame_count'] = 0
    game_state['test_phase'] = 'waiting'

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
                trident.trigger_dash_wave(player['x'], player['y'])
                game_state['vortex_triggered'] = True
                game_state['test_phase'] = 'waiting'
                print("\n=== 회오리 발동! ===")
            elif event.key == pygame.K_r:
                # 리셋
                reset_test()
                print("\n=== 테스트 리셋 ===")
    
    # 삼지창 업데이트
    trident.update(dt)
    
    # 공 물리 업데이트
    if not trident.ball_in_vortex:
        # 일반 물리
        ball['x'] += ball['vx'] * dt * 60
        ball['y'] += ball['vy'] * dt * 60
        
        # 회오리 효과 적용
        new_vx, new_vy = trident.apply_dash_wave_to_ball(
            ball['x'], ball['y'], ball['vx'], ball['vy'],
            player['x'], player['y']
        )
        
        # 속도 변화 감지
        if (new_vx != ball['vx'] or new_vy != ball['vy']):
            if trident.ball_in_vortex:
                print(f"공이 회오리에 캡처됨! 위치: ({ball['x']:.0f}, {ball['y']:.0f})")
                game_state['test_phase'] = 'spinning'
            ball['vx'] = new_vx
            ball['vy'] = new_vy
    else:
        # 회오리에 캡처된 상태 - apply_dash_wave_to_ball이 위치 업데이트를 처리
        new_vx, new_vy = trident.apply_dash_wave_to_ball(
            ball['x'], ball['y'], ball['vx'], ball['vy'],
            player['x'], player['y']
        )
        ball['vx'] = new_vx
        ball['vy'] = new_vy
        
        # 캡처 해제 감지
        if not trident.ball_in_vortex and game_state['test_phase'] == 'spinning':
            print(f"공이 회오리에서 튕겨남! 새 속도: ({ball['vx']:.1f}, {ball['vy']:.1f})")
            game_state['test_phase'] = 'deflected'
    
    # 공 궤적 추가
    ball['trail'].append((ball['x'], ball['y']))
    if len(ball['trail']) > 100:
        ball['trail'].pop(0)
    
    # 벽 충돌
    if ball['x'] <= ball['radius'] or ball['x'] >= SCREEN_WIDTH - ball['radius']:
        ball['vx'] = -ball['vx']
        ball['x'] = max(ball['radius'], min(SCREEN_WIDTH - ball['radius'], ball['x']))
    
    # 화면 벗어남 체크
    if ball['y'] < -50 or ball['y'] > SCREEN_HEIGHT + 50:
        reset_test()
        print("공이 화면을 벗어남 - 리셋")
    
    # 화면 그리기
    screen.fill(WHITE)
    
    # 회오리 영역 표시 (디버그용)
    if trident.vortex_active:
        # 왼쪽 회오리 영역
        left_rect = pygame.Rect(
            trident.vortex_left_x - 70,
            trident.vortex_left_y - trident.vortex_left_height,
            140,
            trident.vortex_left_height
        )
        pygame.draw.rect(screen, (200, 200, 255, 50), left_rect, 2)
        pygame.draw.circle(screen, BLUE, 
                         (int(trident.vortex_left_x), int(trident.vortex_left_y)), 
                         70, 1)
        
        # 오른쪽 회오리 영역
        right_rect = pygame.Rect(
            trident.vortex_right_x - 70,
            trident.vortex_right_y - trident.vortex_right_height,
            140,
            trident.vortex_right_height
        )
        pygame.draw.rect(screen, (200, 200, 255, 50), right_rect, 2)
        pygame.draw.circle(screen, BLUE,
                          (int(trident.vortex_right_x), int(trident.vortex_right_y)),
                          70, 1)
    
    # 회오리 효과 그리기
    trident.draw_effects(screen)
    
    # 공 궤적 그리기
    for i in range(1, len(ball['trail'])):
        alpha = int(255 * (i / len(ball['trail'])))
        color = (255, 100, 100, alpha) if game_state['test_phase'] == 'spinning' else (100, 100, 255, alpha)
        pygame.draw.line(screen, color[:3], ball['trail'][i-1], ball['trail'][i], 2)
    
    # 공 그리기
    if trident.ball_in_vortex:
        # 회전 중인 공은 노란색
        pygame.draw.circle(screen, YELLOW, (int(ball['x']), int(ball['y'])), ball['radius'])
        pygame.draw.circle(screen, RED, (int(ball['x']), int(ball['y'])), ball['radius'], 2)
    else:
        # 일반 공
        pygame.draw.circle(screen, RED, (int(ball['x']), int(ball['y'])), ball['radius'])
    
    # 패들 그리기
    pygame.draw.rect(screen, GREEN, 
                    (player['x'] - player['width']//2, 
                     player['y'] - player['height']//2,
                     player['width'], player['height']))
    
    # 정보 표시
    draw_info(screen, trident, ball, game_state)
    
    # 화면 업데이트
    pygame.display.flip()
    game_state['frame_count'] += 1

pygame.quit()