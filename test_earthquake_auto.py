#!/usr/bin/env python3
"""
자동화된 지진 효과 테스트
구버전과 신버전의 차이를 비교
"""

import math
import random

def test_old_clamping(ball_vel, shake_x, shake_y):
    """구버전 축별 클램프 테스트"""
    vel = ball_vel.copy()
    vel[0] += shake_x
    vel[1] += shake_y
    # 축별 클램프 (버그의 원인)
    vel[0] = max(-8, min(8, vel[0]))
    vel[1] = max(-8, min(8, vel[1]))
    return vel

def test_new_clamping(ball_vel, shake_x, shake_y):
    """신버전 벡터 크기 기반 클램프 테스트"""
    vel = ball_vel.copy()
    vel[0] += shake_x
    vel[1] += shake_y
    # 벡터 크기 기반 클램프
    max_speed = 8.0
    cur_speed = math.hypot(vel[0], vel[1])
    if cur_speed > max_speed:
        scale = max_speed / cur_speed
        vel[0] *= scale
        vel[1] *= scale
    return vel

def calculate_direction_change(original, modified):
    """방향 변화량 계산 (각도 차이)"""
    if math.hypot(original[0], original[1]) < 0.001 or math.hypot(modified[0], modified[1]) < 0.001:
        return 0
    
    # 벡터 정규화
    orig_norm = [original[0] / math.hypot(original[0], original[1]), 
                 original[1] / math.hypot(original[0], original[1])]
    mod_norm = [modified[0] / math.hypot(modified[0], modified[1]),
                modified[1] / math.hypot(modified[0], modified[1])]
    
    # 내적으로 각도 계산
    dot_product = orig_norm[0] * mod_norm[0] + orig_norm[1] * mod_norm[1]
    dot_product = max(-1, min(1, dot_product))  # 부동소수점 오차 보정
    angle_diff = math.degrees(math.acos(dot_product))
    return angle_diff

def run_test():
    """테스트 실행"""
    print("=" * 60)
    print("Stage 2 정글지진 효과 테스트")
    print("=" * 60)
    
    test_cases = [
        {"name": "느린 공", "velocity": [3.0, 2.0]},
        {"name": "중간 속도 공", "velocity": [5.0, 4.0]},
        {"name": "빠른 공 (버그 발생 조건)", "velocity": [7.5, 7.0]},
        {"name": "매우 빠른 공", "velocity": [7.9, 7.9]},
    ]
    
    for test_case in test_cases:
        print(f"\n테스트: {test_case['name']}")
        print(f"초기 속도: X={test_case['velocity'][0]:.2f}, Y={test_case['velocity'][1]:.2f}")
        print(f"초기 속력: {math.hypot(test_case['velocity'][0], test_case['velocity'][1]):.2f}")
        print("-" * 40)
        
        # 10번의 흔들림 시뮬레이션
        old_direction_changes = []
        new_direction_changes = []
        
        for i in range(10):
            # 랜덤 흔들림 생성
            shake_x = random.uniform(-3, 3)
            shake_y = random.uniform(-2, 2)
            
            # 구버전과 신버전 처리
            old_result = test_old_clamping(test_case['velocity'], shake_x, shake_y)
            new_result = test_new_clamping(test_case['velocity'], shake_x, shake_y)
            
            # 방향 변화량 계산
            old_change = calculate_direction_change(test_case['velocity'], old_result)
            new_change = calculate_direction_change(test_case['velocity'], new_result)
            
            old_direction_changes.append(old_change)
            new_direction_changes.append(new_change)
        
        # 평균 방향 변화량
        avg_old = sum(old_direction_changes) / len(old_direction_changes)
        avg_new = sum(new_direction_changes) / len(new_direction_changes)
        
        print(f"구버전 평균 방향 변화: {avg_old:.2f}°")
        print(f"신버전 평균 방향 변화: {avg_new:.2f}°")
        
        # 개선도 계산
        if avg_old > 0:
            improvement = ((avg_new - avg_old) / avg_old) * 100
            if improvement > 0:
                print(f"✅ 개선도: +{improvement:.1f}% (흔들림 증가)")
            else:
                print(f"⚠️ 변화: {improvement:.1f}%")
        
        # 버그 판정
        if avg_old < 5.0 and test_case['name'].startswith("빠른"):
            print("🐛 버그 확인: 구버전에서 흔들림이 거의 없음!")
        if avg_new > avg_old * 1.5:
            print("✨ 수정 확인: 신버전에서 흔들림이 크게 개선됨!")
    
    print("\n" + "=" * 60)
    print("테스트 완료")
    print("\n📝 결론:")
    print("- 구버전: 빠른 공일수록 축별 클램프로 인해 흔들림이 사라짐")
    print("- 신버전: 벡터 크기 기반 클램프로 모든 속도에서 흔들림 유지")
    print("=" * 60)

if __name__ == "__main__":
    # 랜덤 시드 고정 (재현 가능한 테스트)
    random.seed(42)
    run_test()