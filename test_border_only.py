#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""내부 테두리만 표시하는 테스트"""

import pygame
import sys
import os
import math

# 상위 디렉토리를 sys.path에 추가
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

def resource_path(relative_path):
    """PyInstaller 환경과 개발 환경 모두에서 작동하는 리소스 경로 반환"""
    try:
        base_path = sys._MEIPASS
    except Exception:
        base_path = os.path.dirname(os.path.abspath(__file__))

    relative_path = relative_path.replace('/', os.sep).replace('\\', os.sep)
    return os.path.join(base_path, relative_path)

def _extract_ring_overlay(surface):
    """라그나로크 해머 프레임에서 붉은 링/코너 하이라이트만 추출한다."""
    overlay = pygame.Surface(surface.get_size(), pygame.SRCALPHA)
    width, height = surface.get_size()
    center_x, center_y = width // 2, height // 2

    for y in range(height):
        for x in range(width):
            color = surface.get_at((x, y))
            if color.a == 0:
                continue

            # 중앙으로부터의 거리 계산
            dist_from_center = math.sqrt((x - center_x) ** 2 + (y - center_y) ** 2)

            # 갈색 해머 손잡이 필터링 (갈색 계열 색상 제외)
            is_brown = (color.r > 100 and color.r < 180 and
                       color.g > 50 and color.g < 120 and
                       color.b < 80)

            # 중앙 근처의 색상 제외 (해머 손잡이 영역)
            in_center_area = dist_from_center < width * 0.35

            # 테두리 근처 여부 (더 두꺼운 테두리를 위해 범위 확장)
            near_edge = x < 10 or x >= width - 10 or y < 10 or y >= height - 10

            # 빨간색 계열 (테두리) - 임계값을 낮춰서 더 많은 테두리 포함
            red_dominant = color.r > 150 and color.r > color.g + 15 and color.r > color.b + 15

            # 따뜻한 하이라이트 (모서리 장식) - 임계값 조정
            warm_highlight = color.r > 180 and color.g > 100 and color.b > 60

            # 테두리나 하이라이트이면서, 갈색이 아니고, 중앙이 아닌 경우만 복사
            if (near_edge or red_dominant or warm_highlight) and not is_brown and not in_center_area:
                overlay.set_at((x, y), color)

    return overlay

