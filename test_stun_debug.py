#!/usr/bin/env python3
"""
라그나로크 해머 스턴 디버그 테스트
스턴이 실제로 작동하는지 상세하게 확인
"""

import pygame
import sys
import os
import time

# 게임 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

pygame.init()

print("=" * 60)
print("🔨 라그나로크 해머 스턴 디버그 테스트")
print("=" * 60)

# 1. 전역 변수 초기화
boss_stun_timer = 0
boss_knockback_timer = 0
boss_knockback_vel = 0
ragnarok_stun_pending = 0
boss_current_speed = 5.0  # 초기 속도

print(f"\n초기 상태:")
print(f"  boss_stun_timer: {boss_stun_timer}")
print(f"  boss_knockback_timer: {boss_knockback_timer}")
print(f"  boss_current_speed: {boss_current_speed}")

# 2. 라그나로크 해머 활성화
from legendary_items import get_legendary_manager
legendary_manager = get_legendary_manager()

if "ragnarok_hammer" in legendary_manager.unlocked_items:
    legendary_manager.activate_item("ragnarok_hammer", {})
    print(f"\n✅ 라그나로크 해머 활성화")
    
    ragnarok = legendary_manager.items.get("ragnarok_hammer")
    if ragnarok and ragnarok.active:
        # 3. 충돌 시뮬레이션
        ball_speed = 20
        boss_x = 150
        horizontal_velocity, stun_duration = ragnarok.calculate_knockback(ball_speed, boss_x)
        
        print(f"\n충돌 시뮬레이션:")
        print(f"  horizontal_velocity: {horizontal_velocity:.1f}")
        print(f"  stun_duration: {stun_duration}초")
        
        # 4. 넉백과 스턴 설정
        boss_knockback_timer = 180  # 3초
        boss_knockback_vel = horizontal_velocity
        ragnarok_stun_pending = int(stun_duration * 60)  # 1초 = 60프레임
        
        print(f"\n넉백 설정:")
        print(f"  boss_knockback_timer: {boss_knockback_timer}")
        print(f"  ragnarok_stun_pending: {ragnarok_stun_pending}")
        
        # 5. 프레임별 시뮬레이션
        print(f"\n프레임별 상태 변화:")
        print(f"{'프레임':>6} | {'knockback':>10} | {'stun':>5} | {'pending':>7} | {'speed':>6} | 상태")
        print("-" * 60)
        
        for frame in range(200):
            # 넉백 처리
            if boss_knockback_timer > 0:
                boss_knockback_timer -= 1
                
                # 넉백이 끝나면 스턴 적용
                if boss_knockback_timer == 1:
                    if ragnarok_stun_pending > 0:
                        boss_stun_timer = ragnarok_stun_pending
                        ragnarok_stun_pending = 0
            
            # 스턴 처리
            if boss_stun_timer > 0:
                boss_stun_timer -= 1
                boss_current_speed = 0
                status = "⚡ STUNNED"
            elif boss_knockback_timer > 0:
                status = "💨 KNOCKBACK"
            else:
                boss_current_speed = 5.0  # 정상 속도 복구
                status = "✅ NORMAL"
            
            # 주요 프레임만 출력
            if frame in [0, 1, 60, 120, 178, 179, 180, 181, 190, 199] or \
               (boss_knockback_timer == 1) or \
               (boss_stun_timer == 59) or \
               (boss_stun_timer == 1):
                print(f"{frame:6d} | {boss_knockback_timer:10d} | {boss_stun_timer:5d} | "
                      f"{ragnarok_stun_pending:7d} | {boss_current_speed:6.1f} | {status}")
        
        print("\n" + "=" * 60)
        
        # 6. 결과 분석
        print("\n📊 결과 분석:")
        if boss_stun_timer == 0 and boss_knockback_timer == 0:
            print("  ✅ 넉백과 스턴이 정상적으로 완료됨")
            print("  ✅ 보스가 정상 상태로 복귀함")
        else:
            print(f"  ⚠️ 비정상 상태:")
            print(f"    boss_stun_timer: {boss_stun_timer}")
            print(f"    boss_knockback_timer: {boss_knockback_timer}")
        
        print("\n💡 동작 원리:")
        print("  1. 충돌 시 3초(180프레임) 넉백 시작")
        print("  2. 넉백이 끝나는 시점(timer==1)에 1초(60프레임) 스턴 적용")
        print("  3. 스턴 중에는 boss_current_speed = 0")
        print("  4. 스턴이 끝나면 정상 속도로 복구")
        
        print("\n🔍 handle_boss() 함수 체크 포인트:")
        print("  1. 함수 시작 부분에서 boss_stun_timer > 0 체크")
        print("  2. 스턴 중이면 즉시 return (모든 처리 차단)")
        print("  3. AI 핸들러도 스턴 체크 (중복이지만 안전)")
        
    else:
        print("❌ 라그나로크 해머가 활성화되지 않음")
else:
    print("❌ 라그나로크 해머가 해금되지 않음")

print("\n=== 테스트 완료 ===")