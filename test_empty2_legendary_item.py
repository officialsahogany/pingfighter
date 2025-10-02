"""
아이템 관리자 - 전설창 Empty2 아이템
해머 아이콘을 제외한 모든 시각 효과만 표시
"""

import pygame
import math
import sys

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((1000, 700))
pygame.display.set_caption("Item Manager - Legendary Tab - Empty2 Item")
clock = pygame.time.Clock()

# 색상 정의
BACKGROUND = (30, 30, 50)  # 아이템 관리자 배경색
WHITE = (255, 255, 255)
LEGENDARY_COLOR = (255, 50, 50)
COMMON_LEGENDARY_BORDER_COLOR = (180, 200, 255)
COMMON_LEGENDARY_CORNER_COLOR = (255, 215, 0)

# 폰트
small_font = pygame.font.Font(None, 16)
font = pygame.font.Font(None, 20)
title_font = pygame.font.Font(None, 28)
label_font = pygame.font.Font(None, 24)

# 애니메이션 변수
animation_time = 0

def draw_item_slot_background(surface, x, y, size):
    """아이템 슬롯 배경"""
    slot_bg = pygame.Surface((size + 20, size + 20), pygame.SRCALPHA)
    slot_bg.fill((20, 20, 40, 200))
    pygame.draw.rect(slot_bg, (100, 100, 150), (0, 0, size + 20, size + 20), 2)
    surface.blit(slot_bg, (x - 10, y - 10))

def draw_empty2_legendary_item(surface, x, y, size, anim_time):
    """Empty2 전설 아이템 - 해머 아이콘 없이 모든 효과만"""

    # 상하 움직임 (Floating Motion)
    float_offset = int(math.sin(anim_time * 2.5) * 2)
    actual_y = y + float_offset

    # ========== 레이어 순서대로 그리기 (Bottom → Top) ==========

    # Layer 1: Blue Pulsing Glow (파란색 펄싱 배경)
    pulse = (math.sin(anim_time * 4.0) + 1) / 2
    base_radius = max(6, int(size * 0.42))
    outer_radius = min(size // 2, int(base_radius + size * 0.05 * pulse))
    inner_radius = max(4, int(outer_radius * 0.65))

    center = (x + size // 2, actual_y + size // 2)

    # 3층 구조 파란색 글로우
    pygame.draw.circle(surface, (30, 90, 170), center, outer_radius)
    pygame.draw.circle(surface, (70, 140, 200), center, int(outer_radius * 0.85))
    pygame.draw.circle(surface, (140, 190, 220), center, inner_radius)

    # Layer 2: Red Inner Borders (붉은색 내부 테두리 3중)
    inner_pulse = (math.sin(anim_time * 6.0) + 1) / 2
    outer_inner_color = (
        int(150 + 70 * inner_pulse),
        int(30 + 35 * inner_pulse),
        int(30 + 35 * inner_pulse)
    )
    mid_inner_color = (
        int(135 + 65 * inner_pulse),
        int(20 + 30 * inner_pulse),
        int(20 + 30 * inner_pulse)
    )
    inner_inner_color = (
        int(120 + 60 * inner_pulse),
        int(10 + 25 * inner_pulse),
        int(10 + 25 * inner_pulse)
    )

    inner_rect_outer = pygame.Rect(x + 2, actual_y + 2, size - 4, size - 4)
    inner_rect_mid = inner_rect_outer.inflate(-2, -2)
    inner_rect_inner = inner_rect_outer.inflate(-4, -4)

    pygame.draw.rect(surface, outer_inner_color, inner_rect_outer, 1)
    pygame.draw.rect(surface, mid_inner_color, inner_rect_mid, 1)
    pygame.draw.rect(surface, inner_inner_color, inner_rect_inner, 1)

    # Layer 3: HAMMER ICON SKIPPED (해머 아이콘 생략!)
    # 중앙에 "EMPTY" 텍스트 대신 표시
    empty_text = font.render("EMPTY", True, (100, 100, 100))
    empty_rect = empty_text.get_rect(center=(x + size//2, actual_y + size//2))
    surface.blit(empty_text, empty_rect)

    # Layer 4: Silver-Blue Frame (은색-파란색 외부 프레임)
    border_rect = pygame.Rect(x - 1, actual_y - 1, size + 2, size + 2)
    pygame.draw.rect(surface, COMMON_LEGENDARY_BORDER_COLOR, border_rect, 2)

    # Layer 5: Golden Corners (황금색 L자 코너 장식)
    corner_size = 8
    corner_color = COMMON_LEGENDARY_CORNER_COLOR

    # Top-left corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x - 2, actual_y + corner_size), (x - 2, actual_y - 2),
                      (x + corner_size, actual_y - 2)], 2)
    # Top-right corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - corner_size + 2, actual_y - 2),
                      (x + size + 2, actual_y - 2),
                      (x + size + 2, actual_y + corner_size)], 2)
    # Bottom-left corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x - 2, actual_y + size - corner_size + 2),
                      (x - 2, actual_y + size + 2),
                      (x + corner_size, actual_y + size + 2)], 2)
    # Bottom-right corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - corner_size + 2, actual_y + size + 2),
                      (x + size + 2, actual_y + size + 2),
                      (x + size + 2, actual_y + size - corner_size + 2)], 2)

    # 코너 점들
    for cx, cy in [(x, actual_y), (x + size, actual_y),
                   (x, actual_y + size), (x + size, actual_y + size)]:
        pygame.draw.circle(surface, corner_color, (cx, cy), 2)

    # Layer 6: Red Pulsing Border (빨간색 펄싱 최외곽 테두리)
    legendary_border_color = (
        int(255 * (0.5 + 0.5 * math.sin(anim_time * 3))),
        0,
        0
    )
    pygame.draw.rect(surface, legendary_border_color,
                    (x, actual_y, size, size), 3)

    # Layer 7: Corner Dots (4개 모서리 흰색 점)
    corner_positions = [
        (x, actual_y),  # Top-left
        (x + size, actual_y),  # Top-right
        (x, actual_y + size),  # Bottom-left
        (x + size, actual_y + size)  # Bottom-right
    ]

    for cx, cy in corner_positions:
        # 흰색 점
        pygame.draw.circle(surface, WHITE, (cx, cy), 3)

        # 점 주변 글로우
        glow_surf = pygame.Surface((16, 16), pygame.SRCALPHA)
        for i in range(3):
            radius = 8 - i * 2
            alpha = 50 - i * 15
            pygame.draw.circle(glow_surf, (255, 255, 255, alpha), (8, 8), radius)
        surface.blit(glow_surf, (cx - 8, cy - 8))

