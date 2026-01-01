import os
import sys

def resource_path(relative_path):
    """PyInstaller 번들과 일반 실행 모두에서 작동하는 리소스 경로 반환"""
    try:
        # PyInstaller 번들인 경우
        base_path = sys._MEIPASS
    except Exception:
        # 일반 Python 실행인 경우 - 상위 디렉토리로 이동
        base_path = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
    
    return os.path.join(base_path, relative_path)


# -*- coding: utf-8 -*-
import pygame
import math
import random

class AnimatedBackground:
    def __init__(self, base_image_path="stage1_field.png", target_width=None, target_height=None):
        original_image = pygame.image.load(resource_path(base_image_path)).convert()

        # 타겟 크기가 지정되면 이미지를 미리 스케일링 (이중 스케일링 방지)
        if target_width and target_height:
            self.base_image = pygame.transform.smoothscale(original_image, (target_width, target_height))
            self.width = target_width
            self.height = target_height
        else:
            self.base_image = original_image
            self.width = self.base_image.get_width()
            self.height = self.base_image.get_height()

        self.time = 0

        self.glow_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self.grid_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)

        self.center_x = self.width // 2
        self.center_y = self.height // 2
        self.taegeuk_radius = 80  # 더 크게

        self.grid_particles = []
        for _ in range(20):
            self.grid_particles.append({
                'x': random.randint(0, self.width),
                'y': random.randint(self.height//2, self.height),
                'speed': random.uniform(0.5, 2),
                'size': random.randint(1, 3)
            })
    
    def update(self, dt):
        self.time += dt
        
        for particle in self.grid_particles:
            particle['y'] -= particle['speed']
            if particle['y'] < self.height // 2:
                particle['y'] = self.height
                particle['x'] = random.randint(0, self.width)
    
    def draw(self, screen):
        screen.blit(self.base_image, (0, 0))
        
        self.glow_surface.fill((0, 0, 0, 0))
        
        pulse = math.sin(self.time * 0.002) * 0.5 + 0.5
        glow_alpha = int(80 + pulse * 100)  # 더 진하게
        glow_radius = self.taegeuk_radius + int(pulse * 15)
        
        for i in range(3):
            radius = glow_radius + i * 10
            alpha = max(0, glow_alpha - i * 30)
            if alpha > 0:
                pygame.draw.circle(self.glow_surface, 
                                 (25, 25, 200, alpha),  # 군청색 계열 글로우
                                 (self.center_x, self.center_y),
                                 radius)
        
        rotation = self.time * 0.001
        rotated_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        for angle in range(0, 360, 90):
            rad = math.radians(angle + rotation * 50)
            x = self.center_x + math.cos(rad) * (self.taegeuk_radius + 30)
            y = self.center_y + math.sin(rad) * (self.taegeuk_radius + 30)
            
            spark_alpha = int(100 + pulse * 100)
            pygame.draw.circle(rotated_surface,
                             (50, 50, 255, spark_alpha),  # 군청색 스파크
                             (int(x), int(y)), 3)
        
        screen.blit(self.glow_surface, (0, 0), special_flags=pygame.BLEND_ADD)
        screen.blit(rotated_surface, (0, 0), special_flags=pygame.BLEND_ADD)
        
        self.grid_surface.fill((0, 0, 0, 0))
        for particle in self.grid_particles:
            alpha = int(100 * (1 - (particle['y'] - self.height//2) / (self.height//2)))
            if alpha > 0:
                pygame.draw.circle(self.grid_surface,
                                 (25, 25, 150, alpha),  # 군청색 파티클
                                 (int(particle['x']), int(particle['y'])),
                                 particle['size'])
        
        screen.blit(self.grid_surface, (0, 0), special_flags=pygame.BLEND_ADD)
        
        if int(self.time / 1000) % 3 == 0:
            flash_alpha = int(abs(math.sin(self.time * 0.01)) * 20)
            flash_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            # 검은색 번쩍임 효과
            pygame.draw.circle(flash_surface,
                             (10, 10, 10, flash_alpha),  # 거의 검은색
                             (self.center_x, self.center_y),
                             self.taegeuk_radius + 10)
            screen.blit(flash_surface, (0, 0), special_flags=pygame.BLEND_ADD)