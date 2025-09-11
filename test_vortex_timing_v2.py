#!/usr/bin/env python3
"""포세이돈 삼지창 회오리 타이밍 테스트 v2"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from legendary_items import PoseidonTrident
import pygame

def test_vortex_timing_v2():
    """1.3초 타이밍과 0.8초 효과 활성화 테스트"""
    print("🔱 포세이돈 삼지창 회오리 타이밍 테스트 v2")
    print("=" * 60)
    
    # 초기화
    pygame.init()
    trident = PoseidonTrident()
    trident.active = True
    
    # 대시 웨이브 트리거
    paddle_x, paddle_y = 300, 600
    trident.trigger_dash_wave(paddle_x, paddle_y)
    
    print("\n⏱️ 새로운 타이밍 테스트:")
    print("-" * 60)
    
    # 각 단계별 테스트
    phases = [
        (0, "시작"),
        (0.15, "성장 중간"),
        (0.3, "성장 완료"),
        (0.5, "유지 중간"),
        (0.8, "유지 끝 (효과 끝)"),
        (1.0, "소멸 중간"),
        (1.3, "소멸 완료")
    ]
    
    for target_time, phase_name in phases:
        # 트리거 다시
        trident.vortex_active = True
        trident.vortex_timer = 0
        trident.vortex_left_height = 0
        trident.vortex_right_height = 0
        
        # 목표 시간까지 업데이트
        frames = int(target_time * 60)
        for _ in range(frames):
            trident.update(0.016, False)
        
        print(f"\n{phase_name} (t={target_time:.2f}초):")
        print(f"  타이머: {trident.vortex_timer:.2f}초")
        print(f"  높이: 왼쪽={trident.vortex_left_height:.0f}, 오른쪽={trident.vortex_right_height:.0f}")
        print(f"  활성 상태: {trident.vortex_active}")
        
        # 공 굴절 테스트 (보스 공)
        ball_x, ball_y = 180, 550  # 왼쪽 회오리 중심
        ball_vx, ball_vy = 0, 5
        
        new_vx, new_vy = trident.apply_dash_wave_to_ball(
            ball_x, ball_y, ball_vx, ball_vy,
            paddle_x, paddle_y
        )
        
        if new_vx != ball_vx or new_vy != ball_vy:
            print(f"  굴절 효과: ✅ 활성 (속도 변화: {ball_vy:.1f} → {new_vy:.1f})")
        else:
            print(f"  굴절 효과: ❌ 비활성")
    
    # 시간별 상세 테스트
    print("\n📈 시간별 상세 분석:")
    print("-" * 60)
    
    trident.vortex_active = True
    trident.vortex_timer = 0
    trident.vortex_left_height = 0
    trident.vortex_right_height = 0
    
    for frame in range(80):  # 80프레임 = 1.33초
        trident.update(0.016, False)
        
        # 0.1초마다 출력
        if frame % 6 == 0:
            time_sec = frame / 60
            
            # 효과 테스트
            new_vx, new_vy = trident.apply_dash_wave_to_ball(
                180, 550, 0, 5, paddle_x, paddle_y
            )
            
            effect_active = (new_vy != 5)
            status = "✅" if effect_active else "❌"
            
            print(f"  {time_sec:.2f}초: 높이={trident.vortex_left_height:.0f}, "
                  f"효과={status}, 활성={trident.vortex_active}")
    
    print("\n" + "=" * 60)
    print("📊 타이밍 요약:")
    print("  성장 단계: 0.0 ~ 0.3초 (효과 활성)")
    print("  유지 단계: 0.3 ~ 0.8초 (효과 활성)")
    print("  소멸 단계: 0.8 ~ 1.3초 (효과 비활성)")
    print("  총 지속시간: 1.3초")
    print("  효과 활성 시간: 0.8초")
    print("\n✨ 테스트 완료!")

if __name__ == "__main__":
    test_vortex_timing_v2()