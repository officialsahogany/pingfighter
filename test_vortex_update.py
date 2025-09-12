#!/usr/bin/env python3
"""포세이돈 삼지창 수평 왕복 버그 수정 검증 테스트"""

import pygame
import math
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from legendary_items import PoseidonTrident

pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("Vortex Horizontal Oscillation Test")
clock = pygame.time.Clock()

# 색상
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
BLUE = (0, 100, 255)
GREEN = (0, 255, 0)
YELLOW = (255, 255, 0)
ORANGE = (255, 165, 0)

# 포세이돈 삼지창
trident = PoseidonTrident()
trident.active = True

# 테스트 케이스들
test_cases = [
    {"name": "수직 하강", "x": 400, "y": 100, "vx": 0, "vy": 10},
    {"name": "대각선 하강", "x": 350, "y": 100, "vx": 3, "vy": 8},
    {"name": "거의 수평", "x": 300, "y": 350, "vx": 8, "vy": 1},
    {"name": "완전 수평", "x": 250, "y": 400, "vx": 10, "vy": 0},
    {"name": "수평 상승", "x": 450, "y": 450, "vx": 7, "vy": -2},
]

current_test = 0
ball_x = test_cases[0]["x"]
ball_y = test_cases[0]["y"]
ball_vel_x = test_cases[0]["vx"]
ball_vel_y = test_cases[0]["vy"]
ball_radius = 10

paddle_x = 400
paddle_y = 500

# 수평 왕복 감지
horizontal_oscillation_count = 0
last_vx_sign = 0
oscillation_detected = False

# 통계
stats = {
    "frames_in_vortex": 0,
    "horizontal_frames": 0,
    "upward_frames": 0,
    "downward_frames": 0,
    "max_horizontal_speed": 0,
    "min_vertical_speed": 100,
}

messages = []

def add_message(msg, color=WHITE):
    messages.append({"text": msg, "color": color, "time": 60})
    print(msg)

def reset_test(index):
    global ball_x, ball_y, ball_vel_x, ball_vel_y, current_test
    global horizontal_oscillation_count, last_vx_sign, oscillation_detected, stats
    
    current_test = index % len(test_cases)
    test = test_cases[current_test]
    ball_x = test["x"]
    ball_y = test["y"]
    ball_vel_x = test["vx"]
    ball_vel_y = test["vy"]
    
    horizontal_oscillation_count = 0
    last_vx_sign = 0
    oscillation_detected = False
    stats = {
        "frames_in_vortex": 0,
        "horizontal_frames": 0,
        "upward_frames": 0,
        "downward_frames": 0,
        "max_horizontal_speed": 0,
        "min_vertical_speed": 100,
    }
    
    add_message(f"테스트 {current_test+1}: {test['name']}", GREEN)

running = True
frame_count = 0
auto_test_timer = 0

