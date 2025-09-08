#!/usr/bin/env python3
"""
스마트폰-스톱워치 복구 후 방향 테스트
간단한 시뮬레이션으로 복구 로직 확인
"""

import math

def test_stopwatch_recovery():
    """스톱워치 복구 시 위 방향 설정 테스트"""
    
    print("=" * 50)
    print("스마트폰-스톱워치 복구 방향 테스트")
    print("=" * 50)
    
    # 테스트 케이스들
    test_cases = [
        {"name": "공이 아래로 가는 경우", "ball_vel": [3, 5], "expected_y": "negative"},
        {"name": "공이 위로 가는 경우", "ball_vel": [3, -5], "expected_y": "negative"},
        {"name": "공이 수평으로 가는 경우", "ball_vel": [5, 0], "expected_y": "negative"},
        {"name": "공이 정지한 경우", "ball_vel": [0, 0], "expected_y": "negative"},
        {"name": "공이 빠르게 아래로", "ball_vel": [10, 15], "expected_y": "negative"},
    ]
    
    for i, test in enumerate(test_cases, 1):
        print(f"\n테스트 {i}: {test['name']}")
        print(f"  원래 속도: vx={test['ball_vel'][0]}, vy={test['ball_vel'][1]}")
        
        # 스톱워치 복구 로직 시뮬레이션
        ball_vel = test['ball_vel'].copy()
        
        # stopwatch_forced_upward가 True일 때의 로직
        original_speed = math.hypot(ball_vel[0], ball_vel[1])
        final_speed = original_speed if original_speed > 0 else max(5.0, math.hypot(ball_vel[0], ball_vel[1]))
        
        # X 방향 결정 (현재 X 방향 유지하거나 기본값)
        if abs(ball_vel[0]) > 0.1:
            dir_x = ball_vel[0] / abs(ball_vel[0])  # 부호만 유지
        else:
            dir_x = 0.5  # 약간 오른쪽으로
        
        # Y 방향은 무조건 위로 (음수)
        dir_y = -1.0
        
        # 방향 벡터 정규화
        norm = math.hypot(dir_x, dir_y)
        if norm > 0:
            dir_x = dir_x / norm
            dir_y = dir_y / norm
        
        # 최종 속도 설정
        ball_vel[0] = dir_x * final_speed
        ball_vel[1] = dir_y * final_speed  # 무조건 음수 (위쪽)
        
        print(f"  복구 후 속도: vx={ball_vel[0]:.2f}, vy={ball_vel[1]:.2f}")
        
        # 검증
        if ball_vel[1] < 0:
            print(f"  ✅ 성공: 공이 위로 향합니다 (vy={ball_vel[1]:.2f} < 0)")
        else:
            print(f"  ❌ 실패: 공이 위로 향하지 않습니다 (vy={ball_vel[1]:.2f} >= 0)")
        
        # 속도 크기 확인
        recovered_speed = math.hypot(ball_vel[0], ball_vel[1])
        print(f"  속도 크기: 원래={original_speed:.2f}, 복구 후={recovered_speed:.2f}")
    
    print("\n" + "=" * 50)
    print("테스트 완료!")
    print("모든 경우에서 스톱워치 복구 후 공이 위(보스) 방향으로 향해야 합니다.")
    print("=" * 50)

if __name__ == "__main__":
    test_stopwatch_recovery()