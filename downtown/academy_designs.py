#!/usr/bin/env python3
"""
아카데미 학교 5가지 디자인 옵션
스킬 훈련/학습을 위한 건물
"""

import pygame
import math
import random
from downtown.constants import *

# =============================================================================
# 디자인 1: 아카데미 (해리포터 스타일)
# =============================================================================
def draw_academy_design1_magic_school(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 1: 아카데미 - 중세 성 + 마법 효과"""
    w, h = building.width, building.height

    # 색상 팔레트
    STONE_GRAY = (120, 120, 130)
    STONE_DARK = (80, 80, 90)
    MAGIC_PURPLE = (150, 100, 255)
    MAGIC_BLUE = (100, 150, 255)
    WINDOW_GOLD = (255, 230, 150)
    ROOF_RED = (150, 50, 50)
    BOOK_BROWN = (139, 90, 43)

    # 애니메이션
    pulse = 0.7 + 0.3 * abs(math.sin(animation_timer * 1.5))
    magic_glow = abs(math.sin(animation_timer * 2))
    float_offset = 5 * math.sin(animation_timer * 1.2)

    # 1. 마법 오라
    for i in range(4):
        aura_size = 35 - i * 8
        aura_alpha = int((70 - i * 15) * pulse)
        aura_surf = pygame.Surface((w + aura_size * 2, h + aura_size * 2), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_surf, (*MAGIC_PURPLE, aura_alpha),
                           (0, 0, w + aura_size * 2, h + aura_size * 2))
        screen.blit(aura_surf, (x - aura_size, y - aura_size))

    # 2. 돌 성벽 (메인 건물)
    castle_surf = pygame.Surface((w, h - 20), pygame.SRCALPHA)
    for i in range(h - 20):
        grad = 0.7 + 0.3 * math.sin(i * 0.1)
        r = int(STONE_GRAY[0] * grad)
        g = int(STONE_GRAY[1] * grad)
        b = int(STONE_GRAY[2] * grad)
        pygame.draw.line(castle_surf, (r, g, b), (0, i), (w, i))
    screen.blit(castle_surf, (x, y + 15))

    # 돌 블록 텍스처
    for row in range(3):
        for col in range(4):
            block_x = x + 8 + col * 18
            block_y = y + 20 + row * 18
            pygame.draw.rect(screen, STONE_DARK, (block_x, block_y, 16, 16), 1)

    # 3. 탑 3개 (중앙이 제일 높음)
    towers = [
        (x + 8, y + 5, 16, h - 25),           # 왼쪽 탑
        (x + w // 2 - 10, y - 5, 20, h - 15), # 중앙 탑 (제일 높음)
        (x + w - 24, y + 5, 16, h - 25)       # 오른쪽 탑
    ]

    for tower_x, tower_y, tower_w, tower_h in towers:
        # 탑 본체
        tower_surf = pygame.Surface((tower_w, tower_h), pygame.SRCALPHA)
        for i in range(tower_h):
            grad = 0.75 + 0.25 * math.sin(i * 0.08)
            color = (int(STONE_GRAY[0] * grad), int(STONE_GRAY[1] * grad), int(STONE_GRAY[2] * grad))
            pygame.draw.line(tower_surf, color, (0, i), (tower_w, i))
        screen.blit(tower_surf, (tower_x, tower_y))

        # 탑 테두리
        pygame.draw.rect(screen, STONE_DARK, (tower_x, tower_y, tower_w, tower_h), 2)

        # 성벽 톱니 (꼭대기)
        for i in range(3):
            merlon_x = tower_x + i * (tower_w // 3)
            pygame.draw.rect(screen, STONE_GRAY, (merlon_x, tower_y - 4, tower_w // 4, 4))

        # 탑 지붕 (뾰족한 원뿔)
        roof_points = [
            (tower_x, tower_y),
            (tower_x + tower_w // 2, tower_y - 12),
            (tower_x + tower_w, tower_y)
        ]
        pygame.draw.polygon(screen, ROOF_RED, roof_points)
        pygame.draw.polygon(screen, STONE_DARK, roof_points, 2)

    # 4. 마법 창문 (빛나는)
    windows = [
        (x + w // 2 - 8, y + 25),  # 중앙 위
        (x + 18, y + 35),          # 왼쪽
        (x + w - 26, y + 35),      # 오른쪽
        (x + w // 2 - 8, y + 50)   # 중앙 아래
    ]

    for win_x, win_y in windows:
        # 창문 글로우
        glow_alpha = int(120 * magic_glow)
        glow_surf = pygame.Surface((20, 20), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (*WINDOW_GOLD, glow_alpha), (0, 0, 20, 20))
        screen.blit(glow_surf, (win_x - 2, win_y - 2))

        # 창문 본체 (아치형)
        pygame.draw.rect(screen, WINDOW_GOLD, (win_x, win_y, 16, 18), border_radius=8)
        pygame.draw.line(screen, STONE_DARK, (win_x + 8, win_y), (win_x + 8, win_y + 18), 2)
        pygame.draw.line(screen, STONE_DARK, (win_x, win_y + 9), (win_x + 16, win_y + 9), 2)

    # 5. 정문 (아치형 대문)
    door_w = 22
    door_h = 30
    door_x = x + (w - door_w) // 2
    door_y = y + h - door_h - 5

    # 아치 프레임
    pygame.draw.rect(screen, STONE_DARK, (door_x - 3, door_y - 3, door_w + 6, door_h + 6), border_radius=12)

    # 문 본체
    door_surf = pygame.Surface((door_w, door_h), pygame.SRCALPHA)
    for i in range(door_h):
        grad = 0.4 + 0.3 * (i / door_h)
        color = (int(BOOK_BROWN[0] * grad), int(BOOK_BROWN[1] * grad), int(BOOK_BROWN[2] * grad))
        pygame.draw.line(door_surf, color, (0, i), (door_w, i))
    screen.blit(door_surf, (door_x, door_y))

    # 문 장식 (마법진)
    circle_center = (door_x + door_w // 2, door_y + door_h // 2)
    pygame.draw.circle(screen, MAGIC_PURPLE, circle_center, 8, 2)
    pygame.draw.circle(screen, MAGIC_BLUE, circle_center, 5, 1)

    # 6. 떠다니는 마법책 (아카데미 상징)
    book_y = y + 8 + float_offset
    book_x = x + w // 2 - 10

    # 책 글로우
    for i in range(3):
        glow_alpha = int((90 - i * 25) * pulse)
        pygame.draw.rect(screen, (*MAGIC_BLUE, glow_alpha),
                        (book_x - i * 2, book_y - i * 2, 20 + i * 4, 14 + i * 4), border_radius=2)

    # 책 본체
    pygame.draw.rect(screen, BOOK_BROWN, (book_x, book_y, 20, 14), border_radius=2)
    pygame.draw.rect(screen, (100, 60, 20), (book_x, book_y, 20, 14), 2, border_radius=2)

    # 책 페이지
    pygame.draw.line(screen, (200, 180, 140), (book_x + 10, book_y), (book_x + 10, book_y + 14), 1)

    # 마법 기호
    pygame.draw.circle(screen, MAGIC_PURPLE, (book_x + 10, book_y + 7), 3)

    # 7. Academy 각인
    title_y = y + h - 12
    title_font = pygame.font.Font(None, 14)

    # 마법 글로우
    for offset in range(2, 0, -1):
        glow_alpha = int((80 - offset * 30) * magic_glow)
        glow_text = title_font.render("ACADEMY", True, (*MAGIC_PURPLE, glow_alpha))
        glow_rect = glow_text.get_rect(center=(x + w // 2, title_y))
        screen.blit(glow_text, (glow_rect.x - offset, glow_rect.y))
        screen.blit(glow_text, (glow_rect.x + offset, glow_rect.y))

    title_text = title_font.render("ACADEMY", True, WINDOW_GOLD)
    title_rect = title_text.get_rect(center=(x + w // 2, title_y))
    screen.blit(title_text, title_rect)

    # 8. 마법 파티클 (반짝이는 별)
    random.seed(building_id * 13 + int(animation_timer * 3))
    for _ in range(8):
        px = random.randint(x + 5, x + w - 5)
        py = random.randint(y + 10, y + h - 15)

        particle_alpha = random.randint(120, 200)
        particle_color = random.choice([MAGIC_PURPLE, MAGIC_BLUE, WINDOW_GOLD])
        size = random.randint(1, 2)

        # 십자 반짝임
        pygame.draw.circle(screen, (*particle_color, particle_alpha), (px, py), size)
        pygame.draw.line(screen, (*particle_color, particle_alpha // 2),
                        (px - 3, py), (px + 3, py), 1)
        pygame.draw.line(screen, (*particle_color, particle_alpha // 2),
                        (px, py - 3), (px, py + 3), 1)
    random.seed()


# =============================================================================
# 디자인 2: 아카데미 (유리 건물)
# =============================================================================
def draw_academy_design2_modern_university(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 2: 아카데미 - 유리 건물 + 책 모티브"""
    w, h = building.width, building.height

    # 색상 팔레트
    GLASS_BLUE = (180, 210, 240)
    CONCRETE = (140, 140, 145)
    STEEL_GRAY = (100, 100, 110)
    WINDOW_CYAN = (150, 220, 255)
    ACCENT_ORANGE = (255, 150, 50)
    BOOK_BLUE = (70, 130, 180)
    TEXT_WHITE = (240, 240, 250)

    # 애니메이션
    pulse = 0.8 + 0.2 * abs(math.sin(animation_timer * 1.8))
    light_flicker = abs(math.sin(animation_timer * 3))

    # 1. 건물 그림자
    shadow_surf = pygame.Surface((w + 15, 15), pygame.SRCALPHA)
    for i in range(15):
        alpha = 40 - i * 2
        pygame.draw.ellipse(shadow_surf, (20, 20, 30, alpha), (0, i, w + 15, 15 - i))
    screen.blit(shadow_surf, (x - 5, y + h))

    # 2. 콘크리트 베이스
    base_h = 12
    base_surf = pygame.Surface((w, base_h), pygame.SRCALPHA)
    for i in range(base_h):
        grad = 0.9 + 0.1 * (i / base_h)
        color = (int(CONCRETE[0] * grad), int(CONCRETE[1] * grad), int(CONCRETE[2] * grad))
        pygame.draw.line(base_surf, color, (0, i), (w, i))
    screen.blit(base_surf, (x, y + h - base_h))
    pygame.draw.line(screen, STEEL_GRAY, (x, y + h - base_h), (x + w, y + h - base_h), 2)

    # 3. 유리 건물 본체
    glass_h = h - base_h - 15
    glass_surf = pygame.Surface((w, glass_h), pygame.SRCALPHA)
    for i in range(glass_h):
        grad = 0.6 + 0.4 * (i / glass_h)
        alpha = 200
        r = int(GLASS_BLUE[0] * grad)
        g = int(GLASS_BLUE[1] * grad)
        b = int(GLASS_BLUE[2] * grad)
        pygame.draw.line(glass_surf, (r, g, b, alpha), (0, i), (w, i))
    screen.blit(glass_surf, (x, y + 15))

    # 유리 반사
    reflection_surf = pygame.Surface((w, glass_h // 4), pygame.SRCALPHA)
    for i in range(glass_h // 4):
        alpha = 100 - i * 3
        pygame.draw.line(reflection_surf, (*TEXT_WHITE, alpha), (0, i), (w, i))
    screen.blit(reflection_surf, (x, y + 18))

    # 4. 창문 그리드
    window_rows = 4
    window_cols = 4
    window_spacing_x = (w - 16) // window_cols
    window_spacing_y = (glass_h - 12) // window_rows

    for row in range(window_rows):
        for col in range(window_cols):
            win_x = x + 8 + col * window_spacing_x
            win_y = y + 20 + row * window_spacing_y

            # 창문 (일부만 불이 켜짐)
            is_lit = (row + col + int(animation_timer)) % 3 == 0

            if is_lit:
                glow_alpha = int(150 * light_flicker)
                pygame.draw.rect(screen, (*WINDOW_CYAN, glow_alpha),
                               (win_x - 1, win_y - 1, window_spacing_x - 4, window_spacing_y - 4))
                pygame.draw.rect(screen, WINDOW_CYAN,
                               (win_x, win_y, window_spacing_x - 6, window_spacing_y - 6), 1)
            else:
                pygame.draw.rect(screen, STEEL_GRAY,
                               (win_x, win_y, window_spacing_x - 6, window_spacing_y - 6), 1)

    # 5. 입구 (현대식 자동문)
    door_w = 28
    door_h = 28
    door_x = x + (w - door_w) // 2
    door_y = y + h - base_h - door_h - 3

    # 문 프레임 (강철)
    pygame.draw.rect(screen, STEEL_GRAY, (door_x - 2, door_y - 2, door_w + 4, door_h + 4))

    # 유리문
    door_glass = pygame.Surface((door_w, door_h), pygame.SRCALPHA)
    for i in range(door_h):
        alpha = 180 + int(30 * math.sin(i * 0.2))
        pygame.draw.line(door_glass, (*GLASS_BLUE, alpha), (0, i), (door_w, i))
    screen.blit(door_glass, (door_x, door_y))

    # 문 손잡이
    pygame.draw.line(screen, ACCENT_ORANGE, (door_x + door_w // 2, door_y + 10),
                    (door_x + door_w // 2, door_y + door_h - 10), 3)

    # 6. 지붕 (책 모양)
    roof_h = 15
    roof_points = [
        (x, y + roof_h),
        (x + w // 2, y),
        (x + w, y + roof_h)
    ]

    # 지붕 그라데이션
    roof_surf = pygame.Surface((w, roof_h), pygame.SRCALPHA)
    for i in range(roof_h):
        grad = 0.7 + 0.3 * (i / roof_h)
        color = (int(BOOK_BLUE[0] * grad), int(BOOK_BLUE[1] * grad), int(BOOK_BLUE[2] * grad))
        progress = i / roof_h
        half_width = int((w // 2) * (1 - progress))
        pygame.draw.line(roof_surf, color,
                        (w // 2 - half_width, i), (w // 2 + half_width, i))
    screen.blit(roof_surf, (x, y))

    pygame.draw.polygon(screen, STEEL_GRAY, roof_points, 2)

    # 7. 학교 로고 (책 + 전구)
    logo_y = y + 6
    logo_x = x + w // 2

    # 열린 책
    book_w = 24
    book_h = 12
    pygame.draw.rect(screen, ACCENT_ORANGE, (logo_x - book_w // 2, logo_y, book_w, book_h), border_radius=2)
    pygame.draw.line(screen, TEXT_WHITE, (logo_x, logo_y), (logo_x, logo_y + book_h), 2)

    # 페이지 선
    for i in range(3):
        line_y = logo_y + 3 + i * 3
        pygame.draw.line(screen, TEXT_WHITE, (logo_x - 8, line_y), (logo_x - 2, line_y), 1)
        pygame.draw.line(screen, TEXT_WHITE, (logo_x + 2, line_y), (logo_x + 8, line_y), 1)

    # 8. ACADEMY 사인보드
    sign_y = y + h - base_h - 5
    sign_font = pygame.font.Font(None, 16)

    # 배경 패널
    sign_text = sign_font.render("ACADEMY", True, TEXT_WHITE)
    sign_rect = sign_text.get_rect(center=(x + w // 2, sign_y))
    pygame.draw.rect(screen, BOOK_BLUE, (sign_rect.x - 5, sign_rect.y - 2,
                                          sign_rect.width + 10, sign_rect.height + 4))
    pygame.draw.rect(screen, ACCENT_ORANGE, (sign_rect.x - 5, sign_rect.y - 2,
                                              sign_rect.width + 10, sign_rect.height + 4), 2)
    screen.blit(sign_text, sign_rect)

    # 9. 계단
    stairs = 3
    for i in range(stairs):
        stair_y = y + h - base_h + i * 4
        stair_w = w - i * 6
        stair_x = x + i * 3
        pygame.draw.line(screen, CONCRETE, (stair_x, stair_y), (stair_x + stair_w, stair_y), 3)


# =============================================================================
# 디자인 3: 동양 도장 (무술 수련장)
# =============================================================================
def draw_academy_design3_dojo(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 3: 동양 도장 - 일본/중국 전통 건축"""
    w, h = building.width, building.height

    # 색상 팔레트
    WOOD_BROWN = (139, 90, 43)
    WOOD_DARK = (90, 60, 30)
    ROOF_RED = (180, 50, 50)
    ROOF_DARK = (120, 30, 30)
    PAPER_WHITE = (245, 240, 230)
    INK_BLACK = (40, 40, 45)
    GOLD_ACCENT = (255, 200, 50)
    BAMBOO_GREEN = (100, 140, 80)

    # 애니메이션
    pulse = 0.85 + 0.15 * abs(math.sin(animation_timer * 1.5))
    sway = 3 * math.sin(animation_timer * 0.8)

    # 1. 그림자
    shadow_surf = pygame.Surface((w + 20, 18), pygame.SRCALPHA)
    for i in range(18):
        alpha = 35 - i * 1.5
        pygame.draw.ellipse(shadow_surf, (20, 15, 10, int(alpha)), (0, i, w + 20, 18 - i))
    screen.blit(shadow_surf, (x - 10, y + h - 2))

    # 2. 나무 플랫폼 (단)
    platform_h = 8
    for i in range(2):
        plat_y = y + h - platform_h - i * 6
        plat_w = w - i * 8
        plat_x = x + i * 4

        # 플랫폼 그라데이션
        plat_surf = pygame.Surface((plat_w, 5), pygame.SRCALPHA)
        for py in range(5):
            grad = 0.7 + 0.3 * (py / 5)
            color = (int(WOOD_BROWN[0] * grad), int(WOOD_BROWN[1] * grad), int(WOOD_BROWN[2] * grad))
            pygame.draw.line(plat_surf, color, (0, py), (plat_w, py))
        screen.blit(plat_surf, (plat_x, plat_y))

        # 플랫폼 테두리
        pygame.draw.line(screen, WOOD_DARK, (plat_x, plat_y), (plat_x + plat_w, plat_y), 2)

    # 3. 메인 건물 (나무 벽)
    building_h = h - 30
    building_surf = pygame.Surface((w - 10, building_h), pygame.SRCALPHA)

    # 나무 널빤지 텍스처
    for i in range(building_h):
        grad = 0.75 + 0.25 * math.sin(i * 0.15)
        color = (int(WOOD_BROWN[0] * grad), int(WOOD_BROWN[1] * grad), int(WOOD_BROWN[2] * grad))
        pygame.draw.line(building_surf, color, (0, i), (w - 10, i))

    # 나무 널빤지 선
    for plank in range(4):
        plank_y = plank * (building_h // 4)
        pygame.draw.line(building_surf, WOOD_DARK, (0, plank_y), (w - 10, plank_y), 1)

    screen.blit(building_surf, (x + 5, y + 20))

    # 4. 기둥 4개
    pillar_positions = [x + 8, x + w // 3, x + w * 2 // 3, x + w - 16]
    for px in pillar_positions:
        # 기둥 본체
        pillar_surf = pygame.Surface((8, building_h), pygame.SRCALPHA)
        for i in range(8):
            grad = 0.5 + 0.5 * abs(i - 4) / 4
            for py in range(building_h):
                color = (int(WOOD_DARK[0] * grad), int(WOOD_DARK[1] * grad), int(WOOD_DARK[2] * grad))
                pillar_surf.set_at((i, py), color)
        screen.blit(pillar_surf, (px, y + 20))

        # 기둥 링
        for ring_y in [y + 25, y + 20 + building_h // 2, y + 20 + building_h - 5]:
            pygame.draw.rect(screen, GOLD_ACCENT, (px - 1, ring_y, 10, 3))

    # 5. 처마 (2단 지붕)
    # 위쪽 작은 지붕
    small_roof_y = y + 8
    small_roof_w = w - 20
    small_roof_points = [
        (x + 10, small_roof_y + 8),
        (x + w // 2, small_roof_y),
        (x + w - 10, small_roof_y + 8)
    ]

    # 지붕 그라데이션
    small_roof_surf = pygame.Surface((small_roof_w, 10), pygame.SRCALPHA)
    for i in range(10):
        grad = 0.8 - i * 0.05
        color = (int(ROOF_RED[0] * grad), int(ROOF_RED[1] * grad), int(ROOF_RED[2] * grad))
        progress = i / 10
        half_width = int((small_roof_w // 2) * (1 - progress * 0.7))
        pygame.draw.line(small_roof_surf, color,
                        (small_roof_w // 2 - half_width, i),
                        (small_roof_w // 2 + half_width, i))
    screen.blit(small_roof_surf, (x + 10, small_roof_y))

    pygame.draw.polygon(screen, ROOF_DARK, small_roof_points, 3)

    # 처마 끝 장식 (곡선)
    pygame.draw.line(screen, GOLD_ACCENT, (x + 10, small_roof_y + 8), (x + 8, small_roof_y + 10), 2)
    pygame.draw.line(screen, GOLD_ACCENT, (x + w - 10, small_roof_y + 8), (x + w - 8, small_roof_y + 10), 2)

    # 큰 메인 지붕
    main_roof_y = y + 16
    main_roof_points = [
        (x - 8, main_roof_y + 12),
        (x + w // 2, main_roof_y),
        (x + w + 8, main_roof_y + 12)
    ]

    main_roof_surf = pygame.Surface((w + 20, 14), pygame.SRCALPHA)
    for i in range(14):
        grad = 0.85 - i * 0.04
        color = (int(ROOF_RED[0] * grad), int(ROOF_RED[1] * grad), int(ROOF_RED[2] * grad))
        progress = i / 14
        half_width = int((w // 2 + 10) * (1 - progress * 0.65))
        pygame.draw.line(main_roof_surf, color,
                        (w // 2 + 10 - half_width, i),
                        (w // 2 + 10 + half_width, i))
    screen.blit(main_roof_surf, (x - 10, main_roof_y))

    pygame.draw.polygon(screen, ROOF_DARK, main_roof_points, 3)

    # 처마 끝 곡선
    pygame.draw.arc(screen, GOLD_ACCENT, (x - 12, main_roof_y + 8, 12, 8), 0, math.pi, 2)
    pygame.draw.arc(screen, GOLD_ACCENT, (x + w, main_roof_y + 8, 12, 8), 0, math.pi, 2)

    # 6. 한지문 (슬라이딩 도어)
    door_w = 24
    door_h = 32
    door_x = x + (w - door_w) // 2
    door_y = y + h - building_h

    # 문틀
    pygame.draw.rect(screen, WOOD_DARK, (door_x - 3, door_y - 3, door_w + 6, door_h + 6))

    # 한지 (2개 패널)
    for panel in range(2):
        panel_x = door_x + panel * 12
        panel_surf = pygame.Surface((11, door_h), pygame.SRCALPHA)
        for i in range(door_h):
            grad = 0.95 + 0.05 * math.sin(i * 0.2)
            color = (int(PAPER_WHITE[0] * grad), int(PAPER_WHITE[1] * grad), int(PAPER_WHITE[2] * grad))
            pygame.draw.line(panel_surf, color, (0, i), (11, i))
        screen.blit(panel_surf, (panel_x, door_y))

        # 격자 무늬
        for grid in range(4):
            grid_y = door_y + 6 + grid * 7
            pygame.draw.line(screen, INK_BLACK, (panel_x, grid_y), (panel_x + 11, grid_y), 1)
        pygame.draw.line(screen, INK_BLACK, (panel_x + 5, door_y), (panel_x + 5, door_y + door_h), 1)

        # 테두리
        pygame.draw.rect(screen, WOOD_DARK, (panel_x, door_y, 11, door_h), 2)

    # 7. 서예 간판 (한자 스타일)
    sign_y = y + h - 16
    sign_font = pygame.font.Font(None, 18)

    # 나무 간판
    sign_bg = pygame.Rect(x + w // 2 - 32, sign_y - 3, 64, 16)
    pygame.draw.rect(screen, WOOD_BROWN, sign_bg, border_radius=2)
    pygame.draw.rect(screen, WOOD_DARK, sign_bg, 2, border_radius=2)

    # 붓글씨 효과
    title_text = sign_font.render("武館", True, INK_BLACK)  # 무관
    title_rect = title_text.get_rect(center=(x + w // 2, sign_y + 5))

    # 먹번짐 효과
    for offset in range(1, 0, -1):
        blur_alpha = 40
        blur_text = sign_font.render("武館", True, (*INK_BLACK, blur_alpha))
        screen.blit(blur_text, (title_rect.x + offset, title_rect.y + offset))

    screen.blit(title_text, title_rect)

    # 8. 대나무 (양옆 장식)
    bamboo_positions = [(x - 5 + sway, y + 25), (x + w + 5 - sway, y + 25)]

    for bx, by in bamboo_positions:
        # 대나무 줄기
        segments = 4
        segment_h = (h - 40) // segments

        for seg in range(segments):
            seg_y = by + seg * segment_h

            # 줄기
            pygame.draw.line(screen, BAMBOO_GREEN, (bx, seg_y), (bx, seg_y + segment_h), 4)

            # 마디
            pygame.draw.circle(screen, WOOD_DARK, (bx, seg_y), 3)

            # 잎
            if seg > 1:
                leaf_angle = math.radians(45 + seg * 15)
                leaf_x = bx + 10 * math.cos(leaf_angle)
                leaf_y = seg_y + 10 * math.sin(leaf_angle)
                pygame.draw.line(screen, BAMBOO_GREEN, (bx, seg_y), (leaf_x, leaf_y), 2)


# =============================================================================
# 디자인 4: 사이버 훈련소 (미래형)
# =============================================================================
def draw_academy_design4_cyber_training(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 4: 사이버 훈련소 - VR/AR 훈련 센터"""
    w, h = building.width, building.height

    # 색상 팔레트
    CYBER_DARK = (20, 25, 40)
    NEON_BLUE = (0, 200, 255)
    NEON_PINK = (255, 50, 150)
    NEON_GREEN = (50, 255, 150)
    CHROME = (200, 210, 220)
    HOLO_PURPLE = (180, 100, 255)
    ENERGY_YELLOW = (255, 255, 100)

    # 애니메이션
    pulse = 0.6 + 0.4 * abs(math.sin(animation_timer * 2.5))
    scan = (animation_timer * 60) % h
    data_flow = animation_timer * 40
    holo_flicker = 0.85 + 0.15 * abs(math.sin(animation_timer * 5))

    # 1. 에너지 필드
    for i in range(4):
        field_size = 30 - i * 7
        field_alpha = int((65 - i * 14) * pulse)
        field_surf = pygame.Surface((w + field_size * 2, h + field_size * 2), pygame.SRCALPHA)
        pygame.draw.rect(field_surf, (*NEON_BLUE, field_alpha),
                        (field_size, field_size, w, h), border_radius=10)
        screen.blit(field_surf, (x - field_size, y - field_size))

    # 2. 메인 건물 (어두운 금속)
    main_surf = pygame.Surface((w, h), pygame.SRCALPHA)
    for i in range(h):
        grad = 0.3 + 0.15 * math.sin(i * 0.08)
        r = int(CYBER_DARK[0] * grad)
        g = int(CYBER_DARK[1] * grad)
        b = int(CYBER_DARK[2] * (grad + 0.3))
        pygame.draw.line(main_surf, (r, g, b), (0, i), (w, i))
    screen.blit(main_surf, (x, y))

    # 크롬 테두리
    pygame.draw.rect(screen, CHROME, (x, y, w, h), 2, border_radius=8)

    # 3. 홀로그램 그리드
    grid_spacing = 12
    for gx in range(0, w, grid_spacing):
        grid_alpha = int(25 * holo_flicker)
        pygame.draw.line(screen, (*NEON_BLUE, grid_alpha),
                        (x + gx, y + 5), (x + gx, y + h - 5), 1)

    for gy in range(0, h, grid_spacing):
        grid_alpha = int(25 * holo_flicker)
        pygame.draw.line(screen, (*NEON_BLUE, grid_alpha),
                        (x + 5, y + gy), (x + w - 5, y + gy), 1)

    # 4. VR 헤드셋 홀로그램 (상징)
    holo_y = y + h // 4
    holo_x = x + w // 2

    # 홀로그램 레이어
    for layer in range(3):
        layer_offset = layer * 2
        layer_alpha = int((120 - layer * 35) * holo_flicker)

        # VR 고글
        goggle_w = 28 + layer_offset
        goggle_h = 12 + layer_offset
        goggle_rect = pygame.Rect(holo_x - goggle_w // 2, holo_y, goggle_w, goggle_h)

        pygame.draw.ellipse(screen, (*HOLO_PURPLE, layer_alpha), goggle_rect, 2)

        # 렌즈
        left_lens = (holo_x - 8, holo_y + goggle_h // 2)
        right_lens = (holo_x + 8, holo_y + goggle_h // 2)

        if layer == 0:
            pygame.draw.circle(screen, NEON_BLUE, left_lens, 5)
            pygame.draw.circle(screen, NEON_PINK, right_lens, 5)
        else:
            pygame.draw.circle(screen, (*HOLO_PURPLE, layer_alpha), left_lens, 5 + layer, 1)
            pygame.draw.circle(screen, (*HOLO_PURPLE, layer_alpha), right_lens, 5 + layer, 1)

    # 5. 스캔 라인
    scan_surf = pygame.Surface((w, 3), pygame.SRCALPHA)
    pygame.draw.rect(scan_surf, (*NEON_GREEN, 200), (0, 0, w, 3))
    screen.blit(scan_surf, (x, y + int(scan)))

    # 6. 데이터 스트림 (흐르는 숫자)
    stream_count = 5
    for i in range(stream_count):
        stream_x = x + 10 + i * (w - 20) // (stream_count - 1)
        stream_offset = (int(data_flow) + i * 15) % (h - 10)
        stream_y = y + 5 + stream_offset

        stream_alpha = int(180 * holo_flicker)

        # 숫자 스트림
        pygame.draw.line(screen, (*NEON_GREEN, stream_alpha),
                        (stream_x, stream_y - 12), (stream_x, stream_y), 2)
        pygame.draw.circle(screen, (*NEON_GREEN, stream_alpha), (stream_x, stream_y), 2)

    # 7. 상태 표시 패널 (LED)
    panel_y = y + h - 30
    led_spacing = (w - 20) // 6

    for i in range(6):
        led_x = x + 10 + i * led_spacing
        led_color = random.choice([NEON_BLUE, NEON_GREEN, NEON_PINK])
        led_alpha = int(200 * abs(math.sin(animation_timer * 2 + i * 0.5)))

        # LED 글로우
        pygame.draw.circle(screen, (*led_color, led_alpha // 2), (led_x, panel_y), 4)
        # LED 코어
        pygame.draw.circle(screen, led_color, (led_x, panel_y), 2)

    # 8. 출입문 (에너지 게이트)
    gate_w = 26
    gate_h = 35
    gate_x = x + (w - gate_w) // 2
    gate_y = y + h - gate_h - 8

    # 게이트 프레임
    pygame.draw.rect(screen, CHROME, (gate_x - 3, gate_y - 3, gate_w + 6, gate_h + 6), border_radius=8)

    # 에너지 필드 (스캔 효과)
    gate_surf = pygame.Surface((gate_w, gate_h), pygame.SRCALPHA)
    for i in range(gate_h):
        scan_phase = (i + int(animation_timer * 50)) % gate_h
        alpha = int(120 + 80 * abs(math.sin(scan_phase * 0.3)))
        r = int((NEON_BLUE[0] + HOLO_PURPLE[0]) / 2)
        g = int((NEON_BLUE[1] + HOLO_PURPLE[1]) / 2)
        b = int((NEON_BLUE[2] + HOLO_PURPLE[2]) / 2)
        pygame.draw.line(gate_surf, (r, g, b, alpha), (0, i), (gate_w, i))
    screen.blit(gate_surf, (gate_x, gate_y))

    # 게이트 그리드
    for gx in range(0, gate_w, 6):
        pygame.draw.line(screen, (*CHROME, 60), (gate_x + gx, gate_y), (gate_x + gx, gate_y + gate_h), 1)

    # 9. TRAINING 홀로그램 텍스트
    title_y = y + h - 12
    title_font = pygame.font.Font(None, 14)

    # 홀로그램 글리치 효과
    for glitch in range(3):
        glitch_offset = random.randint(-1, 1) if random.random() < 0.3 else 0
        glitch_alpha = int((90 - glitch * 30) * holo_flicker)
        glitch_text = title_font.render("TRAINING", True, (*NEON_BLUE, glitch_alpha))
        glitch_rect = glitch_text.get_rect(center=(x + w // 2 + glitch_offset, title_y + glitch * 0.5))
        screen.blit(glitch_text, glitch_rect)

    # 메인 텍스트
    title_text = title_font.render("TRAINING", True, CHROME)
    title_rect = title_text.get_rect(center=(x + w // 2, title_y))
    screen.blit(title_text, title_rect)

    # 10. 에너지 파티클
    random.seed(building_id * 23 + int(animation_timer * 4))
    for _ in range(10):
        px = random.randint(x + 8, x + w - 8)
        py_base = random.randint(y + 8, y + h - 8)
        py = (py_base - int(data_flow * 0.6)) % (h - 16) + y + 8

        particle_alpha = random.randint(140, 220)
        particle_color = random.choice([NEON_BLUE, NEON_GREEN, NEON_PINK, ENERGY_YELLOW])
        size = random.randint(1, 2)

        pygame.draw.circle(screen, (*particle_color, particle_alpha), (px, py), size)
        # 트레일
        pygame.draw.line(screen, (*particle_color, particle_alpha // 2),
                        (px, py), (px, py + 6), 1)
    random.seed()


# =============================================================================
# 디자인 5: 고대 신전 (그리스/로마)
# =============================================================================
def draw_academy_design5_ancient_temple(screen, building, x, y, building_id, animation_timer, particles):
    """디자인 5: 고대 신전 - 지혜의 신전"""
    w, h = building.width, building.height

    # 색상 팔레트
    MARBLE = (240, 235, 230)
    MARBLE_SHADOW = (180, 175, 170)
    GOLD = (255, 215, 0)
    GOLD_DARK = (200, 165, 0)
    COLUMN_WHITE = (250, 245, 240)
    SKY_BLUE = (135, 206, 250)
    WISDOM_PURPLE = (138, 43, 226)
    SCROLL_BEIGE = (245, 222, 179)

    # 애니메이션
    pulse = 0.75 + 0.25 * abs(math.sin(animation_timer * 1.3))
    glow = abs(math.sin(animation_timer * 2))
    float_offset = 4 * math.sin(animation_timer)

    # 1. 신성한 빛
    for i in range(5):
        light_size = 35 - i * 7
        light_alpha = int((60 - i * 10) * glow)
        light_surf = pygame.Surface((w + light_size * 2, h + light_size * 2), pygame.SRCALPHA)
        pygame.draw.ellipse(light_surf, (*GOLD, light_alpha),
                           (light_size, light_size, w, h))
        screen.blit(light_surf, (x - light_size, y - light_size))

    # 2. 대리석 기단 (3단)
    for step in range(3):
        step_y = y + h - 10 - step * 5
        step_w = w - step * 6
        step_x = x + step * 3

        step_surf = pygame.Surface((step_w, 6), pygame.SRCALPHA)
        for i in range(6):
            grad = 0.9 + 0.1 * (i / 6)
            color = (int(MARBLE[0] * grad), int(MARBLE[1] * grad), int(MARBLE[2] * grad))
            pygame.draw.line(step_surf, color, (0, i), (step_w, i))
        screen.blit(step_surf, (step_x, step_y))

        # 황금 라인
        pygame.draw.line(screen, GOLD, (step_x, step_y), (step_x + step_w, step_y), 2)

    # 3. 대리석 본체
    temple_h = h - 35
    temple_surf = pygame.Surface((w, temple_h), pygame.SRCALPHA)
    for i in range(temple_h):
        grad = 0.92 + 0.08 * math.sin(i * 0.1)
        color = (int(MARBLE[0] * grad), int(MARBLE[1] * grad), int(MARBLE[2] * grad))
        pygame.draw.line(temple_surf, color, (0, i), (w, i))
    screen.blit(temple_surf, (x, y + 25))

    # 대리석 질감
    for vein in range(3):
        vein_y = y + 30 + vein * (temple_h // 3)
        vein_alpha = random.randint(20, 40)
        pygame.draw.line(screen, (*MARBLE_SHADOW, vein_alpha),
                        (x + 5, vein_y), (x + w - 5, vein_y + random.randint(-2, 2)), 1)

    # 4. 기둥 6개 (도리아식)
    column_count = 6
    column_spacing = (w - 20) // (column_count - 1)

    for i in range(column_count):
        col_x = x + 10 + i * column_spacing
        col_h = temple_h - 10

        # 기둥 본체
        col_surf = pygame.Surface((6, col_h), pygame.SRCALPHA)
        for cy in range(col_h):
            # 엔타시스 (중간이 약간 볼록)
            bulge = 1 - abs(cy - col_h / 2) / (col_h / 2)
            width_factor = 1 + bulge * 0.15

            for cx in range(6):
                grad = 0.7 + 0.3 * abs(cx - 3) / 3
                color = (int(COLUMN_WHITE[0] * grad), int(COLUMN_WHITE[1] * grad), int(COLUMN_WHITE[2] * grad))
                col_surf.set_at((cx, cy), color)

        screen.blit(col_surf, (col_x - 3, y + 30))

        # 세로 홈 (플루팅)
        for flute in range(3):
            flute_x = col_x - 2 + flute * 2
            pygame.draw.line(screen, MARBLE_SHADOW, (flute_x, y + 32), (flute_x, y + 30 + col_h - 5), 1)

        # 기둥 머리 (주두)
        capital_y = y + 28
        pygame.draw.rect(screen, COLUMN_WHITE, (col_x - 5, capital_y, 10, 4))
        pygame.draw.rect(screen, GOLD, (col_x - 6, capital_y - 2, 12, 3))

    # 5. 박공 (페디먼트)
    pediment_y = y + 15
    pediment_points = [
        (x, pediment_y + 10),
        (x + w // 2, pediment_y),
        (x + w, pediment_y + 10)
    ]

    # 박공 그라데이션
    pediment_surf = pygame.Surface((w, 12), pygame.SRCALPHA)
    for i in range(12):
        grad = 0.88 - i * 0.04
        color = (int(MARBLE[0] * grad), int(MARBLE[1] * grad), int(MARBLE[2] * grad))
        progress = i / 12
        half_width = int((w // 2) * (1 - progress * 0.85))
        pygame.draw.line(pediment_surf, color,
                        (w // 2 - half_width, i), (w // 2 + half_width, i))
    screen.blit(pediment_surf, (x, pediment_y))

    pygame.draw.polygon(screen, MARBLE_SHADOW, pediment_points, 3)

    # 6. 박공 장식 (지혜의 상징 - 올빼미)
    owl_x = x + w // 2
    owl_y = pediment_y + 5

    # 올빼미 실루엣
    pygame.draw.circle(screen, WISDOM_PURPLE, (owl_x, owl_y), 6)  # 머리
    pygame.draw.circle(screen, GOLD, (owl_x - 2, owl_y), 2)  # 왼쪽 눈
    pygame.draw.circle(screen, GOLD, (owl_x + 2, owl_y), 2)  # 오른쪽 눈

    # 7. 입구 (대리석 문)
    door_w = 22
    door_h = 30
    door_x = x + (w - door_w) // 2
    door_y = y + h - 30 - door_h

    # 문 프레임
    pygame.draw.rect(screen, GOLD_DARK, (door_x - 3, door_y - 3, door_w + 6, door_h + 6))

    # 문 본체
    door_surf = pygame.Surface((door_w, door_h), pygame.SRCALPHA)
    for i in range(door_h):
        grad = 0.75 + 0.25 * (i / door_h)
        color = (int(MARBLE[0] * grad), int(MARBLE[1] * grad), int(MARBLE[2] * grad))
        pygame.draw.line(door_surf, color, (0, i), (door_w, i))
    screen.blit(door_surf, (door_x, door_y))

    # 문 장식 (그리스 문양)
    pygame.draw.rect(screen, GOLD, (door_x + 3, door_y + 5, door_w - 6, door_h - 10), 2)

    # 미앤더 패턴 (간단화)
    pattern_y = door_y + door_h // 2
    pygame.draw.line(screen, GOLD, (door_x + 6, pattern_y), (door_x + door_w - 6, pattern_y), 2)

    # 8. 떠다니는 두루마리 (지혜의 상징)
    scroll_y = y + 5 + float_offset
    scroll_x = x + w // 2 - 12

    # 두루마리 글로우
    for i in range(3):
        glow_alpha = int((80 - i * 20) * pulse)
        pygame.draw.rect(screen, (*WISDOM_PURPLE, glow_alpha),
                        (scroll_x - i * 2, scroll_y - i * 2, 24 + i * 4, 12 + i * 4), border_radius=2)

    # 두루마리 본체
    pygame.draw.rect(screen, SCROLL_BEIGE, (scroll_x, scroll_y, 24, 12), border_radius=2)
    pygame.draw.rect(screen, GOLD_DARK, (scroll_x, scroll_y, 24, 12), 2, border_radius=2)

    # 두루마리 손잡이
    pygame.draw.rect(screen, GOLD, (scroll_x - 2, scroll_y + 2, 3, 8))
    pygame.draw.rect(screen, GOLD, (scroll_x + 23, scroll_y + 2, 3, 8))

    # 그리스 문자 (간단화)
    pygame.draw.line(screen, WISDOM_PURPLE, (scroll_x + 6, scroll_y + 4), (scroll_x + 18, scroll_y + 4), 1)
    pygame.draw.line(screen, WISDOM_PURPLE, (scroll_x + 6, scroll_y + 8), (scroll_x + 18, scroll_y + 8), 1)

    # 9. ACADEMY 라틴어 각인
    title_y = y + h - 15
    title_font = pygame.font.Font(None, 16)

    # 돌에 새긴 효과
    for offset in range(2, 0, -1):
        shadow_alpha = 60
        shadow_text = title_font.render("ACADEMIA", True, (*MARBLE_SHADOW, shadow_alpha))
        shadow_rect = shadow_text.get_rect(center=(x + w // 2 + offset, title_y + offset))
        screen.blit(shadow_text, shadow_rect)

    title_text = title_font.render("ACADEMIA", True, GOLD)
    title_rect = title_text.get_rect(center=(x + w // 2, title_y))
    screen.blit(title_text, title_rect)

    # 10. 지혜의 빛 파티클
    random.seed(building_id * 17 + int(animation_timer * 2.5))
    for _ in range(8):
        px = random.randint(x + 8, x + w - 8)
        py = random.randint(y + 15, y + h - 20)

        particle_alpha = random.randint(100, 180)
        particle_color = random.choice([GOLD, WISDOM_PURPLE, SKY_BLUE])

        # 빛나는 점
        pygame.draw.circle(screen, (*particle_color, particle_alpha), (px, py), 1)

        # 십자 빛
        pygame.draw.line(screen, (*particle_color, particle_alpha // 2),
                        (px - 2, py), (px + 2, py), 1)
        pygame.draw.line(screen, (*particle_color, particle_alpha // 2),
                        (px, py - 2), (px, py + 2), 1)
    random.seed()


# 디자인 매핑
ACADEMY_DESIGNS = {
    1: draw_academy_design1_magic_school,
    2: draw_academy_design2_modern_university,
    3: draw_academy_design3_dojo,
    4: draw_academy_design4_cyber_training,
    5: draw_academy_design5_ancient_temple
}

def draw_academy_by_design(design_number, screen, building, x, y, building_id, animation_timer, particles):
    """선택된 디자인으로 아카데미 그리기"""
    design_func = ACADEMY_DESIGNS.get(design_number, draw_academy_design1_magic_school)
    design_func(screen, building, x, y, building_id, animation_timer, particles)
