"""
헤르메스의 신발 - 실제 라그나로크 해머와 동일한 스타일
파란 원형 배경, 은색 모서리 장식, 변화하는 빨간 테두리
"""

import pygame
import math
import os

pygame.init()

ICON_SIZE = 32
FRAMES = 8

# 실제 라그나로크 해머의 정확한 색상 (분석 결과)
CORNER_COLORS = [
    # Frame 0-7의 모서리 색상 (왼쪽/오른쪽 교대)
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
    """실제 라그나로크 스타일의 헤르메스 신발 프레임"""
    surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
    
    # 1. 파란색 원형 배경 (라그나로크와 동일)
    # 중앙에 파란색 원 그리기
    center = ICON_SIZE // 2
    radius = 13
    
    # 그라데이션 효과를 위한 여러 원
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
            # 맨 구석은 빨간색
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
    
    # 4. 신발 그리기 (중앙에)
    t = frame_index / FRAMES
    
    # 신발 색상
    SHOE_BASE = (139, 69, 19)
    SHOE_DARK = (101, 67, 33)
    SHOE_LIGHT = (160, 82, 45)
    WING_COLOR = (255, 255, 255)
    WING_SHADOW = (200, 200, 200)
    
    # 애니메이션 오프셋
    wing_angle = math.sin(t * math.pi * 2) * 15
    shoe_y_offset = int(math.sin(t * math.pi * 2) * 1)
    
    # 신발 본체
    shoe_x = 10
    shoe_y = 14 + shoe_y_offset
    shoe_width = 12
    shoe_height = 8
    
    # 신발 그림자
    pygame.draw.ellipse(surface, SHOE_DARK,
                       (shoe_x + 1, shoe_y + 1, shoe_width, shoe_height))
    
    # 메인 신발
    pygame.draw.ellipse(surface, SHOE_BASE,
                       (shoe_x, shoe_y, shoe_width, shoe_height))
    
    # 신발 하이라이트
    pygame.draw.ellipse(surface, SHOE_LIGHT,
                       (shoe_x + 2, shoe_y + 1, shoe_width - 4, 3))
    
    # 신발 끈
    lace_y = shoe_y + 2
    for i in range(2):
        pygame.draw.line(surface, (255, 255, 255),
                       (shoe_x + 3 + i*3, lace_y),
                       (shoe_x + 3 + i*3, lace_y + 2), 1)
    
    # 날개 (양쪽)
    wing_base_y = shoe_y + 2
    wing_offset = int(math.sin(t * math.pi * 4) * 2)
    
    # 왼쪽 날개
    left_wing_x = shoe_x - 4
    for i in range(3):
        feather_length = 5 - i
        feather_y = wing_base_y - i * 2 + wing_offset
        
        # 깃털 그림자
        pygame.draw.line(surface, WING_SHADOW,
                       (left_wing_x, feather_y),
                       (left_wing_x - feather_length, feather_y - 1), 1)
        
        # 메인 깃털
        pygame.draw.line(surface, WING_COLOR,
                       (left_wing_x, feather_y),
                       (left_wing_x - feather_length, feather_y - 2), 1)
    
    # 오른쪽 날개
    right_wing_x = shoe_x + shoe_width + 2
    for i in range(3):
        feather_length = 5 - i
        feather_y = wing_base_y - i * 2 - wing_offset
        
        # 깃털 그림자
        pygame.draw.line(surface, WING_SHADOW,
                       (right_wing_x, feather_y),
                       (right_wing_x + feather_length, feather_y - 1), 1)
        
        # 메인 깃털
        pygame.draw.line(surface, WING_COLOR,
                       (right_wing_x, feather_y),
                       (right_wing_x + feather_length, feather_y - 2), 1)
    
    # 속도 효과 (특정 프레임)
    if frame_index in [2, 3, 6, 7]:
        # 속도선
        SPEED_TRAIL = (100, 200, 255)
        for i in range(3):
            trail_y = shoe_y + 2 + i * 2
            trail_length = 6 - i * 2
            trail_alpha = 150 - i * 40
            
            for j in range(trail_length):
                x = shoe_x - 2 - j
                if 3 < x < 29 and 3 < trail_y < 29:
                    current = surface.get_at((x, trail_y))
                    # 기존 색상과 블렌드
                    new_color = (
                        min(255, current[0] + SPEED_TRAIL[0] * trail_alpha // 255 // 2),
                        min(255, current[1] + SPEED_TRAIL[1] * trail_alpha // 255 // 2),
                        min(255, current[2] + SPEED_TRAIL[2] * trail_alpha // 255 // 2),
                        255
                    )
                    surface.set_at((x, trail_y), new_color)
    
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
    screen = pygame.display.set_mode((800, 300))
    pygame.display.set_caption("헤르메스의 신발 vs 라그나로크 해머")
    
    clock = pygame.time.Clock()
    
    # 헤르메스 프레임 생성
    hermes_frames = save_animated_icon()
    
    # 라그나로크 프레임 로드
    ragnarok_frames = []
    for i in range(FRAMES):
        path = f"items/legendary/ragnarok_hammer_frame_{i}.png"
        if os.path.exists(path):
            ragnarok_frames.append(pygame.image.load(path))
        else:
            ragnarok_frames.append(pygame.Surface((32, 32)))
    
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
        
        # 헤르메스 신발 (왼쪽)
        hermes_big = pygame.transform.scale(hermes_frames[frame_index], (128, 128))
        screen.blit(hermes_big, (50, 80))
        screen.blit(hermes_frames[frame_index], (100, 220))
        
        title1 = font.render("HERMES SHOES", True, (255, 100, 100))
        screen.blit(title1, (50, 30))
        
        # 라그나로크 해머 (오른쪽)
        ragnarok_big = pygame.transform.scale(ragnarok_frames[frame_index], (128, 128))
        screen.blit(ragnarok_big, (450, 80))
        screen.blit(ragnarok_frames[frame_index], (500, 220))
        
        title2 = font.render("RAGNAROK HAMMER", True, (255, 100, 100))
        screen.blit(title2, (420, 30))
        
        # 중앙 정보
        vs_text = font.render("VS", True, (255, 255, 255))
        screen.blit(vs_text, (385, 150))
        
        frame_text = small_font.render(f"Frame: {frame_index + 1}/{FRAMES}", True, (150, 150, 150))
        screen.blit(frame_text, (350, 260))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    print("\n✅ 완료! 이제 동일한 스타일입니다!")

if __name__ == "__main__":
    create_demo_animation()