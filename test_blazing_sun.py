# -*- coding: utf-8 -*-
"""불타는 태양 필러 테스트"""

import pygame
import time
import sys
import os

# 현재 디렉토리를 경로에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from pillar_blazing_sun import BlazingSunFrame

def main():
    pygame.init()
    screen = pygame.display.set_mode((1280, 720))
    pygame.display.set_caption("🔥 불타는 태양 필러 테스트 - 스페이스바로 로딩 시뮬레이션")
    clock = pygame.time.Clock()

    # 필러 생성 (게임 영역: 900x600)
    pillar = BlazingSunFrame(1280, 720, 900, 600)

    # 폰트
    font = pygame.font.Font(None, 48)
    small_font = pygame.font.Font(None, 28)

    running = True
    progress = 0.0
    auto_mode = False

    print("=" * 50)
    print("🔥 불타는 태양 필러 테스트")
    print("=" * 50)
    print("조작법:")
    print("  ↑/↓ : 강렬함 수동 조절")
    print("  SPACE : 자동 로딩 시뮬레이션 시작/정지")
    print("  R : 리셋")
    print("  ESC : 종료")
    print("=" * 50)

    while running:
        dt = clock.tick(60) / 1000.0

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    auto_mode = not auto_mode
                    if auto_mode:
                        progress = 0.0
                    print(f"자동 모드: {'ON' if auto_mode else 'OFF'}")
                elif event.key == pygame.K_r:
                    progress = 0.0
                    auto_mode = False
                    print("리셋!")

        # 수동 조절
        keys = pygame.key.get_pressed()
        if not auto_mode:
            if keys[pygame.K_UP]:
                progress = min(1.0, progress + dt * 0.5)
            if keys[pygame.K_DOWN]:
                progress = max(0.0, progress - dt * 0.5)

        # 자동 로딩 시뮬레이션
        if auto_mode:
            progress += dt * 0.15  # 약 7초에 걸쳐 완료
            if progress >= 1.0:
                progress = 1.0
                auto_mode = False
                print("로딩 완료!")

        # 필러 업데이트 및 그리기
        pillar.set_intensity(progress)
        pillar.update(dt)
        pillar.draw(screen)

        # UI 오버레이 (게임 영역 내부)
        game_x = (1280 - 900) // 2
        game_y = (720 - 600) // 2

        # 진행률 텍스트
        progress_text = f"로딩: {progress * 100:.0f}%"
        text_surface = font.render(progress_text, True, (255, 255, 255))
        text_rect = text_surface.get_rect(center=(640, 300))
        screen.blit(text_surface, text_rect)

        # 강렬함 레벨 표시
        if progress < 0.2:
            level_text = "🌑 약한 불씨"
            level_color = (150, 80, 50)
        elif progress < 0.5:
            level_text = "🔥 타오르는 중"
            level_color = (200, 100, 50)
        elif progress < 0.8:
            level_text = "🔥🔥 맹렬한 화염"
            level_color = (255, 150, 50)
        else:
            level_text = "☀️ 백열 태양!"
            level_color = (255, 220, 100)

        level_surface = small_font.render(level_text, True, level_color)
        level_rect = level_surface.get_rect(center=(640, 350))
        screen.blit(level_surface, level_rect)

        # 조작 안내
        help_text = "SPACE: 자동 | ↑↓: 수동 | R: 리셋 | ESC: 종료"
        help_surface = small_font.render(help_text, True, (150, 150, 150))
        help_rect = help_surface.get_rect(center=(640, 650))
        screen.blit(help_surface, help_rect)

        # 프로그레스 바
        bar_width = 400
        bar_height = 10
        bar_x = (1280 - bar_width) // 2
        bar_y = 400

        # 배경
        pygame.draw.rect(screen, (50, 30, 20), (bar_x - 2, bar_y - 2, bar_width + 4, bar_height + 4), border_radius=5)
        pygame.draw.rect(screen, (30, 20, 15), (bar_x, bar_y, bar_width, bar_height), border_radius=4)

        # 진행 바 (그라데이션)
        fill_width = int(bar_width * progress)
        if fill_width > 0:
            for i in range(fill_width):
                ratio = i / bar_width
                # 진행률에 따른 색상
                if progress < 0.5:
                    r = int(150 + ratio * 105)
                    g = int(50 + ratio * 50)
                    b = int(20)
                else:
                    intensity = (progress - 0.5) * 2
                    r = 255
                    g = int(100 + intensity * 100 + ratio * 55)
                    b = int(20 + intensity * 80)
                pygame.draw.line(screen, (r, g, b),
                               (bar_x + i, bar_y), (bar_x + i, bar_y + bar_height - 1))

        pygame.display.flip()

    pygame.quit()
    print("테스트 종료!")

if __name__ == "__main__":
    main()
