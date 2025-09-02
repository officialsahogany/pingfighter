#!/usr/bin/env python3
"""빈 try 블록을 자동으로 수정하는 스크립트"""

import os
import re

def fix_empty_try_blocks(filepath):
    """파일의 빈 try 블록을 수정"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    fixed_lines = []
    i = 0
    changes = 0
    
    while i < len(lines):
        line = lines[i]
        fixed_lines.append(line)
        
        # try: 블록 찾기
        if line.strip() == 'try:':
            indent = len(line) - len(line.lstrip())
            next_indent = ' ' * (indent + 4)
            
            # 다음 줄 확인
            if i + 1 < len(lines):
                next_line = lines[i + 1]
                # 다음 줄이 주석이거나 except인 경우
                if (next_line.strip().startswith('#') or 
                    next_line.strip().startswith('except')):
                    # pass 추가
                    fixed_lines.append(f"{next_indent}pass  # Empty try block fix\n")
                    changes += 1
        
        i += 1
    
    if changes > 0:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(fixed_lines)
        print(f"✅ Fixed {changes} empty try blocks in {filepath}")
        return True
    return False

def main():
    """game_logic 디렉토리의 모든 파일 수정"""
    game_logic_dir = "/Users/pika/Desktop/game/bosspong/game_logic"
    
    if not os.path.exists(game_logic_dir):
        print(f"❌ Directory not found: {game_logic_dir}")
        return
    
    total_fixed = 0
    for filename in os.listdir(game_logic_dir):
        if filename.endswith('.py'):
            filepath = os.path.join(game_logic_dir, filename)
            if fix_empty_try_blocks(filepath):
                total_fixed += 1
    
    print(f"\n🎉 총 {total_fixed}개 파일 수정 완료!")

if __name__ == "__main__":
    main()