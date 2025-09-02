#!/usr/bin/env python3
"""
Phase 2-1: 중복 함수 통합 스크립트
유사한 패턴의 함수들을 통합하여 코드 중복 제거
"""

import re
import os

def inline_short_functions(content):
    """짧은 함수들을 인라인화"""
    lines_before = content.count('\n')
    
    # 1. get_special_gauge - 단순 반환
    pattern = r'def get_special_gauge\(\):.*?\n.*?return special_gauge'
    content = re.sub(pattern, '', content, flags=re.DOTALL)
    # 호출 부분 직접 치환
    content = re.sub(r'get_special_gauge\(\)', 'special_gauge', content)
    
    # 2. stop_quake_sound - 단순 호출
    pattern = r'def stop_quake_sound\(\):.*?\n.*?quake_sound\.stop\(\)'
    content = re.sub(pattern, '', content, flags=re.DOTALL)
    # 호출 부분 직접 치환
    content = re.sub(r'stop_quake_sound\(\)', 'quake_sound.stop()', content)
    
    # 3. consume_special_gauge - 간단한 업데이트
    pattern = r'def consume_special_gauge\(amount\):.*?\n.*?global special_gauge.*?\n.*?special_gauge -= amount'
    replacement = ''
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)
    # 호출 부분을 직접 연산으로 치환
    content = re.sub(r'consume_special_gauge\(([^)]+)\)', r'special_gauge -= \1', content)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def consolidate_throw_functions(content):
    """throw_ 함수들을 하나의 범용 함수로 통합"""
    lines_before = content.count('\n')
    
    # throw_item 범용 함수 생성
    throw_item_func = '''
def throw_item(item_type, start_x, start_y, target_x, target_y):
    """범용 투척 아이템 처리 함수"""
    global grenades, smoke_grenades, flares, molotov_bottles
    
    item_data = {
        'grenade': {'list': grenades, 'damage': 30, 'radius': 100},
        'smoke': {'list': smoke_grenades, 'damage': 0, 'radius': 150},
        'flare': {'list': flares, 'damage': 0, 'radius': 200},
        'molotov': {'list': molotov_bottles, 'damage': 20, 'radius': 120}
    }
    
    if item_type in item_data:
        item_info = item_data[item_type]
        item_info['list'].append({
            'x': start_x, 'y': start_y,
            'target_x': target_x, 'target_y': target_y,
            'progress': 0, 'active': True,
            'damage': item_info['damage'],
            'radius': item_info['radius']
        })
'''
    
    # 기존 throw_ 함수들 제거
    throw_patterns = [
        r'def throw_grenade\(\):.*?(?=\ndef |\nclass |\Z)',
        r'def throw_smoke_grenade\(\):.*?(?=\ndef |\nclass |\Z)',
        r'def throw_flare\(\):.*?(?=\ndef |\nclass |\Z)',
        r'def throw_molotov\(\):.*?(?=\ndef |\nclass |\Z)'
    ]
    
    for pattern in throw_patterns:
        content = re.sub(pattern, '', content, flags=re.DOTALL)
    
    # 새로운 범용 함수 추가 (적절한 위치에)
    insert_pos = content.find('def activate_grenade():')
    if insert_pos > 0:
        content = content[:insert_pos] + throw_item_func + '\n' + content[insert_pos:]
    
    # 호출 부분 수정
    content = re.sub(r'throw_grenade\(\)', 
                     "throw_item('grenade', PLAYER.centerx, PLAYER.centery, BOSS.centerx, BOSS.centery)", 
                     content)
    content = re.sub(r'throw_smoke_grenade\(\)', 
                     "throw_item('smoke', PLAYER.centerx, PLAYER.centery, WIDTH//2, HEIGHT//2)", 
                     content)
    content = re.sub(r'throw_flare\(\)', 
                     "throw_item('flare', PLAYER.centerx, PLAYER.centery, BOSS.centerx, BOSS.centery)", 
                     content)
    content = re.sub(r'throw_molotov\(\)', 
                     "throw_item('molotov', PLAYER.centerx, PLAYER.centery, BOSS.centerx, BOSS.centery)", 
                     content)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def consolidate_activate_patterns(content):
    """activate_ 함수들 중 유사한 패턴 통합"""
    lines_before = content.count('\n')
    
    # 간단한 activate 함수들을 딕셔너리 기반으로 통합
    activate_config = '''
# 아이템 활성화 설정
ITEM_ACTIVATION = {
    'long_boost': {'gauge_cost': 10, 'timer': 600, 'flag': 'long_boost_active'},
    'flare': {'gauge_cost': 15, 'timer': 300, 'flag': 'flare_active'},
    'smoke_grenade': {'gauge_cost': 20, 'timer': 400, 'flag': 'smoke_active'},
}

def activate_item(item_name):
    """범용 아이템 활성화 함수"""
    global special_gauge
    if item_name in ITEM_ACTIVATION:
        config = ITEM_ACTIVATION[item_name]
        if special_gauge >= config['gauge_cost']:
            special_gauge -= config['gauge_cost']
            globals()[config['flag']] = True
            globals()[config['flag'].replace('_active', '_timer')] = config['timer']
            return True
    return False
'''
    
    # 단순한 activate 함수들 제거
    simple_patterns = [
        r'def activate_long_boost\(\):.*?(?=\ndef |\nclass |\Z)',
        r'def activate_flare\(\):.*?(?=\ndef |\nclass |\Z)',
        r'def activate_smoke_grenade\(\):.*?(?=\ndef |\nclass |\Z)',
    ]
    
    for pattern in simple_patterns:
        content = re.sub(pattern, '', content, flags=re.DOTALL)
    
    # 새로운 통합 함수 추가
    insert_pos = content.find('def activate_grenade():')
    if insert_pos > 0:
        content = content[:insert_pos] + activate_config + '\n' + content[insert_pos:]
    
    # 호출 부분 수정
    content = re.sub(r'activate_long_boost\(\)', "activate_item('long_boost')", content)
    content = re.sub(r'activate_flare\(\)', "activate_item('flare')", content)
    content = re.sub(r'activate_smoke_grenade\(\)', "activate_item('smoke_grenade')", content)
    
    lines_after = content.count('\n')
    return content, lines_before - lines_after

