#!/usr/bin/env python3
"""
아카데미 스킬 마스터 보너스 테스트
max_level이 5인 스킬을 5/5로 만들면 레벨 6 효과를 받는지 확인
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from academy import skill_system, get_skill_bonus

def test_master_bonus():
    """마스터 보너스 시스템 테스트"""
    print("=== 아카데미 스킬 마스터 보너스 테스트 ===\n")
    
    # 테스트할 스킬 목록 (max_level이 5인 스킬들)
    test_skills = [
        {"id": "dash_lightweight", "name": "경량화", "multiplier": 0.07},
        {"id": "dash_module_control", "name": "모듈제어", "multiplier": 0.10},
        {"id": "dash_jump", "name": "도약", "multiplier": 0.04},
        {"id": "dash_battery_pack", "name": "배터리팩", "multiplier": 0.08},
        {"id": "dash_acceleration", "name": "버스트업", "multiplier": 0.6},
        {"id": "item_spawn", "name": "아이템 스폰", "multiplier": 0.1},
        {"id": "item_cooldown", "name": "아이템 쿨다운", "multiplier": 0.6},
        {"id": "item_slot", "name": "아이템 슬롯", "multiplier": 1},
        {"id": "paddle_gauge", "name": "패들 게이지", "multiplier": 5},
        {"id": "paddle_speed", "name": "패들 속도", "multiplier": 0.5},
        {"id": "paddle_size", "name": "패들 크기", "multiplier": 0.02},
        {"id": "paddle_max_gauge", "name": "최대 게이지", "multiplier": 30}
    ]
    
    for skill_info in test_skills:
        skill_id = skill_info["id"]
        skill_name = skill_info["name"]
        multiplier = skill_info["multiplier"]
        
        # 스킬 데이터 가져오기
        skill_data = skill_system.get_skill_data(skill_id)
        if not skill_data:
            print(f"❌ {skill_name} ({skill_id}): 스킬 데이터 없음")
            continue
            
        if skill_data.get("max_level") != 5:
            continue  # max_level이 5가 아닌 스킬은 건너뛰기
        
        print(f"테스트 스킬: {skill_name} ({skill_id})")
        print(f"  max_level: {skill_data.get('max_level')}")
        
        # 초기화
        skill_system.reset_all()
        skill_system.skill_points = 100  # 충분한 스킬 포인트 제공
        
        # 레벨별 보너스 확인
        for level in range(1, 6):
            # 스킬 업그레이드
            if skill_system.can_upgrade_skill(skill_id):
                skill_system.upgrade_skill(skill_id)
            
            current_level = skill_system.get_skill_level(skill_id)
            bonus = get_skill_bonus(skill_id)
            expected_normal = current_level * multiplier
            
            print(f"  레벨 {current_level}: 보너스 = {bonus:.2f}", end="")
            
            # 레벨 5일 때 마스터 보너스 확인
            if current_level == 5:
                expected_master = 6 * multiplier  # 레벨 6 효과
                if abs(bonus - expected_master) < 0.001:
                    print(f" ✅ 마스터 보너스 적용! (레벨 6 효과: {expected_master:.2f})")
                else:
                    print(f" ❌ 마스터 보너스 미적용 (기대값: {expected_master:.2f})")
            else:
                print(f" (정상: {expected_normal:.2f})")
        
        print()
    
    print("=== 테스트 완료 ===")

if __name__ == "__main__":
    test_master_bonus()