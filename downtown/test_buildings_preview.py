#!/usr/bin/env python3
"""
StarBank 5가지 디자인 미리보기 테스트
"""

import sys
import os
import pygame
import math

# 프로젝트 루트를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from downtown.constants import *
from downtown.bank_designs import BANK_DESIGNS

def create_preview():
    """5가지 디자인을 화면에 표시"""
    pygame.init()

    # 화면 설정 (5개를 가로로 배치)
    screen_width = 500
    screen_height = 250
    screen = pygame.display.set_mode((screen_width, screen_height))
    pygame.display.set_caption("StarBank 디자인 미리보기 (1-5번 선택)")

    clock = pygame.time.Clock()
    animation_timer = 0

    # 임시 건물 클래스
    class TempBuilding:
        def __init__(self):
            self.width = 85
            self.height = 80

    # 폰트
    font = pygame.font.Font(None, 20)
    desc_font = pygame.font.Font(None, 14)

    # 디자인 설명
    design_descriptions = {
        1: "우아한 대리석",
        2: "네온 사이버",
        3: "크리스탈 궁전",
        4: "황금 신전",
        5: "미래 은행"
    }

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key in [pygame.K_1, pygame.K_2, pygame.K_3, pygame.K_4, pygame.K_5]:
                    selected = event.key - pygame.K_0
                    print(f"\n선택: 디자인 {selected}번 - {design_descriptions[selected]}")
                    print("이 디자인을 적용하시겠습니까? (y/n)")

        # 배경
        screen.fill((20, 20, 30))

        # 제목
        title = font.render("StarBank 디자인 선택 (1-5 키를 누르세요)", True, (255, 215, 0))
        screen.blit(title, (screen_width // 2 - title.get_width() // 2, 10))

        # 5개 디자인 미리보기
        design_width = screen_width // 5
        building = TempBuilding()

        for i in range(1, 6):
            x_offset = (i - 1) * design_width

            # 번호 표시
            num_text = font.render(f"{i}", True, (255, 255, 255))
            screen.blit(num_text, (x_offset + design_width // 2 - 8, 35))

            # 건물 렌더링
            building_x = x_offset + design_width // 2 - 42
            building_y = 70

            # 빈 파티클 딕셔너리
            particles = {i: []}

            # 디자인 그리기
            BANK_DESIGNS[i](screen, building, building_x, building_y, i, animation_timer, particles)

            # 설명
            desc = desc_font.render(design_descriptions[i], True, (200, 200, 200))
            desc_rect = desc.get_rect(center=(x_offset + design_width // 2, 165))
            screen.blit(desc, desc_rect)

        # 안내 텍스트
        guide = desc_font.render("ESC: 종료", True, (150, 150, 150))
        screen.blit(guide, (screen_width // 2 - guide.get_width() // 2, screen_height - 25))

        pygame.display.flip()
        clock.tick(60)

        animation_timer += 1 / 60  # 60 FPS

    pygame.quit()

if __name__ == "__main__":
    print("\n" + "="*80)
    print("🏦 StarBank 5가지 디자인 미리보기")
    print("="*80)
    print("\n1. 우아한 대리석 - 현재 버전 (대리석 + 황금)")
    print("2. 네온 사이버펑크 - 사이버펑크 (네온 글로우 + 홀로그램)")
    print("3. 크리스탈 궁전 - 판타지 (크리스탈 + 마법)")
    print("4. 황금 신전 - 고대 신전 (피라미드 + 별빛)")
    print("5. 미래 은행 - 미래적 (유리 + 홀로그램 + 에너지)")
    print("\n미리보기 창에서 1-5 키를 눌러 선택하세요.\n")
    print("="*80 + "\n")

    create_preview()
