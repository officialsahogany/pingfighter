# -*- coding: utf-8 -*-
"""콜로세움 투기장 간단 테스트"""

import pygame
import pygame.freetype
import sys
import os

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from downtown.colosseum_arena import ColosseumsArena, SCREEN_WIDTH, SCREEN_HEIGHT

def main():
    pygame.init()
    pygame.freetype.init()

    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("콜로세움 투기장 테스트")
    clock = pygame.time.Clock()

    # 폰트
    fonts = {}
    try:
        fonts["small"] = pygame.freetype.Font(None, 16)
        fonts["medium"] = pygame.freetype.Font(None, 20)
        fonts["large"] = pygame.freetype.Font(None, 28)
    except Exception as e:
        print(f"Font error: {e}")

    # 투기장 생성
    arena = ColosseumsArena(screen, fonts, 1000)

    running = True
    frame_count = 0

    while running:
        dt = clock.tick(60) / 1000.0
        frame_count += 1

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
            elif arena.handle_event(event):
                running = False

        arena.update(dt)
        arena.draw()

        # 상태 표시
        if fonts.get("small"):
            state_text = f"State: {arena.state.name} | Frame: {frame_count}"
            surf, _ = fonts["small"].render(state_text, (255, 255, 0))
            screen.blit(surf, (10, SCREEN_HEIGHT - 25))

        pygame.display.flip()

    pygame.quit()

if __name__ == "__main__":
    main()
