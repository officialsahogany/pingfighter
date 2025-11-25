#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
번화가 시스템 테스트 스크립트
Downtown System Test Script
"""

import pygame
import sys
import os

# 프로젝트 루트 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from downtown import DowntownManager
from downtown.constants import SCREEN_WIDTH, SCREEN_HEIGHT

def main():
    """메인 테스트 함수"""
    pygame.init()
    pygame.display.set_caption("🏙️ 번화가 시스템 테스트 - PingFighter Downtown")

    # 화면 설정
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))

    # 캐릭터 타입 선택
    print("\n캐릭터를 선택하세요:")
    print("  1: 스매셔 (Smasher)")
    print("  2: 코만도 (Soldier)")
    print("  3: 발토르 (Blacksmith)")
    print("  Enter: 스매셔 (기본)")

    try:
        char_input = input("\n캐릭터 번호: ").strip()
        char_map = {'1': 'smasher', '2': 'soldier', '3': 'blacksmith'}
        character_type = char_map.get(char_input, 'smasher')
    except:
        character_type = 'smasher'

    print(f"✅ 선택된 캐릭터: {character_type}")

    # 플레이어 초기 데이터
    player_data = {
        'gold': 1500,
        'items': ['speed_potion', 'health_pack'],
        'buffs': [],
        'character_type': character_type  # 선택한 캐릭터
    }

    # 테스트할 스테이지 선택
    print("=" * 50)
    print("🏙️ 번화가 시스템 테스트")
    print("=" * 50)
    print("\n조작법:")
    print("  방향키/WASD - 이동")
    print("  Z - 상호작용 (건물 입장)")
    print("  TAB - 인벤토리")
    print("  ESC - 메뉴/나가기")
    print("\n테스트할 스테이지를 선택하세요:")
    print("  1-5: 해당 스테이지")
    print("  Enter: 스테이지 1")

    try:
        stage_input = input("\n스테이지 번호: ").strip()
        stage_number = int(stage_input) if stage_input else 1
        stage_number = max(1, min(10, stage_number))
    except ValueError:
        stage_number = 1

    print(f"\n🚀 스테이지 {stage_number} 시작...")

    # 번화가 매니저 초기화
    manager = DowntownManager(screen)
    manager.initialize(stage_number=stage_number, player_data=player_data)

    # 메인 루프 실행
    result = manager.run()

    # 결과 출력
    print("\n" + "=" * 50)
    print("📊 번화가 탐험 결과")
    print("=" * 50)

    if result:
        print(f"  방문한 건물: {len(result.get('visited_buildings', []))}")
        for building in result.get('visited_buildings', []):
            print(f"    - {building}")
        print(f"  획득 골드: {result.get('gold_earned', 0)}")
        print(f"  소비 골드: {result.get('gold_spent', 0)}")
        print(f"  획득 아이템: {len(result.get('items_obtained', []))}")
        print(f"  획득 버프: {len(result.get('buffs_obtained', []))}")
    else:
        print("  (취소됨)")

    pygame.quit()
    print("\n테스트 완료!")

def test_map_generation():
    """맵 생성 테스트"""
    print("\n" + "=" * 50)
    print("🗺️ 맵 생성 테스트")
    print("=" * 50)

    from downtown.map_generator import DowntownMap

    for stage in range(1, 6):
        map_obj = DowntownMap(stage_number=stage)
        print(f"\n스테이지 {stage}:")
        print(f"  테마: {map_obj.theme}")
        print(f"  건물 수: {len(map_obj.buildings)}")
        print(f"  건물 목록:")
        for btype, x, y, w, h in map_obj.buildings:
            print(f"    - {btype}: ({x}, {y}) {w}x{h}")
        print(f"  스폰: {map_obj.spawn_point}")
        print(f"  출구: {map_obj.exit_point}")

def test_action_points():
    """행동 포인트 테스트"""
    print("\n" + "=" * 50)
    print("⭐ 행동 포인트 테스트")
    print("=" * 50)

    from downtown.action_points import ActionPointSystem

    ap = ActionPointSystem()

    print(f"\n초기 AP: {ap.current_ap}/{ap.max_ap}")

    # 스테이지별 리셋 테스트
    for stage in [1, 3, 5, 9]:
        ap.reset(stage)
        print(f"스테이지 {stage} 리셋 후: {ap.current_ap}/{ap.max_ap}")

    # AP 사용 테스트
    ap.reset(1)
    print(f"\nAP 사용 테스트:")
    print(f"  현재: {ap.current_ap}")

    for i in range(6):
        if ap.use_ap(1):
            print(f"  1 AP 사용 → 남은 AP: {ap.current_ap}")
        else:
            print(f"  AP 부족! 남은 AP: {ap.current_ap}")

    print(f"  소진 여부: {ap.is_exhausted()}")

if __name__ == "__main__":
    # 인자 확인
    if len(sys.argv) > 1:
        if sys.argv[1] == "--map":
            test_map_generation()
        elif sys.argv[1] == "--ap":
            test_action_points()
        elif sys.argv[1] == "--all":
            test_map_generation()
            test_action_points()
            print("\n" + "=" * 50)
            print("실제 게임 테스트를 시작합니다...")
            print("=" * 50)
            main()
        else:
            print("사용법:")
            print("  python test_downtown.py        # 게임 테스트")
            print("  python test_downtown.py --map  # 맵 생성 테스트")
            print("  python test_downtown.py --ap   # AP 시스템 테스트")
            print("  python test_downtown.py --all  # 전체 테스트")
    else:
        main()
