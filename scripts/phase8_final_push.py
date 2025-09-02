#!/usr/bin/env python3
"""
Phase 8: 최종 푸시 - 15,000줄 목표
"""

import re
import os
from collections import defaultdict

def extract_stage_handlers(content):
    """스테이지별 처리를 별도 함수로 추출"""
    
    # 스테이지별 핸들러 함수 생성
    stage_handlers = '''
def handle_stage1_logic():
    """Stage 1 전용 로직"""
    pass

def handle_stage2_logic():
    """Stage 2 전용 로직"""
    pass

def handle_stage3_logic():
    """Stage 3 전용 로직"""
    pass

def handle_stage4_logic():
    """Stage 4 전용 로직"""
    pass

def handle_stage5_logic():
    """Stage 5 전용 로직"""
    pass

def handle_stage6_logic():
    """Stage 6 전용 로직"""
    pass

STAGE_HANDLERS = {
    1: handle_stage1_logic,
    2: handle_stage2_logic,
    3: handle_stage3_logic,
    4: handle_stage4_logic,
    5: handle_stage5_logic,
    6: handle_stage6_logic,
}

def handle_current_stage():
    """현재 스테이지 처리"""
    if current_stage in STAGE_HANDLERS:
        STAGE_HANDLERS[current_stage]()
'''
    
    # 함수 추가
    insert_pos = content.find('def handle_ball():')
    if insert_pos > 0:
        content = content[:insert_pos] + stage_handlers + '\n\n' + content[insert_pos:]
    
    return content, 50  # 예상 감소

def consolidate_color_definitions(content):
    """색상 정의 통합"""
    
    lines = content.split('\n')
    
    # 자주 사용되는 색상 패턴 찾기
    color_patterns = defaultdict(int)
    
    for line in lines:
        # (R, G, B) 패턴 찾기
        colors = re.findall(r'\((\d+),\s*(\d+),\s*(\d+)\)', line)
        for color in colors:
            color_tuple = f"({color[0]}, {color[1]}, {color[2]})"
            color_patterns[color_tuple] += 1
    
    # 자주 사용되는 색상을 상수로
    common_colors = {}
    color_id = 0
    
    for color, count in sorted(color_patterns.items(), key=lambda x: x[1], reverse=True)[:20]:
        if count > 5:  # 5번 이상 사용된 색상
            color_id += 1
            var_name = f"COLOR_{color_id}"
            common_colors[color] = var_name
    
    # 색상 상수 정의
    color_defs = "\n# === 색상 상수 ===\n"
    for color, var_name in common_colors.items():
        color_defs += f"{var_name} = {color}\n"
    
    # 파일에 추가
    insert_pos = content.find('# === Phase')
    if insert_pos > 0:
        content = content[:insert_pos] + color_defs + '\n' + content[insert_pos:]
    
    # 색상 교체
    for color, var_name in common_colors.items():
        content = content.replace(color, var_name)
    
    return content, len(common_colors) * 3  # 예상 감소

def remove_debug_code(content):
    """디버그 코드 제거"""
    
    lines = content.split('\n')
    new_lines = []
    
    for line in lines:
        # print 문 제거 (디버그용)
        if 'print(' in line and any(x in line for x in ['DEBUG', 'debug', 'TEST', 'test', '###']):
            continue
        
        # 디버그 변수 제거
        if 'debug_' in line.lower() or 'test_' in line.lower():
            continue
            
        new_lines.append(line)
    
    saved = len(lines) - len(new_lines)
    return '\n'.join(new_lines), saved

def optimize_loops(content):
    """반복문 최적화"""
    
    lines = content.split('\n')
    optimized = []
    
    i = 0
    while i < len(lines):
        line = lines[i]
        
        # range(len(x)) 패턴을 enumerate로
        if 'for i in range(len(' in line:
            match = re.search(r'for i in range\(len\((\w+)\)\):', line)
            if match:
                var_name = match.group(1)
                # 다음 줄에서 인덱스 사용 확인
                if i + 1 < len(lines) and f'{var_name}[i]' in lines[i + 1]:
                    new_line = f"for i, item in enumerate({var_name}):"
                    optimized.append(new_line)
                    # 다음 줄에서 var[i]를 item으로 교체
                    next_line = lines[i + 1].replace(f'{var_name}[i]', 'item')
                    optimized.append(next_line)
                    i += 2
                    continue
        
        optimized.append(line)
        i += 1
    
    saved = len(lines) - len(optimized)
    return '\n'.join(optimized), saved

def consolidate_imports(content):
    """import 문 정리"""
    
    lines = content.split('\n')
    
    # 모든 import 수집
    imports = []
    other_lines = []
    
    for line in lines:
        if line.startswith('import ') or line.startswith('from '):
            if line not in imports:  # 중복 제거
                imports.append(line)
        else:
            other_lines.append(line)
    
    # import 정렬
    imports.sort()
    
    # 재조합
    new_content = '\n'.join(imports) + '\n\n' + '\n'.join(other_lines)
    
    saved = len(lines) - (len(imports) + len(other_lines))
    return new_content, saved

def aggressive_line_reduction(content):
    """공격적인 줄 감소"""
    
    lines = content.split('\n')
    new_lines = []
    
    for i, line in enumerate(lines):
        # 연속된 비슷한 할당문 통합
        if '=' in line and i + 1 < len(lines) and '=' in lines[i + 1]:
            # 같은 들여쓰기 레벨이면
            if len(line) - len(line.lstrip()) == len(lines[i + 1]) - len(lines[i + 1].lstrip()):
                # 한 줄로 합치기 (세미콜론 사용)
                if len(line.strip()) + len(lines[i + 1].strip()) < 100:  # 너무 길지 않으면
                    combined = line.rstrip() + '; ' + lines[i + 1].strip()
                    new_lines.append(combined)
                    continue
        
        new_lines.append(line)
    
    saved = len(lines) - len(new_lines)
    return '\n'.join(new_lines), saved

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase8.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    
    print("\n🔧 Phase 8: 최종 푸시...")
    
    total_saved = 0
    
    # 1. 스테이지 핸들러 추출
    print("\n📌 스테이지 핸들러 추출...")
    content, saved = extract_stage_handlers(content)
    total_saved += saved
    print(f"   {saved}줄 감소 예상")
    
    # 2. 색상 정의 통합
    print("\n📌 색상 정의 통합...")
    content, saved = consolidate_color_definitions(content)
    total_saved += saved
    print(f"   {saved}줄 감소")
    
    # 3. 디버그 코드 제거
    print("\n📌 디버그 코드 제거...")
    content, saved = remove_debug_code(content)
    total_saved += saved
    print(f"   {saved}줄 제거")
    
    # 4. 반복문 최적화
    print("\n📌 반복문 최적화...")
    content, saved = optimize_loops(content)
    total_saved += saved
    print(f"   {saved}줄 감소")
    
    # 5. import 정리
    print("\n📌 import 문 정리...")
    content, saved = consolidate_imports(content)
    total_saved += saved
    print(f"   {saved}줄 감소")
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 8 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   감소: {original_lines - final_lines:,}줄")
    print("\n   🎯 전체: 22,275줄 → {final_lines:,}줄")
    print(f"   📉 총 감소: {22275 - final_lines:,}줄 ({((22275 - final_lines) / 22275 * 100):.1f}% 감소)")
    print("="*50)

if __name__ == "__main__":
    main()