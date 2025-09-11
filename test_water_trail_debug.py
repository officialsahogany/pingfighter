#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""포세이돈 삼지창 - 물 궤적 디버그 테스트"""

import pygame
import sys
import os

# 부모 디렉토리를 Python 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 모듈 임포트
from legendary_items import PoseidonTrident

# Pygame 초기화
pygame.init()

# 화면 설정
screen = pygame.display.set_mode((600, 700))

# 포세이돈 삼지창 생성
trident = PoseidonTrident()
trident.active = True

print("=== 물 궤적 시스템 디버그 테스트 ===\n")

# 1. 회오리 발동
print("1. 회오리 발동")
trident.trigger_dash_wave(300, 600)
print(f"   - 회오리 활성: {trident.vortex_active}")
print(f"   - 왼쪽 회오리: ({trident.vortex_left_x}, {trident.vortex_left_y})")
print(f"   - 오른쪽 회오리: ({trident.vortex_right_x}, {trident.vortex_right_y})\n")

# 2. 회오리 업데이트
print("2. 회오리 업데이트 (10프레임)")
for i in range(10):
    trident.update(0.016)
print(f"   - 회오리 타이머: {trident.vortex_timer}\n")

# 3. 공이 회오리에 들어감 (보스가 친 공)
print("3. 공이 회오리에 들어감")
ball_x = trident.vortex_left_x  # 왼쪽 회오리 중앙
ball_y = trident.vortex_left_y - 50  # 회오리 범위 내
ball_vx = 0
ball_vy = 10  # 아래로 (보스가 친 공)

print(f"   - 공 위치: ({ball_x}, {ball_y})")
print(f"   - 공 속도: ({ball_vx}, {ball_vy})")

# 회오리 효과 적용
new_vx, new_vy = trident.apply_dash_wave_to_ball(
    ball_x, ball_y, ball_vx, ball_vy,
    300, 600, 300, 600
)

print(f"   - 회오리 후 속도: ({new_vx:.1f}, {new_vy:.1f})")
print(f"   - 공 캡처됨: {trident.ball_in_vortex}")
print(f"   - 물 궤적 활성: {trident.water_trail_active}")
print(f"   - 물 궤적 포인트: {len(trident.water_trail)}\n")

# 4. 물 궤적 업데이트 테스트
print("4. 물 궤적 업데이트 (20프레임)")
for i in range(20):
    # 공 위치 시뮬레이션 (회전)
    ball_x += new_vx
    ball_y += new_vy
    
    # 물 궤적 업데이트
    trident.update_water_trail(ball_x, ball_y)
    
    if i % 5 == 0:
        print(f"   프레임 {i}: 궤적 포인트={len(trident.water_trail)}, 물방울={len(trident.water_droplets)}")

print(f"\n5. 최종 상태")
print(f"   - 물 궤적 활성: {trident.water_trail_active}")
print(f"   - 물 궤적 포인트: {len(trident.water_trail)}")
print(f"   - 물방울 파티클: {len(trident.water_droplets)}")

# 6. 화면에 그리기 테스트
print("\n6. 화면에 그리기 테스트")
screen.fill((255, 255, 255))  # 흰색 배경

# 물 궤적 그리기
trident.draw_effects(screen)

# 화면 업데이트
pygame.display.flip()

print("\n=== 테스트 완료 ===")
print("물 궤적이 화면에 표시되어야 합니다.")
print("창을 닫으려면 Ctrl+C를 누르세요...")

# 잠시 대기
import time
time.sleep(5)

pygame.quit()