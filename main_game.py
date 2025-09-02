#!/usr/bin/env python3
"""
🎮 PingFighter - Optimized Modular Version
22,000줄 → 500줄로 압축된 메인 게임 파일
"""

import pygame
import sys
from dataclasses import dataclass
from typing import Optional, Dict, Any

# 핵심 모듈 임포트
from core.game_engine import GameEngine
from core.constants import *
from entities.ball import Ball
from entities.paddle import Paddle
from entities.boss import BossFactory
from managers.sound_manager import SoundManager
from managers.effects_manager import EffectsManager
from managers.resource_manager import ResourceManager
from rendering.renderer import Renderer
from game_logic.collision_manager import CollisionManager
from game_logic.score_manager import ScoreManager
from game_logic.physics_manager import PhysicsManager
from ui.hud_display import HUDDisplay
from ui.pause_menu import PauseMenu


@dataclass
class GameState:
    """게임 상태 관리"""
    running: bool = True
    paused: bool = False
    current_stage: int = 1
    score: int = 0
    lives: int = 3
    combo: int = 0
    
    
class PingFighterGame:
    """메인 게임 클래스 - 모든 시스템 통합"""
    
    def __init__(self):
        pygame.init()
        self.screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
        pygame.display.set_caption("PingFighter - Modular")
        self.clock = pygame.time.Clock()
        
        # 게임 상태
        self.state = GameState()
        
        # 매니저 초기화
        self.sound_manager = SoundManager()
        self.effects_manager = EffectsManager()
        self.resource_manager = ResourceManager()
        self.collision_manager = CollisionManager()
        self.score_manager = ScoreManager()
        self.physics_manager = PhysicsManager()
        
        # 렌더러
        self.renderer = Renderer(self.screen)
        
        # UI
        self.hud = HUDDisplay()
        self.pause_menu = PauseMenu()
        
        # 게임 오브젝트
        self.ball: Optional[Ball] = None
        self.paddle: Optional[Paddle] = None
        self.boss: Optional[Any] = None
        self.items: list = []
        
        self.init_stage()
        
    def init_stage(self):
        """스테이지 초기화"""
        # 공과 패들 생성
        self.ball = Ball(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2)
        self.paddle = Paddle(SCREEN_WIDTH // 2, SCREEN_HEIGHT - 50)
        
        # 보스 생성
        self.boss = BossFactory.create_boss(
            self.state.current_stage,
            SCREEN_WIDTH // 2,
            100
        )
        
        # 배경음악 재생
        self.sound_manager.play_bgm(f"stage{self.state.current_stage}")
        
    def handle_events(self):
        """이벤트 처리"""
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                self.state.running = False
                
            elif event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    self.state.paused = not self.state.paused
                    
                elif event.key == pygame.K_SPACE and not self.state.paused:
                    # 대시 실행
                    self.paddle.dash()
                    self.sound_manager.play_sfx("dash")
                    
            elif event.type == pygame.MOUSEMOTION and not self.state.paused:
                # 패들 이동
                self.paddle.move_to(event.pos[0])
                
    def update(self, dt: float):
        """게임 로직 업데이트"""
        if self.state.paused:
            return
            
        # 공 업데이트
        self.ball.update(dt)
        self.physics_manager.apply_physics(self.ball, dt)
        
        # 패들 업데이트
        self.paddle.update(dt)
        
        # 보스 업데이트
        if self.boss:
            self.boss.update(dt, self.ball, self.paddle)
            
        # 충돌 검사
        self.check_collisions()
        
        # 아이템 업데이트
        for item in self.items[:]:
            item.update(dt)
            if item.expired:
                self.items.remove(item)
                
        # 이펙트 업데이트
        self.effects_manager.update(dt)
        
        # 게임 오버 체크
        if self.ball.y > SCREEN_HEIGHT:
            self.handle_ball_lost()
            
    def check_collisions(self):
        """충돌 검사"""
        # 공-패들 충돌
        if self.collision_manager.check_ball_paddle(self.ball, self.paddle):
            self.sound_manager.play_sfx("hit_paddle")
            self.state.combo += 1
            self.score_manager.add_score(100 * self.state.combo)
            
        # 공-보스 충돌
        if self.boss and self.collision_manager.check_ball_boss(self.ball, self.boss):
            self.sound_manager.play_sfx("hit_boss")
            self.boss.take_damage(10)
            self.score_manager.add_score(500)
            
            if self.boss.health <= 0:
                self.handle_boss_defeated()
                
        # 공-벽 충돌
        if self.collision_manager.check_ball_walls(self.ball):
            self.sound_manager.play_sfx("wall_bounce")
            
        # 아이템 수집
        for item in self.items[:]:
            if self.collision_manager.check_paddle_item(self.paddle, item):
                self.sound_manager.play_sfx("item_collect")
                item.apply_effect(self.state)
                self.items.remove(item)
                
    def handle_ball_lost(self):
        """공 놓쳤을 때 처리"""
        self.state.lives -= 1
        self.state.combo = 0
        self.sound_manager.play_sfx("ball_lost")
        
        if self.state.lives <= 0:
            self.game_over()
        else:
            self.reset_ball()
            
    def handle_boss_defeated(self):
        """보스 처치 처리"""
        self.sound_manager.play_sfx("boss_defeated")
        self.score_manager.add_score(10000)
        self.effects_manager.create_explosion(self.boss.x, self.boss.y)
        
        # 다음 스테이지
        self.state.current_stage += 1
        if self.state.current_stage <= MAX_STAGES:
            self.init_stage()
        else:
            self.victory()
            
    def reset_ball(self):
        """공 리셋"""
        self.ball.reset(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2)
        self.ball.launch()
        
    def render(self):
        """렌더링"""
        # 배경 그리기
        self.renderer.draw_background(self.state.current_stage)
        
        # 게임 오브젝트 그리기
        if self.boss:
            self.renderer.draw_boss(self.boss)
            
        self.renderer.draw_paddle(self.paddle)
        self.renderer.draw_ball(self.ball)
        
        # 아이템 그리기
        for item in self.items:
            self.renderer.draw_item(item)
            
        # 이펙트 그리기
        self.effects_manager.render(self.screen)
        
        # HUD 그리기
        self.hud.render(
            self.screen,
            score=self.state.score,
            lives=self.state.lives,
            combo=self.state.combo,
            stage=self.state.current_stage
        )
        
        # 일시정지 메뉴
        if self.state.paused:
            self.pause_menu.render(self.screen)
            
        pygame.display.flip()
        
    def game_over(self):
        """게임 오버 처리"""
        self.sound_manager.play_sfx("game_over")
        # 게임 오버 화면 표시
        self.show_game_over_screen()
        self.state.running = False
        
    def victory(self):
        """승리 처리"""
        self.sound_manager.play_sfx("victory")
        # 승리 화면 표시
        self.show_victory_screen()
        self.state.running = False
        
    def show_game_over_screen(self):
        """게임 오버 화면"""
        font = pygame.font.Font(None, 72)
        text = font.render("GAME OVER", True, (255, 0, 0))
        text_rect = text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2))
        
        self.screen.fill((0, 0, 0))
        self.screen.blit(text, text_rect)
        
        score_text = font.render(f"Score: {self.state.score}", True, (255, 255, 255))
        score_rect = score_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 100))
        self.screen.blit(score_text, score_rect)
        
        pygame.display.flip()
        pygame.time.wait(3000)
        
    def show_victory_screen(self):
        """승리 화면"""
        font = pygame.font.Font(None, 72)
        text = font.render("VICTORY!", True, (255, 215, 0))
        text_rect = text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2))
        
        self.screen.fill((0, 0, 0))
        self.screen.blit(text, text_rect)
        
        score_text = font.render(f"Final Score: {self.state.score}", True, (255, 255, 255))
        score_rect = score_text.get_rect(center=(SCREEN_WIDTH // 2, SCREEN_HEIGHT // 2 + 100))
        self.screen.blit(score_text, score_rect)
        
        pygame.display.flip()
        pygame.time.wait(5000)
        
    def run(self):
        """메인 게임 루프"""
        while self.state.running:
            dt = self.clock.tick(FPS) / 1000.0  # Delta time in seconds
            
            self.handle_events()
            self.update(dt)
            self.render()
            
        self.cleanup()
        
    def cleanup(self):
        """리소스 정리"""
        self.sound_manager.cleanup()
        self.resource_manager.cleanup()
        pygame.quit()
        

def main():
    """메인 함수"""
    game = PingFighterGame()
    game.run()
    

if __name__ == "__main__":
    main()