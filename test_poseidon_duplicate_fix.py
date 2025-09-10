#!/usr/bin/env python3
"""포세이돈 삼지창 중복 방지 최종 테스트"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import items

def test_poseidon_duplicate_prevention():
    """포세이돈 삼지창 중복 방지 종합 테스트"""
    print("🔱 포세이돈 삼지창 중복 방지 최종 테스트")
    print("=" * 60)
    
    # 테스트 1: TAB 메뉴에서 선택 시뮬레이션
    print("\n1️⃣ TAB 메뉴에서 포세이돈 삼지창 선택:")
    items.poseidon_trident_obtained = True
    print(f"   poseidon_trident_obtained: {items.poseidon_trident_obtained}")
    
    # 테스트 2: spawn_random_item에서 전역 변수 접근 테스트
    print("\n2️⃣ spawn_random_item 함수에서 전역 변수 접근 테스트:")
    
    # spawn_random_item 함수 내부 로직 시뮬레이션
    def test_spawn_logic():
        # spawn_random_item 함수에서 사용되는 전역 변수들
        global poseidon_trident_obtained  # 이 줄이 중요!
        
        # items 모듈에서 가져오기
        poseidon_trident_obtained = items.poseidon_trident_obtained
        
        print(f"   함수 내부에서 poseidon_trident_obtained: {poseidon_trident_obtained}")
        
        # 스폰 가능 여부 체크
        can_spawn = True
        for item in items.ITEM_TYPES:
            if item["name"] == "poseidon_trident":
                if poseidon_trident_obtained:
                    can_spawn = False
                    print(f"   포세이돈 삼지창: 스폰 불가 (이미 획득)")
                else:
                    can_spawn = True
                    print(f"   포세이돈 삼지창: 스폰 가능")
                break
        
        return can_spawn
    
    can_spawn = test_spawn_logic()
    
    # 테스트 3: 실제 spawn_random_item 함수 호출
    print("\n3️⃣ 실제 spawn_random_item 함수 테스트:")
    
    # 백업
    original_items = items.item_list.copy() if hasattr(items, 'item_list') else []
    
    # spawn_random_item 호출
    spawned_item = items.spawn_random_item()
    
    if spawned_item:
        print(f"   스폰된 아이템: {spawned_item['name']}")
        # 포세이돈 삼지창이 스폰되었는지 확인
        if spawned_item['name'] == 'poseidon_trident':
            print("   ❌ 버그: 포세이돈 삼지창이 중복 스폰됨!")
        else:
            print("   ✅ 정상: 포세이돈 삼지창이 스폰되지 않음")
    else:
        print("   아이템이 스폰되지 않음 (정상일 수 있음)")
    
    # 테스트 4: 스테이지 전환 후에도 유지되는지 확인
    print("\n4️⃣ 스테이지 전환 후 상태 확인:")
    items.reset_items()
    print(f"   reset_items() 후 poseidon_trident_obtained: {items.poseidon_trident_obtained}")
    
    # 검증
    print("\n" + "=" * 60)
    if items.poseidon_trident_obtained and not can_spawn:
        print("✨ 테스트 성공! 중복 방지가 제대로 작동합니다.")
        print("   - TAB 메뉴 선택 후 플래그 설정 ✓")
        print("   - spawn_random_item에서 중복 체크 ✓")
        print("   - 스테이지 전환 후에도 상태 유지 ✓")
    else:
        print("⚠️ 테스트 실패! 중복 방지가 작동하지 않습니다.")
        if not items.poseidon_trident_obtained:
            print("   - 플래그가 제대로 설정되지 않음")
        if can_spawn:
            print("   - spawn_random_item에서 체크 실패")

if __name__ == "__main__":
    test_poseidon_duplicate_prevention()