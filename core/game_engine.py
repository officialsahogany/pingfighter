"""
🎮 PingFighter Game Engine
핵심 게임 엔진 - 메인 루프 및 상태 관리
"""

import pygame
import sys
import random
import time
from typing import Optional, Dict, Any, Tuple
from dataclasses import dataclass, field
from enum import Enum

# Core imports
from core.game_state import GameState
from core.events import EventManager, EventType
from core.constants import *
from core.input_keys import (
    is_move_left_key,
    is_move_right_key,
    is_move_left_event,
    is_move_right_event,
)

# Manager imports
from managers.sound_manager import SoundManager
from managers.effects_manager import EffectsManager
from managers.resource_manager import ResourceManager

# Entity imports
from entities.ball import Ball
from entities.paddle import Paddle
from entities.boss import Boss

# Game Logic imports
from game_logic.collision_manager import CollisionManager
from game_logic.physics_engine import PhysicsEngine
from game_logic.score_manager import ScoreManager
from game_logic.round_manager import RoundManager

# Rendering imports
from rendering.renderer import GameRenderer

# UI imports
from ui.menu_system import MenuSystem
from ui.hud_display import HUDDisplay
from ui.pause_menu import PauseMenu


class GameMode(Enum):
    """게임 모드 열거형"""
    MENU = "menu"
    PLAYING = "playing"
    PAUSED = "paused"
    GAME_OVER = "game_over"
    VICTORY = "victory"


@dataclass
class GameConfig:
    """게임 설정 데이터 클래스"""
    screen_width: int = 600
    screen_height: int = 750
    fps: int = 60
    stage: int = 1
    difficulty: str = "normal"
    sound_enabled: bool = True
    fullscreen: bool = False
    

