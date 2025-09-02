"""
사이버펑크 테마 메인 메뉴 배경
캐릭터 선택창과 통일된 밝은 사이버펑크 스타일
"""
import pygame
import math
import random
from typing import List, Tuple

class CyberpunkBackground:
    """사이버펑크 스타일 배경 관리 클래스"""
    
    def __init__(self, width: int, height: int):
        self.width = width
        self.height = height
        self.time = 0
        
        # 사이버펑크 색상 팔레트 (밝은 톤)
        self.colors = {
            'bg_top': (10, 20, 40),      # 상단 (어두운 남색)
            'bg_bottom': (30, 40, 60),    # 하단 (밝은 남색)
            'grid': (0, 150, 200, 25),    # 홀로그램 그리드
            'neon_cyan': (0, 255, 255),
            'neon_pink': (255, 0, 128),
            'neon_green': (128, 255, 0),
            'neon_purple': (150, 0, 255),
            'neon_yellow': (255, 255, 0),
        }
        
        # 태양계 스타일 공전 행성들
        self.planets = self._create_orbital_planets()
        
        # 네온 파티클 (최소화)
        self.neon_particles = []
        for _ in range(20):
            self.neon_particles.append({
                'x': random.randint(0, width),
                'y': random.randint(0, height),
                'vx': random.uniform(-0.3, 0.3),
                'vy': random.uniform(-0.3, 0.3),
                'size': random.randint(1, 2),
                'color': random.choice([self.colors['neon_cyan'], 
                                       self.colors['neon_pink'], 
                                       self.colors['neon_green']]),
                'alpha': random.randint(40, 100),
                'pulse_speed': random.uniform(0.02, 0.05)
            })
        
        # 사이버펑크 그리드 라인
        self.grid_offset = 0
        
        # 스캔라인 효과 (최소화)
        self.scan_lines = []
        for i in range(2):
            self.scan_lines.append({
                'y': random.randint(0, height),
                'speed': random.uniform(0.8, 1.5),
                'alpha': random.randint(15, 25),
                'color': self.colors['neon_cyan'],
                'width': 1
            })
        
        # 디지털 매트릭스 효과 (배경)
        self.matrix_drops = []
        for x in range(0, width, 120):
            self.matrix_drops.append({
                'x': x,
                'y': random.randint(-height, 0),
                'speed': random.uniform(0.3, 0.8),
                'chars': ['0', '1'],
                'color': (0, 100, 150, 30)  # 투명한 청록색
            })
    
    def _create_orbital_planets(self) -> List[dict]:
        """태양계 스타일 공전 행성 생성 - 심플하고 세련된 스타일"""
        center_x = self.width // 2
        center_y = self.height // 2
        
        planets = [
            # 중심 태양 (작고 깔끔하게)
            {
                'type': 'sun',
                'x': center_x,
                'y': center_y,
                'radius': 25,
                'color': (255, 230, 100),
                'glow_color': (255, 200, 50),
                'corona_color': (255, 150, 0),
                'orbit_radius': 0,
                'orbit_speed': 0,
                'orbit_angle': 0,
                'pulse': True,
                'rotation': 0,
                'surface_detail': 'simple'
            },
            # 심플한 행성 1
            {
                'type': 'simple_planet',
                'radius': 12,
                'color': (100, 150, 200),
                'glow_color': (150, 200, 255),
                'orbit_radius': 120,
                'orbit_speed': 0.5,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.02,
                'trail': []
            },
            # 심플한 행성 2
            {
                'type': 'simple_planet',
                'radius': 15,
                'color': (200, 150, 100),
                'glow_color': (255, 200, 150),
                'orbit_radius': 200,
                'orbit_speed': 0.3,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.015,
                'trail': []
            },
            # 심플한 행성 3
            {
                'type': 'simple_planet',
                'radius': 10,
                'color': (150, 100, 200),
                'glow_color': (200, 150, 255),
                'orbit_radius': 280,
                'orbit_speed': 0.2,
                'orbit_angle': random.uniform(0, math.pi * 2),
                'rotation': 0,
                'rotation_speed': 0.01,
                'trail': []
            }
        ]
        
        return planets
    
    def update(self, dt: float):
        """배경 업데이트"""
        self.time += dt
        
        # 행성 공전 업데이트
        center_x = self.width // 2
        center_y = self.height // 2
        
        for planet in self.planets:
            if planet['type'] == 'sun':
                # 태양 펄스 효과
                if planet['pulse']:
                    planet['current_radius'] = planet['radius'] + math.sin(self.time * 2) * 5
                planet['rotation'] += 0.005 * dt
            else:
                # 행성 공전
                planet['orbit_angle'] += planet['orbit_speed'] * dt
                planet['x'] = center_x + math.cos(planet['orbit_angle']) * planet['orbit_radius']
                planet['y'] = center_y + math.sin(planet['orbit_angle']) * planet['orbit_radius'] * 0.4
                
                # 행성 자전
                if 'rotation_speed' in planet:
                    planet['rotation'] += planet['rotation_speed']
                
                # 궤적 추가
                if len(planet['trail']) > 30:
                    planet['trail'].pop(0)
                planet['trail'].append((planet['x'], planet['y']))
                
                # 특수 효과 업데이트
                if planet['type'] == 'ringed_planet':
                    planet['ring_rotation'] = planet['orbit_angle'] * 0.5
                elif planet['type'] == 'tech_planet' and planet.get('has_satellites'):
                    planet['satellite_angle'] += 2.0 * dt
                elif planet['type'] == 'ice_planet':
                    for sparkle in planet['sparkle_points']:
                        sparkle['brightness'] = 0.5 + 0.5 * math.sin(self.time * 3 + sparkle['angle'])
                elif planet['type'] == 'toxic_planet':
                    for swirl in planet['gas_swirls']:
                        swirl['angle'] += swirl['speed']
        
        # 네온 파티클 업데이트
        for particle in self.neon_particles:
            particle['x'] += particle['vx']
            particle['y'] += particle['vy']
            
            if particle['x'] < 0 or particle['x'] > self.width:
                particle['vx'] *= -1
            if particle['y'] < 0 or particle['y'] > self.height:
                particle['vy'] *= -1
        
        # 스캔라인 업데이트
        for scan_line in self.scan_lines:
            scan_line['y'] += scan_line['speed']
            if scan_line['y'] > self.height:
                scan_line['y'] = -10
        
        # 매트릭스 업데이트
        for drop in self.matrix_drops:
            drop['y'] += drop['speed']
            if drop['y'] > self.height:
                drop['y'] = random.randint(-self.height, -50)
        
        # 그리드 오프셋 애니메이션
        self.grid_offset = (self.grid_offset + dt * 10) % 30
    
    def draw(self, surface: pygame.Surface):
        """배경 그리기"""
        
        # 1. 그라데이션 배경 (밝은 사이버펑크)
        for y in range(self.height):
            ratio = y / self.height
            r = int(self.colors['bg_top'][0] + ratio * (self.colors['bg_bottom'][0] - self.colors['bg_top'][0]))
            g = int(self.colors['bg_top'][1] + ratio * (self.colors['bg_bottom'][1] - self.colors['bg_top'][1]))
            b = int(self.colors['bg_top'][2] + ratio * (self.colors['bg_bottom'][2] - self.colors['bg_top'][2]))
            pygame.draw.line(surface, (r, g, b), (0, y), (self.width, y))
        
        # 2. 홀로그램 격자 패턴
        grid_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        for x in range(0, self.width, 30):
            pygame.draw.line(grid_surface, self.colors['grid'], 
                           (x + self.grid_offset % 30, 0), 
                           (x + self.grid_offset % 30, self.height))
        for y in range(0, self.height, 30):
            pygame.draw.line(grid_surface, self.colors['grid'], 
                           (0, y), (self.width, y))
        surface.blit(grid_surface, (0, 0))
        
        # 3. 디지털 매트릭스 (배경)
        matrix_font = pygame.font.Font(None, 12)
        for drop in self.matrix_drops:
            for i in range(5):
                char = random.choice(drop['chars'])
                alpha = int(drop['color'][3] * (1 - i/5))
                text = matrix_font.render(char, True, (*drop['color'][:3], alpha))
                surface.blit(text, (drop['x'], drop['y'] - i * 15))
        
        # 4. 궤도 그리기
        center_x = self.width // 2
        center_y = self.height // 2
        orbit_surface = pygame.Surface((self.width, self.height), pygame.SRCALPHA)
        
        for planet in self.planets:
            if planet['orbit_radius'] > 0:
                # 궤도 선 (타원)
                orbit_rect = pygame.Rect(
                    center_x - planet['orbit_radius'],
                    center_y - planet['orbit_radius'] * 0.4,
                    planet['orbit_radius'] * 2,
                    planet['orbit_radius'] * 0.8
                )
                pygame.draw.ellipse(orbit_surface, (50, 100, 150, 30), orbit_rect, 1)
        
        surface.blit(orbit_surface, (0, 0))
        
        # 5. 행성 그리기 (뒤에서 앞으로)
        sorted_planets = sorted(self.planets, key=lambda p: p.get('y', center_y))
        
        for planet in sorted_planets:
            x, y = planet.get('x', center_x), planet.get('y', center_y)
            
            if planet['type'] == 'sun':
                # 태양 그리기 - 심플하고 깔끔한 스타일
                radius = planet.get('current_radius', planet['radius'])
                
                # 1. 부드러운 글로우 효과 (2층만)
                for layer in range(2):
                    glow_radius = radius + (layer + 1) * 15
                    glow_alpha = 30 - layer * 10
                    glow_surf = pygame.Surface((int(glow_radius * 2), int(glow_radius * 2)), pygame.SRCALPHA)
                    pygame.draw.circle(glow_surf, (*planet['glow_color'], glow_alpha),
                                     (glow_radius, glow_radius), glow_radius)
                    surface.blit(glow_surf, (int(x - glow_radius), int(y - glow_radius)))
                
                # 2. 태양 본체 (심플한 그라데이션)
                pygame.draw.circle(surface, planet['color'], (int(x), int(y)), int(radius))
                
                # 3. 중심부 밝은 부분
                core_radius = int(radius * 0.6)
                pygame.draw.circle(surface, (255, 255, 200), (int(x), int(y)), core_radius)
            
            elif planet['type'] == 'simple_planet':
                # 심플한 행성 그리기
                radius = planet['radius']
                
                # 1. 은은한 글로우
                glow_radius = radius + 8
                glow_surf = pygame.Surface((int(glow_radius * 2), int(glow_radius * 2)), pygame.SRCALPHA)
                pygame.draw.circle(glow_surf, (*planet['glow_color'], 20),
                                 (glow_radius, glow_radius), glow_radius)
                surface.blit(glow_surf, (int(x - glow_radius), int(y - glow_radius)))
                
                # 2. 행성 본체
                pygame.draw.circle(surface, planet['color'], (int(x), int(y)), int(radius))
                
                # 3. 하이라이트
                highlight_offset = int(radius * 0.4)
                highlight_radius = int(radius * 0.5)
                pygame.draw.circle(surface, (255, 255, 255, 50),
                                 (int(x - highlight_offset), int(y - highlight_offset)), 
                                 highlight_radius)
            
            # 공통 궤적 그리기 (심플하게)
            if planet.get('trail') and len(planet['trail']) > 1:
                for i in range(len(planet['trail']) - 1):
                    alpha = int(15 * (i / len(planet['trail'])))
                    pygame.draw.circle(surface, (*planet.get('glow_color', (200, 200, 200)), alpha),
                                     (int(planet['trail'][i][0]), int(planet['trail'][i][1])), 2)
                                     
            # 나머지 복잡한 행성 타입들은 제거됨
                    flare_angle = planet['rotation'] + flare_num * (math.pi / 3)
                    
                    # 주 플레어
                    flare_length = radius * 2.5
                    flare_intensity = abs(math.sin(self.time * 3 + flare_num))
                    
                    # 플레어 경로 (곡선)
                    flare_points = []
                    for point in range(10):
                        point_dist = (point / 10) * flare_length
                        curve = math.sin(point * 0.3) * 10 * flare_intensity
                        flare_x = x + math.cos(flare_angle) * point_dist + math.sin(flare_angle) * curve
                        flare_y = y + math.sin(flare_angle) * point_dist - math.cos(flare_angle) * curve
                        flare_points.append((flare_x, flare_y))
                    
                    # 플레어 그리기
                    if len(flare_points) > 1:
                        for i in range(len(flare_points) - 1):
                            width = max(1, 5 - i // 2)
                            alpha = int(150 * (1 - i / len(flare_points)) * flare_intensity)
                            
                            # 외부 글로우
                            pygame.draw.line(surface, (255, 200, 100, alpha // 2),
                                           flare_points[i], flare_points[i + 1], width + 2)
                            # 중심 밝은 부분
                            pygame.draw.line(surface, (255, 255, 200, alpha),
                                           flare_points[i], flare_points[i + 1], width)
                
                # 5. 태양 표면 폭발 (프로미넌스)
                for prom in range(4):
                    prom_angle = self.time * 0.5 + prom * (math.pi / 2)
                    prom_height = radius * 0.8 * abs(math.sin(self.time * 2 + prom))
                    
                    # 프로미넌스 아치
                    prom_start_x = x + math.cos(prom_angle - 0.2) * radius
                    prom_start_y = y + math.sin(prom_angle - 0.2) * radius
                    prom_end_x = x + math.cos(prom_angle + 0.2) * radius
                    prom_end_y = y + math.sin(prom_angle + 0.2) * radius
                    prom_peak_x = x + math.cos(prom_angle) * (radius + prom_height)
                    prom_peak_y = y + math.sin(prom_angle) * (radius + prom_height)
                    
                    # 프로미넌스 입자
                    for particle in range(5):
                        t = particle / 5
                        # 베지어 곡선으로 아치 모양 만들기
                        px = (1-t)**2 * prom_start_x + 2*(1-t)*t * prom_peak_x + t**2 * prom_end_x
                        py = (1-t)**2 * prom_start_y + 2*(1-t)*t * prom_peak_y + t**2 * prom_end_y
                        
                        pygame.draw.circle(surface, (255, 150, 50),
                                         (int(px), int(py)), 3)
                        pygame.draw.circle(surface, (255, 200, 100),
                                         (int(px), int(py)), 2)
                
                # 6. 중심부 밝은 코어
                core_surf = pygame.Surface((int(radius * 2), int(radius * 2)), pygame.SRCALPHA)
                for i in range(int(radius // 3)):
                    core_alpha = int(100 * (1 - i / (radius // 3)))
                    pygame.draw.circle(core_surf, (255, 255, 255, core_alpha),
                                     (int(radius), int(radius)), int(radius // 3) - i)
                surface.blit(core_surf, (int(x - radius), int(y - radius)))
            
            elif planet['type'] == 'lava_planet':
                # 용암 행성 - 붉게 타오르는 효과
                radius = planet['radius']
                
                # 1. 화염 대기 효과 (여러 레이어)
                for layer in range(4):
                    flame_radius = radius + 10 + layer * 8
                    flame_alpha = 50 - layer * 10
                    flame_surf = pygame.Surface((flame_radius * 2 + 30, flame_radius * 2 + 30), pygame.SRCALPHA)
                    
                    # 불규칙한 화염 효과
                    for angle in range(0, 360, 15):
                        flame_len = flame_radius + random.randint(-3, 8)
                        flame_x = flame_radius + 15 + math.cos(math.radians(angle)) * flame_len
                        flame_y = flame_radius + 15 + math.sin(math.radians(angle)) * flame_len
                        pygame.draw.circle(flame_surf, (*planet['glow_color'], flame_alpha),
                                         (int(flame_x), int(flame_y)), 5)
                    
                    surface.blit(flame_surf, (x - flame_radius - 15, y - flame_radius - 15))
                
                # 2. 행성 본체 (다층 용암 텍스처)
                for i in range(int(radius)):
                    # 용암 패턴 생성
                    lava_pattern1 = abs(math.sin(planet['rotation'] + i * 0.15))
                    lava_pattern2 = abs(math.cos(planet['rotation'] * 1.5 + i * 0.25))
                    lava_intensity = (lava_pattern1 + lava_pattern2) / 2
                    
                    # 그라데이션 효과
                    depth_factor = 1 - (i / radius)
                    color_r = int(planet['color'][0] + lava_intensity * 80 * depth_factor)
                    color_g = int(planet['color'][1] + lava_intensity * 50 * depth_factor)
                    color_b = int(planet['color'][2] + lava_intensity * 20)
                    
                    # 색상 값 범위 확인
                    color_r = min(255, max(0, color_r))
                    color_g = min(255, max(0, color_g))
                    color_b = min(255, max(0, color_b))
                    
                    pygame.draw.circle(surface, (color_r, color_g, color_b),
                                     (int(x), int(y)), radius - i)
                
                # 3. 용암 균열 (표면 디테일)
                for crack in range(8):
                    crack_angle = planet['rotation'] + crack * (math.pi / 4)
                    crack_start_r = radius * 0.3
                    crack_end_r = radius * 0.9
                    
                    # 균열 시작점과 끝점
                    crack_start_x = x + math.cos(crack_angle) * crack_start_r
                    crack_start_y = y + math.sin(crack_angle) * crack_start_r
                    crack_end_x = x + math.cos(crack_angle) * crack_end_r
                    crack_end_y = y + math.sin(crack_angle) * crack_end_r
                    
                    # 균열 그리기 (빛나는 용암)
                    pygame.draw.line(surface, (255, 200, 0), 
                                   (crack_start_x, crack_start_y),
                                   (crack_end_x, crack_end_y), 2)
                    pygame.draw.line(surface, (255, 255, 100), 
                                   (crack_start_x, crack_start_y),
                                   (crack_end_x, crack_end_y), 1)
                
                # 4. 용암 분출 효과
                for i in range(6):
                    eruption_angle = planet['rotation'] * 3 + i * (math.pi / 3)
                    eruption_dist = radius + abs(math.sin(self.time * 3 + i)) * 10
                    eruption_x = x + math.cos(eruption_angle) * eruption_dist
                    eruption_y = y + math.sin(eruption_angle) * eruption_dist
                    
                    # 용암 입자
                    for j in range(3):
                        particle_offset = j * 3
                        pygame.draw.circle(surface, (255, 150 + j * 30, 0), 
                                         (int(eruption_x + particle_offset), 
                                          int(eruption_y + particle_offset)), 4 - j)
                
                # 5. 표면 하이라이트 (3D 효과)
                highlight_x = int(x - radius * 0.3)
                highlight_y = int(y - radius * 0.3)
                highlight_surf = pygame.Surface((int(radius), int(radius)), pygame.SRCALPHA)
                pygame.draw.circle(highlight_surf, (255, 100, 50, 30),
                                 (radius // 2, radius // 2), radius // 3)
                surface.blit(highlight_surf, (highlight_x, highlight_y))
            
            elif planet['type'] == 'ringed_planet':
                # 토성 스타일 고리 행성
                radius = planet['radius']
                
                # 1. 고리 시스템 (여러 층의 고리)
                if planet.get('ring_inner') and planet.get('ring_outer'):
                    ring_surf = pygame.Surface((planet['ring_outer'] * 2 + 40, 
                                              planet['ring_outer'] * 2 + 40), pygame.SRCALPHA)
                    
                    # 고리 회전 각도
                    ring_tilt = math.sin(planet['ring_rotation']) * 0.3
                    
                    # 여러 고리 밴드 그리기
                    ring_bands = [
                        {'inner': planet['ring_inner'], 'outer': planet['ring_inner'] + 5, 
                         'color': (200, 180, 150, 120), 'particles': True},
                        {'inner': planet['ring_inner'] + 8, 'outer': planet['ring_inner'] + 15, 
                         'color': (180, 160, 140, 100), 'particles': False},
                        {'inner': planet['ring_inner'] + 18, 'outer': planet['ring_outer'] - 5, 
                         'color': (160, 140, 120, 80), 'particles': True},
                        {'inner': planet['ring_outer'] - 3, 'outer': planet['ring_outer'], 
                         'color': (140, 120, 100, 60), 'particles': False}
                    ]
                    
                    for band in ring_bands:
                        # 메인 고리
                        pygame.draw.circle(ring_surf, band['color'],
                                         (planet['ring_outer'] + 20, planet['ring_outer'] + 20),
                                         band['outer'], band['outer'] - band['inner'])
                        
                        # 고리 입자 효과
                        if band['particles']:
                            for particle_angle in range(0, 360, 10):
                                particle_r = (band['inner'] + band['outer']) / 2
                                particle_x = planet['ring_outer'] + 20 + math.cos(math.radians(particle_angle)) * particle_r
                                particle_y = planet['ring_outer'] + 20 + math.sin(math.radians(particle_angle)) * particle_r * (1 - abs(ring_tilt))
                                particle_size = random.randint(1, 2)
                                pygame.draw.circle(ring_surf, (220, 200, 180, 150),
                                                 (int(particle_x), int(particle_y)), particle_size)
                    
                    surface.blit(ring_surf, (x - planet['ring_outer'] - 20, 
                                           y - planet['ring_outer'] - 20))
                
                # 2. 행성 본체 (복잡한 대기 패턴)
                for i in range(int(radius)):
                    # 다층 줄무늬 효과
                    band1 = math.sin(i * 0.25 + planet['rotation']) * 0.2
                    band2 = math.cos(i * 0.15 - planet['rotation'] * 0.5) * 0.15
                    band3 = math.sin(i * 0.35 + planet['rotation'] * 1.5) * 0.1
                    band_effect = 0.7 + band1 + band2 + band3
                    
                    # 깊이에 따른 색상 변화
                    depth_factor = 1 - (i / radius) * 0.5
                    color_r = int(planet['color'][0] * band_effect * depth_factor)
                    color_g = int(planet['color'][1] * band_effect * depth_factor)
                    color_b = int(planet['color'][2] * band_effect * depth_factor)
                    
                    # 색상 값 범위 확인
                    color_r = min(255, max(0, color_r))
                    color_g = min(255, max(0, color_g))
                    color_b = min(255, max(0, color_b))
                    
                    pygame.draw.circle(surface, (color_r, color_g, color_b),
                                     (int(x), int(y)), radius - i)
                
                # 3. 대기 소용돌이 (Great Red Spot 스타일)
                for spot in range(2):
                    spot_angle = planet['rotation'] + spot * math.pi
                    spot_x = x + math.cos(spot_angle) * radius * 0.5
                    spot_y = y + math.sin(spot_angle) * radius * 0.3
                    spot_radius = int(radius // 4)
                    
                    # 소용돌이 그라데이션
                    for i in range(spot_radius):
                        swirl_alpha = int(80 * (1 - i / spot_radius))
                        swirl_color = (180 + i * 3, 140 + i * 2, 100 + i, swirl_alpha)
                        pygame.draw.circle(surface, swirl_color,
                                         (int(spot_x), int(spot_y)), spot_radius - i)
                
                # 4. 표면 디테일 (구름 패턴)
                cloud_surf = pygame.Surface((int(radius * 2), int(radius * 2)), pygame.SRCALPHA)
                for cloud in range(5):
                    cloud_angle = planet['rotation'] * 2 + cloud * (math.pi * 2 / 5)
                    cloud_x = radius + math.cos(cloud_angle) * radius * 0.7
                    cloud_y = radius + math.sin(cloud_angle) * radius * 0.4
                    pygame.draw.ellipse(cloud_surf, (255, 240, 220, 20),
                                      (cloud_x - 10, cloud_y - 5, 20, 10))
                surface.blit(cloud_surf, (int(x - radius), int(y - radius)))
                
                # 5. 3D 하이라이트와 그림자
                # 상단 하이라이트
                highlight_surf = pygame.Surface((int(radius * 2), int(radius * 2)), pygame.SRCALPHA)
                for i in range(int(radius // 2)):
                    highlight_alpha = int(40 * (1 - i / (radius // 2)))
                    pygame.draw.circle(highlight_surf, (255, 255, 240, highlight_alpha),
                                     (radius - radius // 3, radius - radius // 3), radius // 3 - i)
                surface.blit(highlight_surf, (int(x - radius), int(y - radius)))
                
                # 하단 그림자
                shadow_surf = pygame.Surface((int(radius * 2), int(radius * 2)), pygame.SRCALPHA)
                pygame.draw.circle(shadow_surf, (50, 40, 30, 30),
                                 (radius + radius // 4, radius + radius // 4), radius // 2)
                surface.blit(shadow_surf, (int(x - radius), int(y - radius)))
            
            elif planet['type'] == 'ice_planet':
                # 얼음 행성 - 크리스탈 효과
                radius = planet['radius']
                
                # 1. 오로라 대기 효과
                aurora_surf = pygame.Surface((int(radius * 4), int(radius * 4)), pygame.SRCALPHA)
                for aurora_layer in range(3):
                    aurora_radius = radius * 1.5 + aurora_layer * 10
                    aurora_alpha = 30 - aurora_layer * 8
                    
                    # 오로라 색상 (청록색, 보라색, 녹색)
                    aurora_colors = [
                        (100, 200, 255, aurora_alpha),
                        (150, 100, 255, aurora_alpha),
                        (100, 255, 200, aurora_alpha)
                    ]
                    
                    for i, color in enumerate(aurora_colors):
                        aurora_angle = self.time + i * (math.pi * 2 / 3)
                        aurora_x = radius * 2 + math.cos(aurora_angle) * aurora_radius * 0.3
                        aurora_y = radius * 2 + math.sin(aurora_angle) * aurora_radius * 0.3
                        pygame.draw.ellipse(aurora_surf, color,
                                          (aurora_x - aurora_radius, aurora_y - aurora_radius // 2,
                                           aurora_radius * 2, aurora_radius))
                
                surface.blit(aurora_surf, (int(x - radius * 2), int(y - radius * 2)))
                
                # 2. 얼음 본체 (다층 크리스탈 구조)
                for i in range(int(radius)):
                    # 얼음 결정 패턴
                    crystal_pattern = abs(math.sin(i * 0.2 + planet['rotation'])) * 0.3
                    frost_pattern = abs(math.cos(i * 0.3 - planet['rotation'] * 0.5)) * 0.2
                    
                    # 깊이에 따른 투명도와 색상
                    depth_factor = 1 - (i / radius)
                    transparency = 0.7 + crystal_pattern
                    
                    color_r = int(planet['color'][0] * transparency + frost_pattern * 30)
                    color_g = int(planet['color'][1] * transparency + frost_pattern * 40)
                    color_b = int(planet['color'][2] * transparency + frost_pattern * 50)
                    
                    # 내부 빛 굴절 효과
                    if i < radius * 0.7:
                        refraction = abs(math.sin(planet['rotation'] + i * 0.1)) * 20
                        color_r = min(255, max(0, color_r + int(refraction)))
                        color_g = min(255, max(0, color_g + int(refraction * 1.2)))
                        color_b = min(255, max(0, color_b + int(refraction * 1.5)))
                    
                    # 색상 값 범위 확인
                    color_r = min(255, max(0, int(color_r)))
                    color_g = min(255, max(0, int(color_g)))
                    color_b = min(255, max(0, int(color_b)))
                    
                    pygame.draw.circle(surface, (color_r, color_g, color_b),
                                     (int(x), int(y)), radius - i)
                
                # 3. 얼음 균열 패턴
                crack_surf = pygame.Surface((int(radius * 2), int(radius * 2)), pygame.SRCALPHA)
                for crack in range(6):
                    crack_angle = planet['rotation'] * 0.5 + crack * (math.pi / 3)
                    
                    # 균열 경로 (지그재그)
                    crack_points = []
                    for point in range(5):
                        point_r = radius * (0.2 + point * 0.15)
                        offset = random.randint(-5, 5)
                        crack_x = radius + math.cos(crack_angle + offset * 0.01) * point_r
                        crack_y = radius + math.sin(crack_angle + offset * 0.01) * point_r
                        crack_points.append((crack_x, crack_y))
                    
                    # 균열 그리기
                    if len(crack_points) > 1:
                        for i in range(len(crack_points) - 1):
                            pygame.draw.line(crack_surf, (200, 230, 255, 100),
                                           crack_points[i], crack_points[i + 1], 2)
                            pygame.draw.line(crack_surf, (255, 255, 255, 150),
                                           crack_points[i], crack_points[i + 1], 1)
                
                surface.blit(crack_surf, (int(x - radius), int(y - radius)))
                
                # 4. 크리스탈 반짝임 (향상된 버전)
                for sparkle in planet['sparkle_points']:
                    sparkle_x = x + math.cos(sparkle['angle']) * radius * sparkle['dist']
                    sparkle_y = y + math.sin(sparkle['angle']) * radius * sparkle['dist']
                    
                    # 다층 반짝임 효과
                    for layer in range(3):
                        layer_size = sparkle['size'] * (3 - layer)
                        layer_alpha = int(sparkle['brightness'] * 255 / (layer + 1))
                        sparkle_surf = pygame.Surface((layer_size * 6, layer_size * 6), pygame.SRCALPHA)
                        
                        # 십자 모양 반짝임
                        pygame.draw.line(sparkle_surf, (*planet['crystal_color'], layer_alpha),
                                       (layer_size * 3, 0), (layer_size * 3, layer_size * 6), layer_size)
                        pygame.draw.line(sparkle_surf, (*planet['crystal_color'], layer_alpha),
                                       (0, layer_size * 3), (layer_size * 6, layer_size * 3), layer_size)
                        
                        # 대각선 반짝임
                        pygame.draw.line(sparkle_surf, (*planet['crystal_color'], layer_alpha // 2),
                                       (layer_size, layer_size), (layer_size * 5, layer_size * 5), 1)
                        pygame.draw.line(sparkle_surf, (*planet['crystal_color'], layer_alpha // 2),
                                       (layer_size * 5, layer_size), (layer_size, layer_size * 5), 1)
                        
                        surface.blit(sparkle_surf, (sparkle_x - layer_size * 3, sparkle_y - layer_size * 3))
                
                # 5. 서리 효과 (표면 디테일)
                frost_surf = pygame.Surface((int(radius * 2), int(radius * 2)), pygame.SRCALPHA)
                for frost in range(8):
                    frost_angle = self.time * 0.5 + frost * (math.pi / 4)
                    frost_x = radius + math.cos(frost_angle) * radius * 0.8
                    frost_y = radius + math.sin(frost_angle) * radius * 0.8
                    frost_size = random.randint(3, 6)
                    
                    # 눈송이 모양
                    for i in range(6):
                        branch_angle = frost_angle + i * (math.pi / 3)
                        branch_end_x = frost_x + math.cos(branch_angle) * frost_size
                        branch_end_y = frost_y + math.sin(branch_angle) * frost_size
                        pygame.draw.line(frost_surf, (240, 250, 255, 80),
                                       (frost_x, frost_y), (branch_end_x, branch_end_y), 1)
                
                surface.blit(frost_surf, (int(x - radius), int(y - radius)))
                
                # 6. 3D 빛 반사 효과
                highlight_surf = pygame.Surface((int(radius * 2), int(radius * 2)), pygame.SRCALPHA)
                # 여러 각도의 하이라이트
                for highlight in range(3):
                    h_angle = planet['rotation'] * 0.3 + highlight * (math.pi * 2 / 3)
                    h_x = radius + math.cos(h_angle) * radius * 0.3
                    h_y = radius + math.sin(h_angle) * radius * 0.3
                    h_radius = int(radius // 4)
                    
                    for i in range(h_radius):
                        h_alpha = int(60 * (1 - i / h_radius))
                        pygame.draw.circle(highlight_surf, (255, 255, 255, h_alpha),
                                         (int(h_x), int(h_y)), h_radius - i)
                
                surface.blit(highlight_surf, (int(x - radius), int(y - radius)))
            
            elif planet['type'] == 'tech_planet':
                # 사이버펑크 테크 행성
                radius = planet['radius']
                
                # 네온 글로우
                tech_glow = pygame.Surface((int(radius * 3), int(radius * 3)), pygame.SRCALPHA)
                pygame.draw.circle(tech_glow, (*planet['glow_color'], 50),
                                 (radius * 1.5, radius * 1.5), int(radius * 1.4))
                surface.blit(tech_glow, (int(x - radius * 1.5), int(y - radius * 1.5)))
                
                # 행성 본체
                pygame.draw.circle(surface, planet['color'], (int(x), int(y)), radius)
                
                # 회로 패턴
                for i in range(4):
                    circuit_angle = planet['rotation'] + i * math.pi / 2
                    for j in range(3):
                        circuit_radius = radius * (0.3 + j * 0.3)
                        circuit_x = x + math.cos(circuit_angle) * circuit_radius
                        circuit_y = y + math.sin(circuit_angle) * circuit_radius
                        pygame.draw.circle(surface, planet['circuit_color'],
                                         (int(circuit_x), int(circuit_y)), 2)
                
                # 위성
                if planet.get('has_satellites'):
                    for i in range(3):
                        sat_angle = planet['satellite_angle'] + i * math.pi * 2 / 3
                        sat_x = x + math.cos(sat_angle) * (radius + 15)
                        sat_y = y + math.sin(sat_angle) * (radius + 15)
                        pygame.draw.circle(surface, (200, 200, 255), (int(sat_x), int(sat_y)), 3)
            
            elif planet['type'] == 'toxic_planet':
                # 독성 가스 행성
                radius = planet['radius']
                
                # 독성 대기
                for i in range(3):
                    gas_radius = radius + (i + 1) * 8
                    gas_alpha = 30 - i * 10
                    gas_surf = pygame.Surface((gas_radius * 2, gas_radius * 2), pygame.SRCALPHA)
                    pygame.draw.circle(gas_surf, (*planet['glow_color'], gas_alpha),
                                     (gas_radius, gas_radius), gas_radius)
                    surface.blit(gas_surf, (x - gas_radius, y - gas_radius))
                
                # 행성 본체
                pygame.draw.circle(surface, planet['color'], (int(x), int(y)), radius)
                
                # 독성 가스 소용돌이
                for swirl in planet['gas_swirls']:
                    swirl_radius = radius * swirl['size']
                    swirl_x = x + math.cos(swirl['angle']) * radius * 0.6
                    swirl_y = y + math.sin(swirl['angle']) * radius * 0.6
                    swirl_surf = pygame.Surface((swirl_radius * 2, swirl_radius * 2), pygame.SRCALPHA)
                    pygame.draw.circle(swirl_surf, planet['gas_color'],
                                     (swirl_radius, swirl_radius), int(swirl_radius))
                    surface.blit(swirl_surf, (swirl_x - swirl_radius, swirl_y - swirl_radius))
            
            # 공통 궤적 그리기
            if planet.get('trail') and len(planet['trail']) > 1:
                for i in range(len(planet['trail']) - 1):
                    alpha = int(30 * (i / len(planet['trail'])))
                    trail_surf = pygame.Surface((6, 6), pygame.SRCALPHA)
                    pygame.draw.circle(trail_surf, (*planet['glow_color'], alpha),
                                     (3, 3), 3)
                    surface.blit(trail_surf, (planet['trail'][i][0] - 3, planet['trail'][i][1] - 3))
        
        # 6. 네온 파티클
        for particle in self.neon_particles:
            pulse = abs(math.sin(self.time * particle['pulse_speed']))
            current_alpha = int(particle['alpha'] * (0.5 + pulse * 0.5))
            particle_surf = pygame.Surface((particle['size'] * 2, particle['size'] * 2), pygame.SRCALPHA)
            pygame.draw.circle(particle_surf, (*particle['color'], current_alpha),
                             (particle['size'], particle['size']), particle['size'])
            surface.blit(particle_surf, (particle['x'] - particle['size'], particle['y'] - particle['size']))
        
        # 7. 스캔라인 효과
        for scan_line in self.scan_lines:
            line_surf = pygame.Surface((self.width, scan_line['width']), pygame.SRCALPHA)
            pygame.draw.rect(line_surf, (*scan_line['color'], scan_line['alpha']),
                           (0, 0, self.width, scan_line['width']))
            surface.blit(line_surf, (0, scan_line['y']))