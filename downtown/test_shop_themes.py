#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# downtown/test_shop_themes.py
# 5가지 상점 테마 미리보기 테스트

import pygame
import pygame.freetype
import os
import sys

# 부모 디렉토리를 sys.path에 추가
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

from downtown.constants import SCREEN_WIDTH, SCREEN_HEIGHT, resource_path
from downtown.shop import Shop, preview_shop_themes

def init_fonts():
    """폰트 초기화"""
    freetype_fonts = {}

    # freetype 폰트 로드 시도
    font = None
    try:
        font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
        if os.path.exists(font_path):
            font = font_path
    except:
        pass

    # 시스템 폰트 fallback
    if font is None:
        if os.path.exists("/System/Library/Fonts/AppleSDGothicNeo.ttc"):
            font = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
        elif os.path.exists("C:/Windows/Fonts/malgun.ttf"):
            font = "C:/Windows/Fonts/malgun.ttf"

    # freetype 폰트 생성
    try:
        freetype_fonts['large'] = pygame.freetype.Font(font, 32)
        freetype_fonts['medium'] = pygame.freetype.Font(font, 24)
        freetype_fonts['small'] = pygame.freetype.Font(font, 16)
    except:
        freetype_fonts['large'] = pygame.freetype.SysFont(None, 32)
        freetype_fonts['medium'] = pygame.freetype.SysFont(None, 24)
        freetype_fonts['small'] = pygame.freetype.SysFont(None, 16)

    return freetype_fonts

def test_theme_preview():
    """테마 미리보기 테스트"""
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("상점 테마 미리보기")

    freetype_fonts = init_fonts()

    print("=" * 60)
    print("상점 테마 미리보기")
    print("=" * 60)
    print("\n5가지 테마:")
    for i, (key, theme) in enumerate(Shop.THEMES.items(), 1):
        print(f"{i}. {theme['name']} ({key})")
        print(f"   {theme['description']}")
        print()

    # 테마 선택 화면
    selected_theme = preview_shop_themes(screen, freetype_fonts)

    if selected_theme:
        print(f"\n선택된 테마: {Shop.THEMES[selected_theme]['name']}")
        print(f"테마 키: {selected_theme}")

        # 선택된 테마로 상점 열기
        shop = Shop(screen, theme=selected_theme, freetype_fonts=freetype_fonts)
        shop.set_player_gold(5000)  # 테스트용 골드

        print("\n상점 열기...")
        purchased_items, remaining_gold = shop.open(5000)

        print("\n구매 결과:")
        print(f"- 구매한 아이템: {len(purchased_items)}개")
        for item in purchased_items:
            print(f"  * {item.name} - {item.price}G")
        print(f"- 남은 골드: {remaining_gold}G")
    else:
        print("\n테마 선택 취소됨")

    pygame.quit()

def test_single_theme(theme_key="cyberpunk"):
    """단일 테마 테스트"""
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption(f"상점 테스트 - {theme_key}")

    freetype_fonts = init_fonts()

    print(f"\n{Shop.THEMES[theme_key]['name']} 테스트")
    print("=" * 60)

    shop = Shop(screen, theme=theme_key, freetype_fonts=freetype_fonts)
    shop.set_player_gold(3000)

    purchased_items, remaining_gold = shop.open(3000)

    print("\n결과:")
    print(f"- 구매한 아이템: {len(purchased_items)}개")
    for item in purchased_items:
        print(f"  * {item.name} - {item.price}G")
    print(f"- 남은 골드: {remaining_gold}G")

    pygame.quit()

def show_all_themes_side_by_side():
    """모든 테마를 한 화면에 표시"""
    pygame.init()

    # 큰 화면 생성 (5개 테마를 나란히)
    screen = pygame.display.set_mode((SCREEN_WIDTH * 2, SCREEN_HEIGHT * 3))
    pygame.display.set_caption("모든 상점 테마 비교")

    freetype_fonts = init_fonts()

    print("\n모든 테마 비교")
    print("=" * 60)

    themes = list(Shop.THEMES.keys())

    # 각 테마별로 스크린샷 영역에 렌더링
    for i, theme_key in enumerate(themes):
        theme = Shop.THEMES[theme_key]
        print(f"\n{i + 1}. {theme['name']} ({theme_key})")
        print(f"   설명: {theme['description']}")
        print(f"   주색상: {theme['primary_color']}")
        print(f"   부색상: {theme['secondary_color']}")

    # 대기
    clock = pygame.time.Clock()
    running = True

    while running:
        clock.tick(60)

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

        # 배경
        screen.fill((20, 20, 30))

        # 제목
        font_large = freetype_fonts.get('large')
        if font_large:
            title_surf, title_rect = font_large.render("5가지 상점 테마", (255, 255, 255))
            screen.blit(title_surf, (20, 20))

        # 테마 정보 표시
        y_offset = 80
        font_medium = freetype_fonts.get('medium')

        for i, theme_key in enumerate(themes):
            theme = Shop.THEMES[theme_key]

            if font_medium:
                # 테마 이름
                name_surf, name_rect = font_medium.render(
                    f"{i + 1}. {theme['name']}",
                    theme['primary_color']
                )
                screen.blit(name_surf, (40, y_offset))

                # 설명
                desc_surf, desc_rect = freetype_fonts['small'].render(
                    theme['description'],
                    (150, 150, 150)
                )
                screen.blit(desc_surf, (60, y_offset + 30))

                # 색상 샘플
                pygame.draw.rect(screen, theme['primary_color'],
                               (500, y_offset, 100, 20), border_radius=5)
                pygame.draw.rect(screen, theme['secondary_color'],
                               (620, y_offset, 100, 20), border_radius=5)

                y_offset += 80

        pygame.display.flip()

    pygame.quit()

if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1:
        command = sys.argv[1]

        if command == "preview":
            # 테마 선택 미리보기
            test_theme_preview()
        elif command == "compare":
            # 모든 테마 비교
            show_all_themes_side_by_side()
        elif command in Shop.THEMES:
            # 특정 테마 테스트
            test_single_theme(command)
        else:
            print(f"알 수 없는 명령: {command}")
            print("사용법:")
            print("  python test_shop_themes.py preview     - 테마 선택 미리보기")
            print("  python test_shop_themes.py compare     - 모든 테마 비교")
            print(f"  python test_shop_themes.py <theme>    - 특정 테마 테스트")
            print(f"    가능한 테마: {', '.join(Shop.THEMES.keys())}")
    else:
        # 기본: 테마 미리보기
        test_theme_preview()
