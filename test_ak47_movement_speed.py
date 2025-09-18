#!/usr/bin/env python3
"""AK-47 연사 시 이동속도 감소 테스트"""

import pygame
import sys
import os

# 게임 모듈 임포트를 위한 경로 설정
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pingfighter import (
    soldier_weapons,
    current_weapon_index,
    WIDTH, HEIGHT,
    MAX_SPEED, ACCELERATION, DECELERATION,
    selected_character_type,
    PLAYER,
    current_speed
)
from item_effects.ak47 import get_ak47_instance

# Pygame 초기화
pygame.init()
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("AK-47 이동속도 감소 테스트")
clock = pygame.time.Clock()

def setup_test_environment():
    """테스트 환경 설정"""
    global selected_character_type, soldier_weapons, current_speed
    
    # 군인 캐릭터로 설정
    selected_character_type = "soldier"
    
    # AK-47을 무기 목록에 추가
    soldier_weapons = ["pistol", "ak47"]
    
    # 플레이어 위치 초기화
    PLAYER.centerx = WIDTH // 2
    PLAYER.centery = HEIGHT - 60
    
    # 속도 초기화
    current_speed = 0
    
    # AK-47 초기화 및 활성화
    ak47 = get_ak47_instance()
    ak47.active = True
    ak47.current_ammo = 30
    ak47.is_firing = False
    ak47.shot_cooldown = 0
    
    print("테스트 환경 설정 완료")
    print(f"- 캐릭터: {selected_character_type}")
    print(f"- 무기: {soldier_weapons}")
    print(f"- AK-47 활성화: {ak47.active}")

def calculate_movement_speed():
    """현재 이동속도 배율 계산 (게임 로직과 동일)"""
    # 기본 배율
    base_multiplier = 1.0
    
    # AK-47 연사 시 이동속도 감소 배율
    ak47_speed_multiplier = 1.0
    if selected_character_type == "soldier" and 'ak47' in soldier_weapons:
        ak47 = get_ak47_instance()
        ak47_speed_multiplier = ak47.get_movement_speed_multiplier()
    
    # 최종 배율 계산
    final_multiplier = base_multiplier * ak47_speed_multiplier
    
    # 조정된 이동 파라미터
    adjusted_acceleration = ACCELERATION * final_multiplier
    adjusted_max_speed = MAX_SPEED * final_multiplier
    
    return {
        'ak47_multiplier': ak47_speed_multiplier,
        'final_multiplier': final_multiplier,
        'adjusted_acceleration': adjusted_acceleration,
        'adjusted_max_speed': adjusted_max_speed
    }

def main():
    """메인 테스트 루프"""
    global current_speed
    
    setup_test_environment()
    
    running = True
    font = pygame.font.Font(None, 24)
    
    # 테스트 상태
    test_firing = False
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            # 키 입력 처리는 handle_space_input에서 자동으로 처리됨
        
        keys = pygame.key.get_pressed()
        
        # AK-47 업데이트 (쿨다운 감소)
        ak47 = get_ak47_instance()
        if ak47.shot_cooldown > 0:
            ak47.shot_cooldown -= 1
            
        # 실제 게임과 동일하게 스페이스 입력 처리
        ak47.handle_space_input(keys[pygame.K_SPACE])
        
        # 이동속도 계산
        speed_info = calculate_movement_speed()
        
        # 플레이어 이동 (간단한 버전)
        adjusted_acceleration = speed_info['adjusted_acceleration']
        adjusted_max_speed = speed_info['adjusted_max_speed']
        
        if keys[pygame.K_LEFT]:
            if current_speed > -adjusted_max_speed:
                current_speed -= adjusted_acceleration
        elif keys[pygame.K_RIGHT]:
            if current_speed < adjusted_max_speed:
                current_speed += adjusted_acceleration
        else:
            # 감속
            if current_speed > 0:
                current_speed -= DECELERATION
            elif current_speed < 0:
                current_speed += DECELERATION
        
        # 플레이어 위치 업데이트
        PLAYER.x += current_speed
        PLAYER.x = max(0, min(WIDTH - PLAYER.width, PLAYER.x))
        
        # 화면 클리어
        SCREEN.fill((30, 30, 30))
        
        # 플레이어 그리기
        player_color = (255, 100, 100) if ak47.is_firing else (100, 200, 100)
        pygame.draw.rect(SCREEN, player_color, PLAYER)
        
        # 상태 정보 표시
        info_y = 10
        status_texts = [
            "AK-47 이동속도 감소 테스트",
            "",
            f"AK-47 연사 중: {ak47.is_firing}",
            f"AK-47 쿨다운: {ak47.shot_cooldown}",
            f"속도 배율: {speed_info['ak47_multiplier']:.1f} ({int((1-speed_info['ak47_multiplier'])*100)}% 감소)" if speed_info['ak47_multiplier'] < 1.0 else f"속도 배율: {speed_info['ak47_multiplier']:.1f} (정상)",
            "",
            f"현재 속도: {current_speed:.2f}",
            f"최대 속도: {speed_info['adjusted_max_speed']:.2f} (기본: {MAX_SPEED})",
            f"가속도: {speed_info['adjusted_acceleration']:.2f} (기본: {ACCELERATION})",
            "",
            "조작법:",
            "← → 키: 이동",
            "SPACE(누르기): AK-47 연사",
            "SPACE(떼기): 연사 중지",
            "ESC: 종료"
        ]
        
        for text in status_texts:
            if text:  # 빈 문자열이 아닐 때만 렌더링
                color = (255, 255, 100) if "속도 배율" in text and "감소" in text else (255, 255, 255)
                text_surface = font.render(text, True, color)
                SCREEN.blit(text_surface, (10, info_y))
            info_y += 25
        
        # 중앙에 속도 표시
        speed_text = f"현재 속도: {current_speed:.1f}"
        speed_surface = pygame.font.Font(None, 36).render(speed_text, True, (255, 255, 255))
        SCREEN.blit(speed_surface, (WIDTH // 2 - speed_surface.get_width() // 2, HEIGHT // 2))
        
        # 연사 상태 표시
        if ak47.is_firing:
            firing_text = "🔫 AK-47 연사 중 - 이동속도 50% 감소"
            firing_surface = font.render(firing_text, True, (255, 100, 100))
            SCREEN.blit(firing_surface, (WIDTH // 2 - firing_surface.get_width() // 2, HEIGHT // 2 + 50))
        
        # 화면 업데이트
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()

if __name__ == "__main__":
    main()