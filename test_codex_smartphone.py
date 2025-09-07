"""
코덱스가 개선한 스마트폰 발동 조건 테스트
- miss_at_player_x 예측 시스템 검증
- 동적 상태 추적 검증
- 바닥 임박 긴급 발동 검증
"""

import pygame
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from item_effects.smartphone import get_smartphone_instance

# 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))

# 스마트폰 인스턴스
smartphone = get_smartphone_instance()
smartphone.active = True

# 테스트용 게임 상태
test_state = {
    'active_items': [
        {'name': 'stopwatch', 'effect': 'stopwatch'},
        {'name': 'aipill', 'effect': 'aipill'}
    ]
}

# 테스트용 스테이지 정보
class TestStage:
    def __init__(self, ball_x, ball_y, ball_vx, ball_vy, paddle_y):
        self.ball_x = ball_x
        self.ball_y = ball_y
        self.ball_vx = ball_vx
        self.ball_vy = ball_vy
        self.paddle_y = paddle_y
        self.paddle_size = 50

# 전역 변수 설정
class MockMain:
    def __init__(self):
        self.last_hit_by = "boss"
        self.rolling_active = False
        self.rolling_charges = 1
        self.HEIGHT = 750
        self.PADDLE_HEIGHT = 50
        self.PLAYER = type('obj', (object,), {'centerx': 50, 'centery': 710})()

mock_main = MockMain()
sys.modules['__main__'] = mock_main

print("=" * 60)
print("코덱스 스마트폰 개선 로직 테스트")
print("=" * 60)

def test_scenario(name, ball_x, ball_y, ball_vx, ball_vy, paddle_y, expected, rolling=False):
    """테스트 시나리오 실행"""
    mock_main.rolling_active = rolling
    mock_main.PLAYER.centery = paddle_y
    
    danger = smartphone.check_danger_v2(ball_x, ball_y, ball_vx, ball_vy, paddle_y, 50, player_x=50)
    
    symbol = "✅" if danger == expected else "❌"
    result = "발동" if danger else "안함"
    exp_str = "발동" if expected else "안함"
    
    print(f"\n{symbol} {name}")
    print(f"   위치: ({ball_x}, {ball_y}), 속도: (vx={ball_vx:.0f}, vy={ball_vy:.0f})")
    print(f"   패들Y: {paddle_y}, 대시: {rolling}")
    print(f"   결과: {result} (예상: {exp_str})")
    return danger == expected

print("\n" + "=" * 60)
print("테스트 1: Y축 기준 판단 (바닥 패배 규칙)")
print("=" * 60)

# Y축으로 내려오는 공 (vy > 0)
test_scenario("아래로 내려오는 공 - 도달 가능", 200, 680, -5, 10, 710, expected=False)
test_scenario("아래로 내려오는 공 - 도달 불가", 200, 680, -5, 50, 710, expected=True)

# Y축으로 올라가는 공 (vy <= 0) - 발동 안함
test_scenario("위로 올라가는 공", 200, 680, -5, -10, 710, expected=False)
test_scenario("정지한 공", 200, 680, -5, 0, 710, expected=False)

print("\n" + "=" * 60)
print("테스트 2: miss_at_player_x 예측 시스템")
print("=" * 60)

# X축 도달 시점 예측
test_scenario("X축 도달시 차단 가능", 100, 680, -10, 5, 710, expected=False)
test_scenario("X축 도달시 차단 불가", 100, 500, -10, 5, 710, expected=True)

# 오른쪽으로 가는 공 (vx >= 0) - X축 예측 무의미
test_scenario("오른쪽으로 가는 공", 100, 680, 10, 5, 710, expected=False)

print("\n" + "=" * 60)
print("테스트 3: 동적 상태 추적 (갭 축소 감지)")
print("=" * 60)

# 첫 프레임 - 상태 기록
test_scenario("첫 프레임 (상태 기록)", 200, 600, -5, 10, 710, expected=False)

# 두 번째 프레임 - 플레이어가 공을 향해 이동
mock_main.PLAYER.centery = 650  # 플레이어가 위로 60px 이동
test_scenario("갭 축소 중 (안전)", 195, 610, -5, 10, 650, expected=False)

# 갭이 넓어지는 상황
mock_main.PLAYER.centery = 710  # 플레이어가 다시 아래로
test_scenario("갭 확대 중 (위험)", 190, 620, -5, 10, 710, expected=False)

print("\n" + "=" * 60)
print("테스트 4: 바닥 임박 긴급 발동")
print("=" * 60)

# 바닥 임박 (frames_to_floor <= 16)
test_scenario("바닥 임박 - 긴급", 200, 720, -5, 10, 600, expected=True)
test_scenario("바닥 아직 여유", 200, 600, -5, 10, 710, expected=False)

# urgent_override 플래그 확인
if smartphone.urgent_override:
    print("✅ urgent_override 플래그 설정됨 (쿨다운 무시)")

print("\n" + "=" * 60)
print("테스트 5: 대시 상태 반영")
print("=" * 60)

# 대시 중이면 더 빠른 속도 적용
test_scenario("대시 없음 - 도달 불가", 200, 680, -5, 20, 500, expected=True, rolling=False)
test_scenario("대시 중 - 도달 가능", 200, 680, -5, 20, 500, expected=False, rolling=True)

print("\n" + "=" * 60)
print("테스트 6: 플레이어가 친 공 (발동 안함)")
print("=" * 60)

mock_main.last_hit_by = "player"
test_scenario("플레이어가 친 공", 200, 680, -5, 10, 710, expected=False)

mock_main.last_hit_by = "boss"
test_scenario("보스가 친 공", 200, 680, -5, 10, 710, expected=False)

print("\n" + "=" * 60)
print("테스트 7: 화면 영역 체크 (90% 이하에서만)")
print("=" * 60)

# 화면 높이 750의 60% = 450 (수정된 값)
test_scenario("화면 상단 (발동 안함)", 200, 400, -5, 10, 710, expected=False)  # y=400 < 450
test_scenario("화면 하단 (발동 가능)", 200, 700, -5, 10, 600, expected=True)  # y=700 > 450

print("\n" + "=" * 60)
print("테스트 8: 극한 상황 추가 테스트")
print("=" * 60)

# 바닥 임박 상황 더 명확히
test_scenario("바닥 3프레임 전", 200, 735, -5, 5, 600, expected=True)  # (750-735)/5 = 3프레임
test_scenario("Y거리 180 - 도달불가", 200, 680, -5, 10, 500, expected=True)  # 180px 차이

print("\n" + "=" * 60)
print("코덱스 로직 테스트 완료!")
print("=" * 60)