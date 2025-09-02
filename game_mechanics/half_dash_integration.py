"""
Half-Dash Integration Module
============================
Integration layer to connect half-dash system with pingfighter.py
Minimizes changes to the main game file.

Author: Claude Code
Date: 2024-08-22
"""

import pygame
from game_mechanics.half_dash_system import initialize_half_dash, get_half_dash_system

def integrate_half_dash_with_game():
    """
    pingfighter.py와 하프 대쉬 시스템 통합
    main 파일 수정을 최소화하기 위한 래퍼 함수들
    """
    # 하프 대쉬 시스템 초기화
    half_dash = initialize_half_dash()
    return half_dash

def check_and_activate_half_dash(game_state):
    """
    하프 대쉬 발동 체크 및 활성화
    
    Args:
        game_state: 게임 상태 딕셔너리
            - special_gauge: 현재 게이지
            - required_gauge: 필요 게이지
            - rolling_charges: 대쉬 토큰
            - rolling_active: 대쉬 활성 여부
            - rolling_stun_timer: 대쉬 스턴 타이머
            - keys: 키보드 상태
            - down_pressed: 아래키 눌림 여부
            - jump_bonus: 도약 스킬 보너스 (optional)
            - dashgear_obtained: 대쉬기어 획득 여부 (optional)
            
    Returns:
        (activated, direction, timer, token_cost) 튜플
    """
    half_dash = get_half_dash_system()
    if not half_dash:
        return False, 0, 0, 0
        
    # 게임 상태 추출
    special_gauge = game_state.get('special_gauge', 0)
    required_gauge = game_state.get('required_gauge', 140)
    rolling_charges = game_state.get('rolling_charges', 0)
    rolling_active = game_state.get('rolling_active', False)
    rolling_stun_timer = game_state.get('rolling_stun_timer', 0)
    down_pressed = game_state.get('down_pressed', False)
    keys = game_state.get('keys', {})
    jump_bonus = game_state.get('jump_bonus', 0)
    dashgear_obtained = game_state.get('dashgear_obtained', False)
    
    # 키 상태 확인 (keys는 pygame.key.get_pressed() 결과)
    left_key = keys[pygame.K_LEFT] if keys else False
    right_key = keys[pygame.K_RIGHT] if keys else False
    
    # 하프 대쉬 체크
    activated, direction, base_timer, token_cost = half_dash.check_half_dash_activation(
        special_gauge, required_gauge, rolling_charges,
        rolling_active, rolling_stun_timer, down_pressed, left_key, right_key
    )
    
    # 하프 대쉬가 활성화되면 jump_bonus와 dashgear 효과 적용
    if activated and base_timer > 0:
        # 하프 대쉬 타이머에 보너스 적용
        adjusted_timer = half_dash.apply_half_dash_effects(base_timer, dashgear_obtained, jump_bonus)
        return activated, direction, adjusted_timer, token_cost
    
    return activated, direction, base_timer, token_cost

def apply_half_dash_timer_adjustment(base_timer, dashgear_obtained, jump_bonus):
    """
    하프 대쉬 타이머 조정
    
    Args:
        base_timer: 기본 대쉬 타이머
        dashgear_obtained: 대쉬기어 보유 여부
        jump_bonus: 도약 스킬 보너스
        
    Returns:
        조정된 타이머
    """
    half_dash = get_half_dash_system()
    if not half_dash or not half_dash.half_dash_active:
        return base_timer
        
    return half_dash.apply_half_dash_effects(base_timer, dashgear_obtained, jump_bonus)

def draw_half_dash_effects(screen, player_rect, rolling_direction):
    """
    하프 대쉬 시각 효과 그리기
    
    Args:
        screen: 게임 화면
        player_rect: 플레이어 위치
        rolling_direction: 대쉬 방향
    """
    half_dash = get_half_dash_system()
    if not half_dash:
        return
        
    # 하프 대쉬 효과 그리기
    half_dash.draw_half_dash_effect(screen, player_rect, rolling_direction)
    
    # 쿨다운 표시 (플레이어 위)
    half_dash.draw_cooldown_indicator(
        screen, 
        player_rect.centerx, 
        player_rect.top - 30
    )

def handle_half_dash_ball_collision(ball_rect, player_rect):
    """
    하프 대쉬 중 공 충돌 처리
    
    Args:
        ball_rect: 공 위치
        player_rect: 플레이어 위치
        
    Returns:
        충돌 여부
    """
    half_dash = get_half_dash_system()
    if not half_dash:
        return False
        
    return half_dash.handle_ball_collision(ball_rect, player_rect)

def reset_half_dash_round():
    """라운드 리셋시 하프 대쉬 초기화"""
    half_dash = get_half_dash_system()
    if half_dash:
        half_dash.reset_round()

def get_half_dash_stats():
    """하프 대쉬 통계 반환"""
    half_dash = get_half_dash_system()
    if not half_dash:
        return {}
        
    return half_dash.get_statistics()

# pingfighter.py에 추가할 코드 스니펫
INTEGRATION_CODE = '''
# === 하프 대쉬 시스템 통합 ===
# 파일 상단 import 섹션에 추가:
from game_mechanics.half_dash_integration import (
    integrate_half_dash_with_game,
    check_and_activate_half_dash,
    apply_half_dash_timer_adjustment,
    draw_half_dash_effects,
    handle_half_dash_ball_collision,
    reset_half_dash_round,
    get_half_dash_stats
)

# 게임 초기화 부분에 추가:
half_dash_system = integrate_half_dash_with_game()

# 대쉬 키 입력 처리 부분 (약 3766번 줄 근처)에 추가:
# 기존 대쉬 코드 전에 하프 대쉬 체크
if down_pressed and rolling_charges > 0 and not rolling_active:
    # 게이지 부족시 하프 대쉬 체크
    game_state = {
        'special_gauge': special_gauge,
        'required_gauge': required_gauge,
        'rolling_charges': rolling_charges,
        'rolling_active': rolling_active,
        'down_pressed': down_pressed,
        'keys': keys
    }
    
    half_dash_activated, half_dash_direction, half_dash_timer = check_and_activate_half_dash(game_state)
    
    if half_dash_activated:
        # 하프 대쉬 발동
        rolling_active = True
        rolling_direction = half_dash_direction
        rolling_timer = half_dash_timer
        
        # 하프 대쉬는 게이지 소모 없음
        # rolling_charges는 유지 (토큰도 소모하지 않음)
        
        # 대쉬 효과음
        play_dash_sound()
        
        # 하프 대쉬 메시지
        display_status_message("하프 대쉬!", (150, 150, 255))
        
        # 기존 대쉬 코드 스킵
        continue

# 대쉬 중 그리기 부분에 추가:
if rolling_active:
    draw_half_dash_effects(screen, PLAYER, rolling_direction)

# 라운드 리셋 함수에 추가:
reset_half_dash_round()

# 통계 표시 부분에 추가 (선택사항):
half_dash_stats = get_half_dash_stats()
if half_dash_stats['total_uses'] > 0:
    print(f"  : {half_dash_stats['total_uses']}")
    print(f"   : {half_dash_stats['ball_saves']}")
'''

def print_integration_instructions():
    """통합 방법 출력"""
    print("=" * 60)
    print("")
    print("=" * 60)
    print(INTEGRATION_CODE)
    print("=" * 60)
    print("pingfighter.py   .")
    print(".")
    print("=" * 60)