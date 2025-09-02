"""
개선된 메인 메뉴 함수
새로운 우주 배경을 적용한 메인 메뉴
"""
import pygame
import random
import math
from ui.menu_background import SpaceBackground
from ui.font_manager import font_manager
from ui.theme_manager import theme_manager

def show_improved_start_screen(SCREEN, WIDTH, HEIGHT):
    """개선된 메인 메뉴 화면"""
    
    # 배경 초기화
    space_bg = SpaceBackground(WIDTH, HEIGHT)
    
    # 메뉴 옵션
    menu_options = ["경기시작", "NEW BOSS BATTLE", "메달샵", "옵션", "게임종료"]
    selected = 0
    last_selected = -1
    
    # 시계
    clock = pygame.time.Clock()
    
    # 애니메이션 변수
    animation_timer = 0
    menu_hover_scale = {}
    for i in range(len(menu_options)):
        menu_hover_scale[i] = 1.0
    
    # 타이틀 애니메이션
    title_offset = 0
    title_glow = 0
    
    # 메인 루프
    running = True
    while running:
        dt = clock.tick(60) / 1000.0  # Delta time in seconds
        animation_timer += dt
        
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                return "quit"
            
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_UP:
                    selected = (selected - 1) % len(menu_options)
                    # 선택 사운드 재생 (기존 시스템 활용)
                    try:
                        pygame.mixer.Sound("sounds/button_hover.wav").play()
                    except:
                        pass
                
                elif event.key == pygame.K_DOWN:
                    selected = (selected + 1) % len(menu_options)
                    # 선택 사운드 재생
                    try:
                        pygame.mixer.Sound("sounds/button_hover.wav").play()
                    except:
                        pass
                
                elif event.key == pygame.K_RETURN or event.key == pygame.K_SPACE:
                    # 선택 확인 사운드
                    try:
                        pygame.mixer.Sound("sounds/button_select.wav").play()
                    except:
                        pass
                    
                    # 메뉴 선택 처리
                    if selected == 0:  # 경기시작
                        return "start"
                    elif selected == 1:  # NEW BOSS BATTLE
                        return "boss_battle"
                    elif selected == 2:  # 메달샵
                        return "medal_shop"
                    elif selected == 3:  # 옵션
                        return "options"
                    elif selected == 4:  # 게임종료
                        return "quit"
                
                elif event.key == pygame.K_ESCAPE:
                    return "quit"
        
        # 호버 애니메이션 업데이트
        for i in range(len(menu_options)):
            if i == selected:
                menu_hover_scale[i] = min(1.15, menu_hover_scale[i] + dt * 3)
            else:
                menu_hover_scale[i] = max(1.0, menu_hover_scale[i] - dt * 3)
        
        # 타이틀 애니메이션
        title_offset = math.sin(animation_timer * 2) * 5
        title_glow = (math.sin(animation_timer * 3) + 1) / 2
        
        # 배경 업데이트
        space_bg.update(dt)
        
        # === 렌더링 ===
        # 배경 그리기
        space_bg.draw(SCREEN)
        
        # 반투명 오버레이 (메뉴 가독성)
        overlay = pygame.Surface((WIDTH, HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 20, 100))
        SCREEN.blit(overlay, (0, 0))
        
        # 타이틀 "메인 메뉴"
        title_text = "메인 메뉴"
        title_font = pygame.font.Font("NanumSquareB.ttf", 72)
        
        # 타이틀 글로우 효과
        for offset in range(3, 0, -1):
            glow_alpha = int(100 * title_glow / offset)
            glow_color = (100, 200, 255, glow_alpha)
            glow_surf = pygame.Surface((WIDTH, 100), pygame.SRCALPHA)
            
            title_glow_text = title_font.render(title_text, True, glow_color)
            title_glow_rect = title_glow_text.get_rect(center=(WIDTH // 2, 120 + title_offset))
            glow_surf.blit(title_glow_text, title_glow_rect)
            
            SCREEN.blit(glow_surf, (0, 0))
        
        # 타이틀 메인 텍스트
        title_surface = title_font.render(title_text, True, (255, 255, 255))
        title_rect = title_surface.get_rect(center=(WIDTH // 2, 120 + title_offset))
        SCREEN.blit(title_surface, title_rect)
        
        # 타이틀 언더라인
        line_width = 300
        line_x = WIDTH // 2 - line_width // 2
        line_y = 180 + title_offset
        pygame.draw.line(SCREEN, (100, 200, 255), 
                        (line_x, line_y), (line_x + line_width, line_y), 2)
        
        # 메뉴 옵션들
        menu_y_start = 280
        menu_spacing = 60
        
        for i, option in enumerate(menu_options):
            # 위치 계산
            y_pos = menu_y_start + i * menu_spacing
            
            # 선택된 항목 하이라이트 배경
            if i == selected:
                # 배경 박스
                box_width = 400
                box_height = 50
                box_x = WIDTH // 2 - box_width // 2
                box_y = y_pos - box_height // 2
                
                # 글로우 효과
                glow_surf = pygame.Surface((box_width + 20, box_height + 20), pygame.SRCALPHA)
                pygame.draw.rect(glow_surf, (100, 200, 255, 30), glow_surf.get_rect(), border_radius=10)
                SCREEN.blit(glow_surf, (box_x - 10, box_y - 10))
                
                # 메인 박스
                pygame.draw.rect(SCREEN, (20, 40, 60, 180), 
                               (box_x, box_y, box_width, box_height), 
                               border_radius=8)
                pygame.draw.rect(SCREEN, (100, 200, 255), 
                               (box_x, box_y, box_width, box_height), 
                               2, border_radius=8)
                
                # 화살표 인디케이터
                arrow_x = box_x - 30
                arrow_points = [
                    (arrow_x, y_pos - 10),
                    (arrow_x - 15, y_pos),
                    (arrow_x, y_pos + 10)
                ]
                pygame.draw.polygon(SCREEN, (100, 200, 255), arrow_points)
            
            # 텍스트 스케일 적용
            scale = menu_hover_scale[i]
            
            # 폰트 크기 조정
            if i == selected:
                menu_font = pygame.font.Font("NanumSquareB.ttf", int(32 * scale))
                text_color = (255, 255, 255)
            else:
                menu_font = pygame.font.Font("NanumSquareR.ttf", 28)
                text_color = (180, 180, 200)
            
            # 텍스트 렌더링
            text_surface = menu_font.render(option, True, text_color)
            text_rect = text_surface.get_rect(center=(WIDTH // 2, y_pos))
            SCREEN.blit(text_surface, text_rect)
            
            # 잠금 상태 표시 (NEW BOSS BATTLE)
            if option == "NEW BOSS BATTLE":
                lock_font = pygame.font.Font("NanumSquareR.ttf", 16)
                lock_text = lock_font.render("🔒 Coming Soon", True, (255, 200, 100))
                lock_rect = lock_text.get_rect(center=(WIDTH // 2, y_pos + 25))
                SCREEN.blit(lock_text, lock_rect)
        
        # 하단 안내 텍스트
        help_font = pygame.font.Font("NanumSquareR.ttf", 18)
        help_text = "↑↓ 선택    ENTER 확인    ESC 종료"
        help_surface = help_font.render(help_text, True, (150, 150, 170))
        help_rect = help_surface.get_rect(center=(WIDTH // 2, HEIGHT - 40))
        SCREEN.blit(help_surface, help_rect)
        
        # 버전 정보
        version_font = pygame.font.Font("NanumSquareR.ttf", 14)
        version_text = "PingFighter v1.0"
        version_surface = version_font.render(version_text, True, (100, 100, 120))
        version_rect = version_surface.get_rect(bottomright=(WIDTH - 10, HEIGHT - 10))
        SCREEN.blit(version_surface, version_rect)
        
        # 화면 업데이트
        pygame.display.flip()
    
    return "quit"