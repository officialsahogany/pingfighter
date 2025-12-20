# -*- coding: utf-8 -*-
import sys

file_path = "d:/PING/bosspong/pingfighter.py"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Check if already added
if 'on_starpoint_collected(1)' in content:
    print('Already added!')
    sys.exit(0)

# Find the exact pattern
old_text = """            # 트레이드 포인트 획득
            trade_point_collected += 1

            # 레거시 변수 업데이트 (호환성)"""

new_text = """            # 트레이드 포인트 획득
            trade_point_collected += 1

            # 런타임 스킬 시스템에 스타포인트 수집 알림
            on_starpoint_collected(1)

            # 레거시 변수 업데이트 (호환성)"""

if old_text in content:
    new_content = content.replace(old_text, new_text)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(new_content)
    print('SUCCESS: Added on_starpoint_collected call')
else:
    print('Pattern not found, searching alternative...')
    # Look for the line
    lines = content.split('\n')
    found_idx = -1
    for i, line in enumerate(lines):
        if 'trade_point_collected += 1' in line and i > 70000:
            found_idx = i
            print(f'Found at line {i+1}: {repr(line)}')
            # Show context
            for j in range(max(0,i-3), min(len(lines), i+5)):
                print(f'{j+1}: {repr(lines[j])}')
            break
