#!/usr/bin/env python3
"""
라그나로크 해머 부드러운 넉백 테스트
0.6초 넉백 + 단계별 감속 테스트
"""

import pygame
import sys
import os
import math

# 게임 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 상수 정의
WIDTH = 600
HEIGHT = 750
FPS = 60
PADDLE_WIDTH = 100

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("라그나로크 해머 넉백 테스트")
clock = pygame.time.Clock()

# 폰트 설정
font = pygame.font.Font(None, 24)
big_font = pygame.font.Font(None, 36)

# 보스 패들
boss_x = 250
boss_y = 50
boss_width = PADDLE_WIDTH
boss_height = 20

# 넉백 관련 변수
boss_knockback_timer = 0
boss_knockback_vel = 0
boss_stun_timer = 0
ragnarok_stun_pending = 0

# 시각화를 위한 위치 기록
position_history = []
max_history = 100

def calculate_knockback_test(ball_speed=20):
    """넉백 계산 테스트"""
    global boss_knockback_timer, boss_knockback_vel, ragnarok_stun_pending
    
    # legendary_items의 calculate_knockback 시뮬레이션
    horizontal_power = 10  # 기본 파워
    speed_bonus = abs(ball_speed) * 0.5  # 공속 보너스
    horizontal_power += speed_bonus
    
    # 보스 위치에 따른 방향 결정
    if boss_x + 50 < 300:
        horizontal_velocity = horizontal_power
    else:
        horizontal_velocity = -horizontal_power
    
    # 공속 보너스
    if abs(ball_speed) >= 25:
        horizontal_velocity *= 1.15
    elif abs(ball_speed) >= 20:
        horizontal_velocity *= 1.1
    elif abs(ball_speed) >= 15:
        horizontal_velocity *= 1.05
    
    # 랜덤 요소 (중간값 사용)
    horizontal_velocity *= 1.2
    
    # 넉백 설정
    boss_knockback_timer = 36  # 0.6초
    boss_knockback_vel = horizontal_velocity
    ragnarok_stun_pending = 60  # 1초 스턴
    
    return horizontal_velocity

def update_knockback():
    """넉백 업데이트 (실제 게임 로직)"""
    global boss_x, boss_knockback_timer, boss_knockback_vel, boss_stun_timer, ragnarok_stun_pending
    
    if boss_knockback_timer > 0:
        boss_knockback_timer -= 1
        
        # 수평 넉백 적용
        if abs(boss_knockback_vel) > 0.1:
            boss_x += boss_knockback_vel
            boss_x = max(0, min(WIDTH - PADDLE_WIDTH, boss_x))
            
            # 단계별 감속
            if boss_knockback_timer > 24:  # 처음 0.2초
                boss_knockback_vel *= 0.92
            elif boss_knockback_timer > 12:  # 중간 0.2초
                boss_knockback_vel *= 0.95
            else:  # 마지막 0.2초
                boss_knockback_vel *= 0.98
        
        # 넉백 종료 시 스턴 적용
        if boss_knockback_timer <= 1 and ragnarok_stun_pending > 0:
            boss_stun_timer = ragnarok_stun_pending
            ragnarok_stun_pending = 0
    
    # 스턴 처리
    if boss_stun_timer > 0:
        boss_stun_timer -= 1

