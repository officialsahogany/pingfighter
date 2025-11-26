#!/usr/bin/env python3
"""
StarBank 5가지 디자인 옵션
각각 독립적인 함수로 구현
"""

import pygame
import math
import random
from downtown.constants import *

# =============================================================================
# 디자인 1: 우아한 대리석 (현재 버전)
# =============================================================================
def draw_bank_design1_elegant_marble(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 1: 우아한 대리석 - 현재 적용된 디자인"""
    w, h = building.width, building.height

    # 색상 팔레트
    GOLD = (255, 215, 0)
    GOLD_LIGHT = (255, 235, 120)
    GOLD_DARK = (200, 165, 0)
    MARBLE_WHITE = (250, 248, 245)
    MARBLE = (235, 230, 225)
    MARBLE_SHADOW = (200, 195, 190)
    ROYAL_BLUE = (65, 105, 225)
    ACCENT_CYAN = (100, 200, 255)

    # 애니메이션
    pulse = 0.7 + 0.3 * abs(math.sin(animation_timer * 1.2))
    glow = abs(math.sin(animation_timer * 1.5))

    # 1. 그림자
    for i in range(12, 0, -2):
        shadow_alpha = 20 + i * 2
        shadow_surf = pygame.Surface((w + 20, 20), pygame.SRCALPHA)
        pygame.draw.ellipse(shadow_surf, (20, 15, 10, shadow_alpha),
                           (0, 0, w + 20, 18 - i // 2))
        screen.blit(shadow_surf, (x - 10, y + h + i - 8))

    # 2. 황금 글로우
    for i in range(3):
        glow_size = 30 - i * 9
        glow_alpha = int((45 - i * 12) * glow)
        if glow_alpha > 0:
            glow_surf = pygame.Surface((w + glow_size * 2, h + glow_size * 2), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (*GOLD, glow_alpha),
                            (0, 0, w + glow_size * 2, h + glow_size * 2), border_radius=10)
            screen.blit(glow_surf, (x - glow_size, y - glow_size))

    # 3. 대리석 기단
    for i in range(3):
        step_y = y + h - 8 + i * 4
        step_w = w + 12 - i * 4
        step_x = x - 6 + i * 2
        step_surf = pygame.Surface((int(step_w), 5), pygame.SRCALPHA)
        for sy in range(5):
            grad = 0.88 + 0.12 * (1 - sy / 5)
            color = (int(240 * grad), int(235 * grad), int(230 * grad))
            pygame.draw.line(step_surf, color, (0, sy), (int(step_w), sy))
        screen.blit(step_surf, (int(step_x), step_y))
        pygame.draw.line(screen, GOLD_LIGHT, (int(step_x), step_y), (int(step_x + step_w), step_y), 2)

    # 4. 메인 건물 본체
    building_surf = pygame.Surface((w, h - 25), pygame.SRCALPHA)
    for i in range(h - 25):
        grad = 0.94 + 0.06 * math.sin(i * 0.08)
        color = (int(245 * grad), int(242 * grad), int(238 * grad))
        pygame.draw.line(building_surf, color, (0, i), (w, i))
    screen.blit(building_surf, (x, y + 20))

    # 5. 황금 기둥
    pillar_positions = [x + 8, x + w - 18]
    pillar_w = 10
    pillar_h = h - 30
    for px in pillar_positions:
        for i in range(pillar_w):
            grad = 0.6 + 0.4 * abs(i - pillar_w / 2) / (pillar_w / 2)
            for py in range(pillar_h):
                height_grad = 0.75 + 0.25 * math.sin(py * 0.06)
                final_grad = grad * height_grad
                color = (int(GOLD[0] * final_grad), int(GOLD[1] * final_grad), int(50 * final_grad))
                screen.set_at((px + i, y + 18 + py), color)
        pygame.draw.line(screen, GOLD_LIGHT, (px + 3, y + 18), (px + 3, y + 18 + pillar_h), 2)

    # 6. 황금 아치 지붕
    roof_surf = pygame.Surface((w + 30, 40), pygame.SRCALPHA)
    for i in range(40):
        grad = 0.92 - i * 0.012
        color = (int(GOLD[0] * grad), int(GOLD[1] * grad), int(60 * grad))
        progress = i / 40
        half_width = int((w // 2 + 12) * (1 - progress * 0.88))
        cx = w // 2 + 15
        pygame.draw.line(roof_surf, color, (cx - half_width, i), (cx + half_width, i))
    screen.blit(roof_surf, (x - 15, y - 15))

    # 7. 환전 엠블렘 (★ ⇄ $)
    emblem_y = y + 2
    star_x = x + w // 2 - 20
    pygame.draw.circle(screen, ROYAL_BLUE, (star_x, emblem_y), 13)
    pygame.draw.circle(screen, ACCENT_CYAN, (star_x, emblem_y), 11)
    pygame.draw.circle(screen, GOLD, (star_x, emblem_y), 11, 2)

    star_points = []
    for i in range(5):
        angle_out = math.radians(i * 72 - 90)
        px = star_x + 7 * math.cos(angle_out)
        py = emblem_y + 7 * math.sin(angle_out)
        star_points.append((px, py))
        angle_in = math.radians(i * 72 + 36 - 90)
        px_in = star_x + 3 * math.cos(angle_in)
        py_in = emblem_y + 3 * math.sin(angle_in)
        star_points.append((px_in, py_in))
    pygame.draw.polygon(screen, GOLD, star_points)

    # 화살표
    arrow_x = x + w // 2
    pygame.draw.line(screen, GOLD_LIGHT, (star_x + 15, emblem_y), (arrow_x + 15, emblem_y), 3)
    pygame.draw.polygon(screen, GOLD_LIGHT, [(arrow_x + 15, emblem_y), (arrow_x + 10, emblem_y - 4), (arrow_x + 10, emblem_y + 4)])
    pygame.draw.polygon(screen, GOLD_LIGHT, [(star_x + 15, emblem_y), (star_x + 20, emblem_y - 4), (star_x + 20, emblem_y + 4)])

    # 금화
    coin_x = x + w // 2 + 20
    pygame.draw.circle(screen, GOLD_DARK, (coin_x + 1, emblem_y + 1), 12)
    pygame.draw.circle(screen, GOLD, (coin_x, emblem_y), 12)
    pygame.draw.circle(screen, GOLD_LIGHT, (coin_x - 2, emblem_y - 2), 6)
    pygame.draw.circle(screen, GOLD_DARK, (coin_x, emblem_y), 12, 2)
    font = pygame.font.Font(None, 22)
    dollar = font.render("$", True, (180, 140, 30))
    screen.blit(dollar, (coin_x - 5, emblem_y - 8))

    # 8. 대리석 문
    door_w = max(26, w // 2 + 5)
    door_h = max(38, h - 50)
    door_x = x + (w - door_w) // 2
    door_y = y + max(28, h - door_h - 8)

    pygame.draw.rect(screen, GOLD_DARK, (door_x - 4, door_y - 4, door_w + 8, door_h + 8), border_radius=6)
    pygame.draw.rect(screen, GOLD, (door_x - 2, door_y - 2, door_w + 4, door_h + 4), border_radius=5)

    door_surf = pygame.Surface((door_w, door_h), pygame.SRCALPHA)
    for dy in range(door_h):
        grad = 0.7 + 0.3 * (dy / door_h)
        r = int(ROYAL_BLUE[0] * (1 - grad) + MARBLE[0] * grad)
        g = int(ROYAL_BLUE[1] * (1 - grad) + MARBLE[1] * grad)
        b = int(ROYAL_BLUE[2] * (1 - grad) + MARBLE[2] * grad)
        pygame.draw.line(door_surf, (r, g, b), (0, dy), (door_w, dy))
    screen.blit(door_surf, (door_x, door_y))

    # 9. StarBank 명판
    plate_y = y + 12
    plate_w = 60
    plate_h = 14
    plate_x = x + (w - plate_w) // 2

    plate_surf = pygame.Surface((plate_w, plate_h), pygame.SRCALPHA)
    for py in range(plate_h):
        grad = 0.85 + 0.15 * (1 - abs(py - plate_h / 2) / (plate_h / 2))
        color = (int(GOLD[0] * grad), int(GOLD[1] * grad), int(50 * grad))
        pygame.draw.line(plate_surf, color, (0, py), (plate_w, py))
    screen.blit(plate_surf, (plate_x, plate_y))
    pygame.draw.rect(screen, GOLD_DARK, (plate_x, plate_y, plate_w, plate_h), 2, border_radius=3)

    name_font = pygame.font.Font(None, 16)
    bank_text = name_font.render("StarBank", True, (80, 60, 20))
    text_rect = bank_text.get_rect(center=(plate_x + plate_w // 2, plate_y + plate_h // 2))
    screen.blit(bank_text, text_rect)

    # 10. 반짝임
    sparkle_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    random.seed(building_id * 13 + int(animation_timer * 1.5))
    for _ in range(6):
        sx = random.randint(10, w - 10)
        sy = random.randint(15, h - 20)
        star_alpha = random.randint(150, 220)
        star_size = random.randint(1, 2)
        pygame.draw.circle(sparkle_surf, (*GOLD_LIGHT, star_alpha), (sx, sy), star_size)
        pygame.draw.line(sparkle_surf, (*GOLD_LIGHT, star_alpha // 2),
                       (sx - star_size * 3, sy), (sx + star_size * 3, sy), 1)
        pygame.draw.line(sparkle_surf, (*GOLD_LIGHT, star_alpha // 2),
                       (sx, sy - star_size * 3), (sx, sy + star_size * 3), 1)
    screen.blit(sparkle_surf, (x, y))
    random.seed()


# =============================================================================
# 디자인 2: 네온 사이버펑크
# =============================================================================
def draw_bank_design2_neon_cyber(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 2: 네온 사이버펑크 - 네온 글로우 + 홀로그램"""
    w, h = building.width, building.height

    # 색상 팔레트
    NEON_PINK = (255, 20, 147)
    NEON_CYAN = (0, 255, 255)
    NEON_PURPLE = (138, 43, 226)
    NEON_GOLD = (255, 215, 0)
    DARK_BG = (15, 15, 35)
    CYBER_BLUE = (30, 60, 100)

    # 애니메이션
    pulse = 0.5 + 0.5 * abs(math.sin(animation_timer * 2))
    scan = (animation_timer * 50) % h
    glow = abs(math.sin(animation_timer * 3))

    # 1. 사이버 그림자 (네온 글로우)
    for i in range(5):
        glow_size = 40 - i * 8
        alpha = int((80 - i * 15) * pulse)
        glow_surf = pygame.Surface((w + glow_size * 2, h + glow_size * 2), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*NEON_CYAN, alpha),
                        (glow_size, glow_size, w, h), border_radius=8)
        screen.blit(glow_surf, (x - glow_size, y - glow_size))

    # 2. 메인 건물 (어두운 배경)
    main_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for i in range(h):
        grad = 0.3 + 0.1 * math.sin(i * 0.1)
        color = (int(DARK_BG[0] * grad), int(DARK_BG[1] * grad), int(DARK_BG[2] * grad + 30))
        pygame.draw.line(main_surf, color, (0, i), (w, i))
    screen.blit(main_surf, (x, y))

    # 3. 네온 테두리
    border_thickness = 3
    pygame.draw.rect(screen, NEON_CYAN, (x, y, w, h), border_thickness, border_radius=6)

    # 네온 내부 글로우
    inner_glow = pygame.Surface((w, h), pygame.SRCALPHA)
    pygame.draw.rect(inner_glow, (*NEON_CYAN, int(60 * pulse)),
                    (border_thickness, border_thickness,
                     w - border_thickness * 2, h - border_thickness * 2),
                    border_radius=4)
    screen.blit(inner_glow, (x, y))

    # 4. 홀로그램 엠블렘 (★ ⇄ $)
    emblem_y = y + h // 4
    center_x = x + w // 2

    # 별 홀로그램 (왼쪽)
    star_x = center_x - 18
    for ring in range(3):
        ring_alpha = int((120 - ring * 30) * pulse)
        pygame.draw.circle(screen, (*NEON_PINK, ring_alpha), (star_x, emblem_y), 12 + ring * 3, 2)

    # 별 본체
    star_points = []
    for i in range(5):
        angle_out = math.radians(i * 72 - 90 + animation_timer * 15)
        px = star_x + 8 * math.cos(angle_out)
        py = emblem_y + 8 * math.sin(angle_out)
        star_points.append((px, py))
        angle_in = math.radians(i * 72 + 36 - 90 + animation_timer * 15)
        px_in = star_x + 3 * math.cos(angle_in)
        py_in = emblem_y + 3 * math.sin(angle_in)
        star_points.append((px_in, py_in))
    pygame.draw.polygon(screen, NEON_GOLD, star_points)

    # 홀로그램 화살표 (중앙)
    arrow_surf = pygame.Surface((40, 20), pygame.SRCALPHA)
    arrow_alpha = int(200 * pulse)
    for i in range(5):
        offset = i * 8 - (animation_timer * 30) % 40
        if 0 <= offset < 35:
            pygame.draw.polygon(arrow_surf, (*NEON_CYAN, arrow_alpha),
                              [(offset, 10), (offset + 5, 7), (offset + 5, 13)])
    screen.blit(arrow_surf, (center_x - 20, emblem_y - 10))

    # 금화 홀로그램 (오른쪽)
    coin_x = center_x + 18
    for ring in range(3):
        ring_alpha = int((120 - ring * 30) * pulse)
        pygame.draw.circle(screen, (*NEON_GOLD, ring_alpha), (coin_x, emblem_y), 12 + ring * 3, 2)

    pygame.draw.circle(screen, NEON_GOLD, (coin_x, emblem_y), 10)
    pygame.draw.circle(screen, (*DARK_BG, 150), (coin_x, emblem_y), 8)
    font = pygame.font.Font(None, 20)
    dollar = font.render("$", True, NEON_GOLD)
    screen.blit(dollar, (coin_x - 5, emblem_y - 8))

    # 5. 네온 라인 장식
    line_spacing = h // 8
    for i in range(7):
        line_y = y + 10 + i * line_spacing
        line_alpha = int(80 + 40 * math.sin(animation_timer * 2 + i * 0.5))
        pygame.draw.line(screen, (*NEON_CYAN, line_alpha),
                        (x + 8, line_y), (x + w - 8, line_y), 1)

    # 6. 스캔 라인 효과
    scan_surf = pygame.Surface((w, 3), pygame.SRCALPHA)
    pygame.draw.rect(scan_surf, (*NEON_PINK, 180), (0, 0, w, 3))
    screen.blit(scan_surf, (x, y + int(scan)))

    # 7. StarBank 홀로그램 텍스트
    title_y = y + h - 25
    title_font = pygame.font.Font(None, 18)

    # 글로우 효과
    for offset in range(3, 0, -1):
        glow_alpha = int((90 - offset * 20) * glow)
        glow_text = title_font.render("STARBANK", True, (*NEON_CYAN, glow_alpha))
        glow_rect = glow_text.get_rect(center=(center_x, title_y))
        screen.blit(glow_text, (glow_rect.x - offset, glow_rect.y))
        screen.blit(glow_text, (glow_rect.x + offset, glow_rect.y))

    # 메인 텍스트
    title_text = title_font.render("STARBANK", True, NEON_CYAN)
    title_rect = title_text.get_rect(center=(center_x, title_y))
    screen.blit(title_text, title_rect)

    # 8. 데이터 스트림 파티클
    random.seed(building_id * 7 + int(animation_timer * 4))
    for _ in range(8):
        px = random.randint(x + 5, x + w - 5)
        py_base = random.randint(y + 5, y + h - 5)
        py = (py_base + int(animation_timer * 40)) % h + y
        particle_alpha = random.randint(120, 220)
        particle_color = random.choice([NEON_CYAN, NEON_PINK, NEON_GOLD])
        pygame.draw.circle(screen, (*particle_color, particle_alpha), (px, py), 1)
    random.seed()


