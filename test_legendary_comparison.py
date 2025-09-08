#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""전설 아이템 비교 테스트 - 라그나로크 해머와 헤르메스 신발"""

import pygame
import sys
import os

# 경로 설정
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from legendary_items import LegendaryItemManager

def main():
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("전설 아이템 비교 - Ragnarok Hammer vs Hermes Shoes")
    clock = pygame.time.Clock()
    
    # 배경색
    BG_COLOR = (30, 30, 40)
    
    # 전설 아이템 매니저 초기화
    legendary_manager = LegendaryItemManager()
    legendary_manager._init_legendary_items()
    
    # 아이템 가져오기
    ragnarok_hammer = legendary_manager.get_item("ragnarok_hammer")
    hermes_shoes = legendary_manager.get_item("hermes_shoes")
    
    # 폰트 설정
    font = pygame.font.Font(None, 36)
    small_font = pygame.font.Font(None, 24)
    
    # 프레임 인덱스
    frame_index = 0
    frame_timer = 0
    FRAME_DELAY = 100  # 100ms per frame
    
    running = True
    while running:
        dt = clock.tick(60)
        frame_timer += dt
        
        # 프레임 업데이트
        if frame_timer >= FRAME_DELAY:
            frame_timer = 0
            frame_index = (frame_index + 1) % 8
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
        
        # 화면 클리어
        screen.fill(BG_COLOR)
        
        # 제목
        title = font.render("Legendary Items Comparison", True, (255, 255, 255))
        screen.blit(title, (screen.get_width()//2 - title.get_width()//2, 20))
        
        # 구분선
        pygame.draw.line(screen, (100, 100, 100), (50, 80), (750, 80), 2)
        
        # 라그나로크 해머 섹션
        hammer_label = small_font.render("Ragnarok Hammer (PNG Files)", True, (255, 200, 200))
        screen.blit(hammer_label, (150, 120))
        
        # 라그나로크 해머 프레임들 표시
        for i in range(8):
            x = 100 + i * 80
            y = 160
            
            # 프레임 배경
            if i == frame_index:
                pygame.draw.rect(screen, (80, 80, 100), (x-5, y-5, 70, 70))
            else:
                pygame.draw.rect(screen, (50, 50, 60), (x-5, y-5, 70, 70))
            
            # 프레임 그리기
            if ragnarok_hammer and ragnarok_hammer.animation_frames and i < len(ragnarok_hammer.animation_frames):
                frame = ragnarok_hammer.animation_frames[i]
                # 크기 조정 (32x32 -> 60x60)
                scaled_frame = pygame.transform.scale(frame, (60, 60))
                screen.blit(scaled_frame, (x, y))
            
            # 프레임 번호
            num_text = small_font.render(str(i), True, (150, 150, 150))
            screen.blit(num_text, (x + 25, y + 75))
        
        # 구분선
        pygame.draw.line(screen, (100, 100, 100), (50, 280), (750, 280), 2)
        
        # 헤르메스 신발 섹션
        shoes_label = small_font.render("Hermes Shoes (Generated)", True, (255, 215, 100))
        screen.blit(shoes_label, (150, 320))
        
        # 헤르메스 신발 프레임들 표시
        for i in range(8):
            x = 100 + i * 80
            y = 360
            
            # 프레임 배경
            if i == frame_index:
                pygame.draw.rect(screen, (80, 80, 100), (x-5, y-5, 70, 70))
            else:
                pygame.draw.rect(screen, (50, 50, 60), (x-5, y-5, 70, 70))
            
            # 프레임 그리기
            if hermes_shoes and hermes_shoes.animation_frames and i < len(hermes_shoes.animation_frames):
                frame = hermes_shoes.animation_frames[i]
                # 크기 조정 (32x32 -> 60x60)
                scaled_frame = pygame.transform.scale(frame, (60, 60))
                screen.blit(scaled_frame, (x, y))
            
            # 프레임 번호
            num_text = small_font.render(str(i), True, (150, 150, 150))
            screen.blit(num_text, (x + 25, y + 475))
        
        # 현재 프레임 표시
        current_text = small_font.render(f"Current Frame: {frame_index}", True, (200, 200, 200))
        screen.blit(current_text, (350, 520))
        
        # 안내 텍스트
        info_text = small_font.render("ESC to exit | Frames update automatically", True, (150, 150, 150))
        screen.blit(info_text, (250, 560))
        
        pygame.display.flip()
    
    pygame.quit()
    return 0

if __name__ == "__main__":
    sys.exit(main())