"""
라그나로크 해머 - 실제 PNG 이미지 파일 로드 및 표시
아이템 관리자창에 표시되는 실제 모습 그대로
"""

import pygame
import math
import sys
import os

# 리소스 경로 헬퍼
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((1000, 700))
pygame.display.set_caption("Ragnarok Hammer - Real PNG Images from Game")
clock = pygame.time.Clock()

# 색상 정의
BACKGROUND = (30, 30, 50)
WHITE = (255, 255, 255)
LEGENDARY_COLOR = (255, 50, 50)
COMMON_LEGENDARY_BORDER_COLOR = (180, 200, 255)
COMMON_LEGENDARY_CORNER_COLOR = (255, 215, 0)

# 폰트 설정
font = pygame.font.Font(None, 20)
title_font = pygame.font.Font(None, 28)
korean_font = pygame.font.Font(None, 26)

# 애니메이션 변수
animation_time = 0
frame_counter = 0
current_frame = 0
animation_speed = 8

# 라그나로크 해머 프레임들 로드
hammer_frames = []
frames_loaded = 0

print("라그나로크 해머 PNG 파일 로드 중...")

for i in range(8):
    frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
    try:
        frame = pygame.image.load(frame_path).convert_alpha()
        hammer_frames.append(frame)
        frames_loaded += 1
        print(f"✓ Frame {i} loaded: {frame.get_size()}")
    except Exception as e:
        print(f"✗ Frame {i} failed: {e}")
        # 로드 실패시 빈 이미지 생성
        empty_frame = pygame.Surface((128, 128), pygame.SRCALPHA)
        empty_frame.fill((100, 0, 0, 100))  # 어두운 빨간색으로 표시
        hammer_frames.append(empty_frame)

print(f"총 {frames_loaded}/8 프레임 로드 완료")

def draw_common_legendary_frame(surface, x, y, size, anim_time, draw_icon=True):
    """전설 아이템 공통 프레임 그리기 (실제 게임과 동일)"""

    # 프레임 상하 움직임
    frame_offset = int(math.sin(anim_time * 2.5) * 2)
    frame_y = y + frame_offset

    # 1. 파란색 원형 배경 (펄싱)
    pulse = (math.sin(anim_time * 4.0) + 1) / 2
    base_radius = max(6, int(size * 0.42))
    outer_radius = min(size // 2, int(base_radius + size * 0.05 * pulse))
    inner_radius = max(4, int(outer_radius * 0.65))

    center = (x + size // 2, frame_y + size // 2)

    pygame.draw.circle(surface, (30, 90, 170), center, outer_radius)
    pygame.draw.circle(surface, (70, 140, 200), center, int(outer_radius * 0.85))
    pygame.draw.circle(surface, (140, 190, 220), center, inner_radius)

    # 2. 내부 붉은색 테두리 (3중)
    inner_pulse = (math.sin(anim_time * 6.0) + 1) / 2
    outer_inner_color = (
        int(150 + 70 * inner_pulse),
        int(30 + 35 * inner_pulse),
        int(30 + 35 * inner_pulse)
    )
    mid_inner_color = (
        int(135 + 65 * inner_pulse),
        int(20 + 30 * inner_pulse),
        int(20 + 30 * inner_pulse)
    )
    inner_inner_color = (
        int(120 + 60 * inner_pulse),
        int(10 + 25 * inner_pulse),
        int(10 + 25 * inner_pulse)
    )

    inner_rect_outer = pygame.Rect(x + 2, frame_y + 2, size - 4, size - 4)
    inner_rect_mid = inner_rect_outer.inflate(-2, -2)
    inner_rect_inner = inner_rect_outer.inflate(-4, -4)

    pygame.draw.rect(surface, outer_inner_color, inner_rect_outer, 1)
    pygame.draw.rect(surface, mid_inner_color, inner_rect_mid, 1)
    pygame.draw.rect(surface, inner_inner_color, inner_rect_inner, 1)

    # 3. 실제 PNG 이미지 그리기
    if draw_icon and hammer_frames and current_frame < len(hammer_frames):
        icon = hammer_frames[current_frame]
        # 크기 조정
        if icon.get_size() != (size, size):
            icon = pygame.transform.smoothscale(icon, (size, size))
        surface.blit(icon, (x, frame_y))

    # 4. 외부 프레임 (은색-파란색)
    border_rect = pygame.Rect(x - 1, frame_y - 1, size + 2, size + 2)
    pygame.draw.rect(surface, COMMON_LEGENDARY_BORDER_COLOR, border_rect, 2)

    # 5. 황금색 코너 장식
    corner_size = 8
    corner_color = COMMON_LEGENDARY_CORNER_COLOR

    # L자 형태 코너 (아이템 관리자창과 동일)
    # Top-left
    pygame.draw.lines(surface, corner_color, False,
                     [(x - 2, frame_y + corner_size), (x - 2, frame_y - 2),
                      (x + corner_size, frame_y - 2)], 2)
    # Top-right
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - corner_size + 2, frame_y - 2),
                      (x + size + 2, frame_y - 2),
                      (x + size + 2, frame_y + corner_size)], 2)
    # Bottom-left
    pygame.draw.lines(surface, corner_color, False,
                     [(x - 2, frame_y + size - corner_size + 2),
                      (x - 2, frame_y + size + 2),
                      (x + corner_size, frame_y + size + 2)], 2)
    # Bottom-right
    pygame.draw.lines(surface, corner_color, False,
                     [(x + size - corner_size + 2, frame_y + size + 2),
                      (x + size + 2, frame_y + size + 2),
                      (x + size + 2, frame_y + size - corner_size + 2)], 2)

    # 코너 점
    for cx, cy in [(x, frame_y), (x + size, frame_y),
                   (x, frame_y + size), (x + size, frame_y + size)]:
        pygame.draw.circle(surface, corner_color, (cx, cy), 2)

    # 6. 최외곽 전설 테두리 (빨간색 펄싱)
    legendary_border_color = (
        int(255 * (0.5 + 0.5 * math.sin(anim_time * 3))),
        0,
        0
    )
    pygame.draw.rect(surface, legendary_border_color,
                    (x, frame_y, size, size), 3)

    return frame_offset

