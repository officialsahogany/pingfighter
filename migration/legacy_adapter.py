# -*- coding: utf-8 -*-
"""
레거시 어댑터
기존 pingfighter.py 코드를 새 아키텍처에 점진적으로 통합
"""

import pygame
import sys
from typing import Dict, Any, Callable, Optional
from functools import wraps

from core.game_state import GameState
from core.event_bus import get_event_bus, Event
from services.game_service import GameService


class LegacyAdapter:
    """레거시 코드 어댑터
    
    기존 전역 함수들을 새 시스템의 메서드로 변환합니다.
    """
    
    def __init__(self):
        self.game_state = GameState.get_instance()
        self.event_bus = get_event_bus()
        self.legacy_functions = {}
        self.migrated_functions = {}
        
    def register_legacy_function(self, name: str, func: Callable):
        """레거시 함수 등록
        
        Args:
            name: 함수 이름
            func: 레거시 함수
        """
        self.legacy_functions[name] = func
        
    def migrate_function(self, old_name: str, new_method: Callable):
        """함수를 새 메서드로 마이그레이션
        
        Args:
            old_name: 기존 함수 이름
            new_method: 새 시스템의 메서드
        """
        @wraps(new_method)
        def migrated_wrapper(*args, **kwargs):
            # 마이그레이션 로그
            print(f"[Migration] {old_name} -> {new_method.__name__}")
            
            # 새 메서드 실행
            result = new_method(*args, **kwargs)
            
            # 이벤트 발행
            self.event_bus.publish(Event(
                type='migration.function_called',
                data={'old': old_name, 'new': new_method.__name__}
            ))
            
            return result
        
        self.migrated_functions[old_name] = migrated_wrapper
        return migrated_wrapper
    
    def create_global_variable_proxy(self):
        """전역 변수 프록시 생성
        
        Returns:
            전역 변수를 GameState로 매핑하는 프록시 객체
        """
        class GlobalProxy:
            def __init__(self, game_state):
                self._game_state = game_state
                
            def __getattr__(self, name):
                return getattr(self._game_state, name)
                
            def __setattr__(self, name, value):
                if name.startswith('_'):
                    super().__setattr__(name, value)
                else:
                    setattr(self._game_state, name, value)
        
        return GlobalProxy(self.game_state)


class MigrationPlan:
    """마이그레이션 계획 관리"""
    
    def __init__(self):
        self.phases = {
            'phase1': {
                'name': '핵심 시스템 마이그레이션',
                'tasks': [
                    'GameState 전역 변수 통합',
                    '이벤트 시스템 연결',
                    'DI 컨테이너 설정'
                ],
                'completed': []
            },
            'phase2': {
                'name': '게임 로직 마이그레이션',
                'tasks': [
                    '충돌 시스템 분리',
                    '물리 엔진 모듈화',
                    'AI 시스템 분리'
                ],
                'completed': []
            },
            'phase3': {
                'name': 'UI/렌더링 마이그레이션',
                'tasks': [
                    'HUD 시스템 분리',
                    '메뉴 시스템 모듈화',
                    '이펙트 시스템 분리'
                ],
                'completed': []
            },
            'phase4': {
                'name': '최종 정리',
                'tasks': [
                    '레거시 코드 제거',
                    '테스트 작성',
                    '문서화'
                ],
                'completed': []
            }
        }
        
    def complete_task(self, phase: str, task: str):
        """작업 완료 표시"""
        if phase in self.phases and task in self.phases[phase]['tasks']:
            if task not in self.phases[phase]['completed']:
                self.phases[phase]['completed'].append(task)
                
    def get_progress(self) -> Dict[str, float]:
        """진행률 조회"""
        progress = {}
        for phase_id, phase_data in self.phases.items():
            total = len(phase_data['tasks'])
            completed = len(phase_data['completed'])
            progress[phase_id] = (completed / total * 100) if total > 0 else 0
        return progress
    
    def print_status(self):
        """현재 상태 출력"""
        print("\n" + "="*60)
        print("📊 마이그레이션 진행 상황")
        print("="*60)
        
        for phase_id, phase_data in self.phases.items():
            progress = self.get_progress()[phase_id]
            print(f"\n{phase_data['name']} ({progress:.1f}%)")
            
            for task in phase_data['tasks']:
                status = "✅" if task in phase_data['completed'] else "⏳"
                print(f"  {status} {task}")
        
        total_progress = sum(self.get_progress().values()) / len(self.phases)
        print(f"\n전체 진행률: {total_progress:.1f}%")
        print("="*60)


