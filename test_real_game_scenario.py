#!/usr/bin/env python3
"""
실제 게임 시나리오를 시뮬레이션하여 스마트폰 테스트
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import pygame
pygame.init()

from item_effects.smartphone import Smartphone
import items

def test_real_game_scenario():
    """실제 게임과 동일한 방식으로 스마트폰 테스트"""
    phone = Smartphone()
    phone.active = True
    
    print("=" * 60)
    print("테스트: 실제 게임 시나리오 시뮬레이션")
    print("=" * 60)
    
    # 실제 게임과 동일한 active_item_slot 구조
    active_item_slot = []
    
    # 스톱워치 아이템 찾기
    stopwatch_item = None
    for item in items.ITEM_TYPES:
        if item["name"] == "stopwatch":
            stopwatch_item = item.copy()
            break
    
    if stopwatch_item:
        # 실제 게임과 동일하게 아이템 추가
        stopwatch_item["last_use"] = 0
        stopwatch_item["x"] = 100
        stopwatch_item["y"] = 100
        active_item_slot.append(stopwatch_item)
        print(f"스톱워치 아이템 추가: {stopwatch_item['name']}")
        print(f"아이템 키: {list(stopwatch_item.keys())}")
    
    # 빈 슬롯 추가
    while len(active_item_slot) < 3:
        active_item_slot.append(None)
    
    # Mock main module
    class MockMainModule:
        def __init__(self):
            self.last_hit_by = "boss"
            self.PLAYER = type('obj', (object,), {'centerx': 50, 'centery': 710})()
            self.stopwatch_active = False
            self.active_item_slot = active_item_slot
            self.selected_item_index = 0
            self.BALL = type('obj', (object,), {'centerx': 70, 'centery': 650})()
            self.ball_vel = [-10, 0]
            
        def activate_stopwatch(self):
            print("✅ activate_stopwatch() 함수가 호출되었습니다!")
            self.stopwatch_active = True
    
    mock_main = MockMainModule()
    sys.modules['__main__'] = mock_main
    
    # 게임 상태 구성 (실제 게임과 동일)
    smartphone_state = {
        'current_stage': 1,
        'active_items': active_item_slot
    }
    
    # Stage 정보 (실제 게임과 동일)
    class StageInfo:
        def __init__(self):
            self.ball_x = 70
            self.ball_y = 650
            self.ball_vx = -10
            self.ball_vy = 0
            self.paddle_y = 710
            self.paddle_size = 100
    
    stage_info = StageInfo()
    
    print("\n현재 상황:")
    print(f"- active_item_slot 개수: {len(active_item_slot)}")
    print(f"- 슬롯 내용:")
    for i, item in enumerate(active_item_slot):
        if item:
            print(f"  슬롯 {i}: {item.get('name', 'unknown')} (타입: {type(item)})")
        else:
            print(f"  슬롯 {i}: None")
    print(f"- 공 위치: ({stage_info.ball_x}, {stage_info.ball_y})")
    print(f"- 공 속도: ({stage_info.ball_vx}, {stage_info.ball_vy})")
    print(f"- last_hit_by: {mock_main.last_hit_by}")
    
    print("\n스마트폰 업데이트 실행...")
    phone.update(smartphone_state, stage_info)
    
    if mock_main.stopwatch_active:
        print("\n✅ 성공: 스마트폰이 스톱워치를 정상적으로 발동했습니다!")
    else:
        print("\n❌ 실패: 스마트폰이 스톱워치를 발동하지 못했습니다.")
    
    print("\n" + "=" * 60)
    print("테스트 완료!")
    print("=" * 60)

if __name__ == "__main__":
    test_real_game_scenario()