"""
라그나로크 해머 - 모든 파츠 개별 분리 표시
각 시각 요소를 레이어별로 완전히 분리해서 표시
"""

import pygame
import math
import sys
import os

def resource_path(relative_path):
    """Get absolute path to resource"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((1400, 900))
pygame.display.set_caption("Ragnarok Hammer - All Parts Separated")
clock = pygame.time.Clock()

# 색상 정의
BACKGROUND = (30, 30, 50)
WHITE = (255, 255, 255)
LEGENDARY_COLOR = (255, 50, 50)
COMMON_LEGENDARY_BORDER_COLOR = (180, 200, 255)
COMMON_LEGENDARY_CORNER_COLOR = (255, 215, 0)

# 폰트
font = pygame.font.Font(None, 18)
title_font = pygame.font.Font(None, 32)
label_font = pygame.font.Font(None, 16)

# 애니메이션 변수
animation_time = 0
current_frame = 0
frame_counter = 0
animation_speed = 8

# 라그나로크 해머 이미지 로드
hammer_frames = []
for i in range(8):
    frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
    try:
        frame = pygame.image.load(frame_path).convert_alpha()
        hammer_frames.append(frame)
    except:
        # 로드 실패시 빈 이미지
        empty = pygame.Surface((128, 128), pygame.SRCALPHA)
        hammer_frames.append(empty)

def draw_part_1_hammer_only(surface, x, y, size):
    """Part 1: 해머 아이콘만 (PNG 원본)"""
    if hammer_frames and current_frame < len(hammer_frames):
        icon = hammer_frames[current_frame]
        if icon.get_size() != (size, size):
            icon = pygame.transform.smoothscale(icon, (size, size))
        surface.blit(icon, (x, y))

    # 라벨
    label = label_font.render("1. Hammer Icon (PNG)", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 5)
    surface.blit(label, label_rect)

    desc = label_font.render(f"Frame {current_frame}/7", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 22)
    surface.blit(desc, desc_rect)

def draw_part_2_blue_pulsing(surface, x, y, size, anim_time):
    """Part 2: 파란색 펄싱 배경만"""
    pulse = (math.sin(anim_time * 4.0) + 1) / 2
    base_radius = max(6, int(size * 0.42))
    outer_radius = min(size // 2, int(base_radius + size * 0.05 * pulse))
    inner_radius = max(4, int(outer_radius * 0.65))

    center = (x + size // 2, y + size // 2)

    # 3층 파란색 글로우
    pygame.draw.circle(surface, (30, 90, 170), center, outer_radius)
    pygame.draw.circle(surface, (70, 140, 200), center, int(outer_radius * 0.85))
    pygame.draw.circle(surface, (140, 190, 220), center, inner_radius)

    # 라벨
    label = label_font.render("2. Blue Pulsing Glow", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 5)
    surface.blit(label, label_rect)

    desc = label_font.render(f"Pulse: {pulse:.2f}", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 22)
    surface.blit(desc, desc_rect)

def draw_part_3_red_inner_borders(surface, x, y, size, anim_time):
    """Part 3: 내부 붉은색 테두리만 (3중)"""
    inner_pulse = (math.sin(anim_time * 6.0) + 1) / 2

    # 3개 테두리 색상
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

    # 3개 사각형
    pygame.draw.rect(surface, outer_color, (x + 2, y + 2, size - 4, size - 4), 1)
    pygame.draw.rect(surface, mid_color, (x + 4, y + 4, size - 8, size - 8), 1)
    pygame.draw.rect(surface, inner_color, (x + 6, y + 6, size - 12, size - 12), 1)

    # 라벨
    label = label_font.render("3. Red Inner Borders", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 5)
    surface.blit(label, label_rect)

    desc = label_font.render(f"R: {outer_color[0]}", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 22)
    surface.blit(desc, desc_rect)

def draw_part_4_silver_frame(surface, x, y, size):
    """Part 4: 은색/파란색 외부 프레임만"""
    border_rect = pygame.Rect(x - 1, y - 1, size + 2, size + 2)
    pygame.draw.rect(surface, COMMON_LEGENDARY_BORDER_COLOR, border_rect, 2)

    # 라벨
    label = label_font.render("4. Silver-Blue Frame", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 5)
    surface.blit(label, label_rect)

    desc = label_font.render("Static outer frame", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 22)
    surface.blit(desc, desc_rect)

def draw_part_5_golden_corners(surface, x, y, size):
    """Part 5: 황금색 코너 장식만"""
    corner_size = 8
    corner_color = COMMON_LEGENDARY_CORNER_COLOR

    # L자 형태 코너들
    # Top-left
    pygame.draw.lines(surface, corner_color, False,
                     [(x - 2, y + corner_size), (x - 2, y - 2), (x + corner_size, y - 2)], 2)
    # Top-right
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - corner_size + 2, y - 2), (x + size + 2, y - 2),
                      (x + size + 2, y + corner_size)], 2)
    # Bottom-left
    pygame.draw.lines(surface, corner_color, False,
                     [(x - 2, y + size - corner_size + 2), (x - 2, y + size + 2),
                      (x + corner_size, y + size + 2)], 2)
    # Bottom-right
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - corner_size + 2, y + size + 2), (x + size + 2, y + size + 2),
                      (x + size + 2, y + size - corner_size + 2)], 2)

    # 코너 점들
    for cx, cy in [(x, y), (x + size, y), (x, y + size), (x + size, y + size)]:
        pygame.draw.circle(surface, corner_color, (cx, cy), 2)

    # 라벨
    label = label_font.render("5. Golden Corners", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 5)
    surface.blit(label, label_rect)

    desc = label_font.render("L-shaped decorations", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 22)
    surface.blit(desc, desc_rect)

def draw_part_6_red_pulsing_border(surface, x, y, size, anim_time):
    """Part 6: 빨간색 펄싱 외곽 테두리만"""
    border_color = (
        int(255 * (0.5 + 0.5 * math.sin(anim_time * 3))),
        0,
        0
    )
    pygame.draw.rect(surface, border_color, (x, y, size, size), 3)

    # 라벨
    label = label_font.render("6. Red Pulsing Border", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 5)
    surface.blit(label, label_rect)

    desc = label_font.render(f"R: {border_color[0]}", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 22)
    surface.blit(desc, desc_rect)

def draw_part_7_floating_effect(surface, x, y, size, anim_time):
    """Part 7: 상하 움직임 효과 시각화"""
    offset = int(math.sin(anim_time * 2.5) * 2)

    # 원래 위치 (점선)
    for i in range(0, size, 8):
        pygame.draw.circle(surface, (100, 100, 100), (x + i, y + size//2), 1)

    # 움직인 위치
    moved_y = y + offset
    pygame.draw.rect(surface, (100, 200, 100), (x, moved_y, size, size), 2)

    # 움직임 화살표
    if offset != 0:
        arrow_x = x + size + 10
        arrow_color = (255, 200, 0)
        if offset > 0:
            pygame.draw.polygon(surface, arrow_color,
                               [(arrow_x, y + size//2 - 5),
                                (arrow_x - 5, y + size//2 - 15),
                                (arrow_x + 5, y + size//2 - 15)])
            pygame.draw.line(surface, arrow_color,
                            (arrow_x, y + size//2 - 5),
                            (arrow_x, y + size//2 + 10), 2)
        else:
            pygame.draw.polygon(surface, arrow_color,
                               [(arrow_x, y + size//2 + 5),
                                (arrow_x - 5, y + size//2 + 15),
                                (arrow_x + 5, y + size//2 + 15)])
            pygame.draw.line(surface, arrow_color,
                            (arrow_x, y + size//2 + 5),
                            (arrow_x, y + size//2 - 10), 2)

    # 라벨
    label = label_font.render("7. Floating Motion", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 5)
    surface.blit(label, label_rect)

    desc = label_font.render(f"Y offset: {offset}px", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 22)
    surface.blit(desc, desc_rect)

def draw_combined_layers(surface, x, y, size, anim_time):
    """레이어 합성 과정 표시"""
    offset = int(math.sin(anim_time * 2.5) * 2)
    actual_y = y + offset

    # 각 레이어를 순서대로 그리기

    # Layer 1: 파란색 펄싱
    pulse = (math.sin(anim_time * 4.0) + 1) / 2
    base_radius = max(6, int(size * 0.42))
    outer_radius = min(size // 2, int(base_radius + size * 0.05 * pulse))
    center = (x + size // 2, actual_y + size // 2)
    pygame.draw.circle(surface, (30, 90, 170), center, outer_radius)
    pygame.draw.circle(surface, (70, 140, 200), center, int(outer_radius * 0.85))
    pygame.draw.circle(surface, (140, 190, 220), center, int(outer_radius * 0.65))

    # Layer 2: 붉은색 내부 테두리
    inner_pulse = (math.sin(anim_time * 6.0) + 1) / 2
    red_color = (int(150 + 70 * inner_pulse), int(30 + 35 * inner_pulse), int(30 + 35 * inner_pulse))
    pygame.draw.rect(surface, red_color, (x + 2, actual_y + 2, size - 4, size - 4), 1)
    pygame.draw.rect(surface, red_color, (x + 4, actual_y + 4, size - 8, size - 8), 1)
    pygame.draw.rect(surface, red_color, (x + 6, actual_y + 6, size - 12, size - 12), 1)

    # Layer 3: 해머 아이콘
    if hammer_frames and current_frame < len(hammer_frames):
        icon = hammer_frames[current_frame]
        if icon.get_size() != (size, size):
            icon = pygame.transform.smoothscale(icon, (size, size))
        surface.blit(icon, (x, actual_y))

    # Layer 4: 은색 프레임
    pygame.draw.rect(surface, COMMON_LEGENDARY_BORDER_COLOR, (x - 1, actual_y - 1, size + 2, size + 2), 2)

    # Layer 5: 황금색 코너
    cs = 8
    pygame.draw.lines(surface, COMMON_LEGENDARY_CORNER_COLOR, False,
                     [(x - 2, actual_y + cs), (x - 2, actual_y - 2), (x + cs, actual_y - 2)], 2)
    pygame.draw.lines(surface, COMMON_LEGENDARY_CORNER_COLOR, False,
                     [(x + size - cs + 2, actual_y - 2), (x + size + 2, actual_y - 2),
                      (x + size + 2, actual_y + cs)], 2)
    pygame.draw.lines(surface, COMMON_LEGENDARY_CORNER_COLOR, False,
                     [(x - 2, actual_y + size - cs + 2), (x - 2, actual_y + size + 2),
                      (x + cs, actual_y + size + 2)], 2)
    pygame.draw.lines(surface, COMMON_LEGENDARY_CORNER_COLOR, False,
                     [(x + size - cs + 2, actual_y + size + 2), (x + size + 2, actual_y + size + 2),
                      (x + size + 2, actual_y + size - cs + 2)], 2)

    # Layer 6: 빨간색 펄싱 테두리
    legendary_color = (int(255 * (0.5 + 0.5 * math.sin(anim_time * 3))), 0, 0)
    pygame.draw.rect(surface, legendary_color, (x, actual_y, size, size), 3)

    # 라벨
    label = label_font.render("8. All Combined", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 5)
    surface.blit(label, label_rect)

    desc = label_font.render("Final result", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 22)
    surface.blit(desc, desc_rect)

# 메인 루프
running = True
while running:
    dt = clock.tick(60) / 1000.0
    animation_time += dt

    # 프레임 업데이트
    frame_counter += 1
    if frame_counter >= animation_speed:
        frame_counter = 0
        current_frame = (current_frame + 1) % 8

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False

    # 화면 그리기
    screen.fill(BACKGROUND)

    # 제목
    title = title_font.render("Ragnarok Hammer - All Parts Completely Separated", True, WHITE)
    title_rect = title.get_rect(centerx=700, top=20)
    screen.blit(title, title_rect)

    # 파츠 크기와 위치
    part_size = 100
    start_x = 80
    start_y = 100
    spacing_x = 160
    spacing_y = 180

    # 첫 번째 줄 - 기본 요소들
    draw_part_1_hammer_only(screen, start_x, start_y, part_size)
    draw_part_2_blue_pulsing(screen, start_x + spacing_x, start_y, part_size, animation_time)
    draw_part_3_red_inner_borders(screen, start_x + spacing_x * 2, start_y, part_size, animation_time)
    draw_part_4_silver_frame(screen, start_x + spacing_x * 3, start_y, part_size)

    # 두 번째 줄 - 추가 요소들
    draw_part_5_golden_corners(screen, start_x, start_y + spacing_y, part_size)
    draw_part_6_red_pulsing_border(screen, start_x + spacing_x, start_y + spacing_y, part_size, animation_time)
    draw_part_7_floating_effect(screen, start_x + spacing_x * 2, start_y + spacing_y, part_size, animation_time)
    draw_combined_layers(screen, start_x + spacing_x * 3, start_y + spacing_y, part_size, animation_time)

    # 레이어 순서 설명
    layer_y = start_y + spacing_y * 2 + 80
    layer_title = font.render("Layer Order (Bottom → Top):", True, WHITE)
    screen.blit(layer_title, (start_x, layer_y))

    layers = [
        "1. Blue Pulsing Glow (Background)",
        "2. Red Inner Borders (3 layers)",
        "3. Hammer Icon (PNG image)",
        "4. Silver-Blue Frame",
        "5. Golden Corner Decorations",
        "6. Red Pulsing Border (Outermost)",
        "7. + Floating Motion (Y-axis)"
    ]

    for i, layer in enumerate(layers):
        color = (200 - i * 15, 200 - i * 15, 200 - i * 15)
        layer_text = label_font.render(f"  {layer}", True, color)
        screen.blit(layer_text, (start_x, layer_y + 25 + i * 18))

    # 애니메이션 파라미터
    param_x = 900
    param_y = 100
    param_title = font.render("Animation Parameters:", True, WHITE)
    screen.blit(param_title, (param_x, param_y))

    params = [
        f"Time: {animation_time:.2f}s",
        f"Frame: {current_frame}/7",
        "",
        "Pulsing Effects:",
        f"  Blue Glow: sin(t×4) = {(math.sin(animation_time * 4.0) + 1) / 2:.2f}",
        f"  Red Inner: sin(t×6) = {(math.sin(animation_time * 6.0) + 1) / 2:.2f}",
        f"  Red Border: sin(t×3) = {(0.5 + 0.5 * math.sin(animation_time * 3)):.2f}",
        f"  Float Y: sin(t×2.5)×2 = {int(math.sin(animation_time * 2.5) * 2)}px",
        "",
        "Colors:",
        f"  Blue Glow: (30, 90, 170) → (140, 190, 220)",
        f"  Red Inner: RGB({int(150 + 70 * ((math.sin(animation_time * 6.0) + 1) / 2))}, ...)",
        f"  Silver Frame: RGB(180, 200, 255)",
        f"  Golden Corners: RGB(255, 215, 0)",
        f"  Red Border: RGB({int(255 * (0.5 + 0.5 * math.sin(animation_time * 3)))}, 0, 0)"
    ]

    for i, param in enumerate(params):
        if param == "":
            continue
        color = WHITE if not param.startswith("  ") else (180, 180, 180)
        param_text = label_font.render(param, True, color)
        screen.blit(param_text, (param_x, param_y + 30 + i * 18))

    # 컨트롤
    controls = font.render("Press ESC to exit", True, (100, 100, 100))
    controls_rect = controls.get_rect(centerx=700, bottom=880)
    screen.blit(controls, controls_rect)

    pygame.display.flip()

pygame.quit()
sys.exit()