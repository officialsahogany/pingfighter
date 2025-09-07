#!/usr/bin/env python3
"""
Test smartphone - should NOT activate when ball is above player's head
공이 플레이어 머리 위에 있을 때는 발동하지 않는지 테스트
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone - no activation above player's head...")
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
print(f"X축 발동 조건: 플레이어로부터 300픽셀 이상")
print(f"Y축 발동 조건: 패들과 같거나 아래 (0 ~ 50픽셀)")
print(f"발동 Y범위: {PADDLE_Y} ~ {PADDLE_Y + 50} (650 ~ 700)")
print("-" * 60)

# Test scenarios
test_cases = [
    {
        "name": "1. 🚨 패들과 같은 높이, 멀리 (위험)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=318(≥300), Y차이=0 (같은 높이)"
    },
    {
        "name": "2. 머리 바로 위, 멀리 (안전)",
        "ball_x": 400, "ball_y": 649,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=318(≥300), Y차이=-1 (머리 위)"
    },
    {
        "name": "3. 머리 위 10픽셀, 멀리 (안전)",
        "ball_x": 500, "ball_y": 640,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=418(≥300), Y차이=-10 (머리 위)"
    },
    {
        "name": "4. 머리 위 50픽셀, 멀리 (안전)",
        "ball_x": 500, "ball_y": 600,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=418(≥300), Y차이=-50 (머리 위)"
    },
    {
        "name": "5. 🚨 패들 아래 25픽셀, 멀리 (위험)",
        "ball_x": 450, "ball_y": 675,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=368(≥300), Y차이=25 (아래)"
    },
    {
        "name": "6. 🚨 패들 아래 50픽셀 경계, 멀리 (위험)",
        "ball_x": 400, "ball_y": 700,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=318(≥300), Y차이=50 (경계)"
    },
    {
        "name": "7. 패들 아래 51픽셀, 멀리 (안전)",
        "ball_x": 400, "ball_y": 701,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=318(≥300), Y차이=51 (범위 밖)"
    },
    {
        "name": "8. 머리 바로 위, 가까움 (안전)",
        "ball_x": 200, "ball_y": 640,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=118(<300), Y차이=-10 (가깝고 위)"
    },
    {
        "name": "9. 패들 높이, 가까움 (안전)",
        "ball_x": 250, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=168(<300), Y차이=0 (너무 가까움)"
    },
    {
        "name": "10. 화면 상단, 멀리 (안전)",
        "ball_x": 600, "ball_y": 100,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=518(≥300), Y차이=-550 (머리 위 멀리)"
    },
    {
        "name": "11. 플레이어 바로 위 (안전)",
        "ball_x": 82, "ball_y": 600,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=0(<300), Y차이=-50 (바로 위)"
    },
    {
        "name": "12. 플레이어 약간 오른쪽 위 (안전)",
        "ball_x": 150, "ball_y": 600,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=68(<300), Y차이=-50 (가깝고 위)"
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
    print("\n✅ 완벽! 머리 위에서는 발동하지 않습니다!")
    print("\n발동 조건:")
    print("- 공이 플레이어를 향해 이동 중 (ball_vx < 0)")
    print("- X축: 플레이어로부터 300픽셀 이상 떨어져 있을 때")
    print("- Y축: 패들과 같거나 아래 (0 ~ 50픽셀)")
    print("- 공이 패들 머리 위에 있으면 절대 발동하지 않음")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")