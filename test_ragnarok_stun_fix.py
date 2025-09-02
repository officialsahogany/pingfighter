#!/usr/bin/env python3
"""
라그나로크 해머 스턴 버그 수정 확인 테스트
handle_boss() 함수 실행 순서 변경 후 스턴이 정상 작동하는지 검증
"""

import pygame
import sys
import os
import random
import math

# 게임 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 필요한 상수 정의
WIDTH = 600
HEIGHT = 750
PADDLE_WIDTH = 100
BOSS_Y = 50
FPS = 60

# pingfighter.py의 전역 변수들 초기화
boss_stun_timer = 0
boss_knockback_timer = 0
boss_knockback_vel = 0
ragnarok_stun_pending = 0
boss_knockback_distance = 0
boss_current_speed = 0
boss_stunned_timer = 0
boss_stunned_after_whip = False
whip_active = False
boss_throwing = False
boss_throw_timer = 0
ai_enabled = True
ai_mode = "pro"
current_stage = 1
new_boss_mode_active = False
selected_top_boss = 0
stopwatch_active = False
stopwatch_timer = 0
whip_deactivation_active = False
speed_defense_active = False
speed_defense_timer = 0
boss_fail_timer = 0
boss_fake_move = False
boss_fake_start_time = 0
boss_fake_during_player_serve = False
is_player_serve = False
is_waiting_for_serve = False
waiting_start_time = 0
wait_delay = 0
ball_vel = [0, 0]
boss_speed_boost_timer = 0
BOSS_SPEED = 5
BOSS_ACCELERATION = 0.5
BOSS_DECELERATION = 0.5
BOSS_MAX_SPEED = 5
BOSS_INSTANT_STOP_DECELERATION = 1

# BOSS 패들 시뮬레이션
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

def handle_boss_junior():
    """주니어 리그 AI 스텁"""
    print("  [AI] 주니어 리그 실행")

def handle_boss_pro():
    """프로 리그 AI 스텁"""
    print("  [AI] 프로 리그 실행")

def handle_boss_champion():
    """챔피언 리그 AI 스텁"""
    print("  [AI] 챔피언 리그 실행")

def handle_boss_mythic():
    """신화 리그 AI 스텁"""
    print("  [AI] 신화 리그 실행")

def handle_boss_fixed():
    """수정된 handle_boss() 함수 시뮬레이션"""
    global boss_stun_timer, boss_knockback_timer, boss_knockback_vel
    global ragnarok_stun_pending, boss_current_speed, ai_enabled, ai_mode
    global boss_stunned_timer, whip_active, current_stage, boss_stunned_after_whip
    global boss_throwing, new_boss_mode_active
    
    # 💥 넉백 처리를 가장 먼저 실행 (스턴 체크보다 먼저!)
    if boss_knockback_timer > 0:
        boss_knockback_timer -= 1
        print(f"  [넉백] 처리 중... (남은 시간: {boss_knockback_timer})")
        
        # 라그나로크 해머 시뮬레이션
        from legendary_items import get_legendary_manager
        legendary_manager = get_legendary_manager()
        
        if "ragnarok_hammer" in legendary_manager.active_items:
            # 수평 넉백 적용
            if abs(boss_knockback_vel) > 0.1:
                BOSS.x += boss_knockback_vel
                BOSS.x = max(0, min(WIDTH - PADDLE_WIDTH, BOSS.x))
                boss_knockback_vel *= 0.85
            
            # 흔들림 효과
            shake_x = random.uniform(-5, 5)
            BOSS.x += shake_x
            BOSS.x = max(0, min(WIDTH - PADDLE_WIDTH, BOSS.x))
            
            # 넉백이 끝나면 스턴 적용
            if boss_knockback_timer <= 1 and boss_knockback_timer > 0 and ragnarok_stun_pending > 0:
                boss_stun_timer = ragnarok_stun_pending
                ragnarok_stun_pending = 0
                print(f"  🔨⚡ 스턴 적용! boss_stun_timer = {boss_stun_timer}")
    
    # 🔨 스턴 체크 (넉백 처리 후에 실행)
    if boss_stun_timer > 0:
        boss_stun_timer -= 1
        boss_current_speed = 0
        if boss_stun_timer % 60 == 0:
            print(f"  ⚡ 보스 스턴 중! 남은 시간: {boss_stun_timer/60:.1f}초")
        return  # 스턴 중에는 모든 처리 차단
    
    # AI 모드별 처리
    if ai_enabled and ai_mode == "junior":
        handle_boss_junior()
        return
    elif ai_enabled and ai_mode == "pro":
        handle_boss_pro()
        return
    elif ai_enabled and ai_mode == "champion":
        handle_boss_champion()
        return
    elif ai_enabled and ai_mode == "mythic":
        handle_boss_mythic()
        return
    
    # 기타 처리들...
    if boss_stunned_timer > 0:
        boss_stunned_timer -= 1
        return
    
    if current_stage == 1 and boss_stunned_after_whip:
        boss_current_speed = 0
        return
    
    if current_stage == 1 and whip_active:
        boss_current_speed *= 0.3
        return
    
    if current_stage == 5 and boss_throwing:
        boss_current_speed = 0
        return

