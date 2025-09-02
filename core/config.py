"""
게임 설정 관리 모듈
"""
import pygame
from .constants import *

class GameConfig:
    """게임 설정 관리 클래스"""
    
    def __init__(self):
        self.fullscreen = False
        self.sound_enabled = True
        self.music_volume = 0.7
        self.sfx_volume = 0.8
        self.difficulty = "normal"
        self.language = "ko"
        
        # 스테이지 설정
        self.current_stage = 1
        self.max_stages = 6
        
        # 플레이어 설정
        self.player_name = "Player"
        self.player_color = WHITE
        
        # AI 설정
        self.ai_difficulty = 1.0
        self.ai_reaction_time = 5
        
    def save_config(self, filepath="config.json"):
        """설정을 파일로 저장"""
        import json
        config_data = {
            'fullscreen': self.fullscreen,
            'sound_enabled': self.sound_enabled,
            'music_volume': self.music_volume,
            'sfx_volume': self.sfx_volume,
            'difficulty': self.difficulty,
            'language': self.language
        }
        with open(filepath, 'w') as f:
            json.dump(config_data, f, indent=2)
    
    def load_config(self, filepath="config.json"):
        """파일에서 설정 로드"""
        import json
        try:
            with open(filepath, 'r') as f:
                config_data = json.load(f)
                for key, value in config_data.items():
                    if hasattr(self, key):
                        setattr(self, key, value)
        except FileNotFoundError:
            pass  # 기본 설정 사용
            
# 전역 설정 인스턴스
game_config = GameConfig()