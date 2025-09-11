#!/usr/bin/env python3
"""
Complete flow test for Poseidon's Trident duplicate issue
Tests both TAB menu selection and spawn prevention
"""

import pygame
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import items
from pingfighter import apply_selected_items, store_passive_item

def test_complete_poseidon_flow():
    """Test the complete flow of Poseidon's Trident selection and spawning"""
    pygame.init()
    
    print("🔱 Complete Poseidon's Trident Flow Test")
    print("=" * 60)
    
    # Step 1: Check initial state
    print("\n1️⃣ Initial State:")
    print(f"   items.poseidon_trident_obtained = {items.poseidon_trident_obtained}")
    
    # Step 2: Check if Poseidon's Trident is in ITEM_TYPES
    poseidon_in_items = False
    for item in items.ITEM_TYPES:
        if item["name"] == "poseidon_trident":
            poseidon_in_items = True
            print(f"   ✓ Poseidon's Trident found in ITEM_TYPES")
            print(f"     - color: {item['color']}")
            print(f"     - chance: {item.get('chance', 'N/A')}")
            break
    
    if not poseidon_in_items:
        print(f"   ❌ Poseidon's Trident NOT found in ITEM_TYPES!")
    
    # Step 3: Simulate TAB menu selection
    print("\n2️⃣ Simulating TAB Menu Selection:")
    print("   Calling apply_selected_items with poseidon_trident...")
    
    # Clear any previous state
    items.poseidon_trident_obtained = False
    
    # Simulate selecting Poseidon's Trident from TAB menu
    apply_selected_items([], ["poseidon_trident"], ["poseidon_trident"])
    
    print(f"   After TAB selection: items.poseidon_trident_obtained = {items.poseidon_trident_obtained}")
    
    # Step 4: Check if spawn would be prevented
    print("\n3️⃣ Testing Spawn Prevention:")
    
    # Test spawn_random_item logic
    available_for_spawn = []
    for item in items.ITEM_TYPES:
        # Check the exact condition used in spawn_random_item
        if item["name"] == "poseidon_trident":
            if items.poseidon_trident_obtained:
                print(f"   ✓ Poseidon's Trident spawn BLOCKED (obtained flag is True)")
            else:
                available_for_spawn.append(item)
                print(f"   ❌ Poseidon's Trident would SPAWN (obtained flag is False)")
        else:
            # Check other legendary items for comparison
            if item["name"] == "ragnarok_hammer" and items.ragnarok_hammer_obtained:
                continue
            elif item["name"] == "hermes_shoes" and items.hermes_shoes_obtained:
                continue
            else:
                available_for_spawn.append(item)
    
    # Step 5: Test actual spawn_random_item function
    print("\n4️⃣ Testing actual spawn_random_item:")
    
    # Temporarily set all other items as obtained to force Poseidon spawn attempt
    original_states = {}
    for attr in dir(items):
        if attr.endswith("_obtained") and attr != "poseidon_trident_obtained":
            original_states[attr] = getattr(items, attr)
            setattr(items, attr, True)
    
    # Try to spawn an item
    spawned = items.spawn_random_item()
    
    if spawned:
        print(f"   Spawned item: {spawned['name']}")
        if spawned['name'] == 'poseidon_trident':
            print(f"   ❌ ERROR: Poseidon's Trident spawned despite obtained flag!")
        else:
            print(f"   ✓ Different item spawned (Poseidon blocked)")
    else:
        print(f"   No item spawned (all items obtained or unavailable)")
    
    # Restore original states
    for attr, value in original_states.items():
        setattr(items, attr, value)
    
    # Step 6: Test direct flag manipulation
    print("\n5️⃣ Testing Direct Flag Manipulation:")
    print(f"   Setting items.poseidon_trident_obtained = True directly")
    items.poseidon_trident_obtained = True
    
    # Check if it persists
    print(f"   Verification: items.poseidon_trident_obtained = {items.poseidon_trident_obtained}")
    
    # Test spawn prevention again
    can_spawn = False
    for item in items.ITEM_TYPES:
        if item["name"] == "poseidon_trident" and not items.poseidon_trident_obtained:
            can_spawn = True
            break
    
    print(f"   Can Poseidon spawn now? {can_spawn}")
    
    # Step 7: Check for any reset functions
    print("\n6️⃣ Testing reset_items (stage transition):")
    initial_flag = items.poseidon_trident_obtained
    items.reset_items()
    after_reset_flag = items.poseidon_trident_obtained
    
    print(f"   Before reset: {initial_flag}")
    print(f"   After reset: {after_reset_flag}")
    
    if initial_flag and after_reset_flag:
        print(f"   ✓ Flag correctly preserved across reset")
    elif initial_flag and not after_reset_flag:
        print(f"   ❌ ERROR: Flag was incorrectly reset!")
    
    # Final summary
    print("\n" + "=" * 60)
    print("📊 Test Summary:")
    
    issues = []
    
    if not poseidon_in_items:
        issues.append("Poseidon's Trident not in ITEM_TYPES")
    
    if not items.poseidon_trident_obtained:
        issues.append("Flag not set after TAB selection")
    
    if initial_flag and not after_reset_flag:
        issues.append("Flag reset during stage transition")
    
    if issues:
        print("❌ Issues found:")
        for issue in issues:
            print(f"   - {issue}")
    else:
        print("✅ All tests passed! The fix should be working.")
        print("\nIf spawning still occurs, check:")
        print("1. Is the game using a different spawn function?")
        print("2. Is there a cache or delayed update issue?")
        print("3. Are there multiple Poseidon items with different names?")

if __name__ == "__main__":
    test_complete_poseidon_flow()