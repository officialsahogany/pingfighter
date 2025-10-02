"""
라그나로크 해머 시각 효과 전체 분해 분석
모든 레이어별 시각 요소를 개별적으로 표시
"""

import pygame
import math
import sys
import os

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((1200, 800))
pygame.display.set_caption("Ragnarok Hammer Visual Components Analysis")
clock = pygame.time.Clock()

# 색상 정의
BACKGROUND = (30, 30, 50)
WHITE = (255, 255, 255)
RED = (255, 0, 0)
YELLOW = (255, 200, 0)
BLUE = (100, 150, 255)

# 폰트 설정
font = pygame.font.Font(None, 20)
title_font = pygame.font.Font(None, 28)
small_font = pygame.font.Font(None, 16)

# 애니메이션 시간
animation_time = 0

def draw_component_label(surface, x, y, width, title, description):
    """컴포넌트 라벨 그리기"""
    title_surf = font.render(title, True, WHITE)
    title_rect = title_surf.get_rect(centerx=x + width//2, top=y - 35)
    surface.blit(title_surf, title_rect)

    desc_surf = small_font.render(description, True, (150, 150, 150))
    desc_rect = desc_surf.get_rect(centerx=x + width//2, top=y - 15)
    surface.blit(desc_surf, desc_rect)

def draw_1_blue_glow(surface, x, y, size, anim_time):
    """1. 파란색 원형 글로우 배경 (펄싱)"""
    pulse = (math.sin(anim_time * 4.0) + 1) / 2
    base_radius = int(size * 0.42)
    outer_radius = int(base_radius + size * 0.05 * pulse)
    inner_radius = int(outer_radius * 0.65)

    center = (x + size//2, y + size//2)

    # 3층 구조의 파란색 글로우
    pygame.draw.circle(surface, (30, 90, 170, 80), center, outer_radius)
    pygame.draw.circle(surface, (70, 140, 200, 150), center, int(outer_radius * 0.85))
    pygame.draw.circle(surface, (140, 190, 220, 190), center, inner_radius)

    draw_component_label(surface, x, y, size, "1. Blue Glow", "Pulsing circular background")

def draw_2_red_inner_borders(surface, x, y, size, anim_time):
    """2. 내부 붉은색 테두리 (3중 그라데이션)"""
    inner_pulse = (math.sin(anim_time * 6.0) + 1) / 2

    # 3중 테두리 색상 (바깥쪽부터)
    outer_color = (int(150 + 70 * inner_pulse), int(30 + 35 * inner_pulse), int(30 + 35 * inner_pulse))
    mid_color = (int(135 + 65 * inner_pulse), int(20 + 30 * inner_pulse), int(20 + 30 * inner_pulse))
    inner_color = (int(120 + 60 * inner_pulse), int(10 + 25 * inner_pulse), int(10 + 25 * inner_pulse))

    # 3개의 사각형 테두리
    pygame.draw.rect(surface, outer_color, (x + 2, y + 2, size - 4, size - 4), 1)
    pygame.draw.rect(surface, mid_color, (x + 4, y + 4, size - 8, size - 8), 1)
    pygame.draw.rect(surface, inner_color, (x + 6, y + 6, size - 12, size - 12), 1)

    draw_component_label(surface, x, y, size, "2. Red Inner Borders", "Triple gradient pulsing")

def draw_3_outer_frame(surface, x, y, size, anim_time):
    """3. 외부 프레임 (은색/파란색 정적)"""
    border_color = (180, 200, 255)  # 연한 파란색-은색
    border_rect = pygame.Rect(x - 1, y - 1, size + 2, size + 2)
    pygame.draw.rect(surface, border_color, border_rect, 2)

    draw_component_label(surface, x, y, size, "3. Outer Frame", "Static silver-blue border")

def draw_4_corner_highlights(surface, x, y, size, anim_time):
    """4. 황금색 코너 하이라이트 (L자 형태)"""
    corner_color = (255, 215, 0)  # 황금색
    corner_size = 8

    # Top-left corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x, y + corner_size), (x, y), (x + corner_size, y)], 2)
    # Top-right corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - corner_size, y), (x + size, y), (x + size, y + corner_size)], 2)
    # Bottom-left corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x, y + size - corner_size), (x, y + size), (x + corner_size, y + size)], 2)
    # Bottom-right corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - corner_size, y + size), (x + size, y + size), (x + size, y + size - corner_size)], 2)

    # 코너 점들
    for cx, cy in [(x, y), (x + size, y), (x, y + size), (x + size, y + size)]:
        pygame.draw.circle(surface, corner_color, (cx, cy), 2)

    draw_component_label(surface, x, y, size, "4. Corner Highlights", "Golden L-shaped corners")

def draw_5_legendary_border(surface, x, y, size, anim_time):
    """5. 전설 테두리 (빨간색 펄싱)"""
    border_color = (
        int(255 * (0.5 + 0.5 * math.sin(anim_time * 3))),
        0,
        0
    )
    pygame.draw.rect(surface, border_color, (x, y, size, size), 3)

    draw_component_label(surface, x, y, size, "5. Legendary Border", f"Pulsing red (R={border_color[0]})")

def draw_6_hammer_icon(surface, x, y, size, anim_time):
    """6. 해머 아이콘 (중앙)"""
    # 해머 아이콘 시뮬레이션
    icon_size = int(size * 0.6)
    icon_x = x + (size - icon_size) // 2
    icon_y = y + (size - icon_size) // 2

    # 해머 머리 부분
    hammer_head = pygame.Rect(icon_x, icon_y, icon_size, icon_size // 2)
    pygame.draw.rect(surface, (150, 150, 150), hammer_head)
    pygame.draw.rect(surface, (200, 200, 200), hammer_head, 2)

    # 해머 손잡이
    handle_width = icon_size // 4
    handle_x = icon_x + (icon_size - handle_width) // 2
    handle_y = icon_y + icon_size // 2
    handle = pygame.Rect(handle_x, handle_y, handle_width, icon_size // 2)
    pygame.draw.rect(surface, (100, 70, 50), handle)
    pygame.draw.rect(surface, (70, 50, 30), handle, 1)

    draw_component_label(surface, x, y, size, "6. Hammer Icon", "Central item icon")

def draw_7_floating_animation(surface, x, y, size, anim_time):
    """7. 상하 움직임 애니메이션"""
    offset = int(math.sin(anim_time * 2.5) * 2)

    # 움직임 표시용 박스
    box = pygame.Surface((size, size), pygame.SRCALPHA)
    box.fill((100, 100, 100, 100))
    surface.blit(box, (x, y + offset))

    # 움직임 방향 표시
    arrow_x = x + size + 10
    if offset > 0:
        pygame.draw.polygon(surface, YELLOW,
                           [(arrow_x, y + size//2),
                            (arrow_x - 5, y + size//2 - 10),
                            (arrow_x + 5, y + size//2 - 10)])
    else:
        pygame.draw.polygon(surface, YELLOW,
                           [(arrow_x, y + size//2),
                            (arrow_x - 5, y + size//2 + 10),
                            (arrow_x + 5, y + size//2 + 10)])

    draw_component_label(surface, x, y, size, "7. Float Animation", f"Y offset: {offset}px")

def draw_8_complete_effect(surface, x, y, size, anim_time):
    """8. 모든 효과 결합"""
    # 모든 레이어를 순서대로 그리기
    offset = int(math.sin(anim_time * 2.5) * 2)
    actual_y = y + offset

    # 1. 파란색 글로우
    pulse = (math.sin(anim_time * 4.0) + 1) / 2
    base_radius = int(size * 0.42)
    outer_radius = int(base_radius + size * 0.05 * pulse)
    center = (x + size//2, actual_y + size//2)
    pygame.draw.circle(surface, (30, 90, 170), center, outer_radius)
    pygame.draw.circle(surface, (70, 140, 200), center, int(outer_radius * 0.85))
    pygame.draw.circle(surface, (140, 190, 220), center, int(outer_radius * 0.65))

    # 2. 내부 붉은 테두리
    inner_pulse = (math.sin(anim_time * 6.0) + 1) / 2
    red_color = (int(150 + 70 * inner_pulse), int(30 + 35 * inner_pulse), int(30 + 35 * inner_pulse))
    pygame.draw.rect(surface, red_color, (x + 2, actual_y + 2, size - 4, size - 4), 1)
    pygame.draw.rect(surface, red_color, (x + 4, actual_y + 4, size - 8, size - 8), 1)
    pygame.draw.rect(surface, red_color, (x + 6, actual_y + 6, size - 12, size - 12), 1)

    # 3. 외부 프레임
    pygame.draw.rect(surface, (180, 200, 255), (x - 1, actual_y - 1, size + 2, size + 2), 2)

    # 4. 코너 하이라이트
    corner_color = (255, 215, 0)
    cs = 8
    pygame.draw.lines(surface, corner_color, False,
                     [(x, actual_y + cs), (x, actual_y), (x + cs, actual_y)], 2)
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - cs, actual_y), (x + size, actual_y), (x + size, actual_y + cs)], 2)
    pygame.draw.lines(surface, corner_color, False,
                     [(x, actual_y + size - cs), (x, actual_y + size), (x + cs, actual_y + size)], 2)
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - cs, actual_y + size), (x + size, actual_y + size), (x + size, actual_y + size - cs)], 2)

    # 5. 전설 테두리
    legendary_color = (int(255 * (0.5 + 0.5 * math.sin(anim_time * 3))), 0, 0)
    pygame.draw.rect(surface, legendary_color, (x, actual_y, size, size), 3)

    # 6. 해머 아이콘
    icon_size = int(size * 0.6)
    icon_x = x + (size - icon_size) // 2
    icon_y = actual_y + (size - icon_size) // 2
    hammer_head = pygame.Rect(icon_x, icon_y, icon_size, icon_size // 2)
    pygame.draw.rect(surface, (150, 150, 150), hammer_head)
    handle = pygame.Rect(icon_x + icon_size//3, icon_y + icon_size//2, icon_size//3, icon_size//2)
    pygame.draw.rect(surface, (100, 70, 50), handle)

    draw_component_label(surface, x, y, size, "8. Complete Effect", "All layers combined")

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

    # 제목
    title = title_font.render("Ragnarok Hammer - Visual Components Breakdown", True, WHITE)
    title_rect = title.get_rect(centerx=600, top=20)
    screen.blit(title, title_rect)

    # 컴포넌트 크기와 위치
    comp_size = 100
    start_x = 50
    start_y = 100
    spacing_x = 140
    spacing_y = 200

    # 첫 번째 줄 - 기본 구성 요소들
    draw_1_blue_glow(screen, start_x, start_y, comp_size, animation_time)
    draw_2_red_inner_borders(screen, start_x + spacing_x, start_y, comp_size, animation_time)
    draw_3_outer_frame(screen, start_x + spacing_x * 2, start_y, comp_size, animation_time)
    draw_4_corner_highlights(screen, start_x + spacing_x * 3, start_y, comp_size, animation_time)

    # 두 번째 줄 - 추가 효과들
    draw_5_legendary_border(screen, start_x, start_y + spacing_y, comp_size, animation_time)
    draw_6_hammer_icon(screen, start_x + spacing_x, start_y + spacing_y, comp_size, animation_time)
    draw_7_floating_animation(screen, start_x + spacing_x * 2, start_y + spacing_y, comp_size, animation_time)
    draw_8_complete_effect(screen, start_x + spacing_x * 3, start_y + spacing_y, comp_size, animation_time)

    # 레이어 순서 설명
    layer_info_y = start_y + spacing_y * 2 + 50
    layer_title = font.render("Layer Order (Bottom to Top):", True, WHITE)
    screen.blit(layer_title, (start_x, layer_info_y))

    layers = [
        "1. Blue Glow Background (Pulsing)",
        "2. Red Inner Borders (Triple gradient)",
        "3. Outer Frame (Static silver-blue)",
        "4. Corner Highlights (Golden L-shapes)",
        "5. Legendary Border (Pulsing red)",
        "6. Hammer Icon (Central)",
        "7. Float Animation (Y-axis movement)"
    ]

    for i, layer in enumerate(layers):
        color = (200 - i * 20, 200 - i * 20, 200 - i * 20)
        layer_surf = small_font.render(f"  {layer}", True, color)
        screen.blit(layer_surf, (start_x, layer_info_y + 30 + i * 20))

    # 애니메이션 정보
    info_x = 800
    info_y = 100
    info_title = font.render("Animation Parameters:", True, WHITE)
    screen.blit(info_title, (info_x, info_y))

    params = [
        f"Time: {animation_time:.2f}s",
        f"Blue Glow: sin(t*4.0) = {(math.sin(animation_time * 4.0) + 1) / 2:.2f}",
        f"Red Borders: sin(t*6.0) = {(math.sin(animation_time * 6.0) + 1) / 2:.2f}",
        f"Legendary: sin(t*3.0) = {(0.5 + 0.5 * math.sin(animation_time * 3)):.2f}",
        f"Float Y: sin(t*2.5)*2 = {int(math.sin(animation_time * 2.5) * 2)}px"
    ]

    for i, param in enumerate(params):
        param_surf = small_font.render(param, True, (150, 150, 150))
        screen.blit(param_surf, (info_x, info_y + 30 + i * 20))

    # 컨트롤 안내
    controls = font.render("Press ESC to exit", True, (100, 100, 100))
    controls_rect = controls.get_rect(centerx=600, bottom=790)
    screen.blit(controls, controls_rect)

    pygame.display.flip()

pygame.quit()
sys.exit()