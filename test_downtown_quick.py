#!/usr/bin/env python3
"""
번화가 시작/도착 위치 및 건물 배치 빠른 확인
"""

import sys
import os
import math

# 프로젝트 루트를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from downtown.map_generator import DowntownMap
from downtown.constants import BuildingType

def test_positions():
    """시작/도착 위치 및 건물 배치 확인"""
    print("=== 번화가 시작/도착 위치 및 건물 배치 확인 ===\n")

    # 여러 맵 생성 테스트
    for i in range(5):
        print(f"맵 #{i+1} (Seed: {i}):")
        test_map = DowntownMap(stage_number=1, seed=i)

        spawn_tile = test_map.spawn_point
        exit_tile = test_map.exit_point

        print(f"  시작: 타일 {spawn_tile} (Y={spawn_tile[1]})")
        print(f"  도착: 타일 {exit_tile} (Y={exit_tile[1]})")

        # 방향 확인
        if spawn_tile[1] > exit_tile[1]:
            print(f"  ✅ 방향: 아래(Y={spawn_tile[1]}) → 위(Y={exit_tile[1]})")
        else:
            print(f"  ❌ 방향: 위(Y={spawn_tile[1]}) → 아래(Y={exit_tile[1]})")

        # 건물 배치 확인
        print(f"\n  건물 배치 ({len(test_map.buildings)}개):")
        bank_found = False
        bank_near_spawn = False

        for btype, bx, by, bw, bh in test_map.buildings:
            # 건물 중심점
            center_x = bx + bw / 2
            center_y = by + bh / 2

            # 시작 지점과의 거리
            spawn_dist = math.sqrt((center_x - spawn_tile[0])**2 + (center_y - spawn_tile[1])**2)
            # 도착 지점과의 거리
            exit_dist = math.sqrt((center_x - exit_tile[0])**2 + (center_y - exit_tile[1])**2)

            if btype == BuildingType.BANK:
                bank_found = True
                print(f"    🏦 은행: ({bx}, {by}) - 시작점과 거리: {spawn_dist:.1f}타일")
                if spawn_dist < 8:
                    bank_near_spawn = True
                    print(f"       ✅ 시작 지점 근처에 배치됨")
            else:
                # 시작/도착 지점 근처 건물 체크 (7타일 이내)
                if spawn_dist < 7:
                    print(f"    ❌ {btype}: ({bx}, {by}) - 시작점과 거리: {spawn_dist:.1f}타일 (너무 가까움!)")
                elif exit_dist < 7:
                    print(f"    ❌ {btype}: ({bx}, {by}) - 도착점과 거리: {exit_dist:.1f}타일 (너무 가까움!)")

        if not bank_found:
            print(f"    ❌ 은행이 배치되지 않음!")
        elif not bank_near_spawn:
            print(f"    ⚠️  은행이 시작 지점에서 너무 멀리 배치됨")

        print()

    print("=== 테스트 완료 ===")

if __name__ == "__main__":
    test_positions()
