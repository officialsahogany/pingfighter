#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""F-string 문법 오류 수정 스크립트"""

import re

def fix_fstring_errors(filepath):
    """F-string에서 잘못된 문법 수정"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 패턴 1: else 'OFF' -> else 'OFF'
    content = re.sub(r'else '([^'\']+)\'', r"else '\1'", content)
    
    # 패턴 2: else '문자열' -> else '문자열'  
    content = re.sub(r'else '([^'\']+)"', r"else '\1'", content)
    
    # 패턴 3: ' +"문자열 -> ' + "문자열
    content = re.sub(r'\' \+"', r"' + \"", content)
    
    # 패턴 4: 잘못된 중첩 따옴표 수정
    content = re.sub(r'if ([^}]+) else '([^'\']+)\'', r"if \1 else '\2'", content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"수정 완료: {filepath}")

if __name__ == "__main__":
    fix_fstring_errors("E:\\윈도우용최신\\game\\bosspong\\pingfighter.py")