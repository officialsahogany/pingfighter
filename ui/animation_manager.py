"""
애니메이션 및 트랜지션 관리 시스템
부드러운 UI 애니메이션과 전환 효과를 제공합니다.
"""
import pygame
import math
from typing import Callable, Optional, Dict, Any

class AnimationManager:
    """UI 애니메이션 및 트랜지션 관리"""
    
    def __init__(self):
        self.animations = {}
        self.active_animations = []
    
    # === Easing Functions (가속도 함수) ===
    @staticmethod
    def ease_linear(t: float) -> float:
        """선형 보간"""
        return t
    
    @staticmethod
    def ease_in_quad(t: float) -> float:
        """제곱 가속 시작"""
        return t * t
    
    @staticmethod
    def ease_out_quad(t: float) -> float:
        """제곱 감속 종료"""
        return t * (2 - t)
    
    @staticmethod
    def ease_in_out_quad(t: float) -> float:
        """제곱 가속 시작, 감속 종료"""
        return 2 * t * t if t < 0.5 else -1 + (4 - 2 * t) * t
    
    @staticmethod
    def ease_in_cubic(t: float) -> float:
        """세제곱 가속 시작"""
        return t * t * t
    
    @staticmethod
    def ease_out_cubic(t: float) -> float:
        """세제곱 감속 종료"""
        return 1 + (t - 1) ** 3
    
    @staticmethod
    def ease_in_out_cubic(t: float) -> float:
        """세제곱 가속 시작, 감속 종료"""
        return 4 * t * t * t if t < 0.5 else 1 + (t - 1) * (2 * (t - 2)) ** 2
    
    @staticmethod
    def ease_elastic(t: float) -> float:
        """탄성 효과"""
        if t == 0 or t == 1:
            return t
        p = 0.3
        s = p / 4
        return -(2 ** (10 * (t - 1))) * math.sin((t - 1 - s) * (2 * math.pi) / p)
    
    @staticmethod
    def ease_bounce(t: float) -> float:
        """바운스 효과"""
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
    
    @staticmethod
    def ease_back(t: float) -> float:
        """뒤로 당겼다가 나가는 효과"""
        s = 1.70158
        return t * t * ((s + 1) * t - s)

class Animation:
    """개별 애니메이션 클래스"""
    
    def __init__(self, 
                 start_value: Any,
                 end_value: Any,
                 duration: float,
                 easing_func: Callable = AnimationManager.ease_in_out_quad,
                 on_update: Optional[Callable] = None,
                 on_complete: Optional[Callable] = None):
        
        self.start_value = start_value
        self.end_value = end_value
        self.duration = duration
        self.easing_func = easing_func
        self.on_update = on_update
        self.on_complete = on_complete
        
        self.elapsed_time = 0
        self.current_value = start_value
        self.is_complete = False
        self.is_paused = False
    
    def update(self, dt: float):
        """애니메이션 업데이트"""
        if self.is_complete or self.is_paused:
            return
        
        self.elapsed_time += dt
        progress = min(self.elapsed_time / self.duration, 1.0)
        eased_progress = self.easing_func(progress)
        
        # 값 타입에 따라 다르게 처리
        if isinstance(self.start_value, (int, float)):
            self.current_value = self.start_value + (self.end_value - self.start_value) * eased_progress
        elif isinstance(self.start_value, tuple):
            self.current_value = tuple(
                start + (end - start) * eased_progress 
                for start, end in zip(self.start_value, self.end_value)
            )
        elif isinstance(self.start_value, pygame.Rect):
            self.current_value = pygame.Rect(
                self.start_value.x + (self.end_value.x - self.start_value.x) * eased_progress,
                self.start_value.y + (self.end_value.y - self.start_value.y) * eased_progress,
                self.start_value.width + (self.end_value.width - self.start_value.width) * eased_progress,
                self.start_value.height + (self.end_value.height - self.start_value.height) * eased_progress
            )
        
        if self.on_update:
            self.on_update(self.current_value)
        
        if progress >= 1.0:
            self.is_complete = True
            if self.on_complete:
                self.on_complete()
    
    def pause(self):
        """애니메이션 일시정지"""
        self.is_paused = True
    
    def resume(self):
        """애니메이션 재개"""
        self.is_paused = False
    
    def reset(self):
        """애니메이션 리셋"""
        self.elapsed_time = 0
        self.current_value = self.start_value
        self.is_complete = False
        self.is_paused = False

