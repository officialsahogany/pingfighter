#!/usr/bin/env python3
"""헤르메스의 신발 아이콘 생성기 - 라그나로크 해머 스타일 완벽 복사"""

import pygame
import math
import os

# Pygame 초기화
pygame.init()

# 아이콘 크기 (32x32) - 라그나로크 해머와 동일
ICON_SIZE = 32
FRAMES = 8  # 애니메이션 프레임 수

# 색상 정의 - 라그나로크 해머와 정확히 동일
LEGENDARY_RED = (255, 50, 50)
SHOE_GOLD = (255, 215, 0)  # 황금색 신발
SHOE_DARK_GOLD = (200, 170, 0)  # 어두운 황금색
SHOE_HIGHLIGHT = (255, 255, 150)  # 하이라이트
WING_WHITE = (255, 255, 255)  # 흰색 날개
WING_LIGHT = (240, 240, 255)  # 밝은 날개
WING_SHADOW = (200, 200, 220)  # 날개 그림자
LIGHTNING_YELLOW = (255, 255, 150)
LIGHTNING_WHITE = (255, 255, 255)
IMPACT_GLOW = (255, 200, 100)

def create_hermes_frame(frame_index):
    """헤르메스 신발 프레임 생성 - 라그나로크 해머와 동일한 구조"""
    surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
    
    # 애니메이션 타이밍
    t = frame_index / FRAMES
    
    # 1. 파란색 원형 배경 (라그나로크 해머와 동일) - 중요!
    center_x, center_y = ICON_SIZE // 2, ICON_SIZE // 2
    # 여러 겹의 원으로 그라데이션 효과
    for i in range(3):
        radius = ICON_SIZE // 2 - i
        alpha = 200 - i * 50  # 바깥쪽이 더 진함
        color = (50 + i * 20, 70 + i * 20, 100 + i * 30, alpha)  # 점점 밝은 파란색
        pygame.draw.circle(surface, color, (center_x, center_y), radius)
    
    # 2. 빨간 테두리 (전설 티어) - 라그나로크 해머와 정확히 동일
    border_thickness = 2
    # 프레임마다 색상 변화 (중요!)
    border_colors = [
        (255, 50, 50),    # Frame 0: 기본 빨강
        (255, 80, 80),    # Frame 1: 밝은 빨강
        (255, 40, 40),    # Frame 2: 어두운 빨강
        (255, 100, 100),  # Frame 3: 더 밝은 빨강
        (255, 30, 30),    # Frame 4: 더 어두운 빨강
        (255, 60, 60),    # Frame 5: 중간 빨강
        (255, 90, 90),    # Frame 6: 밝은 빨강
        (255, 70, 70),    # Frame 7: 약간 밝은 빨강
    ]
    current_border_color = border_colors[frame_index % len(border_colors)]
    
    # 글로우 효과를 위한 여러 겹의 테두리
    border_glow = int(128 + 127 * math.sin(t * math.pi * 2))  # 펄싱 효과
    for i in range(2):
        alpha = border_glow // (i + 1)
        thickness = border_thickness - i
        if thickness > 0:
            pygame.draw.rect(surface, (*current_border_color, alpha), 
                           (i, i, ICON_SIZE - i*2, ICON_SIZE - i*2), thickness)
    
    # 메인 빨간 테두리
    pygame.draw.rect(surface, current_border_color, 
                   (0, 0, ICON_SIZE, ICON_SIZE), border_thickness)
    
    # 3. 꼭지점 디테일 (은색 코너) - 라그나로크 해머의 중요한 특징!
    corner_size = 6
    corner_color = (200, 200, 200)  # 은색
    
    # 왼쪽 위 코너
    pygame.draw.lines(surface, corner_color, False, 
                     [(0, corner_size), (0, 0), (corner_size, 0)], 2)
    # 오른쪽 위 코너
    pygame.draw.lines(surface, corner_color, False,
                     [(ICON_SIZE - corner_size, 0), (ICON_SIZE - 1, 0), (ICON_SIZE - 1, corner_size)], 2)
    # 왼쪽 아래 코너
    pygame.draw.lines(surface, corner_color, False,
                     [(0, ICON_SIZE - corner_size), (0, ICON_SIZE - 1), (corner_size, ICON_SIZE - 1)], 2)
    # 오른쪽 아래 코너
    pygame.draw.lines(surface, corner_color, False,
                     [(ICON_SIZE - corner_size, ICON_SIZE - 1), (ICON_SIZE - 1, ICON_SIZE - 1), (ICON_SIZE - 1, ICON_SIZE - corner_size)], 2)
    
    # 코너 점 장식 (더 화려하게)
    for cx, cy in [(0, 0), (ICON_SIZE - 1, 0), (0, ICON_SIZE - 1), (ICON_SIZE - 1, ICON_SIZE - 1)]:
        pygame.draw.circle(surface, current_border_color, (cx, cy), 3)
        pygame.draw.circle(surface, corner_color, (cx, cy), 2)
    
    # 애니메이션 오프셋
    shoe_y_offset = int(math.sin(t * math.pi * 2) * 2)  # 위아래 움직임
    
    # 4. 번개 효과 (특정 프레임에만)
    if frame_index in [2, 3, 6, 7]:
        # 작은 번개 볼트 (날개처럼)
        for i in range(2):
            start_x = 8 + i * 16
            start_y = 5
            segments = 3
            prev_x, prev_y = start_x, start_y
            
            for seg in range(segments):
                next_x = prev_x + (4 if i == 0 else -4)
                next_y = prev_y + 5
                
                # 지그재그 효과
                if seg % 2 == 0:
                    next_x += 2
                else:
                    next_x -= 2
                    
                pygame.draw.line(surface, LIGHTNING_YELLOW, 
                               (prev_x, prev_y), (next_x, next_y), 1)
                prev_x, prev_y = next_x, next_y
    
    # 5. 신발 그리기 (가운데 위치)
    shoe_x = 10
    shoe_y = 14 + shoe_y_offset
    shoe_width = 12
    shoe_height = 6
    
    # 신발 그림자
    pygame.draw.ellipse(surface, SHOE_DARK_GOLD, 
                       (shoe_x, shoe_y + 1, shoe_width, shoe_height))
    
    # 메인 신발
    pygame.draw.ellipse(surface, SHOE_GOLD, 
                       (shoe_x, shoe_y, shoe_width, shoe_height))
    
    # 신발 하이라이트
    pygame.draw.ellipse(surface, SHOE_HIGHLIGHT, 
                       (shoe_x + 2, shoe_y + 1, shoe_width - 4, 2), 1)
    
    # 신발 앞코
    pygame.draw.ellipse(surface, SHOE_GOLD, 
                       (shoe_x + shoe_width - 3, shoe_y + 1, 5, 4))
    
    # 6. 날개 그리기 (애니메이션)
    wing_flap = math.sin(t * math.pi * 4) * 2  # 날개 펄럭임
    
    # 왼쪽 날개
    left_wing = [
        (shoe_x - 1 + int(wing_flap), shoe_y + 2),
        (shoe_x - 4 + int(wing_flap * 1.5), shoe_y),
        (shoe_x - 5 + int(wing_flap * 1.5), shoe_y + 3),
        (shoe_x - 3 + int(wing_flap), shoe_y + 5),
        (shoe_x, shoe_y + 3)
    ]
    pygame.draw.polygon(surface, WING_WHITE, left_wing)
    pygame.draw.polygon(surface, WING_SHADOW, left_wing, 1)
    
    # 오른쪽 날개
    right_wing = [
        (shoe_x + shoe_width + 1 - int(wing_flap), shoe_y + 2),
        (shoe_x + shoe_width + 4 - int(wing_flap * 1.5), shoe_y),
        (shoe_x + shoe_width + 5 - int(wing_flap * 1.5), shoe_y + 3),
        (shoe_x + shoe_width + 3 - int(wing_flap), shoe_y + 5),
        (shoe_x + shoe_width, shoe_y + 3)
    ]
    pygame.draw.polygon(surface, WING_WHITE, right_wing)
    pygame.draw.polygon(surface, WING_SHADOW, right_wing, 1)
    
    # 7. 충격파 효과 (특정 프레임)
    if frame_index in [0, 4]:
        # 충격파 원
        impact_radius = 6 + (frame_index // 4) * 2
        impact_alpha = 100 - (frame_index // 4) * 30
        
        for i in range(2):
            radius = impact_radius - i * 2
            if radius > 0:
                color = (*IMPACT_GLOW, impact_alpha // (i + 1))
                # 충격파를 픽셀 단위로 그리기
                for angle in range(0, 360, 30):
                    x = center_x + int(radius * math.cos(math.radians(angle)))
                    y = center_y + int(radius * math.sin(math.radians(angle)))
                    if 0 <= x < ICON_SIZE and 0 <= y < ICON_SIZE:
                        surface.set_at((x, y), color)
    
    # 8. 파워 글로우 (신발 주변)
    if frame_index % 2 == 0:
        # 신발 주변에 붉은 광채
        glow_alpha = 40 + int(20 * math.sin(t * math.pi * 2))
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                if dx != 0 or dy != 0:
                    glow_x = shoe_x + shoe_width // 2 + dx * 3
                    glow_y = shoe_y + shoe_height // 2 + dy * 3
                    if 0 <= glow_x < ICON_SIZE and 0 <= glow_y < ICON_SIZE:
                        surface.set_at((glow_x, glow_y), (*LEGENDARY_RED, glow_alpha))
    
    # 9. 반짝임 효과
    if frame_index in [1, 5]:
        # 작은 별 효과
        star_color = (255, 255, 200, 150)
        # 신발 위에 작은 별
        pygame.draw.line(surface, star_color, 
                       (shoe_x + shoe_width // 2 - 2, shoe_y - 2), 
                       (shoe_x + shoe_width // 2 + 2, shoe_y - 2), 1)
        pygame.draw.line(surface, star_color, 
                       (shoe_x + shoe_width // 2, shoe_y - 4), 
                       (shoe_x + shoe_width // 2, shoe_y), 1)
    
    return surface

# 디렉토리 생성
output_dir = "items/legendary"
os.makedirs(output_dir, exist_ok=True)

# 프레임 생성
for i in range(FRAMES):
    frame = create_hermes_frame(i)
    output_path = os.path.join(output_dir, f"hermes_shoes_frame_{i}.png")
    pygame.image.save(frame, output_path)
    print(f"Saved: {output_path}")

# 메인 아이콘과 프리뷰 저장
frame_0 = pygame.image.load(os.path.join(output_dir, "hermes_shoes_frame_0.png"))
pygame.image.save(frame_0, os.path.join(output_dir, "hermes_shoes.png"))
pygame.image.save(frame_0, os.path.join(output_dir, "hermes_shoes_preview.png"))

print(f"\n✅ Successfully generated {FRAMES} frames for Hermes Shoes!")
print(f"Files saved in: {output_dir}/")
print("Files created:")
print("  - hermes_shoes.png (main icon)")
print("  - hermes_shoes_preview.png")
print(f"  - hermes_shoes_frame_0.png to hermes_shoes_frame_{FRAMES-1}.png")