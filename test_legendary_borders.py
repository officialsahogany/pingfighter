"""
전설 아이템 테두리 애니메이션 시각화
- Outer Frame (은색 정적 프레임)
- Legendary Border (빨간색 펄싱 애니메이션)
"""

import pygame
import math
import sys

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 400))
pygame.display.set_caption("Legendary Item Border Animation")
clock = pygame.time.Clock()

# 색상 정의
BACKGROUND = (30, 30, 50)
WHITE = (255, 255, 255)

# 폰트 설정
font = pygame.font.Font(None, 24)
title_font = pygame.font.Font(None, 32)

# 애니메이션 시간
animation_time = 0

def draw_outer_frame_demo(surface, x, y, size):
    """Outer Frame (은색 정적 프레임) 시연"""
    # 배경 박스
    box = pygame.Surface((size, size), pygame.SRCALPHA)
    box.fill((50, 50, 80, 200))

    # Outer frame (은색/회색 정적 프레임)
    frame_color = (200, 200, 200)
    pygame.draw.rect(box, frame_color, (2, 2, size - 4, size - 4), 1)

    surface.blit(box, (x, y))

    # 라벨
    label = font.render("Outer Frame", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 10)
    surface.blit(label, label_rect)

    # 설명
    desc = font.render("(Static Silver Frame)", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 35)
    surface.blit(desc, desc_rect)

def draw_legendary_border_demo(surface, x, y, size, anim_time):
    """Legendary Border (빨간색 펄싱 애니메이션) 시연"""
    # 배경 박스
    box = pygame.Surface((size, size), pygame.SRCALPHA)
    box.fill((50, 50, 80, 200))

    # Pulsing red border effect (펄싱 레드 보더)
    border_color = (
        int(255 * (0.5 + 0.5 * math.sin(anim_time * 3))),
        0,
        0
    )
    pygame.draw.rect(box, border_color, (0, 0, size, size), 3)

    surface.blit(box, (x, y))

    # 라벨
    label = font.render("Legendary Border", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 10)
    surface.blit(label, label_rect)

    # 설명
    desc = font.render("(Pulsing Red Animation)", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 35)
    surface.blit(desc, desc_rect)

    # 현재 색상 값 표시
    color_text = font.render(f"Red: {border_color[0]}", True, (255, 100, 100))
    color_rect = color_text.get_rect(centerx=x + size//2, top=y + size + 60)
    surface.blit(color_text, color_rect)

def draw_combined_demo(surface, x, y, size, anim_time):
    """두 효과를 함께 적용한 모습"""
    # 배경 박스
    box = pygame.Surface((size, size), pygame.SRCALPHA)
    box.fill((50, 50, 80, 200))

    # 1. Legendary Border (빨간색 펄싱 - 바깥쪽)
    border_color = (
        int(255 * (0.5 + 0.5 * math.sin(anim_time * 3))),
        0,
        0
    )
    pygame.draw.rect(box, border_color, (0, 0, size, size), 3)

    # 2. Outer Frame (은색 정적 - 안쪽)
    frame_color = (200, 200, 200)
    pygame.draw.rect(box, frame_color, (5, 5, size - 10, size - 10), 1)

    # 아이템 아이콘 대체 (예시)
    icon_rect = pygame.Rect(15, 15, size - 30, size - 30)
    pygame.draw.rect(box, (100, 150, 200), icon_rect)
    pygame.draw.rect(box, (150, 200, 250), icon_rect, 2)

    surface.blit(box, (x, y))

    # 라벨
    label = font.render("Combined Effect", True, WHITE)
    label_rect = label.get_rect(centerx=x + size//2, top=y + size + 10)
    surface.blit(label, label_rect)

    # 설명
    desc = font.render("(Both Borders Together)", True, (150, 150, 150))
    desc_rect = desc.get_rect(centerx=x + size//2, top=y + size + 35)
    surface.blit(desc, desc_rect)

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
    title = title_font.render("Legendary Item Border Effects", True, WHITE)
    title_rect = title.get_rect(centerx=400, top=20)
    screen.blit(title, title_rect)

    # 각 테두리 효과 표시
    icon_size = 100
    y_pos = 100

    # 1. Outer Frame (은색 정적)
    draw_outer_frame_demo(screen, 100, y_pos, icon_size)

    # 2. Legendary Border (빨간색 펄싱)
    draw_legendary_border_demo(screen, 350, y_pos, icon_size, animation_time)

    # 3. Combined (둘 다 적용)
    draw_combined_demo(screen, 600, y_pos, icon_size, animation_time)

    # 안내 텍스트
    info = font.render("Press ESC to exit", True, (100, 100, 100))
    info_rect = info.get_rect(centerx=400, bottom=390)
    screen.blit(info, info_rect)

    # 시간 표시
    time_text = font.render(f"Animation Time: {animation_time:.2f}s", True, (150, 150, 150))
    time_rect = time_text.get_rect(left=10, bottom=390)
    screen.blit(time_text, time_rect)

    pygame.display.flip()

pygame.quit()
sys.exit()