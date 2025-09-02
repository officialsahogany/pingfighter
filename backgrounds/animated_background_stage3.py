import pygame
import math
import random

class AnimatedBackgroundStage3:
    def __init__(self, base_image_path="stage3_field.png"):
        self.base_image = pygame.image.load(base_image_path).convert()
        self.width = self.base_image.get_width()
        self.height = self.base_image.get_height()
        self.time = 0
        
        self.glow_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self.particle_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        self.center_x = self.width // 2
        self.center_y = self.height // 2
        
        # 떨어지는 벚꽃 잎 (2~3개만)
        self.sakura_petals = []
        for _ in range(3):
            self.sakura_petals.append({
                'x': random.randint(100, self.width - 100),
                'y': random.randint(-100, 0),
                'speed': random.uniform(0.5, 1.5),
                'sway': random.uniform(0, math.pi * 2),
                'size': random.randint(8, 12),
                'rotation': random.uniform(0, math.pi * 2)
            })
        
        # 하트 펄스 제거
        
        # 글리치 효과 제거
        
        # 픽셀 하트 애니메이션
        self.pixel_heart_pulse = 0
    
    def update(self, dt):
        self.time += dt
        self.pixel_heart_pulse = math.sin(self.time * 0.003) * 0.5 + 0.5
        
        # 벚꽃 잎 떨어지기
        for petal in self.sakura_petals:
            petal['y'] += petal['speed']
            petal['sway'] += 0.02
            petal['x'] += math.sin(petal['sway']) * 2
            petal['rotation'] += 0.05
            
            # 바닥에 닿으면 다시 위로
            if petal['y'] > self.height:
                petal['y'] = random.randint(-100, -20)
                petal['x'] = random.randint(0, self.width)
        
        # 글리치 효과 제거됨
    
    def draw(self, screen):
        screen.blit(self.base_image, (0, 0))
        
        self.glow_surface.fill((0, 0, 0, 0))
        
        # 가운데 효과 제거 - 깔끔한 배경 유지
        
        # 떨어지는 벚꽃 잎
        self.particle_surface.fill((0, 0, 0, 0))
        for petal in self.sakura_petals:
            # 5개 꽃잎 그리기
            for i in range(5):
                angle = i * 72 + math.degrees(petal['rotation'])
                rad = math.radians(angle)
                x = petal['x'] + math.cos(rad) * petal['size']
                y = petal['y'] + math.sin(rad) * petal['size']
                
                petal_alpha = 150
                pygame.draw.ellipse(self.particle_surface,
                                  (255, 150, 200, petal_alpha),
                                  (int(x - 5), int(y - 3), 10, 6))
        
        screen.blit(self.particle_surface, (0, 0), special_flags=pygame.BLEND_ADD)
        
        # 픽셀 하트 테두리 펄스
        if self.pixel_heart_pulse > 0.7:
            border_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
            alpha = int((self.pixel_heart_pulse - 0.7) * 500)
            
            # 상단 하트들 빛나기
            for i in range(0, self.width, 40):
                pygame.draw.circle(border_surface,
                                 (255, 100, 200, min(alpha, 100)),
                                 (i + 20, 30), 15)
            
            # 하단 하트들 빛나기
            for i in range(0, self.width, 40):
                pygame.draw.circle(border_surface,
                                 (255, 100, 200, min(alpha, 100)),
                                 (i + 20, self.height - 30), 15)
            
            screen.blit(border_surface, (0, 0), special_flags=pygame.BLEND_ADD)