#!/usr/bin/env python3
"""
draw_objects 함수 분석 및 구조 파악
"""

def analyze_draw_objects():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # draw_objects 함수 찾기
    start_line = None
    end_line = None
    
    for i, line in enumerate(lines):
        if line.strip().startswith('def draw_objects'):
            start_line = i
        elif start_line is not None and line.startswith('def ') and i > start_line:
            end_line = i
            break
    
    if not end_line:
        end_line = len(lines)
    
    print(f"draw_objects 함수: {start_line+1}줄 ~ {end_line}줄")
    print(f"총 {end_line - start_line}줄\n")
    
    # 주요 섹션 찾기
    sections = []
    current_section = None
    
    for i in range(start_line, end_line):
        line = lines[i]
        
        # 주석으로 섹션 구분
        if '# 🎾' in line or '# 🎯' in line or '# 🔥' in line or '# ⚡' in line or '# 🌟' in line:
            if current_section:
                current_section['end'] = i
                sections.append(current_section)
            current_section = {
                'name': line.strip(),
                'start': i,
                'end': None
            }
        # if 문으로 큰 블록 구분
        elif line.strip().startswith('if current_stage'):
            if current_section:
                current_section['end'] = i
                sections.append(current_section)
            current_section = {
                'name': f"스테이지 조건: {line.strip()[:50]}",
                'start': i,
                'end': None
            }
    
    if current_section:
        current_section['end'] = end_line
        sections.append(current_section)
    
    # 섹션 출력
    print("주요 섹션:")
    print("-" * 60)
    for section in sections[:20]:  # 처음 20개만
        lines_count = section['end'] - section['start']
        print(f"{section['name'][:50]:<50} | {lines_count:>4}줄")
    
    # 스테이지별 코드 분석
    print("\n스테이지별 코드:")
    print("-" * 60)
    stage_sections = {}
    
    for i in range(start_line, end_line):
        line = lines[i]
        if 'current_stage == ' in line:
            stage_num = None
            for num in ['1', '2', '3', '4', '5', '6']:
                if f'current_stage == {num}' in line:
                    stage_num = num
                    break
            if stage_num:
                if stage_num not in stage_sections:
                    stage_sections[stage_num] = 0
                stage_sections[stage_num] += 1
    
    for stage, count in sorted(stage_sections.items()):
        print(f"스테이지 {stage}: {count}개 조건문")
    
    return sections, start_line, end_line

if __name__ == "__main__":
    analyze_draw_objects()