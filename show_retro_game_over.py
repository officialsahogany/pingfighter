"""
레트로 스타일 게임 종료 화면 테스트
"""
import pygame
import sys
from ui.retro_game_over import RetroGameOverScreen

def show_retro_game_over():
    """레트로 게임 종료 화면 표시"""
    pygame.init()
    
    # 화면 설정
    WIDTH = 600
    HEIGHT = 750
    SCREEN = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("게임 종료 - 최종 실력 평가")
    
    # 레트로 화면 생성
    retro_screen = RetroGameOverScreen(WIDTH, HEIGHT)
    
    # 테스트용 게임 통계
    game_stats = {
        'stage': 6,
        'difficulty': 3.0,
        'skill_grade': 'F',
        'skill_score': 20,
        'dash_grade': 'F',
        'dash_score': 25,
        'item_grade': 'C',
        'item_score': 60,
        'guard_grade': 'C',
        'guard_score': 60,
        'total_score': 439,
        'max_score': 2000,
        'skill_points': 77,
        'dash_points': 75,
        'item_points': 37,
        'bonus': 300,
        'penalty': 1800
    }
    
    clock = pygame.time.Clock()
    running = True
    
    while running:
        dt = clock.tick(60) / 1000.0  # 60 FPS
        
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key in [pygame.K_ESCAPE, pygame.K_SPACE]:
                    running = False
        
        # 업데이트
        retro_screen.update(dt)
        
        # 그리기
        retro_screen.draw(SCREEN, game_stats)
        
        pygame.display.flip()
    
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    show_retro_game_over()