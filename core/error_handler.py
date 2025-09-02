"""
Error Handler - 에러 처리 시스템
중앙화된 에러 처리 및 복구 메커니즘
"""

import sys
import traceback
import logging
import pygame
from typing import Any, Callable, Optional, Dict, List
from datetime import datetime
from enum import Enum
from pathlib import Path
import json
from functools import wraps
from core.global_manager import GlobalManager
from core.events import EventType, emit_event


class ErrorSeverity(Enum):
    """에러 심각도"""
    DEBUG = "debug"      # 디버그 정보
    INFO = "info"        # 정보성 메시지
    WARNING = "warning"  # 경고
    ERROR = "error"      # 에러 (복구 가능)
    CRITICAL = "critical"  # 심각한 에러 (복구 불가능)
    FATAL = "fatal"      # 치명적 에러 (게임 종료 필요)


class ErrorCategory(Enum):
    """에러 카테고리"""
    SYSTEM = "system"        # 시스템 에러
    RESOURCE = "resource"    # 리소스 로딩 에러
    NETWORK = "network"      # 네트워크 에러
    GAMEPLAY = "gameplay"    # 게임플레이 에러
    UI = "ui"               # UI 에러
    AUDIO = "audio"         # 오디오 에러
    SAVE = "save"           # 저장/로드 에러
    CONFIG = "config"       # 설정 에러
    UNKNOWN = "unknown"     # 알 수 없는 에러


class GameError(Exception):
    """게임 에러 기본 클래스"""
    
    def __init__(self, message: str, severity: ErrorSeverity = ErrorSeverity.ERROR,
                 category: ErrorCategory = ErrorCategory.UNKNOWN,
                 recoverable: bool = True):
        super().__init__(message)
        self.message = message
        self.severity = severity
        self.category = category
        self.recoverable = recoverable
        self.timestamp = datetime.now()
        

class ResourceError(GameError):
    """리소스 관련 에러"""
    
    def __init__(self, message: str, resource_path: str):
        super().__init__(
            message,
            severity=ErrorSeverity.ERROR,
            category=ErrorCategory.RESOURCE
        )
        self.resource_path = resource_path


class NetworkError(GameError):
    """네트워크 관련 에러"""
    
    def __init__(self, message: str, error_code: int = 0):
        super().__init__(
            message,
            severity=ErrorSeverity.ERROR,
            category=ErrorCategory.NETWORK
        )
        self.error_code = error_code


class SaveError(GameError):
    """저장/로드 관련 에러"""
    
    def __init__(self, message: str, file_path: str):
        super().__init__(
            message,
            severity=ErrorSeverity.WARNING,
            category=ErrorCategory.SAVE
        )
        self.file_path = file_path


class ErrorRecoveryStrategy:
    """에러 복구 전략"""
    
    def __init__(self, name: str):
        self.name = name
        
    def can_recover(self, error: GameError) -> bool:
        """복구 가능 여부 확인
        
        Args:
            error: 게임 에러
            
        Returns:
            복구 가능 여부
        """
        return error.recoverable
        
    def recover(self, error: GameError) -> bool:
        """에러 복구 시도
        
        Args:
            error: 게임 에러
            
        Returns:
            복구 성공 여부
        """
        raise NotImplementedError


