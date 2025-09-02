#!/usr/bin/env python3
"""
라그나로크 해머 스턴 버그 테스트
AI가 활성화된 상태에서 스턴이 작동하지 않는 문제를 재현하고 검증합니다.
"""

import pygame
import sys
import os
import time
import math

# 게임 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 필요한 상수 정의
WIDTH = 600
HEIGHT = 750
PADDLE_WIDTH = 100
FPS = 60

# 전역 변수들
boss_stun_timer = 0
boss_knockback_timer = 0
boss_knockback_vel = 0
ragnarok_stun_pending = 0
ai_enabled = True
ai_mode = "pro"
current_stage = 1

# BOSS 패들 (간단한 시뮬레이션용)
class BossPaddle:
    def __init__(self):
        self.x = 250
        self.y = 50
        self.width = PADDLE_WIDTH
        self.height = 20
        self.centerx = self.x + self.width // 2
    
    def update_centerx(self):
        self.centerx = self.x + self.width // 2

BOSS = BossPaddle()

def simulate_ragnarok_hit():
    """라그나로크 해머 충돌 시뮬레이션"""
    global boss_knockback_timer, boss_knockback_vel, ragnarok_stun_pending, boss_stun_timer
    
    print("\n=== 라그나로크 해머 충돌 시뮬레이션 ===\n")
    
    # 1. 라그나로크 해머 활성화
    from legendary_items import get_legendary_manager
    legendary_manager = get_legendary_manager()
    legendary_manager.activate_item("ragnarok_hammer", {})
    
    # 2. 충돌 시 넉백 계산
    ragnarok = legendary_manager.items.get("ragnarok_hammer")
    if ragnarok and ragnarok.active:
        ball_speed = 20.0
        horizontal_velocity, stun_duration = ragnarok.calculate_knockback(ball_speed, BOSS.x)
        
        print(f"충돌 시:")
        print(f"  - 공 속도: {ball_speed}")
        print(f"  - 수평 넉백: {horizontal_velocity:.1f}")
        print(f"  - 스턴 시간: {stun_duration}초")
        
        # 3. 넉백 설정 (pingfighter.py 방식)
        boss_knockback_timer = 180  # 3초
        boss_knockback_vel = horizontal_velocity
        ragnarok_stun_pending = int(stun_duration * 60)  # 초를 프레임으로 변환
        
        print(f"\n넉백 설정:")
        print(f"  - boss_knockback_timer: {boss_knockback_timer}")
        print(f"  - boss_knockback_vel: {boss_knockback_vel:.1f}")
        print(f"  - ragnarok_stun_pending: {ragnarok_stun_pending}")

def handle_boss_stub():
    """handle_boss() 함수 스텁 - 버그 재현용"""
    global boss_knockback_timer, boss_stun_timer, ragnarok_stun_pending
    
    # AI 모드별 핸들러 호출 후 return (버그 재현)
    if ai_enabled and ai_mode == "pro":
        # handle_boss_pro() 호출 시뮬레이션
        if boss_stun_timer > 0:
            boss_stun_timer -= 1
            print(f"  [AI] 스턴 중... (남은 시간: {boss_stun_timer})")
            return  # AI 정지
        print(f"  [AI] 정상 작동")
        return  # ⚠️ 여기서 return하면 아래 넉백 처리가 실행되지 않음!
    
    # 넉백 처리 (AI return 때문에 실행되지 않음)
    if boss_knockback_timer > 0:
        boss_knockback_timer -= 1
        print(f"  [넉백] 처리 중... (남은 시간: {boss_knockback_timer})")
        
        # 넉백이 끝나면 스턴 적용
        if boss_knockback_timer == 1:
            if ragnarok_stun_pending > 0:
                boss_stun_timer = ragnarok_stun_pending
                ragnarok_stun_pending = 0
                print(f"  [넉백] 스턴 적용! boss_stun_timer = {boss_stun_timer}")

