#!/usr/bin/env python3
"""
Phase 2-1: 중복 함수 통합을 위한 분석 스크립트
유사한 함수 패턴을 찾아서 통합 가능한 함수들을 식별
"""

import re
import ast
from collections import defaultdict

def find_similar_functions(content):
    """유사한 함수들을 찾아서 통합 가능한 그룹으로 분류"""
    
    # 함수 정의 패턴
    func_pattern = r'def (\w+)\([^)]*\):(.*?)(?=\ndef |\nclass |\Z)'
    matches = re.findall(func_pattern, content, re.DOTALL)
    
    function_groups = defaultdict(list)
    
    for func_name, func_body in matches:
        # 함수 본문의 주요 패턴 추출
        lines = func_body.strip().split('\n')
        
        # 짧은 함수들 (5줄 이하) - 통합 가능성 높음
        if len(lines) <= 5:
            function_groups['short_functions'].append((func_name, len(lines)))
        
        # draw_ 함수들 중 유사한 패턴
        if func_name.startswith('draw_'):
            # pygame.draw 호출 수 계산
            draw_calls = len(re.findall(r'pygame\.draw\.\w+', func_body))
            if draw_calls > 0:
                function_groups['draw_functions'].append((func_name, draw_calls))
            
            # 단순 blit만 하는 함수들
            if 'blit' in func_body and len(lines) <= 10:
                function_groups['simple_blit'].append(func_name)
        
        # handle_ 함수들 중 유사한 패턴
        if func_name.startswith('handle_'):
            # 상태 업데이트만 하는 함수들
            if 'global' in func_body and len(lines) <= 15:
                function_groups['state_handlers'].append((func_name, len(lines)))
        
        # 활성화 함수들 (activate_)
        if func_name.startswith('activate_'):
            function_groups['activate_functions'].append((func_name, len(lines)))
        
        # throw_ 함수들 (투척물 관련)
        if func_name.startswith('throw_'):
            function_groups['throw_functions'].append(func_name)
        
    return function_groups

def main():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    groups = find_similar_functions(content)
    
    print("=" * 60)
    print("🔍 Phase 2-1: 중복 함수 통합 가능성 분석")
    print("=" * 60)
    
    total_functions = 0
    consolidation_opportunities = []
    
    # 1. 짧은 함수들 (통합 가능)
    if groups['short_functions']:
        short_funcs = sorted(groups['short_functions'], key=lambda x: x[1])
        print(f"\n📌 짧은 함수들 ({len(short_funcs)}개) - 인라인화 가능:")
        for name, lines in short_funcs[:10]:  # 상위 10개만
            print(f"   - {name}: {lines}줄")
        total_functions += len(short_funcs)
        consolidation_opportunities.append(('short_inline', len(short_funcs)))
    
    # 2. 단순 draw 함수들
    if groups['simple_blit']:
        print(f"\n📌 단순 blit 함수들 ({len(groups['simple_blit'])}개) - 통합 가능:")
        for name in groups['simple_blit'][:5]:
            print(f"   - {name}")
        consolidation_opportunities.append(('simple_blit', len(groups['simple_blit'])))
    
    # 3. activate_ 함수들
    if groups['activate_functions']:
        activate_funcs = sorted(groups['activate_functions'], key=lambda x: x[1])
        print(f"\n📌 activate_ 함수들 ({len(activate_funcs)}개) - 패턴 통합 가능:")
        for name, lines in activate_funcs[:5]:
            print(f"   - {name}: {lines}줄")
        consolidation_opportunities.append(('activate_pattern', len(activate_funcs)))
    
    # 4. throw_ 함수들
    if groups['throw_functions']:
        print(f"\n📌 throw_ 함수들 ({len(groups['throw_functions'])}개) - 통합 가능:")
        for name in groups['throw_functions']:
            print(f"   - {name}")
        consolidation_opportunities.append(('throw_pattern', len(groups['throw_functions'])))
    
    # 5. 상태 핸들러들
    if groups['state_handlers']:
        state_handlers = sorted(groups['state_handlers'], key=lambda x: x[1])
        print(f"\n📌 상태 핸들러 ({len(state_handlers)}개) - 패턴 통합 가능:")
        for name, lines in state_handlers[:5]:
            print(f"   - {name}: {lines}줄")
        consolidation_opportunities.append(('state_handlers', len(state_handlers)))
    
    # 예상 줄 감소 계산
    estimated_reduction = 0
    for pattern_type, count in consolidation_opportunities:
        if pattern_type == 'short_inline':
            estimated_reduction += count * 3  # 평균 3줄 감소
        elif pattern_type == 'simple_blit':
            estimated_reduction += count * 5  # 평균 5줄 감소
        elif pattern_type == 'activate_pattern':
            estimated_reduction += count * 4  # 평균 4줄 감소
        elif pattern_type == 'throw_pattern':
            estimated_reduction += count * 10  # 평균 10줄 감소
        elif pattern_type == 'state_handlers':
            estimated_reduction += count * 3  # 평균 3줄 감소
    
    print("\n" + "=" * 60)
    print("📊 통합 가능성 요약:")
    print(f"   - 분석된 패턴 그룹: {len(consolidation_opportunities)}개")
    print(f"   - 통합 가능 함수: {sum(c[1] for c in consolidation_opportunities)}개")
    print(f"   - 예상 줄 감소: ~{estimated_reduction}줄")
    print("=" * 60)

if __name__ == "__main__":
    main()
