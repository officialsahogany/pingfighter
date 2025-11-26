"""
파티클 시스템 유틸리티 함수 모음
점진적 리팩토링을 위한 파티클 생성 및 관리 코드 분리
"""
import random
import math
import pygame
from .color_utils import get_neon_color, blend_colors, NEON_PALETTE, CYBERPUNK_PALETTE

# === 파티클 기본 클래스 ===
class Particle:
    """파티클 기본 클래스"""
    def __init__(self, x, y, vx, vy, life, color, particle_type="basic"):
        self.x = x
        self.y = y
        self.vx = vx
        self.vy = vy
        self.life = life
        self.max_life = life
        self.color = color
        self.type = particle_type
        self.size = 3
        self.alpha = 255
        
    def update(self):
        """파티클 상태 업데이트"""
        self.x += self.vx
        self.y += self.vy
        self.life -= 1
        
        # 수명에 따른 알파값 감소
        if self.max_life > 0:
            self.alpha = int(255 * (self.life / self.max_life))
        
        return self.life > 0
    
    def draw(self, surface):
        """파티클 그리기"""
        if self.alpha > 0:
            # 알파 블렌딩을 위한 임시 서페이스
            temp_surface = pygame.Surface((self.size * 2, self.size * 2), pygame.SRCALPHA)
            color_with_alpha = (*self.color[:3], self.alpha)
            pygame.draw.circle(temp_surface, color_with_alpha, (self.size, self.size), self.size)
            surface.blit(temp_surface, (self.x - self.size, self.y - self.size))

# === 파티클 생성 함수들 ===
def create_energy_particle(x, y, particle_list, speed_range=(0.5, 2), life=25):
    """에너지 파티클 생성
    
    Args:
        x, y: 생성 위치
        particle_list: 파티클을 추가할 리스트
        speed_range: 속도 범위 (min, max)
        life: 파티클 수명 (프레임)
    """
    angle = random.uniform(0, 2 * math.pi)
    speed = random.uniform(*speed_range)
    
    particle_data = {
        'x': x + random.randint(-5, 5),
        'y': y + random.randint(-5, 5),
        'vx': math.cos(angle) * speed,
        'vy': math.sin(angle) * speed,
        'life': life,
        'max_life': life,
        'color': random.choice([(100, 150, 255), (150, 200, 255), (200, 220, 255)]),
        'type': 'energy',
        'size': random.randint(2, 4),
        'alpha': 255
    }
    particle_list.append(particle_data)
    return particle_data

def create_spark_particle(x, y, particle_list, speed_range=(2, 4), life=15):
    """전기 스파크 파티클 생성
    
    Args:
        x, y: 생성 위치
        particle_list: 파티클을 추가할 리스트
        speed_range: 속도 범위 (min, max)
        life: 파티클 수명 (프레임)
    """
    angle = random.uniform(0, 2 * math.pi)
    speed = random.uniform(*speed_range)
    
    particle_data = {
        'x': x + random.randint(-3, 3),
        'y': y + random.randint(-3, 3),
        'vx': math.cos(angle) * speed,
        'vy': math.sin(angle) * speed,
        'life': life,
        'max_life': life,
        'color': (255, 255, 100),
        'type': 'spark',
        'size': random.randint(1, 3),
        'alpha': 255
    }
    particle_list.append(particle_data)
    return particle_data

def create_neon_particle(x, y, particle_list, color=None, speed_range=(1, 3)):
    """네온 파티클 생성
    
    Args:
        x, y: 생성 위치
        particle_list: 파티클을 추가할 리스트
        color: 파티클 색상 (None이면 랜덤)
        speed_range: 속도 범위 (min, max)
    """
    angle = random.uniform(0, 2 * math.pi)
    speed = random.uniform(*speed_range)
    
    if color is None:
        color = random.choice([(255, 100, 200), (100, 255, 200), (200, 100, 255)])
    
    particle_data = {
        'x': x,
        'y': y,
        'vx': math.cos(angle) * speed,
        'vy': math.sin(angle) * speed,
        'life': 30,
        'max_life': 30,
        'alpha': 255,
        'color': color,
        'type': 'neon',
        'size': random.randint(2, 5)
    }
    particle_list.append(particle_data)
    return particle_data

