"""
전설 아이템 기본 템플릿 생성기
모든 전설 아이템이 반드시 포함해야 하는 기본 테두리 스타일
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

def create_legendary_base_frame(frame_index):
    """전설 아이템 기본 프레임 (에너지 필드 애니메이션 + 테두리)"""
    surface = pygame.Surface((ICON_SIZE, ICON_SIZE), pygame.SRCALPHA)
    
    # ===== 1. 에너지 필드 (배경) - 모든 전설 아이템 기본 =====
    # 라그나로크 해머와 헤르메스의 신발에 사용된 동일한 에너지 필드
    # 애니메이션 타이밍
    t = frame_index / FRAMES
    
    # 중심점
    center_x = ICON_SIZE // 2
    center_y = ICON_SIZE // 2
    
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
    
    # 2. 은색/보라색 모서리 장식 (3x3 영역) (필수!)
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
    
    # 3. 빨간 테두리 (프레임별로 색상 변화) (필수!)
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
    
    return surface

def draw_custom_item(surface, frame_index):
    """
    여기에 아이템별 고유 디자인을 추가하세요
    
    Args:
        surface: 그릴 Surface (이미 테두리가 그려진 상태)
        frame_index: 현재 프레임 번호 (0-7)
    
    Example:
        # 중앙에 아이템 그리기
        pygame.draw.circle(surface, (255, 255, 0), (16, 16), 5)
    """
    # TODO: 여기에 아이템별 고유 디자인 추가
    # 예시: 물음표 그리기
    font = pygame.font.Font(None, 20)
    text = font.render("?", True, (255, 255, 255))
    text_rect = text.get_rect(center=(16, 16))
    surface.blit(text, text_rect)

def create_legendary_item(item_name="template"):
    """전설 아이템 생성"""
    os.makedirs("items/legendary", exist_ok=True)
    
    frames = []
    for i in range(FRAMES):
        # 기본 프레임 생성 (테두리)
        frame = create_legendary_base_frame(i)
        
        # 아이템별 고유 디자인 추가
        draw_custom_item(frame, i)
        
        frames.append(frame)
        
        # 각 프레임 저장
        filename = f"items/legendary/{item_name}_frame_{i}.png"
        pygame.image.save(frame, filename)
        print(f"프레임 {i} 저장: {filename}")
    
    # 기본 아이콘 저장
    pygame.image.save(frames[0], f"items/legendary/{item_name}.png")
    print(f"\n기본 아이콘 저장: items/legendary/{item_name}.png")
    
    # 미리보기 생성
    preview_width = ICON_SIZE * FRAMES
    preview = pygame.Surface((preview_width, ICON_SIZE), pygame.SRCALPHA)
    
    for i, frame in enumerate(frames):
        preview.blit(frame, (i * ICON_SIZE, 0))
    
    pygame.image.save(preview, f"items/legendary/{item_name}_preview.png")
    print(f"미리보기 저장: items/legendary/{item_name}_preview.png")
    
    return frames

def main():
    """
    사용법:
    1. draw_custom_item() 함수에 아이템 디자인 추가
    2. create_legendary_item("아이템명") 호출
    
    기본 포함 요소:
    - 에너지 필드 애니메이션 (펄싱하는 청록색 원)
    - 전설 등급 빨간 테두리
    - 은색/보라색 모서리 장식
    """
    # 템플릿 생성 예시
    create_legendary_item("template")
    
    print("\n" + "="*50)
    print("✅ 전설 아이템 템플릿 생성 완료!")
    print("📌 기본 포함 요소:")
    print("   - 에너지 필드 애니메이션 (자동)")
    print("   - 전설 등급 테두리 (자동)")
    print("⚠️  draw_custom_item() 함수를 수정하여 고유 디자인을 추가하세요")
    print("⚠️  에너지 필드와 테두리는 자동으로 포함됩니다!")
    print("="*50)

if __name__ == "__main__":
    main()