#!/usr/bin/env python3
"""
Test simple smartphone danger detection
공이 플레이어 뒤로 넘어가기 직전에만 발동
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing simple smartphone danger detection...")
print("=" * 60)
print("공이 플레이어 뒤로 넘어가기 직전에만 발동")
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

# Test scenarios for simple detection
test_cases = [
    {
        "name": "1. 공이 아주 멀리 있음 (안전)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리 350 > 250"
    },
    {
        "name": "2. 🚨 공이 중거리 (위험)",
        "ball_x": 200, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리 150 <= 250"
    },
    {
        "name": "3. 🚨 공이 가까움 (위험)",
        "ball_x": 100, "ball_y": 500,
        "ball_vx": -30, "ball_vy": 5,
        "expected": True,
        "reason": "X거리 50 <= 250"
    },
    {
        "name": "4. 공이 오른쪽으로 이동 (안전)",
        "ball_x": 200, "ball_y": 650,
        "ball_vx": 10, "ball_vy": 0,
        "expected": False,
        "reason": "공이 멀어지는 중"
    },
    {
        "name": "5. 공이 플레이어 뒤 (안전)",
        "ball_x": 40, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "이미 플레이어 뒤"
    },
    {
        "name": "6. 🚨 경계선 (위험)",
        "ball_x": 300, "ball_y": 700,
        "ball_vx": -5, "ball_vy": 0,
        "expected": True,
        "reason": "X거리 250 = 250"
    },
    {
        "name": "7. 경계선 밖 (안전)",
        "ball_x": 301, "ball_y": 650,
        "ball_vx": -20, "ball_vy": 0,
        "expected": False,
        "reason": "X거리 251 > 250"
    },
    {
        "name": "8. 🚨 먼 거리에서도 발동 (위험)",
        "ball_x": 250, "ball_y": 400,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": "X거리 200 <= 250"
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
        650, 100  # paddle_y, paddle_size (not used in simple logic)
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
    print("\n✅ 완벽! 단순 위험 감지가 작동합니다!")
    print("\n발동 조건:")
    print("- 공이 플레이어를 향해 이동 중 (ball_vx < 0)")
    print("- 공이 플레이어로부터 250픽셀 이내")
    print("- Y축 위치는 무관")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")