# -*- coding: utf-8 -*-
"""
게임 렌더러 모듈
모든 게임 요소의 그리기를 담당
"""

import pygame
import math
from typing import Optional, Tuple, List, Any
from dataclasses import dataclass


@dataclass
class RenderConfig:
    """렌더링 설정"""
    enable_particles: bool = True
    enable_glow: bool = True
    enable_shadows: bool = True
    enable_antialiasing: bool = True
    particle_quality: int = 2  # 1: Low, 2: Medium, 3: High
    

class GameRenderer:
    """게임 렌더링 시스템
    
    모든 게임 요소를 화면에 그리는 책임을 담당합니다.
    """
    
    def __init__(self, screen: pygame.Surface):
        """렌더러 초기화
        
        Args:
            screen: Pygame 화면 객체
        """
        self.screen = screen
        self.config = RenderConfig()
        
        # 화면 크기
        self.width = screen.get_width()
        self.height = screen.get_height()
        
        # 레이어 서페이스
        self.background_layer = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self.game_layer = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self.effect_layer = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self.ui_layer = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        # 색상 정의
        self.colors = {
            'white': (255, 255, 255),
            'black': (0, 0, 0),
            'red': (255, 0, 0),
            'green': (0, 255, 0),
            'blue': (0, 0, 255),
            'yellow': (255, 255, 0),
            'cyan': (0, 255, 255),
            'magenta': (255, 0, 255),
            'gray': (128, 128, 128),
        }
        
        # 파티클 시스템
        self.particles = []
        
    def render_game(self, game_state):
        """게임 화면 렌더링
        
        Args:
            game_state: 게임 상태 객체
        """
        # 레이어 초기화
        self._clear_layers()
        
        # 배경 렌더링
        self._render_background(game_state)
        
        # 게임 객체 렌더링
        self._render_game_objects(game_state)
        
        # 이펙트 렌더링
        if self.config.enable_particles:
            self._render_particles()
        
        # UI 렌더링
        self._render_ui(game_state)
        
        # 레이어 합성
        self._composite_layers()
    
    def _clear_layers(self):
        """모든 레이어 초기화"""
        self.background_layer.fill((0, 0, 0, 0))
        self.game_layer.fill((0, 0, 0, 0))
        self.effect_layer.fill((0, 0, 0, 0))
        self.ui_layer.fill((0, 0, 0, 0))
    
    def _render_background(self, game_state):
        """배경 렌더링"""
        # 스테이지별 배경색
        stage_colors = {
            1: (20, 30, 40),    # 어두운 파랑
            2: (40, 20, 30),    # 어두운 빨강
            3: (30, 20, 40),    # 어두운 보라
            4: (40, 40, 20),    # 어두운 노랑
            5: (40, 30, 20),    # 어두운 주황
            6: (20, 40, 30),    # 어두운 초록
        }
        
        stage = getattr(game_state, 'current_stage', 1)
        bg_color = stage_colors.get(stage, (20, 20, 20))
        self.background_layer.fill(bg_color)
        
        # 그라데이션 효과
        self._draw_gradient(self.background_layer, bg_color, (0, 0, 0))
    
    def _render_game_objects(self, game_state):
        """게임 객체 렌더링"""
        # 공 렌더링
        if hasattr(game_state, 'ball'):
            self._render_ball(game_state.ball)
        
        # 패들 렌더링
        if hasattr(game_state, 'player_paddle'):
            self._render_paddle(game_state.player_paddle, is_player=True)
        
        if hasattr(game_state, 'boss_paddle'):
            self._render_paddle(game_state.boss_paddle, is_player=False)
        
        # 아이템 렌더링
        if hasattr(game_state, 'items'):
            for item in game_state.items:
                self._render_item(item)
    
    def _render_ball(self, ball):
        """공 렌더링"""
        if not ball or not hasattr(ball, 'x'):
            return
        
        # 그림자 효과
        if self.config.enable_shadows:
            shadow_pos = (int(ball.x + 5), int(ball.y + 5))
            pygame.draw.circle(self.game_layer, (0, 0, 0, 50), 
                             shadow_pos, ball.radius)
        
        # 공 본체
        pygame.draw.circle(self.game_layer, self.colors['white'],
                          (int(ball.x), int(ball.y)), ball.radius)
        
        # 발광 효과
        if self.config.enable_glow:
            self._draw_glow(self.effect_layer, (int(ball.x), int(ball.y)),
                          ball.radius + 5, (255, 255, 255, 30))
        
        # 꼬리 효과
        if hasattr(ball, 'trail'):
            self._render_trail(ball.trail)
    
    def _render_paddle(self, paddle, is_player=True):
        """패들 렌더링"""
        if not paddle or not hasattr(paddle, 'rect'):
            return
        
        color = self.colors['cyan'] if is_player else self.colors['red']
        
        # 그림자
        if self.config.enable_shadows:
            shadow_rect = paddle.rect.copy()
            shadow_rect.x += 3
            shadow_rect.y += 3
            pygame.draw.rect(self.game_layer, (0, 0, 0, 50), shadow_rect)
        
        # 패들 본체
        pygame.draw.rect(self.game_layer, color, paddle.rect)
        
        # 테두리
        pygame.draw.rect(self.game_layer, self.colors['white'], 
                        paddle.rect, 2)
        
        # 발광 효과
        if self.config.enable_glow and hasattr(paddle, 'powered_up') and paddle.powered_up:
            self._draw_rect_glow(self.effect_layer, paddle.rect, color)
    
    def _render_item(self, item):
        """아이템 렌더링"""
        if not item or not hasattr(item, 'rect'):
            return
        
        # 아이템 색상
        item_color = getattr(item, 'color', self.colors['yellow'])
        
        # 아이템 그리기
        pygame.draw.rect(self.game_layer, item_color, item.rect)
        pygame.draw.rect(self.game_layer, self.colors['white'], item.rect, 1)
        
        # 반짝임 효과
        if hasattr(item, 'sparkle_timer'):
            alpha = int(128 + 127 * math.sin(item.sparkle_timer * 0.1))
            sparkle_color = (*item_color, alpha)
            sparkle_rect = item.rect.inflate(4, 4)
            pygame.draw.rect(self.effect_layer, sparkle_color, sparkle_rect, 2)
    
    def _render_particles(self):
        """파티클 렌더링"""
        for particle in self.particles[:]:
            if not self._update_particle(particle):
                self.particles.remove(particle)
            else:
                self._draw_particle(particle)
    
    def _update_particle(self, particle) -> bool:
        """파티클 업데이트
        
        Returns:
            bool: 파티클이 살아있으면 True
        """
        particle['x'] += particle['vx']
        particle['y'] += particle['vy']
        particle['life'] -= 1
        
        # 중력 적용
        if 'gravity' in particle:
            particle['vy'] += particle['gravity']
        
        # 페이드 아웃
        if 'fade' in particle:
            particle['alpha'] = max(0, particle['alpha'] - particle['fade'])
        
        return particle['life'] > 0
    
    def _draw_particle(self, particle):
        """파티클 그리기"""
        color = particle.get('color', self.colors['white'])
        alpha = particle.get('alpha', 255)
        size = particle.get('size', 2)
        
        # 알파 채널이 있는 색상
        if len(color) == 3:
            color = (*color, alpha)
        
        pos = (int(particle['x']), int(particle['y']))
        
        if particle.get('type') == 'circle':
            pygame.draw.circle(self.effect_layer, color, pos, size)
        else:
            rect = pygame.Rect(pos[0] - size//2, pos[1] - size//2, size, size)
            pygame.draw.rect(self.effect_layer, color, rect)
    
    def _render_ui(self, game_state):
        """UI 렌더링"""
        # 점수 표시
        self._render_score(game_state)
        
        # 체력바 표시
        self._render_health_bars(game_state)
        
        # 게이지 표시
        self._render_gauges(game_state)
    
    def _render_score(self, game_state):
        """점수 표시"""
        if not hasattr(game_state, 'player_score'):
            return
        
        font = pygame.font.Font(None, 48)
        
        # 플레이어 점수
        player_text = font.render(str(game_state.player_score), True, self.colors['white'])
        player_rect = player_text.get_rect(center=(self.width // 4, 50))
        self.ui_layer.blit(player_text, player_rect)
        
        # 보스 점수
        if hasattr(game_state, 'boss_score'):
            boss_text = font.render(str(game_state.boss_score), True, self.colors['white'])
            boss_rect = boss_text.get_rect(center=(3 * self.width // 4, 50))
            self.ui_layer.blit(boss_text, boss_rect)
    
    def _render_health_bars(self, game_state):
        """체력바 렌더링"""
        # 플레이어 체력
        if hasattr(game_state, 'player_hp'):
            self._draw_health_bar(50, self.height - 30, 200, 20,
                                 game_state.player_hp, game_state.player_max_hp,
                                 self.colors['green'])
        
        # 보스 체력
        if hasattr(game_state, 'boss_hp'):
            self._draw_health_bar(self.width - 250, 30, 200, 20,
                                 game_state.boss_hp, game_state.boss_max_hp,
                                 self.colors['red'])
    
    def _draw_health_bar(self, x, y, width, height, current, maximum, color):
        """체력바 그리기"""
        # 배경
        bg_rect = pygame.Rect(x, y, width, height)
        pygame.draw.rect(self.ui_layer, (50, 50, 50), bg_rect)
        
        # 체력
        if maximum > 0:
            fill_width = int(width * current / maximum)
            fill_rect = pygame.Rect(x, y, fill_width, height)
            pygame.draw.rect(self.ui_layer, color, fill_rect)
        
        # 테두리
        pygame.draw.rect(self.ui_layer, self.colors['white'], bg_rect, 2)
    
    def _render_gauges(self, game_state):
        """게이지 렌더링"""
        if hasattr(game_state, 'special_gauge'):
            self._draw_gauge(50, self.height - 60, 200, 15,
                           game_state.special_gauge, 100,
                           self.colors['yellow'], "Special")
    
    def _draw_gauge(self, x, y, width, height, current, maximum, color, label):
        """게이지 그리기"""
        # 배경
        bg_rect = pygame.Rect(x, y, width, height)
        pygame.draw.rect(self.ui_layer, (30, 30, 30), bg_rect)
        
        # 게이지 채우기
        if maximum > 0:
            fill_width = int(width * current / maximum)
            fill_rect = pygame.Rect(x, y, fill_width, height)
            pygame.draw.rect(self.ui_layer, color, fill_rect)
        
        # 테두리
        pygame.draw.rect(self.ui_layer, self.colors['white'], bg_rect, 1)
        
        # 라벨
        font = pygame.font.Font(None, 12)
        text = font.render(label, True, self.colors['white'])
        self.ui_layer.blit(text, (x, y - 15))
    
    def _composite_layers(self):
        """레이어 합성"""
        self.screen.blit(self.background_layer, (0, 0))
        self.screen.blit(self.game_layer, (0, 0))
        self.screen.blit(self.effect_layer, (0, 0))
        self.screen.blit(self.ui_layer, (0, 0))
    
    def _draw_gradient(self, surface, color1, color2):
        """그라데이션 그리기"""
        for i in range(self.height):
            ratio = i / self.height
            r = int(color1[0] * (1 - ratio) + color2[0] * ratio)
            g = int(color1[1] * (1 - ratio) + color2[1] * ratio)
            b = int(color1[2] * (1 - ratio) + color2[2] * ratio)
            pygame.draw.line(surface, (r, g, b), (0, i), (self.width, i))
    
    def _draw_glow(self, surface, pos, radius, color):
        """발광 효과 그리기"""
        for i in range(3):
            alpha = color[3] // (i + 1) if len(color) > 3 else 50 // (i + 1)
            glow_color = (*color[:3], alpha) if len(color) > 3 else (*color, alpha)
            pygame.draw.circle(surface, glow_color, pos, radius + i * 3)
    
    def _draw_rect_glow(self, surface, rect, color):
        """사각형 발광 효과"""
        for i in range(3):
            alpha = 50 // (i + 1)
            glow_rect = rect.inflate(i * 6, i * 6)
            pygame.draw.rect(surface, (*color, alpha), glow_rect, 2)
    
    def _render_trail(self, trail_points):
        """꼬리 효과 렌더링"""
        if len(trail_points) < 2:
            return
        
        for i in range(len(trail_points) - 1):
            alpha = int(255 * (i / len(trail_points)))
            color = (*self.colors['white'], alpha)
            pygame.draw.line(self.effect_layer, color,
                           trail_points[i], trail_points[i + 1], 2)
    
    def spawn_particle(self, x, y, vx=0, vy=0, color=None, life=30, **kwargs):
        """파티클 생성
        
        Args:
            x, y: 시작 위치
            vx, vy: 속도
            color: 색상
            life: 수명
            **kwargs: 추가 속성
        """
        particle = {
            'x': x, 'y': y,
            'vx': vx, 'vy': vy,
            'color': color or self.colors['white'],
            'life': life,
            'alpha': 255,
            'size': 2,
            'type': 'circle',
            **kwargs
        }
        self.particles.append(particle)
    
    def spawn_explosion(self, x, y, color=None, particle_count=20):
        """폭발 효과 생성"""
        import random
        for _ in range(particle_count):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(2, 8)
            self.spawn_particle(
                x, y,
                math.cos(angle) * speed,
                math.sin(angle) * speed,
                color=color,
                life=random.randint(20, 40),
                gravity=0.3,
                fade=10
            )
    
    # 메뉴 렌더링 메서드들
    def render_menu(self):
        """메인 메뉴 렌더링"""
        self.screen.fill((20, 20, 40))
        
        font_title = pygame.font.Font(None, 72)
        font_option = pygame.font.Font(None, 36)
        
        # 타이틀
        title = font_title.render("PING FIGHTER", True, self.colors['white'])
        title_rect = title.get_rect(center=(self.width // 2, 150))
        self.screen.blit(title, title_rect)
        
        # 메뉴 옵션
        options = ["Start Game", "Options", "Quit"]
        for i, option in enumerate(options):
            text = font_option.render(option, True, self.colors['white'])
            rect = text.get_rect(center=(self.width // 2, 300 + i * 60))
            self.screen.blit(text, rect)
    
    def render_pause_menu(self):
        """일시정지 메뉴 렌더링"""
        # 반투명 오버레이
        overlay = pygame.Surface((self.width, self.height))
        overlay.set_alpha(128)
        overlay.fill((0, 0, 0))
        self.screen.blit(overlay, (0, 0))
        
        font = pygame.font.Font(None, 48)
        text = font.render("PAUSED", True, self.colors['white'])
        rect = text.get_rect(center=(self.width // 2, self.height // 2))
        self.screen.blit(text, rect)
        
        font_small = pygame.font.Font(None, 24)
        text_small = font_small.render("Press ESC to continue", True, self.colors['white'])
        rect_small = text_small.get_rect(center=(self.width // 2, self.height // 2 + 50))
        self.screen.blit(text_small, rect_small)
    
    def render_game_over(self):
        """게임 오버 화면 렌더링"""
        self.screen.fill((40, 0, 0))
        
        font = pygame.font.Font(None, 72)
        text = font.render("GAME OVER", True, self.colors['red'])
        rect = text.get_rect(center=(self.width // 2, self.height // 2))
        self.screen.blit(text, rect)
    
    def render_victory(self):
        """승리 화면 렌더링"""
        self.screen.fill((0, 40, 0))
        
        font = pygame.font.Font(None, 72)
        text = font.render("VICTORY!", True, self.colors['green'])
        rect = text.get_rect(center=(self.width // 2, self.height // 2))
        self.screen.blit(text, rect)