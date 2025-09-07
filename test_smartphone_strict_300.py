#!/usr/bin/env python3
"""
Test smartphone with STRICT 300 pixel boundary
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone STRICT 300 pixel boundary...")
print("=" * 60)
print("조건: X거리가 정확히 300픽셀 초과해야만 발동")
print("=" * 60)

# Import modules
import items
from item_effects.smartphone import get_smartphone_instance

# Create and activate smartphone
smartphone = get_smartphone_instance()
items.smartphone_obtained = True
test_state = {'current_stage': None, 'active_items': []}
smartphone.activate(test_state, None)

print("\n경계선 테스트 (295~305 픽셀):")
print("-" * 60)

# Test precise boundary cases
test_cases = []

# Test from 295 to 305 pixels (player at x=50)
for x in range(295, 306):
    ball_x = 50 + x  # Player is at x=50
    test_cases.append({
        "name": f"X거리 = {x}픽셀",
        "ball_x": ball_x,
        "ball_y": 650,
        "ball_vx": -10,
        "ball_vy": 0,
        "paddle_y": 650,
        "expected": x > 300,  # Should only activate when x > 300
        "x_distance": x
    })

# Run tests
passed = 0
failed = 0

for test in test_cases:
    print(f"\n{test['name']} (ball_x={test['ball_x']})")
    
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
print("요약:")
print("-" * 60)
print("X거리 ≤ 300: 안전 (발동 안함)")
print("X거리 > 300: 위험 (발동함)")
print("-" * 60)
print(f"테스트 결과: {passed}/{len(test_cases)} 통과")

if passed == len(test_cases):
    print("\n✅ 완벽! 300픽셀 경계가 정확하게 작동합니다!")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")
    print("\n실패한 케이스:")
    for test in test_cases:
        result = smartphone.check_danger(
            test['ball_x'], test['ball_y'],
            test['ball_vx'], test['ball_vy'],
            test['paddle_y'], 100
        )
        if result != test['expected']:
            expected_str = "발동" if test['expected'] else "안전"
            result_str = "발동" if result else "안전"
            print(f"  X거리={test['x_distance']}: 예상={expected_str}, 실제={result_str}")