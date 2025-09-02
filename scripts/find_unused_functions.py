#!/usr/bin/env python3
"""
Phase 3-2: 사용하지 않는 함수 찾기
정의되었지만 호출되지 않는 함수들을 찾기
"""

import re
from collections import defaultdict

def find_unused_functions(content):
    """사용하지 않는 함수 찾기"""
    
    lines = content.split('\n')
    
    # 함수 정의 찾기
    function_definitions = {}
    function_calls = defaultdict(int)
    
    # 함수 정의 패턴
    func_def_pattern = r'^def\s+(\w+)\s*\('
    
    for i, line in enumerate(lines):
        match = re.match(func_def_pattern, line)
        if match:
            func_name = match.group(1)
            function_definitions[func_name] = i + 1
    
    # 함수 호출 찾기
    for i, line in enumerate(lines):
        # 주석 제외
        if '#' in line:
            comment_pos = line.index('#')
            # 문자열 내의 # 는 제외
            in_string = False
            for j, char in enumerate(line[:comment_pos]):
                if char in '"\'':
                    in_string = not in_string
            if not in_string:
                line = line[:comment_pos]
        
        # 각 정의된 함수가 호출되는지 확인
        for func_name in function_definitions:
            # 함수 정의 라인은 제외
            if i + 1 == function_definitions[func_name]:
                continue
            
            # 함수 호출 패턴
            # func_name( 형태로 호출되는 경우
            pattern = r'\b' + re.escape(func_name) + r'\s*\('
            if re.search(pattern, line):
                function_calls[func_name] += 1
            
            # 콜백이나 참조로 사용되는 경우 (괄호 없이)
            # 예: button.on_click = func_name
            pattern2 = r'[=,\[\(]\s*' + re.escape(func_name) + r'\b'
            if re.search(pattern2, line):
                function_calls[func_name] += 1
    
    # 사용되지 않는 함수 찾기
    unused_funcs = []
    for func_name, def_line in function_definitions.items():
        if function_calls[func_name] == 0:
            # main, __init__ 등 특수 함수는 제외
            if func_name not in ['main', '__init__', '__str__', '__repr__']:
                unused_funcs.append((func_name, def_line))
    
    # 거의 사용되지 않는 함수 (1번만 호출)
    rarely_used = []
    for func_name, def_line in function_definitions.items():
        if function_calls[func_name] == 1:
            rarely_used.append((func_name, def_line, function_calls[func_name]))
    
    return unused_funcs, rarely_used, function_definitions, function_calls

def get_function_size(content, func_name, start_line):
    """함수의 크기(라인 수) 계산"""
    lines = content.split('\n')
    
    # 시작 라인부터 다음 함수 또는 클래스까지 카운트
    func_lines = 0
    in_func = False
    base_indent = None
    
    for i in range(start_line - 1, len(lines)):
        line = lines[i]
        
        # 함수 시작
        if i == start_line - 1:
            in_func = True
            # 기본 들여쓰기 레벨 저장
            base_indent = len(line) - len(line.lstrip())
            func_lines += 1
            continue
        
        if in_func:
            # 빈 라인도 카운트
            if not line.strip():
                func_lines += 1
                continue
            
            # 현재 들여쓰기 레벨
            current_indent = len(line) - len(line.lstrip())
            
            # 같거나 작은 들여쓰기 레벨이면 함수 끝
            if current_indent <= base_indent and line.strip():
                break
            
            func_lines += 1
    
    return func_lines

def main():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    unused_funcs, rarely_used, all_funcs, calls = find_unused_functions(content)
    
    print("=" * 60)
    print("🔍 Phase 3-2: 사용하지 않는 함수 분석")
    print("=" * 60)
    
    print(f"\n📌 전체 함수 정의: {len(all_funcs)}개")
    
    # 사용되지 않는 함수
    if unused_funcs:
        print(f"\n📌 사용되지 않는 함수 ({len(unused_funcs)}개):")
        total_lines = 0
        for func_name, line_num in sorted(unused_funcs, key=lambda x: x[1])[:20]:
            func_size = get_function_size(content, func_name, line_num)
            total_lines += func_size
            print(f"   - Line {line_num}: {func_name}() [{func_size}줄]")
        print(f"   → 총 {total_lines}줄 제거 가능")
    
    # 1번만 호출되는 함수
    if rarely_used:
        print(f"\n📌 1번만 호출되는 함수 ({len(rarely_used)}개 중 10개):")
        for func_name, line_num, count in rarely_used[:10]:
            func_size = get_function_size(content, func_name, line_num)
            print(f"   - Line {line_num}: {func_name}() [{func_size}줄]")
    
    # 가장 많이 호출되는 함수
    most_called = sorted([(name, calls[name]) for name in all_funcs if calls[name] > 0], 
                        key=lambda x: x[1], reverse=True)[:10]
    print(f"\n📌 가장 많이 호출되는 함수:")
    for func_name, count in most_called:
        print(f"   - {func_name}(): {count}번")
    
    # 예상 감소량
    estimated_reduction = sum(get_function_size(content, func, line) 
                            for func, line in unused_funcs)
    
    print("\n" + "=" * 60)
    print(f"📊 예상 줄 감소: ~{estimated_reduction}줄")
    print("=" * 60)

if __name__ == "__main__":
    main()