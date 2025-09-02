#!/usr/bin/env python3
"""
Test half-dash trigger conditions
"""

import pygame
from game_mechanics.half_dash_system import HalfDashSystem

# Initialize
pygame.init()
half_dash = HalfDashSystem()

# Test case 1: Normal conditions, gauge insufficient
print("=" * 60)
print("테스트 1: 게이지 부족 상황")
print("=" * 60)

result = half_dash.check_half_dash_activation(
    special_gauge=50,      # 부족한 게이지
    required_gauge=140,    # 필요 게이지
    rolling_charges=3,     # 토큰 있음
    rolling_active=False,  # 대쉬 중 아님
    rolling_stun_timer=0,  # 쿨다운 끝남
    down_pressed=True,     # 아래키 눌림
    left_key=True,         # 왼쪽키 눌림
    right_key=False
)

print(f"결과: {result}")
print("")

# Test case 2: During cooldown
print("=" * 60)
print("테스트 2: 쿨다운 중")
print("=" * 60)

result = half_dash.check_half_dash_activation(
    special_gauge=50,
    required_gauge=140,
    rolling_charges=3,
    rolling_active=False,
    rolling_stun_timer=10,  # 쿨다운 중
    down_pressed=True,
    left_key=True,
    right_key=False
)

print(f"결과: {result}")
print("")

# Test case 3: No tokens
print("=" * 60)  
print("테스트 3: 토큰 없음")
print("=" * 60)

result = half_dash.check_half_dash_activation(
    special_gauge=50,
    required_gauge=140,
    rolling_charges=0,     # 토큰 없음
    rolling_active=False,
    rolling_stun_timer=0,
    down_pressed=True,
    left_key=True,
    right_key=False
)

print(f"결과: {result}")
print("")

# Test case 4: Enough gauge (should not trigger)
print("=" * 60)
print("테스트 4: 게이지 충분 (하프대쉬 미발동)")
print("=" * 60)

result = half_dash.check_half_dash_activation(
    special_gauge=200,     # 충분한 게이지
    required_gauge=140,
    rolling_charges=3,
    rolling_active=False,
    rolling_stun_timer=0,
    down_pressed=True,
    left_key=True,
    right_key=False
)

print(f"결과: {result}")