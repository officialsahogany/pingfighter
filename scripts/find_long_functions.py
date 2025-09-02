#!/usr/bin/env python3
"""
Phase 4-1: 긴 함수 찾기
너무 긴 함수들을 찾아서 분할 가능성 분석
"""

import re
from collections import defaultdict

def find_long_functions(content):
    """긴 함수들 찾기"""
    
    lines = content.split('\n')
    
    # 함수 정의와 크기 찾기
    functions = []
    
    # 함수 정의 패턴
    func_def_pattern = r'^def\s+(\w+)\s*\('
    
    i = 0
    while i < len(lines):
        match = re.match(func_def_pattern, lines[i])
        if match:
            func_name = match.group(1)
            start_line = i + 1
            
            # 함수 끝 찾기 (다음 def 또는 class 또는 파일 끝)
            end_line = i + 1
            base_indent = len(lines[i]) - len(lines[i].lstrip())
            
            j = i + 1
            while j < len(lines):
                line = lines[j]
                
                # 빈 줄은 계속
                if not line.strip():
                    j += 1
                    continue
                
                # 들여쓰기 레벨 확인
                current_indent = len(line) - len(line.lstrip())
                
                # 같거나 작은 들여쓰기면 함수 끝
                if current_indent <= base_indent and line.strip():
                    break
                
                j += 1
            
            end_line = j
            func_size = end_line - start_line
            functions.append((func_name, start_line, func_size))
            i = j
        else:
            i += 1
    
    # 크기순으로 정렬
    functions.sort(key=lambda x: x[2], reverse=True)
    
    return functions

def analyze_function_complexity(content, func_name, start_line):
    """함수의 복잡도 분석"""
    lines = content.split('\n')
    
    # 시작 라인부터 함수 끝까지
    func_lines = []
    i = start_line - 1
    base_indent = len(lines[i]) - len(lines[i].lstrip())
    
    while i < len(lines):
        line = lines[i]
        
        # 빈 줄도 포함
        if not line.strip():
            func_lines.append(line)
            i += 1
            continue
        
        # 들여쓰기 레벨 확인
        current_indent = len(line) - len(line.lstrip())
        
        # 같거나 작은 들여쓰기면 함수 끝
        if i > start_line - 1 and current_indent <= base_indent and line.strip():
            break
        
        func_lines.append(line)
        i += 1
    
    # 복잡도 분석
    if_count = sum(1 for line in func_lines if 'if ' in line)
    elif_count = sum(1 for line in func_lines if 'elif ' in line)
    for_count = sum(1 for line in func_lines if 'for ' in line)
    while_count = sum(1 for line in func_lines if 'while ' in line)
    
    # 중첩 레벨 계산
    max_indent = 0
    for line in func_lines:
        if line.strip():
            indent = len(line) - len(line.lstrip())
            max_indent = max(max_indent, indent)
    
    max_nesting = max_indent // 4  # 4 spaces per indent
    
    # 섹션 구분 주석 찾기 (=== 패턴)
    section_comments = []
    for line in func_lines:
        if '===' in line and '#' in line:
            section_comments.append(line.strip())
    
    return {
        'if_count': if_count,
        'elif_count': elif_count,
        'for_count': for_count,
        'while_count': while_count,
        'max_nesting': max_nesting,
        'sections': len(section_comments),
        'section_comments': section_comments[:5]  # 처음 5개만
    }

def main():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    functions = find_long_functions(content)
    
    print("=" * 60)
    print("🔍 Phase 4-1: 긴 함수 분석")
    print("=" * 60)
    
    print(f"\n📌 전체 함수: {len(functions)}개")
    
    # 가장 긴 함수 TOP 15
    print(f"\n📌 가장 긴 함수 TOP 15:")
    for i, (func_name, line_num, size) in enumerate(functions[:15], 1):
        complexity = analyze_function_complexity(content, func_name, line_num)
        print(f"\n{i}. {func_name}() - {size}줄 (Line {line_num})")
        print(f"   조건문: if({complexity['if_count']}), elif({complexity['elif_count']})")
        print(f"   반복문: for({complexity['for_count']}), while({complexity['while_count']})")
        print(f"   최대 중첩: {complexity['max_nesting']}단계")
        if complexity['sections'] > 0:
            print(f"   섹션: {complexity['sections']}개")
            for section in complexity['section_comments']:
                print(f"      - {section}")
    
    # 분할 가능한 함수 추천
    print("\n" + "=" * 60)
    print("📊 분할 추천 함수:")
    
    split_candidates = []
    for func_name, line_num, size in functions:
        if size > 200:  # 200줄 이상
            complexity = analyze_function_complexity(content, func_name, line_num)
            if complexity['sections'] > 2:  # 섹션이 3개 이상
                split_candidates.append((func_name, size, complexity['sections']))
    
    for func_name, size, sections in split_candidates[:5]:
        print(f"   - {func_name}(): {size}줄, {sections}개 섹션으로 분할 가능")
    
    # 예상 개선
    total_reduction = sum(size // 10 for _, size, _ in split_candidates)  # 10% 정도 감소 예상
    
    print("\n" + "=" * 60)
    print(f"📊 예상 줄 감소: ~{total_reduction}줄")
    print("=" * 60)

if __name__ == "__main__":
    main()