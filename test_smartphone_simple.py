#!/usr/bin/env python3
"""
Test smartphone with simple and clear conditions
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone with simple conditions...")
print("=" * 60)
print("발동 조건:")
print("1. 공이 플레이어 높이 근처 (Y거리 <= 100픽셀)")
print("2. 공이 플레이어를 향함 (vx < 0)")
print("3. 대쉬로 도달 불가능 (X거리 > 300픽셀)")
print("4. 충분한 속도 (|vx| >= 5)")
print("=" * 60)

# Import modules
import items
from item_effects.smartphone import get_smartphone_instance

# Create and activate smartphone
smartphone = get_smartphone_instance()
items.smartphone_obtained = True
test_state = {'current_stage': None, 'active_items': []}
smartphone.activate(test_state, None)

print("\n테스트 시나리오:")
print("-" * 60)

# Test scenarios
test_cases = [
    {
        "name": "1. 공이 플레이어 높이에서 멀리",
        "ball_x": 400, "ball_y": 400,  # Y거리 250
        "ball_vx": -10, "ball_vy": 5,
        "paddle_y": 650,
        "expected": False,
        "reason": "Y거리 > 100"
    },
    {
        "name": "2. 공이 반대로 움직임",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": 5, "ball_vy": 0,  # 오른쪽으로
        "paddle_y": 650,
        "expected": False,
        "reason": "vx >= 0"
    },
    {
        "name": "3. 대쉬로 도달 가능",
        "ball_x": 250, "ball_y": 650,  # X거리 200
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "X거리 <= 300"
    },
    {
        "name": "4. 공이 너무 느림",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": -3, "ball_vy": 0,  # 속도 3
        "paddle_y": 650,
        "expected": False,
        "reason": "속도 < 5"
    },
    {
        "name": "5. 🚨 완벽한 위험 상황!",
        "ball_x": 400, "ball_y": 650,  # X거리 350, Y거리 0
        "ball_vx": -15, "ball_vy": 0,  # 빠른 속도
        "paddle_y": 650,
        "expected": True,
        "reason": "모든 조건 만족"
    },
    {
        "name": "6. 🚨 약간 위/아래에서 빠르게",
        "ball_x": 500, "ball_y": 600,  # Y거리 50
        "ball_vx": -20, "ball_vy": 5,
        "paddle_y": 650,
        "expected": True,
        "reason": "Y근처 & X멀리 & 빠름"
    },
    {
        "name": "7. 경계선 케이스 (X=300)",
        "ball_x": 350, "ball_y": 650,  # X거리 정확히 300
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "X거리 = 300 (도달 가능)"
    },
    {
        "name": "8. 🚨 경계선 케이스 (X=301)",
        "ball_x": 351, "ball_y": 650,  # X거리 301
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "X거리 > 300 (도달 불가)"
    }
]

# Run tests
passed = 0
failed = 0

for i, test in enumerate(test_cases):
    print(f"\n{test['name']}")
    print(f"  위치: ({test['ball_x']}, {test['ball_y']})")
    print(f"  속도: vx={test['ball_vx']}, vy={test['ball_vy']}")
    print(f"  플레이어 Y: {test['paddle_y']}")
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
        
    print(f"  예상: {test['expected']}, 결과: {result} - {status}")

print("\n" + "=" * 60)
print(f"테스트 결과: {passed}/{len(test_cases)} 통과")

if passed == len(test_cases):
    print("\n✅ 완벽! 모든 테스트 통과!")
    print("\n스마트폰이 이제 명확한 조건으로 작동합니다:")
    print("- 플레이어 높이 근처에 있고")
    print("- 대쉬로도 도달할 수 없을 때만 발동!")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")