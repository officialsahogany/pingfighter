#!/usr/bin/env python3
"""
Test very simple smartphone logic
매우 단순한 스마트폰 로직 테스트
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing very simple smartphone logic...")
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
print(f"Y축 발동 범위: {PADDLE_Y - 150} ~ {PADDLE_Y + 150}")
print("-" * 60)

# Test scenarios
test_cases = [
    {
        "name": "1. 🚨 패들 높이 공 (위험)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "Y거리 = 0 <= 150"
    },
    {
        "name": "2. 🚨 패들 위 100픽셀 (위험)",
        "ball_x": 300, "ball_y": 550,
        "ball_vx": -5, "ball_vy": 0,
        "expected": True,
        "reason": "Y거리 = 100 <= 150"
    },
    {
        "name": "3. 🚨 패들 아래 100픽셀 (위험)",
        "ball_x": 500, "ball_y": 750,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": "Y거리 = 100 <= 150"
    },
    {
        "name": "4. 패들 위 200픽셀 (안전)",
        "ball_x": 400, "ball_y": 450,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "Y거리 = 200 > 150"
    },
    {
        "name": "5. 공이 오른쪽으로 이동 (안전)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": 10, "ball_vy": 0,
        "expected": False,
        "reason": "공이 멀어지는 중"
    },
    {
        "name": "6. 플레이어 뒤 (안전)",
        "ball_x": 50, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "공이 이미 플레이어 뒤"
    },
    {
        "name": "7. 🚨 패들 경계선 150픽셀 (위험)",
        "ball_x": 700, "ball_y": 500,
        "ball_vx": -20, "ball_vy": 0,
        "expected": True,
        "reason": "Y거리 = 150 = 150"
    },
    {
        "name": "8. 패들 경계선 밖 151픽셀 (안전)",
        "ball_x": 700, "ball_y": 499,
        "ball_vx": -20, "ball_vy": 0,
        "expected": False,
        "reason": "Y거리 = 151 > 150"
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
    print("\n✅ 완벽! 매우 단순한 로직이 작동합니다!")
    print("\n발동 조건:")
    print("- 공이 플레이어를 향해 이동 중 (ball_vx < 0)")
    print("- 공이 플레이어 앞에 있음 (ball_x > 82)")
    print(f"- 공이 패들 높이 ±150픽셀 이내 ({PADDLE_Y-150} ~ {PADDLE_Y+150})")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")