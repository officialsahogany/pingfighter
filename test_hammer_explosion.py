#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
발토르 해머쇼크 폭발 이펙트 테스트
"""

import pygame
import sys
import os

# 프로젝트 루트 디렉토리를 Python 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from hammer_explosion import get_hammer_explosion_manager

def test_hammer_explosion():
    """발토르 해머쇼크 폭발 이펙트 테스트"""
    
    # Pygame 초기화
    pygame.init()
    
    # 화면 설정
    WIDTH, HEIGHT = 800, 600
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("발토르 해머쇼크 폭발 이펙트 테스트")
    
    # 시계 설정
    clock = pygame.time.Clock()
    
    # 폭발 매니저 초기화
    explosion_manager = get_hammer_explosion_manager()
    
    # 배경색
    BLACK = (0, 0, 0)
    WHITE = (255, 255, 255)
    
    # 메시지 폰트
    try:
        font = pygame.font.Font(None, 36)
    except:
        font = pygame.font.Font(pygame.font.get_default_font(), 36)
    
    last_explosion_time = 0
    explosion_cooldown = 2000  # 2초마다 새 폭발
    
    print("발토르 해머쇼크 폭발 이펙트 테스트를 시작합니다!")
    print("마우스를 클릭하면 폭발 이펙트가 생성됩니다.")
    print("ESC 키를 누르면 종료합니다.")
    
    running = True
    while running:
        current_time = pygame.time.get_ticks()
        
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 스페이스바로 화면 중앙에 폭발 생성
                    explosion_manager.add_explosion(WIDTH // 2, HEIGHT // 2)
                    print("💥 화면 중앙에 폭발 생성!")
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:  # 왼쪽 마우스 버튼
                    mouse_x, mouse_y = pygame.mouse.get_pos()
                    explosion_manager.add_explosion(mouse_x, mouse_y)
                    print(f"💥 폭발 생성! 위치: ({mouse_x}, {mouse_y})")
        
        # 자동 폭발 생성 (2초마다)
        if current_time - last_explosion_time > explosion_cooldown:
            import random
            x = random.randint(100, WIDTH - 100)
            y = random.randint(100, HEIGHT - 100)
            explosion_manager.add_explosion(x, y)
            last_explosion_time = current_time
            print(f"🎆 자동 폭발! 위치: ({x}, {y})")
        
        # 화면 지우기
        screen.fill(BLACK)
        
        # 폭발 이펙트 업데이트
        explosion_manager.update()
        
        # 폭발 이펙트 그리기
        explosion_manager.draw(screen)
        
        # 활성 폭발 수 표시
        active_count = len(explosion_manager.explosions)
        if active_count > 0:
            text = font.render(f"활성 폭발: {active_count}개", True, WHITE)
            screen.blit(text, (10, 10))
        
        # 조작 안내
        guide_text = font.render("마우스 클릭: 폭발 생성, 스페이스: 중앙 폭발, ESC: 종료", True, WHITE)
        text_rect = guide_text.get_rect(center=(WIDTH // 2, HEIGHT - 30))
        screen.blit(guide_text, text_rect)
        
        # 화면 업데이트
        pygame.display.flip()
        clock.tick(60)
    
    # 정리
    pygame.quit()
    print("테스트가 종료되었습니다.")

if __name__ == "__main__":
    test_hammer_explosion()