#!/usr/bin/env python3
"""
Phase 2-2: 유사 로직 패턴 분석
반복되는 패턴과 유사한 로직을 찾아서 통합 기회 식별
"""

import re
from collections import defaultdict

def analyze_similar_patterns(content):
    """유사한 코드 패턴들을 찾아서 분석"""
    
    patterns_found = defaultdict(list)
    lines = content.split('\n')
    
    # 1. if-elif 체인 패턴 찾기
    if_elif_pattern = r'^\s*if\s+.*:\s*$'
    elif_pattern = r'^\s*elif\s+.*:\s*$'
    
    for i, line in enumerate(lines):
        if re.match(if_elif_pattern, line):
            # elif 체인 길이 계산
            elif_count = 0
            j = i + 1
            while j < len(lines) and j < i + 50:  # 최대 50줄까지만 확인
                if re.match(elif_pattern, lines[j]):
                    elif_count += 1
                elif re.match(if_elif_pattern, lines[j]):
                    break
                j += 1
            
            if elif_count >= 3:  # 3개 이상의 elif가 있는 경우
                patterns_found['long_if_elif'].append((i+1, elif_count))
    
    # 2. 반복되는 global 선언 패턴
    global_pattern = r'^\s*global\s+(.+)$'
    global_vars = defaultdict(list)
    
    for i, line in enumerate(lines):
        match = re.match(global_pattern, line)
        if match:
            vars_list = match.group(1).split(',')
            if len(vars_list) >= 5:  # 5개 이상의 변수를 global로 선언
                patterns_found['many_globals'].append((i+1, len(vars_list)))
    
    # 3. 유사한 pygame.draw 호출 패턴
    draw_patterns = [
        (r'pygame\.draw\.circle\(', 'circle'),
        (r'pygame\.draw\.rect\(', 'rect'),
        (r'pygame\.draw\.line\(', 'line'),
        (r'pygame\.draw\.polygon\(', 'polygon')
    ]
    
    for pattern, shape in draw_patterns:
        matches = re.findall(pattern, content)
        if len(matches) >= 10:  # 10번 이상 반복되는 경우
            patterns_found[f'repeated_{shape}'].append(len(matches))
    
    # 4. 반복되는 try-except 패턴 (Phase 1에서 놓친 것들)
    try_except_count = len(re.findall(r'try:\s*\n.*?\nexcept', content, re.DOTALL))
    if try_except_count > 0:
        patterns_found['remaining_try_except'].append(try_except_count)
    
    # 5. 중복된 조건 체크 패턴
    condition_patterns = defaultdict(int)
    condition_regex = r'if\s+([^:]+):'
    
    for match in re.finditer(condition_regex, content):
        condition = match.group(1).strip()
        # 단순 조건들만 카운트
        if len(condition) < 50 and 'and' not in condition and 'or' not in condition:
            condition_patterns[condition] += 1
    
    # 3번 이상 반복되는 조건들
    for condition, count in condition_patterns.items():
        if count >= 3:
            patterns_found['repeated_conditions'].append((condition, count))
    
    # 6. 유사한 함수 호출 패턴
    func_call_pattern = r'(\w+)\([^)]*\)'
    func_calls = defaultdict(int)
    
    for match in re.finditer(func_call_pattern, content):
        func_name = match.group(1)
        if func_name not in ['print', 'int', 'str', 'len', 'range', 'max', 'min']:
            func_calls[func_name] += 1
    
    # 자주 호출되는 함수들
    for func, count in func_calls.items():
        if count >= 20:
            patterns_found['frequent_calls'].append((func, count))
    
    return patterns_found

def main():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    patterns = analyze_similar_patterns(content)
    
    print("=" * 60)
    print("🔍 Phase 2-2: 유사 로직 패턴 분석")
    print("=" * 60)
    
    total_opportunities = 0
    estimated_reduction = 0
    
    # 1. 긴 if-elif 체인
    if patterns['long_if_elif']:
        print(f"\n📌 긴 if-elif 체인 ({len(patterns['long_if_elif'])}개):")
        for line, count in patterns['long_if_elif'][:5]:
            print(f"   - Line {line}: {count}개의 elif")
        total_opportunities += len(patterns['long_if_elif'])
        estimated_reduction += len(patterns['long_if_elif']) * 5
    
    # 2. 많은 global 변수 선언
    if patterns['many_globals']:
        print(f"\n📌 많은 global 변수 선언 ({len(patterns['many_globals'])}개):")
        for line, count in patterns['many_globals'][:5]:
            print(f"   - Line {line}: {count}개 변수")
        total_opportunities += len(patterns['many_globals'])
        estimated_reduction += len(patterns['many_globals']) * 2
    
    # 3. 반복되는 draw 호출
    for shape in ['circle', 'rect', 'line', 'polygon']:
        key = f'repeated_{shape}'
        if patterns[key]:
            print(f"\n📌 반복되는 pygame.draw.{shape} ({patterns[key][0]}번):")
            print(f"   → DrawHelper로 통합 가능")
            estimated_reduction += patterns[key][0] // 10 * 2
    
    # 4. 남은 try-except
    if patterns['remaining_try_except']:
        print(f"\n📌 남은 try-except 블록: {patterns['remaining_try_except'][0]}개")
        estimated_reduction += patterns['remaining_try_except'][0] * 3
    
    # 5. 반복되는 조건
    if patterns['repeated_conditions']:
        print(f"\n📌 반복되는 조건 체크 ({len(patterns['repeated_conditions'])}개):")
        for condition, count in patterns['repeated_conditions'][:5]:
            print(f"   - '{condition}': {count}번")
        estimated_reduction += len(patterns['repeated_conditions']) * 2
    
    # 6. 자주 호출되는 함수
    if patterns['frequent_calls']:
        print(f"\n📌 자주 호출되는 함수:")
        for func, count in sorted(patterns['frequent_calls'], key=lambda x: x[1], reverse=True)[:5]:
            print(f"   - {func}(): {count}번")
    
    print("\n" + "=" * 60)
    print("📊 통합 가능성 요약:")
    print(f"   - 발견된 패턴: {len(patterns)}개")
    print(f"   - 최적화 기회: {total_opportunities}개")
    print(f"   - 예상 줄 감소: ~{estimated_reduction}줄")
    print("=" * 60)

if __name__ == "__main__":
    main()
