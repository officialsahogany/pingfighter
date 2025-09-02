#!/usr/bin/env python3
"""
Half-Dash System Patcher for PingFighter
========================================
This script patches pingfighter.py to add half-dash functionality
with minimal changes to the original code.

Usage: python apply_half_dash_patch.py

Author: Claude Code
Date: 2024-08-22
"""

import os
import sys
import shutil
from datetime import datetime

def create_backup(filename):
    """Create a backup of the original file"""
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_name = f"{filename}.backup_halfdash_{timestamp}"
    shutil.copy2(filename, backup_name)
    print(f"✅ Backup created: {backup_name}")
    return backup_name

def find_insertion_points(content_lines):
    """Find the line numbers where we need to insert code"""
    insertion_points = {}
    
    # Find import section (after other game_mechanics imports if they exist)
    for i, line in enumerate(content_lines):
        if "from game_mechanics" in line or "import game_mechanics" in line:
            insertion_points['import'] = i + 1
            break
        elif "import pygame" in line and 'import' not in insertion_points:
            # If no game_mechanics imports, add after pygame imports
            for j in range(i, min(i+20, len(content_lines))):
                if content_lines[j].strip() == "" or not content_lines[j].startswith("import"):
                    insertion_points['import'] = j
                    break
    
    # Find game initialization (after academy initialization)
    for i, line in enumerate(content_lines):
        if "academy.load_save_data()" in line or "academy = Academy()" in line:
            insertion_points['init'] = i + 1
            break
    
    # Find dash key handling (looking for the main dash activation code)
    for i, line in enumerate(content_lines):
        if "if down_pressed and can_use_rolling and rolling_charges > 0" in line:
            insertion_points['dash_check'] = i
            break
    
    # Find the dash execution code block
    for i, line in enumerate(content_lines):
        if "rolling_active = True" in line and "# 아래키 +" in content_lines[i-1]:
            insertion_points['dash_execute'] = i - 2  # Insert before the comment
            break
    
    # Find round reset function
    for i, line in enumerate(content_lines):
        if "def reset_round()" in line:
            # Find the end of variable declarations in reset_round
            for j in range(i+1, min(i+100, len(content_lines))):
                if "rolling_active = False" in content_lines[j]:
                    insertion_points['reset'] = j + 3
                    break
    
    # Find draw function where dash effects are drawn
    for i, line in enumerate(content_lines):
        if "if rolling_active:" in line and "draw" in content_lines[i+1].lower():
            insertion_points['draw'] = i + 5
            break
    
    return insertion_points

