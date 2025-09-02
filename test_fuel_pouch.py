"""
연료파우치 아이템 테스트
최대 스킬 게이지 증가 효과 검증
"""

import pygame
import sys
import os
from item_effects.fuel_pouch import get_fuel_pouch_instance, activate_fuel_pouch, get_fuel_pouch_gauge_bonus

# Pygame 초기화
pygame.init()

# 화면 설정
SCREEN_WIDTH = 600
SCREEN_HEIGHT = 750
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("연료파우치 테스트")

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
GREEN = (0, 255, 0)
BLUE = (100, 150, 255)
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
        self.max_gauge = 1000  # 기본 최대 게이지
        self.gauge = 500  # 현재 게이지
        
    def get_max_gauge(self):
        """연료파우치 보너스를 포함한 최대 게이지 반환"""
        fuel_pouch_bonus = get_fuel_pouch_gauge_bonus()
        return self.max_gauge + fuel_pouch_bonus

# 게임 상태 초기화
game_state = {
    'max_gauge': 1000,
    'gauge': 500
}

# 테스트 변수
fuel_pouch_active = False
original_max_gauge = game_state['max_gauge']
clock = pygame.time.Clock()

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

def draw_test_ui(screen, game_state):
    """테스트 UI 그리기"""
    screen.fill(BLACK)
    
    # 제목
    title = font.render("연료파우치 테스트", True, WHITE)
    screen.blit(title, (SCREEN_WIDTH // 2 - title.get_width() // 2, 50))
    
    # 아이템 상태
    pouch = get_fuel_pouch_instance()
    status_text = "활성화" if pouch.active else "비활성화"
    status_color = GREEN if pouch.active else WHITE
    status = font_small.render(f"연료파우치 상태: {status_text}", True, status_color)
    screen.blit(status, (50, 150))
    
    # 게이지 보너스 표시
    bonus = get_fuel_pouch_gauge_bonus()
    bonus_text = font_small.render(f"게이지 보너스: +{bonus}", True, YELLOW)
    screen.blit(bonus_text, (50, 200))
    
    # 최대 게이지 정보
    fuel_pouch_bonus = get_fuel_pouch_gauge_bonus()
    max_gauge_with_bonus = game_state['max_gauge'] + fuel_pouch_bonus
    
    max_text = font_small.render(f"기본 최대 게이지: {game_state['max_gauge']}", True, WHITE)
    screen.blit(max_text, (50, 250))
    
    total_text = font_small.render(f"총 최대 게이지: {max_gauge_with_bonus}", True, ORANGE)
    screen.blit(total_text, (50, 300))
    
    # 현재 게이지 표시
    current_text = font_small.render(f"현재 게이지: {game_state['gauge']} / {max_gauge_with_bonus}", True, WHITE)
    screen.blit(current_text, (50, 350))
    
    # 게이지 바 그리기
    draw_gauge_bar(screen, 50, 400, 500, 30, game_state['gauge'], max_gauge_with_bonus, BLUE)
    
    # 컨트롤 안내
    controls = [
        "SPACE: 연료파우치 활성화/비활성화",
        "↑/↓: 게이지 증가/감소 (테스트용)",
        "R: 게이지 리셋",
        "ESC: 종료"
    ]
    
    y = 500
    for control in controls:
        text = font_small.render(control, True, WHITE)
        screen.blit(text, (50, y))
        y += 40
    
    # 아이콘 테스트 (아이콘이 있는 경우)
    try:
        icon = pygame.image.load("items/fuel_pouch.png").convert_alpha()
        icon = pygame.transform.scale(icon, (64, 64))
        screen.blit(icon, (SCREEN_WIDTH - 150, 150))
        icon_label = font_small.render("아이콘", True, WHITE)
        screen.blit(icon_label, (SCREEN_WIDTH - 140, 220))
    except:
        pass

# 메인 루프
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                # 연료파우치 활성화/비활성화 토글
                pouch = get_fuel_pouch_instance()
                if not pouch.active:
                    print("연료파우치 활성화")
                    activate_fuel_pouch(game_state, 1)  # current_stage = 1로 설정
                else:
                    print("연료파우치 비활성화")
                    pouch.deactivate()
                    # 게이지 원래대로 복원
                    game_state['max_gauge'] = original_max_gauge
                    if game_state['gauge'] > game_state['max_gauge']:
                        game_state['gauge'] = game_state['max_gauge']
            elif event.key == pygame.K_UP:
                # 게이지 증가
                fuel_pouch_bonus = get_fuel_pouch_gauge_bonus()
                max_gauge = game_state['max_gauge'] + fuel_pouch_bonus
                game_state['gauge'] = min(game_state['gauge'] + 100, max_gauge)
            elif event.key == pygame.K_DOWN:
                # 게이지 감소
                game_state['gauge'] = max(game_state['gauge'] - 100, 0)
            elif event.key == pygame.K_r:
                # 게이지 리셋
                game_state['gauge'] = 500
    
    # 화면 그리기
    draw_test_ui(screen, game_state)
    
    # 디버그 정보 출력 (콘솔)
    pouch = get_fuel_pouch_instance()
    if pouch.active and pygame.time.get_ticks() % 60 == 0:  # 1초마다
        print(f"[DEBUG] 활성화: {pouch.active}, 보너스: {pouch.get_gauge_bonus()}, "
              f"최대 게이지: {game_state['max_gauge'] + pouch.get_gauge_bonus()}")
    
    pygame.display.flip()
    clock.tick(60)

# 종료
pygame.quit()
sys.exit()