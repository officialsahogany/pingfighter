# downtown/manager.py
# 번화가 시스템 메인 매니저

import pygame
import os
import sys

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

        # 상태
        self.state = DowntownState.ENTERING
        self.stage_number = 1
        self.is_running = False

        # 현재 상호작용
        self.current_building = None
        self.interaction_result = None

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
        """폰트 초기화"""
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
            if event.key == pygame.K_ESCAPE:
                # ESC 메뉴
                self._show_pause_menu()

            elif event.key == pygame.K_z:
                # 상호작용
                self._handle_interaction()

            elif event.key == pygame.K_TAB:
                # 인벤토리
                self._show_inventory()

    def _handle_building_event(self, event):
        """건물 내부 이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self._exit_building()

    def _handle_interaction(self):
        """상호작용 처리"""
        if self.player.interaction_target:
            target = self.player.interaction_target

            if target['type'] == 'building':
                self._enter_building(target['building_type'])

            elif target['type'] == 'exit':
                self._try_exit()

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
        if building_type == BuildingType.SHOP:
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

        # 플레이어
        if self.state != DowntownState.IN_BUILDING:
            self.player.draw(self.screen, camera_offset)

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
        # AP 표시
        self.ap_system.draw(self.screen, 20, 20, self.font_medium)

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

    def _draw_stage_info(self):
        """스테이지 정보 표시"""
        # 행성 이름
        planet_name = self.downtown_map.theme_data.get('name', '???')
        stage_text = f"Stage {self.stage_number} - {planet_name}"

        text_surface = self.font_medium.render(stage_text, True, Colors.TEXT_WHITE)
        text_x = SCREEN_WIDTH // 2 - text_surface.get_width() // 2
        self.screen.blit(text_surface, (text_x, 10))

    def _draw_gold(self):
        """골드 표시"""
        gold = self.player_data.get('gold', 0)
        gold_text = f"💰 {gold:,}"

        text_surface = self.font_medium.render(gold_text, True, Colors.UI_ACCENT)
        self.screen.blit(text_surface, (20, 90))

    def _draw_building_interior(self):
        """건물 내부 화면"""
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

            # 제목
            title_text = self.font_large.render(info['name'], True, Colors.TEXT_WHITE)
            self.screen.blit(title_text,
                           (panel_x + panel_width // 2 - title_text.get_width() // 2,
                            panel_y + 20))

            # "개발 중" 메시지
            dev_text = self.font_medium.render("🚧 컨텐츠 개발 중...", True, Colors.TEXT_GRAY)
            self.screen.blit(dev_text,
                           (panel_x + panel_width // 2 - dev_text.get_width() // 2,
                            panel_y + panel_height // 2))

            # 나가기 힌트
            exit_text = self.font_small.render("[ESC] 나가기", True, Colors.TEXT_GRAY)
            self.screen.blit(exit_text,
                           (panel_x + panel_width // 2 - exit_text.get_width() // 2,
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
        """메시지 표시"""
        # 간단한 메시지 오버레이
        overlay = pygame.Surface((SCREEN_WIDTH, 80), pygame.SRCALPHA)
        overlay.fill((0, 0, 0, 200))

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
