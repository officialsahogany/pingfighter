# downtown/manager.py
# 번화가 시스템 메인 매니저

import pygame
import pygame.freetype
import os
import sys
import math

from .constants import (
    SCREEN_WIDTH, SCREEN_HEIGHT, TILE_SIZE,
    BuildingType, BUILDING_INFO, Colors, PLANET_THEMES, PlanetTheme,
    resource_path
)
from .map_generator import DowntownMap
from .player import DowntownPlayer
from .buildings import BuildingManager
from .action_points import ActionPointSystem, ActionPointEvent
from .renderer import DowntownRenderer
from .npc import NPCManager

class DowntownState:
    """번화가 상태"""
    ENTERING = "entering"       # 진입 애니메이션
    EXPLORING = "exploring"     # 탐험 중
    IN_BUILDING = "in_building" # 건물 내부
    EXITING = "exiting"        # 나가는 중
    COMPLETED = "completed"    # 완료 (다음 스테이지로)

class DowntownManager:
    """
    번화가 시스템 메인 매니저
    - 전체 번화가 시스템 관리
    - 게임 루프 처리
    - 이벤트 처리
    """

    def __init__(self, screen):
        self.screen = screen
        self.clock = pygame.time.Clock()

        # 폰트 초기화
        self._init_fonts()

        # 시스템 컴포넌트
        self.downtown_map = None
        self.player = None
        self.buildings = BuildingManager()
        self.ap_system = ActionPointSystem()
        self.renderer = DowntownRenderer()
        self.npc_manager = NPCManager()

        # 상태
        self.state = DowntownState.ENTERING
        self.stage_number = 1
        self.is_running = False

        # 현재 상호작용
        self.current_building = None
        self.interaction_result = None

        # 건물 입장 확인 다이얼로그
        self.building_confirmation_dialog = None  # {'building_type': ..., 'building_name': ...}
        self.dialog_yes_rect = None
        self.dialog_no_rect = None

        # 전환 효과
        self.transition_alpha = 255
        self.transition_speed = 300

        # 플레이어 데이터 (외부에서 전달)
        self.player_data = {
            'gold': 0,
            'items': [],
            'buffs': [],
            'character_type': 'smasher'  # 선택한 캐릭터 타입
        }

        # 결과 데이터
        self.result_data = {
            'visited_buildings': [],
            'gold_spent': 0,
            'gold_earned': 0,
            'items_obtained': [],
            'buffs_obtained': []
        }

    def _init_fonts(self):
        """폰트 초기화 (pygame.freetype 사용 - 한글 지원)"""
        self._freetype_fonts = {}

        # freetype 폰트 로드 시도
        font = None
        try:
            font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
            if os.path.exists(font_path):
                font = font_path
        except:
            pass

        # 시스템 폰트 fallback
        if font is None:
            if os.path.exists("/System/Library/Fonts/AppleSDGothicNeo.ttc"):
                font = "/System/Library/Fonts/AppleSDGothicNeo.ttc"
            elif os.path.exists("C:/Windows/Fonts/malgun.ttf"):
                font = "C:/Windows/Fonts/malgun.ttf"

        # freetype 폰트 생성
        try:
            self._freetype_fonts['large'] = pygame.freetype.Font(font, 32)
            self._freetype_fonts['medium'] = pygame.freetype.Font(font, 24)
            self._freetype_fonts['small'] = pygame.freetype.Font(font, 16)
        except:
            self._freetype_fonts['large'] = pygame.freetype.SysFont(None, 32)
            self._freetype_fonts['medium'] = pygame.freetype.SysFont(None, 24)
            self._freetype_fonts['small'] = pygame.freetype.SysFont(None, 16)

        # 기존 pygame.font도 유지 (호환성)
        try:
            font_path = resource_path(os.path.join("fonts", "NanumSquareB.ttf"))
            self.font_large = pygame.font.Font(font_path, 32)
            self.font_medium = pygame.font.Font(font_path, 24)
            self.font_small = pygame.font.Font(font_path, 16)
        except:
            self.font_large = pygame.font.Font(None, 32)
            self.font_medium = pygame.font.Font(None, 24)
            self.font_small = pygame.font.Font(None, 16)

    def initialize(self, stage_number, player_data=None):
        """번화가 초기화"""
        self.stage_number = stage_number
        self.state = DowntownState.ENTERING
        self.transition_alpha = 255

        # 플레이어 데이터 설정
        if player_data:
            self.player_data = player_data

        # 맵 생성
        self.downtown_map = DowntownMap(stage_number)

        # 플레이어 생성 (캐릭터 타입 전달)
        spawn_pos = self.downtown_map.get_spawn_pixel_pos()
        character_type = self.player_data.get('character_type', 'smasher')
        self.player = DowntownPlayer(spawn_pos[0], spawn_pos[1], character_type)

        # 건물 로드
        self.buildings.load_from_map(self.downtown_map)

        # AP 초기화
        self.ap_system.reset(stage_number)

        # 렌더러 테마 설정
        theme = self.downtown_map.theme
        self.renderer.set_theme(self.downtown_map.theme_data)

        # NPC 초기화
        self.npc_manager.initialize(self.downtown_map, stage_number)

        # 결과 초기화
        self.result_data = {
            'visited_buildings': [],
            'gold_spent': 0,
            'gold_earned': 0,
            'items_obtained': [],
            'buffs_obtained': []
        }

        self.is_running = True

    def run(self):
        """메인 게임 루프"""
        while self.is_running:
            dt = self.clock.tick(60) / 1000.0

            # 이벤트 처리
            for event in pygame.event.get():
                if event.type == pygame.QUIT:
                    self.is_running = False
                    return None
                self._handle_event(event)

            # 업데이트
            self._update(dt)

            # 렌더링
            self._draw()

            pygame.display.flip()

            # 완료 체크
            if self.state == DowntownState.COMPLETED:
                return self.result_data

        return None

    def _handle_event(self, event):
        """이벤트 처리"""
        if self.state == DowntownState.IN_BUILDING:
            self._handle_building_event(event)
            return

        if event.type == pygame.KEYDOWN:
            # 이동키 입력 처리 (한글/영문 레이아웃 모두 동일 동작)
            if self.player:
                self.player.handle_movement_key_event(
                    True,
                    scancode=getattr(event, "scancode", None),
                    keycode=event.key,
                    unicode_char=getattr(event, "unicode", None)
                )

            if event.key == pygame.K_ESCAPE:
                # ESC 메뉴
                self._show_pause_menu()

            elif event.key == pygame.K_SPACE:
                # 상호작용 (건물/출구) 또는 NPC 대화
                self._handle_interaction_or_talk()

            elif event.key == pygame.K_TAB:
                # 인벤토리
                self._show_inventory()

        elif event.type == pygame.KEYUP:
            if self.player:
                self.player.handle_movement_key_event(
                    False,
                    scancode=getattr(event, "scancode", None),
                    keycode=event.key,
                    unicode_char=getattr(event, "unicode", None)
                )

        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # 왼쪽 마우스 버튼
                # 다이얼로그가 열려있으면 버튼 클릭 처리
                if self.building_confirmation_dialog:
                    self._handle_dialog_click(event.pos)
                else:
                    # 건물 클릭 체크
                    self._handle_mouse_click(event.pos)

    def _handle_building_event(self, event):
        """건물 내부 이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self._exit_building()

    def _handle_npc_talk(self):
        """NPC 대화 처리"""
        if self.state != DowntownState.EXPLORING:
            return

        # NPC에게 말 걸기 시도
        dialogue = self.npc_manager.try_talk_to_npc(
            self.player.x, self.player.y, radius=70
        )

        if dialogue:
            # 대화 성공 - NPC가 알아서 말풍선을 표시함
            pass
        # 대화 실패 시 아무것도 하지 않음 (자연스럽게)

    def _handle_interaction_or_talk(self):
        """상호작용 또는 NPC 대화 처리 (Space/마우스 클릭용)"""
        if self.state != DowntownState.EXPLORING:
            return

        # 1. 먼저 건물/출구 상호작용 체크
        if self.player.interaction_target:
            target = self.player.interaction_target

            if target['type'] == 'building':
                # 건물 입장 확인 다이얼로그 표시
                self._show_building_confirmation_dialog(target['building_type'])
                return

            elif target['type'] == 'exit':
                self._try_exit()
                return

        # 2. 상호작용 대상이 없으면 NPC 대화 시도
        self._handle_npc_talk()

    def _handle_mouse_click(self, mouse_pos):
        """마우스 클릭으로 건물 상호작용"""
        if self.state != DowntownState.EXPLORING:
            return

        # 카메라 오프셋 가져오기
        camera_offset = self.renderer.get_camera_offset()

        # 플레이어에게 클릭한 건물 확인 요청
        clicked_building = self.player.check_building_click(
            mouse_pos, camera_offset, self.downtown_map
        )

        if clicked_building and clicked_building['type'] == 'building':
            building_type = clicked_building['building_type']

            # 확인 다이얼로그 표시
            self._show_building_confirmation_dialog(building_type)

    def _show_building_confirmation_dialog(self, building_type):
        """건물 입장 확인 다이얼로그 표시"""
        building_info = BUILDING_INFO[building_type]
        building_name = building_info['name']
        ap_cost = building_info['ap_cost']

        self.building_confirmation_dialog = {
            'building_type': building_type,
            'building_name': building_name,
            'ap_cost': ap_cost
        }

    def _handle_dialog_click(self, mouse_pos):
        """다이얼로그 버튼 클릭 처리"""
        if not self.building_confirmation_dialog:
            return

        # 예/아니오 버튼 영역 체크
        if self.dialog_yes_rect and self.dialog_yes_rect.collidepoint(mouse_pos):
            # 예 클릭 - 건물 입장
            building_type = self.building_confirmation_dialog['building_type']
            self.building_confirmation_dialog = None
            self._enter_building(building_type)
        elif self.dialog_no_rect and self.dialog_no_rect.collidepoint(mouse_pos):
            # 아니오 클릭 - 다이얼로그 닫기
            self.building_confirmation_dialog = None

    def _enter_building(self, building_type):
        """건물 입장"""
        info = BUILDING_INFO[building_type]
        ap_cost = info['ap_cost']

        # AP 체크
        if not self.ap_system.can_use(ap_cost):
            self._show_message("행동 포인트가 부족합니다!", Colors.UI_DANGER)
            return

        # AP 소모
        self.ap_system.use_ap(ap_cost)

        # 상태 변경
        self.state = DowntownState.IN_BUILDING
        self.current_building = building_type

        # 건물 방문 처리
        building = self.buildings.get_nearest_building(
            self.player.x, self.player.y, TILE_SIZE * 3
        )
        if building:
            self.buildings.mark_visited(building)
            self.result_data['visited_buildings'].append(building_type)

        # 건물별 이벤트 실행
        self._run_building_event(building_type)

    def _run_building_event(self, building_type):
        """건물 이벤트 실행 (각 건물별로 구현)"""
        # 임시 - 나중에 각 건물별 모듈로 분리
        if building_type == BuildingType.MAGIC_STORE:
            self._show_shop()
        elif building_type == BuildingType.BLACKSMITH:
            self._show_blacksmith()
        elif building_type == BuildingType.CASINO:
            self._show_casino()
        elif building_type == BuildingType.COLOSSEUM:
            self._show_colosseum()
        elif building_type == BuildingType.PET_SHOP:
            self._show_pet_shop()
        elif building_type == BuildingType.ELDER:
            self._show_elder()
        elif building_type == BuildingType.MINIGAME:
            self._show_minigame()
        elif building_type == BuildingType.TAVERN:
            self._show_tavern()
        elif building_type == BuildingType.BANK:
            self._show_bank()
        elif building_type == BuildingType.MYSTERY:
            self._show_mystery()
        else:
            self._show_placeholder(building_type)

    def _exit_building(self):
        """건물 나가기"""
        self.state = DowntownState.EXPLORING
        self.current_building = None
        self.player.end_interaction()

    def _try_exit(self):
        """번화가 나가기 시도"""
        # AP가 남아있으면 확인
        if self.ap_system.current_ap > 0:
            confirm = self._show_confirm(
                "아직 행동 포인트가 남아있습니다.\n정말 다음 스테이지로 이동하시겠습니까?"
            )
            if not confirm:
                return

        self.state = DowntownState.EXITING
        self.transition_alpha = 0

    def _update(self, dt):
        """업데이트"""
        # 상태별 업데이트
        if self.state == DowntownState.ENTERING:
            self._update_entering(dt)

        elif self.state == DowntownState.EXPLORING:
            self._update_exploring(dt)

        elif self.state == DowntownState.IN_BUILDING:
            self._update_in_building(dt)

        elif self.state == DowntownState.EXITING:
            self._update_exiting(dt)

    def _update_entering(self, dt):
        """진입 애니메이션"""
        self.transition_alpha -= self.transition_speed * dt
        if self.transition_alpha <= 0:
            self.transition_alpha = 0
            self.state = DowntownState.EXPLORING

    def _update_exploring(self, dt):
        """탐험 모드 업데이트"""
        # 입력 처리
        keys = pygame.key.get_pressed()
        self.player.handle_input(keys, dt)

        # 플레이어 업데이트
        self.player.update(dt, self.downtown_map)

        # 건물 업데이트
        self.buildings.update(dt)

        # NPC 업데이트
        self.npc_manager.update(dt, self.downtown_map)

        # NPC가 플레이어에 반응
        self.npc_manager.trigger_reactions(self.player.x, self.player.y, 60)

        # 하이라이트 업데이트
        if self.player.interaction_target:
            if self.player.interaction_target['type'] == 'building':
                building = self.buildings.get_nearest_building(
                    self.player.x, self.player.y, TILE_SIZE * 2
                )
                self.buildings.set_highlight(building)
            else:
                self.buildings.clear_highlight()
        else:
            self.buildings.clear_highlight()

        # AP 업데이트
        self.ap_system.update(dt)

        # 렌더러 업데이트
        self.renderer.update(dt, self.player.x, self.player.y)

        # AP 소진 체크
        if self.ap_system.is_exhausted():
            # 강제 출구로 이동
            self._force_exit()

    def _update_in_building(self, dt):
        """건물 내부 업데이트"""
        pass

    def _update_exiting(self, dt):
        """나가기 애니메이션"""
        self.transition_alpha += self.transition_speed * dt
        if self.transition_alpha >= 255:
            self.transition_alpha = 255
            self.state = DowntownState.COMPLETED

    def _force_exit(self):
        """강제 퇴장 (AP 소진)"""
        self._show_message("행동 포인트가 모두 소진되었습니다!", Colors.UI_ACCENT)
        pygame.time.delay(1500)
        self.state = DowntownState.EXITING
        self.transition_alpha = 0

    def _draw(self):
        """렌더링"""
        camera_offset = self.renderer.get_camera_offset()

        # 배경
        self.renderer.draw_background(self.screen)

        # 타일
        self.renderer.draw_tiles(self.screen, self.downtown_map)

        # 파티클 (배경)
        self.renderer.draw_particles(self.screen)

        # 건물
        self.buildings.draw(self.screen, camera_offset)

        # NPC (건물과 플레이어 사이에 Y 정렬되어 그려짐)
        self.npc_manager.draw(self.screen, camera_offset)

        # 플레이어
        if self.state != DowntownState.IN_BUILDING:
            self.player.draw(self.screen, camera_offset)

        # 스폰/출구 오오라 (모든 것 위에 - 잘 보이도록)
        self.renderer.draw_spawn_exit_auras(self.screen, self.downtown_map)

        # UI
        self._draw_ui()

        # 건물 내부 화면
        if self.state == DowntownState.IN_BUILDING:
            self._draw_building_interior()

        # 전환 효과
        if self.transition_alpha > 0:
            overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT))
            overlay.fill((0, 0, 0))
            overlay.set_alpha(int(self.transition_alpha))
            self.screen.blit(overlay, (0, 0))

    def _draw_ui(self):
        """UI 그리기"""
        # AP 표시 (모퉁이에서 살짝 안쪽으로)
        self.ap_system.draw(self.screen, 35, 30, self.font_medium)

        # 미니맵
        self.renderer.draw_minimap(
            self.screen, self.downtown_map, self.player, self.buildings
        )

        # 상호작용 힌트
        if self.player.interaction_target and self.state == DowntownState.EXPLORING:
            target = self.player.interaction_target

            if target['type'] == 'building':
                info = BUILDING_INFO[target['building_type']]
                self.renderer.draw_interaction_hint(self.screen, info, self.font_medium)
            elif target['type'] == 'exit':
                exit_info = {
                    'name': '다음 스테이지',
                    'description': '번화가를 떠나 다음 스테이지로 이동합니다',
                    'ap_cost': 0,
                    'color': Colors.NEON_ORANGE
                }
                self.renderer.draw_interaction_hint(self.screen, exit_info, self.font_medium)

        # 스테이지 정보
        self._draw_stage_info()

        # 골드 표시
        self._draw_gold()

        # 스타 포인트 표시 (우측 상단)
        self._draw_star_points()

        # 건물 입장 확인 다이얼로그
        if self.building_confirmation_dialog:
            self._draw_confirmation_dialog()

    def _draw_confirmation_dialog(self):
        """건물 입장 확인 다이얼로그 그리기"""
        dialog = self.building_confirmation_dialog
        building_name = dialog['building_name']
        ap_cost = dialog['ap_cost']

        # 다이얼로그 크기 및 위치 (10% 확대)
        dialog_width = 440  # 400 * 1.1
        dialog_height = 198  # 180 * 1.1
        dialog_x = (SCREEN_WIDTH - dialog_width) // 2
        dialog_y = (SCREEN_HEIGHT - dialog_height) // 2

        # 반투명 배경 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 150))
        self.screen.blit(overlay, (0, 0))

        # 다이얼로그 배경
        dialog_rect = pygame.Rect(dialog_x, dialog_y, dialog_width, dialog_height)
        pygame.draw.rect(self.screen, (30, 30, 40), dialog_rect, border_radius=15)
        pygame.draw.rect(self.screen, Colors.UI_PRIMARY, dialog_rect, 3, border_radius=15)

        # 제목 텍스트 (freetype 사용 - 한글 지원)
        title_text = f"{building_name}에 입장하시겠습니까?"
        title_surface, title_rect = self._freetype_fonts['medium'].render(title_text, Colors.TEXT_WHITE)
        title_x = dialog_x + (dialog_width - title_rect.width) // 2
        title_y = dialog_y + 30
        self.screen.blit(title_surface, (title_x, title_y))

        # AP 소모 안내 (열쇠 아이콘으로 표시 - 광장과 동일한 앤틱 디자인)
        key_size = 20  # 아이콘 크기
        key_x = dialog_x + (dialog_width - 100) // 2  # 아이콘 + 텍스트 중앙 정렬
        key_y = title_y + 48

        # 광장 좌측 상단과 동일한 앤틱 열쇠 그리기
        self.ap_system._draw_antique_key(self.screen, key_x, key_y, key_size, active=True)

        # 소모 개수 표시
        key_gold = (175, 140, 85)  # 앤틱 골드 색상 (광장 열쇠와 동일)
        ap_text = f"{ap_cost} 소모"
        ap_surface, ap_rect = self._freetype_fonts['small'].render(ap_text, key_gold)
        # 열쇠 크기 계산 (앤틱 열쇠는 세로로 긴 비율 - 1.0 x 2.2)
        key_display_width = int(key_size * 1.0)
        key_display_height = int(key_size * 2.2)
        ap_text_x = key_x + key_display_width + 15
        ap_text_y = key_y - ap_rect.height // 2
        self.screen.blit(ap_surface, (ap_text_x, ap_text_y))

        # 버튼 설정
        button_width = 140
        button_height = 50
        button_spacing = 20
        buttons_y = dialog_y + dialog_height - button_height - 25

        yes_button_x = dialog_x + (dialog_width // 2) - button_width - (button_spacing // 2)
        no_button_x = dialog_x + (dialog_width // 2) + (button_spacing // 2)

        # 예 버튼
        self.dialog_yes_rect = pygame.Rect(yes_button_x, buttons_y, button_width, button_height)
        pygame.draw.rect(self.screen, Colors.UI_SUCCESS, self.dialog_yes_rect, border_radius=10)
        pygame.draw.rect(self.screen, (100, 255, 100), self.dialog_yes_rect, 2, border_radius=10)

        yes_text = "예"
        yes_surface, yes_rect = self._freetype_fonts['medium'].render(yes_text, Colors.TEXT_WHITE)
        yes_text_x = yes_button_x + (button_width - yes_rect.width) // 2
        yes_text_y = buttons_y + (button_height - yes_rect.height) // 2
        self.screen.blit(yes_surface, (yes_text_x, yes_text_y))

        # 아니오 버튼
        self.dialog_no_rect = pygame.Rect(no_button_x, buttons_y, button_width, button_height)
        pygame.draw.rect(self.screen, Colors.UI_DANGER, self.dialog_no_rect, border_radius=10)
        pygame.draw.rect(self.screen, (255, 100, 100), self.dialog_no_rect, 2, border_radius=10)

        no_text = "아니오"
        no_surface, no_rect = self._freetype_fonts['medium'].render(no_text, Colors.TEXT_WHITE)
        no_text_x = no_button_x + (button_width - no_rect.width) // 2
        no_text_y = buttons_y + (button_height - no_rect.height) // 2
        self.screen.blit(no_surface, (no_text_x, no_text_y))

    def _draw_stage_info(self):
        """스테이지 정보 표시"""
        # 행성 이름
        planet_name = self.downtown_map.theme_data.get('name', '???')
        stage_text = f"Stage {self.stage_number} - {planet_name}"

        text_surface = self.font_medium.render(stage_text, True, Colors.TEXT_WHITE)
        text_x = SCREEN_WIDTH // 2 - text_surface.get_width() // 2
        self.screen.blit(text_surface, (text_x, 10))

    def _draw_gold(self):
        """골드 표시 - 금화 아이콘 직접 그리기"""
        gold = self.player_data.get('gold', 0)

        # 금화 아이콘 그리기 (20x20 크기)
        coin_x, coin_y = 35, 75
        coin_size = 18
        self._draw_gold_coin(self.screen, coin_x, coin_y, coin_size)

        # 골드 숫자
        gold_text = f"{gold:,}"
        text_surface = self.font_medium.render(gold_text, True, Colors.UI_ACCENT)
        self.screen.blit(text_surface, (coin_x + coin_size + 8, coin_y - 4))

    def _draw_star_points(self):
        """스타 포인트 표시 - 우측 상단"""
        star_points = self.player_data.get('star_points', 0)

        # 우측 상단 위치 (더 우측으로 이동)
        star_x = SCREEN_WIDTH - 100
        star_y = 30

        # 별 아이콘 그리기
        star_size = 16
        self._draw_star_icon(self.screen, star_x, star_y, star_size)

        # 스타 포인트 숫자
        star_text = f"{star_points}"
        text_surface = self.font_medium.render(star_text, True, (255, 220, 100))
        self.screen.blit(text_surface, (star_x + star_size + 10, star_y - 6))

    def _draw_star_icon(self, screen, cx, cy, size):
        """5각 별 아이콘 그리기 - 아카데미 스타일"""
        import math

        # 메인 별 포인트 계산
        star_points = []
        for i in range(10):
            angle = -math.pi / 2 + (i * math.pi / 5)  # 위쪽부터 시작
            radius = size if i % 2 == 0 else size * 0.5
            px = cx + radius * math.cos(angle)
            py = cy + radius * math.sin(angle)
            star_points.append((px, py))

        # 메인 별 그리기 (노란색)
        pygame.draw.polygon(screen, (255, 255, 100), star_points)

        # 외곽선 그리기 (금색)
        pygame.draw.polygon(screen, (255, 215, 0), star_points, 2)

        # 광택 효과 (작은 별)
        gloss_points = []
        for i in range(10):
            angle = -math.pi / 2 + (i * math.pi / 5)
            radius = size * 0.3 if i % 2 == 0 else size * 0.15
            px = cx + radius * math.cos(angle)
            py = cy - 2 + radius * math.sin(angle)  # 약간 위로
            gloss_points.append((px, py))

        # 광택 별 그리기 (밝은 노란색, 반투명)
        gloss_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
        gloss_offset_x = size * 2 - cx
        gloss_offset_y = size * 2 - cy
        adjusted_gloss_points = [(px + gloss_offset_x, py + gloss_offset_y) for px, py in gloss_points]
        pygame.draw.polygon(gloss_surf, (255, 255, 200, 180), adjusted_gloss_points)
        screen.blit(gloss_surf, (cx - size * 2, cy - size * 2))

    def _draw_gold_coin(self, screen, x, y, size):
        """금화 아이콘 그리기 - 입체감 있는 동전"""
        # 금화 서피스 생성
        coin_surf = pygame.Surface((size + 4, size + 4), pygame.SRCALPHA)

        cx, cy = size // 2 + 2, size // 2 + 2
        radius = size // 2

        # 색상 정의
        gold_dark = (180, 130, 20)      # 어두운 금색 (테두리/그림자)
        gold_main = (255, 200, 50)       # 메인 금색
        gold_light = (255, 235, 120)     # 밝은 금색 (하이라이트)
        gold_shine = (255, 250, 200)     # 반짝임

        # 그림자 (약간 아래 오른쪽)
        pygame.draw.circle(coin_surf, (0, 0, 0, 80), (cx + 2, cy + 2), radius)

        # 외곽 테두리 (어두운 금색)
        pygame.draw.circle(coin_surf, gold_dark, (cx, cy), radius)

        # 메인 금화
        pygame.draw.circle(coin_surf, gold_main, (cx, cy), radius - 2)

        # 내부 테두리 (입체감)
        pygame.draw.circle(coin_surf, gold_dark, (cx, cy), radius - 3, 1)

        # 상단 하이라이트 (반원)
        highlight_rect = (cx - radius + 4, cy - radius + 3, (radius - 4) * 2, radius - 2)
        pygame.draw.arc(coin_surf, gold_light, highlight_rect, 0.5, 2.6, 2)

        # 중앙에 별 무늬
        star_size = radius // 2
        star_points = []
        for i in range(5):
            # 바깥 점
            angle = math.pi / 2 + i * 2 * math.pi / 5
            px = cx + int(star_size * math.cos(angle))
            py = cy - int(star_size * math.sin(angle))
            star_points.append((px, py))
            # 안쪽 점
            angle += math.pi / 5
            px = cx + int(star_size * 0.4 * math.cos(angle))
            py = cy - int(star_size * 0.4 * math.sin(angle))
            star_points.append((px, py))

        if len(star_points) >= 3:
            pygame.draw.polygon(coin_surf, gold_dark, star_points)
            # 별 하이라이트
            inner_star = [(int(cx + (p[0] - cx) * 0.7), int(cy + (p[1] - cy) * 0.7)) for p in star_points]
            if len(inner_star) >= 3:
                pygame.draw.polygon(coin_surf, gold_light, inner_star)

        # 반짝임 효과 (우상단)
        pygame.draw.circle(coin_surf, gold_shine, (cx + radius // 3, cy - radius // 3), 2)

        screen.blit(coin_surf, (x - size // 2, y - size // 2))

    def _draw_building_interior(self):
        """건물 내부 화면 (한글 폰트 지원)"""
        # 어두운 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, SCREEN_HEIGHT), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 200))
        self.screen.blit(overlay, (0, 0))

        # 건물 정보 패널
        if self.current_building:
            info = BUILDING_INFO[self.current_building]

            # 패널
            panel_width = 600
            panel_height = 400
            panel_x = SCREEN_WIDTH // 2 - panel_width // 2
            panel_y = SCREEN_HEIGHT // 2 - panel_height // 2

            pygame.draw.rect(self.screen, (30, 30, 50),
                           (panel_x, panel_y, panel_width, panel_height),
                           border_radius=20)
            pygame.draw.rect(self.screen, info['color'],
                           (panel_x, panel_y, panel_width, panel_height),
                           3, border_radius=20)

            # freetype 폰트 사용
            font_large = self._freetype_fonts.get('large')
            font_medium = self._freetype_fonts.get('medium')
            font_small = self._freetype_fonts.get('small')

            # 제목
            if font_large:
                title_surf, title_rect = font_large.render(info['name'], Colors.TEXT_WHITE)
                self.screen.blit(title_surf,
                               (panel_x + panel_width // 2 - title_rect.width // 2,
                                panel_y + 20))

            # "개발 중" 메시지
            if font_medium:
                dev_surf, dev_rect = font_medium.render("🚧 컨텐츠 개발 중...", Colors.TEXT_GRAY)
                self.screen.blit(dev_surf,
                               (panel_x + panel_width // 2 - dev_rect.width // 2,
                                panel_y + panel_height // 2))

            # 나가기 힌트
            if font_small:
                exit_surf, exit_rect = font_small.render("[ESC] 나가기", Colors.TEXT_GRAY)
                self.screen.blit(exit_surf,
                               (panel_x + panel_width // 2 - exit_rect.width // 2,
                                panel_y + panel_height - 40))

    # ==========================================================================
    # 건물별 플레이스홀더 (나중에 구현)
    # ==========================================================================

    def _show_shop(self):
        """아이템 상점"""
        pass

    def _show_blacksmith(self):
        """대장장이"""
        pass

    def _show_casino(self):
        """도박장"""
        pass

    def _show_colosseum(self):
        """콜로세움"""
        pass

    def _show_pet_shop(self):
        """펫 상점"""
        pass

    def _show_elder(self):
        """현자"""
        pass

    def _show_minigame(self):
        """미니게임"""
        pass

    def _show_tavern(self):
        """주점"""
        pass

    def _show_bank(self):
        """은행"""
        pass

    def _show_mystery(self):
        """미스터리"""
        pass

    def _show_placeholder(self, building_type):
        """플레이스홀더"""
        pass

    def _show_message(self, message, color=Colors.TEXT_WHITE):
        """메시지 표시 (한글 지원)"""
        # 간단한 메시지 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, 80), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 200))

        font_medium = self._freetype_fonts.get('medium')
        if font_medium:
            text_surf, text_rect = font_medium.render(message, color)
            text_x = SCREEN_WIDTH // 2 - text_rect.width // 2
            overlay.blit(text_surf, (text_x, 25))
        else:
            text = self.font_medium.render(message, True, color)
            text_x = SCREEN_WIDTH // 2 - text.get_width() // 2
            overlay.blit(text, (text_x, 25))

        self.screen.blit(overlay, (0, SCREEN_HEIGHT // 2 - 40))
        pygame.display.flip()

    def _show_confirm(self, message):
        """확인 다이얼로그"""
        # 임시 구현 - 항상 True 반환
        return True

    def _show_pause_menu(self):
        """일시정지 메뉴"""
        pass

    def _show_inventory(self):
        """인벤토리"""
        pass


# =============================================================================
# 테스트용 실행
# =============================================================================
def test_downtown():
    """번화가 시스템 테스트"""
    pygame.init()
    screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
    pygame.display.set_caption("Downtown Test")

    manager = DowntownManager(screen)
    manager.initialize(stage_number=1, player_data={'gold': 1000})

    result = manager.run()
    print("Result:", result)

    pygame.quit()

if __name__ == "__main__":
    test_downtown()
