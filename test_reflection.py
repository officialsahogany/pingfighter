"""
반사 예측 시스템 테스트
상하 벽 반사를 고려한 Y 위치 예측 검증
"""

import pygame
import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# 화면 크기
SCREEN_HEIGHT = 750

def reflect_y(y0, vy0, dt, y_min, y_max):
    """상하 벽 반사를 고려한 Y 위치 예측"""
    size = max(y_max - y_min, 1)
    total = (y0 - y_min) + vy0 * dt
    period = 2 * size
    m = total % period
    if m < 0:
        m += period
    if m <= size:
        return y_min + m
    else:
        return y_max - (m - size)

def simple_predict(y0, vy, dt):
    """단순 선형 예측 (반사 무시)"""
    return y0 + vy * dt

print("=" * 60)
print("반사 예측 시스템 테스트")
print("=" * 60)

# 테스트 케이스
test_cases = [
    # (시작Y, 속도Y, 시간, 설명)
    (100, 20, 30, "위로 빠르게 - 천장 반사"),
    (650, 20, 10, "아래로 - 바닥 반사"),
    (400, -30, 20, "위로 매우 빠르게"),
    (100, 50, 40, "초고속 - 여러 번 반사"),
    (700, 10, 10, "바닥 근처에서 반사"),
]

for y0, vy, dt, desc in test_cases:
    simple = simple_predict(y0, vy, dt)
    reflected = reflect_y(y0, vy, dt, 0, SCREEN_HEIGHT)
    
    # 화면 밖으로 나가는지 체크
    out_of_bounds = simple < 0 or simple > SCREEN_HEIGHT
    
    print(f"\n{desc}")
    print(f"  시작: Y={y0}, 속도: vy={vy}, 시간: {dt}프레임")
    print(f"  단순 예측: Y={simple:.0f} {'❌ 화면 밖!' if out_of_bounds else '✅'}")
    print(f"  반사 예측: Y={reflected:.0f} ✅")
    
    if out_of_bounds:
        print(f"  → 반사 시스템이 {abs(simple - reflected):.0f}px 차이 보정!")

print("\n" + "=" * 60)
print("스마트폰 정확도 향상 테스트")
print("=" * 60)

# 실제 게임 상황 시뮬레이션
scenarios = [
    # (공X, 공Y, vx, vy, 패들Y, 설명)
    (400, 100, -10, -20, 700, "천장 근처 공"),
    (300, 700, -15, 15, 600, "바닥 근처 공"),
    (500, 50, -20, -40, 650, "초고속 상단 공"),
]

for ball_x, ball_y, ball_vx, ball_vy, paddle_y, desc in scenarios:
    # X축 도달 시간
    t_to_x = (ball_x - 50) / abs(ball_vx) if ball_vx < 0 else 999
    
    # 예측 비교
    simple_y = ball_y + ball_vy * t_to_x
    reflected_y = reflect_y(ball_y, ball_vy, t_to_x, 0, SCREEN_HEIGHT)
    
    # Y 갭 계산
    simple_gap = abs(simple_y - paddle_y)
    reflected_gap = abs(reflected_y - paddle_y)
    
    print(f"\n{desc}")
    print(f"  공: ({ball_x}, {ball_y}), 속도: ({ball_vx}, {ball_vy})")
    print(f"  패들Y: {paddle_y}, X도달: {t_to_x:.1f}프레임")
    print(f"  단순 예측Y: {simple_y:.0f}, 갭: {simple_gap:.0f}px")
    print(f"  반사 예측Y: {reflected_y:.0f}, 갭: {reflected_gap:.0f}px")
    
    # 위험 판단 차이
    danger_simple = simple_gap > 100
    danger_reflected = reflected_gap > 100
    
    if danger_simple != danger_reflected:
        print(f"  ⚠️ 판단 차이! 단순={'위험' if danger_simple else '안전'}, 반사={'위험' if danger_reflected else '안전'}")

print("\n" + "=" * 60)
print("완료!")
print("=" * 60)