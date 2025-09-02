"""
스테이지별 렌더링 통합 클래스
모든 draw 함수들을 하나의 클래스로 통합
"""

import pygame
import math
import random
from typing import Dict, Any, List, Tuple, Optional

class StageRenderer:
    """스테이지 렌더링 통합"""
    
    def __init__(self, screen, width, height):
        self.screen = screen
        self.width = width
        self.height = height
        self.draw_functions = {
            'tears': self._draw_tears,
            'predicted_trajectory': self._draw_predicted_trajectory,
            'shaking_screen': self._draw_shaking_screen,
            'speech': self._draw_speech,
            'balloons': self._draw_balloons,
            'water_trail': self._draw_water_trail,
            'pachinko': self._draw_pachinko,
            'item_obtained': self._draw_item_obtained,
            'player_gauge': self._draw_player_gauge,
            'crocodile_boss': self._draw_crocodile_boss,
            'aircraft_carrier_boss': self._draw_aircraft_carrier_boss,
            'objects': self._draw_objects,
            'stage2_jungle_border': self._draw_stage2_jungle_border,
            'stage2_leaves': self._draw_stage2_leaves,
            'field': self._draw_field,
            'score': self._draw_score,
            'laser_cannon_gauge': self._draw_laser_cannon_gauge,
            'boss_health_bar': self._draw_boss_health_bar,
            'impact_particles': self._draw_impact_particles,
            'fireball_explosion': self._draw_fireball_explosion,
            'ai_visualization': self._draw_ai_visualization,
            'player_skill_display': self._draw_player_skill_display,
            'ability_radar': self._draw_ability_radar,
            'pause_overlay': self._draw_pause_overlay,
            'gradient_background': self._draw_gradient_background,
            'modern_panel': self._draw_modern_panel,
            'section_container': self._draw_section_container
        }
    
    def draw(self, element_type: str, **kwargs):
        """통합 draw 메서드"""
        if element_type in self.draw_functions:
            return self.draw_functions[element_type](**kwargs)
        else:
            print(f"Unknown draw element: {element_type}")
    
    def _draw_tears(self, tears_data=None, stage=None, img=None):
        """눈물 그리기"""
        if not tears_data:
            return
        for x, y, _, _ in tears_data:
            if -50 <= x <= self.width + 50 and -50 <= y <= self.height + 50:
                if img:
                    self.screen.blit(img, (x - img.get_width()//2, y - img.get_height()//2))
    
    def _draw_predicted_trajectory(self, points=None, color=(255, 255, 0, 100)):
        """예측 궤적 그리기"""
        if points and len(points) > 1:
            for i in range(len(points) - 1):
                pygame.draw.line(self.screen, color[:3], points[i], points[i+1], 2)
    
    def _draw_shaking_screen(self, shake_intensity=0):
        """화면 흔들림"""
        if shake_intensity > 0:
            offset_x = random.randint(-shake_intensity, shake_intensity)
            offset_y = random.randint(-shake_intensity, shake_intensity)
            return (offset_x, offset_y)
        return (0, 0)
    
    def _draw_speech(self, text="", pos=None, font=None):
        """대사 그리기"""
        if text and pos:
            if not font:
                font = pygame.font.Font(None, 24)
            text_surf = font.render(text, True, (255, 255, 255))
            self.screen.blit(text_surf, pos)
    
    def _draw_balloons(self, balloons=None):
        """풍선 그리기"""
        if not balloons:
            return
        for balloon in balloons:
            x, y = balloon.get('x', 0), balloon.get('y', 0)
            radius = balloon.get('radius', 10)
            color = balloon.get('color', (255, 0, 0))
            pygame.draw.circle(self.screen, color, (int(x), int(y)), radius)
    
    def _draw_water_trail(self, trail_points=None):
        """물 궤적 그리기"""
        if trail_points and len(trail_points) > 1:
            for i in range(len(trail_points) - 1):
                alpha = int(255 * (i / len(trail_points)))
                color = (0, 100, 200)
                pygame.draw.line(self.screen, color, trail_points[i], trail_points[i+1], 3)
    
    def _draw_pachinko(self, **kwargs):
        """파칭코 그리기 - 실제 구현은 원본 참조"""
        pass
    
    def _draw_item_obtained(self, item_name="", pos=None):
        """아이템 획득 효과"""
        if item_name and pos:
            font = pygame.font.Font(None, 36)
            text = font.render(f"+{item_name}", True, (255, 255, 0))
            self.screen.blit(text, pos)
    
    def _draw_player_gauge(self, **kwargs):
        """플레이어 게이지"""
        pass
    
    def _draw_crocodile_boss(self, **kwargs):
        """악어 보스"""
        pass
    
    def _draw_aircraft_carrier_boss(self, **kwargs):
        """항공모함 보스"""
        pass
    
    def _draw_objects(self, **kwargs):
        """오브젝트들"""
        pass
    
    def _draw_stage2_jungle_border(self, **kwargs):
        """스테이지2 정글 테두리"""
        pass
    
    def _draw_stage2_leaves(self, leaves=None):
        """스테이지2 나뭇잎"""
        if not leaves:
            return
        for leaf in leaves:
            x, y = leaf.get('x', 0), leaf.get('y', 0)
            pygame.draw.circle(self.screen, (0, 200, 0), (int(x), int(y)), 5)
    
    def _draw_field(self, **kwargs):
        """필드"""
        pass
    
    def _draw_score(self, score=0, pos=None):
        """점수"""
        if pos:
            font = pygame.font.Font(None, 48)
            text = font.render(str(score), True, (255, 255, 255))
            self.screen.blit(text, pos)
    
    def _draw_laser_cannon_gauge(self, **kwargs):
        """레이저 캐논 게이지"""
        pass
    
    def _draw_boss_health_bar(self, current=0, maximum=100, pos=None):
        """보스 체력바"""
        if pos and maximum > 0:
            x, y = pos
            width, height = 200, 20
            # 배경
            pygame.draw.rect(self.screen, (50, 50, 50), (x, y, width, height))
            # 체력
            ratio = current / maximum
            if ratio > 0:
                bar_width = int(width * ratio)
                color = (0, 255, 0) if ratio > 0.6 else (255, 255, 0) if ratio > 0.3 else (255, 0, 0)
                pygame.draw.rect(self.screen, color, (x, y, bar_width, height))
            # 테두리
            pygame.draw.rect(self.screen, (255, 255, 255), (x, y, width, height), 2)
    
    def _draw_impact_particles(self, particles=None):
        """충격 파티클"""
        if not particles:
            return
        for p in particles:
            x, y = p.get('x', 0), p.get('y', 0)
            size = p.get('size', 2)
            color = p.get('color', (255, 255, 255))
            alpha = p.get('alpha', 255)
            if alpha > 0:
                pygame.draw.circle(self.screen, color, (int(x), int(y)), size)
    
    def _draw_fireball_explosion(self, **kwargs):
        """화염구 폭발"""
        pass
    
    def _draw_ai_visualization(self, **kwargs):
        """AI 시각화"""
        pass
    
    def _draw_player_skill_display(self, **kwargs):
        """플레이어 스킬 표시"""
        pass
    
    def _draw_ability_radar(self, **kwargs):
        """능력 레이더 차트"""
        pass
    
    def _draw_pause_overlay(self):
        """일시정지 오버레이"""
        overlay = pygame.Surface((self.width, self.height))
        overlay.set_alpha(128)
        overlay.fill((0, 0, 0))
        self.screen.blit(overlay, (0, 0))
        
        font = pygame.font.Font(None, 72)
        text = font.render("PAUSED", True, (255, 255, 255))
        rect = text.get_rect(center=(self.width//2, self.height//2))
        self.screen.blit(text, rect)
    
    def _draw_gradient_background(self, rect=None, color1=(0, 0, 0), color2=(100, 100, 100)):
        """그라데이션 배경"""
        if not rect:
            rect = pygame.Rect(0, 0, self.width, self.height)
        
        for y in range(rect.height):
            ratio = y / rect.height
            r = int(color1[0] + (color2[0] - color1[0]) * ratio)
            g = int(color1[1] + (color2[1] - color1[1]) * ratio)
            b = int(color1[2] + (color2[2] - color1[2]) * ratio)
            pygame.draw.line(self.screen, (r, g, b), 
                           (rect.x, rect.y + y), 
                           (rect.x + rect.width, rect.y + y))
    
    def _draw_modern_panel(self, rect=None, title="", title_color=(255, 215, 0)):
        """모던 패널"""
        if rect:
            pygame.draw.rect(self.screen, (30, 30, 40), rect)
            pygame.draw.rect(self.screen, title_color, rect, 3)
            
            if title:
                font = pygame.font.Font(None, 24)
                text = font.render(title, True, title_color)
                text_rect = text.get_rect(centerx=rect.centerx, y=rect.y + 10)
                self.screen.blit(text, text_rect)
    
    def _draw_section_container(self, rect=None, title="", icon=""):
        """섹션 컨테이너"""
        if rect:
            pygame.draw.rect(self.screen, (40, 40, 50), rect, border_radius=10)
            pygame.draw.rect(self.screen, (100, 100, 120), rect, 2, border_radius=10)
            
            if title:
                font = pygame.font.Font(None, 20)
                text = font.render(f"{icon} {title}" if icon else title, True, (255, 255, 255))
                self.screen.blit(text, (rect.x + 10, rect.y + 10))

# 싱글톤 인스턴스
_stage_renderer = None

def get_stage_renderer(screen, width, height) -> StageRenderer:
    """StageRenderer 인스턴스 반환"""
    global _stage_renderer
    if _stage_renderer is None:
        _stage_renderer = StageRenderer(screen, width, height)
    return _stage_renderer