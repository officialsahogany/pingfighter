"""
AnimationSystem - 애니메이션 시스템
게임의 모든 애니메이션과 트랜지션 효과 관리
"""

import pygame
import math
import random
from typing import List, Dict, Any, Optional, Tuple, Callable
from core.events import EventType, emit_event


class Animation:
    """개별 애니메이션 클래스"""
    
    def __init__(self, duration: float, easing: str = 'linear', 
                 on_complete: Optional[Callable] = None):
        self.duration = duration
        self.easing = easing
        self.on_complete = on_complete
        self.elapsed = 0.0
        self.completed = False
        self.paused = False
        
    def update(self, dt: float) -> float:
        """애니메이션 업데이트
        
        Returns:
            진행률 (0.0 ~ 1.0)
        """
        if self.paused or self.completed:
            return self.get_progress()
            
        self.elapsed += dt
        
        if self.elapsed >= self.duration:
            self.elapsed = self.duration
            self.completed = True
            if self.on_complete:
                self.on_complete()
                
        return self.get_progress()
        
    def get_progress(self) -> float:
        """진행률 반환 (이징 적용)"""
        if self.duration == 0:
            return 1.0
            
        t = min(1.0, self.elapsed / self.duration)
        return self.apply_easing(t)
        
    def apply_easing(self, t: float) -> float:
        """이징 함수 적용"""
        if self.easing == 'linear':
            return t
        elif self.easing == 'ease_in':
            return t * t
        elif self.easing == 'ease_out':
            return 1 - (1 - t) * (1 - t)
        elif self.easing == 'ease_in_out':
            if t < 0.5:
                return 2 * t * t
            else:
                return 1 - pow(-2 * t + 2, 2) / 2
        elif self.easing == 'elastic':
            if t == 0 or t == 1:
                return t
            p = 0.3
            return pow(2, -10 * t) * math.sin((t - p / 4) * (2 * math.pi) / p) + 1
        elif self.easing == 'bounce':
            if t < 1 / 2.75:
                return 7.5625 * t * t
            elif t < 2 / 2.75:
                t -= 1.5 / 2.75
                return 7.5625 * t * t + 0.75
            elif t < 2.5 / 2.75:
                t -= 2.25 / 2.75
                return 7.5625 * t * t + 0.9375
            else:
                t -= 2.625 / 2.75
                return 7.5625 * t * t + 0.984375
        elif self.easing == 'back':
            c1 = 1.70158
            c3 = c1 + 1
            return 1 + c3 * pow(t - 1, 3) + c1 * pow(t - 1, 2)
        else:
            return t
            

