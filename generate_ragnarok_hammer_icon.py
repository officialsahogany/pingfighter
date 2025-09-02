"""
라그나로크 해머 레전드 아이템 아이콘 생성
- 빨간 테두리와 애니메이션 효과를 가진 전설 티어 아이템
"""

import pygame
import math
import os

# Pygame 초기화
pygame.init()

# 아이콘 크기 (32x32)
ICON_SIZE = 32
FRAMES = 8  # 애니메이션 프레임 수

# 색상 정의
LEGENDARY_RED = (255, 50, 50)
HAMMER_HEAD_COLOR = (120, 120, 140)  # 회색빛 금속
HAMMER_HEAD_DARK = (80, 80, 100)
HAMMER_HEAD_LIGHT = (160, 160, 180)
HAMMER_HANDLE = (101, 67, 33)  # 나무 손잡이
HAMMER_HANDLE_DARK = (71, 47, 23)
LIGHTNING_YELLOW = (255, 255, 150)
LIGHTNING_WHITE = (255, 255, 255)
IMPACT_GLOW = (255, 200, 100)

def create_hammer_frame(frame_index):
    """해머 프레임 생성"""
    surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
    
    # 애니메이션 타이밍
    t = frame_index / FRAMES
    
    # 빨간 테두리 (전설 티어)
    border_thickness = 2
    border_glow = int(128 + 127 * math.sin(t * math.pi * 2))  # 펄싱 효과
    
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
    
    # 해머 회전 애니메이션
    rotation_angle = math.sin(t * math.pi * 2) * 10  # -10도에서 +10도
    hammer_y_offset = int(math.sin(t * math.pi * 2) * 2)  # 위아래 움직임
    
    # 번개 효과 (일부 프레임에만)
    if frame_index in [2, 3, 6, 7]:
        # 작은 번개 볼트
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
    
    # 해머 손잡이 (나무)
    handle_x = 14
    handle_y = 10 + hammer_y_offset
    handle_width = 4
    handle_height = 16
    
    # 손잡이 그림자
    pygame.draw.rect(surface, HAMMER_HANDLE_DARK, 
                   (handle_x + 1, handle_y + 1, handle_width, handle_height))
    
    # 메인 손잡이
    pygame.draw.rect(surface, HAMMER_HANDLE, 
                   (handle_x, handle_y, handle_width, handle_height))
    
    # 손잡이 하이라이트
    pygame.draw.rect(surface, HAMMER_HANDLE, 
                   (handle_x, handle_y, 1, handle_height))
    
    # 손잡비 나무결
    for i in range(3):
        y = handle_y + 4 + i * 5
        pygame.draw.line(surface, HAMMER_HANDLE_DARK, 
                       (handle_x, y), (handle_x + handle_width - 1, y), 1)
    
    # 해머 헤드 (금속)
    head_x = 8
    head_y = 7 + hammer_y_offset
    head_width = 16
    head_height = 8
    
    # 해머 헤드 그림자
    pygame.draw.rect(surface, HAMMER_HEAD_DARK, 
                   (head_x + 1, head_y + 1, head_width, head_height))
    
    # 메인 해머 헤드
    pygame.draw.rect(surface, HAMMER_HEAD_COLOR, 
                   (head_x, head_y, head_width, head_height))
    
    # 해머 헤드 하이라이트 (금속 광택)
    pygame.draw.rect(surface, HAMMER_HEAD_LIGHT, 
                   (head_x + 2, head_y + 1, head_width - 4, 2))
    
    # 해머 헤드 디테일 (양쪽 끝)
    # 왼쪽 끝
    pygame.draw.rect(surface, HAMMER_HEAD_COLOR, 
                   (head_x - 2, head_y + 1, 3, head_height - 2))
    pygame.draw.rect(surface, HAMMER_HEAD_DARK, 
                   (head_x - 2, head_y + head_height - 2, 3, 1))
    
    # 오른쪽 끝
    pygame.draw.rect(surface, HAMMER_HEAD_COLOR, 
                   (head_x + head_width - 1, head_y + 1, 3, head_height - 2))
    pygame.draw.rect(surface, HAMMER_HEAD_DARK, 
                   (head_x + head_width - 1, head_y + head_height - 2, 3, 1))
    
    # 충격파 효과 (일부 프레임)
    if frame_index in [0, 4]:
        # 충격파 원
        impact_radius = 6 + (frame_index // 4) * 2
        impact_alpha = 100 - (frame_index // 4) * 30
        
        for i in range(2):
            radius = impact_radius - i * 2
            if radius > 0:
                color = (*IMPACT_GLOW, impact_alpha // (i + 1))
                # 충격파를 픽셀 단위로 그리기
                center_x, center_y = 16, 11 + hammer_y_offset
                for angle in range(0, 360, 30):
                    x = center_x + int(radius * math.cos(math.radians(angle)))
                    y = center_y + int(radius * math.sin(math.radians(angle)))
                    if 0 <= x < ICON_SIZE and 0 <= y < ICON_SIZE:
                        surface.set_at((x, y), color)
    
    # 파워 글로우 (해머 주변)
    if frame_index % 2 == 0:
        # 해머 주변에 붉은 광채
        glow_alpha = 40 + int(20 * math.sin(t * math.pi * 2))
        for dx in range(-1, 2):
            for dy in range(-1, 2):
                if dx != 0 or dy != 0:
                    glow_x = head_x + head_width // 2 + dx * 3
                    glow_y = head_y + head_height // 2 + dy * 3
                    if 0 <= glow_x < ICON_SIZE and 0 <= glow_y < ICON_SIZE:
                        surface.set_at((glow_x, glow_y), (*LEGENDARY_RED, glow_alpha))
    
    # 룬 문자 (신화적 요소)
    if frame_index in [1, 5]:
        # 작은 룬 문자를 해머 헤드에
        rune_color = (255, 100, 100, 150)
        # 간단한 V 모양 룬
        pygame.draw.lines(surface, rune_color, False, 
                        [(head_x + 7, head_y + 3), 
                         (head_x + 9, head_y + 5), 
                         (head_x + 11, head_y + 3)], 1)
    
    return surface

def save_animated_icon():
    """애니메이션 아이콘을 개별 프레임으로 저장"""
    # legendary 디렉토리 생성
    os.makedirs("items/legendary", exist_ok=True)
    
    frames = []
    for i in range(FRAMES):
        frame = create_hammer_frame(i)
        frames.append(frame)
        
        # 각 프레임을 개별 파일로 저장
        filename = f"items/legendary/ragnarok_hammer_frame_{i}.png"
        pygame.image.save(frame, filename)
        print(f"프레임 {i} 저장: {filename}")
    
    # 첫 번째 프레임을 기본 아이콘으로도 저장
    pygame.image.save(frames[0], "items/legendary/ragnarok_hammer.png")
    print("\n기본 아이콘 저장: items/legendary/ragnarok_hammer.png")
    
    # 애니메이션 미리보기 생성 (모든 프레임을 한 이미지에)
    preview_width = ICON_SIZE * FRAMES
    preview = pygame.Surface((preview_width, ICON_SIZE), pygame.SRCALPHA)
    
    for i, frame in enumerate(frames):
        preview.blit(frame, (i * ICON_SIZE, 0))
    
    pygame.image.save(preview, "items/legendary/ragnarok_hammer_preview.png")
    print("애니메이션 미리보기 저장: items/legendary/ragnarok_hammer_preview.png")
    
    return frames

def create_demo_animation():
    """데모 애니메이션 창"""
    screen = pygame.display.set_mode((400, 200))
    pygame.display.set_caption("라그나로크 해머 - 레전드 아이템")
    
    clock = pygame.time.Clock()
    frames = save_animated_icon()
    
    frame_index = 0
    frame_counter = 0
    animation_speed = 8  # 프레임당 틱 수
    
    # 폰트
    font = pygame.font.Font(None, 24)
    small_font = pygame.font.Font(None, 18)
    
    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
        
        # 배경
        screen.fill((30, 30, 40))
        
        # 애니메이션 프레임 업데이트
        frame_counter += 1
        if frame_counter >= animation_speed:
            frame_counter = 0
            frame_index = (frame_index + 1) % FRAMES
        
        # 큰 버전 (4x 확대)
        big_icon = pygame.transform.scale(frames[frame_index], (128, 128))
        screen.blit(big_icon, (50, 50))
        
        # 작은 버전 (원본 크기)
        screen.blit(frames[frame_index], (220, 90))
        
        # 텍스트
        title_text = font.render("RAGNAROK HAMMER", True, LEGENDARY_RED)
        screen.blit(title_text, (200, 30))
        
        tier_text = small_font.render("LEGENDARY TIER", True, (255, 200, 200))
        screen.blit(tier_text, (200, 55))
        
        desc_text = small_font.render("Massive Knockback & Stun", True, (200, 200, 200))
        screen.blit(desc_text, (200, 130))
        
        frame_text = small_font.render(f"Frame: {frame_index + 1}/{FRAMES}", True, (150, 150, 150))
        screen.blit(frame_text, (200, 160))
        
        # 전설 효과 표시
        glow_intensity = abs(math.sin(pygame.time.get_ticks() * 0.002))
        glow_radius = int(70 + glow_intensity * 10)
        glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (*LEGENDARY_RED, int(30 * glow_intensity)), 
                         (glow_radius, glow_radius), glow_radius)
        screen.blit(glow_surf, (114 - glow_radius, 114 - glow_radius))
        
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()
    print("\n✅ 라그나로크 해머 아이콘 생성 완료!")
    print("📁 저장 위치:")
    print("  - items/legendary/ragnarok_hammer.png (기본)")
    print("  - items/legendary/ragnarok_hammer_frame_0~7.png (애니메이션)")
    print("  - items/legendary/ragnarok_hammer_preview.png (미리보기)")

if __name__ == "__main__":
    create_demo_animation()