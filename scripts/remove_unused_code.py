#!/usr/bin/env python3
"""
Phase 1-3: 미사용 코드 제거 스크립트
"""

import re
import os

def remove_unused_variables(content):
    """미사용 변수 제거"""
    lines_before = content.count('\n')
    
    # 미사용 변수 패턴들 (VS Code 진단에서 확인된 것들)
    unused_vars = [
        'multiplier',
        'current_speed', 
        'rolling_stun_timer',
        'rolling_dash_available_timer',
        'power_smashing_parabola_active',
        'power_smashing_start_time',
        'power_smashing_arc_strength',
        'particle_x',
        'particle_y',
        'rainbow_color',
        'original_x',
        'original_y',
        'ball_impact_boost',
        'fireball_last_cast',
        'fireball_cooldown',
        'mouse_controls',
        'space_pressed',
        'old_charges',
        'current_time',
        'electric_intensity',
        'layer_alpha',
        'alpha',
        'current_charged',
        'flame_alpha',
        'draw_rect_with_shake',
        'draw_circle_with_shake',
        'skill_gauge_ratio',
        'stripe_width',
        'wand_height',
        'font_subtitle',
        'glow_intensity',
        'last_selected',
        'glitch_timer',
        'glitch_active',
        'card_hover_offset',
        'selected_card_width',
        'selected_card_height',
        'fan_radius',
        'fan_angle_range',
        'scroll_offset',
        'sensor_enabled',
        'leaf_green',
        'bar_alpha',
        'dark_frame',
        'mega_smashing_active',
        'mega_smashing_start_time',
        'is_player',
        'life',
        'color_with_alpha',
        'wall_collision_bonus',
        'perfect_shot',
        'quantum_explosion_time',
        'momentum_uncertainty',
        'vx', 'vy',
        'special_gauge_max',
        'border_flash_active',
        'stage2_border_flash_timer',
        'last_wall_collision_time',
        'power_smashing_direction',
        'wall_hit',
        'whip_timer',
        'boss_special_waiting',
        'boss_special_timer',
        'enhanced_deceleration',
        'ball_direction_y',
        'wall_momentum_active',
        'dash_max',
        'rolling_consecutive_count',
        'mega_smashing_boss_defense_count',
        'drive_activated',
        'mega_smashing_original_speed',
        'final_speed',
        'speedboots_obtained',
        'speedgear_obtained', 
        'battery_obtained',
        'revival_obtained',
        'revival_used',
        'chargebag_obtained',
        'bulkup_obtained',
        'gravitybelt_obtained',
        'danger_sensor_obtained',
        'sensor_obtained',
        'gravity_speed_synergy',
        'font_small',
        'content_height',
        'left_stats_width',
        'tab_count',
        'rolling_obtained'
    ]
    
    changes = 0
    
    # 각 미사용 변수에 대해 제거
    for var in unused_vars:
        # 단순 할당문 제거 (줄 전체)
        pattern = rf'^\s*{re.escape(var)}\s*=\s*[^\n]+\n'
        matches = list(re.finditer(pattern, content, re.MULTILINE))
        if matches:
            for match in reversed(matches):
                # 주석이 포함된 줄은 건드리지 않음
                if '#' not in match.group():
                    content = content[:match.start()] + content[match.end():]
                    changes += 1
    
    lines_after = content.count('\n')
    return content, changes, lines_before - lines_after

def remove_empty_functions(content):
    """빈 함수 제거"""
    lines_before = content.count('\n')
    changes = 0
    
    # 빈 함수 패턴
    patterns = [
        # pass만 있는 함수
        r'def \w+\([^)]*\):\s*\n\s+pass\s*\n',
        # return만 있는 함수
        r'def \w+\([^)]*\):\s*\n\s+return\s*\n',
        # return None만 있는 함수
        r'def \w+\([^)]*\):\s*\n\s+return None\s*\n',
    ]
    
    for pattern in patterns:
        matches = list(re.finditer(pattern, content))
        for match in reversed(matches):
            content = content[:match.start()] + content[match.end():]
            changes += 1
    
    lines_after = content.count('\n')
    return content, changes, lines_before - lines_after

def remove_excessive_blank_lines(content):
    """과도한 빈 줄 제거 (3줄 이상 -> 2줄)"""
    lines_before = content.count('\n')
    
    # 3줄 이상의 빈 줄을 2줄로
    content = re.sub(r'\n\n\n+', '\n\n', content)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase1_3.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    total_changes = 0
    total_lines_saved = 0
    
    print("\n🔧 Phase 1-3: 미사용 코드 제거...")
    
    # 1. 미사용 변수 제거
    print("\n1️⃣ 미사용 변수 제거...")
    content, changes, lines_saved = remove_unused_variables(content)
    total_changes += changes
    total_lines_saved += lines_saved
    print(f"   ✅ {changes}개 변수 제거, {lines_saved}줄 감소")
    
    # 2. 빈 함수 제거
    print("\n2️⃣ 빈 함수 제거...")
    content, changes, lines_saved = remove_empty_functions(content)
    total_changes += changes
    total_lines_saved += lines_saved
    print(f"   ✅ {changes}개 함수 제거, {lines_saved}줄 감소")
    
    # 3. 과도한 빈 줄 제거
    print("\n3️⃣ 과도한 빈 줄 제거...")
    content, lines_saved = remove_excessive_blank_lines(content)
    total_lines_saved += lines_saved
    print(f"   ✅ {lines_saved}줄 감소")
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 1-3 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   감소: {original_lines - final_lines:,}줄 ({(original_lines - final_lines) / original_lines * 100:.1f}%)")
    print(f"   변경: {total_changes}개 항목")
    print("="*50)

if __name__ == "__main__":
    main()