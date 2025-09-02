#!/usr/bin/env python3
"""
draw_objects 함수를 추출하여 새로운 모듈로 분리
"""

def extract_serve_ui_section():
    """서브 UI 섹션 추출"""
    
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # 서브 UI 섹션 찾기 (약 67줄)
    start_marker = "    # 🎾 서브 대기 상태 UI (미니멀 디자인)"
    end_marker = "    # 🎯 퍼펙트 타이밍"
    
    start_idx = None
    end_idx = None
    
    for i, line in enumerate(lines):
        if start_marker in line:
            start_idx = i
        elif end_marker in line and start_idx is not None:
            end_idx = i
            break
    
    if start_idx and end_idx:
        section_lines = lines[start_idx:end_idx]
        
        # 들여쓰기 조정 (4칸 제거)
        adjusted_lines = []
        for line in section_lines:
            if line.startswith('    '):
                adjusted_lines.append(line[4:])
            else:
                adjusted_lines.append(line)
        
        return ''.join(adjusted_lines), (start_idx, end_idx)
    
    return None, None

def create_serve_ui_function(section_code):
    """서브 UI 함수 생성"""
    
    function_template = '''def draw_serve_ui_section(is_waiting_for_serve, waiting_start_time, is_player_serve, 
                        WIDTH, HEIGHT, SCREEN, boss_names, current_stage):
    """서브 대기 상태 UI 그리기 - draw_objects에서 추출"""
{code}
'''
    
    # 함수로 래핑
    indented_code = '\n'.join(['    ' + line for line in section_code.split('\n') if line])
    return function_template.format(code=indented_code)

def main():
    """메인 함수"""
    
    # 서브 UI 섹션 추출
    serve_ui_code, indices = extract_serve_ui_section()
    
    if not serve_ui_code:
        print("❌ 서브 UI 섹션을 찾을 수 없습니다.")
        return
    
    print(f"✅ 서브 UI 섹션 찾음: {indices[0]}줄 ~ {indices[1]}줄")
    print(f"   총 {indices[1] - indices[0]}줄")
    
    # 새 함수 생성
    new_function = create_serve_ui_function(serve_ui_code)
    
    # draw_objects_extracted.py에 저장
    with open('draw_objects_extracted.py', 'w', encoding='utf-8') as f:
        f.write("# draw_objects에서 추출한 함수들\n\n")
        f.write("import pygame\n\n")
        f.write(new_function)
    
    print("📁 draw_objects_extracted.py 파일 생성됨")
    
    # bosspong.py 수정
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # 해당 섹션을 함수 호출로 대체
    new_lines = []
    i = 0
    while i < len(lines):
        if i == indices[0]:
            # 함수 호출로 대체
            new_lines.append("    # 서브 UI (모듈화됨)\n")
            new_lines.append("    draw_serve_ui_section(is_waiting_for_serve, waiting_start_time, is_player_serve, ")
            new_lines.append("WIDTH, HEIGHT, SCREEN, boss_names, current_stage)\n")
            i = indices[1]
        else:
            new_lines.append(lines[i])
            i += 1
    
    # 백업 생성
    with open('bosspong_before_extract.py', 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    # 수정된 파일 저장
    with open('bosspong_test_extract.py', 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print("📁 bosspong_test_extract.py 테스트 파일 생성됨")
    print(f"📉 예상 줄 수 감소: {indices[1] - indices[0] - 3}줄")

if __name__ == "__main__":
    main()