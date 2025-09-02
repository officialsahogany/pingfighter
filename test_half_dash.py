#!/usr/bin/env python3
"""
Half-Dash System Test
=====================
Test script to verify half-dash functionality

Author: Claude Code
Date: 2024-08-22
"""

import pygame
import sys
import os

# Add parent directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from game_mechanics.half_dash_system import HalfDashSystem

def test_half_dash_system():
    """Test the half-dash system"""
    print("=" * 60)
    print("하프 대쉬 시스템 테스트")
    print("=" * 60)
    
    # Initialize system
    half_dash = HalfDashSystem()
    print("✅ 하프 대쉬 시스템 초기화 완료")
    
    # Test 1: Normal dash (enough gauge)
    print("\n테스트 1: 게이지 충분 - 하프 대쉬 미발동")
    result = half_dash.check_half_dash_activation(
        special_gauge=200,  # 충분한 게이지
        required_gauge=140,
        rolling_charges=3,
        rolling_active=False,
        down_pressed=True,
        left_key=True,
        right_key=False
    )
    assert result[0] == False, "게이지가 충분할 때는 하프 대쉬가 발동하면 안됨"
    print("✅ 테스트 1 통과")
    
    # Test 2: Half dash activation (insufficient gauge)
    print("\n테스트 2: 게이지 부족 - 하프 대쉬 발동")
    result = half_dash.check_half_dash_activation(
        special_gauge=50,   # 부족한 게이지
        required_gauge=140,
        rolling_charges=3,
        rolling_active=False,
        down_pressed=True,
        left_key=True,
        right_key=False
    )
    assert result[0] == True, "게이지가 부족할 때 하프 대쉬가 발동해야 함"
    assert result[1] == -1, "왼쪽 키 입력시 방향은 -1이어야 함"
    assert result[2] == 8, "하프 대쉬 타이머는 8이어야 함"
    print("✅ 테스트 2 통과")
    
    # Test 3: Cooldown test
    print("\n테스트 3: 쿨다운 테스트")
    # 쿨다운이 있는 상태에서 다시 시도
    result = half_dash.check_half_dash_activation(
        special_gauge=50,
        required_gauge=140,
        rolling_charges=3,
        rolling_active=False,
        down_pressed=True,
        left_key=False,
        right_key=True
    )
    assert result[0] == False, "쿨다운 중에는 하프 대쉬가 발동하면 안됨"
    print(f"✅ 테스트 3 통과 (쿨다운: {half_dash.half_dash_cooldown}/180)")
    
    # Test 4: Timer adjustment
    print("\n테스트 4: 타이머 조정 테스트")
    base_timer = 15
    adjusted = half_dash.apply_half_dash_effects(base_timer, False, 0)
    assert adjusted == 7, f"기본 타이머 조정값이 잘못됨: {adjusted}"
    
    adjusted_with_gear = half_dash.apply_half_dash_effects(base_timer, True, 0)
    expected_gear = int(7 * 1.1)  # 7 * 1.1 = 7.7 -> 7
    assert adjusted_with_gear == expected_gear, f"대쉬기어 적용 타이머가 잘못됨: {adjusted_with_gear} (expected: {expected_gear})"
    
    adjusted_with_jump = half_dash.apply_half_dash_effects(base_timer, False, 0.2)
    expected_jump = int(7 * (1 + 0.2 * 0.5))  # 7 * 1.1 = 7.7 -> 7
    assert adjusted_with_jump == expected_jump, f"도약 스킬 적용 타이머가 잘못됨: {adjusted_with_jump} (expected: {expected_jump})"
    print("✅ 테스트 4 통과")
    
    # Test 5: Statistics
    print("\n테스트 5: 통계 테스트")
    stats = half_dash.get_statistics()
    assert stats['total_uses'] == 1, "총 사용 횟수가 1이어야 함"
    assert stats['ball_saves'] == 0, "공 방어 횟수가 0이어야 함"
    print(f"✅ 테스트 5 통과: {stats}")
    
    # Test 6: Round reset
    print("\n테스트 6: 라운드 리셋 테스트")
    half_dash.reset_round()
    assert half_dash.half_dash_active == False, "라운드 리셋 후 활성 상태가 False여야 함"
    assert half_dash.half_dash_cooldown > 0, "쿨다운은 유지되어야 함"
    print("✅ 테스트 6 통과")
    
    print("\n" + "=" * 60)
    print("🎉 모든 테스트 통과!")
    print("하프 대쉬 시스템이 정상적으로 작동합니다.")
    print("=" * 60)

def test_visual():
    """Visual test with pygame"""
    pygame.init()
    screen = pygame.display.set_mode((600, 400))
    pygame.display.set_caption("하프 대쉬 시각 테스트")
    clock = pygame.time.Clock()
    
    # Test rectangle (player)
    player_rect = pygame.Rect(300, 200, 50, 80)
    
    # Initialize half dash
    half_dash = HalfDashSystem()
    
    running = True
    direction = 0
    
    font = pygame.font.Font(None, 24)
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_LEFT:
                    direction = -1
                    half_dash.half_dash_active = True
                elif event.key == pygame.K_RIGHT:
                    direction = 1
                    half_dash.half_dash_active = True
                elif event.key == pygame.K_SPACE:
                    half_dash.half_dash_active = False
        
        # Clear screen
        screen.fill((30, 30, 30))
        
        # Draw player
        pygame.draw.rect(screen, (100, 200, 100), player_rect)
        
        # Draw half dash effect
        if half_dash.half_dash_active:
            half_dash.draw_half_dash_effect(screen, player_rect, direction)
        
        # Draw cooldown
        half_dash.draw_cooldown_indicator(screen, 300, 100)
        
        # Instructions
        text = font.render("Press LEFT/RIGHT to test effect, SPACE to clear", True, (255, 255, 255))
        screen.blit(text, (50, 350))
        
        pygame.display.flip()
        clock.tick(60)
        
        # Update cooldown
        if half_dash.half_dash_cooldown > 0:
            half_dash.half_dash_cooldown -= 1
    
    pygame.quit()

if __name__ == "__main__":
    # Run unit tests
    test_half_dash_system()
    
    # Run visual test (optional)
    print("\n시각 테스트를 실행하시겠습니까? (y/n): ", end="")
    if input().lower() == 'y':
        test_visual()