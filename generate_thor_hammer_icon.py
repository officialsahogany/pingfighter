"""
라그나로크 해머 아이콘 생성 - 토르 망치 스타일 (에너지 응축)
"""
import pygame
import math
import random
import os

# 초기화
pygame.init()

# 아이콘 크기
ICON_SIZE = 32
FRAMES = 8  # 애니메이션 프레임 수

def create_thor_hammer_frame(frame_index):
    """토르의 망치 스타일로 한 프레임 생성"""
    surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
    
    # 애니메이션 타이밍
    t = frame_index / FRAMES
    
    # 중심점
    center_x = ICON_SIZE // 2
    center_y = ICON_SIZE // 2
    
    # === 1. 에너지 필드 (배경) ===
    # 응축된 에너지 오라 (펄싱)
    energy_radius = 14 + math.sin(t * math.pi * 2) * 2
    for i in range(5, 0, -1):
        radius = energy_radius + i * 2
        alpha = 40 - i * 8
        # 청록색 전기 에너지
        energy_color = (100, 200, 255, alpha)
        
        # 에너지 원
        energy_surf = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
        pygame.draw.circle(energy_surf, energy_color, (center_x, center_y), radius)
        surface.blit(energy_surf, (0, 0))
    
    # === 2. 망치 헤드 (묠니르 스타일) ===
    # 메탈릭 그라데이션 색상
    hammer_base = (120, 130, 140)  # 다크 메탈
    hammer_light = (200, 210, 220)  # 라이트 메탈
    hammer_highlight = (255, 255, 255)  # 하이라이트
    
    # 망치 머리 (사각형, 큰 크기)
    head_width = 18
    head_height = 12
    head_x = center_x - head_width // 2
    head_y = center_y - 6
    
    # 메탈 그라데이션 효과
    for y in range(head_height):
        gradient = y / head_height
        color_r = int(hammer_light[0] * (1 - gradient) + hammer_base[0] * gradient)
        color_g = int(hammer_light[1] * (1 - gradient) + hammer_base[1] * gradient)
        color_b = int(hammer_light[2] * (1 - gradient) + hammer_base[2] * gradient)
        pygame.draw.line(surface, (color_r, color_g, color_b), 
                        (head_x, head_y + y), (head_x + head_width - 1, head_y + y))
    
    # 망치 모서리 경사 (입체감)
    pygame.draw.polygon(surface, hammer_base, [
        (head_x, head_y),
        (head_x + 2, head_y - 2),
        (head_x + head_width - 2, head_y - 2),
        (head_x + head_width, head_y)
    ])
    
    # 중앙 룬 문자 (북유럽 스타일)
    rune_color = (150, 220, 255)  # 밝은 청색
    rune_glow = int(200 + 55 * math.sin(t * math.pi * 4))  # 빛나는 효과
    
    # 번개 룬 (지그재그 패턴)
    rune_points = [
        (center_x - 3, head_y + 3),
        (center_x, head_y + 5),
        (center_x - 2, head_y + 7),
        (center_x + 3, head_y + 9)
    ]
    pygame.draw.lines(surface, (rune_glow, rune_glow, 255), False, rune_points, 2)
    
    # === 3. 손잡이 ===
    handle_color = (80, 60, 40)  # 다크 브라운 (가죽 느낌)
    handle_width = 4
    handle_height = 10
    handle_x = center_x - handle_width // 2
    handle_y = head_y + head_height
    
    # 손잡이 그리기
    pygame.draw.rect(surface, handle_color, 
                    (handle_x, handle_y, handle_width, handle_height))
    
    # 손잡이 감기 (가죽 끈)
    for i in range(0, handle_height, 2):
        wrap_color = (60, 45, 30) if i % 4 == 0 else (100, 75, 50)
        pygame.draw.line(surface, wrap_color, 
                        (handle_x, handle_y + i), 
                        (handle_x + handle_width - 1, handle_y + i))
    
    # === 4. 전기 에너지 파티클 ===
    # 프레임별로 다른 번개 효과
    if frame_index % 2 == 0:  # 짝수 프레임에서 강한 번개
        num_sparks = 5 + frame_index % 3
        for _ in range(num_sparks):
            # 랜덤 번개 시작점
            spark_start_x = center_x + random.randint(-8, 8)
            spark_start_y = center_y + random.randint(-8, 8)
            
            # 번개 끝점
            angle = random.uniform(0, math.pi * 2)
            length = random.randint(8, 14)
            spark_end_x = spark_start_x + int(math.cos(angle) * length)
            spark_end_y = spark_start_y + int(math.sin(angle) * length)
            
            # 번개 중간점 (지그재그)
            mid_x = (spark_start_x + spark_end_x) // 2 + random.randint(-3, 3)
            mid_y = (spark_start_y + spark_end_y) // 2 + random.randint(-3, 3)
            
            # 번개 색상 (밝은 청백색)
            lightning_color = (200, 230, 255)
            
            # 번개 그리기
            pygame.draw.lines(surface, lightning_color, False,
                            [(spark_start_x, spark_start_y),
                             (mid_x, mid_y),
                             (spark_end_x, spark_end_y)], 1)
    
    # === 5. 응축된 에너지 코어 ===
    # 망치 중심부의 강력한 에너지
    core_pulse = math.sin(t * math.pi * 3)
    core_size = 3 + abs(core_pulse)
    core_alpha = int(150 + 105 * abs(core_pulse))
    
    # 에너지 코어 (다층 구조)
    for i in range(3):
        size = core_size - i
        if size > 0:
            alpha = core_alpha - i * 30
            if alpha > 0:
                core_color = (150, 200, 255, alpha)
                core_surf = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
                pygame.draw.circle(core_surf, core_color, (center_x, center_y), int(size))
                surface.blit(core_surf, (0, 0))
    
    # 중심 밝은 점
    pygame.draw.circle(surface, (255, 255, 255), (center_x, center_y), 1)
    
    # === 6. 전설 등급 테두리 ===
    # 레전더리 빨간색 테두리 (번개 효과 포함)
    border_color = (255, 50, 50)
    border_glow = int(150 + 105 * math.sin(t * math.pi * 2))
    
    # 외곽 테두리
    pygame.draw.rect(surface, (border_glow, 0, 0), 
                    (0, 0, ICON_SIZE, ICON_SIZE), 2)
    
    # 코너 강조 (번개 스파크)
    corners = [(1, 1), (ICON_SIZE-2, 1), (1, ICON_SIZE-2), (ICON_SIZE-2, ICON_SIZE-2)]
    for cx, cy in corners:
        # 코너 스파크
        spark_alpha = int(200 + 55 * math.sin(t * math.pi * 4 + cx))
        pygame.draw.circle(surface, (spark_alpha, spark_alpha, 255), (cx, cy), 2)
    
    # === 7. 파워 인디케이터 ===
    # 상단에 작은 번개 표시 (파워 레벨)
    if frame_index in [0, 4]:  # 특정 프레임에서만
        power_y = 3
        for i in range(3):
            power_x = center_x - 4 + i * 4
            power_color = (255, 220, 100) if i == 1 else (200, 180, 80)
            pygame.draw.circle(surface, power_color, (power_x, power_y), 1)
    
    return surface

