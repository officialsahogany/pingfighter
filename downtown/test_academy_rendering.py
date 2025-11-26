#!/usr/bin/env python3
"""
아카데미 건물 렌더링 테스트
BuildingRenderer를 사용하여 실제 게임에서 아카데미가 어떻게 보이는지 테스트
"""

import sys
import os
import pygame

# 프로젝트 루트를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from downtown.constants import *
from downtown.building_designs import BuildingRenderer

def test_academy_rendering():
    """아카데미 건물 렌더링 테스트"""
    pygame.init()
    
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("아카데미 건물 렌더링 테스트")
    
    clock = pygame.time.Clock()
    
    # BuildingRenderer 초기화
    renderer = BuildingRenderer()
    
    # 아카데미 건물 생성
    class Building:
        def __init__(self):
            self.type = BuildingType.ACADEMY
            self.x = SCREEN_WIDTH // 2 - 55
            self.y = SCREEN_HEIGHT // 2 - 50
            info = BUILDING_INFO[BuildingType.ACADEMY]
            self.width = info["pixel_size"][0]
            self.height = info["pixel_size"][1]
    
    academy = Building()
    
    # 건물 정보 출력
    print("\n" + "="*80)
    print("🏫 아카데미 건물 렌더링 테스트")
    print("="*80)
    print(f"\n건물 타입: {academy.type}")
    print(f"건물 크기: {academy.width} x {academy.height}")
    print(f"건물 위치: ({academy.x}, {academy.y})")
    print("\n테스트 창에서 아카데미 건물이 올바르게 렌더링되는지 확인하세요.")
    print("ESC 키를 눌러 종료하세요.\n")
    print("="*80 + "\n")
    
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
        
        # 배경
        screen.fill((20, 20, 30))
        
        # 아카데미 건물 그리기
        renderer.draw_building(screen, academy, camera_offset=(0, 0))
        
        # 안내 텍스트
        font = pygame.font.Font(None, 24)
        title = font.render("Academy Building Test", True, (255, 255, 255))
        screen.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, 20))
        
        info_font = pygame.font.Font(None, 18)
        info_text = info_font.render("Press ESC to exit", True, (150, 150, 150))
        screen.blit(info_text, (SCREEN_WIDTH // 2 - info_text.get_width() // 2, SCREEN_HEIGHT - 30))
        
        pygame.display.flip()
        clock.tick(60)
        
        # 애니메이션 타이머 업데이트
        renderer.animation_timer += 1 / 60
    
    pygame.quit()
    print("\n✅ 테스트 완료!\n")

if __name__ == "__main__":
    test_academy_rendering()
