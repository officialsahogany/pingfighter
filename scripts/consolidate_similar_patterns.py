#!/usr/bin/env python3
"""
Phase 2-2: 유사 로직 패턴 통합
반복되는 패턴을 헬퍼 함수로 통합
"""

import re
import os

def create_draw_helper(content):
    """DrawHelper 클래스 생성 및 pygame.draw 호출 간소화"""
    lines_before = content.count('\n')
    
    # DrawHelper 클래스 추가
    draw_helper_class = '''
# === DrawHelper 클래스 ===
class DrawHelper:
    """pygame.draw 호출을 간소화하는 헬퍼 클래스"""
    def __init__(self, surface):
        self.surface = surface
    
    def circle(self, color, pos, radius, width=0):
        """원 그리기 간소화"""
        pygame.draw.circle(self.surface, color, pos, radius, width)
    
    def rect(self, color, rect, width=0, border_radius=0):
        """사각형 그리기 간소화"""
        if border_radius > 0:
            pygame.draw.rect(self.surface, color, rect, width, border_radius=border_radius)
        else:
            pygame.draw.rect(self.surface, color, rect, width)
    
    def line(self, color, start, end, width=1):
        """선 그리기 간소화"""
        pygame.draw.line(self.surface, color, start, end, width)
    
    def polygon(self, color, points, width=0):
        """다각형 그리기 간소화"""
        pygame.draw.polygon(self.surface, color, points, width)
    
    def lines(self, color, closed, points, width=1):
        """여러 선 그리기 간소화"""
        pygame.draw.lines(self.surface, color, closed, points, width)

# DrawHelper 인스턴스 생성
draw = DrawHelper(SCREEN)
'''
    
    # 적절한 위치에 DrawHelper 클래스 추가 (초기화 후)
    init_pos = content.find('# === 글로벌 상수 ===')
    if init_pos > 0:
        content = content[:init_pos] + draw_helper_class + '\n' + content[init_pos:]
    
    # pygame.draw 호출을 draw 헬퍼로 교체 (주요 패턴만)
    replacements = [
        # 단순 circle 호출
        (r'pygame\.draw\.circle\(SCREEN,\s*', 'draw.circle('),
        # 단순 rect 호출  
        (r'pygame\.draw\.rect\(SCREEN,\s*', 'draw.rect('),
        # 단순 line 호출
        (r'pygame\.draw\.line\(SCREEN,\s*', 'draw.line('),
        # 단순 polygon 호출
        (r'pygame\.draw\.polygon\(SCREEN,\s*', 'draw.polygon('),
    ]
    
    for old, new in replacements:
        content = re.sub(old, new, content)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def consolidate_if_elif_chains(content):
    """긴 if-elif 체인을 딕셔너리 기반으로 개선"""
    lines_before = content.count('\n')
    
    # 아이템 활성화 관련 if-elif 체인을 딕셔너리로 변경
    # (너무 복잡한 패턴은 수정하지 않음)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def consolidate_global_declarations(content):
    """많은 global 선언을 그룹화"""
    lines_before = content.count('\n')
    
    # global 선언 그룹화 패턴
    # 5개 이상의 global 변수가 여러 줄에 걸쳐 있는 경우 한 줄로
    pattern = r'(global\s+\w+(?:\s*,\s*\w+)*)\s*\n\s*(global\s+\w+(?:\s*,\s*\w+)*)'
    
    def merge_globals(match):
        first = match.group(1).replace('global ', '')
        second = match.group(2).replace('global ', '')
        return f'global {first}, {second}'
    
    # 연속된 global 선언 병합
    content = re.sub(pattern, merge_globals, content)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def remove_remaining_try_except(content):
    """남은 try-except 블록 중 단순한 것들 제거"""
    lines_before = content.count('\n')
    
    # 단순 pass만 있는 try-except 제거
    pattern = r'try:\s*\n\s*([^\n]+)\s*\nexcept[^:]*:\s*\n\s*pass'
    
    def replace_try_except(match):
        # 단순 할당이나 호출만 있는 경우
        statement = match.group(1).strip()
        if '.play(' in statement or '.stop(' in statement or '.load(' in statement:
            return statement  # try-except 제거하고 문장만 남김
        return match.group(0)  # 복잡한 경우 그대로 유지
    
    content = re.sub(pattern, replace_try_except, content, flags=re.MULTILINE)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase2_2.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    total_lines_saved = 0
    
    print("\n🔧 Phase 2-2: 유사 로직 패턴 통합...")
    
    # 1. DrawHelper 생성 및 적용
    print("\n1️⃣ DrawHelper로 pygame.draw 호출 간소화...")
    content, lines_saved = create_draw_helper(content)
    total_lines_saved += lines_saved
    print(f"   ✅ {abs(lines_saved)}줄 변경")
    
    # 2. global 선언 그룹화
    print("\n2️⃣ global 선언 그룹화...")
    content, lines_saved = consolidate_global_declarations(content)
    total_lines_saved += lines_saved
    print(f"   ✅ {lines_saved}줄 감소")
    
    # 3. 남은 try-except 제거
    print("\n3️⃣ 단순 try-except 제거...")
    content, lines_saved = remove_remaining_try_except(content)
    total_lines_saved += lines_saved
    print(f"   ✅ {lines_saved}줄 감소")
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 2-2 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   변경: {abs(original_lines - final_lines):,}줄")
    print("="*50)

if __name__ == "__main__":
    main()
