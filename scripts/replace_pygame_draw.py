#!/usr/bin/env python3
"""
Phase 11: pygame.draw 직접 호출을 DrawHelper로 교체
"""

import re

def replace_pygame_draw():
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    replacements = [
        # pygame.draw.circle -> draw.circle
        (r'pygame\.draw\.circle\((.*?),(.*?),(.*?),(.*?)\)', r'draw.circle(\2,\3,\4)'),
        # pygame.draw.rect -> draw.rect  
        (r'pygame\.draw\.rect\((.*?),(.*?),(.*?)\)', r'draw.rect(\2,\3)'),
        # pygame.draw.line -> draw.line
        (r'pygame\.draw\.line\((.*?),(.*?),(.*?),(.*?),(.*?)\)', r'draw.line(\2,\3,\4,\5)'),
        # pygame.draw.lines -> draw.lines
        (r'pygame\.draw\.lines\((.*?),(.*?),(.*?),(.*?),(.*?)\)', r'draw.lines(\2,\3,\4,\5)'),
    ]
    
    count = 0
    for pattern, replacement in replacements:
        matches = re.findall(pattern, content)
        if matches:
            content = re.sub(pattern, replacement, content)
            count += len(matches)
    
    # draw = DrawHelper(SCREEN) 가 있는지 확인
    if 'draw = DrawHelper(SCREEN)' not in content:
        print("⚠️ DrawHelper가 초기화되지 않았습니다!")
        return
    
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✅ {count}개의 pygame.draw 호출을 DrawHelper로 교체했습니다!")
    return count

if __name__ == "__main__":
    replace_pygame_draw()