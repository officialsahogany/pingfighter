#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# downtown/preview_shop_designs.py
# 5가지 상점 건물 디자인 미리보기

import pygame
import pygame.freetype
import os
import sys

# 부모 디렉토리를 sys.path에 추가
parent_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if parent_dir not in sys.path:
    sys.path.insert(0, parent_dir)

from downtown.constants import (
    SCREEN_WIDTH, SCREEN_HEIGHT, resource_path,
    SHOP_DESIGNS, Colors
)

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

def draw_shop_building(screen, x, y, design, fonts, selected=False):
    """상점 건물 시각화"""
    width, height = 160, 180
    building_width = 100
    building_height = 100

    # 카드 배경
    card_rect = pygame.Rect(x, y, width, height)
    if selected:
        pygame.draw.rect(screen, (*design["color"], 150), card_rect, border_radius=15)
        pygame.draw.rect(screen, design["color"], card_rect, 3, border_radius=15)
    else:
        pygame.draw.rect(screen, (40, 40, 50), card_rect, border_radius=15)
        pygame.draw.rect(screen, (70, 70, 80), card_rect, 1, border_radius=15)

    # 건물 그리기 영역
    building_x = x + (width - building_width) // 2
    building_y = y + 15

    # 스타일별 건물 그리기
    style = design["style"]

    if style == "cyberpunk":
        # 네온 박스
        box_rect = pygame.Rect(building_x + 15, building_y + 20, building_width - 30, building_height - 30)
        pygame.draw.rect(screen, (50, 50, 80), box_rect, border_radius=8)
        pygame.draw.rect(screen, design["color"], box_rect, 3, border_radius=8)

        # 네온 라인
        for i in range(3):
            line_y = building_y + 30 + i * 15
            pygame.draw.line(screen, design["secondary_color"],
                           (building_x + 25, line_y), (building_x + building_width - 25, line_y), 2)

    elif style == "fantasy":
        # 마법 성소 형태
        tower_width = building_width - 30
        tower_height = building_height - 20

        # 메인 타워
        tower_rect = pygame.Rect(building_x + 15, building_y + 10, tower_width, tower_height)
        pygame.draw.rect(screen, (60, 40, 100), tower_rect, border_radius=5)
        pygame.draw.rect(screen, design["color"], tower_rect, 2, border_radius=5)

        # 지붕 (삼각형)
        roof_points = [
            (building_x + width // 2 - 50, building_y + 10),
            (building_x + width // 2 - 75, building_y - 10),
            (building_x + width // 2 - 25, building_y - 10)
        ]
        pygame.draw.polygon(screen, design["secondary_color"], roof_points)

        # 마법진
        import math
        cx = building_x + tower_width // 2 + 15
        cy = building_y + tower_height // 2 + 10
        pygame.draw.circle(screen, design["secondary_color"], (cx, cy), 15, 2)

    elif style == "steampunk":
        # 기계식 박스
        box_rect = pygame.Rect(building_x + 15, building_y + 20, building_width - 30, building_height - 30)
        pygame.draw.rect(screen, (80, 60, 40), box_rect, border_radius=5)
        pygame.draw.rect(screen, design["color"], box_rect, 2, border_radius=5)

        # 기어 장식
        gear_x = building_x + building_width // 2
        gear_y = building_y + building_height // 2
        pygame.draw.circle(screen, design["secondary_color"], (gear_x, gear_y), 20, 3)
        pygame.draw.circle(screen, design["color"], (gear_x, gear_y), 10, 2)

    elif style == "nature":
        # 목조 건물
        house_rect = pygame.Rect(building_x + 15, building_y + 25, building_width - 30, building_height - 35)
        pygame.draw.rect(screen, (139, 90, 43), house_rect, border_radius=8)
        pygame.draw.rect(screen, design["color"], house_rect, 2, border_radius=8)

        # 지붕
        roof_points = [
            (building_x + 15, building_y + 25),
            (building_x + width // 2 - 50, building_y),
            (building_x + building_width, building_y + 25)
        ]
        pygame.draw.polygon(screen, design["secondary_color"], roof_points)

        # 나뭇잎 장식
        leaf_x = building_x + 25
        leaf_y = building_y + 10
        pygame.draw.circle(screen, design["color"], (leaf_x, leaf_y), 5)

    elif style == "luxury":
        # 고급스러운 건물
        box_rect = pygame.Rect(building_x + 10, building_y + 15, building_width - 20, building_height - 25)
        pygame.draw.rect(screen, (50, 45, 40), box_rect, border_radius=10)
        pygame.draw.rect(screen, design["color"], box_rect, 3, border_radius=10)

        # 황금 테두리
        inner_rect = pygame.Rect(building_x + 15, building_y + 20, building_width - 30, building_height - 35)
        pygame.draw.rect(screen, design["secondary_color"], inner_rect, 2, border_radius=8)

        # 다이아몬드
        import math
        diamond_cx = building_x + building_width // 2
        diamond_cy = building_y + building_height // 2
        diamond_points = [
            (diamond_cx, diamond_cy - 15),
            (diamond_cx - 10, diamond_cy),
            (diamond_cx, diamond_cy + 15),
            (diamond_cx + 10, diamond_cy)
        ]
        pygame.draw.polygon(screen, design["secondary_color"], diamond_points, 2)

    # 아이콘
    icon_surf, icon_rect = fonts['large'].render(design["icon"], design["color"])
    icon_x = x + (width - icon_rect.width) // 2
    screen.blit(icon_surf, (icon_x, building_y + building_height - 15))

    # 이름
    name_surf, name_rect = fonts['medium'].render(design["name"], Colors.TEXT_WHITE)
    name_x = x + (width - name_rect.width) // 2
    screen.blit(name_surf, (name_x, y + height - 50))

    # 설명 (작게)
    desc_words = design["description"].split()
    line1 = " ".join(desc_words[:2])
    line2 = " ".join(desc_words[2:]) if len(desc_words) > 2 else ""

    desc1_surf, desc1_rect = fonts['tiny'].render(line1, Colors.TEXT_GRAY)
    desc1_x = x + (width - desc1_rect.width) // 2
    screen.blit(desc1_surf, (desc1_x, y + height - 28))

    if line2:
        desc2_surf, desc2_rect = fonts['tiny'].render(line2, Colors.TEXT_GRAY)
        desc2_x = x + (width - desc2_rect.width) // 2
        screen.blit(desc2_surf, (desc2_x, y + height - 12))

def main():
    """메인 함수"""
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH * 2, SCREEN_HEIGHT))
    pygame.display.set_caption("상점 건물 디자인 선택 (5가지)")
    clock = pygame.time.Clock()

    fonts = init_fonts()

    designs = list(SHOP_DESIGNS.items())
    selected = 0
    running = True

    print("\n" + "=" * 80)
    print("상점 건물 디자인 미리보기")
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
        clock.tick(60)

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

        # 배경
        screen.fill((20, 20, 30))

        # 제목
        title_surf, title_rect = fonts['large'].render(
            "상점 건물 디자인 선택", Colors.TEXT_WHITE
        )
        screen.blit(title_surf, ((SCREEN_WIDTH * 2 - title_rect.width) // 2, 30))

        # 부제
        subtitle_surf, subtitle_rect = fonts['small'].render(
            "5가지 디자인 중 하나를 선택하세요", Colors.TEXT_GRAY
        )
        screen.blit(subtitle_surf, ((SCREEN_WIDTH * 2 - subtitle_rect.width) // 2, 75))

        # 상점 디자인들 (한 줄에 3개씩)
        row1_designs = designs[:3]
        row2_designs = designs[3:]

        # 첫 번째 줄
        start_x = 100
        start_y = 130
        spacing = 200

        for i, (key, design) in enumerate(row1_designs):
            x = start_x + i * spacing
            is_selected = (i == selected)
            draw_shop_building(screen, x, start_y, design, fonts, is_selected)

        # 두 번째 줄
        start_y2 = start_y + 220
        start_x2 = start_x + spacing  # 2개만 있으므로 중앙 정렬

        for i, (key, design) in enumerate(row2_designs):
            x = start_x2 + i * spacing
            is_selected = (i + 3 == selected)
            draw_shop_building(screen, x, start_y2, design, fonts, is_selected)

        # 선택된 디자인 정보
        selected_design = designs[selected][1]
        info_y = SCREEN_HEIGHT - 120

        # 큰 아이콘
        icon_surf, icon_rect = fonts['large'].render(
            selected_design["icon"], selected_design["color"]
        )
        screen.blit(icon_surf, (SCREEN_WIDTH - 50, info_y))

        # 이름
        name_surf, name_rect = fonts['medium'].render(
            f"선택: {selected_design['name']}", selected_design["color"]
        )
        screen.blit(name_surf, (SCREEN_WIDTH - 30, info_y + 10))

        # 설명
        desc_surf, desc_rect = fonts['small'].render(
            selected_design['description'], Colors.TEXT_GRAY
        )
        screen.blit(desc_surf, (SCREEN_WIDTH - 30, info_y + 45))

        # 하단 안내
        hint_text = "[← →] 선택  [ENTER] 확정  [ESC] 취소"
        hint_surf, hint_rect = fonts['small'].render(hint_text, Colors.TEXT_GRAY)
        screen.blit(hint_surf, ((SCREEN_WIDTH * 2 - hint_rect.width) // 2, SCREEN_HEIGHT - 50))

        pygame.display.flip()

    return None

if __name__ == "__main__":
    result = main()
    pygame.quit()

    if result:
        print(f"\n✨ 선택 완료! 디자인 키: {result}")
    else:
        print("\n❌ 선택 취소됨")