def create_preview_image():
    """미리보기 이미지 생성 (모든 프레임 나열)"""
    preview_width = ICON_SIZE * FRAMES
    preview_height = ICON_SIZE
    preview = pygame.Surface((preview_width, preview_height), pygame.SRCALPHA)
    preview.fill((30, 30, 50))  # 다크 배경
    
    for i in range(FRAMES):
        frame = create_thor_hammer_frame(i)
        preview.blit(frame, (i * ICON_SIZE, 0))
        # 프레임 구분선
        if i > 0:
            pygame.draw.line(preview, (100, 100, 100), 
                           (i * ICON_SIZE, 0), (i * ICON_SIZE, ICON_SIZE))
    
    return preview

def main():
    # 출력 디렉토리 생성
    os.makedirs("items/legendary", exist_ok=True)
    
    # 각 프레임 생성 및 저장
    print("🔨⚡ 토르 스타일 라그나로크 해머 생성 중...")
    
    frames = []
    for i in range(FRAMES):
        frame = create_thor_hammer_frame(i)
        frames.append(frame)
        
        # 개별 프레임 저장
        filename = f"items/legendary/ragnarok_hammer_frame_{i}.png"
        pygame.image.save(frame, filename)
        print(f"  프레임 {i+1}/{FRAMES} 생성 완료: {filename}")
    
    # 첫 번째 프레임을 기본 아이콘으로 저장
    pygame.image.save(frames[0], "items/legendary/ragnarok_hammer.png")
    print("  기본 아이콘 저장: items/legendary/ragnarok_hammer.png")
    
    # 미리보기 이미지 생성
    preview = create_preview_image()
    pygame.image.save(preview, "items/legendary/ragnarok_hammer_preview.png")
    print("  미리보기 생성: items/legendary/ragnarok_hammer_preview.png")
    
    print(f"\n✨ 토르의 망치 스타일 라그나로크 해머 생성 완료!")
    print(f"  - 에너지 응축 효과")
    print(f"  - 룬 문자 발광")
    print(f"  - 번개 파티클 효과")
    print(f"  - 메탈릭 그라데이션")
    print(f"  - 전설 등급 테두리")

if __name__ == "__main__":
    main()