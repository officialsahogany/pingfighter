#!/usr/bin/env python3
"""
Phase 3-1: 사용하지 않는 변수 찾기
정의되었지만 한 번도 사용되지 않는 변수들을 찾기
"""

import re
from collections import defaultdict

def find_unused_variables(content):
    """사용하지 않는 변수 찾기"""
    
    lines = content.split('\n')
    
    # 변수 정의 찾기
    variable_definitions = {}
    variable_usage = defaultdict(int)
    
    # 전역 변수 정의 패턴
    global_var_pattern = r'^([a-z_][a-z0-9_]*)\s*=\s*'
    
    for i, line in enumerate(lines):
        # 주석 제외
        if '#' in line:
            line = line[:line.index('#')]
        
        # 전역 변수 정의 찾기
        match = re.match(global_var_pattern, line)
        if match:
            var_name = match.group(1)
            if var_name not in variable_definitions:
                variable_definitions[var_name] = i + 1
    
    # 변수 사용 찾기
    for i, line in enumerate(lines):
        # 주석 제외
        if '#' in line:
            line = line[:line.index('#')]
        
        # 각 정의된 변수가 사용되는지 확인
        for var_name in variable_definitions:
            # 정의 라인은 제외
            if i + 1 == variable_definitions[var_name]:
                continue
            
            # 변수 사용 패턴 (단순 이름 매칭은 부정확할 수 있음)
            # 더 정확한 패턴: 변수명이 독립적으로 나타나는 경우
            pattern = r'\b' + re.escape(var_name) + r'\b'
            if re.search(pattern, line):
                variable_usage[var_name] += 1
    
    # 사용되지 않는 변수 찾기
    unused_vars = []
    for var_name, def_line in variable_definitions.items():
        if variable_usage[var_name] == 0:
            unused_vars.append((var_name, def_line))
    
    return unused_vars, variable_definitions, variable_usage

def find_unused_globals(content):
    """global 선언했지만 사용하지 않는 변수 찾기"""
    
    lines = content.split('\n')
    unused_globals = []
    
    # 함수 내 global 선언 찾기
    in_function = False
    current_function = None
    function_globals = {}
    
    for i, line in enumerate(lines):
        # 함수 시작
        if re.match(r'^def\s+(\w+)\s*\(', line):
            match = re.match(r'^def\s+(\w+)\s*\(', line)
            in_function = True
            current_function = match.group(1)
            function_globals[current_function] = {'globals': [], 'uses': set()}
        
        # 함수 끝 (들여쓰기가 없는 다음 라인)
        elif in_function and line and line[0] not in ' \t':
            in_function = False
            current_function = None
        
        # global 선언
        elif in_function and 'global ' in line:
            global_vars = re.findall(r'global\s+([\w\s,]+)', line)
            if global_vars:
                vars_list = [v.strip() for v in global_vars[0].split(',')]
                function_globals[current_function]['globals'].extend([(v, i+1) for v in vars_list])
        
        # 변수 사용 체크
        elif in_function and current_function:
            for var, _ in function_globals[current_function]['globals']:
                if re.search(r'\b' + re.escape(var) + r'\b', line) and 'global' not in line:
                    function_globals[current_function]['uses'].add(var)
    
    # 사용하지 않는 global 찾기
    for func, data in function_globals.items():
        for var, line_num in data['globals']:
            if var not in data['uses']:
                unused_globals.append((func, var, line_num))
    
    return unused_globals

def main():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    unused_vars, all_vars, usage = find_unused_variables(content)
    unused_globals = find_unused_globals(content)
    
    print("=" * 60)
    print("🔍 Phase 3-1: 사용하지 않는 변수 분석")
    print("=" * 60)
    
    print(f"\n📌 전체 변수 정의: {len(all_vars)}개")
    
    # 사용되지 않는 변수 (상위 20개만)
    if unused_vars:
        print(f"\n📌 사용되지 않는 변수 ({len(unused_vars)}개 중 상위 20개):")
        for var_name, line_num in sorted(unused_vars, key=lambda x: x[1])[:20]:
            print(f"   - Line {line_num}: {var_name}")
    
    # 사용되지 않는 global 선언
    if unused_globals:
        print(f"\n📌 사용되지 않는 global 선언 ({len(unused_globals)}개):")
        for func, var, line_num in unused_globals[:10]:
            print(f"   - Line {line_num}: global {var} in {func}()")
    
    # 거의 사용되지 않는 변수 (1-2번만 사용)
    rarely_used = [(var, usage[var]) for var in all_vars if 0 < usage[var] <= 2]
    if rarely_used:
        print(f"\n📌 거의 사용되지 않는 변수 (1-2번만 사용, {len(rarely_used)}개 중 10개):")
        for var_name, count in sorted(rarely_used, key=lambda x: x[1])[:10]:
            print(f"   - {var_name}: {count}번 사용")
    
    # 예상 감소량
    estimated_reduction = len(unused_vars) + len(unused_globals)
    
    print("\n" + "=" * 60)
    print(f"📊 예상 줄 감소: ~{estimated_reduction}줄")
    print("=" * 60)

if __name__ == "__main__":
    main()