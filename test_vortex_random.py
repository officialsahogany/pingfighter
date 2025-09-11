#!/usr/bin/env python3
"""포세이돈 삼지창 회오리 랜덤 굴절 테스트"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from legendary_items import PoseidonTrident
import pygame
import math

def test_vortex_random():
    """다양한 위치에서 랜덤 굴절 테스트"""
    print("🔱 포세이돈 삼지창 회오리 랜덤 굴절 테스트")
    print("=" * 60)
    
    # 초기화
    pygame.init()
    trident = PoseidonTrident()
    trident.active = True
    
    # 대시 웨이브 트리거
    paddle_x, paddle_y = 300, 600
    trident.trigger_dash_wave(paddle_x, paddle_y)
    
    # 회오리 성장
    for i in range(30):
        trident.update(0.016, False)
    
    print("\n🎲 다양한 위치에서 랜덤 굴절 테스트:")
    print("-" * 60)
    
    # 다양한 위치에서 테스트
    test_positions = [
        (170, 400, "왼쪽 회오리 왼쪽"),
        (180, 400, "왼쪽 회오리 중심"),
        (190, 400, "왼쪽 회오리 오른쪽"),
        (180, 350, "왼쪽 회오리 위쪽"),
        (180, 450, "왼쪽 회오리 아래쪽"),
        (410, 400, "오른쪽 회오리 왼쪽"),
        (420, 400, "오른쪽 회오리 중심"),
        (430, 400, "오른쪽 회오리 오른쪽"),
        (420, 350, "오른쪽 회오리 위쪽"),
        (420, 450, "오른쪽 회오리 아래쪽"),
    ]
    
    deflection_data = []
    
    for ball_x, ball_y, desc in test_positions:
        ball_vx, ball_vy = 0, 5  # 보스 공 (아래로)
        
        new_vx, new_vy = trident.apply_dash_wave_to_ball(
            ball_x, ball_y, ball_vx, ball_vy,
            paddle_x, paddle_y
        )
        
        if new_vy < 0:  # 위로 튕겨짐
            angle = math.atan2(new_vy, new_vx) * 180 / math.pi
            speed = math.sqrt(new_vx**2 + new_vy**2)
            deflection_data.append((desc, angle, new_vx, new_vy, speed))
            print(f"  {desc:20s}: 각도={angle:6.1f}°, 속도=({new_vx:5.2f}, {new_vy:5.2f})")
        else:
            print(f"  {desc:20s}: 굴절 없음")
    
    if deflection_data:
        angles = [d[1] for d in deflection_data]
        min_angle = min(angles)
        max_angle = max(angles)
        angle_range = max_angle - min_angle
        
        print(f"\n📊 굴절 분석:")
        print(f"  각도 범위: {min_angle:.1f}° ~ {max_angle:.1f}°")
        print(f"  전체 범위: {angle_range:.1f}°")
        
        # 회전 효과 확인
        print("\n🌀 시간에 따른 회전 효과:")
        for i in range(5):
            trident.update(0.016, False)
            
            # 같은 위치에서 테스트
            new_vx, new_vy = trident.apply_dash_wave_to_ball(
                180, 400, 0, 5,
                paddle_x, paddle_y
            )
            
            if new_vy < 0:
                angle = math.atan2(new_vy, new_vx) * 180 / math.pi
                print(f"  시간 {trident.vortex_timer:.2f}: 각도={angle:.1f}°")
    
    print("\n" + "=" * 60)
    print("✨ 테스트 완료!")

if __name__ == "__main__":
    test_vortex_random()