"""
라그나로크 해머 - 빨간 테두리와 모서리 점 완전 분리
각 요소를 개별적으로 분리해서 표시
"""

import pygame
import math
import sys

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((1400, 800))
pygame.display.set_caption("Red Border & Corner Dots - Completely Separated")
clock = pygame.time.Clock()

# 색상 정의
BACKGROUND = (30, 30, 50)
WHITE = (255, 255, 255)

# 폰트
small_font = pygame.font.Font(None, 14)
font = pygame.font.Font(None, 18)
title_font = pygame.font.Font(None, 28)
label_font = pygame.font.Font(None, 20)

# 애니메이션 변수
animation_time = 0

def draw_only_red_border(surface, x, y, size, anim_time):
    """1. 빨간색 펄싱 테두리만 (점 없음)"""

    # 배경 박스
    box = pygame.Surface((size + 40, size + 60), pygame.SRCALPHA)
    box.fill((40, 40, 60, 100))
    surface.blit(box, (x - 20, y - 20))

    # 펄싱 효과
    pulse = 0.5 + 0.5 * math.sin(anim_time * 3)
    border_color = (int(255 * pulse), 0, 0)

    # 굵은 빨간 테두리만 그리기 (점 없음!)
    pygame.draw.rect(surface, border_color, (x, y, size, size), 3)

    # 라벨
    label = label_font.render("Red Border ONLY", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 10)
    surface.blit(label, label_rect)

    desc = font.render("빨간 테두리만", True, (200, 100, 100))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 32)
    surface.blit(desc, desc_rect)

    # 색상 정보
    color_info = small_font.render(f"RGB({border_color[0]}, 0, 0)", True, (255, 100, 100))
    info_rect = color_info.get_rect(centerx=x + size//2, top=y + size + 48)
    surface.blit(color_info, info_rect)

def draw_only_corner_dots(surface, x, y, size):
    """2. 4개 모서리 점만 (테두리 없음)"""

    # 배경 박스
    box = pygame.Surface((size + 40, size + 60), pygame.SRCALPHA)
    box.fill((40, 40, 60, 100))
    surface.blit(box, (x - 20, y - 20))

    # 가이드라인 (점 위치 표시용 - 연한 회색)
    pygame.draw.rect(surface, (60, 60, 60), (x, y, size, size), 1)

    # 4개 모서리 점만 그리기 (테두리 없음!)
    corner_positions = [
        (x, y),                    # Top-left
        (x + size, y),            # Top-right
        (x, y + size),            # Bottom-left
        (x + size, y + size)      # Bottom-right
    ]

    for cx, cy in corner_positions:
        # 흰색 점
        pygame.draw.circle(surface, WHITE, (cx, cy), 3)

        # 점 주변 글로우
        for i in range(3):
            glow_surf = pygame.Surface((16, 16), pygame.SRCALPHA)
            radius = 8 - i * 2
            alpha = 60 - i * 20
            pygame.draw.circle(glow_surf, (255, 255, 255, alpha), (8, 8), radius)
            surface.blit(glow_surf, (cx - 8, cy - 8))

    # 라벨
    label = label_font.render("Corner Dots ONLY", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 10)
    surface.blit(label, label_rect)

    desc = font.render("모서리 점만", True, (200, 200, 200))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 32)
    surface.blit(desc, desc_rect)

    # 정보
    info = small_font.render("4 White Dots", True, (200, 200, 200))
    info_rect = info.get_rect(centerx=x + size//2, top=y + size + 48)
    surface.blit(info, info_rect)

def draw_combined_preview(surface, x, y, size, anim_time):
    """3. 두 요소가 합쳐진 모습 (참고용)"""

    # 배경 박스
    box = pygame.Surface((size + 40, size + 60), pygame.SRCALPHA)
    box.fill((40, 40, 60, 100))
    surface.blit(box, (x - 20, y - 20))

    # 펄싱 효과
    pulse = 0.5 + 0.5 * math.sin(anim_time * 3)
    border_color = (int(255 * pulse), 0, 0)

    # 빨간 테두리
    pygame.draw.rect(surface, border_color, (x, y, size, size), 3)

    # 4개 모서리 점
    corner_positions = [
        (x, y), (x + size, y),
        (x, y + size), (x + size, y + size)
    ]

    for cx, cy in corner_positions:
        pygame.draw.circle(surface, WHITE, (cx, cy), 3)

    # 라벨
    label = label_font.render("Combined", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 10)
    surface.blit(label, label_rect)

    desc = font.render("합쳐진 모습", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 32)
    surface.blit(desc, desc_rect)

def draw_visual_equation(surface, x, y, size, anim_time):
    """시각적 방정식 표시"""

    # 제목
    title = label_font.render("Visual Equation", True, WHITE)
    surface.blit(title, (x, y - 30))

    # 요소들 표시
    elem_size = 60
    spacing = 100

    # 1. 빨간 테두리
    pulse = 0.5 + 0.5 * math.sin(anim_time * 3)
    border_color = (int(255 * pulse), 0, 0)
    pygame.draw.rect(surface, border_color, (x, y, elem_size, elem_size), 3)

    label1 = small_font.render("Red Border", True, (255, 100, 100))
    surface.blit(label1, (x - 5, y + elem_size + 5))

    # + 기호
    plus = title_font.render("+", True, WHITE)
    surface.blit(plus, (x + elem_size + 30, y + elem_size//2 - 10))

    # 2. 모서리 점들
    dots_x = x + spacing
    pygame.draw.rect(surface, (60, 60, 60), (dots_x, y, elem_size, elem_size), 1)

    corners = [(dots_x, y), (dots_x + elem_size, y),
               (dots_x, y + elem_size), (dots_x + elem_size, y + elem_size)]
    for cx, cy in corners:
        pygame.draw.circle(surface, WHITE, (cx, cy), 3)

    label2 = small_font.render("Corner Dots", True, (200, 200, 200))
    surface.blit(label2, (dots_x - 5, y + elem_size + 5))

    # = 기호
    equals = title_font.render("=", True, WHITE)
    surface.blit(equals, (dots_x + elem_size + 30, y + elem_size//2 - 10))

    # 3. 결합된 모습
    combined_x = dots_x + spacing
    pygame.draw.rect(surface, border_color, (combined_x, y, elem_size, elem_size), 3)

    corners = [(combined_x, y), (combined_x + elem_size, y),
               (combined_x, y + elem_size), (combined_x + elem_size, y + elem_size)]
    for cx, cy in corners:
        pygame.draw.circle(surface, WHITE, (cx, cy), 3)

    label3 = small_font.render("Final", True, (150, 255, 150))
    surface.blit(label3, (combined_x + 10, y + elem_size + 5))

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

    # 메인 제목
    main_title = title_font.render("Red Border & Corner Dots - COMPLETELY SEPARATED", True, WHITE)
    title_rect = main_title.get_rect(centerx=700, top=30)
    screen.blit(main_title, title_rect)

    # 메인 표시 영역
    main_size = 120
    start_x = 150
    main_y = 120
    spacing = 300

    # 1. 빨간 테두리만
    draw_only_red_border(screen, start_x, main_y, main_size, animation_time)

    # 2. 모서리 점만
    draw_only_corner_dots(screen, start_x + spacing, main_y, main_size)

    # 3. 합쳐진 모습 (참고)
    draw_combined_preview(screen, start_x + spacing * 2, main_y, main_size, animation_time)

    # 시각적 방정식
    draw_visual_equation(screen, start_x, main_y + 250, main_size, animation_time)

    # 기술 정보
    info_x = 150
    info_y = 480

    info_title = label_font.render("Technical Specifications", True, (200, 200, 200))
    screen.blit(info_title, (info_x, info_y))

    pulse = 0.5 + 0.5 * math.sin(animation_time * 3)
    red_value = int(255 * pulse)

    specs = [
        "",
        "Component 1 - Red Pulsing Border:",
        f"  • Color: RGB({red_value}, 0, 0)",
        "  • Width: 3 pixels",
        "  • Animation: sin(t * 3)",
        "  • Range: RGB(127-255, 0, 0)",
        "",
        "Component 2 - Corner Dots:",
        "  • Color: RGB(255, 255, 255) - Pure White",
        "  • Size: 3 pixel radius",
        "  • Position: Exact corners (0,0), (size,0), (0,size), (size,size)",
        "  • Glow: White fade effect",
        "  • Count: 4 dots total"
    ]

    y_offset = 25
    for spec in specs:
        if spec == "":
            y_offset += 5
            continue

        if spec.startswith("Component"):
            color = (255, 200, 100)
        elif spec.startswith("  •"):
            color = (180, 180, 180)
        else:
            color = (150, 150, 150)

        spec_text = small_font.render(spec, True, color)
        screen.blit(spec_text, (info_x, info_y + y_offset))
        y_offset += 18

    # 애니메이션 정보
    anim_info = small_font.render(f"Animation Time: {animation_time:.2f}s | Pulse: {pulse:.2f}",
                                 True, (150, 150, 150))
    anim_rect = anim_info.get_rect(centerx=700, bottom=780)
    screen.blit(anim_info, anim_rect)

    pygame.display.flip()

pygame.quit()
sys.exit()