#!/usr/bin/env python3
"""AK-47 화기류 전환 테스트"""

import pygame
import sys
import os

# 게임 모듈 임포트를 위한 경로 설정
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pingfighter import (
    soldier_weapons,
    current_weapon_index,
    get_ak47_instance,
    draw_soldier_weapon_ui,
    WIDTH, HEIGHT,
    resource_path
)
from item_effects.ak47 import AK47

# Pygame 초기화
pygame.init()
SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("AK-47 화기류 전환 테스트")
clock = pygame.time.Clock()

# 글로벌 변수 설정
def setup_globals():
    """테스트를 위한 글로벌 변수 설정"""
    global soldier_ammo_count, soldier_max_ammo, soldier_reloading, soldier_reload_timer
    global round_start_time, ui_manager, font_tiny
    
    soldier_ammo_count = 5
    soldier_max_ammo = 5
    soldier_reloading = False
    soldier_reload_timer = 0
    round_start_time = pygame.time.get_ticks() - 4000  # 3초 제한 통과
    
    # 간단한 UI 매니저 모킹
    class MockUIManager:
        def __init__(self):
            self.korean_font = pygame.font.Font(None, 20)
    
    ui_manager = MockUIManager()
    font_tiny = pygame.font.Font(None, 12)
    
    # globals에 추가
    import pingfighter
    pingfighter.soldier_ammo_count = soldier_ammo_count
    pingfighter.soldier_max_ammo = soldier_max_ammo
    pingfighter.soldier_reloading = soldier_reloading
    pingfighter.soldier_reload_timer = soldier_reload_timer
    pingfighter.round_start_time = round_start_time
    pingfighter.ui_manager = ui_manager
    pingfighter.font_tiny = font_tiny

def main():
    """메인 테스트 루프"""
    global current_weapon_index
    
    # 글로벌 변수 설정
    setup_globals()
    
    # 테스트를 위해 모든 화기류 추가
    import pingfighter
    pingfighter.soldier_weapons = ["pistol", "bazooka", "ak47"]
    pingfighter.current_weapon_index = 0
    
    # AK-47 초기화
    ak47 = get_ak47_instance()
    ak47.active = True  # 활성화
    ak47.current_ammo = 30
    ak47.max_ammo = 30
    
    # 바주카포 초기화 (없으면 에러 발생할 수 있음)
    try:
        from item_effects.bazooka import get_bazooka_instance
        bazooka = get_bazooka_instance()
        bazooka.equipped = False
    except:
        pass
    
    running = True
    font = pygame.font.Font(None, 36)
    small_font = pygame.font.Font(None, 24)
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_UP:
                    # 화기류 전환
                    pingfighter.current_weapon_index = (pingfighter.current_weapon_index + 1) % len(pingfighter.soldier_weapons)
                    current_weapon = pingfighter.soldier_weapons[pingfighter.current_weapon_index]
                    
                    print(f"🔄 화기 전환: {current_weapon}")
                    
                    # 전환 로직 실행
                    if current_weapon == "bazooka":
                        try:
                            bazooka = get_bazooka_instance()
                            bazooka.equipped = True
                        except:
                            pass
                    elif current_weapon == "pistol":
                        try:
                            bazooka = get_bazooka_instance()
                            bazooka.equipped = False
                        except:
                            pass
                    elif current_weapon == "ak47":
                        try:
                            bazooka = get_bazooka_instance()
                            bazooka.equipped = False
                        except:
                            pass
                        # AK-47 활성화
                        ak47 = get_ak47_instance()
                        ak47.active = True
                        print(f"📌 AK-47 active 상태: {ak47.active}")
        
        # 화면 클리어
        SCREEN.fill((50, 50, 50))
        
        # 화기류 UI 그리기
        draw_soldier_weapon_ui(SCREEN)
        
        # 현재 무기 정보 표시
        current_weapon = pingfighter.soldier_weapons[pingfighter.current_weapon_index]
        info_y = 10
        
        # 타이틀
        title_text = font.render("AK-47 화기류 전환 테스트", True, (255, 255, 255))
        SCREEN.blit(title_text, (WIDTH // 2 - title_text.get_width() // 2, info_y))
        info_y += 50
        
        # 현재 무기
        weapon_text = font.render(f"현재 무기: {current_weapon}", True, (255, 255, 100))
        SCREEN.blit(weapon_text, (10, info_y))
        info_y += 40
        
        # AK-47 상태
        ak47_status = f"AK-47 active: {ak47.active}, 잔탄: {ak47.current_ammo}/{ak47.max_ammo}"
        status_text = small_font.render(ak47_status, True, (200, 200, 200))
        SCREEN.blit(status_text, (10, info_y))
        info_y += 30
        
        # 조작법
        help_texts = [
            "↑키: 화기류 전환",
            "ESC: 종료"
        ]
        
        for text in help_texts:
            help_surface = small_font.render(text, True, (150, 150, 150))
            SCREEN.blit(help_surface, (10, info_y))
            info_y += 25
        
        # 화면 업데이트
        pygame.display.flip()
        clock.tick(60)
    
    pygame.quit()

if __name__ == "__main__":
    main()