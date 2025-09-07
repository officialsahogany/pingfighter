#!/usr/bin/env python3
"""
Test smartphone with 200 pixel activation distance
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone 200 pixel activation distance...")
print("=" * 60)
print("조건: X거리가 200픽셀 초과해야만 발동")
print("=" * 60)

# Import modules
import items
from item_effects.smartphone import get_smartphone_instance

# Create and activate smartphone
smartphone = get_smartphone_instance()
items.smartphone_obtained = True
test_state = {'current_stage': None, 'active_items': []}
smartphone.activate(test_state, None)

print("\n200픽셀 경계 테스트:")
print("-" * 60)

# Test scenarios around 200 pixel boundary
test_cases = [
    {
        "name": "1. X거리 = 150픽셀 (안전)",
        "ball_x": 200, "ball_y": 650,  # 50 + 150
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "X거리 150 < 200"
    },
    {
        "name": "2. X거리 = 199픽셀 (안전)",
        "ball_x": 249, "ball_y": 650,  # 50 + 199
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "X거리 199 < 200"
    },
    {
        "name": "3. X거리 = 200픽셀 (경계, 안전)",
        "ball_x": 250, "ball_y": 650,  # 50 + 200
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "X거리 200 = 200 (도달 가능)"
    },
    {
        "name": "4. 🚨 X거리 = 201픽셀 (발동!)",
        "ball_x": 251, "ball_y": 650,  # 50 + 201
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "X거리 201 > 200"
    },
    {
        "name": "5. 🚨 X거리 = 250픽셀 (발동!)",
        "ball_x": 300, "ball_y": 650,  # 50 + 250
        "ball_vx": -15, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "X거리 250 > 200"
    },
    {
        "name": "6. 🚨 X거리 = 300픽셀 (발동!)",
        "ball_x": 350, "ball_y": 650,  # 50 + 300
        "ball_vx": -20, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "X거리 300 > 200"
    },
    {
        "name": "7. 공이 플레이어 왼쪽 (절대 안전)",
        "ball_x": 30, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "ball_x < PLAYER_X"
    },
    {
        "name": "8. Y거리가 멀어도 X거리 201이면 (발동 안함)",
        "ball_x": 251, "ball_y": 500,  # Y거리 150
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "Y거리 > 100"
    }
]

# Run tests
passed = 0
failed = 0

for i, test in enumerate(test_cases):
    print(f"\n{test['name']}")
    print(f"  위치: ({test['ball_x']}, {test['ball_y']})")
    print(f"  속도: vx={test['ball_vx']}, vy={test['ball_vy']}")
    print(f"  이유: {test['reason']}")
    
    result = smartphone.check_danger(
        test['ball_x'], test['ball_y'],
        test['ball_vx'], test['ball_vy'],
        test['paddle_y'], 100
    )
    
    if result == test['expected']:
        status = "✅ PASS"
        passed += 1
    else:
        status = "❌ FAIL"
        failed += 1
        
    expected_str = "발동" if test['expected'] else "안전"
    result_str = "발동" if result else "안전"
    print(f"  예상: {expected_str}, 결과: {result_str} - {status}")

print("\n" + "=" * 60)
print(f"테스트 결과: {passed}/{len(test_cases)} 통과")

if passed == len(test_cases):
    print("\n✅ 완벽! 200픽셀 경계가 정확하게 작동합니다!")
    print("\n발동 조건:")
    print("- X거리 > 200픽셀 (대쉬로 도달 불가)")
    print("- Y거리 ≤ 100픽셀 (플레이어 높이 근처)")
    print("- 공 속도 ≥ 5")
    print("- 공이 왼쪽으로 이동 중 (vx < 0)")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")