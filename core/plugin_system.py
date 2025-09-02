# -*- coding: utf-8 -*-
"""
플러그인 시스템
게임에 동적으로 기능을 추가할 수 있는 확장 시스템
"""

import os
import importlib
import inspect
from typing import Dict, List, Any, Optional, Callable
from abc import ABC, abstractmethod
from dataclasses import dataclass
from enum import Enum


class PluginPriority(Enum):
    """플러그인 실행 우선순위"""
    CRITICAL = 0     # 최고 우선순위
    HIGH = 100
    NORMAL = 500
    LOW = 900
    LOWEST = 999


class PluginLifecycle(Enum):
    """플러그인 생명주기 이벤트"""
    PRE_INIT = "pre_init"
    POST_INIT = "post_init"
    PRE_UPDATE = "pre_update"
    POST_UPDATE = "post_update"
    PRE_RENDER = "pre_render"
    POST_RENDER = "post_render"
    PRE_CLEANUP = "pre_cleanup"
    POST_CLEANUP = "post_cleanup"


@dataclass
class PluginMetadata:
    """플러그인 메타데이터"""
    name: str
    version: str
    author: str
    description: str
    dependencies: List[str] = None
    priority: PluginPriority = PluginPriority.NORMAL
    enabled: bool = True


class IPlugin(ABC):
    """플러그인 인터페이스"""
    
    @abstractmethod
    def get_metadata(self) -> PluginMetadata:
        """플러그인 메타데이터 반환"""
        pass
    
    @abstractmethod
    def initialize(self, game_context: Any) -> bool:
        """플러그인 초기화
        
        Args:
            game_context: 게임 컨텍스트
            
        Returns:
            초기화 성공 여부
        """
        pass
    
    @abstractmethod
    def cleanup(self) -> None:
        """플러그인 정리"""
        pass
    
    def on_update(self, dt: float) -> None:
        """업데이트 이벤트 (선택적)"""
        pass
    
    def on_render(self, screen: Any) -> None:
        """렌더링 이벤트 (선택적)"""
        pass
    
    def on_event(self, event_type: str, event_data: Any) -> None:
        """이벤트 처리 (선택적)"""
        pass


