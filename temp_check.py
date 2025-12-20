import sys
sys.stdout.reconfigure(encoding='utf-8')

with open('d:/PING/bosspong/pingfighter.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# 2834번 줄 확인 (0-indexed: 2833)
for i in range(2833, 2840):
    print(f'{i+1}: {repr(lines[i][:60])}')