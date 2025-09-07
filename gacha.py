import pygame
import random
import math
import sys
import os

# 리소스 경로 헬퍼 (PyInstaller 호환)
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        # 현재 파일의 디렉토리를 기준으로 함 (gacha.py가 있는 위치)
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

# 뽑기 시스템 전역 변수
gacha_active = False
gacha_phase = 0  # 0: 대기, 1: 동전 투입, 2: 캡슐 떨어짐, 3: 축하 페이지
gacha_spinning = False
gacha_spin_timer = 0
gacha_result = None
gacha_animation = 0
gacha_items = []

# 캡슐 애니메이션 변수
falling_capsule = None
capsule_fall_speed = 0
capsule_fall_y = 0
capsule_bounce_count = 0
capsule_bounce_height = 0

# 뽑기통 크기 및 위치
GACHA_MACHINE_WIDTH = 300
GACHA_MACHINE_HEIGHT = 400
GACHA_GLOBE_RADIUS = 120
GACHA_BASE_HEIGHT = 80

def init_gacha(available_items):
    """뽑기 시스템 초기화 함수"""
    global gacha_active, gacha_phase, gacha_items, gacha_spinning
    global gacha_result, gacha_animation, gacha_spin_timer
    global falling_capsule, capsule_fall_speed, capsule_fall_y, capsule_bounce_count, capsule_bounce_height
    
    gacha_active = True
    gacha_phase = 0
    gacha_spinning = False
    gacha_spin_timer = 0
    gacha_result = None
    gacha_animation = 0
    
    # 뽑기 통 안의 아이템들 (40개로 증가, 다양한 색상)
    gacha_items = []
    capsule_colors = [
        (255, 100, 100),  # 밝은 빨강
        (100, 255, 100),  # 밝은 초록
        (100, 150, 255),  # 밝은 파랑
        (255, 255, 100),  # 밝은 노랑
        (255, 150, 255),  # 밝은 분홍
        (150, 255, 255),  # 밝은 시안
        (255, 180, 100),  # 밝은 주황
        (200, 150, 255),  # 밝은 보라
    ]
    
    # 🚫 패시브 아이템 중복 방지를 위한 필터링
    # items.py의 패시브 아이템 획득 상태 확인
    import items
    filtered_items = []
    for item in available_items:
        # chargebag은 중복 가능
        if item.get("name") == "chargebag":
            filtered_items.append(item)
            continue
            
        # 이미 획득한 패시브 아이템은 제외
        should_skip = False
        item_name = item.get("name", "")
        
        # 각 패시브 아이템 체크
        if item_name == "slot_add" and getattr(items, 'slot_add_obtained', 0) >= 2:
            should_skip = True
        elif item_name == "speedboots" and getattr(items, 'speedboots_obtained', False):
            should_skip = True
        elif item_name == "speedgear" and getattr(items, 'speedgear_obtained', False):
            should_skip = True
        elif item_name == "battery" and getattr(items, 'battery_obtained', False):
            should_skip = True
        elif item_name == "revival" and (getattr(items, 'revival_obtained', False) or getattr(items, 'revival_used', False)):
            should_skip = True
        elif item_name == "master" and getattr(items, 'master_obtained', False):
            should_skip = True
        elif item_name == "cooltime" and getattr(items, 'cooltime_obtained', False):
            should_skip = True
        elif item_name == "spikeboots" and getattr(items, 'spikeboots_obtained', False):
            should_skip = True
        elif item_name == "dashgear" and getattr(items, 'dashgear_obtained', False):
            should_skip = True
        elif item_name == "bulkup" and getattr(items, 'bulkup_obtained', False):
            should_skip = True
        elif item_name == "dashholder" and getattr(items, 'dashholder_obtained', False):
            should_skip = True
        elif item_name == "gravitybelt" and getattr(items, 'gravitybelt_obtained', False):
            should_skip = True
        elif item_name == "sensor" and getattr(items, 'sensor_obtained', False):
            should_skip = True
        elif item_name == "dowsing_pendulum" and getattr(items, 'dowsing_pendulum_obtained', False):
            should_skip = True
        elif item_name == "commando_arm" and getattr(items, 'commando_arm_obtained', False):
            should_skip = True
        elif item_name == "technical_vest" and getattr(items, 'technical_vest_obtained', False):
            should_skip = True
        elif item_name == "fuel_pouch" and getattr(items, 'fuel_pouch_obtained', False):
            should_skip = True
        elif item_name == "bluetooth_ring" and getattr(items, 'bluetooth_ring_obtained', False):
            should_skip = True
        elif item_name == "smartphone" and getattr(items, 'smartphone_obtained', False):
            should_skip = True
        elif item_name == "ragnarok_hammer" and getattr(items, 'ragnarok_hammer_obtained', False):
            should_skip = True  # 라그나로크 해머도 중복 방지
        
        if not should_skip:
            filtered_items.append(item)
    
    # 필터링된 아이템이 없으면 원본 사용
    if not filtered_items:
        filtered_items = available_items
    
    for i in range(40):
        item = random.choice(filtered_items).copy()
        item["capsule_color"] = random.choice(capsule_colors)
        gacha_items.append(item)
    
    # 캡슐 애니메이션 초기화
    falling_capsule = None
    capsule_fall_speed = 0
    capsule_fall_y = 0
    capsule_bounce_count = 0
    capsule_bounce_height = 0
    


def update_gacha():
    """뽑기 시스템 업데이트 함수"""
    global gacha_phase, gacha_spinning, gacha_spin_timer, gacha_result, gacha_animation
    global falling_capsule, capsule_fall_speed, capsule_fall_y, capsule_bounce_count, capsule_bounce_height
    
    if not gacha_active:
        return
    
    if gacha_phase == 1:  # 동전 투입 애니메이션
        gacha_spin_timer += 1
        if gacha_spin_timer >= 60:  # 1초 후 캡슐 떨어짐
            gacha_phase = 2
            gacha_spin_timer = 0
            
            # 랜덤하게 아이템 선택
            gacha_result = random.choice(gacha_items)
            
            # 캡슐 떨어지는 애니메이션 시작
            falling_capsule = gacha_result
            capsule_fall_y = 0
            capsule_fall_speed = 0
            capsule_bounce_count = 0
            capsule_bounce_height = 0
    
    elif gacha_phase == 2:  # 캡슐 떨어지는 애니메이션
        capsule_fall_speed += 0.8  # 중력
        capsule_fall_y += capsule_fall_speed
        
        # 바닥에 닿으면 튀어오름
        if capsule_fall_y >= 200 and capsule_fall_speed > 0:
            capsule_fall_speed = -capsule_fall_speed * 0.6  # 튀어오름
            capsule_bounce_count += 1
            capsule_bounce_height = capsule_fall_y
        
        # 3번 튀어오른 후 바로 축하 페이지로 이동
        if capsule_bounce_count >= 3:
            gacha_phase = 3
            gacha_animation = 0
            return
    
    # 애니메이션 업데이트
    if gacha_phase == 3:
        gacha_animation += 1

