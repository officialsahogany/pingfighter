"""
Settings UI - 설정 UI
게임 설정 인터페이스
"""

import pygame
import math
from typing import Optional, List, Dict, Any, Tuple
from core.events import EventType, emit_event
from core.global_manager import GlobalManager
from config.settings_system import (
    get_settings_manager,
    SettingCategory,
    GraphicsQuality,
    LANGUAGE_OPTIONS,
)

LANGUAGE_LABELS = {code: label for code, label in LANGUAGE_OPTIONS}
LANGUAGE_CODES = [code for code, _ in LANGUAGE_OPTIONS]


class SettingsUI:
    """설정 UI 시스템"""
    
    def __init__(self, screen: pygame.Surface):
        """설정 UI 초기화
        
        Args:
            screen: 화면 Surface
        """
        self.screen = screen
        self.global_manager = GlobalManager.get_instance()
        self.settings_manager = get_settings_manager()
        
        # UI 상태
        self.active = False
        self.current_category = SettingCategory.CONTROLS
        self.selected_index = 0
        self.scroll_offset = 0
        
        # 키 바인딩 모드
        self.binding_mode = False
        self.binding_action = None
        self.binding_type = None  # 'primary' or 'secondary'
        
        # 슬라이더 드래그
        self.dragging_slider = None
        
        # 폰트
        try:
            self.font_title = pygame.font.Font("NanumSquareEB.ttf", 36)
            self.font_category = pygame.font.Font("NanumSquareB.ttf", 28)
            self.font_option = pygame.font.Font("NanumSquareR.ttf", 20)
            self.font_small = pygame.font.Font("NanumSquareR.ttf", 16)
        except:
            self.font_title = pygame.font.Font(None, 36)
            self.font_category = pygame.font.Font(None, 28)
            self.font_option = pygame.font.Font(None, 20)
            self.font_small = pygame.font.Font(None, 16)
            
        # 애니메이션
        self.animation_timer = 0
        self.fade_alpha = 0
        
        # UI 레이아웃
        self.panel_width = 500
        self.panel_height = 600
        self.panel_x = (self.global_manager.get('WIDTH', 600) - self.panel_width) // 2
        self.panel_y = (self.global_manager.get('HEIGHT', 750) - self.panel_height) // 2
        
        # 카테고리 탭
        self.tab_height = 50
        self.content_start_y = self.panel_y + self.tab_height + 20
        
        # 설정 항목들
        self.setting_items: Dict[SettingCategory, List[Dict]] = {
            SettingCategory.LANGUAGE: self._get_language_items(),
            SettingCategory.CONTROLS: self._get_control_items(),
            SettingCategory.GRAPHICS: self._get_graphics_items(),
            SettingCategory.AUDIO: self._get_audio_items(),
            SettingCategory.GAMEPLAY: self._get_gameplay_items(),
            SettingCategory.NETWORK: self._get_network_items()
        }

        self.category_key_map = {
            SettingCategory.LANGUAGE: 'language',
            SettingCategory.GRAPHICS: 'graphics',
            SettingCategory.AUDIO: 'audio',
            SettingCategory.GAMEPLAY: 'gameplay',
            SettingCategory.NETWORK: 'network'
        }
        
    def _get_control_items(self) -> List[Dict]:
        """조작 설정 항목들"""
        items = []
        
        for action, binding in self.settings_manager.key_bindings.items():
            items.append({
                'type': 'key_binding',
                'action': action,
                'label': binding.description or action
            })
            
        return items
        
    def _get_language_items(self) -> List[Dict]:
        """언어 설정 항목들"""
        return [
            {
                'type': 'dropdown',
                'key': 'language',
                'label': '언어',
                'options': LANGUAGE_CODES,
                'format': lambda code: LANGUAGE_LABELS.get(code, code)
            }
        ]

    def _get_graphics_items(self) -> List[Dict]:
        """그래픽 설정 항목들"""
        return [
            {
                'type': 'dropdown',
                'key': 'resolution',
                'label': '해상도',
                'options': [(600, 750), (800, 1000), (1024, 1280), (1200, 1500)],
                'format': lambda x: f"{x[0]}x{x[1]}"
            },
            {
                'type': 'toggle',
                'key': 'fullscreen',
                'label': '전체화면'
            },
            {
                'type': 'dropdown',
                'key': 'quality',
                'label': '그래픽 품질',
                'options': [q.name for q in GraphicsQuality],
                'format': lambda x: GraphicsQuality[x].value[0]
            },
            {
                'type': 'slider',
                'key': 'fps_limit',
                'label': 'FPS 제한',
                'min': 30,
                'max': 144,
                'step': 1
            },
            {
                'type': 'toggle',
                'key': 'vsync',
                'label': '수직 동기화'
            },
            {
                'type': 'toggle',
                'key': 'particles',
                'label': '파티클 효과'
            },
            {
                'type': 'toggle',
                'key': 'screen_shake',
                'label': '화면 흔들림'
            },
            {
                'type': 'toggle',
                'key': 'shadows',
                'label': '그림자'
            },
            {
                'type': 'toggle',
                'key': 'show_fps',
                'label': 'FPS 표시'
            }
        ]
        
    def _get_audio_items(self) -> List[Dict]:
        """오디오 설정 항목들"""
        return [
            {
                'type': 'slider',
                'key': 'master_volume',
                'label': '마스터 볼륨',
                'min': 0,
                'max': 1,
                'step': 0.1
            },
            {
                'type': 'slider',
                'key': 'sfx_volume',
                'label': '효과음 볼륨',
                'min': 0,
                'max': 1,
                'step': 0.1
            },
            {
                'type': 'slider',
                'key': 'music_volume',
                'label': '음악 볼륨',
                'min': 0,
                'max': 1,
                'step': 0.1
            },
            {
                'type': 'toggle',
                'key': 'mute_all',
                'label': '모두 음소거'
            },
            {
                'type': 'toggle',
                'key': 'spatial_audio',
                'label': '공간 음향'
            },
            {
                'type': 'toggle',
                'key': 'dynamic_music',
                'label': '동적 음악'
            }
        ]
        
    def _get_gameplay_items(self) -> List[Dict]:
        """게임플레이 설정 항목들"""
        return [
            {
                'type': 'dropdown',
                'key': 'difficulty',
                'label': '난이도',
                'options': ['easy', 'normal', 'hard', 'insane'],
                'format': lambda x: {'easy': '쉬움', 'normal': '보통', 
                                   'hard': '어려움', 'insane': '극한'}.get(x, x)
            },
            {
                'type': 'toggle',
                'key': 'auto_save',
                'label': '자동 저장'
            },
            {
                'type': 'toggle',
                'key': 'show_hints',
                'label': '힌트 표시'
            },
            {
                'type': 'slider',
                'key': 'camera_shake_intensity',
                'label': '카메라 흔들림 강도',
                'min': 0,
                'max': 2,
                'step': 0.1
            },
            {
                'type': 'toggle',
                'key': 'damage_numbers',
                'label': '데미지 숫자'
            },
            {
                'type': 'toggle',
                'key': 'auto_pause_on_focus_loss',
                'label': '포커스 잃을 때 자동 일시정지'
            }
        ]
        
    def _get_network_items(self) -> List[Dict]:
        """네트워크 설정 항목들"""
        return [
            {
                'type': 'text',
                'key': 'player_name',
                'label': '플레이어 이름'
            },
            {
                'type': 'number',
                'key': 'default_port',
                'label': '기본 포트',
                'min': 1024,
                'max': 65535
            },
            {
                'type': 'toggle',
                'key': 'auto_reconnect',
                'label': '자동 재연결'
            },
            {
                'type': 'slider',
                'key': 'ping_limit',
                'label': '핑 제한 (ms)',
                'min': 50,
                'max': 500,
                'step': 50
            },
            {
                'type': 'toggle',
                'key': 'interpolation',
                'label': '보간'
            },
            {
                'type': 'toggle',
                'key': 'prediction',
                'label': '예측'
            }
        ]
        
    def open(self):
        """설정 UI 열기"""
        self.active = True
        self.fade_alpha = 0
        self.selected_index = 0
        self.scroll_offset = 0
        emit_event(EventType.MENU_OPENED, {'type': 'settings'})
        
    def close(self):
        """설정 UI 닫기"""
        self.active = False
        self.binding_mode = False
        # 설정 저장
        self.settings_manager.save_settings()
        
    def handle_event(self, event: pygame.event.Event):
        """이벤트 처리
        
        Args:
            event: pygame 이벤트
        """
        if not self.active:
            return
            
        if self.binding_mode:
            self._handle_binding_event(event)
        else:
            self._handle_normal_event(event)
            
    def _handle_normal_event(self, event: pygame.event.Event):
        """일반 이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                self.close()
                
            elif event.key == pygame.K_TAB:
                # 카테고리 전환
                categories = list(SettingCategory)
                current_idx = categories.index(self.current_category)
                self.current_category = categories[(current_idx + 1) % len(categories)]
                self.selected_index = 0
                self.scroll_offset = 0
                
            elif event.key == pygame.K_UP:
                self.selected_index = max(0, self.selected_index - 1)
                self._adjust_scroll()
                
            elif event.key == pygame.K_DOWN:
                items = self.setting_items[self.current_category]
                self.selected_index = min(len(items) - 1, self.selected_index + 1)
                self._adjust_scroll()
                
            elif event.key == pygame.K_LEFT:
                self._adjust_value(-1)
                
            elif event.key == pygame.K_RIGHT:
                self._adjust_value(1)
                
            elif event.key == pygame.K_RETURN:
                self._activate_item()
                
        elif event.type == pygame.MOUSEBUTTONDOWN:
            if event.button == 1:  # 좌클릭
                self._handle_click(event.pos)
                
        elif event.type == pygame.MOUSEBUTTONUP:
            if event.button == 1:
                self.dragging_slider = None
                
        elif event.type == pygame.MOUSEMOTION:
            if self.dragging_slider:
                self._handle_slider_drag(event.pos)
                
    def _handle_binding_event(self, event: pygame.event.Event):
        """키 바인딩 이벤트 처리"""
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                # 바인딩 취소
                self.binding_mode = False
                self.binding_action = None
                self.binding_type = None
            else:
                # 키 바인딩 설정
                if self.binding_type == 'primary':
                    self.settings_manager.set_key_binding(
                        self.binding_action, primary=event.key
                    )
                else:
                    self.settings_manager.set_key_binding(
                        self.binding_action, secondary=event.key
                    )
                    
                self.binding_mode = False
                self.binding_action = None
                self.binding_type = None
                
    def _get_category_key(self, category: SettingCategory) -> Optional[str]:
        """카테고리 키 문자열 반환"""
        return self.category_key_map.get(category)

    def _get_setting_value(self, key: str, default: Any = None,
                            category: Optional[SettingCategory] = None) -> Any:
        """설정 값 조회"""
        target_category = category if category is not None else self.current_category
        category_key = self._get_category_key(target_category)
        if category_key is None:
            return default
        return self.settings_manager.get_setting(category_key, key, default)

    def _set_setting_value(self, key: str, value: Any,
                            category: Optional[SettingCategory] = None):
        """설정 값 저장"""
        target_category = category if category is not None else self.current_category
        category_key = self._get_category_key(target_category)
        if category_key is None:
            return
        self.settings_manager.set_setting(category_key, key, value)

    def _adjust_value(self, direction: int):
        """값 조정
        
        Args:
            direction: 방향 (-1 또는 1)
        """
        items = self.setting_items[self.current_category]
        if 0 <= self.selected_index < len(items):
            item = items[self.selected_index]
            
            if item['type'] == 'toggle':
                key = item['key']
                current = bool(self._get_setting_value(key, False))
                self._set_setting_value(key, not current)
                
            elif item['type'] == 'slider':
                key = item['key']
                current = self._get_setting_value(key, item['min'])
                step = item.get('step', 0.1)
                new_value = current + (step * direction)
                new_value = max(item['min'], min(item['max'], new_value))
                self._set_setting_value(key, new_value)
                
            elif item['type'] == 'dropdown':
                key = item['key']
                options = item['options']
                default_option = options[0] if options else None
                current = self._get_setting_value(key, default_option)
                if options:
                    try:
                        current_idx = options.index(current)
                    except ValueError:
                        current_idx = 0
                    new_idx = (current_idx + direction) % len(options)
                    self._set_setting_value(key, options[new_idx])
                    
    def _activate_item(self):
        """선택된 항목 활성화"""
        items = self.setting_items[self.current_category]
        if 0 <= self.selected_index < len(items):
            item = items[self.selected_index]
            
            if item['type'] == 'key_binding':
                # 키 바인딩 모드 진입
                self.binding_mode = True
                self.binding_action = item['action']
                self.binding_type = 'primary'
                
            elif item['type'] == 'toggle':
                self._adjust_value(1)
                
    def _handle_click(self, pos: Tuple[int, int]):
        """클릭 처리
        
        Args:
            pos: 클릭 위치
        """
        # 탭 클릭 체크
        tab_y = self.panel_y
        tab_width = self.panel_width // len(SettingCategory)
        
        for i, category in enumerate(SettingCategory):
            tab_x = self.panel_x + i * tab_width
            tab_rect = pygame.Rect(tab_x, tab_y, tab_width, self.tab_height)
            if tab_rect.collidepoint(pos):
                self.current_category = category
                self.selected_index = 0
                self.scroll_offset = 0
                return
                
        # 설정 항목 클릭 체크
        # TODO: 아이템별 클릭 처리
        
    def _handle_slider_drag(self, pos: Tuple[int, int]):
        """슬라이더 드래그 처리
        
        Args:
            pos: 마우스 위치
        """
        if self.dragging_slider:
            # TODO: 슬라이더 값 업데이트
            pass
            
    def _adjust_scroll(self):
        """스크롤 조정"""
        # TODO: 스크롤 위치 조정
        pass
        
    def update(self, dt: float):
        """업데이트
        
        Args:
            dt: 델타 타임
        """
        if not self.active:
            return
            
        # 애니메이션
        self.animation_timer += dt
        
        # 페이드 인
        if self.fade_alpha < 255:
            self.fade_alpha = min(255, self.fade_alpha + 500 * dt)
            
    def render(self, screen: pygame.Surface):
        """렌더링
        
        Args:
            screen: 화면 Surface
        """
        if not self.active:
            return
            
        # 배경 (반투명)
        overlay = pygame.Surface((self.global_manager.get('WIDTH', 600), 
                                 self.global_manager.get('HEIGHT', 750)))
        overlay.set_alpha(200)
        overlay.fill((0, 0, 0))
        screen.blit(overlay, (0, 0))
        
        # 패널 배경
        panel_surface = pygame.Surface((self.panel_width, self.panel_height))
        panel_surface.set_alpha(int(self.fade_alpha))
        panel_surface.fill((30, 30, 30))
        pygame.draw.rect(panel_surface, (100, 100, 100), 
                        (0, 0, self.panel_width, self.panel_height), 2)
        screen.blit(panel_surface, (self.panel_x, self.panel_y))
        
        # 카테고리 탭
        self._render_tabs(screen)
        
        # 설정 항목들
        self._render_items(screen)
        
        # 키 바인딩 모드
        if self.binding_mode:
            self._render_binding_mode(screen)
            
    def _render_tabs(self, screen: pygame.Surface):
        """탭 렌더링"""
        tab_width = self.panel_width // len(SettingCategory)
        
        for i, category in enumerate(SettingCategory):
            tab_x = self.panel_x + i * tab_width
            tab_y = self.panel_y
            
            # 선택된 탭 강조
            if category == self.current_category:
                pygame.draw.rect(screen, (60, 60, 60), 
                               (tab_x, tab_y, tab_width, self.tab_height))
                               
            # 탭 텍스트
            text = self.font_category.render(category.value, True, (255, 255, 255))
            text_rect = text.get_rect(center=(tab_x + tab_width // 2, 
                                             tab_y + self.tab_height // 2))
            screen.blit(text, text_rect)
            
            # 탭 구분선
            if i < len(SettingCategory) - 1:
                pygame.draw.line(screen, (100, 100, 100),
                               (tab_x + tab_width, tab_y),
                               (tab_x + tab_width, tab_y + self.tab_height))
                               
    def _render_items(self, screen: pygame.Surface):
        """설정 항목 렌더링"""
        items = self.setting_items[self.current_category]
        y = self.content_start_y - self.scroll_offset
        
        for i, item in enumerate(items):
            # 선택된 항목 강조
            if i == self.selected_index:
                pygame.draw.rect(screen, (50, 50, 50),
                               (self.panel_x + 10, y - 5, 
                                self.panel_width - 20, 30))
                                
            if item['type'] == 'key_binding':
                self._render_key_binding(screen, item, y)
            elif item['type'] == 'toggle':
                self._render_toggle(screen, item, y)
            elif item['type'] == 'slider':
                self._render_slider(screen, item, y)
            elif item['type'] == 'dropdown':
                self._render_dropdown(screen, item, y)
            elif item['type'] == 'text':
                self._render_text(screen, item, y)
                
            y += 35
            
    def _render_key_binding(self, screen: pygame.Surface, item: Dict, y: int):
        """키 바인딩 렌더링"""
        binding = self.settings_manager.get_key_binding(item['action'])
        if binding:
            # 라벨
            label_text = self.font_option.render(item['label'], True, (200, 200, 200))
            screen.blit(label_text, (self.panel_x + 20, y))
            
            # 주 키
            primary_text = binding.get_key_name(binding.primary)
            primary_surface = self.font_option.render(primary_text, True, (255, 255, 100))
            screen.blit(primary_surface, (self.panel_x + 250, y))
            
            # 보조 키
            secondary_text = binding.get_key_name(binding.secondary)
            secondary_surface = self.font_option.render(secondary_text, True, (200, 200, 100))
            screen.blit(secondary_surface, (self.panel_x + 350, y))
            
    def _render_toggle(self, screen: pygame.Surface, item: Dict, y: int):
        """토글 렌더링"""
        # 라벨
        label_text = self.font_option.render(item['label'], True, (200, 200, 200))
        screen.blit(label_text, (self.panel_x + 20, y))
        
        # 체크박스
        value = self.settings_manager.get_setting(
            self.current_category.value.lower(), item['key']
        )
        checkbox_x = self.panel_x + 400
        checkbox_rect = pygame.Rect(checkbox_x, y, 20, 20)
        pygame.draw.rect(screen, (100, 100, 100), checkbox_rect, 2)
        
        if value:
            pygame.draw.rect(screen, (100, 255, 100), 
                           (checkbox_x + 4, y + 4, 12, 12))
                           
    def _render_slider(self, screen: pygame.Surface, item: Dict, y: int):
        """슬라이더 렌더링"""
        # 라벨
        label_text = self.font_option.render(item['label'], True, (200, 200, 200))
        screen.blit(label_text, (self.panel_x + 20, y))
        
        # 슬라이더
        value = self.settings_manager.get_setting(
            self.current_category.value.lower(), item['key']
        )
        slider_x = self.panel_x + 250
        slider_width = 150
        
        # 슬라이더 트랙
        pygame.draw.line(screen, (100, 100, 100),
                       (slider_x, y + 10), (slider_x + slider_width, y + 10), 2)
                       
        # 슬라이더 핸들
        ratio = (value - item['min']) / (item['max'] - item['min'])
        handle_x = slider_x + int(slider_width * ratio)
        pygame.draw.circle(screen, (255, 255, 255), (handle_x, y + 10), 5)
        
        # 값 표시
        if item.get('step', 0.1) >= 1:
            value_text = str(int(value))
        else:
            value_text = f"{value:.1f}"
        value_surface = self.font_small.render(value_text, True, (150, 150, 150))
        screen.blit(value_surface, (slider_x + slider_width + 10, y + 3))
        
    def _render_dropdown(self, screen: pygame.Surface, item: Dict, y: int):
        """드롭다운 렌더링"""
        # 라벨
        label_text = self.font_option.render(item['label'], True, (200, 200, 200))
        screen.blit(label_text, (self.panel_x + 20, y))
        
        # 현재 값
        value = self.settings_manager.get_setting(
            self.current_category.value.lower(), item['key']
        )
        formatter = item.get('format', str)
        display_text = formatter(value)
        value_surface = self.font_option.render(display_text, True, (255, 255, 100))
        screen.blit(value_surface, (self.panel_x + 300, y))
        
    def _render_text(self, screen: pygame.Surface, item: Dict, y: int):
        """텍스트 입력 렌더링"""
        # 라벨
        label_text = self.font_option.render(item['label'], True, (200, 200, 200))
        screen.blit(label_text, (self.panel_x + 20, y))
        
        # 값
        value = self.settings_manager.get_setting(
            self.current_category.value.lower(), item['key']
        )
        value_surface = self.font_option.render(str(value), True, (255, 255, 100))
        screen.blit(value_surface, (self.panel_x + 300, y))
        
    def _render_binding_mode(self, screen: pygame.Surface):
        """키 바인딩 모드 렌더링"""
        # 오버레이
        overlay = pygame.Surface((self.panel_width - 40, 100))
        overlay.set_alpha(240)
        overlay.fill((40, 40, 40))
        overlay_rect = overlay.get_rect(center=(self.panel_x + self.panel_width // 2,
                                               self.panel_y + self.panel_height // 2))
        screen.blit(overlay, overlay_rect)
        
        # 안내 텍스트
        text = "새 키를 누르세요 (ESC로 취소)"
        text_surface = self.font_category.render(text, True, (255, 255, 100))
        text_rect = text_surface.get_rect(center=(self.panel_x + self.panel_width // 2,
                                                 self.panel_y + self.panel_height // 2))
        screen.blit(text_surface, text_rect)


# 싱글톤 인스턴스
_settings_ui = None

def get_settings_ui(screen: pygame.Surface) -> SettingsUI:
    """설정 UI 싱글톤 반환"""
    global _settings_ui
    if _settings_ui is None:
        _settings_ui = SettingsUI(screen)
    return _settings_ui
