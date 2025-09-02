#!/usr/bin/env python3
"""
Phase 4-2: pygame.draw 호출을 DrawHelper로 통합
반복되는 색상 상수화
"""

import re
import os

def add_color_constants(content):
    """자주 사용되는 색상을 상수로 정의"""
    lines_before = content.count('\n')
    
    # 색상 상수 추가
    color_constants = '''
# === 추가 색상 상수 ===
COLOR_GOLD = (255, 215, 0)
COLOR_LIGHT_BLUE = (100, 150, 255)
COLOR_LIGHT_GRAY2 = (200, 200, 200)
COLOR_MID_GRAY = (150, 150, 150)
COLOR_DARK_GRAY2 = (100, 100, 100)
COLOR_LIGHT_RED = (255, 100, 100)
COLOR_LIGHT_YELLOW = (255, 255, 100)
'''
    
    # 색상 상수가 아직 없다면 추가
    if 'COLOR_GOLD' not in content:
        insert_pos = content.find('# === 색상 상수 ===')
        if insert_pos > 0:
            # 다음 섹션 찾기
            next_section = content.find('\n# ===', insert_pos + 10)
            if next_section > 0:
                content = content[:next_section] + color_constants + content[next_section:]
        else:
            # DrawHelper 클래스 앞에 추가
            insert_pos = content.find('class DrawHelper:')
            if insert_pos > 0:
                content = content[:insert_pos] + color_constants + '\n' + content[insert_pos:]
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def convert_pygame_draw_to_helper(content):
    """pygame.draw 호출을 DrawHelper로 변환"""
    lines_before = content.count('\n')
    
    # 변환 패턴들
    replacements = [
        # pygame.draw.circle(SCREEN, ...) -> draw.circle(...)
        (r'pygame\.draw\.circle\(SCREEN,\s*', 'draw.circle('),
        # pygame.draw.rect(SCREEN, ...) -> draw.rect(...)
        (r'pygame\.draw\.rect\(SCREEN,\s*', 'draw.rect('),
        # pygame.draw.line(SCREEN, ...) -> draw.line(...)
        (r'pygame\.draw\.line\(SCREEN,\s*', 'draw.line('),
        # pygame.draw.polygon(SCREEN, ...) -> draw.polygon(...)
        (r'pygame\.draw\.polygon\(SCREEN,\s*', 'draw.polygon('),
        # pygame.draw.lines(SCREEN, ...) -> draw.lines(...)
        (r'pygame\.draw\.lines\(SCREEN,\s*', 'draw.lines('),
    ]
    
    for pattern, replacement in replacements:
        content = re.sub(pattern, replacement, content)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def replace_color_tuples(content):
    """색상 튜플을 상수로 교체"""
    lines_before = content.count('\n')
    
    # 색상 교체 매핑
    color_replacements = [
        (r'\(255,\s*215,\s*0\)', 'COLOR_GOLD'),
        (r'\(100,\s*150,\s*255\)', 'COLOR_LIGHT_BLUE'),
        (r'\(200,\s*200,\s*200\)', 'COLOR_LIGHT_GRAY2'),
        (r'\(150,\s*150,\s*150\)', 'COLOR_MID_GRAY'),
        (r'\(100,\s*100,\s*100\)', 'COLOR_DARK_GRAY2'),
        (r'\(255,\s*100,\s*100\)', 'COLOR_LIGHT_RED'),
        (r'\(255,\s*255,\s*100\)', 'COLOR_LIGHT_YELLOW'),
    ]
    
    # 색상 정의 부분은 건드리지 않기 위해 함수 내부만 처리
    lines = content.split('\n')
    in_function = False
    new_lines = []
    
    for line in lines:
        # 함수 시작
        if re.match(r'^def\s+', line):
            in_function = True
        # 함수 끝 (들여쓰기가 없는 다음 라인)
        elif in_function and line and line[0] not in ' \t' and not line.startswith('#'):
            in_function = False
        
        # 함수 내부에서만 색상 교체
        if in_function and 'COLOR_' not in line:  # 이미 상수화된 것은 건드리지 않음
            for pattern, replacement in color_replacements:
                line = re.sub(pattern, replacement, line)
        
        new_lines.append(line)
    
    content = '\n'.join(new_lines)
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase4_2.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    total_changes = 0
    
    print("\n🔧 Phase 4-2: 반복 코드 패턴 통합...")
    
    # 1. 색상 상수 추가
    print("\n1️⃣ 색상 상수 추가...")
    content, lines_changed = add_color_constants(content)
    total_changes += abs(lines_changed)
    print(f"   ✅ {abs(lines_changed)}줄 추가")
    
    # 2. pygame.draw -> DrawHelper 변환
    print("\n2️⃣ pygame.draw → DrawHelper 변환...")
    content, lines_changed = convert_pygame_draw_to_helper(content)
    total_changes += abs(lines_changed)
    print(f"   ✅ {abs(lines_changed)}개 호출 변환")
    
    # 3. 색상 튜플 -> 상수 교체
    print("\n3️⃣ 색상 튜플 → 상수 교체...")
    content, lines_changed = replace_color_tuples(content)
    total_changes += abs(lines_changed)
    print(f"   ✅ {abs(lines_changed)}개 색상 교체")
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 4-2 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   변경: {original_lines - final_lines:,}줄 감소")
    print("="*50)

if __name__ == "__main__":
    main()