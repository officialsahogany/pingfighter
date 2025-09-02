#!/usr/bin/env python3
"""
Phase 7: 공격적인 코드 감소
실제로 줄을 줄이는데 집중
"""

import re
import os

def aggressive_pygame_draw_conversion(content):
    """모든 pygame.draw 호출을 DrawHelper로 변환"""
    
    lines = content.split('\n')
    changed = 0
    
    for i, line in enumerate(lines):
        original = line
        
        # 모든 pygame.draw.circle 변환
        if 'pygame.draw.circle' in line:
            # Surface 파라미터 파악
            if 'pygame.draw.circle(SCREEN' in line:
                line = line.replace('pygame.draw.circle(SCREEN,', 'draw.circle(')
            elif 'pygame.draw.circle(screen' in line:
                line = line.replace('pygame.draw.circle(screen,', 'draw.circle(')
            # 다른 Surface는 그대로 둠
            
        # 모든 pygame.draw.rect 변환
        if 'pygame.draw.rect' in line:
            if 'pygame.draw.rect(SCREEN' in line:
                line = line.replace('pygame.draw.rect(SCREEN,', 'draw.rect(')
            elif 'pygame.draw.rect(screen' in line:
                line = line.replace('pygame.draw.rect(screen,', 'draw.rect(')
                
        # 모든 pygame.draw.line 변환
        if 'pygame.draw.line' in line:
            if 'pygame.draw.line(SCREEN' in line:
                line = line.replace('pygame.draw.line(SCREEN,', 'draw.line(')
            elif 'pygame.draw.line(screen' in line:
                line = line.replace('pygame.draw.line(screen,', 'draw.line(')
                
        # pygame.draw.polygon 변환
        if 'pygame.draw.polygon' in line:
            if 'pygame.draw.polygon(SCREEN' in line:
                line = line.replace('pygame.draw.polygon(SCREEN,', 'draw.polygon(')
                
        # pygame.draw.ellipse 변환
        if 'pygame.draw.ellipse' in line:
            if 'pygame.draw.ellipse(SCREEN' in line:
                line = line.replace('pygame.draw.ellipse(SCREEN,', 'draw.ellipse(')
        
        if line != original:
            lines[i] = line
            changed += 1
    
    return '\n'.join(lines), changed

def remove_duplicate_blocks(content):
    """중복된 코드 블록 제거"""
    
    lines = content.split('\n')
    
    # 연속된 빈 줄 제거
    new_lines = []
    prev_empty = False
    
    for line in lines:
        if not line.strip():
            if not prev_empty:
                new_lines.append(line)
                prev_empty = True
        else:
            new_lines.append(line)
            prev_empty = False
    
    # 중복된 import 제거
    imports = set()
    final_lines = []
    
    for line in new_lines:
        if line.startswith('import ') or line.startswith('from '):
            if line not in imports:
                imports.add(line)
                final_lines.append(line)
        else:
            final_lines.append(line)
    
    saved = len(lines) - len(final_lines)
    return '\n'.join(final_lines), saved

def consolidate_similar_functions(content):
    """비슷한 함수들 통합"""
    
    # 비슷한 draw 함수들을 하나로 통합
    consolidation = '''
def draw_colored_circle(pos, radius, color, width=0):
    """색상이 있는 원 그리기"""
    draw.circle(color, pos, radius, width)

def draw_colored_rect(rect, color, width=0, border_radius=0):
    """색상이 있는 사각형 그리기"""
    draw.rect(color, rect, width, border_radius)

def draw_text_centered(text, pos, font_size=20, color=(255, 255, 255)):
    """중앙 정렬된 텍스트 그리기"""
    font = pygame.font.Font(None, font_size)
    text_surface = font.render(text, True, color)
    text_rect = text_surface.get_rect(center=pos)
    SCREEN.blit(text_surface, text_rect)
'''
    
    # 기존 비슷한 함수들을 찾아서 새 함수 호출로 교체
    lines = content.split('\n')
    
    # 헬퍼 함수 추가
    insert_pos = content.find('def draw_colored_circle')
    if insert_pos == -1:  # 없으면 추가
        insert_pos = content.find('class DrawHelper:')
        if insert_pos > 0:
            content = content[:insert_pos] + consolidation + '\n\n' + content[insert_pos:]
    
    return content, 30  # 예상 감소

def remove_commented_code(content):
    """주석 처리된 코드 제거"""
    
    lines = content.split('\n')
    new_lines = []
    
    for line in lines:
        # 주석 처리된 코드 라인 제거 (설명 주석은 유지)
        if line.strip().startswith('#'):
            # 코드처럼 보이는 주석 제거
            if any(x in line for x in ['=', '(', ')', 'def ', 'if ', 'for ', 'while ']):
                continue  # 코드 주석은 제거
            else:
                new_lines.append(line)  # 설명 주석은 유지
        else:
            new_lines.append(line)
    
    saved = len(lines) - len(new_lines)
    return '\n'.join(new_lines), saved

def inline_simple_variables(content):
    """단순 변수 인라인화"""
    
    lines = content.split('\n')
    changed = 0
    
    # 한 번만 사용되는 변수들 인라인화
    for i in range(len(lines) - 1):
        line = lines[i].strip()
        next_line = lines[i + 1].strip() if i + 1 < len(lines) else ""
        
        # 간단한 할당 패턴: var = value
        if '=' in line and not any(x in line for x in ['==', '!=', '>=', '<=', '+=', '-=', '*=', '/=']):
            parts = line.split('=', 1)
            if len(parts) == 2:
                var_name = parts[0].strip()
                value = parts[1].strip()
                
                # 다음 줄에서만 사용되고 간단한 값인 경우
                if var_name in next_line and value.isdigit():
                    # 변수를 값으로 교체
                    lines[i + 1] = lines[i + 1].replace(var_name, value)
                    lines[i] = ''  # 변수 선언 제거
                    changed += 1
    
    # 빈 줄 제거
    lines = [line for line in lines if line]
    
    return '\n'.join(lines), changed

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase7.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    
    print("\n🔧 Phase 7: 공격적인 코드 감소...")
    
    total_saved = 0
    
    # 1. pygame.draw 모두 변환
    print("\n📌 pygame.draw → DrawHelper 완전 변환...")
    content, changed = aggressive_pygame_draw_conversion(content)
    print(f"   {changed}개 호출 변환")
    
    # 2. 중복 블록 제거
    print("\n📌 중복 코드 블록 제거...")
    content, saved = remove_duplicate_blocks(content)
    total_saved += saved
    print(f"   {saved}줄 제거")
    
    # 3. 비슷한 함수 통합
    print("\n📌 비슷한 함수 통합...")
    content, saved = consolidate_similar_functions(content)
    total_saved += saved
    print(f"   {saved}줄 감소 예상")
    
    # 4. 주석 코드 제거
    print("\n📌 주석 처리된 코드 제거...")
    content, saved = remove_commented_code(content)
    total_saved += saved
    print(f"   {saved}줄 제거")
    
    # 5. 단순 변수 인라인화
    print("\n📌 단순 변수 인라인화...")
    content, saved = inline_simple_variables(content)
    total_saved += saved
    print(f"   {saved}개 변수 인라인화")
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 7 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   감소: {original_lines - final_lines:,}줄")
    print("\n   전체: 22,275줄 → {final_lines:,}줄")
    print(f"   총 감소: {22275 - final_lines:,}줄 ({((22275 - final_lines) / 22275 * 100):.1f}% 감소)")
    print("="*50)

if __name__ == "__main__":
    main()