#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
판도라의 상자 중복 아이템 방지 테스트
"""

import pygame
import sys
import os

# PyInstaller 실행 환경과 일반 Python 실행 환경 모두 대응
if hasattr(sys, '_MEIPASS'):
    BASE_DIR = sys._MEIPASS
else:
    BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# 경로를 프로젝트 루트에 추가
sys.path.insert(0, BASE_DIR)

# Pygame 초기화
pygame.init()

# items 모듈 import
import items

# 테스트를 위해 몇 가지 전역 변수 설정
items.speedboots_obtained = False
items.speedgear_obtained = False
items.battery_obtained = False
items.master_obtained = False
items.cooltime_obtained = False
items.spikeboots_obtained = False
items.dashgear_obtained = False

# pingfighter의 passive_item_list 시뮬레이션
class MockPingfighter:
    passive_item_list = []

# Mock 객체를 items 모듈에 주입
items.pingfighter = MockPingfighter()

def test_pandora_box_duplicate():
    """판도라의 상자로 아이템이 중복 스폰되는지 테스트"""
    print("=== 판도라의 상자 중복 방지 테스트 ===\n")
    
    # 테스트 1: 첫 번째 스폰
    print("1. 첫 번째 아이템 스폰 테스트")
    items.item_list = []  # 필드 초기화
    items.spawn_random_item()
    if items.item_list:
        first_item = items.item_list[0]["type"]["name"]
        print(f"   스폰된 아이템: {first_item}")
    
    # 테스트 2: 패시브 아이템을 인벤토리에 추가
    print("\n2. 패시브 아이템을 인벤토리에 추가")
    MockPingfighter.passive_item_list = [
        {"name": "speedboots"},
        {"name": "battery"}
    ]
    print(f"   현재 인벤토리: {[item['name'] for item in MockPingfighter.passive_item_list]}")
    
    # 테스트 3: 판도라의 상자 효과로 여러 아이템 빠르게 스폰
    print("\n3. 판도라의 상자 효과 시뮬레이션 (빠른 스폰)")
    items.item_list = []  # 필드 초기화
    spawned_items = []
    
    for i in range(10):  # 10번 스폰 시도
        items.spawn_random_item()
        if len(items.item_list) > len(spawned_items):
            new_item = items.item_list[-1]["type"]["name"]
            spawned_items.append(new_item)
            print(f"   스폰 {i+1}: {new_item}")
    
    # 중복 체크
    print("\n4. 중복 체크 결과")
    unique_items = set(spawned_items)
    if len(spawned_items) != len(unique_items):
        duplicates = []
        for item in unique_items:
            count = spawned_items.count(item)
            if count > 1:
                duplicates.append(f"{item} ({count}개)")
        print(f"   ❌ 중복 발견: {', '.join(duplicates)}")
    else:
        print(f"   ✅ 중복 없음! 총 {len(spawned_items)}개 아이템 모두 유니크")
    
    # 인벤토리와 중복 체크
    print("\n5. 인벤토리 아이템과 중복 체크")
    inventory_items = [item['name'] for item in MockPingfighter.passive_item_list]
    field_duplicates = []
    for item in spawned_items:
        if item in inventory_items:
            field_duplicates.append(item)
    
    if field_duplicates:
        print(f"   ❌ 인벤토리와 중복: {field_duplicates}")
    else:
        print(f"   ✅ 인벤토리 아이템과 중복 없음!")

if __name__ == "__main__":
    try:
        test_pandora_box_duplicate()
    except Exception as e:
        print(f"테스트 중 오류 발생: {e}")
        import traceback
        traceback.print_exc()