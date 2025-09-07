"""
스탑워치 안전 거리 테스트
패들과 공이 너무 가까울 때 발동하지 않는지 확인
"""

import pygame
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# 초기화
pygame.init()

# Mock 설정
class MockRect:
    def __init__(self, x, y, w=20, h=20):
        self.centerx = x
        self.centery = y
        self.x = x - w//2
        self.y = y - h//2
        self.width = w
        self.height = h

# 전역 변수 설정
sys.modules['__main__'].BALL = None
sys.modules['__main__'].PLAYER = None
sys.modules['__main__'].stopwatch_active = False
sys.modules['__main__'].stopwatch_timer = 0
sys.modules['__main__'].stopwatch_flash_timer = 0
sys.modules['__main__'].stopwatch_recovery_timer = 0
sys.modules['__main__'].stopwatch_clock_angle = 0
sys.modules['__main__'].stopwatch_original_ball_vel = None
sys.modules['__main__'].ball_vel = [10, 10]
sys.modules['__main__'].player_collision_handled = False
sys.modules['__main__'].player_collision_cooldown = 0
sys.modules['__main__'].boss_collision_cooldown = 0
sys.modules['__main__'].current_speed = 7
sys.modules['__main__'].STOPWATCH_DURATION = 120
sys.modules['__main__'].active_item_slot = [{"name": "stopwatch"}]
sys.modules['__main__'].HEIGHT = 750
sys.modules['__main__'].PADDLE_HEIGHT = 50

# play_active_item_sound 함수 모킹
def play_active_item_sound():
    pass

sys.modules['__main__'].play_active_item_sound = play_active_item_sound

# activate_stopwatch 함수 가져오기
exec("""
def activate_stopwatch():
    global stopwatch_active, stopwatch_timer, stopwatch_flash_timer
    global stopwatch_original_ball_vel, stopwatch_recovery_timer, stopwatch_clock_angle
    global ball_vel, BALL, PLAYER
    global player_collision_handled, player_collision_cooldown, boss_collision_cooldown
    global current_speed
    
    # 패들과 공 사이 안전 거리 확인
    MIN_SAFE_DISTANCE = 35  # 최소 안전 거리
    if BALL and PLAYER:
        x_distance = abs(BALL.centerx - PLAYER.centerx)
        y_distance = abs(BALL.centery - PLAYER.centery)
        
        # 너무 가까우면 발동하지 않음
        if x_distance <= MIN_SAFE_DISTANCE and y_distance <= MIN_SAFE_DISTANCE:
            print(f"[스탑워치] 발동 취소 - 패들과 너무 가까움 (X:{x_distance:.0f}, Y:{y_distance:.0f})")
            return False
    
    if not stopwatch_active and BALL:
        stopwatch_active = True
        stopwatch_timer = STOPWATCH_DURATION  # 2초
        stopwatch_recovery_timer = 0
        stopwatch_flash_timer = 10  # 화면 번쩍임 효과
        stopwatch_clock_angle = 0
        
        # 원래 공 속도 저장
        stopwatch_original_ball_vel = ball_vel.copy() if ball_vel else [0, 0]
        
        # 공 정지
        ball_vel = [0, 0]
        
        # 플레이어 이동 속도도 정지 (스탑워치 중 속도 누적 방지)
        current_speed = 0
        
        # 충돌 플래그 리셋 (스탑워치 시작 시 충돌 상태 초기화)
        player_collision_handled = False
        player_collision_cooldown = 0
        boss_collision_cooldown = 0
        
        # 효과음 재생
        play_active_item_sound()
        
        print("스탑워치 활성화!")
        return True
    
    return False
""", globals())

print("=" * 60)
print("스탑워치 안전 거리 테스트")
print("=" * 60)

def test_stopwatch(name, ball_x, ball_y, paddle_x, paddle_y, expected):
    """스탑워치 발동 테스트"""
    # 초기화
    sys.modules['__main__'].stopwatch_active = False
    sys.modules['__main__'].ball_vel = [10, 10]
    
    # 공과 패들 설정
    sys.modules['__main__'].BALL = MockRect(ball_x, ball_y)
    sys.modules['__main__'].PLAYER = MockRect(paddle_x, paddle_y, 100, 50)
    
    # 거리 계산
    x_dist = abs(ball_x - paddle_x)
    y_dist = abs(ball_y - paddle_y)
    
    # 발동 시도
    result = activate_stopwatch()
    
    # 결과 확인
    symbol = "✅" if result == expected else "❌"
    status = "발동됨" if result else "차단됨"
    
    print(f"\n{symbol} {name}")
    print(f"   공 위치: ({ball_x}, {ball_y})")
    print(f"   패들 위치: ({paddle_x}, {paddle_y})")
    print(f"   거리: X={x_dist}, Y={y_dist}")
    print(f"   결과: {status} (예상: {'발동' if expected else '차단'})")
    
    return result == expected

print("\n" + "=" * 60)
print("시나리오 1: 너무 가까운 경우 (차단되어야 함)")
print("=" * 60)

test_stopwatch("매우 가까움 (X=20, Y=20)", 100, 700, 120, 720, expected=False)
test_stopwatch("X축 가까움 (X=30)", 100, 700, 130, 750, expected=False)
test_stopwatch("Y축 가까움 (Y=30)", 100, 700, 150, 730, expected=False)
test_stopwatch("대각선 가까움 (X=35, Y=35)", 100, 700, 135, 735, expected=False)

print("\n" + "=" * 60)
print("시나리오 2: 안전 거리 (발동되어야 함)")
print("=" * 60)

test_stopwatch("X축 안전 (X=40)", 100, 700, 140, 700, expected=True)
test_stopwatch("Y축 안전 (Y=40)", 100, 700, 100, 740, expected=True)
test_stopwatch("충분한 거리 (X=50, Y=50)", 100, 700, 150, 750, expected=True)
test_stopwatch("멀리 떨어짐", 100, 600, 200, 700, expected=True)

print("\n" + "=" * 60)
print("시나리오 3: 경계 케이스")
print("=" * 60)

test_stopwatch("정확히 35픽셀 (경계)", 100, 700, 135, 735, expected=False)
test_stopwatch("36픽셀 (안전)", 100, 700, 136, 700, expected=True)
test_stopwatch("X축만 안전", 100, 700, 150, 700, expected=True)
test_stopwatch("Y축만 안전", 100, 700, 100, 750, expected=True)

print("\n" + "=" * 60)
print("시나리오 4: 스마트폰 자동 발동 상황")
print("=" * 60)

# 바닥 근처 위험 상황 시뮬레이션
test_stopwatch("바닥 근처 적절한 거리", 150, 720, 100, 700, expected=True)
test_stopwatch("바닥 근처 너무 가까움", 120, 720, 110, 710, expected=False)

print("\n" + "=" * 60)
print("테스트 완료!")
print("=" * 60)
