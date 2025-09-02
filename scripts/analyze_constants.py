#!/usr/bin/env python3
"""
Phase 2-4: 상수 정리 및 통합 분석
중복된 상수, 매직 넘버, 그룹화 가능한 상수들을 찾기
"""

import re
from collections import defaultdict

def analyze_constants(content):
    """상수 패턴 분석"""
    
    lines = content.split('\n')
    constants = defaultdict(list)
    
    # 1. 전역 상수 찾기 (대문자 변수)
    constant_pattern = r'^([A-Z][A-Z_0-9]+)\s*=\s*(.+)$'
    for i, line in enumerate(lines):
        match = re.match(constant_pattern, line)
        if match:
            const_name = match.group(1)
            const_value = match.group(2).strip()
            constants['global_constants'].append((i+1, const_name, const_value))
    
    # 2. 매직 넘버 찾기 (코드에 직접 사용된 숫자)
    magic_numbers = defaultdict(list)
    for i, line in enumerate(lines):
        # 함수 호출이나 조건문에서 사용되는 숫자들
        numbers = re.findall(r'[\s\(\[\{,=><!\+\-\*/](\d+(?:\.\d+)?)', line)
        for num in numbers:
            if num not in ['0', '1', '2']:  # 너무 일반적인 숫자는 제외
                try:
                    if '.' in num:
                        val = float(num)
                    else:
                        val = int(num)
                    if val >= 10:  # 10 이상의 숫자만
                        magic_numbers[num].append(i+1)
                except:
                    pass
    
    # 3. 색상 관련 상수 찾기
    color_constants = []
    for i, line in enumerate(lines):
        if re.search(r'\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)', line):
            color_constants.append(i+1)
    
    # 4. 파일 경로 문자열 찾기
    path_strings = []
    for i, line in enumerate(lines):
        if re.search(r'["\'][\w/]+\.(png|jpg|wav|mp3|ttf)["\']', line):
            path_strings.append(i+1)
    
    # 5. 스테이지 관련 상수
    stage_constants = []
    for i, line in enumerate(lines):
        if re.search(r'STAGE\d+|stage_?\d+', line, re.IGNORECASE):
            stage_constants.append(i+1)
    
    # 6. 크기/위치 관련 상수
    size_constants = []
    for i, line in enumerate(lines):
        if re.search(r'WIDTH|HEIGHT|SIZE|RADIUS|X|Y|POS', line):
            size_constants.append(i+1)
    
    return constants, magic_numbers, color_constants, path_strings, stage_constants, size_constants

def suggest_consolidation(constants, magic_numbers):
    """상수 통합 제안"""
    suggestions = []
    
    # 1. 자주 사용되는 매직 넘버
    frequent_magic = []
    for num, lines in magic_numbers.items():
        if len(lines) >= 5:  # 5번 이상 사용된 숫자
            frequent_magic.append((num, len(lines)))
    
    if frequent_magic:
        suggestions.append({
            'type': 'magic_numbers',
            'items': sorted(frequent_magic, key=lambda x: x[1], reverse=True)[:10],
            'solution': '상수로 정의하여 재사용'
        })
    
    # 2. 그룹화 가능한 상수들
    groups = defaultdict(list)
    for _, name, value in constants['global_constants']:
        # 접두사로 그룹화
        prefix = name.split('_')[0] if '_' in name else name
        groups[prefix].append(name)
    
    groupable = []
    for prefix, names in groups.items():
        if len(names) >= 3:  # 3개 이상 같은 접두사
            groupable.append((prefix, len(names)))
    
    if groupable:
        suggestions.append({
            'type': 'groupable_constants',
            'items': sorted(groupable, key=lambda x: x[1], reverse=True),
            'solution': '딕셔너리나 클래스로 그룹화'
        })
    
    return suggestions

def main():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    constants, magic_numbers, color_constants, path_strings, stage_constants, size_constants = analyze_constants(content)
    suggestions = suggest_consolidation(constants, magic_numbers)
    
    print("=" * 60)
    print("🔍 Phase 2-4: 상수 정리 및 통합 분석")
    print("=" * 60)
    
    print(f"\n📌 전역 상수: {len(constants['global_constants'])}개")
    
    print(f"\n📌 매직 넘버 (10회 이상 사용):")
    for num, lines in sorted(magic_numbers.items(), key=lambda x: len(x[1]), reverse=True)[:10]:
        if len(lines) >= 10:
            print(f"   - {num}: {len(lines)}회 사용")
    
    print(f"\n📌 색상 정의: {len(color_constants)}개 라인")
    print(f"📌 파일 경로: {len(path_strings)}개 라인")
    print(f"📌 스테이지 관련: {len(stage_constants)}개 라인")
    print(f"📌 크기/위치 관련: {len(size_constants)}개 라인")
    
    print("\n" + "=" * 60)
    print("📊 통합 제안:")
    
    for suggestion in suggestions:
        print(f"\n{suggestion['type'].replace('_', ' ').title()}:")
        for item in suggestion['items'][:5]:
            print(f"   - {item}")
        print(f"   해결책: {suggestion['solution']}")
    
    # 예상 감소량 계산
    estimated_reduction = 0
    for num, count in frequent_magic[:10]:
        estimated_reduction += count // 5  # 상수화로 인한 감소
    estimated_reduction += len(groupable) * 10  # 그룹화로 인한 감소
    
    print("\n" + "=" * 60)
    print(f"📊 예상 줄 감소: ~{estimated_reduction}줄")
    print("=" * 60)

if __name__ == "__main__":
    main()