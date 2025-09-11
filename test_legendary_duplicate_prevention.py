#!/usr/bin/env python3
"""
전설 아이템 중복 방지 종합 테스트
TAB 메뉴 선택 후 중복 스폰 방지 확인
"""

import pygame
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import items
from pingfighter import apply_selected_items, store_passive_item

def test_legendary_duplicate_prevention():
    """전설 아이템 중복 방지 종합 테스트"""
    pygame.init()
    
    print("🎯 전설 아이템 중복 방지 종합 테스트")
    print("=" * 60)
    
    # 테스트할 전설 아이템들
    legendary_items = [
        ("poseidon_trident", "포세이돈의 삼지창", "poseidon_trident_obtained"),
        ("ragnarok_hammer", "라그나로크 해머", "ragnarok_hammer_obtained"),
        ("hermes_shoes", "헤르메스의 신발", "hermes_shoes_obtained")
    ]
    
    test_results = []
    
    for item_name, korean_name, flag_name in legendary_items:
        print(f"\n📌 {korean_name} 테스트")
        print("-" * 40)
        
        # 초기 상태 확인
        initial_flag = getattr(items, flag_name)
        print(f"1. 초기 상태: {flag_name} = {initial_flag}")
        
        # TAB 메뉴에서 선택 시뮬레이션
        print(f"2. TAB 메뉴에서 {korean_name} 선택 시뮬레이션...")
        apply_selected_items([], [item_name], [item_name])
        
        # 플래그 확인
        after_tab_flag = getattr(items, flag_name)
        print(f"3. TAB 선택 후: {flag_name} = {after_tab_flag}")
        
        # spawn_random_item에서 중복 체크 시뮬레이션
        can_spawn = True
        available_items = []
        for item in items.ITEM_TYPES:
            if item["name"] == item_name:
                if getattr(items, flag_name):
                    can_spawn = False
                    print(f"4. spawn_random_item: {korean_name} 스폰 불가 (이미 획득)")
                else:
                    available_items.append(item)
                    print(f"4. spawn_random_item: {korean_name} 스폰 가능")
        
        # 결과 저장
        test_passed = after_tab_flag == True and can_spawn == False
        test_results.append({
            "item": korean_name,
            "flag_set": after_tab_flag,
            "spawn_blocked": not can_spawn,
            "passed": test_passed
        })
        
        # 다음 테스트를 위해 플래그 리셋
        setattr(items, flag_name, False)
        print(f"5. 테스트 종료, 플래그 리셋: {flag_name} = False")
    
    # 전체 결과 출력
    print("\n" + "=" * 60)
    print("📊 테스트 결과 요약")
    print("=" * 60)
    
    all_passed = True
    for result in test_results:
        status = "✅ 성공" if result["passed"] else "❌ 실패"
        print(f"{result['item']:20} {status}")
        print(f"  - 플래그 설정: {'✓' if result['flag_set'] else '✗'}")
        print(f"  - 중복 방지: {'✓' if result['spawn_blocked'] else '✗'}")
        if not result["passed"]:
            all_passed = False
    
    print("\n" + "=" * 60)
    if all_passed:
        print("🎉 모든 전설 아이템 중복 방지 테스트 성공!")
        print("TAB 메뉴 선택 후 중복 스폰이 올바르게 차단됩니다.")
    else:
        print("⚠️ 일부 테스트 실패! 중복 방지 로직을 확인하세요.")
    
    return all_passed

if __name__ == "__main__":
    test_legendary_duplicate_prevention()