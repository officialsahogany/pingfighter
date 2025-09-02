"""
라그나로크 해머 필드 애니메이션 테스트
"""

import pygame
import sys
import os
import math

# 현재 디렉토리를 모듈 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Pygame 초기화
pygame.init()
screen = pygame.display.set_mode((800, 600))
pygame.display.set_caption("라그나로크 해머 필드 애니메이션 테스트")
clock = pygame.time.Clock()

# 리소스 경로 함수
def resource_path(relative_path):
    """리소스 파일의 절대 경로 반환"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.abspath(".")
    return os.path.join(base_path, relative_path)

# 전설 아이템 매니저 임포트
from legendary_items import get_legendary_manager

# items 모듈 임포트
import items

# 아이템 매니저 초기화
legendary_manager = get_legendary_manager()

# 라그나로크 해머를 필드에 직접 추가
ragnarok_item_type = None
for item_type in items.ITEM_TYPES:
    if item_type["name"] == "ragnarok_hammer":
        ragnarok_item_type = item_type
        break

if ragnarok_item_type:
    # 필드에 라그나로크 해머 추가 (화면 중앙에)
    field_item = {
        "x": 400,
        "y": 300,
        "vel": [0, 0],  # 정지 상태
        "type": ragnarok_item_type,
        "timer": 600,
        "bounce_count": 0,
        "max_bounces": 0,
        "angle": 0
    }
    items.item_list.append(field_item)
    print("라그나로크 해머를 필드에 추가했습니다!")

# 메인 루프
running = True
frame_count = 0

while running:
    dt = clock.tick(60) / 1000.0  # 60 FPS
    
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                # 스페이스바로 아이템 위치 재설정
                if items.item_list:
                    items.item_list[0]["x"] = 400
                    items.item_list[0]["y"] = 300
                    print("아이템 위치 리셋!")
    
    # 화면 초기화
    screen.fill((20, 20, 40))
    
    # 격자 그리기 (참조용)
    for x in range(0, 800, 100):
        pygame.draw.line(screen, (40, 40, 60), (x, 0), (x, 600), 1)
    for y in range(0, 600, 100):
        pygame.draw.line(screen, (40, 40, 60), (0, y), (800, y), 1)
    
    # 중앙 십자선
    pygame.draw.line(screen, (60, 60, 80), (400, 0), (400, 600), 2)
    pygame.draw.line(screen, (60, 60, 80), (0, 300), (800, 300), 2)
    
    # 필드 아이템 그리기
    items.draw_items(screen)
    
    # 정보 표시
    font = pygame.font.Font(None, 24)
    info_texts = [
        f"Frame: {frame_count}",
        f"Field Items: {len(items.item_list)}",
        "Press SPACE to reset position",
        "Press ESC to exit"
    ]
    
    for i, text in enumerate(info_texts):
        text_surface = font.render(text, True, (200, 200, 200))
        screen.blit(text_surface, (10, 10 + i * 25))
    
    # 아이템 위치 표시
    if items.item_list:
        item = items.item_list[0]
        pos_text = f"Item Position: ({item['x']:.0f}, {item['y']:.0f})"
        pos_surface = font.render(pos_text, True, (255, 255, 100))
        screen.blit(pos_surface, (10, 120))
        
        # 아이템 이름 표시
        name_text = f"Item: {item['type']['name']}"
        name_surface = font.render(name_text, True, (255, 100, 100))
        screen.blit(name_surface, (10, 145))
    
    # 화면 업데이트
    pygame.display.flip()
    frame_count += 1

# 종료
pygame.quit()
print("테스트 종료")