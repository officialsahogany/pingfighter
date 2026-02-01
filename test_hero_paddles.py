# -*- coding: utf-8 -*-
"""
영웅 패들 미리보기 테스트
8명의 영웅 패들 디자인 확인용
"""

import pygame
import sys
import os
import math

# 경로 설정
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from downtown.hero_paddles import get_hero_paddle_renderer

# 영웅 데이터
TOP_HEROES = [
    {"id": "gallita", "name": "갤리타", "title": "폭풍의 여전사", "color": (60, 200, 120)},
    {"id": "archines", "name": "아르키네스", "title": "철벽의 수호자", "color": (60, 120, 220)},
    {"id": "chungkia", "name": "토키아", "title": "바위의 거인", "color": (200, 140, 60)},
    {"id": "poineth", "name": "포이네스", "title": "그림자 암살자", "color": (160, 60, 200)},
]

BOTTOM_HEROES = [
    {"id": "gestand", "name": "게스탄드", "title": "현명한 전술가", "color": (100, 160, 220)},
    {"id": "bukandai", "name": "부칸다이", "title": "광기의 광대", "color": (220, 80, 180)},
    {"id": "pinjo", "name": "핀조", "title": "불굴의 검투사", "color": (220, 60, 60)},
    {"id": "alexa", "name": "알렉사", "title": "황금의 창", "color": (220, 180, 60)},
]


def main():
    pygame.init()
    pygame.freetype.init()

    screen = pygame.display.set_mode((800, 600))
    pygame.display.set_caption("영웅 패들 미리보기")
    clock = pygame.time.Clock()

    # 폰트
    try:
        font = pygame.freetype.Font(None, 16)
        title_font = pygame.freetype.Font(None, 24)
    except:
        font = None
        title_font = None

    # 렌더러
    renderer = get_hero_paddle_renderer()

    # 애니메이션 상태
    animation_timer = 0
    move_phase = 0

    running = True
    while running:
        dt = clock.tick(60) / 1000.0
        animation_timer += dt
        move_phase = math.sin(animation_timer * 2) * 30  # 좌우 이동 시뮬레이션

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

        # 배경
        screen.fill((40, 45, 55))

        # 타이틀
        if title_font:
            surf, _ = title_font.render("콜로세움 영웅 패들 미리보기", (255, 215, 0))
            screen.blit(surf, (400 - surf.get_width() // 2, 20))

            surf, _ = font.render("상단 영웅 (아래를 바라봄)", (200, 200, 200))
            screen.blit(surf, (200 - surf.get_width() // 2, 60))

            surf, _ = font.render("하단 영웅 (위를 바라봄)", (200, 200, 200))
            screen.blit(surf, (600 - surf.get_width() // 2, 60))

        # 렌더러 업데이트
        renderer.update(dt)

        # 상단 영웅 그리기 (왼쪽 절반)
        for i, hero in enumerate(TOP_HEROES):
            x = 100 + (i % 2) * 180
            y = 150 + (i // 2) * 200

            # 이동 시뮬레이션
            sim_x = x + move_phase * (1 if i % 2 == 0 else -1)
            renderer.update_movement(hero["id"], sim_x, dt)

            # 배경 박스
            pygame.draw.rect(screen, (30, 35, 45), (x - 70, y - 50, 140, 130), border_radius=8)
            pygame.draw.rect(screen, hero["color"], (x - 70, y - 50, 140, 130), 2, border_radius=8)

            # 패들 그리기 (미리보기 모드 - 크게 표시)
            renderer.draw_hero_paddle(screen, hero["id"], sim_x, y, 80, 12, "down", hero["color"], scale_mode="preview")

            # 이름
            if font:
                name_surf, _ = font.render(hero["name"], (255, 255, 255))
                screen.blit(name_surf, (x - name_surf.get_width() // 2, y + 50))
                title_surf, _ = font.render(hero["title"], hero["color"])
                screen.blit(title_surf, (x - title_surf.get_width() // 2, y + 68))

        # 하단 영웅 그리기 (오른쪽 절반)
        for i, hero in enumerate(BOTTOM_HEROES):
            x = 500 + (i % 2) * 180
            y = 150 + (i // 2) * 200

            # 이동 시뮬레이션
            sim_x = x + move_phase * (-1 if i % 2 == 0 else 1)
            renderer.update_movement(hero["id"], sim_x, dt)

            # 배경 박스
            pygame.draw.rect(screen, (30, 35, 45), (x - 70, y - 50, 140, 130), border_radius=8)
            pygame.draw.rect(screen, hero["color"], (x - 70, y - 50, 140, 130), 2, border_radius=8)

            # 패들 그리기 (미리보기 모드 - 크게 표시)
            renderer.draw_hero_paddle(screen, hero["id"], sim_x, y, 80, 12, "up", hero["color"], scale_mode="preview")

            # 이름
            if font:
                name_surf, _ = font.render(hero["name"], (255, 255, 255))
                screen.blit(name_surf, (x - name_surf.get_width() // 2, y + 50))
                title_surf, _ = font.render(hero["title"], hero["color"])
                screen.blit(title_surf, (x - title_surf.get_width() // 2, y + 68))

        # 안내
        if font:
            surf, _ = font.render("ESC: 종료 | 자동으로 좌우 이동 애니메이션 시뮬레이션 중", (150, 150, 150))
            screen.blit(surf, (400 - surf.get_width() // 2, 570))

        pygame.display.flip()

    pygame.quit()


if __name__ == "__main__":
    main()