def create_shadow_particle(x, y, particle_list, life=10):
    """그림자 파티클 생성
    
    Args:
        x, y: 생성 위치
        particle_list: 파티클을 추가할 리스트
        life: 파티클 수명 (프레임)
    """
    particle_data = {
        'x': x,
        'y': y,
        'vx': random.uniform(-0.5, 0.5),
        'vy': random.uniform(-0.5, -1),  # 위로 올라감
        'life': life,
        'max_life': life,
        'color': (50, 50, 50),
        'alpha': 150,
        'type': 'shadow',
        'size': random.randint(3, 6)
    }
    particle_list.append(particle_data)
    return particle_data

def create_explosion_particles(x, y, particle_list, count=20, color=None, speed_range=(2, 8)):
    """폭발 파티클 생성
    
    Args:
        x, y: 폭발 중심 위치
        particle_list: 파티클을 추가할 리스트
        count: 생성할 파티클 수
        color: 파티클 색상 (None이면 랜덤)
        speed_range: 속도 범위
    """
    for _ in range(count):
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(*speed_range)
        
        if color is None:
            particle_color = random.choice([(255, 100, 0), (255, 200, 0), (255, 150, 50)])
        else:
            particle_color = color
        
        particle_data = {
            'x': x,
            'y': y,
            'vx': math.cos(angle) * speed,
            'vy': math.sin(angle) * speed,
            'life': random.randint(20, 40),
            'max_life': 40,
            'color': particle_color,
            'type': 'explosion',
            'size': random.randint(3, 6),
            'alpha': 255
        }
        particle_list.append(particle_data)

def create_trail_particle(x, y, particle_list, color, velocity=(0, 0), life=15):
    """트레일(잔상) 파티클 생성
    
    Args:
        x, y: 생성 위치
        particle_list: 파티클을 추가할 리스트
        color: 파티클 색상
        velocity: 속도 벡터 (vx, vy)
        life: 파티클 수명
    """
    particle_data = {
        'x': x + random.randint(-2, 2),
        'y': y + random.randint(-2, 2),
        'vx': velocity[0] * 0.2 + random.uniform(-0.5, 0.5),
        'vy': velocity[1] * 0.2 + random.uniform(-0.5, 0.5),
        'life': life,
        'max_life': life,
        'color': color,
        'type': 'trail',
        'size': random.randint(1, 3),
        'alpha': 150
    }
    particle_list.append(particle_data)
    return particle_data

def create_healing_particle(x, y, particle_list):
    """치유 파티클 생성
    
    Args:
        x, y: 생성 위치
        particle_list: 파티클을 추가할 리스트
    """
    angle = random.uniform(0, 2 * math.pi)
    speed = random.uniform(0.5, 1.5)
    
    particle_data = {
        'x': x,
        'y': y,
        'vx': math.cos(angle) * speed,
        'vy': math.sin(angle) * speed - 0.5,  # 약간 위로 올라가는 효과
        'life': 40,
        'max_life': 40,
        'color': random.choice([(100, 255, 100), (150, 255, 150), (200, 255, 200)]),
        'type': 'healing',
        'size': random.randint(2, 4),
        'alpha': 255,
        'pulse': 0  # 펄스 효과용
    }
    particle_list.append(particle_data)
    return particle_data

def create_ice_particle(x, y, particle_list):
    """얼음 파티클 생성
    
    Args:
        x, y: 생성 위치
        particle_list: 파티클을 추가할 리스트
    """
    angle = random.uniform(0, 2 * math.pi)
    speed = random.uniform(1, 3)
    
    particle_data = {
        'x': x,
        'y': y,
        'vx': math.cos(angle) * speed,
        'vy': math.sin(angle) * speed + 0.5,  # 약간 아래로 떨어지는 효과
        'life': 30,
        'max_life': 30,
        'color': random.choice([(150, 200, 255), (180, 220, 255), (200, 235, 255)]),
        'type': 'ice',
        'size': random.randint(2, 5),
        'alpha': 200,
        'rotation': random.uniform(0, 2 * math.pi)
    }
    particle_list.append(particle_data)
    return particle_data

