#!/usr/bin/env python3
"""
안전하게 pygame.draw 호출을 DrawHelper로 교체하는 스크립트
Phase 5 - 점진적 교체
"""

import re
import sys

def replace_pygame_draw_calls(filename):
    """pygame.draw 호출을 DrawHelper로 교체"""
    
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_content = content
    replacements = 0
    
    # 교체 패턴들 정의 (안전한 것들만)
    patterns = [
        # pygame.draw.circle(SCREEN, color, pos, radius) -> draw.circle(color, pos, radius)
        (r'pygame\.draw\.circle\(SCREEN,\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\)',
         r'draw.circle(\1, \2, \3)'),
        
        # pygame.draw.circle(SCREEN, color, pos, radius, width) -> draw.circle(color, pos, radius, width)
        (r'pygame\.draw\.circle\(SCREEN,\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\)',
         r'draw.circle(\1, \2, \3, \4)'),
        
        # pygame.draw.rect(SCREEN, color, rect) -> draw.rect(color, rect)
        (r'pygame\.draw\.rect\(SCREEN,\s*([^,]+),\s*([^,\)]+)\)',
         r'draw.rect(\1, \2)'),
        
        # pygame.draw.rect(SCREEN, color, rect, width) -> draw.rect(color, rect, width)
        (r'pygame\.draw\.rect\(SCREEN,\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\)',
         r'draw.rect(\1, \2, \3)'),
        
        # pygame.draw.line(SCREEN, color, start, end) -> draw.line(color, start, end)
        (r'pygame\.draw\.line\(SCREEN,\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\)',
         r'draw.line(\1, \2, \3)'),
        
        # pygame.draw.line(SCREEN, color, start, end, width) -> draw.line(color, start, end, width)
        (r'pygame\.draw\.line\(SCREEN,\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\)',
         r'draw.line(\1, \2, \3, \4)'),
        
        # pygame.draw.polygon(SCREEN, color, points) -> draw.polygon(color, points)
        (r'pygame\.draw\.polygon\(SCREEN,\s*([^,]+),\s*([^,\)]+)\)',
         r'draw.polygon(\1, \2)'),
        
        # pygame.draw.polygon(SCREEN, color, points, width) -> draw.polygon(color, points, width)
        (r'pygame\.draw\.polygon\(SCREEN,\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\)',
         r'draw.polygon(\1, \2, \3)'),
        
        # pygame.draw.ellipse(SCREEN, color, rect) -> draw.ellipse(color, rect)
        (r'pygame\.draw\.ellipse\(SCREEN,\s*([^,]+),\s*([^,\)]+)\)',
         r'draw.ellipse(\1, \2)'),
        
        # pygame.draw.ellipse(SCREEN, color, rect, width) -> draw.ellipse(color, rect, width)
        (r'pygame\.draw\.ellipse\(SCREEN,\s*([^,]+),\s*([^,]+),\s*([^,\)]+)\)',
         r'draw.ellipse(\1, \2, \3)'),
    ]
    
    # 각 패턴 적용
    for pattern, replacement in patterns:
        matches = re.findall(pattern, content)
        if matches:
            print(f"패턴 발견: {pattern[:50]}... -> {len(matches)}개")
            content, count = re.subn(pattern, replacement, content)
            replacements += count
    
    # border_radius가 있는 rect 처리 (특별 케이스)
    border_radius_pattern = r'pygame\.draw\.rect\(SCREEN,\s*([^,]+),\s*([^,]+),\s*([^,]+),\s*border_radius\s*=\s*([^,\)]+)\)'
    border_radius_replacement = r'draw.rect(\1, \2, \3, border_radius=\4)'
    matches = re.findall(border_radius_pattern, content)
    if matches:
        print(f"border_radius rect 발견: {len(matches)}개")
        content, count = re.subn(border_radius_pattern, border_radius_replacement, content)
        replacements += count
    
    # 변경된 내용 저장
    if replacements > 0:
        # 백업 생성
        with open(filename + '.backup_phase5', 'w', encoding='utf-8') as f:
            f.write(original_content)
        
        # 변경 사항 저장
        with open(filename, 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"\n✅ 총 {replacements}개의 pygame.draw 호출을 DrawHelper로 교체했습니다!")
        
        # 남은 pygame.draw 호출 확인
        remaining = len(re.findall(r'pygame\.draw\.', content))
        print(f"📊 남은 pygame.draw 호출: {remaining}개")
    else:
        print("변경할 항목이 없습니다.")
    
    return replacements

if __name__ == "__main__":
    filename = "../bosspong.py"
    if len(sys.argv) > 1:
        filename = sys.argv[1]
    
    print("=== pygame.draw -> DrawHelper 교체 시작 ===")
    total = replace_pygame_draw_calls(filename)
    print(f"\n완료! 총 {total}개 교체")