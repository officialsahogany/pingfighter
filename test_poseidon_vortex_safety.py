#!/usr/bin/env python3
"""
포세이돈의 삼지창 회오리 반사 안전성 테스트
공이 플레이어 아래로 튕기지 않는지 검증
"""
import math
import random
import sys
import os

# legendary_items 모듈 임포트를 위한 경로 설정
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

def test_vortex_reflection_safety():
    """회오리 반사 각도가 안전한지 테스트"""
    print("=" * 60)
    print("포세이돈의 삼지창 회오리 반사 안전성 테스트")
    print("=" * 60)
    
    # 테스트 파라미터
    base_angle = -math.pi / 2  # -90도 (위쪽)
    fan_spread = math.pi / 4   # 45도 (수정된 값)
    min_upward_speed = -15     # 최소 위쪽 속도 (증가됨)
    max_x_speed = 20          # 최대 X축 속도 (증가됨)
    
    # 테스트 케이스
    test_speeds = [10, 15, 20, 25]  # 다양한 공 속도
    test_count = 1000  # 각 속도별 테스트 횟수
    
    print(f"테스트 설정:")
    print(f"- 기본 반사 각도: {math.degrees(base_angle):.1f}도")
    print(f"- 부채꼴 범위: ±{math.degrees(fan_spread):.1f}도")
    print(f"- 최소 위쪽 속도: {min_upward_speed}")
    print(f"- 최대 X축 속도: {max_x_speed}")
    print()
    
    dangerous_cases = 0
    safe_cases = 0
    
    for captured_speed in test_speeds:
        print(f"\n캡처된 공 속도: {captured_speed}")
        print("-" * 40)
        
        angle_stats = {
            "min_angle": float('inf'),
            "max_angle": float('-inf'),
            "avg_angle": 0,
            "min_vy": float('inf'),
            "max_vy": float('-inf'),
            "dangerous_count": 0
        }
        
        for i in range(test_count):
            # 랜덤 오프셋 생성
            random_offset = random.uniform(-fan_spread, fan_spread)
            target_angle = base_angle + random_offset
            
            # 반사 속도 계산 (150% 증가, 최소 18, 최대 30)
            deflect_speed = max(18, min(captured_speed * 1.5, 30))
            
            # 속도 벡터 계산
            new_vx = math.cos(target_angle) * deflect_speed
            new_vy = math.sin(target_angle) * deflect_speed
            
            # Y축 속도 안전장치 적용
            if new_vy >= 0:  # 아래쪽이나 수평이면
                new_vy = min_upward_speed  # 강제로 위쪽으로
            elif new_vy > min_upward_speed:  # 위쪽이지만 너무 느리면
                new_vy = min_upward_speed
            
            # X축 속도 제한
            if abs(new_vx) > max_x_speed:
                new_vx = max_x_speed if new_vx > 0 else -max_x_speed
            
            # 통계 업데이트
            actual_angle = math.atan2(new_vy, new_vx)
            angle_deg = math.degrees(actual_angle)
            
            angle_stats["min_angle"] = min(angle_stats["min_angle"], angle_deg)
            angle_stats["max_angle"] = max(angle_stats["max_angle"], angle_deg)
            angle_stats["avg_angle"] += angle_deg
            angle_stats["min_vy"] = min(angle_stats["min_vy"], new_vy)
            angle_stats["max_vy"] = max(angle_stats["max_vy"], new_vy)
            
            # 위험한 경우 체크 (Y축 속도가 양수 = 아래쪽)
            if new_vy > 0:
                angle_stats["dangerous_count"] += 1
                dangerous_cases += 1
            else:
                safe_cases += 1
        
        # 평균 계산
        angle_stats["avg_angle"] /= test_count
        
        # 결과 출력
        print(f"  반사 각도 범위: {angle_stats['min_angle']:.1f}° ~ {angle_stats['max_angle']:.1f}°")
        print(f"  평균 반사 각도: {angle_stats['avg_angle']:.1f}°")
        print(f"  Y축 속도 범위: {angle_stats['min_vy']:.2f} ~ {angle_stats['max_vy']:.2f}")
        print(f"  위험한 경우: {angle_stats['dangerous_count']}/{test_count} ({angle_stats['dangerous_count']/test_count*100:.1f}%)")
    
    print("\n" + "=" * 60)
    print(f"전체 테스트 결과:")
    print(f"- 총 테스트: {len(test_speeds) * test_count}회")
    print(f"- 안전한 경우: {safe_cases}회 ({safe_cases/(safe_cases+dangerous_cases)*100:.1f}%)")
    print(f"- 위험한 경우: {dangerous_cases}회 ({dangerous_cases/(safe_cases+dangerous_cases)*100:.1f}%)")
    
    if dangerous_cases == 0:
        print("\n✅ 모든 테스트 통과! 공이 플레이어 아래로 튕기는 경우가 없습니다.")
    else:
        print("\n❌ 테스트 실패! 공이 플레이어 아래로 튕기는 경우가 발견되었습니다.")
    
    return dangerous_cases == 0

def test_extreme_cases():
    """극단적인 상황 테스트"""
    print("\n\n극단적인 상황 테스트")
    print("=" * 60)
    
    # 파라미터
    base_angle = -math.pi / 2
    fan_spread = math.pi / 4
    min_upward_speed = -15
    max_x_speed = 20
    
    # 극단적인 케이스들
    extreme_cases = [
        ("최대 오른쪽 반사", fan_spread),
        ("최대 왼쪽 반사", -fan_spread),
        ("정중앙 반사", 0),
        ("오른쪽 30도", math.pi / 6),
        ("왼쪽 30도", -math.pi / 6)
    ]
    
    for case_name, offset in extreme_cases:
        print(f"\n{case_name} (오프셋: {math.degrees(offset):.1f}도)")
        print("-" * 40)
        
        target_angle = base_angle + offset
        
        # 다양한 속도로 테스트
        for speed in [10, 20, 30]:
            deflect_speed = max(18, min(speed * 1.5, 30))
            new_vx = math.cos(target_angle) * deflect_speed
            new_vy = math.sin(target_angle) * deflect_speed
            
            # 안전장치 적용 전
            before_vy = new_vy
            
            # Y축 속도 안전장치
            if new_vy >= 0:
                new_vy = min_upward_speed
            elif new_vy > min_upward_speed:
                new_vy = min_upward_speed
            
            # X축 속도 제한
            if abs(new_vx) > max_x_speed:
                new_vx = max_x_speed if new_vx > 0 else -max_x_speed
            
            actual_angle = math.atan2(new_vy, new_vx)
            print(f"  속도 {speed}: vx={new_vx:.2f}, vy={new_vy:.2f} (원래 vy={before_vy:.2f})")
            print(f"  실제 각도: {math.degrees(actual_angle):.1f}도")
            
            if new_vy >= 0:
                print(f"  ⚠️ 위험! Y축 속도가 양수입니다!")
            else:
                print(f"  ✅ 안전! 공이 위쪽으로 향합니다.")

if __name__ == "__main__":
    # 일반 안전성 테스트
    success = test_vortex_reflection_safety()
    
    # 극단적인 케이스 테스트
    test_extreme_cases()
    
    print("\n테스트 완료!")