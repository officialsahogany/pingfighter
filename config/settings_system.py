"""
Settings System - 설정 시스템
게임 설정 관리 (키 바인딩, 그래픽, 사운드 등)
"""

import json
import os
import pygame
from typing import Dict, Any, Optional, List, Tuple
from dataclasses import dataclass, asdict
from enum import Enum
from core.events import EventType, emit_event
from core.global_manager import GlobalManager


LANGUAGE_OPTIONS = [
    ("ko", "한국어"),
    ("en", "English"),
    ("ja", "日本語")
]


class SettingCategory(Enum):
    """설정 카테고리"""
    LANGUAGE = "언어"
    CONTROLS = "조작"
    GRAPHICS = "그래픽"
    AUDIO = "오디오"
    GAMEPLAY = "게임플레이"
    NETWORK = "네트워크"


class GraphicsQuality(Enum):
    """그래픽 품질"""
    LOW = ("낮음", 0.5)
    MEDIUM = ("중간", 0.75)
    HIGH = ("높음", 1.0)
    ULTRA = ("최고", 1.25)


@dataclass
class KeyBinding:
    """키 바인딩"""
    action: str
    primary: int  # pygame key code
    secondary: Optional[int] = None
    description: str = ""
    
    def get_key_name(self, key: Optional[int]) -> str:
        """키 이름 반환"""
        if key is None:
            return "없음"
        return pygame.key.name(key).upper()