def create_fire_particle(x, y, particle_list):
    """화염 파티클 생성
    
    Args:
        x, y: 생성 위치
        particle_list: 파티클을 추가할 리스트
    """
    particle_data = {
        'x': x + random.randint(-5, 5),
        'y': y,
        'vx': random.uniform(-1, 1),
        'vy': random.uniform(-3, -1),  # 위로 올라감
        'life': random.randint(20, 35),
        'max_life': 35,
        'color': random.choice([(255, 100, 0), (255, 150, 0), (255, 200, 0), (255, 255, 100)]),
        'type': 'fire',
        'size': random.randint(3, 6),
        'alpha': 255
    }
    particle_list.append(particle_data)
    return particle_data

# === 파티클 업데이트 및 렌더링 ===
def update_particles(particle_list, gravity=0, friction=1.0):
    """파티클 리스트 업데이트
    
    Args:
        particle_list: 파티클 리스트
        gravity: 중력 가속도 (0이면 없음)
        friction: 마찰 계수 (1.0이면 마찰 없음)
    
    Returns:
        업데이트된 파티클 리스트
    """
    updated_particles = []
    
    for particle in particle_list:
        # 위치 업데이트
        particle['x'] += particle['vx']
        particle['y'] += particle['vy']
        
        # 중력 적용
        if gravity != 0:
            particle['vy'] += gravity
        
        # 마찰 적용
        if friction != 1.0:
            particle['vx'] *= friction
            particle['vy'] *= friction
        
        # 수명 감소
        particle['life'] -= 1
        
        # 알파값 업데이트
        if 'max_life' in particle and particle['max_life'] > 0:
            particle['alpha'] = int(255 * (particle['life'] / particle['max_life']))
        
        # 특수 효과 업데이트
        if particle.get('type') == 'healing' and 'pulse' in particle:
            particle['pulse'] = (particle['pulse'] + 0.2) % (2 * math.pi)
            particle['size'] = 3 + int(math.sin(particle['pulse']) * 2)
        elif particle.get('type') == 'ice' and 'rotation' in particle:
            particle['rotation'] += 0.1
        elif particle.get('type') == 'light_shard':
            # 빛의 파편 회전 및 중력
            if 'rotation' in particle and 'rotation_speed' in particle:
                particle['rotation'] += particle['rotation_speed']
            if 'gravity' in particle:
                particle['vy'] += particle['gravity']
            if 'brightness' in particle:
                particle['brightness'] *= 0.97  # 밝기 서서히 감소
        elif particle.get('type') == 'light_glow' and 'pulse' in particle:
            # 글로우 펄스 효과
            particle['pulse'] = (particle['pulse'] + 0.3) % (2 * math.pi)
            pulse_factor = 0.5 + 0.5 * math.sin(particle['pulse'])
            particle['size'] = int(particle.get('size', 4) * (0.8 + 0.4 * pulse_factor))
        
        # 살아있는 파티클만 유지
        if particle['life'] > 0:
            updated_particles.append(particle)
    
    return updated_particles

