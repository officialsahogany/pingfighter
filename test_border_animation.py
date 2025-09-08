#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""테두리 애니메이션 테스트"""

import pygame
import sys
import os
import math

# 경로 설정
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from legendary_items import LegendaryItemManager, LEGENDARY_COLOR

def main():
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("Border Animation Test")
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
    
    # 애니메이션 시간
    animation_time = 0
    
    running = True
    while running:
        dt = clock.tick(60) / 1000.0  # 초 단위로 변환
        animation_time += dt * 1000  # 밀리초로 변환
        
        # 아이템 업데이트 (중요!)
        if ragnarok_hammer:
            ragnarok_hammer.update(dt * 1000)
        if hermes_shoes:
            hermes_shoes.update(dt * 1000)
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
        
        # 화면 클리어
        screen.fill(BG_COLOR)
        
        # 제목
        title = font.render("Border Animation Test", True, (255, 255, 255))
        screen.blit(title, (screen.get_width()//2 - title.get_width()//2, 20))
        
        # 라그나로크 해머
        hammer_label = small_font.render("Ragnarok Hammer", True, (255, 200, 200))
        screen.blit(hammer_label, (150, 100))
        
        if ragnarok_hammer:
            # 큰 아이콘
            ragnarok_hammer.draw_icon(screen, 100, 150, 120)
            # 중간 아이콘
            ragnarok_hammer.draw_icon(screen, 250, 170, 80)
            # 작은 아이콘 (기본 크기)
            ragnarok_hammer.draw_icon(screen, 350, 180, 60)
            
            # glow_intensity 표시
            glow_text = small_font.render(f"Glow: {ragnarok_hammer.glow_intensity:.2f}", True, (200, 200, 200))
            screen.blit(glow_text, (100, 290))
        
        # 구분선
        pygame.draw.line(screen, (100, 100, 100), (50, 320), (750, 320), 2)
        
        # 헤르메스 신발
        shoes_label = small_font.render("Hermes Shoes", True, (255, 215, 100))
        screen.blit(shoes_label, (150, 350))
        
        if hermes_shoes:
            # 큰 아이콘
            hermes_shoes.draw_icon(screen, 100, 400, 120)
            # 중간 아이콘
            hermes_shoes.draw_icon(screen, 250, 420, 80)
            # 작은 아이콘 (기본 크기)
            hermes_shoes.draw_icon(screen, 350, 430, 60)
            
            # glow_intensity 표시
            glow_text = small_font.render(f"Glow: {hermes_shoes.glow_intensity:.2f}", True, (200, 200, 200))
            screen.blit(glow_text, (100, 540))
        
        # 시간 표시
        time_text = small_font.render(f"Time: {animation_time/1000:.1f}s", True, (150, 150, 150))
        screen.blit(time_text, (650, 550))
        
        pygame.display.flip()
    
    pygame.quit()
    return 0

if __name__ == "__main__":
    sys.exit(main())