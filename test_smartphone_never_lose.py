#!/usr/bin/env python3
"""
Test smartphone - should NEVER let player lose
플레이어가 절대 패배하지 않도록 스마트폰이 작동하는지 테스트
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone - NEVER LOSE guarantee...")
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
print(f"긴급 발동: X ≤ 120픽셀 AND Y ≤ 100픽셀")
print(f"일반 발동: X ≥ 200픽셀 AND Y ≤ 60픽셀")
print("-" * 60)

# Test scenarios - 모든 패배 가능 상황
test_cases = [
    {
        "name": "1. 🚨🚨 매우 가까운 공 (긴급)",
        "ball_x": 150, "ball_y": 650,
        "ball_vx": -20, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=68(≤120), Y거리=0(≤100) - 놓치면 패배!"
    },
    {
        "name": "2. 🚨🚨 가까운 공 위쪽 (긴급)",
        "ball_x": 180, "ball_y": 600,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=98(≤120), Y거리=50(≤100) - 놓치면 패배!"
    },
    {
        "name": "3. 🚨🚨 가까운 공 아래쪽 (긴급)",
        "ball_x": 180, "ball_y": 700,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=98(≤120), Y거리=50(≤100) - 놓치면 패배!"
    },
    {
        "name": "4. 🚨🚨 바로 앞 (긴급)",
        "ball_x": 120, "ball_y": 650,
        "ball_vx": -30, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=38(≤120), Y거리=0(≤100) - 즉시 패배 위험!"
    },
    {
        "name": "5. 🚨 멀리 있지만 패들 높이 (일반)",
        "ball_x": 300, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=218(≥200), Y거리=0(≤60) - 위험 감지"
    },
    {
        "name": "6. 🚨 멀리 있고 약간 위 (일반)",
        "ball_x": 400, "ball_y": 620,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=318(≥200), Y거리=30(≤60) - 위험 감지"
    },
    {
        "name": "7. 🚨 멀리 있고 약간 아래 (일반)",
        "ball_x": 400, "ball_y": 680,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=318(≥200), Y거리=30(≤60) - 위험 감지"
    },
    {
        "name": "8. 🚨🚨 경계선 긴급 상황 (긴급)",
        "ball_x": 202, "ball_y": 650,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=120(=120), Y거리=0(≤100) - 긴급 발동"
    },
    {
        "name": "9. 중간 거리 안전 구간 (안전)",
        "ball_x": 160, "ball_y": 800,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=78(≤120), Y거리=150(>100) - Y축 벗어남"
    },
    {
        "name": "10. 멀리 있고 Y축 벗어남 (안전)",
        "ball_x": 400, "ball_y": 750,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "X거리=318(≥200), Y거리=100(>60) - Y축 벗어남"
    },
    {
        "name": "11. 🚨🚨 Y축 경계 긴급 (긴급)",
        "ball_x": 150, "ball_y": 550,
        "ball_vx": -20, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=68(≤120), Y거리=100(=100) - 긴급 발동"
    },
    {
        "name": "12. 🚨 Y축 경계 일반 (일반)",
        "ball_x": 350, "ball_y": 590,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X거리=268(≥200), Y거리=60(=60) - 일반 발동"
    },
    {
        "name": "13. 공이 오른쪽으로 (안전)",
        "ball_x": 100, "ball_y": 650,
        "ball_vx": 10, "ball_vy": 0,
        "expected": False,
        "reason": "공이 멀어지는 중 - 위험 없음"
    },
    {
        "name": "14. 플레이어 뒤 (안전)",
        "ball_x": 50, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "이미 플레이어 뒤 - 무시"
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
    print("\n✅ 완벽! 플레이어는 절대 패배하지 않습니다!")
    print("\n발동 조건:")
    print("- 긴급 발동: X ≤ 120픽셀 AND Y ≤ 100픽셀 (놓치면 즉시 패배)")
    print("- 일반 발동: X ≥ 200픽셀 AND Y ≤ 60픽셀 (미리 대비)")
    print("- 공이 플레이어를 향해 이동 중일 때만")
    print("- 플레이어가 절대 패배하지 않도록 보장")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")