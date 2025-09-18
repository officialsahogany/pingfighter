#!/usr/bin/env python3
"""물자보급 시스템 테스트"""

import pygame
import sys
import os

# 게임 모듈 임포트를 위한 경로 설정
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pingfighter import (
    supply_drop_state,
    update_supply_drop_system,
    draw_supply_drop_system,
    draw_supply_drop_gauge,
    draw_supply_radio_motion,
    SUPPLY_DROP_GAUGE_COST,
    SUPPLY_DROP_HOLD_REQUIRED,
    SUPPLY_DROP_HOLD_THRESHOLD,
    supply_radio_motion,
    supply_radio_timer,
    supply_drop_hold_time
)

# Pygame 초기화
pygame.init()
WIDTH = 800
HEIGHT = 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("물자보급 시스템 테스트")
clock = pygame.time.Clock()

# 전역 변수 설정
PLAYER = pygame.Rect(WIDTH // 2 - 40, HEIGHT - 60, 80, 20)
special_gauge = 500  # 테스트를 위해 충분한 게이지
selected_character_type = "soldier"  # 군인 캐릭터 선택
serve_completed_timer = 0
is_waiting_for_serve = False
is_player_serve = False
player_stunned_timer = 0

def main():
    """메인 테스트 루프"""
    global special_gauge, supply_drop_hold_time, supply_radio_motion, supply_radio_timer
    
    running = True
    font = pygame.font.Font(None, 36)
    small_font = pygame.font.Font(None, 24)
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
        
        keys = pygame.key.get_pressed()
        
        # 화면 클리어
        screen.fill((50, 50, 50))
        
        # 플레이어 패들 그리기
        pygame.draw.rect(screen, (100, 200, 100), PLAYER)
        
        # 물자보급 시스템 업데이트
        if keys[pygame.K_DOWN] and not supply_drop_state.active:
            # 물자보급 발동 가능
            if special_gauge >= SUPPLY_DROP_GAUGE_COST:
                supply_drop_hold_time += 1
                
                # 홀드 진행률 출력
                if supply_drop_hold_time % 10 == 0:
                    progress = (supply_drop_hold_time / SUPPLY_DROP_HOLD_REQUIRED) * 100
                    print(f"홀드 중: {progress:.1f}% ({supply_drop_hold_time}/{SUPPLY_DROP_HOLD_REQUIRED})")
                
                # 1초 홀드 완료 시 발동
                if supply_drop_hold_time >= SUPPLY_DROP_HOLD_REQUIRED:
                    print("물자보급 발동!")
                    supply_drop_state.active = True
                    special_gauge -= SUPPLY_DROP_GAUGE_COST
                    supply_drop_state.timer = 120  # 2초 후 비행기 출현
                    supply_drop_state.hold_time = 0
                    
                    # 무전기 모션 활성화
                    supply_radio_motion = True
                    supply_radio_timer = 30
                    
                    # 사운드 재생 시도
                    try:
                        sound_path = os.path.join("sounds", "radio.wav")
                        if os.path.exists(sound_path):
                            radio_sound = pygame.mixer.Sound(sound_path)
                            radio_sound.set_volume(0.6)
                            radio_sound.play()
                            print("무전기 사운드 재생 성공")
                        else:
                            print(f"사운드 파일 없음: {sound_path}")
                    except Exception as e:
                        print(f"사운드 재생 실패: {e}")
        else:
            if supply_drop_hold_time > 0:
                print(f"홀드 중단 ({supply_drop_hold_time}/{SUPPLY_DROP_HOLD_REQUIRED})")
            supply_drop_hold_time = 0
        
        # 물자보급 홀드 시간을 supply_drop_state에도 동기화
        supply_drop_state.hold_time = supply_drop_hold_time
        
        # 물자보급 시스템 업데이트
        update_supply_drop_system()
        
        # 무전기 타이머 업데이트
        if supply_radio_timer > 0:
            supply_radio_timer -= 1
            if supply_radio_timer <= 0:
                supply_radio_motion = False
        
        # 물자보급 시스템 그리기
        draw_supply_drop_system(screen)
        
        # UI 정보 표시
        gauge_text = font.render(f"Gauge: {special_gauge}", True, (255, 255, 255))
        screen.blit(gauge_text, (10, 10))
        
        status_text = small_font.render(f"Supply Drop Active: {supply_drop_state.active}", True, (255, 255, 255))
        screen.blit(status_text, (10, 50))
        
        timer_text = small_font.render(f"Timer: {supply_drop_state.timer}", True, (255, 255, 255))
        screen.blit(timer_text, (10, 80))
        
        hold_text = small_font.render(f"Hold Time: {supply_drop_hold_time}/{SUPPLY_DROP_HOLD_REQUIRED}", True, (255, 255, 255))
        screen.blit(hold_text, (10, 110))
        
        radio_text = small_font.render(f"Radio Motion: {supply_radio_motion} (timer: {supply_radio_timer})", True, (255, 255, 255))
        screen.blit(radio_text, (10, 140))
        
        # 조작법 안내
        help_text = small_font.render("Hold DOWN arrow to activate Supply Drop", True, (200, 200, 200))
        screen.blit(help_text, (WIDTH // 2 - help_text.get_width() // 2, HEIGHT - 30))
        
        # 화면 업데이트
        pygame.display.flip()
        clock.tick(60)  # 60 FPS
    
    pygame.quit()

if __name__ == "__main__":
    main()