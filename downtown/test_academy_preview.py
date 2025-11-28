#!/usr/bin/env python3
"""
아카데미 5가지 디자인 미리보기 테스트
"""

import sys
import os
import pygame
import math

# 프로젝트 루트를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from downtown.constants import *
from downtown.academy_designs import ACADEMY_DESIGNS

def create_preview():
    """5가지 디자인을 화면에 표시"""
    pygame.init()

    # 화면 설정 (5개를 가로로 배치)
    screen_width = 500
    screen_height = 250
    screen = pygame.display.set_mode((screen_width, screen_height))
    pygame.display.set_caption("아카데미 디자인 미리보기 (1-5번 선택)")

    clock = pygame.time.Clock()
    animation_timer = 0

    # 임시 건물 클래스
    class TempBuilding:
        def __init__(self):
            self.width = 85
            self.height = 80

    # 폰트
    font = pygame.font.Font(None, 20)
    desc_font = pygame.font.Font(None, 12)

    # 디자인 설명
    design_descriptions = {
        1: "아카데미",
        2: "현대 대학",
        3: "동양 도장",
        4: "사이버 훈련소",
        5: "고대 신전"
    }

    running = True
    selected = None

    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key in [pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4, pygame.K_5]:
                    selected = event.key - pygame.K_0
                    print(f"\n✅ 선택: 디자인 {selected}번 - {design_descriptions[selected]}")
                    print(f"이 디자인을 적용하려면 창을 닫고 선택하세요.")

        # 배경
        screen.fill((20, 20, 30))

        # 제목
        title = font.render("아카데미 디자인 선택 (1-5 키)", True, (150, 100, 255))
        screen.blit(title, (screen_width // 2 - title.get_width() // 2, 10))

        # 5개 디자인 미리보기
        design_width = screen_width // 5
        building = TempBuilding()

        for i in range(1, 6):
            x_offset = (i - 1) * design_width

            # 선택된 디자인 강조
            if selected == i:
                highlight_rect = pygame.Rect(x_offset, 30, design_width, 190)
                pygame.draw.rect(screen, (150, 100, 255), highlight_rect, 3)

            # 번호 표시
            num_text = font.render(f"{i}", True, (255, 255, 255) if selected != i else (150, 100, 255))
            screen.blit(num_text, (x_offset + design_width // 2 - 8, 35))

            # 건물 렌더링
            building_x = x_offset + design_width // 2 - 42
            building_y = 70

            # 빈 파티클 딕셔너리
            particles = {i: []}

            # 디자인 그리기
            ACADEMY_DESIGNS[i](screen, building, building_x, building_y, i, animation_timer, particles)

            # 설명
            desc_lines = design_descriptions[i].split(" ")
            for idx, line in enumerate(desc_lines):
                desc = desc_font.render(line, True, (200, 200, 200))
                desc_rect = desc.get_rect(center=(x_offset + design_width // 2, 165 + idx * 12))
                screen.blit(desc, desc_rect)

        # 안내 텍스트
        guide = desc_font.render("ESC: 종료 | 1-5: 선택", True, (150, 150, 150))
        screen.blit(guide, (screen_width // 2 - guide.get_width() // 2, screen_height - 25))

        if selected:
            choice_text = desc_font.render(f"선택됨: {design_descriptions[selected]}", True, (150, 255, 150))
            screen.blit(choice_text, (screen_width // 2 - choice_text.get_width() // 2, screen_height - 40))

        pygame.display.flip()
        clock.tick(60)

        animation_timer += 1 / 60  # 60 FPS

    pygame.quit()
    return selected

if __name__ == "__main__":
    print("\n" + "="*80)
    print("🏫 아카데미 5가지 디자인 미리보기")
    print("="*80)
    print("\n1. 아카데미 - 중세 마법사 성 (해리포터 스타일)")
    print("2. 아카데미 - 유리 건물 + 책 모티브")
    print("3. 동양 도장 - 일본/중국 전통 무술 수련장")
    print("4. 사이버 훈련소 - VR/AR 미래형 훈련 센터")
    print("5. 고대 신전 - 그리스/로마 지혜의 신전")
    print("\n미리보기 창에서 1-5 키를 눌러 선택하세요.\n")
    print("="*80 + "\n")

    selected = create_preview()

    if selected:
        print(f"\n최종 선택: {selected}번 디자인")
    else:
        print("\n선택하지 않고 종료했습니다.")
