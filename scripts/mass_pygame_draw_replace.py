#!/usr/bin/env python3
"""
모든 pygame.draw 호출을 DrawHelper로 대체하는 대규모 스크립트
"""

import re
from typing import List, Tuple

def replace_pygame_draw_calls(content: str) -> Tuple[str, int]:
    """
    pygame.draw 호출을 draw 헬퍼로 대체
    """
    replacements = 0
    
    # pygame.draw.rect 대체
    # pygame.draw.rect(SCREEN, color, rect[, width][, border_radius])
    pattern = r'pygame\.draw\.rect\(SCREEN,\s*([^,]+),\s*([^,\)]+)(?:,\s*(\d+))?(?:,\s*(\d+))?\)'
    
    def rect_replacer(match):
        nonlocal replacements
        replacements += 1
        color = match.group(1)
        rect = match.group(2)
        width = match.group(3) if match.group(3) else '0'
        border_radius = match.group(4) if match.group(4) else '0'
        
        if border_radius != '0' and border_radius is not None:
            return f'draw.rect({color}, {rect}, {width}, {border_radius})'
        elif width != '0':
            return f'draw.rect({color}, {rect}, {width})'
        else:
            return f'draw.rect({color}, {rect})'
    
    content = re.sub(pattern, rect_replacer, content)
    
    # pygame.draw.circle 대체
    # pygame.draw.circle(SCREEN, color, pos, radius[, width])
    pattern = r'pygame\.draw\.circle\(SCREEN,\s*([^,]+),\s*([^,]+),\s*([^,\)]+)(?:,\s*(\d+))?\)'
    
    def circle_replacer(match):
        nonlocal replacements
        replacements += 1
        color = match.group(1)
        pos = match.group(2)
        radius = match.group(3)
        width = match.group(4) if match.group(4) else '0'
        
        if width != '0':
            return f'draw.circle({color}, {pos}, {radius}, {width})'
        else:
            return f'draw.circle({color}, {pos}, {radius})'
    
    content = re.sub(pattern, circle_replacer, content)
    
    # pygame.draw.line 대체
    # pygame.draw.line(SCREEN, color, start, end[, width])
    pattern = r'pygame\.draw\.line\(SCREEN,\s*([^,]+),\s*([^,]+),\s*([^,]+)(?:,\s*(\d+))?\)'
    
    def line_replacer(match):
        nonlocal replacements
        replacements += 1
        color = match.group(1)
        start = match.group(2)
        end = match.group(3)
        width = match.group(4) if match.group(4) else '1'
        
        if width != '1':
            return f'draw.line({color}, {start}, {end}, {width})'
        else:
            return f'draw.line({color}, {start}, {end})'
    
    content = re.sub(pattern, line_replacer, content)
    
    # pygame.draw.lines 대체
    pattern = r'pygame\.draw\.lines\(SCREEN,\s*([^,]+),\s*([^,]+),\s*([^,]+)(?:,\s*(\d+))?\)'
    
    def lines_replacer(match):
        nonlocal replacements
        replacements += 1
        color = match.group(1)
        closed = match.group(2)
        points = match.group(3)
        width = match.group(4) if match.group(4) else '1'
        
        return f'draw.lines({color}, {points}, {closed}, {width})'
    
    content = re.sub(pattern, lines_replacer, content)
    
    # pygame.draw.polygon 대체
    pattern = r'pygame\.draw\.polygon\(SCREEN,\s*([^,]+),\s*([^,]+)(?:,\s*(\d+))?\)'
    
    def polygon_replacer(match):
        nonlocal replacements
        replacements += 1
        color = match.group(1)
        points = match.group(2)
        width = match.group(3) if match.group(3) else '0'
        
        return f'draw.polygon({color}, {points}, {width})'
    
    content = re.sub(pattern, polygon_replacer, content)
    
    return content, replacements

def main():
    """메인 함수"""
    
    # bosspong.py 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 원본 백업
    with open('bosspong_backup_mass_draw.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    # 변환 수행
    new_content, count = replace_pygame_draw_calls(content)
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(new_content)
    
    print(f"✅ {count}개의 pygame.draw 호출을 DrawHelper로 대체했습니다.")
    print(f"📁 원본 백업: bosspong_backup_mass_draw.py")
    
    # 예상 줄 수 감소 계산
    # 평균적으로 pygame.draw.rect -> draw.rect으로 10자 정도 감소
    estimated_chars_saved = count * 10
    estimated_lines_saved = estimated_chars_saved // 80  # 평균 80자 per line
    print(f"📉 예상 문자 수 감소: {estimated_chars_saved}")
    print(f"📉 예상 줄 수 감소: ~{estimated_lines_saved}줄")

if __name__ == "__main__":
    main()