"""
스마트폰 개선된 발동 조건 테스트
- 공 속도와 무관하게 도달 불가능한 상황에서만 발동
- 대시 가능 여부 고려
- X축 전체 범위에서 작동
"""

import pygame
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from item_effects.smartphone import get_smartphone_instance

# 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))

# 스마트폰 인스턴스 가져오기
smartphone = get_smartphone_instance()
smartphone.active = True  # 패시브 아이템 활성화

# 테스트용 게임 상태
test_state = {
    'active_items': [
        {'name': 'stopwatch', 'effect': 'stopwatch'},
        {'name': 'aipill', 'effect': 'aipill'}
    ]
}

# 테스트용 스테이지 정보 클래스
class TestStage:
    def __init__(self, ball_x, ball_y, ball_vx, ball_vy, paddle_y):
        self.ball_x = ball_x
        self.ball_y = ball_y
        self.ball_vx = ball_vx
        self.ball_vy = ball_vy
        self.paddle_y = paddle_y
        self.paddle_size = 100

# 전역 변수 설정 (대시 테스트용)
class MockMain:
    def __init__(self):
        self.last_hit_by = "boss"
        self.rolling_charges = 1  # 대시 가능
        self.PLAYER = type('obj', (object,), {'centerx': 50, 'centery': 710})()

mock_main = MockMain()
sys.modules['__main__'] = mock_main

print("=" * 60)
print("개선된 스마트폰 발동 조건 테스트")
print("=" * 60)

def test_scenario(name, ball_x, ball_y, ball_vx, ball_vy, paddle_y, expected, dash_available=False):
    """테스트 시나리오 실행"""
    mock_main.rolling_charges = 1 if dash_available else 0
    mock_main.PLAYER.centery = paddle_y
    
    stage = TestStage(ball_x, ball_y, ball_vx, ball_vy, paddle_y)
    danger = smartphone.check_danger(ball_x, ball_y, ball_vx, ball_vy, paddle_y, 100, player_x=50)
    
    # X, Y 거리 계산
    x_dist = ball_x - 50
    y_dist = abs(ball_y - paddle_y)
    
    symbol = "✅" if danger == expected else "❌"
    result = "발동" if danger else "안함"
    exp_str = "발동" if expected else "안함"
    
    print(f"\n{symbol} {name}")
    print(f"   위치: ({ball_x}, {ball_y}), 속도: {ball_vx:.0f}")
    print(f"   X거리: {x_dist:.0f}px, Y거리: {y_dist:.0f}px")
    print(f"   대시 가능: {dash_available}")
    print(f"   결과: {result} (예상: {exp_str})")
    return danger == expected

print("\n" + "=" * 60)
print("테스트 1: 거리별 도달 가능성 판단")
print("=" * 60)

# 근거리 테스트
test_scenario("가까운 거리 + Y축 가까움", 100, 700, -5, 0, 710, expected=False)
test_scenario("가까운 거리 + Y축 멀음", 100, 500, -5, 0, 710, expected=True)

# 중거리 테스트
test_scenario("중거리 + Y축 가까움", 300, 700, -10, 0, 710, expected=False)
test_scenario("중거리 + Y축 멀음", 300, 500, -10, 0, 710, expected=True)

# 원거리 테스트
test_scenario("원거리 + Y축 가까움", 600, 700, -5, 0, 710, expected=False)
test_scenario("원거리 + Y축 매우 멀음", 600, 100, -5, 0, 710, expected=True)

print("\n" + "=" * 60)
print("테스트 2: 속도와 무관한 판단")
print("=" * 60)

# 느린 공
test_scenario("느린 공 + 도달 가능", 200, 650, -2, 0, 710, expected=False)
test_scenario("느린 공 + 도달 불가능", 200, 200, -2, 0, 710, expected=True)

# 보통 속도
test_scenario("보통 속도 + 도달 가능", 300, 650, -10, 0, 710, expected=False) 
test_scenario("보통 속도 + 도달 불가능", 300, 100, -10, 0, 710, expected=True)

# 빠른 공
test_scenario("빠른 공 + 도달 가능", 150, 680, -30, 0, 710, expected=False)
test_scenario("빠른 공 + 도달 불가능", 150, 400, -30, 0, 710, expected=True)

print("\n" + "=" * 60)
print("테스트 3: 대시 가능 여부 영향")
print("=" * 60)

# 대시 없으면 불가능, 대시 있으면 가능
test_scenario("대시 없음 - 도달 불가", 400, 500, -15, 0, 710, expected=True, dash_available=False)
test_scenario("대시 있음 - 도달 가능", 400, 500, -15, 0, 710, expected=False, dash_available=True)

# 대시로도 불가능한 거리
test_scenario("대시로도 불가 - 너무 멀음", 500, 100, -10, 0, 710, expected=True, dash_available=True)

print("\n" + "=" * 60)
print("테스트 4: 화면 끝 특수 케이스")
print("=" * 60)

# 화면 상단에서 하단으로
test_scenario("화면 상단→하단", 400, 50, -10, 0, 750, expected=True)
test_scenario("화면 하단→상단", 400, 750, -10, 0, 50, expected=True)
test_scenario("화면 중앙 근처", 400, 400, -10, 0, 450, expected=False)

print("\n" + "=" * 60)
print("테스트 5: 플레이어가 친 공 (발동 안함)")
print("=" * 60)

mock_main.last_hit_by = "player"
test_scenario("플레이어 서브/샷", 200, 500, -10, 0, 710, expected=False)

mock_main.last_hit_by = "boss"
test_scenario("보스가 친 공", 200, 500, -10, 0, 710, expected=True)

print("\n" + "=" * 60)
print("테스트 완료!")
print("=" * 60)