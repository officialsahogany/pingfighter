"""
블루투스링 아이템 테스트
패들에 공이 닿을 때 게이지 충전량 25% 증가 효과 검증
"""

import pygame
import sys
import os
from item_effects.bluetooth_ring import (
    get_bluetooth_ring_instance, 
    activate_bluetooth_ring, 
    calculate_bluetooth_ring_gauge_charge,
    is_bluetooth_ring_active
)

# Pygame 초기화
pygame.init()

# 화면 설정
SCREEN_WIDTH = 600
SCREEN_HEIGHT = 750
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("블루투스링 테스트")

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
GREEN = (0, 255, 0)
BLUE = (100, 150, 255)
BLUETOOTH_BLUE = (100, 150, 255)
YELLOW = (255, 255, 100)
ORANGE = (255, 150, 50)

# 폰트 설정
try:
    font_path = "DungGeunMo.ttf"
    if os.path.exists(font_path):
        font = pygame.font.Font(font_path, 24)
        font_small = pygame.font.Font(font_path, 20)
    else:
        font = pygame.font.Font(None, 36)
        font_small = pygame.font.Font(None, 24)
except:
    font = pygame.font.Font(None, 36)
    font_small = pygame.font.Font(None, 24)

# 게임 상태 시뮬레이션
class GameState:
    def __init__(self):
        self.max_gauge = 500  # 기본 최대 게이지
        self.gauge = 0  # 현재 게이지
        self.base_charge = 30  # 기본 충전량
        self.total_hits = 0  # 총 패들 히트 수
        self.total_charge = 0  # 총 충전량

# 게임 상태 초기화
game_state = GameState()

# 테스트 변수
clock = pygame.time.Clock()
paddle_rect = pygame.Rect(250, 600, 100, 20)
ball_rect = pygame.Rect(300, 400, 20, 20)
ball_vel = [5, 5]

def simulate_paddle_hit(game_state):
    """패들 히트 시뮬레이션"""
    base_charge = game_state.base_charge
    
    # 블루투스링이 활성화된 경우 충전량 증가
    if is_bluetooth_ring_active():
        actual_charge = calculate_bluetooth_ring_gauge_charge(base_charge)
    else:
        actual_charge = base_charge
    
    game_state.gauge += actual_charge
    if game_state.gauge > game_state.max_gauge:
        game_state.gauge = game_state.max_gauge
    
    game_state.total_hits += 1
    game_state.total_charge += actual_charge
    
    return actual_charge

def draw_gauge_bar(screen, x, y, width, height, current, max_val, color):
    """게이지 바 그리기"""
    # 배경
    pygame.draw.rect(screen, (50, 50, 50), (x, y, width, height))
    # 게이지
    if max_val > 0:
        fill_width = int((current / max_val) * width)
        pygame.draw.rect(screen, color, (x, y, fill_width, height))
    # 테두리
    pygame.draw.rect(screen, WHITE, (x, y, width, height), 2)
    
    # 게이지 텍스트
    gauge_text = font_small.render(f"{current}/{max_val}", True, WHITE)
    text_rect = gauge_text.get_rect(center=(x + width // 2, y + height // 2))
    screen.blit(gauge_text, text_rect)

def draw_test_ui(screen, game_state):
    """테스트 UI 그리기"""
    screen.fill(BLACK)
    
    # 제목
    title = font.render("블루투스링 테스트", True, WHITE)
    screen.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, 50))
    
    # 아이템 상태
    ring = get_bluetooth_ring_instance()
    status_text = "활성화" if ring.active else "비활성화"
    status_color = BLUETOOTH_BLUE if ring.active else WHITE
    status = font_small.render(f"블루투스링 상태: {status_text}", True, status_color)
    screen.blit(status, (50, 150))
    
    # 충전량 배율 표시
    if ring.active:
        multiplier = ring.get_gauge_charge_multiplier()
        bonus_text = font_small.render(f"충전량 배율: x{multiplier:.2f} (+25%)", True, BLUETOOTH_BLUE)
        screen.blit(bonus_text, (50, 200))
    else:
        bonus_text = font_small.render("충전량 배율: x1.00 (기본)", True, WHITE)
        screen.blit(bonus_text, (50, 200))
    
    # 통계 정보
    stats_y = 250
    stats = [
        f"패들 히트 횟수: {game_state.total_hits}",
        f"기본 충전량: {game_state.base_charge}",
        f"실제 충전량: {int(game_state.base_charge * (1.25 if ring.active else 1.0))}",
        f"총 충전량: {game_state.total_charge}"
    ]
    
    for stat in stats:
        text = font_small.render(stat, True, WHITE)
        screen.blit(text, (50, stats_y))
        stats_y += 35
    
    # 게이지 바 그리기
    draw_gauge_bar(screen, 50, 420, 500, 40, game_state.gauge, game_state.max_gauge, BLUE)
    
    # 시뮬레이션 비주얼
    # 패들 그리기
    pygame.draw.rect(screen, GREEN, paddle_rect)
    
    # 공 그리기
    pygame.draw.circle(screen, WHITE, ball_rect.center, 10)
    
    # 블루투스링 이펙트 (활성화 시)
    if ring.active:
        # 패들 주변에 블루투스 글로우 효과
        for i in range(3):
            alpha = 100 - i * 30
            glow_surf = pygame.Surface((paddle_rect.width + i * 10, paddle_rect.height + i * 10), pygame.SRCALPHA)
            glow_surf.fill((*BLUETOOTH_BLUE, alpha))
            screen.blit(glow_surf, (paddle_rect.x - i * 5, paddle_rect.y - i * 5))
        
        # 블루투스 아이콘 표시
        icon_x = paddle_rect.right + 15
        icon_y = paddle_rect.centery
        pygame.draw.circle(screen, BLUETOOTH_BLUE, (icon_x, icon_y), 12)
        b_text = font_small.render("B", True, WHITE)
        b_rect = b_text.get_rect(center=(icon_x, icon_y))
        screen.blit(b_text, b_rect)
    
    # 컨트롤 안내
    controls = [
        "SPACE: 블루투스링 활성화/비활성화",
        "P: 패들 히트 시뮬레이션",
        "R: 게이지 리셋",
        "↑/↓: 기본 충전량 조절",
        "ESC: 종료"
    ]
    
    y = 520
    for control in controls:
        text = font_small.render(control, True, (200, 200, 200))
        screen.blit(text, (50, y))
        y += 30
    
    # 아이콘 테스트 (아이콘이 있는 경우)
    try:
        icon = pygame.image.load("items/bluetooth_ring.png").convert_alpha()
        icon = pygame.transform.scale(icon, (64, 64))
        screen.blit(icon, (SCREEN_WIDTH - 150, 150))
        icon_label = font_small.render("아이콘", True, WHITE)
        screen.blit(icon_label, (SCREEN_WIDTH - 140, 220))
    except:
        pass