while running:
    dt = clock.tick(60) / 1000.0
    frame_count += 1
    auto_test_timer += 1
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                trident.trigger_dash_wave(paddle_x, paddle_y)
                add_message("대시 웨이브 발동!", BLUE)
            elif event.key == pygame.K_1:
                reset_test(0)
            elif event.key == pygame.K_2:
                reset_test(1)
            elif event.key == pygame.K_3:
                reset_test(2)
            elif event.key == pygame.K_4:
                reset_test(3)
            elif event.key == pygame.K_5:
                reset_test(4)
            elif event.key == pygame.K_n:
                reset_test(current_test + 1)
            elif event.key == pygame.K_r:
                reset_test(current_test)
    
    # 자동 테스트 (5초마다 대시 웨이브 발동)
    if auto_test_timer >= 300:
        trident.trigger_dash_wave(paddle_x, paddle_y)
        add_message("자동 대시 웨이브!", BLUE)
        auto_test_timer = 0
    
    # 물리 업데이트
    old_vx, old_vy = ball_vel_x, ball_vel_y
    trident.update(dt)
    
    new_vel_x, new_vel_y = trident.apply_dash_wave_to_ball(
        ball_x, ball_y, ball_vel_x, ball_vel_y, 0, paddle_y
    )
    
    # 통계 수집
    if trident.ball_in_vortex:
        stats["frames_in_vortex"] += 1
        
        if abs(new_vel_y) < 1:
            stats["horizontal_frames"] += 1
        if new_vel_y < 0:
            stats["upward_frames"] += 1
        elif new_vel_y > 0:
            stats["downward_frames"] += 1
            
        stats["max_horizontal_speed"] = max(stats["max_horizontal_speed"], abs(new_vel_x))
        stats["min_vertical_speed"] = min(stats["min_vertical_speed"], abs(new_vel_y))
    
    # 수평 왕복 감지
    if trident.ball_in_vortex:
        vx_sign = 1 if new_vel_x > 0 else -1 if new_vel_x < 0 else 0
        if vx_sign != 0 and last_vx_sign != 0 and vx_sign != last_vx_sign:
            horizontal_oscillation_count += 1
            if horizontal_oscillation_count >= 3 and not oscillation_detected:
                add_message("⚠️ 수평 왕복 패턴 감지!", RED)
                oscillation_detected = True
        last_vx_sign = vx_sign
    
    # 속도 업데이트
    ball_vel_x = new_vel_x
    ball_vel_y = new_vel_y
    ball_x += ball_vel_x
    ball_y += ball_vel_y
    
    # 경계 처리
    if ball_x < ball_radius or ball_x > 800 - ball_radius:
        ball_vel_x = -ball_vel_x
        ball_x = max(ball_radius, min(800 - ball_radius, ball_x))
    
    if ball_y < ball_radius:
        ball_vel_y = abs(ball_vel_y)
        ball_y = ball_radius
    elif ball_y > 600 - ball_radius:
        add_message("공이 바닥에 닿음", ORANGE)
        reset_test(current_test)
    
    # 화면 그리기
    screen.fill(BLACK)
    
    # 회오리 그리기
    if trident.vortex_timer > 0:
        for vortex in trident.vortex_positions:
            if vortex:
                vx, vy = vortex
                height = min(trident.vortex_timer * 8, 300)
                width = min(trident.vortex_timer * 5, 150)
                
                vortex_surf = pygame.Surface((width, height), pygame.SRCALPHA)
                vortex_surf.fill((0, 100, 255, 100))
                screen.blit(vortex_surf, (vx - width//2, vy - height))
                
                # 중심 표시
                pygame.draw.circle(screen, YELLOW, (int(vx), int(vy - height//2)), 5)
    
    # 패들
    pygame.draw.rect(screen, WHITE, (paddle_x - 50, paddle_y - 5, 100, 10))
    
    # 공
    color = GREEN if ball_vel_y < 0 else RED if ball_vel_y > 0 else YELLOW
    pygame.draw.circle(screen, color, (int(ball_x), int(ball_y)), ball_radius)
    
    # 속도 벡터
    pygame.draw.line(screen, WHITE,
                     (int(ball_x), int(ball_y)),
                     (int(ball_x + ball_vel_x * 3), int(ball_y + ball_vel_y * 3)), 2)
    
    # 정보 표시
    font = pygame.font.Font(None, 20)
    info = [
        f"테스트 {current_test+1}/{len(test_cases)}: {test_cases[current_test]['name']}",
        f"위치: ({ball_x:.0f}, {ball_y:.0f})",
        f"속도: ({ball_vel_x:.1f}, {ball_vel_y:.1f})",
        f"회오리 캡처: {trident.ball_in_vortex}",
        f"",
        f"통계:",
        f"  회오리 프레임: {stats['frames_in_vortex']}",
        f"  수평 프레임: {stats['horizontal_frames']}",
        f"  상향 프레임: {stats['upward_frames']}",
        f"  하향 프레임: {stats['downward_frames']}",
        f"  수평 왕복: {horizontal_oscillation_count}회",
        f"",
        f"조작: SPACE(웨이브) 1-5(테스트) N(다음) R(리셋)",
    ]
    
    for i, text in enumerate(info):
        surf = font.render(text, True, WHITE)
        screen.blit(surf, (10, 10 + i * 22))
    
    # 경고 표시
    if oscillation_detected:
        warning = font.render("⚠️ 수평 왕복 버그 발생!", True, RED)
        screen.blit(warning, (300, 10))
    
    # 메시지 표시
    for i, msg in enumerate(messages[-5:]):
        surf = font.render(msg["text"], True, msg["color"])
        screen.blit(surf, (10, 450 + i * 22))
    
    # 메시지 타이머 감소
    messages[:] = [m for m in messages if m["time"] > 0]
    for m in messages:
        m["time"] -= 1
    
    pygame.display.flip()

pygame.quit()