"""
show_start_screen 함수 - bosspong.py에서 추출
"""

import pygame
import math
import random
import items
import academy
from ui.menu_system import MenuSystem
from game_logic.show_character_selection_module import show_character_selection
from game_logic.show_difficulty_selection_module import show_difficulty_selection

def show_start_screen():
    global passive_item_list, active_item_slot, selected_item_index, MAX_ITEM_SLOTS  # bosspong.py 내부 전역변수 초기화 선언
    global chargebag_obtained, spikeboots_obtained, dashgear_obtained  # 🆕 패시브 아이템 변수 초기화
    
    # 화면 설정 (임시)
    WIDTH = 600
    HEIGHT = 750
    SCREEN = pygame.display.get_surface()
    if not SCREEN:
        SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))

    # 아이템 초기화 (items.py 내부 변수 초기화)
    items.reset_items()

    # bosspong.py 내부 변수들도 초기화
    passive_item_list = []  # 패시브 아이템 초기화
    active_item_slot = []  # 엑티브 아이템 초기화
    selected_item_index = 0  # 선택 인덱스 초기화
    MAX_ITEM_SLOTS = 3  # 아이템 슬롯 기본값으로 초기화
    
    # 🆕 패시브 아이템 효과 초기화
    chargebag_obtained = False
    spikeboots_obtained = False
    dashgear_obtained = False
    
    # 🎓 아카데미 스킬 포인트 초기화 (게임 시작시 0포인트)
    academy.reset_skill_points()
    
    # 🎮 새로운 메뉴 시스템 초기화
    menu_system = MenuSystem(SCREEN, WIDTH, HEIGHT)
    menu_system.current_menu = menu_system.create_main_menu()
    
    # 기존 변수들 (임시 유지)
    menu_options = ["경기시작", "NEW BOSS BATTLE", "메달샵", "옵션", "게임종료"]
    selected = 0
    last_selected = -1  # 호버 사운드용
    locked_message_timer = 0
    dev_code = [1]
    item_code = [2]
    input_buffer = []

    developer_unlocked = False
    item_manager_unlocked = False

    # 사이버펑크 홀로그램 테마 변수들
    animation_timer = 0
    
    # 네온 파티클 시스템 (최소화)
    neon_particles = []
    for _ in range(15):  # 파티클 수 대폭 감소
        neon_particles.append({
            "x": random.randint(0, WIDTH),
            "y": random.randint(0, HEIGHT),
            "vx": random.uniform(-0.5, 0.5),  # 더 느린 속도
            "vy": random.uniform(-0.5, 0.5),
            "size": random.randint(1, 2),  # 더 작은 크기
            "color": random.choice([(0, 255, 255), (255, 0, 128), (128, 255, 0)]),  # 색상 수 감소
            "alpha": random.randint(30, 80),  # 더 투명하게
            "pulse_speed": random.uniform(0.03, 0.08)
        })
    
    # 스캔라인 효과 (최소화)
    scan_lines = []
    for i in range(3):  # 스캔라인 수 대폭 감소
        scan_lines.append({
            "y": random.randint(0, HEIGHT),
            "speed": random.uniform(1.0, 2.0),
            "alpha": random.randint(20, 40),  # 더 투명하게
            "color": (0, 255, 255),  # 단일 색상
            "width": 1  # 얇은 라인
        })
    
    # 글리치 효과
    glitch_timer = 0
    glitch_active = False
    
    # 깔끔한 디지털 매트릭스 효과
    matrix_drops = []
    for x in range(0, WIDTH, 100):  # 간격을 넓게
        matrix_drops.append({
            "x": x,
            "y": random.randint(-HEIGHT, 0),
            "speed": random.uniform(0.5, 1.5),  # 느린 속도
            "chars": ["0", "1"],
            "color": (0, 80, 120)  # 어두운 청록색
        })
    
    # 🎬 시네마틱 영상 관련 변수들 (메인메뉴 진입 기준)
    idle_start_time = pygame.time.get_ticks()  # 대기 시작 시간 (실제 시간 기반)
    cinematic_trigger_time = 15000  # 15초 (밀리초)

    try:
        pass  # Empty try block fix