class AnimationSystem:
    """애니메이션 시스템 관리자"""
    
    def __init__(self, screen: pygame.Surface):
        self.screen = screen
        self.animations = {}
        self.particles = []
        self.screen_effects = []
        self.transitions = []
        
        # 스크린 쉐이크
        self.shake_intensity = 0
        self.shake_duration = 0
        self.shake_offset = [0, 0]
        
        # 페이드 효과
        self.fade_surface = None
        self.fade_alpha = 0
        self.fade_target = 0
        self.fade_speed = 5
        
        # 플래시 효과
        self.flash_color = (255, 255, 255)
        self.flash_alpha = 0
        self.flash_duration = 0
        
        # 슬로우 모션
        self.time_scale = 1.0
        self.time_scale_target = 1.0
        self.time_scale_speed = 0.1
        
    def update(self, dt: float):
        """애니메이션 시스템 업데이트"""
        # 타임 스케일 적용
        scaled_dt = dt * self.time_scale
        
        # 애니메이션 업데이트
        completed_animations = []
        for name, anim in self.animations.items():
            anim.update(scaled_dt)
            if anim.completed:
                completed_animations.append(name)
                
        # 완료된 애니메이션 제거
        for name in completed_animations:
            del self.animations[name]
            
        # 파티클 업데이트
        self.update_particles(scaled_dt)
        
        # 스크린 효과 업데이트
        self.update_screen_effects(scaled_dt)
        
        # 트랜지션 업데이트
        self.update_transitions(scaled_dt)
        
        # 타임 스케일 보간
        if self.time_scale != self.time_scale_target:
            diff = self.time_scale_target - self.time_scale
            self.time_scale += diff * self.time_scale_speed
            if abs(diff) < 0.01:
                self.time_scale = self.time_scale_target
                
    def update_particles(self, dt: float):
        """파티클 업데이트"""
        alive_particles = []
        for particle in self.particles:
            particle['lifetime'] -= dt
            
            if particle['lifetime'] > 0:
                # 위치 업데이트
                particle['x'] += particle['vx'] * dt
                particle['y'] += particle['vy'] * dt
                
                # 중력 적용
                if 'gravity' in particle:
                    particle['vy'] += particle['gravity'] * dt
                    
                # 감속 적용
                if 'friction' in particle:
                    particle['vx'] *= (1 - particle['friction'])
                    particle['vy'] *= (1 - particle['friction'])
                    
                # 회전 업데이트
                if 'rotation_speed' in particle:
                    particle['rotation'] += particle['rotation_speed'] * dt
                    
                # 스케일 업데이트
                if 'scale_speed' in particle:
                    particle['scale'] += particle['scale_speed'] * dt
                    
                # 알파 업데이트
                if 'fade_speed' in particle:
                    particle['alpha'] = max(0, particle['alpha'] - particle['fade_speed'] * dt)
                    
                alive_particles.append(particle)
                
        self.particles = alive_particles
        
    def update_screen_effects(self, dt: float):
        """스크린 효과 업데이트"""
        # 스크린 쉐이크
        if self.shake_duration > 0:
            self.shake_duration -= dt
            if self.shake_duration <= 0:
                self.shake_offset = [0, 0]
            else:
                self.shake_offset[0] = random.uniform(-self.shake_intensity, self.shake_intensity)
                self.shake_offset[1] = random.uniform(-self.shake_intensity, self.shake_intensity)
                
        # 페이드 효과
        if self.fade_alpha != self.fade_target:
            diff = self.fade_target - self.fade_alpha
            self.fade_alpha += diff * self.fade_speed * dt
            if abs(diff) < 1:
                self.fade_alpha = self.fade_target
                
        # 플래시 효과
        if self.flash_duration > 0:
            self.flash_duration -= dt
            if self.flash_duration <= 0:
                self.flash_alpha = 0
            else:
                # 플래시 페이드 아웃
                self.flash_alpha = int(255 * (self.flash_duration / 0.2))
                
    def update_transitions(self, dt: float):
        """트랜지션 업데이트"""
        alive_transitions = []
        for transition in self.transitions:
            transition['elapsed'] += dt
            progress = min(1.0, transition['elapsed'] / transition['duration'])
            
            if progress >= 1.0:
                if transition.get('on_complete'):
                    transition['on_complete']()
            else:
                alive_transitions.append(transition)
                
        self.transitions = alive_transitions
        
    def draw_particles(self):
        """파티클 그리기"""
        for particle in self.particles:
            if particle['alpha'] <= 0:
                continue
                
            x, y = int(particle['x']), int(particle['y'])
            
            if particle['type'] == 'circle':
                color = (*particle['color'], int(particle['alpha']))
                size = int(particle['size'] * particle.get('scale', 1.0))
                
                # 글로우 효과
                if particle.get('glow'):
                    for i in range(3):
                        glow_size = size + i * 2
                        glow_alpha = int(particle['alpha'] * 0.3 / (i + 1))
                        glow_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                        pygame.draw.circle(glow_surface, (*particle['color'], glow_alpha),
                                         (glow_size, glow_size), glow_size)
                        self.screen.blit(glow_surface, (x - glow_size, y - glow_size))
                        
                # 메인 파티클
                particle_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                pygame.draw.circle(particle_surface, color, (size, size), size)
                
                # 회전 적용
                if 'rotation' in particle:
                    particle_surface = pygame.transform.rotate(particle_surface, particle['rotation'])
                    
                self.screen.blit(particle_surface, 
                               (x - particle_surface.get_width() // 2,
                                y - particle_surface.get_height() // 2))
                                
            elif particle['type'] == 'spark':
                # 스파크 파티클
                length = particle.get('length', 10)
                angle = math.atan2(particle['vy'], particle['vx'])
                end_x = x - math.cos(angle) * length
                end_y = y - math.sin(angle) * length
                
                color = (*particle['color'], int(particle['alpha']))
                pygame.draw.line(self.screen, color, (x, y), (end_x, end_y), 2)
                
            elif particle['type'] == 'star':
                # 별 모양 파티클
                size = int(particle['size'] * particle.get('scale', 1.0))
                points = []
                for i in range(10):
                    angle = math.pi * 2 * i / 10
                    if i % 2 == 0:
                        radius = size
                    else:
                        radius = size * 0.5
                    px = x + math.cos(angle) * radius
                    py = y + math.sin(angle) * radius
                    points.append((px, py))
                    
                color = (*particle['color'], int(particle['alpha']))
                if len(points) >= 3:
                    particle_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                    pygame.draw.polygon(particle_surface, color, 
                                      [(p[0] - x + size, p[1] - y + size) for p in points])
                    self.screen.blit(particle_surface, (x - size, y - size))
                    
    def draw_screen_effects(self):
        """스크린 효과 그리기"""
        # 페이드 효과
        if self.fade_alpha > 0:
            if not self.fade_surface:
                self.fade_surface = pygame.Surface(self.screen.get_size(), pygame.SRCALPHA)
            self.fade_surface.fill((0, 0, 0, int(self.fade_alpha)))
            self.screen.blit(self.fade_surface, (0, 0))
            
        # 플래시 효과
        if self.flash_alpha > 0:
            flash_surface = pygame.Surface(self.screen.get_size(), pygame.SRCALPHA)
            flash_surface.fill((*self.flash_color, int(self.flash_alpha)))
            self.screen.blit(flash_surface, (0, 0))
            
        # 트랜지션 효과
        for transition in self.transitions:
            self.draw_transition(transition)
            
    def draw_transition(self, transition: Dict[str, Any]):
        """트랜지션 그리기"""
        progress = min(1.0, transition['elapsed'] / transition['duration'])
        
        if transition['type'] == 'wipe':
            # 와이프 트랜지션
            width = int(self.screen.get_width() * progress)
            rect = pygame.Rect(0, 0, width, self.screen.get_height())
            pygame.draw.rect(self.screen, transition.get('color', (0, 0, 0)), rect)
            
        elif transition['type'] == 'circle':
            # 원형 트랜지션
            center = transition.get('center', (self.screen.get_width() // 2, 
                                              self.screen.get_height() // 2))
            max_radius = math.sqrt(self.screen.get_width() ** 2 + self.screen.get_height() ** 2)
            radius = int(max_radius * progress)
            
            mask_surface = pygame.Surface(self.screen.get_size(), pygame.SRCALPHA)
            if transition.get('reverse'):
                mask_surface.fill((0, 0, 0, 255))
                pygame.draw.circle(mask_surface, (0, 0, 0, 0), center, radius)
            else:
                pygame.draw.circle(mask_surface, (0, 0, 0, 255), center, radius)
            self.screen.blit(mask_surface, (0, 0))
            
        elif transition['type'] == 'fade':
            # 페이드 트랜지션
            alpha = int(255 * progress)
            if transition.get('reverse'):
                alpha = 255 - alpha
            fade_surface = pygame.Surface(self.screen.get_size(), pygame.SRCALPHA)
            fade_surface.fill((*transition.get('color', (0, 0, 0)), alpha))
            self.screen.blit(fade_surface, (0, 0))
            
    # 애니메이션 생성 메서드들
    def create_animation(self, name: str, duration: float, 
                        easing: str = 'linear', on_complete: Optional[Callable] = None):
        """애니메이션 생성"""
        self.animations[name] = Animation(duration, easing, on_complete)
        
    def get_animation_progress(self, name: str) -> float:
        """애니메이션 진행률 반환"""
        if name in self.animations:
            return self.animations[name].get_progress()
        return 0.0
        
    def is_animating(self, name: str) -> bool:
        """애니메이션 진행 중 여부"""
        return name in self.animations and not self.animations[name].completed
        
    # 파티클 효과 메서드들
    def create_explosion(self, x: float, y: float, color: Tuple[int, int, int] = (255, 200, 0),
                        count: int = 20, speed: float = 200):
        """폭발 효과 생성"""
        for _ in range(count):
            angle = random.uniform(0, math.pi * 2)
            velocity = random.uniform(speed * 0.5, speed)
            self.particles.append({
                'type': 'circle',
                'x': x,
                'y': y,
                'vx': math.cos(angle) * velocity,
                'vy': math.sin(angle) * velocity,
                'size': random.uniform(2, 5),
                'color': color,
                'alpha': 255,
                'lifetime': random.uniform(0.5, 1.0),
                'friction': 0.02,
                'fade_speed': 300,
                'glow': True
            })
            
    def create_sparkle(self, x: float, y: float, color: Tuple[int, int, int] = (255, 255, 255)):
        """반짝임 효과 생성"""
        for _ in range(10):
            self.particles.append({
                'type': 'star',
                'x': x + random.uniform(-20, 20),
                'y': y + random.uniform(-20, 20),
                'vx': random.uniform(-50, 50),
                'vy': random.uniform(-100, -50),
                'size': random.uniform(3, 8),
                'color': color,
                'alpha': 255,
                'lifetime': random.uniform(0.3, 0.6),
                'gravity': 200,
                'fade_speed': 400,
                'rotation': 0,
                'rotation_speed': random.uniform(-360, 360),
                'scale': 1.0,
                'scale_speed': -0.5
            })
            
    def create_trail(self, x: float, y: float, vx: float, vy: float, 
                    color: Tuple[int, int, int] = (100, 200, 255)):
        """트레일 효과 생성"""
        self.particles.append({
            'type': 'spark',
            'x': x,
            'y': y,
            'vx': vx * 0.5 + random.uniform(-20, 20),
            'vy': vy * 0.5 + random.uniform(-20, 20),
            'length': 15,
            'color': color,
            'alpha': 200,
            'lifetime': 0.3,
            'fade_speed': 600
        })
        
    # 스크린 효과 메서드들
    def shake_screen(self, intensity: float = 10, duration: float = 0.3):
        """스크린 쉐이크"""
        self.shake_intensity = intensity
        self.shake_duration = duration
        emit_event(EventType.SCREEN_SHAKE, {'intensity': intensity, 'duration': duration})
        
    def flash_screen(self, color: Tuple[int, int, int] = (255, 255, 255), 
                    duration: float = 0.2):
        """스크린 플래시"""
        self.flash_color = color
        self.flash_alpha = 255
        self.flash_duration = duration
        
    def fade_in(self, duration: float = 1.0):
        """페이드 인"""
        self.fade_alpha = 255
        self.fade_target = 0
        self.fade_speed = 1.0 / duration
        
    def fade_out(self, duration: float = 1.0):
        """페이드 아웃"""
        self.fade_alpha = 0
        self.fade_target = 255
        self.fade_speed = 1.0 / duration
        
    def set_time_scale(self, scale: float, duration: float = 0.5):
        """타임 스케일 설정 (슬로우 모션)"""
        self.time_scale_target = scale
        self.time_scale_speed = 1.0 / duration
        
    # 트랜지션 메서드들
    def start_transition(self, transition_type: str, duration: float = 1.0,
                        **kwargs):
        """트랜지션 시작"""
        transition = {
            'type': transition_type,
            'duration': duration,
            'elapsed': 0.0,
            **kwargs
        }
        self.transitions.append(transition)
        
    def get_shake_offset(self) -> Tuple[float, float]:
        """스크린 쉐이크 오프셋 반환"""
        return self.shake_offset
        
    def clear_all(self):
        """모든 효과 초기화"""
        self.animations.clear()
        self.particles.clear()
        self.screen_effects.clear()
        self.transitions.clear()
        self.shake_duration = 0
        self.shake_offset = [0, 0]
        self.flash_alpha = 0
        self.fade_alpha = 0
        self.time_scale = 1.0
        self.time_scale_target = 1.0