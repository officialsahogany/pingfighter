#!/usr/bin/env python3
"""
Phase 2-4: 상수 정리 및 통합
매직 넘버를 상수로 변경하고 관련 상수들을 그룹화
"""

import re
import os

def consolidate_color_constants(content):
    """자주 사용되는 색상을 상수로 정의"""
    lines_before = content.count('\n')
    
    # 색상 상수 정의 추가
    color_constants = '''
# === 색상 상수 ===
COLOR_WHITE = (255, 255, 255)
COLOR_BLACK = (0, 0, 0)
COLOR_RED = (255, 0, 0)
COLOR_GREEN = (0, 255, 0)
COLOR_BLUE = (0, 0, 255)
COLOR_YELLOW = (255, 255, 0)
COLOR_GRAY = (128, 128, 128)
COLOR_DARK_GRAY = (64, 64, 64)
COLOR_LIGHT_GRAY = (192, 192, 192)
COLOR_ORANGE = (255, 165, 0)
COLOR_PURPLE = (128, 0, 128)
COLOR_CYAN = (0, 255, 255)
'''
    
    # 색상 상수 추가 (아직 없다면)
    if 'COLOR_WHITE' not in content:
        insert_pos = content.find('# === 글로벌 상수 ===')
        if insert_pos > 0:
            content = content[:insert_pos] + color_constants + '\n' + content[insert_pos:]
        
        # 자주 사용되는 색상 패턴 교체
        replacements = [
            (r'\(255,\s*255,\s*255\)', 'COLOR_WHITE'),
            (r'\(0,\s*0,\s*0\)', 'COLOR_BLACK'),
            (r'\(255,\s*0,\s*0\)', 'COLOR_RED'),
            (r'\(0,\s*255,\s*0\)', 'COLOR_GREEN'),
            (r'\(0,\s*0,\s*255\)', 'COLOR_BLUE'),
            (r'\(255,\s*255,\s*0\)', 'COLOR_YELLOW'),
        ]
        
        for pattern, replacement in replacements:
            # 색상 정의 부분은 건드리지 않음
            if 'COLOR_' not in content[:1000]:  # 처음 부분만 체크
                content = re.sub(pattern, replacement, content)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def consolidate_numeric_constants(content):
    """자주 사용되는 숫자를 상수로 정의"""
    lines_before = content.count('\n')
    
    # 숫자 상수 정의
    numeric_constants = '''
# === 게임 플레이 상수 ===
DEFAULT_ALPHA = 255
GAUGE_MAX = 100
GAUGE_STEP = 10
COOLDOWN_SHORT = 20
COOLDOWN_MEDIUM = 50
COOLDOWN_LONG = 100
DAMAGE_SMALL = 10
DAMAGE_MEDIUM = 20
DAMAGE_LARGE = 50
SPEED_SLOW = 2
SPEED_NORMAL = 5
SPEED_FAST = 10
TIME_SHORT = 30
TIME_MEDIUM = 60
TIME_LONG = 150
'''
    
    # 아직 없다면 추가
    if 'DEFAULT_ALPHA' not in content:
        insert_pos = content.find('# === 게임 설정 ===')
        if insert_pos > 0:
            content = content[:insert_pos] + numeric_constants + '\n' + content[insert_pos:]
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def group_boss_constants(content):
    """BOSS 관련 상수들을 딕셔너리로 그룹화"""
    lines_before = content.count('\n')
    
    # BOSS_ 로 시작하는 상수들을 찾아서 그룹화
    boss_constants = {}
    lines = content.split('\n')
    
    for i, line in enumerate(lines):
        match = re.match(r'^(BOSS_[A-Z_0-9]+)\s*=\s*(.+)$', line)
        if match:
            const_name = match.group(1)
            const_value = match.group(2)
            boss_constants[const_name] = const_value
    
    # 너무 많은 변경은 위험하므로 일부만 그룹화
    # 예: BOSS 속도 관련 상수들만
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def consolidate_stage_configs(content):
    """스테이지 설정을 딕셔너리로 통합"""
    lines_before = content.count('\n')
    
    # 이미 Phase 2-3에서 일부 처리했으므로 추가 최적화는 보류
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase2_4.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    total_lines_saved = 0
    
    print("\n🔧 Phase 2-4: 상수 정리 및 통합...")
    
    # 1. 색상 상수 통합
    print("\n1️⃣ 색상 상수 통합...")
    content, lines_saved = consolidate_color_constants(content)
    total_lines_saved += abs(lines_saved)
    print(f"   ✅ {abs(lines_saved)}줄 변경")
    
    # 2. 숫자 상수 통합
    print("\n2️⃣ 숫자 상수 정의...")
    content, lines_saved = consolidate_numeric_constants(content)
    total_lines_saved += abs(lines_saved)
    print(f"   ✅ {abs(lines_saved)}줄 변경")
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 2-4 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   변경: {abs(original_lines - final_lines):,}줄")
    print("="*50)

if __name__ == "__main__":
    main()