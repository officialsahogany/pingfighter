#!/usr/bin/env python3
"""
Test smartphone to ensure it doesn't activate when ball is above player's head
공이 플레이어 머리 위에 있을 때는 발동하지 않도록 수정 테스트
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone head position fix...")
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
print(f"X축 발동 조건: 플레이어로부터 100픽셀 이상")
print(f"Y축 발동 조건: 패들 기준 -60 ~ +60 픽셀 범위")
print("-" * 60)

# Test scenarios
test_cases = [
    {
        "name": "1. 🚨 패들 높이 (위험)",
        "ball_x": 250, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=168(≥100), Y차이=0 (범위 내)"
    },
    {
        "name": "2. 머리 위 멀리 (안전)",
        "ball_x": 250, "ball_y": 500,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=168(≥100), Y차이=-150 (범위 밖)"
    },
    {
        "name": "3. 🚨 패들 위 60픽셀 경계 (위험)",
        "ball_x": 300, "ball_y": 590,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=218(≥100), Y차이=-60 (경계)"
    },
    {
        "name": "4. 패들 위 61픽셀 (안전)",
        "ball_x": 300, "ball_y": 589,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=218(≥100), Y차이=-61 (범위 밖)"
    },
    {
        "name": "5. 🚨 패들 아래 59픽셀 (위험)",
        "ball_x": 400, "ball_y": 709,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=318(≥100), Y차이=59 (범위 내)"
    },
    {
        "name": "6. 패들 아래 60픽셀 (안전)",
        "ball_x": 400, "ball_y": 710,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=318(≥100), Y차이=60 (범위 밖)"
    },
    {
        "name": "7. 화면 상단 (안전)",
        "ball_x": 500, "ball_y": 100,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=418(≥100), Y차이=-550 (너무 위)"
    },
    {
        "name": "8. X축 너무 가까움 (안전)",
        "ball_x": 180, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리=98(<100), Y차이=0"
    },
    {
        "name": "9. 🚨 패들 약간 위 (위험)",
        "ball_x": 350, "ball_y": 620,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=268(≥100), Y차이=-30 (범위 내)"
    },
    {
        "name": "10. 🚨 패들 약간 아래 (위험)",
        "ball_x": 350, "ball_y": 680,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리=268(≥100), Y차이=30 (범위 내)"
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
    print("\n✅ 완벽! 머리 위 버그가 수정되었습니다!")
    print("\n발동 조건:")
    print("- 공이 플레이어를 향해 이동 중 (ball_vx < 0)")
    print("- X축: 플레이어로부터 100픽셀 이상 떨어져 있을 때")
    print("- Y축: 패들 기준 위로 60픽셀 ~ 아래로 60픽셀 범위 내")
    print("- 공이 플레이어 머리 위 멀리 있으면 발동하지 않음")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")