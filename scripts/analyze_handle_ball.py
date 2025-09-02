#!/usr/bin/env python3
"""
Phase 5-2: handle_ball 함수 분석
1325줄의 거대한 함수를 섹션별로 분석
"""

import re

def analyze_handle_ball(content):
    """handle_ball 함수의 구조 분석"""
    
    lines = content.split('\n')
    
    # handle_ball 함수 찾기
    start_line = None
    for i, line in enumerate(lines):
        if 'def handle_ball():' in line:
            start_line = i
            break
    
    if start_line is None:
        return None
    
    # 함수 끝 찾기
    end_line = start_line + 1
    base_indent = 0
    
    for i in range(start_line + 1, len(lines)):
        line = lines[i]
        
        # 빈 줄은 계속
        if not line.strip():
            continue
        
        # 들여쓰기 레벨 확인
        current_indent = len(line) - len(line.lstrip())
        
        # 같거나 작은 들여쓰기면 함수 끝
        if current_indent <= base_indent and line.strip():
            end_line = i
            break
    
    # 주요 섹션 찾기
    sections = []
    
    for i in range(start_line + 1, end_line):
        line = lines[i]
        
        # 주석으로 섹션 구분
        if '#' in line and any(keyword in line for keyword in ['Stage', '충돌', '이동', '효과', '점수', '아이템', '스킬']):
            sections.append({
                'line': i + 1,
                'content': line.strip(),
                'type': 'comment'
            })
        
        # 큰 if 블록 찾기
        if line.strip().startswith('if current_stage'):
            sections.append({
                'line': i + 1,
                'content': line.strip(),
                'type': 'stage_condition'
            })
    
    return {
        'start': start_line + 1,
        'end': end_line,
        'total_lines': end_line - start_line,
        'sections': sections
    }

def find_extractable_sections(content):
    """추출 가능한 큰 섹션 찾기"""
    
    lines = content.split('\n')
    
    # handle_ball 함수 범위 찾기
    start_idx = None
    end_idx = None
    
    for i, line in enumerate(lines):
        if 'def handle_ball():' in line:
            start_idx = i
            # 함수 끝 찾기
            for j in range(i+1, len(lines)):
                if lines[j] and not lines[j].startswith((' ', '\t')):
                    end_idx = j
                    break
            break
    
    if not start_idx or not end_idx:
        return []
    
    # 큰 블록 찾기 (100줄 이상)
    extractable = []
    current_block = []
    block_start = None
    block_name = None
    
    for i in range(start_idx, end_idx):
        line = lines[i]
        
        # Stage별 처리 블록
        if 'if current_stage ==' in line:
            if current_block and len(current_block) > 100:
                extractable.append({
                    'name': block_name,
                    'start': block_start,
                    'lines': len(current_block)
                })
            current_block = [line]
            block_start = i + 1
            # Stage 번호 추출
            match = re.search(r'current_stage == (\d+)', line)
            if match:
                block_name = f"Stage {match.group(1)} 처리"
        elif current_block:
            current_block.append(line)
    
    # 마지막 블록 처리
    if current_block and len(current_block) > 100:
        extractable.append({
            'name': block_name,
            'start': block_start,
            'lines': len(current_block)
        })
    
    return sorted(extractable, key=lambda x: x['lines'], reverse=True)

def main():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # handle_ball 분석
    analysis = analyze_handle_ball(content)
    
    if not analysis:
        print("handle_ball 함수를 찾을 수 없습니다!")
        return
    
    print("="*60)
    print("📊 handle_ball 함수 분석")
    print("="*60)
    print(f"\n📍 위치: Line {analysis['start']} - {analysis['end']}")
    print(f"📏 크기: {analysis['total_lines']}줄")
    print(f"📑 섹션: {len(analysis['sections'])}개")
    
    # 추출 가능한 섹션 찾기
    extractable = find_extractable_sections(content)
    
    if extractable:
        print("\n📌 추출 가능한 큰 섹션들:")
        for i, section in enumerate(extractable[:10], 1):
            print(f"   {i}. {section['name']}: {section['lines']}줄 (Line {section['start']})")
    
    # Stage별 조건문 수 계산
    stage_conditions = [s for s in analysis['sections'] if s['type'] == 'stage_condition']
    print(f"\n📊 Stage별 조건문: {len(stage_conditions)}개")
    
    # 제안
    print("\n💡 리팩토링 제안:")
    print("   1. Stage별 처리를 별도 함수로 분리 (handle_stage1, handle_stage2, ...)")
    print("   2. 충돌 처리 로직을 collision_handler로 분리")
    print("   3. 아이템 효과 처리를 item_effect_handler로 분리")
    print("   4. 점수 계산 로직을 score_calculator로 분리")
    
    estimated_reduction = analysis['total_lines'] * 0.1  # 약 10% 감소 예상
    print(f"\n예상 줄 감소: ~{int(estimated_reduction)}줄")
    print("="*60)

if __name__ == "__main__":
    main()