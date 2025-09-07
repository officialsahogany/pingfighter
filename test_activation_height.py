"""
발동 높이 문제 테스트
너무 낮은 위치에서 발동 차단하는 로직 검증
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
print("발동 높이 가드 테스트")
print("=" * 60)

def test_height(name, ball_x, ball_y, ball_vx, ball_vy, paddle_y, expected):
    """테스트 실행"""
    result = smartphone.check_danger_v2(ball_x, ball_y, ball_vx, ball_vy, paddle_y, 50, 50)
    
    # 높이 가드 계산 (업데이트된 로직)
    activation_height_ok = (ball_y <= (paddle_y + 50))  # 패들 높이 전체 허용
    
    symbol = "✅" if result == expected else "❌"
    print(f"\n{symbol} {name}")
    print(f"   공: ({ball_x}, {ball_y}), 속도: ({ball_vx}, {ball_vy})")
    print(f"   패들Y: {paddle_y}")
    print(f"   높이 가드: {'통과' if activation_height_ok else '차단'} (공Y={ball_y:.0f} <= 패들Y+50={paddle_y+50:.0f})")
    print(f"   결과: {'발동' if result else '안함'} (예상: {'발동' if expected else '안함'})")
    return result == expected

print("\n" + "=" * 60)
print("테스트 1: 바닥 근처 다양한 높이")
print("=" * 60)

# 플레이어 Y=700 기준으로 테스트
paddle_y = 700

test_height("패들 위 (Y=690)", 150, 690, -10, 10, paddle_y, expected=True)
test_height("패들 중심 (Y=700)", 150, 700, -10, 10, paddle_y, expected=True)
test_height("패들 살짝 아래 (Y=710)", 150, 710, -10, 10, paddle_y, expected=True)
test_height("패들 아래 (Y=720)", 150, 720, -10, 10, paddle_y, expected=True)  # 이제 허용
test_height("패들 아래 (Y=740)", 150, 740, -10, 10, paddle_y, expected=True)  # 이제 허용
test_height("패들 범위 밖 (Y=755)", 150, 755, -10, 10, paddle_y, expected=False)  # 차단

print("\n" + "=" * 60)
print("테스트 2: 교차 직전 긴급 발동")
print("=" * 60)

# X축 매우 가까운 상황
test_height("X=100, Y=690 (긴급)", 100, 690, -10, 10, paddle_y, expected=True)
test_height("X=100, Y=740 (긴급+높이허용)", 100, 740, -10, 10, paddle_y, expected=True)
test_height("X=100, Y=755 (긴급+높이차단)", 100, 755, -10, 10, paddle_y, expected=False)

print("\n" + "=" * 60)
print("테스트 3: 실제 스크린샷 상황 재현")
print("=" * 60)

# 스크린샷처럼 플레이어가 낮은 위치
test_height("플레이어 바닥 (Y=720)", 200, 710, -10, 10, 720, expected=True)
test_height("플레이어 바닥 (Y=730)", 200, 720, -10, 10, 730, expected=True)
test_height("플레이어 바닥 (Y=740)", 200, 730, -10, 10, 740, expected=True)

# 공이 패들보다 아래 (이제 패들+50까지 허용)
test_height("공이 패들 아래 (720 < 700+50)", 200, 720, -10, 10, 700, expected=True)
test_height("공이 패들 아래 (730 < 710+50)", 200, 730, -10, 10, 710, expected=True)
test_height("공이 패들 범위 밖 (765 > 710+50)", 200, 765, -10, 10, 710, expected=False)

print("\n" + "=" * 60)
print("테스트 4: 높이 가드 임계값")
print("=" * 60)

# 정확한 임계값 테스트 (업데이트된 로직)
paddle_y = 700
threshold = paddle_y + 50  # 750 (패들 높이 전체)

test_height(f"Y={threshold-1:.1f} (통과)", 150, threshold-1, -10, 10, paddle_y, expected=True)
test_height(f"Y={threshold:.1f} (경계)", 150, threshold, -10, 10, paddle_y, expected=True)
test_height(f"Y={threshold+1:.1f} (차단)", 150, threshold+1, -10, 10, paddle_y, expected=False)

print("\n" + "=" * 60)
print("완료!")
print("=" * 60)