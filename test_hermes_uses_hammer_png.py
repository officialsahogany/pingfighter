#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""헤르메스의 신발이 라그나로크 해머 PNG를 사용하는지 확인"""

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
    pygame.display.set_caption("Hermes Shoes Using Ragnarok Hammer PNG")
    clock = pygame.time.Clock()
    
    # 배경색
    BG_COLOR = (30, 30, 40)
    
    # 폰트 설정
    font = pygame.font.Font(None, 24)
    small_font = pygame.font.Font(None, 18)
    
    # LegendaryItemManager 가져오기
    from legendary_items import get_legendary_manager
    
    # 매니저 초기화
    legendary_manager = get_legendary_manager()
    if not legendary_manager:
        print("LegendaryItemManager 초기화 실패!")
        return 1
    
    # 헤르메스의 신발 가져오기
    hermes = legendary_manager.get_item("hermes_shoes")
    if not hermes:
        print("헤르메스의 신발을 찾을 수 없음!")
        return 1
    
    print(f"헤르메스의 신발 프레임 개수: {len(hermes.animation_frames)}")
    
    # 라그나로크 해머 PNG 파일 직접 로드
    hammer_frames = []
    for i in range(8):
        frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
        try:
            frame = pygame.image.load(frame_path).convert_alpha()
            hammer_frames.append(frame)
            print(f"라그나로크 해머 프레임 {i} 로드 성공")
        except Exception as e:
            print(f"라그나로크 해머 프레임 {i} 로드 실패: {e}")
    
    # 프레임 비교
    frames_match = True
    if len(hermes.animation_frames) == len(hammer_frames):
        for i, (hermes_frame, hammer_frame) in enumerate(zip(hermes.animation_frames, hammer_frames)):
            # Surface 크기 비교
            if hermes_frame.get_size() != hammer_frame.get_size():
                print(f"프레임 {i} 크기 불일치: 헤르메스 {hermes_frame.get_size()} vs 해머 {hammer_frame.get_size()}")
                frames_match = False
            
            # 픽셀 데이터 비교 (샘플링)
            w, h = hermes_frame.get_size()
            for x in range(0, w, 4):  # 4픽셀마다 샘플링
                for y in range(0, h, 4):
                    hermes_pixel = hermes_frame.get_at((x, y))
                    hammer_pixel = hammer_frame.get_at((x, y))
                    if hermes_pixel != hammer_pixel:
                        frames_match = False
                        break
                if not frames_match:
                    break
    else:
        print(f"프레임 개수 불일치: 헤르메스 {len(hermes.animation_frames)} vs 해머 {len(hammer_frames)}")
        frames_match = False
    
    if frames_match:
        print("✅ 헤르메스의 신발이 라그나로크 해머 PNG를 정확히 사용하고 있습니다!")
    else:
        print("❌ 헤르메스의 신발과 라그나로크 해머 PNG가 다릅니다!")
    
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
        title = font.render("Hermes Shoes vs Ragnarok Hammer PNG", True, (255, 255, 255))
        screen.blit(title, (screen.get_width()//2 - title.get_width()//2, 20))
        
        # 상태 표시
        if frames_match:
            status = font.render("✅ IDENTICAL - Using Same PNG Files!", True, (100, 255, 100))
        else:
            status = font.render("❌ DIFFERENT - Not Using Same Files", True, (255, 100, 100))
        screen.blit(status, (screen.get_width()//2 - status.get_width()//2, 60))
        
        # 프레임 비교 표시
        if frame_index < len(hermes.animation_frames) and frame_index < len(hammer_frames):
            # 헤르메스의 신발 (왼쪽)
            hermes_frame = hermes.animation_frames[frame_index]
            
            # 원본 크기
            screen.blit(hermes_frame, (150, 150))
            label1 = small_font.render("Hermes Shoes", True, (200, 200, 200))
            screen.blit(label1, (140, 190))
            
            # 4x 확대
            hermes_4x = pygame.transform.scale(hermes_frame, (128, 128))
            screen.blit(hermes_4x, (100, 220))
            
            # 라그나로크 해머 PNG (오른쪽)
            hammer_frame = hammer_frames[frame_index]
            
            # 원본 크기
            screen.blit(hammer_frame, (450, 150))
            label2 = small_font.render("Ragnarok Hammer PNG", True, (200, 200, 200))
            screen.blit(label2, (410, 190))
            
            # 4x 확대
            hammer_4x = pygame.transform.scale(hammer_frame, (128, 128))
            screen.blit(hammer_4x, (400, 220))
            
            # 차이점 표시 (가운데)
            diff_surface = pygame.Surface((32, 32), pygame.SRCALPHA)
            for x in range(32):
                for y in range(32):
                    hermes_pixel = hermes_frame.get_at((x, y))
                    hammer_pixel = hammer_frame.get_at((x, y))
                    if hermes_pixel != hammer_pixel:
                        diff_surface.set_at((x, y), (255, 0, 0, 255))
                    else:
                        diff_surface.set_at((x, y), (0, 255, 0, 50))
            
            # 차이점 4x 확대
            diff_4x = pygame.transform.scale(diff_surface, (128, 128))
            screen.blit(diff_4x, (250, 380))
            label3 = small_font.render("Difference (Red=Different)", True, (200, 200, 200))
            screen.blit(label3, (235, 520))
        
        # 현재 프레임 정보
        info = small_font.render(f"Frame {frame_index}/7", True, (200, 200, 200))
        screen.blit(info, (350, 100))
        
        # 안내
        guide = small_font.render("SPACE: Next Frame | ESC: Exit", True, (150, 150, 150))
        screen.blit(guide, (300, 570))
        
        pygame.display.flip()
    
    pygame.quit()
    return 0

if __name__ == "__main__":
    sys.exit(main())