# Downtown System - 행성 번화가 시스템
# PingFighter의 로그라이크 스타일 탐험 모드

"""
번화가 시스템 구조:
- DowntownManager: 전체 번화가 시스템 관리
- DowntownMap: 랜덤 맵 생성 및 타일 관리
- DowntownPlayer: 플레이어 캐릭터 이동/상호작용
- DowntownBuilding: 이벤트 건물 (도박장, 콜로세움 등)
- DowntownNPC: NPC 캐릭터들
- ActionPointSystem: 행동 포인트 관리
"""

from .manager import DowntownManager
from .map_generator import DowntownMap
from .player import DowntownPlayer
from .buildings import BuildingManager
from .action_points import ActionPointSystem
from .renderer import DowntownRenderer
from .npc import NPCManager, NPC, NPCType

__all__ = [
    'DowntownManager',
    'DowntownMap',
    'DowntownPlayer',
    'BuildingManager',
    'ActionPointSystem',
    'DowntownRenderer',
    'NPCManager',
    'NPC',
    'NPCType'
]
