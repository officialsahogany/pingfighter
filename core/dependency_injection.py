# -*- coding: utf-8 -*-
"""
의존성 주입(DI) 컨테이너
모든 서비스와 컴포넌트의 생명주기를 관리
"""

from typing import Dict, Any, Type, Callable, Optional, List
from enum import Enum
import inspect
from functools import wraps


class ServiceLifetime(Enum):
    """서비스 생명주기 타입"""
    SINGLETON = "singleton"      # 앱 전체에서 하나의 인스턴스
    SCOPED = "scoped"            # 범위당 하나의 인스턴스
    TRANSIENT = "transient"      # 매번 새 인스턴스


class DIContainer:
    """의존성 주입 컨테이너
    
    서비스 등록, 해결, 생명주기 관리를 담당합니다.
    """
    
    def __init__(self):
        self._services: Dict[Type, Dict[str, Any]] = {}
        self._singletons: Dict[Type, Any] = {}
        self._factories: Dict[Type, Callable] = {}
        self._scoped_instances: Dict[str, Dict[Type, Any]] = {}
        self._current_scope: Optional[str] = None
        
    def register(self, 
                interface: Type,
                implementation: Optional[Type] = None,
                factory: Optional[Callable] = None,
                lifetime: ServiceLifetime = ServiceLifetime.SINGLETON,
                **kwargs):
        """서비스 등록
        
        Args:
            interface: 서비스 인터페이스/추상 클래스
            implementation: 구현 클래스
            factory: 팩토리 함수
            lifetime: 서비스 생명주기
            **kwargs: 생성자 인자
        """
        if not implementation and not factory:
            implementation = interface
            
        self._services[interface] = {
            'implementation': implementation,
            'factory': factory,
            'lifetime': lifetime,
            'kwargs': kwargs
        }
        
        if factory:
            self._factories[interface] = factory
    
    def register_singleton(self, interface: Type, implementation: Optional[Type] = None, **kwargs):
        """싱글톤 서비스 등록"""
        self.register(interface, implementation, lifetime=ServiceLifetime.SINGLETON, **kwargs)
    
    def register_transient(self, interface: Type, implementation: Optional[Type] = None, **kwargs):
        """Transient 서비스 등록"""
        self.register(interface, implementation, lifetime=ServiceLifetime.TRANSIENT, **kwargs)
    
    def register_scoped(self, interface: Type, implementation: Optional[Type] = None, **kwargs):
        """Scoped 서비스 등록"""
        self.register(interface, implementation, lifetime=ServiceLifetime.SCOPED, **kwargs)
    
    def resolve(self, service_type: Type) -> Any:
        """서비스 해결 (인스턴스 반환)
        
        Args:
            service_type: 요청하는 서비스 타입
            
        Returns:
            서비스 인스턴스
        """
        if service_type not in self._services:
            raise ValueError(f"Service {service_type.__name__} is not registered")
        
        service_info = self._services[service_type]
        lifetime = service_info['lifetime']
        
        # 생명주기에 따른 인스턴스 반환
        if lifetime == ServiceLifetime.SINGLETON:
            return self._get_or_create_singleton(service_type, service_info)
        elif lifetime == ServiceLifetime.SCOPED:
            return self._get_or_create_scoped(service_type, service_info)
        else:  # TRANSIENT
            return self._create_instance(service_type, service_info)
    
    def _get_or_create_singleton(self, service_type: Type, service_info: Dict) -> Any:
        """싱글톤 인스턴스 획득 또는 생성"""
        if service_type not in self._singletons:
            self._singletons[service_type] = self._create_instance(service_type, service_info)
        return self._singletons[service_type]
    
    def _get_or_create_scoped(self, service_type: Type, service_info: Dict) -> Any:
        """Scoped 인스턴스 획득 또는 생성"""
        if not self._current_scope:
            raise RuntimeError("No scope is active. Use 'with container.create_scope():'")
        
        if self._current_scope not in self._scoped_instances:
            self._scoped_instances[self._current_scope] = {}
        
        scope_instances = self._scoped_instances[self._current_scope]
        
        if service_type not in scope_instances:
            scope_instances[service_type] = self._create_instance(service_type, service_info)
        
        return scope_instances[service_type]
    
    def _create_instance(self, service_type: Type, service_info: Dict) -> Any:
        """인스턴스 생성"""
        # 팩토리가 있으면 팩토리 사용
        if service_info['factory']:
            return service_info['factory'](self)
        
        implementation = service_info['implementation']
        kwargs = service_info['kwargs']
        
        # 생성자 의존성 자동 주입
        sig = inspect.signature(implementation.__init__)
        resolved_args = {}
        
        for param_name, param in sig.parameters.items():
            if param_name == 'self':
                continue
                
            # 타입 힌트가 있으면 자동 해결 시도
            if param.annotation != inspect.Parameter.empty:
                try:
                    if param.annotation in self._services:
                        resolved_args[param_name] = self.resolve(param.annotation)
                except:
                    pass
        
        # 명시적 kwargs 우선
        resolved_args.update(kwargs)
        
        return implementation(**resolved_args)
    
    def create_scope(self, scope_name: Optional[str] = None):
        """새로운 범위 생성 (with 구문 사용)"""
        return DIScope(self, scope_name)
    
    def inject(self, func: Callable) -> Callable:
        """데코레이터: 함수 파라미터 자동 주입"""
        @wraps(func)
        def wrapper(*args, **kwargs):
            sig = inspect.signature(func)
            injected_kwargs = {}
            
            for param_name, param in sig.parameters.items():
                if param_name not in kwargs and param.annotation != inspect.Parameter.empty:
                    try:
                        if param.annotation in self._services:
                            injected_kwargs[param_name] = self.resolve(param.annotation)
                    except:
                        pass
            
            kwargs.update(injected_kwargs)
            return func(*args, **kwargs)
        
        return wrapper
    
    def clear(self):
        """컨테이너 초기화"""
        self._services.clear()
        self._singletons.clear()
        self._factories.clear()
        self._scoped_instances.clear()
        self._current_scope = None


