# -*- coding: utf-8 -*-
"""
스테이지 2 정글 필러 테스트 - 미니멀 버전 확인
"""
import pygame
import sys

pygame.init()

# 화면 설정
SCREEN_WIDTH = 1280
SCREEN_HEIGHT = 720
GAME_WIDTH = 800
GAME_HEIGHT = 600

screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Stage 2 Jungle Pillar Test - Minimal")

# 정글 필러 임포트
from pillar_jungle import MossyStoneFrame

# 인스턴스 생성
jungle_frame = MossyStoneFrame(SCREEN_WIDTH, SCREEN_HEIGHT, GAME_WIDTH, GAME_HEIGHT)

clock = pygame.time.Clock()
running = True

while running:
    dt = clock.tick(60) / 1000.0

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        elif event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            elif event.key == pygame.K_SPACE:
                jungle_frame.trigger_excitement(1.5)

    # 업데이트
    jungle_frame.update(dt)

    # 그리기
    screen.fill((20, 20, 25))
    jungle_frame.draw(screen)

    # 게임 영역 표시
    game_x = (SCREEN_WIDTH - GAME_WIDTH) // 2
    game_y = (SCREEN_HEIGHT - GAME_HEIGHT) // 2
    pygame.draw.rect(screen, (40, 60, 40), (game_x, game_y, GAME_WIDTH, GAME_HEIGHT))

    # 안내 텍스트
    font = pygame.font.Font(None, 24)
    text = font.render("Stage 2 Jungle Pillar - Minimal Version (ESC to exit, SPACE for effect)", True, (200, 200, 200))
    screen.blit(text, (10, 10))

    pygame.display.flip()

pygame.quit()
sys.exit()