class PluginManager:
    """플러그인 관리자
    
    플러그인 로드, 실행, 관리를 담당합니다.
    """
    
    def __init__(self, plugin_dir: str = "plugins"):
        self.plugin_dir = plugin_dir
        self.plugins: Dict[str, IPlugin] = {}
        self.plugin_order: List[str] = []
        self.hooks: Dict[str, List[Callable]] = {}
        self.game_context = None
        
        # 생명주기 이벤트 초기화
        for lifecycle in PluginLifecycle:
            self.hooks[lifecycle.value] = []
    
    def discover_plugins(self) -> List[str]:
        """플러그인 디렉토리에서 플러그인 발견
        
        Returns:
            발견된 플러그인 이름 리스트
        """
        discovered = []
        
        if not os.path.exists(self.plugin_dir):
            os.makedirs(self.plugin_dir)
            return discovered
        
        for filename in os.listdir(self.plugin_dir):
            if filename.endswith('.py') and not filename.startswith('_'):
                plugin_name = filename[:-3]
                discovered.append(plugin_name)
        
        # 플러그인 폴더도 체크
        for dirname in os.listdir(self.plugin_dir):
            dir_path = os.path.join(self.plugin_dir, dirname)
            if os.path.isdir(dir_path):
                init_file = os.path.join(dir_path, '__init__.py')
                if os.path.exists(init_file):
                    discovered.append(dirname)
        
        return discovered
    
    def load_plugin(self, plugin_name: str) -> bool:
        """플러그인 로드
        
        Args:
            plugin_name: 플러그인 이름
            
        Returns:
            로드 성공 여부
        """
        try:
            # 모듈 임포트
            module_name = f"{self.plugin_dir.replace('/', '.')}.{plugin_name}"
            module = importlib.import_module(module_name)
            
            # IPlugin 구현 찾기
            plugin_class = None
            for name, obj in inspect.getmembers(module):
                if inspect.isclass(obj) and issubclass(obj, IPlugin) and obj != IPlugin:
                    plugin_class = obj
                    break
            
            if not plugin_class:
                print(f"플러그인 {plugin_name}에서 IPlugin 구현을 찾을 수 없습니다.")
                return False
            
            # 플러그인 인스턴스 생성
            plugin_instance = plugin_class()
            metadata = plugin_instance.get_metadata()
            
            # 의존성 체크
            if metadata.dependencies:
                for dep in metadata.dependencies:
                    if dep not in self.plugins:
                        print(f"플러그인 {plugin_name}의 의존성 {dep}가 없습니다.")
                        return False
            
            # 플러그인 등록
            self.plugins[metadata.name] = plugin_instance
            
            # 우선순위에 따라 정렬
            self._update_plugin_order()
            
            print(f"플러그인 로드: {metadata.name} v{metadata.version}")
            return True
            
        except Exception as e:
            print(f"플러그인 {plugin_name} 로드 실패: {e}")
            return False
    
    def load_all_plugins(self) -> int:
        """모든 플러그인 로드
        
        Returns:
            로드된 플러그인 수
        """
        discovered = self.discover_plugins()
        loaded = 0
        
        for plugin_name in discovered:
            if self.load_plugin(plugin_name):
                loaded += 1
        
        return loaded
    
    def unload_plugin(self, plugin_name: str) -> bool:
        """플러그인 언로드
        
        Args:
            plugin_name: 플러그인 이름
            
        Returns:
            언로드 성공 여부
        """
        if plugin_name not in self.plugins:
            return False
        
        plugin = self.plugins[plugin_name]
        
        try:
            # 정리 호출
            plugin.cleanup()
            
            # 제거
            del self.plugins[plugin_name]
            self._update_plugin_order()
            
            print(f"플러그인 언로드: {plugin_name}")
            return True
            
        except Exception as e:
            print(f"플러그인 {plugin_name} 언로드 실패: {e}")
            return False
    
    def initialize_plugins(self, game_context: Any) -> None:
        """모든 플러그인 초기화
        
        Args:
            game_context: 게임 컨텍스트
        """
        self.game_context = game_context
        
        # PRE_INIT 훅 실행
        self._execute_hooks(PluginLifecycle.PRE_INIT)
        
        # 플러그인 초기화 (우선순위 순)
        for plugin_name in self.plugin_order:
            plugin = self.plugins[plugin_name]
            metadata = plugin.get_metadata()
            
            if metadata.enabled:
                try:
                    if plugin.initialize(game_context):
                        print(f"플러그인 초기화: {plugin_name}")
                    else:
                        print(f"플러그인 초기화 실패: {plugin_name}")
                        metadata.enabled = False
                except Exception as e:
                    print(f"플러그인 초기화 오류: {plugin_name} - {e}")
                    metadata.enabled = False
        
        # POST_INIT 훅 실행
        self._execute_hooks(PluginLifecycle.POST_INIT)
    
    def update_plugins(self, dt: float) -> None:
        """모든 플러그인 업데이트
        
        Args:
            dt: 델타 시간
        """
        # PRE_UPDATE 훅
        self._execute_hooks(PluginLifecycle.PRE_UPDATE, dt=dt)
        
        # 플러그인 업데이트
        for plugin_name in self.plugin_order:
            plugin = self.plugins[plugin_name]
            metadata = plugin.get_metadata()
            
            if metadata.enabled:
                try:
                    plugin.on_update(dt)
                except Exception as e:
                    print(f"플러그인 업데이트 오류: {plugin_name} - {e}")
        
        # POST_UPDATE 훅
        self._execute_hooks(PluginLifecycle.POST_UPDATE, dt=dt)
    
    def render_plugins(self, screen: Any) -> None:
        """모든 플러그인 렌더링
        
        Args:
            screen: 화면 객체
        """
        # PRE_RENDER 훅
        self._execute_hooks(PluginLifecycle.PRE_RENDER, screen=screen)
        
        # 플러그인 렌더링
        for plugin_name in self.plugin_order:
            plugin = self.plugins[plugin_name]
            metadata = plugin.get_metadata()
            
            if metadata.enabled:
                try:
                    plugin.on_render(screen)
                except Exception as e:
                    print(f"플러그인 렌더링 오류: {plugin_name} - {e}")
        
        # POST_RENDER 훅
        self._execute_hooks(PluginLifecycle.POST_RENDER, screen=screen)
    
    def broadcast_event(self, event_type: str, event_data: Any = None) -> None:
        """모든 플러그인에 이벤트 브로드캐스트
        
        Args:
            event_type: 이벤트 타입
            event_data: 이벤트 데이터
        """
        for plugin_name in self.plugin_order:
            plugin = self.plugins[plugin_name]
            metadata = plugin.get_metadata()
            
            if metadata.enabled:
                try:
                    plugin.on_event(event_type, event_data)
                except Exception as e:
                    print(f"플러그인 이벤트 처리 오류: {plugin_name} - {e}")
    
    def register_hook(self, lifecycle: PluginLifecycle, callback: Callable) -> None:
        """생명주기 훅 등록
        
        Args:
            lifecycle: 생명주기 이벤트
            callback: 콜백 함수
        """
        if lifecycle.value in self.hooks:
            self.hooks[lifecycle.value].append(callback)
    
    def _execute_hooks(self, lifecycle: PluginLifecycle, **kwargs) -> None:
        """훅 실행"""
        for hook in self.hooks[lifecycle.value]:
            try:
                hook(**kwargs)
            except Exception as e:
                print(f"훅 실행 오류: {lifecycle.value} - {e}")
    
    def _update_plugin_order(self) -> None:
        """플러그인 순서 업데이트 (우선순위 기반)"""
        self.plugin_order = sorted(
            self.plugins.keys(),
            key=lambda name: self.plugins[name].get_metadata().priority.value
        )
    
    def get_plugin(self, plugin_name: str) -> Optional[IPlugin]:
        """플러그인 인스턴스 반환"""
        return self.plugins.get(plugin_name)
    
    def is_plugin_loaded(self, plugin_name: str) -> bool:
        """플러그인 로드 여부 확인"""
        return plugin_name in self.plugins
    
    def get_loaded_plugins(self) -> List[str]:
        """로드된 플러그인 목록 반환"""
        return list(self.plugins.keys())
    
    def cleanup(self) -> None:
        """모든 플러그인 정리"""
        # PRE_CLEANUP 훅
        self._execute_hooks(PluginLifecycle.PRE_CLEANUP)
        
        # 플러그인 정리 (역순)
        for plugin_name in reversed(self.plugin_order):
            plugin = self.plugins[plugin_name]
            try:
                plugin.cleanup()
            except Exception as e:
                print(f"플러그인 정리 오류: {plugin_name} - {e}")
        
        # POST_CLEANUP 훅
        self._execute_hooks(PluginLifecycle.POST_CLEANUP)
        
        # 초기화
        self.plugins.clear()
        self.plugin_order.clear()


# 전역 플러그인 관리자
_plugin_manager = PluginManager()


def get_plugin_manager() -> PluginManager:
    """전역 플러그인 관리자 반환"""
    return _plugin_manager