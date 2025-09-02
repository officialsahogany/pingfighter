#!/usr/bin/env python3
"""
Test script to verify Stage 4 integration in the main game
Starts the game directly at Stage 4
"""

import pygame
import sys

# Force stage 4
import builtins
builtins.FORCE_STAGE = 4

# Now import the main game
import pingfighter

if __name__ == "__main__":
    print("Testing Stage 4 Shaolin Temple integration...")
    print("Press ESC to exit")
    print("Stage 4 should show the Shaolin Temple background with:")
    print("- 5-level pagoda")
    print("- Hanging lanterns")
    print("- Incense smoke")
    print("- Training dummies")
    print("- Bamboo trees")
    print("- Moon and stars")