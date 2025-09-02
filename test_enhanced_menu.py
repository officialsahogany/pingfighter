#!/usr/bin/env python3
"""
향상된 메뉴 배경 테스트
회전하는 고리와 고급 파티클 효과 확인
"""

import pygame
import sys
from ui.enhanced_menu_background import EnhancedMenuBackground

def main():
    # Pygame 초기화
    pygame.init()
    
    # 화면 설정
    WIDTH = 600
    HEIGHT = 750
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Enhanced Menu Background Test - Rotating Rings")
    
    # 시계
    clock = pygame.time.Clock()
    
    # 향상된 배경 생성
    background = EnhancedMenuBackground(WIDTH, HEIGHT)
    
    # 폰트 설정
    try:
        font = pygame.font.Font("NeoDGM.ttf", 24)
        title_font = pygame.font.Font("NeoDGM.ttf", 36)
    except:
        font = pygame.font.Font(None, 24)
        title_font = pygame.font.Font(None, 36)
    
    # 메인 루프
    running = True
    dt = 0
    
    while running:
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
        
        # 업데이트
        background.update(dt)
        
        # 그리기
        background.draw(screen)
        
        # UI 오버레이
        # 제목
        title_text = title_font.render("PINGFIGHTER", True, (100, 255, 255))
        title_rect = title_text.get_rect(center=(WIDTH // 2, 100))
        
        # 제목 배경
        title_bg = pygame.Surface((title_rect.width + 40, title_rect.height + 20), pygame.SRCALPHA)
        pygame.draw.rect(title_bg, (0, 0, 0, 100), title_bg.get_rect(), border_radius=10)
        screen.blit(title_bg, (title_rect.x - 20, title_rect.y - 10))
        
        screen.blit(title_text, title_rect)
        
        # 서브타이틀
        subtitle_text = font.render("CYBERPUNK PONG BATTLE", True, (255, 100, 255))
        subtitle_rect = subtitle_text.get_rect(center=(WIDTH // 2, 140))
        screen.blit(subtitle_text, subtitle_rect)
        
        # 정보 텍스트
        info_texts = [
            "Enhanced Particle Effects",
            "Rotating Planetary Rings",
            "15+ Particle Systems",
            "Press ESC to exit"
        ]
        
        y_offset = HEIGHT - 150
        for text in info_texts:
            text_surface = font.render(text, True, (200, 200, 255))
            text_rect = text_surface.get_rect(center=(WIDTH // 2, y_offset))
            screen.blit(text_surface, text_rect)
            y_offset += 30
        
        # FPS 표시
        fps_text = font.render(f"FPS: {int(clock.get_fps())}", True, (255, 255, 255))
        screen.blit(fps_text, (10, 10))
        
        # 화면 업데이트
        pygame.display.flip()
        dt = clock.tick(60) / 1000.0  # 60 FPS 제한
    
    # 종료
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()