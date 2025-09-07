#!/usr/bin/env python3
"""
Test smartphone with realistic player position
실제 게임의 플레이어 위치를 반영한 테스트
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone with realistic player position...")
print("=" * 60)

# Import modules
import items
from item_effects.smartphone import get_smartphone_instance

# Create and activate smartphone
smartphone = get_smartphone_instance()
items.smartphone_obtained = True
test_state = {'current_stage': None, 'active_items': []}
smartphone.activate(test_state, None)

# 실제 게임에서의 플레이어 위치
PLAYER_X = 82  # 왼쪽 패들의 일반적인 중심 X 좌표
PADDLE_Y = 650

print(f"플레이어 X 위치: {PLAYER_X}")
print(f"패들 Y 위치: {PADDLE_Y}")
print(f"패들 상단 Y: {PADDLE_Y - 25} (발동 기준)")
print("-" * 60)

# Test scenarios with realistic positions
test_cases = [
    {
        "name": "1. 화면 끝 공 (안전)",
        "ball_x": 750, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리 {750-PLAYER_X} > 600"
    },
    {
        "name": "2. 🚨 화면 중앙 공 (위험)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리 {400-PLAYER_X} < 600, Y={650} >= 625"
    },
    {
        "name": "3. 화면 중앙, 위쪽 공 (안전)",
        "ball_x": 400, "ball_y": 500,
        "ball_vx": -15, "ball_vy": 0,
        "expected": False,
        "reason": f"Y={500} < 패들상단 625"
    },
    {
        "name": "4. 🚨 가까운 공 (위험)",
        "ball_x": 200, "ball_y": 650,
        "ball_vx": -20, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리 {200-PLAYER_X} < 600, Y조건 만족"
    },
    {
        "name": "5. 🚨 600픽셀 경계 (위험)",
        "ball_x": 682, "ball_y": 630,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": f"X거리 = 600, Y >= 625"
    },
    {
        "name": "6. 601픽셀 거리 (안전)",
        "ball_x": 683, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": f"X거리 = 601 > 600"
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
    
    # Test with actual player position
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
    print("\n✅ 완벽! 실제 플레이어 위치에서 작동합니다!")
    print("\n실제 게임 발동 조건:")
    print(f"- 공이 플레이어({PLAYER_X})로부터 600픽셀 이내")
    print(f"- 공이 패들 높이({PADDLE_Y-25}) 아래")
    print("- 공이 왼쪽으로 이동 중")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")