class DefaultRecoveryStrategy(ErrorRecoveryStrategy):
    """기본 복구 전략"""
    
    def __init__(self):
        super().__init__("default")
        self.global_manager = GlobalManager.get_instance()
        
    def recover(self, error: GameError) -> bool:
        """기본 복구 시도"""
        try:
            if error.category == ErrorCategory.RESOURCE:
                # 리소스 에러: 기본 리소스로 대체
                print(f"🔧 리소스 복구 시도: {error.message}")
                return self._recover_resource(error)
                
            elif error.category == ErrorCategory.NETWORK:
                # 네트워크 에러: 연결 재시도 또는 오프라인 모드
                print(f"🔧 네트워크 복구 시도: {error.message}")
                return self._recover_network(error)
                
            elif error.category == ErrorCategory.SAVE:
                # 저장 에러: 백업 사용 또는 자동 저장
                print(f"🔧 저장 복구 시도: {error.message}")
                return self._recover_save(error)
                
            elif error.category == ErrorCategory.GAMEPLAY:
                # 게임플레이 에러: 상태 리셋
                print(f"🔧 게임플레이 복구 시도: {error.message}")
                return self._recover_gameplay(error)
                
            else:
                # 기타: 로그만 남기고 계속
                print(f"⚠️ 복구 불가능한 에러: {error.message}")
                return False
                
        except Exception as e:
            print(f"❌ 복구 실패: {e}")
            return False
            
    def _recover_resource(self, error: GameError) -> bool:
        """리소스 에러 복구"""
        if isinstance(error, ResourceError):
            # 기본 리소스로 대체
            if "image" in error.resource_path.lower():
                # 기본 이미지 생성
                default_surface = pygame.Surface((64, 64))
                default_surface.fill((128, 128, 128))
                print(f"✅ 기본 이미지로 대체: {error.resource_path}")
                return True
            elif "sound" in error.resource_path.lower():
                # 사운드 무시
                print(f"✅ 사운드 무시: {error.resource_path}")
                return True
        return False
        
    def _recover_network(self, error: GameError) -> bool:
        """네트워크 에러 복구"""
        if isinstance(error, NetworkError):
            # 오프라인 모드로 전환
            self.global_manager.set('network_mode', 'offline')
            emit_event(EventType.NETWORK_ERROR, {'message': error.message})
            print("✅ 오프라인 모드로 전환")
            return True
        return False
        
    def _recover_save(self, error: GameError) -> bool:
        """저장 에러 복구"""
        if isinstance(error, SaveError):
            # 백업 파일 확인
            backup_path = Path(error.file_path + ".backup")
            if backup_path.exists():
                try:
                    # 백업 복원
                    import shutil
                    shutil.copy2(backup_path, error.file_path)
                    print(f"✅ 백업 파일 복원: {error.file_path}")
                    return True
                except Exception:
                    pass
            # 자동 저장 비활성화
            self.global_manager.set('auto_save_enabled', False)
            print("⚠️ 자동 저장 비활성화")
            return True
        return False
        
    def _recover_gameplay(self, error: GameError) -> bool:
        """게임플레이 에러 복구"""
        # 현재 라운드 재시작
        emit_event(EventType.ROUND_RESTART)
        print("✅ 라운드 재시작")
        return True


