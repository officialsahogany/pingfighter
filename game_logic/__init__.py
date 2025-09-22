"""
게임 로직 모듈
게임의 핵심 로직을 관리하는 모듈들
"""

from .collision_manager import CollisionManager
from .score_manager import ScoreManager
from .round_manager import RoundManager
from .physics_manager import PhysicsManager
from .boss_ai import BossAI
from .skill_system import SkillSystem
from .item_system import ItemSystem
from .game_loop import GameLoop, LegacyHooks, create_game_loop, create_game_vars_adapters

__all__ = [
    'CollisionManager', 
    'ScoreManager', 
    'RoundManager', 
    'PhysicsManager', 
    'BossAI',
    'SkillSystem',
    'ItemSystem',
    'GameLoop',
    'create_game_loop',
    'create_game_vars_adapters',
    'LegacyHooks'
]
