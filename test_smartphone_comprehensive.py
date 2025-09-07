#!/usr/bin/env python3
"""
Comprehensive smartphone test - Final verification
All requirements:
1. Ball above player's head should NOT activate
2. Player serve should NOT activate
3. Unreachable balls should be ignored
4. Player should NEVER lose when smartphone is equipped
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("🔍 Comprehensive Smartphone Test")
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
PADDLE_HEIGHT = 50
PADDLE_TOP = PADDLE_Y - (PADDLE_HEIGHT / 2)  # 625
PADDLE_BOTTOM = PADDLE_Y + (PADDLE_HEIGHT / 2)  # 675

print(f"플레이어 X 위치: {PLAYER_X}")
print(f"패들 Y 중심: {PADDLE_Y}")
print(f"패들 상단: {PADDLE_TOP}")
print(f"패들 하단: {PADDLE_BOTTOM}")
print(f"패들 높이: {PADDLE_HEIGHT}")
print("-" * 60)

# Test categories
categories = {
    "머리 위 방지": [],
    "서브 방지": [],
    "도달 불가": [],
    "패배 방지": [],
}

# Test scenarios
test_cases = [
    # === 머리 위 방지 테스트 ===
    {
        "category": "머리 위 방지",
        "name": "패들 바로 위 (Y=620)",
        "ball_x": 300, "ball_y": 620,
        "ball_vx": -15, "ball_vy": 0,
        "expected": False,
        "reason": "패들 상단(625)보다 위"
    },
    {
        "category": "머리 위 방지",
        "name": "패들 위 빠른 공",
        "ball_x": 250, "ball_y": 600,
        "ball_vx": -25, "ball_vy": 0,
        "expected": False,
        "reason": "머리 위는 속도 무관"
    },
    {
        "category": "머리 위 방지",
        "name": "패들 상단 경계 (Y=624)",
        "ball_x": 300, "ball_y": 624,
        "ball_vx": -15, "ball_vy": 0,
        "expected": False,
        "reason": "패들 상단(625)보다 위"
    },
    {
        "category": "머리 위 방지",
        "name": "패들 내부 (Y=626)",
        "ball_x": 300, "ball_y": 626,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": "패들 범위 내 위험"
    },
    
    # === 서브 방지 테스트 ===
    {
        "category": "서브 방지",
        "name": "플레이어 서브 (느림)",
        "ball_x": 150, "ball_y": 650,
        "ball_vx": -5, "ball_vy": 0,
        "expected": False,
        "reason": "X<200 & 속도<10 = 서브"
    },
    {
        "category": "서브 방지",
        "name": "서브 직후 (느림)",
        "ball_x": 190, "ball_y": 650,
        "ball_vx": -8, "ball_vy": 0,
        "expected": False,
        "reason": "X<200 & 속도<10 = 서브"
    },
    {
        "category": "서브 방지",
        "name": "빠른 공 (서브 아님)",
        "ball_x": 190, "ball_y": 650,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": "속도>=10은 서브 아님"
    },
    
    # === 도달 불가 테스트 ===
    {
        "category": "도달 불가",
        "name": "Y축 너무 멀리 (200픽셀)",
        "ball_x": 400, "ball_y": 450,
        "ball_vx": -15, "ball_vy": 0,
        "expected": False,
        "reason": "머리 위 + Y>150"
    },
    {
        "category": "도달 불가",
        "name": "Y축 너무 아래 (200픽셀)",
        "ball_x": 400, "ball_y": 850,
        "ball_vx": -15, "ball_vy": 0,
        "expected": False,
        "reason": "Y거리>150 도달불가"
    },
    {
        "category": "도달 불가",
        "name": "화면 밖으로",
        "ball_x": 500, "ball_y": 700,
        "ball_vx": -10, "ball_vy": 100,
        "expected": False,
        "reason": "화면 밖 예상"
    },
    
    # === 패배 방지 테스트 (반드시 발동) ===
    {
        "category": "패배 방지",
        "name": "🚨 매우 가까운 위험",
        "ball_x": 150, "ball_y": 650,
        "ball_vx": -12, "ball_vy": 0,
        "expected": True,
        "reason": "X≤80 & 속도≥8 긴급"
    },
    {
        "category": "패배 방지",
        "name": "🚨 마지막 순간",
        "ball_x": 180, "ball_y": 680,
        "ball_vx": -10, "ball_vy": 0,
        "expected": True,
        "reason": "X≤120 & Y≤100 보호"
    },
    {
        "category": "패배 방지",
        "name": "🚨 초고속 공",
        "ball_x": 300, "ball_y": 650,
        "ball_vx": -25, "ball_vy": 0,
        "expected": True,
        "reason": "속도≥20 반응불가"
    },
    {
        "category": "패배 방지",
        "name": "🚨 패들 가장자리",
        "ball_x": 250, "ball_y": 690,
        "ball_vx": -12, "ball_vy": 0,
        "expected": True,
        "reason": "가장자리 위험"
    },
    {
        "category": "패배 방지",
        "name": "🚨 중거리 빠른 공",
        "ball_x": 350, "ball_y": 650,
        "ball_vx": -20, "ball_vy": 0,
        "expected": True,
        "reason": "대쉬로도 불가"
    },
    
    # === 경계 케이스 ===
    {
        "category": "패배 방지",
        "name": "패들 중심",
        "ball_x": 300, "ball_y": 650,
        "ball_vx": -15, "ball_vy": 0,
        "expected": True,
        "reason": "일반 위험"
    },
    {
        "category": "도달 불가",
        "name": "오른쪽으로 이동",
        "ball_x": 200, "ball_y": 650,
        "ball_vx": 10, "ball_vy": 0,
        "expected": False,
        "reason": "멀어지는 공"
    },
    {
        "category": "도달 불가",
        "name": "플레이어 뒤",
        "ball_x": 50, "ball_y": 650,
        "ball_vx": -10, "ball_vy": 0,
        "expected": False,
        "reason": "이미 지나감"
    },
    {
        "category": "도달 불가",
        "name": "너무 느린 공",
        "ball_x": 300, "ball_y": 650,
        "ball_vx": -3, "ball_vy": 0,
        "expected": False,
        "reason": "속도<5 무시"
    },
]

# Run tests
for test in test_cases:
    result = smartphone.check_danger(
        test['ball_x'], test['ball_y'],
        test['ball_vx'], test['ball_vy'],
        PADDLE_Y, 100, PLAYER_X
    )
    
    test['passed'] = (result == test['expected'])
    test['result'] = result
    categories[test['category']].append(test)

# Report results by category
print("\n📊 테스트 결과 (카테고리별)")
print("=" * 60)

total_tests = 0
total_passed = 0

for category_name, tests in categories.items():
    if not tests:
        continue
        
    passed = sum(1 for t in tests if t['passed'])
    total = len(tests)
    total_tests += total
    total_passed += passed
    
    print(f"\n### {category_name}: {passed}/{total} 통과")
    print("-" * 40)
    
    for test in tests:
        status = "✅" if test['passed'] else "❌"
        expected = "발동" if test['expected'] else "안전"
        result = "발동" if test['result'] else "안전"
        
        print(f"{status} {test['name']}")
        print(f"   위치: ({test['ball_x']}, {test['ball_y']}), 속도: ({test['ball_vx']}, {test['ball_vy']})")
        print(f"   예상: {expected}, 결과: {result}")
        if not test['passed']:
            print(f"   ⚠️ 실패 이유: {test['reason']}")

print("\n" + "=" * 60)
print(f"📈 전체 결과: {total_passed}/{total_tests} 통과")

if total_passed == total_tests:
    print("\n🎉 완벽! 모든 요구사항 충족!")
    print("✅ 머리 위 공은 발동 안함")
    print("✅ 플레이어 서브는 발동 안함")
    print("✅ 도달 불가능한 공은 무시")
    print("✅ 플레이어는 절대 패배하지 않음")
else:
    failed_count = total_tests - total_passed
    print(f"\n⚠️ {failed_count}개 테스트 실패")
    print("문제 카테고리:")
    for category_name, tests in categories.items():
        failed = [t for t in tests if not t['passed']]
        if failed:
            print(f"  - {category_name}: {len(failed)}개 실패")