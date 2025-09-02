#!/usr/bin/env python3
"""
Phase 1 종합 리팩토링 스크립트
- try-except 블록 통합
- 중복 draw 함수 통합
- 빈 함수 제거
"""

import re
import os

def consolidate_try_except_blocks(content):
    """try-except 블록을 safe_loader로 통합"""
    changes = 0
    lines_before = content.count('\n')
    
    # 1. 이미지 로드 패턴
    patterns = [
        # 이미지 로드 + 스케일
        (r'try:\s*\n\s+(\w+)\s*=\s*pygame\.image\.load\("([^"]+)"\)\.convert(_alpha)?\(\)\s*\n\s+\1\s*=\s*pygame\.transform\.scale\(\1,\s*\(([^)]+)\)\)[^\n]*\nexcept[^:]+:\s*\n(?:[^\n]+\n)*?\s+\1\s*=\s*pygame\.Surface\(\(([^)]+)\)\)',
         r'\1 = safe_loader.safe_load_image("\2", (\5))\n\1 = safe_loader.safe_scale_image(\1, (\4))'),
        
        # 단순 이미지 로드
        (r'try:\s*\n\s+(\w+)\s*=\s*pygame\.image\.load\("([^"]+)"\)\.convert(_alpha)?\(\)[^\n]*\nexcept[^:]+:\s*\n(?:[^\n]+\n)*?\s+\1\s*=\s*pygame\.Surface\(\(([^)]+)\)\)',
         r'\1 = safe_loader.safe_load_image("\2", (\4))'),
        
        # 사운드 로드
        (r'try:\s*\n\s+(\w+)\s*=\s*pygame\.mixer\.Sound\("([^"]+)"\)[^\n]*\n(?:\s+\1\.set_volume\(([^)]+)\)[^\n]*\n)?except[^:]+:\s*\n(?:[^\n]+\n)*?\s+\1\s*=\s*None',
         r'\1 = safe_loader.safe_load_sound("\2")'),
        
        # 폰트 로드
        (r'try:\s*\n\s+(\w+)\s*=\s*pygame\.font\.Font\("([^"]+)",\s*(\d+)\)[^\n]*\nexcept[^:]+:\s*\n(?:[^\n]+\n)*?\s+\1\s*=\s*pygame\.font\.SysFont\("([^"]+)",\s*\d+\)',
         r'\1 = safe_loader.safe_load_font("\2", \3)')
    ]
    
    for pattern, replacement in patterns:
        matches = list(re.finditer(pattern, content))
        changes += len(matches)
        content = re.sub(pattern, replacement, content)
    
    lines_after = content.count('\n')
    return content, changes, lines_before - lines_after

def consolidate_draw_functions(content):
    """중복된 draw 함수들을 통합"""
    changes = 0
    lines_before = content.count('\n')
    
    # draw_particles 유사 함수들 통합
    particle_patterns = [
        (r'def draw_(\w+)_particles\(\):\s*\n(?:\s+"""[^"]*"""\s*\n)?(?:\s+global [^\n]+\n)*\s+for particle in \w+:\s*\n(?:\s+[^\n]+\n){1,15}\s+pygame\.draw\.circle\([^)]+\)',
         'effect_renderer.draw_particles'),
        
        (r'def draw_(\w+)_effect\(\):\s*\n(?:\s+"""[^"]*"""\s*\n)?(?:\s+[^\n]+\n){1,20}',
         'effect_renderer.draw_effect')
    ]
    
    for pattern, replacement in particle_patterns:
        matches = list(re.finditer(pattern, content))
        if matches:
            changes += len(matches)
            # 함수 호출부분만 대체
            for match in matches:
                func_name = match.group(1) if match.groups() else ''
                old_call = f'draw_{func_name}_particles()'
                new_call = f'effect_renderer.draw_particles({func_name}_particles)'
                content = content.replace(old_call, new_call)
            
            # 함수 정의 제거
            content = re.sub(pattern, '', content)
    
    lines_after = content.count('\n')
    return content, changes, lines_before - lines_after

def remove_empty_functions(content):
    """빈 함수 및 미사용 코드 제거"""
    changes = 0
    lines_before = content.count('\n')
    
    # 빈 함수 패턴
    empty_patterns = [
        r'def \w+\([^)]*\):\s*\n\s+pass\s*\n',
        r'def \w+\([^)]*\):\s*\n\s+"""[^"]*"""\s*\n\s+pass\s*\n',
        r'def \w+\([^)]*\):\s*\n\s+return\s*\n',
    ]
    
    for pattern in empty_patterns:
        matches = list(re.finditer(pattern, content))
        changes += len(matches)
        content = re.sub(pattern, '', content)
    
    # 연속된 빈 줄 제거 (3줄 이상)
    content = re.sub(r'\n\n\n+', '\n\n', content)
    
    lines_after = content.count('\n')
    return content, changes, lines_before - lines_after

def add_imports_if_needed(content):
    """필요한 import 추가"""
    imports_to_add = []
    
    if 'safe_loader' in content and 'from utils import safe_loader' not in content:
        imports_to_add.append('from utils import safe_loader')
    
    if 'effect_renderer' in content and 'from utils.effect_renderer import EffectRenderer' not in content:
        imports_to_add.append('from utils.effect_renderer import EffectRenderer')
        imports_to_add.append('effect_renderer = EffectRenderer()')
    
    if imports_to_add:
        # pygame import 다음에 추가
        pygame_match = re.search(r'(import pygame\n)', content)
        if pygame_match:
            insert_pos = pygame_match.end()
            import_text = '\n'.join(imports_to_add) + '\n'
            content = content[:insert_pos] + import_text + content[insert_pos:]
    
    return content

def main():
    """메인 리팩토링 실행"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase1.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    total_changes = 0
    total_lines_saved = 0
    
    print("\n🔧 Phase 1 리팩토링 시작...")
    
    # 1. try-except 블록 통합
    print("\n1️⃣ try-except 블록 통합...")
    content, changes, lines_saved = consolidate_try_except_blocks(content)
    total_changes += changes
    total_lines_saved += lines_saved
    print(f"   ✅ {changes}개 블록 통합, {lines_saved}줄 감소")
    
    # 2. 중복 draw 함수 통합
    print("\n2️⃣ 중복 draw 함수 통합...")
    content, changes, lines_saved = consolidate_draw_functions(content)
    total_changes += changes
    total_lines_saved += lines_saved
    print(f"   ✅ {changes}개 함수 통합, {lines_saved}줄 감소")
    
    # 3. 빈 함수 제거
    print("\n3️⃣ 빈 함수 및 미사용 코드 제거...")
    content, changes, lines_saved = remove_empty_functions(content)
    total_changes += changes
    total_lines_saved += lines_saved
    print(f"   ✅ {changes}개 항목 제거, {lines_saved}줄 감소")
    
    # 4. 필요한 import 추가
    content = add_imports_if_needed(content)
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 1 리팩토링 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   감소: {original_lines - final_lines:,}줄 ({(original_lines - final_lines) / original_lines * 100:.1f}%)")
    print(f"   변경: {total_changes}개 항목")
    print("="*50)

if __name__ == "__main__":
    main()