class UITransitions:
    """UI 전환 효과 모음"""
    
    @staticmethod
    def fade_in(surface: pygame.Surface, alpha: float) -> pygame.Surface:
        """페이드 인 효과"""
        surface.set_alpha(int(alpha * 255))
        return surface
    
    @staticmethod
    def fade_out(surface: pygame.Surface, alpha: float) -> pygame.Surface:
        """페이드 아웃 효과"""
        surface.set_alpha(int((1 - alpha) * 255))
        return surface
    
    @staticmethod
    def slide_in(rect: pygame.Rect, progress: float, direction: str = 'left') -> pygame.Rect:
        """슬라이드 인 효과"""
        new_rect = rect.copy()
        
        if direction == 'left':
            new_rect.x = -rect.width + (rect.width * progress)
        elif direction == 'right':
            new_rect.x = pygame.display.get_surface().get_width() - (rect.width * progress)
        elif direction == 'top':
            new_rect.y = -rect.height + (rect.height * progress)
        elif direction == 'bottom':
            new_rect.y = pygame.display.get_surface().get_height() - (rect.height * progress)
        
        return new_rect
    
    @staticmethod
    def scale(surface: pygame.Surface, scale_factor: float) -> pygame.Surface:
        """스케일 효과"""
        width = int(surface.get_width() * scale_factor)
        height = int(surface.get_height() * scale_factor)
        return pygame.transform.scale(surface, (width, height))
    
    @staticmethod
    def rotate(surface: pygame.Surface, angle: float) -> pygame.Surface:
        """회전 효과"""
        return pygame.transform.rotate(surface, angle)
    
    @staticmethod
    def shake(pos: tuple, intensity: float, offset_x: float = 0, offset_y: float = 0) -> tuple:
        """흔들기 효과"""
        import random
        shake_x = random.uniform(-intensity, intensity) + offset_x
        shake_y = random.uniform(-intensity, intensity) + offset_y
        return (pos[0] + shake_x, pos[1] + shake_y)
    
    @staticmethod
    def pulse(scale: float, time: float, frequency: float = 1.0) -> float:
        """펄스 효과"""
        return scale + math.sin(time * frequency * 2 * math.pi) * 0.1
    
    @staticmethod
    def glow(surface: pygame.Surface, color: tuple, intensity: float) -> pygame.Surface:
        """발광 효과"""
        glow_surf = pygame.Surface(surface.get_size(), pygame.SRCALPHA)
        glow_surf.fill((*color, int(intensity * 50)))
        surface.blit(glow_surf, (0, 0), special_flags=pygame.BLEND_ADD)
        return surface

class AnimationSequence:
    """연속 애니메이션 시퀀스"""
    
    def __init__(self):
        self.animations = []
        self.current_index = 0
        self.is_complete = False
    
    def add(self, animation: Animation):
        """애니메이션 추가"""
        self.animations.append(animation)
        return self
    
    def update(self, dt: float):
        """시퀀스 업데이트"""
        if self.is_complete or self.current_index >= len(self.animations):
            self.is_complete = True
            return
        
        current_anim = self.animations[self.current_index]
        current_anim.update(dt)
        
        if current_anim.is_complete:
            self.current_index += 1
    
    def reset(self):
        """시퀀스 리셋"""
        self.current_index = 0
        self.is_complete = False
        for anim in self.animations:
            anim.reset()

# 전역 애니메이션 매니저
animation_manager = AnimationManager()