def draw_cyberpunk_gacha_machine(screen, center_x, center_y):
    """사이버펑크 홀로그램 뽑기통"""
    # 뽑기통 위치 계산
    machine_x = center_x - GACHA_MACHINE_WIDTH // 2
    machine_y = center_y - GACHA_MACHINE_HEIGHT // 2
    
    # 펄스 효과
    pulse = abs(math.sin(pygame.time.get_ticks() * 0.003)) * 0.3 + 0.7
    animation_timer = pygame.time.get_ticks() // 50
    
    # 1. 홀로그램 베이스 (하단부)
    base_rect = pygame.Rect(machine_x + 50, machine_y + GACHA_MACHINE_HEIGHT - GACHA_BASE_HEIGHT, 
                           GACHA_MACHINE_WIDTH - 100, GACHA_BASE_HEIGHT)
    
    # 베이스 네온 글로우
    for i in range(3):
        glow_surf = pygame.Surface((GACHA_MACHINE_WIDTH - 90 + i*10, GACHA_BASE_HEIGHT + i*10), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (0, 255, 255, 50 - i*15), 
                        (0, 0, GACHA_MACHINE_WIDTH - 90 + i*10, GACHA_BASE_HEIGHT + i*10),
                        border_radius=10)
        screen.blit(glow_surf, (machine_x + 45 - i*5, machine_y + GACHA_MACHINE_HEIGHT - GACHA_BASE_HEIGHT - i*5))
    
    # 베이스 본체 (홀로그램 그라데이션)
    base_surf = pygame.Surface((GACHA_MACHINE_WIDTH - 100, GACHA_BASE_HEIGHT), pygame.SRCALPHA)
    for y in range(GACHA_BASE_HEIGHT):
        ratio = y / GACHA_BASE_HEIGHT
        alpha = int(200 - ratio * 50)
        color = (0, int(100 * pulse), int(150 * pulse))
        pygame.draw.line(base_surf, (*color, min(alpha, 255)), (0, y), (GACHA_MACHINE_WIDTH - 100, y))
    screen.blit(base_surf, (machine_x + 50, machine_y + GACHA_MACHINE_HEIGHT - GACHA_BASE_HEIGHT))
    
    # 베이스 테두리
    pygame.draw.rect(screen, (0, 255, 255), base_rect, 3, border_radius=5)
    
    # 네온 장식선
    pygame.draw.rect(screen, (255, 0, 255), 
                    (machine_x + 45, machine_y + GACHA_MACHINE_HEIGHT - GACHA_BASE_HEIGHT - 5, 
                     GACHA_MACHINE_WIDTH - 90, 5))
    pygame.draw.rect(screen, (255, 0, 255), 
                    (machine_x + 45, machine_y + GACHA_MACHINE_HEIGHT - 5, 
                     GACHA_MACHINE_WIDTH - 90, 5))
    
    # 2. 동전 투입구 (사이버펑크 스타일)
    coin_slot_rect = pygame.Rect(machine_x + 70, machine_y + GACHA_MACHINE_HEIGHT - GACHA_BASE_HEIGHT + 15, 
                                50, 20)
    # 홀로그램 슬롯
    slot_surf = pygame.Surface((50, 20), pygame.SRCALPHA)
    pygame.draw.rect(slot_surf, (0, 50, 100, 150), (0, 0, 50, 20))
    pygame.draw.rect(slot_surf, (0, 255, 255), (0, 0, 50, 20), 2)
    screen.blit(slot_surf, (coin_slot_rect.x, coin_slot_rect.y))
    
    # 슬롯 LED 표시
    if gacha_phase >= 1:
        led_color = (0, 255, 0)  # 활성화시 초록
    else:
        led_color = (255, 0, 0)  # 비활성화시 빨간색
    pygame.draw.circle(screen, led_color, (machine_x + 95, machine_y + GACHA_MACHINE_HEIGHT - GACHA_BASE_HEIGHT + 10), 3)
    
    # 동전 투입 텍스트
    try:
        coin_font = pygame.font.Font(resource_path("NanumSquare.ttf"), 10)
    except:
        coin_font = pygame.font.Font(None, 10)
    coin_text = coin_font.render("INSERT", True, (0, 200, 200))
    screen.blit(coin_text, (coin_slot_rect.x + 5, coin_slot_rect.y - 12))
    
    # 3. 핸들 (회전하는 레버) - 사이버펑크 스타일
    handle_center_x = machine_x + GACHA_MACHINE_WIDTH // 2 + 80
    handle_center_y = machine_y + GACHA_MACHINE_HEIGHT - GACHA_BASE_HEIGHT + 40
    
    # 핸들 베이스
    handle_base = pygame.Rect(handle_center_x - 15, handle_center_y - 15, 30, 30)
    pygame.draw.rect(screen, (100, 100, 150), handle_base)
    pygame.draw.rect(screen, (0, 255, 255), handle_base, 2)
    
    # 회전 각도 계산
    if gacha_phase == 1:
        # 레버 돌리기 애니메이션
        rotation_angle = gacha_spin_timer * 10  # 회전 속도
    else:
        rotation_angle = 0
    
    # 핸들 암 그리기
    handle_length = 40
    handle_end_x = handle_center_x + handle_length * math.cos(math.radians(rotation_angle))
    handle_end_y = handle_center_y + handle_length * math.sin(math.radians(rotation_angle))
    
    # 핸들 암 네온 효과
    for i in range(3):
        width = 5 - i
        alpha = 150 - i * 40
        pygame.draw.line(screen, (0, 255, 255), (handle_center_x, handle_center_y), 
                        (handle_end_x, handle_end_y), width)
    
    # 핸들 손잡이 (홀로그램 구체)
    handle_glow_radius = 15
    for i in range(2):
        glow_surf = pygame.Surface((handle_glow_radius * 2 + i*10, handle_glow_radius * 2 + i*10), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (255, 0, 255, 80 - i*30), 
                         (handle_glow_radius + i*5, handle_glow_radius + i*5), handle_glow_radius + i*5)
        screen.blit(glow_surf, (handle_end_x - handle_glow_radius - i*5, handle_end_y - handle_glow_radius - i*5))
    
    pygame.draw.circle(screen, (255, 0, 255), (int(handle_end_x), int(handle_end_y)), 12)
    pygame.draw.circle(screen, (255, 255, 255), (int(handle_end_x), int(handle_end_y)), 12, 2)
    
    # 핸들 회전 표시기
    if gacha_phase == 1:
        # 회전 이펙트
        for angle_offset in range(0, 360, 45):
            effect_angle = rotation_angle + angle_offset
            effect_x = handle_center_x + 25 * math.cos(math.radians(effect_angle))
            effect_y = handle_center_y + 25 * math.sin(math.radians(effect_angle))
            effect_alpha = int(100 * pulse)
            pygame.draw.circle(screen, (0, 255, 255, effect_alpha), (int(effect_x), int(effect_y)), 2)
    
    # 4. 캡슐 배출구 (홀로그램 스타일)
    chute_rect = pygame.Rect(machine_x + 110, machine_y + GACHA_MACHINE_HEIGHT - GACHA_BASE_HEIGHT + 50, 
                            80, 25)
    chute_surf = pygame.Surface((80, 25), pygame.SRCALPHA)
    pygame.draw.rect(chute_surf, (0, 30, 60, 150), (0, 0, 80, 25))
    pygame.draw.rect(chute_surf, (0, 255, 255), (0, 0, 80, 25), 2)
    screen.blit(chute_surf, (chute_rect.x, chute_rect.y))
    
    # 배출구 네온 효과
    if gacha_phase == 2:
        outlet_glow = pygame.Surface((90, 35), pygame.SRCALPHA)
        pygame.draw.rect(outlet_glow, (0, 255, 0, 50), (0, 0, 90, 35), border_radius=5)
        screen.blit(outlet_glow, (chute_rect.x - 5, chute_rect.y - 5))
    
    # 5. 투명한 구체 (캡슐들이 들어있는 부분) - 홀로그램 스타일
    globe_center_x = machine_x + GACHA_MACHINE_WIDTH // 2
    globe_center_y = machine_y + 150
    
    # 구체 글로우 효과
    for i in range(3):
        glow_radius = GACHA_GLOBE_RADIUS + i * 10
        glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
        pygame.draw.circle(glow_surf, (0, 255, 255, 30 - i*10), 
                         (glow_radius, glow_radius), glow_radius)
        screen.blit(glow_surf, (globe_center_x - glow_radius, globe_center_y - glow_radius))
    
    # 구체 본체 (홀로그램 유리)
    globe_surface = pygame.Surface((GACHA_GLOBE_RADIUS * 2, GACHA_GLOBE_RADIUS * 2), pygame.SRCALPHA)
    pygame.draw.circle(globe_surface, (0, 100, 150, 50), 
                      (GACHA_GLOBE_RADIUS, GACHA_GLOBE_RADIUS), GACHA_GLOBE_RADIUS)
    
    # 홀로그램 반사 효과
    for angle in range(0, 360, 30):
        x = GACHA_GLOBE_RADIUS + int(GACHA_GLOBE_RADIUS * 0.7 * math.cos(math.radians(angle)))
        y = GACHA_GLOBE_RADIUS + int(GACHA_GLOBE_RADIUS * 0.7 * math.sin(math.radians(angle)))
        pygame.draw.circle(globe_surface, (255, 255, 255, 20), (x, y), 5)
    
    screen.blit(globe_surface, (globe_center_x - GACHA_GLOBE_RADIUS, globe_center_y - GACHA_GLOBE_RADIUS))
    
    # 구체 테두리 (네온)
    pygame.draw.circle(screen, (0, 255, 255), (globe_center_x, globe_center_y), GACHA_GLOBE_RADIUS, 3)
    
    # 상단 커버 (메탈 효과)
    cover_y = globe_center_y - GACHA_GLOBE_RADIUS - 20
    cover_rect = pygame.Rect(globe_center_x - 60, cover_y, 120, 30)
    
    # 커버 그라데이션
    cover_surf = pygame.Surface((120, 30), pygame.SRCALPHA)
    for y in range(30):
        ratio = y / 30
        alpha = int(200 - ratio * 100)
        pygame.draw.line(cover_surf, (150, 150, 200, alpha), (0, y), (120, y))
    screen.blit(cover_surf, (cover_rect.x, cover_rect.y))
    
    pygame.draw.rect(screen, (0, 255, 255), cover_rect, 2, border_radius=10)
    pygame.draw.ellipse(screen, (100, 100, 150), 
                       (globe_center_x - 65, cover_y + 25, 130, 15))
    pygame.draw.ellipse(screen, (0, 255, 255), 
                       (globe_center_x - 65, cover_y + 25, 130, 15), 2)
    
    # 6. 구체 안의 캡슐들 그리기 (사이버펑크 스타일)
    if gacha_phase == 0 or gacha_phase == 1:
        # 시간에 따른 부드러운 애니메이션
        time_factor = gacha_animation * 0.035
        
        for i, item in enumerate(gacha_items[:20]):  # 20개 표시
            # 각 아이템마다 고유한 궤도와 속도
            base_angle = (i * 137.5) % 360  # 황금각으로 분산
            unique_speed = 0.8 + (i % 5) * 0.3
            
            # 시간에 따른 부드러운 회전
            animated_angle = base_angle + (time_factor * unique_speed * 60)
            
            # 타원형 궤도로 더 자연스럽게
            base_radius = 40 + (i % 3) * 15
            ellipse_factor = 0.8
            
            rad = math.radians(animated_angle)
            capsule_x = globe_center_x + math.cos(rad) * base_radius
            capsule_y = globe_center_y + math.sin(rad) * base_radius * ellipse_factor
            
            # 경계 체크 (구체 밖으로 나가지 않게)
            distance_from_center = math.sqrt((capsule_x - globe_center_x)**2 + (capsule_y - globe_center_y)**2)
            if distance_from_center > GACHA_GLOBE_RADIUS - 15:
                scale_factor = (GACHA_GLOBE_RADIUS - 15) / distance_from_center
                capsule_x = globe_center_x + (capsule_x - globe_center_x) * scale_factor
                capsule_y = globe_center_y + (capsule_y - globe_center_y) * scale_factor
            
            # 캡슐 크기
            capsule_radius = 8
            
            # 홀로그램 캡슐 글로우
            if gacha_phase == 1 and i % 3 == 0:  # 선택적 글로우 효과
                glow_surf = pygame.Surface((capsule_radius * 4, capsule_radius * 4), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*item.get("capsule_color", item["color"]), 50), 
                                 (capsule_radius * 2, capsule_radius * 2), capsule_radius * 2)
                screen.blit(glow_surf, (capsule_x - capsule_radius * 2, capsule_y - capsule_radius * 2))
            
            # 캡슐 색상 결정
            capsule_color = item.get("capsule_color", item.get("color", (255, 255, 255)))
            
            # 캡슐 본체 (홀로그램 효과)
            pygame.draw.circle(screen, capsule_color, (int(capsule_x), int(capsule_y)), capsule_radius)
            pygame.draw.circle(screen, (255, 255, 255), (int(capsule_x), int(capsule_y)), capsule_radius, 2)
            
            # 캡슐 하이라이트
            highlight_surf = pygame.Surface((capsule_radius * 2, capsule_radius * 2), pygame.SRCALPHA)
            pygame.draw.circle(highlight_surf, (255, 255, 255, 80), 
                             (capsule_radius - capsule_radius//3, capsule_radius - capsule_radius//3), 
                             capsule_radius//3)
            screen.blit(highlight_surf, (capsule_x - capsule_radius, capsule_y - capsule_radius))
            
            # 캡슐 내부 아이콘
            if "icon" in item and item["icon"]:
                icon_size = max(10, capsule_radius - 1)
                icon = pygame.transform.scale(item["icon"], (icon_size, icon_size))
                icon_rect = icon.get_rect(center=(int(capsule_x), int(capsule_y)))
                screen.blit(icon, icon_rect)
    
    # 7. 디지털 디스플레이 패널 (상태 표시)
    display_rect = pygame.Rect(machine_x + 30, machine_y + GACHA_MACHINE_HEIGHT - 50, 
                               GACHA_MACHINE_WIDTH - 60, 30)
    
    # 디스플레이 배경
    display_surf = pygame.Surface((GACHA_MACHINE_WIDTH - 60, 30), pygame.SRCALPHA)
    pygame.draw.rect(display_surf, (0, 20, 40, 180), (0, 0, GACHA_MACHINE_WIDTH - 60, 30))
    pygame.draw.rect(display_surf, (0, 255, 255), (0, 0, GACHA_MACHINE_WIDTH - 60, 30), 2)
    screen.blit(display_surf, (display_rect.x, display_rect.y))
    
    # 상태 텍스트
    if gacha_phase == 0:
        status_text = "READY"
        status_color = (0, 255, 255)
    elif gacha_phase == 1:
        status_text = "EXTRACTING..."
        status_color = (255, 255, 0)
    else:
        status_text = "COMPLETE!"
        status_color = (0, 255, 0)
    
    try:
        status_font = pygame.font.Font(resource_path("NanumSquareB.ttf"), 16)
    except:
        status_font = pygame.font.Font(None, 16)
    
    text_surf = status_font.render(status_text, True, status_color)
    text_rect = text_surf.get_rect(center=(display_rect.x + display_rect.width//2, 
                                           display_rect.y + display_rect.height//2))
    
    # 텍스트 깜빡임 효과
    if gacha_phase == 1 and pygame.time.get_ticks() % 500 < 250:
        screen.blit(text_surf, text_rect)
    elif gacha_phase != 1:
        screen.blit(text_surf, text_rect)
    
    # 8. 볼트와 디테일 (기계적 요소)
    # 상단 볼트
    for i in range(4):
        bolt_x = machine_x + 30 + i * 60
        bolt_y = machine_y + 10
        # 네온 볼트
        bolt_glow = pygame.Surface((10, 10), pygame.SRCALPHA)
        pygame.draw.circle(bolt_glow, (0, 255, 255, 100), (5, 5), 5)
        screen.blit(bolt_glow, (bolt_x - 5, bolt_y - 5))
        pygame.draw.circle(screen, (150, 150, 200), (bolt_x, bolt_y), 4)
        pygame.draw.circle(screen, (0, 255, 255), (bolt_x, bolt_y), 4, 2)
    
    # 7. 떨어지는 캡슐 애니메이션 (홀로그램 스타일)
    if gacha_phase == 2 and falling_capsule:
        fall_x = center_x
        fall_y = machine_y + GACHA_MACHINE_HEIGHT + 50 + capsule_fall_y
        
        # 홀로그램 글로우 효과
        for i in range(3):
            glow_radius = 20 + i * 5
            glow_surf = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
            glow_alpha = 80 - i * 20
            pygame.draw.circle(glow_surf, (*falling_capsule["color"], glow_alpha), 
                             (glow_radius, glow_radius), glow_radius)
            screen.blit(glow_surf, (fall_x - glow_radius, fall_y - glow_radius))
        
        # 떨어지는 캡슐
        capsule_radius = 15
        pygame.draw.circle(screen, falling_capsule["color"], (int(fall_x), int(fall_y)), capsule_radius)
        pygame.draw.circle(screen, (0, 255, 255), (int(fall_x), int(fall_y)), capsule_radius, 3)
        
        # 트레일 효과
        trail_count = 5
        for i in range(trail_count):
            trail_y = fall_y - (i + 1) * 10
            trail_alpha = 100 - i * 20
            trail_radius = capsule_radius - i
            trail_surf = pygame.Surface((trail_radius * 2, trail_radius * 2), pygame.SRCALPHA)
            pygame.draw.circle(trail_surf, (*falling_capsule["color"], trail_alpha), 
                             (trail_radius, trail_radius), trail_radius)
            screen.blit(trail_surf, (fall_x - trail_radius, trail_y - trail_radius))
        
        # 캡슐 내부 아이콘
        if "icon" in falling_capsule and falling_capsule["icon"]:
            icon = pygame.transform.scale(falling_capsule["icon"], (20, 20))
            icon_rect = icon.get_rect(center=(int(fall_x), int(fall_y)))
            screen.blit(icon, icon_rect)
    


def draw_gacha(screen, width, height, get_item_name_korean, get_item_description):
    """뽑기 시스템 그리기 함수 - 사이버펑크 테마"""
    if not gacha_active:
        return
    
    # 사이버펑크 그라데이션 배경
    for y in range(height):
        ratio = y / height
        r = int(10 + ratio * 20)
        g = int(20 + ratio * 30)
        b = int(30 + ratio * 50)
        pygame.draw.line(screen, (r, g, b), (0, y), (width, y))
    
    # 홀로그램 격자 패턴
    grid_surf = pygame.Surface((width, height), pygame.SRCALPHA)
    grid_color = (0, 255, 255, 20)
    for x in range(0, width, 30):
        pygame.draw.line(grid_surf, grid_color, (x, 0), (x, height))
    for y in range(0, height, 30):
        pygame.draw.line(grid_surf, grid_color, (0, y), (width, y))
    screen.blit(grid_surf, (0, 0))
    
    # 네온 파티클 효과
    if not hasattr(draw_gacha, 'neon_particles'):
        draw_gacha.neon_particles = []
        for _ in range(30):
            draw_gacha.neon_particles.append({
                'x': random.randint(0, width),
                'y': random.randint(0, height),
                'speed': random.uniform(0.3, 1.0),
                'size': random.randint(1, 3),
                'alpha': random.randint(50, 150),
                'color': random.choice([(0, 255, 255), (255, 0, 255), (255, 255, 0)])
            })
    
    # 파티클 업데이트 및 그리기
    for particle in draw_gacha.neon_particles:
        particle['y'] -= particle['speed']
        if particle['y'] < 0:
            particle['y'] = height
            particle['x'] = random.randint(0, width)
        
        alpha = int(particle['alpha'] * (0.5 + 0.5 * math.sin(pygame.time.get_ticks() * 0.005)))
        size = particle['size']
        
        for i in range(2):
            glow_surf = pygame.Surface((size * (3-i), size * (3-i)), pygame.SRCALPHA)
            pygame.draw.circle(glow_surf, (*particle['color'], alpha // (i+1)), 
                             (size * (3-i) // 2, size * (3-i) // 2), size * (3-i) // 2)
            screen.blit(glow_surf, (particle['x'] - size * (3-i) // 2, 
                                   particle['y'] - size * (3-i) // 2))
    
    # 메인 컨테이너 (홀로그램 스타일)
    container_width = 800
    container_height = 650
    container_x = (width - container_width) // 2
    container_y = (height - container_height) // 2 - 30
    
    # 홀로그램 글로우 효과
    for i in range(5):
        glow_alpha = 60 - i * 10
        glow_surf = pygame.Surface((container_width + i*10, container_height + i*10), pygame.SRCALPHA)
        pygame.draw.rect(glow_surf, (0, 255, 255, glow_alpha), 
                        (0, 0, container_width + i*10, container_height + i*10), 
                        3, border_radius=20)
        screen.blit(glow_surf, (container_x - i*5, container_y - i*5))
    
    # 메인 컨테이너 배경
    main_container = pygame.Rect(container_x, container_y, container_width, container_height)
    container_surf = pygame.Surface((container_width, container_height), pygame.SRCALPHA)
    
    # 홀로그램 배경 그라데이션
    for y in range(container_height):
        ratio = y / container_height
        alpha = int(200 - ratio * 100)
        pygame.draw.line(container_surf, (0, 30, 60, alpha), (0, y), (container_width, y))
    
    screen.blit(container_surf, (container_x, container_y))
    
    # 네온 테두리
    pygame.draw.rect(screen, (0, 255, 255), main_container, 3, border_radius=15)
    
    # 모서리 장식
    corner_size = 20
    corners = [(container_x, container_y), 
              (container_x + container_width - corner_size, container_y),
              (container_x, container_y + container_height - corner_size),
              (container_x + container_width - corner_size, container_y + container_height - corner_size)]
    
    for cx, cy in corners:
        if cx == container_x:
            pygame.draw.lines(screen, (0, 255, 255), False, 
                            [(cx + corner_size, cy), (cx, cy), (cx, cy + corner_size)], 3)
        else:
            pygame.draw.lines(screen, (0, 255, 255), False, 
                            [(cx, cy), (cx + corner_size, cy), (cx + corner_size, cy + corner_size)], 3)
    
    
    # 사이버펑크 스타일 타이틀
    title_font = pygame.font.Font(resource_path("NanumSquareEB.ttf"), 56)
    title_text = "◈ LOOT EXTRACTION ◈"
    subtitle_text = "[ 아이템 획듍 프로토콜 ]"
    
    # 타이틀 네온 글로우 효과
    for i in range(3):
        glow_alpha = 100 - i * 30
        glow_surf = title_font.render(title_text, True, (0, 255, 255))
        glow_surf.set_alpha(glow_alpha)
        glow_rect = glow_surf.get_rect(center=(container_x + container_width // 2 - i*2, container_y + 75 - i*2))
        screen.blit(glow_surf, glow_rect)
    
    # 메인 타이틀
    main_title = title_font.render(title_text, True, (255, 255, 255))
    title_rect = main_title.get_rect(center=(container_x + container_width // 2, container_y + 75))
    screen.blit(main_title, title_rect)
    
    # 서브타이틀
    subtitle_font = pygame.font.Font(resource_path("NanumSquareB.ttf"), 24)
    subtitle_surf = subtitle_font.render(subtitle_text, True, (0, 200, 200))
    subtitle_rect = subtitle_surf.get_rect(center=(container_x + container_width // 2, container_y + 105))
    screen.blit(subtitle_surf, subtitle_rect)
    
    # 홀로그램 뽑기통 그리기
    gacha_center_x = container_x + container_width // 2
    gacha_center_y = container_y + 320
    draw_cyberpunk_gacha_machine(screen, gacha_center_x, gacha_center_y)
    
    # 안내 텍스트 영역 (컨테이너 내부에 배치)
    guide_area = pygame.Rect(container_x + 60, container_y + container_height - 120, container_width - 120, 80)
    pygame.draw.rect(screen, (40, 30, 20), guide_area)
    pygame.draw.rect(screen, (255, 215, 0), guide_area, 3)
    
    # 안내 텍스트 (더 크고 깔끔하게)
    if gacha_phase == 0:
        guide_font = pygame.font.Font(resource_path("NanumSquareB.ttf"), 32)
        guide_text = "✨ SPACE를 눌러 뽑기 시작! ✨"
        text = guide_font.render(guide_text, True, (255, 255, 255))
        # 텍스트 그림자
        shadow_text = guide_font.render(guide_text, True, (80, 80, 80))
        text_rect = text.get_rect(center=(container_x + container_width // 2, container_y + container_height - 80))
        shadow_rect = text_rect.copy()
        shadow_rect.x += 2
        shadow_rect.y += 2
        screen.blit(shadow_text, shadow_rect)
        screen.blit(text, text_rect)
    
    elif gacha_phase == 1:
        guide_font = pygame.font.Font(resource_path("NanumSquareB.ttf"), 28)
        guide_text = "🪙 동전을 투입하고 있습니다..."
        text = guide_font.render(guide_text, True, (255, 255, 255))
        shadow_text = guide_font.render(guide_text, True, (80, 80, 80))
        text_rect = text.get_rect(center=(container_x + container_width // 2, container_y + container_height - 80))
        shadow_rect = text_rect.copy()
        shadow_rect.x += 2
        shadow_rect.y += 2
        screen.blit(shadow_text, shadow_rect)
        screen.blit(text, text_rect)
    
    elif gacha_phase == 2:
        guide_font = pygame.font.Font(resource_path("NanumSquareB.ttf"), 28)
        guide_text = "🎁 아이템이 나오고 있습니다..."
        text = guide_font.render(guide_text, True, (255, 255, 255))
        shadow_text = guide_font.render(guide_text, True, (80, 80, 80))
        text_rect = text.get_rect(center=(container_x + container_width // 2, container_y + container_height - 80))
        shadow_rect = text_rect.copy()
        shadow_rect.x += 2
        shadow_rect.y += 2
        screen.blit(shadow_text, shadow_rect)
        screen.blit(text, text_rect)
    

    


def run_gacha(screen, width, height, get_item_name_korean, store_passive_item, store_active_item, get_item_description):
    """뽑기 시스템 실행 함수"""
    global gacha_phase, gacha_spinning, gacha_result
    
    clock = pygame.time.Clock()
    running = True
    
    while running:
        clock.tick(60)
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE:
                    if gacha_phase == 0:  # 시작
                        gacha_phase = 1
                        gacha_spin_timer = 0
                    elif gacha_phase == 3:  # 결과 - 별도 결과 페이지로 이동
                        # 뽑기 종료하고 결과 페이지로
                        global gacha_active
                        gacha_active = False
                        running = False
        
        # 뽑기 업데이트
        update_gacha()
        
        # 애니메이션 카운터 증가 (아이템들이 계속 움직이도록)
        global gacha_animation
        gacha_animation += 1
        
        # 뽑기 그리기
        draw_gacha(screen, width, height, get_item_name_korean, get_item_description)
        
        pygame.display.flip()
    
    # 뽑기 완료 후 결과 페이지 표시
    if gacha_result:
        show_gacha_result_page(screen, width, height, gacha_result, get_item_name_korean, get_item_description, store_passive_item, store_active_item)

def show_gacha_result_page(screen, width, height, gacha_result, get_item_name_korean, get_item_description, store_passive_item, store_active_item):
    """뽑기 결과 전용 페이지 - 화려한 축하 화면"""
    clock = pygame.time.Clock()
    running = True
    animation_timer = 0
    
    # 색종이 파티클 리스트 (대폭 강화!)
    confetti_particles = []
    for i in range(200):  # 200개로 증가
        confetti_particles.append({
            "x": random.randint(0, width),
            "y": random.randint(-300, -100),  # 더 위에서 시작
            "vx": random.uniform(-6, 6),  # 더 빠른 가로 속도
            "vy": random.uniform(4, 12),  # 더 빠른 세로 속도
            "color": random.choice([
                (255, 0, 0),      # 진한 빨강
                (0, 255, 0),      # 진한 초록
                (0, 0, 255),      # 진한 파랑
                (255, 255, 0),    # 진한 노랑
                (255, 0, 255),    # 진한 마젠타
                (0, 255, 255),    # 진한 시안
                (255, 128, 0),    # 진한 주황
                (128, 0, 255),    # 진한 보라
                (255, 255, 255),  # 흰색
                (255, 215, 0),    # 골드
                (255, 100, 100),  # 연한 빨강
                (100, 255, 100),  # 연한 초록
                (100, 100, 255),  # 연한 파랑
                (255, 255, 100),  # 연한 노랑
            ]),
            "size": random.randint(20, 40),  # 훨씬 더 크게
            "rotation": random.uniform(0, 360),
            "rotation_speed": random.uniform(-12, 12),  # 더 빠른 회전
            "shape": random.choice(["rect", "circle", "star", "triangle"])  # 삼각형 추가
        })
    
    while running:
        clock.tick(60)
        animation_timer += 1
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pygame.quit()
                sys.exit()
            
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE:
                    # 아이템 지급
                    print(f"  : {gacha_result['name']} (: {gacha_result['type']})")
                    if gacha_result["type"] == "passive":
                        item_data = {
                            "name": gacha_result["name"],
                            "color": gacha_result["color"],
                            "effect": gacha_result["name"],
                            "icon": gacha_result.get("icon")
                        }
                        store_passive_item(item_data)
                    else:
                        item_data = {
                            "name": gacha_result["name"],
                            "color": gacha_result["color"],
                            "effect": gacha_result["name"],
                            "icon": gacha_result.get("icon")
                        }
                        store_active_item(item_data)
                    running = False
        
        # 사이버펑크 그라데이션 배경
        for y in range(height):
            ratio = y / height
            r = int(10 + ratio * 20)
            g = int(20 + ratio * 30)
            b = int(30 + ratio * 50)
            pygame.draw.line(screen, (r, g, b), (0, y), (width, y))
        
        # 홀로그램 격자 패턴
        grid_surf = pygame.Surface((width, height), pygame.SRCALPHA)
        grid_color = (0, 255, 255, 15)
        for x in range(0, width, 40):
            pygame.draw.line(grid_surf, grid_color, (x, 0), (x, height))
        for y in range(0, height, 40):
            pygame.draw.line(grid_surf, grid_color, (0, y), (width, y))
        screen.blit(grid_surf, (0, 0))
        
        # 홀로그램 스캔라인 효과
        scan_offset = (animation_timer * 3) % height
        for i in range(3):
            scan_y = (scan_offset + i * 20) % height
            scan_surf = pygame.Surface((width, 3), pygame.SRCALPHA)
            scan_surf.fill((0, 255, 255, 40))
            screen.blit(scan_surf, (0, scan_y))
        
        # 색종이 애니메이션 업데이트 및 그리기 (대폭 강화!)
        for particle in confetti_particles:
            # 위치 업데이트
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            particle["rotation"] += particle["rotation_speed"]
            
            # 중력 효과 (더 강하게)
            particle["vy"] += 0.25
            
            # 화면 밖으로 나가면 다시 위에서 시작
            if particle["y"] > height + 100:
                particle["y"] = random.randint(-300, -100)
                particle["x"] = random.randint(0, width)
                particle["vy"] = random.uniform(4, 12)
                particle["vx"] = random.uniform(-6, 6)
            
            # 색종이 그리기 (더 밝고 선명하게)
            if particle["y"] > -150:  # 화면에 보일 때만 그리기
                size = particle["size"]
                color = particle["color"]
                rotation = particle["rotation"]
                shape = particle["shape"]
                
                # 모양에 따른 그리기
                if shape == "rect":
                    # 직사각형 색종이 (더 선명하게)
                    rect_surface = pygame.Surface((size, size//2), pygame.SRCALPHA)
                    pygame.draw.rect(rect_surface, color, (0, 0, size, size//2))
                    # 테두리 추가로 더 선명하게
                    pygame.draw.rect(rect_surface, (255, 255, 255), (0, 0, size, size//2), 2)
                    rotated_surface = pygame.transform.rotate(rect_surface, rotation)
                    
                elif shape == "circle":
                    # 원형 색종이 (더 선명하게)
                    circle_surface = pygame.Surface((size, size), pygame.SRCALPHA)
                    pygame.draw.circle(circle_surface, color, (size//2, size//2), size//2)
                    # 테두리 추가
                    pygame.draw.circle(circle_surface, (255, 255, 255), (size//2, size//2), size//2, 2)
                    rotated_surface = pygame.transform.rotate(circle_surface, rotation)
                    
                elif shape == "triangle":
                    # 삼각형 색종이 (새로 추가)
                    triangle_surface = pygame.Surface((size, size), pygame.SRCALPHA)
                    points = [
                        (size//2, 0),           # 상단
                        (0, size),              # 좌하단
                        (size, size)            # 우하단
                    ]
                    pygame.draw.polygon(triangle_surface, color, points)
                    # 테두리 추가
                    pygame.draw.polygon(triangle_surface, (255, 255, 255), points, 2)
                    rotated_surface = pygame.transform.rotate(triangle_surface, rotation)
                    
                else:  # star
                    # 별 모양 색종이 (다이아몬드, 더 선명하게)
                    star_surface = pygame.Surface((size, size), pygame.SRCALPHA)
                    points = [
                        (size//2, 0),           # 상단
                        (size, size//2),        # 우측
                        (size//2, size),        # 하단
                        (0, size//2)            # 좌측
                    ]
                    pygame.draw.polygon(star_surface, color, points)
                    # 테두리 추가
                    pygame.draw.polygon(star_surface, (255, 255, 255), points, 2)
                    rotated_surface = pygame.transform.rotate(star_surface, rotation)
                
                # 화면에 그리기 (더 선명하게)
                screen.blit(rotated_surface, (particle["x"] - rotated_surface.get_width()//2, 
                                            particle["y"] - rotated_surface.get_height()//2))
        
        # 홀로그램 컨테이너 (사이버펑크 스타일)
        container_width = 900
        container_height = 650
        container_x = (width - container_width) // 2
        container_y = (height - container_height) // 2 - 20
        
        # 홀로그램 글로우 효과 (여러 레이어)
        for i in range(5):
            glow_alpha = 100 - i * 18
            glow_surf = pygame.Surface((container_width + i*30, container_height + i*30), pygame.SRCALPHA)
            pygame.draw.rect(glow_surf, (0, 255, 255, glow_alpha), 
                           (0, 0, container_width + i*30, container_height + i*30), 
                           3, border_radius=20)
            screen.blit(glow_surf, (container_x - i*15, container_y - i*15))
        
        # 메인 컨테이너 배경
        container_surf = pygame.Surface((container_width, container_height), pygame.SRCALPHA)
        
        # 홀로그램 그라데이션 배경
        for y in range(container_height):
            ratio = y / container_height
            alpha = int(230 - ratio * 130)
            color = (int(0 + ratio * 30), int(40 + ratio * 40), int(80 + ratio * 50), alpha)
            pygame.draw.line(container_surf, color, (0, y), (container_width, y))
        
        screen.blit(container_surf, (container_x, container_y))
        
        # 네온 테두리
        main_container = pygame.Rect(container_x, container_y, container_width, container_height)
        pygame.draw.rect(screen, (0, 255, 255), main_container, 3, border_radius=15)
        pygame.draw.rect(screen, (255, 0, 255), 
                        pygame.Rect(container_x + 5, container_y + 5, container_width - 10, container_height - 10), 
                        2, border_radius=12)
        
        # 타이틀 영역 (홀로그램 패널)
        title_area = pygame.Rect(container_x + 50, container_y + 40, container_width - 100, 100)
        
        # 홀로그램 패널 배경
        panel_surf = pygame.Surface((container_width - 100, 100), pygame.SRCALPHA)
        pygame.draw.rect(panel_surf, (0, 50, 100, 150), (0, 0, container_width - 100, 100))
        screen.blit(panel_surf, (title_area.x, title_area.y))
        
        pygame.draw.rect(screen, (0, 255, 255), title_area, 2)
        
        # 축하 메시지 (사이버펑크 스타일)
        congrats_font = pygame.font.Font(resource_path("NanumSquareEB.ttf"), 56)
        congrats_text = "◆ 축하합니다! ◆"
        
        # 홀로그램 아이콘 (양쪽에)
        icon_left_x = width // 2 - 340
        icon_right_x = width // 2 + 340
        icon_y = container_y + 90
        
        # 왼쪽 홀로그램 아이콘
        pygame.draw.polygon(screen, (0, 255, 255), 
                           [(icon_left_x - 25, icon_y), 
                            (icon_left_x, icon_y - 30), 
                            (icon_left_x + 25, icon_y), 
                            (icon_left_x, icon_y + 30)], 2)
        pygame.draw.circle(screen, (255, 0, 255), (icon_left_x, icon_y), 18, 2)
        
        # 오른쪽 홀로그램 아이콘
        pygame.draw.polygon(screen, (0, 255, 255), 
                           [(icon_right_x - 25, icon_y), 
                            (icon_right_x, icon_y - 30), 
                            (icon_right_x + 25, icon_y), 
                            (icon_right_x, icon_y + 30)], 2)
        pygame.draw.circle(screen, (255, 0, 255), (icon_right_x, icon_y), 18, 2)
        
        # 메인 축하 메시지 (네온 글로우 효과)
        for i in range(3):
            glow_alpha = 150 - i * 40
            glow_surf = congrats_font.render(congrats_text, True, (0, 255, 255))
            glow_surf.set_alpha(glow_alpha)
            glow_rect = glow_surf.get_rect(center=(width // 2 - i*2, container_y + 90 - i*2))
            screen.blit(glow_surf, glow_rect)
        
        main_congrats = congrats_font.render(congrats_text, True, (255, 255, 255))
        main_rect = main_congrats.get_rect(center=(width // 2, container_y + 90))
        screen.blit(main_congrats, main_rect)
        
        # 서브타이틀
        subtitle_font = pygame.font.Font(resource_path("NanumSquareB.ttf"), 24)
        subtitle_text = "[ 아이템 획듍 성공 ]"
        subtitle_surf = subtitle_font.render(subtitle_text, True, (0, 200, 200))
        subtitle_rect = subtitle_surf.get_rect(center=(width // 2, container_y + 130))
        screen.blit(subtitle_surf, subtitle_rect)
        
        # 아이템 아이콘 (매우 크게 + 빛나는 효과 + 위아래 떠다니는 모션)
        if "icon" in gacha_result and gacha_result["icon"]:
            icon_center_x = width // 2
            # 위아래로 떠다니는 모션 (사인파) - 위치를 더 위로 조정
            float_offset = math.sin(animation_timer * 0.1) * 12  # 12픽셀 범위로 줄임
            icon_center_y = container_y + 240 + float_offset  # 더 위로 올림
            
            # 아이템 색상에 따른 빛나는 효과
            item_color = gacha_result["color"]
            
            # 1. 홀로그램 펄스 효과 (아이템 색상 기반)
            pulse_scale = 1 + 0.1 * math.sin(animation_timer * 0.05)
            for i in range(20):
                glow_alpha = 100 - i * 5
                glow_radius = int(60 * pulse_scale + i * 2)
                glow_surface = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surface, (*item_color, glow_alpha), (glow_radius, glow_radius), glow_radius)
                screen.blit(glow_surface, (icon_center_x - glow_radius, icon_center_y - glow_radius))
            
            # 2. 네온 글로우 (사이안)
            for i in range(15):
                glow_alpha = 120 - i * 8
                glow_radius = 48 + i * 2
                glow_surface = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surface, (0, 255, 255, glow_alpha), (glow_radius, glow_radius), glow_radius)
                screen.blit(glow_surface, (icon_center_x - glow_radius, icon_center_y - glow_radius))
            
            # 3. 코어 글로우 (흰색)
            for i in range(10):
                glow_alpha = 150 - i * 15
                glow_radius = 42 + i * 1
                glow_surface = pygame.Surface((glow_radius * 2, glow_radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(glow_surface, (255, 255, 255, glow_alpha), (glow_radius, glow_radius), glow_radius)
                screen.blit(glow_surface, (icon_center_x - glow_radius, icon_center_y - glow_radius))
            
            # 4. 메인 아이콘 (60% 크기로 줄임)
            icon = pygame.transform.scale(gacha_result["icon"], (120, 120))  # 200*0.6 = 120
            icon_rect = icon.get_rect(center=(icon_center_x, icon_center_y))
            screen.blit(icon, icon_rect)
            
            # 5. 홀로그램 테두리
            pygame.draw.circle(screen, (0, 255, 255), (icon_center_x, icon_center_y), 63, 3)
            pygame.draw.circle(screen, (255, 0, 255), (icon_center_x, icon_center_y), 63, 1)
            
            # 홀로그램 링 애니메이션
            ring_radius = 63 + 20 * abs(math.sin(animation_timer * 0.03))
            ring_alpha = int(100 * (1 - abs(math.sin(animation_timer * 0.03))))
            ring_surf = pygame.Surface((int(ring_radius * 2), int(ring_radius * 2)), pygame.SRCALPHA)
            pygame.draw.circle(ring_surf, (0, 255, 255, ring_alpha), (int(ring_radius), int(ring_radius)), int(ring_radius), 2)
            screen.blit(ring_surf, (icon_center_x - ring_radius, icon_center_y - ring_radius))
        
        # 아이템 이름 영역 (홀로그램 패널)
        name_area = pygame.Rect(container_x + 60, container_y + 350, container_width - 120, 80)
        
        # 홀로그램 패널 배경
        panel_surf = pygame.Surface((container_width - 120, 80), pygame.SRCALPHA)
        pygame.draw.rect(panel_surf, (0, 30, 60, 180), (0, 0, container_width - 120, 80))
        screen.blit(panel_surf, (name_area.x, name_area.y))
        
        pygame.draw.rect(screen, (0, 255, 255), name_area, 2)
        
        # 아이템 설명 영역 (홀로그램 패널)
        desc_area = pygame.Rect(container_x + 60, container_y + 450, container_width - 120, 100)
        
        # 홀로그램 패널 배경
        desc_panel_surf = pygame.Surface((container_width - 120, 100), pygame.SRCALPHA)
        pygame.draw.rect(desc_panel_surf, (0, 30, 60, 180), (0, 0, container_width - 120, 100))
        screen.blit(desc_panel_surf, (desc_area.x, desc_area.y))
        
        pygame.draw.rect(screen, (0, 255, 255), desc_area, 2)
        
        # 아이템 이름과 아이콘 (더 크고 깔끔하게)
        item_name = get_item_name_korean(gacha_result['name'])
        name_font = pygame.font.Font(resource_path("NanumSquareEB.ttf"), 42)
        name_text = item_name
        
        # 시너지 효과일 때 보라색으로 표시
        if gacha_result['name'] == "gravitybelt":
            # 시너지 상태를 확인하기 위해 전역 변수 접근 시도
            try:
                import bosspong
                if hasattr(bosspong, 'gravity_speed_synergy') and bosspong.gravity_speed_synergy:
                    name_color = (200, 100, 255)  # 밝은 보라색
                else:
                    name_color = (255, 255, 255)  # 흰색
            except:
                name_color = (255, 255, 255)  # 기본값
        else:
            name_color = (255, 255, 255)  # 흰색
        
        # 아이템 원래 크기 아이콘 (이름 영역 왼쪽에 배치)
        if "icon" in gacha_result and gacha_result["icon"]:
            # 원래 크기 아이콘 (64x64 또는 액티브 슬롯 크기)
            original_icon = pygame.transform.scale(gacha_result["icon"], (64, 64))
            icon_x = width // 2 - 200  # 아이템 이름에서 더 멀리 왼쪽에 배치 (간격 확보)
            icon_y = container_y + 390 - 32  # 이름 영역 중앙에 맞춤
            
            # 아이콘 배경 (둥근 테두리)
            pygame.draw.circle(screen, gacha_result["color"], (icon_x + 32, icon_y + 32), 36, 3)
            pygame.draw.circle(screen, (255, 255, 255), (icon_x + 32, icon_y + 32), 36, 2)
            
            # 아이콘 그리기
            screen.blit(original_icon, (icon_x, icon_y))
        
        # 메인 이름 (그림자 효과) - 이름 영역 중앙에 배치
        shadow_name = name_font.render(name_text, True, (50, 50, 50))
        main_name = name_font.render(name_text, True, name_color)
        main_name_rect = main_name.get_rect(center=(width // 2, container_y + 390))  # 이름 영역 중앙
        shadow_name_rect = main_name_rect.copy()
        shadow_name_rect.x += 3
        shadow_name_rect.y += 3
        screen.blit(shadow_name, shadow_name_rect)
        screen.blit(main_name, main_name_rect)
        
        # 텍스트 줄바꿈 함수
        def wrap_text(text, font, max_width):
            """텍스트를 지정된 너비에 맞게 균형잡힌 줄바꿈하는 함수"""
            words = text.split(' ')
            
            # 전체 텍스트가 한 줄에 들어가는지 확인
            full_text_width = font.size(text)[0]
            if full_text_width <= max_width:
                return [text]
            
            # 두 줄로 나누기 시도 (균형잡힌 분할)
            if len(words) >= 2:
                best_split = 1
                best_difference = float('inf')
                
                for split_point in range(1, len(words)):
                    line1 = " ".join(words[:split_point])
                    line2 = " ".join(words[split_point:])
                    
                    line1_width = font.size(line1)[0]
                    line2_width = font.size(line2)[0]
                    
                    # 두 줄 모두 최대 너비를 넘지 않는지 확인
                    if line1_width <= max_width and line2_width <= max_width:
                        # 두 줄의 길이 차이 계산 (균형도 측정)
                        difference = abs(line1_width - line2_width)
                        if difference < best_difference:
                            best_difference = difference
                            best_split = split_point
                
                # 최적의 분할점으로 나누기
                if best_difference != float('inf'):
                    line1 = " ".join(words[:best_split])
                    line2 = " ".join(words[best_split:])
                    return [line1, line2]
            
            # 균형잡힌 분할이 불가능하면 일반적인 줄바꿈 사용
            lines = []
            current_line = ""
            
            for word in words:
                test_line = current_line + (" " if current_line else "") + word
                test_width = font.size(test_line)[0]
                
                if test_width <= max_width:
                    current_line = test_line
                else:
                    if current_line:
                        lines.append(current_line)
                        current_line = word
                    else:
                        lines.append(word)
                        current_line = ""
            
            if current_line:
                lines.append(current_line)
            
            return lines
        
        # 아이템 설명 (줄바꿈 적용) - 설명 영역 내부에 배치
        item_description = get_item_description(gacha_result['name'])
        desc_font = pygame.font.Font(resource_path("NanumSquareR.ttf"), 24)  # 폰트 크기를 더 줄임
        
        # 설명 텍스트 최대 너비 (설명 영역 너비에서 여백 제외)
        max_desc_width = container_width - 180  # 양쪽 여백 90px씩
        
        # 텍스트 줄바꿈
        desc_lines = wrap_text(item_description, desc_font, max_desc_width)
        
        # 줄바꿈된 텍스트 그리기 - 설명 영역 중앙에 배치
        line_height = 28  # 줄 간격을 좀 더 촘촘하게
        desc_area_center_y = container_y + 500  # 설명 영역의 중앙 Y 좌표
        start_y = desc_area_center_y - (len(desc_lines) - 1) * line_height // 2
        
        for i, line in enumerate(desc_lines):
            desc_text = desc_font.render(line, True, (220, 220, 220))
            desc_rect = desc_text.get_rect(center=(width // 2, start_y + i * line_height))
            screen.blit(desc_text, desc_rect)
        
        # 계속하기 안내 영역 (설명 영역 아래에 배치)
        continue_area = pygame.Rect(container_x + 100, container_y + 570, container_width - 200, 60)
        pygame.draw.rect(screen, (60, 45, 25), continue_area)
        pygame.draw.rect(screen, (255, 215, 0), continue_area, 3)
        
        # 계속하기 안내 (시크하게 변경)
        continue_font = pygame.font.Font(resource_path("NanumSquareEB.ttf"), 36)
        continue_text = "아이템 받기"
        
        # 깜빡이는 효과
        blink_alpha = int(abs(math.sin(animation_timer * 0.1)) * 255)
        
        # 그림자 효과
        shadow_continue = continue_font.render(continue_text, True, (50, 50, 50))
        text_small = continue_font.render(continue_text, True, (255, 255, 255))
        text_small.set_alpha(blink_alpha)
        
        text_small_rect = text_small.get_rect(center=(width // 2, container_y + 600))
        shadow_continue_rect = text_small_rect.copy()
        shadow_continue_rect.x += 3
        shadow_continue_rect.y += 3
        
        # 그림자는 깜빡이지 않게
        screen.blit(shadow_continue, shadow_continue_rect)
        screen.blit(text_small, text_small_rect)
        
        pygame.display.flip()

def get_gacha_result():
    """뽑기 결과 반환"""
    return gacha_result 