#!/usr/bin/env python3
"""
Phase 2-3: 조건문 최적화 분석
긴 if-elif 체인과 반복되는 조건 패턴 찾기
"""

import re
from collections import defaultdict

def analyze_condition_patterns(content):
    """조건문 패턴 분석"""
    
    lines = content.split('\n')
    patterns = defaultdict(list)
    
    # 1. 매우 긴 if-elif 체인 찾기 (10개 이상)
    for i, line in enumerate(lines):
        if re.match(r'^\s*if\s+.*:', line):
            elif_count = 0
            j = i + 1
            while j < len(lines) and j < i + 100:
                if re.match(r'^\s*elif\s+.*:', lines[j]):
                    elif_count += 1
                elif re.match(r'^\s*else:', lines[j]):
                    break
                elif re.match(r'^\s*if\s+', lines[j]):
                    break
                j += 1
            
            if elif_count >= 10:
                patterns['very_long_chains'].append((i+1, elif_count))
    
    # 2. 아이템/키 관련 조건 찾기 (딕셔너리로 변환 가능)
    item_conditions = []
    key_conditions = []
    
    for i, line in enumerate(lines):
        # 아이템 조건
        if re.search(r'if\s+current_item\s*==\s*["\'](\w+)["\']', line):
            item_conditions.append(i+1)
        # 키 이벤트 조건
        if re.search(r'event\.key\s*==\s*pygame\.K_\w+', line):
            key_conditions.append(i+1)
    
    if len(item_conditions) >= 5:
        patterns['item_conditions'] = item_conditions[:10]
    if len(key_conditions) >= 10:
        patterns['key_conditions'] = key_conditions[:20]
    
    # 3. 스테이지 관련 조건
    stage_conditions = []
    for i, line in enumerate(lines):
        if re.search(r'current_stage\s*==\s*\d+', line):
            stage_conditions.append(i+1)
    
    if len(stage_conditions) >= 10:
        patterns['stage_conditions'] = stage_conditions[:20]
    
    # 4. 범위 체크 조건 (최적화 가능)
    range_checks = []
    for i, line in enumerate(lines):
        # x > a and x < b 패턴
        if re.search(r'(\w+)\s*[><]=?\s*\d+\s+and\s+\1\s*[><]=?\s*\d+', line):
            range_checks.append(i+1)
    
    if range_checks:
        patterns['range_checks'] = range_checks[:10]
    
    # 5. 동일 변수 반복 체크
    variable_checks = defaultdict(list)
    for i, line in enumerate(lines):
        # if variable == value 패턴
        match = re.search(r'if\s+(\w+)\s*==', line)
        if match:
            var = match.group(1)
            if var not in ['True', 'False', 'None']:
                variable_checks[var].append(i+1)
    
    # 5번 이상 체크되는 변수들
    for var, lines_list in variable_checks.items():
        if len(lines_list) >= 5:
            patterns[f'repeated_{var}'] = lines_list[:5]
    
    return patterns

def suggest_optimizations(patterns):
    """최적화 제안"""
    suggestions = []
    
    if patterns['very_long_chains']:
        suggestions.append({
            'type': 'long_chains',
            'count': len(patterns['very_long_chains']),
            'lines': patterns['very_long_chains'][:3],
            'solution': '딕셔너리 매핑 또는 함수 테이블 사용'
        })
    
    if patterns['item_conditions']:
        suggestions.append({
            'type': 'item_conditions',
            'count': len(patterns['item_conditions']),
            'lines': patterns['item_conditions'][:5],
            'solution': 'ITEM_HANDLERS 딕셔너리 사용'
        })
    
    if patterns['key_conditions']:
        suggestions.append({
            'type': 'key_conditions',
            'count': len(patterns['key_conditions']),
            'lines': patterns['key_conditions'][:5],
            'solution': 'KEY_HANDLERS 딕셔너리 사용'
        })
    
    if patterns['stage_conditions']:
        suggestions.append({
            'type': 'stage_conditions',
            'count': len(patterns['stage_conditions']),
            'lines': patterns['stage_conditions'][:5],
            'solution': 'STAGE_CONFIG 딕셔너리 사용'
        })
    
    if patterns['range_checks']:
        suggestions.append({
            'type': 'range_checks',
            'count': len(patterns['range_checks']),
            'lines': patterns['range_checks'][:5],
            'solution': 'min/max 또는 clamp 함수 사용'
        })
    
    return suggestions

def main():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    patterns = analyze_condition_patterns(content)
    suggestions = suggest_optimizations(patterns)
    
    print("=" * 60)
    print("🔍 Phase 2-3: 조건문 최적화 분석")
    print("=" * 60)
    
    total_optimizations = 0
    estimated_reduction = 0
    
    for suggestion in suggestions:
        print(f"\n📌 {suggestion['type'].replace('_', ' ').title()}")
        print(f"   발견: {suggestion['count']}개")
        print(f"   예시 라인: {suggestion['lines']}")
        print(f"   해결책: {suggestion['solution']}")
        
        total_optimizations += suggestion['count']
        
        # 예상 감소 줄 수 계산
        if suggestion['type'] == 'long_chains':
            estimated_reduction += sum(count for _, count in suggestion['lines']) * 2
        elif suggestion['type'] in ['item_conditions', 'key_conditions']:
            estimated_reduction += suggestion['count'] * 3
        elif suggestion['type'] == 'stage_conditions':
            estimated_reduction += suggestion['count'] * 2
        elif suggestion['type'] == 'range_checks':
            estimated_reduction += suggestion['count'] * 1
    
    print("\n" + "=" * 60)
    print("📊 최적화 가능성 요약:")
    print(f"   - 최적화 기회: {total_optimizations}개")
    print(f"   - 예상 줄 감소: ~{estimated_reduction}줄")
    print("=" * 60)

if __name__ == "__main__":
    main()
