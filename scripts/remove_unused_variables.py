#!/usr/bin/env python3
"""
Phase 3-1: 사용하지 않는 변수 제거
안전하게 제거할 수 있는 변수들만 제거
"""

import re
import os

def remove_unused_variables(content):
    """사용하지 않는 변수 제거"""
    lines_before = content.count('\n')
    
    # 안전하게 제거할 수 있는 변수들
    safe_to_remove = [
        'event_manager',
        'mega_smashing_trails',
        'ai_learning_active',
        'laser_target_angle',
        'hongryeon_gauge',
        'hongryeon_gauge_max',
        'tear_shower_timer',
        'sensor_auto_dash_cooldown',
        'sensor_last_auto_dash_time',
        'boss_fake_duration',
        'last_hit_time',
        'long_boost_animation_timer',
        'long_boost_last_width',
        'long_boost_scaled_img',
        'star_particles',
        'star_particle_timer',
        'star_particle_spawn_rate',
        'momentum_preservation',
        'aipill_turn_boost',
        'pachinko_slots',
        'bridge',
        'quantum_wave_function',
        'quantum_entanglement_pairs',
        'quantum_interference_pattern',
        'active_item_icon_size',
        'tear_shower_active',
        'danger_sensor_auto_dash_cooldown',
        'danger_sensor_last_auto_dash_time'
    ]
    
    lines = content.split('\n')
    new_lines = []
    removed_count = 0
    
    for line in lines:
        should_remove = False
        
        # 변수 정의 라인 확인
        for var in safe_to_remove:
            # 단순 할당 패턴
            pattern = r'^' + re.escape(var) + r'\s*=\s*'
            if re.match(pattern, line):
                should_remove = True
                removed_count += 1
                break
        
        if not should_remove:
            new_lines.append(line)
    
    content = '\n'.join(new_lines)
    lines_after = content.count('\n')
    
    return content, lines_before - lines_after, removed_count

def remove_unused_global_declarations(content):
    """사용하지 않는 global 선언 제거"""
    lines_before = content.count('\n')
    
    # 제거할 global 선언들 (함수별로)
    unused_globals = {
        'go_to_next_round': ['special_gauge_max'],
        'activate_long_boost': ['long_boost_scale'],
        'throw_grenade': ['BOSS'],
        'throw_flare': ['BOSS'],
        'calculate_trajectory': ['PLAYER', 'BOSS'],
        'throw_molotov': ['BOSS'],
        'handle_player': ['ball_angle', 'power_smashing_direction', 'long_boost_animating']
    }
    
    lines = content.split('\n')
    new_lines = []
    in_function = None
    removed_count = 0
    
    for i, line in enumerate(lines):
        # 함수 시작 감지
        func_match = re.match(r'^def\s+(\w+)\s*\(', line)
        if func_match:
            in_function = func_match.group(1)
        
        # 함수 끝 감지
        elif in_function and line and line[0] not in ' \t':
            in_function = None
        
        # global 선언 처리
        if in_function and in_function in unused_globals and 'global ' in line:
            # 사용하지 않는 global 제거
            globals_to_remove = unused_globals[in_function]
            original_line = line
            
            for var in globals_to_remove:
                # global var 제거
                line = re.sub(r'\bglobal\s+' + re.escape(var) + r'\s*,?\s*', '', line)
                line = re.sub(r',\s*' + re.escape(var) + r'\b', '', line)
                line = re.sub(r'\b' + re.escape(var) + r'\s*,\s*', '', line)
            
            # global 키워드만 남은 경우 전체 라인 제거
            if line.strip() == 'global' or line.strip() == 'global,':
                removed_count += 1
                continue
            
            # 변경이 있었으면 카운트
            if line != original_line:
                removed_count += 1
        
        new_lines.append(line)
    
    content = '\n'.join(new_lines)
    lines_after = content.count('\n')
    
    return content, lines_before - lines_after, removed_count

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase3_1.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    total_lines_saved = 0
    
    print("\n🔧 Phase 3-1: 사용하지 않는 변수 제거...")
    
    # 1. 사용하지 않는 변수 제거
    print("\n1️⃣ 사용하지 않는 변수 제거...")
    content, lines_saved, removed_vars = remove_unused_variables(content)
    total_lines_saved += lines_saved
    print(f"   ✅ {removed_vars}개 변수 제거, {lines_saved}줄 감소")
    
    # 2. 사용하지 않는 global 선언 제거
    print("\n2️⃣ 사용하지 않는 global 선언 제거...")
    content, lines_saved, removed_globals = remove_unused_global_declarations(content)
    total_lines_saved += lines_saved
    print(f"   ✅ {removed_globals}개 global 선언 수정, {lines_saved}줄 감소")
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 3-1 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   감소: {total_lines_saved:,}줄")
    print("="*50)

if __name__ == "__main__":
    main()