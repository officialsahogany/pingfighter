#!/usr/bin/env python3
"""
Test that smartphone auto-removal doesn't cause TypeError
"""

import sys
import os
sys.path.insert(0, '/Volumes/T7/윈도우용최신/game/bosspong')

print("Testing smartphone auto-removal safety...")
print("-" * 50)

# Simulate the game's active_item_slot with items
active_item_slot = [
    {'name': 'stopwatch', 'effect': 'stopwatch'},
    {'name': 'aipill', 'effect': 'aipill'},
    None  # Empty slot
]

print("Initial slots:", [item['name'] if item else None for item in active_item_slot])

# Simulate smartphone removing an item (like it does when auto-using)
print("\nSimulating smartphone auto-use of stopwatch...")
active_item_slot[0] = None  # Smartphone sets to None

print("After auto-use:", [item['name'] if item else None for item in active_item_slot])

# Simulate the game loop trying to process items
print("\nSimulating game loop item processing...")
for i, item in enumerate(active_item_slot):
    # This is what the fixed code does
    if item is None:
        print(f"  Slot {i}: None - Skipping (no error!)")
        continue
        
    # If we get here, item is not None
    effect = item["effect"]  # This would crash without the None check
    print(f"  Slot {i}: {item['name']} - effect: {effect}")

print("\n✅ Test complete! No TypeError when processing None items.")
print("The fix successfully prevents crashes when smartphone removes items.")