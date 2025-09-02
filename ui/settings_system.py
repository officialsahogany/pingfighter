"""
SettingsSystem - 설정 시스템
게임 옵션, 컨트롤, 사운드, 그래픽 설정 관리
"""

import pygame
import json
import os
from typing import Dict, Any, Optional, List
from core.game_state import GameState
from core.events import EventType, emit_event


class SettingsSystem:
    """설정 시스템 관리자"""
    
    def __init__(self, screen: pygame.Surface, width: int = 600, height: int = 750):
        self.screen = screen
        self.width = width
        self.height = height
        self.game_state = GameState.get_instance()
        
        # 설정 파일 경로
        self.settings_file = "game_settings.json"
        
        # 기본 설정
        self.default_settings = {
            'sound': {
                'master_volume': 1.0,
                'music_volume': 0.8,
                'sfx_volume': 1.0,
                'sound_enabled': True,
                'music_enabled': True
            },
            'graphics': {
                'fullscreen': False,
                'vsync': True,
                'particle_quality': 'high',
                'effects_quality': 'high',
                'background_quality': 'high'
            },
            'controls': {
                'player1_left': pygame.K_LEFT,
                'player1_right': pygame.K_RIGHT,
                'player1_dash': pygame.K_SPACE,
                'player1_skill': pygame.K_z,
                'player2_left': pygame.K_a,
                'player2_right': pygame.K_d,
                'player2_dash': pygame.K_LSHIFT,
                'player2_skill': pygame.K_q,
                'pause': pygame.K_ESCAPE,
                'mouse_controls': False
            },
            'gameplay': {
                'difficulty': 'normal',
                'ai_mode': 'adaptive',
                'auto_save': True,
                'show_hints': True,
                'damage_numbers': True,
                'screen_shake': True,
                'camera_follow': True
            },
            'accessibility': {
                'colorblind_mode': 'off',
                'high_contrast': False,
                'reduce_motion': False,
                'larger_text': False,
                'screen_reader': False
            }
        }
        
        # 현재 설정
        self.current_settings = self.load_settings()
        
        # UI 상태
        self.current_tab = 'sound'
        self.tabs = ['sound', 'graphics', 'controls', 'gameplay', 'accessibility']
        self.selected_option = 0
        self.editing_control = None
        self.unsaved_changes = False
        
        # 폰트 초기화
        self.init_fonts()
        
        # 색상 테마
        self.colors = {
            'background': (20, 20, 30),
            'panel': (30, 30, 40),
            'border': (100, 150, 255),
            'text': (255, 255, 255),
            'text_dim': (180, 180, 180),
            'accent': (0, 255, 200),
            'warning': (255, 200, 50),
            'error': (255, 80, 80),
            'success': (0, 255, 100)
        }
        
    def init_fonts(self):
        """폰트 초기화"""
        try:
            self.font_title = pygame.font.Font("NanumSquareEB.ttf", 36)
            self.font_tab = pygame.font.Font("NanumSquareB.ttf", 24)
            self.font_option = pygame.font.Font("NanumSquareR.ttf", 20)
            self.font_value = pygame.font.Font("NanumSquareB.ttf", 20)
            self.font_small = pygame.font.Font("NanumSquareR.ttf", 16)
        except:
            self.font_title = pygame.font.Font(None, 36)
            self.font_tab = pygame.font.Font(None, 24)
            self.font_option = pygame.font.Font(None, 20)
            self.font_value = pygame.font.Font(None, 20)
            self.font_small = pygame.font.Font(None, 16)
            
    def load_settings(self) -> Dict[str, Any]:
        """설정 파일 로드"""
        if os.path.exists(self.settings_file):
            try:
                with open(self.settings_file, 'r', encoding='utf-8') as f:
                    loaded_settings = json.load(f)
                    # 기본 설정과 병합 (새로운 옵션 추가 대응)
                    return self.merge_settings(self.default_settings, loaded_settings)
            except:
                return self.default_settings.copy()
        return self.default_settings.copy()
        
    def merge_settings(self, default: Dict, loaded: Dict) -> Dict:
        """기본 설정과 로드된 설정 병합"""
        merged = default.copy()
        for key, value in loaded.items():
            if key in merged:
                if isinstance(value, dict) and isinstance(merged[key], dict):
                    merged[key] = self.merge_settings(merged[key], value)
                else:
                    merged[key] = value
        return merged
        
    def save_settings(self):
        """설정 파일 저장"""
        try:
            with open(self.settings_file, 'w', encoding='utf-8') as f:
                json.dump(self.current_settings, f, indent=2, ensure_ascii=False)
            self.unsaved_changes = False
            
            # 이벤트 발생
            emit_event(EventType.SETTINGS_CHANGED, self.current_settings)
            return True
        except Exception as e:
            print(f"설정 저장 실패: {e}")
            return False
            
    def apply_settings(self):
        """설정 적용"""
        # GameState에 설정 적용
        self.game_state.sound_enabled = self.current_settings['sound']['sound_enabled']
        self.game_state.music_enabled = self.current_settings['sound']['music_enabled']
        self.game_state.ai_mode = self.current_settings['gameplay']['difficulty']
        
        # 이벤트 발생
        emit_event(EventType.SETTINGS_CHANGED, self.current_settings)
        
    def reset_to_defaults(self):
        """기본 설정으로 초기화"""
        self.current_settings = self.default_settings.copy()
        self.unsaved_changes = True
        
    def draw(self):
        """설정 화면 그리기"""
        # 배경
        self.screen.fill(self.colors['background'])
        
        # 제목
        title_text = self.font_title.render("⚙️ 설정", True, self.colors['text'])
        title_rect = title_text.get_rect(center=(self.width // 2, 40))
        self.screen.blit(title_text, title_rect)
        
        # 탭 그리기
        self.draw_tabs()
        
        # 현재 탭 내용 그리기
        self.draw_tab_content()
        
        # 저장되지 않은 변경사항 표시
        if self.unsaved_changes:
            warning_text = self.font_small.render("⚠️ 저장되지 않은 변경사항", True, self.colors['warning'])
            warning_rect = warning_text.get_rect(topright=(self.width - 20, 10))
            self.screen.blit(warning_text, warning_rect)
            
        # 하단 버튼들
        self.draw_bottom_buttons()
        
    def draw_tabs(self):
        """탭 그리기"""
        tab_width = (self.width - 40) // len(self.tabs)
        tab_height = 40
        tab_y = 80
        
        for i, tab in enumerate(self.tabs):
            x = 20 + i * tab_width
            rect = pygame.Rect(x, tab_y, tab_width, tab_height)
            
            # 탭 배경
            if tab == self.current_tab:
                pygame.draw.rect(self.screen, self.colors['accent'], rect)
                color = self.colors['background']
            else:
                pygame.draw.rect(self.screen, self.colors['panel'], rect)
                pygame.draw.rect(self.screen, self.colors['border'], rect, 2)
                color = self.colors['text_dim']
                
            # 탭 텍스트
            tab_names = {
                'sound': '🔊 사운드',
                'graphics': '🎨 그래픽',
                'controls': '🎮 컨트롤',
                'gameplay': '⚔️ 게임플레이',
                'accessibility': '♿ 접근성'
            }
            text = self.font_tab.render(tab_names[tab], True, color)
            text_rect = text.get_rect(center=rect.center)
            self.screen.blit(text, text_rect)
            
    def draw_tab_content(self):
        """탭 내용 그리기"""
        content_area = pygame.Rect(20, 140, self.width - 40, self.height - 240)
        pygame.draw.rect(self.screen, self.colors['panel'], content_area)
        pygame.draw.rect(self.screen, self.colors['border'], content_area, 2)
        
        y = 160
        options = self.get_current_tab_options()
        
        for i, (key, value) in enumerate(options.items()):
            # 선택된 옵션 강조
            if i == self.selected_option:
                highlight_rect = pygame.Rect(30, y - 5, self.width - 60, 35)
                pygame.draw.rect(self.screen, (*self.colors['accent'], 50), highlight_rect)
                
            # 옵션 이름
            option_text = self.font_option.render(self.get_option_display_name(key), 
                                                 True, self.colors['text'])
            self.screen.blit(option_text, (40, y))
            
            # 옵션 값
            value_display = self.get_value_display(key, value)
            if isinstance(value, bool):
                # 체크박스
                checkbox_rect = pygame.Rect(self.width - 100, y, 20, 20)
                pygame.draw.rect(self.screen, self.colors['border'], checkbox_rect, 2)
                if value:
                    pygame.draw.rect(self.screen, self.colors['accent'], 
                                   checkbox_rect.inflate(-6, -6))
            elif isinstance(value, (int, float)):
                # 슬라이더
                self.draw_slider(self.width - 200, y + 5, 150, value, key)
            elif isinstance(value, str):
                # 텍스트 또는 선택 옵션
                value_text = self.font_value.render(value_display, True, self.colors['accent'])
                value_rect = value_text.get_rect(right=self.width - 40, centery=y + 10)
                self.screen.blit(value_text, value_rect)
            elif isinstance(value, int) and self.current_tab == 'controls':
                # 키 바인딩
                key_name = pygame.key.name(value).upper()
                if self.editing_control == key:
                    key_name = "Press key..."
                    color = self.colors['warning']
                else:
                    color = self.colors['accent']
                key_text = self.font_value.render(key_name, True, color)
                key_rect = key_text.get_rect(right=self.width - 40, centery=y + 10)
                pygame.draw.rect(self.screen, self.colors['border'], 
                               key_rect.inflate(10, 5), 2)
                self.screen.blit(key_text, key_rect)
                
            y += 40
            
    def draw_slider(self, x: int, y: int, width: int, value: float, key: str):
        """슬라이더 그리기"""
        # 슬라이더 트랙
        track_rect = pygame.Rect(x, y + 8, width, 4)
        pygame.draw.rect(self.screen, self.colors['border'], track_rect)
        
        # 슬라이더 핸들
        handle_x = x + int(width * value)
        handle_rect = pygame.Rect(handle_x - 8, y, 16, 20)
        pygame.draw.rect(self.screen, self.colors['accent'], handle_rect)
        pygame.draw.rect(self.screen, self.colors['text'], handle_rect, 2)
        
        # 값 표시
        value_text = self.font_small.render(f"{int(value * 100)}%", True, self.colors['text'])
        value_rect = value_text.get_rect(center=(x + width // 2, y - 10))
        self.screen.blit(value_text, value_rect)
        
    def draw_bottom_buttons(self):
        """하단 버튼 그리기"""
        button_y = self.height - 60
        button_width = 120
        button_height = 40
        
        # 저장 버튼
        save_rect = pygame.Rect(self.width // 2 - button_width - 10, button_y, 
                               button_width, button_height)
        save_color = self.colors['success'] if self.unsaved_changes else self.colors['border']
        pygame.draw.rect(self.screen, save_color, save_rect, 2)
        save_text = self.font_tab.render("💾 저장", True, save_color)
        save_text_rect = save_text.get_rect(center=save_rect.center)
        self.screen.blit(save_text, save_text_rect)
        
        # 초기화 버튼
        reset_rect = pygame.Rect(self.width // 2 + 10, button_y, 
                                button_width, button_height)
        pygame.draw.rect(self.screen, self.colors['warning'], reset_rect, 2)
        reset_text = self.font_tab.render("↺ 초기화", True, self.colors['warning'])
        reset_text_rect = reset_text.get_rect(center=reset_rect.center)
        self.screen.blit(reset_text, reset_text_rect)
        
    def get_current_tab_options(self) -> Dict[str, Any]:
        """현재 탭의 옵션들 반환"""
        return self.current_settings.get(self.current_tab, {})
        
    def get_option_display_name(self, key: str) -> str:
        """옵션 표시 이름 반환"""
        display_names = {
            # 사운드
            'master_volume': '마스터 볼륨',
            'music_volume': '음악 볼륨',
            'sfx_volume': '효과음 볼륨',
            'sound_enabled': '사운드 켜기',
            'music_enabled': '음악 켜기',
            # 그래픽
            'fullscreen': '전체화면',
            'vsync': '수직동기화',
            'particle_quality': '파티클 품질',
            'effects_quality': '효과 품질',
            'background_quality': '배경 품질',
            # 컨트롤
            'player1_left': 'P1 왼쪽',
            'player1_right': 'P1 오른쪽',
            'player1_dash': 'P1 대시',
            'player1_skill': 'P1 스킬',
            'player2_left': 'P2 왼쪽',
            'player2_right': 'P2 오른쪽',
            'player2_dash': 'P2 대시',
            'player2_skill': 'P2 스킬',
            'pause': '일시정지',
            'mouse_controls': '마우스 컨트롤',
            # 게임플레이
            'difficulty': '난이도',
            'ai_mode': 'AI 모드',
            'auto_save': '자동 저장',
            'show_hints': '힌트 표시',
            'damage_numbers': '데미지 표시',
            'screen_shake': '화면 흔들림',
            'camera_follow': '카메라 추적',
            # 접근성
            'colorblind_mode': '색맹 모드',
            'high_contrast': '고대비',
            'reduce_motion': '모션 감소',
            'larger_text': '큰 텍스트',
            'screen_reader': '스크린 리더'
        }
        return display_names.get(key, key)
        
    def get_value_display(self, key: str, value: Any) -> str:
        """값 표시 문자열 반환"""
        if isinstance(value, bool):
            return "ON" if value else "OFF"
        elif key == 'difficulty':
            difficulty_names = {
                'easy': '쉬움',
                'normal': '보통',
                'hard': '어려움',
                'mythic': '지옥'
            }
            return difficulty_names.get(value, value)
        elif key == 'ai_mode':
            ai_names = {
                'passive': '수동적',
                'adaptive': '적응형',
                'aggressive': '공격적',
                'strategic': '전략적'
            }
            return ai_names.get(value, value)
        elif key in ['particle_quality', 'effects_quality', 'background_quality']:
            quality_names = {
                'low': '낮음',
                'medium': '중간',
                'high': '높음',
                'ultra': '울트라'
            }
            return quality_names.get(value, value)
        elif key == 'colorblind_mode':
            mode_names = {
                'off': '끄기',
                'protanopia': '적색맹',
                'deuteranopia': '녹색맹',
                'tritanopia': '청황색맹'
            }
            return mode_names.get(value, value)
        else:
            return str(value)
            
    def handle_input(self, event: pygame.event.Event) -> bool:
        """입력 처리"""
        if self.editing_control:
            # 키 바인딩 편집 중
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    self.editing_control = None
                else:
                    # 새 키 할당
                    options = self.get_current_tab_options()
                    options[self.editing_control] = event.key
                    self.editing_control = None
                    self.unsaved_changes = True
                return True
                
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                if self.unsaved_changes:
                    # 저장되지 않은 변경사항 경고
                    emit_event(EventType.MENU_CLOSED, {'unsaved': True})
                else:
                    emit_event(EventType.MENU_CLOSED, {})
                return True
                
            elif event.key == pygame.K_TAB:
                # 다음 탭으로 이동
                current_index = self.tabs.index(self.current_tab)
                self.current_tab = self.tabs[(current_index + 1) % len(self.tabs)]
                self.selected_option = 0
                return True
                
            elif event.key == pygame.K_UP:
                # 이전 옵션
                options = self.get_current_tab_options()
                self.selected_option = max(0, self.selected_option - 1)
                return True
                
            elif event.key == pygame.K_DOWN:
                # 다음 옵션
                options = self.get_current_tab_options()
                self.selected_option = min(len(options) - 1, self.selected_option + 1)
                return True
                
            elif event.key in [pygame.K_LEFT, pygame.K_RIGHT]:
                # 값 변경
                self.change_option_value(event.key == pygame.K_RIGHT)
                return True
                
            elif event.key == pygame.K_RETURN:
                # 옵션 선택/토글
                self.toggle_option()
                return True
                
            elif event.key == pygame.K_s and pygame.key.get_mods() & pygame.KMOD_CTRL:
                # Ctrl+S로 저장
                self.save_settings()
                return True
                
        return False
        
    def change_option_value(self, increase: bool):
        """옵션 값 변경"""
        options = self.get_current_tab_options()
        if not options:
            return
            
        keys = list(options.keys())
        if self.selected_option >= len(keys):
            return
            
        key = keys[self.selected_option]
        value = options[key]
        
        if isinstance(value, bool):
            options[key] = not value
        elif isinstance(value, float):
            # 볼륨 조절
            delta = 0.1 if increase else -0.1
            options[key] = max(0.0, min(1.0, value + delta))
        elif isinstance(value, str):
            # 선택 옵션 순환
            if key == 'difficulty':
                difficulties = ['easy', 'normal', 'hard', 'mythic']
                current_index = difficulties.index(value)
                direction = 1 if increase else -1
                options[key] = difficulties[(current_index + direction) % len(difficulties)]
            elif key == 'ai_mode':
                modes = ['passive', 'adaptive', 'aggressive', 'strategic']
                current_index = modes.index(value)
                direction = 1 if increase else -1
                options[key] = modes[(current_index + direction) % len(modes)]
            elif key in ['particle_quality', 'effects_quality', 'background_quality']:
                qualities = ['low', 'medium', 'high', 'ultra']
                current_index = qualities.index(value)
                direction = 1 if increase else -1
                options[key] = qualities[(current_index + direction) % len(qualities)]
                
        self.unsaved_changes = True
        
    def toggle_option(self):
        """옵션 토글/선택"""
        options = self.get_current_tab_options()
        if not options:
            return
            
        keys = list(options.keys())
        if self.selected_option >= len(keys):
            return
            
        key = keys[self.selected_option]
        value = options[key]
        
        if isinstance(value, bool):
            options[key] = not value
            self.unsaved_changes = True
        elif self.current_tab == 'controls' and isinstance(value, int):
            # 키 바인딩 편집 시작
            self.editing_control = key
            
    def get_setting(self, category: str, key: str) -> Any:
        """특정 설정 값 가져오기"""
        return self.current_settings.get(category, {}).get(key)
        
    def set_setting(self, category: str, key: str, value: Any):
        """특정 설정 값 설정"""
        if category not in self.current_settings:
            self.current_settings[category] = {}
        self.current_settings[category][key] = value
        self.unsaved_changes = True