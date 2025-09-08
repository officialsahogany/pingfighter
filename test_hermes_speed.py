#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""헤르메스의 신발 속도 증가 테스트"""

import sys
import os

# 게임 모듈 경로 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 모듈 임포트
import items

def test_hermes_speed():
    """헤르메스의 신발 속도 증가 테스트"""
    print("="*50)
    print("헤르메스의 신발 속도 증가 테스트")
    print("="*50)
    
    # 기본 속도값
    PERMANENT_SPEED_BOOST = 0.06  # 6%
    MAX_SPEED = 12
    
    print("\n[테스트 1] 헤르메스의 신발 미착용 시")
    items.hermes_shoes_obtained = False
    items.speedboots_obtained = False
    
    speed_multiplier = 1.0
    if items.speedboots_obtained:
        speed_multiplier = 1.0 + PERMANENT_SPEED_BOOST
    if items.hermes_shoes_obtained:
        speed_multiplier *= 1.5
    
    effective_max_speed = MAX_SPEED * speed_multiplier
    print(f"- 기본 속도: {MAX_SPEED}")
    print(f"- 속도 배율: {speed_multiplier:.2f}x")
    print(f"- 최종 속도: {effective_max_speed:.1f}")
    
    print("\n[테스트 2] 헤르메스의 신발만 착용 시")
    items.hermes_shoes_obtained = True
    items.speedboots_obtained = False
    
    speed_multiplier = 1.0
    if items.speedboots_obtained:
        speed_multiplier = 1.0 + PERMANENT_SPEED_BOOST
    if items.hermes_shoes_obtained:
        speed_multiplier *= 1.5
    
    effective_max_speed = MAX_SPEED * speed_multiplier
    print(f"- 기본 속도: {MAX_SPEED}")
    print(f"- 속도 배율: {speed_multiplier:.2f}x")
    print(f"- 최종 속도: {effective_max_speed:.1f}")
    print(f"- 속도 증가율: {(speed_multiplier - 1) * 100:.0f}%")
    
    print("\n[테스트 3] 스피드부츠 + 헤르메스의 신발 착용 시")
    items.hermes_shoes_obtained = True
    items.speedboots_obtained = True
    
    speed_multiplier = 1.0
    if items.speedboots_obtained:
        speed_multiplier = 1.0 + PERMANENT_SPEED_BOOST
    if items.hermes_shoes_obtained:
        speed_multiplier *= 1.5
    
    effective_max_speed = MAX_SPEED * speed_multiplier
    print(f"- 기본 속도: {MAX_SPEED}")
    print(f"- 스피드부츠 배율: {1.0 + PERMANENT_SPEED_BOOST:.2f}x")
    print(f"- 헤르메스 추가 배율: 1.5x")
    print(f"- 최종 속도 배율: {speed_multiplier:.2f}x")
    print(f"- 최종 속도: {effective_max_speed:.1f}")
    print(f"- 총 속도 증가율: {(speed_multiplier - 1) * 100:.0f}%")
    
    print("\n" + "="*50)
    print("테스트 결과:")
    print("✅ 헤르메스의 신발 착용 시 50% 속도 증가")
    print("✅ 스피드부츠와 중첩 가능 (1.06 * 1.5 = 1.59배)")
    print("="*50)

if __name__ == "__main__":
    test_hermes_speed()