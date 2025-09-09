"""
헤르메스의 날개 부츠 - 디테일 강화 버전
전설 아이템 기본 테두리 + 명확한 부츠 형태와 디테일
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
    """헤르메스 날개 부츠 - 디테일 강화"""
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
    
    # ===== 동그란 배경 효과 (라그나로크 해머와 동일) =====
    # 프레임별로 크기와 색상이 변하는 배경
    t = frame_index / FRAMES
    
    # 배경 크기 애니메이션 (15-16 픽셀 반경 - 라그나로크 해머와 동일)
    bg_radius = 15  # 거의 전체 아이콘 크기
    
    # 배경 색상 변화 (초록색/청록색 계열로 변화 - 헤르메스 테마)
    bg_colors = [
        (50, 200, 150),   # 청록색
        (40, 180, 130),   # 진한 청록색
        (60, 220, 170),   # 밝은 청록색
        (45, 190, 140),   # 중간 청록색
        (35, 170, 120),   # 어두운 청록색
        (55, 210, 160),   # 연한 청록색
        (48, 195, 145),   # 민트색
        (52, 205, 155),   # 에메랄드색
    ]
    bg_color = bg_colors[frame_index % len(bg_colors)]
    
    # 배경 원 그리기 (아이템 뒤에)
    center_x, center_y = 16, 16
    for r in range(bg_radius, 0, -1):
        # 안쪽으로 갈수록 밝아지는 그라데이션
        alpha = int(150 * (r / bg_radius))
        color = tuple(min(255, c + (bg_radius - r) * 5) for c in bg_color)
        
        # 원 그리기
        for angle in range(360):
            rad = math.radians(angle)
            px = int(center_x + r * math.cos(rad))
            py = int(center_y + r * math.sin(rad))
            if 0 <= px < 32 and 0 <= py < 32:
                existing = surface.get_at((px, py))
                if existing[3] == 0:  # 투명한 픽셀에만 그리기
                    surface.set_at((px, py), (*color, alpha))
    
    # ===== 디테일한 부츠 디자인 =====
    
    t = frame_index / FRAMES
    
    # 색상 팔레트
    BOOT_BROWN = (101, 67, 33)  # 메인 갈색
    BOOT_MID = (139, 69, 19)  # 중간 갈색
    BOOT_LIGHT = (160, 82, 45)  # 밝은 갈색
    BOOT_DARK = (71, 47, 23)  # 어두운 갈색
    BOOT_SOLE = (30, 30, 30)  # 검은 밑창
    BUCKLE_GOLD = (255, 215, 0)  # 금색 버클
    BUCKLE_DARK = (184, 134, 11)  # 어두운 금색
    LACE_WHITE = (240, 240, 240)  # 흰색 끈
    WING_SILVER = (192, 192, 192)  # 은색
    WING_WHITE = (255, 255, 255)  # 흰색
    WING_LIGHT = (220, 220, 220)  # 밝은 은색
    WING_CYAN = (173, 216, 230)  # 하늘색
    
    # 애니메이션
    wing_flap = math.sin(t * math.pi * 4) * 2
    hover = int(math.sin(t * math.pi * 2) * 1)
    
    # === 부츠 디테일 그리기 (측면 뷰) ===
    boot_x = 10  # 8에서 10으로 변경 (오른쪽으로 2픽셀 이동)
    boot_y = 11 + hover
    
    # 1. 부츠 윤곽선 정의 (더 명확한 부츠 모양)
    # 부츠 상단 (다리 부분) - 원통형
    for y in range(boot_y, boot_y + 7):
        for x in range(boot_x + 1, boot_x + 7):
            # 측면 그라데이션 효과
            if x == boot_x + 1:  # 왼쪽 가장자리
                surface.set_at((x, y), BOOT_DARK)
            elif x == boot_x + 6:  # 오른쪽 가장자리
                surface.set_at((x, y), BOOT_DARK)
            elif x == boot_x + 2:  # 왼쪽 하이라이트
                surface.set_at((x, y), BOOT_LIGHT)
            else:  # 중간
                surface.set_at((x, y), BOOT_BROWN)
    
    # 2. 발목 부분 (약간 좁아짐)
    ankle_y = boot_y + 7
    for x in range(boot_x + 2, boot_x + 6):
        surface.set_at((x, ankle_y), BOOT_MID)
    
    # 3. 발 부분 (측면 실루엣)
    # 발등
    for y in range(ankle_y + 1, ankle_y + 3):
        for x in range(boot_x, boot_x + 8):
            if x == boot_x:  # 왼쪽 윤곽
                surface.set_at((x, y), BOOT_DARK)
            elif x == boot_x + 7:  # 오른쪽 윤곽
                surface.set_at((x, y), BOOT_DARK)
            elif x == boot_x + 1:  # 하이라이트
                surface.set_at((x, y), BOOT_LIGHT)
            else:
                surface.set_at((x, y), BOOT_BROWN)
    
    # 4. 발가락 부분 (둥근 앞코 - 더 길게)
    toe_y = ankle_y + 3
    # 둥근 발가락 표현 (앞으로 더 길게 확장)
    for x in range(boot_x - 3, boot_x + 9):  # 앞코를 3픽셀 더 길게
        if x < boot_x - 1:  # 발가락 맨 앞부분
            surface.set_at((x, toe_y), BOOT_DARK)
            surface.set_at((x, toe_y + 1), BOOT_DARK)
        elif x < boot_x + 1:  # 발가락 앞부분
            surface.set_at((x, toe_y), BOOT_MID)
            surface.set_at((x, toe_y + 1), BOOT_DARK)
        elif x < boot_x + 7:  # 중간 부분
            surface.set_at((x, toe_y), BOOT_BROWN)
            surface.set_at((x, toe_y + 1), BOOT_MID)
        else:  # 뒤쪽
            surface.set_at((x, toe_y), BOOT_MID)
            surface.set_at((x, toe_y + 1), BOOT_DARK)
    
    # 5. 밑창 (두껍고 명확하게 - 더 길게)
    sole_y = toe_y + 2
    for x in range(boot_x - 3, boot_x + 9):  # 밑창도 더 길게
        surface.set_at((x, sole_y), BOOT_SOLE)
        # 밑창 패턴
        if x % 2 == 0:
            surface.set_at((x, sole_y + 1), BOOT_SOLE)
        else:
            surface.set_at((x, sole_y + 1), (50, 50, 50))
    
    # 6. 부츠 디테일 추가
    
    # 버클 (2개)
    # 상단 버클
    buckle1_y = boot_y + 2
    pygame.draw.rect(surface, BUCKLE_GOLD, (boot_x + 2, buckle1_y, 3, 2))
    surface.set_at((boot_x + 3, buckle1_y), BUCKLE_DARK)  # 버클 구멍
    
    # 하단 버클
    buckle2_y = boot_y + 5
    pygame.draw.rect(surface, BUCKLE_GOLD, (boot_x + 2, buckle2_y, 3, 2))
    surface.set_at((boot_x + 3, buckle2_y), BUCKLE_DARK)  # 버클 구멍
    
    # 끈 (지그재그 패턴)
    # 상단 끈
    pygame.draw.line(surface, LACE_WHITE,
                    (boot_x + 1, boot_y + 1),
                    (boot_x + 5, boot_y + 2), 1)
    # 중간 끈
    pygame.draw.line(surface, LACE_WHITE,
                    (boot_x + 5, boot_y + 3),
                    (boot_x + 1, boot_y + 4), 1)
    
    # 스티치 라인 (바느질)
    for y in range(boot_y + 1, ankle_y, 2):
        surface.set_at((boot_x + 3, y), BOOT_DARK)
    
    # === 날개 디자인 (더 화려하게) ===
    wing_base_x = boot_x + 7
    wing_base_y = boot_y + 4
    
    # 메인 날개 (크고 디테일하게)
    for feather in range(6):  # 6개 깃털
        angle = -35 + feather * 12 + wing_flap * (1 - feather * 0.15)
        length = 9 - feather
        
        for i in range(length):
            rad = math.radians(angle)
            fx = int(wing_base_x + i * math.cos(rad))
            fy = int(wing_base_y - i * math.sin(rad) + feather * 0.4)
            
            if 3 < fx < 29 and 3 < fy < 29:
                # 깃털 색상 그라데이션
                if feather == 0:  # 가장 앞 깃털
                    if i < 3:
                        surface.set_at((fx, fy), WING_WHITE)
                    elif i < 6:
                        surface.set_at((fx, fy), WING_LIGHT)
                    else:
                        surface.set_at((fx, fy), WING_CYAN)
                elif feather < 3:  # 중간 깃털들
                    if i % 2 == 0:
                        surface.set_at((fx, fy), WING_LIGHT)
                    else:
                        surface.set_at((fx, fy), WING_SILVER)
                else:  # 뒤쪽 깃털
                    surface.set_at((fx, fy), WING_SILVER)
                
                # 깃털 디테일 라인
                if i > 0 and i % 3 == 0:
                    if fy - 1 > 3:
                        surface.set_at((fx, fy - 1), WING_WHITE)
    
    # 날개 윤곽 강조 (제거 - 불필요한 픽셀 방지)
    # pygame.draw.lines(surface, WING_WHITE, False,
    #                  [(wing_base_x, wing_base_y - 2),
    #                   (wing_base_x + 3, wing_base_y - 4),
    #                   (wing_base_x + 6, wing_base_y - 3),
    #                   (wing_base_x + 7, wing_base_y)], 1)
    
    # 날개 광채 효과 (제거 - 불필요한 파란색 직사각형 방지)
    # if frame_index % 2 == 0:
    #     for i in range(3):
    #         glow_x = wing_base_x + 4 + i
    #         glow_y = wing_base_y - 2 - i
    #         if 3 < glow_x < 29 and 3 < glow_y < 29:
    #             current = surface.get_at((glow_x, glow_y))
    #             new_color = (
    #                 min(255, current[0] + 50),
    #                 min(255, current[1] + 50),
    #                 min(255, current[2] + 100),
    #                 255
    #             )
    #             surface.set_at((glow_x, glow_y), new_color)
    
    # 스피드 효과
    if frame_index in [1, 3, 5, 7]:
        for i in range(3):
            trail_y = boot_y + 6 + i
            for j in range(5):
                trail_x = boot_x - 2 - j
                if 3 < trail_x < 29 and 3 < trail_y < 29:
                    alpha = 80 - j * 15
                    pygame.draw.line(surface, (100, 150, 255, alpha),
                                   (trail_x, trail_y),
                                   (trail_x - 1, trail_y), 1)
    
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
    pygame.display.set_caption("헤르메스의 날개 부츠 - 디테일 버전")
    
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
        screen.blit(title_text, (250, 80))
        
        subtitle = small_font.render("Detailed Version", True, (200, 200, 200))
        screen.blit(subtitle, (250, 105))
        
        features = [
            "Enhanced Details:",
            "- Clear boot silhouette",
            "- Double golden buckles",
            "- Zigzag lace pattern",
            "- Thick black sole",
            "- Stitching details",
            "- 6-layer wing feathers",
            "- Gradient wing colors"
        ]
        
        for i, feature in enumerate(features):
            text = small_font.render(feature, True, (150, 150, 150))
            screen.blit(text, (250, 130 + i * 18))
        
        frame_text = small_font.render(f"Frame: {frame_index + 1}/{FRAMES}", True, (150, 150, 150))
        screen.blit(frame_text, (100, 250))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    print("\n✅ 디테일한 헤르메스의 날개 부츠 완성!")

if __name__ == "__main__":
    # PNG 파일만 생성 (데모 창 없이)
    frames = save_animated_icon()
    print("\n✅ 디테일한 헤르메스의 날개 부츠 완성!")
    print("📝 신발 앞코를 더 길게 수정 완료!")