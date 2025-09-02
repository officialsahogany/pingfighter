#!/usr/bin/env python3
"""
여러 대형 함수들을 일괄 추출
"""

FUNCTIONS_TO_EXTRACT = [
    ('show_character_selection', 978),
    ('draw_aircraft_carrier_boss', 795),
    ('get_final_boss_config', 767),
    ('show_start_screen', 587),
    ('show_difficulty_selection', 578),
    ('draw_player_gauge', 541),
]

def extract_function(lines, func_name):
    """특정 함수 추출"""
    start_idx = None
    end_idx = None
    
    for i, line in enumerate(lines):
        if f'def {func_name}' in line:
            start_idx = i
        elif start_idx is not None and line.startswith('def ') and i > start_idx:
            end_idx = i
            break
    
    if not end_idx:
        end_idx = len(lines)
    
    if start_idx:
        return lines[start_idx:end_idx], start_idx, end_idx
    return None, None, None

def main():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    total_reduction = 0
    functions_extracted = []
    
    # 각 함수 추출
    for func_name, expected_lines in FUNCTIONS_TO_EXTRACT:
        func_lines, start_idx, end_idx = extract_function(lines, func_name)
        
        if func_lines:
            # 모듈 파일 생성
            module_name = f'game_logic/{func_name}_module.py'
            with open(module_name, 'w', encoding='utf-8') as f:
                f.write(f'"""\\n{func_name} 함수 - bosspong.py에서 추출\\n"""\\n\\n')
                f.write('import pygame\\nimport math\\nimport random\\n\\n')
                f.write(''.join(func_lines))
            
            functions_extracted.append((func_name, start_idx, end_idx))
            reduction = end_idx - start_idx - 4  # 래퍼 함수 크기
            total_reduction += reduction
            print(f"✅ {func_name}: {end_idx - start_idx}줄 → 모듈화 (-{reduction}줄)")
    
    # bosspong.py 수정
    new_lines = []
    skip_until = -1
    imports_added = False
    
    for i, line in enumerate(lines):
        # import 추가
        if not imports_added and 'from game_logic' in line:
            new_lines.append(line)
            for func_name, _, _ in functions_extracted:
                new_lines.append(f'from game_logic.{func_name}_module import {func_name} as original_{func_name}\n')
            imports_added = True
            continue
        
        # 함수 대체 확인
        if i < skip_until:
            continue
        
        replaced = False
        for func_name, start_idx, end_idx in functions_extracted:
            if i == start_idx:
                # 래퍼 함수로 대체
                func_line = lines[start_idx]
                params = func_line[func_line.index('('):func_line.index(':')] 
                new_lines.append(f'def {func_name}{params}:\n')
                new_lines.append(f'    """래퍼 - 실제 구현은 모듈에서"""\n')
                new_lines.append(f'    return original_{func_name}{params}\n')
                new_lines.append('\n')
                skip_until = end_idx
                replaced = True
                break
        
        if not replaced:
            new_lines.append(line)
    
    # 백업
    with open('bosspong_backup_batch.py', 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    # 새 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print(f"\\n✅ 총 {len(functions_extracted)}개 함수 모듈화")
    print(f"📉 총 줄 수 감소: {total_reduction}줄")
    
    # 줄 수 확인
    import subprocess
    result = subprocess.run(['wc', '-l', 'bosspong.py'], capture_output=True, text=True)
    print(f"📊 새로운 줄 수: {result.stdout.strip()}")

if __name__ == "__main__":
    main()