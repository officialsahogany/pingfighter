"""
헤르메스의 신발 - 아이코닉한 디자인
전설 아이템 기본 테두리 + 심플하고 명확한 날개 신발
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
    """헤르메스 신발 - 심플하고 아이코닉한 디자인"""
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
    
    # ===== 심플하고 명확한 신발 디자인 =====
    
    t = frame_index / FRAMES
    
    # 색상 - 대비가 강한 색상 사용
    SHOE_RED = (220, 20, 60)  # 진한 빨강
    SHOE_DARK = (139, 0, 0)  # 어두운 빨강
    SHOE_WHITE = (255, 255, 255)  # 흰색
    WING_GOLD = (255, 215, 0)  # 금색
    WING_YELLOW = (255, 255, 0)  # 밝은 노랑
    WING_ORANGE = (255, 165, 0)  # 주황
    
    # 애니메이션
    wing_flap = abs(math.sin(t * math.pi * 4)) * 3
    
    # 중앙에 큰 신발 (정면 뷰)
    shoe_cx = 16
    shoe_cy = 17
    
    # 신발 몸체 (빨간색 원형)
    pygame.draw.ellipse(surface, SHOE_RED, (shoe_cx - 5, shoe_cy - 3, 10, 7))
    pygame.draw.ellipse(surface, SHOE_DARK, (shoe_cx - 5, shoe_cy - 3, 10, 7), 1)
    
    # 신발 앞코 (둥근 부분)
    pygame.draw.circle(surface, SHOE_RED, (shoe_cx - 3, shoe_cy), 3)
    
    # 신발 디테일 - M자 로고 (머큐리/헤르메스)
    # M자 그리기
    pygame.draw.lines(surface, SHOE_WHITE, False,
                     [(shoe_cx - 2, shoe_cy + 1),
                      (shoe_cx - 1, shoe_cy - 1),
                      (shoe_cx, shoe_cy + 1),
                      (shoe_cx + 1, shoe_cy - 1),
                      (shoe_cx + 2, shoe_cy + 1)], 1)
    
    # 신발 밑창 (흰색 선)
    for x in range(shoe_cx - 4, shoe_cx + 5):
        surface.set_at((x, shoe_cy + 3), SHOE_WHITE)
    
    # 큰 날개 (양쪽에 명확하게)
    wing_size = int(6 + wing_flap)
    
    # 왼쪽 날개 (크고 선명하게)
    wing_left_x = shoe_cx - 7
    wing_left_y = shoe_cy - 1
    
    # 날개 몸체 (삼각형 모양)
    for i in range(wing_size):
        for j in range(wing_size - i):
            x = wing_left_x - i
            y = wing_left_y - j + i // 2
            if 3 < x < 29 and 3 < y < 29:
                if i == 0:
                    surface.set_at((x, y), WING_GOLD)
                elif i < wing_size // 2:
                    surface.set_at((x, y), WING_YELLOW)
                else:
                    surface.set_at((x, y), WING_ORANGE)
    
    # 오른쪽 날개
    wing_right_x = shoe_cx + 7
    wing_right_y = shoe_cy - 1
    
    for i in range(wing_size):
        for j in range(wing_size - i):
            x = wing_right_x + i
            y = wing_right_y - j + i // 2
            if 3 < x < 29 and 3 < y < 29:
                if i == 0:
                    surface.set_at((x, y), WING_GOLD)
                elif i < wing_size // 2:
                    surface.set_at((x, y), WING_YELLOW)
                else:
                    surface.set_at((x, y), WING_ORANGE)
    
    # 날개 윤곽선 (더 선명하게)
    # 왼쪽 날개 윤곽
    pygame.draw.lines(surface, WING_GOLD, False,
                     [(wing_left_x, wing_left_y - 3),
                      (wing_left_x - 5, wing_left_y),
                      (wing_left_x, wing_left_y + 3)], 1)
    
    # 오른쪽 날개 윤곽
    pygame.draw.lines(surface, WING_GOLD, False,
                     [(wing_right_x, wing_right_y - 3),
                      (wing_right_x + 5, wing_right_y),
                      (wing_right_x, wing_right_y + 3)], 1)
    
    # 스피드 라인 (움직임 효과)
    if frame_index % 2 == 0:
        for i in range(3):
            line_y = shoe_cy - 1 + i
            line_start = 5
            line_end = shoe_cx - 8
            pygame.draw.line(surface, (100, 150, 255, 100),
                           (line_start, line_y), (line_end, line_y), 1)
    
    # 반짝임 효과
    if frame_index in [0, 4]:
        # 날개 끝 반짝임
        sparkle_left = (wing_left_x - 5, wing_left_y)
        sparkle_right = (wing_right_x + 5, wing_right_y)
        
        for px, py in [sparkle_left, sparkle_right]:
            if 3 < px < 29 and 3 < py < 29:
                # 별 모양
                surface.set_at((px, py), (255, 255, 255))
                surface.set_at((px+1, py), (255, 255, 200))
                surface.set_at((px-1, py), (255, 255, 200))
                surface.set_at((px, py+1), (255, 255, 200))
                surface.set_at((px, py-1), (255, 255, 200))
    
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
    pygame.display.set_caption("헤르메스의 신발 - 아이코닉 디자인")
    
    clock = pygame.time.Clock()
    frames = save_animated_icon()
    
    # 라그나로크 해머와 비교
    ragnarok_frames = []
    for i in range(FRAMES):
        path = f"items/legendary/ragnarok_hammer_frame_{i}.png"
        if os.path.exists(path):
            ragnarok_frames.append(pygame.image.load(path))
    
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
        
        # 헤르메스 신발
        big_icon = pygame.transform.scale(frames[frame_index], (128, 128))
        screen.blit(big_icon, (50, 80))
        screen.blit(frames[frame_index], (100, 220))
        
        # 라그나로크 해머 (비교용)
        if ragnarok_frames:
            rag_big = pygame.transform.scale(ragnarok_frames[frame_index], (128, 128))
            screen.blit(rag_big, (400, 80))
            screen.blit(ragnarok_frames[frame_index], (450, 220))
        
        # 설명
        title_text = font.render("HERMES SHOES", True, (255, 50, 50))
        screen.blit(title_text, (50, 30))
        
        title2_text = font.render("RAGNAROK HAMMER", True, (255, 50, 50))
        screen.blit(title2_text, (380, 30))
        
        features = [
            "Iconic Design:",
            "- Red shoe with M logo",
            "- Golden wings",
            "- Clear shape",
            "- Speed lines"
        ]
        
        for i, feature in enumerate(features):
            text = small_font.render(feature, True, (150, 150, 150))
            screen.blit(text, (220, 100 + i * 20))
        
        frame_text = small_font.render(f"Frame: {frame_index + 1}/{FRAMES}", True, (150, 150, 150))
        screen.blit(frame_text, (250, 250))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    print("\n✅ 아이코닉한 헤르메스의 신발 완성!")

if __name__ == "__main__":
    create_demo_animation()