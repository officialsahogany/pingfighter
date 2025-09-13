"""무릎보호대 - 하프대쉬로 공을 맞출 때 게이지 50% 충전"""

import pygame
import math
import random

class KneePads:
    def __init__(self):
        self.active = False
        self.obtained = False
        self.flash_timer = 0  # 빛나는 이펙트 타이머
        self.flash_pos = None  # 이펙트 위치
        self.particles = []  # 파티클 시스템
        self.shockwave_radius = 0  # 충격파 반경
        self.energy_lines = []  # 에너지 라인들
        self.charge_rings = []  # 충전 링 효과
        
    def activate(self):
        """무릎보호대 획득 시 활성화"""
        self.active = True
        self.obtained = True
        print("무릎보호대 활성화 - 하프대쉬 공 타격 시 게이지 50% 충전")
    
    def deactivate(self):
        """무릎보호대 비활성화 (게임오버 시)"""
        self.active = False
        self.obtained = False
        self.flash_timer = 0
        self.flash_pos = None
        print("무릎보호대 비활성화")
    
    def on_half_dash_hit(self, ball_pos):
        """하프대쉬로 공을 맞췄을 때 호출"""
        print(f"[DEBUG] on_half_dash_hit 호출됨, active={self.active}, ball_pos={ball_pos}")
        if self.active:
            # 빛나는 이펙트 시작
            self.flash_timer = 30  # 30프레임 동안 이펙트 (0.5초)
            self.flash_pos = ball_pos
            self.shockwave_radius = 0  # 충격파 시작
            print(f"[DEBUG] 이펙트 설정 완료: flash_timer={self.flash_timer}, flash_pos={self.flash_pos}")
            
            # 파티클 생성 (충전 에너지 파티클)
            for _ in range(20):
                angle = random.uniform(0, 2 * math.pi)
                speed = random.uniform(3, 8)
                particle = {
                    'x': ball_pos[0],
                    'y': ball_pos[1],
                    'vx': math.cos(angle) * speed,
                    'vy': math.sin(angle) * speed,
                    'life': 30,
                    'color': random.choice([(255, 255, 0), (255, 220, 0), (255, 200, 100)]),
                    'size': random.uniform(2, 5)
                }
                self.particles.append(particle)
            
            # 에너지 라인 생성 (충전 효과)
            for i in range(8):
                angle = (i / 8) * 2 * math.pi
                self.energy_lines.append({
                    'angle': angle,
                    'length': 0,
                    'max_length': random.uniform(40, 60),
                    'life': 20
                })
            
            # 충전 링 생성
            for i in range(3):
                self.charge_rings.append({
                    'radius': 10 + i * 5,
                    'max_radius': 80 + i * 20,
                    'alpha': 255,
                    'color': (255, 255 - i * 30, 0)
                })
            
            return True  # 게이지 충전 신호
        return False
    
    def update(self):
        """매 프레임 업데이트"""
        if self.flash_timer > 0:
            self.flash_timer -= 1
            
            # 충격파 확장
            if self.shockwave_radius < 100:
                self.shockwave_radius += 8
            
            # 에너지 라인 확장
            for line in self.energy_lines:
                if line['length'] < line['max_length']:
                    line['length'] += 4
                line['life'] -= 1
            self.energy_lines = [l for l in self.energy_lines if l['life'] > 0]
            
            # 충전 링 확장
            for ring in self.charge_rings:
                if ring['radius'] < ring['max_radius']:
                    ring['radius'] += 5
                ring['alpha'] = max(0, ring['alpha'] - 8)
            self.charge_rings = [r for r in self.charge_rings if r['alpha'] > 0]
        
        # 파티클 업데이트
        for particle in self.particles:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['vy'] += 0.3  # 중력 효과
            particle['life'] -= 1
            particle['size'] = max(1, particle['size'] - 0.1)
        
        # 죽은 파티클 제거
        self.particles = [p for p in self.particles if p['life'] > 0]
    
    def draw_effect(self, screen):
        """화려한 충전 이펙트 그리기"""
        if self.flash_timer > 0 and self.flash_pos:
            # 1. 충격파 효과 (가장 뒤에 그리기)
            if self.shockwave_radius > 0 and self.shockwave_radius < 100:
                shockwave_alpha = int(255 * (1 - self.shockwave_radius / 100))
                for i in range(3):
                    radius = self.shockwave_radius - i * 5
                    if radius > 0:
                        pygame.draw.circle(screen, (255, 255, 0, shockwave_alpha // (i + 1)), 
                                         (int(self.flash_pos[0]), int(self.flash_pos[1])), 
                                         int(radius), 2)
            
            # 2. 충전 링 효과
            for ring in self.charge_rings:
                if ring['alpha'] > 0:
                    ring_surface = pygame.Surface((ring['radius'] * 2 + 10, ring['radius'] * 2 + 10), pygame.SRCALPHA)
                    color = (*ring['color'], ring['alpha'])
                    pygame.draw.circle(ring_surface, color, 
                                     (ring['radius'] + 5, ring['radius'] + 5), 
                                     int(ring['radius']), 3)
                    screen.blit(ring_surface, 
                              (self.flash_pos[0] - ring['radius'] - 5, 
                               self.flash_pos[1] - ring['radius'] - 5))
            
            # 3. 에너지 라인 효과 (번개처럼)
            for line in self.energy_lines:
                if line['life'] > 0:
                    end_x = self.flash_pos[0] + math.cos(line['angle']) * line['length']
                    end_y = self.flash_pos[1] + math.sin(line['angle']) * line['length']
                    
                    # 메인 라인
                    pygame.draw.line(screen, (255, 255, 100), 
                                   (self.flash_pos[0], self.flash_pos[1]),
                                   (end_x, end_y), 3)
                    
                    # 글로우 효과
                    pygame.draw.line(screen, (255, 200, 0, 128), 
                                   (self.flash_pos[0], self.flash_pos[1]),
                                   (end_x, end_y), 5)
            
            # 4. 중심 플래시 효과
            flash_alpha = int(255 * (self.flash_timer / 30))
            flash_surface = pygame.Surface((200, 200), pygame.SRCALPHA)
            
            # 다층 글로우
            for i in range(5):
                radius = 30 - i * 5
                alpha = flash_alpha // (i + 1)
                color = (255, 255 - i * 20, 0, alpha)
                pygame.draw.circle(flash_surface, color, (100, 100), radius)
            
            # 밝은 중심점
            pygame.draw.circle(flash_surface, (255, 255, 255, flash_alpha), (100, 100), 5)
            
            screen.blit(flash_surface, 
                       (self.flash_pos[0] - 100, self.flash_pos[1] - 100))
            
            # 5. 회전하는 별 효과
            if self.flash_timer > 15:
                rotation = (30 - self.flash_timer) * 10
                for i in range(8):
                    angle = math.radians(i * 45 + rotation)
                    distance = 40 + math.sin(self.flash_timer * 0.3) * 10
                    x = self.flash_pos[0] + math.cos(angle) * distance
                    y = self.flash_pos[1] + math.sin(angle) * distance
                    
                    # 별 모양 그리기
                    star_points = []
                    for j in range(10):
                        r = 8 if j % 2 == 0 else 4
                        star_angle = angle + math.radians(j * 36)
                        sx = x + math.cos(star_angle) * r
                        sy = y + math.sin(star_angle) * r
                        star_points.append((sx, sy))
                    
                    if len(star_points) > 2:
                        pygame.draw.polygon(screen, (255, 255, 100, flash_alpha), star_points)
        
        # 6. 파티클 효과
        for particle in self.particles:
            if particle['life'] > 0:
                alpha = int(255 * (particle['life'] / 30))
                particle_surface = pygame.Surface((int(particle['size'] * 2 + 4), 
                                                  int(particle['size'] * 2 + 4)), 
                                                 pygame.SRCALPHA)
                
                # 파티클 글로우
                color_with_alpha = (*particle['color'], alpha)
                pygame.draw.circle(particle_surface, color_with_alpha,
                                 (int(particle['size'] + 2), int(particle['size'] + 2)),
                                 int(particle['size']))
                
                # 밝은 중심
                if particle['size'] > 2:
                    pygame.draw.circle(particle_surface, (255, 255, 255, alpha // 2),
                                     (int(particle['size'] + 2), int(particle['size'] + 2)),
                                     int(particle['size'] / 2))
                
                screen.blit(particle_surface,
                          (int(particle['x'] - particle['size'] - 2),
                           int(particle['y'] - particle['size'] - 2)))

# 싱글톤 인스턴스
knee_pads_instance = None

def get_knee_pads_instance():
    global knee_pads_instance
    if knee_pads_instance is None:
        knee_pads_instance = KneePads()
    return knee_pads_instance