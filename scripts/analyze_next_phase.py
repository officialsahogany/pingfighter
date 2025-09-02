#!/usr/bin/env python3
"""
Phase 6: 다음 리팩토링 기회 분석
17,933줄을 더 줄일 수 있는 부분 찾기
"""

import re
from collections import defaultdict

def analyze_code_patterns(content):
    """코드 패턴 심화 분석"""
    
    lines = content.split('\n')
    analysis = {
        'if_elif_chains': [],
        'similar_blocks': [],
        'repeated_calls': defaultdict(int),
        'long_functions': [],
        'duplicate_logic': []
    }
    
    # 1. if-elif 체인 분석
    in_if_chain = False
    chain_start = 0
    chain_count = 0
    
    for i, line in enumerate(lines):
        stripped = line.strip()
        if stripped.startswith('if '):
            in_if_chain = True
            chain_start = i
            chain_count = 1
        elif in_if_chain and stripped.startswith('elif '):
            chain_count += 1
        elif in_if_chain and not stripped.startswith(('elif', 'else ')):
            if chain_count > 5:  # 5개 이상의 elif
                analysis['if_elif_chains'].append({
                    'start': chain_start,
                    'count': chain_count,
                    'lines': i - chain_start
                })
            in_if_chain = False
    
    # 2. 비슷한 코드 블록 찾기
    block_hashes = defaultdict(list)
    current_block = []
    
    for i, line in enumerate(lines):
        if line.strip():
            current_block.append(line.strip())
            if len(current_block) == 5:  # 5줄 블록 단위로 비교
                block_hash = hash(tuple(current_block))
                block_hashes[block_hash].append(i-4)
                current_block.pop(0)
    
    # 중복된 블록 찾기
    for block_hash, positions in block_hashes.items():
        if len(positions) > 2:  # 3번 이상 반복
            analysis['similar_blocks'].append({
                'positions': positions,
                'count': len(positions)
            })
    
    # 3. 반복되는 함수 호출
    for line in lines:
        # DrawHelper 패턴
        if 'draw.' in line:
            match = re.search(r'draw\.(\w+)', line)
            if match:
                analysis['repeated_calls'][f'draw.{match.group(1)}'] += 1
        
        # pygame 직접 호출
        if 'pygame.' in line:
            match = re.search(r'pygame\.(\w+\.\w+)', line)
            if match:
                analysis['repeated_calls'][f'pygame.{match.group(1)}'] += 1
    
    return analysis

def find_optimization_opportunities(content):
    """최적화 기회 찾기"""
    
    opportunities = []
    lines = content.split('\n')
    
    # 1. 연속된 draw 호출
    consecutive_draws = 0
    draw_start = 0
    
    for i, line in enumerate(lines):
        if 'draw.' in line or 'pygame.draw.' in line:
            if consecutive_draws == 0:
                draw_start = i
            consecutive_draws += 1
        else:
            if consecutive_draws > 10:
                opportunities.append({
                    'type': '연속 draw 호출',
                    'start': draw_start,
                    'count': consecutive_draws,
                    'potential_saving': consecutive_draws // 3
                })
            consecutive_draws = 0
    
    # 2. 중복된 조건문
    condition_counts = defaultdict(int)
    for line in lines:
        if 'if current_stage ==' in line:
            match = re.search(r'if current_stage == (\d+)', line)
            if match:
                condition_counts[f'stage_{match.group(1)}'] += 1
    
    for condition, count in condition_counts.items():
        if count > 10:
            opportunities.append({
                'type': '중복 스테이지 조건',
                'condition': condition,
                'count': count,
                'potential_saving': count * 2
            })
    
    # 3. 매직 넘버
    magic_numbers = defaultdict(int)
    for line in lines:
        numbers = re.findall(r'\b(\d{2,4})\b', line)
        for num in numbers:
            val = int(num)
            if 50 <= val <= 1000:
                magic_numbers[num] += 1
    
    for num, count in magic_numbers.items():
        if count > 15:
            opportunities.append({
                'type': '매직 넘버',
                'value': num,
                'count': count,
                'potential_saving': count // 2
            })
    
    return opportunities

def analyze_functions(content):
    """함수 크기 및 복잡도 분석"""
    
    lines = content.split('\n')
    functions = []
    
    for i, line in enumerate(lines):
        if line.startswith('def '):
            func_name = re.search(r'def (\w+)', line)
            if func_name:
                # 함수 끝 찾기
                end_line = i + 1
                indent_level = 0
                
                for j in range(i + 1, min(i + 500, len(lines))):
                    if lines[j] and not lines[j][0].isspace():
                        end_line = j
                        break
                
                size = end_line - i
                if size > 50:  # 50줄 이상 함수
                    functions.append({
                        'name': func_name.group(1),
                        'start': i,
                        'size': size
                    })
    
    return sorted(functions, key=lambda x: x['size'], reverse=True)

def main():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    print("="*60)
    print("📊 Phase 6: 다음 리팩토링 기회 분석")
    print("="*60)
    
    # 코드 패턴 분석
    patterns = analyze_code_patterns(content)
    
    print("\n📌 코드 패턴 분석:")
    print(f"   긴 if-elif 체인: {len(patterns['if_elif_chains'])}개")
    print(f"   중복 코드 블록: {len(patterns['similar_blocks'])}개")
    
    # 자주 호출되는 함수
    print("\n📌 자주 호출되는 함수 TOP 10:")
    for func, count in sorted(patterns['repeated_calls'].items(), 
                              key=lambda x: x[1], reverse=True)[:10]:
        print(f"   - {func}: {count}회")
    
    # 최적화 기회
    opportunities = find_optimization_opportunities(content)
    
    print("\n📌 최적화 기회:")
    total_savings = 0
    for opp in sorted(opportunities, key=lambda x: x['potential_saving'], reverse=True)[:10]:
        print(f"   - {opp['type']}: {opp.get('count', '?')}개, 예상 감소 {opp['potential_saving']}줄")
        total_savings += opp['potential_saving']
    
    # 큰 함수들
    functions = analyze_functions(content)
    
    print("\n📌 50줄 이상 함수:")
    for func in functions[:10]:
        print(f"   - {func['name']}: {func['size']}줄")
    
    # 요약
    print("\n" + "="*60)
    print("📊 리팩토링 가능성:")
    print(f"   예상 추가 감소: ~{total_savings}줄")
    print(f"   분할 가능 함수: {len([f for f in functions if f['size'] > 100])}개")
    print(f"   최종 예상: ~{17933 - total_savings}줄")
    print("="*60)

if __name__ == "__main__":
    main()