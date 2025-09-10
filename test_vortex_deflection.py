#!/usr/bin/env python3
"""포세이돈 삼지창 회오리 굴절 테스트"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from legendary_items import PoseidonTrident, get_legendary_manager
import pygame

def test_vortex_deflection():
    """회오리가 공을 제대로 튕겨내는지 테스트"""
    print("🔱 포세이돈 삼지창 회오리 굴절 테스트")
    print("=" * 60)
    
    # 초기화
    pygame.init()
    trident = PoseidonTrident()
    trident.active = True
    
    # 대시 웨이브 트리거 (패들 위치: 300, 600)
    paddle_x, paddle_y = 300, 600
    trident.trigger_dash_wave(paddle_x, paddle_y)
    
    # 회오리 성장 시뮬레이션 (1초)
    print("\n📈 회오리 성장 중...")
    for i in range(60):  # 60프레임 = 1초
        trident.update(0.016, False)
        if i % 10 == 0:
            print(f"   프레임 {i}: 왼쪽 높이={trident.vortex_left_height:.0f}, "
                  f"오른쪽 높이={trident.vortex_right_height:.0f}")
    
    # 테스트 케이스들
    test_cases = [
        # (공X, 공Y, 공VX, 공VY, 설명)
        (150, 550, 0, 5, "왼쪽 회오리 중심으로 내려오는 보스 공"),
        (450, 550, 0, 5, "오른쪽 회오리 중심으로 내려오는 보스 공"),
        (150, 400, 2, 8, "왼쪽 회오리 위쪽으로 비스듬히 내려오는 공"),
        (450, 400, -2, 8, "오른쪽 회오리 위쪽으로 비스듬히 내려오는 공"),
        (300, 550, 0, 5, "회오리 밖 중앙으로 내려오는 공"),
        (150, 650, 0, -5, "왼쪽 회오리에서 올라가는 플레이어 공"),
    ]
    
    print("\n🎾 공 굴절 테스트:")
    print("-" * 60)
    
    for ball_x, ball_y, ball_vx, ball_vy, desc in test_cases:
        print(f"\n테스트: {desc}")
        print(f"  입력: 위치=({ball_x}, {ball_y}), 속도=({ball_vx:.1f}, {ball_vy:.1f})")
        
        # 굴절 적용
        new_vx, new_vy = trident.apply_dash_wave_to_ball(
            ball_x, ball_y, ball_vx, ball_vy,
            paddle_x, paddle_y
        )
        
        # 결과 확인
        if new_vx != ball_vx or new_vy != ball_vy:
            print(f"  ✅ 굴절됨: 속도=({new_vx:.1f}, {new_vy:.1f})")
            if ball_vy > 0 and new_vy < 0:
                print(f"  🎯 보스 공이 성공적으로 위로 튕겨짐!")
        else:
            print(f"  ❌ 굴절 없음: 속도 변화 없음")
    
    print("\n" + "=" * 60)
    print("✨ 테스트 완료!")
    
    # 추가 정보
    print("\n📊 회오리 정보:")
    print(f"  왼쪽 회오리: X={trident.vortex_left_x}, Y={trident.vortex_left_y}")
    print(f"  오른쪽 회오리: X={trident.vortex_right_x}, Y={trident.vortex_right_y}")
    print(f"  회오리 너비: {trident.vortex_width}")
    print(f"  최대 높이: {trident.vortex_max_height}")

if __name__ == "__main__":
    test_vortex_deflection()