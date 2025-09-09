"""
포세이돈의 삼지창 - 전설 아이템 아이콘 생성
물의 신 포세이돈의 강력한 삼지창
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

def create_poseidon_frame(frame_index):
    """포세이돈의 삼지창 프레임 생성"""
    surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
    
    # ===== 라그나로크 해머와 동일한 에너지 필드 (배경) =====
    # 애니메이션 타이밍
    t = frame_index / FRAMES
    
    # 중심점
    center_x = ICON_SIZE // 2
    center_y = ICON_SIZE // 2
    
    # === 1. 에너지 필드 (배경) - 모든 전설 아이템 기본 ===
    # 응축된 에너지 오라 (펄싱) - 물빛 청록색으로 변경
    energy_radius = 14 + math.sin(t * math.pi * 2) * 2
    for i in range(5, 0, -1):
        radius = energy_radius + i * 2
        alpha = 40 - i * 8
        # 물빛 청록색 전기 에너지 (포세이돈 테마)
        energy_color = (50, 150, 255, alpha)  # 더 진한 파란색
        
        # 에너지 원
        energy_surf = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
        pygame.draw.circle(energy_surf, energy_color, (center_x, center_y), radius)
        surface.blit(energy_surf, (0, 0))
    
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
    
    # ===== 포세이돈의 삼지창 디자인 =====
    
    # 색상 팔레트 (바다 테마)
    TRIDENT_SILVER = (200, 220, 240)  # 은빛 메탈
    TRIDENT_DARK = (100, 120, 140)    # 어두운 메탈
    TRIDENT_LIGHT = (240, 250, 255)   # 밝은 메탈
    WATER_BLUE = (0, 150, 255)        # 물빛 파란색
    WATER_LIGHT = (150, 200, 255)     # 연한 물빛
    WATER_DARK = (0, 100, 200)        # 진한 물빛
    FOAM_WHITE = (240, 250, 255)      # 거품 흰색
    
    # 애니메이션 변수
    wave_offset = math.sin(t * math.pi * 4) * 2  # 물결 효과
    pulse = math.sin(t * math.pi * 2) * 0.5 + 0.5  # 펄스 효과
    
    # === 삼지창 본체 그리기 ===
    
    # 중앙 기둥 (손잡이)
    shaft_x = center_x
    shaft_y_start = 22
    shaft_y_end = 8
    
    # 메탈릭 그라데이션 효과의 기둥
    for y in range(shaft_y_end, shaft_y_start + 1):
        # 중심에서 가장자리로 갈수록 어두워지는 효과
        for x_offset in range(-1, 2):
            x = shaft_x + x_offset
            if 3 < x < 29 and 3 < y < 29:
                if x_offset == 0:
                    surface.set_at((x, y), TRIDENT_LIGHT)
                else:
                    surface.set_at((x, y), TRIDENT_SILVER)
    
    # 삼지창 머리 부분 (세 갈래)
    prong_y = shaft_y_end
    
    # 중앙 갈래 (가장 길고 곧음)
    for y in range(prong_y - 6, prong_y + 1):
        if 3 < y < 29:
            surface.set_at((center_x, y), TRIDENT_LIGHT)
            # 양옆 그라데이션
            if center_x - 1 > 3:
                surface.set_at((center_x - 1, y), TRIDENT_SILVER)
            if center_x + 1 < 29:
                surface.set_at((center_x + 1, y), TRIDENT_SILVER)
    
    # 중앙 갈래 끝 (뾰족한 부분)
    tip_y = prong_y - 7
    if 3 < tip_y < 29:
        surface.set_at((center_x, tip_y), TRIDENT_LIGHT)
    
    # 왼쪽 갈래 (곡선)
    left_prong_x = center_x - 5
    for i in range(7):
        y = prong_y - i
        # 곡선 효과
        x_offset = int(math.sin(i * 0.3) * 2)
        x = left_prong_x - x_offset
        if 3 < x < 29 and 3 < y < 29:
            surface.set_at((x, y), TRIDENT_SILVER)
            if x + 1 < 29:
                surface.set_at((x + 1, y), TRIDENT_DARK)
    
    # 오른쪽 갈래 (곡선)
    right_prong_x = center_x + 5
    for i in range(7):
        y = prong_y - i
        # 곡선 효과
        x_offset = int(math.sin(i * 0.3) * 2)
        x = right_prong_x + x_offset
        if 3 < x < 29 and 3 < y < 29:
            surface.set_at((x, y), TRIDENT_SILVER)
            if x - 1 > 3:
                surface.set_at((x - 1, y), TRIDENT_DARK)
    
    # 갈래 연결 부분 (장식)
    connect_y = prong_y
    for x in range(center_x - 5, center_x + 6):
        if 3 < x < 29 and 3 < connect_y < 29:
            surface.set_at((x, connect_y), TRIDENT_DARK)
    
    # === 물의 효과 추가 ===
    
    # 물방울 효과 (프레임별로 다른 위치)
    droplet_positions = [
        (center_x - 7, 12 + int(wave_offset)),
        (center_x + 7, 14 - int(wave_offset)),
        (center_x - 4, 18 + int(wave_offset * 0.5)),
        (center_x + 4, 16 - int(wave_offset * 0.5)),
    ]
    
    for i, (drop_x, drop_y) in enumerate(droplet_positions):
        if frame_index % 2 == i % 2:  # 프레임별로 다른 물방울 표시
            if 3 < drop_x < 29 and 3 < drop_y < 29:
                # 물방울 중심
                surface.set_at((drop_x, drop_y), WATER_LIGHT)
                # 물방울 하이라이트
                if drop_y - 1 > 3:
                    surface.set_at((drop_x, drop_y - 1), FOAM_WHITE)
    
    # 물결 효과 (삼지창 주변)
    if frame_index in [0, 2, 4, 6]:  # 특정 프레임에서만
        # 왼쪽 물결
        wave_x = center_x - 8
        wave_y = 15 + int(wave_offset)
        if 3 < wave_x < 29 and 3 < wave_y < 29:
            for i in range(3):
                wx = wave_x + i
                if 3 < wx < 29:
                    color = WATER_BLUE if i == 1 else WATER_DARK
                    surface.set_at((wx, wave_y), color)
        
        # 오른쪽 물결
        wave_x = center_x + 6
        wave_y = 15 - int(wave_offset)
        if 3 < wave_x < 29 and 3 < wave_y < 29:
            for i in range(3):
                wx = wave_x + i
                if 3 < wx < 29:
                    color = WATER_BLUE if i == 1 else WATER_DARK
                    surface.set_at((wx, wave_y), color)
    
    # 바다의 힘 효과 (삼지창 끝에서 발산)
    if frame_index % 3 == 0:
        # 중앙 갈래 끝에서 발산
        power_y = tip_y - 1
        if 3 < power_y < 29:
            # 작은 파동
            for x_off in [-2, -1, 1, 2]:
                px = center_x + x_off
                if 3 < px < 29:
                    alpha_factor = 1.0 - abs(x_off) / 3.0
                    if alpha_factor > 0.3:
                        surface.set_at((px, power_y), WATER_LIGHT)
    
    # 삼지창 손잡이 장식 (바다 문양)
    grip_y = 20
    if 3 < grip_y < 29:
        # 파도 문양
        for i in range(3):
            pattern_y = grip_y - i * 2
            if 3 < pattern_y < 29:
                # 지그재그 패턴
                if i % 2 == 0:
                    surface.set_at((center_x - 1, pattern_y), WATER_DARK)
                    surface.set_at((center_x + 1, pattern_y), WATER_DARK)
                else:
                    surface.set_at((center_x, pattern_y), WATER_BLUE)
    
    return surface

def save_animated_icon():
    """애니메이션 아이콘 저장"""
    os.makedirs("items/legendary", exist_ok=True)
    
    frames = []
    for i in range(FRAMES):
        frame = create_poseidon_frame(i)
        frames.append(frame)
        
        filename = f"items/legendary/poseidon_trident_frame_{i}.png"
        pygame.image.save(frame, filename)
        print(f"프레임 {i} 저장: {filename}")
    
    # 기본 아이콘 (첫 번째 프레임)
    pygame.image.save(frames[0], "items/legendary/poseidon_trident.png")
    print("\n기본 아이콘 저장: items/legendary/poseidon_trident.png")
    
    # 미리보기
    preview_width = ICON_SIZE * FRAMES
    preview = pygame.Surface((preview_width, ICON_SIZE), pygame.SRCALPHA)
    
    for i, frame in enumerate(frames):
        preview.blit(frame, (i * ICON_SIZE, 0))
    
    pygame.image.save(preview, "items/legendary/poseidon_trident_preview.png")
    print("미리보기 저장: items/legendary/poseidon_trident_preview.png")
    
    return frames

def main():
    """메인 실행 함수"""
    frames = save_animated_icon()
    print("\n✅ 포세이돈의 삼지창 생성 완료!")
    print("🔱 바다의 신 포세이돈의 강력한 삼지창")
    print("💧 물의 파동으로 공의 궤적을 조작합니다")

if __name__ == "__main__":
    main()