#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
탄약상자 (Ammo Box) 아이템 테스트
- 물자보급으로만 획득 가능
- 액티브 아이템 슬롯에 저장
- 숫자키로 사용 시 모든 화기류 재장전
"""

import pygame
import sys
import os

# 경로 설정
def resource_path(relative_path):
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(base_path, relative_path)

# 상위 디렉토리를 Python 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import items
from item_effects.ammo_box import get_ammo_box_instance
from item_effects.bazooka import get_bazooka_instance
from item_effects.ak47 import get_ak47_instance

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("Ammo Box Test")
clock = pygame.time.Clock()

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
GREEN = (0, 255, 0)
RED = (255, 0, 0)
BLUE = (0, 0, 255)
GRAY = (128, 128, 128)
YELLOW = (255, 255, 0)

# 폰트 설정
font = pygame.font.Font(None, 36)
small_font = pygame.font.Font(None, 24)

# 플레이어 패들
player_rect = pygame.Rect(400, 500, 80, 20)

# 바주카포 인스턴스
bazooka = get_bazooka_instance()
bazooka.equip()  # 바주카포 장착

# 탄약상자 인스턴스
ammo_box = get_ammo_box_instance()

# 테스트용 상태
active_item_slot = []
MAX_ITEM_SLOTS = 3
selected_item_index = 0
soldier_pistol_ammo = 5
SOLDIER_PISTOL_MAX_AMMO = 10
soldier_weapons = ["pistol", "bazooka", "ak47"]  # 모든 화기류 보유

# AK-47 인스턴스
ak47 = get_ak47_instance()
ak47.activate(None, None)  # 활성화
ak47.current_ammo = 10  # 탄약 일부만 남김

# 메인 게임 루프
running = True
test_stage = 1
show_instructions = True

print("\n=== 탄약상자 테스트 시작 ===")
print("1. SPACE: 물자보급으로 탄약상자 획득")
print("2. 숫자키 1-3: 아이템 슬롯 선택")
print("3. ENTER: 선택된 아이템 사용")
print("4. F: 화기류 발사 (탄약 소모)")
print("5. ESC: 종료")

while running:
    dt = clock.tick(60) / 1000.0
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                # 물자보급으로 탄약상자 획득
                if len(active_item_slot) < MAX_ITEM_SLOTS:
                    item_data = {
                        "name": "ammo_box",
                        "color": (139, 69, 19),
                        "effect": "ammo_box",
                        "icon": None
                    }
                    active_item_slot.append(item_data)
                    print(f"📦 탄약상자를 획득했습니다! (슬롯 {len(active_item_slot)})")
                else:
                    print("❌ 아이템 슬롯이 가득 찼습니다!")
            
            # 아이템 슬롯 선택
            elif event.key in [pygame.K_1, pygame.K_2, pygame.K_3]:
                slot = event.key - pygame.K_1
                if slot < MAX_ITEM_SLOTS:
                    selected_item_index = slot
                    print(f"슬롯 {slot + 1} 선택")
            
            # 아이템 사용
            elif event.key == pygame.K_RETURN:
                if selected_item_index < len(active_item_slot):
                    item = active_item_slot[selected_item_index]
                    if item["name"] == "ammo_box":
                        # 권총 재장전
                        prev_pistol = soldier_pistol_ammo
                        soldier_pistol_ammo = SOLDIER_PISTOL_MAX_AMMO
                        print(f"   🔫 권총 재장전: {prev_pistol} → {soldier_pistol_ammo}")
                        
                        # 탄약상자 효과 활성화
                        ammo_box.activate(None, test_stage)
                        
                        # 사용한 아이템 제거
                        active_item_slot.pop(selected_item_index)
                        selected_item_index = min(selected_item_index, len(active_item_slot) - 1)
                        print("✅ 탄약상자를 사용했습니다!")
            
            # 화기류 발사 (탄약 소모)
            elif event.key == pygame.K_f:
                # 권총 발사
                if soldier_pistol_ammo > 0:
                    soldier_pistol_ammo -= 1
                    print(f"🔫 권총 발사! 남은 탄약: {soldier_pistol_ammo}/{SOLDIER_PISTOL_MAX_AMMO}")
                
                # 바주카포 발사
                if bazooka.ammo_count > 0:
                    bazooka.ammo_count -= 1
                    print(f"🚀 바주카포 발사! 남은 탄약: {bazooka.ammo_count}/{bazooka.max_ammo}")
                
                # AK-47 발사
                if ak47.current_ammo > 0:
                    ak47.current_ammo -= 5  # 연사
                    ak47.current_ammo = max(0, ak47.current_ammo)
                    print(f"🔫 AK-47 연사! 남은 탄약: {ak47.current_ammo}/{ak47.max_ammo}")
    
    # 키 상태 확인
    keys = pygame.key.get_pressed()
    
    # 플레이어 이동 (좌우)
    if keys[pygame.K_LEFT] and player_rect.left > 0:
        player_rect.x -= 5
    if keys[pygame.K_RIGHT] and player_rect.right < 800:
        player_rect.x += 5
    
    # 업데이트
    bazooka.update(dt)
    ammo_box.update(test_stage)
    ak47.update(test_stage)
    
    # 그리기
    screen.fill(BLACK)
    
    # 플레이어 패들 그리기
    pygame.draw.rect(screen, GREEN, player_rect)
    
    # 탄약상자 재장전 애니메이션 그리기
    ammo_box.draw_effects(screen, player_rect=player_rect)
    
    # UI 그리기
    # 화기류 탄약 상태
    y_pos = 20
    
    # 권총
    pistol_text = f"권총: {soldier_pistol_ammo}/{SOLDIER_PISTOL_MAX_AMMO}"
    pistol_color = GREEN if soldier_pistol_ammo == SOLDIER_PISTOL_MAX_AMMO else (YELLOW if soldier_pistol_ammo > 0 else RED)
    text_surface = font.render(pistol_text, True, pistol_color)
    screen.blit(text_surface, (20, y_pos))
    y_pos += 40
    
    # 바주카포
    bazooka_text = f"바주카포: {bazooka.ammo_count}/{bazooka.max_ammo}"
    bazooka_color = GREEN if bazooka.ammo_count == bazooka.max_ammo else (YELLOW if bazooka.ammo_count > 0 else RED)
    text_surface = font.render(bazooka_text, True, bazooka_color)
    screen.blit(text_surface, (20, y_pos))
    y_pos += 40
    
    # AK-47
    ak47_text = f"AK-47: {ak47.current_ammo}/{ak47.max_ammo}"
    ak47_color = GREEN if ak47.current_ammo == ak47.max_ammo else (YELLOW if ak47.current_ammo > 0 else RED)
    text_surface = font.render(ak47_text, True, ak47_color)
    screen.blit(text_surface, (20, y_pos))
    
    # 액티브 아이템 슬롯
    slot_y = 200
    slot_text = font.render("액티브 아이템 슬롯:", True, WHITE)
    screen.blit(slot_text, (20, slot_y))
    
    # 슬롯 그리기
    slot_x = 20
    slot_y += 40
    for i in range(MAX_ITEM_SLOTS):
        # 슬롯 배경
        slot_rect = pygame.Rect(slot_x + i * 80, slot_y, 60, 60)
        color = YELLOW if i == selected_item_index else (100, 100, 100)
        pygame.draw.rect(screen, color, slot_rect, 2)
        
        # 슬롯 번호
        num_text = small_font.render(str(i + 1), True, color)
        screen.blit(num_text, (slot_x + i * 80 + 25, slot_y - 25))
        
        # 아이템 아이콘
        if i < len(active_item_slot):
            item = active_item_slot[i]
            if item["name"] == "ammo_box":
                # 탄약상자 아이콘 그리기
                box_rect = pygame.Rect(slot_x + i * 80 + 10, slot_y + 10, 40, 30)
                pygame.draw.rect(screen, (139, 69, 19), box_rect)
                pygame.draw.rect(screen, (101, 67, 33), box_rect, 2)
                # 십자 표시
                cross_x = slot_x + i * 80 + 30
                cross_y = slot_y + 25
                pygame.draw.rect(screen, WHITE, (cross_x - 8, cross_y - 2, 16, 4))
                pygame.draw.rect(screen, WHITE, (cross_x - 2, cross_y - 8, 4, 16))
    
    # 도움말
    if show_instructions:
        instructions = [
            "SPACE: Fire Bazooka",
            "R: Use Ammo Box (Reload)",
            "← →: Move",
            "ESC: Exit"
        ]
        y_offset = 100
        for instruction in instructions:
            inst_surface = small_font.render(instruction, True, WHITE)
            screen.blit(inst_surface, (20, y_offset))
            y_offset += 25
    
    # 탄약상자 상태
    if ammo_box.active:
        status_text = f"Reloading... {int(ammo_box.reload_progress * 100)}%"
        status_surface = font.render(status_text, True, YELLOW)
        text_rect = status_surface.get_rect(center=(400, 300))
        screen.blit(status_surface, text_rect)
    
    pygame.display.flip()

print("\n=== 테스트 종료 ===")
pygame.quit()