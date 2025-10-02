"""
Legendary Item Border System - Complete Reference
전설 아이템 테두리 시스템 - 완전 참조

All border effects identified and separated from the Ragnarok Hammer analysis
라그나로크 해머 분석에서 식별되고 분리된 모든 테두리 효과
"""

import pygame
import math
import sys

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((1400, 900))
pygame.display.set_caption("Legendary Item Border System - Complete Reference")
clock = pygame.time.Clock()

# 색상 정의
BACKGROUND = (30, 30, 50)
WHITE = (255, 255, 255)
LEGENDARY_RED = (255, 0, 0)
SILVER_BLUE = (180, 200, 255)
GOLDEN = (255, 215, 0)

# 폰트
small_font = pygame.font.Font(None, 14)
font = pygame.font.Font(None, 18)
title_font = pygame.font.Font(None, 32)
label_font = pygame.font.Font(None, 20)

# 애니메이션 변수
animation_time = 0

def draw_layer_1_blue_pulsing_glow(surface, x, y, size, anim_time):
    """Layer 1: Blue Pulsing Glow (파란색 펄싱 배경)"""
    pulse = (math.sin(anim_time * 4.0) + 1) / 2
    base_radius = max(6, int(size * 0.42))
    outer_radius = min(size // 2, int(base_radius + size * 0.05 * pulse))
    inner_radius = max(4, int(outer_radius * 0.65))

    center = (x + size // 2, y + size // 2)

    # 3층 구조 파란색 글로우
    pygame.draw.circle(surface, (30, 90, 170), center, outer_radius)
    pygame.draw.circle(surface, (70, 140, 200), center, int(outer_radius * 0.85))
    pygame.draw.circle(surface, (140, 190, 220), center, inner_radius)

def draw_layer_2_red_inner_borders(surface, x, y, size, anim_time):
    """Layer 2: Red Inner Borders (붉은색 내부 테두리 3중)"""
    inner_pulse = (math.sin(anim_time * 6.0) + 1) / 2

    outer_color = (
        int(150 + 70 * inner_pulse),
        int(30 + 35 * inner_pulse),
        int(30 + 35 * inner_pulse)
    )
    mid_color = (
        int(135 + 65 * inner_pulse),
        int(20 + 30 * inner_pulse),
        int(20 + 30 * inner_pulse)
    )
    inner_color = (
        int(120 + 60 * inner_pulse),
        int(10 + 25 * inner_pulse),
        int(10 + 25 * inner_pulse)
    )

    inner_rect_outer = pygame.Rect(x + 2, y + 2, size - 4, size - 4)
    inner_rect_mid = inner_rect_outer.inflate(-2, -2)
    inner_rect_inner = inner_rect_outer.inflate(-4, -4)

    pygame.draw.rect(surface, outer_color, inner_rect_outer, 1)
    pygame.draw.rect(surface, mid_color, inner_rect_mid, 1)
    pygame.draw.rect(surface, inner_color, inner_rect_inner, 1)

def draw_layer_4_silver_blue_frame(surface, x, y, size):
    """Layer 4: Silver-Blue Frame (은색-파란색 외부 프레임)"""
    border_rect = pygame.Rect(x - 1, y - 1, size + 2, size + 2)
    pygame.draw.rect(surface, SILVER_BLUE, border_rect, 2)

def draw_layer_5_golden_corners(surface, x, y, size):
    """Layer 5: Golden Corners (황금색 L자 코너 장식)"""
    corner_size = 8
    corner_color = GOLDEN

    # Top-left corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x - 2, y + corner_size), (x - 2, y - 2),
                      (x + corner_size, y - 2)], 2)
    # Top-right corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - corner_size + 2, y - 2),
                      (x + size + 2, y - 2),
                      (x + size + 2, y + corner_size)], 2)
    # Bottom-left corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x - 2, y + size - corner_size + 2),
                      (x - 2, y + size + 2),
                      (x + corner_size, y + size + 2)], 2)
    # Bottom-right corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - corner_size + 2, y + size + 2),
                      (x + size + 2, y + size + 2),
                      (x + size + 2, y + size - corner_size + 2)], 2)

    # 코너 점들
    for cx, cy in [(x, y), (x + size, y),
                   (x, y + size), (x + size, y + size)]:
        pygame.draw.circle(surface, corner_color, (cx, cy), 2)

