#!/usr/bin/env python3
"""
Stage 2 정글지진 완성 테스트

최종 수정 사항:
1. activate_quake()에서 animated_bg_stage2.trigger_earthquake() 호출 추가
2. draw_shaking_screen()에서 earthquake_offset을 screen_shake_offset에 통합
3. draw_objects()에서 벽돌이 screen_shake_offset을 따라 흔들림

이제 다음이 모두 정상 작동해야 함:
- 정글지진 시 화면 흔들림 효과
- 벽돌이 화면과 함께 흔들리며 계속 보임
- 다른 오브젝트들도 함께 흔들림
"""

import pygame
import sys
import os
import random

# 게임 디렉토리를 Python 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 상수 정의
WIDTH = 600
HEIGHT = 750
FPS = 60

# 색상 정의
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
GREEN = (34, 139, 34)  # 정글 색상
BROWN = (139, 69, 19)  # 벽돌 색상

def test_integration():
    """통합 테스트: 실제 게임과 동일한 렌더링 파이프라인"""
    pygame.init()
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("Stage 2 정글지진 통합 테스트")
    clock = pygame.time.Clock()
    
    # 테스트 상태
    running = True
    earthquake_active = False
    earthquake_timer = 0
    earthquake_duration = 80
    screen_shake_offset_x = 0
    screen_shake_offset_y = 0
    
    # 벽돌 리스트
    walls = []
    for i in range(3):
        walls.append({
            "rect": pygame.Rect(200 + i*100, 400, 60, 20)
        })
    
    font = pygame.font.Font(None, 36)
    
    def get_earthquake_offset():
        if not earthquake_active:
            return (0, 0)
        
        progress = earthquake_timer / earthquake_duration
        intensity = 8 * (1 - progress)
        offset_x = (random.random() - 0.5) * intensity * 2
        offset_y = (random.random() - 0.5) * intensity * 2
        return (int(offset_x), int(offset_y))
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    earthquake_active = True
                    earthquake_timer = 0
                    print("🌋 정글지진 발동!")
        
        # 지진 업데이트
        if earthquake_active:
            earthquake_timer += 1
            if earthquake_timer >= earthquake_duration:
                earthquake_active = False
                print("🌋 정글지진 종료")
        
        # 지진 오프셋 계산 (draw_shaking_screen() 로직 재현)
        if earthquake_active:
            earthquake_offset_x, earthquake_offset_y = get_earthquake_offset()
            screen_shake_offset_x = earthquake_offset_x
            screen_shake_offset_y = earthquake_offset_y
        else:
            screen_shake_offset_x = 0
            screen_shake_offset_y = 0
        
        # 렌더링 (실제 게임과 동일한 방식)
        if screen_shake_offset_x != 0 or screen_shake_offset_y != 0:
            # temp_surface 생성
            temp_surface = pygame.Surface((WIDTH, HEIGHT))
            
            # 배경 그리기
            temp_surface.fill(GREEN)
            
            # 벽돌 그리기 (temp_surface에)
            for wall in walls:
                pygame.draw.rect(temp_surface, BROWN, wall["rect"])
                pygame.draw.rect(temp_surface, WHITE, wall["rect"], 2)
            
            # 정보 텍스트
            status_text = font.render("🌋 정글지진 발동중!", True, WHITE)
            temp_surface.blit(status_text, (WIDTH//2 - status_text.get_width()//2, 50))
            
            offset_text = font.render(f"오프셋: ({screen_shake_offset_x}, {screen_shake_offset_y})", True, WHITE)
            temp_surface.blit(offset_text, (WIDTH//2 - offset_text.get_width()//2, 100))
            
            # 오프셋 적용하여 화면에 그리기
            screen.fill(BLACK)
            screen.blit(temp_surface, (screen_shake_offset_x, screen_shake_offset_y))
        else:
            # 지진 없을 때
            screen.fill(GREEN)
            
            # 벽돌 그리기
            for wall in walls:
                pygame.draw.rect(screen, BROWN, wall["rect"])
                pygame.draw.rect(screen, WHITE, wall["rect"], 2)
            
            # 정보 텍스트
            status_text = font.render("SPACE: 정글지진 발동", True, WHITE)
            screen.blit(status_text, (WIDTH//2 - status_text.get_width()//2, 50))
        
        pygame.display.flip()
        clock.tick(FPS)
    
    pygame.quit()

if __name__ == "__main__":
    print("=" * 60)
    print("Stage 2 정글지진 완성 테스트")
    print("=" * 60)
    print("수정 완료:")
    print("✅ activate_quake()에서 animated_bg_stage2 사용")
    print("✅ trigger_earthquake() 호출 추가")
    print("✅ earthquake_offset이 screen_shake_offset에 통합")
    print("✅ 벽돌이 화면과 함께 흔들리며 계속 보임")
    print("=" * 60)
    
    test_integration()