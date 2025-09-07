#!/usr/bin/env python3
"""
Test smartphone with balanced conditions
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone with balanced danger detection...")
print("=" * 60)

# Import modules
import items
from item_effects.smartphone import get_smartphone_instance

# Create and activate smartphone
smartphone = get_smartphone_instance()
items.smartphone_obtained = True
test_state = {'current_stage': None, 'active_items': []}
smartphone.activate(test_state, None)

print("\n테스트 시나리오 (균형잡힌 조건):")
print("-" * 60)

# Test scenarios
test_cases = [
    {
        "name": "1. 공이 위로 올라감",
        "ball_x": 300, "ball_y": 600,
        "ball_vx": -5, "ball_vy": -5,  # 위로
        "paddle_y": 650,
        "expected": False,
        "reason": "ball_vy <= 0"
    },
    {
        "name": "2. 공이 높은 위치",
        "ball_x": 300, "ball_y": 500,  # 75% 위
        "ball_vx": -5, "ball_vy": 5,
        "paddle_y": 650,
        "expected": False,
        "reason": "ball_y <= HEIGHT * 0.75"
    },
    {
        "name": "3. 공이 패들 바로 앞",
        "ball_x": 60, "ball_y": 630,  # 패들 바로 앞
        "ball_vx": -10, "ball_vy": 5,
        "paddle_y": 650,
        "expected": False,
        "reason": "이미 패들 바로 앞"
    },
    {
        "name": "4. 플레이어가 도달 가능",
        "ball_x": 200, "ball_y": 600,
        "ball_vx": -3, "ball_vy": 5,
        "paddle_y": 650,
        "expected": False,
        "reason": "일반 이동으로 도달 가능"
    },
    {
        "name": "5. 🚨 위험! 빠르고 멀리",
        "ball_x": 400, "ball_y": 580,
        "ball_vx": -15, "ball_vy": 10,
        "paddle_y": 650,
        "expected": True,
        "reason": "도달 불가능 & 멀리 있음"
    },
    {
        "name": "6. 🚨 위험! 매우 빠른 공",
        "ball_x": 500, "ball_y": 600,
        "ball_vx": -25, "ball_vy": 8,
        "paddle_y": 650,
        "expected": True,
        "reason": "너무 빨라서 도달 불가"
    },
    {
        "name": "7. 천천히 내려옴",
        "ball_x": 300, "ball_y": 580,
        "ball_vx": -2, "ball_vy": 2,  # 매우 느림
        "paddle_y": 650,
        "expected": False,
        "reason": "도달 시간 > 60 frames"
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
        test['paddle_y'], 100
    )
    
    if result == test['expected']:
        status = "✅ PASS"
        passed += 1
    else:
        status = "❌ FAIL"
        failed += 1
        
    print(f"  예상: {test['expected']}, 결과: {result} - {status}")

print("\n" + "=" * 60)
print(f"테스트 결과: {passed}/{len(test_cases)} 통과")

if passed == len(test_cases):
    print("\n✅ 완벽! 모든 테스트 통과!")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")

print("\n현재 발동 조건:")
print("1. 공이 아래로 이동 (vy > 0)")
print("2. 공이 화면 75% 아래")
print("3. 1초 이내 도달 예정")
print("4. 플레이어가 도달 불가능")
print("5. 패들 바로 앞이 아님")