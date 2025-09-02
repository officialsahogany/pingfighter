#!/usr/bin/env python3
"""
Phase 3-2: 사용하지 않는 함수 제거
안전하게 제거할 수 있는 함수들만 제거
"""

import re
import os

def remove_function(content, func_name, start_line):
    """특정 함수 제거"""
    lines = content.split('\n')
    
    # 시작 라인부터 함수 끝까지 찾기
    end_line = start_line
    in_func = False
    base_indent = None
    
    for i in range(start_line - 1, len(lines)):
        line = lines[i]
        
        # 함수 시작
        if i == start_line - 1:
            in_func = True
            # 기본 들여쓰기 레벨 저장
            base_indent = len(line) - len(line.lstrip())
            continue
        
        if in_func:
            # 빈 라인도 포함
            if not line.strip():
                end_line = i + 1
                continue
            
            # 현재 들여쓰기 레벨
            current_indent = len(line) - len(line.lstrip())
            
            # 같거나 작은 들여쓰기 레벨이면 함수 끝
            if current_indent <= base_indent and line.strip():
                break
            
            end_line = i + 1
    
    # 함수 제거
    new_lines = lines[:start_line-1] + lines[end_line:]
    return '\n'.join(new_lines), end_line - start_line + 1

def remove_unused_functions(content):
    """사용하지 않는 함수들 제거"""
    lines_before = content.count('\n')
    
    # 안전하게 제거할 수 있는 함수들
    # get_gauge, use_gauge는 dash_manager를 위해 유지
    # draw_pachinko는 너무 크고 복잡하므로 일단 유지
    safe_to_remove = [
        ('play_dash_sound', 226),
        ('activate_fireball', 1325),
        ('handle_meditation', 1810),
        ('draw_crocodile_boss', 5187),
        ('draw_score', 11418),
        ('predict_ball_position', 14126),
        ('draw_player_skill_display', 14958),
        ('record_player_miss', 15039)
    ]
    
    # 라인 번호 기준 역순으로 정렬 (아래서부터 제거)
    safe_to_remove.sort(key=lambda x: x[1], reverse=True)
    
    total_removed = 0
    for func_name, original_line in safe_to_remove:
        # 함수가 실제로 있는지 확인
        pattern = r'^def\s+' + re.escape(func_name) + r'\s*\('
        lines = content.split('\n')
        
        actual_line = None
        for i, line in enumerate(lines):
            if re.match(pattern, line):
                actual_line = i + 1
                break
        
        if actual_line:
            content, removed = remove_function(content, func_name, actual_line)
            total_removed += removed
            print(f"   - {func_name}() 제거: {removed}줄")
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after, total_removed

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase3_2.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    
    print("\n🔧 Phase 3-2: 사용하지 않는 함수 제거...")
    
    # 사용하지 않는 함수 제거
    content, lines_saved, removed_count = remove_unused_functions(content)
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 3-2 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   감소: {lines_saved:,}줄")
    print("="*50)

if __name__ == "__main__":
    main()