def draw_item_slot(surface, x, y, size):
    """아이템 슬롯 배경"""
    slot_bg = pygame.Surface((size + 20, size + 20), pygame.SRCALPHA)
    slot_bg.fill((20, 20, 40, 200))
    pygame.draw.rect(slot_bg, (100, 100, 150), (0, 0, size + 20, size + 20), 2)
    surface.blit(slot_bg, (x - 10, y - 10))

# 메인 루프
running = True
show_raw = False  # 원본 이미지만 보기 모드

while running:
    dt = clock.tick(60) / 1000.0
    animation_time += dt

    # 프레임 카운터 업데이트
    frame_counter += 1
    if frame_counter >= animation_speed:
        frame_counter = 0
        current_frame = (current_frame + 1) % 8

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                animation_speed = 16 if animation_speed == 8 else 8
            elif event.key == pygame.K_r:
                show_raw = not show_raw  # R키로 원본 이미지 토글

    # 화면 그리기
    screen.fill(BACKGROUND)

    # 제목
    title_text = "Raw PNG Images" if show_raw else "Item Manager Style (with effects)"
    title = title_font.render(title_text, True, WHITE)
    title_rect = title.get_rect(centerx=500, top=20)
    screen.blit(title, title_rect)

    if show_raw:
        # 원본 PNG 이미지만 표시 (효과 없이)
        info = font.render("Original PNG frames without any effects", True, (150, 150, 150))
        screen.blit(info, (350, 60))

        # 큰 이미지
        if hammer_frames and current_frame < len(hammer_frames):
            big_frame = pygame.transform.smoothscale(hammer_frames[current_frame], (200, 200))
            screen.blit(big_frame, (400, 100))

            # 프레임 정보
            frame_info = font.render(f"Frame {current_frame}/7", True, WHITE)
            screen.blit(frame_info, (460, 320))

        # 모든 프레임 표시
        all_label = font.render("All 8 frames:", True, WHITE)
        screen.blit(all_label, (50, 380))

        for i in range(8):
            if i < len(hammer_frames):
                small_frame = pygame.transform.smoothscale(hammer_frames[i], (80, 80))
                x_pos = 50 + i * 110
                y_pos = 420

                # 현재 프레임 하이라이트
                if i == current_frame:
                    pygame.draw.rect(screen, (255, 255, 0),
                                   (x_pos - 5, y_pos - 5, 90, 90), 2)

                screen.blit(small_frame, (x_pos, y_pos))

                # 프레임 번호
                num_text = font.render(str(i), True, (200, 200, 200))
                screen.blit(num_text, (x_pos + 35, y_pos + 85))

    else:
        # 아이템 관리자창 스타일 (모든 효과 적용)

        # 메인 아이템 (크게)
        main_size = 128
        main_x = 436
        main_y = 150

        # 슬롯 배경
        draw_item_slot(screen, main_x, main_y, main_size)

        # 라그나로크 해머 with 모든 효과
        draw_common_legendary_frame(screen, main_x, main_y, main_size, animation_time)

        # 아이템 이름
        item_name = korean_font.render("라그나로크 해머", True, LEGENDARY_COLOR)
        name_rect = item_name.get_rect(centerx=500, top=main_y + main_size + 30)
        screen.blit(item_name, name_rect)

        # 프레임별 표시 (작게)
        frame_label = font.render("All frames with effects:", True, WHITE)
        screen.blit(frame_label, (50, 380))

        small_size = 80
        for i in range(8):
            frame_x = 50 + i * 110
            frame_y = 420

            # 현재 프레임 하이라이트
            if i == current_frame:
                highlight = pygame.Surface((small_size + 10, small_size + 10), pygame.SRCALPHA)
                highlight.fill((255, 255, 0, 50))
                screen.blit(highlight, (frame_x - 5, frame_y - 5))

            # 임시로 current_frame 변경해서 각 프레임 그리기
            temp_current = current_frame
            current_frame = i
            draw_item_slot(screen, frame_x, frame_y, small_size)
            draw_common_legendary_frame(screen, frame_x, frame_y, small_size, animation_time)
            current_frame = temp_current

            # 프레임 번호
            frame_num = font.render(str(i), True, (150, 150, 150))
            screen.blit(frame_num, (frame_x + 35, frame_y + small_size + 10))

    # 정보 표시
    info_x = 50
    info_y = 100

    info_texts = [
        f"Loaded: {frames_loaded}/8 frames",
        f"Current: Frame {current_frame}",
        f"Speed: {animation_speed} ticks/frame",
        "",
        "Controls:",
        "SPACE: Toggle speed",
        "R: Show raw images",
        "ESC: Exit"
    ]

    for i, text in enumerate(info_texts):
        color = WHITE if i < 3 else (150, 150, 150)
        info_surf = font.render(text, True, color)
        screen.blit(info_surf, (info_x, info_y + i * 22))

    pygame.display.flip()

pygame.quit()
sys.exit()