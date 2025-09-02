#!/usr/bin/env python3
"""
handle_ball 함수를 모듈로 추출
"""

def extract_handle_ball():
    """handle_ball 함수 추출"""
    
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # handle_ball 함수 찾기
    start_idx = None
    end_idx = None
    
    for i, line in enumerate(lines):
        if line.strip() == 'def handle_ball():':
            start_idx = i
        elif start_idx is not None and line.startswith('def ') and i > start_idx:
            end_idx = i
            break
    
    if not end_idx:
        # 파일 끝까지
        end_idx = len(lines)
    
    print(f"handle_ball 함수: {start_idx+1}줄 ~ {end_idx}줄")
    print(f"총 {end_idx - start_idx}줄")
    
    # 함수 내용 추출
    function_lines = lines[start_idx:end_idx]
    
    return function_lines, start_idx, end_idx

def main():
    """메인 함수"""
    
    # handle_ball 추출
    function_lines, start_idx, end_idx = extract_handle_ball()
    
    # 모듈 파일 생성
    module_content = '''"""
handle_ball 함수 - bosspong.py에서 추출
1,591줄의 거대한 함수를 별도 모듈로 분리
"""

import pygame
import math
import random

'''
    
    module_content += ''.join(function_lines)
    
    with open('game_logic/handle_ball_module.py', 'w', encoding='utf-8') as f:
        f.write(module_content)
    
    print("✅ game_logic/handle_ball_module.py 생성됨")
    
    # bosspong.py 수정
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # import 추가 및 함수 대체
    new_lines = []
    import_added = False
    
    for i, line in enumerate(lines):
        # draw_objects_module import 다음에 추가
        if not import_added and 'draw_objects_module' in line:
            new_lines.append(line)
            new_lines.append('from game_logic.handle_ball_module import handle_ball as original_handle_ball\n')
            import_added = True
        elif i == start_idx:
            # 래퍼 함수로 대체
            new_lines.append('def handle_ball():\n')
            new_lines.append('    """handle_ball 래퍼 - 실제 구현은 모듈에서"""\n')
            new_lines.append('    return original_handle_ball()\n')
            new_lines.append('\n')
            # 원본 함수 건너뛰기
            continue
        elif i > start_idx and i < end_idx:
            continue
        else:
            new_lines.append(line)
    
    # 백업
    with open('bosspong_backup_handle_ball.py', 'w', encoding='utf-8') as f:
        f.writelines(lines)
    
    # 새 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print(f"✅ bosspong.py 수정됨")
    print(f"📉 줄 수 감소: {end_idx - start_idx - 4}줄")
    
    # 줄 수 확인
    import subprocess
    result = subprocess.run(['wc', '-l', 'bosspong.py'], capture_output=True, text=True)
    print(f"📊 새로운 줄 수: {result.stdout.strip()}")

if __name__ == "__main__":
    main()