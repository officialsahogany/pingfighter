import pygame
import math
import random

# 초기화
pygame.init()

# 화면 설정
WIDTH = 600
HEIGHT = 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Stage 6 - 세기말 사이버펑크 우주전함 해상 기지")

def create_stage6_epic_background():
    """Stage 6 세기말 사이버펑크 우주전함 바다 배경 생성"""
    background = pygame.Surface((WIDTH, HEIGHT))
    
    # 1. 베이스 - 어두운 바다 그라데이션 (위: 어두운 하늘, 아래: 깊은 바다)
    for y in range(HEIGHT):
        ratio = y / HEIGHT
        # 위쪽은 어두운 보라빛 하늘, 아래쪽은 깊은 바다
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
        # 수직 구조물
        pygame.draw.rect(background, (35, 35, 45), 
                        (ship_x + offset - 5, ship_y - 20, 10, 30))
        # 네온 라이트
        pygame.draw.circle(background, (255, 0, 100), 
                         (ship_x + offset, ship_y - 25), 3)
    
    # 엔진 글로우
    for offset in [-120, -80, 80, 120]:
        # 엔진 추진 효과
        for i in range(5):
            alpha = 100 - i * 20
            color = (100 - i*20, 150 - i*30, 255 - i*40)
            pygame.draw.circle(background, color, 
                             (ship_x + offset, ship_y + 65 + i*3), 8 - i)
    
    # 3. 수평선과 바다 효과
    horizon_y = HEIGHT // 3
    
    # 수평선
    pygame.draw.line(background, (50, 100, 150), (0, horizon_y), (WIDTH, horizon_y), 2)
    
    # 파도 효과 (여러 레이어)
    wave_colors = [(20, 60, 100), (15, 50, 90), (10, 40, 80)]
    for layer, color in enumerate(wave_colors):
        for x in range(WIDTH):
            wave_y = horizon_y + 50 + layer * 30
            wave_height = math.sin(x * 0.02 + layer) * 10
            pygame.draw.circle(background, color, 
                             (x, int(wave_y + wave_height)), 2)
    
    # 4. 중앙 경기장 조명 (수면 반사 포함)
    center_x = WIDTH // 2
    center_y = HEIGHT // 2
    
    # 홀로그램 경기장 프레임
    # 외곽 육각형
    hex_points = []
    for i in range(6):
        angle = math.radians(60 * i + 30)
        px = center_x + 140 * math.cos(angle)
        py = center_y + 100 * math.sin(angle)
        hex_points.append((px, py))
    
    # 홀로그램 글로우 효과
    for i in range(3):
        alpha = 80 - i * 25
        size_mult = 1 + i * 0.1
        temp_points = []
        for point in hex_points:
            tx = center_x + (point[0] - center_x) * size_mult
            ty = center_y + (point[1] - center_y) * size_mult
            temp_points.append((tx, ty))
        
        # 육각형 그리기
        for j in range(len(temp_points)):
            next_j = (j + 1) % len(temp_points)
            pygame.draw.line(background, (0, 200 - i*50, 255 - i*50), 
                           temp_points[j], temp_points[next_j], 3 - i)
    
    # 중앙 서클
    pygame.draw.circle(background, (0, 150, 200), (center_x, center_y), 100, 3)
    pygame.draw.circle(background, (0, 100, 150), (center_x, center_y), 70, 2)
    pygame.draw.circle(background, (0, 80, 120), (center_x, center_y), 40, 2)
    
    # 중앙 코어
    pygame.draw.circle(background, (0, 255, 255), (center_x, center_y), 10)
    pygame.draw.circle(background, (255, 255, 255), (center_x, center_y), 5)
    
    # 5. 수면 반사 효과
    # 경기장 빛 반사
    for i in range(20):
        reflect_y = center_y + 150 + i * 5
        if reflect_y < HEIGHT:
            alpha = 100 - i * 5
            width = 150 - i * 5
            if width > 0:
                pygame.draw.ellipse(background, (0, 50 + i*2, 100 - i*3), 
                                  (center_x - width//2, reflect_y, width, 10), 1)
    
    # 6. 부유 잔해물 (세기말 분위기)
    debris_positions = [
        (100, 450), (500, 480), (150, 550), (450, 600), (250, 650)
    ]
    for pos in debris_positions:
        # 잔해 본체
        debris_size = random.randint(15, 25)
        pygame.draw.rect(background, (40, 35, 30), 
                       (pos[0] - debris_size//2, pos[1] - debris_size//2, 
                        debris_size, debris_size//2))
        # 녹슨 효과
        for _ in range(3):
            rust_x = pos[0] + random.randint(-10, 10)
            rust_y = pos[1] + random.randint(-5, 5)
            pygame.draw.circle(background, (80, 40, 20), (rust_x, rust_y), 2)
    
    # 7. 네온 부표 (경기장 경계 표시)
    buoy_positions = [
        (100, 350), (WIDTH - 100, 350),
        (80, 500), (WIDTH - 80, 500),
        (100, 650), (WIDTH - 100, 650)
    ]
    
    for pos in buoy_positions:
        # 부표 본체
        pygame.draw.circle(background, (60, 60, 70), pos, 8)
        pygame.draw.circle(background, (150, 150, 160), pos, 8, 2)
        # 네온 라이트
        if random.random() > 0.3:  # 일부는 깜빡임
            pygame.draw.circle(background, (255, 0, 0), pos, 5)
            pygame.draw.circle(background, (255, 100, 100), pos, 3)
    
    # 8. 대기 중 떠다니는 드론들
    drone_positions = [
        (150, 200), (450, 180), (100, 250), (500, 240)
    ]
    for pos in drone_positions:
        # 드론 본체
        pygame.draw.rect(background, (70, 70, 80), 
                       (pos[0] - 8, pos[1] - 4, 16, 8))
        # 프로펠러
        for offset in [-10, 10]:
            pygame.draw.circle(background, (100, 100, 110), 
                             (pos[0] + offset, pos[1]), 3, 1)
        # 서치라이트
        light_points = [
            pos,
            (pos[0] - 15, pos[1] + 30),
            (pos[0] + 15, pos[1] + 30)
        ]
        light_surf = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        pygame.draw.polygon(light_surf, (255, 255, 100, 30), light_points)
        background.blit(light_surf, (0, 0))
    
    # 9. 비 효과 (세기말 분위기)
    for _ in range(50):
        rain_x = random.randint(0, WIDTH)
        rain_y = random.randint(0, HEIGHT)
        rain_length = random.randint(10, 20)
        pygame.draw.line(background, (30, 40, 50), 
                       (rain_x, rain_y), 
                       (rain_x - 2, rain_y + rain_length), 1)
    
    # 10. 경고 표시 (위험 구역)
    warning_font = pygame.font.Font(None, 20)
    warning_texts = [
        ("DANGER ZONE", (50, HEIGHT - 50)),
        ("RESTRICTED", (WIDTH - 120, HEIGHT - 50))
    ]
    
    for text, pos in warning_texts:
        # 배경 박스
        text_surf = warning_font.render(text, True, (255, 50, 50))
        text_rect = text_surf.get_rect()
        text_rect.topleft = pos
        pygame.draw.rect(background, (50, 0, 0), text_rect.inflate(10, 5))
        pygame.draw.rect(background, (255, 50, 50), text_rect.inflate(10, 5), 2)
        background.blit(text_surf, pos)
    
    # 11. 스캔라인 효과 (구형 모니터 느낌)
    for y in range(0, HEIGHT, 4):
        pygame.draw.line(background, (0, 0, 0, 50), (0, y), (WIDTH, y), 1)
    
    return background

def main():
    """메인 실행 함수"""
    clock = pygame.time.Clock()
    running = True
    
    # Stage 6 배경 생성
    stage6_bg = create_stage6_epic_background()
    
    # 애니메이션 변수
    animation_timer = 0
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_s:
                    # S키를 누르면 이미지 저장
                    pygame.image.save(stage6_bg, "stage6_field.png")
                    print("Stage 6 배경이 'stage6_field.png'로 저장되었습니다!")
        
        # 배경 그리기
        screen.blit(stage6_bg, (0, 0))
        
        # 애니메이션 효과
        animation_timer += 1
        
        # 홀로그램 펄스 효과
        if animation_timer % 60 < 30:
            pulse_alpha = (animation_timer % 30) * 3
            pulse_surf = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
            pygame.draw.circle(pulse_surf, (0, 200, 255, pulse_alpha), 
                             (WIDTH // 2, HEIGHT // 2), 105, 5)
            screen.blit(pulse_surf, (0, 0))
        
        # 우주전함 엔진 불꽃 애니메이션
        if animation_timer % 10 == 0:
            for offset in [-120, -80, 80, 120]:
                flame_surf = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
                flame_y = 185 + random.randint(-5, 5)
                flame_size = random.randint(5, 10)
                pygame.draw.circle(flame_surf, (100, 150, 255, 150), 
                                 (WIDTH // 2 + offset, flame_y), flame_size)
                screen.blit(flame_surf, (0, 0))
        
        # 화면 업데이트
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()

if __name__ == "__main__":
    main()
    print("\n=== Stage 6 세기말 사이버펑크 우주전함 해상 기지 ===")
    print("🚢 거대 우주전함 실루엣")
    print("🌊 어두운 바다와 파도 효과")
    print("⬡ 홀로그램 육각형 경기장")
    print("💡 네온 부표와 경고 표시")
    print("🚁 순찰 드론과 서치라이트")
    print("☔ 비 효과와 부유 잔해")
    print("📺 스캔라인 레트로 효과")
    print("\n실행 후 'S'키를 눌러 이미지를 저장하세요!")