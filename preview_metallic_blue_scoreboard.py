#!/usr/bin/env python3
"""메탈릭 블루 전광판 미리보기"""
import pygame
import sys
import os

# 현재 디렉토리를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ui.ice_crystal_scoreboard import draw_ice_crystal_scoreboard

def main():
    pygame.init()

    WIDTH, HEIGHT = 800, 400
    screen = pygame.display.set_mode((WIDTH, HEIGHT))
    pygame.display.set_caption("메탈릭 블루 전광판 미리보기")

    clock = pygame.time.Clock()

    # 테스트용 점수
    player_score = 2
    boss_score = 1
    current_stage = 1  # 스테이지 변경용

    font = pygame.font.SysFont("Arial", 20)

    running = True
    while running:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                # 스테이지 변경 (1-8)
                elif event.key == pygame.K_1:
                    current_stage = 1
                elif event.key == pygame.K_2:
                    current_stage = 2
                elif event.key == pygame.K_3:
                    current_stage = 3
                elif event.key == pygame.K_4:
                    current_stage = 4
                elif event.key == pygame.K_5:
                    current_stage = 5
                elif event.key == pygame.K_6:
                    current_stage = 6
                elif event.key == pygame.K_7:
                    current_stage = 7
                elif event.key == pygame.K_8:
                    current_stage = 8
                # 점수 변경
                elif event.key == pygame.K_UP:
                    player_score = min(5, player_score + 1)
                elif event.key == pygame.K_DOWN:
                    player_score = max(0, player_score - 1)
                elif event.key == pygame.K_RIGHT:
                    boss_score = min(5, boss_score + 1)
                elif event.key == pygame.K_LEFT:
                    boss_score = max(0, boss_score - 1)

        # 배경 (게임 배경 시뮬레이션)
        screen.fill((30, 30, 50))

        # 전광판 그리기
        draw_ice_crystal_scoreboard(screen, player_score, boss_score, WIDTH, HEIGHT, current_stage)

        # 조작 안내
        help_text = [
            f"Stage: {current_stage} | Player: {player_score} | Boss: {boss_score}",
            "1-8: 스테이지 변경 | ↑↓: 플레이어 점수 | ←→: 보스 점수 | ESC: 종료"
        ]
        for i, text in enumerate(help_text):
            rendered = font.render(text, True, (200, 200, 200))
            screen.blit(rendered, (20, HEIGHT - 60 + i * 25))

        pygame.display.flip()
        clock.tick(60)

    pygame.quit()

if __name__ == "__main__":
    main()
