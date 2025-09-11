#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""포세이돈 삼지창 - 보스 반격 시 속도 복원 테스트"""

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
pygame.display.set_caption("포세이돈 삼지창 - 보스 반격 속도 복원 테스트")

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
BLUE = (0, 100, 255)
GREEN = (0, 255, 0)
YELLOW = (255, 255, 0)
ORANGE = (255, 165, 0)

# 시계
clock = pygame.time.Clock()

# 포세이돈 삼지창 생성
trident = PoseidonTrident()
trident.active = True

# 공 속성
ball = {
    'rect': pygame.Rect(300, 400, 16, 16),
    'vel': [0, 10],  # 보스가 친 공 (아래로)
    'trail': [],
    'impact_boost': 1.0,
    'original_speed': 10,  # 원래 속도 저장
    'boss_hit': False  # 보스가 쳤는지 여부
}

# 패들 속성
player = {
    'rect': pygame.Rect(250, 600, 100, 15),
}

boss = {
    'rect': pygame.Rect(250, 50, 100, 15),
}

# 폰트
font = pygame.font.Font(None, 24)
small_font = pygame.font.Font(None, 18)

# 게임 상태
game_state = {
    'frame_count': 0,
    'vortex_triggered': False,
    'phase': 'waiting',  # waiting, vortex_active, deflected, boss_counter
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
        f"Ball Speed: {speed:.1f} (Original: {ball['original_speed']:.1f})",
        "",
        f"Phase: {game_state['phase']}",
        f"Vortex Active: {trident.vortex_active}",
        f"Ball in Vortex: {trident.ball_in_vortex}",
        f"Vortex Affected: {trident.vortex_affected}",
        f"Boss Hit: {ball['boss_hit']}",
        "",
        "SPACE: 회오리 발동",
        "B: 보스가 공을 침 (시뮬레이션)",
        "P: 플레이어가 공을 침 (시뮬레이션)",
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
    ball['rect'].center = (300, 400)
    ball['vel'] = [0, 10]
    ball['trail'] = []
    ball['impact_boost'] = 1.0
    ball['boss_hit'] = False
    
    trident.vortex_active = False
    trident.vortex_timer = 0
    trident.ball_in_vortex = False
    trident.ball_vortex_timer = 0
    trident.vortex_affected = False
    trident.original_ball_speed = 0
    
    game_state['vortex_triggered'] = False
    game_state['frame_count'] = 0
    game_state['phase'] = 'waiting'

def simulate_boss_hit():
    """보스가 공을 치는 시뮬레이션"""
    # 공을 아래로 향하게 함 (보스가 친 것처럼)
    current_speed = math.sqrt(ball['vel'][0]**2 + ball['vel'][1]**2)
    ball['vel'][0] = 0
    ball['vel'][1] = abs(current_speed)  # 아래로
    ball['boss_hit'] = True
    game_state['phase'] = 'boss_counter'
    print(f"\n=== 보스가 공을 침! 속도: {current_speed:.1f} ===")

def simulate_player_hit():
    """플레이어가 공을 치는 시뮬레이션"""
    # 공을 위로 향하게 함 (플레이어가 친 것처럼)
    current_speed = math.sqrt(ball['vel'][0]**2 + ball['vel'][1]**2)
    ball['vel'][0] = 0
    ball['vel'][1] = -abs(current_speed)  # 위로
    ball['boss_hit'] = False
    game_state['phase'] = 'player_shot'
    print(f"\n=== 플레이어가 공을 침! 속도: {current_speed:.1f} ===")

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
                game_state['vortex_triggered'] = True
                game_state['phase'] = 'vortex_active'
                print("\n=== 회오리 발동! ===")
            elif event.key == pygame.K_b:
                # 보스가 공을 치는 시뮬레이션
                simulate_boss_hit()
            elif event.key == pygame.K_p:
                # 플레이어가 공을 치는 시뮬레이션
                simulate_player_hit()
            elif event.key == pygame.K_r:
                # 리셋
                reset_test()
                print("\n=== 테스트 리셋 ===")
    
    # 삼지창 업데이트
    trident.update(dt)
    
    # 페이즈 업데이트
    if game_state['phase'] == 'vortex_active' and trident.vortex_affected:
        game_state['phase'] = 'deflected'
        print(f"공이 회오리에서 튕겨남! 속도: {math.sqrt(ball['vel'][0]**2 + ball['vel'][1]**2):.1f}")
    
    # 공 물리 업데이트 (실제 게임과 유사하게)
    # 실제 속도 계산
    actual_vel_x = ball['vel'][0] * ball['impact_boost']
    actual_vel_y = ball['vel'][1] * ball['impact_boost']
    
    # 여러 스텝으로 나누어 처리
    num_steps = game_state['num_steps']
    step_vel_x = actual_vel_x / num_steps
    step_vel_y = actual_vel_y / num_steps
    
    for step in range(num_steps):
        # 회오리 효과 적용
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
            
            # 속도 복원 감지
            if ball['boss_hit'] and not trident.vortex_affected:
                new_speed = math.sqrt(ball['vel'][0]**2 + ball['vel'][1]**2)
                print(f"속도 복원됨! {new_speed:.1f}")
                ball['boss_hit'] = False
                game_state['phase'] = 'speed_restored'
        
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
    
    # 화면 벗어남 체크
    if ball['rect'].bottom < 0 or ball['rect'].top > SCREEN_HEIGHT:
        reset_test()
        print("공이 화면을 벗어남 - 리셋")
    
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
        if game_state['phase'] == 'player_shot':
            color = (135, 206, 235)  # 플레이어가 친 공 (하늘색)
        elif game_state['phase'] == 'boss_counter':
            color = ORANGE  # 보스가 친 공
        elif trident.ball_in_vortex:
            color = YELLOW  # 회오리에 캡처된 공
        elif trident.vortex_affected:
            color = GREEN  # 회오리 효과를 받은 공
        else:
            color = BLUE  # 일반 공
        pygame.draw.line(screen, color, ball['trail'][i-1], ball['trail'][i], 2)
    
    # 공 그리기
    if trident.ball_in_vortex:
        pygame.draw.circle(screen, YELLOW, ball['rect'].center, 8)
        pygame.draw.circle(screen, RED, ball['rect'].center, 8, 2)
    elif ball['boss_hit']:
        pygame.draw.circle(screen, ORANGE, ball['rect'].center, 8)
    elif trident.vortex_affected:
        pygame.draw.circle(screen, GREEN, ball['rect'].center, 8)
    else:
        pygame.draw.circle(screen, RED, ball['rect'].center, 8)
    
    # 패들 그리기
    pygame.draw.rect(screen, GREEN, player['rect'])
    
    # 보스 패들 그리기
    pygame.draw.rect(screen, BLACK, boss['rect'])
    
    # 정보 표시
    draw_info(screen, trident, ball, game_state)
    
    # 화면 업데이트
    pygame.display.flip()
    game_state['frame_count'] += 1

pygame.quit()