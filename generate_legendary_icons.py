"""
전설 아이템 아이콘 생성 스크립트
각 전설 아이템별로 32x32 픽셀 아이콘을 생성합니다.
"""

import pygame
import math
import os

# Pygame 초기화
pygame.init()

# 아이콘 디렉토리 생성
if not os.path.exists("items/legendary"):
    os.makedirs("items/legendary")

def create_infinity_gauntlet():
    """무한의 건틀릿 아이콘 생성"""
    icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    
    # 건틀릿 (장갑) 모양
    # 손바닥 부분
    pygame.draw.ellipse(icon, (150, 100, 50), (8, 12, 16, 14))
    pygame.draw.ellipse(icon, (180, 130, 80), (9, 13, 14, 12))
    
    # 손가락들 (5개)
    fingers = [
        (8, 8, 4, 8),    # 엄지
        (13, 4, 3, 10),  # 검지
        (17, 3, 3, 11),  # 중지
        (21, 4, 3, 10),  # 약지
        (24, 6, 3, 8),   # 새끼
    ]
    
    for x, y, w, h in fingers:
        pygame.draw.rect(icon, (150, 100, 50), (x, y, w, h))
        pygame.draw.rect(icon, (180, 130, 80), (x, y+1, w-1, h-2))
    
    # 인피니티 스톤들 (6개의 보석)
    stones = [
        (10, 15, (255, 0, 0)),     # 빨강
        (16, 15, (0, 255, 0)),     # 초록
        (22, 15, (0, 100, 255)),   # 파랑
        (10, 20, (255, 255, 0)),   # 노랑
        (16, 20, (255, 0, 255)),   # 보라
        (22, 20, (255, 150, 0)),   # 주황
    ]
    
    for x, y, color in stones:
        pygame.draw.circle(icon, color, (x, y), 2)
        pygame.draw.circle(icon, (255, 255, 255), (x, y), 2, 1)
    
    pygame.image.save(icon, "items/legendary/infinity_gauntlet.png")
    print("무한의 건틀릿 아이콘 생성 완료")


