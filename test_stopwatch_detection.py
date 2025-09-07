#!/usr/bin/env python3
"""
스마트폰이 스톱워치를 감지하는지 테스트
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from item_effects.smartphone import Smartphone

def test_stopwatch_detection():
    """스마트폰이 스톱워치를 감지하는지 테스트"""
    phone = Smartphone()
    phone.active = True
    
    print("=" * 60)
    print("테스트: 스마트폰 스톱워치 감지")
    print("=" * 60)
    
    # Mock game state with stopwatch in active items
    game_state = {
        'current_stage': 1,
        'active_items': [
            {'name': 'stopwatch', 'effect': 'stopwatch'},  # Stopwatch in slot 0
            None,  # Empty slot 1
            None   # Empty slot 2
        ]
    }
    
    # Mock stage info with danger situation
    class MockStage:
        def __init__(self):
            self.ball_x = 70  # Close to player
            self.ball_y = 650  # In player zone
            self.ball_vx = -10  # Moving toward player
            self.ball_vy = 0
            self.paddle_y = 710
            self.paddle_size = 100
    
    # Mock main module with boss as last hitter
    class MockMainModule:
        def __init__(self):
            self.last_hit_by = "boss"
            self.PLAYER = type('obj', (object,), {'centerx': 50})()
            self.stopwatch_active = False
            self.active_item_slot = game_state['active_items']
            self.selected_item_index = 0
            
        def activate_stopwatch(self):
            print("✅ activate_stopwatch() 함수가 호출되었습니다!")
            self.stopwatch_active = True
    
    mock_main = MockMainModule()
    sys.modules['__main__'] = mock_main
    
    print("\n[시나리오 1] 스톱워치가 있고 위험 상황")
    print(f"active_items: {game_state['active_items']}")
    print(f"ball position: ({MockStage().ball_x}, {MockStage().ball_y})")
    print(f"last_hit_by: {mock_main.last_hit_by}")
    
    # Update smartphone
    phone.update(game_state, MockStage())
    
    if mock_main.stopwatch_active:
        print("\n✅ 성공: 스마트폰이 스톱워치를 정상적으로 발동했습니다!")
    else:
        print("\n❌ 실패: 스마트폰이 스톱워치를 발동하지 못했습니다.")
    
    print("\n" + "=" * 60)
    
    # Test case 2: No stopwatch
    print("\n[시나리오 2] 스톱워치가 없는 경우")
    phone.auto_activated = False  # Reset
    phone.last_activation_time = 0
    mock_main.stopwatch_active = False
    
    game_state['active_items'] = [None, None, None]  # No items
    print(f"active_items: {game_state['active_items']}")
    
    phone.update(game_state, MockStage())
    
    if not mock_main.stopwatch_active:
        print("✅ 정상: 스톱워치가 없어서 발동하지 않았습니다.")
    else:
        print("❌ 오류: 스톱워치가 없는데 발동되었습니다.")
    
    print("\n" + "=" * 60)
    print("테스트 완료!")
    print("=" * 60)

if __name__ == "__main__":
    test_stopwatch_detection()