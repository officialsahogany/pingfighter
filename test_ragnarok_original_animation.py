"""
라그나로크 해머 - 아이템 관리자창 원본 애니메이션 재현
legendary_items.py의 RagnarokHammer.draw_icon() 메서드 완벽 재현
"""

import pygame
import math
import sys
import os

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("Ragnarok Hammer - Original Animation from Item Manager")
clock = pygame.time.Clock()

# 색상 정의
BACKGROUND = (30, 30, 50)  # 아이템 관리자창 배경색과 유사
WHITE = (255, 255, 255)
LEGENDARY_COLOR = (255, 50, 50)  # 전설 아이템 붉은색
COMMON_LEGENDARY_BORDER_COLOR = (180, 200, 255)  # 연한 파란색-은색 테두리
COMMON_LEGENDARY_CORNER_COLOR = (255, 215, 0)  # 황금색 코너

# 폰트 설정
font = pygame.font.Font(None, 24)
title_font = pygame.font.Font(None, 32)
korean_font = pygame.font.Font(None, 28)

# 애니메이션 변수
animation_time = 0
frame_counter = 0
current_frame = 0
animation_speed = 8  # 라그나로크 해머의 프레임 전환 속도

def draw_common_legendary_frame(surface, x, y, size, anim_time):
    """전설 아이템의 공통 프레임을 그리는 함수 (legendary_items.py와 동일)"""

    # 프레임 상하 움직임 효과 (살짝 위아래로 흔들림)
    frame_offset = int(math.sin(anim_time * 2.5) * 2)
    frame_y = y + frame_offset

    # 1. 파란색 원형 배경 애니메이션 (외곽/중앙 두 겹으로 펄싱)
    pulse = (math.sin(anim_time * 4.0) + 1) / 2  # 0~1
    base_radius = max(6, int(size * 0.42))
    outer_radius = min(size // 2, int(base_radius + size * 0.05 * pulse))
    inner_radius = max(4, int(outer_radius * 0.65))

    center = (x + size // 2, frame_y + size // 2)

    # 3층 구조의 파란색 글로우
    pygame.draw.circle(surface, (30, 90, 170, 80), center, outer_radius)
    pygame.draw.circle(surface, (70, 140, 200, 150), center, int(outer_radius * 0.85))
    pygame.draw.circle(surface, (140, 190, 220, 190), center, inner_radius)

    # 2. 내부 붉은색 테두리 (프레임별 그라데이션)
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

    inner_rect_outer = pygame.Rect(x + 2, frame_y + 2, size - 4, size - 4)
    inner_rect_mid = inner_rect_outer.inflate(-2, -2)
    inner_rect_inner = inner_rect_outer.inflate(-4, -4)

    pygame.draw.rect(surface, outer_inner_color, inner_rect_outer, 1)
    pygame.draw.rect(surface, mid_inner_color, inner_rect_mid, 1)
    pygame.draw.rect(surface, inner_inner_color, inner_rect_inner, 1)

    # 3. 공통 테두리 (외부 프레임)
    border_rect = pygame.Rect(x - 1, frame_y - 1, size + 2, size + 2)
    pygame.draw.rect(surface, COMMON_LEGENDARY_BORDER_COLOR, border_rect, 2)

    # 4. 코너 장식 (L자 형태 황금색)
    corner_size = 8
    corner_color = COMMON_LEGENDARY_CORNER_COLOR

    # Top-left corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x - 2, frame_y + corner_size), (x - 2, frame_y - 2), (x + corner_size, frame_y - 2)], 2)
    # Top-right corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - corner_size + 2, frame_y - 2), (x + size + 2, frame_y - 2), (x + size + 2, frame_y + corner_size)], 2)
    # Bottom-left corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x - 2, frame_y + size - corner_size + 2), (x - 2, frame_y + size + 2), (x + corner_size, frame_y + size + 2)], 2)
    # Bottom-right corner
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - corner_size + 2, frame_y + size + 2), (x + size + 2, frame_y + size + 2), (x + size + 2, frame_y + size - corner_size + 2)], 2)

    # 코너 포인트들
    for cx, cy in [(x, frame_y), (x + size, frame_y), (x, frame_y + size), (x + size, frame_y + size)]:
        pygame.draw.circle(surface, corner_color, (cx, cy), 2)

    return frame_offset

