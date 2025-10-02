"""
라그나로크 해머 - 모든 분리된 시각 효과 쇼케이스
PNG 내부 효과와 외부 오버레이 효과를 모두 분리해서 한눈에 보기
"""

import pygame
import math
import sys
import os

def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((1600, 900))
pygame.display.set_caption("Ragnarok Hammer - All Visual Effects Showcase")
clock = pygame.time.Clock()

# 색상 정의
BACKGROUND = (20, 20, 35)
WHITE = (255, 255, 255)
SECTION_BG = (30, 30, 50)

# 폰트
small_font = pygame.font.Font(None, 14)
label_font = pygame.font.Font(None, 16)
title_font = pygame.font.Font(None, 24)
section_font = pygame.font.Font(None, 20)

# 애니메이션 변수
animation_time = 0
current_frame = 0
frame_counter = 0
animation_speed = 8

# 라그나로크 해머 PNG 로드
hammer_frames = []
for i in range(8):
    frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
    try:
        frame = pygame.image.load(frame_path).convert_alpha()
        hammer_frames.append(frame)
    except:
        empty = pygame.Surface((128, 128), pygame.SRCALPHA)
        empty.fill((50, 0, 0, 50))
        hammer_frames.append(empty)

def draw_section_background(surface, x, y, width, height, title):
    """섹션 배경과 제목"""
    # 배경
    section = pygame.Surface((width, height), pygame.SRCALPHA)
    section.fill((*SECTION_BG, 200))
    pygame.draw.rect(section, (60, 60, 80), (0, 0, width, height), 2)
    surface.blit(section, (x, y))

    # 제목
    title_surf = section_font.render(title, True, (200, 200, 220))
    title_rect = title_surf.get_rect(centerx=x + width//2, top=y + 10)
    surface.blit(title_surf, title_rect)

def draw_effect_box(surface, x, y, size, name, korean_name, color=(100, 100, 120)):
    """개별 효과 박스"""
    # 배경
    box = pygame.Surface((size + 20, size + 50), pygame.SRCALPHA)
    box.fill((40, 40, 60, 150))
    pygame.draw.rect(box, color, (0, 0, size + 20, size + 50), 1)
    surface.blit(box, (x - 10, y - 10))

    # 영어 이름
    name_surf = label_font.render(name, True, WHITE)
    name_rect = name_surf.get_rect(centerx=x + size//2, top=y + size + 5)
    surface.blit(name_surf, name_rect)

    # 한글 이름
    kr_surf = small_font.render(korean_name, True, (180, 180, 200))
    kr_rect = kr_surf.get_rect(centerx=x + size//2, top=y + size + 22)
    surface.blit(kr_surf, kr_rect)

# ============ PNG 내부 효과 ============

def draw_png_hammer_core(surface, x, y, size):
    """PNG 내부: 해머 코어"""
    draw_effect_box(surface, x, y, size, "Hammer Core", "해머 코어", (150, 100, 100))

    if hammer_frames and current_frame < len(hammer_frames):
        icon = pygame.transform.smoothscale(hammer_frames[current_frame], (size, size))
        # 중앙 부분만 (테두리 제외 시뮬레이션)
        core_area = pygame.Rect(20, 20, size-40, size-40)
        surface.blit(icon, (x, y), core_area)

def draw_png_red_gradient_ring(surface, x, y, size, anim_time):
    """PNG 내부: 빨간색 그라데이션 링"""
    draw_effect_box(surface, x, y, size, "Icon Red Gradient", "빨간색 그라데이션", (200, 50, 50))

    # 그라데이션 링 시뮬레이션
    gradient = int((math.sin(anim_time * 4) + 1) * 20)
    for i in range(8):
        alpha = 180 - i * 20
        red = 255 - i * 10 - gradient
        color = (red, 50 + i * 5, 50 + i * 5, alpha)
        rect = pygame.Rect(x + i, y + i, size - i*2, size - i*2)
        pygame.draw.rect(surface, color[:3], rect, 1)

def draw_png_corner_shimmer(surface, x, y, size, anim_time):
    """PNG 내부: 코너 쉬머"""
    draw_effect_box(surface, x, y, size, "Corner Shimmer", "코너 쉬머", (100, 100, 200))

    shimmer = (math.sin(anim_time * 3) + 1) / 2
    corner_size = size // 4

    # 각 코너에 쉬머 효과
    for cx, cy in [(x, y), (x + size - corner_size, y),
                   (x, y + size - corner_size), (x + size - corner_size, y + size - corner_size)]:
        blue = int(100 + shimmer * 155)
        silver = int(180 + (1-shimmer) * 75)
        color = (silver, silver, blue)

        # L자 형태
        if cx == x and cy == y:  # Top-left
            pygame.draw.lines(surface, color, False,
                            [(cx, cy + corner_size), (cx, cy), (cx + corner_size, cy)], 2)
        elif cx > x and cy == y:  # Top-right
            pygame.draw.lines(surface, color, False,
                            [(cx, cy), (cx + corner_size, cy), (cx + corner_size, cy + corner_size)], 2)
        elif cx == x and cy > y:  # Bottom-left
            pygame.draw.lines(surface, color, False,
                            [(cx, cy), (cx, cy + corner_size), (cx + corner_size, cy + corner_size)], 2)
        else:  # Bottom-right
            pygame.draw.lines(surface, color, False,
                            [(cx, cy + corner_size), (cx + corner_size, cy + corner_size),
                             (cx + corner_size, cy)], 2)

# ============ 외부 오버레이 효과 ============

def draw_overlay_blue_pulsing(surface, x, y, size, anim_time):
    """오버레이: 파란색 펄싱"""
    draw_effect_box(surface, x, y, size, "Blue Pulsing", "파란색 펄싱", (50, 100, 200))

    pulse = (math.sin(anim_time * 4.0) + 1) / 2
    base_radius = int(size * 0.42)
    outer_radius = int(base_radius + size * 0.05 * pulse)
    center = (x + size // 2, y + size // 2)

    pygame.draw.circle(surface, (30, 90, 170), center, outer_radius)
    pygame.draw.circle(surface, (70, 140, 200), center, int(outer_radius * 0.85))
    pygame.draw.circle(surface, (140, 190, 220), center, int(outer_radius * 0.65))

def draw_overlay_red_inner(surface, x, y, size, anim_time):
    """오버레이: 붉은 내부 테두리"""
    draw_effect_box(surface, x, y, size, "Red Inner Border", "붉은 내부 테두리", (200, 50, 50))

    pulse = (math.sin(anim_time * 6.0) + 1) / 2
    colors = [
        (int(150 + 70 * pulse), int(30 + 35 * pulse), int(30 + 35 * pulse)),
        (int(135 + 65 * pulse), int(20 + 30 * pulse), int(20 + 30 * pulse)),
        (int(120 + 60 * pulse), int(10 + 25 * pulse), int(10 + 25 * pulse))
    ]

    for i, color in enumerate(colors):
        offset = 2 + i * 2
        rect = pygame.Rect(x + offset, y + offset, size - offset*2, size - offset*2)
        pygame.draw.rect(surface, color, rect, 1)

def draw_overlay_silver_frame(surface, x, y, size):
    """오버레이: 은색 프레임"""
    draw_effect_box(surface, x, y, size, "Silver Frame", "은색 프레임", (180, 200, 255))

    pygame.draw.rect(surface, (180, 200, 255), (x - 1, y - 1, size + 2, size + 2), 2)

def draw_overlay_golden_corners(surface, x, y, size):
    """오버레이: 황금 코너"""
    draw_effect_box(surface, x, y, size, "Golden Corners", "황금 코너", (255, 215, 0))

    corner_size = 15
    color = (255, 215, 0)

    # L자 코너들
    pygame.draw.lines(surface, color, False,
                     [(x - 2, y + corner_size), (x - 2, y - 2), (x + corner_size, y - 2)], 2)
    pygame.draw.lines(surface, color, False,
                     [(x + size - corner_size + 2, y - 2), (x + size + 2, y - 2),
                      (x + size + 2, y + corner_size)], 2)
    pygame.draw.lines(surface, color, False,
                     [(x - 2, y + size - corner_size + 2), (x - 2, y + size + 2),
                      (x + corner_size, y + size + 2)], 2)
    pygame.draw.lines(surface, color, False,
                     [(x + size - corner_size + 2, y + size + 2), (x + size + 2, y + size + 2),
                      (x + size + 2, y + size - corner_size + 2)], 2)

    # 코너 점
    for cx, cy in [(x, y), (x + size, y), (x, y + size), (x + size, y + size)]:
        pygame.draw.circle(surface, color, (cx, cy), 2)

def draw_overlay_red_pulsing(surface, x, y, size, anim_time):
    """오버레이: 빨간 펄싱 테두리"""
    draw_effect_box(surface, x, y, size, "Red Pulsing", "빨간 펄싱", (255, 50, 50))

    color = (int(255 * (0.5 + 0.5 * math.sin(anim_time * 3))), 0, 0)
    pygame.draw.rect(surface, color, (x, y, size, size), 3)

def draw_overlay_floating(surface, x, y, size, anim_time):
    """오버레이: 상하 움직임"""
    draw_effect_box(surface, x, y, size, "Floating", "상하 움직임", (100, 200, 100))

    offset = int(math.sin(anim_time * 2.5) * 2)

    # 기준선
    pygame.draw.line(surface, (100, 100, 100), (x, y + size//2), (x + size, y + size//2), 1)

    # 움직이는 박스
    moved_rect = pygame.Rect(x, y + offset, size, size)
    pygame.draw.rect(surface, (100, 200, 100), moved_rect, 2)

    # 오프셋 표시
    offset_text = small_font.render(f"{offset:+d}px", True, (100, 200, 100))
    surface.blit(offset_text, (x + size + 5, y + size//2))

def draw_final_combined(surface, x, y, size, anim_time):
    """최종 결합"""
    draw_effect_box(surface, x, y, size, "FINAL", "최종", (255, 255, 255))

    offset = int(math.sin(anim_time * 2.5) * 2)
    actual_y = y + offset

    # 모든 레이어 순서대로
    # 1. 파란 펄싱
    pulse = (math.sin(anim_time * 4.0) + 1) / 2
    radius = int(size * 0.42 + size * 0.05 * pulse)
    center = (x + size // 2, actual_y + size // 2)
    pygame.draw.circle(surface, (30, 90, 170), center, radius)

    # 2. 붉은 내부
    inner_pulse = (math.sin(anim_time * 6.0) + 1) / 2
    red = (int(150 + 70 * inner_pulse), int(30 + 35 * inner_pulse), int(30 + 35 * inner_pulse))
    pygame.draw.rect(surface, red, (x + 2, actual_y + 2, size - 4, size - 4), 1)

    # 3. 해머 아이콘
    if hammer_frames and current_frame < len(hammer_frames):
        icon = pygame.transform.smoothscale(hammer_frames[current_frame], (size, size))
        surface.blit(icon, (x, actual_y))

    # 4. 은색 프레임
    pygame.draw.rect(surface, (180, 200, 255), (x - 1, actual_y - 1, size + 2, size + 2), 2)

    # 5. 황금 코너
    cs = 8
    pygame.draw.lines(surface, (255, 215, 0), False,
                     [(x - 2, actual_y + cs), (x - 2, actual_y - 2), (x + cs, actual_y - 2)], 2)

    # 6. 빨간 펄싱
    legendary = (int(255 * (0.5 + 0.5 * math.sin(anim_time * 3))), 0, 0)
    pygame.draw.rect(surface, legendary, (x, actual_y, size, size), 3)

# 메인 루프
running = True
show_animation = True

while running:
    dt = clock.tick(60) / 1000.0
    if show_animation:
        animation_time += dt

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
            elif event.key == pygame.K_SPACE:
                show_animation = not show_animation

    # 화면 그리기
    screen.fill(BACKGROUND)

    # 메인 제목
    main_title = title_font.render("RAGNAROK HAMMER - ALL VISUAL EFFECTS SEPARATED", True, WHITE)
    main_rect = main_title.get_rect(centerx=800, top=20)
    screen.blit(main_title, main_rect)

    effect_size = 80

    # ========== PNG 내부 효과 섹션 ==========
    png_section_x = 50
    png_section_y = 70
    png_section_width = 700
    png_section_height = 180

    draw_section_background(screen, png_section_x, png_section_y,
                           png_section_width, png_section_height,
                           "PNG INTERNAL EFFECTS (PNG 이미지 내부 효과)")

    # PNG 효과들
    png_x = png_section_x + 40
    png_y = png_section_y + 50
    spacing = 160

    draw_png_hammer_core(screen, png_x, png_y, effect_size)
    draw_png_red_gradient_ring(screen, png_x + spacing, png_y, effect_size, animation_time)
    draw_png_corner_shimmer(screen, png_x + spacing * 2, png_y, effect_size, animation_time)

    # PNG 합성
    combined_png_x = png_x + spacing * 3
    draw_effect_box(screen, combined_png_x, png_y, effect_size, "PNG Combined", "PNG 결합", (255, 150, 150))
    if hammer_frames and current_frame < len(hammer_frames):
        icon = pygame.transform.smoothscale(hammer_frames[current_frame], (effect_size, effect_size))
        screen.blit(icon, (combined_png_x, png_y))

    # ========== 외부 오버레이 효과 섹션 ==========
    overlay_section_x = 50
    overlay_section_y = 280
    overlay_section_width = 1500
    overlay_section_height = 380

    draw_section_background(screen, overlay_section_x, overlay_section_y,
                           overlay_section_width, overlay_section_height,
                           "EXTERNAL OVERLAY EFFECTS (외부 오버레이 효과)")

    # 오버레이 효과들 - 첫 번째 줄
    overlay_x = overlay_section_x + 40
    overlay_y = overlay_section_y + 50

    draw_overlay_blue_pulsing(screen, overlay_x, overlay_y, effect_size, animation_time)
    draw_overlay_red_inner(screen, overlay_x + spacing, overlay_y, effect_size, animation_time)
    draw_overlay_silver_frame(screen, overlay_x + spacing * 2, overlay_y, effect_size)
    draw_overlay_golden_corners(screen, overlay_x + spacing * 3, overlay_y, effect_size)

    # 오버레이 효과들 - 두 번째 줄
    overlay_y2 = overlay_y + 150
    draw_overlay_red_pulsing(screen, overlay_x, overlay_y2, effect_size, animation_time)
    draw_overlay_floating(screen, overlay_x + spacing, overlay_y2, effect_size, animation_time)

    # ========== 최종 결합 ==========
    final_x = overlay_x + spacing * 3
    final_y = overlay_y2
    draw_final_combined(screen, final_x, final_y, effect_size + 20, animation_time)

    # ========== 레이어 순서 표시 ==========
    layer_info_x = 800
    layer_info_y = 100

    layer_title = label_font.render("Layer Stack (Bottom→Top):", True, (200, 200, 200))
    screen.blit(layer_title, (layer_info_x, layer_info_y))

    layers = [
        "1. Blue Pulsing Glow",
        "2. Red Inner Borders",
        "3. PNG Image (with internal effects)",
        "4. Silver-Blue Frame",
        "5. Golden Corners",
        "6. Red Pulsing Border",
        "7. + Floating Motion"
    ]

    for i, layer in enumerate(layers):
        color = (200 - i * 20, 200 - i * 20, 200 - i * 20)
        layer_text = small_font.render(layer, True, color)
        screen.blit(layer_text, (layer_info_x + 10, layer_info_y + 20 + i * 16))

    # 애니메이션 정보
    info_x = 1100
    info_y = 100
    info_title = label_font.render("Animation Status:", True, (200, 200, 200))
    screen.blit(info_title, (info_x, info_y))

    status = "PLAYING" if show_animation else "PAUSED"
    status_color = (100, 255, 100) if show_animation else (255, 100, 100)
    status_text = label_font.render(status, True, status_color)
    screen.blit(status_text, (info_x, info_y + 20))

    # 컨트롤
    controls = [
        "SPACE: Play/Pause",
        "ESC: Exit"
    ]

    for i, control in enumerate(controls):
        control_text = small_font.render(control, True, (150, 150, 150))
        screen.blit(control_text, (info_x, info_y + 50 + i * 16))

    # 하단 정보
    bottom_info = small_font.render(f"Time: {animation_time:.2f}s | Frame: {current_frame}/7",
                                   True, (150, 150, 150))
    bottom_rect = bottom_info.get_rect(centerx=800, bottom=880)
    screen.blit(bottom_info, bottom_rect)

    pygame.display.flip()

pygame.quit()
sys.exit()