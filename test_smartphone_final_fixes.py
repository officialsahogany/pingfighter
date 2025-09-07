#!/usr/bin/env python3
"""
Test smartphone final fixes:
1. Ball above player's head should NOT activate
2. Player serve should NOT activate
3. Unreachable balls should be ignored
4. Player should NEVER lose when smartphone is equipped
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone final fixes...")
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
print("-" * 60)

# Test scenarios
test_cases = [
    # 1. Ball above player's head tests
    {
        "name": "1. 공이 플레이어 머리 바로 위 (안전)",
        "ball_x": 200, "ball_y": 590,  # 패들보다 60픽셀 위
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "머리 위에 있는 공은 발동하지 않음"
    },
    {
        "name": "2. 공이 플레이어 머리 위, 빠른 속도 (안전)",
        "ball_x": 300, "ball_y": 580,  # 패들보다 70픽셀 위
        "ball_vx": -20, "ball_vy": 0,
        "expected": False,
        "reason": "머리 위는 속도와 관계없이 발동 안함"
    },
    
    # 2. Player serve tests
    {
        "name": "3. 플레이어가 막 서브한 공 (안전)",
        "ball_x": 150, "ball_y": 650,
        "ball_vx": -5, "ball_vy": 0,
        "expected": False,
        "reason": "플레이어 근처에서 시작한 공은 서브로 판단"
    },
    {
        "name": "4. 플레이어 서브 직후 (안전)",
        "ball_x": 180, "ball_y": 650,
        "ball_vx": -8, "ball_vy": 0,
        "expected": False,
        "reason": "X < 200이고 거리 < 100은 서브"
    },
    
    # 3. Unreachable balls tests
    {
        "name": "5. Y축 너무 멀리 위 (도달 불가)",
        "ball_x": 400, "ball_y": 450,  # 패들에서 200픽셀 위
        "ball_vx": -15, "ball_vy": 0,
        "expected": False,
        "reason": "Y거리 > 150은 도달 불가능"
    },
    {
        "name": "6. Y축 너무 멀리 아래 (도달 불가)",
        "ball_x": 400, "ball_y": 850,  # 패들에서 200픽셀 아래
        "ball_vx": -15, "ball_vy": 0,
        "expected": False,
        "reason": "Y거리 > 150은 도달 불가능"
    },
    {
        "name": "7. 화면 밖으로 나가는 공 (도달 불가)",
        "ball_x": 500, "ball_y": 100,
        "ball_vx": -10, "ball_vy": -50,  # 위로 빠르게 이동
        "expected": False,
        "reason": "화면 밖으로 나가는 공은 무시"
    },
    
    # 4. Never lose scenarios (MUST activate)
    {
        "name": "8. 🚨🚨 매우 가까운 공 (긴급 발동)",
        "ball_x": 150, "ball_y": 650,
        "ball_vx": -20, "ball_vy": 0,
        "expected": True,
        "reason": "X ≤ 80이고 Y ≤ 150이면 긴급 발동"
    },
    {
        "name": "9. 🚨🚨 마지막 순간 보호 (긴급 발동)",
        "ball_x": 180, "ball_y": 700,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X ≤ 120이고 Y ≤ 100이면 마지막 보호"
    },
    {
        "name": "10. 🚨 빠른 공 패들 높이 (위험)",
        "ball_x": 300, "ball_y": 650,
        "ball_vx": -25, "ball_vy": 0,
        "expected": True,
        "reason": "초고속 공은 발동"
    },
    {
        "name": "11. 🚨 가장자리 위험 (발동)",
        "ball_x": 250, "ball_y": 685,
        "ball_vx": -12, "ball_vy": 0,
        "expected": True,
        "reason": "패들 가장자리는 위험"
    },
    
    # 5. Edge cases
    {
        "name": "12. 공이 오른쪽으로 이동 (안전)",
        "ball_x": 150, "ball_y": 650,
        "ball_vx": 10, "ball_vy": 0,
        "expected": False,
        "reason": "멀어지는 공은 무시"
    },
    {
        "name": "13. 공이 플레이어 뒤 (안전)",
        "ball_x": 50, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "이미 지나간 공은 무시"
    },
    {
        "name": "14. 느린 공 (안전)",
        "ball_x": 200, "ball_y": 650,
        "ball_vx": -3, "ball_vy": 0,
        "expected": False,
        "reason": "속도 < 5는 너무 느림"
    },
    
    # 6. Boundary tests
    {
        "name": "15. 패들 정확히 50픽셀 위 (머리 위 경계)",
        "ball_x": 300, "ball_y": 600,
        "ball_vx": -15, "ball_vy": 0,
        "expected": False,
        "reason": "패들 높이(50) 위는 머리 위"
    },
    {
        "name": "16. 패들 49픽셀 위 (머리 위 아님)",
        "ball_x": 300, "ball_y": 601,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": "패들 높이 내부는 위험 감지"
    },
    {
        "name": "17. Y거리 정확히 150 (경계)",
        "ball_x": 400, "ball_y": 500,
        "ball_vx": -15, "ball_vy": 0,
        "expected": False,
        "reason": "Y거리 = 150은 도달 가능 범위"
    },
    {
        "name": "18. Y거리 151 (도달 불가)",
        "ball_x": 400, "ball_y": 499,
        "ball_vx": -15, "ball_vy": 0,
        "expected": False,
        "reason": "Y거리 > 150은 도달 불가"
    }
]

# Run tests
passed = 0
failed = 0
failures = []

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
        failures.append(test['name'])
        
    expected_str = "발동" if test['expected'] else "안전"
    result_str = "발동" if result else "안전"
    print(f"  예상: {expected_str}, 결과: {result_str} - {status}")

print("\n" + "=" * 60)
print(f"테스트 결과: {passed}/{len(test_cases)} 통과")

if failed > 0:
    print(f"\n⚠️ {failed}개 테스트 실패:")
    for failure in failures:
        print(f"  - {failure}")
else:
    print("\n✅ 모든 테스트 통과!")
    print("\n수정 사항:")
    print("1. ✅ 공이 플레이어 머리 위에 있을 때 발동 안함")
    print("2. ✅ 플레이어가 서브한 공은 발동 안함")
    print("3. ✅ 도달 불가능한 공은 무시")
    print("4. ✅ 플레이어가 절대 패배하지 않도록 보호")