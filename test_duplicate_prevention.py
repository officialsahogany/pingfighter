#!/usr/bin/env python3
"""전설 아이템 중복 방지 테스트"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import items

def test_duplicate_prevention():
    """전설 아이템 중복 생성 방지 테스트"""
    print("🔱 전설 아이템 중복 방지 테스트")
    print("=" * 60)
    
    # 초기 상태 확인
    print("\n1️⃣ 초기 상태:")
    print(f"   ragnarok_hammer_obtained: {items.ragnarok_hammer_obtained}")
    print(f"   hermes_shoes_obtained: {items.hermes_shoes_obtained}")
    print(f"   poseidon_trident_obtained: {items.poseidon_trident_obtained}")
    
    # 포세이돈 삼지창 획득 시뮬레이션
    print("\n2️⃣ 포세이돈 삼지창 획득:")
    items.poseidon_trident_obtained = True
    print(f"   poseidon_trident_obtained: {items.poseidon_trident_obtained}")
    
    # reset_items 호출 (스테이지 전환 시뮬레이션)
    print("\n3️⃣ 스테이지 전환 (reset_items 호출):")
    items.reset_items()
    print(f"   poseidon_trident_obtained: {items.poseidon_trident_obtained}")
    
    # 검증
    if items.poseidon_trident_obtained:
        print("\n✅ 성공: 전설 아이템 획득 상태가 유지됨!")
    else:
        print("\n❌ 실패: 전설 아이템 획득 상태가 초기화됨!")
        
    # 아이템 스폰 가능 여부 테스트
    print("\n4️⃣ 아이템 스폰 가능 여부 체크:")
    
    # 포세이돈 삼지창이 스폰 가능한지 확인
    can_spawn = True
    for item in items.ITEM_TYPES:
        if item["name"] == "poseidon_trident":
            # spawn_random_item의 로직 시뮬레이션
            if items.poseidon_trident_obtained:
                can_spawn = False
                print(f"   포세이돈 삼지창: 스폰 불가 (이미 획득)")
            else:
                can_spawn = True
                print(f"   포세이돈 삼지창: 스폰 가능")
            break
    
    print("\n" + "=" * 60)
    if not can_spawn:
        print("✨ 테스트 성공! 중복 방지가 제대로 작동합니다.")
    else:
        print("⚠️ 테스트 실패! 중복 방지가 작동하지 않습니다.")

if __name__ == "__main__":
    test_duplicate_prevention()