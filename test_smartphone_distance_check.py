#!/usr/bin/env python3
"""
Test smartphone distance check - only activates when ball is far from player
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone distance-based activation...")
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

# Test scenarios
test_cases = [
    {
        "name": "1. 공이 플레이어와 매우 가까움 (안전거리)",
        "ball_x": 80, "ball_y": 640,  # 플레이어(50, 650) 근처
        "ball_vx": -5, "ball_vy": 5,
        "paddle_y": 650,
        "expected": False,
        "reason": "Y 거리 < 패들높이*2 (안전거리)"
    },
    {
        "name": "2. 공이 가까이 있지만 도달 불가능한 위치",
        "ball_x": 120, "ball_y": 600,  # 가까운 거리
        "ball_vx": -20, "ball_vy": 8,
        "paddle_y": 650,
        "expected": False,
        "reason": "현재 거리 < 150픽셀 (너무 가까움)"
    },
    {
        "name": "3. 공이 멀리 있고 도달 가능",
        "ball_x": 300, "ball_y": 580,
        "ball_vx": -3, "ball_vy": 5,
        "paddle_y": 650,
        "expected": False,
        "reason": "플레이어가 이동으로 도달 가능"
    },
    {
        "name": "4. 🚨 공이 멀리 있고 도달 불가능 (발동!)",
        "ball_x": 400, "ball_y": 580,  # 멀리 있음
        "ball_vx": -15, "ball_vy": 10,  # 빠르게 접근
        "paddle_y": 650,
        "expected": True,
        "reason": "거리 > 150 && 도달 불가능"
    },
    {
        "name": "5. 🚨 매우 멀리서 빠르게 접근 (발동!)",
        "ball_x": 500, "ball_y": 570,
        "ball_vx": -20, "ball_vy": 15,
        "paddle_y": 650,
        "expected": True,
        "reason": "완벽한 발동 조건"
    }
]

# Run tests
passed = 0
failed = 0

for i, test in enumerate(test_cases):
    print(f"\n{test['name']}")
    print(f"  공 위치: ({test['ball_x']}, {test['ball_y']})")
    print(f"  공 속도: vx={test['ball_vx']}, vy={test['ball_vy']}")
    print(f"  플레이어 Y: {test['paddle_y']}")
    print(f"  이유: {test['reason']}")
    
    result = smartphone.check_danger(
        test['ball_x'], test['ball_y'],
        test['ball_vx'], test['ball_vy'],
        test['paddle_y'], 100  # paddle_size
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

print("\n핵심 개선사항:")
print("1. Y 거리 체크: 패들 높이*2 이내면 안전거리로 판단")
print("2. 최소 거리 체크: 150픽셀 이상 떨어져 있어야 아이템 사용")
print("3. 가까이 있으면 대쉬나 일반 이동으로 막을 수 있다고 판단")
print("\n이제 스마트폰이 정말 위험한 상황에서만 아이템을 사용합니다!")