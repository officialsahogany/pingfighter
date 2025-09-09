"""
헤르메스의 신발 - 더 명확한 신발 디자인
전설 아이템 기본 테두리 + 개선된 신발 모양
"""

import pygame
import math
import os

pygame.init()

ICON_SIZE = 32
FRAMES = 8

# 전설 아이템 필수 색상 (변경 금지!)
CORNER_COLORS = [
    [(246, 246, 255), (145, 145, 255)],  # Frame 0
    [(229, 229, 255), (208, 208, 255)],  # Frame 1
    [(153, 153, 255), (254, 254, 255)],  # Frame 2
    [(170, 170, 255), (191, 191, 255)],  # Frame 3
    [(246, 246, 255), (145, 145, 255)],  # Frame 4
    [(229, 229, 255), (208, 208, 255)],  # Frame 5
    [(153, 153, 255), (254, 254, 255)],  # Frame 6
    [(170, 170, 255), (191, 191, 255)],  # Frame 7
]

# 테두리 색상 (프레임별로 변화)
BORDER_COLORS = [
    (150, 0, 0),    # Frame 0, 4
    (224, 0, 0),    # Frame 1, 3
    (255, 0, 0),    # Frame 2
    (224, 0, 0),    # Frame 3 (duplicate)
    (150, 0, 0),    # Frame 4 (duplicate)
    (75, 0, 0),     # Frame 5, 7
    (45, 0, 0),     # Frame 6
    (75, 0, 0),     # Frame 7 (duplicate)
]