# =============================================================================
# 디자인 3: 크리스탈 궁전
# =============================================================================
def draw_bank_design3_crystal_palace(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 3: 크리스탈 궁전 - 크리스탈 구조 + 마법 효과"""
    w, h = building.width, building.height

    # 색상 팔레트
    CRYSTAL_CYAN = (100, 200, 255)
    CRYSTAL_BLUE = (80, 150, 255)
    CRYSTAL_PURPLE = (180, 100, 255)
    CRYSTAL_WHITE = (240, 250, 255)
    MAGIC_PINK = (255, 150, 200)
    GOLD = (255, 215, 0)

    # 애니메이션
    pulse = 0.6 + 0.4 * abs(math.sin(animation_timer * 1.5))
    magic_flow = animation_timer * 20
    shimmer = abs(math.sin(animation_timer * 2.5))

    # 1. 마법 오라
    for i in range(5):
        aura_size = 35 - i * 7
        aura_alpha = int((70 - i * 12) * pulse)
        aura_surf = pygame.Surface((w + aura_size * 2, h + aura_size * 2), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_surf, (*CRYSTAL_PURPLE, aura_alpha),
                           (0, 0, w + aura_size * 2, h + aura_size * 2))
        screen.blit(aura_surf, (x - aura_size, y - aura_size))

    # 2. 크리스탈 베이스 (다이아몬드 형태)
    base_points = [
        (x + w // 2, y),           # 위
        (x + w, y + h // 3),       # 오른쪽 위
        (x + w, y + h * 2 // 3),   # 오른쪽 아래
        (x + w // 2, y + h),       # 아래
        (x, y + h * 2 // 3),       # 왼쪽 아래
        (x, y + h // 3)            # 왼쪽 위
    ]

    # 크리스탈 그라데이션
    crystal_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for i in range(h):
        grad = 0.4 + 0.6 * (i / h) * pulse
        r = int(CRYSTAL_CYAN[0] * (1 - grad) + CRYSTAL_WHITE[0] * grad)
        g = int(CRYSTAL_CYAN[1] * (1 - grad) + CRYSTAL_WHITE[1] * grad)
        b = int(CRYSTAL_CYAN[2] * (1 - grad) + CRYSTAL_WHITE[2] * grad)
        pygame.draw.line(crystal_surf, (r, g, b), (0, i), (w, i))

    # 육각형 마스크 적용
    mask_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    pygame.draw.polygon(mask_surf, (255, 255, 255, 255),
                       [(p[0] - x, p[1] - y) for p in base_points])
    crystal_surf.blit(mask_surf, (0, 0), special_flags=pygame.BLEND_RGBA_MIN)
    screen.blit(crystal_surf, (x, y))

    # 크리스탈 테두리
    pygame.draw.polygon(screen, CRYSTAL_BLUE, base_points, 3)

    # 3. 내부 크리스탈 패싯 (빛 반사)
    facet_lines = [
        [(x + w // 2, y), (x + w // 2, y + h)],
        [(x, y + h // 3), (x + w, y + h * 2 // 3)],
        [(x, y + h * 2 // 3), (x + w, y + h // 3)]
    ]
    for line in facet_lines:
        alpha = int(100 * shimmer)
        pygame.draw.line(screen, (*CRYSTAL_WHITE, alpha), line[0], line[1], 2)

    # 4. 마법 엠블렘 (★ ⇄ $)
    emblem_y = y + h // 3
    center_x = x + w // 2

    # 별 크리스탈
    star_x = center_x - 15
    # 마법진 배경
    for ring in range(4):
        ring_radius = 15 - ring * 3
        ring_alpha = int((130 - ring * 25) * pulse)
        pygame.draw.circle(screen, (*MAGIC_PINK, ring_alpha), (star_x, emblem_y), ring_radius, 1)

    # 회전하는 별
    star_points = []
    for i in range(5):
        angle_out = math.radians(i * 72 - 90 + magic_flow)
        px = star_x + 8 * math.cos(angle_out)
        py = emblem_y + 8 * math.sin(angle_out)
        star_points.append((px, py))
        angle_in = math.radians(i * 72 + 36 - 90 + magic_flow)
        px_in = star_x + 3.5 * math.cos(angle_in)
        py_in = emblem_y + 3.5 * math.sin(angle_in)
        star_points.append((px_in, py_in))

    # 별 글로우
    for offset in range(3):
        alpha = int((140 - offset * 40) * pulse)
        star_glow = [(p[0] + offset * 0.3, p[1] + offset * 0.3) for p in star_points]
        pygame.draw.polygon(screen, (*GOLD, alpha), star_glow)
    pygame.draw.polygon(screen, GOLD, star_points)

    # 마법 화살표
    arrow_length = 25
    arrow_y = emblem_y
    # 빛나는 화살표
    for offset in range(3):
        alpha = int((120 - offset * 30) * shimmer)
        pygame.draw.line(screen, (*CRYSTAL_CYAN, alpha),
                        (star_x + 12, arrow_y), (star_x + 12 + arrow_length, arrow_y), 3)

    # 화살촉
    arrow_tip = star_x + 12 + arrow_length
    pygame.draw.polygon(screen, CRYSTAL_CYAN,
                       [(arrow_tip, arrow_y), (arrow_tip - 6, arrow_y - 4), (arrow_tip - 6, arrow_y + 4)])
    pygame.draw.polygon(screen, CRYSTAL_CYAN,
                       [(star_x + 12, arrow_y), (star_x + 18, arrow_y - 4), (star_x + 18, arrow_y + 4)])

    # 금화 크리스탈
    coin_x = center_x + 15
    # 마법진 배경
    for ring in range(4):
        ring_radius = 15 - ring * 3
        ring_alpha = int((130 - ring * 25) * pulse)
        pygame.draw.circle(screen, (*GOLD, ring_alpha), (coin_x, emblem_y), ring_radius, 1)

    # 회전하는 금화
    coin_angle = magic_flow
    for i in range(8):
        angle = math.radians(i * 45 + coin_angle)
        px = coin_x + 10 * math.cos(angle)
        py = emblem_y + 10 * math.sin(angle)
        size = int(3 + 2 * abs(math.cos(angle)))
        pygame.draw.circle(screen, GOLD, (int(px), int(py)), size)

    # 중앙 금화
    pygame.draw.circle(screen, GOLD, (coin_x, emblem_y), 8)
    pygame.draw.circle(screen, CRYSTAL_WHITE, (coin_x - 2, emblem_y - 2), 4)

    font = pygame.font.Font(None, 18)
    dollar = font.render("$", True, (180, 140, 30))
    screen.blit(dollar, (coin_x - 4, emblem_y - 7))

    # 5. 마법 파티클
    random.seed(building_id * 11 + int(animation_timer * 3))
    for _ in range(12):
        angle = random.uniform(0, math.pi * 2)
        distance = random.uniform(10, w // 2)
        px = center_x + distance * math.cos(angle + animation_timer * 0.5)
        py = emblem_y + distance * math.sin(angle + animation_timer * 0.5)

        if x < px < x + w and y < py < y + h:
            particle_alpha = random.randint(120, 200)
            particle_color = random.choice([CRYSTAL_CYAN, MAGIC_PINK, GOLD])
            size = random.randint(1, 3)
            pygame.draw.circle(screen, (*particle_color, particle_alpha), (int(px), int(py)), size)
    random.seed()

    # 6. StarBank 마법 각인
    title_y = y + h - 20
    title_font = pygame.font.Font(None, 18)

    # 마법 글로우
    for offset in range(4, 0, -1):
        glow_alpha = int((100 - offset * 20) * pulse)
        glow_text = title_font.render("StarBank", True, (*CRYSTAL_PURPLE, glow_alpha))
        glow_rect = glow_text.get_rect(center=(center_x, title_y))
        screen.blit(glow_text, (glow_rect.x, glow_rect.y - offset))

    title_text = title_font.render("StarBank", True, CRYSTAL_WHITE)
    title_rect = title_text.get_rect(center=(center_x, title_y))
    screen.blit(title_text, title_rect)

    # 7. 크리스탈 빛줄기
    for i in range(4):
        beam_x = x + (i + 1) * w // 5
        beam_alpha = int(50 * abs(math.sin(animation_timer * 1.8 + i * 0.7)))
        pygame.draw.line(screen, (*CRYSTAL_CYAN, beam_alpha),
                        (beam_x, y), (beam_x, y + h), 1)


# =============================================================================
# 디자인 4: 황금 신전
# =============================================================================
def draw_bank_design4_golden_temple(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 4: 황금 신전 - 피라미드 + 별빛"""
    w, h = building.width, building.height

    # 색상 팔레트
    GOLD = (255, 215, 0)
    GOLD_DARK = (200, 165, 0)
    GOLD_LIGHT = (255, 245, 150)
    EGYPTIAN_BLUE = (0, 90, 156)
    SAND = (210, 180, 140)
    STAR_WHITE = (255, 255, 240)

    # 애니메이션
    pulse = 0.7 + 0.3 * abs(math.sin(animation_timer * 1.3))
    shimmer = abs(math.sin(animation_timer * 2))
    star_twinkle = abs(math.sin(animation_timer * 3))

    # 1. 신성한 빛 (방사형)
    for i in range(6):
        angle_offset = (animation_timer * 10 + i * 60) % 360
        angle = math.radians(angle_offset)
        beam_length = 40 + 10 * pulse
        end_x = x + w // 2 + beam_length * math.cos(angle)
        end_y = y + h // 2 + beam_length * math.sin(angle)

        beam_alpha = int((90 - i * 12) * shimmer)
        pygame.draw.line(screen, (*GOLD, beam_alpha),
                        (x + w // 2, y + h // 2), (end_x, end_y), 3)

    # 2. 피라미드 구조
    pyramid_top = (x + w // 2, y + 5)
    pyramid_base_left = (x + 5, y + h - 10)
    pyramid_base_right = (x + w - 5, y + h - 10)

    pyramid_points = [pyramid_top, pyramid_base_right, pyramid_base_left]

    # 피라미드 그라데이션
    pyramid_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for i in range(h - 15):
        grad = 0.6 + 0.4 * (i / (h - 15))
        r = int(GOLD[0] * grad)
        g = int(GOLD[1] * grad)
        b = int(60 * grad)

        # 삼각형 너비 계산
        progress = i / (h - 15)
        left_x = pyramid_top[0] - (pyramid_top[0] - pyramid_base_left[0]) * progress
        right_x = pyramid_top[0] + (pyramid_base_right[0] - pyramid_top[0]) * progress

        pygame.draw.line(pyramid_surf, (r, g, b),
                        (left_x - x, i + 5), (right_x - x, i + 5))
    screen.blit(pyramid_surf, (x, y))

    # 피라미드 테두리
    pygame.draw.polygon(screen, GOLD_DARK, pyramid_points, 4)
    pygame.draw.polygon(screen, GOLD_LIGHT,
                       [(pyramid_top[0] - 2, pyramid_top[1] + 3),
                        (pyramid_base_right[0] - 5, pyramid_base_right[1] - 3),
                        (pyramid_base_left[0] + 5, pyramid_base_left[1] - 3)], 2)

    # 3. 피라미드 단 (계단식)
    steps = 5
    for i in range(steps):
        step_y = y + h - 15 - i * 8
        step_width = w - 10 - i * 12
        step_x = x + (w - step_width) // 2

        # 계단 그라데이션
        step_surf = pygame.Surface((int(step_width), 6), pygame.SRCALPHA)
        for sy in range(6):
            grad = 0.7 + 0.3 * (1 - sy / 6)
            color = (int(GOLD[0] * grad), int(GOLD[1] * grad), int(50 * grad))
            pygame.draw.line(step_surf, color, (0, sy), (int(step_width), sy))
        screen.blit(step_surf, (int(step_x), step_y))

        # 계단 테두리
        pygame.draw.line(screen, GOLD_LIGHT, (int(step_x), step_y), (int(step_x + step_width), step_y), 2)

    # 4. 별빛 엠블렘 (★ ⇄ $)
    emblem_y = y + h // 3
    center_x = x + w // 2

    # 이집트 별 (8각)
    star_x = center_x - 15
    # 별빛 후광
    for ring in range(5):
        ring_radius = 18 - ring * 3
        ring_alpha = int((110 - ring * 20) * star_twinkle)
        pygame.draw.circle(screen, (*STAR_WHITE, ring_alpha), (star_x, emblem_y), ring_radius, 1)

    # 8각 별
    star_8_points = []
    for i in range(8):
        angle = math.radians(i * 45 - 90 + animation_timer * 8)
        if i % 2 == 0:
            px = star_x + 9 * math.cos(angle)
            py = emblem_y + 9 * math.sin(angle)
        else:
            px = star_x + 4 * math.cos(angle)
            py = emblem_y + 4 * math.sin(angle)
        star_8_points.append((px, py))

    pygame.draw.polygon(screen, EGYPTIAN_BLUE, star_8_points)
    pygame.draw.polygon(screen, GOLD, star_8_points, 2)

    # 중앙 별빛
    pygame.draw.circle(screen, STAR_WHITE, (star_x, emblem_y), 3)

    # 교환 화살표 (고대 문양)
    arrow_center = center_x
    arrow_y = emblem_y
    arrow_width = 25

    # 이집트 스타일 화살표
    for i in range(3):
        offset = i * 2
        alpha = int((160 - i * 40) * pulse)
        pygame.draw.line(screen, (*GOLD, alpha),
                        (arrow_center - arrow_width // 2 + offset, arrow_y),
                        (arrow_center + arrow_width // 2 - offset, arrow_y), 2)

    # 화살촉
    pygame.draw.polygon(screen, GOLD,
                       [(arrow_center + arrow_width // 2, arrow_y),
                        (arrow_center + arrow_width // 2 - 5, arrow_y - 4),
                        (arrow_center + arrow_width // 2 - 5, arrow_y + 4)])
    pygame.draw.polygon(screen, GOLD,
                       [(arrow_center - arrow_width // 2, arrow_y),
                        (arrow_center - arrow_width // 2 + 5, arrow_y - 4),
                        (arrow_center - arrow_width // 2 + 5, arrow_y + 4)])

    # 금화 (고대 동전)
    coin_x = center_x + 15
    # 금화 후광
    for ring in range(5):
        ring_radius = 18 - ring * 3
        ring_alpha = int((110 - ring * 20) * pulse)
        pygame.draw.circle(screen, (*GOLD, ring_alpha), (coin_x, emblem_y), ring_radius, 1)

    # 금화 본체
    pygame.draw.circle(screen, GOLD_DARK, (coin_x + 1, emblem_y + 1), 10)
    pygame.draw.circle(screen, GOLD, (coin_x, emblem_y), 10)
    pygame.draw.circle(screen, EGYPTIAN_BLUE, (coin_x, emblem_y), 8)
    pygame.draw.circle(screen, GOLD, (coin_x, emblem_y), 8, 2)

    # 이집트 문양
    pygame.draw.circle(screen, GOLD_LIGHT, (coin_x - 2, emblem_y - 2), 3)

    font = pygame.font.Font(None, 16)
    dollar = font.render("$", True, GOLD)
    screen.blit(dollar, (coin_x - 4, emblem_y - 6))

    # 5. 히에로글리프 장식
    hieroglyph_y = y + h - 28
    hieroglyph_spacing = w // 6

    for i in range(5):
        hx = x + 10 + i * hieroglyph_spacing
        hy = hieroglyph_y

        # 간단한 이집트 문양
        alpha = int(150 * abs(math.sin(animation_timer * 1.5 + i * 0.5)))
        pygame.draw.rect(screen, (*EGYPTIAN_BLUE, alpha), (hx, hy, 6, 8), 1)
        pygame.draw.line(screen, (*GOLD_LIGHT, alpha), (hx + 3, hy), (hx + 3, hy + 8), 1)

    # 6. StarBank 각인 (고대 문자 스타일)
    title_y = y + h - 15
    title_font = pygame.font.Font(None, 16)

    # 황금 글로우
    for offset in range(3, 0, -1):
        glow_alpha = int((90 - offset * 25) * shimmer)
        glow_text = title_font.render("STARBANK", True, (*GOLD, glow_alpha))
        glow_rect = glow_text.get_rect(center=(center_x, title_y))
        screen.blit(glow_text, (glow_rect.x - offset, glow_rect.y))
        screen.blit(glow_text, (glow_rect.x + offset, glow_rect.y))

    title_text = title_font.render("STARBANK", True, EGYPTIAN_BLUE)
    title_rect = title_text.get_rect(center=(center_x, title_y))
    screen.blit(title_text, title_rect)

    # 테두리
    pygame.draw.rect(screen, GOLD, (title_rect.x - 5, title_rect.y - 2,
                                     title_rect.width + 10, title_rect.height + 4), 1)

    # 7. 별빛 파티클
    random.seed(building_id * 17 + int(animation_timer * 2.5))
    for _ in range(10):
        px = random.randint(x + 10, x + w - 10)
        py = random.randint(y + 15, y + h - 25)

        twinkle_alpha = random.randint(100, 220)
        twinkle_size = random.randint(1, 2)

        # 십자 반짝임
        pygame.draw.circle(screen, (*STAR_WHITE, twinkle_alpha), (px, py), twinkle_size)
        pygame.draw.line(screen, (*STAR_WHITE, twinkle_alpha // 2),
                        (px - 3, py), (px + 3, py), 1)
        pygame.draw.line(screen, (*STAR_WHITE, twinkle_alpha // 2),
                        (px, py - 3), (px, py + 3), 1)
    random.seed()


# =============================================================================
# 디자인 5: 미래 은행
# =============================================================================
def draw_bank_design5_future_bank(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 5: 미래 은행 - 유리 + 홀로그램 + 에너지 필드"""
    w, h = building.width, building.height

    # 색상 팔레트
    GLASS_BLUE = (150, 200, 255)
    HOLO_CYAN = (0, 240, 255)
    HOLO_PURPLE = (200, 100, 255)
    ENERGY_GREEN = (100, 255, 150)
    CHROME = (220, 230, 240)
    DARK_GLASS = (30, 50, 80)
    GOLD_ACCENT = (255, 215, 0)

    # 애니메이션
    pulse = 0.6 + 0.4 * abs(math.sin(animation_timer * 2))
    energy_flow = animation_timer * 50
    data_stream = (animation_timer * 30) % h
    holo_flicker = 0.8 + 0.2 * abs(math.sin(animation_timer * 5))

    # 1. 에너지 필드 (건물 보호막)
    for i in range(4):
        field_size = 30 - i * 7
        field_alpha = int((60 - i * 12) * pulse)
        field_surf = pygame.Surface((w + field_size * 2, h + field_size * 2), pygame.SRCALPHA)
        pygame.draw.rect(field_surf, (*ENERGY_GREEN, field_alpha),
                        (field_size, field_size, w, h), border_radius=12)
        screen.blit(field_surf, (x - field_size, y - field_size))

    # 2. 유리 건물 본체
    glass_surf = pygame.Surface((w, h), pygame.SRCALPHA)

    # 유리 그라데이션 (반투명)
    for i in range(h):
        grad = 0.3 + 0.4 * (i / h)
        alpha = int(180 + 40 * math.sin(i * 0.1))
        r = int(GLASS_BLUE[0] * grad + DARK_GLASS[0] * (1 - grad))
        g = int(GLASS_BLUE[1] * grad + DARK_GLASS[1] * (1 - grad))
        b = int(GLASS_BLUE[2] * grad + DARK_GLASS[2] * (1 - grad))
        pygame.draw.line(glass_surf, (r, g, b, alpha), (0, i), (w, i))
    screen.blit(glass_surf, (x, y))

    # 유리 테두리 (크롬)
    pygame.draw.rect(screen, CHROME, (x, y, w, h), 2, border_radius=8)

    # 3. 유리 반사 효과
    reflection_surf = pygame.Surface((w, h // 3), pygame.SRCALPHA)
    for i in range(h // 3):
        alpha = int(80 - i * 2)
        pygame.draw.line(reflection_surf, (*CHROME, alpha), (0, i), (w, i))
    screen.blit(reflection_surf, (x, y + 5))

    # 4. 홀로그램 그리드
    grid_spacing = 10
    for gx in range(0, w, grid_spacing):
        grid_alpha = int(30 * holo_flicker)
        pygame.draw.line(screen, (*HOLO_CYAN, grid_alpha),
                        (x + gx, y + 10), (x + gx, y + h - 10), 1)

    for gy in range(0, h, grid_spacing):
        grid_alpha = int(30 * holo_flicker)
        pygame.draw.line(screen, (*HOLO_CYAN, grid_alpha),
                        (x + 10, y + gy), (x + w - 10, y + gy), 1)

    # 5. 홀로그램 엠블렘 (★ ⇄ $)
    emblem_y = y + h // 3
    center_x = x + w // 2

    # 별 홀로그램 (3D 투영)
    star_x = center_x - 18

    # 홀로그램 투영 베이스
    for z in range(5):
        z_offset = z * 2
        z_alpha = int((120 - z * 20) * holo_flicker)

        star_points = []
        for i in range(5):
            angle_out = math.radians(i * 72 - 90 + energy_flow * 0.3)
            px = star_x + (8 + z_offset) * math.cos(angle_out)
            py = emblem_y + z_offset + (8 + z_offset) * math.sin(angle_out)
            star_points.append((px, py))

            angle_in = math.radians(i * 72 + 36 - 90 + energy_flow * 0.3)
            px_in = star_x + (3 + z_offset * 0.4) * math.cos(angle_in)
            py_in = emblem_y + z_offset + (3 + z_offset * 0.4) * math.sin(angle_in)
            star_points.append((px_in, py_in))

        pygame.draw.polygon(screen, (*GOLD_ACCENT, z_alpha), star_points, 2 if z > 0 else 0)

    # 데이터 스트림 화살표
    arrow_surf = pygame.Surface((35, 15), pygame.SRCALPHA)
    for i in range(6):
        arrow_offset = (i * 6 - int(energy_flow * 0.5)) % 35
        arrow_alpha = int(200 * holo_flicker)

        # 미래적 화살표
        arrow_points = [
            (arrow_offset, 7),
            (arrow_offset + 5, 4),
            (arrow_offset + 5, 10)
        ]
        pygame.draw.polygon(arrow_surf, (*HOLO_CYAN, arrow_alpha), arrow_points)
        pygame.draw.line(arrow_surf, (*HOLO_CYAN, arrow_alpha // 2),
                        (arrow_offset, 7), (arrow_offset + 5, 7), 1)

    screen.blit(arrow_surf, (center_x - 17, emblem_y - 7))

    # 금화 홀로그램 (3D 회전)
    coin_x = center_x + 18

    # 홀로그램 레이어
    for z in range(5):
        z_offset = z * 2
        z_alpha = int((120 - z * 20) * holo_flicker)
        coin_radius = 10 + z_offset

        pygame.draw.circle(screen, (*GOLD_ACCENT, z_alpha),
                          (coin_x, emblem_y + z_offset), coin_radius, 2)

        # 회전하는 $ 심볼
        if z == 0:
            font = pygame.font.Font(None, 20)
            dollar = font.render("$", True, GOLD_ACCENT)
            screen.blit(dollar, (coin_x - 5, emblem_y - 8))

    # 6. 에너지 코어 (중앙)
    core_y = y + h * 2 // 3
    core_size = int(8 + 4 * pulse)

    # 코어 글로우
    for i in range(4):
        glow_size = core_size + i * 4
        glow_alpha = int((100 - i * 20) * pulse)
        pygame.draw.circle(screen, (*ENERGY_GREEN, glow_alpha),
                          (center_x, core_y), glow_size)

    # 코어 본체
    pygame.draw.circle(screen, ENERGY_GREEN, (center_x, core_y), core_size)
    pygame.draw.circle(screen, CHROME, (center_x, core_y), core_size - 2)
    pygame.draw.circle(screen, ENERGY_GREEN, (center_x, core_y), core_size - 4)

    # 7. 데이터 스트림 라인
    stream_count = 4
    for i in range(stream_count):
        stream_x = x + 15 + i * (w - 30) // (stream_count - 1)
        stream_y = (y + int(data_stream) + i * 20) % h + y

        stream_alpha = int(150 * holo_flicker)

        # 스트림 선
        pygame.draw.line(screen, (*HOLO_PURPLE, stream_alpha),
                        (stream_x, stream_y - 15), (stream_x, stream_y), 2)

        # 스트림 끝점
        pygame.draw.circle(screen, (*HOLO_PURPLE, stream_alpha),
                          (stream_x, stream_y), 3)

    # 8. StarBank 홀로그램 텍스트
    title_y = y + h - 20
    title_font = pygame.font.Font(None, 18)

    # 스캔라인 효과
    scanline_surf = pygame.Surface((w - 20, 25), pygame.SRCALPHA)
    for i in range(0, 25, 2):
        alpha = int(40 * holo_flicker)
        pygame.draw.line(scanline_surf, (*HOLO_CYAN, alpha),
                        (0, i), (w - 20, i), 1)
    screen.blit(scanline_surf, (x + 10, title_y - 5))

    # 홀로그램 글로우
    for offset in range(4, 0, -1):
        glow_alpha = int((100 - offset * 20) * holo_flicker)
        glow_text = title_font.render("STARBANK", True, (*HOLO_CYAN, glow_alpha))
        glow_rect = glow_text.get_rect(center=(center_x, title_y))
        screen.blit(glow_text, (glow_rect.x - offset, glow_rect.y))
        screen.blit(glow_text, (glow_rect.x + offset, glow_rect.y))

    # 메인 텍스트
    title_text = title_font.render("STARBANK", True, CHROME)
    title_rect = title_text.get_rect(center=(center_x, title_y))
    screen.blit(title_text, title_rect)

    # 서브 텍스트
    sub_font = pygame.font.Font(None, 12)
    sub_text = sub_font.render("EXCHANGE SYSTEM", True, HOLO_CYAN)
    sub_rect = sub_text.get_rect(center=(center_x, title_y + 12))
    screen.blit(sub_text, sub_rect)

    # 9. 에너지 파티클
    random.seed(building_id * 19 + int(animation_timer * 4))
    for _ in range(10):
        px = random.randint(x + 10, x + w - 10)
        py_base = random.randint(y + 10, y + h - 10)
        py = (py_base - int(energy_flow * 0.8)) % (h - 20) + y + 10

        particle_alpha = random.randint(120, 200)
        particle_color = random.choice([ENERGY_GREEN, HOLO_CYAN, HOLO_PURPLE])
        particle_size = random.randint(1, 2)

        # 에너지 파티클
        pygame.draw.circle(screen, (*particle_color, particle_alpha), (px, py), particle_size)

        # 파티클 트레일
        pygame.draw.line(screen, (*particle_color, particle_alpha // 2),
                        (px, py), (px, py + 5), 1)
    random.seed()

    # 10. 모서리 강화 (크롬 액센트)
    corner_size = 8
    corners = [
        (x, y),  # 좌상
        (x + w - corner_size, y),  # 우상
        (x, y + h - corner_size),  # 좌하
        (x + w - corner_size, y + h - corner_size)  # 우하
    ]

    for cx, cy in corners:
        # L자 모양 강화
        pygame.draw.line(screen, CHROME, (cx, cy), (cx + corner_size, cy), 3)
        pygame.draw.line(screen, CHROME, (cx, cy), (cx, cy + corner_size), 3)


# 디자인 매핑
BANK_DESIGNS = {
    1: draw_bank_design1_elegant_marble,
    2: draw_bank_design2_neon_cyber,
    3: draw_bank_design3_crystal_palace,
    4: draw_bank_design4_golden_temple,
    5: draw_bank_design5_future_bank
}

def draw_bank_by_design(design_number, screen, building, x, y, building_id, animation_timer, particles):
    """선택된 디자인으로 은행 그리기"""
    design_func = BANK_DESIGNS.get(design_number, draw_bank_design1_elegant_marble)
    design_func(screen, building, x, y, building_id, animation_timer, particles)
