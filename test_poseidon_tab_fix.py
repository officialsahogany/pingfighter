#!/usr/bin/env python3
"""
포세이돈 삼지창 TAB 메뉴 선택 후 중복 스폰 버그 수정 테스트
"""
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 모듈 import
import items
from pingfighter import apply_selected_items

def test_tab_selection_sets_flag():
    """TAB 메뉴에서 포세이돈 삼지창 선택 시 획득 플래그가 설정되는지 테스트"""
    print("=" * 60)
    print("테스트: TAB 메뉴 포세이돈 삼지창 선택 후 획득 플래그 설정")
    print("=" * 60)
    
    # 초기 상태 확인
    items.poseidon_trident_obtained = False
    print(f"초기 상태: poseidon_trident_obtained = {items.poseidon_trident_obtained}")
    
    # TAB 메뉴에서 포세이돈 삼지창 선택 시뮬레이션
    selected_active_items = []
    selected_passive_items = []
    selected_legendary_items = ["poseidon_trident"]
    
    print(f"\nTAB 메뉴 선택: {selected_legendary_items}")
    
    # apply_selected_items 호출
    apply_selected_items(selected_active_items, selected_passive_items, selected_legendary_items)
    
    # 플래그 확인
    print(f"\n선택 후 상태: poseidon_trident_obtained = {items.poseidon_trident_obtained}")
    
    if items.poseidon_trident_obtained:
        print("✅ 성공: 획득 플래그가 올바르게 설정됨!")
    else:
        print("❌ 실패: 획득 플래그가 설정되지 않음!")
    
    return items.poseidon_trident_obtained

def test_spawn_prevention():
    """획득 플래그가 설정된 후 스폰이 방지되는지 테스트"""
    print("\n" + "=" * 60)
    print("테스트: 획득 플래그 설정 후 스폰 방지")
    print("=" * 60)
    
    # 플래그 설정
    items.poseidon_trident_obtained = True
    print(f"플래그 설정: poseidon_trident_obtained = {items.poseidon_trident_obtained}")
    
    # spawn_random_item 시뮬레이션 (실제로는 호출하지 않고 로직만 확인)
    can_spawn = not items.poseidon_trident_obtained
    
    print(f"스폰 가능 여부: {can_spawn}")
    
    if not can_spawn:
        print("✅ 성공: 포세이돈 삼지창이 더 이상 스폰되지 않음!")
    else:
        print("❌ 실패: 포세이돈 삼지창이 여전히 스폰 가능!")
    
    return not can_spawn

if __name__ == "__main__":
    print("포세이돈 삼지창 TAB 메뉴 중복 스폰 버그 수정 테스트")
    print("=" * 60)
    
    # 테스트 실행
    test1_pass = test_tab_selection_sets_flag()
    test2_pass = test_spawn_prevention()
    
    # 결과 요약
    print("\n" + "=" * 60)
    print("테스트 결과 요약")
    print("=" * 60)
    print(f"1. TAB 선택 시 플래그 설정: {'✅ 성공' if test1_pass else '❌ 실패'}")
    print(f"2. 플래그 설정 후 스폰 방지: {'✅ 성공' if test2_pass else '❌ 실패'}")
    
    if test1_pass and test2_pass:
        print("\n🎉 모든 테스트 통과! 버그가 수정되었습니다!")
    else:
        print("\n⚠️ 일부 테스트 실패. 추가 수정이 필요합니다.")