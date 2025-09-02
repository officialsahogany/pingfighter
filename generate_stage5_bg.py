import pygame
import math
import random
import sys

# 초기화
pygame.init()

# 화면 설정
WIDTH = 600
HEIGHT = 750

def create_stage5_background():
    """Stage 5 중국 전통 컨셉 배경 생성"""
    background = pygame.Surface((WIDTH, HEIGHT))
    
    # 1. 그라데이션 배경 (어두운 붉은색 -> 검은색)
    for y in range(HEIGHT):
        ratio = y / HEIGHT
        # 위쪽은 어두운 붉은색, 아래쪽은 검은색
        r = int(80 * (1 - ratio))
        g = int(10 * (1 - ratio))
        b = int(5 * (1 - ratio))
        pygame.draw.line(background, (r, g, b), (0, y), (WIDTH, y))
    
    # 2. 중국 전통 문양 패턴 (육각형 창살 문양)
    pattern_color = (120, 20, 10, 80)
    for x in range(0, WIDTH + 60, 60):
        for y in range(0, HEIGHT + 52, 52):
            # 육각형 그리기
            points = []
            for i in range(6):
                angle = math.radians(60 * i)
                px = x + 25 * math.cos(angle)
                py = y + 25 * math.sin(angle)
                points.append((px, py))
            if points:
                # 테두리만 그리기
                for i in range(len(points)):
                    next_i = (i + 1) % len(points)
                    pygame.draw.line(background, (100, 15, 10), points[i], points[next_i], 1)
    
    # 3. 중앙 스타디움 원형 라인 (센터 서클)
    center_x = WIDTH // 2
    center_y = HEIGHT // 2
    
    # 바깥쪽 큰 원
    pygame.draw.circle(background, (200, 30, 20), (center_x, center_y), 120, 3)
    
    # 중간 원
    pygame.draw.circle(background, (180, 25, 15), (center_x, center_y), 80, 2)
    
    # 안쪽 작은 원
    pygame.draw.circle(background, (160, 20, 10), (center_x, center_y), 40, 2)
    
    # 중앙 점
    pygame.draw.circle(background, (255, 50, 30), (center_x, center_y), 8)
    pygame.draw.circle(background, (255, 100, 50), (center_x, center_y), 5)
    
    # 4. 수평 중앙선
    pygame.draw.line(background, (200, 30, 20), (0, center_y), (WIDTH, center_y), 3)
    
    # 5. 상단과 하단 목표 구역 (반원)
    # 상단 반원
    pygame.draw.arc(background, (200, 30, 20), 
                   (center_x - 80, -40, 160, 80), 0, math.pi, 3)
    
    # 하단 반원
    pygame.draw.arc(background, (200, 30, 20), 
                   (center_x - 80, HEIGHT - 40, 160, 80), math.pi, 2 * math.pi, 3)
    
    # 6. 중국 전통 장식 - 용 문양 힌트 (간단한 곡선)
    # 왼쪽 용 문양
    for i in range(3):
        y_offset = 150 + i * 200
        pygame.draw.arc(background, (150, 25, 15),
                       (30, y_offset, 80, 60), math.pi/2, 3*math.pi/2, 2)
        pygame.draw.arc(background, (150, 25, 15),
                       (30, y_offset + 30, 80, 60), -math.pi/2, math.pi/2, 2)
    
    # 오른쪽 용 문양
    for i in range(3):
        y_offset = 150 + i * 200
        pygame.draw.arc(background, (150, 25, 15),
                       (WIDTH - 110, y_offset, 80, 60), -math.pi/2, math.pi/2, 2)
        pygame.draw.arc(background, (150, 25, 15),
                       (WIDTH - 110, y_offset + 30, 80, 60), math.pi/2, 3*math.pi/2, 2)
    
    # 7. 중국 전통 등불 효과 (글로우)
    lantern_positions = [
        (100, 100), (WIDTH - 100, 100),
        (100, HEIGHT - 100), (WIDTH - 100, HEIGHT - 100),
        (50, center_y), (WIDTH - 50, center_y)
    ]
    
    for pos in lantern_positions:
        # 등불 글로우 효과
        for radius in range(40, 10, -5):
            alpha = 20 + (40 - radius)
            color = (255, 80 - radius, 30 - radius//2)
            pygame.draw.circle(background, color, pos, radius)
        # 등불 중심
        pygame.draw.circle(background, (255, 150, 50), pos, 10)
        pygame.draw.circle(background, (255, 200, 100), pos, 6)
    
    # 8. 사각 코너 장식 (중국 전통 테두리)
    corner_size = 60
    corner_color = (180, 30, 20)
    corner_width = 3
    
    # 왼쪽 상단
    pygame.draw.lines(background, corner_color, False, 
                     [(0, corner_size), (0, 0), (corner_size, 0)], corner_width)
    pygame.draw.lines(background, corner_color, False,
                     [(10, corner_size-10), (10, 10), (corner_size-10, 10)], 2)
    
    # 오른쪽 상단
    pygame.draw.lines(background, corner_color, False,
                     [(WIDTH - corner_size, 0), (WIDTH, 0), (WIDTH, corner_size)], corner_width)
    pygame.draw.lines(background, corner_color, False,
                     [(WIDTH - corner_size + 10, 10), (WIDTH - 10, 10), (WIDTH - 10, corner_size - 10)], 2)
    
    # 왼쪽 하단
    pygame.draw.lines(background, corner_color, False,
                     [(0, HEIGHT - corner_size), (0, HEIGHT), (corner_size, HEIGHT)], corner_width)
    pygame.draw.lines(background, corner_color, False,
                     [(10, HEIGHT - corner_size + 10), (10, HEIGHT - 10), (corner_size - 10, HEIGHT - 10)], 2)
    
    # 오른쪽 하단
    pygame.draw.lines(background, corner_color, False,
                     [(WIDTH - corner_size, HEIGHT), (WIDTH, HEIGHT), (WIDTH, HEIGHT - corner_size)], corner_width)
    pygame.draw.lines(background, corner_color, False,
                     [(WIDTH - corner_size + 10, HEIGHT - 10), (WIDTH - 10, HEIGHT - 10), (WIDTH - 10, HEIGHT - corner_size + 10)], 2)
    
    # 9. 불꽃 파티클 효과 (화염 분위기)
    for _ in range(20):
        x = random.randint(50, WIDTH - 50)
        y = random.randint(HEIGHT // 2, HEIGHT - 50)
        size = random.randint(3, 8)
        
        # 불꽃 그라데이션
        for i in range(size, 0, -1):
            alpha = 150 - (size - i) * 20
            if i == size:
                color = (255, 100, 0)
            elif i > size // 2:
                color = (255, 150, 50)
            else:
                color = (255, 200, 100)
            pygame.draw.circle(background, color, (x, y - i*2), i)
    
    return background

# 배경 생성
print("Stage 5 배경 생성 중...")
stage5_bg = create_stage5_background()

# 이미지 저장
pygame.image.save(stage5_bg, "stage5_field.png")
print("✅ Stage 5 배경이 'stage5_field.png'로 저장되었습니다!")

print("\n=== Stage 5 중국 전통 스타디움 맵 특징 ===")
print("🏟️ 중앙 스타디움 원형 라인")
print("🏮 중국 전통 육각 문양 패턴")
print("🔥 붉은색 테마 (홍련 컨셉)")
print("✨ 전통 등불 글로우 효과")
print("🎨 모서리 중국식 장식")
print("🐉 용 문양 힌트")

pygame.quit()
sys.exit()