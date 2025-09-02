#!/usr/bin/env python3
"""
draw_ 함수들을 완전히 제거하고 StageRenderer로 대체하는 공격적인 스크립트
"""

import re
from typing import List, Tuple, Dict

def find_draw_function_definitions(content: str) -> Dict[str, Tuple[int, int]]:
    """
    draw_ 함수 정의를 찾아서 시작과 끝 라인 인덱스 반환
    """
    lines = content.split('\n')
    draw_functions = {}
    
    i = 0
    while i < len(lines):
        line = lines[i]
        # draw_ 함수 정의 찾기
        if line.startswith('def draw_'):
            match = re.match(r'def (draw_\w+)\(.*\):', line)
            if match:
                func_name = match.group(1)
                start_line = i
                
                # 함수의 끝 찾기 (다음 def나 클래스 정의까지)
                j = i + 1
                while j < len(lines):
                    next_line = lines[j]
                    # 들여쓰기가 없는 다음 정의를 찾으면 종료
                    if next_line and not next_line[0].isspace() and (
                        next_line.startswith('def ') or 
                        next_line.startswith('class ') or
                        next_line.startswith('#') and j > i + 1
                    ):
                        break
                    j += 1
                
                end_line = j - 1
                draw_functions[func_name] = (start_line, end_line)
                i = j
                continue
        i += 1
    
    return draw_functions

def create_stage_renderer_calls(func_name: str) -> str:
    """
    함수 이름에 따라 적절한 StageRenderer 호출 생성
    """
    mappings = {
        'draw_tears': "stage_renderer.draw('tears', tears_data=falling_tears, stage=current_stage, img=TEAR_IMG)",
        'draw_predicted_trajectory': "stage_renderer.draw('predicted_trajectory', points=predicted_trajectory)",
        'draw_impact_particles': "stage_renderer.draw('impact_particles', particles=impact_particles)",
        'draw_pause_overlay': "stage_renderer.draw('pause_overlay')",
        'draw_shaking_screen': "shake_offset = stage_renderer.draw('shaking_screen', shake_intensity=shake_intensity)",
    }
    
    if func_name in mappings:
        return mappings[func_name]
    else:
        # 기본 매핑
        element_type = func_name.replace('draw_', '')
        return f"stage_renderer.draw('{element_type}')"

def main():
    """메인 함수"""
    
    # bosspong.py 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    lines = content.split('\n')
    
    # 원본 백업
    with open('bosspong_backup_aggressive.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    # draw 함수 정의 찾기
    draw_functions = find_draw_function_definitions(content)
    
    # 제거할 함수들 (간단한 것들만)
    simple_functions = [
        'draw_tears', 'draw_predicted_trajectory', 'draw_impact_particles',
        'draw_pause_overlay', 'draw_shaking_screen'
    ]
    
    lines_to_remove = []
    replacements = {}
    
    for func_name in simple_functions:
        if func_name in draw_functions:
            start, end = draw_functions[func_name]
            lines_to_remove.extend(range(start, end + 1))
            
            # 함수 호출 대체 매핑 생성
            call_pattern = f"{func_name}()"
            replacement = create_stage_renderer_calls(func_name)
            replacements[call_pattern] = replacement
    
    # 새 내용 생성 (함수 정의 제거)
    new_lines = []
    skip_next = False
    
    for i, line in enumerate(lines):
        # 이전에 주석 처리된 라인 제거
        if '# [StageRenderer로 대체]' in line:
            continue
        if '# 원본 백업' in line and ('draw_tears()' in line or 'draw_predicted_trajectory()' in line):
            continue
            
        if i not in lines_to_remove:
            # 함수 호출 대체
            modified_line = line
            for old_call, new_call in replacements.items():
                if old_call in modified_line:
                    # 단순 치환이 아닌 전체 라인 교체
                    indent = len(line) - len(line.lstrip())
                    modified_line = ' ' * indent + new_call
            new_lines.append(modified_line)
    
    new_content = '\n'.join(new_lines)
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"✅ {len(simple_functions)}개의 draw 함수를 제거하고 대체했습니다.")
    print(f"📉 제거된 라인 수: {len(lines_to_remove)}")
    print(f"📁 원본 백업: bosspong_backup_aggressive.py")
    
    # 변경 사항 출력
    for func_name in simple_functions:
        if func_name in draw_functions:
            print(f"  ✅ {func_name} 함수 제거 및 호출 대체")

if __name__ == "__main__":
    main()