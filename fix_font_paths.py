#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""모든 파일의 폰트 경로를 PyInstaller 호환으로 수정"""

import re
import os

def add_resource_path_helper(filepath):
    """파일에 resource_path 헬퍼 추가 및 폰트 경로 수정"""
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # resource_path 헬퍼가 없으면 추가
    if 'def resource_path(' not in content:
        # import 부분 찾기
        import_match = re.search(r'(import .*?\n)+', content)
        if import_match:
            import_end = import_match.end()
            
            # sys와 os import 확인 및 추가
            imports_to_add = []
            if 'import os' not in content and 'from os' not in content:
                imports_to_add.append('import os')
            if 'import sys' not in content and 'from sys' not in content:
                imports_to_add.append('import sys')
            
            # resource_path 헬퍼 추가
            helper_code = '\n'.join(imports_to_add) + '\n' if imports_to_add else ''
            helper_code += '''
# 리소스 경로 헬퍼 (PyInstaller 호환)
def resource_path(relative_path):
    """Get absolute path to resource, works for dev and for PyInstaller"""
    try:
        # PyInstaller creates a temp folder and stores path in _MEIPASS
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

'''
            content = content[:import_end] + helper_code + content[import_end:]
    
    # 폰트 파일 경로 패턴 수정
    font_patterns = [
        # pygame.font.Font("파일명.ttf", ...)
        (r'pygame\.font\.Font\(["\']([^"\']+\.ttf)["\']', r'pygame.font.Font(resource_path("\1")'),
        # pygame.font.Font('파일명.ttf', ...)
        (r'pygame\.font\.Font\([\'"]([^"\']+\.ttf)[\'"]', r'pygame.font.Font(resource_path("\1")'),
        # get_font 등의 함수 내부
        (r'= ["\']([^"\']+\.ttf)["\']', r'= resource_path("\1")'),
        # 폰트 파일 직접 참조
        (r'font_path = ["\']([^"\']+\.ttf)["\']', r'font_path = resource_path("\1")'),
    ]
    
    for pattern, replacement in font_patterns:
        content = re.sub(pattern, replacement, content)
    
    # 이미 resource_path가 적용된 경우 중복 방지
    content = re.sub(r'resource_path\(resource_path\(', r'resource_path(', content)
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"수정 완료: {os.path.basename(filepath)}")

# 수정할 파일들
files_to_fix = [
    "E:\\윈도우용최신\\game\\bosspong\\pingfighter.py",
    "E:\\윈도우용최신\\game\\bosspong\\pixel_font_manager.py",
    "E:\\윈도우용최신\\game\\bosspong\\font_config.py",
    "E:\\윈도우용최신\\game\\bosspong\\opening.py",
]

for filepath in files_to_fix:
    if os.path.exists(filepath):
        add_resource_path_helper(filepath)

print("\n모든 폰트 경로 수정 완료!")