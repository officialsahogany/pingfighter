"""
라그나로크 해머 - 최외곽 전설 테두리 시스템
굵은 빨간색 테두리 + 4개 모서리 점을 하나의 통합 요소로
"""

import pygame
import math
import sys
import os

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((1200, 700))
pygame.display.set_caption("Legendary Outer Border System - Unified Component")
clock = pygame.time.Clock()

# 색상 정의
BACKGROUND = (30, 30, 50)
WHITE = (255, 255, 255)
LEGENDARY_RED = (255, 0, 0)

# 폰트
font = pygame.font.Font(None, 20)
title_font = pygame.font.Font(None, 28)
label_font = pygame.font.Font(None, 18)

# 애니메이션 변수
animation_time = 0

def draw_legendary_outer_border_system(surface, x, y, size, anim_time, show_parts=False):
    """
    전설 아이템 최외곽 테두리 시스템
    = 굵은 빨간색 펄싱 테두리 + 4개 모서리 점
    """

    # 펄싱 효과 계산
    pulse_intensity = 0.5 + 0.5 * math.sin(anim_time * 3)
    border_color = (
        int(255 * pulse_intensity),
        0,
        0
    )

    if show_parts:
        # 분리된 요소들 표시

        # 1. 굵은 빨간색 테두리만
        pygame.draw.rect(surface, border_color, (x, y, size, size), 3)

        # 2. 4개 모서리 점만 (분리 표시)
        corner_color = WHITE  # 스크린샷처럼 흰색
        corner_positions = [
            (x, y),  # Top-left
            (x + size, y),  # Top-right
            (x, y + size),  # Bottom-left
            (x + size, y + size)  # Bottom-right
        ]

        for cx, cy in corner_positions:
            pygame.draw.circle(surface, corner_color, (cx, cy), 3)
            # 점 주변 글로우 효과
            glow_surface = pygame.Surface((20, 20), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, (*corner_color, 50), (10, 10), 8)
            surface.blit(glow_surface, (cx - 10, cy - 10))

    else:
        # 통합된 시스템 표시

        # 굵은 빨간색 펄싱 테두리
        pygame.draw.rect(surface, border_color, (x, y, size, size), 3)

        # 4개 모서리 점 (테두리와 통합)
        corner_positions = [
            (x, y),  # Top-left
            (x + size, y),  # Top-right
            (x, y + size),  # Bottom-left
            (x + size, y + size)  # Bottom-right
        ]

        for cx, cy in corner_positions:
            # 흰색 점
            pygame.draw.circle(surface, WHITE, (cx, cy), 3)

            # 점 주변 빨간색 글로우 (테두리와 연결감)
            glow_color = (*border_color, 100)
            for i in range(3):
                glow_surface = pygame.Surface((20, 20), pygame.SRCALPHA)
                radius = 6 - i * 2
                alpha = 50 - i * 15
                pygame.draw.circle(glow_surface, (*border_color, alpha), (10, 10), radius)
                surface.blit(glow_surface, (cx - 10, cy - 10))

