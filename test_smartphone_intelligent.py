#!/usr/bin/env python3
"""
Test smartphone with intelligent danger detection
플레이어가 반격할 수 없는 상황을 지능적으로 판단
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone intelligent danger detection...")
print("=" * 60)
print("플레이어가 반격할 수 없는 상황을 지능적으로 감지")
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

# Test scenarios for intelligent detection
test_cases = [
    {
        "name": "1. 느린 공, 가까운 거리 (반격 가능)",
        "ball_x": 100, "ball_y": 650,
        "ball_vx": -8, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "느린 속도로 반격 가능"
    },
    {
        "name": "2. 🚨 초고속 공, 가까운 거리 (반응 불가)",
        "ball_x": 180, "ball_y": 650,
        "ball_vx": -30, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "속도 30, 도달시간 < 5프레임"
    },
    {
        "name": "3. 빠른 공, Y축 이동 필요 (반격 불가)",
        "ball_x": 150, "ball_y": 600,
        "ball_vx": -20, "ball_vy": 5,
        "paddle_y": 650,
        "expected": True,
        "reason": "Y축 이동 시간 부족"
    },
    {
        "name": "4. 중속 공, Y축 가까움 (반격 가능)",
        "ball_x": 150, "ball_y": 640,
        "ball_vx": -12, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "Y축 이동 거리 작음"
    },
    {
        "name": "5. 🚨 패들 가장자리 노림 (위험)",
        "ball_x": 200, "ball_y": 695,
        "ball_vx": -15, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "가장자리 + 빠른 속도"
    },
    {
        "name": "6. 먼 거리, 중속 (반격 가능)",
        "ball_x": 400, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "충분한 반응 시간"
    },
    {
        "name": "7. 🚨 중거리 초고속 (대쉬로도 불가)",
        "ball_x": 250, "ball_y": 650,
        "ball_vx": -25, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "대쉬로도 도달 불가"
    },
    {
        "name": "8. 높이 벗어남, 느린 공 (안전)",
        "ball_x": 200, "ball_y": 500,
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "Y거리 > 100, 느린 속도"
    },
    {
        "name": "9. 🚨 높이 벗어났지만 초고속 (위험)",
        "ball_x": 180, "ball_y": 500,
        "ball_vx": -35, "ball_vy": 10,
        "paddle_y": 650,
        "expected": True,
        "reason": "초고속으로 위험"
    },
    {
        "name": "10. 가까운 거리, 중속, Y축 적당 (반격 가능)",
        "ball_x": 120, "ball_y": 630,
        "ball_vx": -10, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "모든 조건 적당함"
    },
    {
        "name": "11. 🚨 빠른 공 + Y축 멀리 (이동 불가)",
        "ball_x": 130, "ball_y": 550,
        "ball_vx": -18, "ball_vy": 0,
        "paddle_y": 650,
        "expected": True,
        "reason": "Y축 100픽셀 이동 불가"
    },
    {
        "name": "12. 매우 느린 공 (항상 안전)",
        "ball_x": 100, "ball_y": 650,
        "ball_vx": -3, "ball_vy": 0,
        "paddle_y": 650,
        "expected": False,
        "reason": "속도 < 5"
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
        
    expected_str = "발동" if test['expected'] else "안전"
    result_str = "발동" if result else "안전"
    print(f"  예상: {expected_str}, 결과: {result_str} - {status}")

print("\n" + "=" * 60)
print(f"테스트 결과: {passed}/{len(test_cases)} 통과")

if passed == len(test_cases):
    print("\n✅ 완벽! 지능적인 위험 감지가 작동합니다!")
    print("\n발동 시나리오:")
    print("- 초고속 공 (속도 ≥25, 도달시간 ≤5)")
    print("- Y축 이동 시간 부족")
    print("- 대쉬로도 도달 불가능")
    print("- 패들 가장자리 위험")
    print("- 높이 벗어났지만 초고속")
else:
    print(f"\n⚠️ {failed}개 테스트 실패")