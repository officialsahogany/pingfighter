#!/usr/bin/env python3
"""
Phase 4-2: 반복 코드 패턴 찾기
비슷한 코드 블록을 찾아서 통합 가능성 분석
"""

import re
from collections import defaultdict

def find_repetitive_patterns(content):
    """반복되는 코드 패턴 찾기"""
    
    lines = content.split('\n')
    patterns = defaultdict(list)
    
    # 1. pygame.draw 호출 패턴
    draw_calls = defaultdict(int)
    for i, line in enumerate(lines):
        if 'pygame.draw.' in line:
            # 메서드 추출
            match = re.search(r'pygame\.draw\.(\w+)', line)
            if match:
                method = match.group(1)
                draw_calls[method] += 1
        elif 'draw.' in line and not 'def draw' in line:
            # DrawHelper 사용
            match = re.search(r'draw\.(\w+)', line)
            if match:
                method = match.group(1)
                draw_calls[f'helper_{method}'] += 1
    
    # 2. 비슷한 for 루프 패턴
    for_loops = []
    for i, line in enumerate(lines):
        if re.match(r'\s*for\s+.*in\s+range\((\d+)\)', line):
            match = re.match(r'\s*for\s+.*in\s+range\((\d+)\)', line)
            count = match.group(1)
            for_loops.append((i+1, count))
    
    # 3. 색상 튜플 패턴
    color_patterns = defaultdict(int)
    for i, line in enumerate(lines):
        colors = re.findall(r'\((\d+),\s*(\d+),\s*(\d+)(?:,\s*\d+)?\)', line)
        for color in colors:
            color_str = f"({','.join(color)})"
            color_patterns[color_str] += 1
    
    # 4. 문자열 리터럴 반복
    string_literals = defaultdict(int)
    for i, line in enumerate(lines):
        strings = re.findall(r'["\']([^"\']{3,})["\']', line)
        for s in strings:
            if not s.startswith('/') and not s.startswith('.'):  # 경로 제외
                string_literals[s] += 1
    
    # 5. 조건문 패턴 (current_stage == N)
    stage_conditions = defaultdict(int)
    for i, line in enumerate(lines):
        if 'current_stage ==' in line or 'current_stage in' in line:
            stage_conditions[line.strip()] += 1
    
    # 6. 매직 넘버 사용
    magic_numbers = defaultdict(list)
    for i, line in enumerate(lines):
        # 함수 호출이나 조건문에서 사용되는 숫자들
        numbers = re.findall(r'[\s\(\[\{,=><!\+\-\*/](\d+)(?:\.\d+)?', line)
        for num in numbers:
            if num not in ['0', '1', '2']:  # 너무 일반적인 숫자는 제외
                try:
                    val = int(num) if '.' not in num else float(num)
                    if 100 <= val <= 1000:  # 100-1000 사이 숫자
                        magic_numbers[num].append(i+1)
                except:
                    pass
    
    return draw_calls, for_loops, color_patterns, string_literals, stage_conditions, magic_numbers

def main():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    draw_calls, for_loops, colors, strings, stages, numbers = find_repetitive_patterns(content)
    
    print("=" * 60)
    print("🔍 Phase 4-2: 반복 코드 패턴 분석")
    print("=" * 60)
    
    # 1. pygame.draw 호출 통계
    print("\n📌 Draw 메서드 사용 통계:")
    for method, count in sorted(draw_calls.items(), key=lambda x: x[1], reverse=True)[:10]:
        if count >= 10:
            print(f"   - {method}: {count}회")
    
    # 2. 자주 사용되는 색상
    print("\n📌 자주 사용되는 색상 (10회 이상):")
    for color, count in sorted(colors.items(), key=lambda x: x[1], reverse=True)[:10]:
        if count >= 10:
            print(f"   - {color}: {count}회")
    
    # 3. 반복되는 문자열
    print("\n📌 반복되는 문자열 (5회 이상):")
    for string, count in sorted(strings.items(), key=lambda x: x[1], reverse=True)[:10]:
        if count >= 5 and len(string) > 5:
            print(f"   - '{string[:30]}...': {count}회")
    
    # 4. 스테이지 조건문
    print("\n📌 스테이지 조건문 사용:")
    total_stage_conditions = sum(stages.values())
    print(f"   총 {total_stage_conditions}개 사용")
    
    # 5. 자주 사용되는 매직 넘버
    print("\n📌 자주 사용되는 매직 넘버 (100-1000):")
    for num, lines_list in sorted(numbers.items(), key=lambda x: len(x[1]), reverse=True)[:10]:
        if len(lines_list) >= 5:
            print(f"   - {num}: {len(lines_list)}회")
    
    # 예상 개선
    print("\n" + "=" * 60)
    print("📊 개선 가능성:")
    
    # DrawHelper로 더 변환 가능한 것들
    unconverted_draws = sum(count for method, count in draw_calls.items() 
                          if not method.startswith('helper_') and count > 5)
    print(f"   - pygame.draw → DrawHelper 추가 변환: {unconverted_draws}개")
    
    # 색상 상수화
    color_constants_possible = sum(1 for color, count in colors.items() if count >= 10)
    print(f"   - 색상 상수화 가능: {color_constants_possible}개")
    
    # 매직 넘버 상수화
    magic_constants_possible = sum(1 for num, lines in numbers.items() if len(lines) >= 10)
    print(f"   - 매직 넘버 상수화: {magic_constants_possible}개")
    
    estimated_reduction = unconverted_draws * 0.5 + color_constants_possible * 2 + magic_constants_possible * 3
    print(f"\n예상 줄 감소: ~{int(estimated_reduction)}줄")
    print("=" * 60)

if __name__ == "__main__":
    main()