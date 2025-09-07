#!/usr/bin/env python3
"""
Test smartphone activation with simple conditions
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone activation...")
print("=" * 60)

# Import modules
import items
from item_effects.smartphone import get_smartphone_instance

# Create and activate smartphone
smartphone = get_smartphone_instance()
items.smartphone_obtained = True

# Create test state with stopwatch
test_state = {
    'current_stage': None,
    'active_items': [
        {'name': 'stopwatch', 'effect': 'stopwatch'},
        {'name': 'molotov', 'effect': 'molotov'}
    ]
}

# Activate smartphone
smartphone.activate(test_state, None)

print("\n테스트 1: 일반적인 위험 상황")
print("-" * 60)

# Create a mock stage with danger situation
class MockStage:
    def __init__(self):
        self.ball_x = 200
        self.ball_y = 650
        self.ball_vx = -15
        self.ball_vy = 0
        self.paddle_y = 650
        self.paddle_size = 100

stage = MockStage()

# Test update
print(f"공 위치: ({stage.ball_x}, {stage.ball_y})")
print(f"공 속도: ({stage.ball_vx}, {stage.ball_vy})")
print(f"패들 Y: {stage.paddle_y}")
print("\nUpdate 호출:")
smartphone.update(test_state, stage)

print("\n" + "=" * 60)
print("테스트 2: 매우 빠른 공")
print("-" * 60)

# Reset for next test
smartphone.auto_activated = False
smartphone.last_activation_time = 0

stage.ball_x = 250
stage.ball_vx = -25
print(f"공 위치: ({stage.ball_x}, {stage.ball_y})")
print(f"공 속도: ({stage.ball_vx}, {stage.ball_vy})")
print("\nUpdate 호출:")
smartphone.update(test_state, stage)

print("\n" + "=" * 60)
print("테스트 3: 가까운 거리 초고속")
print("-" * 60)

# Reset for next test
smartphone.auto_activated = False
smartphone.last_activation_time = 0

stage.ball_x = 150
stage.ball_vx = -30
print(f"공 위치: ({stage.ball_x}, {stage.ball_y})")
print(f"공 속도: ({stage.ball_vx}, {stage.ball_vy})")
print("\nUpdate 호출:")
smartphone.update(test_state, stage)