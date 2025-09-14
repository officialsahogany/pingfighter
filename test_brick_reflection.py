#!/usr/bin/env python3
"""
벽돌 반사 테스트 스크립트
백업 파일의 간단한 반사 로직이 제대로 작동하는지 확인
"""

import pygame
import sys
import os
import math

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Initialize Pygame
pygame.init()
WIDTH, HEIGHT = 800, 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("벽돌 반사 테스트")
clock = pygame.time.Clock()

# Colors
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
BROWN = (139, 69, 19)
YELLOW = (255, 255, 0)
GRAY = (128, 128, 128)

# Ball properties
ball_pos = [WIDTH // 2, HEIGHT - 200]
ball_vel = [5, -8]  # 오른쪽 위로 발사
ball_radius = 8
BALL = pygame.Rect(ball_pos[0] - ball_radius, ball_pos[1] - ball_radius, ball_radius * 2, ball_radius * 2)

# Walls
walls = []
# 벽돌 여러 개 배치
for i in range(5):
    wall = {
        "rect": pygame.Rect(150 + i * 120, 200, 80, 30),
        "hit_count": 0,
        "crack_level": 0
    }
    walls.append(wall)

# 추가 벽돌 행
for i in range(4):
    wall = {
        "rect": pygame.Rect(210 + i * 120, 280, 80, 30),
        "hit_count": 0,
        "crack_level": 0
    }
    walls.append(wall)

def draw_scene():
    """화면 그리기"""
    screen.fill(BLACK)
    
    # Draw walls
    for wall in walls:
        color = BROWN
        if wall["crack_level"] == 1:
            color = (109, 49, 9)  # Darker brown for cracked
        pygame.draw.rect(screen, color, wall["rect"])
        pygame.draw.rect(screen, WHITE, wall["rect"], 2)
        
        # 히트 카운트 표시
        font = pygame.font.Font(None, 20)
        text = font.render(f"{wall['hit_count']}/2", True, WHITE)
        text_rect = text.get_rect(center=wall["rect"].center)
        screen.blit(text, text_rect)
    
    # Draw ball
    pygame.draw.circle(screen, YELLOW, (int(ball_pos[0]), int(ball_pos[1])), ball_radius)
    pygame.draw.circle(screen, WHITE, (int(ball_pos[0]), int(ball_pos[1])), ball_radius, 1)
    
    # Draw velocity vector
    end_x = ball_pos[0] + ball_vel[0] * 5
    end_y = ball_pos[1] + ball_vel[1] * 5
    pygame.draw.line(screen, GREEN, ball_pos, (end_x, end_y), 2)
    
    # Info text
    font = pygame.font.Font(None, 36)
    vel_text = font.render(f"속도: ({ball_vel[0]:.1f}, {ball_vel[1]:.1f})", True, WHITE)
    screen.blit(vel_text, (10, 10))
    
    wall_text = font.render(f"남은 벽돌: {len(walls)}", True, WHITE)
    screen.blit(wall_text, (10, 50))
    
    instruction_text = font.render("스페이스: 리셋, ESC: 종료", True, GREEN)
    screen.blit(instruction_text, (10, HEIGHT - 40))
    
    pygame.display.flip()

def update_physics():
    """물리 업데이트 (백업 파일의 반사 로직 사용)"""
    global ball_pos, ball_vel, walls, BALL
    
    # Update ball position
    ball_pos[0] += ball_vel[0]
    ball_pos[1] += ball_vel[1]
    
    # Update BALL rect
    BALL.x = ball_pos[0] - ball_radius
    BALL.y = ball_pos[1] - ball_radius
    
    # 벽돌 충돌 검사 (백업 파일의 로직)
    for wall in walls[:]:  # 리스트 복사본으로 순회
        if BALL.colliderect(wall["rect"]):
            # 벽돌에 맞은 횟수 증가
            wall["hit_count"] += 1
            wall["crack_level"] = wall["hit_count"]
            
            # 공 튕기기 (백업 파일의 간단한 방식)
            ball_vel[1] = -abs(ball_vel[1])  # 위로 튕기기
            ball_vel[0] *= 0.8  # 좌우 속도 감소
            
            print(f"벽돌 타격! ({wall['hit_count']}/2), 새 속도: ({ball_vel[0]:.1f}, {ball_vel[1]:.1f})")
            
            # 벽돌 파괴
            if wall["hit_count"] >= 2:
                walls.remove(wall)
                print("벽돌 파괴!")
            
            break  # 한 번에 하나의 벽돌만 처리
    
    # 화면 경계 충돌
    if ball_pos[0] - ball_radius <= 0 or ball_pos[0] + ball_radius >= WIDTH:
        ball_vel[0] = -ball_vel[0]
        ball_pos[0] = max(ball_radius, min(WIDTH - ball_radius, ball_pos[0]))
    
    if ball_pos[1] - ball_radius <= 0:
        ball_vel[1] = -ball_vel[1]
        ball_pos[1] = ball_radius
    
    # 아래로 떨어지면 리셋
    if ball_pos[1] > HEIGHT:
        reset_ball()

def reset_ball():
    """공 위치 리셋"""
    global ball_pos, ball_vel
    ball_pos = [WIDTH // 2, HEIGHT - 200]
    ball_vel = [5, -8]

# Main loop
running = True
while running:
    dt = clock.tick(60) / 1000.0
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                reset_ball()
                # 벽돌 리셋
                walls.clear()
                for i in range(5):
                    wall = {
                        "rect": pygame.Rect(150 + i * 120, 200, 80, 30),
                        "hit_count": 0,
                        "crack_level": 0
                    }
                    walls.append(wall)
                for i in range(4):
                    wall = {
                        "rect": pygame.Rect(210 + i * 120, 280, 80, 30),
                        "hit_count": 0,
                        "crack_level": 0
                    }
                    walls.append(wall)
    
    update_physics()
    draw_scene()

pygame.quit()
print("\n벽돌 반사 테스트 완료!")