#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# downtown/preview_shop_designs.py
# 5가지 상점 건물 디자인 미리보기 (UHD 초고퀄리티)

import pygame
import pygame.freetype
import os
import sys
import math

# 부모 디렉토리를 sys.path에 추가
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

from downtown.constants import (
    SCREEN_WIDTH, SCREEN_HEIGHT, resource_path,
    SHOP_DESIGNS, Colors
)
from downtown.building_designs import BuildingDesigner

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
        freetype_fonts['large'] = pygame.freetype.Font(font, 36)
        freetype_fonts['medium'] = pygame.freetype.Font(font, 24)
        freetype_fonts['small'] = pygame.freetype.Font(font, 18)
        freetype_fonts['tiny'] = pygame.freetype.Font(font, 14)
    except:
        freetype_fonts['large'] = pygame.freetype.SysFont(None, 36)
        freetype_fonts['medium'] = pygame.freetype.SysFont(None, 24)
        freetype_fonts['small'] = pygame.freetype.SysFont(None, 18)
        freetype_fonts['tiny'] = pygame.freetype.SysFont(None, 14)

    return freetype_fonts

class DummyBuilding:
    """BuildingDesigner 테스트용 더미 건물 클래스"""
    def __init__(self, building_type, x, y, width=100, height=100):
        self.type = building_type
        self.x = x
        self.y = y
        self.width = width
        self.height = height

def draw_shop_card(screen, x, y, design_key, design, fonts, designer, selected=False, animation_timer=0):
    """상점 디자인 카드 그리기 (UHD 초고퀄리티 렌더링)"""
    width, height = 200, 220
    building_width = 120
    building_height = 120

    # 카드 배경
    card_rect = pygame.Rect(x, y, width, height)
    if selected:
        # 선택된 카드 글로우
        for i in range(5):
            glow_offset = i * 3
            glow_alpha = int(150 / (i + 1))
            glow_surf = pygame.Surface((width + glow_offset * 2, height + glow_offset * 2), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*design["color"], glow_alpha),
                           (0, 0, width + glow_offset * 2, height + glow_offset * 2),
                           border_radius=20 + i)
            screen.blit(glow_surf, (x - glow_offset, y - glow_offset))

        pygame.draw.rect(screen, (*design["color"], 180), card_rect, border_radius=15)
        pygame.draw.rect(screen, design["color"], card_rect, 4, border_radius=15)
    else:
        pygame.draw.rect(screen, (40, 40, 50), card_rect, border_radius=15)
        pygame.draw.rect(screen, (70, 70, 80), card_rect, 2, border_radius=15)

    # 건물 그리기 영역 (BuildingDesigner 사용)
    building_x = x + (width - building_width) // 2
    building_y = y + 20

    # 더미 건물 객체 생성
    dummy_building = DummyBuilding("item_shop", building_x, building_y, building_width, building_height)

    # BuildingDesigner의 애니메이션 타이머 설정
    designer.animation_timer = animation_timer

    # 스타일별 고퀄리티 렌더링
    style = design["style"]
    pulse = 0.8 + 0.2 * abs(math.sin(animation_timer * 2))
    glow = abs(math.sin(animation_timer * 1.5))

    if style == "cyberpunk":
        designer._draw_cyberpunk_shop(screen, building_x, building_y, building_width, building_height, design, pulse, glow)
    elif style == "fantasy":
        designer._draw_fantasy_shop(screen, building_x, building_y, building_width, building_height, design, pulse, glow)
    elif style == "steampunk":
        designer._draw_steampunk_shop(screen, building_x, building_y, building_width, building_height, design, pulse, glow)
    elif style == "nature":
        designer._draw_nature_shop(screen, building_x, building_y, building_width, building_height, design, pulse, glow)
    elif style == "luxury":
        designer._draw_luxury_shop(screen, building_x, building_y, building_width, building_height, design, pulse, glow)

    # 아이콘
    icon_surf, icon_rect = fonts['large'].render(design["icon"], design["color"])
    icon_x = x + (width - icon_rect.width) // 2
    screen.blit(icon_surf, (icon_x, building_y + building_height + 5))

    # 이름
    name_surf, name_rect = fonts['medium'].render(design["name"], Colors.TEXT_WHITE)
    name_x = x + (width - name_rect.width) // 2
    screen.blit(name_surf, (name_x, y + height - 55))

    # 설명 (2줄)
    desc_words = design["description"].split()
    line1 = " ".join(desc_words[:2])
    line2 = " ".join(desc_words[2:]) if len(desc_words) > 2 else ""

    desc1_surf, desc1_rect = fonts['tiny'].render(line1, Colors.TEXT_GRAY)
    desc1_x = x + (width - desc1_rect.width) // 2
    screen.blit(desc1_surf, (desc1_x, y + height - 33))

    if line2:
        desc2_surf, desc2_rect = fonts['tiny'].render(line2, Colors.TEXT_GRAY)
        desc2_x = x + (width - desc2_rect.width) // 2
        screen.blit(desc2_surf, (desc2_x, y + height - 15))

