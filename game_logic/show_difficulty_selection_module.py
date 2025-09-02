"""
show_difficulty_selection 함수 - bosspong.py에서 추출
"""

import pygame
import math
import random
import sys
import os

# bosspong.py의 경로를 sys.path에 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 게임 상수 임포트
from config.constants import WIDTH, HEIGHT

# 전역 screen 객체 가져오기
def get_screen():
    return pygame.display.get_surface() or pygame.display.set_mode((WIDTH, HEIGHT))

# 사운드 초기화
def init_sounds():
    sounds = {}
    try:
        sounds['SOUND_BUTTON_CLICK'] = pygame.mixer.Sound("sounds/button_click.wav")
        sounds['SOUND_BUTTON_HOVER'] = pygame.mixer.Sound("sounds/button_hover.wav")
    except (FileNotFoundError, pygame.error):
        # 사운드 파일이 없을 경우 더미 사운드 객체 생성
        class DummySound:
            def play(self): pass
            def set_volume(self, vol): pass
        sounds['SOUND_BUTTON_CLICK'] = DummySound()
        sounds['SOUND_BUTTON_HOVER'] = DummySound()
    return sounds

def show_difficulty_selection():
    """난이도 선택 화면 - 사이버펑크 스타일"""
    SCREEN = get_screen()
    sounds = init_sounds()
    SOUND_BUTTON_CLICK = sounds['SOUND_BUTTON_CLICK']
    SOUND_BUTTON_HOVER = sounds['SOUND_BUTTON_HOVER']
    clock = pygame.time.Clock()
    
    # 4단계 리그 시스템 (홀로그램 테마)
    difficulties = [
        {
            "id": "junior",
            "name": "주니어리그",
            "description": "게임의 기본을 익히는 초보자 리그\n편안한 속도로 기술을 연습할 수 있습니다",
            "ai_mode": "junior",
            "color": (100, 255, 100),
            "icon": "🌱",
            "details": [
                "• 느린 공 속도",
                "• AI 실수 빈번 (25%)",
                "• 넉넉한 반응시간",
                "• 기본기 연습에 최적",
                "⚡ 보스 능력치: 기본 (100%)",
                "🎯 목표 승률: 80%"
            ]
        },
        {
            "id": "pro",
            "name": "프로리그", 
            "description": "본격적인 경쟁이 시작되는 중급자 리그\n전략과 반응속도가 중요해집니다",
            "ai_mode": "pro",
            "color": (255, 200, 100),
            "icon": "⚡",
            "details": [
                "• 표준 공 속도",
                "• AI 적당한 실수 (15%)",
                "• 예측 가능한 패턴",
                "• 실력 향상에 좋음",
                "⚡ 보스 능력치: +5% (105%)",
                "🎯 목표 승률: 60%"
            ]
        },
        {
            "id": "champion",
            "name": "챔피언리그",
            "description": "실력자들만이 도전하는 상급자 리그\n빠른 판단력과 정확한 컨트롤이 필수입니다",
            "ai_mode": "champion",
            "color": (255, 150, 255),
            "icon": "💎",
            "details": [
                "• 빠른 공 속도", 
                "• AI 소수 실수 (8%)",
                "• 고도의 전략 필요",
                "• 챔피언급 도전",
                "⚡ 보스 능력치: +10% (110%)",
                "🎯 목표 승률: 35%"
            ]
        },
        {
            "id": "mythic",
            "name": "신화리그",
            "description": "오직 최강자만이 생존하는 전설의 리그\n인간의 한계를 시험하는 극한의 난이도입니다",
            "ai_mode": "mythic",
            "color": (255, 215, 0),
            "icon": "👑",
            "details": [
                "• 완벽한 예측 능력",
                "• AI 거의 무실수 (2%)",
                "• 미래 시뮬레이션 AI",
                "• 신화급 난이도",
                "⚡ 보스 능력치: +20% (120%)",
                "🎯 목표 승률: 10%",
                "⚠️ 극강 주의!"
            ]
        }
    ]
    
    selected = 0
    animation_timer = 0
    scroll_offset = 0
    glitch_timer = 0
    glitch_active = False
    
    # 사이버펑크 배경 효과용 변수들
    neon_particles = []
    for _ in range(50):  # 더 많은 네온 파티클
        neon_particles.append({
            "x": random.randint(0, WIDTH),
            "y": random.randint(0, HEIGHT),
            "vx": random.uniform(-1, 1),
            "vy": random.uniform(-1, 1),
            "size": random.randint(1, 3),
            "color": random.choice([(0, 255, 255), (255, 0, 255), (255, 255, 0)]),
            "alpha": random.randint(40, 100),
            "pulse_speed": random.uniform(0.05, 0.15)
        })
    
    # 스캔라인 효과
    scan_lines = []
    for i in range(5):  # 더 많은 스캔라인
        scan_lines.append({
            "y": random.randint(0, HEIGHT),
            "speed": random.uniform(2, 4),
            "alpha": random.randint(20, 40)
        })
    
    while True:
        animation_timer += 1
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    pass
                    return None  # 캐릭터 선택으로 돌아가기
                elif event.key in [pygame.K_UP, pygame.K_w]:
                    pass
                    # 2x2 그리드에서 위로 이동
                    current_row = selected // cards_per_row
                    current_col = selected % cards_per_row
                    new_row = (current_row - 1) % 2  # 2행에서 순환
                    selected = new_row * cards_per_row + current_col
                    if selected >= len(difficulties):  # 인덱스 범위 초과 시 조정
                        selected = (len(difficulties) - 1)
                    SOUND_BUTTON_HOVER.play()
                elif event.key in [pygame.K_DOWN, pygame.K_s]:
                    pass
                    # 2x2 그리드에서 아래로 이동
                    current_row = selected // cards_per_row
                    current_col = selected % cards_per_row
                    new_row = (current_row + 1) % 2  # 2행에서 순환
                    selected = new_row * cards_per_row + current_col
                    if selected >= len(difficulties):  # 인덱스 범위 초과 시 조정
                        selected = current_col if current_col < len(difficulties) else 0
                    SOUND_BUTTON_HOVER.play()
                elif event.key in [pygame.K_LEFT, pygame.K_a]:
                    pass
                    # 2x2 그리드에서 왼쪽으로 이동
                    current_row = selected // cards_per_row
                    current_col = selected % cards_per_row
                    new_col = (current_col - 1) % cards_per_row  # 2열에서 순환
                    selected = current_row * cards_per_row + new_col
                    if selected >= len(difficulties):  # 인덱스 범위 초과 시 조정
                        selected = current_row * cards_per_row + (new_col % len(difficulties))
                    SOUND_BUTTON_HOVER.play()
                elif event.key in [pygame.K_RIGHT, pygame.K_d]:
                    pass
                    # 2x2 그리드에서 오른쪽으로 이동
                    current_row = selected // cards_per_row
                    current_col = selected % cards_per_row
                    new_col = (current_col + 1) % cards_per_row  # 2열에서 순환
                    selected = current_row * cards_per_row + new_col
                    if selected >= len(difficulties):  # 인덱스 범위 초과 시 조정
                        selected = current_row * cards_per_row + (new_col % len(difficulties))
                    SOUND_BUTTON_HOVER.play()
                elif event.key in [pygame.K_SPACE, pygame.K_RETURN]:
                    SOUND_BUTTON_CLICK.play()
                    return difficulties[selected]["ai_mode"]
        
        # 사이버펑크 배경 그리기 (그라데이션)
        for y in range(HEIGHT):
            ratio = y / HEIGHT
            r = int(10 + ratio * 30)  # 더 밝은 빨강
            g = int(20 + ratio * 40)  # 더 밝은 초록
            b = int(40 + ratio * 60)  # 더 밝은 파랑
            color = (r, g, b)
            pygame.draw.line(SCREEN, color, (0, y), (WIDTH, y))
        
        # 홀로그램 격자 패턴
        grid_color = (0, 150, 200, 25)
        grid_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        for x in range(0, WIDTH, 30):
            pygame.draw.line(grid_surface, grid_color, (x, 0), (x, HEIGHT))
        for y in range(0, HEIGHT, 30):
            pygame.draw.line(grid_surface, grid_color, (0, y), (WIDTH, y))
        SCREEN.blit(grid_surface, (0, 0))
        
        # 디지털 매트릭스 효과 (최소화)
        try:
            font_matrix = pygame.font.Font(None, 10)
        except:
            font_matrix = pygame.font.Font(None, 10)
        
        # 정적 매트릭스 배경 (매우 절제)
        for i in range(3):  # 열 수 대폭 감소
            x = 100 + i * 200  # 넓은 간격
            y = 150 + (i % 2) * 100  # 엇갈린 배치
            if random.random() < 0.1:  # 10% 확률로만 표시
                char = random.choice(["0", "1"])
                char_surface = font_matrix.render(char, True, (0, 60, 80))
                char_surface.set_alpha(20)  # 매우 희미하게
                SCREEN.blit(char_surface, (x, y))
        
        # 글리치 효과
        glitch_timer += 1
        if random.randint(0, 300) == 0:
            glitch_active = True
        if glitch_timer > 10:
            glitch_active = False
            glitch_timer = 0
        
        # 폰트 설정
        try:
            font_title = pygame.font.Font("NanumSquareB.ttf", 36)  # 제목 폰트 크기 감소
            font_subtitle = pygame.font.Font("NanumSquareR.ttf", 18)
            font_desc = pygame.font.Font("NanumSquareR.ttf", 14)
            font_detail = pygame.font.Font("NanumSquareR.ttf", 12)  # 상세 폰트 크기 감소
        except:
            font_title = pygame.font.Font(None, 42)
            font_subtitle = pygame.font.Font(None, 20)
            font_desc = pygame.font.Font(None, 16)
            font_detail = pygame.font.Font(None, 14)
        
        # 홀로그램 스타일 제목
        title_main = "◆ DIFFICULTY MATRIX ◆"
        title_sub = ">> NEURAL CHALLENGE SELECTOR <<"
        
        # 글리치 효과 적용
        glitch_offset_x = 0
        glitch_offset_y = 0
        if glitch_active:
            glitch_offset_x = random.randint(-3, 3)
            glitch_offset_y = random.randint(-1, 1)
        
        # 네온 글로우 레이어들
        title_y = 50
        for i, (offset, color, alpha) in enumerate([(4, (0, 255, 255), 60), (2, (255, 0, 128), 120), (0, (255, 255, 255), 255)]):
            glow_text = font_title.render(title_main, True, (*color[:3], alpha))
            glow_rect = glow_text.get_rect(center=(WIDTH // 2 + offset + glitch_offset_x, title_y + glitch_offset_y))
            if alpha < 255:  # 글로우 레이어
                glow_surface = pygame.Surface(glow_text.get_size(), pygame.SRCALPHA)
                glow_surface.blit(glow_text, (0, 0))
                SCREEN.blit(glow_surface, glow_rect)
            else:  # 메인 텍스트
                SCREEN.blit(glow_text, glow_rect)
        
        # 서브 제목
        sub_text = font_desc.render(title_sub, True, (0, 255, 255))
        sub_rect = sub_text.get_rect(center=(WIDTH // 2, title_y + 35))
        SCREEN.blit(sub_text, sub_rect)
        
        # 타이핑 커서 효과
        if animation_timer % 60 < 30:
            cursor_surface = pygame.Surface((150, 2), pygame.SRCALPHA)
            pygame.draw.rect(cursor_surface, (0, 255, 255, 150), (0, 0, 150, 2))
            SCREEN.blit(cursor_surface, (WIDTH // 2 - 75, title_y + 45))
        
        # 네온 파티클 업데이트 및 그리기
        for particle in neon_particles:
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            
            # 화면 경계 처리
            if particle["x"] < 0 or particle["x"] > WIDTH:
                particle["vx"] *= -1
            if particle["y"] < 0 or particle["y"] > HEIGHT:
                particle["vy"] *= -1
            
            # 펄스 효과
            pulse = abs(math.sin(animation_timer * particle["pulse_speed"]))
            current_alpha = int(particle["alpha"] * (0.5 + pulse * 0.5))
            
            # 네온 글로우 파티클
            for i in range(2):
                glow_size = particle["size"] + i * 2
                glow_alpha = current_alpha // (i + 1)
                glow_surf = pygame.Surface((glow_size * 4, glow_size * 4), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*particle["color"], glow_alpha),
                                 (glow_size * 2, glow_size * 2), glow_size)
                SCREEN.blit(glow_surf, (particle["x"] - glow_size * 2, 
                                       particle["y"] - glow_size * 2))
        
        # 스캔라인 효과
        for scan_line in scan_lines:
            scan_line["y"] += scan_line["speed"]
            if scan_line["y"] > HEIGHT:
                scan_line["y"] = -10
            
            # 더 화려한 스캔라인
            for i in range(3):
                scan_alpha = scan_line["alpha"] - i * 10
                if scan_alpha > 0:
                    scan_surf = pygame.Surface((WIDTH, 2 - i), pygame.SRCALPHA)
                    scan_surf.fill((0, 255, 255, scan_alpha))
                    SCREEN.blit(scan_surf, (0, scan_line["y"] + i))
        
        # 홀로그램 난이도 카드들
        cards_per_row = 2  # 2x2 레이아웃
        card_width = 250  # 카드 너비 증가
        card_height = 170  # 카드 높이 증가
        card_margin = 40  # 마진 증가
        
        start_x = (WIDTH - (cards_per_row * card_width + (cards_per_row - 1) * card_margin)) // 2
        start_y = 120  # 시작 위치 약간 위로
        
        for i, difficulty in enumerate(difficulties):
            row = i // cards_per_row
            col = i % cards_per_row
            
            card_x = start_x + col * (card_width + card_margin)
            card_y = start_y + row * (card_height + card_margin + 20)  # 세로 간격 감소
            
            # 선택된 카드 효과 (다층 홀로그램 글로우)
            if i == selected:
                pass
                # 다층 네온 글로우
                for glow_layer in range(5, 0, -1):
                    glow_intensity = int(abs(math.sin(animation_timer * 0.15 + glow_layer * 0.5)) * 40) + 60
                    glow_size = glow_layer * 6
                    glow_surface = pygame.Surface((card_width + glow_size, card_height + glow_size), pygame.SRCALPHA)
                    
                    # 무지개빛 효과
                    if glow_layer % 2 == 0:
                        holo_angle = animation_timer * 0.1 + glow_layer
                        holo_r = int(128 + 127 * math.sin(holo_angle))
                        holo_g = int(128 + 127 * math.sin(holo_angle + 2.094))
                        holo_b = int(128 + 127 * math.sin(holo_angle + 4.189))
                        layer_color = (holo_r, holo_g, holo_b)
                    else:
                        layer_color = difficulty["color"]
                    
                    pygame.draw.rect(glow_surface, (*layer_color, glow_intensity // glow_layer),
                                   (0, 0, card_width + glow_size, card_height + glow_size), border_radius=20)
                    SCREEN.blit(glow_surface, (card_x - glow_size//2, card_y - glow_size//2))
                
                # 선택 테두리 (네온 스타일)
                draw.rect( difficulty["color"],
                               (card_x - 4, card_y - 4, card_width + 8, card_height + 8), 3, border_radius=15)
                # 내부 테두리
                draw.rect((*difficulty["color"], 100),
                               (card_x - 2, card_y - 2, card_width + 4, card_height + 4), 1, border_radius=13)
            
            # 홀로그램 카드 배경
            card_surface = pygame.Surface((card_width, card_height), pygame.SRCALPHA)
            
            # 어두운 배경과 회로 패턴
            if i == selected:
                card_surface.fill((10, 15, 25, 250))  # 더 진한 배경
                # 전자 회로 패턴 추가
                for _ in range(8):
                    node_x = random.randint(10, card_width - 10)
                    node_y = random.randint(10, card_height - 10)
                    pygame.draw.circle(card_surface, (*difficulty["color"], 30), (node_x, node_y), 1)
            else:
                card_surface.fill((15, 20, 30, 200))
            
            # 네온 테두리
            pygame.draw.rect(card_surface, (*difficulty["color"], 150), (0, 0, card_width, card_height), 2, border_radius=12)
            SCREEN.blit(card_surface, (card_x, card_y))
            
            # 리그 이름 표시 (선택된 카드만 이름 표시, 네온 효과)
            if i == selected:
                pass
                # 네온 글로우 텍스트
                for j in range(2, 0, -1):
                    name_glow = font_subtitle.render(difficulty['name'], True, (*difficulty["color"], 100 - j*30))
                    name_rect = name_glow.get_rect(center=(card_x + card_width//2, card_y + 30))
                    SCREEN.blit(name_glow, (name_rect.x - j, name_rect.y - j))
                    SCREEN.blit(name_glow, (name_rect.x + j, name_rect.y + j))
                
                name_text = font_subtitle.render(difficulty['name'], True, (255, 255, 255))
                name_rect = name_text.get_rect(center=(card_x + card_width//2, card_y + 30))
                SCREEN.blit(name_text, name_rect)
            
            # 리그별 엠블럼 그리기 (카드 중앙에 크고 화려하게)
            emblem_x = card_x + card_width // 2
            emblem_y = card_y + card_height // 2 + 10
            
            # 선택된 엠블럼은 회전 효과 적용
            rotation_angle = 0
            if i == selected:
                rotation_angle = (animation_timer * 2) % 360
            
            if difficulty["id"] == "junior":
                pass
                # 🌱 주니어리그 - 새싹 엠블럼
                # 회전 효과를 위한 스케일 계산
                scale_x = math.cos(math.radians(rotation_angle)) if i == selected else 1.0
                
                # 줄기
                draw.line((100, 200, 100), (emblem_x, emblem_y + 20), (emblem_x, emblem_y - 5), 3)
                # 잎사귀들 (회전 효과 적용)
                for j, (dx, dy, angle) in enumerate([(-15, -5, -30), (15, -5, 30), (-12, 5, -20), (12, 5, 20)]):
                    leaf_color = (50 + j*30, 255 - j*20, 50)
                    # 회전 효과 적용
                    rotated_dx = dx * scale_x
                    # 잎 본체
                    leaf_width = max(2, int(16 * abs(scale_x)))
                    draw.ellipse( leaf_color, (emblem_x + rotated_dx - leaf_width//2, emblem_y + dy - 4, leaf_width, 8))
                    if abs(scale_x) > 0.3:
                        draw.ellipse( (0, 150, 0), (emblem_x + rotated_dx - leaf_width//2, emblem_y + dy - 4, leaf_width, 8), 1)
                # 중심 새싹
                draw.circle((150, 255, 150), (emblem_x, emblem_y - 10), 8)
                draw.circle((100, 255, 100), (emblem_x, emblem_y - 10), 6)
                draw.circle((200, 255, 200), (emblem_x - 2, emblem_y - 12), 2)
                # 빛나는 효과
                for r in range(3):
                    alpha = 50 - r * 15
                    draw.circle( (150, 255, 150, alpha), (emblem_x, emblem_y - 10), 12 + r * 3, 1)
                    
            elif difficulty["id"] == "pro":
                pass
                # ⚡ 프로리그 - 번개 엠블럼
                # 회전 효과를 위한 스케일 계산
                scale_x = math.cos(math.radians(rotation_angle)) if i == selected else 1.0
                
                # 외곽 원 (회전 시 타원형으로)
                if abs(scale_x) > 0.1:
                    ellipse_width = int(50 * abs(scale_x))
                    ellipse_rect = (emblem_x - ellipse_width//2, emblem_y - 25, ellipse_width, 50)
                    draw.ellipse( (255, 200, 100), ellipse_rect, 2)
                
                # 번개 본체 (회전 효과 적용)
                lightning_points = [
                    (emblem_x - 8 * scale_x, emblem_y - 15),
                    (emblem_x + 3 * scale_x, emblem_y - 5),
                    (emblem_x - 3 * scale_x, emblem_y - 5),
                    (emblem_x + 8 * scale_x, emblem_y + 15),
                    (emblem_x - 2 * scale_x, emblem_y + 5),
                    (emblem_x + 4 * scale_x, emblem_y + 5)
                ]
                if abs(scale_x) > 0.2:
                    draw.lines((255, 100, 255, 1), False, lightning_points, 4)
                    draw.lines((255, 0, 200, 1), False, lightning_points, 2)
                # 전기 스파크 (회전과 무관하게 유지)
                for angle in range(0, 360, 60):
                    spark_angle = angle + rotation_angle if i == selected else angle
                    spark_x = emblem_x + 30 * math.cos(math.radians(spark_angle))
                    spark_y = emblem_y + 30 * math.sin(math.radians(spark_angle))
                    draw.line((255, 255, 150), (emblem_x, emblem_y), (spark_x, spark_y), 1)
                # 중심 광원
                draw.circle((255, 255, 200), (emblem_x, emblem_y), 5)
                
            elif difficulty["id"] == "champion":
                pass
                # 💎 챔피언리그 - 다이아몬드 엠블럼
                # 회전 효과를 위한 스케일 계산
                scale_x = math.cos(math.radians(rotation_angle)) if i == selected else 1.0
                
                # 다이아몬드 외형 (회전 효과 적용)
                diamond_points = [
                    (emblem_x, emblem_y - 25),  # 상단
                    (emblem_x + 20 * scale_x, emblem_y - 5),  # 우상
                    (emblem_x + 15 * scale_x, emblem_y + 5),  # 우중
                    (emblem_x, emblem_y + 20),  # 하단
                    (emblem_x - 15 * scale_x, emblem_y + 5),  # 좌중
                    (emblem_x - 20 * scale_x, emblem_y - 5),  # 좌상
                ]
                # 그라데이션 효과를 위한 여러 층
                colors = [(255, 150, 255), (255, 100, 255), (200, 50, 200)]
                for j, color in enumerate(colors):
                    scaled_points = []
                    scale = 1.0 - j * 0.2
                    for px, py in diamond_points:
                        scaled_x = emblem_x + (px - emblem_x) * scale
                        scaled_y = emblem_y + (py - emblem_y) * scale
                        scaled_points.append((scaled_x, scaled_y))
                    if abs(scale_x) > 0.1:
                        draw.polygon(color, scaled_points)
                # 반짝임 효과
                if abs(scale_x, 0) > 0.2:
                    draw.lines((255, 255, 255, 1), True, diamond_points, 2)
                # 중심 빛
                draw.circle((255, 200, 255), (emblem_x, emblem_y), 3)
                # 광채 효과 (회전과 무관하게 유지)
                for angle in range(45, 360, 90):
                    ray_angle = angle + rotation_angle if i == selected else angle
                    ray_x = emblem_x + 35 * math.cos(math.radians(ray_angle))
                    ray_y = emblem_y + 35 * math.sin(math.radians(ray_angle))
                    draw.line((255, 200, 255, 100), (emblem_x, emblem_y), (ray_x, ray_y), 1)
                    
            elif difficulty["id"] == "mythic":
                pass
                # 👑 신화리그 - 왕관 엠블럼
                # 회전 효과를 위한 스케일 계산
                scale_x = math.cos(math.radians(rotation_angle)) if i == selected else 1.0
                
                # 왕관 베이스 (회전 효과 적용)
                crown_base = [(emblem_x - 25 * scale_x, emblem_y + 10), (emblem_x + 25 * scale_x, emblem_y + 10)]
                if abs(scale_x) > 0.2:
                    draw.line((255, 215, 0), crown_base[0], crown_base[1], 3)
                
                # 왕관 봉우리들 (회전 효과 적용)
                peaks = [
                    (emblem_x - 20 * scale_x, emblem_y - 15, 12),  # 왼쪽
                    (emblem_x - 10 * scale_x, emblem_y - 10, 10),
                    (emblem_x, emblem_y - 20, 15),  # 중앙 (가장 높음)
                    (emblem_x + 10 * scale_x, emblem_y - 10, 10),
                    (emblem_x + 20 * scale_x, emblem_y - 15, 12),  # 오른쪽
                ]
                # 왕관 본체
                if abs(scale_x) > 0.2:
                    for j, (px, py, height) in enumerate(peaks):
                        # 봉우리 그리기
                        draw.lines((255, 0, 215, 1), False, 
                                        [(px - 5 * abs(scale_x), emblem_y + 10), (px, py), (px + 5 * abs(scale_x), emblem_y + 10)], 3)
                        # 보석
                        gem_colors = [(255, 50, 50), (50, 255, 50), (255, 255, 255), (50, 50, 255), (255, 50, 50)]
                        draw.circle(gem_colors[j], (px, py + 5), 3)
                        if scale_x > 0:
                            draw.circle((255, 255, 255), (px - 1, py + 4), 1)
                # 중앙 큰 보석
                draw.circle((255, 100, 255), (emblem_x, emblem_y), 5)
                draw.circle((255, 200, 255), (emblem_x, emblem_y), 3)
                draw.circle((255, 255, 255), (emblem_x - 1, emblem_y - 1), 1)
                # 황금빛 후광
                for r in range(3):
                    draw.circle( (255, 215, 0, 30 - r*10), (emblem_x, emblem_y), 30 + r*5, 1)
        
        # 선택된 난이도 상세 정보
        if selected < len(difficulties):
            pass
            # 상세 정보 박스를 카드 아래쪽에 배치
            detail_y = start_y + 2 * (card_height + card_margin + 20) + 10  # 두 번째 줄 카드 아래
            
            selected_diff = difficulties[selected]
            
            # 홀로그램 상세 정보 패널
            detail_width = 520
            detail_height = 100
            detail_x = (WIDTH - detail_width) // 2
            
            # 다층 글로우 배경
            for j in range(3, 0, -1):
                glow_surface = pygame.Surface((detail_width + j*10, detail_height + j*10), pygame.SRCALPHA)
                glow_alpha = 30 - j*8
                pygame.draw.rect(glow_surface, (*selected_diff["color"], glow_alpha), 
                               (0, 0, detail_width + j*10, detail_height + j*10), 
                               border_radius=15)
                SCREEN.blit(glow_surface, (detail_x - j*5, detail_y - j*5))
            
            # 메인 패널
            detail_surface = pygame.Surface((detail_width, detail_height), pygame.SRCALPHA)
            detail_surface.fill((10, 15, 25, 220))
            pygame.draw.rect(detail_surface, selected_diff["color"], 
                           (0, 0, detail_width, detail_height), 2, border_radius=12)
            
            # 내부 회로 패턴
            for j in range(5):
                node_x = random.randint(10, detail_width - 10)
                node_y = random.randint(10, detail_height - 10)
                pygame.draw.circle(detail_surface, (*selected_diff["color"], 40), (node_x, node_y), 2)
            
            SCREEN.blit(detail_surface, (detail_x, detail_y))
            
            # 상세 제목 제거 (스크린샷처럼 내용만 표시)
            
            # 챔피언리그 텍스트만 표시 (스크린샷처럼)
            if selected_diff['id'] == 'champion':
                pass
                # 챔피언리그 - 상세 정보 텍스트 (가운데 정렬)
                champion_text1 = font_subtitle.render(f"{selected_diff['icon']} {selected_diff['name']} - 상세 정보", True, (255, 255, 255))
                champion_rect1 = champion_text1.get_rect(center=(detail_x + detail_width//2, detail_y + 25))
                SCREEN.blit(champion_text1, champion_rect1)
                
                # 공 속도와 AI 실수 텍스트 (가운데 정렬)
                champion_text2 = font_detail.render("빠른 공 속도", True, (200, 200, 200))
                champion_rect2 = champion_text2.get_rect(center=(detail_x + detail_width//2, detail_y + 45))
                SCREEN.blit(champion_text2, champion_rect2)
                
                champion_text3 = font_detail.render("AI 소수 실수 (8%)", True, (200, 200, 200))
                champion_rect3 = champion_text3.get_rect(center=(detail_x + detail_width//2, detail_y + 65))
                SCREEN.blit(champion_text3, champion_rect3)
            else:
                pass
                # 다른 리그들은 기존 설명 표시 (가운데 정렬)
                # 제목
                title_text = font_subtitle.render(f"{selected_diff['icon']} {selected_diff['name']} - 상세 정보", True, (255, 255, 255))
                title_rect = title_text.get_rect(center=(detail_x + detail_width//2, detail_y + 25))
                SCREEN.blit(title_text, title_rect)
                
                # 설명
                desc_lines = selected_diff["description"].split('\n')
                for i, desc_line in enumerate(desc_lines[:2]):
                    desc_text = font_detail.render(desc_line, True, (200, 200, 200))
                    desc_rect = desc_text.get_rect(center=(detail_x + detail_width//2, detail_y + 45 + i * 20))
                    SCREEN.blit(desc_text, desc_rect)
        
        # 홀로그램 스타일 조작 안내
        controls_y = HEIGHT - 35
        control_text = "↑↓←→ : Navigate    SPACE : Launch    ESC : Back"
        
        # 네온 텍스트 효과
        control_surface = font_desc.render(control_text, True, (0, 255, 255))
        control_rect = control_surface.get_rect(center=(WIDTH // 2, controls_y))
        SCREEN.blit(control_surface, control_rect)
        
        # 하단 스캔라인
        scan_y = HEIGHT - 20
        scan_alpha = int(abs(math.sin(animation_timer * 0.1)) * 100) + 50
        draw.line( (0, 255, 255, scan_alpha), (50, scan_y), (WIDTH - 50, scan_y), 1)
        
        pygame.display.flip()
        clock.tick(60)

