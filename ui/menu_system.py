"""
MenuSystem - 메뉴 시스템
게임의 모든 메뉴 UI 관리
"""

import pygame
import math
import random
from typing import List, Dict, Any, Optional, Callable
from core.game_state import GameState
from core.events import EventType, emit_event
from enum import Enum


def draw_glass_orb_button(surface: pygame.Surface, rect: pygame.Rect,
                          text: str, font: pygame.font.Font,
                          selected: bool = False, hover: bool = False,
                          animation_timer: float = 0,
                          base_color: tuple = (80, 150, 255)) -> pygame.Rect:
    """투명 유리알 스타일 버튼 그리기

    Args:
        surface: 그릴 서피스
        rect: 버튼 영역
        text: 버튼 텍스트
        font: 폰트
        selected: 선택 상태
        hover: 호버 상태
        animation_timer: 애니메이션 타이머
        base_color: 기본 색상

    Returns:
        실제 버튼 영역
    """
    x, y, width, height = rect.x, rect.y, rect.width, rect.height
    center_x = x + width // 2
    center_y = y + height // 2

    # 선택/호버 상태에 따른 색상 조정
    if selected:
        # 선택 시 더 밝고 따뜻한 색상
        pulse = abs(math.sin(animation_timer * 0.08))
        r = min(255, int(base_color[0] * 1.5 + 100 * pulse))
        g = min(255, int(base_color[1] * 1.3 + 80 * pulse))
        b = min(255, int(base_color[2] * 0.8))
        glow_color = (r, g, b)
        glow_intensity = 1.5 + 0.5 * pulse
        scale_factor = 1.08 + 0.03 * pulse
    elif hover:
        glow_color = (min(255, base_color[0] + 40),
                      min(255, base_color[1] + 40),
                      min(255, base_color[2] + 40))
        glow_intensity = 1.2
        scale_factor = 1.03
    else:
        glow_color = base_color
        glow_intensity = 1.0
        scale_factor = 1.0

    # 스케일 적용
    scaled_width = int(width * scale_factor)
    scaled_height = int(height * scale_factor)
    scaled_x = center_x - scaled_width // 2
    scaled_y = center_y - scaled_height // 2

    # 버튼 서피스 생성
    button_surface = pygame.Surface((scaled_width + 40, scaled_height + 40), pygame.SRCALPHA)
    btn_cx = (scaled_width + 40) // 2
    btn_cy = (scaled_height + 40) // 2

    # === 1. 외곽 글로우 효과 (발광) ===
    for i in range(12):
        glow_alpha = int(40 * glow_intensity * (12 - i) / 12)
        glow_radius = max(scaled_width, scaled_height) // 2 + 15 - i
        glow_surf = pygame.Surface((glow_radius * 2 + 4, glow_radius * 2 + 4), pygame.SRCALPHA)
        pygame.draw.ellipse(glow_surf, (*glow_color, glow_alpha),
                           (0, 0, glow_radius * 2 + 4, int((glow_radius * 2 + 4) * 0.6)))
        button_surface.blit(glow_surf,
                           (btn_cx - glow_radius - 2,
                            btn_cy - int(glow_radius * 0.3) - 2))

    # === 2. 그림자 (아래쪽) ===
    shadow_height = int(scaled_height * 0.15)
    shadow_surf = pygame.Surface((scaled_width + 20, shadow_height + 10), pygame.SRCALPHA)
    for i in range(shadow_height):
        shadow_alpha = int(60 * (shadow_height - i) / shadow_height)
        pygame.draw.ellipse(shadow_surf, (0, 0, 0, shadow_alpha),
                           (5 + i, i, scaled_width + 10 - i * 2, shadow_height - i))
    button_surface.blit(shadow_surf,
                       (btn_cx - scaled_width // 2 - 10,
                        btn_cy + scaled_height // 2 - 5))

    # === 3. 메인 유리알 본체 (그라데이션) ===
    glass_surf = pygame.Surface((scaled_width + 4, scaled_height + 4), pygame.SRCALPHA)

    # 본체 그라데이션 (위에서 아래로)
    for i in range(scaled_height):
        ratio = i / scaled_height
        # 상단: 밝음, 하단: 어둡고 채도 높음
        r = int(glow_color[0] * (0.4 + 0.4 * (1 - ratio)))
        g = int(glow_color[1] * (0.4 + 0.4 * (1 - ratio)))
        b = int(glow_color[2] * (0.5 + 0.3 * (1 - ratio)))
        # 투명도: 중앙이 가장 높음, 가장자리 낮음
        base_alpha = 180 if selected else 140
        alpha = int(base_alpha * (0.7 + 0.3 * math.sin(ratio * math.pi)))

        # 수평 그라데이션 적용
        line_surf = pygame.Surface((scaled_width, 1), pygame.SRCALPHA)
        for j in range(scaled_width):
            h_ratio = abs(j - scaled_width / 2) / (scaled_width / 2)
            edge_fade = 1 - h_ratio * 0.3
            pygame.draw.line(line_surf, (r, g, b, int(alpha * edge_fade)), (j, 0), (j, 1))
        glass_surf.blit(line_surf, (2, 2 + i))

    # 둥근 모서리 마스크 적용
    mask_surf = pygame.Surface((scaled_width + 4, scaled_height + 4), pygame.SRCALPHA)
    pygame.draw.rect(mask_surf, (255, 255, 255, 255),
                    (0, 0, scaled_width + 4, scaled_height + 4),
                    border_radius=min(20, scaled_height // 3))

    # 마스크 적용
    for px in range(glass_surf.get_width()):
        for py in range(glass_surf.get_height()):
            if mask_surf.get_at((px, py))[3] == 0:
                glass_surf.set_at((px, py), (0, 0, 0, 0))

    button_surface.blit(glass_surf, (btn_cx - scaled_width // 2 - 2,
                                      btn_cy - scaled_height // 2 - 2))

    # === 4. 상단 하이라이트 (반사광) ===
    highlight_height = int(scaled_height * 0.35)
    highlight_surf = pygame.Surface((scaled_width - 10, highlight_height), pygame.SRCALPHA)
    for i in range(highlight_height):
        ratio = i / highlight_height
        alpha = int(120 * (1 - ratio) * (1 - ratio))
        # 가장자리 페이드
        pygame.draw.ellipse(highlight_surf, (255, 255, 255, alpha),
                           (i * 2, i, scaled_width - 10 - i * 4, highlight_height - i * 2))
    button_surface.blit(highlight_surf,
                       (btn_cx - scaled_width // 2 + 5,
                        btn_cy - scaled_height // 2 + 3))

    # === 5. 테두리 (림 라이팅) ===
    rim_color = (min(255, glow_color[0] + 80),
                 min(255, glow_color[1] + 80),
                 min(255, glow_color[2] + 80))
    rim_surf = pygame.Surface((scaled_width + 6, scaled_height + 6), pygame.SRCALPHA)

    # 외곽 림
    pygame.draw.rect(rim_surf, (*rim_color, 100),
                    (0, 0, scaled_width + 6, scaled_height + 6),
                    width=2, border_radius=min(22, scaled_height // 3 + 2))
    # 내곽 림 (더 밝음)
    pygame.draw.rect(rim_surf, (*rim_color, 60),
                    (2, 2, scaled_width + 2, scaled_height + 2),
                    width=1, border_radius=min(20, scaled_height // 3))
    button_surface.blit(rim_surf, (btn_cx - scaled_width // 2 - 3,
                                   btn_cy - scaled_height // 2 - 3))

    # === 6. 선택 시 반짝이는 입자 효과 ===
    if selected:
        particle_count = 6
        for i in range(particle_count):
            angle = animation_timer * 0.05 + i * (math.pi * 2 / particle_count)
            dist = scaled_width * 0.35 + math.sin(animation_timer * 0.1 + i) * 8
            px = int(btn_cx + math.cos(angle) * dist)
            py = int(btn_cy + math.sin(angle) * dist * 0.4)

            # 입자 크기 변동
            size = 2 + int(abs(math.sin(animation_timer * 0.15 + i * 0.5)) * 2)
            alpha = int(150 + 100 * abs(math.sin(animation_timer * 0.1 + i)))

            # 빛나는 점
            spark_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
            pygame.draw.circle(spark_surf, (255, 255, 200, alpha), (size * 2, size * 2), size)
            pygame.draw.circle(spark_surf, (255, 255, 255, min(255, alpha + 50)), (size * 2, size * 2), size // 2)
            button_surface.blit(spark_surf, (px - size * 2, py - size * 2))

    # === 7. 하단 반사 (유리알 아래 하이라이트) ===
    bottom_highlight_height = int(scaled_height * 0.15)
    bottom_surf = pygame.Surface((scaled_width - 20, bottom_highlight_height), pygame.SRCALPHA)
    for i in range(bottom_highlight_height):
        ratio = i / bottom_highlight_height
        alpha = int(40 * ratio)
        pygame.draw.ellipse(bottom_surf, (255, 255, 255, alpha),
                           (i, 0, scaled_width - 20 - i * 2, bottom_highlight_height - i))
    button_surface.blit(bottom_surf,
                       (btn_cx - scaled_width // 2 + 10,
                        btn_cy + scaled_height // 2 - bottom_highlight_height - 3))

    # 버튼 서피스를 메인 서피스에 블릿
    surface.blit(button_surface, (scaled_x - 20, scaled_y - 20))

    # === 8. 텍스트 렌더링 ===
    if selected:
        text_color = (255, 255, 255)
        # 텍스트 글로우
        glow_text = font.render(text, True, glow_color)
        glow_text.set_alpha(150)
        for offset in [(-2, -1), (2, -1), (-2, 1), (2, 1), (0, -2), (0, 2)]:
            text_rect = glow_text.get_rect(center=(center_x + offset[0], center_y + offset[1]))
            surface.blit(glow_text, text_rect)
    else:
        text_color = (220, 230, 255) if hover else (180, 200, 230)

    # 텍스트 그림자
    shadow_text = font.render(text, True, (20, 30, 50))
    shadow_rect = shadow_text.get_rect(center=(center_x + 1, center_y + 2))
    surface.blit(shadow_text, shadow_rect)

    # 메인 텍스트
    text_surface = font.render(text, True, text_color)
    text_rect = text_surface.get_rect(center=(center_x, center_y))
    surface.blit(text_surface, text_rect)

    return pygame.Rect(scaled_x, scaled_y, scaled_width, scaled_height)


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
        """배경 파티클 초기화 (부드럽게 떠다니는 빛나는 입자)"""
        for _ in range(60):
            self.particles.append({
                'x': random.randint(0, self.width),
                'y': random.randint(0, self.height),
                'vx': random.uniform(-0.3, 0.3),
                'vy': random.uniform(-0.8, -0.2),
                'size': random.randint(1, 4),
                'alpha': random.randint(80, 180),
                'phase': random.uniform(0, math.pi * 2)  # 흔들림 위상
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
        
        # 파티클 업데이트 (물결치듯 부드러운 움직임)
        for particle in self.particles:
            # 위상 업데이트
            particle['phase'] = particle.get('phase', 0) + 0.02

            # 좌우 흔들림 추가
            wave_offset = math.sin(particle['phase']) * 0.5
            particle['x'] += particle['vx'] + wave_offset
            particle['y'] += particle['vy']

            # 알파 깜빡임
            base_alpha = particle.get('base_alpha', particle['alpha'])
            if 'base_alpha' not in particle:
                particle['base_alpha'] = particle['alpha']
            particle['alpha'] = int(base_alpha * (0.7 + 0.3 * abs(math.sin(particle['phase'] * 0.5))))

            # 화면 밖으로 나가면 위치 리셋
            if particle['y'] < -10:
                particle['y'] = self.height + 10
                particle['x'] = random.randint(0, self.width)
                particle['size'] = random.randint(1, 4)
            if particle['x'] < -10:
                particle['x'] = self.width + 10
            elif particle['x'] > self.width + 10:
                particle['x'] = -10
                
    def render(self, screen: pygame.Surface = None):
        """메뉴 렌더링"""
        if screen:
            self.screen = screen
            
        if self.current_menu:
            self.draw_menu(self.current_menu)
            
    def draw_menu(self, menu_items: List[MenuItem]):
        """메뉴 그리기 (유리알 버튼 스타일)"""
        # 배경
        self.draw_background()

        # 제목 (상태별로 다른 제목)
        title_text = self._get_menu_title()

        # 제목 배경 글로우
        title_glow_pulse = abs(math.sin(self.animation_timer * 0.03))
        for i in range(8):
            glow_alpha = int(30 * (8 - i) / 8 * (0.5 + 0.5 * title_glow_pulse))
            glow_color = (0, 255, 200, glow_alpha)
            glow_surf = pygame.Surface((400 + i * 20, 80 + i * 10), pygame.SRCALPHA)
            pygame.draw.ellipse(glow_surf, glow_color, glow_surf.get_rect())
            self.screen.blit(glow_surf, (self.width // 2 - glow_surf.get_width() // 2,
                                         75 - glow_surf.get_height() // 2))

        title_surface = self.font_title.render(title_text, True, self.colors['primary'])
        title_rect = title_surface.get_rect(center=(self.width // 2, 100))

        # 제목 글로우 효과
        glow_alpha = abs(math.sin(self.animation_timer * 0.05)) * 50 + 50
        glow_surface = self.font_title.render(title_text, True, self.colors['glow'])
        glow_surface.set_alpha(int(glow_alpha))
        for offset in [(-2, -2), (2, -2), (-2, 2), (2, 2)]:
            self.screen.blit(glow_surface, (title_rect.x + offset[0], title_rect.y + offset[1]))

        self.screen.blit(title_surface, title_rect)

        # === 유리알 버튼 스타일 메뉴 아이템 ===
        button_width = 280
        button_height = 48
        start_y = 200
        item_spacing = 58

        # 버튼 색상 팔레트 (아이템별로 다른 색상)
        button_colors = [
            (100, 180, 255),   # 게임 시작 - 파랑
            (180, 140, 255),   # 아카데미 - 보라
            (255, 180, 100),   # 가챠 - 주황
            (100, 255, 180),   # 스테이지 - 청록
            (200, 200, 220),   # 설정 - 회색
            (150, 220, 255),   # 도움말 - 하늘
            (255, 200, 150),   # 크레딧 - 베이지
            (255, 120, 120),   # 종료 - 빨강
        ]

        for i, item in enumerate(menu_items):
            y = start_y + i * item_spacing

            # 선택 상태 업데이트
            is_selected = (i == self.selected_index)
            is_hover = item.hover
            item.selected = is_selected

            # 버튼 영역 계산
            btn_rect = pygame.Rect(
                self.width // 2 - button_width // 2,
                y - button_height // 2,
                button_width,
                button_height
            )

            # 아이템별 색상 (범위 초과 시 기본 색상)
            base_color = button_colors[i % len(button_colors)]

            # 유리알 버튼 그리기
            actual_rect = draw_glass_orb_button(
                self.screen,
                btn_rect,
                item.text,
                self.font_menu,
                selected=is_selected,
                hover=is_hover,
                animation_timer=self.animation_timer,
                base_color=base_color
            )

            # 클릭 영역 저장
            item.rect = actual_rect

        # 파티클 렌더링 (버튼 위에)
        self._render_particles()

        # 상태별 추가 UI
        self._render_state_ui()
            
    def draw_background(self):
        """배경 그리기 (고급 그라데이션 + 빛 효과)"""
        # 깊은 우주 느낌의 그라데이션 배경
        for y in range(0, self.height, 2):
            ratio = y / self.height
            # 상단: 깊은 남색, 하단: 진한 보라
            r = int(8 + ratio * 15 + math.sin(ratio * math.pi) * 10)
            g = int(12 + ratio * 8)
            b = int(35 + ratio * 25 - math.sin(ratio * math.pi) * 15)
            pygame.draw.rect(self.screen, (r, g, b), (0, y, self.width, 2))

        # 중앙 빛줄기 효과 (버튼들 뒤쪽)
        beam_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        beam_pulse = 0.7 + 0.3 * abs(math.sin(self.animation_timer * 0.02))
        for i in range(20):
            beam_alpha = int(15 * beam_pulse * (20 - i) / 20)
            beam_width = 200 + i * 15
            pygame.draw.ellipse(beam_surf, (80, 120, 180, beam_alpha),
                               (self.width // 2 - beam_width // 2, 100, beam_width, self.height - 100))
        self.screen.blit(beam_surf, (0, 0))

        # 별빛 효과 (작은 반짝이는 점들)
        star_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        random.seed(42)  # 고정 시드로 일관된 별 위치
        for _ in range(80):
            sx = random.randint(0, self.width)
            sy = random.randint(0, self.height)
            # 반짝임 애니메이션
            twinkle = abs(math.sin(self.animation_timer * 0.03 + sx * 0.01 + sy * 0.01))
            star_alpha = int(50 + 100 * twinkle)
            star_size = 1 + int(twinkle * 1.5)
            pygame.draw.circle(star_surf, (200, 220, 255, star_alpha), (sx, sy), star_size)
        self.screen.blit(star_surf, (0, 0))

        # 움직이는 빛 파티클 (느린 움직임)
        particle_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        for i in range(15):
            angle = self.animation_timer * 0.01 + i * 0.5
            radius = 150 + i * 20
            px = self.width // 2 + int(math.cos(angle) * radius * 0.3)
            py = self.height // 2 + int(math.sin(angle * 0.7) * radius * 0.8)

            # 부드러운 글로우 파티클
            for j in range(5):
                p_alpha = int(30 * (5 - j) / 5)
                p_size = 8 + j * 4
                pygame.draw.circle(particle_surf, (100, 150, 220, p_alpha), (px, py), p_size)
        self.screen.blit(particle_surf, (0, 0))

        # 하단 반사광 (바닥 느낌)
        floor_surf = pygame.Surface((self.width, 100), pygame.SRCALPHA)
        for i in range(100):
            floor_alpha = int(20 * (100 - i) / 100)
            pygame.draw.rect(floor_surf, (60, 80, 120, floor_alpha), (0, i, self.width, 1))
        self.screen.blit(floor_surf, (0, self.height - 100))

        # 모서리 비네팅 효과
        vignette_surf = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        for i in range(50):
            vig_alpha = int(80 * (50 - i) / 50)
            pygame.draw.rect(vignette_surf, (0, 0, 0, vig_alpha),
                            (i, i, self.width - i * 2, self.height - i * 2), 1)
        self.screen.blit(vignette_surf, (0, 0))

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
        """파티클 렌더링 (유리알 느낌의 빛나는 먼지)"""
        for particle in self.particles:
            # 파티클 크기와 글로우
            size = particle['size']
            px, py = int(particle['x']), int(particle['y'])

            # 외곽 글로우
            glow_size = size * 4
            glow_surf = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
            glow_alpha = int(particle['alpha'] * 0.3)
            pygame.draw.circle(glow_surf, (150, 200, 255, glow_alpha),
                             (glow_size, glow_size), glow_size)
            self.screen.blit(glow_surf, (px - glow_size, py - glow_size))

            # 메인 파티클 (밝은 중심)
            main_surf = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
            pygame.draw.circle(main_surf, (200, 230, 255, particle['alpha']),
                             (size * 2, size * 2), size + 1)
            pygame.draw.circle(main_surf, (255, 255, 255, min(255, particle['alpha'] + 50)),
                             (size * 2, size * 2), size)
            self.screen.blit(main_surf, (px - size * 2, py - size * 2))
            
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
