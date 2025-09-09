"""
헤르메스의 날개 부츠 - 참고 이미지 스타일
전설 아이템 기본 테두리 + 갈색 부츠와 은색 날개
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
    """헤르메스 날개 부츠 - 참고 이미지 스타일"""
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
    
    # ===== 날개 달린 부츠 디자인 =====
    
    t = frame_index / FRAMES
    
    # 색상 팔레트 (참고 이미지 기반)
    BOOT_BROWN = (139, 69, 19)  # 짙은 갈색
    BOOT_LIGHT = (160, 82, 45)  # 밝은 갈색
    BOOT_DARK = (101, 67, 33)  # 어두운 갈색
    BOOT_BLACK = (20, 20, 20)  # 검은색 밑창
    BUCKLE_GOLD = (218, 165, 32)  # 금색 버클
    WING_SILVER = (192, 192, 192)  # 은색 날개
    WING_LIGHT = (220, 220, 220)  # 밝은 은색
    WING_DARK = (160, 160, 160)  # 어두운 은색
    WING_BLUE = (173, 216, 230)  # 하늘색 하이라이트
    
    # 애니메이션
    wing_flap = math.sin(t * math.pi * 4) * 2
    hover = int(math.sin(t * math.pi * 2) * 1)
    
    # 부츠 본체 (정면/측면 혼합 뷰)
    boot_x = 10
    boot_y = 13 + hover
    
    # 부츠 상단 (다리 부분)
    for x in range(boot_x, boot_x + 6):
        for y in range(boot_y, boot_y + 8):
            if y < boot_y + 2:  # 상단
                surface.set_at((x, y), BOOT_BROWN)
            elif y < boot_y + 6:  # 중간
                if x == boot_x or x == boot_x + 5:
                    surface.set_at((x, y), BOOT_DARK)
                else:
                    surface.set_at((x, y), BOOT_BROWN)
            else:  # 하단
                surface.set_at((x, y), BOOT_LIGHT)
    
    # 부츠 발 부분
    for x in range(boot_x - 2, boot_x + 7):
        for y in range(boot_y + 8, boot_y + 11):
            if x < boot_x:  # 발끝
                if y == boot_y + 10:
                    surface.set_at((x, y), BOOT_BLACK)
                else:
                    surface.set_at((x, y), BOOT_DARK)
            else:  # 발 몸통
                if y == boot_y + 10:
                    surface.set_at((x, y), BOOT_BLACK)
                else:
                    surface.set_at((x, y), BOOT_BROWN)
    
    # 버클 디테일 (금색)
    buckle_y = boot_y + 3
    pygame.draw.rect(surface, BUCKLE_GOLD, (boot_x + 1, buckle_y, 4, 2))
    surface.set_at((boot_x + 2, buckle_y), BOOT_DARK)  # 버클 구멍
    
    # 부츠 끈 (X자 패턴)
    lace_color = BOOT_DARK
    pygame.draw.line(surface, lace_color, 
                    (boot_x + 1, boot_y + 5),
                    (boot_x + 4, boot_y + 7), 1)
    pygame.draw.line(surface, lace_color,
                    (boot_x + 4, boot_y + 5),
                    (boot_x + 1, boot_y + 7), 1)
    
    # 날개 (크고 화려하게 - 참고 이미지 스타일)
    wing_base_x = boot_x + 6
    wing_base_y = boot_y + 4
    
    # 큰 날개 (여러 겹의 깃털)
    for feather in range(5):  # 5개의 깃털
        angle = -30 + feather * 15 + wing_flap * (1 - feather * 0.2)
        length = 8 - feather
        
        for i in range(length):
            # 각도 계산
            rad = math.radians(angle)
            fx = int(wing_base_x + i * math.cos(rad))
            fy = int(wing_base_y - i * math.sin(rad) + feather * 0.5)
            
            if 3 < fx < 29 and 3 < fy < 29:
                # 깃털 그라데이션
                if feather == 0:  # 가장 앞 깃털
                    if i < length // 3:
                        surface.set_at((fx, fy), WING_LIGHT)
                    elif i < length * 2 // 3:
                        surface.set_at((fx, fy), WING_SILVER)
                    else:
                        surface.set_at((fx, fy), WING_BLUE)
                elif feather < 3:  # 중간 깃털
                    surface.set_at((fx, fy), WING_SILVER)
                else:  # 뒤쪽 깃털
                    surface.set_at((fx, fy), WING_DARK)
                
                # 깃털 디테일 (가로선)
                if i % 2 == 0 and feather < 3:
                    if fy - 1 > 3:
                        surface.set_at((fx, fy - 1), WING_LIGHT)
    
    # 날개 윤곽선 강조
    # 상단 곡선
    for i in range(6):
        x = wing_base_x + i
        y = wing_base_y - 3 - (i // 2)
        if 3 < x < 29 and 3 < y < 29:
            surface.set_at((x, y), WING_SILVER)
    
    # 하단 곡선
    for i in range(6):
        x = wing_base_x + i
        y = wing_base_y + 2 + (i // 3)
        if 3 < x < 29 and 3 < y < 29:
            surface.set_at((x, y), WING_DARK)
    
    # 날개 반짝임 효과
    if frame_index % 3 == 0:
        sparkle_x = wing_base_x + 5
        sparkle_y = wing_base_y - 2
        if 3 < sparkle_x < 29 and 3 < sparkle_y < 29:
            # 별 모양 반짝임
            surface.set_at((sparkle_x, sparkle_y), (255, 255, 255))
            for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                sx, sy = sparkle_x + dx, sparkle_y + dy
                if 3 < sx < 29 and 3 < sy < 29:
                    surface.set_at((sx, sy), WING_BLUE)
    
    # 움직임 효과 (스피드 라인)
    if frame_index in [1, 3, 5, 7]:
        for i in range(3):
            trail_y = boot_y + 5 + i * 2
            for j in range(4):
                trail_x = boot_x - 3 - j
                if 3 < trail_x < 29 and 3 < trail_y < 29:
                    alpha = 100 - j * 25
                    current = surface.get_at((trail_x, trail_y))
                    new_color = (
                        min(255, current[0] + 100 * alpha // 255),
                        min(255, current[1] + 150 * alpha // 255),
                        min(255, current[2] + 200 * alpha // 255),
                        255
                    )
                    surface.set_at((trail_x, trail_y), new_color)
    
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
    pygame.display.set_caption("헤르메스의 날개 부츠")
    
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
        title_text = font.render("HERMES WINGED BOOTS", True, (255, 215, 0))
        screen.blit(title_text, (250, 100))
        
        desc_text = small_font.render("Legendary Speed Item", True, (200, 200, 200))
        screen.blit(desc_text, (250, 130))
        
        features = [
            "Design Features:",
            "- Brown leather boots",
            "- Golden buckle detail",
            "- Silver feathered wings",
            "- Speed trail effects",
            "- Animated wing flap"
        ]
        
        for i, feature in enumerate(features):
            text = small_font.render(feature, True, (150, 150, 150))
            screen.blit(text, (250, 160 + i * 20))
        
        frame_text = small_font.render(f"Frame: {frame_index + 1}/{FRAMES}", True, (150, 150, 150))
        screen.blit(frame_text, (100, 250))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    print("\n✅ 헤르메스의 날개 부츠 완성!")
    print("🦅 참고 이미지 스타일로 제작 완료!")

if __name__ == "__main__":
    create_demo_animation()