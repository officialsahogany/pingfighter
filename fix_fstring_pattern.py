#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""F-string 문법 오류 패턴 수정"""

import os
import re
import glob

def fix_fstring_pattern(content):
    """F-string의 특정 패턴 수정"""
    # 패턴: else '문자열' -> else '문자열'
    content = re.sub(r'else '([^'\']*?)\'', r"else '\1'", content)
    
    # 패턴: else '문자열' -> else '문자열'  
    content = re.sub(r'else '([^'\']*?)"', r"else '\1'", content)
    
    # 패턴: else ' -> else ''
    content = re.sub(r'else\'([^\']*?)\'', r"else '\1'", content)
    
    # 잘못된 패턴 수정
    content = re.sub(r'else '\'', r"else ''", content)
    content = re.sub(r'else\'\'', r"else ''", content)
    
    return content

def fix_file(filepath):
    """파일의 F-string 문법 오류 수정"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original = content
        content = fix_fstring_pattern(content)
        
        if content != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(content)
            print(f"수정됨: {os.path.basename(filepath)}")
            return True
    except Exception as e:
        print(f"오류: {filepath} - {e}")
    return False

def main():
    """모든 Python 파일 수정"""
    # 우선순위 파일들
    priority_files = [
        "pingfighter.py",
        "dash_manager.py", 
        "physics_manager.py",
        "skill.py",
        "academy.py",
        "items.py",
        "gacha.py",
        "opening.py",
        "effects_manager.py",
        "ui_manager.py",
        "sound_manager.py",
        "feedback_system.py",
        "trade_point_system.py",
        "legendary_items.py",
        "pixel_font_manager.py",
        "game_mechanics/half_dash_system.py",
        "game_mechanics/half_dash_integration.py",
    ]
    
    base_dir = "E:\\윈도우용최신\\game\\bosspong"
    fixed_count = 0
    
    for file in priority_files:
        filepath = os.path.join(base_dir, file)
        if os.path.exists(filepath):
            if fix_file(filepath):
                fixed_count += 1
    
    # 추가로 모든 .py 파일 검사
    for filepath in glob.glob(os.path.join(base_dir, "**/*.py"), recursive=True):
        if fix_file(filepath):
            fixed_count += 1
    
    print(f"\n총 {fixed_count}개 파일 수정 완료")

if __name__ == "__main__":
    main()