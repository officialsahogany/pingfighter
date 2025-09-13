"""
스마트폰 패시브 아이템 디버그 테스트
자동 치유 기능과 위험 감지 기능을 테스트합니다.
"""

import pygame
import sys
import os
import math
import time

# 경로 설정
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 모듈 임포트
import items
from item_effects.smartphone import get_smartphone_instance

# Pygame 초기화
pygame.init()

# 화면 설정
WIDTH = 800
HEIGHT = 750
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("스마트폰 아이템 디버그 테스트")

# 색상
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
YELLOW = (255, 255, 0)

# 글로벌 변수 설정 (게임에서 사용하는 변수들)
PADDLE_WIDTH = 155
PADDLE_HEIGHT = 50
special_gauge = 80  # 낮은 게이지로 시작
active_item_slot = []
selected_item_index = 0
sfx_volume = 0.7
last_hit_by = "player"
rolling_charges = 1
rolling_active = False

# 플레이어와 공
PLAYER = pygame.Rect(50, HEIGHT - 150, PADDLE_WIDTH, PADDLE_HEIGHT)
BALL = pygame.Rect(400, 300, 20, 20)
ball_vel = [-5, 10]

# 사운드 더미
class DummySound:
    def set_volume(self, vol):
        pass
    def play(self):
        print("♪ 사운드 재생됨")

SOUND_DRINK = DummySound()

def get_max_gauge():
    return 550

def draw_status(screen, font):
    """상태 정보 그리기"""
    y_pos = 10
    status_texts = [
        f"스마트폰 획득: {items.smartphone_obtained}",
        f"게이지: {special_gauge}/550",
        f"활성 아이템: {len(active_item_slot)}개",
        f"공 위치: ({BALL.centerx:.0f}, {BALL.centery:.0f})",
        f"공 속도: ({ball_vel[0]:.1f}, {ball_vel[1]:.1f})",
        f"플레이어 Y: {PLAYER.centery}",
        ""
    ]
    
    # 스마트폰 상태
    smartphone = get_smartphone_instance()
    if smartphone and smartphone.active:
        status_texts.append(f"스마트폰 활성화: {smartphone.active}")
        status_texts.append(f"쿨타임: {smartphone.last_activation_time}")
        status_texts.append(f"자동 발동 여부: {smartphone.auto_activated}")
    
    for text in status_texts:
        text_surface = font.render(text, True, WHITE)
        screen.blit(text_surface, (10, y_pos))
        y_pos += 25

