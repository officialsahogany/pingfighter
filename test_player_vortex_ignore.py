#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""포세이돈 삼지창 - 플레이어 공 회오리 무시 테스트"""

import sys
import os
import math

# 부모 디렉토리를 Python 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 모듈 임포트
from legendary_items import PoseidonTrident

# 테스트 시작
print("=== 포세이돈 삼지창 - 플레이어 공 회오리 무시 테스트 ===\n")

# 포세이돈 삼지창 생성
trident = PoseidonTrident()
trident.active = True

# 회오리 발동
trident.trigger_dash_wave(300, 600)
print("1. 회오리 발동됨")
print(f"   - 왼쪽 회오리: x={trident.vortex_left_x}, y={trident.vortex_left_y}")
print(f"   - 오른쪽 회오리: x={trident.vortex_right_x}, y={trident.vortex_right_y}\n")

# 회오리 업데이트 (활성화 상태로 만들기)
for i in range(10):
    trident.update(0.016)  # 60fps
print(f"2. 회오리 상태: active={trident.vortex_active}, timer={trident.vortex_timer}\n")

# 테스트 1: 플레이어가 친 공 (위로 향함)
print("3. 플레이어가 친 공 테스트 (위로 향하는 공)")
player_ball_x = trident.vortex_left_x  # 왼쪽 회오리 정중앙
player_ball_y = trident.vortex_left_y - 50  # 회오리 범위 내
player_ball_vx = 0
player_ball_vy = -10  # 위로 향함 (플레이어가 친 공)

print(f"   - 공 위치: ({player_ball_x}, {player_ball_y})")
print(f"   - 공 속도: ({player_ball_vx}, {player_ball_vy})")

new_vx, new_vy = trident.apply_dash_wave_to_ball(
    player_ball_x, player_ball_y,
    player_ball_vx, player_ball_vy,
    300, 600, 300, 600
)

print(f"   - 회오리 후 속도: ({new_vx}, {new_vy})")
if new_vx == player_ball_vx and new_vy == player_ball_vy:
    print("   ✅ 성공: 플레이어 공이 회오리를 무시함!\n")
else:
    print("   ❌ 실패: 플레이어 공이 회오리 영향을 받음\n")

# 테스트 2: 보스가 친 공 (아래로 향함)
print("4. 보스가 친 공 테스트 (아래로 향하는 공)")
boss_ball_x = trident.vortex_left_x  # 왼쪽 회오리 정중앙
boss_ball_y = trident.vortex_left_y - 50  # 회오리 범위 내
boss_ball_vx = 0
boss_ball_vy = 10  # 아래로 향함 (보스가 친 공)

print(f"   - 공 위치: ({boss_ball_x}, {boss_ball_y})")
print(f"   - 공 속도: ({boss_ball_vx}, {boss_ball_vy})")

new_vx, new_vy = trident.apply_dash_wave_to_ball(
    boss_ball_x, boss_ball_y,
    boss_ball_vx, boss_ball_vy,
    300, 600, 300, 600
)

print(f"   - 회오리 후 속도: ({new_vx}, {new_vy})")
if new_vx != boss_ball_vx or new_vy != boss_ball_vy:
    print("   ✅ 성공: 보스 공이 회오리 영향을 받음!")
    if trident.ball_in_vortex:
        print("   - 공이 회오리에 캡처됨")
else:
    print("   ❌ 실패: 보스 공이 회오리를 무시함")

print("\n=== 테스트 완료 ===")