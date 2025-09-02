#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""VIDEORESIZE 이벤트 처리 제거"""

def remove_resize_events(filepath):
    """VIDEORESIZE 이벤트 처리 코드 제거"""
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    new_lines = []
    i = 0
    removed_count = 0
    
    while i < len(lines):
        line = lines[i]
        
        # VIDEORESIZE 이벤트 처리 부분 찾기
        if 'pygame.VIDEORESIZE' in line:
            # 해당 elif 블록 전체 건너뛰기
            removed_count += 1
            # elif 라인 건너뛰기
            i += 1
            # handle_window_resize 라인 건너뛰기
            if i < len(lines) and 'handle_window_resize' in lines[i]:
                i += 1
            continue
        else:
            new_lines.append(line)
            i += 1
    
    with open(filepath, 'w', encoding='utf-8') as f:
        f.writelines(new_lines)
    
    print(f"VIDEORESIZE 이벤트 처리 {removed_count}개 제거 완료")

if __name__ == "__main__":
    remove_resize_events("E:\\윈도우용최신\\game\\bosspong\\pingfighter.py")