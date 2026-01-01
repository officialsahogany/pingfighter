import pygame
import math
import random

class AnimatedBackgroundStage5:
    def __init__(self, base_image_path="stage5_field.png"):
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
        
        # 팔괘 회전
        self.bagua_rotation = 0
        
        # 떨어지는 매화 꽃잎
        self.falling_petals = []
        for _ in range(8):
            self.falling_petals.append({
                'x': random.randint(50, 150),  # 주로 왼쪽 상단 근처
                'y': random.randint(-100, 0),
                'speed': random.uniform(0.3, 1.0),
                'sway': random.uniform(0, math.pi * 2),
                'size': random.randint(4, 8),
                'rotation': random.uniform(0, math.pi * 2),
                'color': random.choice([
                    (255, 180, 200),  # 핑크
                    (255, 160, 180),  # 연핑크
                    (255, 200, 220)   # 밝은 핑크
                ])
            })
        
        # 화염 입자
        self.flame_particles = []
        for _ in range(15):
            side = random.choice(['left', 'right'])
            if side == 'left':
                x = random.randint(10, 40)
            else:
                x = random.randint(self.width - 40, self.width - 10)
            self.flame_particles.append({
                'x': x,
                'y': random.randint(200, self.height - 200),
                'vx': random.uniform(-0.5, 0.5),
                'vy': random.uniform(-1.5, -0.5),
                'size': random.randint(2, 4),
                'life': random.randint(30, 60),
                'max_life': 60,
                'side': side
            })
        
        # 디지털 꽃 펄스
        self.digital_flower_pulse = 0
        
        # 불타는 스타디움 라인 애니메이션
        self.fire_line_particles = []  # 불꽃 파티클들
        self.fire_glow_phase = 0  # 불꽃 빛나는 애니메이션 위상
        self.center_circle_radius = 80  # 중앙 원 반지름
        self.stadium_line_y = 375  # 스타디움 가로 라인 y 위치 (중앙)
        self.fire_colors = [
            (255, 100, 50),   # 밝은 주황
            (255, 80, 30),    # 진한 주황
            (200, 60, 20),    # 붉은 주황
            (150, 40, 10),    # 어두운 빨강
        ]
    
    def update(self, dt):
        self.time += dt
        self.bagua_rotation += dt * 0.00005  # 매우 천천히 회전
        self.digital_flower_pulse = math.sin(self.time * 0.002) * 0.5 + 0.5
        self.fire_glow_phase += 0.05  # 불꽃 맥동 애니메이션
        
        # 불타는 라인 파티클 업데이트
        self._update_fire_lines()
        
        # 매화 꽃잎 떨어지기
        for petal in self.falling_petals:
            petal['y'] += petal['speed']
            petal['sway'] += 0.02
            petal['x'] += math.sin(petal['sway']) * 1.5
            petal['rotation'] += 0.03
            
            # 바닥에 닿으면 다시 위로
            if petal['y'] > self.height:
                petal['y'] = random.randint(-100, -20)
                petal['x'] = random.randint(50, 150)
        
        # 화염 입자 업데이트
        for particle in self.flame_particles:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['vy'] += 0.02  # 중력 효과
            particle['life'] -= 0.5
            
            # 수명이 다하면 재생성
            if particle['life'] <= 0:
                if particle['side'] == 'left':
                    particle['x'] = random.randint(10, 40)
                else:
                    particle['x'] = random.randint(self.width - 40, self.width - 10)
                particle['y'] = random.randint(200, self.height - 200)
                particle['vx'] = random.uniform(-0.5, 0.5)
                particle['vy'] = random.uniform(-1.5, -0.5)
                particle['life'] = random.randint(30, 60)
    
    def draw(self, screen):
        screen.blit(self.base_image, (0, 0))

        self.glow_surface.fill(self._transparent)
        
        # 팔괘 회전 효과 (아주 희미하게)
        bagua_radius = 50
        for i in range(8):
            angle = i * 45 + math.degrees(self.bagua_rotation)
            rad = math.radians(angle)
            x1 = self.center_x + math.cos(rad) * (bagua_radius - 10)
            y1 = self.center_y + math.sin(rad) * (bagua_radius - 10)
            x2 = self.center_x + math.cos(rad) * bagua_radius
            y2 = self.center_y + math.sin(rad) * bagua_radius
            
            alpha = int(20 + math.sin(self.time * 0.003 + i) * 10)
            pygame.draw.line(self.glow_surface,
                           (255, 120, 60, max(alpha, 0)),
                           (int(x1), int(y1)), (int(x2), int(y2)), 2)
        
        # 중앙 펄스 효과 (매우 희미)
        if self.digital_flower_pulse > 0.8:
            alpha = int((self.digital_flower_pulse - 0.8) * 150)
            pygame.draw.circle(self.glow_surface,
                             (255, 100, 50, min(alpha, 40)),
                             (self.center_x, self.center_y),
                             55, width=2)
        
        screen.blit(self.glow_surface, (0, 0), special_flags=pygame.BLEND_ADD)
        
        # 떨어지는 매화 꽃잎
        self.particle_surface.fill(self._transparent)
        for petal in self.falling_petals:
            # 5개 꽃잎 그리기
            for i in range(5):
                angle = i * 72 + math.degrees(petal['rotation'])
                rad = math.radians(angle)
                x = petal['x'] + math.cos(rad) * petal['size']
                y = petal['y'] + math.sin(rad) * petal['size']
                
                petal_alpha = 120
                color = petal['color'] + (petal_alpha,)
                pygame.draw.ellipse(self.particle_surface,
                                  color,
                                  (int(x - 4), int(y - 2), 8, 4))
        
        # 화염 입자
        for particle in self.flame_particles:
            life_ratio = particle['life'] / particle['max_life']
            alpha = int(100 * life_ratio)
            size = int(particle['size'] * life_ratio)
            
            # 화염 색상 (수명에 따라 변화)
            if life_ratio > 0.7:
                color = (255, 255, 200, alpha)  # 흰색/노랑
            elif life_ratio > 0.4:
                color = (255, 150, 50, alpha)   # 주황
            else:
                color = (255, 50, 50, alpha)    # 빨강
            
            if size > 0:
                pygame.draw.circle(self.particle_surface,
                                 color,
                                 (int(particle['x']), int(particle['y'])),
                                 size)
        
        screen.blit(self.particle_surface, (0, 0), special_flags=pygame.BLEND_ADD)
        
        # 불타는 스타디움 라인 그리기
        self._draw_fire_lines(screen)
        
        # 가끔씩 화염 플래시
        if random.random() > 0.98:
            flash_side = random.choice(['left', 'right'])
            flash_y = random.randint(200, self.height - 200)
            flash_alpha = 100
            
            if flash_side == 'left':
                flash_x = 30
            else:
                flash_x = self.width - 30
            
            pygame.draw.circle(screen, (255, 100, 50, flash_alpha),
                             (flash_x, flash_y), 20)
    
    def _update_fire_lines(self):
        """불타는 라인 애니메이션 업데이트"""
        # 새로운 불꽃 파티클 생성 (원형 라인과 가로 라인에서)
        if random.random() < 0.3:  # 30% 확률로 생성
            # 중앙 원형 라인에서 불꽃 생성
            angle = random.uniform(0, math.pi * 2)
            x = self.width // 2 + math.cos(angle) * self.center_circle_radius
            y = self.stadium_line_y + math.sin(angle) * self.center_circle_radius
            self._create_fire_particle(x, y)
            
            # 가로 스타디움 라인에서 불꽃 생성
            x = random.randint(50, self.width - 50)
            self._create_fire_particle(x, self.stadium_line_y)
        
        # 파티클 업데이트
        for particle in self.fire_line_particles[:]:
            particle['y'] -= particle['vy']  # 위로 올라감
            particle['x'] += particle['vx']  # 약간 좌우로 흔들림
            particle['life'] -= 1
            particle['size'] *= 0.95  # 점점 작아짐
            
            if particle['life'] <= 0 or particle['size'] < 0.5:
                self.fire_line_particles.remove(particle)
    
    def _create_fire_particle(self, x, y):
        """불꽃 파티클 생성"""
        if len(self.fire_line_particles) < 80:  # 최대 파티클 수 제한
            particle = {
                'x': x,
                'y': y,
                'vx': random.uniform(-0.5, 0.5),  # 좌우 속도
                'vy': random.uniform(0.5, 2.0),   # 위로 올라가는 속도
                'size': random.uniform(2, 4),
                'life': random.randint(20, 40),
                'color': random.choice(self.fire_colors),
                'glow': random.uniform(0.6, 1.0),
            }
            self.fire_line_particles.append(particle)
    
    def _draw_fire_lines(self, surface):
        """불타는 스타디움 라인 그리기"""
        # 불꽃 빛나기 효과 계산
        glow_intensity = (math.sin(self.fire_glow_phase) + 1) * 0.3 + 0.4  # 0.4 ~ 1.0
        
        # 중앙 원형 라인 (은은한 불꽃 효과)
        center_x = self.width // 2
        center_y = self.stadium_line_y
        
        # 여러 겹의 글로우 효과로 불타는 느낌 (더 은은하게)
        for i in range(2):  # 2겹으로 줄임
            alpha = int(20 * glow_intensity * (1 - i * 0.4))  # 더 낮은 알파값
            radius = self.center_circle_radius + i * 3
            color = (200 + int(55 * glow_intensity), 
                    60 + int(40 * glow_intensity), 
                    20)
            
            # 글로우 서피스에 그리기
            glow_surface = pygame.Surface((radius * 2 + 20, radius * 2 + 20), pygame.SRCALPHA)
            pygame.draw.circle(glow_surface, (*color, alpha), 
                             (radius + 10, radius + 10), radius, 1 + i)
            surface.blit(glow_surface, (center_x - radius - 10, center_y - radius - 10))
        
        # 메인 원형 라인 (얇고 밝은 불꽃색)
        main_color = (255, int(120 + 30 * glow_intensity), 60)
        pygame.draw.circle(surface, main_color, (center_x, center_y), 
                          self.center_circle_radius, 1)
        
        # 가로 스타디움 라인 (은은한 불꽃 효과)
        line_start_x = 50
        line_end_x = self.width - 50
        
        # 여러 겹의 글로우 효과 (더 은은하게)
        for i in range(2):  # 2겹으로 줄임
            alpha = int(18 * glow_intensity * (1 - i * 0.4))  # 더 낮은 알파값
            thickness = 1 + i
            color = (200 + int(55 * glow_intensity),
                    60 + int(40 * glow_intensity),
                    20)
            
            # 글로우 라인
            glow_surface = pygame.Surface((self.width, 10), pygame.SRCALPHA)
            pygame.draw.line(glow_surface, (*color, alpha),
                           (line_start_x, 5),
                           (line_end_x, 5), thickness)
            surface.blit(glow_surface, (0, self.stadium_line_y - 5))
        
        # 메인 가로 라인 (얇고 밝은 불꽃색)
        pygame.draw.line(surface, main_color,
                        (line_start_x, self.stadium_line_y),
                        (line_end_x, self.stadium_line_y), 1)
        
        # 불꽃 파티클 그리기
        for particle in self.fire_line_particles:
            # 파티클 글로우 효과
            glow_alpha = int(particle['glow'] * particle['life'] * 1.5)
            if glow_alpha > 0:
                glow_size = particle['size'] * 1.5
                glow_surface = pygame.Surface((int(glow_size * 2), int(glow_size * 2)), pygame.SRCALPHA)
                pygame.draw.circle(glow_surface, (*particle['color'], min(glow_alpha, 80)),
                                 (int(glow_size), int(glow_size)), int(glow_size))
                surface.blit(glow_surface, (particle['x'] - glow_size, particle['y'] - glow_size))
            
            # 파티클 본체
            pygame.draw.circle(surface, particle['color'],
                             (int(particle['x']), int(particle['y'])),
                             int(particle['size']))