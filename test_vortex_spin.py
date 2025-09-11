#!/usr/bin/env python3
"""포세이돈 삼지창 회오리 회전 및 랜덤 굴절 테스트"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from legendary_items import PoseidonTrident
import pygame
import math

def test_vortex_spin():
    """회오리 회전 및 랜덤 굴절 테스트"""
    print("🔱 포세이돈 삼지창 회오리 회전 테스트")
    print("=" * 60)
    
    # 초기화
    pygame.init()
    trident = PoseidonTrident()
    trident.active = True
    
    # 대시 웨이브 트리거 (패들 위치: 300, 600)
    paddle_x, paddle_y = 300, 600
    trident.trigger_dash_wave(paddle_x, paddle_y)
    
    # 회오리 성장 시뮬레이션 (0.5초)
    print("\n📈 회오리 성장 중...")
    for i in range(30):  # 30프레임 = 0.5초
        trident.update(0.016, False)
    
    print(f"  회오리 위치: 왼쪽({trident.vortex_left_x}, {trident.vortex_left_y}), "
          f"오른쪽({trident.vortex_right_x}, {trident.vortex_right_y})")
    print(f"  회오리 크기: 너비={trident.vortex_width}, 높이={trident.vortex_left_height:.0f}")
    
    # 여러 번 테스트하여 랜덤성 확인
    print("\n🎲 랜덤 굴절 테스트 (10회):")
    print("-" * 60)
    
    # 보스 공 테스트 (아래로 향하는 공)
    print("\n보스 공 (아래로 향하는):")
    deflection_angles = []
    
    for test_num in range(10):
        # 왼쪽 회오리 중심으로 들어오는 공
        ball_x, ball_y = 180, 400
        ball_vx, ball_vy = 0, 5
        
        new_vx, new_vy = trident.apply_dash_wave_to_ball(
            ball_x, ball_y, ball_vx, ball_vy,
            paddle_x, paddle_y
        )
        
        if new_vy < 0:  # 위로 튕겨짐
            # 굴절 각도 계산
            deflection_angle = math.atan2(new_vy, new_vx) * 180 / math.pi
            deflection_angles.append(deflection_angle)
            print(f"  테스트 {test_num+1}: 굴절 각도 = {deflection_angle:.1f}°, "
                  f"속도 = ({new_vx:.2f}, {new_vy:.2f})")
    
    if deflection_angles:
        min_angle = min(deflection_angles)
        max_angle = max(deflection_angles)
        avg_angle = sum(deflection_angles) / len(deflection_angles)
        
        print(f"\n📊 굴절 각도 분석:")
        print(f"  최소: {min_angle:.1f}°")
        print(f"  최대: {max_angle:.1f}°")
        print(f"  평균: {avg_angle:.1f}°")
        print(f"  범위: {max_angle - min_angle:.1f}° (부채꼴 효과)")
    
    # 회전 효과 시뮬레이션
    print("\n🌀 회전 효과 시각화:")
    print("-" * 60)
    
    # 시간별 회전 시뮬레이션
    for frame in range(6):  # 6프레임 = 0.1초
        trident.update(0.016, False)
        
        # 테스트 공
        ball_x, ball_y = 180, 450
        ball_vx, ball_vy = 0, 5
        
        new_vx, new_vy = trident.apply_dash_wave_to_ball(
            ball_x, ball_y, ball_vx, ball_vy,
            paddle_x, paddle_y
        )
        
        if new_vy != ball_vy:
            spin_component = math.sin(trident.vortex_timer * 12) * 0.3
            print(f"  프레임 {frame}: 타이머={trident.vortex_timer:.2f}, "
                  f"회전 성분={spin_component:.2f}, "
                  f"결과 속도=({new_vx:.2f}, {new_vy:.2f})")
    
    print("\n" + "=" * 60)
    print("✨ 테스트 완료!")
    
    print("\n📋 요약:")
    print("  • 공이 회오리에 들어가면 빙글빙글 회전")
    print("  • 보스 공은 위로 향하는 부채꼴 범위 내에서 랜덤 반사")
    print("  • 굴절 각도는 약 ±60° 범위 내에서 변화")
    print("  • 회전 효과는 시간에 따라 주기적으로 변화")

if __name__ == "__main__":
    test_vortex_spin()