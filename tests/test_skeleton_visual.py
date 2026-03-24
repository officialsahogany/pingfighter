"""
Skeletal Sprite System — 파츠 스왑 데모 + 시각적 비교 테스트.

키 입력으로 헬멧/무기/방패를 실시간 교체하여
뼈대 시스템의 파츠 스왑 기능을 검증한다.

실행: .venv_win/Scripts/python.exe tests/test_skeleton_visual.py
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pygame
import math

pygame.init()

SCREEN_W, SCREEN_H = 900, 600
screen = pygame.display.set_mode((SCREEN_W, SCREEN_H))
pygame.display.set_caption("Parts Swap Demo — 1/2/3=헬멧  4/5=무기  6/7=방패")

font = pygame.font.SysFont("Consolas", 14)
font_big = pygame.font.SysFont("Consolas", 16, bold=True)

# ── 뼈대 + 스킨 임포트 ──
from entities.player_skeleton import (
    Skeleton, UPPER_BODY_JOINTS, create_smasher_skeleton,
)
from entities.body_parts.smasher_skin import (
    get_smasher_skeleton, get_smasher_skin, SMASHER_PALETTE,
)

# 기본 파츠
from entities.body_parts.smasher_head import SmasherHeadPart
from entities.body_parts.smasher_weapon import SmasherWeaponPart
from entities.body_parts.smasher_shield import SmasherShieldPart

# 커스텀 파츠
from entities.body_parts.custom_heads import HornedHelmetPart, CrownHelmetPart
from entities.body_parts.custom_weapons import FlameRacketPart
from entities.body_parts.custom_shields import MirrorShieldPart

# ── 싱글톤 인스턴스 ──
skeleton = get_smasher_skeleton()
skin = get_smasher_skin()

# ── 파츠 프리셋 ──
HEAD_OPTIONS = [
    ("1: Smasher Helmet", SmasherHeadPart()),
    ("2: Horned Viking", HornedHelmetPart()),
    ("3: Golden Crown", CrownHelmetPart()),
]
WEAPON_OPTIONS = [
    ("4: Mecha Racket", SmasherWeaponPart()),
    ("5: Flame Racket", FlameRacketPart()),
]
SHIELD_OPTIONS = [
    ("6: Penta Shield", SmasherShieldPart()),
    ("7: Mirror Shield", MirrorShieldPart()),
]

current_head = 0
current_weapon = 0
current_shield = 0

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

            # 모션 트리거
            elif event.key == pygame.K_SPACE:
                hit_timer = 8
            elif event.key == pygame.K_s:
                shield_timer = 18
            elif event.key == pygame.K_a:
                left_raise_timer = 18

            # ── 파츠 스왑 키 ──
            elif event.key == pygame.K_1:
                current_head = 0
                skin.set_part(HEAD_OPTIONS[0][1])
            elif event.key == pygame.K_2:
                current_head = 1
                skin.set_part(HEAD_OPTIONS[1][1])
            elif event.key == pygame.K_3:
                current_head = 2
                skin.set_part(HEAD_OPTIONS[2][1])
            elif event.key == pygame.K_4:
                current_weapon = 0
                skin.set_part(WEAPON_OPTIONS[0][1])
            elif event.key == pygame.K_5:
                current_weapon = 1
                skin.set_part(WEAPON_OPTIONS[1][1])
            elif event.key == pygame.K_6:
                current_shield = 0
                skin.set_part(SHIELD_OPTIONS[0][1])
            elif event.key == pygame.K_7:
                current_shield = 1
                skin.set_part(SHIELD_OPTIONS[1][1])

    # 걷기 phase
    phase = (phase + dt * 2.0) % 1.0

    # 타이머 감소
    if hit_timer > 0:
        hit_timer -= 1
    if shield_timer > 0:
        shield_timer -= 1
    if left_raise_timer > 0:
        left_raise_timer -= 1

    # 모션 강도 계산
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

    # ── 포즈 블렌딩 ──
    motion = skin.motion
    base_pose = motion.get_walk_pose(phase)

    if hit_ratio > 0:
        hit_pose = motion.get_hit_pose(1.0 - hit_ratio)
        base_pose = Skeleton.layer_pose(base_pose, hit_pose, mask=UPPER_BODY_JOINTS)
    if shield_strength > 0:
        shield_pose = motion.get_shield_raise_pose(shield_strength)
        base_pose = Skeleton.layer_pose(base_pose, shield_pose, mask={"r_shoulder", "r_elbow", "r_wrist"})
    if left_strength > 0:
        left_pose = motion.get_left_raise_pose(left_strength)
        base_pose = Skeleton.layer_pose(base_pose, left_pose, mask={"l_shoulder", "l_elbow", "l_wrist"})

    skeleton.apply_pose(base_pose)
    skeleton.update(root_pos=(125.0, 56.0))

    # ── 렌더링 ──
    surface = pygame.Surface((250, 120), pygame.SRCALPHA)
    skin.draw_all(surface, skeleton, phase)

    # ── 화면 그리기 ──
    screen.fill((25, 25, 35))

    # 캐릭터 3배 확대
    scale = 3
    big = pygame.transform.scale(surface, (250 * scale, 120 * scale))
    char_x = (SCREEN_W - 250 * scale) // 2
    char_y = 100
    screen.blit(big, (char_x, char_y))

    # ── 타이틀 ──
    title = font_big.render("Parts Swap Demo", True, (255, 255, 255))
    screen.blit(title, (SCREEN_W // 2 - title.get_width() // 2, 10))

    # ── 모션 정보 ──
    info = f"Phase: {phase:.2f}  Hit: {hit_ratio:.2f}  Shield: {shield_strength:.2f}"
    t = font.render(info, True, (180, 180, 180))
    screen.blit(t, (SCREEN_W // 2 - t.get_width() // 2, 35))

    controls = "SPACE=hit  S=shield  A=left_raise  ESC=quit"
    t = font.render(controls, True, (140, 140, 140))
    screen.blit(t, (SCREEN_W // 2 - t.get_width() // 2, 52))

    # ── 파츠 선택 UI ──
    panel_y = char_y + 120 * scale + 20

    def draw_slot_panel(title_text, options, current_idx, start_x, y):
        """슬롯별 옵션 패널 그리기."""
        # 슬롯 타이틀
        t = font_big.render(title_text, True, (200, 200, 255))
        screen.blit(t, (start_x, y))

        for i, (label, _part) in enumerate(options):
            is_active = (i == current_idx)
            color = (100, 255, 100) if is_active else (150, 150, 150)
            prefix = "> " if is_active else "  "
            t = font.render(prefix + label, True, color)
            screen.blit(t, (start_x, y + 20 + i * 18))

    # 3열 배치
    col_w = SCREEN_W // 3
    draw_slot_panel("HEAD", HEAD_OPTIONS, current_head, 40, panel_y)
    draw_slot_panel("WEAPON", WEAPON_OPTIONS, current_weapon, 40 + col_w, panel_y)
    draw_slot_panel("SHIELD", SHIELD_OPTIONS, current_shield, 40 + col_w * 2, panel_y)

    # ── 파츠 스왑 설명 ──
    explain_y = panel_y + 90
    explain = font.render(
        "Press number keys to swap parts — each slot is independently replaceable!",
        True, (120, 120, 140),
    )
    screen.blit(explain, (SCREEN_W // 2 - explain.get_width() // 2, explain_y))

    pygame.display.flip()

pygame.quit()