class SettingsManager:
    """설정 관리자"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        
        # 설정 파일 경로
        self.settings_file = "settings.json"
        
        # 기본 설정
        self.settings = self.get_default_settings()
        
        # 키 바인딩
        self.key_bindings: Dict[str, KeyBinding] = self.get_default_key_bindings()
        
        # 설정 변경 콜백
        self.change_callbacks: Dict[str, List] = {}
        
        # 설정 로드
        self.load_settings()
        
        # 초기 설정 적용
        self.apply_all_settings()
        
    def get_default_settings(self) -> Dict[str, Any]:
        """기본 설정 반환"""
        return {
            # 그래픽 설정
            'graphics': {
                'resolution': (600, 750),
                'fullscreen': False,
                'vsync': True,
                'fps_limit': 60,
                'quality': GraphicsQuality.HIGH.name,
                'particles': True,
                'screen_shake': True,
                'bloom_effect': True,
                'shadows': True,
                'antialiasing': True,
                'show_fps': False
            },
            
            # 오디오 설정
            'audio': {
                'master_volume': 0.8,
                'sfx_volume': 1.0,
                'music_volume': 0.7,
                'ambient_volume': 0.5,
                'mute_all': False,
                'spatial_audio': True,
                'dynamic_music': True
            },
            
            # 게임플레이 설정
            'gameplay': {
                'difficulty': 'normal',
                'auto_save': True,
                'save_interval': 60,  # 초
                'show_hints': True,
                'screen_edge_scroll': False,
                'camera_shake_intensity': 1.0,
                'slow_motion_effect': True,
                'damage_numbers': True,
                'auto_pause_on_focus_loss': True
            },
            
            # 네트워크 설정
            'network': {
                'default_port': 12345,
                'player_name': 'Player',
                'auto_reconnect': True,
                'connection_timeout': 10,
                'ping_limit': 200,  # ms
                'interpolation': True,
                'prediction': True
            },

            # 언어 설정
            'language': {
                'language': LANGUAGE_OPTIONS[0][0]
            },
            
            # 접근성 설정
            'accessibility': {
                'colorblind_mode': 'none',  # none, protanopia, deuteranopia, tritanopia
                'high_contrast': False,
                'reduce_motion': False,
                'larger_text': False,
                'screen_reader': False,
                'subtitles': True
            }
        }
        
    def get_default_key_bindings(self) -> Dict[str, KeyBinding]:
        """기본 키 바인딩 반환"""
        return {
            # 이동
            'move_left': KeyBinding(
                action='move_left',
                primary=pygame.K_LEFT,
                secondary=pygame.K_a,
                description="왼쪽 이동"
            ),
            'move_right': KeyBinding(
                action='move_right',
                primary=pygame.K_RIGHT,
                secondary=pygame.K_d,
                description="오른쪽 이동"
            ),
            
            # 액션
            'dash': KeyBinding(
                action='dash',
                primary=pygame.K_SPACE,
                secondary=pygame.K_LSHIFT,
                description="대시"
            ),
            'special': KeyBinding(
                action='special',
                primary=pygame.K_q,
                secondary=None,
                description="특수 능력"
            ),
            
            # 아이템
            'item_1': KeyBinding(
                action='item_1',
                primary=pygame.K_1,
                secondary=None,
                description="아이템 슬롯 1"
            ),
            'item_2': KeyBinding(
                action='item_2',
                primary=pygame.K_2,
                secondary=None,
                description="아이템 슬롯 2"
            ),
            'item_3': KeyBinding(
                action='item_3',
                primary=pygame.K_3,
                secondary=None,
                description="아이템 슬롯 3"
            ),
            'item_4': KeyBinding(
                action='item_4',
                primary=pygame.K_4,
                secondary=None,
                description="아이템 슬롯 4"
            ),
            'item_5': KeyBinding(
                action='item_5',
                primary=pygame.K_5,
                secondary=None,
                description="아이템 슬롯 5"
            ),
            'item_6': KeyBinding(
                action='item_6',
                primary=pygame.K_6,
                secondary=None,
                description="아이템 슬롯 6"
            ),
            'item_select': KeyBinding(
                action='item_select',
                primary=pygame.K_TAB,
                secondary=None,
                description="아이템 선택"
            ),
            
            # 시스템
            'pause': KeyBinding(
                action='pause',
                primary=pygame.K_ESCAPE,
                secondary=pygame.K_p,
                description="일시정지"
            ),
            'menu': KeyBinding(
                action='menu',
                primary=pygame.K_m,
                secondary=None,
                description="메뉴"
            ),
            'settings': KeyBinding(
                action='settings',
                primary=pygame.K_F1,
                secondary=None,
                description="설정"
            ),
            
            # 디버그
            'debug_menu': KeyBinding(
                action='debug_menu',
                primary=pygame.K_F3,
                secondary=None,
                description="디버그 메뉴"
            ),
            'profiler': KeyBinding(
                action='profiler',
                primary=pygame.K_F7,
                secondary=None,
                description="프로파일러"
            ),
            'screenshot': KeyBinding(
                action='screenshot',
                primary=pygame.K_F12,
                secondary=None,
                description="스크린샷"
            )
        }
        
    def load_settings(self) -> bool:
        """설정 로드
        
        Returns:
            성공 여부
        """
        try:
            if os.path.exists(self.settings_file):
                with open(self.settings_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    
                # 설정 업데이트
                self._deep_update(self.settings, data.get('settings', {}))
                
                # 키 바인딩 로드
                key_bindings_data = data.get('key_bindings', {})
                for action, binding_data in key_bindings_data.items():
                    if action in self.key_bindings:
                        binding = self.key_bindings[action]
                        binding.primary = binding_data.get('primary', binding.primary)
                        binding.secondary = binding_data.get('secondary', binding.secondary)
                        
                print("⚙️ 설정 로드됨")
                return True
                
        except Exception as e:
            print(f"설정 로드 실패 (기본값 사용): {e}")
            
        return False
        
    def save_settings(self) -> bool:
        """설정 저장
        
        Returns:
            성공 여부
        """
        try:
            # 키 바인딩 데이터 준비
            key_bindings_data = {}
            for action, binding in self.key_bindings.items():
                key_bindings_data[action] = {
                    'primary': binding.primary,
                    'secondary': binding.secondary
                }
                
            # 저장 데이터
            save_data = {
                'settings': self.settings,
                'key_bindings': key_bindings_data
            }
            
            # 파일 저장
            with open(self.settings_file, 'w', encoding='utf-8') as f:
                json.dump(save_data, f, indent=2)
                
            print("💾 설정 저장됨")
            return True
            
        except Exception as e:
            print(f"❌ 설정 저장 실패: {e}")
            return False
            
    def _deep_update(self, target: Dict, source: Dict):
        """딕셔너리 깊은 업데이트
        
        Args:
            target: 대상 딕셔너리
            source: 소스 딕셔너리
        """
        for key, value in source.items():
            if key in target:
                if isinstance(target[key], dict) and isinstance(value, dict):
                    self._deep_update(target[key], value)
                else:
                    target[key] = value
                    
    def get_setting(self, category: str, key: str, default: Any = None) -> Any:
        """설정 값 가져오기
        
        Args:
            category: 카테고리
            key: 키
            default: 기본값
            
        Returns:
            설정 값
        """
        if category in self.settings and key in self.settings[category]:
            return self.settings[category][key]
        return default
        
    def set_setting(self, category: str, key: str, value: Any):
        """설정 값 설정
        
        Args:
            category: 카테고리
            key: 키
            value: 값
        """
        if category not in self.settings:
            self.settings[category] = {}
            
        old_value = self.settings[category].get(key)
        self.settings[category][key] = value
        
        # 변경 콜백 호출
        callback_key = f"{category}.{key}"
        if callback_key in self.change_callbacks:
            for callback in self.change_callbacks[callback_key]:
                callback(old_value, value)
                
        # 설정 적용
        self.apply_setting(category, key, value)
        
        # 이벤트 발생
        emit_event(EventType.MENU_OPENED, {
            'type': 'setting_changed',
            'category': category,
            'key': key,
            'value': value
        })
        
    def apply_setting(self, category: str, key: str, value: Any):
        """설정 적용
        
        Args:
            category: 카테고리
            key: 키
            value: 값
        """
        if category == 'graphics':
            self._apply_graphics_setting(key, value)
        elif category == 'audio':
            self._apply_audio_setting(key, value)
        elif category == 'gameplay':
            self._apply_gameplay_setting(key, value)
        elif category == 'language':
            self._apply_language_setting(key, value)
        elif category == 'network':
            self._apply_network_setting(key, value)
            
    def _apply_graphics_setting(self, key: str, value: Any):
        """그래픽 설정 적용"""
        if key == 'resolution':
            # 해상도 변경
            if not self.get_setting('graphics', 'fullscreen'):
                screen = pygame.display.set_mode(value)
                self.global_manager.set('screen', screen)
                self.global_manager.set('WIDTH', value[0])
                self.global_manager.set('HEIGHT', value[1])
                
        elif key == 'fullscreen':
            # 전체화면 토글
            resolution = self.get_setting('graphics', 'resolution')
            if value:
                screen = pygame.display.set_mode(resolution, pygame.FULLSCREEN)
            else:
                screen = pygame.display.set_mode(resolution)
            self.global_manager.set('screen', screen)
            
        elif key == 'fps_limit':
            # FPS 제한
            self.global_manager.set('fps', value)
            
        elif key == 'quality':
            # 그래픽 품질
            quality = GraphicsQuality[value]
            self.global_manager.set('graphics_quality', quality.value[1])
            
        elif key == 'particles':
            # 파티클 효과
            self.global_manager.set('particles_enabled', value)
            
        elif key == 'screen_shake':
            # 화면 흔들림
            self.global_manager.set('screen_shake_enabled', value)
            
    def _apply_audio_setting(self, key: str, value: Any):
        """오디오 설정 적용"""
        from managers.sound_manager import get_sound_manager
        sound_manager = get_sound_manager()
        
        if key == 'master_volume':
            sound_manager.set_master_volume(value)
        elif key == 'sfx_volume':
            sound_manager.set_sfx_volume(value)
        elif key == 'music_volume':
            sound_manager.set_music_volume(value)
        elif key == 'mute_all':
            if value:
                sound_manager.mute()
            else:
                sound_manager.unmute()
                
    def _apply_gameplay_setting(self, key: str, value: Any):
        """게임플레이 설정 적용"""
        if key == 'difficulty':
            self.global_manager.set_setting('difficulty', value)
        elif key == 'auto_save':
            self.global_manager.set_setting('auto_save', value)
        elif key == 'camera_shake_intensity':
            self.global_manager.set('shake_intensity', value)
            
    def _apply_network_setting(self, key: str, value: Any):
        """네트워크 설정 적용"""
        if key == 'player_name':
            self.global_manager.set('player_name', value)
        elif key == 'default_port':
            self.global_manager.set_setting('default_port', value)

    def _apply_language_setting(self, key: str, value: Any):
        """언어 설정 적용"""
        if key == 'language':
            valid_codes = {code for code, _ in LANGUAGE_OPTIONS}
            if value not in valid_codes:
                value = LANGUAGE_OPTIONS[0][0]
            self.settings.setdefault('language', {})['language'] = value
            self.global_manager.set_setting('language', value)
            self.global_manager.set('language', value)

    def apply_all_settings(self):
        """모든 설정 적용"""
        for category, settings in self.settings.items():
            for key, value in settings.items():
                self.apply_setting(category, key, value)
                
    def register_change_callback(self, setting_path: str, callback):
        """설정 변경 콜백 등록
        
        Args:
            setting_path: 설정 경로 (예: "graphics.resolution")
            callback: 콜백 함수
        """
        if setting_path not in self.change_callbacks:
            self.change_callbacks[setting_path] = []
        self.change_callbacks[setting_path].append(callback)
        
    def get_key_binding(self, action: str) -> Optional[KeyBinding]:
        """키 바인딩 가져오기
        
        Args:
            action: 액션
            
        Returns:
            키 바인딩 또는 None
        """
        return self.key_bindings.get(action)
        
    def set_key_binding(self, action: str, primary: Optional[int] = None, 
                       secondary: Optional[int] = None):
        """키 바인딩 설정
        
        Args:
            action: 액션
            primary: 주 키
            secondary: 보조 키
        """
        if action in self.key_bindings:
            binding = self.key_bindings[action]
            if primary is not None:
                binding.primary = primary
            if secondary is not None:
                binding.secondary = secondary
                
    def is_key_pressed(self, action: str, key: int) -> bool:
        """키가 액션에 바인딩되어 있는지 확인
        
        Args:
            action: 액션
            key: 키 코드
            
        Returns:
            바인딩 여부
        """
        binding = self.key_bindings.get(action)
        if binding:
            return key == binding.primary or key == binding.secondary
        return False
        
    def get_action_for_key(self, key: int) -> Optional[str]:
        """키에 해당하는 액션 반환
        
        Args:
            key: 키 코드
            
        Returns:
            액션 이름 또는 None
        """
        for action, binding in self.key_bindings.items():
            if key == binding.primary or key == binding.secondary:
                return action
        return None
        
    def reset_to_defaults(self, category: Optional[str] = None):
        """기본값으로 리셋
        
        Args:
            category: 카테고리 (None이면 전체)
        """
        default_settings = self.get_default_settings()
        
        if category:
            if category in default_settings:
                self.settings[category] = default_settings[category].copy()
        else:
            self.settings = default_settings
            self.key_bindings = self.get_default_key_bindings()
            
        self.apply_all_settings()
        
    def export_settings(self, filepath: str) -> bool:
        """설정 내보내기
        
        Args:
            filepath: 파일 경로
            
        Returns:
            성공 여부
        """
        try:
            # 키 바인딩 데이터 준비
            key_bindings_data = {}
            for action, binding in self.key_bindings.items():
                key_bindings_data[action] = {
                    'action': binding.action,
                    'primary': binding.primary,
                    'secondary': binding.secondary,
                    'description': binding.description
                }
                
            export_data = {
                'version': '1.0.0',
                'settings': self.settings,
                'key_bindings': key_bindings_data
            }
            
            with open(filepath, 'w', encoding='utf-8') as f:
                json.dump(export_data, f, indent=2)
                
            return True
            
        except Exception as e:
            print(f"설정 내보내기 실패: {e}")
            return False
            
    def import_settings(self, filepath: str) -> bool:
        """설정 가져오기
        
        Args:
            filepath: 파일 경로
            
        Returns:
            성공 여부
        """
        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                import_data = json.load(f)
                
            # 버전 체크
            version = import_data.get('version', '0.0.0')
            if version != '1.0.0':
                print(f"경고: 설정 버전 불일치 ({version})")
                
            # 설정 가져오기
            self._deep_update(self.settings, import_data.get('settings', {}))
            
            # 키 바인딩 가져오기
            key_bindings_data = import_data.get('key_bindings', {})
            for action, binding_data in key_bindings_data.items():
                if action not in self.key_bindings:
                    self.key_bindings[action] = KeyBinding(
                        action=binding_data['action'],
                        primary=binding_data['primary'],
                        secondary=binding_data.get('secondary'),
                        description=binding_data.get('description', '')
                    )
                else:
                    binding = self.key_bindings[action]
                    binding.primary = binding_data['primary']
                    binding.secondary = binding_data.get('secondary')
                    
            self.apply_all_settings()
            return True
            
        except Exception as e:
            print(f"설정 가져오기 실패: {e}")
            return False


# 싱글톤 인스턴스
_settings_manager = None

def get_settings_manager() -> SettingsManager:
    """설정 매니저 싱글톤 반환"""
    global _settings_manager
    if _settings_manager is None:
        _settings_manager = SettingsManager()
    return _settings_manager