def apply_patch(filename):
    """Apply the half-dash patch to pingfighter.py"""
    
    # Read the original file
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
        content_lines = content.split('\n')
    
    print(f"📖 Read {len(content_lines)} lines from {filename}")
    
    # Find insertion points
    points = find_insertion_points(content_lines)
    print(f"🔍 Found {len(points)} insertion points: {list(points.keys())}")
    
    # Prepare patches
    patches = []
    
    # Import patch
    if 'import' in points:
        import_patch = """
# === 하프 대쉬 시스템 ===
try:
    from game_mechanics.half_dash_integration import (
        integrate_half_dash_with_game,
        check_and_activate_half_dash,
        apply_half_dash_timer_adjustment,
        draw_half_dash_effects,
        reset_half_dash_round
    )
    HALF_DASH_ENABLED = True
    print("💫 하프 대쉬 시스템 로드 완료")
except ImportError:
    HALF_DASH_ENABLED = False
    print("⚠️ 하프 대쉬 시스템을 찾을 수 없습니다")
"""
        patches.append((points['import'], import_patch))
    
    # Initialization patch
    if 'init' in points:
        init_patch = """
# 하프 대쉬 시스템 초기화
if HALF_DASH_ENABLED:
    half_dash_system = integrate_half_dash_with_game()
"""
        patches.append((points['init'], init_patch))
    
    # Dash check patch (insert before normal dash check)
    if 'dash_check' in points:
        dash_patch = """
            # === 하프 대쉬 체크 (게이지 부족시) ===
            if HALF_DASH_ENABLED and down_pressed and rolling_charges > 0 and not rolling_active:
                # 게이지 계산
                base_gauge_cost = 140
                next_consecutive_count = rolling_consecutive_count + 1
                consecutive_discount = 0.5 ** (next_consecutive_count - 1)
                discounted_cost = int(base_gauge_cost * consecutive_discount)
                if dashgear_obtained:
                    discounted_cost = int(discounted_cost * 0.8)
                battery_bonus = academy.get_skill_bonus("dash_battery_pack") if 'academy' in globals() else 0
                required_gauge = max(10, int(discounted_cost * (1 - battery_bonus)))
                
                # 게이지가 부족한 경우 하프 대쉬 체크
                if special_gauge < required_gauge:
                    game_state = {
                        'special_gauge': special_gauge,
                        'required_gauge': required_gauge,
                        'rolling_charges': rolling_charges,
                        'rolling_active': rolling_active,
                        'down_pressed': down_pressed,
                        'keys': keys
                    }
                    
                    half_dash_activated, half_dash_direction, half_dash_timer = check_and_activate_half_dash(game_state)
                    
                    if half_dash_activated:
                        # 하프 대쉬 발동
                        rolling_active = True
                        rolling_direction = half_dash_direction
                        rolling_timer = half_dash_timer
                        
                        # 하프 대쉬는 게이지와 토큰 소모 없음
                        # 대쉬 효과음
                        play_dash_sound()
                        
                        # 하프 대쉬 메시지 표시
                        message_text = "하프 대쉬!"
                        message_color = (150, 150, 255)
                        message_font = pygame.font.Font("NeoDGM.ttf", 32) if os.path.exists("NeoDGM.ttf") else pygame.font.Font(None, 32)
                        
                        # 일반 대쉬 코드 건너뛰기
                        # continue 대신 플래그 사용
                        half_dash_executed = True
            
            # 일반 대쉬 처리 (하프 대쉬가 실행되지 않은 경우만)
            if 'half_dash_executed' not in locals() or not half_dash_executed:
"""
        patches.append((points['dash_check'], dash_patch))
    
    # Reset patch
    if 'reset' in points:
        reset_patch = """
    # 하프 대쉬 라운드 리셋
    if HALF_DASH_ENABLED:
        reset_half_dash_round()
"""
        patches.append((points['reset'], reset_patch))
    
    # Draw patch
    if 'draw' in points:
        draw_patch = """
        # 하프 대쉬 효과 그리기
        if HALF_DASH_ENABLED:
            draw_half_dash_effects(screen, PLAYER, rolling_direction)
"""
        patches.append((points['draw'], draw_patch))
    
    # Apply patches (in reverse order to maintain line numbers)
    patches.sort(key=lambda x: x[0], reverse=True)
    
    for line_num, patch_content in patches:
        patch_lines = patch_content.split('\n')
        for i, patch_line in enumerate(patch_lines):
            content_lines.insert(line_num + i, patch_line)
        print(f"✅ Patch applied at line {line_num}")
    
    # Write the patched file
    patched_content = '\n'.join(content_lines)
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(patched_content)
    
    print(f"✅ Successfully patched {filename}")
    print("💫 하프 대쉬 시스템이 통합되었습니다!")
    print("")
    print("기능 설명:")
    print("- 게이지가 부족할 때 대쉬를 시도하면 자동으로 하프 대쉬 발동")
    print("- 하프 대쉬는 일반 대쉬의 50% 거리만 이동")
    print("- 게이지와 토큰을 소모하지 않음")
    print("- 3초 쿨다운 적용")

def main():
    """Main function"""
    target_file = "pingfighter.py"
    
    if not os.path.exists(target_file):
        print(f"❌ Error: {target_file} not found!")
        print("Please run this script in the same directory as pingfighter.py")
        sys.exit(1)
    
    print("=" * 60)
    print("하프 대쉬 시스템 패처")
    print("=" * 60)
    
    # Create backup
    backup_file = create_backup(target_file)
    
    try:
        # Apply patch
        apply_patch(target_file)
        
        print("")
        print("=" * 60)
        print("✅ 패치 완료!")
        print(f"백업 파일: {backup_file}")
        print("문제가 발생하면 백업 파일로 복원하세요.")
        print("=" * 60)
        
    except Exception as e:
        print(f"❌ Error applying patch: {e}")
        print(f"Restoring from backup: {backup_file}")
        shutil.copy2(backup_file, target_file)
        print("✅ Original file restored")
        sys.exit(1)

if __name__ == "__main__":
    main()