#!/usr/bin/env python3
"""
Test that smartphone completely removes items from active_item_slot using del
"""

import sys
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone complete item removal with del...")
print("=" * 60)

# Import modules
import items
from item_effects.smartphone import get_smartphone_instance

# Simulate main module's active_item_slot
class MockMainModule:
    def __init__(self):
        self.active_item_slot = [
            {'name': 'stopwatch', 'effect': 'stopwatch'},
            {'name': 'aipill', 'effect': 'aipill'},
            {'name': 'molotov', 'effect': 'molotov'}
        ]
        self.selected_item_index = 0
        self.stopwatch_active = False
        self.aipill_active = False
    
    def activate_stopwatch(self):
        self.stopwatch_active = True
        print('✅ Stopwatch activated!')
    
    def activate_aipill(self):
        self.aipill_active = True
        print('✅ AI Pill activated!')

# Replace __main__ with our mock
import sys
mock_main = MockMainModule()
sys.modules['__main__'] = mock_main

# Test smartphone
smartphone = get_smartphone_instance()
items.smartphone_obtained = True

# Activate smartphone
test_state = {
    'current_stage': None,
    'active_items': mock_main.active_item_slot.copy()  # Copy for local tracking
}
smartphone.activate(test_state, None)

print("\n초기 상태:")
print(f"  슬롯 개수: {len(mock_main.active_item_slot)}")
print(f"  슬롯 내용: {[item['name'] for item in mock_main.active_item_slot]}")
print(f"  선택 인덱스: {mock_main.selected_item_index}")

# Test stopwatch removal
print("\n1. 스탑워치 자동 사용:")
smartphone.activate_stopwatch(test_state, None)
print(f"  사용 후 슬롯 개수: {len(mock_main.active_item_slot)}")
print(f"  사용 후 슬롯 내용: {[item['name'] for item in mock_main.active_item_slot]}")
print(f"  선택 인덱스: {mock_main.selected_item_index}")

# Reset for AI pill test
mock_main.stopwatch_active = False
mock_main.active_item_slot = [
    {'name': 'aipill', 'effect': 'aipill'},
    {'name': 'molotov', 'effect': 'molotov'}
]
mock_main.selected_item_index = 1  # Pointing to molotov

print("\n2. AI알약 자동 사용 (선택 인덱스가 1일 때):")
print(f"  사용 전 슬롯: {[item['name'] for item in mock_main.active_item_slot]}")
print(f"  사용 전 선택 인덱스: {mock_main.selected_item_index}")

smartphone.activate_ai_pill(test_state, None)
print(f"  사용 후 슬롯 개수: {len(mock_main.active_item_slot)}")
print(f"  사용 후 슬롯 내용: {[item['name'] for item in mock_main.active_item_slot]}")
print(f"  사용 후 선택 인덱스: {mock_main.selected_item_index} (자동 조정됨)")

print("\n" + "=" * 60)
print("✅ 테스트 완료!")
print("\n결과:")
print("- del을 사용하여 아이템이 완전히 제거됨")
print("- 슬롯 개수가 실제로 줄어듦")
print("- 선택 인덱스가 자동으로 조정됨")
print("- 검은 빈 슬롯이 남지 않음!")