def draw_layer_6_red_pulsing_border(surface, x, y, size, anim_time):
    """Layer 6: Red Pulsing Border (빨간색 펄싱 최외곽 테두리)"""
    pulse = 0.5 + 0.5 * math.sin(anim_time * 3)
    border_color = (int(255 * pulse), 0, 0)
    pygame.draw.rect(surface, border_color, (x, y, size, size), 3)

def draw_layer_7_corner_dots(surface, x, y, size):
    """Layer 7: Corner Dots (4개 모서리 흰색 점)"""
    corner_positions = [
        (x, y),  # Top-left
        (x + size, y),  # Top-right
        (x, y + size),  # Bottom-left
        (x + size, y + size)  # Bottom-right
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

def draw_floating_motion(y, anim_time):
    """Floating Motion (상하 움직임)"""
    return int(math.sin(anim_time * 2.5) * 2)

def draw_complete_border_system(surface, x, y, size, anim_time):
    """Complete Legendary Border System - All Layers Combined"""
    # Apply floating motion
    float_offset = draw_floating_motion(y, anim_time)
    actual_y = y + float_offset

    # Draw all layers in order
    draw_layer_1_blue_pulsing_glow(surface, x, actual_y, size, anim_time)
    draw_layer_2_red_inner_borders(surface, x, actual_y, size, anim_time)
    # Layer 3: Icon (skipped in this reference)
    draw_layer_4_silver_blue_frame(surface, x, actual_y, size)
    draw_layer_5_golden_corners(surface, x, actual_y, size)
    draw_layer_6_red_pulsing_border(surface, x, actual_y, size, anim_time)
    draw_layer_7_corner_dots(surface, x, actual_y, size)

def draw_individual_layers(surface, start_x, start_y, size, anim_time):
    """Draw each layer separately for reference"""
    spacing_x = size + 40
    spacing_y = size + 80

    layers = [
        ("Layer 1: Blue Pulsing Glow", draw_layer_1_blue_pulsing_glow, True),
        ("Layer 2: Red Inner Borders", draw_layer_2_red_inner_borders, True),
        ("Layer 4: Silver-Blue Frame", draw_layer_4_silver_blue_frame, False),
        ("Layer 5: Golden Corners", draw_layer_5_golden_corners, False),
        ("Layer 6: Red Pulsing Border", draw_layer_6_red_pulsing_border, True),
        ("Layer 7: Corner Dots", draw_layer_7_corner_dots, False),
    ]

    for i, (name, draw_func, uses_anim) in enumerate(layers):
        row = i // 3
        col = i % 3
        x = start_x + col * spacing_x
        y = start_y + row * spacing_y

        # Background box
        box = pygame.Surface((size + 20, size + 60), pygame.SRCALPHA)
        box.fill((40, 40, 60, 100))
        surface.blit(box, (x - 10, y - 10))

        # Draw layer
        if uses_anim:
            draw_func(surface, x, y, size, anim_time)
        else:
            draw_func(surface, x, y, size)

        # Label
        label = label_font.render(name, True, WHITE)
        label_rect = label.get_rect(centerx=x + size//2, top=y + size + 10)
        surface.blit(label, label_rect)

def draw_combination_showcase(surface, x, y, size, anim_time):
    """Show progressive combination of layers"""
    spacing = size + 40

    combinations = [
        ("Base", [1]),  # Just blue glow
        ("+ Inner", [1, 2]),  # Blue glow + red inner
        ("+ Frame", [1, 2, 4]),  # + Silver frame
        ("+ Corners", [1, 2, 4, 5]),  # + Golden corners
        ("+ Border", [1, 2, 4, 5, 6]),  # + Red border
        ("Complete", [1, 2, 4, 5, 6, 7]),  # + Corner dots
    ]

    for i, (name, layers_to_draw) in enumerate(combinations):
        item_x = x + (i % 3) * spacing
        item_y = y + (i // 3) * (size + 80)

        # Background
        box = pygame.Surface((size + 20, size + 60), pygame.SRCALPHA)
        box.fill((40, 40, 60, 100))
        surface.blit(box, (item_x - 10, item_y - 10))

        # Apply floating motion to all
        float_offset = draw_floating_motion(item_y, anim_time)
        actual_y = item_y + float_offset

        # Draw selected layers
        for layer_num in layers_to_draw:
            if layer_num == 1:
                draw_layer_1_blue_pulsing_glow(surface, item_x, actual_y, size, anim_time)
            elif layer_num == 2:
                draw_layer_2_red_inner_borders(surface, item_x, actual_y, size, anim_time)
            elif layer_num == 4:
                draw_layer_4_silver_blue_frame(surface, item_x, actual_y, size)
            elif layer_num == 5:
                draw_layer_5_golden_corners(surface, item_x, actual_y, size)
            elif layer_num == 6:
                draw_layer_6_red_pulsing_border(surface, item_x, actual_y, size, anim_time)
            elif layer_num == 7:
                draw_layer_7_corner_dots(surface, item_x, actual_y, size)

        # Label
        label = label_font.render(name, True, WHITE)
        label_rect = label.get_rect(centerx=item_x + size//2, top=item_y + size + 10)
        surface.blit(label, label_rect)

# Main loop
running = True
show_mode = 0  # 0: Individual, 1: Combination, 2: Complete

while running:
    dt = clock.tick(60) / 1000.0
    animation_time += dt

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                show_mode = (show_mode + 1) % 3

    # Clear screen
    screen.fill(BACKGROUND)

    # Title
    title = title_font.render("Legendary Item Border System", True, WHITE)
    title_rect = title.get_rect(centerx=700, top=20)
    screen.blit(title, title_rect)

    subtitle_text = ["Individual Layers", "Progressive Combination", "Complete System"][show_mode]
    subtitle = font.render(f"Mode: {subtitle_text} (Press SPACE to switch)", True, (200, 200, 200))
    subtitle_rect = subtitle.get_rect(centerx=700, top=60)
    screen.blit(subtitle, subtitle_rect)

    # Draw based on mode
    if show_mode == 0:
        # Individual layers
        draw_individual_layers(screen, 100, 120, 100, animation_time)
    elif show_mode == 1:
        # Progressive combination
        draw_combination_showcase(screen, 100, 120, 100, animation_time)
    else:
        # Complete system
        main_x = 300
        main_y = 200
        main_size = 200

        # Large complete example
        draw_complete_border_system(screen, main_x, main_y, main_size, animation_time)

        # Label
        complete_label = label_font.render("Complete Border System", True, WHITE)
        label_rect = complete_label.get_rect(centerx=main_x + main_size//2, top=main_y + main_size + 20)
        screen.blit(complete_label, label_rect)

        # Technical info
        info_x = 600
        info_y = 200

        info_title = label_font.render("Layer Stack:", True, (200, 200, 200))
        screen.blit(info_title, (info_x, info_y))

        layers_info = [
            "1. Blue Pulsing Glow",
            "2. Red Inner Borders (3x)",
            "3. [Icon Layer - Not Shown]",
            "4. Silver-Blue Frame",
            "5. Golden Corners (L-shaped)",
            "6. Red Pulsing Border",
            "7. Corner Dots (4 white)",
            "+ Floating Motion"
        ]

        for i, info in enumerate(layers_info):
            if "[Icon" in info:
                color = (100, 100, 100)
            else:
                color = (180, 180, 180)
            info_text = font.render(info, True, color)
            screen.blit(info_text, (info_x, info_y + 30 + i * 20))

    # Animation info
    anim_info = small_font.render(
        f"Time: {animation_time:.2f}s | Pulse: {(math.sin(animation_time * 3) + 1) / 2:.2f}",
        True, (150, 150, 150)
    )
    anim_rect = anim_info.get_rect(right=1380, bottom=880)
    screen.blit(anim_info, anim_rect)

    # Instructions
    instructions = small_font.render("Press SPACE to switch modes | ESC to exit", True, (150, 150, 150))
    inst_rect = instructions.get_rect(left=20, bottom=880)
    screen.blit(instructions, inst_rect)

    pygame.display.flip()

pygame.quit()
sys.exit()