def draw_scene():
    """화면 그리기"""
    screen.fill((20, 20, 30))
    
    # 위치 히스토리 그리기 (궤적)
    for i, pos in enumerate(position_history):
        alpha = int(255 * (i / len(position_history)))
        color = (alpha//2, alpha//4, alpha//2)
        pygame.draw.rect(screen, color, (pos, boss_y, boss_width, boss_height), 1)
    
    # 보스 패들 그리기
    if boss_stun_timer > 0:
        # 스턴 중 - 노란색으로 깜빡임
        if boss_stun_timer % 10 < 5:
            color = (255, 255, 0)
        else:
            color = (200, 200, 0)
    elif boss_knockback_timer > 0:
        # 넉백 중 - 붉은색
        intensity = int(255 * (boss_knockback_timer / 36))
        color = (255, 100 + intensity//2, 100)
    else:
        # 일반 상태
        color = (100, 100, 255)
    
    pygame.draw.rect(screen, color, (boss_x, boss_y, boss_width, boss_height))
    
    # 정보 표시
    y_offset = 150
    info_texts = [
        f"넉백 타이머: {boss_knockback_timer}/36 프레임",
        f"넉백 속도: {boss_knockback_vel:.2f}",
        f"스턴 타이머: {boss_stun_timer}/60 프레임",
        f"보스 X 위치: {boss_x:.1f}",
        "",
        "SPACE: 라그나로크 해머 발동",
        "R: 리셋",
        "ESC: 종료"
    ]
    
    for i, text in enumerate(info_texts):
        if text:
            text_surface = font.render(text, True, (255, 255, 255))
            screen.blit(text_surface, (20, y_offset + i * 30))
    
    # 단계별 감속 구간 표시
    if boss_knockback_timer > 0:
        stage_text = ""
        if boss_knockback_timer > 24:
            stage_text = "빠른 감속 단계 (0.92x)"
            color = (255, 100, 100)
        elif boss_knockback_timer > 12:
            stage_text = "중간 감속 단계 (0.95x)"
            color = (255, 200, 100)
        else:
            stage_text = "느린 감속 단계 (0.98x)"
            color = (100, 255, 100)
        
        stage_surface = big_font.render(stage_text, True, color)
        screen.blit(stage_surface, (WIDTH//2 - stage_surface.get_width()//2, 400))
    
    pygame.display.flip()

def main():
    """메인 루프"""
    global boss_x, boss_knockback_timer, boss_knockback_vel, boss_stun_timer, ragnarok_stun_pending
    global position_history
    
    running = True
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 라그나로크 해머 발동
                    if boss_knockback_timer == 0 and boss_stun_timer == 0:
                        velocity = calculate_knockback_test(20)
                        position_history.clear()
                        print(f"\n🔨 라그나로크 해머 발동!")
                        print(f"  초기 넉백 속도: {velocity:.1f}")
                        print(f"  넉백 시간: 0.6초 (36 프레임)")
                        print(f"  예정 스턴: 1초 (60 프레임)")
                elif event.key == pygame.K_r:
                    # 리셋
                    boss_x = 250
                    boss_knockback_timer = 0
                    boss_knockback_vel = 0
                    boss_stun_timer = 0
                    ragnarok_stun_pending = 0
                    position_history.clear()
                    print("\n🔄 리셋됨")
        
        # 위치 기록
        if boss_knockback_timer > 0:
            position_history.append(boss_x)
            if len(position_history) > max_history:
                position_history.pop(0)
        
        # 업데이트
        update_knockback()
        
        # 그리기
        draw_scene()
        
        # FPS 유지
        clock.tick(FPS)
    
    pygame.quit()

if __name__ == "__main__":
    print("=" * 60)
    print("라그나로크 해머 부드러운 넉백 테스트")
    print("=" * 60)
    print("\n조정 내용:")
    print("- 넉백 시간: 0.3초 → 0.6초 (36 프레임)")
    print("- 초기 속도: 15 + 공속*0.8 → 10 + 공속*0.5")
    print("- 감속 단계:")
    print("  * 0~0.2초: 빠른 감속 (0.92x)")
    print("  * 0.2~0.4초: 중간 감속 (0.95x)")
    print("  * 0.4~0.6초: 느린 감속 (0.98x)")
    print("- 흔들림: 처음 0.3초만 적용")
    print("\n조작법:")
    print("- SPACE: 라그나로크 해머 발동")
    print("- R: 리셋")
    print("- ESC: 종료")
    
    main()