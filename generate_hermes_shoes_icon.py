#!/usr/bin/env python3
"""헤르메스의 신발 아이콘 생성기 - 라그나로크 해머 스타일 유지"""

import pygame
import math
import os

def resource_path(relative_path):
    """Get absolute path to resource, works for dev and PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    
    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

# Initialize Pygame
pygame.init()

# Constants - 라그나로크 해머와 동일한 설정
ICON_SIZE = 32
FRAMES = 8

# Colors - 라그나로크 해머와 동일한 색상 팔레트
BACKGROUND_BLUE = [(70, 90, 130), (90, 110, 160), (110, 130, 190)]  # 파란색 배경
LEGENDARY_RED = (255, 50, 50)  # 전설 아이템 빨간 테두리
SHOE_GOLD = (255, 215, 0)  # 황금색 신발
SHOE_DARK_GOLD = (200, 170, 0)  # 어두운 황금색
SHOE_HIGHLIGHT = (255, 255, 150)  # 하이라이트
WING_WHITE = (255, 255, 255)  # 흰색 날개
WING_LIGHT = (240, 240, 255)  # 밝은 날개
WING_SHADOW = (200, 200, 220)  # 날개 그림자
LIGHTNING_YELLOW = (255, 255, 150)  # 번개 효과
IMPACT_GLOW = (255, 200, 100)  # 충격 효과

# Create output directory
output_dir = "items/legendary"
os.makedirs(output_dir, exist_ok=True)

# Generate frames
for frame_index in range(FRAMES):
    # Create surface with alpha channel
    surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
    
    # 1. 파란색 원형 배경 (라그나로크 해머와 동일)
    center_x, center_y = ICON_SIZE // 2, ICON_SIZE // 2
    for i in range(3):
        radius = ICON_SIZE // 2 - i
        alpha = 200 - i * 50
        color = (*BACKGROUND_BLUE[i], alpha)
        pygame.draw.circle(surface, color, (center_x, center_y), radius)
    
    # Animation timing
    t = frame_index / FRAMES
    
    # 2. 빨간 테두리 (펄싱 효과) - 라그나로크 해머와 동일
    border_thickness = 2
    border_glow = int(128 + 127 * math.sin(t * math.pi * 2))
    
    # 글로우 효과를 위한 여러 겹의 테두리
    for i in range(2):
        alpha = border_glow // (i + 1)
        thickness = border_thickness - i
        if thickness > 0:
            pygame.draw.rect(surface, (*LEGENDARY_RED, alpha), 
                           (i, i, ICON_SIZE - i*2, ICON_SIZE - i*2), thickness)
    
    # 메인 빨간 테두리
    pygame.draw.rect(surface, LEGENDARY_RED, 
                   (0, 0, ICON_SIZE, ICON_SIZE), border_thickness)
    
    # 3. 날개달린 신발 그리기
    shoe_y_offset = int(math.sin(t * math.pi * 2) * 1.5)  # 위아래 움직임
    
    # 신발 본체 (황금색)
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
    pygame.draw.ellipse(surface, SHOE_DARK_GOLD, 
                       (shoe_x + shoe_width - 3, shoe_y + 1, 5, 4), 1)
    
    # 4. 날개 그리기 (애니메이션)
    wing_flap = math.sin(t * math.pi * 4) * 3  # 날개 펄럭임
    
    # 왼쪽 날개
    left_wing_points = [
        (shoe_x - 2 + int(wing_flap), shoe_y + 2),
        (shoe_x - 6 + int(wing_flap * 1.5), shoe_y),
        (shoe_x - 7 + int(wing_flap * 1.5), shoe_y + 3),
        (shoe_x - 5 + int(wing_flap), shoe_y + 5),
        (shoe_x, shoe_y + 3)
    ]
    pygame.draw.polygon(surface, WING_WHITE, left_wing_points)
    pygame.draw.polygon(surface, WING_SHADOW, left_wing_points, 1)
    
    # 왼쪽 날개 깃털 디테일
    for i in range(2):
        feather_x = shoe_x - 4 + int(wing_flap)
        feather_y = shoe_y + 1 + i * 2
        pygame.draw.line(surface, WING_LIGHT, 
                       (feather_x, feather_y), 
                       (feather_x - 2, feather_y), 1)
    
    # 오른쪽 날개
    right_wing_points = [
        (shoe_x + shoe_width + 2 - int(wing_flap), shoe_y + 2),
        (shoe_x + shoe_width + 6 - int(wing_flap * 1.5), shoe_y),
        (shoe_x + shoe_width + 7 - int(wing_flap * 1.5), shoe_y + 3),
        (shoe_x + shoe_width + 5 - int(wing_flap), shoe_y + 5),
        (shoe_x + shoe_width, shoe_y + 3)
    ]
    pygame.draw.polygon(surface, WING_WHITE, right_wing_points)
    pygame.draw.polygon(surface, WING_SHADOW, right_wing_points, 1)
    
    # 오른쪽 날개 깃털 디테일
    for i in range(2):
        feather_x = shoe_x + shoe_width + 4 - int(wing_flap)
        feather_y = shoe_y + 1 + i * 2
        pygame.draw.line(surface, WING_LIGHT, 
                       (feather_x, feather_y), 
                       (feather_x + 2, feather_y), 1)
    
    # 5. 번개 효과 (특정 프레임에만)
    if frame_index in [0, 2, 4, 6]:
        # 작은 번개 볼트
        for i in range(2):
            start_x = 8 + i * 16
            start_y = 8
            
            # 번개 지그재그
            points = []
            for j in range(3):
                x = start_x + (j * 3 if i == 0 else -j * 3)
                y = start_y + j * 6
                if j == 1:
                    x += 2 if i == 0 else -2
                points.append((x, y))
            
            # 번개 그리기
            for j in range(len(points) - 1):
                pygame.draw.line(surface, LIGHTNING_YELLOW, 
                               points[j], points[j + 1], 1)
    
    # 6. 스피드 라인 효과 (속도감)
    if frame_index % 2 == 1:
        for i in range(3):
            speed_y = 10 + i * 6
            speed_x = 5 - i
            speed_length = 4 + i * 2
            alpha = 100 - i * 30
            pygame.draw.line(surface, (*WING_WHITE, alpha), 
                           (speed_x, speed_y), 
                           (speed_x - speed_length, speed_y), 1)
    
    # 7. 충격파 효과 (특정 프레임)
    if frame_index in [0, 4]:
        impact_radius = 10 + (frame_index // 4) * 2
        impact_alpha = 80 - (frame_index // 4) * 20
        
        # 충격파 원
        pygame.draw.circle(surface, (*IMPACT_GLOW, impact_alpha), 
                         (center_x, center_y + shoe_y_offset), 
                         impact_radius, 1)
    
    # 8. 반짝임 효과
    if frame_index in [1, 3, 5, 7]:
        # 작은 별 효과
        sparkle_points = [
            (shoe_x + shoe_width // 2, shoe_y - 2),
            (shoe_x - 3, shoe_y + 2),
            (shoe_x + shoe_width + 3, shoe_y + 2)
        ]
        for px, py in sparkle_points:
            if 0 <= px < ICON_SIZE and 0 <= py < ICON_SIZE:
                # 십자 별
                pygame.draw.line(surface, SHOE_HIGHLIGHT, 
                               (px - 2, py), (px + 2, py), 1)
                pygame.draw.line(surface, SHOE_HIGHLIGHT, 
                               (px, py - 2), (px, py + 2), 1)
    
    # Save frame
    output_path = os.path.join(output_dir, f"hermes_shoes_frame_{frame_index}.png")
    pygame.image.save(surface, output_path)
    print(f"Saved: {output_path}")

# Also save preview and main icon
# Preview (frame 0)
preview_surface = pygame.image.load(os.path.join(output_dir, "hermes_shoes_frame_0.png"))
pygame.image.save(preview_surface, os.path.join(output_dir, "hermes_shoes_preview.png"))
pygame.image.save(preview_surface, os.path.join(output_dir, "hermes_shoes.png"))

print(f"\n✅ Successfully generated {FRAMES} frames for Hermes Shoes!")
print(f"Files saved in: {output_dir}/")
print("Files created:")
print("  - hermes_shoes.png (main icon)")
print("  - hermes_shoes_preview.png")
print(f"  - hermes_shoes_frame_0.png to hermes_shoes_frame_{FRAMES-1}.png")