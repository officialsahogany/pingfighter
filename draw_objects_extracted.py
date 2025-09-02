# draw_objects에서 추출한 함수들

import pygame

def draw_serve_ui_section(is_waiting_for_serve, waiting_start_time, is_player_serve, 
                        WIDTH, HEIGHT, SCREEN, boss_names, current_stage):
    """서브 대기 상태 UI 그리기 - draw_objects에서 추출"""
    # 🎾 서브 대기 상태 UI (미니멀 디자인)
    if is_waiting_for_serve:
        # 시간 계산
        current_time = pygame.time.get_ticks()
        wait_time = current_time - waiting_start_time
        
        if is_player_serve:
            # 🟢 플레이어 서브 - 하단 미니멀 UI
            serve_font = pygame.font.Font("NanumSquareB.ttf", 24)
            info_font = pygame.font.Font("NanumSquareR.ttf", 16)
            
            # 간단한 텍스트만 표시
            serve_text = serve_font.render("Player Serve", True, (255, 255, 255))
            serve_rect = serve_text.get_rect(center=(WIDTH // 2, HEIGHT - 100))
            SCREEN.blit(serve_text, serve_rect)
            
            # 액센트 라인
            line_width = serve_rect.width + 20
            line_y = serve_rect.bottom + 5
            line_surface = pygame.Surface((line_width, 2), pygame.SRCALPHA)
            line_surface.fill((0, 200, 100))
            SCREEN.blit(line_surface, ((WIDTH - line_width) // 2, line_y))
            
            # 3초 후 자동 서브 카운트다운
            if wait_time >= 1000:
                remaining = max(0, 3000 - wait_time) // 1000
                if remaining > 0:
                    countdown_text = info_font.render(f"SPACE ({remaining}s)", True, (200, 200, 200))
                else:
                    countdown_text = info_font.render("Auto serve", True, (255, 255, 100))
            else:
                countdown_text = info_font.render("Press SPACE", True, (200, 200, 200))
            
            countdown_rect = countdown_text.get_rect(center=(WIDTH // 2, serve_rect.bottom + 20))
            SCREEN.blit(countdown_text, countdown_rect)
            
        else:
            # 🔴 보스 서브 - 상단 미니멀 UI
            serve_font = pygame.font.Font("NanumSquareB.ttf", 24)
            info_font = pygame.font.Font("NanumSquareR.ttf", 16)
            
            # 간단한 텍스트만 표시
            boss_name = boss_names.get(current_stage, "Boss")
            serve_text = serve_font.render(f"{boss_name} Serve", True, (255, 255, 255))
            serve_rect = serve_text.get_rect(center=(WIDTH // 2, 80))
            SCREEN.blit(serve_text, serve_rect)
            
            # 액센트 라인
            line_width = serve_rect.width + 20
            line_y = serve_rect.bottom + 5
            line_surface = pygame.Surface((line_width, 2), pygame.SRCALPHA)
            line_surface.fill((200, 80, 80))
            SCREEN.blit(line_surface, ((WIDTH - line_width) // 2, line_y))
            
            # 상태 텍스트
            if boss_fake_move and wait_delay > 0:
                remaining = max(0, wait_delay - wait_time) // 100
                if remaining > 0:
                    status_text = info_font.render("Preparing...", True, (200, 200, 200))
                else:
                    status_text = info_font.render("Ready", True, (255, 255, 100))
            else:
                status_text = info_font.render("Waiting...", True, (200, 200, 200))
            
            status_rect = status_text.get_rect(center=(WIDTH // 2, serve_rect.bottom + 20))
            SCREEN.blit(status_text, status_rect)
