import pygame
import math
import random
import sys

# 초기화
pygame.init()

# 화면 설정
WIDTH = 600
HEIGHT = 750

def create_stage6_epic_background():
    """Stage 6 세기말 사이버펑크 우주전함 바다 배경 생성"""
    background = pygame.Surface((WIDTH, HEIGHT))
    
    # 1. 베이스 - 어두운 바다 그라데이션
    for y in range(HEIGHT):
        ratio = y / HEIGHT
        if y < HEIGHT // 3:
            # 하늘 부분 - 보라빛 어둠
            sky_ratio = y / (HEIGHT // 3)
            r = int(20 + sky_ratio * 10)
            g = int(10 + sky_ratio * 20)
            b = int(40 + sky_ratio * 40)
        else:
            # 바다 부분 - 깊은 청록색
            sea_ratio = (y - HEIGHT // 3) / (HEIGHT * 2 // 3)
            r = int(10 + sea_ratio * 5)
            g = int(30 - sea_ratio * 10)
            b = int(80 - sea_ratio * 30)
        pygame.draw.line(background, (r, g, b), (0, y), (WIDTH, y))
    
    # 2. 우주전함 실루엣 (상단 중앙)
    ship_x = WIDTH // 2
    ship_y = 120
    
    # 메인 선체
    ship_points = [
        (ship_x - 150, ship_y),
        (ship_x - 180, ship_y + 30),
        (ship_x - 170, ship_y + 60),
        (ship_x + 170, ship_y + 60),
        (ship_x + 180, ship_y + 30),
        (ship_x + 150, ship_y)
    ]
    pygame.draw.polygon(background, (30, 30, 40), ship_points)
    pygame.draw.polygon(background, (0, 150, 200), ship_points, 2)
    
    # 함교 구조물
    bridge_rect = pygame.Rect(ship_x - 40, ship_y - 30, 80, 40)
    pygame.draw.rect(background, (40, 40, 50), bridge_rect)
    pygame.draw.rect(background, (0, 200, 255), bridge_rect, 2)
    
    # 안테나와 무기 시스템
    for offset in [-100, -50, 50, 100]:
        pygame.draw.rect(background, (35, 35, 45), 
                        (ship_x + offset - 5, ship_y - 20, 10, 30))
        pygame.draw.circle(background, (255, 0, 100), 
                         (ship_x + offset, ship_y - 25), 3)
    
    # 엔진 글로우
    for offset in [-120, -80, 80, 120]:
        for i in range(5):
            color = (100 - i*20, 150 - i*30, 255 - i*40)
            pygame.draw.circle(background, color, 
                             (ship_x + offset, ship_y + 65 + i*3), 8 - i)
    
    # 3. 수평선과 파도
    horizon_y = HEIGHT // 3
    pygame.draw.line(background, (50, 100, 150), (0, horizon_y), (WIDTH, horizon_y), 2)
    
    wave_colors = [(20, 60, 100), (15, 50, 90), (10, 40, 80)]
    for layer, color in enumerate(wave_colors):
        for x in range(WIDTH):
            wave_y = horizon_y + 50 + layer * 30
            wave_height = math.sin(x * 0.02 + layer) * 10
            pygame.draw.circle(background, color, 
                             (x, int(wave_y + wave_height)), 2)
    
    # 4. 중앙 홀로그램 경기장
    center_x = WIDTH // 2
    center_y = HEIGHT // 2
    
    # 육각형 프레임
    hex_points = []
    for i in range(6):
        angle = math.radians(60 * i + 30)
        px = center_x + 140 * math.cos(angle)
        py = center_y + 100 * math.sin(angle)
        hex_points.append((px, py))
    
    for i in range(3):
        size_mult = 1 + i * 0.1
        temp_points = []
        for point in hex_points:
            tx = center_x + (point[0] - center_x) * size_mult
            ty = center_y + (point[1] - center_y) * size_mult
            temp_points.append((tx, ty))
        
        for j in range(len(temp_points)):
            next_j = (j + 1) % len(temp_points)
            pygame.draw.line(background, (0, 200 - i*50, 255 - i*50), 
                           temp_points[j], temp_points[next_j], 3 - i)
    
    # 중앙 서클
    pygame.draw.circle(background, (0, 150, 200), (center_x, center_y), 100, 3)
    pygame.draw.circle(background, (0, 100, 150), (center_x, center_y), 70, 2)
    pygame.draw.circle(background, (0, 80, 120), (center_x, center_y), 40, 2)
    pygame.draw.circle(background, (0, 255, 255), (center_x, center_y), 10)
    pygame.draw.circle(background, (255, 255, 255), (center_x, center_y), 5)
    
    # 5. 수면 반사
    for i in range(20):
        reflect_y = center_y + 150 + i * 5
        if reflect_y < HEIGHT:
            width = 150 - i * 5
            if width > 0:
                pygame.draw.ellipse(background, (0, 50 + i*2, 100 - i*3), 
                                  (center_x - width//2, reflect_y, width, 10), 1)
    
    # 6. 부유 잔해물
    debris_positions = [
        (100, 450), (500, 480), (150, 550), (450, 600), (250, 650)
    ]
    for pos in debris_positions:
        debris_size = random.randint(15, 25)
        pygame.draw.rect(background, (40, 35, 30), 
                       (pos[0] - debris_size//2, pos[1] - debris_size//2, 
                        debris_size, debris_size//2))
        for _ in range(3):
            rust_x = pos[0] + random.randint(-10, 10)
            rust_y = pos[1] + random.randint(-5, 5)
            pygame.draw.circle(background, (80, 40, 20), (rust_x, rust_y), 2)
    
    # 7. 네온 부표
    buoy_positions = [
        (100, 350), (WIDTH - 100, 350),
        (80, 500), (WIDTH - 80, 500),
        (100, 650), (WIDTH - 100, 650)
    ]
    
    for pos in buoy_positions:
        pygame.draw.circle(background, (60, 60, 70), pos, 8)
        pygame.draw.circle(background, (150, 150, 160), pos, 8, 2)
        if random.random() > 0.3:
            pygame.draw.circle(background, (255, 0, 0), pos, 5)
            pygame.draw.circle(background, (255, 100, 100), pos, 3)
    
    # 8. 드론들
    drone_positions = [
        (150, 200), (450, 180), (100, 250), (500, 240)
    ]
    for pos in drone_positions:
        pygame.draw.rect(background, (70, 70, 80), 
                       (pos[0] - 8, pos[1] - 4, 16, 8))
        for offset in [-10, 10]:
            pygame.draw.circle(background, (100, 100, 110), 
                             (pos[0] + offset, pos[1]), 3, 1)
    
    # 9. 비 효과
    for _ in range(50):
        rain_x = random.randint(0, WIDTH)
        rain_y = random.randint(0, HEIGHT)
        rain_length = random.randint(10, 20)
        pygame.draw.line(background, (30, 40, 50), 
                       (rain_x, rain_y), 
                       (rain_x - 2, rain_y + rain_length), 1)
    
    # 10. 스캔라인
    for y in range(0, HEIGHT, 4):
        pygame.draw.line(background, (0, 0, 0, 50), (0, y), (WIDTH, y), 1)
    
    return background

# 배경 생성
print("Stage 6 세기말 배경 생성 중...")
stage6_bg = create_stage6_epic_background()

# 이미지 저장
pygame.image.save(stage6_bg, "stage6_field.png")
print("✅ Stage 6 배경이 'stage6_field.png'로 저장되었습니다!")

print("\n=== Stage 6 세기말 사이버펑크 우주전함 해상 기지 ===")
print("🚢 거대 우주전함 실루엣")
print("🌊 어두운 바다와 파도 효과")
print("⬡ 홀로그램 육각형 경기장")
print("💡 네온 부표와 경고 표시")
print("🚁 순찰 드론")
print("☔ 비 효과와 부유 잔해")
print("📺 스캔라인 레트로 효과")

pygame.quit()
sys.exit()