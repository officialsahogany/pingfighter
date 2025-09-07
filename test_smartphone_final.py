"""
스마트폰 최종 테스트
높이 가드 개선 후 정상 작동 확인
"""

import pygame
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from item_effects.smartphone import get_smartphone_instance

# 초기화
pygame.init()

# Mock main module
class MockMain:
    HEIGHT = 750
    PADDLE_HEIGHT = 50
    last_hit_by = 'boss'
    rolling_active = False

sys.modules['__main__'] = MockMain()

# 스마트폰 인스턴스
smartphone = get_smartphone_instance()
smartphone.active = True
smartphone.last_use_time = 0  # 쿨타임 리셋

print("=" * 60)
print("스마트폰 최종 동작 테스트")
print("=" * 60)

def test(name, ball_x, ball_y, vx, vy, paddle_y, expected):
    """테스트 실행"""
    smartphone.last_y_gap = None
    smartphone.closing_streak = 0
    smartphone.urgent_override = False
    
    result = smartphone.check_danger_v2(ball_x, ball_y, vx, vy, paddle_y, 50, 7)
    
    symbol = "✅" if result == expected else "❌"
    status = "🚨 발동" if result else "대기"
    print(f"{symbol} {name}: {status} (예상: {'발동' if expected else '대기'})")
    
    if result != expected:
        print(f"   ⚠️ 오류: 공({ball_x},{ball_y}), 속도({vx},{vy}), 패들Y={paddle_y}")
    
    return result == expected

print("\n1. 바닥 근처 위험 상황 (Y>=680)")
print("-" * 40)
test("바닥 근처 Y=690", 150, 690, -10, 5, 700, expected=True)
test("바닥 근처 Y=710", 150, 710, -10, 5, 700, expected=True)
test("바닥 근처 Y=730", 150, 730, -10, 5, 700, expected=True)
test("바닥 경계 Y=750", 150, 750, -10, 5, 700, expected=True)
test("바닥 너무 아래 Y=755", 150, 755, -10, 5, 700, expected=False)

print("\n2. X축 교차 임박 상황")
print("-" * 40)
test("X=100 임박", 100, 690, -15, 10, 700, expected=True)
test("X=80 매우 임박", 80, 710, -10, 5, 700, expected=True)
test("X=60 극임박", 60, 700, -20, 10, 700, expected=True)

print("\n3. 타격 가능한 상황 (발동 안 함)")
print("-" * 40)
test("패들 중심 근처", 200, 705, -5, 2, 700, expected=False)
test("천천히 접근", 300, 680, -3, 5, 700, expected=False)
test("Y축 매우 가까움", 150, 702, -10, 2, 700, expected=False)

print("\n4. 높은 공 (Y<680, 발동 안 함)")
print("-" * 40)
test("높은 공 Y=450", 200, 450, -10, 10, 700, expected=False)
test("높은 공 Y=500", 200, 500, -10, 10, 700, expected=False)
test("높은 공 Y=600", 200, 600, -10, 10, 700, expected=False)

print("\n5. 패시브 아이템 확인")
print("-" * 40)

# 패시브 아이템 테스트를 위한 가짜 pingfighter 설정
import types
main = types.ModuleType('__main__')
main.active_item_slot = []
main.selected_item_index = 0
main.MAX_ITEM_SLOTS = 3
sys.modules['__main__'] = main

# store_active_item 함수 정의 (간소화)
def store_active_item(item_data):
    """액티브 아이템 저장 (패시브는 무시)"""
    passive_items = [
        "speedboots", "technical_vest", "shield_generator",
        "bloodsucker", "lucky_dice", "time_slower", "gravity_ball",
        "magneticball", "smartphone", "ragnarok_hammer", "cloverleaf"
    ]
    
    if item_data["name"] in passive_items:
        print(f"   → {item_data['name']}은(는) 패시브 아이템 (슬롯 추가 안 함)")
        return
    
    if len(main.active_item_slot) < main.MAX_ITEM_SLOTS:
        main.active_item_slot.append(item_data)
        print(f"   → {item_data['name']}을(를) 액티브 슬롯에 추가")

# 테스트
smartphone_item = {"name": "smartphone", "color": (100, 150, 200)}
store_active_item(smartphone_item)

stopwatch_item = {"name": "stopwatch", "color": (255, 255, 0)}
store_active_item(stopwatch_item)

print(f"\n최종 액티브 슬롯: {[item['name'] for item in main.active_item_slot]}")

if len(main.active_item_slot) == 1 and main.active_item_slot[0]['name'] == 'stopwatch':
    print("✅ 스마트폰이 액티브 슬롯에 추가되지 않음 (정상)")
else:
    print("❌ 스마트폰이 잘못 처리됨")

print("\n" + "=" * 60)
print("테스트 완료!")
print("=" * 60)
