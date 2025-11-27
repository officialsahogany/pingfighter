#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# Edit 도구를 사용하여 함수를 직접 교체

import os
import sys

# 현재 디렉토리 확인
os.chdir('/Volumes/isatra/1007/윈도우용최신/game/bosspong')

# 파일 읽기
with open('downtown/building_designs.py', 'r', encoding='utf-8') as f:
    lines = f.readlines()

# Fantasy 함수 찾기 (line 3748부터)
print("=== Fantasy 함수 위치 확인 ===")
for i in range(3747, 3760):
    print(f"{i+1}: {lines[i].rstrip()}")

# Steampunk 함수 찾기
print("\n=== Steampunk 함수 위치 확인 ===")
for i in range(3897, 3910):
    print(f"{i+1}: {lines[i].rstrip()}")

# Nature 함수 찾기
print("\n=== Nature 함수 검색 ===")
for i in range(len(lines)):
    if '_draw_nature_shop' in lines[i]:
        print(f"Nature 함수 발견: line {i+1}")
        for j in range(i, min(i+10, len(lines))):
            print(f"{j+1}: {lines[j].rstrip()}")
        break

# Luxury 함수 찾기
print("\n=== Luxury 함수 검색 ===")
for i in range(len(lines)):
    if '_draw_luxury_shop' in lines[i]:
        print(f"Luxury 함수 발견: line {i+1}")
        for j in range(i, min(i+10, len(lines))):
            print(f"{j+1}: {lines[j].rstrip()}")
        break

print("\n파일 총 라인 수:", len(lines))
