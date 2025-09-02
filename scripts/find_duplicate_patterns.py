#!/usr/bin/env python3
"""
중복 코드 패턴을 찾는 스크립트
"""

import re
from collections import Counter

def find_duplicate_patterns(filename):
    """중복되는 코드 패턴 찾기"""
    
    with open(filename, 'r', encoding='utf-8') as f:
        lines = f.readlines()
    
    # 패턴별 카운터
    patterns = {
        'draw_circle_patterns': [],
        'draw_rect_patterns': [],
        'color_calculations': [],
        'position_calculations': [],
        'collision_checks': [],
        'distance_calculations': [],
        'angle_calculations': [],
    }
    
    for i, line in enumerate(lines, 1):
        # draw.circle 패턴
        if 'draw.circle(' in line:
            patterns['draw_circle_patterns'].append((i, line.strip()))
        
        # draw.rect 패턴
        if 'draw.rect(' in line:
            patterns['draw_rect_patterns'].append((i, line.strip()))
        
        # 색상 계산 패턴
        if re.search(r'\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*\)', line):
            patterns['color_calculations'].append((i, line.strip()))
        
        # 위치 계산 패턴
        if 'int(x' in line or 'int(y' in line or 'center_x' in line or 'center_y' in line:
            patterns['position_calculations'].append((i, line.strip()))
        
        # 충돌 체크 패턴
        if 'colliderect' in line or 'collidepoint' in line:
            patterns['collision_checks'].append((i, line.strip()))
        
        # 거리 계산 패턴
        if 'math.sqrt' in line or 'distance' in line or '**2' in line:
            patterns['distance_calculations'].append((i, line.strip()))
        
        # 각도 계산 패턴
        if 'math.sin' in line or 'math.cos' in line or 'math.atan2' in line:
            patterns['angle_calculations'].append((i, line.strip()))
    
    # 자주 반복되는 패턴 찾기
    print("=== 중복 패턴 분석 ===\n")
    
    # 비슷한 draw 호출 찾기
    print("1. Draw 패턴 분석:")
    print(f"   - draw.circle 호출: {len(patterns['draw_circle_patterns'])}개")
    print(f"   - draw.rect 호출: {len(patterns['draw_rect_patterns'])}개")
    
    # 자주 사용되는 색상 찾기
    print("\n2. 자주 사용되는 색상:")
    color_counter = Counter()
    for _, line in patterns['color_calculations'][:100]:  # 처음 100개만
        colors = re.findall(r'\((\s*\d+\s*,\s*\d+\s*,\s*\d+\s*)\)', line)
        for color in colors:
            color_counter[color] += 1
    
    for color, count in color_counter.most_common(10):
        if count > 3:
            print(f"   ({color}): {count}회")
    
    # 반복되는 계산 패턴
    print("\n3. 반복 계산 패턴:")
    print(f"   - 위치 계산: {len(patterns['position_calculations'])}개")
    print(f"   - 충돌 체크: {len(patterns['collision_checks'])}개")
    print(f"   - 거리 계산: {len(patterns['distance_calculations'])}개")
    print(f"   - 각도 계산: {len(patterns['angle_calculations'])}개")
    
    # 구체적인 중복 패턴 찾기
    print("\n4. 구체적인 중복 패턴:")
    
    # 반복되는 전체 라인 찾기
    line_counter = Counter()
    for line in lines:
        stripped = line.strip()
        if len(stripped) > 20 and not stripped.startswith('#'):
            line_counter[stripped] += 1
    
    print("\n   가장 많이 반복되는 코드 라인:")
    for line, count in line_counter.most_common(15):
        if count > 2:
            print(f"   [{count}회] {line[:80]}...")
    
    return patterns

def suggest_helper_functions(patterns):
    """헬퍼 함수 제안"""
    
    print("\n=== 헬퍼 함수 제안 ===\n")
    
    suggestions = []
    
    # 색상 관련 헬퍼
    print("1. 색상 관련 헬퍼:")
    print("   - get_stage_color(stage): 스테이지별 색상 반환")
    print("   - fade_color(color, alpha): 색상 페이드 효과")
    print("   - blend_colors(color1, color2, ratio): 색상 블렌딩")
    
    # 위치 관련 헬퍼
    print("\n2. 위치 관련 헬퍼:")
    print("   - get_center_pos(rect): 중심 좌표 반환")
    print("   - calculate_distance(pos1, pos2): 거리 계산")
    print("   - rotate_point(point, angle, center): 점 회전")
    
    # 그리기 관련 헬퍼
    print("\n3. 그리기 관련 헬퍼:")
    print("   - draw_glow_circle(pos, radius, color): 광채 효과 원")
    print("   - draw_gradient_rect(rect, color1, color2): 그라데이션 사각형")
    print("   - draw_explosion_effect(pos, radius, frame): 폭발 효과")
    
    # 충돌 관련 헬퍼
    print("\n4. 충돌 관련 헬퍼:")
    print("   - check_collision(obj1, obj2): 충돌 체크")
    print("   - handle_wall_bounce(ball_vel, wall_side): 벽 반사 처리")
    
    return suggestions

if __name__ == "__main__":
    filename = "../bosspong.py"
    
    print("중복 패턴 분석을 시작합니다...\n")
    patterns = find_duplicate_patterns(filename)
    suggest_helper_functions(patterns)