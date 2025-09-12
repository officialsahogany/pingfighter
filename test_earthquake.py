#!/usr/bin/env python3
"""
Stage 2 정글지진 효과 테스트
공이 제대로 흔들리는지 확인
"""

import pygame
import random
import math
import sys
import os

# 게임 설정
WINDOW_WIDTH = 1024
WINDOW_HEIGHT = 768
FPS = 60
BALL_BASE_SPEED = 5.0

# 색상
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
YELLOW = (255, 255, 0)

# 초기화
pygame.init()
screen = pygame.display.set_mode((WINDOW_WIDTH, WINDOW_HEIGHT))
pygame.display.set_caption("Earthquake Effect Test")
clock = pygame.time.Clock()
font = pygame.font.Font(None, 36)
small_font = pygame.font.Font(None, 24)

# 게임 상태
ball = pygame.Rect(WINDOW_WIDTH // 2 - 8, WINDOW_HEIGHT // 2 - 8, 16, 16)
ball_vel = [BALL_BASE_SPEED, BALL_BASE_SPEED]
quake_active = False
quake_timer = 0
original_ball_speed = [BALL_BASE_SPEED, BALL_BASE_SPEED]
shake_trail = []  # 흔들림 궤적 저장

def activate_quake():
    """지진 효과 활성화"""
    global quake_active, quake_timer, original_ball_speed
    quake_active = True
    quake_timer = 180  # 3초 (60 FPS)
    original_ball_speed = ball_vel.copy()
    print(f"Earthquake activated! Original speed: {original_ball_speed}")

def handle_quake_old():
    """구버전 지진 처리 (축별 클램프) - 버그 재현용"""
    global quake_active, quake_timer, ball_vel
    if quake_active:
        if quake_timer > 0:
            quake_timer -= 1
            # 흔들림 효과
            shake_x = random.uniform(-3, 3)
            shake_y = random.uniform(-2, 2)
            ball_vel[0] += shake_x
            ball_vel[1] += shake_y
            # 속도 제한 (축별 클램프 - 버그의 원인)
            ball_vel[0] = max(-8, min(8, ball_vel[0]))
            ball_vel[1] = max(-8, min(8, ball_vel[1]))
        else:
            # 효과 종료
            quake_active = False
            ball_vel = original_ball_speed.copy()

def handle_quake_new():
    """신버전 지진 처리 (벡터 크기 기반 클램프) - 수정된 버전"""
    global quake_active, quake_timer, ball_vel
    if quake_active:
        if quake_timer > 0:
            quake_timer -= 1
            # 흔들림 효과
            shake_x = random.uniform(-3, 3)
            shake_y = random.uniform(-2, 2)
            ball_vel[0] += shake_x
            ball_vel[1] += shake_y
            
            # 속도 제한 (벡터 크기 기반)
            max_speed = 8.0
            cur_speed = math.hypot(ball_vel[0], ball_vel[1])
            if cur_speed > max_speed:
                scale = max_speed / cur_speed
                ball_vel[0] *= scale
                ball_vel[1] *= scale
        else:
            # 효과 종료
            quake_active = False
            ball_vel = original_ball_speed.copy()

# 테스트 모드 선택
use_new_version = True  # True: 수정된 버전, False: 버그가 있는 구버전

def main():
    global ball_vel, quake_active, use_new_version, shake_trail
    
    running = True
    while running:
        dt = clock.tick(FPS) / 1000.0
        
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE:
                    # 스페이스바로 지진 활성화
                    activate_quake()
                    shake_trail.clear()
                elif event.key == pygame.K_v:
                    # V키로 버전 전환
                    use_new_version = not use_new_version
                    print(f"Switched to {'NEW' if use_new_version else 'OLD'} version")
                elif event.key == pygame.K_r:
                    # R키로 리셋
                    ball.center = (WINDOW_WIDTH // 2, WINDOW_HEIGHT // 2)
                    ball_vel = [BALL_BASE_SPEED, BALL_BASE_SPEED]
                    quake_active = False
                    shake_trail.clear()
                elif event.key == pygame.K_f:
                    # F키로 빠른 공 테스트
                    ball_vel = [7.5, 7.5]
                    print(f"Fast ball mode: {ball_vel}")
        
        # 지진 효과 처리
        if use_new_version:
            handle_quake_new()
        else:
            handle_quake_old()
        
        # 공 이동
        ball.x += ball_vel[0]
        ball.y += ball_vel[1]
        
        # 벽 충돌
        if ball.left <= 0 or ball.right >= WINDOW_WIDTH:
            ball_vel[0] = -ball_vel[0]
            ball.x = max(0, min(WINDOW_WIDTH - ball.width, ball.x))
        if ball.top <= 0 or ball.bottom >= WINDOW_HEIGHT:
            ball_vel[1] = -ball_vel[1]
            ball.y = max(0, min(WINDOW_HEIGHT - ball.height, ball.y))
        
        # 흔들림 궤적 기록 (지진 중일 때만)
        if quake_active:
            shake_trail.append((ball.centerx, ball.centery))
            if len(shake_trail) > 30:  # 최대 30개 점만 유지
                shake_trail.pop(0)
        
        # 화면 그리기
        screen.fill(BLACK)
        
        # 흔들림 궤적 그리기
        if len(shake_trail) > 1:
            for i in range(len(shake_trail) - 1):
                alpha = int(255 * (i / len(shake_trail)))
                color = (alpha, alpha // 2, 0)
                pygame.draw.line(screen, color, shake_trail[i], shake_trail[i + 1], 2)
        
        # 공 그리기
        color = YELLOW if quake_active else WHITE
        pygame.draw.circle(screen, color, ball.center, 8)
        
        # 지진 효과 시각화
        if quake_active:
            # 화면 테두리 효과
            pygame.draw.rect(screen, RED, (0, 0, WINDOW_WIDTH, WINDOW_HEIGHT), 3)
            # 지진 타이머 표시
            timer_text = font.render(f"EARTHQUAKE! {quake_timer // 60 + 1}s", True, RED)
            screen.blit(timer_text, (WINDOW_WIDTH // 2 - timer_text.get_width() // 2, 50))
        
        # 정보 표시
        version_text = small_font.render(f"Version: {'NEW (Fixed)' if use_new_version else 'OLD (Buggy)'}", True, GREEN if use_new_version else RED)
        screen.blit(version_text, (10, 10))
        
        speed = math.hypot(ball_vel[0], ball_vel[1])
        speed_text = small_font.render(f"Speed: {speed:.2f} (X:{ball_vel[0]:.2f}, Y:{ball_vel[1]:.2f})", True, WHITE)
        screen.blit(speed_text, (10, 40))
        
        # 조작법 표시
        controls = [
            "SPACE: Activate Earthquake",
            "V: Switch Version (Old/New)",
            "F: Fast Ball Mode",
            "R: Reset",
            "ESC: Exit"
        ]
        for i, text in enumerate(controls):
            control_text = small_font.render(text, True, WHITE)
            screen.blit(control_text, (10, WINDOW_HEIGHT - 150 + i * 25))
        
        # 버그 설명
        if not use_new_version:
            bug_text = small_font.render("BUG: Ball goes straight when fast due to axis clamping", True, RED)
            screen.blit(bug_text, (WINDOW_WIDTH // 2 - bug_text.get_width() // 2, 100))
        else:
            fix_text = small_font.render("FIXED: Vector magnitude clamping preserves shaking", True, GREEN)
            screen.blit(fix_text, (WINDOW_WIDTH // 2 - fix_text.get_width() // 2, 100))
        
        pygame.display.flip()
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()