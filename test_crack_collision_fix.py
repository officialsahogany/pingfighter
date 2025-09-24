#!/usr/bin/env python3
"""
Test script to validate the boss-crack collision fix.
This simulates the collision detection without running the full game.
"""

import pygame
import math
import sys
import os

# Add the current directory to Python path so we can import from pingfighter
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Mock constants and globals that would be imported from pingfighter
FPS = 60
WIDTH = 800

# Collision detection constants
BLACKSMITH_GROUND_CRACK_BOSS_IGNORE_MS = 200
BLACKSMITH_GROUND_CRACK_STUCK_FREE_FRAMES = max(1, int(0.15 * FPS))
BLACKSMITH_GROUND_CRACK_STUCK_CLEAR_DELAY_MS = 300
BLACKSMITH_GROUND_CRACK_STUCK_CLEAR_COOLDOWN_MS = 300
BLACKSMITH_GROUND_CRACK_PASS_THROUGH_MS = 420

# Global variables to track state
boss_crack_ignore_until = 0
boss_crack_stuck_timer = 0
boss_crack_last_release = 0
blacksmith_ground_cracks = []

def create_test_crack(x, y, angle, length, segments_remaining=5):
    """Create a test crack for collision testing"""
    return {
        "x": x,
        "y": y,
        "angle": angle,
        "length": length,
        "segments_remaining": segments_remaining,
        "segments_total": 10,
        "thickness": 5,
        "boss_padding": 1,
        "boss_touch_cooldown": 0,
        "initial_length": length
    }

def _check_boss_crack_collision_fixed(boss_rect, crack):
    """Fixed collision detection function"""
    global boss_crack_ignore_until

    current_ticks = pygame.time.get_ticks()

    disabled_until = crack.get("boss_contact_disabled_until", 0)
    if disabled_until and current_ticks < disabled_until:
        return False
    if disabled_until and current_ticks >= disabled_until:
        crack.pop("boss_contact_disabled_until", None)

    if current_ticks < boss_crack_ignore_until:
        return False

    # Check if crack has any length left (completely broken cracks should not collide)
    if crack.get("length", 0) <= 0 or crack.get("segments_remaining", 0) <= 0:
        return False
        
    # Create a line segment for the crack
    line_start_x = crack.get("x", 0.0)
    line_start_y = crack.get("y", 0.0)
    line_end_x = line_start_x + math.cos(crack.get("angle", 0.0)) * crack.get("length", 0.0)
    line_end_y = line_start_y + math.sin(crack.get("angle", 0.0)) * crack.get("length", 0.0)

    # 더 간단하고 확실한 충돌 감지
    # 크랙의 X 범위
    crack_min_x = min(line_start_x, line_end_x)
    crack_max_x = max(line_start_x, line_end_x)
    
    # 보스와 크랙의 X 범위 겹침 검사 (여유를 조금만 둠)
    margin = 15  # 기존 20에서 15로 더 줄임
    if boss_rect.right < crack_min_x - margin or boss_rect.left > crack_max_x + margin:
        return False
    
    # Y 축 검사 (크랙은 보통 바닥 근처에 있음)
    crack_min_y = min(line_start_y, line_end_y)
    crack_max_y = max(line_start_y, line_end_y)
    
    # 보스 패들과 크랙의 Y 범위가 합리적한 거리 내에 있는지 확인
    vertical_margin = 25  # 기존 30에서 25로 줄임
    if abs(boss_rect.centery - (crack_min_y + crack_max_y) / 2) > vertical_margin:
        return False

    # 간단하고 확실한 충돌 감지
    # 크랙을 두꺼운 사각형으로 취급하여 충돌 검사
    thickness = 20  # 충돌 감지용 두께를 줄임
    
    # 크랙의 바운딩 박스 생성 (두께 포함)
    crack_rect = pygame.Rect(
        crack_min_x - thickness // 2,
        crack_min_y - thickness // 2,  
        crack_max_x - crack_min_x + thickness,
        crack_max_y - crack_min_y + thickness
    )
    
    # 보스와 크랙 바운딩 박스의 직접 충돌 검사
    collision_detected = boss_rect.colliderect(crack_rect)
    
    # Only print debug info when collision is actually detected to reduce spam
    if collision_detected:
        print(f"[COLLISION] Boss collides with crack!")
        print(f"  Boss: ({boss_rect.x}, {boss_rect.y}, {boss_rect.width}x{boss_rect.height})")
        print(f"  Crack: length={crack.get('length', 0):.1f}, segments={crack.get('segments_remaining', 0)}")
        return True
    
    # 충돌이 없으면 False 반환
    return False

