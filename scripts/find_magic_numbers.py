#!/usr/bin/env python3
"""
매직넘버를 찾아서 상수로 교체할 후보를 제안하는 스크립트
"""

import re
from collections import Counter

def find_magic_numbers(filename):
    """매직넘버 찾기"""
    
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # 숫자 패턴별 카운터
    number_counter = Counter()
    number_contexts = {}  # 숫자가 사용된 컨텍스트 저장
    
    for i, line in enumerate(lines, 1):
        # 주석과 문자열 리터럴 제외
        if line.strip().startswith('#') or '"""' in line or "'''" in line:
            continue
        
        # 상수 정의 라인은 제외
        if '=' in line and line.strip()[0].isupper():
            continue
        
        # 숫자 찾기 (정수와 소수점)
        numbers = re.findall(r'\b\d+\.?\d*\b', line)
        
        for num in numbers:
            # 0, 1, 2는 너무 일반적이므로 제외
            if num in ['0', '1', '2', '0.0', '1.0', '2.0']:
                continue
            
            # RGB 값 범위는 이미 처리됨
            if num in ['255', '128', '192', '64']:
                continue
            
            number_counter[num] += 1
            
            # 컨텍스트 저장 (처음 몇 개만)
            if num not in number_contexts:
                number_contexts[num] = []
            if len(number_contexts[num]) < 3:
                number_contexts[num].append((i, line.strip()))
    
    return number_counter, number_contexts

def analyze_magic_numbers(counter, contexts):
    """매직넘버 분석 및 상수 제안"""
    
    print("=== 자주 사용되는 매직넘버 ===\n")
    
    # 카테고리별로 분류
    categories = {
        'timer': [],      # 시간 관련 (프레임, 밀리초)
        'size': [],       # 크기 관련 (너비, 높이, 반지름)
        'speed': [],      # 속도 관련
        'position': [],   # 위치 관련
        'angle': [],      # 각도 관련
        'other': []       # 기타
    }
    
    # 상수 제안
    constant_suggestions = {}
    
    for num, count in counter.most_common(50):
        if count < 3:  # 3번 미만 사용된 것은 제외
            break
        
        # 컨텍스트 분석으로 카테고리 결정
        context_lines = contexts.get(num, [])
        category = 'other'
        suggested_name = None
        
        # 컨텍스트 키워드 분석
        context_text = ' '.join([line for _, line in context_lines]).lower()
        
        if any(word in context_text for word in ['timer', 'cooldown', 'duration', 'delay', 'frame']):
            category = 'timer'
            if num == '60':
                suggested_name = 'FPS'
            elif num == '1000':
                suggested_name = 'MILLISECOND'
            elif num == '30':
                suggested_name = 'HALF_SECOND_FRAMES'
            elif num == '120':
                suggested_name = 'TWO_SECONDS_FRAMES'
        elif any(word in context_text for word in ['width', 'height', 'size', 'radius']):
            category = 'size'
            if num == '20':
                suggested_name = 'DEFAULT_RADIUS'
            elif num == '50':
                suggested_name = 'LARGE_SIZE'
            elif num == '100':
                suggested_name = 'DEFAULT_SIZE'
        elif any(word in context_text for word in ['speed', 'velocity', 'vel']):
            category = 'speed'
            if num == '5':
                suggested_name = 'DEFAULT_SPEED'
            elif num == '10':
                suggested_name = 'HIGH_SPEED'
        elif any(word in context_text for word in ['x', 'y', 'pos', 'center']):
            category = 'position'
            if num == '300':
                suggested_name = 'CENTER_X'
            elif num == '375':
                suggested_name = 'CENTER_Y'
        elif any(word in context_text for word in ['angle', 'rotation', 'degree', 'sin', 'cos']):
            category = 'angle'
            if num == '360':
                suggested_name = 'FULL_ROTATION'
            elif num == '180':
                suggested_name = 'HALF_ROTATION'
            elif num == '90':
                suggested_name = 'QUARTER_ROTATION'
        
        categories[category].append((num, count))
        if suggested_name:
            constant_suggestions[num] = suggested_name
        
        print(f"{num:>6} : {count:>3}회 사용 [{category}]")
        for line_num, line in context_lines[:2]:
            print(f"         Line {line_num}: {line[:70]}...")
    
    print("\n=== 상수 정의 제안 ===\n")
    
    # 카테고리별로 상수 제안
    print("# 타이머 및 시간 관련")
    for num, name in constant_suggestions.items():
        if 'FRAME' in name or 'SECOND' in name or name in ['FPS', 'MILLISECOND']:
            print(f"{name} = {num}")
    
    print("\n# 크기 관련")
    for num, name in constant_suggestions.items():
        if 'SIZE' in name or 'RADIUS' in name or 'WIDTH' in name or 'HEIGHT' in name:
            print(f"{name} = {num}")
    
    print("\n# 속도 관련")
    for num, name in constant_suggestions.items():
        if 'SPEED' in name or 'VELOCITY' in name:
            print(f"{name} = {num}")
    
    print("\n# 각도 관련")
    for num, name in constant_suggestions.items():
        if 'ROTATION' in name or 'ANGLE' in name:
            print(f"{name} = {num}")
    
    return constant_suggestions

if __name__ == "__main__":
    filename = "../bosspong.py"
    
    print("매직넘버 분석을 시작합니다...\n")
    counter, contexts = find_magic_numbers(filename)
    suggestions = analyze_magic_numbers(counter, contexts)