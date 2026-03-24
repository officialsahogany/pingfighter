"""
패시브 아이템 → 파츠 스왑 데모.

실제 게임 아이템 이름으로 apply_item_to_skin()을 호출하여
캐릭터 외형이 바뀌는 것을 검증한다.

실행: .venv_win/Scripts/python.exe tests/test_item_parts.py

조작:
  Q/W — 헬멧 (가시투구 / 방탄모자 / 기본)
  E/R — 몸통 (테크니컬조끼 / 벌크업슈트 / 기본)
  A/S — 왼팔 (코만도암 / 골드디거 / 기본)
  D   — 무기 (라그나로크 해머 / 기본)
  F   — 등   (충전가방 / 해제)
  0   — 전체 초기화 (기본 스매셔)
  SPACE — 타격 모션
  ESC — 종료
"""

import sys
import os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import pygame
import math

pygame.init()

SCREEN_W, SCREEN_H = 900, 620
screen = pygame.display.set_mode((SCREEN_W, SCREEN_H))
pygame.display.set_caption("Item Parts Demo — 패시브 아이템 외형 변경 테스트")

font = pygame.font.SysFont("Consolas", 13)
font_big = pygame.font.SysFont("Consolas", 15, bold=True)

from entities.player_skeleton import Skeleton, UPPER_BODY_JOINTS
from entities.body_parts.smasher_skin import (
    get_smasher_skeleton, get_smasher_skin, create_smasher_skin,
)
from entities.body_parts.item_parts_registry import (
    apply_item_to_skin, remove_item_from_skin, ITEM_SLOT_MAP, VISUAL_ITEM_NAMES,
)

# 매번 초기화 가능하도록 새 스킨 생성
skeleton = get_smasher_skeleton()
skin = create_smasher_skin()

# ── 슬롯별 현재 장착 아이템 추적 ──
equipped = {
    "head": None,
    "torso": None,
    "l_arm": None,
    "weapon": None,
    "back": None,
}

# ── 아이템 순환 목록 ──
SLOT_ITEMS = {
    "head": [None, "spiked_helmet", "bulletproof_hat"],
    "torso": [None, "technical_vest", "bulkup"],
    "l_arm": [None, "commando_arm", "gold_digger"],
    "weapon": [None, "ragnarok_hammer"],
    "back": [None, "chargebag"],
}

slot_indices = {slot: 0 for slot in SLOT_ITEMS}

# ── 한글 이름 매핑 ──
ITEM_KOREAN = {
    None: "기본",
    "spiked_helmet": "가시투구",
    "bulletproof_hat": "방탄모자",
    "technical_vest": "테크니컬조끼",
    "bulkup": "벌크업슈트",
    "commando_arm": "코만도암",
    "gold_digger": "골드디거",
    "ragnarok_hammer": "라그나로크 해머",
    "chargebag": "충전가방",
}


def cycle_slot(slot_name: str, direction: int = 1):
    """슬롯의 아이템을 순환 교체."""
    items = SLOT_ITEMS[slot_name]
    idx = slot_indices[slot_name]
    idx = (idx + direction) % len(items)
    slot_indices[slot_name] = idx

    item_name = items[idx]
    if item_name is None:
        remove_item_from_skin(skin, equipped[slot_name] or "", block=9)
        equipped[slot_name] = None
    else:
        apply_item_to_skin(skin, item_name, block=9)
        equipped[slot_name] = item_name


clock = pygame.time.Clock()
phase = 0.0
hit_timer = 0
shield_timer = 0

