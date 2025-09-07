#!/usr/bin/env python3
"""
보스 반격 후 스마트폰 발동 테스트
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from item_effects.smartphone import Smartphone

# Mock the main module's last_hit_by variable
class MockMainModule:
    def __init__(self):
        self.last_hit_by = "player"  # 초기값은 플레이어

mock_main = MockMainModule()
sys.modules['__main__'] = mock_main

def test_boss_counterattack():
    """보스가 반격한 후 스마트폰이 발동하는지 테스트"""
    phone = Smartphone()
    phone.active = True
    
    print("=" * 60)
    print("테스트: 보스 반격 시나리오")
    print("=" * 60)
    
    paddle_y = 710  # 플레이어 Y 위치
    player_x = 50
    
    # 시나리오 1: 플레이어가 공을 친 상태
    print("\n[시나리오 1] 플레이어가 공을 친 직후")
    mock_main.last_hit_by = "player"
    result = phone.check_danger(70, 650, -10, 0, paddle_y, 100, player_x)
    print(f"결과: {'발동' if result else '안함'} (예상: 안함)")
    
    # 시나리오 2: 보스가 반격한 상태 
    print("\n[시나리오 2] 보스가 반격한 후")
    mock_main.last_hit_by = "boss"  # 보스가 공을 쳤다고 설정
    result = phone.check_danger(70, 650, -10, 0, paddle_y, 100, player_x)
    print(f"결과: {'발동' if result else '안함'} (예상: 발동)")
    
    # 시나리오 3: 다시 플레이어가 친 상태
    print("\n[시나리오 3] 플레이어가 다시 친 후")
    mock_main.last_hit_by = "player"
    result = phone.check_danger(70, 650, -10, 0, paddle_y, 100, player_x)
    print(f"결과: {'발동' if result else '안함'} (예상: 안함)")
    
    # 시나리오 4: 다시 보스가 반격
    print("\n[시나리오 4] 보스가 다시 반격")
    mock_main.last_hit_by = "boss"
    result = phone.check_danger(70, 650, -10, 0, paddle_y, 100, player_x)
    print(f"결과: {'발동' if result else '안함'} (예상: 발동)")
    
    print("\n" + "=" * 60)
    print("테스트 완료!")
    print("=" * 60)

if __name__ == "__main__":
    test_boss_counterattack()