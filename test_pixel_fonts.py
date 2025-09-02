#!/usr/bin/env python3
"""
픽셀 폰트 시스템 테스트 및 데모
모든 폰트 스타일과 기능을 확인합니다
"""

import pygame
import sys
from pixel_font_manager import (
    get_font, FontStyle, PixelColors, 
    render_pixel_text, render_blinking_text, 
    render_shadow_text, toggle_pixel_font, check_fonts
)

pygame.init()

# 화면 설정
WIDTH, HEIGHT = 800, 700
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("🎮 PingFighter 픽셀 폰트 시스템 테스트")

# 배경색
BG_COLOR = (20, 20, 30)

def draw_test_screen(screen, clock_ticks):
    """테스트 화면 그리기"""
    screen.fill(BG_COLOR)
    
    # 타이틀
    render_shadow_text(screen, "PingFighter 핑파이터", (WIDTH//2, 50), 
                      48, PixelColors.RETRO_GREEN, offset=3)
    
    # 다양한 스타일 테스트
    y_offset = 120
    
    # 1. 제목 스타일들
    render_pixel_text(screen, "[ 제목 스타일 ]", (WIDTH//2, y_offset), 
                     24, PixelColors.YELLOW, center=True)
    y_offset += 40
    
    title_font = FontStyle.title()
    text = title_font.render("Stage 6 - BOSS BATTLE", True, PixelColors.RED)
    rect = text.get_rect(center=(WIDTH//2, y_offset))
    screen.blit(text, rect)
    y_offset += 50
    
    # 2. 메뉴 스타일
    render_pixel_text(screen, "[ 메뉴 스타일 ]", (WIDTH//2, y_offset), 
                     24, PixelColors.YELLOW, center=True)
    y_offset += 40
    
    menu_items = ["게임 시작", "옵션", "나가기"]
    for i, item in enumerate(menu_items):
        color = PixelColors.RETRO_CYAN if i == (clock_ticks // 500) % 3 else PixelColors.WHITE
        render_pixel_text(screen, f"▶ {item}", (WIDTH//2 - 60, y_offset), 
                         28, color)
        y_offset += 35
    
    y_offset += 20
    
    # 3. 점수 표시
    render_pixel_text(screen, "[ 점수 시스템 ]", (WIDTH//2, y_offset), 
                     24, PixelColors.YELLOW, center=True)
    y_offset += 40
    
    score_font = FontStyle.score()
    score_text = score_font.render("SCORE: 999,999", True, PixelColors.SCORE)
    score_rect = score_text.get_rect(center=(WIDTH//2, y_offset))
    screen.blit(score_text, score_rect)
    y_offset += 50
    
    # 4. 아이템 획득 메시지
    render_pixel_text(screen, "[ 아이템 메시지 ]", (WIDTH//2, y_offset), 
                     24, PixelColors.YELLOW, center=True)
    y_offset += 40
    
    render_blinking_text(screen, "⚡ POWER UP! ⚡", (WIDTH//2, y_offset), 
                        32, PixelColors.WHITE, PixelColors.RETRO_PINK, speed=300)
    y_offset += 50
    
    # 5. 게이지 텍스트
    render_pixel_text(screen, "[ 게이지 표시 ]", (WIDTH//2, y_offset), 
                     24, PixelColors.YELLOW, center=True)
    y_offset += 40
    
    gauge_font = FontStyle.gauge()
    gauge_text = gauge_font.render("HP: ████████░░ 80%", True, PixelColors.HEALTH)
    gauge_rect = gauge_text.get_rect(center=(WIDTH//2, y_offset))
    screen.blit(gauge_text, gauge_rect)
    y_offset += 30
    
    # 6. 작은 텍스트
    tiny_font = FontStyle.tiny()
    tiny_text = tiny_font.render("Press SPACE to toggle pixel font", True, PixelColors.RETRO_AMBER)
    tiny_rect = tiny_text.get_rect(center=(WIDTH//2, HEIGHT - 50))
    screen.blit(tiny_text, tiny_rect)
    
    # 7. 특수 효과 텍스트
    if (clock_ticks // 1000) % 2 == 0:
        render_shadow_text(screen, "GAME OVER", (WIDTH//2, HEIGHT - 120), 
                          48, PixelColors.RED, PixelColors.BLACK, offset=4)

def main():
    clock = pygame.time.Clock()
    running = True
    clock_ticks = 0
    
    # 폰트 체크
    print("\n" + "="*50)
    print("🎮 PingFighter 픽셀 폰트 시스템 테스트")
    print("="*50)
    check_fonts()
    print("="*50 + "\n")
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 픽셀 폰트 토글
                    is_pixel = toggle_pixel_font()
                    mode = "픽셀 폰트" if is_pixel else "기본 폰트"
                    print(f"📱 모드 전환: {mode}")
        
        # 화면 그리기
        draw_test_screen(screen, clock_ticks)
        
        # FPS 표시
        fps = int(clock.get_fps())
        fps_text = f"FPS: {fps}"
        render_pixel_text(screen, fps_text, (WIDTH - 80, 20), 
                         16, PixelColors.RETRO_GREEN)
        
        pygame.display.flip()
        clock.tick(60)
        clock_ticks += clock.get_rawtime()
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()