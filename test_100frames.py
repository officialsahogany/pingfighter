"""
패들 양쪽 100프레임 이내 발동 억제 테스트
공이 패들 X축 기준 100프레임 이내에 있을 때 발동하지 않는지 확인
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
    PADDLE_WIDTH = 155
    last_hit_by = 'boss'
    rolling_active = False

sys.modules['__main__'] = MockMain()

# 스마트폰 인스턴스
smartphone = get_smartphone_instance()
smartphone.active = True
smartphone.last_use_time = 0  # 쿨타임 리셋

print("=" * 60)
print("패들 양쪽 100프레임 이내 발동 억제 테스트")
print("=" * 60)

def test(name, ball_x, ball_y, vx, vy, paddle_x, paddle_y, expected):
    """테스트 실행"""
    smartphone.last_y_gap = None
    smartphone.closing_streak = 0
    smartphone.urgent_override = False
    
    result = smartphone.check_danger_v2(ball_x, ball_y, vx, vy, paddle_y, 50, paddle_x)
    
    symbol = "✅" if result == expected else "❌"
    status = "🚨 발동" if result else "억제됨"
    
    # 프레임 계산
    frames_to_paddle = None
    if vx < 0 and ball_x > paddle_x:
        frames_to_paddle = (ball_x - paddle_x) / abs(vx)
    elif vx > 0 and ball_x < paddle_x:
        frames_to_paddle = (paddle_x - ball_x) / abs(vx)
    
    print(f"\n{symbol} {name}")
    print(f"   공: ({ball_x},{ball_y}), 속도: ({vx},{vy})")
    print(f"   패들: X={paddle_x}, Y={paddle_y}")
    if frames_to_paddle:
        print(f"   패들까지 프레임: {frames_to_paddle:.1f}")
    print(f"   결과: {status} (예상: {'발동' if expected else '억제'})")
    
    return result == expected

print("\n시나리오 1: 100프레임 이내 (발동 안 해야 함)")
print("-" * 40)

# 50프레임 후 도달
test("50프레임 후 도달 (vx=-10)", 
     ball_x=550, ball_y=700, vx=-10, vy=10,
     paddle_x=50, paddle_y=700, expected=False)

# 99프레임 후 도달
test("99프레임 후 도달 (vx=-5)",
     ball_x=545, ball_y=700, vx=-5, vy=10,
     paddle_x=50, paddle_y=700, expected=False)

# 정확히 100프레임
test("정확히 100프레임 (vx=-5)",
     ball_x=550, ball_y=700, vx=-5, vy=10,
     paddle_x=50, paddle_y=700, expected=False)

print("\n시나리오 2: 100프레임 초과 (발동해야 함)")
print("-" * 40)

# 101프레임 후 도달
test("101프레임 후 도달 (vx=-5)",
     ball_x=555, ball_y=700, vx=-5, vy=10,
     paddle_x=50, paddle_y=700, expected=True)

# 200프레임 후 도달
test("200프레임 후 도달 (vx=-2.5)",
     ball_x=550, ball_y=700, vx=-2.5, vy=10,
     paddle_x=50, paddle_y=700, expected=True)

print("\n시나리오 3: 오른쪽으로 이동하는 공")
print("-" * 40)

# 패들 왼쪽에서 오른쪽으로 이동 (50프레임 전 통과)
test("오른쪽 이동 - 50프레임 전 통과",
     ball_x=25, ball_y=700, vx=0.5, vy=10,
     paddle_x=50, paddle_y=700, expected=False)

# 패들 왼쪽에서 오른쪽으로 이동 (150프레임 전 통과)
test("오른쪽 이동 - 150프레임 전 통과",
     ball_x=-25, ball_y=700, vx=0.5, vy=10,
     paddle_x=50, paddle_y=700, expected=True)

print("\n시나리오 4: 속도가 0인 경우")
print("-" * 40)

# X축 속도가 0
test("X축 속도 0",
     ball_x=200, ball_y=700, vx=0, vy=10,
     paddle_x=50, paddle_y=700, expected=True)

print("\n시나리오 5: 빠른 속도")
print("-" * 40)

# 매우 빠른 속도 (10프레임 후 도달)
test("초고속 공 (vx=-50)",
     ball_x=550, ball_y=700, vx=-50, vy=10,
     paddle_x=50, paddle_y=700, expected=False)

# 느린 속도 (500프레임 후 도달)
test("매우 느린 공 (vx=-1)",
     ball_x=550, ball_y=700, vx=-1, vy=10,
     paddle_x=50, paddle_y=700, expected=True)

print("\n" + "=" * 60)
print("테스트 완료!")
print("=" * 60)