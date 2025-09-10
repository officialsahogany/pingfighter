#!/usr/bin/env python3
"""포세이돈의 삼지창 아이콘 테스트"""

import pygame
import sys
import os

# 게임 모듈 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from legendary_items import PoseidonTrident

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("포세이돈의 삼지창 아이콘 테스트")
clock = pygame.time.Clock()

# 포세이돈의 삼지창 인스턴스 생성
trident = PoseidonTrident()

# 배경색
BG_COLOR = (20, 30, 50)

# 메인 루프
running = True
frame_count = 0

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
    
    # 화면 클리어
    screen.fill(BG_COLOR)
    
    # 타이틀
    font = pygame.font.Font(None, 36)
    title = font.render("Poseidon's Trident Icon Test", True, (255, 255, 255))
    screen.blit(title, (250, 30))
    
    # 설명 텍스트
    font_small = pygame.font.Font(None, 24)
    desc = font_small.render("Custom trident shape with Ragnarok's effects", True, (200, 200, 200))
    screen.blit(desc, (230, 70))
    
    # 프레임별 아이콘 표시 (8개 프레임)
    if trident.icon_frames:
        # 현재 애니메이션 프레임 (큰 사이즈)
        current_frame_idx = (frame_count // 8) % len(trident.icon_frames)
        current_frame = trident.icon_frames[current_frame_idx]
        
        # 큰 아이콘 (중앙)
        big_size = 128
        scaled_frame = pygame.transform.scale(current_frame, (big_size, big_size))
        screen.blit(scaled_frame, (336, 150))
        
        # 아이콘 아래 프레임 번호
        frame_text = font_small.render(f"Frame {current_frame_idx + 1}/8", True, (255, 255, 200))
        screen.blit(frame_text, (360, 290))
        
        # 모든 프레임 미리보기 (하단)
        preview_y = 400
        preview_size = 64
        for i, frame in enumerate(trident.icon_frames):
            x = 100 + i * 80
            scaled = pygame.transform.scale(frame, (preview_size, preview_size))
            
            # 현재 프레임 하이라이트
            if i == current_frame_idx:
                pygame.draw.rect(screen, (255, 255, 100), (x-2, preview_y-2, preview_size+4, preview_size+4), 2)
            
            screen.blit(scaled, (x, preview_y))
            
            # 프레임 번호
            num_text = font_small.render(str(i+1), True, (150, 150, 150))
            screen.blit(num_text, (x + preview_size//2 - 5, preview_y + preview_size + 5))
    else:
        error_text = font.render("Failed to load icon frames!", True, (255, 100, 100))
        screen.blit(error_text, (250, 300))
    
    # draw_icon 메서드를 사용한 렌더링 테스트 (상단 좌우)
    trident.update(0.016)  # 60fps 업데이트
    
    # 왼쪽 아이콘
    trident.draw_icon(screen, 50, 150, 80)
    label_left = font_small.render("draw_icon()", True, (150, 150, 255))
    screen.blit(label_left, (50, 240))
    
    # 오른쪽 아이콘
    trident.draw_icon(screen, 670, 150, 80)
    label_right = font_small.render("with effects", True, (150, 150, 255))
    screen.blit(label_right, (670, 240))
    
    # 컨트롤 안내
    controls = font_small.render("Press ESC to exit", True, (100, 100, 100))
    screen.blit(controls, (340, 550))
    
    # 화면 업데이트
    pygame.display.flip()
    clock.tick(60)
    frame_count += 1

pygame.quit()
print("✓ 포세이돈의 삼지창 아이콘 테스트 완료")