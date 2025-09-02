"""
Legacy Bridge - 레거시 브리지
bosspong.py와 main.py를 연결하는 브리지 모듈
점진적 마이그레이션을 위한 인터페이스
"""

import pygame
import sys
from typing import Optional, Dict, Any
from core.global_manager import GlobalManager
from core.events import EventType, emit_event


class LegacyBridge:
    """레거시 코드 브리지"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        self.legacy_game = None
        self.is_legacy_mode = False
        
    def initialize_legacy_game(self):
        """레거시 게임 초기화"""
        try:
            # bosspong 모듈 동적 임포트
            import bosspong
            self.legacy_game = bosspong
            self.is_legacy_mode = True
            print("🔗 레거시 브리지 초기화 완료")
            return True
        except Exception as e:
            print(f"❌ 레거시 게임 로드 실패: {e}")
            return False
            
    def run_legacy_game(self, stage: int = 1, new_boss_mode: bool = False):
        """레거시 게임 실행
        
        Args:
            stage: 스테이지 번호
            new_boss_mode: 새 보스 모드 여부
        """
        if not self.legacy_game:
            print("❌ 레거시 게임이 초기화되지 않았습니다")
            return
            
        try:
            # 레거시 main 함수 호출
            self.legacy_game.main(stage, new_boss_mode)
        except Exception as e:
            print(f"❌ 레거시 게임 실행 오류: {e}")
            
    def sync_with_legacy(self):
        """레거시 게임과 상태 동기화"""
        if not self.legacy_game:
            return
            
        try:
            # 레거시 게임의 주요 변수들을 GlobalManager와 동기화
            
            # 점수 동기화
            if hasattr(self.legacy_game, 'player_score'):
                self.global_manager.set('player_score', self.legacy_game.player_score)
            if hasattr(self.legacy_game, 'boss_score'):
                self.global_manager.set('boss_score', self.legacy_game.boss_score)
                
            # 오브젝트 위치 동기화
            if hasattr(self.legacy_game, 'BALL'):
                self.global_manager.set('BALL', self.legacy_game.BALL)
            if hasattr(self.legacy_game, 'PLAYER'):
                self.global_manager.set('PLAYER', self.legacy_game.PLAYER)
            if hasattr(self.legacy_game, 'BOSS'):
                self.global_manager.set('BOSS', self.legacy_game.BOSS)
                
            # 공 속도 동기화
            if hasattr(self.legacy_game, 'ball_dx'):
                self.global_manager.set('ball_dx', self.legacy_game.ball_dx)
            if hasattr(self.legacy_game, 'ball_dy'):
                self.global_manager.set('ball_dy', self.legacy_game.ball_dy)
                
        except Exception as e:
            print(f"동기화 오류: {e}")
            
    def migrate_function(self, func_name: str, module_name: str):
        """레거시 함수를 새 모듈로 마이그레이션
        
        Args:
            func_name: 함수 이름
            module_name: 대상 모듈 이름
        """
        if not self.legacy_game or not hasattr(self.legacy_game, func_name):
            print(f"❌ 함수 {func_name}을 찾을 수 없습니다")
            return False
            
        try:
            # 동적으로 모듈 임포트
            module = __import__(module_name, fromlist=[''])
            
            # 함수 복사
            legacy_func = getattr(self.legacy_game, func_name)
            setattr(module, func_name, legacy_func)
            
            print(f"✅ {func_name} → {module_name} 마이그레이션 완료")
            return True
            
        except Exception as e:
            print(f"❌ 마이그레이션 실패: {e}")
            return False
            
    def get_legacy_value(self, var_name: str, default: Any = None) -> Any:
        """레거시 변수 값 가져오기
        
        Args:
            var_name: 변수 이름
            default: 기본값
            
        Returns:
            변수 값
        """
        if not self.legacy_game:
            return default
            
        return getattr(self.legacy_game, var_name, default)
        
    def set_legacy_value(self, var_name: str, value: Any):
        """레거시 변수 값 설정
        
        Args:
            var_name: 변수 이름
            value: 값
        """
        if not self.legacy_game:
            return
            
        setattr(self.legacy_game, var_name, value)
        
    def call_legacy_function(self, func_name: str, *args, **kwargs) -> Any:
        """레거시 함수 호출
        
        Args:
            func_name: 함수 이름
            *args: 위치 인자
            **kwargs: 키워드 인자
            
        Returns:
            함수 반환값
        """
        if not self.legacy_game or not hasattr(self.legacy_game, func_name):
            print(f"❌ 함수 {func_name}을 찾을 수 없습니다")
            return None
            
        try:
            func = getattr(self.legacy_game, func_name)
            return func(*args, **kwargs)
        except Exception as e:
            print(f"❌ 함수 호출 오류: {e}")
            return None
            
    def is_legacy_active(self) -> bool:
        """레거시 모드 활성 여부
        
        Returns:
            활성 여부
        """
        return self.is_legacy_mode
        
    def shutdown_legacy(self):
        """레거시 게임 종료"""
        if self.legacy_game:
            # 레거시 게임 정리
            if hasattr(self.legacy_game, 'cleanup'):
                self.legacy_game.cleanup()
                
            self.legacy_game = None
            self.is_legacy_mode = False
            print("🔗 레거시 브리지 종료")


# 싱글톤 인스턴스
_legacy_bridge = None

def get_legacy_bridge() -> LegacyBridge:
    """레거시 브리지 싱글톤 반환"""
    global _legacy_bridge
    if _legacy_bridge is None:
        _legacy_bridge = LegacyBridge()
    return _legacy_bridge