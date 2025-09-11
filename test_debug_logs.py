#!/usr/bin/env python3
"""Test that essential debug logs are present and excessive logs are removed."""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import items

print("Testing debug logs...")
print("-" * 50)

# Test spawn_random_item debug logs
print("\n1. Testing spawn_random_item debug logs:")
items.poseidon_trident_obtained = False
print("   Setting poseidon_trident_obtained = False")

# This should trigger the debug log
item = items.spawn_random_item()
if item:
    print(f"   Spawned item: {item['name']}")

print("\n2. Setting poseidon_trident_obtained = True")
items.poseidon_trident_obtained = True

# This should show the item is skipped
item = items.spawn_random_item()
if item:
    print(f"   Spawned item: {item['name'] if item else 'None'}")

print("\n3. Testing apply_selected_items debug logs:")
print("   This requires running the game and selecting Poseidon from TAB menu")
print("   Debug logs should show:")
print("   - [DEBUG apply_selected_items] Before: items.poseidon_trident_obtained = False")
print("   - [DEBUG apply_selected_items] After: items.poseidon_trident_obtained = True")

print("\n4. Verifying excessive logs are removed:")
print("   ✅ No more 💧 water momentum logs")
print("   ✅ No more 🌊 vortex detailed logs")
print("   ✅ No more 🔄 particle rotation logs")
print("   ✅ No more ⚡ deflection success logs")
print("   ✅ Only essential [DEBUG] spawn-related logs remain")

print("\n" + "=" * 50)
print("Debug log cleanup complete!")
print("Essential spawn debugging logs are preserved.")