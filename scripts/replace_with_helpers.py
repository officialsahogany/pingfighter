#!/usr/bin/env python3
"""
중복 코드를 헬퍼 함수로 교체하는 스크립트
"""

import re

def replace_duplicate_patterns(filename):
    """중복 패턴을 헬퍼 함수로 교체"""
    
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    replacements = 0
    new_lines = []
    
    for i, line in enumerate(lines):
        original_line = line
        modified = False
        
        # 거리 계산 패턴 교체
        # math.sqrt((x1 - x2)**2 + (y1 - y2)**2) 형태를 찾아서 교체
        distance_pattern = r'math\.sqrt\(\(([^)]+)\s*-\s*([^)]+)\)\s*\*\*\s*2\s*\+\s*\(([^)]+)\s*-\s*([^)]+)\)\s*\*\*\s*2\)'
        distance_match = re.search(distance_pattern, line)
        if distance_match:
            x1, x2, y1, y2 = distance_match.groups()
            # 변수 이름을 정리
            pos1 = f"({x1.strip()}, {y1.strip()})"
            pos2 = f"({x2.strip()}, {y2.strip()})"
            replacement = f"calculate_distance({pos1}, {pos2})"
            line = re.sub(distance_pattern, replacement, line)
            modified = True
            replacements += 1
        
        # 중심 좌표 계산 패턴 교체
        # (rect.centerx, rect.centery) 형태
        center_pattern = r'\((\w+)\.centerx,\s*\1\.centery\)'
        center_match = re.search(center_pattern, line)
        if center_match and 'def get_center_pos' not in line:
            rect_name = center_match.group(1)
            line = re.sub(center_pattern, f'get_center_pos({rect_name})', line)
            modified = True
            replacements += 1
        
        # 색상 튜플 패턴 교체 (자주 사용되는 색상들)
        color_replacements = [
            (r'\(255,\s*255,\s*255\)', 'WHITE'),
            (r'\(0,\s*0,\s*0\)', 'BLACK'),
            (r'\(255,\s*0,\s*0\)', 'RED'),
            (r'\(0,\s*255,\s*0\)', 'GREEN'),
            (r'\(0,\s*0,\s*255\)', 'BLUE'),
            (r'\(255,\s*255,\s*0\)', 'YELLOW'),
            (r'\(0,\s*255,\s*255\)', 'CYAN'),
            (r'\(255,\s*0,\s*255\)', 'MAGENTA'),
        ]
        
        # 색상 상수는 정의 부분과 주석은 건드리지 않음
        if not ('=' in line and any(color in line for color in ['WHITE', 'BLACK', 'RED', 'GREEN', 'BLUE'])) \
           and not line.strip().startswith('#'):
            for pattern, replacement in color_replacements:
                if re.search(pattern, line):
                    line = re.sub(pattern, replacement, line)
                    modified = True
                    replacements += 1
                    break
        
        if modified:
            print(f"Line {i+1}: 교체됨")
            print(f"  이전: {original_line.strip()}")
            print(f"  이후: {line.strip()}")
        
        new_lines.append(line)
    
    # 파일 저장
    if replacements > 0:
        # 백업 생성
        with open(filename + '.backup_phase6', 'w', encoding='utf-8') as f:
            f.writelines(lines)
        
        # 변경 사항 저장
        with open(filename, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        
        print(f"\n✅ 총 {replacements}개의 패턴을 헬퍼 함수로 교체했습니다!")
    else:
        print("교체할 패턴이 없습니다.")
    
    return replacements

if __name__ == "__main__":
    filename = "../bosspong.py"
    
    print("=== 중복 코드를 헬퍼 함수로 교체 ===\n")
    total = replace_duplicate_patterns(filename)
    print(f"\n완료! 총 {total}개 교체")