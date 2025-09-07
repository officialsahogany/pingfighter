#!/usr/bin/env python3
"""
Test smartphone with 150px minimum distance
150픽셀 이상 떨어져 있을 때만 발동하도록 테스트
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone with 150px minimum distance...")
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
print(f"X축 발동 조건: 플레이어로부터 150픽셀 이상 (≥{PLAYER_X + 150})")
print(f"Y축 발동 조건: 패들 기준 -60 ~ +59 픽셀 범위")
print("-" * 60)

# Test scenarios
test_cases = [
    {
        "name": "1. 🚨 충분히 멀리 (위험)",
        "ball_x": 300, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=218(≥150), Y차이=0"
    },
    {
        "name": "2. 너무 가까움 100px (안전)",
        "ball_x": 182, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=100(<150), Y차이=0"
    },
    {
        "name": "3. 너무 가까움 149px (안전)",
        "ball_x": 231, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=149(<150), Y차이=0"
    },
    {
        "name": "4. 🚨 최소 경계 150px (위험)",
        "ball_x": 232, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=150(=150), Y차이=0"
    },
    {
        "name": "5. 🚨 멀리 떨어진 공 (위험)",
        "ball_x": 400, "ball_y": 680,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=318(≥150), Y차이=30"
    },
    {
        "name": "6. 가까운데 Y축 벗어남 (안전)",
        "ball_x": 200, "ball_y": 750,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=118(<150), Y차이=100"
    },
    {
        "name": "7. 멀리인데 Y축 벗어남 (안전)",
        "ball_x": 300, "ball_y": 550,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=218(≥150), Y차이=-100"
    },
    {
        "name": "8. 🚨 패들 위 범위 내 (위험)",
        "ball_x": 350, "ball_y": 620,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=268(≥150), Y차이=-30"
    },
    {
        "name": "9. 플레이어 뒤 (안전)",
        "ball_x": 50, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "공이 이미 플레이어 뒤"
    },
    {
        "name": "10. 공이 오른쪽으로 (안전)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": 10, "ball_vy": 0,
        "expected": False,
        "reason": "공이 멀어지는 중"
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
    print("\n✅ 완벽! 150픽셀 거리 조건이 작동합니다!")
    print("\n발동 조건:")
    print("- 공이 플레이어를 향해 이동 중 (ball_vx < 0)")
    print("- X축: 플레이어로부터 150픽셀 이상 떨어져 있을 때")
    print("- Y축: 패들 기준 위로 60픽셀 ~ 아래로 59픽셀 범위 내")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")