def draw_particles(surface, particle_list):
    """파티클 리스트 그리기
    
    Args:
        surface: pygame.Surface 객체
        particle_list: 파티클 리스트
    """
    for particle in particle_list:
        x = int(particle['x'])
        y = int(particle['y'])
        size = particle.get('size', 3)
        alpha = particle.get('alpha', 255)
        color = particle['color']
        
        if alpha <= 0:
            continue
        
        # 파티클 타입별 렌더링
        particle_type = particle.get('type', 'basic')
        
        if particle_type in ['energy', 'neon', 'healing']:
            # 글로우 효과
            for i in range(2, 0, -1):
                glow_alpha = alpha // (i * 2)
                glow_size = size + i * 2
                temp_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                glow_color = (*color[:3], glow_alpha)
                pygame.draw.circle(temp_surface, glow_color, (glow_size, glow_size), glow_size)
                surface.blit(temp_surface, (x - glow_size, y - glow_size), special_flags=pygame.BLEND_ADD)
        
        elif particle_type == 'spark':
            # 전기 스파크 효과 (선 형태)
            end_x = x + particle['vx'] * 2
            end_y = y + particle['vy'] * 2
            pygame.draw.line(surface, color, (x, y), (end_x, end_y), max(1, size // 2))
        
        elif particle_type == 'ice' and 'rotation' in particle:
            # 얼음 결정 효과 (회전하는 별 모양)
            points = []
            for i in range(6):
                angle = particle['rotation'] + i * math.pi / 3
                px = x + size * math.cos(angle)
                py = y + size * math.sin(angle)
                points.append((px, py))
            if len(points) > 2:
                temp_surface = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
                shifted_points = [(p[0] - x + size * 2, p[1] - y + size * 2) for p in points]
                color_with_alpha = (*color[:3], alpha)
                pygame.draw.polygon(temp_surface, color_with_alpha, shifted_points)
                surface.blit(temp_surface, (x - size * 2, y - size * 2))
        
        elif particle_type == 'fire':
            # 화염 효과 (그라데이션)
            for i in range(size, 0, -1):
                flame_alpha = alpha * (i / size)
                flame_color = blend_colors(color, (255, 255, 255), 1 - (i / size))
                temp_surface = pygame.Surface((i * 2, i * 2), pygame.SRCALPHA)
                flame_color_alpha = (*flame_color[:3], int(flame_alpha))
                pygame.draw.circle(temp_surface, flame_color_alpha, (i, i), i)
                surface.blit(temp_surface, (x - i, y - i))

        elif particle_type == 'light_shard':
            # 빛의 파편 효과 (회전하는 다이아몬드 모양)
            brightness = particle.get('brightness', 1.0)
            rotation = particle.get('rotation', 0)

            # 밝기에 따라 색상 조정
            bright_color = tuple(min(255, int(c * brightness)) for c in color[:3])

            # 다이아몬드 모양 그리기
            points = []
            num_points = 4
            for i in range(num_points):
                angle = rotation + i * (2 * math.pi / num_points)
                px = x + size * math.cos(angle)
                py = y + size * math.sin(angle)
                points.append((px, py))

            if len(points) >= 3:
                # 글로우 효과
                for glow_size in range(3, 0, -1):
                    glow_alpha = alpha // (glow_size + 1)
                    temp_surface = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
                    glow_points = []
                    for i in range(num_points):
                        angle = rotation + i * (2 * math.pi / num_points)
                        px = size * 2 + (size + glow_size) * math.cos(angle)
                        py = size * 2 + (size + glow_size) * math.sin(angle)
                        glow_points.append((px, py))
                    glow_color = (*bright_color[:3], glow_alpha)
                    pygame.draw.polygon(temp_surface, glow_color, glow_points)
                    surface.blit(temp_surface, (x - size * 2, y - size * 2), special_flags=pygame.BLEND_ADD)

                # 메인 파편
                temp_surface = pygame.Surface((size * 4, size * 4), pygame.SRCALPHA)
                shifted_points = [(p[0] - x + size * 2, p[1] - y + size * 2) for p in points]
                color_with_alpha = (*bright_color[:3], alpha)
                pygame.draw.polygon(temp_surface, color_with_alpha, shifted_points)
                surface.blit(temp_surface, (x - size * 2, y - size * 2))

        elif particle_type == 'light_glow':
            # 빛나는 글로우 효과 (ADD 블렌딩)
            pulse_size = particle.get('size', size)
            for i in range(2, 0, -1):
                glow_alpha = alpha // (i * 2)
                glow_size = pulse_size + i * 2
                temp_surface = pygame.Surface((glow_size * 2, glow_size * 2), pygame.SRCALPHA)
                glow_color = (*color[:3], glow_alpha)
                pygame.draw.circle(temp_surface, glow_color, (glow_size, glow_size), glow_size)
                surface.blit(temp_surface, (x - glow_size, y - glow_size), special_flags=pygame.BLEND_ADD)

        else:
            # 기본 원형 파티클
            if alpha < 255:
                temp_surface = pygame.Surface((size * 2, size * 2), pygame.SRCALPHA)
                color_with_alpha = (*color[:3], alpha)
                pygame.draw.circle(temp_surface, color_with_alpha, (size, size), size)
                surface.blit(temp_surface, (x - size, y - size))
            else:
                pygame.draw.circle(surface, color, (x, y), size)

# === 파티클 이펙트 프리셋 ===
def create_hit_effect(x, y, particle_list, intensity=10):
    """히트 이펙트 생성 (타격 시)"""
    for _ in range(intensity):
        create_spark_particle(x, y, particle_list, speed_range=(3, 6), life=10)
        if random.random() < 0.5:
            create_energy_particle(x, y, particle_list, speed_range=(1, 3), life=15)

def create_dash_effect(x, y, particle_list, color=(100, 200, 255)):
    """대시 이펙트 생성"""
    for _ in range(8):
        create_trail_particle(x, y, particle_list, color, life=20)
        if random.random() < 0.3:
            create_neon_particle(x, y, particle_list, color=color)

def create_powerup_effect(x, y, particle_list):
    """파워업 획득 이펙트"""
    colors = NEON_PALETTE[:3]
    for _ in range(15):
        color = random.choice(colors)
        create_neon_particle(x, y, particle_list, color=color, speed_range=(2, 5))
    for _ in range(10):
        create_energy_particle(x, y, particle_list, speed_range=(1, 4), life=30)

def create_light_shard_particle(x, y, particle_list, color=(255, 255, 200), speed_range=(3, 8)):
    """빛의 파편 파티클 생성 (파워 스매싱용)

    Args:
        x, y: 생성 위치
        particle_list: 파티클을 추가할 리스트
        color: 파티클 색상
        speed_range: 속도 범위 (min, max)
    """
    angle = random.uniform(0, 2 * math.pi)
    speed = random.uniform(*speed_range)

    # 다양한 크기의 파편 생성
    size = random.randint(2, 6)

    particle_data = {
        'x': x + random.randint(-3, 3),
        'y': y + random.randint(-3, 3),
        'vx': math.cos(angle) * speed,
        'vy': math.sin(angle) * speed,
        'life': random.randint(15, 30),
        'max_life': 30,
        'color': color,
        'type': 'light_shard',
        'size': size,
        'alpha': 255,
        'rotation': random.uniform(0, 2 * math.pi),
        'rotation_speed': random.uniform(-0.3, 0.3),
        'gravity': 0.15,  # 중력 효과
        'brightness': 1.0  # 밝기 (시간에 따라 감소)
    }
    particle_list.append(particle_data)
    return particle_data

def create_light_shards_explosion(x, y, particle_list, intensity=20, color=(255, 255, 200), speed_range=(3, 8)):
    """빛의 파편 폭발 이펙트 생성 (파워 스매싱 넉백 시작 시)

    Args:
        x, y: 폭발 중심 위치
        particle_list: 파티클을 추가할 리스트
        intensity: 파티클 수 (파워에 비례)
        color: 파편 색상
        speed_range: 속도 범위
    """
    # 메인 파편들 (튀기는 효과)
    for _ in range(intensity):
        create_light_shard_particle(x, y, particle_list, color, speed_range)

    # 추가 글로우 파티클 (폭발감 강화)
    for _ in range(intensity // 2):
        angle = random.uniform(0, 2 * math.pi)
        speed = random.uniform(speed_range[0] * 0.5, speed_range[1] * 0.5)

        # 빛나는 글로우 효과
        glow_color = (
            min(255, color[0] + 30),
            min(255, color[1] + 30),
            min(255, color[2] + 50)
        )

        particle_data = {
            'x': x,
            'y': y,
            'vx': math.cos(angle) * speed,
            'vy': math.sin(angle) * speed,
            'life': random.randint(10, 20),
            'max_life': 20,
            'color': glow_color,
            'type': 'light_glow',
            'size': random.randint(4, 8),
            'alpha': 200,
            'pulse': random.uniform(0, 2 * math.pi)
        }
        particle_list.append(particle_data)