#!/usr/bin/env python3
"""
handle_player 함수를 모듈로 추출
"""

def main():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # handle_player 함수 찾기
    start_idx = None
    end_idx = None
    
    for i, line in enumerate(lines):
        if line.strip().startswith('def handle_player(keys):'):
            start_idx = i
        elif start_idx is not None and line.startswith('def ') and i > start_idx:
            end_idx = i
            break
    
    print(f"handle_player 함수: {start_idx+1}줄 ~ {end_idx}줄")
    print(f"총 {end_idx - start_idx}줄")
    
    # 함수 내용 추출
    function_lines = lines[start_idx:end_idx]
    
    # 모듈 파일 생성
    module_content = '''"""
handle_player 함수 - bosspong.py에서 추출
1,137줄의 거대한 함수를 별도 모듈로 분리
"""

import pygame
import math
import random

'''
    
    module_content += ''.join(function_lines)
    
    with open('game_logic/handle_player_module.py', 'w', encoding='utf-8') as f:
        f.write(module_content)
    
    print("✅ game_logic/handle_player_module.py 생성됨")
    
    # bosspong.py 수정
    new_lines = []
    import_added = False
    
    for i, line in enumerate(lines):
        # import 추가
        if not import_added and 'handle_ball_module' in line:
            new_lines.append(line)
            new_lines.append('from game_logic.handle_player_module import handle_player as original_handle_player\n')
            import_added = True
        elif i == start_idx:
            # 래퍼 함수로 대체
            new_lines.append('def handle_player(keys):\n')
            new_lines.append('    """handle_player 래퍼 - 실제 구현은 모듈에서"""\n')
            new_lines.append('    return original_handle_player(keys)\n')
            new_lines.append('\n')
            continue
        elif i > start_idx and i < end_idx:
            continue
        else:
            new_lines.append(line)
    
    # 백업
    with open('bosspong_backup_handle_player.py', 'w', encoding='utf-8') as f:
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