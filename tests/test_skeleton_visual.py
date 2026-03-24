"""
Skeletal Sprite System 시각적 비교 테스트.

기존 create_smasher_paddle_surface()와 새 render_smasher_skeletal()을
나란히 표시하여 시각적으로 비교한다.

실행: python tests/test_skeleton_visual.py
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pygame
import math

pygame.init()

SCREEN_W, SCREEN_H = 800, 500
screen = pygame.display.set_mode((SCREEN_W, SCREEN_H))
pygame.display.set_caption("Skeleton Visual Test — 좌: 기존 | 우: 뼈대 시스템")

# 폰트
font = pygame.font.SysFont("Consolas", 14)

# 새 시스템 임포트
from entities.body_parts.smasher_skin import render_smasher_skeletal

# 기존 시스템 임포트 시도
try:
    from pingfighter import create_smasher_paddle_surface
    HAS_OLD = True
except Exception as e:
    print(f"기존 함수 임포트 실패 (독립 비교 불가): {e}")
    HAS_OLD = False

clock = pygame.time.Clock()
phase = 0.0
hit_timer = 0
shield_timer = 0
left_raise_timer = 0

running = True
while running:
    dt = clock.tick(60) / 1000.0

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                hit_timer = 8  # 타격 포즈 트리거
            elif event.key == pygame.K_s:
                shield_timer = 18  # 방패 들기 트리거
            elif event.key == pygame.K_a:
                left_raise_timer = 18  # 왼팔 들기 트리거

    # 걷기 phase 업데이트
    phase = (phase + dt * 2.0) % 1.0

    # 타이머 감소
    if hit_timer > 0:
        hit_timer -= 1
    if shield_timer > 0:
        shield_timer -= 1
    if left_raise_timer > 0:
        left_raise_timer -= 1

    # 모션 강도 계산 (기존 시스템과 동일한 방식)
    hit_ratio = max(0.0, min(1.0, hit_timer / 8.0))

    shield_strength = 0.0
    if shield_timer > 0:
        normalized = 1.0 - (shield_timer / 18.0)
        if normalized < 0.5:
            shield_strength = normalized * 2.0
        else:
            shield_strength = (1.0 - normalized) * 2.0
        shield_strength = max(0.0, min(1.0, shield_strength)) ** 0.7

    left_strength = 0.0
    if left_raise_timer > 0:
        normalized = 1.0 - (left_raise_timer / 18.0)
        if normalized < 0.5:
            left_strength = normalized * 2.0
        else:
            left_strength = (1.0 - normalized) * 2.0
        left_strength = max(0.0, min(1.0, left_strength)) ** 0.7

    # ── 렌더링 ──
    screen.fill((30, 30, 40))

    # 새 시스템 렌더링
    new_surf = render_smasher_skeletal(
        step_phase=phase,
        hit_pose_ratio=hit_ratio,
        shield_raise_strength=shield_strength,
        left_raise_strength=left_strength,
    )

    # 2배 확대 표시
    scale = 3
    new_big = pygame.transform.scale(
        new_surf, (new_surf.get_width() * scale, new_surf.get_height() * scale)
    )

    if HAS_OLD:
        # 기존 시스템
        old_surf = create_smasher_paddle_surface(phase)
        old_big = pygame.transform.scale(
            old_surf, (old_surf.get_width() * scale, old_surf.get_height() * scale)
        )
        screen.blit(old_big, (20, 80))
        label_old = font.render("OLD (create_smasher_paddle_surface)", True, (200, 200, 200))
        screen.blit(label_old, (20, 55))
    else:
        label_na = font.render("OLD: import failed (run from project root)", True, (150, 150, 150))
        screen.blit(label_na, (20, 55))

    screen.blit(new_big, (420, 80))
    label_new = font.render("NEW (render_smasher_skeletal)", True, (100, 255, 100))
    screen.blit(label_new, (420, 55))

    # 상태 정보
    title = font.render("Skeleton Visual Test", True, (255, 255, 255))
    screen.blit(title, (SCREEN_W // 2 - title.get_width() // 2, 10))

    info_lines = [
        f"Phase: {phase:.2f}  Hit: {hit_ratio:.2f}  Shield: {shield_strength:.2f}  LeftRaise: {left_strength:.2f}",
        "SPACE=hit  S=shield  A=left_raise  ESC=quit",
    ]
    for i, line in enumerate(info_lines):
        t = font.render(line, True, (180, 180, 180))
        screen.blit(t, (SCREEN_W // 2 - t.get_width() // 2, 30 + i * 16))

    pygame.display.flip()

pygame.quit()