class GameEngine:
    """
    🎮 핵심 게임 엔진 클래스
    
    게임의 메인 루프, 상태 관리, 이벤트 처리를 담당합니다.
    모든 게임 시스템의 중앙 컨트롤러 역할을 합니다.
    """
    
    def __init__(self, config: Optional[GameConfig] = None):
        """
        게임 엔진 초기화
        
        Args:
            config: 게임 설정 (None일 경우 기본값 사용)
        """
        self.config = config or GameConfig()
        self.running = False
        self.mode = GameMode.MENU
        
        # Pygame 초기화
        pygame.init()
        
        # 화면 설정
        self._setup_display()
        
        # 시스템 초기화
        self._initialize_systems()
        
        # 게임 상태 초기화
        self._initialize_game_state()
        
        # 이벤트 핸들러 등록
        self._register_event_handlers()
        
        print("🎮 게임 엔진 초기화 완료")
    
    def _setup_display(self):
        """디스플레이 설정"""
        flags = pygame.FULLSCREEN if self.config.fullscreen else 0
        self.screen = pygame.display.set_mode(
            (self.config.screen_width, self.config.screen_height),
            flags
        )
        pygame.display.set_caption("PingFighter")
        self.clock = pygame.time.Clock()
    
    def _initialize_systems(self):
        """게임 시스템 초기화"""
        # 매니저 초기화
        self.sound_manager = SoundManager(enabled=self.config.sound_enabled)
        self.effects_manager = EffectsManager()
        self.resource_manager = ResourceManager()
        
        # 게임 로직 초기화
        self.collision_manager = CollisionManager()
        self.physics_engine = PhysicsEngine()
        self.score_manager = ScoreManager()
        self.round_manager = RoundManager()
        
        # 렌더링 시스템 초기화
        self.renderer = GameRenderer(self.screen)
        
        # UI 시스템 초기화
        self.menu_system = MenuSystem(self.screen)
        self.hud_display = HUDDisplay(self.screen)
        self.pause_menu = PauseMenu(self.screen)
        
        # 이벤트 매니저
        self.event_manager = EventManager.get_instance()
        
        # 게임 상태
        self.game_state = GameState.get_instance()
    
    def _initialize_game_state(self):
        """게임 상태 초기화"""
        # 엔티티 생성
        self.ball = Ball(
            self.config.screen_width // 2,
            self.config.screen_height // 2
        )
        self.paddle = Paddle(
            self.config.screen_width // 2,
            self.config.screen_height - 50
        )
        self.boss = Boss(
            self.config.screen_width // 2,
            50,
            self.config.stage
        )
        
        # 게임 변수 초기화
        self.stage = self.config.stage
        self.round_wins = 0
        self.round_losses = 0
        self.paused = False
        
        # 타이머 초기화
        self.last_update_time = pygame.time.get_ticks()
        self.delta_time = 0
    
    def _register_event_handlers(self):
        """이벤트 핸들러 등록"""
        self.event_manager.register(EventType.GAME_START, self._on_game_start)
        self.event_manager.register(EventType.GAME_OVER, self._on_game_over)
        self.event_manager.register(EventType.ROUND_WIN, self._on_round_win)
        self.event_manager.register(EventType.ROUND_LOSE, self._on_round_lose)
        self.event_manager.register(EventType.PAUSE, self._on_pause)
        self.event_manager.register(EventType.RESUME, self._on_resume)
    
    def run(self):
        """메인 게임 루프 실행"""
        self.running = True
        print("🎮 게임 시작!")
        
        while self.running:
            # 델타 타임 계산
            current_time = pygame.time.get_ticks()
            self.delta_time = (current_time - self.last_update_time) / 1000.0
            self.last_update_time = current_time
            
            # 이벤트 처리
            self._handle_events()
            
            # 게임 모드별 업데이트
            if self.mode == GameMode.MENU:
                self._update_menu()
            elif self.mode == GameMode.PLAYING:
                self._update_game()
            elif self.mode == GameMode.PAUSED:
                self._update_pause()
            elif self.mode == GameMode.GAME_OVER:
                self._update_game_over()
            elif self.mode == GameMode.VICTORY:
                self._update_victory()
            
            # 렌더링
            self._render()
            
            # FPS 제한
            self.clock.tick(self.config.fps)
        
        self._cleanup()
    
    def _handle_events(self):
        """이벤트 처리"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.running = False
            
            # 키보드 이벤트
            elif event.type == pygame.KEYDOWN:
                self._handle_keydown(event)
            elif event.type == pygame.KEYUP:
                self._handle_keyup(event)
            
            # 마우스 이벤트
            elif event.type == pygame.MOUSEBUTTONDOWN:
                self._handle_mousedown(event)
    
    def _handle_keydown(self, event):
        """키 다운 이벤트 처리"""
        if event.key == pygame.K_ESCAPE:
            if self.mode == GameMode.PLAYING:
                self.toggle_pause()
            elif self.mode == GameMode.PAUSED:
                self.resume_game()
        
        elif event.key == pygame.K_SPACE and self.mode == GameMode.PLAYING:
            # 대쉬 또는 특수 능력 활성화
            self.paddle.activate_dash()
        
        elif is_move_left_event(event):
            self.paddle.start_move_left()
        elif is_move_right_event(event):
            self.paddle.start_move_right()
    
    def _handle_keyup(self, event):
        """키 업 이벤트 처리"""
        if is_move_left_event(event):
            self.paddle.stop_move_left()
        elif is_move_right_event(event):
            self.paddle.stop_move_right()
    
    def _handle_mousedown(self, event):
        """마우스 다운 이벤트 처리"""
        if self.mode == GameMode.MENU:
            self.menu_system.handle_click(event.pos)
        elif self.mode == GameMode.PAUSED:
            self.pause_menu.handle_click(event.pos)
    
    def _update_menu(self):
        """메뉴 업데이트"""
        result = self.menu_system.update(self.delta_time)
        if result == "start_game":
            self.start_game()
        elif result == "quit":
            self.running = False
    
    def _update_game(self):
        """게임 플레이 업데이트"""
        # 물리 업데이트
        self.physics_engine.update(
            self.ball, 
            self.paddle, 
            self.boss, 
            self.delta_time
        )
        
        # 충돌 체크
        collisions = self.collision_manager.check_collisions(
            self.ball, 
            self.paddle, 
            self.boss
        )
        
        # 충돌 처리
        for collision in collisions:
            self._handle_collision(collision)
        
        # 엔티티 업데이트
        self.ball.update(self.delta_time)
        self.paddle.update(self.delta_time)
        self.boss.update(self.delta_time, self.ball)
        
        # 이펙트 업데이트
        self.effects_manager.update(self.delta_time)
        
        # 득점 체크
        self._check_scoring()
        
        # 라운드 종료 체크
        if self.round_manager.is_round_complete():
            self._handle_round_complete()
    
    def _update_pause(self):
        """일시정지 상태 업데이트"""
        result = self.pause_menu.update(self.delta_time)
        if result == "resume":
            self.resume_game()
        elif result == "quit":
            self.mode = GameMode.MENU
    
    def _update_game_over(self):
        """게임 오버 상태 업데이트"""
        # 게임 오버 화면 업데이트
        pass
    
    def _update_victory(self):
        """승리 상태 업데이트"""
        # 승리 화면 업데이트
        pass
    
    def _render(self):
        """렌더링"""
        # 화면 클리어
        self.screen.fill((0, 0, 0))
        
        # 게임 모드별 렌더링
        if self.mode == GameMode.MENU:
            self.menu_system.render()
        elif self.mode == GameMode.PLAYING:
            self._render_game()
        elif self.mode == GameMode.PAUSED:
            self._render_game()  # 게임 화면 그리기
            self.pause_menu.render()  # 일시정지 메뉴 오버레이
        elif self.mode == GameMode.GAME_OVER:
            self._render_game_over()
        elif self.mode == GameMode.VICTORY:
            self._render_victory()
        
        # 화면 업데이트
        pygame.display.flip()
    
    def _render_game(self):
        """게임 플레이 렌더링"""
        # 배경 렌더링
        self.renderer.render_background(self.stage)
        
        # 엔티티 렌더링
        self.renderer.render_entity(self.boss)
        self.renderer.render_entity(self.paddle)
        self.renderer.render_entity(self.ball)
        
        # 이펙트 렌더링
        self.effects_manager.render(self.screen)
        
        # HUD 렌더링
        self.hud_display.render(
            score=(self.round_wins, self.round_losses),
            gauge=self.paddle.dash_gauge,
            stage=self.stage
        )
    
    def _render_game_over(self):
        """게임 오버 화면 렌더링"""
        # 게임 오버 화면 렌더링
        font = pygame.font.Font(None, 72)
        text = font.render("GAME OVER", True, (255, 0, 0))
        text_rect = text.get_rect(center=(self.config.screen_width // 2, self.config.screen_height // 2))
        self.screen.blit(text, text_rect)
    
    def _render_victory(self):
        """승리 화면 렌더링"""
        # 승리 화면 렌더링
        font = pygame.font.Font(None, 72)
        text = font.render("VICTORY!", True, (255, 215, 0))
        text_rect = text.get_rect(center=(self.config.screen_width // 2, self.config.screen_height // 2))
        self.screen.blit(text, text_rect)
    
    def _handle_collision(self, collision):
        """충돌 처리"""
        collision_type = collision['type']
        
        if collision_type == 'paddle':
            self.sound_manager.play('paddle_hit')
            self.effects_manager.create_impact(collision['position'])
        elif collision_type == 'boss':
            self.sound_manager.play('boss_hit')
            self.effects_manager.create_spark(collision['position'])
        elif collision_type == 'wall':
            self.sound_manager.play('wall_hit')
    
    def _check_scoring(self):
        """득점 체크"""
        # 공이 아래로 떨어진 경우 (보스 득점)
        if self.ball.y > self.config.screen_height:
            self.round_losses += 1
            self.event_manager.emit(EventType.ROUND_LOSE)
            self.reset_round()
        
        # 공이 위로 올라간 경우 (플레이어 득점)
        elif self.ball.y < 0:
            self.round_wins += 1
            self.event_manager.emit(EventType.ROUND_WIN)
            self.reset_round()
    
    def _handle_round_complete(self):
        """라운드 완료 처리"""
        if self.round_wins >= 3:
            # 스테이지 클리어
            self.mode = GameMode.VICTORY
            self.event_manager.emit(EventType.STAGE_CLEAR)
        elif self.round_losses >= 3:
            # 게임 오버
            self.mode = GameMode.GAME_OVER
            self.event_manager.emit(EventType.GAME_OVER)
    
    def reset_round(self):
        """라운드 리셋"""
        # 공 위치 리셋
        self.ball.reset(
            self.config.screen_width // 2,
            self.config.screen_height // 2
        )
        
        # 패들 위치 리셋
        self.paddle.reset(
            self.config.screen_width // 2,
            self.config.screen_height - 50
        )
        
        # 보스 위치 리셋
        self.boss.reset(
            self.config.screen_width // 2,
            50
        )
    
    def start_game(self):
        """게임 시작"""
        self.mode = GameMode.PLAYING
        self.round_wins = 0
        self.round_losses = 0
        self.reset_round()
        self.event_manager.emit(EventType.GAME_START)
        print("🎮 게임 플레이 시작!")
    
    def toggle_pause(self):
        """일시정지 토글"""
        if self.mode == GameMode.PLAYING:
            self.mode = GameMode.PAUSED
            self.event_manager.emit(EventType.PAUSE)
            print("⏸️ 게임 일시정지")
        elif self.mode == GameMode.PAUSED:
            self.resume_game()
    
    def resume_game(self):
        """게임 재개"""
        self.mode = GameMode.PLAYING
        self.event_manager.emit(EventType.RESUME)
        print("▶️ 게임 재개")
    
    def _on_game_start(self, event_data):
        """게임 시작 이벤트 핸들러"""
        print("🎮 게임 시작 이벤트 처리")
    
    def _on_game_over(self, event_data):
        """게임 오버 이벤트 핸들러"""
        print("💀 게임 오버 이벤트 처리")
    
    def _on_round_win(self, event_data):
        """라운드 승리 이벤트 핸들러"""
        print(f"✅ 라운드 승리! ({self.round_wins}/{self.round_losses})")
    
    def _on_round_lose(self, event_data):
        """라운드 패배 이벤트 핸들러"""
        print(f"❌ 라운드 패배! ({self.round_wins}/{self.round_losses})")
    
    def _on_pause(self, event_data):
        """일시정지 이벤트 핸들러"""
        pass
    
    def _on_resume(self, event_data):
        """재개 이벤트 핸들러"""
        pass
    
    def _cleanup(self):
        """정리 작업"""
        print("🎮 게임 엔진 종료 중...")
        self.sound_manager.cleanup()
        self.effects_manager.cleanup()
        self.resource_manager.cleanup()
        pygame.quit()
        print("👋 게임 종료 완료")


# 단독 실행 테스트
if __name__ == "__main__":
    # 테스트용 설정
    config = GameConfig(
        stage=1,
        difficulty="normal",
        sound_enabled=True
    )
    
    # 게임 엔진 생성 및 실행
    engine = GameEngine(config)
    engine.run()
