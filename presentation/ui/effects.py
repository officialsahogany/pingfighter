"""
UI 효과 시스템 모듈
- 화면 전환 효과
- 텍스트 애니메이션
- 파티클 효과
- 화면 흔들림
- 페이드 효과
"""

import pygame
import math
import random


class UIEffects:
    """UI 효과 시스템 클래스"""
    
    def __init__(self, screen, width, height):
        self.screen = screen
        self.width = width
        self.height = height
        
        # 효과 상태
        self.shake_intensity = 0
        self.shake_duration = 0
        self.fade_alpha = 0
        self.fade_target = 0
        self.fade_speed = 5
        
        # 파티클 시스템
        self.particles = []
        
        # 텍스트 애니메이션
        self.floating_texts = []
        
    def update(self):
        """매 프레임마다 호출되어 효과들을 업데이트"""
        # 화면 흔들림 업데이트
        if self.shake_duration > 0:
            self.shake_duration -= 1
            if self.shake_duration <= 0:
                self.shake_intensity = 0
        
        # 페이드 효과 업데이트
        if self.fade_alpha != self.fade_target:
            diff = self.fade_target - self.fade_alpha
            if abs(diff) < self.fade_speed:
                self.fade_alpha = self.fade_target
            else:
                self.fade_alpha += self.fade_speed if diff > 0 else -self.fade_speed
        
        # 파티클 업데이트
        self.update_particles()
        
        # 떠다니는 텍스트 업데이트
        self.update_floating_texts()
    
    def shake_screen(self, intensity=10, duration=10):
        """화면 흔들림 효과 시작
        
        Args:
            intensity: 흔들림 강도 (픽셀)
            duration: 지속 시간 (프레임)
        """
        self.shake_intensity = intensity
        self.shake_duration = duration
    
    def get_shake_offset(self):
        """현재 화면 흔들림 오프셋 반환
        
        Returns:
            tuple: (x_offset, y_offset)
        """
        if self.shake_duration > 0:
            x_offset = random.randint(-self.shake_intensity, self.shake_intensity)
            y_offset = random.randint(-self.shake_intensity, self.shake_intensity)
            return (x_offset, y_offset)
        return (0, 0)
    
    def fade_in(self, speed=5):
        """페이드 인 효과 시작"""
        self.fade_alpha = 255
        self.fade_target = 0
        self.fade_speed = speed
    
    def fade_out(self, speed=5):
        """페이드 아웃 효과 시작"""
        self.fade_alpha = 0
        self.fade_target = 255
        self.fade_speed = speed
    
    def draw_fade(self):
        """페이드 효과 그리기"""
        if self.fade_alpha > 0:
            fade_surf = pygame.Surface((self.width, self.height))
            fade_surf.set_alpha(self.fade_alpha)
            fade_surf.fill((0, 0, 0))
            self.screen.blit(fade_surf, (0, 0))
    
    def spawn_explosion_particles(self, x, y, count=20, color=None):
        """폭발 파티클 생성
        
        Args:
            x, y: 폭발 중심 위치
            count: 파티클 개수
            color: 파티클 색상 (None이면 랜덤)
        """
        colors = [
            (255, 100, 0),  # 주황
            (255, 200, 0),  # 노랑
            (255, 50, 0),   # 빨강
            (255, 255, 255) # 흰색
        ]
        
        for _ in range(count):
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2, 8)
            
            particle = {
                "x": x,
                "y": y,
                "vx": math.cos(angle) * speed,
                "vy": math.sin(angle) * speed,
                "size": random.randint(2, 6),
                "color": color if color else random.choice(colors),
                "life": random.randint(20, 40),
                "max_life": 40,
                "gravity": 0.3
            }
            self.particles.append(particle)
    
    def spawn_sparkle_particles(self, x, y, count=10):
        """반짝임 파티클 생성"""
        for _ in range(count):
            particle = {
                "x": x + random.randint(-20, 20),
                "y": y + random.randint(-20, 20),
                "vx": random.uniform(-1, 1),
                "vy": random.uniform(-2, -0.5),
                "size": random.randint(1, 3),
                "color": (255, 255, 200),
                "life": random.randint(15, 30),
                "max_life": 30,
                "gravity": 0,
                "sparkle": True
            }
            self.particles.append(particle)
    
    def update_particles(self):
        """파티클 업데이트"""
        for particle in self.particles[:]:
            # 이동
            particle["x"] += particle["vx"]
            particle["y"] += particle["vy"]
            
            # 중력 적용
            if "gravity" in particle:
                particle["vy"] += particle["gravity"]
            
            # 수명 감소
            particle["life"] -= 1
            
            # 죽은 파티클 제거
            if particle["life"] <= 0:
                self.particles.remove(particle)
    
    def draw_particles(self):
        """파티클 그리기"""
        for particle in self.particles:
            # 알파값 계산 (수명에 따라)
            alpha_ratio = particle["life"] / particle["max_life"]
            alpha = int(255 * alpha_ratio)
            
            # 파티클 서페이스 생성
            size = particle["size"]
            if particle.get("sparkle"):
                # 반짝임 효과
                size = int(size * (0.5 + 0.5 * math.sin(particle["life"] * 0.5)))
            
            surf = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
            color = (*particle["color"], alpha)
            pygame.draw.circle(surf, color, (size, size), size)
            
            # 화면에 그리기
            self.screen.blit(surf, (particle["x"] - size, particle["y"] - size))
    
    def add_floating_text(self, text, x, y, color=(255, 255, 255), size=24, duration=60):
        """떠오르는 텍스트 추가
        
        Args:
            text: 표시할 텍스트
            x, y: 시작 위치
            color: 텍스트 색상
            size: 폰트 크기
            duration: 지속 시간 (프레임)
        """
        font = pygame.font.Font(None, size)
        text_surf = font.render(str(text), True, color)
        
        floating_text = {
            "surface": text_surf,
            "x": x,
            "y": y,
            "vy": -2,  # 위로 떠오르는 속도
            "life": duration,
            "max_life": duration,
            "color": color
        }
        self.floating_texts.append(floating_text)
    
    def update_floating_texts(self):
        """떠다니는 텍스트 업데이트"""
        for text in self.floating_texts[:]:
            # 위로 이동
            text["y"] += text["vy"]
            
            # 속도 감소 (점점 느려짐)
            text["vy"] *= 0.95
            
            # 수명 감소
            text["life"] -= 1
            
            # 죽은 텍스트 제거
            if text["life"] <= 0:
                self.floating_texts.remove(text)
    
    def draw_floating_texts(self):
        """떠다니는 텍스트 그리기"""
        for text in self.floating_texts:
            # 알파값 계산
            alpha_ratio = text["life"] / text["max_life"]
            alpha = int(255 * alpha_ratio)
            
            # 텍스트 그리기
            text["surface"].set_alpha(alpha)
            rect = text["surface"].get_rect(center=(text["x"], text["y"]))
            self.screen.blit(text["surface"], rect)
    
    def draw_lightning(self, start_pos, end_pos, color=(255, 255, 255), width=2, segments=10):
        """번개 효과 그리기
        
        Args:
            start_pos: 시작 위치 (x, y)
            end_pos: 끝 위치 (x, y)
            color: 번개 색상
            width: 선 굵기
            segments: 번개 세그먼트 수
        """
        points = [start_pos]
        
        # 중간 점들 생성 (지그재그)
        for i in range(1, segments):
            t = i / segments
            x = start_pos[0] + (end_pos[0] - start_pos[0]) * t
            y = start_pos[1] + (end_pos[1] - start_pos[1]) * t
            
            # 랜덤 오프셋 추가
            offset = 20 * (1 - abs(t - 0.5) * 2)  # 중간에서 최대 오프셋
            x += random.randint(-offset, offset)
            y += random.randint(-offset, offset)
            
            points.append((x, y))
        
        points.append(end_pos)
        
        # 번개 그리기
        for i in range(len(points) - 1):
            pygame.draw.line(self.screen, color, points[i], points[i + 1], width)
            
            # 밝은 중심선
            if width > 1:
                bright_color = tuple(min(255, c + 100) for c in color)
                pygame.draw.line(self.screen, bright_color, points[i], points[i + 1], max(1, width // 2))
    
    def draw_circle_wave(self, x, y, radius, color=(100, 200, 255), width=3):
        """원형 파동 효과
        
        Args:
            x, y: 중심 위치
            radius: 현재 반지름
            color: 파동 색상
            width: 선 굵기
        """
        if radius > 0:
            # 알파값 계산 (거리에 따라 희미해짐)
            max_radius = max(self.width, self.height)
            alpha = int(255 * (1 - radius / max_radius))
            
            # 파동 그리기
            surf = pygame.Surface((radius * 2 + 10, radius * 2 + 10), pygame.SRCALPHA)
            color_with_alpha = (*color, alpha)
            pygame.draw.circle(surf, color_with_alpha, 
                             (radius + 5, radius + 5), 
                             radius, width)
            
            self.screen.blit(surf, (x - radius - 5, y - radius - 5))
    
    def draw_gradient_rect(self, rect, color1, color2, horizontal=True):
        """그라데이션 사각형 그리기
        
        Args:
            rect: pygame.Rect 객체
            color1: 시작 색상
            color2: 끝 색상
            horizontal: True면 수평, False면 수직 그라데이션
        """
        if horizontal:
            for x in range(rect.width):
                ratio = x / rect.width
                r = int(color1[0] + (color2[0] - color1[0]) * ratio)
                g = int(color1[1] + (color2[1] - color1[1]) * ratio)
                b = int(color1[2] + (color2[2] - color1[2]) * ratio)
                pygame.draw.line(self.screen, (r, g, b), 
                               (rect.x + x, rect.y), 
                               (rect.x + x, rect.y + rect.height))
        else:
            for y in range(rect.height):
                ratio = y / rect.height
                r = int(color1[0] + (color2[0] - color1[0]) * ratio)
                g = int(color1[1] + (color2[1] - color1[1]) * ratio)
                b = int(color1[2] + (color2[2] - color1[2]) * ratio)
                pygame.draw.line(self.screen, (r, g, b), 
                               (rect.x, rect.y + y), 
                               (rect.x + rect.width, rect.y + y))


# 싱글톤 인스턴스
_ui_effects = None

def init_ui_effects(screen, width, height):
    """UI 효과 시스템 초기화"""
    global _ui_effects
    _ui_effects = UIEffects(screen, width, height)
    return _ui_effects

# 호환성을 위한 래퍼 함수들
def shake_screen(screen, intensity=10, duration=10, width=600, height=750):
    """화면 흔들림 효과 (호환성 래퍼)"""
    global _ui_effects
    if _ui_effects is None:
        _ui_effects = UIEffects(screen, width, height)
    _ui_effects.shake_screen(intensity, duration)

def spawn_explosion(screen, x, y, count=20, width=600, height=750):
    """폭발 효과 (호환성 래퍼)"""
    global _ui_effects
    if _ui_effects is None:
        _ui_effects = UIEffects(screen, width, height)
    _ui_effects.spawn_explosion_particles(x, y, count)

def add_floating_text(screen, text, x, y, color=(255, 255, 255), width=600, height=750):
    """떠오르는 텍스트 (호환성 래퍼)"""
    global _ui_effects
    if _ui_effects is None:
        _ui_effects = UIEffects(screen, width, height)
    _ui_effects.add_floating_text(text, x, y, color)