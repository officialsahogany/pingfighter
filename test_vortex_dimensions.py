#!/usr/bin/env python3
"""포세이돈 삼지창 회오리 크기 테스트"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from legendary_items import PoseidonTrident
import pygame

def test_vortex_dimensions():
    """수정된 회오리 크기 테스트"""
    print("🔱 포세이돈 삼지창 회오리 크기 테스트")
    print("=" * 60)
    
    # 초기화
    pygame.init()
    trident = PoseidonTrident()
    trident.active = True
    
    # 패들 위치
    paddle_x, paddle_y = 300, 600
    
    print("\n📐 회오리 크기 설정:")
    print(f"  최대 높이: {trident.vortex_max_height}픽셀 (화면의 {trident.vortex_max_height/750*100:.1f}%)")
    print(f"  회오리 너비: {trident.vortex_width}픽셀")
    print(f"  영향 반경: {trident.vortex_width/2:.0f}픽셀")
    
    # 대시 웨이브 트리거
    trident.trigger_dash_wave(paddle_x, paddle_y)
    
    print("\n📍 회오리 위치:")
    print(f"  패들 위치: X={paddle_x}, Y={paddle_y}")
    print(f"  왼쪽 회오리: X={trident.vortex_left_x} (패들 중심 - 120)")
    print(f"  오른쪽 회오리: X={trident.vortex_right_x} (패들 중심 + 120)")
    print(f"  간격: {trident.vortex_right_x - trident.vortex_left_x}픽셀")
    
    # 회오리 완전 성장 시뮬레이션
    print("\n📈 회오리 성장 테스트:")
    for i in range(60):  # 1초 동안 업데이트
        trident.update(0.016, False)
    
    print(f"  최종 왼쪽 높이: {trident.vortex_left_height:.0f}픽셀")
    print(f"  최종 오른쪽 높이: {trident.vortex_right_height:.0f}픽셀")
    
    # 충돌 범위 테스트
    print("\n🎯 충돌 감지 테스트:")
    test_positions = [
        (180, 550, "왼쪽 회오리 중심"),
        (420, 550, "오른쪽 회오리 중심"),
        (120, 550, "왼쪽 회오리 가장자리"),
        (480, 550, "오른쪽 회오리 가장자리"),
        (300, 550, "중앙 (회오리 밖)"),
        (50, 550, "왼쪽 회오리 밖"),
        (550, 550, "오른쪽 회오리 밖"),
    ]
    
    for ball_x, ball_y, desc in test_positions:
        new_vx, new_vy = trident.apply_dash_wave_to_ball(
            ball_x, ball_y, 0, 5,
            paddle_x, paddle_y
        )
        
        if new_vy != 5:
            print(f"  ✅ {desc}: 충돌 감지됨 (X={ball_x})")
        else:
            print(f"  ❌ {desc}: 충돌 없음 (X={ball_x})")
    
    print("\n📊 요약:")
    print(f"  화면 크기: 600 x 750")
    print(f"  회오리 크기: {trident.vortex_width} x {trident.vortex_max_height}")
    print(f"  커버 범위: 좌({trident.vortex_left_x-70}~{trident.vortex_left_x+70}), "
          f"우({trident.vortex_right_x-70}~{trident.vortex_right_x+70})")
    print(f"  중앙 공백: {trident.vortex_left_x+70}~{trident.vortex_right_x-70} "
          f"({trident.vortex_right_x-70-(trident.vortex_left_x+70)}픽셀)")
    
    print("\n✨ 테스트 완료!")

if __name__ == "__main__":
    test_vortex_dimensions()