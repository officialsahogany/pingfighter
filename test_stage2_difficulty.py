#!/usr/bin/env python3
"""
Stage 2 난이도 변경 테스트
- 보스 속도: 11.5 -> 11.0 (max_speed: 6.585 -> 6.3)
- 스피드 디펜스 지속 시간: 5초 -> 3초 (180 프레임)
- 스피드 디펜스 발동 간격: 20초 -> 25초 (1500 프레임)
- 스피드 디펜스 방어율: 100% -> 80%
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from config.stage_configs import BOSS_CONFIGS

def test_stage2_speed():
    """Stage 2 보스 속도 확인"""
    stage2_config = BOSS_CONFIGS[2]
    print("=== Stage 2 보스 설정 ===")
    print(f"이름: {stage2_config['name']}")
    print(f"최대 속도: {stage2_config['max_speed']}")
    print(f"가속도: {stage2_config['accel']}")
    print(f"감속도: {stage2_config['decel']}")
    
    # 속도 확인
    expected_speed = 6.3
    actual_speed = stage2_config['max_speed']
    
    if abs(actual_speed - expected_speed) < 0.01:
        print(f"✅ 속도 설정 성공: {actual_speed} (목표: {expected_speed})")
    else:
        print(f"❌ 속도 설정 실패: {actual_speed} (목표: {expected_speed})")
    
    return actual_speed == expected_speed

def test_speed_defense_params():
    """스피드 디펜스 파라미터 확인"""
    print("\n=== 스피드 디펜스 설정 ===")
    
    # pingfighter.py 파일에서 설정값 확인
    import pingfighter
    
    # 지속 시간 (3초 = 180 프레임)
    expected_duration = 180
    actual_duration = pingfighter.speed_defense_cooldown
    print(f"지속 시간: {actual_duration} 프레임 ({actual_duration/60:.1f}초)")
    
    # 발동 간격 (25초 = 1500 프레임)
    expected_interval = 1500
    actual_interval = pingfighter.SPEED_DEFENSE_INTERVAL
    print(f"발동 간격: {actual_interval} 프레임 ({actual_interval/60:.1f}초)")
    
    # 방어율 (80%)
    expected_block_rate = 0.8
    actual_block_rate = pingfighter.SPEED_DEFENSE_BLOCK_RATE
    print(f"방어율: {actual_block_rate*100:.0f}%")
    
    # 결과 확인
    duration_ok = actual_duration == expected_duration
    interval_ok = actual_interval == expected_interval
    block_rate_ok = actual_block_rate == expected_block_rate
    
    if duration_ok:
        print(f"✅ 지속 시간 설정 성공")
    else:
        print(f"❌ 지속 시간 설정 실패")
        
    if interval_ok:
        print(f"✅ 발동 간격 설정 성공")
    else:
        print(f"❌ 발동 간격 설정 실패")
        
    if block_rate_ok:
        print(f"✅ 방어율 설정 성공")
    else:
        print(f"❌ 방어율 설정 실패")
    
    return duration_ok and interval_ok and block_rate_ok

def main():
    print("🎮 Stage 2 난이도 변경 테스트 시작\n")
    
    speed_ok = test_stage2_speed()
    defense_ok = test_speed_defense_params()
    
    print("\n=== 테스트 결과 ===")
    if speed_ok and defense_ok:
        print("✅ 모든 테스트 통과! Stage 2 난이도가 성공적으로 조정되었습니다.")
        print("\n📋 변경 내용:")
        print("• 보스 속도: 11.5 → 11.0 (약 4.3% 감소)")
        print("• 스피드 디펜스 지속: 5초 → 3초 (40% 단축)")
        print("• 스피드 디펜스 간격: 20초 → 25초 (25% 증가)")
        print("• 스피드 디펜스 방어율: 100% → 80% (20% 통과 가능)")
    else:
        print("❌ 일부 테스트 실패. 설정을 확인해주세요.")
    
    return speed_ok and defense_ok

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)