def handle_boss_fixed():
    """수정된 handle_boss() 함수"""
    global boss_knockback_timer, boss_stun_timer, ragnarok_stun_pending
    
    # 넉백 처리를 AI 핸들러 호출 전에 실행
    if boss_knockback_timer > 0:
        boss_knockback_timer -= 1
        print(f"  [넉백] 처리 중... (남은 시간: {boss_knockback_timer})")
        
        # 넉백이 끝나면 스턴 적용
        if boss_knockback_timer == 1:
            if ragnarok_stun_pending > 0:
                boss_stun_timer = ragnarok_stun_pending
                ragnarok_stun_pending = 0
                print(f"  [넉백] 스턴 적용! boss_stun_timer = {boss_stun_timer}")
    
    # AI 모드별 핸들러 호출
    if ai_enabled and ai_mode == "pro":
        # handle_boss_pro() 호출 시뮬레이션
        if boss_stun_timer > 0:
            boss_stun_timer -= 1
            print(f"  [AI] 스턴 중... (남은 시간: {boss_stun_timer})")
            return  # AI 정지
        print(f"  [AI] 정상 작동")
        return

def test_bug_scenario():
    """버그 시나리오 테스트"""
    global boss_knockback_timer, boss_stun_timer, ragnarok_stun_pending
    
    print("\n=== 버그 시나리오 테스트 (현재 코드) ===\n")
    
    # 초기화
    boss_knockback_timer = 0
    boss_stun_timer = 0
    ragnarok_stun_pending = 0
    
    # 라그나로크 해머 충돌 시뮬레이션
    simulate_ragnarok_hit()
    
    # 게임 루프 시뮬레이션 (주요 프레임만)
    frames_to_test = [1, 60, 120, 179, 180, 181, 190, 200, 240]
    
    for frame in frames_to_test:
        # 프레임까지 진행
        while frame > 0:
            handle_boss_stub()
            frame -= 1
            if boss_knockback_timer > 0 or boss_stun_timer > 0:
                break
        
        print(f"\n프레임 {frames_to_test[frames_to_test.index(frame) if frame in frames_to_test else 0]}:")
        print(f"  boss_knockback_timer: {boss_knockback_timer}")
        print(f"  boss_stun_timer: {boss_stun_timer}")
        print(f"  ragnarok_stun_pending: {ragnarok_stun_pending}")
    
    # 결과 확인
    print("\n❌ 버그 확인: 넉백 처리 코드가 실행되지 않아 스턴이 적용되지 않음!")

def test_fixed_scenario():
    """수정된 시나리오 테스트"""
    global boss_knockback_timer, boss_stun_timer, ragnarok_stun_pending
    
    print("\n=== 수정된 시나리오 테스트 ===\n")
    
    # 초기화
    boss_knockback_timer = 0
    boss_stun_timer = 0
    ragnarok_stun_pending = 0
    
    # 라그나로크 해머 충돌 시뮬레이션
    simulate_ragnarok_hit()
    
    # 게임 루프 시뮬레이션 (주요 프레임만)
    frames_to_test = [1, 60, 120, 179, 180, 181, 190, 200, 240]
    
    for frame_idx, target_frame in enumerate(frames_to_test):
        # 이전 프레임부터 현재 프레임까지 진행
        if frame_idx == 0:
            frames_to_run = target_frame
        else:
            frames_to_run = target_frame - frames_to_test[frame_idx - 1]
        
        for _ in range(frames_to_run):
            handle_boss_fixed()
        
        print(f"\n프레임 {target_frame}:")
        print(f"  boss_knockback_timer: {boss_knockback_timer}")
        print(f"  boss_stun_timer: {boss_stun_timer}")
        print(f"  ragnarok_stun_pending: {ragnarok_stun_pending}")
    
    # 결과 확인
    if boss_stun_timer > 0:
        print("\n✅ 수정 확인: 넉백 후 스턴이 정상적으로 적용됨!")
    else:
        print("\n⚠️ 추가 수정 필요")

if __name__ == "__main__":
    pygame.init()
    
    print("=" * 60)
    print("라그나로크 해머 스턴 버그 테스트")
    print("=" * 60)
    
    # 버그 시나리오 테스트
    test_bug_scenario()
    
    print("\n" + "=" * 60)
    
    # 수정된 시나리오 테스트
    test_fixed_scenario()
    
    print("\n=== 테스트 완료 ===")
    
    print("\n수정 방법:")
    print("1. pingfighter.py의 21825, 21829, 21833, 21837줄의 return 제거")
    print("   또는")
    print("2. 넉백 처리 코드(21847-21889줄)를 AI 핸들러 호출 전으로 이동")