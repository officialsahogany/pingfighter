#!/usr/bin/env python3
"""
draw_objects 함수 전체를 모듈로 추출
"""

def extract_entire_draw_objects():
    """draw_objects 함수 전체 추출"""
    
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # draw_objects 함수 찾기
    start_idx = None
    end_idx = None
    
    for i, line in enumerate(lines):
        if line.strip().startswith('def draw_objects():'):
            start_idx = i
        elif start_idx is not None and line.startswith('def ') and i > start_idx:
            end_idx = i
            break
    
    if not end_idx:
        end_idx = len(lines)
    
    print(f"draw_objects 함수: {start_idx+1}줄 ~ {end_idx}줄")
    print(f"총 {end_idx - start_idx}줄")
    
    # 함수 내용 추출
    function_lines = lines[start_idx:end_idx]
    
    return function_lines, start_idx, end_idx

def create_modular_draw_objects(function_lines):
    """모듈화된 draw_objects 생성"""
    
    # 모듈 파일 내용
    module_content = '''"""
draw_objects 함수 - bosspong.py에서 추출
2,724줄의 거대한 함수를 별도 모듈로 분리
"""

import pygame
import math
import random

'''
    
    # 함수 내용 추가
    module_content += ''.join(function_lines)
    
    return module_content

def main():
    """메인 함수"""
    
    # draw_objects 추출
    function_lines, start_idx, end_idx = extract_entire_draw_objects()
    
    # 모듈 파일 생성
    module_content = create_modular_draw_objects(function_lines)
    
    with open('game_logic/draw_objects_module.py', 'w', encoding='utf-8') as f:
        f.write(module_content)
    
    print("✅ game_logic/draw_objects_module.py 생성됨")
    
    # bosspong.py 수정
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # draw_objects를 import와 래퍼로 대체
    new_lines = []
    import_added = False
    
    for i, line in enumerate(lines):
        # import 섹션에 추가
        if not import_added and line.startswith('import '):
            new_lines.append(line)
            new_lines.append('from game_logic.draw_objects_module import draw_objects as original_draw_objects\n')
            import_added = True
        elif i == start_idx:
            # 래퍼 함수로 대체
            new_lines.append('def draw_objects():\n')
            new_lines.append('    """draw_objects 래퍼 - 실제 구현은 모듈에서"""\n')
            new_lines.append('    # 전역 변수들을 딕셔너리로 전달\n')
            new_lines.append('    return original_draw_objects()\n')
            new_lines.append('\n')
            # 원본 함수 건너뛰기
            i = end_idx
            while i < len(lines):
                new_lines.append(lines[i])
                i += 1
            break
        else:
            new_lines.append(line)
    
    # 백업
    with open('bosspong_backup_massive.py', 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    # 새 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print(f"✅ bosspong.py 수정됨")
    print(f"📉 줄 수 감소: {end_idx - start_idx - 5}줄")
    
    # 줄 수 확인
    import subprocess
    result = subprocess.run(['wc', '-l', 'bosspong.py'], capture_output=True, text=True)
    print(f"📊 새로운 줄 수: {result.stdout.strip()}")

if __name__ == "__main__":
    main()