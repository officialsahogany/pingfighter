"""
타격 가능 영역 발동 억제 테스트
플레이어가 직접 타격 가능한 거리에서는 절대 발동 안함
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
print("타격 가능 영역 테스트")
print("=" * 60)

def test_hitting(name, ball_x, ball_y, ball_vx, ball_vy, paddle_y, expected):
    """테스트 실행"""
    result = smartphone.check_danger_v2(ball_x, ball_y, ball_vx, ball_vy, paddle_y, 50, 50)
    
    # 계산
    if ball_vx < 0:
        t_to_x = (ball_x - 50) / abs(ball_vx)
        predicted_y = ball_y + ball_vy * t_to_x
        y_gap = abs(predicted_y - paddle_y)
    else:
        t_to_x = 999
        y_gap = 999
    
    symbol = "✅" if result == expected else "❌"
    print(f"\n{symbol} {name}")
    print(f"   위치: ({ball_x}, {ball_y}), 속도: (vx={ball_vx}, vy={ball_vy})")
    print(f"   패들Y: {paddle_y}, X도달: {t_to_x:.1f}프레임")
    if t_to_x < 100:
        print(f"   예측Y: {predicted_y:.0f}, Y갭: {y_gap:.0f}px")
    print(f"   결과: {'발동' if result else '안함'} (예상: {'발동' if expected else '안함'})")
    return result == expected

print("\n" + "=" * 60)
print("테스트 1: 초근접 타격 영역 (≤15프레임)")
print("=" * 60)

# 5프레임 - 절대 발동 안함
test_hitting("5프레임 - 패들 범위 내", 100, 690, -10, 5, 700, expected=False)
test_hitting("5프레임 - 패들 범위 밖", 100, 600, -10, 5, 700, expected=False)

# 10프레임 - 타격 가능하면 안함
test_hitting("10프레임 - 패들 가까움", 150, 680, -10, 5, 700, expected=False)
test_hitting("10프레임 - Y 멀지만 도달 가능", 150, 650, -10, 5, 700, expected=False)

# 15프레임 경계
test_hitting("15프레임 - 타격 가능", 200, 680, -10, 5, 700, expected=False)
test_hitting("15프레임 - Y 매우 멀음", 200, 500, -10, 5, 700, expected=False)

print("\n" + "=" * 60)
print("테스트 2: 중거리 영역 (16-30프레임)")
print("=" * 60)

# 20프레임 - 패들 범위 내면 억제
test_hitting("20프레임 - 패들 범위 내", 250, 690, -10, 5, 700, expected=False)
test_hitting("20프레임 - Y 멀고 도달 불가", 250, 500, -10, 5, 700, expected=True)

# 25프레임
test_hitting("25프레임 - 도달 가능", 300, 680, -10, 5, 700, expected=False)
test_hitting("25프레임 - 도달 불가", 300, 500, -10, 5, 700, expected=True)

print("\n" + "=" * 60)
print("테스트 3: 원거리 (>30프레임)")
print("=" * 60)

# 40프레임 - 정상 위험 판단
test_hitting("40프레임 - 도달 불가", 450, 680, -10, 10, 500, expected=True)
test_hitting("40프레임 - 도달 가능", 450, 680, -10, 5, 700, expected=False)

print("\n" + "=" * 60)
print("테스트 4: 극한 케이스")
print("=" * 60)

# 매우 빠른 공
test_hitting("초고속 5프레임", 150, 680, -20, 10, 700, expected=False)

# 바닥 임박 + 타격 가능
test_hitting("바닥 임박 but 타격 가능", 100, 720, -10, 10, 700, expected=False)

# 바닥 임박 + 타격 불가
test_hitting("바닥 임박 + 타격 불가", 400, 720, -10, 10, 500, expected=True)

print("\n" + "=" * 60)
print("테스트 5: 실제 게임 시나리오")
print("=" * 60)

# 플레이어가 서브 직후 상황
test_hitting("서브 직후 (가까움)", 120, 690, -8, 3, 700, expected=False)

# 중앙에서 빠른 공
test_hitting("중앙 빠른 공", 400, 600, -20, 15, 700, expected=False)

# 놓칠 것 같은 공
test_hitting("확실히 놓칠 공", 500, 680, -10, 20, 500, expected=True)

print("\n" + "=" * 60)
print("완료!")
print("=" * 60)