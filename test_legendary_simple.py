#!/usr/bin/env python3
"""
간단한 전설 아이템 애니메이션 테스트
E 키를 누르면 전설 아이템 획득 애니메이션 재생
"""

import pygame
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from effects.legendary_integration import (
    trigger_legendary_acquisition,
    update_legendary_effect,
    draw_legendary_effect,
    should_pause_for_legendary,
    handle_legendary_space_press,
    initialize_legendary_effects
)

def main():
    pygame.init()
    
    # 화면 설정
    WIDTH, HEIGHT = 600, 750
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("전설 아이템 애니메이션 테스트 (E키로 시작)")
    clock = pygame.time.Clock()
    
    # 폰트 설정 - 한글 지원 폰트 사용 (NeoDGM 사용)
    try:
        font_large = pygame.font.Font("NeoDGM.ttf", 48)
        font_huge = pygame.font.Font("NeoDGM.ttf", 72)
    except:
        try:
            # 대안: Pretendard 폰트 시도
            font_large = pygame.font.Font("Pretendard-Medium.ttf", 48)
            font_huge = pygame.font.Font("Pretendard-Medium.ttf", 72)
        except:
            # 폰트 파일이 없으면 기본 폰트 사용
            font_large = pygame.font.Font(None, 48)
            font_huge = pygame.font.Font(None, 72)
            print("Warning: Korean font not found, using default font")
    
    # 효과 시스템 초기화
    initialize_legendary_effects(WIDTH, HEIGHT)
    
    # 게임 상태
    running = True
    game_paused = False
    
    print("=" * 50)
    print("전설 아이템 애니메이션 테스트")
    print("=" * 50)
    print("E: 전설 아이템 획득 애니메이션 (5초)")
    print("애니메이션 후 스페이스바를 눌러 계속")
    print("ESC: 종료")
    print("=" * 50)
    
    while running:
        dt = clock.tick(60)
        
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_e:
                    # 전설 아이템 획득 애니메이션 트리거
                    print("전설 아이템 획득 애니메이션 시작!")
                    trigger_legendary_acquisition("ragnarok_hammer", "라그나로크")
                elif event.key == pygame.K_SPACE:
                    # 스페이스바 처리
                    if handle_legendary_space_press():
                        print("스페이스바로 애니메이션 종료!")
                        game_paused = False
        
        # 전설 아이템 효과로 인한 일시정지 체크
        if should_pause_for_legendary():
            game_paused = True
        
        # 전설 아이템 효과 업데이트
        update_legendary_effect(dt)
        
        # 화면 그리기
        screen.fill((20, 20, 30))
        
        # 배경 격자
        for x in range(0, WIDTH, 50):
            pygame.draw.line(screen, (30, 30, 40), (x, 0), (x, HEIGHT), 1)
        for y in range(0, HEIGHT, 50):
            pygame.draw.line(screen, (30, 30, 40), (0, y), (WIDTH, y), 1)
        
        # 게임 일시정지 표시
        if game_paused:
            pause_text = font_large.render("PAUSED", True, (255, 100, 100))
            screen.blit(pause_text, (WIDTH // 2 - pause_text.get_width() // 2, 50))
        
        # 안내 텍스트
        instructions = [
            "E: 전설 아이템 애니메이션",
            "애니메이션 후 스페이스바",
            "ESC: 종료"
        ]
        
        try:
            font_small = pygame.font.Font("NeoDGM.ttf", 24)
        except:
            font_small = pygame.font.Font(None, 24)
        for i, text in enumerate(instructions):
            inst_text = font_small.render(text, True, (200, 200, 200))
            screen.blit(inst_text, (10, 10 + i * 25))
        
        # 전설 아이템 획득 효과 그리기 (최상단 레이어)
        draw_legendary_effect(screen, font_large, font_huge)
        
        # FPS 표시
        fps_text = font_small.render(f"FPS: {int(clock.get_fps())}", True, (150, 150, 150))
        screen.blit(fps_text, (WIDTH - 100, HEIGHT - 30))
        
        pygame.display.flip()
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()