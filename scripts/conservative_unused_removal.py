#!/usr/bin/env python3
"""
Phase 1-3: 보수적인 미사용 코드 제거 스크립트
실제로 사용되지 않는 변수만 안전하게 제거
"""

import re
import os

def remove_truly_unused_variables(content):
    """진짜 미사용 변수만 제거 (사용 여부 검증)"""
    lines_before = content.count('\n')
    
    # 정말 사용되지 않는 변수들만 (철저히 검증됨)
    truly_unused = [
        'rolling_stun_timer',  # 검색 결과 없음
        'rolling_dash_available_timer',  # 검색 결과 없음
        'power_smashing_parabola_active',  # 검색 결과 없음
        'power_smashing_start_time',  # 사용 안됨
        'power_smashing_arc_strength',  # 사용 안됨
        'ball_impact_boost',  # 사용 안됨
        'fireball_last_cast',  # 사용 안됨
        'fireball_cooldown',  # 사용 안됨
        'mouse_controls',  # 사용 안됨
        'space_pressed',  # 사용 안됨
        'old_charges',  # 사용 안됨
        'electric_intensity',  # 사용 안됨
        'draw_rect_with_shake',  # 사용 안됨
        'draw_circle_with_shake',  # 사용 안됨
        'stripe_width',  # 사용 안됨
        'wand_height',  # 사용 안됨
        'last_selected',  # 사용 안됨
        'glitch_timer',  # 사용 안됨
        'glitch_active',  # 사용 안됨
        'card_hover_offset',  # 사용 안됨
        'selected_card_width',  # 사용 안됨
        'selected_card_height',  # 사용 안됨
        'fan_radius',  # 사용 안됨
        'fan_angle_range',  # 사용 안됨
        'scroll_offset',  # 사용 안됨
        'sensor_enabled',  # 사용 안됨
        'leaf_green',  # 사용 안됨
        'bar_alpha',  # 사용 안됨
        'dark_frame',  # 사용 안됨
        'mega_smashing_active',  # 사용 안됨
        'mega_smashing_start_time',  # 사용 안됨
        'is_player',  # 사용 안됨
        'life',  # 사용 안됨
        'color_with_alpha',  # 사용 안됨
        'wall_collision_bonus',  # 사용 안됨
        'perfect_shot',  # 사용 안됨
        'quantum_explosion_time',  # 사용 안됨
        'momentum_uncertainty',  # 사용 안됨
        'special_gauge_max',  # 사용 안됨
        'border_flash_active',  # 사용 안됨
        'stage2_border_flash_timer',  # 사용 안됨
        'last_wall_collision_time',  # 사용 안됨
        'power_smashing_direction',  # 사용 안됨
        'wall_hit',  # 사용 안됨
        'whip_timer',  # 사용 안됨
        'boss_special_waiting',  # 사용 안됨
        'boss_special_timer',  # 사용 안됨
        'enhanced_deceleration',  # 사용 안됨
        'ball_direction_y',  # 사용 안됨
        'wall_momentum_active',  # 사용 안됨
        'dash_max',  # 사용 안됨
        'rolling_consecutive_count',  # 사용 안됨
        'mega_smashing_boss_defense_count',  # 사용 안됨
        'drive_activated',  # 사용 안됨
        'mega_smashing_original_speed',  # 사용 안됨
        'final_speed',  # 사용 안됨
        'speedboots_obtained',  # 사용 안됨
        'speedgear_obtained',  # 사용 안됨
        'battery_obtained',  # 사용 안됨
        'revival_obtained',  # 사용 안됨
        'revival_used',  # 사용 안됨
        'chargebag_obtained',  # 사용 안됨
        'bulkup_obtained',  # 사용 안됨
        'gravitybelt_obtained',  # 사용 안됨
        'danger_sensor_obtained',  # 사용 안됨
        'sensor_obtained',  # 사용 안됨
        'gravity_speed_synergy',  # 사용 안됨
        'content_height',  # 사용 안됨
        'left_stats_width',  # 사용 안됨
        'tab_count',  # 사용 안됨
        'rolling_obtained'  # 사용 안됨
    ]
    
    changes = 0
    
    # 각 미사용 변수에 대해 제거 (단순 할당만)
    for var in truly_unused:
        # 단순 할당문 제거 (전체 줄)
        pattern = rf'^\s*{re.escape(var)}\s*=\s*[^#\n]+(?:#[^\n]*)?\n'
        matches = list(re.finditer(pattern, content, re.MULTILINE))
        if matches:
            for match in reversed(matches):
                # 실제 사용 체크 (할당 외에 참조가 있는지)
                var_usage_pattern = rf'\b{re.escape(var)}\b'
                all_matches = re.findall(var_usage_pattern, content)
                assignment_matches = re.findall(rf'{re.escape(var)}\s*=', content)
                
                # 할당만 있고 사용은 없는 경우만 제거
                if len(all_matches) == len(assignment_matches):
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
    os.system('cp bosspong.py bosspong_backup_conservative_phase1_3.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    total_changes = 0
    total_lines_saved = 0
    
    print("\n🔧 Phase 1-3: 보수적인 미사용 코드 제거...")
    
    # 1. 진짜 미사용 변수만 제거
    print("\n1️⃣ 검증된 미사용 변수 제거...")
    content, changes, lines_saved = remove_truly_unused_variables(content)
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
    print("📊 Phase 1-3 (보수적) 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   감소: {original_lines - final_lines:,}줄 ({(original_lines - final_lines) / original_lines * 100:.1f}%)")
    print(f"   변경: {total_changes}개 항목")
    print("="*50)

if __name__ == "__main__":
    main()