def draw_showcase(surface):
    """전체 쇼케이스"""

    # 제목
    title = title_font.render("Legendary Outer Border System", True, WHITE)
    title_rect = title.get_rect(centerx=600, top=30)
    surface.blit(title, title_rect)

    subtitle = font.render("굵은 빨간색 펄싱 테두리 + 4개 모서리 점", True, (200, 200, 200))
    subtitle_rect = subtitle.get_rect(centerx=600, top=65)
    surface.blit(subtitle, subtitle_rect)

    # 크기별 표시
    sizes = [80, 100, 120]
    start_x = 150
    y_pos = 150

    # 1. 분리된 요소들
    section_label = label_font.render("SEPARATED COMPONENTS (분리된 요소)", True, (255, 200, 100))
    surface.blit(section_label, (start_x, y_pos - 30))

    for i, size in enumerate(sizes):
        x_pos = start_x + i * 200

        # 배경 박스
        box = pygame.Surface((size + 40, size + 40), pygame.SRCALPHA)
        box.fill((40, 40, 60, 100))
        surface.blit(box, (x_pos - 20, y_pos - 20))

        # 분리된 요소 그리기
        draw_legendary_outer_border_system(surface, x_pos, y_pos, size, animation_time, show_parts=True)

        # 라벨
        size_label = label_font.render(f"{size}x{size}", True, (150, 150, 150))
        label_rect = size_label.get_rect(centerx=x_pos + size//2, top=y_pos + size + 10)
        surface.blit(size_label, label_rect)

    # 2. 통합된 시스템
    y_pos = 350
    section_label = label_font.render("UNIFIED SYSTEM (통합 시스템)", True, (100, 255, 100))
    surface.blit(section_label, (start_x, y_pos - 30))

    for i, size in enumerate(sizes):
        x_pos = start_x + i * 200

        # 배경 박스
        box = pygame.Surface((size + 40, size + 40), pygame.SRCALPHA)
        box.fill((40, 40, 60, 100))
        surface.blit(box, (x_pos - 20, y_pos - 20))

        # 통합 시스템 그리기
        draw_legendary_outer_border_system(surface, x_pos, y_pos, size, animation_time, show_parts=False)

        # 라벨
        size_label = label_font.render(f"{size}x{size}", True, (150, 150, 150))
        label_rect = size_label.get_rect(centerx=x_pos + size//2, top=y_pos + size + 10)
        surface.blit(size_label, label_rect)

    # 3. 명칭 정리
    y_pos = 550
    naming_title = label_font.render("OFFICIAL NAMING (공식 명칭)", True, WHITE)
    surface.blit(naming_title, (start_x, y_pos))

    names = [
        ("English:", "Legendary Outer Border System", (255, 200, 100)),
        ("한국어:", "전설 외곽 테두리 시스템", (100, 200, 255)),
        ("Components:", "Red Pulsing Border + 4 Corner Dots", (200, 200, 200)),
        ("구성요소:", "빨간 펄싱 테두리 + 4개 모서리 점", (200, 200, 200))
    ]

    y_offset = 30
    for label, text, color in names:
        label_surf = font.render(label, True, (150, 150, 150))
        surface.blit(label_surf, (start_x, y_pos + y_offset))

        text_surf = font.render(text, True, color)
        surface.blit(text_surf, (start_x + 120, y_pos + y_offset))

        y_offset += 25

def draw_technical_info(surface, x, y):
    """기술적 정보"""
    title = label_font.render("Technical Details", True, (200, 200, 200))
    surface.blit(title, (x, y))

    # 펄싱 정보
    pulse = 0.5 + 0.5 * math.sin(animation_time * 3)
    red_value = int(255 * pulse)

    details = [
        f"Border Width: 3px",
        f"Border Color: RGB({red_value}, 0, 0)",
        f"Pulse Function: sin(t * 3)",
        f"Pulse Range: 0.0 - 1.0",
        f"Current Intensity: {pulse:.2f}",
        "",
        "Corner Dots:",
        "  Color: RGB(255, 255, 255)",
        "  Radius: 3px",
        "  Position: Exact corners",
        "  Glow: Red fade effect"
    ]

    y_offset = 25
    for detail in details:
        if detail == "":
            y_offset += 10
            continue

        color = WHITE if not detail.startswith(" ") else (180, 180, 180)
        detail_surf = font.render(detail, True, color)
        surface.blit(detail_surf, (x, y + y_offset))
        y_offset += 20

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

    # 메인 쇼케이스
    draw_showcase(screen)

    # 기술 정보
    draw_technical_info(screen, 800, 150)

    # 애니메이션 타임라인
    timeline_y = 400
    timeline_x = 800

    timeline_title = label_font.render("Animation Timeline", True, (200, 200, 200))
    surface.blit(timeline_title, (timeline_x, timeline_y))

    # 타임라인 바
    bar_width = 300
    bar_height = 20
    bar_y = timeline_y + 30

    pygame.draw.rect(screen, (60, 60, 80), (timeline_x, bar_y, bar_width, bar_height), 1)

    # 현재 위치
    pulse = (math.sin(animation_time * 3) + 1) / 2
    pos_x = timeline_x + int(pulse * bar_width)
    pygame.draw.circle(screen, (255, 100, 100), (pos_x, bar_y + bar_height//2), 5)

    # 최소/최대 표시
    min_text = font.render("Min (127)", True, (150, 150, 150))
    screen.blit(min_text, (timeline_x - 10, bar_y + 25))

    max_text = font.render("Max (255)", True, (150, 150, 150))
    max_rect = max_text.get_rect(right=timeline_x + bar_width + 10, top=bar_y + 25)
    screen.blit(max_text, max_rect)

    # 컨트롤
    controls = font.render("Press ESC to exit", True, (100, 100, 100))
    controls_rect = controls.get_rect(centerx=600, bottom=680)
    screen.blit(controls, controls_rect)

    pygame.display.flip()

pygame.quit()
sys.exit()