class DIScope:
    """DI 범위 컨텍스트 관리자"""
    
    def __init__(self, container: DIContainer, scope_name: Optional[str] = None):
        self.container = container
        self.scope_name = scope_name or f"scope_{id(self)}"
        self.previous_scope = None
    
    def __enter__(self):
        self.previous_scope = self.container._current_scope
        self.container._current_scope = self.scope_name
        return self
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        # 범위 정리
        if self.scope_name in self.container._scoped_instances:
            del self.container._scoped_instances[self.scope_name]
        
        self.container._current_scope = self.previous_scope


# 전역 컨테이너 인스턴스
_container = DIContainer()


def get_container() -> DIContainer:
    """전역 DI 컨테이너 반환"""
    return _container


def register_services():
    """모든 서비스 등록 (앱 시작 시 호출)"""
    from core.game_state import GameState
    from core.events import EventManager
    from game_logic.physics_engine import PhysicsEngine
    from game_logic.collision_system import CollisionSystem
    from rendering.game_renderer import GameRenderer
    from managers.resource_manager import ResourceManager
    from managers.sound_manager import SoundManager
    
    container = get_container()
    
    # 싱글톤 서비스
    container.register_singleton(GameState)
    container.register_singleton(EventManager)
    container.register_singleton(ResourceManager)
    container.register_singleton(SoundManager)
    
    # Transient 서비스 (매번 새 인스턴스)
    container.register_transient(PhysicsEngine)
    container.register_transient(CollisionSystem)
    
    # 팩토리 패턴 사용
    def renderer_factory(container: DIContainer):
        # 화면은 나중에 설정
        return GameRenderer(None)
    
    container.register(GameRenderer, factory=renderer_factory, lifetime=ServiceLifetime.SINGLETON)


# 편의 함수들
def inject(service_type: Type) -> Any:
    """서비스 주입 헬퍼"""
    return get_container().resolve(service_type)


def singleton(cls: Type) -> Type:
    """싱글톤 데코레이터"""
    get_container().register_singleton(cls)
    return cls


def transient(cls: Type) -> Type:
    """Transient 데코레이터"""
    get_container().register_transient(cls)
    return cls


def scoped(cls: Type) -> Type:
    """Scoped 데코레이터"""
    get_container().register_scoped(cls)
    return cls