def create_phoenix_feather():
    """불사조의 깃털 아이콘 생성"""
    icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    
    # 깃털 중심축
    pygame.draw.line(icon, (255, 150, 0), (16, 28), (16, 4), 2)
    
    # 깃털 날개 부분 (그라데이션 효과)
    colors = [
        (255, 100, 0),
        (255, 150, 0),
        (255, 200, 50),
        (255, 255, 100),
    ]
    
    for i in range(12):
        y = 6 + i * 2
        width = 8 - abs(i - 6)
        if width > 0:
            color = colors[min(i // 3, 3)]
            # 왼쪽 깃털
            for j in range(width):
                alpha = 200 - j * 20
                pygame.draw.line(icon, (*color, alpha), 
                                (16 - j - 2, y), (16 - width - 2, y))
            # 오른쪽 깃털
            for j in range(width):
                alpha = 200 - j * 20
                pygame.draw.line(icon, (*color, alpha), 
                                (16 + j + 2, y), (16 + width + 2, y))
    
    # 불꽃 효과
    flame_points = [(16, 4), (14, 7), (16, 5), (18, 7)]
    pygame.draw.polygon(icon, (255, 50, 0), flame_points)
    
    pygame.image.save(icon, "items/legendary/phoenix_feather.png")
    print("불사조의 깃털 아이콘 생성 완료")


def create_chronos_clock():
    """크로노스의 시계 아이콘 생성"""
    icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    
    # 시계 외곽 (황금색)
    pygame.draw.circle(icon, (200, 170, 0), (16, 16), 12)
    pygame.draw.circle(icon, (255, 215, 0), (16, 16), 11)
    pygame.draw.circle(icon, (50, 50, 50), (16, 16), 9)
    
    # 시계 숫자 (12, 3, 6, 9)
    font = pygame.font.Font(None, 8)
    numbers = [(16, 8, "12"), (23, 16, "3"), (16, 24, "6"), (9, 16, "9")]
    for x, y, num in numbers:
        text = font.render(num, True, (255, 255, 255))
        text_rect = text.get_rect(center=(x, y))
        icon.blit(text, text_rect)
    
    # 시계 바늘
    # 시침
    pygame.draw.line(icon, (255, 255, 255), (16, 16), (16, 11), 2)
    # 분침
    pygame.draw.line(icon, (255, 255, 255), (16, 16), (20, 13), 2)
    
    # 중앙 나사
    pygame.draw.circle(icon, (255, 215, 0), (16, 16), 2)
    
    # 시간 왜곡 효과 (소용돌이)
    for i in range(3):
        angle = i * 2 * math.pi / 3
        x = 16 + int(6 * math.cos(angle))
        y = 16 + int(6 * math.sin(angle))
        pygame.draw.circle(icon, (100, 100, 255, 100), (x, y), 2)
    
    pygame.image.save(icon, "items/legendary/chronos_clock.png")
    print("크로노스의 시계 아이콘 생성 완료")


def create_excalibur_blade():
    """엑스칼리버 아이콘 생성"""
    icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    
    # 검날 (은색)
    blade_points = [
        (16, 2),    # 끝
        (13, 18),   # 왼쪽
        (16, 16),   # 중앙
        (19, 18),   # 오른쪽
    ]
    pygame.draw.polygon(icon, (200, 200, 200), blade_points)
    pygame.draw.polygon(icon, (255, 255, 255), blade_points, 1)
    
    # 검날 중앙선 (빛나는 효과)
    pygame.draw.line(icon, (255, 255, 255), (16, 2), (16, 18), 1)
    
    # 가드 (황금색)
    pygame.draw.rect(icon, (200, 170, 0), (8, 18, 16, 3))
    pygame.draw.rect(icon, (255, 215, 0), (9, 19, 14, 1))
    
    # 손잡이 (갈색)
    pygame.draw.rect(icon, (100, 50, 0), (14, 21, 4, 8))
    pygame.draw.rect(icon, (150, 75, 0), (15, 21, 2, 8))
    
    # 포멜 (보석)
    pygame.draw.circle(icon, (200, 0, 0), (16, 29), 2)
    pygame.draw.circle(icon, (255, 100, 100), (16, 29), 1)
    
    # 신성한 빛 효과
    for i in range(4):
        angle = i * math.pi / 2
        x = 16 + int(10 * math.cos(angle))
        y = 10 + int(10 * math.sin(angle))
        pygame.draw.line(icon, (255, 255, 100, 50), (16, 10), (x, y), 1)
    
    pygame.image.save(icon, "items/legendary/excalibur_blade.png")
    print("엑스칼리버 아이콘 생성 완료")


def create_ragnarok_hammer():
    """라그나로크 해머 아이콘 생성"""
    icon = pygame.Surface((32, 32), pygame.SRCALPHA)
    
    # 해머 헤드 (망치 머리 부분) - 거대하고 묵직한 느낌
    hammer_head = pygame.Rect(4, 8, 24, 12)
    
    # 해머 그라데이션 (어두운 금속색)
    for i in range(12):
        color_val = 50 + i * 10
        pygame.draw.rect(icon, (color_val, color_val, color_val + 20), 
                        (4, 8 + i, 24, 1))
    
    # 해머 테두리 (밝은 금속)
    pygame.draw.rect(icon, (180, 180, 200), hammer_head, 2)
    
    # 룬 문자 (북유럽 스타일)
    rune_color = (100, 200, 255)  # 밝은 파란색
    # 가운데 룬
    pygame.draw.line(icon, rune_color, (16, 10), (16, 18), 2)
    pygame.draw.line(icon, rune_color, (12, 12), (16, 10), 1)
    pygame.draw.line(icon, rune_color, (20, 12), (16, 10), 1)
    
    # 손잡이 (나무 느낌)
    handle_color = (101, 67, 33)  # 갈색
    pygame.draw.rect(icon, handle_color, (14, 20, 4, 10))
    pygame.draw.rect(icon, (131, 87, 43), (15, 20, 2, 10))  # 하이라이트
    
    # 번개 효과 (망치 주변)
    lightning_color = (255, 255, 100)
    # 작은 번개들
    pygame.draw.line(icon, lightning_color, (2, 6), (4, 8), 1)
    pygame.draw.line(icon, lightning_color, (28, 8), (30, 6), 1)
    pygame.draw.line(icon, lightning_color, (4, 20), (2, 22), 1)
    pygame.draw.line(icon, lightning_color, (28, 20), (30, 22), 1)
    
    # 파워 오라 (주변 빛)
    for i in range(3):
        alpha = 100 - i * 30
        aura_surf = pygame.Surface((32, 32), pygame.SRCALPHA)
        pygame.draw.ellipse(aura_surf, (200, 100, 255, alpha), 
                           (8 - i*2, 12 - i*2, 16 + i*4, 8 + i*4))
        icon.blit(aura_surf, (0, 0))
    
    pygame.image.save(icon, "items/legendary/ragnarok_hammer.png")
    print("라그나로크 해머 아이콘 생성 완료")


# 모든 아이콘 생성
create_infinity_gauntlet()
create_phoenix_feather()
create_chronos_clock()
create_excalibur_blade()
create_ragnarok_hammer()

print("\n모든 전설 아이템 아이콘이 items/legendary/ 폴더에 생성되었습니다!")