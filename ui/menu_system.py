"""
MenuSystem - 메뉴 시스템
게임의 모든 메뉴 UI 관리
"""

import pygame
import math
from typing import List, Dict, Any, Optional, Callable
from core.game_state import GameState
from core.events import EventType, emit_event
from enum import Enum


class MenuState(Enum):
    """메뉴 상태"""
    MAIN = "main"
    SETTINGS = "settings"
    PAUSE = "pause"
    HELP = "help"
    CONTROLS = "controls"
    GAME_OVER = "game_over"
    STAGE_CLEAR = "stage_clear"
    ACADEMY = "academy"
    GACHA = "gacha"
    CREDITS = "credits"
    STAGE_SELECT = "stage_select"


class MenuItem:
    """메뉴 아이템 클래스"""
    
    def __init__(self, text: str, action: Optional[Callable] = None, 
                 submenu: Optional[List] = None, value: Any = None,
                 color: tuple = (255, 255, 255),
                 hover_color: tuple = (255, 215, 0)):
        self.text = text
        self.action = action
        self.submenu = submenu
        self.value = value
        self.selected = False
        self.hover = False
        self.rect = None
        self.color = color
        self.hover_color = hover_color
        
        # 애니메이션 속성
        self.hover_scale = 1.0
        self.hover_offset = 0
        self.glow_alpha = 0
        
    def update(self, dt: float):
        """애니메이션 업데이트"""
        if self.selected:
            # 호버 시 확대
            self.hover_scale = min(1.15, self.hover_scale + dt * 60 * 0.033)
            # 좌우 움직임
            self.hover_offset = math.sin(pygame.time.get_ticks() * 0.003) * 5
            # 글로우 효과
            self.glow_alpha = abs(math.sin(pygame.time.get_ticks() * 0.002)) * 100 + 155
        else:
            # 원래 크기로 복귀
            self.hover_scale = max(1.0, self.hover_scale - dt * 60 * 0.05)
            self.hover_offset = self.hover_offset * 0.9
            self.glow_alpha = max(0, self.glow_alpha - dt * 60 * 5)
        

