#!/usr/bin/env python3
"""
Phase 5-1: draw_objects 함수를 실제로 여러 함수로 분할
가장 큰 섹션들을 독립된 함수로 추출
"""

import re
import os

def extract_player_drawing(content):
    """플레이어 그리기 섹션을 별도 함수로 추출"""
    lines = content.split('\n')
    
    # draw_objects 함수 찾기
    start_idx = None
    for i, line in enumerate(lines):
        if 'def draw_objects():' in line:
            start_idx = i
            break
    
    if not start_idx:
        return content, 0
    
    # 플레이어 이미지 섹션 찾기
    player_section_start = None
    player_section_end = None
    
    for i in range(start_idx, len(lines)):
        if '=== 플레이어 이미지 (새로운 보스 모드 고려) ===' in lines[i]:
            player_section_start = i
        elif player_section_start and '===' in lines[i] and i > player_section_start:
            player_section_end = i
            break
    
    if not player_section_start or not player_section_end:
        return content, 0
    
    # 섹션 추출
    player_lines = lines[player_section_start+1:player_section_end]
    
    # 새 함수 생성
    new_function = ['def draw_player():']
    new_function.append('    """플레이어 이미지 그리기"""')
    
    # 필요한 global 변수들 추출
    globals_needed = set()
    for line in player_lines:
        # global 변수 패턴 찾기
        if 'current_stage' in line: globals_needed.add('current_stage')
        if 'PLAYER' in line: globals_needed.add('PLAYER')
        if 'BOSS' in line: globals_needed.add('BOSS')
        if 'boss_hit' in line: globals_needed.add('boss_hit_animation_timer')
        if 'player_hit' in line: globals_needed.add('player_hit_animation_timer')
        if 'time_slow' in line: globals_needed.add('time_slow_active')
    
    if globals_needed:
        new_function.append('    global ' + ', '.join(sorted(globals_needed)))
    
    # 코드 추가 (들여쓰기 조정 안함 - 이미 적절함)
    for line in player_lines:
        if line.strip():  # 빈 줄이 아니면
            new_function.append(line)
        else:
            new_function.append('')
    
    # draw_objects에서 섹션을 함수 호출로 대체
    lines[player_section_start:player_section_end] = ['    # === 플레이어 그리기 ===', '    draw_player()']
    
    # 새 함수를 draw_objects 앞에 추가
    insert_pos = start_idx
    lines[insert_pos:insert_pos] = new_function + ['', '']
    
    return '\n'.join(lines), len(player_lines) - 2

def extract_ball_drawing(content):
    """공 그리기 섹션을 별도 함수로 추출"""
    lines = content.split('\n')
    
    # draw_objects 함수 찾기
    start_idx = None
    for i, line in enumerate(lines):
        if 'def draw_objects():' in line:
            start_idx = i
            break
    
    if not start_idx:
        return content, 0
    
    # 공 섹션 찾기
    ball_section_start = None
    ball_section_end = None
    
    for i in range(start_idx, len(lines)):
        if '=== 공 (화면 흔들림 오프셋 적용) ===' in lines[i]:
            ball_section_start = i
        elif ball_section_start and '===' in lines[i] and i > ball_section_start:
            ball_section_end = i
            break
    
    if not ball_section_start or not ball_section_end:
        return content, 0
    
    # 섹션 추출
    ball_lines = lines[ball_section_start+1:ball_section_end]
    
    # 새 함수 생성
    new_function = ['def draw_ball():']
    new_function.append('    """공 그리기 (화면 흔들림 포함)"""')
    
    # 필요한 global 변수들
    globals_needed = ['current_stage', 'BALL', 'ball_fire_mode', 'fire_ball_size',
                     'screen_shake_offset_x', 'screen_shake_offset_y', 'inverted_controls']
    
    new_function.append('    global ' + ', '.join(globals_needed[:4]))
    new_function.append('    global ' + ', '.join(globals_needed[4:]))
    
    # 코드 추가
    for line in ball_lines:
        if line.strip():
            new_function.append(line)
        else:
            new_function.append('')
    
    # draw_objects에서 섹션을 함수 호출로 대체
    lines[ball_section_start:ball_section_end] = ['    # === 공 그리기 ===', '    draw_ball()']
    
    # 새 함수를 draw_objects 앞에 추가
    insert_pos = start_idx
    lines[insert_pos:insert_pos] = new_function + ['', '']
    
    return '\n'.join(lines), len(ball_lines) - 2