class ErrorHandler:
    """에러 핸들러"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        
        # 로거 설정
        self.setup_logging()
        
        # 에러 기록
        self.error_history: List[GameError] = []
        self.max_history = 100
        
        # 복구 전략
        self.recovery_strategies: Dict[ErrorCategory, ErrorRecoveryStrategy] = {
            ErrorCategory.UNKNOWN: DefaultRecoveryStrategy()
        }
        self.default_strategy = DefaultRecoveryStrategy()
        
        # 에러 카운터
        self.error_counts: Dict[ErrorCategory, int] = {}
        
        # 에러 리포터
        self.error_reporters: List[Callable] = []
        
        # 크래시 덤프 경로
        self.crash_dump_dir = Path("crash_dumps")
        self.crash_dump_dir.mkdir(exist_ok=True)
        
    def setup_logging(self):
        """로깅 설정"""
        # 로그 디렉토리 생성
        log_dir = Path("logs")
        log_dir.mkdir(exist_ok=True)
        
        # 로거 설정
        self.logger = logging.getLogger("BossPong")
        self.logger.setLevel(logging.DEBUG)
        
        # 파일 핸들러
        log_file = log_dir / f"bosspong_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"
        file_handler = logging.FileHandler(log_file, encoding='utf-8')
        file_handler.setLevel(logging.DEBUG)
        
        # 콘솔 핸들러
        console_handler = logging.StreamHandler()
        console_handler.setLevel(logging.INFO)
        
        # 포맷터
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        file_handler.setFormatter(formatter)
        console_handler.setFormatter(formatter)
        
        # 핸들러 추가
        self.logger.addHandler(file_handler)
        self.logger.addHandler(console_handler)
        
    def register_recovery_strategy(self, category: ErrorCategory, 
                                  strategy: ErrorRecoveryStrategy):
        """복구 전략 등록
        
        Args:
            category: 에러 카테고리
            strategy: 복구 전략
        """
        self.recovery_strategies[category] = strategy
        
    def register_error_reporter(self, reporter: Callable):
        """에러 리포터 등록
        
        Args:
            reporter: 리포터 함수
        """
        self.error_reporters.append(reporter)
        
    def handle_error(self, error: Exception) -> bool:
        """에러 처리
        
        Args:
            error: 에러
            
        Returns:
            복구 성공 여부
        """
        # GameError로 변환
        if isinstance(error, GameError):
            game_error = error
        else:
            game_error = GameError(
                str(error),
                severity=ErrorSeverity.ERROR,
                category=self._categorize_error(error)
            )
            
        # 에러 기록
        self._record_error(game_error)
        
        # 로깅
        self._log_error(game_error)
        
        # 심각도 확인
        if game_error.severity == ErrorSeverity.FATAL:
            # 치명적 에러: 크래시 덤프 생성 후 종료
            self._create_crash_dump(game_error)
            return False
            
        # 복구 시도
        recovered = self._attempt_recovery(game_error)
        
        # 리포터에게 알림
        self._report_error(game_error, recovered)
        
        # 이벤트 발생
        emit_event(EventType.ERROR_OCCURRED, {
            'error': game_error,
            'recovered': recovered
        })
        
        return recovered
        
    def _categorize_error(self, error: Exception) -> ErrorCategory:
        """에러 카테고리 분류"""
        error_type = type(error).__name__
        error_msg = str(error).lower()
        
        if "resource" in error_msg or "load" in error_msg or "file" in error_msg:
            return ErrorCategory.RESOURCE
        elif "network" in error_msg or "connection" in error_msg:
            return ErrorCategory.NETWORK
        elif "save" in error_msg or "load" in error_msg:
            return ErrorCategory.SAVE
        elif "pygame" in error_type:
            return ErrorCategory.SYSTEM
        else:
            return ErrorCategory.UNKNOWN
            
    def _record_error(self, error: GameError):
        """에러 기록"""
        # 히스토리에 추가
        self.error_history.append(error)
        if len(self.error_history) > self.max_history:
            self.error_history.pop(0)
            
        # 카운터 증가
        self.error_counts[error.category] = self.error_counts.get(error.category, 0) + 1
        
    def _log_error(self, error: GameError):
        """에러 로깅"""
        # 스택 트레이스 가져오기
        stack_trace = traceback.format_exc()
        
        # 심각도에 따른 로깅
        if error.severity == ErrorSeverity.DEBUG:
            self.logger.debug(f"{error.category.value}: {error.message}")
        elif error.severity == ErrorSeverity.INFO:
            self.logger.info(f"{error.category.value}: {error.message}")
        elif error.severity == ErrorSeverity.WARNING:
            self.logger.warning(f"{error.category.value}: {error.message}")
        elif error.severity == ErrorSeverity.ERROR:
            self.logger.error(f"{error.category.value}: {error.message}\n{stack_trace}")
        elif error.severity in [ErrorSeverity.CRITICAL, ErrorSeverity.FATAL]:
            self.logger.critical(f"{error.category.value}: {error.message}\n{stack_trace}")
            
    def _attempt_recovery(self, error: GameError) -> bool:
        """복구 시도"""
        # 카테고리별 전략 선택
        strategy = self.recovery_strategies.get(error.category, self.default_strategy)
        
        # 복구 가능 여부 확인
        if not strategy.can_recover(error):
            return False
            
        # 복구 시도
        try:
            return strategy.recover(error)
        except Exception as e:
            self.logger.error(f"복구 중 에러 발생: {e}")
            return False
            
    def _report_error(self, error: GameError, recovered: bool):
        """에러 리포터에게 알림"""
        for reporter in self.error_reporters:
            try:
                reporter(error, recovered)
            except Exception as e:
                self.logger.error(f"리포터 에러: {e}")
                
    def _create_crash_dump(self, error: GameError):
        """크래시 덤프 생성"""
        try:
            dump_file = self.crash_dump_dir / f"crash_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            
            dump_data = {
                'timestamp': error.timestamp.isoformat(),
                'error': {
                    'message': error.message,
                    'severity': error.severity.value,
                    'category': error.category.value,
                    'stack_trace': traceback.format_exc()
                },
                'system_info': {
                    'python_version': sys.version,
                    'pygame_version': pygame.version.ver,
                    'platform': sys.platform
                },
                'game_state': self._collect_game_state(),
                'error_history': [
                    {
                        'message': e.message,
                        'category': e.category.value,
                        'timestamp': e.timestamp.isoformat()
                    }
                    for e in self.error_history[-10:]  # 최근 10개
                ]
            }
            
            with open(dump_file, 'w', encoding='utf-8') as f:
                json.dump(dump_data, f, indent=2, ensure_ascii=False)
                
            print(f"💾 크래시 덤프 생성: {dump_file}")
            
        except Exception as e:
            print(f"❌ 크래시 덤프 생성 실패: {e}")
            
    def _collect_game_state(self) -> Dict[str, Any]:
        """게임 상태 수집"""
        try:
            return {
                'current_stage': self.global_manager.get('current_stage', 0),
                'player_score': self.global_manager.get('player_score', 0),
                'boss_score': self.global_manager.get('boss_score', 0),
                'game_mode': self.global_manager.get('game_mode', 'unknown'),
                'fps': self.global_manager.get('fps', 0)
            }
        except Exception:
            return {}
            
    def get_error_stats(self) -> Dict[str, Any]:
        """에러 통계 조회"""
        return {
            'total_errors': sum(self.error_counts.values()),
            'by_category': dict(self.error_counts),
            'recent_errors': len(self.error_history)
        }
        
    def clear_error_history(self):
        """에러 히스토리 초기화"""
        self.error_history.clear()
        self.error_counts.clear()
        
    def cleanup(self):
        """정리"""
        # 로거 정리
        for handler in self.logger.handlers:
            handler.close()
            self.logger.removeHandler(handler)
            
        print("🧹 에러 핸들러 정리 완료")


def safe_execute(func: Callable) -> Callable:
    """안전한 실행 데코레이터"""
    @wraps(func)
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except Exception as e:
            error_handler = get_error_handler()
            if error_handler.handle_error(e):
                # 복구 성공: 기본값 반환
                return None
            else:
                # 복구 실패: 예외 재발생
                raise
    return wrapper


def handle_exceptions(severity: ErrorSeverity = ErrorSeverity.ERROR,
                     category: ErrorCategory = ErrorCategory.UNKNOWN,
                     recoverable: bool = True):
    """예외 처리 데코레이터
    
    Args:
        severity: 에러 심각도
        category: 에러 카테고리
        recoverable: 복구 가능 여부
    """
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                game_error = GameError(
                    f"{func.__name__}에서 에러 발생: {str(e)}",
                    severity=severity,
                    category=category,
                    recoverable=recoverable
                )
                
                error_handler = get_error_handler()
                if error_handler.handle_error(game_error):
                    return None
                else:
                    raise
        return wrapper
    return decorator


# 싱글톤 인스턴스
_error_handler = None

def get_error_handler() -> ErrorHandler:
    """에러 핸들러 싱글톤 반환"""
    global _error_handler
    if _error_handler is None:
        _error_handler = ErrorHandler()
    return _error_handler