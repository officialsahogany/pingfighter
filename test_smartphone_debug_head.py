#!/usr/bin/env python3
"""
Debug test for smartphone head position bug
플레이어 머리 바로 위에서 발동하는 버그 조사
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("🔍 Debugging smartphone head position bug...")
print("=" * 60)

# Import modules
import items
from item_effects.smartphone import get_smartphone_instance

# Create and activate smartphone
smartphone = get_smartphone_instance()
items.smartphone_obtained = True
test_state = {'current_stage': None, 'active_items': []}
smartphone.activate(test_state, None)

PLAYER_X = 82
PADDLE_Y = 650

print(f"플레이어 X 위치: {PLAYER_X}")
print(f"패들 Y 위치: {PADDLE_Y}")
print(f"\n현재 발동 조건:")
print(f"1. 긴급: X ≤ 120 AND Y절대값 ≤ 100")
print(f"2. 일반: X ≥ 200 AND Y절대값 ≤ 60")
print("-" * 60)

# 머리 위 시나리오 집중 테스트
test_cases = [
    # 플레이어 바로 위 (X축 동일)
    {
        "name": "플레이어 정확히 위 (X=82)",
        "ball_x": 82, "ball_y": 600,
        "ball_vx": -1, "ball_vy": 0,
        "note": "X거리=0, Y차이=50"
    },
    {
        "name": "플레이어 정확히 위 (X=82, 더 위)",
        "ball_x": 82, "ball_y": 550,
        "ball_vx": -1, "ball_vy": 0,
        "note": "X거리=0, Y차이=100"
    },
    # 약간 오른쪽 위
    {
        "name": "약간 오른쪽 위 (X=100)",
        "ball_x": 100, "ball_y": 600,
        "ball_vx": -5, "ball_vy": 0,
        "note": "X거리=18, Y차이=50"
    },
    {
        "name": "약간 오른쪽 위 (X=120)",
        "ball_x": 120, "ball_y": 600,
        "ball_vx": -5, "ball_vy": 0,
        "note": "X거리=38, Y차이=50"
    },
    # 긴급 발동 경계
    {
        "name": "🔴 긴급 경계 X=202, 바로 위",
        "ball_x": 202, "ball_y": 600,
        "ball_vx": -10, "ball_vy": 0,
        "note": "X거리=120, Y차이=50"
    },
    {
        "name": "🔴 긴급 경계 X=202, 더 위",
        "ball_x": 202, "ball_y": 550,
        "ball_vx": -10, "ball_vy": 0,
        "note": "X거리=120, Y차이=100"
    },
    {
        "name": "🔴 긴급 경계 X=202, 너무 위",
        "ball_x": 202, "ball_y": 549,
        "ball_vx": -10, "ball_vy": 0,
        "note": "X거리=120, Y차이=101"
    },
    # 중간 거리 (발동 안 해야 함)
    {
        "name": "중간 거리 X=150, 위",
        "ball_x": 150, "ball_y": 600,
        "ball_vx": -10, "ball_vy": 0,
        "note": "X거리=68, Y차이=50"
    },
    {
        "name": "중간 거리 X=180, 위",
        "ball_x": 180, "ball_y": 550,
        "ball_vx": -10, "ball_vy": 0,
        "note": "X거리=98, Y차이=100"
    },
    # 일반 발동 거리
    {
        "name": "🟡 일반 거리 X=282, 약간 위",
        "ball_x": 282, "ball_y": 590,
        "ball_vx": -10, "ball_vy": 0,
        "note": "X거리=200, Y차이=60"
    },
    {
        "name": "일반 거리 X=282, 너무 위",
        "ball_x": 282, "ball_y": 589,
        "ball_vx": -10, "ball_vy": 0,
        "note": "X거리=200, Y차이=61"
    },
    # 실제 문제 상황 재현
    {
        "name": "⚠️ 문제 상황 1: 가까운 머리 위",
        "ball_x": 100, "ball_y": 550,
        "ball_vx": -5, "ball_vy": 0,
        "note": "X거리=18, Y차이=100 - 긴급 발동?"
    },
    {
        "name": "⚠️ 문제 상황 2: 플레이어 바로 위",
        "ball_x": 90, "ball_y": 580,
        "ball_vx": -3, "ball_vy": 0,
        "note": "X거리=8, Y차이=70 - 긴급 발동?"
    },
    {
        "name": "⚠️ 문제 상황 3: 머리 위 대각선",
        "ball_x": 150, "ball_y": 560,
        "ball_vx": -8, "ball_vy": 0,
        "note": "X거리=68, Y차이=90 - 긴급 발동?"
    }
]

print("\n🔍 상세 디버그 분석:")
print("-" * 60)

for i, test in enumerate(test_cases, 1):
    print(f"\n[{i}] {test['name']}")
    print(f"    위치: ({test['ball_x']}, {test['ball_y']})")
    print(f"    속도: vx={test['ball_vx']}, vy={test['ball_vy']}")
    print(f"    계산: {test['note']}")
    
    # 실제 거리 계산
    x_distance = test['ball_x'] - PLAYER_X
    y_diff = abs(test['ball_y'] - PADDLE_Y)
    
    print(f"    실제 X거리: {x_distance}")
    print(f"    실제 Y차이(절대값): {y_diff}")
    
    # 발동 조건 체크
    will_trigger_emergency = x_distance <= 120 and y_diff <= 100
    will_trigger_normal = x_distance >= 200 and y_diff <= 60
    
    print(f"    긴급 조건: X≤120({x_distance<=120}) AND Y≤100({y_diff<=100}) = {will_trigger_emergency}")
    print(f"    일반 조건: X≥200({x_distance>=200}) AND Y≤60({y_diff<=60}) = {will_trigger_normal}")
    
    # 실제 발동 테스트
    result = smartphone.check_danger(
        test['ball_x'], test['ball_y'],
        test['ball_vx'], test['ball_vy'],
        PADDLE_Y, 100, PLAYER_X
    )
    
    # 결과 분석
    expected = will_trigger_emergency or will_trigger_normal
    
    if result:
        if will_trigger_emergency:
            print(f"    📍 결과: 🚨🚨 긴급 발동!")
        elif will_trigger_normal:
            print(f"    📍 결과: 🚨 일반 발동!")
        else:
            print(f"    📍 결과: ❌ 예상치 못한 발동!")
    else:
        print(f"    📍 결과: ✅ 발동 안 함")
    
    if result != expected:
        print(f"    ⚠️ 예상과 다름! (예상: {expected}, 실제: {result})")

print("\n" + "=" * 60)
print("🔍 분석 결과:")
print("-" * 60)
print("Y축 거리 계산이 절대값을 사용하므로,")
print("공이 패들 위나 아래 모두에서 동일하게 처리됩니다.")
print("\n만약 머리 위에서만 발동하지 않게 하려면:")
print("1. Y축 차이를 절대값이 아닌 실제 차이로 계산")
print("2. 공이 패들보다 위에 있을 때 다른 조건 적용")
print("3. 또는 Y축 범위를 더 좁게 조정")