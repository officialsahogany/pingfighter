"""
패들 위 공 발동 억제 테스트
공이 패들 범위 내에 있을 때 스마트폰이 발동하지 않는지 확인
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
print("패들 위 공 발동 억제 테스트")
print("=" * 60)

def test(name, ball_x, ball_y, vx, vy, paddle_x, paddle_y, expected):
    """테스트 실행"""
    smartphone.last_y_gap = None
    smartphone.closing_streak = 0
    smartphone.urgent_override = False
    
    result = smartphone.check_danger_v2(ball_x, ball_y, vx, vy, paddle_y, 50, paddle_x)
    
    symbol = "✅" if result == expected else "❌"
    status = "🚨 발동" if result else "억제됨"
    
    # 패들 범위 계산
    paddle_left = paddle_x - 155/2 - 10
    paddle_right = paddle_x + 155/2 + 10
    in_x_range = paddle_left <= ball_x <= paddle_right
    in_y_range = (ball_y >= paddle_y - 50) and (ball_y <= paddle_y + 25)
    
    print(f"\n{symbol} {name}")
    print(f"   공: ({ball_x},{ball_y}), 속도: ({vx},{vy})")
    print(f"   패들: X={paddle_x} (범위:{paddle_left:.0f}~{paddle_right:.0f}), Y={paddle_y}")
    print(f"   X범위 내: {in_x_range}, Y범위 내: {in_y_range}")
    print(f"   결과: {status} (예상: {'발동' if expected else '억제'})")
    
    return result == expected

print("\n시나리오 1: 패들 바로 위 (발동 안 해야 함)")
print("-" * 40)

# 패들 중앙 위
test("패들 정중앙 위", 
     ball_x=100, ball_y=680, vx=-5, vy=10,
     paddle_x=100, paddle_y=700, expected=False)

# 패들 왼쪽 끝 위
test("패들 왼쪽 끝 위",
     ball_x=30, ball_y=680, vx=-5, vy=10,
     paddle_x=100, paddle_y=700, expected=False)

# 패들 오른쪽 끝 위
test("패들 오른쪽 끝 위",
     ball_x=170, ball_y=680, vx=-5, vy=10,
     paddle_x=100, paddle_y=700, expected=False)

print("\n시나리오 2: 패들 범위 밖 (발동해야 함)")
print("-" * 40)

# X축 범위 밖
test("패들 왼쪽 밖",
     ball_x=10, ball_y=680, vx=-5, vy=10,
     paddle_x=100, paddle_y=700, expected=True)

test("패들 오른쪽 밖",
     ball_x=200, ball_y=680, vx=-5, vy=10,
     paddle_x=100, paddle_y=700, expected=True)

# Y축 너무 높음
test("패들 위 너무 높음",
     ball_x=100, ball_y=640, vx=-5, vy=10,
     paddle_x=100, paddle_y=700, expected=False)  # 너무 높으면 원래 발동 안 함

print("\n시나리오 3: 경계 케이스")
print("-" * 40)

# 패들 범위 경계
test("패들 X축 경계 (왼쪽)",
     ball_x=12.5, ball_y=680, vx=-5, vy=10,
     paddle_x=100, paddle_y=700, expected=False)  # 여유 10px 포함

test("패들 X축 경계 (오른쪽)",
     ball_x=187.5, ball_y=680, vx=-5, vy=10,
     paddle_x=100, paddle_y=700, expected=False)  # 여유 10px 포함

# Y축 경계
test("패들 Y축 경계 (위)",
     ball_x=100, ball_y=650, vx=-5, vy=10,
     paddle_x=100, paddle_y=700, expected=False)  # 패들 위 50px

test("패들 Y축 경계 (아래)",
     ball_x=100, ball_y=725, vx=-5, vy=10,
     paddle_x=100, paddle_y=700, expected=False)  # 패들 중심 + 25px

print("\n시나리오 4: 공이 위로 움직일 때")
print("-" * 40)

# 공이 위로 올라가는 중
test("패들 위지만 위로 이동",
     ball_x=100, ball_y=680, vx=-5, vy=-10,  # vy가 음수
     paddle_x=100, paddle_y=700, expected=False)  # 원래 위로 가면 발동 안 함

print("\n" + "=" * 60)
print("테스트 완료!")
print("=" * 60)