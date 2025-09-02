# -*- coding: utf-8 -*-
"""
게임 코어 모듈
게임 초기화, 메인 루프, 전체 상태 관리를 담당
"""

import pygame
import sys
import os
from typing import Optional, Tuple
from dataclasses import dataclass
from enum import Enum

# 로컬 모듈
from core.game_state import GameState
from core.events import EventManager, EventType
from rendering.game_renderer import GameRenderer
from game_logic.physics_engine import PhysicsEngine
from game_logic.collision_system import CollisionSystem
from managers.resource_manager import ResourceManager
from managers.sound_manager import SoundManager


class GameMode(Enum):
    """게임 모드 열거형"""
    MENU = "menu"
    PLAYING = "playing"
    PAUSED = "paused"
    GAME_OVER = "game_over"
    VICTORY = "victory"
    ACADEMY = "academy"
    GACHA = "gacha"


@dataclass
class GameConfig:
    """게임 설정 데이터 클래스"""
    width: int = 1024
    height: int = 768
    fps: int = 60
    title: str = "PingFighter (핑파이터)"
    fullscreen: bool = False
    vsync: bool = True
    audio_enabled: bool = True


class GameCore:
    """게임의 핵심 시스템을 관리하는 메인 클래스
    
    이 클래스는 게임의 초기화, 메인 루프, 상태 관리 등
    핵심 기능을 담당합니다.
    """
    
    def __init__(self, config: Optional[GameConfig] = None):
        """GameCore 초기화
        
        Args:
            config: 게임 설정. None이면 기본값 사용
        """
        self.config = config or GameConfig()
        self.running = False
        self.clock = None
        self.screen = None
        self.current_mode = GameMode.MENU
        
        # 서브시스템
        self.game_state = None
        self.event_manager = None
        self.renderer = None
        self.physics_engine = None
        self.collision_system = None
        self.resource_manager = None
        self.sound_manager = None
        
    def initialize(self) -> bool:
        """게임 시스템 초기화
        
        Returns:
            bool: 초기화 성공 여부
        """
        try:
            # Pygame 초기화
            pygame.init()
            
            # 화면 설정
            flags = pygame.DOUBLEBUF
            if self.config.fullscreen:
                flags |= pygame.FULLSCREEN
            if self.config.vsync:
                flags |= pygame.HWSURFACE
                
            self.screen = pygame.display.set_mode(
                (self.config.width, self.config.height),
                flags
            )
            pygame.display.set_caption(self.config.title)
            
            # 시계 초기화
            self.clock = pygame.time.Clock()
            
            # 서브시스템 초기화
            self._initialize_subsystems()
            
            return True
            
        except Exception as e:
            print(f"게임 초기화 실패: {e}")
            return False
    
    def _initialize_subsystems(self):
        """서브시스템 초기화"""
        # 게임 상태 관리자
        self.game_state = GameState.get_instance()
        
        # 이벤트 관리자
        self.event_manager = EventManager.get_instance()
        
        # 리소스 관리자
        self.resource_manager = ResourceManager()
        self.resource_manager.initialize()
        
        # 사운드 관리자
        if self.config.audio_enabled:
            self.sound_manager = SoundManager()
            self.sound_manager.initialize()
        
        # 렌더러
        self.renderer = GameRenderer(self.screen)
        
        # 물리 엔진
        self.physics_engine = PhysicsEngine()
        
        # 충돌 시스템
        self.collision_system = CollisionSystem()
    
    def run(self):
        """메인 게임 루프"""
        if not self.initialize():
            print("게임 초기화 실패")
            return
            
        self.running = True
        
        while self.running:
            # 델타 타임 계산
            dt = self.clock.tick(self.config.fps) / 1000.0
            
            # 이벤트 처리
            self._handle_events()
            
            # 게임 로직 업데이트
            self._update(dt)
            
            # 렌더링
            self._render()
            
            # 화면 업데이트
            pygame.display.flip()
        
        self.cleanup()
    
    def _handle_events(self):
        """이벤트 처리"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    if self.current_mode == GameMode.PLAYING:
                        self.pause_game()
                    elif self.current_mode == GameMode.PAUSED:
                        self.resume_game()
            
            # 이벤트 매니저로 전달
            self.event_manager.handle_pygame_event(event)
    
    def _update(self, dt: float):
        """게임 상태 업데이트
        
        Args:
            dt: 델타 타임 (초 단위)
        """
        if self.current_mode == GameMode.PLAYING:
            # 물리 업데이트
            self.physics_engine.update(dt)
            
            # 충돌 검사
            self.collision_system.check_collisions()
            
            # 게임 상태 업데이트
            self.game_state.update(dt)
            
        elif self.current_mode == GameMode.MENU:
            # 메뉴 업데이트
            pass
            
        # 이벤트 처리
        self.event_manager.process_events()
    
    def _render(self):
        """화면 렌더링"""
        # 화면 지우기
        self.screen.fill((0, 0, 0))
        
        # 현재 모드에 따른 렌더링
        if self.current_mode == GameMode.PLAYING:
            self.renderer.render_game(self.game_state)
        elif self.current_mode == GameMode.MENU:
            self.renderer.render_menu()
        elif self.current_mode == GameMode.PAUSED:
            self.renderer.render_pause_menu()
        elif self.current_mode == GameMode.GAME_OVER:
            self.renderer.render_game_over()
        elif self.current_mode == GameMode.VICTORY:
            self.renderer.render_victory()
    
    def pause_game(self):
        """게임 일시정지"""
        if self.current_mode == GameMode.PLAYING:
            self.current_mode = GameMode.PAUSED
            self.event_manager.emit(EventType.GAME_PAUSED)
    
    def resume_game(self):
        """게임 재개"""
        if self.current_mode == GameMode.PAUSED:
            self.current_mode = GameMode.PLAYING
            self.event_manager.emit(EventType.GAME_RESUMED)
    
    def start_new_game(self, stage: int = 1):
        """새 게임 시작
        
        Args:
            stage: 시작 스테이지 번호
        """
        self.game_state.reset()
        self.game_state.current_stage = stage
        self.current_mode = GameMode.PLAYING
        self.event_manager.emit(EventType.GAME_STARTED)
    
    def cleanup(self):
        """리소스 정리"""
        if self.sound_manager:
            self.sound_manager.cleanup()
        if self.resource_manager:
            self.resource_manager.cleanup()
        pygame.quit()
        sys.exit()


def create_game(config: Optional[GameConfig] = None) -> GameCore:
    """게임 인스턴스 생성 헬퍼 함수
    
    Args:
        config: 게임 설정
        
    Returns:
        GameCore: 생성된 게임 인스턴스
    """
    return GameCore(config)


if __name__ == "__main__":
    # 테스트용 실행
    game = create_game()
    game.run()