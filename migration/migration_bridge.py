# -*- coding: utf-8 -*-
"""
마이그레이션 브리지
기존 pingfighter.py와 새 아키텍처를 연결하는 브리지 모듈
"""

import sys
import os
from typing import Dict, Any, Optional

# 프로젝트 경로 추가
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.game_state import GameState
from core.dependency_injection import DIContainer, get_container
from core.event_bus import EventBus, Event, GameEvents, get_event_bus
from services.game_service import GameService
from repositories.game_repository import GameRepository


class MigrationBridge:
    """레거시 코드와 새 아키텍처를 연결하는 브리지
    
    이 클래스는 점진적 마이그레이션을 위해
    기존 전역 변수와 새로운 시스템을 동기화합니다.
    """
    
    def __init__(self):
        """브리지 초기화"""
        self.game_state = GameState.get_instance()
        self.container = get_container()
        self.event_bus = get_event_bus()
        self.legacy_globals = {}
        
        # 새 시스템 초기화
        self._init_new_systems()
        
    def _init_new_systems(self):
        """새 시스템 초기화 및 DI 컨테이너 설정"""
        # 서비스 등록
        self.container.register_singleton(GameState)
        self.container.register_singleton(EventBus)
        self.container.register_singleton(GameRepository)
        self.container.register_singleton(GameService)
        
        # 서비스 인스턴스 획득
        self.game_service = self.container.resolve(GameService)
        self.repository = self.container.resolve(GameRepository)
    
    def sync_globals_to_state(self, globals_dict: Dict[str, Any]):
        """전역 변수를 GameState로 동기화
        
        Args:
            globals_dict: pingfighter.py의 전역 변수 딕셔너리
        """
        # 중요한 전역 변수 매핑
        mapping = {
            # 게임 상태
            'game_running': 'game_running',
            'game_paused': 'game_paused',
            'current_stage': 'current_stage',
            'ai_mode': 'ai_mode',
            
            # 점수
            'player_score': 'player_score',
            'ai_score': 'ai_score',
            'round_wins': 'round_wins',
            'round_losses': 'round_losses',
            'medal_score': 'medal_score',
            
            # 플레이어
            'player_x': 'player_x',
            'player_y': 'player_y',
            'player_width': 'player_width',
            'player_height': 'player_height',
            'player_speed': 'player_speed',
            
            # 보스
            'boss_x': 'boss_x',
            'boss_y': 'boss_y',
            'boss_width': 'boss_width',
            'boss_height': 'boss_height',
            'boss_speed': 'boss_speed',
            'boss_health': 'boss_health',
            
            # 공
            'ball_x': 'ball_x',
            'ball_y': 'ball_y',
            'ball_speed_x': 'ball_speed_x',
            'ball_speed_y': 'ball_speed_y',
            'ball_radius': 'ball_radius',
            
            # 특수 능력
            'special_gauge': 'special_gauge',
            'special_ready': 'special_ready',
            'special_active': 'special_active',
            
            # 대시
            'dash_charges': 'dash_charges',
            'dash_active': 'dash_active',
            'dash_timer': 'dash_timer',
            
            # 아이템 상태
            'speedboots_obtained': 'speedboots_obtained',
            'speedgear_obtained': 'speedgear_obtained',
            'battery_obtained': 'battery_obtained',
            'revival_obtained': 'revival_obtained',
            'revival_used': 'revival_used',
        }
        
        # 전역 변수를 GameState로 복사
        for global_name, state_attr in mapping.items():
            if global_name in globals_dict:
                setattr(self.game_state, state_attr, globals_dict[global_name])
        
        # 레거시 전역 변수 저장
        self.legacy_globals = globals_dict
    
    def sync_state_to_globals(self, globals_dict: Dict[str, Any]):
        """GameState를 전역 변수로 동기화
        
        Args:
            globals_dict: 업데이트할 전역 변수 딕셔너리
        """
        # GameState 값을 전역 변수로 복사
        mapping = {
            'game_running': 'game_running',
            'game_paused': 'game_paused',
            'current_stage': 'current_stage',
            'player_score': 'player_score',
            'ai_score': 'ai_score',
            'player_x': 'player_x',
            'player_y': 'player_y',
            'ball_x': 'ball_x',
            'ball_y': 'ball_y',
            'ball_speed_x': 'ball_speed_x',
            'ball_speed_y': 'ball_speed_y',
            'special_gauge': 'special_gauge',
            'dash_charges': 'dash_charges',
        }
        
        for state_attr, global_name in mapping.items():
            if hasattr(self.game_state, state_attr):
                globals_dict[global_name] = getattr(self.game_state, state_attr)
    
    def wrap_legacy_function(self, func_name: str, func):
        """레거시 함수를 새 시스템과 연결
        
        Args:
            func_name: 함수 이름
            func: 래핑할 함수
            
        Returns:
            래핑된 함수
        """
        def wrapped(*args, **kwargs):
            # 함수 실행 전 이벤트
            self.event_bus.publish(Event(
                type=f'legacy.{func_name}.before',
                data={'args': args, 'kwargs': kwargs}
            ))
            
            # 원본 함수 실행
            result = func(*args, **kwargs)
            
            # 함수 실행 후 이벤트
            self.event_bus.publish(Event(
                type=f'legacy.{func_name}.after',
                data={'result': result}
            ))
            
            return result
        
        return wrapped
    
    def migrate_event_handler(self, pygame_event):
        """Pygame 이벤트를 새 이벤트 시스템으로 변환
        
        Args:
            pygame_event: Pygame 이벤트 객체
        """
        import pygame
        
        # 키 이벤트 매핑
        if pygame_event.type == pygame.KEYDOWN:
            if pygame_event.key == pygame.K_LEFT:
                self.game_service.process_player_input({'move': -1})
            elif pygame_event.key == pygame.K_RIGHT:
                self.game_service.process_player_input({'move': 1})
            elif pygame_event.key == pygame.K_SPACE:
                self.game_service.process_player_input({'dash': True})
            elif pygame_event.key == pygame.K_z:
                self.game_service.process_player_input({'special': True})
    
    def migrate_update_logic(self, dt: float):
        """업데이트 로직을 새 시스템으로 마이그레이션
        
        Args:
            dt: 델타 시간
        """
        # 새 시스템 업데이트
        self.game_service.update(dt)
        
        # 상태 동기화
        self.sync_state_to_globals(self.legacy_globals)
    
    def is_ready_for_full_migration(self) -> bool:
        """완전 마이그레이션 준비 상태 확인
        
        Returns:
            준비 완료 여부
        """
        checks = {
            'game_state': self.game_state is not None,
            'container': self.container is not None,
            'event_bus': self.event_bus is not None,
            'game_service': hasattr(self, 'game_service'),
            'repository': hasattr(self, 'repository'),
        }
        
        ready = all(checks.values())
        
        if not ready:
            print("마이그레이션 준비 상태:")
            for check, status in checks.items():
                print(f"  {check}: {'✓' if status else '✗'}")
        
        return ready


# 전역 브리지 인스턴스
_migration_bridge = None


def get_migration_bridge() -> MigrationBridge:
    """마이그레이션 브리지 싱글톤 반환"""
    global _migration_bridge
    if _migration_bridge is None:
        _migration_bridge = MigrationBridge()
    return _migration_bridge


def init_migration(globals_dict: Dict[str, Any]):
    """마이그레이션 초기화
    
    Args:
        globals_dict: pingfighter.py의 전역 변수
    """
    bridge = get_migration_bridge()
    bridge.sync_globals_to_state(globals_dict)
    
    print("="*50)
    print("마이그레이션 브리지 초기화 완료")
    print("- GameState 동기화: ✓")
    print("- DI 컨테이너 설정: ✓")
    print("- 이벤트 버스 준비: ✓")
    print("- 서비스 레이어 활성: ✓")
    print("="*50)
    
    return bridge