#!/usr/bin/env python3
"""
스마트폰 Y축 80프레임 조건 테스트
- Y축 이동에 80프레임 이상 필요한 경우 발동
- 공 속도와 X축 위치는 무관
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from item_effects.smartphone import Smartphone

def test_y_axis_conditions():
    """Y축 80프레임 조건 테스트"""
    phone = Smartphone()
    phone.active = True
    
    print("=" * 60)
    print("스마트폰 Y축 80프레임 조건 테스트")
    print("플레이어 이동 속도: 10 픽셀/프레임")
    print("임계값: 80프레임 (Y축 거리 800픽셀)")
    print("=" * 60)
    
    # 플레이어 위치 고정
    paddle_y = 400  # 화면 중앙
    player_x = 50
    
    test_cases = [
        # (이름, ball_x, ball_y, ball_vx, ball_vy, 예상결과)
        
        # Y축 거리 테스트 (공 속도 무관)
        ("Y축 100픽셀 차이 (10프레임)", 300, 500, -5, 0, False),  # 100/10 = 10프레임
        ("Y축 300픽셀 차이 (30프레임)", 300, 700, -5, 0, False),  # 300/10 = 30프레임
        ("Y축 500픽셀 차이 (50프레임)", 300, 900, -5, 0, False),  # 500/10 = 50프레임 (화면 밖이지만 테스트)
        ("Y축 790픽셀 차이 (79프레임)", 300, 1190, -5, 0, False),  # 790/10 = 79프레임 (임계값 미만)
        ("Y축 800픽셀 차이 (80프레임) 🚨", 300, 1200, -5, 0, True),  # 800/10 = 80프레임 (발동!)
        ("Y축 900픽셀 차이 (90프레임) 🚨", 300, 1300, -5, 0, True),  # 900/10 = 90프레임 (발동!)
        
        # 공 속도 무관 테스트 (Y축 거리가 충분하면)
        ("느린 공 + Y축 800픽셀 🚨", 300, 1200, -1, 0, True),  # 매우 느린 공도 발동
        ("빠른 공 + Y축 800픽셀 🚨", 300, 1200, -30, 0, True),  # 매우 빠른 공도 발동
        
        # X축 위치 무관 테스트 (Y축 거리가 충분하면)
        ("가까운 X + Y축 800픽셀 🚨", 100, 1200, -5, 0, True),  # X축 가까워도 발동
        ("먼 X + Y축 800픽셀 🚨", 700, 1200, -5, 0, True),  # X축 멀어도 발동
        
        # 위쪽도 같은 조건
        ("위쪽 Y축 800픽셀 차이 🚨", 300, -400, -5, 0, True),  # 400 - (-400) = 800
        
        # 추가 보호 조건: 가까이 있고 Y축 차이가 클 때
        ("가까운 공 + Y축 100픽셀", 60, 500, -10, 0, True),  # X거리 10, 도달시간 1프레임 < Y이동 10프레임
        ("가까운 공 + Y축 200픽셀", 70, 600, -10, 0, True),  # X거리 20, 도달시간 2프레임 < Y이동 20프레임
        
        # 공이 플레이어를 향하지 않는 경우 (발동 안함)
        ("오른쪽으로 가는 공", 300, 1200, 5, 0, False),  # vx > 0
        ("정지한 공", 300, 1200, 0, 0, False),  # vx = 0
        
        # 공이 플레이어 뒤에 있는 경우 (발동 안함)
        ("플레이어 뒤의 공", 40, 1200, -5, 0, False),  # x < player_x
    ]
    
    for name, ball_x, ball_y, ball_vx, ball_vy, expected in test_cases:
        result = phone.check_danger(
            ball_x, ball_y, ball_vx, ball_vy,
            paddle_y, 100, player_x
        )
        
        y_distance = abs(ball_y - paddle_y)
        frames_needed = y_distance / 10
        
        status = "✅" if result == expected else "❌"
        print(f"\n{status} {name}")
        print(f"   공 위치: ({ball_x}, {ball_y}), 속도: ({ball_vx}, {ball_vy})")
        print(f"   Y축 거리: {y_distance:.0f}픽셀, 필요 프레임: {frames_needed:.0f}")
        print(f"   결과: {'위험' if result else '안전'} (예상: {'위험' if expected else '안전'})")

def test_edge_cases():
    """경계값 테스트"""
    phone = Smartphone()
    phone.active = True
    
    print("\n" + "=" * 60)
    print("경계값 테스트")
    print("=" * 60)
    
    paddle_y = 400
    player_x = 50
    
    # 정확히 79, 80, 81 프레임 테스트
    for frames in [79, 80, 81]:
        y_distance = frames * 10  # 프레임 * 속도
        ball_y = paddle_y + y_distance
        
        result = phone.check_danger(
            300, ball_y, -5, 0,
            paddle_y, 100, player_x
        )
        
        expected = frames >= 80
        status = "✅" if result == expected else "❌"
        
        print(f"\n{status} {frames}프레임 테스트")
        print(f"   Y축 거리: {y_distance}픽셀")
        print(f"   결과: {'위험' if result else '안전'} (예상: {'위험' if expected else '안전'})")

if __name__ == "__main__":
    test_y_axis_conditions()
    test_edge_cases()
    
    print("\n" + "=" * 60)
    print("테스트 완료!")
    print("스마트폰은 이제 Y축 이동에 80프레임 이상 필요한 경우 발동합니다.")
    print("공 속도와 X축 위치는 무관합니다.")
    print("=" * 60)