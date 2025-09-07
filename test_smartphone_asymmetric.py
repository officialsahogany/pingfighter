#!/usr/bin/env python3
"""
Test smartphone with asymmetric Y-axis range
위로 50픽셀, 아래로 100픽셀 비대칭 범위 테스트
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone with asymmetric Y-axis range...")
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
print(f"X축 발동 조건: 플레이어로부터 150픽셀 이상")
print(f"Y축 발동 조건: 패들 기준 위로 50픽셀 ~ 아래로 100픽셀")
print(f"발동 Y범위: {PADDLE_Y - 50} ~ {PADDLE_Y + 100} (600 ~ 750)")
print("-" * 60)

# Test scenarios
test_cases = [
    {
        "name": "1. 🚨 패들 높이 (위험)",
        "ball_x": 300, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=218(≥150), Y차이=0 (범위 내)"
    },
    {
        "name": "2. 머리 위 60픽셀 (안전)",
        "ball_x": 300, "ball_y": 590,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=218(≥150), Y차이=-60 (범위 밖)"
    },
    {
        "name": "3. 머리 위 100픽셀 (안전)",
        "ball_x": 400, "ball_y": 550,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=318(≥150), Y차이=-100 (범위 밖)"
    },
    {
        "name": "4. 🚨 패들 위 50픽셀 경계 (위험)",
        "ball_x": 350, "ball_y": 600,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=268(≥150), Y차이=-50 (경계)"
    },
    {
        "name": "5. 패들 위 51픽셀 (안전)",
        "ball_x": 350, "ball_y": 599,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=268(≥150), Y차이=-51 (범위 밖)"
    },
    {
        "name": "6. 🚨 패들 아래 100픽셀 경계 (위험)",
        "ball_x": 400, "ball_y": 750,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=318(≥150), Y차이=100 (경계)"
    },
    {
        "name": "7. 패들 아래 101픽셀 (안전)",
        "ball_x": 400, "ball_y": 751,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=318(≥150), Y차이=101 (범위 밖)"
    },
    {
        "name": "8. 🚨 패들 약간 위 (위험)",
        "ball_x": 500, "ball_y": 620,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=418(≥150), Y차이=-30 (범위 내)"
    },
    {
        "name": "9. 🚨 패들 아래 50픽셀 (위험)",
        "ball_x": 600, "ball_y": 700,
        "ball_vx": -20, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=518(≥150), Y차이=50 (범위 내)"
    },
    {
        "name": "10. 화면 상단 (안전)",
        "ball_x": 700, "ball_y": 100,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=618(≥150), Y차이=-550 (머리 위 멀리)"
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
    print("\n✅ 완벽! 비대칭 Y축 범위가 작동합니다!")
    print("\n발동 조건:")
    print("- 공이 플레이어를 향해 이동 중 (ball_vx < 0)")
    print("- X축: 플레이어로부터 150픽셀 이상 떨어져 있을 때")
    print("- Y축: 패들 기준 위로 50픽셀 ~ 아래로 100픽셀 범위")
    print("- 머리 위에서는 발동하지 않음, 아래쪽은 넓게 감지")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")