"""
바닥 근처 실제 위험 상황 테스트
스크린샷과 유사한 상황 재현
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
print("바닥 근처 실제 위험 상황 테스트")
print("=" * 60)

def test_scenario(name, ball_x, ball_y, ball_vx, ball_vy, paddle_y, player_speed, expected):
    """실제 게임 시나리오 테스트"""
    # 상태 초기화
    smartphone.last_y_gap = None
    smartphone.closing_streak = 0
    smartphone.urgent_override = False
    
    result = smartphone.check_danger_v2(ball_x, ball_y, ball_vx, ball_vy, paddle_y, 50, player_speed)
    
    # 상태 정보 계산
    y_distance = abs(ball_y - paddle_y)
    frames_to_floor = (750 - ball_y) / max(abs(ball_vy), 0.1) if ball_vy > 0 else 999
    t_to_player_x = (ball_x - 50) / abs(ball_vx) if ball_vx < 0 else 999
    
    symbol = "✅" if result == expected else "❌"
    print(f"\n{symbol} {name}")
    print(f"   공 위치: ({ball_x:.0f}, {ball_y:.0f})")
    print(f"   공 속도: ({ball_vx:.1f}, {ball_vy:.1f})")
    print(f"   패들Y: {paddle_y:.0f}, 플레이어 속도: {player_speed}")
    print(f"   Y 거리: {y_distance:.0f}px")
    print(f"   바닥까지: {frames_to_floor:.1f} 프레임")
    print(f"   X 도달: {t_to_player_x:.1f} 프레임")
    print(f"   결과: {'🚨 발동!' if result else '대기'} (예상: {'발동' if expected else '대기'})")
    
    if result != expected:
        print(f"   ⚠️ 예상과 다름!")
    
    return result == expected

print("\n" + "=" * 60)
print("시나리오 1: 스크린샷 상황 재현")
print("(공이 바닥 근처, 플레이어가 도달 불가)")
print("=" * 60)

# 스크린샷 상황: 공이 바닥 근처(Y~700), 플레이어 패들도 바닥(Y~700)
# 공이 왼쪽으로 이동 중, 플레이어가 미스할 가능성 높음
test_scenario(
    "바닥 근처 좌측 이동",
    ball_x=200,    # 좌측으로 이동 중
    ball_y=710,    # 바닥 근처
    ball_vx=-8,    # 좌측으로
    ball_vy=5,     # 아래로
    paddle_y=700,  # 패들 위치
    player_speed=7,
    expected=True  # 위험하므로 발동해야 함
)

test_scenario(
    "바닥 매우 가까이",
    ball_x=150,
    ball_y=730,    # 거의 바닥
    ball_vx=-10,
    ball_vy=3,
    paddle_y=700,
    player_speed=7,
    expected=True
)

print("\n" + "=" * 60)
print("시나리오 2: Y=680 이상 영역")
print("(특별 처리 영역)")
print("=" * 60)

test_scenario(
    "Y=680 경계",
    ball_x=180,
    ball_y=680,
    ball_vx=-8,
    ball_vy=5,
    paddle_y=700,
    player_speed=7,
    expected=True
)

test_scenario(
    "Y=690 위험",
    ball_x=160,
    ball_y=690,
    ball_vx=-10,
    ball_vy=8,
    paddle_y=700,
    player_speed=7,
    expected=True
)

test_scenario(
    "Y=700 긴급",
    ball_x=140,
    ball_y=700,
    ball_vx=-12,
    ball_vy=5,
    paddle_y=700,
    player_speed=7,
    expected=True
)

print("\n" + "=" * 60)
print("시나리오 3: X축 가까운 상황")
print("(교차 임박)")
print("=" * 60)

test_scenario(
    "X=100 임박",
    ball_x=100,
    ball_y=690,
    ball_vx=-15,
    ball_vy=10,
    paddle_y=700,
    player_speed=7,
    expected=True
)

test_scenario(
    "X=80 매우 임박",
    ball_x=80,
    ball_y=710,
    ball_vx=-10,
    ball_vy=5,
    paddle_y=700,
    player_speed=7,
    expected=True
)

print("\n" + "=" * 60)
print("시나리오 4: 타격 가능한 상황")
print("(발동하면 안 됨)")
print("=" * 60)

test_scenario(
    "패들 범위 내",
    ball_x=200,
    ball_y=705,    # 패들 중심 근처
    ball_vx=-5,    # 천천히 접근
    ball_vy=2,
    paddle_y=700,
    player_speed=7,
    expected=False  # 타격 가능하므로 발동 안 함
)

test_scenario(
    "충분한 시간",
    ball_x=300,
    ball_y=680,
    ball_vx=-3,    # 매우 천천히
    ball_vy=5,
    paddle_y=700,
    player_speed=7,
    expected=False  # 충분히 도달 가능
)

print("\n" + "=" * 60)
print("시나리오 5: 디버그 - 실제 위험 상황")
print("=" * 60)

# 실제로 위험한 상황들을 더 상세히 테스트
test_scenario(
    "빠른 공 + 먼 거리",
    ball_x=120,
    ball_y=720,    # 바닥 근처
    ball_vx=-20,   # 매우 빠름
    ball_vy=10,
    paddle_y=680,  # 패들이 위에 있음
    player_speed=7,
    expected=True
)

test_scenario(
    "Y축 갭 큼",
    ball_x=150,
    ball_y=730,
    ball_vx=-8,
    ball_vy=5,
    paddle_y=650,  # 패들이 멀리 있음
    player_speed=7,
    expected=True
)

print("\n" + "=" * 60)
print("완료!")
print("=" * 60)