def main():
    global special_gauge, active_item_slot, BALL, ball_vel, last_hit_by
    
    clock = pygame.time.Clock()
    font = pygame.font.Font(None, 24)
    running = True
    
    # 스마트폰 획득 시뮬레이션
    print("\n=== 스마트폰 아이템 획득 시뮬레이션 ===")
    items.smartphone_obtained = True
    smartphone = get_smartphone_instance()
    
    # 스마트폰 활성화
    game_state = {
        'current_stage': 1,
        'active_items': active_item_slot
    }
    smartphone.activate(game_state, None)
    print(f"스마트폰 활성화 상태: {smartphone.active}")
    
    # 테스트용 아이템 추가
    print("\n=== 테스트 아이템 추가 ===")
    
    # 생명수 추가
    active_item_slot.append({
        'name': 'life_elixir',
        'effect': 'gauge_charge_500'
    })
    print("생명수 추가됨")
    
    # 에너지드링크 추가
    active_item_slot.append({
        'name': 'gauge_charge',
        'effect': 'gauge_charge_220'
    })
    print("에너지드링크 추가됨")
    
    # 스탑워치 추가
    active_item_slot.append({
        'name': 'stopwatch',
        'effect': 'slowtime'
    })
    print("스탑워치 추가됨")
    
    frame_count = 0
    auto_heal_tested = False
    danger_tested = False
    
    while running:
        frame_count += 1
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_SPACE:
                    # 게이지 감소 (자동 치유 테스트)
                    special_gauge = 50
                    print(f"\n[테스트] 게이지를 {special_gauge}로 감소시킴")
                elif event.key == pygame.K_d:
                    # 위험 상황 시뮬레이션
                    BALL.center = (PLAYER.centerx + 100, PLAYER.centery - 20)
                    ball_vel = [-15, 8]  # 빠르게 플레이어 방향으로
                    last_hit_by = "boss"
                    print(f"\n[테스트] 위험 상황 시뮬레이션 - 공이 빠르게 접근")
                elif event.key == pygame.K_r:
                    # 리셋
                    special_gauge = 80
                    BALL.center = (400, 300)
                    ball_vel = [-5, 10]
                    smartphone.last_activation_time = 0
                    smartphone.auto_activated = False
                    print("\n[테스트] 상황 리셋")
        
        # 공 이동
        BALL.x += ball_vel[0]
        BALL.y += ball_vel[1]
        
        # 벽 충돌
        if BALL.left <= 0 or BALL.right >= WIDTH:
            ball_vel[0] = -ball_vel[0]
        if BALL.top <= 0 or BALL.bottom >= HEIGHT:
            ball_vel[1] = -ball_vel[1]
        
        # 스마트폰 업데이트 (메인 게임 루프처럼)
        if smartphone and smartphone.active:
            # StageInfo 클래스 시뮬레이션
            class StageInfo:
                def __init__(self):
                    self.ball_x = BALL.centerx
                    self.ball_y = BALL.centery
                    self.ball_vx = ball_vel[0]
                    self.ball_vy = ball_vel[1]
                    self.paddle_y = PLAYER.centery
                    self.paddle_size = PADDLE_HEIGHT
            
            stage_info = StageInfo()
            smartphone_state = {
                'current_stage': 1,
                'active_items': active_item_slot
            }
            
            # 업데이트 호출
            smartphone.update(smartphone_state, stage_info)
            
            # 자동 치유 테스트 로그
            if special_gauge <= 120 and not auto_heal_tested and frame_count > 60:
                print(f"\n[자동 치유 테스트] 게이지가 {special_gauge}입니다.")
                print(f"활성 아이템: {[item['name'] for item in active_item_slot]}")
                print(f"스마트폰 쿨타임: {smartphone.last_activation_time}")
                auto_heal_tested = True
                
                # 잠시 후 결과 확인
                if frame_count > 120:
                    if special_gauge > 120:
                        print(f"✅ 자동 치유 성공! 게이지: {special_gauge}")
                    else:
                        print(f"❌ 자동 치유 실패. 게이지: {special_gauge}")
        
        # 화면 그리기
        screen.fill(BLACK)
        
        # 플레이어 그리기
        pygame.draw.rect(screen, GREEN, PLAYER)
        
        # 공 그리기
        pygame.draw.circle(screen, RED, BALL.center, 10)
        
        # 공 속도 벡터 그리기
        end_x = BALL.centerx + ball_vel[0] * 5
        end_y = BALL.centery + ball_vel[1] * 5
        pygame.draw.line(screen, YELLOW, BALL.center, (end_x, end_y), 2)
        
        # 상태 정보 그리기
        draw_status(screen, font)
        
        # 사용법 안내
        help_texts = [
            "스페이스: 게이지 감소 (자동 치유 테스트)",
            "D: 위험 상황 시뮬레이션",
            "R: 리셋",
            "ESC: 종료"
        ]
        y_pos = HEIGHT - 100
        for text in help_texts:
            text_surface = font.render(text, True, YELLOW)
            screen.blit(text_surface, (10, y_pos))
            y_pos += 25
        
        pygame.display.flip()
        clock.tick(60)
        
        # ESC 키로 종료
        keys = pygame.key.get_pressed()
        if keys[pygame.K_ESCAPE]:
            running = False
    
    pygame.quit()
    print("\n테스트 종료")

if __name__ == "__main__":
    main()