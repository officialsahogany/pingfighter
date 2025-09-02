#!/usr/bin/env python3
"""
Phase 5-4: 중복 코드 통합
반복되는 패턴을 헬퍼 함수로 통합
"""

import re
from collections import defaultdict
import os

def find_duplicate_patterns(content):
    """중복되는 코드 패턴 찾기"""
    
    lines = content.split('\n')
    patterns = defaultdict(list)
    
    # 1. pygame.draw 패턴 통합 가능성
    draw_patterns = []
    for i, line in enumerate(lines):
        if 'pygame.draw.' in line and 'draw.' not in line:
            draw_patterns.append((i+1, line.strip()))
    
    # 2. 비슷한 if-elif 체인
    if_chains = []
    in_chain = False
    chain_start = 0
    chain_lines = []
    
    for i, line in enumerate(lines):
        if 'if current_stage ==' in line:
            in_chain = True
            chain_start = i+1
            chain_lines = [line]
        elif in_chain and 'elif current_stage ==' in line:
            chain_lines.append(line)
        elif in_chain and line.strip() and not line.strip().startswith(('elif', 'else ')):
            if len(chain_lines) > 3:
                if_chains.append((chain_start, len(chain_lines)))
            in_chain = False
            chain_lines = []
    
    # 3. 반복되는 함수 호출 패턴
    function_calls = defaultdict(int)
    for line in lines:
        # play_sound 패턴
        if 'play_sound(' in line:
            function_calls['play_sound'] += 1
        # draw 패턴
        if 'draw.' in line:
            match = re.search(r'draw\.(\w+)', line)
            if match:
                function_calls[f'draw.{match.group(1)}'] += 1
    
    return {
        'draw_patterns': len(draw_patterns),
        'if_chains': len(if_chains),
        'function_calls': function_calls
    }

def consolidate_stage_checks(content):
    """스테이지 체크 로직 통합"""
    
    # 스테이지별 설정을 딕셔너리로 통합
    stage_config_code = '''
def get_stage_config(stage):
    """스테이지별 설정 반환"""
    configs = {
        1: {'speed_multiplier': 1.0, 'boss_speed': 10, 'special': 'none'},
        2: {'speed_multiplier': 1.2, 'boss_speed': 15, 'special': 'speed_defense'},
        3: {'speed_multiplier': 1.3, 'boss_speed': 12, 'special': 'overdrive'},
        4: {'speed_multiplier': 1.1, 'boss_speed': 8, 'special': 'magnetic'},
        5: {'speed_multiplier': 1.5, 'boss_speed': 20, 'special': 'fire_dragon'},
        6: {'speed_multiplier': 1.4, 'boss_speed': 18, 'special': 'carrier'}
    }
    return configs.get(stage, configs[1])
'''
    
    # 함수를 적절한 위치에 추가
    insert_pos = content.find('# === 게임 함수들 ===')
    if insert_pos > 0:
        content = content[:insert_pos] + stage_config_code + '\n' + content[insert_pos:]
    
    return content, 10  # 예상 감소 줄 수

def consolidate_draw_calls(content):
    """DrawHelper로 더 많은 draw 호출 통합"""
    
    lines = content.split('\n')
    changed = 0
    
    for i, line in enumerate(lines):
        original = line
        
        # pygame.draw.circle -> draw.circle
        if 'pygame.draw.circle(' in line and 'draw.circle(' not in line:
            line = line.replace('pygame.draw.circle(SCREEN,', 'draw.circle(')
            line = line.replace('pygame.draw.circle(screen,', 'draw.circle(')
        
        # pygame.draw.rect -> draw.rect
        elif 'pygame.draw.rect(' in line and 'draw.rect(' not in line:
            line = line.replace('pygame.draw.rect(SCREEN,', 'draw.rect(')
            line = line.replace('pygame.draw.rect(screen,', 'draw.rect(')
        
        # pygame.draw.line -> draw.line
        elif 'pygame.draw.line(' in line and 'draw.line(' not in line:
            line = line.replace('pygame.draw.line(SCREEN,', 'draw.line(')
            line = line.replace('pygame.draw.line(screen,', 'draw.line(')
        
        if line != original:
            lines[i] = line
            changed += 1
    
    return '\n'.join(lines), changed

def create_color_mixer():
    """색상 믹싱 헬퍼 함수 생성"""
    
    helper_code = '''
def mix_color(base_color, tint_color, ratio=0.5):
    """두 색상을 비율에 따라 혼합"""
    return tuple(
        int(base_color[i] * (1 - ratio) + tint_color[i] * ratio)
        for i in range(3)
    )

def darken_color(color, factor=0.7):
    """색상을 어둡게 만들기"""
    return tuple(int(c * factor) for c in color[:3])

def lighten_color(color, factor=1.3):
    """색상을 밝게 만들기"""
    return tuple(min(255, int(c * factor)) for c in color[:3])
'''
    return helper_code

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase5_4.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    
    print("\n🔧 Phase 5-4: 중복 코드 통합...")
    
    # 중복 패턴 찾기
    patterns = find_duplicate_patterns(content)
    
    print("\n📊 중복 패턴 분석:")
    print(f"   pygame.draw 직접 호출: {patterns['draw_patterns']}개")
    print(f"   스테이지 if-elif 체인: {patterns['if_chains']}개")
    print(f"   자주 호출되는 함수:")
    for func, count in sorted(patterns['function_calls'].items(), 
                              key=lambda x: x[1], reverse=True)[:5]:
        print(f"      - {func}: {count}회")
    
    total_saved = 0
    
    # 1. 스테이지 체크 통합
    print("\n📌 스테이지 체크 로직 통합...")
    content, saved = consolidate_stage_checks(content)
    total_saved += saved
    print(f"   {saved}줄 감소 예상")
    
    # 2. Draw 호출 통합
    print("\n📌 pygame.draw → DrawHelper 추가 변환...")
    content, changed = consolidate_draw_calls(content)
    total_saved += changed // 2  # 대략적인 줄 감소
    print(f"   {changed}개 호출 변환")
    
    # 3. 색상 헬퍼 추가
    print("\n📌 색상 믹싱 헬퍼 함수 추가...")
    color_helper = create_color_mixer()
    insert_pos = content.find('class DrawHelper:')
    if insert_pos > 0:
        content = content[:insert_pos] + color_helper + '\n\n' + content[insert_pos:]
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 5-4 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   변경: {original_lines - final_lines:,}줄")
    print("="*50)

if __name__ == "__main__":
    main()