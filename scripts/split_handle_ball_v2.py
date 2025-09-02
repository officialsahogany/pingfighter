#!/usr/bin/env python3
"""
Phase 5-2: handle_ball 함수 분할 V2
Stage별 처리를 찾아서 별도 함수로 추출
"""

import re
import os

def extract_stage5_fireball(content):
    """Stage 5 화염탄 처리를 별도 함수로 추출"""
    lines = content.split('\n')
    
    # Stage 5 화염탄 섹션 찾기
    stage5_start = None
    stage5_end = None
    
    for i, line in enumerate(lines):
        if '# === Stage 5 화염탄 ===' in line:
            stage5_start = i
            # 다음 === 섹션 또는 함수 끝까지
            for j in range(i+1, min(i+500, len(lines))):
                if '# ===' in lines[j] or (lines[j] and not lines[j].startswith(' ')):
                    stage5_end = j
                    break
            break
    
    if not stage5_start or not stage5_end:
        return content, 0
    
    # 섹션 추출
    section_lines = lines[stage5_start+1:stage5_end]
    
    # 새 함수 생성
    new_function = ['def handle_stage5_fireball():']
    new_function.append('    """Stage 5 화염탄 처리"""')
    new_function.append('    global fireball_last_cast, fireball_cooldown, round_start_time')
    new_function.append('    global current_stage, fireballs, BOSS, ball_speed_x, ball_speed_y')
    new_function.append('    ')
    
    # 코드 추가
    for line in section_lines:
        if line.strip():
            new_function.append(line)
        else:
            new_function.append('')
    
    # handle_ball에서 함수 호출로 대체
    lines[stage5_start:stage5_end] = [
        '    # === Stage 5 화염탄 ===',
        '    handle_stage5_fireball()'
    ]
    
    # 새 함수를 handle_ball 앞에 추가
    handle_ball_idx = None
    for i, line in enumerate(lines):
        if 'def handle_ball():' in line:
            handle_ball_idx = i
            break
    
    if handle_ball_idx:
        lines[handle_ball_idx:handle_ball_idx] = new_function + ['', '']
    
    return '\n'.join(lines), len(section_lines)

def extract_paddle_collision(content):
    """패들 충돌 처리를 별도 함수로 추출"""
    lines = content.split('\n')
    
    # 패들 충돌 섹션 찾기
    collision_start = None
    collision_end = None
    
    for i, line in enumerate(lines):
        if '# 패들 충돌 체크' in line:
            collision_start = i
            # 다음 주요 섹션까지
            for j in range(i+1, min(i+200, len(lines))):
                if ('# ===' in lines[j] or 
                    '# Stage' in lines[j] or
                    'def ' in lines[j]):
                    collision_end = j
                    break
            break
    
    if not collision_start or not collision_end:
        return content, 0
    
    # 섹션 추출
    section_lines = lines[collision_start+1:collision_end]
    
    # 새 함수 생성
    new_function = ['def handle_paddle_collision():']
    new_function.append('    """패들과 공의 충돌 처리"""')
    new_function.append('    global BALL, PLAYER, BOSS, ball_speed_x, ball_speed_y')
    new_function.append('    global player_hit_animation_active, player_hit_animation_timer')
    new_function.append('    global boss_hit_animation_active, boss_hit_animation_timer')
    new_function.append('    global combo_count, current_player_paddle_hits')
    new_function.append('    ')
    
    # 코드 추가
    for line in section_lines:
        if line.strip():
            new_function.append(line)
        else:
            new_function.append('')
    
    # handle_ball에서 함수 호출로 대체
    lines[collision_start:collision_end] = [
        '    # 패들 충돌 체크',
        '    handle_paddle_collision()'
    ]
    
    # 새 함수를 handle_ball 앞에 추가
    handle_ball_idx = None
    for i, line in enumerate(lines):
        if 'def handle_ball():' in line:
            handle_ball_idx = i
            break
    
    if handle_ball_idx:
        lines[handle_ball_idx:handle_ball_idx] = new_function + ['', '']
    
    return '\n'.join(lines), len(section_lines)

def extract_ball_movement(content):
    """공 이동 처리를 별도 함수로 추출"""
    lines = content.split('\n')
    
    # 공 이동 관련 코드 찾기
    movement_sections = []
    
    handle_ball_start = None
    handle_ball_end = None
    
    for i, line in enumerate(lines):
        if 'def handle_ball():' in line:
            handle_ball_start = i
            # 함수 끝 찾기
            for j in range(i+1, len(lines)):
                if lines[j] and not lines[j].startswith(' '):
                    handle_ball_end = j
                    break
            break
    
    if not handle_ball_start:
        return content, 0
    
    # 공 이동 코드 패턴 찾기
    movement_start = None
    movement_end = None
    
    for i in range(handle_ball_start, handle_ball_end or len(lines)):
        if 'BALL.x += ball_speed_x' in lines[i]:
            movement_start = i
            # 몇 줄 더 포함
            movement_end = min(i + 20, handle_ball_end or len(lines))
            break
    
    if not movement_start:
        return content, 0
    
    # 섹션 추출
    section_lines = lines[movement_start:movement_end]
    
    # 새 함수 생성  
    new_function = ['def update_ball_position():']
    new_function.append('    """공 위치 업데이트"""')
    new_function.append('    global BALL, ball_speed_x, ball_speed_y')
    new_function.append('    global magnetic_field_active, inverted_controls')
    new_function.append('    ')
    
    # 코드 추가
    for line in section_lines:
        if line.strip():
            # 들여쓰기 조정
            new_function.append(line)
        else:
            new_function.append('')
    
    # handle_ball에서 함수 호출로 대체
    lines[movement_start:movement_end] = ['    update_ball_position()']
    
    # 새 함수를 handle_ball 앞에 추가
    if handle_ball_start:
        lines[handle_ball_start:handle_ball_start] = new_function + ['', '']
    
    return '\n'.join(lines), len(section_lines) - 1

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase5_2_v2.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    
    print("\n🔧 Phase 5-2: handle_ball 함수 분할 V2...")
    
    total_saved = 0
    
    # 1. Stage 5 화염탄 처리 추출
    print("\n📌 Stage 5 화염탄 처리 추출...")
    content, saved = extract_stage5_fireball(content)
    total_saved += saved
    print(f"   {saved}줄 → 함수 호출로 변환")
    
    # 2. 패들 충돌 처리 추출
    print("\n📌 패들 충돌 처리 추출...")
    content, saved = extract_paddle_collision(content)
    total_saved += saved
    print(f"   {saved}줄 → 함수 호출로 변환")
    
    # 3. 공 이동 처리 추출
    print("\n📌 공 이동 처리 추출...")
    content, saved = extract_ball_movement(content)
    total_saved += saved
    print(f"   {saved}줄 → 함수 호출로 변환")
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 5-2 진행 상황:")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   변경: {original_lines - final_lines:,}줄")
    print("="*50)

if __name__ == "__main__":
    main()