#!/usr/bin/env python3
"""
Test smartphone with trajectory prediction
공이 실제로 플레이어에게 도달할 궤적인지 예측
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone with trajectory prediction...")
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
print(f"화면 높이: 0 ~ 600")
print("-" * 60)

# Test scenarios - 궤적 예측 테스트
test_cases = [
    {
        "name": "1. 🚨 직선으로 패들을 향해 오는 공 (위험)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "직선 궤적, 패들에 도달"
    },
    {
        "name": "2. 위쪽에서 아래로 내려오는 공 (안전)",
        "ball_x": 400, "ball_y": 100,
        "ball_vx": -10, "ball_vy": 5,
        "expected": False,
        "reason": "도달 시 Y위치가 패들보다 아래"
    },
    {
        "name": "3. 🚨 패들 높이 근처 공 (위험)",
        "ball_x": 300, "ball_y": 600,
        "ball_vx": -15, "ball_vy": 2,
        "expected": True,
        "reason": "패들 높이 근처 도달"
    },
    {
        "name": "4. 위쪽 공, 아래로 빠르게 (안전)",
        "ball_x": 500, "ball_y": 200,
        "ball_vx": -5, "ball_vy": 20,
        "expected": False,
        "reason": "너무 빨리 아래로 벗어남"
    },
    {
        "name": "5. 공이 오른쪽으로 이동 (안전)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": 10, "ball_vy": 0,
        "expected": False,
        "reason": "공이 멀어지는 중"
    },
    {
        "name": "6. 🚨 벽에 한번 튕긴 후 패들 도달 (위험)",
        "ball_x": 400, "ball_y": 580,
        "ball_vx": -10, "ball_vy": 10,
        "expected": True,
        "reason": "바닥 반사 후 패들 높이"
    },
    {
        "name": "7. 너무 위에서 시작 (안전)",
        "ball_x": 600, "ball_y": 50,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "패들 높이에서 너무 멀리"
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
    print("\n✅ 완벽! 궤적 예측이 작동합니다!")
    print("\n발동 조건:")
    print("- 공이 플레이어를 향해 이동 중")
    print("- 공의 예측 궤적이 패들 높이에 도달")
    print("- 벽 반사를 고려한 예측")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")