def migrate_global_variables(globals_dict: Dict[str, Any]) -> Dict[str, Any]:
    """전역 변수를 GameState로 마이그레이션
    
    Args:
        globals_dict: pingfighter.py의 전역 변수
        
    Returns:
        마이그레이션된 변수 매핑
    """
    game_state = GameState.get_instance()
    adapter = LegacyAdapter()
    proxy = adapter.create_global_variable_proxy()
    
    # 중요 전역 변수 매핑
    variable_mapping = {
        # 게임 상태
        'game_running': 'game_running',
        'game_paused': 'game_paused',
        'current_stage': 'current_stage',
        
        # 점수
        'player_score': 'player_score',
        'ai_score': 'ai_score',
        'round_wins': 'round_wins',
        'round_losses': 'round_losses',
        
        # 플레이어
        'player_x': 'player_x',
        'player_y': 'player_y',
        'player_width': 'player_width',
        'player_height': 'player_height',
        
        # 공
        'ball_x': 'ball_x',
        'ball_y': 'ball_y',
        'ball_speed_x': 'ball_speed_x',
        'ball_speed_y': 'ball_speed_y',
        
        # 특수
        'special_gauge': 'special_gauge',
        'dash_charges': 'dash_charges',
    }
    
    migrated = {}
    
    for old_name, new_name in variable_mapping.items():
        if old_name in globals_dict:
            # GameState로 값 복사
            setattr(game_state, new_name, globals_dict[old_name])
            
            # 프록시를 통해 접근 가능하도록 설정
            migrated[old_name] = proxy
            
            print(f"✓ Migrated: {old_name} -> GameState.{new_name}")
    
    return migrated


def create_migration_wrapper(legacy_func: Callable, service_method: Callable):
    """레거시 함수를 서비스 메서드로 래핑
    
    Args:
        legacy_func: 기존 함수
        service_method: 새 서비스 메서드
        
    Returns:
        래핑된 함수
    """
    @wraps(legacy_func)
    def wrapper(*args, **kwargs):
        # 서비스 메서드 호출
        try:
            result = service_method(*args, **kwargs)
            return result
        except Exception as e:
            # 실패 시 레거시 함수 폴백
            print(f"⚠️ Migration failed, falling back: {e}")
            return legacy_func(*args, **kwargs)
    
    return wrapper


class IncrementalMigrator:
    """점진적 마이그레이션 관리자"""
    
    def __init__(self, legacy_module):
        """초기화
        
        Args:
            legacy_module: pingfighter 모듈
        """
        self.legacy_module = legacy_module
        self.adapter = LegacyAdapter()
        self.plan = MigrationPlan()
        self.game_service = GameService()
        
    def start_migration(self):
        """마이그레이션 시작"""
        print("\n🚀 점진적 마이그레이션 시작...")
        
        # Phase 1: 전역 변수 마이그레이션
        self._migrate_global_variables()
        
        # Phase 2: 핵심 함수 마이그레이션
        self._migrate_core_functions()
        
        # Phase 3: 이벤트 시스템 연결
        self._connect_event_systems()
        
        # 진행 상황 출력
        self.plan.print_status()
        
    def _migrate_global_variables(self):
        """전역 변수 마이그레이션"""
        print("\n📦 전역 변수 마이그레이션 중...")
        
        legacy_globals = vars(self.legacy_module)
        migrated = migrate_global_variables(legacy_globals)
        
        # 원본 모듈의 전역 변수를 프록시로 교체
        for name, proxy in migrated.items():
            setattr(self.legacy_module, name, proxy)
        
        self.plan.complete_task('phase1', 'GameState 전역 변수 통합')
        
    def _migrate_core_functions(self):
        """핵심 함수 마이그레이션"""
        print("\n🔧 핵심 함수 마이그레이션 중...")
        
        # 함수 매핑
        function_mappings = {
            'start_game': self.game_service.start_game,
            'pause_game': self.game_service.pause_game,
            'resume_game': self.game_service.resume_game,
            'process_player_input': self.game_service.process_player_input,
        }
        
        for func_name, service_method in function_mappings.items():
            if hasattr(self.legacy_module, func_name):
                legacy_func = getattr(self.legacy_module, func_name)
                wrapped = create_migration_wrapper(legacy_func, service_method)
                setattr(self.legacy_module, func_name, wrapped)
                print(f"✓ Migrated function: {func_name}")
        
    def _connect_event_systems(self):
        """이벤트 시스템 연결"""
        print("\n🔌 이벤트 시스템 연결 중...")
        
        event_bus = get_event_bus()
        
        # Pygame 이벤트를 새 이벤트 버스로 브리지
        def event_bridge(pygame_event):
            if pygame_event.type == pygame.KEYDOWN:
                event_bus.publish(Event(
                    type='input.key',
                    data={'key': pygame_event.key}
                ))
        
        # 원본 이벤트 핸들러 래핑
        if hasattr(self.legacy_module, 'handle_events'):
            original_handler = self.legacy_module.handle_events
            
            def wrapped_handler(*args, **kwargs):
                result = original_handler(*args, **kwargs)
                # 이벤트 브리지 실행
                for event in pygame.event.get():
                    event_bridge(event)
                return result
            
            self.legacy_module.handle_events = wrapped_handler
        
        self.plan.complete_task('phase1', '이벤트 시스템 연결')
        
    def get_migration_status(self) -> Dict[str, Any]:
        """마이그레이션 상태 조회"""
        return {
            'progress': self.plan.get_progress(),
            'phases': self.plan.phases,
            'adapter_stats': {
                'legacy_functions': len(self.adapter.legacy_functions),
                'migrated_functions': len(self.adapter.migrated_functions)
            }
        }