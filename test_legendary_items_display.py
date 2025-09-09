"""
전설 아이템 표시 테스트
라그나로크 해머와 헤르메스의 신발 비교
"""

import pygame
import os
import sys

# 리소스 경로 함수
def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

pygame.init()

# 화면 설정
SCREEN_WIDTH = 800
SCREEN_HEIGHT = 400
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("전설 아이템 디스플레이 - 라그나로크 해머 vs 헤르메스의 신발")

# 색상
BG_COLOR = (30, 30, 40)
TEXT_COLOR = (255, 255, 255)
LEGENDARY_RED = (255, 50, 50)

# 폰트
font_large = pygame.font.Font(None, 36)
font_medium = pygame.font.Font(None, 24)
font_small = pygame.font.Font(None, 18)

# 아이템 프레임 로드
ragnarok_frames = []
hermes_frames = []

for i in range(8):
    # 라그나로크 해머
    rag_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
    if os.path.exists(rag_path):
        ragnarok_frames.append(pygame.image.load(rag_path))
    
    # 헤르메스의 신발
    hermes_path = resource_path(f"items/legendary/hermes_shoes_frame_{i}.png")
    if os.path.exists(hermes_path):
        hermes_frames.append(pygame.image.load(hermes_path))

# 애니메이션 변수
frame_index = 0
frame_counter = 0
animation_speed = 8

# 시계
clock = pygame.time.Clock()

# 메인 루프
running = True
show_grid = True
zoom_level = 4  # 확대 레벨

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                show_grid = not show_grid
            elif event.key == pygame.K_UP:
                zoom_level = min(8, zoom_level + 1)
            elif event.key == pygame.K_DOWN:
                zoom_level = max(1, zoom_level - 1)
    
    # 배경
    screen.fill(BG_COLOR)
    
    # 애니메이션 업데이트
    frame_counter += 1
    if frame_counter >= animation_speed:
        frame_counter = 0
        frame_index = (frame_index + 1) % 8
    
    # 타이틀
    title = font_large.render("LEGENDARY ITEMS", True, LEGENDARY_RED)
    title_rect = title.get_rect(center=(SCREEN_WIDTH // 2, 30))
    screen.blit(title, title_rect)
    
    # 왼쪽: 라그나로크 해머
    if ragnarok_frames:
        # 원본 크기
        screen.blit(ragnarok_frames[frame_index], (150, 100))
        
        # 확대 버전
        zoomed = pygame.transform.scale(ragnarok_frames[frame_index], 
                                       (32 * zoom_level, 32 * zoom_level))
        screen.blit(zoomed, (100, 150))
        
        # 텍스트
        name1 = font_medium.render("RAGNAROK HAMMER", True, TEXT_COLOR)
        screen.blit(name1, (80, 70))
        
        desc1 = font_small.render("Massive Knockback & Stun", True, (200, 200, 200))
        screen.blit(desc1, (80, 350))
    
    # 오른쪽: 헤르메스의 신발
    if hermes_frames:
        # 원본 크기
        screen.blit(hermes_frames[frame_index], (550, 100))
        
        # 확대 버전
        zoomed = pygame.transform.scale(hermes_frames[frame_index], 
                                       (32 * zoom_level, 32 * zoom_level))
        screen.blit(zoomed, (500, 150))
        
        # 텍스트
        name2 = font_medium.render("HERMES SHOES", True, TEXT_COLOR)
        screen.blit(name2, (490, 70))
        
        desc2 = font_small.render("Speed & Half-Dash", True, (200, 200, 200))
        screen.blit(desc2, (490, 350))
    
    # 중앙 구분선
    pygame.draw.line(screen, (100, 100, 100), 
                    (SCREEN_WIDTH // 2, 60), 
                    (SCREEN_WIDTH // 2, SCREEN_HEIGHT - 20), 2)
    
    # VS 텍스트
    vs = font_large.render("VS", True, TEXT_COLOR)
    vs_rect = vs.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2))
    screen.blit(vs, vs_rect)
    
    # 그리드 (옵션)
    if show_grid and (ragnarok_frames or hermes_frames):
        # 라그나로크 그리드
        grid_x = 100
        grid_y = 150
        for i in range(32 * zoom_level + 1):
            if i % zoom_level == 0:
                # 주요 그리드 라인
                pygame.draw.line(screen, (60, 60, 60), 
                               (grid_x + i, grid_y), 
                               (grid_x + i, grid_y + 32 * zoom_level), 1)
                pygame.draw.line(screen, (60, 60, 60), 
                               (grid_x, grid_y + i), 
                               (grid_x + 32 * zoom_level, grid_y + i), 1)
        
        # 헤르메스 그리드
        grid_x = 500
        for i in range(32 * zoom_level + 1):
            if i % zoom_level == 0:
                pygame.draw.line(screen, (60, 60, 60), 
                               (grid_x + i, grid_y), 
                               (grid_x + i, grid_y + 32 * zoom_level), 1)
                pygame.draw.line(screen, (60, 60, 60), 
                               (grid_x, grid_y + i), 
                               (grid_x + 32 * zoom_level, grid_y + i), 1)
    
    # 정보
    info = font_small.render(f"Frame: {frame_index + 1}/8 | Zoom: {zoom_level}x | [SPACE] Grid | [↑↓] Zoom", 
                            True, (150, 150, 150))
    screen.blit(info, (SCREEN_WIDTH // 2 - 200, SCREEN_HEIGHT - 30))
    
    pygame.display.flip()
    clock.tick(60)

pygame.quit()
print("전설 아이템 표시 테스트 종료")