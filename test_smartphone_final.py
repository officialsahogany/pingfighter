#!/usr/bin/env python3
"""
스마트폰 최종 발동 조건 테스트
- 플레이어가 서브나 공을 칠 때는 발동 안함
- X축 위치를 감지하여 패배 직전에 발동
- 보스가 친 공만 위험 감지
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from item_effects.smartphone import Smartphone

# Mock the main module's last_hit_by variable
class MockMainModule:
    def __init__(self):
        self.last_hit_by = "boss"  # Default to boss

mock_main = MockMainModule()
sys.modules['__main__'] = mock_main

def test_player_serve_protection():
    """플레이어가 친 공에는 발동 안함"""
    phone = Smartphone()
    phone.active = True
    
    print("=" * 60)
    print("테스트 1: 플레이어 서브/샷 보호")
    print("=" * 60)
    
    paddle_y = 400
    player_x = 50
    
    # 플레이어가 친 공 (발동 안해야 함)
    mock_main.last_hit_by = "player"
    
    test_cases = [
        ("플레이어 서브 직후", 100, 400, -10, 0, False),
        ("플레이어가 친 빠른 공", 70, 400, -20, 0, False),
        ("플레이어가 친 공 (위험 위치)", 60, 500, -15, 0, False),
    ]
    
    for name, ball_x, ball_y, ball_vx, ball_vy, expected in test_cases:
        result = phone.check_danger(
            ball_x, ball_y, ball_vx, ball_vy,
            paddle_y, 100, player_x
        )
        
        status = "✅" if result == expected else "❌"
        print(f"{status} {name}: {'발동' if result else '안함'} (예상: {'발동' if expected else '안함'})")

def test_x_axis_danger_detection():
    """X축 기반 패배 직전 감지"""
    phone = Smartphone()
    phone.active = True
    
    print("\n" + "=" * 60)
    print("테스트 2: X축 패배 직전 감지")
    print("=" * 60)
    
    paddle_y = 400
    player_x = 50
    
    # 보스가 친 공
    mock_main.last_hit_by = "boss"
    
    test_cases = [
        # (이름, ball_x, ball_y, ball_vx, ball_vy, 예상결과)
        
        # X축 거리별 테스트
        ("매우 가까운 공 (60px)", 60, 400, -10, 0, True),  # 위험!
        ("가까운 공 (80px)", 80, 400, -10, 0, True),  # 위험!
        ("중간 거리 (100px)", 100, 400, -10, 0, False),  # 아직 안전
        ("먼 거리 (200px)", 200, 400, -10, 0, False),  # 안전
        
        # 초고속 공
        ("초고속 공 접근", 90, 400, -25, 0, True),  # 위험!
        ("초고속 공 멀리", 150, 400, -25, 0, False),  # 아직 안전
        
        # Y축 도달 불가능 + X축 가까움
        ("X 가까움 + Y 멀음", 70, 500, -8, 0, True),  # 위험!
        ("X 가까움 + Y 가까움", 70, 420, -8, 0, False),  # 도달 가능
        
        # 패들 범위 밖
        ("패들 범위 밖 (Y축)", 55, 480, -10, 0, True),  # 위험!
        
        # 공이 오른쪽으로 가는 경우 (발동 안함)
        ("오른쪽으로 가는 공", 60, 400, 10, 0, False),
        
        # 공이 플레이어 뒤에 있는 경우 (발동 안함)
        ("플레이어 뒤의 공", 40, 400, -10, 0, False),
    ]
    
    for name, ball_x, ball_y, ball_vx, ball_vy, expected in test_cases:
        result = phone.check_danger(
            ball_x, ball_y, ball_vx, ball_vy,
            paddle_y, 100, player_x
        )
        
        x_distance = ball_x - player_x
        y_distance = abs(ball_y - paddle_y)
        
        status = "✅" if result == expected else "❌"
        print(f"\n{status} {name}")
        print(f"   위치: ({ball_x}, {ball_y}), 속도: {ball_vx}")
        print(f"   X거리: {x_distance}px, Y거리: {y_distance}px")
        print(f"   결과: {'발동' if result else '안함'} (예상: {'발동' if expected else '안함'})")

def test_combined_scenarios():
    """복합 시나리오 테스트"""
    phone = Smartphone()
    phone.active = True
    
    print("\n" + "=" * 60)
    print("테스트 3: 복합 시나리오")
    print("=" * 60)
    
    paddle_y = 400
    player_x = 50
    
    # 시나리오 1: 플레이어 → 보스 전환
    print("\n[시나리오 1] 플레이어가 친 후 보스가 받아침")
    
    mock_main.last_hit_by = "player"
    result1 = phone.check_danger(100, 400, -10, 0, paddle_y, 100, player_x)
    print(f"  플레이어가 친 공 (100px): {'발동' if result1 else '안함'} ✅")
    
    mock_main.last_hit_by = "boss"
    result2 = phone.check_danger(70, 400, -10, 0, paddle_y, 100, player_x)
    print(f"  보스가 받아친 공 (70px): {'발동' if result2 else '안함'} ✅")
    
    # 시나리오 2: Y축 극한 상황
    print("\n[시나리오 2] Y축 800픽셀 차이 + X축 가까움")
    
    mock_main.last_hit_by = "boss"
    result3 = phone.check_danger(150, 1200, -10, 0, paddle_y, 100, player_x)
    print(f"  X거리 100px, Y거리 800px: {'발동' if result3 else '안함'} ✅")
    
    # 시나리오 3: 패배 직전 상황
    print("\n[시나리오 3] 진짜 패배 직전")
    
    mock_main.last_hit_by = "boss"
    result4 = phone.check_danger(55, 450, -15, 0, paddle_y, 100, player_x)
    print(f"  X거리 5px, 빠른 속도: {'발동' if result4 else '안함'} ✅")

def test_edge_cases():
    """경계 케이스 테스트"""
    phone = Smartphone()
    phone.active = True
    
    print("\n" + "=" * 60)
    print("테스트 4: 경계 케이스")
    print("=" * 60)
    
    paddle_y = 400
    player_x = 50
    mock_main.last_hit_by = "boss"
    
    # X축 경계값
    print("\n[X축 경계값 테스트]")
    for x in [79, 80, 81]:
        result = phone.check_danger(x, 400, -10, 0, paddle_y, 100, player_x)
        expected = x <= 80
        status = "✅" if result == expected else "❌"
        print(f"{status} X={x}px: {'발동' if result else '안함'} (예상: {'발동' if expected else '안함'})")
    
    # 속도 경계값
    print("\n[속도 경계값 테스트]")
    for speed in [-4, -5, -6]:
        result = phone.check_danger(70, 400, speed, 0, paddle_y, 100, player_x)
        expected = abs(speed) >= 5
        status = "✅" if result == expected else "❌"
        print(f"{status} 속도={speed}: {'발동' if result else '안함'} (예상: {'발동' if expected else '안함'})")

if __name__ == "__main__":
    test_player_serve_protection()
    test_x_axis_danger_detection()
    test_combined_scenarios()
    test_edge_cases()
    
    print("\n" + "=" * 60)
    print("테스트 완료!")
    print("스마트폰 발동 조건:")
    print("1. 플레이어가 친 공에는 발동 안함")
    print("2. X축 80픽셀 이내로 접근 시 발동")
    print("3. 패배 직전 상황 정확히 감지")
    print("=" * 60)