def draw_ragnarok_hammer_icon(surface, x, y, size, anim_time, frame_idx=0):
    """라그나로크 해머 아이콘 그리기 (원본과 동일)"""

    # 1. 전설 프레임 그리기
    frame_offset = draw_common_legendary_frame(surface, x, y, size, anim_time)
    actual_y = y + frame_offset

    # 2. 해머 아이콘 시뮬레이션 (프레임별로 살짝 다른 모습)
    # 실제 게임에서는 8개의 PNG 프레임을 로드하지만, 여기서는 시뮬레이션
    icon_surface = pygame.Surface((size, size), pygame.SRCALPHA)

    # 해머 머리 부분 (프레임별로 약간 회전)
    hammer_size = int(size * 0.5)
    hammer_x = (size - hammer_size) // 2
    hammer_y = (size - hammer_size) // 2 - 5

    # 프레임별 회전 효과
    rotation = frame_idx * 5  # 각 프레임마다 5도씩 회전

    # 해머 머리 그리기
    hammer_rect = pygame.Rect(hammer_x, hammer_y, hammer_size, hammer_size // 2)

    # 메탈릭한 그라데이션 효과
    for i in range(3):
        color_val = 100 + i * 30
        inner_rect = hammer_rect.inflate(-i * 4, -i * 2)
        pygame.draw.rect(icon_surface, (color_val, color_val, color_val + 10), inner_rect)

    # 해머 손잡이
    handle_width = hammer_size // 4
    handle_x = hammer_x + (hammer_size - handle_width) // 2
    handle_y = hammer_y + hammer_size // 2
    handle_height = hammer_size // 2 + 10

    handle_rect = pygame.Rect(handle_x, handle_y, handle_width, handle_height)
    pygame.draw.rect(icon_surface, (80, 50, 30), handle_rect)
    pygame.draw.rect(icon_surface, (60, 35, 20), handle_rect, 1)

    # 번개 효과 (프레임별로 다른 패턴)
    if frame_idx % 2 == 0:  # 짝수 프레임에만 번개
        lightning_color = (255, 255, 100, 180)
        # 번개 패턴 1
        points = [
            (hammer_x - 5, hammer_y + hammer_size // 4),
            (hammer_x + 10, hammer_y + hammer_size // 4 - 5),
            (hammer_x + 5, hammer_y + hammer_size // 4 + 5),
            (hammer_x + hammer_size + 5, hammer_y + hammer_size // 4)
        ]
        pygame.draw.lines(icon_surface, lightning_color, False, points, 2)

    # 프레임별 광채 효과
    if frame_idx % 4 < 2:  # 절반의 프레임에만 광채
        glow_surf = pygame.Surface((size, size), pygame.SRCALPHA)
        glow_radius = 15 + frame_idx * 2
        pygame.draw.circle(glow_surf, (255, 200, 100, 30),
                         (size // 2, size // 2 - 5), glow_radius)
        icon_surface.blit(glow_surf, (0, 0))

    # 아이콘을 실제 위치에 그리기
    surface.blit(icon_surface, (x, actual_y))

    # 3. 최외곽 전설 테두리 (빨간색 펄싱)
    legendary_border_color = (
        int(255 * (0.5 + 0.5 * math.sin(anim_time * 3))),
        0,
        0
    )
    pygame.draw.rect(surface, legendary_border_color,
                    (x, actual_y, size, size), 3)

def draw_item_slot(surface, x, y, size):
    """아이템 슬롯 배경 그리기 (아이템 관리자창 스타일)"""
    # 슬롯 배경
    slot_bg = pygame.Surface((size + 20, size + 20), pygame.SRCALPHA)
    slot_bg.fill((20, 20, 40, 200))
    pygame.draw.rect(slot_bg, (100, 100, 150), (0, 0, size + 20, size + 20), 2)
    surface.blit(slot_bg, (x - 10, y - 10))

# 메인 루프
running = True
while running:
    dt = clock.tick(60) / 1000.0
    animation_time += dt

    # 프레임 카운터 업데이트 (라그나로크 해머와 동일한 방식)
    frame_counter += 1
    if frame_counter >= animation_speed:
        frame_counter = 0
        current_frame = (current_frame + 1) % 8  # 8개 프레임 순환

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                # 스페이스바로 애니메이션 속도 조절
                animation_speed = 16 if animation_speed == 8 else 8

    # 화면 그리기
    screen.fill(BACKGROUND)

    # 제목
    title = title_font.render("Item Manager - Legendary Tab", True, WHITE)
    title_rect = title.get_rect(centerx=400, top=30)
    screen.blit(title, title_rect)

    # 메인 아이템 표시 (크게)
    main_size = 120
    main_x = 340
    main_y = 150

    # 아이템 슬롯 배경
    draw_item_slot(screen, main_x, main_y, main_size)

    # 라그나로크 해머 그리기
    draw_ragnarok_hammer_icon(screen, main_x, main_y, main_size, animation_time, current_frame)

    # 아이템 이름
    item_name = korean_font.render("라그나로크 해머", True, LEGENDARY_COLOR)
    name_rect = item_name.get_rect(centerx=400, top=main_y + main_size + 30)
    screen.blit(item_name, name_rect)

    # 프레임 표시 (작은 크기로 8개 모두 표시)
    frame_label = font.render("Animation Frames (0-7):", True, WHITE)
    screen.blit(frame_label, (50, 380))

    small_size = 60
    for i in range(8):
        frame_x = 50 + i * 85
        frame_y = 420

        # 현재 프레임 하이라이트
        if i == current_frame:
            highlight = pygame.Surface((small_size + 10, small_size + 10), pygame.SRCALPHA)
            highlight.fill((255, 255, 0, 50))
            screen.blit(highlight, (frame_x - 5, frame_y - 5))

        # 작은 아이콘 그리기
        draw_item_slot(screen, frame_x, frame_y, small_size)
        draw_ragnarok_hammer_icon(screen, frame_x, frame_y, small_size, animation_time, i)

        # 프레임 번호
        frame_num = font.render(str(i), True, (150, 150, 150))
        num_rect = frame_num.get_rect(centerx=frame_x + small_size // 2, top=frame_y + small_size + 5)
        screen.blit(frame_num, num_rect)

    # 애니메이션 정보
    info_y = 100
    info_x = 50

    info_texts = [
        f"Animation Time: {animation_time:.2f}s",
        f"Current Frame: {current_frame}/7",
        f"Frame Speed: {animation_speed} ticks/frame",
        f"Blue Glow: {(math.sin(animation_time * 4.0) + 1) / 2:.2f}",
        f"Red Border: {(math.sin(animation_time * 6.0) + 1) / 2:.2f}",
        f"Legendary: {int(255 * (0.5 + 0.5 * math.sin(animation_time * 3)))}",
        f"Y Offset: {int(math.sin(animation_time * 2.5) * 2)}px"
    ]

    for i, text in enumerate(info_texts):
        info_surf = font.render(text, True, (200, 200, 200))
        screen.blit(info_surf, (info_x, info_y + i * 25))

    # 컨트롤 안내
    controls = [
        "ESC: Exit",
        "SPACE: Toggle Animation Speed"
    ]

    for i, text in enumerate(controls):
        control_surf = font.render(text, True, (100, 100, 100))
        screen.blit(control_surf, (600, 100 + i * 25))

    pygame.display.flip()

pygame.quit()
sys.exit()