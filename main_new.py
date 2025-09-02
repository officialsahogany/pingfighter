#!/usr/bin/env python3
"""
BossPong - 새로운 메인 진입점
이 파일을 통해 기존 게임과 새 기능들을 실행합니다.
"""

import sys
import pygame
import bosspong  # 기존 게임 (18,841줄 - 더 이상 수정 안 함!)

# 새 기능들은 여기서 import
# from new_features.modes import survival_mode, tournament_mode
# from new_features.systems import achievement_system

def show_main_menu():
    """새로운 메인 메뉴"""
    pygame.init()
    screen = pygame.display.set_mode((600, 750))
    pygame.display.set_caption("BossPong - Extended Edition")
    clock = pygame.time.Clock()
    font = pygame.font.Font("NanumSquareR.ttf", 40)
    small_font = pygame.font.Font("NanumSquareR.ttf", 25)
    
    menu_items = [
        ("1. 클래식 게임 (Original)", "classic"),
        ("2. 서바이벌 모드 (Coming Soon)", "survival"),
        ("3. 토너먼트 모드 (Coming Soon)", "tournament"),
        ("4. 업적 & 리더보드 (Coming Soon)", "achievements"),
        ("5. 종료", "quit")
    ]
    
    selected = 0
    running = True
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return "quit"
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_UP:
                    selected = (selected - 1) % len(menu_items)
                elif event.key == pygame.K_DOWN:
                    selected = (selected + 1) % len(menu_items)
                elif event.key == pygame.K_RETURN:
                    return menu_items[selected][1]
                elif event.key == pygame.K_ESCAPE:
                    return "quit"
        
        # 화면 그리기
        screen.fill((20, 20, 40))
        
        # 타이틀
        title = font.render("BossPong Extended", True, (100, 200, 255))
        title_rect = title.get_rect(center=(300, 100))
        screen.blit(title, title_rect)
        
        # 메뉴 아이템들
        for i, (text, _) in enumerate(menu_items):
            color = (255, 255, 100) if i == selected else (200, 200, 200)
            item = small_font.render(text, True, color)
            item_rect = item.get_rect(center=(300, 250 + i * 60))
            screen.blit(item, item_rect)
            
            # 선택된 항목에 화살표
            if i == selected:
                arrow = small_font.render("→", True, (255, 255, 100))
                arrow_rect = arrow.get_rect(center=(150, 250 + i * 60))
                screen.blit(arrow, arrow_rect)
        
        # 안내 텍스트
        info = small_font.render("↑↓: 선택  Enter: 확인  ESC: 종료", True, (150, 150, 150))
        info_rect = info.get_rect(center=(300, 650))
        screen.blit(info, info_rect)
        
        pygame.display.flip()
        clock.tick(60)
    
    return "quit"

def main():
    """메인 실행 함수"""
    while True:
        choice = show_main_menu()
        
        if choice == "classic":
            # 기존 게임 실행
            print("클래식 게임 시작...")
            pygame.quit()  # 메뉴 종료
            bosspong.game_loop()  # 기존 게임 실행
            break
            
        elif choice == "survival":
            print("서바이벌 모드는 준비 중입니다!")
            # from new_features.modes.survival_mode import start_survival
            # start_survival()
            
        elif choice == "tournament":
            print("토너먼트 모드는 준비 중입니다!")
            # from new_features.modes.tournament_mode import start_tournament
            # start_tournament()
            
        elif choice == "achievements":
            print("업적 시스템은 준비 중입니다!")
            # from new_features.systems.achievement_system import show_achievements
            # show_achievements()
            
        elif choice == "quit":
            pygame.quit()
            sys.exit()
            break

if __name__ == "__main__":
    main()