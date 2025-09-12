#!/usr/bin/env python3
"""
스마트폰 아이템 스폰 및 패시브 리스트 등록 테스트
"""

import pygame
import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import items

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("스마트폰 스폰 테스트")
clock = pygame.time.Clock()
font = pygame.font.Font(None, 36)
small_font = pygame.font.Font(None, 24)

# 테스트를 위한 임시 변수
test_items = []
passive_items = []
active_items = []

# 스마트폰 강제 스폰 함수
def force_spawn_smartphone():
    """스마트폰을 100% 확률로 스폰"""
    item_data = {
        "name": "smartphone",
        "x": 400,
        "y": 300,
        "color": (100, 150, 200),
        "type": "passive"
    }
    test_items.append(item_data)
    print("스마트폰 스폰됨!")
    return item_data

# 아이템 획득 시뮬레이션
def pickup_item(item_data):
    """아이템 획득 처리 시뮬레이션"""
    global passive_items, active_items
    
    if item_data["name"] == "smartphone":
        # 패시브 아이템으로 추가
        passive_items.append(item_data)
        items.smartphone_obtained = True
        print(f"스마트폰 획득! 패시브 리스트에 추가됨")
        print(f"현재 패시브 아이템: {[item['name'] for item in passive_items]}")
        
        # 스마트폰 인스턴스 활성화
        from item_effects.smartphone import get_smartphone_instance
        smartphone = get_smartphone_instance()
        if smartphone:
            phone_state = {
                'current_stage': 1,
                'active_items': active_items
            }
            smartphone.activate(phone_state, 1)
            print("스마트폰 인스턴스 활성화됨!")
        
        # 아이템 리스트에서 제거
        if item_data in test_items:
            test_items.remove(item_data)

# 메인 루프
running = True
spawn_timer = 0
info_messages = []

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_SPACE:
                # 스페이스바로 스마트폰 강제 스폰
                item = force_spawn_smartphone()
                info_messages.append(("스마트폰 스폰됨!", 120))
            elif event.key == pygame.K_p:
                # P키로 아이템 획득
                if test_items:
                    item = test_items[0]
                    pickup_item(item)
                    info_messages.append(("아이템 획득!", 120))
            elif event.key == pygame.K_r:
                # R키로 리셋
                test_items.clear()
                passive_items.clear()
                active_items.clear()
                items.smartphone_obtained = False
                info_messages.append(("리셋됨!", 120))
    
    # 화면 그리기
    screen.fill((30, 30, 40))
    
    # 타이틀
    title = font.render("스마트폰 스폰 테스트", True, (255, 255, 255))
    screen.blit(title, (250, 30))
    
    # 조작 안내
    help_text = [
        "SPACE: 스마트폰 스폰",
        "P: 아이템 획득",
        "R: 리셋",
        "ESC: 종료"
    ]
    y_pos = 100
    for text in help_text:
        rendered = small_font.render(text, True, (200, 200, 200))
        screen.blit(rendered, (50, y_pos))
        y_pos += 25
    
    # 현재 상태 표시
    status_y = 220
    
    # 스폰된 아이템
    spawn_text = small_font.render(f"스폰된 아이템: {len(test_items)}개", True, (255, 255, 100))
    screen.blit(spawn_text, (50, status_y))
    
    # 아이템 그리기
    for item in test_items:
        pygame.draw.circle(screen, item["color"], (int(item["x"]), int(item["y"])), 20)
        # 스마트폰 아이콘 표시
        pygame.draw.rect(screen, (20, 20, 20), (item["x"]-8, item["y"]-10, 16, 20), border_radius=2)
        pygame.draw.rect(screen, (100, 180, 255), (item["x"]-6, item["y"]-8, 12, 14))
    
    # 패시브 아이템 리스트
    passive_y = status_y + 30
    passive_text = small_font.render(f"패시브 아이템: {[item['name'] for item in passive_items]}", True, (100, 255, 100))
    screen.blit(passive_text, (50, passive_y))
    
    # smartphone_obtained 플래그 상태
    flag_y = passive_y + 30
    flag_text = small_font.render(f"items.smartphone_obtained: {items.smartphone_obtained}", True, (255, 200, 100))
    screen.blit(flag_text, (50, flag_y))
    
    # 스마트폰 스폰 확률
    chance_y = flag_y + 30
    for item_type in items.ITEM_TYPES:
        if item_type["name"] == "smartphone":
            chance_text = small_font.render(f"스마트폰 스폰 확률: {item_type['chance']*100:.1f}%", True, (200, 200, 255))
            screen.blit(chance_text, (50, chance_y))
            break
    
    # 정보 메시지 표시
    msg_y = 450
    for i, (msg, timer) in enumerate(info_messages[:]):
        if timer > 0:
            alpha = min(255, timer * 4)
            msg_surface = small_font.render(msg, True, (255, 255, 255))
            msg_surface.set_alpha(alpha)
            screen.blit(msg_surface, (300, msg_y + i * 25))
            info_messages[i] = (msg, timer - 1)
        else:
            info_messages.remove((msg, timer))
    
    pygame.display.flip()
    clock.tick(60)
    
    # ESC로 종료
    keys = pygame.key.get_pressed()
    if keys[pygame.K_ESCAPE]:
        running = False

pygame.quit()
print("\n테스트 종료")
print(f"최종 패시브 아이템: {[item['name'] for item in passive_items]}")
print(f"smartphone_obtained: {items.smartphone_obtained}")