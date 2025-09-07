"""
타격 직전 발동 억제 테스트
코덱스가 추가한 24프레임 이내 억제 로직 검증
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
print("타격 직전 발동 억제 테스트")
print("=" * 60)

def test_near_hit(name, ball_x, ball_y, ball_vx, ball_vy, paddle_y, expected):
    """테스트 실행"""
    result = smartphone.check_danger_v2(ball_x, ball_y, ball_vx, ball_vy, paddle_y, 50, 50)
    
    # X축 도달 시간 계산
    if ball_vx < 0:
        t_to_x = (ball_x - 50) / abs(ball_vx)
    else:
        t_to_x = 999
    
    symbol = "✅" if result == expected else "❌"
    print(f"\n{symbol} {name}")
    print(f"   위치: ({ball_x}, {ball_y}), 속도: (vx={ball_vx}, vy={ball_vy})")
    print(f"   패들Y: {paddle_y}, X축 도달: {t_to_x:.1f}프레임")
    print(f"   결과: {'발동' if result else '안함'} (예상: {'발동' if expected else '안함'})")
    return result == expected

print("\n" + "=" * 60)
print("테스트 1: 24프레임 이내 타격 예정")
print("=" * 60)

# 20프레임 후 타격 - 억제되어야 함
test_near_hit("20프레임 후 타격 (억제)", 250, 680, -10, 5, 700, expected=False)

# 10프레임 후 타격 - 확실히 억제
test_near_hit("10프레임 후 타격 (확실히 억제)", 150, 680, -10, 5, 700, expected=False)

# 5프레임 후 타격 - 무조건 억제
test_near_hit("5프레임 후 타격 (무조건 억제)", 100, 680, -10, 5, 700, expected=False)

print("\n" + "=" * 60)
print("테스트 2: 24프레임 초과 (정상 판단)")
print("=" * 60)

# 30프레임 후 - 정상 위험 판단
test_near_hit("30프레임 후 (정상 판단)", 350, 680, -10, 5, 500, expected=True)

# 50프레임 후 - 정상 위험 판단
test_near_hit("50프레임 후 (정상 판단)", 550, 680, -10, 5, 500, expected=True)

print("\n" + "=" * 60)
print("테스트 3: 경계값 테스트")
print("=" * 60)

# 정확히 24프레임
test_near_hit("정확히 24프레임", 290, 680, -10, 5, 650, expected=False)

# 25프레임 (경계 초과)
test_near_hit("25프레임 (경계 초과)", 300, 680, -10, 5, 500, expected=True)

print("\n" + "=" * 60)
print("테스트 4: Y축 거리 큰 경우도 억제 확인")
print("=" * 60)

# 타격 직전이지만 Y축 거리 큼
test_near_hit("10프레임 + Y거리 100px", 150, 600, -10, 5, 700, expected=False)

# 타격 직전이지만 Y축 거리 매우 큼
test_near_hit("10프레임 + Y거리 200px", 150, 500, -10, 5, 700, expected=False)

print("\n" + "=" * 60)
print("완료!")
print("=" * 60)