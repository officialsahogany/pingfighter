#!/usr/bin/env python3
"""
마우스 클릭 건물 상호작용 테스트
건물을 클릭하면 "~~ 에 입장하시겠습니까? (행동 포인트 ~ 소모) 예 / 아니오" 다이얼로그 표시
"""

import sys
import os
import pygame

# 프로젝트 루트를 path에 추가
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from downtown.constants import *
from downtown.map_generator import DowntownMap
from downtown.player import DowntownPlayer
from downtown.renderer import DowntownRenderer
from downtown.buildings import BuildingManager
from downtown.action_points import ActionPointSystem

def test_mouse_click():
    """마우스 클릭 테스트"""
    pygame.init()

    # 화면 설정
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("마우스 클릭 테스트 - 건물을 클릭하세요")

    clock = pygame.time.Clock()

    # 맵 생성 (시드 42 - 은행이 가까운 맵, 자동 생성됨)
    downtown_map = DowntownMap(seed=42)

    # 플레이어 생성
    spawn_x = downtown_map.spawn_point[0] * TILE_SIZE + TILE_SIZE // 2
    spawn_y = downtown_map.spawn_point[1] * TILE_SIZE + TILE_SIZE // 2
    player = DowntownPlayer(spawn_x, spawn_y)

    # 렌더러 및 건물 매니저
    renderer = DowntownRenderer()
    buildings = BuildingManager()

    # 건물 배치
    for building_type, bx, by, bw, bh in downtown_map.buildings:
        buildings.add_building(building_type, bx, by, bw, bh)

    # 폰트 (freetype 사용 - 한글 지원)
    try:
        font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
        if os.path.exists(font_path):
            font = pygame.freetype.Font(font_path, 24)
            small_font = pygame.freetype.Font(font_path, 16)
        else:
            raise FileNotFoundError
    except:
        font = pygame.freetype.Font(None, 24)
        small_font = pygame.freetype.Font(None, 16)

    # 상태 변수
    confirmation_dialog = None
    dialog_yes_rect = None
    dialog_no_rect = None

    running = True
    while running:
        dt = clock.tick(60) / 1000.0

        # 이벤트 처리
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    if confirmation_dialog:
                        confirmation_dialog = None  # 다이얼로그 닫기
                    else:
                        running = False

                # 한글 키보드 이동
                if hasattr(event, 'unicode') and event.unicode:
                    if event.unicode in ['ㅁ', 'ㅇ', 'ㅈ', 'ㄴ']:
                        player.set_korean_key(
                            event.unicode,
                            True,
                            scancode=getattr(event, "scancode", None),
                            keycode=event.key,
                        )

            elif event.type == pygame.KEYUP:
                # 한글 키 릴리즈
                player.release_korean_key_by_scancode(
                    getattr(event, "scancode", None), keycode=event.key
                )

            elif event.type == pygame.MOUSEBUTTONDOWN:
                if event.button == 1:  # 왼쪽 마우스 버튼
                    # 다이얼로그가 열려있으면 버튼 클릭 처리
                    if confirmation_dialog:
                        if dialog_yes_rect and dialog_yes_rect.collidepoint(event.pos):
                            # 예 클릭 - 입장 처리
                            building_name = confirmation_dialog['building_name']
                            print(f"✅ {building_name}에 입장했습니다!")
                            confirmation_dialog = None
                        elif dialog_no_rect and dialog_no_rect.collidepoint(event.pos):
                            # 아니오 클릭 - 다이얼로그 닫기
                            print("❌ 입장을 취소했습니다.")
                            confirmation_dialog = None
                    else:
                        # 건물 클릭 체크
                        camera_offset = renderer.get_camera_offset()
                        clicked_building = player.check_building_click(
                            event.pos, camera_offset, downtown_map
                        )

                        if clicked_building:
                            building_type = clicked_building['building_type']
                            building_info = BUILDING_INFO[building_type]
                            confirmation_dialog = {
                                'building_type': building_type,
                                'building_name': building_info['name'],
                                'ap_cost': building_info['ap_cost']
                            }
                            print(f"🏛️ {building_info['name']} 클릭! (거리: {clicked_building['distance']:.1f}px)")

        # 입력 처리
        if not confirmation_dialog:  # 다이얼로그가 없을 때만 이동 가능
            keys = pygame.key.get_pressed()
            player.handle_input(keys, dt)

        # 플레이어 업데이트
        player.update(dt, downtown_map)

        # 렌더링
        screen.fill((20, 20, 30))

        # 카메라 오프셋
        camera_offset = renderer.get_camera_offset()

        # 타일 그리기
        renderer.draw_tiles(screen, downtown_map)

        # 건물 그리기
        buildings.draw(screen, camera_offset)

        # 플레이어 그리기
        player.draw(screen, camera_offset)

        # 안내 텍스트
        guide_lines = [
            "== 마우스 클릭 테스트 ==",
            "WASD / 화살표 / ㅁㅈㅇㄴ: 이동",
            "건물 클릭: 입장 확인 다이얼로그",
            "ESC: 종료 / 다이얼로그 닫기"
        ]

        y_offset = SCREEN_HEIGHT - 90
        for line in guide_lines:
            text_surface, _ = small_font.render(line, (200, 200, 200))
            screen.blit(text_surface, (10, y_offset))
            y_offset += 20

        # 확인 다이얼로그 그리기
        if confirmation_dialog:
            building_name = confirmation_dialog['building_name']
            ap_cost = confirmation_dialog['ap_cost']

            # 반투명 배경 오버레이
            overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
            overlay.fill((0, 0, 0, 150))
            screen.blit(overlay, (0, 0))

            # 다이얼로그 배경
            dialog_width = 400
            dialog_height = 180
            dialog_x = (SCREEN_WIDTH - dialog_width) // 2
            dialog_y = (SCREEN_HEIGHT - dialog_height) // 2

            dialog_rect = pygame.Rect(dialog_x, dialog_y, dialog_width, dialog_height)
            pygame.draw.rect(screen, (30, 30, 40), dialog_rect, border_radius=15)
            pygame.draw.rect(screen, Colors.UI_PRIMARY, dialog_rect, 3, border_radius=15)

            # 제목 텍스트 (freetype 사용 - 한글 지원)
            title_text = f"{building_name}에 입장하시겠습니까?"
            title_surface, title_rect = font.render(title_text, Colors.TEXT_WHITE)
            title_x = dialog_x + (dialog_width - title_rect.width) // 2
            title_y = dialog_y + 30
            screen.blit(title_surface, (title_x, title_y))

            # AP 소모 안내 (실제 광장의 열쇠 아이콘 사용)
            # 앤틱 열쇠 아이콘 크기 및 위치
            key_size = 20
            key_center_y = title_y + 45  # 제목 아래 중앙

            # AP 개수만큼 열쇠 표시 (가로로 배치)
            num_keys = ap_cost
            total_width = num_keys * 24  # 각 열쇠 간격 24px
            start_x = dialog_x + (dialog_width - total_width) // 2

            # ActionPointSystem의 _draw_antique_key 메서드 사용
            # 임시 AP 시스템 인스턴스 생성 (열쇠 그리기용)
            temp_ap_system = ActionPointSystem()

            for i in range(num_keys):
                key_x = start_x + i * 24 + 12  # 중심점
                temp_ap_system._draw_antique_key(screen, key_x, key_center_y, key_size, active=True)

            # 소모 안내 텍스트 (열쇠 아래)
            ap_text = f"{ap_cost} 소모"
            ap_surface, ap_rect = small_font.render(ap_text, Colors.UI_DANGER)
            ap_text_x = dialog_x + (dialog_width - ap_rect.width) // 2
            ap_text_y = key_center_y + 25  # 열쇠 아래
            screen.blit(ap_surface, (ap_text_x, ap_text_y))

            # 버튼 설정
            button_width = 140
            button_height = 50
            button_spacing = 20
            buttons_y = dialog_y + dialog_height - button_height - 25

            yes_button_x = dialog_x + (dialog_width // 2) - button_width - (button_spacing // 2)
            no_button_x = dialog_x + (dialog_width // 2) + (button_spacing // 2)

            # 예 버튼
            dialog_yes_rect = pygame.Rect(yes_button_x, buttons_y, button_width, button_height)
            pygame.draw.rect(screen, Colors.UI_SUCCESS, dialog_yes_rect, border_radius=10)
            pygame.draw.rect(screen, (100, 255, 100), dialog_yes_rect, 2, border_radius=10)

            yes_text = "예"
            yes_surface, yes_rect = font.render(yes_text, Colors.TEXT_WHITE)
            yes_text_x = yes_button_x + (button_width - yes_rect.width) // 2
            yes_text_y = buttons_y + (button_height - yes_rect.height) // 2
            screen.blit(yes_surface, (yes_text_x, yes_text_y))

            # 아니오 버튼
            dialog_no_rect = pygame.Rect(no_button_x, buttons_y, button_width, button_height)
            pygame.draw.rect(screen, Colors.UI_DANGER, dialog_no_rect, border_radius=10)
            pygame.draw.rect(screen, (255, 100, 100), dialog_no_rect, 2, border_radius=10)

            no_text = "아니오"
            no_surface, no_rect = font.render(no_text, Colors.TEXT_WHITE)
            no_text_x = no_button_x + (button_width - no_rect.width) // 2
            no_text_y = buttons_y + (button_height - no_rect.height) // 2
            screen.blit(no_surface, (no_text_x, no_text_y))

        pygame.display.flip()

    pygame.quit()
    print("\n✅ 마우스 클릭 테스트 종료")

if __name__ == "__main__":
    print("\n" + "="*80)
    print("🖱️  마우스 클릭 건물 상호작용 테스트")
    print("="*80)
    print("\n건물을 클릭하면 입장 확인 다이얼로그가 표시됩니다:")
    print("  - 건물 이름과 AP 소모량 표시")
    print("  - '예' 버튼 클릭: 건물 입장")
    print("  - '아니오' 버튼 클릭: 취소")
    print("\nWSAD 키나 화살표 키로 이동할 수 있습니다.")
    print("한글 키보드 (ㅁㅈㅇㄴ)도 사용 가능합니다.\n")
    print("="*80 + "\n")

    test_mouse_click()
