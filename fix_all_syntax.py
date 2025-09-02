#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""모든 F-string 문법 오류 수정"""

import re

def fix_all_fstring_errors(filepath):
    """모든 F-string 문법 오류 수정"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    fixed_lines = []
    for i, line in enumerate(lines):
        original_line = line
        
        # F-string이 포함된 라인 검색
        if 'print(f"' in line or 'print(f\'' in line:
            # 패턴 1: else '문자열' -> else '문자열'
            line = re.sub(r'else '([^'\']*?)\'', r"else '\1'", line)
            
            # 패턴 2: else '문자열' -> else '문자열'
            line = re.sub(r'else '([^'\']*?)"', r"else '\1'", line)
            
            # 패턴 3: 잘못된 삼항 연산자 수정
            line = re.sub(r'(\{[^}]*?if[^}]*?)else '([^}\']*?)\'([^}]*?\})', r"\1else '\2'\3", line)
            line = re.sub(r'(\{[^}]*?if[^}]*?)else '([^}']*?)"([^}]*?\})', r"\1else '\2'\3", line)
            
            # 패턴 4: 중첩 따옴표 수정
            if line.count('"') % 2 != 0:
                # 홀수개의 따옴표가 있으면 마지막 따옴표 제거 시도
                if line.rstrip().endswith('")'):
                    line = line.rstrip()[:-2] + '")\n'
            
            if line != original_line:
                print(f"라인 {i+1} 수정됨")
        
        fixed_lines.append(line)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(fixed_lines)
    
    print(f"총 수정 완료: {filepath}")

if __name__ == "__main__":
    fix_all_fstring_errors("E:\\윈도우용최신\\game\\bosspong\\pingfighter.py")