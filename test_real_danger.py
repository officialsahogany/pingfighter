"""
실제 위험 상황 감지 테스트
Y > 680인 바닥 근처에서 정확히 발동하는지 검증
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
print("실제 위험 상황 감지 테스트")
print("=" * 60)

def test_danger(name, ball_x, ball_y, ball_vx, ball_vy, paddle_y, expected):
    """테스트 실행"""
    result = smartphone.check_danger_v2(ball_x, ball_y, ball_vx, ball_vy, paddle_y, 50, 50)
    
    symbol = "✅" if result == expected else "❌"
    print(f"\n{symbol} {name}")
    print(f"   공 위치: ({ball_x}, {ball_y})")
    print(f"   공 속도: (vx={ball_vx}, vy={ball_vy})")
    print(f"   패들Y: {paddle_y}")
    print(f"   결과: {'발동' if result else '안함'} (예상: {'발동' if expected else '안함'})")
    
    # 디버깅 정보
    if result != expected:
        print(f"   [DEBUG] 실패 원인 분석:")
        # X축 도달 시간
        if ball_vx < 0:
            t_x = (ball_x - 50) / abs(ball_vx)
            print(f"   - X축 도달: {t_x:.1f}프레임")
        # Y축 거리
        y_gap = abs(ball_y - paddle_y)
        print(f"   - Y축 거리: {y_gap:.0f}px")
        # 바닥까지 시간
        frames_to_floor = (750 - ball_y) / abs(ball_vy) if ball_vy > 0 else 999
        print(f"   - 바닥까지: {frames_to_floor:.1f}프레임")
    
    return result == expected

print("\n" + "=" * 60)
print("테스트 1: 바닥 임박 상황 (Y > 700)")
print("=" * 60)

# 바닥 매우 가까움 + 패들 멀리
test_danger("바닥 임박 + 패들 멀리", 200, 720, -10, 10, 600, expected=True)
test_danger("바닥 임박 + 패들 위", 200, 720, -10, 10, 500, expected=True)
test_danger("바닥 임박 + 패들 가까움", 200, 720, -10, 10, 700, expected=False)  # 타격 가능

print("\n" + "=" * 60)
print("테스트 2: 위험 영역 (Y = 680)")
print("=" * 60)

# Y=680에서 다양한 상황
test_danger("Y=680 + 패들 멀리", 200, 680, -10, 15, 500, expected=True)
test_danger("Y=680 + 패들 중간", 200, 680, -10, 15, 600, expected=True)
test_danger("Y=680 + 패들 가까움", 200, 680, -10, 15, 650, expected=False)  # 도달 가능
test_danger("Y=680 + X 가까움", 100, 680, -10, 15, 600, expected=False)  # 타격 가능

print("\n" + "=" * 60)
print("테스트 3: Y=650 영역")
print("=" * 60)

# Y=650에서 테스트
test_danger("Y=650 + 패들 매우 멀리", 300, 650, -10, 10, 450, expected=True)
test_danger("Y=650 + 패들 멀리", 300, 650, -10, 10, 550, expected=True)
test_danger("Y=650 + 패들 가까움", 300, 650, -10, 10, 650, expected=False)

print("\n" + "=" * 60)
print("테스트 4: 빠른 공 위험 상황")
print("=" * 60)

# 빠른 공
test_danger("초고속 + Y=680", 300, 680, -30, 25, 500, expected=True)
test_danger("초고속 + Y=720", 250, 720, -25, 20, 600, expected=True)
test_danger("초고속 + 타격 가능", 100, 680, -30, 20, 680, expected=False)

print("\n" + "=" * 60)
print("테스트 5: 경계 케이스")
print("=" * 60)

# 정확히 경계에서
test_danger("Y=680 경계", 250, 680, -10, 10, 580, expected=True)
test_danger("Y=700 경계", 250, 700, -10, 10, 600, expected=True)
test_danger("Y=730 경계", 250, 730, -10, 5, 650, expected=True)

print("\n" + "=" * 60)
print("완료!")
print("=" * 60)