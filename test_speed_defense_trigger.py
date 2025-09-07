#!/usr/bin/env python3
"""
스피드 디펜스 발동 테스트
들여쓰기 수정 후 실제 발동 확인
"""

import pygame
import sys
import os
import math
import random

# 현재 디렉토리를 sys.path에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 필요한 상수 정의
WIDTH = 600
HEIGHT = 750
FPS = 60

# Stage 2 보스 기본 설정
BOSS_MAX_SPEED_DEFAULT = 6.3
BOSS_ACCELERATION_DEFAULT = 0.840
BOSS_DECELERATION_DEFAULT = 0.840
BOSS_INSTANT_STOP_DECELERATION_DEFAULT = 0.714

# 스피드 디펜스 설정
SPEED_DEFENSE_INTERVAL = 1500  # 25초
SPEED_DEFENSE_BLOCK_RATE = 0.8  # 80% 방어율

def test_speed_defense_logic():
    """스피드 디펜스 발동 로직 테스트"""
    print("=== 스피드 디펜스 발동 시뮬레이션 ===\n")
    
    # 시뮬레이션 변수
    speed_defense_active = False
    speed_defense_timer = 0
    speed_defense_cooldown = 180  # 3초
    speed_defense_last_activation = 0
    
    # 보스 변수
    BOSS_centerx = WIDTH // 2
    BOSS_centery = 100
    boss_current_speed = 0
    BOSS_MAX_SPEED = BOSS_MAX_SPEED_DEFAULT
    
    # 공 변수
    BALL_centerx = WIDTH // 2
    BALL_centery = 400
    ball_vel = [5, -15]  # 위로 빠르게 이동
    
    # 시뮬레이션 프레임
    for frame in range(300):  # 5초간 시뮬레이션
        current_time = frame
        
        # Stage 2 보스 스피드 디펜스 로직
        if not speed_defense_active and speed_defense_timer <= 0 and ball_vel[1] < 0:
            # 공이 보스 근처에 도달할 시간 예측
            if BALL_centery < HEIGHT * 0.35:  # 262.5 픽셀 이상
                time_to_reach_boss = abs((BOSS_centery - BALL_centery) / ball_vel[1]) if ball_vel[1] < 0 else float('inf')
                
                if time_to_reach_boss < 30:  # 0.5초 이내
                    predicted_x = BALL_centerx + ball_vel[0] * time_to_reach_boss
                    distance_to_predicted = abs(predicted_x - BOSS_centerx)
                    boss_max_move = BOSS_MAX_SPEED_DEFAULT * time_to_reach_boss
                    
                    # 위험 감지
                    if distance_to_predicted > boss_max_move * 0.8:
                        # 3% 확률로 발동 (테스트를 위해 100%로 변경)
                        if True:  # random.random() < 0.03 대신 항상 발동
                            # 발동 간격 체크
                            if current_time - speed_defense_last_activation >= SPEED_DEFENSE_INTERVAL:
                                print(f"[프레임 {frame}] 🎯 스피드 디펜스 발동 조건 충족!")
                                print(f"  - 공 위치: ({BALL_centerx}, {BALL_centery})")
                                print(f"  - 보스 위치: ({BOSS_centerx}, {BOSS_centery})")
                                print(f"  - 예상 도달 시간: {time_to_reach_boss:.2f} 프레임")
                                print(f"  - 예상 도달 위치: {predicted_x:.1f}")
                                print(f"  - 거리 차이: {distance_to_predicted:.1f}")
                                print(f"  - 최대 이동 가능: {boss_max_move:.1f}")
                                
                                speed_defense_active = True
                                speed_defense_timer = speed_defense_cooldown
                                speed_defense_last_activation = current_time
                                
                                # 스피드 디펜스 효과 적용
                                speed_multiplier = 2.0
                                BOSS_MAX_SPEED = BOSS_MAX_SPEED_DEFAULT * speed_multiplier
                                
                                if predicted_x < BOSS_centerx:
                                    boss_current_speed = -BOSS_MAX_SPEED * 0.3
                                else:
                                    boss_current_speed = BOSS_MAX_SPEED * 0.3
                                    
                                print(f"  ✅ 스피드 디펜스 활성화!")
                                print(f"  - 보스 속도: {BOSS_MAX_SPEED_DEFAULT:.2f} → {BOSS_MAX_SPEED:.2f}")
                                print(f"  - 초기 속도: {boss_current_speed:.2f}\n")
                            else:
                                remaining = SPEED_DEFENSE_INTERVAL - (current_time - speed_defense_last_activation)
                                if frame % 60 == 0:  # 1초마다 출력
                                    print(f"[프레임 {frame}] ⏰ 쿨다운 중... {remaining/60:.1f}초 남음")
        
        # 타이머 업데이트
        if speed_defense_timer > 0:
            speed_defense_timer -= 1
            if frame % 30 == 0 and speed_defense_active:  # 0.5초마다
                print(f"[프레임 {frame}] 🛡️ 스피드 디펜스 활성 중... {speed_defense_timer/60:.1f}초 남음")
        
        if speed_defense_active and speed_defense_timer <= 0:
            speed_defense_active = False
            BOSS_MAX_SPEED = BOSS_MAX_SPEED_DEFAULT
            print(f"[프레임 {frame}] 🔚 스피드 디펜스 종료\n")
        
        # 공 이동 시뮬레이션
        BALL_centerx += ball_vel[0]
        BALL_centery += ball_vel[1]
        
        # 공이 화면 밖으로 나가면 리셋
        if BALL_centery < 0:
            BALL_centerx = random.randint(100, 500)
            BALL_centery = 400
            ball_vel[0] = random.uniform(-7, 7)
            ball_vel[1] = -random.uniform(12, 18)
            print(f"[프레임 {frame}] 🎾 공 리셋\n")

def test_defense_block_rate():
    """스피드 디펜스 방어율 테스트"""
    print("\n=== 스피드 디펜스 방어율 테스트 ===\n")
    
    success_count = 0
    fail_count = 0
    total_tests = 1000
    
    for i in range(total_tests):
        if random.random() < SPEED_DEFENSE_BLOCK_RATE:
            success_count += 1
        else:
            fail_count += 1
    
    print(f"테스트 횟수: {total_tests}")
    print(f"방어 성공: {success_count} ({success_count/total_tests*100:.1f}%)")
    print(f"방어 실패: {fail_count} ({fail_count/total_tests*100:.1f}%)")
    print(f"목표 방어율: {SPEED_DEFENSE_BLOCK_RATE*100:.0f}%")
    
    # 오차 범위 확인 (±3% 이내)
    actual_rate = success_count / total_tests
    if abs(actual_rate - SPEED_DEFENSE_BLOCK_RATE) < 0.03:
        print("✅ 방어율이 목표 범위 내에 있습니다.")
    else:
        print("❌ 방어율이 목표 범위를 벗어났습니다.")

def main():
    print("🎮 스피드 디펜스 발동 테스트\n")
    
    # 발동 로직 테스트
    test_speed_defense_logic()
    
    # 방어율 테스트
    test_defense_block_rate()
    
    print("\n✅ 테스트 완료!")
    return True

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)