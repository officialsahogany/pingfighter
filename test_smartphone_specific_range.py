#!/usr/bin/env python3
"""
Test smartphone with specific X and Y ranges
X축: 100~600픽셀, Y축: 70픽셀 이하
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone with specific ranges...")
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
print(f"X축 발동 범위: {PLAYER_X + 100} ~ {PLAYER_X + 600} (182 ~ 682)")
print(f"Y축 발동 범위: {PADDLE_Y - 70} ~ {PADDLE_Y + 70} (580 ~ 720)")
print("-" * 60)

# Test scenarios
test_cases = [
    {
        "name": "1. 🚨 중앙 범위 (위험)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리={400-PLAYER_X}(318), Y거리=0"
    },
    {
        "name": "2. X축 너무 가까움 (안전)",
        "ball_x": 150, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리={150-PLAYER_X}(68) < 100"
    },
    {
        "name": "3. X축 너무 멀리 (안전)",
        "ball_x": 700, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리={700-PLAYER_X}(618) > 600"
    },
    {
        "name": "4. Y축 너무 멀리 (안전)",
        "ball_x": 300, "ball_y": 550,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리 OK, Y거리=100 > 70"
    },
    {
        "name": "5. 🚨 X축 최소 경계 (위험)",
        "ball_x": 182, "ball_y": 650,
        "ball_vx": -5, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=100, Y거리=0"
    },
    {
        "name": "6. 🚨 X축 최대 경계 (위험)",
        "ball_x": 682, "ball_y": 650,
        "ball_vx": -5, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=600, Y거리=0"
    },
    {
        "name": "7. 🚨 Y축 최대 경계 (위험)",
        "ball_x": 400, "ball_y": 720,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리 OK, Y거리=70"
    },
    {
        "name": "8. Y축 경계 밖 (안전)",
        "ball_x": 400, "ball_y": 721,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리 OK, Y거리=71 > 70"
    },
    {
        "name": "9. 공이 오른쪽으로 (안전)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": 10, "ball_vy": 0,
        "expected": False,
        "reason": "공이 멀어지는 중"
    },
    {
        "name": "10. 🚨 완벽한 범위 (위험)",
        "ball_x": 350, "ball_y": 620,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리={350-PLAYER_X}(268), Y거리=30"
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
    print("\n✅ 완벽! 지정된 범위에서 작동합니다!")
    print("\n발동 조건:")
    print("- 공이 플레이어를 향해 이동 중 (ball_vx < 0)")
    print("- X축: 플레이어로부터 100~600픽셀 사이")
    print("- Y축: 패들 중심에서 ±70픽셀 이내")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")