def extract_stage5_effects(content):
    """Stage 5 화염 용 이펙트를 별도 함수로 추출"""
    lines = content.split('\n')
    
    # draw_objects 함수 찾기
    start_idx = None
    for i, line in enumerate(lines):
        if 'def draw_objects():' in line:
            start_idx = i
            break
    
    if not start_idx:
        return content, 0
    
    # Stage 5 이펙트 섹션 찾기
    section_start = None
    section_end = None
    
    for i in range(start_idx, len(lines)):
        if 'Stage 5 화염 용이 소용돌이치며 공을 따라오는 이펙트' in lines[i]:
            section_start = i
        elif section_start and '===' in lines[i] and i > section_start:
            section_end = i
            break
    
    if not section_start or not section_end:
        return content, 0
    
    # 섹션 추출
    effect_lines = lines[section_start+1:section_end]
    
    # 새 함수 생성
    new_function = ['def draw_stage5_fire_dragon():']
    new_function.append('    """Stage 5 화염 용 이펙트 그리기"""')
    new_function.append('    global current_stage, BALL, fire_dragon_segments')
    new_function.append('    global screen_shake_offset_x, screen_shake_offset_y')
    
    # 코드 추가
    for line in effect_lines:
        if line.strip():
            new_function.append(line)
        else:
            new_function.append('')
    
    # draw_objects에서 섹션을 함수 호출로 대체
    lines[section_start:section_end] = ['    # === Stage 5 화염 용 이펙트 ===', '    draw_stage5_fire_dragon()']
    
    # 새 함수를 draw_objects 앞에 추가
    insert_pos = start_idx
    lines[insert_pos:insert_pos] = new_function + ['', '']
    
    return '\n'.join(lines), len(effect_lines) - 2

def extract_plasma_cannon(content):
    """플라즈마 레이저 캐논 시스템을 별도 함수로 추출"""
    lines = content.split('\n')
    
    # draw_objects 함수 찾기
    start_idx = None
    for i, line in enumerate(lines):
        if 'def draw_objects():' in line:
            start_idx = i
            break
    
    if not start_idx:
        return content, 0
    
    # 플라즈마 캐논 섹션 찾기
    section_start = None
    section_end = None
    
    for i in range(start_idx, len(lines)):
        if '플라즈마 레이저 캐논 시스템' in lines[i]:
            section_start = i
        elif section_start and '===' in lines[i] and i > section_start:
            section_end = i
            break
    
    if not section_start or not section_end:
        return content, 0
    
    # 섹션 추출
    cannon_lines = lines[section_start+1:section_end]
    
    # 새 함수 생성
    new_function = ['def draw_plasma_cannon():']
    new_function.append('    """플라즈마 레이저 캐논 시스템 그리기"""')
    new_function.append('    global current_stage, plasma_cannon_active, plasma_cannon_charging')
    new_function.append('    global plasma_cannon_charge, plasma_cannon_beam_active, plasma_cannon_beam_timer')
    new_function.append('    global plasma_cannon_position, plasma_cannon_target, BOSS')
    new_function.append('    global screen_shake_offset_x, screen_shake_offset_y')
    
    # 코드 추가
    for line in cannon_lines:
        if line.strip():
            new_function.append(line)
        else:
            new_function.append('')
    
    # draw_objects에서 섹션을 함수 호출로 대체
    lines[section_start:section_end] = ['    # === 플라즈마 캐논 시스템 ===', '    draw_plasma_cannon()']
    
    # 새 함수를 draw_objects 앞에 추가
    insert_pos = start_idx
    lines[insert_pos:insert_pos] = new_function + ['', '']
    
    return '\n'.join(lines), len(cannon_lines) - 2

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase5_1_real.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    
    print("\n🔧 Phase 5-1: draw_objects 함수 실제 분할...")
    
    total_saved = 0
    
    # 1. 플레이어 그리기 추출
    print("\n📌 플레이어 그리기 섹션 추출...")
    content, saved = extract_player_drawing(content)
    total_saved += saved
    print(f"   {saved}줄 → 함수 호출로 변환")
    
    # 2. 공 그리기 추출
    print("\n📌 공 그리기 섹션 추출...")
    content, saved = extract_ball_drawing(content)
    total_saved += saved
    print(f"   {saved}줄 → 함수 호출로 변환")
    
    # 3. Stage 5 이펙트 추출
    print("\n📌 Stage 5 화염 용 이펙트 추출...")
    content, saved = extract_stage5_effects(content)
    total_saved += saved
    print(f"   {saved}줄 → 함수 호출로 변환")
    
    # 4. 플라즈마 캐논 추출
    print("\n📌 플라즈마 캐논 시스템 추출...")
    content, saved = extract_plasma_cannon(content)
    total_saved += saved
    print(f"   {saved}줄 → 함수 호출로 변환")
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 5-1 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   감소: {original_lines - final_lines:,}줄")
    print("="*50)

if __name__ == "__main__":
    main()