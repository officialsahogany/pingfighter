#!/usr/bin/env python3
"""
번화가 건물 배치 상세 테스트
"""

import sys
import os
import math

# 프로젝트 루트를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from downtown.map_generator import DowntownMap
from downtown.constants import BuildingType

def test_building_placement():
    """건물 배치 상세 테스트"""
    print("=== 번화가 건물 배치 상세 테스트 ===\n")

    # 더 많은 건물을 위해 높은 스테이지
    for stage in [1, 3, 5]:
        print(f"\n{'='*60}")
        print(f"스테이지 {stage} 테스트")
        print(f"{'='*60}\n")

        test_map = DowntownMap(stage_number=stage, seed=12345)

        spawn_tile = test_map.spawn_point
        exit_tile = test_map.exit_point

        print(f"시작 위치: {spawn_tile} (Y={spawn_tile[1]})")
        print(f"도착 위치: {exit_tile} (Y={exit_tile[1]})")
        print(f"총 건물 수: {len(test_map.buildings)}개\n")

        # 금지 영역 분석
        violations_spawn = []
        violations_exit = []
        bank_info = None

        for btype, bx, by, bw, bh in test_map.buildings:
            # 건물 중심점
            center_x = bx + bw / 2
            center_y = by + bh / 2

            # 시작 지점과의 거리
            spawn_dist = math.sqrt((center_x - spawn_tile[0])**2 + (center_y - spawn_tile[1])**2)
            # 도착 지점과의 거리
            exit_dist = math.sqrt((center_x - exit_tile[0])**2 + (center_y - exit_tile[1])**2)

            if btype == BuildingType.BANK:
                bank_info = {
                    'pos': (bx, by),
                    'dist': spawn_dist
                }
            else:
                # 금지 영역 체크 (7타일)
                if spawn_dist < 7:
                    violations_spawn.append({
                        'type': btype,
                        'pos': (bx, by),
                        'dist': spawn_dist
                    })
                if exit_dist < 7:
                    violations_exit.append({
                        'type': btype,
                        'pos': (bx, by),
                        'dist': exit_dist
                    })

        # 결과 출력
        print("🏦 은행:")
        if bank_info:
            print(f"  위치: {bank_info['pos']}")
            print(f"  시작점과 거리: {bank_info['dist']:.2f}타일")
            if bank_info['dist'] < 8:
                print(f"  ✅ 시작 지점 근처 배치 성공")
            else:
                print(f"  ⚠️  시작 지점에서 멀리 배치됨")
        else:
            print(f"  ❌ 은행이 배치되지 않음!")

        print("\n🚫 시작 지점 금지 영역 (7타일) 위반:")
        if violations_spawn:
            for v in violations_spawn:
                print(f"  ❌ {v['type']}: {v['pos']} - 거리 {v['dist']:.2f}타일")
        else:
            print(f"  ✅ 위반 없음")

        print("\n🚫 도착 지점 금지 영역 (7타일) 위반:")
        if violations_exit:
            for v in violations_exit:
                print(f"  ❌ {v['type']}: {v['pos']} - 거리 {v['dist']:.2f}타일")
        else:
            print(f"  ✅ 위반 없음")

        print("\n건물 목록:")
        for btype, bx, by, bw, bh in test_map.buildings:
            print(f"  - {btype}: ({bx}, {by}) 크기 {bw}x{bh}")

    print(f"\n{'='*60}")
    print("=== 테스트 완료 ===")

if __name__ == "__main__":
    test_building_placement()
