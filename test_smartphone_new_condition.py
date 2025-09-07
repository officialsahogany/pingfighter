#!/usr/bin/env python3
"""
Test smartphone with new conditions
X축: 60픽셀 이상, Y축: 50픽셀 미만
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone with new conditions...")
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
print(f"X축 발동 조건: {PLAYER_X + 100}픽셀 이상 (≥182)")
print(f"Y축 발동 조건: 패들 중심에서 60픽셀 미만 (<60)")
print("-" * 60)

# Test scenarios
test_cases = [
    {
        "name": "1. 🚨 완벽한 조건 (위험)",
        "ball_x": 250, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=168(≥100), Y거리=0(<60)"
    },
    {
        "name": "2. X축 너무 가까움 (안전)",
        "ball_x": 180, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=98(<100), Y거리=0"
    },
    {
        "name": "3. Y축 너무 멀리 (안전)",
        "ball_x": 250, "ball_y": 710,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=168(≥100), Y거리=60(≥60)"
    },
    {
        "name": "4. 🚨 X축 최소 경계 (위험)",
        "ball_x": 182, "ball_y": 650,
        "ball_vx": -5, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=100(≥100), Y거리=0(<60)"
    },
    {
        "name": "5. 🚨 Y축 최대 경계 (위험)",
        "ball_x": 300, "ball_y": 709,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=218(≥100), Y거리=59(<60)"
    },
    {
        "name": "6. Y축 경계 밖 (안전)",
        "ball_x": 300, "ball_y": 710,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=218(≥100), Y거리=60(≥60)"
    },
    {
        "name": "7. 공이 오른쪽으로 (안전)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": 10, "ball_vy": 0,
        "expected": False,
        "reason": "공이 멀어지는 중"
    },
    {
        "name": "8. 플레이어 뒤 (안전)",
        "ball_x": 50, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "공이 이미 플레이어 뒤"
    },
    {
        "name": "9. 🚨 멀리 떨어진 공 (위험)",
        "ball_x": 600, "ball_y": 640,
        "ball_vx": -20, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=518(≥100), Y거리=10(<60)"
    },
    {
        "name": "10. 두 조건 모두 경계선 (안전)",
        "ball_x": 181, "ball_y": 710,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=99(<100), Y거리=60(≥60)"
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
        PADDLE_Y, 100, PLAYER_X
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
    print("\n✅ 완벽! 새로운 조건이 정확히 작동합니다!")
    print("\n발동 조건:")
    print("- 공이 플레이어를 향해 이동 중 (ball_vx < 0)")
    print("- X축: 플레이어로부터 100픽셀 이상 떨어져 있을 때")
    print("- Y축: 패들 중심에서 60픽셀 미만")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")