# 메인 루프
running = True
auto_test = False
auto_timer = 0

while running:
    dt = clock.tick(60)
    
    # 자동 테스트 모드
    if auto_test:
        auto_timer += dt
        if auto_timer > 500:  # 0.5초마다
            charge = simulate_paddle_hit(game_state)
            print(f"패들 히트! 충전량: {charge} (총: {game_state.gauge}/{game_state.max_gauge})")
            auto_timer = 0
    
    # 공 움직임 (시각적 효과용)
    ball_rect.x += ball_vel[0]
    ball_rect.y += ball_vel[1]
    
    if ball_rect.left <= 0 or ball_rect.right >= SCREEN_WIDTH:
        ball_vel[0] = -ball_vel[0]
    if ball_rect.top <= 0 or ball_rect.bottom >= SCREEN_HEIGHT:
        ball_vel[1] = -ball_vel[1]
    
    # 패들과 공 충돌 체크
    if ball_rect.colliderect(paddle_rect) and ball_vel[1] > 0:
        ball_vel[1] = -ball_vel[1]
        charge = simulate_paddle_hit(game_state)
        print(f"패들 히트! 충전량: {charge} (총: {game_state.gauge}/{game_state.max_gauge})")
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                # 블루투스링 활성화/비활성화 토글
                ring = get_bluetooth_ring_instance()
                if not ring.active:
                    print("블루투스링 활성화")
                    activate_bluetooth_ring({}, 1)  # current_stage = 1
                else:
                    print("블루투스링 비활성화")
                    ring.deactivate()
            elif event.key == pygame.K_p:
                # 패들 히트 시뮬레이션
                charge = simulate_paddle_hit(game_state)
                print(f"수동 패들 히트! 충전량: {charge}")
            elif event.key == pygame.K_r:
                # 게이지 리셋
                game_state.gauge = 0
                game_state.total_hits = 0
                game_state.total_charge = 0
                print("게이지 리셋")
            elif event.key == pygame.K_UP:
                # 기본 충전량 증가
                game_state.base_charge += 5
                print(f"기본 충전량: {game_state.base_charge}")
            elif event.key == pygame.K_DOWN:
                # 기본 충전량 감소
                game_state.base_charge = max(5, game_state.base_charge - 5)
                print(f"기본 충전량: {game_state.base_charge}")
            elif event.key == pygame.K_a:
                # 자동 테스트 토글
                auto_test = not auto_test
                print(f"자동 테스트: {'ON' if auto_test else 'OFF'}")
    
    # 화면 그리기
    draw_test_ui(screen, game_state)
    
    pygame.display.flip()

# 종료
pygame.quit()
sys.exit()