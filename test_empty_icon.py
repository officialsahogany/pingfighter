#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""EmptyIcon 전설 아이템 테스트"""

import pygame
import sys
import os
import math

# 상위 디렉토리를 sys.path에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from legendary_items import EmptyIcon

def main():
    """EmptyIcon 전설 아이템 시각 테스트"""
    # Pygame 초기화
    pygame.init()

    # 화면 설정
    SCREEN_WIDTH = 800
    SCREEN_HEIGHT = 600
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("EmptyIcon Legendary Item Test - 빈아이콘 전설 아이템 테스트")

    # 색상 정의
    BLACK = (0, 0, 0)
    WHITE = (255, 255, 255)
    DARK_GRAY = (40, 40, 40)

    # 폰트 초기화
    font = pygame.font.Font(None, 36)
    small_font = pygame.font.Font(None, 24)

    # 시계 초기화
    clock = pygame.time.Clock()

    # EmptyIcon 인스턴스 생성
    empty_icon = EmptyIcon()
    empty_icon.unlocked = True  # 테스트를 위해 해금

    # 애니메이션 시간
    animation_time = 0

    # 테스트 아이콘 크기들
    test_sizes = [40, 60, 80, 100, 120]

    # 마우스 위치 추적용
    mouse_icon_size = 60
    show_mouse_icon = False

    # 메인 루프
    running = True
    dt = 0.016  # 60fps 기준

    while running:
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    show_mouse_icon = not show_mouse_icon
                elif event.key == pygame.K_UP:
                    mouse_icon_size = min(200, mouse_icon_size + 10)
                elif event.key == pygame.K_DOWN:
                    mouse_icon_size = max(20, mouse_icon_size - 10)

        # 화면 지우기 - 어두운 배경
        screen.fill(DARK_GRAY)

        # 격자 배경 그리기
        for x in range(0, SCREEN_WIDTH, 50):
            pygame.draw.line(screen, (50, 50, 50), (x, 0), (x, SCREEN_HEIGHT))
        for y in range(0, SCREEN_HEIGHT, 50):
            pygame.draw.line(screen, (50, 50, 50), (0, y), (SCREEN_WIDTH, y))

        # 제목 표시
        title_text = font.render("EmptyIcon - 빈아이콘 테스트", True, WHITE)
        screen.blit(title_text, (SCREEN_WIDTH // 2 - title_text.get_width() // 2, 20))

        # 설명 텍스트
        desc_text = small_font.render("라그나로크 프레임 + 외부 테두리 + 전설대기 스타일 내부 글로우", True, (200, 200, 200))
        screen.blit(desc_text, (SCREEN_WIDTH // 2 - desc_text.get_width() // 2, 60))

        # 조작 설명
        control_text1 = small_font.render("SPACE: 마우스 아이콘 토글", True, (150, 150, 150))
        control_text2 = small_font.render("↑/↓: 마우스 아이콘 크기 조절", True, (150, 150, 150))
        control_text3 = small_font.render("ESC: 종료", True, (150, 150, 150))
        screen.blit(control_text1, (10, SCREEN_HEIGHT - 80))
        screen.blit(control_text2, (10, SCREEN_HEIGHT - 55))
        screen.blit(control_text3, (10, SCREEN_HEIGHT - 30))

        # 다양한 크기로 아이콘 그리기
        y_base = 120
        for i, size in enumerate(test_sizes):
            x = SCREEN_WIDTH // 2 - (len(test_sizes) * 70) // 2 + i * 140
            y = y_base

            # 배경 박스
            box_margin = 20
            pygame.draw.rect(screen, (30, 30, 30),
                           (x - box_margin, y - box_margin,
                            size + box_margin * 2, size + box_margin * 2))
            pygame.draw.rect(screen, (60, 60, 60),
                           (x - box_margin, y - box_margin,
                            size + box_margin * 2, size + box_margin * 2), 2)

            # 아이콘 그리기
            empty_icon.draw_icon(screen, x, y, size)

            # 크기 레이블
            size_label = small_font.render(f"{size}px", True, (150, 150, 150))
            screen.blit(size_label, (x + size // 2 - size_label.get_width() // 2, y + size + 25))

        # 중앙 큰 아이콘
        center_x = SCREEN_WIDTH // 2 - 75
        center_y = 320
        center_size = 150

        # 배경 패널
        panel_rect = pygame.Rect(center_x - 30, center_y - 30, center_size + 60, center_size + 100)
        pygame.draw.rect(screen, (20, 20, 20), panel_rect)
        pygame.draw.rect(screen, (80, 80, 80), panel_rect, 3)

        # 메인 아이콘 그리기
        empty_icon.draw_icon(screen, center_x, center_y, center_size)

        # 아이콘 이름
        name_text = font.render("빈아이콘 (Empty Icon)", True, (255, 215, 0))
        screen.blit(name_text, (center_x + center_size // 2 - name_text.get_width() // 2, center_y + center_size + 15))

        # 마우스 위치에 아이콘 그리기 (토글 가능)
        if show_mouse_icon:
            mouse_x, mouse_y = pygame.mouse.get_pos()
            empty_icon.draw_icon(screen, mouse_x - mouse_icon_size // 2,
                               mouse_y - mouse_icon_size // 2, mouse_icon_size)

            # 마우스 아이콘 크기 표시
            mouse_size_text = small_font.render(f"크기: {mouse_icon_size}px", True, WHITE)
            screen.blit(mouse_size_text, (mouse_x + mouse_icon_size // 2 + 10, mouse_y))

        # 애니메이션 정보 표시
        info_text = small_font.render(f"Animation Time: {animation_time:.2f}", True, (100, 100, 100))
        screen.blit(info_text, (SCREEN_WIDTH - 200, 20))

        frame_text = small_font.render(f"Frame: {empty_icon.current_frame}/8", True, (100, 100, 100))
        screen.blit(frame_text, (SCREEN_WIDTH - 200, 45))

        # 특성 설명
        features = [
            "✓ 라그나로크 PNG 프레임 (8장)",
            "✓ 황금색 L자 외부 코너",
            "✓ 전설대기 스타일 3중 글로우",
            "✓ 중앙 완전 비움"
        ]

        for i, feature in enumerate(features):
            feature_text = small_font.render(feature, True, (150, 200, 150))
            screen.blit(feature_text, (20, 120 + i * 25))

        # 애니메이션 업데이트
        empty_icon.update(dt, ui_mode=True)
        animation_time += dt

        # 화면 업데이트
        pygame.display.flip()
        clock.tick(60)

    # 종료
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()