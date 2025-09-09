"""
헤르메스의 신발 (탈라리아) - 그리스 신화 스타일
전설 아이템 기본 테두리 + 고대 그리스 샌들 디자인
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
    """헤르메스의 탈라리아 - 그리스 신화 스타일"""
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
    
    # ===== 그리스 신화 스타일 샌들 디자인 =====
    
    t = frame_index / FRAMES
    
    # 색상 팔레트 - 고대 그리스 스타일
    SANDAL_GOLD = (218, 165, 32)  # 골드 브론즈
    SANDAL_BRONZE = (184, 134, 11)  # 어두운 골드
    SANDAL_DARK = (139, 90, 0)  # 그림자
    STRAP_GOLD = (255, 215, 0)  # 밝은 금색 끈
    WING_WHITE = (255, 255, 255)  # 순백색 깃털
    WING_PEARL = (245, 245, 220)  # 진주색
    WING_SILVER = (192, 192, 192)  # 은색
    DIVINE_GLOW = (255, 255, 200)  # 신성한 빛
    
    # 애니메이션
    wing_flap = math.sin(t * math.pi * 4) * 3
    hover = int(math.sin(t * math.pi * 2) * 1.5)
    glow_pulse = abs(math.sin(t * math.pi * 2))
    
    # 샌들 본체 (측면 뷰)
    sandal_x = 8
    sandal_y = 16 + hover
    
    # 샌들 밑창 (곡선형)
    # 앞쪽 (둥근 발가락 부분)
    for x in range(sandal_x, sandal_x + 3):
        for y in range(sandal_y + 3, sandal_y + 6):
            if y == sandal_y + 3 and x == sandal_x:
                continue  # 둥근 모서리
            surface.set_at((x, y), SANDAL_GOLD)
    
    # 중간 부분 (아치형)
    for x in range(sandal_x + 3, sandal_x + 10):
        for y in range(sandal_y + 2, sandal_y + 5):
            if y == sandal_y + 2:
                surface.set_at((x, y), SANDAL_BRONZE)
            else:
                surface.set_at((x, y), SANDAL_GOLD)
    
    # 뒤꿈치 부분
    for x in range(sandal_x + 10, sandal_x + 13):
        for y in range(sandal_y + 1, sandal_y + 4):
            surface.set_at((x, y), SANDAL_GOLD)
    
    # 샌들 가장자리 장식 (그리스 패턴)
    for x in range(sandal_x + 1, sandal_x + 12, 2):
        surface.set_at((x, sandal_y + 4), SANDAL_BRONZE)
    
    # 십자 교차 끈 (그리스 샌들 특징)
    # 발등 끈
    for i in range(5):
        x = sandal_x + 2 + i * 2
        y = sandal_y - i
        if 3 < x < 29 and 3 < y < 29:
            surface.set_at((x, y), STRAP_GOLD)
            surface.set_at((x, y-1), STRAP_GOLD)
    
    # 교차 끈 1
    pygame.draw.line(surface, STRAP_GOLD,
                    (sandal_x + 3, sandal_y),
                    (sandal_x + 8, sandal_y - 3), 1)
    
    # 교차 끈 2
    pygame.draw.line(surface, STRAP_GOLD,
                    (sandal_x + 8, sandal_y),
                    (sandal_x + 3, sandal_y - 3), 1)
    
    # 발목 끈 (나선형)
    for i in range(3):
        y = sandal_y - 1 - i
        x = sandal_x + 10 + (i % 2)
        if 3 < x < 29 and 3 < y < 29:
            surface.set_at((x, y), STRAP_GOLD)
            surface.set_at((x+1, y), STRAP_GOLD)
    
    # 신성한 날개 (더 크고 화려하게)
    wing_x = sandal_x + 12
    wing_y = sandal_y
    
    # 큰 날개 (여러 층의 깃털)
    for layer in range(4):
        feather_angle = -20 + layer * 15 + wing_flap
        feather_length = 7 - layer
        
        for i in range(feather_length):
            angle_rad = math.radians(feather_angle)
            x = int(wing_x + i * math.cos(angle_rad))
            y = int(wing_y - i * math.sin(angle_rad) - layer)
            
            if 3 < x < 29 and 3 < y < 29:
                if layer == 0:
                    surface.set_at((x, y), WING_WHITE)
                    surface.set_at((x, y-1), WING_PEARL)
                elif layer == 1:
                    surface.set_at((x, y), WING_PEARL)
                elif layer == 2:
                    surface.set_at((x, y), WING_SILVER)
                else:
                    # 깃털 디테일
                    if i % 2 == 0:
                        surface.set_at((x, y), WING_WHITE)
    
    # 작은 날개 (반대편)
    for layer in range(3):
        feather_angle = 160 - layer * 15 - wing_flap
        feather_length = 5 - layer
        
        for i in range(feather_length):
            angle_rad = math.radians(feather_angle)
            x = int(sandal_x + i * math.cos(angle_rad))
            y = int(wing_y - i * math.sin(angle_rad) - layer)
            
            if 3 < x < 29 and 3 < y < 29:
                if layer == 0:
                    surface.set_at((x, y), WING_WHITE)
                else:
                    surface.set_at((x, y), WING_PEARL)
    
    # 신성한 광채 효과
    if frame_index % 2 == 0:
        # 샌들 주변 금빛 광채
        glow_intensity = int(100 * glow_pulse)
        for dx in [-1, 0, 1]:
            for dy in [-1, 0, 1]:
                glow_x = sandal_x + 6 + dx * 2
                glow_y = sandal_y + 2 + dy * 2
                if 3 < glow_x < 29 and 3 < glow_y < 29:
                    current = surface.get_at((glow_x, glow_y))
                    new_color = (
                        min(255, current[0] + glow_intensity),
                        min(255, current[1] + glow_intensity),
                        min(255, current[2]),
                        255
                    )
                    surface.set_at((glow_x, glow_y), new_color)
    
    # 별빛 효과 (신들의 축복)
    if frame_index in [0, 3, 6]:
        star_positions = [
            (wing_x + 3, wing_y - 4),
            (sandal_x + 5, sandal_y - 5),
            (wing_x - 2, wing_y - 6)
        ]
        for sx, sy in star_positions:
            if 3 < sx < 29 and 3 < sy < 29:
                # 십자 별
                surface.set_at((sx, sy), DIVINE_GLOW)
                surface.set_at((sx+1, sy), (255, 255, 150))
                surface.set_at((sx-1, sy), (255, 255, 150))
                surface.set_at((sx, sy+1), (255, 255, 150))
                surface.set_at((sx, sy-1), (255, 255, 150))
    
    # 바람 효과 (속도의 신)
    if frame_index in [1, 2, 5, 6]:
        for i in range(3):
            wind_x = sandal_x - 2 - i * 2
            wind_y = sandal_y + 2
            alpha = 80 - i * 20
            
            if 3 < wind_x < 29 and 3 < wind_y < 29:
                pygame.draw.line(surface, (150, 200, 255, alpha),
                               (wind_x, wind_y),
                               (wind_x - 3, wind_y), 1)
    
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
    pygame.display.set_caption("탈라리아 - 헤르메스의 날개 달린 샌들")
    
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
        title_text = font.render("TALARIA - Hermes' Winged Sandals", True, (255, 215, 0))
        screen.blit(title_text, (250, 80))
        
        desc_text = small_font.render("Mythical Greek Sandals", True, (200, 200, 200))
        screen.blit(desc_text, (250, 110))
        
        features = [
            "- Golden bronze sandal",
            "- Cross-strap design",
            "- Pearl white wings",
            "- Divine glow effect",
            "- Star blessings",
            "- Wind trails"
        ]
        
        for i, feature in enumerate(features):
            text = small_font.render(feature, True, (150, 150, 150))
            screen.blit(text, (250, 140 + i * 20))
        
        frame_text = small_font.render(f"Frame: {frame_index + 1}/{FRAMES}", True, (150, 150, 150))
        screen.blit(frame_text, (100, 250))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    print("\n✅ 탈라리아 - 헤르메스의 날개 달린 샌들 완성!")
    print("🏛️ 고대 그리스 신화의 전설적인 신발!")

if __name__ == "__main__":
    create_demo_animation()