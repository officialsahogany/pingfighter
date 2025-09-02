#!/usr/bin/env python3
"""
Test Stage 4 by starting the game at Stage 4
"""

import sys
import os

# Add the game directory to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def patch_stage():
    """Patch the game to start at Stage 4"""
    import pingfighter
    
    # Set stage to 4
    pingfighter.current_stage = 4
    pingfighter.CURRENT_BG = pingfighter.STAGE4_BG
    
    # Set appropriate boss for stage 4
    if hasattr(pingfighter, 'boss_settings'):
        pingfighter.boss_settings = pingfighter.STAGE4_BOSS_SETTINGS
    
    print("✅ Game patched to start at Stage 4")
    print("🏛️ Shaolin Temple background should be visible")
    print("Press ESC to exit")
    
    # Start the game with stage 4
    pingfighter.main(4)

if __name__ == "__main__":
    patch_stage()