def main():
    """메인 함수"""
    
    # 백업 생성
    print("📁 백업 생성 중...")
    os.system('cp bosspong.py bosspong_backup_phase2_1.py')
    
    # 파일 읽기
    with open('bosspong.py', 'r', encoding='utf-8') as f:
        content = f.read()
    
    original_lines = content.count('\n')
    total_lines_saved = 0
    
    print("\n🔧 Phase 2-1: 중복 함수 통합...")
    
    # 1. 짧은 함수 인라인화
    print("\n1️⃣ 짧은 함수 인라인화...")
    content, lines_saved = inline_short_functions(content)
    total_lines_saved += lines_saved
    print(f"   ✅ {lines_saved}줄 감소")
    
    # 2. throw_ 함수 통합
    print("\n2️⃣ throw_ 함수 통합...")
    content, lines_saved = consolidate_throw_functions(content)
    total_lines_saved += lines_saved
    print(f"   ✅ {lines_saved}줄 감소")
    
    # 3. activate_ 패턴 통합
    print("\n3️⃣ activate_ 패턴 통합...")
    content, lines_saved = consolidate_activate_patterns(content)
    total_lines_saved += lines_saved
    print(f"   ✅ {lines_saved}줄 감소")
    
    # 파일 저장
    with open('bosspong.py', 'w', encoding='utf-8') as f:
        f.write(content)
    
    final_lines = content.count('\n')
    
    print("\n" + "="*50)
    print("📊 Phase 2-1 완료!")
    print(f"   원본: {original_lines:,}줄")
    print(f"   결과: {final_lines:,}줄")
    print(f"   감소: {original_lines - final_lines:,}줄 ({(original_lines - final_lines) / original_lines * 100:.1f}%)")
    print("="*50)

if __name__ == "__main__":
    main()
