import pygame
import math
import random

class HammerExplosion:
    def __init__(self, x, y):
        self.x = x
        self.y = y
        self.particles = []
        self.energy_shards = []
        self.shockwave_radius = 0
        self.shockwave_alpha = 255
        self.explosion_timer = 0
        self.max_duration = 60  # 1초 (60프레임)
        self.active = True
        
        # 메인 폭발 파티클 생성
        self.create_explosion_particles()
        # 에너지 파편 생성
        self.create_energy_shards()
        
    def create_explosion_particles(self):
        """메인 폭발 파티클들 생성"""
        particle_count = random.randint(40, 60)
        
        for _ in range(particle_count):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(3, 12)
            size = random.randint(4, 12)
            
            particle = {
                'x': self.x,
                'y': self.y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'size': size,
                'initial_size': size,
                'life': random.randint(30, 50),
                'max_life': random.randint(30, 50),
                'color': random.choice([
                    (255, 220, 0),    # 금색
                    (255, 150, 0),    # 주황색
                    (255, 255, 100),  # 밝은 노랑
                    (255, 80, 0),     # 적주황
                    (200, 200, 255)   # 연한 파랑 (에너지)
                ])
            }
            self.particles.append(particle)
            
    def create_energy_shards(self):
        """에너지 파편들 생성"""
        shard_count = random.randint(8, 16)
        
        for _ in range(shard_count):
            angle = random.uniform(0, 2 * math.pi)
            speed = random.uniform(2, 8)
            
            shard = {
                'x': self.x,
                'y': self.y,
                'vx': math.cos(angle) * speed,
                'vy': math.sin(angle) * speed,
                'size': random.randint(6, 14),
                'angle': angle,
                'rotation_speed': random.uniform(-0.3, 0.3),
                'life': random.randint(40, 70),
                'max_life': random.randint(40, 70),
                'trail_points': [],
                'energy_type': random.choice(['electric', 'plasma', 'divine'])
            }
            self.energy_shards.append(shard)
    
    def update(self):
        """폭발 이펙트 업데이트"""
        if not self.active:
            return
            
        self.explosion_timer += 1
        
        # 충격파 확장
        if self.explosion_timer < 20:
            self.shockwave_radius += 8
            self.shockwave_alpha = max(0, 255 - (self.explosion_timer * 12))
        
        # 파티클 업데이트
        for particle in self.particles[:]:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            particle['vx'] *= 0.98  # 공기 저항
            particle['vy'] *= 0.98
            particle['life'] -= 1
            
            # 크기 감소
            life_ratio = particle['life'] / particle['max_life']
            particle['size'] = particle['initial_size'] * life_ratio
            
            if particle['life'] <= 0 or particle['size'] <= 0:
                self.particles.remove(particle)
        
        # 에너지 파편 업데이트
        for shard in self.energy_shards[:]:
            shard['x'] += shard['vx']
            shard['y'] += shard['vy']
            shard['vx'] *= 0.95
            shard['vy'] *= 0.95
            shard['angle'] += shard['rotation_speed']
            shard['life'] -= 1
            
            # 트레일 포인트 추가
            shard['trail_points'].append((shard['x'], shard['y']))
            if len(shard['trail_points']) > 8:
                shard['trail_points'].pop(0)
            
            if shard['life'] <= 0:
                self.energy_shards.remove(shard)
        
        # 폭발 종료 체크
        if (self.explosion_timer >= self.max_duration and 
            len(self.particles) == 0 and 
            len(self.energy_shards) == 0):
            self.active = False
    
    def draw(self, screen):
        """폭발 이펙트 그리기"""
        if not self.active:
            return
        
        # 충격파 그리기
        if self.shockwave_radius > 0 and self.shockwave_alpha > 0:
            shockwave_surface = pygame.Surface((self.shockwave_radius * 2, self.shockwave_radius * 2), pygame.SRCALPHA)
            
            # 다중 링 충격파
            for i in range(3):
                ring_radius = self.shockwave_radius - (i * 15)
                if ring_radius > 0:
                    alpha = self.shockwave_alpha // (i + 1)
                    color = (255, 200, 100, alpha)
                    pygame.draw.circle(shockwave_surface, color, 
                                     (self.shockwave_radius, self.shockwave_radius), 
                                     ring_radius, 3)
            
            screen.blit(shockwave_surface, 
                       (self.x - self.shockwave_radius, self.y - self.shockwave_radius))
        
        # 에너지 파편의 트레일 그리기
        for shard in self.energy_shards:
            if len(shard['trail_points']) > 1:
                life_ratio = shard['life'] / shard['max_life']
                trail_alpha = int(100 * life_ratio)
                
                for i in range(len(shard['trail_points']) - 1):
                    point_alpha = trail_alpha * (i + 1) // len(shard['trail_points'])
                    if point_alpha > 0:
                        trail_color = self.get_energy_color(shard['energy_type'], point_alpha)
                        if i < len(shard['trail_points']) - 1:
                            try:
                                pygame.draw.line(screen, trail_color[:3], 
                                               shard['trail_points'][i], 
                                               shard['trail_points'][i + 1], 2)
                            except:
                                pass
        
        # 메인 폭발 파티클 그리기
        for particle in self.particles:
            life_ratio = particle['life'] / particle['max_life']
            alpha = int(255 * life_ratio)
            
            if alpha > 0:
                particle_surface = pygame.Surface((particle['size'] * 2, particle['size'] * 2), pygame.SRCALPHA)
                color_with_alpha = (*particle['color'], alpha)
                
                # 글로우 효과
                glow_size = particle['size'] + 4
                glow_alpha = alpha // 3
                glow_color = (*particle['color'], glow_alpha)
                pygame.draw.circle(particle_surface, glow_color, 
                                 (particle['size'], particle['size']), glow_size)
                
                # 메인 파티클
                pygame.draw.circle(particle_surface, color_with_alpha, 
                                 (particle['size'], particle['size']), int(particle['size']))
                
                screen.blit(particle_surface, 
                           (particle['x'] - particle['size'], particle['y'] - particle['size']))
        
        # 에너지 파편 그리기
        for shard in self.energy_shards:
            life_ratio = shard['life'] / shard['max_life']
            alpha = int(255 * life_ratio)
            
            if alpha > 0:
                shard_color = self.get_energy_color(shard['energy_type'], alpha)
                
                # 회전된 다이아몬드 모양 그리기
                points = self.get_rotated_diamond_points(
                    shard['x'], shard['y'], shard['size'], shard['angle']
                )
                
                if len(points) >= 3:
                    # 글로우 효과
                    glow_points = self.get_rotated_diamond_points(
                        shard['x'], shard['y'], shard['size'] + 3, shard['angle']
                    )
                    if len(glow_points) >= 3:
                        glow_surface = pygame.Surface((shard['size'] * 4, shard['size'] * 4), pygame.SRCALPHA)
                        adjusted_glow_points = [(p[0] - shard['x'] + shard['size'] * 2, 
                                               p[1] - shard['y'] + shard['size'] * 2) for p in glow_points]
                        pygame.draw.polygon(glow_surface, (*shard_color[:3], alpha // 4), adjusted_glow_points)
                        screen.blit(glow_surface, (shard['x'] - shard['size'] * 2, shard['y'] - shard['size'] * 2))
                    
                    # 메인 파편
                    pygame.draw.polygon(screen, shard_color[:3], points)
    
    def get_energy_color(self, energy_type, alpha):
        """에너지 타입에 따른 색상 반환"""
        colors = {
            'electric': (100, 200, 255, alpha),  # 전기 파랑
            'plasma': (255, 100, 255, alpha),    # 플라즈마 보라
            'divine': (255, 255, 150, alpha)     # 신성한 금색
        }
        return colors.get(energy_type, (255, 255, 255, alpha))
    
    def get_rotated_diamond_points(self, x, y, size, angle):
        """회전된 다이아몬드 포인트들 반환"""
        cos_a = math.cos(angle)
        sin_a = math.sin(angle)
        
        # 다이아몬드 기본 포인트들
        base_points = [
            (0, -size),     # 상단
            (size, 0),      # 우측
            (0, size),      # 하단
            (-size, 0)      # 좌측
        ]
        
        rotated_points = []
        for px, py in base_points:
            # 회전 변환
            rx = px * cos_a - py * sin_a
            ry = px * sin_a + py * cos_a
            rotated_points.append((x + rx, y + ry))
        
        return rotated_points

# 전역 폭발 이펙트 관리자
class HammerExplosionManager:
    def __init__(self):
        self.explosions = []
    
    def add_explosion(self, x, y):
        """새로운 폭발 이펙트 추가"""
        explosion = HammerExplosion(x, y)
        self.explosions.append(explosion)
    
    def update(self):
        """모든 폭발 이펙트 업데이트"""
        for explosion in self.explosions[:]:
            explosion.update()
            if not explosion.active:
                self.explosions.remove(explosion)
    
    def draw(self, screen):
        """모든 폭발 이펙트 그리기"""
        for explosion in self.explosions:
            explosion.draw(screen)
    
    def clear(self):
        """모든 폭발 이펙트 제거"""
        self.explosions.clear()

# 전역 인스턴스
hammer_explosion_manager = HammerExplosionManager()

def get_hammer_explosion_manager():
    """폭발 이펙트 매니저 인스턴스 반환"""
    global hammer_explosion_manager
    return hammer_explosion_manager