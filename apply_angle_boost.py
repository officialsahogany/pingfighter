#!/usr/bin/env python3
"""
각도 기반 임팩트 부스트 시스템 패치
공의 각도가 수평에 가까울수록 더 큰 부스트를 받도록 수정
"""

import sys
import os
import shutil
from datetime import datetime
import re


def apply_angle_based_boost():
    """각도 기반 부스트 시스템 적용"""
    
    print("\n" + "="*60)
    print("🎯 각도 기반 임팩트 부스트 시스템 패치")
    print("="*60)
    print("\n📐 각도별 부스트 비율:")
    print("• 90도 (수직): 200% → 70%")
    print("• 80도: 210% → 70%")
    print("• 70도: 220% → 70%")
    print("• 60도: 230% → 70%")
    print("• 45도 이하: 240% → 70%")
    
    # 백업 생성
    source_file = "pingfighter.py"
    backup_file = f"pingfighter_backup_{datetime.now().strftime('%Y%m%d_%H%M%S')}.py"
    
    print(f"\n1️⃣ 백업 생성 중...")
    try:
        shutil.copy(source_file, backup_file)
        print(f"   ✅ 백업 완료: {backup_file}")
    except Exception as e:
        print(f"   ❌ 백업 실패: {e}")
        return False
    
    # pingfighter.py 읽기
    print(f"\n2️⃣ {source_file} 읽는 중...")
    try:
        with open(source_file, 'r', encoding='utf-8') as f:
            content = f.read()
        print(f"   ✅ 파일 읽기 완료")
    except Exception as e:
        print(f"   ❌ 파일 읽기 실패: {e}")
        return False
    
    # calculate_bounce 함수에서 부스트 계산 부분 찾기
    print(f"\n3️⃣ 부스트 계산 코드 수정 중...")
    
    # 원본 코드 패턴
    original_pattern = r"(    # 🚀 수정: 속도가 높아져도 초기 임팩트 부스트는 유지\n    base_boost = 2\.0.*?\n    min_boost = 1\.1.*?\n)"
    
    # 수정할 코드
    replacement_code = """    # 🚀 수정: 속도가 높아져도 초기 임팩트 부스트는 유지
    # 🎯 각도 기반 부스트 시스템: 수평에 가까울수록 더 큰 부스트
    # 현재 공의 각도 계산 (Y속도와 X속도의 비율)
    ball_angle_deg = 90  # 기본값 (수직)
    if abs(ball_vel[0]) > 0.1:  # X속도가 거의 0이 아닐 때
        # atan2를 사용해 정확한 각도 계산 (라디안 → 도)
        ball_angle_rad = math.atan2(abs(ball_vel[1]), abs(ball_vel[0]))
        ball_angle_deg = math.degrees(ball_angle_rad)
    
    # 각도에 따른 부스트 계산 (수평에 가까울수록 높은 부스트)
    # 90도 (수직) = 2.0x, 0도 (수평) = 2.4x
    if ball_angle_deg >= 90:
        angle_boost_multiplier = 2.0  # 200%
    elif ball_angle_deg >= 80:
        # 90도에서 80도: 200% → 210%
        angle_ratio = (90 - ball_angle_deg) / 10
        angle_boost_multiplier = 2.0 + 0.1 * angle_ratio
    elif ball_angle_deg >= 70:
        # 80도에서 70도: 210% → 220%
        angle_ratio = (80 - ball_angle_deg) / 10
        angle_boost_multiplier = 2.1 + 0.1 * angle_ratio
    elif ball_angle_deg >= 60:
        # 70도에서 60도: 220% → 230%
        angle_ratio = (70 - ball_angle_deg) / 10
        angle_boost_multiplier = 2.2 + 0.1 * angle_ratio
    elif ball_angle_deg >= 45:
        # 60도에서 45도: 230% → 240%
        angle_ratio = (60 - ball_angle_deg) / 15
        angle_boost_multiplier = 2.3 + 0.1 * angle_ratio
    else:
        # 45도 미만: 최대 240%
        angle_boost_multiplier = 2.4
    
    base_boost = angle_boost_multiplier  # 각도 기반 부스트 적용
    min_boost = 1.1         # 최소 110% 부스트 (고속에서 적절한 반응 시간 확보)
    
    # 디버그 출력 (가끔씩만)
    if pygame.time.get_ticks() % 180 < 16:  # 3초마다
        print(f"📐 각도 기반 부스트: {ball_angle_deg:.1f}° → {angle_boost_multiplier:.1%} 부스트")
"""
    
    # 코드 교체
    if re.search(original_pattern, content, re.DOTALL):
        content = re.sub(original_pattern, replacement_code, content, flags=re.DOTALL)
        print("   ✅ 부스트 계산 코드 수정 완료")
    else:
        print("   ⚠️ 원본 패턴을 찾을 수 없어 새로운 방법으로 시도...")
        # 대체 방법: base_boost = 2.0 라인 직접 찾기
        pattern2 = r"base_boost = 2\.0.*?min_boost = 1\.1"
        if re.search(pattern2, content, re.DOTALL):
            content = re.sub(pattern2, 
                replacement_code.split("# 🚀 수정:")[1].strip(), 
                content, flags=re.DOTALL)
            print("   ✅ 대체 방법으로 수정 완료")
        else:
            print("   ❌ 부스트 계산 코드를 찾을 수 없습니다")
            return False
    
    # 동적 감속 시스템도 각도를 고려하도록 수정
    print(f"\n4️⃣ 감속 시스템 수정 중...")
    
    # base_min_boost 패턴 찾기
    min_boost_pattern = r"(    # 🚀 스무스 트랜지션 시스템:.*?\n    base_min_boost = 0\.70.*?\n)"
    
    min_boost_replacement = """    # 🚀 스무스 트랜지션 시스템: 속도 하락 완화 (70% → 55%로 조정)
    # 🎯 각도 기반: 수평에 가까울수록 더 낮은 최종 속도로 감속
    base_min_boost = 0.70         # 기본 최종 속도 (느린 속도용)
"""
    
    if re.search(min_boost_pattern, content, re.DOTALL):
        content = re.sub(min_boost_pattern, min_boost_replacement, content, flags=re.DOTALL)
        print("   ✅ 감속 시스템 수정 완료")
    
    # 파일 저장
    print(f"\n5️⃣ 수정된 파일 저장 중...")
    try:
        with open(source_file, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"   ✅ 파일 저장 완료")
    except Exception as e:
        print(f"   ❌ 파일 저장 실패: {e}")
        return False
    
    print("\n" + "="*60)
    print("✅ 각도 기반 임팩트 부스트 시스템 적용 완료!")
    print("="*60)
    print("\n다음 변경사항이 적용되었습니다:")
    print("• 공의 각도에 따라 동적 부스트 계산")
    print("• 90도 (수직): 200% 부스트")
    print("• 45도 이하 (수평에 가까움): 최대 240% 부스트")
    print("• 각도별 선형 보간으로 부드러운 전환")
    print("• 디버그 출력 추가 (3초마다)")
    print("\n게임을 실행하여 테스트해보세요!")
    
    return True


if __name__ == "__main__":
    success = apply_angle_based_boost()
    if not success:
        print("\n⚠️ 패치 적용에 실패했습니다. 백업 파일을 확인하세요.")
        sys.exit(1)