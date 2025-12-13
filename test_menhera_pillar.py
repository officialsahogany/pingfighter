# -*- coding: utf-8 -*-
"""
Stage 3 멘헤라 스타일 필러 배경 테스트
- 거대한 귀여운 인형이 게임 영역을 감싸는 느낌
- 멘헤라 스타일 배경 (일본어, 하트 등)
"""

import pygame
import sys

# 초기화
pygame.init()

# 화면 설정
SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
GAME_WIDTH = 800
GAME_HEIGHT = 600

screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Stage 3 - Menhera Plush Frame Test")

# 멘헤라 배경 임포트
from pillar_menhera import init_menhera_background, get_menhera_background

# 배경 초기화
bg = init_menhera_background(SCREEN_WIDTH, SCREEN_HEIGHT, GAME_WIDTH, GAME_HEIGHT)

# 게임 영역 위치
game_x = (SCREEN_WIDTH - GAME_WIDTH) // 2
game_y = (SCREEN_HEIGHT - GAME_HEIGHT) // 2

clock = pygame.time.Clock()
running = True

print("멘헤라 스타일 필러 배경 테스트")
print("- 거대한 인형이 게임 영역을 감싸는 스타일")
print("- 스페이스바: 흥분 효과")
print("- ESC: 종료")

while running:
    dt = clock.tick(60) / 1000.0

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                bg.trigger_excitement(2.0)
                print("흥분 효과!")

    # 배경 업데이트
    bg.update(dt)

    # 화면 클리어
    screen.fill((0, 0, 0))

    # 배경 그리기
    bg.draw(screen)

    # 게임 영역 (임시 - 어두운 보라색)
    game_rect = pygame.Rect(game_x, game_y, GAME_WIDTH, GAME_HEIGHT)
    pygame.draw.rect(screen, (25, 15, 30), game_rect)

    # 게임 영역 안내 텍스트
    font = pygame.font.SysFont('Arial', 24)
    text = font.render("Game Area", True, (150, 100, 150))
    text_rect = text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2))
    screen.blit(text, text_rect)

    # FPS 표시
    fps = int(clock.get_fps())
    fps_text = font.render(f"FPS: {fps}", True, (200, 200, 200))
    screen.blit(fps_text, (10, 10))

    pygame.display.flip()

pygame.quit()
sys.exit()
