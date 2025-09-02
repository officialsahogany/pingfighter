#!/usr/bin/env python3
"""
전설 아이템 시스템 테스트
"""

import pygame
from legendary_items import get_legendary_manager

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("전설 아이템 테스트")

# 색상 정의
WHITE = (255, 255, 255)
BLACK = (0, 0, 0)
RED = (255, 0, 0)

# 전설 아이템 매니저 가져오기
legendary_manager = get_legendary_manager()

# 테스트를 위해 모든 아이템 해금
print("=== 전설 아이템 시스템 테스트 ===\n")
print("모든 전설 아이템 강제 해금 중...")

# 해금 조건 무시하고 직접 해금
for item_name, item in legendary_manager.items.items():
    item.unlocked = True
    legendary_manager.unlocked_items.append(item_name)
    print(f"✅ [{item.korean_name}] 해금됨")
    print(f"   - 설명: {item.description}")
    print(f"   - 해금 조건: {item.unlock_condition}")

print("\n=== 전설 아이템 렌더링 테스트 ===")

# 게임 루프
running = True
clock = pygame.time.Clock()
dt = 0

# 아이템 위치
x_start = 100
y_start = 100
item_spacing = 100

while running:
    dt = clock.tick(60)
    
    # 이벤트 처리
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_1:
                # 무한의 건틀릿 활성화
                game_state = {'cooldown_multiplier': 1.0}
                legendary_manager.activate_item("infinity_gauntlet", game_state)
                print("무한의 건틀릿 활성화!")
            elif event.key == pygame.K_2:
                # 불사조의 깃털 활성화
                game_state = {}
                legendary_manager.activate_item("phoenix_feather", game_state)
                print("불사조의 깃털 활성화!")
            elif event.key == pygame.K_3:
                # 크로노스의 시계 활성화
                game_state = {}
                legendary_manager.activate_item("chronos_clock", game_state)
                print("크로노스의 시계 활성화!")
            elif event.key == pygame.K_4:
                # 엑스칼리버 활성화
                game_state = {}
                legendary_manager.activate_item("excalibur_blade", game_state)
                print("엑스칼리버 활성화!")
    
    # 화면 지우기
    screen.fill(BLACK)
    
    # 제목
    font = pygame.font.Font(None, 36)
    title_text = font.render("Legendary Items Test", True, WHITE)
    screen.blit(title_text, (250, 30))
    
    # 안내 텍스트
    font_small = pygame.font.Font(None, 24)
    info_text = font_small.render("Press 1-4 to activate items, ESC to quit", True, WHITE)
    screen.blit(info_text, (200, 70))
    
    # 전설 아이템 그리기
    for i, (item_name, item) in enumerate(legendary_manager.items.items()):
        x = x_start + (i % 4) * item_spacing
        y = y_start + (i // 4) * item_spacing
        
        # 아이템 업데이트
        item.update(dt)
        
        # 아이템 아이콘 그리기
        item.draw_icon(screen, x, y, 60)
        
        # 아이템 이름
        name_text = font_small.render(item.korean_name, True, WHITE)
        name_rect = name_text.get_rect(center=(x + 30, y + 80))
        screen.blit(name_text, name_rect)
        
        # 활성 상태 표시
        if item.active:
            active_text = font_small.render("ACTIVE", True, (0, 255, 0))
            active_rect = active_text.get_rect(center=(x + 30, y + 100))
            screen.blit(active_text, active_rect)
    
    # 활성 아이템 목록
    y_offset = 350
    active_title = font_small.render("Active Items:", True, WHITE)
    screen.blit(active_title, (50, y_offset))
    
    for i, name in enumerate(legendary_manager.active_items):
        item = legendary_manager.items[name]
        active_item_text = font_small.render(f"- {item.korean_name}", True, (255, 100, 100))
        screen.blit(active_item_text, (50, y_offset + 30 + i * 25))
    
    # 화면 업데이트
    pygame.display.flip()

pygame.quit()
print("\n테스트 종료")