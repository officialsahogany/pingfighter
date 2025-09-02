#!/usr/bin/env python3
"""
DrawHelper 호출 버그 수정
surface를 첫번째 인자로 전달하는 잘못된 호출들을 수정
"""

import re

def fix_draw_calls():
    with open('../bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # draw.circle( 형태의 잘못된 호출을 pygame.draw.circle로 수정
    # surface를 첫번째 인자로 받는 경우를 감지
    patterns = [
        # draw.circle( 로 시작하는 패턴 (surface 포함)
        (r'draw\.circle\(\s*\(', 'pygame.draw.circle('),
        # draw.rect( 로 시작하는 패턴 (surface 포함) 
        (r'draw\.rect\(\s*\(', 'pygame.draw.rect('),
    ]
    
    for pattern, replacement in patterns:
        # 먼저 패턴 찾기
        matches = re.findall(pattern, content)
        if matches:
            print(f"Found {len(matches)} occurrences of pattern: {pattern}")
    
    # 실제로는 더 정교한 수정이 필요
    # draw.circle( (color_tuple), ... ) 형태를 찾아서 수정
    
    # surface가 명시적으로 있는 경우 찾기
    lines = content.split('\n')
    fixed_lines = []
    
    for i, line in enumerate(lines):
        # draw.circle( (숫자로 시작하는 튜플) 패턴 찾기
        if 'draw.circle(' in line:
            # 첫번째 인자가 색상 튜플인지 확인
            match = re.search(r'draw\.circle\(\s*\((\d+|MAX_COLOR|COLOR_\d+)', line)
            if match:
                # surface를 추가해야 하는 경우
                # 어떤 surface를 사용하는지 파악
                if 'surface' in line.lower() or '_surf' in line.lower():
                    # 특정 surface가 있는 경우 그대로 pygame.draw로 변경
                    line = line.replace('draw.circle(', 'pygame.draw.circle(')
                else:
                    # SCREEN을 사용하는 경우
                    # draw.circle(color, pos, radius) -> draw.circle(color, pos, radius)는 그대로
                    # 하지만 잘못된 호출은 수정 필요
                    pass
        
        # draw.line도 비슷한 문제가 있을 수 있음
        if 'draw.line(' in line and '(' in line[line.index('draw.line('):]:
            # 첫번째 인자가 색상 튜플인지 확인
            match = re.search(r'draw\.line\(\s*\((\d+|MAX_COLOR|COLOR_\d+)', line)
            if match:
                # SCREEN을 사용하는 경우는 그대로 두기
                pass
        
        fixed_lines.append(line)
    
    # 특별히 문제가 되는 부분들을 직접 수정
    content = '\n'.join(fixed_lines)
    
    # 잘못된 draw.circle( 호출 수정
    # draw.circle( (color), pos, radius) 형태는 괜찮지만
    # surface가 포함된 경우만 수정
    
    replacements = [
        # 특정 surface에 그리는 경우들
        (r'draw\.circle\(\s*\(', 'pygame.draw.circle(SCREEN, ('),
        (r'draw\.rect\(\s*\(', 'pygame.draw.rect(SCREEN, ('),
    ]
    
    # 백업 생성
    with open('../bosspong_before_draw_fix.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    # 수정 적용
    fix_count = 0
    
    # 잘못된 호출만 찾아서 수정
    # draw.circle( (color_tuple), ...) 형태를 찾기
    pattern = r'draw\.circle\(\s*\('
    matches = list(re.finditer(pattern, content))
    
    print(f"\nFound {len(matches)} potential issues with draw.circle calls")
    
    # 뒤에서부터 수정 (인덱스가 변하지 않도록)
    for match in reversed(matches):
        start = match.start()
        # 해당 라인 찾기
        line_start = content.rfind('\n', 0, start) + 1
        line_end = content.find('\n', start)
        if line_end == -1:
            line_end = len(content)
        
        line = content[line_start:line_end]
        
        # surface 변수가 있는지 확인
        if '_surface' in line or '_surf' in line:
            # surface 변수 찾기
            surface_match = re.search(r'(\w+_surf(?:ace)?)', line[:start-line_start])
            if surface_match:
                surface_name = surface_match.group(1)
            else:
                surface_name = 'SCREEN'
            
            # draw.circle( ( -> pygame.draw.circle(surface, (
            old_call = 'draw.circle( ('
            new_call = f'pygame.draw.circle({surface_name}, ('
            
            # 해당 부분만 교체
            before = content[:start]
            after = content[start+len('draw.circle('):]
            # 공백 처리
            if after.startswith(' ('):
                after = after[1:]  # 공백 제거
            
            content = before + f'pygame.draw.circle({surface_name}, ' + after
            fix_count += 1
    
    # 파일 쓰기
    with open('../bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✅ Fixed {fix_count} draw.circle calls")
    
    return fix_count

if __name__ == "__main__":
    print("=== Fixing DrawHelper Calls ===")
    total_fixes = fix_draw_calls()
    print(f"\n✅ Total fixes: {total_fixes}")
