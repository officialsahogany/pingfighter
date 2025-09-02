#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Windows cp949 인코딩 오류 해결을 위한 유니코드 이모지 제거 스크립트"""

import os
import re
import glob

def remove_emojis(text):
    """텍스트에서 이모지와 특수 유니코드 문자 제거"""
    # 이모지 패턴
    emoji_pattern = re.compile(
        "["
        "\U0001F600-\U0001F64F"  # 이모티콘
        "\U0001F300-\U0001F5FF"  # 심볼 & 그림문자
        "\U0001F680-\U0001F6FF"  # 교통 & 지도 심볼
        "\U0001F1E0-\U0001F1FF"  # 국기
        "\U00002702-\U000027B0"
        "\U000024C2-\U0001F251"
        "\U0001F900-\U0001F9FF"  # 추가 이모티콘
        "\U00002600-\U000026FF"  # 기타 심볼
        "\U00002700-\U000027BF"  # 딩뱃
        "]+", 
        flags=re.UNICODE
    )
    return emoji_pattern.sub('', text)

def fix_file(filepath):
    """파일의 print 문에서 이모지 제거"""
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        
        original_content = content
        
        # print 문에서 이모지 제거
        lines = content.split('\n')
        new_lines = []
        modified = False
        
        for line in lines:
            if 'print(' in line or 'print (' in line:
                # 이모지가 포함된 경우만 처리
                clean_line = remove_emojis(line)
                if clean_line != line:
                    modified = True
                    # 공백 정리
                    clean_line = re.sub(r'print\(["\'][\s]+', 'print("', clean_line)
                    clean_line = re.sub(r'[\s]+["\']', '"', clean_line)
                new_lines.append(clean_line)
            else:
                new_lines.append(line)
        
        if modified:
            new_content = '\n'.join(new_lines)
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            print(f"수정됨: {filepath}")
            return True
    except Exception as e:
        print(f"오류 발생 {filepath}: {e}")
    return False

def main():
    """핵심 파일들의 유니코드 이모지 제거"""
    # 우선순위 파일들
    priority_files = [
        'pingfighter.py',
        'academy.py',
        'items.py',
        'gacha.py',
        'skill.py',
        'opening.py',
        'effects_manager.py',
        'physics_manager.py',
        'ui_manager.py',
        'sound_manager.py',
        'dash_manager.py',
        'feedback_system.py',
        'trade_point_system.py',
        'legendary_items.py',
        'pixel_font_manager.py',
        'game_mechanics/half_dash_system.py',
        'game_mechanics/half_dash_integration.py',
        'events/balloon_machine_event.py',
        'events/stage1_event_integration.py',
        'events/stage5_fire_machine_event.py',
        'events/stage5_event_integration.py',
        'item_effects/devil_dice.py',
        'item_effects/technical_vest.py',
        'item_effects/bluetooth_ring.py',
        'item_effects/fuel_pouch.py',
        'item_effects/dowsing_pendulum.py',
        'backgrounds/animated_background_stage2.py',
        'backgrounds/animated_background_stage3.py',
        'backgrounds/animated_background_stage4.py',
        'backgrounds/animated_background_stage5.py',
        'backgrounds/animated_background_stage6.py',
        'ui/stage3_menhera_world.py',
        'ui/stage4_shaolin_temple.py',
        'ui/stage5_chinese_market.py',
        'game_logic/boss_movement_integration.py',
        'game_logic/checkmate_system.py',
        'game_logic/show_character_selection_module.py',
    ]
    
    fixed_count = 0
    
    for file in priority_files:
        filepath = f"E:\\윈도우용최신\\game\\bosspong\\{file}"
        if os.path.exists(filepath):
            if fix_file(filepath):
                fixed_count += 1
    
    print(f"\n총 {fixed_count}개 파일 수정 완료")

if __name__ == "__main__":
    main()