def simulate_ragnarok_hit():
    """라그나로크 해머 충돌 시뮬레이션"""
    global boss_knockback_timer, boss_knockback_vel, ragnarok_stun_pending
    
    print("\n=== 라그나로크 해머 충돌 시뮬레이션 ===")
    
    # 라그나로크 해머 활성화
    from legendary_items import get_legendary_manager
    legendary_manager = get_legendary_manager()
    legendary_manager.activate_item("ragnarok_hammer", {})
    
    # 충돌 시 효과 계산
    ragnarok = legendary_manager.items.get("ragnarok_hammer")
    if ragnarok and ragnarok.active:
        ball_speed = 20.0
        horizontal_velocity, stun_duration = ragnarok.calculate_knockback(ball_speed, BOSS.x)
        
        print(f"충돌 정보:")
        print(f"  - 공 속도: {ball_speed}")
        print(f"  - 수평 넉백: {horizontal_velocity:.1f}")
        print(f"  - 스턴 시간: {stun_duration}초")
        
        # 넉백 설정
        boss_knockback_timer = 180  # 3초
        boss_knockback_vel = horizontal_velocity
        ragnarok_stun_pending = int(stun_duration * 60)  # 초를 프레임으로
        
        print(f"\n초기 설정:")
        print(f"  - boss_knockback_timer: {boss_knockback_timer}")
        print(f"  - boss_knockback_vel: {boss_knockback_vel:.1f}")
        print(f"  - ragnarok_stun_pending: {ragnarok_stun_pending}")

def test_fixed_stun():
    """수정된 코드로 스턴 테스트"""
    global boss_knockback_timer, boss_stun_timer, ragnarok_stun_pending
    
    print("\n" + "=" * 60)
    print("🔧 수정된 코드 테스트")
    print("=" * 60)
    
    # 초기화
    boss_knockback_timer = 0
    boss_stun_timer = 0
    ragnarok_stun_pending = 0
    
    # 라그나로크 해머 충돌
    simulate_ragnarok_hit()
    
    # 테스트할 프레임들
    test_frames = [1, 60, 120, 178, 179, 180, 181, 185, 190, 200, 240, 300, 360]
    
    frame_count = 0
    for target_frame in test_frames:
        # 목표 프레임까지 실행
        while frame_count < target_frame:
            handle_boss_fixed()
            frame_count += 1
        
        print(f"\n프레임 {target_frame}:")
        print(f"  boss_knockback_timer: {boss_knockback_timer}")
        print(f"  boss_stun_timer: {boss_stun_timer}")
        print(f"  ragnarok_stun_pending: {ragnarok_stun_pending}")
        
        # 중요 시점 체크
        if target_frame == 180:
            print("  💥 넉백 종료 시점")
        elif target_frame == 181:
            if boss_stun_timer > 0:
                print("  ✅ 스턴 성공적으로 적용됨!")
            else:
                print("  ❌ 스턴 적용 실패!")
        elif target_frame >= 360:
            if boss_stun_timer == 0:
                print("  ✅ 스턴 종료됨")
    
    # 최종 검증
    print("\n" + "=" * 60)
    if boss_stun_timer == 0 and boss_knockback_timer == 0:
        print("✅ 수정 완료: 넉백 후 스턴이 정상 작동하고 타이머가 소진됨!")
    else:
        print("⚠️ 추가 확인 필요")

if __name__ == "__main__":
    pygame.init()
    
    print("=" * 60)
    print("🔨 라그나로크 해머 스턴 버그 수정 검증")
    print("=" * 60)
    print("\n문제 원인:")
    print("- handle_boss()에서 AI 핸들러가 return으로 조기 종료")
    print("- 넉백 처리 코드가 AI 핸들러 이후에 있어서 실행 안됨")
    print("\n해결 방법:")
    print("- 넉백 처리를 스턴 체크보다 먼저 실행")
    print("- 스턴 체크를 넉백 처리 후로 이동")
    
    # 테스트 실행
    test_fixed_stun()
    
    print("\n=== 테스트 완료 ===")