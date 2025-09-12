#!/usr/bin/env python3
"""
스마트폰 자동 치유 로직 테스트 (콘솔)
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from item_effects.smartphone import get_smartphone_instance

# 게임 상태 모의
class MockGameState:
    def __init__(self):
        self.active_items = []
        
    def get(self, key, default=None):
        if key == 'active_items':
            return self.active_items
        return default

# 메인 모듈 모의
class MockMainModule:
    def __init__(self):
        self.special_gauge = 100
        self.special_ready = False
        self.active_item_slot = []
        self.selected_item_index = 0
        self.SOUND_DRINK = None
        
    def get_max_gauge(self):
        return 550

# 스마트폰 테스트
def test_autoheal():
    print("=== 스마트폰 자동 치유 기능 테스트 ===\n")
    
    # 모의 모듈 설정
    main_module = MockMainModule()
    sys.modules['__main__'] = main_module
    
    # 스마트폰 인스턴스
    smartphone = get_smartphone_instance()
    game_state = MockGameState()
    
    # 스마트폰 활성화
    smartphone.activate(game_state, None)
    print("✓ 스마트폰 활성화됨\n")
    
    # 테스트 1: 게이지 120 이하, 생명수 보유
    print("테스트 1: 게이지 100, 생명수 보유")
    main_module.special_gauge = 100
    main_module.active_item_slot = [{"name": "life_elixir"}]
    game_state.active_items = [{"name": "life_elixir"}]
    smartphone.last_activation_time = 0  # 쿨타임 리셋
    
    print(f"  - 초기 게이지: {main_module.special_gauge}")
    print(f"  - 초기 아이템: {[item['name'] for item in main_module.active_item_slot]}")
    
    smartphone.update(game_state, None)
    
    print(f"  - 업데이트 후 게이지: {main_module.special_gauge}")
    print(f"  - 업데이트 후 아이템: {[item.get('name') for item in main_module.active_item_slot if item]}")
    print(f"  - 결과: {'✓ 생명수 자동 사용됨' if main_module.special_gauge > 100 else '✗ 발동 안됨'}\n")
    
    # 테스트 2: 게이지 120 이하, 에너지드링크 보유
    print("테스트 2: 게이지 80, 에너지드링크 보유")
    main_module.special_gauge = 80
    main_module.active_item_slot = [{"name": "gauge_charge"}]
    game_state.active_items = [{"name": "gauge_charge"}]
    smartphone.last_activation_time = 0
    
    print(f"  - 초기 게이지: {main_module.special_gauge}")
    print(f"  - 초기 아이템: {[item['name'] for item in main_module.active_item_slot]}")
    
    smartphone.update(game_state, None)
    
    print(f"  - 업데이트 후 게이지: {main_module.special_gauge}")
    print(f"  - 업데이트 후 아이템: {[item.get('name') for item in main_module.active_item_slot if item]}")
    print(f"  - 결과: {'✓ 에너지드링크 자동 사용됨' if main_module.special_gauge > 80 else '✗ 발동 안됨'}\n")
    
    # 테스트 3: 게이지 120 이하, 생명수+에너지드링크 보유 (생명수 우선)
    print("테스트 3: 게이지 50, 생명수+에너지드링크 모두 보유")
    main_module.special_gauge = 50
    main_module.active_item_slot = [{"name": "gauge_charge"}, {"name": "life_elixir"}]
    game_state.active_items = [{"name": "gauge_charge"}, {"name": "life_elixir"}]
    smartphone.last_activation_time = 0
    
    print(f"  - 초기 게이지: {main_module.special_gauge}")
    print(f"  - 초기 아이템: {[item['name'] for item in main_module.active_item_slot]}")
    
    old_gauge = main_module.special_gauge
    smartphone.update(game_state, None)
    
    print(f"  - 업데이트 후 게이지: {main_module.special_gauge}")
    print(f"  - 업데이트 후 아이템: {[item.get('name') for item in main_module.active_item_slot if item]}")
    gauge_increase = main_module.special_gauge - old_gauge
    if gauge_increase == 500:
        print(f"  - 결과: ✓ 생명수 우선 사용됨 (+500)\n")
    elif gauge_increase == 220:
        print(f"  - 결과: ✓ 에너지드링크 사용됨 (+220)\n")
    else:
        print(f"  - 결과: 게이지 증가량 {gauge_increase}\n")
    
    # 테스트 4: 게이지 121 초과 (발동 안함)
    print("테스트 4: 게이지 150 (121 이상)")
    main_module.special_gauge = 150
    main_module.active_item_slot = [{"name": "life_elixir"}]
    game_state.active_items = [{"name": "life_elixir"}]
    smartphone.last_activation_time = 0
    
    print(f"  - 초기 게이지: {main_module.special_gauge}")
    print(f"  - 초기 아이템: {[item['name'] for item in main_module.active_item_slot]}")
    
    smartphone.update(game_state, None)
    
    print(f"  - 업데이트 후 게이지: {main_module.special_gauge}")
    print(f"  - 업데이트 후 아이템: {[item.get('name') for item in main_module.active_item_slot if item]}")
    print(f"  - 결과: {'✓ 게이지가 충분하여 발동 안됨' if len(main_module.active_item_slot) == 1 else '✗ 잘못 발동됨'}\n")
    
    # 테스트 5: 게이지 정확히 120
    print("테스트 5: 게이지 정확히 120")
    main_module.special_gauge = 120
    main_module.active_item_slot = [{"name": "life_elixir"}]
    game_state.active_items = [{"name": "life_elixir"}]
    smartphone.last_activation_time = 0
    
    print(f"  - 초기 게이지: {main_module.special_gauge}")
    print(f"  - 초기 아이템: {[item['name'] for item in main_module.active_item_slot]}")
    
    smartphone.update(game_state, None)
    
    print(f"  - 업데이트 후 게이지: {main_module.special_gauge}")
    print(f"  - 업데이트 후 아이템: {[item.get('name') for item in main_module.active_item_slot if item]}")
    print(f"  - 결과: {'✓ 게이지 120에서 자동 사용됨' if main_module.special_gauge > 120 else '✗ 발동 안됨'}\n")
    
    print("=== 테스트 완료 ===")

if __name__ == "__main__":
    test_autoheal()