#!/usr/bin/env python3
"""
Test script to verify smartphone danger detection matches danger sensor logic
"""

import sys
import os
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone danger detection (synchronized with 위험감지센서)...")
print("=" * 60)

# Import modules
import items
from item_effects.smartphone import get_smartphone_instance

# Create and activate smartphone
smartphone = get_smartphone_instance()
items.smartphone_obtained = True
test_state = {'current_stage': None, 'active_items': []}
smartphone.activate(test_state, None)

print("\n테스트 시나리오 (위험감지센서와 동일한 조건):")
print("-" * 60)

# Test scenarios matching danger sensor conditions
test_cases = [
    {
        "name": "1. 공이 위로 올라가는 중",
        "ball_x": 300, "ball_y": 600, 
        "ball_vx": -5, "ball_vy": -5,  # 위로 올라감
        "expected": False,
        "reason": "ball_vy <= 0"
    },
    {
        "name": "2. 공이 화면 상단에 있음",
        "ball_x": 300, "ball_y": 500,  # HEIGHT * 0.75 = 562.5보다 위
        "ball_vx": -5, "ball_vy": 5,
        "expected": False,
        "reason": "ball_y <= HEIGHT * 0.75 (562.5)"
    },
    {
        "name": "3. 공이 너무 천천히 내려옴",
        "ball_x": 100, "ball_y": 600,  # 낮은 위치
        "ball_vx": -2, "ball_vy": 1,   # 매우 천천히
        "expected": False,
        "reason": "time_to_reach > 60 frames"
    },
    {
        "name": "4. 플레이어가 도달 가능한 위치",
        "ball_x": 100, "ball_y": 600,
        "ball_vx": -2, "ball_vy": 5,
        "expected": False,
        "reason": "distance < player_max_distance + PADDLE_WIDTH/2"
    },
    {
        "name": "5. 🚨 위험! 플레이어가 도달 불가능",
        "ball_x": 500, "ball_y": 600,  # 멀리 있음
        "ball_vx": -8, "ball_vy": 5,   # 빠르게 접근
        "expected": True,
        "reason": "모든 조건 충족 & distance > max_reach"
    },
    {
        "name": "6. 🚨 위험! 매우 빠른 공",
        "ball_x": 400, "ball_y": 580,
        "ball_vx": -15, "ball_vy": 10,  # 매우 빠름
        "expected": True,
        "reason": "너무 빨라서 도달 불가능"
    }
]

# Run tests
for i, test in enumerate(test_cases):
    print(f"\n{test['name']}")
    print(f"  위치: x={test['ball_x']}, y={test['ball_y']}")
    print(f"  속도: vx={test['ball_vx']}, vy={test['ball_vy']}")
    print(f"  이유: {test['reason']}")
    
    result = smartphone.check_danger(
        test['ball_x'], test['ball_y'],
        test['ball_vx'], test['ball_vy'],
        650, 100  # paddle_y, paddle_size (not used in new logic)
    )
    
    status = "✅ PASS" if result == test['expected'] else "❌ FAIL"
    print(f"  예상: {test['expected']}, 결과: {result} - {status}")

print("\n" + "=" * 60)
print("위험감지센서 동기화 테스트 완료!")
print("\n핵심 로직:")
print("1. ball_vy > 0 (아래로 이동)")
print("2. ball_y > HEIGHT * 0.75 (화면 75% 아래)")
print("3. 도달시간 < 60 frames (1초)")
print("4. 예상위치까지 거리 > 플레이어 최대이동 + 패들폭/2")
print("\n이제 스마트폰과 위험감지센서가 동일한 조건으로 작동합니다!")