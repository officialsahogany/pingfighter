#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
윈도우에서 라운드 전환 시 대시 상태 초기화 테스트
"""

import pygame
import sys
import time

# Initialize Pygame
pygame.init()

# Create a simple test window
WIDTH, HEIGHT = 800, 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("대시 라운드 전환 버그 테스트")
clock = pygame.time.Clock()

# Font for display
font = pygame.font.Font(None, 36)
small_font = pygame.font.Font(None, 24)

# Game state
round_num = 1
score = 0
dash_active = False
dash_timer = 0
dash_direction = 0
player_x = WIDTH // 2
player_y = HEIGHT - 100

# Test state
test_log = []

def add_log(message):
    """로그 추가"""
    global test_log
    test_log.append(f"[{pygame.time.get_ticks()}ms] {message}")
    if len(test_log) > 10:
        test_log.pop(0)
    print(message)

def reset_dash_state():
    """대시 상태 초기화 (수정된 버전)"""
    global dash_active, dash_timer, dash_direction
    
    # 대시 상태 초기화
    dash_active = False
    dash_timer = 0
    dash_direction = 0
    
    # 키 이벤트 큐 클리어 (중요!)
    pygame.event.clear(pygame.KEYDOWN)
    pygame.event.clear(pygame.KEYUP)
    pygame.key.set_repeat()  # 키 반복 리셋
    
    add_log("대시 상태 초기화 완료")

def simulate_round_end():
    """라운드 종료 시뮬레이션"""
    global round_num, score
    
    add_log(f"라운드 {round_num} 종료!")
    
    # 즉시 대시 상태 초기화
    reset_dash_state()
    
    # 라운드 증가
    round_num += 1
    score += 1
    
    # 플레이어 위치 리셋
    global player_x, player_y
    player_x = WIDTH // 2
    player_y = HEIGHT - 100
    
    add_log(f"라운드 {round_num} 시작!")

def main():
    global dash_active, dash_timer, dash_direction, player_x
    
    running = True
    test_mode = False
    
    while running:
        dt = clock.tick(60) / 1000.0  # Delta time in seconds
        
        # Event handling
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 라운드 종료 시뮬레이션
                    simulate_round_end()
                elif event.key == pygame.K_t:
                    # 테스트 모드 토글
                    test_mode = not test_mode
                    add_log(f"테스트 모드: {test_mode}")
                elif event.key == pygame.K_LEFT or event.key == pygame.K_RIGHT:
                    if not dash_active:
                        # 대시 시작
                        dash_active = True
                        dash_timer = 30  # 0.5초 (60fps 기준)
                        dash_direction = -1 if event.key == pygame.K_LEFT else 1
                        add_log(f"대시 시작! 방향: {dash_direction}")
        
        # Update dash
        if dash_active:
            if dash_timer > 0:
                # 대시 이동
                player_x += dash_direction * 10
                dash_timer -= 1
                
                # 화면 경계 체크
                player_x = max(50, min(WIDTH - 50, player_x))
            else:
                # 대시 종료
                dash_active = False
                dash_direction = 0
                add_log("대시 종료")
        
        # Test mode: 자동 라운드 종료
        if test_mode and dash_active and dash_timer == 5:
            add_log("테스트: 대시 중 라운드 종료 시뮬레이션!")
            simulate_round_end()
        
        # Clear screen
        screen.fill((20, 20, 30))
        
        # Draw player
        color = (255, 100, 100) if dash_active else (100, 100, 255)
        pygame.draw.circle(screen, color, (int(player_x), int(player_y)), 30)
        
        # Draw UI
        score_text = font.render(f"라운드: {round_num} | 점수: {score}", True, (255, 255, 255))
        screen.blit(score_text, (10, 10))
        
        status_text = small_font.render(
            f"대시: {'활성' if dash_active else '비활성'} | 타이머: {dash_timer} | 방향: {dash_direction}",
            True, (200, 200, 200)
        )
        screen.blit(status_text, (10, 50))
        
        # Instructions
        instructions = [
            "조작법:",
            "← → : 대시",
            "SPACE : 라운드 종료 시뮬레이션",
            "T : 테스트 모드 (대시 중 자동 라운드 종료)",
            "ESC : 종료"
        ]
        
        for i, text in enumerate(instructions):
            inst_text = small_font.render(text, True, (150, 150, 150))
            screen.blit(inst_text, (WIDTH - 300, 10 + i * 25))
        
        # Draw log
        log_y = HEIGHT - 200
        for log_entry in test_log:
            log_text = small_font.render(log_entry, True, (100, 255, 100))
            screen.blit(log_text, (10, log_y))
            log_y += 25
        
        # Update display
        pygame.display.flip()
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    add_log("윈도우 대시 버그 수정 테스트 시작")
    add_log("수정 내용: 라운드 종료 시 키 이벤트 큐 클리어")
    main()