running = True
while running:
    dt = clock.tick(60) / 1000.0

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False

            # 모션
            elif event.key == pygame.K_SPACE:
                hit_timer = 8
            elif event.key == pygame.K_LSHIFT:
                shield_timer = 18

            # 슬롯 순환
            elif event.key == pygame.K_q:
                cycle_slot("head", 1)
            elif event.key == pygame.K_w:
                cycle_slot("head", -1)
            elif event.key == pygame.K_e:
                cycle_slot("torso", 1)
            elif event.key == pygame.K_r:
                cycle_slot("torso", -1)
            elif event.key == pygame.K_a:
                cycle_slot("l_arm", 1)
            elif event.key == pygame.K_s:
                cycle_slot("l_arm", -1)
            elif event.key == pygame.K_d:
                cycle_slot("weapon", 1)
            elif event.key == pygame.K_f:
                cycle_slot("back", 1)

            # 전체 초기화
            elif event.key == pygame.K_0:
                for slot in SLOT_ITEMS:
                    slot_indices[slot] = 0
                    if equipped[slot]:
                        remove_item_from_skin(skin, equipped[slot])
                    equipped[slot] = None

    # 걷기 phase
    phase = (phase + dt * 2.0) % 1.0

    # 타이머
    if hit_timer > 0:
        hit_timer -= 1
    if shield_timer > 0:
        shield_timer -= 1

    hit_ratio = max(0.0, min(1.0, hit_timer / 8.0))
    shield_strength = 0.0
    if shield_timer > 0:
        n = 1.0 - (shield_timer / 18.0)
        shield_strength = (n * 2.0 if n < 0.5 else (1.0 - n) * 2.0)
        shield_strength = max(0.0, min(1.0, shield_strength)) ** 0.7

    # ── 포즈 블렌딩 ──
    motion = skin.motion
    base_pose = motion.get_walk_pose(phase)
    if hit_ratio > 0:
        hit_pose = motion.get_hit_pose(1.0 - hit_ratio)
        base_pose = Skeleton.layer_pose(base_pose, hit_pose, mask=UPPER_BODY_JOINTS)
    if shield_strength > 0:
        shield_pose = motion.get_shield_raise_pose(shield_strength)
        base_pose = Skeleton.layer_pose(base_pose, shield_pose, mask={"r_shoulder", "r_elbow", "r_wrist"})

    skeleton.apply_pose(base_pose)
    skeleton.update(root_pos=(125.0, 56.0))

    # ── 렌더링 ──
    char_surf = pygame.Surface((250, 120), pygame.SRCALPHA)
    skin.draw_all(char_surf, skeleton, phase)

    # ── 화면 그리기 ──
    screen.fill((20, 22, 30))

    # 캐릭터 3배 확대
    scale = 3
    big = pygame.transform.scale(char_surf, (250 * scale, 120 * scale))
    char_x = (SCREEN_W - 250 * scale) // 2
    char_y = 70
    screen.blit(big, (char_x, char_y))

    # ── 타이틀 ──
    title = font_big.render("Item Parts Demo", True, (255, 255, 255))
    screen.blit(title, (SCREEN_W // 2 - title.get_width() // 2, 8))

    controls = "Q/W=head  E/R=torso  A/S=arm  D=weapon  F=back  0=reset  SPACE=hit  SHIFT=shield"
    t = font.render(controls, True, (130, 130, 150))
    screen.blit(t, (SCREEN_W // 2 - t.get_width() // 2, 30))

    # ── 장착 슬롯 UI ──
    panel_y = char_y + 120 * scale + 20
    slot_display = [
        ("HEAD", "head", "Q/W"),
        ("TORSO", "torso", "E/R"),
        ("L_ARM", "l_arm", "A/S"),
        ("WEAPON", "weapon", "D"),
        ("BACK", "back", "F"),
    ]

    col_w = SCREEN_W // len(slot_display)
    for i, (label, slot, keys) in enumerate(slot_display):
        sx = 10 + i * col_w

        # 슬롯 타이틀
        t = font_big.render(f"[{label}]", True, (180, 180, 220))
        screen.blit(t, (sx, panel_y))

        # 키 안내
        t = font.render(f"Keys: {keys}", True, (100, 100, 120))
        screen.blit(t, (sx, panel_y + 18))

        # 현재 장착 아이템
        current = equipped[slot]
        name_kr = ITEM_KOREAN.get(current, current or "기본")
        color = (100, 255, 100) if current else (150, 150, 150)
        t = font.render(f"> {name_kr}", True, color)
        screen.blit(t, (sx, panel_y + 36))

        # 옵션 목록
        items = SLOT_ITEMS[slot]
        for j, item in enumerate(items):
            is_active = (j == slot_indices[slot])
            c = (80, 200, 80) if is_active else (80, 80, 90)
            marker = "●" if is_active else "○"
            name = ITEM_KOREAN.get(item, item or "기본")
            t = font.render(f"  {marker} {name}", True, c)
            screen.blit(t, (sx, panel_y + 56 + j * 16))

    # ── 설명 ──
    explain_y = panel_y + 130
    lines = [
        "패시브 아이템을 획득하면 캐릭터 외형이 자동으로 변경됩니다.",
        "apply_item_to_skin(skin, 'spiked_helmet') — 이 한 줄이면 끝!",
    ]
    for i, line in enumerate(lines):
        t = font.render(line, True, (100, 100, 120))
        screen.blit(t, (SCREEN_W // 2 - t.get_width() // 2, explain_y + i * 16))

    pygame.display.flip()

pygame.quit()
