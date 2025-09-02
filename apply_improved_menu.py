#!/usr/bin/env python3
"""
PingFighter 픽셀 폰트 적용 예제
레트로 스타일 메뉴 데모
"""

import pygame
import sys
import math
import random
from pixel_font_manager import (
    get_font, FontStyle, PixelColors, 
    render_pixel_text, render_shadow_text
)

pygame.init()

WIDTH, HEIGHT = 600, 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("🎮 PingFighter - 픽셀 폰트 적용")

def apply_pixel_fonts_to_game():
    """
    게임에 픽셀 폰트를 적용하는 방법을 보여주는 함수
    """
    print("\n" + "="*60)
    print("🎮 PingFighter 픽셀 폰트 적용 가이드")
    print("="*60)
    
    print("\n1️⃣ Import 추가 (pingfighter.py 상단):")
    print("-" * 40)
    print("from pixel_font_manager import get_font, FontStyle, PixelColors")
    
    print("\n2️⃣ 메인 폰트 변경 (Line 481-483):")
    print("-" * 40)
    print("# 변경 전:")
    print("FONT = pygame.font.Font('NanumSquareR.ttf', 40)")
    print("\n# 변경 후:")
    print("FONT = get_font(40)  # 자동으로 픽셀 폰트 사용")
    
    print("\n3️⃣ 타이틀 폰트 변경 (Line 1501-1502):")
    print("-" * 40)
    print("# 변경 전:")
    print("font_large = pygame.font.Font('NanumSquareB.ttf', 64)")
    print("\n# 변경 후:")
    print("font_large = FontStyle.title_large()")
    
    print("\n4️⃣ 점수 폰트 변경 (Line 2375):")
    print("-" * 40)
    print("# 변경 전:")
    print("font = pygame.font.Font('NanumSquareB.ttf', 26)")
    print("\n# 변경 후:")
    print("font = FontStyle.score()")
    
    print("\n5️⃣ 슬롯머신 폰트 (이미 수정됨 ✅):")
    print("-" * 40)
    print("Lines 5109-5132: NeoDunggeunmoPro.ttf 사용 중")
    
    print("\n✅ 현재 상태:")
    print("-" * 40)
    print("• 픽셀 폰트 다운로드 완료 (NeoDunggeunmoPro.ttf)")
    print("• pixel_font_manager.py 모듈 생성 완료")
    print("• IndentationError 수정 완료 (Lines 5107-5132)")
    print("• 테스트 스크립트 작성 완료")
    
    print("\n📝 다음 단계:")
    print("-" * 40)
    print("1. python test_pixel_fonts.py 로 테스트")
    print("2. pingfighter.py 백업")
    print("3. 위 변경사항 적용")
    print("4. 게임 실행 테스트")
    
    print("\n" + "="*60 + "\n")

def demo_retro_menu():
    """간단한 레트로 메뉴 데모"""
    clock = pygame.time.Clock()
    running = True
    selected = 0
    menu_items = ["게임 시작", "아카데미", "옵션", "나가기"]
    animation_time = 0
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_UP:
                    selected = (selected - 1) % len(menu_items)
                elif event.key == pygame.K_DOWN:
                    selected = (selected + 1) % len(menu_items)
                elif event.key == pygame.K_RETURN:
                    print(f"선택: {menu_items[selected]}")
                    if selected == 3:
                        running = False
        
        # 배경
        screen.fill((10, 10, 20))
        
        # 타이틀
        render_shadow_text(screen, "PINGFIGHTER", 
                         (WIDTH // 2, 100), 
                         64, PixelColors.RETRO_GREEN, 
                         PixelColors.BLACK, 3)
        
        render_pixel_text(screen, "핑파이터", 
                        (WIDTH // 2, 160), 
                        32, PixelColors.RETRO_AMBER, center=True)
        
        # 메뉴
        for i, item in enumerate(menu_items):
            y_pos = 300 + i * 60
            if i == selected:
                # 선택된 아이템
                wave = math.sin(animation_time * 5) * 5
                render_pixel_text(screen, "▶", 
                                (WIDTH // 2 - 100 + wave, y_pos), 
                                32, PixelColors.YELLOW)
                render_shadow_text(screen, item, 
                                 (WIDTH // 2, y_pos), 
                                 32, PixelColors.YELLOW, 
                                 PixelColors.BLACK, 2)
            else:
                render_pixel_text(screen, item, 
                                (WIDTH // 2, y_pos), 
                                28, PixelColors.WHITE, center=True)
        
        # 안내
        render_pixel_text(screen, "↑↓ 선택  ENTER 확인  ESC 나가기", 
                        (WIDTH // 2, HEIGHT - 80), 
                        20, PixelColors.RETRO_CYAN, center=True)
        
        pygame.display.flip()
        clock.tick(60)
        animation_time += clock.get_rawtime() / 1000.0
    
    pygame.quit()

if __name__ == "__main__":
    # 가이드 출력
    apply_pixel_fonts_to_game()
    
    # 데모 실행 옵션
    response = input("레트로 메뉴 데모를 실행하시겠습니까? (y/n): ")
    if response.lower() == 'y':
        demo_retro_menu()
    
    sys.exit()