def create_hermes_frame(frame_index):
    """헤르메스 신발 프레임 - 더 명확한 신발 디자인"""
    surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
    
    # 1. 파란색 원형 배경 (전설 아이템 필수)
    center = ICON_SIZE // 2
    radius = 13
    
    for r in range(radius, 0, -1):
        alpha = 255 - (radius - r) * 10
        blue_intensity = 100 + (radius - r) * 10
        color = (100, 150, min(255, blue_intensity), alpha)
        pygame.draw.circle(surface, color, (center, center), r)
    
    # 2. 은색/보라색 모서리 장식 (3x3 영역)
    left_corner, right_corner = CORNER_COLORS[frame_index]
    
    # 왼쪽 위 모서리
    for y in range(3):
        for x in range(3):
            surface.set_at((x, y), (*left_corner, 255))
    
    # 오른쪽 위 모서리
    for y in range(3):
        for x in range(29, 32):
            surface.set_at((x, y), (*right_corner, 255))
    
    # 왼쪽 아래 모서리
    for y in range(29, 32):
        for x in range(3):
            surface.set_at((x, y), (*left_corner, 255))
    
    # 오른쪽 아래 모서리
    for y in range(29, 32):
        for x in range(29, 32):
            if x == 31 and y == 31:
                surface.set_at((x, y), (*BORDER_COLORS[frame_index], 255))
            else:
                surface.set_at((x, y), (*right_corner, 255))
    
    # 3. 빨간 테두리 (프레임별로 색상 변화)
    border_color = BORDER_COLORS[frame_index]
    
    # 상단 테두리
    for x in range(3, 29):
        surface.set_at((x, 0), (*border_color, 255))
        surface.set_at((x, 1), (*border_color, 255))
    
    # 하단 테두리
    for x in range(3, 29):
        surface.set_at((x, 30), (*border_color, 255))
        surface.set_at((x, 31), (*border_color, 255))
    
    # 왼쪽 테두리
    for y in range(3, 29):
        surface.set_at((0, y), (*border_color, 255))
        surface.set_at((1, y), (*border_color, 255))
    
    # 오른쪽 테두리
    for y in range(3, 29):
        surface.set_at((30, y), (*border_color, 255))
        surface.set_at((31, y), (*border_color, 255))
    
    # ===== 개선된 신발 디자인 =====
    
    t = frame_index / FRAMES
    
    # 신발 색상
    SHOE_BROWN = (101, 67, 33)  # 갈색
    SHOE_DARK = (71, 47, 23)  # 어두운 갈색
    SHOE_SOLE = (51, 34, 17)  # 밑창 색상
    LACE_COLOR = (255, 255, 255)  # 흰색 끈
    WING_WHITE = (255, 255, 255)
    WING_GOLD = (255, 215, 0)  # 황금색 날개
    WING_SHADOW = (200, 170, 0)
    
    # 애니메이션
    wing_flap = math.sin(t * math.pi * 4) * 2
    hover = int(math.sin(t * math.pi * 2) * 1)
    
    # 측면 신발 디자인 (더 크고 명확하게)
    shoe_x = 9
    shoe_y = 15 + hover
    
    # 신발 몸체 (측면 모양)
    # 신발 윗부분
    for x in range(shoe_x, shoe_x + 14):
        for y in range(shoe_y, shoe_y + 6):
            # 신발 모양 만들기
            if x < shoe_x + 2:  # 발가락 부분
                if y >= shoe_y + 2:
                    surface.set_at((x, y), SHOE_BROWN)
            elif x < shoe_x + 10:  # 중간 부분
                surface.set_at((x, y), SHOE_BROWN)
            else:  # 발목 부분
                if y <= shoe_y + 4:
                    surface.set_at((x, y), SHOE_BROWN)
    
    # 신발 밑창 (더 두껍게)
    for x in range(shoe_x, shoe_x + 12):
        surface.set_at((x, shoe_y + 6), SHOE_SOLE)
        surface.set_at((x, shoe_y + 7), SHOE_SOLE)
    
    # 신발 끈 구멍과 끈
    for i in range(3):
        hole_x = shoe_x + 3 + i * 3
        hole_y = shoe_y + 1
        
        # 끈 구멍
        surface.set_at((hole_x, hole_y), (50, 50, 50))
        
        # X자 끈 패턴
        if i < 2:
            # 대각선 끈
            pygame.draw.line(surface, LACE_COLOR,
                           (hole_x, hole_y),
                           (hole_x + 3, hole_y + 2), 1)
            pygame.draw.line(surface, LACE_COLOR,
                           (hole_x + 3, hole_y),
                           (hole_x, hole_y + 2), 1)
    
    # 신발 디테일 - 스티치
    for x in range(shoe_x + 2, shoe_x + 10, 2):
        surface.set_at((x, shoe_y + 4), SHOE_DARK)
    
    # 신발 하이라이트
    for x in range(shoe_x + 2, shoe_x + 8):
        surface.set_at((x, shoe_y), (120, 80, 40))
    
    # 날개 (더 크고 화려하게)
    wing_base_x = shoe_x + 11
    wing_base_y = shoe_y + 2
    
    # 큰 날개 (3겹)
    for layer in range(3):
        wing_y_offset = layer * 2 - 3 + int(wing_flap)
        wing_length = 6 - layer
        
        # 날개 깃털
        for i in range(wing_length):
            x = wing_base_x + i
            y = wing_base_y + wing_y_offset
            
            if 3 < x < 29 and 3 < y < 29:
                if layer == 0:  # 가장 위 날개
                    surface.set_at((x, y), WING_WHITE)
                    surface.set_at((x, y-1), WING_GOLD)
                elif layer == 1:  # 중간 날개
                    surface.set_at((x, y), WING_GOLD)
                else:  # 아래 날개
                    surface.set_at((x, y), WING_SHADOW)
    
    # 작은 날개 (반대편)
    for layer in range(2):
        wing_y_offset = layer * 2 - 2 - int(wing_flap)
        wing_length = 3 - layer
        
        for i in range(wing_length):
            x = shoe_x - 1 - i
            y = wing_base_y + wing_y_offset
            
            if 3 < x < 29 and 3 < y < 29:
                if layer == 0:
                    surface.set_at((x, y), WING_WHITE)
                else:
                    surface.set_at((x, y), WING_GOLD)
    
    # 속도 효과 (특정 프레임)
    if frame_index in [1, 2, 5, 6]:
        # 잔상 효과
        TRAIL_COLOR = (150, 200, 255)
        for i in range(4):
            trail_x = shoe_x - 2 - i * 2
            trail_y = shoe_y + 3
            alpha = 100 - i * 25
            
            if 3 < trail_x < 29 and 3 < trail_y < 29:
                current = surface.get_at((trail_x, trail_y))
                new_color = (
                    min(255, current[0] + TRAIL_COLOR[0] * alpha // 500),
                    min(255, current[1] + TRAIL_COLOR[1] * alpha // 500),
                    min(255, current[2] + TRAIL_COLOR[2] * alpha // 500),
                    255
                )
                surface.set_at((trail_x, trail_y), new_color)
    
    # 반짝임 효과 (날개)
    if frame_index % 3 == 0:
        sparkle_x = wing_base_x + 2
        sparkle_y = wing_base_y - 2
        if 3 < sparkle_x < 29 and 3 < sparkle_y < 29:
            surface.set_at((sparkle_x, sparkle_y), (255, 255, 200))
            surface.set_at((sparkle_x+1, sparkle_y), (255, 255, 150))
            surface.set_at((sparkle_x, sparkle_y+1), (255, 255, 150))
    
    return surface

def save_animated_icon():
    """애니메이션 아이콘 저장"""
    os.makedirs("items/legendary", exist_ok=True)
    
    frames = []
    for i in range(FRAMES):
        frame = create_hermes_frame(i)
        frames.append(frame)
        
        filename = f"items/legendary/hermes_shoes_frame_{i}.png"
        pygame.image.save(frame, filename)
        print(f"프레임 {i} 저장: {filename}")
    
    pygame.image.save(frames[0], "items/legendary/hermes_shoes.png")
    print("\n기본 아이콘 저장: items/legendary/hermes_shoes.png")
    
    # 미리보기
    preview_width = ICON_SIZE * FRAMES
    preview = pygame.Surface((preview_width, ICON_SIZE), pygame.SRCALPHA)
    
    for i, frame in enumerate(frames):
        preview.blit(frame, (i * ICON_SIZE, 0))
    
    pygame.image.save(preview, "items/legendary/hermes_shoes_preview.png")
    print("미리보기 저장: items/legendary/hermes_shoes_preview.png")
    
    return frames

def create_demo_animation():
    """데모 창"""
    screen = pygame.display.set_mode((600, 300))
    pygame.display.set_caption("헤르메스의 신발 - 개선된 디자인")
    
    clock = pygame.time.Clock()
    frames = save_animated_icon()
    
    frame_index = 0
    frame_counter = 0
    animation_speed = 8
    
    font = pygame.font.Font(None, 24)
    small_font = pygame.font.Font(None, 18)
    
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
        
        screen.fill((30, 30, 40))
        
        frame_counter += 1
        if frame_counter >= animation_speed:
            frame_counter = 0
            frame_index = (frame_index + 1) % FRAMES
        
        # 큰 버전 (4x 확대)
        big_icon = pygame.transform.scale(frames[frame_index], (128, 128))
        screen.blit(big_icon, (100, 80))
        
        # 원본 크기
        screen.blit(frames[frame_index], (150, 220))
        
        # 설명
        title_text = font.render("HERMES SHOES", True, (255, 100, 100))
        screen.blit(title_text, (250, 100))
        
        desc_text = small_font.render("Legendary Speed Item", True, (200, 200, 200))
        screen.blit(desc_text, (250, 130))
        
        features = [
            "- Clear shoe shape",
            "- Golden wings",
            "- Speed trails",
            "- Detailed laces"
        ]
        
        for i, feature in enumerate(features):
            text = small_font.render(feature, True, (150, 150, 150))
            screen.blit(text, (250, 160 + i * 20))
        
        frame_text = small_font.render(f"Frame: {frame_index + 1}/{FRAMES}", True, (150, 150, 150))
        screen.blit(frame_text, (100, 250))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    print("\n✅ 개선된 헤르메스의 신발 완성!")

if __name__ == "__main__":
    create_demo_animation()