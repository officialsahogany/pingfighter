#!/usr/bin/env python3
"""
Test smartphone X distance fix - should NOT activate when ball is close
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone X distance fix...")
print("=" * 60)
print("수정 사항:")
print("1. 공이 플레이어 왼쪽(뒤)에 있으면 발동 안함")
print("2. X거리를 절대값이 아닌 실제 거리로 계산")
print("3. 공이 플레이어 오른쪽 300픽셀 이상에서만 발동")
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

# Test scenarios focusing on X distance issues
test_cases = [
    {
        "name": "1. 공이 플레이어 왼쪽에 있음 (절대 발동 안함)",
        "ball_x": 30, "ball_y": 650,  # 플레이어(50) 왼쪽
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "ball_x < PLAYER_CENTERX"
    },
    {
        "name": "2. 공이 플레이어 바로 앞 (가까움)",
        "ball_x": 100, "ball_y": 650,  # X거리 50
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "X거리 50 < 300"
    },
    {
        "name": "3. 공이 가까운 거리 (X=200)",
        "ball_x": 250, "ball_y": 650,  # X거리 200
        "ball_vx": -15, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "X거리 200 < 300"
    },
    {
        "name": "4. 경계선 케이스 (X거리=300)",
        "ball_x": 350, "ball_y": 650,  # X거리 정확히 300
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "X거리 300 = 300 (도달 가능)"
    },
    {
        "name": "5. 🚨 경계선 넘음 (X거리=301)",
        "ball_x": 351, "ball_y": 650,  # X거리 301
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "X거리 301 > 300 (발동!)"
    },
    {
        "name": "6. 🚨 멀리 있음 (X거리=400)",
        "ball_x": 450, "ball_y": 650,  # X거리 400
        "ball_vx": -20, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "X거리 400 > 300 (발동!)"
    },
    {
        "name": "7. 공이 왼쪽에서 빠르게 접근 (절대 발동 안함)",
        "ball_x": -50, "ball_y": 650,  # 왼쪽 멀리
        "ball_vx": -30, "ball_vy": 0,  # 매우 빠름
        "paddle_y": 650,
        "expected": False,
        "reason": "ball_x < PLAYER_CENTERX (왼쪽)"
    },
    {
        "name": "8. 공이 플레이어 위치에 정확히 있음",
        "ball_x": 50, "ball_y": 650,  # 플레이어와 같은 X
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "ball_x = PLAYER_CENTERX"
    }
]

# Run tests
passed = 0
failed = 0

for i, test in enumerate(test_cases):
    print(f"\n{test['name']}")
    print(f"  위치: ({test['ball_x']}, {test['ball_y']})")
    print(f"  속도: vx={test['ball_vx']}, vy={test['ball_vy']}")
    print(f"  플레이어 Y: {test['paddle_y']}")
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
    print("\n✅ 완벽! X거리 버그가 수정되었습니다!")
    print("\n수정 내용:")
    print("- 공이 플레이어 왼쪽에 있으면 절대 발동 안함")
    print("- X거리를 절대값이 아닌 실제 오른쪽 거리로 계산")
    print("- 오직 공이 오른쪽 300픽셀 이상에서만 발동")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")