def main():
    """내부 테두리만 표시"""
    # Pygame 초기화
    pygame.init()

    # 화면 설정
    SCREEN_WIDTH = 800
    SCREEN_HEIGHT = 600
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("내부 테두리만 표시 - Border Only Test")

    # 색상 정의
    BLACK = (0, 0, 0)
    WHITE = (255, 255, 255)
    DARK_GRAY = (40, 40, 40)
    LIGHT_GRAY = (100, 100, 100)

    # 폰트 초기화
    font = pygame.font.Font(None, 36)
    small_font = pygame.font.Font(None, 24)

    # 시계 초기화
    clock = pygame.time.Clock()

    # 라그나로크 프레임 로드
    ragnarok_frames = []
    for i in range(8):
        frame_path = resource_path(f"items/legendary/ragnarok_hammer_frame_{i}.png")
        try:
            frame = pygame.image.load(frame_path).convert_alpha()
            ragnarok_frames.append(frame)
            print(f"✓ 라그나로크 프레임 {i} 로드 성공")
        except Exception as e:
            print(f"[ERROR] 라그나로크 프레임 {i} 로드 실패: {e}")
            empty_frame = pygame.Surface((60, 60), pygame.SRCALPHA)
            ragnarok_frames.append(empty_frame)

    # 애니메이션 변수
    current_frame = 0
    frame_counter = 0
    animation_speed = 8

    # 메인 루프
    running = True

    while running:
        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                elif event.key == pygame.K_SPACE:
                    # 프레임 수동 전진
                    current_frame = (current_frame + 1) % 8

        # 화면 지우기
        screen.fill(DARK_GRAY)

        # 격자 배경 그리기
        for x in range(0, SCREEN_WIDTH, 50):
            pygame.draw.line(screen, (50, 50, 50), (x, 0), (x, SCREEN_HEIGHT))
        for y in range(0, SCREEN_HEIGHT, 50):
            pygame.draw.line(screen, (50, 50, 50), (0, y), (SCREEN_WIDTH, y))

        # 제목 표시
        title_text = font.render("내부 테두리만 표시 (Border Only)", True, WHITE)
        screen.blit(title_text, (SCREEN_WIDTH // 2 - title_text.get_width() // 2, 20))

        # 설명 텍스트
        desc_text = small_font.render("_extract_ring_overlay 함수 결과", True, (200, 200, 200))
        screen.blit(desc_text, (SCREEN_WIDTH // 2 - desc_text.get_width() // 2, 60))

        # 조작 설명
        control_text = small_font.render("SPACE: 프레임 전진 | ESC: 종료", True, (150, 150, 150))
        screen.blit(control_text, (10, SCREEN_HEIGHT - 30))

        if ragnarok_frames and len(ragnarok_frames) > 0:
            # 프레임 애니메이션 업데이트
            frame_counter += 1
            if frame_counter >= animation_speed:
                frame_counter = 0
                current_frame = (current_frame + 1) % len(ragnarok_frames)

            # 현재 프레임 가져오기
            original_frame = ragnarok_frames[current_frame]

            # 다양한 크기로 테스트
            test_sizes = [60, 100, 150, 200]

            for i, size in enumerate(test_sizes):
                # 프레임 크기 조정
                if original_frame.get_size() != (size, size):
                    scaled_frame = pygame.transform.scale(original_frame, (size, size))
                else:
                    scaled_frame = original_frame

                # 테두리만 추출
                border_only = _extract_ring_overlay(scaled_frame)

                # 위치 계산
                x = 100 + (i % 2) * 350
                y = 150 + (i // 2) * 200

                # 배경 패널
                panel_rect = pygame.Rect(x - 20, y - 20, size + 40, size + 80)
                pygame.draw.rect(screen, (30, 30, 30), panel_rect)
                pygame.draw.rect(screen, (60, 60, 60), panel_rect, 2)

                # 체크보드 패턴 (투명도 확인용)
                check_size = 10
                for cy in range(y, y + size, check_size):
                    for cx in range(x, x + size, check_size):
                        if ((cx - x) // check_size + (cy - y) // check_size) % 2 == 0:
                            pygame.draw.rect(screen, LIGHT_GRAY,
                                           (cx, cy, min(check_size, x + size - cx),
                                            min(check_size, y + size - cy)))

                # 추출된 테두리 그리기
                screen.blit(border_only, (x, y))

                # 크기 레이블
                size_label = small_font.render(f"{size}px", True, WHITE)
                screen.blit(size_label, (x + size // 2 - size_label.get_width() // 2, y + size + 10))

                # 프레임 번호
                frame_label = small_font.render(f"Frame {current_frame}/7", True, (150, 150, 150))
                screen.blit(frame_label, (x + size // 2 - frame_label.get_width() // 2, y + size + 35))

        # 정보 표시
        info_text = small_font.render(f"현재 프레임: {current_frame}/7", True, WHITE)
        screen.blit(info_text, (SCREEN_WIDTH - 200, 20))

        # 필터 정보
        filter_info = [
            "필터 조건:",
            "• 테두리 범위: 10픽셀",
            "• 빨간색 임계값: R>150, R>G+15, R>B+15",
            "• 하이라이트: R>180, G>100, B>60",
            "• 갈색 제외: R(100-180), G(50-120), B<80",
            "• 중앙 35% 제외"
        ]

        for i, text in enumerate(filter_info):
            info_surf = small_font.render(text, True, (150, 200, 150))
            screen.blit(info_surf, (20, 100 + i * 25))

        # 화면 업데이트
        pygame.display.flip()
        clock.tick(60)

    # 종료
    pygame.quit()
    sys.exit()

if __name__ == "__main__":
    main()