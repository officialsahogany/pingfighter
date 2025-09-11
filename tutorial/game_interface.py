"""
게임 인터페이스 모듈
튜토리얼 시스템과 메인 게임 간의 인터페이스를 정의
"""

from abc import ABC, abstractmethod
from typing import Tuple, Optional, Dict, Any
import pygame


class GameInterface(ABC):
    """게임과 튜토리얼 간의 인터페이스 추상 클래스"""
    
    @abstractmethod
    def get_screen(self) -> pygame.Surface:
        """게임 화면 Surface 반환"""
        pass
    
    @abstractmethod
    def get_screen_dimensions(self) -> Tuple[int, int]:
        """화면 크기 반환 (width, height)"""
        pass
    
    @abstractmethod
    def get_ball_position(self) -> Tuple[float, float]:
        """공 위치 반환 (x, y)"""
        pass
    
    @abstractmethod
    def set_ball_position(self, x: float, y: float) -> None:
        """공 위치 설정"""
        pass
    
    @abstractmethod
    def get_ball_velocity(self) -> Tuple[float, float]:
        """공 속도 반환 (dx, dy)"""
        pass
    
    @abstractmethod
    def set_ball_velocity(self, dx: float, dy: float) -> None:
        """공 속도 설정"""
        pass
    
    @abstractmethod
    def get_ball_speed(self) -> float:
        """공 속력 반환"""
        pass
    
    @abstractmethod
    def set_ball_speed(self, speed: float) -> None:
        """공 속력 설정"""
        pass
    
    @abstractmethod
    def get_player_position(self) -> Tuple[float, float]:
        """플레이어 패들 위치 반환"""
        pass
    
    @abstractmethod
    def set_player_position(self, x: float, y: float) -> None:
        """플레이어 패들 위치 설정"""
        pass
    
    @abstractmethod
    def get_special_gauge(self) -> float:
        """특수 게이지 값 반환"""
        pass
    
    @abstractmethod
    def set_special_gauge(self, value: float) -> None:
        """특수 게이지 값 설정"""
        pass
    
    @abstractmethod
    def get_rolling_charges(self) -> int:
        """대쉬 토큰 개수 반환"""
        pass
    
    @abstractmethod
    def set_rolling_charges(self, charges: int) -> None:
        """대쉬 토큰 개수 설정"""
        pass
    
    @abstractmethod
    def get_font(self, size: int) -> pygame.font.Font:
        """지정된 크기의 폰트 반환"""
        pass
    
    @abstractmethod
    def play_sound(self, sound_name: str) -> None:
        """사운드 재생"""
        pass
    
    @abstractmethod
    def get_game_state(self) -> Dict[str, Any]:
        """현재 게임 상태 딕셔너리 반환"""
        pass
    
    @abstractmethod
    def set_game_state(self, state: Dict[str, Any]) -> None:
        """게임 상태 설정"""
        pass
    
    @abstractmethod
    def is_serving(self) -> bool:
        """서브 상태 여부 반환"""
        pass
    
    @abstractmethod
    def start_serve(self, player: str = "player") -> None:
        """서브 시작"""
        pass
    
    @abstractmethod
    def handle_player_input(self, action: str, params: Optional[Dict] = None) -> None:
        """플레이어 입력 처리"""
        pass
    
    @abstractmethod
    def pause_game(self) -> None:
        """게임 일시정지"""
        pass
    
    @abstractmethod
    def resume_game(self) -> None:
        """게임 재개"""
        pass
    
    @abstractmethod
    def reset_game_state(self) -> None:
        """게임 상태 초기화"""
        pass


