#!/usr/bin/env python3
"""Test script to verify PoseidonTrident update method fix"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from legendary_items import PoseidonTrident, LegendaryItemManager, get_legendary_manager

def test_update_method():
    """Test that PoseidonTrident.update() accepts ui_mode parameter"""
    print("🔱 Testing PoseidonTrident update method fix...")
    
    # Create instance
    trident = PoseidonTrident()
    trident.active = True
    
    # Test with both signatures
    try:
        # Test with just dt
        trident.update(0.016)
        print("✅ update(dt) works")
    except Exception as e:
        print(f"❌ update(dt) failed: {e}")
        return False
    
    try:
        # Test with dt and ui_mode
        trident.update(0.016, False)
        print("✅ update(dt, ui_mode=False) works")
    except Exception as e:
        print(f"❌ update(dt, ui_mode=False) failed: {e}")
        return False
    
    try:
        # Test with dt and ui_mode=True
        trident.update(0.016, True)
        print("✅ update(dt, ui_mode=True) works")
    except Exception as e:
        print(f"❌ update(dt, ui_mode=True) failed: {e}")
        return False
    
    # Test vortex animation
    print("\n🌊 Testing vortex animation...")
    trident.trigger_dash_wave(300, 400)
    
    # Simulate several update cycles
    for i in range(5):
        trident.update(0.016, False)
        print(f"  Frame {i+1}: vortex_timer={trident.vortex_timer:.2f}, "
              f"left_height={trident.vortex_left_height:.0f}, "
              f"right_height={trident.vortex_right_height:.0f}, "
              f"particles={len(trident.vortex_particles)}")
    
    # Test LegendaryItemManager
    print("\n📦 Testing LegendaryItemManager...")
    manager = get_legendary_manager()
    manager.activate_item("poseidon_trident", {})
    
    try:
        manager.update(0.016, False)
        print("✅ LegendaryItemManager.update() works")
    except Exception as e:
        print(f"❌ LegendaryItemManager.update() failed: {e}")
        return False
    
    print("\n✨ All tests passed!")
    return True

if __name__ == "__main__":
    success = test_update_method()
    sys.exit(0 if success else 1)