"""
라그나로크 해머 아이콘 자체의 테두리 효과 분리
PNG 이미지에 포함된 테두리 효과들을 개별적으로 분리 표시
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
screen = pygame.display.set_mode((1200, 800))
pygame.display.set_caption("Hammer Icon Internal Border Effects - Separated")
clock = pygame.time.Clock()

# 색상 정의
BACKGROUND = (30, 30, 50)
WHITE = (255, 255, 255)

# 폰트
font = pygame.font.Font(None, 20)
title_font = pygame.font.Font(None, 28)
label_font = pygame.font.Font(None, 18)
desc_font = pygame.font.Font(None, 14)

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
        hammer_frames.append(empty)

def extract_hammer_core(image):
    """해머 중심부만 추출 (테두리 제거)"""
    size = image.get_size()[0]
    core = pygame.Surface((size, size), pygame.SRCALPHA)

    # 중앙 영역만 복사 (테두리 제외)
    border_width = 15  # 테두리 추정 너비
    for y in range(border_width, size - border_width):
        for x in range(border_width, size - border_width):
            color = image.get_at((x, y))
            # 테두리 색상이 아닌 경우만 복사
            if color.a > 0:
                # 빨간색/파란색 테두리가 아닌 경우
                is_border = (color.r > 200 and color.g < 100) or \
                           (color.b > 200 and color.r < 150)
                if not is_border:
                    core.set_at((x, y), color)

    return core

def extract_icon_red_gradient_ring(image):
    """아이콘 내부의 빨간색 그라데이션 링 추출"""
    size = image.get_size()[0]
    ring = pygame.Surface((size, size), pygame.SRCALPHA)

    # 외곽 근처 픽셀 분석
    for y in range(size):
        for x in range(size):
            # 가장자리 근처 영역만 체크
            edge_dist = min(x, y, size-x-1, size-y-1)
            if edge_dist < 12 and edge_dist > 2:  # 테두리 영역
                color = image.get_at((x, y))
                if color.a > 0:
                    # 빨간색 계열 체크 (그라데이션)
                    if color.r > color.g + 30 and color.r > color.b + 30:
                        ring.set_at((x, y), color)

    return ring

def extract_icon_corner_gradient(image):
    """아이콘 코너의 은색-파란색 그라데이션 추출"""
    size = image.get_size()[0]
    corners = pygame.Surface((size, size), pygame.SRCALPHA)

    corner_size = 20  # 코너 영역 크기

    # 각 코너 영역 체크
    for y in range(size):
        for x in range(size):
            # 코너 영역 판별
            in_corner = False
            if (x < corner_size and y < corner_size) or \
               (x > size - corner_size and y < corner_size) or \
               (x < corner_size and y > size - corner_size) or \
               (x > size - corner_size and y > size - corner_size):
                in_corner = True

            if in_corner:
                color = image.get_at((x, y))
                if color.a > 0:
                    # 은색-파란색 계열 체크
                    if color.b > color.r and color.b > 150:
                        corners.set_at((x, y), color)
                    elif abs(color.r - color.g) < 30 and abs(color.g - color.b) < 30:
                        # 은색 계열
                        corners.set_at((x, y), color)

    return corners

def draw_part_1_hammer_core(surface, x, y, size):
    """Part 1: 해머 코어 (순수 해머 이미지, 테두리 없음)"""
    box = pygame.Surface((size, size), pygame.SRCALPHA)
    box.fill((40, 40, 60, 100))
    surface.blit(box, (x, y))

    if hammer_frames and current_frame < len(hammer_frames):
        # 해머 중심부만 표시
        icon = hammer_frames[current_frame]
        if icon.get_size() != (size, size):
            icon = pygame.transform.smoothscale(icon, (size, size))

        # 중앙 부분만 그리기 (시뮬레이션)
        core_rect = pygame.Rect(15, 15, size-30, size-30)
        surface.blit(icon, (x, y), core_rect)

    # 라벨
    label = label_font.render("1. Hammer Core", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 5)
    surface.blit(label, label_rect)

    desc = desc_font.render("Pure hammer without borders", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 25)
    surface.blit(desc, desc_rect)

def draw_part_2_icon_red_ring(surface, x, y, size, anim_time):
    """Part 2: Icon Red Gradient Ring (아이콘 빨간색 그라데이션 링)"""
    box = pygame.Surface((size, size), pygame.SRCALPHA)
    box.fill((40, 40, 60, 100))
    surface.blit(box, (x, y))

    # 빨간색 그라데이션 링 시뮬레이션
    ring_width = 8

    # 프레임별로 변하는 그라데이션
    gradient_shift = int((math.sin(anim_time * 4) + 1) * 20)

    for i in range(ring_width):
        alpha = 200 - i * 20
        red = 255 - i * 10 - gradient_shift
        green = 50 + i * 5
        blue = 50 + i * 5

        rect = pygame.Rect(x + i, y + i, size - i*2, size - i*2)
        pygame.draw.rect(surface, (red, green, blue, alpha), rect, 1)

    # 라벨
    label = label_font.render("2. Icon Red Gradient Ring", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 5)
    surface.blit(label, label_rect)

    desc = desc_font.render("아이콘 빨간색 그라데이션 링", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 25)
    surface.blit(desc, desc_rect)

    color_info = desc_font.render(f"R: {255 - gradient_shift}, Animated", True, (255, 100, 100))
    info_rect = color_info.get_rect(centerx=x + size//2, top=y + size + 40)
    surface.blit(color_info, info_rect)

def draw_part_3_icon_corner_shimmer(surface, x, y, size, anim_time):
    """Part 3: Icon Corner Shimmer (아이콘 코너 은색-파란색 쉬머)"""
    box = pygame.Surface((size, size), pygame.SRCALPHA)
    box.fill((40, 40, 60, 100))
    surface.blit(box, (x, y))

    # 코너 쉬머 효과 시뮬레이션
    shimmer = (math.sin(anim_time * 3) + 1) / 2

    corner_size = 20
    corner_positions = [
        (x, y),  # Top-left
        (x + size - corner_size, y),  # Top-right
        (x, y + size - corner_size),  # Bottom-left
        (x + size - corner_size, y + size - corner_size)  # Bottom-right
    ]

    for cx, cy in corner_positions:
        # 은색에서 파란색으로 변하는 그라데이션
        for i in range(corner_size):
            for j in range(corner_size):
                dist = math.sqrt(i**2 + j**2)
                if dist < corner_size:
                    # 시간에 따라 색상 변화
                    blue_amount = int(100 + shimmer * 155)
                    silver_amount = int(180 + (1-shimmer) * 75)

                    color = (silver_amount, silver_amount, blue_amount, 100)

                    # 각 코너에 픽셀 그리기
                    if cx == x and cy == y:  # Top-left
                        screen.set_at((cx + i, cy + j), color)
                    elif cx == x + size - corner_size and cy == y:  # Top-right
                        screen.set_at((cx + (corner_size - i), cy + j), color)
                    elif cx == x and cy == y + size - corner_size:  # Bottom-left
                        screen.set_at((cx + i, cy + (corner_size - j)), color)
                    else:  # Bottom-right
                        screen.set_at((cx + (corner_size - i), cy + (corner_size - j)), color)

    # 라벨
    label = label_font.render("3. Icon Corner Shimmer", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 5)
    surface.blit(label, label_rect)

    desc = desc_font.render("아이콘 코너 은색-파란색 쉬머", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 25)
    surface.blit(desc, desc_rect)

    color_info = desc_font.render(f"Silver→Blue: {int(shimmer*100)}%", True, (150, 150, 255))
    info_rect = color_info.get_rect(centerx=x + size//2, top=y + size + 40)
    surface.blit(color_info, info_rect)

def draw_part_4_combined_icon(surface, x, y, size, anim_time):
    """Part 4: 모든 아이콘 내부 효과 결합"""
    box = pygame.Surface((size, size), pygame.SRCALPHA)
    box.fill((40, 40, 60, 100))
    surface.blit(box, (x, y))

    if hammer_frames and current_frame < len(hammer_frames):
        # 전체 아이콘 표시
        icon = hammer_frames[current_frame]
        if icon.get_size() != (size, size):
            icon = pygame.transform.smoothscale(icon, (size, size))
        surface.blit(icon, (x, y))

    # 라벨
    label = label_font.render("4. Complete Icon", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 5)
    surface.blit(label, label_rect)

    desc = desc_font.render("All icon effects combined", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 25)
    surface.blit(desc, desc_rect)

def draw_visual_breakdown(surface, x, y):
    """시각적 분해 다이어그램"""
    title = font.render("Icon Internal Structure", True, WHITE)
    surface.blit(title, (x, y))

    # 레이어 다이어그램
    layers = [
        ("Core", "Hammer base image", (150, 150, 150)),
        ("Red Ring", "Gradient border", (255, 100, 100)),
        ("Corner Shimmer", "Silver-blue corners", (150, 150, 255)),
        ("Complete", "Final icon", (255, 255, 255))
    ]

    y_offset = 30
    for i, (name, desc, color) in enumerate(layers):
        # 화살표
        if i < len(layers) - 1:
            pygame.draw.line(surface, (100, 100, 100),
                           (x + 50, y + y_offset + i * 25 + 10),
                           (x + 50, y + y_offset + (i+1) * 25), 1)
            pygame.draw.polygon(surface, (100, 100, 100),
                              [(x + 50, y + y_offset + (i+1) * 25),
                               (x + 45, y + y_offset + (i+1) * 25 - 5),
                               (x + 55, y + y_offset + (i+1) * 25 - 5)])

        # 레이어 이름
        layer_text = desc_font.render(f"{i+1}. {name}: {desc}", True, color)
        surface.blit(layer_text, (x + 70, y + y_offset + i * 25))

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
    title = title_font.render("Hammer Icon Internal Border Effects - Named & Separated", True, WHITE)
    title_rect = title.get_rect(centerx=600, top=30)
    screen.blit(title, title_rect)

    # 파츠 표시
    part_size = 120
    start_x = 100
    start_y = 120
    spacing = 200

    # 상단 줄 - 분리된 요소들
    draw_part_1_hammer_core(screen, start_x, start_y, part_size)
    draw_part_2_icon_red_ring(screen, start_x + spacing, start_y, part_size, animation_time)
    draw_part_3_icon_corner_shimmer(screen, start_x + spacing * 2, start_y, part_size, animation_time)
    draw_part_4_combined_icon(screen, start_x + spacing * 3, start_y, part_size, animation_time)

    # 구조 다이어그램
    draw_visual_breakdown(screen, start_x, start_y + 200)

    # 용어 정리
    terms_y = start_y + 350
    terms_title = font.render("Terminology (용어 정리):", True, WHITE)
    surface.blit(terms_title, (start_x, terms_y))

    terms = [
        ("Icon Red Gradient Ring", "아이콘 빨간색 그라데이션 링",
         "- PNG 이미지 자체에 포함된 빨간색 테두리 효과"),
        ("Icon Corner Shimmer", "아이콘 코너 은색-파란색 쉬머",
         "- PNG 이미지 코너의 은색→파란색 변화 효과"),
        ("Hammer Core", "해머 코어",
         "- 테두리를 제외한 순수 해머 이미지"),
    ]

    y_pos = terms_y + 30
    for eng, kor, desc in terms:
        # 영어명
        eng_text = label_font.render(eng, True, (255, 200, 100))
        surface.blit(eng_text, (start_x, y_pos))

        # 한글명
        kor_text = label_font.render(f"({kor})", True, (150, 200, 255))
        surface.blit(kor_text, (start_x + 250, y_pos))

        # 설명
        desc_text = desc_font.render(desc, True, (180, 180, 180))
        surface.blit(desc_text, (start_x + 20, y_pos + 20))

        y_pos += 50

    # 애니메이션 정보
    info_x = 850
    info_y = 120
    info_title = font.render("Animation Info:", True, WHITE)
    surface.blit(info_title, (info_x, info_y))

    infos = [
        f"Time: {animation_time:.2f}s",
        f"Frame: {current_frame}/7",
        "",
        "Red Ring Gradient:",
        f"  Shift: {int((math.sin(animation_time * 4) + 1) * 20)}",
        "",
        "Corner Shimmer:",
        f"  Silver→Blue: {int(((math.sin(animation_time * 3) + 1) / 2) * 100)}%",
        "",
        "Note: These are effects",
        "embedded in the PNG",
        "image itself, not",
        "overlay effects."
    ]

    for i, info in enumerate(infos):
        color = WHITE if not info.startswith(" ") else (180, 180, 180)
        if info == "":
            continue
        info_text = desc_font.render(info, True, color)
        surface.blit(info_text, (info_x, info_y + 30 + i * 18))

    # 컨트롤
    controls = font.render("Press ESC to exit", True, (100, 100, 100))
    controls_rect = controls.get_rect(centerx=600, bottom=780)
    screen.blit(controls, controls_rect)

    pygame.display.flip()

pygame.quit()
sys.exit()