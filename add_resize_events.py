#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""모든 이벤트 루프에 VIDEORESIZE 이벤트 처리 추가"""

import re

def add_resize_event_handling(filepath):
    """VIDEORESIZE 이벤트 처리 추가"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    modified = False
    new_lines = []
    i = 0
    
    while i < len(lines):
        line = lines[i]
        
        # pygame.QUIT 처리 바로 다음에 VIDEORESIZE 추가
        if 'if event.type == pygame.QUIT:' in line:
            # 해당 라인 추가
            new_lines.append(line)
            i += 1
            
            # pygame.QUIT 처리 블록 끝까지 찾기
            indent = len(line) - len(line.lstrip())
            while i < len(lines):
                current_line = lines[i]
                if current_line.strip() and not current_line.startswith(' ' * (indent + 4)):
                    # 같은 레벨의 다른 elif/else 찾음
                    break
                new_lines.append(current_line)
                i += 1
            
            # VIDEORESIZE 이벤트 체크가 이미 있는지 확인
            if i < len(lines) and 'pygame.VIDEORESIZE' not in lines[i]:
                # VIDEORESIZE 이벤트 처리 추가
                resize_code = f"{' ' * indent}elif event.type == pygame.VIDEORESIZE:\n"
                resize_code += f"{' ' * (indent + 4)}handle_window_resize(event.w, event.h)\n"
                new_lines.append(resize_code)
                modified = True
        else:
            new_lines.append(line)
            i += 1
    
    if modified:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        print(f"VIDEORESIZE 이벤트 처리 추가 완료")
        return True
    else:
        print(f"변경 사항 없음")
        return False

if __name__ == "__main__":
    add_resize_event_handling("E:\\윈도우용최신\\game\\bosspong\\pingfighter.py")