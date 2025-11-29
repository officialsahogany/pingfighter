#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# downtown/preview_cyberpunk_gacha.py
# 사이버펑크 가챠샵 인테리어 프리뷰

import pygame
import sys
import math
from pathlib import Path

# 프로젝트 루트를 경로에 추가
project_root = Path(__file__).resolve().parents[1]
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from downtown.constants import SCREEN_WIDTH, SCREEN_HEIGHT, TILE_SIZE, BuildingType

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("사이버펑크 가챠샵 프리뷰")
clock = pygame.time.Clock()

# 가챠샵 맵 크기 (2배 확대: 20x20)
MAP_WIDTH = 20
MAP_HEIGHT = 20
PIXEL_WIDTH = MAP_WIDTH * TILE_SIZE
PIXEL_HEIGHT = MAP_HEIGHT * TILE_SIZE

# 카메라 오프셋
camera_x = (PIXEL_WIDTH - SCREEN_WIDTH) // 2
camera_y = (PIXEL_HEIGHT - SCREEN_HEIGHT) // 2

# 애니메이션 타이머
animation_timer = 0

def draw_cyberpunk_floor(cam_x, cam_y):
    """사이버펑크 바닥 그리기"""
    FLOOR_PINK = (80, 40, 90)
    FLOOR_PINK_DARK = (60, 30, 70)
    FLOOR_STRIPE = (120, 60, 130)

    tile_w = TILE_SIZE
    tile_h = TILE_SIZE

    start_x = max(0, int(cam_x // tile_w) - 1)
    start_y = max(0, int(cam_y // tile_h) - 1)
    end_x = min(MAP_WIDTH + 2, start_x + SCREEN_WIDTH // tile_w + 3)
    end_y = min(MAP_HEIGHT + 2, start_y + SCREEN_HEIGHT // tile_h + 3)

    for ty in range(start_y, end_y):
        for tx in range(start_x, end_x):
            tile_x = tx * tile_w - cam_x
            tile_y = ty * tile_h - cam_y

            # 대각선 스트라이프 패턴
            if (tx + ty) % 4 < 2:
                color = FLOOR_PINK
            else:
                color = FLOOR_PINK_DARK
            pygame.draw.rect(screen, color, (tile_x, tile_y, tile_w, tile_h))

            # 스트라이프 라인
            if (tx + ty) % 4 == 0:
                pygame.draw.line(screen, FLOOR_STRIPE,
                               (tile_x, tile_y),
                               (tile_x + tile_w, tile_y + tile_h), 2)
                pygame.draw.line(screen, FLOOR_STRIPE,
                               (tile_x + tile_w, tile_y),
                               (tile_x, tile_y + tile_h), 2)

def draw_neon_sign_box(x, y, w, h, color, text=""):
    """네온 사인 박스 그리기"""
    bg_color = (30, 20, 40)
    pygame.draw.rect(screen, bg_color, (x, y, w, h), border_radius=5)

    # 글로우 효과
    glow_pulse = abs(math.sin(animation_timer * 3))
    for offset in range(3):
        alpha = int((80 - offset * 25) * glow_pulse)
        glow_surf = pygame.Surface((w + offset * 4, h + offset * 4), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*color, alpha), (0, 0, w + offset * 4, h + offset * 4), 2, border_radius=5)
        screen.blit(glow_surf, (x - offset * 2, y - offset * 2))

    pygame.draw.rect(screen, color, (x, y, w, h), 2, border_radius=5)

    if text:
        text_w = min(w - 10, len(text) * 10)
        text_h = h - 15
        text_x = x + (w - text_w) // 2
        text_y = y + (h - text_h) // 2
        pygame.draw.rect(screen, color, (text_x, text_y, text_w, text_h), border_radius=2)

def draw_neon_sign_large(x, y, w, h, color, text=""):
    """대형 네온 사인 그리기"""
    bg_color = (20, 15, 30)
    pygame.draw.rect(screen, bg_color, (x, y, w, h), border_radius=8)

    glow_pulse = abs(math.sin(animation_timer * 2.5))
    for offset in range(4):
        alpha = int((100 - offset * 20) * glow_pulse)
        glow_surf = pygame.Surface((w + offset * 6, h + offset * 6), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*color, alpha), (0, 0, w + offset * 6, h + offset * 6), 3, border_radius=8)
        screen.blit(glow_surf, (x - offset * 3, y - offset * 3))

    inner_margin = 8
    pygame.draw.rect(screen, (40, 30, 60), (x + inner_margin, y + inner_margin,
                                             w - inner_margin * 2, h - inner_margin * 2), border_radius=4)
    pygame.draw.rect(screen, color, (x + inner_margin, y + inner_margin,
                                     w - inner_margin * 2, h - inner_margin * 2), 2, border_radius=4)

def draw_small_display_case(x, y, color):
    """작은 유리 진열장 그리기"""
    case_w, case_h = 35, 50

    pygame.draw.rect(screen, (60, 50, 80), (x, y, case_w, case_h), border_radius=3)
    pygame.draw.rect(screen, color, (x, y, case_w, case_h), 2, border_radius=3)

    glass_surf = pygame.Surface((case_w - 6, case_h - 12), pygame.SRCALPHA)
    glass_surf.fill((100, 150, 200, 60))
    screen.blit(glass_surf, (x + 3, y + 3))

    item_y = y + case_h // 2
    item_colors = [(255, 150, 200), (150, 200, 255), (200, 255, 150), (255, 200, 150)]
    item_color = item_colors[int(x) % len(item_colors)]

    head_y = item_y - 8
    pygame.draw.circle(screen, item_color, (x + case_w // 2, head_y), 8)
    pygame.draw.ellipse(screen, item_color, (x + case_w // 2 - 6, head_y + 6, 12, 15))

    shelf_y = y + case_h - 8
    pygame.draw.rect(screen, (80, 70, 100), (x + 2, shelf_y, case_w - 4, 6))

def draw_monitor_display(x, y, w, h, color):
    """모니터 디스플레이 그리기"""
    frame_color = (50, 45, 70)
    pygame.draw.rect(screen, frame_color, (x, y, w, h), border_radius=5)
    pygame.draw.rect(screen, (80, 70, 100), (x, y, w, h), 3, border_radius=5)

    screen_margin = 6
    screen_rect = (x + screen_margin, y + screen_margin,
                  w - screen_margin * 2, h - screen_margin * 2)

    pygame.draw.rect(screen, (20, 40, 50), screen_rect, border_radius=3)

    char_colors = [(255, 150, 200), (150, 255, 200), (200, 150, 255), (255, 200, 150)]
    char_x_start = x + screen_margin + 10
    char_y = y + screen_margin + h // 2 - 10

    for i in range(4):
        char_x = char_x_start + i * 18
        pygame.draw.circle(screen, char_colors[i], (char_x, char_y - 5), 5)
        pygame.draw.rect(screen, char_colors[i], (char_x - 4, char_y, 8, 10))

    for scan_y in range(y + screen_margin, y + h - screen_margin, 4):
        alpha = 30
        scan_surf = pygame.Surface((w - screen_margin * 2, 1), pygame.SRCALPHA)
        scan_surf.fill((0, 0, 0, alpha))
        screen.blit(scan_surf, (x + screen_margin, scan_y))

def draw_escalator(x, y, w, h, gray_color, rail_color, accent_color):
    """에스컬레이터 그리기"""
    pygame.draw.rect(screen, gray_color, (x, y, w, h))

    rail_w = 15
    pygame.draw.rect(screen, rail_color, (x, y, rail_w, h))
    pygame.draw.rect(screen, rail_color, (x + w - rail_w, y, rail_w, h))

    glow_pulse = abs(math.sin(animation_timer * 2))
    for offset in range(2):
        alpha = int((60 - offset * 25) * glow_pulse)
        glow_surf = pygame.Surface((rail_w + 4, h + 4), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*rail_color, alpha), (0, 0, rail_w + 4, h + 4))
        screen.blit(glow_surf, (x - 2, y - 2))
        screen.blit(glow_surf, (x + w - rail_w - 2, y - 2))

    step_count = int(h / 20)
    step_h = h / step_count
    step_offset = (animation_timer * 30) % step_h

    for i in range(step_count + 1):
        step_y = y + i * step_h - step_offset
        if y <= step_y < y + h:
            step_color = (100, 90, 120) if i % 2 == 0 else (90, 80, 110)
            pygame.draw.rect(screen, step_color, (x + rail_w + 5, step_y, w - rail_w * 2 - 10, step_h - 2))
            pygame.draw.line(screen, (70, 65, 90), (x + rail_w + 5, step_y), (x + w - rail_w - 5, step_y), 1)

    platform_h = 25
    pygame.draw.rect(screen, (60, 55, 80), (x - 10, y - platform_h, w + 20, platform_h))
    pygame.draw.rect(screen, accent_color, (x - 10, y - platform_h, w + 20, 3))
    pygame.draw.rect(screen, (60, 55, 80), (x - 10, y + h, w + 20, platform_h))
    pygame.draw.rect(screen, accent_color, (x - 10, y + h + platform_h - 3, w + 20, 3))

    center_x = x + w // 2
    pygame.draw.line(screen, (50, 45, 70), (center_x, y), (center_x, y + h), 4)

def draw_single_gacha_machine(x, y, w, h, machine_color, top_color, accent, index):
    """단일 가챠 머신 그리기"""
    body_h = h * 0.4
    body_y = y + h - body_h
    pygame.draw.rect(screen, machine_color, (x, body_y, w, body_h), border_radius=5)
    pygame.draw.rect(screen, tuple(max(0, c - 30) for c in machine_color), (x, body_y, w, body_h), 2, border_radius=5)

    dome_h = h * 0.6
    dome_y = y

    pygame.draw.ellipse(screen, (40, 30, 60), (x + 3, dome_y + 3, w - 6, dome_h - 6))

    dome_surf = pygame.Surface((int(w - 6), int(dome_h - 6)), pygame.SRCALPHA)
    pygame.draw.ellipse(dome_surf, (100, 150, 200, 80), (0, 0, w - 6, dome_h - 6))
    screen.blit(dome_surf, (x + 3, dome_y + 3))

    pygame.draw.ellipse(screen, top_color, (x + 3, dome_y + 3, w - 6, dome_h - 6), 3)

    capsule_colors = [(255, 100, 150), (100, 200, 255), (255, 255, 100),
                     (150, 255, 150), (255, 150, 100)]
    capsule_count = 6
    center_x = x + w // 2
    center_y = dome_y + dome_h // 2

    for i in range(capsule_count):
        angle = animation_timer * (1 + index * 0.2) + i * (math.pi * 2 / capsule_count)
        radius_x = (w - 20) // 3
        radius_y = (dome_h - 20) // 3
        cx = center_x + math.cos(angle) * radius_x
        cy = center_y + math.sin(angle) * radius_y * 0.7

        capsule_color = capsule_colors[i % len(capsule_colors)]
        pygame.draw.ellipse(screen, capsule_color, (cx - 5, cy - 7, 10, 14))
        pygame.draw.circle(screen, (255, 255, 255), (int(cx - 2), int(cy - 3)), 2)

    outlet_y = body_y + 15
    pygame.draw.rect(screen, (30, 25, 40), (x + w // 2 - 12, outlet_y, 24, 18), border_radius=4)
    pygame.draw.rect(screen, accent, (x + w // 2 - 12, outlet_y, 24, 18), 2, border_radius=4)

    coin_y = body_y + 45
    pygame.draw.rect(screen, (80, 70, 100), (x + w // 2 - 8, coin_y, 16, 8), border_radius=2)
    pygame.draw.rect(screen, (200, 180, 100), (x + w // 2 - 8, coin_y, 16, 8), 1, border_radius=2)

    pygame.draw.line(screen, accent, (x + 5, body_y + body_h - 10), (x + w - 5, body_y + body_h - 10), 2)

    glow_pulse = abs(math.sin(animation_timer * 3 + index))
    for offset in range(2):
        alpha = int((50 - offset * 20) * glow_pulse)
        glow_surf = pygame.Surface((int(w + 8), int(dome_h + 8)), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_surf, (*accent, alpha), (0, 0, w + 8, dome_h + 8), 2)
        screen.blit(glow_surf, (x - 4, dome_y - 4))

def draw_crane_game(x, y, w, h, accent):
    """크레인 게임 그리기"""
    body_color = (70, 60, 90)
    pygame.draw.rect(screen, body_color, (x, y, w, h), border_radius=5)
    pygame.draw.rect(screen, accent, (x, y, w, h), 2, border_radius=5)

    glass_margin = 5
    glass_rect = (x + glass_margin, y + glass_margin,
                 w - glass_margin * 2, int(h * 0.65))

    pygame.draw.rect(screen, (25, 20, 35), glass_rect, border_radius=3)

    glass_surf = pygame.Surface((int(glass_rect[2]), int(glass_rect[3])), pygame.SRCALPHA)
    glass_surf.fill((80, 120, 160, 50))
    screen.blit(glass_surf, (glass_rect[0], glass_rect[1]))

    pygame.draw.rect(screen, accent, glass_rect, 2, border_radius=3)

    plush_colors = [(255, 200, 220), (200, 220, 255), (220, 255, 200), (255, 255, 200)]
    plush_count = 4
    plush_y = y + glass_margin + int(h * 0.4)

    for i in range(plush_count):
        plush_x = x + glass_margin + 8 + i * (w - glass_margin * 2 - 16) // plush_count
        plush_color = plush_colors[i]

        pygame.draw.circle(screen, plush_color, (plush_x, plush_y - 8), 10)
        pygame.draw.ellipse(screen, plush_color, (plush_x - 8, plush_y - 2, 16, 12))
        pygame.draw.circle(screen, (50, 50, 50), (plush_x - 3, plush_y - 10), 2)
        pygame.draw.circle(screen, (50, 50, 50), (plush_x + 3, plush_y - 10), 2)

    crane_x = x + w // 2 + int(10 * math.sin(animation_timer * 2))
    crane_y = y + glass_margin + 5
    pygame.draw.line(screen, (200, 200, 200), (crane_x, crane_y), (crane_x, crane_y + 30), 2)
    pygame.draw.line(screen, (200, 200, 200), (crane_x - 8, crane_y + 30), (crane_x + 8, crane_y + 30), 2)

    panel_y = y + h * 0.7
    panel_h = h * 0.3 - 5
    pygame.draw.rect(screen, (50, 45, 65), (x + 3, panel_y, w - 6, panel_h), border_radius=3)

    joy_x = x + w // 3
    joy_y = panel_y + panel_h // 2
    pygame.draw.circle(screen, (80, 80, 100), (int(joy_x), int(joy_y)), 8)
    pygame.draw.circle(screen, accent, (int(joy_x), int(joy_y)), 5)

    btn_x = x + w * 2 // 3
    pygame.draw.circle(screen, (255, 80, 80), (int(btn_x), int(joy_y)), 8)
    pygame.draw.circle(screen, (255, 150, 150), (int(btn_x), int(joy_y)), 5)

def draw_ceiling_neon_tubes(cam_x, cam_y, neon_pink, neon_cyan):
    """천장 네온 튜브"""
    tube_y = -cam_y - 5
    tube_h = 8
    tube_spacing = TILE_SIZE * 3

    for i in range(int(PIXEL_WIDTH // tube_spacing) + 1):
        tube_x = i * tube_spacing - cam_x
        color = neon_pink if i % 2 == 0 else neon_cyan

        pygame.draw.rect(screen, color, (tube_x, tube_y, tube_spacing - 20, tube_h), border_radius=3)

        glow_pulse = abs(math.sin(animation_timer * 4 + i * 0.3))
        for offset in range(2):
            alpha = int((80 - offset * 30) * glow_pulse)
            glow_surf = pygame.Surface((tube_spacing - 16, tube_h + 8), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*color, alpha), (0, 0, tube_spacing - 16, tube_h + 8), border_radius=4)
            screen.blit(glow_surf, (tube_x - 2, tube_y - 4))

def draw_cyberpunk_gacha_interior():
    """사이버펑크 가챠샵 전체 그리기"""
    global camera_x, camera_y

    # 색상 정의
    BG_DARK = (25, 15, 35)
    WALL_PURPLE = (45, 25, 60)
    NEON_PINK = (255, 50, 150)
    NEON_CYAN = (0, 255, 255)
    NEON_GREEN = (50, 255, 100)
    NEON_YELLOW = (255, 255, 0)
    NEON_BLUE = (100, 150, 255)
    MACHINE_PURPLE = (100, 60, 140)
    MACHINE_PINK = (180, 80, 160)
    ESCALATOR_GRAY = (80, 80, 100)
    ESCALATOR_GREEN = (100, 200, 150)

    cam_x, cam_y = camera_x, camera_y

    # 배경
    screen.fill(BG_DARK)

    # 바닥
    draw_cyberpunk_floor(cam_x, cam_y)

    # 상단 벽
    wall_h = int(TILE_SIZE * 5)
    wall_rect = pygame.Rect(-cam_x, -cam_y, PIXEL_WIDTH, wall_h)
    pygame.draw.rect(screen, WALL_PURPLE, wall_rect)

    # 네온 간판들
    center_x = PIXEL_WIDTH // 2

    sign1_x = center_x - 200 - cam_x
    sign1_y = 20 - cam_y
    draw_neon_sign_box(sign1_x, sign1_y, 60, 40, NEON_CYAN, "龍城")

    sign2_x = center_x - 80 - cam_x
    draw_neon_sign_box(sign2_x, sign1_y, 50, 35, (255, 255, 100), "天岩")

    sign3_x = center_x - 20 - cam_x
    draw_neon_sign_box(sign3_x, sign1_y, 50, 35, NEON_PINK, "ラヂ")

    sign4_x = center_x + 80 - cam_x
    sign4_y = 15 - cam_y
    draw_neon_sign_large(sign4_x, sign4_y, 120, 50, NEON_CYAN, "スターガチャ")

    # 유리 진열장들
    row2_y = 70 - cam_y
    for i, offset in enumerate([-180, -120, -60, 0, 60, 120, 180]):
        sign_x = center_x + offset - cam_x
        colors = [NEON_PINK, NEON_CYAN, NEON_GREEN, (255, 200, 100), NEON_PINK, NEON_CYAN, NEON_GREEN]
        draw_small_display_case(sign_x, row2_y, colors[i % len(colors)])

    # 모니터
    monitor_x = PIXEL_WIDTH - 120 - cam_x
    monitor_y = 30 - cam_y
    draw_monitor_display(monitor_x, monitor_y, 90, 60, NEON_CYAN)

    # 에스컬레이터
    escalator_x = PIXEL_WIDTH // 2 - int(TILE_SIZE * 3)
    escalator_y = wall_h + int(TILE_SIZE * 1)
    escalator_w = int(TILE_SIZE * 6)
    escalator_h = int(TILE_SIZE * 8)
    draw_escalator(escalator_x - cam_x, escalator_y - cam_y,
                  escalator_w, escalator_h, ESCALATOR_GRAY, ESCALATOR_GREEN, NEON_CYAN)

    # 좌측 가챠 머신들
    left_x = int(TILE_SIZE * 1.5)
    machine_y = wall_h + int(TILE_SIZE * 0.5)
    machine_w = int(TILE_SIZE * 1.5)
    machine_h = int(TILE_SIZE * 3.5)

    for i in range(3):
        mx = left_x + i * (machine_w + int(TILE_SIZE * 0.1)) - cam_x
        draw_single_gacha_machine(mx, machine_y - cam_y, machine_w, machine_h,
                                  MACHINE_PURPLE, MACHINE_PINK, NEON_PINK, i)

    # 우측 가챠 머신들
    right_x = PIXEL_WIDTH - int(TILE_SIZE * 6)
    for i in range(3):
        mx = right_x + i * (machine_w + int(TILE_SIZE * 0.1)) - cam_x
        draw_single_gacha_machine(mx, machine_y - cam_y, machine_w, machine_h,
                                  MACHINE_PURPLE, MACHINE_PINK, NEON_CYAN, i + 3)

    # 프라이즈 머신들
    prize_y = wall_h + int(TILE_SIZE * 6)
    prize_w = int(TILE_SIZE * 2) - 5
    prize_h = int(TILE_SIZE * 2.5)

    # 좌측 크레인
    draw_crane_game(left_x - cam_x, prize_y - cam_y, prize_w, prize_h, NEON_YELLOW)
    draw_crane_game(left_x + prize_w + 10 - cam_x, prize_y - cam_y, prize_w, prize_h, NEON_BLUE)

    # 우측 크레인
    draw_crane_game(right_x - cam_x, prize_y - cam_y, prize_w, prize_h, NEON_GREEN)
    draw_crane_game(right_x + prize_w + 10 - cam_x, prize_y - cam_y, prize_w, prize_h, NEON_PINK)

    # 천장 네온
    draw_ceiling_neon_tubes(cam_x, cam_y, NEON_PINK, NEON_CYAN)

    # 안내 텍스트
    font = pygame.font.Font(None, 24)
    text = font.render("Arrow keys: Move camera | ESC: Exit | Space: Reset", True, (200, 200, 200))
    screen.blit(text, (10, SCREEN_HEIGHT - 30))

    # 맵 정보
    info_text = font.render(f"Map: {MAP_WIDTH}x{MAP_HEIGHT} ({PIXEL_WIDTH}x{PIXEL_HEIGHT}px) | Camera: ({cam_x}, {cam_y})", True, (150, 150, 150))
    screen.blit(info_text, (10, 10))

def main():
    global camera_x, camera_y, animation_timer

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    camera_x = (PIXEL_WIDTH - SCREEN_WIDTH) // 2
                    camera_y = (PIXEL_HEIGHT - SCREEN_HEIGHT) // 2

        # 키보드 입력 처리
        keys = pygame.key.get_pressed()
        move_speed = 5
        if keys[pygame.K_LEFT]:
            camera_x = max(0, camera_x - move_speed)
        if keys[pygame.K_RIGHT]:
            camera_x = min(PIXEL_WIDTH - SCREEN_WIDTH, camera_x + move_speed)
        if keys[pygame.K_UP]:
            camera_y = max(0, camera_y - move_speed)
        if keys[pygame.K_DOWN]:
            camera_y = min(PIXEL_HEIGHT - SCREEN_HEIGHT, camera_y + move_speed)

        # 애니메이션 타이머 업데이트
        animation_timer += 0.05

        # 그리기
        draw_cyberpunk_gacha_interior()

        pygame.display.flip()
        clock.tick(60)

    pygame.quit()

if __name__ == "__main__":
    main()
