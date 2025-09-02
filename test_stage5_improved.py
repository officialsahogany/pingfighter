#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
Stage 5 개선된 맵 테스트
"""

import pygame
import sys
import os

# 상위 디렉토리를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ui.stage5_chinese_market import Stage5ChineseMarket

# 초기화
pygame.init()

# 화면 설정
WIDTH = 600
HEIGHT = 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Stage 5 - 개선된 중국 전통시장 화염 테마")

# 색상
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)

def main():
    clock = pygame.time.Clock()
    running = True
    
    # Stage 5 인스턴스 생성
    stage5 = Stage5ChineseMarket()
    
    # 테스트용 변수
    show_info = True
    test_fire_burst = False
    test_inferno = False
    
    # 폰트
    font = pygame.font.Font(None, 24)
    
    while running:
        dt = clock.tick(60)
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 스페이스바: 일반 화염탄 효과 테스트
                    stage5.trigger_spiral_burst(inferno=False)
                    test_fire_burst = True
                    print("일반 화염탄 효과 발동!")
                elif event.key == pygame.K_i:
                    # I키: 홍련폭염 모드 테스트
                    stage5.trigger_spiral_burst(inferno=True)
                    test_inferno = True
                    print("홍련폭염 모드 발동!")
                elif event.key == pygame.K_f:
                    # F키: 바닥 충돌 화염 효과 테스트
                    import random
                    x = random.randint(100, WIDTH - 100)
                    stage5.add_fire_impact(x, HEIGHT - 50)
                    print(f"화염 충돌 효과 추가: x={x}")
                elif event.key == pygame.K_h:
                    # H키: 정보 표시 토글
                    show_info = not show_info
                elif event.key == pygame.K_s:
                    # S키: 스크린샷 저장
                    pygame.image.save(screen, "stage5_improved.png")
                    print("스크린샷 저장됨: stage5_improved.png")
        
        # 업데이트
        stage5.update(dt)
        
        # 그리기
        screen.fill((20, 5, 5))
        stage5.draw(screen)
        
        # 정보 표시
        if show_info:
            info_texts = [
                "Stage 5 개선된 디자인 테스트",
                "조작법:",
                "SPACE - 일반 화염탄 효과",
                "I - 홍련폭염 모드",
                "F - 바닥 충돌 화염",
                "H - 정보 표시 토글",
                "S - 스크린샷 저장",
                "",
                f"파티클 수: {len(stage5.fire_particles) + len(stage5.fire_line_particles)}",
                f"충돌 지점: {len(stage5.impact_fire_zones)}",
                f"나선 타이머: {stage5.spiral_burst_timer:.0f}ms"
            ]
            
            y_offset = 10
            for text in info_texts:
                text_surface = font.render(text, True, WHITE)
                # 배경 박스
                text_rect = text_surface.get_rect(topleft=(10, y_offset))
                pygame.draw.rect(screen, (0, 0, 0, 128), text_rect.inflate(10, 2))
                screen.blit(text_surface, (10, y_offset))
                y_offset += 25
        
        # FPS 표시
        fps_text = font.render(f"FPS: {clock.get_fps():.1f}", True, WHITE)
        fps_rect = fps_text.get_rect(topright=(WIDTH - 10, 10))
        pygame.draw.rect(screen, (0, 0, 0, 128), fps_rect.inflate(10, 2))
        screen.blit(fps_text, fps_rect)
        
        pygame.display.flip()
    
    pygame.quit()
    print("\n=== Stage 5 개선 사항 ===")
    print("✅ 홀로그램 단순화 - 복잡한 삼각형 제거")
    print("✅ 애니메이션 속도 50% 감소")
    print("✅ 배경 대비 개선")
    print("✅ 파티클 수 50% 감소 (100→50)")
    print("✅ 시각적 노이즈 감소")
    print("\n개선 후 성능과 가독성이 향상되었습니다!")

if __name__ == "__main__":
    main()