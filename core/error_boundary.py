"""
Error Boundary - 에러 경계
시스템별 에러 격리 및 복구
"""

import pygame
from typing import Any, Callable, Optional, Dict, Type
from functools import wraps
from contextlib import contextmanager
from core.error_handler import (
    GameError, ErrorSeverity, ErrorCategory,
    get_error_handler, ResourceError, NetworkError, SaveError
)
from core.global_manager import GlobalManager
from core.events import EventType, emit_event


class ErrorBoundary:
    """에러 경계 기본 클래스"""
    
    def __init__(self, name: str, category: ErrorCategory):
        self.name = name
        self.category = category
        self.error_handler = get_error_handler()
        self.global_manager = GlobalManager.get_instance()
        self.fallback_active = False
        self.error_count = 0
        self.max_errors = 5  # 최대 에러 횟수
        
    def wrap(self, func: Callable) -> Callable:
        """함수를 에러 경계로 감싸기
        
        Args:
            func: 대상 함수
            
        Returns:
            래핑된 함수
        """
        @wraps(func)
        def wrapper(*args, **kwargs):
            try:
                # 에러가 너무 많으면 폴백 모드
                if self.error_count >= self.max_errors:
                    return self.fallback(*args, **kwargs)
                    
                return func(*args, **kwargs)
                
            except Exception as e:
                return self.handle_error(e, func, args, kwargs)
                
        return wrapper
        
    def handle_error(self, error: Exception, func: Callable, 
                    args: tuple, kwargs: dict) -> Any:
        """에러 처리
        
        Args:
            error: 발생한 에러
            func: 에러가 발생한 함수
            args: 함수 인자
            kwargs: 함수 키워드 인자
            
        Returns:
            복구 결과 또는 폴백 값
        """
        self.error_count += 1
        
        # GameError로 변환
        if not isinstance(error, GameError):
            error = GameError(
                f"{self.name}에서 에러 발생: {str(error)}",
                severity=ErrorSeverity.ERROR,
                category=self.category,
                recoverable=True
            )
            
        # 에러 핸들러에 전달
        recovered = self.error_handler.handle_error(error)
        
        if recovered:
            # 복구 성공: 재시도 또는 폴백
            if self.error_count < 3:
                # 재시도
                try:
                    return func(*args, **kwargs)
                except Exception:
                    # 재시도 실패: 폴백
                    return self.fallback(*args, **kwargs)
            else:
                # 에러 횟수 초과: 폴백
                return self.fallback(*args, **kwargs)
        else:
            # 복구 실패: 예외 재발생
            raise error
            
    def fallback(self, *args, **kwargs) -> Any:
        """폴백 동작
        
        Args:
            *args: 원래 함수 인자
            **kwargs: 원래 함수 키워드 인자
            
        Returns:
            폴백 값
        """
        self.fallback_active = True
        emit_event(EventType.ERROR_FALLBACK, {
            'boundary': self.name,
            'error_count': self.error_count
        })
        return None
        
    def reset(self):
        """에러 카운터 리셋"""
        self.error_count = 0
        self.fallback_active = False
        
    @contextmanager
    def context(self):
        """컨텍스트 매니저로 사용"""
        try:
            yield self
        except Exception as e:
            self.handle_error(e, lambda: None, (), {})


