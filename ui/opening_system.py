"""
Opening System - 오프닝 및 시네마틱 시스템
게임 인트로, 시네마틱 장면, 컷신 관리
"""

import pygame
import math
import random
from typing import Dict, Optional, List, Tuple
from core.global_manager import GlobalManager
from core.events import EventType, emit_event
from managers.effects_manager import get_effects_manager


class OpeningSystem:
    """오프닝 및 시네마틱 시스템"""
    
    def __init__(self):
        self.global_manager = GlobalManager.get_instance()
        self.effects_manager = get_effects_manager()
        
        # 상태
        self.active = False
        self.mode = 'opening'  # 'opening', 'cinematic', 'stage_intro'
        self.timer = 0
        self.scene_index = 0
        
        # 오프닝 관련
        self.opening = {
            'logo_scale': 0.1,
            'logo_y': 0,
            'logo_target_y': 0,
            'text_alpha': 0,
            'typing_text': "",
            'full_text': "핑파이터",
            'typing_timer': 0,
            'particles': [],
            'show_press_key': False,
            'press_key_alpha': 0,
            'idle_timer': 0,
            'special_animation': False
        }
        
        # 시네마틱 관련
        self.cinematic = {
            'current_scene': 0,
            'scene_timer': 0,
            'transition_alpha': 0,
            'transitioning': False,
            'scene_durations': [240, 270, 300, 240, 270],  # 5개 장면
            'particles': [],
            'energy_waves': []
        }
        
        # 스테이지 인트로
        self.stage_intros = {
            1: {
                'title': 'Stage 1: Training Ground',
                'subtitle': 'Master the basics',
                'duration': 180
            },
            2: {
                'title': 'Stage 2: Speed Zone',
                'subtitle': 'Velocity is key',
                'duration': 180
            },
            3: {
                'title': 'Stage 3: Emotional Chaos',
                'subtitle': 'Feel the intensity',
                'duration': 180
            },
            4: {
                'title': 'Stage 4: Magnetic Field',
                'subtitle': 'Attraction and repulsion',
                'duration': 180
            },
            5: {
                'title': 'Stage 5: Inferno',
                'subtitle': 'Burn everything',
                'duration': 180
            },
            6: {
                'title': 'Stage 6: Final Battle',
                'subtitle': 'The ultimate challenge',
                'duration': 180
            }
        }
        
    def start_opening(self):
        """오프닝 시작"""
        self.active = True
        self.mode = 'opening'
        self.timer = 0
        
        # 오프닝 초기화
        height = self.global_manager.get('HEIGHT', 750)
        width = self.global_manager.get('WIDTH', 600)
        
        self.opening['logo_y'] = height // 2
        self.opening['logo_target_y'] = height // 3
        self.opening['typing_text'] = ""
        self.opening['typing_timer'] = 0
        self.opening['particles'].clear()
        
        emit_event(EventType.MENU_OPENED, {'type': 'opening'})
        
    def start_cinematic(self):
        """시네마틱 시작"""
        self.active = True
        self.mode = 'cinematic'
        self.timer = 0
        self.cinematic['current_scene'] = 0
        self.cinematic['scene_timer'] = 0
        self.cinematic['particles'].clear()
        
        emit_event(EventType.MENU_OPENED, {'type': 'cinematic'})
        
    def start_stage_intro(self, stage: int):
        """스테이지 인트로 시작
        
        Args:
            stage: 스테이지 번호
        """
        self.active = True
        self.mode = 'stage_intro'
        self.timer = 0
        self.scene_index = stage
        
        emit_event(EventType.MENU_OPENED, {'type': 'stage_intro', 'stage': stage})
        
    def update(self, dt: float) -> bool:
        """시스템 업데이트
        
        Args:
            dt: 델타 타임
            
        Returns:
            완료 여부
        """
        if not self.active:
            return False
            
        self.timer += dt * 60  # 프레임 단위로 변환
        
        if self.mode == 'opening':
            return self._update_opening(dt)
        elif self.mode == 'cinematic':
            return self._update_cinematic(dt)
        elif self.mode == 'stage_intro':
            return self._update_stage_intro(dt)
            
        return False
        
    def _update_opening(self, dt: float) -> bool:
        """오프닝 업데이트"""
        opening = self.opening
        
        # 로고 애니메이션
        if opening['logo_scale'] < 1.0:
            opening['logo_scale'] = min(1.0, opening['logo_scale'] + 0.02)
            
        # 로고 위치 이동
        logo_diff = opening['logo_target_y'] - opening['logo_y']
        opening['logo_y'] += logo_diff * 0.05
        
        # 타이핑 효과
        opening['typing_timer'] += 0.1
        if opening['typing_timer'] >= 1.0 and len(opening['typing_text']) < len(opening['full_text']):
            opening['typing_text'] += opening['full_text'][len(opening['typing_text'])]
            opening['typing_timer'] = 0
            
        # 텍스트 페이드인
        if len(opening['typing_text']) == len(opening['full_text']):
            opening['text_alpha'] = min(255, opening['text_alpha'] + 5)
            
        # 1초 후 Press Key 표시
        if self.timer > 60:
            opening['show_press_key'] = True
            opening['press_key_alpha'] = min(255, opening['press_key_alpha'] + 3)
            
        # 10초 후 특별 애니메이션
        if self.timer > 600 and not opening['special_animation']:
            opening['special_animation'] = True
            self._start_special_animation()
            
        # 파티클 업데이트
        self._update_particles(opening['particles'], dt)
        
        # 파티클 생성
        if random.random() < 0.1:
            self._create_opening_particle()
            
        return False  # 사용자 입력 대기
        
    def _update_cinematic(self, dt: float) -> bool:
        """시네마틱 업데이트"""
        cinematic = self.cinematic
        
        cinematic['scene_timer'] += dt * 60
        
        # 현재 장면 지속시간 체크
        if cinematic['scene_timer'] >= cinematic['scene_durations'][cinematic['current_scene']]:
            # 다음 장면으로
            cinematic['current_scene'] += 1
            cinematic['scene_timer'] = 0
            
            if cinematic['current_scene'] >= len(cinematic['scene_durations']):
                # 시네마틱 종료
                self.active = False
                emit_event(EventType.MENU_CLOSED, {'type': 'cinematic'})
                return True
                
        # 파티클 업데이트
        self._update_particles(cinematic['particles'], dt)
        
        # 장면별 업데이트
        self._update_cinematic_scene(cinematic['current_scene'], dt)
        
        return False
        
    def _update_stage_intro(self, dt: float) -> bool:
        """스테이지 인트로 업데이트"""
        intro = self.stage_intros.get(self.scene_index)
        if not intro:
            self.active = False
            return True
            
        # 지속시간 체크
        if self.timer >= intro['duration']:
            self.active = False
            emit_event(EventType.MENU_CLOSED, {'type': 'stage_intro', 'stage': self.scene_index})
            return True
            
        return False
        
    def _update_cinematic_scene(self, scene: int, dt: float):
        """시네마틱 장면별 업데이트"""
        if scene == 0:
            # 장면 1: 패들과 공의 첫 만남
            self._update_scene_meeting(dt)
        elif scene == 1:
            # 장면 2: 보스의 등장
            self._update_scene_boss_appears(dt)
        elif scene == 2:
            # 장면 3: 격렬한 전투
            self._update_scene_battle(dt)
        elif scene == 3:
            # 장면 4: 파워업
            self._update_scene_powerup(dt)
        elif scene == 4:
            # 장면 5: 최종 대결
            self._update_scene_final(dt)
            
    def _update_scene_meeting(self, dt: float):
        """장면 1: 첫 만남"""
        # 공이 천천히 내려옴
        if random.random() < 0.05:
            x = self.global_manager.get('WIDTH', 600) // 2
            y = 100
            self._create_energy_particle(x, y, (100, 200, 255))
            
    def _update_scene_boss_appears(self, dt: float):
        """장면 2: 보스 등장"""
        # 붉은 파티클
        if random.random() < 0.1:
            x = random.randint(100, self.global_manager.get('WIDTH', 600) - 100)
            y = 150
            self._create_energy_particle(x, y, (255, 100, 100))
            
    def _update_scene_battle(self, dt: float):
        """장면 3: 전투"""
        # 격렬한 파티클
        if random.random() < 0.2:
            x = random.randint(0, self.global_manager.get('WIDTH', 600))
            y = random.randint(0, self.global_manager.get('HEIGHT', 750))
            colors = [(255, 100, 100), (100, 100, 255), (255, 255, 100)]
            self._create_energy_particle(x, y, random.choice(colors))
            
    def _update_scene_powerup(self, dt: float):
        """장면 4: 파워업"""
        # 황금빛 파티클
        if random.random() < 0.15:
            x = self.global_manager.get('WIDTH', 600) // 2
            y = self.global_manager.get('HEIGHT', 750) - 100
            self._create_energy_particle(x, y, (255, 215, 0))
            
    def _update_scene_final(self, dt: float):
        """장면 5: 최종 대결"""
        # 무지개 파티클
        if random.random() < 0.25:
            x = random.randint(0, self.global_manager.get('WIDTH', 600))
            y = random.randint(0, self.global_manager.get('HEIGHT', 750))
            hue = (self.timer * 3) % 360
            color = self._hsv_to_rgb(hue, 1.0, 1.0)
            self._create_energy_particle(x, y, color)
            
    def _create_opening_particle(self):
        """오프닝 파티클 생성"""
        width = self.global_manager.get('WIDTH', 600)
        height = self.global_manager.get('HEIGHT', 750)
        
        particle = {
            'x': random.randint(0, width),
            'y': random.randint(0, height),
            'vx': random.uniform(-2, 2),
            'vy': random.uniform(-2, 2),
            'life': random.randint(60, 120),
            'max_life': 120,
            'size': random.randint(1, 3),
            'color': (random.randint(100, 255), random.randint(100, 255), random.randint(100, 255))
        }
        self.opening['particles'].append(particle)
        
    def _create_energy_particle(self, x: float, y: float, color: Tuple[int, int, int]):
        """에너지 파티클 생성"""
        angle = random.uniform(0, math.pi * 2)
        speed = random.uniform(2, 5)
        
        particle = {
            'x': x,
            'y': y,
            'vx': math.cos(angle) * speed,
            'vy': math.sin(angle) * speed,
            'life': random.randint(30, 60),
            'max_life': 60,
            'size': random.randint(2, 5),
            'color': color
        }
        
        if self.mode == 'cinematic':
            self.cinematic['particles'].append(particle)
        else:
            self.opening['particles'].append(particle)
            
    def _update_particles(self, particles: List, dt: float):
        """파티클 업데이트"""
        for particle in particles[:]:
            particle['x'] += particle['vx'] * dt * 60
            particle['y'] += particle['vy'] * dt * 60
            particle['life'] -= 1
            
            if particle['life'] <= 0:
                particles.remove(particle)
                
    def _start_special_animation(self):
        """특별 애니메이션 시작"""
        # 화면 효과
        self.effects_manager.flash_screen(color=(255, 255, 255), duration=1.0)
        self.effects_manager.shake_screen(intensity=10, duration=2.0)
        
        # 추가 파티클 생성
        for _ in range(50):
            self._create_opening_particle()
            
    def render(self, screen: pygame.Surface):
        """렌더링"""
        if not self.active:
            return
            
        if self.mode == 'opening':
            self._render_opening(screen)
        elif self.mode == 'cinematic':
            self._render_cinematic(screen)
        elif self.mode == 'stage_intro':
            self._render_stage_intro(screen)
            
    def _render_opening(self, screen: pygame.Surface):
        """오프닝 렌더링"""
        opening = self.opening
        width = self.global_manager.get('WIDTH', 600)
        height = self.global_manager.get('HEIGHT', 750)
        
        # 배경
        screen.fill((10, 10, 30))
        
        # 파티클
        for particle in opening['particles']:
            alpha = int(255 * (particle['life'] / particle['max_life']))
            color = (*particle['color'], alpha)
            
            s = pygame.Surface((particle['size'] * 2, particle['size'] * 2), pygame.SRCALPHA)
            pygame.draw.circle(s, color, (particle['size'], particle['size']), particle['size'])
            screen.blit(s, (particle['x'] - particle['size'], particle['y'] - particle['size']))
            
        # 로고 (텍스트로 대체)
        try:
            font_large = pygame.font.Font(None, int(80 * opening['logo_scale']))
            logo_text = font_large.render("BossPong", True, (255, 255, 255))
            logo_rect = logo_text.get_rect(center=(width // 2, int(opening['logo_y'])))
            screen.blit(logo_text, logo_rect)
        except:
            pass
            
        # 타이핑 텍스트
        if opening['typing_text']:
            try:
                font_medium = pygame.font.Font(None, 40)
                typing = font_medium.render(opening['typing_text'], True, (200, 200, 255))
                typing_rect = typing.get_rect(center=(width // 2, int(opening['logo_y']) + 100))
                typing.set_alpha(opening['text_alpha'])
                screen.blit(typing, typing_rect)
            except:
                pass
                
        # Press Any Key
        if opening['show_press_key']:
            try:
                font_small = pygame.font.Font(None, 30)
                press_text = font_small.render("Press Any Key to Start", True, (150, 150, 150))
                press_rect = press_text.get_rect(center=(width // 2, height - 100))
                press_text.set_alpha(int(opening['press_key_alpha'] * abs(math.sin(self.timer * 0.05))))
                screen.blit(press_text, press_rect)
            except:
                pass
                
    def _render_cinematic(self, screen: pygame.Surface):
        """시네마틱 렌더링"""
        cinematic = self.cinematic
        
        # 배경
        screen.fill((0, 0, 20))
        
        # 파티클
        for particle in cinematic['particles']:
            alpha = int(255 * (particle['life'] / particle['max_life']))
            color = (*particle['color'], alpha)
            
            s = pygame.Surface((particle['size'] * 2, particle['size'] * 2), pygame.SRCALPHA)
            pygame.draw.circle(s, color, (particle['size'], particle['size']), particle['size'])
            screen.blit(s, (particle['x'] - particle['size'], particle['y'] - particle['size']))
            
        # 장면 번호
        try:
            font = pygame.font.Font(None, 20)
            scene_text = font.render(f"Scene {cinematic['current_scene'] + 1}/5", True, (100, 100, 100))
            screen.blit(scene_text, (10, 10))
        except:
            pass
            
        # 전환 효과
        if cinematic['transition_alpha'] > 0:
            fade_surface = pygame.Surface(screen.get_size())
            fade_surface.fill((0, 0, 0))
            fade_surface.set_alpha(cinematic['transition_alpha'])
            screen.blit(fade_surface, (0, 0))
            
    def _render_stage_intro(self, screen: pygame.Surface):
        """스테이지 인트로 렌더링"""
        intro = self.stage_intros.get(self.scene_index)
        if not intro:
            return
            
        width = self.global_manager.get('WIDTH', 600)
        height = self.global_manager.get('HEIGHT', 750)
        
        # 배경 페이드
        fade_alpha = 200
        if self.timer < 30:  # 페이드인
            fade_alpha = int(200 * (self.timer / 30))
        elif self.timer > intro['duration'] - 30:  # 페이드아웃
            fade_alpha = int(200 * ((intro['duration'] - self.timer) / 30))
            
        screen.fill((0, 0, 0))
        
        # 타이틀
        try:
            font_large = pygame.font.Font(None, 60)
            title = font_large.render(intro['title'], True, (255, 255, 255))
            title_rect = title.get_rect(center=(width // 2, height // 2 - 50))
            title.set_alpha(fade_alpha)
            screen.blit(title, title_rect)
            
            # 서브타이틀
            font_small = pygame.font.Font(None, 30)
            subtitle = font_small.render(intro['subtitle'], True, (200, 200, 200))
            subtitle_rect = subtitle.get_rect(center=(width // 2, height // 2 + 20))
            subtitle.set_alpha(fade_alpha)
            screen.blit(subtitle, subtitle_rect)
        except:
            pass
            
    def handle_input(self, event) -> bool:
        """입력 처리
        
        Args:
            event: pygame 이벤트
            
        Returns:
            처리 여부
        """
        if not self.active:
            return False
            
        if self.mode == 'opening':
            if event.type == pygame.KEYDOWN or event.type == pygame.MOUSEBUTTONDOWN:
                # 오프닝 스킵
                self.active = False
                emit_event(EventType.MENU_CLOSED, {'type': 'opening'})
                return True
                
        elif self.mode == 'cinematic':
            if event.type == pygame.KEYDOWN and event.key == pygame.K_ESCAPE:
                # 시네마틱 스킵
                self.active = False
                emit_event(EventType.MENU_CLOSED, {'type': 'cinematic'})
                return True
                
        return False
        
    def _hsv_to_rgb(self, h: float, s: float, v: float) -> Tuple[int, int, int]:
        """HSV를 RGB로 변환"""
        h = h / 360.0
        c = v * s
        x = c * (1 - abs((h * 6) % 2 - 1))
        m = v - c
        
        if h < 1/6:
            r, g, b = c, x, 0
        elif h < 2/6:
            r, g, b = x, c, 0
        elif h < 3/6:
            r, g, b = 0, c, x
        elif h < 4/6:
            r, g, b = 0, x, c
        elif h < 5/6:
            r, g, b = x, 0, c
        else:
            r, g, b = c, 0, x
            
        return (int((r + m) * 255), int((g + m) * 255), int((b + m) * 255))
        
    def is_active(self) -> bool:
        """활성 상태 확인"""
        return self.active


# 싱글톤 인스턴스
_opening_system = None

def get_opening_system() -> OpeningSystem:
    """오프닝 시스템 싱글톤 반환"""
    global _opening_system
    if _opening_system is None:
        _opening_system = OpeningSystem()
    return _opening_system