#!/usr/bin/env python3
"""
🎮 PingFighter - Modular Version
모듈화된 PingFighter 게임 실행 파일
"""

import pygame
import sys
import os

# 경로 설정
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# 핵심 모듈 임포트
from core.game_engine import GameEngine, GameConfig
from core.constants import *

# 픽셀 폰트 매니저
try:
    from pixel_font_manager import get_font
    PIXEL_FONT_AVAILABLE = True
except ImportError:
    PIXEL_FONT_AVAILABLE = False
    print("⚠️ 픽셀 폰트 매니저를 찾을 수 없습니다")


def show_main_menu():
    """메인 메뉴 표시"""
    pygame.init()
    screen = pygame.display.set_mode((600, 750))
    pygame.display.set_caption("PingFighter - Modular Version")
    clock = pygame.time.Clock()
    
    # 폰트 설정
    if PIXEL_FONT_AVAILABLE:
        title_font = get_font(72, "bold")
        menu_font = get_font(36, "regular")
    else:
        title_font = pygame.font.Font(None, 72)
        menu_font = pygame.font.Font(None, 36)
    
    # 메뉴 옵션
    menu_options = [
        {"text": "1. 새 게임", "action": "new_game"},
        {"text": "2. 스테이지 선택", "action": "stage_select"},
        {"text": "3. 설정", "action": "settings"},
        {"text": "4. 종료", "action": "quit"}
    ]
    
    selected_index = 0
    running = True
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return "quit"
            
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_UP:
                    selected_index = (selected_index - 1) % len(menu_options)
                elif event.key == pygame.K_DOWN:
                    selected_index = (selected_index + 1) % len(menu_options)
                elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                    return menu_options[selected_index]["action"]
                elif event.key == pygame.K_1:
                    return "new_game"
                elif event.key == pygame.K_2:
                    return "stage_select"
                elif event.key == pygame.K_3:
                    return "settings"
                elif event.key == pygame.K_4 or event.key == pygame.K_ESCAPE:
                    return "quit"
        
        # 화면 그리기
        screen.fill((20, 20, 40))
        
        # 배경 효과
        for i in range(0, 750, 50):
            color = (30, 0, 50 - i // 20)
            pygame.draw.line(screen, color, (0, i), (600, i), 2)
        
        # 타이틀
        title_text = title_font.render("PINGFIGHTER", True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(300, 150))
        screen.blit(title_text, title_rect)
        
        # 부제목
        subtitle_font = pygame.font.Font(None, 24)
        subtitle_text = subtitle_font.render("Modular Edition", True, (150, 150, 255))
        subtitle_rect = subtitle_text.get_rect(center=(300, 200))
        screen.blit(subtitle_text, subtitle_rect)
        
        # 메뉴 옵션
        for i, option in enumerate(menu_options):
            y_pos = 350 + i * 60
            
            # 선택된 항목 하이라이트
            if i == selected_index:
                # 배경 박스
                pygame.draw.rect(screen, (50, 50, 100), 
                               (150, y_pos - 25, 300, 50), 
                               border_radius=10)
                pygame.draw.rect(screen, (100, 100, 255), 
                               (150, y_pos - 25, 300, 50), 3,
                               border_radius=10)
                color = (255, 255, 100)
            else:
                color = (200, 200, 200)
            
            # 텍스트
            text = menu_font.render(option["text"], True, color)
            text_rect = text.get_rect(center=(300, y_pos))
            screen.blit(text, text_rect)
        
        # 도움말
        help_font = pygame.font.Font(None, 20)
        help_text = help_font.render("↑↓: 선택  Enter: 확인  ESC: 종료", True, (100, 100, 100))
        help_rect = help_text.get_rect(center=(300, 680))
        screen.blit(help_text, help_rect)
        
        # 버전 정보
        version_text = help_font.render("v2.0.0 - Fully Modular", True, (80, 80, 80))
        version_rect = version_text.get_rect(bottomright=(590, 740))
        screen.blit(version_text, version_rect)
        
        pygame.display.flip()
        clock.tick(60)
    
    return "quit"


def select_stage():
    """스테이지 선택 화면"""
    pygame.init()
    screen = pygame.display.set_mode((600, 750))
    clock = pygame.time.Clock()
    
    # 폰트 설정
    if PIXEL_FONT_AVAILABLE:
        title_font = get_font(48, "bold")
        stage_font = get_font(32, "regular")
    else:
        title_font = pygame.font.Font(None, 48)
        stage_font = pygame.font.Font(None, 32)
    
    stages = [
        {"num": 1, "name": "사이버펑크", "color": (150, 0, 255)},
        {"num": 2, "name": "정글 악어", "color": (0, 255, 0)},
        {"num": 3, "name": "멘헤라 월드", "color": (255, 100, 150)},
        {"num": 4, "name": "소림사", "color": (255, 200, 0)},
        {"num": 5, "name": "중국 시장", "color": (255, 80, 0)},
        {"num": 6, "name": "항공모함", "color": (150, 200, 255)}
    ]
    
    selected_stage = 0
    running = True
    
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return None
            
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    return None
                elif event.key == pygame.K_LEFT:
                    selected_stage = (selected_stage - 1) % len(stages)
                elif event.key == pygame.K_RIGHT:
                    selected_stage = (selected_stage + 1) % len(stages)
                elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                    return stages[selected_stage]["num"]
                elif pygame.K_1 <= event.key <= pygame.K_6:
                    stage_num = event.key - pygame.K_0
                    if 1 <= stage_num <= 6:
                        return stage_num
        
        # 화면 그리기
        screen.fill((20, 20, 40))
        
        # 타이틀
        title_text = title_font.render("스테이지 선택", True, (255, 255, 255))
        title_rect = title_text.get_rect(center=(300, 100))
        screen.blit(title_text, title_rect)
        
        # 스테이지 카드
        for i, stage in enumerate(stages):
            x = 100 + (i % 3) * 180
            y = 250 + (i // 3) * 200
            
            # 카드 배경
            if i == selected_stage:
                pygame.draw.rect(screen, stage["color"], (x - 60, y - 60, 120, 120), border_radius=15)
                pygame.draw.rect(screen, (255, 255, 255), (x - 60, y - 60, 120, 120), 3, border_radius=15)
            else:
                pygame.draw.rect(screen, (50, 50, 50), (x - 60, y - 60, 120, 120), border_radius=15)
                pygame.draw.rect(screen, stage["color"], (x - 60, y - 60, 120, 120), 2, border_radius=15)
            
            # 스테이지 번호
            num_font = pygame.font.Font(None, 48)
            num_text = num_font.render(str(stage["num"]), True, (255, 255, 255))
            num_rect = num_text.get_rect(center=(x, y - 20))
            screen.blit(num_text, num_rect)
            
            # 스테이지 이름
            name_font = pygame.font.Font(None, 20)
            name_text = name_font.render(stage["name"], True, (200, 200, 200))
            name_rect = name_text.get_rect(center=(x, y + 20))
            screen.blit(name_text, name_rect)
        
        # 도움말
        help_font = pygame.font.Font(None, 20)
        help_text = help_font.render("←→: 선택  Enter: 시작  ESC: 뒤로", True, (100, 100, 100))
        help_rect = help_text.get_rect(center=(300, 680))
        screen.blit(help_text, help_rect)
        
        pygame.display.flip()
        clock.tick(60)
    
    return None


def run_game(stage_num: int = 1):
    """게임 실행"""
    print(f"🎮 Stage {stage_num} 시작!")
    
    # 게임 설정
    config = GameConfig(
        stage=stage_num,
        difficulty="normal",
        sound_enabled=True,
        fps=60
    )
    
    # 게임 엔진 생성 및 실행
    try:
        engine = GameEngine(config)
        engine.run()
    except Exception as e:
        print(f"❌ 게임 실행 중 오류 발생: {e}")
        import traceback
        traceback.print_exc()


def main():
    """메인 함수"""
    print("=" * 50)
    print("🎮 PingFighter - Modular Version")
    print("=" * 50)
    
    while True:
        # 메인 메뉴
        action = show_main_menu()
        
        if action == "quit":
            print("👋 게임을 종료합니다.")
            break
        
        elif action == "new_game":
            # 새 게임 (스테이지 1부터)
            run_game(1)
        
        elif action == "stage_select":
            # 스테이지 선택
            stage = select_stage()
            if stage:
                run_game(stage)
        
        elif action == "settings":
            # 설정 (아직 미구현)
            print("⚙️ 설정 메뉴는 개발 중입니다.")
            pygame.time.wait(1000)
    
    pygame.quit()
    sys.exit()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n⚠️ 사용자에 의해 중단되었습니다.")
        pygame.quit()
        sys.exit()
    except Exception as e:
        print(f"❌ 치명적 오류 발생: {e}")
        import traceback
        traceback.print_exc()
        pygame.quit()
        sys.exit(1)