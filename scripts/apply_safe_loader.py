#!/usr/bin/env python3
"""
safe_loader 유틸리티를 적용하여 try-except 블록을 통합하는 스크립트
"""

import re
import os

def apply_safe_loader_to_file(filepath):
    """파일에서 try-except 블록을 safe_loader로 대체"""
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    replacements = []
    
    # 1. pygame.image.load try-except 패턴 대체
    image_pattern = r'try:\s*\n\s+(\w+)\s*=\s*pygame\.image\.load\(([^)]+)\)\.convert(_alpha)?\(\)\s*\n\s+(\w+)\s*=\s*pygame\.transform\.scale\((\w+),\s*([^)]+)\)\s*\nexcept[^:]+:\s*\n(?:\s+.*\n)*?\s+(\w+)\s*=\s*pygame\.Surface\(([^)]+)\)(?:\.convert_alpha\(\))?'
    
    def replace_image_load(match):
        var_name = match.group(1)
        path = match.group(2)
        alpha = match.group(3) or ""
        scale_size = match.group(5)
        default_size = match.group(7)
        
        replacements.append(f"Image load: {var_name}")
        
        if alpha:
            return f'{var_name} = safe_loader.safe_load_image({path}, {default_size})\n{var_name} = safe_loader.safe_scale_image({var_name}, {scale_size})'
        else:
            return f'{var_name} = safe_loader.safe_load_image({path}, {default_size})\n{var_name} = safe_loader.safe_scale_image({var_name}, {scale_size})'
    
    # 2. 간단한 pygame.image.load try-except 패턴
    simple_image_pattern = r'try:\s*\n\s+(\w+)\s*=\s*pygame\.image\.load\(([^)]+)\)\.convert(_alpha)?\(\)[^\n]*\nexcept[^:]+:\s*\n(?:\s+.*\n)*?\s+(\w+)\s*=\s*pygame\.Surface\(([^)]+)\)'
    
    def replace_simple_image(match):
        var_name = match.group(1)
        path = match.group(2)
        default_size = match.group(5)
        
        replacements.append(f"Simple image: {var_name}")
        return f'{var_name} = safe_loader.safe_load_image({path}, {default_size})'
    
    # 3. pygame.mixer.Sound try-except 패턴
    sound_pattern = r'try:\s*\n\s+(\w+)\s*=\s*pygame\.mixer\.Sound\(([^)]+)\)[^\n]*\n(?:\s+\w+\.set_volume\([^)]+\)[^\n]*\n)?except[^:]+:\s*\n(?:\s+.*\n)*?\s+(\w+)\s*=\s*None'
    
    def replace_sound_load(match):
        var_name = match.group(1)
        path = match.group(2)
        
        replacements.append(f"Sound: {var_name}")
        return f'{var_name} = safe_loader.safe_load_sound({path})'
    
    # 4. pygame.font.Font try-except 패턴
    font_pattern = r'try:\s*\n\s+(\w+)\s*=\s*pygame\.font\.Font\(([^,]+),\s*([^)]+)\)[^\n]*\nexcept[^:]+:\s*\n(?:\s+.*\n)*?\s+(\w+)\s*=\s*pygame\.font\.SysFont\(([^,]+),\s*([^)]+)\)'
    
    def replace_font_load(match):
        var_name = match.group(1)
        path = match.group(2)
        size = match.group(3)
        
        replacements.append(f"Font: {var_name}")
        return f'{var_name} = safe_loader.safe_load_font({path}, {size})'
    
    # 패턴 적용
    content = re.sub(image_pattern, replace_image_load, content, flags=re.MULTILINE)
    content = re.sub(simple_image_pattern, replace_simple_image, content, flags=re.MULTILINE)
    content = re.sub(sound_pattern, replace_sound_load, content, flags=re.MULTILINE)
    content = re.sub(font_pattern, replace_font_load, content, flags=re.MULTILINE)
    
    # safe_loader import 추가 (아직 없다면)
    if 'from utils.safe_loader import' not in content and 'import safe_loader' not in content:
        # 다른 utils import 찾기
        utils_import_match = re.search(r'from utils\.\w+ import', content)
        if utils_import_match:
            # 기존 utils import 다음에 추가
            insert_pos = utils_import_match.end()
            content = content[:insert_pos] + '\nfrom utils import safe_loader' + content[insert_pos:]
        else:
            # pygame import 다음에 추가
            pygame_import_match = re.search(r'import pygame\n', content)
            if pygame_import_match:
                insert_pos = pygame_import_match.end()
                content = content[:insert_pos] + 'from utils import safe_loader\n' + content[insert_pos:]
    
    final_lines = content.count('\n')
    lines_saved = original_lines - final_lines
    
    return content, replacements, lines_saved

def main():
    """메인 함수"""
    
    # 백업 생성
    os.system('cp bosspong.py bosspong_backup_safe_loader.py')
    
    # 변환 수행
    content, replacements, lines_saved = apply_safe_loader_to_file('bosspong.py')
    
    if replacements:
        print(f"🎯 {len(replacements)}개의 try-except 블록을 safe_loader로 대체합니다:")
        for i, replacement in enumerate(replacements[:10]):  # 처음 10개만 표시
            print(f"  {i+1}. {replacement}")
        if len(replacements) > 10:
            print(f"  ... 그리고 {len(replacements)-10}개 더")
        
        # 파일 저장
        with open('bosspong.py', 'w', encoding='utf-8') as f:
            f.write(content)
        
        print(f"\n✅ 성공적으로 {len(replacements)}개의 try-except 블록을 대체했습니다.")
        print(f"📉 예상 줄 수 감소: ~{lines_saved}줄")
        print("📁 원본 백업: bosspong_backup_safe_loader.py")
    else:
        print("변환할 try-except 블록을 찾지 못했습니다.")

if __name__ == "__main__":
    main()