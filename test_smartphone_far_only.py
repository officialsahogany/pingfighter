#!/usr/bin/env python3
"""
Test smartphone - only activates when ball is far away
공이 멀리 떨어져 있을 때만 발동하는지 테스트
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone - far distance only activation...")
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
print(f"X축 발동 조건: 플레이어로부터 300픽셀 이상 (대쉬 불가 거리)")
print(f"Y축 발동 조건: 패들 기준 ±50픽셀 범위")
print(f"발동 범위: X ≥ {PLAYER_X + 300}, Y {PADDLE_Y - 50} ~ {PADDLE_Y + 50}")
print("-" * 60)

# Test scenarios
test_cases = [
    {
        "name": "1. 가까운 거리 100px (안전)",
        "ball_x": 182, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=100 (패들에 닿을 수 있는 거리)"
    },
    {
        "name": "2. 중간 거리 200px (안전)",
        "ball_x": 282, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=200 (대쉬로 닿을 수 있는 거리)"
    },
    {
        "name": "3. 경계 거리 299px (안전)",
        "ball_x": 381, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=299 (아직 가까움)"
    },
    {
        "name": "4. 🚨 최소 발동 거리 300px (위험)",
        "ball_x": 382, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=300 (대쉬로도 못 닿는 거리)"
    },
    {
        "name": "5. 🚨 멀리 떨어진 500px (위험)",
        "ball_x": 582, "ball_y": 650,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=500 (확실히 멀리)"
    },
    {
        "name": "6. 🚨 매우 멀리 700px (위험)",
        "ball_x": 782, "ball_y": 650,
        "ball_vx": -20, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=700 (매우 멀리)"
    },
    {
        "name": "7. 멀지만 Y축 벗어남 위 (안전)",
        "ball_x": 500, "ball_y": 599,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=418 (멀리), Y차이=-51 (범위 밖)"
    },
    {
        "name": "8. 멀지만 Y축 벗어남 아래 (안전)",
        "ball_x": 500, "ball_y": 701,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=418 (멀리), Y차이=51 (범위 밖)"
    },
    {
        "name": "9. 🚨 Y축 경계 위 (위험)",
        "ball_x": 450, "ball_y": 600,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=368, Y차이=-50 (경계)"
    },
    {
        "name": "10. 🚨 Y축 경계 아래 (위험)",
        "ball_x": 450, "ball_y": 700,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=368, Y차이=50 (경계)"
    },
    {
        "name": "11. 가까운데 Y축 정확 (안전)",
        "ball_x": 250, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=168 (너무 가까움)"
    },
    {
        "name": "12. 머리 위 멀리 (안전)",
        "ball_x": 500, "ball_y": 400,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=418, Y차이=-250 (머리 위 멀리)"
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
    print("\n✅ 완벽! 멀리 떨어진 공만 감지합니다!")
    print("\n발동 조건:")
    print("- 공이 플레이어를 향해 이동 중 (ball_vx < 0)")
    print("- X축: 플레이어로부터 300픽셀 이상 (대쉬로도 못 닿는 거리)")
    print("- Y축: 패들 기준 ±50픽셀 범위")
    print("- 패들에 닿을 수 있는 거리에서는 발동하지 않음")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")