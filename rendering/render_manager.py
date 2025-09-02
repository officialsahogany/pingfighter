"""
Render Manager - 통합 렌더링 관리자
모든 렌더러를 통합 관리하고 렌더링 순서를 제어
"""
import pygame
from typing import Dict, Any, Optional, Tuple, List
from .ball_renderer import BallRenderer, BallEffectManager
from .paddle_renderer import PaddleRenderer
from .ui_renderer import UIRenderer
from .effect_renderer import EffectRenderer

class RenderManager:
    """렌더링 매니저 - 모든 렌더링 시스템 통합 관리"""
    
    def __init__(self, screen: pygame.Surface):
        """초기화
        
        Args:
            screen: 메인 화면 Surface
        """
        self.screen = screen
        self.width = screen.get_width()
        self.height = screen.get_height()
        
        # 각 렌더러 초기화
        self.ball_renderer = BallRenderer(screen)
        self.ball_effect_manager = BallEffectManager()
        self.paddle_renderer = PaddleRenderer(screen)
        self.ui_renderer = UIRenderer(screen)
        self.effect_renderer = EffectRenderer(screen)
        
        # 레이어 시스템 (렌더링 순서)
        self.layers = {
            'background': 0,
            'game_objects': 1,
            'effects': 2,
            'ui': 3,
            'overlay': 4
        }
        
        # 렌더링 설정
        self.settings = {
            'enable_particles': True,
            'enable_glow': True,
            'enable_screen_shake': True,
            'particle_quality': 'high',  # 'low', 'medium', 'high'
            'render_debug': False
        }
        
        # 성능 모니터링
        self.frame_times = []
        self.max_frame_history = 60
        
    def render_frame(self, game_state: Dict[str, Any]):
        """전체 프레임 렌더링
        
        Args:
            game_state: 게임 상태 딕셔너리
        """
        # 렌더링 시작 시간 기록
        start_time = pygame.time.get_ticks()
        
        # 화면 흔들림 효과 가져오기
        shake_offset = self.effect_renderer.render()
        
        # Layer 0: 배경
        self._render_background(game_state, shake_offset)
        
        # Layer 1: 게임 객체
        self._render_game_objects(game_state, shake_offset)
        
        # Layer 2: 이펙트
        self._render_effects(shake_offset)
        
        # Layer 3: UI
        self._render_ui(game_state)
        
        # Layer 4: 오버레이 (디버그 정보 등)
        if self.settings['render_debug']:
            self._render_debug_info()
        
        # 렌더링 시간 기록
        render_time = pygame.time.get_ticks() - start_time
        self._update_performance_metrics(render_time)
    
    def _render_background(self, game_state: Dict[str, Any], shake_offset: Tuple[int, int]):
        """배경 렌더링
        
        Args:
            game_state: 게임 상태
            shake_offset: 화면 흔들림 오프셋
        """
        # 배경은 game_state에서 가져오거나 별도 배경 렌더러 사용
        background = game_state.get('background')
        if background:
            # 화면 흔들림 적용
            if shake_offset != (0, 0):
                self.screen.blit(background, shake_offset)
            else:
                self.screen.blit(background, (0, 0))
    
    def _render_game_objects(self, game_state: Dict[str, Any], shake_offset: Tuple[int, int]):
        """게임 객체 렌더링
        
        Args:
            game_state: 게임 상태
            shake_offset: 화면 흔들림 오프셋
        """
        # 임시 서페이스에 렌더링 (화면 흔들림용)
        if shake_offset != (0, 0):
            temp_surface = pygame.Surface((self.width, self.height))
            temp_surface.blit(self.screen, (0, 0))
            
            # 게임 객체들을 임시 서페이스에 렌더링
            self._render_on_surface(temp_surface, game_state)
            
            # 흔들림 효과 적용하여 메인 화면에 블릿
            self.screen.blit(temp_surface, shake_offset)
        else:
            self._render_on_surface(self.screen, game_state)
    
    def _render_on_surface(self, surface: pygame.Surface, game_state: Dict[str, Any]):
        """특정 서페이스에 게임 객체 렌더링
        
        Args:
            surface: 렌더링할 서페이스
            game_state: 게임 상태
        """
        # 보스 패들 렌더링
        boss_data = game_state.get('boss')
        if boss_data:
            self.paddle_renderer.render_boss_paddle(
                boss_data.get('rect', pygame.Rect(300, 50, 100, 20)),
                boss_data.get('color', (255, 0, 0)),
                boss_data.get('stage', 1),
                boss_data.get('is_rage', False),
                boss_data.get('special_attack')
            )
        
        # 플레이어 패들 렌더링
        player_data = game_state.get('player')
        if player_data:
            self.paddle_renderer.render_player_paddle(
                player_data.get('rect', pygame.Rect(250, 700, 100, 20)),
                player_data.get('color', (0, 255, 0)),
                player_data.get('is_dashing', False),
                player_data.get('is_charging', False),
                player_data.get('charge_level', 0.0),
                player_data.get('power_ups', {})
            )
        
        # 공 렌더링
        ball_data = game_state.get('ball')
        if ball_data:
            self.ball_renderer.render(
                ball_data.get('pos', (300, 375)),
                ball_data.get('radius', 10),
                ball_data.get('color', (255, 255, 255)),
                ball_data.get('power_shot', False),
                ball_data.get('curve_ball', False),
                ball_data.get('ghost_ball', False),
                ball_data.get('velocity')
            )
        
        # 공 이펙트 렌더링
        self.ball_effect_manager.render(surface)
        
        # 아이템 렌더링 (필요시 별도 ItemRenderer 추가)
        items = game_state.get('items', [])
        for item in items:
            self._render_item(surface, item)
    
    def _render_effects(self, shake_offset: Tuple[int, int]):
        """이펙트 렌더링
        
        Args:
            shake_offset: 화면 흔들림 오프셋
        """
        # EffectRenderer가 자체적으로 모든 이펙트 관리
        self.effect_renderer.render()
    
    def _render_ui(self, game_state: Dict[str, Any]):
        """UI 렌더링
        
        Args:
            game_state: 게임 상태
        """
        # 점수 표시
        score_data = game_state.get('score', {})
        if score_data:
            self.ui_renderer.render_score(
                score_data.get('player', 0),
                score_data.get('boss', 0),
                game_state.get('stage', 1),
                'top'
            )
        
        # 게이지 표시
        gauges = game_state.get('gauges', {})
        
        # 특수 게이지
        if 'special' in gauges:
            self.ui_renderer.render_gauge(
                gauges['special'].get('value', 0),
                gauges['special'].get('max', 100),
                'special'
            )
        
        # 체력 게이지
        if 'health' in gauges:
            self.ui_renderer.render_gauge(
                gauges['health'].get('value', 100),
                gauges['health'].get('max', 100),
                'health'
            )
        
        # 콤보 표시
        combo = game_state.get('combo', {})
        if combo.get('count', 0) > 0:
            self.ui_renderer.render_combo(
                combo.get('count', 0),
                combo.get('multiplier', 1.0)
            )
        
        # 타이머 표시
        timer = game_state.get('timer')
        if timer is not None:
            self.ui_renderer.render_timer(timer)
        
        # 파워업 인디케이터
        power_ups = game_state.get('active_powerups', {})
        if power_ups:
            self.ui_renderer.render_power_up_indicator(power_ups)
        
        # 메시지 표시
        message = game_state.get('message')
        if message:
            self.ui_renderer.render_message(
                message.get('text', ''),
                message.get('duration', 0),
                message.get('position', 'center'),
                message.get('size', 'medium'),
                message.get('color')
            )
    
    def _render_item(self, surface: pygame.Surface, item: Dict[str, Any]):
        """아이템 렌더링
        
        Args:
            surface: 렌더링할 서페이스
            item: 아이템 데이터
        """
        pos = item.get('pos', (0, 0))
        size = item.get('size', 20)
        color = item.get('color', (255, 255, 0))
        item_type = item.get('type', 'default')
        
        # 기본 아이템 렌더링 (나중에 ItemRenderer로 분리 가능)
        if item_type == 'powerup':
            # 회전 애니메이션
            import math
            angle = (pygame.time.get_ticks() % 3600) / 10
            corners = []
            for i in range(4):
                corner_angle = angle + i * 90
                x = pos[0] + size * math.cos(math.radians(corner_angle))
                y = pos[1] + size * math.sin(math.radians(corner_angle))
                corners.append((x, y))
            pygame.draw.polygon(surface, color, corners)
        else:
            # 기본 원형 아이템
            pygame.draw.circle(surface, color, (int(pos[0]), int(pos[1])), size)
            # 하이라이트
            pygame.draw.circle(surface, (255, 255, 255), 
                             (int(pos[0] - size//3), int(pos[1] - size//3)), size//3)
    
    def _render_debug_info(self):
        """디버그 정보 렌더링"""
        debug_font = pygame.font.Font(None, 16)
        debug_info = []
        
        # FPS 정보
        if self.frame_times:
            avg_frame_time = sum(self.frame_times) / len(self.frame_times)
            fps = 1000 / avg_frame_time if avg_frame_time > 0 else 0
            debug_info.append(f"FPS: {fps:.1f}")
            debug_info.append(f"Frame Time: {avg_frame_time:.2f}ms")
        
        # 파티클 수
        particle_count = len(self.effect_renderer.particles)
        debug_info.append(f"Particles: {particle_count}")
        
        # 렌더러 상태
        debug_info.append(f"Ball Trail: {len(self.ball_renderer.trail_points)}")
        debug_info.append(f"Effects: {len(self.effect_renderer.explosions)}")
        
        # 디버그 정보 표시
        y = 10
        for info in debug_info:
            text = debug_font.render(info, True, (255, 255, 0))
            text_rect = text.get_rect()
            
            # 배경 박스
            bg_rect = text_rect.copy()
            bg_rect.topleft = (10, y)
            text_rect.topleft = (10, y)
            
            pygame.draw.rect(self.screen, (0, 0, 0, 150), bg_rect.inflate(4, 2))
            self.screen.blit(text, text_rect)
            y += 18
    
    def _update_performance_metrics(self, render_time: float):
        """성능 메트릭 업데이트
        
        Args:
            render_time: 렌더링 시간 (밀리초)
        """
        self.frame_times.append(render_time)
        if len(self.frame_times) > self.max_frame_history:
            self.frame_times.pop(0)
    
    # === 외부 인터페이스 메서드 ===
    
    def add_explosion(self, pos: Tuple[float, float], size: str = "medium"):
        """폭발 효과 추가"""
        self.effect_renderer.add_explosion(pos, size)
    
    def add_laser(self, start: Tuple[float, float], end: Tuple[float, float]):
        """레이저 효과 추가"""
        self.effect_renderer.add_laser(start, end)
    
    def add_screen_shake(self, intensity: int = 5, duration: int = 10):
        """화면 흔들림 추가"""
        self.effect_renderer.add_screen_shake(intensity, duration)
    
    def add_screen_flash(self, color: Tuple[int, int, int] = (255, 255, 255)):
        """화면 플래시 효과"""
        self.effect_renderer.add_screen_flash(color)
    
    def trigger_hit_effect(self, pos: Tuple[float, float], target: str = "ball"):
        """히트 효과 트리거
        
        Args:
            pos: 충돌 위치
            target: 타겟 ("ball", "paddle", "boss")
        """
        if target == "ball":
            self.ball_effect_manager.add_hit_effect(pos)
        elif target == "paddle":
            self.paddle_renderer.trigger_hit_animation()
        
        # 추가 이펙트
        self.effect_renderer.add_shockwave(pos, 50)
    
    def set_render_quality(self, quality: str):
        """렌더링 품질 설정
        
        Args:
            quality: 품질 설정 ("low", "medium", "high")
        """
        self.settings['particle_quality'] = quality
        
        if quality == "low":
            self.settings['enable_particles'] = False
            self.settings['enable_glow'] = False
        elif quality == "medium":
            self.settings['enable_particles'] = True
            self.settings['enable_glow'] = False
        else:  # high
            self.settings['enable_particles'] = True
            self.settings['enable_glow'] = True
    
    def toggle_debug(self):
        """디버그 모드 토글"""
        self.settings['render_debug'] = not self.settings['render_debug']
    
    def clear_all_effects(self):
        """모든 이펙트 클리어"""
        self.ball_renderer.clear_effects()
        self.paddle_renderer.clear_effects()
        self.effect_renderer.clear_all()
        self.ball_effect_manager = BallEffectManager()  # 재초기화
    
    def get_performance_stats(self) -> Dict[str, float]:
        """성능 통계 반환"""
        if not self.frame_times:
            return {'avg_fps': 0, 'avg_frame_time': 0}
        
        avg_frame_time = sum(self.frame_times) / len(self.frame_times)
        avg_fps = 1000 / avg_frame_time if avg_frame_time > 0 else 0
        
        return {
            'avg_fps': avg_fps,
            'avg_frame_time': avg_frame_time,
            'min_frame_time': min(self.frame_times),
            'max_frame_time': max(self.frame_times)
        }