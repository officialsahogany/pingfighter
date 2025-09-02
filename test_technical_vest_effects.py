"""
테크니컬조끼 연막 효과 테스트 - 실제 연막탄과 동일한 효과 확인
"""

import pygame
import sys
import random
import math
from item_effects.technical_vest import get_technical_vest_instance

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH, HEIGHT = 600, 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("테크니컬조끼 효과 테스트")

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
BLUE = (0, 0, 255)
YELLOW = (255, 255, 0)
GREEN = (0, 255, 0)
PURPLE = (200, 0, 255)
ORANGE = (255, 165, 0)

# 테스트 객체들
player_rect = pygame.Rect(WIDTH // 2 - 50, HEIGHT - 150, 100, 15)
fireballs = []  # Stage 5 화염탄
missiles = []   # Stage 6 미사일
laser_active = False  # Stage 6 레이저
tears = []      # Stage 3 눈물
fire_zones = []  # Stage 5 화염지대

# 테크니컬조끼 인스턴스
technical_vest = get_technical_vest_instance()
technical_vest.activate({}, 1)

# 폰트 설정
font = pygame.font.Font(None, 24)
small_font = pygame.font.Font(None, 18)

# 타이머와 상태
test_mode = 0  # 0: 대기, 1: 화염탄, 2: 미사일, 3: 레이저, 4: 눈물, 5: 화염지대
protection_active = False
protection_message = ""

clock = pygame.time.Clock()
running = True

while running:
    dt = clock.tick(60)
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                # 연막 수동 발동
                technical_vest.on_ball_paddle_collision(player_rect)
                protection_active = True
            elif event.key == pygame.K_1:
                # 화염탄 테스트
                test_mode = 1
                fireballs.append({
                    'x': random.randint(50, WIDTH-50),
                    'y': 50,
                    'vy': 3
                })
            elif event.key == pygame.K_2:
                # 미사일 테스트
                test_mode = 2
                missiles.append({
                    'x': random.randint(50, WIDTH-50),
                    'y': 50,
                    'vx': random.uniform(-1, 1),
                    'vy': 3
                })
            elif event.key == pygame.K_3:
                # 레이저 테스트
                test_mode = 3
                laser_active = True
            elif event.key == pygame.K_4:
                # 눈물 테스트
                test_mode = 4
                tears.append({
                    'x': random.randint(50, WIDTH-50),
                    'y': 50,
                    'vy': 2
                })
            elif event.key == pygame.K_5:
                # 화염지대 테스트
                test_mode = 5
                fire_zones.append({
                    'x': player_rect.centerx,
                    'y': player_rect.centery,
                    'radius': 100,
                    'timer': 300
                })
    
    # 마우스로 플레이어 이동
    mouse_x, _ = pygame.mouse.get_pos()
    player_rect.centerx = mouse_x
    
    # 테크니컬조끼 업데이트
    technical_vest.update(player_rect)
    
    # 연막 안에 있는지 확인
    protection_active = technical_vest.check_smoke_collision(
        player_rect.centerx, player_rect.centery
    )
    
    # 화염탄 업데이트
    for fireball in fireballs[:]:
        fireball['y'] += fireball['vy']
        # 플레이어와 충돌 체크
        if abs(fireball['x'] - player_rect.centerx) < 30 and \
           abs(fireball['y'] - player_rect.centery) < 30:
            if protection_active:
                protection_message = "화염탄 방어 성공!"
                fireballs.remove(fireball)
            else:
                protection_message = "화염탄 피격!"
                fireballs.remove(fireball)
        elif fireball['y'] > HEIGHT:
            fireballs.remove(fireball)
    
    # 미사일 업데이트
    for missile in missiles[:]:
        missile['x'] += missile['vx']
        missile['y'] += missile['vy']
        # 플레이어와 충돌 체크
        if abs(missile['x'] - player_rect.centerx) < 30 and \
           abs(missile['y'] - player_rect.centery) < 20:
            if protection_active:
                protection_message = "미사일 방어 성공!"
                missiles.remove(missile)
            else:
                protection_message = "미사일 피격!"
                missiles.remove(missile)
        elif missile['y'] > HEIGHT:
            missiles.remove(missile)
    
    # 레이저 체크
    if laser_active:
        if protection_active:
            protection_message = "레이저 스턴 방어!"
        else:
            protection_message = "레이저 스턴!"
        laser_active = False
    
    # 눈물 업데이트
    for tear in tears[:]:
        tear['y'] += tear['vy']
        # 플레이어와 충돌 체크
        if abs(tear['x'] - player_rect.centerx) < 20 and \
           abs(tear['y'] - player_rect.centery) < 20:
            if protection_active:
                protection_message = "눈물샤워 방어 성공!"
                tears.remove(tear)
            else:
                protection_message = "눈물샤워 피격!"
                tears.remove(tear)
        elif tear['y'] > HEIGHT:
            tears.remove(tear)
    
    # 화염지대 업데이트
    for zone in fire_zones[:]:
        zone['timer'] -= 1
        if zone['timer'] <= 0:
            fire_zones.remove(zone)
        else:
            # 플레이어와 충돌 체크
            dist = math.sqrt((zone['x'] - player_rect.centerx)**2 + 
                           (zone['y'] - player_rect.centery)**2)
            if dist < zone['radius']:
                if protection_active:
                    protection_message = "화염지대 넉백 면역!"
                else:
                    protection_message = "화염지대 넉백!"
    
    # 화면 그리기
    screen.fill(BLACK)
    
    # 배경 그리드
    for x in range(0, WIDTH, 50):
        pygame.draw.line(screen, (30, 30, 30), (x, 0), (x, HEIGHT))
    for y in range(0, HEIGHT, 50):
        pygame.draw.line(screen, (30, 30, 30), (0, y), (WIDTH, y))
    
    # 연막 효과 그리기
    technical_vest.draw_effects(screen)
    
    # 플레이어 그리기
    color = GREEN if protection_active else BLUE
    pygame.draw.rect(screen, color, player_rect)
    pygame.draw.rect(screen, WHITE, player_rect, 2)
    
    # 화염탄 그리기
    for fireball in fireballs:
        pygame.draw.circle(screen, ORANGE, (int(fireball['x']), int(fireball['y'])), 10)
        pygame.draw.circle(screen, RED, (int(fireball['x']), int(fireball['y'])), 7)
    
    # 미사일 그리기
    for missile in missiles:
        pygame.draw.circle(screen, PURPLE, (int(missile['x']), int(missile['y'])), 5)
    
    # 눈물 그리기
    for tear in tears:
        pygame.draw.circle(screen, (100, 100, 255), (int(tear['x']), int(tear['y'])), 5)
    
    # 화염지대 그리기
    for zone in fire_zones:
        alpha = zone['timer'] / 300 * 100
        pygame.draw.circle(screen, (255, 100, 0), 
                         (int(zone['x']), int(zone['y'])), 
                         zone['radius'], 2)
    
    # UI 텍스트
    title = font.render("테크니컬조끼 효과 테스트", True, WHITE)
    screen.blit(title, (WIDTH // 2 - title.get_width() // 2, 20))
    
    # 상태 표시
    status_text = "연막 보호: 활성" if protection_active else "연막 보호: 비활성"
    status_color = GREEN if protection_active else RED
    status = font.render(status_text, True, status_color)
    screen.blit(status, (10, 60))
    
    # 보호 메시지
    if protection_message:
        msg_color = GREEN if "성공" in protection_message or "면역" in protection_message else RED
        msg = font.render(protection_message, True, msg_color)
        screen.blit(msg, (WIDTH // 2 - msg.get_width() // 2, 100))
    
    # 조작법
    controls = [
        "SPACE: 연막 발동 (30% 확률)",
        "1: 화염탄 테스트 (Stage 5)",
        "2: 미사일 테스트 (Stage 6)",
        "3: 레이저 테스트 (Stage 6)",
        "4: 눈물샤워 테스트 (Stage 3)",
        "5: 화염지대 테스트 (Stage 5)",
        "마우스: 패들 이동"
    ]
    
    y_pos = HEIGHT - 180
    for control in controls:
        text = small_font.render(control, True, (200, 200, 200))
        screen.blit(text, (10, y_pos))
        y_pos += 25
    
    # 효과 리스트
    effects = [
        "✓ 화염탄 면역 (Stage 5)",
        "✓ 미사일 면역 (Stage 6)",
        "✓ 레이저 스턴 면역 (Stage 6)",
        "✓ 눈물샤워 면역 (Stage 3)",
        "✓ 화염지대 넉백 면역 (Stage 5)"
    ]
    
    y_pos = 150
    for effect in effects:
        color = GREEN if protection_active else (150, 150, 150)
        text = small_font.render(effect, True, color)
        screen.blit(text, (WIDTH - 250, y_pos))
        y_pos += 25
    
    pygame.display.flip()

pygame.quit()
sys.exit()