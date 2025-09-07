#!/usr/bin/env python3
"""
Test smartphone with X and Y axis conditions
X축 600픽셀 이내 AND Y축이 패들 높이 아래일 때만 발동
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone with X and Y axis conditions...")
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

# 패들 Y 위치는 650으로 설정
PADDLE_Y = 650
PADDLE_TOP = PADDLE_Y - 25  # 625

print(f"패들 중심 Y: {PADDLE_Y}")
print(f"패들 상단 Y: {PADDLE_TOP}")
print("-" * 60)

# Test scenarios
test_cases = [
    {
        "name": "1. X축 OK, Y축 위 (안전)",
        "ball_x": 400, "ball_y": 500,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"Y={500} < 패들상단={PADDLE_TOP}"
    },
    {
        "name": "2. 🚨 X축 OK, Y축 패들 높이 (위험)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X=350 ≤ 600, Y={650} ≥ {PADDLE_TOP}"
    },
    {
        "name": "3. 🚨 X축 OK, Y축 패들 아래 (위험)",
        "ball_x": 300, "ball_y": 700,
        "ball_vx": -15, "ball_vy": 5,
        "expected": True,
        "reason": f"X=250 ≤ 600, Y={700} ≥ {PADDLE_TOP}"
    },
    {
        "name": "4. X축 멀리, Y축 아래 (안전)",
        "ball_x": 700, "ball_y": 650,
        "ball_vx": -30, "ball_vy": 0,
        "expected": False,
        "reason": "X=650 > 600"
    },
    {
        "name": "5. 공이 오른쪽으로 이동 (안전)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": 10, "ball_vy": 0,
        "expected": False,
        "reason": "공이 멀어지는 중"
    },
    {
        "name": "6. 🚨 패들 상단 경계선 (위험)",
        "ball_x": 500, "ball_y": 625,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"Y={625} = 패들상단={PADDLE_TOP}"
    },
    {
        "name": "7. 패들 위 1픽셀 (안전)",
        "ball_x": 500, "ball_y": 624,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"Y={624} < 패들상단={PADDLE_TOP}"
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
        PADDLE_Y, 100  # paddle_y, paddle_size
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
    print("\n✅ 완벽! X축과 Y축 조건이 모두 작동합니다!")
    print("\n발동 조건:")
    print("- 공이 플레이어를 향해 이동 중 (ball_vx < 0)")
    print("- 공이 플레이어로부터 600픽셀 이내 (X축)")
    print(f"- 공이 패들 상단({PADDLE_TOP}) 아래에 있음 (Y축)")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")