class GameInterfaceImpl(GameInterface):
    """
    실제 게임과 연결되는 GameInterface 구현체
    pingfighter.py의 전역 변수들과 연결
    """
    
    def __init__(self, globals_dict: Dict[str, Any]):
        """
        Args:
            globals_dict: pingfighter.py의 globals() 딕셔너리
        """
        self.g = globals_dict
        
    def get_screen(self) -> pygame.Surface:
        return self.g.get('SCREEN')
    
    def get_screen_dimensions(self) -> Tuple[int, int]:
        return self.g.get('WIDTH', 1024), self.g.get('HEIGHT', 768)
    
    def get_ball_position(self) -> Tuple[float, float]:
        return self.g.get('ball_x', 0), self.g.get('ball_y', 0)
    
    def set_ball_position(self, x: float, y: float) -> None:
        self.g['ball_x'] = x
        self.g['ball_y'] = y
    
    def get_ball_velocity(self) -> Tuple[float, float]:
        return self.g.get('ball_dx', 0), self.g.get('ball_dy', 0)
    
    def set_ball_velocity(self, dx: float, dy: float) -> None:
        self.g['ball_dx'] = dx
        self.g['ball_dy'] = dy
    
    def get_ball_speed(self) -> float:
        return self.g.get('ball_speed', 5.0)
    
    def set_ball_speed(self, speed: float) -> None:
        self.g['ball_speed'] = speed
    
    def get_player_position(self) -> Tuple[float, float]:
        player_x = self.g.get('player_x', 50)
        player_y = self.g.get('player_y', 384)
        return player_x, player_y
    
    def set_player_position(self, x: float, y: float) -> None:
        self.g['player_x'] = x
        self.g['player_y'] = y
    
    def get_special_gauge(self) -> float:
        return self.g.get('special_gauge', 0)
    
    def set_special_gauge(self, value: float) -> None:
        self.g['special_gauge'] = value
        self.g['displayed_gauge'] = value
    
    def get_rolling_charges(self) -> int:
        return self.g.get('rolling_charges', 1)
    
    def set_rolling_charges(self, charges: int) -> None:
        self.g['rolling_charges'] = charges
    
    def get_font(self, size: int) -> pygame.font.Font:
        get_font_func = self.g.get('get_font')
        if get_font_func:
            return get_font_func(size)
        return pygame.font.Font(None, size)
    
    def play_sound(self, sound_name: str) -> None:
        sound_dict = self.g.get('SOUNDS', {})
        if sound_name in sound_dict:
            sound_dict[sound_name].play()
    
    def get_game_state(self) -> Dict[str, Any]:
        return {
            'ball_x': self.g.get('ball_x', 0),
            'ball_y': self.g.get('ball_y', 0),
            'ball_dx': self.g.get('ball_dx', 0),
            'ball_dy': self.g.get('ball_dy', 0),
            'ball_speed': self.g.get('ball_speed', 5.0),
            'player_x': self.g.get('player_x', 50),
            'player_y': self.g.get('player_y', 384),
            'special_gauge': self.g.get('special_gauge', 0),
            'rolling_charges': self.g.get('rolling_charges', 1),
            'current_stage': self.g.get('current_stage', 0),
            'is_serving': self.g.get('is_serving', False),
        }
    
    def set_game_state(self, state: Dict[str, Any]) -> None:
        for key, value in state.items():
            if key in self.g:
                self.g[key] = value
    
    def is_serving(self) -> bool:
        return self.g.get('is_serving', False)
    
    def start_serve(self, player: str = "player") -> None:
        self.g['is_serving'] = True
        self.g['serve_player'] = player
        
    def handle_player_input(self, action: str, params: Optional[Dict] = None) -> None:
        """플레이어 입력 시뮬레이션"""
        if action == "dash":
            if self.g.get('handle_dash'):
                self.g['handle_dash']()
        elif action == "half_dash":
            if self.g.get('handle_half_dash'):
                self.g['handle_half_dash']()
        elif action == "power_smash":
            if self.g.get('handle_power_smash'):
                self.g['handle_power_smash']()
    
    def pause_game(self) -> None:
        self.g['game_paused'] = True
    
    def resume_game(self) -> None:
        self.g['game_paused'] = False
    
    def reset_game_state(self) -> None:
        """게임 상태를 기본값으로 초기화"""
        self.g['ball_x'] = self.g.get('WIDTH', 1024) // 2
        self.g['ball_y'] = self.g.get('HEIGHT', 768) // 2
        self.g['ball_dx'] = 0
        self.g['ball_dy'] = 0
        self.g['ball_speed'] = 5.0
        self.g['special_gauge'] = 0
        self.g['displayed_gauge'] = 0
        self.g['rolling_charges'] = 1