class MenuSystem:
    """메뉴 시스템 관리자"""
    
    def __init__(self, screen: pygame.Surface, width: int = 600, height: int = 750):
        self.screen = screen
        self.width = width
        self.height = height
        self.game_state = GameState.get_instance()
        
        # 폰트 설정
        self.init_fonts()
        
        # 메뉴 상태
        self.current_state = MenuState.MAIN
        self.previous_state = None
        self.menus = {}
        self.current_menu = None
        self.menu_stack = []
        self.selected_index = 0
        self.animation_timer = 0
        
        # 배경 파티클 시스템
        self.particles = []
        self._init_particles()
        
        # 메뉴 생성
        self._create_all_menus()
        
        # 색상 테마
        self.colors = {
            'background': (15, 15, 25),
            'primary': (0, 255, 200),
            'secondary': (255, 80, 120),
            'accent': (255, 200, 50),
            'text': (255, 255, 255),
            'text_dim': (180, 180, 180),
            'border': (100, 150, 255),
            'glow': (0, 255, 255)
        }
        
    def init_fonts(self):
        """폰트 초기화"""
        # pygame.font 초기화 확인
        if not pygame.font.get_init():
            pygame.font.init()
            
        try:
            self.font_title = pygame.font.Font("NanumSquareEB.ttf", 48)
            self.font_menu = pygame.font.Font("NanumSquareB.ttf", 32)
            self.font_small = pygame.font.Font("NanumSquareR.ttf", 24)
        except:
            self.font_title = pygame.font.Font(None, 48)
            self.font_menu = pygame.font.Font(None, 32)
            self.font_small = pygame.font.Font(None, 24)
            
    def _init_particles(self):
        """배경 파티클 초기화"""
        import random
        for _ in range(50):
            self.particles.append({
                'x': random.randint(0, self.width),
                'y': random.randint(0, self.height),
                'vx': random.uniform(-0.5, 0.5),
                'vy': random.uniform(-1, -0.5),
                'size': random.randint(1, 3),
                'alpha': random.randint(50, 150)
            })
            
    def _create_all_menus(self):
        """모든 메뉴 생성"""
        self.menus[MenuState.MAIN] = self.create_main_menu()
        self.menus[MenuState.PAUSE] = self.create_pause_menu()
        self.menus[MenuState.SETTINGS] = self.create_options_menu()
        self.menus[MenuState.HELP] = self.create_help_menu()
        self.menus[MenuState.CONTROLS] = self.create_controls_menu()
        self.menus[MenuState.GAME_OVER] = self.create_game_over_menu()
        self.menus[MenuState.STAGE_CLEAR] = self.create_stage_clear_menu()
        self.menus[MenuState.CREDITS] = self.create_credits_menu()
        self.menus[MenuState.STAGE_SELECT] = self.create_stage_menu()
        
        # 시작시 메인 메뉴 설정
        self.current_menu = self.menus[MenuState.MAIN]
    
    def create_main_menu(self) -> List[MenuItem]:
        """메인 메뉴 생성"""
        return [
            MenuItem("게임 시작", action=lambda: self.start_game()),
            MenuItem("아카데미", action=lambda: self.open_academy()),
            MenuItem("가챠", action=lambda: self.open_gacha()),
            MenuItem("스테이지 선택", action=lambda: self.change_state(MenuState.STAGE_SELECT)),
            MenuItem("설정", action=lambda: self.change_state(MenuState.SETTINGS)),
            MenuItem("도움말", action=lambda: self.change_state(MenuState.HELP)),
            MenuItem("크레딧", action=lambda: self.change_state(MenuState.CREDITS)),
            MenuItem("종료", action=lambda: self.quit_game())
        ]
        
    def create_stage_menu(self) -> List[MenuItem]:
        """스테이지 선택 메뉴 생성"""
        stages = []
        max_stage = self.game_state.current_stage
        
        for i in range(1, min(max_stage + 1, 22)):
            stage_name = self.get_stage_name(i)
            stages.append(
                MenuItem(f"Stage {i}: {stage_name}", 
                        action=lambda stage=i: self.select_stage(stage),
                        value=i)
            )
        stages.append(MenuItem("뒤로", action=lambda: self.go_back()))
        return stages
        
    def create_options_menu(self) -> List[MenuItem]:
        """옵션 메뉴 생성"""
        return [
            MenuItem(f"사운드: {'ON' if self.game_state.sound_enabled else 'OFF'}", 
                    action=lambda: self.toggle_sound()),
            MenuItem(f"음악: {'ON' if self.game_state.music_enabled else 'OFF'}", 
                    action=lambda: self.toggle_music()),
            MenuItem(f"난이도: {self.game_state.ai_mode}", 
                    submenu=self.create_difficulty_menu()),
            MenuItem("컨트롤 설정", action=lambda: self.open_controls()),
            MenuItem("뒤로", action=lambda: self.go_back())
        ]
        
    def create_pause_menu(self) -> List[MenuItem]:
        """일시정지 메뉴 생성"""
        return [
            MenuItem("계속하기", action=lambda: self.resume_game()),
            MenuItem("재시작", action=lambda: self.restart_stage()),
            MenuItem("설정", action=lambda: self.change_state(MenuState.SETTINGS)),
            MenuItem("조작법", action=lambda: self.change_state(MenuState.CONTROLS)),
            MenuItem("메인 메뉴로", action=lambda: self.to_main_menu())
        ]
        
    def create_help_menu(self) -> List[MenuItem]:
        """도움말 메뉴 생성"""
        return [
            MenuItem("게임 방법", action=lambda: self.show_how_to_play()),
            MenuItem("조작법", action=lambda: self.change_state(MenuState.CONTROLS)),
            MenuItem("아이템 설명", action=lambda: self.show_items()),
            MenuItem("스킬 설명", action=lambda: self.show_skills()),
            MenuItem("보스 정보", action=lambda: self.show_bosses()),
            MenuItem("뒤로", action=lambda: self.go_back())
        ]
        
    def create_controls_menu(self) -> List[MenuItem]:
        """조작법 메뉴 생성"""
        return [
            MenuItem("← → : 이동", color=(200, 200, 200)),
            MenuItem("SPACE : 대시", color=(200, 200, 200)),
            MenuItem("1-6 : 아이템 사용", color=(200, 200, 200)),
            MenuItem("TAB : 아이템 슬롯 변경", color=(200, 200, 200)),
            MenuItem("ESC : 일시정지", color=(200, 200, 200)),
            MenuItem("뒤로", action=lambda: self.go_back())
        ]
        
    def create_game_over_menu(self) -> List[MenuItem]:
        """게임 오버 메뉴 생성"""
        return [
            MenuItem("재시도", action=lambda: self.retry()),
            MenuItem("메인 메뉴로", action=lambda: self.to_main_menu()),
            MenuItem("종료", action=lambda: self.quit_game())
        ]
        
    def create_stage_clear_menu(self) -> List[MenuItem]:
        """스테이지 클리어 메뉴 생성"""
        return [
            MenuItem("다음 스테이지", action=lambda: self.next_stage()),
            MenuItem("아카데미", action=lambda: self.open_academy()),
            MenuItem("가챠", action=lambda: self.open_gacha()),
            MenuItem("메인 메뉴로", action=lambda: self.to_main_menu())
        ]
        
    def create_credits_menu(self) -> List[MenuItem]:
        """크레딧 메뉴 생성"""
        return [
            MenuItem("개발: BossPong Team", color=(200, 200, 200)),
            MenuItem("음악: Free Assets", color=(200, 200, 200)),
            MenuItem("그래픽: Community", color=(200, 200, 200)),
            MenuItem("Special Thanks", color=(200, 200, 200)),
            MenuItem("뒤로", action=lambda: self.go_back())
        ]
        
    def create_difficulty_menu(self) -> List[MenuItem]:
        """난이도 선택 메뉴 생성"""
        return [
            MenuItem("쉬움", action=lambda: self.set_difficulty("easy")),
            MenuItem("보통", action=lambda: self.set_difficulty("normal")),
            MenuItem("어려움", action=lambda: self.set_difficulty("hard")),
            MenuItem("지옥", action=lambda: self.set_difficulty("mythic")),
            MenuItem("뒤로", action=lambda: self.go_back())
        ]
        
    def update(self, dt: float):
        """시스템 업데이트"""
        # 현재 메뉴 아이템 업데이트
        if self.current_menu:
            for item in self.current_menu:
                item.update(dt)
                
        # 배경 애니메이션
        self.animation_timer += dt * 60
        
        # 파티클 업데이트
        for particle in self.particles:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            
            # 화면 밖으로 나가면 위치 리셋
            if particle['y'] < 0:
                particle['y'] = self.height
                particle['x'] = (pygame.time.get_ticks() % self.width)
                
    def render(self, screen: pygame.Surface = None):
        """메뉴 렌더링"""
        if screen:
            self.screen = screen
            
        if self.current_menu:
            self.draw_menu(self.current_menu)
            
    def draw_menu(self, menu_items: List[MenuItem]):
        """메뉴 그리기"""
        # 배경
        self.draw_background()
        
        # 제목 (상태별로 다른 제목)
        title_text = self._get_menu_title()
        title_surface = self.font_title.render(title_text, True, self.colors['primary'])
        title_rect = title_surface.get_rect(center=(self.width // 2, 100))
        
        # 제목 글로우 효과
        glow_alpha = abs(math.sin(self.animation_timer * 0.05)) * 50 + 50
        glow_surface = self.font_title.render(title_text, True, self.colors['glow'])
        glow_surface.set_alpha(int(glow_alpha))
        for offset in [(-2, -2), (2, -2), (-2, 2), (2, 2)]:
            self.screen.blit(glow_surface, (title_rect.x + offset[0], title_rect.y + offset[1]))
            
        self.screen.blit(title_surface, title_rect)
        
        # 메뉴 아이템들
        start_y = 250
        item_height = 60
        
        for i, item in enumerate(menu_items):
            y = start_y + i * item_height
            
            # 선택된 아이템 강조
            if i == self.selected_index:
                item.selected = True
                self.draw_selection_highlight(y, item_height)
                color = item.hover_color if hasattr(item, 'hover_color') else self.colors['accent']
                scale = item.hover_scale if hasattr(item, 'hover_scale') else 1.1
            elif item.hover:
                color = self.colors['primary']
                scale = 1.05
            else:
                item.selected = False
                color = item.color if hasattr(item, 'color') else self.colors['text_dim']
                scale = 1.0
                
            # 글로우 효과 (선택된 아이템)
            if i == self.selected_index and hasattr(item, 'glow_alpha') and item.glow_alpha > 0:
                glow_surface = self.font_menu.render(item.text, True, color)
                glow_surface.set_alpha(int(item.glow_alpha))
                for offset in [(-2, -2), (2, -2), (-2, 2), (2, 2)]:
                    self.screen.blit(glow_surface, 
                                   (self.width // 2 - glow_surface.get_width() // 2 + offset[0], 
                                    y - glow_surface.get_height() // 2 + offset[1]))
                
            # 텍스트 렌더링
            text_surface = self.font_menu.render(item.text, True, color)
            
            # 스케일 적용
            if scale != 1.0:
                w, h = text_surface.get_size()
                text_surface = pygame.transform.scale(text_surface, 
                                                     (int(w * scale), int(h * scale)))
                
            # 호버 오프셋 적용
            x_offset = item.hover_offset if hasattr(item, 'hover_offset') else 0
            text_rect = text_surface.get_rect(center=(self.width // 2 + x_offset, y))
            item.rect = text_rect
            self.screen.blit(text_surface, text_rect)
            
        # 파티클 렌더링
        self._render_particles()
        
        # 상태별 추가 UI
        self._render_state_ui()
            
    def draw_background(self):
        """배경 그리기"""
        # 그라데이션 배경
        for y in range(0, self.height, 10):
            ratio = y / self.height
            r = int(15 + ratio * 10)
            g = int(15 + ratio * 10)
            b = int(25 + ratio * 15)
            pygame.draw.rect(self.screen, (r, g, b), (0, y, self.width, 10))
            
        # 움직이는 패턴
        pattern_color = (30, 40, 60)
        offset = self.animation_timer * 0.5
        for x in range(-100, self.width + 100, 100):
            for y in range(-100, self.height + 100, 100):
                offset_x = x + offset
                offset_y = y + offset * 0.5
                pygame.draw.circle(self.screen, pattern_color, 
                                 (int(offset_x % self.width), int(offset_y % self.height)), 
                                 50, 1)
                           
    def draw_selection_highlight(self, y: int, height: int):
        """선택 강조 효과"""
        # 발광 효과
        glow_surface = pygame.Surface((self.width - 100, height), pygame.SRCALPHA)
        
        # 그라데이션 글로우
        for i in range(height // 2):
            alpha = int(100 * (1 - i / (height // 2)))
            color = (*self.colors['accent'], alpha)
            pygame.draw.rect(glow_surface, color,
                           (0, i, self.width - 100, 1))
            pygame.draw.rect(glow_surface, color,
                           (0, height - i - 1, self.width - 100, 1))
                           
        self.screen.blit(glow_surface, (50, y - height // 2))
        
        # 좌우 화살표
        arrow_offset = int(10 * math.sin(self.animation_timer * 3))
        left_arrow = [(30 + arrow_offset, y), (50 + arrow_offset, y - 10), (50 + arrow_offset, y + 10)]
        right_arrow = [(self.width - 30 - arrow_offset, y), 
                      (self.width - 50 - arrow_offset, y - 10),
                      (self.width - 50 - arrow_offset, y + 10)]
        pygame.draw.polygon(self.screen, self.colors['accent'], left_arrow)
        pygame.draw.polygon(self.screen, self.colors['accent'], right_arrow)
        
    def _render_particles(self):
        """파티클 렌더링"""
        for particle in self.particles:
            s = pygame.Surface((particle['size'] * 2, particle['size'] * 2), pygame.SRCALPHA)
            pygame.draw.circle(s, (255, 255, 255, particle['alpha']), 
                             (particle['size'], particle['size']), particle['size'])
            self.screen.blit(s, (int(particle['x']), int(particle['y'])))
            
    def _render_state_ui(self):
        """상태별 추가 UI 렌더링"""
        # 하단 정보
        if self.current_state == MenuState.MAIN:
            version_text = self.font_small.render("v1.0.0 - Modular Architecture", True, (100, 100, 100))
            self.screen.blit(version_text, (10, self.height - 30))
            
        # ESC 안내
        if self.current_state != MenuState.MAIN:
            esc_text = self.font_small.render("ESC: 뒤로가기", True, (150, 150, 150))
            self.screen.blit(esc_text, (self.width - 120, self.height - 30))
            
    def _get_menu_title(self) -> str:
        """현재 메뉴 상태에 따른 제목 반환"""
        titles = {
            MenuState.MAIN: "BossPong",
            MenuState.SETTINGS: "설정",
            MenuState.PAUSE: "일시정지",
            MenuState.HELP: "도움말",
            MenuState.CONTROLS: "조작법",
            MenuState.GAME_OVER: "GAME OVER",
            MenuState.STAGE_CLEAR: "Stage Clear!",
            MenuState.ACADEMY: "아카데미",
            MenuState.GACHA: "가챠",
            MenuState.CREDITS: "크레딧",
            MenuState.STAGE_SELECT: "스테이지 선택"
        }
        return titles.get(self.current_state, "BossPong")
        
    def handle_event(self, event: pygame.event.Event) -> bool:
        """이벤트 처리 (개선된 버전)"""
        return self.handle_input(event)
        
    def handle_input(self, event: pygame.event.Event) -> bool:
        """입력 처리
        
        Returns:
            이벤트가 처리되었는지 여부
        """
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_UP:
                self.move_selection(-1)
                return True
            elif event.key == pygame.K_DOWN:
                self.move_selection(1)
                return True
            elif event.key in [pygame.K_RETURN, pygame.K_SPACE]:
                self.select_current()
                return True
            elif event.key == pygame.K_ESCAPE:
                self.go_back()
                return True
                
        elif event.type == pygame.MOUSEMOTION:
            self.handle_mouse_hover(event.pos)
            return True
            
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # 왼쪽 클릭
                self.handle_mouse_click(event.pos)
                return True
                
        return False
        
    def move_selection(self, direction: int):
        """선택 이동"""
        if self.current_menu:
            self.selected_index = (self.selected_index + direction) % len(self.current_menu)
            emit_event(EventType.MENU_OPENED, {'selection_changed': True})
            
    def select_current(self):
        """현재 선택된 아이템 실행"""
        if self.current_menu and 0 <= self.selected_index < len(self.current_menu):
            item = self.current_menu[self.selected_index]
            
            if item.action:
                item.action()
            elif item.submenu:
                self.push_menu(item.submenu)
                
            emit_event(EventType.BUTTON_CLICKED, {'menu_item': item.text})
            
    def change_state(self, new_state: MenuState):
        """메뉴 상태 변경"""
        self.previous_state = self.current_state
        self.current_state = new_state
        self.current_menu = self.menus.get(new_state, self.menus[MenuState.MAIN])
        self.selected_index = 0
        emit_event(EventType.MENU_OPENED, {'state': new_state.value})
        
    def push_menu(self, menu: List[MenuItem]):
        """새 메뉴를 스택에 추가"""
        if self.current_menu:
            self.menu_stack.append((self.current_menu, self.selected_index))
        self.current_menu = menu
        self.selected_index = 0
        
    def go_back(self):
        """이전 메뉴로 돌아가기"""
        if self.previous_state:
            self.current_state = self.previous_state
            self.current_menu = self.menus.get(self.current_state, self.menus[MenuState.MAIN])
            self.previous_state = None
        elif self.menu_stack:
            self.current_menu, self.selected_index = self.menu_stack.pop()
        else:
            self.current_state = MenuState.MAIN
            self.current_menu = self.menus[MenuState.MAIN]
        emit_event(EventType.MENU_CLOSED, {'menu_depth': len(self.menu_stack)})
            
    def handle_mouse_hover(self, pos: tuple):
        """마우스 호버 처리"""
        if self.current_menu:
            for i, item in enumerate(self.current_menu):
                if item.rect and item.rect.collidepoint(pos):
                    item.hover = True
                    self.selected_index = i
                else:
                    item.hover = False
                    
    def handle_mouse_click(self, pos: tuple):
        """마우스 클릭 처리"""
        if self.current_menu:
            for item in self.current_menu:
                if item.rect and item.rect.collidepoint(pos):
                    self.select_current()
                    break
                    
    def get_stage_name(self, stage: int) -> str:
        """스테이지 이름 반환"""
        stage_names = {
            1: "기본 보스",
            2: "악어 보스",
            3: "멘헤라걸",
            4: "자석 마녀",
            5: "슬롯머신",
            6: "체력형 보스"
        }
        
        if stage in stage_names:
            return stage_names[stage]
        elif stage > 6:
            return f"레벨 {stage}"
        return "알 수 없음"
        
    # 액션 메서드들
    def start_game(self):
        """게임 시작"""
        emit_event(EventType.GAME_START, {'from_menu': True})
        
    def select_stage(self, stage: int):
        """스테이지 선택"""
        self.game_state.current_stage = stage
        emit_event(EventType.GAME_START, {'stage': stage})
        
    def open_academy(self):
        """아카데미 열기"""
        emit_event(EventType.MENU_OPENED, {'type': 'academy'})
        
    def open_gacha(self):
        """가챠 열기"""
        emit_event(EventType.MENU_OPENED, {'type': 'gacha'})
        
    def resume_game(self):
        """게임 재개"""
        emit_event(EventType.GAME_RESUME, {})
        
    def restart_stage(self):
        """스테이지 재시작"""
        current_stage = self.game_state.get('current_stage', 1)
        emit_event(EventType.GAME_START, {'stage': current_stage})
        
    def to_main_menu(self):
        """메인 메뉴로"""
        self.current_state = MenuState.MAIN
        self.current_menu = self.menus[MenuState.MAIN]
        emit_event(EventType.MENU_OPENED, {'state': MenuState.MAIN.value})
        
    def retry(self):
        """재시도"""
        current_stage = self.game_state.get('current_stage', 1)
        emit_event(EventType.GAME_START, {'stage': current_stage})
        
    def next_stage(self):
        """다음 스테이지"""
        current_stage = self.game_state.get('current_stage', 1)
        emit_event(EventType.GAME_START, {'stage': current_stage + 1})
        
    def show_how_to_play(self):
        """게임 방법 표시"""
        # TODO: 게임 방법 화면 구현
        pass
        
    def show_items(self):
        """아이템 설명 표시"""
        # TODO: 아이템 설명 화면 구현
        pass
        
    def show_skills(self):
        """스킬 설명 표시"""
        # TODO: 스킬 설명 화면 구현
        pass
        
    def show_bosses(self):
        """보스 정보 표시"""
        # TODO: 보스 정보 화면 구현
        pass
        
    def open_shop(self):
        """상점 열기"""
        emit_event(EventType.MENU_OPENED, {'menu_type': 'shop'})
        
    def quit_game(self):
        """게임 종료"""
        emit_event(EventType.GAME_OVER, {'from_menu': True})
        
    def toggle_sound(self):
        """사운드 토글"""
        self.game_state.sound_enabled = not self.game_state.sound_enabled
        
    def toggle_music(self):
        """음악 토글"""
        self.game_state.music_enabled = not self.game_state.music_enabled
        
    def set_difficulty(self, difficulty: str):
        """난이도 설정"""
        self.game_state.ai_mode = difficulty
        self.go_back()
        
    def open_controls(self):
        """컨트롤 설정 열기"""
        emit_event(EventType.MENU_OPENED, {'menu_type': 'controls'})
