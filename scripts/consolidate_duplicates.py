#!/usr/bin/env python3
"""
Phase 13: Consolidate duplicate code into helper functions
"""

import re

def consolidate_duplicates():
    with open('../bosspong.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # Find insertion point (after constants)
    insert_line = 0
    for i, line in enumerate(lines):
        if '# === End Phase 12 Constants ===' in line:
            insert_line = i + 2
            break
    
    if not insert_line:
        print("Could not find insertion point!")
        return
    
    # Helper functions to add
    helper_functions = '''
# === Phase 13: Helper Functions ===

def play_sound_safe(sound):
    """Safely play a sound if it exists"""
    if sound:
        sound.play()

def random_direction():
    """Get random direction (-1 or 1)"""
    return random.choice([-1, 1])

def random_angle():
    """Get random angle in radians (0 to 2π)"""
    return random.uniform(0, 2 * math.pi)

def get_ball_speed():
    """Get current ball speed"""
    return math.hypot(ball_vel[0], ball_vel[1])

def normalize_velocity(vel_x, vel_y, target_speed):
    """Normalize velocity to target speed"""
    current_speed = math.hypot(vel_x, vel_y)
    if current_speed > 0:
        scale = target_speed / current_speed
        return vel_x * scale, vel_y * scale
    return vel_x, vel_y

def create_standard_impact(impact_type="normal"):
    """Create standard impact effect at ball position"""
    create_impact_effect(BALL.centerx, BALL.centery, ball_vel, impact_type)

def get_angle_components(angle):
    """Get cos and sin of angle"""
    return math.cos(angle), math.sin(angle)

def draw_white_circle(x, y, radius=5):
    """Draw a white circle (commonly used for particles)"""
    draw.circle((MAX_COLOR, MAX_COLOR, MAX_COLOR), (int(x), int(y)), radius)

def get_random_boss_x():
    """Get random x position within boss movement area"""
    return random.randint(BOSS.width // 2, WIDTH - BOSS.width // 2)

def check_ball_player_collision():
    """Check if ball collides with player"""
    return BALL.colliderect(PLAYER)

# === End Phase 13 Helper Functions ===

'''
    
    # Insert helper functions
    lines.insert(insert_line, helper_functions)
    
    # Now replace common patterns
    content = ''.join(lines)
    
    replacements = [
        # Sound plays
        (r'SOUND_SERVE\.play\(\)', 'play_sound_safe(SOUND_SERVE)'),
        (r'SOUND_WALL\.play\(\)', 'play_sound_safe(SOUND_WALL)'),
        (r'SOUND_BUTTON_HOVER\.play\(\)', 'play_sound_safe(SOUND_BUTTON_HOVER)'),
        (r'SOUND_ACTIVE_ITEM\.play\(\)', 'play_sound_safe(SOUND_ACTIVE_ITEM)'),
        (r'SOUND_BUTTON_CLICK\.play\(\)', 'play_sound_safe(SOUND_BUTTON_CLICK)'),
        
        # Random patterns
        (r'random\.choice\(\[-1, 1\]\)', 'random_direction()'),
        (r'random\.uniform\(0, 2 \* math\.pi\)', 'random_angle()'),
        (r'math\.hypot\(ball_vel\[0\], ball_vel\[1\]\)', 'get_ball_speed()'),
        (r'random\.randint\(BOSS\.width // 2, WIDTH - BOSS\.width // 2\)', 'get_random_boss_x()'),
        
        # Collision checks  
        (r'BALL\.colliderect\(PLAYER\)(?!\)\.)', 'check_ball_player_collision()'),
        
        # Math patterns (careful with these)
        (r'math\.cos\(angle\), math\.sin\(angle\)', 'get_angle_components(angle)'),
    ]
    
    replace_count = 0
    for pattern, replacement in replacements:
        matches = re.findall(pattern, content)
        if matches:
            content = re.sub(pattern, replacement, content)
            replace_count += len(matches)
            print(f"Replaced {len(matches)} occurrences of {pattern[:30]}...")
    
    # Write back
    with open('../bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"\n✅ Added {len(helper_functions.split('\\n'))-2} lines of helper functions")
    print(f"✅ Replaced {replace_count} duplicate patterns")
    
    # Estimate savings
    estimated_savings = replace_count * 0.5  # Each replacement saves about half a line on average
    print(f"📊 Estimated line reduction: ~{int(estimated_savings)} lines")
    
    return replace_count

if __name__ == "__main__":
    print("=== Phase 13: Consolidating Duplicate Code ===\n")
    total_replacements = consolidate_duplicates()
    print(f"\n✅ Phase 13 Complete!")
    print(f"Total replacements: {total_replacements}")
