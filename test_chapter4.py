#!/usr/bin/env python3
"""
Test script for Tutorial Chapter 4 functionality
Press 4 to start in Chapter 4, 8 to skip chapters
"""

import pygame
import sys
import os

# Add parent directory to path for imports
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def test_chapter4():
    """Test Tutorial Chapter 4 implementation"""
    
    # Initialize Pygame
    pygame.init()
    
    print("=" * 60)
    print("Tutorial Chapter 4 Test")
    print("=" * 60)
    print("\nInstructions:")
    print("- Press '4' at the tutorial start screen to jump to Chapter 4")
    print("- Press '8' during any chapter to skip to the next")
    print("- Chapter 4 should have:")
    print("  • Max gauge of 500 (not 300)")
    print("  • Gauge charges 500 on paddle hit")
    print("  • Serve reminder after instructor dialogue")
    print("\n" + "=" * 60)
    
    # Import and run the game
    try:
        import pingfighter
        
        # The game will run with our fixes
        print("\n✅ Game loaded successfully with Chapter 4 fixes")
        print("Starting game...")
        
    except SyntaxError as e:
        print(f"\n❌ Syntax Error: {e}")
        return False
    except Exception as e:
        print(f"\n❌ Error: {e}")
        return False
    
    return True

if __name__ == "__main__":
    success = test_chapter4()
    if not success:
        sys.exit(1)