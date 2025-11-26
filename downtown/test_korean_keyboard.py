#!/usr/bin/env python3
"""
한글 키보드 이동 테스트
ㅁㅈㅇㄴ 키로 플레이어 이동 테스트
"""

import sys
import os
import pygame

# 프로젝트 루트를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from downtown.constants import *
from downtown.player import DowntownPlayer

def test_korean_keyboard():
    """한글 키보드 테스트"""
    pygame.init()

    # 화면 설정
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("한글 키보드 이동 테스트 - ㅁㅈㅇㄴ 키로 이동")

    clock = pygame.time.Clock()

    # 플레이어 생성
    player = DowntownPlayer(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2)

    # 폰트
    font = pygame.font.Font(None, 24)
    small_font = pygame.font.Font(None, 18)

    running = True
    while running:
        dt = clock.tick(60) / 1000.0

        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False

                # 한글 키보드 감지
                if hasattr(event, 'unicode') and event.unicode:
                    if event.unicode in ['ㅁ', 'ㅇ', 'ㅈ', 'ㄴ']:
                        player.set_korean_key(
                            event.unicode,
                            True,
                            scancode=getattr(event, "scancode", None),
                            keycode=event.key,
                        )
                        print(
                            f"한글 키 감지: {event.unicode} "
                            f"(scancode: {getattr(event, 'scancode', None)}, keycode: {event.key})"
                        )

            elif event.type == pygame.KEYUP:
                # 한글 키 릴리즈
                player.release_korean_key_by_scancode(
                    getattr(event, "scancode", None), keycode=event.key
                )

        # 입력 처리 (일반 키 + 한글 키)
        keys = pygame.key.get_pressed()
        player.handle_input(keys, dt)

        # 플레이어 업데이트 (맵 없이 자유 이동)
        player.x += player.velocity_x
        player.y += player.velocity_y

        # 화면 경계 체크
        player.x = max(50, min(SCREEN_WIDTH - 50, player.x))
        player.y = max(50, min(SCREEN_HEIGHT - 50, player.y))

        # 화면 그리기
        screen.fill((20, 20, 30))

        # 플레이어 그리기 (간단한 원)
        pygame.draw.circle(screen, (100, 149, 237), (int(player.x), int(player.y)), 30)

        # 방향 표시
        direction_texts = ["아래", "왼쪽", "오른쪽", "위"]
        direction_text = direction_texts[player.direction]
        dir_surface = font.render(f"방향: {direction_text}", True, (255, 255, 255))
        screen.blit(dir_surface, (10, 10))

        # 속도 표시
        vel_text = f"속도: ({player.velocity_x:.1f}, {player.velocity_y:.1f})"
        vel_surface = font.render(vel_text, True, (255, 255, 255))
        screen.blit(vel_surface, (10, 40))

        # 위치 표시
        pos_text = f"위치: ({int(player.x)}, {int(player.y)})"
        pos_surface = font.render(pos_text, True, (255, 255, 255))
        screen.blit(pos_surface, (10, 70))

        # 한글 키 상태 표시
        korean_status = []
        if player.korean_key_left:
            korean_status.append("ㅁ(왼쪽)")
        if player.korean_key_right:
            korean_status.append("ㄹ(오른쪽)")
        if player.korean_key_up:
            korean_status.append("ㅈ(위)")
        if player.korean_key_down:
            korean_status.append("ㄴ(아래)")

        if korean_status:
            korean_text = "한글 키: " + ", ".join(korean_status)
        else:
            korean_text = "한글 키: 없음"
        korean_surface = font.render(korean_text, True, (150, 255, 150))
        screen.blit(korean_surface, (10, 100))

        # 사용법 안내
        guide_lines = [
            "== 사용법 ==",
            "WASD 또는 화살표: 이동",
            "ㅁㅈㅇㄴ (한글): 이동",
            "  ㅁ = 왼쪽 (a)",
            "  ㅇ = 오른쪽 (d)",
            "  ㅈ = 위 (w)",
            "  ㄴ = 아래 (s)",
            "ESC: 종료"
        ]

        y_offset = SCREEN_HEIGHT - 160
        for line in guide_lines:
            guide_surface = small_font.render(line, True, (200, 200, 200))
            screen.blit(guide_surface, (10, y_offset))
            y_offset += 20

        pygame.display.flip()

    pygame.quit()
    print("\n✅ 한글 키보드 테스트 종료")

if __name__ == "__main__":
    print("\n" + "="*80)
    print("🎮 한글 키보드 이동 테스트")
    print("="*80)
    print("\n한글 입력 모드에서 ㅁㅈㅇㄴ 키로 플레이어를 이동할 수 있습니다.")
    print("  ㅁ = 왼쪽 (a키 위치)")
    print("  ㅇ = 오른쪽 (d키 위치)")
    print("  ㅈ = 위 (w키 위치)")
    print("  ㄴ = 아래 (s키 위치)")
    print("\n일반 WASD 키와 화살표 키도 사용 가능합니다.\n")
    print("="*80 + "\n")

    test_korean_keyboard()