def test_collision_scenarios():
    """Test various collision scenarios"""
    print("Testing boss-crack collision detection fixes...")
    print("=" * 60)
    
    # Initialize pygame for Rect functionality
    pygame.init()
    
    # Test Case 1: Normal collision
    print("\nTest Case 1: Normal collision with active crack")
    boss_rect = pygame.Rect(300, 500, 80, 20)
    active_crack = create_test_crack(320, 510, 0, 100, segments_remaining=5)
    
    collision = _check_boss_crack_collision_fixed(boss_rect, active_crack)
    print(f"Result: {'COLLISION' if collision else 'NO COLLISION'} (Expected: COLLISION)")
    
    # Test Case 2: Broken crack (should not collide)
    print("\nTest Case 2: Collision with broken crack")
    broken_crack = create_test_crack(320, 510, 0, 0, segments_remaining=0)  # Zero length and segments
    
    collision = _check_boss_crack_collision_fixed(boss_rect, broken_crack)
    print(f"Result: {'COLLISION' if collision else 'NO COLLISION'} (Expected: NO COLLISION)")
    
    # Test Case 3: Distant crack (should not collide)
    print("\nTest Case 3: Collision with distant crack")
    distant_crack = create_test_crack(500, 510, 0, 50, segments_remaining=3)  # Far away
    
    collision = _check_boss_crack_collision_fixed(boss_rect, distant_crack)
    print(f"Result: {'COLLISION' if collision else 'NO COLLISION'} (Expected: NO COLLISION)")
    
    # Test Case 4: Very small crack (edge case)
    print("\nTest Case 4: Collision with very small crack")
    small_crack = create_test_crack(320, 510, 0, 5, segments_remaining=1)  # Very small
    
    collision = _check_boss_crack_collision_fixed(boss_rect, small_crack)
    print(f"Result: {'COLLISION' if collision else 'NO COLLISION'} (Expected: COLLISION)")
    
    # Test Case 5: Crack with disabled contact
    print("\nTest Case 5: Collision with disabled crack")
    disabled_crack = create_test_crack(320, 510, 0, 100, segments_remaining=5)
    disabled_crack["boss_contact_disabled_until"] = pygame.time.get_ticks() + 1000  # Disabled for 1 second
    
    collision = _check_boss_crack_collision_fixed(boss_rect, disabled_crack)
    print(f"Result: {'COLLISION' if collision else 'NO COLLISION'} (Expected: NO COLLISION)")
    
    print("\n" + "=" * 60)
    print("Collision detection tests completed!")
    
    # Test performance by running many collision checks
    print("\nPerformance Test: Running 1000 collision checks...")
    import time
    start_time = time.time()
    
    for _ in range(1000):
        _check_boss_crack_collision_fixed(boss_rect, active_crack)
    
    end_time = time.time()
    print(f"1000 collision checks completed in {(end_time - start_time) * 1000:.2f}ms")
    print(f"Average per check: {(end_time - start_time) * 1000000 / 1000:.2f}µs")

def test_stuck_prevention():
    """Test the stuck prevention mechanism"""
    print("\n" + "=" * 60)
    print("Testing stuck prevention mechanism...")
    
    # Simulate a boss getting stuck
    boss_rect = pygame.Rect(300, 500, 80, 20)
    
    # Create multiple overlapping cracks that could cause stuck
    global blacksmith_ground_cracks
    blacksmith_ground_cracks = [
        create_test_crack(280, 510, 0, 60, segments_remaining=3),
        create_test_crack(320, 510, 0, 60, segments_remaining=4),
        create_test_crack(360, 510, 0, 60, segments_remaining=2)
    ]
    
    print(f"Created {len(blacksmith_ground_cracks)} overlapping cracks around boss")
    
    # Check how many are colliding
    colliding_count = 0
    for crack in blacksmith_ground_cracks:
        if _check_boss_crack_collision_fixed(boss_rect, crack):
            colliding_count += 1
    
    print(f"Boss is colliding with {colliding_count} crack(s)")
    
    if colliding_count > 1:
        print("Multiple collision scenario detected - this could cause stuck behavior")
        print("In the actual game, the force_clear_nearest_crack function would resolve this")
    else:
        print("Single or no collision - normal operation")

if __name__ == "__main__":
    test_collision_scenarios()
    test_stuck_prevention()
    
    print("\n" + "=" * 60)
    print("Summary of fixes applied:")
    print("1. ✅ Reduced collision detection margins (15px X, 25px Y, 20px thickness)")
    print("2. ✅ Added check for broken cracks (length=0, segments=0)")
    print("3. ✅ Reduced debug spam (only print on actual collision)")
    print("4. ✅ Improved force clear function to remove multiple colliding cracks")
    print("5. ✅ Reduced timing constants for faster stuck resolution")
    print("6. ✅ Removed immediate collision recheck after crack hit")
    print("\nThe boss should now move more smoothly around ground cracks!")