class RenderingBoundary(ErrorBoundary):
    """렌더링 에러 경계"""
    
    def __init__(self):
        super().__init__("Rendering", ErrorCategory.UI)
        self.last_valid_frame = None
        
    def fallback(self, *args, **kwargs) -> Any:
        """렌더링 폴백: 마지막 유효 프레임 또는 기본 화면"""
        screen = args[0] if args else None
        if not screen:
            return
            
        try:
            if self.last_valid_frame:
                # 마지막 유효 프레임 표시
                screen.blit(self.last_valid_frame, (0, 0))
            else:
                # 기본 화면
                screen.fill((50, 50, 50))
                
            # 에러 메시지 표시
            font = pygame.font.Font(None, 30)
            text = font.render("Rendering Error - Fallback Mode", True, (255, 100, 100))
            rect = text.get_rect(center=(screen.get_width() // 2, screen.get_height() // 2))
            screen.blit(text, rect)
            
        except Exception:
            # 최소한의 화면 표시
            try:
                screen.fill((0, 0, 0))
            except Exception:
                pass
                
    def save_frame(self, screen: pygame.Surface):
        """유효 프레임 저장"""
        try:
            self.last_valid_frame = screen.copy()
        except Exception:
            pass


class NetworkBoundary(ErrorBoundary):
    """네트워크 에러 경계"""
    
    def __init__(self):
        super().__init__("Network", ErrorCategory.NETWORK)
        self.offline_mode = False
        
    def handle_error(self, error: Exception, func: Callable,
                    args: tuple, kwargs: dict) -> Any:
        """네트워크 에러 처리"""
        # 오프라인 모드로 전환
        self.offline_mode = True
        self.global_manager.set('network_mode', 'offline')
        
        # NetworkError로 변환
        if not isinstance(error, NetworkError):
            error = NetworkError(f"네트워크 에러: {str(error)}")
            
        # 기본 처리
        return super().handle_error(error, func, args, kwargs)
        
    def fallback(self, *args, **kwargs) -> Any:
        """네트워크 폴백: 오프라인 모드"""
        emit_event(EventType.NETWORK_OFFLINE)
        return {'offline': True, 'data': None}


class ResourceBoundary(ErrorBoundary):
    """리소스 에러 경계"""
    
    def __init__(self):
        super().__init__("Resource", ErrorCategory.RESOURCE)
        self.default_resources = {}
        self._create_default_resources()
        
    def _create_default_resources(self):
        """기본 리소스 생성"""
        try:
            # 기본 이미지
            default_surface = pygame.Surface((64, 64))
            default_surface.fill((128, 128, 128))
            self.default_resources['image'] = default_surface
            
            # 기본 폰트
            self.default_resources['font'] = pygame.font.Font(None, 20)
            
        except Exception:
            pass
            
    def handle_error(self, error: Exception, func: Callable,
                    args: tuple, kwargs: dict) -> Any:
        """리소스 에러 처리"""
        # ResourceError로 변환
        if not isinstance(error, ResourceError):
            resource_path = kwargs.get('path', '') or (args[0] if args else '')
            error = ResourceError(f"리소스 로드 실패: {str(error)}", resource_path)
            
        # 기본 처리
        result = super().handle_error(error, func, args, kwargs)
        
        # 결과가 None이면 기본 리소스 반환
        if result is None:
            return self._get_default_resource(error.resource_path)
            
        return result
        
    def _get_default_resource(self, path: str) -> Any:
        """기본 리소스 반환"""
        path_lower = path.lower()
        
        if any(ext in path_lower for ext in ['.png', '.jpg', '.bmp']):
            return self.default_resources.get('image')
        elif any(ext in path_lower for ext in ['.ttf', '.otf']):
            return self.default_resources.get('font')
        else:
            return None


class GameplayBoundary(ErrorBoundary):
    """게임플레이 에러 경계"""
    
    def __init__(self):
        super().__init__("Gameplay", ErrorCategory.GAMEPLAY)
        self.safe_mode = False
        
    def handle_error(self, error: Exception, func: Callable,
                    args: tuple, kwargs: dict) -> Any:
        """게임플레이 에러 처리"""
        # 안전 모드 활성화
        self.safe_mode = True
        
        # 기본 처리
        result = super().handle_error(error, func, args, kwargs)
        
        # 라운드 재시작
        if self.error_count >= 3:
            emit_event(EventType.ROUND_RESTART)
            self.reset()
            
        return result
        
    def fallback(self, *args, **kwargs) -> Any:
        """게임플레이 폴백: 안전 모드"""
        # 기본 동작만 수행
        return {'safe_mode': True, 'action': 'skip'}


class SaveBoundary(ErrorBoundary):
    """저장/로드 에러 경계"""
    
    def __init__(self):
        super().__init__("Save", ErrorCategory.SAVE)
        self.backup_enabled = True
        
    def handle_error(self, error: Exception, func: Callable,
                    args: tuple, kwargs: dict) -> Any:
        """저장 에러 처리"""
        # SaveError로 변환
        if not isinstance(error, SaveError):
            file_path = kwargs.get('path', '') or (args[0] if args else '')
            error = SaveError(f"저장 실패: {str(error)}", file_path)
            
        # 백업 시도
        if self.backup_enabled and hasattr(error, 'file_path'):
            self._try_backup(error.file_path)
            
        # 기본 처리
        return super().handle_error(error, func, args, kwargs)
        
    def _try_backup(self, file_path: str):
        """백업 시도"""
        try:
            import shutil
            from pathlib import Path
            
            source = Path(file_path)
            if source.exists():
                backup = Path(file_path + ".backup")
                shutil.copy2(source, backup)
                print(f"💾 백업 생성: {backup}")
                
        except Exception as e:
            print(f"백업 실패: {e}")
            
    def fallback(self, *args, **kwargs) -> Any:
        """저장 폴백: 메모리 저장"""
        # 메모리에만 저장
        data = kwargs.get('data') or (args[1] if len(args) > 1 else None)
        if data:
            self.global_manager.set('temp_save_data', data)
            emit_event(EventType.SAVE_TO_MEMORY, {'data': data})
            return True
        return False


class BoundaryManager:
    """에러 경계 관리자"""
    
    def __init__(self):
        self.boundaries: Dict[str, ErrorBoundary] = {}
        self._setup_boundaries()
        
    def _setup_boundaries(self):
        """기본 에러 경계 설정"""
        self.boundaries['rendering'] = RenderingBoundary()
        self.boundaries['network'] = NetworkBoundary()
        self.boundaries['resource'] = ResourceBoundary()
        self.boundaries['gameplay'] = GameplayBoundary()
        self.boundaries['save'] = SaveBoundary()
        
    def get_boundary(self, name: str) -> Optional[ErrorBoundary]:
        """에러 경계 가져오기
        
        Args:
            name: 경계 이름
            
        Returns:
            에러 경계 또는 None
        """
        return self.boundaries.get(name)
        
    def register_boundary(self, name: str, boundary: ErrorBoundary):
        """에러 경계 등록
        
        Args:
            name: 경계 이름
            boundary: 에러 경계
        """
        self.boundaries[name] = boundary
        
    def wrap_function(self, func: Callable, boundary_name: str) -> Callable:
        """함수를 에러 경계로 감싸기
        
        Args:
            func: 대상 함수
            boundary_name: 경계 이름
            
        Returns:
            래핑된 함수
        """
        boundary = self.get_boundary(boundary_name)
        if boundary:
            return boundary.wrap(func)
        return func
        
    def reset_all(self):
        """모든 경계 리셋"""
        for boundary in self.boundaries.values():
            boundary.reset()
            
    def get_stats(self) -> Dict[str, Any]:
        """통계 조회"""
        return {
            name: {
                'error_count': boundary.error_count,
                'fallback_active': boundary.fallback_active
            }
            for name, boundary in self.boundaries.items()
        }


# 데코레이터
def with_boundary(boundary_name: str):
    """에러 경계 데코레이터
    
    Args:
        boundary_name: 경계 이름
    """
    def decorator(func: Callable) -> Callable:
        manager = get_boundary_manager()
        return manager.wrap_function(func, boundary_name)
    return decorator


def rendering_boundary(func: Callable) -> Callable:
    """렌더링 경계 데코레이터"""
    return with_boundary('rendering')(func)


def network_boundary(func: Callable) -> Callable:
    """네트워크 경계 데코레이터"""
    return with_boundary('network')(func)


def resource_boundary(func: Callable) -> Callable:
    """리소스 경계 데코레이터"""
    return with_boundary('resource')(func)


def gameplay_boundary(func: Callable) -> Callable:
    """게임플레이 경계 데코레이터"""
    return with_boundary('gameplay')(func)


def save_boundary(func: Callable) -> Callable:
    """저장 경계 데코레이터"""
    return with_boundary('save')(func)


# 싱글톤 인스턴스
_boundary_manager = None

def get_boundary_manager() -> BoundaryManager:
    """경계 관리자 싱글톤 반환"""
    global _boundary_manager
    if _boundary_manager is None:
        _boundary_manager = BoundaryManager()
    return _boundary_manager