#!/usr/bin/env python3
"""
draw_ 함수 호출을 StageRenderer로 안전하게 대체하는 스크립트
"""

import re
from typing import List, Tuple, Dict

# 대체 가능한 draw 함수 매핑
DRAW_FUNCTION_MAPPINGS = {
    # 'draw_tears()': 이미 수동으로 대체됨
    'draw_predicted_trajectory()': "stage_renderer.draw('predicted_trajectory', points=predicted_trajectory)",
    'draw_impact_particles()': "stage_renderer.draw('impact_particles', particles=impact_particles)",
}

def find_and_replace_draw_calls(content: str) -> Tuple[str, List[str]]:
    """
    draw_ 함수 호출을 찾아서 대체
    """
    replacements_made = []
    
    for old_call, new_call in DRAW_FUNCTION_MAPPINGS.items():
        # 함수 호출 찾기 (들여쓰기 포함)
        pattern = r'(\s*)' + re.escape(old_call)
        
        matches = list(re.finditer(pattern, content))
        if matches:
            # 대체 수행
            for match in reversed(matches):  # 역순으로 처리하여 인덱스 문제 방지
                indent = match.group(1)
                old_text = match.group(0)
                new_text = f"{indent}# [StageRenderer로 대체]\n{indent}{new_call}\n{indent}# {old_call}  # 원본 백업"
                
                # 문자열 대체
                start_pos = match.start()
                end_pos = match.end()
                content = content[:start_pos] + new_text + content[end_pos:]
                
                replacements_made.append(f"✅ {old_call} → {new_call}")
    
    return content, replacements_made

def main():
    """메인 함수"""
    
    # bosspong.py 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 원본 백업
    with open('bosspong_backup_stage_renderer.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    # 변환 수행
    new_content, replacements = find_and_replace_draw_calls(content)
    
    if replacements:
        print(f"🎯 {len(replacements)}개의 draw 함수 호출을 대체합니다:")
        for replacement in replacements:
            print(f"  {replacement}")
        
        # 파일 저장
        with open('bosspong.py', 'w', encoding='utf-8') as f:
            f.write(new_content)
        
        print(f"\n✅ 성공적으로 {len(replacements)}개의 함수 호출을 대체했습니다.")
        print("📁 원본 백업: bosspong_backup_stage_renderer.py")
    else:
        print("변환할 함수 호출을 찾지 못했습니다.")

if __name__ == "__main__":
    main()