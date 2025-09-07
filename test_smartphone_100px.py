#!/usr/bin/env python3
"""
Test smartphone with 100 pixel activation distance
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone 100 pixel activation distance...")
print("=" * 60)
print("조건: X거리와 Y거리 모두 100픽셀")
print("=" * 60)

# Import modules
import items
from item_effects.smartphone import get_smartphone_instance

# Create and activate smartphone
smartphone = get_smartphone_instance()
items.smartphone_obtained = True
test_state = {'current_stage': None, 'active_items': []}
smartphone.activate(test_state, None)

print("\n100픽셀 경계 테스트:")
print("-" * 60)

# Test scenarios around 100 pixel boundary
test_cases = [
    {
        "name": "1. X거리 = 50픽셀 (안전)",
        "ball_x": 100, "ball_y": 650,  # 50 + 50
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "X거리 50 < 100"
    },
    {
        "name": "2. X거리 = 99픽셀 (안전)",
        "ball_x": 149, "ball_y": 650,  # 50 + 99
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "X거리 99 < 100"
    },
    {
        "name": "3. X거리 = 100픽셀 (경계, 안전)",
        "ball_x": 150, "ball_y": 650,  # 50 + 100
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "X거리 100 = 100 (도달 가능)"
    },
    {
        "name": "4. 🚨 X거리 = 101픽셀 (발동!)",
        "ball_x": 151, "ball_y": 650,  # 50 + 101
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "X거리 101 > 100"
    },
    {
        "name": "5. 🚨 X거리 = 150픽셀 (발동!)",
        "ball_x": 200, "ball_y": 650,  # 50 + 150
        "ball_vx": -15, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "X거리 150 > 100"
    },
    {
        "name": "6. 🚨 X거리 = 200픽셀 (발동!)",
        "ball_x": 250, "ball_y": 650,  # 50 + 200
        "ball_vx": -20, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "X거리 200 > 100"
    },
    {
        "name": "7. Y거리 = 99픽셀, X거리 = 101픽셀 (발동!)",
        "ball_x": 151, "ball_y": 551,  # Y거리 99
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "X > 100 && Y <= 100"
    },
    {
        "name": "8. Y거리 = 101픽셀, X거리 = 101픽셀 (안전)",
        "ball_x": 151, "ball_y": 549,  # Y거리 101
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "Y거리 > 100"
    },
    {
        "name": "9. 완벽한 경계 (X=101, Y=100)",
        "ball_x": 151, "ball_y": 550,  # X=101, Y=100
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "X=101>100 && Y=100<=100"
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
    print("\n✅ 완벽! 100픽셀 경계가 정확하게 작동합니다!")
    print("\n발동 조건:")
    print("- X거리 > 100픽셀 (대쉬로 도달 불가)")
    print("- Y거리 ≤ 100픽셀 (플레이어 높이 근처)")
    print("- 공 속도 ≥ 5")
    print("- 공이 왼쪽으로 이동 중 (vx < 0)")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")