def draw_ui_elements(surface):
    """UI 요소들 그리기"""
    # 상단 타이틀
    title = title_font.render("아이템 관리자 - 전설", True, WHITE)
    title_rect = title.get_rect(centerx=500, top=30)
    surface.blit(title, title_rect)

    subtitle = font.render("Legendary Items Tab", True, (150, 150, 150))
    subtitle_rect = subtitle.get_rect(centerx=500, top=65)
    surface.blit(subtitle, subtitle_rect)

    # 탭 버튼 시뮬레이션
    tabs = ["일반", "희귀", "영웅", "전설"]
    tab_x = 300
    tab_y = 100

    for i, tab in enumerate(tabs):
        tab_color = LEGENDARY_COLOR if tab == "전설" else (100, 100, 100)
        tab_text = font.render(tab, True, tab_color)
        surface.blit(tab_text, (tab_x + i * 100, tab_y))

# 메인 루프
running = True

while running:
    dt = clock.tick(60) / 1000.0
    animation_time += dt

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False

    # 화면 그리기
    screen.fill(BACKGROUND)

    # UI 요소 그리기
    draw_ui_elements(screen)

    # 메인 아이템 표시 영역
    main_item_x = 400
    main_item_y = 200
    main_item_size = 128

    # 아이템 슬롯 배경
    draw_item_slot_background(screen, main_item_x, main_item_y, main_item_size)

    # Empty2 전설 아이템 그리기
    draw_empty2_legendary_item(screen, main_item_x, main_item_y, main_item_size, animation_time)

    # 아이템 이름
    item_name = label_font.render("Empty2", True, LEGENDARY_COLOR)
    name_rect = item_name.get_rect(centerx=main_item_x + main_item_size//2,
                                   top=main_item_y + main_item_size + 30)
    screen.blit(item_name, name_rect)

    # 아이템 설명
    desc_y = main_item_y + main_item_size + 70
    descriptions = [
        "전설 아이템 프레임 테스트",
        "해머 아이콘 없이 모든 효과만 표시",
        "",
        "포함된 효과:",
        "• Blue Pulsing Glow",
        "• Red Inner Borders",
        "• Silver-Blue Frame",
        "• Golden Corners",
        "• Red Pulsing Border",
        "• Corner Dots (4 white)",
        "• Floating Motion"
    ]

    for i, desc in enumerate(descriptions):
        if desc.startswith("•"):
            color = (150, 200, 255)
        elif desc == "":
            continue
        elif desc.startswith("포함"):
            color = (255, 200, 100)
        else:
            color = (180, 180, 180)

        desc_text = small_font.render(desc, True, color)
        desc_rect = desc_text.get_rect(centerx=500, top=desc_y + i * 20)
        screen.blit(desc_text, desc_rect)

    # 레이어 정보 (왼쪽)
    layer_x = 50
    layer_y = 200
    layer_title = font.render("Layer Stack:", True, (200, 200, 200))
    screen.blit(layer_title, (layer_x, layer_y))

    layers = [
        "1. Blue Pulsing",
        "2. Red Inner Borders",
        "3. [Icon Skipped]",
        "4. Silver Frame",
        "5. Golden Corners",
        "6. Red Pulsing Border",
        "7. Corner Dots",
        "+ Floating Motion"
    ]

    for i, layer in enumerate(layers):
        if "[Icon Skipped]" in layer:
            color = (100, 100, 100)
        else:
            color = (180 - i * 15, 180 - i * 15, 180 - i * 15)

        layer_text = small_font.render(layer, True, color)
        screen.blit(layer_text, (layer_x, layer_y + 30 + i * 18))

    # 애니메이션 정보 (오른쪽)
    info_x = 750
    info_y = 200
    info_title = font.render("Animation:", True, (200, 200, 200))
    screen.blit(info_title, (info_x, info_y))

    pulse = (math.sin(animation_time * 4.0) + 1) / 2
    red_pulse = 0.5 + 0.5 * math.sin(animation_time * 3)
    float_offset = int(math.sin(animation_time * 2.5) * 2)

    anim_infos = [
        f"Time: {animation_time:.2f}s",
        f"Blue Pulse: {pulse:.2f}",
        f"Red Border: {int(255 * red_pulse)}",
        f"Float Y: {float_offset:+d}px"
    ]

    for i, info in enumerate(anim_infos):
        info_text = small_font.render(info, True, (150, 150, 150))
        screen.blit(info_text, (info_x, info_y + 30 + i * 20))

    # 하단 정보
    bottom_text = small_font.render("Empty2 - Legendary Frame without Icon",
                                   True, (100, 100, 100))
    bottom_rect = bottom_text.get_rect(centerx=500, bottom=680)
    screen.blit(bottom_text, bottom_rect)

    pygame.display.flip()

pygame.quit()
sys.exit()