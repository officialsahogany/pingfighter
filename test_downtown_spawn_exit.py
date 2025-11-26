#!/usr/bin/env python3
"""
번화가 시작/도착 위치 및 오오라 테스트
"""

import pygame
import sys
import os

# 프로젝트 루트를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from downtown.map_generator import DowntownMap
from downtown.renderer import DowntownRenderer
from downtown.constants import SCREEN_WIDTH, SCREEN_HEIGHT, TILE_SIZE, TileType

def test_spawn_exit_positions():
    """시작/도착 위치 테스트"""
    print("=== 시작/도착 위치 테스트 ===")

    # 맵 생성
    test_map = DowntownMap(stage_number=1, seed=12345)

    # 시작 위치
    spawn_tile = test_map.spawn_point
    spawn_pixel = test_map.get_spawn_pixel_pos()
    print(f"시작 위치 (타일): {spawn_tile}")
    print(f"시작 위치 (픽셀): {spawn_pixel}")
    print(f"시작 타일 타입: {test_map.get_tile(*spawn_tile)}")

    # 도착 위치
    exit_tile = test_map.exit_point
    exit_pixel = test_map.get_exit_pixel_pos()
    print(f"도착 위치 (타일): {exit_tile}")
    print(f"도착 위치 (픽셀): {exit_pixel}")
    print(f"도착 타일 타입: {test_map.get_tile(*exit_tile)}")

    # 위치 확인 (아래에서 시작 → 위로 출구)
    if spawn_tile[1] > exit_tile[1]:
        print("✅ 올바른 방향: 아래(시작) → 위(출구)")
    else:
        print("❌ 잘못된 방향: 위(시작) → 아래(출구)")

    return test_map

def test_aura_rendering():
    """오오라 렌더링 테스트"""
    print("\n=== 오오라 렌더링 테스트 ===")

    # Pygame 초기화
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("Downtown Spawn/Exit Aura Test")
    clock = pygame.time.Clock()

    # 맵 및 렌더러 생성
    test_map = DowntownMap(stage_number=1, seed=12345)
    renderer = DowntownRenderer()

    # 카메라를 시작 위치로 설정
    spawn_pixel = test_map.get_spawn_pixel_pos()
    renderer.camera_x = spawn_pixel[0] - SCREEN_WIDTH // 2
    renderer.camera_y = spawn_pixel[1] - SCREEN_HEIGHT // 2

    print("렌더링 테스트 시작 (ESC로 종료)")
    print("방향키: 카메라 이동")
    print("1: 시작점으로 이동")
    print("2: 도착점으로 이동")

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
                elif event.key == pygame.K_1:
                    # 시작점으로 이동
                    spawn_pixel = test_map.get_spawn_pixel_pos()
                    renderer.camera_x = spawn_pixel[0] - SCREEN_WIDTH // 2
                    renderer.camera_y = spawn_pixel[1] - SCREEN_HEIGHT // 2
                    print("시작점으로 이동")
                elif event.key == pygame.K_2:
                    # 도착점으로 이동
                    exit_pixel = test_map.get_exit_pixel_pos()
                    renderer.camera_x = exit_pixel[0] - SCREEN_WIDTH // 2
                    renderer.camera_y = exit_pixel[1] - SCREEN_HEIGHT // 2
                    print("도착점으로 이동")

        # 카메라 이동 (방향키)
        keys = pygame.key.get_pressed()
        camera_speed = 300
        if keys[pygame.K_LEFT]:
            renderer.camera_x -= camera_speed * dt
        if keys[pygame.K_RIGHT]:
            renderer.camera_x += camera_speed * dt
        if keys[pygame.K_UP]:
            renderer.camera_y -= camera_speed * dt
        if keys[pygame.K_DOWN]:
            renderer.camera_y += camera_speed * dt

        # 렌더러 업데이트
        renderer.update(dt, renderer.camera_x + SCREEN_WIDTH // 2,
                       renderer.camera_y + SCREEN_HEIGHT // 2)

        # 렌더링
        screen.fill((0, 0, 0))

        # 1. 배경
        renderer.draw_background(screen)

        # 2. 타일 (기본 도로만)
        renderer.draw_tiles(screen, test_map)

        # 3. 오오라 레이어 (모든 것 위에)
        renderer.draw_spawn_exit_auras(screen, test_map)

        # 4. 디버그 정보
        font = pygame.font.Font(None, 24)
        camera_pos_text = font.render(
            f"Camera: ({int(renderer.camera_x)}, {int(renderer.camera_y)})",
            True, (255, 255, 255)
        )
        screen.blit(camera_pos_text, (10, 10))

        hint_text = font.render("1: Spawn | 2: Exit | Arrows: Move | ESC: Quit", True, (255, 255, 255))
        screen.blit(hint_text, (10, 40))

        pygame.display.flip()

    pygame.quit()
    print("렌더링 테스트 완료")

if __name__ == "__main__":
    print("번화가 시작/도착 위치 및 오오라 테스트\n")

    # 1. 위치 테스트
    test_map = test_spawn_exit_positions()

    # 2. 오오라 렌더링 테스트
    print("\n오오라 렌더링 테스트를 시작하시겠습니까? (y/n): ", end='')
    response = input().strip().lower()
    if response == 'y':
        test_aura_rendering()
    else:
        print("테스트 종료")
