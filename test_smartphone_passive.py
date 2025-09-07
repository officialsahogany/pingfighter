"""
스마트폰 패시브 아이템 슬롯 버그 테스트
스마트폰 획득 시 액티브 슬롯에 추가되지 않는지 확인
"""

import pygame
import sys
import os

# 게임 디렉토리 추가
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Mock 설정
pygame.init()

# 전역 변수 설정
sys.modules['__main__'].active_item_slot = []
sys.modules['__main__'].selected_item_index = 0
sys.modules['__main__'].aipill_active = False
sys.modules['__main__'].last_item_use_time = 0
sys.modules['__main__'].long_boost_active = False
sys.modules['__main__'].MAX_ITEM_SLOTS = 3

# pingfighter.py의 store_active_item 함수 가져오기
exec(open('pingfighter.py').read(), globals())

print("=" * 60)
print("스마트폰 패시브 아이템 테스트")
print("=" * 60)

# 테스트 아이템들
test_items = [
    {"name": "smartphone", "color": (100, 150, 200)},
    {"name": "speedboots", "color": (255, 128, 0)},
    {"name": "stopwatch", "color": (255, 255, 0)},  # 액티브
    {"name": "aipill", "color": (255, 0, 255)},     # 액티브
    {"name": "ragnarok_hammer", "color": (255, 50, 50)},
]

print("\n액티브 슬롯 초기 상태:", sys.modules['__main__'].active_item_slot)

for item in test_items:
    print(f"\n{item['name']} 추가 시도...")
    before_count = len(sys.modules['__main__'].active_item_slot)
    
    # store_active_item 호출
    store_active_item(item)
    
    after_count = len(sys.modules['__main__'].active_item_slot)
    
    if after_count > before_count:
        print(f"  ✅ {item['name']}이(가) 액티브 슬롯에 추가됨 (현재 {after_count}개)")
    else:
        print(f"  ❌ {item['name']}은(는) 패시브로 처리되어 추가 안됨")

print("\n최종 액티브 슬롯 상태:")
for i, item in enumerate(sys.modules['__main__'].active_item_slot):
    print(f"  슬롯 {i}: {item['name']}")

print("\n" + "=" * 60)
print("테스트 완료!")
print("=" * 60)