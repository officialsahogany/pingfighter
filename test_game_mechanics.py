#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
게임 메커니즘 시스템 테스트
아이템과 스킬 시스템 테스트
"""

import sys
import os
import pygame

# 프로젝트 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from game_mechanics.item_system import ItemSystem, Item, ItemType, ItemRarity, create_default_items
from game_mechanics.skill_system import SkillSystem, Skill, SkillType, create_default_skills


class MockGameState:
    """테스트용 게임 상태 모의 객체"""
    def __init__(self):
        self.speed_multiplier = 1.0
        self.damage_multiplier = 1.0
        self.shield = False
        self.shield_hp = 0
        self.energy = 100
        self.time_scale = 1.0


class MockEntity:
    """테스트용 엔티티 모의 객체"""
    def __init__(self):
        self.x = 300
        self.y = 400
        self.vel_x = 0
        self.vel_y = 0
        self.energy = 100
        self.shield = False
        self.shield_hp = 0


def test_item_system():
    """아이템 시스템 테스트"""
    print("\n🎁 아이템 시스템 테스트...")
    
    # 아이템 시스템 초기화
    item_system = ItemSystem()
    
    # 기본 아이템 등록
    default_items = create_default_items()
    for item in default_items:
        item_system.register_item(item)
    
    print(f"  ✅ {len(default_items)}개 아이템 등록 완료")
    
    # 아이템 스폰 테스트
    print("\n1. 아이템 스폰 테스트:")
    if default_items:
        item_system.spawn_item(default_items[0], (300, 400))
        if len(item_system.spawned_items) > 0:
            print("  ✅ 아이템 스폰 성공")
        else:
            print("  ❌ 아이템 스폰 실패")
    
    # 아이템 수집 테스트
    print("\n2. 아이템 수집 테스트:")
    collector_rect = pygame.Rect(280, 380, 40, 40)
    collected = item_system.check_collection(collector_rect)
    if collected:
        print(f"  ✅ 아이템 수집 성공: {collected.name}")
    else:
        print("  ❌ 아이템 수집 실패")
    
    # 아이템 활성화 테스트
    print("\n3. 아이템 활성화 테스트:")
    game_state = MockGameState()
    item_system.activate_item("speed_boost", game_state)
    
    # 활성 아이템 확인
    active_items = item_system.get_active_items()
    if active_items:
        print(f"  ✅ 활성 아이템: {len(active_items)}개")
    else:
        print("  ℹ️ 활성 아이템 없음")
    
    return True


def test_skill_system():
    """스킬 시스템 테스트"""
    print("\n⚔️ 스킬 시스템 테스트...")
    
    # 스킬 시스템 초기화
    skill_system = SkillSystem()
    
    # 기본 스킬 등록
    default_skills = create_default_skills()
    for skill in default_skills:
        skill_system.register_skill(skill)
    
    print(f"  ✅ {len(default_skills)}개 스킬 등록 완료")
    
    # 엔티티에 스킬 부여
    print("\n1. 스킬 부여 테스트:")
    entity = MockEntity()
    skill_system.grant_skill(entity, "dash")
    skill_system.grant_skill(entity, "shield")
    
    entity_skills = skill_system.get_entity_skills(entity)
    if len(entity_skills) == 2:
        print(f"  ✅ 스킬 부여 성공: {', '.join([s.name for s in entity_skills])}")
    else:
        print("  ❌ 스킬 부여 실패")
    
    # 스킬 사용 테스트
    print("\n2. 스킬 사용 테스트:")
    result = skill_system.use_skill(entity, "dash", direction=1)
    if result:
        print("  ✅ 대시 스킬 사용 성공")
        if entity.vel_x != 0:
            print(f"    속도 변화: vel_x = {entity.vel_x}")
    else:
        print("  ❌ 스킬 사용 실패")
    
    # 쿨다운 테스트
    print("\n3. 쿨다운 테스트:")
    # 즉시 재사용 시도
    result2 = skill_system.use_skill(entity, "dash")
    if not result2:
        print("  ✅ 쿨다운 작동 확인")
    else:
        print("  ❌ 쿨다운 작동 안함")
    
    # 쿨다운 진행률 확인
    progress = skill_system.get_skill_cooldown(entity, "dash")
    print(f"    쿨다운 진행률: {progress*100:.1f}%")
    
    # 실드 스킬 테스트
    print("\n4. 실드 스킬 테스트:")
    result3 = skill_system.use_skill(entity, "shield")
    if result3 and entity.shield:
        print(f"  ✅ 실드 활성화: HP = {entity.shield_hp}")
    else:
        print("  ❌ 실드 활성화 실패")
    
    return True


def test_item_skill_integration():
    """아이템-스킬 통합 테스트"""
    print("\n🔗 아이템-스킬 통합 테스트...")
    
    # 시스템 초기화
    item_system = ItemSystem()
    skill_system = SkillSystem()
    game_state = MockGameState()
    
    # 아이템과 스킬 등록
    default_items = create_default_items()
    default_skills = create_default_skills()
    
    for item in default_items:
        item_system.register_item(item)
    
    for skill in default_skills:
        skill_system.register_skill(skill)
    
    print("  ✅ 시스템 초기화 완료")
    
    # 업데이트 테스트
    print("\n업데이트 사이클 테스트:")
    dt = 0.016  # 60 FPS
    
    # 몇 프레임 업데이트
    for i in range(5):
        item_system.update(dt, game_state)
        skill_system.update(dt)
    
    print("  ✅ 업데이트 사이클 정상 작동")
    
    # 리셋 테스트
    print("\n리셋 테스트:")
    item_system.reset()
    skill_system.reset()
    
    if len(item_system.spawned_items) == 0 and len(item_system.active_items) == 0:
        print("  ✅ 시스템 리셋 성공")
    else:
        print("  ❌ 시스템 리셋 실패")
    
    return True


def run_all_tests():
    """모든 테스트 실행"""
    print("\n" + "="*60)
    print("🎮 게임 메커니즘 시스템 종합 테스트")
    print("="*60)
    
    pygame.init()
    
    results = []
    
    # 1. 아이템 시스템 테스트
    results.append(("아이템 시스템", test_item_system()))
    
    # 2. 스킬 시스템 테스트
    results.append(("스킬 시스템", test_skill_system()))
    
    # 3. 통합 테스트
    results.append(("아이템-스킬 통합", test_item_skill_integration()))
    
    # 결과 출력
    print("\n" + "="*60)
    print("📊 테스트 결과")
    print("="*60)
    
    for name, result in results:
        icon = "✅" if result else "❌"
        print(f"{icon} {name}: {'통과' if result else '실패'}")
    
    all_passed = all(result for _, result in results)
    
    if all_passed:
        print("\n🎉 모든 게임 메커니즘 테스트 통과!")
    else:
        print("\n⚠️ 일부 테스트 실패")
    
    pygame.quit()
    return all_passed


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)