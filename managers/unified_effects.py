"""
Unified Effects Manager - Phase 101
통합 효과 관리 시스템
"""

import pygame
import math
import random

class UnifiedEffectsManager:
    """통합 효과 관리자"""
    
    def __init__(self):
        self.particles = []  # 모든 파티클
        self.trails = []  # 모든 잔상
        self.explosions = []  # 폭발 효과
        self.texts = []  # 텍스트 효과
        self.special_effects = []  # 특수 효과
        
    def update(self, dt=1/60):
        """모든 효과 업데이트"""
        # 파티클 업데이트
        new_particles = []
        for particle in self.particles:
            particle['life'] -= dt * 60
            if particle['life'] > 0:
                particle['x'] += particle['vx'] * dt * 60
                particle['y'] += particle['vy'] * dt * 60
                particle['vy'] += particle.get('gravity', 0.5) * dt * 60
                new_particles.append(particle)
        self.particles = new_particles
        
        # 잔상 업데이트
        new_trails = []
        for trail in self.trails:
            trail['alpha'] *= 0.95
            if trail['alpha'] > 10:
                new_trails.append(trail)
        self.trails = new_trails
        
        # 폭발 업데이트
        new_explosions = []
        for explosion in self.explosions:
            explosion['radius'] += explosion.get('expansion', 2)
            explosion['alpha'] *= 0.9
            if explosion['alpha'] > 10:
                new_explosions.append(explosion)
        self.explosions = new_explosions
        
        # 텍스트 효과 업데이트
        new_texts = []
        for text in self.texts:
            text['y'] -= text.get('rise_speed', 1)
            text['alpha'] *= 0.98
            if text['alpha'] > 10:
                new_texts.append(text)
        self.texts = new_texts
        
    def spawn_particles(self, x, y, count=10, color=(255, 255, 255), 
                       speed_range=(2, 8), life=60, gravity=0.5):
        """파티클 생성"""
        for _ in range(count):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(*speed_range)
            self.particles.append({
                'x': x,
                'y': y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'color': color,
                'life': life,
                'size': random.randint(2, 5),
                'gravity': gravity
            })
            
    def spawn_directional_particles(self, x, y, direction, spread=30, 
                                   count=5, color=(255, 255, 0), speed=10):
        """방향성 파티클 생성"""
        for _ in range(count):
            angle_offset = random.uniform(-spread, spread) * math.pi / 180
            angle = direction + angle_offset
            speed_variance = speed * random.uniform(0.8, 1.2)
            
            self.particles.append({
                'x': x,
                'y': y,
                'vx': math.cos(angle) * speed_variance,
                'vy': math.sin(angle) * speed_variance,
                'color': color,
                'life': 45,
                'size': random.randint(3, 6),
                'gravity': 0.3
            })
            
    def spawn_explosion(self, x, y, radius=50, color=(255, 100, 0)):
        """폭발 효과 생성"""
        self.explosions.append({
            'x': x,
            'y': y,
            'radius': 10,
            'max_radius': radius,
            'color': color,
            'alpha': 255,
            'expansion': 3
        })
        
        # 폭발 파티클도 함께 생성
        self.spawn_particles(x, y, count=20, color=color, 
                           speed_range=(5, 15), life=45)
                           
    def add_trail(self, x, y, color=(255, 255, 255), size=10):
        """잔상 추가"""
        self.trails.append({
            'x': x,
            'y': y,
            'color': color,
            'size': size,
            'alpha': 200
        })
        
    def spawn_text(self, x, y, text, color=(255, 255, 255), size=20, 
                  rise_speed=1, font=None):
        """텍스트 효과 생성"""
        self.texts.append({
            'x': x,
            'y': y,
            'text': text,
            'color': color,
            'size': size,
            'alpha': 255,
            'rise_speed': rise_speed,
            'font': font
        })
        
    def spawn_star_burst(self, x, y, count=8, radius=50, color=(255, 255, 0)):
        """별 모양 폭발"""
        for i in range(count):
            angle = (i / count) * 2 * math.pi
            end_x = x + math.cos(angle) * radius
            end_y = y + math.sin(angle) * radius
            
            # 각 방향으로 파티클 생성
            for j in range(5):
                t = j / 5
                px = x + (end_x - x) * t
                py = y + (end_y - y) * t
                self.particles.append({
                    'x': px,
                    'y': py,
                    'vx': math.cos(angle) * 2,
                    'vy': math.sin(angle) * 2,
                    'color': color,
                    'life': 30 + j * 5,
                    'size': 5 - j,
                    'gravity': 0
                })
                
    def spawn_ring_wave(self, x, y, color=(100, 200, 255)):
        """링 웨이브 효과"""
        self.special_effects.append({
            'type': 'ring_wave',
            'x': x,
            'y': y,
            'radius': 10,
            'max_radius': 100,
            'color': color,
            'alpha': 255,
            'thickness': 3
        })
        
    def spawn_shockwave(self, x, y, force=10, color=(255, 255, 255)):
        """충격파 효과"""
        self.special_effects.append({
            'type': 'shockwave',
            'x': x,
            'y': y,
            'radius': 0,
            'max_radius': 150,
            'force': force,
            'color': color,
            'alpha': 200
        })
        
        # 주변 파티클도 밀어냄
        for particle in self.particles:
            dx = particle['x'] - x
            dy = particle['y'] - y
            dist = math.hypot(dx, dy)
            if dist > 0 and dist < 100:
                push_force = force * (1 - dist / 100)
                particle['vx'] += (dx / dist) * push_force
                particle['vy'] += (dy / dist) * push_force
                
    def clear(self):
        """모든 효과 제거"""
        self.particles.clear()
        self.trails.clear()
        self.explosions.clear()
        self.texts.clear()
        self.special_effects.clear()
        
    def clear_type(self, effect_type):
        """특정 타입의 효과만 제거"""
        if effect_type == 'particles':
            self.particles.clear()
        elif effect_type == 'trails':
            self.trails.clear()
        elif effect_type == 'explosions':
            self.explosions.clear()
        elif effect_type == 'texts':
            self.texts.clear()
        elif effect_type == 'special':
            self.special_effects.clear()
            
    def get_particle_count(self):
        """현재 파티클 수 반환"""
        return len(self.particles)
        
    def get_total_effects(self):
        """전체 효과 수 반환"""
        return (len(self.particles) + len(self.trails) + 
                len(self.explosions) + len(self.texts) + 
                len(self.special_effects))