#         medal_icon = pygame.image.load("medal.png")
#         medal_icon = pygame.transform.scale(medal_icon, (32, 32))
    except:
        medal_icon = pygame.Surface((32, 32))
        medal_icon.fill((255, 215, 0))

    while True:
        animation_timer += 1
        current_time = pygame.time.get_ticks()
        
        # 🎬 15초 대기 후 시네마틱 영상 재생 (실제 시간 기반)
        if current_time - idle_start_time >= cinematic_trigger_time:
            cinematic.show_cinematic_scenes(SCREEN, WIDTH, HEIGHT)
            idle_start_time = pygame.time.get_ticks()  # 시네마틱 종료 후 타이머 리셋
        
        # 사이버펑크 배경 그리기 (그라데이션) - 캐릭터 선택 화면과 동일
        for y in range(HEIGHT):
            ratio = y / HEIGHT
            r = int(10 + ratio * 30)  # 더 밝은 빨강
            g = int(20 + ratio * 40)  # 더 밝은 초록
            b = int(40 + ratio * 60)  # 더 밝은 파랑
            color = (r, g, b)
            pygame.draw.line(SCREEN, color, (0, y), (WIDTH, y))
        
        # 홀로그램 격자 패턴 - 캐릭터 선택 화면과 동일
        grid_color = (0, 150, 200, 25)
        grid_surface = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        for x in range(0, WIDTH, 30):
            pygame.draw.line(grid_surface, grid_color, (x, 0), (x, HEIGHT))
        for y in range(0, HEIGHT, 30):
            pygame.draw.line(grid_surface, grid_color, (0, y), (WIDTH, y))
        SCREEN.blit(grid_surface, (0, 0))
        
        # 은하수 배경 (고퀄리티 사이버펑크)
        galaxy_surf = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        
        # 은하수 중심선
        for x in range(WIDTH):
            galaxy_y = HEIGHT // 3 + int(50 * math.sin(x * 0.01 + animation_timer * 0.02))
            for dy in range(-30, 30):
                distance = abs(dy)
                alpha = max(0, 40 - distance)
                if alpha > 0:
                    color_shift = math.sin(x * 0.02 + animation_timer * 0.01)
                    r = int(100 + 50 * color_shift)
                    g = int(50 + 100 * abs(color_shift))
                    b = int(150 + 50 * color_shift)
                    pygame.draw.circle(galaxy_surf, (r, g, b, alpha), (x, galaxy_y + dy), 1)
        
        # 성운 구름 효과
        for i in range(5):
            nebula_x = 100 + i * 100
            nebula_y = HEIGHT // 3 + int(30 * math.sin(i + animation_timer * 0.015))
            nebula_color = [(255, 100, 150, 20), (100, 150, 255, 20), (150, 255, 100, 20)][i % 3]
            for r in range(60, 0, -5):
                alpha = nebula_color[3] * (r / 60)
                nebula_circle = pygame.Surface((r * 2, r * 2), pygame.SRCALPHA)
                pygame.draw.circle(nebula_circle, (*nebula_color[:3], int(alpha)), (r, r), r)
                galaxy_surf.blit(nebula_circle, (nebula_x - r, nebula_y - r))
        
        SCREEN.blit(galaxy_surf, (0, 0))
        
        # 고퀄리티 자전하는 행성들
        
        # 1. 거대한 붉은 행성 (토성 스타일)
        planet1_x, planet1_y = 120, 150
        planet1_radius = 85
        rotation1 = animation_timer * 0.01
        
        # 행성 본체 (자전 표현)
        planet1_surf = pygame.Surface((planet1_radius * 2, planet1_radius * 2), pygame.SRCALPHA)
        for i in range(planet1_radius, 0, -1):
            ratio = i / planet1_radius
            # 자전에 따른 색상 변화
            rotation_offset = math.sin(rotation1 + i * 0.1) * 20
            color = (
                min(255, int(200 + 55 * (1 - ratio) + rotation_offset)),
                min(255, int(50 + 30 * (1 - ratio))),
                min(255, int(30 + 50 * (1 - ratio)))
            )
            pygame.draw.circle(planet1_surf, (*color, int(180 * ratio)), (planet1_radius, planet1_radius), i)
        
        # 자전 띠 패턴
        for j in range(5):
            band_y = planet1_radius - 30 + j * 15
            band_offset = int(20 * math.sin(rotation1 + j))
            pygame.draw.arc(planet1_surf, (255, 150, 100, 50), 
                          (band_offset, band_y - 5, planet1_radius * 2 - band_offset * 2, 10),
                          0, math.pi, 2)
        
        SCREEN.blit(planet1_surf, (planet1_x - planet1_radius, planet1_y - planet1_radius))
        
        # 삼중 고리 시스템
        for ring_num in range(3):
            ring_radius = planet1_radius + 20 + ring_num * 15
            ring_surf = pygame.Surface((ring_radius * 2, ring_radius // 2), pygame.SRCALPHA)
            ring_rotation = rotation1 * (1 + ring_num * 0.2)
            
            # 고리 입자들
            for angle in range(0, 360, 5):
                particle_angle = math.radians(angle + ring_rotation * 100)
                particle_x = ring_radius + math.cos(particle_angle) * (ring_radius - 10)
                particle_y = ring_radius // 4 + math.sin(particle_angle) * 20
                particle_color = (255, 200 - ring_num * 50, 100, 80 - ring_num * 20)
                pygame.draw.circle(ring_surf, particle_color, (int(particle_x), int(particle_y)), 2)
            
            SCREEN.blit(ring_surf, (planet1_x - ring_radius, planet1_y - 10))
        
        # 2. 사이버펑크 가스 거인 (목성 스타일)
        planet2_x, planet2_y = WIDTH - 100, 280
        planet2_radius = 65
        rotation2 = animation_timer * 0.015
        
        planet2_surf = pygame.Surface((planet2_radius * 2, planet2_radius * 2), pygame.SRCALPHA)
        
        # 소용돌이 패턴
        for i in range(planet2_radius, 0, -1):
            ratio = i / planet2_radius
            # 대적점 효과
            storm_offset = math.sin(rotation2 + i * 0.05) * 30
            color = (
                min(255, int(150 + 100 * (1 - ratio) + storm_offset * 0.5)),
                min(255, int(50 + 150 * (1 - ratio))),
                min(255, int(200 + 55 * (1 - ratio) + storm_offset))
            )
            pygame.draw.circle(planet2_surf, (*color, int(150 * ratio)), (planet2_radius, planet2_radius), i)
        
        # 대적점 (Great Storm)
        storm_x = planet2_radius + int(30 * math.cos(rotation2))
        storm_y = planet2_radius
        pygame.draw.ellipse(planet2_surf, (255, 100, 150, 100), 
                          (storm_x - 20, storm_y - 10, 40, 20))
        
        # 가스 띠 (움직이는)
        for j in range(6):
            band_y = planet2_radius - 40 + j * 15
            flow_offset = int(10 * math.sin(rotation2 * 2 + j))
            band_color = (200 - j * 20, 100 + j * 10, 255, 60)
            pygame.draw.line(planet2_surf, band_color,
                           (flow_offset, band_y), 
                           (planet2_radius * 2 - flow_offset, band_y), 3)
        
        SCREEN.blit(planet2_surf, (planet2_x - planet2_radius, planet2_y - planet2_radius))
        
        # 3. 네온 도시 행성 (사이버펑크 지구)
        planet3_x, planet3_y = 90, HEIGHT - 200
        planet3_radius = 50
        rotation3 = animation_timer * 0.02
        
        planet3_surf = pygame.Surface((planet3_radius * 2, planet3_radius * 2), pygame.SRCALPHA)
        
        # 행성 기본
        for i in range(planet3_radius, 0, -1):
            ratio = i / planet3_radius
            color = (
                int(30 + 70 * (1 - ratio)),
                int(80 + 100 * (1 - ratio)),
                int(120 + 100 * (1 - ratio))
            )
            pygame.draw.circle(planet3_surf, (*color, int(180 * ratio)), (planet3_radius, planet3_radius), i)
        
        # 도시 불빛 (자전하며 나타났다 사라짐)
        for angle in range(0, 360, 15):
            city_angle = math.radians(angle + rotation3 * 100)
            visibility = max(0, math.cos(city_angle))  # 앞면에만 보임
            if visibility > 0:
                dist = random.uniform(planet3_radius * 0.3, planet3_radius * 0.8)
                city_x = planet3_radius + math.cos(city_angle) * dist
                city_y = planet3_radius + math.sin(city_angle * 0.5) * dist * 0.7
                city_color = random.choice([(255, 255, 0), (0, 255, 255), (255, 0, 255)])
                alpha = int(visibility * 255)
                pygame.draw.circle(planet3_surf, (*city_color, alpha), 
                                 (int(city_x), int(city_y)), 2)
        
        # 대기층 글로우
        glow_surf = pygame.Surface((planet3_radius * 2 + 20, planet3_radius * 2 + 20), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (0, 200, 255, 30), 
                         (planet3_radius + 10, planet3_radius + 10), planet3_radius + 10)
        SCREEN.blit(glow_surf, (planet3_x - planet3_radius - 10, planet3_y - planet3_radius - 10))
        SCREEN.blit(planet3_surf, (planet3_x - planet3_radius, planet3_y - planet3_radius))
        
        # 4. 크리스탈 달 (얼음 위성)
        moon_x, moon_y = WIDTH - 150, HEIGHT - 180
        moon_radius = 30
        rotation4 = animation_timer * 0.025
        
        moon_surf = pygame.Surface((moon_radius * 2, moon_radius * 2), pygame.SRCALPHA)
        
        # 크리스탈 표면
        for i in range(moon_radius, 0, -1):
            ratio = i / moon_radius
            crystal_shift = math.sin(rotation4 + i * 0.2) * 20
            gray = min(255, max(0, int(180 + 70 * (1 - ratio) + crystal_shift)))
            moon_surf = pygame.Surface((i * 2, i * 2), pygame.SRCALPHA)
            alpha = min(255, max(0, int(150 * ratio)))
            color = (gray, gray, min(255, gray + 30), alpha)
            pygame.draw.circle(moon_surf, color, (i, i), i)
            SCREEN.blit(moon_surf, (moon_x - i, moon_y - i))
        
        # 크리스탈 반사 효과
        for angle in range(0, 360, 45):
            crystal_angle = math.radians(angle + rotation4 * 200)
            crystal_x = moon_x + math.cos(crystal_angle) * moon_radius * 0.7
            crystal_y = moon_y + math.sin(crystal_angle) * moon_radius * 0.7
            pygame.draw.circle(SCREEN, (200, 220, 255, 100), 
                             (int(crystal_x), int(crystal_y)), 3)
        
        # 5. 파괴된 행성 잔해 (소행성 벨트)
        debris_center_x, debris_center_y = WIDTH // 2, 100
        
        for i in range(12):
            debris_angle = math.radians(i * 30 + animation_timer * 0.5)
            debris_dist = 40 + math.sin(i + animation_timer * 0.03) * 10
            dx = debris_center_x + math.cos(debris_angle) * debris_dist
            dy = debris_center_y + math.sin(debris_angle) * debris_dist
            
            # 각 조각마다 독립적 회전
            piece_rotation = animation_timer * (0.02 + i * 0.01)
            size = 5 + i % 3 * 3
            
            # 네온 테두리를 가진 조각
            debris_color = [(255, 100, 100), (100, 255, 100), (100, 100, 255)][i % 3]
            points = []
            for j in range(5):
                angle = math.radians(j * 72 + piece_rotation * 100)
                px = dx + math.cos(angle) * size
                py = dy + math.sin(angle) * size
                points.append((px, py))
            
            pygame.draw.polygon(SCREEN, (*debris_color, 150), points)
            pygame.draw.polygon(SCREEN, (0, 255, 255), points, 2)
        
        # 홀로그램 별 효과
        if not hasattr(show_start_screen, 'stars'):
            show_start_screen.stars = []
            for _ in range(100):
                show_start_screen.stars.append({
                    'x': random.randint(0, WIDTH),
                    'y': random.randint(0, HEIGHT),
                    'size': random.uniform(0.5, 2),
                    'twinkle': random.uniform(0, math.pi * 2)
                })
        
        for star in show_start_screen.stars:
            twinkle = abs(math.sin(star['twinkle'] + animation_timer * 0.05))
            star_alpha = int(twinkle * 100)
            star_color = (255, 255, 255, star_alpha)
            star_surf = pygame.Surface((int(star['size'] * 4), int(star['size'] * 4)), pygame.SRCALPHA)
            pygame.draw.circle(star_surf, star_color, 
                             (int(star['size'] * 2), int(star['size'] * 2)), int(star['size']))
            SCREEN.blit(star_surf, (star['x'] - star['size'] * 2, star['y'] - star['size'] * 2))
        
        # 네온 파티클 업데이트 및 그리기 - 캐릭터 선택 화면과 동일
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
        
        # 스캔라인 효과 - 캐릭터 선택 화면과 동일
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
        
        # 홀로그램 메달 표시
        medal_panel = pygame.Surface((150, 50), pygame.SRCALPHA)
        medal_panel.fill((10, 15, 25, 180))
        pygame.draw.rect(medal_panel, (255, 215, 0), (0, 0, 150, 50), 2, border_radius=8)
        SCREEN.blit(medal_panel, (WIDTH - 170, 10))
        
        # 메달 아이콘과 텍스트
        try:
            font_medal = pygame.font.Font("NanumSquareB.ttf", 24)
        except:
            font_medal = pygame.font.Font(None, 24)
        
        # 전역 변수 medal_score 사용
        global medal_score
        if 'medal_score' not in globals():
            medal_score = 0  # 초기값 설정
        medal_text = font_medal.render(f"🏅 {medal_score}", True, (255, 215, 0))
        medal_rect = medal_text.get_rect(center=(WIDTH - 95, 35))
        SCREEN.blit(medal_text, medal_rect)

        # 메뉴 제목 (우아하게)
        try:
            font_title = pygame.font.Font("NanumSquareB.ttf", 48)
        except:
            font_title = pygame.font.Font(None, 48)
        
        title_text = font_title.render("메인 메뉴", True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(WIDTH // 2, 120))
        
        # 간단한 텍스트 그림자만
        shadow_text = font_title.render("메인 메뉴", True, (0, 20, 30))
        shadow_rect = shadow_text.get_rect(center=(WIDTH // 2 + 2, 122))
        SCREEN.blit(shadow_text, shadow_rect)
        
        SCREEN.blit(title_text, title_rect)

        # 메뉴 출력 (우아하게)
        # 🆕 메뉴 옵션에 이모지와 설명 추가
        display_options = []
        for option in menu_options:
            if option == "경기시작":
                pass
                display_options.append("🏟️ 경기시작")
            elif option == "헬모드":
                pass
                display_options.append("🔥 헬모드")
            elif option == "NEW BOSS BATTLE":
                pass
                display_options.append("✨ NEW BOSS BATTLE")
            elif option == "메달샵":
                pass
                display_options.append("🏆 메달샵")
            elif option == "옵션":
                pass
                display_options.append("⚙️ 옵션")
            elif option == "게임종료":
                pass
                display_options.append("🚪 게임종료")
            else:
                display_options.append(option)
        
        # 개발자/아이템관리 옵션 추가
        if developer_unlocked:
            display_options.append("🔧 개발자")
        if item_manager_unlocked:
            display_options.append("📦 아이템관리")
            
        all_options = menu_options + (["개발자"] if developer_unlocked else []) + (["아이템관리"] if item_manager_unlocked else [])
        for i, (option, display_option) in enumerate(zip(all_options, display_options)):
            # 메뉴 아이템 배경 (선택된 항목만)
            if i == selected:
                pass
                # 선택된 항목 배경
                option_width = 300
                option_height = 50
                option_x = WIDTH // 2 - option_width // 2
                option_y = 220 + i * 60
                
                # 심플한 선택 표시
                option_bg = pygame.Surface((option_width, option_height), pygame.SRCALPHA)
                pygame.draw.rect(option_bg, (20, 30, 40, 100), (0, 0, option_width, option_height), border_radius=10)
                pygame.draw.rect(option_bg, (0, 150, 200, 200), (0, 0, option_width, option_height), width=2, border_radius=10)
                SCREEN.blit(option_bg, (option_x, option_y))
            
            # 텍스트 색상 결정
            if i == selected:
                color = (255, 255, 0)  # 선택된 항목은 노란색
                try:
                    font_option = pygame.font.Font("NanumSquareB.ttf", 32)
                except:
                    font_option = pygame.font.Font(None, 32)
            else:
                color = (220, 220, 220)  # 일반 항목은 은은한 흰색
                try:
                    font_option = pygame.font.Font("NanumSquareR.ttf", 28)
                except:
                    font_option = pygame.font.Font(None, 28)
            
            # 텍스트 그림자 제거 (깔끔함을 위해)
            
            # 메인 텍스트
            option_surface = font_option.render(display_option, True, color)
            option_rect = option_surface.get_rect(center=(WIDTH // 2, 245 + i * 60))
            SCREEN.blit(option_surface, option_rect)
            
            # 🆕 NEW BOSS BATTLE 선택 시 추가 설명 표시
            if i == selected and option == "NEW BOSS BATTLE":
                try:
                    font_desc = pygame.font.Font("NanumSquareR.ttf", 16)
                except:
                    font_desc = pygame.font.Font(None, 16)
                
                desc_text = font_desc.render("⚡🧊🔥💨 4명의 새로운 보스들의 대결!", True, (200, 200, 255))
                desc_rect = desc_text.get_rect(center=(WIDTH // 2, 245 + i * 60 + 25))
                SCREEN.blit(desc_text, desc_rect)

        if locked_message_timer > 0:
            pass
            # 잠금 메시지 배경
            message_width = 400
            message_height = 40
            message_x = WIDTH // 2 - message_width // 2
            message_y = 580
            
            # 배경 글로우
            for j in range(10, 0, -2):
                alpha = int(60 * (1 - j / 10))
                glow_surface = pygame.Surface((message_width + j*2, message_height + j*2), pygame.SRCALPHA)
                pygame.draw.rect(glow_surface, (255, 100, 100, alpha), (0, 0, message_width + j*2, message_height + j*2), border_radius=20)
                SCREEN.blit(glow_surface, (message_x - j, message_y - j))
            
            # 메인 배경
            message_bg = pygame.Surface((message_width, message_height), pygame.SRCALPHA)
            pygame.draw.rect(message_bg, (255, 100, 100, 40), (0, 0, message_width, message_height), border_radius=20)
            pygame.draw.rect(message_bg, (255, 100, 100, 120), (0, 0, message_width, message_height), width=2, border_radius=20)
            SCREEN.blit(message_bg, (message_x, message_y))
            
            # 메시지 텍스트
            try:
                font_message = pygame.font.Font("NanumSquareR.ttf", 24)
            except:
                font_message = pygame.font.Font(None, 24)
            
            # 텍스트 그림자
            message_shadow = font_message.render("모든 보스를 클리어시 해금됩니다", True, (100, 50, 50))
            message_rect = message_shadow.get_rect(center=(WIDTH // 2 + 1, 600 + 1))
            SCREEN.blit(message_shadow, message_rect)
            
            # 메인 텍스트
            locked_surface = font_message.render("모든 보스를 클리어시 해금됩니다", True, (255, 150, 150))
            message_rect = locked_surface.get_rect(center=(WIDTH // 2, 600))
            SCREEN.blit(locked_surface, message_rect)
            
            locked_message_timer -= 1

        pygame.display.flip()

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()

            elif event.type == pygame.MOUSEBUTTONDOWN or event.type == pygame.MOUSEMOTION:
                idle_start_time = pygame.time.get_ticks()  # 🎬 마우스 활동 시 대기 타이머 리셋

            elif event.type == pygame.KEYDOWN:
                idle_start_time = pygame.time.get_ticks()  # 🎬 키 입력 시 대기 타이머 리셋
                # 숫자 키 바로 이동
                if event.key == pygame.K_1:
                    # SOUND_BUTTON_CLICK.play()  # 🎵 클릭 사운드
                    show_developer_stage_select()
                    return
                elif event.key == pygame.K_2:
                    # SOUND_BUTTON_CLICK.play()  # 🎵 클릭 사운드
                    show_item_manager_menu()
                    return
                
                if pygame.K_0 <= event.key <= pygame.K_9:
                    num = event.key - pygame.K_0
                    input_buffer.append(num)
                    if input_buffer[-4:] == dev_code:
                        developer_unlocked = True
                    if input_buffer[-4:] == item_code:
                        item_manager_unlocked = True

                if event.key in [pygame.K_DOWN, pygame.K_s]:
                    selected = (selected + 1) % len(all_options)
                    # SOUND_BUTTON_HOVER.play()  # 🎵 호버 사운드
                elif event.key in [pygame.K_UP, pygame.K_w]:
                    selected = (selected - 1) % len(all_options)
                    # SOUND_BUTTON_HOVER.play()  # 🎵 호버 사운드
                elif event.key == pygame.K_SPACE:
                    # SOUND_BUTTON_CLICK.play()  # 🎵 클릭 사운드
                    choice = all_options[selected]
                    if choice == "경기시작":
                        pass
                        # 플레이어 캐릭터 선택 화면으로 이동
                        selected_character = show_character_selection()
                        if selected_character is not None:
                            pass
                            # 캐릭터 선택 후 난이도 선택
                            selected_difficulty = show_difficulty_selection()
                            if selected_difficulty is not None:
                                pass
                                # 선택한 난이도로 게임 시작
                                start_game_with_difficulty(selected_character, selected_difficulty)
                        return
# 헬모드 제거됨
                    elif choice == "NEW BOSS BATTLE":
                        pass
                        # 🆕 새로운 보스 배틀 모드 바로 시작
                        main(1, new_boss_mode=True)
                        return
                    elif choice == "메달샵":
                        pass
                        # 메달샵 기능 (아직 구현되지 않음)
                        locked_message_timer = 120
                    elif choice == "옵션":
                        pass
                        option_module.show_options_menu(SCREEN, WIDTH, HEIGHT)
                    elif choice == "게임종료":
                        pygame.quit()
                        sys.exit()
                    elif choice == "개발자":
                        pass
                        show_developer_stage_select()
                    elif choice == "아이템관리":
                        show_item_manager_menu()

