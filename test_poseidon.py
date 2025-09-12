#!/usr/bin/env python3
"""포세이돈의 삼지창 물 회오리 버그 수정 테스트"""

import pygame
import math
import sys
import os

# 게임 모듈 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from legendary_items import PoseidonTrident

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("Poseidon Trident Vortex Test")
clock = pygame.time.Clock()

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
BLUE = (0, 100, 255)
GREEN = (0, 255, 0)
YELLOW = (255, 255, 0)

# 포세이돈 삼지창 인스턴스
trident = PoseidonTrident()
trident.active = True

# 공 상태
ball_x = 400
ball_y = 100
ball_vel_x = 0
ball_vel_y = 5  # 아래로 떨어지는 공
ball_radius = 10

# 패들 위치 (물 회오리 생성 위치)
paddle_y = 500
paddle_x = 400

# 테스트 모드
test_mode = 0  # 0: 일반, 1: 빠른 하강, 2: 대각선
test_messages = []

def reset_ball(mode=0):
    """공을 초기 위치로 리셋"""
    global ball_x, ball_y, ball_vel_x, ball_vel_y, test_mode
    
    test_mode = mode
    
    if mode == 0:  # 일반 하강
        ball_x = 400
        ball_y = 100
        ball_vel_x = 0
        ball_vel_y = 5
    elif mode == 1:  # 빠른 하강
        ball_x = 400
        ball_y = 100
        ball_vel_x = 0
        ball_vel_y = 15
    elif mode == 2:  # 대각선 하강
        ball_x = 300
        ball_y = 100
        ball_vel_x = 3
        ball_vel_y = 8

def add_message(msg):
    """디버그 메시지 추가"""
    global test_messages
    test_messages.append(msg)
    if len(test_messages) > 10:
        test_messages.pop(0)
    print(msg)

# 메인 루프
running = True
frame_count = 0
space_pressed = False

while running:
    dt = clock.tick(60) / 1000.0  # 60 FPS
    frame_count += 1
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                # 대시 웨이브 발동
                if not space_pressed:
                    trident.trigger_dash_wave(paddle_x, paddle_y)
                    add_message(f"[Frame {frame_count}] 대시 웨이브 발동!")
                    space_pressed = True
            elif event.key == pygame.K_1:
                reset_ball(0)
                add_message("테스트 모드: 일반 하강")
            elif event.key == pygame.K_2:
                reset_ball(1)
                add_message("테스트 모드: 빠른 하강")
            elif event.key == pygame.K_3:
                reset_ball(2)
                add_message("테스트 모드: 대각선 하강")
            elif event.key == pygame.K_r:
                reset_ball(test_mode)
                add_message("공 위치 리셋")
        elif event.type == pygame.KEYUP:
            if event.key == pygame.K_SPACE:
                space_pressed = False
    
    # 이전 속도 저장
    old_vel_y = ball_vel_y
    
    # 포세이돈 삼지창 업데이트 및 물리 적용
    trident.update(dt)
    
    # 물 회오리 물리 적용
    new_vel_x, new_vel_y = trident.apply_dash_wave_to_ball(
        ball_x, ball_y, ball_vel_x, ball_vel_y, 0, paddle_y  # current_stage = 0, paddle_y 추가
    )
    
    # 속도 변화 감지
    if old_vel_y != new_vel_y:
        if new_vel_y > 0 and old_vel_y <= 0:
            add_message(f"[WARNING] 공이 아래로 방향 전환! vy: {old_vel_y:.1f} → {new_vel_y:.1f}")
        elif new_vel_y > old_vel_y and new_vel_y > 0:
            add_message(f"[WARNING] 하향 가속! vy: {old_vel_y:.1f} → {new_vel_y:.1f}")
        elif new_vel_y < 0:
            add_message(f"[OK] 상향 반사! vy: {old_vel_y:.1f} → {new_vel_y:.1f}")
    
    # 공 위치 업데이트
    ball_vel_x = new_vel_x
    ball_vel_y = new_vel_y
    ball_x += ball_vel_x
    ball_y += ball_vel_y
    
    # 화면 경계 처리
    if ball_x < ball_radius or ball_x > 800 - ball_radius:
        ball_vel_x = -ball_vel_x
        ball_x = max(ball_radius, min(800 - ball_radius, ball_x))
    
    if ball_y < ball_radius:
        ball_vel_y = abs(ball_vel_y)
        ball_y = ball_radius
    elif ball_y > 600 - ball_radius:
        # 바닥에 닿음 - 경고
        add_message(f"[FAIL] 공이 바닥에 닿음! (플레이어 패배 상황)")
        reset_ball(test_mode)
    
    # 화면 그리기
    screen.fill(BLACK)
    
    # 물 회오리 그리기
    if trident.vortex_timer > 0:
        for i, vortex in enumerate(trident.vortex_positions):
            if vortex is not None:
                vx, vy = vortex
                # 회오리 영역 표시
                height = min(trident.vortex_timer * 8, 300)
                width = min(trident.vortex_timer * 5, 150)
                
                # 회오리 영역 (반투명 파란색)
                vortex_surf = pygame.Surface((width, height), pygame.SRCALPHA)
                vortex_surf.fill((0, 100, 255, 100))
                screen.blit(vortex_surf, (vx - width//2, vy - height))
                
                # 회오리 중심선
                pygame.draw.line(screen, BLUE, (vx, vy), (vx, vy - height), 2)
                
                # 캡처 반경 표시
                capture_radius = min(width/2, 100) * 0.9
                pygame.draw.circle(screen, GREEN, (int(vx), int(vy - height//2)), 
                                 int(capture_radius), 1)
    
    # 패들 위치 표시
    pygame.draw.rect(screen, WHITE, (paddle_x - 50, paddle_y - 5, 100, 10))
    
    # 공 그리기
    color = RED if ball_vel_y > 0 else GREEN  # 하강 중이면 빨간색
    pygame.draw.circle(screen, color, (int(ball_x), int(ball_y)), ball_radius)
    
    # 속도 벡터 표시
    pygame.draw.line(screen, YELLOW, 
                     (int(ball_x), int(ball_y)),
                     (int(ball_x + ball_vel_x * 5), int(ball_y + ball_vel_y * 5)), 2)
    
    # 정보 표시
    font = pygame.font.Font(None, 24)
    info_texts = [
        f"FPS: {clock.get_fps():.1f}",
        f"Ball Pos: ({ball_x:.0f}, {ball_y:.0f})",
        f"Ball Vel: ({ball_vel_x:.1f}, {ball_vel_y:.1f})",
        f"Vortex Timer: {trident.vortex_timer}",
        f"In Vortex: {trident.ball_in_vortex}",
        "",
        "Controls:",
        "SPACE - Trigger Dash Wave",
        "1/2/3 - Test Modes",
        "R - Reset Ball",
    ]
    
    for i, text in enumerate(info_texts):
        surf = font.render(text, True, WHITE)
        screen.blit(surf, (10, 10 + i * 25))
    
    # 디버그 메시지 표시
    for i, msg in enumerate(test_messages):
        color = RED if "WARNING" in msg or "FAIL" in msg else WHITE
        color = GREEN if "OK" in msg else color
        surf = font.render(msg, True, color)
        screen.blit(surf, (10, 350 + i * 20))
    
    pygame.display.flip()

pygame.quit()