def main():
    """메인 함수"""
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH * 2, SCREEN_HEIGHT + 100))
    pygame.display.set_caption("상점 건물 디자인 - UHD 초고퀄리티 미리보기")
    clock = pygame.time.Clock()

    fonts = init_fonts()
    designer = BuildingDesigner()

    designs = list(SHOP_DESIGNS.items())
    selected = 0
    running = True
    animation_time = 0

    print("\n" + "=" * 80)
    print("상점 건물 디자인 미리보기 (UHD 초고퀄리티)")
    print("=" * 80)
    print("\n5가지 디자인:")
    for i, (key, design) in enumerate(designs, 1):
        print(f"\n{i}. {design['name']} ({key})")
        print(f"   {design['description']}")
        print(f"   주색상: RGB{design['color']}")
        print(f"   부색상: RGB{design['secondary_color']}")
        print(f"   스타일: {design['style']}")

    print("\n" + "=" * 80)
    print("조작법:")
    print("  [← →] 선택")
    print("  [ENTER] 확정")
    print("  [ESC] 취소")
    print("=" * 80)

    while running:
        dt = clock.tick(60) / 1000.0  # 60 FPS
        animation_time += dt

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return None

            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return None
                elif event.key == pygame.K_LEFT:
                    selected = (selected - 1) % len(designs)
                elif event.key == pygame.K_RIGHT:
                    selected = (selected + 1) % len(designs)
                elif event.key == pygame.K_RETURN:
                    design_key = designs[selected][0]
                    print(f"\n✅ 선택됨: {designs[selected][1]['name']} ({design_key})")
                    print(f"\n📝 constants.py에서 다음과 같이 설정하세요:")
                    print(f"   SELECTED_SHOP_DESIGN = \"{design_key}\"")
                    return design_key

        # 배경 (그라데이션)
        for i in range(SCREEN_HEIGHT + 100):
            gradient_ratio = i / (SCREEN_HEIGHT + 100)
            bg_color = (
                int(20 + 10 * gradient_ratio),
                int(20 + 10 * gradient_ratio),
                int(30 + 20 * gradient_ratio)
            )
            pygame.draw.line(screen, bg_color, (0, i), (SCREEN_WIDTH * 2, i))

        # 제목
        title_surf, title_rect = fonts['large'].render(
            "상점 건물 디자인 - UHD 초고퀄리티", Colors.TEXT_WHITE
        )
        screen.blit(title_surf, ((SCREEN_WIDTH * 2 - title_rect.width) // 2, 30))

        # 부제
        subtitle_surf, subtitle_rect = fonts['small'].render(
            "5가지 디자인 중 하나를 선택하세요 (실시간 애니메이션)", Colors.TEXT_GRAY
        )
        screen.blit(subtitle_surf, ((SCREEN_WIDTH * 2 - subtitle_rect.width) // 2, 75))

        # 상점 디자인들 (한 줄에 3개, 두 번째 줄에 2개)
        row1_designs = designs[:3]
        row2_designs = designs[3:]

        # 첫 번째 줄
        start_x = 120
        start_y = 130
        spacing = 240

        for i, (key, design) in enumerate(row1_designs):
            x = start_x + i * spacing
            is_selected = (i == selected)
            draw_shop_card(screen, x, start_y, key, design, fonts, designer, is_selected, animation_time)

        # 두 번째 줄
        start_y2 = start_y + 260
        start_x2 = start_x + spacing  # 2개만 있으므로 중앙 정렬

        for i, (key, design) in enumerate(row2_designs):
            x = start_x2 + i * spacing
            is_selected = (i + 3 == selected)
            draw_shop_card(screen, x, start_y2, key, design, fonts, designer, is_selected, animation_time)

        # 선택된 디자인 정보
        selected_design = designs[selected][1]
        info_y = SCREEN_HEIGHT + 100 - 130

        # 정보 패널 배경
        info_panel = pygame.Rect(50, info_y - 10, SCREEN_WIDTH * 2 - 100, 110)
        pygame.draw.rect(screen, (30, 30, 40, 200), info_panel, border_radius=15)
        pygame.draw.rect(screen, selected_design["color"], info_panel, 2, border_radius=15)

        # 큰 아이콘
        icon_surf, icon_rect = fonts['large'].render(
            selected_design["icon"], selected_design["color"]
        )
        screen.blit(icon_surf, (SCREEN_WIDTH - 50, info_y + 10))

        # 이름
        name_surf, name_rect = fonts['medium'].render(
            f"선택: {selected_design['name']}", selected_design["color"]
        )
        screen.blit(name_surf, (SCREEN_WIDTH - 30, info_y + 20))

        # 설명
        desc_surf, desc_rect = fonts['small'].render(
            selected_design['description'], Colors.TEXT_GRAY
        )
        screen.blit(desc_surf, (SCREEN_WIDTH - 30, info_y + 55))

        # 스타일 정보
        style_text = f"스타일: {selected_design['style'].upper()}"
        style_surf, style_rect = fonts['tiny'].render(style_text, Colors.TEXT_GRAY)
        screen.blit(style_surf, (SCREEN_WIDTH - 30, info_y + 80))

        # 하단 안내
        hint_text = "[← →] 선택  [ENTER] 확정  [ESC] 취소"
        hint_surf, hint_rect = fonts['small'].render(hint_text, Colors.TEXT_GRAY)
        screen.blit(hint_surf, ((SCREEN_WIDTH * 2 - hint_rect.width) // 2, SCREEN_HEIGHT + 100 - 50))

        pygame.display.flip()

    return None

if __name__ == "__main__":
    result = main()
    pygame.quit()

    if result:
        print(f"\n✨ 선택 완료! 디자인 키: {result}")
    else:
        print("\n❌ 선택 취소됨")
