#!/usr/bin/env python3
"""
Test smartphone without X-axis distance limit
X축 거리 제한 없이 Y축 조건만 체크
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone without X-axis distance limit...")
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
print(f"패들 상단 Y: {PADDLE_Y - 25} (발동 기준)")
print("-" * 60)

# Test scenarios - X축 거리에 관계없이 Y축 조건만 체크
test_cases = [
    {
        "name": "1. 🚨 멀리 있지만 패들 높이 (위험)",
        "ball_x": 750, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리 무관, Y=650 >= 625"
    },
    {
        "name": "2. 멀리 있고 위쪽 (안전)",
        "ball_x": 750, "ball_y": 500,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "Y=500 < 625"
    },
    {
        "name": "3. 🚨 가까이 패들 높이 (위험)",
        "ball_x": 200, "ball_y": 630,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": "X거리 무관, Y=630 >= 625"
    },
    {
        "name": "4. 🚨 화면 끝 패들 아래 (위험)",
        "ball_x": 800, "ball_y": 700,
        "ball_vx": -5, "ball_vy": 0,
        "expected": True,
        "reason": "X거리 무관, Y=700 >= 625"
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
        "name": "7. 🚨 패들 상단 경계 (위험)",
        "ball_x": 500, "ball_y": 625,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "Y=625 = 패들상단"
    },
    {
        "name": "8. 패들 위 1픽셀 (안전)",
        "ball_x": 500, "ball_y": 624,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "Y=624 < 625"
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
    print("\n✅ 완벽! X축 거리 제한 없이 작동합니다!")
    print("\n발동 조건:")
    print("- 공이 플레이어를 향해 이동 중 (ball_vx < 0)")
    print("- 공이 플레이어 앞에 있음 (ball_x > 82)")
    print("- 공이 패들 높이 아래 (Y >= 625)")
    print("- X축 거리는 무제한!")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")