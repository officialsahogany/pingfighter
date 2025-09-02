#!/usr/bin/env python3
"""
Stage 5 화염 지대 테스트
"""

import pygame
import sys
import os
import random

# 게임 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from events.stage5_fire_machine_event import Stage5FireMachineEvent
from events.stage5_event_integration import Stage5EventManager

# Pygame 초기화
pygame.init()
pygame.mixer.init()

# 화면 설정
WIDTH = 600
HEIGHT = 750
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Stage 5 Fire Zone Test")

# 색상
BLACK = (0, 0, 0)
WHITE = (255, 255, 255)
RED = (255, 0, 0)
ORANGE = (255, 165, 0)
GREEN = (0, 255, 0)
BLUE = (0, 100, 255)

# FPS
FPS = 60
clock = pygame.time.Clock()

# 플레이어 설정
player_rect = pygame.Rect(WIDTH // 2 - 30, HEIGHT - 100, 60, 10)
player_speed = 5
player_dashing = False
dash_timer = 0
player_stunned = False
stun_timer = 0

# Stage 5 이벤트 매니저
stage5_events = Stage5EventManager()

# 폰트
font = pygame.font.Font(None, 24)
big_font = pygame.font.Font(None, 36)

def main():
    global player_dashing, dash_timer, player_stunned, stun_timer
    
    running = True
    current_stage = 5
    fire_event_active = False
    manual_trigger_cooldown = 0
    
    # 타이머 시작
    stage5_events.start_timer(current_stage)
    
    while running:
        dt = clock.tick(FPS)
        
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE and manual_trigger_cooldown <= 0:
                    # 수동으로 화염 이벤트 발동
                    if not fire_event_active:
                        print("🔥 수동으로 화염 이벤트 발동!")
                        if stage5_events.trigger_event(SCREEN, current_stage):
                            fire_event_active = True
                            manual_trigger_cooldown = 120  # 2초 쿨다운
                elif event.key == pygame.K_d and not player_stunned and dash_timer <= 0:
                    # 대쉬 시작
                    player_dashing = True
                    dash_timer = 30  # 0.5초 대쉬
                    print("💨 대쉬 시작!")
        
        # 키 입력 처리
        keys = pygame.key.get_pressed()
        
        # 플레이어 이동 (스턴 중이 아닐 때만)
        if not player_stunned:
            if keys[pygame.K_LEFT]:
                player_rect.x -= player_speed
            if keys[pygame.K_RIGHT]:
                player_rect.x += player_speed
            
            # 경계 체크
            player_rect.x = max(0, min(WIDTH - player_rect.width, player_rect.x))
        
        # 대쉬 타이머 처리
        if dash_timer > 0:
            dash_timer -= 1
            if dash_timer <= 0:
                player_dashing = False
                print("💨 대쉬 종료")
        
        # 스턴 타이머 처리
        if stun_timer > 0:
            stun_timer -= 1
            if stun_timer <= 0:
                player_stunned = False
                print("✅ 스턴 해제")
        
        # 수동 트리거 쿨다운
        if manual_trigger_cooldown > 0:
            manual_trigger_cooldown -= 1
        
        # 타이머 기반 이벤트 체크
        if stage5_events.check_timer_event(current_stage):
            if stage5_events.trigger_event(SCREEN, current_stage):
                fire_event_active = True
                print("⏰ 타이머로 화염 이벤트 자동 발동!")
        
        # 이벤트 업데이트
        if stage5_events.update():
            fire_event_active = True
        else:
            fire_event_active = False
        
        # 화염 지대와 플레이어 충돌 체크
        if not player_dashing and not player_stunned:
            is_in_fire, push_direction = stage5_events.check_fire_zone_collision(
                player_rect, is_rolling=False, in_smoke_grenade=False
            )
            if is_in_fire:
                player_stunned = True
                stun_timer = 30  # 0.5초 스턴
                # 밀려나는 효과
                player_rect.x += push_direction * 20
                player_rect.x = max(0, min(WIDTH - player_rect.width, player_rect.x))
                print(f"🔥 플레이어가 화염에 피격! 방향: {push_direction}")
        
        # 화면 그리기
        SCREEN.fill(BLACK)
        
        # 배경 요소 그리기 (화염 지대 등)
        stage5_events.draw_background(SCREEN)
        
        # 플레이어 그리기
        if player_stunned:
            # 스턴 중이면 빨간색으로 깜빡임
            if stun_timer % 4 < 2:
                pygame.draw.rect(SCREEN, RED, player_rect)
        elif player_dashing:
            # 대쉬 중이면 초록색
            pygame.draw.rect(SCREEN, GREEN, player_rect)
        else:
            # 평상시 파란색
            pygame.draw.rect(SCREEN, BLUE, player_rect)
        
        # 전경 요소 그리기 (기계 등)
        stage5_events.draw(SCREEN)
        
        # UI 텍스트
        status_text = []
        status_text.append(f"Stage 5 Fire Zone Test")
        status_text.append(f"Timer: {stage5_events.event_timer // 60:.1f}초")
        status_text.append(f"Event Active: {fire_event_active}")
        status_text.append(f"Player Dashing: {player_dashing}")
        status_text.append(f"Player Stunned: {player_stunned}")
        
        if stage5_events.fire_machine.fire_zones:
            status_text.append(f"Fire Zone Active: {len(stage5_events.fire_machine.fire_zones)} / 1")
        
        # 컨트롤 안내
        control_text = [
            "Controls:",
            "← → : Move",
            "D : Dash (immune to fire)",
            "SPACE : Manual trigger event",
            "ESC : Exit"
        ]
        
        # 텍스트 렌더링
        y = 10
        for text in status_text:
            text_surface = font.render(text, True, WHITE)
            SCREEN.blit(text_surface, (10, y))
            y += 25
        
        y = HEIGHT - 140
        for text in control_text:
            text_surface = font.render(text, True, WHITE)
            SCREEN.blit(text_surface, (10, y))
            y += 25
        
        # 화면 업데이트
        pygame.display.flip()
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()