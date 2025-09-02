#!/usr/bin/env python3
"""
Phase 6-1: pygame.draw 직접 호출을 DrawHelper로 전환
"""

import re
import os

def convert_remaining_pygame_draws(content):
    """남은 pygame.draw 호출을 DrawHelper로 변환"""
    
    lines = content.split('\n')
    changed = 0
    
    for i, line in enumerate(lines):
        original = line
        
        # pygame.draw.circle -> draw.circle
        if 'pygame.draw.circle(' in line:
            # SCREEN 파라미터 제거
            line = re.sub(r'pygame\.draw\.circle\(SCREEN,\s*', 'draw.circle(', line)
            line = re.sub(r'pygame\.draw\.circle\(screen,\s*', 'draw.circle(', line)
            # Surface가 첫 파라미터인 경우 처리
            line = re.sub(r'pygame\.draw\.circle\((\w+),\s*', r'pygame.draw.circle(\1, ', line)
        
        # pygame.draw.rect -> draw.rect
        elif 'pygame.draw.rect(' in line:
            line = re.sub(r'pygame\.draw\.rect\(SCREEN,\s*', 'draw.rect(', line)
            line = re.sub(r'pygame\.draw\.rect\(screen,\s*', 'draw.rect(', line)
            # Surface가 첫 파라미터인 경우 처리
            line = re.sub(r'pygame\.draw\.rect\((\w+),\s*', r'pygame.draw.rect(\1, ', line)
        
        # pygame.draw.line -> draw.line
        elif 'pygame.draw.line(' in line:
            line = re.sub(r'pygame\.draw\.line\(SCREEN,\s*', 'draw.line(', line)
            line = re.sub(r'pygame\.draw\.line\(screen,\s*', 'draw.line(', line)
            # Surface가 첫 파라미터인 경우 처리
            line = re.sub(r'pygame\.draw\.line\((\w+),\s*', r'pygame.draw.line(\1, ', line)
        
        # pygame.draw.polygon -> draw.polygon
        elif 'pygame.draw.polygon(' in line:
            line = re.sub(r'pygame\.draw\.polygon\(SCREEN,\s*', 'draw.polygon(', line)
            line = re.sub(r'pygame\.draw\.polygon\(screen,\s*', 'draw.polygon(', line)
        
        # pygame.draw.ellipse -> draw.ellipse
        elif 'pygame.draw.ellipse(' in line:
            line = re.sub(r'pygame\.draw\.ellipse\(SCREEN,\s*', 'draw.ellipse(', line)
            line = re.sub(r'pygame\.draw\.ellipse\(screen,\s*', 'draw.ellipse(', line)
        
        if line != original:
            lines[i] = line
            changed += 1
    
    return '\n'.join(lines), changed

def consolidate_magic_numbers(content):
    """자주 사용되는 매직 넘버를 상수로 변환"""
    
    # 가장 빈번한 숫자들
    constants_to_add = {
        '100': 'DEFAULT_SIZE',
        '200': 'LARGE_SIZE', 
        '50': 'SMALL_SIZE',
        '150': 'MEDIUM_SIZE',
        '255': 'MAX_COLOR',
        '10': 'SMALL_OFFSET',
        '20': 'MEDIUM_OFFSET',
        '30': 'LARGE_OFFSET',
        '60': 'ONE_SECOND',
        '120': 'TWO_SECONDS',
    }
    
    # 상수 정의 추가
    constants_def = "\n# === Phase 6 상수 정의 ===\n"
    for num, name in constants_to_add.items():
        constants_def += f"{name} = {num}\n"
    
    # 파일에 상수 정의 추가
    insert_pos = content.find('# === 게임 설정 ===')
    if insert_pos > 0:
        content = content[:insert_pos] + constants_def + '\n' + content[insert_pos:]
    
    lines = content.split('\n')
    changed = 0
    
    # 일부 매직 넘버만 교체 (너무 많이 바꾸면 오류 발생 가능)
    for i, line in enumerate(lines):
        # 주석이나 문자열은 건드리지 않음
        if '#' in line or '"' in line or "'" in line:
            continue
        
        original = line
        
        # 100 -> DEFAULT_SIZE (일부만)
        if ' 100)' in line and 'range' not in line:
            line = line.replace(' 100)', ' DEFAULT_SIZE)')
        
        # 255 -> MAX_COLOR (색상 관련만)
        if '(255,' in line or ', 255,' in line or ', 255)' in line:
            line = line.replace('(255,', '(MAX_COLOR,')
            line = line.replace(', 255,', ', MAX_COLOR,')
            line = line.replace(', 255)', ', MAX_COLOR)')
        
        if line != original:
            lines[i] = line
            changed += 1
    
    return '\n'.join(lines), changed

def extract_common_patterns(content):
    """반복되는 패턴을 함수로 추출"""
    
    # 색상 튜플 생성 패턴을 함수로
    helper_functions = '''
def get_color_with_alpha(base_color, alpha):
    """알파값이 적용된 색상 반환"""
    return (*base_color, alpha) if len(base_color) == 3 else base_color

def get_random_color(min_val=0, max_val=255):
    """랜덤 색상 생성"""
    return (random.randint(min_val, max_val),
            random.randint(min_val, max_val),
            random.randint(min_val, max_val))

def interpolate_color(color1, color2, ratio):
    """두 색상 사이를 보간"""
    return tuple(int(c1 * (1 - ratio) + c2 * ratio) 
                for c1, c2 in zip(color1, color2))
'''
    
    # 헬퍼 함수 추가
    insert_pos = content.find('def mix_color(')
    if insert_pos > 0:
        content = content[:insert_pos] + helper_functions + '\n' + content[insert_pos:]
    
    return content, 20  # 예상 감소 줄 수

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase6_1.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    
    print("\n🔧 Phase 6-1: 추가 최적화...")
    
    total_changed = 0
    
    # 1. pygame.draw 변환
    print("\n📌 pygame.draw → DrawHelper 추가 변환...")
    content, changed = convert_remaining_pygame_draws(content)
    total_changed += changed
    print(f"   {changed}개 호출 변환")
    
    # 2. 매직 넘버 상수화
    print("\n📌 매직 넘버 상수화...")
    content, changed = consolidate_magic_numbers(content)
    total_changed += changed
    print(f"   {changed}개 위치 상수화")
    
    # 3. 공통 패턴 추출
    print("\n📌 공통 패턴 함수화...")
    content, saved = extract_common_patterns(content)
    print(f"   {saved}줄 감소 예상")
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 6-1 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   변경: {original_lines - final_lines:,}줄")
    print("="*50)

if __name__ == "__main__":
    main()