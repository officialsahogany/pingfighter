#!/usr/bin/env python3
"""
빠른 스마트폰 테스트 - 게임 실행 시 자동으로 스마트폰과 스톱워치 획득
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 스마트폰과 스톱워치를 자동으로 획득하도록 설정
import items
items.smartphone_obtained = True  # 스마트폰 자동 획득
print("✅ 스마트폰 자동 획득 설정 완료!")

# 게임 시작
import pingfighter

print("\n테스트 방법:")
print("1. 게임을 시작하세요")
print("2. 스톱워치 아이템을 획득하세요 (또는 치트로 추가)")
print("3. 보스가 공을 쳐서 플레이어에게 올 때 스마트폰이 자동으로 스톱워치를 발동하는지 확인")
print("\n주의: 플레이어가 공을 친 상태에서는 발동하지 않습니다!")