#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""프레임 분석 테스트"""

import pygame
import sys
import os

# 경로 설정
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

def main():
    pygame.init()
    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("Frame Analysis - Raw PNG Content")
    clock = pygame.time.Clock()
    
    # 배경색
    BG_COLOR = (30, 30, 40)
    
    # 폰트 설정
    font = pygame.font.Font(None, 24)
    small_font = pygame.font.Font(None, 18)
    
    # 라그나로크 해머 프레임 로드
    hammer_frames = []
    for i in range(8):
        frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
        try:
            frame = pygame.image.load(frame_path).convert_alpha()
            hammer_frames.append(frame)
            print(f"로드됨: {frame_path} - 크기: {frame.get_size()}")
        except Exception as e:
            print(f"로드 실패: {frame_path} - {e}")
    
    # 프레임 인덱스
    frame_index = 0
    frame_timer = 0
    FRAME_DELAY = 200  # 200ms per frame
    
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
                elif event.key == pygame.K_SPACE:
                    frame_index = (frame_index + 1) % 8
        
        # 화면 클리어
        screen.fill(BG_COLOR)
        
        # 제목
        title = font.render("Ragnarok Hammer PNG Raw Content", True, (255, 255, 255))
        screen.blit(title, (screen.get_width()//2 - title.get_width()//2, 20))
        
        # 현재 프레임 정보
        info = small_font.render(f"Frame {frame_index}/7", True, (200, 200, 200))
        screen.blit(info, (350, 60))
        
        if hammer_frames and frame_index < len(hammer_frames):
            frame = hammer_frames[frame_index]
            
            # 원본 크기로 표시 (32x32)
            screen.blit(frame, (100, 100))
            label1 = small_font.render("Original (32x32)", True, (150, 150, 150))
            screen.blit(label1, (85, 140))
            
            # 2배 크기
            scaled_2x = pygame.transform.scale(frame, (64, 64))
            screen.blit(scaled_2x, (250, 100))
            label2 = small_font.render("2x (64x64)", True, (150, 150, 150))
            screen.blit(label2, (255, 170))
            
            # 4배 크기
            scaled_4x = pygame.transform.scale(frame, (128, 128))
            screen.blit(scaled_4x, (400, 100))
            label3 = small_font.render("4x (128x128)", True, (150, 150, 150))
            screen.blit(label3, (430, 240))
            
            # 8배 크기
            scaled_8x = pygame.transform.scale(frame, (256, 256))
            screen.blit(scaled_8x, (200, 280))
            label4 = small_font.render("8x (256x256)", True, (150, 150, 150))
            screen.blit(label4, (290, 550))
            
            # 프레임 정보
            size_info = small_font.render(f"Size: {frame.get_size()}", True, (200, 200, 200))
            screen.blit(size_info, (600, 100))
            
            # 알파 채널 정보
            has_alpha = frame.get_flags() & pygame.SRCALPHA
            alpha_info = small_font.render(f"Alpha: {'Yes' if has_alpha else 'No'}", True, (200, 200, 200))
            screen.blit(alpha_info, (600, 125))
        
        # 안내
        guide = small_font.render("SPACE: Next Frame | ESC: Exit", True, (150, 150, 150))
        screen.blit(guide, (300, 570))
        
        pygame.display.flip()
    
    pygame.quit()
    return 0

if __name__ == "__main__":
    sys.exit(main())