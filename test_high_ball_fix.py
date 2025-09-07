"""
높이 떠있는 공 발동 문제 테스트
스크린샷 상황 재현 및 검증
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

print("=" * 60)
print("높이 떠있는 공 발동 문제 테스트")
print("=" * 60)

def test_scenario(name, ball_x, ball_y, ball_vx, ball_vy, paddle_y, expected):
    """테스트 실행"""
    result = smartphone.check_danger_v2(ball_x, ball_y, ball_vx, ball_vy, paddle_y, 50, 50)
    
    symbol = "✅" if result == expected else "❌"
    print(f"\n{symbol} {name}")
    print(f"   공 위치: ({ball_x}, {ball_y})")
    print(f"   공 속도: (vx={ball_vx}, vy={ball_vy})")
    print(f"   패들Y: {paddle_y}")
    print(f"   결과: {'발동' if result else '안함'} (예상: {'발동' if expected else '안함'})")
    return result == expected

print("\n" + "=" * 60)
print("테스트 1: 스크린샷 상황 재현")
print("=" * 60)

# 스크린샷의 상황: 공이 화면 중앙, 멀리 있음
test_scenario("공 화면 중앙 (Y=450)", 600, 450, -10, 5, 700, expected=False)
test_scenario("공 화면 중앙 (Y=400)", 600, 400, -10, 5, 700, expected=False)
test_scenario("공 화면 상단 (Y=350)", 600, 350, -10, 5, 700, expected=False)

print("\n" + "=" * 60)
print("테스트 2: 다양한 높이에서 테스트")
print("=" * 60)

# 다양한 Y축 위치
test_scenario("Y=500 (화면 2/3)", 500, 500, -10, 5, 700, expected=False)
test_scenario("Y=550 (화면 3/4)", 500, 550, -10, 5, 700, expected=False)
test_scenario("Y=600 (플레이어 근처)", 500, 600, -10, 5, 700, expected=False)
test_scenario("Y=650 (매우 가까움)", 200, 650, -10, 10, 700, expected=False)

print("\n" + "=" * 60)
print("테스트 3: 빠른 공 vs 느린 공")
print("=" * 60)

# 느린 공 - 멀리 있으면 발동 안함
test_scenario("느린 공 멀리", 600, 500, -5, 3, 700, expected=False)
test_scenario("느린 공 중간", 400, 550, -5, 3, 700, expected=False)

# 빠른 공 - 더 일찍 감지
test_scenario("빠른 공 멀리", 600, 500, -20, 15, 700, expected=False)
test_scenario("빠른 공 중간", 400, 550, -20, 15, 700, expected=False)

print("\n" + "=" * 60)
print("테스트 4: 실제 위험 상황")
print("=" * 60)

# 정말 위험한 상황만 발동
test_scenario("바닥 임박", 200, 720, -10, 10, 600, expected=True)
test_scenario("도달 불가능", 200, 680, -15, 20, 500, expected=True)
test_scenario("초고속 근접", 150, 680, -30, 20, 700, expected=False)  # 타격 가능

print("\n" + "=" * 60)
print("테스트 5: X축 거리별 테스트")
print("=" * 60)

# X축 멀리 있으면 더 엄격
test_scenario("X=700 (매우 멀리)", 700, 550, -10, 5, 700, expected=False)
test_scenario("X=500 (멀리)", 500, 600, -10, 5, 700, expected=False)
test_scenario("X=300 (중간)", 300, 650, -10, 5, 700, expected=False)
test_scenario("X=150 (가까움)", 150, 680, -10, 5, 700, expected=False)

print("\n" + "=" * 60)
print("완료!")
print("=" * 60)