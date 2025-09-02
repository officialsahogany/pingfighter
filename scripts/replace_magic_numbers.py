#!/usr/bin/env python3
"""
매직넘버를 상수로 교체하는 스크립트
안전하게 교체하기 위해 컨텍스트를 확인
"""

import re

def replace_magic_numbers(filename):
    """매직넘버를 상수로 교체"""
    
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    replacements = 0
    new_lines = []
    
    # 교체 규칙 (컨텍스트 기반)
    replacements_map = [
        # 타이머 관련
        (r'\b60\b', 'FPS', ['fps', 'frame', '프레임']),
        (r'\b30\b', 'HALF_SECOND_FRAMES', ['timer', 'cooldown', 'duration', 'delay']),
        (r'\b120\b', 'TWO_SECONDS_FRAMES', ['timer', 'cooldown', 'duration', 'delay']),
        (r'\b180\b', 'THREE_SECONDS_FRAMES', ['timer', 'cooldown', 'duration']),
        (r'\b1000\b', 'MILLISECONDS_PER_SECOND', ['millisec', 'ms', 'time']),
        
        # 크기 관련
        (r'\b32\b', 'ICON_SIZE', ['icon', 'scale', 'transform']),
        (r'\b40\b', 'TILE_SIZE', ['range', 'grid', 'tile']),
        (r'\b20\b', 'DEFAULT_RADIUS', ['radius', 'circle']),
        (r'\b50\b', 'LARGE_SIZE', ['size', 'width', 'height']),
        
        # 각도 관련
        (r'\b90\b', 'QUARTER_ROTATION', ['angle', 'rotation', 'rotate']),
        (r'\b180\b', 'HALF_ROTATION', ['angle', 'rotation', 'rotate']),
        (r'\b360\b', 'FULL_ROTATION', ['angle', 'rotation', 'rotate']),
        
        # UI 관련
        (r'\b150\b', 'DEFAULT_ALPHA', ['alpha', 'transparent', 'opacity']),
        (r'\b4\b', 'BORDER_WIDTH', ['border', 'width.*border', 'border.*width']),
    ]
    
    skip_lines = False
    
    for i, line in enumerate(lines):
        original_line = line
        modified = False
        
        # 상수 정의 부분은 건너뛰기
        if '# === 게임 관련 상수 ===' in line:
            skip_lines = True
        elif '# === DrawHelper 클래스 ===' in line:
            skip_lines = False
        
        if skip_lines or line.strip().startswith('#'):
            new_lines.append(line)
            continue
        
        # 이미 정의된 상수 라인은 건너뛰기
        if '=' in line and line.strip()[0].isupper() and line.strip()[0].isalpha():
            new_lines.append(line)
            continue
        
        # import 문은 건너뛰기
        if line.strip().startswith('import ') or line.strip().startswith('from '):
            new_lines.append(line)
            continue
        
        # 문자열 리터럴 내부는 건너뛰기
        if '"""' in line or "'''" in line or '"' in line or "'" in line:
            # 간단한 체크만 (정교한 처리는 복잡함)
            if line.count('"') % 2 == 0 or line.count("'") % 2 == 0:
                new_lines.append(line)
                continue
        
        # 교체 수행
        line_lower = line.lower()
        for pattern, replacement, contexts in replacements_map:
            # 컨텍스트 확인
            if any(ctx in line_lower for ctx in contexts):
                # 이미 상수가 사용된 경우는 건너뛰기
                if replacement in line:
                    continue
                
                # 교체
                new_line = re.sub(pattern, replacement, line)
                if new_line != line:
                    line = new_line
                    modified = True
                    replacements += 1
                    break  # 한 줄에서 하나만 교체
        
        if modified:
            print(f"Line {i+1}: 교체됨")
            print(f"  이전: {original_line.strip()}")
            print(f"  이후: {line.strip()}")
        
        new_lines.append(line)
    
    # 파일 저장
    if replacements > 0:
        # 백업 생성
        with open(filename + '.backup_phase7', 'w', encoding='utf-8') as f:
            f.writelines(lines)
        
        # 변경 사항 저장
        with open(filename, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        
        print(f"\n✅ 총 {replacements}개의 매직넘버를 상수로 교체했습니다!")
    else:
        print("교체할 매직넘버가 없습니다.")
    
    return replacements

if __name__ == "__main__":
    filename = "../bosspong.py"
    
    print("=== 매직넘버를 상수로 교체 ===\n")
    total = replace_magic_numbers(filename)
    print(f"\n완료! 총 {total}개 교체")