import pygame
import math
import random

class AnimatedBackgroundStage4:
    def __init__(self, base_image_path="stage4_field.png"):
        self.base_image = pygame.image.load(base_image_path).convert()
        self.width = self.base_image.get_width()
        self.height = self.base_image.get_height()
        self.time = 0

        # 서피스 재사용 (최적화)
        self.glow_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self.particle_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        self._transparent = (0, 0, 0, 0)  # fill용 투명 색상 캐시
        
        self.center_x = self.width // 2
        self.center_y = self.height // 2
        
        # 명상 원 펄스
        self.meditation_pulse = 0
        
        # 디지털 입자 (최소한으로)
        self.digital_particles = []
        for _ in range(10):
            self.digital_particles.append({
                'x': random.choice([random.randint(0, 100), random.randint(self.width - 100, self.width)]),
                'y': random.randint(200, self.height - 200),
                'speed': random.uniform(0.1, 0.3),
                'alpha': random.randint(20, 50),
                'size': random.randint(1, 3)
            })
        
        # 홀로그램 연꽃 회전
        self.lotus_rotation = 0
    
    def update(self, dt):
        self.time += dt
        self.meditation_pulse = math.sin(self.time * 0.002) * 0.5 + 0.5
        self.lotus_rotation += dt * 0.0001
        
        # 디지털 입자 위로 이동
        for particle in self.digital_particles:
            particle['y'] -= particle['speed']
            
            # 화면 밖으로 나가면 아래에서 다시 시작
            if particle['y'] < 0:
                particle['y'] = self.height
                particle['x'] = random.choice([random.randint(0, 100), 
                                              random.randint(self.width - 100, self.width)])
    
    def draw(self, screen):
        screen.blit(self.base_image, (0, 0))

        self.glow_surface.fill(self._transparent)
        
        # 명상 원 펄스 효과 (아주 희미하게)
        if self.meditation_pulse > 0.7:
            alpha = int((self.meditation_pulse - 0.7) * 100)
            pygame.draw.circle(self.glow_surface,
                             (150, 120, 200, min(alpha, 30)),
                             (self.center_x, self.center_y),
                             65, width=2)
        
        # 홀로그램 연꽃 회전 효과 (좌측)
        lotus_x, lotus_y = 100, self.center_y
        for petal in range(8):
            angle = petal * 45 + math.degrees(self.lotus_rotation)
            rad = math.radians(angle)
            px = lotus_x + math.cos(rad) * 25
            py = lotus_y + math.sin(rad) * 25
            
            petal_alpha = int(30 + math.sin(self.time * 0.003 + petal) * 20)
            pygame.draw.ellipse(self.glow_surface,
                              (180, 150, 255, max(petal_alpha, 0)),
                              (int(px - 10), int(py - 5), 20, 10))
        
        # 홀로그램 연꽃 회전 효과 (우측)
        lotus_x, lotus_y = self.width - 100, self.center_y
        for petal in range(8):
            angle = petal * 45 - math.degrees(self.lotus_rotation)
            rad = math.radians(angle)
            px = lotus_x + math.cos(rad) * 25
            py = lotus_y + math.sin(rad) * 25
            
            petal_alpha = int(30 + math.sin(self.time * 0.003 + petal) * 20)
            pygame.draw.ellipse(self.glow_surface,
                              (180, 150, 255, max(petal_alpha, 0)),
                              (int(px - 10), int(py - 5), 20, 10))
        
        screen.blit(self.glow_surface, (0, 0), special_flags=pygame.BLEND_ADD)
        
        # 디지털 입자 그리기
        self.particle_surface.fill(self._transparent)
        for particle in self.digital_particles:
            pygame.draw.circle(self.particle_surface,
                             (200, 180, 255, particle['alpha']),
                             (int(particle['x']), int(particle['y'])),
                             particle['size'])
        
        screen.blit(self.particle_surface, (0, 0), special_flags=pygame.BLEND_ADD)
        
        # 디지털 라인 플래시 (가끔씩)
        if random.random() > 0.98:
            flash_y = random.randint(200, self.height - 200)
            flash_alpha = 80
            
            # 좌측 플래시
            pygame.draw.line(screen, (200, 150, 255, flash_alpha),
                           (10, flash_y), (40, flash_y), 2)
            
            # 우측 플래시
            pygame.draw.line(screen, (200, 150, 255, flash_alpha),
                           (self.width - 40, flash_y), (self.width - 10, flash_y), 2)