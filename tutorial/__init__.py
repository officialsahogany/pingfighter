"""
튜토리얼 시스템 모듈
PingFighter 게임의 튜토리얼 기능을 모듈화한 패키지
"""

from .manager import TutorialManager
from .state import TutorialState
from .game_interface import GameInterface

# 공개 API
__all__ = [
    'TutorialManager',
    'TutorialState', 
    'GameInterface',
    'create_tutorial_manager'
]

def create_tutorial_manager(game_interface):
    """
    튜토리얼 매니저 생성 팩토리 함수
    
    Args:
        game_interface: 게임과의 인터페이스 객체
        
    Returns:
        TutorialManager: 초기화된 튜토리얼 매니저
    """
    return TutorialManager(game_interface)