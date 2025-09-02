"""
Paddle Renderer - 패들 렌더링 모듈
draw_objects_module.py에서 분리한 패들 관련 렌더링 코드
"""
import pygame
import math
import random
from typing import Tuple, Optional, Dict, Any
from utils.color_utils import get_neon_color, blend_colors, get_stage_color
from utils.draw_utils import draw_gradient_rect, draw_glow_effect
from utils.particle_utils import create_energy_particle, create_spark_particle

class PaddleRenderer:
    """패들 렌더링 클래스"""
    
    def __init__(self, screen: pygame.Surface):
        """초기화
        
        Args:
            screen: 렌더링할 화면
        """
        self.screen = screen
        self.width = screen.get_width()
        self.height = screen.get_height()
        
        # 애니메이션 상태
        self.hit_animation_timer = 0
        self.hit_animation_scale = 1.0
        self.charge_animation_phase = 0
        
        # 파티클
        self.particles = []
        
        # 트레일
        self.trail_points = []
        self.max_trail_length = 10
        
    def render_player_paddle(self, paddle_rect: pygame.Rect, 
                            paddle_color: Tuple[int, int, int] = (0, 255, 0),
                            is_dashing: bool = False,
                            is_charging: bool = False,
                            charge_level: float = 0.0,
                            power_ups: Optional[Dict[str, bool]] = None):
        """플레이어 패들 렌더링
        
        Args:
            paddle_rect: 패들 위치와 크기
            paddle_color: 패들 색상
            is_dashing: 대시 중 여부
            is_charging: 차징 중 여부
            charge_level: 차징 레벨 (0.0 ~ 1.0)
            power_ups: 활성화된 파워업 딕셔너리
        """
        if power_ups is None:
            power_ups = {}
        
        # 트레일 업데이트 (대시 중일 때)
        if is_dashing:
            self._update_trail(paddle_rect.center, paddle_color)
        
        # 트레일 그리기
        self._draw_trail()
        
        # 파워업 효과
        if power_ups.get('wide_paddle'):
            self._draw_wide_paddle_effect(paddle_rect)
        
        if power_ups.get('shield'):
            self._draw_shield_effect(paddle_rect)
        
        # 차징 효과
        if is_charging:
            self._draw_charge_effect(paddle_rect, charge_level)
        
        # 대시 효과
        if is_dashing:
            self._draw_dash_effect(paddle_rect, paddle_color)
        
        # 패들 본체 그리기
        self._draw_paddle_body(paddle_rect, paddle_color, is_dashing)
        
        # 히트 애니메이션
        if self.hit_animation_timer > 0:
            self._draw_hit_animation(paddle_rect)
            self.hit_animation_timer -= 1
        
        # 파티클 업데이트 및 그리기
        self._update_particles()
        self._draw_particles()
        
    def render_boss_paddle(self, paddle_rect: pygame.Rect,
                          paddle_color: Tuple[int, int, int] = (255, 0, 0),
                          boss_stage: int = 1,
                          is_rage_mode: bool = False,
                          special_attack: Optional[str] = None):
        """보스 패들 렌더링
        
        Args:
            paddle_rect: 패들 위치와 크기
            paddle_color: 패들 색상
            boss_stage: 보스 스테이지
            is_rage_mode: 광폭화 모드 여부
            special_attack: 특수 공격 종류
        """
        # 스테이지별 색상
        stage_color = get_stage_color(boss_stage)
        final_color = blend_colors(paddle_color, stage_color, 0.3)
        
        # 광폭화 모드 효과
        if is_rage_mode:
            self._draw_rage_mode_effect(paddle_rect)
            final_color = blend_colors(final_color, (255, 0, 0), 0.5)
        
        # 특수 공격 효과
        if special_attack:
            self._draw_special_attack_effect(paddle_rect, special_attack)
        
        # 보스 패들 본체
        self._draw_boss_paddle_body(paddle_rect, final_color, boss_stage)
        
        # 보스 고유 효과
        self._draw_boss_aura(paddle_rect, boss_stage)
        
    def _draw_paddle_body(self, rect: pygame.Rect, color: Tuple[int, int, int], 
                         is_dashing: bool = False):
        """패들 본체 그리기"""
        # 그라데이션 효과
        lighter_color = blend_colors(color, (255, 255, 255), 0.3)
        draw_gradient_rect(self.screen, rect, lighter_color, color, vertical=True)
        
        # 테두리
        border_color = get_neon_color(color) if is_dashing else color
        pygame.draw.rect(self.screen, border_color, rect, 2)
        
        # 중앙 라인
        center_line = pygame.Rect(rect.centerx - 1, rect.top + 2, 
                                 2, rect.height - 4)
        pygame.draw.rect(self.screen, lighter_color, center_line)
        
    def _draw_boss_paddle_body(self, rect: pygame.Rect, color: Tuple[int, int, int],
                               boss_stage: int):
        """보스 패들 본체 그리기"""
        # 스테이지별 특수 효과
        if boss_stage >= 4:
            # 고급 보스는 더 화려한 효과
            for i in range(3):
                expanded_rect = rect.inflate(i * 4, i * 2)
                alpha = 100 - i * 30
                surf = pygame.Surface((expanded_rect.width, expanded_rect.height), 
                                     pygame.SRCALPHA)
                pygame.draw.rect(surf, (*color, alpha), surf.get_rect(), 
                               border_radius=3)
                self.screen.blit(surf, expanded_rect.topleft)
        
        # 본체 그라데이션
        darker_color = blend_colors(color, (0, 0, 0), 0.3)
        draw_gradient_rect(self.screen, rect, color, darker_color, vertical=True)
        
        # 강화된 테두리
        pygame.draw.rect(self.screen, get_neon_color(color), rect, 3)
        
        # 패턴 그리기
        self._draw_boss_pattern(rect, boss_stage)
        
    def _draw_boss_pattern(self, rect: pygame.Rect, boss_stage: int):
        """보스 패들 패턴 그리기"""
        if boss_stage == 1:
            # 단순 줄무늬
            for i in range(0, rect.width, 10):
                pygame.draw.line(self.screen, (255, 255, 255, 50),
                               (rect.left + i, rect.top),
                               (rect.left + i, rect.bottom))
        elif boss_stage == 2:
            # 다이아몬드 패턴
            for i in range(0, rect.width, 15):
                points = [
                    (rect.left + i, rect.centery),
                    (rect.left + i + 7, rect.top + 3),
                    (rect.left + i + 15, rect.centery),
                    (rect.left + i + 7, rect.bottom - 3)
                ]
                pygame.draw.polygon(self.screen, (255, 255, 255, 30), points)
        elif boss_stage >= 3:
            # 복잡한 회로 패턴
            for i in range(0, rect.width, 20):
                # 수평선
                pygame.draw.line(self.screen, (100, 200, 255, 40),
                               (rect.left + i, rect.centery),
                               (rect.left + i + 15, rect.centery))
                # 노드
                pygame.draw.circle(self.screen, (100, 200, 255, 60),
                                 (rect.left + i + 10, rect.centery), 3)
    
    def _draw_charge_effect(self, rect: pygame.Rect, charge_level: float):
        """차징 효과 그리기"""
        if charge_level <= 0:
            return
        
        # 차징 파티클
        if random.random() < charge_level:
            particle_x = rect.centerx + random.randint(-rect.width//2, rect.width//2)
            particle_y = rect.centery
            self.particles.append({
                'x': particle_x,
                'y': particle_y,
                'vx': random.uniform(-1, 1),
                'vy': random.uniform(-3, -1),
                'life': 20,
                'color': (255, 255, 100),
                'size': random.randint(2, 4)
            })
        
        # 차징 오라
        charge_radius = int(30 + charge_level * 20)
        charge_alpha = int(50 + charge_level * 150)
        
        charge_surf = pygame.Surface((charge_radius * 2, charge_radius * 2), 
                                    pygame.SRCALPHA)
        pygame.draw.circle(charge_surf, (255, 255, 100, charge_alpha),
                         (charge_radius, charge_radius), charge_radius)
        
        self.screen.blit(charge_surf, 
                        (rect.centerx - charge_radius, rect.centery - charge_radius),
                        special_flags=pygame.BLEND_ADD)
    
    def _draw_dash_effect(self, rect: pygame.Rect, color: Tuple[int, int, int]):
        """대시 효과 그리기"""
        # 잔상 효과
        for i in range(3):
            offset = i * 5
            alpha = 150 - i * 40
            dash_surf = pygame.Surface((rect.width, rect.height), pygame.SRCALPHA)
            pygame.draw.rect(dash_surf, (*color, alpha), dash_surf.get_rect())
            self.screen.blit(dash_surf, (rect.x - offset, rect.y))
        
        # 스피드 라인
        for _ in range(3):
            line_y = rect.centery + random.randint(-rect.height//2, rect.height//2)
            line_length = random.randint(20, 40)
            pygame.draw.line(self.screen, get_neon_color(color),
                           (rect.left - line_length, line_y),
                           (rect.left, line_y), 2)
    
    def _draw_shield_effect(self, rect: pygame.Rect):
        """실드 효과 그리기"""
        shield_rect = rect.inflate(20, 10)
        
        # 실드 버블
        shield_surf = pygame.Surface((shield_rect.width, shield_rect.height),
                                    pygame.SRCALPHA)
        pygame.draw.ellipse(shield_surf, (100, 200, 255, 100), shield_surf.get_rect(), 2)
        pygame.draw.ellipse(shield_surf, (150, 220, 255, 50), shield_surf.get_rect())
        
        self.screen.blit(shield_surf, shield_rect.topleft)
        
        # 전기 효과
        if random.random() < 0.3:
            spark_angle = random.uniform(0, math.pi * 2)
            spark_dist = shield_rect.width // 2
            spark_x = shield_rect.centerx + math.cos(spark_angle) * spark_dist
            spark_y = shield_rect.centery + math.sin(spark_angle) * spark_dist * 0.5
            
            pygame.draw.circle(self.screen, (200, 220, 255), 
                             (int(spark_x), int(spark_y)), 2)
    
    def _draw_wide_paddle_effect(self, rect: pygame.Rect):
        """와이드 패들 효과 그리기"""
        # 확장 표시
        extend_surf = pygame.Surface((20, rect.height), pygame.SRCALPHA)
        
        # 왼쪽 확장
        pygame.draw.rect(extend_surf, (100, 255, 100, 50), extend_surf.get_rect())
        self.screen.blit(extend_surf, (rect.left - 20, rect.top))
        
        # 오른쪽 확장
        self.screen.blit(extend_surf, (rect.right, rect.top))
        
        # 화살표 표시
        arrow_color = (150, 255, 150)
        # 왼쪽 화살표
        pygame.draw.polygon(self.screen, arrow_color,
                          [(rect.left - 15, rect.centery),
                           (rect.left - 5, rect.centery - 5),
                           (rect.left - 5, rect.centery + 5)])
        # 오른쪽 화살표
        pygame.draw.polygon(self.screen, arrow_color,
                          [(rect.right + 15, rect.centery),
                           (rect.right + 5, rect.centery - 5),
                           (rect.right + 5, rect.centery + 5)])
    
    def _draw_rage_mode_effect(self, rect: pygame.Rect):
        """광폭화 모드 효과 그리기"""
        # 붉은 오라
        for i in range(3):
            rage_rect = rect.inflate(i * 10, i * 5)
            alpha = 100 - i * 30
            rage_surf = pygame.Surface((rage_rect.width, rage_rect.height),
                                      pygame.SRCALPHA)
            pygame.draw.rect(rage_surf, (255, 0, 0, alpha), rage_surf.get_rect())
            self.screen.blit(rage_surf, rage_rect.topleft, 
                           special_flags=pygame.BLEND_ADD)
        
        # 화염 파티클
        if random.random() < 0.5:
            flame_x = rect.centerx + random.randint(-rect.width//2, rect.width//2)
            flame_y = rect.top
            self.particles.append({
                'x': flame_x,
                'y': flame_y,
                'vx': random.uniform(-1, 1),
                'vy': random.uniform(-2, 0),
                'life': 15,
                'color': (255, random.randint(50, 150), 0),
                'size': random.randint(3, 6)
            })
    
    def _draw_special_attack_effect(self, rect: pygame.Rect, attack_type: str):
        """특수 공격 효과 그리기"""
        if attack_type == "laser":
            # 레이저 차징
            pygame.draw.circle(self.screen, (255, 0, 0), rect.center, 10)
            for i in range(3):
                radius = 15 + i * 5
                alpha = 150 - i * 40
                laser_surf = pygame.Surface((radius * 2, radius * 2), pygame.SRCALPHA)
                pygame.draw.circle(laser_surf, (255, 0, 0, alpha),
                                 (radius, radius), radius)
                self.screen.blit(laser_surf,
                               (rect.centerx - radius, rect.centery - radius),
                               special_flags=pygame.BLEND_ADD)
        
        elif attack_type == "missile":
            # 미사일 발사 준비
            for i in range(2):
                missile_x = rect.centerx + (i * 2 - 1) * 20
                pygame.draw.circle(self.screen, (255, 200, 0), 
                                 (missile_x, rect.centery), 5)
    
    def _draw_boss_aura(self, rect: pygame.Rect, boss_stage: int):
        """보스 오라 그리기"""
        # 스테이지가 높을수록 강한 오라
        aura_strength = boss_stage * 0.2
        aura_color = get_stage_color(boss_stage)
        
        # 펄싱 효과
        pulse = math.sin(pygame.time.get_ticks() * 0.005) * 0.5 + 0.5
        aura_radius = int(rect.width * 0.6 * (1 + pulse * aura_strength))
        
        aura_surf = pygame.Surface((aura_radius * 2, aura_radius * 2), pygame.SRCALPHA)
        alpha = int(30 + pulse * 50)
        pygame.draw.circle(aura_surf, (*aura_color, alpha),
                         (aura_radius, aura_radius), aura_radius)
        
        self.screen.blit(aura_surf,
                        (rect.centerx - aura_radius, rect.centery - aura_radius),
                        special_flags=pygame.BLEND_ADD)
    
    def _draw_hit_animation(self, rect: pygame.Rect):
        """히트 애니메이션 그리기"""
        # 충격파 효과
        wave_radius = int((30 - self.hit_animation_timer))
        wave_alpha = int(self.hit_animation_timer * 8)
        
        if wave_alpha > 0:
            wave_surf = pygame.Surface((wave_radius * 2, wave_radius * 2), 
                                      pygame.SRCALPHA)
            pygame.draw.circle(wave_surf, (255, 255, 255, wave_alpha),
                             (wave_radius, wave_radius), wave_radius, 2)
            self.screen.blit(wave_surf,
                           (rect.centerx - wave_radius, rect.centery - wave_radius))
    
    def _update_trail(self, center: Tuple[int, int], color: Tuple[int, int, int]):
        """트레일 업데이트"""
        self.trail_points.append({
            'pos': center,
            'color': color,
            'alpha': 200,
            'width': 100
        })
        
        if len(self.trail_points) > self.max_trail_length:
            self.trail_points.pop(0)
        
        for point in self.trail_points:
            point['alpha'] *= 0.85
            point['width'] *= 0.95
    
    def _draw_trail(self):
        """트레일 그리기"""
        for point in self.trail_points:
            if point['alpha'] > 10:
                trail_surf = pygame.Surface((int(point['width']), 20), pygame.SRCALPHA)
                pygame.draw.rect(trail_surf, (*point['color'], int(point['alpha'])),
                               trail_surf.get_rect())
                self.screen.blit(trail_surf,
                               (point['pos'][0] - point['width']//2, 
                                point['pos'][1] - 10))
    
    def _update_particles(self):
        """파티클 업데이트"""
        updated = []
        for particle in self.particles:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['vy'] += 0.1  # 중력
            particle['life'] -= 1
            particle['size'] *= 0.95
            
            if particle['life'] > 0 and particle['size'] > 0.5:
                updated.append(particle)
        
        self.particles = updated
    
    def _draw_particles(self):
        """파티클 그리기"""
        for particle in self.particles:
            alpha = int(255 * (particle['life'] / 20))
            if alpha > 0:
                size = int(particle['size'])
                if size > 0:
                    part_surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    pygame.draw.circle(part_surf, (*particle['color'], alpha),
                                     (size, size), size)
                    self.screen.blit(part_surf,
                                   (particle['x'] - size, particle['y'] - size),
                                   special_flags=pygame.BLEND_ADD)
    
    def trigger_hit_animation(self):
        """히트 애니메이션 트리거"""
        self.hit_animation_timer = 30
        self.hit_animation_scale = 1.2
    
    def clear_effects(self):
        """모든 효과 초기화"""
        self.particles.clear()
        self.trail_points.clear()
        self.hit_animation_timer = 0
        self.charge_animation_phase = 0