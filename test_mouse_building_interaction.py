#!/usr/bin/env python3
"""
건물 마우스 클릭 상호작용 테스트
"""

import pygame
import sys
import os

# 프로젝트 루트를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from downtown.manager import DowntownManager
from downtown.constants import SCREEN_WIDTH, SCREEN_HEIGHT

def test_mouse_interaction():
    """마우스 클릭으로 건물 상호작용 테스트"""
    print("=== 건물 마우스 클릭 상호작용 테스트 ===")
    print("1. 건물에 가까이 간 후 건물을 마우스로 클릭해보세요")
    print("2. 확인 다이얼로그가 나타나면 '예' 또는 '아니오' 버튼을 클릭하세요")
    print("3. 스페이스 키로도 상호작용이 가능합니다 (비교용)")
    print("4. ESC로 종료")
    print()
    print("조작법:")
    print("- WASD 또는 방향키: 이동")
    print("- 마우스 왼쪽 버튼: 건물 클릭")
    print("- 스페이스: 가까이 있는 건물과 상호작용")
    print("=" * 50)

    # Pygame 초기화
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("Mouse Building Interaction Test")

    # 매니저 생성 및 초기화
    manager = DowntownManager(screen)
    manager.initialize(
        stage_number=1,
        player_data={
            'gold': 1000,
            'star_points': 15,  # 스타 포인트 추가
            'character_type': 'smasher'
        }
    )

    # 테스트 정보 표시
    font = pygame.font.Font(None, 20)

    clock = pygame.time.Clock()
    running = True

    mouse_click_count = 0
    space_click_count = 0

    while running:
        dt = clock.tick(60) / 1000.0

        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    space_click_count += 1
                    print(f"[스페이스] 상호작용 시도 (총 {space_click_count}회)")
            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:
                    mouse_click_count += 1
                    print(f"[마우스] 클릭 위치: {event.pos} (총 {mouse_click_count}회)")

            # 매니저에 이벤트 전달
            manager._handle_event(event)

        # 업데이트
        manager._update(dt)

        # 렌더링
        manager._draw()

        # 테스트 정보 오버레이
        info_y = SCREEN_HEIGHT - 100
        info_texts = [
            f"마우스 클릭: {mouse_click_count}회",
            f"스페이스 사용: {space_click_count}회",
            "건물에 가까이 가서 클릭 또는 스페이스를 눌러보세요",
            "ESC: 종료"
        ]

        for i, text in enumerate(info_texts):
            text_surface = font.render(text, True, (255, 255, 255))
            # 배경
            text_rect = text_surface.get_rect()
            bg_rect = pygame.Rect(10, info_y + i * 22 - 2, text_rect.width + 10, text_rect.height + 4)
            pygame.draw.rect(screen, (0, 0, 0, 180), bg_rect)
            # 텍스트
            screen.blit(text_surface, (15, info_y + i * 22))

        pygame.display.flip()

        # 완료 체크
        if manager.state == "completed":
            print("번화가 탐험 완료!")
            break

    pygame.quit()
    print("\n테스트 종료")
    print(f"총 마우스 클릭: {mouse_click_count}회")
    print(f"총 스페이스 사용: {space_click_count}회")

if __name__ == "__main__":
    test_mouse_interaction()
