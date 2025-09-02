#!/usr/bin/env python3
"""
라운드 스코어 화면 테스트
네오둥근모 픽셀 폰트 적용 확인
"""

import pygame
import sys
from ui.hud_display import HUDDisplay

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 600, 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("🎮 라운드 스코어 테스트 - 네오둥근모 픽셀 폰트")

# 배경색
BG_COLOR = (20, 20, 30)

def draw_field():
    """배경 그리기"""
    screen.fill(BG_COLOR)
    # 간단한 배경 패턴
    for i in range(0, HEIGHT, 50):
        pygame.draw.line(screen, (40, 40, 50), (0, i), (WIDTH, i), 1)
    for i in range(0, WIDTH, 50):
        pygame.draw.line(screen, (40, 40, 50), (i, 0), (i, HEIGHT), 1)

def main():
    # HUD 디스플레이 초기화
    hud = HUDDisplay(screen, WIDTH, HEIGHT, draw_field, None)
    
    print("\n" + "="*60)
    print("🎮 라운드 스코어 화면 테스트")
    print("="*60)
    print("네오둥근모 픽셀 폰트가 적용된 스코어 화면을 표시합니다.")
    print("ESC 키를 눌러 종료하세요.")
    print("="*60 + "\n")
    
    # 테스트 점수
    player_score = 1
    boss_score = 2
    
    # 스코어 화면 표시
    hud.show_score(player_score, boss_score)
    
    # 메인 루프
    clock = pygame.time.Clock()
    running = True
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 스페이스바로 스코어 화면 다시 표시
                    hud.show_score(player_score, boss_score)
        
        # 배경 그리기
        draw_field()
        
        # 안내 텍스트
        from pixel_font_manager import FontStyle, render_pixel_text, PixelColors
        render_pixel_text(screen, "SPACE: 스코어 화면 표시", 
                        (WIDTH // 2, HEIGHT - 100), 
                        20, PixelColors.RETRO_CYAN, center=True)
        render_pixel_text(screen, "ESC: 종료", 
                        (WIDTH // 2, HEIGHT - 60), 
                        20, PixelColors.RETRO_AMBER, center=True)
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()