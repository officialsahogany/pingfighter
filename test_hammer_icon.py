"""
라그나로크 해머 아이콘 테스트
아이템 관리창과 패시브 탭에서 동일한 이미지가 표시되는지 확인
"""

import pygame
import sys
import os

# 게임 경로 추가
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from legendary_items import RagnarokHammer

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("라그나로크 해머 아이콘 테스트")
clock = pygame.time.Clock()

# 폰트
font = pygame.font.Font(None, 24)
small_font = pygame.font.Font(None, 18)

# 라그나로크 해머 인스턴스 생성
hammer = RagnarokHammer()
hammer.active = True

# 테스트용 변수
frame_counter = 0

running = True
while running:
    dt = clock.tick(60)
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
    
    # 배경
    screen.fill((30, 30, 50))
    
    # 제목
    title = font.render("Ragnarok Hammer Icon Test", True, (255, 255, 255))
    screen.blit(title, (250, 30))
    
    # 해머 업데이트
    hammer.update(dt)
    
    # 1. 아이템 관리창 스타일 (전설 탭)
    label1 = small_font.render("Item Manager (Legend Tab)", True, (200, 200, 200))
    screen.blit(label1, (100, 100))
    
    # 아이템 관리창 배경
    item_size = 60
    x, y = 100, 130
    item_rect = pygame.Rect(x, y, item_size, item_size)
    pygame.draw.rect(screen, (60, 60, 80), item_rect)
    pygame.draw.rect(screen, (255, 255, 255), item_rect, 2)
    
    # draw_icon 메서드 사용 (아이템 관리창 방식)
    hammer.draw_icon(screen, x + 5, y + 5, item_size - 10)
    
    # 2. 패시브 탭 스타일
    label2 = small_font.render("In-Game Passive Tab", True, (200, 200, 200))
    screen.blit(label2, (300, 100))
    
    # 패시브 탭 배경
    icon_size = 45
    icon_x, icon_y = 300, 130
    pygame.draw.rect(screen, (50, 50, 70), (icon_x - 5, icon_y - 5, icon_size + 10, icon_size + 10))
    
    # draw_icon 메서드 사용 (패시브 탭 방식)
    hammer.draw_icon(screen, icon_x, icon_y, icon_size)
    
    # 3. 원본 크기 (참고용)
    label3 = small_font.render("Original Size (32x32)", True, (200, 200, 200))
    screen.blit(label3, (500, 100))
    
    hammer.draw_icon(screen, 500, 130, 32)
    
    # 프레임 정보
    info_text = f"Animation Frames: {len(hammer.animation_frames)}"
    info_text2 = f"Current Frame: {hammer.current_frame}"
    info_text3 = f"Frame Counter: {hammer.frame_counter}"
    
    info_surface = small_font.render(info_text, True, (150, 200, 150))
    info_surface2 = small_font.render(info_text2, True, (150, 200, 150))
    info_surface3 = small_font.render(info_text3, True, (150, 200, 150))
    
    screen.blit(info_surface, (100, 250))
    screen.blit(info_surface2, (100, 270))
    screen.blit(info_surface3, (100, 290))
    
    # 모든 프레임 표시 (디버깅용)
    if hammer.animation_frames:
        label4 = small_font.render("All Frames:", True, (200, 200, 200))
        screen.blit(label4, (100, 350))
        
        for i, frame in enumerate(hammer.animation_frames):
            frame_x = 100 + i * 40
            frame_y = 380
            scaled_frame = pygame.transform.scale(frame, (32, 32))
            screen.blit(scaled_frame, (frame_x, frame_y))
            
            # 현재 프레임 표시
            if i == hammer.current_frame:
                pygame.draw.rect(screen, (255, 100, 100), (frame_x - 2, frame_y - 2, 36, 36), 2)
    
    # 설명
    desc = small_font.render("Both should show the same animated hammer icon", True, (200, 200, 100))
    screen.blit(desc, (200, 500))
    
    pygame.display.flip()
    frame_counter += 1

pygame.quit()
print("\n테스트 완료!")